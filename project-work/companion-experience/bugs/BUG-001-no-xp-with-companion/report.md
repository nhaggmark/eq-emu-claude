# BUG-001: No Experience Gain When Companion Deals Killing Blow

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-03-05
> **Feature:** companion-experience
> **Status:** Open

---

## Observed Behavior

When a recruited NPC companion is in the player's group and the companion
deals the killing blow to a mob, the player does not receive any experience.
Loot was also initially broken in the same scenario (since fixed), suggesting
that post-death hooks are not firing correctly when a companion NPC lands
the kill.

## Expected Behavior

When the companion deals the killing blow, the kill should trigger the same
post-death hooks as a normal group kill:
- Player receives shared experience (standard group XP split)
- Companion tracks XP toward leveling up (same progression as the player)
- All post-death events (loot, quest credit, etc.) fire normally

## Reproduction Steps

1. Log in with a character
2. Recruit an NPC companion into the group
3. Engage and kill mobs, allowing the companion to deal killing blows
4. Observe that no experience is gained by the player

## Evidence

User reports XP works normally without a companion. The issue is specific
to the companion group scenario, particularly when the NPC lands the kill.
Loot had the same class of issue (post-death hooks not triggering) and was
previously fixed.

## Affected Systems

- [x] C++ server source -> c-expert (post-death hooks, XP distribution, group mechanics)
- [ ] Lua quest scripts -> lua-expert
- [ ] Perl quest scripts -> perl-expert
- [ ] Database / SQL -> data-expert
- [ ] Rules / Configuration -> config-expert
- [ ] Client protocol -> protocol-agent
- [ ] Infrastructure / Docker -> infra-expert
