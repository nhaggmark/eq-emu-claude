# Recruited NPC Controls — Dev Notes: Lua Expert

> **Feature branch:** `feature/recruited-npc-controls`
> **Agent:** lua-expert
> **Task(s):** Task 2 (companion.lua refactor) + Task 3 (global_npc.lua prefix routing)
> **Date started:** 2026-02-28
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Refactor `companion.lua`: remove keyword system, add `!` prefix dispatch with 14 handlers | — | In Progress |
| 3 | Update `global_npc.lua`: replace keyword interception with prefix check | Task 2 | Pending |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | 534 | Has MANAGE_KEYWORDS table (lines 34-40), `is_management_keyword()` (93-101), `handle_command()` (408-447), and sub-handlers (449-494). Recruitment system (RECRUIT_KEYWORDS, `is_recruitment_keyword()`, `attempt_recruitment()`) must remain untouched. |
| `akk-stack/server/quests/global/global_npc.lua` | 88 | Lines 11-13 are the companion keyword interception block. Lines 16-21 are the recruitment check (unchanged). Requires only replacing lines 11-13 with prefix check. |
| `claude/project-work/feature/recruited-npc-controls/architect/architecture.md` | 794 | Complete implementation spec with code sketches for all 14 handlers. Verified all required Lua bindings exist. |
| `claude/project-work/feature/recruited-npc-controls/lore-master/lore-notes.md` | 136 | Two required phrase corrections: (1) balanced stance split by companion_type; (2) combat commands use "I see your target." / "I will assist." |

### Key Findings

1. **companion.lua structure:** The file has two clearly separated systems — recruitment (lines 27-400) and management (lines 403-494). Only the management section changes. The `companion` table, module-level constants pattern, and `return companion` at EOF are the framework to preserve.

2. **Old management system to remove:** `MANAGE_KEYWORDS` table, `is_management_keyword()`, `handle_command()`, `handle_dismiss()`, `handle_stance()`, `handle_follow()`, `handle_guard()`, `handle_show_equipment()`, `handle_give_slot()`, `handle_give_all()`. These are all replaced by the prefix dispatch system.

3. **`handle_stance()` current behavior:** Calls `npc:Say("Understood. I will fight " .. stance_name .. ".")` for all stances including passive ("Understood. I will fight passive." — wrong per lore). New per-command handlers fix this.

4. **GetFollowID gap:** Architecture confirmed — track guard/follow mode in module-level `companion_modes` table keyed by NPC entity ID.

5. **Data bucket API:** `eq.get_data(key)` returns empty string if key not found (not nil). Check `on_cd and on_cd ~= ""`.

6. **Rule reading:** `eq.get_rule("Companions:RecallCooldownS")` returns string or nil. Use `tonumber(...) or 30` fallback.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modify | Remove MANAGE_KEYWORDS, is_management_keyword(), handle_command() and all sub-handlers. Add COMMAND_PREFIX constant, RECALL_MIN_DISTANCE constant, companion_modes table, COMMANDS dispatch table, dispatch_prefix_command(), and 14 cmd_* handlers. |
| `akk-stack/server/quests/global/global_npc.lua` | Modify | Replace lines 11-13 (keyword interception) with prefix check (6 lines per architecture spec). |

**Change sequence:**
1. companion.lua: Add new module-level constants (COMMAND_PREFIX, RECALL_MIN_DISTANCE, companion_modes)
2. companion.lua: Add COMMANDS dispatch table
3. companion.lua: Add `dispatch_prefix_command()` entry point
4. companion.lua: Add all 14 `cmd_*` handlers
5. companion.lua: Remove MANAGE_KEYWORDS table, `is_management_keyword()`, `handle_command()` and sub-handlers
6. global_npc.lua: Replace keyword interception block with prefix check

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `npc:SetStance(int)` | `claude/docs/topography/LUA-CODE.md` + architecture.md | Yes | Bound on Lua_Companion; 0=passive, 1=balanced, 2=aggressive |
| `npc:SetGuardMode(bool)` | architecture.md | Yes | true=hold, false=resume follow |
| `npc:Dismiss(bool)` | architecture.md companion.lua:452 | Yes | true=voluntary |
| `npc:ShowEquipment(client)` | architecture.md companion.lua:482 | Yes | Bound; formats and sends to client |
| `npc:GiveSlot(client, slot_name)` | architecture.md companion.lua:488 | Yes | Bound; slot name string |
| `npc:GiveAll(client)` | architecture.md companion.lua:493 | Yes | Bound; gives all equipped items |
| `npc:GetCompanionType()` | architecture.md | Yes | 0=loyal, 1=mercenary |
| `npc:GetStance()` | architecture.md | Yes | Returns current stance int |
| `npc:GetCompanionID()` | architecture.md | Yes | Used for recall cooldown bucket key |
| `npc:GetOwnerCharacterID()` | architecture.md | Yes | Ownership check |
| `npc:GMMove(x, y, z, heading)` | architecture.md lua_mob.h:82-84 | Yes | Intra-zone teleport |
| `npc:CalculateDistance(client)` | architecture.md lua_mob.h:297 | Yes | Returns float distance |
| `npc:SetTarget(mob)` | architecture.md lua_mob.h:130 | Yes | Sets NPC attack target |
| `npc:AddToHateList(mob, hate, dmg, ...)` | architecture.md lua_mob.h:245 | Yes | Add to hate list; use 1,0,false,false,false args |
| `client:GetTarget()` | architecture.md | Yes | Returns current target mob or nil |
| `client:CharacterID()` | companion.lua:325 | Yes | Already used in existing code |
| `client:Message(color, text)` | architecture.md | Yes | MT constants or int (15=white) |
| `npc:GetID()` | LUA-CODE.md Lua_Mob | Yes | Entity ID (not npc_type_id) — used as companion_modes key |
| `eq.get_data(key)` | companion.lua:327 | Yes | Returns "" if not found |
| `eq.set_data(key, value, expires_str)` | companion.lua:396 | Yes | TTL is string |
| `eq.get_rule(name)` | companion.lua:113 | Yes | Returns string or nil |
| `npc:GetHP()`, `GetMaxHP()`, `GetMana()`, `GetMaxMana()` | architecture.md | Yes | Standard Mob methods |
| `npc:GetLevel()`, `GetClassName()`, `GetCleanName()` | architecture.md | Yes | Standard Mob methods |

### Plan Amendments

Plan confirmed — no amendments needed. Architecture spec is authoritative and all bindings verified via source references.

One note: `npc:GetID()` returns the entity ID which is the correct key for `companion_modes` (not `GetNPCTypeID()` which would collide across different spawn instances of the same NPC type).

### Verified Plan

See Implementation Plan above — confirmed by research.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| team-lead | Plan review | Architecture already socialized — team-lead dispatched Task 2 with full spec; no additional questions. |

### Feedback Received

Architecture.md from architect is the consensus plan — it incorporates lore-master corrections, config-expert rule advice, and protocol-agent prefix audit. No new feedback needed.

### Consensus Plan

**Agreed approach:** Follow architecture.md exactly. The architect's code sketches in the architecture doc are authoritative.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modify | Replace management section with prefix dispatch system |
| `akk-stack/server/quests/global/global_npc.lua` | Modify | Replace keyword interception with prefix check |

**Change sequence (final):**
1. Replace management section in companion.lua (remove old, add new)
2. Update global_npc.lua prefix routing
3. Commit to feature branch

---

## Stage 4: Build

### Implementation Log

#### 2026-02-28 — Refactor companion.lua management section

**What:** Removed MANAGE_KEYWORDS table, `is_management_keyword()`, `handle_command()`,
`handle_dismiss()`, `handle_stance()`, `handle_follow()`, `handle_guard()`,
`handle_show_equipment()`, `handle_give_slot()`, `handle_give_all()`. Added COMMAND_PREFIX
constant, RECALL_MIN_DISTANCE constant, `companion_modes` table, COMMANDS dispatch table,
`dispatch_prefix_command()`, and 14 `cmd_*` handlers.

**Where:** `akk-stack/server/quests/lua_modules/companion.lua` lines 33-534 (management section)

**Why:** Architecture requires `!` prefix dispatch replacing O(n) keyword scan. Eliminates
false triggers from common English words in companion conversation.

**Notes:**
- `companion_modes` table is module-level; resets on `#reloadquests`. Default "follow" assumed.
- `GetStance() ~= 0` guards AddToHateList in target/assist — passive companions face but don't engage.
- `!unequipall` is architecture's alias for `!unequip all` but PRD spells it as `!unequip all`.
  Using separate table entry `unequipall` pointing to cmd_unequip routing "all" args for
  the `!unequipall` alias mentioned in team-lead's message.
- Dismiss: lore-master notes the existing "Farewell." is a fallback since LLM dismiss event
  handler may provide richer dialogue. Architecture keeps hardcoded "Farewell." as confirmed fallback.

#### 2026-02-28 — Update global_npc.lua for prefix routing

**What:** Replaced lines 11-13 (keyword interception block) with prefix check per architecture spec.

**Where:** `akk-stack/server/quests/global/global_npc.lua` lines 9-21

**Why:** New routing: `!` prefix → dispatch_prefix_command(); no prefix → LLM.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| `!unequipall` alias noted in task dispatch | Not in architecture COMMANDS table | Added `unequipall` as alias in COMMANDS table routing same handler as `unequip` with "all" injected |
| `!gear` alias for `!equipment` noted in task dispatch | Not in architecture COMMANDS table | Added `gear` as alias in COMMANDS table routing `cmd_equipment` |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modified | Replaced management section with prefix dispatch system |
| `akk-stack/server/quests/global/global_npc.lua` | Modified | Replaced keyword interception with prefix check |

---

## Open Items

- [ ] game-tester validation pending

---

## Context for Next Agent

Task 2 and 3 are complete. The `!` prefix system is live in companion.lua and global_npc.lua.

**Key architecture decisions implemented:**
- `companion_modes` table tracks guard/follow (resets on reload; defaults to "follow")
- Ownership check in `dispatch_prefix_command()` before any command runs
- `!target`/`!assist` only call `AddToHateList` when `GetStance() ~= 0`
- `!recall` uses data bucket TTL for cooldown; `eq.get_data()` returns "" not nil when missing
- `!equip` is deferred — shows trade instructions instead
- Balanced stance splits by `GetCompanionType()`: 0=loyal "I will fight at your side." / 1=mercenary "Understood."

**Aliases implemented:**
- `!gear` → same as `!equipment`
- `!unequipall` → same as `!unequip all`

**Recruitment system untouched:** `RECRUIT_KEYWORDS`, `is_recruitment_keyword()`,
`attempt_recruitment()`, and all recruitment sub-functions are unchanged.
