# NPC Companion Context — Status Tracker

> **Feature branch:** `feature/npc-companion-context`
> **Created:** 2026-03-02
> **Last updated:** 2026-03-02

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-02 | 2026-03-02 |
| Design | game-designer + lore-master | Complete | 2026-03-02 | 2026-03-02 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-03-02 | 2026-03-02 |
| Implementation | c-expert + lua-expert | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-02
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architect
- **Date:** 2026-03-02
- **Notes:** PRD complete at `game-designer/prd.md`. Lore review approved by
  lore-master with one correction (Splitpaw → Sabertooth gnolls) and several
  enrichments (Vah Shir oral culture, Iksar KOS constraints, Erudite
  Erudin/Paineel distinction, Luclin fixed-lighting zones). All findings
  incorporated. PRD scope: companion context layer for LLM sidecar (identity
  shift, situational awareness, personality variation, unprompted commentary).
  5 open questions for architect to investigate.

### architect → implementation team (c-expert + lua-expert)
- **Date:** 2026-03-02
- **Notes:** Architecture plan complete at `architect/architecture.md`. 
  Feature is primarily Lua with two small C++ additions. Implementation
  sequence: Task 1 (C++ getters, c-expert) must complete first with server
  rebuild, then Tasks 2-7 (all Lua, lua-expert) can proceed. Only two
  experts needed: c-expert for C++ bindings, lua-expert for all Lua modules.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Add GetTimeActive() and GetRecruitedZoneID() C++ getters + Lua bindings | c-expert | Not Started | ~30 lines across 4 files. Requires rebuild. |
| 2 | Create companion_context.lua module (context builder) | lua-expert | Complete | 2026-03-02 |
| 3 | Extend companion_culture.lua with all Classic-Luclin race framings | lua-expert | Complete | 2026-03-02. Fixed race ID bugs (DarkElf=6, Troll=9, Ogre=10, Gnome=12). |
| 4 | Modify llm_bridge.lua to integrate companion context | lua-expert | Complete | 2026-03-02 |
| 5 | Create companion_commentary.lua (unprompted commentary module) | lua-expert | Complete | 2026-03-02 |
| 6 | Modify global_npc.lua for companion timer setup and death tracking | lua-expert | Complete | 2026-03-02 |
| 7 | Add commentary config values to llm_config.lua | lua-expert | Complete | 2026-03-02 |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | What companion state is already exposed to Lua? | game-designer | architect | Answered | Via Lua_Companion: GetCompanionID, GetOwnerCharacterID, GetCompanionType, GetStance, GetCompanionXP, GetRecruitedLevel, GetRecruitedNPCTypeID. Via Lua_Mob: GetRace, GetClass, GetLevel, GetDeity, GetHP, GetHPRatio, IsEngaged, GetHateListCount. NOT exposed: time_active, zones_visited. Two new bindings needed. |
| 2 | How does the sidecar currently structure its system prompt? | game-designer | architect | Answered | Sidecar receives flat JSON via POST /v1/chat. When is_companion=true is in payload, sidecar should branch to companion prompt frame. Internal prompt engineering is sidecar-side (out of scope per PRD). |
| 3 | What recent activity data is readily available? | game-designer | architect | Answered | Combat status (IsEngaged, GetHateListCount), HP ratio, time_active (needs new getter). Kill names NOT tracked in C++ (only counter). Solution: Lua entity variables for last 5 NPC names via event_death_zone. |
| 4 | Unprompted commentary implementation approach? | game-designer | architect | Answered | Timer-based: eq.set_timer() on companion in event_spawn, fires every 10 min, evaluates context change + probability roll. Uses existing LLM bridge with unprompted=true flag. |
| 5 | Luclin fixed-lighting zones handling? | lore-master | architect | Answered | Hardcoded Lua lookup table in companion_context.lua. When is_luclin_fixed_light=true, context omits time-of-day or flags it so sidecar avoids day/night commentary. No zone metadata changes needed. |

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
| 1 | Sabertooth gnolls in West Karana (not Splitpaw) | lore-master | 2026-03-02 | Splitpaw is Southern Karana; Sabertooth operates from Blackburrow |
| 2 | Vah Shir primary threats: grimlings + Akheva | lore-master | 2026-03-02 | Shissar are distant; grimlings are the day-to-day threat |
| 3 | Vah Shir oral culture as defining personality trait | lore-master | 2026-03-02 | Banned written records, blame Erudite magic for exile |
| 4 | Iksar KOS city constraints in companion dialogue | lore-master | 2026-03-02 | Iksar are KOS in all old-world good-aligned cities |
| 5 | Erudite Erudin/Paineel origin distinction by class | lore-master | 2026-03-02 | Necromancer=Paineel, Paladin=Erudin; deeply hostile factions |
| 6 | Companion context as Lua-only (no new DB tables or protocol changes) | architect | 2026-03-02 | All data derivable from live entity state + existing companion_data columns |
| 7 | Two new C++ Lua bindings: GetTimeActive() and GetRecruitedZoneID() | architect | 2026-03-02 | time_active and recruited zone data exist in C++ but lack Lua getters |
| 8 | Unprompted commentary timing in llm_config.lua (not ruletypes.h) | architect | 2026-03-02 | Creative tuning values, hot-reloadable, colocated with other LLM settings |
| 9 | Luclin fixed-lighting handled via hardcoded Lua lookup table | architect | 2026-03-02 | Small fixed set of zones, no metadata infrastructure needed |
| 10 | Recent kill tracking via Lua entity variables (not C++) | architect | 2026-03-02 | Transient data appropriate for entity variables; C++ only tracks count |

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

- Lore-master compiled comprehensive research across all 14 Classic-Luclin
  races, 15 classes, 16 deities, and relevant zones/factions. Research notes
  saved to lore-master context folder.
- Existing companion_culture.lua race framings (Ogre, Dark Elf, Iksar, Troll)
  confirmed lore-accurate by lore-master. This feature extends to remaining races.

