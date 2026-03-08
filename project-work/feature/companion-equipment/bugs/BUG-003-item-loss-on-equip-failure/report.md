# BUG-003: Item lost when companion cannot equip it

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-03-08
> **Feature:** companion-equipment
> **Status:** Fix deployed, pending validation

---

## Observed Behavior

When handing a companion an item they cannot equip (due to class/race
restrictions or other validation failure), a Lua script error occurs in the
trade handler. The item is consumed — it is neither equipped on the companion
nor returned to the player. The item simply disappears.

## Expected Behavior

If for any reason the companion cannot equip a provided item, the companion
should:

1. Return the item to the player's inventory (item is NEVER lost)
2. Provide actionable feedback explaining why the item cannot be equipped
   (e.g., "I cannot wear that — it is not suited for my kind")
3. Handle all error paths gracefully — no Lua errors visible in chat

## Reproduction Steps

1. Recruit an NPC companion into group
2. Open trade window with the companion
3. Place an item the companion cannot equip (e.g., gloves restricted to a
   class/race the NPC does not match)
4. Complete the trade
5. Observe: Lua error appears in chat, item disappears entirely

## Evidence

User-provided screenshot showing Lua error output in the Main Chat window
during the trade. The error occurs in the global NPC trade handler script.

## Affected Systems

- [ ] C++ server source → c-expert
- [x] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert

---

## Architecture Assessment

**Assessed by:** architect
**Date:** 2026-03-08

### Root Cause Analysis

There are **two bugs** that combine to produce the item loss:

**Bug A: `item_data:IsEquipable()` does not exist on `Lua_Item`**

Line 205 of `global_npc.lua` calls `item_data:IsEquipable(comp_race, comp_class)`.
The variable `item_data` is a `Lua_Item` object (returned by `inst:GetItem()` with
no arguments at line 194). The `Lua_Item` class wraps `EQ::ItemData` and does NOT
have `IsEquipable` bound -- scanning `lua_item.h` confirms it is not listed among
the ~130 methods. `IsEquipable` exists only on `Lua_ItemInst` (which wraps
`EQ::ItemInstance`, bound in `lua_iteminst.cpp` at lines 59-67 and registered at
lines 494-495).

When `item_data:IsEquipable()` is called, Lua attempts to call a nil value, which
throws a runtime error. This error aborts the entire `event_trade` handler immediately.
No subsequent code executes -- critically, no `SummonItem()` call runs to return the
item.

**Bug B: `eq.get_rule()` returns a string, not a boolean**

Lines 200-201 call `eq.get_rule("Companions:EnforceClassRestrictions")` and
`eq.get_rule("Companions:EnforceRaceRestrictions")`. The `eq.get_rule()` function
(implemented as `lua_get_rule()` in `lua_general.cpp` at line 930) calls
`RuleManager::Instance()->GetRule()` which returns the rule value as a **string**
(e.g., `"true"` or `"false"`).

In Lua, ALL non-empty strings are truthy -- including the string `"false"`. Therefore
the condition `(enforce_class or enforce_race)` on line 202 is ALWAYS true when the
rules exist in the database, regardless of their actual boolean value. This means
the restriction check block is entered unconditionally, and Bug A is triggered on
every trade that reaches a slot match.

Even if Bug A were fixed, Bug B would cause the class/race check to fire even when
the admin has intentionally disabled it via rules. The correct Lua API for boolean
rules is `RuleB.Get(rule_enum_value)`, not `eq.get_rule("Category:RuleName")`.
However, the `RuleB.Get()` function takes an integer enum value, not a string name.
The simplest fix for the Lua script is to compare the string result:
`eq.get_rule("Companions:EnforceClassRestrictions") == "true"`.

**The item loss mechanism:**

After the Lua `event_trade` handler runs (or crashes with an error), execution
returns to C++ in `Client::FinishTrade()` at `trading.cpp` line 649-660. The
companion-specific code path unconditionally deletes ALL trade slot item instances:

```cpp
if (tradingWith->IsCompanion()) {
    handin_npc->ResetHandin();
    for (auto &inst: insts) {
        if (inst) {
            safe_delete(inst);  // <-- items destroyed regardless of Lua handler outcome
        }
    }
    return;
}
```

This C++ code runs whether the Lua handler completed successfully or crashed.
It assumes the Lua handler has already dealt with all items (either equipping
them via `GiveItem` or returning them via `SummonItem`). When the Lua handler
crashes at the `IsEquipable` call, neither action has occurred, and the item
is silently destroyed.

### Key Files and Lines

| File | Lines | Relevance |
|------|-------|-----------|
| `akk-stack/server/quests/global/global_npc.lua` | 200-210 | `event_trade` companion equipment handler -- the `eq.get_rule()` and `item_data:IsEquipable()` calls |
| `eqemu/zone/lua_item.h` | 19-208 | `Lua_Item` class -- confirms `IsEquipable` is NOT bound |
| `eqemu/zone/lua_iteminst.cpp` | 59-67, 494-495 | `Lua_ItemInst::IsEquipable` -- where the method actually lives |
| `eqemu/zone/lua_general.cpp` | 930-934 | `lua_get_rule()` -- returns string, not bool |
| `eqemu/zone/lua_general.cpp` | 5889-5891 | `get_ruleb()` -- the typed boolean rule accessor (`RuleB.Get()`) |
| `eqemu/zone/trading.cpp` | 649-660 | Companion trade completion -- unconditional `safe_delete` of items |
| `eqemu/common/ruletypes.h` | 1206-1207 | `Companions:EnforceClassRestrictions` and `EnforceRaceRestrictions` rule definitions (RULE_BOOL) |

### Proposed Fix

**Lua-only fix in `global_npc.lua` -- no C++ changes required.**

The fix has three parts, all in the `event_trade` function:

**Fix 1: Use `inst:IsEquipable()` instead of `item_data:IsEquipable()`**

Replace line 205:
```lua
-- BEFORE (broken):
if not item_data:IsEquipable(comp_race, comp_class) then

-- AFTER (fixed):
if not inst:IsEquipable(comp_race, comp_class) then
```

The `inst` variable (type `Lua_ItemInst`) already holds the item instance and
HAS the `IsEquipable(race, class)` method bound.

**Fix 2: Compare rule string to `"true"` for correct boolean semantics**

Replace lines 200-202:
```lua
-- BEFORE (broken):
local enforce_class = eq.get_rule("Companions:EnforceClassRestrictions")
local enforce_race  = eq.get_rule("Companions:EnforceRaceRestrictions")
if (enforce_class or enforce_race) and item_data then

-- AFTER (fixed):
local enforce_class = eq.get_rule("Companions:EnforceClassRestrictions") == "true"
local enforce_race  = eq.get_rule("Companions:EnforceRaceRestrictions") == "true"
if (enforce_class or enforce_race) and inst then
```

This ensures the restriction check is only entered when the admin has the rules
enabled. Also changes `item_data` guard to `inst` since the `IsEquipable` call
now uses `inst`.

**Fix 3: Wrap the entire trade loop body in `pcall` for defensive safety**

Even with fixes 1 and 2, a future Lua error in the trade handler would still
cause item loss due to the C++ `safe_delete` behavior. Add a `pcall` wrapper
around the per-item processing so that any unexpected error returns the item
to the player rather than losing it:

```lua
for i = 1, 4 do
    local inst = e.trade["item" .. i]
    if inst and inst.valid then
        local item_id = inst:GetID()
        if item_id and item_id ~= 0 then
            local ok, err = pcall(function()
                -- ... existing equip logic ...
            end)
            if not ok then
                -- Safety net: return item on any unexpected error
                e.other:SummonItem(item_id)
                e.other:Message(15, "[Error] Could not process item for " ..
                    e.self:GetCleanName() .. ". Item returned.")
            end
        end
    end
end
```

This ensures NO item can ever be lost due to a Lua error in the trade handler,
regardless of what goes wrong in the processing logic.

### Task Breakdown

**Task 1: Fix the trade handler** (lua-expert)
- File: `akk-stack/server/quests/global/global_npc.lua`, function `event_trade`
- Fix 1: Change `item_data:IsEquipable()` to `inst:IsEquipable()` at line 205
- Fix 2: Change `eq.get_rule()` comparisons to `== "true"` at lines 200-201
- Fix 2b: Change `item_data` guard to `inst` guard on line 202
- Fix 3: Wrap per-item processing in `pcall` with `SummonItem` fallback
- Verify the `goto continue` still works correctly within the pcall wrapper
  (note: `goto` cannot jump out of a pcall scope -- restructure to use a
  local return or flag variable inside the pcall, then check the flag after)

**Task 2: Test** (game-tester)
- Trade a class-restricted item to a companion of the wrong class -- item should
  be returned with a message, no Lua error
- Trade a race-restricted item to a companion of the wrong race -- same behavior
- Trade a valid equippable item -- should equip normally
- Set `Companions:EnforceClassRestrictions` to `false` via `#rules` command, then
  trade a class-restricted item -- should equip (restriction bypassed)
- Trade multiple items in one trade window (mix of valid and restricted) --
  valid items equip, restricted items return, no items lost
- Trade a non-equipment item (e.g., food, container) -- should return with message

### Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| `inst:IsEquipable()` uses bitmask race/class values, not DB IDs | Medium | Verify that `GetRace()` and `GetClass()` return values compatible with `IsEquipable()`. The C++ `ItemData::IsEquipable()` uses `GetPlayerRaceBit()` and `GetPlayerClassBit()` internally, which convert from race/class IDs to bitmasks. `ItemInstance::IsEquipable(uint16, uint16)` delegates to `ItemData::IsEquipable()` which handles this conversion. |
| `goto continue` incompatible with `pcall` scope | Medium | The `goto` label `::continue::` is outside the `pcall` function scope. Lua does not allow `goto` to jump out of a closure. Restructure the inner function to use early returns and check a flag variable after pcall. |
| `pcall` swallows legitimate errors silently | Low | The fallback logs an error message to the player's chat. The server logs will also capture the Lua error via the standard quest error logging. |
| Edge case: item with 0 slots bitmask | Low | `companion_find_slot()` returns nil for 0 bitmask, which falls to the "cannot equip" path (line 225-228) which correctly returns the item. Not affected by this bug. |
