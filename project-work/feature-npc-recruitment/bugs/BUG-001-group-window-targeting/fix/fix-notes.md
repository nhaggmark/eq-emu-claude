# BUG-001 Fix: Refactor Spawn Paths to Use Companion::Spawn()

**Agent:** c-expert
**Date:** 2026-02-27
**Fix type:** Option B (structural refactor)

---

## Root Cause (from diagnosis)

The companion's spawn packet name (`Guard_Liben001`) did not match the group
window name (`Guard Liben`). The Titanium client resolves group window clicks
to entity IDs by exact name matching against the spawn list. Name mismatch
means silent targeting failure.

The previous fix (commit `26056651d`) placed `strcpy(name, GetCleanName())`
inside `Companion::Spawn()`, but that method was **never called** -- both
code paths called `entity_list.AddCompanion()` directly.

---

## What Was Changed

### 1. `Companion::Spawn()` refactored as single entry point

**File:** `eqemu/zone/companion.cpp` (lines 476-520)

`Spawn()` now handles the full spawn lifecycle:
1. Sets owner character ID
2. Invalidates `clean_name` cache (`clean_name[0] = '\0'`)
3. Normalizes `name` to match `GetCleanName()` (strips underscores, digits)
4. Calls `entity_list.AddCompanion(this, true, true)` to assign entity ID and
   send the spawn packet
5. Calls `AI_Start()` to initialize AI and load companion spells
6. Calls `CompanionJoinClientGroup()` to join/create the owner's group

This mirrors `Bot::Spawn()` (`bot.cpp:3597`).

### 2. `Companion::FillSpawnStruct()` now overrides is_npc

**File:** `eqemu/zone/companion.cpp` (lines 459-470)

Added overrides mirroring `Bot::FillSpawnStruct()` (`bot.cpp:3807-3813`):
- `ns->spawn.is_npc = 0` (was inheriting 1 from NPC)
- `ns->spawn.is_pet = 0` (explicit, was already 0)
- `ns->spawn.NPC = 0` (was inheriting 1 from NPC; 0 = player-like)

This makes the Titanium client treat the companion as a player-like entity
for group window targeting purposes.

### 3. Lua recruitment path refactored

**File:** `eqemu/zone/lua_client.cpp` (lines 3647-3671)

Replaced direct calls to:
- `entity_list.AddCompanion(companion, true, true)`
- `companion->AI_Start()`
- `companion->CompanionJoinClientGroup()`

With a single call to:
- `companion->Spawn(self)`

Note: `Save()` is called BEFORE `Spawn()` because the DB record must exist
before group join operations. The source NPC `Depop(true)` remains outside
`Spawn()` because it is recruitment-specific logic.

Error handling changed from `companion->Depop()` to `delete companion` on
failure paths before `Spawn()`, since the companion is not yet in the entity
list and `Depop()` would try to remove a non-existent entity.

### 4. Zone-in path refactored

**File:** `eqemu/zone/companion.cpp` (lines 1739-1750)

Replaced direct calls to:
- `entity_list.AddCompanion(companion)`
- `companion->AI_Start()`
- `companion->CompanionJoinClientGroup()`

With a single call to:
- `companion->Spawn(this)` (where `this` is the `Client*`)

Error handling uses `delete companion` + `continue` on failure since the
companion is not yet in the entity list.

---

## What Was NOT Changed

- `EntityList::AddCompanion()` -- remains a low-level method, unchanged
- Group packet logic -- already uses `GetCleanName()`, which is correct
- Game logic (recruitment rolls, persistence, scaling, etc.)

---

## Why This Fixes the Bug

After this change, the spawn lifecycle is:

1. NPC constructor: `name` = `Guard_Liben001` (MakeNameUnique)
2. `Companion::Spawn()`:
   - `clean_name[0] = '\0'` (invalidate cache)
   - `strcpy(name, GetCleanName())` -> `name` = `Guard Liben`
   - `AddCompanion()` -> spawn packet `name` = `Guard Liben`
   - `FillSpawnStruct()` -> `is_npc = 0`, `NPC = 0` (player-like)
   - `CompanionJoinClientGroup()` -> group packet `membername` = `Guard Liben`

Spawn name == Group name == `Guard Liben`. The Titanium client can now match
the group window entry to the in-world entity and send `OP_TargetMouse` with
the correct entity ID.

---

## Testing

Rebuild the server:
```bash
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
```

Test scenarios:
1. Recruit a new NPC companion -- verify group window shows name and clicking
   targets the companion
2. Zone with an active companion -- verify group window targeting works after
   zone-in
3. Dismiss and re-recruit -- verify names remain consistent
