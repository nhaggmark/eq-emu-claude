# BUG-003 Fix: Companion Lost on Relog

**Fixed by:** c-expert
**Date:** 2026-02-27
**Branch:** feature-npc-recruitment

---

## Root Cause

Companions were saved with `is_suspended = 1` during logout because the only
save path went through `DisbandGroup()` -> `Suspend()`. On re-login,
`SpawnCompanionsOnZone()` skips rows where `is_suspended = 1`, so companions
were never restored.

Additionally, the three client lifecycle paths (camp, disconnect, zone change)
had NO explicit companion save/depop calls, unlike Mercs and Bots which are
explicitly handled in each path.

## 4-Part Fix

### 1. Camp timer (`client_process.cpp` line ~210)

Added companion Zone() calls after the Merc save/depop block inside the
`camp_timer.Check()` handler. This mirrors the Merc pattern:

```cpp
if (RuleB(Companions, CompanionsEnabled)) {
    auto companions = entity_list.GetCompanionsByOwnerCharacterID(CharacterID());
    for (auto* comp : companions) {
        comp->Zone();
    }
}
```

### 2. Hard disconnect (`client_process.cpp` line ~712)

Added the same pattern inside `OnDisconnect(true)`, after the Merc save/depop.
This covers client crash, linkdead timeout, and kick paths.

### 3. Zone change (`zoning.cpp` line ~45)

Added companion Zone() iteration after the `Bot::ProcessClientZoneChange()`
call in `Handle_OP_ZoneChange`. This ensures companions are saved (with current
HP, mana, XP, kill history) and depoped when the owner zones, so
`SpawnCompanionsOnZone()` restores them in the destination zone.

### 4. DisbandGroup safety net (`groups.cpp` line ~962)

Changed the BUG-002 safety net from `comp->Suspend()` to `comp->Zone()`. This
is the critical change: `Suspend()` sets `is_suspended = 1` before saving,
while `Zone()` leaves `m_suspended` as `false` (its default), so the DB record
gets `is_suspended = 0`.

## Why Zone() Instead of Suspend()

- `Suspend()` calls `SetSuspended(true)` then `Save()` -> writes `is_suspended = 1`
- `Zone()` calls `Save()` directly -> writes `is_suspended = 0` (m_suspended default is false)
- `SpawnCompanionsOnZone()` skips rows where `is_suspended = 1`
- Therefore `Zone()` is the correct call for all save-on-exit scenarios

## Files Modified

| File | Change |
|------|--------|
| `zone/client_process.cpp` | Added `#include "companion.h"`. Added companion Zone() to camp_timer and OnDisconnect blocks |
| `zone/zoning.cpp` | Added `#include "zone/companion.h"`. Added companion Zone() iteration in Handle_OP_ZoneChange |
| `zone/groups.cpp` | Changed DisbandGroup companion safety net from Suspend() to Zone() |

## What Was NOT Changed

- `SpawnCompanionsOnZone()` -- the load path is correct as-is
- `Companion::Save()`, `Zone()`, `Suspend()` methods -- they work correctly
- `Companion::Depop()` -- already correct
- No new methods were created; all helpers already existed

## Testing Notes

After applying this fix and rebuilding, the following scenarios should work:

1. **Normal /camp**: Companion should reappear on next login
2. **GM fast camp**: Same as above
3. **Client crash/linkdead**: Companion saved and restored on reconnect
4. **Zone transition**: Companion saved with current state, respawned in new zone
5. **Group disband on logout**: Companion saved with is_suspended=0

Verify by checking `companion_data` table: all active companions should have
`is_suspended = 0` after any of these logout/zone scenarios.
