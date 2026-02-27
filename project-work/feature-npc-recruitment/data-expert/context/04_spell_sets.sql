-- =============================================================================
-- Task 5: Create companion_spell_sets table + seed all 15 Classic-Luclin classes
-- Feature: npc-recruitment
-- Source: npc_spells_entries joined with Default class spell lists
--   npc_spells ID 1  = Default Cleric List    -> class_id 2  (CLR)
--   npc_spells ID 2  = Default Wizard List     -> class_id 12 (WIZ)
--   npc_spells ID 3  = Default Necromancer List-> class_id 11 (NEC)
--   npc_spells ID 4  = Default Magician List   -> class_id 13 (MAG)
--   npc_spells ID 5  = Default Enchanter List  -> class_id 14 (ENC)
--   npc_spells ID 6  = Default Shaman List     -> class_id 10 (SHM)
--   npc_spells ID 7  = Default Druid List      -> class_id 6  (DRU)
--   npc_spells ID 8  = Default Paladin List    -> class_id 3  (PAL)
--   npc_spells ID 9  = Default Shadowknight List -> class_id 5 (SHK)
--   npc_spells ID 10 = Default Ranger List     -> class_id 4  (RNG)
--   npc_spells ID 11 = Default Bard List       -> class_id 8  (BRD)
--   npc_spells ID 12 = Default Beastlord List  -> class_id 15 (BST)
--
-- Warriors (1), Monks (7), Rogues (9): no spell entries (pure melee classes)
-- Berserker (16): post-Luclin, excluded per era lock
--
-- stance = 0 (all stances): companion_ai.cpp applies stance filtering on spellid
-- =============================================================================

-- companion_spell_sets: class-specific spell lists for recruited companions
CREATE TABLE IF NOT EXISTS companion_spell_sets (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  class_id        TINYINT UNSIGNED NOT NULL,
  min_level       TINYINT UNSIGNED NOT NULL DEFAULT 1,
  max_level       TINYINT UNSIGNED NOT NULL DEFAULT 65,
  spell_id        INT UNSIGNED NOT NULL,
  spell_type      INT UNSIGNED NOT NULL,     -- same type bitmasks as npc_spells_entries
  stance          SMALLINT NOT NULL DEFAULT 0, -- 0=all stances
  priority        SMALLINT NOT NULL DEFAULT 0,
  min_hp_pct      SMALLINT NOT NULL DEFAULT 0,
  max_hp_pct      SMALLINT NOT NULL DEFAULT 100,
  INDEX idx_class_level (class_id, min_level, max_level)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- =============================================================================
-- Populate from Default class spell lists
-- Cap maxlevel at 65 for Luclin era lock
-- =============================================================================

-- CLR (class_id = 2): Default Cleric List (npc_spells_id = 1)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 2, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM npc_spells_entries
WHERE npc_spells_id = 1 AND minlevel <= 65;

-- WIZ (class_id = 12): Default Wizard List (npc_spells_id = 2)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 12, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM npc_spells_entries
WHERE npc_spells_id = 2 AND minlevel <= 65;

-- NEC (class_id = 11): Default Necromancer List (npc_spells_id = 3)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 11, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM npc_spells_entries
WHERE npc_spells_id = 3 AND minlevel <= 65;

-- MAG (class_id = 13): Default Magician List (npc_spells_id = 4)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 13, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM npc_spells_entries
WHERE npc_spells_id = 4 AND minlevel <= 65;

-- ENC (class_id = 14): Default Enchanter List (npc_spells_id = 5)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 14, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM npc_spells_entries
WHERE npc_spells_id = 5 AND minlevel <= 65;

-- SHM (class_id = 10): Default Shaman List (npc_spells_id = 6)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 10, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM npc_spells_entries
WHERE npc_spells_id = 6 AND minlevel <= 65;

-- DRU (class_id = 6): Default Druid List (npc_spells_id = 7)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 6, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM npc_spells_entries
WHERE npc_spells_id = 7 AND minlevel <= 65;

-- PAL (class_id = 3): Default Paladin List (npc_spells_id = 8)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 3, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM npc_spells_entries
WHERE npc_spells_id = 8 AND minlevel <= 65;

-- SHK / Shadowknight (class_id = 5): Default Shadowknight List (npc_spells_id = 9)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 5, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM npc_spells_entries
WHERE npc_spells_id = 9 AND minlevel <= 65;

-- RNG (class_id = 4): Default Ranger List (npc_spells_id = 10)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 4, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM npc_spells_entries
WHERE npc_spells_id = 10 AND minlevel <= 65;

-- BRD (class_id = 8): Default Bard List (npc_spells_id = 11)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 8, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM npc_spells_entries
WHERE npc_spells_id = 11 AND minlevel <= 65;

-- BST (class_id = 15): Default Beastlord List (npc_spells_id = 12)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 15, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM npc_spells_entries
WHERE npc_spells_id = 12 AND minlevel <= 65;

-- WAR (class_id = 1): no spell entries (pure melee — handled by melee AI only)
-- MNK (class_id = 7): no spell entries (pure melee — kick, flying kick, etc.)
-- ROG (class_id = 9): no spell entries (backstab, evade handled by melee AI)
