# BUG-018: Equipment trade to companion produces duplicate items when replacing existing gear

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-03-11
> **Feature:** npc-companion-realistic-stats
> **Status:** Open

---

## Observed Behavior

When handing a piece of equipment to a companion NPC to replace an existing
piece in the same slot, the player receives TWO copies of the old item back
instead of one. This is an item duplication bug.

## Expected Behavior

When trading equipment to a companion that already has an item in that slot:
1. The old item should be returned to the player (one copy)
2. The new item should be equipped on the companion
3. No item duplication should occur

## Reproduction Steps

1. Recruit a companion
2. Give them a piece of equipment (e.g., a sword)
3. Give them a different piece of equipment for the same slot (e.g., a better sword)
4. Observe: two copies of the original sword are returned to the player

## Evidence

User observed duplicate items during in-game testing.

## Affected Systems

- [x] C++ server source -> c-expert (GiveItem / trade handling in companion.cpp)
- [ ] Lua quest scripts -> lua-expert
- [ ] Perl quest scripts -> perl-expert
- [ ] Database / SQL -> data-expert
- [ ] Rules / Configuration -> config-expert
- [ ] Client protocol -> protocol-agent
- [ ] Infrastructure / Docker -> infra-expert
