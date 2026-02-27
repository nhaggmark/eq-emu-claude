-- =============================================================================
-- Task 20: Create companion_inventories table
-- Feature: npc-recruitment
-- Purpose: Persist equipped items on companions across dismiss/re-recruit cycles
--   Items stay with the companion on dismiss (not returned to player).
--   Items are destroyed on soul wipe (permanent death).
-- Structure mirrors character_corpse_items for familiarity.
-- =============================================================================

CREATE TABLE IF NOT EXISTS companion_inventories (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  companion_id    INT UNSIGNED NOT NULL,               -- companion_data.id
  slot_id         SMALLINT UNSIGNED NOT NULL DEFAULT 0, -- EQ slot ID (standard EQEmu slot constants)
  item_id         INT UNSIGNED NOT NULL DEFAULT 0,     -- items.id
  charges         TINYINT UNSIGNED NOT NULL DEFAULT 0,
  aug_slot_1      INT UNSIGNED NOT NULL DEFAULT 0,
  aug_slot_2      INT UNSIGNED NOT NULL DEFAULT 0,
  aug_slot_3      INT UNSIGNED NOT NULL DEFAULT 0,
  aug_slot_4      INT UNSIGNED NOT NULL DEFAULT 0,
  aug_slot_5      INT UNSIGNED NOT NULL DEFAULT 0,
  INDEX idx_companion (companion_id),
  UNIQUE KEY idx_companion_slot (companion_id, slot_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
