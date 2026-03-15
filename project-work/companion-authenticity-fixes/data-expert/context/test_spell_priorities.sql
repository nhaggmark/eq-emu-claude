-- =============================================================
-- test_spell_priorities.sql
-- Validates spell priority changes from GAP-05 (companion-authenticity-fixes)
-- Feature branch: feature/companion-authenticity-fixes
-- Date: 2026-03-14
--
-- Run via:
--   docker exec -i akk-stack-mariadb-1 mysql -ueqemu \
--     -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq \
--     < /path/to/test_spell_priorities.sql
--
-- Each test outputs a single PASS or FAIL line.
-- FAIL lines include diagnostic detail.
-- =============================================================

-- Suppress column headers for clean output
SET SESSION sql_mode = '';

-- =============================================================
-- TEST 1: Shaman heals prioritized (all type=2 in list 6 >= 15)
-- Expected: All 9 shaman heal spells at priority 20
-- =============================================================
SELECT
  CASE
    WHEN COUNT(*) = 0 THEN 'PASS: Shaman heals all priority >= 15'
    ELSE CONCAT('FAIL: Shaman list has ', COUNT(*), ' heal spell(s) below priority 15')
  END AS test_result
FROM npc_spells_entries
WHERE npc_spells_id = 6
  AND type = 2
  AND priority < 15;

-- =============================================================
-- TEST 2: Shaman damage deprioritized (max DD/DoT priority < max heal priority)
-- DD nukes (type=1 effectid1=0) are at priority 5, heals at 20
-- Slows (type=1 effectid1=10) are at priority 10 -- critical utility, still < heals
-- =============================================================
SELECT
  CASE
    WHEN MAX(CASE WHEN type = 2 THEN priority ELSE 0 END) >
         MAX(CASE WHEN type IN (1, 256) AND priority NOT IN (10, 8) THEN priority ELSE 0 END)
    THEN 'PASS: Shaman heal priority > Shaman damage priority'
    ELSE CONCAT(
      'FAIL: Shaman heals max=',
      MAX(CASE WHEN type = 2 THEN priority ELSE 0 END),
      ' not > damage max=',
      MAX(CASE WHEN type IN (1, 256) THEN priority ELSE 0 END)
    )
  END AS test_result
FROM npc_spells_entries
WHERE npc_spells_id = 6;

-- =============================================================
-- TEST 3: Shaman slows/debuffs have mid-priority (between nukes and heals)
-- Slows at priority 10, disease debuffs at priority 8
-- Must be > DD nukes (5) and < heals (20)
-- =============================================================
SELECT
  CASE
    WHEN SUM(CASE WHEN spellid IN (
      505, 270, 3380, 506, 507, 1589, 1588, 281, 163, 162,
      110, 111, 1578, 3395, 112, 3387, 1577, 1592
    ) AND priority > 5 AND priority < 20 THEN 1 ELSE 0 END) = 18
    THEN 'PASS: Shaman slows/debuffs all have mid-priority (5 < priority < 20)'
    ELSE CONCAT(
      'FAIL: Expected 18 shaman slow/debuff spells with mid-priority, found ',
      SUM(CASE WHEN spellid IN (
        505, 270, 3380, 506, 507, 1589, 1588, 281, 163, 162,
        110, 111, 1578, 3395, 112, 3387, 1577, 1592
      ) AND priority > 5 AND priority < 20 THEN 1 ELSE 0 END)
    )
  END AS test_result
FROM npc_spells_entries
WHERE npc_spells_id = 6;

-- =============================================================
-- TEST 4: Druid heals prioritized (all type=2 in list 7 >= 10)
-- Expected: All 11 druid heal spells at priority 15
-- =============================================================
SELECT
  CASE
    WHEN COUNT(*) = 0 THEN 'PASS: Druid heals all priority >= 10'
    ELSE CONCAT('FAIL: Druid list has ', COUNT(*), ' heal spell(s) below priority 10')
  END AS test_result
FROM npc_spells_entries
WHERE npc_spells_id = 7
  AND type = 2
  AND priority < 10;

-- =============================================================
-- TEST 5: Druid damage deprioritized (DD nukes and DoTs below heals)
-- DD nukes (type=1) at priority 5, DoTs (type=256) at priority 7, heals at 15
-- =============================================================
SELECT
  CASE
    WHEN MAX(CASE WHEN type = 2 THEN priority ELSE 0 END) >
         MAX(CASE WHEN type IN (1, 256) THEN priority ELSE 0 END)
    THEN 'PASS: Druid heal priority > Druid damage priority'
    ELSE CONCAT(
      'FAIL: Druid heals max=',
      MAX(CASE WHEN type = 2 THEN priority ELSE 0 END),
      ' not > damage max=',
      MAX(CASE WHEN type IN (1, 256) THEN priority ELSE 0 END)
    )
  END AS test_result
FROM npc_spells_entries
WHERE npc_spells_id = 7;

-- =============================================================
-- TEST 6: Ranger heals prioritized (all type=2 in list 10 >= 5)
-- Expected: All 6 ranger heal spells at priority 8
-- =============================================================
SELECT
  CASE
    WHEN COUNT(*) = 0 THEN 'PASS: Ranger heals all priority >= 5'
    ELSE CONCAT('FAIL: Ranger list has ', COUNT(*), ' heal spell(s) below priority 5')
  END AS test_result
FROM npc_spells_entries
WHERE npc_spells_id = 10
  AND type = 2
  AND priority < 5;

-- =============================================================
-- TEST 7: Cleric baseline unchanged
-- spellid=12 (Complete Heal) should still be at priority 20
-- spellid=17 (Celestial Healing) should still be at priority 10
-- =============================================================
SELECT
  CASE
    WHEN SUM(CASE WHEN spellid = 12 AND priority = 20 THEN 1 ELSE 0 END) = 1
     AND SUM(CASE WHEN spellid = 17 AND priority = 10 THEN 1 ELSE 0 END) = 1
    THEN 'PASS: Cleric baseline heals unchanged (CH=20, Celestial=10)'
    ELSE CONCAT(
      'FAIL: Cleric baseline changed -- CH priority=',
      MAX(CASE WHEN spellid = 12 THEN priority ELSE NULL END),
      ', Celestial priority=',
      MAX(CASE WHEN spellid = 17 THEN priority ELSE NULL END)
    )
  END AS test_result
FROM npc_spells_entries
WHERE npc_spells_id = 1
  AND spellid IN (12, 17);

-- =============================================================
-- TEST 8: No healer list (6, 7, 10) has heals stuck at priority=1
-- Lists 6/7/10 all had this problem before GAP-05; confirming it's fixed.
-- Note: Cleric list (1) intentionally has some heals at priority=1 (lower-tier
--       heals cast when CH/high-priority heals are on cooldown) -- not checked here.
-- =============================================================
SELECT
  CASE
    WHEN COUNT(*) = 0 THEN 'PASS: No healer list (6, 7, 10) has heals at priority=1'
    ELSE CONCAT(
      'FAIL: Found ', COUNT(*), ' heal spell(s) at priority=1 in lists 6/7/10: ',
      GROUP_CONCAT(CONCAT('list=', npc_spells_id, ' spellid=', spellid) ORDER BY npc_spells_id)
    )
  END AS test_result
FROM npc_spells_entries
WHERE npc_spells_id IN (6, 7, 10)
  AND type = 2
  AND priority = 1;

-- =============================================================
-- TEST 9: Priority hierarchy for changed lists (6, 7, 10)
-- For each list: max(heal priority) > max(damage priority) > max(utility priority)
-- Checked per list -- generates a row per list with PASS/FAIL
-- Note: Cleric list (1) is excluded; it has DD nukes at priority 30 > heals at 20,
--       which is intentional legacy behavior not touched by GAP-05.
-- =============================================================
SELECT
  CASE
    WHEN max_heal > max_damage AND max_damage > max_utility
    THEN CONCAT('PASS: List ', npc_spells_id, ' hierarchy: heal(', max_heal, ') > damage(', max_damage, ') > utility(', max_utility, ')')
    ELSE CONCAT('FAIL: List ', npc_spells_id, ' hierarchy broken: heal(', max_heal, ') damage(', max_damage, ') utility(', max_utility, ')')
  END AS test_result
FROM (
  SELECT
    npc_spells_id,
    MAX(CASE WHEN type = 2 THEN priority ELSE 0 END) AS max_heal,
    MAX(CASE WHEN type IN (1, 256) THEN priority ELSE 0 END) AS max_damage,
    MAX(CASE WHEN type IN (4, 8, 128, 512) THEN priority ELSE 0 END) AS max_utility
  FROM npc_spells_entries
  WHERE npc_spells_id IN (6, 7, 10)
  GROUP BY npc_spells_id
) AS priorities
ORDER BY npc_spells_id;
