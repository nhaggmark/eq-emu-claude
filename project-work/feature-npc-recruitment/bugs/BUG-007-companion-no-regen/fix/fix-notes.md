# BUG-007: Fix Notes

## Commit

`08095c20a` on branch `feature/npc-recruitment`

## What Was Changed

**File:** `eqemu/zone/entity.cpp`
**Function:** `EntityList::RemoveFromHateLists(Mob *mob, bool settoone)`

Added a second loop after the existing `npc_list` loop to also process
`companion_list`:

```cpp
// Companions are stored in companion_list, not npc_list, so they must be
// processed separately. Without this, a dead enemy stays on the companion's
// hate list for up to 10 minutes (RemoveStaleEntries timeout), keeping
// IsEngaged() true and blocking OOC HP regeneration after combat ends.
auto cit = companion_list.begin();
while (cit != companion_list.end()) {
    if (cit->second->CheckAggro(mob)) {
        if (!settoone) {
            cit->second->RemoveFromHateList(mob);
        } else {
            cit->second->SetHateAmountOnEnt(mob, 1);
        }
    }
    ++cit;
}
```

No other files changed. No new functions or headers needed — `companion.h` was
already included in `entity.cpp`.

## Why This Fix Works

1. Enemy NPC dies -> `EntityList::RemoveFromHateLists(dead_npc)` is called
2. New loop clears the dead NPC from any companion's hate list
3. `Mob::RemoveFromHateList()` fires `AI_Event_NoLongerEngaged()` when the
   hate list becomes empty
4. `IsEngaged()` returns false on next tic
5. `NPC::Process()` regen block enters OOC path:
   `SetHP(GetHP() + npc_regen + npc_sitting_regen_bonus)`
   where `npc_regen = max(npc_hp_regen, ooc_regen_calc)` and
   `ooc_regen_calc = GetMaxHP() * ooc_regen / 100` (5% by default)

## What Was NOT Changed

- `CalcHPRegen()`, `hp_regen` seeding, and `ooc_regen` seeding (added in BUG-006
  commit a1a7d605d) are correct and required — this fix completes that work
- Rules `Companions::HPRegenPerTic` (1) and `Companions::OOCRegenPct` (5)
  remain unchanged
- `NPC::Process()` regen logic unchanged — we fix the precondition instead

## Secondary Issue (Not Fixed — Low Priority)

`eqemu/zone/entity.cpp:571` calls `entity_list.RemoveNPC(id)` when a companion
is removed, but companions are not in `npc_list`. `RemoveNPC` silently no-ops on
the missing key. This is not a bug but is misleading; defer for cleanup.

## How to Test

1. Recruit a companion with a low HP NPC (or reduce HP in-game)
2. Kill one or more enemies
3. After combat: companion should regen at OOC rate (5% max HP per 6-second tic)
4. During combat: companion should regen at floor rate (1 HP/tic minimum)
5. Verify no in-combat regen boost (companion should stay at combat rate until
   the last enemy on the hate list is dead/removed)
