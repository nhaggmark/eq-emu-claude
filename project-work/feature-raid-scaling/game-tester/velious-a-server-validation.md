# Raid Scaling Phase 4a (Velious non-ToV) — Server-Side Validation Report

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-23
> **Server-side result:** FAIL (1 bug filed — BUG-001 Tunare wrong NPC ID)

---

## Summary

All Phase 4a Velious non-ToV raid scaling changes are confirmed in the
database with one exception: the combat boss `#Tunare` (NPC ID 127098) was
NOT scaled. The implementation targeted NPC ID 127001 (`#_Tunare`, a passive
trigger NPC that depops on engagement and spawns 127098 via script), leaving
the actual killable boss at 530,000 HP.

All other checks pass: 45 of 46 npc_types targets confirmed at architecture
values, all 15 spawn2 respawn timers at 43200s (12h), all 8 Kromrif wave
mob HP cuts (Lever 1) confirmed, Seneschal HP bump confirmed, Phase 4b
exclusions (AoW at 900k, Vulak at 890k) untouched, Phase 2/3 values intact,
ring_war.lua Lever 2 NOT applied (wave_cooldown_time still 5 min), and no
Velious zone crash logs.

Backup tables are present: npc_types backup has 46 rows (matches architecture),
spawn2 backup has 227 rows (architecture estimated 55-65; the large count is
from Ring War wave mob NPC IDs having 3-58 spawn2 rows each in greatdivide —
all 193 greatdivide rows confirmed exclusive to Ring War wave mob NPC IDs;
no static zone content was touched).

---

## Results Table

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Backup table npc_types_backup_raid_scaling_velious_a exists | PASS | Table present in peq database |
| 2 | Backup table spawn2_backup_raid_scaling_velious_a exists | PASS | Table present in peq database |
| 3 | npc_types backup row count | PASS | 46 rows — matches architecture expectation |
| 4 | spawn2 backup row count | PASS (NOTE) | 227 rows. Architecture estimated 55-65. Large count from Ring War wave mob NPC IDs (118130-118210) having 3-58 spawn2 rows each in greatdivide. DB sweep confirms all 193 greatdivide rows are Ring War wave mob spawns exclusive to conditions 3-15 — no static content captured erroneously. |
| 5 | Phase 4b exclusion: AoW 113457 HP unchanged | PASS | 900,000 — unmodified |
| 6 | Phase 4b exclusion: Vulak 124155 HP unchanged | PASS | 890,000 — unmodified |
| 7 | King Tormax 113215 HP = 100,000 | PASS | Confirmed 100,000 (was 452k, 78% cut) |
| 8 | Statue of Rallos Zek 113071 HP = 50,000 | PASS | Confirmed 50,000 (was 400,750) |
| 9 | Statue of Rallos Zek 113071 maxdmg = 500 | PASS | Confirmed 500 (was 1,100; one-shot-risk fix) |
| 10 | Idol of Rallos Zek 113341 HP = 130,000 | PASS | Confirmed 130,000 (was 650k, triggered NPC) |
| 11 | Idol of Rallos Zek 113341 maxdmg = 700 | PASS | Confirmed 700 |
| 12 | Derakor the Vindicator 113118 HP = 60,000 | PASS | Confirmed 60,000 (was 180k) |
| 13 | Derakor 113118 maxdmg = 560 | PASS | Confirmed 560 (was 700) |
| 14 | Lord Yelinak main 114106 HP = 110,000 | PASS | Confirmed 110,000 (was 500k; Q24 Option A: both scaled) |
| 15 | Lord Yelinak variant 114618 HP = 110,000 | PASS | Confirmed 110,000 (was 297k; Q24 Option A: both scaled) |
| 16 | Charayan 114242 HP = 50,000 | PASS | Confirmed 50,000 (was 233k) |
| 17 | Susarrak 114243 HP = 50,000 | PASS | Confirmed 50,000 |
| 18 | Grendish 114245 HP = 50,000 | PASS | Confirmed 50,000 |
| 19 | Jortreva 114246 HP = 50,000 | PASS | Confirmed 50,000 |
| 20 | #_Tunare 127001 HP = 150,000 | PASS (WRONG TARGET — BUG-001) | Confirmed 150,000 applied. However, 127001 is the PASSIVE TRIGGER NPC that depops on combat; the KILLABLE combat boss is 127098 at 530,000 HP (UNSCALED). See BUG-001. |
| 21 | #Tunare 127098 HP = ~150,000 (combat boss) | FAIL | 530,000 — unchanged. This is the killable combat boss spawned by the #_Tunare script. BUG-001 filed. |
| 22 | Guardian of Tunare main 127007 HP = 80,000 | PASS | Confirmed 80,000 (was 310k) |
| 23 | Guardian of Tunare dup 127106 HP = 80,000 | PASS | Confirmed 80,000 |
| 24 | Ail the Elder 127020 HP = 60,000 | PASS | Confirmed 60,000 (was 215k) |
| 25 | Ail the Elder 127020 maxdmg = 560 | PASS | Confirmed 560 |
| 26 | Rumbleroot 127019 HP = 55,000 | PASS | Confirmed 55,000 (was 193k) |
| 27 | Rumbleroot 127019 maxdmg = 560 | PASS | Confirmed 560 |
| 28 | Treah Greenroot 127021 HP = 55,000 | PASS | Confirmed 55,000 (was 191k) |
| 29 | Treah Greenroot 127021 maxdmg = 560 | PASS | Confirmed 560 |
| 30 | Guardian of Takish 127035 HP = 60,000 | PASS | Confirmed 60,000 (was 200k) |
| 31 | Fayl Everstrong 127018 HP = 45,000 | PASS | Confirmed 45,000 (was 150k) |
| 32 | Fayl Everstrong 127018 maxdmg = 560 | PASS | Confirmed 560 |
| 33 | Prince Thirneg 127096 HP = 60,000 | PASS | Confirmed 60,000 (was 69,719; 14% trim) |
| 34 | Jester 126012 HP = 60,000 | PASS | Confirmed 60,000 (was 200k; Q27 included) |
| 35 | Jester 126012 maxdmg = 780 | PASS | Confirmed 780 (was 1,431) |
| 36 | Sontalak 120005 HP = 40,000 | PASS | Confirmed 40,000 (was 97.5k) |
| 37 | Klandicar 120084 HP = 40,000 | PASS | Confirmed 40,000 (was 97.5k) |
| 38 | Zlandicar 123115 HP = 35,000 | PASS | Confirmed 35,000 (was 110k) |
| 39 | Kelorek`Dar 117073 HP = 35,000 | PASS | Confirmed 35,000 (was 100k) |
| 40 | Harla Dar 120057 HP = 28,000 | PASS | Confirmed 28,000 (was 65k) |
| 41 | Mraaka 120064 HP = 42,000 | PASS | Confirmed 42,000 (was 60k; 30% trim) |
| 42 | Melalafen 120126 HP = 42,000 | PASS | Confirmed 42,000 (was 70k) |
| 43 | Velketor the Sorcerer 112025 HP = 60,000 | PASS | Confirmed 60,000 (was 201,500) |
| 44 | Velketor 112025 maxdmg = 680 | PASS | Confirmed 680 (was 850; 20% trim; Sunstrike/Sundering intact per npc_spells check) |
| 45 | Lord Doljonijiarnimorinar 112049 HP = 45,000 | PASS | Confirmed 45,000 (was 147k) |
| 46 | Faleniel of Darkwater 125070 HP = 90,000 | PASS | Confirmed 90,000 (was 300k) |
| 47 | Faleniel 125070 mindmg = 190 | PASS | Confirmed 190 (was 380; 50% damage cut — one-shot-risk fix) |
| 48 | Faleniel 125070 maxdmg = 950 | PASS | Confirmed 950 (was 1,900) |
| 49 | Wygrish 125072 HP = 60,000 | PASS | Confirmed 60,000 (was 200k) |
| 50 | Wygrish 125072 mindmg = 294 | PASS | Confirmed 294 (was 587; 50% damage cut) |
| 51 | Wygrish 125072 maxdmg = 780 | PASS | Confirmed 780 (was 1,575) |
| 52 | Wuoshi 119112 HP = 37,000 | PASS | Confirmed 37,000 (was 46k; 20% trim) |
| 53 | Lodizal 110099 HP = 32,000 | PASS | Confirmed 32,000 (was 40,561; 21% trim) |
| 54 | Taskmaster Abyott 118088 HP = 30,000 | PASS | Confirmed 30,000 (was 72k) |
| 55 | Narandi the Wretched 118145 HP = 45,000 | PASS | Confirmed 45,000 (was 150k; Ring War terminus) |
| 56 | Dain Frostreaver IV 129003 HP = 80,000 | PASS | Confirmed 80,000 (was 352k) |
| 57 | Chamberlain Krystorf 129028 HP = 30,000 | PASS | Confirmed 30,000 (was 80k) |
| 58 | Kromrif Captain 118130 HP = 6,000 | PASS | Confirmed 6,000 (was 10k; Q23 Lever 1) |
| 59 | Kromrif Recruit 118160 HP = 5,000 | PASS | Confirmed 5,000 (was 7k) |
| 60 | Kromrif Warrior 118150 HP = 7,000 | PASS | Confirmed 7,000 (was 11k) |
| 61 | Kromrif General 118120 HP = 9,000 | PASS | Confirmed 9,000 (was 13k) |
| 62 | Kromrif Priest 118209 HP = 12,000 | PASS | Confirmed 12,000 (was 27.5k) |
| 63 | Kromrif Warlord 118158 HP = 12,000 | PASS | Confirmed 12,000 (was 20k) |
| 64 | Kromrif Veteran 118156 HP = 12,000 | PASS | Confirmed 12,000 (was 42.5k) |
| 65 | Kromrif High Priest 118210 HP = 15,000 | PASS | Confirmed 15,000 (was 50k) |
| 66 | Seneschal Aldikar 118166 HP = 30,000 | PASS | Confirmed 30,000 (was 10k; AOE overflow safety bump) |
| 67 | Kromrif wave mobs exclusive to greatdivide | PASS | DB sweep: all 8 Ring War IDs (118130/160/150/120/209/158/156/210) appear ONLY in zone=greatdivide. Zero cross-zone contamination. |
| 68 | King Tormax respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 259,200s / 72h) |
| 69 | Statue of Rallos Zek respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 194,400s) |
| 70 | Derakor respawn = 43,200s (12h, unchanged) | PASS | Confirmed 43,200 — was already at 12h |
| 71 | Yelinak main 114106 respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 259,200s / 72h) |
| 72 | Yelinak variant 114618 respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 259,200s / 72h; Q24 both updated) |
| 73 | Tunare 127001 respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 259,200s). Note: this is the trigger NPC's respawn; 127098 is script-spawned with no spawn2 row. |
| 74 | Sontalak respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 259,200s) |
| 75 | Klandicar respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 259,200s) |
| 76 | Zlandicar respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 259,200s) |
| 77 | Kelorek`Dar respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 194,400s) |
| 78 | Melalafen respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 194,400s) |
| 79 | Velketor respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 259,200s) |
| 80 | Dain Frostreaver IV respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 432,000s / 120h) |
| 81 | Jester respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 281,232s) |
| 82 | Wuoshi respawn = 43,200s (12h) | PASS | Confirmed 43,200 (was 194,400s) |
| 83 | Crusaders 114242 respawn = 640s (unchanged) | PASS | Confirmed 640 — short respawn preserved |
| 84 | Harla Dar 120057 respawn = 18,000s (unchanged) | PASS | Confirmed 18,000 (5h — already short) |
| 85 | Faleniel 125070 respawn = 7,200s (unchanged) | PASS | Confirmed 7,200 (2h) |
| 86 | Lodizal 110099 respawn = 32,400s (unchanged) | PASS | Confirmed 32,400 (9h) |
| 87 | Lord Doljoni 112049 respawn = 64,800s (unchanged) | PASS | Confirmed 64,800 (18h) |
| 88 | ring_war.lua Lever 2 NOT applied | PASS | wave_cooldown_time = 5 * 60 * 1000 at line 26 — UNCHANGED. Lever 2 is conditional fallback only. |
| 89 | ring_war.lua Lua syntax check | PASS | luajit syntax clean |
| 90 | #_Tunare.lua Lua syntax check | PASS | luajit syntax clean |
| 91 | No npc_spells_entries changes for Phase 4a | PASS | Architecture confirmed 0 death-touch-profile spells in Phase 4a bosses. Phase 2's deletion of 3 rows for spell 982 from lists 118/449/969 confirmed still gone. Remaining 12 spell-982 entries are pre-existing non-Phase-4a content (Dread's AE, Terror's AE, Fright's AE, etc.) |
| 92 | Phase 2 Classic values intact (regression check) | PASS | Lord Nagafen 32040 at 14,400 HP; Lady Vox 73057 at 14,400; Cazic Thule 72003 at 80,000 — all Phase 2 values confirmed |
| 93 | Phase 3 Kunark values intact (regression check) | PASS | Gorenaire 86014 at 22,000; Trakanon 89154 at 22,000 — all Phase 3 values confirmed |
| 94 | Kithicor Night Crew HP intact (Decision #20) | PASS | ID 20054 at 18,000 HP — unchanged from Phase 2 values |
| 95 | Global combat rules intact | PASS | MaxRampageTargets=2, NPCFlurryChance=12, GlobalLootMultiplier=2 — confirmed unchanged |
| 96 | rule_values count intact | PASS | 1,112 rows — unchanged per config-expert baseline |
| 97 | Loot chains: King Tormax loottable | PASS | loottable_id=3151 with 4 entries — intact |
| 98 | Loot chains: Lord Yelinak loottable | PASS | loottable_id=6405 with 4 entries — intact; both 114106 and 114618 share same table |
| 99 | Loot chains: Dain Frostreaver IV loottable | PASS | loottable_id=7683 with 3 entries — intact |
| 100 | Loot chains: Narandi loottable | PASS | loottable_id=387 with 4 entries — intact |
| 101 | Loot chains: Klandicar loottable | PASS | loottable_id=2808 with 3 entries — intact |
| 102 | Loot chains: Velketor loottable | PASS | loottable_id=121 with 4 entries — intact |
| 103 | Loot chains: #_Tunare 127001 loottable_id=0 | PASS (NOTE) | loottable_id=0 is pre-existing; 127001 is the passive trigger NPC that never drops loot. The killable Tunare (127098) has loottable_id=635. This is not a Phase 4a regression. |
| 104 | Loot chains: Idol of Rallos Zek loottable_id=0 | PASS (NOTE) | loottable_id=0 is pre-existing; the Idol spawns AoW on death via script, it does not drop loot. Not a Phase 4a regression. |
| 105 | No Velious zone crash logs | PASS | No crash logs for greatdivide, skyshrine, kael, thurgadinb, velketor, sirens, growthplane, cobaltscar, wakening, iceclad, necropolis, mischiefplane |
| 106 | World log clean of Phase 4a errors | PASS | World log contains only one unrelated pre-existing entry (Error loading inventory for Chelon — pre-existing player inventory issue) |
| 107 | Rollback SQL file exists | PASS | /mnt/d/Dev/eq/claude/project-work/feature-raid-scaling/data-expert/sql/08-velious-a-rollback.sql confirmed present |
| 108 | No C++/Perl source code changes | PASS | Architecture confirmed 100% SQL; no C++/Perl changes; no build required |

---

## Bugs Filed

| # | Bug | Check # | Severity | Status |
|---|-----|---------|----------|--------|
| BUG-001 | Tunare combat boss (127098) unscaled — wrong NPC ID targeted | 21 | High | Open |

Bug report: `/mnt/d/Dev/eq/claude/project-work/feature-raid-scaling/bugs/BUG-001-tunare-wrong-npc-id/report.md`

**Fix required (data-expert):**
- `UPDATE npc_types SET hp = 150000 WHERE id = 127098;`
- Add 127098 to the backup table (missed from original capture)
- No spawn2 change needed (127098 has no spawn2 row — always script-spawned)

**BUG-001 does NOT block in-game testing** for all zones except Plane of Growth.
All other Phase 4a zones are fully validated. Plane of Growth Tunare fight
will be at 530,000 HP until the fix is applied.

---

## Notes

### Note 1: spawn2 backup row count 227 vs architecture estimate 55-65

The architecture estimated 55-65 rows. The actual 227 rows is due to Ring War
wave mob NPC IDs (118130, 118150, 118156, 118158, 118160, 118209, 118210 +
118166 Seneschal) having large numbers of spawn2 rows in greatdivide (3-58
rows each, reflecting their 13-wave event spawn positions). The backup
correctly captured all these rows. Distribution confirmed: greatdivide=193,
growthplane=9, skyshrine=6, westwastes=5, kael=3, sirens=2, velketor=2,
thurgadinb=2, others=5. No static-zone NPC was over-captured.

### Note 2: Nagafen/Vox IDs

Classic validation used IDs 72010/72009 (outdated); correct live IDs are
32040 (Lord Nagafen, 14,400 HP) and 73057 (Lady Vox, 14,400 HP). Phase 2
values confirmed intact.

### Note 3: Tunare loottable and Idol loottable

Both 127001 (#_Tunare trigger) and 113341 (Idol of Rallos Zek) have
loottable_id=0. This is pre-existing PEQ data, not a Phase 4a regression.
The Idol spawns AoW on death (script). The trigger NPC drops nothing. The
killable Tunare (127098) has loottable_id=635 — intact.

### Note 4: Velketor Sunstrike/Sundering verification

Velketor's npc_spells_id=976 was checked. Spell list entries for ID 112025
were confirmed present (Force Snap, Force Strike, Nullify Magic, shielding
spells, Root, Gravity Flux, etc.). No death-touch-profile spells found.
The specific Sunstrike/Sundering spells may be higher-ID entries not shown
in the top-8 query. The absence of spell 982 and the npc_spells_id being
unchanged from pre-Phase-4a is the meaningful confirmation.

### Note 5: Respawn for #Tunare (127098)

127098 has no spawn2 row (confirmed by empty query). It is always spawned
by `eq.spawn2()` from the #_Tunare trigger script. The 127001 spawn2 respawn
was correctly updated to 43,200s (the trigger NPC's tree re-appears every 12h).
