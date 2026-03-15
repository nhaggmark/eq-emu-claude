# Companion Authenticity Phase 3-4 — Dev Notes: Lua Expert

> **Feature branch:** `feature/companion-authenticity-phase3-4`
> **Agent:** lua-expert
> **Task(s):** GAP-12, GAP-13, GAP-14
> **Date started:** 2026-03-15
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| GAP-12 | Fix commentary channel to use group chat | -- | Complete |
| GAP-13 | Add level-up LLM dialogue handler | -- | Complete |
| GAP-14 | Resolve re-recruitment bonus text vs behavior | -- | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `lua_modules/companion_commentary.lua` | 169 | Commentary fires via `check_and_speak()`. Line 159: `npc:Say(response)` — the offending public-channel call. Owner client is already resolved at line 136. |
| `global/global_npc.lua` | 659 | No `event_level_up` handler. Has `event_timer`, `event_spawn`, `event_death_zone`. Pattern for LLM calls established in `event_say`. `llm_bridge` and `llm_config` are required at top. |
| `lua_modules/companion_culture.lua` | 622 | `"level_up"` event type defined in `_get_event_prompt()` lines 458-469. `get_companion_context(npc, client, event_type, companion_data)` assembles full system-prompt text. |
| `lua_modules/companion_context.lua` | 284 | `build(npc, client)` populates `type_framing` and `evolution_context` for LLM. |
| `lua_modules/llm_bridge.lua` | ~300 | `build_context(e)` uses fake_e table. `generate_response(context, message)` for LLM call. `unprompted=true` keeps sidecar response to 1 sentence. |
| `npc-llm-sidecar/app/models.py` | 83 | `type_framing`, `evolution_context`, `unprompted` are all serialized fields. No `event_type` field — event guidance must go through `type_framing` override. |
| `lua_modules/companion.lua` | ~1500 | `REREC_BONUS = 10` at line 74 (now removed). Four help-text locations with "+10% bonus" or "re-recruit later with bonus". Header comment on `Dismiss()`. Comment block in re-recruitment section. |

### Key Findings

- **GAP-12**: `companion_commentary.check_and_speak()` already resolves the owner client (line 136). Just need to use `client:GetGroup()` + `group:GroupMessage()` before falling back to `npc:Say()`.
- **GAP-13**: EQEmu fires `event_level_up` for NPC entities too (confirmed in LUA-CODE.md event list). The LLM call pattern: build fake_e → `llm_bridge.build_context(fake_e)` → override `context.type_framing` with `companion_culture.get_companion_context()` for "level_up" → set `context.unprompted = true` → `generate_response(context, "[level_up]")`. Route result through group chat.
- **GAP-14**: `REREC_BONUS` constant is defined but never used — re-recruitment bypasses all rolls in `attempt_recruitment()` (lines 463-474). Text in 4 help locations plus 2 comment blocks. The `attempt_recruitment()` function itself does not reference `REREC_BONUS` at all (confirmed by reading lines 463-508).

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `event_level_up` for NPC | LUA-CODE.md event list (NPC Events table) | Yes | Confirmed in NPC events table |
| `group:GroupMessage(npc, msg)` | LUA-CODE.md Lua_Group bindings | Yes | Same pattern used in event_say for gsay_response_channel=="group" |
| `llm_bridge.build_context(fake_e)` | llm_bridge.lua source | Yes | Used identically in companion_commentary.lua line 143 |
| `context.unprompted = true` | models.py + prompt_assembler.py | Yes | Adds "1 sentence only" instruction to sidecar prompt |
| `companion_culture.get_companion_context()` | companion_culture.lua line 387 | Yes | Returns assembled system-prompt string for event type |
| `context.type_framing` override | llm_bridge.generate_response() line 241 | Yes | type_framing is serialized to sidecar — overriding it replaces cultural framing with event-specific text |

### Plan Amendments

No amendments needed — plan confirmed by research.

---

## Stage 3: Socialize

No teammate dependencies for these three small changes. All are self-contained Lua changes with no C++ or DB dependencies. Proceeding directly to build.

---

## Stage 4: Build

### Implementation Log

#### 2026-03-15 — GAP-12: Fix commentary channel

**What:** Changed `companion_commentary.check_and_speak()` to route LLM response through group chat.
**Where:** `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion_commentary.lua` lines 158-166 (after fix)
**Why:** All other companion dialogue uses `group:GroupMessage()`. Commentary using `npc:Say()` was inconsistent and visible to all nearby players, not just the owner's group.
**Notes:** Owner `client` is already resolved earlier in the function (line 136). Fallback to `npc:Say()` retained for the edge case where owner has no group.

#### 2026-03-15 — GAP-13: Add event_level_up handler

**What:** Added `event_level_up` function to `global_npc.lua` before `event_death_zone`.
**Where:** `/mnt/d/Dev/eq/akk-stack/server/quests/global/global_npc.lua` — inserted ~50 lines before old line 603
**Why:** `companion_culture.lua` defines a "level_up" event type with appropriate dialogue guidance, but no NPC event handler existed to trigger it. When EQEmu fires `event_level_up` for a companion NPC, the handler now generates personalized LLM dialogue.
**Notes:**
- Pattern mirrors `companion_commentary.check_and_speak()`: fake_e → build_context → override type_framing → generate_response → group chat.
- `context.type_framing` is overridden with `companion_culture.get_companion_context()` output for "level_up" so the sidecar gets event-specific guidance instead of the generic framing from `companion_context.build()`.
- `context.unprompted = true` keeps the response to 1 sentence (appropriate for a level-up remark).
- All calls are pcall-wrapped. Silent failure on any error.

#### 2026-03-15 — GAP-14: Remove REREC_BONUS, fix help text

**What:** Removed `REREC_BONUS = 10` constant and updated all help text to accurately describe unconditional re-recruitment.
**Where:** `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion.lua`
**Why:** `REREC_BONUS` was never applied — the re-recruitment track in `attempt_recruitment()` bypasses all roll logic (lines 463-474). Help text claiming "+10% bonus" was misleading.
**Notes:**
- Removed constant definition (lines 73-74 in original)
- Updated 4 help text strings: 2 in `cmd_help()`, 2 in `cmd_help_standalone()`
- Updated comment on `cmd_dismiss()` function
- Updated comment block in re-recruitment section
- Updated header comment on `companion:Dismiss()` API description
- `Dismiss(true)` call in `cmd_dismiss()` unchanged — the `voluntary_bool` parameter controls whether C++ preserves the re-recruitment record, not whether a bonus applies

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| `event_type` not in sidecar model | Sidecar `ChatRequest` has no `event_type` field | Override `context.type_framing` with `companion_culture.get_companion_context()` output — this puts event-specific guidance into the field the sidecar does read |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion_commentary.lua` | Modified | GAP-12: Route commentary through group:GroupMessage() |
| `akk-stack/server/quests/global/global_npc.lua` | Modified | GAP-13: Add event_level_up handler for companions |
| `akk-stack/server/quests/lua_modules/companion.lua` | Modified | GAP-14: Remove REREC_BONUS, fix 4 help text strings + 3 comments |

---

## Open Items

- None

---

## Context for Next Agent

All three tasks are complete and committed to `feature/companion-authenticity-phase3-4`.

**GAP-12**: Commentary now routes through group chat via `group:GroupMessage(npc, response)` in `companion_commentary.check_and_speak()`, with fallback to `npc:Say()` when owner has no group.

**GAP-13**: `event_level_up` in `global_npc.lua` fires for companions, builds LLM context, overrides `type_framing` with `companion_culture.get_companion_context()` "level_up" event text, sets `unprompted=true`, and routes response through group chat.

**GAP-14**: `REREC_BONUS` constant removed. All help text now says "can always re-recruit later" instead of "+10% bonus". The actual re-recruitment code in `attempt_recruitment()` was already correct (unconditional bypass) — only the documentation was wrong.
