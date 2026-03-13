# Companion Behavior Improvements — Dev Notes: Lua Expert

> **Feature branch:** `feature/companion-behavior-improvements`
> **Agent:** lua-expert
> **Task(s):** Task 4 — BUG-025: Rewrite buff timer handler to sequential queue
> **Date started:** 2026-03-12
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 4 | BUG-025: Rewrite buff timer handler in global_npc.lua to sequential queue | — | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `akk-stack/server/quests/global/global_npc.lua` | 403-524 | Buff timer handler: builds target list, queries DB, nested loop calls CastSpell for each spell x each target in one tick — root cause of bug |
| `akk-stack/server/quests/lua_modules/companion.lua` | 956-1003 | cmd_buffme sets `buff_request_target="owner"`, cmd_buffs sets `buff_request_target="party"`, both start timer `buff_request_<npc_id>` at 2000ms |
| `claude/docs/topography/LUA-CODE.md` | full | eq.set_timer, eq.stop_timer, entity variables, Database() API, group:GetMember(i), event_timer pattern |
| `claude/project-work/feature/companion-behavior-improvements/architect/architecture.md` | 258-285 | Architect's design: build queue of {spell_id, target_id} pairs, store as JSON, process one pair per tick, re-arm timer, stop when empty |

### Key Findings

1. **Root cause confirmed:** Lines 494-507 in `global_npc.lua` — nested loop calls `CastSpell()` for every (spell, target) pair in one tick. `CastSpell()` sets `casting_spell_id` on first success; all subsequent calls find it non-zero and silently return false. Only spell #1 on the first target actually gets cast.

2. **Entity variable storage:** The architect specifies storing a JSON queue in entity variables. The `json` Lua module is available via `require("json")`. Entity variables are strings so JSON serialization is needed.

3. **Queue approach:** Build the full list of `{spell_id, target_id}` pairs upfront on the first timer fire, serialize to JSON, store in `buff_queue`. Each subsequent timer fire pops index `buff_queue_idx`, casts one spell, increments index, re-arms timer.

4. **Target validity:** Must re-verify `target.valid` each tick before casting — party member may have zoned, died, or left group since queue was built.

5. **Combat guard:** Existing check `e.self:IsEngaged() or e.self:IsCasting()` already handles waiting until idle. The queue build only happens when NOT engaged; mid-queue engagement check is separate.

6. **!buffs vs !buffme distinction:** `request == "owner"` → only queue spells targeting the owner client. `request == "party"` → queue spells for all group members. Both correctly set in companion.lua already.

7. **New entity variables needed:**
   - `buff_queue` — JSON string: array of `[spell_id, target_id]` pairs
   - `buff_queue_idx` — current index (1-based) into queue

8. **Cleanup:** When queue is empty or exhausted, clear `buff_request_target`, `buff_request_retries`, `buff_queue`, `buff_queue_idx`.

### Implementation Plan

**Files to modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/global/global_npc.lua` | Modify | Rewrite buff timer handler (lines 403-524) |

**Change sequence:**
1. Keep the timer name check, retry cap check, idle check (these are correct)
2. On first timer fire (when `buff_queue` entity var is empty), build the queue: query DB for spell IDs, iterate targets, push `{spell_id, target_id}` pairs into a list, serialize to JSON, store in `buff_queue`, set `buff_queue_idx = 1`
3. On every timer fire: read `buff_queue` + `buff_queue_idx`, if queue exists: pop the current entry (index), cast ONE spell on the target (after validity check), increment index, re-arm timer for 2000ms
4. When index exceeds queue length: clear all entity vars, stop timer, optionally send "buffs complete" message
5. If companion enters combat while queue is active: keep existing `IsEngaged()` check — re-arm and retry when idle

**What to test:**
- `!buffme` → only player gets buffed, one spell per timer tick
- `!buffs` → all party members buffed, one spell per tick across all targets
- Party member dead/zoned mid-queue → skipped cleanly
- Companion enters combat mid-queue → waits until idle, resumes
- New `!buffs` request while queue in progress → resets and starts fresh

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `e.self:GetEntityVariable("key")` | LUA-CODE.md topography | Yes | Returns string; empty string if not set |
| `e.self:SetEntityVariable("key", "val")` | LUA-CODE.md topography | Yes | Value must be string |
| `require("json")` | LUA-CODE.md topography (module table) | Yes | json.lua in lua_modules, available globally |
| `json.encode(t)` / `json.decode(s)` | Standard json.lua interface | Yes | Standard encode/decode interface |
| `eq.set_timer("name", ms)` | LUA-CODE.md topography | Yes | Starts/restarts named timer |
| `eq.stop_timer("name")` | LUA-CODE.md topography | Yes | Stops timer |
| `e.self:CastSpell(spell_id, target_id, slot)` | LUA-CODE.md topography + existing code line 502 | Yes | slot 7 = misc spell slot |
| `group:GetMember(i)` for i=0..5 | existing code lines 466-470 | Yes | Returns Mob (client or NPC), check .valid |
| `Database():prepare()` / `stmt:execute({})` / `stmt:fetch_hash()` | LUA-CODE.md topography + existing code lines 484-508 | Yes | Standard DB prepared statement pattern |
| `target:GetID()` | LUA-CODE.md topography | Yes | Returns entity ID for CastSpell target_id arg |
| `eq.get_entity_list():GetMobByID(id)` | LUA-CODE.md general API | Yes | Re-fetch mob by ID each tick for validity check |

### Plan Amendments

The architect specifies storing the queue as a JSON array and using `buff_queue_idx` as a separate counter. On re-reading, this is clean. One refinement: instead of storing target_id and re-fetching by ID each tick (which risks stale IDs if entity is recreated), we store target_id and use `GetMobByID()` — if nil or not valid, skip. This matches the architect's guidance for the "target dies mid-queue" edge case.

For the DB query, the existing code already correctly queries `companion_spell_sets` with the right BUFF_TYPE_MASK. Keep that logic unchanged, just collect spell IDs instead of immediately casting them.

Plan confirmed — no structural amendments needed.

### Verified Plan

See Implementation Plan above — confirmed by research. Proceed to Stage 3.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| team-lead | BUG-025 plan review | No cross-system dependencies — this is pure Lua. No questions for c-expert. |

### Feedback Received

No blocking feedback required. Architecture doc is comprehensive and self-consistent for this Lua task. The c-expert tasks are independent (different files, different repo).

### Consensus Plan

**Agreed approach:** Rewrite the buff timer handler in `global_npc.lua` as a two-phase sequential queue:
- **Phase 1 (build):** When timer fires and `buff_queue` entity var is empty, query DB, build full list of (spell_id, target_id) pairs for all applicable targets, serialize to JSON, store in `buff_queue`, set `buff_queue_idx = "1"`, then immediately process the first entry (don't re-arm — process inline to avoid an extra 2s delay).
- **Phase 2 (process):** Each timer fire reads one entry from the queue at `buff_queue_idx`, validates the target via `GetMobByID()`, casts one spell, increments index, re-arms timer for 2000ms. When index exceeds queue length, clean up all entity vars.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/global/global_npc.lua` | Modify | Replace lines 403-524 (buff timer section) |

**Change sequence (final):**
1. Update status.md Task 4 to In Progress
2. Rewrite buff handler in global_npc.lua
3. Verify no syntax errors
4. Commit to feature branch
5. Update status.md Task 4 to Complete

---

## Stage 4: Build

### Implementation Log

#### 2026-03-12 — Rewrote buff timer handler in global_npc.lua

**What:** Replaced the nested-loop CastSpell approach (lines 403-524) with a two-phase sequential queue. Phase 1 builds a JSON queue of `[spell_id, target_id]` pairs and stores it in entity variables. Phase 2 (every subsequent timer fire) pops one entry, casts one spell, re-arms timer for 2000ms, and stops when the queue is exhausted.

**Where:** `akk-stack/server/quests/global/global_npc.lua`, lines 403-524 (the `buff_request_` timer handler block)

**Why:** CastSpell() checks `casting_spell_id != 0` and returns false if already casting. All but the first call in the original nested loop silently failed. The queue ensures only one CastSpell per tick.

**Notes:**
- Used `require("json")` for queue serialization — already in lua_modules
- Target validity re-checked each tick via `eq.get_entity_list():GetMobByID(target_id)` — handles member death/zone between ticks
- Timer re-armed at 2000ms per entry — same interval as original retry loop
- Queue build + first entry processed in same tick (Phase 1 calls the process step inline) to avoid unnecessary 2s gap
- All entity vars cleaned up on completion or abandonment: `buff_request_target`, `buff_request_retries`, `buff_queue`, `buff_queue_idx`
- Existing `IsEngaged()` / `IsCasting()` guard preserved — if companion enters combat while queue is mid-flight, it waits and retries (retries counter increments)

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/global/global_npc.lua` | Modified | Buff timer handler rewritten as sequential queue |
| `claude/project-work/feature/companion-behavior-improvements/status.md` | Modified | Task 4 marked Complete |
| `claude/project-work/feature/companion-behavior-improvements/lua-expert/dev-notes.md` | Modified | All stages documented |

---

## Open Items

- [ ] Open question in status.md: "Does CastSpell work for NPC-to-NPC beneficial spells?" — flagged for game-tester. If it rejects NPC targets, the fallback is `SpellFinished()` but that bypasses mana/resist checks.

---

## Context for Next Agent

Task 4 is complete. The buff timer handler in `global_npc.lua` now processes one (spell, target) pair per 2-second timer tick using a JSON queue stored in entity variables `buff_queue` and `buff_queue_idx`. The fix is in the `buff_request_<id>` timer block (~lines 403-530). The companion.lua cmd_buffs/cmd_buffme functions were not modified — they correctly set `buff_request_target` and start the initial timer.

If game-tester finds that NPC-to-NPC buffing still doesn't work, the fallback approach is to replace `e.self:CastSpell(spell_id, target_id, 7)` with `e.self:SpellFinished(spell_id, target)` but note this bypasses mana cost and resist checks.
