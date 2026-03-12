# BUG-019: Wizard companion spams damage shield (O'Keils Embers) out of combat

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-11
> **Feature:** companion-group-commands
> **Status:** Open

---

## Observed Behavior

The Wizard companion continuously casts O'Keils Embers (damage shield) out of
combat, burning through their mana pool. The spell is being cast indiscriminately
rather than only during combat and only on melee group members.

## Expected Behavior

Damage shields should ONLY be cast:
1. During combat (not out of combat)
2. On melee group members only (not on casters)

This was previously addressed in the npc-companion-realistic-stats feature
(AI_WizardBuff audit fix — DS only on melee during combat). The behavior
appears to have regressed or not carried over.

## Reproduction Steps

1. Recruit a Wizard companion
2. Form a group with other companions
3. Observe the Wizard out of combat
4. Wizard continuously casts O'Keils Embers, draining mana

## Evidence

User observed in-game during testing of companion-group-commands feature.

## Affected Systems

- [x] C++ server source → c-expert (companion_ai.cpp AI_WizardBuff logic)
- [x] Lua quest scripts → lua-expert (companion spell AI if any Lua-side logic)
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
