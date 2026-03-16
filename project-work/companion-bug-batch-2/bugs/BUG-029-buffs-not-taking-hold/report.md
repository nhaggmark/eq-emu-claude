# BUG-029: Buffs not taking hold on NPC companions

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-15
> **Feature:** companion-bug-batch-2
> **Status:** Open

---

## Observed Behavior

Not all player buffs work on NPC companions. In some cases (e.g., Alacrity), the message "The spell did not take hold" appears. Buffs and buff mechanics should work on NPC companions exactly as they do for real player group members.

## Expected Behavior

All buffs that can be cast on a player group member should work identically on NPC companions — stat bonuses, haste, resist buffs, HP buffs, etc. should all apply with the same mechanics.

## Reproduction Steps

1. Have an NPC companion in group
2. Cast Alacrity on the companion
3. Observe "The spell did not take hold" message
4. Other buffs may also be affected

## Investigation Needed

- Audit how buffs are applied to companions vs players
- Check for NPC-specific buff restrictions that shouldn't apply to companions
- Check buff stacking logic — is the "did not take hold" message from a stacking conflict or a target restriction?
- Ensure stat bonuses from buffs actually apply (CalcBonuses recalculation)
- Comprehensive audit of buff mechanics on companions

## Affected Systems

- [x] C++ server source → c-expert
- [x] Lua quest scripts → lua-expert
- [ ] Database / SQL → data-expert
