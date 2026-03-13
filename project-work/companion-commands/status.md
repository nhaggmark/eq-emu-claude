# Companion Commands — Status Tracker

> **Feature branch:** `feature/companion-commands`
> **Created:** 2026-03-13
> **Last updated:** 2026-03-13

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-13 | 2026-03-13 |
| Design | game-designer + lore-master | Complete | 2026-03-13 | 2026-03-13 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-03-13 | 2026-03-13 |
| Implementation | lua-expert | Complete | 2026-03-13 | 2026-03-13 |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-13
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architecture team (architect + protocol-agent + config-expert)
- **Date:** 2026-03-13
- **Notes:** PRD approved by game-designer, lore review approved by lore-master.
  PRD at `game-designer/prd.md`, lore notes at `lore-master/lore-notes.md`.

### architect → implementation team (lua-expert)
- **Date:** 2026-03-13
- **Notes:** Architecture plan complete at `architect/architecture.md`.
  6 tasks, all assigned to lua-expert. No C++ or database changes needed.
  Task sequence: (1) !hold command, (2) !tome update, (3) !help reformat,
  (4) !help standalone routing, (5) documentation rewrite, (6) test suite.
  Tasks 1 and 2 are independent; 3-6 have sequential dependencies.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Implement !hold command (COMMANDS entry, cmd_hold handler, cmd_assist guard-break) | lua-expert | Complete | Independent, can start immediately |
| 2 | Implement !tome update (WipeHateList, SetGuardMode(false), follow mode after GMMove) | lua-expert | Complete | Independent, can start immediately |
| 3 | Implement !help reformat (alphabetical per-line output matching PRD format) | lua-expert | Complete | Depends on Task 1 (!hold in list) |
| 4 | Implement !help standalone (event_say in global_player.lua, cmd_help_standalone) | lua-expert | Complete | Depends on Task 3 |
| 5 | Rewrite companion-commands-reference.md documentation | lua-expert | Complete | Depends on Tasks 1, 2, 3 |
| 6 | Write comprehensive test suite (4 test files) | lua-expert | Complete | Depends on Tasks 1-4 |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | !help without target routing | game-designer | architect | Resolved | Use Player EVENT_SAY in global_player.lua (fires before NPC dispatch) |
| 2 | !hold mode tracking | game-designer | architect | Resolved | Track as "guard" in companion_modes + stance==0. No new mode value. |
| 3 | !tome guard-break behavior | game-designer | architect | Resolved | Yes, !tome breaks guard and sets follow mode. Consistent with cmd_recall. |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| (none) | | | |

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
| 1 | PRD lore-approved | lore-master | 2026-03-13 | All changes Classic-Luclin compliant |
| 2 | !tome naming non-blocking flag | lore-master | 2026-03-13 | Pre-existing name, not changed by this PRD |
| 3 | All changes pure Lua, no C++ | architect | 2026-03-13 | All needed bindings exist. Protocol-agent confirmed no constraints. |
| 4 | No rule changes needed | architect, config-expert | 2026-03-13 | No existing rules cover these behaviors |
| 5 | !hold = guard + passive (no new mode) | architect | 2026-03-13 | Two existing concepts suffice; no third mode value |
| 6 | !tome uses WipeHateList not SetTarget(nil) | architect | 2026-03-13 | Avoids luabind nil risk; proven safe pattern |
| 7 | !help via Player EVENT_SAY | architect | 2026-03-13 | Fires before NPC dispatch; no C++ changes needed |

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

- All 6 implementation tasks assigned to a single lua-expert agent. No C++ build
  cycle needed — changes apply via `#rq` (reload quest) in-game.
- The companion system's existing test pattern (mock-based standalone LuaJIT tests)
  is reused for the new test files.
