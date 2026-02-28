# BUG-005 C++ Expert Diagnosis: Companion AI Unresponsive

## Summary

Three distinct bugs prevent the companion AI from functioning. All are in
`zone/companion.cpp` and `zone/mob_ai.cpp`. None require architectural changes;
all are surgical fixes within existing patterns.

---

## Bug 1: Hate List Wiped Every AI Tick (CRITICAL — Root Cause of No Combat)

### Location
`zone/mob_ai.cpp`, `Mob::AI_Process()`, lines 1066–1074

### Code
```cpp
if (AI_target_check_timer->Check()) {
    if (
        IsNPC() &&
        !CastToNPC()->GetSwarmInfo() &&
        (!IsPet() || (HasOwner() && GetOwner()->IsNPC())) &&
        !CastToNPC()->GetNPCAggro()
    ) {
        WipeHateList(true); // wipe NPCs from hate list to prevent faction war
    }
    // ...
}
```

### Why It Hits Companions

The guard condition checks:
- `IsNPC()` — **true** (Companion inherits NPC and overrides to return true)
- `GetSwarmInfo()` — null (companions are not swarm pets)
- `!IsPet()` — **true** (companions are not pets; they use the pet system only for their own summoned pets)
- `GetNPCAggro()` — **false** (default value for NPCs loaded from npc_types without `aggro = 1` in the DB row; companion_data has no column for this)

All four conditions pass, so `WipeHateList(true)` fires every `AI_target_check_timer` tick (~2–4 seconds).

### Effect

`WipeHateList(true)` with `npc_only=true` (see `zone/hate_list.cpp:44`) removes all
hate-list entries where the hated entity is NOT `IsOfClientBotMerc()`. Enemy NPCs
attacking the player are never `IsOfClientBotMerc()`, so they are erased.

`IsEngaged()` is defined as:
```cpp
// zone/mob.h:785
bool IsEngaged() { return(!hate_list.IsHateListEmpty()); }
```

With an empty hate list, `IsEngaged()` returns false. The AI_Process engaged-combat
block never executes. The companion does nothing.

### Bots are Not Affected

Bots override `IsBot()` → true. Their hate list is managed in `Bot::AI_Process()`
(bot.cpp:~2600) which uses `XTargetAutoHaters` for assist logic rather than relying
on `Mob::AI_Process()`'s NPC code path. Bots do not hit the `WipeHateList` condition
because `(!IsPet() ...)` combined with `IsBot()` is handled differently.

### Fix

Add `!IsCompanion()` to the guard condition. This mirrors the existing `!CastToNPC()->GetSwarmInfo()` pattern for excluding special NPCs from the faction-war suppression logic.

```cpp
// zone/mob_ai.cpp — in Mob::AI_Process(), engaged block, AI_target_check_timer branch
if (
    IsNPC() &&
    !CastToNPC()->GetSwarmInfo() &&
    !IsCompanion() &&                          // ADD THIS LINE
    (!IsPet() || (HasOwner() && GetOwner()->IsNPC())) &&
    !CastToNPC()->GetNPCAggro()
) {
    WipeHateList(true);
}
```

---

## Bug 2: Combat Assist Sets Target Without Adding to Hate List

### Location
`zone/companion.cpp`, `Companion::Process()`, lines 420–429

### Code
```cpp
Client* owner = GetCompanionOwner();
if (owner && m_current_stance != COMPANION_STANCE_PASSIVE) {
    // If owner is in combat and we don't have a target, pick up owner's target
    if (owner->GetTarget() && owner->GetTarget()->IsAttackAllowed(this)) {
        if (!GetTarget() || GetTarget() == owner) {
            SetTarget(owner->GetTarget());
        }
    }
}
```

### Two Problems

**Problem A: `IsAttackAllowed` is called on the wrong object.**

The call `owner->GetTarget()->IsAttackAllowed(this)` asks: "is the owner's target
allowed to attack the companion?" That is the opposite of what is needed. The
correct call is `this->IsAttackAllowed(owner->GetTarget())`, which asks: "is the
companion allowed to attack the owner's target?"

**Problem B: `SetTarget()` alone does not engage combat.**

`SetTarget()` sets the companion's visual/movement target pointer. It does NOT
add the enemy to the companion's hate list. Without an entry on the hate list:
- `IsEngaged()` returns false
- `AI_Event_Engaged()` is never called
- `CombatEvent` is never set to true
- The AI's engaged combat block never executes

Correct pattern (from `Bot::TryAssistOwner`, bot.cpp ~3511):
```cpp
auto attack_target = bot_owner->GetTarget();
if (attack_target && IsAttackAllowed(attack_target)) {
    AddToHateList(attack_target, 1);
    SetTarget(attack_target);
    ...
}
```

### Fix

```cpp
// zone/companion.cpp — Companion::Process()
Client* owner = GetCompanionOwner();
if (owner && m_current_stance != COMPANION_STANCE_PASSIVE) {
    Mob* owner_target = owner->GetTarget();
    if (owner_target && IsAttackAllowed(owner_target)) {  // FIX: 'this' checks attack against target
        if (!IsEngaged() || !GetTarget()) {               // FIX: only intervene if not already fighting
            AddToHateList(owner_target, 1);               // FIX: populate hate list to trigger engagement
            SetTarget(owner_target);
        }
    }
}
```

---

## Bug 3: Guard Command Has No Effect

### Location
`zone/companion.cpp` — the Lua command `companion:guard()` presumably calls
`SetFollowID(0)` and some form of `SetGuardPoint()`. The issue is in what
happens next in `Mob::AI_Process()`.

### The Guard Code Path (mob_ai.cpp ~1657)
```cpp
} else if (IsGuarding()) {
    bool at_gp = IsPositionEqualWithinCertainZ(m_Position, m_GuardPoint, 15.0f);
    if (at_gp) {
        // stops and faces guard direction
    } else {
        NavigateTo(m_GuardPoint.x, m_GuardPoint.y, m_GuardPoint.z);
    }
}
```

`IsGuarding()` depends on having a guard point set via `SetGuardPoint()`. The
movement section `else if (AI_movement_timer->Check() && !IsRooted())` at line
1395 only enters the guard path if `IsPet()` is true AND the pet order is
`PetOrder::Guard`.

Companions are not pets, so `IsPet()` returns false. They do have `GetFollowID()`
set by `CompanionJoinClientGroup()`. When the guard command clears the follow ID,
the companion falls into the `else` branch at mob_ai.cpp:1506 (not a pet, not
following) and tries to roam on its grid — which it doesn't have — so it may do
nothing or jitter.

More importantly, the companion does have `IsGuarding()` available. Calling
`SetGuardPoint(x, y, z, heading)` plus clearing `SetFollowID(0)` should cause
the companion to navigate to and hold the guard point. The Lua `companion:guard()`
binding must call both:
1. `SetGuardPoint(companion->GetX(), companion->GetY(), companion->GetZ(), companion->GetHeading())`
2. `SetFollowID(0)`

If the Lua command only calls `SetFollowID(0)` without calling `SetGuardPoint()`,
then `IsGuarding()` returns false and the guard code never runs.

Check `zone/lua_companion.cpp` for the `guard()` binding implementation.

---

## Bug 4: Stance Change Has No Immediate Effect on Engaged AI

### Location
`zone/companion_ai.cpp` — class handlers check `m_current_stance` each tick.

### Analysis

`SetStance(stance)` updates `m_current_stance`. On the next AI tick, the class
handlers (`AI_Tank`, `AI_Cleric`, etc.) read `m_current_stance` and adjust spell
selection accordingly. This part works correctly by design.

**However**: Because Bug 1 (hate list wiped) means the companion is never engaged,
stance differences only manifest in the idle cast check (`AI_IdleCastCheck`). The
aggressive vs balanced distinction is meaningless if the companion never enters
combat. Fix Bug 1 first; stance behavior will then work as coded.

---

## AI Loop Execution Confirmation

The AI loop **IS running** for companions. Confirmed trace:

1. `main.cpp` calls `entity_list.MobProcess()` every loop iteration
2. `EntityList::MobProcess()` (`entity.cpp:481`) iterates `mob_list`
3. `EntityList::AddCompanion()` (`companion.cpp:1604`) adds companions to both
   `companion_list` AND `mob_list` (line 1612): `mob_list.emplace(..., new_companion)`
4. `MobProcess()` calls `mob->Process()` for each entry
5. `Companion::Process()` (`companion.cpp:391`) runs companion-specific timers,
   then calls `NPC::Process()` (`npc.cpp:572`)
6. `NPC::Process()` calls `AI_Process()` at line 799

So the AI loop calls are correct. The failures are in what happens inside the AI
loop, not in whether it runs at all.

---

## Pursuit Movement Bug (Secondary)

In `Mob::AI_Process()` engaged branch (`mob_ai.cpp:1342`):
```cpp
else if (AI_movement_timer->Check() && target &&
    (GetOwnerID() || IsBot() || IsTempPet() ||
    CastToNPC()->GetCombatEvent()))
```

Companions have:
- `GetOwnerID()` = 0 (pet owner system not used by companions)
- `IsBot()` = false
- `IsTempPet()` = false
- `CastToNPC()->GetCombatEvent()` = true (set when `AI_Event_Engaged` fires)

So once Bug 1 and Bug 2 are fixed and companions actually enter combat,
`GetCombatEvent()` will be set true by `AI_Event_Engaged`, and companions will
pursue their targets normally. No fix needed here — it will work once the hate
list is populated.

---

## Recommended Fix Priority

| # | Bug | Severity | File | Fix Complexity |
|---|-----|----------|------|----------------|
| 1 | Hate list wiped every tick | Critical | mob_ai.cpp | 1 line: add `!IsCompanion()` |
| 2 | SetTarget without AddToHateList | Critical | companion.cpp | 4 lines |
| 3 | Guard command wiring | Medium | lua_companion.cpp | Verify Lua binding |
| 4 | Stance behavioral nuance | Low | companion_ai.cpp | Fixed by Bug 1 fix |

---

## Specific Code Locations

| Issue | File | Lines |
|-------|------|-------|
| Hate list wipe condition | `zone/mob_ai.cpp` | 1066–1074 |
| IsEngaged definition | `zone/mob.h` | 785 |
| WipeHateList implementation | `zone/hate_list.cpp` | 44–73 |
| Companion::Process() combat assist | `zone/companion.cpp` | 420–431 |
| Bot combat assist pattern | `zone/bot.cpp` | 3511–3523 |
| AddCompanion + mob_list insertion | `zone/companion.cpp` | 1604–1633 |
| MobProcess iteration | `zone/entity.cpp` | 481–596 |
| NPC::Process() → AI_Process() | `zone/npc.cpp` | 799 |
| Mob::AI_Process() engaged pursuit | `zone/mob_ai.cpp` | 1342–1354 |
| AI_Event_Engaged for NPCs | `zone/mob_ai.cpp` | 1758–1796 |
