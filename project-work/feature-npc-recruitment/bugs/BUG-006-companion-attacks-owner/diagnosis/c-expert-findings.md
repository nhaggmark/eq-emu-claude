# BUG-006 C++ Diagnosis Findings

**Expert:** c-expert
**Date:** 2026-02-28
**Status:** Root cause confirmed and fixed

---

## Root Cause

BUG-005 Fix 2 (commit `392bfcf42`) rewrote the combat assist block in
`Companion::Process()` to use `AddToHateList(owner_target, 1)`. The code
immediately before the `AddToHateList` call was:

```cpp
// BUG-005 state — no owner_target == owner guard
Mob* owner_target = owner->GetTarget();
if (owner_target && IsAttackAllowed(owner_target)) {
    if (!IsEngaged() || GetTarget() == nullptr) {
        AddToHateList(owner_target, 1);   // ← called with owner_target == owner
        SetTarget(owner_target);
    }
}
```

`IsAttackAllowed(Mob* target)` checks faction relationships, team membership,
and PvP flags — but it does **not** have an explicit fast-path check for
`target == this->GetOwner()`. In normal gameplay `IsAttackAllowed(owner)`
returns false because the companion and owner are on the same team. However,
the check is not guaranteed in all edge cases (e.g. faction misconfiguration,
charmed/confused states, or future code paths that bypass it).

More critically, `IsAttackAllowed` returning false only prevents the `AddToHateList`
call if it returns false. There was no guard preventing the companion from being
directed to add its owner to the hate list through any **other** code path
(e.g., spells that call `AddToHateList` internally, or `SpellFinished` targeting).

## Code Path Analysis

1. Player presses F1 → `owner->GetTarget()` returns the owner (`Client*`)
2. `owner_target` is non-null, and in some configs `IsAttackAllowed(owner)` returns true
3. `AddToHateList(owner, 1)` is called — owner is now on the companion's hate list
4. On the next combat AI tick, `IsEngaged()` returns true (hate list is non-empty)
5. `Mob::AI_Process()` selects the highest-hate target → the owner
6. `NPC::Attack()` is called with the owner as target → companion strikes the player

## Files Investigated

- `eqemu/zone/companion.cpp` — `Companion::Process()` lines 472-510, `Companion::Attack()` lines 363-390
- `eqemu/zone/mob_ai.cpp` — `Mob::AI_Process()` to understand hate-list-to-attack flow
- `eqemu/zone/hate_list.h` / `eqemu/zone/hate_list.cpp` — `HateList` structure
- `eqemu/zone/mob.h` — `IsAttackAllowed()`, `RemoveFromHateList()` declarations (line 763)
- `eqemu/zone/companion.h` — `GetCompanionOwner()` (line 249), `GetOwnerCharacterID()` (line 250)

## Related Companion AI File (`companion_ai.cpp`)

Reviewed `AI_NukeTarget()`, `AI_SlowDebuff()`, and all class handlers. None of
them directly call `AddToHateList` — they cast spells via `AIDoSpellCast()` →
`CastSpell()` which uses spell targeting rules. The `SpellFinished()` pipeline
does its own target validation before applying hate. No fix needed in
`companion_ai.cpp` for this specific bug.

## Conclusion

The bug is entirely in `Companion::Process()`. The fix requires:
1. An explicit `owner_target == owner` guard before `AddToHateList`
2. A defense-in-depth `Attack()` override to catch any future code path
   that might add the owner to the hate list through means other than the
   Process() assist block
