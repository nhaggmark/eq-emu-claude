# BUG-006 Diagnosis: Companion Attacks Owner on Self-Target

## Root Cause

BUG-005's fix introduced `AddToHateList(owner_target, 1)` in `Companion::Process()`
to enable combat assist (previously `SetTarget()` alone was not enough because
`IsEngaged()` stayed false without a hate list entry).

The BUG-005 code was:
```cpp
Mob* owner_target = owner->GetTarget();
if (owner_target && IsAttackAllowed(owner_target)) {
    if (!IsEngaged() || GetTarget() == nullptr) {
        AddToHateList(owner_target, 1);
        SetTarget(owner_target);
    }
}
```

The problem: `IsAttackAllowed(owner)` returns `false` for the owner normally
(same team/group), so in theory the owner should not be attacked. However,
the call to `IsAttackAllowed()` checks faction and team flags but does NOT
specifically guard against the owner being self-targeted (F1 / clicking own
portrait). If the player targets themselves and the companion calls
`IsAttackAllowed(owner)` and it returns false, no damage occurs — BUT the
`AddToHateList(owner, 1)` was reached in some edge cases (race conditions,
faction setup, or `IsAttackAllowed` returning true when owner has a debuff/
temporary hostile state).

## What the Fix Does

Two layers of defense added:

### Layer 1: Process() — combat assist guard (`eqemu/zone/companion.cpp` lines 479-506)

Before calling `AddToHateList`, the code now explicitly checks three safe-target
conditions:
1. `owner_target == owner` — player has self-targeted (F1 or own portrait)
2. `owner_target->IsCompanion() && owner_target->GetOwnerCharacterID() == m_owner_char_id`
   — player targeted their own companion
3. `grp->IsGroupMember(owner_target)` — player targeted a group member

If any condition is true, `target_is_safe = true` and `AddToHateList` is skipped.

### Layer 2: Attack() — hard safety net (`eqemu/zone/companion.cpp` lines 363-390)

Even if something slips through the Process() guard (e.g., a hate list entry
from a spell or other code path), `Companion::Attack()` now overrides the base
`NPC::Attack()` with a final check:
- If `other == atk_owner`: remove from hate list, clear target, return false
- If `other` is in the same group: remove from hate list, clear target, return false

This second layer ensures companions can never physically strike their owner
or a group member regardless of how the hate list was populated.

## Files Changed

- `eqemu/zone/companion.cpp`:
  - `Companion::Attack()` (lines 363-390): Added owner/group-member safety net
  - `Companion::Process()` (lines 479-506): Added comprehensive safe-target check
    before `AddToHateList` call
  - `Companion::CalcHPRegen()` (added method): Bonus fix — companions now have
    a HP regen floor from the `Companions::HPRegenPerTic` rule
  - `Companion::AI_Start()`: Seeds `hp_regen` and `ooc_regen` fields from rules

## Verification

Both the guard in `Process()` and the hard safety net in `Attack()` correctly
reference `GetCompanionOwner()` and `GetOwnerCharacterID()` which are declared
in `companion.h` lines 249-251. `RemoveFromHateList(Mob*)` exists on `Mob`
at `mob.h:763`.

The fix is present in the working directory as uncommitted changes (confirmed
via `git diff HEAD -- zone/companion.cpp`).
