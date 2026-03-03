# BUG-001 Triage: Companion Context Not Shifting Identity

**Architect:** architect
**Date:** 2026-03-03
**Status:** Diagnosed — fix plan ready

---

## Bug Summary

Recruited NPC companion (Guard Liben, Qeynos guard) responds with boilerplate NPC dialogue instead of companion-framed responses. The debug log confirms the LLM bridge fires and gets a response (`response OK for NPC Guard Liben player=Chelon`), but the dialogue is standard NPC, not companion-aware.

## Diagnosis

### Root Cause: Silent pcall error swallowing in `llm_bridge.lua:154-166`

The companion context integration in `llm_bridge.build_context()` uses nested pcalls that **silently swallow ALL errors with zero logging**:

```lua
-- llm_bridge.lua lines 154-166
if e.self:IsCompanion() then
    local ok, comp_ctx_lib = pcall(require, "companion_context")
    if ok and comp_ctx_lib then
        local ok2, companion_fields = pcall(function()
            return comp_ctx_lib.build(e.self, e.other)
        end)
        if ok2 and companion_fields then
            for k, v in pairs(companion_fields) do
                context[k] = v
            end
        end
    end
end
```

**Failure chain:**
1. If `pcall(require, "companion_context")` returns `ok=false` → module load error → silently ignored
2. If `pcall(comp_ctx_lib.build(...))` returns `ok2=false` → build error → silently ignored  
3. In EITHER case: `context.is_companion` remains `nil`
4. In `generate_response()` line 216: `is_companion = context.is_companion or false` → sends `false`
5. Sidecar receives `is_companion=false` → generates standard NPC dialogue
6. Log shows `response OK` because the sidecar DID respond (just without companion framing)

**There is NO error logging when either pcall fails.** This is the core diagnostic gap.

### Contributing Bug #1: Database method case mismatch in `companion_context.lua:124-131`

The `get_recruited_zone_name()` function uses PascalCase method names:
```lua
local db = Database()
local stmt = db:Prepare(...)       -- WRONG: registered as "prepare" (lowercase)
stmt:Execute({zone_id})             -- WRONG: registered as "execute"
local row = stmt:FetchHash()        -- WRONG: registered as "fetch_hash" (snake_case)
db:Close()                          -- WRONG: registered as "close"
```

The luabind registration in `lua_database.cpp:199-209` uses lowercase:
```cpp
.def("close", &Lua_Database::Close)
.def("prepare", &Lua_Database::Prepare, ...)
.def("execute", ...)
.def("fetch_hash", &Lua_MySQLPreparedStmt::FetchHash)
```

**Lua is case-sensitive.** `db:Prepare()` calls a nil method → throws → caught by pcall → falls back to "unknown"/"an unknown land" for recruited zone. 

This bug alone does NOT cause the main issue — `get_recruited_zone_name()` is wrapped in its own pcall inside `build()`, so the function continues. But the recruited zone data is always wrong ("unknown" instead of the actual recruited zone).

### Contributing Bug #2: Function name mismatch in `companion_culture.lua`

Line 500 calls:
```lua
return companion_culture._get_self_preservation_context(npc_race)
```

But line 546 defines:
```lua
function companion_culture.get_self_preservation_context(npc_race, companion_type)
```

The underscore prefix `_get_self_preservation_context` is not defined — this would throw if a mercenary companion enters self-preservation mode. Not related to the current bug path (only triggers during combat), but should be fixed.

### What I Could NOT Determine Without Runtime Testing

The static analysis confirms the pcall error-swallowing mechanism is the proximate cause. However, I cannot determine the SPECIFIC error being thrown without adding diagnostic logging and testing in-game. The candidates are:

1. **Module load failure** — `require("companion_context")` fails (dependency chain issue with `companion_culture`, caching, path resolution)
2. **`build()` runtime error** — A method call inside `companion_context.build()` throws (e.g., `GetCompanionType()`, `GetStance()`, or any companion_culture function call)
3. **Luabind type confusion** — The `e.self` Lua_Companion object somehow loses its type when passed through the pcall closure

## Fix Plan

### Fix 1 (CRITICAL): Add error logging to companion context pcalls

**File:** `akk-stack/server/quests/lua_modules/llm_bridge.lua` (lines 154-166)
**Agent:** lua-expert

Add `eq.log()` calls when either pcall fails. This will immediately reveal the actual error:

```lua
if e.self:IsCompanion() then
    local ok, comp_ctx_lib = pcall(require, "companion_context")
    if not ok then
        eq.log(87, "llm_bridge: companion_context require failed: " .. tostring(comp_ctx_lib))
    elseif comp_ctx_lib then
        local ok2, companion_fields = pcall(function()
            return comp_ctx_lib.build(e.self, e.other)
        end)
        if not ok2 then
            eq.log(87, "llm_bridge: companion_context.build failed: " .. tostring(companion_fields))
        elseif companion_fields then
            for k, v in pairs(companion_fields) do
                context[k] = v
            end
        end
    end
end
```

This is the **most important fix** — it transforms a silent failure into a diagnosable error. After deploying this and testing in-game, the server log will tell us exactly which error is occurring, enabling targeted repair.

### Fix 2: Fix Database method case in `companion_context.lua`

**File:** `akk-stack/server/quests/lua_modules/companion_context.lua` (lines 124-131)
**Agent:** lua-expert

Change PascalCase to lowercase/snake_case:
```lua
local db = Database()
local stmt = db:prepare(...)       -- lowercase
stmt:execute({zone_id})             -- lowercase
local row = stmt:fetch_hash()       -- snake_case
db:close()                          -- lowercase
```

### Fix 3: Fix function name mismatch in `companion_culture.lua`

**File:** `akk-stack/server/quests/lua_modules/companion_culture.lua` (line 500)
**Agent:** lua-expert

Either:
- Rename the call at line 500 to match the definition: `companion_culture.get_self_preservation_context(npc_race)`
- Or rename the definition at line 546 to use the underscore prefix to match the call

### Fix 4: Defensive logging in `companion_context.build()`

**File:** `akk-stack/server/quests/lua_modules/companion_context.lua`
**Agent:** lua-expert

Add basic validation at the top of `build()` to catch the most likely failures:
```lua
function companion_context.build(npc, client)
    if not npc then
        eq.log(87, "companion_context.build: npc is nil")
        return nil
    end
    -- Verify companion methods are accessible
    local ok_ct, ct = pcall(function() return npc:GetCompanionType() end)
    if not ok_ct then
        eq.log(87, "companion_context.build: GetCompanionType failed: " .. tostring(ct))
        -- Fall through with defaults rather than returning nil
    end
    -- ... rest of function
end
```

## Implementation Order

1. **Deploy Fix 1 first** (error logging in llm_bridge.lua) → `#reloadquests` → test in-game
2. Read the server log to identify the exact error
3. Apply Fix 2 and Fix 3 (known bugs) regardless of what Fix 1 reveals
4. If Fix 1 reveals a different root cause, apply Fix 4 or additional targeted fixes
5. Test end-to-end: speak to companion, verify `is_companion=true` reaches sidecar

## Files Affected

| File | Change | Priority |
|------|--------|----------|
| `akk-stack/server/quests/lua_modules/llm_bridge.lua` | Add error logging to pcalls (lines 154-166) | CRITICAL |
| `akk-stack/server/quests/lua_modules/companion_context.lua` | Fix Database method case (lines 124-131) | HIGH |
| `akk-stack/server/quests/lua_modules/companion_culture.lua` | Fix function name mismatch (line 500) | MEDIUM |
| `akk-stack/server/quests/lua_modules/companion_context.lua` | Add defensive validation in build() | LOW (may not be needed after Fix 1) |

All fixes are Lua-only — hot-reloadable via `#reloadquests`, no server rebuild needed.

## Verified Code Path

Traced the full event flow from player speech to sidecar response:

1. Player says text to companion NPC
2. `lua_parser.cpp:509` → `e.self` set as `Lua_Companion` (not `Lua_NPC`)
3. `global_npc.lua:event_say(e)` fires
4. Line 11: `e.self:IsCompanion()` → true, message not `!`-prefixed → falls through
5. Line 27: `llm_bridge.is_eligible(e)` → line 65 returns true immediately for companions
6. Line 35: `e.other:GetFaction(e.self)` (via `client_ext.lua:64`) → works (CastToNPC handles companion)
7. Line 53: thinking indicator sent
8. Line 56: `llm_bridge.build_context(e)` → **HERE is where companion context should be merged**
9. Lines 154-166: companion context pcall(s) → **FAILING SILENTLY**
10. Line 216: `is_companion = context.is_companion or false` → sends `false` to sidecar
11. Sidecar responds with standard NPC dialogue
12. Line 298: `response OK` logged → confirms sidecar responded

## Key Architectural Note

The `Lua_Companion` class inherits from `Lua_Mob` (NOT `Lua_NPC`). This is by design:
- `Lua_Mob` methods (GetRace, GetClass, GetLevel, etc.) ARE available on companions
- `Lua_NPC` methods (GetPrimaryFaction, etc.) are NOT available → handled via pcall workarounds
- `Lua_Entity` methods (IsCompanion, CastToNPC, etc.) ARE available (resolved through chain)
- `Lua_Companion` own methods (GetCompanionType, GetStance, GetTimeActive, etc.) ARE available

The C++ rebuild completed successfully with `GetTimeActive()` and `GetRecruitedZoneID()` bindings.
