# Universal NPC LLM Speech — Architecture Plan

> **Feature:** Make every eligible NPC able to have LLM conversations regardless of local quest scripts
> **Scope:** Lua-only changes (llm_bridge.lua, global_npc.lua)
> **Author:** architect
> **Date:** 2026-02-26
> **Status:** Complete

---

## 1. Problem Statement

The current `has_local_script()` function in `llm_bridge.lua` (lines 12-22) checks
whether any file exists at `quests/<zone>/<NPC_Name>.lua` or `.pl`. If a file exists,
the NPC is blocked from LLM speech entirely.

This is too coarse. Across the quest repository:

| Metric | Count |
|--------|-------|
| Total Lua NPC scripts | 3,748 |
| Lua scripts WITHOUT `event_say` | 1,922 (51%) |
| Total Perl NPC scripts | 3,607 |
| Perl scripts WITHOUT `EVENT_SAY` | 1,170 (32%) |
| **Total silenced NPCs that could speak** | **~3,092** |

Example: `Guard_Calik.lua` defines only `event_combat` (a one-line "Time to die!"
taunt). The guard has no dialogue, no say handler, no keywords — yet `has_local_script()`
finds the file and blocks LLM speech for this guard.

The fix must distinguish between:
- **Scripts with `event_say`**: Local handler exists and may produce responses. LLM must
  defer to avoid double responses.
- **Scripts without `event_say`**: File exists for combat/spawn/signal/waypoint only. No
  dialogue handler. LLM should be allowed.

## 2. Root Cause: The Double-Fire Problem

EQEmu's C++ event dispatch (`quest_parser_collection.cpp:475-501`) calls **all three**
event handlers unconditionally:

```cpp
int QuestParserCollection::EventNPC(...) {
    const int local_return   = EventNPCLocal(...);   // always runs
    const int global_return  = EventNPCGlobal(...);  // always runs
    const int default_return = DispatchEventNPC(...); // always runs (encounters)
    // return values determine which result propagates, but all three executed
}
```

This means when a player says something to any NPC:
1. `EventNPCLocal` fires the NPC's local script `event_say` (if it has one)
2. `EventNPCGlobal` fires `global_npc.lua:event_say` (always, since it's defined there)
3. Both produce responses → player sees double messages

The original `has_local_script()` was a blunt instrument to prevent this: if the NPC has
any script file at all, assume it might have `event_say` and skip the LLM. This worked
when only a few NPCs had scripts, but it silences 3,092+ NPCs unnecessarily.

## 3. Solution: Replace File-Existence with Function-Existence Check

### Core Idea

Instead of checking whether a **file** exists, check whether the NPC's loaded script
package has an `event_say` **function** registered in the Lua runtime.

### How It Works

EQEmu's Lua parser stores each loaded script in the Lua registry under the key
`npc_<npc_type_id>` (see `lua_parser.cpp:499,909`). The C++ `HasFunction()` method
(line 1288) probes this registry to check if a function name exists in a package.

From global_npc.lua, we can do the same thing from Lua:

```lua
local function local_script_has_say(npc_type_id)
    local reg = debug.getregistry()
    local pkg = reg["npc_" .. npc_type_id]
    if pkg and type(pkg.event_say) == "function" then
        return true
    end
    return false
end
```

**Why this works:**
- `EventNPCLocal` runs BEFORE `EventNPCGlobal` in the C++ dispatch (line 488-489)
- `EventNPCLocal` loads the script on-demand if not already loaded (lines 519-526)
- By the time `global_npc.lua:event_say` executes, the local script is already loaded
  into the Lua registry
- So the registry probe is guaranteed to see the local script's functions

**Why this is safe:**
- `debug.getregistry()` is a read-only introspection call
- It accesses the same Lua state (`L`) that the parser uses
- It does not modify any state, trigger any side effects, or cross security boundaries
- It mirrors exactly what the C++ `HasFunction()` does

### Handling Perl Scripts

For NPCs with Perl scripts (no Lua equivalent), the Lua registry has no entry. In
these cases, we fall back to file scanning with caching:

1. Check if a `.pl` file exists for the NPC (same as current `has_local_script`)
2. If it exists, read the file and search for `EVENT_SAY` or `sub EVENT_SAY`
3. Cache the result in a module-level table keyed by `npc_type_id`

**Why caching is necessary:** `io.open` + `read("*a")` on every say event would be too
slow. The cache persists until `#reloadquest` (which reloads all Lua modules including
llm_bridge, resetting the cache). This is correct behavior — if a quest author adds
`EVENT_SAY` to a Perl script, they also `#reloadquest`, which clears the cache.

**Why file scanning is acceptable for Perl:** Unlike Lua, where we have direct
runtime introspection, Perl scripts live in a separate interpreter (`PerlembParser`).
There is no cross-interpreter API to probe Perl package contents from Lua. File
scanning is the only option without C++ changes.

### Combined Check: `has_local_say_handler()`

The new function replaces `has_local_script()`:

```lua
local _perl_say_cache = {}

local function has_local_say_handler(e)
    local npc_id = e.self:GetNPCTypeID()

    -- 1. Check Lua registry: does this NPC's loaded script have event_say?
    local reg = debug.getregistry()
    local pkg = reg["npc_" .. npc_id]
    if pkg then
        -- Lua script is loaded for this NPC
        if type(pkg.event_say) == "function" then
            return true   -- local Lua event_say exists, skip LLM
        else
            return false  -- Lua script loaded, but no event_say (e.g., combat only)
        end
    end

    -- 2. No Lua script loaded. Check for Perl script with EVENT_SAY (cached).
    if _perl_say_cache[npc_id] ~= nil then
        return _perl_say_cache[npc_id]
    end

    local zone = eq.get_zone_short_name()
    local name = e.self:GetCleanName():gsub(" ", "_")
    local pl_path = "/home/eqemu/server/quests/" .. zone .. "/" .. name .. ".pl"
    local f = io.open(pl_path, "r")
    if f then
        local content = f:read("*a")
        f:close()
        local has_say = content:find("EVENT_SAY") ~= nil
        _perl_say_cache[npc_id] = has_say
        return has_say
    end

    -- 3. No local script at all → LLM is allowed
    _perl_say_cache[npc_id] = false
    return false
end
```

### Where the Check Goes

In `llm_bridge.is_eligible()`, replace the `has_local_script(e)` call with
`has_local_say_handler(e)`:

```lua
function llm_bridge.is_eligible(e)
    if not config.enabled then return false end

    -- Skip NPCs whose local script already handles event_say
    if has_local_say_handler(e) then return false end

    -- Sentience filter: low-INT creatures do not speak
    if e.self:GetINT() < config.min_npc_intelligence then return false end

    -- Body type filter: non-sentient creature types excluded
    local body_type = e.self:GetBodyType()
    if config.excluded_body_types[body_type] then return false end

    -- Per-NPC opt-out: data bucket "llm_enabled-{npc_type_id}" = "0" disables
    local opt_out = eq.get_data("llm_enabled-" .. e.self:GetNPCTypeID())
    if opt_out == "0" then return false end

    return true
end
```

## 4. Files Modified

| File | Change | Scope |
|------|--------|-------|
| `akk-stack/server/quests/lua_modules/llm_bridge.lua` | Replace `has_local_script()` with `has_local_say_handler()` | ~30 lines changed |
| `akk-stack/server/quests/global/global_npc.lua` | No changes needed | None |

Only ONE file changes. `global_npc.lua` remains untouched — its `event_say` handler
already calls `llm_bridge.is_eligible(e)`, which will now use the improved check.

## 5. Behavior Matrix

| NPC Scenario | Old Behavior | New Behavior |
|-------------|-------------|-------------|
| No local script, eligible | LLM responds | LLM responds (unchanged) |
| No local script, ineligible (low INT) | Silent | Silent (unchanged) |
| Local script with `event_say` only | Silent (correct) | Silent (correct, unchanged) |
| Local script with `event_combat` only | **Silent (WRONG)** | **LLM responds (FIXED)** |
| Local script with `event_signal` only | **Silent (WRONG)** | **LLM responds (FIXED)** |
| Local script with `event_spawn` only | **Silent (WRONG)** | **LLM responds (FIXED)** |
| Local script with `event_trade` only | **Silent (WRONG)** | **LLM responds (FIXED)** |
| Local script with `event_say` + `event_combat` | Silent (correct) | Silent (correct, unchanged) |
| Tier 2 script (Captain_Tillin) with LLM fallback | Silent via global, LLM via local | Silent via global, LLM via local (unchanged) |
| Perl script with `EVENT_SAY` | Silent (correct) | Silent (correct, unchanged) |
| Perl script without `EVENT_SAY` | **Silent (WRONG)** | **LLM responds (FIXED)** |

## 6. Edge Cases and Risks

### Risk 1: Double response from scripted NPCs with partial event_say

**Scenario:** An NPC's local `event_say` handles "hail" but not other keywords.
Player says "hail" → local handler responds. Player says "weather" → local handler
does nothing, global handler fires, LLM responds.

**This is correct behavior.** The local script's event_say function fires first and
handles "hail". Global fires next — but since the local script has event_say,
`has_local_say_handler()` returns true and the LLM is skipped. The NPC stays silent
for "weather" (unless the local script has its own LLM fallback, like Tier 2 scripts).

**Wait** — re-reading the flow: if `has_local_say_handler()` returns true, the LLM
is skipped in global_npc.lua. This means for NPC Guard_Beren (who has `event_say`
handling "hail" and "dwarf"), saying something off-keyword like "weather" will result
in silence. This is **by design** — the local script owns the NPC's speech, and if
it doesn't handle a message, the NPC stays silent. Only Tier 2 scripts (which
explicitly opt into LLM fallback in their own event_say) get LLM responses for
off-keyword speech.

### Risk 2: Lua registry structure changes in future EQEmu versions

**Likelihood:** Very low. The `npc_<id>` package naming has been stable since Lua
quest support was added. The registry approach mirrors exactly what the C++ code does.

**Mitigation:** If the naming convention changes, the check will fail safe — it
will not find the package, will check for Perl, find none, and allow LLM (safe
because the NPC has no say handler anyway).

### Risk 3: Performance of Perl file scanning

**Likelihood:** Low impact. File scanning only occurs for NPCs in zones with Perl
scripts (not Lua). The result is cached per NPC type ID for the duration of the
Lua module's lifetime. The cache clears on `#reloadquest`.

**Worst case:** First time each Perl-scripted NPC is spoken to, there's a single
file read. Subsequent interactions use the cache. The I/O is local filesystem (not
network), and the files are small (<10KB typically).

### Risk 4: NPC name mismatch between clean name and file name

**Scenario:** An NPC's clean name doesn't match the script filename due to special
characters or backtick-to-hyphen conversion.

**Analysis:** This is the same name-resolution logic used by the existing
`has_local_script()` function. The Perl file scan uses the same path construction.
If the current check works (and it does — it correctly finds Guard_Calik.lua), the
new check will work identically for the Perl fallback path.

For the Lua registry probe, there's no name issue at all — it uses `npc_type_id`
(a numeric ID), not the NPC name.

### Risk 5: What about NPC ID-based scripts (e.g., `1173.lua`)?

**Analysis:** The Lua registry stores scripts by NPC type ID (`npc_1173`), not by
filename. When the C++ parser loads `1173.lua`, it registers it under `npc_1173`.
The registry probe uses `e.self:GetNPCTypeID()` which returns the same numeric ID.
So ID-based scripts are handled correctly by the Lua probe.

For Perl ID-based scripts (e.g., `48030.pl`), the file-scan fallback currently only
checks by NPC name. We should add an ID-based path check:

```lua
-- Check name-based path
local pl_path_name = base .. "/" .. name .. ".pl"
-- Check ID-based path
local pl_path_id = base .. "/" .. npc_id .. ".pl"
```

### Risk 6: Race condition between EventNPCLocal and EventNPCGlobal

**Analysis:** No race condition exists. The C++ code calls `EventNPCLocal` first,
which synchronously loads the script and executes the event handler. Only after it
returns does `EventNPCGlobal` execute. Since Lua is single-threaded and the calls
are sequential, the registry is guaranteed to be populated before the global
handler probes it.

## 7. Tier 2 Script Interaction

Tier 2 scripts (like `Captain_Tillin.lua`) have their own `event_say` with LLM
fallback built in. Under the new system:

1. `has_local_say_handler()` finds `event_say` in the Lua registry → returns true
2. `is_eligible()` returns false
3. `global_npc.lua:event_say` does nothing (correct — no double response)
4. Captain Tillin's own `event_say` handles keywords and falls back to LLM for
   off-keyword text via `llm_bridge.build_quest_context()`

This is exactly the desired behavior. No change needed to Tier 2 scripts.

## 8. Implementation Details

### Full replacement code for `llm_bridge.lua`

Replace lines 11-22 (the `has_local_script` function) with the new
`has_local_say_handler` function (~35 lines). Update `is_eligible()` to call the
new function. All other functions in `llm_bridge.lua` remain unchanged.

### Testing checklist

1. **Guard_Calik** (combat-only script): should now respond to "hail" via LLM
2. **Guard_Phaeton** (signal-only script): should now respond to "hail" via LLM
3. **Guard_Beren** (has event_say): should still respond via scripted dialogue, NOT LLM
4. **Captain_Tillin** (Tier 2 with LLM fallback): unchanged behavior
5. **Unscripted NPC** (no local file at all): unchanged behavior
6. **Low-INT NPC** (e.g., rats): should remain silent regardless of script status
7. **Perl-scripted NPC with EVENT_SAY**: should use scripted dialogue, not LLM
8. **Perl-scripted NPC without EVENT_SAY**: should now respond via LLM

### Deployment

1. Edit `llm_bridge.lua` on host (akk-stack/server/quests/lua_modules/)
2. In-game: `#reloadquest` (clears Lua module cache, reloads all scripts)
3. Test immediately — no server restart, no build, no database changes

## 9. Summary

**One file changes.** The fix replaces a file-existence check with a function-existence
check using the Lua runtime registry, with a file-scan fallback for Perl scripts. This
unblocks ~3,092 NPCs that have scripts for non-speech events (combat, signals, spawns,
waypoints, trades) without disrupting any NPC that has a genuine speech handler.

The change is:
- **Zero C++ changes** — pure Lua
- **Zero database changes** — no schema or data modifications
- **Zero config changes** — no rules, no .env, no docker-compose
- **Zero risk to existing scripts** — NPCs with event_say remain untouched
- **Hot-deployable** — `#reloadquest` applies it instantly
- **Reversible** — revert the one file to restore old behavior
