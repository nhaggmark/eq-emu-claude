-- =============================================================================
-- Task 2: Create companion core tables
-- Feature: npc-recruitment
-- Tables: companion_data, companion_buffs, companion_exclusions,
--         companion_culture_persuasion
-- =============================================================================

-- companion_data: one row per active/suspended companion per player
-- Includes all expanded scope columns (XP, leveling, history, state)
CREATE TABLE IF NOT EXISTS companion_data (
  id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  owner_id          INT UNSIGNED NOT NULL,               -- character_data.id
  npc_type_id       INT UNSIGNED NOT NULL,               -- npc_types.id (source NPC)
  name              VARCHAR(64) NOT NULL DEFAULT '',     -- NPC original name
  companion_type    TINYINT UNSIGNED NOT NULL DEFAULT 0, -- 0=companion, 1=mercenary
  level             TINYINT UNSIGNED NOT NULL DEFAULT 1,
  class_id          TINYINT UNSIGNED NOT NULL DEFAULT 0,
  race_id           SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  gender            TINYINT UNSIGNED NOT NULL DEFAULT 0,
  zone_id           INT UNSIGNED NOT NULL DEFAULT 0,     -- current/last zone
  x                 FLOAT NOT NULL DEFAULT 0,
  y                 FLOAT NOT NULL DEFAULT 0,
  z                 FLOAT NOT NULL DEFAULT 0,
  heading           FLOAT NOT NULL DEFAULT 0,
  cur_hp            BIGINT NOT NULL DEFAULT 0,
  cur_mana          BIGINT NOT NULL DEFAULT 0,
  cur_endurance     BIGINT NOT NULL DEFAULT 0,
  is_suspended      TINYINT UNSIGNED NOT NULL DEFAULT 1, -- 1=suspended, 0=active
  stance            TINYINT UNSIGNED NOT NULL DEFAULT 1, -- 0=passive, 1=balanced, 2=aggressive
  spawn2_id         INT UNSIGNED NOT NULL DEFAULT 0,     -- original spawn point (for return)
  spawngroupid      INT UNSIGNED NOT NULL DEFAULT 0,     -- original spawn group
  recruited_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- Expanded scope: XP tracking and leveling
  experience        BIGINT UNSIGNED NOT NULL DEFAULT 0,
  recruited_level   TINYINT UNSIGNED NOT NULL DEFAULT 1, -- level at time of recruitment
  -- Expanded scope: dismissal and persistence
  is_dismissed      TINYINT UNSIGNED NOT NULL DEFAULT 0, -- 1=dismissed (not active, but retained)
  -- Expanded scope: history tracking (companion_ai.cpp increments these)
  total_kills       INT UNSIGNED NOT NULL DEFAULT 0,
  zones_visited     TEXT NULL DEFAULT NULL,              -- JSON array of zone IDs visited
  time_active       INT UNSIGNED NOT NULL DEFAULT 0,     -- cumulative seconds active
  times_died        INT UNSIGNED NOT NULL DEFAULT 0,
  INDEX idx_owner (owner_id),
  INDEX idx_npc_type (npc_type_id),
  INDEX idx_owner_active (owner_id, is_dismissed, is_suspended)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- companion_buffs: buff state saved across zone/log transitions
-- Mirrors merc_buffs structure but with companion_id FK
CREATE TABLE IF NOT EXISTS companion_buffs (
  id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  companion_id      INT UNSIGNED NOT NULL,               -- companion_data.id
  spell_id          INT UNSIGNED NOT NULL DEFAULT 0,
  caster_level      TINYINT UNSIGNED NOT NULL DEFAULT 0,
  duration_formula  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  ticks_remaining   INT NOT NULL DEFAULT 0,
  dot_rune          INT NOT NULL DEFAULT 0,
  persistent        TINYINT NOT NULL DEFAULT 0,
  counters          INT NOT NULL DEFAULT 0,
  num_hits          INT NOT NULL DEFAULT 0,
  melee_rune        INT NOT NULL DEFAULT 0,
  magic_rune        INT NOT NULL DEFAULT 0,
  instrument_mod    INT NOT NULL DEFAULT 10,
  buff_tics         INT NOT NULL DEFAULT 0,
  caston_x          INT NOT NULL DEFAULT 0,
  caston_y          INT NOT NULL DEFAULT 0,
  caston_z          INT NOT NULL DEFAULT 0,
  extra_di_chance   INT NOT NULL DEFAULT 0,
  INDEX idx_companion (companion_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- companion_exclusions: NPCs that can never be recruited
-- Populated by Task 3 (auto-detection + named lore anchors)
CREATE TABLE IF NOT EXISTS companion_exclusions (
  npc_type_id       INT UNSIGNED NOT NULL PRIMARY KEY,   -- npc_types.id
  reason            VARCHAR(255) NOT NULL DEFAULT '',
  exclusion_type    TINYINT UNSIGNED NOT NULL DEFAULT 0  -- 0=manual, 1=auto-detected
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- companion_culture_persuasion: race -> persuasion stat mapping
-- Used by Lua companion.lua to calculate recruitment roll modifiers
CREATE TABLE IF NOT EXISTS companion_culture_persuasion (
  race_id           SMALLINT UNSIGNED NOT NULL PRIMARY KEY, -- npc_types.race
  primary_stat      VARCHAR(16) NOT NULL DEFAULT 'CHA',  -- CHA, STR, INT
  secondary_type    VARCHAR(16) NOT NULL DEFAULT 'faction', -- faction, level, stat
  secondary_stat    VARCHAR(16) DEFAULT NULL,             -- STR, INT, etc. (if type=stat)
  recruitment_type  TINYINT UNSIGNED NOT NULL DEFAULT 0,  -- 0=companion, 1=mercenary
  max_disposition   TINYINT UNSIGNED NOT NULL DEFAULT 4,  -- 0=rooted..4=eager
  notes             VARCHAR(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
