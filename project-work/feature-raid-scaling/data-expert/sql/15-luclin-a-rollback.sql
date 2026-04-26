-- Phase 5a Luclin non-VT Raid Scaling -- Emergency Rollback
-- Date: 2026-04-22
-- Purpose: Restore npc_types, spawn2, and npc_spells_entries to pre-Phase-5a state.
-- PREREQUISITE: Backup tables must exist (created by 13-luclin-a-backup.sql).
-- Run this ONLY to undo Phase 5a Luclin non-VT changes.
-- This does NOT affect Phase 2 Classic, Phase 3 Kunark, Phase 4a, or Phase 4b changes.

START TRANSACTION;

-- ============================================================
-- Rollback 1: npc_types HP/damage
-- ============================================================
UPDATE npc_types nt
JOIN npc_types_backup_raid_scaling_luclin_a bk ON bk.id = nt.id
SET nt.hp     = bk.hp,
    nt.mindmg = bk.mindmg,
    nt.maxdmg = bk.maxdmg;

-- ============================================================
-- Rollback 2: spawn2 respawn timers
-- ============================================================
UPDATE spawn2 s2
JOIN spawn2_backup_raid_scaling_luclin_a bk ON bk.id = s2.id
SET s2.respawntime = bk.respawntime,
    s2.variance    = bk.variance;

-- ============================================================
-- Rollback 3: npc_spells_entries -- re-insert Touch of Vinitras
-- ============================================================
-- Re-insert the deleted row (list 196, spell 2859) from backup.
-- Only runs if the row was actually deleted and backup captured it.
INSERT IGNORE INTO npc_spells_entries
SELECT * FROM npc_spells_entries_backup_raid_scaling_luclin_a;

COMMIT;

-- ============================================================
-- Rollback verification
-- ============================================================
SELECT 'Emperor Ssraeshza HP (expect 1250500)' AS check_name, hp AS actual FROM npc_types WHERE id = 162227;
SELECT 'Emperor Ssraeshza maxdmg (expect 904)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 162227;
SELECT 'High Priest HP (expect 941000)' AS check_name, hp AS actual FROM npc_types WHERE id = 162076;
SELECT 'Lord Inquisitor Seru HP (expect 1201500)' AS check_name, hp AS actual FROM npc_types WHERE id = 159691;
SELECT 'Lord Inquisitor Seru maxdmg (expect 915)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 159691;
SELECT 'Lord Inquisitor Seru MR (expect 800)' AS check_name, MR AS actual FROM npc_types WHERE id = 159691;
SELECT 'Vyzh`dra Cursed HP (expect 900000)' AS check_name, hp AS actual FROM npc_types WHERE id = 162206;
SELECT 'Vyzh`dra Exiled HP (expect 450000)' AS check_name, hp AS actual FROM npc_types WHERE id = 162232;
SELECT 'Vyzh`dra Banished HP (expect 403000)' AS check_name, hp AS actual FROM npc_types WHERE id = 162214;
SELECT 'Shei Vinitras REAL HP (expect 690000)' AS check_name, hp AS actual FROM npc_types WHERE id = 179032;
SELECT 'Khati Sha HP (expect 475000)' AS check_name, hp AS actual FROM npc_types WHERE id = 154145;
SELECT 'Khati Sha maxdmg (expect 1004)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 154145;
SELECT 'Thought Horror Overfiend HP (expect 807000)' AS check_name, hp AS actual FROM npc_types WHERE id = 164078;
SELECT 'Doomshade HP (expect 350000)' AS check_name, hp AS actual FROM npc_types WHERE id = 176088;
SELECT 'Sheleric Vis 179133 HP (expect 116000)' AS check_name, hp AS actual FROM npc_types WHERE id = 179133;
SELECT 'Sheleric Vis 179133 maxdmg (expect 746)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 179133;
SELECT 'A_Spiritual_Arcanist HP (expect 150000)' AS check_name, hp AS actual FROM npc_types WHERE id = 154153;

SELECT 'Touch of Vinitras list 196 RESTORED (expect 1 row)' AS check_name,
       COUNT(*) AS actual
FROM npc_spells_entries WHERE npc_spells_id = 196 AND spellid = 2859;

SELECT 'High Priest respawn (expect 259200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 162076 LIMIT 1;

SELECT 'Lord Seru respawn (expect 259200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 159691 LIMIT 1;

SELECT 'Itraer Vius respawn (expect 210924)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 179037 LIMIT 1;

SELECT 'Grieg variant respawn (expect 561600)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 163231 LIMIT 1;

SELECT 'evolved burrower respawn (expect 97200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 154142 LIMIT 1;
