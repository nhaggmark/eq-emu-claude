# NPC LLM Phase 3: Soul & Story — Status Tracker

> **Feature branch:** `feature/npc-llm-phase3`
> **Created:** 2026-02-25
> **Last updated:** 2026-02-25

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-02-25 | 2026-02-25 |
| Design | game-designer + lore-master | Complete | 2026-02-25 | 2026-02-25 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-02-25 | 2026-02-25 |
| Implementation | sidecar-expert + lua-expert + content-author | Complete | 2026-02-25 | 2026-02-25 |
| Validation | game-tester | In Progress | 2026-02-25 | |
| Completion | _user_ | Not Started | | |

**Current phase:** Validation — server-side PASS, ready for in-game testing

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-02-25
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architect
- **Date:** 2026-02-25
- **Notes:** PRD complete and approved by lore-master.
  Three deliverables: NPC backstory seeding (80-110 overrides), quest hint
  system (20-30 Tier 2 scripts), soul element framework (Layer 6 of prompt
  assembler). Lore-master review identified 2 corrections (Elisi Nasin class
  error, Leatherfoot Tales naming) — both resolved. Key design decisions:
  6 personality axes, deity alignment rules, faction political constraints,
  anti-flattening as explicit goal. 6 open questions for architect
  (soul storage format, quest hint injection, say-link compatibility,
  hot-reload, quest state passing, NPC deity lookup).

### architect → implementation team
- **Date:** 2026-02-25
- **Notes:** Architecture plan complete. All 6 open questions resolved:
  1. Soul data in separate `soul_elements.json` (different authoring cadence)
  2. Quest hints as Layer 5.5 with separate `LLM_BUDGET_QUEST_HINTS=150` budget
  3. `AutoInjectSaylinksToSay` handles [brackets] automatically (confirmed with protocol-agent)
  4. POST `/v1/config/reload` endpoint for hot-reload (no file-watcher dependency)
  5. Script-side quest state construction (keeps sidecar simple)
  6. `e.self:GetDeity()` in Lua context builder (method exists, field exists in ChatRequest)

  **No C++ changes, no database changes, no protocol changes.**
  
  7 implementation tasks assigned to 3 experts:
  - **sidecar-expert** (Tasks 1-3): SoulElementProvider, prompt assembler L5.5+L6, config reload, docker-compose
  - **lua-expert** (Tasks 4-5): llm_bridge extension, 20-30 Tier 2 quest scripts
  - **content-author** (Tasks 6-7): 80-110 backstories, 30-50 soul element entries

---

## Implementation Tasks

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Create SoulElementProvider + soul_elements.json config | sidecar-expert | Complete | 2026-02-25 |
| 2 | Extend ChatRequest + prompt assembler (L5.5 quest hints + L6 soul) | sidecar-expert | Complete | 2026-02-25 |
| 3 | Add /v1/config/reload endpoint + docker-compose updates | sidecar-expert | Complete | 2026-02-25 |
| 4 | Extend llm_bridge.lua (npc_deity, build_quest_context) | lua-expert | Complete | 2026-02-25 |
| 5 | Upgrade 20-30 quest scripts to Tier 2 | lua-expert | Complete | 2026-02-25 — 28 scripts upgraded |
| 6 | Author 80-110 NPC backstory overrides | content-author | Complete | 2026-02-25 — 137 overrides delivered (all 15 cities) |
| 7 | Author soul element data for key NPCs | content-author | Complete | 2026-02-25 — 70 overrides + 4 role defaults; duplicates resolved, NPC 1077 corrected 2026-02-26 |

---

## Open Questions

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Soul element storage format | game-designer | architect | **Resolved** | Separate `soul_elements.json` file |
| 2 | Quest hint injection layer position | game-designer | architect | **Resolved** | Layer 5.5 (between faction and soul), separate budget |
| 3 | Say-link auto-injection compatibility | game-designer | architect | **Resolved** | AutoInjectSaylinksToSay handles it automatically |
| 4 | Hot-reload mechanism | game-designer | architect | **Resolved** | POST `/v1/config/reload` endpoint |
| 5 | Quest state passing approach | game-designer | architect | **Resolved** | Script-side construction |
| 6 | NPC deity lookup method | game-designer | architect | **Resolved** | Lua `e.self:GetDeity()` + existing ChatRequest field |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| Container not restarted after code deployment — LLM_BUDGET_SOUL=0, /v1/config/reload=404, soul elements inactive | game-tester | 2026-02-25 | 2026-02-26 — container restarted, all env vars active |
| NPC ID 1077 (Danon Fletcher, merchant) has Captain Tillin backstory+soul — wrong NPC | game-tester | 2026-02-25 | 2026-02-26 — soul elements corrected to merchant traits |
| soul_elements.json has 5 duplicate keys (9100, 75075, 42019, 82044, 155151) — json.load silently discards first | game-tester | 2026-02-25 | 2026-02-26 — verified resolved (only single entries exist) |

---

## Decision Log

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | 6 personality axes (added Loyalty) | game-designer + lore-master | 2026-02-25 | Faction commitment is critical for EQ political dynamics |
| 2 | Deity alignment rules mandatory | game-designer + lore-master | 2026-02-25 | NPCs must have soul traits consistent with deity values |
| 3 | City-specific guard identity | game-designer + lore-master | 2026-02-25 | Each city's guard force has distinct faction identity |
| 4 | Anti-flattening as explicit goal | game-designer + lore-master | 2026-02-25 | Soul system must preserve racial/cultural differentiation |
| 5 | Elisi Nasin → Maesyn Trueshot | lore-master | 2026-02-25 | Elisi is a Rogue GM, not Ranger. Maesyn is correct Ranger GM. |
| 6 | Soul elements in separate file | architect + config-expert | 2026-02-25 | Different authoring cadence; cleaner separation from backstories |
| 7 | Quest hints as Layer 5.5 | architect + config-expert | 2026-02-25 | Between faction and personality; separate budget for independent truncation |
| 8 | Reload endpoint over file-watching | architect + config-expert | 2026-02-25 | No dependency; explicit; testable; supports content author workflow |
| 9 | NPC deity via Lua GetDeity() | architect | 2026-02-25 | Method exists on Lua_Mob; field exists in ChatRequest; zero C++ changes |
| 10 | AutoInjectSaylinksToSay handles keywords | architect + protocol-agent | 2026-02-25 | Rule defaults true; no extra Lua processing needed |
| 11 | No protocol/C++ changes needed | architect + protocol-agent | 2026-02-25 | Entire feature is sidecar + Lua + config |

---

## Handoff Log (continued)

### implementation team → game-tester
- **Date:** 2026-02-25
- **Notes:** Server-side validation run. 29/29 checks PASS or PASS-with-caveats. 3 blockers found:
  1. CRITICAL: Container not restarted after Phase 3 deployment — soul elements disabled, reload endpoint 404
  2. HIGH: NPC ID 1077 (Danon Fletcher) incorrectly assigned Captain Tillin backstory/soul
  3. MEDIUM: 5 duplicate keys in soul_elements.json — content-author to deduplicate
  All 31 Tier 2 Lua scripts pass syntax. 15/15 regression tests pass.
  In-game testing blocked until container restart + blockers 2/3 fixed.

---

## Completion Checklist

_Filled in after game-tester validation passes._

- [x] All implementation tasks marked Complete
- [x] No open Blockers (all 3 resolved 2026-02-26)
- [ ] game-tester validation: server-side PASS, in-game testing ready
- [ ] Feature branch merged to main
- [ ] Server rebuilt (N/A — no C++ changes)
- [ ] All phases marked Complete in Workflow Status table

**Merged by:** _name_
**Merge date:** _YYYY-MM-DD_

---

## Notes

- PRD underwent two revisions: initial draft, then major revision incorporating
  lore-master's preliminary research (11 changes), then final corrections (2 fixes).
- Lore-master provided extensive racial archetype, deity, and faction reference
  material that significantly improved the PRD's specificity.
- Architecture phase confirmed zero C++/database/protocol changes needed.
  All implementation is Python sidecar + Lua scripts + JSON config content.
- Full conversation log in `agent-conversations.md`.
