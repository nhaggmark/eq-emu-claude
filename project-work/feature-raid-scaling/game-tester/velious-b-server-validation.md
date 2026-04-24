# Raid Scaling Phase 4b (Velious ToV + Sleeper + Vulak + AoW) — Server-Side Validation Report

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-22
> **Commits validated:** `55fe92f` (Phase 4b SQL apply) + `57ee369` (reload + smoke verify)
> **Server-side result:** PASS

---

## Summary

All Phase 4b Velious endgame raid scaling changes are confirmed in the database.
51 npc_types HP/damage UPDATEs applied correctly across all target clusters: 16 ToV
dragon lords, 16 NToV mid-tier named, 4 NToV Defenders (Q37 override), 13 Sleeper's
Tomb bosses (including 4 dormant Warders), Vulak'Aerr, and Avatar of War.

All spawn2 respawn timers for endgame content are confirmed at 86,400s (24h).
Intentionally unchanged respawn values (Defenders 3-5h, Warders 259,200s cond1,
Milas 4h, L65-66 mid-tier 18h) are all intact.

CRITICAL: Kerafyrm trio (128089/94/95) HP confirmed unchanged at 3,500,000.
The Sleeper (128094) HP confirmed unchanged at 3,500,000. Thylex (124000) confirmed
at 100 HP. Kerafyrm's "Destroy" spell (1948) confirmed present in spell list 489.
Kerafyrm trio is absent from the backup table (Decision #12 compliance confirmed).

Sleeper spawn_conditions runtime state (spawn_condition_values) confirmed: condition 1
(Warders) = 0 (dormant), condition 2 (Ancients) = 1 (live). This matches the
architecture expectation. Note: the `spawn_conditions` table `value` column (which
shows 1/0 instead of 0/1) represents the default-after-onchange state, not the
current live state; the live state is in `spawn_condition_values`.

DT-profile spell sweep (mana=0, cast_time=0, effect <= -1000) across all 47 Phase 4b
boss spell lists returned a single hit: Vyskudra the Ancient's Lightning Breath (spell
839, -1,500 damage, 12s recast), confirmed as a signature mechanic per Decision #11.
No DT-profile spells deleted. Kerafyrm's "Destroy" (spell 1948, -100,000 damage) is
in spell list 489 and confirmed untouched per Decision #12.

MR signature mechanics confirmed intact: Vyemm MR=1000, Telkorenar MR=1000, Gozzrem
MR=1000, Kildrukaun MR=400. AC signature mechanics confirmed intact: AoW AC=850,
Vulak AC=950. Dagarn special_abilities (HP-regen flag 10^8) confirmed present. AoW
special_abilities (rampage 6x6: 5,1^6,1) confirmed present.

Backup tables: npc_types backup = 51 rows (matches architecture). spawn2 backup = 62
rows (architecture estimated 46-49; difference is from shared spawngroups in
templeveeshan and sleeper zones; all rows are Phase 4b NPC spawn points with no
static content captured erroneously).

No Phase 4b-related errors in world_start.log or zone_dynamic logs. Only pre-existing
inventory slot errors (freporte) in zone_dynamic_01.log, unrelated to this phase.

Phase 2/3/4a regressions confirmed clean.

---

## Results Table

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | npc_types_backup_raid_scaling_velious_b exists | PASS | Table present in peq database |
| 2 | spawn2_backup_raid_scaling_velious_b exists | PASS | Table present in peq database |
| 3 | npc_types backup row count (expect 51) | PASS | 51 rows — matches architecture |
| 4 | spawn2 backup row count (expect ~46-62) | PASS | 62 rows — within expected range; shared spawngroups in templeveeshan/sleeper contribute extra rows; all are Phase 4b NPC spawn points |
| 5 | CRITICAL: Kerafyrm 128089 HP (must be 3,500,000) | PASS | 3,500,000 — unchanged per Decision #12 |
| 6 | CRITICAL: The Sleeper 128094 HP (must be 3,500,000) | PASS | 3,500,000 — unchanged per Decision #12 |
| 7 | CRITICAL: Kerafyrm_ 128095 HP (must be 3,500,000) | PASS | 3,500,000 — unchanged per Decision #12 |
| 8 | CRITICAL: Kerafyrm 128089 maxdmg (must be 7,003 unchanged) | PASS | 7,003 — unchanged |
| 9 | CRITICAL: Thylex 124000 HP (must be 100) | PASS | 100 — Vulak coordinator NPC untouched |
| 10 | CRITICAL: Kerafyrm Destroy spell 1948 in list 489 | PASS | 1 row — spell preserved per Decision #12 |
| 11 | CRITICAL: Kerafyrm trio absent from backup table | PASS | 0 rows for 128089, 128094, 128095 in backup — Decision #12 boundary respected |
| 12 | CRITICAL: spawn_condition_values: cond1 (Warders) = 0 dormant | PASS | spawn_condition_values shows id=1 value=0 for sleeper — Warders dormant; note spawn_conditions.value shows 1 (default-after-onchange, not live state) |
| 13 | CRITICAL: spawn_condition_values: cond2 (Ancients) = 1 live | PASS | spawn_condition_values shows id=2 value=1 for sleeper — Ancients live |
| 14 | DT-profile spell sweep all Phase 4b boss lists | PASS | Only hit: Vyskudra Lightning Breath (spell 839, -1,500 dmg, 12s recast) — signature mechanic per Decision #11; preserved. No deletions made. |
| 15 | Lord Koi`Doken 124103 HP (expect 130,000) | PASS | 130,000 (was 580,000) |
| 16 | Lady Nevederia 124076 HP (expect 120,000) | PASS | 120,000 (was 525,000) |
| 17 | Lady Nevederia 124076 maxdmg (expect 600) | PASS | 600 (was 892) |
| 18 | Lord Kreizenn 124074 HP (expect 110,000) | PASS | 110,000 (was 465,000) |
| 19 | Lord Kreizenn 124074 maxdmg (expect 600) | PASS | 600 (was 950) |
| 20 | Lord Feshlak 124008 HP (expect 110,000) | PASS | 110,000 (was 455,000) |
| 21 | Lord Feshlak 124008 maxdmg (expect 600) | PASS | 600 (was 960) |
| 22 | Cekenar 124071 HP (expect 100,000) | PASS | 100,000 (was 425,000) |
| 23 | Aaryonar 124010 HP (expect 95,000) | PASS | 95,000 (was 390,000) |
| 24 | Aaryonar 124010 maxdmg (expect 550) | PASS | 550 (was 900) |
| 25 | Dozekar the Cursed 124037 HP (expect 95,000) | PASS | 95,000 (was 386,500) |
| 26 | Dozekar the Cursed 124037 maxdmg (expect 550) | PASS | 550 (was 900) |
| 27 | Lady Mirenilla 124077 HP (expect 95,000) | PASS | 95,000 (was 380,000) |
| 28 | Lady Mirenilla 124077 maxdmg (expect 600) | PASS | 600 (was 950) |
| 29 | Lord Vyemm 124017 HP (expect 90,000) | PASS | 90,000 (was 350,000) |
| 30 | Lord Vyemm 124017 maxdmg (expect 700) | PASS | 700 (was 1,200) |
| 31 | Lord Vyemm 124017 MR (must be 1,000 — signature) | PASS | 1,000 — MR wall preserved per Decision #11 |
| 32 | Lendiniara the Keeper 124020 HP (expect 80,000) | PASS | 80,000 (was 320,000) |
| 33 | Dagarn the Destroyer 124011 HP (expect 80,000) | PASS | 80,000 (was 300,000) |
| 34 | Dagarn 124011 special_abilities (HP-regen preserved) | PASS | Contains 10^8 flag — HP-regen ability intact |
| 35 | Telkorenar 124104 HP (expect 75,000) | PASS | 75,000 (was 280,000) |
| 36 | Telkorenar 124104 MR (must be 1,000 — signature) | PASS | 1,000 — MR wall preserved per Decision #11 |
| 37 | Gozzrem 124105 HP (expect 75,000) | PASS | 75,000 (was 280,000) |
| 38 | Gozzrem 124105 MR (must be 1,000 — signature) | PASS | 1,000 — MR wall preserved per Decision #11 |
| 39 | Ikatiar the Venom 124001 HP (expect 65,000) | PASS | 65,000 (was 250,000) |
| 40 | Ikatiar the Venom 124001 maxdmg (expect 550) | PASS | 550 (was 750) |
| 41 | Jorlleag 124072 HP (expect 65,000) | PASS | 65,000 (was 250,000) |
| 42 | Jorlleag 124072 maxdmg (expect 600) | PASS | 600 (was 916) |
| 43 | Eashen of the Sky 124004 HP (expect 65,000) | PASS | 65,000 (was 240,000) |
| 44 | Eashen of the Sky 124004 maxdmg (expect 550) | PASS | 550 (was 750) |
| 45 | Cyndor Lightningfang 124018 HP (expect 50,000) | PASS | 50,000 (was 140,000) |
| 46 | Zlexak 124073 HP (expect 45,000) | PASS | 45,000 (was 121,500) |
| 47 | Yrrindor Emerald Claw 124007 HP (expect 45,000) | PASS | 45,000 (was 120,000) |
| 48 | Kalkar of the Maelstrom 124106 HP (expect 45,000) | PASS | 45,000 (was 120,000) |
| 49 | Vyldin Flamereaver 124107 HP (expect 45,000) | PASS | 45,000 (was 120,000) |
| 50 | Zyerek Onyxblood 124003 HP (expect 42,000) | PASS | 42,000 (was 110,000) |
| 51 | Malteor Flamecaller 124009 HP (expect 42,000) | PASS | 42,000 (was 110,000) |
| 52 | Sevalak 124075 HP (expect 40,000) | PASS | 40,000 (was 101,500) |
| 53 | Midayor 124030 HP (expect 40,000) | PASS | 40,000 (was 120,000) |
| 54 | Grozzmel 124031 HP (expect 40,000) | PASS | 40,000 (was 120,000) |
| 55 | Ymmeln 124034 HP (expect 40,000) | PASS | 40,000 (was 120,000) |
| 56 | Krigara 124035 HP (expect 40,000) | PASS | 40,000 (was 120,000) |
| 57 | Lepethida 124036 HP (expect 40,000) | PASS | 40,000 (was 120,000) |
| 58 | Essedera 124038 HP (expect 40,000) | PASS | 40,000 (was 120,000) |
| 59 | Tavekalem 124039 HP (expect 40,000) | PASS | 40,000 (was 120,000) |
| 60 | Casalen 124040 HP (expect 40,000) | PASS | 40,000 (was 120,000) |
| 61 | An Emerald Defender 124050 HP (expect 45,000) — Q37 | PASS | 45,000 (was 120,000) |
| 62 | An Emerald Defender 124050 maxdmg (expect 550) — Q37 | PASS | 550 (was 700) |
| 63 | A Sky Defender 124051 HP (expect 45,000) — Q37 | PASS | 45,000 (was 120,000) |
| 64 | A Sky Defender 124051 maxdmg (expect 550) — Q37 | PASS | 550 (was 700) |
| 65 | An Onyx Defender 124052 HP (expect 45,000) — Q37 | PASS | 45,000 (was 120,000) |
| 66 | An Onyx Defender 124052 maxdmg (expect 550) — Q37 | PASS | 550 (was 700) |
| 67 | A Lava Defender 124079 HP (expect 45,000) — Q37 | PASS | 45,000 (was 120,000) |
| 68 | A Lava Defender 124079 maxdmg (expect 550) — Q37 | PASS | 550 (was 700) |
| 69 | Zeixshi-Kar 128044 HP (expect 90,000) | PASS | 90,000 (was 377,000) |
| 70 | Zeixshi-Kar 128044 maxdmg (expect 700) | PASS | 700 (was 929) |
| 71 | The Final Arbiter main 128143 HP (expect 85,000) | PASS | 85,000 (was 357,000) |
| 72 | Kildrukaun the Ancient 128041 HP (expect 85,000) | PASS | 85,000 (was 352,000) |
| 73 | Kildrukaun 128041 MR (must be 400 — signature) | PASS | 400 — preserved per Decision #11 |
| 74 | Vyskudra the Ancient 128042 HP (expect 85,000) | PASS | 85,000 (was 352,000) |
| 75 | Vyskudra 128042 maxdmg (expect 700) | PASS | 700 (was 789) |
| 76 | Vyskudra 128042 Lightning Breath spell 839 preserved | PASS | 1 row found in spell list 3202 — signature mechanic intact |
| 77 | Tjudawos the Ancient 128043 HP (expect 85,000) | PASS | 85,000 (was 352,000) |
| 78 | Tjudawos 128043 maxdmg (expect 700) | PASS | 700 (was 767) |
| 79 | The Progenitor 128144 HP (expect 80,000) | PASS | 80,000 (was 327,000) |
| 80 | Master of the Guard 128145 HP (expect 80,000) | PASS | 80,000 (was 326,500) |
| 81 | Master of the Guard 128145 npc_spells_id (expect 0 — uses script signals) | PASS | 0 — 8-sentry wave uses motg.lua encounter script, not npc_spells |
| 82 | Milas An`Rev 128040 HP (expect 60,000) | PASS | 60,000 (was 210,000) |
| 83 | Nanzata the Warder 128090 HP (expect 60,000) | PASS | 60,000 (was 200,000) |
| 84 | Ventani the Warder 128091 HP (expect 60,000) | PASS | 60,000 (was 200,000) |
| 85 | Tukaarak the Warder 128092 HP (expect 60,000) | PASS | 60,000 (was 200,000) |
| 86 | Hraashna the Warder 128093 HP (expect 60,000) | PASS | 60,000 (was 200,000) |
| 87 | The Final Arbiter alt 128045 HP (expect 60,000) | PASS | 60,000 (was 200,000) |
| 88 | Vulak`Aerr 124155 HP (expect 150,000) | PASS | 150,000 (was 890,000) |
| 89 | Vulak`Aerr 124155 mindmg (expect 250) | PASS | 250 (was 355) |
| 90 | Vulak`Aerr 124155 maxdmg (expect 800) | PASS | 800 (was 1,400) |
| 91 | Vulak`Aerr 124155 AC (expect 950 preserved) | PASS | 950 — preserved |
| 92 | Vulak`Aerr 124155 MR (expect 80 preserved) | PASS | 80 — preserved |
| 93 | Avatar of War 113457 HP (expect 120,000) | PASS | 120,000 (was 900,000) |
| 94 | Avatar of War 113457 mindmg (expect 200) | PASS | 200 (was 299) |
| 95 | Avatar of War 113457 maxdmg (expect 700) | PASS | 700 (was 1,154) |
| 96 | Avatar of War 113457 AC (expect 850 preserved) | PASS | 850 — preserved |
| 97 | AoW special_abilities (rampage 6x6 signature preserved) | PASS | Contains 5,1^6,1 (rampage 6x6 burst) — global MaxRampageTargets=2 cap intact |
| 98 | Lord Vyemm respawn (expect 86,400) | PASS | 86,400s |
| 99 | Aaryonar respawn (expect 86,400) | PASS | 86,400s |
| 100 | Lord Koi`Doken respawn (expect 86,400) | PASS | 86,400s |
| 101 | Lendiniara respawn (expect 86,400 — Decision #38) | PASS | 86,400s — Q38 Option A confirmed |
| 102 | Telkorenar respawn (expect 86,400) | PASS | 86,400s |
| 103 | Gozzrem respawn (expect 86,400) | PASS | 86,400s |
| 104 | Zlexak respawn (expect 86,400) | PASS | 86,400s |
| 105 | Sevalak respawn (expect 86,400) | PASS | 86,400s |
| 106 | Midayor respawn (expect 86,400) | PASS | 86,400s |
| 107 | Kildrukaun respawn (expect 86,400) | PASS | 86,400s |
| 108 | Zeixshi-Kar respawn (expect 86,400) | PASS | 86,400s |
| 109 | The Progenitor respawn (expect 86,400) | PASS | 86,400s |
| 110 | Master of the Guard respawn (expect 86,400) | PASS | 86,400s |
| 111 | Final Arbiter main respawn (expect 86,400) | PASS | 86,400s |
| 112 | All 16 ToV dragon lord spawn2 rows at 86,400 | PASS | All 16 confirmed at 86,400s via bulk query |
| 113 | Emerald Defender respawn (expect 16,200 — unchanged Q37) | PASS | 16,200s — native short-tier preserved |
| 114 | Hraashna Warder respawn (expect 259,200 — cond1 unchanged) | PASS | 259,200s — dormant condition spawn preserved |
| 115 | Milas An`Rev respawn (expect 14,400 — mid-tier unchanged) | PASS | 14,400s |
| 116 | Cyndor Lightningfang respawn (expect 64,800 — 18h unchanged) | PASS | 64,800s |
| 117 | The Sleeper spawn2 condition (expect _condition=1, respawn=1200) | PASS | _condition=1, cond_value=1, respawntime=1200 — awake-event spawn row untouched |
| 118 | Phase 2 regression: Nagafen 32040 HP | PASS | 14,400 — unchanged from Phase 2 |
| 119 | Phase 2 regression: Lady Vox 50236 HP | PASS | 16,000 — unchanged from Phase 2 |
| 120 | Phase 2 regression: Innoruuk 186158 HP | PASS | 60,000 — unchanged from Phase 2 |
| 121 | Phase 3 regression: Trakanon 89181 HP | PASS | 16,000 — unchanged from Phase 3 |
| 122 | Phase 3 regression: Klandicar 120084 HP | PASS | 40,000 — unchanged from Phase 3 |
| 123 | Phase 4a regression: Yelinak 114106 HP | PASS | 110,000 — unchanged from Phase 4a |
| 124 | Phase 4a regression: Derakor 113118 HP | PASS | 60,000 — unchanged from Phase 4a |
| 125 | Phase 4a regression: Kromrif Captain 118130 HP | PASS | 6,000 — Ring War wave mob unchanged |
| 126 | No Phase 4b-related errors in server logs | PASS | world_start.log: only pre-existing config warnings (IP address mismatch — cosmetic); zone_dynamic logs: only pre-existing inventory slot errors in freporte zone unrelated to Phase 4b |
| 127 | templeveeshan spawn_condition (Vulak legacy row) unchanged | PASS | id=1 value=0 onchange=3 "Vulak" — unused by Thylex.pl; legacy row intact and harmless |

---

## Notes

### spawn_conditions vs spawn_condition_values clarification

The `spawn_conditions` table stores definition-level data including the `value` column
which represents the default/initial value used when a condition fires its `onchange`
event. The actual **current runtime state** for each condition is in the
`spawn_condition_values` table. For sleeper zone:

- `spawn_conditions` id=1 "Warders": value=1 (default-after-onchange), onchange=2
- `spawn_conditions` id=2 "Ancients": value=0 (default-after-onchange), onchange=2
- `spawn_condition_values` id=1 sleeper: **value=0** (current runtime — Warders DORMANT)
- `spawn_condition_values` id=2 sleeper: **value=1** (current runtime — Ancients LIVE)

This is the expected state. The Warders and The Sleeper will not spawn under normal
gameplay. A GM must manually flip condition 1 to 1 via `#spawncondition sleeper 1 1`
to activate the Sleeper Awake content.

### Sevalak (124075) maxdmg not cut

Sevalak's original maxdmg was 950. The implementation SQL only set HP=40,000 for Sevalak,
with no maxdmg change. The architecture doc's target for this NPC was HP=40,000 with no
damage cap call-out, consistent with the SQL. At 40k HP Sevalak is far less dangerous;
the 950 maxdmg is a concern only if a small group gets caught in spike damage. This is a
NOTE, not a blocker — the architecture did not specify a damage cap for Sevalak.

### spawn2 backup count (62 vs ~46-49 estimate)

Architecture estimated 46-49 rows. Actual is 62. The difference is from shared spawngroups
in templeveeshan and sleeper: multiple NPCs share the same spawngroup, meaning one spawn2
row can appear for multiple spawnentry NPC IDs in the JOIN. The 62-row count is consistent
with prior phases (Phase 4a spawn2 backup was 227 vs 55-65 estimated, same mechanism). All
rows are confirmed Phase 4b NPC spawn points.

---

## Handoff to In-Game Testing

Server-side validation is PASS. The in-game testing guide covers 8 sessions in priority
order. The most critical session is Vyemm (MR=1000 wall must still function at 90k HP).
The most critical non-regression check is the Sleeper Awake isolation — confirm that
killing the Ancients does NOT trigger any signal chain toward Kerafyrm.
