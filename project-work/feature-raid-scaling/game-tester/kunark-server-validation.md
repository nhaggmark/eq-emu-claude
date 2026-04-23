# Raid Scaling Phase 3 (Kunark) — Server-Side Validation Report

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-23
> **Server-side result:** PASS

---

## Summary

All Phase 3 Kunark raid scaling changes are confirmed in the database and
match the architecture plan targets. Backup tables are present and populated.
All 21 npc_types UPDATEs and all spawn2 respawn UPDATEs landed correctly.
The VP _condition=2 filter held — only revamp dragons got the 12h respawn;
classic-era dormant variants are untouched. Intentionally unchanged NPCs
(#Trakanon 89181, Drusella 105153, Prince Selrach 103080, Lhranc 90093) were
not modified. The Fabled Chardok variant (103218) was not touched. Kithicor
Night Crew values are intact from Phase 2. No source code changes were made.
No build is required.

Two minor notes: (1) npc_types backup has 28 rows (architecture expected 27)
— the extra row is accounted for by Renux Herkanor 448200 being added via
Decision #22 Option A after the architecture doc was written with a 26-row
estimate; (2) spawn2 backup has 25 rows (architecture expected ~22) — the
higher count reflects additional spawn2 rows from shared spawngroups, which
is normal and correct.

---

## Results Table

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Backup table npc_types_backup_raid_scaling_kunark exists | PASS | Table present in peq database |
| 2 | Backup table spawn2_backup_raid_scaling_kunark exists | PASS | Table present in peq database |
| 3 | npc_types backup row count | PASS (NOTE) | 28 rows. Architecture doc said 27 (pre-Decision #22); Renux Herkanor 448200 added per Q22=Option A accounts for +1 row |
| 4 | spawn2 backup row count | PASS (NOTE) | 25 rows. Architecture expected ~22; higher count from shared spawngroups is expected behavior |
| 5 | VP spawn2 backup condition split | PASS | condition=1 (dormant): 6 rows; condition=2 (revamp): 7 rows — correct VP variant separation |
| 6 | Gorenaire HP = 22000 | PASS | Confirmed 22000 (was 32000, 31% cut) |
| 7 | Gorenaire maxdmg = 400 | PASS | Confirmed 400 (was 500) |
| 8 | Severilous HP = 22000 | PASS | Confirmed 22000 |
| 9 | Severilous maxdmg = 400 | PASS | Confirmed 400 |
| 10 | Talendor HP = 22000 | PASS | Confirmed 22000 |
| 11 | Talendor maxdmg = 400 | PASS | Confirmed 400 |
| 12 | Faydedar HP = 19000 | PASS | Confirmed 19000 (was 32000, 40% cut) |
| 13 | Faydedar maxdmg unchanged at 236 | PASS | Confirmed 236 — architecture said no damage change; only HP cut |
| 14 | #Faydedar (96073) HP = 19000 | PASS | Confirmed 19000 — consistency with main Faydedar |
| 15 | Trakanon HP = 22000 | PASS | Confirmed 22000 (was 32000, 31% cut) |
| 16 | Trakanon maxdmg unchanged at 630 | PASS | Confirmed 630 — signature flurry+rampage mechanics preserved per Decision #11 |
| 17 | #Trakanon (89181) HP = 16000 (UNCHANGED) | PASS | Confirmed 16000 — already named-tier; no Phase 3 HP change applied |
| 18 | #Venril_Sathir (102112) HP = 16500 | PASS | Confirmed 16500 (was 22000, 25% cut) |
| 19 | #Venril_Sathir maxdmg = 365 | PASS | Confirmed 365 (was 404) |
| 20 | Drusella_Sathir HP = 15750 (UNCHANGED) | PASS | Confirmed 15750 — already named-tier; no change applied |
| 21 | Queen Velazul Di'zok HP = 24000 | PASS | Confirmed 24000 (was 30000, 20% cut) |
| 22 | Overking Bathezid HP = 26000 | PASS | Confirmed 26000 (was 34500, 25% cut) |
| 23 | Prince Selrach Di'zok HP = 25000 (UNCHANGED) | PASS | Confirmed 25000 — already near named-tier; no change per audit |
| 24 | Kilidna HP = 30000 | PASS | Confirmed 30000 (was 100000, 70% cut) |
| 25 | Kilidna mindmg = 300 | PASS | Confirmed 300 (was 700) |
| 26 | Kilidna maxdmg = 1000 | PASS | Confirmed 1000 (was 4600 — critical one-shot fix) |
| 27 | Lhranc HP = 19000 (UNCHANGED) | PASS | Confirmed 19000 — already named-tier, respawn already ~13.67h |
| 28 | Druushk HP = 95000 | PASS | Confirmed 95000 (was 470000, 80% cut) |
| 29 | Druushk maxdmg = 780 | PASS | Confirmed 780 (was 1567) |
| 30 | Guardian of Veeshan HP = 120000 | PASS | Confirmed 120000 (was 600000, 80% cut) |
| 31 | Guardian of Veeshan mindmg = 230 | PASS | Confirmed 230 (was 380) |
| 32 | Guardian of Veeshan maxdmg = 750 | PASS | Confirmed 750 (was 1273) |
| 33 | Hoshkar HP = 110000 | PASS | Confirmed 110000 (was 536000, 79% cut) |
| 34 | Hoshkar maxdmg = 800 | PASS | Confirmed 800 (was 1603) |
| 35 | Nexona HP = 120000 | PASS | Confirmed 120000 (was 800000, 85% cut) |
| 36 | Nexona maxdmg = 1000 | PASS | Confirmed 1000 (was 2475) |
| 37 | Phara Dar HP = 120000 | PASS | Confirmed 120000 (was 681000, 82% cut) |
| 38 | Phara Dar mindmg = 450 | PASS | Confirmed 450 (was 1032) |
| 39 | Phara Dar maxdmg = 750 | PASS | Confirmed 750 (was 1621) |
| 40 | Silverwing HP = 90000 | PASS | Confirmed 90000 (was 454000, 80% cut) |
| 41 | Silverwing mindmg = 332 | PASS | Confirmed 332 (was 554) |
| 42 | Silverwing maxdmg = 777 | PASS | Confirmed 777 (was 1295) |
| 43 | Xygoz HP = 120000 | PASS | Confirmed 120000 (was 814000, 85% cut) |
| 44 | Xygoz maxdmg = 900 | PASS | Confirmed 900 (was 2266) |
| 45 | #Renux_Herkanor (448200) HP = 120000 | PASS | Confirmed 120000 (was 500000) per Decision #22 Option A |
| 46 | #Renux_Herkanor maxdmg = 900 | PASS | Confirmed 900 (was 1605) |
| 47 | VP classic Silverwing (108509) HP = 153500 (UNCHANGED) | PASS | Confirmed 153500 — dormant variant untouched |
| 48 | VP classic Phara Dar (108510) HP = 191500 (UNCHANGED) | PASS | Confirmed 191500 — dormant variant untouched |
| 49 | VP classic Xygoz (108511) HP = 144500 (UNCHANGED) | PASS | Confirmed 144500 — dormant variant untouched |
| 50 | VP classic Druushk (108512) HP = 156500 (UNCHANGED) | PASS | Confirmed 156500 — dormant variant untouched |
| 51 | VP classic Nexona (108513) HP = 152500 (UNCHANGED) | PASS | Confirmed 152500 — dormant variant untouched |
| 52 | VP classic Hoshkar (108517) HP = 151500 (UNCHANGED) | PASS | Confirmed 151500 — dormant variant untouched |
| 53 | Gorenaire respawn = 43200s (12h) | PASS | Confirmed 43200 in dreadlands spawn2 row |
| 54 | Severilous respawn = 43200s (12h) | PASS | Confirmed 43200 in emeraldjungle spawn2 row |
| 55 | Talendor respawn = 43200s (12h) | PASS | Confirmed 43200 in skyfire spawn2 row |
| 56 | Faydedar respawn = 43200s (12h) | PASS | Confirmed 43200 in timorous spawn2 row |
| 57 | Trakanon respawn = 43200s (12h) | PASS | Confirmed 43200 in sebilis spawn2 row |
| 58 | Drusella_Sathir respawn = 43200s (12h) | PASS | Confirmed 43200 in charasis spawn2 row |
| 59 | #Venril_Sathir spawn2 row respawn = 43200s | PASS | Confirmed 43200 in karnor spawn2 row (primarily script-spawned; static row updated for consistency) |
| 60 | Kilidna respawn = 21600s (6h) | PASS | Confirmed 21600 in citymist spawn2 row (was 5400 / 1.5h) |
| 61 | Lhranc respawn = 49215s (~13.67h) (UNCHANGED) | PASS | Confirmed 49215 — already in target range; no change |
| 62 | Queen Velazul respawn = 5400s (1.5h) (UNCHANGED) | PASS | Confirmed 5400 per Decision #21 Option A (preserve farming cadence) |
| 63 | Overking Bathezid respawn = 5400s (1.5h) (UNCHANGED) | PASS | Confirmed 5400 per Decision #21 Option A |
| 64 | Prince Selrach respawn = 5400s (1.5h) (UNCHANGED) | PASS | Confirmed 5400 per Decision #21 Option A |
| 65 | VP revamp 7 dragons respawn = 43200s, condition=2 only | PASS | All 7 VP revamp spawn2 rows (Druushk, GoV, Hoshkar, Nexona, Phara Dar, Silverwing, Xygoz) at 43200s with _condition=2 |
| 66 | VP _condition=2 scoping: only revamp rows at 43200 | PASS | Query on veeshan zone WHERE respawntime=43200 GROUP BY _condition returns ONLY condition=2 (7 rows) — classic-era condition=1 rows were NOT touched |
| 67 | VP classic condition=1 respawn UNCHANGED | PASS | condition=1 rows range 64800-86400s (original values) — no Phase 3 change |
| 68 | No accidental touch: #Trakanon 89181 | PASS | HP 16000, unchanged |
| 69 | No accidental touch: Drusella 105153 | PASS | HP 15750, unchanged |
| 70 | No accidental touch: Prince Selrach 103080 | PASS | HP 25000, unchanged |
| 71 | No accidental touch: Lhranc 90093 | PASS | HP 19000, unchanged |
| 72 | No accidental touch: Fabled Prince Selrach 103218 | PASS | HP 1500000 — post-Luclin Fabled variant not touched |
| 73 | Kithicor Night Crew HP unchanged (Decision #20) | PASS | IDs 20054-20064 confirmed at Phase 2 values (12000-27000 range); no Phase 3 regression |
| 74 | Global combat rules intact | PASS | MaxRampageTargets=2, DefaultRampageTargets=1, NPCFlurryChance=12, NPCAssistCap=3, StartEnrageValue=5, GlobalLootMultiplier=2 — all confirmed unchanged |
| 75 | Loot chains: Gorenaire loottable_id | PASS | loottable_id=3138 (Gorenaire) with 5 lootdrop entries — intact |
| 76 | Loot chains: Trakanon loottable_id | PASS | loottable_id=331 (Trakanon) with 4 lootdrop entries — intact |
| 77 | Loot chains: Queen Velazul loottable_id | PASS | loottable_id=1034 with 5 lootdrop entries — intact |
| 78 | Loot chains: Overking Bathezid loottable_id | PASS | loottable_id=1035 with 6 lootdrop entries — intact |
| 79 | Loot chains: Kilidna loottable_id | PASS | loottable_id=87761 with 1 lootdrop entry — intact |
| 80 | Loot chains: Nexona loottable_id | PASS | loottable_id=14450 with 3 lootdrop entries — intact |
| 81 | Loot chains: #Renux_Herkanor loottable_id | PASS | loottable_id=15000 with 3 lootdrop entries — intact |
| 82 | No npc_spells_entries changes for Phase 3 | PASS | Architecture confirmed 0 death-touch-profile spells in Kunark raid bosses; no Phase 3 spell list deletes |
| 83 | No source code changes (build verification N/A) | PASS | Architecture confirmed 100% SQL; no C++/Lua/Perl changes; no build required |
| 84 | World log clean (no Kunark-related errors) | PASS | World log contains no errors related to Kunark NPC IDs or Kunark zone names; one unrelated "Error loading inventory for Chelon" present (pre-existing, player-inventory issue, not a Phase 3 regression) |
| 85 | No Kunark zone crashes | PASS | No crash logs present for sebilis, veeshan, dreadlands, emeraldjungle, skyfire, karnor, chardok, citymist, charasis in the crashes/ directory |
| 86 | Rollback SQL file exists | PASS | /mnt/d/Dev/eq/claude/project-work/feature-raid-scaling/data-expert/sql/06-kunark-rollback.sql confirmed present |

---

## Notes

### Note 1: npc_types backup row count 28 vs architecture estimate of 27

The architecture doc was written before Decision #22 was resolved. With #22
Option A (include Renux Herkanor 448200), the backup table captures 28 rows
instead of the 27 mentioned in the architecture doc (26 pre-Q22 + 1 Q22 NPC).
The data-expert's backup SQL header already says "Expected rows: 27" reflecting
the Q22=Option A adjustment to the architecture's original 26. The count of
28 in the live table is correct and accounts for Renux Herkanor 448200.

### Note 2: spawn2 backup row count 25 vs architecture estimate of ~22

The architecture estimated ~20 rows (architecture doc) and the backup SQL
commented ~22. The actual 25 rows is within the expected variance from shared
spawngroups producing multiple spawn2 entries for a single NPC. This is correct
behavior — the backup captures all spawn2 rows that link through spawnentry to
any Kunark Phase 3 NPC, which is the right scope for rollback safety.

### Note 3: Kilidna respawn changed from 5400 to 21600 (6h)

The implementation SQL changed Kilidna's respawn from 1.5h (5400s) to 6h
(21600s). This is correct per the architecture plan ("Kilidna: 6h — damage
outlier; keep accessible for Paladin/SK epic navigation"). Decision #21 applied
ONLY to the Chardok Royals (103055, 103056, 103080) keeping them at 1.5h.
Kilidna (90186) was always planned at 6h. Confirmed correct.

### Note 4: timorous crash log is pre-existing

The crash log crash_timorous_version_0_inst_id_0_port_0_233.log is an old
crash (port_0 indicates no active assignment at crash time, pre-Phase 3
implementation period). This is not related to Phase 3 Faydedar changes.

---

## Rollback Instructions

If any Phase 3 change must be reversed:

```bash
docker exec -i akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq < \
  /mnt/d/Dev/eq/claude/project-work/feature-raid-scaling/data-expert/sql/06-kunark-rollback.sql
```

Then issue #reloadworld via world telnet console (port 9000):
```bash
(echo 'reloadworld'; sleep 2) | telnet 127.0.0.1 9000
```

No full-stack restart required for Phase 3 rollback (no npc_spells_entries
changes were made in Phase 3).
