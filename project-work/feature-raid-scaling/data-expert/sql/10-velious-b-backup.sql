-- Phase 4b Velious-B Raid Scaling — Backup Tables
-- Date: 2026-04-22
-- Purpose: Pre-change snapshots scoped to Phase 4b NPC IDs.
-- Run this FIRST before 11-velious-b-implementation.sql.
-- EXCLUDES: Kerafyrm trio (128089/94/95), The Sleeper (128094) — per Decision #12.
-- INCLUDES: Defenders 124050/51/52/79 per user Q37 override 2026-04-23.

-- ============================================================
-- Backup 1: npc_types for all Phase 4b NPC IDs (expect 51 rows)
-- ============================================================
CREATE TABLE npc_types_backup_raid_scaling_velious_b AS
SELECT id, name, level, hp, mindmg, maxdmg, AC, MR, special_abilities, npcspecialattks, npc_spells_id
FROM npc_types
WHERE id IN (
    -- ToV 16 dragon lords
    124001, 124004, 124008, 124010, 124011, 124017, 124020, 124037,
    124071, 124072, 124074, 124076, 124077, 124103, 124104, 124105,
    -- NToV 16 mid-tier named (Midayor cluster + L65-66)
    124018, 124073, 124007, 124106, 124107, 124003, 124009, 124075,
    124030, 124031, 124034, 124035, 124036, 124038, 124039, 124040,
    -- NToV Defenders (4 — included per user Q37 override 2026-04-23)
    124050, 124051, 124052, 124079,
    -- Vulak`Aerr + Avatar of War
    124155, 113457,
    -- Sleeper's Tomb 13 (4 Ancients + Progenitor + Arbiter main & alt + MotG + Milas + 4 Warders)
    128040, 128041, 128042, 128043, 128044, 128045,
    128090, 128091, 128092, 128093,
    128143, 128144, 128145
);
-- Expected rows: 51
-- Note: 128089/94/95 (Kerafyrm trio) explicitly excluded per Decision #12.

SELECT 'npc_types_backup_raid_scaling_velious_b rows (expect 51)' AS label,
       COUNT(*) AS row_count
FROM npc_types_backup_raid_scaling_velious_b;

-- ============================================================
-- Backup 2: spawn2 rows for Phase 4b bosses
-- ============================================================
-- Note: 113457 AoW + 124155 Vulak have NO spawn2 rows (script-spawned) — silently skipped by JOIN.
-- Note: 128089/94/95 Kerafyrm trio excluded per Decision #12.
-- Note: Defenders (124050/51/52/79) included for backup but respawn NOT updated (native 3-5h preserved).
-- Note: Warders (128090-93) + Final Arbiter alt (128045) on condition 1 — backed up, respawn NOT updated.
CREATE TABLE spawn2_backup_raid_scaling_velious_b AS
SELECT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance,
       s2._condition, s2.cond_value, s2.x, s2.y, s2.z, s2.heading
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID IN (
    124001, 124004, 124008, 124010, 124011, 124017, 124020, 124037,
    124071, 124072, 124074, 124076, 124077, 124103, 124104, 124105,
    124018, 124073, 124007, 124106, 124107, 124003, 124009, 124075,
    124030, 124031, 124034, 124035, 124036, 124038, 124039, 124040,
    124050, 124051, 124052, 124079,
    128040, 128041, 128042, 128043, 128044, 128045,
    128090, 128091, 128092, 128093,
    128143, 128144, 128145
);
-- Expected rows: ~46-49 (shared spawngroups mean some spawn2 rows appear for multiple NPC IDs;
--   DISTINCT via spawn2.id implicit in result; actual count confirmed via SELECT after run)

SELECT 'spawn2_backup_raid_scaling_velious_b rows (expect ~46-49)' AS label,
       COUNT(*) AS row_count
FROM spawn2_backup_raid_scaling_velious_b;
