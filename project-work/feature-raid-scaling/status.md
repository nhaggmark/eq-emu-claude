# Raid Scaling — Status Tracker

> **Feature branch:** `feature/raid-scaling`
> **Created:** 2026-04-21
> **Last updated:** 2026-04-21

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-04-21 | 2026-04-21 |
| Design | game-designer + lore-master | Not Started | | |
| Architecture | architect + protocol-agent + config-expert | Not Started | | |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Design

---

## Phase Notes

### IMPORTANT: Phase 1 is an AUDIT phase

The game-designer's first deliverable is **not code changes** — it is a
comprehensive scaling-status document cataloging every raid boss and raid-tier
quest chain across Classic through Luclin, with its current scaling state:

- Scaled by prior pass
- Partially scaled
- Untouched
- Special-case (requires unique handling)

**Prior work reference:** Overland/group content has an existing scaling pass.
The audit MUST cross-reference it to identify gaps where raid content was missed
or only partially addressed.

**USER DECISION GATE after Phase 1:** After the audit document is delivered and
approved, the user must be consulted before proceeding to Phase 2 (Classic raids).
The user will decide whether to continue as one sustained effort or split the era
phases (Classic, Kunark, Velious, Luclin) into separate projects.

### Phased delivery plan

| Phase | Scope | Status |
|-------|-------|--------|
| Phase 1 — Audit | All raid bosses + raid quest chains catalogued with scaling status | Not Started |
| Phase 2 — Classic | Fear, Hate, Sky, Nagafen, Vox, dragons + Classic epic steps | Not Started |
| Phase 3 — Kunark | Trakanon, Veeshan's Peak + Kunark epic steps | Not Started |
| Phase 4 — Velious | NToV, ToV, Kael, Sleeper's Tomb, AoW, Velious dragons | Not Started |
| Phase 5 — Luclin | Ssraeshza, Vex Thal, Luclin raid content | Not Started |

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-04-21
- **Notes:** Workspace created. Feature brief at `feature-brief.md`. PRD template
  ready at `game-designer/prd.md`. Phase 1 deliverable is an audit document, not
  code. Spawn both agents as teammates for the Design phase.

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
| 1 | After Phase 1 audit: continue as one project or split into per-era projects? | bootstrap-agent | user | Pending — review after Phase 1 deliverable | |

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
| 1 | Deliver as phased project; Phase 1 is audit-only | user | 2026-04-21 | Scope too large for single pipeline run; audit first to understand gap before committing to full implementation |
| 2 | Trash/named mobs untouched; only raid bosses scaled | user | 2026-04-21 | Current named difficulty feels good; only raid tier needs adjustment |
| 3 | Loot tables unchanged; respawn timers reduced to 6-24h range | user | 2026-04-21 | Keep loot piñata feel; reduce lockout friction for small group |

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
