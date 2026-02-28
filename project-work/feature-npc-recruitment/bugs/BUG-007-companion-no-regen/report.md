# BUG-007: Companion does not regenerate health after combat

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-02-28
> **Feature:** feature-npc-recruitment
> **Status:** Open

---

## Observed Behavior

After taking damage in combat, the companion's health does not regenerate.
The player observed the companion's HP remaining static for an extended
period after combat ended.

## Expected Behavior

Companions should regenerate HP out of combat, similar to other NPCs, pets,
mercs, or bots. The regeneration rate should be reasonable — not instant,
but visible over time.

## Reproduction Steps

1. Log in with an active companion
2. Engage in combat — companion takes damage
3. End combat (kill the mob or flee)
4. Watch companion's HP bar over the next 30-60 seconds
5. Observe: HP does not increase

## Affected Systems

- [x] C++ server source → c-expert (NPC regen, companion HP processing)
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
