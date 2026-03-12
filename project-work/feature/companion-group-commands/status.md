# Companion Group Commands — Status Tracker

> **Feature branch:** `feature/companion-group-commands`
> **Created:** 2026-03-11
> **Last updated:** 2026-03-11 (BUG-020 resolved)

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-11 | 2026-03-11 |
| Design | game-designer + lore-master | Complete | 2026-03-11 | 2026-03-11 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-03-11 | 2026-03-11 |
| Implementation | lua-expert | Complete | 2026-03-11 | 2026-03-11 |
| Validation | game-tester | In Progress | 2026-03-11 | |
| Completion | _user_ | Not Started | | |

**Current phase:** Validation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-11
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architecture team (architect + protocol-agent + config-expert)
- **Date:** 2026-03-11
- **Notes:** PRD complete at `game-designer/prd.md`. Lore review approved at
  `lore-master/dev-notes.md`. One lore note for architect: !equipmentupgrade
  responses must be static formatted output, not LLM-routed.

### architect → implementation team (lua-expert)
- **Date:** 2026-03-11
- **Notes:** Architecture plan complete at `architect/architecture.md`.
  Pure Lua implementation — no C++ changes, no database changes, no new rules.
  All 5 tasks assigned to lua-expert. Tasks 1-4 are independent (separate
  handler functions), Task 5 depends on all of them (COMMANDS table + help text).
  Only spawn lua-expert for the implementation phase.

### implementation team → game-tester
- **Date:** 2026-03-11
- **Notes:** All 5 tasks complete. Committed in efe7593 on feature/companion-group-commands.
  2 files changed: companion.lua (+609/-106 lines), global_npc.lua (+124 lines).
  Server-side validation: PASS WITH WARNINGS.
  1 warning: IsSitting() not bound in Lua API (cmd_status always shows "Standing").
  Non-blocking. In-game testing guide available at game-tester/test-plan.md.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Implement !status (enhanced), !help (updated), !equipmentmissing, !follow (enhanced feedback) | lua-expert | Complete | Committed in efe7593 |
| 2 | Implement !tome, !flee, !assist (enhanced with auto-stance), !follow confirmation | lua-expert | Complete | Committed in efe7593 |
| 3 | Implement !buffme, !buffs with timer-based buff queue | lua-expert | Complete | Committed in efe7593 |
| 4 | Implement !equipmentupgrade with item link parsing and stat comparison | lua-expert | Complete | Committed in efe7593 |
| 5 | Update COMMANDS table and cmd_help reference card | lua-expert | Complete | Committed in efe7593 |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| | | | | | |

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
| 1 | IsSitting() not bound in Lua — cmd_status always shows "Standing" | Low | game-tester | Resolved | c-expert | 2026-03-11 |
| BUG-019 | Wizard companion spams DS spell out-of-combat | Medium | user | Resolved | c-expert | 2026-03-11 |
| BUG-020 | Companion NPCs cast buff spells while sitting/meditating | High | user | Resolved | c-expert | 2026-03-11 |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Pure Lua implementation — no C++ changes | architect | 2026-03-11 | All needed methods already exposed to Lua API; avoids rebuild cycle |
| 2 | No new rule values — thresholds hardcoded in Lua | architect | 2026-03-11 | 10% mana OOM and 50-unit proximity are game design constants, not tunables |
| 3 | Timer-based buff queue instead of C++ AI modification | architect | 2026-03-11 | Entity variable + Lua timer avoids touching companion_ai.cpp |
| 4 | !equipmentupgrade responses are static output, not LLM-routed | architect | 2026-03-11 | Resolves lore-master's concern; avoids racial voice constraint complexity |
| 5 | @all !help deduplication via data bucket with 1s TTL | architect | 2026-03-11 | Only first companion responds; prevents chat flood |
| 6 | Only lua-expert needed for implementation | architect | 2026-03-11 | All changes are in companion.lua + global_npc.lua timer handler |

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

- Architecture team consulted both protocol-agent and config-expert. Both
  confirmed no blocking constraints. Config-expert recommended 2 new rules
  but architect overrode — see agent-conversations.md for full rationale.
- !flee hate retention is intentional (confirmed by lore-master and architect).
- GroupChatAddressingEnabled must be true for @name/@all path to work.
