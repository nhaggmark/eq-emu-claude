# Companion Behavior Improvements — Status Tracker

> **Feature branch:** `feature/companion-behavior-improvements`
> **Created:** 2026-03-12
> **Last updated:** 2026-03-12

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-12 | 2026-03-12 |
| Design | game-designer + lore-master | Complete (bug reports serve as PRD) | 2026-03-12 | 2026-03-12 |
| Architecture | architect + protocol-agent + config-expert | Complete (updated for BUG-026, BUG-027) | 2026-03-12 | 2026-03-12 |
| Implementation | c-expert + lua-expert | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-12
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.

### design team → architecture team (architect + protocol-agent + config-expert)
- **Date:** 2026-03-12
- **Notes:** Bug reports BUG-023, BUG-024, BUG-025 and brainstorm notes serve as
  the feature brief. No formal PRD needed — bugs are well-defined with clear
  acceptance criteria.

### architect → implementation team (c-expert + lua-expert)
- **Date:** 2026-03-12
- **Notes:** Architecture plan complete at `architect/architecture.md`. Six tasks
  assigned: Tasks 1-3, 5-6 to c-expert (rogue positioning, LOM announcement,
  LOM rule, caster LOS positioning, always meditate regen + rule), Task 4 to
  lua-expert (buff queue rewrite). All C++ tasks and the Lua task are independent
  and can be worked in parallel. After all complete: rebuild server binary and
  #reloadquest.

### architect → implementation team (UPDATE: BUG-026, BUG-027 added)
- **Date:** 2026-03-12
- **Notes:** Architecture doc updated with two additional bugs. Task 5 (BUG-026:
  caster LOS positioning in companion.cpp) and Task 6 (BUG-027: always meditate
  regen in companion.cpp + ruletypes.h) added to c-expert's workload. Both are
  independent of existing tasks.

---

## Implementation Tasks

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | BUG-023: Replace rogue backstab positioning with direct geometric calculation | c-expert | Complete | companion.cpp UpdateCombatPositioning() — committed 2026-03-12 |
| 2 | BUG-024: Add m_lom_announced flag and LOM check in Process() | c-expert | Complete | companion.h + companion.cpp — committed 2026-03-12 |
| 3 | BUG-024: Add LOMThresholdPct rule to ruletypes.h | c-expert | Complete | ruletypes.h — committed 2026-03-12 |
| 4 | BUG-025: Rewrite buff timer handler to sequential queue | lua-expert | Complete | global_npc.lua |
| 5 | BUG-026: Add LOS validation to caster/healer positioning in UpdateCombatPositioning() | c-expert | Complete | companion.cpp — committed 2026-03-12 |
| 6 | BUG-027: Remove IsSitting() gate in CalcManaRegen(), add AlwaysMeditateRegen rule | c-expert | Complete | companion.cpp + ruletypes.h — committed 2026-03-12 |

---

## Open Questions

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Does CastSpell work for NPC-to-NPC beneficial spells in group context? | architect | game-tester | Open | Flagged for testing; SpellFinished is fallback |

---

## Blockers

_None._

---

## Bug Reports

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| BUG-023 | Rogue backstab pathing too wide | Medium | user | Fix Planned | c-expert | |
| BUG-024 | Caster LOM announcement missing | Medium | user | Fix Planned | c-expert | |
| BUG-025 | !buffs only buffs player | High | user | Fix Planned | lua-expert | |
| BUG-026 | Caster companions lose LOS in indoor/confined spaces | High | user | Fix Planned | c-expert | |
| BUG-027 | Companions should always regen mana at meditation rates | High | user | Fix Planned | c-expert | |

---

## Decision Log

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | No protocol changes needed | architect | 2026-03-12 | All bugs are server-side AI/script behavior |
| 2 | Direct trigonometry replaces PlotPositionAroundTarget for rogue | architect | 2026-03-12 | PlotPositionAroundTarget calculates from wrong reference point |
| 3 | New rule Companions:LOMThresholdPct = 15 | architect | 2026-03-12 | Tunable threshold, fits between ManaCutoffPct(20%) and 0 |
| 4 | Sequential buff queue, not SpellFinished | architect | 2026-03-12 | Preserves normal casting behavior (mana cost, cast time) |
| 5 | Hardcode backstab offset, no new rule | architect | 2026-03-12 | Geometry constant, not balance tunable |
| 6 | No new rule for caster LOS checking | architect | 2026-03-12 | Correctness fix — casters should never run to blind spots |
| 7 | New rule Companions:AlwaysMeditateRegen = true | architect | 2026-03-12 | Fun-over-authenticity decision, toggleable via rule |
| 8 | LOS iteration (max 6 raycasts) has no performance concern | architect | 2026-03-12 | BSP raycasts are O(log n), aggro scanning does more |

---

## Completion Checklist

### Implementation Complete (agents can check these)

- [ ] All implementation tasks marked Complete
- [ ] No open Blockers
- [ ] game-tester server-side validation: PASS
- [ ] User completed in-game testing guide: PASS
- [ ] All changes committed and pushed to feature branch in ALL repos
- [ ] Server rebuilt (if C++ changed)
- [ ] All phases marked Complete in Workflow Status table

### Merge & Cleanup (USER-INITIATED ONLY)

- [ ] User confirmed feature is complete
- [ ] Feature branch merged to main in ALL affected repos
- [ ] Main pushed to origin in ALL affected repos
- [ ] Stale feature branches deleted (local + remote)

**Merged by:** _name_
**Merge date:** _YYYY-MM-DD_

---

## Notes

Five companion behavior bugs batched into a single feature workspace. Root causes
identified during architecture phase:
- BUG-023: PlotPositionAroundTarget calculates position from rogue, not from target
- BUG-024: No in-combat mana monitoring exists; only sitting OOC report
- BUG-025: Multiple CastSpell calls in single tick; only first succeeds due to
  casting_spell_id guard in spells.cpp
- BUG-026: Caster positioning code has no LOS validation; calculates position by
  distance only, causing casters to run behind walls in indoor zones
- BUG-027: CalcManaRegen() gates meditate formula behind IsSitting(); companions
  standing/fighting get only flat 2 mana/tick instead of ~38/tick
