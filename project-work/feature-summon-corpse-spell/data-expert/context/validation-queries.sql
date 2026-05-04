-- Universal Summon Corpse Spell — Validation Queries
-- Run after applying feature_summon_corpse_spell.sql migration.
-- Expected results noted in comments.

-- ============================================================
-- 1. Spells: All 12 new spells present with correct IDs and names
-- ============================================================
SELECT id, name, spell_category
FROM spells_new
WHERE id IN (1348,5093,9412,9413,9414,9415,9416,9417,9418,9419,9420,9421)
ORDER BY id;
-- Expected 12 rows:
-- 1348  Conjure Cadaver           221
-- 5093  Death's Recall            221
-- 9412  Divine Reclamation        221
-- 9413  Solemn Retrieval          221
-- 9414  Nature's Reclamation      221
-- 9415  Warden's Claim            221
-- 9416  Ancestral Summons         221
-- 9417  Ancestral Call            221
-- 9418  Spectral Translocation    221
-- 9419  Summon Mortal Remains     221
-- 9420  Phantasmal Reclamation    221
-- 9421  Dirge of Homecoming       221

-- ============================================================
-- 2. Spell mechanics: All 12 have correct cast params
-- ============================================================
SELECT id, name, cast_time, recovery_time, recast_time, mana,
       effectid1, effect_base_value1, targettype, buffduration,
       EndurTimerIndex, IsDiscipline, no_block
FROM spells_new
WHERE id IN (1348,5093,9412,9413,9414,9415,9416,9417,9418,9419,9420,9421)
ORDER BY id;
-- All rows must have:
--   cast_time=6000, recovery_time=2500, recast_time=180000, mana=0
--   effectid1=91, effect_base_value1=255, targettype=6
--   buffduration=65535, EndurTimerIndex=0, IsDiscipline=0, no_block=1

-- ============================================================
-- 3. Spell class restrictions: each spell allows exactly 1 class
-- ============================================================
SELECT id, name,
  classes1 as WAR, classes2 as CLR, classes3 as PAL, classes4 as RNG,
  classes5 as SHD, classes6 as DRU, classes7 as MNK, classes8 as BRD,
  classes9 as ROG, classes10 as SHM, classes11 as NEC, classes12 as WIZ,
  classes13 as MAG, classes14 as ENC, classes15 as BST
FROM spells_new
WHERE id IN (1348,5093,9412,9413,9414,9415,9416,9417,9418,9419,9420,9421)
ORDER BY id;
-- Each row: exactly one class column = 1, all others = 255
-- 1348 NEC: classes11=1
-- 5093 SHD: classes5=1
-- 9412 CLR: classes2=1
-- 9413 PAL: classes3=1
-- 9414 DRU: classes6=1
-- 9415 RNG: classes4=1
-- 9416 SHM: classes10=1
-- 9417 BST: classes15=1
-- 9418 WIZ: classes12=1
-- 9419 MAG: classes13=1
-- 9420 ENC: classes14=1
-- 9421 BRD: classes8=1

-- ============================================================
-- 4. No other spells share spell_category=221
-- ============================================================
SELECT COUNT(*) as other_spells_with_category_221
FROM spells_new
WHERE spell_category = 221
  AND id NOT IN (1348,5093,9412,9413,9414,9415,9416,9417,9418,9419,9420,9421);
-- Expected: 0

-- ============================================================
-- 5. Spell IDs all within Titanium SPELL_ID_MAX=9999
-- ============================================================
SELECT COUNT(*) as spells_over_9999
FROM spells_new
WHERE id IN (1348,5093,9412,9413,9414,9415,9416,9417,9418,9419,9420,9421)
  AND id > 9999;
-- Expected: 0

-- ============================================================
-- 6. Items: All 12 scroll items present with correct scrolleffect
-- ============================================================
SELECT id, Name, itemtype, scrolleffect, classes, price, nodrop, norent
FROM items
WHERE id BETWEEN 1000001 AND 1000012
ORDER BY id;
-- Expected 12 rows, itemtype=20, scrolltype=7, classes = single-class bitmask

-- ============================================================
-- 7. Items/spells cross-check: each scroll's scrolleffect points to a valid new spell
-- ============================================================
SELECT i.id as item_id, i.Name as scroll_name, i.scrolleffect as spell_id, sn.name as spell_name
FROM items i
LEFT JOIN spells_new sn ON sn.id = i.scrolleffect
WHERE i.id BETWEEN 1000001 AND 1000012
ORDER BY i.id;
-- All 12 rows must have a non-null spell_name

-- ============================================================
-- 8. Merchantlist: all 12 scroll items appear on at least one vendor
-- ============================================================
SELECT i.id as item_id, i.Name, COUNT(ml.merchantid) as vendor_count
FROM items i
LEFT JOIN merchantlist ml ON ml.item = i.id
WHERE i.id BETWEEN 1000001 AND 1000012
GROUP BY i.id, i.Name
ORDER BY i.id;
-- All 12 items must have vendor_count >= 1

-- ============================================================
-- 9. Merchantlist: verify each scroll is on the expected vendor(s)
-- ============================================================
SELECT ml.merchantid, n.name as npc_name, s2.zone, ml.slot, ml.item, i.Name as scroll_name
FROM merchantlist ml
JOIN items i ON i.id = ml.item
JOIN npc_types n ON n.merchant_id = ml.merchantid
JOIN spawnentry se ON se.npcID = n.id
JOIN spawngroup sg ON sg.id = se.spawngroupID
JOIN spawn2 s2 ON s2.spawngroupID = sg.id
WHERE ml.item BETWEEN 1000001 AND 1000012
ORDER BY s2.zone, i.Name, ml.merchantid;
-- Expected: 57 rows across starting-city vendors for all 12 classes

-- ============================================================
-- 10. Merchantlist total row count
-- ============================================================
SELECT COUNT(*) as total_merchantlist_rows
FROM merchantlist
WHERE item BETWEEN 1000001 AND 1000012;
-- Expected: 57

-- ============================================================
-- 11. Auto-scribe: character_spells rows for the new spells
-- ============================================================
SELECT cs.id as char_id, cd.name as char_name, cd.class,
       cs.slot_id, cs.spell_id, sn.name as spell_name
FROM character_spells cs
JOIN character_data cd ON cd.id = cs.id
JOIN spells_new sn ON sn.id = cs.spell_id
WHERE cs.spell_id IN (1348,5093,9412,9413,9414,9415,9416,9417,9418,9419,9420,9421)
ORDER BY cs.id, cs.slot_id;
-- Expected: 1 row for character Chelon (class=14/ENC, spell_id=9420 Phantasmal Reclamation)
-- slot_id must be <= 399

-- ============================================================
-- 12. Auto-scribe: slot_id must be within spellbook bounds
-- ============================================================
SELECT COUNT(*) as out_of_bounds_slots
FROM character_spells
WHERE spell_id IN (1348,5093,9412,9413,9414,9415,9416,9417,9418,9419,9420,9421)
  AND slot_id > 399;
-- Expected: 0

-- ============================================================
-- 13. Rule_values: cooldown rule present
-- ============================================================
SELECT ruleset_id, rule_name, rule_value, notes
FROM rule_values
WHERE rule_name = 'Spells:UniversalSummonCorpseCooldown';
-- Expected: ruleset_id=1, rule_value='180'

-- ============================================================
-- 14. No existing spells were modified (existing NEC/SHM summon-corpse line intact)
-- ============================================================
SELECT id, name, spell_category, recast_time
FROM spells_new
WHERE effectid1 = 91
  AND id NOT IN (1348,5093,9412,9413,9414,9415,9416,9417,9418,9419,9420,9421)
ORDER BY id;
-- Expected: original 11 rows unchanged (spell_category=52 or -99, recast_time=12000 or 0)
-- spell_category must NOT be 221 for any of these rows

-- ============================================================
-- 15. Summary check: all counts in one query
-- ============================================================
SELECT
  (SELECT COUNT(*) FROM spells_new WHERE id IN (1348,5093,9412,9413,9414,9415,9416,9417,9418,9419,9420,9421)) as new_spells,
  (SELECT COUNT(*) FROM items WHERE id BETWEEN 1000001 AND 1000012) as new_items,
  (SELECT COUNT(*) FROM merchantlist WHERE item BETWEEN 1000001 AND 1000012) as vendor_entries,
  (SELECT COUNT(*) FROM character_spells WHERE spell_id IN (1348,5093,9412,9413,9414,9415,9416,9417,9418,9419,9420,9421)) as auto_scribed,
  (SELECT COUNT(*) FROM rule_values WHERE rule_name='Spells:UniversalSummonCorpseCooldown') as rule_row;
-- Expected: 12 | 12 | 57 | 1 | 1
