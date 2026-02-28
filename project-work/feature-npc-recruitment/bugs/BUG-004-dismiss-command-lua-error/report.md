# BUG-004: Dismiss command produces Lua error

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-02-28
> **Feature:** feature-npc-recruitment
> **Status:** Open

---

## Observed Behavior

Saying "dismiss" to a companion NPC produces a Lua console error instead of
dismissing the companion. The dismiss command does not work.

## Expected Behavior

Saying "dismiss" to a recruited companion should dismiss them, removing them
from the group and marking them as dismissed in the database.

## Reproduction Steps

1. Log in with an active companion (e.g. Guard Simkin)
2. Target the companion
3. Say "dismiss"
4. Observe: Lua error in console, companion is NOT dismissed

## Evidence

User reports Lua console error visible in-game.

## Affected Systems

- [ ] C++ server source → c-expert
- [x] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
