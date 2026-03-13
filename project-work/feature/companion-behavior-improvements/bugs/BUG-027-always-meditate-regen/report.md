# BUG-027: Companions should always regenerate mana at meditation rates

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-12
> **Feature:** companion-behavior-improvements
> **Status:** Open

---

## Observed Behavior

Companion casters only regenerate mana at meditation rates when actually
sitting/meditating. Managing sitting and standing for NPC companions during
combat is too complex and unfun. The current system requires the player to
micromanage companion sit/stand state which is not practical in a small-group
setting.

## Expected Behavior

NPC companions should ALWAYS regenerate mana at meditation-level rates,
whether standing, sitting, or in combat. This is an intentional departure
from authentic EQ behavior in favor of playability for the 1-3 player
small-group experience.

The user explicitly acknowledged this trades authenticity for fun:
"I know we are going for maximum authenticity, but there are thresholds of
complexity we just aren't going to be able to hit and still make this fun."

## Reproduction Steps

1. Recruit a caster companion
2. Observe their mana regeneration rate while standing/fighting
3. Compare to regeneration rate while sitting
4. Standing regen is much slower, making companions mana-starved in combat

## Evidence

User design decision based on gameplay experience.

## Affected Systems

- [x] C++ server source → c-expert (companion mana regen logic)
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [x] Rules / Configuration → config-expert (may need rule for regen multiplier)
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
