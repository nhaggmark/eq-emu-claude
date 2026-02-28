# BUG-001 Diagnosis: C++ Expert Findings

## Summary

The root cause is a **name mismatch between the spawn packet and the group
packet**. The previous fix (commit `26056651d`) placed the name correction in
`Companion::Spawn()`, but that method is **never called** — both code paths
that spawn companions call `entity_list.AddCompanion()` directly, bypassing
`Spawn()` entirely.

---

## How Group Targeting Works

1. The Titanium client receives group member names via `OP_GroupUpdate`
   (`GroupJoin_Struct.membername` field). Names are stored as strings.

2. The client also receives spawn data via `OP_ZoneSpawns` / `OP_NewSpawn`
   (`Spawn_Struct.name` field). Each spawn has a `spawnId` (entity ID).

3. When the player clicks a name tile in the Group Window, the **client
   resolves the group member name to an entity ID by matching the name
   against its local spawn list**. It then sends `OP_TargetCommand` with
   the entity ID.

4. If the names don't match, the client cannot find the spawn and sends
   nothing — this is the observed bug.

---

## What Is Broken

### The Name Mismatch

**Spawn packet name**: `Guard_Liben001` (raw `name` field after NPC constructor)
**Group packet name**: `Guard Liben` (from `GetCleanName()`)

These do not match. The client cannot associate the group window entry with
the in-world entity.

### Why the Previous Fix Failed

Commit `26056651d` added this code to `Companion::Spawn()` (line 483):

```cpp
strcpy(name, GetCleanName());
```

This is the correct fix conceptually (mirrors Bot::Spawn at bot.cpp:3605).
However, `Companion::Spawn()` is **dead code** — it is never called from
any code path:

1. **Lua recruitment path** (`lua_client.cpp:3654`): Calls
   `entity_list.AddCompanion(companion, true, true)` directly, then
   `companion->CompanionJoinClientGroup()`. Never calls `Spawn()`.

2. **Zone-in path** (`companion.cpp:1715`): Calls
   `entity_list.AddCompanion(companion)` directly, then
   `companion->CompanionJoinClientGroup()`. Never calls `Spawn()`.

Since `Spawn()` is never invoked, the `strcpy(name, GetCleanName())` fix
never executes. The `name` field retains the MakeNameUnique-suffixed value
(e.g. `Guard_Liben001`) when the spawn packet is sent.

### The Name Pipeline in Detail

1. `Companion` constructor -> `NPC` constructor (npc.cpp:312-313):
   - `EntityList::RemoveNumbers(name)` strips trailing digits
   - `entity_list.MakeNameUnique(name)` appends `001` suffix
   - Result: `name` = `Guard_Liben001`

2. `GetCleanName()` first call (mob.cpp:5149-5156):
   - `CleanMobName(GetName(), clean_name)` converts `_` to ` `, strips digits
   - Result: `clean_name` = `Guard Liben` (cached permanently)

3. `entity_list.AddCompanion()` (companion.cpp:1596-1604):
   - Calls `CreateSpawnPacket` or `FillSpawnStruct`
   - `Mob::FillSpawnStruct` (mob.cpp:1285): `strcpy(ns->spawn.name, name)`
   - Spawn packet name = `Guard_Liben001`

4. `Group::AddMember()` (groups.cpp:260):
   - `new_member_name = new_member->GetCleanName()`
   - Group packet name = `Guard Liben`

5. Mismatch: `Guard_Liben001` (spawn) != `Guard Liben` (group)

---

## Hypothesis

The fix logic is correct but placed in the wrong location. The
`strcpy(name, GetCleanName())` call must execute BEFORE
`entity_list.AddCompanion()` sends the spawn packet. It should be placed
in one of:

- The Lua `CreateCompanion` method (`lua_client.cpp`)
- The `SpawnCompanionsOnZone` method (`companion.cpp`)
- Or better: inside `entity_list.AddCompanion()` itself

---

## Suggested Fix

### Option A: Fix at the AddCompanion call sites (minimum change)

Add `strcpy(companion->name, companion->GetCleanName())` before each
`entity_list.AddCompanion()` call:

1. `lua_client.cpp:3654` — before `entity_list.AddCompanion(companion, true, true)`
2. `companion.cpp:1715` — before `entity_list.AddCompanion(companion)`

### Option B: Fix inside AddCompanion (single point, defensive)

Add the name cleanup inside `EntityList::AddCompanion()` itself
(companion.cpp:1580) before the spawn packet is sent:

```cpp
void EntityList::AddCompanion(Companion* new_companion, bool send_spawn_packet, bool dont_queue)
{
    if (!new_companion) { return; }

    // Ensure the spawn name matches the clean name so the Titanium client
    // can associate the group window entry with the in-world entity.
    strcpy(new_companion->name, new_companion->GetCleanName());

    new_companion->SetID(GetFreeID());
    // ... rest of method
}
```

### Option C: Move Spawn() logic into AddCompanion and have callers use Spawn()

Refactor so all callers use `Companion::Spawn()` which handles name cleanup,
AddCompanion, and group join in the correct order.

### Recommendation

**Option B** is the safest — it guarantees that every companion spawn packet
has the correct name, regardless of which code path creates the companion. It
is a single-line addition in one location.

Additionally, the dead `Companion::Spawn()` method should either be:
- Removed (if its logic is absorbed into AddCompanion), or
- Made the sole entry point that callers use (Option C)

### Additional Concern: clean_name Cache Invalidation

Protocol-agent raised a concern about `clean_name` cache invalidation.
Analysis:

After `strcpy(name, GetCleanName())`, `name` becomes `Guard Liben` and
`clean_name` (cached) is `Guard Liben`. `CleanMobName("Guard Liben")`
produces `Guard Liben` (spaces preserved, no digits to strip). The cache
is always consistent with the new `name` value. **No invalidation needed.**

Both current code paths (Lua recruitment and zone-in) call `AddCompanion`
before anything calls `GetCleanName()`, so the cache is computed from the
original MakeNameUnique name, but the resulting clean name is identical
regardless of whether we compute from `Guard_Liben001` or `Guard Liben`.

For defensive safety, adding `clean_name[0] = '\0'` before the `strcpy`
would force recomputation, but it is not strictly required.

---

## Protocol-Agent Confirmation (2026-02-27)

Protocol-agent independently confirmed the same root cause. Key additional
findings from their analysis:

1. There are **no ENCODE/DECODE entries** for group packets in the Titanium
   translation layer -- packets pass through unchanged.
2. The client searches its local spawn list by exact name match to resolve
   group member clicks to entity IDs.
3. Both agents agree the fix must be placed where it actually executes before
   the spawn packet is sent.

---

## Files Involved

| File | Line(s) | Role |
|------|---------|------|
| `zone/companion.cpp:470-497` | `Companion::Spawn()` — dead code, fix unreachable |
| `zone/companion.cpp:1580-1609` | `EntityList::AddCompanion()` — sends spawn packet |
| `zone/companion.cpp:640-727` | `CompanionJoinClientGroup()` — adds to group |
| `zone/companion.cpp:1715` | Zone-in spawn path (bypasses `Spawn()`) |
| `zone/lua_client.cpp:3654` | Lua recruitment path (bypasses `Spawn()`) |
| `zone/groups.cpp:260` | `Group::AddMember()` — uses `GetCleanName()` for group name |
| `zone/groups.cpp:1285` | `Mob::FillSpawnStruct()` — uses raw `name` for spawn packet |
| `zone/npc.cpp:312-313` | NPC constructor `MakeNameUnique` — source of suffix |

---

## Protocol Questions for protocol-agent

1. Does the Titanium client do case-sensitive or case-insensitive name matching
   when resolving group member clicks to entity IDs?

2. Are there any known issues with spaces in NPC spawn names for the Titanium
   client? (NPCs normally have underscores which the client renders as spaces,
   but we'd be sending literal spaces in the name field.)

3. Does the `Spawn_Struct.NPC` field (value 1 for NPCs) affect how the client
   handles group window targeting? Could the client ignore NPC-flagged spawns
   when resolving group member names?
