# npc-companion-realistic-stats — Status Tracker

> **Feature branch:** `feature/npc-companion-realistic-stats`
> **Created:** 2026-03-10
> **Last updated:** 2026-03-10

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-10 | 2026-03-10 |
| Design | game-designer + lore-master | Complete | 2026-03-10 | 2026-03-10 |
| Architecture | architect + protocol-agent + config-expert | Not Started | | |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Architecture

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-10
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architect
- **Date:** 2026-03-10
- **Notes:** PRD complete at `game-designer/prd.md`. Lore-master review: approved
  (purely mechanical changes, no lore implications). PRD covers 5 phases:
  Phase 1 (weapon damage/delay), Phase 2 (combat skills + damage bonus + triple attack),
  Phase 3 (STA-to-HP + sitting regen + defense AC divisor), Phase 4 (spell AI tuning),
  Phase 5 (resist caps + focus effects + balance pass). Primary input document:
  `improved-companion-stats/architect/context/companion-mechanics-reference.md`
  (22-item gap table). 6 open questions for architect investigation. 9 suggested
  new rule names for tunability.

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
| 1 | Monk fist damage scaling — use npc_types or monk H2H table? | game-designer | architect | Open | |
| 2 | Weapon ratio validation — sanity bounds needed? | game-designer | architect | Open | |
| 3 | Skill data source — reuse skill_caps table or companion-specific? | game-designer | architect | Open | |
| 4 | Focus effect code path — does Mob focus apply to companions? | game-designer | architect | Open | |
| 5 | Spell AI thresholds — data-driven or code-driven? | game-designer | architect | Open | |
| 6 | Attack path divergence risk — override vs IsCompanion() branch? | game-designer | architect | Open | |

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
| 1 | Phase order: weapons first, then skills, then survivability | game-designer | 2026-03-10 | Weapon damage/delay is the highest-impact gap and the foundation for damage bonus (Phase 2). Skills must be in place before defense divisor change is meaningful (Phase 3). |
| 2 | Fallback to npc_types when no weapon equipped | game-designer | 2026-03-10 | Preserves monk unarmed combat, freshly-recruited companion behavior, and prevents regression. |
| 3 | Phase 4 (spell AI) is independent of Phases 1-3 | game-designer | 2026-03-10 | Spell AI tuning is behavioral, not dependent on stat/combat mechanics. Can be parallelized. |
| 4 | Target companion power: 70-85% of player character | game-designer | 2026-03-10 | Effective enough for group roles, preserves player edge. Multiple tuning knobs available. |

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

- Primary reference: `improved-companion-stats/architect/context/companion-mechanics-reference.md`
- The companion system's dual identity (IsNPC()=true AND IsOfClientBot()=true) is a key
  architectural constraint that affects how changes should be implemented.
- This feature is expected to significantly increase companion effectiveness when well-geared.
  The StatScalePct rule and other tuning knobs provide safety valves.
