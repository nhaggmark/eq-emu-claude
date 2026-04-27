# XP Retune — Status Tracker

> **Feature branch:** `feature/xp-retune`
> **Created:** 2026-04-27
> **Last updated:** 2026-04-27

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-04-27 | 2026-04-27 |
| Design | game-designer + lore-master | Not Started | | |
| Architecture | architect + protocol-agent + config-expert | Not Started | | |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Design

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-04-27
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

  **Feature brief seeded from brainstorming:**
  Reduce kill XP multiplier from 3.0x to 2.0x while keeping AA XP at 3.0x.
  The original server-wide 3x XP boost is leveling players too fast.
  Scope is a pure `rule_values` UPDATE — no rebuild needed; `#reloadrules` applies it live.

  **Confirmed scope:**
  - `Character:ExpMultiplier`: 3.0 → 2.0
  - `Character:AAExpMultiplier`: stays 3.0
  - All other XP rules untouched (group, raid, hotzone, level_exp_mods, death loss, companion XP)

  **Config-expert audit findings (pre-confirmed):**
  - Active ruleset_id = 1 ("default")
  - Group/raid bonuses at EQEmu defaults
  - Death XP loss at 1.5%/death (already softened vs 3.5% default — keep)
  - Levels 66–70 braked via level_exp_mods (intentional era-lock pacing — keep)
  - HotZone bonus at default +0.75x (keep)
  - Companion XP rules custom but unrelated (keep)

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
| | | | | | | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Kill XP reduced 3.0x → 2.0x; AA XP stays 3.0x | user | 2026-04-27 | Kill XP was leveling players too fast; AA grind should stay accelerated |
| 2 | Pure rule_values UPDATE; no C++ rebuild | user | 2026-04-27 | No code change needed; #reloadrules applies live |

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
