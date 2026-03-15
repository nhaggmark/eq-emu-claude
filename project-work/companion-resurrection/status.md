# Companion Resurrection System — Status Tracker

> **Feature branch:** `feature/companion-resurrection`
> **Created:** 2026-03-15
> **Last updated:** 2026-03-15

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-15 | 2026-03-15 |
| Design | game-designer + lore-master | Complete | 2026-03-15 | 2026-03-15 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-03-15 | 2026-03-15 |
| Implementation | c-expert + data-expert | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-15
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architecture team (architect + protocol-agent + config-expert)
- **Date:** 2026-03-15
- **Notes:** PRD completed at `game-designer/prd.md`. Research notes at
  `game-designer/context/research-notes.md`. Lore notes mostly template
  (lore input was delivered via conversation, captured in `agent-conversations.md`).

### architect → implementation team (c-expert + data-expert)
- **Date:** 2026-03-15
- **Notes:** Architecture plan complete at `architect/architecture.md`.
  12 implementation tasks defined. Critical path: Task 2 → (3,4,5 parallel) → 7 → 9 → 10 → 12.
  Only 2 experts needed: c-expert (11 tasks) and data-expert (1 task).
  c-expert should start with Tasks 1 and 2 (independent foundations).
  data-expert can run Task 11 in parallel (verify spell IDs from spells_new).

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Add 5 new rules to `ruletypes.h` + `rule_values` SQL | c-expert | Not Started | Independent — can start immediately |
| 2 | Add companion metadata to Corpse class (`corpse.h/cpp`) | c-expert | Not Started | Independent — can start immediately |
| 3 | Strip loot from companion corpses + set companion data in `attack.cpp` | c-expert | Not Started | Depends on 2 |
| 4 | Extend `SpellEffect::Revive` in `spell_effects.cpp` for companion corpses | c-expert | Not Started | Depends on 2 |
| 5 | Add `GetCompanionCorpseByOwnerWithinRange()` to `entity.h/cpp` | c-expert | Not Started | Depends on 2 |
| 6 | Implement `ApplyDeathXPPenalty()` + call from `Death()` | c-expert | Not Started | Depends on 1 |
| 7 | Implement `ResurrectFromCorpse()` static method | c-expert | Not Started | Depends on 2, 5, 6 |
| 8 | Add rez delay timer + update `AI_IdleCastCheck()` | c-expert | Not Started | Depends on 1 |
| 9 | Implement full rez AI: `AI_ResurrectDeadGroupMember()`, `FindDeadGroupMemberCorpse()`, `SelectBestRezSpell()`, deity dialogue | c-expert | Not Started | Depends on 1, 2, 5, 8 |
| 10 | Wire rez AI into `AI_Cleric()`, `AI_Paladin()`, `AI_Necromancer()` | c-expert | Not Started | Depends on 9 |
| 11 | Verify rez spell IDs from `spells_new`, populate `companion_spell_sets` | data-expert | Not Started | Independent — can start immediately |
| 12 | Multiple-healer coordination: only highest-rez-capable companion attempts | c-expert | Not Started | Depends on 9 |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Verify all rez spell IDs (Reanimation, Resuscitate) from `spells_new` | game-designer | data-expert | Open | Task 11 — data-expert queries DB |
| 2 | Corpse decay time for companion corpses — should match `DeathDespawnS` (30 min) | architect | c-expert | Open | Set in attack.cpp when creating companion corpse |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| None | | | |

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
| 1 | Spell data must be verified from spells_new database, not third-party sources | game-designer, lore-master | 2026-03-15 | Third-party sources disagree on exact mana costs and XP values |
| 2 | Necro Convergence uses death-energy justification (Option A) | game-designer, lore-master | 2026-03-15 | Essence Emerald impossible for companions; lore-master recommended option A |
| 3 | Deity-themed rez dialogue with class-based fallback | game-designer, lore-master | 2026-03-15 | Rez tied to divine faith; fallback needed if deity field is 0 |
| 4 | "Raised" not "resurrected" for necro dialogue | game-designer, lore-master | 2026-03-15 | Thematic distinction: necro manipulates death energy, not divine power |
| 5 | Rez-capable classes: Cleric, Paladin, Necromancer only | game-designer, lore-master | 2026-03-15 | Druids/shamans confirmed no rez in Classic-Luclin |
| 6 | Dialogue implemented as C++ lookup table, not Lua module | architect | 2026-03-15 | Avoids Lua→C++ bridging overhead; only ~10 deity entries + 3 class fallbacks |
| 7 | Companion corpse loot stripped in attack.cpp after corpse creation | architect | 2026-03-15 | Cleanest approach — corpse reference is directly available at creation point |
| 8 | Companion corpse decay time matches DeathDespawnS (30 min) | architect | 2026-03-15 | Prevents corpse disappearing before death despawn timer fires |
| 9 | ResurrectFromCorpse updates DB before deleting corpse | architect | 2026-03-15 | Crash safety — if server dies mid-rez, companion is saved with restored XP |
| 10 | Only 2 implementation agents needed (c-expert + data-expert) | architect | 2026-03-15 | Feature is heavily C++ focused; no Lua/infra changes |

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

Companion Resurrection System — Healer companions autonomously rez dead group members after combat. Companions leave corpses (no loot). Auto-accept rez. Standard EQ penalties per spell. Era-appropriate rez spells for clerics, paladins, necros.
