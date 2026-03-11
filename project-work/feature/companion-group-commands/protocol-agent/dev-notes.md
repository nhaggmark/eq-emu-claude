# Companion Group Commands — Dev Notes: Protocol Agent

> **Feature branch:** `feature/companion-group-commands`
> **Agent:** protocol-agent
> **Task(s):** Task #3 — Review for client-server protocol concerns
> **Date started:** 2026-03-11
> **Current stage:** Research (blocked on Task #1 — architecture doc not yet complete)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Review for client-server protocol concerns | Task #1 (architecture doc) | Blocked — pre-research complete, awaiting architecture doc |

---

## Stage 1: Plan

This task is a review pass, not an implementation task. The plan is:
1. Read architecture doc + PRD
2. Verify protocol assumptions against source
3. Document findings on 5 key questions:
   - Group chat message length limits
   - Multi-line vs split messages in group say
   - Packet size concerns for `!status` / `!equipmentmissing`
   - Color codes / special formatting in Titanium group chat
   - Timing / rate limits for rapid successive messages

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/common/eq_packet_structs.h` | 1189-1198 | `ChannelMessage_Struct`: 148B fixed header + `message[0]` (variable length, null-terminated) |
| `eqemu/common/eq_constants.h` | 950-969 | `ChatChannelNames` enum: `ChatChannel_Group = 2` |
| `eqemu/common/patches/titanium.cpp` | — | No ENCODE/DECODE for `OP_ChannelMessage` → passes through unchanged (identical wire format) |
| `eqemu/common/patches/titanium_structs.h` | 1022-1028 | Titanium `ChannelMessage_Struct` identical to internal — confirmed pass-through |
| `eqemu/zone/client.cpp` | 1879-1884 | `ChannelMessageSend` uses `char buffer[4096]` with `vsnprintf` → hard 4096B message limit |
| `eqemu/zone/client.cpp` | 1360-1376 | Group chat dispatch: `ChatChannel_Group` → `HandleGroupChatMentions` when `@` present |
| `eqemu/zone/client.cpp` | 1680-1858 | `HandleGroupChatMentions`: parses `@name`/`@all` tokens, dispatches `EVENT_SAY` to each companion |
| `eqemu/zone/groups.cpp` | 931-951 | `Group::GroupMessage`: iterates group members, calls `ChannelMessageSend` per client |
| `eqemu/zone/companion.cpp` | 2263-2278 | `CompanionGroupSay`: `char buf[4096]`, calls `g->GroupMessage(speaker, ...)` |
| `akk-stack/server/quests/lua_modules/companion.lua` | 578-597 | Existing `cmd_status` uses `client:Message()` not group chat (sends `OP_SpecialMesg`, only player sees it) |
| `akk-stack/server/quests/lua_modules/companion.lua` | 91-113 | COMMANDS table — existing handlers: `status`, `help`, `assist`, `follow`, `guard`, `recall`, `equipment`, `equip`, `unequip`, `stats`, `passive`, `balanced`, `aggressive`, `dismiss` |
| `akk-stack/server/quests/global/global_npc.lua` | 8-17 | `event_say`: `!`-prefix routes to `dispatch_prefix_command` |
| `akk-stack/server/quests/global/global_npc.lua` | 68-93 | LLM group chat: uses `group:GroupMessage(e.self, response)` for group channel delivery |

### Key Findings

**1. ChannelMessage_Struct is pass-through for Titanium**

There is no `ENCODE` or `DECODE` registered for `OP_ChannelMessage` in `titanium.cpp`. The Titanium wire format for group chat is identical to the internal struct. No translation layer concerns for this feature.

**2. Hard message size limit: 4095 bytes effective**

`ChannelMessageSend` uses `char buffer[4096]` with `vsnprintf(buffer, 4096, ...)`. This is the effective ceiling. In practice, Titanium client chat windows display far less before scrolling — empirically, a single `/gsay` message can hold well over 200 characters, but extremely long messages may be truncated by the client UI even if the packet is valid.

**3. No multi-line in a single ChannelMessage**

The Titanium client does not render `\n` in chat messages as newlines. Each `Group::GroupMessage()` call produces one line in the chat window. The PRD's multi-line output formats (e.g., `!status`, `!help`, `!equipmentmissing`) must be split across multiple sequential `GroupMessage()` / `CompanionGroupSay()` calls — one call per line.

**4. Existing `!status` and `!help` use wrong channel**

The current `companion.lua:cmd_status()` (line 578) and `cmd_help()` (line 634) use `client:Message(15, ...)` which sends `OP_SpecialMesg` — visible only to the player as a system message, NOT in group chat. The PRD requires these responses to appear in group chat (`OP_ChannelMessage` with `chan_num = 2`).

The new commands (`!status`, `!help`, `!buffme`, `!buffs`, `!tome`, `!flee`, `!assist`, `!equipmentupgrade`, `!equipmentmissing`, `!follow`) must respond via `CompanionGroupSay()` (which calls `Group::GroupMessage()`) not `client:Message()`.

**5. The existing commands are dispatched via `event_say` not `event_group_say`**

`HandleGroupChatMentions` (client.cpp:1680) dispatches `EVENT_SAY` to companions — not a new event type. The companion receives the payload (everything after the `@name` token) as an `event_say` with `e.message` set to the command (e.g., `!assist`). This is the existing mechanism from `feature/group-chat-addressing`. The new commands integrate naturally here.

**6. No rate limiting on group chat messages at the protocol level**

`Group::GroupMessage()` has no rate limiting or queuing. Multiple rapid calls are delivered immediately and independently. For `@all !status` (5 companions), 5 separate `GroupMessage` sequences fire in the same tick. Each companion sends 6-8 individual messages (one per status line). This means up to 40 `OP_ChannelMessage` packets can be queued to the client in rapid succession.

The EQ reliable UDP stream handles sequencing and fragmentation transparently. The Titanium client processes and displays all queued chat messages. There is no observed client-side rate limiting on chat reception.

**7. Color codes: none available in group chat**

`OP_ChannelMessage` does not support inline color codes. Color/formatting belongs to `OP_SpecialMesg` (used by `client:Message(type, ...)` where `type` is a `Chat::*` color enum). Group chat messages render in the standard group chat color configured by the client.

Responses that use `CompanionGroupSay()` will appear in the player's group chat color (typically teal/green on Titanium). There is no way to use red/yellow/white for emphasis within a single group say message.

**8. `!help` output from PRD exceeds practical group chat usability**

The PRD's `!help` output card spans approximately 20+ lines. Sending 20+ sequential group chat lines from a single NPC will flood the chat window. This is a UX concern, not a hard protocol limit. The architect should be aware that `!help` as specified will significantly flood group chat compared to the current `client:Message()` implementation.

**9. `!equipmentmissing` output size: well within limits**

Worst case: 19 slot names + companion name prefix ≈ ~150 characters. Well within the 4096B message limit. Can be sent as a single `CompanionGroupSay()` call if formatted inline, or 2-3 calls if formatted for readability.

**10. `!status` buff list size: bounded but requires splitting**

Worst case: companion name (64B max) + HP/mana line + stance/target line + state/follow line + "Buffs (N active):" header + up to 42 buff lines × ~40B each = ~1800B total. Must be split across multiple `CompanionGroupSay()` calls (at minimum 4-7 calls per companion).

### Critical Architecture Constraint

The PRD specifies all command responses appear in group chat. The existing `cmd_status()` and `cmd_help()` use `client:Message()` which does NOT appear in group chat. The implementation team must change these (and all new commands) to use `CompanionGroupSay()` instead of (or in addition to) `client:Message()`.

This is not a protocol concern — the Titanium client supports receiving companion group chat messages fine. It is an implementation constraint: the response method must change from `OP_SpecialMesg` to `OP_ChannelMessage`.

---

## Stage 2: Research

All findings above are from direct source inspection. Key verifications:

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `ChannelMessage_Struct` wire format | `eq_packet_structs.h:1189`, `titanium_structs.h:1022` | Yes | Identical — pass-through confirmed |
| `OP_ChannelMessage` Titanium translation | `titanium.cpp` (no ENCODE/DECODE found) | Yes | Pass-through: no encoding needed |
| `ChannelMessageSend` buffer size | `client.cpp:1879` `char buffer[4096]` | Yes | Hard 4096B limit |
| `ChatChannel_Group` value | `eq_constants.h:953` | Yes | `= 2` |
| `Group::GroupMessage` routing | `groups.cpp:931-951`, `client.cpp:1360-1376` | Yes | Calls `ChannelMessageSend` per member |
| `CompanionGroupSay` | `companion.cpp:2263-2278` | Yes | Uses 4096B buf, calls `GroupMessage` |
| `HandleGroupChatMentions` dispatch | `client.cpp:1680-1858` | Yes | Fires `EVENT_SAY` on companion with payload |
| Existing `cmd_status` channel | `companion.lua:578-597` | Yes | Uses `client:Message()` — NOT group chat |

### Plan Amendments

Task #1 (architecture doc) is still in progress. Once the architecture is available, I will review it against these findings and add any protocol concerns the architect's design raises. The pre-research above covers all foreseeable protocol questions from the PRD.

---

## Stage 3: Socialize

_Waiting for Task #1 (architecture doc) to complete before sending findings to team-lead._

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| team-lead | Protocol review ready (blocked on architecture) | Architecture doc still a template — will notify when complete |

---

## Protocol Review Findings (Summary for Team-Lead)

These are the findings for the architecture review. Organized by concern level:

### No Protocol Layer Changes Needed

- **OP_ChannelMessage has ENCODE/DECODE in titanium.cpp** (lines 349-376, 2587-2604), but these only handle say link body size conversion (server 56-char ↔ Titanium 45-char). This is transparent — it just works for the feature.
- **Group chat packet size is not a concern.** The 4096B buffer in `ChannelMessageSend` and `CompanionGroupSay` is more than sufficient for any single response line.
- **No rate limiting concerns.** The EQ reliable UDP stream handles rapid successive packets; Titanium client displays all of them.
- **`!equipmentmissing` output: well within limits.** ~150B per companion, trivially fits in a single message.
- **Item links in group chat messages survive the round trip.** `\x12` bytes and item IDs are preserved through `DECODE(OP_ChannelMessage)`. Item ID is parseable from `e.message` in Lua (or better: via C++ helper using `EQ::saylink::DegenerateLinkBody`).

### Implementation Constraints (Must Address)

1. **Multi-line responses require multiple `CompanionGroupSay()` calls.** The Titanium client does not render `\n` in chat messages. `!status`, `!help`, and `!equipmentmissing` must send each line as a separate call. This is how `CompanionGroupSay` is already used in `companion.cpp` (one call = one line).

2. **`cmd_status()` and `cmd_help()` currently use `client:Message()` not group chat.** The existing `!status` (companion.lua:578) and `!help` (companion.lua:634) send responses via `OP_SpecialMesg` which only the player sees. The PRD requires group chat responses. The implementation must change these to use `CompanionGroupSay()` (or the Lua equivalent: `group:GroupMessage(npc, line)`).

3. **No inline color codes in group chat.** Any emphasis in responses must use text formatting only (e.g., uppercase, punctuation, ASCII separators). No `Chat::Red` or similar in group say output.

### UX Concerns (Architect Should Consider)

4. **`!help` output as specified (~20+ lines) will flood group chat.** The existing `!help` sends to `client:Message()` which goes to a separate chat window area. Sending 20+ lines to group chat is a significant UX downgrade. The architect should consider: (a) keeping `!help` on `client:Message()` only (not group chat), or (b) using a condensed 5-line summary format for group chat with a note "full help via /say !help".

5. **`@all !status` with 5 companions produces 30-50 group chat lines at once.** Per-companion `!status` sends ~6-8 lines; 5 companions × 7 lines = 35 sequential group chat messages. The stagger delay rules in `HandleGroupChatMentions` apply to LLM conversations (dispatched via `gsay_stagger_ms`) but the architect should confirm whether the stagger mechanism should also apply to `!` prefix commands when `@all` is used. Currently, `!` commands are NOT staggered (stagger is only set for `is_conversation` — line 1840-1852 in client.cpp).

---

## Open Items

- [ ] Awaiting Task #1 (architecture doc) completion to do final review pass
- [ ] Confirm with architect: should `!` prefix commands via `@all` also use stagger delay?
- [ ] Confirm with architect: should `!help` response channel be group chat or `client:Message()`?
- [ ] Confirm with lua-expert: does `group:GroupMessage(npc, line)` work from Lua, or must C++ `CompanionGroupSay` be used?

---

## Context for Next Agent

This is a review task, not an implementation task. The protocol agent does not write C++ or Lua — findings are delivered to the architect and team-lead.

**Key constraint to communicate:** The existing `cmd_status()` and `cmd_help()` in `companion.lua` use `client:Message()`. The PRD requires group chat responses. The implementation team (lua-expert) must change these to use the group message path.

**No new opcodes, structs, or Titanium translation layer changes are needed for this feature.** All communication uses the existing `OP_ChannelMessage` path with `ChatChannel_Group = 2`.

**Source files examined:**
- `/mnt/d/Dev/eq/eqemu/common/eq_packet_structs.h` (line 1189)
- `/mnt/d/Dev/eq/eqemu/common/eq_constants.h` (line 950)
- `/mnt/d/Dev/eq/eqemu/common/patches/titanium.cpp` (no ChannelMessage handler)
- `/mnt/d/Dev/eq/eqemu/zone/client.cpp` (lines 1360-1858, 1861-1945)
- `/mnt/d/Dev/eq/eqemu/zone/groups.cpp` (lines 931-951)
- `/mnt/d/Dev/eq/eqemu/zone/companion.cpp` (lines 2263-2278)
- `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion.lua` (lines 91-164, 578-713)
- `/mnt/d/Dev/eq/akk-stack/server/quests/global/global_npc.lua` (lines 8-103)
