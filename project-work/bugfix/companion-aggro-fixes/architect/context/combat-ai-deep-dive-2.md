# Combat AI Deep Dive #2: Companion Despawn & Cleric Melee Issues

**Date:** 2026-03-09
**Status:** Root causes identified

---

## Executive Summary

Three distinct bugs are causing the observed combat AI failures:

1. **BUG (Critical): Companions vanish on death — no corpse created for NPC-killed companions.** When an enemy NPC kills a companion, `NPC::Death()` skips the corpse creation branch (because the killer is not a client), sets `p_depop = true`, and the companion simply disappears with no visual feedback. The player sees the companion "vanish" rather than die.

2. **BUG (Critical): Death despawn timer never fires — `p_depop` causes immediate removal.** `NPC::Death()` unconditionally sets `p_depop = true` at attack.cpp:3017. On the next Process() tick, `NPC::Process()` returns false at line 582-593, and MobProcess() removes the entity. The `m_death_despawn_timer` started in `Companion::Death()` never gets to fire because the entity is already deleted.

3. **BUG (Moderate): Cleric charges to melee when OOM.** The `UpdateCombatPositioning()` function at companion.cpp:629-631 falls through to default melee behavior when `GetManaRatio() <= 10.0f`. Since companions don't set `ownerid`, they need `GetCombatEvent()` for pursuit. When OOM, `m_hold_combat_position` is NOT set, and the default melee pursuit code kicks in.

---

## Priority 1: Why Companions DESPAWN During Combat

### Root Cause: NPC Death Path Doesn't Create Corpses for Companion Kills

**The vanishing mechanism is DEATH, not a despawn timer.**

When a companion takes fatal damage from an enemy NPC, the following occurs:

#### Death Flow (traced through source)

1. **`Companion::Death()`** is called (companion.cpp:335)
2. **`NPC::Death()`** is called at line 340
3. **Corpse creation check at attack.cpp:2823-2853:**

```cpp
if (
    (
        !HasOwner() &&          // TRUE: companions don't set ownerid
        !IsMerc() &&            // TRUE: companions are not mercs
        !GetSwarmInfo() &&      // TRUE: companions have no swarm info
        // ... BUT the killer checks fail:
        (
            (
                killer &&
                (
                    killer->IsClient() ||           // FALSE: enemy NPC is not a client
                    killer->IsCompanion() ||         // FALSE: enemy NPC is not a companion
                    (
                        killer->HasOwner() &&        // FALSE: enemy NPC has no owner
                        killer->GetUltimateOwner()->IsClient()
                    )
                    // ... swarm info check also fails
                )
            )
        )
    )
```

**Result: The corpse creation branch is NOT entered.** The `else` at line 2982 runs instead, which only calls `RemoveFromXTargets()`. No corpse is created.

4. **`p_depop = true`** is set at attack.cpp:3017 (ALWAYS, regardless of corpse creation)
5. **Back in `Companion::Death()`:** The companion saves to DB, starts `m_death_despawn_timer`
6. **Next Process() tick:** `NPC::Process()` line 582 checks `p_depop`, finds it true, returns false
7. **MobProcess() cleanup:** Entity is removed from mob_list and safe_deleted
8. **The death_despawn_timer NEVER fires** because the entity no longer exists

#### What the player sees

The companion simply disappears mid-combat. No corpse, no death animation lingering, no "has fallen in battle" message delay — it's gone on the next server tick. Since the entity is deleted immediately, the client receives a `OP_DeleteSpawn` with Decay=0 (instant vanish), making it look like the companion poofed.

### Why wizard vanishes first

The wizard is positioned at range (70 units) and is standing still (holding position). The wizard is the squishiest companion — lowest HP, no armor. When the enemy NPC uses any AE ability or switches targets to the wizard, the wizard dies quickly. Since no corpse is created, it simply vanishes.

### Why ALL companions eventually vanish

The enemy NPC attacks each companion in turn (hate list cycling), and each companion that dies vanishes instantly via the same mechanism. The "fixed number of seconds before vanishing" the user perceived is actually the time it takes the enemy NPC to kill each companion.

### Evidence supporting this theory

- Wizard vanished first (squishiest, lowest HP)
- Other companions vanished "after some time" (time to take lethal damage)
- Companions "didn't seem to do any damage after disappearing" (because they were dead/deleted)
- The perceived "not moving = despawn" correlation is coincidental — the wizard was stationary (holding position) AND squishy, so it died first

---

## Priority 2: Why the Cleric Still Runs Into Melee

### Root Cause Analysis

The cleric is class 2 (Cleric), which maps to `COMBAT_ROLE_HEALER` via `DetermineRoleFromClass()` at companion.cpp:539-542. This is correct.

The `UpdateCombatPositioning()` code for HEALER/CASTER_DPS roles at lines 627-688 is structurally correct — it checks distance and sets `m_hold_combat_position = true` in all three cases (sweet spot, too far, too close).

**However, there is a fallthrough at line 629-631:**

```cpp
int desired_range = RuleI(Companions, CasterCombatRange);
if (desired_range <= 0 || GetManaRatio() <= 10.0f) {
    // OOM or rule disabled — fall back to default melee pursue
    break;
}
```

When the cleric's mana drops below 10%, `m_hold_combat_position` stays false, and the HEALER falls through to default melee behavior. In the `AI_Process()` engaged/not-in-range branch:

```cpp
// mob_ai.cpp:1367
else if (AI_movement_timer->Check() && target &&
        (GetOwnerID() || IsBot() || IsTempPet() ||
        CastToNPC()->GetCombatEvent())) {
    if (!IsRooted()) {
        RunTo(target->GetX(), target->GetY(), target->GetZ());
    }
}
```

Since companions don't set `ownerid` (they use `m_owner_char_id` instead), the first three conditions are false. `GetCombatEvent()` IS true (set when combat started), so the companion DOES pursue to melee.

### Scenarios where cleric charges to melee

1. **OOM (mana < 10%):** The explicit OOM fallthrough at line 629-631 sends the cleric to melee. This is likely the primary cause — clerics casting heals drain mana quickly.

2. **Initial engagement:** When combat starts, the cleric is at formation-follow distance (near the owner). If the enemy is also near the owner, the cleric is immediately in or near melee range. `UpdateCombatPositioning()` would try to retreat, but the retreat may be overridden by `AI_Process()`'s melee attack code if the companion is in `CombatRange()`.

3. **Target switches:** If the target changes (hate list cycling), the distance recalculation may briefly fail, leaving `m_hold_combat_position` false for a tick.

### Additional concern: AI_Process pursuit timing

Even when `m_hold_combat_position` IS set correctly, there's a subtle timing issue. `UpdateCombatPositioning()` is called at companion.cpp:880 BEFORE `NPC::Process()` at line 882. Inside `NPC::Process()`, the `AI_Process()` call happens at line 808 (near the end). The flag persists correctly across this call chain. So the timing is fine.

The root cause is most likely the **OOM fallthrough**. A cleric healing a group of 3-6 members in combat will drain mana quickly, dropping below 10%, at which point it charges into melee.

---

## Priority 3: Why the Wizard Vanishes

This is the same as Priority 1 — the wizard is killed by the enemy NPC, no corpse is created, and the entity is immediately deleted. The wizard vanishes first because:

1. Lowest HP pool of the group
2. Standing stationary at range (easy target for any AE)
3. If the enemy NPC switches targets to the wizard, the wizard has no defensive mitigation

---

## Proposed Fixes

### Fix 1 (Critical): Prevent immediate deletion on companion death

**In `Companion::Death()`**, after `NPC::Death()` returns, reset `p_depop` back to false:

```cpp
bool result = NPC::Death(killer_mob, damage, spell_id, attack_skill, killed_by, is_buff_tic);

// NPC::Death() sets p_depop = true unconditionally, which causes immediate entity
// removal on the next Process() tick. For companions, we want to keep the entity
// alive long enough for the death_despawn_timer to fire, allowing resurrection.
// Override p_depop back to false — the death_despawn_timer handler in Process()
// will return false when it fires, triggering proper cleanup.
p_depop = false;
```

**Rationale:** The companion's `Process()` function already handles the death despawn timer. By keeping `p_depop = false`, the companion entity stays in the world (as a dead entity) until the timer fires, giving the player time to resurrect.

### Fix 2 (Critical): Create corpse for companions killed by NPCs

**In `NPC::Death()` at attack.cpp**, extend the corpse creation condition to include companions being killed by any source:

```cpp
// In the condition at line 2823, add a companion-specific check:
if (
    (
        !HasOwner() &&
        !IsMerc() &&
        !GetSwarmInfo() &&
        (!is_merchant || allow_merchant_corpse) &&
        (
            (
                killer &&
                (
                    killer->IsClient() ||
                    killer->IsCompanion() ||
                    (killer->HasOwner() && killer->GetUltimateOwner()->IsClient()) ||
                    // ... existing swarm info check
                )
            ) ||
            is_ldon_treasure ||
            IsCompanion()  // <-- NEW: always create corpse for companions
        )
    )
    || IsQueuedForCorpse()
)
```

OR, alternatively, handle companion death entirely in `Companion::Death()` before calling `NPC::Death()`, by creating the companion-specific "dead but still in world" state without relying on the NPC corpse system.

### Fix 3 (Moderate): Don't send cleric to melee when OOM

**In `UpdateCombatPositioning()`**, change the OOM behavior for healers:

```cpp
case COMBAT_ROLE_CASTER_DPS:
case COMBAT_ROLE_HEALER: {
    int desired_range = RuleI(Companions, CasterCombatRange);
    if (desired_range <= 0) {
        break;  // Rule disabled — use default melee
    }
    
    // OOM casters/healers should hold position, not charge to melee.
    // Melee is almost always worse than standing at range and auto-attacking
    // (which they can still do with ranged weapons) or waiting for mana regen.
    if (GetManaRatio() <= 10.0f) {
        // Hold at current position (wherever they are), don't pursue
        if (IsMoving()) {
            StopNavigation();
        }
        FaceTarget();
        m_hold_combat_position = true;
        break;
    }
    
    // ... rest of positioning logic unchanged
```

### Fix 4 (Minor): Ensure companion loot rights when killed by NPC

In the corpse creation code in `NPC::Death()`, when the companion IS the dead entity (not the killer), ensure loot rights are granted to the companion's owner. The existing code at lines 2861-2866 handles the case where a companion is the KILLER, but not where the companion IS the victim.

---

## Implementation Notes

### Entity lifecycle for companion death (proposed)

1. Companion takes fatal damage
2. `Companion::Death()` is called
3. `NPC::Death()` runs — creates corpse, sets `p_depop = true`
4. **NEW:** `Companion::Death()` resets `p_depop = false`
5. Death despawn timer starts
6. Companion entity stays in world (dead state, `GetHP() <= 0`)
7. On each Process() tick: companion is dead but entity persists
8. When death_despawn_timer fires: `Process()` returns false, entity cleaned up
9. OR: player resurrects companion, timer is cancelled, companion revived

### Files to modify

| File | Change |
|------|--------|
| `zone/companion.cpp` | Fix 1: Reset `p_depop` in `Death()` after NPC::Death() |
| `zone/companion.cpp` | Fix 3: Change OOM behavior in `UpdateCombatPositioning()` |
| `zone/attack.cpp` | Fix 2: Extend corpse creation condition for companions |
| `zone/companion.cpp` | Handle dead-but-present companion state in Process() |

### Key variables and their roles

| Variable | Location | Purpose |
|----------|----------|---------|
| `p_depop` | npc.h (NPC member) | When true, NPC::Process() returns false → entity removed |
| `m_depop` | companion.h | Companion's own depop flag (separate from p_depop) |
| `m_death_despawn_timer` | companion.h | Timer for auto-dismiss after death |
| `m_hold_combat_position` | mob.h | When true, AI_Process() skips melee pursuit |
| `m_combat_role` | companion.h | HEALER/CASTER_DPS/MELEE_TANK/etc |
| `combat_event` | npc.h | True when NPC is in combat (needed for pursue) |
| `ownerid` | mob.h | NPC owner — NOT SET for companions (they use m_owner_char_id) |

### Testing verification

1. **Companion death creates corpse:** Kill a companion with an NPC, verify corpse appears
2. **Companion doesn't instantly vanish:** After companion death, verify entity persists for DeathDespawnS seconds
3. **Cleric stays at range when OOM:** Let cleric go OOM, verify it holds position instead of charging
4. **Wizard holds position:** Verify wizard stays at CasterCombatRange distance throughout combat
5. **Death notification sent:** Verify owner receives "has fallen in battle" message
6. **Re-recruitment works:** After death timer, verify companion can be re-recruited with equipment intact

---

## Additional Findings

### The `ownerid` vs `m_owner_char_id` discrepancy

Companions use `m_owner_char_id` for ownership tracking but never set the NPC-inherited `ownerid` field. This has several implications:

1. `GetOwnerID()` returns 0 for companions
2. `HasOwner()` returns false for companions
3. In `AI_Process()`, the pursuit code requires `GetCombatEvent()` for companions to pursue (since `GetOwnerID()` is 0)
4. In `EntityList::Depop()`, the guard `GetOwner() && GetOwner()->IsOfClientBot()` does NOT protect companions
5. In `NPC::Death()`, `!HasOwner()` is true for companions, affecting corpse creation logic

This is a deliberate design choice (companions are not NPC-style "pets" with an owner chain), but it means several NPC-level behaviors don't automatically include companions and must be explicitly handled.

### The `m_hold_combat_position` reset-per-tick pattern

`UpdateCombatPositioning()` resets `m_hold_combat_position = false` at the start of every tick (line 561) and re-evaluates. This means:

- If ANY early-return path in UpdateCombatPositioning fires (e.g., not engaged, no target, follow target guard), the flag stays false
- The AI_Process engaged code then sees false and uses default melee behavior
- This creates a one-tick window where the companion could pursue to melee if UpdateCombatPositioning() doesn't set the flag

This is generally fine but could cause brief position jitter if the target or engagement state changes rapidly.
