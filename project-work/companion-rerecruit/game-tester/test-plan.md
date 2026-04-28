# Companion Re-recruitment Fix — Test Plan

> **Feature branch:** `bugfix/companion-rerecruit`
> **Author:** game-tester
> **Date:** 2026-04-28
> **Server-side result:** PASS

---

## Test Summary

Validates the companion re-recruitment fix: a single-character change in
`companion.lua:1434` (`Dismiss(true)` to `Dismiss(false)`) that closes the
SoulWipe bug — voluntary dismiss was deleting the `companion_data` row,
causing the two-track recruitment system to fall through to Track 2
(full first-recruit checks including level range and cooldown). After the
fix, dismiss correctly sets `is_suspended=1` and `is_dismissed=1` on the
row, leaving it findable for Track 1 (re-recruit path, no level checks, no
cooldown).

**Systems affected:** `companion.lua`, `companion_data` table (ghost row
deleted), `test_companion_recruitment.lua` (5 new TDD tests added).

**No C++ changes. No schema changes. No rule_values changes. No build required.**

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] status.md — all implementation tasks Complete (Tasks 1-7; Task 8 this document)
- [x] Acceptance criteria identified: 10 criteria (AC-1 through AC-10)

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Commit presence: akk-stack 76e6753 (failing TDD tests) | PASS | Confirmed on bugfix/companion-rerecruit |
| 2 | Commit presence: akk-stack ad79630 (fix) | PASS | Confirmed on bugfix/companion-rerecruit |
| 3 | Commit presence: akk-stack 7101248 (Makefile target) | PASS | Confirmed on bugfix/companion-rerecruit |
| 4 | Commit presence: claude lua-expert + data-expert dev-notes | PASS | f55ffbf and 5decc45 on bugfix/companion-rerecruit |
| 5 | `make test-companion` — 50 main tests | PASS | 50/50 passed, 0 failed |
| 6 | `make test-companion` — 8 edge case tests | PASS | 8/8 passed, 0 failed |
| 7 | TDD tests: all 5 new TDD tests pass | PASS | TDD-1 through TDD-5 all green |
| 8 | Ghost row `companion_data.id=21` deleted | PASS | SELECT returns 0 rows |
| 9 | Canonical Lydl row `companion_data.id=10` intact | PASS | level=53, is_suspended=1, 14 gear items |
| 10 | Canonical Hollish row `companion_data.id=18` intact | PASS | level=53, is_suspended=0, 15 gear items |
| 11 | DB integrity: 5 companion rows total for owner_id=6 | PASS | ids 10,18,22,23,24 |
| 12 | Stale cooldowns in `data_buckets` | PASS | 0 rows with key LIKE 'companion_cooldown_%' |
| 13 | `companion.lua` syntax check (luajit -bl) | PASS | No errors |
| 14 | Line 15 doc comment corrected (parameter semantics) | PASS | `false=voluntary preserve, true=permanent SoulWipe` |
| 15 | Line 207 LevelRange fallback `or 50` | PASS | Confirmed in live file |
| 16 | Line 1434 `Dismiss(false)` (not true) | PASS | Confirmed in live file |
| 17 | Lines 394-397 `ORDER BY level DESC, experience DESC, id DESC` | PASS | Confirmed in live file |
| 18 | Log scan: companion/recruit/dismiss errors | PASS | No errors in zone_dynamic_01.log through zone_dynamic_04.log |
| 19 | Rule validation: `Companions:LevelRange` = 50 | PASS | rule_values confirms value=50 |
| 20 | Rule validation: `Companions:RecruitCooldownS` = 900 | PASS | rule_values confirms value=900 |
| 21 | Build verification | PASS (N/A) | No C++ changes; no build required |

### Database Integrity

**Queries run:**

```sql
-- Ghost row deletion confirmed:
SELECT * FROM companion_data WHERE id = 21;
-- Result: 0 rows (empty)

-- Canonical companion rows intact:
SELECT id, name, level, experience, is_suspended, is_dismissed, cur_hp
FROM companion_data WHERE owner_id = 6 ORDER BY id;
-- Result: 5 rows — ids 10,18,22,23,24

-- Gear preservation (sample):
SELECT cd.id, cd.name, COUNT(ci.id) as inventory_items
FROM companion_data cd
LEFT JOIN companion_inventories ci ON ci.companion_id = cd.id
WHERE cd.owner_id = 6 GROUP BY cd.id ORDER BY cd.id;
-- Result: 10→14 items, 18→15 items, 22→17 items, 23→11 items, 24→13 items

-- No stale cooldowns:
SELECT COUNT(*) FROM data_buckets WHERE `key` LIKE 'companion_cooldown_%';
-- Result: 0

-- No currently dismissed rows (all re-recruitable):
SELECT id, npc_type_id, name, is_suspended, is_dismissed
FROM companion_data WHERE is_dismissed = 1 OR is_suspended = 1;
-- Result: 1 row — id=10, Lydl the Great, is_suspended=1 (correct — died in combat)
```

**Findings:** Database state is clean and consistent. All 5 companion rows are
valid. Ghost row id=21 is gone. Zero stale cooldowns. Lydl (id=10) has
`is_suspended=1` which is the correct state after combat death — Track 1 will
find this row on next re-recruit attempt.

### Quest Script Syntax

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Lua | PASS | luajit -bl returns clean |
| `akk-stack/server/quests/tests/test_companion_recruitment.lua` | Lua | PASS | 50 tests run and pass |
| `akk-stack/server/quests/tests/test_companion_rerec_edge_cases.lua` | Lua | PASS | 8 tests run and pass |

### Log Analysis

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| zone_dynamic_01.log | 0 errors | — | No companion/recruit/dismiss errors |
| zone_dynamic_02.log | 0 errors | — | Clean |
| zone_dynamic_03.log | 0 errors | — | Clean |
| zone_dynamic_04.log | 0 errors | — | Clean |

Note: Zone logs show normal companion activity (SpawnCompanionsOnZone, CreateFromNPC
for re-recruitment of id=18 Hollish Tnoops). Several `Warning | Death` entries show
the SQL fallback path for companions who died with entity id=0 — these are expected
behavior from the death handling path (not errors introduced by this fix).

### Rule Validation

| Rule | Category | Value | Valid Range | Result |
|------|----------|-------|-------------|--------|
| LevelRange | Companions | 50 | >0 = active, 0 = disabled | PASS |
| RecruitCooldownS | Companions | 900 | >0 | PASS |
| MaxPerPlayer | Companions | 5 | >0 | PASS |
| CompanionsEnabled | Companions | true | bool | PASS |
| DismissedRetentionDays | Companions | 30 | >0 | PASS |

Note: `LevelRange=50` matches the Lua fallback hardening (`or 50` at line 207).
This means even if `rule_values` is wiped, the fallback matches DB intent — the
first-recruit level window remains 50 levels (very permissive but not unlimited).

### Spawn Verification

Not applicable. No new spawns created. No spawn table modifications. The fix
affects runtime behavior only (dismiss preserves the companion_data row instead
of deleting it).

### Loot Chain Validation

Not applicable. No loot tables modified.

### Build Verification

**Not required.** Zero C++ changes in this bugfix. The fix is Lua-only.

The zone processes (dynamic_01 through dynamic_08) started on Apr 27. The
`companion.lua` fix was applied on Apr 28 09:33. Zone processes use
`#reloadquests` (which calls `lua_close()` + `luaL_newstate()` — a complete
Lua state reinitialize), so the fix is live after the user runs
`#reload quest global` in any zone.

**Deployment action required before in-game testing:**
```
#reload quest global
```
This reloads quest scripts across all running zones. No restart required.

---

## Part 2: In-Game Testing Guide

### Prerequisites

```
Character: Chelon (or any character who has recruited companions before)
Zone: East Freeport (freporte) is the primary test zone — Lydl the Great spawns here
      at approximately (-1174, -964, -51)
Access: GM account with #reload, #zone, #goto, #kill, #showstats
Companions needed:
  - Lydl the Great (already recruited as companion_data id=10, is_suspended=1,
    level 53, 14 gear items — ready to be re-recruited without additional setup)
  - Any other previously-recruited companion for regression checks
    (Hollish Tnoops, Jimble Woodentoe, Jracol Brestiage, or Lashun Novashine)
```

**Before starting any in-game test, run this command in-game to load the fix:**

```
#reload quest global
```

Wait for the confirmation message, then proceed with the scenarios below.

---

### Test 1: Re-recruit Lydl after combat death (AC-3, AC-5, AC-6)

**Acceptance criteria:**
- AC-3: A previously-recruited NPC can be re-recruited immediately after death — no cooldown wait.
- AC-5: Re-recruited companion's level exactly matches their level at drop-out.
- AC-6: Re-recruited companion's gear (equipped + carried) exactly matches their inventory at drop-out.

**Setup note:** Lydl (companion_data id=10) is already in `is_suspended=1` state from a
prior combat death. This test exercises the re-recruit path directly without needing to
first kill the companion.

**Steps:**

1. Log in as Chelon. Run `#reload quest global` and wait for confirmation.
2. Run `#zone freporte` to travel to East Freeport.
3. Run `#goto freporte -1174 -964 -51` to get near Lydl's spawn point.
4. Find Lydl the Great. Run `#findnpc Lydl` if needed.
5. Target Lydl and run `#showstats` — note Lydl's current base level (NPC base is 4).
6. With Lydl targeted, say: `recruit`
   (or any recruitment keyword: "join me", "will you join", "join my party")
7. Expected: Lydl responds with the re-recruit dialogue (something like
   "I remember you. Let us continue." or similar). Lydl joins the group.
8. Open the group window. Verify Lydl is in the group.
9. Target Lydl (companion). Note Lydl's displayed level.
   Expected: Level 53 (companion_data level, not NPC base level of 4).
10. Type `!stats` with Lydl targeted.
    Expected: Stats show level 53, gear equipped. No gear loss.
11. Check that the re-recruit happened IMMEDIATELY — no "won't discuss joining you
    again so soon" message appeared. No waiting was required.

**Pass if:**
- Lydl joins the group immediately on saying "recruit"
- No cooldown error message appears
- No "too low level" or "too far from your level" message appears
- Lydl rejoins at level 53 (not level 4 which is the NPC base level)
- Lydl has 14 gear items (use `!stats` or open trade window to verify gear is present)

**Fail if:**
- "won't discuss joining you again so soon" message appears (cooldown blocking)
- "is too far from your level to recruit" message appears (level check blocking)
- Lydl joins but at level 4 instead of level 53 (level reset)
- Lydl joins but gear is missing (gear reset)
- Lydl refuses to recruit for any other reason

**GM commands for setup:**
```
#reload quest global
#zone freporte
#goto freporte -1174 -964 -51
#findnpc Lydl
```

---

### Test 2: Re-recruit immediately after voluntary dismiss (AC-4, AC-5, AC-6) — canonical bug repro

**Acceptance criteria:**
- AC-4: A previously-recruited NPC can be re-recruited immediately after dismissal — no cooldown wait.
- AC-5: Level preserved after dismiss-and-rerecruit cycle.
- AC-6: Gear preserved after dismiss-and-rerecruit cycle.

**This is the canonical bug repro for BUG-001.** Before the fix, this would delete
the companion_data row via SoulWipe, causing Track 2 (level checks, cooldown) to fire.

**Prerequisite:** Complete Test 1 first so Lydl is active as a companion.

**Steps:**

1. With Lydl active in the group, note Lydl's current level (should be 53) and gear.
2. Type `!stats` with Lydl targeted. Record the level and any visible gear.
3. Target Lydl (the companion NPC in your group, not the world NPC).
4. Type `!dismiss`
   Expected: Lydl says "Farewell." and despawns. No error messages.
5. Immediately (within seconds) walk back to the original Lydl spawn point
   at (-1174, -964, -51) in East Freeport.
   Note: the world NPC Lydl should have respawned or already be at the spawn point.
6. Target the world NPC Lydl (not a companion). Say: `recruit`
7. Expected: Lydl rejoins immediately. The re-recruit dialogue fires.
   No cooldown message. No level rejection.
8. Verify level (should be 53 — same as before dismiss).
9. Verify gear is intact (use `!stats`).

**Pass if:**
- Lydl accepts re-recruitment immediately after `!dismiss`
- No "won't discuss joining you again so soon" message
- No "too far from your level" message
- Lydl rejoins at same level as before dismiss
- Gear is fully preserved

**Fail if:**
- Any cooldown or level-range blocking message appears
- Lydl joins but at a different level
- Gear is missing after re-recruitment

---

### Test 3: Level delta check — player at higher level than companion (AC-1, AC-2)

**Acceptance criteria:**
- AC-1: A previously-recruited NPC can be re-recruited at any player level.
- AC-2: No "too low level" error path is reachable for a previously-recruited NPC.

**Context:** This simulates the Scenario A from the PRD — the original bug where a
player's character has leveled far above the companion's NPC base level. Lydl's NPC
base level is 4; with player at 55+, the level delta would be >50 (beyond
`Companions:LevelRange=50`), which triggers "too far from your level" for new recruits.

**Prerequisite:** Lydl is currently dismissed (complete Test 2 first).

**Steps:**

1. Set your character to a level that is more than 50 above Lydl's NPC base level (4).
   Lydl's base level is 4, so set yourself to level 55 or higher:
   ```
   #level 60
   ```
2. Walk to Lydl's spawn in East Freeport (-1174, -964, -51).
3. Target Lydl (world NPC) and say: `recruit`
4. Expected: Lydl accepts immediately. The re-recruit path fires (Track 1), which
   bypasses the level range check entirely. Lydl rejoins at level 53.
5. Verify level 53 and gear intact.
6. Now dismiss Lydl again (`!dismiss`) and immediately re-recruit. Same result expected.
7. After the test, restore your character level: `#level 55` (or your preferred level).

**Pass if:**
- Lydl re-recruits regardless of the player level vs. NPC base level gap
- No "too far from your level to recruit" message
- Lydl rejoins at companion level 53, not NPC base level 4

**Fail if:**
- "is too far from your level to recruit" message appears at any point during
  re-recruitment of Lydl

**GM commands:**
```
#level 60
#goto freporte -1174 -964 -51
#level 55   (restore afterward)
```

---

### Test 4: First-recruit gating preserved — no regression (AC-7)

**Acceptance criteria:**
- AC-7: First-recruitment of a never-before-recruited NPC still enforces existing rules
  (level range, faction, etc.).

**Purpose:** Confirm the fix did NOT accidentally remove all level/cooldown gating.
The bypass only applies to previously-recruited NPCs (Track 1). Track 2 must still
enforce all 11 eligibility checks for first-time recruits.

**Steps:**

1. Find an NPC that is NOT in your companion_data — a never-before-recruited NPC.
   Look for a random monster or guard in the zone. The key is that there is no
   `companion_data` row for this NPC's `npc_type_id` with your `owner_id`.
2. Set your character to a level that is more than 50 levels away from the NPC's level.
   For example: if the NPC is level 5, set yourself to level 60:
   ```
   #level 60
   ```
3. Target the NPC and say: `recruit`
4. Expected: The NPC rejects with a "too far from your level to recruit" message.
   This is Track 2 (first-time recruit path) working correctly.

**Note:** If the NPC's level is actually within your LevelRange (50 levels), the
NPC will not reject on the level check. You may need to deliberately find a very
low-level mob while at high level, or vice versa. The `Companions:LevelRange=50`
means if you are level 60 and the NPC is level 5, the delta is 55 > 50 → rejection.

**Pass if:**
- The "too far from your level to recruit" message appears for a never-recruited NPC
  when the level delta exceeds `Companions:LevelRange` (50)

**Fail if:**
- The NPC accepts recruitment despite being outside the level range
  (would indicate the fix accidentally disabled first-recruit gating)

**GM commands:**
```
#level 60
```

---

### Test 5: Re-recruit after combat death — live test (AC-3)

**Acceptance criteria:**
- AC-3: Re-recruit immediately after death — no cooldown wait.

**Purpose:** End-to-end death-and-rejoin cycle with a fresh kill. Lydl is already
`is_suspended=1` from a prior death (Test 1 above covers this scenario). This test
validates the LIVE kill path if you want to witness the full cycle.

**Optional — can skip if Test 1 already passed.** Only run this if you want to
see the full death cycle from scratch.

**Steps:**

1. First, recruit Lydl (from Test 1 or 2) so Lydl is active in group.
2. Find combat against a mob Lydl cannot survive. You can use `#kill` on a very
   strong mob to spawn near Lydl, or find a high-level mob in the zone.
   Alternatively: target Lydl (companion) and use `#kill` on Lydl if there's a GM
   command for that. (Check with `#help kill`.)
3. Alternative approach: Zone to Nagafen's Lair (`#zone soldungb`) where Lydl previously
   died (log shows the death was there). Run into Nagafen combat with Lydl in group.
4. When Lydl dies, a death message should appear. Lydl despawns.
5. Immediately travel back to East Freeport (`#zone freporte`) to Lydl's spawn.
6. Target Lydl (world NPC) and say: `recruit`
7. Expected: Lydl accepts IMMEDIATELY. No cooldown. No level check.
8. Lydl rejoins at the same level and with the same gear.

**Pass if:**
- Lydl re-recruits immediately after combat death with no blocking messages
- Level and gear are preserved

**Fail if:**
- Any cooldown or rejection message appears after combat death

**GM commands:**
```
#zone freporte
#goto freporte -1174 -964 -51
```

---

### Test 6: Gear preservation across dismiss-rerecruit cycle (AC-6)

**Acceptance criteria:**
- AC-6: Re-recruited companion's gear exactly matches their inventory at drop-out.

**Purpose:** Verify that gear is not lost during dismiss and re-recruit. This is
verified indirectly by Test 2 (Lydl has 14 known gear items), but if you want to
trace a specific item:

**Steps:**

1. Recruit Lydl (active in group).
2. Open a trade window with Lydl. Note or record any visible equipped items.
   Use `!stats` for a stats readout that shows equipped gear effects.
3. Record Lydl's current level (53) as the reference.
4. Dismiss Lydl (`!dismiss`).
5. Re-recruit Lydl immediately (as in Test 2).
6. Open a trade window with Lydl again. Verify gear is identical to step 2.
7. Use `!stats` again and compare to step 2 readout.

**Pass if:**
- All gear items present before dismiss are present after re-recruitment
- `!stats` output is identical (or only differs in HP/MP which may have been
  restored to full on re-recruit)
- No "Your companion has lost items" or similar error messages

**Fail if:**
- Any gear items are missing after re-recruitment

---

### Test 7: AC-10 — Lydl Mastat quest interaction

**Acceptance criteria:**
- AC-10: Re-recruitment of an NPC who is also a kill target or dialogue node in an active
  quest still succeeds per the invariant.

**Context:** Lydl the Great is a kill target in the Lydl Mastat Freeport wizard-guild
quest. The architecture doc confirms no quest-state gating is added — the invariant
overrides quest gating. The re-recruit path (Track 1) short-circuits before any
exclusion checks.

**Steps:**

1. Check if you have the Lydl Mastat quest active. If not, this test can be
   considered implicitly covered by Tests 1-3 (Lydl re-recruits regardless).
2. If you have the quest active: approach Lydl, say `recruit`.
   Expected: Lydl accepts normally. The quest state does NOT block re-recruitment.
3. Optional: with Lydl recruited, kill Lydl in combat.
   Expected: Quest kill credit fires (if applicable). Companion death path runs normally.
   Lydl can be re-recruited afterward per the invariant.

**Pass if:**
- Lydl accepts re-recruitment regardless of whether the Lydl Mastat quest is active
- Quest state (active or complete) does not appear in any rejection message

**Fail if:**
- "NPC is involved in an active quest" or any quest-related rejection message appears

---

### Test 8: Companion XP gain regression check

**Acceptance criteria (regression):** Companion XP gain still works correctly.
The `feature/xp-retune` branch merged before this fix — verify no regression.

**Steps:**

1. Recruit Lydl (active in group at level 53).
2. Note Lydl's current experience value. (Use `!stats` if it shows XP, or check DB:
   ```sql
   SELECT experience FROM companion_data WHERE id = 10;
   ```
   Current value: 8,106,020)
3. Kill some mobs together with Lydl in the group.
4. After a kill, check if Lydl's XP has increased. Either watch for a level-up message
   or re-query the DB.
5. Expected: XP increases after kills in which Lydl participated.

**Pass if:**
- Companion XP increases after combat participation

**Fail if:**
- Companion XP does not change at all after multiple kills
  (would indicate an XP system regression)

**GM commands for fast XP check:**
```sql
-- Before kill:
SELECT id, level, experience FROM companion_data WHERE id = 10;
-- Kill mobs, then:
SELECT id, level, experience FROM companion_data WHERE id = 10;
```

---

### Test 9: Normal companion dismissal — no error messages

**Acceptance criteria (regression):** Normal companion dismissal still works cleanly.

**Steps:**

1. Recruit any companion (e.g., Lydl from Test 1).
2. Target the companion. Type `!dismiss`.
3. Expected: Companion says "Farewell." and despawns cleanly.
4. Verify: No error messages in chat. No zone crash. Companion is gone from group list.

**Pass if:**
- `!dismiss` completes cleanly with "Farewell." message
- Companion leaves the group
- No error messages appear

**Fail if:**
- Error message appears after `!dismiss`
- Companion does not despawn
- Any Lua error in chat log

---

### Test 10: Group capacity regression check (AC-8)

**Acceptance criteria:** Concurrent re-recruit attempts cannot produce a
double-recruited companion (AC-8). Also verifies group-full gating still works.

**Context:** With 5 companions already active (player + 5 = 6 members, at the
`MaxPerPlayer=5` cap), a 6th recruit attempt should be blocked.

**Steps:**

1. Check how many companions are currently in your group.
   Current state: companions Hollish Tnoops (id=18), Jimble Woodentoe (id=22),
   Jracol Brestiage (id=23), and Lashun Novashine (id=24) are all active (not suspended).
   Plus Lydl who may or may not be active depending on prior tests.
2. If you have fewer than 5 companions active, recruit companions until you have 5
   (the max). With the player + 5 companions = 6 group members.
3. Find any recruitable NPC. Say: `recruit`
4. Expected: NPC rejects with "Your party is full." or similar group-capacity message.
5. Dismiss one companion (`!dismiss`). Now you have 4 companions + player = 5 members.
6. Re-recruit the 5th companion. Expected: succeeds immediately.

**Pass if:**
- Recruitment blocked when group is full (6 members)
- Recruitment succeeds when group has room (5 members)

**Fail if:**
- A 6th companion is added to a full group (capacity gate bypassed)
- Re-recruitment fails when group has room

---

## Edge Case Tests

### Test E1: Dismiss mid-zoning (antagonistic scenario from architecture plan)

**Risk from architecture plan:** "Player dismisses a companion mid-zoning. The
companion is already despawning. `Dismiss(false)` writes to DB; if the zone
process crashes between SetSuspended/SetDismissed and Save(), the row may be
stale on the next zone load."

**Steps:**

1. Start zoning to another zone (e.g., `/zone northkarana`).
2. Quickly target a companion and type `!dismiss` during the zone loading screen.
   (This is difficult to test precisely — the companion may already be despawning.)
3. After zoning in, travel back to the original zone.
4. Attempt to re-recruit the companion.

**Expected behavior:** Either the companion re-recruits normally (row was saved
before despawn) OR the companion appears still-active and does not need re-recruiting
(zone load brought them back). No corrupted state.

**Pass if:** Companion is either re-recruitable or still active. No "stuck" state.
**Fail if:** Companion is neither active nor re-recruitable after mid-zone dismiss.

---

### Test E2: First-recruit cooldown after failed persuasion (regression)

**Risk:** Fix must not break the cooldown that applies after a FAILED first-time
persuasion roll. (This is `Companions:RecruitCooldownS=900` applying to Track 2.)

**Steps:**

1. Find a never-before-recruited NPC of appropriate level.
2. Set `Companions:BaseRecruitChance` low enough to make failure likely:
   ```
   #reloadrules
   ```
   (Check current BaseRecruitChance: it's 100 in rule_values — meaning 100% success.
   If it's 100%, the persuasion roll always succeeds and a cooldown from failure
   cannot be directly tested without modifying the rule or using a test fixture.)
3. Alternative: Note that the TDD suite covers this case (`test_first_recruit_still_gates`
   and `TDD-4` pass — these cover the regression at the unit level).

**Note:** With `Companions:BaseRecruitChance=100`, first-recruit persuasion always
succeeds and cooldown is never set on success. The cooldown system is only set on
failure. This edge case is fully covered by the TDD suite (50 passing tests) and
does not require in-game verification unless a specific failure scenario is needed.

**Pass if:** TDD tests for first-recruit cooldown pass (confirmed via `make test-companion`).

---

## Deployment Instructions

Before the user runs in-game tests, apply the fix to the running server:

```
In-game (as GM):
#reload quest global
```

This command:
1. Calls `ReloadQuests()` on all running zone processes
2. Closes the current Lua state (`lua_close(L)`)
3. Creates a fresh Lua state (`luaL_newstate()`)
4. Reloads all scripts including `companion.lua` from disk

The updated `companion.lua` (with `Dismiss(false)` at line 1434) will be live
immediately after the reload completes.

**No server restart required. No Docker restart required. No build required.**

---

## Rollback Instructions

If something goes wrong during testing:

### Rollback the Lua fix

```bash
# In the akk-stack directory on host:
cd /mnt/d/Dev/eq/akk-stack
git revert ad79630   # the fix commit
# This restores companion.lua:1434 to Dismiss(true)
# Then reload in-game: #reload quest global
```

### Restore ghost row (if needed for repro purposes)

```sql
-- Only if you need to test the original broken state:
INSERT INTO companion_data (owner_id, npc_type_id, name, level, experience, is_suspended, is_dismissed)
VALUES (6, 9144, 'Hollish Tnoops', 14, 0, 1, 0);
-- Note: this creates a new ghost row with a new id, not id=21
```

### Emergency: full companion_data restore from backup

If companion data is corrupted during testing, contact the orchestrator to
restore from a database backup. The `claude/tmp/` directory may have backups
from recent sessions.

---

## Blockers

No blockers found. All server-side checks passed. Deployment instructions are clear.

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|-------------------|--------|
| — | None | — | — | — |

---

## Recommendations

1. **companion-commands-reference.md update needed (non-blocking):** The reference doc
   at `claude/docs/companion-commands-reference.md` line 147 still says
   `Companion::Dismiss(true)`. This should be updated to `Dismiss(false)` to match
   the fix. This is documentation-only and does not affect gameplay. Recommend updating
   in a follow-up commit.

2. **Future work: zone-disconnect and group-disband drop-out paths** (from architecture
   doc Out-of-Scope section): These paths were not traced during this fix. They should
   be verified to write `is_suspended=1` so that re-recruit works after them too.
   Currently not failing per the bug report.

3. **Future work: `UNIQUE (owner_id, npc_type_id)` constraint** on `companion_data`:
   The dismiss fix closes the most common ghost-row creation vector. Adding the
   UNIQUE constraint would prevent future ghost rows entirely but requires C++ UPSERT
   changes. Track as future work.

4. **Lydl's current state**: Lydl (companion_data id=10, `is_suspended=1`) is ready
   to re-recruit RIGHT NOW without any additional setup. Test 1 can be run immediately
   after applying `#reload quest global`.
