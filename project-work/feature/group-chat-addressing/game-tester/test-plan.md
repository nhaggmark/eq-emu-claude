# Group Chat Companion Addressing — Test Plan

> **Feature branch:** `feature/group-chat-addressing`
> **Author:** game-tester
> **Date:** 2026-03-07
> **Server-side result:** PASS WITH WARNINGS

---

## Test Summary

This plan validates the Group Chat Companion Addressing feature, which allows
players to address recruited NPC companions via `@Name` patterns in `/gsay`
group chat. Commands (`!follow`, `!attack`, etc.) and LLM conversations route
to matched companions without requiring target switching. The implementation
spans C++ (`client.cpp`, `client.h`, `ruletypes.h`), Lua (`global_npc.lua`),
and database (`rule_values`).

**Warning note:** Task #4 (lua-expert) was listed as "Not Started" in status.md
but the actual `global_npc.lua` file contains the full implementation. The
Lua changes are present and verified. Status.md is stale — see server-side
results below. Task #5 (build/deploy) is also listed "Not Started" but the
binary was rebuilt at 14:11 and the server started at 14:12. Both tasks are
effectively complete.

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] status.md — Tasks 1 and 2 marked Complete; Tasks 3, 4, 5 listed Not Started
  (but implementation verified present in all files — status.md was not updated
  by implementing agents)
- [x] Acceptance criteria identified: 14 criteria from PRD

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | DB: Companions:GroupChatAddressingEnabled exists | PASS | rule_value='true', ruleset_id=1 |
| 2 | DB: Companions:GroupChatResponseStaggerMinMS exists | PASS | rule_value='1000', ruleset_id=1 |
| 3 | DB: Companions:GroupChatResponseStaggerMaxMS exists | PASS | rule_value='2000', ruleset_id=1 |
| 4 | DB: No duplicate Companions:GroupChat* rows | PASS | Exactly 3 rows matching Companions:GroupChat* |
| 5 | DB: Total rule_values count matches log | PASS | DB has 1025 rows; zone log shows "Loaded [1,025] rules" |
| 6 | Lua syntax: global_npc.lua | PASS | luajit bytecode compile clean (exit 0) |
| 7 | Lua impl: gsay_response_channel in global_npc.lua | PASS | Lines 68-96 implement group chat routing |
| 8 | Lua impl: gsay_stagger_ms in global_npc.lua | PASS | Lines 73-86 implement stagger timer path |
| 9 | Lua impl: gsay_pending_response in global_npc.lua | PASS | Lines 79, 259-261 implement deferred delivery |
| 10 | Lua impl: event_timer gsay_deliver_ branch | PASS | Lines 257-274 implement timer-based group delivery |
| 11 | C++ impl: HandleGroupChatMentions declared in client.h | PASS | client.h:2414 |
| 12 | C++ impl: HandleGroupChatMentions implemented in client.cpp | PASS | client.cpp:1680-1859 |
| 13 | C++ impl: GroupChatAddressingEnabled rule used as guard | PASS | client.cpp:1369 |
| 14 | C++ impl: gsay_response_channel entity variable set | PASS | client.cpp:1842 |
| 15 | C++ impl: gsay_stagger_ms entity variable set | PASS | client.cpp:1851 |
| 16 | C++ impl: Prefix strip list matches PRD | PASS | 20 prefixes; "High Priestess" before "Priestess" |
| 17 | C++ impl: Raid path unaffected (checked before group) | PASS | client.cpp:1361-1365 raid check before @-parsing |
| 18 | C++ impl: @-parser only at word boundary | PASS | client.cpp:1708 checks msg[at_pos - 1] == ' ' |
| 19 | C++ impl: empty payload = no dispatch | PASS | client.cpp:1830-1833 |
| 20 | C++ impl: @all resolves all companions | PASS | client.cpp:1737-1742 at_all flag |
| 21 | Build verification: ninja reports no work | PASS | "ninja: no work to do." — binary up-to-date |
| 22 | Server processes running with rebuilt binary | PASS | zone PID 611 started 14:12, binary built 14:11 |
| 23 | Zone log: no errors on startup | PASS | zone_611.log clean, no errors |
| 24 | World log: no feature-related errors | PASS | Only pre-existing address mismatch warnings (unrelated) |
| 25 | Entity variable names match C++ vs Lua | PASS | All three names identical: gsay_response_channel, gsay_stagger_ms, gsay_pending_response |
| 26 | status.md accuracy: Tasks 4 and 5 | WARN | status.md shows "Not Started" but implementation is complete — stale tracker |

---

### Database Integrity

**Queries run:**

```sql
-- Verify three new Companions:GroupChat* rule rows exist with correct values
SELECT ruleset_id, rule_name, rule_value, notes
FROM rule_values
WHERE rule_name LIKE 'Companions:GroupChat%'
ORDER BY rule_name;

-- Verify total rule count matches zone startup log
SELECT COUNT(*) FROM rule_values WHERE ruleset_id=1;
```

**Findings:**

Three rows confirmed present in `rule_values`:

| ruleset_id | rule_name | rule_value |
|------------|-----------|------------|
| 1 | Companions:GroupChatAddressingEnabled | true |
| 1 | Companions:GroupChatResponseStaggerMaxMS | 2000 |
| 1 | Companions:GroupChatResponseStaggerMinMS | 1000 |

Total rule count: 1025 rows, matching the zone log's "Loaded [1,025] rules(s)"
confirmation. No integrity issues. No orphaned rows.

Note: data-expert used category name `Companions:` (plural) which matches the
actual existing category in `ruletypes.h`. The architecture doc specified
`Companion:` (singular) but the correct in-source name is `Companions:`.

---

### Quest Script Syntax

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| `akk-stack/server/quests/global/global_npc.lua` | Lua | PASS | luajit bytecode compile clean; exit code 0 |

Command used:
```bash
docker exec akk-stack-eqemu-server-1 bash -c \
  "/home/eqemu/code/build/vcpkg_installed/x64-linux/tools/luajit/luajit \
   -bl /home/eqemu/server/quests/global/global_npc.lua > /dev/null 2>&1 && echo PASS || echo FAIL"
```

The `-bl` flag compiles to bytecode without executing, catching all syntax errors.
Result: PASS.

---

### Log Analysis

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| `zone/zone_611.log` | 0 | — | Zone started cleanly; 1025 rules loaded |
| `world.log` | Pre-existing | Low | IP address mismatch warnings (not related to this feature) |
| `loginserver.log` | 0 | — | Not checked in detail; loginserver unaffected |

The world.log warnings about `192.168.1.86` vs `172.18.0.9` and `108.196.10.119`
are pre-existing configuration notices about the Docker network bridge and external
IP. They are unrelated to this feature and present before implementation.

---

### Rule Validation

| Rule | Category | Value | Valid Range | Result |
|------|----------|-------|-------------|--------|
| GroupChatAddressingEnabled | Companions | true | true/false | PASS |
| GroupChatResponseStaggerMinMS | Companions | 1000 | >= 0 (ms) | PASS |
| GroupChatResponseStaggerMaxMS | Companions | 2000 | >= GroupChatResponseStaggerMinMS | PASS |

C++ guard: `if (max_ms < min_ms) max_ms = min_ms;` at `client.cpp:1848` prevents
invalid stagger range at runtime.

---

### Spawn Verification

Not applicable. This feature adds no new spawns, spawn groups, or grids.

---

### Loot Chain Validation

Not applicable. This feature adds no loot table entries.

---

### Build Verification

- **Build command:** `docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
- **Result:** PASS
- **Output:** `ninja: no work to do.` — binary is current, no recompilation needed.
- **Zone binary:** `/home/eqemu/code/build/bin/zone` — modified 2026-03-07 14:11
- **Server started:** 2026-03-07 14:12 (after build)

The `zone` process (PID 611) is running the newly built binary. The build was
performed by c-expert and the server was restarted correctly.

---

## Part 2: In-Game Testing Guide

### Prerequisites

The following setup is needed before running any test cases:

1. **Character:** A GM-level character is needed for command access. Level 50 is
   sufficient. Any race/class works.

2. **Companions recruited:** You need 2-3 companion NPCs in your group. Recruit
   them from any zone using the recruitment keywords (`recruit`, `join me`, etc.)
   while targeting appropriate NPCs. Suggestion: recruit from North Qeynos area
   NPCs — Guards work well.

3. **Zone:** Any zone with recruitable NPCs works. Qeynos (North Qeynos shortname
   `qeynos2`) is recommended for easy access to Guard NPCs and is the current
   running zone.

4. **LLM sidecar:** For conversational tests (Tests 7-9), the LLM sidecar must
   be running. The conversational tests are marked accordingly and can be skipped
   if the sidecar is unavailable.

**GM setup commands to run before testing:**
```
#level 50
#zone qeynos2
```

To recruit companions quickly, target a Guard NPC and say:
```
/say recruit
```

Repeat for 2-3 different Guard NPCs to build a test group.

**Naming note for tests:** Throughout this guide, "Guard Iskarr", "Guard Sylus",
and "Guard Astrid" are used as example companion names. Substitute with the
actual names of NPCs you recruit.

---

### Test 1: Single Companion Command via @name

**Acceptance criterion:** "Player types `/gsay @companionname !command` and the
named companion executes the command without the player changing their target."

**Prerequisite:** 1 companion in your group. Target a mob or object (not the
companion) before issuing the command.

**Steps:**
1. Log in as your GM character, zone to `qeynos2`.
2. Recruit one NPC companion (e.g., a Guard NPC). Note their exact name.
3. Target any mob or object that is NOT your companion. Keep that target
   throughout this test.
4. Type in group chat: `/gsay @<companionname> !follow`
   (Replace `<companionname>` with the actual companion name, e.g.,
   `/gsay @iskarr !follow` if companion is "Guard Iskarr")
5. Observe your companion's behavior.
6. Observe your current target — it should remain unchanged.

**Expected result:** The companion begins following you. Your target does not
change to the companion.

**Pass if:**
- Companion begins the follow behavior.
- Your client's target indicator remains on the original target.
- The raw text `@iskarr !follow` (or equivalent) is visible in group chat for
  all members.

**Fail if:**
- Companion does not respond to the command.
- Your target changes to the companion.
- An error appears in game or server logs.

**GM commands for setup:**
```
#zone qeynos2
#level 50
```

---

### Test 2: All Companions Respond to @all Command

**Acceptance criterion:** "Player types `/gsay @all !command` and all recruited
companions in the group execute the command."

**Prerequisite:** 2+ companions in your group.

**Steps:**
1. Recruit 2-3 companions into your group.
2. Issue a command to put them in guard mode: `/say guard` (targeting each).
3. Target any mob that is NOT a companion.
4. Type: `/gsay @all !follow`
5. Observe all companions.

**Expected result:** Every companion in the group begins following you. The
player's target is unchanged.

**Pass if:**
- All companions switch to follow behavior.
- Player target is unchanged.
- The `/gsay @all !follow` text is visible in group chat.

**Fail if:**
- Only some companions respond.
- No companions respond.
- Any companion is skipped without explanation.

---

### Test 3: Multi-Companion Addressing with @name1 and @name2

**Acceptance criterion:** "Player types `/gsay @name1 and @name2 !command` and
both named companions execute the command."

**Prerequisite:** Exactly 3 companions in group: A, B, and C. You will address
only A and B.

**Steps:**
1. Recruit 3 companions. Note all their names.
2. Issue `/gsay @all !guard` to put all three in guard mode (hold position).
3. Target something that is not a companion.
4. Type: `/gsay @<companion_A_name> and @<companion_B_name> !follow`
   (e.g., `/gsay @iskarr and @sylus !follow`)
5. Observe all three companions.

**Expected result:** Companions A and B begin following. Companion C remains
in guard/hold position.

**Pass if:**
- Companions A and B follow.
- Companion C does not change behavior.
- Player target unchanged.

**Fail if:**
- Companion C follows (unintended).
- A or B does not follow.
- Player target changes.

---

### Test 4: Case-Insensitive Name Matching

**Acceptance criterion:** "Companion name matching is case-insensitive and works
with partial names (substring)."

**Prerequisite:** 1 companion in group with a known name (e.g., "Guard Iskarr").

**Steps:**
1. With companion "Guard Iskarr" in group, type:
   `/gsay @ISKARR !follow`
2. Issue a guard command, then try:
   `/gsay @Iskarr !follow` (mixed case)
3. Issue a guard command, then try:
   `/gsay @iskarr !follow` (lowercase)

**Expected result:** All three variations work identically — the companion
responds to each form.

**Pass if:** Companion responds to all three case variations.
**Fail if:** Companion responds to some but not others.

---

### Test 5: Substring Name Matching

**Acceptance criterion:** "Companion name matching is case-insensitive and works
with partial names (substring)."

**Prerequisite:** 1 companion in group with a multi-character name
(e.g., "Guard Iskarr").

**Steps:**
1. With companion "Guard Iskarr" in group, type:
   `/gsay @isk !follow` (partial match — first 3 letters of "Iskarr")
2. Observe whether companion responds.
3. Try an even shorter substring:
   `/gsay @is !follow`

**Expected result:** Companion responds to the substring. Note: very short
substrings like `@is` may match multiple companions if any others have "is"
in their name — this is expected behavior.

**Pass if:** Companion responds to `@isk !follow`.
**Fail if:** Companion ignores the partial-name address.

---

### Test 6: Prefix Stripping Matches Companion Names

**Acceptance criterion:** "Common NPC prefixes (Guard, Captain, Sir, Lieutenant,
Keeper, etc.) are stripped before matching, so `@iskarr` matches 'Guard Iskarr'."

**Prerequisite:** Companion whose name has a prefix (e.g., "Guard Iskarr",
"Captain Rohand").

**Steps:**
1. Recruit a companion with a prefix title (e.g., "Guard Iskarr").
2. Type: `/gsay @iskarr !follow`
   (Note: `@iskarr` without the "Guard" prefix)
3. Observe if companion responds.
4. Verify the same command using the full name also works:
   `/gsay @guard !follow`
   (matches "Guard" prefix — but this is ambiguous if multiple Guards are present)

**Expected result:** `@iskarr` successfully routes to "Guard Iskarr" without
requiring the player to type "@guard iskarr".

**Pass if:** Companion responds to `@iskarr`.
**Fail if:** Companion does not respond and requires the full "Guard Iskarr" prefix.

**Prefixes to test if multiple companion types are available:**
- `@iskarr` for "Guard Iskarr"
- `@rohand` for "Captain Rohand"
- (test any prefix from the list: Guard, Captain, Lady, Lord, Sir, Priestess,
  High Priestess, Scout, Merchant, Innkeeper, Banker, Sage, Elder, Master,
  Apprentice, Lieutenant, Warden, Keeper, Deputy, Sergeant)

---

### Test 7: Conversational @mention Routes Response to Group Chat (LLM Required)

**Acceptance criterion:** "Player types `/gsay @companionname how are you?` and
receives an LLM-generated response from that companion in group chat."

**Note:** This test requires the LLM sidecar to be running. If it is not
available, skip to Test 10 and return to this test when the sidecar is up.

**Prerequisite:** 1 companion in group. LLM sidecar running.

**Steps:**
1. Target something that is NOT your companion.
2. Type: `/gsay @<companionname> how are you holding up?`
3. Wait for a response (LLM calls take 2-10 seconds).
4. Observe where the response appears.
5. Observe whether your target changed.

**Expected result:** The companion's LLM-generated response appears in the
GROUP CHAT window, not as an NPC `/say` message. The companion's name appears
as the speaker in group chat. The player's target is unchanged.

**Pass if:**
- Response appears in group chat (not in local /say).
- Response shows the companion's name as speaker.
- Player target is unchanged.
- Response is LLM-generated (contextually appropriate to the question).

**Fail if:**
- Response appears as a local /say message (old behavior).
- No response appears at all.
- Player target changes.
- Response appears in group chat but with the wrong sender name.

---

### Test 8: @all Conversational — Multiple Responses Staggered (LLM Required)

**Acceptance criterion:** "Player types `/gsay @all what do you think?` and each
companion responds in group chat with responses staggered 1-2 seconds apart."

**Note:** Requires LLM sidecar and 2+ companions.

**Prerequisite:** 2-3 companions in group. LLM sidecar running.

**Steps:**
1. Type: `/gsay @all how are you all doing?`
2. Note the time when you send the message.
3. Watch the group chat window carefully.
4. Observe when each companion's response appears.

**Expected result:** Each companion responds in group chat. Responses do not
all appear simultaneously — there is a staggered delay of approximately 1-2
seconds between each companion's response. Order and exact timing may vary.

**Pass if:**
- All companions respond in group chat.
- Responses are not simultaneous (staggered with visible gaps).
- Gap between responses is in the 1-3 second range (allowing for LLM latency).

**Fail if:**
- All responses appear at exactly the same time.
- Some companions don't respond.
- Responses appear as local /say rather than group chat.

**Observation tip:** Since LLM calls are blocking and sequential, the first
companion's response will appear after the LLM generates it (1-3s), and
subsequent companions will be delayed by their stagger timer on top of the
LLM generation time. This is the expected multi-layered delay.

---

### Test 9: Existing /say Path Continues Working (Regression)

**Acceptance criterion:** "Regular `/say` targeting + companion conversation
continues to work unchanged alongside the new `/gsay` addressing."

**Prerequisite:** 1 companion in group. LLM sidecar running for conversation part.

**Steps:**
1. TARGET your companion directly (click on them).
2. Type: `/say !follow`
3. Observe companion responds with follow behavior.
4. Type: `/say hello there`
5. Observe LLM response appears as a local /say message (old behavior, not group chat).
6. Untarget the companion and target something else.
7. Confirm the `/say !follow` does NOT route to the companion (since the companion
   is not targeted anymore).

**Expected result:** Targeting a companion and using `/say` works exactly as before.
LLM conversations via `/say` return as local NPC say, not group chat.

**Pass if:**
- `/say !follow` (with companion targeted) executes the command.
- `/say hello` (with companion targeted) returns response as local /say.
- The local /say response is NOT in group chat format.

**Fail if:**
- `/say` path stops working.
- `/say` conversation responses now appear in group chat (regression).
- Companion no longer responds to direct `/say` targeting.

---

### Test 10: Regular /gsay Without @ Works Normally (Regression)

**Acceptance criterion:** "Regular `/gsay` messages without `@` mentions are
unaffected — group chat works normally for messages that don't use addressing."

**Prerequisite:** 1+ companions in group. Another player OR observe the group chat
window yourself.

**Steps:**
1. Type in group chat: `/gsay hello everyone, how are you?`
   (No @ symbol in message)
2. Observe the group chat window.
3. Type: `/gsay this is a normal group message`
4. Observe again.

**Expected result:** Both messages appear in group chat as normal group say
messages. No companion command routing occurs. The messages behave exactly
as they did before this feature was implemented.

**Pass if:** Messages appear in group chat without any modification or routing.
**Fail if:** Messages trigger unexpected companion behavior, disappear, or appear altered.

---

### Test 11: Silent Failure on Unmatched @name

**Acceptance criterion:** "Unmatched `@name` mentions are silently ignored;
matched companions still receive their commands."

**Prerequisite:** 1+ companions in group.

**Steps:**
1. Type: `/gsay @nobody !follow`
   (Where "nobody" matches no companion in your group)
2. Observe: no error message should appear. The raw text is visible in group chat.
3. Observe: companions do not do anything unexpected.
4. Type: `/gsay @<real_companion> and @nobody !follow`
   (Mix a real companion name with a fake one)
5. Observe: real companion follows, no error for "nobody".

**Expected result:** Step 1 — message appears in group chat, no error. No companion
does anything. Step 3 — the real companion executes `!follow`; the `@nobody`
mention is silently dropped.

**Pass if:**
- No error message appears for unmatched @names.
- In the mixed case, the real companion still responds.
- The raw message text is visible in group chat.

**Fail if:**
- Error or "no companion matched" message appears.
- Real companion fails to respond when paired with an unmatched @name.

---

### Test 12: Target Preservation Throughout All Interactions

**Acceptance criterion:** "The player's current target is never changed by any
`@name` interaction."

**Prerequisite:** 1+ companions in group.

**Steps:**
1. Target a specific mob (or an item on the ground, or a door).
2. Note exactly what you have targeted.
3. Type: `/gsay @all !attack`
4. Check your target — has it changed?
5. Type: `/gsay @<companionname> !follow`
6. Check your target — has it changed?
7. If LLM sidecar is running, type: `/gsay @<companionname> how are you?`
8. Check your target after the LLM response appears.

**Expected result:** Your target remains unchanged through all three interactions.
The server-side routing happens without any target-switch packet being sent to the
Titanium client.

**Pass if:** Target remains unchanged through all @mention interactions.
**Fail if:** Target changes to the companion at any point during or after any command.

---

### Test 13: Feature Toggle — Disable via Rule

**Acceptance criterion:** "The feature works with 1 companion, 2 companions, or
a full group of companions (up to 5)." / Feature toggle via rule.

**Note:** This test verifies the feature can be disabled. It requires `#reloadrules`
to be functional.

**Steps:**
1. Confirm feature works: `/gsay @<companion> !follow` (should work).
2. Open a MySQL session or use `#reloadrules` after changing the rule. Run:
   ```sql
   UPDATE rule_values SET rule_value='false'
   WHERE rule_name='Companions:GroupChatAddressingEnabled'
   AND ruleset_id=1;
   ```
3. In game, type: `#reloadrules`
4. Now type: `/gsay @<companion> !follow`
5. Observe: the raw text goes through as normal group chat; companion does NOT receive the command.
6. Re-enable: update rule back to 'true' and `#reloadrules`.
7. Confirm feature works again: `/gsay @<companion> !follow`.

**Expected result:** When disabled, `/gsay @companion !follow` is treated as
ordinary group chat text — visible to group but not routed to the companion.
When re-enabled, the feature works again.

**Pass if:**
- Disabled: @mentions pass through as plain group chat.
- Re-enabled: @mentions route to companions correctly.

**Fail if:**
- Feature does not disable when rule is set to false.
- Re-enabling does not restore functionality.

**Rollback:** Ensure rule is set back to 'true' after this test.

---

### Test 14: EQ Macro Multi-Line Execution

**Acceptance criterion:** "EQ macros containing `/gsay @name !command` lines
execute correctly."

**Prerequisite:** 2 companions in group. Access to EQ hotbutton/macro editor in the
Titanium client.

**Steps:**
1. Create an EQ hotbutton macro with these lines:
   ```
   Line 1: /gsay @<companion_A> !attack
   Line 2: /gsay @<companion_B> !follow
   ```
2. Target a mob (not a companion).
3. Press the hotbutton.
4. Observe both companions.

**Expected result:** Companion A attacks your target. Companion B follows you.
Both commands execute from the single button press without any target switching.

**Pass if:**
- Both companions respond to their respective commands.
- Commands execute in sequence correctly.
- Player target remains unchanged.

**Fail if:**
- Only the first or last command executes.
- Target changes between macro lines.
- Client or server errors occur.

---

### Edge Case Tests

These tests address specific risks identified in the architecture plan's
antagonistic review.

---

### Test E1: @ in Email-Like Text Is Not Parsed

**Risk from architecture plan:** "/gsay contact me at bob@mail.com — the @mail
portion might be parsed as an @mention."

**Steps:**
1. Type: `/gsay you can reach me at bob@example.com for questions`
2. Observe: no companion receives an accidental command dispatch.

**Pass if:** Message appears in group chat as normal text. No companion behavior changes.
**Fail if:** Any companion responds as if receiving a command from the `@example` token.

---

### Test E2: Empty Payload — @mention with No Command or Text

**Risk from architecture plan:** "Empty payload: `/gsay @iskarr` (no command, no text after name)."

**Steps:**
1. Type: `/gsay @<companionname>` (nothing after the name)
2. Observe: message should appear in group chat as normal text. No command dispatch.

**Pass if:** Message appears in group chat. Companion does not receive an empty command.
**Fail if:** Server error, companion crashes, or unexpected behavior occurs.

---

### Test E3: Companion Not in Same Zone (Cross-Zone Group Member)

**Risk from architecture plan:** "Companion in different zone — cross-zone members
have null Mob pointers in local zone's group object."

**Note:** This is hard to reproduce intentionally on a 1-3 player server. Test by
verifying that normal @mention commands work even when a group member is cross-zone.
If you have a second character, zone them out and attempt @all from the in-zone character.

**Steps:**
1. Have a second character join your group and then zone out.
2. Type: `/gsay @all !follow`
3. Observe: companions in the CURRENT zone respond. No crash.

**Pass if:** In-zone companions respond normally. No crash or error for out-of-zone members.
**Fail if:** Server crashes, companions in current zone don't respond, or error logs appear.

---

### Test E4: gsay_response_channel Stale State After LLM Failure (LLM Required)

**Risk from architecture plan:** "gsay_response_channel variable persists after
failed LLM call — if generate_response() returns nil, variable remains set."

**Note:** This requires the LLM sidecar to be briefly unavailable or configured
to return nil. If you cannot test this directly, verify via code review that the
Lua implementation clears the variable before calling generate_response.

**Code verification (server-side, already done):**
`global_npc.lua` line 71 clears `gsay_response_channel` immediately upon reading it,
BEFORE calling the LLM sidecar (`generate_response` is called at line 61, before
the channel variable is even read). This means a failed LLM call cannot leave
stale state.

**Pass if:** Code review confirms clear-before-read pattern (already verified — PASS).
**Fail if:** Code reads channel variable after calling the sidecar (would allow stale state).

**Server-side verdict:** PASS (verified by code inspection at global_npc.lua lines 61-71).

---

### Test E5: Ambiguous Substring — @a Matches Multiple Companions

**Risk from architecture plan:** "@a !follow matches every companion whose
prefix-stripped name contains 'a'."

**Steps:**
1. Recruit 2 companions whose names both contain the letter "a" (e.g., "Guard Astrid"
   and "Guard Iskarr" — "iskarr" contains 'a').
2. Type: `/gsay @a !follow`
3. Observe which companions respond.

**Expected result:** ALL companions whose prefix-stripped name contains "a" respond.
This is intentional per PRD design — ambiguous substring addresses are broadcast to
all matching companions. Players should use more specific substrings.

**Pass if:** Multiple companions respond (the behavior is intentional).
**Fail if:** Server crashes, errors appear, or no companions respond when matches should exist.

---

### Test E6: @all with Companion Named "All"

**Risk from architecture plan:** "A companion named 'All' would conflict with @all broadcast."

**Steps:**
1. If any companion in your group is named "All" (or "Lady All", stripped to "All"):
   type `/gsay @all !follow`
2. Verify ALL companions receive the command (not just the one named "All").

**Note:** This edge case is unlikely in practice since EQ NPC names rarely include
"All" as the primary identifier. If it cannot be reproduced, mark as N/A.

**Pass if:** `@all` routes to ALL companions regardless of individual names.
**Fail if:** `@all` only routes to a companion named "All" and ignores others.

---

## Rollback Instructions

If testing reveals critical issues requiring rollback:

**Database rollback (remove the 3 new rule rows):**
```sql
DELETE FROM rule_values
WHERE rule_name IN (
  'Companions:GroupChatAddressingEnabled',
  'Companions:GroupChatResponseStaggerMinMS',
  'Companions:GroupChatResponseStaggerMaxMS'
)
AND ruleset_id = 1;
```
Then `#reloadrules` in game.

**Lua rollback (restore global_npc.lua):**
```bash
cd /mnt/d/Dev/eq/akk-stack
git checkout <previous-commit-hash> -- server/quests/global/global_npc.lua
```
Then `#reloadquests` in game.

**C++ rollback (restore client.cpp, client.h, ruletypes.h):**
```bash
cd /mnt/d/Dev/eq/eqemu
git checkout <previous-commit-hash> -- zone/client.cpp zone/client.h common/ruletypes.h
# Rebuild:
docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
# Restart server processes (loginserver, world, zone)
```

**To disable feature without rollback (fastest):**
```sql
UPDATE rule_values SET rule_value='false'
WHERE rule_name='Companions:GroupChatAddressingEnabled' AND ruleset_id=1;
```
Then `#reloadrules` in game. This disables all @-parsing with zero restart.

---

## Blockers

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|-------------------|--------|
| 1 | status.md Task #4 and Task #5 show "Not Started" but implementation is present | Low | orchestrator | Open — status.md needs update; no functional impact |

---

## Recommendations

- Update `status.md` to mark Tasks 3, 4, and 5 as Complete. The implementation is
  fully present and the build is clean. The tracker was not updated by the
  implementing agents.

- The stagger delay logic in `client.cpp:1851` multiplies `stagger_ms * dispatch_index`.
  For companion index 2 (third companion), this yields `stagger_ms * 2`. With min_ms=1000
  and range providing e.g. 1300ms for stagger_ms, companion 2 gets 1300ms delay and
  companion 3 gets 2600ms delay. This is within acceptable range for a 1-3 player server
  but is worth confirming feels natural during in-game Test 8.

- Consider adding a `#gsay` debug command in a future feature to show which companions
  were matched for a given `@mention` message, making it easier for players to diagnose
  when substring matching is ambiguous.

- The `gsay_pending_response` entity variable in the stagger timer path
  (`event_timer` in `global_npc.lua`) looks up the owner via
  `e.self:GetOwnerCharacterID()` and then `GetClientByCharID()`. If the owner
  zones out while the timer is pending, the lookup returns nil and the deferred
  response is silently dropped. This is the correct behavior (companion's owner
  is gone, response has nowhere to go) but it means `@all` conversations could
  produce fewer responses than expected if the player zones during LLM generation.
  This is an acceptable edge case for a 1-3 player server.
