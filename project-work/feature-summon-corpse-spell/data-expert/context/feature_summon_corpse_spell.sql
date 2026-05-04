-- feature/summon-corpse-spell: Universal Summon Corpse Spell
-- Data-expert migration: spells_new + items + merchantlist + character_spells + rule_values
-- Date: 2026-05-03
--
-- EXECUTION: Run with -i flag for stdin piping to work correctly:
--   docker exec -i akk-stack-mariadb-1 mysql -ueqemu -p'<pass>' peq < feature_summon_corpse_spell.sql
--
-- 12 class-flavored Summon Corpse spells (one per casting class), free level-1 utility spells
-- that pull the caster's own corpse to their feet within the same zone.
--
-- Spell IDs assigned: 1348, 5093, 9412-9421 (all <= SPELL_ID_MAX=9999)
-- spell_category: 221 (new; max in use was 220; used as C++ discriminator for rule override)
-- Item IDs: 1000001-1000012 (custom range, free)
--
-- This migration is idempotent (all sections guarded by NOT EXISTS).
-- Run while affected characters are logged out (auto-scribe takes effect on next zone-in).
--
-- Class ID reference: CLR=2, PAL=3, RNG=4, SHD=5, DRU=6, BRD=8, SHM=10, NEC=11, WIZ=12, MAG=13, ENC=14, BST=15
-- Classes bitmask: WAR=1, CLR=2, PAL=4, RNG=8, SHD=16, DRU=32, MNK=64, BRD=128, ROG=256, SHM=512, NEC=1024, WIZ=2048, MAG=4096, ENC=8192, BST=16384

START TRANSACTION;

-- =============================================================================
-- SECTION 1: spells_new — 12 new spell rows
-- Clone cosmetics from spell 2213 (Lesser Summon Corpse):
--   new_icon=109, CastingAnim=43, descnum=2213, effectdescnum=64, goodEffect=1
-- All 12 use:
--   player_1='PLAYER_1', you_cast='', other_casts='', cast_on_you='', cast_on_other='', spell_fades=''
--   (empty string, not NULL — shared_memory C++ loader crashes on NULL varchar fields)
--   effect_id1=91 (SE_SummonCorpse), effect_base_value1=255 (level cap), formula1=100
--   cast_time=6000ms, recovery_time=2500ms, recast_time=180000ms (3 min)
--   mana=0, targettype=6 (ST_Self), buffduration=65535 (0xFFFF, bypasses bard song mode)
--   buffdurationformula=0, resisttype=0, EndurTimerIndex=0, IsDiscipline=0
--   spell_category=221 (new universal summon corpse discriminator)
--   effects 2-12: effectid = 254 (blank sentinel), all base_values/formulas = 0
-- classes[N]: 1 for the spell's class, 255 for all others
--   classes1=WAR, classes2=CLR, classes3=PAL, classes4=RNG, classes5=SHD, classes6=DRU
--   classes7=MNK, classes8=BRD, classes9=ROG, classes10=SHM, classes11=NEC, classes12=WIZ
--   classes13=MAG, classes14=ENC, classes15=BST, classes16=unused (255)
-- =============================================================================

-- ID 1348: Necromancer — Conjure Cadaver (classes11=NEC=1)
INSERT INTO spells_new
  (id, name, player_1, you_cast, other_casts, cast_on_you, cast_on_other, spell_fades,
   cast_time, recovery_time, recast_time, mana,
   effectid1, effect_base_value1, formula1,
   effectid2, effectid3, effectid4, effectid5, effectid6, effectid7, effectid8, effectid9, effectid10, effectid11, effectid12,
   targettype, buffduration, buffdurationformula, goodEffect, resisttype, skill,
   EndurTimerIndex, IsDiscipline, spell_category,
   classes1, classes2, classes3, classes4, classes5, classes6, classes7, classes8, classes9, classes10, classes11, classes12, classes13, classes14, classes15, classes16,
   new_icon, CastingAnim, descnum, effectdescnum,
   MinResist, MaxResist, no_block)
SELECT
  1348, 'Conjure Cadaver', 'PLAYER_1', '', '', '', '', '', 6000, 2500, 180000, 0,
  91, 255, 100,
  254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254,
  6, 65535, 0, 1, 0, 14,
  0, 0, 221,
  255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 1, 255, 255, 255, 255, 255,
  109, 43, 2213, 64,
  0, 0, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM spells_new WHERE id = 1348);

-- ID 5093: Shadow Knight — Death's Recall (classes5=SHD=1)
INSERT INTO spells_new
  (id, name, player_1, you_cast, other_casts, cast_on_you, cast_on_other, spell_fades,
   cast_time, recovery_time, recast_time, mana,
   effectid1, effect_base_value1, formula1,
   effectid2, effectid3, effectid4, effectid5, effectid6, effectid7, effectid8, effectid9, effectid10, effectid11, effectid12,
   targettype, buffduration, buffdurationformula, goodEffect, resisttype, skill,
   EndurTimerIndex, IsDiscipline, spell_category,
   classes1, classes2, classes3, classes4, classes5, classes6, classes7, classes8, classes9, classes10, classes11, classes12, classes13, classes14, classes15, classes16,
   new_icon, CastingAnim, descnum, effectdescnum,
   MinResist, MaxResist, no_block)
SELECT
  5093, 'Death''s Recall', 'PLAYER_1', '', '', '', '', '', 6000, 2500, 180000, 0,
  91, 255, 100,
  254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254,
  6, 65535, 0, 1, 0, 14,
  0, 0, 221,
  255, 255, 255, 255, 1, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
  109, 43, 2213, 64,
  0, 0, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM spells_new WHERE id = 5093);

-- ID 9412: Cleric — Divine Reclamation (classes2=CLR=1, skill=1 Divination)
INSERT INTO spells_new
  (id, name, player_1, you_cast, other_casts, cast_on_you, cast_on_other, spell_fades,
   cast_time, recovery_time, recast_time, mana,
   effectid1, effect_base_value1, formula1,
   effectid2, effectid3, effectid4, effectid5, effectid6, effectid7, effectid8, effectid9, effectid10, effectid11, effectid12,
   targettype, buffduration, buffdurationformula, goodEffect, resisttype, skill,
   EndurTimerIndex, IsDiscipline, spell_category,
   classes1, classes2, classes3, classes4, classes5, classes6, classes7, classes8, classes9, classes10, classes11, classes12, classes13, classes14, classes15, classes16,
   new_icon, CastingAnim, descnum, effectdescnum,
   MinResist, MaxResist, no_block)
SELECT
  9412, 'Divine Reclamation', 'PLAYER_1', '', '', '', '', '', 6000, 2500, 180000, 0,
  91, 255, 100,
  254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254,
  6, 65535, 0, 1, 0, 1,
  0, 0, 221,
  255, 1, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
  109, 43, 2213, 64,
  0, 0, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM spells_new WHERE id = 9412);

-- ID 9413: Paladin — Solemn Retrieval (classes3=PAL=1, skill=1 Divination)
INSERT INTO spells_new
  (id, name, player_1, you_cast, other_casts, cast_on_you, cast_on_other, spell_fades,
   cast_time, recovery_time, recast_time, mana,
   effectid1, effect_base_value1, formula1,
   effectid2, effectid3, effectid4, effectid5, effectid6, effectid7, effectid8, effectid9, effectid10, effectid11, effectid12,
   targettype, buffduration, buffdurationformula, goodEffect, resisttype, skill,
   EndurTimerIndex, IsDiscipline, spell_category,
   classes1, classes2, classes3, classes4, classes5, classes6, classes7, classes8, classes9, classes10, classes11, classes12, classes13, classes14, classes15, classes16,
   new_icon, CastingAnim, descnum, effectdescnum,
   MinResist, MaxResist, no_block)
SELECT
  9413, 'Solemn Retrieval', 'PLAYER_1', '', '', '', '', '', 6000, 2500, 180000, 0,
  91, 255, 100,
  254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254,
  6, 65535, 0, 1, 0, 1,
  0, 0, 221,
  255, 255, 1, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
  109, 43, 2213, 64,
  0, 0, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM spells_new WHERE id = 9413);

-- ID 9414: Druid — Nature's Reclamation (classes6=DRU=1, skill=14 Alteration)
INSERT INTO spells_new
  (id, name, player_1, you_cast, other_casts, cast_on_you, cast_on_other, spell_fades,
   cast_time, recovery_time, recast_time, mana,
   effectid1, effect_base_value1, formula1,
   effectid2, effectid3, effectid4, effectid5, effectid6, effectid7, effectid8, effectid9, effectid10, effectid11, effectid12,
   targettype, buffduration, buffdurationformula, goodEffect, resisttype, skill,
   EndurTimerIndex, IsDiscipline, spell_category,
   classes1, classes2, classes3, classes4, classes5, classes6, classes7, classes8, classes9, classes10, classes11, classes12, classes13, classes14, classes15, classes16,
   new_icon, CastingAnim, descnum, effectdescnum,
   MinResist, MaxResist, no_block)
SELECT
  9414, 'Nature''s Reclamation', 'PLAYER_1', '', '', '', '', '', 6000, 2500, 180000, 0,
  91, 255, 100,
  254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254,
  6, 65535, 0, 1, 0, 14,
  0, 0, 221,
  255, 255, 255, 255, 255, 1, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
  109, 43, 2213, 64,
  0, 0, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM spells_new WHERE id = 9414);

-- ID 9415: Ranger — Warden's Claim (classes4=RNG=1, skill=14 Alteration)
INSERT INTO spells_new
  (id, name, player_1, you_cast, other_casts, cast_on_you, cast_on_other, spell_fades,
   cast_time, recovery_time, recast_time, mana,
   effectid1, effect_base_value1, formula1,
   effectid2, effectid3, effectid4, effectid5, effectid6, effectid7, effectid8, effectid9, effectid10, effectid11, effectid12,
   targettype, buffduration, buffdurationformula, goodEffect, resisttype, skill,
   EndurTimerIndex, IsDiscipline, spell_category,
   classes1, classes2, classes3, classes4, classes5, classes6, classes7, classes8, classes9, classes10, classes11, classes12, classes13, classes14, classes15, classes16,
   new_icon, CastingAnim, descnum, effectdescnum,
   MinResist, MaxResist, no_block)
SELECT
  9415, 'Warden''s Claim', 'PLAYER_1', '', '', '', '', '', 6000, 2500, 180000, 0,
  91, 255, 100,
  254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254,
  6, 65535, 0, 1, 0, 14,
  0, 0, 221,
  255, 255, 255, 1, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
  109, 43, 2213, 64,
  0, 0, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM spells_new WHERE id = 9415);

-- ID 9416: Shaman — Ancestral Summons (classes10=SHM=1, skill=14 Alteration)
INSERT INTO spells_new
  (id, name, player_1, you_cast, other_casts, cast_on_you, cast_on_other, spell_fades,
   cast_time, recovery_time, recast_time, mana,
   effectid1, effect_base_value1, formula1,
   effectid2, effectid3, effectid4, effectid5, effectid6, effectid7, effectid8, effectid9, effectid10, effectid11, effectid12,
   targettype, buffduration, buffdurationformula, goodEffect, resisttype, skill,
   EndurTimerIndex, IsDiscipline, spell_category,
   classes1, classes2, classes3, classes4, classes5, classes6, classes7, classes8, classes9, classes10, classes11, classes12, classes13, classes14, classes15, classes16,
   new_icon, CastingAnim, descnum, effectdescnum,
   MinResist, MaxResist, no_block)
SELECT
  9416, 'Ancestral Summons', 'PLAYER_1', '', '', '', '', '', 6000, 2500, 180000, 0,
  91, 255, 100,
  254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254,
  6, 65535, 0, 1, 0, 14,
  0, 0, 221,
  255, 255, 255, 255, 255, 255, 255, 255, 255, 1, 255, 255, 255, 255, 255, 255,
  109, 43, 2213, 64,
  0, 0, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM spells_new WHERE id = 9416);

-- ID 9417: Beastlord — Ancestral Call (classes15=BST=1, skill=14 Alteration)
INSERT INTO spells_new
  (id, name, player_1, you_cast, other_casts, cast_on_you, cast_on_other, spell_fades,
   cast_time, recovery_time, recast_time, mana,
   effectid1, effect_base_value1, formula1,
   effectid2, effectid3, effectid4, effectid5, effectid6, effectid7, effectid8, effectid9, effectid10, effectid11, effectid12,
   targettype, buffduration, buffdurationformula, goodEffect, resisttype, skill,
   EndurTimerIndex, IsDiscipline, spell_category,
   classes1, classes2, classes3, classes4, classes5, classes6, classes7, classes8, classes9, classes10, classes11, classes12, classes13, classes14, classes15, classes16,
   new_icon, CastingAnim, descnum, effectdescnum,
   MinResist, MaxResist, no_block)
SELECT
  9417, 'Ancestral Call', 'PLAYER_1', '', '', '', '', '', 6000, 2500, 180000, 0,
  91, 255, 100,
  254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254,
  6, 65535, 0, 1, 0, 14,
  0, 0, 221,
  255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 1, 255,
  109, 43, 2213, 64,
  0, 0, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM spells_new WHERE id = 9417);

-- ID 9418: Wizard — Spectral Translocation (classes12=WIZ=1, skill=14 Alteration)
INSERT INTO spells_new
  (id, name, player_1, you_cast, other_casts, cast_on_you, cast_on_other, spell_fades,
   cast_time, recovery_time, recast_time, mana,
   effectid1, effect_base_value1, formula1,
   effectid2, effectid3, effectid4, effectid5, effectid6, effectid7, effectid8, effectid9, effectid10, effectid11, effectid12,
   targettype, buffduration, buffdurationformula, goodEffect, resisttype, skill,
   EndurTimerIndex, IsDiscipline, spell_category,
   classes1, classes2, classes3, classes4, classes5, classes6, classes7, classes8, classes9, classes10, classes11, classes12, classes13, classes14, classes15, classes16,
   new_icon, CastingAnim, descnum, effectdescnum,
   MinResist, MaxResist, no_block)
SELECT
  9418, 'Spectral Translocation', 'PLAYER_1', '', '', '', '', '', 6000, 2500, 180000, 0,
  91, 255, 100,
  254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254,
  6, 65535, 0, 1, 0, 14,
  0, 0, 221,
  255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 1, 255, 255, 255, 255,
  109, 43, 2213, 64,
  0, 0, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM spells_new WHERE id = 9418);

-- ID 9419: Magician — Summon Mortal Remains (classes13=MAG=1, skill=14 Conjuration)
INSERT INTO spells_new
  (id, name, player_1, you_cast, other_casts, cast_on_you, cast_on_other, spell_fades,
   cast_time, recovery_time, recast_time, mana,
   effectid1, effect_base_value1, formula1,
   effectid2, effectid3, effectid4, effectid5, effectid6, effectid7, effectid8, effectid9, effectid10, effectid11, effectid12,
   targettype, buffduration, buffdurationformula, goodEffect, resisttype, skill,
   EndurTimerIndex, IsDiscipline, spell_category,
   classes1, classes2, classes3, classes4, classes5, classes6, classes7, classes8, classes9, classes10, classes11, classes12, classes13, classes14, classes15, classes16,
   new_icon, CastingAnim, descnum, effectdescnum,
   MinResist, MaxResist, no_block)
SELECT
  9419, 'Summon Mortal Remains', 'PLAYER_1', '', '', '', '', '', 6000, 2500, 180000, 0,
  91, 255, 100,
  254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254,
  6, 65535, 0, 1, 0, 14,
  0, 0, 221,
  255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 1, 255, 255, 255,
  109, 43, 2213, 64,
  0, 0, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM spells_new WHERE id = 9419);

-- ID 9420: Enchanter — Phantasmal Reclamation (classes14=ENC=1, skill=14 Alteration)
INSERT INTO spells_new
  (id, name, player_1, you_cast, other_casts, cast_on_you, cast_on_other, spell_fades,
   cast_time, recovery_time, recast_time, mana,
   effectid1, effect_base_value1, formula1,
   effectid2, effectid3, effectid4, effectid5, effectid6, effectid7, effectid8, effectid9, effectid10, effectid11, effectid12,
   targettype, buffduration, buffdurationformula, goodEffect, resisttype, skill,
   EndurTimerIndex, IsDiscipline, spell_category,
   classes1, classes2, classes3, classes4, classes5, classes6, classes7, classes8, classes9, classes10, classes11, classes12, classes13, classes14, classes15, classes16,
   new_icon, CastingAnim, descnum, effectdescnum,
   MinResist, MaxResist, no_block)
SELECT
  9420, 'Phantasmal Reclamation', 'PLAYER_1', '', '', '', '', '', 6000, 2500, 180000, 0,
  91, 255, 100,
  254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254,
  6, 65535, 0, 1, 0, 14,
  0, 0, 221,
  255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 1, 255, 255,
  109, 43, 2213, 64,
  0, 0, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM spells_new WHERE id = 9420);

-- ID 9421: Bard — Dirge of Homecoming (classes8=BRD=1, skill=98 Singing)
INSERT INTO spells_new
  (id, name, player_1, you_cast, other_casts, cast_on_you, cast_on_other, spell_fades,
   cast_time, recovery_time, recast_time, mana,
   effectid1, effect_base_value1, formula1,
   effectid2, effectid3, effectid4, effectid5, effectid6, effectid7, effectid8, effectid9, effectid10, effectid11, effectid12,
   targettype, buffduration, buffdurationformula, goodEffect, resisttype, skill,
   EndurTimerIndex, IsDiscipline, spell_category,
   classes1, classes2, classes3, classes4, classes5, classes6, classes7, classes8, classes9, classes10, classes11, classes12, classes13, classes14, classes15, classes16,
   new_icon, CastingAnim, descnum, effectdescnum,
   MinResist, MaxResist, no_block)
SELECT
  9421, 'Dirge of Homecoming', 'PLAYER_1', '', '', '', '', '', 6000, 2500, 180000, 0,
  91, 255, 100,
  254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254,
  6, 65535, 0, 1, 0, 98,
  0, 0, 221,
  255, 255, 255, 255, 255, 255, 255, 1, 255, 255, 255, 255, 255, 255, 255, 255,
  109, 43, 2213, 64,
  0, 0, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM spells_new WHERE id = 9421);

-- =============================================================================
-- SECTION 2: items — 12 scroll items (itemtype=20, scrolltype=7, scrolllevel=0)
-- Classes bitmask (single class only):
--   CLR=2, PAL=4, RNG=8, SHD=16, DRU=32, BRD=128, SHM=512, NEC=1024, WIZ=2048, MAG=4096, ENC=8192, BST=16384
-- Item IDs: 1000001-1000012
-- idfile='IT63' (standard scroll model, matches existing spell scrolls)
-- slots=0 (matches all existing spell scrolls in live DB)
-- price=1000 (10 silver, trivial)
-- nodrop=0, norent=0, weight=1
-- =============================================================================

-- 1000001: Scroll: Conjure Cadaver (NEC, classes=1024)
INSERT INTO items (id, Name, itemtype, scrolleffect, scrolltype, scrolllevel, classes, races, slots, price, nodrop, norent, weight, idfile, lore)
SELECT 1000001, 'Scroll: Conjure Cadaver', 20, 1348, 7, 0, 1024, 65535, 0, 1000, 0, 0, 1, 'IT63', 'Scroll: Conjure Cadaver'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM items WHERE id = 1000001);

-- 1000002: Scroll: Death's Recall (SHD, classes=16)
INSERT INTO items (id, Name, itemtype, scrolleffect, scrolltype, scrolllevel, classes, races, slots, price, nodrop, norent, weight, idfile, lore)
SELECT 1000002, 'Scroll: Death''s Recall', 20, 5093, 7, 0, 16, 65535, 0, 1000, 0, 0, 1, 'IT63', 'Scroll: Death''s Recall'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM items WHERE id = 1000002);

-- 1000003: Scroll: Divine Reclamation (CLR, classes=2)
INSERT INTO items (id, Name, itemtype, scrolleffect, scrolltype, scrolllevel, classes, races, slots, price, nodrop, norent, weight, idfile, lore)
SELECT 1000003, 'Scroll: Divine Reclamation', 20, 9412, 7, 0, 2, 65535, 0, 1000, 0, 0, 1, 'IT63', 'Scroll: Divine Reclamation'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM items WHERE id = 1000003);

-- 1000004: Scroll: Solemn Retrieval (PAL, classes=4)
INSERT INTO items (id, Name, itemtype, scrolleffect, scrolltype, scrolllevel, classes, races, slots, price, nodrop, norent, weight, idfile, lore)
SELECT 1000004, 'Scroll: Solemn Retrieval', 20, 9413, 7, 0, 4, 65535, 0, 1000, 0, 0, 1, 'IT63', 'Scroll: Solemn Retrieval'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM items WHERE id = 1000004);

-- 1000005: Scroll: Nature's Reclamation (DRU, classes=32)
INSERT INTO items (id, Name, itemtype, scrolleffect, scrolltype, scrolllevel, classes, races, slots, price, nodrop, norent, weight, idfile, lore)
SELECT 1000005, 'Scroll: Nature''s Reclamation', 20, 9414, 7, 0, 32, 65535, 0, 1000, 0, 0, 1, 'IT63', 'Scroll: Nature''s Reclamation'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM items WHERE id = 1000005);

-- 1000006: Scroll: Warden's Claim (RNG, classes=8)
INSERT INTO items (id, Name, itemtype, scrolleffect, scrolltype, scrolllevel, classes, races, slots, price, nodrop, norent, weight, idfile, lore)
SELECT 1000006, 'Scroll: Warden''s Claim', 20, 9415, 7, 0, 8, 65535, 0, 1000, 0, 0, 1, 'IT63', 'Scroll: Warden''s Claim'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM items WHERE id = 1000006);

-- 1000007: Scroll: Ancestral Summons (SHM, classes=512)
INSERT INTO items (id, Name, itemtype, scrolleffect, scrolltype, scrolllevel, classes, races, slots, price, nodrop, norent, weight, idfile, lore)
SELECT 1000007, 'Scroll: Ancestral Summons', 20, 9416, 7, 0, 512, 65535, 0, 1000, 0, 0, 1, 'IT63', 'Scroll: Ancestral Summons'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM items WHERE id = 1000007);

-- 1000008: Scroll: Ancestral Call (BST, classes=16384)
INSERT INTO items (id, Name, itemtype, scrolleffect, scrolltype, scrolllevel, classes, races, slots, price, nodrop, norent, weight, idfile, lore)
SELECT 1000008, 'Scroll: Ancestral Call', 20, 9417, 7, 0, 16384, 65535, 0, 1000, 0, 0, 1, 'IT63', 'Scroll: Ancestral Call'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM items WHERE id = 1000008);

-- 1000009: Scroll: Spectral Translocation (WIZ, classes=2048)
INSERT INTO items (id, Name, itemtype, scrolleffect, scrolltype, scrolllevel, classes, races, slots, price, nodrop, norent, weight, idfile, lore)
SELECT 1000009, 'Scroll: Spectral Translocation', 20, 9418, 7, 0, 2048, 65535, 0, 1000, 0, 0, 1, 'IT63', 'Scroll: Spectral Translocation'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM items WHERE id = 1000009);

-- 1000010: Scroll: Summon Mortal Remains (MAG, classes=4096)
INSERT INTO items (id, Name, itemtype, scrolleffect, scrolltype, scrolllevel, classes, races, slots, price, nodrop, norent, weight, idfile, lore)
SELECT 1000010, 'Scroll: Summon Mortal Remains', 20, 9419, 7, 0, 4096, 65535, 0, 1000, 0, 0, 1, 'IT63', 'Scroll: Summon Mortal Remains'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM items WHERE id = 1000010);

-- 1000011: Scroll: Phantasmal Reclamation (ENC, classes=8192)
INSERT INTO items (id, Name, itemtype, scrolleffect, scrolltype, scrolllevel, classes, races, slots, price, nodrop, norent, weight, idfile, lore)
SELECT 1000011, 'Scroll: Phantasmal Reclamation', 20, 9420, 7, 0, 8192, 65535, 0, 1000, 0, 0, 1, 'IT63', 'Scroll: Phantasmal Reclamation'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM items WHERE id = 1000011);

-- 1000012: Scroll: Dirge of Homecoming (BRD, classes=128)
INSERT INTO items (id, Name, itemtype, scrolleffect, scrolltype, scrolllevel, classes, races, slots, price, nodrop, norent, weight, idfile, lore)
SELECT 1000012, 'Scroll: Dirge of Homecoming', 20, 9421, 7, 0, 128, 65535, 0, 1000, 0, 0, 1, 'IT63', 'Scroll: Dirge of Homecoming'
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM items WHERE id = 1000012);

-- =============================================================================
-- SECTION 3: merchantlist — vendor entries for each starting-city class spell vendor
-- Verified slot values: each row uses max(slot)+1 for its merchant at time of migration.
-- Using NOT EXISTS guard on (merchantid, item) pair for idempotency.
-- faction_required=-100 (no faction gate), level_required=0, classes_required=65535, probability=100
-- NOTE: misty/mistythicket spell vendors do not exist (no scrolleffect items on those merchants).
--       Druids starting in Misty Thicket can purchase from qcat (Surefall Glade) or qeynos2.
-- =============================================================================

-- ---- CLERIC (scroll 1000003: Scroll: Divine Reclamation) ----
-- erudnext: Mertitt_Phentilly (24028, max_slot=20 → new slot=21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 24028, 21, 1000003, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=24028 AND item=1000003);

-- qeynos2: Mellisa_Purgor (2047, max_slot=21 → new slot=22)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 2047, 22, 1000003, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=2047 AND item=1000003);

-- felwithea: Celest_Palestream (61020, max_slot=20 → new slot=21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 61020, 21, 1000003, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=61020 AND item=1000003);

-- halas: Shenigan_Mc`Macky (29082, max_slot=19 → new slot=20)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 29082, 20, 1000003, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=29082 AND item=1000003);

-- kaladimb: Zeffan_Holdsman (67067, max_slot=20 → new slot=21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 67067, 21, 1000003, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=67067 AND item=1000003);

-- rivervale: Frappy_Slimfinger (19024, max_slot=20 → new slot=21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 19024, 21, 1000003, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=19024 AND item=1000003);

-- qcat (Surefall Glade): Leon_Ereek (45058, max_slot=20 → new slot=21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 45058, 21, 1000003, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=45058 AND item=1000003);

-- freeportwest: Amata_D`Lavi (383202, max_slot=20 → new slot=21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 383202, 21, 1000003, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=383202 AND item=1000003);

-- neriakc: Issia_H`Rugla (42033, max_slot=20 → new slot=21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 42033, 21, 1000003, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=42033 AND item=1000003);

-- ---- PALADIN (scroll 1000004: Scroll: Solemn Retrieval) ----
-- erudnext: Mertitt_Phentilly (24028, slot 22 after CLR above)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 24028, 22, 1000004, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=24028 AND item=1000004);

-- qeynos2: Mellisa_Purgor (2047, slot 23)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 2047, 23, 1000004, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=2047 AND item=1000004);

-- felwithea: Celest_Palestream (61020, slot 22)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 61020, 22, 1000004, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=61020 AND item=1000004);

-- halas: Shenigan_Mc`Macky (29082, slot 21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 29082, 21, 1000004, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=29082 AND item=1000004);

-- kaladimb: Zeffan_Holdsman (67067, slot 22)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 67067, 22, 1000004, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=67067 AND item=1000004);

-- rivervale: Frappy_Slimfinger (19024, slot 22)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 19024, 22, 1000004, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=19024 AND item=1000004);

-- freeportwest: Amata_D`Lavi (383202, slot 22)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 383202, 22, 1000004, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=383202 AND item=1000004);

-- ---- RANGER (scroll 1000006: Scroll: Warden's Claim) ----
-- gfaydark: Zelli_Starsfire (54081, max_slot=21 → new slot=22)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 54081, 22, 1000006, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=54081 AND item=1000006);

-- qcat: Vidurlyn_Aeminee (45050, max_slot=19 → new slot=20)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 45050, 20, 1000006, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=45050 AND item=1000006);

-- qeynos2: Henlom_Visrek (2054, max_slot=18 → new slot=19)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 2054, 19, 1000006, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=2054 AND item=1000006);

-- ---- SHADOW KNIGHT (scroll 1000002: Scroll: Death's Recall) ----
-- neriakc: Misal_S`Kor (42027, max_slot=20 → new slot=21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 42027, 21, 1000002, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=42027 AND item=1000002);

-- cabeast: Lord_Vizaroth (106016, max_slot=16 → new slot=17)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 106016, 17, 1000002, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=106016 AND item=1000002);

-- freeporteast: Malalon_Morotia (382151, max_slot=70 → new slot=71)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 382151, 71, 1000002, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=382151 AND item=1000002);

-- ---- DRUID (scroll 1000005: Scroll: Nature's Reclamation) ----
-- gfaydark: Zelli_Starsfire (54081, slot 23 after RNG above)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 54081, 23, 1000005, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=54081 AND item=1000005);

-- qcat: Leon_Ereek (45058, slot 22 after CLR above)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 45058, 22, 1000005, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=45058 AND item=1000005);

-- qeynos2: Henlom_Visrek (2054, slot 20 after RNG above)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 2054, 20, 1000005, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=2054 AND item=1000005);

-- ---- BARD (scroll 1000012: Scroll: Dirge of Homecoming) ----
-- gfaydark: Astar_Leafsinger (54074, max_slot=12 → new slot=13)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 54074, 13, 1000012, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=54074 AND item=1000012);

-- freeporteast: Malusuard_Blolus (382070, max_slot=41 → new slot=42) [Bard-only vendor]
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 382070, 42, 1000012, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=382070 AND item=1000012);

-- qeynos: Chalea_Volesga (1036, max_slot=17 → new slot=18)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 1036, 18, 1000012, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=1036 AND item=1000012);

-- neriakc: Sol_Punox (42035, max_slot=18 → new slot=19)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 42035, 19, 1000012, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=42035 AND item=1000012);

-- ---- SHAMAN (scroll 1000007: Scroll: Ancestral Summons) ----
-- grobb: Crilt (52027, max_slot=44 → new slot=45)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 52027, 45, 1000007, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=52027 AND item=1000007);

-- halas: Shenigan_Mc`Macky (29082, slot 22 after CLR+PAL above)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 29082, 22, 1000007, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=29082 AND item=1000007);

-- oggok: Brogdog (49089, max_slot=19 → new slot=20) [Brogdog in oggok = merchant 49089]
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 49089, 20, 1000007, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=49089 AND item=1000007);

-- cabeast: Vessel_Kabda (106092, max_slot=18 → new slot=19)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 106092, 19, 1000007, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=106092 AND item=1000007);

-- sharvahl: Scribe_Mojir (155187, max_slot=18 → new slot=19)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 155187, 19, 1000007, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=155187 AND item=1000007);

-- ---- NECROMANCER (scroll 1000001: Scroll: Conjure Cadaver) ----
-- paineel: Kilevra_Natasu (75087, max_slot=18 → new slot=19)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 75087, 19, 1000001, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=75087 AND item=1000001);

-- cabwest: Keeper_Plight (82037, max_slot=20 → new slot=21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 82037, 21, 1000001, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=82037 AND item=1000001);

-- neriakc: Misal_S`Kor (42027, slot 22 after SHD above)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 42027, 22, 1000001, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=42027 AND item=1000001);

-- ---- WIZARD (scroll 1000009: Scroll: Spectral Translocation) ----
-- erudnint: Onyssa_Vroce (23008, max_slot=17 → new slot=18)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 23008, 18, 1000009, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=23008 AND item=1000009);

-- felwitheb: Celent_Newmist (62007, max_slot=13 → new slot=14)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 62007, 14, 1000009, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=62007 AND item=1000009);

-- freeportwest: Charia_Betou (383133, max_slot=12 → new slot=13)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 383133, 13, 1000009, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=383133 AND item=1000009);

-- qeynos: Pai_Berenis (1024, max_slot=14 → new slot=15)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 1024, 15, 1000009, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=1024 AND item=1000009);

-- neriakb: Mignar_Mi`Draskch (41003, max_slot=10 → new slot=11)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 41003, 11, 1000009, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=41003 AND item=1000009);

-- ---- MAGICIAN (scroll 1000010: Scroll: Summon Mortal Remains) ----
-- erudnext: Chembla_Ellent (24014, max_slot=20 → new slot=21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 24014, 21, 1000010, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=24014 AND item=1000010);

-- erudnint: Onyssa_Vroce (23008, slot 19 after WIZ above)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 23008, 19, 1000010, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=23008 AND item=1000010);

-- felwitheb: Osisa_Goldenspear (62012, max_slot=17 → new slot=18)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 62012, 18, 1000010, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=62012 AND item=1000010);

-- freeportwest: Tharma_Jaremi (383156, max_slot=17 → new slot=18)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 383156, 18, 1000010, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=383156 AND item=1000010);

-- qeynos: Gende_Reldari (1015, max_slot=17 → new slot=18)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 1015, 18, 1000010, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=1015 AND item=1000010);

-- neriakc: Ash_C`Luzz (42008, max_slot=20 → new slot=21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 42008, 21, 1000010, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=42008 AND item=1000010);

-- ---- ENCHANTER (scroll 1000011: Scroll: Phantasmal Reclamation) ----
-- erudnint: Pinilla (23015, max_slot=20 → new slot=21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 23015, 21, 1000011, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=23015 AND item=1000011);

-- felwitheb: Est_Treewalker (62002, max_slot=18 → new slot=19)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 62002, 19, 1000011, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=62002 AND item=1000011);

-- freeporteast: Eywen_Nalous (382158, max_slot=75 → new slot=76)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 382158, 76, 1000011, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=382158 AND item=1000011);

-- qeynos: Corrao_Duperame (1021, max_slot=17 → new slot=18)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 1021, 18, 1000011, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=1021 AND item=1000011);

-- neriakb: Kizya_D`Dbth (41015, max_slot=18 → new slot=19)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 41015, 19, 1000011, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=41015 AND item=1000011);

-- sharvahl: Scribe_Qualia (155230, max_slot=20 → new slot=21)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 155230, 21, 1000011, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=155230 AND item=1000011);

-- ---- BEASTLORD (scroll 1000008: Scroll: Ancestral Call) ----
-- grobb: Tracab (49089, slot 21 after SHM/oggok share above)
-- NOTE: Tracab in grobb and Brogdog in oggok share merchant_id=49089.
--       SHM was already added at slot 20 for this merchant, so BST goes to slot 21.
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 49089, 21, 1000008, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=49089 AND item=1000008);

-- cabeast: Vessel_Kabda (106092, slot 20 after SHM above)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 106092, 20, 1000008, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=106092 AND item=1000008);

-- sharvahl: Scribe_Kaleej (155237, max_slot=19 → new slot=20)
INSERT INTO merchantlist (merchantid, slot, item, faction_required, level_required, classes_required, probability)
SELECT 155237, 20, 1000008, -100, 0, 65535, 100
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM merchantlist WHERE merchantid=155237 AND item=1000008);

-- =============================================================================
-- SECTION 4: character_spells — auto-scribe migration
-- One INSERT...SELECT per class. Idempotent via NOT EXISTS.
-- Slot pick: MIN(MAX(slot_id) + 1, 399) per character.
-- Targets: character_data.class IN (2,3,4,5,6,8,10,11,12,13,14,15), deleted_at IS NULL.
-- Class IDs: CLR=2, PAL=3, RNG=4, SHD=5, DRU=6, BRD=8, SHM=10, NEC=11, WIZ=12, MAG=13, ENC=14, BST=15
-- =============================================================================

-- CLR=2: Divine Reclamation (spell_id=9412)
INSERT INTO character_spells (id, slot_id, spell_id)
SELECT cd.id,
       LEAST(COALESCE((SELECT MAX(cs2.slot_id) FROM character_spells cs2 WHERE cs2.id = cd.id), -1) + 1, 399),
       9412
FROM character_data cd
WHERE cd.class = 2
  AND cd.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM character_spells cs WHERE cs.id = cd.id AND cs.spell_id = 9412);

-- PAL=3: Solemn Retrieval (spell_id=9413)
INSERT INTO character_spells (id, slot_id, spell_id)
SELECT cd.id,
       LEAST(COALESCE((SELECT MAX(cs2.slot_id) FROM character_spells cs2 WHERE cs2.id = cd.id), -1) + 1, 399),
       9413
FROM character_data cd
WHERE cd.class = 3
  AND cd.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM character_spells cs WHERE cs.id = cd.id AND cs.spell_id = 9413);

-- RNG=4: Warden's Claim (spell_id=9415)
INSERT INTO character_spells (id, slot_id, spell_id)
SELECT cd.id,
       LEAST(COALESCE((SELECT MAX(cs2.slot_id) FROM character_spells cs2 WHERE cs2.id = cd.id), -1) + 1, 399),
       9415
FROM character_data cd
WHERE cd.class = 4
  AND cd.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM character_spells cs WHERE cs.id = cd.id AND cs.spell_id = 9415);

-- SHD=5: Death's Recall (spell_id=5093)
INSERT INTO character_spells (id, slot_id, spell_id)
SELECT cd.id,
       LEAST(COALESCE((SELECT MAX(cs2.slot_id) FROM character_spells cs2 WHERE cs2.id = cd.id), -1) + 1, 399),
       5093
FROM character_data cd
WHERE cd.class = 5
  AND cd.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM character_spells cs WHERE cs.id = cd.id AND cs.spell_id = 5093);

-- DRU=6: Nature's Reclamation (spell_id=9414)
INSERT INTO character_spells (id, slot_id, spell_id)
SELECT cd.id,
       LEAST(COALESCE((SELECT MAX(cs2.slot_id) FROM character_spells cs2 WHERE cs2.id = cd.id), -1) + 1, 399),
       9414
FROM character_data cd
WHERE cd.class = 6
  AND cd.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM character_spells cs WHERE cs.id = cd.id AND cs.spell_id = 9414);

-- BRD=8: Dirge of Homecoming (spell_id=9421)
INSERT INTO character_spells (id, slot_id, spell_id)
SELECT cd.id,
       LEAST(COALESCE((SELECT MAX(cs2.slot_id) FROM character_spells cs2 WHERE cs2.id = cd.id), -1) + 1, 399),
       9421
FROM character_data cd
WHERE cd.class = 8
  AND cd.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM character_spells cs WHERE cs.id = cd.id AND cs.spell_id = 9421);

-- SHM=10: Ancestral Summons (spell_id=9416)
INSERT INTO character_spells (id, slot_id, spell_id)
SELECT cd.id,
       LEAST(COALESCE((SELECT MAX(cs2.slot_id) FROM character_spells cs2 WHERE cs2.id = cd.id), -1) + 1, 399),
       9416
FROM character_data cd
WHERE cd.class = 10
  AND cd.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM character_spells cs WHERE cs.id = cd.id AND cs.spell_id = 9416);

-- NEC=11: Conjure Cadaver (spell_id=1348)
INSERT INTO character_spells (id, slot_id, spell_id)
SELECT cd.id,
       LEAST(COALESCE((SELECT MAX(cs2.slot_id) FROM character_spells cs2 WHERE cs2.id = cd.id), -1) + 1, 399),
       1348
FROM character_data cd
WHERE cd.class = 11
  AND cd.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM character_spells cs WHERE cs.id = cd.id AND cs.spell_id = 1348);

-- WIZ=12: Spectral Translocation (spell_id=9418)
INSERT INTO character_spells (id, slot_id, spell_id)
SELECT cd.id,
       LEAST(COALESCE((SELECT MAX(cs2.slot_id) FROM character_spells cs2 WHERE cs2.id = cd.id), -1) + 1, 399),
       9418
FROM character_data cd
WHERE cd.class = 12
  AND cd.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM character_spells cs WHERE cs.id = cd.id AND cs.spell_id = 9418);

-- MAG=13: Summon Mortal Remains (spell_id=9419)
INSERT INTO character_spells (id, slot_id, spell_id)
SELECT cd.id,
       LEAST(COALESCE((SELECT MAX(cs2.slot_id) FROM character_spells cs2 WHERE cs2.id = cd.id), -1) + 1, 399),
       9419
FROM character_data cd
WHERE cd.class = 13
  AND cd.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM character_spells cs WHERE cs.id = cd.id AND cs.spell_id = 9419);

-- ENC=14: Phantasmal Reclamation (spell_id=9420)
INSERT INTO character_spells (id, slot_id, spell_id)
SELECT cd.id,
       LEAST(COALESCE((SELECT MAX(cs2.slot_id) FROM character_spells cs2 WHERE cs2.id = cd.id), -1) + 1, 399),
       9420
FROM character_data cd
WHERE cd.class = 14
  AND cd.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM character_spells cs WHERE cs.id = cd.id AND cs.spell_id = 9420);

-- BST=15: Ancestral Call (spell_id=9417)
INSERT INTO character_spells (id, slot_id, spell_id)
SELECT cd.id,
       LEAST(COALESCE((SELECT MAX(cs2.slot_id) FROM character_spells cs2 WHERE cs2.id = cd.id), -1) + 1, 399),
       9417
FROM character_data cd
WHERE cd.class = 15
  AND cd.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM character_spells cs WHERE cs.id = cd.id AND cs.spell_id = 9417);

-- =============================================================================
-- SECTION 5: rule_values — cooldown rule seed (config-expert also contributes this)
-- ruleset_id=1 (default and only active ruleset on this server)
-- =============================================================================

INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes)
SELECT 1, 'Spells:UniversalSummonCorpseCooldown', '180',
       'Cooldown in seconds for the universal summon corpse spell line (12 class-flavored level-1 self-summon spells). 0 disables cooldown. Default 180 (3 minutes). Hot-reloadable via #reloadrules.'
FROM DUAL
WHERE NOT EXISTS (
  SELECT 1 FROM rule_values
  WHERE ruleset_id = 1 AND rule_name = 'Spells:UniversalSummonCorpseCooldown'
);

COMMIT;
