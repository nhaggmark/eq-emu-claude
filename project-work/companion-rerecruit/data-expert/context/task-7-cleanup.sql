-- Task 7: Ghost row cleanup for companion_data.id=21
-- Feature: bugfix/companion-rerecruit
-- Date: 2026-04-27
-- Author: data-expert
--
-- Ghost row: Hollish Tnoops id=21 (level=14, experience=0, 0 inventory)
-- Canonical row: Hollish Tnoops id=18 (level=53, experience=18707712, 15 inventory)
-- Both owned by owner_id=6 (character Chelon), npc_type_id=9144
--
-- Ghost was created by a prior bug where re-recruit INSERTed a new row
-- instead of reusing the existing one. The dismiss fix at companion.lua:1434
-- prevents future ghost creation via the dismiss→re-recruit path.

-- Step 1: Verify ghost row matches expected profile
SELECT id, owner_id, npc_type_id, name, level, experience, times_died, is_suspended, is_dismissed,
       (SELECT COUNT(*) FROM companion_inventories WHERE companion_id = companion_data.id) AS items
FROM companion_data
WHERE id = 21;
-- Expected: owner_id=6, npc_type_id=9144, name='Hollish Tnoops', level=14,
--           experience=0, times_died=0, is_suspended=1, is_dismissed=0, items=0

-- Step 2: Confirm canonical row exists and is healthier
SELECT id, owner_id, npc_type_id, name, level, experience, is_suspended,
       (SELECT COUNT(*) FROM companion_inventories WHERE companion_id = companion_data.id) AS items
FROM companion_data
WHERE owner_id = 6 AND npc_type_id = 9144 AND id <> 21;
-- Expected: id=18, level=53, experience=18707712, is_suspended=0, items=15

-- Step 3: Delete inventory rows (defensive; ghost had 0 items)
DELETE FROM companion_inventories WHERE companion_id = 21;

-- Step 4: Delete the ghost row
DELETE FROM companion_data WHERE id = 21;

-- Step 5: Verify ghost is gone
SELECT id FROM companion_data WHERE id = 21;
-- Expected: empty result set
