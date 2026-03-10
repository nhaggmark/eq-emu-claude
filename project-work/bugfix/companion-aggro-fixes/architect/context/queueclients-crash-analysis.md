# QueueClients Crash Analysis (BUG-011 Recurrence)

## Crash Details

**Stack trace:**
```
#3  0x000063913dbb4da0 in ?? ()
#4  Group::QueueClients (this=..., sender=...) at groups.cpp:2600
#5  Client::Handle_OP_ClientUpdate at client_packet.cpp:5062
```

**Context:** Player zoned into Oasis of Marr with 3 companions. Crash occurred shortly after, during a movement update packet.

**Crash location:** `groups.cpp:2600` — `if (!members[i]->IsClient())` — after the null check at line 2597.

## Root Cause: Use-After-Free (Dangling Pointer)

### Why the existing null check is insufficient

`QueueClients()` at groups.cpp:2593-2622 already has a null check:
```cpp
if (!members[i])      // line 2597 — null check
    continue;
if (!members[i]->IsClient())  // line 2600 — CRASH HERE
    continue;
```

The crash at line 2600 means `members[i]` is **non-null but dangling** — it points to an object that has been `delete`d. When `IsClient()` (a virtual method) is called, the code follows the vtable pointer at the start of the freed object. The vtable pointer has been overwritten with garbage (`0x000063913dbb4da0`), causing a segfault.

### How companions leave dangling group pointers

The `Group::members[]` array stores raw `Mob*` pointers. When a companion is destroyed, the pointer MUST be nulled in members[]. Several code paths handle this:

1. **Companion::Death()** (BUG-011 fix) — calls `MemberZoned(this)` which nulls the member slot. **Working correctly.**

2. **MobProcess cleanup** (entity.cpp:569-578) — safety net that calls `MemberZoned()` before `safe_delete`. **Working correctly.**

3. **Companion::Depop()** — calls `RemoveCompanionFromGroup()` which calls either `DelMember()` (nulls slot) or `DisbandGroup()` (nulls all + deletes group). **Working correctly for companions.**

4. **NPC constructor** (npc.cpp:137-140) — **DANGEROUS PATH:**
   ```cpp
   Mob *mob = entity_list.GetMob(name);
   if (mob != nullptr) {
       entity_list.RemoveEntity(mob->GetID());
   }
   ```
   If a newly-constructed NPC/Companion has the same uniquified name as an existing mob, `RemoveEntity()` calls `RemoveMob()` which `safe_delete`s the existing mob **without any group cleanup**. This creates a dangling pointer in `members[]`.

5. **RemoveMob() direct path** (entity.cpp:2806-2831) — Called from `RemoveEntity()` and other places. Does `safe_delete(it->second)` on the mob but performs NO group cleanup for companions. It checks npc_list and client_list for cleanup, but companions are in neither (they're in companion_list).

6. **VerifyGroup()** (groups.cpp:1263-1287) — Can SET `members[]` pointers by looking up mobs by name:
   ```cpp
   Mob *them = entity_list.GetMob(membername[i]);
   if (them != nullptr && members[i] != them) {
       members[i] = them;  // could point to wrong mob if name collision!
   }
   ```
   If a companion's clean name matches a regular NPC (e.g., "Guard Liben"), VerifyGroup could set `members[i]` to a regular NPC. When that NPC dies, no group cleanup runs for it.

### Most likely crash scenario

The most probable scenario for this specific crash:

1. Player zones into Oasis. `SendZoneInPackets()` at client_packet.cpp:1589-1644 loads the old group from the `group_id` database table. `LearnMembers()` populates `membername[]` with companion names from the previous zone. `VerifyGroup()` sets `members[]` to nullptr (companions not spawned yet).

2. `SpawnCompanionsOnZone()` spawns 3 companions. Each calls `CompanionJoinClientGroup()` which adds them to the existing group.

3. During companion construction (`new Companion(...)`), the NPC constructor at npc.cpp:137 calls `GetMob(name)`. If a zone NPC with the matching uniquified name exists, it gets `RemoveEntity()`'d — the zone NPC is deleted, but if it was erroneously set as a group member by `VerifyGroup()`, the pointer dangles.

4. Alternatively: `RemoveMob()` is called on a companion through some indirect path (e.g., `LimitRemoveNPC` for NPC spawn limit enforcement at entity.cpp:4293) without group cleanup.

5. Player moves, sending OP_ClientUpdate. `Handle_OP_ClientUpdate` calls `group->QueueClients()`. The iteration hits the dangling pointer and crashes.

## The Real Fix: Defensive Validation in ALL Group Iteration

Rather than trying to catch every code path that can invalidate a member pointer, the robust fix is to **validate member pointers at point of use** in every group iteration function.

### Validation approach

For each `members[i]` access, after the null check, verify the pointer points to a living entity:

```cpp
if (!members[i])
    continue;
// Validate the pointer is still a live entity
if (!entity_list.GetMob(members[i]->GetID()) || members[i]->GetID() == 0) {
    members[i] = nullptr;  // Self-healing: clear the stale pointer
    continue;
}
```

Or more efficiently, use a helper method on Group:

```cpp
// New method: Group::ValidateMember(uint32 index)
// Returns true if members[index] is a valid, living entity.
// If invalid, nulls the pointer and returns false.
bool Group::ValidateMember(uint32 index) {
    if (!members[index])
        return false;
    if (members[index]->GetID() == 0 ||
        !entity_list.GetMob(members[index]->GetID())) {
        members[index] = nullptr;
        return false;
    }
    return true;
}
```

### ALL group iteration functions that need this fix

Every function in groups.cpp that iterates `members[]` and dereferences the pointer is vulnerable. Here is the complete list:

| Function | Line(s) | Pattern | Risk |
|----------|---------|---------|------|
| `QueueClients()` | 2595-2620 | `members[i]->IsClient()`, `members[i]->CastToClient()` | **CRASHED HERE** |
| `GroupMessageString()` | 1291-1302 | `members[i]->IsClient()`, `members[i]->MessageString()` | High |
| `QueuePacket()` | 414-418 | `members[i]->IsClient()`, `members[i]->CastToClient()` | High |
| `SendHPManaEndPacketsTo()` | 428-477 | `members[i]->CreateHPPacket()`, `members[i]->GetID()` | High |
| `SendHPPacketsFrom()` | 463-477 | `members[i]->IsClient()`, `members[i]->CastToClient()` | High |
| `SendManaPacketFrom()` | 489-497 | `members[i]->IsClient()`, `members[i]->CastToClient()` | High |
| `SendEndurancePacketFrom()` | 510-517 | `members[i]->IsClient()`, `members[i]->CastToClient()` | High |
| `SplitExp()` | 142 | `members[i]->IsClient()` | Medium |
| `CastGroupSpell()` | 853-868 | `members[z] != nullptr`, `members[z]->CalcSpellPowerDistanceMod()` | High |
| `GroupMessage()` | 908-912 | `members[i]->IsClient()`, `members[i]->CastToClient()` | High |
| `GetTotalGroupDamage()` | 932-935 | `members[i]`, `other->GetHateAmount(members[i])` | Medium |
| `DisbandGroup()` | 957-1008 | `members[ci]->IsCompanion()`, `members[i]->IsClient()`, `members[i]->IsMerc()` | Medium |
| `SendUpdate()` | 1113-1122 | `members[i]->GetName()`, `members[i]->GetCleanName()` | High |
| `TeleportGroup()` | 1208 | `members[i]->IsClient()`, `members[i]->CastToClient()` | Medium |
| `VerifyGroup()` | 1270-1286 | `members[i]` (but this one tries to fix pointers) | Already handles |
| `BalanceHP()` | 1391-1456 | `members[gi]`, `members[gi]->GetMaxHP()`, `members[gi]->SetHP()` | Medium |
| `BalanceMana()` | 1478-1511 | `members[gi]`, `members[gi]->GetMaxMana()`, `members[gi]->SetMana()` | Medium |
| `HealGroup()` | 1402-1406 | `members[gi]`, `members[gi]->HealDamage()` | Medium |
| `DelegateMainTank()` | 1637-1641 | `members[i]->IsClient()`, `members[i]->CastToClient()` | Medium |
| `DelegateMainAssist()` | 1683-1687 | `members[i]->IsClient()`, `members[i]->CastToClient()` | Medium |
| `DelegatePuller()` | 1730-1734 | `members[i]->IsClient()`, `members[i]->CastToClient()` | Medium |
| `UnDelegateMainTank()` | 1899-1903 | `members[i]->IsClient()`, `members[i]->CastToClient()` | Medium |
| `UnDelegateMainAssist()` | 1933-1953 | `members[i]->IsClient()`, `members[i]->CastToClient()` | Medium |
| `UnDelegatePuller()` | 1976-1980 | `members[i]->IsClient()`, `members[i]->CastToClient()` | Medium |
| `SetGroupAssistTarget()` | 2011-2013 | `members[i]->IsClient()` | Low |
| `SetGroupTankTarget()` | 2024-2026 | `members[i]->IsClient()` | Low |
| `SetGroupPullerTarget()` | 2037-2039 | `members[i]->IsClient()` | Low |
| `MarkNPC()` | 2129-2130 | `members[i]->IsClient()` | Low |
| `UpdateGroupAAs()` | 2206-2207 | `members[i]->IsClient()` | Low |
| `ClearAllNPCMarks()` | 2310-2311 | `members[i]->IsClient()` | Low |
| `GetNumberNeedingHealedInGroup()` | 2332-2338 | `members[i]->qglobal`, `members[i]->GetHPRatio()` | Medium |
| `QueueHPPacketsForNPCHealthAA()` | 2391-2395 | `members[i]->IsClient()`, `members[i]->GetTarget()` | Medium |
| `ChangeLeader()` | 2422-2427 | `members[i]->IsClient()`, `members[i]->CastToClient()` | Medium |
| `UpdateXTargetMarkedNPC()` | 2442-2444 | `members[i]->IsClient()`, `members[i]->CastToClient()` | Low |
| `SetDirtyAutoHaters()` | 2452-2453 | `members[i]->IsClient()` | Low |
| `JoinRaidXTarget()` | 2462-2463 | `members[i]->IsClient()` | Low |
| `GetMemberRole(Mob*)` | 2543, 2558 | `m == members[i]` | Low (ptr compare only) |
| `AnyMemberHasDzLockout()` | 2629-2633 | `members[i]->IsClient()` | Low |
| `AddMember()` | 244-253, 287, 309-327 | `members[slot_id]->IsCompanion()`, `members[slot_id]->IsClient()` | Medium |
| `DelMember()` | 693, 721-725, 756-763 | `members[i] == oldmember`, `members[nl]->IsClient()` | Medium |
| `RemoveCompanionFromGroup()` (companion.cpp) | 1089-1093 | `group->members[i]->IsClient()` | Medium |

**Total: ~35+ iteration patterns** that dereference `members[]` entries.

## Also affected: entity.cpp iteration with companion handling

In `entity.cpp` at line 2090-2096 (`attack.cpp` group loot allowance):
```cpp
auto* group = entity_list.GetGroupByClient(killer_mob->CastToClient());
if (group) {
    for (int i = 0; i < 6; i++) {
        if (group->members[i]) {
            new_corpse->AllowPlayerLoot(group->members[i], i);
        }
    }
}
```
This dereferences `members[i]` to call `AllowPlayerLoot` which takes a `Mob*`. If `members[i]` is dangling, `AllowPlayerLoot` receives a garbage pointer.

## Proposed Fix

### Option A: ValidateMember helper (recommended)

Add a `ValidateMember()` method to Group that checks the pointer against the entity list. Replace all `if (!members[i]) continue;` patterns with `if (!ValidateMember(i)) continue;`.

This is self-healing: once a dangling pointer is detected, it's nulled, preventing future crashes on subsequent iterations.

### Option B: VerifyGroup before every iteration (simpler but slower)

Call `VerifyGroup()` at the start of every iteration function. This is simpler but adds overhead since VerifyGroup does an entity_list lookup for each member.

### Option C: Observer pattern (cleanest but most invasive)

Register the group with the entity list so that when any mob is destroyed, the entity list automatically nulls any group member pointers pointing to it. This is the cleanest solution but requires significant refactoring.

### Recommendation

**Option A** is the best balance of safety and performance. The `entity_list.GetMob(id)` lookup is O(1) on a hash map, so the overhead is minimal. The self-healing behavior means that even if new code paths are added that fail to clean up group pointers, the group iteration won't crash.

Additionally, the **NPC constructor at npc.cpp:137-140** should be fixed to call `MemberZoned()` before `RemoveEntity()` if the mob being removed is in a group:

```cpp
Mob *mob = entity_list.GetMob(name);
if (mob != nullptr) {
    Group* g = entity_list.GetGroupByMob(mob);
    if (g) {
        g->MemberZoned(mob);
    }
    entity_list.RemoveEntity(mob->GetID());
}
```

And `EntityList::RemoveMob()` should add group cleanup as a catch-all:

```cpp
bool EntityList::RemoveMob(uint16 delete_id)
{
    // ... existing code ...
    if (it->second) {
        // Catch-all: ensure group pointers are cleared before deletion
        Group* g = GetGroupByMob(it->second);
        if (g) {
            g->MemberZoned(it->second);
        }
        safe_delete(it->second);
    }
    // ...
}
```

## Risk Assessment

- **Without fix:** Server will continue to crash whenever a group member pointer becomes dangling. The BUG-011 death fix only covers one specific code path. Other paths (NPC constructor, RemoveMob, RemoveEntity, zone-in group reconstruction) remain vulnerable.

- **With fix:** All group iterations become safe against dangling pointers. The self-healing behavior means that stale pointers are detected and cleared on first encounter, preventing cascading failures.

- **Performance impact:** Negligible. One `GetMob(id)` O(1) lookup per member per iteration, in functions that already do far more expensive operations (packet serialization, distance calculations, etc.).

## Files to Modify

1. **`zone/groups.h`** — Add `ValidateMember(uint32 index)` method declaration
2. **`zone/groups.cpp`** — Implement `ValidateMember()` and update all ~35 iteration patterns
3. **`zone/npc.cpp`** — Add group cleanup in NPC constructor's name-collision removal (line 137-140)
4. **`zone/entity.cpp`** — Add group cleanup in `RemoveMob()` as a catch-all (line 2806-2831)
5. **`zone/companion.cpp`** — RemoveCompanionFromGroup iteration at line 1089-1093 needs validation

## Verification Plan

1. Zone into any zone with companions — verify no crash on movement
2. Zone between multiple zones rapidly with companions — stress the zone-in path
3. Have a companion die in combat — verify BUG-011 fix still works
4. Dismiss a companion while grouped — verify group updates correctly
5. Suspend/unsuspend companions — verify group pointer management
6. Use `#depopzone` command with companions in group — verify cleanup
