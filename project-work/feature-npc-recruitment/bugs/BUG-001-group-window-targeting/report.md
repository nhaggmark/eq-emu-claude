# BUG-001: Clicking companion in group window does not target them

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-02-27
> **Feature:** feature-npc-recruitment
> **Status:** Resolved

---

## Observed Behavior

After successfully recruiting an NPC companion into the group, clicking on
the companion's name tile in the Group Window does nothing. The companion
is not targeted.

## Expected Behavior

Clicking on a companion's name in the Group Window should target that
companion, just like clicking on any other group member's name. This is
essential for directing heals, buffs, and other targeted spells at the
companion.

## Reproduction Steps

1. Log in and find an eligible NPC
2. Successfully recruit the NPC as a companion
3. Observe the companion appears in the Group Window
4. Click on the companion's name tile in the Group Window
5. Observe: nothing happens — the companion is not targeted

## Evidence

Observed during in-game testing of the npc-recruitment feature (Test #4
area — companion in group). Note: commit `26056651d` previously attempted
to fix group window targeting by stripping MakeNameUnique suffixes, but
the issue persists.

## Affected Systems

_Check all that apply. These determine which expert agents are assigned
during triage._

- [x] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [x] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
