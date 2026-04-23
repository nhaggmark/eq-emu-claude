-- Phase 3 Kunark Raid Scaling — Implementation SQL
-- Date: 2026-04-22
-- PREREQUISITE: 04-kunark-backup-tables.sql must have run successfully first.
-- Four sections:
--   A. npc_types HP/damage UPDATEs (~21 rows)
--   B. spawn2 respawn UPDATEs (~20 rows)
--   C. Post-change verification queries
--   D. VP condition-gate assertion (pre-apply safety check)
--
-- User decisions applied:
--   Q21 = Option A: Chardok Royals respawn UNCHANGED (keep 1.5h / 5400s)
--   Q22 = Option A: Renux Herkanor 448200 INCLUDED (HP cut applied)
--
-- No npc_spells_entries changes (zero death-touch-profile spells found in Kunark).
-- No special_abilities edits (Decision #11: preserve signature mechanics).
-- No C++, Lua, or Perl changes.

-- ============================================================
-- PRE-APPLY SAFETY CHECK: VP condition state
-- Expected: condition 2 (VeeshanNew) value = 1 (enabled)
-- ============================================================
SELECT 'VP VeeshanNew state (expect value=1)' AS check_name,
       id AS condition_id, value
FROM spawn_condition_values
WHERE id = 2;

-- ============================================================
-- SECTION A: npc_types HP/damage UPDATEs
-- ============================================================

-- ---- Outdoor Dragons (30-40% HP cut, damage trim on 3 of 4) ----
-- Gorenaire: 32000 -> 22000 HP (31% cut), maxdmg 500 -> 400
UPDATE npc_types SET hp = 22000, maxdmg = 400 WHERE id = 86014;
-- Severilous: 32000 -> 22000 HP, maxdmg 500 -> 400
UPDATE npc_types SET hp = 22000, maxdmg = 400 WHERE id = 94009;
-- Talendor: 32000 -> 22000 HP, maxdmg 500 -> 400
UPDATE npc_types SET hp = 22000, maxdmg = 400 WHERE id = 91093;
-- Faydedar: 32000 -> 19000 HP (40% cut; damage already low at 236 max, no change)
UPDATE npc_types SET hp = 19000 WHERE id = 96089;
-- #Faydedar weak variant (script-spawned, no spawn2): 32000 -> 19000 for consistency
UPDATE npc_types SET hp = 19000 WHERE id = 96073;

-- ---- End-Dungeon Bosses ----
-- Trakanon: 32000 -> 22000 HP (31% cut). Keep SERFMCNDf + flurry per Decision #11.
--   Global MaxRampageTargets=2 already caps rampage. No special_abilities edit.
UPDATE npc_types SET hp = 22000 WHERE id = 89154;
-- #Trakanon (Bard epic triggered, script-spawned): 16000 stays. Already named-tier.
--   No HP change. Included in backup for rollback safety only.
-- 89181 left alone

-- #Venril_Sathir (Kunark triggered, script-spawned): 22000 -> 16500 HP (25% cut), maxdmg 404 -> 365
UPDATE npc_types SET hp = 16500, maxdmg = 365 WHERE id = 102112;
-- Drusella_Sathir: 15750 stays. Already named-tier per audit. No HP change.
-- 105153 left alone

-- ---- Chardok Royals (HP trim; respawn UNCHANGED per Q21=Option A) ----
-- Queen Velazul Di'zok: 30000 -> 24000 HP (20% cut)
UPDATE npc_types SET hp = 24000 WHERE id = 103055;
-- Overking Bathezid: 34500 -> 26000 HP (25% cut)
UPDATE npc_types SET hp = 26000 WHERE id = 103056;
-- Prince Selrach Di'zok: 25000 stays. Already near named-tier per audit. No HP change.
-- 103080 left alone

-- ---- City of Mist ----
-- Kilidna: 100000 -> 30000 HP (70% cut); 700-4600 damage -> 300-1000 (critical one-shot fix)
UPDATE npc_types SET hp = 30000, mindmg = 300, maxdmg = 1000 WHERE id = 90186;
-- Lhranc: 19000 stays. Already named-tier, respawn already ~13.67h. No change.
-- 90093 left alone

-- ---- Veeshan's Peak Revamp (live, condition=2) — 80-85% HP cuts, 40-60% damage cuts ----
-- Xygoz: 814000 -> 120000 HP (85% cut), maxdmg 2266 -> 900
UPDATE npc_types SET hp = 120000, maxdmg = 900 WHERE id = 108053;
-- Nexona: 800000 -> 120000 HP (85% cut), maxdmg 2475 -> 1000
UPDATE npc_types SET hp = 120000, maxdmg = 1000 WHERE id = 108047;
-- Phara Dar: 681000 -> 120000 HP (82% cut), mindmg 1032 -> 450, maxdmg 1621 -> 750
UPDATE npc_types SET hp = 120000, mindmg = 450, maxdmg = 750 WHERE id = 108048;
-- Guardian of Veeshan: 600000 -> 120000 HP (80% cut), mindmg 380 -> 230, maxdmg 1273 -> 750
UPDATE npc_types SET hp = 120000, mindmg = 230, maxdmg = 750 WHERE id = 108042;
-- Hoshkar: 536000 -> 110000 HP (79% cut), maxdmg 1603 -> 800
UPDATE npc_types SET hp = 110000, maxdmg = 800 WHERE id = 108043;
-- Druushk: 470000 -> 95000 HP (80% cut), maxdmg 1567 -> 780
UPDATE npc_types SET hp = 95000, maxdmg = 780 WHERE id = 108040;
-- Silverwing: 454000 -> 90000 HP (80% cut), mindmg 554 -> 332, maxdmg 1295 -> 777
UPDATE npc_types SET hp = 90000, mindmg = 332, maxdmg = 777 WHERE id = 108050;

-- VP classic-era variants (dormant, condition=1): NO CHANGES.
-- 108509, 108510, 108511, 108512, 108513, 108517 are disabled by spawn_condition_values.

-- ---- Renux Herkanor (Q22=Option A: in scope) ----
-- #Renux_Herkanor Monk epic terminus: 500000 -> 120000 HP, maxdmg 1605 -> 900
-- (L72 is a PEQ artifact; scaling unblocks Monk epic on small-group server)
UPDATE npc_types SET hp = 120000, maxdmg = 900 WHERE id = 448200;

-- ============================================================
-- SECTION B: spawn2 respawn time UPDATEs
-- ============================================================

-- 12h (43200s) for outdoor dragons (currently 194400s / 54h)
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID IN (86014, 94009, 91093, 96089);

-- 12h (43200s) for Trakanon in sebilis (currently 194400s / 54h)
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID = 89154;

-- 12h (43200s) for Drusella_Sathir in charasis (currently 194400s / 54h)
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID = 105153;

-- #Venril_Sathir (102112): has a spawn2 row in karnor (194400s). Update to 12h.
--   This NPC is primarily script-spawned but has an active spawn2 row; updating it
--   ensures consistency if it ever spawns via the static row.
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID = 102112;

-- 12h (43200s) for VP revamp dragons — SCOPED TO _condition=2 ONLY
-- This is the critical filter: condition=1 (dormant classic variants) must NOT be touched.
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID IN (108040, 108042, 108043, 108047, 108048, 108050, 108053)
  AND s2._condition = 2;

-- 6h (21600s) for Kilidna (damage outlier; keep accessible for Paladin/SK epic)
-- Currently 5400s (1.5h) — bumping to 6h makes her a meaningful gate, not instant respawn
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 21600
WHERE se.npcID = 90186;

-- Lhranc (90093): leave at 49215s (~13.67h). Already in target range. No change.
-- Chardok Royals (103055, 103056, 103080): leave at 5400s (1.5h). Q21=Option A. No change.
-- VP classic (108509-108517): leave untouched (dormant). No change.
-- #Trakanon (89181), #Faydedar (96073), 448200: no spawn2 rows — silently skipped.

-- ============================================================
-- SECTION C: Post-change verification queries
-- ============================================================

SELECT '=== KUNARK PHASE 3 VERIFICATION ===' AS '';

-- Outdoor dragons
SELECT 'Gorenaire HP (expect 22000)' AS check_name, hp AS actual FROM npc_types WHERE id = 86014;
SELECT 'Gorenaire maxdmg (expect 400)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 86014;
SELECT 'Severilous HP (expect 22000)' AS check_name, hp AS actual FROM npc_types WHERE id = 94009;
SELECT 'Severilous maxdmg (expect 400)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 94009;
SELECT 'Talendor HP (expect 22000)' AS check_name, hp AS actual FROM npc_types WHERE id = 91093;
SELECT 'Faydedar HP (expect 19000)' AS check_name, hp AS actual FROM npc_types WHERE id = 96089;
SELECT '#Faydedar HP (expect 19000)' AS check_name, hp AS actual FROM npc_types WHERE id = 96073;

-- End-dungeon bosses
SELECT 'Trakanon HP (expect 22000)' AS check_name, hp AS actual FROM npc_types WHERE id = 89154;
SELECT '#Trakanon HP (expect 16000 unchanged)' AS check_name, hp AS actual FROM npc_types WHERE id = 89181;
SELECT '#Venril_Sathir HP (expect 16500)' AS check_name, hp AS actual FROM npc_types WHERE id = 102112;
SELECT '#Venril_Sathir maxdmg (expect 365)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 102112;
SELECT 'Drusella_Sathir HP (expect 15750 unchanged)' AS check_name, hp AS actual FROM npc_types WHERE id = 105153;

-- Chardok royals
SELECT 'Queen Velazul HP (expect 24000)' AS check_name, hp AS actual FROM npc_types WHERE id = 103055;
SELECT 'Overking Bathezid HP (expect 26000)' AS check_name, hp AS actual FROM npc_types WHERE id = 103056;
SELECT 'Prince Selrach HP (expect 25000 unchanged)' AS check_name, hp AS actual FROM npc_types WHERE id = 103080;

-- City of Mist
SELECT 'Kilidna HP (expect 30000)' AS check_name, hp AS actual FROM npc_types WHERE id = 90186;
SELECT 'Kilidna mindmg (expect 300)' AS check_name, mindmg AS actual FROM npc_types WHERE id = 90186;
SELECT 'Kilidna maxdmg (expect 1000)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 90186;
SELECT 'Lhranc HP (expect 19000 unchanged)' AS check_name, hp AS actual FROM npc_types WHERE id = 90093;

-- VP revamp
SELECT 'Xygoz HP (expect 120000)' AS check_name, hp AS actual FROM npc_types WHERE id = 108053;
SELECT 'Xygoz maxdmg (expect 900)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 108053;
SELECT 'Nexona HP (expect 120000)' AS check_name, hp AS actual FROM npc_types WHERE id = 108047;
SELECT 'Nexona maxdmg (expect 1000)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 108047;
SELECT 'Phara Dar HP (expect 120000)' AS check_name, hp AS actual FROM npc_types WHERE id = 108048;
SELECT 'Phara Dar mindmg (expect 450)' AS check_name, mindmg AS actual FROM npc_types WHERE id = 108048;
SELECT 'Phara Dar maxdmg (expect 750)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 108048;
SELECT 'Guardian of Veeshan HP (expect 120000)' AS check_name, hp AS actual FROM npc_types WHERE id = 108042;
SELECT 'Guardian of Veeshan mindmg (expect 230)' AS check_name, mindmg AS actual FROM npc_types WHERE id = 108042;
SELECT 'Guardian of Veeshan maxdmg (expect 750)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 108042;
SELECT 'Hoshkar HP (expect 110000)' AS check_name, hp AS actual FROM npc_types WHERE id = 108043;
SELECT 'Hoshkar maxdmg (expect 800)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 108043;
SELECT 'Druushk HP (expect 95000)' AS check_name, hp AS actual FROM npc_types WHERE id = 108040;
SELECT 'Druushk maxdmg (expect 780)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 108040;
SELECT 'Silverwing HP (expect 90000)' AS check_name, hp AS actual FROM npc_types WHERE id = 108050;
SELECT 'Silverwing mindmg (expect 332)' AS check_name, mindmg AS actual FROM npc_types WHERE id = 108050;
SELECT 'Silverwing maxdmg (expect 777)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 108050;

-- VP classic variants UNCHANGED
SELECT 'VP classic Silverwing HP (expect 153500 unchanged)' AS check_name, hp AS actual FROM npc_types WHERE id = 108509;
SELECT 'VP classic Phara Dar HP (expect 191500 unchanged)' AS check_name, hp AS actual FROM npc_types WHERE id = 108510;
SELECT 'VP classic Xygoz HP (expect 144500 unchanged)' AS check_name, hp AS actual FROM npc_types WHERE id = 108511;
SELECT 'VP classic Druushk HP (expect 156500 unchanged)' AS check_name, hp AS actual FROM npc_types WHERE id = 108512;
SELECT 'VP classic Nexona HP (expect 152500 unchanged)' AS check_name, hp AS actual FROM npc_types WHERE id = 108513;
SELECT 'VP classic Hoshkar HP (expect 151500 unchanged)' AS check_name, hp AS actual FROM npc_types WHERE id = 108517;

-- Renux Herkanor
SELECT '#Renux_Herkanor HP (expect 120000)' AS check_name, hp AS actual FROM npc_types WHERE id = 448200;
SELECT '#Renux_Herkanor maxdmg (expect 900)' AS check_name, maxdmg AS actual FROM npc_types WHERE id = 448200;

-- Respawn timers
SELECT 'Gorenaire respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 86014 LIMIT 1;

SELECT 'Severilous respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 94009 LIMIT 1;

SELECT 'Talendor respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 91093 LIMIT 1;

SELECT 'Faydedar respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 96089 LIMIT 1;

SELECT 'Trakanon respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 89154 LIMIT 1;

SELECT 'Drusella respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 105153 LIMIT 1;

SELECT 'Venril Sathir spawn2 respawn (expect 43200)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 102112 LIMIT 1;

SELECT 'Kilidna respawn (expect 21600)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 90186 LIMIT 1;

SELECT 'Lhranc respawn (expect 49215 unchanged)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 90093 LIMIT 1;

SELECT 'Queen Velazul respawn (expect 5400 unchanged)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 103055 LIMIT 1;

SELECT 'Overking Bathezid respawn (expect 5400 unchanged)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 103056 LIMIT 1;

SELECT 'Prince Selrach respawn (expect 5400 unchanged)' AS check_name, s2.respawntime AS actual
FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID = 103080 LIMIT 1;

-- VP condition=2 verification (critical: only revamp dragons should have 43200s respawn)
SELECT 'VP veeshan zone respawn by condition (expect ONLY condition=2 at 43200)' AS check_name,
       _condition, COUNT(*) AS rows_at_43200
FROM spawn2
WHERE zone = 'veeshan' AND respawntime = 43200
GROUP BY _condition;

-- VP classic condition=1 respawn UNCHANGED
SELECT 'VP classic condition=1 NOT touched (expect 64800-86400 range)' AS check_name,
       _condition, MIN(respawntime) AS min_respawn, MAX(respawntime) AS max_respawn
FROM spawn2
WHERE zone = 'veeshan' AND _condition = 1
GROUP BY _condition;

SELECT '=== KUNARK PHASE 3 VERIFICATION COMPLETE ===' AS '';
