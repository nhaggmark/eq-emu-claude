-- Task D: Companions:XPSharePct parity activation 50 → 100
-- Feature: feature/xp-retune
-- Date: 2026-04-27 (prepared; NOT YET EXECUTED)
-- Agent: config-expert
-- Scope: ruleset_id=1 only (Companions:* rules are fully custom; zero rows on ruleset_id=10)
--
-- SEQUENCING CONSTRAINT: This UPDATE must run AFTER infra-expert confirms the
-- new C++ binary (with Companion::CalculateExp refactor) is running.
-- Applying before the rebuild is safe but produces intermediate pre-multiplier
-- behavior (full pre-multiplier slice, not full parity). Post-restart preferred
-- for a clean single observable parity activation event.

-- Pre-check (expected: '50')
SELECT ruleset_id, rule_name, rule_value
  FROM rule_values
 WHERE ruleset_id = 1
   AND rule_name  = 'Companions:XPSharePct';

-- Forward
UPDATE rule_values
   SET rule_value = '100'
 WHERE ruleset_id = 1
   AND rule_name  = 'Companions:XPSharePct';

-- Post-check (expected: '100')
SELECT ruleset_id, rule_name, rule_value
  FROM rule_values
 WHERE ruleset_id = 1
   AND rule_name  = 'Companions:XPSharePct';

-- Live reload (run in-game as GM after UPDATE):
-- #reloadrulesworld

-- Rollback (if needed):
UPDATE rule_values
   SET rule_value = '50'
 WHERE ruleset_id = 1
   AND rule_name  = 'Companions:XPSharePct';
-- followed by: #reloadrulesworld
