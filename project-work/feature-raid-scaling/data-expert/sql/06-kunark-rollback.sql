-- Phase 3 Kunark Raid Scaling — Emergency Rollback
-- Date: 2026-04-22
-- Purpose: Restore npc_types and spawn2 to pre-Phase-3-Kunark state.
-- PREREQUISITE: Backup tables must exist (created by 04-kunark-backup-tables.sql).
-- Run this ONLY to undo Phase 3 Kunark changes.
-- This does NOT affect Phase 2 Classic changes.

START TRANSACTION;

-- ============================================================
-- Rollback 1: npc_types HP/damage
-- ============================================================
UPDATE npc_types nt
JOIN npc_types_backup_raid_scaling_kunark bk ON bk.id = nt.id
SET nt.hp     = bk.hp,
    nt.mindmg = bk.mindmg,
    nt.maxdmg = bk.maxdmg;

-- ============================================================
-- Rollback 2: spawn2 respawn timers
-- ============================================================
UPDATE spawn2 s2
JOIN spawn2_backup_raid_scaling_kunark bk ON bk.id = s2.id
SET s2.respawntime = bk.respawntime,
    s2.variance    = bk.variance;

COMMIT;

-- ============================================================
-- Rollback verification
-- ============================================================
SELECT 'Gorenaire HP (expect 32000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 86014;
SELECT 'Trakanon HP (expect 32000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 89154;
SELECT 'Nexona HP (expect 800000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 108047;
SELECT 'Kilidna HP (expect 100000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 90186;
SELECT 'Kilidna maxdmg (expect 4600 pre-change)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 90186;
SELECT '#Renux_Herkanor HP (expect 500000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 448200;

SELECT 'Gorenaire respawn pre-change (expect 194400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 86014 LIMIT 1;

SELECT 'VP Nexona respawn pre-change (expect ~269232)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 108047 LIMIT 1;
