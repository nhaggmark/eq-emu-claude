# C++ Lua Binding Findings — BUG-004 Dismiss Command Lua Error

**Date:** 2026-02-28
**Investigator:** c-expert
**Scope:** Verify C++ Lua bindings for the Companion dismiss flow

---

## Summary

The C++ Lua bindings for `Dismiss()` and all related Companion methods are
**correctly implemented** in `lua_companion.cpp`. The root cause of the Lua
error is elsewhere in the stack: the Lua parser always pushes `Lua_NPC` as the
type of `e.self` for NPC events, even when the underlying C++ object is a
`Companion`. Because `Dismiss()` is only registered on `Lua_Companion` (not
on `Lua_NPC`), calling `npc:Dismiss(true)` in `companion.lua` fails with a
method-not-found error at runtime.

---

## All Companion Methods Exposed to Lua

File: `/mnt/d/Dev/EQ/eqemu/zone/lua_companion.cpp`, lines 158–179

| Lua method name         | C++ binding                                | Declared in companion.h |
|-------------------------|--------------------------------------------|--------------------------|
| `AddExperience(xp)`     | `Lua_Companion::AddExperience(uint32)`     | Yes (public)             |
| `Dismiss(voluntary)`    | `Lua_Companion::Dismiss(bool)`             | Yes (public)             |
| `GetCompanionID()`      | `Lua_Companion::GetCompanionID()`          | Yes (public)             |
| `GetCompanionType()`    | `Lua_Companion::GetCompanionType()`        | Yes (public)             |
| `GetCompanionXP()`      | `Lua_Companion::GetCompanionXP()`          | Yes (public)             |
| `GetOwner()`            | `Lua_Companion::GetOwner()`                | Yes (public)             |
| `GetOwnerCharacterID()` | `Lua_Companion::GetOwnerCharacterID()`     | Yes (public)             |
| `GetRecruitedLevel()`   | `Lua_Companion::GetRecruitedLevel()`       | Yes (public)             |
| `GetRecruitedNPCTypeID()` | `Lua_Companion::GetRecruitedNPCTypeID()` | Yes (public)             |
| `GetStance()`           | `Lua_Companion::GetStance()`               | Yes (public)             |
| `GiveAll(client)`       | `Lua_Companion::GiveAll(Lua_Client)`       | Yes (public)             |
| `GiveSlot(client, name)`| `Lua_Companion::GiveSlot(Lua_Client, string)` | Yes (public)          |
| `Save()`                | `Lua_Companion::Save()`                    | Yes (public)             |
| `SetStance(stance)`     | `Lua_Companion::SetStance(int)`            | Yes (public)             |
| `ShowEquipment(client)` | `Lua_Companion::ShowEquipment(Lua_Client)` | Yes (public)             |
| `SoulWipe()`            | `Lua_Companion::SoulWipe()`                | Yes (public)             |
| `Suspend()`             | `Lua_Companion::Suspend()`                 | Yes (public)             |
| `Unsuspend()`           | `Lua_Companion::Unsuspend()`               | Yes (public)             |

All 18 methods are registered correctly. The `Dismiss()` binding in particular:
- Takes one `bool` parameter (`voluntary`), matching `companion.lua` call `npc:Dismiss(true)`
- Implementation at `lua_companion.cpp:90–94` calls `self->Dismiss(voluntary)` correctly
- C++ `Companion::Dismiss(bool permanent)` is declared public in `companion.h:156`

---

## CastToCompanion() — Correct

File: `/mnt/d/Dev/EQ/eqemu/zone/lua_entity.cpp`, lines 151–155

```cpp
Lua_Companion Lua_Entity::CastToCompanion() {
    void *d = GetLuaPtrData();
    Companion *c = reinterpret_cast<Companion*>(d);
    return Lua_Companion(c);
}
```

Registered in `lua_entity.cpp:170`:
```cpp
.def("CastToCompanion", &Lua_Entity::CastToCompanion)
```

`IsCompanion()` is also correctly bound at `lua_entity.cpp:84–87` and registered at line 182.

---

## Client Methods — Correct

File: `/mnt/d/Dev/EQ/eqemu/zone/lua_client.cpp`

- `GetCompanionByNPCTypeID(npc_type_id)` — lines 3683–3695, registered at line 3846
- `HasActiveCompanion(npc_type_id)` — lines 3697–3709, registered at line 4009

Both iterate `entity_list.GetCompanionList()` correctly.

---

## lua_parser Registration — Correct

File: `/mnt/d/Dev/EQ/eqemu/zone/lua_parser.cpp`, line 1351

```cpp
lua_register_companion(),
```

`Lua_Companion` is registered in the luabind scope alongside all other types.
The class hierarchy is: `luabind::class_<Lua_Companion, Lua_Mob>("Companion")`.

---

## Root Cause: e.self Is Typed as Lua_NPC, Not Lua_Companion

**This is the definitive root cause of BUG-004.**

File: `/mnt/d/Dev/EQ/eqemu/zone/lua_parser.cpp`, line 507:

```cpp
Lua_NPC l_npc(npc);
luabind::adl::object l_npc_o = luabind::adl::object(L, l_npc);
l_npc_o.push(L);
lua_setfield(L, -2, "self");
```

The NPC event dispatcher always wraps the NPC pointer as `Lua_NPC` and pushes it
as `e.self`. There is **no companion-specific event path** in `lua_parser.cpp` —
there is no `CompanionArgumentDispatch` and no conditional to push `Lua_Companion`
when the NPC is a companion.

The luabind class hierarchy is:
```
Lua_Mob (base)
  +-- Lua_NPC      ("NPC" in Lua)
  +-- Lua_Companion ("Companion" in Lua)
```

`Lua_NPC` and `Lua_Companion` are **sibling classes**, not parent/child. luabind
performs type-based dispatch on the registered `Lua_NPC` type object, so methods
registered only on `Lua_Companion` (including `Dismiss`, `SetStance`,
`ShowEquipment`, `GiveSlot`, `GiveAll`, `SoulWipe`, `Suspend`, `Unsuspend`) are
**not accessible** via `e.self` even though the underlying pointer is a `Companion`.

In `global_npc.lua`:
```lua
if e.self:IsCompanion() and companion_lib.is_management_keyword(e.message) then
    companion_lib.handle_command(e.self, e.other, e.message)
```

The call `e.self:IsCompanion()` works (it is bound on `Lua_Entity`, the ancestor
of `Lua_NPC`). But passing `e.self` to `companion_lib.handle_dismiss(npc, client)`,
which then calls `npc:Dismiss(true)`, fails because the luabind type of `npc` is
`Lua_NPC` and `Dismiss` is not registered there.

---

## Additionally Missing: StopMoving

`companion.lua:handle_follow()` calls `npc:StopMoving()` (line 474 in guard handler).
`StopMoving` is **not registered in any Lua binding file** — not on `Lua_NPC`,
`Lua_Mob`, or `Lua_Companion`. This will cause a second Lua error when the
companion's guard command is used.

---

## Recommended Fix

Two options, one in C++ and one in Lua:

### Option A: Push Lua_Companion in lua_parser.cpp (C++ fix)
In `lua_parser.cpp` around line 507, check if the NPC is a companion and push
the appropriate type:

```cpp
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

This is the cleanest fix: `e.self` becomes a proper `Lua_Companion` object when
the NPC is a companion, so all companion methods are accessible without any
Lua-side workaround.

`CastToCompanion()` is already implemented and ready on `Lua_Entity`.

### Option B: Cast in Lua (Lua fix, no C++ change)
In `companion.lua`, replace uses of `npc` with a cast:

```lua
function companion.handle_dismiss(npc, client)
    local companion_obj = npc:CastToCompanion()
    companion_obj:Say("Farewell.")
    companion_obj:Dismiss(true)
end
```

This avoids touching `lua_parser.cpp` but requires updating every function in
`companion.lua` that calls companion-specific methods on `npc`. More code churn
but no rebuild required if the cast is already working.

**Recommendation: Option A** — fix the type at the push site in `lua_parser.cpp`.
It is one small change, requires a rebuild, and correctly propagates the type
everywhere without requiring Lua script changes across multiple call sites.

---

## Files Examined

| File | Path |
|------|------|
| Lua binding declarations | `/mnt/d/Dev/EQ/eqemu/zone/lua_companion.h` |
| Lua binding implementations | `/mnt/d/Dev/EQ/eqemu/zone/lua_companion.cpp` |
| Entity cast/type bindings | `/mnt/d/Dev/EQ/eqemu/zone/lua_entity.cpp` |
| Client companion bindings | `/mnt/d/Dev/EQ/eqemu/zone/lua_client.cpp` |
| Parser registration + event push | `/mnt/d/Dev/EQ/eqemu/zone/lua_parser.cpp` |
| C++ class declaration | `/mnt/d/Dev/EQ/eqemu/zone/companion.h` |
| C++ Dismiss() implementation | `/mnt/d/Dev/EQ/eqemu/zone/companion.cpp` |
| Lua dismiss caller | `/mnt/d/Dev/EQ/akk-stack/server/quests/lua_modules/companion.lua` |
| Global NPC event entry point | `/mnt/d/Dev/EQ/akk-stack/server/quests/global/global_npc.lua` |
