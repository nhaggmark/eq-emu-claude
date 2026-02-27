-- =============================================================================
-- Task 4: Seed companion_culture_persuasion
-- Feature: npc-recruitment
-- Source: architecture.md Data Model section + PRD racial tables
-- Verified race IDs from npc_types:
--   128 = Iksar, 130 = Vah Shir
-- Note: PRIMARY KEY is race_id — one row per race.
--   Erudite (race 3) uses companion type/CHA/faction (Erudin default).
--   The Paineel variant (mercenary/INT/level) is handled in Lua via zone context.
-- =============================================================================

INSERT IGNORE INTO companion_culture_persuasion
  (race_id, primary_stat, secondary_type, secondary_stat, recruitment_type, max_disposition, notes)
VALUES
-- Companion cultures (recruitment_type = 0): open, honor-driven, or adventurous
(1,   'CHA', 'faction', NULL,  0, 4, 'Human — personal magnetism and social standing; max=Eager'),
(2,   'STR', 'level',   NULL,  0, 4, 'Barbarian — respects strength and proven power; max=Eager'),
(3,   'CHA', 'faction', NULL,  0, 3, 'Erudite (Erudin default) — intellectual diplomacy; Paineel Lua override'),
(4,   'CHA', 'faction', NULL,  0, 4, 'Wood Elf — nature-bond and shared cause; max=Eager'),
(5,   'CHA', 'level',   NULL,  0, 3, 'High Elf — structured society; station and elegance; max=Restless'),
(6,   'CHA', 'faction', NULL,  0, 4, 'Half Elf — adaptable, open to mixed allegiances; max=Eager'),
(7,   'CHA', 'faction', 'STR', 0, 3, 'Dwarf (Kaladim) — faction + proven strength both matter; max=Restless'),
(10,  'CHA', 'faction', NULL,  0, 4, 'Halfling (Rivervale) — community trust via reputation; max=Eager'),
(11,  'INT', 'stat',    'CHA', 0, 3, 'Gnome (Ak''Anon) — logic + social acuity; max=Restless'),
(130, 'CHA', 'faction', NULL,  0, 4, 'Vah Shir (Shar Vahl) — honor culture, companion-capable; max=Eager'),

-- Mercenary cultures (recruitment_type = 1): self-interest, power, or tactical alliance
(8,   'STR', 'level',   NULL,  1, 2, 'Troll (Grobb) — follow strength; self-interest; max=Restless per PRD'),
(9,   'STR', 'level',   NULL,  1, 2, 'Ogre (Oggok) — divine curse limits motivation; follows raw power; max=Curious'),
(12,  'CHA', 'stat',    'INT', 1, 1, 'Dark Elf (Neriak) — social manipulation + INT; max=Content per PRD'),
(128, 'INT', 'level',   NULL,  1, 1, 'Iksar (Cabilis) — xenophobic empire-bound; tactical alliance only; max=Content');
