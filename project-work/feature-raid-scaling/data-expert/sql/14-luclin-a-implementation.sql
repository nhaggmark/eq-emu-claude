-- Phase 5a Luclin non-VT Raid Scaling -- Implementation SQL
-- Date: 2026-04-22
-- PREREQUISITE: 13-luclin-a-backup.sql must have run successfully first.
-- Sections:
--   A. npc_types HP/damage UPDATEs (41 rows)
--   B. spawn2 respawntime UPDATEs (~17-18 rows to 86400s / 24h endgame tier)
--   C. npc_spells_entries DELETE -- Touch of Vinitras list 196 only
--   D. Post-change verification queries
--
-- User decisions applied:
--   Decision #8  -- endgame respawn tier = 86,400s (24h)
--   Decision #11 -- signature mechanics preserved (Emperor Leash 290, Lord Seru MR=800, etc.)
--   Decision #16 -- Touch of Vinitras DT DELETE from list 196 (Vyzh`dra Exiled + Banished only)
--   Decision #30 -- Spirit of Akelha`Ra (179144) UNTOUCHED (VT-key turn-in NPC at 1M HP)
--   Decision #60 -- list 179 (Shei Vinitras 179032 REAL) PRESERVED -- DT is signature mechanic
--   Q50=A INCLUDE -- rune/glyph serpents 162253/261 scaled (joint architect+lore-master)
--   Q51=B INCLUDE (user override) -- Akheva elite-named scaled, respawn UNCHANGED at 5400s
--   Q52=B (perl-expert task L13) -- #EmpCycle.pl:3 edit is perl-expert scope, NOT here
--   Q59=A INCLUDE -- A_Spiritual_Arcanist 154153 150k->40k (joint architect+lore-master)
--
-- OUT OF SCOPE (DO NOT TOUCH):
--   162227 Emperor: special_abilities `32,1,290` (Leash) PRESERVED
--   159691 Lord Seru: MR=800 PRESERVED
--   179032 Shei Vinitras REAL: list 179 spell 2859 (Touch of Vinitras DT) PRESERVED per Decision #60
--   179144 Spirit of Akelha`Ra: 1M HP UNTOUCHED per Decision #30
--   162065 Emperor placeholder (non-combat trigger): UNTOUCHED
--   163097 Grieg Veneficus placeholder (14.25k): UNTOUCHED
--   Phase 5b (vexthal): 158081 Va_Dyn_Khar, 158087-94 Akhevan Warders -- NOT touched
--   Event-control NPCs: 162269 (keycheck 999M HP), 176110 (Keymaster 99M HP), 160177/178 (Helsin twins) -- NOT touched
--   OOE NPCs: 163051, 163052, 154161, 176111 -- filtered by min_expansion at runtime

-- ============================================================
-- SECTION A: npc_types HP/damage UPDATEs (41 rows)
-- ============================================================

-- ---- Ssraeshza Temple -- top-tier 6 bosses ----
-- Emperor Ssraeshza: 1.25M->120k HP, 283->200 mindmg, 904->620 maxdmg
-- special_abilities (Leash 290 + Rage buff) PRESERVED per Decision #11
UPDATE npc_types SET hp = 120000, mindmg = 200, maxdmg = 620 WHERE id = 162227;
-- High Priest of Ssraeshza: 941k->90k HP
UPDATE npc_types SET hp =  90000 WHERE id = 162076;
-- Xerkizh the Creator: 806.5k->80k HP
UPDATE npc_types SET hp =  80000 WHERE id = 162190;
-- Arch Lich Rhag`Zadune: 790k->75k HP
UPDATE npc_types SET hp =  75000 WHERE id = 162177;
-- Rhag`Mozdezh: 226k->60k HP
UPDATE npc_types SET hp =  60000 WHERE id = 162192;
-- Rhag`Zhezum: 201k->55k HP
UPDATE npc_types SET hp =  55000 WHERE id = 162178;

-- ---- Ssraeshza Temple -- Emperor cycle gate mobs ----
-- Blood of Ssraeshza: 200k->60k HP (phase-1 Emperor gate, script-spawned)
UPDATE npc_types SET hp =  60000 WHERE id = 162189;
-- Ssraeshzian Blood Golem: 201k->60k HP (failure-retry gate, script-spawned)
UPDATE npc_types SET hp =  60000 WHERE id = 162064;

-- ---- Ssraeshza Temple -- pre-Emperor named (Ring of Shissar Insignia drop chain) ----
-- Respawn UNCHANGED at 1080s (18m) short-tier farmable -- 17 spawn2 rows each preserved
-- General Kizuhx: 250k->60k HP, 510 maxdmg (already at 510 -- value unchanged effectively)
UPDATE npc_types SET hp =  60000, maxdmg = 510 WHERE id = 162066;
-- Arbiter Korazhk: 205k->55k HP
UPDATE npc_types SET hp =  55000 WHERE id = 162191;
-- Advisor Zekuzh: 150k->45k HP
UPDATE npc_types SET hp =  45000 WHERE id = 162067;

-- ---- Ssraeshza Temple -- Rhozth pair (Taskmaster's Pouch quest-drop dependency) ----
-- Respawn UNCHANGED at 5400s/21600s mid-tier
-- Rhozth Ssrakezh: 119k->40k HP
UPDATE npc_types SET hp =  40000 WHERE id = 162258;
-- Rhozth Ssravizh: 105.2k->38k HP
UPDATE npc_types SET hp =  38000 WHERE id = 162089;

-- ---- Ssraeshza Temple -- Vyzh`dra chain stepping-stones (Q50=A INCLUDE) ----
-- Script-spawned, raid_target=1, part of #cursed_controller.pl chain
-- a_rune_covered_serpent: 221k->60k HP
UPDATE npc_types SET hp =  60000 WHERE id = 162253;
-- a_glyph_covered_serpent: 300k->70k HP
UPDATE npc_types SET hp =  70000 WHERE id = 162261;

-- ---- Akheva Ruins -- Vyzh`dra trio (script-spawned) ----
-- Touch of Vinitras DT removed from list 196 (Section C below) -- Exiled + Banished become tractable
-- Vyzh`dra the Cursed: 900k->90k HP (list 197, no DT)
UPDATE npc_types SET hp =  90000 WHERE id = 162206;
-- Vyzh`dra the Exiled: 450k->70k HP (list 196, DT removed by DELETE below)
UPDATE npc_types SET hp =  70000 WHERE id = 162232;
-- Vyzh`dra the Banished: 403k->65k HP (list 196, DT removed by DELETE below)
UPDATE npc_types SET hp =  65000 WHERE id = 162214;

-- ---- Akheva Ruins -- spawn2-backed primary bosses ----
-- The Itraer Vius: 601k->80k HP
UPDATE npc_types SET hp =  80000 WHERE id = 179037;
-- Shei Vinitras REAL: 690k->85k HP, 700->600 maxdmg
-- list 179 PRESERVED (Touch of Vinitras DT is signature per Decision #60)
UPDATE npc_types SET hp =  85000, maxdmg = 600 WHERE id = 179032;
-- Shei Vinitras MERCHANT (trigger-kill form): 400k->60k HP (deeper cut so not raid-tier wall)
UPDATE npc_types SET hp =  60000 WHERE id = 179157;
-- The Insanity Crawler: 401k->60k HP
UPDATE npc_types SET hp =  60000 WHERE id = 179180;
-- The Va`Dyn: 250k->50k HP
UPDATE npc_types SET hp =  50000 WHERE id = 179178;
-- Shar Vinitras: 460.9k->70k HP, 1010->600 maxdmg (signature damage cap)
-- Respawn UNCHANGED at 10800s (3h) short-tier preserved per audit
UPDATE npc_types SET hp =  70000, maxdmg = 600 WHERE id = 179134;

-- ---- Akheva Ruins -- elite-named (Q51=B USER OVERRIDE) ----
-- Respawn UNCHANGED at native 5400s (1.5h short-tier) per Q51 named-tier philosophy
-- special_abilities UNCHANGED per Decision #11
-- Sheleric Vis (L61, 116k HP, maxdmg outlier 746): 116k->35k HP, 746->550 maxdmg
UPDATE npc_types SET hp =  35000, maxdmg = 550 WHERE id = 179133;
-- Sheleric Vis variant (L62, 70k HP, 59/173 dmg already named-tier): 70k->30k HP, damage UNCHANGED
UPDATE npc_types SET hp =  30000 WHERE id = 179046;
-- Xaui Tatrua (L60, 70k HP, 110/376 dmg already named-tier): 70k->30k HP, damage UNCHANGED
UPDATE npc_types SET hp =  30000 WHERE id = 179044;

-- ---- Sanctus Seru ----
-- Lord Inquisitor Seru: 1.2M->120k HP, 339->220 mindmg, 915->620 maxdmg
-- MR=800 PRESERVED (caster-wall signature per Decision #11 -- same pattern as Vyemm MR=1000)
UPDATE npc_types SET hp = 120000, mindmg = 220, maxdmg = 620 WHERE id = 159691;
-- Praesertum Vantorus: 250k->55k HP
UPDATE npc_types SET hp =  55000 WHERE id = 159113;
-- Praesertum Rhugol: 200k->50k HP
UPDATE npc_types SET hp =  50000 WHERE id = 159112;
-- Praesertum Bikun: 160k->45k HP
UPDATE npc_types SET hp =  45000 WHERE id = 159115;
-- Praesertum Matpa: 150k->45k HP
UPDATE npc_types SET hp =  45000 WHERE id = 159114;

-- ---- Katta Castellum ----
-- Lcea Katta: 401.2k->80k HP, 827->620 maxdmg
UPDATE npc_types SET hp =  80000, maxdmg = 620 WHERE id = 160375;
-- Nathyn Illuminious: 430k->80k HP
UPDATE npc_types SET hp =  80000 WHERE id = 160135;

-- ---- Grieg's End ----
-- Grieg Veneficus MAIN: 475.5k->80k HP (script-spawned, no spawn2)
UPDATE npc_types SET hp =  80000 WHERE id = 163075;
-- Grieg Veneficus variant (163231): HP UNCHANGED at 162.5k (already scaled-tier); respawn UPDATE only in Section B
-- Servitor of Luclin: 120k->40k HP
UPDATE npc_types SET hp =  40000 WHERE id = 163013;
-- Praetorian Myral: 95k->35k HP
UPDATE npc_types SET hp =  35000 WHERE id = 163078;

-- ---- Acrylia Caverns ----
-- Khati Sha the Twisted: 475k->90k HP, 1004->750 maxdmg (L68 outlier -- damage cap critical)
UPDATE npc_types SET hp =  90000, maxdmg = 750 WHERE id = 154145;
-- an_evolved_burrower: 300.75k->60k HP
UPDATE npc_types SET hp =  60000 WHERE id = 154142;
-- A_Spiritual_Arcanist: 150k->40k HP (Q59=A -- Khati Sha event Phase 2 wrong-choice penalty mob)
UPDATE npc_types SET hp =  40000 WHERE id = 154153;

-- ---- The Deep ----
-- Thought Horror Overfiend: 807k->90k HP
UPDATE npc_types SET hp =  90000 WHERE id = 164078;

-- ---- Umbral Plains ----
-- Doomshade: 350k->70k HP (audit-missed; script-spawned, no spawn2)
UPDATE npc_types SET hp =  70000 WHERE id = 176088;
-- Zelnithak: 251k->60k HP
UPDATE npc_types SET hp =  60000 WHERE id = 176089;
-- Rumblecrush: 150k->45k HP, 720->600 maxdmg
UPDATE npc_types SET hp =  45000, maxdmg = 600 WHERE id = 176002;

-- ============================================================
-- SECTION B: spawn2 respawntime UPDATEs (~17-18 rows to 86400s / 24h)
-- ============================================================
-- NOT updated (preserved):
--   162066/067/191 pre-Emperor 1080s (Ring of the Shissar farming cadence)
--   162258/089 Rhozth at 5400s/21600s mid-tier (Taskmaster's Pouch farming cadence)
--   179134 Shar Vinitras at 10800s (short-tier preserved per audit)
--   179133/046/044 Sheleric Vis + Xaui Tatrua at 5400s (Q51 elite-named respawn philosophy)
--   Script-spawned bosses with no spawn2 rows: Emperor, Vyzh`dra trio, Rhag`Zadune,
--     Rhag`Mozdezh, Blood, Blood Golem, serpents 162253/261, Khati Sha, Spiritual Arcanist,
--     Doomshade, Grieg main 163075
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 86400
WHERE se.npcID IN (
    -- ssratemple standing-spawn (3 rows: High Priest + Xerkizh + Rhag`Zhezum)
    162076, 162190, 162178,
    -- akheva primary (5 rows: Itraer Vius + Shei MERCHANT + Insanity Crawler + Va`Dyn)
    -- NOTE: 179032 Shei Vinitras REAL has NO spawn2 row -- silently skipped
    179037, 179157, 179180, 179178,
    -- sseru (5 rows: Lord Seru + 4 Praesertum)
    159691, 159113, 159112, 159115, 159114,
    -- katta (2 rows: Lcea Katta + Nathyn Illuminious)
    160375, 160135,
    -- griegsend (3 rows: variant 163231 + Servitor + Praetorian; 163075 main has no spawn2)
    163231, 163013, 163078,
    -- acrylia (1 row: evolved burrower; Khati Sha + Spiritual Arcanist have no spawn2)
    154142,
    -- thedeep (1 row: Thought Horror Overfiend)
    164078,
    -- umbral (2 rows: Zelnithak + Rumblecrush; Doomshade has no spawn2)
    176089, 176002
);
-- Expected: ~17-18 rows updated (exact count depends on spawn2 join dedup)

-- ============================================================
-- SECTION C: npc_spells_entries DELETE -- Touch of Vinitras DT
-- ============================================================
-- DELETE spell 2859 (Touch of Vinitras, -20000 HP, cast 0, recast 120s) from list 196 ONLY.
-- List 196 is used by Vyzh`dra the Exiled (162232) and Vyzh`dra the Banished (162214).
-- List 179 (Shei Vinitras 179032) also contains spell 2859 -- that list is NOT touched per Decision #60.
-- Follows Phase 2 Decision #16 (Cazic Touch DELETE) and Decision #13 (PoSky DT removal) precedent.
DELETE FROM npc_spells_entries
WHERE npc_spells_id = 196 AND spellid = 2859;
-- Expected: 1 row affected

-- ============================================================
-- SECTION D: Post-change verification queries
-- ============================================================

-- D1: Backup table row counts
SELECT 'npc_types_backup rows (expect 41)' AS check_name,
       COUNT(*) AS actual FROM npc_types_backup_raid_scaling_luclin_a;
SELECT 'spawn2_backup rows' AS check_name,
       COUNT(*) AS actual FROM spawn2_backup_raid_scaling_luclin_a;
SELECT 'spells_backup rows (expect 1)' AS check_name,
       COUNT(*) AS actual FROM npc_spells_entries_backup_raid_scaling_luclin_a;

-- D2: Ssraeshza Temple HP targets
SELECT id, name, hp, mindmg, maxdmg
FROM npc_types
WHERE id IN (162227,162076,162190,162177,162192,162178,162189,162064,
             162066,162067,162191,162258,162089,162253,162261)
ORDER BY hp DESC;
-- Expected (descending):
-- 162227 Emperor: 120000, mindmg=200, maxdmg=620
-- 162076 High Priest: 90000
-- 162190 Xerkizh: 80000
-- 162177 Arch Lich Rhag`Zadune: 75000
-- 162261 glyph serpent: 70000
-- 162189 Blood: 60000
-- 162064 Blood Golem: 60000
-- 162066 General Kizuhx: 60000, maxdmg=510
-- 162253 rune serpent: 60000
-- 162192 Rhag`Mozdezh: 60000
-- 162178 Rhag`Zhezum: 55000
-- 162191 Arbiter Korazhk: 55000
-- 162067 Advisor Zekuzh: 45000
-- 162258 Rhozth Ssrakezh: 40000
-- 162089 Rhozth Ssravizh: 38000

-- D3: Emperor special_abilities preservation check (Leash 290)
SELECT id, name, hp, special_abilities FROM npc_types WHERE id = 162227;
-- special_abilities MUST still contain `32,1,290`

-- D4: Akheva HP targets
SELECT id, name, hp, maxdmg FROM npc_types
WHERE id IN (162206,162232,162214,179037,179032,179157,179180,179178,179134,
             179133,179046,179044)
ORDER BY hp DESC;
-- Expected:
-- 162206 Vyzh`dra Cursed: 90000
-- 179032 Shei Vinitras REAL: 85000, maxdmg=600
-- 179037 Itraer Vius: 80000
-- 162232 Vyzh`dra Exiled: 70000
-- 179134 Shar Vinitras: 70000, maxdmg=600
-- 162214 Vyzh`dra Banished: 65000
-- 179157 Shei Vinitras MERCHANT: 60000
-- 179180 Insanity Crawler: 60000
-- 179178 Va`Dyn: 50000
-- 179133 Sheleric Vis: 35000, maxdmg=550
-- 179046 Sheleric Vis variant: 30000
-- 179044 Xaui Tatrua: 30000

-- D5: Seru/Katta HP targets
SELECT id, name, hp, mindmg, maxdmg, MR FROM npc_types
WHERE id IN (159691,159113,159112,159115,159114,160375,160135)
ORDER BY hp DESC;
-- Expected:
-- 159691 Lord Seru: 120000, mindmg=220, maxdmg=620, MR=800 (MR preserved!)
-- 160375 Lcea Katta: 80000, maxdmg=620
-- 160135 Nathyn Illuminious: 80000
-- 159113 Praesertum Vantorus: 55000
-- 159112 Praesertum Rhugol: 50000
-- 159115 Praesertum Bikun: 45000
-- 159114 Praesertum Matpa: 45000

-- D6: Lord Seru MR preservation check
SELECT id, name, MR FROM npc_types WHERE id = 159691;
-- MR MUST = 800

-- D7: Grieg/Acrylia/Deep/Umbral HP targets
SELECT id, name, hp, maxdmg FROM npc_types
WHERE id IN (163075,163231,163013,163078,154145,154142,154153,164078,176088,176089,176002)
ORDER BY hp DESC;
-- Expected:
-- 163231 Grieg variant: 162500 (UNCHANGED -- already scaled-tier)
-- 164078 Thought Horror Overfiend: 90000
-- 154145 Khati Sha: 90000, maxdmg=750
-- 163075 Grieg Veneficus MAIN: 80000
-- 176088 Doomshade: 70000
-- 154142 evolved burrower: 60000
-- 176089 Zelnithak: 60000
-- 163013 Servitor of Luclin: 40000
-- 154153 A_Spiritual_Arcanist: 40000
-- 176002 Rumblecrush: 45000, maxdmg=600
-- 163078 Praetorian Myral: 35000

-- D8: Touch of Vinitras DELETE confirmation
SELECT 'ToV list 196 spell 2859 (expect 0 rows after DELETE)' AS check_name,
       COUNT(*) AS actual
FROM npc_spells_entries WHERE npc_spells_id = 196 AND spellid = 2859;

-- D9: List 179 DT PRESERVED (Shei Vinitras signature -- Decision #60)
SELECT 'list 179 spell 2859 PRESERVED (expect 1 row)' AS check_name,
       COUNT(*) AS actual
FROM npc_spells_entries WHERE npc_spells_id = 179 AND spellid = 2859;

-- D10: Spirit of Akelha`Ra UNTOUCHED (Decision #30)
SELECT 'Spirit of Akelha`Ra HP (expect 1000000)' AS check_name,
       hp AS actual FROM npc_types WHERE id = 179144;

-- D11: spawn2 respawn UPDATE verification -- spot checks
SELECT 'High Priest respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 162076 LIMIT 1;

SELECT 'Lord Seru respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 159691 LIMIT 1;

SELECT 'Itraer Vius respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 179037 LIMIT 1;

SELECT 'Thought Horror Overfiend respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 164078 LIMIT 1;

SELECT 'Grieg variant 163231 respawn (expect 86400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 163231 LIMIT 1;

SELECT 'Shar Vinitras respawn PRESERVED (expect 10800)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 179134 LIMIT 1;

SELECT 'Sheleric Vis 179133 respawn PRESERVED (expect 5400)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 179133 LIMIT 1;

SELECT 'Advisor Zekuzh respawn PRESERVED (expect 1080)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 162067 LIMIT 1;

SELECT 'Rhozth Ssravizh respawn PRESERVED (expect 21600)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 162089 LIMIT 1;

-- D12: Phase 5b safety (vexthal NPCs untouched)
SELECT 'Va_Dyn_Khar 158081 (NOT Phase 5a -- expect PEQ default)' AS check_name,
       id, name, hp FROM npc_types WHERE id = 158081;

-- D13: Event-control NPCs untouched
SELECT 'keycheck 162269 (expect 999M HP unchanged)' AS check_name, id, name, hp
FROM npc_types WHERE id = 162269;
SELECT 'Keymaster 176110 (expect 99M HP unchanged)' AS check_name, id, name, hp
FROM npc_types WHERE id = 176110;
