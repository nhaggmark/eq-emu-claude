-- Phase 2 Classic Raid Scaling — Implementation SQL
-- Date: 2026-04-22
-- PREREQUISITE: 01-backup-tables.sql must have run successfully first.
-- Three sections:
--   A. npc_types HP/damage UPDATEs (~49 rows)
--   B. spawn2 respawn UPDATEs (~40 rows)
--   C. npc_spells_entries DELETE for Cazic Touch (3 rows)
--   D. Post-change verification queries

-- ============================================================
-- SECTION A: npc_types HP/damage UPDATEs
-- ============================================================

-- ---- Classic Dragons ----
-- Lord Nagafen: 32000 -> 14400 (55% cut)
UPDATE npc_types SET hp = 14400 WHERE id = 32040;
-- Lady Vox: 32000 -> 14400 (55% cut)
UPDATE npc_types SET hp = 14400 WHERE id = 73057;
-- Phinigel Autropos: 18000 -> 13500 (25% cut)
UPDATE npc_types SET hp = 13500 WHERE id = 64001;

-- ---- Plane of Fear bosses ----
-- Dread: 32500 -> 20000 (38% cut)
UPDATE npc_types SET hp = 20000 WHERE id = 72000;
-- Terror: 32500 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 72002;
-- Fright: 32500 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 72004;
-- Wraith of a Shissar: 25000 -> 17500 (30% cut)
UPDATE npc_types SET hp = 17500 WHERE id = 72001;
-- The Tempest Reaver: 35000 -> 21000 (40% cut)
UPDATE npc_types SET hp = 21000 WHERE id = 72012;
-- a_dracoliche: 175000 -> 40000 (77% cut), maxdmg 595 -> 420
UPDATE npc_types SET hp = 40000, maxdmg = 420 WHERE id = 72090;
-- Cazic Thule: 451000 -> 80000 (82% cut), maxdmg 603 -> 450
-- NOTE: special_abilities NOT edited — CT's `3,1,10` param0 is unused by rampage AI.
--       Global Combat:MaxRampageTargets=2 already caps rampage. No per-NPC edit needed.
UPDATE npc_types SET hp = 80000, maxdmg = 450 WHERE id = 72003;

-- Q13 PoFear triggered additions
-- Ireblind Imp: 139500 -> 35000 (75% cut)
UPDATE npc_types SET hp = 35000 WHERE id = 72069;
-- an_enraged_golem: 175000 -> 40000 (77% cut) — Wizard epic
UPDATE npc_types SET hp = 40000 WHERE id = 72106;
-- Enraged Imp: 25000 -> 18000 (28% cut; already near named-tier)
UPDATE npc_types SET hp = 18000 WHERE id = 72108;

-- ---- Plane of Hate classic (hateplane) ----
-- Innoruuk classic: 33349 -> 20000, maxdmg 379 -> 300
UPDATE npc_types SET hp = 20000, maxdmg = 300 WHERE id = 76007;
-- Maestro of Rancor: 16228 -> 14600 (minimal cut — already near named)
UPDATE npc_types SET hp = 14600 WHERE id = 76011;
-- Hand of the Maestro: 10870 -> 10870 (leave — already in named range)
-- 76015 left alone — HP 10870 is named-tier
-- Grandmaster R`Tal: 29305 -> 20500
UPDATE npc_types SET hp = 20500 WHERE id = 76017;
-- Corrupter of Life (classic hateplane): 21000 -> 18000
UPDATE npc_types SET hp = 18000 WHERE id = 76018;
-- High Priest M`kari: 29305 -> 20500
UPDATE npc_types SET hp = 20500 WHERE id = 76042;
-- Avatar of Abhorrence (classic): 29305 -> 20500
UPDATE npc_types SET hp = 20500 WHERE id = 76043;
-- Master of Spite: 29305 -> 20500
UPDATE npc_types SET hp = 20500 WHERE id = 76044;
-- Mistress of Scorn: 29305 -> 20500
UPDATE npc_types SET hp = 20500 WHERE id = 76045;

-- ---- Plane of Hate REVAMP (hateplaneb) ----
-- Innoruuk revamp: 100200 -> 60000, maxdmg 822 -> 500
UPDATE npc_types SET hp = 60000, maxdmg = 500 WHERE id = 186158;
-- Hand of the Maestro revamp: 32000 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 186025;
-- Mistress_A`Zara: 19000 -> 15000
UPDATE npc_types SET hp = 15000 WHERE id = 186151;
-- The Deathrot Knight: 35000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 186153;
-- Lord of Ire: 32000 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 186154;
-- Lord of Loathing: already 15000 — leave (named-tier range)
-- 186155 left alone
-- Master R`Tal (revamp): 32000 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 186156;
-- Magi P`Tasa: 32000 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 186157;
-- Mistress of Scorn (revamp): 33000 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 186159;
-- Coercer T`vala: 32000 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 186160;
-- an_ashenbone_broodmaster: 32000 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 186161;
-- Avatar of Abhorrence (revamp): 32000 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 186163;
-- Vicar M`Kari: already 15000 — leave (named-tier)
-- 186164 left alone
-- Master of Spite (revamp): 32000 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 186165;
-- Assassin Z`Jrix: already 21000 — leave
-- 186167 left alone
-- Sorcerer C`Gazin: already 21000 — leave
-- 186168 left alone
-- Evangelist W`Rixxus: already 21000 — leave
-- 186169 left alone
-- Dread Knight T`Kamax: 29000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 186170;
-- Warlord E`Prosio: already 21000 — leave
-- 186171 left alone
-- Spy Master I`Kavin: already 25000 — leave (upper named range, L65)
-- 186172 left alone
-- Overlord R`Gahbsa: already 25000 — leave
-- 186173 left alone
-- Dreadlord M`Noxin: already 25000 — leave
-- 186174 left alone
-- Archon G`Uvin: already 25000 — leave
-- 186175 left alone
-- Arch Lich T`Vaxok: already 25000 — leave
-- 186176 left alone
-- Arcanist V`Gimis: already 25000 — leave
-- 186177 left alone
-- Master of Vengence: 29305 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 186178;
-- Mistress of Malevolence: already 23000 — leave
-- 186181 left alone
-- Warlock J`Rath: 29000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 186182;
-- Grandmaster H`Qilm: already 23000 — leave
-- 186183 left alone
-- Master D`Samni: already 23000 — leave
-- 186184 left alone
-- Grim Abhorrent Kaltik: 29000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 186186;
-- Lord of Fury: 29000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 186187;
-- Templar J`Rosix: 29000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 186188;
-- Corrupter of Life (hateplaneb): already 25000 — leave
-- 186189 left alone
-- Evangelist of Hate: 200000 -> 60000, maxdmg 1200 -> 600
UPDATE npc_types SET hp = 60000, maxdmg = 600 WHERE id = 186198;

-- ---- Plane of Sky ----
-- The Spiroc Lord: 32000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 71012;
-- Noble Dojorn: 32000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 71057;
-- Gorgalosk: 29000 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 71021;
-- a_thunder_spirit_princess: 20000 -> 17000
UPDATE npc_types SET hp = 17000 WHERE id = 71032;
-- Eye of Veeshan: 32000 -> 25600
UPDATE npc_types SET hp = 25600 WHERE id = 71065;
-- Keeper of Souls: 32000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 71075;
-- Bazzt Zzzt: 32000 -> 22000, maxdmg 941 -> 700
UPDATE npc_types SET hp = 22000, maxdmg = 700 WHERE id = 71072;
-- Q13 PoSky additions
-- Overseer of Air: 32000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 71034;
-- Protector of Sky: 21400 -> 17000
UPDATE npc_types SET hp = 17000 WHERE id = 71059;
-- the Hand of Veeshan: 32000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 71060;
-- Sister of the Spire: 17000 -> 12000
UPDATE npc_types SET hp = 12000 WHERE id = 71076;
-- NOTE: essence tamer 71071 (11500 HP) — already named-tier, no HP change.

-- ---- Cazic Thule zone event mobs ----
-- a_boiling_ooze: 140750 -> 35000
UPDATE npc_types SET hp = 35000 WHERE id = 48211;
-- Avatar of Dread: 84000 -> 30000
UPDATE npc_types SET hp = 30000 WHERE id = 48237;
-- Avatar of Fright: 84000 -> 30000
UPDATE npc_types SET hp = 30000 WHERE id = 48239;
-- Avatar of Terror: 84000 -> 30000
UPDATE npc_types SET hp = 30000 WHERE id = 48240;
-- a_Spinechill_Spider: 56000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 48245;
-- a_Gorgon: 56000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 48246;
-- a_Shiverback: 96000 -> 25000
UPDATE npc_types SET hp = 25000 WHERE id = 48247;
-- Amygdalan Knight: 73000 -> 22000
UPDATE npc_types SET hp = 22000 WHERE id = 48248;
-- Guard Thrasciss: 37000 -> 18000
UPDATE npc_types SET hp = 18000 WHERE id = 48249;
-- Guard Khataruss: 37000 -> 18000
UPDATE npc_types SET hp = 18000 WHERE id = 48250;
-- Guard Scithiss: 37000 -> 18000
UPDATE npc_types SET hp = 18000 WHERE id = 48251;
-- a_Tentacle_Terror: 50000 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 48252;

-- ---- Misc Classic ----
-- a_Thul_Tae_Ew_High_Priest: 50000 -> 25000
UPDATE npc_types SET hp = 25000 WHERE id = 48041;
-- Zordakalicus Ragefire: 33000 -> 26000
UPDATE npc_types SET hp = 26000 WHERE id = 91090;
-- Guardian of the Seal: 124000 -> 87000 (30% cut, L70 boss)
UPDATE npc_types SET hp = 87000 WHERE id = 39115;

-- NOTE: Kithicor Night Crew (IDs 20054-20064) EXCLUDED per Decision #20.
--       Already in scaled-named HP range (12k-27k). No changes.

-- ============================================================
-- SECTION B: spawn2 respawn time UPDATEs
-- ============================================================

-- 6h (21600s) for most Classic raid bosses
-- JOIN-based UPDATE scoped to explicit NPC ID list
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
JOIN npc_types nt ON nt.id = se.npcID
SET s2.respawntime = 21600
WHERE nt.id IN (
    32040, 73057, 64001,                   -- Nagafen, Vox, Phinigel
    72000, 72001, 72002, 72004, 72012,     -- PoFear bosses (CT excluded)
    72090,                                  -- a_dracoliche
    76007, 76011, 76018,                   -- PoHate classic (Innoruuk, Maestro, Corrupter)
    76017, 76042, 76043, 76044, 76045,     -- PoHate classic council
    71012, 71057, 71021, 71032, 71065,     -- PoSky bosses with spawnentry
    48041, 91090                            -- Thul Tae Ew, Zordakalicus
);

-- 12h (43200s) for Cazic Thule (endgame-adjacent per Decision #8)
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
JOIN npc_types nt ON nt.id = se.npcID
SET s2.respawntime = 43200
WHERE nt.id = 72003;

-- 12h (43200s) for Guardian of the Seal (L70, mid-tier per Decision #8)
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
JOIN npc_types nt ON nt.id = se.npcID
SET s2.respawntime = 43200
WHERE nt.id = 39115;

-- hateplaneb: 186183 Grandmaster H`Qilm has 194400s (54h) — reduce to 21600s (6h)
-- All other hateplaneb bosses are at 900s/2700s/10800s DZ timers — leave untouched.
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
JOIN npc_types nt ON nt.id = se.npcID
SET s2.respawntime = 21600
WHERE nt.id = 186183;

-- NOTE: PoSky triggered NPCs (71034, 71059, 71060, 71071, 71072, 71075, 71076,
--       186158, 186198, cazicthule event mobs) have no spawn2 rows — JOIN skips them
--       silently, which is correct (script-spawned, no spawn2 entry).

-- ============================================================
-- SECTION C: npc_spells_entries DELETE — Cazic Touch removal
-- ============================================================

-- Remove spell 982 "Cazic Touch" (-100,000 HP, 0 cast time, 0 mana — instant kill)
-- from three Plane of Sky boss spell lists
DELETE FROM npc_spells_entries
WHERE npc_spells_id IN (118, 449, 969)
  AND spellid = 982;
-- Expected: exactly 3 rows deleted
-- Spell lists:
--   118 = The Spiroc Lord
--   449 = Bazzt Zzzt
--   969 = Keeper of Souls
-- Remaining entries (988 Greater Spiroc Thunder, 897 Rotting Flesh, 899 Whirl) preserved.

-- ============================================================
-- SECTION D: Post-change verification queries
-- ============================================================

SELECT '=== VERIFICATION QUERIES ===' AS '';

-- Classic dragons
SELECT 'Nagafen HP (expect 14400)' AS check_name, hp AS actual FROM npc_types WHERE id = 32040;
SELECT 'Vox HP (expect 14400)' AS check_name, hp AS actual FROM npc_types WHERE id = 73057;
SELECT 'Phinigel HP (expect 13500)' AS check_name, hp AS actual FROM npc_types WHERE id = 64001;

-- PoFear
SELECT 'Cazic Thule HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 72003;
SELECT 'Cazic Thule maxdmg (expect 450)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 72003;
SELECT 'CT special_abilities (param0 should still be 10, unchanged)' AS check_name, special_abilities AS actual FROM npc_types WHERE id = 72003;
SELECT 'dracoliche HP (expect 40000)' AS check_name, hp AS actual FROM npc_types WHERE id = 72090;
SELECT 'dracoliche maxdmg (expect 420)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 72090;
SELECT 'Dread HP (expect 20000)' AS check_name, hp AS actual FROM npc_types WHERE id = 72000;
SELECT 'Terror HP (expect 20000)' AS check_name, hp AS actual FROM npc_types WHERE id = 72002;
SELECT 'Fright HP (expect 20000)' AS check_name, hp AS actual FROM npc_types WHERE id = 72004;
SELECT 'Wreith of Shissar HP (expect 17500)' AS check_name, hp AS actual FROM npc_types WHERE id = 72001;
SELECT 'Tempest Reaver HP (expect 21000)' AS check_name, hp AS actual FROM npc_types WHERE id = 72012;
SELECT 'Ireblind Imp HP (expect 35000)' AS check_name, hp AS actual FROM npc_types WHERE id = 72069;
SELECT 'Enraged Golem HP (expect 40000)' AS check_name, hp AS actual FROM npc_types WHERE id = 72106;
SELECT 'Enraged Imp HP (expect 18000)' AS check_name, hp AS actual FROM npc_types WHERE id = 72108;

-- PoHate
SELECT 'Innoruuk classic HP (expect 20000)' AS check_name, hp AS actual FROM npc_types WHERE id = 76007;
SELECT 'Innoruuk classic maxdmg (expect 300)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 76007;
SELECT 'Maestro HP (expect 14600)' AS check_name, hp AS actual FROM npc_types WHERE id = 76011;

-- hateplaneb
SELECT 'Innoruuk revamp HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 186158;
SELECT 'Innoruuk revamp maxdmg (expect 500)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 186158;
SELECT 'Evangelist of Hate HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 186198;
SELECT 'Evangelist of Hate maxdmg (expect 600)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 186198;

-- PoSky
SELECT 'Spiroc Lord HP (expect 22000)' AS check_name, hp AS actual FROM npc_types WHERE id = 71012;
SELECT 'Keeper of Souls HP (expect 22000)' AS check_name, hp AS actual FROM npc_types WHERE id = 71075;
SELECT 'Bazzt Zzzt HP (expect 22000)' AS check_name, hp AS actual FROM npc_types WHERE id = 71072;
SELECT 'Bazzt Zzzt maxdmg (expect 700)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 71072;
SELECT 'Eye of Veeshan HP (expect 25600)' AS check_name, hp AS actual FROM npc_types WHERE id = 71065;
SELECT 'essence tamer HP (expect 11500 unchanged)' AS check_name, hp AS actual FROM npc_types WHERE id = 71071;

-- Death-touch removal
SELECT 'Cazic Touch rows in spell lists 118/449/969 (expect 0)' AS check_name, COUNT(*) AS actual
FROM npc_spells_entries
WHERE npc_spells_id IN (118, 449, 969) AND spellid = 982;

SELECT 'Remaining entries in lists 118/449/969 (expect 3 - one per list)' AS check_name, COUNT(*) AS actual
FROM npc_spells_entries
WHERE npc_spells_id IN (118, 449, 969);

-- Respawn timers
SELECT 'Nagafen respawn (expect 21600)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 32040 LIMIT 1;

SELECT 'CT respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 72003 LIMIT 1;

SELECT 'Guardian of Seal respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 39115 LIMIT 1;

SELECT 'PoHate council respawn NOT changed (expect 1440)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 76017 LIMIT 1;
