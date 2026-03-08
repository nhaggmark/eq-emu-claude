# companion-ai-stances — Status Tracker

> **Feature branch:** `feature/companion-ai-stances`
> **Created:** 2026-03-08
> **Last updated:** 2026-03-08

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-08 | 2026-03-08 |
| Design | game-designer + lore-master | Complete | 2026-03-08 | 2026-03-08 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-03-08 | 2026-03-08 |
| Implementation | c-expert + config-expert + lua-expert | Not Started | | |
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

### design team → architecture team (architect + protocol-agent + config-expert)
- **Date:** 2026-03-08
- **Notes:** PRD complete at `game-designer/prd.md`. Three stances
  (Passive/Balanced/Aggressive), clean break on recruitment, faction
  perspective shift. Primarily mechanical feature — minimal lore impact.

### architect → implementation team (c-expert + config-expert + lua-expert)
- **Date:** 2026-03-08
- **Notes:** Architecture document complete at `architect/architecture.md`.
  7 implementation tasks across 3 agents. Core work is rewriting
  `Companion::Process()` for stance-aware AI (c-expert). Two new rules
  (config-expert). One Lua line for passive hate list clear (lua-expert).
  Tasks 1-3 and 6 are independent and can run in parallel. Task 4 depends
  on 1-3. Task 5 depends on 4. Task 7 (build/test) depends on all others.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Add `AggressiveScanRadius` and `CompanionFleeEnabled` rules to `common/ruletypes.h` | config-expert | Not Started | 2 lines in Companions category |
| 2 | Add `IsCompanion()` guard to `Mob::CheckWillAggro()` in `zone/aggro.cpp` | c-expert | Not Started | 4 lines — prevent faction-based aggro initiation |
| 3 | Add `IsCompanion()` guard to assist timer in `zone/npc.cpp` | c-expert | Not Started | 1 line — prevent companions calling for help |
| 4 | Rewrite `Companion::Process()` for stance-aware AI | c-expert | Not Started | ~100 lines — passive/balanced/aggressive behavior |
| 5 | Add flee suppression using `CompanionFleeEnabled` rule | c-expert | Not Started | 3 lines — depends on Task 1 & 4 |
| 6 | Update `cmd_passive` in `companion.lua` to call `WipeHateList()` | lua-expert | Not Started | 1 line — belt-and-suspenders with C++ |
| 7 | Build, restart, and run manual validation | c-expert | Not Started | Depends on all other tasks |

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
| 1 | Keep NPC::Process() chain intact; add stance guards before it | architect | 2026-03-08 | ~100 lines vs 500+ line full AI override (merc approach). Simpler, less risk. |
| 2 | Two new rules: AggressiveScanRadius=75, CompanionFleeEnabled=true | architect + config-expert | 2026-03-08 | No existing rules cover stance AI; these provide runtime tunability |
| 3 | No protocol/client changes needed | architect + protocol-agent | 2026-03-08 | All stance behavior is server-side; Titanium client unaware |
| 4 | No database changes needed | architect + config-expert | 2026-03-08 | companion_data.stance column already exists |

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

### Feature Brief

Recruited NPC companions retain their original NPC AI behaviors after recruitment.
Stance commands (aggressive/balanced/passive) exist but don't override the underlying
NPC behavior. Guards keep guard-aggroing, etc.

**What we want:**
- On recruitment, companions automatically switch to "balanced" stance
- Recruitment is a clean break — all original NPC AI behavior stops
- Companions use the mercenary AI system that was co-opted for them
- The three stances actually control behavior:
  - **Aggressive** — actively seeks and engages nearby enemies
  - **Balanced** — follows player, doesn't initiate, but fights when player or companion is attacked
  - **Passive** — never fights, just follows, even if attacked

**Success criteria:** A recruited guard stops auto-aggroing nearby hostiles. Setting
them to passive means they truly do nothing in combat. Setting them to aggressive means
they intentionally seek fights. Balanced is the sensible default.
