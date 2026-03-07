# Group Chat Companion Addressing — Architecture & Implementation Plan

> **Feature branch:** `feature/group-chat-addressing`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-03-07
> **Status:** Approved

---

## Executive Summary

This feature enables players to address recruited NPC companions via `@Name`
patterns in `/gsay` group chat, routing both `!commands` and LLM conversations
without requiring target switching. The implementation adds a C++ @-mention
parser in the group chat handler (`client.cpp`), three new rules in a new
`Companion` category (`ruletypes.h`), and Lua modifications to
`global_npc.lua` to route LLM responses through group chat when signaled via
entity variable. No new opcodes, packet structs, database tables, or Titanium
client changes are required.

## Existing System Analysis

### Current State

**Group chat packet flow:**
```
Client sends OP_ChannelMessage (chan_num=2)
  → titanium.cpp DECODE: saylink conversion only, struct passes through
  → client_packet.cpp:4566 Handle_OP_ChannelMessage
  → client.cpp:1202 Client::ChannelMessageReceived(chan_num=2, ...)
  → client.cpp:1360 case ChatChannel_Group:
      → checks for Raid → RaidGroupSay
      → else: group->GroupMessage(this, language, lang_skill, message)
  → groups.cpp:905 Group::GroupMessage()
      → iterates members[0..5], calls ChannelMessageSend() on each Client
      → sends ServerOP_OOZGroupMessage for cross-zone members
```

**Companion `/say` command flow:**
```
Player targets companion, types /say !command
  → client.cpp:1617 case ChatChannel_Say:
      → parse->EventBotMercNPC(EVENT_SAY, target, this, message, language)
  → quest_parser_collection.cpp:1859 EventNPC(EVENT_SAY, companion, client, message)
  → global_npc.lua:event_say(e)
      → if e.message starts with "!" → companion_lib.dispatch_prefix_command()
      → else → llm_bridge.is_eligible(e) → llm_bridge.build_context(e)
              → llm_bridge.generate_response(context, message)
              → e.self:Say(response)  ← delivers via local /say
```

**Companion group chat injection (already exists):**
- `Companion::CompanionGroupSay(Mob* speaker, const char* msg, ...)`
  at `companion.cpp:950` — calls `Group::GroupMessage(speaker, ...)` which
  calls `ChannelMessageSend(speaker->GetName(), ...)` on each Client member.
- `group:GroupMessage(Lua_Mob sender, const char* message)` — Lua binding
  at `lua_group.cpp:40`, already exposed. Companion (inherits Lua_Mob) can
  be passed as sender.

**Entity variable API (already exposed to Lua):**
- `mob:SetEntityVariable(name, value)` — `lua_mob.cpp:2845`
- `mob:GetEntityVariable(name)` — `lua_mob.cpp:2815`
- In-memory only; cleared on NPC despawn. Already used extensively by
  companion commentary system in `global_npc.lua`.

**Anti-spam assessment (resolved):**
The `Chat:EnableAntiSpam` rule only applies to Shout, Auction, OOC, and Tell
channels (`client.cpp:1268`). Group chat (`ChatChannel_Group = 2`) is NOT
subject to anti-spam checks. Companion GroupSay messages are safe from
triggering player kick thresholds.

### Gap Analysis

| What the PRD Requires | Current State | Gap |
|----------------------|---------------|-----|
| @Name parsing in /gsay | No parsing — raw text goes to GroupMessage | Need C++ parser before GroupMessage call |
| Route !commands to companion without target | EVENT_SAY dispatch requires target Mob* | Need to call EventBotMercNPC with resolved companion as target |
| LLM responses in group chat | Responses delivered via e.self:Say() (local /say) | Need signaling mechanism for Lua to use group:GroupMessage() instead |
| Response staggering for multi-companion | No stagger mechanism | Need timer-based delivery in Lua |
| Feature enable/disable toggle | No Companion rule category | Need new category + 3 rules in ruletypes.h |
| NPC prefix stripping for name matching | No prefix matching logic | Need prefix strip list in C++ parser |

## Technical Approach

### Architecture Decision

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `ruletypes.h` — new Companion category + 3 rules | Rule values (Priority 1) | Feature toggle and stagger timing are tunable values that belong in the rule system. Follows `Bots:Enabled` precedent. |
| `rule_values` table — INSERT 3 rows | SQL (Priority 4) | Populate default rule values in database |
| `global_npc.lua` — response channel routing | Lua scripts (Priority 3) | Modify existing response delivery to check entity variable and use group:GroupMessage() when signaled. Stagger timer logic lives here. |
| `client.cpp` — @-mention parser + dispatch | C++ source (Priority 5) | Must intercept before GroupMessage is called. No Lua or config mechanism can intercept raw /gsay text before the C++ handler processes it. The interception point is in compiled C++ code. |

**Justification for C++ involvement:** The @-mention parsing must happen
before `Group::GroupMessage()` is called (at `client.cpp:1360`). There is no
Lua hook that fires between the client receiving the OP_ChannelMessage packet
and the group message broadcast. The C++ interception is unavoidable.
Everything downstream (response channel, staggering) is handled in Lua.

**Entity variable signaling (preferred over alternatives):**
The C++ parser sets a temporary entity variable on the companion before
dispatching EVENT_SAY. This is preferred over:
- New EVENT_GROUP_SAY event type — requires C++ event enum changes, Lua event
  registration, and creates a parallel code path in global_npc.lua
- Lua global variable — not entity-scoped, race-prone with multiple companions
- Message prefix encoding — fragile string parsing

Entity variables are already the standard signaling mechanism for companion
state (commentary system uses 5+ entity variables). The variable is set before
dispatch, read in Lua, and cleared after response delivery.

### Data Model

No new database tables. No schema changes.

Three new rows in the existing `rule_values` table (see Database Changes).

### Code Changes

#### C++ Changes

**File: `eqemu/common/ruletypes.h`**

Add a new `Companion` rule category with three rules:

```cpp
RULE_CATEGORY(Companion)
RULE_BOOL(Companion, GroupChatAddressingEnabled, true, "Enable @Name companion addressing via /gsay group chat")
RULE_INT(Companion, GroupChatResponseStaggerMinMS, 1000, "Minimum stagger delay in ms between companion LLM responses in group chat")
RULE_INT(Companion, GroupChatResponseStaggerMaxMS, 2000, "Maximum stagger delay in ms between companion LLM responses in group chat")
RULE_CATEGORY_END()
```

**File: `eqemu/zone/client.cpp`**

Modify `ChannelMessageReceived()` at `case ChatChannel_Group:` (line 1360).

Before the existing `group->GroupMessage(this, ...)` call, add @-mention
interception:

1. **Early exit check:** If `!RuleB(Companion, GroupChatAddressingEnabled)`,
   skip parsing and fall through to normal GroupMessage.

2. **Detect @ presence:** Quick scan for `@` character in message. If none
   found, fall through to normal GroupMessage.

3. **Parse @mentions:** Extract all `@name` tokens from the message. The
   `@` must be at word boundary (start of message or preceded by space).
   Collect tokens into a vector.

4. **Handle `@all`:** If any token is `all` (case-insensitive), expand to
   all companions in the group.

5. **Resolve companions:** For each @name token, iterate
   `group->members[0..MAX_GROUP_MEMBERS-1]`:
   - Skip null members, skip non-companions (`!members[i]->IsCompanion()`)
   - Get the companion's `GetCleanName()`
   - Strip known prefixes (Guard, Captain, Lady, Lord, Sir, Priestess,
     High Priestess, Scout, Merchant, Innkeeper, Banker, Sage, Elder,
     Master, Apprentice, Lieutenant, Warden, Keeper, Deputy, Sergeant)
   - Compare stripped name against @token (case-insensitive, substring match)
   - If match, add to resolved set (deduplicate)

6. **Extract payload:** Everything after the last @mention is the payload.
   The word "and" between @mentions is stripped. Leading/trailing whitespace
   is trimmed.

7. **If no companions resolved:** Fall through to normal GroupMessage
   (send the raw message as regular group chat — silent failure per PRD).

8. **Broadcast the original message to group:** Call
   `group->GroupMessage(this, language, lang_skill, message)` so all
   group members see what the player typed (PRD Open Question 1: show as-is).

9. **Dispatch payload to each resolved companion:**
   - Determine payload type: starts with `!` = command, else = conversation
   - For commands: call `parse->EventBotMercNPC(EVENT_SAY, companion, this,
     [&]() { return std::string(payload); }, language)` — reuses existing
     companion command dispatch path
   - For conversations: set entity variable `gsay_response_channel=group`
     on the companion, then call same EventBotMercNPC dispatch. The Lua
     side reads this variable to choose response delivery method.

10. **After dispatch:** `break` — do NOT call GroupMessage again (it was
    already called in step 8).

**New helper method on Client (private):**

```cpp
// In client.h:
private:
    void HandleGroupChatMentions(Group* group, uint8 language,
                                 uint8 lang_skill, const char* message);
```

This keeps the switch case clean. The method contains all @-parsing logic.

**Prefix strip list (hardcoded in C++):**

```cpp
static const std::vector<std::string> kCompanionPrefixes = {
    "High Priestess", // Multi-word prefixes first (greedy match)
    "Guard", "Captain", "Lady", "Lord", "Sir", "Priestess",
    "Scout", "Merchant", "Innkeeper", "Banker", "Sage", "Elder",
    "Master", "Apprentice", "Lieutenant", "Warden", "Keeper",
    "Deputy", "Sergeant"
};
```

Note: "High Priestess" must be checked before "Priestess" to avoid
partial stripping of "High Priestess" names.

#### Lua/Script Changes

**File: `akk-stack/server/quests/global/global_npc.lua`**

Modify `event_say()` to check for the `gsay_response_channel` entity variable
and route LLM responses via group chat when set.

Current flow (line 67-68):
```lua
if response then
    e.self:Say(response)
end
```

Modified flow:
```lua
if response then
    local channel = e.self:GetEntityVariable("gsay_response_channel")
    if channel == "group" then
        -- Clear the signal variable immediately
        e.self:SetEntityVariable("gsay_response_channel", "")
        -- Get the group and send via group chat
        local group = e.other:GetGroup()
        if group and group.valid then
            group:GroupMessage(e.self, response)
        else
            -- Fallback: if group lookup fails, use /say
            e.self:Say(response)
        end
    else
        e.self:Say(response)
    end
end
```

**Response staggering for multi-companion conversations:**

When the C++ side dispatches to multiple companions, the LLM sidecar calls
are inherently sequential (each `generate_response()` is a blocking curl
call in the zone process). The natural latency of LLM generation (typically
1-3 seconds per response) provides organic staggering.

However, the PRD requires guaranteed 1-2 second gaps. The C++ side handles
this by introducing a delay between dispatches when multiple companions
are addressed conversationally:

In `HandleGroupChatMentions()`, when dispatching conversation payloads to
multiple companions:
- Dispatch the first companion immediately
- For each subsequent companion, use a `QueueEvent` with a timer offset
  based on `Companion:GroupChatResponseStaggerMinMS` and
  `GroupChatResponseStaggerMaxMS` rules

**Alternative (simpler, recommended):** Since `generate_response()` in
`llm_bridge.lua` is blocking (the zone process pauses during curl), and
each companion's EVENT_SAY fires sequentially in the C++ dispatch loop,
the natural LLM generation time (1-3s) provides staggering automatically.

If the natural stagger proves insufficient (e.g., cached/fast LLM responses),
the Lua side can add an explicit delay before calling `group:GroupMessage()`:
```lua
if channel == "group" then
    -- Check if this is a multi-companion stagger scenario
    local stagger = e.self:GetEntityVariable("gsay_stagger_ms")
    if stagger ~= "" then
        e.self:SetEntityVariable("gsay_stagger_ms", "")
        local delay_ms = tonumber(stagger) or 0
        if delay_ms > 0 then
            -- Store response and schedule delivery via timer
            e.self:SetEntityVariable("gsay_pending_response", response)
            eq.set_timer("gsay_deliver_" .. e.self:GetID(), delay_ms)
            return  -- response will be delivered by event_timer
        end
    end
    -- Immediate delivery (first companion or no stagger needed)
    local group = e.other:GetGroup()
    if group and group.valid then
        group:GroupMessage(e.self, response)
    end
end
```

And in `event_timer()`:
```lua
if e.timer and e.timer:sub(1, 13) == "gsay_deliver_" then
    eq.stop_timer(e.timer)
    local response = e.self:GetEntityVariable("gsay_pending_response")
    if response and response ~= "" then
        e.self:SetEntityVariable("gsay_pending_response", "")
        -- Find the owner client for group lookup
        local owner_id = e.self:GetOwnerCharacterID()
        local owner = eq.get_entity_list():GetClientByCharID(owner_id)
        if owner and owner.valid then
            local group = owner:GetGroup()
            if group and group.valid then
                group:GroupMessage(e.self, response)
            end
        end
    end
end
```

The C++ side sets `gsay_stagger_ms` entity variable on companions 2..N
with increasing delays (companion 2 gets min_ms, companion 3 gets 2*min_ms,
etc., capped at max_ms per step, randomized within [min, max] range).

#### Database Changes

Three INSERT statements for `rule_values` table:

```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes)
VALUES
(1, 'Companion:GroupChatAddressingEnabled', 'true',
 'Enable @Name companion addressing via /gsay group chat'),
(1, 'Companion:GroupChatResponseStaggerMinMS', '1000',
 'Min stagger delay in ms between companion LLM responses in group chat'),
(1, 'Companion:GroupChatResponseStaggerMaxMS', '2000',
 'Max stagger delay in ms between companion LLM responses in group chat');
```

#### Configuration Changes

No changes to `eqemu_config.json` or `.env`. All tunables are rule values.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Add Companion rule category + 3 rules to `ruletypes.h` | c-expert | — | Small: add RULE_CATEGORY block with 3 rules |
| 2 | Insert `rule_values` rows for the 3 Companion rules | data-expert | 1 | Small: 3 INSERT statements |
| 3 | Implement @-mention parser and dispatch in `client.cpp` | c-expert | 1 | Medium: new private method `HandleGroupChatMentions()`, modify `case ChatChannel_Group:` block |
| 4 | Modify `global_npc.lua` for group chat response routing + stagger timer | lua-expert | 3 | Medium: entity variable check in event_say, timer-based stagger delivery in event_timer |
| 5 | Build, deploy, and validate | c-expert | 3, 4 | Small: ninja build, make restart, start server processes |

**Dependency chain:** 1 → 2 (parallel with 3) → 3 → 4 → 5

Task 1 must complete first (rules needed by Task 3's C++ code).
Task 2 can run in parallel with Task 3 (SQL doesn't block compilation).
Task 3 must complete before Task 4 (Lua changes depend on knowing exact
entity variable names and dispatch behavior from C++).
Task 5 validates the integrated result.

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| @-parser fails on edge-case message formats (empty payload, @-only, special chars) | Medium | Low | Defensive parsing: trim whitespace, check for empty payload, skip dispatch if no valid payload. Fall through to normal GroupMessage on any parse failure. |
| Entity variable race condition: variable set by C++ not visible to Lua in same tick | Low | Medium | Entity variables are set on the Mob object in the same thread (zone process is single-threaded). SetEntityVariable → EventBotMercNPC → Lua event_say all execute synchronously. No race possible. |
| LLM generate_response blocks zone process during multi-companion @all | Medium | Medium | This is the existing behavior for single-companion /say conversations. For @all with 3 companions, worst case is 3 × timeout_seconds blocking. Acceptable for 1-3 player server. Future enhancement: async sidecar calls via signal/timer. |
| Stagger timer fires after companion despawns or owner zones | Low | Low | Timer handler checks companion validity and group membership before delivering. Invalid state → timer fires, checks fail, no delivery. Timer name includes entity ID, so eq.stop_timer can clean up. |

### Compatibility Risks

**Regression risk: Normal /gsay without @mentions.**
Messages without `@` characters take the fast path (no parsing) and reach
`GroupMessage()` unchanged. The early-exit check (`if no @ in message`) is
a simple `strchr()` that adds negligible overhead.

**Regression risk: Existing /say companion commands.**
The `/say` → EVENT_SAY → `global_npc.lua` path is completely untouched.
The only change to `global_npc.lua` is in the response delivery block
(checking an entity variable that will be empty for /say-originated events).

**Regression risk: Raid group say.**
The Raid path (`raid->RaidGroupSay()`) is checked before the Group path
at `client.cpp:1361`. The @-parsing only applies to the non-raid Group
branch. Raid users are unaffected.

### Performance Risks

**Zone process blocking for multi-companion LLM calls:**
Each `generate_response()` call blocks the zone process for up to
`config.timeout_seconds` (typically 10s). For `@all` with 3 companions,
this could block for 30s in the worst case. This is identical to the risk
that already exists if a player /say's to a companion — the zone pauses
during the curl call. For a 1-3 player server this is acceptable.

**@-parsing overhead:**
The parser runs only on messages containing `@`. For a 6-member group with
3 companions, the parsing involves: 1 strchr scan, regex-free token
extraction, and 3 string comparisons per @mention. Negligible CPU impact.

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes. Every extension point needed already exists:

1. **Interception point** — `client.cpp:1360`, `case ChatChannel_Group:`
   block. Verified at source. Simple to add a method call before
   `GroupMessage()`.

2. **Companion enumeration** — `group->members[i]->IsCompanion()`.
   Verified: `Companion::IsCompanion()` returns true, `Group::members[]`
   is `Mob*` array. Cast to `Companion*` is safe after `IsCompanion()` check.

3. **Command dispatch** — `parse->EventBotMercNPC(EVENT_SAY, companion,
   this, payload, language)`. Verified at `client.cpp:1629` (existing /say
   path). Identical call signature works for group chat dispatch.

4. **Group chat injection from Lua** — `group:GroupMessage(Lua_Mob, message)`
   at `lua_group.cpp:40`. Verified: accepts any Lua_Mob (Companion inherits
   Lua_Mob). Companion name appears as sender in group chat.

5. **Entity variable signaling** — `mob:SetEntityVariable()` /
   `mob:GetEntityVariable()` at `lua_mob.cpp:2815,2845`. Already used
   extensively by companion commentary system.

6. **Rule system** — `RULE_CATEGORY` / `RULE_BOOL` / `RULE_INT` macros.
   Verified pattern at `ruletypes.h:769` (Bots category).

**Hardest part:** The @-mention parser in C++. It must handle: multiple
@mentions with "and" separators, substring matching against prefix-stripped
names, and clean payload extraction. This is string manipulation, not
algorithmic complexity — straightforward but needs careful implementation.

**Protocol-agent confirmation:** No Titanium client constraints. No new
opcodes needed. OP_ChannelMessage (chan_num=2) passes through Titanium
encode/decode unchanged (only saylinks are converted). The `sender` field
in `ChannelMessage_Struct` is cosmetic — companion names work as senders.

### Pass 2: Simplicity

**Is this the simplest approach?** Yes.

**Components (4 total):**
1. C++ rules definition (boilerplate)
2. C++ @-parser + dispatch (core logic, ~150 lines)
3. Lua response routing (entity variable check, ~20 lines)
4. SQL rule inserts (3 rows)

**What was deferred:**
- No new EVENT_GROUP_SAY event type (entity variable signal is simpler)
- No new C++ bindings for CompanionGroupSay in Lua (GroupMessage already
  exposed)
- No new LLM sidecar endpoint or field (sidecar is unaware of response
  channel — Lua handles delivery)
- No configuration file changes (rules are sufficient)
- No async LLM call mechanism (sequential blocking is acceptable for
  1-3 player server)

**What could be removed?** The stagger timer logic could be deferred if
natural LLM latency provides sufficient gap. The core feature (single
companion @name command/conversation) works without it. However, the PRD
requires it for @all, so it stays.

**YAGNI applied:**
- Prefix strip list is hardcoded, not configurable (config-expert confirmed)
- No "feedback on unmatched @mention" — silent failure per PRD
- No companion-to-companion group chat awareness (future enhancement)
- No async sidecar calls (future enhancement)

### Pass 3: Antagonistic

**Edge cases that break the design:**

1. **Empty payload:** `/gsay @iskarr` (no command, no text after name).
   **Mitigation:** Parser checks for empty payload after stripping @mentions
   and "and" words. If empty, skip dispatch, deliver message as normal group
   chat (player just said "@iskarr" in group — weird but harmless).

2. **@ in email-like text:** `/gsay contact me at bob@mail.com`.
   **Mitigation:** Parser only matches `@` at word boundary (preceded by
   start-of-string or whitespace). Mid-word `@` is not parsed. The PRD
   explicitly specifies this behavior.

3. **Player named "All":** A companion named "All" would conflict with
   `@all` broadcast.
   **Mitigation:** `@all` is a reserved keyword checked before name matching.
   A companion named "All" cannot be individually addressed via `@all` but
   can be addressed by a more specific substring.

4. **Ambiguous substring matches:** `/gsay @a !follow` matches every
   companion whose prefix-stripped name contains "a".
   **Mitigation:** This is intentional per PRD: "If `@war` matches both
   'Guard Warrick' and 'Priestess Warina', both receive the command."
   Players learn to use sufficiently specific substrings.

5. **Companion in different zone (cross-zone group):**
   **Mitigation:** The parser only iterates `group->members[]` which
   contains Mob pointers. Cross-zone members have null Mob pointers in the
   local zone's group object. They are naturally skipped by the null check.

6. **Message contains @ but no valid companion match:**
   `/gsay @nobody how are you?`
   **Mitigation:** Parser resolves zero companions, falls through to normal
   GroupMessage. Message broadcasts as regular group chat. Silent failure
   per PRD.

7. **Zone process blocks for extended time with @all + 3 companions:**
   **Mitigation:** This is the same risk as the existing /say LLM path.
   For a 1-3 player server, 3-10s of zone blocking per LLM call is
   acceptable. The zone process is single-threaded by design.

8. **gsay_response_channel variable persists after failed LLM call:**
   If `generate_response()` returns nil, the variable would remain set.
   **Mitigation:** Clear the variable immediately upon reading it in Lua
   (before calling the sidecar), not after. This way a failed LLM call
   doesn't leave stale state.

9. **Another player (non-owner) types @companionname:**
   PRD Open Question 4: should companions respond to non-owners?
   **Decision:** Yes, companions respond to any player who addresses them
   in group chat. The companion is a group member — all group members can
   interact with all other group members. This matches EQ group chat
   semantics and the PRD's example scenario (other players see the exchange).

10. **Rapid @all spam:** Player types `@all !attack` repeatedly.
    **Mitigation:** The command dispatch reuses `EventBotMercNPC` which
    fires the existing command handler. The companion command system has
    its own rate limiting / state management. No additional rate limiting
    needed for commands.

**Protocol-agent confirmation:** No packet-level edge cases. The Titanium
client sends `@` as a literal ASCII character in the message field. No
encoding issues. No opcode ambiguity.

### Pass 4: Integration

**Implementation sequence walkthrough:**

1. **c-expert adds rules to ruletypes.h** (Task 1). This is a clean edit
   at the end of the file, after existing categories. No merge conflicts
   expected. Must build to verify compilation.

2. **data-expert inserts rule_values** (Task 2). Three INSERT statements.
   Can run in parallel with Task 3 since the build doesn't depend on the
   database having the rule values (defaults are compiled into the binary).

3. **c-expert implements @-parser** (Task 3). Depends on Task 1 (needs
   `RuleB(Companion, GroupChatAddressingEnabled)` to compile). The parser
   is a new method on Client — no existing method signatures change. The
   `case ChatChannel_Group:` block gains a single method call at the top.

4. **lua-expert modifies global_npc.lua** (Task 4). Depends on Task 3
   (needs to know the exact entity variable names: `gsay_response_channel`,
   `gsay_stagger_ms`, `gsay_pending_response`). Changes are localized to
   the response delivery block and the timer handler.

5. **c-expert builds and deploys** (Task 5). Full build cycle: ninja build,
   make restart, start server processes (shared_memory → loginserver →
   world → zone).

**Each expert works independently:**
- c-expert has full context on the C++ changes (ruletypes.h + client.cpp)
- lua-expert has full context on the Lua changes (global_npc.lua)
- data-expert has the exact SQL statements to execute
- No expert needs to read another expert's code to do their work

**Cross-expert dependency:** lua-expert needs the entity variable names
from c-expert's implementation. These are specified in this architecture
doc, so lua-expert can work from the spec. If c-expert changes the variable
names, they must message lua-expert.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | Tasks 1, 3, 5 | C++ rule definitions, @-parser implementation, build/deploy |
| lua-expert | Task 4 | global_npc.lua response routing and stagger timer |
| data-expert | Task 2 | SQL INSERT for rule_values |

## Validation Plan

**For the game-tester agent (server-side validation):**

- [ ] `/gsay @companionname !follow` — companion executes !follow without player changing target
- [ ] `/gsay @companionname !attack` — companion attacks player's current target
- [ ] `/gsay @all !follow` — all companions in group execute !follow
- [ ] `/gsay @name1 and @name2 !follow` — both named companions execute !follow, others unaffected
- [ ] `/gsay @companionname how are you?` — companion responds via LLM in group chat (not /say)
- [ ] `/gsay @all what do you think?` — all companions respond in group chat with staggered timing
- [ ] Name matching is case-insensitive: `@ISKARR` matches "Guard Iskarr"
- [ ] Substring matching works: `@isk` matches "Guard Iskarr"
- [ ] Prefix stripping works: `@iskarr` matches "Guard Iskarr" (strips "Guard" prefix)
- [ ] Unmatched @names are silently ignored: `/gsay @nobody !follow` produces no error
- [ ] Mixed valid/invalid: `/gsay @iskarr and @nobody !follow` — Iskarr gets command, no error for nobody
- [ ] Regular /gsay without @ works normally (no regression)
- [ ] Existing /say companion commands work normally (no regression)
- [ ] Player's target is never changed by @mention interactions
- [ ] Companion LLM responses in group chat show companion name as speaker
- [ ] Feature can be disabled via `Companion:GroupChatAddressingEnabled = false` rule — @mentions pass through as regular group chat
- [ ] Response stagger: with multiple companions, 1-2 second gap between LLM responses
- [ ] EQ macro with multiple /gsay @name lines executes correctly

**In-game testing guide for the user:**

1. Recruit 2-3 companions into group
2. Target a mob (not a companion) and keep it targeted throughout
3. Type `/gsay @companionname !follow` — verify companion follows without target change
4. Type `/gsay @all !attack` — verify all companions engage your target
5. Type `/gsay @companionname tell me about this place` — verify LLM response appears in group chat
6. Type `/gsay @all how are you?` — verify each companion responds in group chat with staggered timing
7. Type `/gsay @badname !follow` — verify silent failure (no error message)
8. Type `/gsay hello everyone` (no @) — verify normal group chat behavior
9. Target a companion and type `/say !follow` — verify existing /say path still works

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
