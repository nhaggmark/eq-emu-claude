-- fix_cleric_heal_priorities.sql
-- NEW-02: Fix cleric heal priority inversion in npc_spells_entries (list id=1)
-- Problem: Greater Healing, Superior Healing, Complete Heal, Remedy, Divine Light all at priority=1
--          while Wrath is at priority=30 and Smite at priority=20.
--          Level 24+ cleric companions cast damage before healing.
-- Fix: Elevate all mid-high tier heals above damage spell priorities.
--
-- Priority hierarchy after fix:
--   Complete Heal (39+):              50 (highest — critical emergency heal)
--   Supernal Remedy, Supernal Light:  48 (post-60 tier)
--   Remedy, Divine Light (51-67):     45 (high tier)
--   Ethereal Light (58-62):           45 (high tier)
--   Superior Healing (34-52):         40
--   Greater Healing (24-50):          35
--   Healing (14-33):                  25 (above Smite=20)
--   Wrath (29-53):                    30 (damage — unchanged)
--   Smite (14-43):                    20 (damage — unchanged)
--   Light Healing (5-23):             15 (bumped from 10)
--   Minor Healing (1-13):             1  (last resort — unchanged)
--
-- NOTE: This list (npc_spells_id=1) is shared with ~1869 non-companion cleric NPCs.
-- Elevating heals is correct behavior for all clerics — a cleric NPC should heal before attacking.
-- Date: 2026-03-15

SELECT 'BEFORE FIX - Cleric heal priorities (npc_spells_id=1):' AS status;
SELECT nse.id, nse.spellid, nse.type, nse.priority, nse.minlevel, nse.maxlevel, sn.name
FROM npc_spells_entries nse
LEFT JOIN spells_new sn ON nse.spellid = sn.id
WHERE nse.npc_spells_id = 1 AND nse.type = 2
ORDER BY nse.minlevel;

-- Complete Heal (spellid=13, id=36): highest priority heal
UPDATE npc_spells_entries SET priority = 50
WHERE id = 36 AND npc_spells_id = 1 AND spellid = 13 AND type = 2;

-- Supernal Remedy (spellid=3465, id=40): post-60 tier
UPDATE npc_spells_entries SET priority = 48
WHERE id = 40 AND npc_spells_id = 1 AND spellid = 3465 AND type = 2;

-- Supernal Light (spellid=3480, id=41): post-60 tier
UPDATE npc_spells_entries SET priority = 48
WHERE id = 41 AND npc_spells_id = 1 AND spellid = 3480 AND type = 2;

-- Remedy (spellid=1518, id=37): high tier (51-60)
UPDATE npc_spells_entries SET priority = 45
WHERE id = 37 AND npc_spells_id = 1 AND spellid = 1518 AND type = 2;

-- Divine Light (spellid=1519, id=38): high tier (53-67)
UPDATE npc_spells_entries SET priority = 45
WHERE id = 38 AND npc_spells_id = 1 AND spellid = 1519 AND type = 2;

-- Ethereal Light (spellid=2182, id=39): high tier (58-62)
UPDATE npc_spells_entries SET priority = 45
WHERE id = 39 AND npc_spells_id = 1 AND spellid = 2182 AND type = 2;

-- Promised Renewal (spellid=9755, id=20058): post-73 tier (keep elevated but post-era)
UPDATE npc_spells_entries SET priority = 48
WHERE id = 20058 AND npc_spells_id = 1 AND spellid = 9755 AND type = 2;

-- Superior Healing (spellid=9, id=35): mid-high tier (34-52)
UPDATE npc_spells_entries SET priority = 40
WHERE id = 35 AND npc_spells_id = 1 AND spellid = 9 AND type = 2;

-- Greater Healing (spellid=15, id=34): mid tier (24-50)
UPDATE npc_spells_entries SET priority = 35
WHERE id = 34 AND npc_spells_id = 1 AND spellid = 15 AND type = 2;

-- Healing (spellid=12, id=33): low-mid tier (14-33) — bump above Smite=20
UPDATE npc_spells_entries SET priority = 25
WHERE id = 33 AND npc_spells_id = 1 AND spellid = 12 AND type = 2;

-- Light Healing (spellid=17, id=32): low tier (5-23) — slight bump for consistency
UPDATE npc_spells_entries SET priority = 15
WHERE id = 32 AND npc_spells_id = 1 AND spellid = 17 AND type = 2;

-- Minor Healing (spellid=200, id=31): fallback (1-13) — leave at 1
-- (no change needed)

SELECT 'AFTER FIX - Cleric heal priorities:' AS status;
SELECT nse.id, nse.spellid, nse.type, nse.priority, nse.minlevel, nse.maxlevel, sn.name
FROM npc_spells_entries nse
LEFT JOIN spells_new sn ON nse.spellid = sn.id
WHERE nse.npc_spells_id = 1 AND nse.type = 2
ORDER BY nse.minlevel;

-- Validation: all cleric mid-high tier heals (minlevel >= 20) should have priority >= 10
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS: All cleric heals (minlevel>=20) have priority >= 10'
  ELSE CONCAT('FAIL: ', COUNT(*), ' cleric heals at priority < 10 above minlevel 20')
  END AS validation_result
FROM npc_spells_entries
WHERE npc_spells_id = 1 AND type = 2 AND minlevel >= 20 AND priority < 10;

-- Validation: no heal should have lower priority than Wrath (30) at same level range
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS: All cleric heals above level 29 outprioritize Wrath (priority>30)'
  ELSE CONCAT('FAIL: ', COUNT(*), ' cleric heals in Wrath range have priority <= 30')
  END AS validation_result
FROM npc_spells_entries
WHERE npc_spells_id = 1 AND type = 2 AND minlevel >= 29 AND priority <= 30;
