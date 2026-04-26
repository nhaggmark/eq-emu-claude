# Raid Scaling — Project Completion Summary

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-22
> **Status:** All 6 implementation phases COMPLETE — server-side PASS on all phases
> **Awaiting:** User in-game spot-test confirmation → project-completion confirmation → branch merge

---

## Project Overview

The raid-scaling project systematically brought all Classic through Luclin raid-tier content
within reach of a 1-3 player group using Titanium client on a custom EverQuest server. The
prior small-group-scaling pass (2026-02-23) had explicitly excluded `raid_target=1` NPCs,
leaving ~200 true-boss encounters at PEQ defaults with HP gaps ranging from 2x (Classic
dragons) to 63x (Aten Ha Ra, the largest gap in the project). The project closed all gaps
using SQL-only changes to `npc_types`, `spawn2`, and `npc_spells_entries`.

---

## Cumulative Totals

### npc_types UPDATEs (HP and/or damage)

| Phase | ERA | npc_types rows changed | Notes |
|-------|-----|------------------------|-------|
| Phase 2 — Classic | Classic | 49 | PoFear + PoHate revamp + PoSky + Nagafen/Vox + Classic dragons + Q13 triggered-spawn NPCs |
| Phase 3 — Kunark | Kunark | 21 | Trakanon + VP revamp dragons + Chardok royals + outdoor dragons + Kilidna + Renux Herkanor |
| Phase 4a — Velious non-ToV | Velious | 35 | Kael + Skyshrine + PoG + outdoor Velious + Velketor + Siren's Grotto + Dain + Ring War Lever 1 |
| Phase 4b — Velious ToV+Sleeper+Vulak+AoW | Velious | 51 | 16 ToV lords + 16 NToV mid-tier + 4 Defenders + 13 Sleeper's Tomb + AoW + Vulak |
| Phase 5a — Luclin non-VT | Luclin | 41 | ssratemple + akheva + sseru/katta + griegsend + acrylia + thedeep + umbral |
| Phase 5b — Luclin VT (FINAL) | Luclin | 124 | Aten Ha Ra dual + 9 inner-VT bosses + Thall Va Xakra dual + Va_Dyn_Khar + 6 Akhevan Warders + 103 Yaemiu trash + A_burrower_parasite |
| **TOTAL** | | **321** | |

Note: The architecture estimated 125 npc_types UPDATEs for Phase 5b; 124 confirmed in DB
(1 less than estimate reflects a counting difference in the Yaemiu batch; 4 orphaned
Yaemiu IDs with no spawn2/spawnentry coverage were not in the architecture's planned ID
list — see Phase 5b server-side validation WARN note).

### spawn2.respawntime UPDATEs

| Phase | Rows updated | Target respawntime | Notes |
|-------|-------------|-------------------|-------|
| Phase 2 — Classic | ~40 | 21,600s (6h) or 43,200s (12h) | Low-tier 6h; Cazic-Thule/Guardian 12h |
| Phase 3 — Kunark | ~14 | 43,200s (12h) | VP + Trakanon + outdoor Kunark dragons |
| Phase 4a — Velious non-ToV | ~15 | 43,200s (12h) | Kael + Skyshrine + PoG + outdoor Velious (not Ring War Kromrif) |
| Phase 4b — Velious ToV+Sleeper+Vulak+AoW | ~32 | 86,400s (24h) | ToV + Sleeper's Tomb + AoW + Vulak |
| Phase 5a — Luclin non-VT | ~21 | 86,400s (24h) | ssratemple endgame + akheva + sseru/katta + grieg + acrylia + thedeep + umbral |
| Phase 5b — Luclin VT (FINAL) | 12 | 86,400s (24h) | 9 inner-VT bosses + Thall Va Xakra dual (Kaas_Thox has 2 spawn2 rows) |
| **TOTAL** | **~134** | | |

Note: Phase 2 spawn2 backup captured 6,669 rows (project-wide over-capture of full table
for safety); Phase 5b captured 990 rows (Yaemiu spawn2 rows included for rollback
completeness). Actual rows with modified respawntime values are the per-phase estimates
above.

### npc_spells_entries DELETEs

| Phase | Spell | Effect | List(s) | Rows deleted | Decision |
|-------|-------|--------|---------|-------------|---------|
| Phase 2 — Classic | 982 (Cazic Touch) | -100,000 HP single-target DT | 118 (Spiroc Lord), 449 (Bazzt Zzzt), 969 (Keeper of Souls) | 3 | Decision #16 |
| Phase 5a — Luclin non-VT | 2859 (Touch of Vinitras) | -20,000 HP single-target DT | 196 (Vyzh\`dra Exiled + Banished) | 1 | Decision #54/#60 |
| Phase 5b — Luclin VT (FINAL) | 1948 (Destroy) | -100,000 HP PBAE DT | 229 (Aten Ha Ra Destroy form) | 1 | Q67=B |
| **TOTAL** | | | **5 rows deleted** | **5** | |

**Preserved DTs (intentional):**
- Spell 1948 (Destroy) in list 489: Kerafyrm (Phase 4b Decision #12 — preserve as
  signature awake-event punishment)
- Spell 2859 (Touch of Vinitras) in list 179: Shei Vinitras REAL form (Phase 5a
  Decision #60 — preserve as signature mechanic)

### Lua/Perl Script Edits

| Phase | Script | Change | Agent |
|-------|--------|--------|-------|
| Phase 4a — Velious non-ToV | (Lever 2 not triggered — lua-expert conditional not invoked) | None | — |
| Phase 5a — Luclin non-VT | `akk-stack/server/quests/ssratemple/#EmpCycle.pl:3` | Emperor Ssraeshza respawn timer: 3-5 days → 22-24h (Decision Q52=B) | perl-expert |
| Phase 5b — Luclin VT (FINAL) | None (Q70=A: KEEP NATIVE Aten respawn; Decision #11: all vexthal scripts preserved) | None | — |
| **TOTAL** | **1 file edited** | | |

### Advisor Decisions Resolved

The architect surfaced 82 numbered user decisions (Q1-Q70 plus follow-up decisions
#1-#82 integrated into the Decision Log across all phases). Key decision categories:

- **HP scaling approach**: Decision #1 (SQL-only levers confirmed)
- **Respawn tiers**: Decision #8 (6h low-tier, 12h mid-tier, 24h endgame)
- **Signature mechanic preservation**: Decision #11 (special_abilities, scripts, DT
  boundary cases all preserved)
- **Kerafyrm Destroy preserved**: Decision #12 (Phase 4b — single-target DT as
  event punishment = preserve)
- **Death-touch removals**: Decision #16 (Cazic Touch / Touch of Vinitras / Aten
  Destroy = PBAE or unconditional DTs = remove)
- **Yaemiu Vex Thal trash inclusion**: Decision Q4=A (104 Yaemiu in scope)
- **Warder count corrected**: Decision #70 (6 not 8 Akhevan Warder NPC IDs)
- **Va_Dyn_Khar respawn preserved**: Decision #74 (21,600s 6h Palace Key cycle)

### Bug Reports Filed

| Bug | Description | Status |
|-----|-------------|--------|
| BUG-001 | Tunare combat boss (127098) not scaled — implementation targeted trigger NPC 127001 instead of combat boss | Fixed (Phase 4a fixup SQL 09-bug-001-tunare-fix.sql) |

Total bugs filed: **1**. All resolved within the same phase.

---

## Phase-by-Phase Summary

| Phase | ERA | Key accomplishments | Server-side result |
|-------|-----|---------------------|-------------------|
| Phase 2 — Classic | Classic | Fear/Hate/Sky/Nagafen/Vox/dragons all scaled; 3 Cazic Touch DELETEs (Spiroc Lord/Bazzt Zzzt/Keeper of Souls); Night Crew excluded per Decision #20 | PASS WITH NOTES (Innoruuk loottable pre-existing script loot — not a bug) |
| Phase 3 — Kunark | Kunark | Trakanon/VP revamp dragons/Chardok/Kilidna/outdoor all scaled; VP condition=2 filter precision; Renux Herkanor added per Decision #22 | PASS |
| Phase 4a — Velious non-ToV | Velious | Kael/Skyshrine/PoG/WW/Velketor/Sirens/Dain/Ring War Lever 1 scaled; BUG-001 Tunare filed and fixed; Yelinak dual-form scaled to 110k; Ring War Lever 2 not triggered | FAIL (BUG-001 filed) → PASS after fix |
| Phase 4b — Velious ToV+Sleeper+Vulak+AoW | Velious | All 16 ToV lords + NToV mid-tier + 4 Defenders + 13 Sleeper's Tomb + AoW + Vulak scaled; Kerafyrm trio preserved at 3.5M; Sleeper awake chain HP-independence proven | PASS |
| Phase 5a — Luclin non-VT | Luclin | All 8 Luclin non-VT zones scaled (ssratemple/akheva/sseru/katta/griegsend/acrylia/thedeep/umbral); Touch of Vinitras DELETE list 196 only (list 179 preserved); Emperor 22-24h cycle via perl-expert | PASS |
| Phase 5b — Luclin VT (FINAL) | Luclin | Vex Thal completed: Aten Ha Ra dual at 180k + Destroy PBAE DT removed; 9 inner-VT bosses at 85-160k; 6 Akhevan Warders at 80k; 103 Yaemiu trash level-tiered; Va_Dyn_Khar 60k + Palace Key preserved; A_burrower_parasite audit-leak closed | PASS WITH NOTES (4 orphaned Yaemiu IDs, non-blocking) |

---

## Completion Checklist for status.md

The following items should be ticked in status.md when the user confirms in-game testing:

- [ ] Phase 5b server-side validation: PASS WITH NOTES (non-blocking WARN on 4 orphaned Yaemiu IDs)
- [ ] Phase 5b in-game testing: Session 1 (Aten Destroy cache flush) — user executes
- [ ] Phase 5b in-game testing: Session 2 (Aten Ha Ra full kill) — user executes
- [ ] Phase 5b in-game testing: Sessions 3-7 (boss/warder/trash/burrower) — user executes
- [ ] All 6 implementation phases complete (Phases 2/3/4a/4b/5a/5b)
- [ ] All prior in-game testing accepted by user (Phases 2/3/4a/4b/5a)
- [ ] Phase 5b in-game testing accepted by user
- [ ] Branch `feature/raid-scaling` committed and pushed (all repos)
- [ ] **RAID SCALING PROJECT COMPLETE** — user confirmation to merge `feature/raid-scaling` into main

---

## Repository State at Project Completion

| Repo | Branch | Changed files |
|------|--------|---------------|
| `eqemu/` | `feature/raid-scaling` | None (0 C++ changes across entire project) |
| `akk-stack/` | `feature/raid-scaling` | 1 file: `server/quests/ssratemple/#EmpCycle.pl` (Phase 5a Q52=B) |
| `claude/` | `feature/raid-scaling` | Architecture docs, SQL files, validation reports, status.md |
| `spire/` | — | No changes |

The raid-scaling project made **zero engine changes** across all 6 phases. Every scaling
lever was a SQL-only change to 3 tables (`npc_types`, `spawn2`, `npc_spells_entries`) plus
one Perl script edit for Emperor Ssraeshza's respawn cycle timer. This reflects the
architecture's fundamental principle: scale stats via data, preserve behaviors via scripts.
