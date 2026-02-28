# NPC LLM Integration — Status Tracker

> **Feature branch:** `feature/npc-llm-integration`
> **Created:** 2026-02-23
> **Last updated:** 2026-02-23

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-02-23 | 2026-02-23 |
| Design | game-designer + lore-master | Complete | 2026-02-23 | 2026-02-23 |
| Architecture | architect + infra-expert + config-expert | Complete | 2026-02-23 | 2026-02-23 |
| Implementation | general-purpose + lua-expert + infra-expert | Complete | 2026-02-23 | 2026-02-23 |
| Validation | game-tester | In Progress | 2026-02-23 | |
| Completion | _user_ | Not Started | | |

**Current phase:** Validation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-02-23
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Existing planning docs are referenced (not duplicated) in the PRD template.
  Spawn both agents as teammates for the Design phase.

### design team → architecture team (architect + infra-expert + config-expert)
- **Date:** 2026-02-23
- **Notes:** PRD complete at `game-designer/prd.md`. Lore review approved by lore-master — all feedback incorporated (Threatening/Scowling distinction, zone cultural context table with 15 cities, era hard stops, forbidden modern concepts, deity awareness, creature exclusion categories). PRD has 15 acceptance criteria. 7 open questions for the architect to investigate (body type IDs for golems/elementals, curl availability, io.popen blocking behavior, emote visibility, model selection, global_npc.lua coexistence, zone context delivery mechanism). No C++ changes in Phase 1. Scope: Python sidecar + Lua bridge + global_npc.lua hook + Docker config.

### implementation team → game-tester
- **Date:** 2026-02-23
- **Server-side result:** PASS WITH WARNINGS
- **Notes:** All 7 implementation tasks completed and verified on disk. Docker
  image builds cleanly. Sidecar container starts and health endpoint responds.
  Lua syntax clean on all 4 files. Zone cultures JSON complete (25 keys / 15
  cities). Post-processor functional. One Critical blocker found: model file
  name case mismatch prevents model from loading. One Medium gap: "stress" not
  in era blocklist. Full in-game testing cannot proceed until Critical blocker
  is resolved. See test plan at `game-tester/test-plan.md` for the complete
  15-test in-game guide once the blocker is fixed.

### architecture team → implementation team (general-purpose + lua-expert + infra-expert)
- **Date:** 2026-02-23
- **Notes:** Architecture doc complete at `architect/architecture.md`. All 7 PRD open questions answered. 7 implementation tasks defined with dependency graph. Advisors consulted: infra-expert designed Docker deployment (compose overlay, networking, healthcheck), config-expert confirmed no rule/config changes needed and flagged saylink bracket stripping requirement. Key decisions: all config via llm_config.lua (no C++ rules), typing indicator via e.other:Message() (speaker-only), zone culture as static JSON in sidecar, 11 body types excluded, sidecar is model-agnostic for RAM flexibility.
  
  **Implementation sequence:**
  1. Python sidecar service + zone_cultures.json → **general-purpose** (parallel)
  2. Lua modules (llm_bridge, llm_config, llm_faction) → **lua-expert** (parallel)
  3. Docker deployment files → **infra-expert** (parallel)
  4. global_npc.lua modification → **lua-expert** (after Lua modules)
  5. curl verification → **infra-expert** (after Docker)
  6. Integration test → **lua-expert** (after all above)
  
  **Assigned experts:** general-purpose, lua-expert, infra-expert

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Create Python sidecar service (main.py, prompt_builder.py, post_processor.py, models.py) | general-purpose | Complete | 2026-02-23 — all files present on disk |
| 2 | Create zone_cultures.json config file (15 cities from PRD table) | general-purpose | Complete | 2026-02-23 — 25 zone keys, all 15 cities covered |
| 3 | Create Lua modules (llm_bridge.lua, llm_config.lua, llm_faction.lua) | lua-expert | Complete | 2026-02-23 |
| 4 | Modify global_npc.lua to add event_say handler | lua-expert | Complete | 2026-02-23 |
| 5 | Create Docker deployment files (compose overlay, Dockerfile, .gitignore, .env, Makefile) | infra-expert | Complete | 2026-02-23 — image builds, container starts |
| 6 | Verify curl availability in eqemu-server container | infra-expert | Complete | 2026-02-23 — /usr/bin/curl v7.88.1 confirmed |
| 7 | Integration test: start sidecar, speak to unscripted NPC, verify response | lua-expert | Blocked | Blocked by model file name mismatch (see Blockers) |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Which body types for golems/elementals to exclude? | game-designer | architect | **Resolved** | 11 types from bodytypes.h: Construct(5), NoTarget(11), Insect(22), Summoned(24), Plant(25), Summoned2(27), Summoned3(28), Familiar(31), Boxes(33), NoTarget2(60), SwarmPet(63). Undead/Dragon/Monster NOT excluded. |
| 2 | curl availability in EQEmu container? | game-designer | architect | **Resolved** | Confirmed by infra-expert: /usr/bin/curl v7.88.1 present in eqemu-server container (Debian bookworm). |
| 3 | io.popen blocking behavior with LuaJIT? | game-designer | architect | **Resolved** | Blocks zone process during execution. Acceptable for 1-6 players. Typing indicator fires before blocking call. curl --max-time 3 enforces hard timeout. |
| 4 | Typing indicator emote: speaker-only or broadcast? | game-designer | architect | **Resolved** | Mob::Emote() broadcasts to all 200 units. Solution: e.other:Message(10, text) sends to single client (speaker only). |
| 5 | Best Mistral 7B variant for RP dialogue? | game-designer | architect | **Resolved** | mistral-7b-instruct-v0.3.Q4_K_M.gguf as baseline. Sidecar is model-agnostic — swap GGUF file to try openhermes-2.5 or nous-hermes-2 variants. |
| 6 | global_npc.lua event_say + event_spawn coexistence? | game-designer | architect | **Resolved** | Confirmed safe. Lua scripts support multiple independent event handlers. event_spawn and event_say are completely independent. |
| 7 | Zone cultural context delivery mechanism? | game-designer | architect | **Resolved** | Static JSON file in sidecar config dir (config/zone_cultures.json). Loaded at startup, keyed by zone short name. Lua sends zone_short_name; sidecar injects culture into system prompt. |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| Model file name case mismatch: disk has `Mistral-7B-Instruct-v0.3-Q4_K_M.gguf` but `.env` expects `mistral-7b-instruct-v0.3.Q4_K_M.gguf`. Sidecar starts but `model_loaded: false`. All LLM conversations silently fail. Fix: rename model file or update .env. | game-tester | 2026-02-23 | Open |
| post_processor.py does not block "stress" (PRD lists it as forbidden). "anxiety" is blocked instead. Minor quality gap. Fix: add `r"\bstress\b"` to ERA_BLOCKLIST. | game-tester | 2026-02-23 | Open |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Threatening gives verbal warning; Scowling gives hostile emote only | game-designer + lore-master | 2026-02-23 | Mechanically and narratively distinct faction levels |
| 2 | INT filter is sentience check, not intelligence commentary | game-designer + lore-master | 2026-02-23 | Prevents generating offensive dialogue about low-INT NPCs |
| 3 | Zone Cultural Context table with 15 cities | game-designer + lore-master | 2026-02-23 | City-specific personality dramatically improves NPC authenticity |
| 4 | Explicit modern concept blocklist in system prompt | game-designer + lore-master | 2026-02-23 | Prevents most common LLM anachronism |
| 5 | Opt-out (not opt-in) for LLM conversations | game-designer | 2026-02-23 | Maximum coverage with minimum configuration |
| 6 | Broad rollout (all unscripted NPCs) not conservative rollout | game-designer | 2026-02-23 | global_npc.lua naturally catches all unscripted NPCs; quest dispatch chain protects scripted NPCs |
| 7 | All Phase 1 config via llm_config.lua, not ruletypes.h | architect + config-expert | 2026-02-23 | No C++ changes = no rule categories; Lua config is hot-reloadable via #reloadquest |
| 8 | Typing indicator via e.other:Message(10), not Emote() | architect | 2026-02-23 | Emote() broadcasts to all within 200 units; Message() sends to single client (speaker-only) |
| 9 | Zone culture as static JSON in sidecar config dir | architect | 2026-02-23 | Data is static, loaded once at startup, no per-request overhead; Lua sends zone_short_name |
| 10 | 11 body types excluded; Undead/Dragon/Monster NOT excluded | architect + lore-master | 2026-02-23 | Sentient creatures should speak; INT filter handles non-sentient ones within non-excluded types |
| 11 | Sidecar is model-agnostic; RAM managed by model swapping | architect + infra-expert | 2026-02-23 | Host has ~8GB RAM; can swap to smaller GGUF without code changes |
| 12 | Strip [square brackets] from LLM output | architect + config-expert | 2026-02-23 | Chat:AutoInjectSaylinksToSay = true; brackets create clickable saylinks |
| 13 | Docker network is backend, not akk-stack_default | architect + infra-expert | 2026-02-23 | Integration plan had wrong network name; infra-expert verified actual compose config |

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

This is a multi-phase feature. Phase 1 (Foundation) focuses on:
- Python sidecar service (FastAPI + llama-cpp-python, Mistral 7B)
- Lua bridge module
- global_npc.lua hook
- Docker compose additions

No C++ changes in Phase 1.

### Existing Planning Docs

- `claude/docs/NPC-CONVERSATION-SYSTEM.md` — deep dive into existing NPC chat system
- `claude/docs/plans/2026-02-23-llm-npc-integration-plan.md` — full integration plan
