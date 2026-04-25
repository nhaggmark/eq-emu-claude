-- Phase 5a Luclin non-VT Raid Scaling -- Backup Tables
-- Date: 2026-04-22
-- Purpose: Pre-change snapshots scoped to Phase 5a NPC IDs.
-- Run this FIRST before 14-luclin-a-implementation.sql.
-- Q50=A INCLUDE: rune/glyph serpents 162253, 162261
-- Q51=B INCLUDE (user override): Akheva elite-named 179133, 179046, 179044
-- Q59=A INCLUDE: A_Spiritual_Arcanist 154153
-- DO NOT TOUCH: Spirit of Akelha`Ra 179144 (Decision #30 VT-key turn-in NPC at 1M HP)
-- DO NOT TOUCH: Shei Vinitras list 179 (Decision #60 -- DT preserved on 179032)
-- DELETE is ONLY list 196 spell 2859 (Vyzh`dra Exiled + Banished)

-- ============================================================
-- Backup 1: npc_types for all Phase 5a NPC IDs (expect 41 rows)
-- ============================================================
CREATE TABLE npc_types_backup_raid_scaling_luclin_a AS
SELECT id, name, level, hp, mindmg, maxdmg, AC, MR, special_abilities, npcspecialattks, npc_spells_id
FROM npc_types
WHERE id IN (
    -- ssratemple -- 13 bosses + 2 cycle serpents (Q50=A INCLUDE)
    162227, 162076, 162190, 162177, 162192, 162178,
    162189, 162064,
    162066, 162067, 162191,
    162258, 162089,
    162253, 162261,
    -- akheva -- 8 primary + 3 elite-named (Q51=B INCLUDE user override)
    162206, 162232, 162214,
    179037, 179032, 179157, 179180, 179178, 179134,
    179133, 179046, 179044,
    -- sseru/katta -- 7
    159691, 159113, 159112, 159115, 159114,
    160375, 160135,
    -- griegsend -- 4 (main + variant + Servitor + Praetorian)
    163075, 163231, 163013, 163078,
    -- acrylia -- 2 + Spiritual Arcanist (Q59=A INCLUDE)
    154145, 154142, 154153,
    -- thedeep -- 1
    164078,
    -- umbral -- 3
    176088, 176089, 176002
);
-- Expected rows: 41 (post-Q50/Q51/Q59 inclusions)

SELECT 'npc_types_backup_raid_scaling_luclin_a rows (expect 41)' AS label,
       COUNT(*) AS row_count
FROM npc_types_backup_raid_scaling_luclin_a;

-- ============================================================
-- Backup 2: spawn2 rows for Phase 5a bosses
-- ============================================================
-- NOTES:
--   Script-spawned (NO spawn2): 162227 Emperor, 162177 Rhag`Zadune, 162192 Rhag`Mozdezh,
--     162189 Blood, 162064 Blood Golem, 162206/232/214 Vyzh`dra trio, 162253/261 serpents,
--     154145 Khati Sha, 154153 Spiritual Arcanist, 176088 Doomshade, 163075 Grieg main -- silently skipped.
--   Pre-Emperor named (162066/067/191): 17 spawn2 rows each at 1080s -- backed up for safety,
--     NOT in respawn UPDATE (short-tier farming cadence preserved).
--   Akheva elite-named (179133/046/044): 5 spawn2 rows at 5400s -- backed up,
--     NOT in respawn UPDATE per Q51 named-tier philosophy.
--   Shar Vinitras 179134: 1 row at 10800s short-tier -- backed up, NOT in respawn UPDATE.
--   Rhozth pair (162258/089): mid-tier respawn -- backed up, NOT in respawn UPDATE.
CREATE TABLE spawn2_backup_raid_scaling_luclin_a AS
SELECT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance,
       s2._condition, s2.cond_value, s2.x, s2.y, s2.z, s2.heading
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID IN (
    -- ssratemple standing-spawn
    162076, 162190, 162178,
    -- pre-Emperor named (17 rows each at 1080s -- captured for safety, respawn NOT updated)
    162066, 162067, 162191,
    -- Rhozth pair (mid-tier, respawn NOT updated)
    162258, 162089,
    -- akheva primary
    179037, 179032, 179157, 179180, 179178, 179134,
    -- akheva elite-named (Q51=B INCLUDE -- backup captured, respawn UNCHANGED at 5400s)
    179133, 179046, 179044,
    -- sseru/katta
    159691, 159113, 159112, 159115, 159114,
    160375, 160135,
    -- griegsend variant + Servitor + Praetorian (163075 main has no spawn2)
    163231, 163013, 163078,
    -- acrylia evolved burrower
    154142,
    -- thedeep
    164078,
    -- umbral
    176089, 176002
);
-- Expected rows: ~22-23 standing-spawn raid-tier rows + ~51 pre-Emperor rows captured for safety

SELECT 'spawn2_backup_raid_scaling_luclin_a rows' AS label,
       COUNT(*) AS row_count
FROM spawn2_backup_raid_scaling_luclin_a;

-- ============================================================
-- Backup 3: npc_spells_entries -- Touch of Vinitras pre-DELETE
-- ============================================================
-- Captures the SINGLE row we will DELETE: list 196, spell 2859 (Touch of Vinitras -20000 HP DT)
-- Used by Vyzh`dra the Exiled (162232) and Vyzh`dra the Banished (162214)
-- List 179 (Shei Vinitras 179032) is NOT touched -- Decision #60 preserves that DT
CREATE TABLE npc_spells_entries_backup_raid_scaling_luclin_a AS
SELECT * FROM npc_spells_entries
WHERE npc_spells_id = 196 AND spellid = 2859;
-- Expected rows: 1

SELECT 'npc_spells_entries_backup_raid_scaling_luclin_a rows (expect 1)' AS label,
       COUNT(*) AS row_count
FROM npc_spells_entries_backup_raid_scaling_luclin_a;
