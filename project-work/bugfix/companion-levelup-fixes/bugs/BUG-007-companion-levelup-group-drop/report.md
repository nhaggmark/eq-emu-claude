# BUG-007: Companion disappears from group interface on level up

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-03-08
> **Feature:** companion-levelup-fixes
> **Status:** Fix deployed, pending validation

---

## Observed Behavior

When a recruited NPC companion levels up, they disappear from the group
interface. The level-up process disrupts the group membership.

## Expected Behavior

Leveling up should be a graceful process that does not disrupt:
- Group membership (companion stays in group)
- Group interface display
- Equipped gear
- Companion stance and AI settings
- Any other companion state

## Reproduction Steps

1. Recruit an NPC companion into group
2. Engage in combat until the companion levels up
3. Observe: companion disappears from the group interface

## Evidence

User reported during companion-ai-stances testing.

## Affected Systems

- [x] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [x] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
