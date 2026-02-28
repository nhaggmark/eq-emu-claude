# NPC Recruitment / Recruit-Any-NPC Companion System — Status Tracker

> **Feature branch:** `feature/npc-recruitment`
> **Created:** 2026-02-25
> **Last updated:** 2026-02-27 (Task 7 companion spell AI complete — all 24 c-expert tasks done)

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-02-25 | 2026-02-25 |
| Design | game-designer + lore-master | Complete | 2026-02-25 | 2026-02-26 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-02-26 | 2026-02-26 |
| Implementation | c-expert + data-expert + lua-expert | Complete | 2026-02-27 | 2026-02-27 |
| Validation | game-tester | In Progress | 2026-02-27 | |
| Completion | _user_ | Not Started | | |

**Current phase:** Validation — PASS (all 3 blockers resolved; ready for in-game testing)

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-02-25
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.


### design team (game-designer + lore-master) → architect
- **Date:** 2026-02-26
- **Notes:** PRD complete and lore-approved at `game-designer/prd.md`.
  Lore-master reviewed twice: initial comprehensive research drove major revision,
  final review caught 4 corrections (faction table ordering, Dreadguard Inner
  exclusion, Circle of Unseen Hands reference, hard-block language for exclusion
  list). All corrections applied and approved. Full conversation audit trail in
  `agent-conversations.md`. PRD covers: recruitment eligibility, companion vs.
  mercenary types, culture-specific persuasion, racial disposition caps, AI
  archetypes for all 15 Classic-Luclin classes, replacement NPC spawning, LLM
  dialogue integration, mercenary retention, and balance levers. 9 open
  questions flagged for architect evaluation.

### architect → implementation team (c-expert + data-expert + lua-expert)
- **Date:** 2026-02-26 (updated 2026-02-27 with expanded scope)
- **Notes:** Architecture document complete at `architect/architecture.md`.
  All 9 PRD open questions answered. Key decisions: new `Companion : public NPC`
  class (not extending Merc or Bot), stats from npc_types, spell AI adapted from
  Bot system, Merc lifecycle patterns for zone persistence. 18 Companions rules
  (12 original + 6 expanded scope). **24 implementation tasks** across
  3 phases. Protocol-agent confirmed Titanium has zero merc opcodes — chat
  commands + group window only. Config-expert confirmed no existing rules
  reusable, no eqemu_config.json changes needed. Full advisor consultation
  audit trail in `agent-conversations.md`.
  
  **Expanded scope (2026-02-27):** 6 new tasks added (19-24) covering companion
  leveling, equipment management, lifelong persistence, re-recruitment, and
  soul wipe. All 6 game-designer design decisions reviewed and approved by
  architect. All 38 user stories technically validated. 6 new rules added.
  Estimated additional scope: ~1,600 lines C++, ~70 lines SQL, ~100 lines Lua.
  
  **Implementation sequence:**
  - Phase 1 (Foundation, parallel): Tasks 1-5, 20 — rules + DB tables + seed data
  - Phase 2 (Core C++, sequential): Tasks 6-13, 19, 21, 22, 24 — Companion class + integrations + expanded scope
  - Phase 3 (Lua + Integration): Tasks 14-18, 23 — recruitment logic + Lua bindings + re-recruitment
  
  **Assigned experts:** c-expert (16 tasks), data-expert (5 tasks), lua-expert (5 tasks, 2 shared with c-expert)

### implementation team → game-tester
- **Date:** 2026-02-27
- **Notes:** Server-side validation complete. Result: PASS WITH WARNINGS. Build compiles clean.
  6 DB tables exist with correct schemas, 7,269 exclusions, 14 culture records, 842 spell entries.
  All 3 Lua files pass syntax checks. 3 blockers identified:
  B1 (High) — Lua rule name mismatch in companion.lua line 113 ("Companions:Enabled" should be "Companions:CompanionsEnabled");
  B2 (High) — ShowEquipment/GiveSlot/GiveAll methods missing from Companion C++ class and Lua bindings;
  B3 (Medium) — 18 Companions rule_values rows absent from DB (migration 9332 skipped).
  20 of 20 in-game tests can proceed (Tests 13/14/19 blocked by B2 and mercenary retention stub).
  Full test plan and results at `game-tester/validation-report.md`.

---

## Implementation Tasks

_Populated by the architect from the architecture document._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Add Companions rule category to `common/ruletypes.h` and seed `rule_values` | c-expert | Complete | 18 rules (CompanionsEnabled to avoid X-macro collision); 2026-02-27 |
| 2 | Create `companion_data`, `companion_buffs`, `companion_exclusions`, `companion_culture_persuasion` tables via migration manifest | data-expert | Complete | 4 tables, 29-col companion_data incl expanded scope; 2026-02-27 |
| 3 | Seed `companion_exclusions` with NPC class-based auto-exclusions + named lore anchors | data-expert | Complete | 7262 auto + 7 manual lore anchors; 2026-02-27 |
| 4 | Seed `companion_culture_persuasion` with racial persuasion mappings | data-expert | Complete | 14 races seeded; race IDs verified: 128=Iksar, 130=Vah Shir; 2026-02-27 |
| 5 | Create `companion_spell_sets` table and seed with spell data for all 15 Classic-Luclin classes | data-expert | Complete | 842 entries from Default class spell lists (IDs 1-12); Bot IDs 3001-3016 have no DB entries; 2026-02-27 |
| 6 | Implement `Companion` class: `zone/companion.h`, `zone/companion.cpp` | c-expert | Complete | ~1300 lines; full lifecycle, group, persistence, scaling, equipment, XP, soul wipe; 2026-02-27 |
| 7 | Implement companion spell AI: `zone/companion_ai.cpp` | c-expert | Complete | 16 class handlers + 8 shared helpers; stance gating; LoadCompanionSpells queries companion_spell_sets; kill hook in exp.cpp; 2026-02-27 |
| 8 | Modify `zone/entity.h/cpp` — add companion_list, AddCompanion/RemoveCompanion | c-expert | Complete | companion_list added; EntityList methods in companion.cpp following Bot pattern; 2026-02-27 |
| 9 | Modify `zone/client.h/cpp` — companion ownership, SpawnCompanionsOnZone | c-expert | Complete | SpawnCompanionsOnZone() in companion.cpp called from client_packet.cpp; mirrors Merc/Bot pattern; 2026-02-27 |
| 10 | Modify `zone/groups.cpp` — auto-dismiss companion when player joins full group | c-expert | Complete | Auto-suspends companion when group hits MAX_GROUP_MEMBERS-1 and new Client joins; 2026-02-27 |
| 11 | Add `ServerOP_CompanionZone`, `ServerOP_CompanionDismiss` to `common/servertalk.h` | c-expert | Complete | 0x4800/0x4801 with packet structs ServerCompanionZone_Struct/ServerCompanionDismiss_Struct; 2026-02-27 |
| 12 | Add `IsCompanion()` virtual to `zone/entity.h` (not mob.h — virtuals live in entity.h) | c-expert | Complete | Added to entity.h alongside IsBot()/IsMerc(); CastToCompanion() also added; 2026-02-27 |
| 13 | Add DB migration entries to `common/database/database_update_manifest.h` | c-expert | Complete | 4 entries (9329-9332): all 6 tables + exclusions + culture persuasion + 18 rule_values; 2026-02-27 |
| 14 | Create `companion.lua` module — recruitment logic, eligibility, persuasion rolls | lua-expert | Complete | 2026-02-27; C++ creation API stubbed (3 TODOs pending Tasks 17/18/23) |
| 15 | Create `companion_culture.lua` module — culture dialogue templates for LLM | lua-expert | Complete | 2026-02-27; all lore constraints implemented (Ogre panic, context-scoped word prohibition) |
| 16 | Modify `global/global_npc.lua` — intercept recruitment/management keywords | lua-expert | Complete | 2026-02-27; companion block added before LLM; management block gated on Task 18 IsCompanion() |
| 17 | Add Lua API methods for companion creation/management (expose C++ to Lua) | c-expert | Complete | lua_client.cpp: CreateCompanion, GetCompanionByNPCTypeID, HasActiveCompanion; lua_entity: IsCompanion/CastToCompanion; 2026-02-27 |
| 18 | Expose Companion class to Lua: `zone/lua_companion.h/cpp` | c-expert | Complete | lua_companion.h/cpp: 14 methods; lua_parser.cpp registration; also fixed lua_mod.h/quest_interface.h/lua_bit.h latent unity-build issues; 2026-02-27 |
| 19 | Add XP tracking + leveling system to Companion class | c-expert | Complete | Implemented in companion.cpp: AddExperience, CheckForLevelUp, GetXPForNextLevel; 2026-02-27 |
| 20 | Create `companion_inventories` table + expanded `companion_data` columns | data-expert | Complete | companion_inventories created; expanded columns already in Task 2 companion_data; 2026-02-27 |
| 21 | Implement equipment system in Companion class (trade, equip, persist) | c-expert | Complete | GiveItem/RemoveItemFromSlot/LoadEquipment/SaveEquipment/SendWearChange in companion.cpp; 2026-02-27 |
| 22 | Add companion history tracking (kills, zones, time_active) | c-expert | Complete | m_total_kills/m_times_died/m_time_active/m_zones_visited; UpdateTimeActive() hooked into Suspend/Zone/Death; RecordZoneVisit() JSON array capped at 100; repository updated; 2026-02-27 |
| 23 | Implement re-recruitment logic (dismiss with state preserve, restore) | c-expert + lua-expert | Complete (lua-expert side) | Re-recruitment transparent inside client:CreateCompanion(npc); Lua adds +10% roll bonus via check_dismissed_record() pre-roll; committed 506e389d3; 2026-02-27 |
| 24 | Implement soul wipe on permanent death (cascade delete + ChromaDB clear) | c-expert + lua-expert | Complete | SoulWipe/SoulWipeByCompanionID in companion.cpp; DataBucket signal for ChromaDB; 2026-02-27 |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1-9 | PRD open questions (merc vs bot, spell lists, replacement NPC, etc.) | game-designer | architect | RESOLVED | All 9 answered in architecture.md "PRD Open Questions" section |
| 10 | Resurrection targeting on NPC corpses — does Titanium client allow? | architect | protocol-agent → c-expert | OPEN | Deferred to implementation phase. Architecture provides fallback approach. |
| 11 | OP_WearChange for non-player-race NPC models | architect | protocol-agent → c-expert | OPEN | Deferred to implementation phase. Only affects visual updates on exotic models. |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| B1: companion.lua line 113 — rule name "Companions:Enabled" → "Companions:CompanionsEnabled" | game-tester | 2026-02-27 | Yes (2026-02-27) — lua-expert fixed |
| B2: ShowEquipment/GiveSlot/GiveAll missing from C++ and Lua bindings | game-tester | 2026-02-27 | Yes (2026-02-27) — c-expert implemented all 3 methods |
| B3: 18 Companions rule_values rows missing from DB | game-tester | 2026-02-27 | Yes (2026-02-27) — data-expert inserted all 18 rows |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | New `Companion : public NPC` class | architect | 2026-02-26 | Merc too coupled to templates, Bot too complex; NPC subclass is cleanest |
| 2 | Stats derived from `npc_types` directly | architect | 2026-02-26 | NPCType struct already has all stats; no need for companion-specific stat tables |
| 3 | Spell AI adapted from Bot system (58+ spell types) | architect | 2026-02-26 | Bot already handles all 16 classes; Merc only has 4 archetypes |
| 4 | Merc lifecycle patterns for zone persistence | architect | 2026-02-26 | Proven pattern: Save/Depop on zone-out, Load/Spawn on zone-in |
| 5 | 12 Companions rules (trimmed from 28) | architect + config-expert | 2026-02-26 | Roll modifiers moved to Lua; redundant caps dropped |
| 6 | Chat commands + group window (no merc UI) | architect + protocol-agent | 2026-02-26 | Titanium has zero merc opcodes; group packets fully functional |
| 7 | Persuasion formula weights in Lua only | architect + config-expert | 2026-02-26 | Complex formula should live in one place, not split between rules and Lua |
| 8 | Linear stat scaling: `base * (current_level / recruited_level)` | game-designer + architect | 2026-02-27 | Simple, predictable, preserves NPC identity. Must use float division. |
| 9 | Equipment persists on dismissed companions | game-designer | 2026-02-27 | Creates emotional investment. Soul wipe destroys all gear (stakes). |
| 10 | 50% XP share for companions | game-designer + architect | 2026-02-27 | Companions lag behind player naturally. Incentivizes human grouping. |
| 11 | Companion max level = player_level - 1, no absolute cap | game-designer + architect | 2026-02-27 | Enables lifelong companion fantasy. StatScalePct provides dampener. |
| 12 | +10% re-recruitment bonus for voluntarily dismissed companions | game-designer | 2026-02-27 | Rewards relationship investment. Soul-wiped companions are strangers. |
| 13 | 6 new rules for expanded scope (total 18) | architect | 2026-02-27 | XPSharePct, MaxLevelOffset, ReRecruitBonus, DismissedRetentionDays, CompanionSelfPreservePct, MercSelfPreservePct |

---

## Completion Checklist

_Filled in after game-tester validation passes._

- [ ] All implementation tasks marked Complete
- [ ] No open Blockers
- [ ] game-tester validation: PASS
- [ ] Feature branch merged to main
- [ ] Server rebuilt (if C++ changed)
- [ ] All phases marked Complete in Workflow Status table

**Merged by:** _name_
**Merge date:** _YYYY-MM-DD_

---

## Notes

This is the signature feature of the entire project — Phase 4 as defined in
`claude/PROJECT.md`. The plan is to hijack/repurpose the existing EQEmu
mercenary system to allow recruitment of any NPC as a companion, available
in Classic-Luclin expansions. Combined with the soul element system from
Phase 3 (npc-llm-integration), players can carry on party conversations and
develop NPC characters over time.

**Key design constraints from user:**
- Allow players to recruit any NPC within 3 levels of their own
- Use faction alignment and/or charisma checks for recruitment
- Repurpose/hijack the existing EQEmu mercenary system
- NPCs of different class types at the player's level can be recruited
- Integration point: soul element system from Phase 3 (npc-llm-phase3 branch)
- Era lock: Classic through Luclin only

**Branch context:**
- `akk-stack/` branch: `feature/npc-recruitment` (from `feature/npc-llm-phase3`)
- `eqemu/` branch: `feature/npc-recruitment` (from `feature/npc-llm-integration`)
