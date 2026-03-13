# Companion Commands — Test Plan

> **Feature branch:** `feature/companion-commands`
> **Author:** game-tester
> **Date:** 2026-03-13
> **Server-side result:** PASS

---

## Test Summary

This test plan covers the companion-commands feature which added three
quality-of-life improvements to the companion command system: (1) `!help`
without a companion target via a new `global_player.lua:event_say` handler,
(2) the new `!hold` command combining guard + passive into one action, and
(3) `!tome` updated to wipe the hate list and break guard mode on recall.

All changes are pure Lua. No C++ build is required. Changes activate on
`#rq` (reload quests).

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] status.md — all 6 implementation tasks marked Complete
- [x] Acceptance criteria identified: REQ-1 through REQ-5 (see PRD)
- [x] Implementation: `companion.lua`, `global_player.lua`
- [x] Documentation: `claude/docs/companion-commands-reference.md`
- [x] Test files: 5 test files across `akk-stack/server/quests/tests/`

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Lua syntax: companion.lua | PASS | luajit -bl clean; no syntax errors |
| 2 | Lua syntax: global_player.lua | PASS | luajit -bl clean; no syntax errors |
| 3 | Test suite: test_companion_cmd_hold.lua | PASS | 14/14 passed |
| 4 | Test suite: test_companion_cmd_tome.lua | PASS | 13/13 passed |
| 5 | Test suite: test_companion_cmd_help.lua | PASS | 23/23 passed |
| 6 | Test suite: test_companion_commands_regression.lua | PASS | 37/37 passed |
| 7 | Test suite: test_companion_cmd_assist.lua (pre-existing) | PASS | 14/14 passed |
| 8 | Total test count | PASS | 101 tests total; 87 new (claim verified) |
| 9 | Log analysis: world.log | PASS | No errors; normal zone startup entries only |
| 10 | Log analysis: zone logs | PASS | Companion spawn/depop entries normal; one unrelated MySQL timeout at 22:51 (connection killed, recovered) |
| 11 | DB integrity | N/A | No database changes in this feature |
| 12 | Build verification | N/A | No C++ changes in this feature |
| 13 | Rule validation | N/A | No rule changes in this feature |
| 14 | COMMANDS table: !hold entry present | PASS | Verified at companion.lua:110 — `hold = { handler = "cmd_hold", category = "movement" }` |
| 15 | cmd_hold: dead check, already-holding, guard+passive | PASS | Verified by reading implementation (lines 535-553) |
| 16 | cmd_tome: WipeHateList + SetGuardMode(false) + follow mode | PASS | Verified at companion.lua:1017-1020 |
| 17 | cmd_assist: guard-break added | PASS | Verified at companion.lua:1107-1109 |
| 18 | cmd_help_standalone: exported from companion.lua | PASS | Function defined at line 865 |
| 19 | global_player.lua event_say: intercepts !help | PASS | event_say defined at line 258; intercepts !help, returns 1 to consume |
| 20 | Help output: alphabetical within categories | PASS | Verified by test_companion_cmd_help.lua tests 4-7 |
| 21 | Documentation: 24 commands listed with !-prefix | PASS | companion-commands-reference.md lists all 24 commands correctly |
| 22 | Documentation: old free-text commands removed | PASS | No references to "leave", "goodbye", "stay", "stance" alias, "handle_command" |
| 23 | Nil-guard pattern: all new code follows existing pattern | PASS | cmd_hold lines 548-549; cmd_tome line 1019; cmd_assist line 1108 |

### Test Count Breakdown

| Test File | New/Pre-existing | Tests | Status |
|-----------|-----------------|-------|--------|
| test_companion_cmd_assist.lua | Pre-existing | 14 | PASS |
| test_companion_cmd_hold.lua | New | 14 | PASS |
| test_companion_cmd_tome.lua | New | 13 | PASS |
| test_companion_cmd_help.lua | New | 23 | PASS |
| test_companion_commands_regression.lua | New | 37 | PASS |
| **Total** | | **101** | **ALL PASS** |

### Notes on Server-Side Findings

**Note 1 — Test count discrepancy (non-blocking):** The briefing states "87
new tests." The actual new test count is 87 (14+13+23+37). The total suite is
101 (includes 14 pre-existing assist tests). This matches the claim.

**Note 2 — MySQL timeout in zone log (non-blocking):** At 22:51:35 in the
commons zone log, a `Connection was killed` MySQL error appears followed by
`attempting to recover`. This is a DB idle timeout unrelated to this feature.
No Lua or quest errors are present.

**Note 3 — !help double-fire behavior (acceptable):** The architecture
documents that when a player targets a companion and types `!help`, both
`global_player.lua:event_say` AND `global_npc.lua:event_say` fire. The
deduplication lock (`help_lock_<zone_id>`) ensures only one response appears.
This behavior is correct per the architecture design.

---

## Part 2: In-Game Testing Guide

Execute these tests in the Titanium client. Use a GM character (`#gmstatus`
check) to run setup commands. All tests require at least one recruited
companion.

**Setup: Recruit a test companion**
```
#spawn [any_npc_id]   -- spawn an NPC to recruit
/say recruit
```
Or use an existing companion if one is already recruited.

**Reload quests after server changes:**
```
#reloadquests
```
or press the Reload Quests button in Spire (http://192.168.1.86:3000).

---

### Test REQ-1a: !help without a target

**PRD criterion:** Player types `/say !help` with NO target: receives full
command list in say chat.

**Prerequisite:** Character with no target selected. No companion target
required.

**Steps:**
1. Log in on any character.
2. Ensure no NPC or companion is targeted (press Escape to clear target).
3. Type `/say !help` in chat.
4. Observe the chat window.

**Expected output (each line in your chat):**
```
=== Companion Commands ===
Buffs:
  !buffme            -- Refresh your buffs (casters, >10% mana)
  !buffs             -- Refresh party buffs (casters, >10% mana)
Combat:
  !assist            -- Attack your target (auto-switches passive to balanced)
  !target            -- Face/engage your current target
Control:
  !dismiss           -- Dismiss companion (re-recruit later with bonus)
Equipment:
  !equip             -- How to give items (use trade window)
  !equipment         -- Show all equipped items (alias: !gear)
  !equipmentmissing  -- List empty equipment slots
  !equipmentupgrade  -- Evaluate a linked item vs. equipped
  !unequip <slot>    -- Return item from slot (or 'all')
Information:
  !help              -- This command list (!help <topic> for details)
  !stats             -- Detailed combat stats
  !status            -- Overview: HP, mana, stance, buffs
Movement:
  !flee              -- Disengage, move to you, follow mode
  !follow            -- Follow you
  !guard             -- Hold current position (still fights)
  !hold              -- Hold position and stop fighting
  !recall            -- Teleport to you (>200 units, 30s cooldown)
  !tome              -- Move to you instantly
Stance:
  !aggressive        -- Actively seek and attack enemies
  !balanced          -- Default: fight when attacked
  !passive           -- Stop fighting, disengage
Type '!help <topic>' for details.
```

**Pass if:** The full command list appears in your chat window without
targeting anything.

**Fail if:** Nothing appears, an error appears, or only partial output
appears.

---

### Test REQ-1b: !help targeting a non-companion NPC

**PRD criterion:** `/say !help` targeting a non-companion NPC: command list
appears (not an error).

**Steps:**
1. Target any non-companion NPC (a regular guard or merchant).
2. Type `/say !help` in chat.
3. Observe the chat window.

**Expected:** Same full command list as REQ-1a appears in your chat.

**Pass if:** Command list appears despite targeting a non-companion NPC.

**Fail if:** An error appears, or the LLM responds to "!help" instead of
the command list appearing.

**GM commands:**
```
#spawn 1   -- spawn a generic NPC if needed
```

---

### Test REQ-1c: !help targeting a companion

**PRD criterion:** `/say !help` targeting a companion: identical output.

**Steps:**
1. Target your companion.
2. Type `/say !help` in chat.
3. Observe the chat window.

**Expected:** Same full command list appears. Only one response fires
(no double output). Output comes from the companion (group chat) or
directly to your chat.

**Pass if:** Single response, identical content to REQ-1a.

**Fail if:** Two responses appear (deduplication failure), or different
content appears.

---

### Test REQ-1d: !help <topic> variants

**PRD criterion:** `!help <topic>` works for all 7 topics.

**Steps (run each separately):**
1. Target companion, type `/say !help stance`
2. Target companion, type `/say !help movement`
3. Target companion, type `/say !help combat`
4. Target companion, type `/say !help buffs`
5. Target companion, type `/say !help equipment`
6. Target companion, type `/say !help information`
7. Target companion, type `/say !help control`

**Expected for each:**
- stance: `=== Stance Commands ===` with !aggressive, !balanced, !passive
- movement: `=== Movement Commands ===` with !flee, !follow, !guard, !hold, !recall, !tome
- combat: `=== Combat Commands ===` with !assist, !target
- buffs: `=== Buff Commands ===` mentioning "Casters"
- equipment: `=== Equipment Commands ===` with all !equipment, !equip, !unequip, !equipmentupgrade, !equipmentmissing
- information: `=== Information Commands ===` with !help, !stats, !status
- control: `=== Control Commands ===` with !dismiss

**Pass if:** Each topic returns a correctly labeled section with appropriate commands.

**Fail if:** Any topic returns "Unknown help topic" or no output.

---

### Test REQ-1e: @all !help deduplication

**PRD criterion:** `@all !help` via gsay: only one response appears.

**Prerequisite:** At least two companions recruited and in your group.

**Steps:**
1. Ensure two companions are in your group.
2. Open group chat (`/gsay`).
3. Type `@all !help` and press Enter.
4. Count how many times the command list appears in chat.

**Pass if:** The command list appears exactly once.

**Fail if:** The command list appears twice (one per companion).

---

### Test REQ-2a: !hold basic behavior

**PRD criterion:** Target companion, type `!hold`: companion stops following,
holds position, enters passive stance, wipes hate list.

**Steps:**
1. Target your companion.
2. Walk around — confirm the companion follows you.
3. Stop moving. Type `/say !hold`.
4. Observe the companion's response and behavior.
5. Walk away from the companion.
6. Observe whether the companion follows.

**Expected:**
- Companion says "Holding position." (or similar)
- Companion stops following when you walk away
- Companion remains at its current position

**Pass if:** Companion stays stationary when you move away.

**Fail if:** Companion continues following you, or no response appears.

---

### Test REQ-2b: Held companion does not engage enemies

**PRD criterion:** Held companion does not engage enemies, even if attacked.

**Steps:**
1. Target your companion. Type `/say !hold`.
2. Pull a mob near the held companion (but not near you).
3. Let the mob attack the companion.
4. Observe whether the companion fights back.

**Expected:** The held companion does not attack the mob, even while being
hit. It remains passive.

**Note:** The mob will continue attacking the companion (hate list is retained
on the mob's side). The companion itself stops initiating attacks.

**Pass if:** Companion takes hits without retaliating.

**Fail if:** Companion starts attacking the mob.

**GM commands:**
```
#spawn [mob_npc_id]   -- spawn a mob near the companion's position
```

---

### Test REQ-2c: !follow breaks hold (resumes movement, stance stays passive)

**PRD criterion:** `!follow` on a held companion: resumes following, stance
stays passive.

**Steps:**
1. Target companion. Type `/say !hold`.
2. Confirm companion is holding position.
3. Type `/say !follow`.
4. Walk away from where the companion was holding.
5. Confirm the companion follows you.
6. Type `/say !status` and observe the stance line.

**Expected:**
- Companion resumes following after `!follow`
- Status shows Stance: Passive (not Balanced)

**Pass if:** Companion follows and stance is still passive.

**Fail if:** Companion does not follow, or stance changed to balanced.

---

### Test REQ-2d: !assist breaks hold (switches to balanced, engages target, resumes following)

**PRD criterion:** `!assist` on a held companion: switches to balanced,
engages target, resumes following.

**Steps:**
1. Target companion. Type `/say !hold`.
2. Confirm companion is holding position.
3. Target a hostile mob (must be attackable).
4. Type `/say !assist`.
5. Observe companion behavior.

**Expected:**
- Companion switches to balanced stance
- Companion engages the targeted mob
- Companion moves toward the mob (guard mode broken)
- Companion follows you after combat

**Pass if:** Companion engages the mob and moves from its held position.

**Fail if:** Companion refuses to engage, stays stationary, or errors out.

**GM commands:**
```
#spawn [mob_id]   -- spawn a hostile mob to target
```

---

### Test REQ-2e: !balanced on held companion (changes stance, stays at position)

**PRD criterion:** `!balanced` on a held companion: changes stance to
balanced, stays at guard position, will fight nearby enemies.

**Steps:**
1. Target companion. Type `/say !hold`.
2. Type `/say !balanced`.
3. Type `/say !status` — confirm stance is now Balanced.
4. Confirm the companion has NOT moved from its held position.

**Expected:**
- Companion status shows Stance: Balanced
- Companion is still at its guard position (has not resumed following)

**Pass if:** Stance changes but position does not change.

**Fail if:** Companion resumes following after `!balanced`, or stance does
not change.

---

### Test REQ-2f: !hold on already-held companion

**PRD criterion:** `!hold` on an already-held companion: responds "Already
holding position." with no state change.

**Steps:**
1. Target companion. Type `/say !hold` (first hold).
2. Type `/say !hold` (second hold).
3. Observe the companion's response.

**Expected:** Companion says "is already holding position." or similar.
No additional state changes occur.

**Pass if:** Second `!hold` produces the "already holding" message.

**Fail if:** No response, or the companion processes the second hold as
a new command.

---

### Test REQ-2g: !hold on dead companion

**PRD criterion:** `!hold` on a dead companion: responds "[Name] is dead
and cannot hold position."

**Steps:**
1. Kill your companion (or use `#kill` while targeting it).
2. Target the companion's corpse (if targetable) or the companion while
   at 0 HP.
3. Type `/say !hold`.
4. Observe the response.

**Expected:** Response mentions "[Name] is dead" and "hold position."

**Pass if:** Appropriate dead companion error appears.

**Fail if:** The command applies guard mode/passive to a dead companion.

**GM commands:**
```
#kill   -- kill targeted NPC (the companion)
```

---

### Test REQ-2h: !hold appears in !help output under Movement

**PRD criterion:** !hold appears in `!help` output under Movement category.
`!help movement` shows !hold.

**Steps:**
1. Type `/say !help` (no target).
2. Look for "Movement:" section. Confirm "!hold" appears there.
3. Target companion. Type `/say !help movement`.
4. Confirm "!hold" appears in the movement topic output.

**Pass if:** !hold is listed under Movement in both general and topic help.

**Fail if:** !hold is missing, listed under a wrong category, or listed
twice.

---

### Test REQ-3a: !tome clears target and stops combat

**PRD criterion:** `!tome` on a companion in combat: companion moves to
player, target is cleared, companion stops attacking.

**Steps:**
1. Let your companion engage a mob (it should be attacking the mob).
2. Walk away so the companion is more than 50 units from you.
3. Target the companion. Type `/say !tome`.
4. Observe: companion moves to you, stops attacking the mob.
5. Use `#showstats` to confirm companion target is cleared.

**Expected:**
- Companion instantly moves to player position (GMMove)
- Companion stops attacking the mob
- Mob may continue chasing the companion (hate list is NOT cleared on
  the mob's side)

**Pass if:** Companion moves to you and stops attacking.

**Fail if:** Companion continues attacking the mob after moving.

**GM commands:**
```
#spawn [mob_id]   -- spawn a mob for the companion to engage
#goto [x] [y] [z]  -- teleport yourself away from the companion
```

---

### Test REQ-3b: !tome preserves stance

**PRD criterion:** `!tome` on a companion in combat: companion's stance is
NOT changed.

**Steps:**
1. Set companion to aggressive: target companion, type `/say !aggressive`.
2. Type `/say !status` — confirm Stance: Aggressive.
3. Let companion engage a mob.
4. Walk away >50 units. Type `/say !tome`.
5. Type `/say !status` again.

**Expected:** Status still shows Stance: Aggressive after `!tome`.

**Pass if:** Stance is unchanged by `!tome`.

**Fail if:** Stance changed to passive or balanced.

---

### Test REQ-3c: !tome breaks guard mode

**PRD criterion:** `!tome` on a companion that was in guard mode: companion
moves to player and switches to follow mode.

**Steps:**
1. Target companion. Type `/say !guard` to put companion in guard mode.
2. Walk away from the companion (>50 units).
3. Type `/say !tome`.
4. After the companion moves to you, walk away again.
5. Observe whether the companion follows you.

**Expected:** After `!tome`, the companion follows you (guard mode broken).

**Pass if:** Companion follows you after being tomed from guard mode.

**Fail if:** Companion stays at the old guard position after being tomed,
or returns to the tome landing position as a guard point.

---

### Test REQ-3d: !tome when companion is nearby (<50 units)

**PRD criterion:** `!tome` on a companion already nearby (<50 units):
"already nearby" message, no changes.

**Steps:**
1. Stand next to your companion (within a few units).
2. Target the companion. Type `/say !tome`.
3. Observe response.

**Expected:** Companion says "[Name] is already nearby." and does not move.

**Pass if:** "already nearby" message appears, no movement occurs.

**Fail if:** Companion is moved unnecessarily, or no message appears.

---

### Test REQ-3e: !tome on dead companion

**PRD criterion:** `!tome` on a dead companion: "[Name] is dead and cannot
move." message.

**Steps:**
1. Kill your companion using `#kill` while targeting it.
2. Walk away from the corpse.
3. Target the companion/corpse. Type `/say !tome`.
4. Observe response.

**Expected:** "[Name] is dead and cannot move." message. No movement.

**Pass if:** Dead companion error appears.

**Fail if:** A dead companion is moved.

---

### Test REQ-3f: Hate list retained on mob side after !tome

**PRD criterion:** Mobs that were fighting the companion before `!tome`
continue to pursue (hate list NOT cleared).

**Steps:**
1. Let a mob engage your companion (companion is on mob's hate list).
2. Use `!tome` to move the companion to you.
3. Observe whether the mob continues chasing the companion.

**Expected:** The mob pursues the companion to its new position because
the mob's hate list still has the companion on it.

**Pass if:** Mob continues chasing after `!tome`.

**Fail if:** Mob immediately loses interest in the companion after `!tome`
(would indicate hate was cleared on both sides).

---

### Test REQ-3g: @all !tome moves all companions

**PRD criterion:** `@all !tome` via gsay: all companions move to player,
all clear targets and stop attacking.

**Prerequisite:** At least two companions in your group, both more than
50 units away and ideally in combat.

**Steps:**
1. Move away from your companions (>50 units each).
2. Open group chat. Type `@all !tome`.
3. Observe all companions move to your position.

**Pass if:** All companions move to player. If in combat, all stop attacking.

**Fail if:** Only one companion moves, or companions move to wrong locations.

---

### Test REQ-4: Documentation audit (spot check)

**Steps:**
1. Open the companion commands reference at:
   `/mnt/d/Dev/eq/claude/docs/companion-commands-reference.md`
2. Verify:
   - 24 commands listed (all with `!` prefix)
   - `!hold` appears under Movement Commands
   - `!tome` behavior matches: "Wipes hate list (stops active combat). Breaks
     guard mode, resets to follow. Stance unchanged."
   - No mention of `leave`, `goodbye`, `stay`, `stance` (old free-text
     commands)
   - Handler listed as `dispatch_prefix_command` (not `handle_command`)
   - `global_player.lua:event_say()` mentioned for `!help` standalone

**Pass if:** All items confirmed accurate.

**Fail if:** Old commands appear, or wrong handler names are documented.

---

### Test REQ-5: Edge case — !hold then !tome sequence

**PRD criterion (architecture antagonistic review #1):** Hold then tome:
stance stays passive (from !hold), mode changes to follow.

**Steps:**
1. Target companion. Type `/say !hold`.
2. Walk away >50 units. Type `/say !tome`.
3. Type `/say !status`.

**Expected:**
- Companion moved to player (from !tome)
- Companion is in follow mode (guard broken by !tome)
- Stance is still Passive (set by !hold; !tome does not change stance)

**Pass if:** Status shows Passive stance, Follow mode after this sequence.

**Fail if:** Stance changed to balanced, or companion is still in guard mode.

---

### Test REQ-5: Edge case — @all commands with multiple companions

**Prerequisite:** Two companions in group.

**Steps:**
1. In group chat: `@all !hold` — both companions hold.
2. In group chat: `@all !follow` — both companions resume following.
3. Confirm each companion responds appropriately.
4. In group chat: `@all !passive` — both go passive.

**Pass if:** All companions respond to @all commands and change state.

**Fail if:** Only one companion responds, or wrong companion responds.

---

## Rollback Instructions

If a critical issue is found that requires reverting these changes:

1. All changes are in two Lua files only (no C++, no DB):
   - `akk-stack/server/quests/lua_modules/companion.lua`
   - `akk-stack/server/quests/global/global_player.lua`

2. To revert: `git checkout` the pre-feature versions of both files from
   the `master` branch.

3. Reload quests in-game: `#reloadquests`

4. No server restart required.

---

## GM Commands Reference for This Test Plan

| Command | Effect |
|---------|--------|
| `#goto [x] [y] [z]` | Teleport to location |
| `#zone [zoneshort]` | Zone to a specific zone |
| `#spawn [npc_id]` | Spawn an NPC at your location |
| `#kill` | Kill targeted NPC/companion |
| `#showstats` | Show targeted NPC stats |
| `#reloadquests` | Hot-reload all Lua quest scripts |
| `/say !hold` | Issue !hold to targeted companion |
| `/say !tome` | Issue !tome to targeted companion |
| `/say !follow` | Issue !follow to targeted companion |
| `/say !assist` | Issue !assist to targeted companion |
| `/say !status` | Show companion status (stance, mode) |
| `/say !help` | Show command list (works without target) |
| `@all !hold` (in /gsay) | Hold all companions in group |
| `@all !tome` (in /gsay) | Tome all companions in group |
| `@all !follow` (in /gsay) | Follow all companions in group |

---

## Server-Side Results Summary

**Overall verdict: PASS**

All 101 tests across 5 test files pass cleanly. Lua syntax is valid for both
modified files. Server logs show no quest or Lua errors. No database, C++,
configuration, or rule changes were made. Implementation matches architecture
and PRD requirements.

The following items require in-game verification before the feature can be
marked fully complete:
- REQ-2b: Held companion does not fight back when attacked
- REQ-3a: !tome stops active combat (companion stops swinging)
- REQ-3c: !tome breaks guard mode (companion follows after being tomed)
- REQ-3f: Mob hate list retained on mob side after !tome
- All @all group dispatch tests (require two companions)

---

## Handoff

**game-tester server-side validation:** PASS

Pending user in-game verification of the tests listed above. No blockers
identified. Feature is ready for in-game testing.

**Next step:** User runs in-game testing guide above. If all pass, mark
Validation phase Complete and proceed to the Completion phase.
