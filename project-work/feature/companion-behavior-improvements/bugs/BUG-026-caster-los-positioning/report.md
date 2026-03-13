# BUG-026: Caster companions lose LOS when positioning at fixed distance from target

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-12
> **Feature:** companion-behavior-improvements
> **Status:** Open

---

## Observed Behavior

Caster companions try to move a fixed distance from their combat target. In
closed/indoor spaces this causes them to run around walls, behind corners,
or out of line of sight (LOS) of enemies. Once out of LOS they cannot cast
spells and stop contributing to the fight entirely.

## Expected Behavior

Casters should attempt to reach their preferred casting distance, but if
doing so would cause them to lose line of sight to the target, they should
stop at the closest viable position that maintains LOS. Staying in LOS and
contributing to the fight is more important than reaching the ideal distance.

## Reproduction Steps

1. Recruit a caster companion (cleric, wizard, etc.)
2. Engage a mob in an indoor zone or confined area (dungeon, building)
3. Observe the caster running around trying to reach fixed distance
4. Caster ends up behind a wall or around a corner, loses LOS, stops casting

## Evidence

User observed in-game during dungeon combat.

## Affected Systems

- [x] C++ server source → c-expert (companion AI caster positioning logic)
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
