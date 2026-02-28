# NPC LLM Phase 2.5 — Lore Integration + Prompt Pipeline — Status Tracker

> **Feature branch:** `feature/npc-llm-phase2.5`
> **Created:** 2026-02-24
> **Last updated:** 2026-02-25

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-02-24 | 2026-02-24 |
| Design | game-designer + lore-master | Complete | 2026-02-25 | 2026-02-25 |
| Architecture | architect + config-expert | Complete | 2026-02-25 | 2026-02-25 |
| Implementation | data-expert + lua-expert + config-expert | Complete | 2026-02-25 | 2026-02-25 |
| Validation | game-tester | In Progress | 2026-02-25 | |
| Completion | _user_ | Not Started | | |

**Current phase:** Validation — Server-side checks complete (PASS WITH WARNINGS). Awaiting in-game playtest.

---

## Context: Parent Feature

This is a sub-phase of `feature/npc-llm-integration`. Phase 2 (conversation
memory via Pinecone) is mechanically complete. Phase 2.5 bridges the gap
between "mechanics work" and "conversations feel authentic" by refactoring
the sidecar's prompt pipeline with rich lore context.

- **Parent workspace:** `claude/project-work/feature-npc-llm-integration/`
- **Parent status:** Phase 2 complete, mechanically validated
- **Vision doc:** `claude/project-work/feature-npc-llm-integration/npc-living-world-vision.md`
  (see "Phase 2.5 — Lore Integration + Prompt Pipeline" section)

---

### game-tester server-side validation (in progress)
- **Date:** 2026-02-25
- **Server-side result:** PASS WITH WARNINGS
- **Checks run:** 27 checks — 25 PASS, 2 WARN (memory threshold, model hallucination)
- **Summary:** Code pipeline correct. Context providers load and serve accurate lore.
  Assembled prompts verified to contain rich cultural context. Two pre-existing Phase 2
  issues surfaced: (1) memory retrieval score threshold too strict, (2) Mistral-7B
  continues to hallucinate location names despite correct system prompts. Neither is a
  Phase 2.5 code defect. Test plan written at `game-tester/test-plan.md` with 10 in-game
  tests + 4 edge cases. In-game validation required before completion.

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-02-24
- **Notes:** Workspace created at `phase-2.5/` within parent feature workspace.
  The implementation plan for Phase 2.5 is fully documented in
  `npc-living-world-vision.md`. Game-designer should use it as the primary
  reference when authoring the PRD. Lore-master should cross-reference the
  existing lore bible at `lore-deep-dive/context/npc-lore-bible.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architecture team (architect + config-expert)
- **Date:** 2026-02-25
- **Notes:** PRD complete (383 lines) and lore-approved. Lore-master approved
  with one minor suggestion (Qeynos guard catacombs wording) and one
  architectural note (canonical NPC overrides by npc_type_id for 13 NPCs
  with existing quest backstories). Both passed to architect for consideration.

### architecture team → implementation team
- **Date:** 2026-02-25
- **Notes:** Architecture doc complete (624 lines). 9 implementation tasks
  assigned to 3 agents: data-expert (tasks 1-2, JSON data authoring),
  lua-expert (tasks 3-7 + 9, Python sidecar + Lua bridge code), config-expert
  (task 8, docker-compose update). Key findings: no C++ changes needed, no DB
  changes needed, NPC deity unavailable (derive from faction), merchant detection
  via GetClass()==41. All 6 PRD open questions answered. Tasks 1+2 and 3+5
  can proceed in parallel. Spawn data-expert, lua-expert, and config-expert.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Author `global_contexts.json` — racial baselines, race+class combos, faction combos, 13 NPC overrides | data-expert | Complete | 2026-02-24 |
| 2 | Author `local_contexts.json` — per-zone knowledge at 3 INT tiers for 22 city + 10-15 outdoor zones | data-expert | Complete | 2026-02-24 |
| 3 | Implement `context_providers.py` — GlobalContextProvider, LocalContextProvider, role framing | lua-expert | Complete | 2026-02-24 |
| 4 | Implement `prompt_assembler.py` — layered prompt assembly with token budgeting | lua-expert | Complete | 2026-02-24 |
| 5 | Update `models.py` — add npc_int, npc_primary_faction, npc_gender, npc_is_merchant | lua-expert | Complete | 2026-02-24 |
| 6 | Update `main.py` — integrate prompt assembler, init providers at startup | lua-expert | Complete | 2026-02-24 |
| 7 | Update `llm_bridge.lua` — add 4 new fields to build_context() and generate_response() | lua-expert | Complete | 2026-02-24 |
| 8 | Update `docker-compose.npc-llm.yml` — n_ctx=2048, new env vars with defaults | config-expert | Complete | 2026-02-25 |
| 9 | Integration test — verify prompt assembly, token budgets, fallback chain with real NPC data | lua-expert | Complete | 2026-02-24 — 37/37 tests PASS. Live HTTP confirmed. Prompt debug verified in-container. |

---

## Key Files for This Phase

| File | Role |
|------|------|
| `akk-stack/npc-llm-sidecar/app/main.py` | Chat endpoint refactor |
| `akk-stack/npc-llm-sidecar/app/prompt_builder.py` | Replaced by assembler |
| `akk-stack/npc-llm-sidecar/app/memory.py` | Memory retrieval improvements |
| `akk-stack/npc-llm-sidecar/app/prompt_assembler.py` | New — layered prompt assembly |
| `akk-stack/npc-llm-sidecar/app/context_providers.py` | New — context provider registry |
| `akk-stack/npc-llm-sidecar/config/global_contexts.json` | New — world-level context |
| `akk-stack/npc-llm-sidecar/config/local_contexts.json` | New — zone/NPC-level context |
| `akk-stack/docker-compose.npc-llm.yml` | n_ctx bump to 2048 |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Global context coverage scope? | PRD | architect | Answered | ~94 entries: 16 racial + ~40 race+class + ~25 faction + 13 overrides |
| 2 | Local context authoring method? | PRD | architect | Answered | Hybrid: data foundation + hand-written paragraphs. ~35 zones x 3 tiers |
| 3 | NPC role inference accuracy? | PRD | architect | Answered | GetClass()==41 for merchants, class→category mapping for others |
| 4 | Performance impact of n_ctx=2048? | PRD | architect | Answered | Low risk — ~5GB VRAM within 6GB limit. Fallback to 1536 if needed |
| 5 | Token budget tuning approach? | PRD | architect | Answered | Env vars with defaults. 200+150+0+200+500=1100 of 2048. ~948 margin |
| 6 | Canonical soul elements from scripts? | PRD | architect | Answered | NPC-specific overrides in global_contexts.json by npc_type_id. 13 entries |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| Memory retrieval returns 0 results — MEMORY_SCORE_THRESHOLD=0.4 is too strict for all-MiniLM-L6-v2 at this collection size. Memories store but never retrieve. | game-tester | 2026-02-25 | No — pre-existing Phase 2 issue |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Derive deity from faction, not from npc_types | architect | 2026-02-25 | npc_types has no deity column. C++ struct has it but marked "not loaded from DB". Bake deity refs into faction-keyed paragraphs. |
| 2 | Merchant detection via GetClass()==41 | architect | 2026-02-25 | merchant_id not exposed in Lua API. Class 41 catches most merchants. Minor accuracy loss acceptable. |
| 3 | No C++ or DB changes for Phase 2.5 | architect | 2026-02-25 | All NPC data accessible via Lua API. Sidecar is standalone Python service. |
| 4 | Token budgets as docker-compose env vars | architect | 2026-02-25 | Follows existing LLM_N_CTX pattern. Tunable without code changes. |
| 5 | Single lua-expert for Python + Lua code | architect | 2026-02-25 | Avoids handoff overhead between sidecar and Lua bridge. Both are scripting work. |
| 6 | Protocol-agent consultation not needed | architect | 2026-02-25 | No client-server packet changes. All changes are sidecar + Lua via localhost HTTP. |

---

## Completion Checklist

_Filled in after game-tester validation passes._

- [ ] All implementation tasks marked Complete
- [ ] No open Blockers
- [ ] game-tester validation: PASS
- [ ] Feature branch merged to main
- [ ] Server rebuilt (if C++ changed)
- [ ] All phases marked Complete in Workflow Status table

**Merged by:** _name_
**Merge date:** _YYYY-MM-DD_

---

## Notes

_Free-form notes, observations, or context that doesn't fit above._
