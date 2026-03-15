-- GAP-07: Fix caster class spell list priorities
-- Feature: companion-authenticity-phase3-4
-- Date: 2026-03-15
--
-- Audit results:
--   Wizard     (ID 2): ALREADY CORRECT — 24 distinct priorities. No changes.
--   Necromancer(ID 3): ALREADY CORRECT — 22 distinct priorities. No changes.
--   Magician   (ID 4): BROKEN — all 54 spells at priority=1. FIXED below.
--   Enchanter  (ID 5): PARTIAL — mez/charm all at priority=1. FIXED below.
--   Paladin    (ID 8): BROKEN — all 41 spells at priority=1. FIXED below.
--   Shadow Knight(ID9): BROKEN — all 48 spells at priority=1. FIXED below.
--
-- Safe to re-apply (idempotent): all statements set absolute values.
--
-- Apply via:
--   docker exec -i akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq < gap07_caster_spell_priorities.sql

-- ============================================================
-- PRE-MIGRATION VERIFICATION
-- ============================================================

SELECT 'PRE-MIGRATION STATE' AS check_name;
SELECT
  npc_spells_id,
  COUNT(*) AS total,
  COUNT(DISTINCT priority) AS distinct_priorities,
  MAX(priority) AS max_priority,
  SUM(CASE WHEN priority = 1 THEN 1 ELSE 0 END) AS at_priority_1
FROM npc_spells_entries
WHERE npc_spells_id IN (4, 5, 8, 9)
GROUP BY npc_spells_id
ORDER BY npc_spells_id;

-- ============================================================
-- MAGICIAN (npc_spells_id = 4)
-- ============================================================
-- Role: DD nuker with elemental pets
-- Priority hierarchy:
--   18 = top-tier nukes (level 59+): Sun Storm, Black Steel, Maelstrom of Thunder, Sun Vortex
--   16 = level 51-58 nukes (Char, Scars of Sigil, Sirocco, Shock of Steel, Seeking Flame, Manastorm)
--   14 = level 44-50 nukes (Shock of Swords, Rain of Swords, Lava Bolt)
--   12 = level 34-43 nukes (Blaze, Rain of Lava)
--   10 = Malo debuff group (Malaise, Malaisement, Malosi, Malosini, Malosinia) — critical resist debuff
--    8 = level 20-33 nukes (Bolt of Flame, Shock of Spikes, Rain of Spikes)
--    6 = level 8-19 nukes (Shock of Blades, Flame Bolt, Rain of Blades, Column of Fire, Shock of Flame)
--    4 = level 1-7 nukes (Burst of Flame, Burn)
--    3 = pet AE nukes (type=256: Elemental Maelstrom, Wrath of the Elements)
--    1 = buffs (type=8), dispels (type=512) — no change needed

SELECT 'Applying Magician fixes (ID 4)...' AS status;

START TRANSACTION;

-- Top-tier nukes (level 59+)
UPDATE npc_spells_entries SET priority = 18
WHERE npc_spells_id = 4 AND type = 1
  AND spellid IN (3319, 3321, 3323, 3325);  -- Sun Storm, Black Steel, Maelstrom of Thunder, Sun Vortex

-- Level 51-58 nukes
UPDATE npc_spells_entries SET priority = 16
WHERE npc_spells_id = 4 AND type = 1
  AND spellid IN (1660, 1661, 1662, 1663, 1664, 1665);  -- Char, Scars of Sigil, Sirocco, Shock of Steel, Seeking Flame, Manastorm

-- Raging Servant (level 70, special)
UPDATE npc_spells_entries SET priority = 16
WHERE npc_spells_id = 4 AND type = 1
  AND spellid IN (8037);  -- Raging Servant

-- Level 44-50 nukes
UPDATE npc_spells_entries SET priority = 14
WHERE npc_spells_id = 4 AND type = 1
  AND spellid IN (114, 410, 70, 2540, 1394);  -- Shock of Swords, Rain of Swords, Lava Bolt, Shock of Fiery Blades, Maelstrom of Electricity

-- Level 34-43 nukes
UPDATE npc_spells_entries SET priority = 12
WHERE npc_spells_id = 4 AND type = 1
  AND spellid IN (120, 121);  -- Blaze, Rain of Lava

-- Malo debuff group (critical resist debuffs for pet/nuke setup)
UPDATE npc_spells_entries SET priority = 10
WHERE npc_spells_id = 4 AND type = 1
  AND spellid IN (110, 111, 112, 1577, 3387, 1772);  -- Malaise, Malaisement, Malosi, Malosini, Malosinia, Mala

-- Level 20-33 nukes
UPDATE npc_spells_entries SET priority = 8
WHERE npc_spells_id = 4 AND type = 1
  AND spellid IN (68, 83, 113, 409);  -- Bolt of Flame, Rain of Fire, Shock of Spikes, Rain of Spikes

-- Level 8-19 nukes
UPDATE npc_spells_entries SET priority = 6
WHERE npc_spells_id = 4 AND type = 1
  AND spellid IN (324, 322, 330, 328, 334);  -- Shock of Blades, Flame Bolt, Rain of Blades, Column of Fire, Shock of Flame

-- Level 1-7 nukes
UPDATE npc_spells_entries SET priority = 4
WHERE npc_spells_id = 4 AND type = 1
  AND spellid IN (93, 94);  -- Burst of Flame, Burn

-- Pet AE nukes (type=256)
UPDATE npc_spells_entries SET priority = 3
WHERE npc_spells_id = 4 AND type = 256;  -- Elemental Maelstrom, Wrath of the Elements

-- (type=8 buffs and type=512 dispels remain at priority=1 — no update needed)

COMMIT;

SELECT 'Magician (ID 4) fixes applied.' AS status;

-- ============================================================
-- ENCHANTER (npc_spells_id = 5)
-- ============================================================
-- Role: CC (mez primary, charm secondary), debuffer, haste buffer
-- Priority hierarchy:
--   18 = Mez (type=2048) — PRIMARY combat role
--   12 = Charm (type=4096) — powerful but risky CC
--   10 = Tash/slow/cripple debuffs (type=1: Tashina, Tashani, Tashania, Tashanian, Wind of Tashanian,
--        Howl of Tashan, Cripple — these set up mez and reduce mob effectiveness)
--    8 = Gravity Flux and other direct-effect type=1 disruptors (leave existing priority=15 alone)
--    5 = Fear spells (type=1, effectid1=23: Fear, Eye of Confusion, Invoke Fear) — CC fallback
--    3 = Roots (type=4) — soft CC
--    2 = DoTs (type=256: Shallow Breath through Strangle) — minor damage over time
--    1 = Buffs (type=8), Dispels (type=512), and remaining type=1 debuffs — stay at 1
--
-- NOTE: Gravity Flux (spellid=73, priority=15) and Command of Druzzil (spellid=3355, priority=15)
-- are already correctly set. Do NOT touch those.

SELECT 'Applying Enchanter fixes (ID 5)...' AS status;

START TRANSACTION;

-- Mez spells (type=2048) — PRIMARY role, highest priority
UPDATE npc_spells_entries SET priority = 18
WHERE npc_spells_id = 5 AND type = 2048;
-- Covers: Mesmerize, Mesmerization, Enthrall, Entrance, Dazzle, Glamour of Kintaz,
--         Rapture, Apathy, Bliss

-- Charm spells (type=4096) — elevate lower-tier charms; leave Command of Druzzil(15) alone
UPDATE npc_spells_entries SET priority = 12
WHERE npc_spells_id = 5 AND type = 4096 AND spellid != 3355;
-- Covers: Charm, Beguile, Cajoling Whispers, Allure, Boltran's Agacerie, Dictate, Beckon
-- (Command of Druzzil stays at 15 — it's already appropriate)

-- Tash debuff group + Cripple (key setup spells)
UPDATE npc_spells_entries SET priority = 10
WHERE npc_spells_id = 5 AND type = 1
  AND spellid IN (676, 677, 678, 1702, 1704, 3342, 1592);
-- Tashina, Tashani, Tashania, Tashanian, Wind of Tashanian, Howl of Tashan, Cripple

-- Fear spells (CC fallback when mez is on cooldown)
UPDATE npc_spells_entries SET priority = 5
WHERE npc_spells_id = 5 AND type = 1
  AND spellid IN (229, 297, 127);
-- Fear, Eye of Confusion, Invoke Fear

-- Roots (soft CC — less preferred than mez but useful)
UPDATE npc_spells_entries SET priority = 3
WHERE npc_spells_id = 5 AND type = 4;
-- Root, Instill, Fetter, Greater Fetter (and Paralyzing Earth/Immobilize which were already at 3/2)

-- DoTs (secondary damage — lower than roots)
UPDATE npc_spells_entries SET priority = 2
WHERE npc_spells_id = 5 AND type = 256;
-- Shallow Breath, Suffocating Sphere, Choke, Suffocate, Gasping Embrace, Asphyxiate, Strangle

-- (type=8 buffs and type=512 dispels and remaining type=1 debuffs stay at 1)
-- (Gravity Flux priority=15 and Command of Druzzil priority=15 are left untouched)

COMMIT;

SELECT 'Enchanter (ID 5) fixes applied.' AS status;

-- ============================================================
-- PALADIN (npc_spells_id = 8)
-- ============================================================
-- Role: Hybrid healer/tank
-- Priority hierarchy:
--   20 = Heals (type=2) — primary healer role in absence of cleric
--   10 = Stuns (type=1, effectid1=21: Holy Might, Force, Quellious' Word, Force of Akilae) — signature CC
--    8 = DD nuke (type=1, effectid1=0: Flame of Light) — damage when mobs are stunnable
--    5 = Roots (type=4) — soft CC
--    3 = Yaulp (type=1024) — self-proc enhancer buffs (cast at start, low urgency in combat)
--    1 = Buffs (type=8), Dispels (type=512) — low urgency

SELECT 'Applying Paladin fixes (ID 8)...' AS status;

START TRANSACTION;

-- Heals (PRIMARY role — equivalent to cleric priority)
UPDATE npc_spells_entries SET priority = 20
WHERE npc_spells_id = 8 AND type = 2;
-- Minor Healing, Light Healing, Healing, Greater Healing, Ethereal Cleansing, Light of Life,
-- Superior Healing, Celestial Cleansing, Touch of Nife, Light of Nife, Supernal Cleansing

-- Stuns (effectid1=21 in type=1)
UPDATE npc_spells_entries SET priority = 10
WHERE npc_spells_id = 8 AND type = 1
  AND spellid IN (123, 124, 2587, 3245);
-- Holy Might, Force, Quellious' Word of Tranquility, Force of Akilae

-- DD nuke (effectid1=0 in type=1)
UPDATE npc_spells_entries SET priority = 8
WHERE npc_spells_id = 8 AND type = 1
  AND spellid IN (1454);
-- Flame of Light

-- Roots
UPDATE npc_spells_entries SET priority = 5
WHERE npc_spells_id = 8 AND type = 4;
-- Root, Instill, Greater Immobilize, Shackles of Tunare

-- Yaulp (self-proc enhancer — cast at engagement start, not combat-critical)
UPDATE npc_spells_entries SET priority = 3
WHERE npc_spells_id = 8 AND type = 1024;
-- Yaulp, Yaulp II, Yaulp III, Yaulp IV

-- (type=8 buffs and type=512 dispels stay at priority=1)

COMMIT;

SELECT 'Paladin (ID 8) fixes applied.' AS status;

-- ============================================================
-- SHADOW KNIGHT (npc_spells_id = 9)
-- ============================================================
-- Role: Lifetap sustain + snare utility + DoT damage
-- Priority hierarchy:
--   20 = Lifetaps (type=64) — core damage AND self-healing (dual role)
--   12 = Snares/Darkness (type=128) — critical for holding mobs in melee range
--    8 = DoTs (type=256) — ongoing damage (Heat Blood, Heart Flutter, Boil Blood, etc.)
--    6 = STR/ATK debuffs (type=1, effectid1=10: Despair, Siphon Strength, Scream of Hate,
--        Shadow Vortex, Shroud of Hate, Shroud of Pain, Abduction of Strength, Torrent series,
--        Aura of Pain)
--    5 = DD nukes (type=1, effectid1=0: Spear of Disease, Spear of Pain, Spear of Plague, Spear of Decay)
--    3 = Fear spells (type=1, effectid1=23: Fear, Invoke Fear) — CC utility
--    2 = Enfeeblement (type=1, effectid1=4: Wave of Enfeeblement)
--    1 = Buffs (type=8), Dispels (type=512)

SELECT 'Applying Shadow Knight fixes (ID 9)...' AS status;

START TRANSACTION;

-- Lifetaps (PRIMARY role — damage + self-healing simultaneously)
UPDATE npc_spells_entries SET priority = 20
WHERE npc_spells_id = 9 AND type = 64;
-- Lifetap, Lifespike, Lifedraw, Life Leech, Siphon Life, Spirit Tap, Drain Spirit, Drain Soul,
-- Touch of Volatis, Touch of Innoruuk

-- Snares/Darkness (keep mobs in melee range)
UPDATE npc_spells_entries SET priority = 12
WHERE npc_spells_id = 9 AND type = 128;
-- Clinging Darkness, Engulfing Darkness, Dooming Darkness, Cascading Darkness, Festering Darkness

-- DoTs (secondary damage over time)
UPDATE npc_spells_entries SET priority = 8
WHERE npc_spells_id = 9 AND type = 256;
-- Disease Cloud, Heat Blood, Heart Flutter, Boil Blood, Asystole, Ignite Blood

-- STR/ATK debuffs (type=1, effectid1=10)
UPDATE npc_spells_entries SET priority = 6
WHERE npc_spells_id = 9 AND type = 1
  AND spellid IN (2571, 343, 2572, 370, 1457, 1458, 2575, 2577, 2578, 2579, 3403);
-- Despair, Siphon Strength, Scream of Hate, Shadow Vortex, Shroud of Hate, Shroud of Pain,
-- Abduction of Strength, Torrent of Hate, Torrent of Pain, Torrent of Fatigue, Aura of Pain

-- DD nukes (type=1, effectid1=0)
UPDATE npc_spells_entries SET priority = 5
WHERE npc_spells_id = 9 AND type = 1
  AND spellid IN (3561, 3560, 3562, 3491);
-- Spear of Disease, Spear of Pain, Spear of Plague, Spear of Decay

-- Fear spells (type=1, effectid1=23)
UPDATE npc_spells_entries SET priority = 3
WHERE npc_spells_id = 9 AND type = 1
  AND spellid IN (229, 127);
-- Fear, Invoke Fear

-- Enfeeblement (type=1, effectid1=4)
UPDATE npc_spells_entries SET priority = 2
WHERE npc_spells_id = 9 AND type = 1
  AND spellid IN (363);
-- Wave of Enfeeblement

-- (type=8 buffs and type=512 dispels stay at priority=1)

COMMIT;

SELECT 'Shadow Knight (ID 9) fixes applied.' AS status;

-- ============================================================
-- POST-MIGRATION VERIFICATION
-- ============================================================

SELECT 'POST-MIGRATION STATE' AS check_name;
SELECT
  npc_spells_id,
  COUNT(*) AS total,
  COUNT(DISTINCT priority) AS distinct_priorities,
  MAX(priority) AS max_priority,
  SUM(CASE WHEN priority = 1 THEN 1 ELSE 0 END) AS still_at_priority_1
FROM npc_spells_entries
WHERE npc_spells_id IN (4, 5, 8, 9)
GROUP BY npc_spells_id
ORDER BY npc_spells_id;

SELECT 'Magician (4) priority distribution:' AS check_name;
SELECT type, priority, COUNT(*) AS cnt
FROM npc_spells_entries WHERE npc_spells_id = 4
GROUP BY type, priority ORDER BY priority DESC, type;

SELECT 'Enchanter (5) priority distribution (CC types only):' AS check_name;
SELECT type, priority, COUNT(*) AS cnt
FROM npc_spells_entries WHERE npc_spells_id = 5 AND type IN (2048, 4096, 1, 4)
GROUP BY type, priority ORDER BY type, priority DESC;

SELECT 'Paladin (8) priority distribution:' AS check_name;
SELECT type, priority, COUNT(*) AS cnt
FROM npc_spells_entries WHERE npc_spells_id = 8
GROUP BY type, priority ORDER BY priority DESC, type;

SELECT 'Shadow Knight (9) priority distribution:' AS check_name;
SELECT type, priority, COUNT(*) AS cnt
FROM npc_spells_entries WHERE npc_spells_id = 9
GROUP BY type, priority ORDER BY priority DESC, type;
