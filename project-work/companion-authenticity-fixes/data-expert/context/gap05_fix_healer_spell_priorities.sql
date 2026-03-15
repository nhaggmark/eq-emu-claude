-- GAP-05: Fix shaman and healer spell list priorities
-- Feature: companion-authenticity-fixes
-- Date: 2026-03-14
--
-- Problem: Default Shaman List (ID 6), Default Druid List (ID 7), and
-- Default Ranger List (ID 10) have ALL spells at priority=1. This causes
-- the NPC AI to randomly pick among heals, buffs, nukes, and utility spells
-- instead of reliably healing injured group members first.
--
-- Fix: Apply differentiated priorities following the Default Cleric List (ID 1)
-- as the reference model (heals at priority 20/10, damage lower).
--
-- Priority scheme used:
--   20 = Heals (shaman) -- primary healer, heals must fire first
--   15 = Heals (druid)  -- secondary healer
--    8 = Heals (ranger) -- minor healer, heals are last resort
--   10 = Slows / ATK debuffs (shaman) -- critical combat utility
--    8 = Disease debuffs (shaman) -- important debuffs, below slows
--    7 = DoTs (type=256)
--    6 = DoTs (ranger type=256)
--    5 = DD nukes (type=1, effectid1=0)
--    3 = Roots (type=4)
--    2 = Snares (type=128) / Buffs (druid/ranger)
--    1 = Buffs (type=8, shaman), Dispel (type=512) -- cast when nothing else needed
--
-- NOTE: This script modifies EXISTING priority values only.
-- It does NOT add or remove spells from any list.

START TRANSACTION;

-- ============================================================
-- SHAMAN: Default Shaman List (npc_spells_id = 6)
-- ============================================================

-- Step 1: Heals (type=2) -> priority 20
-- Includes: Minor Healing, Light Healing, Healing, Greater Healing,
--           Superior Healing, Tnarg's Mending, Daluda's Mending,
--           Regrowth, Regeneration
UPDATE npc_spells_entries
SET priority = 20
WHERE npc_spells_id = 6 AND type = 2;

-- Step 2: Slows / ATK debuffs (type=1, effectid1=10) -> priority 10
-- Includes: Walking Sleep, Drowsy, Cloud of Grummus, Tagar's/Togor's/Tigir's/Turgur's Insects,
--           Disempower, Incapacitate, Listless Power, Malaise, Malaisement,
--           Malo, Malos, Malosi, Malosinia
UPDATE npc_spells_entries
SET priority = 10
WHERE npc_spells_id = 6 AND type = 1 AND spellid IN (
    505,   -- Walking Sleep
    270,   -- Drowsy
    3380,  -- Cloud of Grummus
    506,   -- Tagar's Insects
    507,   -- Togor's Insects
    1589,  -- Tigir's Insects
    1588,  -- Turgur's Insects
    281,   -- Disempower
    163,   -- Incapacitate
    162,   -- Listless Power
    110,   -- Malaise
    111,   -- Malaisement
    1578,  -- Malo
    3395,  -- Malos
    112,   -- Malosi
    3387,  -- Malosinia
    1577   -- Malosini (resist debuff, effectid1=46)
);

-- Step 3: Cripple (type=1, effectid1=5) -> priority 10
-- ATK/stat debuff, same tier as slows
UPDATE npc_spells_entries
SET priority = 10
WHERE npc_spells_id = 6 AND type = 1 AND spellid IN (
    1592   -- Cripple
);

-- Step 4: Disease debuffs (type=1, effectid1=35) -> priority 8
-- Includes: Insidious Decay, Insidious Fever, Insidious Malady, Malicious Decay,
--           Plague of Insects, Feralize
UPDATE npc_spells_entries
SET priority = 8
WHERE npc_spells_id = 6 AND type = 1 AND spellid IN (
    1573,  -- Insidious Decay
    526,   -- Insidious Fever
    527,   -- Insidious Malady
    3386,  -- Malicious Decay
    2527,  -- Plague of Insects
    9999   -- Feralize
);

-- Step 5: DoTs (type=256) -> priority 7
-- Includes: Sicken, Plague, Affliction, Infectious Cloud, Tainted Breath,
--           Envenomed Breath, Venom of the Snake, Envenomed Bolt,
--           Bane of Nife, Pox of Bertoxxulous, Breath of Ultor, Blood of Saryrn
UPDATE npc_spells_entries
SET priority = 7
WHERE npc_spells_id = 6 AND type = 256;

-- Step 6: DD Nukes (type=1, effectid1=0) -> priority 5
-- Includes: Frost Rift, Frost Strike, Ice Strike, Blizzard Blast, Winter's Roar,
--           Spirit Strike, Burst of Flame, Velium Strike, Shock of the Tainted,
--           Shock of Venom, Blast of Poison, Blast of Venom, Gale of Poison,
--           Poison Storm, Torrent of Poison, Spear of Torment, Tears of Saryrn
UPDATE npc_spells_entries
SET priority = 5
WHERE npc_spells_id = 6 AND type = 1 AND spellid IN (
    275,   -- Frost Rift
    508,   -- Frost Strike
    1586,  -- Ice Strike
    510,   -- Blizzard Blast
    509,   -- Winter's Roar
    282,   -- Spirit Strike
    93,    -- Burst of Flame
    3390,  -- Velium Strike
    1427,  -- Shock of the Tainted
    3573,  -- Shock of Venom
    1429,  -- Blast of Poison
    3574,  -- Blast of Venom
    438,   -- Gale of Poison
    437,   -- Poison Storm
    1587,  -- Torrent of Poison
    3379,  -- Spear of Torment
    3385   -- Tears of Saryrn
);

-- Step 7: Roots (type=4) -> priority 3
UPDATE npc_spells_entries
SET priority = 3
WHERE npc_spells_id = 6 AND type = 4;

-- Step 8: Buffs (type=8) -> priority 2
-- Spirit of Wolf, Avatar, Talisman of Tnarg, Focus buffs, etc.
-- Low priority -- only cast when no combat need
UPDATE npc_spells_entries
SET priority = 2
WHERE npc_spells_id = 6 AND type = 8;

-- Step 9: Dispel (type=512) -> priority 1
UPDATE npc_spells_entries
SET priority = 1
WHERE npc_spells_id = 6 AND type = 512;

-- ============================================================
-- DRUID: Default Druid List (npc_spells_id = 7)
-- ============================================================

-- Heals (type=2) -> priority 15 (secondary healer, below shaman)
-- Includes: Minor Healing through Nature's Recovery, Chloroblast, Chloroplast
UPDATE npc_spells_entries
SET priority = 15
WHERE npc_spells_id = 7 AND type = 2;

-- DoTs (type=256) -> priority 7
UPDATE npc_spells_entries
SET priority = 7
WHERE npc_spells_id = 7 AND type = 256;

-- DD Nukes (type=1) -> priority 5
UPDATE npc_spells_entries
SET priority = 5
WHERE npc_spells_id = 7 AND type = 1;

-- Roots (type=4) -> priority 3
UPDATE npc_spells_entries
SET priority = 3
WHERE npc_spells_id = 7 AND type = 4;

-- Snares (type=128) -> priority 2
UPDATE npc_spells_entries
SET priority = 2
WHERE npc_spells_id = 7 AND type = 128;

-- Buffs (type=8) -> priority 1
UPDATE npc_spells_entries
SET priority = 1
WHERE npc_spells_id = 7 AND type = 8;

-- Dispel (type=512) -> priority 1
UPDATE npc_spells_entries
SET priority = 1
WHERE npc_spells_id = 7 AND type = 512;

-- ============================================================
-- RANGER: Default Ranger List (npc_spells_id = 10)
-- ============================================================

-- Heals (type=2) -> priority 8 (minor healer -- heals in emergencies only)
-- Includes: Minor Healing, Light Healing, Healing, Greater Healing,
--           Chloroblast, Regrowth, Chloroplast
UPDATE npc_spells_entries
SET priority = 8
WHERE npc_spells_id = 10 AND type = 2;

-- DoTs (type=256) -> priority 6
UPDATE npc_spells_entries
SET priority = 6
WHERE npc_spells_id = 10 AND type = 256;

-- DD Nukes (type=1) -> priority 5
UPDATE npc_spells_entries
SET priority = 5
WHERE npc_spells_id = 10 AND type = 1;

-- Roots (type=4) -> priority 3
UPDATE npc_spells_entries
SET priority = 3
WHERE npc_spells_id = 10 AND type = 4;

-- Snares (type=128) -> priority 2
UPDATE npc_spells_entries
SET priority = 2
WHERE npc_spells_id = 10 AND type = 128;

-- Buffs (type=8) -> priority 1
UPDATE npc_spells_entries
SET priority = 1
WHERE npc_spells_id = 10 AND type = 8;

-- Dispel (type=512) -> priority 1
UPDATE npc_spells_entries
SET priority = 1
WHERE npc_spells_id = 10 AND type = 512;

COMMIT;

-- ============================================================
-- VERIFICATION QUERIES (run after applying to confirm)
-- ============================================================
-- Shaman heals should appear at top (priority 20):
-- SELECT nse.spellid, nse.type, sn.name, nse.priority
-- FROM npc_spells_entries nse
-- JOIN spells_new sn ON sn.id = nse.spellid
-- WHERE nse.npc_spells_id = 6
-- ORDER BY nse.priority DESC, nse.type;
--
-- Priority distribution summary:
-- SELECT nse.npc_spells_id, nse.priority, nse.type, COUNT(*) as cnt
-- FROM npc_spells_entries nse
-- WHERE nse.npc_spells_id IN (6, 7, 10)
-- GROUP BY nse.npc_spells_id, nse.priority, nse.type
-- ORDER BY nse.npc_spells_id, nse.priority DESC;
