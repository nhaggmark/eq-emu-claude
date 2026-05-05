-- Task 10: Seed rule_values for Companions:SnareHpThreshold and Companions:SnareResistLimit
-- Applies to ruleset_id=1 (the active ruleset on this server).
-- Run AFTER the binary is rebuilt with the new RULE_INT entries from ruletypes.h.
-- After applying, run #reloadrules in-game to activate without a full server restart.
--
-- Apply with:
--   docker exec akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq < 10-rule-values.sql

INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES
(1, 'Companions:SnareHpThreshold', '25',
 'Target HP percent at or below which companions may autonomously cast movement-control spells (snare-line and root-line). Target must ALSO be IsFleeing(). Default 25 aligns with Combat:FleeHPRatio. Set to 100 to disable the HP gate.'),
(1, 'Companions:SnareResistLimit', '2',
 'Consecutive full-resists per (companion, target) per engagement before companion stops attempting movement-control casts on that target. Counter resets on engagement-end and target change. 0 = no cap. Default 2.');
