# BUG-021: @all !assist produces stack trace error in console

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-03-11
> **Feature:** companion-group-commands
> **Status:** Open

---

## Observed Behavior

When the player targets a mob and uses `/gsay @all !assist`, an error with a
stack trace appears in the server console. The command fails to execute.

## Expected Behavior

All companions should attack the player's targeted mob. Companions in passive
stance should auto-switch to balanced before engaging.

## Reproduction Steps

1. Recruit companions into the group
2. Target a hostile mob
3. Type `/gsay @all !assist`
4. Observe: stack trace error in server console

## Evidence

User observed stack trace in console during in-game testing.

## Affected Systems

- [ ] C++ server source → c-expert
- [x] Lua quest scripts → lua-expert (companion.lua cmd_assist)
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
