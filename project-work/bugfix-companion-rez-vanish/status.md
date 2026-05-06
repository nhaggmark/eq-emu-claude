# Companion Rez Vanish — Status Tracker

> **Feature branch:** `bugfix/companion-rez-vanish`
> **Created:** 2026-05-03
> **Last updated:** 2026-05-03

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-05-03 | 2026-05-03 |
| Design | game-designer | Complete | 2026-05-03 | 2026-05-03 |
| Architecture | architect + protocol-agent + config-expert | Next | | |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Architecture

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-05-03
- **Notes:** Workspace created. Bug report BUG-001 filed at
  `bugs/BUG-001-companion-rez-vanish/report.md`. PRD template ready at
  `game-designer/prd.md`. Spawn both agents as teammates for the Design phase.

### design team (game-designer) → architect
- **Date:** 2026-05-03
- **Notes:** PRD finalized at `game-designer/prd.md`. Documents observed
  vs expected behavior, two independent repro plans (time-only and
  zone-only) per team-lead spec, a combined sustained-play repro backing
  AC-5, and seven acceptance criteria covering time persistence, zone
  persistence, command parity, no-regression on prior companion-rez/
  re-recruit fixes, sustained-play resilience, observable log-line
  signal, and full repro retirement.
  - **Out of scope explicitly enumerated:** auto-rez configurability,
    rez UI, player-extendable rez timer, cross-companion-rez expansion,
    rez XP/sickness/effectiveness changes.
  - **User's hypothesis** (uncleared death-timer / despawn clock on
    rez) flagged as priority-1 question for the architect. Six other
    open questions logged for triage.
  - **Lore review:** N/A — no narrative/lore content in this bug fix.
    Lore-master not on the team for this bug-fix workspace per
    team-lead instruction.
  - **Adjacent prior work** (cb95baa41, 83a96f655, 17662d4ba, 035d33348,
    84ac6a204, 478d154bf, akk-stack e230ee3) flagged in the PRD's
    Technical Notes appendix for the architect to review.
  - **Candidate affected systems:** C++ server source (companion
    lifecycle, death timers, rez handler) + Lua quest scripts
    (companion.lua, lua_modules). Architect to confirm during triage.

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
| 1 | Is there a death-timer / corpse reaper / despawn clock on the dead companion entity that is NOT cleared on rez success? (User's hypothesis, priority-1) | game-designer | architect | Open | |
| 2 | Is the bug time-triggered, zone-triggered, or both? Repro plan covers each path independently. | game-designer | architect | Open | |
| 3 | Does the rez code path clear all "dead" state (Dismiss flag, follow state, group slot, name-based lookup keys) per the bugfix/companion-rerecruit invariants? | game-designer | architect | Open | |
| 4 | Is this a regression from the recent merged companion-rez/rerecruit fixes, or has it existed since the autonomous rez feature first merged (cb95baa)? | game-designer | architect | Open | |
| 5 | Is the bug deterministic on every rez, or intermittent? Repro plan assumes deterministic — flag if not. | game-designer | architect / game-tester | Open | |
| 6 | If a despawn timer is the culprit, is it the same timer used for un-rezzed dead companions whose corpses naturally decay? | game-designer | architect | Open | |
| 7 | Does the vanish leave artifacts in `data_buckets`, `character_corpses`, etc., that distinguish "scheduled despawn fired" from "group eviction" from "entity destroyed"? | game-designer | architect / data-expert | Open | |

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
| BUG-001 | Rez'd NPC companion vanishes from group a few minutes after rez | High | User (player), 2026-05-05 | Open — PRD ready for architect triage | architect (next) | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Lore-master excluded from design team for this bug fix | team-lead → game-designer | 2026-05-03 | No lore/narrative content in a behavior bug fix; design team is game-designer solo |
| 2 | Repro plan splits time-only and zone-only paths into independent scenarios (Repro A and Repro B), with a combined sustained-play scenario (Repro C) backing AC-5 | game-designer | 2026-05-03 | User could not confirm which trigger fired; fix must address both paths and tester must independently verify both |
| 3 | AC-6 requires an explicit log-line signal that the death-timer / despawn clock was cleared on rez | game-designer | 2026-05-03 | Future regressions of this exact bug class need to be detectable from logs, not just from manual play observation |

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

- Design phase did not coordinate with lore-master because this bug
  fix has no narrative/lore content. Per team-lead instruction,
  lore-master is not on the design team for this workspace.
  `agent-conversations.md` Design Team section is intentionally empty.
