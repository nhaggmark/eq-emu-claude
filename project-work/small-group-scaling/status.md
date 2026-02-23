# Small-Group Scaling -- Status Tracker

> **Feature branch:** `feature/small-group-scaling`
> **Created:** 2026-02-22
> **Last updated:** 2026-02-23 (Validation phase completed)

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-02-22 | 2026-02-22 |
| Design | game-designer + lore-master | Complete | 2026-02-22 | 2026-02-22 |
| Architecture | architect + config-expert | Complete | 2026-02-23 | 2026-02-23 |
| Implementation | data-expert + config-expert | Complete | 2026-02-23 | 2026-02-23 |
| Validation | game-tester | Complete | 2026-02-23 | 2026-02-23 |
| Completion | _user_ | Not Started | | |

**Current phase:** Completion (ready for user acceptance and in-game playtesting)

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent -> design team (game-designer + lore-master)
- **Date:** 2026-02-22
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### design team -> architecture team (architect + protocol-agent + config-expert)
- **Date:** 2026-02-22
- **Notes:** PRD complete and approved at `game-designer/prd.md`. Key deliverables:
  - ~35 rule_values changes (complete SQL provided in PRD)
  - `npc_scale_global_base` table modifications needed (architect must quantify auto-scaled vs manual NPCs)
  - Loot table SQL updates needed (`loottable_entries`, `lootdrop_entries`, `spawn2`)
  - `level_exp_mods` table population needed for fine-grained XP curve
  - Expansion lock to Luclin (ID 3)
  - Lore review: PASSED (numerical tuning only, no narrative changes)
  - 5 open questions for architect to resolve (see PRD "Open Questions" section)
  - No C++ changes required. No Lua scripts required for initial implementation.
  - All changes reversible via SQL.

### architecture team -> implementation team (data-expert + config-expert)
- **Date:** 2026-02-23
- **Notes:** Architecture doc complete at `architect/architecture.md`. Critical findings:
  - **99.2% of NPCs have manual stats** -- npc_scale_global_base changes alone are insufficient. Direct `npc_types` UPDATE required for NPC difficulty reduction.
  - **rare_spawn=1 is NOT reliable** for identifying named NPCs. Use `rare_spawn=1 OR raid_target=1` as filter. Major named bosses have `rare_spawn=0, raid_target=1`.
  - **Raid bosses all have manual stats** -- npc_scale_global_base does not effectively affect them. Raid boss difficulty is left unchanged (deferred to companion system).
  - **Group XP formula confirmed** -- GroupExpMultiplier=0.8 achieves near-parity between solo and 2-player group XP per person.
  - **Spawn timer reduction scoped to named only** -- global reduction risks overwhelming solo players with trash respawns.
  - All ~35 rule names verified against `common/ruletypes.h`. All correct.
  - Full backup/rollback strategy defined. 16-task implementation sequence provided.
  - Research artifacts saved to `architect/context/research-findings.md`.

### implementation team -> validation (game-tester)
- **Date:** 2026-02-23
- **Notes:** All 16 implementation tasks complete. Config-expert verified:
  - 34/34 rule_values match expected values (zero mismatches)
  - Server restarted successfully via `docker compose restart eqemu-server`
  - Smoke test: 6/6 checks PASS (NPC stat reduction, raid bosses untouched, backup tables intact, expansion lock at 3, loot probability increased, spawn timers reduced)
  - All 5 backup tables exist with correct row counts (46,184 / 2,326 / 12,511 / 3,564 / 42)
  - Ready for in-game playtesting by game-tester agent

### validation (game-tester) -> completion (user)
- **Date:** 2026-02-23
- **Notes:** Server-side validation complete. 15/15 automated checks PASS. No blockers found.
  - All 5 backup tables verified with correct row counts
  - 45,828 non-raid NPCs confirmed at 50% HP, ~75% maxdmg, ~82% AC
  - All raid bosses (Nagafen, Vox, Phinigel, Trakanon) confirmed unchanged
  - 37 rule values verified across 4 rulesets (30 in ruleset 1 + 7 across rulesets 5, 6, 10)
  - 0 broken FK references, 0 zero-HP regressions, 0 broken loot chains
  - 0 ERROR/FATAL entries in server logs post-restart
  - Rollback script validated at `data-expert/context/rollback_sgs.sql`
  - Full test plan with 10 in-game tests + 4 edge case tests written to `game-tester/test-plan.md`
  - Ready for user acceptance: in-game playtesting using the test plan

---

## Implementation Tasks

_Populated by the architect. Tasks assigned to data-expert (SQL) with config-expert verification._

| # | Task | Agent | Status | Depends On | Notes |
|---|------|-------|--------|------------|-------|
| 1 | Create full database backup | data-expert | Complete (2026-02-23) | -- | mysqldump of peq database (31MB gzip) |
| 2 | Create npc_types stat backup table | data-expert | Complete (2026-02-23) | 1 | 46,184 rows backed up |
| 3 | Create loottable_entries backup table | data-expert | Complete (2026-02-23) | 1 | 2,326 rows backed up |
| 4 | Create lootdrop_entries backup table | data-expert | Complete (2026-02-23) | 1 | 12,511 rows backed up |
| 5 | Create spawn2 backup table | data-expert | Complete (2026-02-23) | 1 | 3,564 rows backed up |
| 6 | Apply rule_values changes (~35 rules) | data-expert | Complete (2026-02-23) | 1 | 34 rules updated across all rulesets. Backup table created. |
| 7 | Verify rule_values applied correctly | config-expert | Complete (2026-02-23) | 6 | 34/34 rules verified. All values match expected. Zero mismatches. |
| 8 | Reduce non-raid NPC stats in npc_types | data-expert | Complete (2026-02-23) | 2 | HP: 44,384 changed; maxdmg: 44,259; mindmg: 31,840; AC: 44,318. Raid targets confirmed untouched. |
| 9 | Update npc_scale_global_base types 0,1 | data-expert | Complete (2026-02-23) | 1 | 130 rows updated (types 0+1, levels 1-65) |
| 10 | Increase loottable_entries probability | data-expert | Complete (2026-02-23) | 3 | 102 rows changed (probability * 1.5, cap 100) |
| 11 | Increase lootdrop_entries chance | data-expert | Complete (2026-02-23) | 4 | 12,188 rows changed (chance * 1.5, cap 25) |
| 12 | Reduce spawn2 respawntime for named | data-expert | Complete (2026-02-23) | 5 | 3,564 rows changed (respawntime * 0.75, min 60s) |
| 13 | Populate level_exp_mods table | data-expert | Complete (2026-02-23) | 6 | 65 rows set to baseline 1.0/1.0 (levels 1-65) |
| 14 | Generate rollback SQL script | data-expert | Complete (2026-02-23) | 8-12 | Saved to data-expert/context/rollback_sgs.sql |
| 15 | Server restart and rule reload | config-expert | Complete (2026-02-23) | 6-13 | docker compose restart succeeded. Container restarted cleanly. |
| 16 | Smoke test validation | config-expert | Complete (2026-02-23) | 15 | All 6 checks PASS. NPC stats reduced, raid bosses untouched, backups intact, expansion locked, loot/spawn changes confirmed. |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | What % of Classic-Luclin NPCs use auto-scaling vs manually set stats? | game-designer | architect | **Resolved** | 0.8% auto-scaled (356 NPCs), 99.2% manual stats (45,828 NPCs). npc_scale_global_base alone is insufficient; direct npc_types UPDATE required. |
| 2 | Does `rare_spawn = 1` reliably identify named NPCs in PEQ? | game-designer | architect | **Resolved** | No. Only 354 NPCs flagged. Major nameds (Nagafen, Vox, etc.) have rare_spawn=0, raid_target=1. Use `rare_spawn=1 OR raid_target=1` as compound filter. |
| 3 | Confirm effective group XP multipliers with new GroupExpMultiplier=0.8 | game-designer | architect | **Resolved** | Confirmed via exp.cpp: 2-player group = ~0.98x per person (near solo-equivalent). 3-player = ~0.71x per person. Combined with ExpMultiplier=3.0, meets PRD goals. |
| 4 | Should spawn2.respawntime reduction be global or scoped to named spawns only? | game-designer | architect | **Resolved** | Scoped to named spawns only (rare_spawn=1 OR raid_target=1). Global reduction risks overwhelming solo players with faster trash respawns. |
| 5 | Does npc_scale_global_base affect raid bosses or do they bypass auto-scaling? | game-designer | architect | **Resolved** | Bypassed in practice. All raid bosses have manual stats (hp>0). Scale manager only applies when hp=0. Raid boss difficulty left unchanged (deferred to Phase 4). |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| | | | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Balance NPC stats for 2 players (not 1 or 3) | game-designer | 2026-02-22 | Cannot dynamically scale. 2-player target means solo is hard but possible, 3-player is slightly easier -- acceptable tradeoff. |
| 2 | Use rules + DB tuning only, no C++ changes | game-designer | 2026-02-22 | Reversibility, no rebuild required, faster iteration. Lua Mods documented as future enhancement. |
| 3 | Defer raid-gated zones to companion system (Phase 4) | game-designer | 2026-02-22 | Veeshan's Peak, Sleeper's Tomb, Ssraeshza Temple, Vex Thal require raid force. NPC scaling alone insufficient. |
| 4 | Keep bots and mercs disabled | game-designer | 2026-02-22 | Companion recruitment system (Phase 4) is the intended solution. Bots/mercs would undermine that design. |
| 5 | No changes to individual spell data | game-designer | 2026-02-22 | Global multipliers (regen, crit chance) are sufficient. Per-spell changes risk breaking era compliance and are hard to revert. |
| 6 | Enable BindAnywhere for solo QoL | game-designer | 2026-02-22 | Solo players need flexible bind points. Low risk, high quality-of-life. |
| 7 | Direct npc_types UPDATE required (not just npc_scale_global_base) | architect | 2026-02-23 | 99.2% of NPCs have manual stats. Auto-scaling table only covers 0.8%. Must modify npc_types directly with backup/rollback. |
| 8 | Use compound filter (rare_spawn=1 OR raid_target=1) for named NPCs | architect | 2026-02-23 | rare_spawn=1 alone misses major bosses. raid_target=1 catches them. Combined filter covers known named and raid NPCs. |
| 9 | Scope spawn timer reduction to named spawns only | architect | 2026-02-23 | Global reduction risks mob density issues for solo players. Named-only is targeted and achieves the PRD loot accessibility goal. |
| 10 | Leave raid boss stats unchanged | architect | 2026-02-23 | All raid bosses have manual stats, are deferred to companion system (Phase 4). Reducing their stats would make them trivial for 3 players, undermining the "come back with companions" design. |

---

## Completion Checklist

_Filled in after game-tester validation passes._

- [x] All implementation tasks marked Complete
- [x] No open Blockers
- [x] game-tester validation: PASS (15/15 server-side checks)
- [ ] In-game playtesting by user (10 tests + 4 edge cases in test plan)
- [ ] Feature branch merged to main
- [x] Server rebuilt (if C++ changed) -- N/A, data-only changes
- [ ] All phases marked Complete in Workflow Status table

**Merged by:** _name_
**Merge date:** _YYYY-MM-DD_

---

## Notes

_Free-form notes, observations, and context._

### Architecture Research Artifacts
- Full research findings: `architect/context/research-findings.md`
- Contains detailed database query results, C++ code analysis, and XP formula verification

### Key C++ Source Files Referenced
- `eqemu/zone/exp.cpp` -- XP formulas, Group::SplitExp, CalcEXP
- `eqemu/zone/npc_scale_manager.cpp` -- NPC auto-scaling logic, type classification
- `eqemu/zone/npc_scale_manager.h` -- ScaleNPC, IsAutoScaled, GetNPCScalingType
- `eqemu/common/ruletypes.h` -- All ~1186 rule definitions

### NPCs with scalerate=300
4,122 NPCs have scalerate=300 (3x scaling multiplier). After 50% HP reduction, they will still be at 1.5x standard difficulty. These should be spot-checked during playtesting to ensure they are appropriately challenging but not impossible for 2 players.

### Current Server Rule Overrides
The server already has non-default values:
- `Character:ExpMultiplier` = 0.65 (default 0.5)
- `Character:GroupExpMultiplier` = 0.65 (default 0.5)
- `Expansion:CurrentExpansion` = 9 (will change to 3)
