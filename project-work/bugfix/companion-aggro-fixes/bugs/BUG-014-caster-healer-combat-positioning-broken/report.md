# BUG-014: Caster and healer companions run into melee instead of staying at range

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-03-09
> **Feature:** companion-aggro-fixes
> **Status:** Open

---

## Observed Behavior

When combat begins, caster and healer companions do NOT hold at casting
range as designed. Instead:

- **Wizard**: "vanished" — ran off somewhere unknown, possibly fleeing or
  running to an extreme position
- **Cleric**: Ran directly at the mob and went into melee alongside the
  warrior
- **Warrior**: Ran directly at mob (correct behavior)
- **Rogue**: Circled behind mob for backstab (correct, but took a
  roundabout route)

Only the rogue's combat positioning worked. The caster/healer hold-at-range
behavior appears completely non-functional despite the code being in place.

## Expected Behavior

- Warrior: charge to melee range (working)
- Rogue: circle behind mob for backstab (working, route could be better)
- Wizard: stay at ~70 units from mob, nuke from range
- Cleric: stay at ~70 units from mob, heal from range
- Casters/healers should position between the player and the mob at
  casting range

## Investigation Needed

The combat positioning code exists in Companion::UpdateCombatPositioning()
with CASTER_DPS and HEALER roles. A deep dive is needed to determine why
these roles are not functioning:

1. Is UpdateCombatPositioning() actually being called for casters/healers?
2. Is the combat role correctly assigned (DetermineRoleFromClass)?
3. Is m_hold_combat_position being set and respected in mob_ai.cpp?
4. Is something else overriding the positioning (AI_Process pursue logic)?
5. Why did the wizard "vanish"? Is the distance calculation sending it
   to an extreme position?
6. Is the cleric's role being detected as HEALER or defaulting to melee?

## Reproduction Steps

1. Recruit warrior, rogue, wizard, cleric companions
2. Engage a mob
3. Observe: wizard vanishes, cleric runs into melee
4. Only warrior and rogue behave as expected

## Affected Systems

- [x] C++ server source -> c-expert
- [ ] Lua quest scripts -> lua-expert
- [ ] Perl quest scripts -> perl-expert
- [ ] Database / SQL -> data-expert
- [ ] Rules / Configuration -> config-expert
- [ ] Client protocol -> protocol-agent
- [ ] Infrastructure / Docker -> infra-expert
