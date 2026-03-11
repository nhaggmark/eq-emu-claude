-- Cannibalize Spell Data Migration
-- Feature: npc-companion-realistic-stats
-- Issue: #6 (Shaman Cannibalize AI Enhancement)
-- Date: 2026-03-11
--
-- Adds Cannibalize I-IV to companion_spell_sets for shaman companions (class_id=10).
-- These spells are identified by the C++ FindCannibalizeSpell() helper via:
--   effectid2=15 (SE_CurrentMana) with positive base value
--   targettype=6 (ST_Self)
-- The spell_type=2 (SpellType_Heal) tag ensures they are loaded into m_companion_spells.
--
-- Spell verification:
--   spell_id=265:  Cannibalize     - shaman lvl 23, HP cost=-50, mana gain=+16
--   spell_id=754:  Cannibalize II  - shaman lvl 38, HP cost=-67, mana gain=+21
--   spell_id=1572: Cannibalize III - shaman lvl 54, HP cost=-74, mana gain=+26
--   spell_id=1332: Cannibalize IV  - shaman lvl 58, HP cost=-148, mana gain=+52
--
-- All Classic-Luclin era. Level ranges are tiered so only the highest-available
-- version loads at each level bracket.

-- Guard: only insert if entries do not already exist
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 10, 23, 37, 265, 2, 0, 1, 0, 100
WHERE NOT EXISTS (
    SELECT 1 FROM companion_spell_sets WHERE class_id = 10 AND spell_id = 265
);

INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 10, 38, 53, 754, 2, 0, 1, 0, 100
WHERE NOT EXISTS (
    SELECT 1 FROM companion_spell_sets WHERE class_id = 10 AND spell_id = 754
);

INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 10, 54, 57, 1572, 2, 0, 1, 0, 100
WHERE NOT EXISTS (
    SELECT 1 FROM companion_spell_sets WHERE class_id = 10 AND spell_id = 1572
);

INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 10, 58, 65, 1332, 2, 0, 1, 0, 100
WHERE NOT EXISTS (
    SELECT 1 FROM companion_spell_sets WHERE class_id = 10 AND spell_id = 1332
);

-- Verification: confirm all four spells were inserted
SELECT css.id, css.class_id, css.min_level, css.max_level, css.spell_id, css.spell_type, s.name
FROM companion_spell_sets css
JOIN spells_new s ON css.spell_id = s.id
WHERE css.class_id = 10 AND css.spell_id IN (265, 754, 1572, 1332)
ORDER BY css.min_level;
