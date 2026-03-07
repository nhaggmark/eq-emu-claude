# BUG-002: Companion combat hits not shown in "Other's Hit" windows

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-07
> **Feature:** companion-equipment
> **Status:** Open

---

## Observed Behavior

NPC companion damage dealt and damage received does not appear in the
player's "other people's hits" and "other people being hit" chat windows.
Companion combat is invisible to the owner in these filtered channels.

## Expected Behavior

When a recruited companion hits a mob or is hit by a mob, the damage
messages should appear in the player's "other people's hits" and "other
people being hit" windows, just like they would for any other group member.

## Reproduction Steps

1. Recruit an NPC companion into group
2. Equip companion with a weapon
3. Engage a mob in combat with companion attacking
4. Check the "other people's hits" chat window — companion hits are missing
5. Check the "other people being hit" chat window — companion damage taken is missing

## Evidence

User reported during companion-equipment feature testing.

## Affected Systems

- [x] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [x] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
