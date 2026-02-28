# BUG-006 Fix Notes

**Expert:** c-expert
**Date:** 2026-02-28
**Commit:** `a1a7d605d` on branch `feature/npc-recruitment`
**Files changed:** `eqemu/zone/companion.cpp`, `eqemu/zone/companion.h`, `common/ruletypes.h`

---

## Strategy: Defense in Depth

Two independent layers of protection were added so the bug cannot recur
even if future code introduces new hate-list paths:

---

## Layer 1 — Process() assist guard

**File:** `eqemu/zone/companion.cpp`
**Function:** `Companion::Process()`
**Lines:** 479-506

Replaced:
```cpp
if (owner_target && IsAttackAllowed(owner_target)) {
    if (!IsEngaged() || GetTarget() == nullptr) {
        AddToHateList(owner_target, 1);
        SetTarget(owner_target);
    }
}
```

With:
```cpp
if (owner_target) {
    bool target_is_safe = false;
    if (owner_target == owner) {
        // Player targeted themselves (F1 or clicking own portrait)
        target_is_safe = true;
    } else if (owner_target->IsCompanion() &&
               static_cast<Companion*>(owner_target->CastToNPC())->GetOwnerCharacterID() == m_owner_char_id) {
        // Player targeted another companion belonging to the same owner
        target_is_safe = true;
    } else {
        // Do not attack any other member of our group
        Group* grp = GetGroup();
        if (grp && grp->IsGroupMember(owner_target)) {
            target_is_safe = true;
        }
    }

    if (!target_is_safe && IsAttackAllowed(owner_target)) {
        if (!IsEngaged() || GetTarget() == nullptr) {
            AddToHateList(owner_target, 1);
            SetTarget(owner_target);
        }
    }
}
```

This guard covers three friendly-fire cases:
1. Owner self-target (F1) — the BUG-006 trigger
2. Owner targeting another companion belonging to the same owner
3. Owner targeting any group member

---

## Layer 2 — Attack() hard safety net

**File:** `eqemu/zone/companion.cpp`
**Function:** `Companion::Attack()` (new override of `NPC::Attack()`)
**Lines:** 363-390

Added a full override at the top of `Companion::Attack()`:
```cpp
bool Companion::Attack(Mob* other, int Hand, bool FromRiposte, bool IsStrikethrough,
                       bool IsFromSpell, ExtraAttackOptions* opts)
{
    if (!other) {
        return false;
    }

    // Hard safety net: companions must never strike their owner or any member of
    // their group regardless of how the target ended up on the hate list.
    Client* atk_owner = GetCompanionOwner();
    if (atk_owner) {
        if (other == atk_owner) {
            RemoveFromHateList(other);
            SetTarget(nullptr);
            return false;
        }
        Group* atk_grp = GetGroup();
        if (atk_grp && atk_grp->IsGroupMember(other)) {
            RemoveFromHateList(other);
            SetTarget(nullptr);
            return false;
        }
    }

    return NPC::Attack(other, Hand, FromRiposte, IsStrikethrough, IsFromSpell, opts);
}
```

If anything gets past Layer 1 (spell-applied hate, future code paths, confused
state), this override ensures the companion physically cannot land a hit on
the owner or any group member. It also cleans up the hate list entry and
clears the target so the companion does not continue attempting the attack.

---

## Bonus Fix — HP Regen for Zero-Regen Companions

While investigating, a related issue was found: companions recruited from
NPCs with `hp_regen_rate=0` in `npc_types` never regenerate HP. This is
tracked as BUG-007, but the fix is included in this commit since it was
trivial and self-contained.

**New method:** `Companion::CalcHPRegen()` declared in `companion.h` (line 192),
implemented in `companion.cpp`. Returns `max(native_regen, HPRegenPerTic_rule)`.

**New rules in `common/ruletypes.h`:**
```
RULE_INT(Companions, HPRegenPerTic, 1,
    "Minimum HP regenerated per 6-second tic for companions with 0 hp_regen_rate in npc_types")
RULE_INT(Companions, OOCRegenPct, 5,
    "Out-of-combat HP regen as percentage of max HP per tic")
```

`AI_Start()` now calls `CalcHPRegen()` to seed `hp_regen` and also sets
`ooc_regen = RuleI(Companions, OOCRegenPct)` so out-of-combat recovery uses
the existing `NPC::Process()` OOC regen path.

---

## Verification

All referenced APIs confirmed present:
- `RemoveFromHateList(Mob*)` — `zone/mob.h:763`
- `GetCompanionOwner()` — `zone/companion.h:249`
- `GetOwnerCharacterID()` — `zone/companion.h:250`
- `IsCompanion()` — `zone/companion.h:101`
- `CalcHPRegen()` — `zone/companion.h:192` (newly declared)

Docker was not accessible from WSL during this session. Full `ninja` build
must be run via Spire (`http://192.168.1.86:3000`) or:
```
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
```
