-- Phase 5b Luclin VT (FINAL PHASE) -- Emergency Rollback
-- Date: 2026-04-22
-- Purpose: Restore npc_types, spawn2, and npc_spells_entries to pre-Phase-5b state.
-- PREREQUISITE: Backup tables must exist (created by 16-luclin-b-backup.sql).
-- Run this ONLY to undo Phase 5b Luclin VT changes.
-- This does NOT affect Phase 2 Classic, Phase 3 Kunark, Phase 4a, Phase 4b, or Phase 5a changes.

START TRANSACTION;

-- ============================================================
-- Rollback 1: npc_types HP/damage
-- ============================================================
UPDATE npc_types nt
JOIN npc_types_backup_raid_scaling_luclin_b bk ON bk.id = nt.id
SET nt.hp     = bk.hp,
    nt.mindmg = bk.mindmg,
    nt.maxdmg = bk.maxdmg;

-- ============================================================
-- Rollback 2: spawn2 respawn timers
-- ============================================================
UPDATE spawn2 s2
JOIN spawn2_backup_raid_scaling_luclin_b bk ON bk.id = s2.id
SET s2.respawntime = bk.respawntime,
    s2.variance    = bk.variance;

-- ============================================================
-- Rollback 3: npc_spells_entries -- re-insert Destroy spell
-- ============================================================
-- Re-inserts spell 1948 into list 229 from backup (captured before DELETE).
-- INSERT IGNORE handles the case where the row was never deleted.
INSERT IGNORE INTO npc_spells_entries
SELECT * FROM npc_spells_entries_backup_raid_scaling_luclin_b;

COMMIT;

-- ============================================================
-- Rollback verification
-- ============================================================
SELECT 'Aten_Ha_Ra 158006 HP RESTORED (expect 1901500)' AS check_name, hp AS actual FROM npc_types WHERE id = 158006;
SELECT 'Aten_Ha_Ra 158006 maxdmg RESTORED (expect 1054)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 158006;
SELECT 'Aten_Ha_Ra_ 158096 HP RESTORED (expect 1901500)' AS check_name, hp AS actual FROM npc_types WHERE id = 158096;
SELECT 'Kaas_Thox_Xi_Aten_Ha_Ra 158007 HP RESTORED (expect 1900000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158007;
SELECT 'Kaas_Thox_Xi_Aten_Ha_Ra 158007 maxdmg RESTORED (expect 1650)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 158007;
SELECT 'Thall_Va_Kelun 158008 HP RESTORED (expect 1825000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158008;
SELECT 'Va_Xi_Aten_Ha_Ra 158009 HP RESTORED (expect 1601500)' AS check_name, hp AS actual FROM npc_types WHERE id = 158009;
SELECT 'Diabo_Xi_Va_Temariel 158010 HP RESTORED (expect 1706000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158010;
SELECT 'Thall_Xundraux_Diabo 158011 HP RESTORED (expect 1475000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158011;
SELECT 'Diabo_Xi_Xin_Thall 158012 HP RESTORED (expect 1501500)' AS check_name, hp AS actual FROM npc_types WHERE id = 158012;
SELECT 'Kaas_Thox_Xi_Ans_Dyek 158013 HP RESTORED (expect 1201500)' AS check_name, hp AS actual FROM npc_types WHERE id = 158013;
SELECT 'Diabo_Xi_Va 158014 HP RESTORED (expect 1050000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158014;
SELECT 'Diabo_Xi_Xin 158015 HP RESTORED (expect 1106500)' AS check_name, hp AS actual FROM npc_types WHERE id = 158015;
SELECT 'Thall_Va_Xakra south 158016 HP RESTORED (expect 900000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158016;
SELECT 'Thall_Va_Xakra north 158125 HP RESTORED (expect 900000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158125;
SELECT 'Va_Dyn_Khar 158081 HP RESTORED (expect 600000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158081;
SELECT 'Akhevan_Warder 158094 HP RESTORED (expect 901000)' AS check_name, hp AS actual FROM npc_types WHERE id = 158094;
SELECT 'A_burrower_parasite 164089 HP RESTORED (expect 840000)' AS check_name, hp AS actual FROM npc_types WHERE id = 164089;

SELECT 'Kaas_Thox spawn2 rows respawn RESTORED (expect 468720)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 158007 LIMIT 1;

SELECT 'Thall_Va_Xakra spawn2 respawn RESTORED (expect 140616)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 158016 LIMIT 1;

SELECT 'Destroy spell 1948 in list 229 RESTORED (expect 1)' AS check_name,
       COUNT(*) AS actual
FROM npc_spells_entries WHERE npc_spells_id = 229 AND spellid = 1948;

SELECT 'Kerafyrm list 489 spell 1948 STILL PRESENT (expect 1)' AS check_name,
       COUNT(*) AS actual
FROM npc_spells_entries WHERE npc_spells_id = 489 AND spellid = 1948;
