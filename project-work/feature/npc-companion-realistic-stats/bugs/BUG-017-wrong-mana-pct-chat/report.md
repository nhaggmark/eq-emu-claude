# BUG-017: Companion caster mana percentage chat messages show wrong values

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-11
> **Feature:** npc-companion-realistic-stats
> **Status:** Open

---

## Observed Behavior

Companion casters chat their mana percentage in two contexts:
1. When casting spells in combat (e.g., "Casting Greater Heal... [42% mana]")
2. When sitting/meditating with the player (e.g., "Meditating... [65% mana]")

Both mana percentage values are now incorrect after the Phase 3-5 stat
computation changes. The displayed percentage does not reflect the companion's
actual mana ratio based on updated max mana calculations.

## Expected Behavior

The mana percentage displayed in chat should accurately reflect the companion's
current mana as a percentage of their actual max mana (including all bonuses
from items, spells, and stat conversions).

## Reproduction Steps

1. Recruit a caster companion (cleric, wizard, shaman, etc.)
2. Equip them with INT/WIS gear that increases max mana
3. Engage in combat and observe their casting chat messages
4. Sit with them and observe their meditation chat messages
5. Compare the reported percentage against actual mana/maxmana

## Evidence

User observed incorrect percentages during in-game testing of
npc-companion-realistic-stats feature.

## Affected Systems

- [x] C++ server source -> c-expert
- [x] Lua quest scripts -> lua-expert (chat messages may originate from Lua)
- [ ] Perl quest scripts -> perl-expert
- [ ] Database / SQL -> data-expert
- [ ] Rules / Configuration -> config-expert
- [ ] Client protocol -> protocol-agent
- [ ] Infrastructure / Docker -> infra-expert
