# BUG-028 Investigation: Re-recruitment Blocked for Lashun Novashine

> **Investigator:** architect
> **Date:** 2026-03-14
> **Status:** Root cause identified

---

## Executive Summary

Lashun Novashine's `companion_data` record (id=17) no longer exists in the database.
Without a record, the re-recruitment track in `companion.lua:attempt_recruitment()` cannot
detect her as a former companion and falls through to the first-time recruitment path,
where a prior failed roll's cooldown blocks the attempt. The companion_data record was
lost during a death event on 2026-03-13 at ~22:32 in Upper Guk (guktop), where zone
logs show the companion's entity ID had already become 0 before the death was processed
— indicating the entity was corrupted or cleaned up before `Companion::Death()` could
call `Save()`.

---

## Root Cause

**The companion_data record for Lashun Novashine (id=17, npc_type_id=2032) was deleted
or lost, leaving the re-recruitment system unable to find a prior record.**

### Evidence Chain

1. **companion_data table has NO record for npc_type_id=2032:**
   ```sql
   SELECT * FROM companion_data WHERE npc_type_id = 2032;
   -- Empty result set
   ```

2. **The record DID exist (companion_data id=17):**
   Zone logs confirm Lashun was a valid companion from March 8 through March 13:
   ```
   [03-09] SpawnCompanionsOnZone: spawned companion 'Lashun Novashine' (id 17)
   [03-11] CreateFromNPC: re-recruiting companion id [17] 'Lashun Novashine'
   [03-13] SpawnCompanionsOnZone: spawned companion 'Lashun Novashine' (id 17)
   ```
   IDs 1-23 exist in companion_data; id 17 is in the gap of deleted records.

3. **The record was lost during a death event on March 13 at ~22:32 in guktop:**
   ```
   [03-13-2026 22:19:17] Companion [Lashun Novashine] spawned (entity id: 273)
   [03-13-2026 22:22:44] Companion [Lashun Novashine] leveled up to [29]
   [03-13-2026 22:32:09] Companion [Lashun Novashine] (id 0) NPC::Process() returned
       false — npc_depop=[1] companion_depop=[0] IsEngaged=[0] HP=[0]
   ```
   **The entity ID is 0 at time of death processing.** This is the smoking gun.
   Normal companions have non-zero entity IDs (e.g., 273). Entity ID 0 means
   the entity was already removed from the entity list or was in an invalid state.

4. **What entity ID=0 at death means for Save():**
   - `Companion::Death()` calls `SetSuspended(true)` then `Save()`
   - `Save()` uses `m_companion_id` to decide INSERT vs UPDATE
   - If the companion was corrupted (entity cleaned up early), `m_companion_id`
     could have been reset to 0, causing `Save()` to attempt a new INSERT that
     may fail or create a duplicate
   - OR: the entity was deleted from the entity list before `Death()` ran,
     meaning `Death()` and `Save()` never executed properly

5. **No SoulWipe for id=17 in any log:**
   ```
   Soul wipes logged: ids 7, 8, 9, 13, 14, 19, 20
   No soul wipe for id 17
   ```
   The record was not deliberately deleted by the user.

6. **A stale cooldown blocks first-time recruitment:**
   ```sql
   SELECT * FROM data_buckets WHERE `key` LIKE '%companion_cooldown%2032%';
   -- companion_cooldown_2032_6, expires 1773540118 (~11 minutes from now)
   ```
   This cooldown was set by a FAILED first-time recruitment roll today (since
   the re-recruitment track was unavailable due to the missing record).

### Why "I will not join you." Instead of Cooldown Message

The exact message flow:
1. Player says recruitment keyword to Lashun
2. `attempt_recruitment()` calls `check_existing_companion_record(2032, 6)` → returns nil
3. Falls to first-time recruitment track
4. On the FIRST attempt today, cooldown was not set yet
5. Full eligibility passes, persuasion roll fails
6. `_on_recruitment_failure()` says **"I will not join you."** and sets the cooldown
7. On subsequent attempts, the cooldown message ("won't discuss joining you again so soon") fires

---

## The Underlying Bug

This is **NOT a bug in the recruitment overhaul code**. The recruitment overhaul logic
is correct: `check_existing_companion_record()` queries for `is_dismissed=1 OR is_suspended=1`
and routes to the bypass track if found. Both the Lua and C++ paths are properly aligned.

The bug is in **companion death processing**: under certain conditions (possibly related
to entity cleanup timing, zone transitions, or level-up triggered reload), a companion's
entity can be invalidated (entity ID → 0) before `Death()` can properly save the
suspended state to the database. The companion_data record is then either:
- Never updated with `is_suspended=1` (Save() fails silently due to invalid state)
- Deleted by a cascading cleanup operation that runs on entities with ID 0

### Probable Scenario

The guktop zone log shows a level-up at 22:22:44 that reloaded spells (12 spells).
Between 22:22:44 and 22:32:09, the companion died in combat (the "wipe" the user
reported). During death processing, the entity was in a compromised state (entity
ID=0), causing `Companion::Death()` → `Save()` to either fail silently or write to
an invalid record. The death despawn timer, which would normally set `is_dismissed=1`
and `is_suspended=1`, also never fired because the entity was already removed from
the process loop.

---

## The Message "I will not join you."

**Source:** `companion.lua` line 545, inside `companion._on_recruitment_failure()`
**Code path:** First-time recruitment track → persuasion roll → failed roll

```lua
function companion._on_recruitment_failure(npc, client, cooldown_key)
    local cooldown_s = tonumber(eq.get_rule("Companions:RecruitCooldownS")) or 900
    eq.set_data(cooldown_key, "1", tostring(cooldown_s))
    npc:Say("I will not join you.")  -- line 545
end
```

This is the GENERIC failure message for a failed persuasion roll. It is NOT the
re-recruitment-specific code path.

---

## Database State Summary

| Check | Result |
|-------|--------|
| Lashun npc_type_id | 2032 (class=2, Cleric) |
| companion_data record | **MISSING** (id=17 was deleted) |
| companion_data flags | N/A (record gone) |
| data_buckets cooldown | `companion_cooldown_2032_6` active, expires ~22:01 UTC |
| SoulWipe logged? | NO — no soul wipe for id 17 |
| Last seen alive | 2026-03-13 22:22:44 in guktop (level 29) |
| Death event | 2026-03-13 22:32:09, entity id=0, HP=0 |

---

## Recommended Fix

### Immediate Fix (data recovery)

**Expert: data-expert**

Insert a new companion_data record for Lashun Novashine with reasonable defaults
based on the last known state from logs (level 29, class 2, race from npc_types).
Set `is_suspended=1, is_dismissed=1` so re-recruitment can find it. Also delete
the stale cooldown.

```sql
-- Delete stale cooldown
DELETE FROM data_buckets WHERE `key` = 'companion_cooldown_2032_6';

-- Insert recovery record for Lashun
INSERT INTO companion_data (
    owner_id, npc_type_id, name, companion_type, level, class_id, race_id,
    gender, zone_id, is_suspended, is_dismissed, stance, experience,
    recruited_level, total_kills, times_died
) VALUES (
    6, 2032, 'Lashun Novashine', 0, 29, 2, 1,
    0, 0, 1, 1, 1, 0, 2, 0, 1
);
```

Note: Equipment data (companion_inventories) for id=17 would also have been
deleted. The companion will need to be re-equipped after re-recruitment.

### Systemic Fix (prevent recurrence)

**Expert: c-expert**

The `Companion::Death()` method should be hardened against entity invalidation:

1. **Add entity ID validation at the top of Death():**
   If `GetID() == 0`, log a critical error and attempt an emergency Save()
   using only `m_companion_id` (which is stored independently of the entity ID).

2. **Ensure Save() does not silently fail:**
   If Save() returns false during Death(), log the error AND attempt a direct
   SQL UPDATE as a fallback to at least set `is_suspended=1`.

3. **Add a safety net in Process():**
   If a companion has HP=0 and `m_companion_id != 0` but `!m_suspended`,
   force-suspend and save. This catches the case where Death() partially failed.

4. **Consider a DB-level safeguard:**
   The companion_inventories and companion_data tables should have a
   `deleted_at` soft-delete column rather than hard DELETE, so records can
   be recovered if lost. (Lower priority, deferred.)

---

## Which Experts Should Implement

| Task | Expert | Priority |
|------|--------|----------|
| Data recovery (insert record, delete cooldown) | data-expert | Immediate |
| Harden Companion::Death() entity validation | c-expert | High |
| Add Save() failure fallback in Death() | c-expert | High |
| Add Process() safety net for HP=0 unsuspended | c-expert | Medium |
| Soft-delete for companion_data (deferred) | c-expert + data-expert | Low |
