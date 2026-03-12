# BUG-022: !tome command does not move companions to player location

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-11
> **Feature:** companion-group-commands
> **Status:** Open

---

## Observed Behavior

When the player uses `/gsay @all !tome`, nothing happens. Companions do not
move to the player's location.

## Expected Behavior

All addressed companions should run to the player's current location. If a
companion is already within 50 units, they should skip movement.

## Reproduction Steps

1. Recruit companions into the group
2. Move away from companions so there is visible distance
3. Type `/gsay @all !tome`
4. Observe: companions do not move

## Evidence

User observed in-game — no companion movement after issuing !tome command.

## Affected Systems

- [ ] C++ server source → c-expert
- [x] Lua quest scripts → lua-expert (companion.lua cmd_tome)
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
