# Companion Authenticity Audit — Status Tracker

> **Feature branch:** `feature/companion-authenticity-audit`
> **Created:** 2026-03-14
> **Last updated:** 2026-03-14

---

## Feature Summary

Companion Authenticity Audit — Full audit of companion NPC stats, damage, weapons, and spells vs regular player/NPC behavior. Identify gaps where companions don't match authentic EQ experience.

> **Note:** This is a research/audit task, not an implementation task. The workspace is for collecting findings into a report.

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-14 | 2026-03-14 |
| Design | game-designer + lore-master | Skipped | | |
| Architecture | architect + c-expert + lua-expert + data-expert | Complete | 2026-03-14 | 2026-03-14 |
| Implementation | _not applicable (audit only)_ | N/A | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Complete (audit deliverable ready)

---

## Handoff Log

### bootstrap-agent → audit team
- **Date:** 2026-03-14
- **Notes:** Workspace created. Three expert agents dispatched for parallel audits.

### audit team → architect
- **Date:** 2026-03-14
- **Notes:** Three expert audit reports completed:
  - c-expert: `c-expert/dev-notes.md` — C++ combat, stats, AC, spells, regen
  - lua-expert: `lua-expert/dev-notes.md` — Lua behavior scripts, equipment, stance, buffs
  - data-expert: `data-expert/dev-notes.md` — Database NPC stats, spell lists, scaling
  Architect synthesized into: `architect/architecture.md`

---

## Implementation Tasks

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | C++ audit: companion stats, melee, HP/mana, regen, AC, attack formulas | c-expert | Complete | Findings in c-expert/dev-notes.md |
| 2 | Lua audit: companion behavior scripts, stat scaling, equipment effects, stance logic | lua-expert | Complete | Findings in lua-expert/dev-notes.md |
| 3 | Database audit: companion spell lists, NPC stats, class/race scaling, equipment data | data-expert | Complete | Findings in data-expert/dev-notes.md |
| 4 | Synthesize audit findings into gap analysis report | architect | Complete | architect/architecture.md |

---

## Key Findings Summary

**3 Critical Gaps:**
- GAP-01: Companions cannot critical hit (NPCCanCrit gate blocks them)
- GAP-02: PC-only spells cannot target companions (missing IsCompanion() in pcnpc_only_flag check)
- GAP-03: Missing defensive skills (Parry, Riposte, Dodge, Block, Defense all likely zero)

**4 Major Gaps:**
- GAP-04: Homogeneous base stats (no class/race differentiation — wizard has same STR as warrior)
- GAP-05: Shaman spell healing priority not differentiated (all heals at priority 1)
- GAP-06: Class-neutral base melee damage (wizard and warrior do same NPC base damage)
- GAP-07: Autonomous combat spell casting quality dependent on spell priority data

**5 Intentional Divergences (NOT gaps):**
- Always-meditate mana regen, no fizzle, resist caps at ~70%, free first cast at full mana, OOC HP regen percentage

See `architect/architecture.md` for complete analysis, fix recommendations, and prioritized roadmap.

---

## Open Questions

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Companion mana (Lydl 1798 vs expected ~778) — stored or calculated? | data-expert | c-expert | Open | |
| 2 | Do companions lose XP on death like players? | lua-expert | c-expert | Open | |
| 3 | Do group spells (Group Heal, Aegolism) hit companion NPCs? | lua-expert | c-expert | Open | |

---

## Blockers

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| None | | | |

---

## Bug Reports

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| | No bugs — this is an audit task | | | | | |

---

## Decision Log

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Skipped Design phase — audit does not need a PRD | architect | 2026-03-14 | Research task, not a feature build |
| 2 | Organized report by gap severity rather than system | architect | 2026-03-14 | Prioritized for fix roadmap clarity |
| 3 | Classified always-meditate, no-fizzle, resist caps as intentional divergences | architect | 2026-03-14 | These are documented design decisions per PRD |

---

## Completion Checklist

### Implementation Complete (agents can check these)

- [x] All audit tasks marked Complete
- [x] No open Blockers
- [x] Synthesized report written: architect/architecture.md
- [ ] User reviewed and approved findings

### Merge & Cleanup (USER-INITIATED ONLY)

- [ ] User confirmed audit is complete
- [ ] Feature branch merged to main in ALL affected repos
- [ ] Main pushed to origin in ALL affected repos
- [ ] Stale feature branches deleted (local + remote)

**Merged by:** _name_
**Merge date:** _YYYY-MM-DD_

---

## Notes

This audit identified 17 specific gaps (3 critical, 4 major, 3 moderate, 7 minor) across three system layers. The prioritized fix roadmap in architect/architecture.md provides a clear path to implementation when the user is ready to proceed. Fixes should be implemented in a separate feature branch (e.g., `feature/companion-authenticity-fixes`).
