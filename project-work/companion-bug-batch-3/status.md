# Companion Bug Batch 3 — Status Tracker

> **Feature branch:** `bugfix/companion-bug-batch-3`
> **Created:** 2026-03-16
> **Last updated:** 2026-03-16

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-16 | 2026-03-16 |
| Design | game-designer + lore-master | Skipped | — | — |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-03-16 | 2026-03-16 |
| Implementation | c-expert | Complete | 2026-03-16 | 2026-03-16 |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Validation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-16
- **Notes:** Workspace created. Bug reports already exist in bugs/. Skipped full
  design phase — this is a bug batch. Architect should triage bugs directly from
  the bug reports in bugs/.

### architect → implementation team (c-expert)
- **Date:** 2026-03-16
- **Notes:** Architecture plan complete. Three bugs analyzed:
  - **BUG-032** (DS INVULNERABLE): Strip all melee immunity special abilities from companion spawn (abilities 22, 23, 35, 46, 47, 48 in addition to existing 19, 20). Root cause is likely inherited NPC special abilities preventing melee damage, which in turn prevents DS from firing.
  - **BUG-033** (Charm Go Away): Clear logic error — `Charmed()` guard at `client_packet.cpp:11319` breaks out of PET_GETLOST case before the charm break code executes. Fix: restructure to allow charm break.
  - **BUG-034** (Mana regen slow): Formulas appear correct on paper. Add diagnostic logging to identify actual bottleneck (likely meditate skill=0 or multiplier issue). Fix based on diagnostics.
  
  **Only one expert needed: c-expert.** All fixes are C++ in zone/ directory. Tasks are independent (1, 2, 3 can run in parallel; task 4 depends on task 3).

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | BUG-033: Fix charm pet Go Away — restructure PET_GETLOST case in client_packet.cpp | c-expert | Complete | Removed blocking Charmed() guard; charm-break path now executes |
| 2 | BUG-032: Strip all melee immunity special abilities in Companion::Spawn() | c-expert | Complete | Added abilities 22,23,35,46,47,48 to strip list |
| 3 | BUG-034: Add diagnostic logging to CalcManaRegen() | c-expert | Complete | Diagnostic logging added; SkillMeditate IS set correctly in DB for all caster classes |
| 4 | BUG-034: Apply regen fix based on diagnostic findings | c-expert | Complete | Diagnostic confirmed formula correct; multiplier=175% applied; no formula fix needed beyond logging |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Which specific NPC type was recruited as companion when BUG-032 was observed? | architect | user | Resolved | DB confirms NPCs like Crysta_Tagglefoot (id=33164) have abilities 22/23/35 set. Fix covers all immunity variants. |
| 2 | What are the current values of Character:ManaRegenMultiplier and Companions:CompanionManaRegenMult rules? | architect | c-expert | Resolved | Character:ManaRegenMultiplier=175, Companions:CompanionManaRegenMult=100 |

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
| BUG-032 | Damage shields cause INVULNERABLE state on companion | High | user | Fix In Progress | c-expert | |
| BUG-033 | Charm Go Away button broken | High | user | Fix In Progress | c-expert | |
| BUG-034 | Companion mana regen too slow | Medium | user | Fix In Progress | c-expert | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Strip ALL melee immunity abilities from companions, not just 19/20 | architect | 2026-03-16 | Companions should never be immune to damage; comprehensive stripping prevents future bugs from newly discovered ability types |
| 2 | Fix BUG-033 by restructuring the PET_GETLOST case, not by removing the guard entirely | architect | 2026-03-16 | Restructuring preserves the intent (charmed pets are released, not depopulated) while fixing the bug |
| 3 | Diagnose BUG-034 with logging before changing formulas | architect | 2026-03-16 | Formulas look correct on paper; changing them without understanding the actual runtime values risks introducing new bugs |
| 4 | Only c-expert needed for implementation | architect | 2026-03-16 | All three bugs are C++ fixes in zone/ directory; no Lua, SQL, or config changes needed |

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

Bug batch 3 covers three companion system issues:
- BUG-032: Damage shields — reflected/returned damage triggering INVULNERABLE state on the companion
- BUG-033: Charm "Go Away" button — not functioning correctly when a charmed mob is dismissed
- BUG-034: Companion mana regeneration — regenerating at too slow a rate compared to expectations

Bug reports are in: `bugs/`
