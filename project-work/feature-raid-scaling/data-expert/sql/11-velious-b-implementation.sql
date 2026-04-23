-- Phase 4b Velious-B Raid Scaling — Implementation SQL
-- Date: 2026-04-22
-- PREREQUISITE: 10-velious-b-backup.sql must have run successfully first.
-- Sections:
--   A. npc_types HP/damage UPDATEs (51 rows)
--   B. spawn2 respawntime UPDATEs (~32 rows to 86400s / 24h endgame tier)
--   C. Post-change verification queries
--
-- User decisions applied:
--   Decision #8  — endgame respawn tier = 86,400s (24h)
--   Decision #11 — signature mechanics preserved (Vyemm MR=1000, Dagarn HP-regen, Vyskudra Lightning Breath, etc.)
--   Decision #12 — Kerafyrm trio (128089/94/95) + Destroy spell (1948) UNTOUCHED
--   Decision #36 — Warders (128090-93) scaled; Sleeper Awake event chain preserved intact
--   Decision #37 — Q37 Option B USER OVERRIDE: Defenders (124050/51/52/79) included,
--                  HP 120k→45k, maxdmg 700→550, respawn UNCHANGED (native 3-5h preserved)
--   Decision #38 — Q38 Option A: Lendiniara 86400s respawn (endgame tier applies)
--
-- No npc_spells_entries changes (zero death-touch-profile spells on Phase 4b in-scope bosses).
-- No special_abilities edits (Decision #11).
-- No C++, Perl, Lua changes.
-- OUT OF SCOPE: Kerafyrm (128089), The Sleeper (128094), Kerafyrm_ (128095).

-- ============================================================
-- SECTION A: npc_types HP/damage UPDATEs
-- ============================================================

-- ---- Temple of Veeshan — 16 dragon lords ----
-- Lord Koi`Doken: 580k→130k HP, 690 maxdmg unchanged (already reasonable)
UPDATE npc_types SET hp = 130000                              WHERE id = 124103;
-- Lady Nevederia: 525k→120k HP, 892→600 maxdmg
UPDATE npc_types SET hp = 120000, maxdmg = 600               WHERE id = 124076;
-- Lord Kreizenn: 465k→110k HP, 950→600 maxdmg
UPDATE npc_types SET hp = 110000, maxdmg = 600               WHERE id = 124074;
-- Lord Feshlak: 455k→110k HP, 960→600 maxdmg
UPDATE npc_types SET hp = 110000, maxdmg = 600               WHERE id = 124008;
-- Cekenar: 425k→100k HP (700 maxdmg left as-is — reasonable)
UPDATE npc_types SET hp = 100000                              WHERE id = 124071;
-- Aaryonar: 390k→95k HP, 900→550 maxdmg (signature breath mechanic preserved via special_abilities)
UPDATE npc_types SET hp =  95000, maxdmg = 550               WHERE id = 124010;
-- Dozekar the Cursed: 386.5k→95k HP (Halls of Testing gem drop source; 24h respawn applies)
UPDATE npc_types SET hp =  95000, maxdmg = 550               WHERE id = 124037;
-- Lady Mirenilla: 380k→95k HP, 950→600 maxdmg
UPDATE npc_types SET hp =  95000, maxdmg = 600               WHERE id = 124077;
-- Lord Vyemm: 350k→90k HP, 1200→700 maxdmg (MR=1000 PRESERVED — signature mechanic Decision #11)
UPDATE npc_types SET hp =  90000, maxdmg = 700               WHERE id = 124017;
-- Lendiniara the Keeper: 320k→80k HP (Sleeper's Tomb key talisman source; 24h respawn Decision #38)
UPDATE npc_types SET hp =  80000                              WHERE id = 124020;
-- Dagarn the Destroyer: 300k→80k HP (HP-regen special_ability PRESERVED — Decision #11)
UPDATE npc_types SET hp =  80000                              WHERE id = 124011;
-- Telkorenar: 280k→75k HP (MR=1000 PRESERVED — Decision #11)
UPDATE npc_types SET hp =  75000                              WHERE id = 124104;
-- Gozzrem: 280k→75k HP (MR=1000 PRESERVED — Decision #11)
UPDATE npc_types SET hp =  75000                              WHERE id = 124105;
-- Ikatiar the Venom: 250k→65k HP, 750→550 maxdmg
UPDATE npc_types SET hp =  65000, maxdmg = 550               WHERE id = 124001;
-- Jorlleag: 250k→65k HP, 916→600 maxdmg
UPDATE npc_types SET hp =  65000, maxdmg = 600               WHERE id = 124072;
-- Eashen of the Sky: 240k→65k HP, 750→550 maxdmg
UPDATE npc_types SET hp =  65000, maxdmg = 550               WHERE id = 124004;

-- ---- NToV mid-tier named — Midayor cluster L60 (8 NPCs) ----
UPDATE npc_types SET hp = 40000 WHERE id = 124030;  -- Midayor 120k→40k
UPDATE npc_types SET hp = 40000 WHERE id = 124031;  -- Grozzmel 120k→40k
UPDATE npc_types SET hp = 40000 WHERE id = 124034;  -- Ymmeln 120k→40k
UPDATE npc_types SET hp = 40000 WHERE id = 124035;  -- Krigara 120k→40k
UPDATE npc_types SET hp = 40000 WHERE id = 124036;  -- Lepethida 120k→40k
UPDATE npc_types SET hp = 40000 WHERE id = 124038;  -- Essedera 120k→40k
UPDATE npc_types SET hp = 40000 WHERE id = 124039;  -- Tavekalem 120k→40k
UPDATE npc_types SET hp = 40000 WHERE id = 124040;  -- Casalen 120k→40k

-- ---- NToV mid-tier named — L65-66 cluster (8 NPCs) ----
UPDATE npc_types SET hp = 50000 WHERE id = 124018;  -- Cyndor Lightningfang 140k→50k
UPDATE npc_types SET hp = 45000 WHERE id = 124073;  -- Zlexak 121.5k→45k
UPDATE npc_types SET hp = 45000 WHERE id = 124007;  -- Yrrindor Emerald Claw 120k→45k
UPDATE npc_types SET hp = 45000 WHERE id = 124106;  -- Kalkar of the Maelstrom 120k→45k
UPDATE npc_types SET hp = 45000 WHERE id = 124107;  -- Vyldin Flamereaver 120k→45k
UPDATE npc_types SET hp = 42000 WHERE id = 124003;  -- Zyerek Onyxblood 110k→42k
UPDATE npc_types SET hp = 42000 WHERE id = 124009;  -- Malteor Flamecaller 110k→42k
UPDATE npc_types SET hp = 40000 WHERE id = 124075;  -- Sevalak 101.5k→40k

-- ---- NToV Defenders (4 NPCs — per user Q37 override 2026-04-23) ----
-- HP: 120k→45k (62% cut; aligns with NToV L65 mid-tier band)
-- maxdmg: 700→550 (same trim applied to NToV L65-66 named)
-- respawn: UNCHANGED (native 11250-16200s / 3-5h already below endgame 24h tier)
UPDATE npc_types SET hp = 45000, maxdmg = 550 WHERE id = 124050;  -- An Emerald Defender
UPDATE npc_types SET hp = 45000, maxdmg = 550 WHERE id = 124051;  -- A Sky Defender
UPDATE npc_types SET hp = 45000, maxdmg = 550 WHERE id = 124052;  -- An Onyx Defender
UPDATE npc_types SET hp = 45000, maxdmg = 550 WHERE id = 124079;  -- A Lava Defender

-- ---- Sleeper's Tomb — condition 2 (LIVE: Ancients + main-variant bosses) ----
-- Zeixshi-Kar the Ancient: 377k→90k HP, 929→700 maxdmg
UPDATE npc_types SET hp = 90000, maxdmg = 700 WHERE id = 128044;
-- The Final Arbiter (main, cond 2): 357k→85k HP (629 maxdmg OK)
UPDATE npc_types SET hp = 85000               WHERE id = 128143;
-- Kildrukaun the Ancient: 352k→85k HP (MR=400 PRESERVED — signature mechanic Decision #11)
UPDATE npc_types SET hp = 85000               WHERE id = 128041;
-- Vyskudra the Ancient: 352k→85k HP, 789→700 maxdmg (Lightning Breath npc_spells PRESERVED)
UPDATE npc_types SET hp = 85000, maxdmg = 700 WHERE id = 128042;
-- Tjudawos the Ancient: 352k→85k HP, 767→700 maxdmg
UPDATE npc_types SET hp = 85000, maxdmg = 700 WHERE id = 128043;
-- The Progenitor (main, cond 2): 327k→80k HP (619 maxdmg OK)
UPDATE npc_types SET hp = 80000               WHERE id = 128144;
-- Master of the Guard (main, cond 2): 326.5k→80k HP (8-sentry wave encounter PRESERVED)
UPDATE npc_types SET hp = 80000               WHERE id = 128145;
-- Milas An`Rev: 210k→60k HP (4h respawn mid-tier — NOT updated in spawn2)
UPDATE npc_types SET hp = 60000               WHERE id = 128040;

-- ---- Sleeper's Tomb — condition 1 (DORMANT: Warders + Arbiter alt) ----
-- Warders: 200k→60k HP each. Sleeper Awake trigger chain is behavioral (kill-all-4-Warders
--   fires quest::signalwith(128094,66)), NOT HP-threshold-based. Scaling is transparent
--   to the chain. See arch §Kerafyrm Isolation Proof. Decision #36 acknowledged.
UPDATE npc_types SET hp = 60000 WHERE id = 128090;  -- Nanzata the Warder
UPDATE npc_types SET hp = 60000 WHERE id = 128091;  -- Ventani the Warder
UPDATE npc_types SET hp = 60000 WHERE id = 128092;  -- Tukaarak the Warder
UPDATE npc_types SET hp = 60000 WHERE id = 128093;  -- Hraashna the Warder
-- The Final Arbiter (alt, cond 1): 200k→60k HP
UPDATE npc_types SET hp = 60000 WHERE id = 128045;

-- ---- Pinnacle fights ----
-- Vulak`Aerr: 890k→150k HP, 355→250 mindmg, 1400→800 maxdmg (script-spawned, no spawn2)
UPDATE npc_types SET hp = 150000, mindmg = 250, maxdmg = 800 WHERE id = 124155;
-- Avatar of War: 900k→120k HP, 299→200 mindmg, 1154→700 maxdmg
--   Rampage 6×6 signature preserved; global MaxRampageTargets=2 cap intact (Decision #11)
UPDATE npc_types SET hp = 120000, mindmg = 200, maxdmg = 700 WHERE id = 113457;

-- ============================================================
-- SECTION B: spawn2 respawntime UPDATEs
-- Target: 86,400s (24h) endgame tier per Decision #8.
-- EXCLUDED from respawn update (by design):
--   - Defenders (124050/51/52/79): native 11250-16200s short-tier preserved per Q37
--   - Warders (128090-93) + Arbiter alt (128045): condition 1 / dormant; respawn irrelevant at cond=0
--   - Milas An`Rev (128040): 14400s / 4h mid-tier accessibility preserved
--   - L65-66 named 124018/107/106/003/009 at 64800s (18h): already within tier, per arch line 302
--   - L65-66 named 124007 (Yrrindor): 64800s, NOT in respawn update list
--   - AoW (113457) + Vulak (124155): no spawn2 rows (script-spawned)
-- ============================================================

-- ToV 16 dragon lords at 259200s / 93744s → 86400s
-- Note: Ikatiar (124001) at 93744s — modest 8340s trim to 86400s; included for consistency
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 86400
WHERE se.npcID IN (
    124001, 124004, 124008, 124010, 124011, 124017, 124020, 124037,
    124071, 124072, 124074, 124076, 124077, 124103, 124104, 124105
);

-- NToV mid-tier: Zlexak + Sevalak at 259200s → 86400s (endgame tier per arch line 302-303)
-- Note: Other 6 L65-66 named (124018/007/106/107/003/009) stay at 64800s (18h — tier-appropriate)
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 86400
WHERE se.npcID IN (124073, 124075);

-- NToV Midayor cluster (8 NPCs) at 194400s / 54h → 86400s / 24h
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 86400
WHERE se.npcID IN (
    124030, 124031, 124034, 124035, 124036, 124038, 124039, 124040
);

-- Sleeper's Tomb bosses (condition 2 — LIVE) at 259200s → 86400s
-- Note: 128040 Milas An`Rev (14400s) NOT included here
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 86400
WHERE se.npcID IN (128041, 128042, 128043, 128044, 128143, 128144, 128145);

-- ============================================================
-- SECTION C: Post-change verification queries
-- ============================================================

SELECT '=== VELIOUS-B PHASE 4b VERIFICATION ===' AS '';

-- Kerafyrm trio safety check (MUST remain at PEQ defaults — untouched per Decision #12)
SELECT 'Kerafyrm HP (must be UNCHANGED 3500000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128089;
SELECT 'The Sleeper HP (must be UNCHANGED 3500000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128094;
SELECT 'Kerafyrm_ HP (must be UNCHANGED 3500000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128095;
SELECT 'Kerafyrm maxdmg (must be UNCHANGED 7003)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 128089;
SELECT 'Thylex HP (must be UNCHANGED 100)' AS check_name, hp AS actual FROM npc_types WHERE id = 124000;

-- ---- Temple of Veeshan dragon lords ----
SELECT 'Lord Koi`Doken HP (expect 130000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124103;
SELECT 'Lady Nevederia HP (expect 120000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124076;
SELECT 'Lady Nevederia maxdmg (expect 600)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124076;
SELECT 'Lord Kreizenn HP (expect 110000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124074;
SELECT 'Lord Kreizenn maxdmg (expect 600)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124074;
SELECT 'Lord Feshlak HP (expect 110000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124008;
SELECT 'Lord Feshlak maxdmg (expect 600)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124008;
SELECT 'Cekenar HP (expect 100000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124071;
SELECT 'Aaryonar HP (expect 95000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124010;
SELECT 'Aaryonar maxdmg (expect 550)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124010;
SELECT 'Dozekar the Cursed HP (expect 95000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124037;
SELECT 'Lady Mirenilla HP (expect 95000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124077;
SELECT 'Lady Mirenilla maxdmg (expect 600)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124077;
SELECT 'Lord Vyemm HP (expect 90000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124017;
SELECT 'Lord Vyemm maxdmg (expect 700)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124017;
SELECT 'Lord Vyemm MR (must be UNCHANGED 1000)' AS check_name, MR AS actual FROM npc_types WHERE id = 124017;
SELECT 'Lendiniara HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124020;
SELECT 'Dagarn HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124011;
SELECT 'Telkorenar HP (expect 75000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124104;
SELECT 'Telkorenar MR (must be UNCHANGED 1000)' AS check_name, MR AS actual FROM npc_types WHERE id = 124104;
SELECT 'Gozzrem HP (expect 75000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124105;
SELECT 'Gozzrem MR (must be UNCHANGED 1000)' AS check_name, MR AS actual FROM npc_types WHERE id = 124105;
SELECT 'Ikatiar HP (expect 65000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124001;
SELECT 'Ikatiar maxdmg (expect 550)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124001;
SELECT 'Jorlleag HP (expect 65000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124072;
SELECT 'Jorlleag maxdmg (expect 600)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124072;
SELECT 'Eashen HP (expect 65000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124004;
SELECT 'Eashen maxdmg (expect 550)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124004;

-- ---- NToV mid-tier named ----
SELECT 'Midayor HP (expect 40000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124030;
SELECT 'Grozzmel HP (expect 40000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124031;
SELECT 'Ymmeln HP (expect 40000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124034;
SELECT 'Krigara HP (expect 40000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124035;
SELECT 'Lepethida HP (expect 40000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124036;
SELECT 'Essedera HP (expect 40000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124038;
SELECT 'Tavekalem HP (expect 40000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124039;
SELECT 'Casalen HP (expect 40000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124040;
SELECT 'Cyndor Lightningfang HP (expect 50000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124018;
SELECT 'Zlexak HP (expect 45000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124073;
SELECT 'Yrrindor Emerald Claw HP (expect 45000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124007;
SELECT 'Kalkar HP (expect 45000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124106;
SELECT 'Vyldin HP (expect 45000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124107;
SELECT 'Zyerek HP (expect 42000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124003;
SELECT 'Malteor HP (expect 42000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124009;
SELECT 'Sevalak HP (expect 40000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124075;

-- ---- NToV Defenders (Q37 override) ----
SELECT 'Emerald Defender HP (expect 45000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124050;
SELECT 'Emerald Defender maxdmg (expect 550)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124050;
SELECT 'Sky Defender HP (expect 45000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124051;
SELECT 'Sky Defender maxdmg (expect 550)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124051;
SELECT 'Onyx Defender HP (expect 45000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124052;
SELECT 'Onyx Defender maxdmg (expect 550)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124052;
SELECT 'Lava Defender HP (expect 45000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124079;
SELECT 'Lava Defender maxdmg (expect 550)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124079;

-- ---- Sleeper's Tomb ----
SELECT 'Zeixshi-Kar HP (expect 90000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128044;
SELECT 'Zeixshi-Kar maxdmg (expect 700)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 128044;
SELECT 'The Final Arbiter main HP (expect 85000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128143;
SELECT 'Kildrukaun HP (expect 85000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128041;
SELECT 'Kildrukaun MR (must be UNCHANGED 400)' AS check_name, MR AS actual FROM npc_types WHERE id = 128041;
SELECT 'Vyskudra HP (expect 85000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128042;
SELECT 'Vyskudra maxdmg (expect 700)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 128042;
SELECT 'Tjudawos HP (expect 85000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128043;
SELECT 'Tjudawos maxdmg (expect 700)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 128043;
SELECT 'The Progenitor HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128144;
SELECT 'Master of the Guard HP (expect 80000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128145;
SELECT 'Milas An`Rev HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128040;
SELECT 'Nanzata HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128090;
SELECT 'Ventani HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128091;
SELECT 'Tukaarak HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128092;
SELECT 'Hraashna HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128093;
SELECT 'The Final Arbiter alt HP (expect 60000)' AS check_name, hp AS actual FROM npc_types WHERE id = 128045;

-- ---- Pinnacle fights ----
SELECT 'Vulak HP (expect 150000)' AS check_name, hp AS actual FROM npc_types WHERE id = 124155;
SELECT 'Vulak mindmg (expect 250)' AS check_name, mindmg AS actual FROM npc_types WHERE id = 124155;
SELECT 'Vulak maxdmg (expect 800)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 124155;
SELECT 'Avatar of War HP (expect 120000)' AS check_name, hp AS actual FROM npc_types WHERE id = 113457;
SELECT 'Avatar of War mindmg (expect 200)' AS check_name, mindmg AS actual FROM npc_types WHERE id = 113457;
SELECT 'Avatar of War maxdmg (expect 700)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 113457;

-- ---- Respawn timer verification ----
SELECT 'Lord Koi`Doken respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 124103 LIMIT 1;

SELECT 'Lord Vyemm respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 124017 LIMIT 1;

SELECT 'Aaryonar respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 124010 LIMIT 1;

SELECT 'Lendiniara respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 124020 LIMIT 1;

SELECT 'Zlexak respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 124073 LIMIT 1;

SELECT 'Sevalak respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 124075 LIMIT 1;

SELECT 'Midayor respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 124030 LIMIT 1;

SELECT 'Kildrukaun respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 128041 LIMIT 1;

SELECT 'Zeixshi-Kar respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 128044 LIMIT 1;

SELECT 'The Final Arbiter main respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 128143 LIMIT 1;

SELECT 'Master of the Guard respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 128145 LIMIT 1;

-- Respawns intentionally NOT updated (spot-check):
SELECT 'Emerald Defender respawn (expect 16200 unchanged)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 124050 LIMIT 1;

SELECT 'Hraashna Warder respawn (expect 259200 unchanged - cond1)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 128093 LIMIT 1;

SELECT 'Milas An`Rev respawn (expect 14400 unchanged)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 128040 LIMIT 1;

SELECT 'Cyndor Lightningfang respawn (expect 64800 unchanged)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 124018 LIMIT 1;

SELECT '=== VELIOUS-B PHASE 4b VERIFICATION COMPLETE ===' AS '';
