# Group Chat Companion Addressing — Product Requirements Document

> **Feature branch:** `feature/group-chat-addressing`
> **Author:** game-designer
> **Date:** 2026-03-07
> **Status:** Approved

---

## Problem Statement

Controlling recruited NPC companions during combat on our 1–3 player server
requires targeting each companion individually and using `/say` to issue
commands or have conversations. This creates two critical problems:

1. **Combat disruption:** Switching targets mid-fight to issue companion
   orders (e.g., telling a cleric companion to cast a heal, or ordering a
   warrior companion to attack a specific mob) forces the player to break
   their combat flow. In a server designed for 1–3 players, where companions
   fill essential party roles, this interruption is constant and painful.

2. **Macro impossibility:** Since `/say` commands require the companion to
   be the current target, players cannot create macros that issue orders to
   multiple companions in sequence — each command would need a target switch
   in between. This makes coordinated companion tactics impractical, which
   undermines the core premise of making all content accessible to small groups.

3. **Conversation friction:** The LLM-powered NPC conversation system
   currently only works through `/say` (requiring the NPC to be targeted).
   Players who want to chat with a companion while fighting or while
   targeting something else simply cannot. Companion personality — a key
   part of the recruitment experience — becomes invisible during the majority
   of gameplay.

This feature is foundational infrastructure for the companion system. Without
it, companions are cumbersome to control. With it, they become responsive
party members that players can direct as naturally as typing in group chat.

## Goals

1. **Target-free companion control:** Players can issue commands to any
   recruited companion in their group via `/gsay` without changing their
   current target. Commands like `@iskarr !follow` or `@all !attack` work
   instantly regardless of what the player is targeting.

2. **Target-free companion conversation:** Players can talk to companions
   via `/gsay` using `@Name` addressing and receive LLM-generated responses
   in group chat. This makes companion personality accessible during combat,
   travel, and downtime without requiring a target switch.

3. **Multi-companion coordination:** Players can address multiple companions
   in a single message (`@iskarr and @astrid !follow`) or broadcast to all
   companions (`@all !attack`), enabling coordinated tactics through a single
   chat line.

4. **Macro-friendly syntax:** The `@Name !command` syntax works reliably in
   EQ macro lines, enabling players to create combat macros that orchestrate
   multiple companions (e.g., a "pull" macro that sends the tank companion
   to attack while telling others to hold position).

## Non-Goals

- **New UI elements or custom windows.** The Titanium client has no
  mechanism for custom UI. This feature works entirely within the existing
  `/gsay` chat channel.

- **Cross-zone companion addressing.** Companions must be in the same zone
  and group as the player. Cross-zone group chat routing is out of scope.

- **Changing how `/say` targeting works.** The existing `/say` + target
  system for companion commands and conversation remains unchanged. This
  feature adds a parallel path through `/gsay`, it does not replace `/say`.

- **Companion AI behavior changes.** This feature routes commands and
  conversations to companions — it does not change how companions interpret
  or execute those commands. Command execution is handled by the existing
  companion command system.

- **New commands.** No new `!commands` are introduced. This feature routes
  existing commands through a new channel.

- **Combat-aware LLM context.** Feeding live combat state (current target,
  HP, threat levels) into the LLM prompt for contextually appropriate
  companion responses is a future enhancement, not part of the core feature.

## User Experience

### Player Flow

1. **Player recruits companions as usual.** They have 1–3 NPC companions in
   their group (e.g., Guard Iskarr, a warrior; Priestess Astrid, a cleric;
   and Scout Verin, a ranger). The player is fighting mobs in a dungeon.

2. **Player issues a command via /gsay.** Mid-combat, the player types in
   the group chat window: `/gsay @iskarr !attack`. Guard Iskarr receives
   the `!attack` command and engages the player's current target — without
   the player ever switching their own target away from the mob they're
   fighting.

3. **Player issues a multi-companion command.** The player types:
   `/gsay @iskarr and @astrid !follow`. Both Guard Iskarr and Priestess
   Astrid receive the `!follow` command. Scout Verin is unaffected.

4. **Player broadcasts to all companions.** The player types:
   `/gsay @all !attack`. Every recruited companion in the group receives
   the `!attack` command.

5. **Player has a conversation via /gsay.** During downtime between pulls,
   the player types: `/gsay @astrid what do you think of this place?`.
   Priestess Astrid's response — generated by the LLM sidecar with her
   personality, zone knowledge, and conversation history — appears in
   group chat where all group members (including other companions) can
   "see" it.

6. **Player addresses multiple companions conversationally.** The player
   types: `/gsay @all how are you holding up?`. Each companion responds
   in group chat, with responses staggered 1–2 seconds apart to avoid
   a wall of text and to create a natural conversational cadence.

7. **Silent failure on bad names.** The player types:
   `/gsay @iskarr and @nobody !follow`. Guard Iskarr receives the
   `!follow` command. The `@nobody` mention matches no companion and is
   silently ignored — no error spam in group chat.

### Example Scenario

A level 45 shadow knight is clearing Sebilis with three recruited companions:
Guard Iskarr (warrior, tank), Priestess Astrid (cleric, healer), and Scout
Verin (ranger, DPS/puller). The shadow knight is currently targeting a
Sebilite Juggernaut.

**Combat situation:**

```
/gsay @iskarr !attack          → Iskarr engages the Juggernaut
                                  (player keeps Juggernaut targeted)

/gsay @astrid !follow          → Astrid moves to follow the player
                                  (no target switch needed)

/gsay @all !attack             → All three companions attack
                                  (single command, all companions respond)
```

**Macro example (player creates an EQ hotbutton):**

```
Line 1: /gsay @iskarr !attack
Line 2: /gsay @astrid !guard me
Line 3: /gsay @verin !assist iskarr
```

One button press issues three commands to three different companions.
The player never loses their target.

**Conversation during downtime:**

```
Player:    /gsay @iskarr this dungeon gives me the creeps
Iskarr:    [in group chat, 0-1s later] These Iksar ruins reek of old
           magic and older death. Keep your blade ready.
Player:    /gsay @all what do you think we'll find deeper in?
Astrid:    [in group chat, 0-1s later] The Sebilite have guarded their
           inner sanctums for ages. I sense powerful wards ahead.
Iskarr:    [in group chat, 1-2s after Astrid] Stronger Juggernaut
           types, probably. And their necromancers.
Verin:     [in group chat, 1-2s after Iskarr] My tracking shows
           movement deeper in. Something big.
```

## Game Design Details

### Mechanics

#### Addressing Syntax

The `@` symbol followed by a name fragment triggers companion addressing
when typed in `/gsay`. The system recognizes these patterns:

- **Single address:** `@name` — matches one or more companions by name
- **Multiple addresses:** `@name1 and @name2` — the word "and" between
  `@` mentions is treated as a separator and stripped from the payload
- **Broadcast:** `@all` — matches every recruited companion in the group
- **Mixed valid/invalid:** `@realname and @fakename` — valid matches
  proceed, invalid matches are silently dropped

The `@` symbol is only meaningful at the start of a word. Mid-word `@`
(like an email address) is not parsed.

#### Name Matching

Name matching uses these rules, applied in order:

1. **Case-insensitive:** `@iskarr`, `@Iskarr`, and `@ISKARR` all match
2. **Substring matching:** `@isk` matches "Guard Iskarr" — the match is
   checked against the full NPC name
3. **Common prefix stripping:** Before matching, these prefixes are removed
   from companion names: "Guard", "Captain", "Lady", "Lord", "Sir",
   "Priestess", "High Priestess", "Scout", "Merchant", "Innkeeper",
   "Banker", "Sage", "Elder", "Master", "Apprentice", "Lieutenant",
   "Warden", "Keeper", "Deputy", "Sergeant". So `@iskarr` matches
   "Guard Iskarr" without needing to type "Guard"
4. **Multiple matches:** If `@war` matches both "Guard Warrick" and
   "Priestess Warina", both receive the command. This is intentional — it
   enables shorthand addressing when companions have distinct name prefixes
5. **@all override:** `@all` is a reserved keyword that always means "all
   recruited companions in group" regardless of whether a companion is
   named "All"

#### Payload Types

Everything after the `@name` mentions constitutes the payload. The payload
is categorized by its first character:

- **Command payload (`!` prefix):** The text starting with `!` is routed
  to the existing `/say` command handler for each matched companion. The
  companion processes it exactly as if the player had targeted the companion
  and typed `/say !command`. Example: `@iskarr !follow` routes `!follow`
  to Guard Iskarr's command handler.

- **Conversational payload (no `!` prefix):** The text is routed to the
  LLM sidecar as a conversation request, with the response channel set to
  group chat instead of `/say`. Example: `@iskarr how's the fight going?`
  sends "how's the fight going?" to the LLM for Guard Iskarr.

#### Response Routing

- **Command responses** use existing feedback mechanisms. If a command
  produces a confirmation message (e.g., "Guard Iskarr begins to follow
  you"), that message appears wherever the existing command system sends it.
  No changes to command response routing.

- **Conversational responses** from the LLM sidecar are delivered in group
  chat (`/gsay`). This matches the channel the player initiated from,
  creating a natural group conversation flow. The companion's name appears
  as the speaker, just like any group member speaking in group chat.

- **Existing `/say` conversation** remains unchanged. If a player targets
  a companion and uses `/say`, the response comes back in `/say` as it does
  today. The two paths (group chat via `@name` and `/say` via targeting)
  are independent.

#### Response Staggering

When multiple companions receive conversational payloads (via `@all` or
multiple `@name` mentions), their LLM responses are staggered with 1–2
second delays between each response. This:

- Prevents a wall of text from appearing simultaneously in group chat
- Creates a natural conversational rhythm where companions "speak in turn"
- Allows the player to read each response before the next appears
- Mirrors how a real group of people would respond to a question — not
  all at the exact same instant

The stagger delay should feel natural, not mechanical. A random value
between 1.0 and 2.0 seconds per response is the target range. The order
of responses is not specified — whichever LLM response finishes first can
be delivered first, with subsequent responses delayed.

#### Target Preservation

The player's current target is never modified by this system. The entire
mechanism works through internal routing — the server intercepts the
`/gsay` message, parses it, and routes commands/conversations to the
appropriate companions without any target-switch packets being sent to
the client. From the client's perspective, the player simply typed in
group chat and things happened.

### Balance Considerations

This feature does not change companion power. It changes companion
**accessibility**. The same commands that work via `/say` targeting work
via `/gsay` addressing — no new capabilities are added.

However, the ease-of-use improvement has indirect balance implications:

- **Faster reaction time:** Players can issue companion orders instantly
  without target switching. In a tight combat situation, this could mean
  the difference between a companion heal landing in time or not.
  **This is intentional and desirable** for a 1–3 player server where
  companions fill essential roles.

- **Macro enablement:** Players can now create combat macros that
  coordinate multiple companions. This makes optimal companion usage
  easier to achieve consistently. **This is intentional** — our server
  is designed for small groups who need efficient companion control.

- **No new power ceiling:** A player who could already perfectly manage
  their companions via rapid targeting has no advantage from this feature.
  It raises the floor of companion usability, not the ceiling.

For a server designed around 1–3 players with recruited companions, making
companions easier to control is a core design goal, not a balance concern.

### Era Compliance

This feature introduces no era-specific content. It is a quality-of-life
communication mechanism that works within the existing EQ chat system.

- **`/gsay` is a Classic-era chat channel.** Group say has existed since
  EQ launch. Using it as the vehicle for companion addressing is era-
  appropriate.

- **`@` syntax is a server-side convention.** The client sends the raw
  text; the server interprets `@` patterns. The client is unaware of any
  special meaning, so no Titanium client constraints are violated.

- **No post-Luclin references.** The feature does not introduce any zones,
  NPCs, items, or lore from expansions beyond Luclin.

- **The `!command` system already exists.** This feature routes existing
  commands through a new channel, not introducing new functionality that
  would be era-inappropriate.

## Affected Systems

- [x] C++ server source (`eqemu/`)
  - Group chat message handling (`OP_ChannelMessage` / group say channel)
  - `@Name` parser and companion name resolver
  - Command dispatch routing (to existing `/say` command handler)
  - LLM sidecar conversation routing (group chat response channel)
  - Response stagger mechanism for multi-companion conversations

- [x] Lua quest scripts (`akk-stack/server/quests/`)
  - LLM bridge (`llm_bridge.lua`) may need updates to support group chat
    as a response channel
  - Global NPC handler (`global_npc.lua`) may need updates for the new
    routing path

- [ ] Perl quest scripts (maintenance only)

- [ ] Database tables (`peq`)

- [ ] Rule values

- [ ] Server configuration

- [ ] Infrastructure / Docker

## Dependencies

This feature depends on the following systems being in place:

1. **Companion recruitment system (Phase 4):** Companions must exist in the
   player's group for addressing to work. The feature is designed to work
   with any NPC that has been recruited as a companion and added to the
   player's group.

2. **Companion command system (`!commands`):** The `!command` payload type
   routes to the existing companion command handler. That handler must be
   functional for command routing to be useful.

3. **LLM sidecar (NPC-LLM):** The conversational payload type routes to the
   LLM sidecar. The sidecar must be running and functional for conversational
   responses to work. The sidecar currently supports `/say`-based
   conversation; this feature adds group chat as a response channel.

4. **LLM bridge (`llm_bridge.lua`):** The Lua bridge that connects the
   zone server to the LLM sidecar must support specifying the response
   channel (group chat vs. say).

## Open Questions

1. **Should non-player group members see @mentions in raw form?** When the
   player types `/gsay @iskarr !follow`, do other human players in the group
   see the raw `@iskarr !follow` text, or is it suppressed/reformatted?
   Recommendation: show it as-is — it's transparent and helps other players
   understand what commands are being issued.

2. **Should there be a feedback message when no @mentions match?** Currently
   designed as silent failure. An alternative is a client-only message like
   "No companions matched '@nobody'." This could help debugging but adds
   noise. To be decided during architecture.

3. **How should the response channel flag be passed to the LLM sidecar?**
   The sidecar currently returns a response that the Lua bridge delivers
   via `e.self:Say()`. For group chat responses, the delivery mechanism
   needs to change. The architect should determine whether this is a new
   field in the `ChatRequest`, a separate endpoint, or a different routing
   mechanism entirely.

4. **What is the interaction with existing group chat?** If a non-companion
   group member (another player) types `/gsay @iskarr hello`, should the
   companion respond to them too, or only to the companion's owner? For
   a 1–3 player server this is a real scenario.

5. **Prefix list extensibility.** The current prefix strip list (Guard,
   Captain, Lady, Lord, Sir, etc.) is hardcoded in the design. Should this
   be configurable via a rule value or config file? The architect should
   assess the trade-off.

## Acceptance Criteria

- [ ] Player types `/gsay @companionname !command` and the named companion
  executes the command without the player changing their target
- [ ] Player types `/gsay @all !command` and all recruited companions in
  the group execute the command
- [ ] Player types `/gsay @name1 and @name2 !command` and both named
  companions execute the command
- [ ] Companion name matching is case-insensitive and works with partial
  names (substring)
- [ ] Common NPC prefixes (Guard, Captain, Sir, Lieutenant, Keeper, etc.) are stripped before
  matching, so `@iskarr` matches "Guard Iskarr"
- [ ] Unmatched `@name` mentions are silently ignored; matched companions
  still receive their commands
- [ ] Player types `/gsay @companionname how are you?` and receives an
  LLM-generated response from that companion in group chat
- [ ] Player types `/gsay @all what do you think?` and each companion
  responds in group chat with responses staggered 1–2 seconds apart
- [ ] The player's current target is never changed by any `@name` interaction
- [ ] Regular `/gsay` messages without `@` mentions are unaffected —
  group chat works normally for messages that don't use addressing
- [ ] Regular `/say` targeting + companion conversation continues to work
  unchanged alongside the new `/gsay` addressing
- [ ] Companion LLM responses in group chat use the companion's name as
  the speaker
- [ ] The feature works with 1 companion, 2 companions, or a full group
  of companions (up to 5)
- [ ] EQ macros containing `/gsay @name !command` lines execute correctly

---

## Appendix: Technical Notes for Architect

These are advisory observations from the game designer. The architect makes
all implementation decisions.

- **OP_ChannelMessage handler:** The C++ handler for `OP_ChannelMessage`
  (`Handle_OP_ChannelMessage` in `zone/client_packet.cpp`) is where group
  say messages are processed. This is the natural interception point for
  detecting `@` mentions in group chat.

- **ChannelMessage_Struct:** Defined at line 1189 of
  `common/eq_packet_structs.h`. The `message` field is variable-length.
  The channel number for group say needs to be identified.

- **Existing LLM flow:** Currently: `/say` → `EVENT_SAY` → `global_npc.lua`
  → `llm_bridge.lua` → HTTP POST to sidecar → response via `e.self:Say()`.
  The new flow would be: `/gsay @name` → C++ parser → route to companion →
  trigger LLM flow with group chat as the response channel.

- **Response delivery for group chat:** The server-side mechanism for
  sending group chat messages as a specific NPC/companion should be
  investigated. The companion entity would need to "speak" in group chat.

- **Bot system as reference:** The bot system (`zone/bot.h/cpp`) already
  handles player-issued text commands to NPC party members. The command
  dispatch mechanism there may be informative for how companion commands
  are currently processed.

- **MAX_GROUP_MEMBERS = 6:** The Titanium client supports exactly 6 group
  members (self + 5 others). The `@all` broadcast needs to iterate over
  at most 5 companions.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
