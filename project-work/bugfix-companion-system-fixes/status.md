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
| Architecture | architect + protocol-agent + config-expert | Not Started | | |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Architecture

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

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| | | | | |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Is the LLM sidecar container currently running? | game-designer | architect | Open | Verify before investigating code-level LLM issues |
| 2 | Should Companion override GetEquipmentMaterial() or sync to NPC::equipment[]? | game-designer | architect | Open | Architect determines cleanest approach |
| 3 | Does the spawn packet handle equipment visuals if arrays are populated before spawn? | game-designer | architect | Open | May affect whether explicit wear change packets are needed on zone-in |

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
| 1 | LLM Chat — companions show thinking emote but never respond | High | user | Open | architect | |
| 2 | Equipment Display — traded items don't visually appear on companion | High | user | Open | architect | |
| 3 | Equipment Persistence — equipment lost on zone/relog | High | user | Open | architect | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Bug-fix PRD approved with no lore concerns | game-designer + lore-master | 2026-03-01 | Pure technical fixes, no narrative changes, era compliance confirmed |

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
