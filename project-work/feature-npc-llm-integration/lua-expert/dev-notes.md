# NPC LLM Integration — Dev Notes: lua-expert

> **Feature branch:** `feature/npc-llm-integration`
> **Agent:** lua-expert
> **Task(s):** 3 (Lua modules), 4 (global_npc.lua), 7 (integration test — later)
> **Date started:** 2026-02-23
> **Current stage:** Build (Stage 4)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Create Lua modules (llm_bridge.lua, llm_config.lua, llm_faction.lua) | — | Complete |
| 4 | Modify global_npc.lua to add event_say handler | 3 | Complete |
| 7 | Integration test: start sidecar, speak to unscripted NPC, verify response | 1, 3, 4, 5 | Not Started |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `claude/docs/topography/LUA-CODE.md` | 874 | Full event system, API namespace, module patterns, global_npc.lua description |
| `architect/architecture.md` | 863 | Complete Lua module code designs, API verification notes, dependency graph |
| `akk-stack/server/quests/lua_modules/json.lua` | 741 | JSON4Lua v1.2.1: confirmed `json.encode()` / `json.decode()` API |
| `akk-stack/server/quests/lua_modules/client_ext.lua` | 328 | Confirmed `Client:GetFaction(npc)` signature: calls GetFactionLevel with 7 params |
| `akk-stack/server/quests/global/global_npc.lua` | 31 | Existing event_spawn handler — Halloween costume system, must be preserved exactly |

### Key Findings

1. **json.encode / json.decode**: Correct API names (not json.stringify). Confirmed in json.lua lines 212 and 289.
2. **GetFaction is on Client, not Mob**: `Client:GetFaction(npc)` — so in event_say context `e.other:GetFaction(e.self)` is correct since `e.other` is the player Client.
3. **io.popen**: Confirmed available in LuaJIT per architecture doc. Standard POSIX subprocess.
4. **os.time()**: Standard Lua 5.1 function, available in LuaJIT.
5. **e.other:Message(type, text)**: Confirmed in architecture doc, sends to single client only.
6. **e.self:GetBodyType()**: Standard Mob method, returns integer body type ID.
7. **e.self:GetINT()**: Standard Mob method, returns intelligence stat.
8. **e.self:GetNPCTypeID()**: Standard NPC method, returns numeric type ID.
9. **e.self:SetEntityVariable() / GetEntityVariable()**: In-memory per-entity key-value storage.
10. **global_npc.lua coexistence**: Architecture confirmed safe — event_spawn and event_say are independent handlers.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/llm_config.lua` | Create | All tunable config values |
| `akk-stack/server/quests/lua_modules/llm_faction.lua` | Create | 9 EQ faction levels → tone + instruction |
| `akk-stack/server/quests/lua_modules/llm_bridge.lua` | Create | Core bridge: eligibility, context building, HTTP call |
| `akk-stack/server/quests/global/global_npc.lua` | Modify | Add event_say handler; preserve event_spawn exactly |

**Change sequence:**
1. Create llm_config.lua (no dependencies)
2. Create llm_faction.lua (no dependencies)
3. Create llm_bridge.lua (depends on llm_config and llm_faction via require)
4. Modify global_npc.lua (add event_say using llm_bridge; preserve event_spawn)

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `json.encode()` / `json.decode()` | json.lua source lines 212/289 | Yes | JSON4Lua v1.2.1, confirmed API names |
| `Client:GetFaction(npc)` | client_ext.lua line 64 | Yes | Method on Client object; wraps GetFactionLevel with 7 params |
| `e.other:Message(type, text)` | architecture.md line 55 + LUA-CODE.md | Yes | Speaker-only, single client delivery |
| `e.self:GetBodyType()` | LUA-CODE.md (Lua_Mob ~300 methods) | Yes | Returns integer body type ID |
| `e.self:GetINT()` | LUA-CODE.md (Lua_Mob methods) | Yes | Returns NPC intelligence stat |
| `e.self:GetNPCTypeID()` | LUA-CODE.md (Lua_NPC ~100 methods) | Yes | Returns numeric NPC type ID |
| `e.self:SetEntityVariable(key, val)` | architecture.md line 512-514 | Yes | In-memory key-value on NPC entity |
| `e.self:GetEntityVariable(key)` | architecture.md line 502 | Yes | Returns "" if not set |
| `e.other:CharacterID()` | architecture.md line 501 | Yes | Returns player character ID as integer |
| `io.popen(cmd)` | LuaJIT standard, architecture.md | Yes | Blocking; creates child process |
| `os.time()` | Lua 5.1 standard library | Yes | Returns POSIX timestamp as integer |
| `eq.get_data(key)` | LUA-CODE.md eq.* functions | Yes | Data bucket get — returns string or nil |
| `eq.get_zone_short_name()` | LUA-CODE.md eq.* functions | Yes | Returns zone short name string |
| `eq.get_zone_long_name()` | LUA-CODE.md eq.* functions | Yes | Returns zone long name string (confirmed in arch doc) |
| `math.random(n)` | Lua 5.1 standard library | Yes | Returns random int 1..n |
| `pcall(f, ...)` | Lua 5.1 standard library | Yes | Protected call, returns ok, result |

### Plan Amendments

Architecture doc provides verified, complete code. No amendments needed — the architect already resolved all open questions and verified all APIs against source. Proceeding with architecture doc code directly.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| team-lead | Task 3 starting now — no blocking issues found | Confirming I have all needed dependencies |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| team-lead | Proceed | Proceeding with architecture doc code |

### Consensus Plan

**Agreed approach:** Implement exactly per architecture doc. All APIs verified. No deviations needed.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/llm_config.lua` | Create | Config table with sidecar URL, timeouts, excluded body types, emote lists |
| `akk-stack/server/quests/lua_modules/llm_faction.lua` | Create | 9-level faction mapping (tone + instruction per level) |
| `akk-stack/server/quests/lua_modules/llm_bridge.lua` | Create | is_eligible, check_hostile_cooldown, set_hostile_cooldown, send_thinking_indicator, send_hostile_emote, build_context, generate_response |
| `akk-stack/server/quests/global/global_npc.lua` | Modify | Add event_say at top; preserve event_spawn exactly as-is |

**Change sequence (final):**
1. Create llm_config.lua
2. Create llm_faction.lua
3. Create llm_bridge.lua
4. Modify global_npc.lua

---

## Stage 4: Build

### Implementation Log

#### 2026-02-23 — Created llm_config.lua

**What:** New Lua module with all tunable configuration values for the LLM integration.
**Where:** `/mnt/d/Dev/EQ/akk-stack/server/quests/lua_modules/llm_config.lua`
**Why:** Centralizes all config in one hot-reloadable file (no C++ rules needed). Animal(21) added as safety net despite being covered by INT filter.
**Notes:** `enabled = true` flag allows disabling entire feature by setting to false and running `#reloadquest`.

#### 2026-02-23 — Created llm_faction.lua

**What:** New Lua module mapping all 9 EQ faction levels to tone/instruction pairs for system prompt injection.
**Where:** `/mnt/d/Dev/EQ/akk-stack/server/quests/lua_modules/llm_faction.lua`
**Why:** Faction-to-behavior mapping is static data, best in its own module for clarity and maintainability.
**Notes:** Level 8 (Threatening) has `max_responses = 1` to trigger cooldown after one warning. Level 9 (Scowling) has `no_verbal = true` for emote-only response.

#### 2026-02-23 — Created llm_bridge.lua

**What:** New Lua module providing the core bridge between quest scripts and the Python sidecar.
**Where:** `/mnt/d/Dev/EQ/akk-stack/server/quests/lua_modules/llm_bridge.lua`
**Why:** Encapsulates all LLM interaction logic — eligibility checking, context building, HTTP via io.popen/curl, hostile cooldown management.
**Notes:** `pcall(json.decode, result)` protects against malformed sidecar responses. `tonumber(last_time)` handles entity variable string-to-number conversion. Shell escaping: `'` escaped to `'\''` for POSIX compliance.

#### 2026-02-23 — Modified global_npc.lua

**What:** Added event_say handler alongside existing event_spawn. Added require() calls at top.
**Where:** `/mnt/d/Dev/EQ/akk-stack/server/quests/global/global_npc.lua`
**Why:** global_npc.lua is the entry point — fires for all NPCs without local scripts. event_say here catches all unscripted NPC conversations.
**Notes:** event_spawn preserved character-for-character from original. require() calls at top of file (outside functions) load modules once per script load.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| None encountered | — | — |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/llm_config.lua` | Created | All tunable LLM config values |
| `akk-stack/server/quests/lua_modules/llm_faction.lua` | Created | 9-level EQ faction → tone/instruction mapping |
| `akk-stack/server/quests/lua_modules/llm_bridge.lua` | Created | Core LLM bridge module |
| `akk-stack/server/quests/global/global_npc.lua` | Modified | Added event_say handler; event_spawn preserved |

---

## Open Items

- [ ] Task 7 (integration test) — waiting for Python sidecar (Task 1) and Docker (Task 5) to be ready

---

## Context for Next Agent

If picking up Task 7 (integration test):
1. Read `architect/architecture.md` for the 15 acceptance criteria
2. All Lua modules are in `akk-stack/server/quests/lua_modules/llm_*.lua`
3. global_npc.lua has event_say and event_spawn in `akk-stack/server/quests/global/global_npc.lua`
4. Test requires Python sidecar running (Task 1 by python-dev) and Docker overlay (Task 5 by infra-expert)
5. Reload scripts with `#reloadquest` in-game after any Lua changes
