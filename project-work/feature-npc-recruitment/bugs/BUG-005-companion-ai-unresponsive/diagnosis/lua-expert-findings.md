# BUG-005 Lua Expert Findings: Companion Command Handlers

## Files Examined

- `/mnt/d/Dev/EQ/akk-stack/server/quests/lua_modules/companion.lua`
- `/mnt/d/Dev/EQ/akk-stack/server/quests/global/global_npc.lua`
- `/mnt/d/Dev/EQ/eqemu/zone/lua_companion.cpp`
- `/mnt/d/Dev/EQ/eqemu/zone/lua_companion.h`
- `/mnt/d/Dev/EQ/eqemu/zone/lua_parser.cpp` (lines 495-544)
- `/mnt/d/Dev/EQ/eqemu/zone/lua_mob.cpp` (StopMoving binding)
- `/mnt/d/Dev/EQ/eqemu/zone/lua_npc.cpp` (SetFollowDistance binding)
- `/mnt/d/Dev/EQ/eqemu/zone/lua_entity.cpp` (IsCompanion binding)

---

## Summary

The BUG-004 fix (pushing `e.self` as `Lua_Companion` for companion NPCs) is confirmed
present and correct in `lua_parser.cpp`. The `handle_command()` routing in `global_npc.lua`
is correct. The stance mapping and argument types are correct.

**Two bugs found. One is a definite blocker. One is a likely blocker.**

---

## Bug 1 (DEFINITE BLOCKER): `handle_follow()` calls `SetFollowDistance()` on a `Lua_Companion`

### The Problem

`handle_follow()` in `companion.lua` line 467 calls:

```lua
npc:SetFollowDistance(10)
```

`SetFollowDistance` is a method on `Lua_NPC` (declared in `lua_npc.h`, registered in
`lua_npc.cpp`). The luabind class registration for `Lua_NPC` is:

```cpp
luabind::class_<Lua_NPC, Lua_Mob>("NPC")
```

The luabind class registration for `Lua_Companion` is:

```cpp
luabind::class_<Lua_Companion, Lua_Mob>("Companion")
```

`Lua_Companion` inherits from `Lua_Mob`, NOT from `Lua_NPC`. `SetFollowDistance` is not
present in the `Lua_Companion` binding and is not inherited through `Lua_Mob`. When Lua
calls `npc:SetFollowDistance(10)` on a `Lua_Companion` object, luabind cannot resolve the
method and throws an error at runtime.

This error is silent if Lua pcall swallows it (which it does — the pcall in `lua_parser.cpp`
only logs to zone log, not to the player), so the player sees nothing happen and no error
is displayed.

Note: `StopMoving()` used by `handle_guard()` IS inherited correctly — it is on `Lua_Mob`
which `Lua_Companion` extends. That call is safe.

### Impact

- `handle_follow()` crashes at the `SetFollowDistance` call
- The "I will follow." Say line fires first (before the crash), so the NPC speaks but
  nothing changes in AI behavior — this matches the reported symptom "commands have no effect"
- Whether this also prevents `handle_guard()` from working depends on whether the pcall
  catches the follow error and resets any state

### Fix Options

Option A (preferred): Add `SetFollowDistance` to `Lua_Companion` binding in
`lua_companion.cpp` and `lua_companion.h`. Requires C++ change + rebuild.

Option B (Lua workaround): Remove the `SetFollowDistance` call from `handle_follow()`.
Follow behavior after guard can be controlled purely through companion_ai.cpp by reading
companion stance — no Lua call needed if C++ AI handles re-follow on its own.

---

## Bug 2 (LIKELY BLOCKER): `handle_guard()` calls `StopMoving()` but does not set a guard flag

### The Problem

`handle_guard()` in `companion.lua` lines 472-475:

```lua
function companion.handle_guard(npc, client)
    npc:Say("I will hold here.")
    npc:StopMoving()
end
```

`StopMoving()` halts current movement momentarily. On `Lua_Mob` it calls the C++
`Mob::StopMoving()` which clears the movement queue. However, the companion_ai tick loop
(in `companion_ai.cpp`) will immediately re-issue movement commands on the next AI tick
(typically 100-600ms) because the AI has no persistent "guard mode" state set.

The result: the companion stops briefly then resumes following on the next AI pulse.
This matches the symptom of "guard has no effect."

### How This Should Work

The `Companion` C++ class has a `stance` field (0=passive, 1=balanced, 2=aggressive). There
is no separate guard/follow mode persisted on the companion object in the Lua-accessible API.
`handle_guard()` needs to signal to `companion_ai.cpp` that the companion should hold position.

Possible approaches:

Option A: Add a `SetGuardMode(bool)` method (or equivalent) to `Companion` C++ class,
expose it via `Lua_Companion`, and call it from `handle_guard()`.

Option B: Use an entity variable to signal guard mode and have `companion_ai.cpp` check it
on each tick. Example: `npc:SetEntityVariable("companion_guard", "1")` in `handle_guard()`,
and clear it in `handle_follow()`.

Option C: If `companion_ai.cpp` already uses stance=0 (passive) to mean "don't chase
enemies and hold position", then guard could be implemented by setting stance to passive
temporarily. But this conflates two separate concerns.

---

## What IS Working Correctly

### Routing (global_npc.lua)

```lua
-- global_npc.lua lines 9-14
if e.self:IsCompanion() and companion_lib.is_management_keyword(e.message) then
    companion_lib.handle_command(e.self, e.other, e.message)
    return
end
```

The `IsCompanion()` check works — it is registered on `Lua_Entity` which is the base of
the entire hierarchy. The keyword routing is correct. After BUG-004, `e.self` is pushed as
`Lua_Companion` (confirmed in `lua_parser.cpp` lines 509-513), so companion-specific
methods are available.

### Stance Mapping (handle_stance)

```lua
-- companion.lua lines 416-423
elseif msg:find("passive", 1, true) then
    companion.handle_stance(npc, client, 0)
elseif msg:find("aggressive", 1, true) then
    companion.handle_stance(npc, client, 2)
elseif msg:find("balanced", 1, true) or msg:find("stance", 1, true) then
    companion.handle_stance(npc, client, 1)
```

Mapping is correct: "passive" -> 0, "balanced" -> 1, "aggressive" -> 2.

### SetStance argument type

```lua
-- companion.lua line 460
npc:SetStance(stance)   -- stance is an integer 0/1/2
```

C++ binding:
```cpp
void Lua_Companion::SetStance(int stance)  // lua_companion.h line 59
```

The type is `int` on the C++ side. Lua passes an integer (0, 1, or 2). This is correct.
`SetStance` IS registered on `Lua_Companion` (lua_companion.cpp line 174). This call
works correctly.

### Dismiss

```lua
-- companion.lua line 452
npc:Dismiss(true)   -- bool argument
```

`Dismiss(bool voluntary)` is registered on `Lua_Companion` (lua_companion.cpp line 162).
This call is correct.

### StopMoving (the call itself)

`StopMoving()` on `Lua_Mob` IS inherited by `Lua_Companion` through its luabind base class.
The call itself succeeds. The problem is it has no lasting effect (see Bug 2).

---

## Inheritance Chain Summary

```
Lua_Entity      -- IsCompanion(), IsBot(), IsClient(), etc.
    |
Lua_Mob         -- StopMoving(), StopNavigation(), WalkTo(), etc. (300 methods)
    |          \
Lua_NPC         Lua_Companion
  (100 methods)   (14 methods)
  SetFollowDistance  SetStance, Dismiss, SoulWipe, etc.
  SetFollowID
  SetFollowCanRun
```

`Lua_Companion` does NOT inherit `Lua_NPC`. Any `Lua_NPC`-specific method called
on a companion will fail at runtime.

---

## Recommended Fixes

### Fix for Bug 1 (SetFollowDistance missing on Lua_Companion)

In `lua_companion.h`, add:
```cpp
void SetFollowDistance(int dist);
void SetFollowID(int id);
void SetFollowCanRun(bool v);
```

In `lua_companion.cpp`, implement by casting to NPC:
```cpp
void Lua_Companion::SetFollowDistance(int dist) {
    Lua_Safe_Call_Void();
    // Companion IS-A NPC (via C++ class hierarchy), so this cast is safe
    self->CastToNPC()->SetFollowDistance(dist);
}
```

Register in `lua_register_companion()`:
```cpp
.def("SetFollowDistance", &Lua_Companion::SetFollowDistance)
.def("SetFollowID",       &Lua_Companion::SetFollowID)
.def("SetFollowCanRun",   &Lua_Companion::SetFollowCanRun)
```

Alternatively if the C++ Companion class directly extends NPC (likely), this could instead
be handled by changing the luabind base from `Lua_Mob` to `Lua_NPC`:
```cpp
luabind::class_<Lua_Companion, luabind::bases<Lua_Mob, Lua_NPC>>("Companion")
```
but this needs verification of the C++ class hierarchy from the c-expert.

### Fix for Bug 2 (guard mode not persisted)

Short-term Lua-only option: use entity variable as a guard flag that companion_ai.cpp checks.

In `handle_guard()`:
```lua
function companion.handle_guard(npc, client)
    npc:Say("I will hold here.")
    npc:SetEntityVariable("companion_guard_mode", "1")
    npc:StopMoving()
end
```

In `handle_follow()`:
```lua
function companion.handle_follow(npc, client)
    npc:Say("I will follow.")
    npc:SetEntityVariable("companion_guard_mode", "0")
    -- SetFollowDistance only after Bug 1 C++ fix lands
end
```

Then `companion_ai.cpp` checks `GetEntityVariable("companion_guard_mode")` on each tick
to decide whether to re-issue follow movement. This requires a coordinated c-expert change
to companion_ai.cpp.

---

## Testing Verification

To verify these handlers are reached when the player types "guard"/"passive"/etc:

Add `eq.debug()` calls at the top of each handler:
```lua
function companion.handle_guard(npc, client)
    eq.debug("handle_guard reached for " .. npc:GetName())
    npc:Say("I will hold here.")
    npc:StopMoving()
end
```

`eq.debug()` output appears in-game as `[Quest Debug][lua_debug]` messages, which are
visible to GM-flagged players. This confirms whether the routing is reaching the handler
before investigating the C++ behavior.
