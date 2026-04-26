-- Phase 3 Kunark Raid Scaling — Backup Tables
-- Date: 2026-04-22
-- Purpose: Pre-change snapshots scoped tightly to Phase 3 Kunark NPC IDs.
-- Run this FIRST before 05-kunark-implementation.sql.
-- Phase 2 backup tables (npc_types_backup_raid_scaling, spawn2_backup_raid_scaling)
-- already over-capture these rows but this gives a precise Phase 3-only rollback target.

-- ============================================================
-- Backup 1: npc_types for all Kunark Phase 3 NPC IDs
-- ============================================================
CREATE TABLE npc_types_backup_raid_scaling_kunark AS
SELECT id, name, level, hp, mindmg, maxdmg, AC, special_abilities, npcspecialattks
FROM npc_types
WHERE id IN (
    -- Outdoor dragons
    86014, 94009, 91093, 96089, 96073,
    -- End-dungeon bosses (Trakanon, triggered Trakanon, triggered VS, Drusella)
    89154, 89181, 102112, 105153,
    -- Chardok royals
    103055, 103056, 103080,
    -- City of Mist
    90186, 90093,
    -- VP revamp (live, condition=2)
    108040, 108042, 108043, 108047, 108048, 108050, 108053,
    -- VP classic (dormant, condition=1 — backup only for safety over-capture)
    108509, 108510, 108511, 108512, 108513, 108517,
    -- Renux Herkanor (Q22=Option A: included)
    448200
);
-- Expected rows: 27

SELECT 'npc_types_backup_raid_scaling_kunark rows (expect 27)' AS label, COUNT(*) AS row_count
FROM npc_types_backup_raid_scaling_kunark;

-- ============================================================
-- Backup 2: spawn2 rows for Kunark Phase 3 bosses
-- ============================================================
-- Note: triggered bosses (89181, 96073, 448200, 102112) have no spawn2 rows;
--       JOIN silently skips them — this is correct.
CREATE TABLE spawn2_backup_raid_scaling_kunark AS
SELECT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance, s2._condition, s2.cond_value
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID IN (
    86014, 94009, 91093, 96089,
    89154, 102112, 105153,
    103055, 103056, 103080,
    90186, 90093,
    108040, 108042, 108043, 108047, 108048, 108050, 108053,
    108509, 108510, 108511, 108512, 108513, 108517
);
-- Expected rows: ~22 (outdoor 4 + Trakanon 1 + VS spawn2 1 + Drusella 1 + Chardok 3
--                 + Kilidna 1 + Lhranc 1 + VP revamp 7 + VP classic 6 = 26 max,
--                 minus any duplicates from shared spawngroups)

SELECT 'spawn2_backup_raid_scaling_kunark rows (expect ~22)' AS label, COUNT(*) AS row_count
FROM spawn2_backup_raid_scaling_kunark;

-- Confirm VP split: condition=2 (revamp) vs condition=1 (classic)
SELECT 'VP spawn2 by condition' AS label, _condition, COUNT(*) AS row_count
FROM spawn2_backup_raid_scaling_kunark
WHERE zone = 'veeshan'
GROUP BY _condition;
