# BUG-015: Companion ranged attack flags not set when bow/arrows equipped

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-10
> **Feature:** improved-companion-stats
> **Status:** Open

---

## Observed Behavior

When a player trades a bow and arrows to a companion (e.g., a Ranger),
the companion's `GiveItem()` function stores the items in equipment slots
but never calls `SetBowEquipped(true)` or `SetArrowEquipped(true)`. The
NPC AI checks `HasBowAndArrowEquipped()` to decide whether to perform
ranged attacks — since these flags are never set, the companion will not
do ranged attacks unless the NPC base type already has the
`SpecialAbility::RangedAttack` special ability.

The flags are normally set in `loot.cpp` during NPC loot item loading,
but companion equipment goes through a different code path (`GiveItem()`
/ `LoadEquipment()`) that bypasses this.

## Expected Behavior

When a companion receives a bow in the Range slot and arrows in the Ammo
slot, the ranged attack flags should be set so the AI triggers ranged
attacks appropriately. Ranger and other bow-using class companions should
fire arrows at targets when equipped with a bow.

## Reproduction Steps

1. Recruit a Ranger NPC companion
2. Trade a bow to the companion (Range slot)
3. Trade arrows to the companion (Ammo slot)
4. Engage in combat
5. Observe: companion does melee attacks only, never fires arrows

## Affected Systems

- [x] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
