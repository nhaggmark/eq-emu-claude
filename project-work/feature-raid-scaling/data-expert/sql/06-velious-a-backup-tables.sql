-- Phase 4a Velious non-ToV Raid Scaling — Backup Tables
-- Date: 2026-04-22
-- Purpose: Pre-change snapshots scoped to Phase 4a Velious non-ToV NPC IDs.
-- Run this FIRST before 07-velious-a-implementation.sql.
-- EXCLUDES: ToV proper, Sleeper's Tomb, Avatar of War (113457), Vulak'Aerr (124155) — Phase 4b scope.

-- ============================================================
-- Backup 1: npc_types for all Phase 4a Velious non-ToV NPC IDs
-- ============================================================
CREATE TABLE npc_types_backup_raid_scaling_velious_a AS
SELECT id, name, level, hp, mindmg, maxdmg, AC, special_abilities, npcspecialattks
FROM npc_types
WHERE id IN (
    -- Kael Drakkel (non-AoW): King Tormax, Statue, Idol (triggered), Derakor
    113215, 113071, 113341, 113118,
    -- Skyshrine: 2 Yelinak variants (both live per DB sweep) + 4 Crusaders
    114106, 114618, 114242, 114243, 114245, 114246,
    -- Plane of Growth: Tunare, 2x Guardian of Tunare, Ail, Rumbleroot, Treah,
    --   Guardian of Takish, Fayl Everstrong, Prince Thirneg
    127001, 127007, 127106, 127020, 127019, 127021, 127035, 127018, 127096,
    -- Plane of Mischief: in-era Jester only (Bristlebane L75 + All-Seeing Eye L75 EXCLUDED)
    126012,
    -- Outdoor dragons (ST key path): Sontalak, Klandicar, Zlandicar, Kelorek`Dar
    120005, 120084, 123115, 117073,
    -- Western Wastes near-named tier: Harla Dar, Mraaka, Melalafen
    120057, 120064, 120126,
    -- Velketor's Labyrinth: Velketor the Sorcerer, Lord Doljonijiarnimorinar
    112025, 112049,
    -- Siren's Grotto (one-shot damage risk): Faleniel, Wygrish
    125070, 125072,
    -- Misc outdoor: Wuoshi, Lodizal, Taskmaster Abyott
    119112, 110099, 118088,
    -- Coldain Ring War terminus + Icewell Keep: Narandi, Dain, Chamberlain
    118145, 129003, 129028,
    -- Ring War Kromrif wave mobs (8 IDs, exclusive to greatdivide conditions 3-15 per DB sweep)
    118130, 118160, 118150, 118120, 118209, 118158, 118156, 118210,
    -- Seneschal Aldikar (HP bump: prevent AOE overflow event fail)
    118166
);
-- Expected rows: 46

SELECT 'npc_types_backup_raid_scaling_velious_a rows (expect 46)' AS label,
       COUNT(*) AS row_count
FROM npc_types_backup_raid_scaling_velious_a;

-- ============================================================
-- Backup 2: spawn2 rows for Phase 4a Velious non-ToV bosses
-- ============================================================
-- Note: Idol of Rallos Zek (113341) is triggered (no spawn2), silently skipped by JOIN.
-- Note: Narandi (118145) is condition-gated (spawn2 exists but irrelevant; included for safety).
-- Note: Kromrif wave mobs (118130 etc.) are condition-gated; included for safety snapshot.
CREATE TABLE spawn2_backup_raid_scaling_velious_a AS
SELECT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance,
       s2._condition, s2.cond_value
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID IN (
    113215, 113071, 113118,
    114106, 114618, 114242, 114243, 114245, 114246,
    127001, 127007, 127106, 127020, 127019, 127021, 127035, 127018, 127096,
    126012,
    120005, 120084, 123115, 117073,
    120057, 120064, 120126,
    112025, 112049,
    125070, 125072,
    119112, 110099, 118088,
    118145, 129003, 129028,
    118130, 118160, 118150, 118120, 118209, 118158, 118156, 118210,
    118166
);
-- Expected rows: ~55-65 (includes wave mob spawn2 rows; Idol 113341 silently skipped)

SELECT 'spawn2_backup_raid_scaling_velious_a rows (expect ~55-65)' AS label,
       COUNT(*) AS row_count
FROM spawn2_backup_raid_scaling_velious_a;
