-- Phase 4a Velious non-ToV Raid Scaling — Emergency Rollback
-- Date: 2026-04-22
-- Purpose: Restore npc_types and spawn2 to pre-Phase-4a-Velious-a state.
-- PREREQUISITE: Backup tables must exist (created by 06-velious-a-backup-tables.sql).
-- Run this ONLY to undo Phase 4a Velious non-ToV changes.
-- This does NOT affect Phase 2 Classic or Phase 3 Kunark changes.

START TRANSACTION;

-- ============================================================
-- Rollback 1: npc_types HP/damage
-- ============================================================
UPDATE npc_types nt
JOIN npc_types_backup_raid_scaling_velious_a bk ON bk.id = nt.id
SET nt.hp     = bk.hp,
    nt.mindmg = bk.mindmg,
    nt.maxdmg = bk.maxdmg;

-- ============================================================
-- Rollback 2: spawn2 respawn timers
-- ============================================================
UPDATE spawn2 s2
JOIN spawn2_backup_raid_scaling_velious_a bk ON bk.id = s2.id
SET s2.respawntime = bk.respawntime,
    s2.variance    = bk.variance;

COMMIT;

-- ============================================================
-- Rollback verification
-- ============================================================
SELECT 'King Tormax HP (expect 452000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 113215;
SELECT 'Statue of Rallos Zek HP (expect 400750 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 113071;
SELECT 'Statue of Rallos Zek maxdmg (expect 1100 pre-change)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 113071;
SELECT 'Yelinak main HP (expect 500000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 114106;
SELECT 'Yelinak variant HP (expect 297000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 114618;
SELECT '#_Tunare HP (expect 530000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 127001;
SELECT 'Klandicar HP (expect 97500 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 120084;
SELECT 'Faleniel HP (expect 300000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 125070;
SELECT 'Faleniel maxdmg (expect 1900 pre-change)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 125070;
SELECT 'Dain Frostreaver IV HP (expect 352000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 129003;
SELECT 'Kromrif Captain HP (expect 10000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 118130;
SELECT 'Kromrif High Priest HP (expect 50000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 118210;
SELECT 'Seneschal Aldikar HP (expect 10000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 118166;

SELECT 'King Tormax respawn pre-change (expect 259200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 113215 LIMIT 1;

SELECT 'Yelinak main respawn pre-change (expect 259200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 114106 LIMIT 1;

SELECT 'Dain Frostreaver IV respawn pre-change (expect 432000)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 129003 LIMIT 1;
