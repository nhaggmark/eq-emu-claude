# BUG-023: Rogue companion takes too wide a circle to get behind enemies

> **Severity:** Medium
> **Reported by:** user
> **Date:** 2026-03-12
> **Feature:** companion-behavior-improvements
> **Status:** Open

---

## Observed Behavior

The rogue companion takes a very wide circular path around enemies to get
behind them for backstab positioning. This causes them to get stuck on
geometry and walls. The pathing arc is unnecessarily large.

## Expected Behavior

The rogue should take a more direct line to get behind the enemy. They should
position themselves a step or two behind the mob (not on the exact same spot
as the mob) so they don't have to shift as much once in position.

## Reproduction Steps

1. Recruit a rogue companion
2. Engage a mob in combat
3. Observe the rogue's movement path — they take a wide sweeping circle
4. In confined areas, they get stuck on geometry

## Evidence

User observed in-game during combat testing.

## Affected Systems

- [x] C++ server source → c-expert (companion AI positioning / backstab logic)
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
