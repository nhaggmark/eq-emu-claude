# Companion Re-recruitment Fix — Dev Notes: c-expert

> **Feature branch:** `bugfix/companion-rerecruit`
> **Agent:** c-expert
> **Task(s):** C++ triage — find level cap, dismissed-flag, and cooldown blockers; v2 triage — multi-variant npc_type_id lookup bug
> **Date started:** 2026-04-27
> **Current stage:** v2 TRIAGE IN PROGRESS — companion-rerecruit-architecture-v2 team

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
