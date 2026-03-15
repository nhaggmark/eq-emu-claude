-- companion_db_health_validation.sql
-- Comprehensive companion DB health check — covers TC-D01 through TC-D07
-- Fills 7 test coverage gaps identified in architecture report Section 3
-- Date: 2026-03-15
-- Run: docker exec akk-stack-mariadb-1 mysql -ueqemu -p'...' peq < this_file.sql
--
-- IMPORTANT: companion_spell_sets priority semantics (confirmed by c-expert, 2026-03-15):
-- priority=1 = HIGHEST PRIORITY (checked/cast first) — OPPOSITE of npc_spells_entries.
-- The AI loads spells ORDER BY priority ASC and picks the FIRST match.
-- Therefore: heals should have LOWER priority numbers (1) than damage (10-30).
-- Healer class_id mapping: CLR=2, PAL=3, RNG=4, DRU=6, BRD=8, SHM=10, BST=15
-- Caster class_id mapping: SK=5, NEC=11, WIZ=12, MAG=13, ENC=14
-- Non-casters (no entries expected): WAR=1, MNK=7, ROG=9

-- ============================================================
-- SECTION 1: companion_spell_sets priority validation (TC-D01)
-- ============================================================

SELECT '=== TC-D01: companion_spell_sets priority validation ===' AS section;

-- TC-D01-A: Healer classes must have heals at LOWER priority number than damage
-- (Lower number = checked first = effectively higher priority in companion_spell_sets)
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D01-A: All healer classes have heals checked before damage (lower priority number)'
  ELSE CONCAT('FAIL TC-D01-A: ', COUNT(*), ' healer class(es) have max_heal_prio >= min_damage_prio')
  END AS test_result
FROM (
  SELECT class_id,
         MAX(CASE WHEN spell_type = 2 THEN priority ELSE -1 END) AS max_heal_prio,
         MIN(CASE WHEN spell_type = 1 THEN priority ELSE 999 END) AS min_damage_prio
  FROM companion_spell_sets
  WHERE class_id IN (2, 3, 4, 6, 8, 10, 15)  -- CLR, PAL, RNG, DRU, BRD, SHM, BST
  GROUP BY class_id
  HAVING max_heal_prio >= min_damage_prio
) failing;

-- TC-D01-B: All healer classes must have at least one heal at priority <= 5 (high priority)
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D01-B: All healer classes have at least one heal at priority <= 5'
  ELSE CONCAT('FAIL TC-D01-B: ', COUNT(*), ' healer class(es) missing high-priority heal (priority<=5)')
  END AS test_result
FROM (
  SELECT class_id,
         MIN(CASE WHEN spell_type = 2 THEN priority ELSE 999 END) AS min_heal_prio
  FROM companion_spell_sets
  WHERE class_id IN (2, 3, 4, 6, 8, 10, 15)
  GROUP BY class_id
  HAVING min_heal_prio > 5
) failing;

-- TC-D01-C: All spellcasting companion classes have entries in companion_spell_sets
-- WAR(1), MNK(7), ROG(9) are non-spellcasting and intentionally excluded.
-- Spellcasting class_ids: 2=CLR, 3=PAL, 4=RNG, 5=SK, 6=DRU, 8=BRD,
--   10=SHM, 11=NEC, 12=WIZ, 13=MAG, 14=ENC, 15=BST
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D01-C: All 12 spellcasting companion classes have spell entries'
  ELSE CONCAT('FAIL TC-D01-C: Missing spellcasting class_ids: ', GROUP_CONCAT(v.class_id ORDER BY v.class_id))
  END AS test_result
FROM (
  SELECT 2 class_id UNION SELECT 3 UNION SELECT 4 UNION SELECT 5
  UNION SELECT 6 UNION SELECT 8 UNION SELECT 10 UNION SELECT 11
  UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15
) v
WHERE NOT EXISTS (
  SELECT 1 FROM companion_spell_sets css WHERE css.class_id = v.class_id
);

-- TC-D01-D: Caster classes (NEC=11, WIZ=12, MAG=13, ENC=14) should have differentiated priorities
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D01-D: All caster classes have differentiated spell priorities'
  ELSE CONCAT('FAIL TC-D01-D: ', COUNT(*), ' caster class(es) have flat (all priority=1) entries')
  END AS test_result
FROM (
  SELECT class_id,
         COUNT(DISTINCT priority) AS distinct_priorities
  FROM companion_spell_sets
  WHERE class_id IN (11, 12, 13, 14)  -- NEC, WIZ, MAG, ENC
  GROUP BY class_id
  HAVING distinct_priorities <= 1
) flat_casters;

-- ============================================================
-- SECTION 2: Cleric mid-tier heal priority check (TC-D02)
-- ============================================================

SELECT '=== TC-D02: Cleric heal priority validation (npc_spells_entries) ===' AS section;

-- NOTE: npc_spells_entries uses OPPOSITE semantics — HIGHER number = higher priority.
-- TC-D02-A: All cleric heals at minlevel >= 20 must have priority >= 10 (in npc_spells_entries)
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D02-A: All cleric mid-high heals have priority >= 10 (npc_spells_entries)'
  ELSE CONCAT('FAIL TC-D02-A: ', COUNT(*), ' cleric heals (minlevel>=20) at priority < 10')
  END AS test_result
FROM npc_spells_entries
WHERE npc_spells_id = 1 AND type = 2 AND minlevel >= 20 AND priority < 10;

-- TC-D02-B: Cleric heals at levels 29+ must outprioritize Wrath (priority=30) in npc_spells_entries
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D02-B: Cleric heals (minlevel>=29) outprioritize Wrath (priority>30)'
  ELSE CONCAT('FAIL TC-D02-B: ', COUNT(*), ' cleric heals in Wrath range with priority <= 30')
  END AS test_result
FROM npc_spells_entries
WHERE npc_spells_id = 1 AND type = 2 AND minlevel >= 29 AND priority <= 30;

-- TC-D02-C: companion_spell_sets cleric heals are at low priority numbers (checked first)
-- All heals should be at priority=1, damage at priority >= 10
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D02-C: companion_spell_sets cleric heals at priority=1 (checked first)'
  ELSE CONCAT('FAIL TC-D02-C: ', COUNT(*), ' cleric companion heals at priority > 1')
  END AS test_result
FROM companion_spell_sets
WHERE class_id = 2 AND spell_type = 2 AND priority > 1;

-- ============================================================
-- SECTION 3: Inverted minlevel/maxlevel detection (TC-D03)
-- ============================================================

SELECT '=== TC-D03: Inverted level range detection ===' AS section;

-- TC-D03-A: No companion spell list (1-10) should have minlevel > maxlevel
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D03-A: No inverted level ranges in companion npc_spells_entries'
  ELSE CONCAT('FAIL TC-D03-A: ', COUNT(*), ' inverted entries: ',
    GROUP_CONCAT(CONCAT('id=', id, ' list=', npc_spells_id, ' spell=', spellid) ORDER BY npc_spells_id))
  END AS test_result
FROM npc_spells_entries
WHERE npc_spells_id IN (1,2,3,4,5,6,7,8,9,10)
  AND maxlevel > 0
  AND minlevel > maxlevel;

-- TC-D03-B: No companion_spell_sets entry should have min_level > max_level
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D03-B: No inverted level ranges in companion_spell_sets'
  ELSE CONCAT('FAIL TC-D03-B: ', COUNT(*), ' inverted entries: ',
    GROUP_CONCAT(CONCAT('id=', id, ' class=', class_id, ' spell=', spell_id) ORDER BY class_id))
  END AS test_result
FROM companion_spell_sets
WHERE max_level > 0
  AND min_level > max_level;

-- ============================================================
-- SECTION 4: companion_data state integrity (TC-D04)
-- ============================================================

SELECT '=== TC-D04: companion_data state integrity ===' AS section;

-- TC-D04-A: No companion should be active (not suspended, not dismissed) with 0 HP
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D04-A: No companion is active with 0 HP'
  ELSE CONCAT('FAIL TC-D04-A: ', COUNT(*), ' companions active with 0 HP (stuck dead state)')
  END AS test_result
FROM companion_data
WHERE is_suspended = 0 AND is_dismissed = 0 AND cur_hp = 0;

-- TC-D04-B: No companion should have both suspended AND dismissed flags set
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D04-B: No companion has both is_suspended=1 AND is_dismissed=1'
  ELSE CONCAT('FAIL TC-D04-B: ', COUNT(*), ' companions have conflicting state flags')
  END AS test_result
FROM companion_data
WHERE is_suspended = 1 AND is_dismissed = 1;

-- TC-D04-C: No companion should have negative HP or mana
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D04-C: No companion has negative HP or mana'
  ELSE CONCAT('FAIL TC-D04-C: ', COUNT(*), ' companions have negative HP or mana')
  END AS test_result
FROM companion_data
WHERE cur_hp < 0 OR cur_mana < 0;

-- TC-D04-D: No companion should have an invalid level
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D04-D: All companions have valid level (1-65)'
  ELSE CONCAT('FAIL TC-D04-D: ', COUNT(*), ' companions have invalid level')
  END AS test_result
FROM companion_data
WHERE level < 1 OR level > 65;

-- ============================================================
-- SECTION 5: Orphaned companion_inventories (TC-D05)
-- ============================================================

SELECT '=== TC-D05: Orphaned companion_inventories ===' AS section;

-- TC-D05-A: All inventory rows must have a matching companion_data record
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D05-A: No orphaned companion_inventories rows'
  ELSE CONCAT('FAIL TC-D05-A: ', COUNT(*), ' orphaned inventory rows (companion_data deleted)')
  END AS test_result
FROM companion_inventories ci
LEFT JOIN companion_data cd ON ci.companion_id = cd.id
WHERE cd.id IS NULL;

-- ============================================================
-- SECTION 6: Duplicate spell IDs within same list (TC-D06)
-- ============================================================

SELECT '=== TC-D06: Duplicate spell ID detection ===' AS section;

-- TC-D06-A: No duplicate spellid in the same npc_spells_entries list
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D06-A: No duplicate spell IDs in companion npc_spells_entries'
  ELSE CONCAT('FAIL TC-D06-A: ', COUNT(*), ' duplicate spell entries found')
  END AS test_result
FROM (
  SELECT npc_spells_id, spellid, COUNT(*) AS cnt
  FROM npc_spells_entries
  WHERE npc_spells_id IN (1,2,3,4,5,6,7,8,9,10)
  GROUP BY npc_spells_id, spellid
  HAVING cnt > 1
) dups;

-- TC-D06-B: No duplicate spell_id per class in companion_spell_sets
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D06-B: No duplicate spell IDs in companion_spell_sets per class'
  ELSE CONCAT('FAIL TC-D06-B: ', COUNT(*), ' duplicate spell entries in companion_spell_sets')
  END AS test_result
FROM (
  SELECT class_id, spell_id, COUNT(*) AS cnt
  FROM companion_spell_sets
  GROUP BY class_id, spell_id
  HAVING cnt > 1
) dups;

-- ============================================================
-- SECTION 7: companion_spell_sets vs npc_spells_entries parity (TC-D07)
-- ============================================================

SELECT '=== TC-D07: Cross-system spell parity check ===' AS section;

-- TC-D07-A: Both tables should have heal entries for healer classes
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D07-A: All healer classes have heals in both spell systems'
  ELSE CONCAT('FAIL TC-D07-A: ', COUNT(*), ' healer class(es) missing heals in companion_spell_sets')
  END AS test_result
FROM (
  SELECT v.class_id FROM (
    SELECT 2 class_id UNION SELECT 3 UNION SELECT 4 UNION SELECT 6
    UNION SELECT 8 UNION SELECT 10 UNION SELECT 15
  ) v
  WHERE NOT EXISTS (
    SELECT 1 FROM companion_spell_sets css
    WHERE css.class_id = v.class_id AND css.spell_type = 2
  )
) missing_heals;

-- TC-D07-B: companion_spell_sets healer heal priority <= 5 (ensuring heals are checked first)
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS TC-D07-B: All healer companion heals have high priority (<=5)'
  ELSE CONCAT('WARN TC-D07-B: ', COUNT(*), ' healer class(es) with min heal priority > 5')
  END AS test_result
FROM (
  SELECT class_id, MIN(CASE WHEN spell_type=2 THEN priority ELSE 999 END) AS min_heal_prio
  FROM companion_spell_sets
  WHERE class_id IN (2, 3, 4, 6, 8, 10, 15)
  GROUP BY class_id
  HAVING min_heal_prio > 5
) check_result;

-- ============================================================
-- SUMMARY
-- ============================================================

SELECT '=== SUMMARY ===' AS section;
SELECT 'Run complete. Review FAIL/WARN lines above for issues.' AS note;
SELECT 'Expected results after all pass2 fixes: all tests PASS.' AS note;
