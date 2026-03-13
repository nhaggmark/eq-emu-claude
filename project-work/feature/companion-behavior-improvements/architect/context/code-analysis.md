# Code Analysis — Companion Behavior Improvements

## BUG-023: Rogue Backstab Pathing

### Root Cause
The rogue positioning uses `Mob::PlotPositionAroundTarget()` (mob.cpp:4767) which
calculates the destination relative to the CALLER's current position, not relative
to the target. It uses `GetX()` + `targetSize * sin(heading)` which means it
plots a point at "target size" distance FROM THE ROGUE along the reciprocal heading.

This produces a destination that is offset from the rogue's current position
rather than directly behind the target mob. If the rogue starts far away or
at an angle, the destination won't actually be behind the target.

Additionally, the function iterates up to 4 times reducing range if LoS fails,
but the base range is `target->GetSize()` which for small mobs might be very
small, and for large mobs creates a very wide arc.

### Current Flow (companion.cpp:1306-1323)
1. Check `RogueBehindMob` rule (default true)
2. Check `BehindMob(target, GetX(), GetY())` — angle > 90 degrees
3. If not behind, call `PlotPositionAroundTarget(target, ..., true)`
4. If dest is >5 units away, `RunTo(dest)`
5. Set `m_hold_combat_position = true`

### Problem
PlotPositionAroundTarget calculates dest FROM rogue's position, not FROM
target's position. The rogue runs to a point offset from itself rather
than to a point directly behind the mob.

### Fix Approach
Replace PlotPositionAroundTarget with direct geometric calculation:
- Get target's heading
- Calculate point directly behind target at melee range + small offset
- Use target's position as base, not rogue's position
- Backstab offset: target position + (behind_distance * direction_behind_target)

## BUG-024: Caster LOM Announcement

### Current State
- m_mana_report_timer exists (15s interval) — but ONLY fires when sitting + OOC
- No LOM-specific announcement exists
- CompanionGroupSay() available for group messaging

### Location for Fix
companion.cpp Process() method, around line 1640-1650 area where existing
mana report logic lives.

### Fix Approach
Add a boolean flag `m_lom_announced` (private member) that:
1. Gets set to true when mana drops to <= 15% during combat
2. Triggers CompanionGroupSay "LOM" once
3. Resets to false when mana goes above 15%
4. Only applies to COMBAT_ROLE_CASTER_DPS and COMBAT_ROLE_HEALER

## BUG-025: !buffs Only Buffs Player

### Root Cause
The buff timer handler in global_npc.lua fires all CastSpell calls in a
single tick. Since CastSpell sets `casting_spell_id` on the first call,
all subsequent calls find `casting_spell_id != 0` and silently fail
(spells.cpp:164-171). Only the first spell on the first target (owner)
succeeds.

### Current Flow (global_npc.lua:458-524)
1. cmd_buffs sets buff_request_target = "party"
2. Timer fires, builds target list from group:GetMember(0..5)
3. Queries companion_spell_sets for buff spells
4. Nested loop: for each spell, for each target, CastSpell immediately
5. Only first CastSpell succeeds; rest fail silently

### Fix Approach
Implement a sequential buff queue: instead of firing all CastSpell calls
in one tick, process one spell-target pair per timer tick. Use entity
variables to track progress through the spell list and target list.
Each tick: cast one spell, re-arm the timer for the next spell.

## BUG-026: Caster LOS Positioning

### Root Cause
The caster/healer combat positioning code in `companion.cpp:1326-1404`
(`UpdateCombatPositioning()`, COMBAT_ROLE_CASTER_DPS/HEALER case) calculates
a desired position at `CasterCombatRange` (default 70 units) from the target
and moves there using simple vector math. The code handles three cases:

1. **Sweet spot (50%-100% of range):** Hold position
2. **Too far (>100% of range):** Close to 70% of desired range
3. **Too close (<50% of range):** Retreat to 70% of desired range

The problem: **none of these cases check line-of-sight to the target from the
destination position.** The companion calculates a goal position based purely
on distance, then runs there. In indoor/confined zones (dungeons, buildings),
the goal position may be behind a wall, around a corner, or on the other side
of an obstruction. The companion runs there via navmesh pathing, which routes
around walls — meaning the companion navigates a complex path only to arrive
at a position where they cannot see the target.

### Available LOS Functions
From `mob.h:803-807`:
- `CheckLosFN(Mob* other)` — LOS from this mob to another mob
- `CheckLosFN(float x, float y, float z, float size)` — LOS from this mob to a point
- `CheckPositioningLosFN(Mob* other, float x, float y, float z)` — LOS from a point (x,y,z) to another mob

`CheckPositioningLosFN` (aggro.cpp:1327) is the ideal function for this fix.
It checks whether a given position (x,y,z) has LOS to another mob, using this
mob's size for the watcher height calculation. This lets us verify that a
candidate caster position can see the target before committing to movement.

### Current Code Flow (companion.cpp:1326-1404)
```
case COMBAT_ROLE_CASTER_DPS:
case COMBAT_ROLE_HEALER:
    desired_range = RuleI(Companions, CasterCombatRange)  // 70 units
    dist_sq = DistanceSquaredNoZ(self, target)
    range_sq = desired_range^2

    if 50%..100% of range:
        StopNavigation(); FaceTarget();  m_hold_combat_position = true
    else if > 100%:
        close to 70% of range (vector from self toward target)
    else (< 50%):
        retreat to 70% of range (vector from target away)
```

No LOS check at any stage.

### Fix Approach
After calculating the goal position (in both the "too far" and "too close"
branches), add a LOS check from the goal position to the target. If LOS
fails, iteratively reduce the distance (step closer to the target) until a
position with valid LOS is found.

The algorithm:
1. Calculate desired goal position at 70% of CasterCombatRange (same as now)
2. Call `CheckPositioningLosFN(target, goal_x, goal_y, goal_z)` on the goal
3. If LOS passes, run there (same as now)
4. If LOS fails, reduce distance by 10% increments toward the target
5. At each step, check LOS again
6. If a valid position is found, use it
7. If no valid position found after reducing to 20% of range (minimum safe
   distance), stop navigation and face target — hold current position

Also add a LOS check in the "sweet spot" hold condition. The companion may
already be at the correct distance but have lost LOS (e.g., target moved
behind a pillar). If LOS is lost while holding, re-evaluate positioning.

### Files Modified
- `eqemu/zone/companion.cpp` — UpdateCombatPositioning() caster/healer case

### No New Rules Needed
The existing `CasterCombatRange` rule already controls the desired distance.
The LOS check is a correctness fix, not a tunable behavior.

## BUG-027: Always Meditate Regen

### Root Cause
The mana regen calculation in `Companion::CalcManaRegen()` (companion.cpp:1125-1158)
uses the meditate formula only when `IsSitting()` returns true AND the companion
is not a melee archetype:

```cpp
if (IsSitting()) {
    if (GetArchetype() != Archetype::Melee) {
        uint16 meditate = GetSkill(EQ::skills::SkillMeditate);
        regen = (((meditate / 10) + (level - (level / 4))) / 4) + 4;
    }
}
```

When standing or in combat, casters only get the flat base rate of 2 mana/tick
plus spell/item/AA bonuses. The meditate formula produces significantly higher
regen (at level 60 with 252 meditate: ~38/tick vs base 2/tick).

This is called from `NPC::Process()` (npc.cpp:693-696) which checks
`IsCompanion()` and delegates to `CalcManaRegen()`. This fires every 6-second
tick regardless of sitting/standing state — the function itself gates the
meditate formula behind IsSitting().

### User Design Decision
The user explicitly stated this is a fun-over-authenticity choice:
"I know we are going for maximum authenticity, but there are thresholds of
complexity we just aren't going to be able to hit and still make this fun."

Companions should ALWAYS get meditation-rate regen (standing, sitting, combat).

### Fix Approach
**Option A (recommended): Add a rule `Companions:AlwaysMeditateRegen`**

When true (default), remove the `IsSitting()` gate in `CalcManaRegen()`.
Non-melee casters always use the meditate formula regardless of stance.

Modified logic:
```cpp
// If always-meditate rule is enabled, skip the sitting check
if (RuleB(Companions, AlwaysMeditateRegen) || IsSitting()) {
    if (GetArchetype() != Archetype::Melee) {
        uint16 meditate = GetSkill(EQ::skills::SkillMeditate);
        regen = (((meditate / 10) + (level - (level / 4))) / 4) + 4;
    }
}
```

This is a ~2 line change in companion.cpp plus ~1 line in ruletypes.h.

**Why a rule:** The user acknowledged this is a departure from authenticity.
A rule (default true) lets them toggle back to authentic behavior if they
change their mind. It also documents the design decision in the codebase.

### Impact
- Level 60 wizard with 252 meditate: standing regen goes from ~2 to ~38/tick
  (before multipliers)
- With CompanionManaRegenMult=100 and Character:ManaRegenMultiplier=100:
  this is the full meditation rate at all times
- No change for bards (they have their own formula in CalcManaRegen)
- No change for melee classes (archetype check still applies)
- No change for sitting behavior (already uses meditate formula)

### Files Modified
- `eqemu/zone/companion.cpp` — CalcManaRegen() sitting gate
- `eqemu/common/ruletypes.h` — new Companions:AlwaysMeditateRegen rule
