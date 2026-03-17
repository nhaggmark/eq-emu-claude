# BUG-034: Companion mana regen significantly slower than player's

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-16
> **Feature:** companion-bug-batch-3
> **Status:** Open

---

## Observed Behavior

NPC companion mana regeneration is much slower than the player's, even when the companion has Clarity (enchanter mana regen buff) cast on them. The mana regen does not seem to scale with companion level appropriately. Something is still not working correctly for companion mana regen to behave like a player's.

## Expected Behavior

Companion mana regen should be comparable to a player's at the same level with the same buffs. With the AlwaysMeditateRegen rule enabled, companions should regen at meditation rates. With Clarity on top of that, regen should be substantial.

## Reproduction Steps

1. Have a caster companion in group
2. Cast Clarity on the companion
3. Observe mana regen rate vs player mana regen rate
4. Companion regen is significantly slower

## Investigation Needed

- The AlwaysMeditateRegen rule should give companions meditation-rate regen — is it actually working?
- Is Clarity's mana regen bonus (SPA) actually being applied to companions?
- Is SkillMeditate still zero despite the GAP-15 fix? (SetDefensiveSkillsFromCaps was supposed to set it)
- Is CalcManaRegen() using the right formula for companions?
- Compare the actual mana/tick rate for a companion vs a player at the same level with the same buffs
- Could the Clarity buff itself not be applying correctly (related to BUG-029 buff fix)?

## Affected Systems

- [x] C++ server source → c-expert
