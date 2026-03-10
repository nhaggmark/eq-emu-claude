# improved-companion-stats — Status Tracker

> **Feature branch:** `feature/improved-companion-stats`
> **Created:** 2026-03-10
> **Last updated:** 2026-03-10

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-10 | 2026-03-10 |
| Design | game-designer + lore-master | Complete | 2026-03-10 | 2026-03-10 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-03-10 | 2026-03-10 |
| Implementation | c-expert + lua-expert | In Progress | 2026-03-10 | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-10
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architect
- **Date:** 2026-03-10
- **Notes:** PRD complete at `game-designer/prd.md`. Lore-master signed off (no lore concerns — pure mechanics/UI feature). Feature scope: two companion commands — new `!stats` (detailed stat display) and enhanced `!equipment` (item links, AC, dmg/delay). Also includes access control change to allow any player to inspect any companion's stats/equipment (read-only commands become non-owner-gated). Three open questions for architect: (1) Lua_Companion binding gap for GetMinDMG/GetMaxDMG, (2) GetCombatRole Lua exposure, (3) implementation approach for enhanced equipment display (C++ vs Lua).

### architect → implementation team (c-expert + lua-expert)
- **Date:** 2026-03-10
- **Notes:** Architecture plan complete at `architect/architecture.md`. Three implementation tasks:
  1. **c-expert:** Add `GetMinDMG()`, `GetMaxDMG()`, `GetCombatRole()` to `Lua_Companion` (~30 lines across `lua_companion.h/cpp`)
  2. **c-expert:** Enhance `Companion::ShowEquipment()` to include item links, AC, Damage/Delay (~20 lines in `companion.cpp`)
  3. **lua-expert:** Add `cmd_stats` handler, modify access control in `dispatch_prefix_command()`, add to COMMANDS table, update help text (~80 lines in `companion.lua`)
  
  **Dependency:** Task 3 depends on Task 1 (new Lua bindings). Tasks 1 and 2 are independent.
  **Build required** after Tasks 1+2 before Task 3 can be tested.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Add GetMinDMG(), GetMaxDMG(), GetCombatRole() to Lua_Companion | c-expert | Not Started | lua_companion.h/cpp, ~30 lines |
| 2 | Enhance ShowEquipment() with item links, AC, Dmg/Delay | c-expert | Not Started | companion.cpp, ~20 lines |
| 3 | Add cmd_stats, access control change, COMMANDS update, help update | lua-expert | Complete | companion.lua. GetMinDMG/GetMaxDMG/GetCombatRole need c-expert Task 1 to test. |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | GetMinDMG/GetMaxDMG on Lua_Companion — add bindings or implement in C++? | game-designer | architect | Resolved | Add bindings to Lua_Companion (same pattern as SetFollowDistance workaround). Stats display in Lua, bindings in C++. |
| 2 | GetCombatRole Lua exposure method | game-designer | architect | Resolved | Add GetCombatRole() to Lua_Companion returning uint8 (enum value 0-4). Lua maps to display string. |
| 3 | Enhanced equipment display: modify C++ ShowEquipment or rewrite in Lua? | game-designer | architect | Resolved | Modify C++ ShowEquipment(). It already has database.GetItem() and ItemData access. Adding varlink + AC/Damage/Delay is ~20 lines. Lua rewrite would be more invasive. |

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
| 1 | !stats is separate from !status (complementary, not replacement) | game-designer | 2026-03-10 | !status = operational overview (stance, XP); !stats = detailed combat stats. Different use cases. |
| 2 | Read-only commands (!stats, !equipment, !status) open to any player | game-designer | 2026-03-10 | 1-3 player server — companions are shared group assets, all players need to inspect them |
| 3 | No lore concerns — pure mechanics/UI | lore-master | 2026-03-10 | No NPCs, dialogue, factions, narrative content involved |
| 4 | Add GetMinDMG/GetMaxDMG/GetCombatRole to Lua_Companion (not implement !stats in C++) | architect | 2026-03-10 | Lua display logic can be iterated without rebuilds; only 3 bindings needed. Same pattern as existing SetFollowDistance workaround. |
| 5 | Modify C++ ShowEquipment (not rewrite in Lua) | architect | 2026-03-10 | C++ already has database.GetItem() and ItemData access with AC/Damage/Delay fields. Adding varlink + stat display is ~20 lines vs. needing new bindings for Lua approach. |
| 6 | No new rules or database changes needed | architect | 2026-03-10 | Pure display feature — no tunable values, no persistent state. |

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

- The #npcstats crash on companions is a separate bug (CastToClient() on non-client entity). This feature does NOT fix that bug — it provides a safe player-facing alternative. The crash should be filed as a separate bug report if it needs fixing.
- quest_manager.varlink() availability in the ShowEquipment call path should be verified by c-expert. If quest_manager is not initialized in this context, fall back to direct item link generation (MakeItemLink or equivalent).
