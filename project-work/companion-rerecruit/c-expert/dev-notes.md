# Companion Re-recruitment Fix — Dev Notes: c-expert

> **Feature branch:** `bugfix/companion-rerecruit`
> **Agent:** c-expert
> **Task(s):** C++ triage — find level cap, dismissed-flag, and cooldown blockers; v2 triage — multi-variant npc_type_id lookup bug
> **Date started:** 2026-04-27
> **Current stage:** v2 TRIAGE COMPLETE — on standby pending user V2-8 decision; tasks V2-3/V2-4/V2-5 queued for implementation team spawn

---

## Task Assignment

Triage the C++ side of the companion re-recruitment blockers. Identify:
1. Source of "too low level" / "too far from your level" error
2. Dismissed/suspended flag persistence
3. Cooldown timer mechanism and location
4. Test infrastructure availability

---

## Stage 4: V2 Implementation Log (2026-04-27)

### Tasks V2-3, V2-4, V2-5

**V2-3: Suite 35 added (TDD)**

File: `eqemu/zone/cli/tests/cli_companion_tests.cpp`
- Added `#include "common/repositories/companion_data_repository.h"` to get `CompanionDataRepository::CompanionData` struct and helpers
- Added `TestCompanionReRecruitmentVariantNameMatch()` (Suite 35) with 2 test cases:
  - 35.1: Seeds a companion_data row with `npc_type_id=10162` (Lydl variant A), proves old strict-ID query with variant B (10178) returns empty, then proves new name-based query finds the row
  - 35.2: Proves name-mismatch returns empty (WHERE clause actually filters)
- Registered in `ZoneCLI::TestCompanion()`
- Commit SHA: `6f752cd99`

**V2-4: companion.cpp fix applied**

File: `eqemu/zone/companion.cpp:218-220` (now lines 218-231)

Changed query from:
```cpp
"owner_id = {} AND npc_type_id = {} AND (is_dismissed = 1 OR is_suspended = 1) LIMIT 1"
```
to:
```cpp
"owner_id = {} AND name = '{}' AND name != '' "
"AND (is_dismissed = 1 OR is_suspended = 1) "
"ORDER BY level DESC, experience DESC, id DESC LIMIT 1"
```
with `Strings::Escape(source_npc->GetCleanName())` as the name binding.

Added diagnostic `LogInfo` when `existing[0].npc_type_id != source_npc->GetNPCTypeID()` to surface stale-name cases without changing behavior.

Updated comment block explaining name-based matching and ORDER BY rationale.

Commit SHA: `478d154bf`

**V2-5: Tests verified**

Post-fix build: clean (no warnings introduced)
Test results: 569 PASSED, 0 FAILED across all 35 suites
- Suite 20 (regression): PASSED
- Suite 35 (new): all 7 assertions PASSED

**Deviations from spec:** None. The `REPLACE` subquery was not used (rejected per V2 CORRECTIONS). No C++ exclusion check was added (Lua-only per V2 CORRECTIONS Correction 1).

**Next step:** V2-6 (infra-expert: server restart so new binary is live)

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

### Summary for Architect — REVISED after cross-check with lua-expert (2026-04-27)

**ROOT CAUSE FOUND: `companion.lua:1434` calls `npc:Dismiss(true)`, which maps to
`Companion::Dismiss(true)` → `SoulWipe()` → DELETE companion_data row.**

The Lua binding at `lua_companion.cpp:103` names the parameter `voluntary` but passes
it unchanged to C++ `permanent`. The Lua doc comment at `companion.lua:15` says
`true=voluntary (preserves record)` — this is WRONG. C++ treats `true=permanent=delete`.
`cmd_dismiss` always passes `true`, so every `!dismiss` permanently deletes the row.
On next recruit, Track 1 finds nothing, Track 2 fires, level check applies.

**Blocker 1 (level cap):** Cascading symptom of the SoulWipe bug. Not a direct level-logic bug.

**Blocker 2 (cooldown):** Not an active blocker. Cooldown only fires on first-time FAILURE.
Already bypassed by Track 1 when the row exists. Not the root cause.

**Blocker 3 (dismissed flag):** Root cause. `Dismiss(true)` removes the row entirely.
`CreateFromNPC()` never finds a row to restore. The fix must ensure the row is preserved.

**Lydl's current state (why Lydl differs):** Lydl DIED — death path never calls `Dismiss()`.
Death sets `is_suspended=1` and saves via three independent fallback paths. The row
exists (id=10, is_suspended=1) and IS findable by Track 1. Lydl can currently be re-recruited.

**Corrected group capacity math:** `GroupCount() >= 6` with 4 companions + 1 player = 5.
5 < 6 → group is NOT full. My prior "party full" diagnosis was wrong.

**The fix (all Lua + Lua binding rename):**
1. `companion.lua:1434` — `npc:Dismiss(true)` → `npc:Dismiss(false)` (lua-expert's domain)
2. `lua_companion.cpp:103` — rename parameter `voluntary` → `permanent` for clarity
3. New tests: `Dismiss(false)` preserves row; `Dismiss(true)` deletes; Track 1 end-to-end

**No C++ behavior changes needed.** The `Companion::Dismiss(bool permanent)` logic is
correct — `false=preserve, true=delete`. Only the call site and binding name are wrong.

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

## Open Items (v1 — Resolved by v1 architecture doc)

- [x] Architect to decide: is any C++ change needed, or is this purely a test coverage gap? → v1 decided Lua-only. v2 changes that.
- [x] Verify whether `Companions:MaxPerPlayer` is enforced anywhere beyond group capacity check → group capacity check is the enforcement
- [x] Confirm whether the Lua LevelRange fallback `or 3` needs to be changed to `or 50` → v1 fix addresses this

---

## v2 Triage: Multi-Variant npc_type_id Lookup Bug (2026-04-27)

### Context

The companion-rerecruit-architecture-v2 team was spawned because in-game validation
found a second bug: re-recruit lookup uses strict `npc_type_id` match, which fails
when a recruitble NPC has multiple `npc_type_id` variants in its spawngroup.

### Triage Findings

#### Finding v2-1: `CreateFromNPC` strict npc_type_id query (companion.cpp:215-222)

```cpp
auto existing = CompanionDataRepository::GetWhere(
    database,
    fmt::format(
        "owner_id = {} AND npc_type_id = {} AND (is_dismissed = 1 OR is_suspended = 1) LIMIT 1",
        owner->CharacterID(),
        source_npc->GetNPCTypeID()
    )
);
```

This is the ONLY site in C++ that queries `companion_data` using `npc_type_id`. The query
is strict: it must match the EXACT `npc_type_id` of the NPC the player is standing next to.

**What happens when no row is found:** Falls through to fresh-recruitment branch (lines 284-306).
Creates new `Companion` with `m_companion_id = 0`. When `Lua_Client::CreateCompanion` calls
`companion->Save()`, this triggers `InsertOne` — creating a DUPLICATE `companion_data` row.
The player's existing row (with correct level, XP, gear) is orphaned in the DB.

#### Finding v2-2: Multi-variant NPCs confirmed in production DB

```
npc_type_id   name
-----------   ----------------
10162         Lydl_the_Great   ← row 10 in companion_data (player's row)
10178         Lydl_the_Great   ← same spawngroup, can spawn instead
10181         Lydl_the_Great   ← same spawngroup, can spawn instead
392011        Lydl_the_Great   ← different zone (northro67529)

9144          Hollish_Tnoops   ← row 18 in companion_data
383271        Hollish_Tnoops   ← exists in npc_types (different zone/variant)
```

**Spawngroup `freporte_140` has THREE Lydl variants** (10162, 10178, 10181). When the zone
randomly spawns Lydl, there is a 2/3 chance it picks a variant that doesn't match the
stored `npc_type_id=10162`. Re-recruit fails with Track 2 fallback.

#### Finding v2-3: Name storage in companion_data

- `companion_data.name` is populated by `GetCleanName()` which converts underscores to spaces
  and strips numbers/special chars. So `Lydl_the_Great` → `"Lydl the Great"`.
- All four Lydl variants have `npc_types.name = "Lydl_the_Great"` → identical clean names.
- This means a name-based lookup in `companion_data` could match the stored row regardless
  of which variant the player encounters.

#### Finding v2-4: Lua side has the SAME strict npc_type_id bug

`companion.lua:397` (check_existing_companion_record):
```lua
"WHERE owner_id = ? AND npc_type_id = ? AND (is_dismissed = 1 OR is_suspended = 1) " ..
```
Also strict on `npc_type_id`. Lua uses `npc:GetNPCTypeID()` → the variant ID.
**Both layers must be fixed in sync** (same fix approach for each layer).

#### Finding v2-5: C++ fix approach — name-based lookup

The fix for `CreateFromNPC` must change the query from:
```
WHERE owner_id = ? AND npc_type_id = ? AND (is_dismissed = 1 OR is_suspended = 1)
```
to a name-based variant lookup. Two options:

**Option A — JOIN with npc_types (name-match across all variants):**
```sql
SELECT cd.*
FROM companion_data cd
JOIN npc_types nt ON nt.id = cd.npc_type_id
WHERE cd.owner_id = {char_id}
  AND nt.name = (SELECT name FROM npc_types WHERE id = {source_npc_type_id})
  AND (cd.is_dismissed = 1 OR cd.is_suspended = 1)
ORDER BY cd.level DESC, cd.experience DESC, cd.id DESC
LIMIT 1
```

**Option B — Use companion_data.name column (name already stored, no JOIN):**
```sql
SELECT cd.*
FROM companion_data cd
WHERE cd.owner_id = {char_id}
  AND cd.name = (SELECT REPLACE(name, '_', ' ') FROM npc_types WHERE id = {source_npc_type_id})
  AND (cd.is_dismissed = 1 OR cd.is_suspended = 1)
ORDER BY cd.level DESC, cd.experience DESC, cd.id DESC
LIMIT 1
```

**Recommendation: Option A** — companion_data.name strips numbers and special chars (CleanMobName),
while npc_types.name only has underscores. The JOIN is semantically cleaner and avoids
relying on the stored text being accurate (the stored name could be stale if the NPC was
renamed after recruitment). The JOIN goes through npc_types.name which is authoritative.

However, Option A has performance implications (see Finding v2-6 below). The architect
and data-expert should weigh in on the chosen approach.

**After finding the row**: The existing code at lines 226-281 is correct — it loads by
`existing[0].id` (primary key), not `npc_type_id`. No other changes needed once the
detection query is fixed. The `m_recruited_npc_type_id` is loaded from `cd.npc_type_id`
in `Load()` (line 2857), preserving the ORIGINAL variant's ID — this is intentional.

#### Finding v2-6: Index analysis for name-based query

Current indexes on `companion_data`:
- PRIMARY KEY (id)
- idx_owner (owner_id)
- idx_npc_type (npc_type_id)
- idx_owner_active (owner_id, is_dismissed, is_suspended)

**No index on `companion_data.name`** — but companion_data has at most ~5-10 rows per
player so this is not a hot-path concern. The idx_owner_active index will filter to
player's rows first; name comparison on 5-10 rows is negligible.

**No index on `npc_types.name`** — `npc_types` has 66,315 rows. A subquery or JOIN on
`npc_types.name` without an index is a table scan. This is called on EVERY recruitment
attempt (Track 1 check). With 66K rows and a text column, this could be slow.

**Data-expert should confirm:** Is `npc_types.name` indexed? If not, should one be added?
Alternative: Option B's subquery on `npc_types WHERE id = {source_npc_type_id}` uses the
PRIMARY KEY, then does a string replace — fast. But it relies on `companion_data.name`
being the clean name (which is currently always true given `GetCleanName()` in `Save()`).

#### Finding v2-7: All other companion_data query sites — do they need the fix?

| Location | Query type | Key used | Use case | Needs variant fix? |
|----------|-----------|----------|----------|-------------------|
| `companion.cpp:218` (CreateFromNPC) | GetWhere | npc_type_id | Re-recruit detection | YES — this is the bug |
| `companion.cpp:263` (CreateFromNPC, after fix) | QueryDatabase UPDATE | id (PK) | Clear flags | No — uses id from found row |
| `companion.cpp:654` (Process safety net) | QueryDatabase UPDATE | id (PK) via m_companion_id | Death fallback | No — updates existing companion's own row by id |
| `companion.cpp:672` (Process safety net) | QueryDatabase UPDATE | id (PK) via m_companion_id | Death fallback layer 2 | No — same |
| `companion.cpp:1881` (Death) | QueryDatabase UPDATE | id (PK) via m_companion_id | Death handler | No — same |
| `companion.cpp:2827` (Save, InsertOne) | CompanionDataRepository::InsertOne | n/a (INSERT) | New companion creation | No — new row |
| `companion.cpp:2838` (Save, UpdateOne) | CompanionDataRepository::UpdateOne | id (PK) | Save existing companion | No — uses m_companion_id |
| `companion.cpp:2849` (Load) | CompanionDataRepository::FindOne | id (PK) | Load by companion id | No — already by PK |
| `companion.cpp:3540` (ResurrectFromCorpse) | CompanionDataRepository::FindOne | id (PK) | Corpse rez | No — uses companion_id stored on corpse |
| `companion.cpp:3824` (SoulWipe) | CompanionDataRepository::DeleteOne | id (PK) | Permanent dismiss | No — uses m_companion_id |
| `companion.cpp:4119` (SpawnCompanionsOnZone) | GetWhere by owner_id | owner_id + is_dismissed | Load on zone-in | No — loads ALL player's companions, iterates; does not query by npc_type_id |

**Summary: Only one query site needs the fix — `companion.cpp:218` (the GetWhere in CreateFromNPC).**

All other sites use the PK (`id`) or `owner_id` — they're correct regardless of npc_type_id variants.

#### Finding v2-8: Lua duplicate query site (companion.lua:390-403)

`check_existing_companion_record()` also queries by `npc_type_id`. In the v1 flow, Lua
does this check FIRST (Track 1 detection), then calls `client:CreateCompanion(npc)` which
triggers C++ `CreateFromNPC`. Both must be fixed.

The Lua fix should mirror the C++ approach:
- If C++ uses Option A (JOIN npc_types by name), Lua can use the same JOIN pattern.
- Lua can use parameterized queries (prepared statements) via the Database() API already in use.

This is lua-expert's domain, not c-expert's.

#### Finding v2-9: Cooldown key — also npc_type_id based

The cooldown key format is `companion_cooldown_{npc_type_id}_{char_id}`. This is used:
- In Lua: `companion.lua:458` — `"companion_cooldown_" .. npc_type_id .. "_" .. char_id`
- In C++: `companion.cpp:274` — `fmt::format("companion_cooldown_{}_{}", source_npc->GetNPCTypeID(), ...)`

If the player failed a first-time recruit at variant 10162, the cooldown key is
`companion_cooldown_10162_6`. When they try again at variant 10178, the key is
`companion_cooldown_10178_6` — different key, so the cooldown appears absent.

**This is actually a BENEFIT for the multi-variant case**: cooldowns from variant A don't
block variant B. However, the cooldown deletion on re-recruitment (`companion.cpp:272-275`
and `companion.lua:475`) only clears the CURRENT variant's key. Stale cooldowns for other
variants are left in `data_buckets`. This is low-severity since Track 1 (re-recruit) never
reads the cooldown, only Track 2 (first-time) does.

**No fix needed for cooldown keys.** Track 1 bypasses cooldowns entirely.

#### Finding v2-10: Test infrastructure status

Current suites for re-recruitment coverage:
- Suite 20: HP/mana restoration and DataBucket cooldown — partial coverage
- Suite 25: Cooldown deletion (`TestCompanionCooldownDeletion`) — partial coverage
- No suite exercises the name-match / multi-variant detection path

**New test suite needed (Suite 35):** Multi-variant npc_type_id re-recruit detection.
Test approach:
1. Insert companion_data row with npc_type_id=A (some NPC), is_suspended=1
2. Simulate CreateFromNPC lookup with npc_type_id=B (different ID, same name in npc_types)
3. Assert the query FINDS the row despite npc_type_id mismatch
4. Assert the re-recruited companion has correct level/XP from the original row (not fresh defaults)
5. Assert row is NOT duplicated after re-recruitment

NOTE: `CreateFromNPC()` requires live `Client*` and `NPC*` so the test must exercise
the query logic directly (via `CompanionDataRepository::GetWhere` with the new query text)
rather than calling `CreateFromNPC` end-to-end. This mirrors the existing Suite 20 pattern.

Last suite before v2 work: **Suite 34** (BUG-035). Next available: **Suite 35**.

### Finding v2-11: Architect Deep-Dive Audit (2026-04-27)

#### 1. Complete C++ companion_data query site enumeration

All sites that touch companion_data, with key used and whether variant fix is needed:

| File:Line | Function | Operation | Key | Context | Needs fix? |
|-----------|----------|-----------|-----|---------|-----------|
| `companion.cpp:215` | `CreateFromNPC` | `GetWhere` | `owner_id + npc_type_id + flags` | Re-recruit detection — THE BUG | **YES** |
| `companion.cpp:261` | `CreateFromNPC` | `QueryDatabase UPDATE` | `id` (PK) | Clear flags after re-recruit match | No — uses id from found row |
| `companion.cpp:654` | `Process` safety net | `QueryDatabase UPDATE` | `m_companion_id` (PK) | Death fallback layer 1 (entity id=0 guard) | No |
| `companion.cpp:672` | `Process` safety net | `QueryDatabase UPDATE` | `m_companion_id` (PK) | Death fallback layer 2 (already suspended guard) | No |
| `companion.cpp:1881` | `Death` | `QueryDatabase UPDATE` | `m_companion_id` (PK) | Normal death — sets is_suspended=1 | No |
| `companion.cpp:2827` | `Save` | `InsertOne` | n/a (INSERT) | Fresh recruitment row creation | No |
| `companion.cpp:2838` | `Save` | `UpdateOne` | `m_companion_id` (PK) | Persist in-memory state to DB | No |
| `companion.cpp:2849` | `Load` | `FindOne` | `companion_id` (PK) | Restore companion from DB by PK | No |
| `companion.cpp:3540` | `ResurrectFromCorpse` | `FindOne` | `companion_id` (PK from corpse) | Rez path loads row by id stored on corpse | No |
| `companion.cpp:3824` | `SoulWipe/SoulWipeByCompanionID` | `DeleteOne` | `companion_id` (PK) | Permanent deletion — uses m_companion_id | No |
| `companion.cpp:4119` | `SpawnCompanionsOnZone` | `GetWhere` | `owner_id + is_dismissed` | Loads ALL active companion rows for player on zone-in | No — iterates by owner, not by npc_type_id |
| `companion.cpp:4137` | `SpawnCompanionsOnZone` (inner loop) | `LoadNPCTypesData` | `cd.npc_type_id` | Loads NPCType from stored ID — appearance on zone-in | No — stored npc_type_id is correct for zone-in |

**World/ and common/ repositories:** No companion_data access found in `world/`. The `companion_data_repository.h` provides only `FindOne` (by PK), `GetWhere` (free-form), `InsertOne`, `UpdateOne`, `DeleteOne`, `DeleteWhere` — all generic. No npc_type_id-specific logic in the repository itself.

**Lua binding side (`lua_client.cpp`):**
- `lua_client.cpp:3683` — `GetCompanionByNPCTypeID(npc_type_id)`: scans in-memory `entity_list.GetCompanionList()`, compares `companion->GetRecruitedNPCTypeID() == npc_type_id`. Uses `m_recruited_npc_type_id` (the stored original ID restored by Load). After the fix, a re-recruited Lydl via variant 10178 will have `m_recruited_npc_type_id=10162` (from Load). Scripts calling `GetCompanionByNPCTypeID(10178)` will NOT find it — they must use `GetCompanionByNPCTypeID(10162)` or the stored original ID. **Latent hazard if any Lua script passes the current NPC's variant ID to this function.**
- `lua_client.cpp:3697` — `HasActiveCompanion(npc_type_id)`: same scan, same concern.

Grep of quest scripts confirms: `HasActiveCompanion` and `GetCompanionByNPCTypeID` are only mentioned in the companion.lua module header comment — neither is called from any active production Lua script. No current hazard. Flag for future script authors.

**companion_exclusions check (`companion.lua:252-258`):** Queries `companion_exclusions WHERE npc_type_id = ?` using the source NPC's variant ID. This is a first-time eligibility check (Track 2 only). If exclusion rows exist for ONE variant but not another, different variants of the same NPC could get different answers. Currently moot — exclusions use npc_type_id, and if variant 10162 is excluded, variant 10178 may not be. This is a pre-existing design gap in the exclusions system, not introduced by the variant fix. Not blocking.

#### 2. Full CreateFromNPC flow — verified line numbers (current HEAD)

```
companion.cpp:188  — function entry, null/rule guards
companion.cpp:201  — LoadNPCTypesData(source_npc->GetNPCTypeID()) → npc_type_data
                     APPEARANCE DECISION: npc_type_data is the TARGETED VARIANT's NPCType
companion.cpp:207  — pos = source_npc->GetPosition()
companion.cpp:215  — CompanionDataRepository::GetWhere:
                     "owner_id = {} AND npc_type_id = {} AND (is_dismissed = 1 OR is_suspended = 1) LIMIT 1"
                     — strict npc_type_id match — THE BUG
companion.cpp:224  — if (!existing.empty()) → RE-RECRUIT PATH:
  companion.cpp:226  — new Companion(npc_type_data, ...)  ← targeted variant sets appearance/base stats
  companion.cpp:237  — companion->Load(existing[0].id)   ← loads from stored row by PK:
                          m_recruited_npc_type_id = cd.npc_type_id (stored original ID)
                          ScaleStatsToLevel(cd.level)    ← uses m_base_* from constructor
  companion.cpp:253  — SetHP(GetMaxHP()), SetMana(GetMaxMana())
  companion.cpp:259  — m_suspended=false, m_is_dismissed=false
  companion.cpp:261  — UPDATE companion_data SET is_dismissed=0, is_suspended=0 WHERE id={}
  companion.cpp:272  — DataBucket::DeleteData(cooldown_key)
  companion.cpp:281  — return companion (Spawn() called by Lua_Client::CreateCompanion)
companion.cpp:284  — else → FRESH RECRUIT PATH:
  companion.cpp:285  — new Companion(npc_type_data, ...)  ← targeted variant
  companion.cpp:296  — SetRecruitedNPCTypeID(source_npc->GetNPCTypeID())  ← targeted variant ID stored
  companion.cpp:304  — StoreBaseStats()  ← stores npc_type_data stats as m_base_*
  companion.cpp:306  — return companion (Save() called by Lua_Client::CreateCompanion → InsertOne)
```

**On miss:** Falls through to fresh-recruit path. `SetRecruitedNPCTypeID(source_npc->GetNPCTypeID())` stores the TARGETED variant's ID as `m_recruited_npc_type_id`. When `Save()` runs → `InsertOne` → new row with `npc_type_id = targeted_variant_id`. Player now has TWO companion_data rows (original with 10162, new orphan with 10178). Both rows are for the same companion. The original row's level/XP/gear is never loaded.

#### 3. Paths requiring strict ID match — none

No path REQUIRES strict npc_type_id match:

- **GM/admin commands:** No GM commands in `gm_commands/` query companion_data by npc_type_id. Confirmed by grep.
- **SpawnCompanionsOnZone:** Queries by `owner_id + is_dismissed`. Uses stored `cd.npc_type_id` to load NPCType for appearance — this is the stored original ID, which is correct and unchanged by the fix.
- **Save/Load/Persist:** Use PK (id) via `m_companion_id` or `companion_id` parameter. Completely ID-keyed.
- **SoulWipe:** Uses `m_companion_id` (PK). Correct.
- **ResurrectFromCorpse:** Uses `companion_id` stored on the corpse entity. Correct.

#### 4. Appearance question — what spawns when the fix relaxes the lookup?

The constructor `new Companion(npc_type_data, ...)` at line 226 takes the **targeted variant's** NPCType. This sets:
- Race, gender, texture, helm texture, body type (visual appearance)
- `m_base_str/sta/dex/agi/int/wis/cha/ac/atk/mr/fr/dr/pr/cr/hp/mana` (base combat stats)
- `m_recruited_npc_type_id = d->npc_id` (initially set to targeted variant)

Then `Load()` runs and:
- Overwrites `m_recruited_npc_type_id = cd.npc_type_id` (stored original variant)
- Calls `ScaleStatsToLevel(cd.level)` which recalculates stats using `m_base_*` (targeted variant's base stats) scaled to the saved level

**The visual appearance (race/texture/model) comes from the targeted variant (the NPC the player is standing next to), not from the stored row's npc_type_id.** For Lydl variants 10162/10178/10181, all three have the same race, gender, and texture in npc_types (they are the same NPC at different base levels). The stat difference is trivial (level 2 vs 3 vs 4 base NPC) and entirely overridden by ScaleStatsToLevel to the saved companion level (e.g., 53).

**Conclusion on appearance:** No observable difference to the player regardless of which variant they target. For any multi-variant NPC where variants genuinely differ (different race/texture), the player would see the targeted variant's appearance — which is the most natural behavior anyway (you recruited that specific version).

`m_recruited_npc_type_id` after Load() holds the stored original ID (10162). This is used only by:
1. `Save()` at line 2799 — writes back `cd.npc_type_id = m_recruited_npc_type_id` (preserves original ID in DB)
2. `GetRecruitedNPCTypeID()` — exposed to Lua scripts; currently only used by in-memory list scans

So the stored DB row continues to have `npc_type_id=10162` (original) even when recruited via variant 10178. Correct behavior.

#### 5. Test infrastructure assessment

**Can we add Suite 35 for multi-variant detection?**

Yes. The harness gives us:
- Real database via `database.QueryDatabase` and `CompanionDataRepository::*`
- Sentinel `owner_id` (e.g., 99999) for test isolation — cleanup via `DELETE WHERE owner_id=99999`
- `CompanionDataRepository::InsertOne` to seed a companion_data row with known npc_type_id
- `CompanionDataRepository::GetWhere` to invoke the new query directly
- Any NPC from `npc_types` can be used as the "source" variant — just need two npc_types rows with same name, different IDs

**What we CAN test:**
- Insert a row with `npc_type_id=A, is_suspended=1, owner_id=TEST_SENTINEL`
- Execute the new name-based query with `npc_type_id=B` (different ID, same name)
- Assert: row is found (companion_id == inserted id)
- Assert: row is NOT found with the old strict-ID query (proving the test covers the bug)
- Assert: cleanup leaves zero rows for TEST_SENTINEL

**What we CANNOT test directly:** `CreateFromNPC` end-to-end (requires live `Client*` + `NPC*`). Mirror pattern of Suite 20: test the query logic directly.

**Prerequisite:** Need two npc_types rows with the same `name` field, different `id`s. From live DB: `Lydl_the_Great` has ids 10162, 10178, 10181, 392011. The test can use any two of these.

**Suite 35 is feasible and well-supported by the harness.**

#### 6. Charm pets, swarm pets, mercs, bots

- `pet.cpp`: No companion_data or npc_type_id companion queries — confirmed by grep. Pet system is entirely separate.
- `merc.cpp`: Uses its own `merc_npc_type_id` column in a different table (`merc_inventory`, `merc_spells`, etc.). No shared lookup helper with Companion.
- `bot.cpp`: No companion_data access — confirmed by grep. Bot system uses `bot_data` table.
- No shared `CreateFromNPC`-style helper exists between Companion and any other subclass.

The fix to `CreateFromNPC` is entirely isolated to the Companion class.

#### 7. lua_companion.cpp:103-107 — Dismiss parameter naming (latent hazard)

```cpp
// lua_companion.cpp:103-107 (current HEAD)
void Lua_Companion::Dismiss(bool voluntary)
{
    Lua_Safe_Call_Void();
    self->Dismiss(voluntary);
}
```

The C++ signature is `Companion::Dismiss(bool permanent)`. The binding names it `voluntary`. This is still a latent hazard — the semantics are inverted in the name. Anyone reading only the Lua binding would assume `voluntary=true → preserve record`, but `Companion::Dismiss(true)` = `permanent=true` = SoulWipe.

The v1 fix at `companion.lua:1434` (`Dismiss(true)` → `Dismiss(false)`) closes the production bug. The naming mismatch in the binding remains. **It is not relevant to v2** (the v2 bug is the npc_type_id lookup, not the Dismiss path). Still deferred as future work as documented in v1 architecture decision 1b. No action needed for v2.

### Summary for Architect

**Root cause:** `companion.cpp:218` uses `npc_type_id = {source_npc_type_id}` in the
re-recruit detection query. When Lydl (or any multi-variant NPC) spawns as a different
variant than was originally recruited, the query returns empty → Track 2 fires → fresh
recruitment → duplicate row.

**Same bug in Lua** at `companion.lua:397` — both layers must be fixed in sync.

**C++ change required (unlike v1 which was Lua-only).** This requires a rebuild.

**Recommended fix approach:**
- Change `companion.cpp:218` query to match on `npc_types.name` via a subquery or JOIN,
  instead of strict `npc_type_id` match. Use `ORDER BY level DESC, experience DESC, id DESC LIMIT 1`
  for deterministic selection (already present in the Lua v1 fix).
- Lua `check_existing_companion_record` needs the same change (lua-expert's domain).
- Add Suite 35 TDD test for multi-variant detection.

**Performance concern:** `npc_types.name` has no index (66K rows, text column). Data-expert
should confirm whether an index is warranted, or whether Option B (companion_data.name
subquery via PK) is preferable.

**No other C++ changes needed** — all other companion_data query sites use PK-based lookups.
**No GM admin commands** query companion_data by npc_type_id — confirmed by grep of gm_commands/.

**Risk:**
- Adding a JOIN/subquery to the hot-path re-recruit detection query is low risk but
  changes the C++ code path in a way that requires a full rebuild and re-test.
- The `npc_types.name` table scan concern is real but bounded (recruitment is not
  called in a tight loop — it fires once per manual player action).
- The fix does NOT change what happens after a row is found — load-by-id path is unchanged.

**Third bug found:** The `companion_data.name` column can become stale if an NPC is renamed
in the DB after the companion was recruited (the name is written once at recruitment via
`GetCleanName()`). This is low severity and pre-existing — not introduced by the variant fix.

---

### Finding v2-12: data-expert confirmation — Option B safe (2026-04-27)

**companion_data.name confirmed reliable in production:**
All 5 rows verified. `varchar(64) NOT NULL DEFAULT ''`. All clean names match
`REPLACE(npc_types.name, '_', ' ')` exactly. No null, no empty-string rows exist.

**Option B performance confirmed:** Inner subquery is O(1) via PK. Outer comparison
touches 5-10 rows. No schema change needed. Option A (JOIN) would need
`idx_name_prefix (name(64))` on npc_types + migration entry in
`database_update_manifest_custom.h` — unnecessary overhead.

**Two defensive guards for C++ implementation (data-expert recommendations):**

1. **Empty-name guard:** If `companion_data.name = ''`, fall back to strict npc_type_id
   match rather than matching every row with an empty name. Add `AND name != ''` to
   the query's WHERE clause.

2. **Stale-name log:** If name-match fires with a different npc_type_id than targeted,
   emit a `LogInfo` noting the stored vs. targeted ID mismatch. Helps diagnose any
   future stale-name cases in server logs without changing behavior.

**Exclusions constraint — C++ is not affected for v2:** data-expert noted that "name-match
path in Track 1 must still check companion_exclusions on the TARGET npc_type_id."
Confirmed via grep: C++ has ZERO references to `companion_exclusions` anywhere in
`zone/*.cpp` or `zone/*.h`. Architect decision: Lua-only exclusion guard for v2 is
functionally sufficient because `CreateFromNPC` has exactly ONE production caller
(`lua_client.cpp:3647`). C++ defense-in-depth deferred to Out-of-Scope item 11.
See Finding v2-13 for correction rationale.

**SUPERSEDED — DO NOT USE:** the `REPLACE` subquery shape below was proposed before
architect correction. See Finding v2-13 for the correct query shape.
~~`AND name = (SELECT REPLACE(name, '_', ' ') FROM npc_types WHERE id = {source_npc_type_id})`~~

**Correct Option B query (per v2 architecture doc, architect-confirmed):**
```
owner_id = ?
AND name != ''
AND name = ?                   -- bound to source_npc->GetCleanName()
AND (is_dismissed = 1 OR is_suspended = 1)
ORDER BY level DESC, experience DESC, id DESC
LIMIT 1
```
Bind `source_npc->GetCleanName()` as the second parameter. See Finding v2-13.

---

### Finding v2-13: Architect corrections — SQL shape and exclusions scope (2026-04-27)

#### Correction 1: SQL shape — `REPLACE` subquery is WRONG, bind `GetCleanName()` instead

The `REPLACE(npc_types.name, '_', ' ')` subquery shape was proposed in Finding v2-12
but is incorrect. Verified against live source:

`CleanMobName()` at `common/strings_legacy.cpp:208`:
```cpp
if (isalpha(in[i]) || (in[i] == '`')) {    // numbers, #, or any other crap just gets skipped
    out[j++] = in[i];
}
```
Only alpha chars and backtick are kept. **Digits are stripped, not preserved.**

`MakeNameUnique()` at `entity.cpp:3331` appends `%03d` digit suffixes (`Lydl001`, `Lydl002`).
`CleanMobName` strips those digits: `Lydl001` → `Lydl`. But `REPLACE('_', ' ')` would
produce `Lydl001` (underscores → spaces, digits untouched). Match would fail for any
in-zone disambiguated NPC.

`source_npc->GetCleanName()` already has digits stripped — it IS the canonical form.
Binding it directly as a query parameter avoids any SQL-side string transformation and
is bit-for-bit identical to what `companion_data.name` stores (also written via `GetCleanName()`
in `Save()`). This is the same pattern Lua uses (`npc:GetCleanName()`).

**The correct WHERE clause for V2-4 implementation:**
```cpp
fmt::format(
    "owner_id = {} AND name != '' AND name = '{}' "
    "AND (is_dismissed = 1 OR is_suspended = 1) "
    "ORDER BY level DESC, experience DESC, id DESC LIMIT 1",
    owner->CharacterID(),
    Strings::Escape(source_npc->GetCleanName())
)
```
`Strings::Escape` on the bound name guards against SQL metacharacters in pathological
NPC display names.

#### Correction 2: Exclusions scope — v1 "safe to bypass" doesn't hold under v2 name-match

**Original reasoning (v1, WRONG for v2):** "Track 1 bypasses exclusions by design —
same ID means same exclusion state."

**Why it breaks under v2:** v2 name-match fires on a SET of variant IDs sharing a name.
Some variants may be excluded in `companion_exclusions`, others not. A player could
potentially re-recruit via a non-excluded variant even if the originally-recruited ID
was excluded (or vice versa). The PRD invariant covers re-recruiting YOUR companion,
not exploiting name-match to bypass exclusions via a different variant.

**Architect decision:** Lua-only exclusion check is functionally sufficient for v2.
`CreateFromNPC` has exactly one production caller (`lua_client.cpp:3647`). lua-expert
adds the exclusion check to `is_re_recruitment_eligible()` in V2-2. C++ defense-in-depth
deferred to Out-of-Scope item 11.

**Impact on V2-3 (Suite 35):** One test case removed — the exclusion-bypass test moves
to V2-1 (lua-expert's responsibility). Suite 35 has TWO test cases:
1. Name-match finds correct row when variant ID differs from stored ID (proves fix)
2. Strict-ID query returns empty for the variant (proves test covers the bug, not just a vacuous pass)
