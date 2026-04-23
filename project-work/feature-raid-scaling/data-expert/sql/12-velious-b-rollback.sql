-- Phase 4b Velious-B Raid Scaling — Emergency Rollback
-- Date: 2026-04-22
-- Purpose: Restore npc_types and spawn2 to pre-Phase-4b-Velious-b state.
-- PREREQUISITE: Backup tables must exist (created by 10-velious-b-backup.sql).
-- Run this ONLY to undo Phase 4b Velious-B changes.
-- This does NOT affect Phase 2 Classic, Phase 3 Kunark, or Phase 4a Velious non-ToV changes.

START TRANSACTION;

-- ============================================================
-- Rollback 1: npc_types HP/damage
-- ============================================================
UPDATE npc_types nt
JOIN npc_types_backup_raid_scaling_velious_b bk ON bk.id = nt.id
SET nt.hp     = bk.hp,
    nt.mindmg = bk.mindmg,
    nt.maxdmg = bk.maxdmg;

-- ============================================================
-- Rollback 2: spawn2 respawn timers
-- ============================================================
UPDATE spawn2 s2
JOIN spawn2_backup_raid_scaling_velious_b bk ON bk.id = s2.id
SET s2.respawntime = bk.respawntime,
    s2.variance    = bk.variance;

COMMIT;

-- ============================================================
-- Rollback verification
-- ============================================================
SELECT 'Lord Vyemm HP (expect 350000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 124017;
SELECT 'Lord Vyemm maxdmg (expect 1200 pre-change)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124017;
SELECT 'Aaryonar HP (expect 390000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 124010;
SELECT 'Lord Koi`Doken HP (expect 580000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 124103;
SELECT 'Kildrukaun HP (expect 352000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 128041;
SELECT 'Hraashna HP (expect 200000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 128093;
SELECT 'Emerald Defender HP (expect 120000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 124050;
SELECT 'Emerald Defender maxdmg (expect 700 pre-change)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124050;
SELECT 'Vulak HP (expect 890000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 124155;
SELECT 'Vulak mindmg (expect 355 pre-change)' AS check_name, mindmg AS actual FROM npc_types WHERE id = 124155;
SELECT 'Vulak maxdmg (expect 1400 pre-change)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124155;
SELECT 'Avatar of War HP (expect 900000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 113457;
SELECT 'Avatar of War mindmg (expect 299 pre-change)' AS check_name, mindmg AS actual FROM npc_types WHERE id = 113457;
SELECT 'Avatar of War maxdmg (expect 1154 pre-change)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 113457;
SELECT 'Midayor HP (expect 120000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 124030;
SELECT 'Zlexak HP (expect 121500 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 124073;

SELECT 'Lord Vyemm respawn pre-change (expect 259200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 124017 LIMIT 1;

SELECT 'Kildrukaun respawn pre-change (expect 259200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 128041 LIMIT 1;

SELECT 'Midayor respawn pre-change (expect 194400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 124030 LIMIT 1;

SELECT 'Zlexak respawn pre-change (expect 259200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 124073 LIMIT 1;
