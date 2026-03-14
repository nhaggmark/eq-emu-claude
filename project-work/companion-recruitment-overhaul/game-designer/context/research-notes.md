# Research Notes: Companion Recruitment System

## Current Recruitment Flow (companion.lua)

### attempt_recruitment() — Line ~390
1. Check cooldown data_bucket (`companion_cooldown_{npc_type_id}_{char_id}`)
2. Call `is_eligible_npc(npc, client)` — full eligibility checks
3. Call `check_dismissed_record(npc_type_id, char_id)` — only checks is_dismissed=1
4. Calculate persuasion roll
5. On success: `_on_recruitment_success()` → `client:CreateCompanion(npc)`
6. On failure: `_on_recruitment_failure()` → sets cooldown

### is_eligible_npc() — Line ~180
Checks in order:
1. CompanionsEnabled rule
2. Group capacity < 6
3. NPC not already recruited (entity var)
4. Neither party in combat
5. **Level range (±LevelRange rule)** ← BLOCKS re-recruitment
6. Faction >= MinFaction ← BLOCKS re-recruitment
7. NPC type exclusions (pet, bot, merc, companion)
8. Bodytype exclusions
9. Exclusion table check (companion_exclusions)
10. Froglok check

### check_dismissed_record() — Line ~371
- Only checks `is_dismissed = 1`
- Does NOT check `is_suspended = 1`
- This is the gap: dead companions have is_suspended=1, is_dismissed=0

## C++ Re-Recruitment Path (companion.cpp)

### CreateFromNPC() — Line ~159
- Correctly checks `is_dismissed = 1 OR is_suspended = 1`
- Calls Load() to restore full state
- Clears both flags in C++ and DB
- The C++ is correct; the Lua blocks it from being reached

### Death() — Line ~355
- Sets is_suspended=1
- Increments times_died
- Saves equipment (BUG-012 fix)
- Starts death despawn timer

### Dismiss(bool permanent) — Line ~2155
- permanent=true: soul wipe
- permanent=false: sets is_suspended=1, is_dismissed=1, saves

### Load() — Line ~2449
- Restores all fields from companion_data
- Calls ScaleStatsToLevel() if saved level != base level
- Loads equipment from companion_inventories

## Key Database Tables

### companion_data
- id, owner_id, npc_type_id, companion_type
- level, experience, recruited_level
- cur_hp, cur_mana
- is_suspended, is_dismissed
- stance, spawn2_id, spawngroupid
- total_kills, times_died, time_active, zones_visited

### companion_inventories
- companion_data_id, slot_id, item_id
- Persists through death (BUG-012 fix)

### data_buckets (cooldowns)
- key: companion_cooldown_{npc_type_id}_{char_id}
- character_id=0, npc_id=0 (IDs in key string)
- TTL-based expiration

## Rules Relevant to Recruitment

| Rule | Default | Description |
|------|---------|-------------|
| CompanionsEnabled | true | Master toggle |
| LevelRange | 3 | ±levels for first-time recruitment |
| MinFaction | 3 | Kindly or better for first-time |
| BaseRecruitChance | 50 | Persuasion roll base % |
| RecruitCooldownS | 900 | 15 min cooldown on failure |
| ReRecruitBonus | 0.10 | +10% on re-recruit roll (obsolete after this PRD) |

## Design Decision: What Changes

### Lua Changes (primary)
- `attempt_recruitment()`: detect existing record BEFORE cooldown check
- New: `check_existing_companion_record()` that checks BOTH is_dismissed=1 AND is_suspended=1
- On match: skip all eligibility, skip roll, go straight to `_on_recruitment_success()`
- On success: delete any stale cooldown data_bucket
- Minimal re-recruitment checks: enabled, group capacity, combat, not-already-recruited

### C++ Changes (minor/none)
- CreateFromNPC() already correct
- May want to add cooldown cleanup in C++ as belt-and-suspenders

### No Rule Changes
- Existing rules are correct for first-time recruitment
- Re-recruitment bypasses rules entirely (code path, not rule values)
