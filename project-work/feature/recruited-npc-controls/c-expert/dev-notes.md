# Recruited NPC Controls — Dev Notes: C Expert

> **Feature branch:** `feature/recruited-npc-controls`
> **Agent:** c-expert
> **Task(s):** #3 — Audit companion commands and GM command prefixes for collision
> **Date started:** 2026-02-28
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Audit companion commands and GM command prefixes for collision | — | Complete |

---

## Stage 1: Plan

This is a research-only task (audit and recommendation). No code changes.

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/zone/command.h` | 10 | `#define COMMAND_CHAR '#'` — GM command prefix |
| `eqemu/zone/bot_command.h` | 1027 | `#define BOT_COMMAND_CHAR '^'` — Bot command prefix |
| `eqemu/zone/client.cpp` | 1202–1634 | `ChannelMessageReceived()` — full message routing logic |
| `eqemu/zone/client_packet.cpp` | 320, 11128–11430 | `Handle_OP_PetCommands` — pet commands use dedicated packet, NOT chat prefix |
| `akk-stack/server/quests/lua_modules/companion.lua` | 1–533 | All companion keyword lists confirmed |
| `akk-stack/server/quests/global/global_npc.lua` | 1–55 | Event interception order |
| `akk-stack/server/quests/qeynos2/Davloran_Girionlis.lua` | 5 | "recruit" keyword collision example |

---

## Audit Results

### 1. Confirmed Prefix Characters in Use

| Prefix | System | Defined In | Dispatch Function | Notes |
|--------|--------|-----------|-------------------|-------|
| `#` | GM commands | `zone/command.h:10` `COMMAND_CHAR` | `command_dispatch()` | All player account levels; restricted by `AccountStatus` |
| `^` | Bot commands | `zone/bot_command.h:1027` `BOT_COMMAND_CHAR` | `bot_command_dispatch()` | Only when `RuleB(Bots, Enabled)` is true |

**No other prefix characters are intercepted by `ChannelMessageReceived()`.**

### 2. Message Routing Order in `client.cpp:ChannelMessageReceived()`

The function handles both `AlwaysCaptureCommandText` mode and the main `ChatChannel_Say` path. Both paths follow the same sequence:

```
1. message[0] == '#'  → command_dispatch() → RETURN/BREAK  (GM commands)
2. message[0] == '^'  → bot_command_dispatch() → RETURN/BREAK  (Bot commands)
3. everything else    → entity_list.ChannelMessage() + EventPlayer(EVENT_SAY)
                       + EventBotMercNPC(EVENT_SAY or EVENT_AGGRO_SAY, target)
```

Step 3 is what fires `global_npc.lua:event_say()`, which houses all companion keyword detection.

### 3. Pet Commands

Pet commands (`sit`, `attack`, `guard`, `follow`, `back off`, etc.) arrive via **`OP_PetCommands`** — a dedicated EQ protocol opcode handled by `Handle_OP_PetCommands()` in `client_packet.cpp`. They are **NOT** chat text and have **zero** collision risk with any chat-based system.

### 4. Companion Command Verification vs. companion-commands-reference.md

The reference doc at `claude/docs/companion-commands-reference.md` was verified against `companion.lua`.

**RECRUIT_KEYWORDS (companion.lua lines 28–31):**
- `recruit`, `join me`, `come with me`, `travel with me`, `adventure with me`,
  `will you join`, `join my party`, `join my group`, `come along`, `follow me`

**MANAGE_KEYWORDS (companion.lua lines 34–40):**
- `dismiss`, `leave`, `goodbye`, `farewell`, `release`
- `passive`, `balanced`, `aggressive`, `stance`
- `follow`, `guard`, `stay`
- `show equipment`, `show gear`, `inventory`
- `give me your`, `give me everything`

**Verdict: The reference doc is accurate.** All keywords in the doc match the actual Lua code. No discrepancies found.

### 5. Collision Analysis — Keyword-Based System Risks

The current companion system uses substring keyword matching in `global_npc.lua`. This creates two categories of collision risk:

#### 5a. NPC-script priority — no false triggers for scripted NPCs
`global_npc.lua` fires ONLY when no per-NPC or per-zone script handles the event first. This means:
- An NPC with a dedicated `.lua` or `.pl` script does NOT trigger companion logic
- Conversely, recruiting that NPC via say also doesn't work (the per-NPC script handles it instead)

#### 5b. Known keyword collision: "recruit" in Davloran_Girionlis.lua
`akk-stack/server/quests/qeynos2/Davloran_Girionlis.lua:5` handles the word "recruit" as a quest keyword. Since this NPC has a per-NPC script, the companion system is silently bypassed — players cannot recruit Davloran. This is not a bug per se (it's expected behavior from the script priority system) but it does mean some NPCs will not respond to recruitment keywords.

#### 5c. Common word collision risk for management keywords
Keywords like `follow`, `guard`, `stay`, `leave`, `farewell`, `goodbye`, and `passive` are ordinary English words that could appear in normal conversation with NPCs. Since companion management keywords are only matched when `npc:IsCompanion()` returns true (line 11 of global_npc.lua), false triggers against non-companion NPCs are prevented by the IsCompanion() guard.

For companion NPCs, the concern is inverted: any say to a companion is intercepted if it contains a management keyword. A player could accidentally trigger `follow` or `guard` while roleplaying dialogue.

### 6. Is a New Prefix Character Needed?

**The current design does not use a prefix at all.** Commands are keyword-based natural language sent via `/say`. The question is whether to switch to a prefix-based model.

**Arguments for keeping keyword/say-based model:**
- Natural language fits the "recruit any NPC" immersive theme
- No new C++ dispatch code required — entirely in Lua
- Matches existing companion.lua design intent

**Arguments for a prefix-based model:**
- More precise — no accidental triggers from NPC conversation
- More discoverable — players can type `?help` or `!help` and see a list
- Reduces reliance on IsCompanion() guard logic
- Easier to extend (add new commands without collision risk)

### 7. Safe Prefix Characters Available

If the design team decides to add a prefix, here are the available characters assessed against client compatibility and existing C++ dispatch:

| Character | Safe? | Notes |
|-----------|-------|-------|
| `#` | NO | Reserved for GM commands (`COMMAND_CHAR`) |
| `^` | NO | Reserved for bot commands (`BOT_COMMAND_CHAR`) |
| `!` | YES | Not intercepted by any C++ dispatch; not used in existing quest scripts |
| `?` | YES | Not intercepted; intuitive for "help" queries |
| `~` | YES | Not intercepted; visually distinct |
| `@` | YES | Not intercepted; risk of confusion with "at player" UX convention |
| `%` | YES | Not intercepted; non-intuitive |
| `$` | YES | Not intercepted; non-intuitive |
| `&` | YES | Not intercepted |
| `*` | YES | Not intercepted; used in text for bold/emphasis — mild ambiguity |
| `+` | YES | Not intercepted |
| `-` | YES | Not intercepted; risk of confusion with negative numbers |
| `.` | CAUTION | Not intercepted in C++, but `.` begins some NPC dialogue links |

**Recommendation: `!` (exclamation mark)**

Rationale:
- Not reserved by any existing C++ system
- Conventionally understood in games as a command prefix
- Visually distinct from `#` (GM) and `^` (bot)
- Easy to type for players (Shift+1, no awkward reach)
- Not used in any existing quest keyword patterns
- Works naturally: `!follow`, `!guard`, `!dismiss`, `!passive`

If a prefix model is adopted, the implementation would be entirely in `global_npc.lua` and `companion.lua` — no C++ changes required. The prefix would be stripped before dispatching to `handle_command()`.

---

## Stage 2: Research

This task was research-only. All findings are from direct source code reading.

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `COMMAND_CHAR` define | `eqemu/zone/command.h:10` | Yes | `'#'` hardcoded |
| `BOT_COMMAND_CHAR` define | `eqemu/zone/bot_command.h:1027` | Yes | `'^'` hardcoded |
| `ChannelMessageReceived()` routing | `eqemu/zone/client.cpp:1202–1634` | Yes | Two dispatch paths, both check `#` then `^` then pass through |
| `Handle_OP_PetCommands` | `eqemu/zone/client_packet.cpp:11128` | Yes | Packet-based, not chat prefix |
| `global_npc.lua:event_say` dispatch order | `akk-stack/server/quests/global/global_npc.lua:9–19` | Yes | Companion check before LLM check |

### Plan Amendments

Plan confirmed — no amendments needed. Audit is complete as scoped.

---

## Conclusion and Recommendation

**Prefix audit summary:**
- `#` is taken by GM commands
- `^` is taken by bot commands
- No other characters are intercepted by C++ dispatch
- Pet commands use a dedicated packet, no chat prefix

**Companion command reference doc status:** Accurate, all keywords verified.

**Recommended prefix:** `!` — if the design team chooses to move from keyword-based to prefix-based companion commands. This character is unused by any C++ system and is ergonomic for players.

**If keyword-based model is retained:** No prefix character is needed. The current system works as designed, with the expected trade-off that per-NPC scripted NPCs are not recruitable via say keywords.
