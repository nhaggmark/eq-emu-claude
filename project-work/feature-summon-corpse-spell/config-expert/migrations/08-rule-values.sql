-- Task 8: rule_values seed row for Spells:UniversalSummonCorpseCooldown
-- Feature: feature/summon-corpse-spell
-- Ruleset 1 is the active default ruleset on this server.
-- This row seeds the runtime value for the new rule registered in ruletypes.h.
-- Hot-reloadable via #reloadrules after updating this row.
-- Run this after the rebuilt binary (with the RULE_INT registration) is deployed.

INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes)
VALUES (
  1,
  'Spells:UniversalSummonCorpseCooldown',
  '180',
  'Cooldown in seconds for the universal self-summon-corpse spell line (12 class-flavored level-1 spells). 0 disables the cooldown. Default 180 (3 minutes). Range: 0-3600. Hot-reloadable via #reloadrules.'
);
