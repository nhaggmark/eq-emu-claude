# Recruited NPC Controls — Architecture & Implementation Plan

> **Feature branch:** `feature/recruited-npc-controls`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-02-28
> **Status:** In Review

---

## Executive Summary

Replace the keyword-based companion management system with a `!` prefix
command dispatcher. All `/say` messages to companions starting with `!` are
parsed as commands; everything else flows to the LLM for natural
conversation. This eliminates false triggers from common words like "follow",
"guard", "leave", and "farewell" that currently intercept player dialogue.
The feature adds five new commands (`!recall`, `!target`, `!assist`,
`!status`, `!help`) and restructures the existing command flow. The
implementation is **pure Lua** with one new C++ rule value for recall
cooldown. No database schema changes, no new opcodes.

## Existing System Analysis

### Current State

**Message routing pipeline:**
1. Client sends `/say` text via `OP_ChannelMessage` (UDP)
2. `client.cpp:ChannelMessageReceived()` checks for `#` (GM) and `^` (bot)
   prefixes — both handled and returned before reaching quest scripts
3. All other `/say` text fires `EVENT_SAY` on the target NPC's quest script
4. If no per-NPC or per-zone script exists, `global_npc.lua:event_say()`
   handles the message

**Current companion command flow** (`global_npc.lua` lines 9-13):
```lua
if e.self:IsCompanion() and companion_lib.is_management_keyword(e.message) then
    companion_lib.handle_command(e.self, e.other, e.message)
    return
end
```
- `is_management_keyword()` does substring matching against 17 keywords
  (dismiss, leave, goodbye, farewell, release, passive, balanced, aggressive,
  stance, follow, guard, stay, show equipment, show gear, inventory,
  give me your, give me everything)
- `handle_command()` dispatches to stance/movement/equipment handlers via
  chained `if/elseif` blocks (`companion.lua` lines 408-447)
- Anything not matching a keyword falls through to the LLM bridge

**Existing Lua bindings on `Lua_Companion`** (from `lua_companion.h/cpp`):
- `SetStance(int)` — 0=passive, 1=balanced, 2=aggressive
- `SetGuardMode(bool)` — true=hold position, false=resume following
- `SetFollowDistance(int)`, `SetFollowID(int)`, `SetFollowCanRun(bool)`
- `Dismiss(bool)` — true=voluntary, false=forced
- `ShowEquipment(client)`, `GiveSlot(client, slot_name)`, `GiveAll(client)`
- `GetStance()`, `GetCompanionType()`, `GetOwner()`, `GetCompanionID()`
- `GetCompanionXP()`, `GetRecruitedLevel()`, `GetOwnerCharacterID()`

**Existing Lua bindings on `Lua_Mob`** (inherited by Companion):
- `SetTarget(Lua_Mob)` — set target
- `GetTarget()` — get current target
- `AddToHateList(Lua_Mob, hate, damage)` — add entity to hate list
- `GMMove(x, y, z, heading)` — teleport to coordinates
- `CalculateDistance(Lua_Mob)` — distance to another mob
- `GetHP()`, `GetMaxHP()`, `GetMana()`, `GetMaxMana()`
- `GetName()`, `GetCleanName()`, `GetLevel()`, `GetClass()`, `GetClassName()`
- `IsEngaged()`, `GetHateListCount()`
- `GetX()`, `GetY()`, `GetZ()`, `GetHeading()`

**Binding gap: `GetFollowID()`**
`GetFollowID()` is bound on `Lua_NPC` but NOT on `Lua_Companion` (which
inherits `Lua_Mob`, not `Lua_NPC`). This affects `!status` guard/follow mode
detection. Solution: track mode in a Lua-level table keyed by companion
entity ID, set by `cmd_guard` and `cmd_follow`. No C++ change needed.

**Existing rule values** (`common/ruletypes.h` lines 1181-1201):
21 companion rules exist. None relate to command prefix or recall. The
`Companions:RecruitCooldownS` rule (default 900) provides naming precedent
for `RecallCooldownS`.

**Key files involved:**
- `akk-stack/server/quests/global/global_npc.lua` — event_say entry point
- `akk-stack/server/quests/lua_modules/companion.lua` — command dispatch
- `akk-stack/server/quests/lua_modules/companion_culture.lua` — LLM context
- `eqemu/zone/lua_companion.h/cpp` — Lua bindings for Companion class
- `eqemu/zone/companion.h/cpp` — Companion C++ class
- `eqemu/common/ruletypes.h` — rule definitions

### Gap Analysis

| PRD Requirement | Current State | Gap |
|-----------------|---------------|-----|
| `!` prefix command dispatch | Keyword substring matching | Need prefix parser in Lua |
| Unprefixed text → LLM | Messages with keywords are intercepted | Remove keyword interception |
| `!help` command list | No help system | New help text handler |
| `!status` command | No status display | New status formatter |
| `!recall` teleport | No recall capability | New recall handler + cooldown |
| `!target` set target | No target command | New target handler |
| `!assist` combat assist | No assist command | New assist handler |
| `!equip` trade window | No programmatic trade | **Deferred** (see below) |
| Configurable recall cooldown | N/A | 1 new rule value |
| Guard/follow mode tracking | Not available in Lua | Lua-level mode table |

## Technical Approach

### Architecture Decision

This feature is **Lua quest script changes** plus one new rule value in C++.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| Rule value (`ruletypes.h`) | Add 1 rule: `RecallCooldownS` | Recall cooldown is a tuning parameter operators may want to adjust. Follows existing `RecruitCooldownS` / `DeathDespawnS` naming. |
| Lua module (`companion.lua`) | Major refactor | Replace keyword matching with prefix-based command table dispatch. Add 5 new command handlers. Per config-expert: prefix `!` and recall min distance (200) are Lua constants, not rules. |
| Lua global script (`global_npc.lua`) | Minor edit | Change companion interception from keyword check to prefix check. ~6 lines. |
| C++ source | **None** (beyond the rule) | All required Lua bindings exist. No new methods, classes, or opcodes. |
| Database | **None** | No schema changes. Data buckets for cooldown. |
| Config files | **None** | No eqemu_config.json changes. |

**Why only 1 rule (not 3 as PRD suggested):**
Per config-expert recommendation:
- `CommandPrefix`: The `!` character is a finalized design decision
  (status.md Decision Log #1). A Lua constant is cleaner than a rule that
  adds a DB lookup on every `/say` event. If an operator wants to change it,
  they edit one line in `companion.lua`.
- `RecallMinDistance`: 200 units is a game design constraint preventing
  combat positioning abuse. Making it configurable undermines the balance
  rationale. Hardcode in Lua with a descriptive comment.
- `RecallCooldownS`: Legitimate tuning parameter. Operators may want shorter
  cooldowns for casual servers or longer ones for hardcore. Create as rule.

**Why no C++ logic changes:**
Every Lua API binding needed for the new commands already exists:

| New Command | Required Lua API | Binding Location |
|-------------|-----------------|------------------|
| `!recall` | `GMMove()`, `CalculateDistance()` | `lua_mob.h:82-84, 297-298` |
| `!target` | `SetTarget()`, `AddToHateList()` | `lua_mob.h:130, 245-250` |
| `!assist` | `SetTarget()`, `AddToHateList()` | Same as above |
| `!status` | `GetHP()`, `GetMaxHP()`, `GetMana()`, `GetLevel()`, `GetClassName()`, `GetStance()`, `GetCompanionType()` | `lua_mob.h`, `lua_companion.h` |
| `!help` | `Client:Message()` | `lua_client.h` |

### Trade Window Assessment (`!equip` — Deferred)

The Titanium client's trade flow is always client-initiated. The player
right-clicks an NPC, which sends `OP_TradeRequest` to the server. The server
responds with `OP_TradeRequestAck`. There is no server-side API to
programmatically open a trade window — the client must initiate. The
`Lua_Client` class only exposes `ResetTrade()`, not a trade-initiation
method.

Adding server-initiated trades would require:
1. New C++ method to fabricate and send `OP_TradeRequestAck` unsolicited
2. New Lua binding to expose it
3. Testing Titanium client behavior with unsolicited trade acknowledgment

**Decision: Defer `!equip` to a follow-up feature.** The PRD anticipated
this: "If trade window support requires significant C++ work, `!equip` can
be deferred." The `!equip` command will display instructions directing the
player to right-click the companion to trade normally.

### Data Model

No database schema changes. Recall cooldown uses data buckets:
```
Key:    companion_recall_cd_{companion_id}_{char_id}
Value:  "1"
TTL:    Companions:RecallCooldownS seconds (default 30)
```

Guard/follow mode tracking uses a Lua module-level table:
```lua
-- Module-level state (reset on quest reload or zone restart)
local companion_modes = {}  -- [entity_id] = "follow" | "guard"
```
Set by `cmd_guard` and `cmd_follow`. Read by `cmd_status`. Default
assumption is "follow" if no entry exists (companions start in follow mode).

### Code Changes

#### C++ Changes

**File: `eqemu/common/ruletypes.h`** — Add 1 rule at end of Companions
category (after line 1201):

```cpp
RULE_INT(Companions, RecallCooldownS, 30, "Cooldown in seconds between companion recall teleports")
```

One line. That is the entirety of C++ changes.

#### Lua/Script Changes

**File: `akk-stack/server/quests/global/global_npc.lua`**

Replace the companion keyword interception block (lines 9-13) with:

```lua
if e.self:IsCompanion() then
    if e.message:sub(1, 1) == "!" then
        companion_lib.dispatch_prefix_command(e.self, e.other, e.message)
        return
    end
    -- Non-prefixed: fall through to LLM block below for conversation
end
```

The recruitment keyword check (lines 16-19) remains unchanged — it only
fires for non-companion NPCs.

**File: `akk-stack/server/quests/lua_modules/companion.lua`**

Major refactoring. Changes organized by section:

**1. Remove old keyword system:**
- Delete `MANAGE_KEYWORDS` table (lines 34-40)
- Delete `is_management_keyword()` function (lines 93-101)
- Delete `handle_command()` function (lines 408-447)

**2. Add constants:**
```lua
-- Command prefix (finalized design decision — not a rule)
local COMMAND_PREFIX = "!"

-- Recall minimum distance (game design constraint — not configurable)
local RECALL_MIN_DISTANCE = 200

-- Module-level guard/follow mode tracking
-- Keys are entity IDs, values are "follow" or "guard"
-- Reset on quest reload; default assumption is "follow"
local companion_modes = {}
```

**3. Add command table:**
```lua
local COMMANDS = {
    passive    = { handler = "cmd_passive",    category = "stance" },
    balanced   = { handler = "cmd_balanced",   category = "stance" },
    aggressive = { handler = "cmd_aggressive", category = "stance" },
    follow     = { handler = "cmd_follow",     category = "movement" },
    guard      = { handler = "cmd_guard",      category = "movement" },
    recall     = { handler = "cmd_recall",     category = "movement" },
    equipment  = { handler = "cmd_equipment",  category = "equipment" },
    unequip    = { handler = "cmd_unequip",    category = "equipment" },
    equip      = { handler = "cmd_equip",      category = "equipment" },
    status     = { handler = "cmd_status",     category = "information" },
    help       = { handler = "cmd_help",       category = "information" },
    target     = { handler = "cmd_target",     category = "combat" },
    assist     = { handler = "cmd_assist",     category = "combat" },
    dismiss    = { handler = "cmd_dismiss",    category = "control" },
}
```

**4. Add dispatch function:**
```lua
function companion.dispatch_prefix_command(npc, client, message)
    -- Ownership check
    if npc:GetOwnerCharacterID() ~= client:CharacterID() then
        client:Message(15, "That is not your companion.")
        return
    end

    -- Strip prefix and parse command + args
    local body = message:sub(2):gsub("^%s+", "")
    if body == "" then
        companion.cmd_help(npc, client, "")
        return
    end

    local cmd, args = body:match("^(%S+)%s*(.*)")
    cmd = cmd:lower()

    local entry = COMMANDS[cmd]
    if entry then
        companion[entry.handler](npc, client, args or "")
    else
        client:Message(15, "Unknown command: !" .. cmd ..
                       ". Type !help for available commands.")
    end
end
```

**5. Refactor existing handlers with lore-corrected responses:**

```lua
function companion.cmd_passive(npc, client, args)
    npc:SetStance(0)
    npc:Say("I will stand down.")
end

function companion.cmd_balanced(npc, client, args)
    npc:SetStance(1)
    if npc:GetCompanionType() == 0 then  -- loyal companion
        npc:Say("I will fight at your side.")
    else  -- mercenary
        npc:Say("Understood.")
    end
end

function companion.cmd_aggressive(npc, client, args)
    npc:SetStance(2)
    npc:Say("Understood. I will fight aggressively.")
end

function companion.cmd_follow(npc, client, args)
    npc:SetGuardMode(false)
    companion_modes[npc:GetID()] = "follow"
    npc:Say("I will follow.")
end

function companion.cmd_guard(npc, client, args)
    npc:SetGuardMode(true)
    companion_modes[npc:GetID()] = "guard"
    npc:Say("I will hold here.")
end

function companion.cmd_dismiss(npc, client, args)
    npc:Say("Farewell.")
    npc:Dismiss(true)
end

function companion.cmd_equipment(npc, client, args)
    npc:ShowEquipment(client)
end

function companion.cmd_unequip(npc, client, args)
    local slot_name = args:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if slot_name == "" then
        client:Message(15, "Usage: !unequip <slot> or !unequip all")
        client:Message(15, "Valid slots: primary, secondary, head, chest, " ..
                           "arms, wrist1, wrist2, hands, legs, feet, " ..
                           "charm, ear1, ear2, face, neck, shoulder, " ..
                           "back, finger1, finger2, range, waist, ammo")
        return
    end
    if slot_name == "all" then
        npc:Say("As you wish.")
        npc:GiveAll(client)
    else
        npc:GiveSlot(client, slot_name)
    end
end
```

**6. Add new command handlers:**

```lua
function companion.cmd_recall(npc, client, args)
    local cooldown_s = tonumber(eq.get_rule("Companions:RecallCooldownS")) or 30
    local cd_key = "companion_recall_cd_" ..
                   npc:GetCompanionID() .. "_" .. client:CharacterID()

    -- Cooldown check
    local on_cd = eq.get_data(cd_key)
    if on_cd and on_cd ~= "" then
        client:Message(15, "Recall is on cooldown.")
        return
    end

    -- Distance check
    local dist = npc:CalculateDistance(client)
    if dist < RECALL_MIN_DISTANCE then
        client:Message(15, "Your companion is already nearby.")
        return
    end

    -- Teleport to player position
    npc:GMMove(client:GetX(), client:GetY(), client:GetZ(), client:GetHeading())
    companion_modes[npc:GetID()] = "follow"
    npc:Say("I am here.")

    -- Set cooldown via data bucket
    eq.set_data(cd_key, "1", tostring(cooldown_s))
end

function companion.cmd_target(npc, client, args)
    local player_target = client:GetTarget()
    if not player_target or not player_target.valid then
        client:Message(15, "You must target an enemy first.")
        return
    end
    npc:SetTarget(player_target)
    if npc:GetStance() ~= 0 then  -- not passive: engage
        npc:AddToHateList(player_target, 1, 0, false, false, false)
    end
    npc:Say("I see your target.")
end

function companion.cmd_assist(npc, client, args)
    local player_target = client:GetTarget()
    if not player_target or not player_target.valid then
        client:Message(15, "You must target an enemy first.")
        return
    end
    npc:SetTarget(player_target)
    if npc:GetStance() ~= 0 then
        npc:AddToHateList(player_target, 1, 0, false, false, false)
    end
    npc:Say("I will assist.")
end

function companion.cmd_status(npc, client, args)
    local stance_names = {
        [0] = "Passive", [1] = "Balanced", [2] = "Aggressive"
    }
    local type_names = {
        [0] = "Companion", [1] = "Mercenary"
    }
    local mode = companion_modes[npc:GetID()] or "follow"
    mode = mode:sub(1,1):upper() .. mode:sub(2)

    client:Message(15, "=== " .. npc:GetCleanName() .. " ===")
    client:Message(15, "  Level: " .. npc:GetLevel() ..
                       "  Class: " .. npc:GetClassName())
    client:Message(15, "  HP: " .. npc:GetHP() .. "/" .. npc:GetMaxHP() ..
                       "  Mana: " .. npc:GetMana() .. "/" .. npc:GetMaxMana())
    client:Message(15, "  Stance: " ..
                       (stance_names[npc:GetStance()] or "Unknown") ..
                       "  Mode: " .. mode)
    client:Message(15, "  Type: " ..
                       (type_names[npc:GetCompanionType()] or "Unknown"))
end

function companion.cmd_equip(npc, client, args)
    client:Message(15, "To give items to your companion, right-click them to")
    client:Message(15, "open a trade window, then place items in the trade.")
    client:Message(15, "Items will be auto-equipped into appropriate slots.")
end

function companion.cmd_help(npc, client, args)
    local topic = args:lower():gsub("^%s+", ""):gsub("%s+$", "")

    if topic == "" then
        client:Message(15, "=== Companion Commands ===")
        client:Message(15, "")
        client:Message(15, "Stance:")
        client:Message(15, "  !passive       - Disengage from combat, follow owner")
        client:Message(15, "  !balanced      - Default combat stance")
        client:Message(15, "  !aggressive    - Actively pursue and attack enemies")
        client:Message(15, "")
        client:Message(15, "Movement:")
        client:Message(15, "  !follow        - Follow you at standard distance")
        client:Message(15, "  !guard         - Hold current position")
        client:Message(15, "  !recall        - Return to your side (if stuck)")
        client:Message(15, "")
        client:Message(15, "Equipment:")
        client:Message(15, "  !equipment     - Show equipped items")
        client:Message(15, "  !unequip <slot> - Return item from slot")
        client:Message(15, "  !unequip all   - Return all equipped items")
        client:Message(15, "  !equip         - How to give items")
        client:Message(15, "")
        client:Message(15, "Information:")
        client:Message(15, "  !status        - Show companion overview")
        client:Message(15, "  !help          - This command list")
        client:Message(15, "  !help <topic>  - Details for a category")
        client:Message(15, "")
        client:Message(15, "Combat:")
        client:Message(15, "  !target        - Companion targets your target")
        client:Message(15, "  !assist        - Companion assists you in combat")
        client:Message(15, "")
        client:Message(15, "Control:")
        client:Message(15, "  !dismiss       - Dismiss companion")
        client:Message(15, "")
        client:Message(15, "To talk naturally, just /say without ! prefix.")
        client:Message(15, "Type '!help <topic>' for details.")

    elseif topic == "stance" then
        client:Message(15, "=== Stance Commands ===")
        client:Message(15, "  !passive    - Stop fighting, follow owner.")
        client:Message(15, "                Companion will not engage combat.")
        client:Message(15, "  !balanced   - Default. Fight when attacked or")
        client:Message(15, "                when owner is attacked.")
        client:Message(15, "  !aggressive - Actively seek and attack enemies")
        client:Message(15, "                in range.")

    elseif topic == "movement" then
        client:Message(15, "=== Movement Commands ===")
        client:Message(15, "  !follow  - Follow you at standard distance.")
        client:Message(15, "  !guard   - Hold current position, stop following.")
        client:Message(15, "  !recall  - Teleport companion to your location if")
        client:Message(15, "             stuck or far away (>200 units). Has a")
        client:Message(15, "             30-second cooldown.")

    elseif topic == "equipment" then
        client:Message(15, "=== Equipment Commands ===")
        client:Message(15, "  !equipment      - Show all equipped items.")
        client:Message(15, "  !unequip <slot> - Return item from slot.")
        client:Message(15, "  !unequip all    - Return all equipped items.")
        client:Message(15, "  !equip          - How to give items to companion.")
        client:Message(15, "")
        client:Message(15, "Valid slots: primary, secondary, head, chest, arms,")
        client:Message(15, "  wrist1, wrist2, hands, legs, feet, charm, ear1,")
        client:Message(15, "  ear2, face, neck, shoulder, back, finger1,")
        client:Message(15, "  finger2, range, waist, ammo")

    elseif topic == "combat" then
        client:Message(15, "=== Combat Commands ===")
        client:Message(15, "  !target - Companion targets your current target.")
        client:Message(15, "            In balanced/aggressive, engages combat.")
        client:Message(15, "            In passive, faces target but won't attack.")
        client:Message(15, "  !assist - Same as !target but conveys 'help me")
        client:Message(15, "            fight this'. Same behavior as !target.")

    elseif topic == "control" then
        client:Message(15, "=== Control Commands ===")
        client:Message(15, "  !dismiss - Dismiss your companion. They can be")
        client:Message(15, "             re-recruited later with a +10% bonus.")

    elseif topic == "information" then
        client:Message(15, "=== Information Commands ===")
        client:Message(15, "  !status       - Show companion stats, stance, mode.")
        client:Message(15, "  !help         - Show all available commands.")
        client:Message(15, "  !help <topic> - Show details for a category.")
        client:Message(15, "                  Topics: stance, movement, equipment,")
        client:Message(15, "                  combat, control, information")

    else
        client:Message(15, "Unknown help topic: " .. topic)
        client:Message(15, "Available topics: stance, movement, equipment, " ..
                           "combat, control, information")
    end
end
```

#### Database Changes

None.

#### Configuration Changes

One new rule added to `common/ruletypes.h` under the `Companions` category:

| Rule | Type | Default | Description |
|------|------|---------|-------------|
| `Companions:RecallCooldownS` | INT | `30` | Cooldown in seconds between companion recall teleports |

Two values hardcoded as Lua constants in `companion.lua`:
- `COMMAND_PREFIX = "!"` — the prefix character (fixed design decision)
- `RECALL_MIN_DISTANCE = 200` — minimum distance for recall (balance constraint)

## Open Questions — Resolved

### Q1: Can the EQ trade window be opened programmatically from Lua?

**Answer: No.** The Titanium client's trade flow is always client-initiated
via right-click (`OP_TradeRequest`). The server responds with
`OP_TradeRequestAck` but cannot initiate. Adding server-initiated trades
would require C++ changes to fabricate unsolicited packets — risky with the
Titanium client.

**Decision: Defer `!equip` trade window.** The `!equip` command displays
instructions directing the player to right-click the companion to trade.
This matches the PRD contingency plan.

### Q2: Should `!recall` have a cooldown?

**Answer: Yes, 30 seconds via data bucket.** Configurable via
`Companions:RecallCooldownS` rule. Edge cases:
- Zone boundaries: `GMMove()` is intra-zone only. Cross-zone recall is
  unnecessary — companions zone with owners via `ProcessClientZoneChange()`.
- Instances: `GMMove()` works normally in instances.
- Combat: No combat restriction. Stuck companions need recall most urgently
  during combat. 200-unit minimum prevents positioning abuse.

### Q3: Should `!target` and `!assist` work in passive stance?

**Answer: Yes, with limited effect.** In passive stance:
- Companion targets the specified entity (faces it)
- Does NOT add to hate list (no `AddToHateList()` call)
- Does NOT engage combat
- Acknowledges: "I see your target." / "I will assist."

In balanced/aggressive stance:
- Companion targets AND engages (adds to hate list with 1 hate)
- Same acknowledgments

Implementation: guard on `npc:GetStance() ~= 0` before `AddToHateList()`.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Add `Companions:RecallCooldownS` rule to `ruletypes.h` | config-expert | — | 1 line in 1 file |
| 2 | Refactor `companion.lua`: remove keyword system, add prefix command table dispatch with all 14 command handlers, add error handling, ownership check, help system, lore-corrected response phrases | lua-expert | — | ~350 lines (refactor + new) |
| 3 | Update `global_npc.lua`: replace keyword interception with prefix check | lua-expert | 2 | ~6 lines changed |

Tasks 1 and 2-3 are independent and can be developed in parallel.

**Dependency flow:**
```
Task 1 (config-expert: rule) ──────┐
                                   ├──→ game-tester validation
Tasks 2-3 (lua-expert: Lua) ──────┘
```

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `GMMove()` companion falls through world geometry | Low | Medium | Well-tested GM teleport mechanic. Player can `!recall` again. |
| `SetTarget()` + `AddToHateList()` causes chase across zone | Low | Low | Companion AI has existing leash distance from owner. |
| `eq.get_rule()` returns nil for new rule before DB seeded | Low | Medium | Lua uses `or 30` fallback. Rule auto-seeds on first start. |
| `companion_modes` table resets on `#reloadquests` | Low | Low | Companion defaults to "follow" mode assumption. Worst case: `!status` shows "Follow" when companion is actually guarding. Self-corrects on next `!guard` or `!follow`. |

### Compatibility Risks

**Behavioral change: keyword removal.** Players who learned the keyword
system must discover `!` prefix. This is intentional and desired. The
`!help` command provides discoverability. No silent failure — commands that
worked via keywords now flow to the LLM, which will respond naturally.

**Recruitment unchanged.** `is_recruitment_keyword()` is not modified.
Non-companion NPCs still respond to "recruit", "join me", etc.

**Non-companion NPCs unaffected.** The prefix check is inside the
`IsCompanion()` guard. All other NPC interactions are unchanged.

**LLM conversation preserved.** Non-prefixed messages to companions fall
through to the LLM bridge block, which is unchanged.

### Performance Risks

None. The prefix check (`message:sub(1,1) == "!"`) is O(1) and replaces
an O(n) keyword scan over 17 keywords. Strictly an improvement.

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes. Every required Lua binding already exists:

| Command | Required API | Bound? | Location |
|---------|-------------|--------|----------|
| `!recall` | `GMMove()`, `CalculateDistance()` | Yes | `lua_mob.h:82-84, 297` |
| `!target` | `SetTarget()`, `AddToHateList()` | Yes | `lua_mob.h:130, 245` |
| `!assist` | `SetTarget()`, `AddToHateList()` | Yes | Same |
| `!status` | `GetHP/MaxHP/Mana/Level/ClassName/Stance/Type` | Yes | `lua_mob.h`, `lua_companion.h` |
| `!help` | `Client:Message()` | Yes | `lua_client.h` |
| Existing cmds | `SetStance/SetGuardMode/Dismiss/ShowEquipment/GiveSlot/GiveAll` | Yes | `lua_companion.h` |

**Hardest part:** Clean refactoring of `companion.lua` to replace keyword
dispatch without breaking the recruitment flow. `is_recruitment_keyword()`
must remain unchanged.

**`GetFollowID` gap:** Solved with Lua-level mode tracking table. No C++
change needed.

### Pass 2: Simplicity

**Is this minimal?** Yes:
- 1 C++ rule line (not 3 as PRD suggested — per config-expert advice)
- 2 Lua files modified (not creating new files)
- `!equip` trade window deferred (avoids C++ work)
- No database changes
- Command table pattern is simpler than chained if/elseif blocks

**YAGNI audit:** Nothing can be deferred without reducing PRD scope.

### Pass 3: Antagonistic

**Edge: `! follow` (space after prefix)**
Handled: `body = message:sub(2):gsub("^%s+", "")` strips leading whitespace.

**Edge: `!!follow` (double prefix)**
Strips first `!`, leaving `!follow` as the command lookup. Not found in
table. Error message displayed. Acceptable.

**Edge: Commanding another player's companion**
Ownership check: `npc:GetOwnerCharacterID() ~= client:CharacterID()`.
Returns "That is not your companion." before any command runs.

**Edge: `!dismiss` during combat**
Same behavior as current keyword system. `Dismiss(true)` handles cleanly.

**Edge: `!recall` spam**
Data bucket TTL is server-enforced, per-companion per-player key. No
bypass vector.

**Edge: `!target` on friendly NPC**
`SetTarget()` works on any mob. `AddToHateList()` only fires if stance
is not passive. Companion AI aggro checks prevent attacking friendlies.

**Edge: `!recall` through walls**
`GMMove()` ignores collision (same as `#goto`). Acceptable trade-off
for a companion system. 200-unit minimum prevents micro-positioning.

**Edge: Quest reload clears companion_modes table**
Default assumption is "follow". `!status` shows "Follow" even if companion
was guarding. Self-corrects on next movement command. Low impact.

**Edge: Two companions, only one targeted**
Commands always apply to `e.self` (the targeted NPC). If player targets
companion A and says `!guard`, only companion A guards. Companion B is
unaffected. Correct behavior.

### Pass 4: Integration

**Implementation order is flexible:** Tasks 1 (C++ rule) and 2-3 (Lua
changes) have no build-time dependency. The Lua code reads the rule at
runtime via `eq.get_rule()` with an `or 30` fallback. Both can be developed
and tested independently.

**Testing sequence:**
1. Build server (picks up new rule)
2. `#reloadquests` (picks up Lua changes)
3. Test all 14 `!` commands with an active companion
4. Test unprefixed conversation flows to LLM
5. Test recruitment keywords on non-companion NPCs (regression)
6. Test error cases (no target, wrong owner, invalid command)
7. Test recall distance threshold and cooldown
8. Test `!target`/`!assist` in passive vs active stances

**File change summary:**
```
eqemu/common/ruletypes.h                                → 1 line added
akk-stack/server/quests/lua_modules/companion.lua        → ~350 lines changed
akk-stack/server/quests/global/global_npc.lua            → ~6 lines changed
```

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| config-expert | Task 1: Add `RecallCooldownS` rule | Already reviewed the rule system; trivial 1-line addition |
| lua-expert | Tasks 2-3: All Lua refactoring and new command handlers | Single agent owns all Lua changes for consistency |

**Agents NOT needed:**
- c-expert: No C++ logic changes
- data-expert: No database schema changes
- protocol-agent: No new opcodes (advisory complete)
- infra-expert: No deployment changes

## Validation Plan

### Prefix Command System
- [ ] `!follow` executes follow mode, companion responds "I will follow."
- [ ] `!guard` executes guard mode, companion responds "I will hold here."
- [ ] `!passive` sets passive stance, companion responds "I will stand down."
- [ ] `!balanced` — loyal companion responds "I will fight at your side.", mercenary responds "Understood."
- [ ] `!aggressive` sets aggressive stance, companion responds "Understood. I will fight aggressively."
- [ ] `!dismiss` dismisses companion (voluntary=true), companion responds "Farewell."
- [ ] `!equipment` displays companion's equipped items
- [ ] `!unequip primary` returns primary weapon to player
- [ ] `!unequip all` returns all equipped items
- [ ] `!unequip badslot` shows error with valid slot names
- [ ] `!unequip` (no argument) shows usage instructions

### New Commands
- [ ] `!status` displays companion name, level, HP/mana, stance, mode, type
- [ ] `!recall` teleports companion to player when distance > 200 units, responds "I am here."
- [ ] `!recall` when companion is nearby shows "Your companion is already nearby."
- [ ] `!recall` respects 30-second cooldown (shows "Recall is on cooldown.")
- [ ] `!target` sets companion target to player's target, responds "I see your target."
- [ ] `!target` with no player target shows "You must target an enemy first."
- [ ] `!assist` sets companion target and engages, responds "I will assist."
- [ ] `!target` and `!assist` in passive stance: companion targets but does NOT attack
- [ ] `!equip` displays trade instructions

### Help System
- [ ] `!help` displays full categorized command list
- [ ] `!` alone displays help
- [ ] `!help stance` shows stance details
- [ ] `!help movement` shows movement details
- [ ] `!help equipment` shows equipment details with slot list
- [ ] `!help combat` shows combat details
- [ ] `!help control` shows control details
- [ ] `!help information` shows information details
- [ ] `!help badtopic` shows "Unknown help topic" with available topics
- [ ] `!invalidcommand` shows "Unknown command" with `!help` suggestion

### Error Handling
- [ ] `!follow` targeting a non-companion NPC shows "That is not your companion."
- [ ] `!follow` with no target shows error (handled by IsCompanion() guard — non-companion NPCs skip the prefix check entirely, so this would go to LLM or be ignored)
- [ ] Commanding another player's companion shows "That is not your companion."

### Conversation Flow (Regression)
- [ ] "follow me to the castle" to companion does NOT trigger follow mode
- [ ] "stay safe" to companion does NOT trigger guard mode
- [ ] "farewell old friend" to companion does NOT trigger dismiss
- [ ] Unprefixed text to companion produces LLM natural response
- [ ] "recruit" to non-companion NPC still triggers recruitment
- [ ] "join me" to non-companion NPC still triggers recruitment
- [ ] Non-companion NPCs completely unaffected

### Rule Configurability
- [ ] Changing `Companions:RecallCooldownS` via `#rules set` adjusts cooldown duration

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
