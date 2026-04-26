-- Phase 5b Luclin VT (FINAL PHASE) -- Backup Tables
-- Date: 2026-04-22
-- Purpose: Pre-change snapshots scoped to Phase 5b NPC IDs.
-- Run this FIRST before 17-luclin-b-implementation.sql.
--
-- User decisions applied:
--   Q67 = B  -- DELETE spell 1948 from npc_spells_entries list 229 (Destroy Aten form)
--   Q68 = A  -- INCLUDE A_burrower_parasite 164089 (Phase 5a audit-leak)
--   Q69 = A  -- Acknowledge 13-shard framing (10 Lucid Shards + 3 components; no SQL action)
--   Q70 = A  -- KEEP NATIVE Aten Ha Ra respawn (~2h post-kill qglobal lockout; no Perl edit)
--
-- DO NOT TOUCH: Kerafyrm list 489 spell 1948 (Phase 4b Decision #12)
-- DO NOT TOUCH: Aten 158096 list 540 (Word of Command/Silence/Fling; no Destroy)
-- DO NOT TOUCH: Va_Dyn_Khar 158081 spawn2 respawntime (already 21,600s 6h short-tier)
-- DO NOT TOUCH: Aten_Trigger 158095 (50M HP controller, raid_target=0)
-- DO NOT TOUCH: All Phase 5a NPCs (162xxx, 179xxx, 159xxx, 154xxx, 164078, 176xxx)

-- ============================================================
-- Backup 1: npc_types for all Phase 5b NPC IDs (expect 125 rows with Q68=A)
-- ============================================================
CREATE TABLE npc_types_backup_raid_scaling_luclin_b AS
SELECT id, name, level, hp, mindmg, maxdmg, AC, MR, special_abilities, npcspecialattks, npc_spells_id, raid_target
FROM npc_types
WHERE id IN (
    -- Aten Ha Ra dual-form (script-spawned, no spawn2)
    158006, 158096,
    -- 9 inner-VT gating bosses (spawn2-backed, 130h respawn)
    158007, 158008, 158009, 158010, 158011, 158012, 158013, 158014, 158015,
    -- Thall Va Xakra dual (south + north, spawn2-backed, 39h respawn)
    158016, 158125,
    -- Va_Dyn_Khar (Palace Key dropper, spawn2-backed, 6h respawn)
    158081,
    -- 6 Akhevan Warder NPC IDs (script-summoned adds, no spawn2)
    158087, 158088, 158089, 158090, 158091, 158094,
    -- 104 Yaemiu raid_target=1 trash (standing-spawn + trap-only)
    158000, 158001, 158002, 158003, 158004, 158005,
    158017, 158018, 158019, 158020, 158021, 158022, 158023, 158024, 158025, 158026,
    158027, 158028, 158029, 158030, 158031, 158032, 158033, 158034, 158035, 158036,
    158037, 158038, 158039, 158040, 158041, 158042, 158043, 158044, 158045, 158046,
    158047, 158048, 158049, 158050, 158051, 158052, 158053, 158054, 158055, 158056,
    158057, 158058, 158059, 158060, 158061, 158062, 158063, 158064, 158065, 158066,
    158067, 158068, 158069, 158070, 158071, 158072, 158073, 158074, 158075, 158076,
    158077, 158078, 158079, 158080, 158082, 158083, 158084, 158085, 158086,
    158092, 158093, 158097, 158098, 158099, 158100, 158101, 158102, 158103, 158104,
    158105, 158106, 158107, 158108, 158109, 158110, 158111, 158115, 158116, 158117,
    158118, 158119, 158120, 158121, 158122, 158124, 158126, 158127,
    -- Q68=A: A_burrower_parasite (thedeep, Phase 5a audit-leak)
    164089
);

SELECT 'npc_types_backup_raid_scaling_luclin_b rows (expect ~125)' AS label,
       COUNT(*) AS row_count
FROM npc_types_backup_raid_scaling_luclin_b;

-- ============================================================
-- Backup 2: spawn2 rows for Phase 5b bosses + Yaemiu safety
-- ============================================================
-- Includes: 9 inner-VT boss rows (~10 including 158007 x2) + 2 Thall Va Xakra rows
--           + Va_Dyn_Khar row + 75 standing Yaemiu rows + trap spawn rows (for completeness)
-- Aten dual (158006/158096) and Akhevan Warders (158087-094) have NO spawn2 rows -- script-spawned
CREATE TABLE spawn2_backup_raid_scaling_luclin_b AS
SELECT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance,
       s2._condition, s2.cond_value, s2.x, s2.y, s2.z, s2.heading
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE s2.zone = 'vexthal'
  AND se.npcID IN (
    158007, 158008, 158009, 158010, 158011, 158012, 158013, 158014, 158015,
    158016, 158125,
    158081,
    158000, 158001, 158002, 158003, 158004, 158005,
    158017, 158018, 158019, 158020, 158021, 158022, 158023, 158024, 158025, 158026,
    158027, 158028, 158029, 158030, 158031, 158032, 158033, 158034, 158035, 158036,
    158037, 158038, 158039, 158040, 158041, 158042, 158043, 158044, 158045, 158046,
    158047, 158048, 158049, 158050, 158051, 158052, 158053, 158054, 158055, 158056,
    158057, 158058, 158059, 158060, 158061, 158062, 158063, 158064, 158065, 158066,
    158067, 158068, 158069, 158070, 158071, 158072, 158073, 158074, 158075, 158076,
    158077, 158078, 158079, 158080, 158082, 158083, 158084, 158085, 158086,
    158092, 158093, 158097, 158098, 158099, 158100, 158101, 158102, 158103, 158104,
    158105, 158106, 158107, 158108, 158109, 158110, 158111, 158115, 158116, 158117,
    158118, 158119, 158120, 158121, 158122, 158124, 158126, 158127
);

SELECT 'spawn2_backup_raid_scaling_luclin_b rows (expect ~110)' AS label,
       COUNT(*) AS row_count
FROM spawn2_backup_raid_scaling_luclin_b;

-- ============================================================
-- Backup 3: npc_spells_entries -- Destroy spell from list 229 (Q67=B)
-- ============================================================
-- Captures the row BEFORE DELETE so rollback can re-insert it.
-- Expect 1 row (list 229 spell 1948 Destroy -100k DT).
CREATE TABLE npc_spells_entries_backup_raid_scaling_luclin_b AS
SELECT * FROM npc_spells_entries
WHERE npc_spells_id = 229 AND spellid = 1948;

SELECT 'npc_spells_entries_backup_raid_scaling_luclin_b rows (expect 1 for Q67=B)' AS label,
       COUNT(*) AS row_count
FROM npc_spells_entries_backup_raid_scaling_luclin_b;
