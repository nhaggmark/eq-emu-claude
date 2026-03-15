-- Companion Resurrection System: Spell Data Migration
-- Feature: companion-resurrection
-- Author: data-expert
-- Date: 2026-03-15
--
-- Populates companion_spell_sets with era-appropriate resurrection spells
-- for Cleric (class_id=2), Paladin (class_id=3), and Necromancer (class_id=11).
-- Also inserts 5 new rule_values entries for companion rez tuning.
--
-- SpellType_Resurrect = 65536 (1 << 16)
-- priority=1 is highest priority in companion_spell_sets (checked first in idle cast)
-- stance=0 = all stances
-- min_hp_pct=0, max_hp_pct=0 = no HP filter (rez targets corpses, not living targets)
--
-- All spell IDs verified from spells_new table (effectid1=81, id<3000).
-- XP restore percentages from effect_base_value1.
-- Post-Luclin spells excluded per PRD (no PoP+, no CS spells).
--
-- Spell ladder (era-appropriate, Classic through Luclin):
--   ID   | Name           | CLR lvl | PAL lvl | NEC lvl | Mana | XP%
--   2168 | Reanimation    |  12     |  22     |  --     |  150 |  0%
--   2169 | Reconstitution |  18     |  30     |  --     |  200 | 10%
--   2170 | Reparation     |  22     |  31     |  --     |  250 | 20%
--   391  | Revive         |  27     |  39     |  --     |  300 | 35%
--   2171 | Renewal        |  32     |  49     |  --     |  400 | 50%
--   388  | Resuscitate    |  37     |  --     |  --     |  500 | 60%
--   2172 | Restoration    |  42     |  55     |  --     |  600 | 75%
--   392  | Resurrection   |  47     |  59     |  --     |  700 | 90%
--   1524 | Reviviscence   |  56     |  --     |  --     |  600 | 96%
--   1733 | Convergence    |  --     |  --     |  53     |  700 | 93%

-- ============================================================
-- companion_spell_sets: Cleric rez spells (class_id=2)
-- ============================================================
INSERT INTO companion_spell_sets
  (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
VALUES
  -- Reanimation: CLR 12, 0% XP restore, 150 mana
  (2, 12, 65, 2168, 65536, 0, 1, 0, 0),
  -- Reconstitution: CLR 18, 10% XP restore, 200 mana
  (2, 18, 65, 2169, 65536, 0, 1, 0, 0),
  -- Reparation: CLR 22, 20% XP restore, 250 mana
  (2, 22, 65, 2170, 65536, 0, 1, 0, 0),
  -- Revive: CLR 27, 35% XP restore, 300 mana
  (2, 27, 65, 391,  65536, 0, 1, 0, 0),
  -- Renewal: CLR 32, 50% XP restore, 400 mana
  (2, 32, 65, 2171, 65536, 0, 1, 0, 0),
  -- Resuscitate: CLR 37, 60% XP restore, 500 mana (CLR-only — PAL doesn't get this)
  (2, 37, 65, 388,  65536, 0, 1, 0, 0),
  -- Restoration: CLR 42, 75% XP restore, 600 mana
  (2, 42, 65, 2172, 65536, 0, 1, 0, 0),
  -- Resurrection: CLR 47, 90% XP restore, 700 mana
  (2, 47, 65, 392,  65536, 0, 1, 0, 0),
  -- Reviviscence: CLR 56 (Kunark), 96% XP restore, 600 mana
  (2, 56, 65, 1524, 65536, 0, 1, 0, 0);

-- ============================================================
-- companion_spell_sets: Paladin rez spells (class_id=3)
-- ============================================================
INSERT INTO companion_spell_sets
  (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
VALUES
  -- Reanimation: PAL 22, 0% XP restore, 150 mana
  (3, 22, 65, 2168, 65536, 0, 1, 0, 0),
  -- Reconstitution: PAL 30, 10% XP restore, 200 mana
  (3, 30, 65, 2169, 65536, 0, 1, 0, 0),
  -- Reparation: PAL 31, 20% XP restore, 250 mana
  (3, 31, 65, 2170, 65536, 0, 1, 0, 0),
  -- Revive: PAL 39, 35% XP restore, 300 mana
  (3, 39, 65, 391,  65536, 0, 1, 0, 0),
  -- Renewal: PAL 49, 50% XP restore, 400 mana
  (3, 49, 65, 2171, 65536, 0, 1, 0, 0),
  -- Restoration: PAL 55, 75% XP restore, 600 mana
  (3, 55, 65, 2172, 65536, 0, 1, 0, 0),
  -- Resurrection: PAL 59, 90% XP restore, 700 mana
  (3, 59, 65, 392,  65536, 0, 1, 0, 0);

-- ============================================================
-- companion_spell_sets: Necromancer rez spells (class_id=11)
-- ============================================================
-- Only Convergence is available in Classic-Luclin era for NEC.
-- Convergence requires Essence Emerald reagent which will be waived
-- per RezWaiveReagents rule (lore: draws on residual death-energy from combat).
INSERT INTO companion_spell_sets
  (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
VALUES
  -- Convergence: NEC 53 (Kunark), 93% XP restore, 700 mana, reagent waived
  (11, 53, 65, 1733, 65536, 0, 1, 0, 0);

-- ============================================================
-- rule_values: 5 new companion rez rules (ruleset_id=1 = "default")
-- ============================================================
INSERT INTO rule_values (ruleset_id, rule_name, rule_value)
VALUES
  -- Master toggle for autonomous companion resurrection
  (1, 'Companions:RezEnabled', 'true'),
  -- Seconds after combat ends before healer attempts rez (post-combat settling period)
  (1, 'Companions:RezPostCombatDelayS', '10'),
  -- Maximum distance in units to target a corpse for rez
  (1, 'Companions:RezRange', '200'),
  -- Percentage of current level XP lost on companion death
  (1, 'Companions:XPDeathPenaltyPct', '10'),
  -- Waive spell reagent requirements for companion rez casters (enables NEC Convergence)
  (1, 'Companions:RezWaiveReagents', 'true');
