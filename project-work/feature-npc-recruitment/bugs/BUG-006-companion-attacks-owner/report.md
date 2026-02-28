# BUG-006: Companion attacks owner when player targets self

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-02-28
> **Feature:** feature-npc-recruitment
> **Status:** Open

---

## Observed Behavior

When the player targets themselves, their companion attacks them. The
companion should never be able to attack its owner under any circumstances.

## Expected Behavior

The companion should never add its owner to its hate list or attack them.
Owner targeting (self-targeting for buffs, inspecting, etc.) is common
gameplay and must not trigger companion aggression.

## Reproduction Steps

1. Log in with an active companion
2. Target yourself (click your own name or press F1)
3. Observe: companion begins attacking you

## Likely Cause

BUG-005 Fix 2 added `AddToHateList(owner_target, 1)` in the combat assist
code. If the owner's target is the owner themselves, the companion adds the
owner to its hate list and attacks.

## Affected Systems

- [x] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
