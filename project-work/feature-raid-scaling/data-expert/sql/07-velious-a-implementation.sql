-- Phase 4a Velious non-ToV Raid Scaling — Implementation SQL
-- Date: 2026-04-22
-- PREREQUISITE: 06-velious-a-backup-tables.sql must have run successfully first.
-- Four sections:
--   A. npc_types HP/damage UPDATEs (~46 rows)
--   B. spawn2 respawn UPDATEs (~14 rows to 43200s; others already at target or shorter)
--   C. Post-change verification queries
--
-- User decisions applied:
--   Q5 = 12h (43200s) for Velious non-ToV mid-tier endgame bosses
--   Q23 = Option D: SQL wave-mob HP cuts (Lever 1 only); Lever 2 Lua NOT applied this pass
--   Q24 = Option A: scale BOTH Lord Yelinak variants (114106 and 114618)
--   Q25 = out of scope (faction grinds — separate future initiative)
--   Q26 = out of scope (Ring 8/9 UX timers)
--   Q27 = Jester (126012) INCLUDED per user decision
--
-- No npc_spells_entries changes (zero death-touch-profile spells in Phase 4a scope).
-- No special_abilities edits (Decision #11: preserve signature mechanics).
-- No C++, Perl changes. No Lua changes (Lever 2 is conditional fallback only).
-- OUT OF SCOPE: 113457 Avatar of War, 124155 Vulak'Aerr, ToV proper, Sleeper's Tomb.

-- ============================================================
-- SECTION A: npc_types HP/damage UPDATEs
-- ============================================================

-- ---- Kael Drakkel ----
-- King Tormax: 452k -> 100k HP (78% cut; 575 maxdmg left as-is — reasonable for L70)
UPDATE npc_types SET hp = 100000                       WHERE id = 113215;
-- Statue of Rallos Zek: 400,750 -> 50,000 HP (88% cut), 1,100 -> 500 maxdmg (one-shot-risk fix)
UPDATE npc_types SET hp = 50000, maxdmg = 500          WHERE id = 113071;
-- Idol of Rallos Zek (triggered, no spawn2): 650k -> 130k HP, 1,100 -> 700 maxdmg
UPDATE npc_types SET hp = 130000, maxdmg = 700         WHERE id = 113341;
-- Derakor the Vindicator: 180k -> 60k HP, 700 -> 560 maxdmg (20% trim for combat feel)
UPDATE npc_types SET hp = 60000, maxdmg = 560          WHERE id = 113118;

-- ---- Skyshrine ----
-- Lord Yelinak (main, 500k): -> 110k HP (78% cut). Q24=Option A: scale both variants.
UPDATE npc_types SET hp = 110000                       WHERE id = 114106;
-- Lord Yelinak (variant, 297k): -> 110k HP for consistent target (DB sweep: both live)
UPDATE npc_types SET hp = 110000                       WHERE id = 114618;
-- Charayan the Crusader: 233k -> 50k HP (79% cut; short respawn 640s preserved)
UPDATE npc_types SET hp = 50000                        WHERE id = 114242;
-- Susarrak the Crusader: 233k -> 50k HP
UPDATE npc_types SET hp = 50000                        WHERE id = 114243;
-- Grendish the Crusader: 233k -> 50k HP
UPDATE npc_types SET hp = 50000                        WHERE id = 114245;
-- Jortreva the Crusader: 233k -> 50k HP
UPDATE npc_types SET hp = 50000                        WHERE id = 114246;

-- ---- Plane of Growth ----
-- #_Tunare: 530k -> 150k HP (72% cut)
UPDATE npc_types SET hp = 150000                       WHERE id = 127001;
-- Guardian of Tunare (main ID): 310k -> 80k HP (74% cut)
UPDATE npc_types SET hp = 80000                        WHERE id = 127007;
-- Guardian of Tunare (duplicate ID): 310k -> 80k HP for consistency
UPDATE npc_types SET hp = 80000                        WHERE id = 127106;
-- Ail the Elder: 215k -> 60k HP, 700 -> 560 maxdmg (20% trim on 700-dmg bosses)
UPDATE npc_types SET hp = 60000, maxdmg = 560          WHERE id = 127020;
-- Rumbleroot: 193k -> 55k HP, 700 -> 560 maxdmg
UPDATE npc_types SET hp = 55000, maxdmg = 560          WHERE id = 127019;
-- Treah Greenroot: 191k -> 55k HP, 700 -> 560 maxdmg
UPDATE npc_types SET hp = 55000, maxdmg = 560          WHERE id = 127021;
-- Guardian of Takish: 200k -> 60k HP (maxdmg 210 already reasonable)
UPDATE npc_types SET hp = 60000                        WHERE id = 127035;
-- Fayl Everstrong: 150k -> 45k HP, 700 -> 560 maxdmg
UPDATE npc_types SET hp = 45000, maxdmg = 560          WHERE id = 127018;
-- Prince Thirneg: 69,719 -> 60,000 HP (~14% trim to bring into named-tier band)
UPDATE npc_types SET hp = 60000                        WHERE id = 127096;

-- ---- Plane of Mischief (in-era Jester only) ----
-- #the_Mischievous_Jester: 200k -> 60k HP, 1,431 -> 780 maxdmg (45% cut; condition=2 gated)
-- NOTE: Bristlebane (126160) L75 and All-Seeing Eye (126374) L75 are OUT-OF-ERA — NOT touched.
UPDATE npc_types SET hp = 60000, maxdmg = 780          WHERE id = 126012;

-- ---- Outdoor Dragons (Sleeper's Tomb key path) ----
-- Sontalak: 97.5k -> 40k HP (59% cut; ST key path boss)
UPDATE npc_types SET hp = 40000                        WHERE id = 120005;
-- Klandicar: 97.5k -> 40k HP (59% cut; ST key path boss)
UPDATE npc_types SET hp = 40000                        WHERE id = 120084;
-- Zlandicar: 110k -> 35k HP (68% cut; ST key path boss)
UPDATE npc_types SET hp = 35000                        WHERE id = 123115;
-- Kelorek`Dar: 100k -> 35k HP (65% cut)
UPDATE npc_types SET hp = 35000                        WHERE id = 117073;

-- ---- Western Wastes near-named tier ----
-- Harla Dar: 65k -> 28k HP (57% cut; short respawn 5h already preserved)
UPDATE npc_types SET hp = 28000                        WHERE id = 120057;
-- #Mraaka: 60k -> 42k HP (30% trim; respawn 6h preserved)
UPDATE npc_types SET hp = 42000                        WHERE id = 120064;
-- Melalafen: 70k -> 42k HP (40% trim)
UPDATE npc_types SET hp = 42000                        WHERE id = 120126;

-- ---- Velketor's Labyrinth ----
-- Velketor the Sorcerer: 201,500 -> 60k HP (70% cut), 850 -> 680 maxdmg (20% trim)
--   Signature Sunstrike/Sundering preserved (Decision #11: no special_abilities edit)
UPDATE npc_types SET hp = 60000, maxdmg = 680          WHERE id = 112025;
-- Lord Doljonijiarnimorinar: 147k -> 45k HP (69% cut; respawn 18h already in target range)
UPDATE npc_types SET hp = 45000                        WHERE id = 112049;

-- ---- Siren's Grotto (one-shot damage risk — critical cuts) ----
-- #Faleniel of Darkwater: 300k -> 90k HP, 380-1,900 -> 190-950 (50% damage cut)
UPDATE npc_types SET hp = 90000, mindmg = 190, maxdmg = 950  WHERE id = 125070;
-- Wygrish: 200k -> 60k HP, 587-1,575 -> 294-780 (50% damage cut)
UPDATE npc_types SET hp = 60000, mindmg = 294, maxdmg = 780  WHERE id = 125072;

-- ---- Misc outdoor ----
-- Wuoshi: 46k -> 37k HP (20% trim; near named-tier already)
UPDATE npc_types SET hp = 37000                        WHERE id = 119112;
-- Lodizal: 40,561 -> 32,000 HP (21% trim; Velious Prayer Shawl giver — keep accessible)
UPDATE npc_types SET hp = 32000                        WHERE id = 110099;
-- Taskmaster Abyott: 72k -> 30k HP (58% cut; respawn 18h preserved)
UPDATE npc_types SET hp = 30000                        WHERE id = 118088;

-- ---- Coldain Ring War — Narandi terminus ----
-- #Narandi the Wretched: 150k -> 45k HP. Script-spawned via condition 16; no spawn2 change.
UPDATE npc_types SET hp = 45000                        WHERE id = 118145;

-- ---- Coldain Ring War — Kromrif wave mobs (Q23 Option D: Lever 1 SQL cuts) ----
-- All 8 IDs confirmed exclusive to greatdivide spawn_conditions 3-15 per DB sweep.
-- No special_abilities or damage edits; HP cuts only to make each wave DPS-tractable.
-- Lever 2 (ring_war.lua:26 wave_cooldown_time) is NOT applied this pass (conditional fallback).
-- Kromrif Captain: 10k -> 6k HP
UPDATE npc_types SET hp = 6000                         WHERE id = 118130;
-- Kromrif Recruit: 7k -> 5k HP
UPDATE npc_types SET hp = 5000                         WHERE id = 118160;
-- Kromrif Warrior: 11k -> 7k HP
UPDATE npc_types SET hp = 7000                         WHERE id = 118150;
-- Kromrif General: 13k -> 9k HP
UPDATE npc_types SET hp = 9000                         WHERE id = 118120;
-- Kromrif Priest: 27.5k -> 12k HP
UPDATE npc_types SET hp = 12000                        WHERE id = 118209;
-- Kromrif Warlord: 20k -> 12k HP
UPDATE npc_types SET hp = 12000                        WHERE id = 118158;
-- Kromrif Veteran: 42.5k -> 12k HP
UPDATE npc_types SET hp = 12000                        WHERE id = 118156;
-- Kromrif High Priest: 50k -> 15k HP
UPDATE npc_types SET hp = 15000                        WHERE id = 118210;

-- ---- Seneschal Aldikar (AOE overflow safety bump) ----
-- 10k -> 30k HP: prevents accidental death from wave AOE bleed during per-wave cooldowns
UPDATE npc_types SET hp = 30000                        WHERE id = 118166;

-- ---- Icewell Keep (Coldain Ring 10 terminus) ----
-- #Dain Frostreaver IV: 352k -> 80k HP (77% cut; faction-gated per Decision #14)
UPDATE npc_types SET hp = 80000                        WHERE id = 129003;
-- Chamberlain Krystorf: 80k -> 30k HP (63% cut; respawn 18h preserved)
UPDATE npc_types SET hp = 30000                        WHERE id = 129028;

-- ============================================================
-- SECTION B: spawn2 respawn time UPDATEs
-- Target: 43,200s (12h) for Velious non-ToV mid-tier endgame bosses per Decision #5
-- ============================================================

-- Kael main bosses (King Tormax 259200s, Statue 194400s -> 43200s each)
-- NOTE: Derakor (113118) already at 43200s — excluded from this UPDATE.
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID IN (113215, 113071);

-- Skyshrine: both Yelinak variants at 259200s -> 43200s (Q24: both live, both updated)
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID IN (114106, 114618);

-- Plane of Growth: Tunare only (259200s -> 43200s)
-- Guardian of Tunare (64800s/18h), PoG mid-tier (64800s/18h), Guardian of Takish (86400s/24h),
--   Fayl Everstrong (64800s/18h), Prince Thirneg (64800s/18h) — all within acceptable range, NOT updated.
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID = 127001;

-- Outdoor First Brood dragons (all at 259200s -> 43200s):
--   Sontalak (120005), Klandicar (120084), Zlandicar (123115)
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID IN (120005, 120084, 123115);

-- Kelorek`Dar: 194400s -> 43200s
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID = 117073;

-- Melalafen: 194400s -> 43200s
-- Harla Dar (18000s/5h) and Mraaka (21600s/6h) already short — NOT updated.
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID = 120126;

-- Velketor the Sorcerer: 259200s -> 43200s
-- Lord Doljonijiarnimorinar (64800s/18h) already in range — NOT updated.
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID = 112025;

-- Dain Frostreaver IV: 432000s (120h) -> 43200s
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID = 129003;

-- Plane of Mischief Jester: 281232s -> 43200s (condition=2 gated; safe to update all its spawn2 rows)
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID = 126012;

-- Wuoshi: 194400s -> 43200s
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID = 119112;

-- Respawns intentionally NOT updated (already at target range or special):
--   110099 Lodizal 32400s (9h) — Prayer Shawl giver, accessible as-is
--   112049 Lord Doljonijiarnimorinar 64800s (18h) — within range
--   113118 Derakor 43200s — already at target
--   114242-246 Crusaders 640s — very short, keep
--   118088 Taskmaster Abyott 64800s (18h) — within range
--   118145 Narandi — script-spawned via condition 16; spawn2 respawntime irrelevant
--   120057 Harla Dar 18000s (5h) — short, keep
--   120064 Mraaka 21600s (6h) — short, keep
--   125070/72 Sirens pair 7200s (2h) — short, keep
--   127007/127106 Guardian of Tunare 64800s (18h) — within range
--   127018-021 PoG mid-tier 64800s (18h) — within range
--   127035 Guardian of Takish 86400s (24h) — within range
--   127096 Prince Thirneg 64800s (18h) — within range
--   129028 Chamberlain Krystorf 64800s (18h) — within range
--   Ring War Kromrif wave mobs (118130 etc.) — condition-gated; no respawn change

-- ============================================================
-- SECTION C: Post-change verification queries
-- ============================================================

SELECT '=== VELIOUS-A PHASE 4a VERIFICATION ===' AS '';

-- ToV / Sleeper exclusion safety check (these must NOT be changed)
SELECT 'AoW HP (must be UNCHANGED)' AS check_name, hp AS actual FROM npc_types WHERE id = 113457;
SELECT 'Vulak HP (must be UNCHANGED)' AS check_name, hp AS actual FROM npc_types WHERE id = 124155;

-- ---- Kael Drakkel ----
SELECT 'King Tormax HP (expect 100000)' AS check_name, hp AS actual FROM npc_types WHERE id = 113215;
SELECT 'Statue of Rallos Zek HP (expect 50000)' AS check_name, hp AS actual FROM npc_types WHERE id = 113071;
SELECT 'Statue of Rallos Zek maxdmg (expect 500)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 113071;
SELECT 'Idol of Rallos Zek HP (expect 130000)' AS check_name, hp AS actual FROM npc_types WHERE id = 113341;
SELECT 'Idol of Rallos Zek maxdmg (expect 700)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 113341;
SELECT 'Derakor HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 113118;
SELECT 'Derakor maxdmg (expect 560)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 113118;

-- ---- Skyshrine ----
SELECT 'Yelinak main HP (expect 110000)' AS check_name, hp AS actual FROM npc_types WHERE id = 114106;
SELECT 'Yelinak variant HP (expect 110000 — Q24 both scaled)' AS check_name, hp AS actual FROM npc_types WHERE id = 114618;
SELECT 'Charayan HP (expect 50000)' AS check_name, hp AS actual FROM npc_types WHERE id = 114242;
SELECT 'Susarrak HP (expect 50000)' AS check_name, hp AS actual FROM npc_types WHERE id = 114243;
SELECT 'Grendish HP (expect 50000)' AS check_name, hp AS actual FROM npc_types WHERE id = 114245;
SELECT 'Jortreva HP (expect 50000)' AS check_name, hp AS actual FROM npc_types WHERE id = 114246;

-- ---- Plane of Growth ----
SELECT '#_Tunare HP (expect 150000)' AS check_name, hp AS actual FROM npc_types WHERE id = 127001;
SELECT 'Guardian of Tunare (main) HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 127007;
SELECT 'Guardian of Tunare (dup) HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 127106;
SELECT 'Ail the Elder HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 127020;
SELECT 'Ail the Elder maxdmg (expect 560)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 127020;
SELECT 'Rumbleroot HP (expect 55000)' AS check_name, hp AS actual FROM npc_types WHERE id = 127019;
SELECT 'Treah Greenroot HP (expect 55000)' AS check_name, hp AS actual FROM npc_types WHERE id = 127021;
SELECT 'Guardian of Takish HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 127035;
SELECT 'Fayl Everstrong HP (expect 45000)' AS check_name, hp AS actual FROM npc_types WHERE id = 127018;
SELECT 'Prince Thirneg HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 127096;

-- ---- Plane of Mischief ----
SELECT 'Jester HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 126012;
SELECT 'Jester maxdmg (expect 780)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 126012;

-- ---- Outdoor dragons ----
SELECT 'Sontalak HP (expect 40000)' AS check_name, hp AS actual FROM npc_types WHERE id = 120005;
SELECT 'Klandicar HP (expect 40000)' AS check_name, hp AS actual FROM npc_types WHERE id = 120084;
SELECT 'Zlandicar HP (expect 35000)' AS check_name, hp AS actual FROM npc_types WHERE id = 123115;
SELECT 'Kelorek Dar HP (expect 35000)' AS check_name, hp AS actual FROM npc_types WHERE id = 117073;

-- ---- Western Wastes near-named ----
SELECT 'Harla Dar HP (expect 28000)' AS check_name, hp AS actual FROM npc_types WHERE id = 120057;
SELECT 'Mraaka HP (expect 42000)' AS check_name, hp AS actual FROM npc_types WHERE id = 120064;
SELECT 'Melalafen HP (expect 42000)' AS check_name, hp AS actual FROM npc_types WHERE id = 120126;

-- ---- Velketor's Labyrinth ----
SELECT 'Velketor HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 112025;
SELECT 'Velketor maxdmg (expect 680)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 112025;
SELECT 'Lord Doljoni HP (expect 45000)' AS check_name, hp AS actual FROM npc_types WHERE id = 112049;

-- ---- Siren's Grotto ----
SELECT 'Faleniel HP (expect 90000)' AS check_name, hp AS actual FROM npc_types WHERE id = 125070;
SELECT 'Faleniel mindmg (expect 190)' AS check_name, mindmg AS actual FROM npc_types WHERE id = 125070;
SELECT 'Faleniel maxdmg (expect 950)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 125070;
SELECT 'Wygrish HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 125072;
SELECT 'Wygrish mindmg (expect 294)' AS check_name, mindmg AS actual FROM npc_types WHERE id = 125072;
SELECT 'Wygrish maxdmg (expect 780)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 125072;

-- ---- Misc outdoor ----
SELECT 'Wuoshi HP (expect 37000)' AS check_name, hp AS actual FROM npc_types WHERE id = 119112;
SELECT 'Lodizal HP (expect 32000)' AS check_name, hp AS actual FROM npc_types WHERE id = 110099;
SELECT 'Taskmaster Abyott HP (expect 30000)' AS check_name, hp AS actual FROM npc_types WHERE id = 118088;

-- ---- Ring War terminus + Icewell Keep ----
SELECT 'Narandi HP (expect 45000)' AS check_name, hp AS actual FROM npc_types WHERE id = 118145;
SELECT 'Dain Frostreaver IV HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 129003;
SELECT 'Chamberlain Krystorf HP (expect 30000)' AS check_name, hp AS actual FROM npc_types WHERE id = 129028;

-- ---- Ring War Kromrif wave mobs (Q23 Lever 1) ----
SELECT 'Kromrif Captain HP (expect 6000)' AS check_name, hp AS actual FROM npc_types WHERE id = 118130;
SELECT 'Kromrif Recruit HP (expect 5000)' AS check_name, hp AS actual FROM npc_types WHERE id = 118160;
SELECT 'Kromrif Warrior HP (expect 7000)' AS check_name, hp AS actual FROM npc_types WHERE id = 118150;
SELECT 'Kromrif General HP (expect 9000)' AS check_name, hp AS actual FROM npc_types WHERE id = 118120;
SELECT 'Kromrif Priest HP (expect 12000)' AS check_name, hp AS actual FROM npc_types WHERE id = 118209;
SELECT 'Kromrif Warlord HP (expect 12000)' AS check_name, hp AS actual FROM npc_types WHERE id = 118158;
SELECT 'Kromrif Veteran HP (expect 12000)' AS check_name, hp AS actual FROM npc_types WHERE id = 118156;
SELECT 'Kromrif High Priest HP (expect 15000)' AS check_name, hp AS actual FROM npc_types WHERE id = 118210;

-- ---- Seneschal Aldikar ----
SELECT 'Seneschal Aldikar HP (expect 30000)' AS check_name, hp AS actual FROM npc_types WHERE id = 118166;

-- ---- Respawn timer verification ----
SELECT 'King Tormax respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 113215 LIMIT 1;

SELECT 'Statue of Rallos Zek respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 113071 LIMIT 1;

SELECT 'Derakor respawn (expect 43200 unchanged)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 113118 LIMIT 1;

SELECT 'Yelinak main respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 114106 LIMIT 1;

SELECT 'Yelinak variant respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 114618 LIMIT 1;

SELECT 'Tunare respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 127001 LIMIT 1;

SELECT 'Sontalak respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 120005 LIMIT 1;

SELECT 'Klandicar respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 120084 LIMIT 1;

SELECT 'Zlandicar respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 123115 LIMIT 1;

SELECT 'Kelorek Dar respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 117073 LIMIT 1;

SELECT 'Melalafen respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 120126 LIMIT 1;

SELECT 'Velketor respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 112025 LIMIT 1;

SELECT 'Dain Frostreaver IV respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 129003 LIMIT 1;

SELECT 'Jester respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 126012 LIMIT 1;

SELECT 'Wuoshi respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 119112 LIMIT 1;

-- Respawns intentionally unchanged (spot-check)
SELECT 'Crusaders respawn (expect 640 unchanged)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 114242 LIMIT 1;

SELECT 'Harla Dar respawn (expect 18000 unchanged)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 120057 LIMIT 1;

SELECT 'Sirens Faleniel respawn (expect 7200 unchanged)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 125070 LIMIT 1;

SELECT 'Lodizal respawn (expect 32400 unchanged)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 110099 LIMIT 1;

SELECT 'Lord Doljoni respawn (expect 64800 unchanged)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 112049 LIMIT 1;

SELECT '=== VELIOUS-A PHASE 4a VERIFICATION COMPLETE ===' AS '';
