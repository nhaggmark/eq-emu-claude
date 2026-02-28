# BUG-001 Protocol-Level Diagnosis: Group Window Targeting Failure

**Agent:** protocol-agent
**Date:** 2026-02-27

---

## Summary

The Titanium client resolves group window clicks to targets by **matching the
group member name against spawn names** in the client's local entity list.
The companion's spawn packet name and group window name are **mismatched**,
causing the client to fail the name lookup silently.

---

## 1. How the Titanium Client Resolves Group Window Clicks to Targets

### Group Packets Contain Only Names, Not Entity IDs

The group update packets (`GroupJoin_Struct`, `GroupUpdate_Struct`) contain
**only character name strings** — no entity IDs, no spawn IDs:

```c
// common/eq_packet_structs.h:2497
struct GroupUpdate_Struct {
    uint32 action;
    char   yourname[64];
    char   membername[5][64];   // <-- names only, no entity IDs
    char   leadersname[64];
};

// common/eq_packet_structs.h:2515
struct GroupJoin_Struct {
    uint32 action;
    char   yourname[64];
    char   membername[64];      // <-- name only
    // ... leadership AA data, etc.
};
```

### The Client Must Do a Name-to-Entity Lookup

When you click a name tile in the Group Window, the Titanium client:

1. Reads the member name from the Group Window UI
2. Searches its local spawn list for a spawn whose `name` matches
3. If found, sends `OP_TargetMouse` with the spawn's entity ID

The `OP_TargetMouse` packet contains only a `uint32 new_target` (entity ID):

```c
// common/eq_packet_structs.h:1149
struct ClientTarget_Struct {
    uint32 new_target;  // Entity ID
};
```

### No Titanium-Specific Translation for Group Packets

I confirmed there are **no ENCODE/DECODE entries** for `OP_GroupUpdate`,
`OP_GroupFollow`, or `OP_GroupJoin` in `common/patches/titanium.cpp`. These
packets pass through the Titanium translation layer unchanged.

---

## 2. The Name Mismatch: Root Cause

### NPC Name Lifecycle

When an NPC (including a Companion) is constructed:

1. **NPC constructor** (`zone/npc.cpp:312-313`):
   ```cpp
   EntityList::RemoveNumbers(name);     // Strip any trailing digits
   entity_list.MakeNameUnique(name);    // Append 3-digit suffix: e.g., "000"
   ```
   Result: `name` = `"Guard_Quedal000"`

2. **`GetCleanName()`** (`zone/mob.cpp:5149-5156`):
   Calls `CleanMobName()` which replaces `_` with space and strips all
   non-alpha characters (including the `000` suffix):
   ```cpp
   // common/strings_legacy.cpp:197
   // - Converts '_' to ' '
   // - Strips digits, '#', and other non-alpha chars (except backtick)
   ```
   Result: `GetCleanName()` returns `"Guard Quedal"`

### What the Spawn Packet Sends

`Mob::FillSpawnStruct()` at `zone/mob.cpp:1285`:
```cpp
strcpy(ns->spawn.name, name);  // Copies raw name field
```

So the spawn packet contains: `"Guard_Quedal000"`

### What the Group Window Shows

`Group::AddMember()` at `zone/groups.cpp:303`:
```cpp
strcpy(gj->membername, new_member_name.c_str());
```
Where `new_member_name` is set from `GetCleanName()` at line 260:
```cpp
new_member_name = new_member->GetCleanName();
```

So the group window displays: `"Guard Quedal"`

### The Mismatch

| Source | Name Value |
|--------|-----------|
| Spawn packet (`Spawn_Struct.name`) | `Guard_Quedal000` |
| Group window (`GroupJoin_Struct.membername`) | `Guard Quedal` |

The client searches for `"Guard Quedal"` in its spawn list but finds only
`"Guard_Quedal000"`. **No match. No target.**

---

## 3. Why `Companion::Spawn()` Doesn't Fix It

The previous fix attempt (commit `26056651d`) added name cleanup to
`Companion::Spawn()` at `zone/companion.cpp:478-483`:

```cpp
// Companion::Spawn() — line 483
strcpy(name, GetCleanName());
```

**However, `Companion::Spawn()` is never called.** Both code paths that
create companions call `entity_list.AddCompanion()` directly:

1. **Initial recruitment** (`zone/lua_client.cpp:3647-3654`):
   ```cpp
   Companion* companion = Companion::CreateFromNPC(self, npc);  // NPC ctor: name = "Guard_Quedal000"
   entity_list.AddCompanion(companion, true, true);              // Sends spawn packet with raw name
   // ... later ...
   companion->CompanionJoinClientGroup();                        // Sends group packet with clean name
   ```

2. **Zone-in respawn** (`zone/companion.cpp:1693-1722`):
   ```cpp
   auto* companion = new Companion(npc_type, ...);    // NPC ctor: name = "Guard_Quedal000"
   entity_list.AddCompanion(companion);               // Sends spawn packet with raw name
   companion->CompanionJoinClientGroup();              // Sends group packet with clean name
   ```

Neither path calls `Companion::Spawn()`. The fix is dead code.

### How Bots Avoid This Problem

Bots call `Bot::Spawn()` (at `zone/bot.cpp:3597`) which contains the same
`strcpy(name, GetCleanName())` at line 3605, and this method IS actually
called from `bot_bot.cpp:992` before the bot joins a group:

```cpp
if (!my_bot->Spawn(c)) { ... }
```

After `Spawn()` runs, the bot's `name` field becomes `"Botname"` (matching
`GetCleanName()`), so the spawn packet and group window names are identical.

---

## 4. Additional Finding: `clean_name` Cache Invalidation

There's a subtle secondary issue. After `strcpy(name, GetCleanName())`, the
`clean_name` cache (`mob.cpp:5151`) would still hold the old clean value.
The `GetCleanName()` implementation only recomputes if `clean_name` is empty:

```cpp
const char *Mob::GetCleanName() {
    if (!strlen(clean_name)) {
        CleanMobName(GetName(), clean_name);
    }
    return clean_name;
}
```

So after changing `name`, the `clean_name` cache must be cleared (set to
empty string) to force recalculation. Otherwise subsequent `GetCleanName()`
calls would still return the old cached value. The Bot code works around
this because `Bot::Spawn()` runs early in the lifecycle before any call
to `GetCleanName()` populates the cache.

---

## 5. Secondary Finding: `is_npc` Field Mismatch

In addition to the name mismatch, there is a difference in how the spawn
packet marks companions vs bots:

| Entity | `Spawn_Struct.NPC` (offset 0083) | `Spawn_Struct.is_npc` (offset 0144) |
|--------|----------------------------------|-------------------------------------|
| Player | 0 | 0 |
| Bot | 1 (from Mob) | **0** (overridden in `Bot::FillSpawnStruct`, `bot.cpp:3807`) |
| Companion | 1 (from Mob) | **1** (NOT overridden — inherits from `NPC::FillSpawnStruct`, `npc.cpp:2171`) |

Bots explicitly override `is_npc = 0` and `is_pet = 0`, making them appear
"player-like" to the client. Companions do not. If the client uses `is_npc`
to filter which spawns are valid group member targets, this could be a
contributing factor (or even a blocking factor) for group window targeting.

Relevant code:
- `zone/npc.cpp:2171` — `ns->spawn.is_npc = 1;`
- `zone/bot.cpp:3807` — `ns->spawn.is_npc = 0;` (override)
- `zone/companion.cpp:459-464` — `Companion::FillSpawnStruct` does NOT override

---

## 6. Hypothesis and Recommended Fix

### Root Cause

`Companion::Spawn()` contains the correct name-normalization fix but is
**dead code** — never called by any code path.

### Recommended Fix

The name normalization (`strcpy(name, GetCleanName())`) must execute before
the spawn packet is sent. Two options:

**Option A (Minimal — c-expert's proposal):** Add
`strcpy(new_companion->name, new_companion->GetCleanName())` inside
`EntityList::AddCompanion()` before the spawn packet is sent. Single-line
fix in one location covers all code paths.

**Option B (Structural):** Refactor both code paths to call
`Companion::Spawn()` instead of calling `AddCompanion()` directly. This
mirrors the Bot pattern and keeps the spawn logic in one place. The
`Spawn()` method would need to also clear `clean_name[0]` after overwriting
`name`.

Option A is simpler and lower-risk. Option B is cleaner architecturally.

### Secondary Fix

Consider overriding `is_npc = 0` in `Companion::FillSpawnStruct`, mirroring
the Bot pattern (`bot.cpp:3807`). This makes the companion appear as a
"player-like" entity to the client, which may be needed for group window
targeting. Start with the name fix, test, and add `is_npc` override only
if needed.

### Verification

After the fix, the spawn packet's `Spawn_Struct.name` and the
`GroupJoin_Struct.membername` should both contain the same value
(e.g., `"Guard Quedal"`). The Titanium client will then successfully
match the group window name to the spawn and send `OP_TargetMouse` with
the correct entity ID.

---

## 7. Files Involved

| File | Lines | Role |
|------|-------|------|
| `zone/companion.cpp` | 470-497 | `Companion::Spawn()` — dead code with correct fix |
| `zone/companion.cpp` | 1693-1722 | Zone-in spawn path — bypasses `Spawn()` |
| `zone/lua_client.cpp` | 3639-3683 | `CreateCompanion` — recruitment path, bypasses `Spawn()` |
| `zone/mob.cpp` | 1281-1285 | `FillSpawnStruct` — copies raw `name` to spawn packet |
| `zone/mob.cpp` | 5149-5156 | `GetCleanName()` — strips underscores and digits |
| `zone/groups.cpp` | 260, 303 | `Group::AddMember` — uses `GetCleanName()` for group packet |
| `zone/npc.cpp` | 312-313 | NPC constructor — `MakeNameUnique` appends `000` suffix |
| `zone/entity.cpp` | 3248-3286 | `MakeNameUnique` — appends 3-digit numeric suffix |
| `common/eq_packet_structs.h` | 2497, 2515 | Group structs — name-only, no entity IDs |
| `common/eq_packet_structs.h` | 1149 | `ClientTarget_Struct` — entity ID for targeting |
| `common/strings_legacy.cpp` | 197-215 | `CleanMobName` — underscore→space, strip digits |
