-- Phase 2 Classic Raid Scaling — Emergency Rollback
-- Date: 2026-04-22
-- Purpose: Restore npc_types, spawn2, and npc_spells_entries to pre-Phase-2 state.
-- PREREQUISITE: Backup tables must exist (created by 01-backup-tables.sql).
-- Run this ONLY to undo Phase 2 changes.

START TRANSACTION;

-- ============================================================
-- Rollback 1: npc_types HP/damage/special_abilities
-- ============================================================
UPDATE npc_types nt
JOIN npc_types_backup_raid_scaling bk ON bk.id = nt.id
SET nt.hp       = bk.hp,
    nt.mindmg   = bk.mindmg,
    nt.maxdmg   = bk.maxdmg,
    nt.AC       = bk.AC,
    nt.special_abilities   = bk.special_abilities,
    nt.npcspecialattks     = bk.npcspecialattks;

-- ============================================================
-- Rollback 2: spawn2 respawn timers
-- ============================================================
UPDATE spawn2 s2
JOIN spawn2_backup_raid_scaling bk ON bk.id = s2.id
SET s2.respawntime = bk.respawntime,
    s2.variance    = bk.variance;

-- ============================================================
-- Rollback 3: npc_spells_entries — restore Cazic Touch
-- ============================================================
-- Re-insert only the rows that were deleted (spell 982 in lists 118, 449, 969)
INSERT IGNORE INTO npc_spells_entries (npc_spells_id, spellid, minlevel, maxlevel, priority, resist_adjust, min_hp, max_hp)
SELECT npc_spells_id, spellid, minlevel, maxlevel, priority, resist_adjust, min_hp, max_hp
FROM npc_spells_entries_backup_raid_scaling
WHERE spellid = 982;

COMMIT;

-- ============================================================
-- Rollback verification
-- ============================================================
SELECT 'Nagafen HP (expect 32000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 32040;
SELECT 'Cazic Thule HP (expect 451000 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 72003;
SELECT 'Innoruuk revamp HP (expect 100200 pre-change)' AS check_name, hp AS actual FROM npc_types WHERE id = 186158;
SELECT 'Cazic Touch restored (expect 3)' AS check_name, COUNT(*) AS actual
FROM npc_spells_entries WHERE npc_spells_id IN (118, 449, 969) AND spellid = 982;
SELECT 'Nagafen respawn pre-change' AS check_name, s2.respawntime AS actual
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 32040 LIMIT 1;
