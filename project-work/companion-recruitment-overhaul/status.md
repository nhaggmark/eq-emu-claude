# Companion Recruitment & Re-recruitment Overhaul — Status Tracker

> **Feature branch:** `feature/companion-recruitment-overhaul`
> **Created:** 2026-03-14
> **Last updated:** 2026-03-14

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-14 | 2026-03-14 |
| Design | game-designer + lore-master | Complete | 2026-03-14 | 2026-03-14 |
| Architecture | architect + protocol-agent + config-expert | Not Started | | |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Architecture

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-14
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architect
- **Date:** 2026-03-14
- **Notes:** PRD complete and approved. Lore-master sign-off confirmed (no lore
  concerns). PRD at `game-designer/prd.md`. Scope summary:
  - Two-track recruitment system: first-time (full checks) vs re-recruitment
    (bypasses cooldown, level range, faction, persuasion roll)
  - Primary change in Lua (`companion.lua:attempt_recruitment()`)
  - C++ `CreateFromNPC()` already handles re-recruitment correctly
  - Mandatory Lua/C++ contract alignment gate before implementation
  - Comprehensive acceptance criteria covering 7 test categories

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
| 1 | Should is_suspended=1 with cur_hp > 0 (zoned-out alive companion) also bypass checks? | game-designer | architect | Open | Recommendation: yes |
| 2 | Should re-recruitment work from any NPC of same npc_type_id? | game-designer | architect | Open | Recommendation: yes (current behavior) |
| 3 | Edge case: two NPCs of same npc_type_id, one recruited then dies, recruit the other? | game-designer | architect | Open | CreateFromNPC should handle correctly |

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
| 1 | Two-track recruitment system (first-time vs re-recruitment) | game-designer | 2026-03-14 | Separates first-time checks from re-recruitment to solve blocking issues |
| 2 | Re-recruitment bypasses ALL first-time checks (cooldown, level, faction, roll) | game-designer | 2026-03-14 | Companion already has established relationship; natural friction (travel, lost buffs) is sufficient |
| 3 | "I remember you" narrative framing approved by lore-master | game-designer + lore-master | 2026-03-14 | Consistent with Classic-era NPC memory conventions |
| 4 | No cost or delay on re-recruitment | game-designer | 2026-03-14 | Small-group server; death is already punishment enough |

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

Companion Recruitment & Re-recruitment Overhaul — Fix re-recruitment blocking issues (cooldowns, flags, level caps) so previously recruited companions can always be re-recruited. Enforce Lua/C++ contract alignment.
