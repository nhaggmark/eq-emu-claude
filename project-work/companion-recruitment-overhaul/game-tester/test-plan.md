# Companion Recruitment & Re-recruitment Overhaul — Test Plan

> **Feature branch:** `feature/companion-recruitment-overhaul`
> **Author:** game-tester
> **Date:** 2026-03-14
> **Server-side result:** PASS WITH WARNINGS

---

## Test Summary

This test plan validates the two-track companion recruitment system introduced by the
Companion Recruitment & Re-recruitment Overhaul feature. The feature fixes five
overlapping blocking mechanisms that prevented re-recruitment of previously recruited
companions (dead or dismissed).

**Systems affected:**
- `akk-stack/server/quests/lua_modules/companion.lua` — primary change (Lua recruitment flow)
- `eqemu/zone/companion.cpp` — secondary change (HP/mana restoration + cooldown cleanup)
- `eqemu/zone/cli/tests/cli_companion_tests.cpp` — Suite 19 (C++ tests)
- `akk-stack/server/quests/tests/test_companion_recruitment.lua` — 35 Lua unit tests

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] status.md — all implementation tasks Complete
- [x] Acceptance criteria identified: 36 criteria across 7 categories
- [x] lua-expert dev notes — Task 1 complete
- [x] c-expert dev notes — Task 2 complete

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Git status: all repos clean on feature branch | PASS | All three repos clean, nothing to commit |
| 2 | companion.lua: new functions present | PASS | `check_existing_companion_record()`, `is_re_recruitment_eligible()`, `attempt_recruitment()` confirmed |
| 3 | companion.lua: deprecated function preserved | PASS | `check_dismissed_record()` at line 372 has deprecation comment, still returns is_dismissed=1 rows |
| 4 | companion.lua: re-recruitment detection before cooldown check | PASS | `check_existing_companion_record()` called at line 461, cooldown check at line 478 — ordering correct |
| 5 | companion.lua: cooldown deleted on re-recruitment success | PASS | `eq.delete_data(cooldown_key)` at line 473 after `_on_recruitment_success()` |
| 6 | companion.lua: first-time track unchanged | PASS | Cooldown check, `is_eligible_npc()`, persuasion roll all present and unmodified |
| 7 | companion.lua: SQL query alignment with C++ | PASS | Both Lua and C++ use `(is_dismissed = 1 OR is_suspended = 1) LIMIT 1` |
| 8 | companion.cpp: HP/mana restoration after Load() | PASS | `SetHP(GetMaxHP())` + `SetMana(GetMaxMana())` at lines 224-225 in re-recruitment path |
| 9 | companion.cpp: DataBucket cooldown cleanup | PASS | `DataBucket::DeleteData(&database, ...)` at lines 243-246, correct two-arg signature |
| 10 | companion.cpp: cleanup placed in re-recruitment path only | PASS | Both additions are inside the `if (!existing.empty())` block — fresh recruitment path is unchanged |
| 11 | companion_data table: required columns exist | PASS | `is_dismissed` (uint8), `is_suspended` (uint8), `cur_hp` (int64) confirmed in repository header |
| 12 | data_bucket.h: DeleteData signature matches usage | PASS | `DeleteData(SharedDatabase*, const std::string&)` — c-expert correctly used two-arg form |
| 13 | Lua test file: 35 tests present | PASS | `test_companion_recruitment.lua` contains exactly 35 test cases |
| 14 | C++ test file: Suite 19 present and registered | PASS | `TestCompanionReRecruitmentHP()` defined and called in `TestCompanion()` at line 4596 |
| 15 | Log analysis: zone log no companion errors | PASS | zone_dynamic_01.log shows normal companion spawn/group operations, no errors |
| 16 | Log analysis: pre-existing unrelated errors | WARN | zone: packet size mismatch (OP_Damage, pre-existing); world: inventory load error (pre-existing, not companion-related) |
| 17 | Lua syntax: companion.lua file structure valid | PASS | File terminates properly at line 1471, no unmatched function/end pairs detected by static analysis |
| 18 | Lua test: assertion targets match implementation | PASS | All assert_contains() targets verified against actual npc:Say() and client:Message() strings in companion.lua |
| 19 | Docker/build not accessible from WSL session | WARN | Docker Desktop WSL integration not active — build and Lua runtime tests must be run by user (instructions below) |
| 20 | Companion system rules: no changes required | PASS | Architecture confirmed no rule changes; existing rules (LevelRange, MinFaction, etc.) still apply to first-time track only |

---

### Database Integrity

No database schema changes were made. The `companion_data` and `data_buckets` tables already
had all required columns. The following confirms the schema is correct.

**Schema verification (run when Docker is available):**
```sql
-- Verify companion_data has required columns
DESCRIBE companion_data;
-- Expected: is_suspended (tinyint), is_dismissed (tinyint), cur_hp (bigint)

-- Verify no orphaned companion_data records (owner_id references character_data)
SELECT cd.id, cd.owner_id
FROM companion_data cd
LEFT JOIN character_data ch ON cd.owner_id = ch.id
WHERE ch.id IS NULL;
-- Expected: 0 rows

-- Verify no stale cooldown buckets with malformed keys remain
SELECT id, key_name, value
FROM data_buckets
WHERE key_name LIKE 'companion_cooldown_%'
LIMIT 20;
-- Expected: format is companion_cooldown_{npc_type_id}_{char_id}, verify consistent
```

**Static findings:** companion_data_repository.h confirms `is_dismissed` (uint8, default 0)
and `is_suspended` (uint8, default 1) are present. `cur_hp` (int64, default 0) is present.
All columns match what both Lua and C++ query.

---

### Quest Script Syntax

Docker is not accessible from this WSL session. User must run syntax checks as described below.

**Commands to run when server is accessible:**
```bash
# Lua syntax check on companion.lua
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "luajit -bl /home/eqemu/server/quests/lua_modules/companion.lua > /dev/null && echo 'SYNTAX OK'"

# Run the full Lua test suite
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "cd /home/eqemu/server/quests && luajit tests/test_companion_recruitment.lua"
```

**Static analysis findings:**

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| `lua_modules/companion.lua` | Lua | PASS (static) | File terminates at line 1471 with proper `end` statement; all new functions have matching `function`/`end` pairs; no unbalanced control structures found |
| `tests/test_companion_recruitment.lua` | Lua | PASS (static) | 35 test cases, all assertion targets verified against implementation strings |

---

### Log Analysis

**Logs reviewed:** `akk-stack/server/logs/zone_dynamic_01.log`, `world.log`

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| zone_dynamic_01.log | OP_Damage packet size mismatch (got 23, expected 27) | Low (pre-existing) | Client packet, unrelated to companions |
| world.log | Error loading inventory for Chelon | Low (pre-existing) | Inventory, unrelated to companion recruitment |
| zone_dynamic_01.log | Companion HP=0 at depop (Lashun Novashine) | Info (expected) | Dead companion scenario — this is the state the feature is designed to recover from |

**No companion-related errors found in either log.** The companion spawn, group join, level-up,
and depop operations all complete without errors.

---

### Rule Validation

No rule changes were made by this feature. The existing rules are used by the first-time
recruitment track only; re-recruitment bypasses them by code path, not by changing values.

| Rule | Category | Current Value | Notes |
|------|----------|---------------|-------|
| `CompanionsEnabled` | Companions | true | Master toggle; checked by both tracks |
| `LevelRange` | Companions | 3 | First-time track only |
| `MinFaction` | Companions | 3 (Kindly) | First-time track only |
| `BaseRecruitChance` | Companions | 50 | First-time track only |
| `RecruitCooldownS` | Companions | 900 (15 min) | First-time failure only |

---

### Spawn Verification

Not applicable — no spawn point changes. The companion system creates companions dynamically
via `CreateFromNPC()`. No static spawn entries are involved.

---

### Loot Chain Validation

Not applicable — no loot table changes.

---

### Build Verification

C++ source was modified in `eqemu/zone/companion.cpp`. A build is required to validate
the changes compile cleanly. Docker is not accessible from this WSL session.

**Build command (user must run):**
```bash
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "cd ~/code/build && cmake -G Ninja -DEQEMU_BUILD_TESTS=ON .. 2>&1 | tail -5 && ninja -j\$(nproc)"
```

**C++ test suite command (user must run):**
```bash
docker exec akk-stack-eqemu-server-1 bash -c \
  "cd /home/eqemu/server && ./bin/zone tests:companion 2>&1 | grep -A2 'Suite 19'"
```

Expected output for Suite 19:
```
--- Suite 19: Re-recruitment HP restoration and cooldown cleanup ---
[PASS] ...
--- Suite 19 Complete ---
```

- **Result:** PENDING — user must run
- **Errors:** None expected (c-expert confirmed DataBucket signature and HP path correctness)

---

## Part 2: In-Game Testing Guide

### Prerequisites

**Character requirements:**
- A GM-level character (to use `#` commands for setup)
- Access to a zone with respawnable NPCs (East Commonlands or North Ro recommended — many
  humanoid NPCs of various levels, fast respawn timers)
- Character level approximately 30 for level-range tests

**Before starting all tests:**
```
#reloadquests                 -- reload quest scripts to pick up new companion.lua
#reloadrules                  -- reload rules (safety measure)
```

**Useful GM setup commands:**
```
#level 30                     -- set your level to 30 for level-range tests
#zone ecommons                -- zone to East Commonlands (many recruitable NPCs)
#spawn [npcid]                -- spawn specific NPC at your location
#findnpc [partial name]       -- find an NPC by name in zone
#showstats                    -- inspect targeted NPC stats
#kill                         -- kill targeted entity (use carefully for death tests)
```

---

### TEST 1: First-Time Recruitment — Within Level Range (Regression)

**Acceptance criterion:** Player within ±3 levels of NPC can recruit successfully (with sufficient faction and persuasion roll)

**Prerequisite:** Character level 30, in a zone with NPCs level 27-33. No prior companion record for this NPC type.

**Steps:**
1. Set level: `#level 30`
2. Zone to East Commonlands: `#zone ecommons`
3. Find a humanoid NPC level 27-33 (check with `#showstats` after targeting)
4. Verify you have no existing companion record for this NPC type (or use an NPC you have never recruited)
5. Say one of the recruitment keywords: "join me" or "recruit"
6. Observe NPC response

**Expected result:** NPC either says "I will join you." (success) or "I will not join you." (failure). On failure, a 15-minute cooldown is set.

**Pass if:** NPC responds in-character; on success companion spawns and joins your group; on failure cooldown blocks immediate re-attempt
**Fail if:** NPC ignores the keyword entirely; server error message appears; companion fails to spawn on success with no error

---

### TEST 2: First-Time Recruitment — Outside Level Range (Regression)

**Acceptance criterion:** Player outside ±3 levels of NPC is rejected with level range message

**Prerequisite:** Character level 30, targeting an NPC that is level 20 or lower.

**Steps:**
1. Set level: `#level 30`
2. Find an NPC at level 20 or lower (example: low-level gnoll in East Commonlands)
3. Say "join me" to the NPC

**Expected result:** Client message containing "level" (e.g., "[NPC name] is too far from your level to recruit."). NPC does NOT join.

**Pass if:** Level rejection message appears; no companion created
**Fail if:** NPC joins despite level gap; no message appears

---

### TEST 3: First-Time Recruitment Cooldown (Regression)

**Acceptance criterion:** Failed recruitment attempt triggers 15-minute cooldown; cooldown prevents re-attempt

**Prerequisite:** A fresh NPC never recruited before. Character same level as NPC.

**Steps:**
1. Say "join me" to an NPC of same level with low faction — maximize chance of persuasion failure
2. If NPC declines ("I will not join you."), immediately say "join me" again

**Expected result on step 2:** NPC says "[NPC name] won't discuss joining you again so soon."

**Pass if:** Second attempt blocked with cooldown message
**Fail if:** Second attempt processes normally; NPC joins on second try when cooldown should be active

**Optional database verification:**
```sql
SELECT key_name, value, expires FROM data_buckets
WHERE key_name LIKE 'companion_cooldown_%'
ORDER BY id DESC LIMIT 5;
-- Expected: row with companion_cooldown_{npc_type_id}_{char_id} expiring in ~900 seconds
```

---

### TEST 4: Re-Recruitment After Companion Death — Core Case

**Acceptance criterion:** Companion dies, player finds same npc_type_id, says recruitment keyword, companion rejoins immediately

**Prerequisite:** An active companion. A zone with combatable enemies.

**Steps:**
1. Note companion's name, npc_type_id (use `!status`), and current level
2. Let companion die in combat — do NOT resurrect before despawn timer fires
3. Wait for companion to auto-suspend and depop (death despawn timer)
4. Travel to a spawn point where that NPC type appears; find an NPC of the same type
5. Say "join me" or "recruit" to the NPC

**Expected result:** NPC immediately says "I remember you. Let us continue." and joins the group. No cooldown, no level, no faction rejection.

**Pass if:** "I remember you" dialogue; companion spawns immediately; no rejection message; companion HP is at max (verify with `!status` or `#showstats`)
**Fail if:** "won't discuss joining you again so soon" (cooldown); level/faction rejection; companion spawns with 0 HP; companion spawns at base NPC level instead of saved level

**Critical: verify HP after re-recruitment.**
Use `!status` on the newly re-recruited companion. HP must be at maximum, not 0.

---

### TEST 5: Level Preservation on Re-Recruitment

**Acceptance criterion:** Companion returns at saved companion level (not base NPC level)

**Prerequisite:** A companion that has leveled up from their base NPC level through companion XP.

**Steps:**
1. Use `!status` — note companion's current level (e.g., level 35)
2. Note base NPC level (the NPC's level before recruitment, visible as the world NPC level)
3. Cause companion to die and wait for auto-suspend
4. Find the NPC type; say "join me"
5. Use `!status` on the rejoined companion

**Expected result:** Companion level = saved level (e.g., 35), not base NPC level (e.g., 20).

**Pass if:** `!status` shows companion at their saved level; stats scaled to that level
**Fail if:** Companion returns at base NPC level

---

### TEST 6: Equipment Preservation on Re-Recruitment

**Acceptance criterion:** Re-recruited companion returns with all previously equipped items intact

**Prerequisite:** A companion with equipment you gave them.

**Steps:**
1. Use `!equipment` on active companion — note which items they have equipped
2. Cause companion to die and auto-suspend
3. Re-recruit the companion; use `!equipment` on the re-recruited companion

**Expected result:** All items that were equipped before death are still equipped.

**Pass if:** `!equipment` shows same items as before death
**Fail if:** Equipment is missing or reset to defaults

---

### TEST 7: Re-Recruitment After Voluntary Dismissal

**Acceptance criterion:** Dismissed companion can be re-recruited with same bypasses as death re-recruitment

**Steps:**
1. Note companion's level and equipment (`!status`, `!equipment`)
2. Use `!dismiss` — companion says "Farewell for now." and depops
3. Find the same NPC type in the world; say "join me"

**Expected result:** NPC says "I remember you. Let us continue." Companion rejoins at saved level with equipment. No cooldown, no level check, no persuasion roll.

**Pass if:** "I remember you" dialogue; companion at saved level with equipment
**Fail if:** NPC goes through first-time recruitment flow; cooldown message appears

---

### TEST 8: Group Wipe Recovery — Multiple Companions

**Acceptance criterion:** All companions that died in a group wipe can be re-recruited individually without cross-companion interference

**Prerequisite:** At least 2-3 companions active. Access to simulate deaths.

**Steps:**
1. Note all companion names, levels, and NPC types in your group
2. Cause all companions to die (use `#kill` on each while targeting, or engineer a wipe)
3. Wait for all companions to auto-suspend
4. Travel to find each companion's NPC type in sequence; say "join me" to each

**Expected result:** Each companion re-recruits independently with "I remember you." No cross-companion blocking. Full group restored.

**Pass if:** All companions rejoin; no cross-companion blocking; full group restored
**Fail if:** Only first companion works; subsequent companions get cooldown messages

---

### TEST 9: Safety Check — No Re-Recruitment While Player In Combat

**Acceptance criterion:** Player in combat cannot re-recruit a dead companion

**Steps:**
1. Have a suspended companion and enter combat with an NPC
2. While still in combat, say "join me" to the suspended companion's NPC type

**Expected result:** Client message: "You cannot recruit while in combat." Companion does NOT join.

**Pass if:** Combat block message appears; no companion spawned during combat
**Fail if:** Companion joins during combat

---

### TEST 10: Safety Check — No Re-Recruitment When NPC In Combat

**Acceptance criterion:** NPC in combat cannot be re-recruited

**Steps:**
1. Find an NPC of the suspended companion's type that is currently engaged in combat
2. Say "join me" to the combat-engaged NPC

**Expected result:** Client message: "[NPC name] is engaged in combat." Companion does NOT join.

**Pass if:** NPC-in-combat block message appears
**Fail if:** Companion spawns from a combat NPC

---

### TEST 11: Safety Check — Group Full Blocks Re-Recruitment

**Acceptance criterion:** Group at 6 members cannot add a re-recruited companion

**Steps:**
1. Form a full group of 6 members
2. Find the suspended companion's NPC type; say "join me"

**Expected result:** Client message: "Your party is full. Dismiss a companion or group member first."

**Pass if:** Full group blocks re-recruitment with message
**Fail if:** 7th member joins the group

---

### TEST 12: Safety Check — Companion System Disabled

**Acceptance criterion:** When CompanionsEnabled rule is false, all recruitment is blocked

**Steps:**
1. `#rules set Companions CompanionsEnabled false`
2. Say "join me" to a first-time target NPC
3. Also say "join me" to a suspended companion's NPC type
4. `#rules set Companions CompanionsEnabled true` (restore)

**Expected result:** Both attempts blocked with system-not-available message.

**Pass if:** Both tracks blocked when system disabled
**Fail if:** Re-recruitment bypasses the disabled check

---

### TEST 13: Stale Cooldown Cleanup After Re-Recruitment

**Acceptance criterion:** After successful re-recruitment, no companion_cooldown_* data_bucket exists for this npc_type_id + char_id

**Setup (inject stale cooldown via SQL):**
```sql
-- Replace {npc_type_id} and {char_id} with actual values
INSERT INTO data_buckets (key_name, value, expires) VALUES
('companion_cooldown_{npc_type_id}_{char_id}', '1',
 DATE_ADD(NOW(), INTERVAL 900 SECOND));
```

**Steps:**
1. Inject stale cooldown; verify it exists in data_buckets
2. Re-recruit the suspended companion
3. After successful re-recruitment, check data_buckets:
   ```sql
   SELECT * FROM data_buckets WHERE key_name LIKE 'companion_cooldown_%';
   ```

**Expected result:** The `companion_cooldown_{npc_type_id}_{char_id}` row is gone.

**Pass if:** Cooldown entry deleted after re-recruitment
**Fail if:** Cooldown entry persists

---

### TEST 14: Database State Verification After Re-Recruitment

**Acceptance criterion:** After successful re-recruitment, `is_suspended=0`, `is_dismissed=0`

**Steps:**
1. Before re-recruiting, verify companion state:
   ```sql
   SELECT id, name, is_suspended, is_dismissed, level, cur_hp
   FROM companion_data WHERE owner_id = {your_char_id};
   ```
2. Re-recruit the companion
3. Re-query companion_data

**Expected result after re-recruitment:**
```
is_suspended = 0
is_dismissed = 0
```

**Pass if:** Both flags cleared to 0 after re-recruitment
**Fail if:** Either flag remains 1 after companion is active

---

### TEST 15: Database State After Companion Death

**Acceptance criterion:** After companion death, `is_suspended=1`; equipment rows in companion_inventories preserved

**Steps:**
1. Before companion dies, note companion_data state
2. Cause companion to die and wait for auto-suspend
3. Check companion_data and companion_inventories:
   ```sql
   SELECT id, is_suspended, is_dismissed FROM companion_data WHERE owner_id = {char_id};
   SELECT ci.* FROM companion_inventories ci
   JOIN companion_data cd ON ci.companion_id = cd.id WHERE cd.owner_id = {char_id};
   ```

**Expected result:**
- `is_suspended = 1` after death/auto-suspend
- Equipment rows in companion_inventories unchanged

**Pass if:** is_suspended set to 1; equipment intact
**Fail if:** Equipment rows deleted on death; is_suspended not set

---

### Edge Case Tests

---

### TEST E1: Two NPCs of Same Type — Re-Recruit from Second Instance

**Risk from architecture plan:** "Q3: two NPCs of the same npc_type_id simultaneously — first NPC recruited depops. If companion dies and player finds second NPC of same type, CreateFromNPC() should correctly reuse the existing record."

**Steps:**
1. Find a zone where two NPCs of the same npc_type_id exist
2. Recruit the first one — it depops and becomes your companion
3. Cause the companion to die and auto-suspend
4. Find the second NPC of the same type; say "join me"

**Expected result:** Second NPC says "I remember you. Let us continue." Companion returns at saved level with equipment.

**Pass if:** Re-recruitment from second NPC instance works correctly
**Fail if:** Error appears; companion loads at base level; first-time flow triggers

---

### TEST E2: Re-Recruitment with is_suspended=1 and cur_hp > 0 (Zoned-Out Alive)

**Risk from architecture plan:** "Q1: is_suspended=1 with cur_hp > 0 — companion zoned out alive but became suspended. Should bypass checks."

**Steps:**
1. Have an active companion
2. Zone to a new area — companion follows
3. Log out while companion is active; log back in to a different zone
4. If companion did not auto-respawn, find the companion's NPC type; say "join me"

**Expected result:** Companion rejoins with "I remember you" (bypass checks), not through first-time flow.

**Pass if:** "I remember you" dialogue; companion at saved level
**Fail if:** Level range or cooldown blocks re-join after log/zone

---

### TEST E3: Rapid Dismiss and Immediate Re-Recruit

**Risk from architecture plan:** "Player dismisses companion, immediately says recruit keyword to same NPC type before DB write completes — Dismiss() calls Save() synchronously."

**Steps:**
1. Use `!dismiss` on a companion
2. As quickly as possible, find another NPC of the same type; say "join me"

**Expected result:** Re-recruitment succeeds with "I remember you." (DB write from Dismiss() is synchronous — record already committed.)

**Pass if:** Re-recruitment succeeds; "I remember you" dialogue
**Fail if:** First-time flow triggers (level/faction check)

---

### TEST E4: First-Time Recruitment Regression — Excluded NPC Types

**Acceptance criterion:** Excluded NPC types (pets, bots, mercs, bankers, guildmasters) cannot be recruited

**Steps:**
1. Target a merchant or banker NPC; say "join me"
2. Target a mercenary (if any exist); say "join me"

**Expected result:** Client message indicating that type cannot be recruited. No companion created.

**Pass if:** Exclusion message appears; no companion spawned
**Fail if:** Banker or merc joins party

---

## Rollback Instructions

If something goes wrong during testing and you need to restore the previous recruitment behavior:

**Quest script rollback (revert Lua changes only — no rebuild needed):**
```bash
cd /mnt/d/Dev/eq/akk-stack
git checkout master -- server/quests/lua_modules/companion.lua
# Then reload quests in-game: #reloadquests
```

**Full feature branch rollback (Lua + C++ — requires rebuild):**
```bash
cd /mnt/d/Dev/eq/akk-stack
git checkout master
cd /mnt/d/Dev/eq/eqemu
git checkout master
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j\$(nproc)"
```

**Database cleanup (remove test-injected stale cooldowns):**
```sql
DELETE FROM data_buckets WHERE key_name LIKE 'companion_cooldown_%';
```

**Restore a companion to active state manually (if re-recruitment fails and companion is stuck):**
```sql
UPDATE companion_data SET is_suspended = 0, is_dismissed = 0
WHERE owner_id = {your_char_id} AND name = '{companion_name}';
```

---

## Required Server-Side Commands Before In-Game Testing

The C++ binary must be rebuilt to include the HP/mana restoration fix. Without this rebuild,
dead companions may re-recruit with 0 HP (the bug identified in the architecture plan).

```bash
# Step 1: Build with tests enabled
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "cd ~/code/build && cmake -G Ninja -DEQEMU_BUILD_TESTS=ON .. 2>&1 | tail -5 && ninja -j\$(nproc)"

# Step 2: Run C++ Suite 19 tests (HP restoration + cooldown cleanup)
docker exec akk-stack-eqemu-server-1 bash -c \
  "cd /home/eqemu/server && ./bin/zone tests:companion 2>&1 | grep -E '(Suite 19|PASS|FAIL)'"

# Step 3: Run Lua test suite (35 tests)
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "cd /home/eqemu/server/quests && luajit tests/test_companion_recruitment.lua"

# Step 4: Restart server processes
# Via Spire at http://192.168.1.86:3000 or: cd /mnt/d/Dev/eq/akk-stack && make restart
# Then start zone processes per MEMORY.md server startup procedure

# Step 5: Hot-reload quests in-game
# #reloadquests
```

---

## Blockers

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|-------------------|--------|
| 1 | C++ binary rebuild required before in-game testing — dead companions may spawn at 0 HP without rebuild | High | user | Open — user must run build and restart server before TEST 4-15 |
| 2 | Docker not accessible from current WSL session — Lua tests and C++ build not run automatically | High | user | Open — user must run docker commands manually |

---

## Recommendations

- Run the Lua test suite first (`luajit tests/test_companion_recruitment.lua`). If all 35 tests
  pass, the recruitment logic is correct. In-game testing then focuses on the C++ HP restoration
  path and end-to-end integration.

- TEST 4 (re-recruitment after death with HP verification) is the most important in-game test.
  It validates the new C++ HP/mana restoration code. Check companion HP via `!status` immediately
  after re-recruitment — if HP is at max, the fix is working. If HP is 0, the binary needs to be
  rebuilt.

- For TEST 8 (group wipe), using `#kill` on each companion individually is faster and more
  reproducible than engineering a true group wipe in a dungeon.

- After TEST 14 (database state verification), also confirm the `level` column in `companion_data`
  matches the level shown in-game to verify level preservation end-to-end through Load() →
  ScaleStatsToLevel().

- The pre-existing log warning `Error loading inventory for Chelon` (world.log) and the
  OP_Damage packet mismatch (zone log) are unrelated to this feature and should not block
  validation.
