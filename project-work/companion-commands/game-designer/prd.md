# Companion Commands — Product Requirements Document

> **Feature branch:** `feature/companion-commands`
> **Author:** game-designer
> **Date:** 2026-03-13
> **Status:** Approved

---

## Problem Statement

The companion command system is the primary interface for players to manage
their recruited NPC companions. On a 1-3 player server where companions fill
essential party roles (tank, healer, DPS), efficient command management is
critical to the gameplay experience. Three issues currently degrade that
experience:

1. **!help is cluttered and requires a target.** The current help output is
   organized by category with inconsistent formatting, and the command is
   routed through the standard companion dispatch which requires targeting a
   companion first. A player who forgets the command they need cannot quickly
   reference the list without first clicking on a companion.

2. **No way to park a companion and make it stop fighting.** Players frequently
   need to position a companion at a specific location AND prevent it from
   engaging enemies (e.g., parking a healer at a safe spot during a dangerous
   pull, or holding a companion back while the player scouts ahead). Currently
   this requires two separate commands (!guard then !passive), and the player
   must remember to reverse both when resuming. There should be a single
   command that combines both behaviors.

3. **!tome leaves companions in a combat-ready state.** When recalling a
   companion with !tome, the companion moves to the player but retains its
   current target and continues attacking. This is counter-intuitive — if a
   player is calling a companion to them, they usually want the companion to
   disengage and come cleanly. The companion should arrive ready to receive
   new orders, not still swinging at a mob 200 units away.

4. **Documentation is out of date.** The companion-commands-reference.md
   still references old free-text commands (e.g., "show equipment", "leave",
   "stay", "stance") that no longer exist in the codebase. The system was
   migrated to !-prefix commands but the docs were not updated.

## Goals

1. **Streamlined !help** — Any player can type !help in say chat (no target
   required) and immediately see a clean, alphabetically sorted list of all
   companion commands with brief descriptions, delivered via say chat.

2. **Single-command hold** — A new !hold command that combines guard (stay at
   current position) and passive (stop fighting) into one action. Breaking
   out of hold is intuitive: !follow resumes movement, !assist or any
   combat-engaging command resumes fighting.

3. **Clean !tome recall** — !tome brings the companion to the player AND
   clears its target and stops any active combat engagement. Stance is
   preserved (if aggressive, stays aggressive for future fights).

4. **Accurate command audit** — Every existing command verified against its
   implementation. All discrepancies between documentation and code behavior
   identified and resolved.

5. **Up-to-date documentation** — companion-commands-reference.md reflects
   the actual current system including all changes from this feature.

6. **Full test coverage** — Every command change has corresponding test
   scenarios that verify correct behavior.

## Non-Goals

- Adding new combat commands beyond what is described (no new !attack alias,
  no stance queuing, no macro system)
- Changing recruitment mechanics, dismissal behavior, or equipment handling
- Modifying the @all / gsay dispatch system in C++
- Rebalancing companion AI combat behavior or spell priorities
- Adding new companion types or changing companion progression
- Changing how commands are parsed or dispatched (the ! prefix system stays)

## User Experience

### Player Flow: !help

1. Player is in the world and needs to check available commands.
2. Player types `/say !help` in chat. No target is required.
3. The system responds in say chat with a clean, alphabetically sorted list
   of all companion commands grouped by category, with one-line descriptions.
4. If the player has no companions in the zone, the response still appears
   (a system-level response, not a companion speaking).
5. If the player targets a companion and types `!help`, the same output
   appears. Target is ignored — behavior is identical whether targeted or not.
6. `!help <topic>` continues to work for detailed category help (stance,
   movement, combat, buffs, equipment, information, control).

### Player Flow: !hold

1. Player has a companion healer in their group during a dungeon crawl.
2. Player wants to park the healer at a safe corner while pulling mobs.
3. Player targets the healer companion and types `/say !hold`.
4. The companion says "Holding position." (or similar), stops following,
   and enters a non-combat state. It will not engage mobs, even if attacked.
   It stays at its current position.
5. Player pulls mobs and fights. The held companion stays put and does not
   fight.
6. When the pull is clear, the player types `/say !follow` to the companion.
   The companion resumes following. Its stance remains passive until the
   player explicitly changes it.
7. Alternatively, the player types `/say !assist` (which auto-switches
   passive to balanced) and the companion re-engages. The companion also
   breaks guard mode and resumes following when it begins combat.
8. !hold supports @all via gsay: player types `@all !hold` in group chat
   and all companions hold position and go passive.

### Player Flow: !tome update

1. Player's companion is fighting a mob 150 units away, or got stuck on
   terrain during a zone transition.
2. Player types `/say !tome` targeting the companion.
3. The companion instantly moves to the player's location (same as before).
4. **New behavior:** The companion's target is cleared and it stops any
   active combat engagement (hate list is NOT cleared — mobs that were
   fighting the companion will continue pursuing, but the companion itself
   stops attacking).
5. The companion's stance does NOT change. If it was aggressive, it stays
   aggressive and will engage new threats that come into range.
6. The companion responds: "[Name] moves to your side." (unchanged).
7. !tome supports @all via gsay (existing behavior, unchanged).

### Example Scenario

A level 45 shadow knight is clearing Sebilis with two companions: a cleric
("Tundera") and a warrior ("Guard Halvar").

The SK needs to pull a named mob around a corner. They want Tundera to stay
at the safe spot and not heal (which would draw aggro), while Halvar comes
with them.

1. SK targets Tundera and types: `!hold`
2. Tundera says: "Holding position." — she stops following and goes passive.
3. SK and Halvar push forward and engage the named mob.
4. Tundera stays at the corner, ignoring the fight.
5. After the named dies, SK types in group chat: `@all !follow`
6. Both companions resume following. Tundera is still in passive stance.
7. SK targets Tundera: `!balanced` — she returns to default combat mode.

Later, Halvar gets stuck on geometry after a zone. The SK types `!tome`
targeting Halvar. Halvar warps to the SK's position, drops his current
target, and stops attacking the mob he was stuck on. His aggressive stance
is preserved, so he'll engage the next threat that appears.

## Game Design Details

### Mechanics

#### Complete Command Inventory (Current State)

The following 23 commands exist in the companion system. All use the `!`
prefix and are spoken via `/say` when targeting a companion, or via gsay
with @mentions for group-wide dispatch.

**Stance Commands (owner-only):**

| Command | Behavior |
|---------|----------|
| `!passive` | Set stance to Passive (0). Wipes hate list. Companion disengages from combat. |
| `!balanced` | Set stance to Balanced (1). Default combat mode — fights when attacked or owner is attacked. |
| `!aggressive` | Set stance to Aggressive (2). Actively seeks and attacks enemies in range. |

**Movement Commands (owner-only):**

| Command | Behavior |
|---------|----------|
| `!follow` | Resume following owner. Clears guard mode. |
| `!guard` | Hold current position. Stop following. Companion still fights if engaged. |
| `!recall` | Teleport to owner's location. Requires >200 unit distance. 30s cooldown. Resets to follow mode. |
| `!tome` | Move to owner's location instantly (GMMove). No cooldown. Skips if within 50 units. |
| `!flee` | Go passive, move to owner (GMMove), set follow mode. Hate list intentionally retained. |

**Combat Commands (owner-only):**

| Command | Behavior |
|---------|----------|
| `!target` | Set companion's target to player's current target. In balanced/aggressive: engages target. In passive: faces target but does not attack. |
| `!assist` | Attack player's target. Auto-switches passive to balanced before engaging. Validates target is hostile. |

**Buff Commands (owner-only):**

| Command | Behavior |
|---------|----------|
| `!buffme` | Queue buff refresh on owner only. Casters only, requires >10% mana. |
| `!buffs` | Queue buff refresh on all party members. Casters only, requires >10% mana. |

**Equipment Commands:**

| Command | Owner-Only | Behavior |
|---------|------------|----------|
| `!equipment` | No | Display all equipped items. |
| `!gear` | No | Alias for !equipment. |
| `!equip` | Yes | Display instructions to use the trade window for giving items. |
| `!unequip <slot>` | Yes | Return item from named slot to player. |
| `!unequip all` | Yes | Return all equipped items to player. |
| `!unequipall` | Yes | Alias for !unequip all. |
| `!equipmentupgrade [link]` | No | Evaluate a linked item vs. currently equipped item in that slot. |
| `!equipmentmissing` | No | List all empty equipment slots. |

**Information Commands:**

| Command | Owner-Only | Behavior |
|---------|------------|----------|
| `!stats` | No | Detailed combat stats (attributes, AC, damage, resists). |
| `!status` | No | Overview: HP, mana, XP, stance, mode, target, buffs. |
| `!help` | No | Command list. `!help <topic>` for category details. |

**Control Commands (owner-only):**

| Command | Behavior |
|---------|----------|
| `!dismiss` | Dismiss companion voluntarily. Companion record preserved, re-recruitable with +10% bonus. |

#### Documentation Discrepancies Found

The following discrepancies exist between `claude/docs/companion-commands-reference.md`
and the actual codebase implementation in `companion.lua`:

1. **Dismissal keywords** — Reference doc lists free-text keywords (`leave`,
   `goodbye`, `farewell`, `release`) that do not exist in the code. Only
   `!dismiss` exists.

2. **`stance` alias** — Reference doc lists `stance` as an alias for
   `!balanced`. No such entry exists in the COMMANDS table.

3. **`stay` alias** — Reference doc lists `stay` as an alias for `!guard`.
   No such entry exists in the COMMANDS table.

4. **Equipment commands** — Reference doc lists free-text variants (`show
   equipment`, `show gear`, `inventory`, `give me your <slot>`, `give me
   everything`) that do not exist. The !-prefix commands replaced them.

5. **Handler function name** — Reference doc references `handle_command()`
   which does not exist. The actual dispatcher is `dispatch_prefix_command()`.

#### REQ-1: !help Rework

**Current behavior:** `!help` is dispatched through `dispatch_prefix_command()`
which routes through the COMMANDS table. It requires the player to target a
companion. The output is category-grouped with commands listed horizontally
per category line.

**New behavior:**

- !help requires NO target. If the player types `/say !help` without
  targeting a companion, the system still responds. If a companion is targeted,
  the output is identical.
- The output is delivered via say chat (the player sees it in their chat
  window).
- Commands are listed alphabetically within each category.
- Each command gets its own line with a brief description.
- The `@all` deduplication lock (help_lock_key) is retained so only one
  companion responds when `@all !help` is used via gsay.
- `!help <topic>` continues to work unchanged.

**Output format:**

```
=== Companion Commands ===
Buffs:
  !buffme            — Refresh your buffs (casters, >10% mana)
  !buffs             — Refresh party buffs (casters, >10% mana)
Combat:
  !assist            — Attack your target (auto-switches passive to balanced)
  !target            — Face/engage your current target
Control:
  !dismiss           — Dismiss companion (re-recruit later with bonus)
Equipment:
  !equip             — How to give items (use trade window)
  !equipment         — Show all equipped items (alias: !gear)
  !equipmentmissing  — List empty equipment slots
  !equipmentupgrade  — Evaluate a linked item vs. equipped
  !unequip <slot>    — Return item from slot (or 'all')
Information:
  !help              — This command list (!help <topic> for details)
  !stats             — Detailed combat stats
  !status            — Overview: HP, mana, stance, buffs
Movement:
  !flee              — Disengage, move to you, follow mode
  !follow            — Follow you
  !guard             — Hold current position (still fights)
  !hold              — Hold position and stop fighting
  !recall            — Teleport to you (>200 units, 30s cooldown)
  !tome              — Move to you instantly
Stance:
  !aggressive        — Actively seek and attack enemies
  !balanced          — Default: fight when attacked
  !passive           — Stop fighting, disengage
Type '!help <topic>' for details.
```

**Notes:**
- Aliases (`!gear`, `!unequipall`) are NOT listed separately — they are
  mentioned inline (e.g., "alias: !gear") to reduce clutter.
- The new `!hold` command appears under Movement since its primary purpose
  is positional control.

#### REQ-2: !hold (New Command)

**Behavior:** !hold combines guard mode and passive stance into a single
command. The companion:

1. Sets guard mode ON (stops following, holds current position).
2. Sets stance to Passive (0) and wipes hate list (stops fighting).
3. Tracks the "hold" state in the companion mode tracking table.
4. Responds: "Holding position." (or personality-appropriate variant).

**Breaking out of hold:**

- `!follow` — Breaks the guard component. Companion resumes following.
  Stance remains passive (player must explicitly change stance if desired).
- `!assist` — Breaks the passive component. Companion switches to balanced
  stance (existing !assist auto-switch behavior) and engages the target.
  Also implicitly breaks guard mode because the companion must move to
  engage. Companion resumes following after combat.
- `!balanced` or `!aggressive` — Changes stance from passive but does NOT
  break guard mode. Companion stays at position but will now fight enemies
  that come to it.
- `!guard` — No-op when already holding (already in guard mode).
- `!passive` — No-op when already holding (already passive).
- `!recall` — Teleports companion to player and resets to follow mode
  (existing behavior). Stance remains passive.
- `!tome` — Moves companion to player. With the REQ-3 changes, also clears
  target and stops attacking. Stance remains passive. Mode changes to follow
  (implicit from arriving at player).
- `!hold` while already holding — No-op. Companion confirms: "Already
  holding position."

**@all support:** !hold works with @all via gsay. All companions in the
group enter hold state simultaneously.

**Dead companion:** If the companion is dead, !hold responds: "[Name] is
dead and cannot hold position."

#### REQ-3: !tome Update

**Current behavior:** !tome checks if the companion is dead or within 50
units, then uses GMMove to instantly reposition the companion to the player.
Mode and stance are unchanged.

**New behavior (additions only):**

After repositioning, !tome also:
1. Clears the companion's current target (SetTarget to nil/none).
2. Stops active combat engagement — the companion ceases attacking. The
   hate list is NOT cleared (same design as !flee — mobs continue pursuit,
   but the companion stops initiating attacks).
3. Does NOT change the companion's stance. If aggressive, stays aggressive.
   If passive, stays passive. If balanced, stays balanced.
4. Sets follow mode (companion_modes tracking). If the companion was in
   guard mode, !tome breaks it (the companion is now at the player's
   position, so guarding that spot is equivalent to following).

**Rationale:** When a player calls a companion to them, the intent is "come
here and reset." The companion should arrive ready for new orders, not still
swinging at a distant mob. Preserving stance means the companion retains its
combat personality for future engagements.

**@all support:** Unchanged. !tome already works with @all via gsay dispatch.

#### REQ-4: Documentation Updates

The companion-commands-reference.md must be rewritten to reflect:
1. All 24 commands (23 existing + !hold) with their actual !-prefix syntax.
2. Correct handler function names.
3. Accurate behavior descriptions matching the code.
4. The @all / gsay dispatch mechanism.
5. Owner-only vs. read-only command access.
6. Remove all references to old free-text commands that no longer exist.

### Balance Considerations

These changes are pure quality-of-life improvements with no balance impact:

- **!help rework** — Information display only. No mechanical change.
- **!hold** — Combines two existing commands (!guard + !passive) into one.
  No new capability is introduced; this is strictly a convenience feature.
  A player could achieve the identical result by typing `!passive` then
  `!guard`. The hold state does not grant any combat advantage — it
  actually reduces combat effectiveness by making the companion passive.
- **!tome update** — Adds target-clearing behavior that makes !tome behave
  more intuitively. If anything, this slightly reduces combat effectiveness
  since the companion stops attacking on recall (previously it would
  continue attacking at range after being moved).

No balance tuning knobs are needed for any of these changes.

### Era Compliance

All changes are fully era-compliant:

- No new content references to any expansion.
- No new items, spells, or zones involved.
- The !hold concept is analogous to the original EQ `/pet hold` command
  which existed in the Classic era for pet classes.
- No new NPC types, factions, or racial/cultural content.
- All changes operate within the existing companion command framework.

## Affected Systems

- [ ] C++ server source (`eqemu/`) — Potentially needed if !help without a
  target requires C++ routing changes (architect to determine)
- [x] Lua quest scripts (`akk-stack/server/quests/`) — companion.lua is the
  primary implementation target for all three command changes
- [ ] Perl quest scripts (maintenance only) — Not affected
- [ ] Database tables (`peq`) — Not affected
- [ ] Rule values — Not affected
- [ ] Server configuration — Not affected
- [ ] Infrastructure / Docker — Not affected
- [x] Documentation (`claude/docs/`) — companion-commands-reference.md update

## Dependencies

- **Existing companion system** — All features build on the existing
  !-prefix command dispatch in companion.lua and the @all/gsay dispatch
  in client.cpp. Both are already implemented and working.
- **No new C++ bindings required** for !hold or !tome changes. All
  necessary methods (SetStance, SetGuardMode, WipeHateList, SetTarget,
  GMMove) are already bound to Lua.
- **!help without target** — This may require changes to how the command
  is routed when no companion is targeted. Currently, !-commands only fire
  through `dispatch_prefix_command()` which is called from `global_npc.lua`
  `event_say` when `e.self:IsCompanion()`. If no companion is targeted,
  this code path is never reached. The architect needs to determine how to
  handle this — either a C++ change to route targetless !help, or a
  Lua-level workaround in the global say handler.

## Open Questions

1. **!help without target routing** — The current dispatch path requires
   e.self to be a companion (global_npc.lua line 11). How should !help
   be routed when the player has no target or targets a non-companion?
   The architect should investigate whether this requires a C++ change
   (intercepting !help in the say handler before NPC dispatch) or if it
   can be handled in Lua (e.g., a player say event handler). Note: there
   may be a `global_player.lua` event_say hook that could intercept this.

2. **!hold mode tracking** — The companion_modes table currently tracks
   "follow" or "guard". Should !hold introduce a third mode "hold", or
   should it be tracked as "guard" with an additional "is_passive" flag?
   The architect should determine the cleanest approach.

3. **!tome guard-break behavior** — The PRD specifies that !tome should
   break guard mode (set follow). This is a new behavior — currently !tome
   does not change the movement mode. If a companion was guarding and the
   player calls them with !tome, should they return to guarding at the
   new position, or switch to follow? The PRD recommends follow (since the
   player called them over), but the architect should confirm this is the
   right UX.

## Acceptance Criteria

### REQ-1: !help Rework

- [ ] Player types `/say !help` with NO target: receives the full command
  list in say chat.
- [ ] Player types `/say !help` targeting a companion: receives identical
  output.
- [ ] Player types `/say !help` targeting a non-companion NPC: receives
  the command list (not an error).
- [ ] Commands are listed alphabetically within each category.
- [ ] Each command has its own line with a dash-separated brief description.
- [ ] Aliases (e.g., !gear) are mentioned inline, not as separate entries.
- [ ] The new !hold command appears in the list under Movement.
- [ ] `!help <topic>` works for all topics: stance, movement, combat,
  buffs, equipment, information, control.
- [ ] `@all !help` via gsay: only one response appears (deduplication works).

### REQ-2: !hold Command

- [ ] Player targets a companion and types `!hold`: companion stops
  following, holds position, enters passive stance, wipes hate list.
- [ ] Held companion does not engage enemies, even if attacked.
- [ ] Held companion does not move from its position.
- [ ] `!follow` on a held companion: resumes following, stance stays passive.
- [ ] `!assist` on a held companion: switches to balanced, engages target,
  resumes following.
- [ ] `!balanced` on a held companion: changes stance to balanced, stays
  at guard position, will now fight nearby enemies.
- [ ] `!aggressive` on a held companion: changes stance to aggressive,
  stays at guard position, will now fight enemies in range.
- [ ] `!hold` on an already-held companion: responds "Already holding
  position." (no state change).
- [ ] `!hold` on a dead companion: responds "[Name] is dead and cannot
  hold position."
- [ ] `@all !hold` via gsay: all companions in the group enter hold state.
- [ ] !hold appears in `!help` output under Movement category.
- [ ] !hold appears in `!help movement` detailed output with description.

### REQ-3: !tome Update

- [ ] `!tome` on a companion in combat: companion moves to player,
  target is cleared, companion stops attacking.
- [ ] `!tome` on a companion in combat: companion's stance is NOT changed.
- [ ] `!tome` on a companion that was in guard mode: companion moves to
  player and switches to follow mode.
- [ ] `!tome` on a companion already nearby (<50 units): "already nearby"
  message, no changes (existing behavior preserved).
- [ ] `!tome` on a dead companion: "[Name] is dead and cannot move."
  (existing behavior preserved).
- [ ] Mobs that were fighting the companion before !tome continue to
  pursue (hate list NOT cleared).
- [ ] `@all !tome` via gsay: all companions move to player, all clear
  targets and stop attacking.

### REQ-4: Command Audit & Documentation

- [ ] All 24 commands (23 existing + !hold) verified to match their
  documented behavior.
- [ ] All discrepancies between old documentation and code resolved.
- [ ] companion-commands-reference.md rewritten with:
  - Correct !-prefix command syntax for all commands.
  - Accurate behavior descriptions.
  - Owner-only vs. read-only access noted.
  - @all/gsay support documented.
  - Correct handler function and file references.
  - Old free-text commands removed.

### REQ-5: Test Coverage

- [ ] Each acceptance criterion above has a corresponding test scenario.
- [ ] Tests cover edge cases: dead companion, already-in-state, no target,
  @all dispatch, command interactions (!hold then !follow, !hold then
  !assist, !tome while in guard, etc.).
- [ ] Regression tests for all existing commands verify no unintended
  behavioral changes.

---

## Appendix: Technical Notes for Architect

### Command dispatch table

The COMMANDS table in companion.lua (lines 91-115) is the single source of
truth for all companion commands. Adding !hold means adding one new entry:

```
hold = { handler = "cmd_hold", category = "movement" }
```

### Guard mode + passive interaction

The companion_modes table (module-level in companion.lua) tracks "follow"
or "guard" per entity ID. Guard mode is set via `npc:SetGuardMode(bool)`
(Companion-only, nil-guarded). Passive stance is set via
`npc:SetStance(0)`. Both are independent systems — guard controls movement,
stance controls combat behavior.

### !help routing challenge

Currently, !-commands are only intercepted in global_npc.lua event_say when
`e.self:IsCompanion()` (line 11). Without a companion target, this code
path never fires. Options to investigate:

1. A global_player.lua event_say handler could intercept !help before it
   reaches NPC dispatch.
2. C++ could detect `!help` in the say channel and route it specially.
3. The system could require targeting ANY companion for !help, which is
   the simplest but least user-friendly approach.

### !tome target clearing

The current cmd_tome uses `npc:GMMove()` for repositioning. To clear the
target, `npc:SetTarget(nil)` should work (already used elsewhere in the
codebase). The hate list is intentionally NOT cleared, matching the design
pattern established by cmd_flee.

### Existing nil-guards

Many companion-specific methods (SetStance, GetStance, SetGuardMode,
GetCompanionType, GetCompanionID, GetCombatRole) are nil-guarded throughout
companion.lua because luabind doesn't resolve inherited methods at runtime
(the known Lua_Companion/Lua_NPC inheritance issue). Any new code must
follow the same pattern: `if npc.Method then npc:Method(args) end`.

### @all dispatch flow

Group chat @mentions are handled in C++ (`Client::HandleGroupChatMentions`
in client.cpp). The C++ code parses @tokens, resolves companion names (with
prefix stripping), and dispatches the payload as EVENT_SAY to each matched
companion. Conversation messages get stagger delays; !-commands are
dispatched immediately without stagger. No C++ changes are needed for !hold
or !tome — they are dispatched exactly like existing commands.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
