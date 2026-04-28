# Companion Re-recruitment Fix — Test Plan (v2)

> **Feature branch:** `bugfix/companion-rerecruit`
> **Author:** game-tester
> **Date:** 2026-04-28 (v1) / 2026-04-28 (v2 update)
> **Server-side result (v1):** PASS
> **Server-side result (v2):** PASS

---

## Test Summary

**v1 fix:** A single-character change in `companion.lua:1434` (`Dismiss(true)` to
`Dismiss(false)`) closes the SoulWipe bug — voluntary dismiss was deleting the
`companion_data` row, causing the two-track recruitment system to fall through to
Track 2 (full first-recruit checks including level range and cooldown). After the
fix, dismiss correctly sets `is_suspended=1` and `is_dismissed=1` on the row,
leaving it findable for Track 1 (re-recruit path, no level checks, no cooldown).

**v2 fix:** Widens the Track 1 lookup from strict `npc_type_id` match to
`companion_data.name` match (keyed on `npc:GetCleanName()`). This handles
multi-variant NPCs where the zone can spawn a different `npc_type_id` than the
one stored in `companion_data` (e.g., `Lydl_the_Great` has three freporte variants:
10162, 10178, 10181). Both `companion.lua` (Lua Track 1) and `companion.cpp`
(C++ `CreateFromNPC`) are changed in lockstep. A Q7 exclusion guard in
`is_re_recruitment_eligible()` prevents the name-match from bypassing
`companion_exclusions` for excluded target NPCs. C++ rebuild was required.

**Systems affected:**
- `companion.lua` — v1: `Dismiss(false)` fix; v2: name-based lookup + Q7 guard + `_lookup_exclusion` helper
- `companion.cpp` — v2: name-based SQL at line 218-220 with `Strings::Escape` binding, ORDER BY tie-breaker, diagnostic log
- `companion_data` table — v1: ghost row id=21 deleted
- `test_companion_recruitment.lua` — v1: 5 TDD tests; v2: 3 additional TDD tests (61 total)
- `cli_companion_tests.cpp` — v2: Suite 35 added (569 total cases across 35 suites)

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md` (v1 + v2 + V2 CRITICAL UPDATE + V2 CORRECTIONS)
- [x] status.md — v1 tasks 1-8 Complete; v2 tasks V2-1 through V2-7 (this document is V2-7)
- [x] Acceptance criteria identified: 10 criteria (AC-1 through AC-10)

---

## Part 1: Server-Side Validation

### Results — v1 (original validation, 2026-04-28)

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
| 21 | Build verification (v1) | PASS (N/A) | No C++ changes in v1; no build required |

### Results — v2 (this validation pass, 2026-04-28)

| # | Check | Result | Details |
|---|-------|--------|---------|
| 22 | Commit presence: akk-stack eb88551 (v2 TDD tests) | PASS | Confirmed on bugfix/companion-rerecruit |
| 23 | Commit presence: akk-stack 6358c48 (v2 Lua fix) | PASS | Confirmed on bugfix/companion-rerecruit |
| 24 | Commit presence: eqemu 6f752cd99 (Suite 35 C++ tests) | PASS | Confirmed on bugfix/companion-rerecruit |
| 25 | Commit presence: eqemu 478d154bf (C++ name-match fix) | PASS | Confirmed on bugfix/companion-rerecruit |
| 26 | `make test-companion` — 53 main + 8 edge case = 61 total | PASS | 53/53 + 8/8 = 61 passed, 0 failed |
| 27 | V2 TDD tests: V2-TDD-1 (name-match Track 1 fire) | PASS | Name match with different npc_type_id fires Track 1 |
| 28 | V2 TDD tests: V2-TDD-2 (single-variant regression) | PASS | Existing behavior preserved when IDs match |
| 29 | V2 TDD tests: V2-TDD-3 (Q7 exclusion bypass guard) | PASS | Excluded target NPC blocked even with name-match row |
| 30 | C++ Suite 35 (multi-variant detection): case 35.1 name-match | PASS | Row found by name despite different npc_type_id |
| 31 | C++ Suite 35 (multi-variant detection): case 35.2 name-mismatch | PASS | Wrong name returns empty (WHERE clause filters) |
| 32 | C++ all 35 suites: 569 cases, 0 failures | PASS | `./bin/zone tests:companion` → All Companion Tests Completed! |
| 33 | companion.lua: name-based SQL at line 412 (`name = ?`) | PASS | grep confirms `WHERE owner_id = ? AND name = ? AND name != ''` |
| 34 | companion.lua: `check_existing_companion_record(clean_name, ...)` | PASS | grep confirms param renamed + caller passes `npc:GetCleanName()` |
| 35 | companion.lua: `_lookup_exclusion` helper exists (Track 1 Q7) | PASS | Confirmed at line 177; `is_re_recruitment_eligible` calls it at step 6 |
| 36 | companion.lua: Q7 guard in `is_re_recruitment_eligible` | PASS | Lines 462-469: `_lookup_exclusion(npc:GetNPCTypeID())` blocks excluded targets |
| 37 | companion.cpp: name-based SQL at line 225 | PASS | grep confirms `name = '{}' AND name != ''` with `Strings::Escape` |
| 38 | companion.cpp: ORDER BY tie-breaker at line 227 | PASS | grep confirms `ORDER BY level DESC, experience DESC, id DESC LIMIT 1` |
| 39 | C++ diagnostic log string in zone binary | PASS | strings confirms `Companion::CreateFromNPC: name-match variant mismatch` |
| 40 | Zone binary timestamp: Apr 28 11:06 (post-v2 fix commit) | PASS | Binary built by c-expert during V2-4; ninja reported no-dirty-state on V2-6 |
| 41 | All 8 zone processes running post-restart | PASS | infra-expert V2-6 log: ps confirms 8 zone dynamic processes |
| 42 | DB: 5 companion rows for owner_id=6, no duplicates | PASS | Exactly 5 rows; HAVING COUNT(*) > 1 returns empty |
| 43 | DB: ghost row id=21 still deleted | PASS | SELECT WHERE id=21 returns 0 rows |
| 44 | DB: Lydl (id=10) intact: is_suspended=1, level=53, 14 gear items | PASS | Confirmed; npc_type_id=10162 (stored variant) |
| 45 | DB: stale cooldowns in data_buckets | PASS | 0 rows with key LIKE '%companion%' AND character_id=0 |
| 46 | DB: Lydl variants in npc_types: 4 entries (10162, 10178, 10181, 392011) | PASS | Confirmed; all are Lydl_the_Great |
| 47 | DB: none of the 5 active companions in companion_exclusions | PASS | Queried by npc_type_id for all 5 companions; 0 matches |
| 48 | Log scan: no Lua errors in zone logs post-restart | PASS | No LuaError/stack traceback in zone_dynamic_01-04 logs |
| 49 | Rule validation: `Companions:LevelRange` = 50 (unchanged) | PASS | rule_values confirms; Lua fallback `or 50` matches |
| 50 | Rule validation: `Companions:RecruitCooldownS` = 900 (unchanged) | PASS | rule_values confirms |

### Database Integrity

**v1 queries (from original validation):**

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

**v2 queries (this validation pass):**

```sql
-- Full companion_data state for owner_id=6 (v2 adds npc_type_id column):
SELECT id, name, level, experience, is_dismissed, is_suspended, cur_hp, npc_type_id
FROM companion_data WHERE owner_id = 6 ORDER BY id;
-- Result (live):
-- 10  Lydl the Great  53  8106020  0  1  1504  10162  ← is_suspended=1 (death), npc_type_id=10162 (stored variant)
-- 18  Hollish Tnoops  53  18707712  0  0  696  9144
-- 22  Jimble Woodentoe  53  22940525  0  0  663  22014
-- 23  Jracol Brestiage  53  22716517  0  0  663  2029
-- 24  Lashun Novashine  53  21745789  0  0  2014  2032

-- Stale companion cooldowns (character_id=0 per MEMORY):
SELECT COUNT(*) as stale_cooldowns FROM data_buckets
WHERE `key` LIKE '%companion%' AND character_id = 0;
-- Result: 0

-- Lydl variants in npc_types (all 4 should exist):
SELECT id, name, level FROM npc_types WHERE name LIKE 'Lydl%' ORDER BY id;
-- Result:
-- 10162  Lydl_the_Great  4
-- 10178  Lydl_the_Great  2
-- 10181  Lydl_the_Great  3
-- 392011  Lydl_the_Great  2

-- No duplicate companion rows per name per owner:
SELECT name, COUNT(*) FROM companion_data WHERE owner_id = 6
GROUP BY name HAVING COUNT(*) > 1;
-- Result: empty (no duplicates)

-- companion_exclusions count (sanity check):
SELECT COUNT(*) FROM companion_exclusions;
-- Result: 7269

-- Active companions NOT in companion_exclusions:
SELECT ce.npc_type_id FROM companion_exclusions ce
WHERE ce.npc_type_id IN (10162, 10178, 10181, 392011, 9144, 22014, 2029, 2032);
-- Result: 0 rows (none of the 5 active companions are excluded)
```

**Findings (v2):** Database state is clean and consistent. All 5 companion rows are
valid. No duplicate rows. Ghost row id=21 remains deleted. Zero stale cooldowns.
Lydl (id=10) has `is_suspended=1` and `npc_type_id=10162` — the Track 1 name-match
will now find this row regardless of which of the three freporte variants (10162,
10178, 10181) is currently spawned. None of the 5 active companions appear in
`companion_exclusions`, so the Q7 exclusion guard will not affect normal re-recruit.

### Quest Script Syntax

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Lua | PASS | luajit -bl returns clean; v1+v2 changes applied |
| `akk-stack/server/quests/tests/test_companion_recruitment.lua` | Lua | PASS | 53 tests run and pass (50 v1 + 3 v2) |
| `akk-stack/server/quests/tests/test_companion_rerec_edge_cases.lua` | Lua | PASS | 8 tests run and pass |
| `eqemu/zone/companion.cpp` | C++ | PASS (rebuild) | Built cleanly via ninja; no errors. Suite 35 green. |
| `eqemu/zone/cli/tests/cli_companion_tests.cpp` | C++ | PASS | Suite 35 added; 569 total cases across 35 suites |

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

**v1:** Not required. Zero C++ changes in v1. The fix was Lua-only.

**v2:** C++ rebuild was required. The zone binary was rebuilt by c-expert during V2-4
using `docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`.

- Zone binary timestamp: `Apr 28 11:06` (after v2 C++ fix applied)
- C++ fix commit: `478d154bf` at 11:08 (commit was after ninja; code was already built in-place)
- infra-expert V2-6: `ninja: no work to do` confirmed binary was already current when restart was executed
- New diagnostic string confirmed in binary: `Companion::CreateFromNPC: name-match variant mismatch for '{}'`

The server was fully restarted (Docker + all 8 zone processes) by infra-expert during V2-6.
All zone processes started at 11:11 on Apr 28. The new binary and updated companion.lua
are both live.

**Deployment action required before in-game testing:**
```
No additional reload required — full server restart was done by infra-expert V2-6.
Lua and C++ changes are both live. You can proceed directly to in-game testing.
```

If a quest script-only change is made post-restart, run `#reload quest global` in-game.
A full server restart is not needed for Lua-only changes.

---

## Part 2: In-Game Testing Guide

### Prerequisites

```
Character: Chelon (or any character who has recruited companions before)
Zone: East Freeport (freporte) is the primary test zone — Lydl the Great spawns here
      at approximately (-1174, -964, -51)
Access: GM account with #reload, #zone, #goto, #kill, #showstats
Companions needed:
  - Lydl the Great (companion_data id=10, is_suspended=1, level 53, 14 gear items,
    npc_type_id=10162 stored — v2 canonical bug repro: freporte may spawn 10178 or
    10181 instead of 10162; all three must now re-recruit successfully)
  - Any other previously-recruited companion for regression checks
    (Hollish Tnoops, Jimble Woodentoe, Jracol Brestiage, or Lashun Novashine)
```

**Deployment note (v2): No reload is required.** The full server restart by infra-expert
(V2-6) already loaded both the new Lua and new C++ binary. Proceed directly to testing.

If you have restarted since V2-6 and need to confirm Lua is current, you may run:
```
#reload quest global
```

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

## Part 2b: V2-Specific In-Game Scenarios

These scenarios specifically validate the v2 multi-variant NPC lookup fix. Run after
completing Tests 1-10 above. The canonical bug is: `Lydl_the_Great` has three freporte
variants (npc_type_id 10162, 10178, 10181) that cycle through the spawngroup. Before v2,
if the zone spawned 10178 or 10181 while `companion_data` stored 10162, Track 1 would
miss and the player would see "too far from your level to recruit."

---

### Test V1: Canonical v2 bug repro — re-recruit any Lydl variant (AC-1, AC-2, AC-3/4)

**This is the PRIMARY v2 validation test.** It proves the multi-variant fix works.

**What variant Lydl has:** Lydl's `companion_data` row (id=10) stores `npc_type_id=10162`.
The freporte spawngroup (freporte_140) cycles between 10162, 10178, and 10181 with equal
probability. In approximately 60% of spawns, the variant present in the zone will be
a different `npc_type_id` than stored. This test must PASS regardless of which variant
is currently spawned.

**Steps:**

1. Zone to East Freeport: `#zone freporte`
2. Goto Lydl's spawn point: `#goto freporte -1174 -964 -51`
3. Use `#findnpc Lydl` to locate Lydl the Great.
4. Target Lydl and run `#showstats`. Note the NPC's ID shown in the stats.
   - If ID is 10162: this is the stored variant (easy case)
   - If ID is 10178 or 10181: this is the multi-variant case (the v2 bug scenario)
5. Say: `recruit` (or "join me" / "will you join")
6. Expected: Lydl accepts IMMEDIATELY regardless of which variant is spawned.
   Re-recruit dialogue fires ("I remember you. Let us continue." or similar).
7. Verify Lydl joins the group at level 53 (not the NPC base level 2-4).
8. Verify 14 gear items present via `!stats`.
9. No "too far from your level" message.
10. No cooldown message.

**IMPORTANT — catching the bug scenario:**
- If Lydl is currently 10162, dismiss and repop to force a different variant:
  ```
  !dismiss
  #repop
  ```
  Repop may spawn 10178 or 10181. Retry `recruit` on the new variant.
- Alternatively, just note whichever variant is present and record the NPC ID.

**Pass if:**
- Lydl accepts re-recruitment regardless of which npc_type_id (10162, 10178, or 10181) is spawned
- Level 53, 14 gear items intact
- No rejection messages

**Fail if:**
- "too far from your level to recruit" appears when targeting any Lydl variant other than 10162
- Lydl accepts but joins at base NPC level (2-4) instead of companion level 53
- Duplicate Lydl companion_data row is created (check DB after: `SELECT id, npc_type_id, name FROM companion_data WHERE owner_id=6 AND name='Lydl the Great';` should return exactly 1 row)

**GM commands:**
```
#zone freporte
#goto freporte -1174 -964 -51
#findnpc Lydl
#repop
```

**DB verification after test:**
```sql
SELECT id, npc_type_id, name, level FROM companion_data
WHERE owner_id = 6 AND name = 'Lydl the Great';
-- Expected: 1 row, id=10, level=53 (NOT a new duplicate row)
```

---

### Test V2: Dismiss then re-recruit a different Lydl variant (v2 dismiss regression)

**Purpose:** Proves that the v1 fix (Dismiss(false)) and the v2 fix (name-match) both
work together. Dismiss Lydl, then walk back and recruit a DIFFERENT variant than the
one that was dismissed.

**Prerequisite:** Complete Test V1 first so Lydl is active.

**Steps:**

1. Lydl is active in the group (from Test V1). Note which npc_type_id Lydl was recruited from.
2. `!dismiss` Lydl. Lydl says "Farewell." and despawns.
3. `#repop` to force a new spawn cycle. Check `#findnpc Lydl` — a different variant
   may now be present (or the same one; either is fine).
4. Note the npc_type_id of the new spawn via `#showstats`.
5. Say: `recruit`
6. Expected: Re-recruitment succeeds regardless of whether the variant matches.
   Same level 53, same gear.

**Pass if:**
- Re-recruitment succeeds even when a different variant spawned after dismiss
- Level and gear preserved

**Fail if:**
- Any rejection message (level range or cooldown) appears

---

### Test V3: Cross-zone same-name — northro Lydl variant 392011 (Decision V2-8)

**Architecture doc context:** Decision V2-8 selected "same-name = same character"
semantics. The northro variant of `Lydl_the_Great` (npc_type_id=392011, faction_id=0)
shares the same clean name as the freporte variants (faction_id=186). By design,
Track 1 will find the freporte row for this northro NPC and re-recruit from the
existing `companion_data` entry.

**Note:** This tests the designed cross-zone behavior, not a bug. The architect
explicitly chose this semantics per Decision V2-8.

**Steps:**

1. Ensure Lydl is currently dismissed (companion_data id=10, is_suspended=1).
2. Zone to North Karana (which connects to Rivervale and eventually Northro), or
   use `#zone northro` if available.
3. Use `#findnpc Lydl` — variant 392011 should be findable if it spawns in northro.
4. Target the northro Lydl and say: `recruit`
5. Expected: Re-recruitment SUCCEEDS. Track 1 finds the freporte `companion_data`
   row (same name "Lydl the Great"). Lydl joins at level 53 with 14 gear items.
   A diagnostic log message may appear: "Track 1 name-match: stored npc_type_id=10162
   differs from targeted spawn npc_type_id=392011."
6. Verify no duplicate `companion_data` row is created (DB check below).

**Pass if:**
- Re-recruitment succeeds at northro from the existing companion_data row (id=10)
- Level 53, 14 gear items intact
- No new duplicate row in companion_data

**If variant 392011 doesn't spawn or northro is inaccessible, SKIP this test.** The
behavior is covered by the TDD tests (V2-TDD-1) at the code level.

**Pass criteria if skipped:** TDD V2-TDD-1 confirms the name-match logic works
correctly. Server-side PASS is sufficient.

**DB check after test (if executed):**
```sql
SELECT id, npc_type_id, name, level FROM companion_data
WHERE owner_id = 6 AND name = 'Lydl the Great';
-- Expected: still exactly 1 row (id=10), not a new row with npc_type_id=392011
```

---

### Test V4: Q7 exclusion guard — excluded NPC blocks Track 1 (AC-7 extension)

**Purpose:** Verify that the Q7 guard in `is_re_recruitment_eligible()` prevents
an excluded NPC from bypassing `companion_exclusions` via the name-match. This
guard blocks a theoretical exploit: recruit non-excluded NPC "Renux Herkanor"
(npc_type_id=12032), then attempt to re-recruit the excluded Renux Herkanor
guildmaster (npc_type_id=2033) by name-association.

**Current exposure:** Zero in production. No active companion name matches an
excluded NPC. This test confirms the guard's safety net exists.

**Steps:**

1. Find any NPC that IS in `companion_exclusions`. You can query:
   ```sql
   SELECT ce.npc_type_id, nt.name FROM companion_exclusions ce
   JOIN npc_types nt ON nt.id = ce.npc_type_id
   WHERE ce.exclusion_type = 1 LIMIT 5;
   ```
   These are auto-excluded NPCs. Example: guild masters, city leaders.
2. Look for an NPC whose `name` in `companion_exclusions` is also shared by a
   non-excluded NPC (e.g., a trainer named "Renux Herkanor" where only the
   guildmaster variant is excluded). This is harder to find in the field.
3. Alternative approach: Simply attempt to say `recruit` to any known guildmaster
   or city leader that would normally be excluded (e.g., guild masters in the
   Freeport wizard guild, guard captains).
4. Expected: Rejection with "[NPC name] cannot be recruited." — NOT the level
   range or cooldown message.

**Pass if:**
- Excluded NPC rejects with "cannot be recruited" rather than a level/cooldown message
- The rejection occurs even if a `companion_data` row exists for a same-named non-excluded NPC

**Note:** If you cannot easily identify an excluded same-name sibling pair, the
TDD test V2-TDD-3 covers this case at the code level. In-game confirmation is
a belt-and-suspenders check, not a hard requirement for v2 ship.

---

### Test V5: First-recruit of a new NPC still gates correctly (v2 regression, AC-7)

**Purpose:** Confirm that the name-based Track 1 lookup does NOT fire for NPCs
that have NEVER been recruited by this character. A never-recruited NPC will have
no `companion_data` row; the name-match returns nil; Track 2 fires with full checks.

**Steps:**

1. Find any NPC that is NOT in your companion_data (never recruited).
   Current companion_data names: "Lydl the Great", "Hollish Tnoops",
   "Jimble Woodentoe", "Jracol Brestiage", "Lashun Novashine".
   Any other NPC is a first-time candidate.
2. Set your character to a level that exceeds the LevelRange=50 gap from the NPC:
   ```
   #level 60
   ```
   If the NPC is level 4, your level 60 creates a delta of 56 > 50 → rejection expected.
3. Target the NPC and say: `recruit`
4. Expected: "is too far from your level to recruit" — Track 2 fires, level check rejects.

**Pass if:**
- Track 2 fires (level check rejection) for a never-recruited NPC at an out-of-range level
- No "I remember you" re-recruit dialogue fires (Track 1 must not fire for new NPCs)

**Fail if:**
- The NPC accepts recruitment despite level delta > 50 (would indicate Track 1 fires for non-recruited NPCs)
- Name-match somehow returns a false positive and bypasses first-recruit gates

**GM commands:**
```
#level 60
```

---

### Test V6: No duplicate companion_data row after multi-variant re-recruit (v2 regression)

**Purpose:** Before v2, if Lua Track 1 found the row but C++ still used strict ID
matching, C++ would INSERT a new duplicate row and orphan the original. Confirm this
does NOT happen with v2.

**Steps:**

1. Note the current companion_data state:
   ```sql
   SELECT id, npc_type_id, name, level FROM companion_data WHERE owner_id = 6;
   -- Expected: exactly 5 rows
   ```
2. Ensure Lydl is dismissed (is_suspended=1).
3. In freporte, find a Lydl variant with a DIFFERENT npc_type_id than 10162
   (use `#showstats` to see the NPC ID; if 10162, `#repop` to try another variant).
4. Say `recruit` to the non-10162 variant.
5. Lydl joins the group.
6. Immediately re-query companion_data:
   ```sql
   SELECT id, npc_type_id, name, level FROM companion_data WHERE owner_id = 6;
   -- Expected: still exactly 5 rows — NOT 6
   ```
7. Confirm Lydl's row (id=10) was updated in-place, not a new row:
   ```sql
   SELECT id, npc_type_id, name, is_dismissed, is_suspended
   FROM companion_data WHERE owner_id = 6 AND name = 'Lydl the Great';
   -- Expected: 1 row, id=10, is_dismissed=0, is_suspended=0
   ```

**Pass if:**
- companion_data stays at 5 rows after multi-variant re-recruit
- Lydl row (id=10) is reused (not a new row with new id)

**Fail if:**
- A 6th row appears in companion_data (would mean C++ still fell through to fresh INSERT)
- The new row has a different npc_type_id (10178 or 10181) — orphan creation

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

**v2 deployment is already complete.** infra-expert ran V2-6 (full stack restart):
- Docker containers restarted via `make restart`
- `shared_memory` ran to completion
- `loginserver`, `world`, and 8 zone dynamic processes started
- New zone binary (Apr 28 11:06, with C++ name-match fix) is live
- Updated `companion.lua` (v2 commit 6358c48) is loaded in all zones

**No action required before testing.** Simply log in and run the scenarios.

If for any reason quest scripts need reloading (e.g., you made a further change):
```
In-game (as GM):
#reload quest global
```

This reloads Lua state across all zones. The C++ binary requires a full server
restart if changed — but no further C++ changes are planned.

---

## Rollback Instructions

If something goes wrong during testing:

### Rollback the v2 Lua fix (name-match + Q7 guard)

```bash
# In the akk-stack directory on host:
cd /mnt/d/Dev/eq/akk-stack
git revert 6358c48   # the v2 Lua fix commit
# This restores companion.lua to v1 state (Dismiss(false) still in place;
# only the name-match and Q7 guard are reverted)
# Then reload in-game: #reload quest global
```

### Rollback the v2 C++ fix (name-based CreateFromNPC query)

```bash
# In the eqemu directory on host:
cd /mnt/d/Dev/eq/eqemu
git revert 478d154bf   # the C++ name-match fix commit
# Then rebuild:
docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
# Then restart all zone processes (infra-expert per MEMORY.md)
```

### Rollback the v1 Lua fix (Dismiss(false))

```bash
# In the akk-stack directory on host:
cd /mnt/d/Dev/eq/akk-stack
git revert ad79630   # the v1 fix commit
# This restores companion.lua:1434 to Dismiss(true)
# Then reload in-game: #reload quest global
```

All three rollbacks are independent. Reverting v2 does not require reverting v1.

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
   With v2, the name-match prevents duplicate row creation in the common case. Adding
   the UNIQUE constraint would be belt-and-suspenders but requires C++ UPSERT changes.
   Track as future work.

4. **Future work: stale-name edge case** (v2 new risk): If an admin renames an NPC in
   `npc_types` after a player has recruited it, `companion_data.name` becomes stale and
   Track 1 will miss. The C++ diagnostic log (`Companion::CreateFromNPC: name-match
   variant mismatch`) will surface this case at recruit time. Documented, pre-existing,
   no current production exposure.

5. **Future work: `npc_faction_id` disambiguation** for cross-zone same-name NPCs:
   Decision V2-8 selected "same name = same character" (player-friendly). If the user
   later encounters an unwanted cross-zone merge (freporte Lydl row merging with a
   northro Lydl of different faction), adding `npc_faction_id` to the Track 1 predicate
   would disambiguate. Architecture doc flagged this as a future option.

6. **Lydl's current state**: Lydl (companion_data id=10, `is_suspended=1`, level=53,
   14 gear items, stored npc_type_id=10162) is ready to re-recruit immediately.
   The v2 fix means ANY of the three freporte variants (10162, 10178, 10181) will
   successfully re-recruit using the stored row.
