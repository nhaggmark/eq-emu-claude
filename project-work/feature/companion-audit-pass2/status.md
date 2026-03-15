# Companion Audit Pass 2 — Status Tracker

> **Feature branch:** `feature/companion-audit-pass2`
> **Created:** 2026-03-15
> **Last updated:** 2026-03-15

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-15 | 2026-03-15 |
| Design | game-designer + lore-master | Skipped (audit) | — | — |
| Architecture | architect (synthesis) | Complete | 2026-03-15 | 2026-03-15 |
| Implementation | c-expert + data-expert + lua-expert | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

### bootstrap-agent → implementation team (c-expert, lua-expert, data-expert)
- **Date:** 2026-03-15
- **Notes:** Workspace created. Expert audits dispatched directly (design phase skipped for audit pass).

### c-expert + lua-expert + data-expert → architect (synthesis)
- **Date:** 2026-03-15
- **Notes:** All three expert audits complete. Synthesized into architecture.md.
  - 9 first-pass fixes verified correct
  - 5 new gaps found (1 critical, 2 high, 1 medium, 1 low)
  - 30 test coverage gaps cataloged
  - 4 Lua/C++ contract issues documented
  - Critical finding: companion_spell_sets is the PRIMARY spell system, not npc_spells_entries

### architect → implementation team
- **Date:** 2026-03-15
- **Notes:** Architecture report complete. 14 implementation tasks defined across 3 experts.
  Critical path: c-expert verifies AICastSpell priority semantics → data-expert fixes
  companion_spell_sets → lua-expert fixes CONTRACT-01/02. See architecture.md Section 5.

---

## Implementation Tasks

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Verify AICastSpell priority semantics (ascending vs descending) | c-expert | Not Started | CRITICAL PATH: blocks tasks 2, 3, 11 |
| 2 | Apply GAP-05/07 equivalent priorities to companion_spell_sets | data-expert | Complete | All 12 classes done. Semantics: priority=1=highest. All healer classes have heals checked first. |
| 3 | Fix cleric heal priority inversion (both tables) | data-expert | Complete | npc_spells_entries: CH=50, heals elevated above Wrath. companion_spell_sets: heals at 1, damage at 10-30. |
| 4 | Fix CONTRACT-01: nil-guard GetOwnerCharacterID() | lua-expert | Not Started | |
| 5 | Fix CONTRACT-02: pcall-wrap check_and_speak() | lua-expert | Not Started | |
| 6 | Add ScaleStatsToLevel() call to Companion constructor | c-expert | Not Started | |
| 7 | Fix 4 inverted minlevel/maxlevel entries | data-expert | Complete | Fixed in npc_spells_entries (4 entries) + companion_spell_sets (13 entries including bard songs, berserker). |
| 8 | Fix CONTRACT-03: pcall-protect CastToNPC() | lua-expert | Not Started | |
| 9 | Add Process() safety net UpdateTimeActive() | c-expert | Not Started | |
| 10 | Add critical C++ test coverage (TC-C01/C02/C03) | c-expert | Not Started | Depends on #6 |
| 11 | Add critical DB test coverage (TC-D01/D02/D03) | data-expert | Complete | companion_db_health_validation.sql — 16 tests covering TC-D01 through TC-D07. All PASS. |
| 12 | Add commentary Lua test coverage (TC-L01) | lua-expert | Not Started | Depends on #4, #5 |
| 13 | Remove stale MEMORY.md GetPrimaryFaction() entry | lua-expert | Not Started | |
| 14 | Add CONTRACT-04 Database() nil guards | lua-expert | Not Started | |

---

## Open Questions

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Does companion_spell_sets use ascending (1=highest) or descending (20=highest) priority? | architect | c-expert | Resolved | priority=1 = HIGHEST PRIORITY (checked first). Opposite of npc_spells_entries. c-expert confirmed 2026-03-15. |
| 2 | Does ScaleStatsToLevel() compound with ApplyStatScalePct() or are they independent? | architect | c-expert | Resolved | See c-expert dev notes — call order: ScaleStatsToLevel() → ApplyStatScalePct() → CalcBonuses(). |
| 3 | Is npc_spells_entries list ID=1 (cleric) shared with non-companion NPCs? | architect | data-expert | Resolved | Yes — 1869 NPC types use list ID=1. Elevating heals is correct for all clerics. No companion-specific list needed. |

---

## Blockers

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| AICastSpell priority semantics unknown — blocks all spell data fixes | architect | 2026-03-15 | Yes — 2026-03-15. priority=1 = highest (c-expert confirmed). |

---

## Bug Reports

_No new bugs filed. Findings are documented in architecture.md as NEW-01 through NEW-05._

---

## Decision Log

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Companion AI uses companion_spell_sets as primary spell source | architect (verified from source) | 2026-03-15 | companion_ai.cpp LoadCompanionSpells() queries companion_spell_sets; fallback to npc_spells_entries only when empty |
| 2 | GAP-16 (longbow race restriction) retracted | data-expert | 2026-03-15 | Re-query shows races=65535 (all races). Original finding was from stale data. |
| 3 | MEMORY.md GetPrimaryFaction() entry is stale | c-expert | 2026-03-15 | GAP-17 fix registered GetPrimaryFaction() on Lua_Companion. Method works. |

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

- This is a second-pass audit building on the companion-authenticity-audit (first pass).
- The most critical finding is that companion_spell_sets was not updated by GAP-05/07,
  rendering those spell priority fixes ineffective for all caster companions.
- The fix roadmap has 14 tasks organized into 4 priority tiers.
- Critical path dependency: Task #1 (priority semantics) must complete before Tasks #2, #3, #11.
