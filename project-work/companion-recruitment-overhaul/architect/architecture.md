# Companion Recruitment & Re-recruitment Overhaul — Architecture & Implementation Plan

> **Feature branch:** `feature/companion-recruitment-overhaul`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-03-14
> **Status:** Approved

---

## Executive Summary

This feature fixes the broken companion re-recruitment path by adding an early-detection branch in the Lua `companion.lua:attempt_recruitment()` function. When a player says a recruitment keyword to an NPC, the system checks for an existing `companion_data` record (with `is_suspended=1` OR `is_dismissed=1`) **before** any cooldown, eligibility, or persuasion logic runs. If found, it skips directly to `client:CreateCompanion(npc)`, which already handles re-recruitment correctly in C++. The change is almost entirely in one Lua file, with a minor C++ addition for belt-and-suspenders cooldown cleanup and no database schema changes.

## Existing System Analysis

### Current State

The companion recruitment system spans two layers:

**Lua layer** (`akk-stack/server/quests/lua_modules/companion.lua`):
- `attempt_recruitment()` (line 390): Main entry point. Checks cooldown first (data_bucket), then calls `is_eligible_npc()` for full eligibility, then `check_dismissed_record()` for re-recruitment bonus, then calculates persuasion roll, then calls `_on_recruitment_success()` or `_on_recruitment_failure()`.
- `is_eligible_npc()` (line 180): Enforces 10 checks in order: CompanionsEnabled, group capacity, not-already-recruited, combat, **level range** (±3), **faction** (≥ Kindly), NPC type exclusions, bodytype, exclusion table, Froglok race.
- `check_dismissed_record()` (line 371): Queries `companion_data` for `is_dismissed = 1` only. **Does NOT check `is_suspended = 1`**. This is the primary gap.
- `_on_recruitment_success()` (line 438): Calls `client:CreateCompanion(npc)` which delegates to C++.
- `_on_recruitment_failure()` (line 464): Sets cooldown data_bucket.

**C++ layer** (`eqemu/zone/companion.cpp`):
- `Companion::CreateFromNPC()` (line 159): Correctly queries for `is_dismissed = 1 OR is_suspended = 1`. If found, calls `Load()` to restore full state (level, XP, equipment, stance). Clears both flags in C++ members and DB. **This code is correct.**
- `Companion::Death()` (line 355): Sets `is_suspended=1`, increments `times_died`, saves equipment (BUG-012 fix), starts death despawn timer.
- `Companion::Dismiss(false)` (line 2155): Sets `is_suspended=1` and `is_dismissed=1`, saves.
- `Companion::Load()` (line 2449): Restores all fields from `companion_data`. Calls `ScaleStatsToLevel()` if saved level differs from base. Loads equipment from `companion_inventories`.

**Database:**
- `companion_data` table: Has `is_suspended` (TINYINT), `is_dismissed` (TINYINT), `level`, `experience`, `recruited_level`, and all other companion state.
- `companion_inventories` table: Equipment persists through death (BUG-012 fix already in place).
- `data_buckets` table: Cooldown keys follow pattern `companion_cooldown_{npc_type_id}_{char_id}` with `character_id=0`.

### Gap Analysis

| Problem | Root Cause | Fix Layer |
|---------|-----------|-----------|
| Cooldown blocks re-recruitment | `attempt_recruitment()` checks cooldown BEFORE checking for existing record | Lua |
| Level range blocks re-recruitment | `is_eligible_npc()` enforces level range on all recruitment attempts | Lua |
| Faction blocks re-recruitment | `is_eligible_npc()` enforces faction on all recruitment attempts | Lua |
| Persuasion roll blocks re-recruitment | Roll is calculated for all recruitment attempts | Lua |
| `check_dismissed_record()` misses dead companions | Only checks `is_dismissed=1`, not `is_suspended=1` | Lua |
| Stale cooldowns persist after re-recruitment | No cleanup of data_bucket cooldown keys on success | Lua + C++ (belt-and-suspenders) |

**Summary**: The C++ layer is correct. All gaps are in the Lua layer. The fix is to detect existing records early in `attempt_recruitment()` and route to a bypass path.

## Technical Approach

### Architecture Decision

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `companion.lua` | **Primary**: Rewrite `attempt_recruitment()` flow | Only the Lua layer blocks re-recruitment. The detection must happen before any eligibility check. |
| `companion.lua` | **Primary**: Replace `check_dismissed_record()` with broader query | Current function only checks `is_dismissed=1`. Needs to also check `is_suspended=1`. |
| `companion.cpp` | **Minor**: Add cooldown data_bucket cleanup in `CreateFromNPC()` | Belt-and-suspenders: if Lua deletes the cooldown on success, C++ should also delete it to ensure no stale cooldown survives a code path change. |
| Database | **None**: No schema changes | `companion_data` already has both flags. `data_buckets` already has the cooldown pattern. |
| Rules | **None**: No new rules | Re-recruitment bypasses existing rules entirely via code path, not by changing rule values. |
| Config | **None**: No config changes | No server configuration is involved. |

This follows the least-invasive-first principle: the fix is almost entirely in Lua (the highest-priority scripting layer), with a minor C++ safety net. No database schema changes, no new rules, no protocol changes.

### Data Model

No changes to existing tables. The queries change only in the Lua layer:

**Current query** (`check_dismissed_record`, line 371):
```sql
SELECT id, level, experience, recruited_level, stance, name, companion_type
FROM companion_data
WHERE owner_id = ? AND npc_type_id = ? AND is_dismissed = 1 LIMIT 1
```

**New query** (`check_existing_companion_record`):
```sql
SELECT id, level, experience, recruited_level, stance, name, companion_type,
       is_dismissed, is_suspended
FROM companion_data
WHERE owner_id = ? AND npc_type_id = ? AND (is_dismissed = 1 OR is_suspended = 1) LIMIT 1
```

This matches the C++ `CreateFromNPC()` query exactly. Both layers now use identical matching logic.

### Code Changes

#### Lua Changes (Primary — `akk-stack/server/quests/lua_modules/companion.lua`)

**1. New function: `check_existing_companion_record(npc_type_id, char_id)`**

Replaces the narrow `check_dismissed_record()`. Queries `companion_data` for records matching `is_dismissed = 1 OR is_suspended = 1`, aligning with the C++ `CreateFromNPC()` query.

**2. Rewrite `attempt_recruitment()` flow:**

Current flow:
```
1. Check cooldown → block if active
2. Check eligibility (all 10 checks) → block if failed
3. Check dismissed record → optional +10% bonus
4. Calculate roll
5. Success/failure
```

New flow:
```
1. Check for existing companion record (is_dismissed=1 OR is_suspended=1)
2. IF FOUND → Re-recruitment track:
   a. Minimal safety checks only (enabled, group capacity, combat, not-already-recruited, not IsCompanion)
   b. Skip: cooldown, level range, faction, NPC type exclusions, bodytype, persuasion roll
   c. Call _on_recruitment_success(npc, client, existing_record)
   d. Delete stale cooldown data_bucket
   e. NPC says "I remember you. Let us continue."
3. IF NOT FOUND → First-time track (unchanged):
   a. Check cooldown
   b. Full eligibility check (all 10)
   c. Calculate persuasion roll
   d. Success/failure
```

**3. New function: `is_re_recruitment_eligible(npc, client)`**

Implements the minimal safety checks for re-recruitment:
- `Companions:CompanionsEnabled` rule
- Group capacity (< 6)
- NPC not already recruited (`is_recruited` entity variable)
- Neither party in combat
- NPC is not already a Companion instance (`IsCompanion()`)

These 5 checks are a subset of `is_eligible_npc()` that prevent game-breaking states.

**4. Modify `_on_recruitment_success()` to clean up cooldown on re-recruitment:**

After successful re-recruitment, explicitly delete any stale cooldown data_bucket key for this npc_type_id + char_id.

**5. Deprecate `check_dismissed_record()` (keep for backward compatibility but add comment)**

The old function is no longer called from `attempt_recruitment()` but may be referenced by other code. Mark it as deprecated.

#### C++ Changes (Minor — `eqemu/zone/companion.cpp`)

**1. Add cooldown data_bucket cleanup in `CreateFromNPC()` re-recruitment path (line ~217):**

After clearing `is_dismissed`/`is_suspended` flags, also delete any stale cooldown data_bucket key. This is a belt-and-suspenders measure — the Lua side should already clean this up, but if Lua is bypassed or a code path changes in the future, C++ ensures no stale cooldown survives.

```cpp
// After clearing flags (line 224):
// Belt-and-suspenders: delete any stale cooldown data_bucket
DataBucket::DeleteData(
    fmt::format("companion_cooldown_{}_{}", source_npc->GetNPCTypeID(), owner->CharacterID())
);
```

**2. Add HP restoration for dead companions in `CreateFromNPC()` re-recruitment path:**

When a dead companion (cur_hp=0) is re-recruited, `Load()` restores `cur_hp=0` from the DB. The companion needs to have HP set to max after re-recruitment. Currently this happens in `Unsuspend(true)` via `RestoreHealth()/RestoreMana()`, but the `Lua_Client::CreateCompanion()` path calls `Spawn()` not `Unsuspend()`. Verify and fix if needed: after `Load()` in the re-recruitment path, set HP/mana to max.

Looking at the code flow:
- `CreateFromNPC()` → `Load()` → restores `cur_hp=0` from dead companion
- `Lua_Client::CreateCompanion()` → `Save()` → `Spawn()`
- `Spawn()` does NOT call `RestoreHealth()`

This means a dead companion would re-recruit with 0 HP. **This is a bug that needs fixing.** After `Load()` in the re-recruitment path, we should set HP and mana to max:

```cpp
// After Load() succeeds in re-recruitment path:
companion->SetHP(companion->GetMaxHP());
companion->SetMana(companion->GetMaxMana());
```

#### Database Changes

None. No schema modifications needed.

#### Configuration Changes

None. No rule or config changes needed.

## Lua/C++ Interface Contract

**MANDATORY GATE as required by PRD.**

### Contract Definition

| Entry Point | Lua Signature | C++ Implementation | Returns | Notes |
|-------------|---------------|-------------------|---------|-------|
| Create companion | `client:CreateCompanion(npc)` | `Lua_Client::CreateCompanion(Lua_NPC)` → `Companion::CreateFromNPC(Client*, NPC*)` | `Lua_Companion` or nil | Single entry point for BOTH first-time and re-recruitment. C++ detects existing record internally. |
| Check active companion | `client:HasActiveCompanion(npc_type_id)` | `Lua_Client::HasActiveCompanion(uint32)` | bool | Not used in recruitment flow, but available. |
| Get companion | `client:GetCompanionByNPCTypeID(npc_type_id)` | `Lua_Client::GetCompanionByNPCTypeID(uint32)` | `Lua_Companion` or nil | Not used in recruitment flow, but available. |

### Contract Invariants

1. **Lua decides IF recruitment proceeds; C++ decides HOW.** Lua performs all gating logic (re-recruitment detection, eligibility checks). If Lua calls `client:CreateCompanion(npc)`, C++ handles the rest: DB lookup, Load(), flag clearing, Spawn(), group join.

2. **No new C++ methods needed.** The existing `client:CreateCompanion(npc)` handles both tracks transparently. Lua does not need to pass any flags or parameters to distinguish first-time from re-recruitment.

3. **C++ `CreateFromNPC()` is the source of truth for re-recruitment detection.** Even though Lua now detects existing records early, C++ independently re-checks for `is_dismissed=1 OR is_suspended=1`. This means the Lua detection is an optimization/UX improvement (skip checks, clean messaging) but does not change the C++ behavior.

4. **Both layers must agree on matching criteria.** Lua queries `is_dismissed = 1 OR is_suspended = 1`. C++ queries `is_dismissed = 1 OR is_suspended = 1`. These must remain synchronized.

5. **HP/mana restoration for dead companions happens in C++.** After `Load()` restores `cur_hp=0` for a dead companion, C++ sets HP/mana to max before `Spawn()` is called.

### Verification Requirements

- lua-expert confirms: `attempt_recruitment()` detects existing records before any eligibility checks and routes to re-recruitment track
- c-expert confirms: `CreateFromNPC()` correctly handles `is_suspended=1` records (including cur_hp=0 dead companions) and restores full state including HP/mana to max
- Both confirm: `client:CreateCompanion(npc)` is the single entry point with no new methods required

## Open Question Resolutions

### Q1: Should `is_suspended=1` with `cur_hp > 0` be treated differently?

**Resolution: No, treat identically.** This state represents a companion that was alive but suspended (e.g., zoned out with the player, then the player logged off and back on in a different zone). The companion was actively traveling with the player — there is no reason to require re-persuasion. The re-recruitment track should apply to ALL existing records with `is_suspended=1 OR is_dismissed=1`, regardless of `cur_hp` value.

### Q2: Should re-recruitment work from any NPC of the same npc_type_id?

**Resolution: Yes, any NPC.** The current behavior (any NPC with the same `npc_type_id` works) should be preserved. Forcing the player to find the exact spawn point would be unnecessarily punishing — some spawn points are deep in dangerous zones. The companion is associated with the npc_type_id, not a specific spawn instance.

### Q3: Two NPCs of the same npc_type_id simultaneously?

**Resolution: Works correctly.** The first NPC recruited depops and becomes the companion. If the companion dies and the player finds the second NPC of the same type, `CreateFromNPC()` queries by `owner_id + npc_type_id` and finds the existing record. The second NPC becomes the vessel for the restored companion. The `LIMIT 1` in both the Lua and C++ queries ensures only one record is matched even if (through a bug) multiple records exist.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | **Lua: Rewrite `attempt_recruitment()` with two-track detection** — Add `check_existing_companion_record()`, add `is_re_recruitment_eligible()`, restructure `attempt_recruitment()` to detect existing record first and route to re-recruitment track with minimal checks. Clean up stale cooldown on re-recruitment success. Deprecate `check_dismissed_record()`. | lua-expert | — | ~100 lines changed in companion.lua |
| 2 | **C++: Add cooldown cleanup and HP restoration in `CreateFromNPC()`** — After clearing is_dismissed/is_suspended flags in the re-recruitment path, delete stale cooldown data_bucket. After Load() for dead companions (cur_hp=0), set HP/mana to max. | c-expert | — | ~10 lines added in companion.cpp |
| 3 | **Integration verification: Test re-recruitment flow end-to-end** — Verify Lua detection → C++ CreateFromNPC → Load() → Spawn() → group join works for all scenarios: death re-recruitment, dismissal re-recruitment, group wipe recovery. Verify first-time recruitment is unchanged. | lua-expert + c-expert | 1, 2 | Testing, no code |

### Task Details

**Task 1 (lua-expert) — Lua Recruitment Flow Rewrite:**

File: `akk-stack/server/quests/lua_modules/companion.lua`

Changes:
1. Add new function `companion.check_existing_companion_record(npc_type_id, char_id)`:
   - Query: `SELECT id, level, experience, recruited_level, stance, name, companion_type, is_dismissed, is_suspended FROM companion_data WHERE owner_id = ? AND npc_type_id = ? AND (is_dismissed = 1 OR is_suspended = 1) LIMIT 1`
   - Returns the record table or nil

2. Add new function `companion.is_re_recruitment_eligible(npc, client)`:
   - Check CompanionsEnabled rule
   - Check group capacity < 6
   - Check NPC not already recruited (entity variable)
   - Check neither party in combat
   - Check NPC is not already a Companion
   - Returns true/false with reason string

3. Restructure `companion.attempt_recruitment(npc, client)`:
   ```lua
   function companion.attempt_recruitment(npc, client)
       local npc_type_id = npc:GetNPCTypeID()
       local char_id = client:CharacterID()

       -- STEP 1: Check for existing companion record (re-recruitment detection)
       local existing = companion.check_existing_companion_record(npc_type_id, char_id)

       if existing then
           -- RE-RECRUITMENT TRACK
           local eligible, reason = companion.is_re_recruitment_eligible(npc, client)
           if not eligible then
               client:Message(15, reason)
               return
           end
           -- Skip cooldown, level range, faction, persuasion — go straight to success
           companion._on_recruitment_success(npc, client, existing)
           -- Clean up any stale cooldown
           local cooldown_key = "companion_cooldown_" .. npc_type_id .. "_" .. char_id
           eq.delete_data(cooldown_key)
           return
       end

       -- FIRST-TIME RECRUITMENT TRACK (unchanged)
       local cooldown_key = "companion_cooldown_" .. npc_type_id .. "_" .. char_id
       local on_cooldown = eq.get_data(cooldown_key)
       if on_cooldown and on_cooldown ~= "" then
           npc:Say(npc:GetName() .. " won't discuss joining you again so soon.")
           return
       end

       local eligible, reason = companion.is_eligible_npc(npc, client)
       if not eligible then
           client:Message(15, reason)
           return
       end

       -- Calculate persuasion roll (first-time only)
       local base = tonumber(eq.get_rule("Companions:BaseRecruitChance")) or 50
       local faction_bonus = companion.get_faction_bonus(client, npc)
       local disposition_mod = companion.get_disposition_modifier(npc)
       local persuasion_bonus = companion.get_persuasion_bonus(client, npc)
       local level_diff = math.abs(client:GetLevel() - npc:GetLevel())
       local level_penalty = level_diff * LEVEL_DIFF_MODIFIER

       local roll_chance = base + faction_bonus + disposition_mod + persuasion_bonus - level_penalty
       roll_chance = math.max(ROLL_MIN, math.min(ROLL_MAX, roll_chance))

       local roll = math.random(1, 100)
       if roll <= roll_chance then
           companion._on_recruitment_success(npc, client, nil)
       else
           companion._on_recruitment_failure(npc, client, cooldown_key)
       end
   end
   ```

4. Modify `_on_recruitment_success()` dialogue to use "I remember you" for re-recruitment:
   - The existing code at line 456-460 already handles this with the `dismissed_record` parameter. Rename parameter to `existing_record` for clarity.

5. Add deprecation comment to `check_dismissed_record()`.

**Task 2 (c-expert) — C++ Cooldown Cleanup and HP Restoration:**

File: `eqemu/zone/companion.cpp`

Changes in `CreateFromNPC()` (re-recruitment path, after line 224):

```cpp
// Belt-and-suspenders: delete any stale cooldown data_bucket so
// Lua re-recruitment detection is never blocked by a leftover
// cooldown from a prior failed first-time attempt.
DataBucket::DeleteData(
    fmt::format("companion_cooldown_{}_{}", source_npc->GetNPCTypeID(), owner->CharacterID())
);

// Restore HP/mana to max for dead companions (cur_hp=0 in DB).
// Load() faithfully restores cur_hp from the DB, which is 0 for
// companions that died. Re-recruited companions should spawn alive.
companion->SetHP(companion->GetMaxHP());
companion->SetMana(companion->GetMaxMana());
```

Also verify: confirm `#include "common/data_bucket.h"` is already present (it is, line 21).

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Lua DB query fails silently | Low | Medium — falls through to first-time track, which still works | The query uses the same Database()/prepare/execute pattern used throughout companion.lua. Error would be visible in quest logs. |
| Stale cooldown survives both Lua and C++ cleanup | Very Low | Low — cooldown expires via TTL anyway (15 min default) | Both layers independently clean up. Even if both fail, the cooldown has a TTL. |
| `check_existing_companion_record` matches a record the C++ `CreateFromNPC` doesn't find | Very Low | Medium — C++ would fall through to fresh recruitment, losing saved state | Both use identical WHERE clause. Only possible if a DB write happens between the two queries (race window is <1ms in same zone process thread). |
| Re-recruited companion has 0 HP | Medium (if Task 2 is missed) | High — companion spawns dead | Task 2 explicitly adds HP restoration. This is flagged as a critical sub-task. |

### Compatibility Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| First-time recruitment regression | High if broken | The first-time track is completely unchanged — the code block runs exactly as before when no existing record is found. All existing first-time acceptance criteria still apply. |
| Existing dismissed companions from before this change | None | Records created before this change have the same `is_dismissed=1` flag structure. The new query is a superset of the old one. |
| Other code calling `check_dismissed_record()` | Low | Grep shows it is only called from `attempt_recruitment()`. Deprecation comment added but function preserved. |

### Performance Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Extra DB query on every recruitment attempt | Negligible | One indexed SELECT by `owner_id + npc_type_id` on a table with at most ~10 rows per player. Sub-millisecond. |
| Data bucket DELETE on every re-recruitment | Negligible | One DELETE by key string. Already done for other features. |

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes, with high confidence.

- The C++ re-recruitment path in `CreateFromNPC()` already works correctly. I verified this by reading lines 159-231 of companion.cpp. The query, Load(), flag clearing, and logging are all present and correct.
- The Lua `Database()` class with prepared statements is used extensively throughout companion.lua (check_dismissed_record, is_eligible_npc exclusion table check). The new query follows the same pattern.
- The `eq.delete_data()` function for cooldown cleanup is the standard data_bucket deletion API, used elsewhere in the codebase.
- The `DataBucket::DeleteData()` C++ function is declared in `common/data_bucket.h` (already included in companion.cpp line 21).

**Hardest part:** The Lua `attempt_recruitment()` restructuring must be done carefully to preserve the exact first-time recruitment behavior while adding the re-recruitment branch. The pseudocode in this document is a precise specification.

**HP restoration gap confirmed:** I traced the code path `CreateFromNPC()` → `Load()` → `Lua_Client::CreateCompanion()` → `Save()` → `Spawn()`. None of these set HP to max for a re-recruited dead companion. `Load()` restores `cur_hp=0` from the DB, and `Spawn()` does not call `RestoreHealth()`. This is a real bug that Task 2 fixes.

### Pass 2: Simplicity

**Is this the simplest approach?** Yes.

- The alternative would be to modify the C++ to expose a new "is re-recruitable" method to Lua, letting Lua skip checks based on C++ logic. But this adds complexity to the C++ API surface when a simple DB query in Lua achieves the same result.
- Another alternative: modify `is_eligible_npc()` to accept a "skip checks" parameter. This is fragile — it couples re-recruitment knowledge into the eligibility function. A separate function is cleaner.
- The two-function approach (`check_existing_companion_record` for detection, `is_re_recruitment_eligible` for minimal safety) clearly separates concerns.

**Nothing deferred:** All five PRD problems are addressed in this single implementation.

### Pass 3: Antagonistic

**What could go wrong?**

1. **Race condition: player says recruit keyword to two NPCs of the same type simultaneously.**
   - Only one `attempt_recruitment()` runs at a time per client (Lua events are processed sequentially per entity in the zone process). The first call sets `is_recruited` entity variable. The second NPC would fail the "not already recruited" check. **Not a risk.**

2. **Player dismisses companion, immediately says recruit keyword to same NPC type before DB write completes.**
   - `Dismiss()` calls `Save()` synchronously before `Depop()`. The DB write is committed before the Lua handler for the new NPC can fire. **Not a risk.**

3. **Data corruption: `companion_data` has multiple records for same owner_id + npc_type_id.**
   - Both Lua and C++ queries use `LIMIT 1`. Even with duplicate records, only one is matched. The C++ fresh recruitment path (when no existing record is found) creates a new record, so duplicates could theoretically exist if a prior soul wipe failed. The `LIMIT 1` handles this gracefully. **Low risk, handled.**

4. **Player exploits re-recruitment to bypass combat checks.**
   - The `is_re_recruitment_eligible()` function explicitly checks that neither party is in combat. A player cannot re-recruit mid-fight to get a fresh companion. **Mitigated.**

5. **Player exploits group capacity by rapid dismiss/recruit cycling.**
   - Dismiss removes from group. Re-recruit adds to group. Net group count stays the same. Group capacity check prevents exceeding 6. **Not exploitable.**

6. **Cooldown cleanup deletes wrong data_bucket entry.**
   - The key is deterministic: `companion_cooldown_{npc_type_id}_{char_id}`. It can only match the specific NPC type + character pair. **Not a risk.**

7. **Server crash between Lua re-recruitment detection and C++ CreateFromNPC.**
   - The Lua detection is read-only. No state is changed until `CreateFromNPC()` runs. If the server crashes after detection but before creation, the companion remains suspended/dismissed. The player can try again after restart. **No data corruption risk.**

8. **What if `eq.delete_data()` fails silently?**
   - The cooldown has a TTL (default 15 minutes). Even if deletion fails, the cooldown will expire naturally. The C++ belt-and-suspenders also attempts deletion. **Degraded but not broken.**

### Pass 4: Integration

**How do the pieces fit together?**

Task dependency graph:
```
Task 1 (Lua) ──┐
               ├── Task 3 (Integration testing)
Task 2 (C++)  ──┘
```

Tasks 1 and 2 are fully independent — they modify different files in different repositories. They can be implemented in parallel.

Task 3 requires both to be complete. It is a verification task, not a code task.

**Each expert has enough context:**
- lua-expert needs: this architecture doc, the PRD, and companion.lua (already in their standard working set). The pseudocode for `attempt_recruitment()` is a precise specification.
- c-expert needs: this architecture doc, the PRD, and companion.cpp. The code change is 6 lines in one method.

**Validation coverage:**
- First-time recruitment: unchanged code, regression tested via existing acceptance criteria.
- Re-recruitment after death: new path, tested via PRD acceptance criteria.
- Re-recruitment after dismissal: new path, tested via PRD acceptance criteria.
- Group wipe: multiple companions, tested via PRD acceptance criteria.
- Level restoration: existing C++ logic, verified via PRD acceptance criteria.
- Flag cleanup: both layers, verified via PRD acceptance criteria.
- Blocking scenarios: re-recruitment safety checks, verified via PRD acceptance criteria.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| lua-expert | Task 1: Rewrite `attempt_recruitment()` with two-track detection | Primary change is in companion.lua |
| c-expert | Task 2: Add cooldown cleanup and HP restoration in `CreateFromNPC()` | Minor C++ change for belt-and-suspenders safety and HP fix |

**Not needed:** data-expert (no schema changes), protocol-agent (no packet changes), config-expert (no rule changes), infra-expert (no deployment changes).

## Validation Plan

### First-Time Recruitment (Regression)

- [ ] Player within ±3 levels of NPC can recruit successfully (with sufficient faction and persuasion roll)
- [ ] Player outside ±3 levels of NPC is rejected with level range message
- [ ] Failed recruitment attempt triggers 15-minute cooldown
- [ ] Cooldown prevents re-attempt on the same NPC during the timer
- [ ] Faction below Kindly prevents recruitment
- [ ] Excluded NPC types (pets, bots, mercs, bankers, guildmasters) cannot be recruited

### Re-Recruitment After Death

- [ ] Companion dies → player finds same npc_type_id → says recruitment keyword → companion rejoins immediately
- [ ] No cooldown check — re-recruitment succeeds even if a cooldown data_bucket exists
- [ ] No level range check — even if base NPC is 20 levels below player
- [ ] No faction check — re-recruitment bypasses faction requirement
- [ ] No persuasion roll — re-recruitment is guaranteed (barring combat/group capacity)
- [ ] Companion returns at saved companion level (not base NPC level)
- [ ] Companion returns with all previously equipped items intact
- [ ] Companion XP is preserved
- [ ] Companion HP and mana are set to max after re-recruitment
- [ ] `is_suspended` flag is cleared in both C++ and database
- [ ] Any stale cooldown data_bucket is deleted (verify in data_buckets table)

### Re-Recruitment After Voluntary Dismissal

- [ ] Dismissed companion's npc_type_id re-recruitable with same bypasses
- [ ] `is_dismissed` flag is cleared on re-recruitment
- [ ] Companion returns at saved level with equipment and XP

### Group Wipe Recovery

- [ ] All companions that died in a group wipe can be re-recruited individually
- [ ] No cooldown stacking — each companion re-recruitment is independent
- [ ] Full group restored by sequentially re-recruiting each companion's NPC type

### Blocking Scenarios (Still Enforced)

- [ ] Player in combat cannot re-recruit
- [ ] NPC in combat cannot be re-recruited
- [ ] Group at 6 members cannot add re-recruited companion
- [ ] Companion system disabled prevents all recruitment

### Lua/C++ Contract Verification

- [ ] lua-expert confirms: `attempt_recruitment()` detects existing records before any eligibility checks
- [ ] c-expert confirms: `CreateFromNPC()` handles `is_suspended=1` with `cur_hp=0` and restores HP/mana to max
- [ ] Both confirm: `client:CreateCompanion(npc)` is the single entry point with no new methods

### Flag/State Cleanup

- [ ] After re-recruitment: `companion_data.is_suspended = 0`
- [ ] After re-recruitment: `companion_data.is_dismissed = 0`
- [ ] After re-recruitment: no `companion_cooldown_*` data_bucket exists for this pair
- [ ] After companion death: `companion_data.is_suspended = 1` (unchanged behavior)
- [ ] After companion death: equipment rows preserved (unchanged behavior)

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
