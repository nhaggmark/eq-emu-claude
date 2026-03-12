# companion-group-debugging — Architecture & Implementation Plan

> **Feature branch:** `bugfix/companion-group-debugging`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-03-11
> **Status:** Approved

---

## Executive Summary

Two bugs found during in-game testing of companion group commands. Both stem
from a single root cause: the Lua event dispatch system wraps Companion NPCs
as `Lua_NPC` objects, but the companion command functions call methods that
only exist on `Lua_Companion`. BUG-021 (`!assist` stack trace) crashes because
`GetStance()` is Companion-only. BUG-022 (`!tome` no movement) succeeds
without error but `RunTo()` is immediately overridden by the follow-target
AI on the next process tick. Both fixes are Lua-only — no C++ or database
changes required.

## Existing System Analysis

### Current State

The companion command system works as follows:

1. **C++ dispatch** (`client.cpp` ~line 1836-1858): When a player sends
   `/gsay @all !command`, C++ parses `@all`, resolves companion targets,
   strips the `@all` prefix, and calls `parse->EventBotMercNPC(EVENT_SAY,
   companion, this, payload, language)` for each matched companion.

2. **Event routing** (`quest_parser_collection.cpp` line 1859): `EventBotMercNPC`
   checks `e->IsNPC()` (true for Companion, which inherits NPC) and calls
   `EventNPC(event_id, e->CastToNPC(), ...)`. This is the critical step —
   **the Companion is cast to NPC** before reaching Lua.

3. **Global NPC handler** (`global_npc.lua` lines 11-16): The `event_say`
   handler checks `e.self:IsCompanion()` (works because `IsCompanion` is on
   `Lua_Entity`), sees the `!` prefix, and calls
   `companion_lib.dispatch_prefix_command(e.self, e.other, e.message)`.

4. **Command dispatch** (`companion.lua` lines 141-170): `dispatch_prefix_command`
   strips the `!` prefix, looks up the command in the `COMMANDS` table, and
   calls the handler function with `(npc, client, args)`.

5. **The problem**: The `npc` parameter is a `Lua_NPC` object (from `e.self`).
   Many handler functions call methods that only exist on `Lua_Companion`:
   `GetStance()`, `SetStance()`, `SetGuardMode()`, `GetCompanionType()`,
   `GetCompanionID()`, `GetCombatRole()`. These are nil on `Lua_NPC`,
   causing "attempt to call a nil value" errors.

### Method Availability Matrix

| Method | Lua_Mob | Lua_NPC | Lua_Companion | Used In |
|--------|---------|---------|---------------|---------|
| `GetCleanName()` | Yes | inherited | inherited | cmd_tome, cmd_assist, many |
| `GetHP()` | Yes | inherited | inherited | cmd_tome, cmd_assist, many |
| `CalculateDistance()` | Yes | inherited | inherited | cmd_tome, cmd_recall |
| `RunTo()` | Yes | inherited | inherited | cmd_tome, cmd_flee |
| `IsAttackAllowed()` | Yes | inherited | inherited | cmd_assist, cmd_target |
| `SetTarget()` | Yes | inherited | inherited | cmd_assist, cmd_target |
| `AddToHateList()` | Yes | inherited | inherited | cmd_assist, cmd_target |
| `IsCompanion()` | Yes (Entity) | inherited | inherited | global_npc.lua |
| `GetOwnerCharacterID()` | — | Yes | inherited | dispatch_prefix_command |
| `GetStance()` | — | — | **Yes** | cmd_assist, cmd_flee, cmd_status |
| `SetStance()` | — | — | **Yes** | cmd_passive, cmd_balanced, cmd_aggressive, cmd_assist, cmd_flee |
| `SetGuardMode()` | — | — | **Yes** | cmd_follow, cmd_guard, cmd_flee |
| `GetCompanionType()` | — | — | **Yes** | cmd_balanced, cmd_status |
| `GetCompanionID()` | — | — | **Yes** | cmd_recall |
| `GetCombatRole()` | — | — | **Yes** | cmd_stats |

### Gap Analysis

**BUG-021 (`!assist` stack trace):** `cmd_assist` calls `npc:GetStance()` at
line 924 to check if the companion is in passive stance (and should auto-switch
to balanced). Since `GetStance()` is nil on `Lua_NPC`, this produces:
```
attempt to call a nil value (method 'GetStance')
```
The stack trace propagates up through `dispatch_prefix_command` → `event_say`.

**BUG-022 (`!tome` no effect):** `cmd_tome` calls only `Lua_Mob`-level methods
(`GetCleanName`, `GetHP`, `CalculateDistance`, `RunTo`), so it does NOT produce
a stack trace. However, `RunTo()` is immediately overridden by the companion's
follow-target AI. Companions have `SetFollowID(owner->GetID())` set at group
join time. On every `AI_Process` tick (many times per second), the follow logic
in `mob_ai.cpp` (line 1494-1530) recalculates the path to the owner's formation
position. This overwrites any `RunTo` destination set by Lua within one tick.
The companion_say message ("moves toward you") likely fires but the movement
is instantly cancelled, making it appear that nothing happened.

## Technical Approach

### Architecture Decision

Both bugs are fixed entirely in Lua. No C++ or database changes.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `companion.lua` | Lua fix | Add nil-guards for Companion-only methods + fix tome movement |

### Fix Strategy

The fixes use a two-part approach:

**Part A: Nil-guard pattern for Companion-only methods**

For every call to a Companion-only method (`GetStance`, `SetStance`,
`SetGuardMode`, `GetCompanionType`, `GetCompanionID`, `GetCombatRole`),
wrap with nil-guard:

```lua
-- Pattern: method && method() or default_value
local stance = npc.GetStance and npc:GetStance() or 1  -- default balanced
```

Or for void methods:
```lua
if npc.SetStance then npc:SetStance(1) end
```

This pattern is already documented in MEMORY.md as the workaround for the
luabind inheritance issue.

**Part B: Fix `cmd_tome` movement override**

`RunTo` is overridden by the follow AI. Two options:

1. **Option A (preferred): Use `GMMove` for instant teleport.** The `!tome`
   command is semantically "come to me now" — teleporting is the most reliable
   approach. `GMMove(x, y, z, heading)` instantly repositions the NPC without
   going through the movement manager, so the follow AI doesn't interfere.
   The companion then resumes formation follow normally.

2. **Option B: Temporarily clear follow ID, RunTo, then restore.** This would
   require clearing `SetFollowID(0)`, calling `RunTo`, then setting a timer to
   restore follow. More complex and fragile.

Option A is preferred because `cmd_recall` already uses `GMMove` for the same
purpose (line 551), establishing precedent. The difference between `!tome` and
`!recall` is distance threshold and cooldown — `!tome` has no cooldown and a
50-unit minimum (vs `!recall`'s 200-unit minimum and cooldown).

### Code Changes

#### Lua/Script Changes

**File:** `akk-stack/server/quests/lua_modules/companion.lua`

**BUG-021 Fix — `cmd_assist` (line 897-938):**

Replace direct `GetStance()` / `SetStance()` calls with nil-guarded versions:

```lua
function companion.cmd_assist(npc, client, args)
    local name = npc:GetCleanName()

    if npc:GetHP() <= 0 then
        companion_say(npc, client, name .. " is dead and cannot fight.")
        return
    end

    local player_target = client:GetTarget()
    if not player_target or not player_target.valid then
        companion_say(npc, client, name .. " has no target to assist with. Target a mob first.")
        return
    end

    if player_target == npc then
        companion_say(npc, client, name .. " will not attack themselves.")
        return
    end
    if not npc:IsAttackAllowed(player_target) then
        companion_say(npc, client, name .. " will not attack a friendly target.")
        return
    end

    -- Auto-switch passive -> balanced before engaging (nil-guard for Companion-only method)
    local switched_stance = false
    local stance = npc.GetStance and npc:GetStance() or 1  -- default balanced if method unavailable
    if stance == 0 then
        if npc.SetStance then npc:SetStance(1) end
        switched_stance = true
    end

    npc:SetTarget(player_target)
    npc:AddToHateList(player_target, 1, 0, false, false, false)

    local target_name = player_target:GetCleanName()
    if switched_stance then
        companion_say(npc, client, name .. " switches to balanced stance and assists against " .. target_name .. "!")
    else
        companion_say(npc, client, name .. " assists against " .. target_name .. "!")
    end
end
```

**BUG-022 Fix — `cmd_tome` (line 840-853):**

Replace `RunTo` with `GMMove` to prevent follow-AI override:

```lua
function companion.cmd_tome(npc, client, args)
    local name = npc:GetCleanName()
    if npc:GetHP() <= 0 then
        companion_say(npc, client, name .. " is dead and cannot move.")
        return
    end
    local dist = npc:CalculateDistance(client)
    if dist < 50 then
        companion_say(npc, client, name .. " is already nearby.")
        return
    end
    -- Use GMMove for instant repositioning. RunTo is overridden by the
    -- follow-target AI on the next process tick, making it ineffective.
    -- GMMove sets position directly, then the follow AI resumes formation
    -- naturally. This matches cmd_recall's approach (line 551).
    npc:GMMove(client:GetX(), client:GetY(), client:GetZ(), client:GetHeading())
    companion_say(npc, client, name .. " moves to your side.")
end
```

**Additional nil-guard fixes needed across the file:**

The lua-expert should also apply nil-guards to ALL other commands that use
Companion-only methods. Here is the complete list of affected lines:

| Line | Function | Method | Fix |
|------|----------|--------|-----|
| 490 | `cmd_passive` | `SetStance(0)` | `if npc.SetStance then npc:SetStance(0) end` |
| 491 | `cmd_passive` | (implicit) `WipeHateList` is on Lua_Mob — OK | No change |
| 498 | `cmd_balanced` | `SetStance(1)` | `if npc.SetStance then npc:SetStance(1) end` |
| 499 | `cmd_balanced` | `GetCompanionType()` | `npc.GetCompanionType and npc:GetCompanionType() or 0` |
| 508 | `cmd_aggressive` | `SetStance(2)` | `if npc.SetStance then npc:SetStance(2) end` |
| 518 | `cmd_follow` | `SetGuardMode(false)` | `if npc.SetGuardMode then npc:SetGuardMode(false) end` |
| 525 | `cmd_guard` | `SetGuardMode(true)` | `if npc.SetGuardMode then npc:SetGuardMode(true) end` |
| 534 | `cmd_recall` | `GetCompanionID()` | `npc.GetCompanionID and npc:GetCompanionID() or 0` |
| 642 | `cmd_status` | `GetStance()` | `npc.GetStance and npc:GetStance() or 1` |
| 651 | `cmd_status` | `GetCompanionType()` | `npc.GetCompanionType and npc:GetCompanionType() or 0` |
| 700 | `cmd_stats` | `GetCombatRole()` | `npc.GetCombatRole and npc:GetCombatRole() or 0` |
| 864 | `cmd_flee` | `GetStance()` | `npc.GetStance and npc:GetStance() or 1` |
| 867 | `cmd_flee` | `SetStance(0)` | `if npc.SetStance then npc:SetStance(0) end` |
| 868 | `cmd_flee` | `SetGuardMode(false)` | `if npc.SetGuardMode then npc:SetGuardMode(false) end` |
| 870 | `cmd_flee` | `RunTo` (Lua_Mob — OK but same override issue as tome) | Replace with `GMMove` |
| 889 | `cmd_target` | `GetStance()` | `npc.GetStance and npc:GetStance() or 1` |
| 924-925 | `cmd_assist` | `GetStance()`, `SetStance(1)` | Nil-guard as shown above |

#### C++ Changes
_None required._

#### Database Changes
_None required._

#### Configuration Changes
_None required._

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Fix BUG-021: Add nil-guards for `GetStance`/`SetStance` in `cmd_assist` | lua-expert | — | Small |
| 2 | Fix BUG-022: Replace `RunTo` with `GMMove` in `cmd_tome` | lua-expert | — | Small |
| 3 | Apply nil-guards to ALL companion commands that use Companion-only methods | lua-expert | — | Medium |
| 4 | Fix `cmd_flee` to use `GMMove` instead of `RunTo` (same override issue as tome) | lua-expert | — | Small |

Tasks 1-4 are all in the same file and should be done as a single pass by
lua-expert. They are listed separately for tracking but should be committed
together.

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Nil-guard defaults produce unexpected behavior | Low | Medium | Defaults match expected state: stance=1 (balanced), type=0 (companion), role=0 (melee tank). These are reasonable fallbacks. |
| GMMove teleport looks visually jarring | Low | Low | Same approach used by `!recall`. Players expect instant movement for "come to me" commands. |
| Other Companion-only methods not caught | Low | Medium | Comprehensive grep performed; all usages listed in the fix table above. |

### Compatibility Risks

No existing behavior changes. The nil-guards make commands that previously
crashed now work. The `GMMove` change makes `!tome` actually move companions
rather than silently failing.

### Performance Risks

None. The nil-guard check (`npc.GetStance and ...`) is a trivial Lua table
lookup. `GMMove` is lighter than `RunTo` (no pathfinding).

## Review Passes

### Pass 1: Feasibility
Both fixes are proven patterns in this codebase:
- **Nil-guard**: Already documented in MEMORY.md under "Luabind Inheritance Issue"
  with the exact pattern: `obj.Method and obj:Method() or default`.
- **GMMove**: Already used in `cmd_recall` (line 551) for the same purpose.
  Verified `GMMove(x, y, z, heading)` exists on `Lua_Mob` (inherited by `Lua_NPC`).

### Pass 2: Simplicity
This is the simplest possible fix. The alternative (fixing the C++ event dispatch
to pass `Lua_Companion` instead of `Lua_NPC`) would require changes to
`quest_parser_collection.cpp`, `lua_parser.cpp`, and `lua_parser_events.cpp` —
a much larger and riskier change for the same result. The nil-guard approach
works with the existing architecture.

### Pass 3: Antagonistic
- **Edge case: What if `GetStance` returns nil even on a real Companion?** This
  cannot happen — if the method exists (truthy table lookup), it returns uint8.
  The nil-guard only fires when the method itself is absent.
- **Edge case: GMMove to a position the NPC can't reach?** GMMove bypasses
  pathfinding, so the NPC appears at the destination regardless of geometry.
  This is acceptable for a "come to me" command within the same zone.
- **Edge case: cmd_flee uses RunTo (line 870) with the same override problem.**
  Yes — this is the same bug as BUG-022. Task 4 addresses it.

### Pass 4: Integration
All four tasks modify the same file (`companion.lua`) and can be done in a
single editing pass. No dependencies between tasks. No build step required
(Lua scripts are hot-reloaded with `#reloadquest`). The game-tester should
verify all affected commands after the fix: `!assist`, `!tome`, `!passive`,
`!balanced`, `!aggressive`, `!follow`, `!guard`, `!flee`, `!recall`,
`!target`, `!status`, `!stats`.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| lua-expert | Tasks 1-4 | All fixes are Lua script changes in companion.lua |

## Validation Plan

- [ ] `/gsay @all !assist` with a mob targeted: all companions engage the target, no stack trace
- [ ] `/gsay @all !assist` without a target: informative error message, no crash
- [ ] `/gsay @all !tome` when companions are >50 units away: companions appear at player location
- [ ] `/gsay @all !tome` when companions are <50 units away: "already nearby" message
- [ ] `/gsay @all !passive` : companions enter passive stance, stop fighting
- [ ] `/gsay @all !balanced` : companions enter balanced stance
- [ ] `/gsay @all !aggressive` : companions enter aggressive stance
- [ ] `/gsay @all !follow` : companions resume following (no stack trace)
- [ ] `/gsay @all !guard` : companions hold position (no stack trace)
- [ ] `/gsay @all !flee` : companions disengage and appear at player location
- [ ] `/gsay @all !recall` : companions teleport to player (with cooldown)
- [ ] `/gsay @all !target` with mob targeted: companions face/engage target
- [ ] `/gsay @all !status` : shows companion info without crash
- [ ] `/gsay @all !stats` : shows combat stats without crash

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
