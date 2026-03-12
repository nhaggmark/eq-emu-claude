# BUG-020: Companion NPCs cast buffs while sitting/meditating

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-11
> **Feature:** companion-group-commands
> **Status:** Open

---

## Observed Behavior

When the player and companions are all sitting and meditating, caster
companions continue to cast buff spells. They should not be casting any
spells while in a sitting/meditating state.

## Expected Behavior

When a companion is sitting (meditating), they should NOT cast any spells.
Spell casting should only occur while standing. The newly added IsSitting()
Lua binding can now be used to gate spell casting behavior.

## Reproduction Steps

1. Recruit caster companions (cleric, wizard, shaman, etc.)
2. Sit down to meditate with the group
3. Observe companions casting buff spells while sitting

## Evidence

User observed in-game during testing of companion-group-commands feature.

## Affected Systems

- [x] C++ server source → c-expert (companion AI spell casting logic)
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
