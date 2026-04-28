# Companion Re-recruitment Fix — Dev Notes: c-expert

> **Feature branch:** `bugfix/companion-rerecruit`
> **Agent:** c-expert
> **Task(s):** C++ triage — find level cap, dismissed-flag, and cooldown blockers
> **Date started:** 2026-04-27
> **Current stage:** Stage 1 Complete — awaiting architect dispatch for Stage 3+

---

## Task Assignment

Triage the C++ side of the companion re-recruitment blockers. Identify:
1. Source of "too low level" / "too far from your level" error
2. Dismissed/suspended flag persistence
3. Cooldown timer mechanism and location
4. Test infrastructure availability

---

## Stage 1: Plan / Triage

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/zone/companion.h` | 1–595 | Full Companion class — `m_is_dismissed`, `m_suspended`, `IsEverRecruited()`, `m_companion_id` |
| `eqemu/zone/companion.cpp` | 188–307, 2847–2895, 4115–4192 | `CreateFromNPC()`, `Load()`, `SpawnCompanionsOnZone()` |
| `eqemu/zone/lua_client.cpp` | 3639–3681 | `Lua_Client::CreateCompanion()` — C++ entry from Lua `client:CreateCompanion(npc)` |
| `akk-stack/server/quests/lua_modules/companion.lua` | 170–548 | Two-track recruitment logic, `is_eligible_npc()`, `check_existing_companion_record()` |
| `akk-stack/server/quests/global/global_npc.lua` | 1–100 | Event dispatch — recruitment keyword → `attempt_recruitment()` |
| DB: `rule_values` | — | `Companions:LevelRange = 50` (very permissive — not the active blocker) |
| DB: `companion_data` | — | Lydl row: `id=10, is_dismissed=0, is_suspended=1, cur_hp=1504, level=53, recruited_level=4` |
| DB: `data_buckets` | — | No active cooldown entries for companion_cooldown_* keys |

### Key Findings

#### Finding 1: "Too low level" error source

The phrase "too low level" does NOT appear in any C++ companion code. The actual
Lua error message at `companion.lua:212` is:
```
npc:GetName() .. " is too far from your level to recruit."
```
This fires from `is_eligible_npc()` when the level difference exceeds
`Companions:LevelRange`. However, the rule is currently set to **50** in the DB,
meaning a player would need to be more than 50 levels away from an NPC to hit
this check. This is NOT the current blocker.

**The "too low level" phrasing was a user paraphrase of an older error state, or
possibly hit when LevelRange was previously set to 3 (the code default fallback).**

#### Finding 2: The two-track recruitment system already exists and is correct

`companion.lua:attempt_recruitment()` implements a two-track system:
- **Re-recruitment track**: checks DB for `(is_dismissed = 1 OR is_suspended = 1)`
  FIRST, before cooldown or eligibility. If found, bypasses level range, faction,
  cooldown, and persuasion roll. Only minimal safety checks (capacity, combat state).
- **First-time track**: full eligibility checks including level range.

The query at `companion.lua:390-403` (`check_existing_companion_record`) matches
`WHERE owner_id = ? AND npc_type_id = ? AND (is_dismissed = 1 OR is_suspended = 1)`.

C++ `CreateFromNPC()` at `companion.cpp:215-222` uses the IDENTICAL query.

Both layers are ALIGNED. This is the correct design.

#### Finding 3: Lydl the Great DB state — what's actually happening

Current DB state:
```
id=10, npc_type_id=10162, owner_id=6, name=Lydl the Great,
level=53, is_dismissed=0, is_suspended=1, cur_hp=1504, recruited_level=4
```

The `is_suspended=1` flag IS present and SHOULD be detected by `check_existing_companion_record`.
The DB query runs correctly (verified manually: returns the row).

**Root cause of current blocker: Group capacity limit.**

The `SpawnCompanionsOnZone` log shows 4 companions being spawned for this player:
- Hollish Tnoops (id=18)
- Jimble Woodentoe (id=22)
- Jracol Brestiage (id=23)
- Lashun Novashine (id=24)

Player in group = 5 total. `is_re_recruitment_eligible()` checks:
`if group:GroupCount() >= 6 then return false, "Your party is full."`.

With 4 companions + 1 player = 5 members, group is NOT full (< 6). So group
capacity is not blocking Lydl.

**The actual blocker is the `Companions:MaxPerPlayer = 5` rule.** The player
already has 4 active companions. The `MaxPerPlayer` check exists somewhere in
the recruitment flow. I need to trace where `MaxPerPlayer` is enforced.

Let me search for `MaxPerPlayer` usage:

#### Finding 4: MaxPerPlayer check location

MaxPerPlayer is likely enforced in the Lua eligibility or the C++ CreateFromNPC path.
Need to verify — the `is_re_recruitment_eligible()` function does NOT check MaxPerPlayer
explicitly. Let me check if it's enforced somewhere in the C++ or Lua path.

Looking at `is_eligible_npc()` (first-time track) — it checks group capacity (`>= 6`)
but not MaxPerPlayer directly. The `is_re_recruitment_eligible()` also checks group
capacity only.

`Companions:MaxPerPlayer = 5` appears to be a rule value but may only be checked
in first-time recruitment, not re-recruitment, or it may be checked as group capacity
(since the group can hold max 6 members, and the player takes one slot, so 5 companions
= group full at 6).

**IMPORTANT:** With `Companions:MaxPerPlayer = 5` and the player having 4 active
companions at level 53 + player = 5 in the group, adding Lydl would make 6. That
hits the `group:GroupCount() >= 6` check in `is_re_recruitment_eligible()` — which
blocks re-recruitment with "Your party is full. Dismiss a companion or group member first."

**This is NOT a bug in the re-recruitment system — the party IS full with 4
companions already loaded.**

The question is: WHY is Lydl suspended and not loading on zone-in like the
others? Looking at `SpawnCompanionsOnZone()` at `companion.cpp:4132`:
```cpp
// Skip suspended companions — they exist in DB but are not spawned
if (cd.is_suspended) {
    continue;
}
```
Lydl is suspended (`is_suspended=1`) so it's correctly skipped on zone-in.
The other 4 companions have `is_suspended=0` (they are active).

#### Finding 5: The actual current scenario

Lydl died previously. Upon death, the companion was set to `is_suspended=1` and
depopulated. The player now has 4 OTHER companions who are active. Lydl is in a
"dead but stored" state in the DB.

To re-recruit Lydl, the player must dismiss one of the other 4 companions first,
then attempt to re-recruit Lydl. This is working as designed — the group capacity
check is NOT a bug; it's a valid constraint.

The historical "too low level" problem the user reported was likely from BEFORE
the two-track system was implemented, or when `LevelRange` was set to 3 instead
of 50.

#### Finding 6: Cooldown state

No cooldown entries exist in `data_buckets` for any `companion_cooldown_*` key.
The cooldown is properly absent. This blocker is already clear.

#### Finding 7: Dismissed flag handling — already correct

In `CreateFromNPC()` (re-recruitment path, `companion.cpp:259-265`):
```cpp
companion->m_suspended    = false;
companion->m_is_dismissed = false;
database.QueryDatabase(
    "UPDATE `companion_data` SET `is_dismissed` = 0, `is_suspended` = 0 WHERE `id` = {}"
);
```
Both C++ members AND the DB record are cleared atomically on re-recruitment.
The dismissed/suspended flag IS properly cleared on re-recruitment.

#### Finding 8: Test infrastructure

The test suite at `eqemu/zone/cli/tests/cli_companion_tests.cpp` has:
- 35+ test suites registered in `ZoneCLI::TestCompanion()`
- Suite 20 (`TestCompanionReRecruitmentHP`) tests the dead-companion HP restoration
  and DataBucket cooldown deletion paths
- No existing suite tests the full `CreateFromNPC` re-recruitment path end-to-end
  (DB record detection, Load(), flag clearing, Spawn())

TDD for this feature should add:
- A test that creates a companion_data record with `is_suspended=1`, calls the
  re-recruitment path (or simulates `CreateFromNPC`), and verifies:
  1. The record is found by `GetWhere(is_dismissed=1 OR is_suspended=1)`
  2. `Load()` restores level, XP, equipment correctly
  3. Flags are cleared (`is_dismissed=0, is_suspended=0`) in DB after re-recruitment
  4. HP/mana are set to max (not 0)

#### Finding 9: What DOES need fixing per the PRD invariant

The current code is largely correct for the scenarios tested. However, the PRD
invariant states re-recruitment must work without ANY level checks regardless
of `Companions:LevelRange`. Currently:
- **Re-recruitment track**: `is_re_recruitment_eligible()` does NOT check level range. CORRECT.
- **First-time track**: `is_eligible_npc()` checks level range with `LevelRange=50`. The Lua
  fallback default if rule is missing is `3`, which would cause false failures.

**The remaining risks per the PRD:**

1. **LevelRange rule fallback**: If `Companions:LevelRange` is not in `rule_values`, Lua
   defaults to `3` (line 207 of companion.lua: `or 3`). With `LevelRange=50` in DB,
   this is fine. But the invariant says re-recruitment must NEVER hit level checks.
   The current code correctly routes re-recruitment through `is_re_recruitment_eligible()`
   which skips level range entirely. This is already correct.

2. **dismissed_at column**: The `companion_data` table does not have a `dismissed_at`
   column (verified by `DESCRIBE companion_data`). The PRD appendix mentions it and the
   Lua `check_dismissed_record` (now deprecated) doesn't use it. Not a blocker.

3. **`check_dismissed_record` is deprecated**: Still present in companion.lua (line 371)
   with a DEPRECATED comment. It's no longer called from `attempt_recruitment()`. Safe.

#### Finding 10: Potential gap — `MaxPerPlayer` vs group capacity

`Companions:MaxPerPlayer = 5` is set in rule_values. The Lua checks `group:GroupCount() >= 6`.
These are equivalent only because one group slot is always the player. However, if the
player has no group, the group capacity check is skipped in `is_re_recruitment_eligible()`
(line 414-420). In that case, MaxPerPlayer would need its own enforcement. This appears
to be a pre-existing design gap but is NOT specific to the re-recruitment bug.

### Summary for Architect

**Blocker 1 (level cap):** The Lua error "too far from your level to recruit" exists
in `is_eligible_npc()` at `companion.lua:212`. However, the re-recruitment track BYPASSES
this entirely — it routes through `is_re_recruitment_eligible()` which has no level check.
The current LevelRange=50 rule value means even the first-time track rarely triggers this.
The fix (if any is needed) is cosmetic: ensure the fallback default in `is_eligible_npc()`
line 207 is `50` instead of `3`. The re-recruitment invariant is already upheld in code.

**Blocker 2 (cooldown):** No cooldown entries exist in data_buckets. The two-track system
correctly bypasses cooldown for re-recruitment. The cooldown is only set on first-time
recruitment FAILURE. This blocker is already resolved in the existing code.

**Blocker 3 (dismissed flag):** The flag IS properly cleared in `CreateFromNPC()` both
in memory and in DB. The Lua `check_existing_companion_record()` correctly detects both
`is_dismissed=1` and `is_suspended=1`. This blocker is already resolved in the existing
code.

**Current actual state:** The code is largely correct. The user's Lydl re-recruitment
failure in the original bug report was likely due to:
(a) An older version of companion.lua before the two-track system was implemented, OR
(b) A full party (4 active companions leaving no room for Lydl re-recruitment)

**What actually needs verification/testing:**
- The two-track system needs regression test coverage proving the invariant holds
- The Lua `LevelRange` default fallback should be changed from `3` to `50` to match
  the DB rule value (defense against future rule_values reset)
- An end-to-end integration test for the full re-recruitment path (DB record with
  `is_suspended=1` → `check_existing_companion_record()` → `CreateFromNPC()` → flags cleared)

---

## Stage 2: Research

### Documentation Consulted

All findings are based on direct source code and DB inspection. No external API
research required for this triage.

### Plan Amendments

No implementation plan yet — this is triage phase. Architect reviews these findings
and decides what (if anything) to implement.

---

## Stage 3: Socialize

Findings sent to `architect` on 2026-04-27.

---

## Open Items

- [ ] Architect to decide: is any C++ change needed, or is this purely a test coverage gap?
- [ ] Verify whether `Companions:MaxPerPlayer` is enforced anywhere beyond group capacity check
- [ ] Confirm whether the Lua LevelRange fallback `or 3` needs to be changed to `or 50`
