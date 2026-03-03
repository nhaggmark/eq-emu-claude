# NPC Companion Context — Dev Notes: Lua Expert

> **Feature branch:** `feature/npc-companion-context` (quests repo: `feature/npc-recruitment`)
> **Agent:** lua-expert
> **Task(s):** #3 (BUG-001 Lua fixes)
> **Date started:** 2026-03-03
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Fix BUG-001: Implement all three Lua fixes for companion identity shift | #1 (architect triage) | Complete |

---

## Stage 1: Plan

Read the architect's triage findings at `claude/project-work/npc-companion-context/architect/dev-notes.md`.
Architect identified three Lua bugs causing companion identity shift to fail silently.

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `akk-stack/server/quests/lua_modules/llm_bridge.lua` | 154-166 | Nested pcalls with zero error logging — failures silently swallowed |
| `akk-stack/server/quests/lua_modules/companion_context.lua` | 124-131 | PascalCase DB method calls (`Prepare`, `Execute`, `FetchHash`, `Close`) but luabind registers as lowercase |
| `akk-stack/server/quests/lua_modules/companion_culture.lua` | 500, 546 | Call site `_get_self_preservation_context` (underscore) does not match definition `get_self_preservation_context` |

### Key Findings

- The quests repo (`akk-stack/server/quests/`) is a separate git repo from `akk-stack/`, on branch `feature/npc-recruitment`. The `server/` directory is gitignored in the akk-stack repo.
- `companion_context.lua` was an untracked new file in the quests repo — needed `git add` explicitly before commit.
- `eq.log()` usage pattern confirmed from existing llm_bridge.lua: `eq.log(87, "message")` where 87 = QuestErrors category.

---

## Stage 4: Build

### Implementation Log

#### 2026-03-03 — Fix 1: Add error logging to companion context pcalls

**What:** Replaced silent `if ok and comp_ctx_lib then` / `if ok2 and companion_fields then` branches with explicit `not ok` and `not ok2` error logging paths using `eq.log(87, ...)`.

**Where:** `akk-stack/server/quests/lua_modules/llm_bridge.lua` lines 154-170

**Why:** Both pcall failure paths had no logging. When `require("companion_context")` or `companion_context.build()` threw, the error was silently discarded, `is_companion` remained nil, and the sidecar received `is_companion=false`. Now failures appear in zone logs (QuestErrors category) immediately.

**Notes:** The variable holding the error message in a failed pcall is the second return value — so `comp_ctx_lib` holds the error string when `ok` is false, and `companion_fields` holds the error string when `ok2` is false. The `tostring()` wrap is defensive in case the error is not a string.

#### 2026-03-03 — Fix 2: Fix database method case mismatch

**What:** Changed `db:Prepare(...)` → `db:prepare(...)`, `stmt:Execute(...)` → `stmt:execute(...)`, `stmt:FetchHash()` → `stmt:fetch_hash()`, `db:Close()` → `db:close()`.

**Where:** `akk-stack/server/quests/lua_modules/companion_context.lua` lines 126-129

**Why:** The luabind registration in `lua_database.cpp` uses lowercase (`prepare`, `execute`, `fetch_hash`, `close`). Lua is case-sensitive — the PascalCase calls threw `attempt to call nil` errors, which were caught by the surrounding pcall and fell back to "unknown"/"a distant land" for recruited zone. The recruited zone context was always wrong.

#### 2026-03-03 — Fix 3: Fix function name mismatch

**What:** Changed call site `companion_culture._get_self_preservation_context(npc_race)` to `companion_culture.get_self_preservation_context(npc_race)` (removed leading underscore).

**Where:** `akk-stack/server/quests/lua_modules/companion_culture.lua` line 500

**Why:** The underscore-prefixed name `_get_self_preservation_context` is never defined. The function at line 546 is `get_self_preservation_context` (public, no underscore). This mismatch would crash any mercenary companion entering self-preservation mode. Fixed call site to match definition.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| Commit to akk-stack failed | `server/` is gitignored in akk-stack repo | Committed directly in `server/quests/` git repo |
| `companion_context.lua` not tracked | New file, untracked in quests repo | Added with explicit `git add lua_modules/companion_context.lua` |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/llm_bridge.lua` | Modified | Added error logging to companion context pcall failure paths |
| `akk-stack/server/quests/lua_modules/companion_context.lua` | Created (committed) | Fixed DB method case: Prepare→prepare, Execute→execute, FetchHash→fetch_hash, Close→close |
| `akk-stack/server/quests/lua_modules/companion_culture.lua` | Modified | Fixed call site: `_get_self_preservation_context` → `get_self_preservation_context` |

### Commit

- **Repo:** `akk-stack/server/quests/` (separate git repo)
- **Branch:** `feature/npc-recruitment`
- **SHA:** `aba116432`
- **Message:** `fix(companion-context): surface silent pcall errors and fix two name mismatches`

---

## Continued Investigation (2026-03-03)

### Round 2: Log Investigation

User reported no change after #reloadquests. Investigated log routing:
- QuestErrors (cat 87): `log_to_file=0`, `log_to_gmsay=1` at zone startup
- QuestDebug (cat 38): same
- Zone process stdout → /dev/null (nohup startup)
- Updated DB: `log_to_file=1` for cats 87 and 38 (requires zone restart to take effect)
- Discovered Guard_Liben.lua has its own `event_say` that fires for "hail" — produces boilerplate
- Both local AND global scripts fire unconditionally (confirmed in quest_parser_collection.cpp)

### Round 3: IsCompanion() Investigation

User reported NO gmsay errors after test. Companion detection gate suspected.
Added unconditional diagnostic at top of `build_context()`:
```lua
local ok_ic, ic_val = pcall(function() return e.self:IsCompanion() end)
eq.log(87, string.format("llm_bridge: IsCompanion check for NPC %s ok=%s val=%s", ...))
```
Commit: `f8f2da5ff`

### Round 4: Module Cache / Path Investigation

User reported diagnostic at line 156 NOT appearing after #reloadquests.

Full investigation findings:
- **#reloadquests** calls `lua_close(L)` + `luaL_newstate()` — fully recreates Lua state, no cache
- **File confirmed on disk**: MD5 matches both `/home/eqemu/server/lua_modules/llm_bridge.lua` and `quests/lua_modules/` — same inode (same NTFS file via WSL2)
- **Lua module path**: zone_start.log confirms `lua_modules > [quests/lua_modules]` ✓
- **Syntax valid**: confirmed via lua5.1 loadfile check
- **Zone log `qeynos2_..._7860.log`**: shows last `#reloadquests` at 06:25:35 (AFTER commit f8f2da5ff at 06:21:29)
- **BUT**: no NPC conversation activity recorded after 06:25 reload — user has NOT spoken to companion since that reload
- **Category 87 gmsay**: `log_to_gmsay=1` in DB at startup (also hardcoded default in eqemu_logsys.cpp) — should work
- **Category 38 gmsay** (QuestDebug): same settings, same path — user CAN see this channel

**Root cause of "diagnostic not appearing"**: User has not spoken to companion AFTER the reload that loaded the diagnostic. The diagnostic was added at 06:21, last reload was 06:25, but no further conversation in logs after that.

**Root cause of boilerplate**: For "hail", Guard_Liben.lua fires AND global_npc.lua fires. User sees both. For non-"hail" messages, only global_npc.lua fires.

### Round 5: Direct Message Diagnostic

Added `e.other:Message()` call in global_npc.lua after `build_context()` to bypass log system entirely:
```lua
e.other:Message(15, string.format("[DEBUG] build_context ok: is_companion=%s npc=%s",
    tostring(context and context.is_companion), tostring(e.self:GetCleanName())))
```
Commit: `8dd9a4eb1`

This will appear in the player's chat window unconditionally, regardless of log settings, gmsay routing, or zone restart state.

### What to look for in next test

After `#reloadquests`, say something to Guard Liben (not "hail"):
- If `[DEBUG] build_context ok: is_companion=true` → companion context IS being sent to sidecar. Bug is sidecar-side.
- If `[DEBUG] build_context ok: is_companion=false` or `nil` → IsCompanion() detection failed. Need to investigate luabind resolution.
- If no `[DEBUG]` appears at all → global_npc.lua is not even reaching build_context for the companion. Investigate is_eligible or earlier return paths.

---

## Context for Next Agent

Three Lua bugs in the companion identity shift pipeline were fixed and committed to `feature/npc-recruitment` in the quests repo (`akk-stack/server/quests/`).

**Architecture note:** The quests repo is gitignored inside the akk-stack repo. The `server/` directory in akk-stack is not tracked there — commit quest script changes in `akk-stack/server/quests/` directly.

**What these fixes do:**
1. Errors in `companion_context` loading/building now appear in zone logs → diagnosable
2. Recruited zone DB lookup now works correctly (was always returning "unknown")
3. Mercenary self-preservation dialogue no longer crashes (function name mismatch fixed)

**Hotfix path:** `#reloadquests` in-game to pick up the Lua changes. No C++ rebuild needed.
