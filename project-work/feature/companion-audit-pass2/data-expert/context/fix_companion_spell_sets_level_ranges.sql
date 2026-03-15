-- fix_companion_spell_sets_level_ranges.sql
-- Fix 13 inverted min_level/max_level entries in companion_spell_sets
-- These are additional inversions beyond the 4 already fixed in npc_spells_entries.
-- Date: 2026-03-15

SELECT 'BEFORE FIX - Inverted level ranges in companion_spell_sets:' AS status;
SELECT css.id, css.class_id, css.spell_id, css.spell_type, css.priority,
       css.min_level, css.max_level, sn.name AS spell_name
FROM companion_spell_sets css
LEFT JOIN spells_new sn ON css.spell_id = sn.id
WHERE css.max_level > 0 AND css.min_level > css.max_level
ORDER BY css.class_id, css.min_level;

-- Mirrored from npc_spells_entries (same spells, same fix rationale):

-- PAL (class=3): Touch of Nife heal — min=61, max=52 → min=52, max=65
UPDATE companion_spell_sets SET min_level=52, max_level=65
WHERE id=862 AND class_id=3 AND spell_id=3429 AND min_level=61 AND max_level=52;

-- DRU (class=6): Creeping Crud DoT — min=24, max=23 → min=24, max=28
UPDATE companion_spell_sets SET min_level=24, max_level=28
WHERE id=714 AND class_id=6 AND spell_id=99 AND min_level=24 AND max_level=23;

-- RNG (class=10): Talisman of Kragg buff — min=55, max=9 → min=55, max=65
UPDATE companion_spell_sets SET min_level=55, max_level=65
WHERE id=634 AND class_id=10 AND spell_id=1585 AND min_level=55 AND max_level=9;

-- WIZ (class=12): Resistant Armor buff — min=61, max=57 → min=57, max=65
UPDATE companion_spell_sets SET min_level=57, max_level=65
WHERE id=197 AND class_id=12 AND spell_id=3326 AND min_level=61 AND max_level=57;

-- Bard (class=8): 6 song buffs with incorrect max_level=21, fix to max_level=65
-- The min_level values are correct (match spell level from spells_new).
-- The max_level=21 values are a data entry error — songs are usable through end of era.

-- Vilia's Verses of Celerity (spell 740, bard level 36)
UPDATE companion_spell_sets SET max_level=65
WHERE id=1040 AND class_id=8 AND spell_id=740 AND max_level=21;

-- McVaxius' Berserker Crescendo (spell 702, bard level 42)
UPDATE companion_spell_sets SET max_level=65
WHERE id=1017 AND class_id=8 AND spell_id=702 AND max_level=21;

-- Verses of Victory (spell 747, bard level 50)
UPDATE companion_spell_sets SET max_level=65
WHERE id=1045 AND class_id=8 AND spell_id=747 AND max_level=21;

-- Vilia's Chorus of Celerity (spell 1757, bard level 54)
UPDATE companion_spell_sets SET max_level=65
WHERE id=1060 AND class_id=8 AND spell_id=1757 AND max_level=21;

-- McVaxius' Rousing Rondo (spell 1760, bard level 57)
UPDATE companion_spell_sets SET max_level=65
WHERE id=1063 AND class_id=8 AND spell_id=1760 AND max_level=21;

-- Warsong of Zek (spell 3374, bard level 62)
UPDATE companion_spell_sets SET max_level=65
WHERE id=1087 AND class_id=8 AND spell_id=3374 AND max_level=21;

-- Wind of Marr (spell 3651, bard heal, min=62, max=53) → min=53, max=65
UPDATE companion_spell_sets SET min_level=53, max_level=65
WHERE id=1092 AND class_id=8 AND spell_id=3651 AND min_level=62 AND max_level=53;

-- Berserker (class=15): 2 DD spells with inverted values
-- Blizzard Blast (spell 510, berserker level 59, min=59, max=57) → min=57, max=65
UPDATE companion_spell_sets SET min_level=57, max_level=65
WHERE id=1166 AND class_id=15 AND spell_id=510 AND min_level=59 AND max_level=57;

-- Frost Spear (spell 3493, berserker level 63, min=63, max=57) → min=63, max=65
UPDATE companion_spell_sets SET min_level=63, max_level=65
WHERE id=1188 AND class_id=15 AND spell_id=3493 AND min_level=63 AND max_level=57;

-- Verify all fixed
SELECT 'AFTER FIX - Inverted level ranges should be zero:' AS status;
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS: No inverted level ranges remain in companion_spell_sets'
  ELSE CONCAT('FAIL: ', COUNT(*), ' inverted entries remain')
  END AS validation_result
FROM companion_spell_sets WHERE max_level > 0 AND min_level > max_level;
