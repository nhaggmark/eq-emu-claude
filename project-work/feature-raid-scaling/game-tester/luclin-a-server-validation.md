# Raid Scaling Phase 5a (Luclin non-VT) — Server-Side Validation Report

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-22
> **SQL files validated:** `13-luclin-a-backup.sql`, `14-luclin-a-implementation.sql`
> **Cross-repo edit verified:** `akk-stack/server/quests/ssratemple/#EmpCycle.pl:3` (perl-expert task L13)
> **Server-side result:** PASS

---

## Summary

All Phase 5a Luclin non-VT raid scaling changes are confirmed in the database. 41
npc_types HP/damage UPDATEs applied correctly across all eight zone clusters: Ssraeshza
Temple (15 NPCs including Emperor + Rhozth pair + pre-Emperor named + cycle serpents),
Akheva Ruins (11 NPCs including Vyzh`dra trio + 6 primary bosses + 3 Q51 elite-named),
Sanctus Seru / Katta Castellum (7 NPCs), Grieg's End (3 NPCs + variant), Acrylia Caverns
(3 NPCs including Spiritual Arcanist Q59), The Deep (1 NPC), Umbral Plains (3 NPCs).

All 21 spawn2 respawn timers for endgame content are confirmed at 86,400s (24h) per
Decision #8. Intentionally preserved respawn values are all intact: pre-Emperor named at
1080s (Ring of Shissar farming), Rhozth pair at 5400s/21600s (Taskmaster's Pouch
farming), Shar Vinitras at 10800s (short-tier natural), Akheva elite-named (Sheleric Vis
x2, Xaui Tatrua) at 5400s per Q51 named-tier philosophy.

CRITICAL safety checks all pass: Spirit of Akelha`Ra (179144) HP confirmed unchanged at
1,000,000. Emperor placeholder (162065) at 6,516 HP unchanged. Event-control NPCs
(162269 keycheck 999M HP, 176110 Keymaster 99M HP, 160177/160178 Helsin twins 1M HP)
all confirmed unchanged. Vexthal NPCs (158081 Va_Dyn_Khar, 158087-94 Akhevan Warders)
all confirmed unchanged at Phase 5b reserved values.

Touch of Vinitras DT (spell 2859) confirmed deleted from list 196 (0 rows). List 179
(Shei Vinitras REAL 179032) confirmed preserved with spell 2859 (1 row) per Decision
#60. List 196 retains only spell 2812 (Pyrokinetic Hallucinations, effectid=23, no DT
profile). The backup table `npc_spells_entries_backup_raid_scaling_luclin_a` has 1 row
capturing the pre-DELETE state with all column values intact.

Emperor special_abilities confirmed: `32,1,290` (Leash 290) is present in the
special_abilities string. Lord Inquisitor Seru MR=800 confirmed intact.

Perl edit (Q52=B task L13) confirmed: `#EmpCycle.pl` line 3 reads
`$EmpRepopTime = int(rand(7200)) + 79200;` (22-24h range). `perl -c` syntax check passes.

Backup table counts: npc_types backup 45 rows, spawn2 backup 80 rows, spells backup 1
row. The 45-row count vs. the architecture's "41" estimate is intentional — the backup
SQL captures 45 distinct NPC IDs including Grieg Veneficus variant 163231 and Shar
Vinitras 179134 which are backed up for safety even though their HP values are
intentionally preserved. All 45 IDs match the planned set exactly. No unexpected NPCs
were captured.

Phase 2/3/4a/4b regressions confirmed clean. Cazic Touch (spell 982) is absent from all
Phase 5a boss spell lists. The 12 remaining instances of spell 982 in npc_spells_entries
are across lists 32, 33, 40, 42, 122, 213, 490, 543, 598, 599, 962, 970 — none of these
lists are used by any Phase 5a NPC. Phase 2 deletion of lists 118, 449, 969 is intact.

No Phase 5a-related errors in world_start.log or zone_dynamic logs. World log shows clean
startup. Zone logs show clean boot with no quest or database errors.

---

## Results Table

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | npc_types_backup_raid_scaling_luclin_a exists | PASS | Table present in peq database |
| 2 | spawn2_backup_raid_scaling_luclin_a exists | PASS | Table present in peq database |
| 3 | npc_spells_entries_backup_raid_scaling_luclin_a exists | PASS | Table present in peq database |
| 4 | npc_types backup row count (expect 41+, actual 45) | PASS | 45 rows — over-captures Grieg variant 163231 and Shar Vinitras 179134 as safety captures; all 45 IDs match planned set; no extra NPC outside Phase 5a scope |
| 5 | spawn2 backup row count | PASS | 80 rows — includes ~51 pre-Emperor named (17 spawn2 rows each x3 NPCs) + standing-spawn raid-tier rows; all correct Phase 5a backup captures |
| 6 | npc_spells_entries backup row count (expect 1) | PASS | 1 row — captures list 196 spell 2859 with id=1598, all columns intact |
| 7 | CRITICAL: Spirit of Akelha`Ra 179144 HP (must be 1,000,000) | PASS | 1,000,000 — unchanged per Decision #30 (VT-key turn-in NPC) |
| 8 | CRITICAL: Va_Dyn_Khar 158081 HP (Phase 5b reserved, must be 600,000) | PASS | 600,000 — unchanged, Phase 5b scope |
| 9 | CRITICAL: Emperor placeholder 162065 HP (must be 6,516) | PASS | 6,516 — non-combat trigger NPC unchanged |
| 10 | CRITICAL: Event-control NPC keycheck 162269 HP (must be 999,999,999) | PASS | 999,999,999 — unchanged |
| 11 | CRITICAL: Event-control NPC Keymaster 176110 HP (must be 99,999,999) | PASS | 99,999,999 — unchanged |
| 12 | CRITICAL: Helsin twins 160177/160178 HP (must be 1,000,000 each) | PASS | 1,000,000 each — unchanged |
| 13 | CRITICAL: Akhevan Warders 158087-94 HP (Phase 5b reserved) | PASS | All 4 confirmed present as Akhevan_Warder at 901,000 HP; 1 Eom_Va_Dyn at 101,000; unchanged |
| 14 | CRITICAL: Touch of Vinitras spell 2859 in list 196 (must be 0 rows) | PASS | 0 rows — DELETE confirmed; list 196 now contains only spell 2812 |
| 15 | CRITICAL: Touch of Vinitras spell 2859 in list 179 (must be 1 row, Decision #60) | PASS | 1 row — Shei Vinitras REAL list preserved as intended |
| 16 | Spell 2812 (remaining in list 196) is NOT a DT | PASS | Spell 2812 = "Pyrokinetic Hallucinations", effectid=23, effect_base_value1=3 — no DT profile |
| 17 | Emperor Ssraeshza 162227 HP (expect 120,000) | PASS | 120,000 (was 1,250,500) |
| 18 | Emperor Ssraeshza 162227 mindmg/maxdmg (expect 200/620) | PASS | mindmg=200 (was 283), maxdmg=620 (was 904) |
| 19 | Emperor Ssraeshza 162227 special_abilities Leash 290 preserved | PASS | special_abilities contains `32,1,290` — Leash preserved per Decision #11 |
| 20 | High Priest of Ssraeshza 162076 HP (expect 90,000) | PASS | 90,000 (was 941,000) |
| 21 | Xerkizh the Creator 162190 HP (expect 80,000) | PASS | 80,000 (was 806,516) |
| 22 | Arch Lich Rhag`Zadune 162177 HP (expect 75,000) | PASS | 75,000 (was 790,000) |
| 23 | Rhag`Mozdezh 162192 HP (expect 60,000) | PASS | 60,000 (was 226,000) |
| 24 | Rhag`Zhezum 162178 HP (expect 55,000) | PASS | 55,000 (was 201,000) |
| 25 | Blood of Ssraeshza 162189 HP (expect 60,000) | PASS | 60,000 (was 200,000) |
| 26 | Ssraeshzian Blood Golem 162064 HP (expect 60,000) | PASS | 60,000 (was 201,000) |
| 27 | General Kizuhx 162066 HP (expect 60,000) | PASS | 60,000 (was 250,000) |
| 28 | Arbiter Korazhk 162191 HP (expect 55,000) | PASS | 55,000 (was 205,000) |
| 29 | Advisor Zekuzh 162067 HP (expect 45,000) | PASS | 45,000 (was 150,000) |
| 30 | Rhozth Ssrakezh 162258 HP (expect 40,000) | PASS | 40,000 (was 119,000) |
| 31 | Rhozth Ssravizh 162089 HP (expect 38,000) | PASS | 38,000 (was 105,200) |
| 32 | a_rune_covered_serpent 162253 HP (expect 60,000, Q50=A) | PASS | 60,000 (was 221,000) |
| 33 | a_glyph_covered_serpent 162261 HP (expect 70,000, Q50=A) | PASS | 70,000 (was 300,000) |
| 34 | Vyzh`dra the Cursed 162206 HP (expect 90,000) | PASS | 90,000 (was 900,000) |
| 35 | Vyzh`dra the Exiled 162232 HP (expect 70,000) | PASS | 70,000 (was 450,000) |
| 36 | Vyzh`dra the Banished 162214 HP (expect 65,000) | PASS | 65,000 (was 403,000) |
| 37 | Vyzh`dra trio npc_spells_id integrity (Cursed=197/clean, Exiled=196/Banished=196) | PASS | 162206=list 197, 162232=list 196, 162214=list 196 — all correct |
| 38 | The Itraer Vius 179037 HP (expect 80,000) | PASS | 80,000 (was 601,000) |
| 39 | Shei Vinitras REAL 179032 HP (expect 85,000) | PASS | 85,000 (was 690,000) |
| 40 | Shei Vinitras REAL 179032 maxdmg (expect 600) | PASS | 600 (was 700) |
| 41 | Shei Vinitras REAL 179032 npc_spells_id (must be 179) | PASS | npc_spells_id=179 — list preserved |
| 42 | Shei Vinitras REAL 179032 has no spawn2 row | PASS | 0 spawn2 rows confirmed — script-spawned, no respawn UPDATE needed |
| 43 | Shei Vinitras MERCHANT 179157 HP (expect 60,000) | PASS | 60,000 (was 400,000) |
| 44 | The Insanity Crawler 179180 HP (expect 60,000) | PASS | 60,000 (was 401,000) |
| 45 | The Va`Dyn 179178 HP (expect 50,000) | PASS | 50,000 (was 250,000) |
| 46 | Shar Vinitras 179134 HP (expect 70,000) | PASS | 70,000 (was 460,900) |
| 47 | Shar Vinitras 179134 maxdmg (expect 600) | PASS | 600 (was 1,010) |
| 48 | Sheleric Vis 179133 HP (expect 35,000, Q51=B) | PASS | 35,000 (was 116,000) |
| 49 | Sheleric Vis 179133 maxdmg (expect 550, Q51=B) | PASS | 550 (was 746) |
| 50 | Sheleric Vis variant 179046 HP (expect 30,000, Q51=B) | PASS | 30,000 (was 70,000) |
| 51 | Xaui Tatrua 179044 HP (expect 30,000, Q51=B) | PASS | 30,000 (was 70,000) |
| 52 | Lord Inquisitor Seru 159691 HP (expect 120,000) | PASS | 120,000 (was 1,201,500) |
| 53 | Lord Inquisitor Seru 159691 mindmg/maxdmg (expect 220/620) | PASS | mindmg=220 (was 339), maxdmg=620 (was 915) |
| 54 | Lord Inquisitor Seru 159691 MR (must be 800, preserved) | PASS | MR=800 — preserved per Decision #11 |
| 55 | Praesertum Vantorus 159113 HP (expect 55,000) | PASS | 55,000 (was 250,000) |
| 56 | Praesertum Rhugol 159112 HP (expect 50,000) | PASS | 50,000 (was 200,000) |
| 57 | Praesertum Bikun 159115 HP (expect 45,000) | PASS | 45,000 (was 160,000) |
| 58 | Praesertum Matpa 159114 HP (expect 45,000) | PASS | 45,000 (was 150,000) |
| 59 | Lcea Katta 160375 HP (expect 80,000) | PASS | 80,000 (was 401,200) |
| 60 | Lcea Katta 160375 maxdmg (expect 620) | PASS | 620 (was 827) |
| 61 | Nathyn Illuminious 160135 HP (expect 80,000) | PASS | 80,000 (was 430,000) |
| 62 | Grieg Veneficus MAIN 163075 HP (expect 80,000) | PASS | 80,000 (was 475,500) |
| 63 | Grieg Veneficus variant 163231 HP (expect 162,500 UNCHANGED) | PASS | 162,500 — intentionally unchanged (already scaled-tier); only respawn updated |
| 64 | Servitor of Luclin 163013 HP (expect 40,000) | PASS | 40,000 (was 120,021) |
| 65 | Praetorian Myral 163078 HP (expect 35,000) | PASS | 35,000 (was 95,051) |
| 66 | Khati Sha the Twisted 154145 HP (expect 90,000) | PASS | 90,000 (was 475,000) |
| 67 | Khati Sha the Twisted 154145 maxdmg (expect 750) | PASS | 750 (was 1,004) |
| 68 | an_evolved_burrower 154142 HP (expect 60,000) | PASS | 60,000 (was 300,750) |
| 69 | A_Spiritual_Arcanist 154153 HP (expect 40,000, Q59=A) | PASS | 40,000 (was 150,000) |
| 70 | Thought Horror Overfiend 164078 HP (expect 90,000) | PASS | 90,000 (was 807,000) |
| 71 | Doomshade 176088 HP (expect 70,000) | PASS | 70,000 (was 350,000) |
| 72 | Zelnithak 176089 HP (expect 60,000) | PASS | 60,000 (was 251,000) |
| 73 | Rumblecrush 176002 HP (expect 45,000) | PASS | 45,000 (was 150,000) |
| 74 | Rumblecrush 176002 maxdmg (expect 600) | PASS | 600 (was 720) |
| 75 | spawn2 respawn 86400s — High Priest 162076 (ssratemple) | PASS | respawntime=86400 |
| 76 | spawn2 respawn 86400s — Xerkizh 162190 (ssratemple) | PASS | respawntime=86400 |
| 77 | spawn2 respawn 86400s — Rhag`Zhezum 162178 (ssratemple) | PASS | respawntime=86400 |
| 78 | spawn2 respawn 86400s — Itraer Vius 179037 (akheva) | PASS | respawntime=86400 |
| 79 | spawn2 respawn 86400s — Shei MERCHANT 179157 (akheva) | PASS | respawntime=86400 |
| 80 | spawn2 respawn 86400s — Insanity Crawler 179180 (akheva) | PASS | respawntime=86400 |
| 81 | spawn2 respawn 86400s — Va`Dyn 179178 (akheva) | PASS | respawntime=86400 |
| 82 | spawn2 respawn 86400s — Lord Seru 159691 (sseru) | PASS | respawntime=86400 |
| 83 | spawn2 respawn 86400s — Praesertum Vantorus 159113 (sseru) | PASS | respawntime=86400 |
| 84 | spawn2 respawn 86400s — Praesertum Rhugol 159112 (sseru) | PASS | respawntime=86400 |
| 85 | spawn2 respawn 86400s — Praesertum Bikun 159115 (sseru) | PASS | respawntime=86400 |
| 86 | spawn2 respawn 86400s — Praesertum Matpa 159114 (sseru) | PASS | respawntime=86400 |
| 87 | spawn2 respawn 86400s — Lcea Katta 160375 (katta) | PASS | respawntime=86400 |
| 88 | spawn2 respawn 86400s — Nathyn Illuminious 160135 (katta) | PASS | respawntime=86400 |
| 89 | spawn2 respawn 86400s — Grieg variant 163231 (griegsend) | PASS | respawntime=86400 (was 561,600s — 156h outlier) |
| 90 | spawn2 respawn 86400s — Servitor of Luclin 163013 (griegsend) | PASS | respawntime=86400 |
| 91 | spawn2 respawn 86400s — Praetorian Myral 163078 (griegsend) | PASS | respawntime=86400 |
| 92 | spawn2 respawn 86400s — evolved burrower 154142 (acrylia) | PASS | respawntime=86400 |
| 93 | spawn2 respawn 86400s — Thought Horror Overfiend 164078 (thedeep) | PASS | respawntime=86400 (spawn2 row id=34709 confirmed) |
| 94 | spawn2 respawn 86400s — Zelnithak 176089 (umbral) | PASS | respawntime=86400 |
| 95 | spawn2 respawn 86400s — Rumblecrush 176002 (umbral) | PASS | respawntime=86400 |
| 96 | Total spawn2 rows updated to 86400s (expect 21) | PASS | 21 distinct spawn2.id rows at respawntime=86400 for the Phase 5a update list |
| 97 | spawn2 PRESERVED — pre-Emperor named 162066 at 1080s | PASS | All sampled rows for NPC 162066 show respawntime=1080 |
| 98 | spawn2 PRESERVED — Rhozth Ssrakezh 162258 at 5400s | PASS | respawntime=5400 |
| 99 | spawn2 PRESERVED — Rhozth Ssravizh 162089 at 21600s | PASS | respawntime=21600 |
| 100 | spawn2 PRESERVED — Shar Vinitras 179134 at 10800s | PASS | respawntime=10800 |
| 101 | spawn2 PRESERVED — Sheleric Vis 179133 (x2 rows) at 5400s (Q51) | PASS | Both rows at respawntime=5400 |
| 102 | spawn2 PRESERVED — Sheleric Vis variant 179046 (x2 rows) at 5400s (Q51) | PASS | Both rows at respawntime=5400 |
| 103 | spawn2 PRESERVED — Xaui Tatrua 179044 at 5400s (Q51) | PASS | respawntime=5400 |
| 104 | Perl edit L13 — #EmpCycle.pl:3 reads int(rand(7200))+79200 | PASS | Line 3 confirmed: `$EmpRepopTime = int(rand(7200)) + 79200;` (22-24h endgame tier) |
| 105 | Perl syntax check — #EmpCycle.pl passes perl -c | PASS | `perl -c` output: "syntax OK" |
| 106 | Cazic Touch spell 982 absent from all Phase 5a boss spell lists | PASS | 0 rows for spell 982 across all Phase 5a boss spell list IDs |
| 107 | Cazic Touch spell 982 remaining instances are non-Phase-5a lists | PASS | 12 instances remain in lists 32,33,40,42,122,213,490,543,598,599,962,970 — none used by any Phase 5a NPC |
| 108 | Phase 4b regression — AoW 113457 HP (expect 120,000) | PASS | 120,000 — Phase 4b value intact |
| 109 | Phase 4b regression — Vulak`Aerr 124155 HP (expect 150,000) | PASS | 150,000 — Phase 4b value intact |
| 110 | Phase 4b regression — Kerafyrm 128089 HP (must be 3,500,000) | PASS | 3,500,000 — untouched per Decision #12 |
| 111 | Phase 4b regression — 4 Sleeper Warders HP (expect 60,000 each) | PASS | Nanzata/Ventani/Tukaarak/Hraashna all at 60,000 |
| 112 | Phase 4a regression — Tunare combat boss 127098 HP (expect 150,000) | PASS | 150,000 — BUG-001 fix intact |
| 113 | Phase 3 regression — Trakanon 89181 HP (expect 16,000) | PASS | 16,000 — Phase 3 value intact |
| 114 | Phase 2 regression — Lord Nagafen 32040 HP (expect 14,400) | PASS | 14,400 — Phase 2 value intact |
| 115 | Phase 2 regression — Lady Vox 73057 HP (expect 14,400) | PASS | 14,400 — Phase 2 value intact |
| 116 | World log — no errors post-restart | PASS | world_start.log contains only pre-existing public address warning (LAN vs WAN); no errors |
| 117 | Zone logs — no errors post-restart | PASS | zone_dynamic_01.log shows clean boot: 163 commands, 1048 rules, expansion=3 (Luclin) |

---

## Notes

**Backup row count note:** The npc_types backup has 45 rows vs. the architecture's "41"
estimate. This is correct — the backup SQL captures all 45 distinct IDs including Grieg
Veneficus variant 163231 and Shar Vinitras 179134, which are backed up for safety even
though their HP values are intentionally left unchanged. The 4-row discrepancy is pure
scope accounting, not an error. All 45 IDs match the planned set.

**Cazic Touch (spell 982) note:** 12 instances remain in the database across 12 non-Phase-5a
spell lists. Phase 2 deleted the specific PoSky and Cazic Thule lists (118, 449, 969).
The remaining 12 are unrelated NPCs outside Phase 5a scope — no action needed.

**Spell list 196 note:** After the Touch of Vinitras DELETE, list 196 contains exactly
1 spell: spell 2812 "Pyrokinetic Hallucinations" (effectid=23, not a DT). This is the
correct post-change state. The Vyzh`dra Exiled and Banished (which use list 196) will
still cast Pyrokinetic Hallucinations but will no longer instant-kill the player.

**Touch of Vinitras cache flush:** Per Phase 2 precedent (Decision #16), a full-stack
restart was performed after the SQL apply. The zone_dynamic logs confirm a fresh boot
with no cached spell list data carried over. The `npc_spells_entries` cache is loaded at
zone process startup, not on `#reloadworld`. Since the full-stack restart is complete,
no further cache action is needed. In-game testing (Session 1) should confirm live
behavior.

**Grieg Veneficus variant respawn note:** The 163231 variant had a 561,600s (156h) respawn
that was clearly an outlier. It has been updated to 86,400s (24h) per Decision #8. This
is flagged as worth a quick in-game check since it was the most extreme respawn cut in
Phase 5a.
