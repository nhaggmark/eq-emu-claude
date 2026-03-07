# Group Chat Companion Addressing — Dev Notes: Protocol Agent

> **Feature branch:** `feature/group-chat-addressing`
> **Agent:** protocol-agent
> **Task(s):** Task #2 — Research /gsay protocol and packet handling
> **Date started:** 2026-03-07
> **Current stage:** Complete (research task)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Research /gsay protocol and packet handling | — | Complete |

---

## Stage 1 + 2: Research Findings

These are verified findings from reading the source. All file paths and line
numbers are exact.

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `common/eq_packet_structs.h` | 1189–1198 | `ChannelMessage_Struct` wire format |
| `common/eq_constants.h` | 950–969 | `ChatChannelNames` enum — `ChatChannel_Group = 2` |
| `common/patches/titanium_ops.h` | 28, 100 | OP_ChannelMessage has both ENCODE and DECODE |
| `common/patches/titanium.cpp` | 349–376 | ENCODE: only converts saylinks, direct memcpy otherwise |
| `common/patches/titanium.cpp` | 2587–2604 | DECODE: only converts saylinks, direct memcpy otherwise |
| `zone/client_packet.cpp` | 4566–4593 | `Handle_OP_ChannelMessage` handler |
| `zone/client.cpp` | 1202–1644 | `ChannelMessageReceived` — main dispatch switch |
| `zone/client.cpp` | 1360–1371 | `ChatChannel_Group` case: calls `Group::GroupMessage()` |
| `zone/client.cpp` | 1617–1643 | `ChatChannel_Say` case: calls `EventBotMercNPC(EVENT_SAY, t, ...)` |
| `zone/groups.cpp` | 905–925 | `Group::GroupMessage()` — iterates members, calls `ChannelMessageSend` |
| `zone/entity.cpp` | 4676–4689 | `EntityList::GroupMessage()` — alternate group broadcast |
| `zone/client.h` | 449 | `ChannelMessageSend(from, to, channel_id, ...)` signature |
| `zone/companion.h` | 67–369 | `Companion` class: `IsCompanion()=true`, `GetOwnerCharacterID()`, `GetCompanionOwner()` |
| `zone/companion.cpp` | 950–966 | `Companion::CompanionGroupSay()` — already exists! |
| `zone/quest_parser_collection.cpp` | 1846–1864 | `EventBotMercNPC` dispatches to `EventNPC` for companions |

---

### Key Findings

#### 1. The opcode: OP_ChannelMessage

- Internal opcode: `OP_ChannelMessage` (defined via X-macro in `common/emu_oplist.h`)
- Titanium wire format: identical struct layout to internal format (only saylinks differ)
- Both ENCODE (server→client) and DECODE (client→server) registered in `titanium_ops.h`
- `ChannelMessage_Struct` (`eq_packet_structs.h:1189`):
  ```
  targetname[64]    // recipient name (tells)
  sender[64]        // sender name
  language          // uint32
  chan_num          // uint32 — ChatChannel_Group = 2
  cm_unknown4[2]    // placeholder
  skill_in_language // uint32
  message[0]        // variable-length text
  ```

#### 2. Group chat channel number

`ChatChannel_Group = 2` — defined in `common/eq_constants.h:953`.

#### 3. Client → Server: packet flow for /gsay

```
Titanium client sends OP_ChannelMessage (chan_num=2)
  → titanium.cpp DECODE: converts saylinks, direct memcpy of struct
  → client_packet.cpp:4566 Handle_OP_ChannelMessage
      reads ChannelMessage_Struct, calls:
  → client.cpp:1202 Client::ChannelMessageReceived(chan_num=2, language, lang_skill, message, targetname)
      switch(chan_num):
  → case ChatChannel_Group (line 1360):
      - checks if player is in a Raid → RaidGroupSay
      - else gets Group*, calls:
  → groups.cpp:905 Group::GroupMessage(sender, language, lang_skill, message)
      - iterates members[0..MAX_GROUP_MEMBERS-1]
      - for each Client member: calls ChannelMessageSend(sender->GetName(), member->GetName(), ChatChannel_Group, ...)
      - also sends ServerOP_OOZGroupMessage to worldserver (for cross-zone group members)
```

#### 4. Server → Client: injecting group chat as an NPC/companion

`ChannelMessageSend` signature (`zone/client.h:449`):
```cpp
void Client::ChannelMessageSend(const char* from, const char* to, uint8 channel_id,
                                 uint8 language_id, uint8 language_skill,
                                 const char* message, ...);
```

**The key mechanism:** To make a companion "speak" in group chat from the server side:
1. Get the `Group*` via `entity_list.GetGroupByMob(companion)` or `GetGroupByClient(client)`
2. Call `Group::GroupMessage(companion, Language::CommonTongue, Language::MaxValue, message)`
   - This calls `ChannelMessageSend(companion->GetName(), ...)` on every Client member
   - The client sees the message appear in group chat with the companion's name as sender
3. **This already exists** as `Companion::CompanionGroupSay(Mob* speaker, const char* msg, ...)` at `companion.cpp:950`

#### 5. Existing companion /say flow (for comparison)

When player targets companion and types `/say message`:
```
client.cpp:1629 ChatChannel_Say case:
  parse->EventBotMercNPC(EVENT_SAY, target, this, message, language)
    → quest_parser_collection.cpp:1859:
      EventNPC(EVENT_SAY, companion->CastToNPC(), client, message)
        → global_npc.lua EVENT_SAY handler
            → command parsing (!command) or LLM conversation
            → response via e.self:Say() — goes to local zone /say channel
```

**Difference from group chat path:** The existing path goes through `EventNPC` which fires `global_npc.lua`. The group chat path bypasses this entirely — the server directly calls `Group::GroupMessage` or `Companion::CompanionGroupSay`.

#### 6. Where to intercept /gsay for @-parsing

The ideal interception point is `client.cpp:1360` — the `case ChatChannel_Group:` block in
`ChannelMessageReceived`. This is:
- **Before** `Group::GroupMessage` is called (so we can suppress/modify delivery)
- **After** language processing and AFK/spam checks
- **In** the zone process with full access to `entity_list`, group members, etc.

The interception pattern would be:
```
case ChatChannel_Group:
    if (message contains '@') {
        // parse @mentions, dispatch to companion handlers
        // if message was only @-addressed (no residual text to broadcast),
        //   return without calling GroupMessage
        // else call GroupMessage with cleaned message
    }
    // existing group message path
```

#### 7. Companion enumeration in group

To enumerate companions in the player's group:
```cpp
Group* g = GetGroup();  // on the Client object
for (int i = 0; i < MAX_GROUP_MEMBERS; i++) {
    if (g->members[i] && g->members[i]->IsCompanion()) {
        Companion* c = (Companion*)g->members[i];
        // match c->GetCleanName() against @mention
        // use c->GetOwnerCharacterID() to verify ownership if needed
    }
}
```

`Companion::IsCompanion()` returns `true` (overrides `Entity::IsCompanion()` which returns `false`).
`Group::members[]` is a `Mob*` array, so the cast is safe after `IsCompanion()` check.

#### 8. Dispatching commands to a companion (the !command path)

For a `!command` payload, the existing `/say` path fires `EventBotMercNPC(EVENT_SAY, companion, client, "!command")`. To replicate this from the group chat handler:
```cpp
parse->EventBotMercNPC(EVENT_SAY, companion, this, [&]() { return std::string(payload); }, language);
```
This routes the command payload to `global_npc.lua` as if the player had targeted the companion and `/say`'d the command. **No new C++ command infrastructure needed.**

#### 9. Dispatching conversations to a companion (the LLM path)

The LLM conversation path currently flows: `EVENT_SAY` → `global_npc.lua` → `llm_bridge.lua` → HTTP POST → response via `e.self:Say()`.

For group chat, the response must go via `Companion::CompanionGroupSay()` instead of `Say()`. The lua-expert will need to modify `global_npc.lua` / `llm_bridge.lua` to support a response channel flag. The C++ side needs to pass that flag somehow — options:
1. Pass it as a prefix in the message (e.g., `[groupchat]@iskarr how are you?`) — fragile
2. Use a data bucket or NPC signal to convey the response channel
3. Add a new `EVENT_GROUP_SAY` event code that Lua can distinguish from `EVENT_SAY`
4. Pass it via a custom Lua global variable set before firing the event — simplest

**This is an architecture decision for the architect, not protocol-agent.**

#### 10. Titanium client constraints for group chat

- **No Titanium-specific struct differences:** The ChannelMessage encode/decode in `titanium.cpp` only converts saylinks. The struct layout is identical between internal and Titanium wire format.
- **Group size = 6:** `MAX_GROUP_MEMBERS = 6` (self + 5 others). Max 5 companion @mentions.
- **chan_num = 2 is stable:** The Titanium client uses `chan_num=2` for group chat. This maps to `ChatChannel_Group`. No ambiguity.
- **sender field is cosmetic:** The `sender` field in `ChannelMessage_Struct` is the display name in the client's chat window. When the server calls `ChannelMessageSend(companion->GetName(), ...)`, the companion's name appears as the speaker. This works perfectly for LLM response delivery.
- **No new opcodes needed:** The entire feature operates via existing `OP_ChannelMessage` packets. No Titanium opcode table changes required.

#### 11. The `EntityList::GroupMessage` function (entity.cpp:4676)

Alternative to `Group::GroupMessage` — takes group ID and `from` name directly:
```cpp
void EntityList::GroupMessage(uint32 gid, const char *from, const char *message)
```
This is simpler for server-side injection but `Group::GroupMessage` is preferred because it handles the ServerOP_OOZGroupMessage for cross-zone scenarios and uses the sender `Mob*` for the name.

---

### Architecture Recommendations for Architect

1. **Interception point:** `zone/client.cpp` in `ChannelMessageReceived`, `case ChatChannel_Group:` block.

2. **@-parser location:** New private helper method on `Client`, or a standalone function in a new file `zone/companion_group_chat.cpp`. The architect should decide scope.

3. **Command dispatch (no changes needed to protocol):** Reuse `parse->EventBotMercNPC(EVENT_SAY, companion, this, payload, language)` — identical to the `/say` path.

4. **LLM response channel:** The architect needs to determine how `global_npc.lua` should know to respond via `CompanionGroupSay` instead of `e.self:Say()`. Protocol-agent recommends a new event type (`EVENT_GROUP_SAY`) as the cleanest approach — the lua-expert can handle the Lua side.

5. **`CompanionGroupSay` is ready to use:** `companion.cpp:950` already implements the mechanism for a companion to speak in group chat. The LLM response path just needs to call it.

6. **No Titanium limitations block this feature:** The feature works entirely within existing packet structures and channel semantics. The Titanium client needs zero changes.

---

## Open Items

- [ ] Architect to decide: `EVENT_SAY` with channel flag vs. new `EVENT_GROUP_SAY` for LLM response routing
- [ ] Architect to decide: where to put the @-parser (method on Client vs. standalone helper)
- [ ] Architect to decide: stagger timer mechanism for multi-companion LLM responses
- [ ] lua-expert: `global_npc.lua` and `llm_bridge.lua` changes for group chat response channel

---

## Context for Next Agent

The /gsay interception needs zero new opcodes or packet structs. Everything
works through existing `OP_ChannelMessage` (chan_num=2). The interception point
is `zone/client.cpp:1360` (`case ChatChannel_Group:`). Companion enumeration
uses `group->members[i]->IsCompanion()`. Command dispatch reuses
`parse->EventBotMercNPC(EVENT_SAY, companion, player, payload)`. Companion
group chat injection uses `Companion::CompanionGroupSay()` at `companion.cpp:950`,
which calls `Group::GroupMessage(companion, ...)`, which calls
`ChannelMessageSend(companion->GetName(), ...)` on every Client group member.
