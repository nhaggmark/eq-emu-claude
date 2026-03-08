# BUG-004: Equipping a compatible item fails when slot is already occupied

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-08
> **Feature:** companion-equipment
> **Status:** Fix deployed, pending validation

---

## Observed Behavior

When trading a compatible item (Rusty Mace) to a companion (Guard Liben)
who already has an item in the target slot (Rusty Spear in Primary), the
trade fails with a Lua error. The BUG-003 pcall safety net catches the
error and returns the traded item (the mace), but the swap does not occur.

The error visible in chat: "Could not process item for Guard Liben. Item
returned."

## Expected Behavior

When trading a compatible item to a companion who already has an item in
that slot:

1. The existing item (Rusty Spear) should be returned to the player
2. The new item (Rusty Mace) should be equipped on the companion
3. No errors should appear

This swap behavior is the core design requirement of the companion
equipment feature.

## Reproduction Steps

1. Recruit Guard Liben as a companion
2. Equip him with a Rusty Spear (Primary slot) — works when slot is empty
3. Open trade window, give him a Rusty Mace (also Primary slot)
4. Observe: error message, mace returned, spear stays equipped, no swap

## Evidence

Screenshot showing Rusty Mace item window (1H Blunt, classes WAR CLR PAL
RNG SHD DRU MNK BRD ROG SHM BST) and Main Chat with error "Could not
process item for Guard Liben. Item returned."

## Affected Systems

- [x] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
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

**The `GetEquipment` method is not bound to Lua.**

The `companion_find_slot()` function in `global_npc.lua` (line 131) calls
`companion:GetEquipment(slot_id)` to check whether a slot is already
occupied before deciding where to place a new item. This method exists in
C++ as `Companion::GetEquipment(uint8 slot)` (defined in `companion.h` at
line 212, implemented in `companion.cpp` at line 1311), but it was never
registered in the luabind scope in `lua_companion.cpp`.

The luabind registration block (`lua_register_companion()` at lines
236-264 of `lua_companion.cpp`) lists 20 methods but does NOT include
`GetEquipment`. The following companion equipment methods ARE bound:
- `GiveItem` (line 253)
- `GiveSlot` (line 254)
- `GiveAll` (line 252)
- `ShowEquipment` (line 261)

But `GetEquipment` is missing. Additionally, `GetEquipment` is not bound
anywhere in the Lua binding layer -- it is not on `Lua_Mob` (`lua_mob.h`),
not on `Lua_NPC` (`lua_npc.h`), and not on `Lua_Companion`
(`lua_companion.h`). The Perl binding layer DOES have it
(`perl_mob.cpp` line 178, registered at line 3842 as
`Perl_Mob_GetEquipment`), but Perl bindings are irrelevant since this
code path is Lua.

When Lua calls `companion:GetEquipment(slot_id)`, luabind resolves the
method name to nil, and the call `nil(slot_id)` throws:

```
attempt to call method 'GetEquipment' (a nil value)
```

This error is caught by the pcall wrapper (added by the BUG-003 fix),
which returns the item to the player. The pcall is working correctly --
it prevents item loss -- but the swap cannot occur because the slot
occupancy check fails before the swap logic executes.

### Server Log Confirmation

The zone log at `akk-stack/server/logs/zone_dynamic_01.log` line 117
confirms the exact error:

```
Zone | QuestError | AddError quests/global/global_npc.lua:131: attempt to call method 'GetEquipment' (a nil value)
stack traceback:
    quests/global/global_npc.lua:131: in function 'companion_find_slot'
    quests/global/global_npc.lua:196: in function <quests/global/global_npc.lua:143>
```

### Call Chain

1. Player trades Rusty Mace to Guard Liben (companion)
2. `event_trade` fires in `global_npc.lua`
3. For the traded item, the pcall-wrapped logic calls
   `companion_find_slot(e.self, slots_bitmask)` (line 196)
4. `companion_find_slot` iterates slots 0-22, and for each matching slot
   calls `companion:GetEquipment(slot_id)` (line 131) to check if the
   slot is empty
5. `GetEquipment` is nil on the Lua Companion object -> Lua error
6. pcall catches the error, returns the item via `SummonItem`
7. Player gets their mace back but the spear stays; no swap occurs

### Why This Was Not Caught Earlier

This bug was masked by BUG-003. Before BUG-003 was fixed, the trade
handler crashed at an earlier point (`item_data:IsEquipable()` on line
205, now line ~218) which prevented execution from reaching the
`companion_find_slot()` call. With BUG-003 fixed, execution reaches the
slot finder for the first time and hits the missing binding.

Specifically, equipping an item into an EMPTY slot still fails at
`GetEquipment` -- but the first equip of the Rusty Spear succeeded
because it was done before the BUG-003 fix was deployed (the old code
path did not call `companion_find_slot`). After the BUG-003 fix
restructured the code to use `companion_find_slot` for all equips, ALL
equips now fail, not just swaps.

### Key Files and Lines

| File | Lines | Relevance |
|------|-------|-----------|
| `akk-stack/server/quests/global/global_npc.lua` | 131 | Calls `companion:GetEquipment(slot_id)` -- the nil method |
| `eqemu/zone/lua_companion.cpp` | 236-264 | luabind registration -- `GetEquipment` is MISSING from .def list |
| `eqemu/zone/lua_companion.h` | 20-93 | `Lua_Companion` class declaration -- no `GetEquipment` declared |
| `eqemu/zone/companion.h` | 212 | C++ `GetEquipment(uint8 slot)` declaration |
| `eqemu/zone/companion.cpp` | 1311-1317 | C++ `GetEquipment` implementation |
| `akk-stack/server/logs/zone_dynamic_01.log` | 117-120 | Server log confirming the exact error |

### Proposed Fix

**C++ change in `lua_companion.cpp` and `lua_companion.h` -- requires rebuild.**

**Step 1: Declare `GetEquipment` in `lua_companion.h`**

Add to the "Equipment listing / retrieval" section (after line 92):

```cpp
uint32 GetEquipment(int slot);
```

**Step 2: Implement `GetEquipment` wrapper in `lua_companion.cpp`**

Add implementation (follow the pattern of other methods):

```cpp
uint32 Lua_Companion::GetEquipment(int slot)
{
    Lua_Safe_Call_Int();
    return self->GetEquipment(static_cast<uint8>(slot));
}
```

Note: The parameter is `int` (not `uint8`) because Lua numbers are
doubles and luabind casts from Lua number to the C++ parameter type.
Using `int` is the convention used throughout the existing lua bindings
(e.g., `SetStance(int stance)`, `SetFollowDistance(int dist)`).

**Step 3: Register in luabind scope in `lua_companion.cpp`**

Add to the `lua_register_companion()` function between `GiveAll` and
`GiveItem` (alphabetical order per existing convention):

```cpp
.def("GetEquipment", &Lua_Companion::GetEquipment)
```

**Step 4: Rebuild the zone binary**

```bash
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
```

Then restart the zone process.

### Task Breakdown

**Task 1: Add `GetEquipment` Lua binding** (c-expert)
- File: `eqemu/zone/lua_companion.h` -- add method declaration
- File: `eqemu/zone/lua_companion.cpp` -- add implementation + luabind registration
- Follow the pattern of existing methods like `GetCompanionID()`, `GetStance()` etc.
- Parameter type should be `int` (Lua convention), cast to `uint8` internally

**Task 2: Rebuild zone binary** (c-expert)
- `cd ~/code/build && ninja -j$(nproc)` inside the container
- Restart zone process

**Task 3: Test** (game-tester)
- Test 1: Trade a weapon to a companion with an EMPTY primary slot -- should equip
- Test 2: Trade a different weapon to a companion that ALREADY has a primary weapon --
  existing weapon should return to player, new weapon should equip (swap)
- Test 3: Trade an armor piece to a companion in an empty armor slot -- should equip
- Test 4: Trade a different armor piece for an occupied armor slot -- swap should work
- Test 5: Trade a ring to a companion with no rings -- should go to finger1
- Test 6: Trade a second ring -- should go to finger2 (empty slot preference)
- Test 7: Trade a third ring -- should swap with finger1 (first match, since both occupied)
- Test 8: `!equipment` should show the correct items after each operation

### Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| `GetEquipment` return type mismatch | Low | C++ returns `uint32`, Lua binding returns `uint32`, Lua compares to `0` -- no type issues. Lua treats all numbers as doubles. |
| Missing other unbound methods | Low | Scanned all Lua code calling companion methods. `GetEquipment` is the only unbound method called from Lua. `RemoveItemFromSlot` and `SetEquipment` exist in C++ but are NOT called from Lua (they are called internally by `GiveSlot` and `GiveItem` in C++). |
| Rebuild required means downtime | Low | A zone binary rebuild and process restart is sufficient. No database migration, no shared_memory reload, no world restart needed. |

---

## Deeper Investigation

**Investigated by:** architect
**Date:** 2026-03-08

### Which Hypothesis Was Correct

**Hypothesis 1 is correct: `e.self` in `event_trade` is NOT a `Lua_Companion`.**

Even though `GetEquipment` was successfully added to `lua_companion.h`,
`lua_companion.cpp`, and registered in the luabind scope (confirmed at line
257 of `lua_companion.cpp`), the method remains nil at Lua runtime because
`e.self` is wrapped as `Lua_NPC`, not `Lua_Companion`, when the
`event_trade` handler fires.

### The Actual Mechanism

The issue is a **double-write race in the event argument setup**. Here is
the exact execution sequence in `_EventNPC()` (lua_parser.cpp lines 489-522):

1. **`_EventNPC` creates the `e` table** (line 506: `lua_createtable`)

2. **`_EventNPC` correctly sets `e.self` as `Lua_Companion`** (lines 509-513):
   ```cpp
   if (npc->IsCompanion()) {
       Lua_Companion l_comp(npc->CastToCompanion());
       luabind::adl::object l_comp_o = luabind::adl::object(L, l_comp);
       l_comp_o.push(L);
       lua_setfield(L, -2, "self");
   }
   ```
   This code already exists and correctly wraps companions.

3. **`_EventNPC` calls the per-event argument handler** (lines 521-522):
   ```cpp
   auto arg_function = NPCArgumentDispatch[evt];
   arg_function(this, L, npc, init, data, extra_data, extra_pointers);
   ```

4. **`handle_npc_event_trade` OVERWRITES `e.self` with `Lua_NPC`**
   (lua_parser_events.cpp lines 58-61):
   ```cpp
   Lua_NPC              l_npc(reinterpret_cast<NPC*>(npc));
   luabind::adl::object l_npc_o = luabind::adl::object(L, l_npc);
   l_npc_o.push(L);
   lua_setfield(L, -2, "self");
   ```

The `handle_npc_event_trade` function creates a **brand new `Lua_NPC`
wrapper** for the same C++ NPC pointer and writes it to `e.self`,
destroying the `Lua_Companion` wrapper that `_EventNPC` just set. This
is the ONLY NPC event handler that overwrites `e.self` --
`handle_npc_event_say` and all other handlers leave `e.self` as set by
`_EventNPC`.

### Why `event_say` Works but `event_trade` Doesn't

- `event_say`: `handle_npc_event_say` does NOT set `e.self`. It only sets
  `e.other`, `e.message`, and `e.language`. The `Lua_Companion` wrapper
  from `_EventNPC` survives. Companion methods like `ShowEquipment`,
  `SetStance`, `Dismiss` all work correctly in `event_say`.

- `event_trade`: `handle_npc_event_trade` OVERWRITES `e.self` with
  `Lua_NPC`. All companion-specific methods (including `GetEquipment`,
  `ShowEquipment`, `SetStance`, etc.) become nil. However, methods that
  were ALSO registered on `Lua_NPC` (like `GiveItem`, `GiveSlot`,
  `GiveAll`, `GetOwnerCharacterID`) still work because they are on the
  `Lua_NPC` binding.

### Why the Previous Fix Was Insufficient

The previous fix correctly added `GetEquipment` to `Lua_Companion` class
and luabind registration. This would work in `event_say` or any other
event where `e.self` retains its `Lua_Companion` type. But in
`event_trade`, `e.self` is overwritten to `Lua_NPC`, so the
`Lua_Companion`-only method is still inaccessible.

### The Correct Fix Approach

There are two viable fixes. **Fix B is recommended** because it follows
the established pattern used by all other companion methods that work in
`event_trade`.

#### Fix A: Remove the `e.self` overwrite from `handle_npc_event_trade`

Remove lines 58-61 of `lua_parser_events.cpp` (the `Lua_NPC` construction
and `lua_setfield(L, -2, "self")` lines). Since `_EventNPC` already sets
`e.self` correctly (with companion-awareness), the handler does not need
to re-set it.

**Pros:** Fixes the root cause. All `Lua_Companion` methods work in
`event_trade` automatically, now and in the future.

**Cons:** Risk of unintended side effects. The `handle_npc_event_trade`
handler also uses `l_npc_o` to set `e.trade.self` (line 110-111). If we
remove the `Lua_NPC` variable entirely, we need to adjust the trade
sub-table population. Additionally, this is a widely-used code path -- all
NPC trades in the game flow through it. Must verify no other code depends
on `e.self` being specifically `Lua_NPC` in trade context.

Also note: even with Fix A, the `handle_npc_event_trade` handler still
needs a `Lua_NPC` reference for the `e.trade.self` sub-table (line 110).
So the fix would need to restructure that code to either skip setting
`e.self` while still creating the NPC ref for `e.trade.self`, or use the
companion-aware version there too.

#### Fix B (RECOMMENDED): Add `GetEquipment` to `Lua_NPC` binding

Following the exact pattern used by `GiveItem`, `GiveSlot`, `GiveAll`,
and `GetOwnerCharacterID`, add `GetEquipment` to both `lua_npc.h` and
`lua_npc.cpp` with an `IsCompanion()` guard:

In `lua_npc.h`, add declaration:
```cpp
uint32 GetEquipment(int slot);
```

In `lua_npc.cpp`, add implementation:
```cpp
uint32 Lua_NPC::GetEquipment(int slot)
{
    Lua_Safe_Call_Int();
    if (!self->IsCompanion()) {
        return 0;
    }
    return self->CastToCompanion()->GetEquipment(static_cast<uint8>(slot));
}
```

In `lua_register_npc()`, add registration:
```cpp
.def("GetEquipment", (uint32(Lua_NPC::*)(int))&Lua_NPC::GetEquipment)
```

**Pros:** Follows the established pattern exactly. Minimal risk -- the
same approach used for 4 other companion methods that DO work. No change
to event dispatch code. Works regardless of whether `e.self` is
`Lua_Companion` or `Lua_NPC`.

**Cons:** Methods end up duplicated across `Lua_NPC` and `Lua_Companion`.
Does not fix the root cause (the overwrite in `handle_npc_event_trade`).
Future companion methods will need the same dual-registration unless the
root cause is fixed.

### Why `GiveItem`, `GiveSlot`, `GiveAll` Work but `GetEquipment` Doesn't

These methods were added to BOTH `Lua_Companion` AND `Lua_NPC`:

| Method | On Lua_Companion | On Lua_NPC | Works in event_trade |
|--------|-----------------|------------|---------------------|
| `GiveItem` | Yes (line 260) | Yes (line 1045) | YES |
| `GiveSlot` | Yes (line 268) | Yes (line 1046) | YES |
| `GiveAll` | Yes (line 259) | Yes (line 1044) | YES |
| `GetOwnerCharacterID` | Yes (line 251) | Yes (line 1069) | YES |
| `GetEquipment` | Yes (line 257) | **NO** | **NO** |
| `ShowEquipment` | Yes (line 268) | **NO** | Would fail if called |

The pattern is clear: companion methods that are registered on `Lua_NPC`
work in `event_trade`; those only on `Lua_Companion` do not.

### Updated Task Breakdown

**Task 1: Add `GetEquipment` to `Lua_NPC` binding** (c-expert)
- File: `eqemu/zone/lua_npc.h` -- add `uint32 GetEquipment(int slot);`
  declaration alongside existing companion methods (near `GiveItem`,
  `GiveSlot`, `GiveAll`, `GetOwnerCharacterID`)
- File: `eqemu/zone/lua_npc.cpp` -- add implementation with
  `IsCompanion()` guard and `CastToCompanion()` delegation (follow the
  exact pattern of `Lua_NPC::GiveItem` at line 962)
- File: `eqemu/zone/lua_npc.cpp` -- add `.def("GetEquipment", ...)`
  to `lua_register_npc()` (follow existing registration pattern)
- The method on `Lua_Companion` can stay as-is (it works when `e.self` is
  a `Lua_Companion`, e.g., in `event_say`)

**Task 2: Rebuild zone binary** (c-expert or infra-expert)
- `cd ~/code/build && ninja -j$(nproc)` inside the container
- Restart zone process

**Task 3: Validate** (game-tester)
- Same test matrix as the original task breakdown
- Additionally verify that `!equipment` command still works (it uses
  `event_say`, where `e.self` is `Lua_Companion`)

### Future Consideration

The `handle_npc_event_trade` overwrite of `e.self` is a latent bug that
will affect ANY future companion-only method called from `event_trade`.
A follow-up task should be filed to either:

1. Remove the redundant `e.self` overwrite from `handle_npc_event_trade`
   (requires careful testing of all trade interactions), OR
2. Document the requirement that all companion methods callable from
   `event_trade` must be dual-registered on both `Lua_NPC` and
   `Lua_Companion`

For now, Fix B resolves the immediate blocker with minimal risk.
