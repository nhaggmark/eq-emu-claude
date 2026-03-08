# companion-levelup-fixes — Status Tracker

> **Feature branch:** `bugfix/companion-levelup-fixes`
> **Created:** 2026-03-08
> **Last updated:** 2026-03-08

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-08 | 2026-03-08 |
| Design | game-designer + lore-master | Skipped | — | — |
| Architecture | architect | Complete | 2026-03-08 | 2026-03-08 |
| Implementation | c-expert | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-08
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### architect → implementation team (c-expert)
- **Date:** 2026-03-08
- **Notes:** Architecture doc complete at `architect/architecture.md`. Bug-fix
  feature — design phase was skipped as the bug report (BUG-007) and user's
  audit request serve as the requirements. Single implementation task assigned
  to c-expert: add 2 missing packet calls (`SendHPUpdate()` and
  `SendAppearancePacket(WhoLevel)`) in `Companion::CheckForLevelUp()` to fix
  the group window disappearance issue. Fix is modeled on the bot level-up
  pattern in `bot.cpp:4015-4016`.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Add `SendHPUpdate()` and `SendAppearancePacket(WhoLevel, level, true, true)` in `CheckForLevelUp()` after SetHP/SetMana and before Save() | c-expert | Not Started | 2-line fix in companion.cpp ~line 1659 |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| | None — fix is straightforward | | | | |

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
| BUG-007 | Companion disappears from group interface on level up | Critical | user | Fix Planned | c-expert | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Fix by adding explicit packet calls in CheckForLevelUp() rather than overriding NPC::SetLevel() | architect | 2026-03-08 | More auditable, lower risk of side effects, matches bot/merc pattern exactly |
| 2 | Skip OP_GroupUpdate during level-up | architect | 2026-03-08 | SendHPUpdate + WhoLevel appearance are sufficient; full group update is only needed for member add/remove |
| 3 | Skip design phase for this bug fix | architect | 2026-03-08 | BUG-007 report + user audit request provide sufficient requirements; no game design decisions needed |

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

_Free-form notes, observations, and context._

### Audit Summary (2026-03-08)

The architect performed a thorough audit of the entire companion level-up
process, tracing every function call from `AddExperience()` through
`CheckForLevelUp()` -> `ScaleStatsToLevel()` -> `NPC::SetLevel()`.

**Root cause of BUG-007:** Two missing client notification packets:
1. `SendHPUpdate()` — HP bar update never sent to group members
2. `SendAppearancePacket(WhoLevel)` — level update never broadcast (wrong default params in NPC::SetLevel)

**States verified preserved during level-up:** Group membership, equipment,
hate list, target, follow state, stance, owner relationship, entity ID,
entity variables, buff slots, spell recast timers.

**No other bugs found** in the level-up process itself. The fix is a clean
2-line addition matching the established bot level-up pattern.
