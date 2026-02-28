# NPC LLM Phase 2.5 — Lore Integration + Prompt Pipeline — Dev Notes: lua-expert

> **Feature branch:** `feature/npc-llm-phase2.5`
> **Agent:** lua-expert
> **Task(s):** 3, 4, 5, 6, 7, 9
> **Date started:** 2026-02-24
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Implement `context_providers.py` | — | In Progress |
| 4 | Implement `prompt_assembler.py` | 3 | Pending |
| 5 | Update `models.py` (4 new fields) | — | In Progress |
| 6 | Update `main.py` to integrate assembler | 3, 4, 5 | Pending |
| 7 | Update `llm_bridge.lua` (4 new fields) | 5 | Pending |
| 9 | Integration test — end-to-end verification | 1-8 | Blocked on data-expert + config-expert |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `npc-llm-sidecar/app/main.py` | 230 | FastAPI app. `lifespan()` calls `load_zone_cultures()`, loads model, inits memory. Chat endpoint calls `build_system_prompt(req, memories)`. This is the only call site to refactor. |
| `npc-llm-sidecar/app/models.py` | 41 | `ChatRequest` Pydantic model with 17 fields. `player_id` has default 0. Need to add 4 fields with defaults for backward compat. |
| `npc-llm-sidecar/app/prompt_builder.py` | 206 | Contains `RACE_NAMES`, `CLASS_NAMES`, `FACTION_LABELS`, `format_memory_context()`, `build_system_prompt()`, `build_user_message()`. Assembler will import from here. Old `build_system_prompt` stays as fallback. |
| `server/quests/lua_modules/llm_bridge.lua` | 158 | `build_context()` assembles the context table; `generate_response()` copies fields into request table. Both need 4 new fields: `npc_int`, `npc_primary_faction`, `npc_gender`, `npc_is_merchant`. |
| `phase-2.5/architect/architecture.md` | 624 | Complete specs for all classes. Full class/method signatures, JSON schema, token budgets, env vars. Primary reference. |

### Key Findings

1. **models.py**: Trivial change. Add 4 fields with defaults after `player_id`.
2. **context_providers.py**: New file. `GlobalContextProvider` loads `global_contexts.json`, serves fallback chain (npc_override → race_class_faction → race_class → race). `LocalContextProvider` loads `local_contexts.json`, maps INT to tier. `ROLE_FRAMES` dict + `get_role_frame()` function.
3. **prompt_assembler.py**: New file. `PromptAssembler` class takes llm reference, both providers, budgets dict. `assemble()` builds system prompt in layers with token budgeting via `llm.tokenize()`. Fallback to char estimate if llm is None.
4. **main.py**: Initialize providers and assembler in `lifespan()`. Replace `build_system_prompt()` call in chat endpoint with `assembler.assemble()`. Import assembler module.
5. **llm_bridge.lua**: In `build_context()`, add `npc_int`, `npc_primary_faction`, `npc_gender`, `npc_is_merchant` to returned table. In `generate_response()`, add same 4 fields to the `request` table. Merchant check: `e.self:GetClass() == 41`.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `app/context_providers.py` | Create | New GlobalContextProvider, LocalContextProvider, ROLE_FRAMES, get_role_frame() |
| `app/prompt_assembler.py` | Create | New PromptAssembler class with token-budgeted layered assembly |
| `app/models.py` | Modify | Add npc_int, npc_primary_faction, npc_gender, npc_is_merchant fields |
| `app/main.py` | Modify | Init providers/assembler in lifespan(); replace build_system_prompt call |
| `lua_modules/llm_bridge.lua` | Modify | Add 4 fields to build_context() and generate_response() |

**Change sequence:**
1. models.py — adds field definitions (unblocks lua bridge)
2. context_providers.py — new module (unblocks assembler)
3. prompt_assembler.py — depends on context_providers.py
4. main.py — depends on all three above
5. llm_bridge.lua — depends on field names from models.py

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `llm.tokenize(text.encode("utf-8"))` | Architecture doc + llama-cpp-python API | Yes | Returns list of token IDs; len() gives token count |
| `e.self:GetINT()` | Architecture doc: "confirmed available (already used in eligibility check)" | Yes | Used in is_eligible() already |
| `e.self:GetPrimaryFaction()` | Architecture doc: "confirmed in lua_npc.cpp:1032" | Yes | Returns npc_faction.primaryfaction; 0 for NPCs without faction |
| `e.self:GetGender()` | Architecture doc: "confirmed in lua_mob.cpp" | Yes | 0=male, 1=female, 2=neutral |
| `e.self:GetClass()` | llm_bridge.lua already sends this in build_context | Yes | ==41 for merchant class |
| Pydantic BaseModel optional fields | Standard Pydantic | Yes | Use `field: type = default` syntax |

### Plan Amendments

Plan confirmed — no amendments needed. Architecture doc is detailed enough to implement directly.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| team-lead | Plan ready to execute | Confirming I can proceed without waiting for data-expert (context providers handle missing JSON gracefully) |

### Consensus Plan

**Agreed approach:** Implement Tasks 3, 5, 4, 6, 7 in sequence. Task 9 (integration test) waits for data-expert (tasks 1-2) and config-expert (task 8).

The key design point: all providers handle missing JSON gracefully — `GlobalContextProvider` falls back to empty string, `LocalContextProvider` returns empty string for unknown zones. This means the assembler works with zero data files and degrades to the existing `build_system_prompt()` behavior.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `app/context_providers.py` | Create | New module per architecture spec |
| `app/prompt_assembler.py` | Create | New module per architecture spec |
| `app/models.py` | Modify | +4 fields with defaults |
| `app/main.py` | Modify | Init providers in lifespan; replace prompt call |
| `lua_modules/llm_bridge.lua` | Modify | +4 fields in build_context() and generate_response() |

**Change sequence (final):**
1. models.py (trivial)
2. context_providers.py (new module)
3. prompt_assembler.py (new module, depends on context_providers)
4. main.py (wires it all together)
5. llm_bridge.lua (Lua side)

---

## Stage 4: Build

### Implementation Log

#### 2026-02-24 — Task 5: models.py — add 4 new optional fields

**What:** Added `npc_int`, `npc_primary_faction`, `npc_gender`, `npc_is_merchant` to ChatRequest after `player_id`.
**Where:** `akk-stack/npc-llm-sidecar/app/models.py`
**Why:** Sidecar must accept the new NPC attributes from the Lua bridge for context-provider lookups.
**Notes:** All fields have defaults — old Lua bridges that don't send them still work.

#### 2026-02-24 — Task 3: context_providers.py — new module

**What:** Created GlobalContextProvider, LocalContextProvider, ROLE_FRAMES dict, get_role_frame() function.
**Where:** `akk-stack/npc-llm-sidecar/app/context_providers.py`
**Why:** Separates context data loading from prompt assembly. Providers handle graceful fallback for missing JSON or unknown keys.
**Notes:** ROLE_FRAMES uses class IDs per architecture doc. Merchant check uses npc_is_merchant flag, not class 41 on Python side.

#### 2026-02-24 — Task 4: prompt_assembler.py — new module

**What:** Created PromptAssembler class with count_tokens() and assemble() methods. Token budgets read from env vars. Truncation by layer priority.
**Where:** `akk-stack/npc-llm-sidecar/app/prompt_assembler.py`
**Why:** Replaces flat prompt_builder with layered, token-budgeted assembly.
**Notes:** Falls back to char-estimate tokenization if llm is None. build_system_prompt() stays as fallback if assembler fails.

#### 2026-02-24 — Task 6: main.py — integrate assembler

**What:** Added provider/assembler initialization in lifespan(). Replaced build_system_prompt() call with assembler.assemble() in chat endpoint.
**Where:** `akk-stack/npc-llm-sidecar/app/main.py`
**Why:** Wire the new prompt pipeline into the request handling path.
**Notes:** Assembler instantiated after model load so tokenizer reference is valid.

#### 2026-02-24 — Task 7: llm_bridge.lua — add 4 fields

**What:** Added npc_int, npc_primary_faction, npc_gender, npc_is_merchant to build_context() and generate_response().
**Where:** `akk-stack/server/quests/lua_modules/llm_bridge.lua`
**Why:** Sidecar needs these attributes for cultural context and role framing lookups.
**Notes:** Merchant check is GetClass()==41 per architecture decision #2.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| Assembler needs llm before model loads | lifespan init order | Create assembler after _load_model(); pass None-safe tokenizer |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `app/context_providers.py` | Created | GlobalContextProvider, LocalContextProvider, ROLE_FRAMES, get_role_frame() |
| `app/prompt_assembler.py` | Created | PromptAssembler with token-budgeted layered prompt assembly |
| `app/models.py` | Modified | Added 4 new fields with defaults to ChatRequest |
| `app/main.py` | Modified | Integrated prompt assembler into lifespan and chat endpoint |
| `lua_modules/llm_bridge.lua` | Modified | Added 4 new fields to build_context() and generate_response() |

---

## Open Items

- [ ] Task 9: Integration test — blocked on data-expert (tasks 1+2) and config-expert (task 8)

---

## Context for Next Agent

Tasks 3-7 are complete. The code pipeline is:
- Lua sends 4 new fields (npc_int, npc_primary_faction, npc_gender, npc_is_merchant)
- Sidecar accepts them in ChatRequest (all have defaults for backward compat)
- PromptAssembler.assemble() builds the layered prompt using GlobalContextProvider + LocalContextProvider
- Falls back to old build_system_prompt() if providers fail to load

Task 9 (integration test) is blocked waiting for:
- data-expert task 1: global_contexts.json
- data-expert task 2: local_contexts.json
- config-expert task 8: docker-compose.npc-llm.yml env var updates

Once those are done, test with `LLM_DEBUG_PROMPTS=true` to inspect prompt layers.
