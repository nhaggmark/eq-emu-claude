# Companion Follow Formation Analysis

> **Date:** 2026-03-09
> **Context:** All companions follow the player to the exact same position, making
> them impossible to click/target individually. This analysis identifies where the
> follow position is calculated, how to inject per-companion offsets, and proposes
> a concrete implementation plan.

---

## 1. Current Follow Behavior — Root Cause

### How Follow Works Today

The follow system is in `zone/mob_ai.cpp` lines 1470-1506. When a mob has a
non-zero `follow_id`, it executes this logic every AI tick:

```cpp
// mob_ai.cpp:1470-1500
else if (GetFollowID()) {
    Mob *follow = entity_list.GetMob(static_cast<uint16>(GetFollowID()));
    if (!follow) {
        SetFollowID(0);
        SetFollowDistance(100);    // default: 100 (squared distance)
        SetFollowCanRun(true);
    }
    else {
        float distance = DistanceSquared(m_Position, follow->GetPosition());
        int   follow_distance = GetFollowDistance();

        // Default follow distance is 100 (10 units actual distance, since it's squared)
        if (distance >= follow_distance) {
            bool running = false;
            if (GetFollowCanRun() && distance >= follow_distance + 150) {
                running = true;
            }
            auto &Goal = follow->GetPosition();   // <-- THE PROBLEM
            if (running) {
                RunTo(Goal.x, Goal.y, Goal.z);
            } else {
                WalkTo(Goal.x, Goal.y, Goal.z);
            }
        }
        else {
            moved = false;
            StopNavigation();
        }
    }
}
```

**The problem is on line 1492:** `auto &Goal = follow->GetPosition();`

Every following mob targets the **exact position** of the mob it's following.
There is no offset, no angle, no formation logic. All companions converge on
the owner's coordinates and stop when within `sqrt(follow_distance)` units
(default ~10 units). They all stack on the same spot.

### How Companions Set Up Following

In `companion.cpp`, `CompanionJoinClientGroup()` (lines 1045, 1064) calls:
```cpp
SetFollowID(owner->GetID());
```

The default `follow_dist` is 100 (set in `mob.h` member initialization). No
companion-specific offset or distance is ever set.

### What Mob Members Are Available

From `mob.h` lines 1599-1601:
```cpp
uint32 follow_id;      // entity ID to follow
uint32 follow_dist;    // squared distance threshold for stopping
bool   follow_run;     // whether to run when far away
```

Setters/getters (mob.h:907-912):
```cpp
void SetFollowID(uint32 id);
void SetFollowDistance(uint32 dist);
void SetFollowCanRun(bool v);
uint32 GetFollowID() const;
uint32 GetFollowDistance() const;
bool GetFollowCanRun() const;
```

**There is no follow offset mechanism.** The system only supports "follow to
this entity's exact position, stop within `sqrt(follow_dist)` units."

---

## 2. Existing Formation Systems

### Bots: No Formation

Bots (`zone/bot.cpp`) have no formation logic. They use the same follow system:
`SetFollowID(owner)` with configurable `follow_distance` via bot settings. All
bots converge on the same point. The only control is a per-bot follow distance
setting (line 10405).

### Perl Formation Plugin

`akk-stack/server/quests/plugins/formation_tools.pl` provides NPC squad
formation functions (`MoveToFormation`, `SpawnInFormation`, `FollowFormLeader`,
etc.) that calculate relative positions using heading + distance offsets.

**Key insight from the plugin:** It uses entity variables (slots 50, 51, 52) to
store each NPC's relative distance and heading offset from the leader. On each
movement tick, it recalculates the destination using the leader's current
heading, applying the stored offset.

This is a timer-based Perl solution for NPC squads. It is NOT applicable to
companions because:
- It uses `MoveTo()` calls, not the follow system
- It requires an external timer to drive updates
- It doesn't integrate with AI combat behavior

### EQ Heading System

EQ uses a 0-512 heading system (float, stored in `m_Position.w`):
- `CalculateHeadingAngleBetweenPositions()` in `zone/position.cpp:261` computes
  heading from one position to another
- The return value ranges 0-511.5, where 0 = North (approximately)
- Headings are clockwise (EQ convention)
- Conversion: `degrees = heading * 360.0 / 512.0`
- Conversion: `radians = heading * 2 * PI / 512.0`

---

## 3. Proposed Solution: C++ Formation Offsets in AI Follow Logic

### Approach: Add Per-Mob Follow Offset

Add two new members to `Mob`:
1. `float follow_angle_offset` — angle offset (in EQ heading units, 0-512) from
   directly behind the follow target
2. `float follow_distance_offset` — distance from the follow target's position

Modify the follow logic in `mob_ai.cpp` to compute the Goal position using these
offsets relative to the follow target's heading, rather than targeting the exact
position.

### Why C++ (Not Lua/Rules)

1. **The follow logic runs in C++ AI tick** — the offset calculation MUST be in
   the same place as the `RunTo(Goal.x, Goal.y, Goal.z)` call. A Lua timer
   calling `MoveTo()` would fight against the AI follow system.

2. **Performance** — follow position is recalculated every AI tick (~100ms). A
   Lua callback per-companion per-tick would be expensive and fragile.

3. **No existing hook** — there is no Lua mod hook for follow position
   calculation. The Lua mod system covers combat/XP formulas, not movement.

4. **Integration with combat** — when companions engage in combat, the follow
   system automatically stops. When they disengage, it resumes. The offset needs
   to be part of this native behavior.

### Formation Slot Assignment

Each companion needs a consistent "slot" for angle offset calculation. Options:

**Option A: Group position index** — Use the companion's index in the group
`members[]` array (0-5). The player is typically index 0, so companions are 1-5.
- Pro: Already exists, naturally sequential
- Con: Changes when group composition changes (companion dismissed/added)

**Option B: Entity list iteration order** — Get companions from
`GetCompanionsByOwnerCharacterID()`, which returns a `vector<Companion*>`.
- Pro: Consistent per-zone instance
- Con: Order changes across zones

**Option C: Companion ID** — Use the database `companion_id` for deterministic
ordering. Sort active companions by `companion_id` and assign slots 0, 1, 2...
- Pro: Deterministic, consistent across zones and sessions
- Con: Requires sorting at assignment time

**Recommendation: Option A (group position index).** It's simple, already
available, and the visual change when group order shifts is acceptable. The
player won't notice because the formation adjusts smoothly via movement.

### Offset Calculation

For N companions in a 120-degree arc behind the player:

```
arc_width = 120 degrees = 170.67 heading units (512-scale)
behind = owner_heading + 256 (opposite direction, mod 512)

For companion at slot i (0-indexed, from N total):
  if N == 1: angle_offset = 0 (directly behind)
  if N >= 2:
    step = arc_width / (N - 1)
    angle_offset = -arc_width/2 + i * step

formation_heading = (behind + angle_offset) mod 512
goal_x = owner_x + cos(formation_heading * 2*PI / 512) * distance
goal_y = owner_y + sin(formation_heading * 2*PI / 512) * distance
goal_z = owner_z (or FindGroundZ)
```

Default formation distance: 15 units behind the player.
Arc width: 120 degrees for up to 5 companions.

### Where To Implement

**File: `zone/mob_ai.cpp` lines 1470-1506**

Replace the simple `auto &Goal = follow->GetPosition();` with:

```cpp
else if (GetFollowID()) {
    Mob *follow = entity_list.GetMob(static_cast<uint16>(GetFollowID()));
    if (!follow) {
        SetFollowID(0);
        SetFollowDistance(100);
        SetFollowCanRun(true);
    }
    else {
        // Compute formation-aware goal position
        float goal_x = follow->GetX();
        float goal_y = follow->GetY();
        float goal_z = follow->GetZ();

        // Apply formation offset if this mob has one set
        if (GetFollowAngleOffset() != 0.0f || IsCompanion()) {
            float owner_heading = follow->GetHeading();
            float behind = fmod(owner_heading + 256.0f, 512.0f);
            float formation_heading = fmod(behind + GetFollowAngleOffset() + 512.0f, 512.0f);
            float radians = formation_heading * 2.0f * M_PI / 512.0f;
            float dist = static_cast<float>(GetFollowFormationDistance());
            // EQ coordinate system: sin for X, cos for Y (inverted from standard)
            goal_x += sin(radians) * dist;
            goal_y += cos(radians) * dist;
        }

        float distance = DistanceSquaredNoZ(m_Position, glm::vec4(goal_x, goal_y, goal_z, 0));
        int   follow_distance = GetFollowDistance();

        if (distance >= follow_distance) {
            bool running = (GetFollowCanRun() && distance >= follow_distance + 150);
            if (running) {
                RunTo(goal_x, goal_y, goal_z);
            } else {
                WalkTo(goal_x, goal_y, goal_z);
            }
        }
        else {
            moved = false;
            StopNavigation();
        }
    }
}
```

### New Mob Members Needed

In `zone/mob.h`:
```cpp
// Formation follow offsets (used by companion system)
float follow_angle_offset = 0.0f;     // heading offset from "directly behind" (EQ heading units, 0-512)
float follow_formation_dist = 15.0f;  // distance from owner's position in formation

// Getters/Setters
void SetFollowAngleOffset(float offset) { follow_angle_offset = offset; }
float GetFollowAngleOffset() const { return follow_angle_offset; }
void SetFollowFormationDistance(float dist) { follow_formation_dist = dist; }
float GetFollowFormationDistance() const { return follow_formation_dist; }
```

### Formation Assignment in Companion Code

In `companion.cpp`, after `SetFollowID(owner->GetID())`, call a new function
`AssignFormationSlot()`:

```cpp
void Companion::AssignFormationSlot()
{
    Client* owner = GetCompanionOwner();
    if (!owner) return;

    // Collect all active companions for this owner
    auto companions = entity_list.GetCompanionsByOwnerCharacterID(m_owner_char_id);
    int total = static_cast<int>(companions.size());
    
    // Find my index in the sorted companion list
    // Sort by companion_id for consistency
    std::sort(companions.begin(), companions.end(),
        [](Companion* a, Companion* b) { return a->GetCompanionID() < b->GetCompanionID(); });
    
    int my_slot = 0;
    for (int i = 0; i < total; i++) {
        if (companions[i] == this) {
            my_slot = i;
            break;
        }
    }

    // Calculate arc offset
    float arc_width = 170.67f;  // 120 degrees in 512-heading-units
    float formation_dist = 15.0f;  // units behind player

    if (total == 1) {
        SetFollowAngleOffset(0.0f);
    } else {
        float step = arc_width / static_cast<float>(total - 1);
        float offset = -arc_width / 2.0f + static_cast<float>(my_slot) * step;
        SetFollowAngleOffset(offset);
    }
    SetFollowFormationDistance(formation_dist);
}
```

Call `AssignFormationSlot()` from:
1. `CompanionJoinClientGroup()` — when companion joins group
2. `AddCompanionToGroup()` — when companion is added to group
3. After any companion is dismissed/dies — reassign remaining companions

### Reassignment on Composition Change

When a companion leaves the group (dismiss, death, suspend), all remaining
companions need their formation slots recalculated. Add a call to:

```cpp
static void Companion::ReassignFormationSlots(uint32 owner_char_id)
{
    auto companions = entity_list.GetCompanionsByOwnerCharacterID(owner_char_id);
    for (auto* c : companions) {
        c->AssignFormationSlot();
    }
}
```

Call this from:
- `RemoveCompanionFromGroup()` — after removal
- `Companion::Dismiss()` — after dismissal
- `Companion::Suspend()` — after suspend
- `Companion::Death()` (after death processing)

### Rules to Add

```cpp
RULE_INT(Companions, FormationArcDegrees, 120, "Width of companion follow formation arc in degrees")
RULE_INT(Companions, FormationDistance, 15, "Distance in game units that companions follow behind the player")
```

### Lua Bindings

Expose on `Lua_Companion`:
```cpp
void Lua_Companion::AssignFormationSlot();
```

Not strictly necessary for the initial implementation (C++ handles it
automatically), but useful for debugging and manual control.

---

## 4. Combat Behavior During Formation

When a companion engages in combat:
- `NPC::AI_Process()` handles engaged state BEFORE the follow logic
- The companion RunTo's the target, ignoring follow position
- Formation offset is irrelevant during combat

When combat ends:
- Companion returns to idle state
- Follow logic resumes, using the formation offset
- Companion walks/runs to its offset position behind the player

This is the correct behavior — no changes needed for combat.

---

## 5. Edge Cases

### Collision with Terrain
- The formation offset position could be inside a wall
- Mitigation: `RunTo/WalkTo` use navmesh pathfinding when available
- The companion will path around obstacles to reach the offset position
- Worst case: companion gets stuck, same as any NPC pathing issue

### Guard Mode
- When in guard mode, `SetFollowID(0)` is called, so formation offset is irrelevant
- When exiting guard mode, `SetGuardMode(false)` calls `SetFollowID(owner)` and
  `SetFollowDistance(100)` — should also call `AssignFormationSlot()`

### Zone Transitions
- Formation slots are recalculated on `CompanionJoinClientGroup()` which is
  called after zone-in via `Unsuspend()` → `CompanionJoinClientGroup()`
- No additional handling needed

### Solo Companion
- With 1 companion, offset = 0 (directly behind player)
- This is the ideal behavior — single companion follows directly behind

### Maximum Companions (5)
- With 5 companions in 120-degree arc: offsets at -60, -30, 0, +30, +60 degrees
- At 15 units distance, companions are ~7.5 units apart at the arc endpoints
- This provides adequate visual separation for clicking

### Heading During Movement vs Standing
- `follow->GetHeading()` returns the owner's current heading
- When the player is stationary, heading reflects the direction they face
- When moving, heading updates to direction of movement
- The formation will dynamically rotate as the player turns — this is the
  desired behavior

---

## 6. Implementation Sequence

1. **`mob.h`** — Add `follow_angle_offset`, `follow_formation_dist` members
   with getters/setters

2. **`mob_ai.cpp`** — Modify follow logic (lines 1470-1506) to compute
   offset goal position when `follow_angle_offset != 0`

3. **`companion.h`** — Declare `AssignFormationSlot()` and
   `ReassignFormationSlots(uint32)`

4. **`companion.cpp`** — Implement `AssignFormationSlot()`,
   `ReassignFormationSlots()`. Call from `CompanionJoinClientGroup()`,
   `AddCompanionToGroup()`, `RemoveCompanionFromGroup()`, `Dismiss()`,
   `Suspend()`, and `Death()`

5. **`ruletypes.h`** — Add `FormationArcDegrees` and `FormationDistance` rules

6. **`lua_companion.cpp`** (optional) — Expose `AssignFormationSlot()` to Lua

7. **Test:** Recruit 1-5 companions, verify they fan out behind the player,
   formation rotates when player turns, companions converge for combat then
   re-spread after

---

## 7. Summary

| Question | Answer |
|----------|--------|
| Where is follow position calculated? | `zone/mob_ai.cpp:1492` — `auto &Goal = follow->GetPosition()` |
| Why do companions stack? | All target the owner's exact position with no offset |
| How to fix? | Add `follow_angle_offset` and `follow_formation_dist` to `Mob`, modify follow logic to compute offset position |
| Where to assign slots? | `Companion::AssignFormationSlot()`, called from group join/leave |
| Approach | C++ (must be in AI tick path), with rule-based arc width and distance |
| Files changed | `mob.h`, `mob_ai.cpp`, `companion.h`, `companion.cpp`, `ruletypes.h` |
| Risk | Low — only affects follow path calculation, no protocol/packet changes |
