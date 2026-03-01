# Recruited NPC Controls — Test Plan

> **Feature branch:** `feature/recruited-npc-controls`
> **Author:** game-tester
> **Date:** 2026-02-28
> **Server-side result:** PASS WITH WARNINGS

---

## Test Summary

This plan validates the companion command prefix system. The feature replaces
keyword-based companion management with a `!` prefix dispatcher. All `/say`
messages to a companion starting with `!` are parsed as commands; all other
text flows to the LLM for natural conversation. Five new commands are added
(`!recall`, `!target`, `!assist`, `!status`, `!help`) and old natural-language
keywords (follow, guard, stay, farewell, etc.) are no longer intercepted.

The implementation touches three files:
- `eqemu/common/ruletypes.h` — 1 new rule (`Companions:RecallCooldownS`)
- `akk-stack/server/quests/lua_modules/companion.lua` — full refactor
- `akk-stack/server/quests/global/global_npc.lua` — 6-line routing change

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] status.md — Tasks 2 and 3 marked Complete; Task 1 (config-expert rule) shows Not Started but rule IS present in ruletypes.h and DB (see server-side results)
- [x] Acceptance criteria identified: 20 criteria from PRD

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Lua syntax: companion.lua | PASS | LuaJIT bytecode compiles cleanly; 727 lines |
| 2 | Lua syntax: global_npc.lua | PASS | LuaJIT bytecode compiles cleanly; 91 lines |
| 3 | COMMANDS table: entry count | PASS | 16 entries (14 primary commands + 2 aliases: !gear, !unequipall) |
| 4 | COMMANDS table: all handlers exist | PASS | Every handler name in the table has a matching `companion.cmd_*` function |
| 5 | Recruitment keywords intact | PASS | RECRUIT_KEYWORDS table (10 entries) and is_recruitment_keyword() unchanged |
| 6 | Old keyword system removed | PASS | No is_management_keyword(), handle_command(), or MANAGE_KEYWORDS found in either file |
| 7 | global_npc.lua: prefix routing | PASS | IsCompanion() + sub(1,1)=="!" check routes to dispatch; recruitment check guards with not IsCompanion() |
| 8 | Lore phrases: balanced stance split | PASS | cmd_balanced() checks GetCompanionType()==0 for loyal vs mercenary |
| 9 | Lore phrases: target/assist | PASS | cmd_target says "I see your target."; cmd_assist says "I will assist." (both complete sentences) |
| 10 | Lore phrases: all "I will [verb]." pattern | PASS | passive="I will stand down.", follow="I will follow.", guard="I will hold here.", recall="I am here.", dismiss="Farewell." |
| 11 | !recall reads RecallCooldownS with fallback | PASS | Line 485: `tonumber(eq.get_rule("Companions:RecallCooldownS")) or 30` |
| 12 | !target checks stance before AddToHateList | PASS | Line 664: `if npc:GetStance() ~= 0 then` guards AddToHateList in cmd_target |
| 13 | !assist checks stance before AddToHateList | PASS | Line 679: same guard in cmd_assist |
| 14 | Unprefixed messages fall through (no interception) | PASS | global_npc.lua: non-"!" companion messages fall through to LLM block with no return |
| 15 | RecallCooldownS rule in ruletypes.h | PASS | Line 1202, at end of Companions category, before RULE_CATEGORY_END() |
| 16 | RecallCooldownS in DB (rule_values) | PASS | Value: 30, Notes: "Cooldown in seconds before a companion can be recalled again via !recall" |
| 17 | World server loaded new rule | PASS | world_159.log 16:25:12: "Adding new rule [Companions:RecallCooldownS] ruleset [default] (1) value [30]" |
| 18 | zone binary rebuilt after ruletypes.h change | PASS | zone binary timestamp 16:24, ruletypes.h modified 16:06 — binary is newer |
| 19 | Zone bootup errors (recent) | WARN | zone_187.log shows "Zone Bootup failed" on 2026-02-23 and 2026-02-27. Predates this feature. Unrelated. |
| 20 | !help categories match commands | PASS | 6 help topics (stance, movement, equipment, information, combat, control) all have `elseif topic ==` handlers |
| 21 | status.md Task 1 marked "Not Started" | WARN | Task 1 (RecallCooldownS rule) shows "Not Started" in status.md but IS implemented. status.md needs update. |
| 22 | COMMANDS table vs architecture spec | NOTE | Architecture spec shows 14 commands; implementation has 16 (added !gear alias for !equipment, !unequipall alias for !unequip all). Both aliases are undocumented in !help output. |

---

### Database Integrity

No schema changes were made by this feature. The only DB change is the
auto-seeded rule value.

**Queries run:**

```sql
-- Verify RecallCooldownS rule was seeded
SELECT rule_name, rule_value, notes
FROM rule_values
WHERE rule_name LIKE '%RecallCooldown%';
```

**Result:** 1 row returned — `Companions:RecallCooldownS` = 30.

**Findings:** No orphaned records. No FK issues. The rule_values table is
consistent. No companion_data or other companion tables were modified.

---

### Quest Script Syntax

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Lua | PASS | LuaJIT `-bl` produces valid bytecode; 727 lines |
| `akk-stack/server/quests/global/global_npc.lua` | Lua | PASS | LuaJIT `-bl` produces valid bytecode; 91 lines |

Note: `luajit` is not in container PATH. The correct binary is at:
`/home/eqemu/code/build/vcpkg_installed/x64-linux/tools/luajit/luajit`

---

### Log Analysis

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| `logs/world_159.log` | None | — | Feature-related: confirmed new rule seeded |
| `logs/zone/zone_201.log` | None on 2026-02-28 | — | Clean quest loads |
| `logs/zone/zone_207.log` | None | — | Successful quest reloads |
| `logs/zone/zone_187.log` | "Zone Bootup failed" (x2) | Low | Predates feature (2026-02-23, 2026-02-27); not related |

No Lua errors, no companion script errors, no quest load failures found that
relate to this feature.

---

### Rule Validation

| Rule | Category | Value | Valid Range | Result |
|------|----------|-------|-------------|--------|
| `Companions:RecallCooldownS` | INT | 30 | 0–3600 (reasonable) | PASS |

The `or 30` fallback in companion.lua ensures the command works even if
the rule lookup fails.

---

### Spawn Verification

Not applicable. This feature adds no new spawn points, NPCs, or grids.

---

### Loot Chain Validation

Not applicable. This feature adds no loot tables, lootdrops, or item
references.

---

### Build Verification

C++ was modified (ruletypes.h, 1 line added).

- **zone binary timestamp:** 2026-02-28 16:24
- **ruletypes.h modification time:** 2026-02-28 16:06
- **Result:** PASS — binary is newer than source change
- **World log confirmation:** "Adding new rule [Companions:RecallCooldownS]" at 16:25:12 confirms the rebuilt binary loaded successfully

---

### Implementation Notes for In-Game Testers

Two undocumented aliases exist in the COMMANDS table that are not mentioned
in `!help` output:
- `!gear` (alias for `!equipment`) — works but not documented
- `!unequipall` (alias for `!unequip all`) — works but not documented

These are not blockers but are noted as a recommendation below.

---

## Part 2: In-Game Testing Guide

### Prerequisites

- A character with GM access (any level works; use `#level 35` for consistent testing)
- Be in a zone where you can recruit an NPC (North Karana or any outdoor classic zone works well)
- The companion system must be enabled (rule `Companions:CompanionsEnabled = true`)
- You need at least one active companion for command tests, and access to a non-companion NPC for regression tests

**Initial setup commands (run once before starting tests):**
```
#level 35
#zone nkarana
#reloadquests
#reloadrules
```

**To spawn a test companion quickly:**
```
#spawn [npcid]        -- spawn any eligible NPC at your location
```
Then say "join me" to recruit them. The NPC should respond "I will join you."
and become your companion.

---

### Test 1: !help — Full Command List

**Acceptance criterion:** "`!help` displays a complete, categorized list of all available commands"

**Prerequisite:** Active companion targeted.

**Steps:**
1. Target your companion.
2. `/say !help`
3. Read the system messages.

**Expected result:** Chat shows "=== Companion Commands ===" followed by six
categories: Stance, Movement, Equipment, Information, Combat, Control. Each
category lists the relevant commands with brief descriptions. Final lines read:
"To talk naturally, just /say without ! prefix." and
"Type '!help <topic>' for details."

**Pass if:** All six categories appear with at least one command each. The word
"Combat" and "Control" categories both appear.

**Fail if:** Any category is missing, or the output is empty/garbled.

**GM commands for setup:**
```
#reloadquests    -- if you just made script changes
```

---

### Test 2: !help with topic — Filtered Help

**Acceptance criterion:** "`!help <topic>` displays detailed help for that command category"

**Prerequisite:** Active companion targeted.

**Steps:**
1. Target your companion.
2. `/say !help stance`
3. Verify output shows stance-specific detail.
4. `/say !help movement`
5. Verify output shows movement commands with recall distance noted.
6. `/say !help equipment`
7. Verify output includes the valid slot list.
8. `/say !help combat`
9. `/say !help control`
10. `/say !help information`

**Expected result for !help stance:** "=== Stance Commands ===" with details
for !passive, !balanced, !aggressive.

**Expected result for !help movement:** Shows "!recall - Teleport companion ...
(>200 units). Has a 30-second cooldown."

**Expected result for !help equipment:** Shows valid slot list including
"primary, secondary, head, chest, arms, wrist1, wrist2..." etc.

**Pass if:** Each topic shows the correct category header and relevant commands.

**Fail if:** Any topic returns "Unknown help topic" or blank output.

---

### Test 3: ! alone — Empty Prefix Shows Help

**Acceptance criterion:** "Typing `!` alone shows the help list"

**Prerequisite:** Active companion targeted.

**Steps:**
1. Target your companion.
2. `/say !`
3. Check for help output.

**Expected result:** Same full command list as `!help` (the dispatch function
treats empty body as a help request).

**Pass if:** Full categorized help list appears.

**Fail if:** "Unknown command" error, or no response.

---

### Test 4: Unknown Command Error

**Acceptance criterion:** "Typing an unrecognized `!command` shows an error with a suggestion to use `!help`"

**Prerequisite:** Active companion targeted.

**Steps:**
1. Target your companion.
2. `/say !invalidcmd`
3. Check for error message.
4. `/say !xyzzy`
5. Check for error message.

**Expected result:** "Unknown command: !invalidcmd. Type !help for available commands."

**Pass if:** Error message appears and includes the `!help` suggestion.

**Fail if:** Companion says nothing, or the message goes to the LLM instead.

---

### Test 5: !passive — Passive Stance

**Acceptance criterion:** "`!passive` ... companion responds with a brief, in-character acknowledgment"

**Prerequisite:** Active companion targeted.

**Steps:**
1. Target your companion.
2. `/say !passive`
3. Verify companion says "I will stand down." in /say

**Pass if:** Companion says "I will stand down."

**Fail if:** No response, wrong phrase (e.g., "Standing by." or "Stopping."), or companion attacks targets.

---

### Test 6: !balanced — Balanced Stance (Split Response)

**Acceptance criterion:** "`!balanced` — Companion: 'I will fight at your side.' / Mercenary: 'Understood.'"

**Prerequisite:** Active companion targeted. Test with both a loyal companion
and a mercenary-type companion if available.

**Steps:**
1. Target a loyal companion (companion_type = 0).
2. `/say !balanced`
3. Note the response.
4. If a mercenary companion is available, target them.
5. `/say !balanced`
6. Note the response.

**Expected result (loyal):** "I will fight at your side."

**Expected result (mercenary):** "Understood."

**Pass if:** Loyal companion gives the relational phrase; mercenary gives the neutral phrase.

**Fail if:** Both give the same phrase, or either gives an incorrect phrase.

**GM commands to check companion type:**
```
#showstats    -- shows NPC stats; companion_type visible in extended info
```

---

### Test 7: !aggressive — Aggressive Stance

**Acceptance criterion:** "`!aggressive` ... companion responds with in-character acknowledgment"

**Prerequisite:** Active companion targeted.

**Steps:**
1. Target your companion.
2. `/say !aggressive`
3. Verify companion says "Understood. I will fight aggressively."

**Pass if:** Exact phrase appears.

**Fail if:** Participle form used (e.g., "Fighting aggressively." or "Going aggressive."), or no response.

---

### Test 8: !follow — Follow Mode

**Acceptance criterion:** Commands execute and companion responds appropriately.

**Prerequisite:** Active companion in guard mode (use `!guard` first).

**Steps:**
1. Target your companion.
2. `/say !guard`
3. Walk away from companion.
4. Verify companion stays put.
5. `/say !follow`
6. Walk further away.
7. Verify companion follows you.

**Expected result for !guard:** "I will hold here." Companion stops moving.

**Expected result for !follow:** "I will follow." Companion resumes following.

**Pass if:** Both movement modes work with correct phrases.

**Fail if:** Companion ignores the commands, or phrases differ from spec.

---

### Test 9: !recall — Teleport Companion

**Acceptance criterion:** "`!recall` teleports a stuck companion to the player's location (only if distance > 200 units)"

**Prerequisite:** Active companion in guard mode, player must be more than 200 units away from companion.

**Steps:**
1. Target your companion.
2. `/say !guard` — companion holds position.
3. Run away from companion (approximately 3-4 character lengths — you need 200 units, roughly half a zone section).
4. Target companion again (use `/target [name]` or click).
5. `/say !recall`
6. Verify companion teleports to your position and says "I am here."

**Pass if:** Companion appears at your feet and says "I am here."

**Fail if:** Companion doesn't move, no message, or an error appears.

**GM commands:**
```
#findnpc [companionname]    -- locate companion in zone to verify distance
```

---

### Test 10: !recall When Companion is Nearby

**Acceptance criterion:** "`!recall` when companion is within 200 units shows 'Your companion is already nearby.'"

**Prerequisite:** Active companion at your side (default follow position).

**Steps:**
1. Target your companion (they should be standing right next to you).
2. `/say !recall`
3. Verify error message appears.

**Expected result:** "Your companion is already nearby." — companion does NOT teleport.

**Pass if:** Error message appears and companion does not move.

**Fail if:** Companion teleports even when adjacent, or no message.

---

### Test 11: !recall Cooldown

**Acceptance criterion:** "`!recall` respects 30-second cooldown"

**Prerequisite:** Complete Test 9 first (successful recall).

**Steps:**
1. Run away again to more than 200 units from companion.
2. Target companion.
3. `/say !recall` — should succeed (companion teleports).
4. Immediately run away again to >200 units.
5. Target companion.
6. `/say !recall` within 30 seconds.
7. Verify cooldown message.

**Expected result (step 7):** "Recall is on cooldown."

**Pass if:** Second recall within 30 seconds is blocked with the cooldown message.

**Fail if:** Second recall succeeds without waiting, or shows wrong message.

---

### Test 12: !status — Companion Overview

**Acceptance criterion:** "`!status` displays the companion's name, level, HP, mana, stance, and movement mode"

**Prerequisite:** Active companion targeted.

**Steps:**
1. Target your companion.
2. `/say !passive` (set a known stance)
3. `/say !guard` (set a known mode)
4. `/say !status`
5. Read the system messages.

**Expected result:** Four lines:
- "=== [CompanionName] ==="
- "  Level: [N]  Class: [ClassName]"
- "  HP: [current]/[max]  Mana: [current]/[max]"
- "  Stance: Passive  Mode: Guard"
- "  Type: Companion" (or "Mercenary")

**Pass if:** All five fields appear with correct data. Stance shows "Passive" and Mode shows "Guard" based on the preceding commands.

**Fail if:** Any field missing, stance or mode incorrect, or output is empty.

---

### Test 13: !target — Combat Targeting (Active Stance)

**Acceptance criterion:** "`!target` causes the companion to target the player's current target"

**Prerequisite:** Active companion in balanced stance. A hostile NPC in the zone you can target.

**Steps:**
1. `/say !balanced` to your companion.
2. Target a hostile NPC.
3. `/say !target` to your companion (keep companion targeted after saying this — or use the `/say` while companion is current target).
4. Verify companion says "I see your target."
5. Verify companion engages the hostile NPC.

**Expected result:** "I see your target." Companion attacks the hostile NPC.

**Pass if:** Companion says the correct phrase and engages combat.

**Fail if:** No response, wrong phrase, or companion does not engage.

**GM commands:**
```
#spawn [npcid]    -- spawn a hostile mob to test against
```

---

### Test 14: !target in Passive Stance — No Engagement

**Acceptance criterion:** "`!target` and `!assist` in passive stance: companion targets but does NOT attack"

**Prerequisite:** Active companion in passive stance. A hostile NPC nearby.

**Steps:**
1. `/say !passive` to your companion.
2. Target a hostile NPC.
3. `/say !target` to your companion.
4. Verify companion says "I see your target."
5. Verify companion does NOT engage or move to attack.

**Pass if:** Companion acknowledges the target but remains passive — no attack animation, no chase.

**Fail if:** Companion attacks even in passive stance.

---

### Test 15: !assist — Combat Assist

**Acceptance criterion:** "`!assist` causes the companion to assist the player in combat"

**Prerequisite:** Active companion in balanced stance. A hostile NPC targeted.

**Steps:**
1. `/say !balanced` to your companion.
2. Target a hostile NPC.
3. `/say !assist` to your companion.
4. Verify companion says "I will assist."
5. Verify companion engages the same target.

**Pass if:** "I will assist." appears and companion engages.

**Fail if:** Wrong phrase (e.g., "Assisting."), or companion does not engage.

---

### Test 16: !target / !assist — No Target Error

**Acceptance criterion:** Error message when player has no target.

**Prerequisite:** Active companion targeted. Player has no target selected (click off all targets).

**Steps:**
1. Clear your target (press Escape or click empty ground).
2. Target your companion.
3. `/say !target`
4. Verify error message.

**Expected result:** "You must target an enemy first."

**Pass if:** Error message appears. Companion does not engage anything.

**Fail if:** No message, wrong message, or error causes companion to crash.

---

### Test 17: !equipment — Show Equipped Items

**Acceptance criterion:** "`!equipment` shows the companion's equipped items"

**Prerequisite:** Active companion targeted. Companion should have at least one item equipped (trade an item to them first if needed).

**Steps:**
1. Target your companion.
2. `/say !equipment`
3. Review output.

**Expected result:** System messages listing equipment slots and item names (or "(empty)" for unequipped slots).

**Pass if:** At least slot names are listed; the format matches the PRD example (slot: item name).

**Fail if:** No output, or a Lua error appears.

---

### Test 18: !unequip slot — Return Item from Slot

**Acceptance criterion:** "`!unequip <slot>` returns the item from the specified slot to the player"

**Prerequisite:** Companion has an item equipped in the primary slot.

**Steps:**
1. Give companion a weapon via right-click trade.
2. Target your companion.
3. `/say !equipment` — confirm item is in primary slot.
4. `/say !unequip primary`
5. Verify companion says "As you wish."
6. Check your inventory — item should have returned to you.

**Pass if:** Item appears in your inventory and companion's primary slot is now empty.

**Fail if:** Item does not transfer, wrong message, or Lua error.

---

### Test 19: !unequip all — Return All Items

**Acceptance criterion:** "`!unequip all` returns all equipped items"

**Prerequisite:** Companion has items in multiple slots.

**Steps:**
1. Give companion 2-3 items via trade.
2. Target your companion.
3. `/say !unequip all`
4. Verify companion says "As you wish."
5. Check your inventory — all items should have returned.

**Pass if:** All equipped items appear in your inventory.

**Fail if:** Any item not returned, wrong message, or Lua error.

---

### Test 20: !dismiss — Voluntary Dismissal

**Acceptance criterion:** "`!dismiss` dismisses the companion with voluntary=true (re-recruit bonus)"

**Prerequisite:** Active companion targeted.

**Steps:**
1. Target your companion.
2. `/say !dismiss`
3. Verify companion says "Farewell."
4. Verify companion disappears (is dismissed).
5. Find the same NPC in the world.
6. Say "join me" to attempt re-recruitment.
7. Verify the recruitment roll has a +10% bonus (the re-recruitment bonus is not directly visible, but the system should succeed more readily and the NPC should say "I remember you. Let us continue." on success).

**Expected result:** "Farewell." then companion vanishes. Re-recruitment says "I remember you. Let us continue."

**Pass if:** Dismissal phrase is correct and companion de-spawns. Re-recruitment shows memory phrase.

**Fail if:** Wrong phrase, companion stays, or re-recruitment shows "I will join you." (new recruit phrase) instead of memory phrase.

---

### Test 21: Command to Non-Companion NPC

**Acceptance criterion:** "Commands targeting a non-companion NPC produce: 'That is not your companion.'"

**Prerequisite:** A regular (non-companion) NPC in the zone.

**Steps:**
1. Target a regular NPC (not your companion).
2. `/say !follow`
3. Verify error message.

**Expected result:** "That is not your companion."

**Pass if:** Error message appears. The NPC does not execute any command.

**Fail if:** No message, wrong message, or the NPC somehow follows you.

**Note:** This check fires from the ownership check in `dispatch_prefix_command`. It only
fires if the target IS a companion (another player's). For a completely non-companion NPC,
the `!follow` message starts with `!`, but the NPC is not a companion so `IsCompanion()` is
false and the prefix check is skipped entirely — the message falls through to the LLM block
instead. To test "That is not your companion.", target ANOTHER PLAYER'S companion (requires
a second player), then try to issue commands to it.

---

### Test 22: Conversation — No Prefix Goes to LLM

**Acceptance criterion:** "Typing any text without the `!` prefix to a targeted companion sends the text to the LLM and the companion responds with natural dialogue"

**Prerequisite:** Active companion targeted. LLM sidecar must be running.

**Steps:**
1. Target your companion.
2. `/say How are you holding up?`
3. Verify companion responds with a contextual, personality-driven response (NOT a command acknowledgment).
4. `/say Tell me about your life before we met.`
5. Verify LLM-generated response.

**Pass if:** Companion gives an in-character, non-templated conversational response.

**Fail if:** No response (LLM sidecar may be down — test as SKIP in that case), or a command response appears (e.g., "I will follow.").

---

### Test 23: Old Keywords No Longer Intercept Commands

**Acceptance criterion:** "The old keyword-based management commands no longer trigger command actions when spoken without the `!` prefix"

**Prerequisite:** Active companion targeted.

**Steps:**
1. Target your companion.
2. `/say follow me to the castle`
3. Verify companion does NOT enter follow mode via command — response should be LLM conversation, not "I will follow."
4. `/say stay safe while I scout ahead`
5. Verify companion does NOT enter guard mode — should go to LLM.
6. `/say farewell old friend`
7. Verify companion is NOT dismissed — should go to LLM.
8. `/say I need to guard this passage`
9. Verify companion is NOT put in guard mode.

**Pass if:** All four messages produce LLM conversational responses, not command acknowledgments. Companion remains in its current stance/mode.

**Fail if:** Any unprefixed message triggers a management command.

---

### Test 24: Recruitment Keywords Still Work

**Acceptance criterion:** "Recruitment commands continue to work as keyword-based commands for non-companion NPCs, unchanged"

**Prerequisite:** A non-companion NPC with good faction and appropriate level.

**Steps:**
1. Target a non-companion NPC.
2. `/say join me`
3. Verify recruitment attempt triggers (success or failure roll, appropriate message).
4. `/say come with me`
5. Verify recruitment attempt triggers.
6. `/say recruit` to the same or another NPC.

**Pass if:** All three phrases attempt recruitment. The NPC either accepts ("I will join you.") or declines ("I will not join you.") based on the roll.

**Fail if:** Keywords are silently ignored or sent to LLM without triggering recruitment.

---

### Test 25: Ownership Check — Other Player's Companion

**Acceptance criterion:** "A player cannot command another player's companion (ownership check)"

**Prerequisite:** Two players online. Player B has an active companion.

**Steps:**
1. As Player A, target Player B's companion.
2. `/say !follow`
3. Verify error message.

**Expected result:** "That is not your companion."

**Pass if:** Error message appears. Player B's companion ignores the command.

**Fail if:** Companion executes the command for Player A.

---

## Edge Case Tests

Tests derived from the architecture plan's antagonistic review.

### Test E1: Space After Prefix (! follow)

**Risk from architecture plan:** "Edge: `! follow` (space after prefix) — Handled: `body = message:sub(2):gsub('^%s+', '')` strips leading whitespace."

**Steps:**
1. Target your companion.
2. `/say ! follow` (note space between ! and follow)
3. Verify follow mode activates.

**Pass if:** "I will follow." — whitespace is ignored.

**Fail if:** "Unknown command" error, meaning the space was not stripped.

---

### Test E2: Double Prefix (!!follow)

**Risk from architecture plan:** "Edge: `!!follow` (double prefix) — Strips first `!`, leaving `!follow` as the command lookup. Not found in table. Error message displayed. Acceptable."

**Steps:**
1. Target your companion.
2. `/say !!follow`
3. Verify unknown command error.

**Expected result:** "Unknown command: !!follow. Type !help for available commands."

**Pass if:** Error message appears with the double-prefix text.

**Fail if:** Companion enters follow mode (meaning the double prefix was parsed incorrectly).

---

### Test E3: !dismiss During Active Combat

**Risk from architecture plan:** "`!dismiss` during combat — same behavior as current keyword system. `Dismiss(true)` handles cleanly."

**Steps:**
1. Engage a hostile NPC (get the companion into combat).
2. While companion is fighting, target your companion.
3. `/say !dismiss`
4. Verify companion says "Farewell." and is dismissed.

**Pass if:** Companion dismisses cleanly even while in combat. No server crash or error.

**Fail if:** Dismiss fails silently, causes a Lua error, or leaves the companion in a zombie state.

---

### Test E4: !recall Through Geometry (Stuck Scenario)

**Risk from architecture plan:** "`!recall` through walls — `GMMove()` ignores collision. Acceptable trade-off."

**Steps:**
1. Find a location where your companion can get stuck (near a ramp, doorway, or pathing obstacle).
2. Leave companion guarding there.
3. Move far away (>200 units).
4. `/say !recall`
5. Verify companion teleports to you despite geometry.

**Pass if:** Companion appears at your location regardless of geometry obstacles.

**Fail if:** Companion fails to teleport, gets stuck mid-move, or recall produces an error.

---

### Test E5: !status After Quest Reload (companion_modes reset)

**Risk from architecture plan:** "`companion_modes` table resets on `#reloadquests`. Default assumption is 'follow'. `!status` shows 'Follow' even if companion was guarding. Self-corrects on next movement command."

**Steps:**
1. Target your companion.
2. `/say !guard`
3. Verify "I will hold here."
4. As GM: `#reloadquests`
5. Target companion again.
6. `/say !status`
7. Note the Mode field.

**Expected result (step 7):** Mode shows "Follow" even though companion was set to guard before reload. This is documented expected behavior.

**Pass if:** Status shows "Follow" and no error occurs. After `/say !guard` again the mode corrects.

**Fail if:** Lua error on status command, or the server crashes on quest reload.

---

### Test E6: !unequip with Unknown Slot Name

**PRD error scenario:** "`!unequip badslot` — 'Unknown slot name. Valid slots: primary, secondary, head, chest...'"

**Steps:**
1. Target your companion.
2. `/say !unequip badslot`
3. Verify usage message.

**Expected result:** "Usage: !unequip <slot> or !unequip all" followed by the valid slots list.

**Note:** The current implementation shows the usage message when no argument is given. When a bad slot name is given, `npc:GiveSlot(client, slot_name)` is called with the invalid slot. The PRD specified an "Unknown slot name" error, but the implementation delegates this to the C++ `GiveSlot()` API — the error handling may appear differently in-game.

**Pass if:** Either an appropriate error appears, or nothing bad happens (the API call returns gracefully for an unknown slot).

**Fail if:** Lua error, server crash, or an item is unexpectedly removed.

---

### Test E7: !help with Unknown Topic

**Steps:**
1. Target your companion.
2. `/say !help badtopic`

**Expected result:** "Unknown help topic: badtopic" followed by "Available topics: stance, movement, equipment, combat, control, information"

**Pass if:** Correct error with topic list appears.

**Fail if:** Lua error or silent failure.

---

## Rollback Instructions

If testing reveals a critical issue, rollback steps are:

**Quest script rollback (Lua files):**
```bash
# Revert companion.lua to the previous keyword-based version from git
cd /mnt/d/Dev/eq
git checkout feature/recruited-npc-controls^ -- akk-stack/server/quests/lua_modules/companion.lua
git checkout feature/recruited-npc-controls^ -- akk-stack/server/quests/global/global_npc.lua

# Then reload quests in-game
#reloadquests
```

**C++ rule rollback:**
```bash
# Remove the RecallCooldownS line from ruletypes.h (line 1202)
# Then rebuild:
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
# Then restart via Spire at http://192.168.1.86:3000
```

**Database rule_values rollback:**
```bash
docker exec akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e \
  "DELETE FROM rule_values WHERE rule_name = 'Companions:RecallCooldownS';"
```

---

## Blockers

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|-------------------|--------|
| 1 | status.md shows Task 1 as "Not Started" but rule is implemented | Low | orchestrator | Open — status.md needs update only |

---

## Recommendations

Non-blocking observations from server-side review:

1. **Undocumented aliases:** `!gear` (alias for `!equipment`) and `!unequipall`
   (alias for `!unequip all`) exist in the COMMANDS table but are not listed in
   `!help` output or in the PRD. They work correctly. Either document them in
   `!help equipment` output or remove them if they were added accidentally.
   Recommend documenting — they are genuinely useful shortcuts.

2. **!equip response uses client:Message() not npc:Say():** The `!equip` handler
   uses `client:Message()` for the three instruction lines rather than `npc:Say()`.
   This means instructions appear as system messages (yellow text) rather than NPC
   speech. This is intentional (the instructions are system info, not in-character
   dialogue) but is noted for awareness.

3. **cmd_unequip with a non-empty bad slot name:** The `!unequip badslot` path
   calls `npc:GiveSlot(client, "badslot")` without a Lua-level check. The PRD
   specified an "Unknown slot name" error message. The C++ `GiveSlot()` call may
   handle this gracefully or silently — verify in-game (Test E6). If it causes
   any issue, a Lua-level slot name validation table should be added.

4. **Zone bootup failures in zone_187:** Two unrelated zone bootup failures were
   found in logs (2026-02-23, 2026-02-27). These predate this feature. Recommend
   investigating separately as they may indicate a recurring zone instability
   unrelated to companion scripts.

5. **status.md Task 1 discrepancy:** The config-expert's implementation task
   (Add RecallCooldownS rule) shows "Not Started" in status.md but is clearly
   complete in the codebase. The orchestrator should update status.md to mark
   Task 1 as Complete.
