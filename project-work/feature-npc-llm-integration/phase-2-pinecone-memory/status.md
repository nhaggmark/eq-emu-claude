# NPC Conversation Memory (Pinecone Integration) — Status Tracker

> **Feature branch:** `feature/npc-llm-integration`
> **Phase:** 2 of the NPC LLM Integration feature
> **Created:** 2026-02-24
> **Last updated:** 2026-02-24

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-02-24 | 2026-02-24 |
| Design | game-designer + lore-master | Complete | 2026-02-24 | 2026-02-24 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-02-24 | 2026-02-24 |
| Implementation | python-expert + lua-expert + infra-expert | In Progress | 2026-02-24 | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-02-24
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Phase 1 (stateless NPC conversations) is complete and tested — see
  `claude/project-work/feature-npc-llm-integration/status.md` for full Phase 1
  history. Phase 2 deliverables from the integration plan are:
  1. Pinecone client integration in sidecar
  2. Embedding model (all-MiniLM-L6-v2) for conversation turns
  3. Memory storage after each exchange
  4. Memory retrieval (top-5 relevant) before prompt construction
  5. Namespace-per-NPC architecture
  6. Memory management (TTL cleanup, per-NPC limits)
  7. `/v1/memory/clear` endpoint for admin use

  Phase 1 code lives in:
  - `akk-stack/npc-llm-sidecar/` (Python sidecar)
  - `akk-stack/server/quests/lua_modules/` (Lua bridge)
  - `akk-stack/server/quests/global/global_npc.lua`

  Integration plan reference: `claude/docs/plans/2026-02-23-llm-npc-integration-plan.md`

### design team → architect
- **Date:** 2026-02-24
- **Notes:** PRD complete at `game-designer/prd.md` (514 lines). Lore review
  approved with notes by lore-master — one scenario revision (Scenario 7: Neriak
  memory tone) and role-memory framing table incorporated.

  **PRD scope summary:**
  - Persistent NPC conversation memory via Pinecone vector DB
  - Per-NPC-type, per-player-character memory with topic-relevant retrieval
  - 90-day retention, 100-exchange per-NPC per-player cap, recency weighting
  - Faction change acknowledgment in memory callbacks
  - City culture governs tone of memory callbacks (key lore constraint)
  - Memory framing table: 9 NPC role/culture combinations documented
  - No Lua changes, no C++ changes — Python sidecar + Docker only
  - 14 acceptance criteria, 7 open questions for architect

  **Lore constraints for architect:**
  - City culture MUST govern memory callback tone (see PRD Scenario 7 and Memory Framing table)
  - Neriak, Cabilis, Oggok NPCs never express warmth in memory callbacks, even at positive faction
  - See lore-master's `lore-notes.md` for additional city-culture constraints

### architect → implementation team (python-expert + lua-expert + infra-expert)
- **Date:** 2026-02-24
- **Notes:** Architecture plan complete at `architect/architecture.md`. All 7
  PRD open questions answered. Protocol-agent confirmed no client-server protocol
  changes needed. Config-expert confirmed Docker env vars are the correct config
  mechanism (no C++ rules apply).

  **Architecture summary:**
  - New `app/memory.py` module (~200 lines) — MemoryManager class for Pinecone + embeddings
  - Modified `app/main.py` — memory retrieval/storage in chat flow, new endpoints
  - Modified `app/models.py` — player_id field, memory response fields
  - Modified `app/prompt_builder.py` — memory context injection, city-culture tone instructions
  - Modified `llm_bridge.lua` — 2 lines to add player_id (contradicts PRD "no Lua changes" but necessary)
  - Modified Docker config — Pinecone env vars, CPU-only PyTorch, sentence-transformers

  **Implementation sequence (7 tasks):**
  1. Create `app/memory.py` → python-expert (independent)
  2. Modify `app/main.py` integration → python-expert (depends on 1, 3, 4)
  3. Modify `app/models.py` → python-expert (independent)
  4. Modify `app/prompt_builder.py` → python-expert (independent)
  5. Modify `llm_bridge.lua` → lua-expert (independent)
  6. Update Docker config → infra-expert (independent)
  7. Integration testing → python-expert (depends on all)

  **Key decisions:**
  - Score threshold lowered from PRD's 0.7 to 0.4 (configurable via env var)
  - Turn summaries for better embedding quality (~20 tokens extra LLM generation)
  - In-app asyncio timer for TTL cleanup (no external cron)
  - Weekly Pinecone keepalive to prevent Starter plan auto-pause

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Create `app/memory.py` — MemoryManager class | python-expert | Not Started | ~200 lines. Embed, retrieve, store, clear, cleanup methods. |
| 2 | Modify `app/main.py` — integrate memory into chat flow | python-expert | Not Started | Depends on 1, 3, 4. Add endpoints, scheduled cleanup. |
| 3 | Modify `app/models.py` — add player_id, memory fields | python-expert | Not Started | ~20 lines added. Independent. |
| 4 | Modify `app/prompt_builder.py` — memory context + tone | python-expert | Not Started | ~60 lines added. City-culture memory instructions. |
| 5 | Modify `llm_bridge.lua` — add player_id | lua-expert | Not Started | 2 lines. CharacterID() already available. |
| 6 | Update Docker config — Pinecone env vars, deps | infra-expert | Complete | 2026-02-24. requirements.txt, Dockerfile, compose overlay, .env updated. |
| 7 | Integration testing — verify all acceptance criteria | python-expert | Not Started | Depends on 1-6. Manual testing. |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Pinecone free tier sufficient for months of play? | game-designer | architect | Answered | Yes. Starter plan: 2GB (~300K vectors). Estimated steady-state: ~10,800 vectors. Uses ~1% of monthly allowances. Keepalive needed to prevent 3-week idle pause. |
| 2 | Embedding model + LLM fit in 8GB memory limit? | game-designer | architect | Answered | Yes. all-MiniLM-L6-v2: ~44MB RAM. CPU-only PyTorch: ~200-400MB. Total with Mistral 7B: ~5.5GB within 6GB limit. |
| 3 | Pinecone serverless cold-start latency impact? | game-designer | architect | Answered | 1-3s for first query to inactive namespace. Mitigated by typing indicator + 3s timeout fallback to stateless. One-time cost per session. |
| 4 | player_id (CharacterID) available in Lua bridge? | game-designer | architect | Answered | Yes. `e.other:CharacterID()` confirmed in lua_client.cpp:3698. Already used in llm_bridge.lua:51 for cooldowns. 2-line addition to send it to sidecar. |
| 5 | Memory cleanup scheduling approach? | game-designer | architect | Answered | In-app asyncio background task with daily timer (configurable via MEMORY_CLEANUP_INTERVAL_HOURS). No external cron needed. |
| 6 | Graceful degradation when Pinecone unavailable? | game-designer | architect | Answered | 3-layer: disabled mode (no API key), retrieval failure (empty memories), storage failure (fire-and-forget). All fall back to Phase 1 stateless behavior. |
| 7 | Memory sharing for multi-spawn NPC types? | game-designer | architect | Answered | Shared via namespace `npc_{npc_type_id}`. Zone in metadata for future filtering. Same-type NPCs are "the same NPC" per PRD. |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| Phase 1 model file name case mismatch | game-tester (Phase 1) | 2026-02-23 | Pending |
| Phase 1 post_processor.py "stress" in ERA_BLOCKLIST | game-tester (Phase 1) | 2026-02-23 | Pending (may already be fixed) |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | City culture governs tone of memory callbacks | game-designer + lore-master | 2026-02-24 | Neriak/Cabilis NPCs must remain cold even with positive faction and fond memories. Prevents lore-breaking warm callbacks from dark cities. |
| 2 | Role-memory framing table added to PRD | game-designer + lore-master | 2026-02-24 | 9 NPC role/culture combinations guide system prompt construction for memory-influenced responses. |
| 3 | No protocol changes needed for Phase 2 | architect + protocol-agent | 2026-02-24 | Phase 2 is entirely sidecar-side. Titanium client is unaware of memory. |
| 4 | Docker env vars are correct config mechanism | architect + config-expert | 2026-02-24 | No existing C++ rules govern NPC memory. Sidecar config via env vars follows Phase 1 pattern. |
| 5 | Score threshold lowered from 0.7 to 0.4 | architect | 2026-02-24 | all-MiniLM-L6-v2 cosine similarity typically lower than expected. 0.7 too aggressive. Configurable via env var. |
| 6 | Turn summaries for embedding quality | architect | 2026-02-24 | Embedding raw dialogue produces worse retrieval than summarized exchange topics. ~20-token extra LLM generation per turn. |
| 7 | player_id added to Lua bridge (2 lines) | architect | 2026-02-24 | Contradicts PRD "no Lua changes" but CharacterID is more reliable than player_name for memory keying. Minimal change. |
| 8 | In-app asyncio timer for TTL cleanup | architect | 2026-02-24 | Simplest approach — no cron, no external scheduling. Daily timer configurable via env var. |
| 9 | Weekly Pinecone keepalive | architect | 2026-02-24 | Starter plan pauses after 3 weeks idle. Weekly query in cleanup task prevents auto-pause. |

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

This is Phase 2 of the NPC LLM Integration feature. Phase 1 (stateless
conversations via Mistral 7B) is complete on the same branch.

Phase 2 adds Pinecone vector DB integration so NPCs remember past interactions
with individual players across sessions. Minimal Lua bridge change (2 lines
for player_id) — all other memory logic lives in the Python sidecar.

### Phase 1 Open Blockers (from game-tester, pending fix before Phase 2 test)

| Blocker | Raised By | Date |
|---------|-----------|------|
| Model file name case mismatch: disk has `Mistral-7B-Instruct-v0.3-Q4_K_M.gguf` but `.env` expects `mistral-7b-instruct-v0.3.Q4_K_M.gguf`. Fix: rename file or update .env. | game-tester | 2026-02-23 |
| post_processor.py does not block "stress" — "anxiety" is blocked instead. Fix: add `r"\bstress\b"` to ERA_BLOCKLIST. | game-tester | 2026-02-23 |

### Phase 1 Artifacts

- `claude/project-work/feature-npc-llm-integration/status.md` — full Phase 1 history
- `claude/project-work/feature-npc-llm-integration/game-designer/prd.md` — Phase 1 PRD
- `claude/project-work/feature-npc-llm-integration/architect/architecture.md` — Phase 1 architecture
- `claude/docs/plans/2026-02-23-llm-npc-integration-plan.md` — full multi-phase plan
