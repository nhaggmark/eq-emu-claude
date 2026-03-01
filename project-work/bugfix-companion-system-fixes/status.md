# Companion System Bug Fixes — Status Tracker

> **Feature branch:** `bugfix/companion-system-fixes`
> **Created:** 2026-03-01
> **Last updated:** 2026-03-01

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-01 | 2026-03-01 |
| Design | game-designer + lore-master | Complete | 2026-03-01 | 2026-03-01 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-03-01 | 2026-03-01 |
| Implementation | c-expert + lua-expert | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-01
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.

### design team → architect
- **Date:** 2026-03-01
- **Notes:** Bug-fix PRD completed and approved by lore-master. Documents three
  companion system bugs: (1) LLM chat non-functional — sidecar integration
  path broken, (2) equipment display — visual model doesn't update due to
  dual equipment array issue, (3) equipment persistence — LoadEquipment()
  never called despite being fully implemented. Bugs 2 and 3 interact:
  both must be fixed for equipment to work end-to-end. Bug 1 is independent.
  See `game-designer/prd.md` for full details, repro steps, and acceptance
  criteria. Research notes in `game-designer/context/research-notes.md`.

### architect → implementation team (c-expert + lua-expert)
- **Date:** 2026-03-01
- **Notes:** Architecture plan complete at `architect/architecture.md`.
  Three implementation tasks:
  1. **Task 1 → c-expert:** Fix equipment display — override
     `GetEquipmentMaterial()` and `GetEquippedItemFromTextureSlot()` in
     Companion class, sync `NPC::equipment[]` in GiveItem/RemoveItemFromSlot
  2. **Task 2 → c-expert:** Fix equipment persistence — call
     `LoadEquipment()` from `Load()`, sync `NPC::equipment[]` in LoadEquipment
  3. **Task 3 → lua-expert:** Diagnose and fix LLM chat — sidecar is
     confirmed healthy (config-expert verified), failure is in Lua code path
     (`llm_bridge.lua` `generate_response()`), must diagnose root cause and
     fix, plus add server-log error visibility
  
  Key findings from advisor consultations:
  - protocol-agent: No Titanium constraints. OP_WearChange works for NPC=0
    entities. All 9 material slots valid. Spawn packet handles zone-in visuals
    once equipment[] is correct.
  - config-expert: No existing rules address these bugs. Sidecar IS healthy
    and reachable — Bug 1 is a Lua code issue, not infrastructure.

---

## Implementation Tasks

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Fix equipment display (override GetEquipmentMaterial, sync arrays) | c-expert | Not Started | ~50 lines C++ in companion.h and companion.cpp |
| 2 | Fix equipment persistence (call LoadEquipment from Load, sync arrays) | c-expert | Not Started | ~10 lines C++ in companion.cpp. Depends on Task 1. |
| 3 | Diagnose and fix LLM chat (find failure in llm_bridge.lua, fix it, add logging) | lua-expert | Complete | Added eq.log(87) at all nil-return paths + os.execute fallback for io.popen=nil. Syntax checked. End-to-end tested in luajit. |

---

## Open Questions

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Is the LLM sidecar container currently running? | game-designer | architect | Resolved | Yes — config-expert verified: container healthy, DNS resolves (172.18.0.9), health endpoint OK, model loaded. Bug is in Lua code, not infrastructure. |
| 2 | Should Companion override GetEquipmentMaterial() or sync to NPC::equipment[]? | game-designer | architect | Resolved | Both: override for correct virtual dispatch + sync as belt-and-suspenders. See architecture.md. |
| 3 | Does the spawn packet handle equipment visuals if arrays are populated before spawn? | game-designer | architect | Resolved | Yes — protocol-agent confirmed. FillSpawnStruct calls GetEquipmentMaterial per slot. Once override/sync is in place, spawn packet carries correct materials. No extra WearChange needed. |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| | | | |

---

## Bug Reports

_Bugs discovered during testing or play. Status flow:
Open → Investigating → Fix In Progress → Resolved._

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| 1 | LLM Chat — companions show thinking emote but never respond | High | user | Fix In Progress | lua-expert | |
| 2 | Equipment Display — traded items don't visually appear on companion | High | user | Fix In Progress | c-expert | |
| 3 | Equipment Persistence — equipment lost on zone/relog | High | user | Fix In Progress | c-expert | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Bug-fix PRD approved with no lore concerns | game-designer + lore-master | 2026-03-01 | Pure technical fixes, no narrative changes, era compliance confirmed |
| 2 | All three bugs require code-level fixes (no config alternatives) | config-expert + architect | 2026-03-01 | 22 Companions rules checked — none cover equipment display, persistence, or LLM. Sidecar verified healthy. |
| 3 | Override GetEquipmentMaterial + sync NPC::equipment[] (dual approach) | architect | 2026-03-01 | Virtual override ensures correct rendering pipeline. Sync catches direct equipment[] access. Better than alternatives (drop m_equipment, write-only). |
| 4 | Implementation team: c-expert + lua-expert only | architect | 2026-03-01 | Minimal team — 2 experts for 3 tasks. No other agents needed. |

---

## Completion Checklist

### Implementation Complete (agents can check these)

_Filled in after game-tester validation passes._

- [ ] All implementation tasks marked Complete
- [ ] No open Blockers
- [ ] game-tester server-side validation: PASS
- [ ] User completed in-game testing guide: PASS
- [ ] All changes committed and pushed to feature branch in ALL repos
- [ ] Server rebuilt (if C++ changed)
- [ ] All phases marked Complete in Workflow Status table

### Merge & Cleanup (USER-INITIATED ONLY)

_These items happen ONLY when the user explicitly confirms the feature is done.
The orchestrator NEVER initiates merge or branch cleanup on its own._

- [ ] User confirmed feature is complete
- [ ] Feature branch merged to main in ALL affected repos
- [ ] Main pushed to origin in ALL affected repos
- [ ] Stale feature branches deleted (local + remote)

**Merged by:** _name_
**Merge date:** _YYYY-MM-DD_

---

## Notes

_Free-form notes, observations, or context that doesn't fit above._

- Research notes from game-designer's codebase review are preserved at
  `game-designer/context/research-notes.md` for the architect's reference.
- Config-expert verified sidecar health details: container akk-stack-npc-llm-1
  is healthy, up 3+ hours. DNS resolves npc-llm → 172.18.0.9. Health endpoint
  confirms model loaded, ChromaDB connected with 6 collections.
- Protocol-agent verified: Titanium titanium_ops.h has both ENCODE (line 88)
  and DECODE (line 133) for OP_WearChange. All 9 material slots valid. NPC=0
  entities receive WearChange correctly. Spawn packet equipment fields populated
  by GetEquipmentMaterial per slot.
