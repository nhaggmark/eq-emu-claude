# Companion Rez — Status Tracker

> **Feature branch:** `bugfix/companion-rez`
> **Created:** 2026-04-27
> **Last updated:** 2026-04-27

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-04-27 | 2026-04-27 |
| Design | game-designer + lore-master | Complete | 2026-04-27 | 2026-04-27 |
| Architecture | architect + protocol-agent + config-expert | Not Started | | |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Architecture

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-04-27
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  BUG-001 filed at `bugs/BUG-001-cleric-rez-broken/report.md`.
  Spawn both agents as teammates for the Design phase.

### design team (game-designer + lore-master) → architect
- **Date:** 2026-04-27
- **Notes:** PRD finalized at `game-designer/prd.md` — APPROVED by
  lore-master 2026-04-27, no revisions required. Bug invariant locked
  verbatim: a Cleric NPC companion auto-rezzes downed party members
  (player + recruited NPC companions) post-combat, reliably (AC-10).
  TDD discipline locked as design constraint (AC-9). All 10 acceptance
  criteria from team-lead brief covered; Validation Plan covers all 7
  team-lead scenarios plus 5 additional regression cases. Era
  compliance reviewed and signed off (Classic-Luclin Cleric rez
  progression: Resurrection 15 / Reanimation 29 / Revive 43 /
  Resuscitate 53 / Restoration 65). Shaman rez locked as a HARD STOP
  for any future scope expansion. Necromancer / Druid / Paladin noted
  as future-scope only. Open questions remaining are all
  architect-domain (post-combat delay N value, NPC corpse rez
  confirmation gap, tier preference policy, multi-target ordering,
  quest-NPC edge case, TDD test-scope mapping). Lore-master sign-off
  recorded in `lore-master/lore-notes.md` and exchanges logged in
  `agent-conversations.md`. Architect inherits a clean PRD with no
  lore blockers and a clear AC-10 reliability contract.

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
| 1 | What is N — post-combat delay before Cleric scans for corpses? | game-designer | architect | Open | Architect to define and document in arch plan |
| 2 | NPC corpse rez confirmation gap: auto-accept server-side, bypass rez request, or other approach? | game-designer (BUG-001) | architect | Open | Architect investigates RezzPlayer / OP_RezzAnswer / OP_RezzRequest flow |
| 3 | Rez tier preference policy (highest affordable vs. other) | game-designer | architect | Open | Architect picks; PRD requires policy is documented |
| 4 | Multi-target ordering policy (player-first / tank-first / discovery-order) | game-designer | architect | Open | Architect picks |
| 5 | Cleric OOM flavor chat line — silent or one-time line? | game-designer | lore-master | RESOLVED 2026-04-27 | Silent. Out of scope for this fix; polish pass may revisit |
| 6 | Quest-NPC rez interaction (rezzing an NPC who is also a kill target / quest-state node) | game-designer | architect | Open | Architect-awareness flag; not a scope expansion |
| 7 | TDD test-scope mapping (unit / integration / game-tester per scenario) | game-designer | architect | Open | Architect translates Validation Plan scenarios to test types |

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
| BUG-001 | Cleric companion attempts rez post-combat but NPC companion stays down | High | user | Investigating | architect (Phase 3) | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | No deity / race / alignment restrictions on Cleric rez targets | game-designer + lore-master | 2026-04-27 | Not enforced in Classic mechanics; UX pain on 1-3 player server |
| 2 | Shaman rez is a permanent HARD STOP for any future scope expansion | lore-master | 2026-04-27 | No Shaman rez in Classic-Luclin — era violation if added |
| 3 | Necromancer rez is conditional / out of current scope | lore-master | 2026-04-27 | In-era but mechanically distinct (damaged corpse / XP penalty); not part of this fix |
| 4 | Cleric OOM behavior is silent (no flavor chat output) | lore-master | 2026-04-27 | EQ NPC terseness; flavor lines out of scope for this fix |
| 5 | TDD discipline locked as design constraint (AC-9) | game-designer | 2026-04-27 | Pattern-match to companion-rerecruit; machine-verified invariant |
| 6 | AC-10 reliability bar: every prereq-met rez attempt MUST succeed | game-designer | 2026-04-27 | Closes BUG-001 verbatim user pain ("attempting to rez but nothing happens") |
| 7 | Mid-combat rez initiation explicitly disallowed (AC-8) | game-designer | 2026-04-27 | Rezzed targets re-die instantly; better to spend Cleric mana on heals/CC |
| 8 | Bug Reports table — BUG-001 status updated from Open to Investigating | game-designer | 2026-04-27 | PRD locks the invariant; architect now triages root cause |

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
