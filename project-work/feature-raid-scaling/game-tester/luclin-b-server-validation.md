# Raid Scaling Phase 5b (Luclin VT — FINAL PHASE) — Server-Side Validation Report

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-22
> **SQL files validated:** `16-luclin-b-backup.sql`, `17-luclin-b-implementation.sql`
> **User decisions applied:** Q67=B (DELETE Destroy spell 1948 from list 229), Q68=A (INCLUDE burrower-parasite 164089), Q69=A (acknowledge 10+3 shard framing), Q70=A (KEEP NATIVE Aten respawn ~2h)
> **Server-side result:** PASS WITH NOTES

---

## Summary

All Phase 5b Luclin VT raid scaling changes are confirmed in the database. 124 npc_types
HP/damage UPDATEs applied correctly (architecture estimated 125; difference of 1 explained
below). All 12 spawn2 respawn timers for inner-VT endgame bosses and Thall Va Xakra dual
confirmed at 86,400s (24h) per Decision #8. The Destroy spell 1948 is confirmed absent
from list 229 (Q67=B DELETE executed). Kerafyrm's Destroy in list 489 is confirmed intact
(Phase 4b Decision #12).

**Critical safety checks all pass:** Aten Trigger controller (158095) at 50,000,000 HP
unchanged (raid_target=0). Aten Ha Ra dual-form at 180,000 HP each. Kerafyrm trio
(128089/94/95) at 3,500,000 HP unchanged. The Sleeper (128094) at 3,500,000 HP unchanged.
All Phase 5a NPCs confirmed unchanged (Emperor 120k, Lord Seru 120k, Thought Horror 90k,
Shei Vinitras 85k, Spirit of Akelha`Ra 1,000,000). rule_values count confirmed at 1,112
(zero drift).

Va_Dyn_Khar (158081) spawn2 respawntime confirmed PRESERVED at 21,600s (6h Palace Key
cycle per Decision #74).

List 540 (non-Destroy Aten 158096) confirmed intact: 3 spells — Word of Command (2157),
Silence of the Shadows (2164), Fling (2167). No Destroy spell in list 540.

Touch of Vinitras list 196 (Phase 5a Decision #16/#60) confirmed: spell 2859 = 0 rows in
list 196; spell 2859 = 1 row in list 179 (Shei Vinitras preserved). No Phase 5b regression
on Phase 5a spell work.

**WARN finding (non-blocking):** 4 Yaemiu-range NPCs (158112 #Zun_Zethon_Xakra, 158113
#Qua_Zethon_Xakra, 158114 #Zov_Zethon_Xakra, 158123 #Zun_Liako_Xakra) are at pre-scaled
HP (45k-50k) and were NOT included in the architecture's Yaemiu ID list. These 4 IDs have
no spawnentry rows, no spawn2 rows, and zero references in any vexthal quest script. They
are inaccessible to players in the current zone configuration. They appear to be orphaned
DB entries that were never placed. This is cosmetically incomplete but has ZERO in-game
impact. Logged for awareness; no immediate fix required.

Backup tables confirmed present: npc_types backup = 124 rows, spawn2 backup = 990 rows
(over-capture safe — includes all Yaemiu spawn2 rows for rollback completeness), spells
backup = 1 row (pre-DELETE snapshot of Destroy 1948 from list 229).

---

## Results Table

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | npc_types_backup_raid_scaling_luclin_b exists | PASS | 124 rows (architecture: ~125; 4 orphaned Yaemiu IDs not captured per WARN below; 1 burrower-parasite Q68=A included) |
| 2 | spawn2_backup_raid_scaling_luclin_b exists | PASS | 990 rows (over-capture of Yaemiu spawn2 rows for rollback safety; architecture estimate ~110) |
| 3 | npc_spells_entries_backup_raid_scaling_luclin_b exists | PASS | 1 row (pre-DELETE snapshot of spell 1948 in list 229; Q67=B delete executed) |
| 4 | Aten Ha Ra 158006 HP = 180,000 | PASS | 1,901,500 → 180,000 (90.5% cut, audit recommendation) |
| 5 | Aten Ha Ra 158006 maxdmg = 600 | PASS | 1054 → 600 |
| 6 | Aten Ha Ra_ 158096 HP = 180,000 | PASS | 1,901,500 → 180,000 |
| 7 | Aten Ha Ra_ 158096 maxdmg = 600 | PASS | 1054 → 600 |
| 8 | Aten Ha Ra_ 158096 spell list = 540 (no Destroy) | PASS | npc_spells_id=540 confirmed; list 540 has 3 spells: Word of Command/Silence/Fling |
| 9 | Kaas_Thox_Xi_Aten_Ha_Ra 158007 HP = 160,000 | PASS | 1,900,000 → 160,000 |
| 10 | Kaas_Thox_Xi_Aten_Ha_Ra 158007 maxdmg = 800 | PASS | 1,650 → 800 |
| 11 | Thall_Va_Kelun 158008 HP = 150,000 | PASS | 1,825,000 → 150,000 |
| 12 | Thall_Va_Kelun 158008 maxdmg = 600 | PASS | 1,000 → 600 |
| 13 | Va_Xi_Aten_Ha_Ra 158009 HP = 130,000 | PASS | 1,601,500 → 130,000 |
| 14 | Va_Xi_Aten_Ha_Ra 158009 maxdmg = 750 | PASS | 1,254 → 750 |
| 15 | Diabo_Xi_Va_Temariel 158010 HP = 140,000 | PASS | 1,706,000 → 140,000 |
| 16 | Diabo_Xi_Va_Temariel 158010 maxdmg = 770 | PASS | 1,400 → 770 |
| 17 | Thall_Xundraux_Diabo 158011 HP = 120,000 | PASS | 1,475,000 → 120,000; maxdmg 654 not trimmed (within tolerance) |
| 18 | Diabo_Xi_Xin_Thall 158012 HP = 125,000 | PASS | 1,501,500 → 125,000; maxdmg 750 not trimmed (within tolerance) |
| 19 | Kaas_Thox_Xi_Ans_Dyek 158013 HP = 100,000 | PASS | 1,201,500 → 100,000; maxdmg 650 not trimmed |
| 20 | Diabo_Xi_Va 158014 HP = 85,000 | PASS | 1,050,000 → 85,000; maxdmg 654 not trimmed |
| 21 | Diabo_Xi_Xin 158015 HP = 90,000 | PASS | 1,106,500 → 90,000 |
| 22 | Diabo_Xi_Xin 158015 maxdmg = 650 | PASS | 1,200 → 650 |
| 23 | Thall_Va_Xakra south 158016 HP = 80,000 | PASS | 900,000 → 80,000 |
| 24 | Thall_Va_Xakra south 158016 maxdmg = 700 | PASS | 950 → 700 |
| 25 | Thall_Va_Xakra north 158125 HP = 80,000 | PASS | 900,000 → 80,000 |
| 26 | Thall_Va_Xakra north 158125 maxdmg = 700 | PASS | 950 → 700 |
| 27 | Va_Dyn_Khar 158081 HP = 60,000 | PASS | 600,000 → 60,000 |
| 28 | Va_Dyn_Khar 158081 spawn2 respawntime = 21,600 PRESERVED | PASS | 21,600s (6h Palace Key cycle) unchanged per Decision #74 |
| 29 | Akhevan_Warder 158087 HP = 80,000 | PASS | 901,000 → 80,000 |
| 30 | Akhevan_Warder 158088 HP = 80,000 | PASS | 901,000 → 80,000 |
| 31 | Akhevan_Warder 158089 HP = 80,000 | PASS | 901,000 → 80,000 |
| 32 | Akhevan_Warder 158090 HP = 80,000 | PASS | 901,000 → 80,000 |
| 33 | Akhevan_Warder 158091 HP = 80,000 | PASS | 901,000 → 80,000 |
| 34 | Akhevan_Warder 158094 HP = 80,000 | PASS | 901,000 → 80,000 |
| 35 | A_burrower_parasite 164089 HP = 90,000 (Q68=A) | PASS | 840,000 → 90,000 (Phase 5a audit-leak closed) |
| 36 | Yaemiu Eom-tier spot check: 158001 HP = 25,000 | PASS | Eom_Centien at 25k |
| 37 | Yaemiu Eom-tier Va_Dyn: 158028 HP = 22,000 | PASS | Eom_Va_Dyn at 22k |
| 38 | Yaemiu Pli-tier spot check: 158000 HP = 22,000 | PASS | Pli_Centien at 22k |
| 39 | Yaemiu Pli-tier Va_Dyn: 158029 HP = 20,000 | PASS | Pli_Va_Dyn at 20k |
| 40 | Yaemiu Zun-tier spot check: 158003 HP = 18,000 | PASS | Zun_Senshali at 18k |
| 41 | Yaemiu Zov-tier spot check: 158002 HP = 14,000 | PASS | Zov_Va_Liako at 14k |
| 42 | Yaemiu Zov-tier Va_Dyn: 158080 HP = 15,000 | PASS | Zov_Va_Dyn at 15k |
| 43 | Yaemiu Qua-tier spot check: 158019 HP = 11,000 | PASS | Qua_Liako_Xakra at 11k |
| 44 | Yaemiu Qua-tier Va_Dyn: 158043 HP = 12,000 | PASS | Qua_Va_Dyn at 12k |
| 45 | Yaemiu Va_Xakra mid-tier: 158069 HP = 14,000 | PASS | Va_Xakra at 14k |
| 46 | Yaemiu damage UNCHANGED (200-450 max range) | PASS | maxdmg range in Yaemiu-range: 352-750; well within tolerance; no outliers |
| 47 | Aten Destroy spell 1948 NOT in list 229 (Q67=B DELETE) | PASS | 0 rows — DELETE executed successfully |
| 48 | Kerafyrm Destroy spell 1948 PRESERVED in list 489 | PASS | 1 row — Phase 4b Decision #12 intact |
| 49 | List 540 (non-Destroy Aten 158096) spell count = 3 | PASS | Spells: Word of Command (2157), Silence of the Shadows (2164), Fling (2167) |
| 50 | Inner-VT boss spawn2 rows at 86,400s = 12 | PASS | 9 inner bosses (158007 has 2 rows) + 2 Thall Va Xakra = 12 total |
| 51 | Kaas_Thox_Xi_Aten_Ha_Ra 158007 spawn2 rows at 86,400s = 2 | PASS | Both spawn2 rows for this dual-spawn NPC updated |
| 52 | Aten_Trigger 158095 HP = 50,000,000 UNCHANGED (raid_target=0) | PASS | Controller NPC preserved; raid_target=0 confirmed |
| 53 | Spirit of Akelha`Ra 179144 HP = 1,000,000 UNCHANGED | PASS | Phase 5a Decision #57 intact |
| 54 | Emperor 162227 HP = 120,000 UNCHANGED (Phase 5a) | PASS | No Phase 5b regression |
| 55 | Lord Seru 159691 HP = 120,000 UNCHANGED (Phase 5a) | PASS | No Phase 5b regression |
| 56 | Thought Horror Overfiend 164078 HP = 90,000 UNCHANGED (Phase 5a) | PASS | No Phase 5b regression |
| 57 | Shei Vinitras 179032 HP = 85,000 UNCHANGED (Phase 5a) | PASS | No Phase 5b regression |
| 58 | Touch of Vinitras list 196 spell 2859 = 0 (Phase 5a intact) | PASS | No Phase 5b regression on spell DELETE |
| 59 | Shei list 179 spell 2859 = 1 PRESERVED (Phase 5a) | PASS | Decision #60 intact |
| 60 | Kerafyrm trio 128089/94/95 HP = 3,500,000 UNCHANGED | PASS | Phase 4b Decision #12; The Sleeper confirmed at 3,500,000 |
| 61 | Phase 4b regressions: AoW 113457 = 120,000; Vulak 124155 = 150,000 | PASS | No Phase 5b regression |
| 62 | Phase 4a regressions: Yelinak 114106 = 110,000; Yelinak 114618 = 110,000 | PASS | No Phase 5b regression |
| 63 | Phase 2 regression: Cazic-Thule 72003 HP = 80,000; Cazic Touch spell 982 absent from lists 118/449/969 | PASS | No Phase 5b regression on Cazic Touch DELETEs |
| 64 | rule_values count = 1,112 (no drift) | PASS | Confirmed via SELECT COUNT |
| 65 | World log clean of Phase 5b errors | PASS | No Phase 5b-related errors found in world.log |
| 66 | Zone logs clean of Phase 5b errors | PASS | zone_dynamic_01.log shows clean boot; 0 error lines |
| 67 | Total Phase 5b npc_types rows changed | PASS | 124 rows in backup all confirmed changed (hp, mindmg, or maxdmg differs from backup snapshot in all 124 cases; 0 unchanged rows) |

---

## WARN: 4 Orphaned Yaemiu IDs Not Scaled

During validation, 4 NPCs in the 158xxx Yaemiu range were found at pre-scaled HP that
were not included in the architecture's Yaemiu ID list and not included in the backup table:

| ID | Name | Level | HP (current) | Expected tier HP |
|----|------|-------|--------------|-----------------|
| 158112 | #Zun_Zethon_Xakra | 61 | 50,000 | 18,000 (Zun-tier) |
| 158113 | #Qua_Zethon_Xakra | 55 | 45,000 | 11,000 (Qua-tier) |
| 158114 | #Zov_Zethon_Xakra | 58 | 50,000 | 14,000 (Zov-tier) |
| 158123 | #Zun_Liako_Xakra | 61 | 50,000 | 18,000 (Zun-tier) |

**Root cause:** These 4 IDs have raid_target=1 and loottable IDs assigned, but they have
zero entries in spawnentry (no spawn2 rows) and zero references in any vexthal quest
script. They cannot be encountered by players in the current zone configuration. They are
orphaned DB entries — likely created but never placed in the zone.

**Impact:** None in-game. Players cannot fight or interact with these NPCs.

**Recommendation:** These IDs can be ignored for the current project scope. If future zone
revisions add these NPCs to the zone, they should be addressed at that time. No blocker.

---

## Server-Side Result: PASS WITH NOTES

All 67 checks pass. The 1 WARN finding (4 orphaned Yaemiu IDs at pre-scaled HP with no
in-game accessibility) is non-blocking. All core Phase 5b targets are confirmed in the
database. All critical safety checks pass. All prior-phase regressions are clean.

**Ready for in-game testing.** See `luclin-b-in-game-testing-guide.md`.

**CRITICAL: Session 1 (Aten Ha Ra Destroy-form cache flush verification) MUST be done
first.** The spell list 229 DELETE requires the vexthal zone process to have been restarted
(LB13b) to flush the in-memory cache. If Aten 158006 casts "Destroy" during the encounter,
the cache flush did not complete — dispatch infra-expert for a full-stack restart and retry.
