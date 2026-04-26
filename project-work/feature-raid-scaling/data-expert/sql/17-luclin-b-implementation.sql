-- Phase 5b Luclin VT (FINAL PHASE) -- Implementation SQL
-- Date: 2026-04-22
-- PREREQUISITE: 16-luclin-b-backup.sql must have run successfully first.
-- Sections:
--   A. npc_types HP/damage UPDATEs (~125 rows)
--   B. spawn2 respawntime UPDATEs (~12 rows to 86400s / 24h endgame tier)
--   C. npc_spells_entries DELETE -- Destroy spell 1948 from list 229 only (Q67=B)
--   D. Post-change verification queries
--
-- User decisions applied:
--   Decision #8  -- endgame respawn tier = 86,400s (24h)
--   Decision #11 -- signature mechanics preserved (special_abilities, scripts, spell list 540 intact)
--   Decision #12 -- Kerafyrm list 489 spell 1948 UNTOUCHED
--   Decision #16 -- DT removal precedent applied: spell 1948 DELETE from list 229 (Q67=B)
--   Decision #74 -- Va_Dyn_Khar 158081 spawn2 respawntime PRESERVED at 21,600s (6h Palace Key cycle)
--   Q67 = B  -- DELETE spell 1948 from list 229 (Destroy Aten form); PBAE DT = small-group blocker
--   Q68 = A  -- INCLUDE A_burrower_parasite 164089 (840k->90k)
--   Q69 = A  -- Acknowledge 13-shard (10 Lucid Shards + 3 components); no SQL action
--   Q70 = A  -- KEEP NATIVE Aten respawn (~2h qglobal lockout); no Perl edit
--
-- OUT OF SCOPE (DO NOT TOUCH):
--   158095 Aten_Trigger: 50M HP controller, raid_target=0 -- EXCLUDED
--   158006/158096 spawn2: script-spawned, no spawn2 rows -- EXCLUDED
--   158087-094 Akhevan Warder spawn2: script-summoned adds, no spawn2 -- EXCLUDED
--   158081 Va_Dyn_Khar spawn2 respawntime: already 21,600s -- PRESERVED per Decision #74
--   All Yaemiu spawn2 respawntime: Decision #2 (trash respawn unchanged)
--   Kerafyrm list 489 spell 1948: Phase 4b Decision #12 PRESERVE -- UNTOUCHED
--   Aten 158096 list 540 (Word of Command/Silence/Fling): UNTOUCHED
--   Phase 5a NPCs: 162xxx, 179xxx, 159xxx, 154xxx, 164078, 176xxx -- UNTOUCHED

-- ============================================================
-- SECTION A: npc_types HP/damage UPDATEs (~125 rows)
-- ============================================================

-- ---- Aten Ha Ra dual-form (script-spawned by Aten_Trigger 158095) ----
-- Both forms scaled to 180k HP with damage trim.
-- Decision #11: Aten_Trigger script, qglobal lockout (108-120min), 172800s self-depop on 158096 all PRESERVED.
-- Q67=B: Destroy spell in list 229 deleted separately in Section C.
-- List 540 on 158096 (Word of Command self-heal +3000, Silence, Fling) UNTOUCHED.
UPDATE npc_types SET hp = 180000, mindmg = 200, maxdmg = 600 WHERE id = 158006;  -- Destroy Aten 1,901,500 -> 180k
UPDATE npc_types SET hp = 180000, mindmg = 200, maxdmg = 600 WHERE id = 158096;  -- non-Destroy Aten 1,901,500 -> 180k

-- ---- 9 inner-VT gating bosses ----
-- These 9 NPCs gate the Aten Trigger (if ANY is alive, Destroy form spawns).
-- Each boss script-spawns Akhevan Warder adds on engage (HP-independent; scripts use quest::spawn2 by NPC ID).
-- Damage outliers on 158007/158008/158009/158010/158015 trimmed per audit.
UPDATE npc_types SET hp = 160000, maxdmg =  800 WHERE id = 158007;  -- Kaas_Thox_Xi_Aten_Ha_Ra 1,900,000 -> 160k, 1650 -> 800
UPDATE npc_types SET hp = 150000, maxdmg =  600 WHERE id = 158008;  -- Thall_Va_Kelun 1,825,000 -> 150k, 1000 -> 600
UPDATE npc_types SET hp = 130000, maxdmg =  750 WHERE id = 158009;  -- Va_Xi_Aten_Ha_Ra 1,601,500 -> 130k, 1254 -> 750
UPDATE npc_types SET hp = 140000, maxdmg =  770 WHERE id = 158010;  -- Diabo_Xi_Va_Temariel 1,706,000 -> 140k, 1400 -> 770
UPDATE npc_types SET hp = 120000                 WHERE id = 158011;  -- Thall_Xundraux_Diabo 1,475,000 -> 120k (dmg 654 ok)
UPDATE npc_types SET hp = 125000                 WHERE id = 158012;  -- Diabo_Xi_Xin_Thall 1,501,500 -> 125k (dmg 750 ok)
UPDATE npc_types SET hp = 100000                 WHERE id = 158013;  -- Kaas_Thox_Xi_Ans_Dyek 1,201,500 -> 100k (dmg 650 ok)
UPDATE npc_types SET hp =  85000                 WHERE id = 158014;  -- Diabo_Xi_Va 1,050,000 -> 85k (dmg 654 ok)
UPDATE npc_types SET hp =  90000, maxdmg =  650 WHERE id = 158015;  -- Diabo_Xi_Xin 1,106,500 -> 90k, 1200 -> 650

-- ---- Thall Va Xakra dual (south wing 158016 + north wing 158125) ----
-- Zone-trash-tier bosses. train-pull Lua scripts (158016.lua / 158125.lua) use spawn_id references, HP-independent.
UPDATE npc_types SET hp = 80000, maxdmg = 700 WHERE id = 158016;   -- Thall_Va_Xakra south 900,000 -> 80k, 950 -> 700
UPDATE npc_types SET hp = 80000, maxdmg = 700 WHERE id = 158125;   -- Thall_Va_Xakra north 900,000 -> 80k, 950 -> 700

-- ---- Va_Dyn_Khar (Palace Key dropper) ----
-- Spawn2 respawntime PRESERVED at 21,600s (6h) per Decision #74 -- Palace Key cycle maintained.
UPDATE npc_types SET hp = 60000 WHERE id = 158081;   -- Va_Dyn_Khar 600,000 -> 60k

-- ---- 6 Akhevan Warder NPC IDs (script-summoned adds, no spawn2) ----
-- 45 Warders zone-wide simultaneously when all bosses up (Va_Xi_Aten_Ha_Ra alone summons 14).
-- Warder spell list 236 (Black Winds PBAE root, Lure of Shadows tash, Silence, Fling) PRESERVED.
UPDATE npc_types SET hp = 80000 WHERE id = 158087;   -- Warder 901,000 -> 80k (Kaas_Thox_Xi_Ans_Dyek x2)
UPDATE npc_types SET hp = 80000 WHERE id = 158088;   -- Warder 901,000 -> 80k (Diabo_Xi_Va x5 + Diabo_Xi_Xin x5)
UPDATE npc_types SET hp = 80000 WHERE id = 158089;   -- Warder 901,000 -> 80k (Diabo_Xi_Xin_Thall x7)
UPDATE npc_types SET hp = 80000 WHERE id = 158090;   -- Warder 901,000 -> 80k (Thall_Va_Kelun x2)
UPDATE npc_types SET hp = 80000 WHERE id = 158091;   -- Warder 901,000 -> 80k (Diabo_Xi_Va_Temariel x5 + Thall_Xundraux_Diabo x5)
UPDATE npc_types SET hp = 80000 WHERE id = 158094;   -- Warder 901,000 -> 80k (Va_Xi_Aten_Ha_Ra x14)

-- ---- 104 Yaemiu raid_target=1 trash (level-tiered HP cuts; damage UNCHANGED) ----
-- Decision #2: respawn timers UNCHANGED. Q4=A: Yaemiu are in-scope for HP scaling.

-- Eom-tier (L66) -- top Yaemiu tier -> 25k
UPDATE npc_types SET hp = 25000 WHERE id IN (
  158001, 158039, 158056, 158033, 158034, 158017, 158027, 158044, 158057, 158061,
  158073, 158097, 158100, 158109, 158110, 158115, 158116, 158127, 158126, 158050, 158004
);
-- Eom_Va_Dyn duplicates -> 22k
UPDATE npc_types SET hp = 22000 WHERE id IN (158028, 158092);

-- Pli-tier (L64) -> 22k
UPDATE npc_types SET hp = 22000 WHERE id IN (
  158000, 158005, 158035, 158036, 158037, 158046, 158053, 158054, 158059, 158060,
  158098, 158101, 158105, 158111, 158117, 158118, 158072
);
-- Pli_Va_Dyn / Pli_Senshali / a_corporeal_shadow -> 20k
UPDATE npc_types SET hp = 20000 WHERE id IN (158029, 158031, 158082, 158051);

-- Zun-tier (L61) -> 18k
UPDATE npc_types SET hp = 18000 WHERE id IN (
  158003, 158018, 158023, 158030, 158038, 158040, 158041, 158045, 158049, 158058,
  158071, 158099, 158102, 158108, 158124,
  158032, 158083,
  158052, 158070
);

-- Zov-tier (L58) -> 14k
UPDATE npc_types SET hp = 14000 WHERE id IN (
  158002, 158025, 158026, 158042, 158055, 158062, 158063, 158065, 158066, 158076,
  158077, 158103, 158106, 158121, 158122,
  158022
);
-- Zov_Va_Dyn duplicates + a_pool_of_shadows -> 15k
UPDATE npc_types SET hp = 15000 WHERE id IN (158080, 158084, 158093);

-- Qua-tier (L55) -> 11k
UPDATE npc_types SET hp = 11000 WHERE id IN (
  158019, 158020, 158021, 158024, 158047, 158048, 158064, 158067, 158068, 158075,
  158078, 158079, 158104, 158107, 158119, 158120
);
-- Qua_Va_Dyn duplicates + a_living_shadow -> 12k
UPDATE npc_types SET hp = 12000 WHERE id IN (158043, 158085, 158074);

-- Va_Xakra mid-tier (L60) -> 14k
UPDATE npc_types SET hp = 14000 WHERE id IN (158069, 158086);

-- ---- Q68=A: A_burrower_parasite (thedeep) -- Phase 5a audit-leak ----
-- Script-spawned (no spawn2). Drops Glowing Orb of Luclinite (item 22196) at 100%.
-- Matches 164078 Thought Horror Overfiend's Phase 5a target (90k) for thedeep tier consistency.
UPDATE npc_types SET hp = 90000 WHERE id = 164089;   -- A_burrower_parasite 840,000 -> 90k

-- ============================================================
-- SECTION B: spawn2.respawntime UPDATEs (~12 rows)
-- ============================================================
-- Target: 86,400s (24h) per Decision #8 endgame respawn tier.
-- 158007 has 2 spawn2 rows -- both updated by the IN() clause below.
-- Va_Dyn_Khar 158081 EXCLUDED -- already 21,600s per Decision #74.
-- Yaemiu standing/trap rows EXCLUDED -- Decision #2 (trash respawn unchanged).
-- Aten dual / Akhevan Warders EXCLUDED -- no spawn2 rows (script-spawned).

UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 86400
WHERE s2.zone = 'vexthal'
  AND se.npcID IN (
    158007, 158008, 158009, 158010, 158011, 158012, 158013, 158014, 158015,
    158016, 158125
);
-- Expected rows affected: ~12 (9 inner-VT bosses with 158007 counting as 2 + 2 Thall Va Xakra)

-- ============================================================
-- SECTION C: npc_spells_entries DELETE (Q67=B)
-- ============================================================
-- DELETE spell 1948 (Destroy -100,000 HP PBAE DT) from list 229 only.
-- List 229 is used exclusively by 158006 (#Aten_Ha_Ra "Destroy form").
-- PBAE DT = simultaneous wipe of entire 1-3 player group = small-group blocker.
-- Decision #12: list 489 (Kerafyrm Destroy, Phase 4b) UNTOUCHED -- scoped DELETE by npc_spells_id=229 only.
-- Decision #11: list 540 (Aten 158096 non-Destroy form: Word of Command/Silence/Fling) UNTOUCHED.

DELETE FROM npc_spells_entries WHERE npc_spells_id = 229 AND spellid = 1948;
-- Expected rows affected: 1

-- ============================================================
-- SECTION D: Post-change verification queries
-- ============================================================

-- D1: Aten Ha Ra dual-form HP/damage targets
SELECT 'Aten_Ha_Ra 158006 HP (expect 180000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158006;
SELECT 'Aten_Ha_Ra 158006 maxdmg (expect 600)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 158006;
SELECT 'Aten_Ha_Ra_ 158096 HP (expect 180000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158096;
SELECT 'Aten_Ha_Ra_ 158096 maxdmg (expect 600)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 158096;

-- D2: 9 inner-VT boss HP targets
SELECT 'Kaas_Thox_Xi_Aten_Ha_Ra 158007 HP (expect 160000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158007;
SELECT 'Kaas_Thox_Xi_Aten_Ha_Ra 158007 maxdmg (expect 800)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 158007;
SELECT 'Thall_Va_Kelun 158008 HP (expect 150000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158008;
SELECT 'Thall_Va_Kelun 158008 maxdmg (expect 600)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 158008;
SELECT 'Va_Xi_Aten_Ha_Ra 158009 HP (expect 130000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158009;
SELECT 'Va_Xi_Aten_Ha_Ra 158009 maxdmg (expect 750)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 158009;
SELECT 'Diabo_Xi_Va_Temariel 158010 HP (expect 140000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158010;
SELECT 'Diabo_Xi_Va_Temariel 158010 maxdmg (expect 770)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 158010;
SELECT 'Thall_Xundraux_Diabo 158011 HP (expect 120000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158011;
SELECT 'Diabo_Xi_Xin_Thall 158012 HP (expect 125000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158012;
SELECT 'Kaas_Thox_Xi_Ans_Dyek 158013 HP (expect 100000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158013;
SELECT 'Diabo_Xi_Va 158014 HP (expect 85000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158014;
SELECT 'Diabo_Xi_Xin 158015 HP (expect 90000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158015;
SELECT 'Diabo_Xi_Xin 158015 maxdmg (expect 650)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 158015;

-- D3: Thall Va Xakra dual HP/damage targets
SELECT 'Thall_Va_Xakra south 158016 HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158016;
SELECT 'Thall_Va_Xakra south 158016 maxdmg (expect 700)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 158016;
SELECT 'Thall_Va_Xakra north 158125 HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158125;
SELECT 'Thall_Va_Xakra north 158125 maxdmg (expect 700)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 158125;

-- D4: Va_Dyn_Khar HP target + spawn2 respawn PRESERVED
SELECT 'Va_Dyn_Khar 158081 HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158081;
SELECT 'Va_Dyn_Khar 158081 spawn2 respawn (expect 21600)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 158081;

-- D5: Akhevan Warder HP targets
SELECT 'Akhevan_Warder 158087 HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158087;
SELECT 'Akhevan_Warder 158088 HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158088;
SELECT 'Akhevan_Warder 158089 HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158089;
SELECT 'Akhevan_Warder 158090 HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158090;
SELECT 'Akhevan_Warder 158091 HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158091;
SELECT 'Akhevan_Warder 158094 HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158094;

-- D6: Yaemiu sample HP targets (spot check across tiers)
SELECT 'Eom-tier 158001 HP (expect 25000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158001;
SELECT 'Pli-tier 158000 HP (expect 22000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158000;
SELECT 'Zun-tier 158003 HP (expect 18000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158003;
SELECT 'Zov-tier 158002 HP (expect 14000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158002;
SELECT 'Qua-tier 158019 HP (expect 11000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158019;

-- D7: A_burrower_parasite (Q68=A)
SELECT 'A_burrower_parasite 164089 HP (expect 90000)' AS check_name, hp AS actual FROM npc_types WHERE id = 164089;

-- D8: spawn2 respawntime UPDATE count + sample spot checks
SELECT 'Inner-VT boss spawn2 rows updated to 86400 (expect 12)' AS check_name, COUNT(*) AS actual
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE s2.zone = 'vexthal'
  AND se.npcID IN (158007, 158008, 158009, 158010, 158011, 158012, 158013, 158014, 158015, 158016, 158125)
  AND s2.respawntime = 86400;

SELECT 'Kaas_Thox_Xi_Aten_Ha_Ra 158007 spawn2 rows at 86400 (expect 2)' AS check_name, COUNT(*) AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 158007 AND s2.respawntime = 86400;

-- D9: Q67=B DELETE confirmations
-- Destroy spell 1948 must NOT be in list 229 after DELETE
SELECT 'Destroy spell 1948 in list 229 (expect 0 after DELETE)' AS check_name,
       COUNT(*) AS actual
FROM npc_spells_entries WHERE npc_spells_id = 229 AND spellid = 1948;

-- Kerafyrm list 489 spell 1948 MUST still be present (Phase 4b Decision #12)
SELECT 'Kerafyrm list 489 spell 1948 PRESERVED (expect 1)' AS check_name,
       COUNT(*) AS actual
FROM npc_spells_entries WHERE npc_spells_id = 489 AND spellid = 1948;

-- Aten 158096 list 540 must have Word of Command/Silence/Fling intact
SELECT 'List 540 spell count (expect 3: Word of Command/Silence/Fling)' AS check_name,
       COUNT(*) AS actual
FROM npc_spells_entries WHERE npc_spells_id = 540;

-- D10: Phase 5a NPCs UNTOUCHED (cross-phase safety)
SELECT 'Phase 5a Emperor 162227 HP (expect 120000)' AS check_name, hp AS actual FROM npc_types WHERE id = 162227;
SELECT 'Phase 5a Lord Seru 159691 HP (expect 120000)' AS check_name, hp AS actual FROM npc_types WHERE id = 159691;
SELECT 'Phase 5a Thought Horror 164078 HP (expect 90000)' AS check_name, hp AS actual FROM npc_types WHERE id = 164078;
SELECT 'Phase 5a Shei Vinitras 179032 HP (expect 70000)' AS check_name, hp AS actual FROM npc_types WHERE id = 179032;
-- Touch of Vinitras list 196 must still have spell 2859 deleted (Phase 5a Decision #16)
SELECT 'Touch of Vinitras list 196 spell 2859 (expect 0 per Phase 5a)' AS check_name,
       COUNT(*) AS actual
FROM npc_spells_entries WHERE npc_spells_id = 196 AND spellid = 2859;
-- Phase 5a Shei list 179 spell 2859 PRESERVED
SELECT 'Shei list 179 spell 2859 PRESERVED (expect 1 per Phase 5a Decision #60)' AS check_name,
       COUNT(*) AS actual
FROM npc_spells_entries WHERE npc_spells_id = 179 AND spellid = 2859;
