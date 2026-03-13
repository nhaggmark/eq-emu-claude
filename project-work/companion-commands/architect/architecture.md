# Companion Commands — Architecture & Implementation Plan

> **Feature branch:** `feature/companion-commands`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-03-13
> **Status:** Approved

---

## Executive Summary

This feature makes three quality-of-life improvements to the companion command
system: (1) reworking `!help` to work without targeting a companion and
displaying clean alphabetically-sorted output, (2) adding a new `!hold` command
that combines guard + passive in one action, and (3) updating `!tome` to clear
the companion's target and stop active combat after repositioning. All changes
are pure Lua — no C++, database, or configuration changes are needed. A
documentation update and full test coverage round out the feature.

## Existing System Analysis

### Current State

The companion command system is implemented primarily in
`akk-stack/server/quests/lua_modules/companion.lua` (~1200 lines). Commands use
the `!` prefix and are dispatched through `companion.dispatch_prefix_command()`,
which is called from `global_npc.lua:event_say()` when `e.self:IsCompanion()`
and the message starts with `!`.

**Key data structures:**
- `COMMANDS` table (line 91-115): Maps command names to handler functions and
  categories. 23 commands across 7 categories (stance, movement, combat, buffs,
  equipment, information, control).
- `companion_modes` table (line 43): Module-local table tracking movement mode
  ("follow" or "guard") per entity ID.
- Command handlers follow the pattern `companion.cmd_<name>(npc, client, args)`.

**Say routing flow** (verified in `eqemu/zone/client.cpp:1546-1647`):
1. `#` command check → GM command dispatch
2. `^` bot command check → bot command dispatch
3. Profanity filter
4. Broadcast to nearby clients
5. **Player EVENT_SAY dispatch** (`global_player.lua`) — fires regardless of target
6. Proximity say check
7. **NPC EVENT_SAY dispatch** — requires `GetTarget() != null` and target in range

**Critical routing detail:** Player EVENT_SAY (step 5, line 1609) fires BEFORE
NPC EVENT_SAY (step 7, line 1633). A player-level handler can intercept messages
before they reach NPC dispatch, and does NOT require a target.

**Command output helper:** `companion_say(npc, client, msg)` (line 479-486)
routes messages through group chat if the player is grouped, otherwise falls
back to `npc:Say()`.

**@all dispatch:** Group chat @mentions are handled in C++
(`Client::HandleGroupChatMentions` in client.cpp:1680). The C++ code parses
@tokens, resolves companion names, and dispatches the payload as EVENT_SAY to
each matched companion. `!`-commands are dispatched immediately (no stagger).
No C++ changes needed for new commands — they are dispatched identically.

### Gap Analysis

| PRD Requirement | Current State | Gap |
|-----------------|---------------|-----|
| REQ-1: !help without target | Requires companion target (routed only via `global_npc.lua:event_say` which checks `e.self:IsCompanion()`) | Need player-level EVENT_SAY interception in `global_player.lua` |
| REQ-1: Alphabetical sorted output | Commands listed horizontally by category | Need per-line alphabetical output format |
| REQ-2: !hold command | Does not exist. Guard and passive are separate commands. | Need new command handler, COMMANDS table entry |
| REQ-3: !tome clears target | cmd_tome only does GMMove + companion_say | Need to add hate list wipe and follow mode reset |
| REQ-4: Documentation | 5 discrepancies between docs and code | Need doc rewrite |
| REQ-5: Tests | Only one test file exists (`test_companion_cmd_assist.lua`) | Need comprehensive test suite |

## Technical Approach

### Architecture Decision

All changes live in the **Lua layer** — no C++, SQL, rules, or config changes.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `akk-stack/server/quests/global/global_player.lua` | Add `event_say` handler | Intercept `!help` before NPC dispatch. Player EVENT_SAY fires at client.cpp:1609 regardless of target. Least-invasive: no C++ changes, no new event types. |
| `akk-stack/server/quests/lua_modules/companion.lua` | Modify COMMANDS table, add cmd_hold, modify cmd_tome, reformat cmd_help | All command logic lives here. Pure Lua changes. |
| `claude/docs/companion-commands-reference.md` | Rewrite documentation | Documentation-only. |
| `akk-stack/server/quests/tests/test_companion_*.lua` | Add test files | Test infrastructure already exists with mock pattern from `test_companion_cmd_assist.lua`. |

**Advisor consultations:**
- **protocol-agent:** Confirmed no protocol/Titanium concerns. All changes are
  Lua-layer. No new packets, opcodes, or struct changes. Player EVENT_SAY
  interception is standard and safe.
- **config-expert:** Confirmed no existing rules govern hold behavior, help
  display, or target-clearing. No rule changes needed. All Companions-category
  rules (`CompanionsEnabled`, `RecallCooldownS`, `EnforceClassRestrictions`,
  `EnforceRaceRestrictions`) are unaffected.

### Data Model

No database changes required.

### Code Changes

#### C++ Changes

**None.** All features are achievable in Lua using existing C++ bindings:
- `SetStance(int)` — set companion stance (0=passive, 1=balanced, 2=aggressive)
- `SetGuardMode(bool)` — toggle guard mode
- `WipeHateList()` — clear the companion's hate list
- `GMMove(x, y, z, h)` — instant reposition
- `GetHP()`, `GetStance()`, `CalculateDistance()` — state queries
- `SetTarget(mob)` — set target (not needed; WipeHateList handles disengagement)
- `IsCompanion()` — type check
- Player `event_say(e)` with `e.message` — fires in global_player.lua

#### Lua/Script Changes

**File 1: `akk-stack/server/quests/global/global_player.lua`**

Add an `event_say(e)` function that intercepts `!help` before NPC dispatch:

```lua
function event_say(e)
    -- Intercept !help at the player level so it works without a companion target.
    -- This fires BEFORE NPC EVENT_SAY (client.cpp line 1609 vs 1633).
    local msg = e.message
    if msg:sub(1, 1) == "!" then
        local body = msg:sub(2):gsub("^%s+", "")
        local cmd = body:match("^(%S+)") or ""
        if cmd:lower() == "help" then
            local companion_lib = require("companion")
            local args = body:match("^%S+%s+(.*)") or ""
            companion_lib.cmd_help_standalone(e.self, args)
        end
    end
end
```

**Design notes:**
- Only intercepts `!help` specifically, not all `!` commands. Other commands
  still require a companion target and route through `global_npc.lua`.
- Uses a new `cmd_help_standalone(client, args)` function that takes a Client
  (player) instead of an NPC. Output is delivered via `client:Message()` instead
  of `companion_say()`.
- The existing NPC-routed `cmd_help(npc, client, args)` is preserved for backward
  compatibility when a companion IS targeted. Both call the same formatting logic.

**File 2: `akk-stack/server/quests/lua_modules/companion.lua`**

Changes:

1. **COMMANDS table** — Add one entry:
   ```lua
   hold = { handler = "cmd_hold", category = "movement" },
   ```

2. **New function: `cmd_hold(npc, client, args)`**
   ```
   - Dead check: if HP <= 0, respond "[Name] is dead and cannot hold position."
   - Already holding check: if companion_modes[id] == "guard" AND stance == 0,
     respond "Already holding position."
   - Set guard mode ON: npc:SetGuardMode(true)
   - Set stance to passive: npc:SetStance(0)
   - Wipe hate list: npc:WipeHateList()
   - Track mode: companion_modes[npc:GetID()] = "guard"
   - Respond: "Holding position."
   ```

3. **Modified function: `cmd_tome(npc, client, args)`**
   Add after the GMMove call (line 858):
   ```
   - Wipe the companion's hate list: npc:WipeHateList()
     (This stops active combat without changing stance. Mobs that have the
      companion on THEIR hate lists continue pursuit — WipeHateList only
      clears the companion's own engagement tracking.)
   - Set follow mode: companion_modes[npc:GetID()] = "follow"
   - Break guard mode: npc:SetGuardMode(false)
   ```

4. **Modified function: `cmd_help(npc, client, args)`**
   Reformat the general help output (topic == "") to match the PRD format:
   - Commands listed alphabetically within each category
   - One command per line with dash-separated description
   - Aliases mentioned inline, not as separate entries
   - !hold included under Movement

5. **New function: `cmd_help_standalone(client, args)`**
   A player-level version of cmd_help that:
   - Takes a Client (player) instead of NPC
   - Uses `client:Message(color, msg)` instead of `companion_say()`
   - Includes the same @all deduplication lock (help_lock_key)
   - Shares the same formatting logic as the updated cmd_help

6. **Updated `cmd_assist` interaction with hold state:**
   The existing cmd_assist already auto-switches passive to balanced and
   adds to hate list. When called on a held companion:
   - `SetStance(1)` breaks the passive component (already in cmd_assist)
   - Need to also break guard: add `if npc.SetGuardMode then npc:SetGuardMode(false) end`
     and `companion_modes[npc:GetID()] = "follow"` to cmd_assist, since engaging
     a target requires the companion to move to that target.

**File 3: `claude/docs/companion-commands-reference.md`**

Complete rewrite to reflect all 24 commands with correct !-prefix syntax,
accurate behavior descriptions, owner-only annotations, and @all support.
Remove all references to old free-text commands.

**File 4-N: Test files** (in `akk-stack/server/quests/tests/`)

New test files following the existing mock pattern from
`test_companion_cmd_assist.lua`:
- `test_companion_cmd_hold.lua` — !hold behavior, breaking out of hold
- `test_companion_cmd_tome.lua` — !tome with target clearing, guard break
- `test_companion_cmd_help.lua` — help formatting, standalone (no target)
- `test_companion_commands_regression.lua` — regression for all 23 existing
  commands to verify no behavioral changes

#### Database Changes

None.

#### Configuration Changes

None.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Implement !hold command: add COMMANDS entry, cmd_hold handler, update cmd_assist to break guard on engage | lua-expert | — | Small: ~50 lines new, ~5 lines modified |
| 2 | Implement !tome update: add WipeHateList, SetGuardMode(false), follow mode after GMMove | lua-expert | — | Small: ~10 lines added to existing function |
| 3 | Implement !help rework: reformat cmd_help output to PRD format (alphabetical, per-line) | lua-expert | 1 (needs !hold in list) | Small: ~60 lines rewritten |
| 4 | Implement !help standalone: add event_say to global_player.lua, add cmd_help_standalone to companion.lua | lua-expert | 3 (shares formatting logic) | Small: ~30 lines new |
| 5 | Rewrite companion-commands-reference.md documentation | lua-expert | 1, 2, 3 | Medium: full doc rewrite (~200 lines) |
| 6 | Write comprehensive test suite: test_companion_cmd_hold.lua, test_companion_cmd_tome.lua, test_companion_cmd_help.lua, test_companion_commands_regression.lua | lua-expert | 1, 2, 3, 4 | Medium: ~400 lines across 4 test files |

**Total: 6 tasks, 1 agent (lua-expert)**

All tasks are Lua-only. A single lua-expert can execute the full sequence.
Tasks 1 and 2 are independent and could be done in parallel. Tasks 3-6
have sequential dependencies.

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `event_say` in global_player.lua conflicts with existing handler | Low | Medium | global_player.lua has no existing event_say. The function is new. Verified in source: file has event_enter_zone, event_combine_validate, event_combine_success, event_command, event_connect, event_level_up, event_test_buff, event_task_complete — but NO event_say. |
| WipeHateList in !tome causes companion to be ignored by AI | Low | Low | WipeHateList only clears the companion's own engagement list. The AI re-evaluates threats on each tick. If the companion's stance is aggressive, it will re-engage new threats that enter range. |
| luabind nil handling for SetTarget | N/A | N/A | Eliminated: architecture uses WipeHateList instead of SetTarget(nil). No nil-conversion risk. |
| !help player-level interception still triggers NPC dispatch when targeted | Low | Low | The NPC EVENT_SAY at line 1633 will still fire. The companion's cmd_help handler will also execute (with dedup lock preventing double output). This is harmless — the lock ensures only one response. |
| @all !hold dispatch timing | Low | Low | @all dispatch works identically for all commands. !hold uses the same handler pattern as !guard and !passive. No special timing concerns. |

### Compatibility Risks

No existing behavior is changed for the 23 existing commands. The only
modifications are:
- `cmd_tome`: Adds behavior AFTER the existing GMMove (additive, not replacing)
- `cmd_help`: Changes output FORMAT only (same information, better layout)
- `cmd_assist`: Adds guard-break AFTER existing engage logic (additive)

Regression tests (Task 6) verify all existing commands work unchanged.

### Performance Risks

None. All changes are in Lua quest script handlers that execute once per
command invocation. No hot-path changes, no database queries added, no
new timers or periodic processing.

## Review Passes

### Pass 1: Feasibility

**Can we actually build this with the existing codebase?**

Yes. All required C++ API methods are already bound to Lua:
- `SetStance(int)` — confirmed in companion.lua:490, 498, 509
- `SetGuardMode(bool)` — confirmed in companion.lua:519, 526
- `WipeHateList()` — confirmed in companion.lua:491
- `GMMove(x, y, z, h)` — confirmed in companion.lua:858
- `GetHP()`, `GetStance()`, `CalculateDistance()` — confirmed throughout
- Player `event_say(e)` — confirmed as firing at client.cpp:1609

**Hardest part:** The !help standalone routing. Verified that:
1. `global_player.lua` has NO existing `event_say` handler (checked full file)
2. Player EVENT_SAY fires before NPC EVENT_SAY in the C++ flow
3. The `companion` module can be `require()`d from any Lua script
4. `client:Message(color, msg)` delivers text to the player directly

**Protocol-agent confirmation:** No Titanium constraints. All changes are
server-side Lua. No packet format changes.

### Pass 2: Simplicity

**Is this the simplest approach?**

Yes. Considered and rejected alternatives:

1. **C++ route for !help without target:** Would require modifying
   `ChannelMessageReceived()` to detect `!help` in the say channel and
   dispatch it specially. This is more invasive than a Lua player event_say
   handler and touches C++ code that doesn't need to change.

2. **New "hold" mode in companion_modes:** The PRD asked whether !hold should
   introduce a third mode. Answer: No. "hold" is just "guard" + passive.
   Tracking it as "guard" in companion_modes with the stance being passive
   is sufficient. The combination is the hold state; no new mode value needed.

3. **SetTarget(nil) for !tome:** Would require verifying luabind nil
   conversion behavior. WipeHateList() is safer, already used in the codebase,
   and achieves the same result (companion stops attacking) without relying
   on nil parameter handling.

4. **Separate test framework:** The existing mock-based test pattern in
   `test_companion_cmd_assist.lua` works well. No need for a test framework.

**Config-expert confirmation:** No existing rules can achieve these changes.
All changes require Lua code, not configuration.

### Pass 3: Antagonistic

**What could go wrong?**

1. **Edge case: !hold then !tome** — Player holds a companion, then tomes it.
   !tome moves the companion to the player, wipes hate list, sets follow mode,
   breaks guard. Companion is now following, passive (from !hold), with empty
   hate list. Correct behavior per PRD: "!tome... Stance remains passive.
   Mode changes to follow."

2. **Edge case: !hold then !assist** — Player holds a companion, then assists.
   cmd_assist auto-switches passive to balanced, sets target, adds to hate
   list. The new guard-break in cmd_assist sets follow mode. Companion is now
   following, balanced, engaging target. Correct per PRD.

3. **Edge case: !hold then !balanced** — Player holds then changes stance to
   balanced. Companion stays at guard position (companion_modes still "guard")
   but now fights enemies that come to it. Correct per PRD: "changes stance
   to balanced, stays at guard position, will now fight nearby enemies."

4. **Edge case: !hold on dead companion** — Dead check returns early with
   "[Name] is dead and cannot hold position." Correct per PRD.

5. **Edge case: !hold when already holding** — If companion_modes is "guard"
   AND stance is passive, respond "Already holding position." No state change.
   Correct per PRD.

6. **Edge case: !help with no companions in zone** — Player types !help but
   has no companions. The player-level event_say intercepts it and displays
   help via client:Message(). No companion needed. Correct per PRD.

7. **Edge case: !help targeting non-companion NPC** — Player targets a
   regular NPC and types !help. The player-level event_say fires first
   (before NPC dispatch) and displays help. The NPC dispatch also fires
   but since the NPC is not a companion, global_npc.lua's IsCompanion()
   check fails and it falls through to LLM. The "!help" text reaches the
   LLM — but this is harmless as the player already got their help output.
   To prevent the LLM from responding to "!help", the lua-expert should
   add a check in the player event_say to consume the message (return a
   non-zero value from event_say to indicate handling).

8. **Race condition: @all !help deduplication** — The data bucket lock
   (help_lock_key with 1-second TTL) already handles this. When !help is
   dispatched via @all, the first companion claims the lock. The player-
   level handler should use the same lock key.

9. **Edge case: !tome when companion is NOT in combat** — cmd_tome currently
   checks dead and distance. WipeHateList on a companion with empty hate
   list is a no-op. SetGuardMode(false) when not in guard is a no-op.
   Safe.

10. **Exploit potential: None.** !hold reduces combat effectiveness (passive
    + stationary). !tome clearing adds no new capability. !help is
    information display.

### Pass 4: Integration

**How do the pieces fit together?**

Implementation order is critical:
1. Tasks 1-2 (hold, tome) are independent and can be done first
2. Task 3 (help reformat) depends on Task 1 because !hold must be in the
   COMMANDS table for the help output to include it
3. Task 4 (help standalone) depends on Task 3 for shared formatting logic
4. Task 5 (docs) depends on Tasks 1-3 for accurate command descriptions
5. Task 6 (tests) depends on Tasks 1-4 for testable implementations

All tasks are assigned to one agent (lua-expert), so coordination is
implicit. The dependency chain is linear and natural.

**Cross-file dependencies:**
- `companion.lua` exports `cmd_help_standalone` (new) for `global_player.lua`
- `global_player.lua` requires `companion` module (already on Lua path)
- No other file dependencies

**Reload behavior:** After changes, `#rq` (reload quest) picks up all Lua
changes without server restart. No build cycle needed.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| lua-expert | 1, 2, 3, 4, 5, 6 | All changes are Lua scripts and documentation. Single agent avoids coordination overhead. |

## Open Questions Resolved

### Q1: !help without target routing

**Answer:** Use Player EVENT_SAY in `global_player.lua`. This fires at
client.cpp:1609 before NPC EVENT_SAY at line 1633, regardless of whether
the player has a target. No C++ changes needed.

**Rationale:** Verified that `global_player.lua` has no existing `event_say`
handler. The player event_say mechanism is standard EQEmu functionality used
by many zones for proximity-independent player interactions.

### Q2: !hold mode tracking

**Answer:** Track as "guard" in `companion_modes` (existing table). The "hold"
state is the combination of `companion_modes[id] == "guard"` AND
`npc:GetStance() == 0`. No new mode value needed.

**Rationale:** Introducing a third mode value would require changes to
`cmd_status` display logic and potentially the C++ `SetGuardMode` binding.
The existing two-mode system (follow/guard) combined with stance is sufficient
to express all states.

### Q3: !tome guard-break behavior

**Answer:** Yes, !tome should break guard mode and set follow mode. When a
player calls a companion to their position, the companion should follow from
that point — not return to the original guard position on the next AI tick.

**Rationale:** Consistent with cmd_recall behavior (line 554:
`companion_modes[npc:GetID()] = "follow"`). The companion is now AT the player,
so guarding the old position is not useful.

## Validation Plan

The game-tester should verify the following after implementation:

**REQ-1: !help Rework**
- [ ] `/say !help` with NO target: full command list appears in chat
- [ ] `/say !help` targeting a companion: identical output appears
- [ ] `/say !help` targeting a non-companion NPC: command list appears (not error)
- [ ] Commands are alphabetically sorted within each category
- [ ] Each command on its own line with dash-separated description
- [ ] !hold appears under Movement category
- [ ] `!help stance` / `movement` / `combat` / `buffs` / `equipment` / `information` / `control` all work
- [ ] `@all !help` via gsay: only one response (deduplication works)

**REQ-2: !hold Command**
- [ ] Target companion, `/say !hold`: companion says "Holding position.", stops moving, enters passive
- [ ] Held companion does NOT engage attacking enemies
- [ ] Held companion does NOT move from position
- [ ] `!follow` on held companion: resumes following, stance stays passive
- [ ] `!assist` on held companion: switches to balanced, engages target, resumes following
- [ ] `!balanced` on held companion: changes stance, stays at guard position
- [ ] `!aggressive` on held companion: changes stance, stays at guard position
- [ ] `!hold` on already-held companion: responds "Already holding position."
- [ ] `!hold` on dead companion: responds "[Name] is dead and cannot hold position."
- [ ] `@all !hold` via gsay: all companions hold

**REQ-3: !tome Update**
- [ ] `!tome` on companion in combat: moves to player, stops attacking, stance unchanged
- [ ] `!tome` on companion in guard mode: moves to player, switches to follow mode
- [ ] `!tome` on companion already nearby (<50 units): "already nearby" message, no changes
- [ ] `!tome` on dead companion: "[Name] is dead and cannot move."
- [ ] Mobs that were fighting companion before !tome continue pursuing
- [ ] `@all !tome`: all companions move, all stop attacking

**REQ-4: Documentation**
- [ ] companion-commands-reference.md lists all 24 commands with !-prefix syntax
- [ ] No references to old free-text commands (leave, goodbye, stay, stance, etc.)
- [ ] Correct handler function name (dispatch_prefix_command, not handle_command)
- [ ] Owner-only vs read-only access noted for each command

**REQ-5: Tests**
- [ ] All test files run successfully under `luajit`
- [ ] Test coverage includes all acceptance criteria edge cases

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
