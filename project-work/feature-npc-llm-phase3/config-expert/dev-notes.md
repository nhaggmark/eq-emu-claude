# NPC LLM Phase 3: Soul & Story — Dev Notes: Config Expert

> **Feature branch:** `feature/npc-llm-phase3`
> **Agent:** config-expert
> **Task(s):** #2 — Review config and infrastructure implications
> **Date started:** 2026-02-25
> **Current stage:** Stage 2: Research (architecture reviewed — findings complete)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Review config and infrastructure implications for architecture plan | #1 architecture plan | In Progress |

The architecture plan assigns config/infrastructure implementation to **sidecar-expert**
(Tasks 1-3). Config-expert's role in Phase 3 is advisory review — flagging gaps and
action items for sidecar-expert before they begin.

---

## Stage 1: Plan (Preparatory Research — completed 2026-02-25)

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `akk-stack/docker-compose.npc-llm.yml` | 1-79 | Full overlay compose config. All LLM env vars pass through `.env` with defaults. Soul budget (`LLM_BUDGET_SOUL`) currently 0. Memory settings, ChromaDB path, context file paths all defined. |
| `akk-stack/.env` | 1-107 | `ENABLE_NPC_LLM=true`. LLM section ends at line 106. **All Phase 2.5 vars absent**: `MEMORY_TOP_K`, `MEMORY_SCORE_THRESHOLD`, `MEMORY_MAX_PER_PLAYER`, `MEMORY_TTL_DAYS`, `MEMORY_CLEANUP_INTERVAL_HOURS`, `LLM_DEBUG_PROMPTS`, `LLM_BUDGET_*`, `GLOBAL_CONTEXTS_PATH`, `LOCAL_CONTEXTS_PATH` — all rely on docker-compose defaults only. |
| `npc-llm-sidecar/app/prompt_assembler.py` | 1-225 | 8-layer prompt assembler. Layer 6 placeholder at lines 157-158, 0 budget. Budget vars read from env at init. |
| `npc-llm-sidecar/app/models.py` | 1-44 | `ChatRequest` Pydantic model. Has `npc_deity: int = 0`. No `quest_hints` or `quest_state` fields. |
| `npc-llm-sidecar/app/context_providers.py` | 1-171 | `GlobalContextProvider` fallback chain. No soul element awareness. |
| `npc-llm-sidecar/app/main.py` | 1-253 | FastAPI app. Config files loaded at startup — no hot-reload. PromptAssembler initialized once. |
| `npc-llm-sidecar/Dockerfile` | 1-54 | Python 3.11. Two-stage build. Config dir both copied at build time and volume-mounted at runtime. |
| `npc-llm-sidecar/requirements.txt` | 1-11 | pydantic 2.10.4. `list[str] | None` union syntax (PEP 604) is valid. No watchdog/watchfiles dependency. |
| `eqemu/common/ruletypes.h` | Chat+NPC | No rules govern keyword fallback or dialogue. `Chat:AutoInjectSaylinksToSay=true` default, confirmed live in DB. |

### Key Findings

1. `.env` missing all Phase 2.5 vars — rely on docker-compose defaults only
2. `LLM_BUDGET_SOUL` infrastructure already exists at value 0 — set to 150 for Phase 3
3. `npc_deity` already in `ChatRequest` (models.py:12, default 0) — not yet used by assembler
4. No `quest_hints`/`quest_state` fields — need adding as optional with None defaults
5. No hot-reload mechanism — reload endpoint is the right solution
6. Full prompt with all layers = ~1050 tokens — fits `LLM_N_CTX=2048` comfortably
7. Python 3.11 + Pydantic 2.10 — `list[str] | None` syntax valid
8. No EQEmu rules for keyword fallback — quest hint system is 100% Lua-side

---

## Stage 2: Research — Architecture Review Findings

_Architecture plan read at `claude/project-work/feature-npc-llm-phase3/architect/architecture.md`
dated 2026-02-25. Review covers config and infrastructure implications only._

### Architecture Plan: Config/Infrastructure Items

The plan specifies these config/infrastructure changes (Tasks 1-3, assigned to sidecar-expert):

1. `soul_elements.json` — new config file with `SoulElementProvider` class
2. `models.py` — add `quest_hints: list[str] | None = None` and `quest_state: str | None = None`
3. `prompt_assembler.py` — Layer 5.5 (quest hints, budget 150) + Layer 6 (soul, budget 150)
4. `context_providers.py` — `SoulElementProvider` class with role detection
5. `main.py` — `/v1/config/reload` endpoint, soul provider init
6. `docker-compose.npc-llm.yml` — `LLM_BUDGET_SOUL=150`, `SOUL_ELEMENTS_PATH`, `LLM_BUDGET_QUEST_HINTS=150`

### Findings: APPROVED with 3 Action Items

**Overall: No blocking concerns. Plan is implementable as written.**

#### Action Item 1 (CRITICAL gap): `.env` update is missing from plan scope

The architecture plan (line 77) specifies updating `docker-compose.npc-llm.yml` but does
**not** mention updating `.env`. The `.env` currently ends at `MEMORY_ENABLED=true` (line 106)
with no Phase 2.5 vars present. The three new Phase 3 vars must be added to `.env`.

Without this, the operator has no documented control surface and `.env` remains an incomplete
reference. sidecar-expert Task 3 must explicitly include updating `.env` with:
- All missing Phase 2.5 vars (with comments matching the compose file format):
  `MEMORY_TOP_K`, `MEMORY_SCORE_THRESHOLD`, `MEMORY_MAX_PER_PLAYER`, `MEMORY_TTL_DAYS`,
  `MEMORY_CLEANUP_INTERVAL_HOURS`, `LLM_DEBUG_PROMPTS`, `LLM_BUDGET_GLOBAL`,
  `LLM_BUDGET_LOCAL`, `LLM_BUDGET_SOUL`, `LLM_BUDGET_MEMORY`, `LLM_BUDGET_RESPONSE`,
  `GLOBAL_CONTEXTS_PATH`, `LOCAL_CONTEXTS_PATH`
- The 3 new Phase 3 vars: `LLM_BUDGET_SOUL=150`, `LLM_BUDGET_QUEST_HINTS=150`,
  `SOUL_ELEMENTS_PATH`

#### Action Item 2 (MINOR gap): `PromptAssembler.__init__()` needs new budget var

`prompt_assembler.py` currently reads four budget vars in `__init__()`. The new
`LLM_BUDGET_QUEST_HINTS` is used in the plan's assembler pseudocode but the `__init__`
addition is not explicitly called out. sidecar-expert must add:
```python
self.budget_quest_hints = int(os.environ.get("LLM_BUDGET_QUEST_HINTS", "150"))
```
alongside the existing four budget reads.

#### Action Item 3 (MINOR): docker-compose comment header is stale

Line 2 reads:
```
# LLM sidecar for NPC conversation feature (Phase 1: Foundation + Phase 2: Memory + Phase 2.5: Context Architecture)
```
Should be updated to include `Phase 3: Soul & Story`.

### Observations (no action required)

**Volume mount:** `soul_elements.json` placed at `akk-stack/npc-llm-sidecar/config/`
is automatically available at `/config/soul_elements.json` inside the container via
the existing volume `./npc-llm-sidecar/config:/config:ro`. No compose volumes change needed.

**Reload endpoint thread safety:** The plan's atomic assembler reference swap is correct
for CPython. The async implementation in the plan is correct — no blocking file I/O on
the event loop.

**Token budget arithmetic:** Full prompt with all layers = ~1050 tokens. Fits `LLM_N_CTX=2048`
with ~500 token headroom. Plan's ~980 figure and my ~1050 figure both fit — difference
is in fixed-layer estimates. No context window increase needed.

**Role detection edge case:** Cabilis NPC names (`a_Legionnaire`, `Legion_Guard`) may not
match all guard patterns. False positives are harmless (mild default personality). Key
Iksar NPCs get per-NPC overrides from content-author anyway.

**`npc_deity` passthrough:** The field exists in `ChatRequest` with default 0. lua-expert
populates it via `GetDeity()`. No config changes needed for this.

### Verified Plan

Plan confirmed — no amendments to architecture required. Three action items for sidecar-expert.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Architecture review findings — APPROVED, 3 action items | Confirm .env scope, budget_quest_hints init, comment update |

### Feedback Received

_Awaiting acknowledgment from architect._

### Consensus Plan

_To be written after architect acknowledges findings._

---

## Stage 4: Build

_Not yet started. Config-expert's role in Phase 3 is advisory review._

---

## Open Items

- [ ] Architect to acknowledge the 3 action items from review
- [ ] sidecar-expert to receive review findings before starting Tasks 1-3
- [ ] Confirm `.env` update is in sidecar-expert Task 3 scope

---

## Context for Next Agent

**The architecture plan is sound. Three action items for sidecar-expert (Tasks 1-3):**

1. **`.env` update missing from plan scope** — add all Phase 2.5 vars + 3 Phase 3 vars
   to `akk-stack/.env`. See Action Item 1 above for the full list.

2. **`PromptAssembler.__init__()` needs `self.budget_quest_hints`** — add:
   `self.budget_quest_hints = int(os.environ.get("LLM_BUDGET_QUEST_HINTS", "150"))`
   to `npc-llm-sidecar/app/prompt_assembler.py`.

3. **docker-compose comment** — update line 2 of `docker-compose.npc-llm.yml` to include Phase 3.

Token budget: full prompt with all layers ~1050 tokens. Fits `LLM_N_CTX=2048`. No increase needed.

`soul_elements.json` at `akk-stack/npc-llm-sidecar/config/` is automatically volume-mounted.
No compose volumes change needed.
