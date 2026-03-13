# Companion Behavior Improvements — Architecture & Implementation Plan

> **Feature branch:** `feature/companion-behavior-improvements`
> **PRD:** `game-designer/context/brainstorm-notes.md` (bug reports serve as PRD)
> **Author:** architect
> **Date:** 2026-03-12
> **Updated:** 2026-03-12 (added BUG-026, BUG-027)
> **Status:** Approved

---

## Executive Summary

This plan addresses five companion behavior bugs: (1) rogue companions take an
unnecessarily wide arc to get behind enemies for backstab, getting stuck on
geometry; (2) caster companions silently run out of mana with no LOM announcement;
(3) the `!buffs` command only buffs the player instead of all party members;
(4) caster companions lose line-of-sight in indoor/confined spaces by running to
a fixed distance without LOS validation; (5) companions should always regenerate
mana at meditation rates regardless of sitting/standing/combat state for playability.
Bugs 1, 2, 4, and 5 require C++ fixes. Bug 3 requires a Lua rewrite. Bug 5 adds
a new rule to gate the fun-over-authenticity decision.

## Existing System Analysis

### Current State

**Rogue positioning (BUG-023):**
The rogue combat role is defined in `companion.h:65` as `COMBAT_ROLE_ROGUE`.
The positioning logic lives in `companion.cpp:1306-1323` inside
`UpdateCombatPositioning()`. It calls `PlotPositionAroundTarget()` (defined in
`mob.cpp:4767-4841`) with `lookForAftArc=true` to find a position behind the
target. The `BehindMob()` check (`mob.h:224`) uses angle calculation (>90 degrees
from target's facing = behind). The `RogueBehindMob` rule (`ruletypes.h:1214`)
gates this behavior.

`PlotPositionAroundTarget()` calculates the destination relative to the **rogue's**
current position using `GetX() + targetSize * sin(heading)`. This means it plots
a point at "target size" distance from the rogue along the reciprocal heading,
NOT a point directly behind the target mob. For targets far from the rogue, this
creates a destination that isn't actually behind the target, forcing repeated
recalculations and wide arcing paths.

**Caster LOM announcement (BUG-024):**
Companions already have `m_mana_report_timer` (15-second interval) that fires
while sitting and out of combat (`companion.cpp:1641-1648`), announcing current
mana percentage via `CompanionGroupSay`. There is no in-combat LOM announcement.
The `CompanionGroupSay()` static method (`companion.cpp:2263-2279`) sends a message
to the group via `GroupMessage()`. Casters in combat have a 10% mana threshold
check for positioning (`companion.cpp:1334`) that stops them from running into
melee, but this is silent.

**!buffs party scope (BUG-025):**
The `!buffs` command flow:
1. `companion.lua:983` sets `buff_request_target = "party"` entity variable
2. `global_npc.lua:403-524` timer handler fires 2 seconds later
3. Handler builds target list via `group:GetMember(i)` for i=0..5 (includes both
   clients and NPC companions)
4. Queries `companion_spell_sets` for buff spells
5. Nested loop: for each spell row, for each target, calls `CastSpell()`

The bug is in step 5. `CastSpell()` (`spells.cpp:146`) sets `casting_spell_id`
(line 310) on the first successful call. All subsequent calls in the same tick
find `casting_spell_id != 0` (line 165) and silently return false. Only the
first spell on the first target (the player) succeeds. The rest fail.

**Caster LOS positioning (BUG-026):**
The caster/healer combat positioning code in `companion.cpp:1326-1404`
(`UpdateCombatPositioning()`, COMBAT_ROLE_CASTER_DPS/HEALER case) calculates
a desired position at `CasterCombatRange` (default 70 units) from the target
using simple vector math. Three distance cases are handled:

1. Sweet spot (50%-100% of range): hold position and face target
2. Too far (>100%): close to 70% of desired range
3. Too close (<50%): retreat to 70% of desired range

**None of these cases check line-of-sight to the target from the destination
position.** In indoor/confined zones (dungeons, buildings, corridors), the
goal position may be behind a wall, around a corner, or on the other side of
an obstruction. The companion runs there via navmesh pathing (which routes
around obstacles), arrives at the destination, and then cannot see the target
to cast spells. The caster becomes useless.

The server has `CheckPositioningLosFN(Mob* other, float x, float y, float z)`
(aggro.cpp:1327) which checks LOS from an arbitrary position to a mob, using
the caller's size for height calculation. This function exists and is designed
exactly for this use case but is not currently called in the caster positioning
code.

**Always-meditate mana regen (BUG-027):**
The mana regen calculation in `Companion::CalcManaRegen()` (companion.cpp:1125-1158)
uses the meditate formula only when `IsSitting()` returns true AND the companion
is a non-melee archetype:

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
regen (at level 60 with 252 meditate: ~38/tick vs base 2/tick). This makes
companion casters perpetually mana-starved in combat, requiring micromanagement
of sit/stand states that is impractical in a 1-3 player small-group setting.

This is called from `NPC::Process()` (npc.cpp:693-696) on each 6-second tic.
The `CalcManaRegen()` function itself gates the meditate formula behind
`IsSitting()`.

The user explicitly chose fun over authenticity: companions should ALWAYS
get meditation-rate mana regen regardless of stance or combat state.

### Gap Analysis

| Requirement | Current State | Gap |
|---|---|---|
| Rogue positions directly behind mob | Uses PlotPositionAroundTarget which plots from rogue's pos | Need direct geometric calculation from target's position |
| Rogue 1-2 units behind (not overlapping) | PlotPositionAroundTarget uses target size as offset distance | Need configurable backstab distance parameter |
| LOM announcement at 15% mana | No in-combat mana announcement exists | Need flag + threshold check in Process() |
| LOM once per state (not spam) | N/A | Need boolean flag that resets when mana recovers |
| !buffs casts on all party members | Only first CastSpell per tick succeeds | Need sequential casting (one spell per timer tick) |
| Caster maintains LOS to target | No LOS check in caster positioning code | Need CheckPositioningLosFN validation before committing to position |
| Companions always regen at meditate rate | CalcManaRegen gates meditate formula behind IsSitting() | Remove sitting gate (behind a rule toggle) |

## Technical Approach

### Architecture Decision

| Component | Change Type | Justification |
|---|---|---|
| `companion.cpp` (C++) | Modify `UpdateCombatPositioning()` rogue case | Positioning algorithm is C++ core logic; cannot be done in Lua |
| `companion.h` (C++) | Add `m_lom_announced` flag | State tracking for LOM must persist across ticks in C++ |
| `companion.cpp` (C++) | Add LOM check in `Process()` | Mana monitoring runs every tick in C++ Process loop |
| `global_npc.lua` (Lua) | Rewrite buff timer handler | Buff casting is entirely Lua quest script logic |
| `ruletypes.h` (C++) | Add `LOMThresholdPct` rule | Tunable threshold follows least-invasive-first principle |
| `companion.cpp` (C++) | Add LOS validation to caster positioning | LOS check is a C++ core AI function; must be in the positioning code |
| `companion.cpp` (C++) | Remove IsSitting() gate in CalcManaRegen() | Mana regen calculation is C++ core logic |
| `ruletypes.h` (C++) | Add `AlwaysMeditateRegen` rule | Fun-over-authenticity decision should be toggleable via rule |

### Data Model

No new database tables or columns required. All changes are runtime behavior
modifications.

### Code Changes

#### C++ Changes

**File: `eqemu/zone/companion.h`**
- Add private member: `bool m_lom_announced = false;` — tracks whether LOM has
  been announced for the current low-mana state
- Initialize to false in constructor

**File: `eqemu/zone/companion.cpp`**

*BUG-023 fix — `UpdateCombatPositioning()` rogue case (lines 1306-1323):*

Replace the `PlotPositionAroundTarget` call with direct geometric calculation:

```
1. Get target's heading (the direction the target faces)
2. Calculate the "behind" direction: target_heading + 180 degrees (reciprocal)
3. Compute destination: target_position + behind_direction * backstab_distance
   where backstab_distance = melee_range + 2.0 units (configurable offset)
4. Verify LoS to destination via CheckLosFN
5. If LoS fails, try positions at +/- 30 degrees from directly behind
6. RunTo the valid destination
```

This calculates the destination relative to the TARGET's position and facing,
not relative to the rogue. The rogue gets a direct path to a point behind the
mob, eliminating the wide arc.

The backstab_distance offset of ~2 units behind the mob ensures the rogue
stands a step behind (not on the same spot), as the user requested.

*BUG-024 fix — `Process()` method, after the existing mana report block:*

Add LOM announcement logic:

```cpp
// LOM announcement: casters/healers announce once when mana drops to threshold
if (IsEngaged() &&
    (m_combat_role == COMBAT_ROLE_CASTER_DPS || m_combat_role == COMBAT_ROLE_HEALER) &&
    GetMaxMana() > 0) {
    float lom_threshold = static_cast<float>(RuleI(Companions, LOMThresholdPct));
    if (GetManaRatio() <= lom_threshold) {
        if (!m_lom_announced) {
            CompanionGroupSay(this, "LOM");
            m_lom_announced = true;
        }
    } else {
        m_lom_announced = false;  // Reset when mana recovers above threshold
    }
}
```

*BUG-026 fix — `UpdateCombatPositioning()` caster/healer case (lines 1326-1404):*

Add LOS validation to the "too far" and "too close" branches. After calculating
the goal position, verify LOS from that position to the target. If LOS fails,
iteratively step closer to the target until a valid LOS position is found.

Algorithm for the "too far" and "too close" cases:

```
1. Calculate goal position at 70% of CasterCombatRange (same as current code)
2. Call CheckPositioningLosFN(target, goal_x, goal_y, goal_z)
3. If LOS passes: RunTo(goal) as before
4. If LOS fails: iteratively reduce distance by 10% of desired_range toward
   the target, checking LOS at each step
5. Minimum distance: 20% of CasterCombatRange (to avoid standing on top of mob)
6. If no valid LOS position found: StopNavigation() + FaceTarget() — hold
   current position rather than running to a blind spot
```

Also add a LOS re-check in the "sweet spot" (50%-100%) hold condition:

```
After confirming distance is in sweet spot:
1. Call CheckLosFN(target) from current position
2. If LOS is valid: hold as before
3. If LOS is lost: recalculate position (move closer until LOS restored)
```

This prevents the caster from holding a position where they cannot see the
target (e.g., target moved behind a pillar while caster held position).

*BUG-027 fix — `CalcManaRegen()` (lines 1143-1149):*

Replace the `IsSitting()` gate with a rule-aware check:

```cpp
// If AlwaysMeditateRegen is enabled, casters always use the meditate formula.
// Otherwise, only sitting non-melee casters get meditation rates.
if (RuleB(Companions, AlwaysMeditateRegen) || IsSitting()) {
    if (GetArchetype() != Archetype::Melee) {
        uint16 meditate = GetSkill(EQ::skills::SkillMeditate);
        regen = (((meditate / 10) + (level - (level / 4))) / 4) + 4;
    }
}
```

This is a single conditional change. When `AlwaysMeditateRegen` is true
(default), the sitting check is bypassed — caster companions always regen
at meditation rates. Setting the rule to false restores authentic behavior.

**File: `eqemu/common/ruletypes.h`**
- Add under `RULE_CATEGORY(Companions)`:
  `RULE_INT(Companions, LOMThresholdPct, 15, "Mana percentage at or below which caster companions announce LOM in group chat")`
  `RULE_BOOL(Companions, AlwaysMeditateRegen, true, "When true, companion casters always regenerate mana at meditation rates regardless of sitting/standing/combat state. Fun-over-authenticity setting for small-group play.")`

#### Lua/Script Changes

**File: `akk-stack/server/quests/global/global_npc.lua`**

*BUG-025 fix — buff timer handler (lines 403-524):*

Rewrite the buff timer handler to use a sequential casting queue instead of
firing all CastSpell calls in a single tick.

New approach:
1. On first timer fire, query companion_spell_sets and build a queue of
   `{spell_id, target_id}` pairs stored as a JSON string in an entity variable
2. Each timer tick: pop one pair from the queue, call CastSpell for that
   single pair, re-arm the timer for 1 second (or spell cast time + margin)
3. When the queue is empty, clear the entity variables and stop
4. If companion enters combat or the queue times out (30 retries), abort

Entity variables used:
- `buff_queue` — JSON array of `[spell_id, target_id]` pairs
- `buff_queue_idx` — current index into the queue
- `buff_request_target` — existing variable ("owner" or "party")
- `buff_request_retries` — existing retry counter

The timer re-fires every 2000ms (matching existing retry interval), giving
each CastSpell enough time to complete before the next one fires.

#### Database Changes

None required.

#### Configuration Changes

Two new rule values:
- `Companions:LOMThresholdPct` = 15 (default) — mana percentage for LOM announcement
- `Companions:AlwaysMeditateRegen` = true (default) — always use meditate regen rate

Both auto-populate from ruletypes.h defaults. No manual DB insert needed.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | BUG-023: Replace rogue backstab positioning with direct geometric calculation in `UpdateCombatPositioning()` | c-expert | — | ~40 lines modified in companion.cpp |
| 2 | BUG-024: Add `m_lom_announced` flag to companion.h and LOM check logic in companion.cpp Process() | c-expert | — | ~15 lines in .h, ~20 lines in .cpp |
| 3 | BUG-024: Add `LOMThresholdPct` rule to ruletypes.h | c-expert | 2 | ~1 line |
| 4 | BUG-025: Rewrite buff timer handler in global_npc.lua to sequential queue | lua-expert | — | ~80 lines modified |
| 5 | BUG-026: Add LOS validation to caster/healer positioning in `UpdateCombatPositioning()` | c-expert | — | ~30 lines modified in companion.cpp |
| 6 | BUG-027: Remove IsSitting() gate in `CalcManaRegen()`, add `AlwaysMeditateRegen` rule | c-expert | — | ~3 lines in companion.cpp, ~1 line in ruletypes.h |

Tasks 1-3, 5, 6 (C++) are independent from Task 4 (Lua) and can be worked in parallel.
All C++ tasks are independent of each other. Task 3 is trivially dependent on
Task 2 (same file area). Tasks 5 and 6 are self-contained changes in distinct
code sections.

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Rogue new positioning clips through geometry | Medium | Medium | Use CheckLosFN validation; fall back to current behavior if no valid position found |
| Rogue backstab distance too close/far | Low | Low | Test with different mob sizes; the 2-unit offset may need tuning |
| LOM spam if mana oscillates near threshold | Low | Low | Boolean flag ensures one announcement per transition; hysteresis inherent in the > check |
| Buff queue entity variable exceeds max length | Low | Low | Companion buff spell lists are typically 5-15 entries x 6 targets = 30-90 pairs; well within entity variable limits |
| CastSpell returns false for NPC-to-NPC buff casting | Medium | High | Verify DoCastingChecksOnTarget allows beneficial spells on NPC group members. If it rejects, may need SpellFinished() instead |
| Caster LOS check performance with iterative fallback | Low | Low | Maximum 6 LOS checks per positioning call (70% down to 20% in 10% steps). CheckPositioningLosFN is fast (single raycast). This runs once per tick for engaged casters only. |
| Caster oscillates between positions when target is near LOS boundary | Low | Medium | The "sweet spot" hold condition (50%-100% range with LOS) prevents repositioning when already in a valid spot. Only re-evaluate if LOS is lost. |
| AlwaysMeditateRegen makes companion casters overpowered | Low | Low | This is an intentional design decision for small-group play. The CompanionManaRegenMult rule (default 100%) can be reduced if regen is too fast. The behavior is gated behind a rule toggle. |

### Compatibility Risks

None of these changes modify existing packets, database schema, or client-facing
protocol. All changes are server-side behavioral modifications.

- BUG-023: Falls back to default melee pursuit if the new positioning calculation
  fails (no valid LoS position found behind target)
- BUG-024: Gated behind a new rule with sensible default; disable by setting to 0
- BUG-025: The sequential queue produces the same end result as the intended
  behavior of the original code; only the timing changes
- BUG-026: Falls back to holding current position if no LOS-valid position found.
  This is strictly better than the current behavior of running to a blind spot.
- BUG-027: Gated behind `AlwaysMeditateRegen` rule (default true). Set to false
  to restore authentic behavior. No impact on non-companion NPCs.

### Performance Risks

Minimal. BUG-023 replaces one `PlotPositionAroundTarget` call (4 iterations
with LoS checks) with a simpler trigonometric calculation plus one LoS check.
BUG-024 adds one float comparison per tick for engaged casters. BUG-025
changes the timer from a single heavy tick to multiple lightweight ticks.
BUG-026 adds at most 6 `CheckPositioningLosFN` calls per tick for engaged
casters repositioning — each is a single zone map raycast, very fast. BUG-027
changes a single conditional in a function called once per 6-second tic.

## Review Passes

### Pass 1: Feasibility

**BUG-023:** The rogue positioning code in companion.cpp is well-isolated in the
`COMBAT_ROLE_ROGUE` switch case. The fix replaces the `PlotPositionAroundTarget`
call with direct math. `GetHeading()`, `GetX()`, `GetY()`, `GetZ()`, `RunTo()`,
and `CheckLosFN()` are all available on `Mob*` and confirmed in the source. The
`BehindMob()` check at line 1311 continues to serve as the "am I already behind?"
guard. Fully feasible.

**BUG-024:** `CompanionGroupSay()` already exists and works. Adding a private
boolean member to the class is trivial. The Process() method already has mana
monitoring code (sitting mana report) that this mirrors. Adding a new rule to
ruletypes.h is mechanical. Fully feasible.

**BUG-025:** The buff timer handler is pure Lua. Entity variables provide the
storage mechanism. The existing `eq.set_timer` / `eq.stop_timer` API supports
the sequential approach. The `json` Lua module is available via
`require("json")` for serializing the queue. Fully feasible.

**BUG-026:** `CheckPositioningLosFN(Mob*, float, float, float)` is declared in
`mob.h:807` and implemented in `aggro.cpp:1327`. It checks LOS from an arbitrary
position (x,y,z) to a mob, using the caller's size for height. Since `Companion`
inherits from `NPC` which inherits from `Mob`, this method is directly available
in the `UpdateCombatPositioning()` context as `this->CheckPositioningLosFN()`.
The caster positioning code is isolated in the `COMBAT_ROLE_CASTER_DPS/HEALER`
case of the same switch statement as the rogue fix. Fully feasible.

**BUG-027:** `CalcManaRegen()` is a clearly delineated function
(companion.cpp:1125-1158) with the `IsSitting()` check at line 1144. The fix
is a single conditional change: `if (RuleB(...) || IsSitting())`. Adding a
new `RULE_BOOL` to ruletypes.h is mechanical. The function is called from
`NPC::Process()` at npc.cpp:693-696 only for companions, so the rule change
has no side effects on other NPCs. Fully feasible.

**Protocol-agent assessment:** None of these bugs involve client-server packets
or Titanium wire format. All changes are server-side AI behavior (C++) and
quest script logic (Lua). No protocol constraints apply.

**Config-expert assessment:** Two new rules are appropriate:
- `Companions:LOMThresholdPct` (INT, default 15): No existing rule covers LOM.
- `Companions:AlwaysMeditateRegen` (BOOL, default true): No existing rule covers
  always-meditate. The related `CompanionManaRegenMult` (100%) is a multiplier
  that stacks multiplicatively and remains useful as a scaling knob.

### Pass 2: Simplicity

**BUG-023:** The simplest fix is direct trigonometry from the target's position.
The existing `PlotPositionAroundTarget` is an overly complex iterative approach
designed for general-purpose use. A purpose-built calculation is simpler, more
predictable, and produces better results for this specific use case.

Could this be deferred? No — the rogue getting stuck on geometry makes the class
non-functional in confined zones.

**BUG-024:** A single boolean flag and a threshold check is the minimal approach.
Alternative considered: Lua timer-based approach. Rejected because the mana check
must run every Process() tick to catch the exact transition point; a Lua timer
would miss transitions or add latency.

**BUG-025:** The sequential queue is the simplest fix for the "only first CastSpell
succeeds" problem. Alternative considered: using `SpellFinished()` (instant cast)
instead of `CastSpell()`. Rejected because `SpellFinished()` bypasses mana cost,
resist checks, and fizzle — it would make buffing "free" and instantaneous, which
feels wrong. The sequential approach preserves normal casting behavior.

**BUG-026:** Adding LOS checks to existing positioning code is the minimal fix.
Alternative considered: using navmesh path validity as a proxy for LOS. Rejected
because navmesh paths can route around obstacles (the problem is that they DO
route around obstacles — the companion arrives but cannot see the target). LOS
raycasting directly answers the question "can the caster see the target from
this position?"

Alternative considered: using a different caster positioning algorithm entirely
(e.g., pick the closest open spot to the target within spell range). Rejected
as overengineered — the current distance-based approach is sound, it just needs
LOS validation.

Could this be deferred? No — casters becoming non-functional in dungeons is a
high-severity issue for dungeon crawling gameplay.

**BUG-027:** A single conditional change in `CalcManaRegen()` gated behind a rule
is the absolute minimal fix. Alternative considered: increasing `CompanionManaRegenMult`
to 500% or higher. Rejected because multiplying a base of 2 still gives much less
than the meditate formula (~38 at level 60). The multiplier affects both standing
and sitting regen equally, so it would make sitting regen absurdly high while
standing regen would still be inadequate. The root cause is the formula difference,
not the multiplier.

Alternative considered: making companions automatically sit/stand during combat
(sit when not casting, stand to cast). Rejected as too complex — this is the exact
micromanagement the user wants to eliminate.

### Pass 3: Antagonistic

**BUG-023 edge cases:**
- What if the mob is against a wall? The LoS check will fail for directly behind.
  Mitigation: try +/- 30 degree offsets. If all three fail, do NOT set
  `m_hold_combat_position` — let the rogue fall through to default melee behavior.
- What if the target spins rapidly? The rogue will chase the "behind" position
  each tick. This is acceptable and matches real player rogue behavior.
- What if the target is very large (dragon)? The backstab_distance should use
  `target->GetSize() / 2 + offset` to account for the model radius. A naked
  offset would put the rogue inside large mobs.
- Server crash mid-positioning? No persistent state; the rogue will recalculate
  on the next tick after restart. No risk.

**BUG-024 edge cases:**
- What if companion gains a mana item mid-combat that pushes ratio above 15%
  then it drops again? The flag resets above threshold and re-announces below.
  This is correct behavior — a meaningful state change occurred.
- What if companion dies while LOM? Flag is irrelevant on dead companions.
  On resurrection/respawn, the flag initializes to false.
- Can LOM be exploited? No — it's a group chat message with no gameplay effect.

**BUG-025 edge cases:**
- What if companion enters combat mid-buff-queue? The existing
  `e.self:IsEngaged()` check at line 438 handles this — the timer retries
  until combat ends or retries exhaust (30 max).
- What if a target dies or zones mid-queue? The `target.valid` check must be
  re-verified each tick before casting. Invalid targets should be skipped.
- What about buff stacking? The engine's CanBuffStack check still applies.
  Duplicate buffs will be silently rejected, which is correct.
- What if the player issues !buffs again while a queue is in progress? The
  new request should overwrite the existing queue. The entity variable
  mechanism inherently handles this — setting new values replaces old ones.

**BUG-026 edge cases:**
- What if every position toward the target fails LOS? This happens in complex
  geometry (multi-level dungeons, spiral staircases). Mitigation: fall back to
  holding current position and facing target. A caster standing in place and
  casting from current position (if they have LOS) is better than running to a
  blind spot. If they don't have LOS from current position either, the situation
  is no worse than before the fix.
- What if the target is directly above/below (different floor level)? The LOS
  check uses Z-coordinates with head/eye position offsets, so it will correctly
  detect floor/ceiling obstructions. The caster will hold position since no
  reachable XY position will have vertical LOS through a floor.
- What about rapidly moving targets (kiting)? The positioning recalculates each
  tick. If the target moves from behind a pillar to open space, the next tick
  will find a valid LOS position and the caster will resume movement. Response
  is one tick (~250ms) which is acceptable.
- Caster holds position but can't actually cast (range + LOS but target moved)?
  The spell casting system has its own LOS check. If the caster tries to cast
  and fails the spell's LOS check, the spell fails and the caster tries again
  next tick. The positioning code sets `m_hold_combat_position` but the spell AI
  runs independently.

**BUG-027 edge cases:**
- Does this affect bards? No — bards have a separate code path in CalcManaRegen()
  (companion.cpp:1137-1140) that returns before reaching the meditate check.
  The fix only affects the `IsSitting()` gate for non-melee casters.
- Does this affect melee classes with mana (rangers, paladins, shadow knights)?
  No — the `GetArchetype() != Archetype::Melee` check remains. Hybrid melee
  classes get the flat base rate regardless. This is intentional: their mana
  usage is supplementary (they primarily melee), and the meditate formula would
  be too generous for classes that also deal full melee damage.
- What if CompanionManaRegenMult is set very high alongside AlwaysMeditateRegen?
  At CompanionManaRegenMult=200 + AlwaysMeditateRegen=true, a level 60 caster
  would regen ~76 mana/tick (38 base * 2). With ~5000 max mana, that's full
  mana in ~66 ticks (~6.6 minutes). This is reasonable for small-group play.
  The user can tune CompanionManaRegenMult independently if needed.
- Server crash during regen tick? No persistent state involved — CalcManaRegen()
  is a pure calculation called every tick.

### Pass 4: Integration

**Dependency order:**
1. Tasks 1-3 and 5-6 (C++, c-expert) and Task 4 (Lua, lua-expert) have zero
   interdependencies. They modify separate files in separate repositories.
2. Tasks 5 and 6 are completely independent of tasks 1-3 — they modify different
   functions in companion.cpp and separate sections of ruletypes.h.
3. After all complete: rebuild the server binary (for C++ changes) and
   `#reloadquest` (for Lua changes).
4. Testing must happen AFTER all tasks are complete because the user should
   validate all five fixes together.

**Build considerations:**
- C++ changes require `ninja` rebuild inside the Docker container
- Lua changes are hot-reloadable via `#reloadquest`
- Rule changes in ruletypes.h require rebuild; default values take effect
  automatically on first boot

**Expert context requirements:**
- c-expert needs: companion.h, companion.cpp (UpdateCombatPositioning() and
  Process() and CalcManaRegen() sections), mob.h (BehindMob, PlotPositionAroundTarget,
  CheckPositioningLosFN), ruletypes.h Companions category
- lua-expert needs: global_npc.lua buff timer handler, companion.lua cmd_buffs,
  understanding of CastSpell single-tick limitation

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | Tasks 1, 2, 3, 5, 6 (BUG-023 rogue positioning, BUG-024 LOM announcement + rule, BUG-026 caster LOS positioning, BUG-027 always meditate regen + rule) | All five are C++ source modifications in zone/ and common/ |
| lua-expert | Task 4 (BUG-025 buff queue rewrite) | Lua quest script modification in global_npc.lua |

## Validation Plan

- [ ] **BUG-023:** Recruit a rogue companion, engage a mob in an open area. Verify the rogue takes a direct path behind the mob (not a wide arc). Verify the rogue stands 1-2 units behind the mob, not overlapping.
- [ ] **BUG-023:** Recruit a rogue companion, engage a mob in a confined corridor. Verify the rogue does not get stuck on walls. Verify the rogue falls back to melee if no valid behind-position exists.
- [ ] **BUG-023:** Engage a large mob (dragon or similar). Verify the rogue accounts for model size and doesn't clip inside the mob.
- [ ] **BUG-024:** Recruit a caster companion (cleric, wizard, shaman). Engage in extended combat. Verify "LOM" appears in group chat when mana drops to 15% or below.
- [ ] **BUG-024:** Verify LOM announces only ONCE per low-mana state (not every tick).
- [ ] **BUG-024:** Verify LOM does NOT announce again until mana recovers above 15% and then drops back down.
- [ ] **BUG-024:** Verify LOM does NOT announce for non-caster companions (warrior, rogue, monk).
- [ ] **BUG-025:** Use `/gsay @all !buffs` with a caster companion and at least one other companion in the group. Verify ALL party members receive buffs (player + all companions).
- [ ] **BUG-025:** Verify `!buffme` still only buffs the player (regression test).
- [ ] **BUG-025:** Verify buff queue handles companion entering combat mid-buffing (retries/aborts gracefully).
- [ ] **BUG-025:** Verify buff queue handles a party member dying or zoning mid-queue (skips invalid targets).
- [ ] **BUG-026:** Recruit a caster companion (wizard, cleric), engage a mob in a dungeon or indoor zone with walls and corners. Verify the caster does NOT run behind walls or around corners to reach its preferred range.
- [ ] **BUG-026:** Verify the caster stops at a position where it can see the target, even if that position is closer than the ideal CasterCombatRange.
- [ ] **BUG-026:** Verify the caster still moves to preferred range in open areas (no regression from LOS check in unobstructed terrain).
- [ ] **BUG-026:** Verify the caster re-evaluates position if target moves behind a pillar while caster is holding position (LOS re-check in sweet spot).
- [ ] **BUG-027:** Recruit a caster companion (wizard or cleric). Observe mana regen rate while standing and out of combat. Verify it matches meditation-rate regen (significantly higher than the previous flat-rate 2/tick).
- [ ] **BUG-027:** Engage in combat with a caster companion. Verify mana continues regenerating at meditation rate during combat (not just out of combat).
- [ ] **BUG-027:** Verify bards still use their own regen formula (not affected by the change).
- [ ] **BUG-027:** Verify melee companions (warrior, rogue, monk) are NOT affected by the change (no mana to regen, or melee archetype excluded from meditate formula).
- [ ] **BUG-027:** Use `#rules set Companions:AlwaysMeditateRegen false` and verify caster companions revert to standing=2/tick regen (rule toggle works).

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
