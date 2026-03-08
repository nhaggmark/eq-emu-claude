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
