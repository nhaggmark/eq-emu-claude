# companion-ai-stances — Product Requirements Document

> **Feature branch:** `feature/companion-ai-stances`
> **Author:** game-designer
> **Date:** 2026-03-08
> **Status:** Draft

---

## Problem Statement

Recruited NPC companions currently retain their original NPC AI behaviors after
recruitment. When a player recruits a Qeynos guard, that guard continues to
auto-aggro nearby enemies based on faction, patrol waypoints, and respond to
game-world stimuli exactly as it did before recruitment. The three stance
commands (`!passive`, `!balanced`, `!aggressive`) exist and call `SetStance()`
in the C++ companion code, but the underlying NPC AI behavior is not governed
by the stance value. The result is that companions feel uncontrollable —
a recruited guard charges into fights the player didn't want, a passive
companion still responds to aggro stimuli, and the player has no reliable way
to dictate when their companion fights and when it doesn't.

For a 1–3 player server where companions are the core system enabling small
groups to tackle all content, predictable and controllable companion behavior
is essential. Players need to trust that their companion will do what they're
told, or the entire companion system feels unreliable and frustrating.

## Goals

1. **Recruitment is a clean break** — When an NPC is recruited as a companion,
   all original NPC AI behavior stops immediately. No more faction-based aggro,
   no more patrol routes, no more guard behavior. The companion becomes a blank
   slate governed entirely by the stance system.

2. **Stances actually control behavior** — Each of the three stances produces
   distinct, predictable, observable behavior:
   - **Aggressive**: companion actively seeks and engages nearby enemies
   - **Balanced**: companion follows the player and only fights when the player
     or a group member (including other companions) is attacked
   - **Passive**: companion never fights, even if being attacked; just follows

3. **Balanced is the default** — On recruitment, every companion starts in
   Balanced stance. This is the safest default: the companion won't start
   fights but will defend if attacked.

4. **Stance changes take effect immediately** — Switching stances mid-combat
   produces the expected result within one AI tick. Switching to Passive
   mid-fight means the companion disengages. Switching to Aggressive mid-fight
   means the companion starts seeking additional targets.

5. **Stance persists across sessions** — A companion's stance is saved and
   restored on dismissal/re-recruitment and on server restart. The player
   shouldn't have to re-set their preferred stance every time they log in.

## Non-Goals

- **New stances or custom stance creation** — Three stances is sufficient.
  Adding more (e.g., "defensive", "support-only") is a future consideration,
  not part of this feature.
- **Per-ability or per-spell stance configuration** — This feature controls
  overall combat engagement behavior, not which specific spells or abilities
  the companion uses. Spell AI tuning is a separate feature.
- **Companion positioning or formation AI** — How the companion positions
  itself in combat (tanking position, caster range, etc.) is not in scope.
  This feature controls whether the companion fights, not where it stands.
- **Visual stance indicators** — UI elements showing current stance (buffs,
  auras, particle effects) are not in scope. The `!status` command already
  reports stance.
- **Group-wide stance commands** — No "set all companions to passive" command.
  Each companion is commanded individually.
- **Changes to recruitment mechanics** — How NPCs are recruited, eligibility
  checks, persuasion rolls — all unchanged. This feature only affects
  post-recruitment behavior.

## User Experience

### Player Flow

1. **Player recruits an NPC.** The NPC stops patrolling, stops responding to
   faction-based aggro, and begins following the player. The companion is in
   Balanced stance by default. The player sees a brief acknowledgment message
   (e.g., "I will join you."). From this moment, the companion's behavior is
   entirely governed by the stance system.

2. **Player adventures with companion in Balanced stance.** The companion
   follows the player. When the player is attacked by a gnoll, the companion
   immediately engages the gnoll. When the fight ends, the companion returns
   to following. If the player walks past a hostile NPC without being attacked,
   the companion walks past too — it does not initiate combat on its own.

3. **Player switches to Aggressive.** The player says `!aggressive` to the
   companion. The companion acknowledges. Now, as the player moves through
   a dungeon, the companion actively engages any hostile NPC within a detection
   radius. The player doesn't need to pull or be attacked first — the companion
   seeks fights. This is useful for clearing trash mobs or when the player wants
   maximum damage output.

4. **Player switches to Passive.** The player enters a dangerous area and says
   `!passive`. The companion stops fighting immediately (if in combat, disengages
   and clears its hate list). The companion follows the player silently, taking
   hits without retaliating if attacked. This is useful for corpse runs,
   navigating through dangerous zones without adding aggro, or when the player
   needs the companion to stop attacking a specific target.

5. **Player switches back to Balanced.** The player says `!balanced`. The
   companion resumes normal defensive behavior — it won't initiate, but will
   respond to attacks.

### Example Scenario

A level 25 ranger recruits Guard Gevin in North Qeynos. Before this feature,
Guard Gevin would continue auto-aggroing any dark elf, troll, or ogre NPC
that wandered near, even though he's now "in the player's party." The ranger
can't stop him from running off to fight guards' enemies.

After this feature: Guard Gevin stops acting like a guard the moment he's
recruited. He follows the ranger in Balanced stance. When the ranger engages
a gnoll in Qeynos Hills, Gevin assists. When they walk past a dark elf
merchant, Gevin ignores it — he's no longer a guard. If the ranger sets Gevin
to Aggressive before entering Blackburrow, Gevin charges into gnolls on sight.
If things get hairy, the ranger says `!passive` and Gevin immediately stops
fighting and follows.

### Stance Transition Scenarios

**Balanced to Aggressive (out of combat):**
- Companion starts scanning for hostile targets within detection range
- If hostiles are found, companion engages the nearest one
- If no hostiles, companion continues following — switches to seeking mode

**Balanced to Passive (mid-combat):**
- Companion stops attacking immediately
- Companion clears its hate list (drops aggro)
- Companion stops casting any offensive spells
- Companion returns to following the player
- Note: mobs that were fighting the companion may continue to chase it briefly
  until they leash or switch targets

**Aggressive to Passive (mid-combat):**
- Same as Balanced to Passive: immediate disengage

**Passive to Balanced (while being attacked):**
- Companion begins fighting back against whatever is currently attacking it
- Companion does NOT seek new targets beyond its current attackers

**Passive to Aggressive (while being attacked):**
- Companion begins fighting back AND starts seeking additional targets

**Any stance change (out of combat):**
- Immediate transition, no delay
- Companion continues following player (unless in guard mode)

## Game Design Details

### Mechanics

#### The Clean Break: Recruitment Resets AI

When `client:CreateCompanion(npc)` succeeds, the following NPC AI behaviors
must be suppressed for the resulting companion entity:

| Original NPC Behavior | After Recruitment |
|----------------------|-------------------|
| Faction-based aggro (auto-attack hostile races/factions) | Disabled. Companion does not aggro based on faction. |
| Patrol waypoints / guard routes | Disabled. Companion follows player or holds position (guard mode). |
| Assist radius (helping nearby NPCs of same faction) | Disabled. Companion only assists the player and group members. |
| Proximity aggro (KOS behavior) | Disabled. Companion does not aggro on proximity. |
| Flee behavior (running away at low HP) | Retained. Companions can still flee at low HP if their NPC type has flee behavior. This is a deliberate choice — it adds personality. |
| Special abilities (enrage, rampage, etc.) | Retained for NPC types that have them. These are combat abilities, not AI behaviors. |
| Spellcasting AI | Governed by companion spell AI (already implemented in `companion_ai.cpp`). Not changed by this feature. |

#### Stance Definitions

**Passive (stance 0):**
- Companion does not engage combat under any circumstances
- If currently in combat, immediately disengages: clears hate list, stops
  attacking, stops casting offensive spells
- Companion takes no action if attacked — absorbs damage without retaliating
- Companion continues to follow player or hold guard position
- Beneficial spells (self-heals, buffs) are also suppressed in passive stance
  — the companion is truly inert
- The `!target` and `!assist` commands in passive stance cause the companion
  to face the target but NOT engage combat (this behavior already exists)

**Balanced (stance 1) — default on recruitment:**
- Companion does not initiate combat on its own
- Companion engages when:
  - The companion itself is attacked (added to a mob's hate list or takes damage)
  - The player (owner) is attacked
  - Any group member (including other companions) is attacked
- Once engaged, companion fights until the target is dead or the target
  disengages (leaves hate list)
- Companion does not seek additional targets beyond those that have attacked
  the group
- `!target` and `!assist` commands cause the companion to engage the
  specified target (this behavior already exists)

**Aggressive (stance 2):**
- Companion actively scans for hostile NPCs within a detection radius
- Detection radius: the architect should investigate what scan range is
  appropriate; a reasonable starting point is the same aggro radius used by
  NPCs of similar level (approximately 50–100 game units, tunable via rule value)
- "Hostile" means: any NPC that would be KOS (kill-on-sight) to the player,
  or any NPC currently on the player's or group's hate list
- Companion engages the nearest hostile target
- When current target dies, companion scans for next hostile target
- If no hostile targets in range, companion follows the player normally
- `!target` and `!assist` commands work as expected, overriding the auto-target
  selection

#### Stance Persistence

The companion's current stance is stored in the `companion_data` database
table (the `stance` column already exists based on the `check_dismissed_record`
query in `companion.lua`). This value:
- Is set to 1 (Balanced) on initial recruitment
- Is updated whenever the player changes stance via `!passive`, `!balanced`,
  or `!aggressive`
- Is restored when the companion is re-recruited (re-recruitment already
  restores `companion_data` fields)
- Persists across server restarts (database-backed)

#### Stance Change Timing

Stance changes take effect on the next AI processing tick after `SetStance()`
is called. This should be effectively instantaneous from the player's
perspective (AI ticks run every 100–250ms depending on server configuration).

When transitioning to Passive from an engaged state:
1. Companion's hate list is cleared
2. Companion stops melee attacks
3. Companion cancels any in-progress spell casts (offensive only)
4. Companion's AI state transitions to idle/follow

When transitioning from Passive to an engaged state (Balanced or Aggressive):
1. If the companion is currently being attacked, it immediately engages its
   attackers (Balanced behavior)
2. If in Aggressive, it also begins scanning for nearby hostile targets
3. No artificial delay — combat begins on the next AI tick

### Balance Considerations

**Aggressive stance power level:**
Aggressive stance makes companions very efficient at clearing content — they
auto-target and engage without player input. This is intentional for a 1–3
player server where the player is often managing multiple companions. However,
the detection radius should be tunable via a rule value so it can be adjusted
if aggressive companions trivialize content by pulling too many mobs.

**Passive as an escape valve:**
Passive stance is deliberately powerful — it gives the player an emergency
"stop everything" button. In a small group where one player is managing
companions, the ability to instantly stop a companion from fighting is
essential for survival. Without it, a companion pulling extra mobs could
wipe a small group with no recovery option.

**Balanced as the safe default:**
Balanced is deliberately conservative. It requires the companion to be
provoked (attacked) before it fights. This prevents accidental pulls in
dungeons and lets the player control engagement pace. For most gameplay,
this is the right stance.

**Interaction with 1–3 player constraint:**
- Solo player with 5 companions: needs Aggressive or manual `!target` for
  each companion to manage a full clear. Balanced works for careful play.
- Duo with 4 companions: balanced is ideal — companions defend, players pull.
- Trio with 3 companions: balanced with occasional aggressive for trash clears.

**Flee behavior retention:**
Companions retain their NPC flee behavior (if their NPC type has it) because
it adds personality and tactical depth. A warrior-type companion won't flee,
but a caster-type might. This is consistent with EQ's NPC behavior and gives
different companion types distinct combat feels. If this proves frustrating
in practice, it can be toggled via a rule value in a future update.

### Era Compliance

This feature is entirely era-appropriate. The concepts of combat stances
and companion behavior modes have no expansion-era dependencies. The
mercenary system (which was introduced in Seeds of Destruction, a later
expansion) is being co-opted as an internal implementation mechanism, but
the player-facing feature uses none of the mercenary UI, terminology, or
expansion-locked content.

The three stance names (Passive, Balanced, Aggressive) are generic English
terms, not tied to any expansion's feature set. The `!command` interface
is a custom server feature, not part of any EQ expansion.

No spells, items, zones, NPCs, factions, or quests from post-Luclin
expansions are referenced or required.

## Affected Systems

- [x] C++ server source (`eqemu/`)
  - `zone/companion.cpp` / `companion.h` — core companion class, AI processing
  - `zone/companion_ai.cpp` — companion spell AI (may need stance awareness)
  - `zone/mob_ai.cpp` — NPC AI processing (companions need to bypass standard
    NPC aggro logic)
  - `zone/aggro.cpp` — aggro detection (companions should not use faction-based
    aggro)
  - `zone/npc.cpp` — NPC::Process() may need companion-specific AI path
  - `zone/hate_list.cpp` — hate list clearing on passive transition
  - `zone/lua_companion.cpp` — Lua API bindings (SetStance already exists)
- [x] Lua quest scripts (`akk-stack/server/quests/`)
  - `lua_modules/companion.lua` — stance command handlers (already exist,
    may need minor updates for acknowledgment messages)
- [ ] Perl quest scripts (maintenance only)
- [x] Database tables (`peq`)
  - `companion_data` table — `stance` column (already exists, used for
    persistence)
- [x] Rule values
  - New rule: aggro scan radius for Aggressive stance
  - Possibly: toggle for companion flee behavior retention
- [ ] Server configuration
- [ ] Infrastructure / Docker

## Dependencies

This feature depends on:

1. **Existing companion system** — The recruit-any-NPC companion system must
   be functional. It is: recruitment, dismissal, `!command` dispatch, stance
   commands, and the C++ `Companion` class all exist and work.

2. **Companion AI system** — The class-specific spell AI in
   `companion_ai.cpp` must be functional. This feature does not modify spell
   AI selection, only whether the companion is allowed to engage at all.

3. **Mercenary AI co-option** — The companion system already uses the
   mercenary AI system. This feature extends that system to properly respect
   stance values, but does not require new mercenary features.

No external dependencies. No new database tables required (the `stance`
column in `companion_data` already exists). No client-side changes needed
(Titanium client is unchanged).

## Open Questions

1. **What is the current code path for companion AI processing?** The
   architect needs to trace exactly how `Companion::Process()` or
   `NPC::Process()` handles the companion's AI tick, and where the stance
   value is (or isn't) checked. The existing `SetStance()` stores the value
   but the AI processing may not read it.

2. **How does the mercenary AI system handle stances?** The `Merc` class has
   its own stance system. Since companions co-opt the merc AI, the architect
   should determine whether the merc stance logic can be reused or if
   companion-specific AI logic is needed.

3. **What NPC behaviors need explicit suppression on recruitment?** The
   architect should catalog all NPC AI behaviors that could "leak through"
   after recruitment: faction aggro, patrol waypoints, assist radius,
   proximity aggro, guard behavior flags, special AI flags. Each needs to
   be explicitly disabled on the companion entity.

4. **What is the appropriate scan radius for Aggressive stance?** The
   architect should investigate typical NPC aggro radii at various levels
   and recommend a default value. This should be a rule value for tuning.

5. **Does the companion spell AI need stance awareness?** If a companion
   is in Passive stance, `companion_ai.cpp` should not cast offensive spells.
   The architect should verify whether the spell AI currently checks stance
   before casting.

## Acceptance Criteria

- [ ] Recruiting any NPC produces a companion that does NOT exhibit the
  original NPC's faction-based aggro behavior. A recruited Qeynos guard does
  not auto-attack dark elves.
- [ ] Recruiting any NPC produces a companion that does NOT patrol its
  original waypoint route. The companion follows the player instead.
- [ ] A companion in **Passive** stance takes no combat action, even when
  being attacked. It follows the player and absorbs damage silently.
- [ ] A companion in **Balanced** stance does not initiate combat on its own.
  It only engages when the player, the companion itself, or a group member
  is attacked.
- [ ] A companion in **Aggressive** stance actively seeks and engages nearby
  hostile targets without player input.
- [ ] Switching from any stance to **Passive** mid-combat causes the companion
  to immediately disengage: it stops attacking, clears its hate list, and
  returns to following.
- [ ] Switching from **Passive** to **Balanced** or **Aggressive** while the
  companion is being attacked causes it to begin fighting back immediately.
- [ ] A companion's stance defaults to **Balanced** on initial recruitment.
- [ ] A companion's stance persists across dismissal and re-recruitment (the
  `stance` column in `companion_data` is saved and restored).
- [ ] A companion's stance persists across server restarts.
- [ ] The `!status` command correctly reports the current stance.
- [ ] The `!passive`, `!balanced`, and `!aggressive` commands correctly change
  the stance and the companion acknowledges the change.
- [ ] Stance changes take effect within one AI tick (effectively instantaneous
  from the player's perspective).

---

## Appendix: Technical Notes for Architect

These notes are advisory. The architect makes all implementation decisions.

### Existing Code Pointers

- `companion.lua` line 448-463: The `cmd_passive`, `cmd_balanced`, and
  `cmd_aggressive` handlers already call `npc:SetStance(N)`. The Lua side
  is likely complete — the issue is that C++ doesn't act on the stance value
  during AI processing.

- `companion_data` table has a `stance` column (visible in
  `companion.lua:check_dismissed_record()` which SELECTs it). Persistence
  infrastructure may already be in place.

- The C++ entity hierarchy: `Companion` inherits from `NPC` inherits from
  `Mob`. The `NPC::Process()` method calls `Mob::AI_Process()` which handles
  aggro scanning and combat AI. Companions may need to override or bypass
  parts of this processing based on stance.

- `zone/aggro.cpp` contains faction-based aggro logic. Companions need to
  be excluded from this system entirely (they don't aggro based on faction).

- `zone/merc.cpp` has stance-aware AI processing (Tank, Healer, MeleeDPS,
  CasterDPS roles with stance modifiers). The companion system co-opted this;
  investigate how much of the merc stance logic applies.

### Suggested Rule Values

- `Companions:AggressiveScanRadius` (integer, default 75) — distance in game
  units that Aggressive stance scans for hostile targets
- `Companions:CompanionFleeEnabled` (bool, default true) — whether companions
  retain NPC flee behavior

### Key Behavioral Detail: "Hostile" Definition for Aggressive Stance

For Aggressive stance scanning, "hostile" should mean any NPC that would
aggro the player (KOS to the player based on the player's faction standing).
This uses the player's faction, not the companion's original NPC faction.
A recruited Qeynos guard in Aggressive stance should attack things that are
hostile to the PLAYER, not things that were hostile to Qeynos guards.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
