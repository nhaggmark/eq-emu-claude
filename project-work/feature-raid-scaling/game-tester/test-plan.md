# Raid Scaling Phase 2 — Test Plan

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-22
> **Server-side result:** PASS WITH NOTES

---

## Test Summary

Phase 2 Classic raid scaling is 100% SQL — no C++ or script changes. Three
database tables were modified: `npc_types` (~49 UPDATEs), `spawn2` (~40
UPDATEs), `npc_spells_entries` (3 DELETEs removing instakill spell 982 from
PoSky bosses). All changes were applied 2026-04-22 and a `#reloadworld` was
issued before zone processes restarted. Server is live and stable.

Server-side validation confirms all targets are correct in the DB. In-game
testing is required to confirm: (a) death-touch removal took effect in zone
memory (spell list cache), (b) difficulty feel matches the "slightly harder
than scaled named" target, and (c) loot and quest event chains still work.

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] status.md — all implementation tasks Complete (Tasks 1-10)
- [x] Acceptance criteria identified: 6 zones, 3 death-touch removals, respawn
  tier system, loot tables preserved, quest chains intact

---

## Part 1: Server-Side Validation

Full results in `game-tester/server-validation.md`. Summary below.

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Backup tables exist with correct row counts | PASS | npc_types: 2548, spawn2: 6669, npc_spells_entries: 6 |
| 2 | Cazic Touch captured in backup | PASS | 3 rows with spellid=982 confirmed |
| 3 | Classic dragons HP | PASS | Nagafen/Vox 14400, Phinigel 13500 |
| 4 | Plane of Fear bosses HP/damage | PASS | All 12 PoFear bosses at target values |
| 5 | Cazic Thule HP/damage/special_abilities | PASS | 80000 HP, 450 maxdmg, string unchanged (correct) |
| 6 | Q13 PoFear triggered adds | PASS | Ireblind Imp 35000, Enraged Golem 40000, Enraged Imp 18000 |
| 7 | hateplaneb bosses (23 NPCs) | PASS | All at target values including Innoruuk 60000/500, Evangelist 60000/600 |
| 8 | Intentionally unchanged hateplaneb NPCs | PASS | 7 NPCs confirmed unchanged at named-range HP |
| 9 | Plane of Sky bosses (9 NPCs) | PASS | All at target values |
| 10 | essence tamer unchanged, spell list intact | PASS | 11500 HP, spell 303 present |
| 11 | cazicthule zone event mobs (12 NPCs) | PASS | All at target values |
| 12 | Misc Classic (Thul Tae Ew, Zordakalicus, Guardian of Seal) | PASS | 25000/26000/87000 confirmed |
| 13 | Cazic Touch deleted from lists 118/449/969 | PASS | 0 rows with spellid=982 |
| 14 | Remaining spell entries preserved (1 per list) | PASS | spell 988, 897, 899 intact |
| 15 | Respawn timers: low-tier bosses 21600s | PASS | Nagafen, Vox, Phinigel, PoFear named, Maestro confirmed |
| 16 | Respawn timers: CT and Guardian of Seal 43200s | PASS | Both confirmed |
| 17 | hateplaneb outlier 186183 cut from 194400 to 21600 | PASS | Confirmed 21600 |
| 18 | Night Crew exclusion (20054-20064) | PASS | All 6 IDs match backup HP exactly |
| 19 | PoFear trash unchanged | PASS | a_scareling etc. match backup HP 14285 |
| 20 | Loot chains intact | PASS | Nagafen, CT, Keeper of Souls loottables valid; Innoruuk uses script loot (expected) |
| 21 | Global combat rules intact | PASS | MaxRampageTargets=2, all prior-pass rules confirmed |
| 22 | Server stable (8 zones, no crash loops) | PASS | loginserver, world, dynamic_01-08 running, no errors in logs |
| 23 | No recent crashes in raid zones | PASS | Most recent crash is 2026-04-20 in lavastorm (pre-implementation, unrelated) |
| 24 | Build verification N/A | PASS | 100% SQL, no C++ compiled |

### Quest Script Syntax

No quest scripts were modified. No syntax checks required.

### Log Analysis

World log and zone logs are clean — no errors, no warnings related to Phase 2
changes. The world log shows only standard zone connection Info messages after
the 20:42 restart.

### Rule Validation

No rule values were changed. Prior-pass combat rules confirmed intact via DB
query.

### Build Verification

Not applicable — Phase 2 is 100% SQL.

---

## Part 2: In-Game Testing Guide

Full guide in `game-tester/in-game-testing-guide.md`. Summary of test cases:

| Test | Zone | What | Priority |
|------|------|------|----------|
| N1 | soldungb | Nagafen — full kill, signature mechanics, 6h respawn | High |
| V1 | permafrost | Vox — full kill, same tier as Nagafen | High |
| F1 | fearplane | Pull 2 PoFear named bosses | High |
| F2 | fearplane | dracoliche — Wizard epic path | Medium |
| F3 | cazicthule | Cazic Thule — main boss, rampage cap, event mobs | High |
| F4 | fearplane | Q13 triggered adds (Ireblind/Enraged) | Low |
| S1 | airplane | Spiroc Lord — CRITICAL no death-touch | Critical |
| S2 | airplane | Bazzt Zzzt — CRITICAL no death-touch | Critical |
| S3 | airplane | Keeper of Souls — CRITICAL no death-touch | Critical |
| S4 | airplane | essence tamer — Ranger epic, throw mechanic | Medium |
| S5 | airplane | Other PoSky named 2-3 picks | Low |
| H1 | hateplaneb | Pull 1-2 revamp PoHate named | High |
| H2 | hateplaneb | Innoruuk — end boss, script loot check | High |
| M1 | kedge | Phinigel — epic component drop | Medium |
| M2 | hole | Guardian of the Seal — 12h timer check | Medium |
| M3 | lavastorm | Zordakalicus — spot check | Low |
| E1 | airplane | Edge case: no orphan cast after spell DELETE | Medium |
| E2 | cazicthule | Edge case: rampage cap <= 2 targets | Medium |
| E3 | fearplane | Edge case: trash mobs unchanged | Low |
| E4 | fearplane | Edge case: quest event_death chain fires | Medium |

---

## Blockers

None. Server-side validation passes completely. Proceed to in-game testing.

**One conditional flag:** If the user encounters a Cazic Touch proc in Plane
of Sky during tests S1-S3, the zone's spell list cache is stale. This is
expected behavior per the architecture (spell list cache loads at zone boot,
not on `#reloadworld`). The DB state is correct. The fix is:

1. File a brief observation report (not a bug — it's a documented known caveat)
2. Dispatch infra-expert to run full-stack restart
3. Retest S1-S3 after restart

---

## Recommendations

1. **Do tests S1-S3 (PoSky death-touch) first or early.** These are the most
   critical functional changes and require confirming the spell list cache is
   live. All other tests are purely difficulty-feel validation.

2. **Note difficulty feedback carefully for CT.** At 80000 HP he is the hardest
   Classic boss by design — if he feels "too hard" after all 6 companions are
   deployed, the user should report that as feel feedback so the architect can
   reassess the HP target for Phase 2 revision.

3. **hateplaneb loot via script.** Innoruuk's loot comes from event_loot in
   the quest script. If no loot appears after the kill, that is a pre-existing
   quest script issue — not a Phase 2 regression. Report it as a separate bug.
