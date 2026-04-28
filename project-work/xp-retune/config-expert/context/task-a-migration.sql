-- Task A: Character:ExpMultiplier rate retune 3.0 → 2.0
-- Feature: feature/xp-retune
-- Date: 2026-04-27
-- Agent: config-expert
-- Scope: ruleset_id=1 only (active ruleset; ruleset_id=10 is inactive and MUST NOT be touched)

-- Pre-check (expected: '3.0')
SELECT ruleset_id, rule_name, rule_value
  FROM rule_values
 WHERE ruleset_id = 1
   AND rule_name IN ('Character:ExpMultiplier', 'Character:AAExpMultiplier');

-- Forward (EXECUTED 2026-04-27; confirmed 1 row affected)
UPDATE rule_values
   SET rule_value = '2.0'
 WHERE ruleset_id = 1
   AND rule_name  = 'Character:ExpMultiplier';

-- Post-check (expected: ExpMultiplier='2.0', AAExpMultiplier='3.0' unchanged)
SELECT ruleset_id, rule_name, rule_value
  FROM rule_values
 WHERE ruleset_id = 1
   AND rule_name IN ('Character:ExpMultiplier', 'Character:AAExpMultiplier');

-- Live reload (run in-game as GM after UPDATE):
-- #reloadrulesworld

-- Rollback (if needed):
UPDATE rule_values
   SET rule_value = '3.0'
 WHERE ruleset_id = 1
   AND rule_name  = 'Character:ExpMultiplier';
-- followed by: #reloadrulesworld
