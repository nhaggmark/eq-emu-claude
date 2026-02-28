# BUG-008: Diagnosis — c-expert

## Root Cause

`Mob::Death()` in `zone/attack.cpp` determines whether to create a lootable
player corpse based on two checks:

### Check 1: Corpse creation gate (attack.cpp ~line 2789)

```cpp
if (
    (
        !HasOwner() &&
        !IsMerc() &&
        !GetSwarmInfo() &&
        (!is_merchant || allow_merchant_corpse) &&
        (
            killer->IsClient() ||
            /* killer->IsCompanion() — MISSING */
            (killer->HasOwner() && killer->GetUltimateOwner()->IsClient()) ||
            (killer swarm owner is client)
        )
    )
    || IsQueuedForCorpse()
)
```

The `Companion` class does NOT use the NPC pet-owner system (`petid` /
`SetOwnerID` / `GetOwner()`). It stores ownership via `m_owner_char_id` and
`GetCompanionOwner()` which does an `entity_list` lookup by char ID. Because
the companion has no `petid`, `HasOwner()` returns false and
`GetUltimateOwner()` returns `this`.

As a result: when a companion is the killer, none of the three inner conditions
are satisfied, the gate fails, and **no corpse is created at all** — the enemy
simply depops as if it were an NPC-on-NPC kill.

### Check 2: Loot rights assignment (attack.cpp ~line 2820)

```cpp
if (killer->GetOwner() != 0 && killer->GetOwner()->IsClient()) {
    killer = killer->GetOwner();
}
// Then: if (killer && killer->IsClient()) AllowPlayerLoot(killer, ...)
```

Even if the corpse were created, this block would not reassign `killer` to the
owner client (no `GetOwner()` in the companion), so the corpse would have no
loot rights.

## How Bots and Mercs Work

- **Bots:** Bot overrides `IsOfClientBot()` and uses the `petid` system via
  `SetOwnerID`, so `HasOwner()` returns true and `GetUltimateOwner()` chains up
  to the owning client. The bot owner client is resolved by
  `killer->GetOwner()->IsClient()` check at line 2820.

- **Mercs:** Merc overrides `GetOwner()` to use `GetOwnerID()` similarly.
  `!IsMerc()` at the gate refers to `this` (the dying mob), not the killer —
  it means we don't create player-lootable corpses for dead Mercs.

## Summary

Two lines are missing:
1. `killer->IsCompanion()` in the corpse creation gate (so the corpse exists)
2. Companion owner resolution in the killer reassignment block (so loot rights
   are granted to the player and their group)
