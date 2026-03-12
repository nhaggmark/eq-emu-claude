# Companion Group Commands — Product Requirements Document

> **Feature branch:** `feature/companion-group-commands`
> **Author:** game-designer
> **Date:** 2026-03-11
> **Status:** Draft

---

## Problem Statement

On our 1-3 player Custom EverQuest server, companions are the backbone of every
group. Players recruit NPC companions who fill the roles of tank, healer, DPS,
and support — roles that a full group of human players would normally cover.
However, the companion system currently lacks tactical commands that players
need to efficiently manage their party during combat, travel, and downtime.

Today, players can set a companion's stance (passive/balanced/aggressive), tell
them to follow or guard, equip them with gear, and dismiss them. But there is
no way to:

1. **Get a quick status overview** of a companion's health, mana, stance, and
   buffs without manually inspecting them — critical information when managing
   3-5 companions in a fast-paced dungeon.

2. **Request buffs on demand** from caster companions. Buff AI runs on its own
   schedule, but players sometimes need a specific buff refreshed NOW (e.g.,
   before a named pull, or after a death/rezz).

3. **Summon a companion to the player** ("to me") when they wander off, get
   stuck on geometry, or are out of position after a pull.

4. **Order a tactical retreat** when a fight goes wrong. There is no way to
   tell all companions to disengage and run to the player in a single action.

5. **Direct companions to assist** on the player's current target — the most
   basic group coordination command that every EQ player expects.

6. **Evaluate loot for companion upgrades** without memorizing every companion's
   current gear across 19 slots. When a piece of armor drops, the player should
   be able to quickly ask "is this an upgrade for you?"

7. **See which equipment slots are empty** on a companion to know where to
   prioritize loot distribution.

8. **Get a command reference** in-game without checking external documentation.

9. **Order companions to follow** via group chat without switching targets.

These are not luxury features — they are the fundamental vocabulary of group
management that any EverQuest player expects when controlling party members.
Without them, managing a group of companions is tedious and error-prone,
especially during the fast-paced combat encounters that our server is designed
to make accessible to small groups.

All commands leverage the existing group chat addressing system
(`@name`, `@all`) implemented in the `feature/group-chat-addressing` feature,
allowing players to issue commands without changing their current target.

## Goals

1. **Complete tactical command vocabulary:** Give players the 9 commands they
   need to manage companions effectively in combat, travel, and downtime
   scenarios — covering status reporting, buff management, positioning,
   combat engagement, equipment evaluation, and command discovery.

2. **Seamless group chat integration:** All commands work through the existing
   `@name`/`@all` group chat addressing system, so players can issue commands
   mid-combat without switching targets. Example: `/gsay @iskarr !assist`
   makes Guard Iskarr attack the player's target instantly.

3. **Macro-friendly syntax:** Every command is designed to work reliably in EQ
   macro hotbuttons. A player can create a "pull macro" that sends
   `@tank !assist` on line 1 and `@healer !follow` on line 2, executing both
   with a single button press.

4. **Informative feedback:** Every command produces clear, readable feedback in
   chat so the player knows exactly what happened. No silent successes, no
   ambiguous responses.

5. **Graceful edge case handling:** Commands that don't apply to a companion
   (e.g., `!buffme` to a warrior) produce helpful feedback rather than errors
   or silence.

## Non-Goals

- **New AI behaviors.** These commands direct companions to use existing AI
  capabilities (buffing, following, attacking). They do not add new AI logic
  like pulling, crowd control priority, or heal rotation management.

- **Automatic command execution.** Commands are player-initiated only. There is
  no auto-assist, auto-buff, or auto-follow triggered by game events. The player
  always decides when to issue commands.

- **Custom UI or windows.** All interaction happens through the existing group
  chat channel (`/gsay`) and text responses. No custom EQ UI modifications,
  which are impossible on the Titanium client anyway.

- **Companion-to-companion commands.** Companions do not issue commands to each
  other. All commands originate from the player.

- **Equipment auto-equip or auto-trade.** The `!equipmentupgrade` command
  evaluates whether an item is an upgrade — it does not automatically equip it.
  The player must still trade the item manually.

- **Spell selection or casting control.** The `!buffme`/`!buffs` commands
  request the companion to refresh their available buffs using their existing
  buff spell list. The player cannot specify which spells to cast or override
  the companion's spell AI priorities.

- **New stance types or modifications to existing stances.** The `!flee` and
  `!assist` commands use existing stance values (passive, balanced, aggressive).
  No new stances are introduced.

## User Experience

### Player Flow

1. **Player enters a dungeon with companions.** A level 45 shadow knight has
   recruited three companions: Guard Iskarr (warrior, tank), Priestess Astrid
   (cleric, healer), and Scout Verin (ranger, DPS). They are about to pull a
   named mob in Sebilis.

2. **Player checks party status before the pull.** The player types
   `/gsay @all !status`. Each companion reports their HP, mana, stance, target,
   sit/stand state, and buff list with durations. The player sees that Priestess
   Astrid is at 40% mana and her Aegolism buff on the player expired 2 minutes
   ago. Guard Iskarr's buffs are all fresh. Scout Verin is missing his SoW.

3. **Player requests buffs.** The player types `/gsay @astrid !buffme`.
   Priestess Astrid queues a buff refresh for the player — she will cast her
   available buffs (including Aegolism) on the player during her next idle
   window. The player also types `/gsay @astrid !buffs` to have her refresh
   buffs on the entire party, including Scout Verin's SoW from a different
   companion.

4. **Player initiates the pull.** The shadow knight pulls the named mob. As it
   comes into camp, the player types `/gsay @iskarr !assist`. Guard Iskarr
   (who was in balanced stance) attacks the player's current target — the named
   mob. The player never changed their target.

5. **Fight goes badly — tactical retreat.** The named mob has an unexpected add.
   The player types `/gsay @all !flee`. All three companions immediately switch
   to passive stance, run to the player's location, and begin following the
   player. Their hate lists are NOT cleared — the mobs chase them, creating a
   realistic retreat scenario. The player runs for the zone line.

6. **After recovering, player resumes.** The player types
   `/gsay @iskarr !assist` to re-engage. Iskarr automatically switches from
   passive to balanced stance and attacks the player's target.

7. **Loot evaluation.** After killing a mob, a Mithril Breastplate drops. The
   player links the item in group chat: `/gsay @iskarr !equipmentupgrade
   [Mithril Breastplate]`. Guard Iskarr evaluates the item against his current
   chest piece and responds: "The Mithril Breastplate is an upgrade over my
   current Rusty Breastplate (stat sum: 45 vs 12)." or "My current Breastplate
   of Valor is better (stat sum: 78 vs 45)."

8. **Checking empty slots.** The player types `/gsay @verin !equipmentmissing`.
   Scout Verin reports: "I have nothing equipped in: Face, Neck, Shoulders,
   Back, Wrist 1, Wrist 2, Finger 1, Finger 2, Waist, Secondary, Range, Ammo."
   The player now knows which slots to prioritize for Verin.

9. **Companion wanders off.** During a break, Scout Verin got stuck behind a
   wall after pathing weirdly. The player types `/gsay @verin !tome`. Verin
   moves directly to the player's current location, unsticking himself.

10. **Player forgets a command.** The player types `/gsay @iskarr !help`. Guard
    Iskarr displays the complete command reference card covering all companion
    commands — both existing ones (recruitment, dismissal, stance, equipment)
    and the new commands from this feature.

### Example Scenario

A solo level 55 necromancer is clearing the Hole with four companions: a warrior
(tank), a cleric (healer), a shaman (slower/healer), and an enchanter (crowd
control). The necromancer is the only human player.

**Pre-pull preparation:**
```
/gsay @all !status
  → Warrior: 100% HP, Balanced stance, standing
  → Cleric: 85% mana, Balanced stance, sitting
  → Shaman: 72% mana, Balanced stance, sitting
  → Enchanter: 91% mana, Balanced stance, standing

/gsay @cleric !buffme
  → Cleric queues buff refresh for necromancer (Symbol, Aegolism)

/gsay @shaman !buffs
  → Shaman queues buff refresh for all party members (SoW, STR buff, HP buff)
```

**During combat:**
```
/gsay @warrior !assist
  → Warrior attacks necromancer's target (a Construct of Pain)

[fight goes wrong, second add incoming]

/gsay @all !flee
  → All companions go passive, run to necromancer, follow
  → Mobs chase (hate not cleared) — necromancer FDs, companions keep running
```

**After loot:**
```
/gsay @warrior !equipmentupgrade [Jagged Blade of War]
  → "The Jagged Blade of War is an upgrade! My Primary slot is empty."

/gsay @warrior !equipmentmissing
  → "Empty slots: Face, Neck, Shoulders, Back, Arms, Wrist 1, Wrist 2,
     Hands, Finger 1, Finger 2, Legs, Feet, Waist, Secondary, Range, Ammo"
```

**Macro example (hotbutton for pulling):**
```
Line 1: /gsay @warrior !assist
Line 2: /gsay @shaman !assist
Line 3: /gsay @cleric !follow
```
One button: tank and shaman engage, cleric stays close to the player.

## Game Design Details

### Mechanics

#### Command Overview

| Command | Target | Effect | Interrupts Combat? |
|---------|--------|--------|--------------------|
| `!status` | Single or @all | Report companion state | No |
| `!buffme` | Single or @all | Queue buff refresh on player only | No |
| `!buffs` | Single or @all | Queue buff refresh on all party members | No |
| `!tome` | Single or @all | Move to player's current location | No |
| `!flee` | Single or @all | Passive + move to player + follow | Yes (goes passive) |
| `!assist` | Single or @all | Attack player's current target | Yes (engages) |
| `!equipmentupgrade` | Single only | Evaluate linked item as upgrade | No |
| `!equipmentmissing` | Single or @all | List empty equipment slots | No |
| `!help` | Single or @all | Display command reference | No |
| `!follow` | Single or @all | Begin following the player | No |

All commands use the existing group chat addressing system: `@companionname`
for a specific companion, `@all` for all companions in the group.

---

#### !status — Companion Status Report

**Purpose:** Give the player a snapshot of a companion's current state.

**Output format:**
```
[Companion Name] Status:
  HP: 1450/2000 (72%)  |  Mana: 800/1200 (66%)
  Stance: Balanced  |  Target: a Sebilite Juggernaut
  State: Standing  |  Following: Yes
  Buffs (4 active):
    - Aegolism (23 min remaining)
    - Symbol of Marzin (18 min remaining)
    - Speed of the Shissar (41 min remaining)
    - Haste (7 min remaining)
```

**Rules:**
- HP is always shown as current/max with percentage.
- Mana is shown as current/max with percentage. If the companion has no mana
  pool (pure melee class), display "Mana: N/A".
- Stance shows the current stance name: Passive, Balanced, or Aggressive.
- Target shows the companion's current target's name, or "None" if no target.
- State shows "Standing" or "Sitting" based on the companion's current state.
- Following shows "Yes" or "No" based on whether the companion is in follow
  mode (vs guard mode).
- Buffs lists all active buffs with time remaining in minutes (rounded down).
  If no buffs are active, display "Buffs: None active".
- Buff time remaining of less than 1 minute displays as "<1 min remaining".

**@all behavior:** When sent to `@all`, each companion reports independently.
Reports are delivered sequentially with no artificial delay (status is instant,
not an LLM response).

**Edge cases:**
- Companion is dead: Report "HP: 0/2000 (0%) — DEAD" and omit target/stance.
- Companion has 0 buffs: "Buffs: None active".
- Companion is in combat: Status still reports normally; this command never
  interrupts what the companion is doing.

---

#### !buffme — Request Buffs on Player

**Purpose:** Queue the targeted companion to cast their available buffs on the
requesting player.

**Behavior:**
- The companion adds "buff the player" to its action queue.
- The buff request does NOT interrupt current activity. If the companion is in
  combat, casting, or performing another action, the buff request waits until
  the companion's next idle window.
- When the idle window arrives, the companion casts its available buff spells
  on the player only (not on other group members).
- "Available buff spells" means spells in the companion's spell list that are
  of type `SpellType_Buff` or `SpellType_PreCombatBuff`, are not on cooldown,
  and that the companion has enough mana to cast.
- The companion follows its existing spell AI priority for buff selection.

**Feedback messages:**
- On receipt: "[Companion Name] will refresh your buffs when able."
- If the companion has no buff spells (e.g., warrior, rogue, monk):
  "[Companion Name] has no buff spells available."
- If the companion is out of mana (below 10% threshold):
  "[Companion Name] is too low on mana to buff right now."

**@all behavior:** All companions with buff spells queue a buff refresh for the
player. Companions without buff spells respond with the "no buff spells" message.

**Edge cases:**
- Companion is dead: "[Companion Name] is dead and cannot cast spells."
- Companion already has a pending buff queue: The new request replaces the
  previous one (no stacking of multiple buff requests).
- Player already has the buff: The companion's existing spell AI handles
  buff checking — it will skip buffs already active on the target. This
  command does not override that logic.

---

#### !buffs — Request Buffs on All Party Members

**Purpose:** Queue the targeted companion to cast their available buffs on all
group members (player + all companions).

**Behavior:**
- Identical to `!buffme` except the target is the entire group instead of just
  the player.
- The companion iterates through group members and casts available buffs on
  each, following its existing spell AI priority and target selection.
- Buff casting order follows the companion's existing heal/buff target priority
  (typically owner first, then most-needed party member).

**Feedback messages:**
- On receipt: "[Companion Name] will refresh party buffs when able."
- Same "no buff spells" and "too low on mana" messages as `!buffme`.

**@all behavior:** All companions with buff spells queue a party-wide buff
refresh. This can result in multiple companions buffing the group simultaneously
during their next idle windows.

**Edge cases:**
- Same as `!buffme`, applied to group scope.
- If a group member already has all available buffs, the companion skips them
  naturally via its existing buff-checking logic.

---

#### !tome — Come to Player ("To Me")

**Purpose:** Command the companion to move directly to the player's current
location.

**Behavior:**
- The companion immediately begins moving toward the player's current X/Y/Z
  coordinates at the time the command is issued.
- This is a one-time movement command, not a persistent follow. After arriving
  at the player's location, the companion resumes whatever movement mode it was
  in (follow or guard).
- Movement uses the same pathing system the companion normally uses (navmesh
  or waypoint).
- Does NOT change the companion's stance or combat state. A companion in
  aggressive stance that receives `!tome` will move to the player but remain
  aggressive (and may re-engage enemies along the way).

**Feedback messages:**
- On receipt: "[Companion Name] moves toward you."
- On arrival (within melee range of player): No additional message needed — the
  companion's physical arrival is the confirmation.

**@all behavior:** All companions begin moving to the player's location.

**Edge cases:**
- Companion is already at the player's location (within 50 units): No movement
  needed. "[Companion Name] is already nearby."
- Companion is in a different zone: Not possible — group chat addressing only
  works for companions in the same zone.
- Companion is dead: "[Companion Name] is dead and cannot move."
- Companion is rooted/snared: The companion attempts to move but may be unable
  to reach the player. No special handling — the movement system handles this.
- The command name "tome" is a mnemonic for "to me" and is intentionally short
  for rapid use in macros.

---

#### !flee — Tactical Retreat

**Purpose:** Order the companion to disengage from combat and run to the player.
This is a macro command that chains three actions: set passive stance, move to
player location, and begin following the player.

**Behavior (executed in sequence):**
1. Set companion's stance to PASSIVE (0). This causes the companion to stop
   attacking and stop responding to aggro.
2. Move the companion to the player's current location (same as `!tome`).
3. Set the companion's movement mode to FOLLOW.

**Critical design decision: Hate list is NOT cleared.** This is intentional.
The `!flee` command simulates telling a real party member to run away. In
EverQuest, running away does not magically remove you from a mob's hate list.
The mob will continue to chase the fleeing companion until it leashes, the
companion dies, or the companion gets far enough away. This creates realistic
tactical decisions:

- Should the player use `!flee` while the mob is still alive, knowing it will
  chase the companion?
- Should the player kill the mob first and then reposition companions?
- In a genuine emergency, does the player have an escape plan (FD, evac, zone
  line) for the whole group?

**Feedback messages:**
- On receipt: "[Companion Name] disengages and retreats to you!"
- If companion was not in combat: "[Companion Name] moves to follow you."
  (Same end state, but the companion was already passive/not fighting.)

**@all behavior:** All companions simultaneously set passive, move to player,
and follow. This is the "oh no" button for a wipe-in-progress.

**Edge cases:**
- Companion is already passive and following: Command still executes (moves
  companion to player's current location), but feedback reflects the simpler
  action.
- Companion is dead: "[Companion Name] is dead and cannot flee."
- Companion is rooted: Companion goes passive and attempts to move. It will
  stop attacking but may not be able to physically reach the player until the
  root breaks.

---

#### !assist — Attack Player's Target

**Purpose:** Command the companion to attack whatever the player is currently
targeting.

**Behavior:**
- The companion attacks the player's current target.
- If the companion is currently in PASSIVE stance, the companion is
  automatically switched to BALANCED stance first, then engages the target.
  This prevents the frustrating pattern of a player issuing `!assist` and
  nothing happening because they forgot the companion was set to passive.
- If the companion is already in BALANCED or AGGRESSIVE stance, no stance
  change occurs — the companion simply engages the new target.
- The companion adds the target to its hate list and begins combat (melee
  approach + attack, or ranged/spell engagement based on class AI).

**Feedback messages:**
- On receipt: "[Companion Name] attacks [Target Name]!"
- If companion was passive (auto-switching): "[Companion Name] switches to
  balanced stance and attacks [Target Name]!"
- If the player has no target: "[Companion Name] has no target to assist with.
  Target a mob first."
- If the player's target is a friendly NPC or player: "[Companion Name] will
  not attack a friendly target."
- If the player's target is the companion itself: "[Companion Name] will not
  attack themselves."

**@all behavior:** All companions engage the player's current target.

**Edge cases:**
- Player targets a corpse: "[Companion Name] cannot attack a corpse."
- Companion is dead: "[Companion Name] is dead and cannot fight."
- Target is out of range/zone: The companion will path toward the target using
  normal movement AI. If the target is unreachable, normal NPC pathing failure
  behavior applies.
- Companion is already fighting the target: No change — companion continues
  fighting. No feedback message needed (or optionally: "[Companion Name] is
  already fighting [Target Name].").

---

#### !equipmentupgrade — Evaluate Item as Upgrade

**Purpose:** Let the player link an item in group chat and have the companion
evaluate whether it would be an upgrade over their currently equipped item in
the corresponding slot.

**Syntax:** `/gsay @companionname !equipmentupgrade [Item Name]`

The item must be linked using EQ's standard item link format (the clickable item
links generated by the game). The command extracts the item data from the link.

**Evaluation logic:**

1. **Can the companion wear the item?** Check the item's class and race
   restrictions against the companion's class and race. If the companion cannot
   equip the item, there is no response (silent — the item is irrelevant to
   this companion).

2. **Determine the target slot.** Use the same slot resolution logic as the
   existing equipment trade system.

3. **Is the slot empty?** If the companion has nothing in the target slot,
   always respond YES: "[Companion Name]: The [Item Name] is an upgrade! My
   [Slot Name] slot is empty."

4. **Compare against current item.** Use a simple stat sum comparison:
   - **For armor/jewelry:** Sum = AC + STR + STA + AGI + DEX + WIS + INT +
     CHA + HP + Mana. Compare the new item's sum against the currently equipped
     item's sum.
   - **For weapons:** Sum = DPS (damage / delay * 10, for a comparable scale) +
     STR + STA + AGI + DEX + WIS + INT + CHA + HP + Mana. Compare sums.

5. **Report the result:**
   - If the new item's stat sum is higher: "[Companion Name]: The [Item Name]
     is an upgrade over my [Current Item Name] (stat score: [new] vs [current])."
     The companion also links their currently equipped item so the player can
     manually inspect both.
   - If the current item's stat sum is equal or higher: "[Companion Name]: My
     [Current Item Name] is better than the [Item Name] (stat score: [current]
     vs [new])." The companion links their current item.

**Design rationale for simple stat sum:** The comparison is intentionally
simplistic. It gives the player a quick actionable signal ("probably an upgrade"
/ "probably not") without trying to model the complex interactions between stats,
class mechanics, and encounter-specific needs. The player always has the final
say — the companion links their current item so the player can inspect both and
make an informed decision.

**@all behavior:** Not supported for `!equipmentupgrade`. Item evaluation is
per-companion — sending to `@all` would produce a confusing flood of responses
from 5 companions evaluating the same item for different slots. If sent to
`@all`, only companions who can equip the item respond.

**Edge cases:**
- No item link in the message: "[Companion Name]: Please link an item for me
  to evaluate."
- Item has multiple possible slots (e.g., a ring): The companion evaluates
  against the first occupied slot; if both are empty, reports the empty slot.
  If both are occupied, compare against the weaker of the two equipped items.
- Companion is dead: No response (dead companions cannot evaluate items).
- Item is a NO DROP item the player hasn't looted yet: The player can still
  link it from a corpse. Evaluation works normally.

---

#### !equipmentmissing — Show Empty Equipment Slots

**Purpose:** Have the companion list all equipment slots that currently have no
item equipped.

**Output format:**
```
[Companion Name] has nothing equipped in:
  Head, Face, Neck, Shoulders, Back, Arms, Wrist 1, Wrist 2, Hands,
  Finger 1, Finger 2, Legs, Feet, Waist, Secondary, Range, Ammo
```

**Rules:**
- Lists ALL empty slots regardless of the companion's class. The player decides
  which slots matter — a warrior with empty Range is different from a ranger
  with empty Range, but the companion lists it either way.
- If the companion has all 19 slots filled: "[Companion Name] has all equipment
  slots filled."
- Slot names use the same canonical names as the existing `!equipment` command
  and `!unequip` slot aliases (Head, Face, Neck, Shoulders, Chest, Back, Arms,
  Wrist 1, Wrist 2, Hands, Finger 1, Finger 2, Legs, Feet, Waist, Primary,
  Secondary, Range, Ammo).

**@all behavior:** Each companion reports their empty slots independently.
Reports are delivered sequentially.

**Edge cases:**
- Companion is dead: Still reports empty slots — death does not change
  equipment state.
- Companion has no equipment at all (newly recruited, never traded items):
  Lists all 19 slots.

---

#### !help — Command Reference Card

**Purpose:** Display a complete list of ALL companion commands with brief
descriptions. This is the player's in-game reference card.

**Output format:**
```
Companion Commands Reference:
  Recruitment & Dismissal:
    recruit / join me / come with me    — Recruit an NPC as a companion
    dismiss / leave / goodbye           — Dismiss a companion
  Stances:
    !passive                            — Stop fighting, ignore threats
    !balanced                           — Fight only when attacked (default)
    !aggressive                         — Seek and attack nearby enemies
  Movement:
    !follow                             — Follow the player
    !guard / !stay                      — Hold current position
    !tome                               — Come to player's location
    !flee                               — Disengage, come to player, follow
  Combat:
    !assist                             — Attack player's current target
  Buffs:
    !buffme                             — Refresh buffs on player only
    !buffs                              — Refresh buffs on all party members
  Equipment:
    !equipment / show equipment         — Show all equipped items
    !unequip <slot>                     — Remove item from slot
    !unequip all                        — Remove all equipped items
    !equipmentupgrade [item link]       — Evaluate if item is an upgrade
    !equipmentmissing                   — Show empty equipment slots
  Information:
    !status                             — Show HP, mana, stance, buffs
    !help                               — Show this reference card
  Addressing:
    @name !command                      — Send command to specific companion
    @all !command                       — Send command to all companions
```

**Rules:**
- The help text is static — it does not vary by companion class or state.
- The help text includes BOTH existing commands (from the companion-commands-
  reference) AND the new commands from this feature.
- Categories are organized by function for quick scanning.
- The response is delivered as a single message, not multiple messages.

**@all behavior:** When sent to `@all`, only ONE companion responds with the
help text (the first companion matched). There is no need for every companion
to send identical help text.

---

#### !follow — Follow the Player

**Purpose:** Order the companion to follow the player. This command already
exists in the `/say` command system; this feature ensures it also works
through group chat addressing.

**Behavior:**
- Sets the companion's movement mode to FOLLOW.
- The companion begins trailing the player at the standard follow distance
  (100 units).
- If the companion was in GUARD mode, they leave their guard position and
  begin following.

**Feedback messages:**
- On receipt: "[Companion Name] begins following you." (existing message)
- If companion is already following: "[Companion Name] is already following
  you." (or just re-confirm follow mode silently)

**@all behavior:** All companions switch to follow mode.

**Edge cases:**
- Companion is dead: "[Companion Name] is dead and cannot follow."
- Companion is in combat: Companion continues fighting but will follow after
  combat ends (follow mode is set, but combat takes priority).

---

### Balance Considerations

#### Interaction with 1-3 Player Constraint

These commands are essential for making the companion system viable for small
groups. A solo player managing 5 companions needs efficient communication tools
to make tactical decisions quickly. Without these commands, the solo player
experience is:

- Manually target each companion → `/say !passive` → retarget mob → repeat
  for each companion during an emergency (the `!flee` scenario)
- Open trade window → hand item to companion → check if it was better →
  repeat for every piece of loot across every companion (the `!equipmentupgrade`
  scenario)
- Have no way to know which companion needs gear in which slots without
  checking all 5 companions' equipment one by one (the `!equipmentmissing`
  scenario)

With these commands, the same player can:
- `/gsay @all !flee` — one command, all companions retreat
- `/gsay @iskarr !equipmentupgrade [Mithril Breastplate]` — instant evaluation
- `/gsay @all !equipmentmissing` — complete gear gap analysis in one command

#### No New Power

These commands do not increase companion power. They increase companion
**usability**. A player who could already manually execute every action these
commands automate gains no combat advantage from this feature. It raises the
floor of companion management efficiency, not the ceiling of companion
capability.

The `!assist` command deserves special mention: it does not add a new combat
behavior. Companions in balanced/aggressive stance already attack things. This
command lets the player direct WHICH target the companion attacks, which is
basic group coordination that EverQuest groups have always relied on (the
`/assist` command has existed since Classic).

#### Buff Queue vs Immediate Cast

The `!buffme` and `!buffs` commands deliberately queue buff requests rather
than forcing immediate casts. This prevents:
- Interrupting a companion's heal mid-cast to buff instead
- Breaking a companion's combat spell rotation for a non-urgent buff
- Allowing players to spam-queue buff requests during combat

The companion's existing spell AI decides WHEN to cast the buffs — the player
only decides THAT buffs should be refreshed.

#### Flee Realism

The `!flee` command intentionally does NOT clear hate. This prevents:
- Trivial escapes from any encounter (pull → fail → flee → no consequence)
- Exploiting flee + re-engage to reset companion positioning
- Removing the tactical decision of "when to cut your losses"

A flee that clears hate would be functionally equivalent to an instant evac
for companions, which would trivialize dungeon content.

### Era Compliance

This feature introduces no era-specific content. All commands are quality-of-life
interaction mechanisms that work within the existing EQ chat system.

- **`/gsay` commands are era-appropriate.** Group say and group communication
  have existed since Classic EQ. Using group chat for companion commands is
  consistent with how EQ groups have always coordinated.

- **`/assist` is a Classic command.** The EQ client has had `/assist` since
  launch. The `!assist` companion command mirrors this fundamental group
  mechanic.

- **No post-Luclin references.** No zones, NPCs, items, spells, or lore from
  expansions beyond Luclin are referenced.

- **Buff spells are era-locked.** The `!buffme`/`!buffs` commands use whatever
  spells are in the companion's spell list. Those spell lists are already
  era-locked to Classic-Luclin via the `companion_spell_sets` table. This
  feature adds no new spells.

- **Item evaluation uses era-appropriate stats.** The `!equipmentupgrade`
  stat sum formula (AC + stats + HP + Mana for armor; DPS + stats for weapons)
  uses only stat categories that existed in Classic EQ. No heroic stats, no
  combat effects, no post-Luclin item properties.

## Affected Systems

- [x] C++ server source (`eqemu/`)
  - Companion command handler for new commands
  - Group chat command routing (building on group-chat-addressing feature)
  - Buff queue mechanism (if not already in companion AI)
  - `!tome` movement command
  - `!flee` macro command (stance + movement + follow)
  - `!assist` target engagement + auto-stance-switch
  - `!equipmentupgrade` item evaluation logic
  - `!equipmentmissing` slot enumeration
  - `!status` state reporting

- [x] Lua quest scripts (`akk-stack/server/quests/`)
  - Command handler updates in `companion.lua` for new commands
  - Possible updates to `global_npc.lua` for command routing

- [ ] Perl quest scripts (maintenance only)

- [ ] Database tables (`peq`)

- [ ] Rule values

- [ ] Server configuration

- [ ] Infrastructure / Docker

## Dependencies

1. **Group Chat Addressing System** (`feature/group-chat-addressing`) — This
   feature depends on the `@name`/`@all` group chat addressing system being
   implemented. All commands are designed to be issued via `/gsay @name !command`.
   The commands should also work via the existing `/say` targeting path for
   backward compatibility.

2. **Companion Recruitment System** — The base companion system must be
   functional: NPCs can be recruited, join the player's group, and respond to
   commands.

3. **Companion AI Stances** (`feature/companion-ai-stances`) — The `!flee`
   command sets passive stance and `!assist` may auto-switch from passive to
   balanced. The stance system must be fully functional for these commands to
   work correctly.

4. **Companion Equipment System** (`feature/companion-equipment`) — The
   `!equipmentupgrade` and `!equipmentmissing` commands require the per-slot
   equipment system to be in place. Without it, there is no per-slot data to
   evaluate against.

5. **Companion Spell System** — The `!buffme`/`!buffs` commands rely on the
   companion's spell list (`companion_spell_sets` table) and the class-specific
   spell AI (`companion_ai.cpp`) to determine which buffs to cast and when.

## Open Questions

1. **Should `!equipmentupgrade` include resist stats in the comparison?**
   The current design uses AC + base stats + HP + Mana. Adding fire resist,
   cold resist, etc. to the stat sum would make resist gear show as upgrades
   over non-resist gear, which may not always be desirable. Recommendation:
   keep the formula simple (no resists) and let the player decide if resist
   gear is situationally better.

2. **Should `!status` show exact buff tick counts or just minutes?** Minutes
   is more player-friendly, but ticks (6-second intervals) is more precise.
   Recommendation: minutes (rounded down), with "<1 min" for buffs about to
   expire.

3. **How does `!buffme` interact with the companion's existing buff AI
   schedule?** If the companion's AI was already planning to buff on its next
   idle cycle, does `!buffme` create a duplicate queue entry? Recommendation:
   `!buffme` replaces any pending buff queue rather than stacking.

4. **Should there be a cooldown on `!status` to prevent chat spam?** If a
   player sends `@all !status` to 5 companions every 10 seconds, that is a
   lot of chat text. Recommendation: No cooldown — let the player decide how
   often to check. The text is informational, not spammy like LLM responses.

5. **How should `!equipmentupgrade` handle items that can go in multiple slots
   (rings, wrists)?** The design says compare against the weaker equipped item
   if both slots are occupied. The architect should determine if this is
   implementable with the current inventory inspection API.

6. **What happens if `!assist` is issued but the companion cannot path to the
   target?** Should there be a timeout message, or does the companion simply
   attempt to move and fail silently? Recommendation: let the existing pathing
   system handle it — no special timeout needed.

## Acceptance Criteria

### !status
- [ ] `/gsay @companionname !status` displays HP (current/max/%), mana
  (current/max/% or N/A), stance, target, sit/stand state, and active buff
  list with time remaining
- [ ] Buff durations are shown in minutes (rounded down), with "<1 min" for
  buffs expiring within 60 seconds
- [ ] Pure melee companions show "Mana: N/A" instead of mana values
- [ ] Dead companions report HP as 0 with "DEAD" indicator
- [ ] `@all !status` produces reports from all companions
- [ ] `!status` never interrupts companion activity

### !buffme
- [ ] `/gsay @companionname !buffme` queues a buff refresh targeting the player
- [ ] Buff request does not interrupt current combat or casting
- [ ] Companion casts available buff spells on the player during next idle window
- [ ] Non-caster companions (warrior, rogue, monk) respond with "no buff spells"
- [ ] OOM companions (below 10% mana) respond with "too low on mana"
- [ ] Dead companions respond with "is dead and cannot cast spells"
- [ ] `@all !buffme` queues buffs from all capable companions

### !buffs
- [ ] `/gsay @companionname !buffs` queues a buff refresh for all party members
- [ ] Same queuing behavior as `!buffme` (waits for idle window)
- [ ] Companion casts on all group members, not just the player
- [ ] Same edge case handling as `!buffme` (non-caster, OOM, dead)

### !tome
- [ ] `/gsay @companionname !tome` causes companion to move to player's location
- [ ] Companion moves to the player's X/Y/Z coordinates at command time
- [ ] After arriving, companion resumes previous movement mode (follow or guard)
- [ ] Companion already near the player (within 50 units) responds "already nearby"
- [ ] Dead companions respond with "is dead and cannot move"
- [ ] `@all !tome` moves all companions to the player

### !flee
- [ ] `/gsay @companionname !flee` sets passive stance + moves to player + follows
- [ ] Companion's hate list is NOT cleared (mobs continue to chase)
- [ ] Companion stops all combat activity immediately upon receiving command
- [ ] `@all !flee` causes all companions to disengage and retreat
- [ ] Dead companions respond with "is dead and cannot flee"
- [ ] Works correctly when companion was already passive (still moves to player)

### !assist
- [ ] `/gsay @companionname !assist` causes companion to attack player's target
- [ ] If companion was passive, auto-switches to balanced stance before engaging
- [ ] If player has no target, companion responds with "no target to assist with"
- [ ] If player targets a friendly entity, companion responds with "will not
  attack a friendly target"
- [ ] If player targets the companion itself, companion responds with "will not
  attack themselves"
- [ ] `@all !assist` causes all companions to attack the player's target
- [ ] Dead companions respond with "is dead and cannot fight"

### !equipmentupgrade
- [ ] `/gsay @companionname !equipmentupgrade [Item Link]` evaluates the item
- [ ] Items the companion cannot equip (class/race restrictions) produce no
  response (silent)
- [ ] Empty target slot always responds YES with "slot is empty" message
- [ ] Occupied slot compares stat sums and reports upgrade/downgrade with scores
- [ ] Companion links their currently equipped item in the response
- [ ] Missing item link produces "please link an item" message
- [ ] Stat sum formula: AC + STR + STA + AGI + DEX + WIS + INT + CHA + HP + Mana
  for armor; DPS + stats for weapons

### !equipmentmissing
- [ ] `/gsay @companionname !equipmentmissing` lists all empty equipment slots
- [ ] All 19 slot names are checked and empty ones reported
- [ ] Fully equipped companion responds "all equipment slots filled"
- [ ] `@all !equipmentmissing` produces reports from all companions

### !help
- [ ] `/gsay @companionname !help` displays the complete command reference card
- [ ] Reference includes both existing commands AND new commands from this feature
- [ ] Commands are organized by category (Recruitment, Stances, Movement, etc.)
- [ ] When sent to `@all`, only one companion responds (no duplicate help text)

### !follow
- [ ] `/gsay @companionname !follow` sets companion to follow mode
- [ ] Companion begins trailing player at standard distance
- [ ] Works correctly when companion was in guard mode
- [ ] `@all !follow` sets all companions to follow
- [ ] Dead companions respond with "is dead and cannot follow"

### General
- [ ] All 9 commands work through both `/gsay @name` addressing AND existing
  `/say` targeting
- [ ] All commands work in EQ macro hotbuttons (no syntax issues)
- [ ] No command causes the player's target to change
- [ ] Error/feedback messages are clear and include the companion's name
- [ ] Commands sent to dead companions produce appropriate "is dead" messages
- [ ] No command crashes the server or produces unhandled exceptions

---

## Appendix: Technical Notes for Architect

These are advisory observations from the game designer. The architect makes all
implementation decisions.

### Existing Command Handler

The companion command system currently routes through:
- `global_npc.lua` intercepts `event_say` events
- `companion.lua:handle_command()` processes `!`-prefixed commands
- C++ `Companion` class methods handle the actual behavior

The group chat addressing system (`feature/group-chat-addressing`) routes
`@name !command` payloads to the same command handler. New commands should follow
this existing pattern.

### Buff Queue Implementation

The companion spell AI (`companion_ai.cpp`) already has buff casting logic in
its idle behavior. The `!buffme`/`!buffs` commands could set a flag or priority
override that causes the next AI idle cycle to prioritize buff casting on the
specified targets. This avoids needing a separate queue system — it leverages
the existing AI tick loop.

Relevant code paths:
- `companion_ai.cpp:434` — buff conservation threshold (30% mana)
- `companion_ai.cpp:355-423` — `AI_HealGroupMember` (similar target iteration)
- `companion_ai.cpp:830+` — class-specific AI with buff logic

### Status Reporting

For `!status`, the data is readily available:
- HP/Mana: `GetHP()`, `GetMaxHP()`, `GetMana()`, `GetMaxMana()`
- Stance: `GetStance()` returns 0/1/2
- Target: `GetTarget()` → `GetCleanName()`
- Sit/Stand: `IsNPC()` NPCs don't sit, but companions override this
- Buffs: `GetBuffSlotEntry(slot)` iterates buff slots, `CalcBuffDuration_formula()`
  for remaining time

### Equipment Evaluation

The `!equipmentupgrade` command needs to:
1. Parse the item link from the chat message (item links are encoded in EQ's
   special format)
2. Look up the `ItemData` for the linked item
3. Check class/race restrictions against the companion
4. Determine the target slot
5. Compare stat sums

Item data is accessible via `database.GetItem(item_id)` or
`content_db.GetItem(item_id)`. The companion's equipped items are in
`GetInv().GetItem(slot)`.

### Stat Sum Formula

For `!equipmentupgrade`, suggested stat sum calculation:

**Armor/jewelry:**
`score = AC + STR + STA + AGI + DEX + WIS + INT + CHA + HP + Mana`

**Weapons:**
`score = (Damage * 10 / Delay) + STR + STA + AGI + DEX + WIS + INT + CHA + HP + Mana`

The `Damage * 10 / Delay` scaling puts weapon DPS on a comparable magnitude to
stat points. This is intentionally approximate.

### Follow Command

The `!follow` command already exists in the `/say` command system
(`companion.lua:handle_command()`). For group chat, the routing just needs to
ensure the same handler is reached. No new C++ implementation should be needed
beyond the command routing.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
