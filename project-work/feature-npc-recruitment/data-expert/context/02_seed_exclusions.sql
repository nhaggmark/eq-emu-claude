-- =============================================================================
-- Task 3: Seed companion_exclusions
-- Feature: npc-recruitment
-- Strategy:
--   1. Auto-detect by NPC class (Banker, Merchant, Guildmaster range)
--   2. Auto-detect by rare_spawn flag
--   3. Auto-detect by bodytype (non-sentient/untargetable types)
--   4. Auto-detect Frogloks (pre-Luclin: dungeon mobs, not a civilization)
--   5. Add named lore anchors manually (NPC IDs verified from DB queries)
-- =============================================================================

-- 1. Bankers (class 40) and Merchants (class 41)
INSERT IGNORE INTO companion_exclusions (npc_type_id, reason, exclusion_type)
SELECT id, 'Banker or Merchant NPC (class 40/41)', 1
FROM npc_types
WHERE class IN (40, 41);

-- 2. Guildmasters / Class trainers (class 20-35)
INSERT IGNORE INTO companion_exclusions (npc_type_id, reason, exclusion_type)
SELECT id, CONCAT('Guildmaster or trainer (class ', class, ')'), 1
FROM npc_types
WHERE class BETWEEN 20 AND 35;

-- 3. Rare/named spawns (raid bosses, dungeon bosses)
INSERT IGNORE INTO companion_exclusions (npc_type_id, reason, exclusion_type)
SELECT id, 'Rare/named spawn (boss)', 1
FROM npc_types
WHERE rare_spawn = 1;

-- 4. Non-sentient bodytypes
--   11 = Untargetable
--   64 = Special/invisible types (varies by PEQ)
--   65, 66, 67 = Additional special body types
INSERT IGNORE INTO companion_exclusions (npc_type_id, reason, exclusion_type)
SELECT id, CONCAT('Non-sentient/special bodytype (', bodytype, ')'), 1
FROM npc_types
WHERE bodytype IN (11, 64, 65, 66, 67);

-- 5. Frogloks — not an organized civilization in Classic-Luclin era
--   race 74 = standard Froglok in npc_types
--   race 330 = alternate Froglok race ID
INSERT IGNORE INTO companion_exclusions (npc_type_id, reason, exclusion_type)
SELECT id, 'Froglok (not a recruitable civilization in Classic-Luclin era)', 1
FROM npc_types
WHERE race IN (74, 330);

-- =============================================================================
-- Named lore anchors (exclusion_type = 0 = manual)
-- IDs verified via SELECT queries against the peq database 2026-02-27
-- =============================================================================

-- Sir Lucan D'Lere — defines Freeport civil war storyline
INSERT IGNORE INTO companion_exclusions (npc_type_id, reason, exclusion_type) VALUES
(9018,   'Sir Lucan D''Lere — lore anchor: Freeport civil war', 0),
(382202, 'Sir Lucan D''Lere (alt) — lore anchor: Freeport civil war', 0),
(9147,   '#Sir Lucan D''Lere (script variant) — lore anchor', 0),
(382244, '#Sir Lucan D''Lere (script variant alt) — lore anchor', 0);

-- Lord Antonius Bayle IV — moral authority of Qeynos
INSERT IGNORE INTO companion_exclusions (npc_type_id, reason, exclusion_type) VALUES
(466029, 'Lord Antonius Bayle — lore anchor: Qeynos moral authority', 0);

-- Captain Tillin — structural city guard captain
INSERT IGNORE INTO companion_exclusions (npc_type_id, reason, exclusion_type) VALUES
(1068,   'Captain Tillin — lore anchor: structural city guard captain', 0),
(466035, '#Captain Hiran Tillin (script variant) — lore anchor', 0);

-- King Raja Kerrath — Vah Shir king fighting Grimling War
INSERT IGNORE INTO companion_exclusions (npc_type_id, reason, exclusion_type) VALUES
(155151, 'King Raja Kerrath — lore anchor: Vah Shir king, Grimling War', 0);

-- High Priestess Alexandria — theological anchor of Dismal Rage
INSERT IGNORE INTO companion_exclusions (npc_type_id, reason, exclusion_type) VALUES
(42019,  'High Priestess Alexandria — lore anchor: Dismal Rage theology', 0);

-- Harbinger Glosk — anchors Brood of Kotiz storyline in Cabilis
INSERT IGNORE INTO companion_exclusions (npc_type_id, reason, exclusion_type) VALUES
(82044,  'Harbinger Glosk — lore anchor: Brood of Kotiz in Cabilis', 0);

-- King Thex'Ka IV — Teir'Dal power structure anchor
INSERT IGNORE INTO companion_exclusions (npc_type_id, reason, exclusion_type) VALUES
(73103,  'King Thex''Ka IV — lore anchor: Teir''Dal power structure', 0),
(73112,  'The Fabled King Thex''Ka IV — lore anchor variant', 0);
