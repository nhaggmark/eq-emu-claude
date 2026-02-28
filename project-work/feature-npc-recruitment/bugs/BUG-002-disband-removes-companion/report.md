# BUG-002: Disbanding group removes companion NPCs

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-02-27
> **Feature:** feature-npc-recruitment
> **Status:** Resolved

---

## Observed Behavior

Clicking "Disband" in the Group Window removes companion NPCs from the
group. The companion is lost.

## Expected Behavior

Disbanding a group should remove all other players but keep recruited NPC
companions in the group. The only way to dismiss a companion should be
the explicit dismiss chat command. This protection must hold across:
- Group disband button clicks
- Login/logout sessions
- Zone transitions

A companion, once recruited, persists with the player until explicitly
dismissed.

## Reproduction Steps

1. Log in and recruit an NPC as a companion
2. Observe companion appears in group window
3. Click "Disband" in the Group Window
4. Observe: companion is removed from the group (BUG)

## Evidence

Commit `26056651d` previously attempted to add disband protection but the
issue persists. The companion should only be removable via the dismiss
chat command, never through the group disband UI.

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
