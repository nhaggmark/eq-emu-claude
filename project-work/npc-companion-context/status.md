# NPC Companion Context — Status Tracker

> **Feature branch:** `feature/npc-companion-context`
> **Created:** 2026-03-02
> **Last updated:** 2026-03-02

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-02 | 2026-03-02 |
| Design | game-designer + lore-master | Complete | 2026-03-02 | 2026-03-02 |
| Architecture | architect + protocol-agent + config-expert | Not Started | | |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Architecture

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-02
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architect
- **Date:** 2026-03-02
- **Notes:** PRD complete at `game-designer/prd.md`. Lore review approved by
  lore-master with one correction (Splitpaw → Sabertooth gnolls) and several
  enrichments (Vah Shir oral culture, Iksar KOS constraints, Erudite
  Erudin/Paineel distinction, Luclin fixed-lighting zones). All findings
  incorporated. PRD scope: companion context layer for LLM sidecar (identity
  shift, situational awareness, personality variation, unprompted commentary).
  5 open questions for architect to investigate.

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
| 1 | What companion state is already exposed to Lua? | game-designer | architect | Open | |
| 2 | How does the sidecar currently structure its system prompt? | game-designer | architect | Open | |
| 3 | What recent activity data is readily available? | game-designer | architect | Open | |
| 4 | Unprompted commentary implementation approach? | game-designer | architect | Open | |
| 5 | Luclin fixed-lighting zones handling? | lore-master | architect | Open | |

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
| | | | | | | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Sabertooth gnolls in West Karana (not Splitpaw) | lore-master | 2026-03-02 | Splitpaw is Southern Karana; Sabertooth operates from Blackburrow |
| 2 | Vah Shir primary threats: grimlings + Akheva | lore-master | 2026-03-02 | Shissar are distant; grimlings are the day-to-day threat |
| 3 | Vah Shir oral culture as defining personality trait | lore-master | 2026-03-02 | Banned written records, blame Erudite magic for exile |
| 4 | Iksar KOS city constraints in companion dialogue | lore-master | 2026-03-02 | Iksar are KOS in all old-world good-aligned cities |
| 5 | Erudite Erudin/Paineel origin distinction by class | lore-master | 2026-03-02 | Necromancer=Paineel, Paladin=Erudin; deeply hostile factions |

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

- Lore-master compiled comprehensive research across all 14 Classic-Luclin
  races, 15 classes, 16 deities, and relevant zones/factions. Research notes
  saved to lore-master context folder.
- Existing companion_culture.lua race framings (Ogre, Dark Elf, Iksar, Troll)
  confirmed lore-accurate by lore-master. This feature extends to remaining races.

