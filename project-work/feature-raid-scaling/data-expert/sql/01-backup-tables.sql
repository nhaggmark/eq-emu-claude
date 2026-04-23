-- Phase 2 Classic Raid Scaling — Backup Tables
-- Date: 2026-04-22
-- Purpose: Pre-change snapshots before any Phase 2 UPDATEs/DELETEs.
-- Run this FIRST before 02-implementation.sql.
-- These tables intentionally over-capture all eras (level 45-70 raid_target rows)
-- for cross-phase rollback safety in future phases.

-- ============================================================
-- Backup 1: npc_types raid_target rows (HP, damage, abilities)
-- ============================================================
CREATE TABLE npc_types_backup_raid_scaling AS
SELECT id, name, level, hp, mindmg, maxdmg, AC, special_abilities, npcspecialattks, npc_spells_id, raid_target
FROM npc_types
WHERE raid_target = 1
  AND level BETWEEN 45 AND 70
  AND name NOT LIKE '#The_Fabled%';

-- Also capture the specific Q13/triggered NPCs that may not be raid_target=1
-- (e.g. essence_tamer 71071 is raid_target=0 but in scope for HP scaling)
INSERT INTO npc_types_backup_raid_scaling
SELECT id, name, level, hp, mindmg, maxdmg, AC, special_abilities, npcspecialattks, npc_spells_id, raid_target
FROM npc_types
WHERE id IN (71071, 91090, 48041, 39115, 64001, 72069, 72106, 72108, 71034, 71059, 71060,
             71072, 71075, 71076, 186158, 186198, 72003, 32040, 73057, 72090)
  AND id NOT IN (SELECT id FROM npc_types_backup_raid_scaling);

-- Verify backup row count
SELECT 'npc_types_backup_raid_scaling rows' AS label, COUNT(*) AS row_count
FROM npc_types_backup_raid_scaling;

-- ============================================================
-- Backup 2: spawn2 rows for raid-target bosses
-- ============================================================
CREATE TABLE spawn2_backup_raid_scaling AS
SELECT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
JOIN npc_types nt ON nt.id = se.npcID
WHERE nt.raid_target = 1
  AND nt.level BETWEEN 45 AND 70
  AND nt.name NOT LIKE '#The_Fabled%';

-- Also capture any spawn2 rows for the explicit NPC list
INSERT INTO spawn2_backup_raid_scaling
SELECT DISTINCT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID IN (71071, 91090, 48041, 39115, 64001, 72069, 72106, 72108, 71034, 71059, 71060,
                   71072, 71075, 71076, 186158, 186198, 72003, 32040, 73057, 72090)
  AND s2.id NOT IN (SELECT id FROM spawn2_backup_raid_scaling);

SELECT 'spawn2_backup_raid_scaling rows' AS label, COUNT(*) AS row_count
FROM spawn2_backup_raid_scaling;

-- ============================================================
-- Backup 3: npc_spells_entries for the 3 affected spell lists
-- ============================================================
CREATE TABLE npc_spells_entries_backup_raid_scaling AS
SELECT npc_spells_id, spellid, minlevel, maxlevel, priority, resist_adjust, min_hp, max_hp
FROM npc_spells_entries
WHERE npc_spells_id IN (118, 449, 969);

SELECT 'npc_spells_entries_backup_raid_scaling rows' AS label, COUNT(*) AS row_count
FROM npc_spells_entries_backup_raid_scaling;

-- Expected: ~20 rows total for all three lists combined
-- Confirm spell 982 (Cazic Touch) is captured
SELECT 'Cazic Touch rows in backup' AS label, COUNT(*) AS row_count
FROM npc_spells_entries_backup_raid_scaling
WHERE spellid = 982;
-- Expected: 3 (one per spell list 118, 449, 969)
