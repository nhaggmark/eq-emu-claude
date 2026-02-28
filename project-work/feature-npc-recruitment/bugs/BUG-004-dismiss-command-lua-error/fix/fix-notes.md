# BUG-004 Fix Notes: Push Companion as Lua_Companion in Event Dispatch

## Summary

Two C++ changes were made to fix the bug where companion Lua scripts could not
call companion-specific methods (like `Dismiss()`, `SetStance()`,
`ShowEquipment()`, `GiveSlot()`, `GiveAll()`) and where `StopMoving()` was
unbound entirely.

---

## Fix 1: Type-correct `e.self` in `_EventNPC` event dispatch

**File:** `/mnt/d/Dev/EQ/eqemu/zone/lua_parser.cpp`

**Root cause:** In `LuaParser::_EventNPC()`, every NPC event handler pushed
`e.self` as a `Lua_NPC` object regardless of the actual runtime type. Because
`Lua_Companion` and `Lua_NPC` are siblings (both extend `Lua_Mob`) rather than
parent/child, companion scripts received a `Lua_NPC` that lacked all
companion-specific bindings.

**Changes:**

1. Added `#include "zone/companion.h"` before `#include "zone/lua_companion.h"`.
   This was needed because `lua_companion.h` only forward-declares `class
   Companion;` — the full definition is required to call `CastToCompanion()`
   and to construct a `Lua_Companion`.

2. Changed the `e.self` assignment block at ~line 506 from an unconditional
   `Lua_NPC` push to a branch:

```cpp
// Before
Lua_NPC l_npc(npc);
luabind::adl::object l_npc_o = luabind::adl::object(L, l_npc);
l_npc_o.push(L);
lua_setfield(L, -2, "self");

// After
if (npc->IsCompanion()) {
    Lua_Companion l_comp(npc->CastToCompanion());
    luabind::adl::object l_comp_o = luabind::adl::object(L, l_comp);
    l_comp_o.push(L);
    lua_setfield(L, -2, "self");
} else {
    Lua_NPC l_npc(npc);
    luabind::adl::object l_npc_o = luabind::adl::object(L, l_npc);
    l_npc_o.push(L);
    lua_setfield(L, -2, "self");
}
```

**Scope check:** There is only one place in `lua_parser.cpp` where `Lua_NPC`
is pushed as `e.self` — inside `_EventNPC()`. The other dispatchers
(`_EventPlayer`, `_EventBot`, `_EventMerc`, `_EventZone`) each handle their
own typed `self` and do not need this change.

---

## Fix 2: Bind `StopMoving()` in `Lua_Mob`

**Files:**
- `/mnt/d/Dev/EQ/eqemu/zone/lua_mob.h` — declaration
- `/mnt/d/Dev/EQ/eqemu/zone/lua_mob.cpp` — implementation + luabind registration

**Root cause:** `companion.lua`'s `handle_guard()` function calls
`npc:StopMoving()` to halt companion movement when the player says "guard" or
"stay". `Mob::StopMoving()` exists in C++ but was never exposed to Lua.
`StopNavigation()` was bound, but `StopMoving()` was not.

`StopMoving()` and `StopNavigation()` serve different purposes:
- `StopMoving()` — halts locomotion immediately (clears movement state)
- `StopNavigation()` — cancels the navigation path

For the guard command, `StopMoving()` is the correct call.

**Changes:**

Added declaration in `lua_mob.h` (before `StopNavigation`):
```cpp
void StopMoving();
void StopNavigation();
```

Added implementation in `lua_mob.cpp` (before `StopNavigation` implementation):
```cpp
void Lua_Mob::StopMoving() {
    Lua_Safe_Call_Void();
    self->StopMoving();
}
```

Added luabind registration in `lua_mob.cpp` (before `StopNavigation` `.def`):
```cpp
.def("StopMoving", (void(Lua_Mob::*)(void))&Lua_Mob::StopMoving)
.def("StopNavigation", (void(Lua_Mob::*)(void))&Lua_Mob::StopNavigation)
```

Because `Lua_Companion` inherits from `Lua_Mob`, `StopMoving()` is
automatically available on companion objects without any change to
`lua_companion.cpp`.

---

## Build Result

```
[1/6] Building CXX object zone/CMakeFiles/lua_zone.dir/Unity/unity_2_cxx.cxx.o
[2/6] Building CXX object zone/CMakeFiles/lua_zone.dir/Unity/unity_3_cxx.cxx.o
[3/6] Building CXX object zone/CMakeFiles/lua_zone.dir/Unity/unity_1_cxx.cxx.o
[4/6] Building CXX object zone/CMakeFiles/lua_zone.dir/Unity/unity_0_cxx.cxx.o
[5/6] Linking CXX static library zone/liblua_zone.a
[6/6] Linking CXX executable bin/zone
```

Clean build. No errors, no warnings. Only `lua_zone` (the Lua binding library)
and the `zone` binary were rebuilt, which is the expected minimal footprint for
changes to `lua_parser.cpp` and `lua_mob.cpp`.

---

## Files Modified

| File | Change |
|------|--------|
| `zone/lua_parser.cpp` | Added `companion.h` include; companion type-check in `_EventNPC` |
| `zone/lua_mob.h` | Added `StopMoving()` declaration |
| `zone/lua_mob.cpp` | Added `StopMoving()` implementation and luabind `.def` |

---

## Testing Notes

After server restart, test with a recruited companion:

1. Say "guard" or "stay" to companion — should say "I will hold here." and stop
   moving (no Lua error about `StopMoving`)
2. Say "dismiss" to companion — should call `Dismiss()` without the error
   "attempt to index a nil value" or "method not found" (was failing because
   `Lua_NPC` has no `Dismiss` method)
3. Say "show equipment" — should invoke `ShowEquipment()` correctly
4. Say "passive", "balanced", or "aggressive" — should invoke `SetStance()`
   correctly
