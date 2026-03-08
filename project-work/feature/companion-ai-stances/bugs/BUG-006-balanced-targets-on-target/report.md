# BUG-006: Balanced stance companion attacks when player merely targets a mob

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-08
> **Feature:** companion-ai-stances
> **Status:** Fix deployed, pending validation

---

## Observed Behavior

When in balanced stance, the companion attacks a mob as soon as the player
targets it. Simply selecting/targeting a mob (without attacking) causes the
companion to engage.

## Expected Behavior

Balanced stance should only cause the companion to fight when:
- The player or a group member is attacked (defensive assist)
- The player actually engages in combat (starts attacking)

Merely targeting a mob should NOT trigger the companion to attack. The
player should be able to consider, inspect, or target mobs freely without
their companion starting a fight.

## Reproduction Steps

1. Recruit an NPC companion
2. Set stance to balanced (`!balanced`)
3. Target a nearby mob (click on it, /target, etc.) WITHOUT attacking
4. Observe: companion immediately engages the targeted mob

## Evidence

User confirmed passive works correctly. Balanced triggers on target
selection rather than on actual combat engagement.

## Affected Systems

- [x] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert

---

## Architecture Assessment

> **Triaged by:** architect
> **Date:** 2026-03-08
> **Root cause confirmed:** Yes
> **Complexity:** Low — single code block fix

### Root Cause

The bug is in `eqemu/zone/companion.cpp`, lines 577-603, in the
`Companion::Process()` method. There is a code block labeled:

```
// For both BALANCED and AGGRESSIVE: also assist the owner's explicit target
```

This block runs for **any non-passive stance** (line 578: `m_current_stance != COMPANION_STANCE_PASSIVE`). It checks `owner->GetTarget()` and, if the owner has ANY target that is not a group member or another companion, it immediately adds that target to the companion's hate list and begins attacking (lines 596-600):

```cpp
if (!target_is_safe && IsAttackAllowed(owner_target)) {
    if (!IsEngaged() || GetTarget() == nullptr) {
        AddToHateList(owner_target, 1);
        SetTarget(owner_target);
    }
}
```

The problem: **`owner->GetTarget()` returns whatever the player has clicked on / targeted**, regardless of whether the player is in combat. Simply clicking on a mob to inspect or consider it triggers this code path, causing the companion to attack.

### Why this is wrong for BALANCED stance

The balanced stance already has its own correct defensive logic at lines 519-544. That block scans nearby NPCs and checks whether any of them have a group member on their hate list (`nearby->CheckAggro(member)`). This is the correct "assist when attacked" behavior.

The problem is the **second block** (lines 577-603) that applies to both BALANCED and AGGRESSIVE. For AGGRESSIVE stance, attacking whatever the owner targets is arguably correct — aggressive means "attack anything in sight." But for BALANCED, this block overrides the defensive-only intent by also attacking any mob the owner merely targets.

### How bots and mercs handle this

- **Bots** (`zone/bot.cpp`): Use an explicit `GetAttackFlag()` boolean that is only set when the player issues an attack command (e.g., `^attack`). The bot checks `if (GetAttackFlag()) { SetOwnerTarget(bot_owner); }` (line 2210). A bot never attacks just because the owner targeted something.

- **Bots auto-defend** (`Bot::TryAutoDefend`, line 2611): Checks `bot_owner->GetAggroCount()` — whether the owner actually HAS mobs attacking them. Not whether they have something targeted.

- **Mercs** (`zone/merc.cpp`): Use `CheckHateList()` to manage targets (line 977). Mercs do not have any "assist owner's target" logic — they only fight things that are already on their hate list (placed there by aggro proximity or group healing aggro).

### The Fix

Modify lines 577-603 so the "assist owner's target" block only fires for AGGRESSIVE stance, not BALANCED. The BALANCED stance should rely solely on its existing defensive logic (lines 519-544) for entering combat.

Specifically, change line 578 from:

```cpp
if (owner && m_current_stance != COMPANION_STANCE_PASSIVE) {
```

to:

```cpp
if (owner && m_current_stance == COMPANION_STANCE_AGGRESSIVE) {
```

This is a one-line change. The balanced stance's own group-member-under-attack logic at lines 519-544 is correct and sufficient for balanced behavior.

**Additionally**, for balanced stance, the owner should also be able to trigger companion assist by actively engaging (auto-attack on, or owner is on a mob's hate list). To support this, add a check after the balanced block: if the owner `AutoAttackEnabled()` and `GetTarget()` is set, and the owner is a Client, treat that as an explicit combat engagement. This covers the case where the player hits /attack but the balanced companion doesn't assist.

The recommended approach:

```cpp
// For BALANCED: also assist when the owner is actively fighting (auto-attack on)
if (owner && m_current_stance == COMPANION_STANCE_BALANCED && !IsEngaged()) {
    if (owner->IsClient() && owner->CastToClient()->AutoAttackEnabled()) {
        Mob* owner_target = owner->GetTarget();
        if (owner_target && IsAttackAllowed(owner_target)) {
            // Same safety checks as before (skip group members, other companions)
            bool target_is_safe = false;
            if (owner_target == owner) {
                target_is_safe = true;
            } else if (owner_target->IsCompanion() &&
                       static_cast<Companion*>(owner_target->CastToNPC())->GetOwnerCharacterID() == m_owner_char_id) {
                target_is_safe = true;
            } else {
                Group* grp = GetGroup();
                if (grp && grp->IsGroupMember(owner_target)) {
                    target_is_safe = true;
                }
            }
            if (!target_is_safe) {
                AddToHateList(owner_target, 1);
                SetTarget(owner_target);
            }
        }
    }
}

// For AGGRESSIVE: assist the owner's explicit target (any target)
if (owner && m_current_stance == COMPANION_STANCE_AGGRESSIVE) {
    // ... existing lines 579-603 unchanged ...
}
```

### File and Line Reference

| File | Lines | What |
|------|-------|------|
| `eqemu/zone/companion.cpp` | 577-603 | Bug location: "assist owner's explicit target" block |
| `eqemu/zone/companion.cpp` | 519-544 | Correct balanced defensive logic (keep as-is) |
| `eqemu/zone/companion.cpp` | 546-575 | Aggressive scan logic (keep as-is) |
| `eqemu/zone/companion.h` | 38-40 | Stance constants |

### Assigned Agent

**c-expert** — this is a C++ source change only. No Lua, SQL, config, or protocol changes needed.

### Risk Assessment

- **Low risk**: The change narrows the trigger condition. No new code paths are added.
- **No backward compatibility concern**: Balanced stance was newly written; this corrects it to match the design intent.
- **No protocol impact**: No packet changes needed. The companion still uses standard NPC combat behavior once engaged.
- **Edge case**: If the owner engages with a spell (casting a DD) rather than auto-attack, the `AutoAttackEnabled()` check won't catch it. However, the balanced stance's defensive block (lines 519-544) WILL catch it once the target retaliates and puts the owner on its hate list, which happens almost immediately. This is acceptable behavior — balanced means "fight back," not "pre-emptive strike."
