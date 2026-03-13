# BUG-024: Caster companions should announce LOM (Low On Mana) in group chat

> **Severity:** Medium
> **Reported by:** user
> **Date:** 2026-03-12
> **Feature:** companion-behavior-improvements
> **Status:** Open

---

## Observed Behavior

Caster companions do not announce when they are low on mana. The player has
no way to know when their casters are running dry without checking !status
on each one individually.

## Expected Behavior

All caster companions should announce "LOM" (Low On Mana) via group chat
when their mana drops to 15% or below. This mirrors real EQ player behavior
where casters would type "LOM" in group chat to signal they need to sit
and meditate.

## Reproduction Steps

1. Recruit caster companions (cleric, wizard, shaman, etc.)
2. Engage in extended combat until casters burn through mana
3. Observe: no LOM announcement in group chat

## Evidence

User observed in-game — casters silently run out of mana.

## Affected Systems

- [x] C++ server source → c-expert (companion AI mana monitoring)
- [x] Lua quest scripts → lua-expert (group chat message)
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
