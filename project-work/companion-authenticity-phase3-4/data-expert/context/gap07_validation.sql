-- GAP-07 Validation Script
-- Verifies caster class spell list priority fixes were applied correctly
-- Feature: companion-authenticity-phase3-4
-- Date: 2026-03-15
--
-- Run via:
--   docker exec -i akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq \
--     --skip-column-names < gap07_validation.sql

-- ============================================================
-- MAGICIAN (ID 4) TESTS
-- ============================================================

-- Test M1: Magician has multiple distinct priorities (was all 1)
SELECT
  CASE WHEN COUNT(DISTINCT priority) >= 8 THEN 'PASS' ELSE 'FAIL' END AS result,
  'M1: Magician has >= 8 distinct priorities' AS test,
  COUNT(DISTINCT priority) AS distinct_priorities
FROM npc_spells_entries WHERE npc_spells_id = 4;

-- Test M2: Magician top-tier nukes are highest priority
SELECT
  CASE WHEN MIN(priority) >= 14 THEN 'PASS' ELSE 'FAIL' END AS result,
  'M2: Magician top-tier nukes (Sun Storm, Black Steel, etc.) priority >= 14' AS test,
  MIN(priority) AS min_priority
FROM npc_spells_entries
WHERE npc_spells_id = 4 AND spellid IN (3319, 3321, 3323, 3325);

-- Test M3: Magician low-tier nukes are lower priority than high-tier
SELECT
  CASE WHEN max_high > max_low THEN 'PASS' ELSE 'FAIL' END AS result,
  'M3: Magician high-tier nukes have higher priority than low-tier nukes' AS test,
  max_high, max_low
FROM (
  SELECT
    MAX(CASE WHEN spellid IN (3319, 3321, 3323, 3325) THEN priority ELSE 0 END) AS max_high,
    MAX(CASE WHEN spellid IN (93, 94) THEN priority ELSE 0 END) AS max_low
  FROM npc_spells_entries WHERE npc_spells_id = 4
) t;

-- Test M4: Magician Malo debuffs have meaningful priority
SELECT
  CASE WHEN MIN(priority) >= 8 THEN 'PASS' ELSE 'FAIL' END AS result,
  'M4: Magician Malo debuffs priority >= 8' AS test,
  MIN(priority) AS min_priority
FROM npc_spells_entries
WHERE npc_spells_id = 4 AND spellid IN (110, 111, 112, 1577, 3387, 1772);

-- Test M5: Magician buffs remain at priority=1
SELECT
  CASE WHEN SUM(CASE WHEN priority != 1 THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
  'M5: Magician buffs (type=8) all remain at priority=1' AS test,
  SUM(CASE WHEN priority != 1 THEN 1 ELSE 0 END) AS not_at_1
FROM npc_spells_entries WHERE npc_spells_id = 4 AND type = 8;

-- ============================================================
-- ENCHANTER (ID 5) TESTS
-- ============================================================

-- Test E1: Enchanter mez is highest-priority spell type
SELECT
  CASE WHEN mez_max >= 18 AND mez_max > charm_max AND mez_max > debuff_max THEN 'PASS' ELSE 'FAIL' END AS result,
  'E1: Enchanter mez (type=2048) is highest-priority type' AS test,
  mez_max, charm_max, debuff_max
FROM (
  SELECT
    MAX(CASE WHEN type = 2048 THEN priority ELSE 0 END) AS mez_max,
    MAX(CASE WHEN type = 4096 AND spellid != 3355 THEN priority ELSE 0 END) AS charm_max,
    MAX(CASE WHEN type = 1 AND spellid IN (676,677,678,1702,1704,3342,1592) THEN priority ELSE 0 END) AS debuff_max
  FROM npc_spells_entries WHERE npc_spells_id = 5
) t;

-- Test E2: All Enchanter mez spells are at priority >= 18
SELECT
  CASE WHEN MIN(priority) >= 18 THEN 'PASS' ELSE 'FAIL' END AS result,
  'E2: All Enchanter mez spells (type=2048) at priority >= 18' AS test,
  MIN(priority) AS min_mez_priority,
  COUNT(*) AS mez_spell_count
FROM npc_spells_entries WHERE npc_spells_id = 5 AND type = 2048;

-- Test E3: Enchanter charm > debuffs in priority
SELECT
  CASE WHEN charm_max > debuff_max THEN 'PASS' ELSE 'FAIL' END AS result,
  'E3: Enchanter charm priority > Tash debuff priority' AS test,
  charm_max, debuff_max
FROM (
  SELECT
    MAX(CASE WHEN type = 4096 AND spellid != 3355 THEN priority ELSE 0 END) AS charm_max,
    MAX(CASE WHEN spellid IN (676,677,678,1702,1704,3342,1592) THEN priority ELSE 0 END) AS debuff_max
  FROM npc_spells_entries WHERE npc_spells_id = 5
) t;

-- Test E4: Enchanter Gravity Flux and Command of Druzzil priority unchanged (15)
SELECT
  CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END AS result,
  'E4: Enchanter Gravity Flux and Command of Druzzil still at priority=15' AS test,
  COUNT(*) AS at_15
FROM npc_spells_entries
WHERE npc_spells_id = 5 AND spellid IN (73, 3355) AND priority = 15;

-- ============================================================
-- PALADIN (ID 8) TESTS
-- ============================================================

-- Test P1: Paladin heals are highest priority
SELECT
  CASE WHEN heal_max >= 20 AND heal_max > stun_max AND heal_max > buff_max THEN 'PASS' ELSE 'FAIL' END AS result,
  'P1: Paladin heals (type=2) are highest priority' AS test,
  heal_max, stun_max, buff_max
FROM (
  SELECT
    MAX(CASE WHEN type = 2 THEN priority ELSE 0 END) AS heal_max,
    MAX(CASE WHEN type = 1 AND spellid IN (123,124,2587,3245) THEN priority ELSE 0 END) AS stun_max,
    MAX(CASE WHEN type = 8 THEN priority ELSE 0 END) AS buff_max
  FROM npc_spells_entries WHERE npc_spells_id = 8
) t;

-- Test P2: All Paladin heals at priority >= 15
SELECT
  CASE WHEN MIN(priority) >= 15 THEN 'PASS' ELSE 'FAIL' END AS result,
  'P2: All Paladin heals (type=2) at priority >= 15' AS test,
  MIN(priority) AS min_heal_priority
FROM npc_spells_entries WHERE npc_spells_id = 8 AND type = 2;

-- Test P3: Paladin stuns have higher priority than DD nuke
SELECT
  CASE WHEN stun_p > nuke_p THEN 'PASS' ELSE 'FAIL' END AS result,
  'P3: Paladin stuns have higher priority than DD nuke' AS test,
  stun_p, nuke_p
FROM (
  SELECT
    MAX(CASE WHEN spellid IN (123,124,2587,3245) THEN priority ELSE 0 END) AS stun_p,
    MAX(CASE WHEN spellid = 1454 THEN priority ELSE 0 END) AS nuke_p
  FROM npc_spells_entries WHERE npc_spells_id = 8
) t;

-- Test P4: Paladin buffs remain at priority=1
SELECT
  CASE WHEN SUM(CASE WHEN priority != 1 THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
  'P4: Paladin buffs (type=8) all remain at priority=1' AS test
FROM npc_spells_entries WHERE npc_spells_id = 8 AND type = 8;

-- ============================================================
-- SHADOW KNIGHT (ID 9) TESTS
-- ============================================================

-- Test S1: SK lifetaps are highest priority
SELECT
  CASE WHEN tap_max >= 20 AND tap_max > snare_max AND tap_max > dot_max THEN 'PASS' ELSE 'FAIL' END AS result,
  'S1: SK lifetaps (type=64) are highest priority' AS test,
  tap_max, snare_max, dot_max
FROM (
  SELECT
    MAX(CASE WHEN type = 64 THEN priority ELSE 0 END) AS tap_max,
    MAX(CASE WHEN type = 128 THEN priority ELSE 0 END) AS snare_max,
    MAX(CASE WHEN type = 256 THEN priority ELSE 0 END) AS dot_max
  FROM npc_spells_entries WHERE npc_spells_id = 9
) t;

-- Test S2: All SK lifetaps at priority >= 18
SELECT
  CASE WHEN MIN(priority) >= 18 THEN 'PASS' ELSE 'FAIL' END AS result,
  'S2: All SK lifetaps (type=64) at priority >= 18' AS test,
  MIN(priority) AS min_tap_priority,
  COUNT(*) AS tap_spell_count
FROM npc_spells_entries WHERE npc_spells_id = 9 AND type = 64;

-- Test S3: SK priority chain: lifetap > snare > DoT > debuff
SELECT
  CASE WHEN tap > snare AND snare > dot AND dot > debuff THEN 'PASS' ELSE 'FAIL' END AS result,
  'S3: SK hierarchy: lifetap > snare > DoT > STR debuff' AS test,
  tap, snare, dot, debuff
FROM (
  SELECT
    MAX(CASE WHEN type = 64 THEN priority ELSE 0 END) AS tap,
    MAX(CASE WHEN type = 128 THEN priority ELSE 0 END) AS snare,
    MAX(CASE WHEN type = 256 THEN priority ELSE 0 END) AS dot,
    MAX(CASE WHEN type = 1 AND spellid IN (2571,343,2572,370,1457,1458,2575,2577,2578,2579,3403) THEN priority ELSE 0 END) AS debuff
  FROM npc_spells_entries WHERE npc_spells_id = 9
) t;

-- Test S4: SK buffs remain at priority=1
SELECT
  CASE WHEN SUM(CASE WHEN priority != 1 THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
  'S4: SK buffs (type=8) all remain at priority=1' AS test
FROM npc_spells_entries WHERE npc_spells_id = 9 AND type = 8;

-- ============================================================
-- REGRESSION: Wizard and Necromancer Unchanged
-- ============================================================

-- Test R1: Wizard (ID 2) still has >= 20 distinct priorities (unchanged)
SELECT
  CASE WHEN COUNT(DISTINCT priority) >= 20 THEN 'PASS' ELSE 'FAIL' END AS result,
  'R1: Wizard (ID 2) unchanged — still has >= 20 distinct priorities' AS test,
  COUNT(DISTINCT priority) AS distinct_priorities
FROM npc_spells_entries WHERE npc_spells_id = 2;

-- Test R2: Necromancer (ID 3) still has >= 20 distinct priorities (unchanged)
SELECT
  CASE WHEN COUNT(DISTINCT priority) >= 20 THEN 'PASS' ELSE 'FAIL' END AS result,
  'R2: Necromancer (ID 3) unchanged — still has >= 20 distinct priorities' AS test,
  COUNT(DISTINCT priority) AS distinct_priorities
FROM npc_spells_entries WHERE npc_spells_id = 3;
