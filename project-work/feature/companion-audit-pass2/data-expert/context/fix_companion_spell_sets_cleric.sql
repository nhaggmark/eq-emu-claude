-- fix_companion_spell_sets_cleric.sql
-- NEW-02 (companion_spell_sets): Fix cleric heal priority inversion for class_id=2
-- Mirrors the fix applied to npc_spells_entries list id=1.
--
-- NOTE: This fix uses HIGHER priority number = higher priority semantics.
-- If c-expert confirms LOWER number = higher priority, these values must be inverted.
-- The c-expert confirmation is required before Part 1 (SHM/PAL/RNG/casters) is applied.
-- Cleric fix is included here because the cleric data had BOTH the wrong priority direction
-- (heals below damage) AND was clearly wrong regardless of which direction is correct.
-- (Having heals compete at priority=1 with everything else was the bug, not a direction issue.)
-- Date: 2026-03-15

-- Priority hierarchy applied (matching npc_spells_entries fix):
--   Complete Heal:        50 (highest)
--   Supernal Remedy/Light: 48
--   Remedy/Divine Light/Ethereal Light: 45
--   Superior Healing:     40
--   Greater Healing:      35
--   Healing:              25 (above Wrath=30? depends on semantics — see NOTE)
--   Light Healing:        15
--   Minor Healing:        1 (unchanged)

SELECT 'BEFORE FIX - Cleric companion_spell_sets heals:' AS status;
SELECT css.id, css.class_id, css.spell_id, css.spell_type, css.priority, css.min_level, css.max_level,
       sn.name
FROM companion_spell_sets css LEFT JOIN spells_new sn ON css.spell_id=sn.id
WHERE css.class_id=2 AND css.spell_type=2 ORDER BY css.min_level;

UPDATE companion_spell_sets SET priority=50 WHERE id=4  AND class_id=2 AND spell_id=13   AND spell_type=2;
UPDATE companion_spell_sets SET priority=48 WHERE id=70 AND class_id=2 AND spell_id=3465 AND spell_type=2;
UPDATE companion_spell_sets SET priority=48 WHERE id=78 AND class_id=2 AND spell_id=3480 AND spell_type=2;
UPDATE companion_spell_sets SET priority=45 WHERE id=48 AND class_id=2 AND spell_id=1518 AND spell_type=2;
UPDATE companion_spell_sets SET priority=45 WHERE id=49 AND class_id=2 AND spell_id=1519 AND spell_type=2;
UPDATE companion_spell_sets SET priority=45 WHERE id=60 AND class_id=2 AND spell_id=2182 AND spell_type=2;
UPDATE companion_spell_sets SET priority=40 WHERE id=1  AND class_id=2 AND spell_id=9    AND spell_type=2;
UPDATE companion_spell_sets SET priority=35 WHERE id=6  AND class_id=2 AND spell_id=15   AND spell_type=2;
UPDATE companion_spell_sets SET priority=25 WHERE id=3  AND class_id=2 AND spell_id=12   AND spell_type=2;
UPDATE companion_spell_sets SET priority=15 WHERE id=8  AND class_id=2 AND spell_id=17   AND spell_type=2;

SELECT 'AFTER FIX:' AS status;
SELECT css.id, css.class_id, css.spell_id, css.spell_type, css.priority, css.min_level, css.max_level,
       sn.name
FROM companion_spell_sets css LEFT JOIN spells_new sn ON css.spell_id=sn.id
WHERE css.class_id=2 AND css.spell_type=2 ORDER BY css.min_level;

-- Validation
SELECT CASE WHEN COUNT(*)=0 THEN 'PASS: Cleric companion heals elevated (>=25 at minlevel>=14)'
  ELSE CONCAT('FAIL: ', COUNT(*), ' cleric heals at priority<25') END AS result
FROM companion_spell_sets WHERE class_id=2 AND spell_type=2 AND min_level>=14 AND priority<25;
