# BUG-028 Fix Notes: Companion::Death() Hardening

**Author:** c-expert
**Date:** 2026-03-14
**Branch:** master (hotfix)

---

## Problem Summary

During a guktop death event on 2026-03-13 at ~22:32, the companion entity's
ID had already become 0 when `Companion::Death()` processed. This caused
`Save()` (which calls the ORM repository) to produce an UPDATE that may have
silently failed or targeted a stale record, resulting in the companion_data
row being deleted or corrupted. The player could no longer re-recruit because
the two-track recruitment system found no record for npc_type_id=2032.

See `investigation.md` for the full evidence chain.

---

## What Was Changed

### `eqemu/zone/companion.cpp`

#### Fix 1: Hardened `Companion::Death()`

**Location:** `Companion::Death()`, in the block that calls `SetSuspended(true)`
and `Save()`.

**Before:** The method always called `Save()` via the ORM path. If the entity
ID was 0, `Save()` could use stale entity state (GetX/GetY/GetZ/GetID all
return garbage for a zero-ID entity). If Save() failed, it logged an error
but the companion_data record was left in an indeterminate state.

**After:** Added an entity ID validation guard at the top of the death save
block:

```cpp
if (GetID() == 0 && m_companion_id > 0) {
    // Entity is in invalid state — use direct SQL fallback to guarantee
    // is_suspended=1 is written to the DB regardless of ORM state.
    LogWarning("Companion [{}] Death() with entity id=0 — using direct SQL fallback to save suspended state (companion_id={})",
               GetCleanName(), m_companion_id);
    std::string query = fmt::format(
        "UPDATE `companion_data` SET `is_suspended`=1, `times_died`=`times_died`+1 WHERE `id`={} LIMIT 1",
        m_companion_id);
    database.QueryDatabase(query);
} else {
    // Normal path: entity is valid
    SetSuspended(true);
    m_times_died++;
    UpdateTimeActive();
    SaveEquipment();
    if (!Save()) {
        // ORM path failed — emergency direct SQL as final fallback
        if (m_companion_id > 0) {
            LogWarning("Companion [{}] Death() Save() failed — using direct SQL fallback (companion_id={})",
                       GetCleanName(), m_companion_id);
            std::string query = fmt::format(
                "UPDATE `companion_data` SET `is_suspended`=1, `times_died`=`times_died`+1 WHERE `id`={} LIMIT 1",
                m_companion_id);
            database.QueryDatabase(query);
        }
    }
}
```

This ensures `is_suspended=1` is written even when the entity is corrupted.
The key insight: `m_companion_id` is a simple integer member that survives
entity list corruption — it is not derived from entity state.

#### Fix 2: Safety net in `Companion::Process()`

**Location:** `Companion::Process()`, at the very top (before the
`m_death_despawn_timer` check).

**Before:** No check for HP=0 + not-suspended state.

**After:** Added a guard:

```cpp
// Safety net: if HP has dropped to zero but we were not properly
// suspended (e.g. Death() ran with a corrupted entity ID), force
// a DB save now to guarantee the companion_data record is preserved.
if (GetHP() <= 0 && !m_suspended && m_companion_id > 0) {
    LogWarning("Companion [{}] Process(): HP=0 but not suspended — forcing emergency save (companion_id={})",
               GetCleanName(), m_companion_id);
    SetSuspended(true);
    m_times_died++;
    UpdateTimeActive();
    std::string query = fmt::format(
        "UPDATE `companion_data` SET `is_suspended`=1, `times_died`=`times_died`+1 WHERE `id`={} LIMIT 1",
        m_companion_id);
    database.QueryDatabase(query);
}
```

This catches the window between HP hitting 0 and `Death()` being called, or
when `Death()` itself ran in a compromised state.

---

## Tests Added

**Suite 21: BUG-028 Death Hardening** in `cli_companion_tests.cpp`

Tests cover:
- 21.1: Companion with `m_companion_id=0` — Save() should insert and return id > 0
- 21.2: After Death() logic with valid entity, `IsSuspended()` must be true
- 21.3: After Death() logic with valid entity, `m_times_died` increments
- 21.4: Direct SQL fallback path — companion with a saved record survives entity-id=0 death
- 21.5: Process() safety net — companion with HP=0 and not suspended gets force-suspended

---

## Root Cause

The root cause is that `Companion::Death()` only had one Save() path: the ORM
`CompanionDataRepository::UpdateOne()` path, which uses entity state (GetX,
GetY, GetZ, GetID) to build the record. When the entity ID is 0, these
accessors return stale or garbage values, and the UPDATE may fail silently
(wrong row, constraint violation, or no-op).

The fix adds two fallback layers:
1. A pre-check at the top of Death() — if entity ID is already 0, skip the
   full ORM write and do a targeted `UPDATE ... WHERE id=m_companion_id`.
2. A post-check on ORM failure — if Save() returns false, use the same
   targeted UPDATE as a last resort.
3. A Process() guard — if we somehow enter a tick with HP=0 and not suspended,
   write the suspended state before the entity is removed.

---

## Testing Command

```bash
docker exec akk-stack-eqemu-server-1 bash -c \
  "cd /home/eqemu/server && ./bin/zone tests:companion 2>&1" | grep -E 'Suite 21|PASS|FAIL|BUG-028'
```
