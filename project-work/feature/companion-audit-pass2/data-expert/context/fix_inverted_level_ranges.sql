-- fix_inverted_level_ranges.sql
-- NEW-04: Fix 4 inverted minlevel/maxlevel entries in npc_spells_entries
-- These entries have minlevel > maxlevel, making them inaccessible at any level.
-- Date: 2026-03-15

-- Verify current state before applying fixes
SELECT 'BEFORE FIX - Inverted level ranges:' AS status;
SELECT nse.id, nse.npc_spells_id, nse.spellid, nse.type, nse.priority, nse.minlevel, nse.maxlevel,
       sn.name AS spell_name
FROM npc_spells_entries nse
LEFT JOIN spells_new sn ON nse.spellid = sn.id
WHERE nse.npc_spells_id IN (1,2,3,4,5,6,7,8,9,10)
  AND nse.maxlevel > 0
  AND nse.minlevel > nse.maxlevel
ORDER BY nse.npc_spells_id;

-- FIX 1: Wizard list (id=2), Resistant Armor (spellid=3326)
-- Current: minlevel=61, maxlevel=57 (wizard gets this spell at level 61; swap gives 57-61)
-- Fix: minlevel=57, maxlevel=65 (accessible through end of era)
UPDATE npc_spells_entries
SET minlevel = 57, maxlevel = 65
WHERE id = 176
  AND npc_spells_id = 2
  AND spellid = 3326
  AND minlevel = 61
  AND maxlevel = 57;

-- FIX 2: Shaman list (id=6), Talisman of Kragg (spellid=1585)
-- Current: minlevel=55, maxlevel=9 (shaman gets this spell at level 55; maxlevel=9 is clearly wrong)
-- Fix: minlevel=55, maxlevel=65 (accessible from level 55 through end of era)
UPDATE npc_spells_entries
SET minlevel = 55, maxlevel = 65
WHERE id = 602
  AND npc_spells_id = 6
  AND spellid = 1585
  AND minlevel = 55
  AND maxlevel = 9;

-- FIX 3: Druid list (id=7), Creeping Crud (spellid=99)
-- Current: minlevel=24, maxlevel=23 (values swapped; DoT fills 24-28 window before Immolate at 29)
-- Fix: minlevel=24, maxlevel=28 (covers the gap between Stinging Swarm (14-23) and Immolate (29-51))
UPDATE npc_spells_entries
SET minlevel = 24, maxlevel = 28
WHERE id = 695
  AND npc_spells_id = 7
  AND spellid = 99
  AND minlevel = 24
  AND maxlevel = 23;

-- FIX 4: Paladin list (id=8), Touch of Nife (spellid=3429)
-- Current: minlevel=61, maxlevel=52 (highest-priority paladin heal, inaccessible at 52-61)
-- Fix: minlevel=52, maxlevel=65 (accessible from level 52 through end of era)
UPDATE npc_spells_entries
SET minlevel = 52, maxlevel = 65
WHERE id = 822
  AND npc_spells_id = 8
  AND spellid = 3429
  AND minlevel = 61
  AND maxlevel = 52;

-- Verify all 4 entries are now fixed
SELECT 'AFTER FIX - All entries should have minlevel <= maxlevel:' AS status;
SELECT nse.id, nse.npc_spells_id, nse.spellid, nse.type, nse.priority, nse.minlevel, nse.maxlevel,
       sn.name AS spell_name
FROM npc_spells_entries nse
LEFT JOIN spells_new sn ON nse.spellid = sn.id
WHERE nse.id IN (176, 602, 695, 822)
ORDER BY nse.npc_spells_id;

-- Confirm no remaining inversions in companion lists
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS: No inverted level ranges remain in companion spell lists'
  ELSE CONCAT('FAIL: ', COUNT(*), ' inverted entries remain')
  END AS validation_result
FROM npc_spells_entries
WHERE npc_spells_id IN (1,2,3,4,5,6,7,8,9,10)
  AND maxlevel > 0
  AND minlevel > maxlevel;
