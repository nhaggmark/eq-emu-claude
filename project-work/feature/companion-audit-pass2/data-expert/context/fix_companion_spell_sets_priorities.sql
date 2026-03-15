-- fix_companion_spell_sets_priorities.sql
-- Part 1: Apply correct priority differentiation to ALL classes in companion_spell_sets
--
-- CRITICAL SEMANTICS (confirmed by c-expert, 2026-03-15):
-- companion_spell_sets uses priority=1 = HIGHEST PRIORITY (checked/cast first).
-- This is OPPOSITE of npc_spells_entries (where higher number = higher priority).
-- The AI loads spells ORDER BY priority ASC and picks the FIRST match.
--
-- Priority scheme applied:
--   1 = Heals (type=2), lifetaps (type=64), mez (type=2048), pet summons (type=32)
--   2 = Dispels/cures (type=512)
--   5 = Snare/root (type=4, type=128), slow (type=4096)
--   10 = Buffs (type=8), rune/shield (type=8192)
--   15 = Secondary slow (type=4096 when already at higher priority)
--   20 = DoTs (type=256)
--   30 = Direct damage/nukes (type=1)
--
-- class_id mapping in companion_spell_sets:
--   2=CLR, 3=PAL, 4=RNG, 5=SK, 6=DRU, 8=BRD, 10=SHM,
--   11=NEC, 12=WIZ, 13=MAG, 14=ENC, 15=BST
--
-- Date: 2026-03-15

-- CLR (class_id=2): heals are at 1 (correct). Offensive was at 1 (wrong). Fix offensive only.
UPDATE companion_spell_sets SET priority=30 WHERE class_id=2 AND spell_type=1 AND priority=1;
-- Note: existing Furor=10, Smite=20, Wrath=30 preserved (already correct)

-- PAL (class_id=3): heals stay at 1. Fix damage/utility.
UPDATE companion_spell_sets SET priority=30 WHERE class_id=3 AND spell_type=1 AND priority=1;
UPDATE companion_spell_sets SET priority=2  WHERE class_id=3 AND spell_type=512 AND priority=1;
UPDATE companion_spell_sets SET priority=5  WHERE class_id=3 AND spell_type=4 AND priority=1;
UPDATE companion_spell_sets SET priority=10 WHERE class_id=3 AND spell_type=8 AND priority=1;

-- RNG (class_id=4): heals stay at 1. Fix damage/utility.
UPDATE companion_spell_sets SET priority=30 WHERE class_id=4 AND spell_type=1 AND priority=1;
UPDATE companion_spell_sets SET priority=20 WHERE class_id=4 AND spell_type=256 AND priority=1;
UPDATE companion_spell_sets SET priority=5  WHERE class_id=4 AND spell_type=4 AND priority=1;
UPDATE companion_spell_sets SET priority=5  WHERE class_id=4 AND spell_type=128 AND priority=1;
UPDATE companion_spell_sets SET priority=10 WHERE class_id=4 AND spell_type=8 AND priority=1;
UPDATE companion_spell_sets SET priority=2  WHERE class_id=4 AND spell_type=512 AND priority=1;

-- SK (class_id=5): lifetaps (type=64) stay at 1 as primary combat tool. Fix other types.
UPDATE companion_spell_sets SET priority=30 WHERE class_id=5 AND spell_type=1 AND priority=1;
UPDATE companion_spell_sets SET priority=10 WHERE class_id=5 AND spell_type=8 AND priority=1;
UPDATE companion_spell_sets SET priority=5  WHERE class_id=5 AND spell_type=4 AND priority=1;
UPDATE companion_spell_sets SET priority=2  WHERE class_id=5 AND spell_type=512 AND priority=1;

-- DRU (class_id=6): heals stay at 1. Fix damage/utility.
UPDATE companion_spell_sets SET priority=30 WHERE class_id=6 AND spell_type=1 AND priority=1;
UPDATE companion_spell_sets SET priority=20 WHERE class_id=6 AND spell_type=256 AND priority=1;
UPDATE companion_spell_sets SET priority=5  WHERE class_id=6 AND spell_type=4 AND priority=1;
UPDATE companion_spell_sets SET priority=5  WHERE class_id=6 AND spell_type=128 AND priority=1;
UPDATE companion_spell_sets SET priority=10 WHERE class_id=6 AND spell_type=8 AND priority=1;
UPDATE companion_spell_sets SET priority=2  WHERE class_id=6 AND spell_type=512 AND priority=1;

-- BRD (class_id=8): heals stay at 1. Fix damage/utility.
UPDATE companion_spell_sets SET priority=30 WHERE class_id=8 AND spell_type=1 AND priority=1;
UPDATE companion_spell_sets SET priority=20 WHERE class_id=8 AND spell_type=256 AND priority=1;
UPDATE companion_spell_sets SET priority=5  WHERE class_id=8 AND spell_type=128 AND priority=1;
UPDATE companion_spell_sets SET priority=10 WHERE class_id=8 AND spell_type=8 AND priority=1;

-- SHM (class_id=10): heals stay at 1. Fix damage/utility.
UPDATE companion_spell_sets SET priority=30 WHERE class_id=10 AND spell_type=1 AND priority=1;
UPDATE companion_spell_sets SET priority=20 WHERE class_id=10 AND spell_type=256 AND priority=1;
UPDATE companion_spell_sets SET priority=5  WHERE class_id=10 AND spell_type=4 AND priority=1;
UPDATE companion_spell_sets SET priority=5  WHERE class_id=10 AND spell_type=128 AND priority=1;
UPDATE companion_spell_sets SET priority=10 WHERE class_id=10 AND spell_type=8 AND priority=1;
UPDATE companion_spell_sets SET priority=2  WHERE class_id=10 AND spell_type=512 AND priority=1;

-- NEC (class_id=11): pets (type=32) and lifetaps (type=64) stay at 1. Fix others.
UPDATE companion_spell_sets SET priority=20 WHERE class_id=11 AND spell_type=256 AND priority=1;
UPDATE companion_spell_sets SET priority=30 WHERE class_id=11 AND spell_type=1 AND priority=1;
UPDATE companion_spell_sets SET priority=10 WHERE class_id=11 AND spell_type=8 AND priority=1;

-- WIZ (class_id=12): already had 24 distinct priorities. Bump buffs.
UPDATE companion_spell_sets SET priority=20 WHERE class_id=12 AND spell_type=8 AND priority=1;

-- MAG (class_id=13): pets (type=32) and pet haste (type=16384) stay at 1. Fix damage/buffs.
UPDATE companion_spell_sets SET priority=30 WHERE class_id=13 AND spell_type=1 AND priority=1;
UPDATE companion_spell_sets SET priority=20 WHERE class_id=13 AND spell_type=256 AND priority=1;
UPDATE companion_spell_sets SET priority=10 WHERE class_id=13 AND spell_type=8 AND priority=1;
UPDATE companion_spell_sets SET priority=5  WHERE class_id=13 AND spell_type=512 AND priority=1;

-- ENC (class_id=14): mez (type=2048) stays at 1 as primary combat tool.
UPDATE companion_spell_sets SET priority=30 WHERE class_id=14 AND spell_type=1 AND priority=1;
UPDATE companion_spell_sets SET priority=20 WHERE class_id=14 AND spell_type=256 AND priority=1;
UPDATE companion_spell_sets SET priority=15 WHERE class_id=14 AND spell_type=4096 AND priority=1;
UPDATE companion_spell_sets SET priority=10 WHERE class_id=14 AND spell_type=8 AND priority=1;
UPDATE companion_spell_sets SET priority=10 WHERE class_id=14 AND spell_type=8192 AND priority=1;
UPDATE companion_spell_sets SET priority=5  WHERE class_id=14 AND spell_type=512 AND priority=1;
UPDATE companion_spell_sets SET priority=5  WHERE class_id=14 AND spell_type=4 AND priority=1;

-- BST (class_id=15): heals stay at 1. Fix damage/utility.
UPDATE companion_spell_sets SET priority=30 WHERE class_id=15 AND spell_type=1 AND priority=1;
UPDATE companion_spell_sets SET priority=20 WHERE class_id=15 AND spell_type=256 AND priority=1;
UPDATE companion_spell_sets SET priority=10 WHERE class_id=15 AND spell_type=8 AND priority=1;
UPDATE companion_spell_sets SET priority=2  WHERE class_id=15 AND spell_type=512 AND priority=1;

-- Validation: all healer classes have heals (priority=1) checked before damage (priority>=10)
SELECT CASE
  WHEN COUNT(*)=0 THEN 'PASS: All healer classes have heals checked before damage'
  ELSE CONCAT('FAIL: ', COUNT(*), ' healer class(es) with heal priority >= damage priority')
  END AS validation_result
FROM (
  SELECT class_id,
    MAX(CASE WHEN spell_type=2 THEN priority ELSE -1 END) AS max_heal_prio,
    MIN(CASE WHEN spell_type=1 THEN priority ELSE 999 END) AS min_damage_prio
  FROM companion_spell_sets WHERE class_id IN (2,3,4,6,8,10,15)
  GROUP BY class_id HAVING max_heal_prio >= min_damage_prio
) f;

-- Validation: all caster classes have differentiated priorities
SELECT CASE
  WHEN COUNT(*)=0 THEN 'PASS: All caster classes have differentiated priorities'
  ELSE CONCAT('FAIL: ', COUNT(*), ' caster class(es) with flat priorities')
  END AS validation_result
FROM (SELECT class_id FROM companion_spell_sets WHERE class_id IN (11,12,13,14)
  GROUP BY class_id HAVING COUNT(DISTINCT priority)<=1) f;
