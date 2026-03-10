# Combat Positioning Debug Analysis

## Executive Summary

The combat positioning system for companion casters/healers has multiple interacting bugs. The `m_hold_combat_position` flag is correctly set by `UpdateCombatPositioning()` but is periodically bypassed in `mob_ai.cpp` by `AI_PursueCastCheck()`. When this bypass occurs, the standard pursue-to-melee path can fire (via `GetCombatEvent()` returning true), sending casters directly into melee range. Once in melee, there is no mechanism to retreat. Additionally, the z-clip teleport logic can forcibly move casters to the target's position.

---

## Root Cause Analysis

### Bug 1 (CRITICAL): `AI_PursueCastCheck()` bypasses `m_hold_combat_position`, enabling pursue-to-melee

In `mob_ai.cpp` lines 1337-1362, the engaged-but-not-in-melee-range branch:

```cpp
// Line 1337: NPC pursue-cast check — fires periodically
if (AI_PursueCastCheck()) {
    if (IsCasting() && GetClass() != Class::Bard) {
        StopNavigation();
        FaceTarget();
    }
    // If NOT casting: NOTHING happens. No movement stop, no face target.
}
// Line 1344: Companion hold-position — BYPASSED when above returns true
else if (m_hold_combat_position) {
    if (!IsMoving()) { FaceTarget(); }
    AI_EngagedCastCheck();  // Uses companion spell AI — correct
}
// Line 1351: Standard pursue-to-melee — ALSO BYPASSED when AI_PursueCastCheck returns true
else if (AI_movement_timer->Check() && target &&
        (GetOwnerID() || IsBot() || IsTempPet() ||
        CastToNPC()->GetCombatEvent())) {
    if (!IsRooted()) { RunTo(target->GetX(), target->GetY(), target->GetZ()); }
}
```

**The critical problem:** `NPC::AI_PursueCastCheck()` returns `true` whenever the `AIautocastspell_timer` fires — regardless of whether any spell was cast:

```cpp
bool NPC::AI_PursueCastCheck() {
    if (AIautocastspell_timer->Check(false)) {  // Timer fires?
        AIautocastspell_timer->Disable();
        // Try to cast from NPC spell list (not companion spells!)
        if(!AICastSpell(...)) {  // NPC::AICastSpell — wrong spell list for companions
            if(!AICastSpell(...)) {
                AIautocastspell_timer->Start(RandomTimer(...), false);
            }
        }
        return(true);  // ALWAYS returns true when timer fires
    }
    return(false);
}
```

When this returns true:
1. The companion's `m_hold_combat_position` branch is SKIPPED
2. The companion's `AI_EngagedCastCheck()` is NOT called (companion doesn't cast this tick)
3. The NPC::AICastSpell uses the NPC's original spell list (from `npc_spells_id`), NOT the companion spell list
4. If not currently casting, the companion does NOTHING — no position hold, no casting, no movement

**Why the wrong spell list is used:** `Companion::AICastSpell(int8, uint32)` has a DIFFERENT parameter signature from `NPC::AICastSpell(Mob*, uint8, uint32, bool)`. The companion version does NOT override the NPC version. So `AI_PursueCastCheck()` calls the NPC version.

**Frequency:** The `AIautocastspell_timer` is initialized to 300ms in `AI_Event_Engaged()` (line 1781) and then cycles every few seconds (configured by `AISpellVar.pursue_no_sp_recast_min/max`). This means the bypass happens regularly.

**On bypass ticks:** The companion's `UpdateCombatPositioning()` RunTo/StopNavigation commands from earlier in the tick are NOT overridden — the movement system still executes them. But the `AI_EngagedCastCheck()` call is missed. The position hold is maintained by `UpdateCombatPositioning()` managing movement directly, not by the `m_hold_combat_position` flag in AI_Process.

**BUT THE REAL DANGER:** On ticks where the `AI_PursueCastCheck()` timer does NOT fire AND `m_hold_combat_position` is somehow false (see Bug 1b below), the standard pursue path on line 1351 FIRES because `GetCombatEvent()` returns true for companions. This sends the caster running to melee.

### Bug 1b: `m_hold_combat_position` can be false when `UpdateCombatPositioning()` returns early

`UpdateCombatPositioning()` starts by resetting the flag to false:
```cpp
m_hold_combat_position = false;  // Reset every tick
```

Then it has multiple early-return paths that leave the flag as false:
```cpp
if (!IsEngaged() || !GetTarget()) {
    return;  // flag stays false
}
// ... safety guards ...
if (GetFollowID() && (!target->IsNPC() || target->IsCompanion())) {
    return;  // flag stays false
}
```

If any of these return early, the caster/healer enters AI_Process with `m_hold_combat_position = false`. On a tick where `AI_PursueCastCheck()` also returns false, the only remaining branch is the pursue-to-melee path, which fires because `GetCombatEvent()` is true.

**Scenario that triggers this for the cleric:**
1. Cleric is engaged, target is valid — `UpdateCombatPositioning()` runs normally
2. Target dies mid-tick or is removed from entity list
3. `GetTarget()` returns nullptr in `UpdateCombatPositioning()` → early return, flag stays false
4. But in `AI_Process()`, the target pointer was already captured at the top of the function
5. `m_hold_combat_position` is false, pursue fires, cleric runs to the (now dead) target position
6. Next tick, a new target is acquired, cleric is now in melee, stays there (Bug 3)

### Bug 2: Z-clip teleport can forcibly move casters to target position

In `mob_ai.cpp` lines 1031-1046:
```cpp
if (IsNPC() && m_z_clip_check_timer.Check()) {
    bool is_moving = IsMoving() && !(...);
    auto t = GetTarget();
    if (is_moving && t) {
        // If within 75 horizontal units but >= 25 Z units difference
        // and can't path to target...
        if (within_distance && within_z_distance && !can_path_to) {
            float new_z = FindDestGroundZ(t->GetPosition());
            GMMove(t->GetPosition().x, t->GetPosition().y, new_z + GetZOffset(), ...);
        }
    }
}
```

This runs for ALL NPCs including companions. When a caster companion is moving (from UpdateCombatPositioning's RunTo) and the z-clip conditions are met:
- Companion is teleported (GMMove) right to the target's X/Y position
- `FindDestGroundZ()` may return extreme values in zones with complex geometry
- **This explains the wizard "vanishing"**: teleported to underground or a different floor
- **This contributes to the cleric melee**: teleported into melee range

### Bug 3: No retreat mechanism when caster enters melee range

In `mob_ai.cpp`, the `CombatRange(target)` true branch (lines 1153-1322) handles entities in melee range:
```cpp
if (is_combat_range) {
    StopNavigation();
    FaceTarget();
    // ... melee attacks ...  (lines 1167-1315, no m_hold_combat_position check)
    AI_EngagedCastCheck();   // line 1322 — companion spells work here
}
```

There is NO check for `m_hold_combat_position` in this branch. If a caster/healer ends up in melee range (via z-clip teleport, pursue-to-melee from Bug 1b, spawning near target, etc.):
1. Melee attacks proceed (wrong for a wizard/cleric!)
2. `AI_EngagedCastCheck()` is called (correct — companion casts spells)
3. There is NO command to move the caster BACK to range

**In `UpdateCombatPositioning()`**, the "too close" case (< 50% of desired range) only calls `StopNavigation()` and `FaceTarget()`. It does NOT move the companion away. The comment says "mob will move" — assuming the enemy will move away. If the enemy is stationary, the caster stays in melee permanently.

---

## DetermineRoleFromClass() Verification

Class mapping is CORRECT:

| Class ID | Constant | Combat Role | Correct? |
|----------|----------|-------------|----------|
| 1 | Class::Warrior | COMBAT_ROLE_MELEE_TANK | YES |
| 2 | Class::Cleric | COMBAT_ROLE_HEALER | YES |
| 9 | Class::Rogue | COMBAT_ROLE_ROGUE | YES |
| 12 | Class::Wizard | COMBAT_ROLE_CASTER_DPS | YES |

---

## Process() Call Order

```
Companion::Process()
    ├── Target selection (stance-based assist logic)
    ├── UpdateCombatPositioning()        // Sets m_hold_combat_position
    └── NPC::Process()
         └── AI_Process()
              ├── Z-clip check           // Can teleport to target! (Bug 2)
              ├── CombatRange(target)?
              │   ├── YES: melee attacks  // No m_hold check! (Bug 3)
              │   └── NO:
              │       ├── AI_PursueCastCheck()     // Steals tick (Bug 1)
              │       ├── m_hold_combat_position   // Correct when reached
              │       └── Pursue to melee          // Via GetCombatEvent() (Bug 1b)
```

---

## Why Each Companion Type Behaves Differently

### Tank: "Charge in" — WORKS
1. `UpdateCombatPositioning()` → `COMBAT_ROLE_MELEE_TANK` → `break` → flag stays false
2. Not in CombatRange initially → enters else branch
3. `AI_PursueCastCheck()` may fire (tries NPC spells, likely fails) → does nothing useful
4. `m_hold_combat_position` is false → skip
5. Pursue path: `GetCombatEvent()` is true → `RunTo(target)` → pursues to melee → CORRECT

### Rogue: "Circle behind" — WORKS
1. `UpdateCombatPositioning()` → `COMBAT_ROLE_ROGUE` → `PlotPositionAroundTarget` → `RunTo` + `m_hold_combat_position = true`
2. In CombatRange (rogue wants melee) → melee attacks proceed → CORRECT
3. If not behind target: `m_hold_combat_position` prevents pursue override → CORRECT
4. Once behind: `m_hold_combat_position` NOT set → normal melee AI → CORRECT

### Wizard: "Vanished" — BROKEN
1. `UpdateCombatPositioning()` → `COMBAT_ROLE_CASTER_DPS` → RunTo or StopNavigation + `m_hold_combat_position = true`
2. Wizard is moving (from RunTo) → Z-clip check fires → GMMove to target position or bad Z → **VANISHES** (Bug 2)
3. OR: On bypass tick, wizard misses AI_EngagedCastCheck → doesn't cast → appears broken

### Cleric: "Ran into melee" — BROKEN
1. `UpdateCombatPositioning()` → `COMBAT_ROLE_HEALER` → StopNavigation/RunTo + `m_hold_combat_position = true`
2. Possible scenarios:
   a. Z-clip teleport moves cleric to target (Bug 2) → now in melee → no retreat (Bug 3)
   b. Target changes or dies between UpdateCombatPositioning and AI_Process → flag false → pursue fires (Bug 1b)
   c. Periodic bypass by AI_PursueCastCheck combined with flag reset → pursue-to-melee fires

---

## Specific Code Fixes

### Fix 1 (CRITICAL): Override `AI_PursueCastCheck()` in Companion

The companion must override `AI_PursueCastCheck()` to prevent the NPC version from stealing the tick and using the wrong spell list.

**In `companion.h`:**
```cpp
virtual bool AI_PursueCastCheck() override;
```

**In `companion.cpp`:**
```cpp
bool Companion::AI_PursueCastCheck() {
    // Companions use their own spell AI via AI_EngagedCastCheck()
    // which is called from the m_hold_combat_position branch.
    // Return false so the hold-position or pursue branches run instead.
    return false;
}
```

This ensures:
- Casters/healers always reach the `m_hold_combat_position` branch
- Melee companions always reach the pursue-to-melee branch
- The companion spell AI is always used (never the NPC spell list)

### Fix 2 (CRITICAL): Add active retreat in "too close" case

In `UpdateCombatPositioning()`, change the "too close" case to actively move AWAY:

```cpp
} else {
    // Too close (< 50% of desired range) — back up to 70% of desired range
    float desired_dist = range_f * 0.7f;
    float dx = GetX() - target->GetX();  // Direction AWAY from target
    float dy = GetY() - target->GetY();
    float len = std::sqrt(dx * dx + dy * dy);
    if (len > 1.0f) {  // Guard against division by near-zero
        float nx = dx / len;
        float ny = dy / len;
        float goal_x = target->GetX() + nx * desired_dist;
        float goal_y = target->GetY() + ny * desired_dist;
        RunTo(goal_x, goal_y, GetZ());
    } else {
        // Overlapping with target — pick arbitrary direction (toward owner)
        Client* owner = GetCompanionOwner();
        if (owner) {
            float ox = owner->GetX() - target->GetX();
            float oy = owner->GetY() - target->GetY();
            float olen = std::sqrt(ox * ox + oy * oy);
            if (olen > 0.0f) {
                float goal_x = target->GetX() + (ox / olen) * desired_dist;
                float goal_y = target->GetY() + (oy / olen) * desired_dist;
                RunTo(goal_x, goal_y, GetZ());
            }
        }
    }
    m_hold_combat_position = true;
}
```

### Fix 3 (IMPORTANT): Add `m_hold_combat_position` check in CombatRange branch

In `mob_ai.cpp`, add a companion caster check at the top of the `if (is_combat_range)` branch:

```cpp
if (is_combat_range) {
    // Companion casters/healers should not melee — let positioning push them back
    if (m_hold_combat_position) {
        if (IsMoving()) {
            // Let UpdateCombatPositioning's RunTo continue (retreat)
        } else {
            FaceTarget();
        }
        AI_EngagedCastCheck();
        // Skip melee attacks entirely for casters holding position
    }
    else {
        // ... existing melee attack code (moved into this else block) ...
    }
}
```

### Fix 4 (IMPORTANT): Exempt companions from z-clip teleport

In `mob_ai.cpp` line 1031:
```cpp
if (IsNPC() && !IsCompanion() && m_z_clip_check_timer.Check()) {
```

Companion movement is managed by `UpdateCombatPositioning()` and formation follow. The z-clip teleport is designed for regular NPCs that get stuck on geometry while pursuing, not for companions that intentionally hold at range.

### Fix 5 (OPTIONAL): Disable AIautocastspell_timer for companions

Since companions use their own spell system, the NPC autocast timer is unnecessary and causes the `AI_PursueCastCheck()` interference. Disable it in `Companion::AI_Start()`:

```cpp
void Companion::AI_Start(uint32 iMoveDelay) {
    NPC::AI_Start(iMoveDelay);
    
    // Disable NPC autocast timer — companions use their own spell AI
    AIautocastspell_timer->Disable();
    
    LoadCompanionSpells();
    // ...
}
```

This is complementary to Fix 1. Fix 1 prevents the timer from interfering even if it fires. Fix 5 prevents it from firing at all.

---

## Priority Order

1. **Fix 1** — Override AI_PursueCastCheck (prevents primary bypass)
2. **Fix 3** — CombatRange branch protection (prevents melee when in close range)
3. **Fix 2** — Active retreat (moves casters out of melee when too close)
4. **Fix 4** — Z-clip exemption (prevents forced teleport to target)
5. **Fix 5** — Disable autocast timer (belt-and-suspenders for Fix 1)

---

## File References

| File | Lines | Issue |
|------|-------|-------|
| `zone/companion.cpp` | 548-660 | UpdateCombatPositioning — positioning logic |
| `zone/companion.cpp` | 662-852 | Process — tick ordering, target selection |
| `zone/companion.cpp` | 854-858 | AI_EngagedCastCheck — companion spell AI (correct) |
| `zone/companion.h` | 122-127 | AI virtual overrides — **missing AI_PursueCastCheck** |
| `zone/mob_ai.cpp` | 1031-1046 | Z-clip teleport — affects casters (Bug 2) |
| `zone/mob_ai.cpp` | 1151-1364 | Engaged combat logic — CombatRange branches |
| `zone/mob_ai.cpp` | 1337-1362 | **Pursue-cast / hold-position / pursue chain** (Bugs 1, 1b) |
| `zone/mob_ai.cpp` | 1770-1818 | AI_Event_Engaged — sets combat_event=true, starts autocast timer |
| `zone/mob_ai.cpp` | 1918-1933 | NPC::AI_PursueCastCheck — always returns true on timer |
| `zone/mob.h` | 726-727 | m_hold_combat_position accessors |
| `zone/mob.h` | 788 | IsEngaged — checks hate list empty |
| `zone/mob.h` | 1557 | m_hold_combat_position member |
| `zone/npc.h` | 449-450 | GetCombatEvent/SetCombatEvent |
| `zone/npc.h` | 689 | NPC::AICastSpell signature (different from Companion!) |
| `zone/companion.h` | 124 | Companion::AICastSpell signature (int8, uint32) |
| `common/ruletypes.h` | 1212 | CasterCombatRange rule (default 70 units) |
