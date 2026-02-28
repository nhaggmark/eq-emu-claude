# BUG-004 Lua Expert Diagnosis: Dismiss Command Lua Error

## Summary

The dismiss command (and all other companion management commands) fail with a Lua
error because `e.self` in the NPC event handler is always typed as `Lua_NPC`, but
the methods being called (`Dismiss`, `SetStance`, `ShowEquipment`, `GiveSlot`,
`GiveAll`) are only defined on `Lua_Companion`. The Lua code never casts `e.self`
to a `Companion` before calling these methods.

---

## Root Cause

### The Type Mismatch

In `eqemu/zone/lua_parser.cpp`, line 507, all NPC event handlers package `e.self`
as `Lua_NPC` unconditionally:

```cpp
// lua_parser.cpp:507
lua_createtable(L, 0, 0);
//always push self
Lua_NPC l_npc(npc);
luabind::adl::object l_npc_o = luabind::adl::object(L, l_npc);
l_npc_o.push(L);
lua_setfield(L, -2, "self");
```

Even when the underlying C++ object is a `Companion` (which extends `NPC`), the Lua
layer wraps it in `Lua_NPC`. This means `e.self` is always a `Lua_NPC` object in
the Lua scripts.

### The Luabind Class Hierarchy

The luabind hierarchy is:
```
Lua_Entity
    Lua_Mob
        Lua_NPC        -- registered as "NPC"  in lua_npc.cpp:962
        Lua_Companion  -- registered as "Companion" in lua_companion.cpp:159
```

`Lua_NPC` and `Lua_Companion` are siblings that both inherit from `Lua_Mob`. Neither
inherits from the other. Methods defined on `Lua_Companion` are NOT accessible on a
`Lua_NPC` object.

### The Failing Call

In `akk-stack/server/quests/lua_modules/companion.lua`, the `handle_dismiss` function
(line 450-453) is:

```lua
function companion.handle_dismiss(npc, client)
    npc:Say("Farewell.")
    npc:Dismiss(true)  -- FAILS: Dismiss is on Lua_Companion, not Lua_NPC
end
```

`npc` here is `e.self` from `global_npc.lua`, which is `Lua_NPC`. Calling
`npc:Dismiss(true)` on a `Lua_NPC` object throws a Lua error because `Dismiss` is
not a method on `Lua_NPC` — it is exclusively defined on `Lua_Companion`
(in `lua_companion.h` and registered in `lua_companion.cpp`).

---

## All Affected Methods in companion.lua

Every management command in `companion.lua` that calls a `Lua_Companion`-only method
is broken for the same reason:

| Function | Line | Call | Status |
|---|---|---|---|
| `handle_dismiss` | 452 | `npc:Dismiss(true)` | FAILS — `Dismiss` is Companion-only |
| `handle_stance` | 459 | `npc:SetStance(stance)` | FAILS — `SetStance` is Companion-only |
| `handle_guard` | 474 | `npc:StopMoving()` | FAILS — `StopMoving` not bound in any Lua class |
| `handle_show_equipment` | 481 | `npc:ShowEquipment(client)` | FAILS — Companion-only |
| `handle_give_slot` | 487 | `npc:GiveSlot(client, slot_name)` | FAILS — Companion-only |
| `handle_give_all` | 492 | `npc:GiveAll(client)` | FAILS — Companion-only |

`handle_follow` (line 466-468) calls `npc:SetFollowDistance(10)`, which is on
`Lua_NPC` (lua_npc.cpp:360), so it does not fail — but this is the only one.

`StopMoving` is not bound in `lua_mob.cpp` or `lua_npc.cpp` at all, so it would
fail even if the type were correct.

---

## Exact Error Location

The first error hits at `companion.lua` line 452:

```lua
npc:Dismiss(true)
```

Lua error text (typical luabind method-not-found): something like:
```
[Quest Debug][lua_debug] No matching overload found, candidates:
  in function 'Dismiss'
```

or simply:

```
[Quest Debug][lua_debug] attempt to call a nil value (method 'Dismiss')
```

The `npc:Say("Farewell.")` on line 451 succeeds first (since `Say` is on `Lua_Mob`,
the shared base), then `Dismiss` throws.

---

## Fix

### Fix Option 1: Cast e.self to Companion in companion.lua (Recommended)

The cleanest fix is to cast `e.self` to a `Companion` inside `handle_command` before
dispatching, since at that point we already know `e.self:IsCompanion()` is true (the
check is in `global_npc.lua` line 11).

`CastToCompanion()` is registered on `Lua_Entity` (the base class of all entities) in
`lua_entity.cpp`, line 170. It is accessible on any entity object including `Lua_NPC`.

Change `companion.handle_command` signature from:

```lua
function companion.handle_command(npc, client, message)
```

To cast at the top of the function:

```lua
function companion.handle_command(npc, client, message)
    -- e.self is always Lua_NPC in the event table; cast to Companion to
    -- access Dismiss(), SetStance(), ShowEquipment(), GiveSlot(), GiveAll().
    local companion_entity = npc:CastToCompanion()
    local msg = message:lower()

    if msg:find("dismiss", 1, true) or msg:find("leave", 1, true)
            or msg:find("goodbye", 1, true) or msg:find("farewell", 1, true)
            or msg:find("release", 1, true) then
        companion.handle_dismiss(companion_entity, client, npc)

    elseif msg:find("passive", 1, true) then
        companion.handle_stance(companion_entity, client, 0, npc)
    -- ... etc., passing companion_entity to all sub-handlers
    end
end
```

Then update each sub-handler to receive both `companion_entity` (for Companion-only
calls) and `npc` (for `Say()` calls, since `Say` works on `Lua_NPC`). Or simplify by
letting `companion_entity` handle `Say` too — `Lua_Companion` inherits `Say` from
`Lua_Mob`.

The simplest version: pass `companion_entity` to all sub-handlers and use it for
everything, since `Lua_Companion` inherits all `Lua_Mob`/`Lua_NPC` methods via
luabind:

```lua
function companion.handle_command(npc, client, message)
    -- Cast to Companion: Lua_NPC does not expose Dismiss/SetStance/ShowEquipment/etc.
    -- CastToCompanion() is available on all entities via Lua_Entity base.
    local c = npc:CastToCompanion()
    local msg = message:lower()

    if msg:find("dismiss", 1, true) or msg:find("leave", 1, true)
            or msg:find("goodbye", 1, true) or msg:find("farewell", 1, true)
            or msg:find("release", 1, true) then
        companion.handle_dismiss(c, client)

    elseif msg:find("passive", 1, true) then
        companion.handle_stance(c, client, 0)

    elseif msg:find("aggressive", 1, true) then
        companion.handle_stance(c, client, 2)

    elseif msg:find("balanced", 1, true) or msg:find("stance", 1, true) then
        companion.handle_stance(c, client, 1)

    elseif msg:find("follow", 1, true) then
        companion.handle_follow(c, client)

    elseif msg:find("guard", 1, true) or msg:find("stay", 1, true) then
        companion.handle_guard(c, client)

    elseif msg:find("show equipment", 1, true) or msg:find("show gear", 1, true)
            or msg:find("inventory", 1, true) then
        companion.handle_show_equipment(c, client)

    elseif msg:find("give me everything", 1, true) then
        companion.handle_give_all(c, client)

    elseif msg:find("give me your", 1, true) then
        local slot_name = msg:match("give me your%s+(.+)$")
        if slot_name then
            companion.handle_give_slot(c, client, slot_name:gsub("%s+$", ""))
        else
            client:Message(15, "Specify what to give: 'give me your weapon', etc.")
        end
    end
end
```

### Fix for handle_guard: StopMoving Not Bound

`handle_guard` calls `npc:StopMoving()` which is not bound in any Lua class. The
fix for guard mode needs to use a Companion AI method. Two options:

1. **Preferred**: Add a `StopMoving()` binding to `Lua_Mob` in `lua_mob.cpp` (C++
   change), then `companion_entity:StopMoving()` will work.
2. **Lua-only workaround**: Use `companion_entity:SetStance(0)` (passive) as a
   proxy until guard AI is fully implemented, or remove the `StopMoving()` call and
   rely on companion_ai.cpp for position-hold behavior.

### Fix Option 2: Add Companion-Only Methods to Lua_NPC (Not Recommended)

Adding `Dismiss`, `SetStance`, etc. to `Lua_NPC` would require C++ changes and
pollute the NPC interface. This approach is incorrect — only Companion objects should
have these methods.

### Fix Option 3: Change lua_parser.cpp to deliver e.self as Lua_Companion (C++ change)

In `lua_parser.cpp` line 507, detect if `npc->IsCompanion()` and if so wrap as
`Lua_Companion` instead of `Lua_NPC`. This is cleaner architecturally but requires a
C++ change and rebuild. The Lua cast approach (Option 1) is faster to ship.

---

## Recommended Fix (Actionable)

**File to change**: `/mnt/d/Dev/EQ/akk-stack/server/quests/lua_modules/companion.lua`

**Change**: In `companion.handle_command` (line 408), add `local c = npc:CastToCompanion()`
at the top, then pass `c` to all sub-handlers instead of `npc`. The sub-handler
signatures don't need to change externally since `Lua_Companion` inherits everything
from `Lua_Mob`/`Lua_NPC` (including `Say`, `GetName`, `SetFollowDistance`, etc.).

**Secondary fix needed**: `handle_guard`'s `npc:StopMoving()` call at line 474. Since
`StopMoving` is not bound in any Lua class, this will fail even after the cast. Either:
- Remove the `StopMoving()` call and rely on `companion_ai.cpp` for guard behavior, OR
- Flag for c-expert to add `StopMoving` binding to `Lua_Mob`

---

## Files Investigated

| File | Key Finding |
|---|---|
| `akk-stack/server/quests/global/global_npc.lua` | Correctly checks `e.self:IsCompanion()` before calling `handle_command`; passes `e.self` (Lua_NPC) as first arg |
| `akk-stack/server/lua_modules/companion.lua` | `handle_command` and all sub-handlers use `npc` as `Lua_NPC` but call Lua_Companion-only methods |
| `eqemu/zone/lua_parser.cpp:507` | Always wraps `e.self` as `Lua_NPC` regardless of actual C++ type |
| `eqemu/zone/lua_companion.h` | `Dismiss`, `SetStance`, `ShowEquipment`, `GiveSlot`, `GiveAll` declared here only |
| `eqemu/zone/lua_companion.cpp:159` | `Lua_Companion` registered as sibling of `Lua_NPC`, not child |
| `eqemu/zone/lua_entity.cpp:170` | `CastToCompanion()` registered on `Lua_Entity` base — accessible from `Lua_NPC` objects |
| `eqemu/zone/lua_npc.h` | No `Dismiss`, `SetStance`, `ShowEquipment` methods |
| `eqemu/zone/lua_mob.cpp` | No `StopMoving` binding |
