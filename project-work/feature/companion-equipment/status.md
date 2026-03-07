# Companion Equipment Management Enhancement — Status Tracker

> **Feature branch:** `feature/companion-equipment`
> **Created:** 2026-03-07
> **Last updated:** 2026-03-07

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-07 | 2026-03-07 |
| Design | game-designer + lore-master | Complete | 2026-03-07 | 2026-03-07 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-03-07 | 2026-03-07 |
| Implementation | config-expert, data-expert, c-expert, lua-expert | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-07
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Design doc reference at `claude/docs/plans/2026-03-07-companion-equipment-design.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architect
- **Date:** 2026-03-07
- **Notes:** PRD complete and approved at `game-designer/prd.md`. Lore review
  approved by lore-master — class/race equipment restrictions added based on
  lore feedback. PRD covers 7 goals: per-slot storage (19 slots), correct trade
  replacement, full equipment visibility, slot-aware commands, combat stat
  integration, equipment persistence, and class/race validation. 8 open
  questions for architect to investigate (current storage mechanism, combat stat
  wiring, command audit, trade handler logic, companion identity, multi-slot
  edge cases, NO DROP handling, class/race bitmask mapping). Ready for
  architecture phase.

### architect → implementation team
- **Date:** 2026-03-07
- **Notes:** Architecture plan complete at `architect/architecture.md`. Critical
  finding: equipment stats are NOT currently applied because `m_inv`
  (InventoryProfile) is never populated — `CalcItemBonuses` reads from `m_inv`
  and finds no items. Fix follows bot system pattern: `m_inv.PutItem()`. 10
  implementation tasks across 4 agents (config-expert, data-expert, c-expert,
  lua-expert). No new opcodes/tables needed. Three new rules for toggleable
  behavior. Spawn the assigned experts as teammates for the Implementation phase.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Add 3 new Companions rules to `ruletypes.h` | config-expert | Not Started | EnforceClassRestrictions, EnforceRaceRestrictions, EquipmentPersistsThroughDeath |
| 2 | Insert 3 rule_values rows into database | data-expert | Not Started | Parallel with Task 1 |
| 3 | Fix combat stat integration: populate `m_inv` with ItemInstance | c-expert | Not Started | Depends on Task 1. Critical fix — enables CalcItemBonuses. |
| 4 | Enhance ShowEquipment to display all 19 slots | c-expert | Not Started | Independent. Show "(empty)" for unoccupied. |
| 5 | Add slot name aliases to SlotNameToSlotID per PRD | c-expert | Not Started | Independent. ~20 alias entries. |
| 6 | Add death handler equipment clear gated on rule | c-expert | Not Started | Depends on Task 1. |
| 7 | Enhance companion_find_slot for multi-slot empty preference | lua-expert | Not Started | Independent. Prefer empty Finger2 over occupied Finger1. |
| 8 | Add class/race restriction checks to event_trade | lua-expert | Not Started | Depends on Task 1. Uses eq.get_rule(). |
| 9 | Add money return check to event_trade | lua-expert | Not Started | Independent. Return money with message. |
| 10 | Rebuild server and validate all changes | c-expert | Not Started | Depends on Tasks 1-9. |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | What MobVersion enum should companions use for m_inv? | architect | c-expert | Open | Bot uses MobVersion::Bot; companion should likely use MobVersion::NPC — c-expert to verify during Task 3 |
| 2 | Does GiveAll check inventory capacity before each item return? | architect | c-expert | Open | If not, add capacity check to prevent item loss — c-expert to verify during Task 4 |

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
| 1 | Equipment persists through death — no corpse/loot drop | game-designer + lore-master | 2026-03-07 | Companions are recruited Norrathians, not summoned constructs. Persistent gear is thematically correct for small-group server. |
| 2 | Basic class/race restrictions enforced; advanced (deity, expansion, level) deferred | game-designer + lore-master | 2026-03-07 | Lore-master flagged unrestricted equipment as lore-breaking. Advanced edge cases add complexity for marginal benefit. |
| 3 | Populate m_inv InventoryProfile with ItemInstance (bot system pattern) | architect | 2026-03-07 | CalcItemBonuses reads from m_inv which companions never populate. Bot system proves m_inv.PutItem works for non-player entities. |
| 4 | Three separate toggleable rules (class, race, death persistence) | architect + config-expert | 2026-03-07 | Follows Bot system precedent. Gives server admins granular control. |
| 5 | No EquipmentPersistsThroughDismissal rule | architect + config-expert | 2026-03-07 | Dismissal persistence governed by DismissedRetentionDays and DB row lifetime. Separate rule would create confusing interaction. |
| 6 | No new opcodes or protocol changes needed | architect + protocol-agent | 2026-03-07 | All required opcodes exist. Companion trade bypass delegates to Lua. |

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

_Free-form notes, observations, and context._

**Architecture key finding:** Equipment stats have NEVER been applied to
companions. The `m_equipment[]` array stores item IDs and `SaveEquipment` /
`LoadEquipment` persist them, but `CalcItemBonuses()` reads from `m_inv`
(InventoryProfile) which was never populated. All companion equipment to date
has been cosmetic-only. The Task 3 fix will retroactively enable stats for all
existing companion equipment on first load.

**Slot count clarification:** The C++ storage supports 22 slots (0–21 including
Charm, Ear1, Ear2). The PRD specifies displaying 19 slots. The 3 omitted slots
still store items and apply stats — they just aren't shown in `!equipment`.
This is a UX decision per the PRD, not a technical limitation.
