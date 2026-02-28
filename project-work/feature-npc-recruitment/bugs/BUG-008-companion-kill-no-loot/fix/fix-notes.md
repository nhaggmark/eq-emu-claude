# BUG-008: Fix Notes

## File Changed

`eqemu/zone/attack.cpp`

## Changes

### 1. Include companion.h

Added `#include "zone/companion.h"` after `#include "zone/bot.h"` (~line 27)
so that `CastToCompanion()` and `GetCompanionOwner()` are available.

### 2. Corpse creation gate — add IsCompanion() (attack.cpp ~line 2799)

```cpp
// Before:
killer->IsClient() ||
(
    killer->HasOwner() &&
    killer->GetUltimateOwner()->IsClient()
) || ...

// After:
killer->IsClient() ||
killer->IsCompanion() ||
(
    killer->HasOwner() &&
    killer->GetUltimateOwner()->IsClient()
) || ...
```

This ensures the corpse is created when a companion delivers the killing blow.

### 3. Killer reassignment — resolve companion to owner client (attack.cpp ~line 2824)

```cpp
if (killer) {
    if (killer->GetOwner() != 0 && killer->GetOwner()->IsClient()) {
        killer = killer->GetOwner();
    }

    // NEW: Companion kills: resolve killer to the companion's owner client so
    // loot rights are granted to the player, matching Bot/Merc behaviour.
    if (killer->IsCompanion()) {
        Client* comp_owner = killer->CastToCompanion()->GetCompanionOwner();
        if (comp_owner) {
            killer = comp_owner;
        }
    }

    if (killer->IsClient() && !killer->CastToClient()->GetGM()) {
        CheckTrivialMinMaxLevelDrop(killer);
    }
}
```

After this reassignment `killer` is the owning Client, so:
- `CheckTrivialMinMaxLevelDrop(killer)` runs correctly
- `corpse->AllowPlayerLoot(killer, 0)` grants loot rights to the owner
- `killer->IsGrouped()` / `killer->IsRaidGrouped()` correctly grants rights to
  the entire group/raid

## Why This Is Correct

The Companion class uses `m_owner_char_id` and `GetCompanionOwner()` for
ownership — it does NOT use the NPC pet system (`petid`/`SetOwnerID`). So we
cannot use `HasOwner()` / `GetUltimateOwner()` to walk up to the owner. The
explicit `IsCompanion()` check mirrors exactly what the existing
`GetOwner()->IsClient()` path does for pets and bots.

## Testing

1. Recruit a companion
2. Engage an enemy and let the companion get the killing blow
3. Verify: enemy corpse appears with normal decay timer
4. Verify: you can right-click the corpse and see the loot window
5. If grouped: verify group members can also loot the corpse

## Commit

See branch `feature/npc-recruitment` in `eqemu/`
