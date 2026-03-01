# Recruited NPC Controls — Product Requirements Document

> **Feature branch:** `feature/recruited-npc-controls`
> **Author:** game-designer
> **Date:** 2026-02-28
> **Status:** Approved

---

## Problem Statement

The companion system currently routes all player communication through
keyword matching in `/say`. When a player says "follow" to their companion,
it triggers follow mode -- but so does "I'll follow the trail ahead."
Saying "leave the castle" triggers dismissal. Saying "I need to guard
this passage" triggers guard mode.

This is a critical problem because the companion system is designed around
**natural conversation**. Companions have LLM-powered dialogue with soul
elements, cultural voice, and memory. Players are meant to *talk* to their
companions -- ask about their past, discuss strategy, roleplay. But any
utterance containing a management keyword is intercepted before it reaches
the LLM, silently converting conversation into a command.

The result: players must carefully avoid common English words when speaking
to their companions, which defeats the entire purpose of the LLM conversation
system.

## Goals

1. **Separate commands from conversation.** Players must be able to talk
   naturally to companions without accidentally triggering management commands.
   Commands use a distinct prefix; everything else flows to the LLM for
   natural dialogue.

2. **Maintain discoverability.** New players must be able to find all
   available companion commands without external documentation. An in-game
   help command lists every command with a brief description.

3. **Improve companion management.** Add missing management commands that
   players need for effective companion control (status overview, targeting,
   recall, equipment exchange).

4. **Keep recruitment natural.** Recruitment commands ("recruit", "join me",
   etc.) remain keyword-based -- the natural phrasing IS the intended player
   experience when convincing an NPC to join.

5. **Zero C++ changes.** The prefix system is implementable entirely in Lua
   quest scripts, requiring no server recompilation.

## Non-Goals

- **Name-based addressing** ("Monia, follow") as the primary command system.
  While more immersive, NPC names in EQ are unpredictable ("a Qeynos guard",
  names with spaces, identical names). This could be explored as a future
  enhancement but is not in scope for this feature.
- **Changing the recruitment flow.** Recruitment keywords, eligibility checks,
  persuasion rolls, and the entire `attempt_recruitment()` pipeline are
  unchanged.
- **Pet command integration.** Pet commands use `OP_PetCommands` (a dedicated
  protocol packet, not chat text) and have zero interaction with this system.
- **Bot command integration.** Bot commands use the `^` prefix and their own
  dispatch path. This system is deliberately separate.
- **Changing companion AI behavior.** This PRD covers the command interface,
  not how companions make combat or spell decisions.
- **Trade window C++ implementation.** If the architect determines that a
  companion trade window requires C++ changes, that work would be scoped
  separately.

## User Experience

### The Core Principle

When a player targets their companion and types `/say`, the system asks
one question: **does this message start with `!`?**

- **Yes (`!follow`):** This is a command. Parse and execute it. The companion
  responds with a brief, in-character acknowledgment.
- **No ("How are you holding up?"):** This is conversation. Pass the full
  message to the LLM. The companion responds with natural, personality-driven
  dialogue.

### Player Flow

1. Player recruits a companion using natural language ("Join me", "Come with
   me", etc.) -- this flow is unchanged.

2. After recruitment, the companion follows and fights alongside the player.
   The player can speak to their companion in two modes:

   **Command mode** (prefixed with `!`):
   - `/say !follow` -- companion follows the player
   - `/say !guard` -- companion holds position
   - `/say !passive` -- companion stops fighting
   - `/say !help` -- lists all available commands

   **Conversation mode** (no prefix):
   - `/say How are you holding up after that fight?`
   - `/say Tell me about your life before we met.`
   - `/say What do you think about this place?`

3. Commands always target the player's current target. If the player has
   multiple companions, they target the one they want to command.

4. If the player types `!` followed by an unrecognized command, the system
   suggests using `!help`.

5. If the player types a `!` command while targeting a non-companion NPC,
   they receive a message: "That is not your companion."

### Example Scenario

A level 35 ranger has recruited "Guard Hansl", a warrior companion, in
North Karana. They're traveling toward Rathe Mountains.

> **Player** `/say` to Guard Hansl: `!aggressive`
> **Guard Hansl** says, "Understood. I will fight aggressively."

> **Player** `/say` to Guard Hansl: `Tell me about Qeynos.`
> **Guard Hansl** says, "I served the south gate for eight years. The
> merchants come through at dawn, the trouble comes after dark. I do not
> miss the cold."

> **Player** `/say` to Guard Hansl: `!guard`
> **Guard Hansl** says, "I will hold here."

> **Player** `/say` to Guard Hansl: `Stay safe while I scout ahead.`
> **Guard Hansl** says, "I will keep watch. Return quickly."

Notice: "Stay safe" does not trigger guard mode, even though the old system
would have matched the keyword "stay." And "I will keep watch" is the LLM's
natural response, not the guard-mode acknowledgment.

### Another Scenario: Equipment Management

> **Player** `/say` to Guard Hansl: `!equipment`
> System displays:
> ```
> Guard Hansl's Equipment:
>   Primary: Rusty Long Sword
>   Secondary: (empty)
>   Chest: Banded Mail
>   Legs: (empty)
> ```

> **Player** `/say` to Guard Hansl: `!unequip primary`
> **Guard Hansl** says, "As you wish." (returns Rusty Long Sword to player)

> **Player** `/say` to Guard Hansl: `!help equipment`
> System displays:
> ```
> Equipment Commands:
>   !equipment        - Show companion's equipped items
>   !unequip <slot>   - Companion returns item from slot
>   !unequip all      - Companion returns all equipped items
>   !equip            - Open trade window to give items
> ```

### Help Command

Typing `!help` (or just `!`) displays a categorized command list:

```
=== Companion Commands ===

Stance:
  !passive       - Disengage from combat, follow owner
  !balanced      - Default combat stance
  !aggressive    - Actively pursue and attack enemies

Movement:
  !follow        - Follow you at standard distance
  !guard         - Hold current position
  !recall        - Return to your side (if stuck or distant)

Equipment:
  !equipment     - Show equipped items
  !unequip <slot> - Return item from slot (e.g., !unequip primary)
  !unequip all   - Return all equipped items
  !equip         - Open trade window to give items

Information:
  !status        - Show companion overview (HP, level, stance, mode)
  !help          - Show this command list
  !help <topic>  - Show details for a command category

Control:
  !dismiss       - Dismiss companion (can be re-recruited later)

Combat:
  !target        - Companion targets your current target
  !assist        - Companion assists you (attacks what you attack)

To talk to your companion naturally, just /say without the ! prefix.
Type '!help <topic>' for details (e.g., '!help stance').
```

## Game Design Details

### Mechanics

#### Prefix Detection

Any `/say` message to a companion NPC that begins with `!` is treated as a
command. The `!` character and command word are stripped, and the remaining
text (if any) is passed as arguments.

Messages that do not start with `!` are passed unmodified to the LLM
conversation system (via `llm_bridge` in `global_npc.lua`).

The prefix detection happens at the Lua layer in `global_npc.lua`, before
the current `is_management_keyword()` check. The flow becomes:

```
event_say fires
  |
  +-- Is NPC a companion? (IsCompanion())
  |     |
  |     +-- Does message start with '!'?
  |     |     +-- YES: parse and dispatch command
  |     |     +-- NO: pass to LLM for conversation
  |     |
  |     (old keyword matching is removed for companions)
  |
  +-- Is message a recruitment keyword? (non-companion NPCs only)
  |     +-- YES: attempt_recruitment()
  |     +-- NO: fall through to LLM
```

#### Command List

All management commands move to `!` prefix. The old keyword aliases are
removed for companion NPCs. Non-companion NPCs are unaffected.

**Stance Commands:**

| Command | Effect | Response |
|---------|--------|----------|
| `!passive` | Set stance to PASSIVE (0) — disengage combat, follow owner | "I will stand down." |
| `!balanced` | Set stance to BALANCED (1) — default combat behavior | Companion: "I will fight at your side." / Mercenary: "Understood." |
| `!aggressive` | Set stance to AGGRESSIVE (2) — actively pursue enemies | "Understood. I will fight aggressively." |

**Movement Commands:**

| Command | Effect | Response |
|---------|--------|----------|
| `!follow` | Resume following owner at standard distance (100 units) | "I will follow." |
| `!guard` | Hold current position, stop following | "I will hold here." |
| `!recall` | **(NEW)** Teleport companion to owner's position if distance > 200 units. Resets pathing. Useful when companion is stuck on terrain or fell behind during a zone transition. | "I am here." |

**Equipment Commands:**

| Command | Effect | Response |
|---------|--------|----------|
| `!equipment` | Display all equipped items with slot names | (system message listing gear) |
| `!unequip <slot>` | Return item from specified slot to player's inventory | "As you wish." |
| `!unequip all` | Return all equipped items to player | "As you wish." |
| `!equip` | **(NEW)** Open a trade window between player and companion, allowing the player to give items using the standard EQ trade interface. Items placed in the trade window are auto-equipped by the companion into appropriate slots. | (trade window opens) |

Valid slot names for `!unequip`: charm, ear1, head, face, ear2, neck,
shoulder, arms, back, wrist1, wrist2, range, hands, primary, secondary,
finger1, finger2, chest, legs, feet, waist, ammo.

**Information Commands:**

| Command | Effect | Response |
|---------|--------|----------|
| `!status` | **(NEW)** Display companion overview: name, level, HP/mana, current stance, movement mode, companion type. | (system message with stats) |
| `!help` | Display categorized command list (see Help Command section above) | (system message with command list) |
| `!help <topic>` | Display detailed help for a command category (stance, movement, equipment, combat, control) | (system message with category details) |

**Combat Commands:**

| Command | Effect | Response |
|---------|--------|----------|
| `!target` | **(NEW)** Companion targets the same entity the player is currently targeting (switches companion's attack target in combat, or sets focus target out of combat). | "I see your target." |
| `!assist` | **(NEW)** Companion assists the player -- attacks whatever the player is currently attacking. Functionally similar to `!target` but intended as a combat-flow command (semantically: "help me fight this"). | "I will assist." |

**Control Commands:**

| Command | Effect | Response |
|---------|--------|----------|
| `!dismiss` | Dismiss companion (voluntary). Companion is suspended with re-recruitment bonus (+10%). Same behavior as current dismiss. | "Farewell." |

#### Recruitment Commands (Unchanged)

Recruitment remains keyword-based and unaffected by this feature. When a
player says "recruit", "join me", "come with me", etc. to a non-companion
NPC, the recruitment flow triggers exactly as it does today. This is
intentional: the act of persuading an NPC to join should feel like a
conversation, not a system command.

#### Removed Keywords

The following keyword aliases are removed from companion management:

| Old Keyword | Replacement | Reason |
|-------------|-------------|--------|
| `leave` | `!dismiss` | "leave" is common in conversation |
| `goodbye` | `!dismiss` | common farewell in conversation |
| `farewell` | `!dismiss` | common farewell in conversation |
| `release` | `!dismiss` | ambiguous in conversation |
| `stance` | `!balanced` | vague; explicit command is clearer |
| `stay` | `!guard` | "stay safe" / "stay here" collision |
| `show equipment` | `!equipment` | multi-word keyword, fragile matching |
| `show gear` | `!equipment` | alias, consolidated |
| `inventory` | `!equipment` | alias, consolidated |
| `give me your <slot>` | `!unequip <slot>` | natural language collision |
| `give me everything` | `!unequip all` | natural language collision |

#### Error Handling

| Scenario | System Response |
|----------|----------------|
| `!follow` targeting a non-companion NPC | "That is not your companion." |
| `!follow` with no target | "You must target a companion to use commands." |
| `!invalidcommand` | "Unknown command. Type !help for available commands." |
| `!` alone (nothing after prefix) | Show the full help command list |
| `!unequip badslot` | "Unknown slot name. Valid slots: primary, secondary, head, chest..." |
| `!unequip primary` when slot is empty | "Nothing equipped in that slot." |
| `!recall` when companion is within 200 units | "Your companion is already nearby." (no teleport) |
| `!equip` targeting non-companion | "That is not your companion." |
| `!target` when player has no target | "You must target an enemy first." |

### Balance Considerations

This feature is a **UI/interaction change**, not a power change. It does not
alter companion combat performance, stats, AI behavior, or recruitment
mechanics.

The new commands add convenience, not power:
- `!recall` prevents companions from being permanently stuck on terrain, which
  is a quality-of-life fix, not a combat advantage. The 200-unit minimum
  prevents abuse as a positioning tool in combat.
- `!target` and `!assist` formalize what players already do by switching
  targets and relying on companion AI aggro. They make the experience smoother
  without changing combat outcomes.
- `!status` is information-only.
- `!equip` via trade window is the standard EQ item exchange mechanism and
  does not change what items companions can equip.

**1-player scenario:** Solo player commands one companion -- straightforward,
all commands apply to the targeted companion.

**6-player scenario:** Each player may have one companion. Commands always
target the player's current target, so there is no ambiguity about which
companion receives the command. A player can only command their own
companion(s) -- targeting another player's companion and using `!dismiss`
has no effect (ownership check).

### Era Compliance

This feature has no era compliance concerns. The `!` prefix is a UI/interaction
mechanic with no references to specific zones, NPCs, deities, factions, or
expansion-specific content.

All command vocabulary is era-neutral. The NPC response phrases ("I will hold
here", "Understood", "Farewell") use the same terse, period-appropriate
register already established in the companion system.

*Era compliance confirmed by lore-master pre-review (2026-02-28).*

## Affected Systems

- [x] Lua quest scripts (`akk-stack/server/quests/`)
  - `global/global_npc.lua` — add prefix detection before companion command dispatch
  - `lua_modules/companion.lua` — replace keyword matching with prefix-based command parsing; add new command handlers
- [ ] C++ server source (`eqemu/`) — **not required** for prefix system, command parsing, help, status, recall, target, or assist. May be needed for trade window support (`!equip`); architect to assess.
- [ ] Database tables (`peq`) — no schema changes anticipated
- [ ] Rule values — no new rules required; existing companion rules unchanged
- [ ] Server configuration — no changes
- [ ] Perl quest scripts — no changes (companion system is Lua-only)
- [ ] Infrastructure / Docker — no changes

## Dependencies

- **Companion system (Phase 4) must be operational.** The command prefix
  system builds on the existing companion recruitment, management, and
  LLM conversation infrastructure.
- **LLM sidecar must be running.** Unprefixed conversation flows to the
  LLM bridge. If the sidecar is down, companions simply don't respond to
  conversation (existing graceful fallback behavior).
- **No other features block this work.** This is a self-contained
  interaction layer change.

## Open Questions

1. **Trade window for `!equip`:** Can the existing EQ trade window be opened
   programmatically between a player and a companion NPC from Lua? The
   architect should investigate whether this requires C++ API additions or
   if there is an existing Lua binding. If trade window support requires
   significant C++ work, `!equip` can be deferred to a follow-up feature
   and players can continue giving items to companions through other means.

2. **`!recall` teleport mechanics:** Should `!recall` have a cooldown to
   prevent spamming? Suggested: 30-second cooldown via data bucket, but
   the architect should confirm this is appropriate and determine if there
   are edge cases with zone boundaries or instances.

3. **`!target` and `!assist` scope:** Should these commands work in all
   stances, or only when the companion is in balanced or aggressive stance?
   (Proposed: they work in all stances but passive companions do not attack
   the target, they only face it. This preserves the meaning of passive mode.)

4. **Multi-companion commands:** If a player has multiple companions in the
   future, should there be a way to send a command to all of them at once
   (e.g., `!all follow`)? Not in scope for this PRD but worth noting for
   future design.

## Acceptance Criteria

- [ ] Typing `!<command>` to a targeted companion executes the command and
  the companion responds with a brief, in-character acknowledgment
- [ ] Typing any text without the `!` prefix to a targeted companion sends
  the text to the LLM and the companion responds with natural dialogue
- [ ] The old keyword-based management commands (follow, guard, stay, passive,
  etc.) no longer trigger command actions when spoken without the `!` prefix
  to a companion -- they flow to the LLM instead
- [ ] `!help` displays a complete, categorized list of all available commands
- [ ] `!help <topic>` displays detailed help for that command category
- [ ] Typing `!` alone shows the help list
- [ ] Typing an unrecognized `!command` shows an error with a suggestion to
  use `!help`
- [ ] `!status` displays the companion's name, level, HP, mana, stance, and
  movement mode
- [ ] `!recall` teleports a stuck companion to the player's location (only
  if distance > 200 units)
- [ ] `!target` causes the companion to target the player's current target
- [ ] `!assist` causes the companion to assist the player in combat
- [ ] `!equipment` shows the companion's equipped items
- [ ] `!unequip <slot>` returns the item from the specified slot to the player
- [ ] `!unequip all` returns all equipped items
- [ ] `!dismiss` dismisses the companion with voluntary=true (re-recruit bonus)
- [ ] Commands targeting a non-companion NPC produce: "That is not your companion."
- [ ] Commands with no target produce: "You must target a companion to use commands."
- [ ] Recruitment commands (recruit, join me, etc.) continue to work as
  keyword-based commands for non-companion NPCs, unchanged
- [ ] A player cannot command another player's companion (ownership check)
- [ ] All companion command responses use terse, era-appropriate language
  (1-2 sentences maximum)

---

## Appendix: Technical Notes for Architect

These notes are advisory only. The architect makes all implementation decisions.

**Prefix detection insertion point:** The `!` prefix check should be added
to `global_npc.lua:event_say()` before the existing `IsCompanion()` +
`is_management_keyword()` block. Suggested flow:

```
if e.self:IsCompanion() then
    if message starts with "!" then
        -- strip prefix, dispatch to command handler
    else
        -- pass to LLM (existing llm_bridge flow)
    end
    return  -- companions no longer fall through to keyword matching
end
```

**Command parser location:** A new function in `companion.lua` (e.g.,
`companion.dispatch_prefix_command(npc, client, message)`) that strips the
`!`, splits on the first space to get command + args, and dispatches to the
appropriate handler.

**`!recall` implementation:** The existing `Mob::GMMove()` or equivalent Lua
binding (e.g., `npc:MoveTo()`) could teleport the companion to the owner's
coordinates. The 200-unit minimum distance check prevents abuse. A data
bucket with 30-second TTL could serve as cooldown.

**`!target` and `!assist` implementation:** The companion AI system already
tracks targets. These commands would set the companion's hate target or assist
target. The Lua API likely needs `companion:SetTarget(mob)` or similar -- the
architect should check if this binding exists.

**`!equip` trade window:** In standard EQEmu, `Client::TradeWithNPC()` or
similar C++ path handles trade windows. Whether this can be triggered from
Lua for a Companion entity (which extends NPC) is a question for the
architect. If not trivially available, `!equip` can be deferred.

**Rule name suggestions (advisory):**
- `Companions:CommandPrefix` (string, default "!") -- allows server operators
  to change the prefix character if desired
- `Companions:RecallCooldownS` (int, default 30) -- recall cooldown in seconds
- `Companions:RecallMinDistance` (float, default 200) -- minimum distance for
  recall to activate

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
