# Group Chat Companion Addressing — Dev Notes: C Expert

> **Feature branch:** `feature/group-chat-addressing`
> **Agent:** c-expert
> **Task(s):** #1 (Add Companion rules), #3 (Implement @-parser), #5 (Build/validate)
> **Date started:** 2026-03-07
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Add 3 group-chat rules to Companions category in ruletypes.h | — | In Progress |
| 3 | Implement @-mention parser and dispatch in client.cpp | #1 | Pending |
| 5 | Build, deploy, and validate | #3, #4 | Pending |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `common/ruletypes.h` | 1181-1203 | Companions category already exists with 19 rules. Add 3 group-chat rules before RULE_CATEGORY_END() at line 1203 |
| `zone/client.cpp` | 1360-1372 | `case ChatChannel_Group:` — interception point. Raid check at 1361, then `group->GroupMessage(...)` at 1369. Insert HandleGroupChatMentions() call before GroupMessage. |
| `zone/client.cpp` | 1629 | `parse->EventBotMercNPC(EVENT_SAY, t, this, [&]() { return message; }, language)` — exact call signature for dispatch |
| `zone/client.h` | 448 | `ChannelMessageReceived` declared in public section |
| `zone/client.h` | 2403-2413 | Last private section — add `HandleGroupChatMentions()` declaration here |

### Key Findings

- The `Companions` rule category already exists (not `Companion` as architecture doc says). I'll add to the existing `Companions` category and use `RuleB(Companions, ...)` / `RuleI(Companions, ...)` macros consistently.
- The architecture doc says `RULE_CATEGORY(Companion)` but the existing category is `Companions`. To avoid creating a duplicate category, I add the 3 rules to the existing `Companions` block.
- IMPORTANT: The rule names must be `Companions:GroupChatAddressingEnabled` etc. (with 's') — this affects data-expert's SQL inserts. I must notify data-expert and lua-expert.
- `EventBotMercNPC` signature confirmed: `(event_type, Mob* npc, Client* client, std::function<std::string()> message_fn, uint8 language)`
- `group->members[]` is `Mob*[MAX_GROUP_MEMBERS]` — IsCompanion() check then cast
- Architecture specifies entity variable names: `gsay_response_channel`, `gsay_stagger_ms`, `gsay_pending_response`

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `common/ruletypes.h` | Modify | Add 3 rules inside existing Companions category (before RULE_CATEGORY_END at line 1203) |
| `zone/client.h` | Modify | Add private method declaration `HandleGroupChatMentions(Group*, uint8, uint8, const char*)` |
| `zone/client.cpp` | Modify | Add `HandleGroupChatMentions()` call in `case ChatChannel_Group:` block; implement method |

**Change sequence:**
1. Add 3 rules to `common/ruletypes.h` Companions category
2. Build to verify compilation of rules
3. Add private method declaration to `zone/client.h`
4. Implement `HandleGroupChatMentions()` in `zone/client.cpp`
5. Modify `case ChatChannel_Group:` to call the method
6. Build again to verify full compilation
7. Commit to feature branch

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| RULE_BOOL / RULE_INT macros | Source: ruletypes.h lines 1-37, 1181-1203 | Yes | X-macro pattern confirmed |
| EventBotMercNPC signature | Source: client.cpp:1629 | Yes | `(event, Mob*, Client*, lambda, language)` |
| group->members[] array | Architecture doc + topography | Yes | Mob* array, null-check required |
| IsCompanion() method | Architecture doc: verified at source | Yes | Returns true for Companion* |
| SetEntityVariable / GetEntityVariable | Topography: lua_mob.cpp:2815,2845 | Yes | Already used by commentary system |
| GetCleanName() | EQEmu standard Mob method | Yes | Returns name without underscores |
| strchr for @ detection | C stdlib | Yes | Fast null-check before parsing |

### Plan Amendments

Key finding: existing category is `Companions` (plural), not `Companion`. The architecture doc specifies `RULE_CATEGORY(Companion)` (singular) but that would create a second separate category. To maintain consistency with existing rules, add to `Companions`.

This changes the rule access pattern:
- `RuleB(Companions, GroupChatAddressingEnabled)` (not `Companion`)
- `RuleI(Companions, GroupChatResponseStaggerMinMS)`
- `RuleI(Companions, GroupChatResponseStaggerMaxMS)`

And the rule_values table entries become `Companions:GroupChatAddressingEnabled` etc.

Must message data-expert with corrected category name.
Must message lua-expert with confirmed entity variable names.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| data-expert | Rule category name correction | Category is `Companions` not `Companion` — SQL inserts need `Companions:GroupChatAddressingEnabled` |
| lua-expert | Entity variable names confirmed | gsay_response_channel, gsay_stagger_ms, gsay_pending_response — confirmed as per architecture doc |

### Consensus Plan

**Agreed approach:**
- Add 3 rules to existing `Companions` category in ruletypes.h (not a new category)
- Implement `HandleGroupChatMentions()` as private Client method
- Use entity variable signaling as specified in architecture doc
- Entity variable names confirmed: `gsay_response_channel`, `gsay_stagger_ms`, `gsay_pending_response`

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | Modify | 3 new rules in Companions block (before RULE_CATEGORY_END) |
| `eqemu/zone/client.h` | Modify | Private method declaration |
| `eqemu/zone/client.cpp` | Modify | Method implementation + call in ChatChannel_Group case |

**Change sequence (final):**
1. Add rules to ruletypes.h → commit
2. Add declaration to client.h + implement in client.cpp → commit
3. Build → commit if clean

---

## Stage 4: Build

### Implementation Log

#### 2026-03-07 — Task 1: Add rules to ruletypes.h

**What:** Added 3 new rules to the existing `Companions` category in ruletypes.h
**Where:** `eqemu/common/ruletypes.h` lines 1202-1204 (before RULE_CATEGORY_END)
**Why:** Feature requires tunable toggle and stagger timing. Placing in existing Companions category (not new Companion category) maintains consistency.
**Notes:** Architecture doc said `RULE_CATEGORY(Companion)` but existing category is `Companions` — added to existing block.

#### 2026-03-07 — Task 3: Implement @-parser in client.cpp

**What:** Added private method `HandleGroupChatMentions()` to Client; modified `case ChatChannel_Group:` to call it.
**Where:** `eqemu/zone/client.h` (declaration), `eqemu/zone/client.cpp` (implementation + call site)
**Why:** @-mention parsing must intercept before GroupMessage() — no Lua hook available at this point.
**Notes:** Entity variable names: gsay_response_channel, gsay_stagger_ms, gsay_pending_response (as architecture specifies).

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| Category name mismatch | Architecture doc says `Companion`, source has `Companions` | Added to existing `Companions` category; notified data-expert |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | Modified | 3 group-chat rules added to Companions category |
| `eqemu/zone/client.h` | Modified | HandleGroupChatMentions private method declared |
| `eqemu/zone/client.cpp` | Modified | HandleGroupChatMentions implemented + called from ChatChannel_Group |

---

## Open Items

- [ ] Task #5: Build and validate after lua-expert completes Task #4

---

## Context for Next Agent

If picking up this work after context compaction:

1. The feature adds @-mention parsing to /gsay group chat.
2. Three rules live in the `Companions` category (plural) of ruletypes.h: `GroupChatAddressingEnabled`, `GroupChatResponseStaggerMinMS`, `GroupChatResponseStaggerMaxMS`.
3. The C++ parser is in `Client::HandleGroupChatMentions()` in client.cpp.
4. Entity variable names used to signal Lua: `gsay_response_channel` (set to "group"), `gsay_stagger_ms` (delay in ms as string), `gsay_pending_response` (stored response text).
5. Architecture doc: `claude/project-work/feature/group-chat-addressing/architect/architecture.md`
6. For Task #5: build with `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"` then restart server.
