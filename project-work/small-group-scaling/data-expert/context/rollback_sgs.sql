-- ============================================================================
-- Small-Group Scaling (SGS) Rollback Script
-- Generated: 2026-02-23
-- Purpose: Restore all database changes made by the SGS implementation
-- Usage:
--   docker exec -i akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq < rollback_sgs.sql
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Rollback npc_types stats (hp, mindmg, maxdmg, AC)
--    Restores ~44,000+ non-raid NPCs (levels 1-65) to pre-SGS values
-- ---------------------------------------------------------------------------
UPDATE npc_types nt
JOIN npc_types_backup_sgs bk ON nt.id = bk.id
SET nt.hp = bk.hp,
    nt.mindmg = bk.mindmg,
    nt.maxdmg = bk.maxdmg,
    nt.AC = bk.AC;

-- ---------------------------------------------------------------------------
-- 2. Rollback npc_scale_global_base (types 0 and 1, levels 1-65)
--    NOTE: No backup table was created for this. These must be restored from
--    the full mysqldump backup if needed, or recalculated by doubling hp,
--    multiplying max_dmg by 1/0.75, min_dmg by 1/0.65, ac by 1/0.82.
--    Approximate reversal (may have rounding differences):
-- ---------------------------------------------------------------------------
UPDATE npc_scale_global_base
SET hp = ROUND(hp / 0.50),
    max_dmg = ROUND(max_dmg / 0.75),
    min_dmg = ROUND(min_dmg / 0.65),
    ac = ROUND(ac / 0.82)
WHERE type IN (0, 1) AND level BETWEEN 1 AND 65;

-- ---------------------------------------------------------------------------
-- 3. Rollback loottable_entries probability
--    Restores probability for loot tables linked to named/raid NPCs
-- ---------------------------------------------------------------------------
UPDATE loottable_entries lte
JOIN loottable_entries_backup_sgs bk
  ON lte.loottable_id = bk.loottable_id AND lte.lootdrop_id = bk.lootdrop_id
SET lte.probability = bk.probability;

-- ---------------------------------------------------------------------------
-- 4. Rollback lootdrop_entries chance
--    Restores drop chance for rare items in named/raid loot tables
-- ---------------------------------------------------------------------------
UPDATE lootdrop_entries lde
JOIN lootdrop_entries_backup_sgs bk
  ON lde.lootdrop_id = bk.lootdrop_id AND lde.item_id = bk.item_id
SET lde.chance = bk.chance;

-- ---------------------------------------------------------------------------
-- 5. Rollback spawn2 respawntime
--    Restores respawn timers for named/raid NPC spawn points
-- ---------------------------------------------------------------------------
UPDATE spawn2 s2
JOIN spawn2_backup_sgs bk ON s2.id = bk.id
SET s2.respawntime = bk.respawntime;

-- ---------------------------------------------------------------------------
-- 6. Rollback rule_values
--    Restores all ~34 modified rules to their pre-SGS values
-- ---------------------------------------------------------------------------
UPDATE rule_values rv
JOIN rule_values_backup_sgs bk
  ON rv.rule_name = bk.rule_name AND rv.ruleset_id = bk.ruleset_id
SET rv.rule_value = bk.rule_value;

-- ---------------------------------------------------------------------------
-- 7. Rollback level_exp_mods (optional)
--    The table had 100 rows before SGS. We set levels 1-65 to 1.0/1.0.
--    If those were already 1.0 before, this is a no-op. To fully restore,
--    use the full mysqldump backup.
-- ---------------------------------------------------------------------------
-- No action needed unless values were different before SGS.

-- ---------------------------------------------------------------------------
-- POST-ROLLBACK: Reload rules and restart server
-- ---------------------------------------------------------------------------
-- After running this script, execute in-game:
--   #reloadrules
--   #reloadworld
-- Or restart the server via Spire at http://192.168.1.86:3000

-- ---------------------------------------------------------------------------
-- CLEANUP: Drop backup tables (only after confirming rollback is complete)
-- ---------------------------------------------------------------------------
-- DROP TABLE IF EXISTS npc_types_backup_sgs;
-- DROP TABLE IF EXISTS loottable_entries_backup_sgs;
-- DROP TABLE IF EXISTS lootdrop_entries_backup_sgs;
-- DROP TABLE IF EXISTS spawn2_backup_sgs;
-- DROP TABLE IF EXISTS rule_values_backup_sgs;
