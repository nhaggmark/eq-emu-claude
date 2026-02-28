# NPC Conversation System — Deep Dive

> How player-to-NPC chat works end-to-end in EQEmu, from UDP packet to quest script response.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Protocol Layer](#2-protocol-layer)
3. [Server-Side Routing](#3-server-side-routing)
4. [Quest Event Dispatch](#4-quest-event-dispatch)
5. [NPC Response Delivery](#5-npc-response-delivery)
6. [Say Links](#6-say-links)
7. [Dialogue Window System](#7-dialogue-window-system)
8. [Database-Driven Dialogue](#8-database-driven-dialogue)
9. [Quest Script Patterns](#9-quest-script-patterns)
10. [Task System Integration](#10-task-system-integration)
11. [Distance and Visibility Rules](#11-distance-and-visibility-rules)
12. [Extension Points for LLM Integration](#12-extension-points-for-llm-integration)

---

## 1. Architecture Overview

The NPC conversation system spans four layers of the EQEmu stack:

```
Titanium Client
    │ UDP: OP_ChannelMessage (ChannelMessage_Struct)
    ▼
zone/client_packet.cpp          Handle_OP_ChannelMessage()
    │
    ▼
zone/client.cpp                 ChannelMessageReceived() — routes by channel type
    │
    ├──→ entity.cpp             ChannelMessage() — broadcast to nearby players
    │
    ├──→ quest_parser_collection.cpp  EventBotMercNPC() → EventNPC()
    │    │
    │    ├──→ lua_parser.cpp    _EventNPC() → calls event_say(e) in Lua script
    │    └──→ embparser.cpp     EventCommon() → calls sub EVENT_SAY in Perl script
    │
    └──→ entity.cpp             ProcessProximitySay() — proximity-triggered NPCs
         │
         ▼
NPC Quest Script runs, calls:
    ├── e.self:Say("text")      Lua NPC response
    ├── quest::say("text")      Perl NPC response
    └── DialogueWindow::Render  Alternative window UI
         │
         ▼
zone/mob.cpp                    Mob::Say() — formats response
    │
    ▼
zone/entity.cpp                 MessageCloseString() — sends to nearby clients
    │
    ▼ UDP: ChannelMessage_Struct (response)
Titanium Client displays NPC speech in chat window
```

---

## 2. Protocol Layer

### Inbound Packet: Player Speaks

**Opcode:** `OP_ChannelMessage`
**Handler:** `Client::Handle_OP_ChannelMessage()` — `zone/client_packet.cpp:4558`

**Packet Structure** (`common/eq_packet_structs.h:1189`):

```cpp
struct ChannelMessage_Struct {
    /*000*/ char   targetname[64];      // Tell target or NPC name
    /*064*/ char   sender[64];          // Player's name
    /*128*/ uint32 language;            // Language ID (0=Common Tongue)
    /*132*/ uint32 chan_num;            // Channel number
    /*136*/ uint32 cm_unknown4[2];      // Reserved
    /*144*/ uint32 skill_in_language;   // Player's skill level in language
    /*148*/ char   message[0];          // Variable-length message text
};
```

**Channel Numbers** (`common/eq_constants.h:950-969`):

| Value | Channel | NPC Hears? |
|-------|---------|-----------|
| 0 | Guild | No |
| 2 | Group | No |
| 3 | Shout | No |
| 4 | Auction | No |
| 5 | OOC | No |
| 7 | Tell | No |
| **8** | **Say** | **Yes** |
| 15 | Raid | No |

Only **channel 8 (Say)** triggers NPC dialogue.

### Outbound Packet: NPC Responds

NPC responses use the same `ChannelMessage_Struct` but with:
- `sender` = NPC's name
- `chan_num` = `Chat::NPCQuestSay` (262)
- Uses `GENERIC_SAY` string ID for the `%s says, '%s'` format

The response is wrapped in `MessageCloseString()` which uses `OP_FormattedMessage` or direct channel message packets.

### Titanium Translation

The Titanium patch adapter (`common/patches/titanium.cpp`) does **not** have specific encode/decode methods for `OP_ChannelMessage` — the packet passes through unchanged between internal format and Titanium wire format.

---

## 3. Server-Side Routing

### Handler Entry Point

`Client::Handle_OP_ChannelMessage()` (`client_packet.cpp:4558-4585`):

1. Validates packet size
2. Strips AFK auto-messages
3. Blocks AI-controlled characters from speaking
4. Extracts language skill from player profile
5. Calls `ChannelMessageReceived(chan_num, language, lang_skill, message, targetname)`

### Channel Router

`Client::ChannelMessageReceived()` (`client.cpp:1202-1674`) is the master router. For `ChatChannel_Say` (channel 8), the flow is:

```
Say message received
│
├─ 1. Command check: starts with '#' or '!'?
│  └─ Yes → command_dispatch() → done
│
├─ 2. Bot command check: starts with '^'?
│  └─ Yes → bot_command_dispatch() → done
│
├─ 3. Profanity filter (if active)
│
├─ 4. Voice Graft check: pet speaks for charmed player?
│
├─ 5. Broadcast to nearby clients (200 unit radius)
│  └─ EntityList::ChannelMessage(sender, 8, language, skill, message)
│
├─ 6. Player EVENT_SAY dispatch (player quest scripts)
│  └─ parse->EventPlayer(EVENT_SAY, this, message, language)
│
├─ 7. Proximity Say check
│  └─ entity_list.ProcessProximitySay(message, this, language)
│
└─ 8. NPC interaction (THE KEY SECTION)
   │
   ├─ Conditions:
   │  ├─ Player has a target (GetTarget() != null)
   │  ├─ Player is visible to target (!IsInvisible(target))
   │  └─ Target within RuleI(Range, Say) distance (default 200)
   │     └─ Uses DistanceNoZ() — ignores Z axis for range check
   │
   ├─ If target is ENGAGED in combat:
   │  └─ EventBotMercNPC(EVENT_AGGRO_SAY, target, this, message, language)
   │
   └─ If target is NOT engaged:
      ├─ EventBotMercNPC(EVENT_SAY, target, this, message, language)
      ├─ CheckLDoNHail(npc) — LDoN adventure triggers
      ├─ CheckEmoteHail(npc, message) — DB-driven emote responses
      └─ UpdateTasksOnSpeakWith(npc) — task system credit
```

### Critical Detail: Single-Target Dispatch

NPC dialogue is dispatched to **only the player's current target**. If the player /says something but has no target, or targets a mob outside 200 units, no NPC quest event fires. This is fundamentally different from the broadcast (step 5) which goes to all nearby clients.

**Exception:** Proximity Say (`ProcessProximitySay`) fires for NPCs that have registered a proximity box, regardless of targeting.

---

## 4. Quest Event Dispatch

### Event Router: EventBotMercNPC

`QuestParserCollection::EventBotMercNPC()` (`quest_parser_collection.cpp:1846-1864`):

Checks target type and routes to the appropriate handler:
1. If target is a **Bot** with quest sub → `EventBot()`
2. If target is a **Merc** with quest sub → `EventMerc()`
3. If target is an **NPC** with quest sub → `EventNPC()`

### EventNPC Dispatch Chain

`QuestParserCollection::EventNPC()` (`quest_parser_collection.cpp:475-501`):

Tries three script sources in priority order:

| Priority | Source | Method | Script Location |
|----------|--------|--------|----------------|
| 1 | Local NPC script | `EventNPCLocal()` | `quests/<zone>/<NPC_Name>.lua` or `.pl` |
| 2 | Global NPC script | `EventNPCGlobal()` | `quests/global/global_npc.lua` or `.pl` |
| 3 | Default handlers | `DispatchEventNPC()` | C++ built-in logic |

First non-zero return value wins. If the local script handles the event, global and default are still called but their return values are subordinate.

### Script File Resolution

`GetQIByNPCQuest()` (`quest_parser_collection.cpp:~1050-1125`) searches in this order:

1. `quests/<zone>/v<version>/<npc_id>.lua` (versioned, by ID)
2. `quests/<zone>/v<version>/<NPC_Name>.lua` (versioned, by name)
3. `quests/<zone>/<npc_id>.lua` (by ID)
4. `quests/<zone>/<NPC_Name>.lua` (by name)
5. `quests/global/<npc_id>.lua` (global by ID)
6. `quests/global/<NPC_Name>.lua` (global by name)
7. `quests/<zone>/default.lua` (zone default)
8. `quests/global/default.lua` (global default)

At each step, `.lua` is checked before `.pl`.

### Data Passed to Scripts

**Lua** (`event_say(e)` — packaged in `lua_parser_events.cpp`):

| Field | Type | Content |
|-------|------|---------|
| `e.self` | Lua_NPC | The NPC being spoken to |
| `e.other` | Lua_Mob | The player who spoke |
| `e.message` | string | The player's say text |
| `e.language` | number | Language ID |

**Perl** (`sub EVENT_SAY` — exported in `embparser.cpp`):

| Variable | Content |
|----------|---------|
| `$text` | Player's say text |
| `$npc` | NPC object reference |
| `$client` | Client object reference |
| `$entity_list` | Zone entity list |
| `$name` | Player's character name |
| `$ulevel` | Player's level |
| `%qglobals` | Quest global variables hash |
| `$faction` | Player's faction with NPC |
| `$x`, `$y`, `$z`, `$h` | NPC position |

### Related Events

| Event | ID | Trigger |
|-------|-----|---------|
| `EVENT_SAY` | 0 | Player says to non-engaged NPC |
| `EVENT_AGGRO_SAY` | 28 | Player says to engaged NPC |
| `EVENT_PROXIMITY_SAY` | 32 | Player says within NPC's proximity box |
| Player `EVENT_SAY` | 64 | Player says anything (player script, not NPC) |

---

## 5. NPC Response Delivery

### Mob::Say()

`zone/mob.cpp:5003-5061` — called by quest scripts (`e.self:Say()` or `quest::say()`):

Three delivery modes controlled by server rules:

| Rule | Mode | Behavior |
|------|------|----------|
| (default) | Standard Chat | NPC text in chat window via `MessageCloseString()` |
| `Chat, AutoInjectSaylinksToSay` | Auto-Saylinks | `[bracketed text]` converted to clickable links |
| `Chat, QuestDialogueUsesDialogueWindow` | Dialogue Window | Rendered in special popup window |

### Standard Chat Delivery

```
Mob::Say(text)
  └─→ EntityList::MessageCloseString(sender, false, 200, Chat::NPCQuestSay, GENERIC_SAY, name, text)
      └─→ For each client within 200 units:
          └─→ client->MessageString(type, GENERIC_SAY, npc_name, text)
              └─→ Sends OP_FormattedMessage packet to client
```

The client renders: `<NPC Name> says, '<text>'` using the `GENERIC_SAY` string template.

### QuestManager::say()

`zone/questmgr.cpp` — the C++ backend behind both Lua's `e.self:Say()` and Perl's `quest::say()`:

```cpp
void QuestManager::say(const char *str, uint8 language) {
    // quest_manager.GetOwner() returns the NPC
    quest_manager.GetOwner()->Say(str);
}
```

Both Lua and Perl converge on the same `Mob::Say()` call.

---

## 6. Say Links

Say links are clickable text in NPC dialogue that auto-send a `/say` message when clicked.

### How They Work

1. Quest script outputs text with `[brackets]`: `"Would you like to hear about my [quest]?"`
2. Server processes brackets (if `AutoInjectSaylinksToSay` rule is on, or script uses explicit say_link API)
3. Creates/looks up entry in `saylink` database table
4. Injects special link encoding: `\x12<LinkBody><LinkText>\x12`
5. Client renders clickable colored text
6. Player clicks → client sends `/say <phrase>` as if typed

### Database Table

```sql
CREATE TABLE saylink (
    id    INT AUTO_INCREMENT PRIMARY KEY,
    phrase VARCHAR(64) NOT NULL,    -- case-sensitive (utf8_bin)
    KEY phrase_index (phrase)
);
```

Current server has only 4 saylink entries — most saylinks are generated dynamically at runtime.

### Say Link API

**Lua:**
```lua
local link = eq.say_link("quest text")          -- Generate clickable link
local link = eq.say_link("quest text", true)     -- Silent (no bracket display to others)
local link = eq.say_link("quest text", false, "display name")  -- Custom display text
```

**Perl:**
```perl
my $link = quest::saylink("quest text");
my $link = quest::saylink("quest text", 1);               # Silent
my $link = quest::saylink("quest text", 0, "display");     # Custom display
```

### Link Wire Format

`common/say_link.h:49-63` — SayLinkBody_Struct (hex-encoded, 56 characters):

```cpp
struct SayLinkBody_Struct {
    uint8  action_id;       // Link type identifier
    uint32 item_id;         // Item ID (0 for saylinks)
    uint32 augment_1-6;     // Augment slots (0 for saylinks)
    uint8  is_evolving;     // 0
    uint32 evolve_group;    // 0
    uint8  evolve_level;    // 0
    uint32 ornament_icon;   // 0
    uint32 hash;            // Verification hash
};
```

Saylinks reuse the item link format with zeroed item fields and a special action_id.

### Auto-Injection

When `RuleB(Chat, AutoInjectSaylinksToSay)` is TRUE:
- `SayLinkEngine::InjectSaylinksIfNotExist()` scans NPC text for `[bracketed phrases]`
- Each bracket pair is converted to a clickable saylink
- The phrase is stored in the `saylink` table for persistence

---

## 7. Dialogue Window System

### Overview

An alternative to chat-based dialogue, controlled by `RuleB(Chat, QuestDialogueUsesDialogueWindow)`.

**File:** `zone/dialogue_window.cpp`

When enabled, `Mob::Say()` sends text to a popup window instead of the chat log, but **only to clients targeting the speaking NPC**.

### Markup Language

The dialogue window supports rich formatting:

| Tag | Effect |
|-----|--------|
| `{y}`, `{r}`, `{g}`, `{gold}`, `{orange}`, `{gray}`, `{tan}` | Text colors |
| `{linebreak}` or `{lb}` | Line break |
| `{bullet}` | Bullet point |
| `{in}` | Indent |
| `{table}`, `{row}`, `{cell}` | HTML table |
| `+animation_name+` | Play NPC animation |
| `{mysterious}` | Hide NPC name |
| `noquotes` | Remove quotation marks |
| `nobracket` | Remove bracket display on links |
| `hiddenresponse` | Hide response options |

### Rendering

```cpp
// Only sends to the client targeting this NPC
if (client->GetTarget() && client->GetTarget()->CastToMob() == talker) {
    DialogueWindow::Render(client, window_markdown);
}
```

---

## 8. Database-Driven Dialogue

### NPC Emotes (No Script Required)

The `npc_emotes` table provides scripted-free NPC reactions:

```sql
CREATE TABLE npc_emotes (
    id       INT AUTO_INCREMENT PRIMARY KEY,
    emoteid  INT UNSIGNED DEFAULT 0,    -- Links to npc_types.emoteid
    event_   TINYINT DEFAULT 0,         -- Trigger event
    type     TINYINT DEFAULT 0,         -- Delivery method
    text     VARCHAR(512) NOT NULL      -- Message text
);
```

**Event triggers (`event_`):**

| Value | Trigger | Usage |
|-------|---------|-------|
| 0 | Post-slay idle | 20 entries |
| 1 | Combat aggro | 1,325 entries |
| 2 | NPC death (alternate) | 127 entries |
| 3 | NPC death speech | 1,031 entries |
| 4 | NPC attacked | 57 entries |
| 5 | NPC slays player | 38 entries |
| 6 | NPC slays NPC | 20 entries |
| 7 | Proximity/waypoint | 29 entries |
| 8 | Idle timer | 4 entries |

**Delivery type (`type`):**

| Value | Method | Usage |
|-------|--------|-------|
| 0 | Say | 1,259 entries |
| 1 | Emote | 1,250 entries |
| 2 | Shout | 32 entries |
| 3 | Narrative/boss emote | 111 entries |

**Coverage:** 10,829 of 67,530 NPCs (16%) have emotes assigned.

**Check:** `CheckEmoteHail()` is called in the Say handler specifically for hail-type emotes.

### Quest Globals (Legacy State)

```sql
CREATE TABLE quest_globals (
    charid  INT DEFAULT 0,       -- 0 = all characters
    npcid   INT DEFAULT 0,       -- 0 = all NPCs
    zoneid  INT DEFAULT 0,       -- 0 = all zones
    name    VARCHAR(65) NOT NULL,
    value   VARCHAR(128) NOT NULL,
    expdate INT DEFAULT NULL,    -- Unix timestamp expiry
    PRIMARY KEY (charid, npcid, zoneid, name)
);
```

Three-dimensional scoping: character + NPC + zone. Used by quest scripts to track conversation progress (e.g., "has player heard the opening speech?").

### Data Buckets (Modern State)

```sql
CREATE TABLE data_buckets (
    id           BIGINT AUTO_INCREMENT PRIMARY KEY,
    `key`        VARCHAR(100),
    value        TEXT,
    expires      INT UNSIGNED DEFAULT 0,
    account_id   BIGINT UNSIGNED DEFAULT 0,
    character_id BIGINT UNSIGNED DEFAULT 0,
    npc_id       INT UNSIGNED DEFAULT 0,
    bot_id       INT UNSIGNED DEFAULT 0,
    zone_id      SMALLINT UNSIGNED DEFAULT 0,
    instance_id  SMALLINT UNSIGNED DEFAULT 0,
    UNIQUE KEY (key, character_id, npc_id, bot_id, account_id, zone_id, instance_id)
);
```

Richer scoping than quest_globals. Recommended for new development. Supports expiration timestamps for time-gated dialogue.

---

## 9. Quest Script Patterns

### Pattern: Simple Hail/Keyword (Lua)

```lua
function event_say(e)
    if (e.message:findi("hail")) then
        e.self:Say("Greetings, " .. e.other:GetName() .. "! Care to hear about my [quest]?")
    elseif (e.message:findi("quest")) then
        e.self:Say("Bring me 4 [gnoll fangs] and I shall reward you.")
    elseif (e.message:findi("gnoll fangs")) then
        e.self:Say("You can find gnolls in Blackburrow to the north.")
    end
end
```

### Pattern: State-Tracking Dialogue (Lua)

```lua
function event_say(e)
    local progress = eq.get_data("quest_progress-" .. e.other:CharacterID())
    if (e.message:findi("hail")) then
        if (progress == "started") then
            e.self:Say("Have you completed the [task] I gave you?")
        else
            e.self:Say("Hello traveler. I need [help] with something.")
        end
    elseif (e.message:findi("help")) then
        eq.set_data("quest_progress-" .. e.other:CharacterID(), "started")
        e.self:Say("Please slay 5 rats in the sewers.")
    end
end
```

### Pattern: Default NPC Behavior (Perl)

`plugins/default.pl` → `plugins/default-actions.pl`:

```perl
sub defaultSay {
    my $mname = plugin::val('$mname');
    if ($mname =~ /^Soulbinder/) {
        # Soulbinder dialogue
    } elsif ($mname =~ /^Guard/) {
        # Guard dialogue based on faction
    } elsif ($mname =~ /^Merchant/ || $mname =~ /^Innkeep/) {
        # Merchant greeting
    }
}
```

### Pattern: Coroutine Threading (Lua Encounter System)

```lua
local ThreadManager = require("thread_manager")

function SunsaConversation()
    trumpy:Say("Time to drain the dragon..")
    ThreadManager:Wait(0.65)  -- pause 650ms
    local sunsa = eq.get_entity_list():GetMobByNpcTypeID(1074)
    if (sunsa.valid) then
        sunsa:Say("Trumpy, you are one sick little man!")
    end
end
```

Uses Lua coroutines via `thread_manager.lua` for natural conversation pacing. Timer-based pauses between NPC lines.

---

## 10. Task System Integration

The task system has a "speak with" activity type that integrates with NPC dialogue.

**Activity type 4 = Speak With NPC** — 220 activities across 143 tasks.

When a player hails/says to an NPC whose type ID matches `task_activities.npc_match_list`, the task activity is automatically credited via `UpdateTasksOnSpeakWith()`.

```sql
-- Example task activities requiring NPC speech
SELECT ta.taskid, t.title, ta.description_override, ta.npc_match_list
FROM task_activities ta
JOIN tasks t ON ta.taskid = t.id
WHERE ta.activitytype = 4
LIMIT 5;
```

---

## 11. Distance and Visibility Rules

| Check | Location | Distance | Notes |
|-------|----------|----------|-------|
| Chat broadcast to players | `entity.cpp:1326` | 200 units | Euclidean 3D distance |
| NPC event dispatch | `client.cpp:1622` | `RuleI(Range, Say)` (default 200) | `DistanceNoZ()` — ignores Z axis |
| NPC response delivery | `mob.cpp:5026` | 200 units | Hard-coded |
| Proximity say trigger | `entity.cpp:4154` | Variable (per-NPC box) | Axis-aligned bounding box |
| Dialogue window | `mob.cpp:5032` | 200 units (closemob list) | Also requires target match |

**Visibility:** Player must not be invisible to the NPC (`!IsInvisible(target)`) for the NPC event to fire.

**Target requirement:** Player must have the NPC targeted (except for proximity say which is untargeted).

---

## 12. Extension Points for LLM Integration

### Where to Hook

The architecture provides several natural integration points:

| Hook Point | Layer | Invasiveness | Description |
|------------|-------|--------------|-------------|
| **Lua `event_say` handler** | Quest script | None (pure script) | Intercept at script level, call external service |
| **Lua Mod system** | Engine hook | None (Lua mod) | Register a mod that intercepts say events |
| **`global_npc.lua`** | Global script | None (script) | Add LLM fallback for all NPCs without scripts |
| **`default.lua`** | Default script | None (script) | Replace default NPC behavior with LLM |
| **`QuestManager::say()`** | C++ | Moderate | Modify response pipeline to post-process text |
| **`Mob::Say()`** | C++ | Moderate | Intercept before delivery to add LLM context |
| **`EventNPC()`** | C++ | High | Add pre/post hooks around quest dispatch |
| **New ServerOP code** | C++ | High | Async LLM call via zone→external service |

### Recommended Hook: Lua Global Script + Module

The lowest-risk approach uses `quests/global/global_npc.lua` + a custom Lua module:

1. `event_say` fires in the NPC's local script (existing quest logic runs first)
2. If no local script exists, `global_npc.lua` catches the event
3. Global script calls a Lua module that makes HTTP request to local LLM service
4. LLM service (Mistral 7B) generates response using NPC context from Pinecone
5. Response is sent via `e.self:Say()` — uses existing delivery pipeline

This approach:
- Preserves all existing quest scripts untouched
- Uses existing event dispatch (no C++ changes)
- Falls through gracefully (LLM only handles NPCs without scripts)
- Can be toggled via rules or data buckets

### Data Available at Hook Point

At the moment `event_say(e)` fires, the following data is accessible:

| Data | Access | Use for LLM |
|------|--------|-------------|
| Player message | `e.message` | LLM prompt input |
| NPC name | `e.self:GetCleanName()` | Character identity |
| NPC race/class | `e.self:GetRace()`, `e.self:GetClass()` | Persona context |
| NPC level | `e.self:GetLevel()` | Power context |
| Player name | `e.other:GetName()` | Personalization |
| Player faction | `e.other:GetFactionLevel(npc)` | Relationship context |
| Zone | `eq.get_zone_short_name()` | Location context |
| NPC position | `e.self:GetX/Y/Z()` | Spatial context |
| Quest globals | `eq.get_qglobals()` | Conversation history |
| Data buckets | `eq.get_data(key)` | Persistent memory |
