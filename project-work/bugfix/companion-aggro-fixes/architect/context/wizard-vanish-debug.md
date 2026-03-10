# Wizard Companion Vanishes During Combat — Root Cause Analysis

## Date: 2026-03-09

## Symptom
Wizard companion vanishes from view during combat. It does NOT die — it is alive
and spawns with the owner at the respawn point after the owner dies. The wizard
simply goes somewhere far outside visual range during combat.

---

## PRIMARY CAUSE: NPC Flee Behavior (High Confidence)

### The Bug
The `CompanionFleeEnabled` rule defaults to `true` (ruletypes.h:1210), which
means companions RETAIN NPC flee behavior after recruitment. When a wizard
companion drops below 25% HP (the `FleeHPRatio` default), it starts fleeing
to a **random location in the zone** via navmesh pathfinding.

### Evidence Chain

1. **Rule default** (common/ruletypes.h:1210):
   ```cpp
   RULE_BOOL(Companions, CompanionFleeEnabled, true,
       "Whether companions retain NPC flee behavior after recruitment")
   ```

2. **Flee immunity is NOT set** (companion.cpp:765-769):
   ```cpp
   if (!RuleB(Companions, CompanionFleeEnabled)) {
       SetSpecialAbility(SpecialAbility::FleeingImmunity, 1);
   } else {
       SetSpecialAbility(SpecialAbility::FleeingImmunity, 0);  // <-- flee allowed!
   }
   ```
   When the rule is `true`, `FleeingImmunity` is set to 0 (disabled).

3. **IsPet() check does NOT block companions** (fearpath.cpp:57):
   ```cpp
   void Mob::CheckFlee() {
       if (IsPet() || ...) return;  // IsPet() is false for companions
   ```
   `IsPet()` returns `HasOwner() && !IsMerc()`. Companions don't set `ownerid`
   (they use `m_owner_char_id` instead), so `GetOwnerID()` returns 0, `HasOwner()`
   returns false, and `IsPet()` returns false. Companions pass through this check.

4. **FleeingImmunity check does NOT block companions** (fearpath.cpp:78):
   ```cpp
   if (GetSpecialAbility(SpecialAbility::FleeingImmunity) || spellbonuses.ImmuneToFlee) {
       return;  // only if immunity is set — it's NOT for companions
   }
   ```

5. **Flee threshold is 25%** (ruletypes.h:570):
   ```cpp
   RULE_INT(Combat, FleeHPRatio, 25, "HP percentage when a NPC begins to flee")
   ```
   Wizards are squishy; 25% HP is reached quickly under fire.

6. **Flee destination is random** (fearpath.cpp:280):
   ```cpp
   Node = zone->pathing->GetRandomLocation(glm::vec3(GetX(), GetY(), GetZOffset()), flags);
   ```
   When an NPC flees, it pathfinds to a RANDOM navmesh node, which can be
   anywhere in the zone — potentially hundreds of units from the fight.

7. **Flee overrides combat positioning** (mob_ai.cpp:993-1020):
   ```cpp
   if (RuleB(Combat, EnableFearPathing)) {
       if (currently_fleeing) {
           // Run to fear point and RETURN — skips all other engaged logic
           RunTo(m_FearWalkTarget.x, m_FearWalkTarget.y, m_FearWalkTarget.z);
           return;
       }
   }
   ```
   Fear pathing is checked at the TOP of the engaged branch, BEFORE the
   m_hold_combat_position branch. When fleeing, the companion ignores all
   combat positioning and runs to the random fear point.

### Why the Wizard Matches This Bug

- Wizards have low HP and low AC — they hit 25% HP quickly under fire
- Wizards generate hate via spell damage, drawing mob attention
- If a mob turns to attack the wizard (or AE damage hits it), HP drops fast
- The wizard starts fleeing to a random zone location, vanishing from view
- The wizard is still alive (confirmed by user observation)
- After the owner dies and respawns, the wizard follows to the bind point
  (still alive, still has follow ID set)

### The Fix

Two options:

**Option A (recommended): Disable flee for companions by default**
Change the rule default to `false`:
```cpp
RULE_BOOL(Companions, CompanionFleeEnabled, false,
    "Whether companions retain NPC flee behavior after recruitment")
```
This makes companions immune to fleeing by default. Companions should fight
until death or until told to disengage, not run away randomly.

**Option B: Override CheckFlee for companions**
Add an `IsCompanion()` check to `CheckFlee()`:
```cpp
void Mob::CheckFlee() {
    if (IsPet() || IsCompanion() || IsCasting() || ...) return;
```
This is more invasive and doesn't fix the underlying rule logic issue.

**Recommended approach: Option A**, because:
- The rule already exists and controls this behavior
- Changing the default is a single-line fix
- Server admins can re-enable flee if they want via the rule

Also need to add an additional safety check: update the rule_values in the
database to set `CompanionFleeEnabled` to `false` for the user's server, since
the rule default in code only affects new installations.

---

## SECONDARY ISSUE: Combat Positioning Z Coordinate Inconsistency

### The Issue
In the "too far" path of UpdateCombatPositioning (companion.cpp:679):
```cpp
RunTo(goal_x, goal_y, target->GetZ());
```
Uses the **target's** Z coordinate.

In the "too close" retreat path (companion.cpp:694, 705):
```cpp
RunTo(goal_x, goal_y, GetZ());
```
Uses the **companion's** Z coordinate.

### Impact
When the companion and target are on different Z levels (different floors of a
dungeon), the "too far" path sends the companion to coordinates at the target's
elevation, but the XY goal is based only on XY distance. The navmesh pathfinder
may route the companion through a long path to reach the different Z level.

### Severity
LOW — this is unlikely to cause the vanishing behavior by itself, because:
- The Z difference would need to be extreme (different floors)
- Navmesh pathfinding is generally correct even with Z differences
- The "too far" path using target->GetZ() is actually reasonable (the companion
  needs to get to the target's elevation to cast spells)

### Fix (optional)
Consistent Z handling: use the ground Z at the goal XY position:
```cpp
float goal_z = FindDestGroundZ(glm::vec3(goal_x, goal_y, GetZ()));
RunTo(goal_x, goal_y, goal_z);
```

---

## COMBAT POSITIONING MATH ANALYSIS (No Bugs Found)

### "Too Far" Path (dist > 70 units)
**Test: Target at (100,100), Companion at (500,500)**
```
desired_dist = 49, dx = -400, dy = -400, len = 565.685
nx = -0.7071, ny = -0.7071
goal_x = 500 + (-0.7071) * (565.685 - 49) = 134.53
goal_y = 134.53
Distance from goal to target: 48.96 units ✓ (matches desired_dist of 49)
```

### "Too Close" Path (dist < 35 units)
**Test: Target at (100,100), Companion at (110,110)**
```
desired_dist = 49, dx = 10, dy = 10, len = 14.14
nx = 0.7071, ny = 0.7071
goal_x = 100 + 0.7071 * 49 = 134.65
goal_y = 134.65
Distance from goal to target: 48.96 units ✓
```

### "Overlapping" Path (dist < 1 unit)
**Test: Target at (100,100), Companion at (100.5,100.5), Owner at (500,500)**
```
dx = 0.5, dy = 0.5, len = 0.707 (< 1.0, falls to overlap)
ox = 400, oy = 400, olen = 565.685
goal_x = 100 + (400/565.685) * 49 = 134.65
goal_y = 134.65
Distance from goal to target: 48.96 units ✓
```

### "Sweet Spot" Path (35 ≤ dist ≤ 70)
Calls StopNavigation(), FaceTarget(), holds position. ✓

### Boundary Cases
- Companion at exactly 70 units: enters sweet spot ✓
- Companion at exactly 35 units: enters sweet spot (boundary) ✓
- Companion at 34.9 units: enters "too close" path ✓
- Companion at 70.1 units: enters "too far" path ✓

All math is correct. No division-by-zero, no direction reversal, no coordinate
explosion. The UpdateCombatPositioning math is not the cause of the vanishing.

---

## FORMATION FOLLOW vs COMBAT POSITIONING (No Conflict Found)

### Analysis
- Formation follow runs in the IDLE (not-engaged) branch of AI_Process
- Combat positioning runs in the ENGAGED branch
- These are mutually exclusive — they never run in the same tick
- When combat starts, follow stops; when combat ends, follow resumes
- No conflict between the two systems

### m_hold_combat_position Flag
- Reset to false at start of UpdateCombatPositioning()
- Set to true by all caster/healer code paths
- Read correctly in AI_Process to suppress default melee pursuit
- Single-threaded, no race conditions

### AI_PursueCastCheck Override
- Companion overrides AI_PursueCastCheck() to always return false
- This prevents the NPC spell AI from stealing ticks from companion spell AI
- Correctly falls through to m_hold_combat_position branch

---

## SUMMARY OF FINDINGS

| Issue | Severity | Root Cause | Fix |
|-------|----------|------------|-----|
| Wizard flees during combat | **HIGH** | CompanionFleeEnabled defaults to true; wizard drops below 25% HP and runs to random zone location | Change rule default to false |
| Z coordinate inconsistency | LOW | "Too far" path uses target Z, "too close" uses companion Z | Use FindDestGroundZ at goal position |
| Combat positioning math | NONE | All math verified correct with multiple test cases | No fix needed |
| Formation follow conflict | NONE | Idle and engaged branches are mutually exclusive | No fix needed |

### Recommended Fix Priority
1. **Change CompanionFleeEnabled default to false** — this is the vanishing bug
2. **Set rule_values in DB** — ensure the user's running server has the fix
3. Optionally fix Z coordinate inconsistency for correctness

---

## FILES EXAMINED

| File | Lines | What Was Checked |
|------|-------|-----------------|
| eqemu/zone/companion.h | 1-407 | Full header, class definition, m_combat_role |
| eqemu/zone/companion.cpp | 566-714 | UpdateCombatPositioning() — complete function |
| eqemu/zone/companion.cpp | 716-930 | Process(), AI_PursueCastCheck() |
| eqemu/zone/companion.cpp | 759-769 | Flee immunity logic |
| eqemu/zone/mob_ai.cpp | 978-1380 | AI_Process engaged branch |
| eqemu/zone/mob_ai.cpp | 1494-1543 | Formation follow in idle branch |
| eqemu/zone/fearpath.cpp | 28-170 | GetFleeRatio(), CheckFlee(), flee mechanics |
| eqemu/zone/fearpath.cpp | 223-340 | ProcessFlee(), CalculateNewFearpoint() |
| eqemu/zone/npc.cpp | 580-810 | NPC::Process() flow |
| eqemu/zone/mob.h | 726-727, 1105, 1557 | m_hold_combat_position, IsPet() |
| eqemu/zone/position.cpp | 113-122 | DistanceSquaredNoZ implementation |
| eqemu/common/ruletypes.h | 570, 1209-1212 | FleeHPRatio, companion rules |
