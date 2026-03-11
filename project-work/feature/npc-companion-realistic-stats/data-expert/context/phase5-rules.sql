-- Phase 5: Insert ResistCapBase rule into rule_values
-- Feature: npc-companion-realistic-stats
-- Branch:  feature/npc-companion-realistic-stats
-- Date:    2026-03-11
--
-- Inserts the Companions::ResistCapBase rule used by companion.cpp
-- GetMaxResist() to compute the resist cap: level * 5 + ResistCapBase.
-- At level 60 with default value 50: cap = 60*5+50 = 350 (70% of client
-- cap of 500 — matching the PRD 70-85% companion power target).
-- Set to 0 to disable resist capping entirely.
--
-- ruleset_id=1 matches all other Companions:* rules in this database.

INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes)
SELECT 1,
       'Companions:ResistCapBase',
       '50',
       'Phase 5: Base value for companion resist cap formula. Cap = level * 5 + this value. At level 60 with default 50, cap is 350. Set to 0 to disable resist capping entirely.'
WHERE NOT EXISTS (
    SELECT 1 FROM rule_values
    WHERE ruleset_id = 1
      AND rule_name = 'Companions:ResistCapBase'
);
