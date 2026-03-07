# Group Chat Companion Addressing — Agent Conversations Log

> **Feature branch:** `feature/group-chat-addressing`
> **Created:** 2026-03-07

This file preserves cross-agent communication for context durability. When
context windows compact, this log ensures decisions, coordination, and
rationale are never lost.

**Every agent on a team MUST log their SendMessage exchanges here.**

**Rules:**
1. Log ALL exchanges, including "no concerns" / "no constraints" responses
2. Log the date, sender, recipient, content summary, and outcome
3. An empty section for a team phase means the team process was skipped
4. "APPROVED — no issues" is a valid and valuable finding; it must be logged
5. This file is the audit trail that proves peer review actually happened

---

## Design Team Conversations

_game-designer + lore-master exchanges during Phase 2._

### 2026-03-07 — Lore Review: Complete PRD Draft

**From:** game-designer → **To:** lore-master

> Sent complete PRD draft for lore review. Key review areas:
> 1. Era compliance — /gsay as Classic-era channel, @syntax server-side only
> 2. Example scenario — Level 45 SK in Sebilis with companions discussing Kunark-era content
> 3. NPC prefix stripping list — Guard, Captain, Lady, Lord, Sir, Priestess, High Priestess, Scout, Merchant, Innkeeper, Banker, Sage, Elder, Master, Apprentice
> 4. Overall — purely mechanical QoL feature, no narrative content

**Response from** lore-master:

> **APPROVED** with prefix list additions.
>
> 1. Era compliance: APPROVED. /gsay is Classic-era, @-syntax is server-side only, no post-Luclin references.
> 2. Sebilis example scenario: APPROVED. Sebilite Juggernauts, Iksar necromancers, zone layout references all confirmed accurate to Kunark lore. Zone internal name is `sebilis`.
> 3. Prefix list: APPROVED with additions — recommended adding Lieutenant, Warden, Keeper, Deputy, Sergeant based on PEQ database audit of Classic-Luclin city NPCs. Also noted Hierophant, Squire, Brother, Sheriff as rarer candidates.
> 4. Overall concept: APPROVED. Purely mechanical routing feature, no lore or narrative content, no era concerns.
>
> Key notes for architect: (1) zone short name is `sebilis` internally, (2) prefix list should consider the five additions above.

**Outcome:** PRD approved by lore-master. Prefix list updated to include Lieutenant, Warden, Keeper, Deputy, Sergeant. PRD status changed to Approved.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-03-07 — Protocol Research: /gsay Packet Handling

**From:** protocol-agent → **To:** architect

> Protocol research complete. Key findings:
>
> 1. **Opcode:** `OP_ChannelMessage` (chan_num=2 = ChatChannel_Group). No new opcodes needed. Titanium wire format identical to internal struct — no client constraints.
>
> 2. **Interception point:** `zone/client.cpp:1360` — `case ChatChannel_Group:` in `ChannelMessageReceived()`, before `Group::GroupMessage()` is called.
>
> 3. **Companion enumeration:** `group->members[i]->IsCompanion()` — `Companion::IsCompanion()=true`, cast to `Companion*` for `GetCleanName()`, `GetOwnerCharacterID()`.
>
> 4. **Command dispatch:** Reuse `parse->EventBotMercNPC(EVENT_SAY, companion, this, payload, language)` — identical to existing `/say` → companion path. No new C++ infrastructure.
>
> 5. **Group chat injection:** `Companion::CompanionGroupSay(companion, msg)` already exists at `companion.cpp:950`. Calls `Group::GroupMessage(companion, ...)` → `ChannelMessageSend(companion->GetName(), ...)` on every Client member.
>
> 6. **LLM response channel (architecture decision needed):** Currently `e.self:Say()` in Lua. For group chat, need `CompanionGroupSay()` instead. Options: (1) new `EVENT_GROUP_SAY` event type — recommended; (2) Lua global flag before firing EVENT_SAY; (3) message prefix encoding.
>
> 7. **No Titanium limitations block this feature.**
>
> Full details in `protocol-agent/dev-notes.md`.

**Outcome:** Architect received findings. Used to inform architecture decisions.

---

### 2026-03-07 — Config Assessment: Group Chat Addressing

**From:** config-expert → **To:** architect

> Config assessment complete. Summary of findings:
>
> 1. **Feature enable/disable rule recommended:** `Companion:GroupChatAddressingEnabled` (BOOL, default true). Follows Bots:Enabled precedent. Requires new Companion category in ruletypes.h — c-expert task.
>
> 2. **Prefix strip list: do NOT make a rule.** No RULE_STR list-splitting support; list is stable content, not a tuning knob. Hardcode the lore-master-approved 20 prefixes in Lua/C++.
>
> 3. **Stagger delay: 2 rules recommended:** `Companion:GroupChatResponseStaggerMinMS` (INT, default 1000) and `Companion:GroupChatResponseStaggerMaxMS` (INT, default 2000). Follows Bots:AEMezSuccessDelay pattern. Architect should confirm whether these live in C++ or are passed to the Python sidecar.
>
> 4. **No existing rules interact with this feature.** Chat: and Channels: categories cover anti-spam, saylinks, channel admin — none touch @name parsing, companion routing, or LLM timing.
>
> 5. **Anti-spam flag:** Verify that companion GroupSay messages sent as NPC entities do not count against the player's Chat:EnableAntiSpam / MaximumMessagesPerInterval quota. If they do, @all conversations could trigger kick thresholds.
>
> Full details in: `config-expert/dev-notes.md`

**Outcome:** Architect received findings. All 3 rules adopted. Anti-spam concern resolved (group chat not subject to anti-spam checks — verified at client.cpp:1268).

---

### 2026-03-07 — Architect Response: Architecture Decisions

**From:** architect → **To:** protocol-agent, config-expert

> Architecture decisions made based on your findings:
>
> 1. **LLM response channel routing:** Entity variable signaling chosen over
>    EVENT_GROUP_SAY. C++ sets `gsay_response_channel=group` entity variable on
>    companion before dispatching EVENT_SAY. Lua reads the variable and uses
>    `group:GroupMessage(e.self, response)` instead of `e.self:Say(response)`.
>    Rationale: simpler than new event type, no C++ event enum changes, entity
>    variables already standard for companion state signaling.
>
> 2. **All 3 rules adopted** as config-expert proposed: `Companion:GroupChatAddressingEnabled`
>    (BOOL, true), `Companion:GroupChatResponseStaggerMinMS` (INT, 1000),
>    `Companion:GroupChatResponseStaggerMaxMS` (INT, 2000).
>
> 3. **Prefix strip list hardcoded** in C++ per config-expert recommendation.
>    20 prefixes approved by lore-master.
>
> 4. **Anti-spam concern resolved:** Group chat (chan_num=2) is NOT subject to
>    `Chat:EnableAntiSpam` — anti-spam only checks Shout, Auction, OOC, Tell
>    channels (verified at client.cpp:1268). Companion group chat messages are
>    safe from triggering kick thresholds.
>
> 5. **Stagger timing in C++/Lua hybrid:** C++ sets `gsay_stagger_ms` entity
>    variable with per-companion delay values. Lua reads this and uses
>    `eq.set_timer()` for delayed delivery. Rules are read in C++ and passed
>    as entity variable values.
>
> 6. **Non-owner @mention handling (PRD Open Q4):** Companions respond to any
>    group member who addresses them via @name, not just their owner. Matches
>    EQ group chat semantics.

**Outcome:** Architecture plan finalized. Document written at `architect/architecture.md`.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### [Date] — [Topic]

**From:** [agent] → **To:** [agent]

> [Message content or summary]

**Response from** [agent]:

> [Response content or summary]

**Outcome:** _What was decided or changed as a result_

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Entity variable signaling for LLM response channel (not EVENT_GROUP_SAY) | architect, protocol-agent | 2026-03-07 | Simpler: no C++ event enum changes, entity vars already standard for companion state |
| 2 | 3 new rules in new Companion category (enable toggle + stagger min/max) | architect, config-expert | 2026-03-07 | Follows Bots:Enabled precedent; stagger values are UX tuning knobs |
| 3 | Prefix strip list hardcoded in C++ (not configurable via rules) | architect, config-expert | 2026-03-07 | Rules are scalar-only; list is stable content, not a tuning knob |
| 4 | Anti-spam does NOT affect group chat — companion responses are safe | architect, config-expert | 2026-03-07 | Verified: EnableAntiSpam only checks Shout/Auction/OOC/Tell (client.cpp:1268) |
| 5 | Non-owner group members can @mention companions | architect | 2026-03-07 | PRD Open Q4: matches EQ group chat semantics — all members interact with all members |
| 6 | Show raw @mention text to all group members (no reformatting) | architect | 2026-03-07 | PRD Open Q1: transparent — helps other players understand commands being issued |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| None | — | — | — |
