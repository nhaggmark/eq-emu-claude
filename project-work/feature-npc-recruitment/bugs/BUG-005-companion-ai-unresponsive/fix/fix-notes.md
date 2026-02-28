# BUG-005 Fix Notes: Companion AI Unresponsive

**Date:** 2026-02-28
**Build result:** PASS (8/8 targets, clean link)

---

## Fix 1 (Critical): Hate List Wiped Every AI Tick

**File:** `/mnt/d/Dev/EQ/eqemu/zone/mob_ai.cpp` line 1067

**Root cause:** `Mob::AI_Process()` runs a periodic hate-list check that wipes NPC
hate lists to prevent faction wars. Companions satisfied all guard conditions:
`IsNPC()=true`, `GetSwarmInfo()=null`, `!IsPet()=true`, `GetNPCAggro()=false`.
Every `AI_target_check_timer` tick (2-4 seconds) their hate list was cleared,
making `IsEngaged()` perpetually false and the combat AI block never executing.

**Fix:** Added `!IsCompanion()` to the guard condition. `IsCompanion()` is a virtual
declared on `Entity` (entity.h:85), already accessible in mob_ai.cpp via its existing
`#include "zone/entity.h"`. No new includes needed.

```cpp
// Before:
if (
    IsNPC() &&
    !CastToNPC()->GetSwarmInfo() &&
    (!IsPet() || (HasOwner() && GetOwner()->IsNPC())) &&
    !CastToNPC()->GetNPCAggro()
) {
    WipeHateList(true);
}

// After:
if (
    IsNPC() &&
    !IsCompanion() &&                               // companions manage their own hate list
    !CastToNPC()->GetSwarmInfo() &&
    (!IsPet() || (HasOwner() && GetOwner()->IsNPC())) &&
    !CastToNPC()->GetNPCAggro()
) {
    WipeHateList(true);
}
```

---

## Fix 2 (Critical): Combat Assist Sets Target Without Populating Hate List

**File:** `/mnt/d/Dev/EQ/eqemu/zone/companion.cpp` ~line 420

**Root cause:** The combat assist block in `Companion::Process()` called `SetTarget()`
but never called `AddToHateList()`. `IsEngaged()` is defined as
`!hate_list.IsHateListEmpty()`, so without a hate list entry the companion was never
considered engaged, the `AI_Event_Engaged()` hook never fired, and combat AI never ran.

Additionally, the `IsAttackAllowed()` call was inverted: it checked if the enemy could
attack the companion rather than if the companion could attack the enemy.

**Fix:** Replaced the bare `SetTarget()` with the correct bot-pattern (`AddToHateList`
+ `SetTarget`), fixed the `IsAttackAllowed` call direction, and changed the entry guard
from "no target" to "not already engaged" to avoid re-targeting if already fighting.

```cpp
// Before (broken):
if (owner->GetTarget() && owner->GetTarget()->IsAttackAllowed(this)) {
    if (!GetTarget() || GetTarget() == owner) {
        SetTarget(owner->GetTarget());
    }
}

// After (fixed):
Mob* owner_target = owner->GetTarget();
if (owner_target && IsAttackAllowed(owner_target)) {
    if (!IsEngaged() || GetTarget() == nullptr) {
        AddToHateList(owner_target, 1);
        SetTarget(owner_target);
    }
}
```

---

## Fix 3 (High): Lua_Companion Missing NPC Follow Methods

**Files:**
- `/mnt/d/Dev/EQ/eqemu/zone/lua_companion.h`
- `/mnt/d/Dev/EQ/eqemu/zone/lua_companion.cpp`

**Root cause:** `Lua_Companion` inherits from `Lua_Mob`, not `Lua_NPC`. Methods like
`SetFollowDistance`, `SetFollowID`, and `SetFollowCanRun` are registered on `Lua_NPC`
(not `Lua_Mob`), so calling them on a companion in Lua caused a silent runtime error
(swallowed by pcall). The companion said "I will follow." but nothing changed.

**Fix:** Added the three follow methods directly to `Lua_Companion`. They delegate to the
corresponding `Mob` methods (which are inherited by `Companion` through the C++ hierarchy)
via `self->SetFollowDistance()` etc. Also added `zone/client.h` to the include list for
the `SetGuardMode` implementation (see Fix 4).

New methods added to `lua_companion.h` and implemented/registered in `lua_companion.cpp`:
- `SetFollowDistance(int dist)`
- `SetFollowID(int id)`
- `SetFollowCanRun(bool v)`

---

## Fix 4 (Medium): Guard Command Has No Persistent State

**Files:**
- `/mnt/d/Dev/EQ/eqemu/zone/lua_companion.h`
- `/mnt/d/Dev/EQ/eqemu/zone/lua_companion.cpp`
- `/mnt/d/Dev/EQ/akk-stack/server/quests/lua_modules/companion.lua`

**Root cause:** `handle_guard()` in companion.lua called `StopMoving()` which only
halts movement momentarily. On the next AI tick the companion re-issued follow movement
because no persistent guard state existed.

**Fix:** Added `SetGuardMode(bool enabled)` to `Lua_Companion` which uses the existing
`NPC::SaveGuardSpot()` infrastructure:
- `SetGuardMode(true)`: Calls `SaveGuardSpot(false)` (sets `m_GuardPoint` to current
  position, making `NPC::IsGuarding()` return true), then `SetFollowID(0)` and
  `StopMoving()`. With `IsGuarding()` true and no follow ID, `NPC::AI_DoMovement()`
  holds the guard point on every subsequent AI tick.
- `SetGuardMode(false)`: Calls `SaveGuardSpot(true)` (clears `m_GuardPoint`), then
  looks up the owner by character ID and restores follow ID, distance (100), and
  `FollowCanRun(true)`.

No new member variable was needed — the fix leverages `NPC::m_GuardPoint` (protected)
and the existing `IsGuarding()` check already present in `NPC::AI_DoMovement()`.

**companion.lua changes:**

```lua
-- Before:
function companion.handle_follow(npc, client)
    npc:Say("I will follow.")
    npc:SetFollowDistance(10)  -- crashed: SetFollowDistance not on Lua_Companion
end

function companion.handle_guard(npc, client)
    npc:Say("I will hold here.")
    npc:StopMoving()  -- no persistent state; AI re-enabled follow next tick
end

-- After:
function companion.handle_follow(npc, client)
    npc:Say("I will follow.")
    npc:SetGuardMode(false)  -- clears guard point, restores follow to owner
end

function companion.handle_guard(npc, client)
    npc:Say("I will hold here.")
    npc:SetGuardMode(true)  -- sets NPC guard point, clears follow ID (persistent)
end
```

---

## Files Modified

| File | Change |
|------|--------|
| `eqemu/zone/mob_ai.cpp` | Add `!IsCompanion()` to hate list wipe guard |
| `eqemu/zone/companion.cpp` | Fix `IsAttackAllowed` direction + add `AddToHateList` |
| `eqemu/zone/lua_companion.h` | Declare `SetFollowDistance`, `SetFollowID`, `SetFollowCanRun`, `SetGuardMode` |
| `eqemu/zone/lua_companion.cpp` | Implement and register all 4 new methods; add `zone/client.h` include |
| `akk-stack/server/quests/lua_modules/companion.lua` | `handle_follow` → `SetGuardMode(false)`, `handle_guard` → `SetGuardMode(true)` |

## Build

```
[1/8] Building CXX object zone/CMakeFiles/zone.dir/companion.cpp.o
[2/8] Building CXX object zone/CMakeFiles/zone.dir/mob_ai.cpp.o
[3/8] Building CXX object zone/CMakeFiles/lua_zone.dir/Unity/unity_2_cxx.cxx.o
[4/8] Building CXX object zone/CMakeFiles/lua_zone.dir/Unity/unity_3_cxx.cxx.o
[5/8] Building CXX object zone/CMakeFiles/lua_zone.dir/Unity/unity_1_cxx.cxx.o
[6/8] Building CXX object zone/CMakeFiles/lua_zone.dir/Unity/unity_0_cxx.cxx.o
[7/8] Linking CXX static library zone/liblua_zone.a
[8/8] Linking CXX executable bin/zone
```

Clean build. All 8 targets compiled and linked without errors or warnings.
