-- BUG-001 Fix: Scale #Tunare (127098) — actual PoG combat boss
-- Phase 4a Velious non-ToV — 2026-04-23
--
-- Background:
--   Phase 4a implementation (07-velious-a-implementation.sql) scaled NPC 127001
--   (#_Tunare, the passive trigger NPC in the tree). That NPC depops when attacked
--   and script-spawns the actual combat boss via eq.spawn2(127098,...).
--   NPC 127098 was left at 530,000 HP (PEQ default), making PoG unplayable.
--   This file adds 127098 to the backup table and applies the HP cut.
--
-- Architecture intent: 150,000 HP (same target as was applied to 127001;
--   consistent with Velious mid-tier: King Tormax 100k, Yelinak 110k).
--
-- No spawn2 change needed: 127098 has no spawn2 row (always script-spawned).

-- Pre-change backup (INSERT 127098 into existing backup table)
INSERT INTO npc_types_backup_raid_scaling_velious_a (id, name, level, hp, mindmg, maxdmg, AC, special_abilities, npcspecialattks)
SELECT id, name, level, hp, mindmg, maxdmg, AC, special_abilities, npcspecialattks
FROM npc_types
WHERE id = 127098;

-- Verify backup row
-- Expected: 1 row with hp=530000
SELECT id, name, hp FROM npc_types_backup_raid_scaling_velious_a WHERE id = 127098;

-- Apply fix
UPDATE npc_types SET hp = 150000 WHERE id = 127098;

-- Verify fix
-- Expected: hp=150000
SELECT id, name, hp, maxdmg, raid_target FROM npc_types WHERE id = 127098;
