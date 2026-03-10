# Combat Positioning AI for Companion Classes

> **Date:** 2026-03-09
> **Context:** Design and implementation plan for class-aware combat positioning.
> Currently all companions close to melee range regardless of class role. Casters
> should stay at range, rogues should circle behind mobs, and only tanks/melee
> should engage from the front.

---

## 1. Current Combat Movement — How It Works Today

### The AI_Process Engaged Path

When a companion is engaged in combat (has a target on its hate list), the
execution path is:

1. `Companion::Process()` (companion.cpp:493) handles stance logic and target
   selection, then calls `NPC::Process()` (npc.cpp:580).
2. `NPC::Process()` calls `Mob::AI_Process()` (mob_ai.cpp:967).
3. Inside `AI_Process()`, when `engaged == true` (line 1030), the AI enters the
   engaged branch.
4. **Combat range check** (line 1151): `bool is_combat_range = CombatRange(target);`
5. **If in combat range** (line 1153): Stop moving, face target, perform melee
   attacks, check engaged cast.
6. **If NOT in combat range** (line 1325): Pursue the target by running to its
   exact position: `RunTo(target->GetX(), target->GetY(), target->GetZ())`
   (line 1349).

### The Problem

The critical line is **mob_ai.cpp:1349**:
```cpp
RunTo(target->GetX(), target->GetY(), target->GetZ());
```

Every engaged mob — regardless of class — runs directly to the target's position.
There is no class check. There is no role differentiation. A wizard companion and
a warrior companion both charge at the mob and stop only when `CombatRange()`
returns true (melee range based on sizes).

### What CombatRange() Computes

`CombatRange()` (aggro.cpp:1123) is a **melee range check**. It computes a
distance threshold based on the size of both mobs, with modifiers for race and
flee state. Typical values:

- Standard humanoid (size 6): threshold ~= `(8*8*4)` = 256 squared distance
  (~16 units actual distance)
- This is melee range — appropriate for warriors and monks, completely wrong
  for a wizard.

### How Companion Spell AI Interacts

The companion spell AI (`Companion::AI_EngagedCastCheck()`, companion.cpp:679)
is called at mob_ai.cpp:1322 when the companion IS in combat range. It routes
through `AICastSpell()` in companion_ai.cpp.

When the companion is NOT in combat range (the pursuit branch), the pursue cast
check `AI_PursueCastCheck()` (mob_ai.cpp:1337) may fire instead, but this is
controlled by `AIautocastspell_timer` and has its own recast logic.

**Key insight:** Caster companions DO attempt to cast spells while pursuing, but
they also continue running toward the mob. If the spell cast finishes before
they reach melee range, great. But they still close to melee range afterward.
There is NO mechanism to make them stop at casting range.

---

## 2. How Existing Systems Handle This

### Bots: `StopMeleeLevel` System

The Bot system has a sophisticated positioning system:

1. **`GetStopMeleeLevel()`** (bot.h): A per-bot setting (default from
   `RuleI(Bots, CasterStopMeleeLevel)`) that defines the level at which a
   caster bot stops closing to melee.

2. **`EvaluateCombatRange()`** (bot.cpp:3133): When `stop_melee_level` is true,
   the bot uses a ranged combat distance instead of melee distance:
   ```cpp
   else if (input.stop_melee_level) { // Casters
       float desired_range = GetBotDistanceRanged();
       o.melee_distance_min = max(o.melee_distance_max, desired_range * 0.75f);
       o.melee_distance     = max(o.melee_distance_max * 1.25f, desired_range);
   }
   ```

3. **`DoCombatPositioning()`** (bot.cpp:12052): Fine-grained positioning with
   options for `behind_only` (rogues), `front_only` (taunters), LoS checks,
   and random position adjustment via `PlotBotPositionAroundTarget()`.

4. **`GetBehindMob()` setting** (bot.h:654): Rogues set this to `true`, causing
   the bot to specifically seek a position behind the target.

### Mercs: Simpler But Similar

The Merc system (merc.cpp) has:

1. **`IsMercCasterCombatRange()`** (merc.cpp:908): Uses `MercAISpellRange` (100
   units) as the distance threshold, halved to 50 units (`range * .5`) to
   prevent always stopping at max range.

2. **Rogue positioning** (merc.cpp:1139): Checks `!BehindMob(GetTarget())` and
   calls `PlotPositionAroundTarget()` to find a position behind the mob.

3. **Archetype-aware spacing** (merc.cpp:1155): Non-rogue non-caster melee
   mobs use `PlotPositionAroundTarget(GetTarget(), ..., false)` with a check
   `GetArchetype() != Archetype::Caster` to spread out at melee range.

### Key Takeaway

Both systems demonstrate the same pattern:
- **Classify the mob by combat role** (melee, caster, rogue)
- **Calculate an appropriate combat distance** based on role
- **Position intelligently** (behind for rogues, ranged for casters, spread for melee)

---

## 3. BehindMob — The Backstab Requirement

### How BehindMob Works

`BehindMob()` (mob.h:224) returns true when `MobAngle() > 90.0f`.

`MobAngle()` (mob.cpp:4577) computes the angle between the target's facing
direction vector and the line from the target to the attacker. An angle > 90
degrees means the attacker is in the rear 180-degree arc.

### Backstab Check in TryBackstab

`TryBackstab()` (special_attacks.cpp:712) checks:
```cpp
if (BehindMob(other, GetX(), GetY())) {
    bIsBehind = true;
}
```

If not behind AND no frontal backstab ability, the backstab fails and converts
to a normal attack. This means a rogue companion that charges to the mob's
front will never backstab — it needs to position behind the mob first.

### Calculating the Behind Position

To calculate a position behind a mob:
```
mob_heading_radians = (mob_heading / 512.0f) * 2 * PI
behind_heading = mob_heading_radians + PI  (opposite direction)

behind_x = mob_x + sin(behind_heading) * desired_distance
behind_y = mob_y + cos(behind_heading) * desired_distance
```

This gives a point directly behind the mob at `desired_distance` units.

---

## 4. Proposed Implementation

### 4.1 Architecture: Override AI_Process in Companion

The cleanest approach is to **NOT modify `Mob::AI_Process()`** (which affects
all NPCs). Instead, add combat positioning logic in `Companion::Process()`
that intercepts the engaged state BEFORE calling `NPC::Process()`.

**Why not modify mob_ai.cpp?** The follow formation code (already merged) was
appropriate to add in mob_ai.cpp because it uses a generic `follow_angle_offset`
mechanism on Mob. But combat positioning is companion-specific — it depends on
companion class, stance, mana state, and owner position. Adding this to
`Mob::AI_Process()` would require `IsCompanion()` checks throughout the engaged
section, polluting the general AI path.

**Proposed approach:** Add a new method `Companion::CombatPositioning()` called
from `Companion::Process()` that runs AFTER stance/target selection but BEFORE
`NPC::Process()`. It overrides the companion's target movement destination
based on class role.

### 4.2 Combat Role Classification

Define combat roles mapped to class:

```cpp
enum class CompanionCombatRole : uint8 {
    MELEE_TANK,     // Warrior, Paladin, Shadow Knight — close range, front
    MELEE_DPS,      // Monk, Berserker, Beastlord, Ranger, Bard — close range, any
    ROGUE,          // Rogue — close range, behind mob
    CASTER_DPS,     // Wizard, Magician, Necromancer, Enchanter — stay at range
    HEALER          // Cleric, Druid, Shaman — stay at range, near owner
};
```

Mapping:
| Class | Role |
|-------|------|
| Warrior | MELEE_TANK |
| Paladin | MELEE_TANK |
| Shadow Knight | MELEE_TANK |
| Monk | MELEE_DPS |
| Berserker | MELEE_DPS |
| Beastlord | MELEE_DPS |
| Ranger | MELEE_DPS |
| Bard | MELEE_DPS |
| Rogue | ROGUE |
| Wizard | CASTER_DPS |
| Magician | CASTER_DPS |
| Necromancer | CASTER_DPS |
| Enchanter | CASTER_DPS |
| Cleric | HEALER |
| Druid | HEALER |
| Shaman | HEALER |

### 4.3 Positioning Logic by Role

#### MELEE_TANK (no change)
Current behavior: charge to melee range, attack from front. This is correct.
No modification needed — `Mob::AI_Process()` handles this natively.

#### MELEE_DPS (no change)
Same as MELEE_TANK. Charge to melee range, attack. Monks, bards, etc. don't
have a backstab requirement. Current behavior is fine.

#### ROGUE (new: circle behind mob)
When engaged and target is alive:
1. Check if already behind the mob via `BehindMob(target, GetX(), GetY())`
2. If not behind: calculate position behind mob at melee distance, `RunTo()` it
3. If behind: let normal AI_Process handle melee attacks
4. Re-check periodically since mob may turn

**Implementation:** Use `PlotPositionAroundTarget()` (already exists on Mob,
used by mercs) with `lookForAftArc = true` to find a position behind the target.

#### CASTER_DPS (new: stop at spell range)
When engaged and target is alive:
1. Calculate distance to target
2. If further than spell range (CompanionAISpellRange = 100): close to range
3. If within spell range (~50-100 units): STOP moving, face target, let spell
   AI handle casting
4. If OOM (mana < 10%): fall through to melee behavior
5. Ideal position: between owner and mob, at ~50 units from mob

**Key challenge:** The current `AI_Process()` engaged branch will always try
to close to melee if we let it run. We need to intercept before it runs.

**Implementation options:**

**Option A: Override Process to skip NPC::Process when caster is at range**
- In `Companion::Process()`, if caster role AND within spell range, handle
  casting and facing directly, then return true WITHOUT calling NPC::Process.
- This means we replicate some NPC::Process logic (timers, regen).
- **Risk:** Missing NPC::Process side effects (buff ticks, poison, etc.)

**Option B: Set a "combat position" target point instead of mob position**
- Add a member `glm::vec3 m_combat_position` that represents where the companion
  should stand during combat.
- In the AI_Process pursue branch (mob_ai.cpp:1344-1355), check if IsCompanion()
  and has a combat position set, and RunTo that position instead of the target.
- **Risk:** Requires modifying mob_ai.cpp, but only one if-check.

**Option C: Use StopNavigation when at range, let engaged cast check fire**
- In `Companion::Process()`, before calling NPC::Process, if caster role AND
  within spell range AND has mana: call StopNavigation() and FaceTarget().
- The mob_ai.cpp engage branch checks `is_combat_range` — if we are NOT in
  melee CombatRange, it enters the pursuit else-branch. BUT if we call
  StopNavigation before NPC::Process runs, the mob will be stationary.
- The pursuit branch only runs movement if `AI_movement_timer->Check()`, so
  StopNavigation alone isn't enough — the next AI tick will try to move again.

**Recommended: Option B (combat position target point)**

This is the cleanest approach. We add a small check in the pursuit section of
`mob_ai.cpp` (the `else` branch at line 1325) to use a custom position for
companions. The companion calculates its ideal combat position in
`Companion::Process()` and stores it. The AI pursuit code uses it.

Actually, re-examining the code flow more carefully:

The `engaged` branch in AI_Process has two sub-paths:
1. `is_combat_range` = true → stop, face, attack, cast (lines 1153-1323)
2. `is_combat_range` = false → pursue (summon check, ranged, chase) (lines 1325-1357)

For casters, we want them to be in state where they DON'T chase to melee, but
DO cast spells. The engaged cast check at line 1322 only fires when
`is_combat_range` is true. The pursue cast check at line 1337 fires when NOT
in combat range.

**Revised approach: Override CombatRange for companions**

The cleanest solution is to make caster companions treat "combat range" as
"spell range" instead of "melee range". If we override or supplement the
`CombatRange()` check for caster companions, they will enter the "in combat
range" branch at spell distance, stop moving, face target, and fire
`AI_EngagedCastCheck()` instead of pursuing to melee.

**Implementation: In Companion::Process(), modify target pursuit behavior**

The most surgical approach that avoids modifying AI_Process:

1. In `Companion::Process()`, BEFORE calling `NPC::Process()`:
   - For CASTER_DPS and HEALER roles with mana:
     - If within spell range of target: call `StopNavigation()`, and set a flag
       `m_hold_combat_position = true`
     - If NOT within spell range: set `m_hold_combat_position = false` (let
       pursuit run, but toward a range position not melee)
   - For ROGUE role:
     - If not behind mob: calculate behind position and `RunTo()` it, then
       `return true` (skip NPC::Process for this tick to prevent the default
       pursue from overriding our movement)

2. The problem with returning early is missing NPC::Process side effects.

**Final recommended approach: Modify the pursue target in mob_ai.cpp**

Add a single check in the pursuit branch (mob_ai.cpp line 1344-1355):

```cpp
// mob/npc waits until call for help complete, others can move
else if (AI_movement_timer->Check() && target &&
        (GetOwnerID() || IsBot() || IsTempPet() ||
        CastToNPC()->GetCombatEvent())) {
    if (!IsRooted()) {
        float pursue_x = target->GetX();
        float pursue_y = target->GetY();
        float pursue_z = target->GetZ();

        // Companions: use class-aware combat position
        if (IsCompanion()) {
            CastToNPC()->CastToCompanion()->GetCombatPursuePosition(
                target, pursue_x, pursue_y, pursue_z);
        }

        LogAIDetail("Pursuing [{}] while engaged", target->GetName());
        RunTo(pursue_x, pursue_y, pursue_z);
    }
    else {
        FaceTarget();
    }
}
```

AND add a companion-specific combat range override so casters/healers consider
themselves "at combat range" when within spell range. This could be done by:

In `Companion::Process()`, before calling `NPC::Process()`:
```cpp
// For caster/healer companions, if within spell range, stop pursuing
// and let the engaged cast check fire
if (GetCombatRole() == CompanionCombatRole::CASTER_DPS ||
    GetCombatRole() == CompanionCombatRole::HEALER) {
    if (IsEngaged() && GetTarget()) {
        float dist_sq = DistanceSquaredNoZ(m_Position, GetTarget()->GetPosition());
        float spell_range = CompanionAISpellRange; // 100 units
        if (dist_sq <= (spell_range * spell_range) && GetManaRatio() > 10.0f) {
            // We're within spell range and have mana — stop and cast
            if (IsMoving()) {
                StopNavigation();
            }
            FaceTarget();
            AI_EngagedCastCheck();
            // Don't fall through to NPC::Process which would try to chase
            // ... but we need NPC::Process for buff ticks, regen, etc.
        }
    }
}
```

The problem remains: we need NPC::Process for side effects but its AI_Process
will override our positioning. Let me think about this differently...

### 4.4 Cleanest Approach: Override in the AI Engaged Path

Looking at the code flow again:

```
Companion::Process()
  → does stance/target selection
  → calls NPC::Process()
    → NPC::Process calls various timers, regen, etc.
    → NPC::Process calls Mob::AI_Process()
      → AI_Process engaged branch
        → is_combat_range? attack : pursue
```

NPC::Process does more than just AI — it handles timers, regen, spell effects,
etc. We cannot skip it.

**Best approach:** Add the positioning logic directly to `Companion::Process()`
and use a flag that AI_Process respects.

Or even simpler: **override CombatRange() virtually for companions.**

Wait — `CombatRange` is not virtual. Let me check...

From mob.h: `bool CombatRange(Mob* other, float fixed_size_mod = 0, bool aeRampage = false, ExtraAttackOptions *opts = nullptr);`

It's NOT virtual. So we can't override it in Companion.

**Alternative: Add a companion combat position member and check it in AI_Process**

The simplest modification to mob_ai.cpp:

1. Add to Mob:
   - `bool m_companion_hold_position = false;` — flag meaning "I'm a caster
     companion at spell range, don't chase"
   - `glm::vec3 m_companion_combat_goal;` — custom pursue target for rogue/caster

2. In Companion::Process(), before NPC::Process(), compute and set these values.

3. In mob_ai.cpp engaged pursuit branch (line 1344):
   ```cpp
   // If companion is holding combat position, don't pursue to melee
   if (m_companion_hold_position) {
       // already at desired range, just face target
       FaceTarget();
   }
   else if (AI_movement_timer->Check() && target && ...) {
       // existing pursue logic, but use m_companion_combat_goal if set
   }
   ```

This is minimal and clean. The flag is set/cleared every tick by
Companion::Process() so it stays synchronized.

### 4.5 Final Recommended Design

#### New Members on Mob (or Companion)

On `Companion` (private):
```cpp
CompanionCombatRole m_combat_role;          // cached combat role
bool               m_at_combat_position;    // true when at desired range
glm::vec3          m_combat_pursue_goal;    // custom pursue position
```

On `Mob` (for AI_Process access, since Companion is not accessible there):
```cpp
bool m_hold_combat_position = false; // companions: don't chase to melee
```

Actually, since AI_Process accesses `this` as a `Mob*`, and Companion is a
subclass, we can check `IsCompanion()` and then access companion-specific
methods. So we don't need to add anything to Mob — we can just add a method
to Companion and call it via `CastToNPC()` cast chain.

But wait — there's no `CastToCompanion()`. Let me check:

Actually, `IsCompanion()` exists as a virtual on Entity. We'd need to add a
cast method. Or we can static_cast if we've already checked IsCompanion().

**Simplest: add one member to Mob**

```cpp
// mob.h
bool m_hold_combat_position = false;
```

This costs 1 byte per mob in memory. All non-companion mobs never set it.
Companion::Process() sets/clears it every tick. AI_Process checks it in the
pursue branch.

#### Implementation Files

| File | Change | Description |
|------|--------|-------------|
| `companion.h` | Add enum, methods | `CompanionCombatRole`, `GetCombatRole()`, `ComputeCombatPosition()` |
| `companion.cpp` | Add positioning logic | Combat role classification, position calculation, set hold flag |
| `mob.h` | Add 1 member | `bool m_hold_combat_position = false;` |
| `mob_ai.cpp` | Add 4-line check | In pursue branch, check `m_hold_combat_position` flag |
| `ruletypes.h` | Add rules | `Companions::CasterCombatRange`, `Companions::RogueBehindMob` |

#### Positioning Logic (in Companion::Process, before NPC::Process call)

```cpp
void Companion::UpdateCombatPositioning()
{
    m_hold_combat_position = false;  // reset each tick

    if (!IsEngaged() || !GetTarget()) {
        return;
    }

    Mob* target = GetTarget();
    CompanionCombatRole role = GetCombatRole();

    switch (role) {
        case CompanionCombatRole::MELEE_TANK:
        case CompanionCombatRole::MELEE_DPS:
            // Default melee behavior — no override needed
            break;

        case CompanionCombatRole::ROGUE: {
            // Try to position behind the mob for backstab
            if (!BehindMob(target, GetX(), GetY())) {
                // Not behind — plot position behind mob
                float newX, newY, newZ;
                if (PlotPositionAroundTarget(target, newX, newY, newZ, true)) {
                    // true = lookForAftArc (behind mob)
                    RunTo(newX, newY, newZ);
                    m_hold_combat_position = true;  // suppress default pursue
                }
            }
            // If already behind, let normal melee AI handle attacks
            break;
        }

        case CompanionCombatRole::CASTER_DPS:
        case CompanionCombatRole::HEALER: {
            float dist_sq = DistanceSquaredNoZ(m_Position, target->GetPosition());
            float spell_range = static_cast<float>(CompanionAISpellRange);
            float range_sq = spell_range * spell_range;
            float half_range_sq = (spell_range * 0.5f) * (spell_range * 0.5f);

            bool has_mana = (GetManaRatio() > 10.0f);

            if (has_mana) {
                if (dist_sq <= range_sq && dist_sq >= half_range_sq) {
                    // Within casting range — hold position
                    if (IsMoving()) {
                        StopNavigation();
                    }
                    FaceTarget();
                    m_hold_combat_position = true;
                }
                else if (dist_sq > range_sq) {
                    // Too far — close to spell range, not melee
                    // Calculate position at ~70% of spell range from target
                    float desired_dist = spell_range * 0.7f;
                    float heading_to_target = CalculateHeadingToTarget(
                        target->GetX(), target->GetY());
                    // Reverse heading (from target TO companion direction)
                    float from_target = std::fmod(heading_to_target + 256.0f, 512.0f);
                    float radians = (from_target / 512.0f) * 6.283184f;
                    float goal_x = target->GetX() + std::sin(radians) * desired_dist;
                    float goal_y = target->GetY() + std::cos(radians) * desired_dist;
                    float goal_z = target->GetZ();

                    RunTo(goal_x, goal_y, goal_z);
                    m_hold_combat_position = true;
                }
                else {
                    // Too close — back away to half spell range
                    // (or just hold and let melee happen if cornered)
                    // For simplicity, hold position and cast
                    if (IsMoving()) {
                        StopNavigation();
                    }
                    FaceTarget();
                    m_hold_combat_position = true;
                }
            }
            // If OOM, m_hold_combat_position stays false → normal melee pursue
            break;
        }
    }
}
```

#### AI_Process Modification (mob_ai.cpp)

In the engaged pursuit `else` branch (around line 1325), add at the top:

```cpp
else {
    // Companion casters/healers: hold position at range
    if (m_hold_combat_position) {
        // Companion has set a custom combat position — don't pursue to melee.
        // The companion's Process() has already handled movement/facing.
        // Still allow ranged attacks and pursue cast checks.
        if (AI_PursueCastCheck()) {
            if (IsCasting() && GetClass() != Class::Bard) {
                StopNavigation();
                FaceTarget();
            }
        }
    }
    // See if we can summon the mob to us
    else if (!HateSummon()) {
        // ... existing code ...
    }
}
```

Wait, that's not quite right because the `HateSummon` and ranged attack checks
should still happen. Let me reconsider the placement.

Actually, looking more carefully at the engaged branch:

```cpp
if (is_combat_range) {
    // MELEE: stop, face, attack, cast
    ...
    AI_EngagedCastCheck();   // <-- casters want this, at range
}
else {
    // NOT IN MELEE RANGE:
    if (!HateSummon()) {
        // ranged attack checks
        if (AI_PursueCastCheck()) { ... }  // <-- casters get this during pursue
        else if (AI_movement_timer->Check() && ...) {
            RunTo(target);  // <-- THIS is what we want to suppress for casters
        }
    }
}
```

The caster companion wants:
- To be treated as "at combat range" when within spell range, even though
  CombatRange() (melee) returns false
- To fire AI_EngagedCastCheck (the full engaged cast logic)
- To NOT RunTo the target

**Revised approach: Modify the is_combat_range check**

Instead of modifying the pursue branch, modify how `is_combat_range` is
evaluated for companions. Add right after line 1151:

```cpp
bool is_combat_range = CombatRange(target);

// Companion casters/healers: treat spell range as combat range
if (!is_combat_range && m_hold_combat_position) {
    is_combat_range = true;
}
```

This way, when a caster companion sets `m_hold_combat_position = true` (because
it's within spell range), the AI treats it as being at combat range. The
companion will:
- Stop moving
- Face the target
- Fire AI_EngagedCastCheck() (spell AI)
- NOT attempt melee attacks (because CombatRange is actually false for melee)

Wait, but the melee attack section checks `is_combat_range` too:
```cpp
if (is_combat_range) {
    if (IsMoving()) { StopNavigation(); }
    FaceTarget();
    // ... melee attack code using attack_timer.Check() ...
    AI_EngagedCastCheck();
}
```

If is_combat_range is true but the companion isn't actually in melee range, the
melee attack code will fire but attacks will miss/fail because the target is too
far. The `Attack()` method itself checks distance and returns false if too far.

Actually, let me check... does `Attack()` check range? Let me look at
`Mob::Attack()` briefly:

Actually, the attacks are guarded by CombatRange earlier. But within the
is_combat_range block, the attacks fire without re-checking range. The attacks
would compute damage and try to apply it, but the target might be too far for
some checks.

**Better approach: don't set is_combat_range for casters. Instead, modify the
pursuit branch to not chase.**

Let's use the simple flag approach in the else branch:

```cpp
else {
    // See if we can summon the mob to us
    if (!HateSummon()) {
        // ... ranged attack checks ...

        if (AI_PursueCastCheck()) {
            if (IsCasting() && GetClass() != Class::Bard) {
                StopNavigation();
                FaceTarget();
            }
        }
        else if (m_hold_combat_position) {
            // Companion is at desired combat range — don't pursue to melee
            // Just face the target and let companion Process handle casting
            if (!IsMoving()) {
                FaceTarget();
            }
        }
        else if (AI_movement_timer->Check() && target &&
                (GetOwnerID() || IsBot() || IsTempPet() ||
                CastToNPC()->GetCombatEvent())) {
            if (!IsRooted()) {
                LogAIDetail("Pursuing [{}] while engaged", target->GetName());
                RunTo(target->GetX(), target->GetY(), target->GetZ());
            }
            else {
                FaceTarget();
            }
        }
    }
}
```

The caster companion will:
- AI_PursueCastCheck fires on its timer → tries to cast offensive spells
- When the timer isn't firing: checks `m_hold_combat_position` → faces target
- Does NOT run to melee range
- Companion::Process() calls AI_EngagedCastCheck() separately (companion.cpp:679)
  ... wait, no. AI_EngagedCastCheck is called at mob_ai.cpp:1322 only when
  `is_combat_range` is true. We're in the else branch here.

**The engaged cast check problem:** `AI_EngagedCastCheck()` at line 1322 only
fires when `is_combat_range` is true (melee range). For caster companions at
spell range, this never fires. They only get `AI_PursueCastCheck()` which has
different spell type priorities.

We have two options:
1. Call `AI_EngagedCastCheck()` explicitly from the `m_hold_combat_position`
   branch (treating the companion as "at combat range" for spell purposes)
2. Rely on `AI_PursueCastCheck()` which already handles offensive casting

Option 1 is better because the engaged cast check may have different behavior
(e.g., heal checks, buff checks during combat). Let's add it:

```cpp
else if (m_hold_combat_position) {
    // Companion is at desired combat range — don't pursue to melee
    if (!IsMoving()) {
        FaceTarget();
    }
    AI_EngagedCastCheck();  // Allow full engaged spell AI
}
```

This is clean and correct.

---

## 5. Summary of Changes

### File: `companion.h`
- Add `CompanionCombatRole` enum
- Add `GetCombatRole()` method
- Add `UpdateCombatPositioning()` method declaration

### File: `companion.cpp`
- Implement `GetCombatRole()`: switch on `GetClass()`, return role enum
- Implement `UpdateCombatPositioning()`:
  - MELEE_TANK/MELEE_DPS: no-op
  - ROGUE: check BehindMob, PlotPositionAroundTarget if needed
  - CASTER_DPS/HEALER: check distance to target, stop at spell range if has mana
- Call `UpdateCombatPositioning()` in `Process()` before `NPC::Process()` call

### File: `mob.h`
- Add `bool m_hold_combat_position = false;` member

### File: `mob_ai.cpp`
- In the engaged else branch (not at combat range), add check for
  `m_hold_combat_position` between `AI_PursueCastCheck()` and the pursue
  movement code

### File: `ruletypes.h`
- `RULE_INT(Companions, CasterCombatRange, 70, "Distance in game units that caster companions maintain from targets in combat (0 = use default melee behavior)")`
- `RULE_BOOL(Companions, RogueBehindMob, true, "Whether rogue companions attempt to position behind their target for backstab")`

---

## 6. Edge Cases

### Caster OOM
When `GetManaRatio() <= 10.0f`, `m_hold_combat_position` stays false, and the
caster companion pursues to melee range like a normal NPC. This is the desired
fallback — an OOM wizard should wade in with a staff rather than standing at
range doing nothing.

### Target Moves Away from Caster
If the mob moves out of spell range (chasing the player), the caster companion's
`UpdateCombatPositioning()` detects `dist_sq > range_sq` and computes a new
position at 70% of spell range from the target, then RunTo's it. The
`m_hold_combat_position` is set true so the default pursue is suppressed.

### Rogue Target Turns
If the mob turns to face the rogue companion, `BehindMob()` returns false next
tick, and the rogue recalculates a behind position. This creates the "circling"
behavior naturally.

### Multiple Companions Fighting Same Mob
Each companion independently positions. Two rogue companions might cluster behind
the same mob. Two caster companions will independently stop at range. This is
acceptable for 1-3 players with max 5 companions.

### AE Damage at Caster Range
Casters standing 50-70 units away will generally be out of PBAE range (which is
usually < 35 units). This is a natural benefit of ranged positioning.

### Guard Mode
In guard mode, the companion doesn't follow and doesn't pursue. Combat
positioning is irrelevant. Guard mode sets `follow_id = 0` and stays put.

### Formation After Combat
When combat ends (target dies), `IsEngaged()` returns false next tick.
`UpdateCombatPositioning()` is a no-op when not engaged. The companion falls
through to `NPC::Process()` → `AI_Process()` idle branch → follow formation
logic. The formation offset from the existing formation system handles
out-of-combat positioning.

---

## 7. Implementation Sequence

1. **`companion.h`** — Add `CompanionCombatRole` enum, `GetCombatRole()`,
   `UpdateCombatPositioning()`, and `m_at_combat_position` flag
2. **`mob.h`** — Add `bool m_hold_combat_position = false;`
3. **`companion.cpp`** — Implement `GetCombatRole()` and
   `UpdateCombatPositioning()`. Call from Process() before NPC::Process()
4. **`mob_ai.cpp`** — Add `m_hold_combat_position` check in engaged else
   branch, with `AI_EngagedCastCheck()` call
5. **`ruletypes.h`** — Add `CasterCombatRange` and `RogueBehindMob` rules
6. **Build and test**

---

## 8. Test Plan

1. **Warrior companion** — should charge to melee, no behavior change
2. **Rogue companion** — should circle behind mob and backstab. Use `#hatelist`
   to verify backstab damage is applying. Use `#show field_of_view` to verify
   position relative to target
3. **Wizard companion** — should stop ~70 units from mob, cast spells. Should
   NOT close to melee while it has mana. When OOM, should close to melee
4. **Cleric companion** — should stay at range, heal group members. Should not
   charge into melee
5. **Multi-companion** — recruit a warrior + wizard. Warrior charges in, wizard
   stays back. Verify both fight effectively
6. **Mob chases player** — wizard companion should adjust position to maintain
   spell range from target as it moves
7. **Guard mode** — should not affect combat positioning (guard stays at guard
   point regardless)
8. **Passive mode** — should disengage and not position at all

---

## 9. Summary

| Question | Answer |
|----------|--------|
| Where is combat movement controlled? | `mob_ai.cpp:1344-1355` — `RunTo(target)` in pursue branch |
| How to override per class role? | `Companion::UpdateCombatPositioning()` sets `m_hold_combat_position` flag and handles custom movement |
| Rogue positioning? | `BehindMob()` check + `PlotPositionAroundTarget(target, ..., true)` |
| Caster positioning? | Distance check vs `CompanionAISpellRange`, StopNavigation when in range |
| Healer positioning? | Same as caster — stay at spell range |
| OOM fallback? | `GetManaRatio() <= 10%` → don't set hold flag → normal melee pursue |
| Files changed | `companion.h`, `companion.cpp`, `mob.h`, `mob_ai.cpp`, `ruletypes.h` |
| Risk | Low-medium — modifies mob_ai.cpp with a single conditional branch |
