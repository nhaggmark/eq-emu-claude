# BUG-003 Data Expert Findings

**Date:** 2026-02-27
**Investigator:** data-expert

---

## 1. companion_data Table: Has Rows (Save Path Works)

The save path IS firing. There are 4 rows in `companion_data`:

```
id | owner_id | npc_type_id | name          | is_suspended | is_dismissed | zone_id | recruited_at
---+----------+-------------+---------------+--------------+--------------+---------+---------------------
2  | 6        | 2122        | Guard Liben   | 0            | 0            | 2       | 2026-02-27 16:33:29
3  | 6        | 2113        | Guard Imkar   | 0            | 0            | 2       | 2026-02-27 20:36:28
4  | 6        | 2114        | Guard Simkin  | 1            | 0            | 2       | 2026-02-27 22:50:02
5  | 6        | 2114        | Guard Simkin  | 1            | 0            | 2       | 2026-02-27 23:20:20
```

- Owner character 6 = "Chelon" (verified in `character_data`)
- `companion_buffs` is EMPTY (0 rows)
- `companion_inventories` is EMPTY (0 rows)

## 2. Key Observations

### Issue A: Duplicate Companions (IDs 4 and 5)

Guard Simkin (npc_type_id 2114) has **two separate records** (ids 4 and 5). Both
have `is_dismissed = 0`, meaning neither was dismissed. This suggests the
recruitment process created a new row each time without cleaning up or reusing
the previous one. This is a secondary issue -- it causes duplicate spawns.

### Issue B: is_suspended State Inconsistency

- IDs 2 and 3: `is_suspended = 0` (active) -- these should spawn on zone-in
- IDs 4 and 5: `is_suspended = 1` (suspended) -- these are skipped on zone-in

The `SpawnCompanionsOnZone()` method at `companion.cpp:1675` queries:
```sql
SELECT ... FROM companion_data WHERE owner_id = 6 AND is_dismissed = 0
```
This returns all 4 rows. Then at line 1697 it skips suspended ones:
```cpp
if (cd.is_suspended) {
    continue;
}
```
So only IDs 2 and 3 (Guard Liben and Guard Imkar) should attempt to spawn.

### Issue C: The Load Path Is Correct -- The Problem Is Upstream

The `SpawnCompanionsOnZone()` logic is sound for what it receives. The query
is correct, the filter is correct. If companions are not appearing on login,
the issue is either:

1. **Save path not firing on logout/camp** (most likely -- see below)
2. **`is_suspended` being set to 1 during logout and never reset**
3. **NPC type data not loading** (`database.LoadNPCTypesData()` failure)

## 3. Root Cause Analysis: Missing Save/Suspend on Logout

**This is the smoking gun.** I examined the three disconnect/logout paths in
`client_process.cpp`:

### Path 1: Camp timer (normal /camp)

`client_process.cpp:191-211`:
```cpp
if (camp_timer.Check()) {
    LeaveGroup();          // <-- companion leaves group
    Save();                // <-- player save only
    if (GetMerc()) {
        GetMerc()->Save(); // <-- merc saved
        GetMerc()->Depop(); // <-- merc depoped
    }
    // NO companion save/depop here!
    instalog = true;
}
```

**Mercs are explicitly saved and depoped. Companions are NOT.**

### Path 2: Hard disconnect (OnDisconnect)

`client_process.cpp:691-744`:
```cpp
void Client::OnDisconnect(bool hard_disconnect) {
    if (hard_disconnect) {
        LeaveGroup();
        if (GetMerc()) {
            GetMerc()->Save();
            GetMerc()->Depop();
        }
        // NO companion save/depop here!
    }
}
```

Again, mercs handled, companions not.

### Path 3: Zone change

`zoning.cpp:39-44`:
```cpp
void Client::Handle_OP_ZoneChange(...) {
    if (RuleB(Bots, Enabled)) {
        Bot::ProcessClientZoneChange(this);
    }
    // NO companion zone handling here!
    bZoning = true;
}
```

Bots are processed on zone change. Companions are not.

## 4. What Happens to Companion State on Logout

Because companions are never saved/suspended on logout:

1. `LeaveGroup()` is called -- companion is removed from the group
2. The zone shuts down the entity list -- the Companion NPC object is destroyed
3. **No `Companion::Suspend()` or `Companion::Zone()` is called**
4. The `companion_data` row retains whatever state it had from last explicit save
5. On next login, `SpawnCompanionsOnZone()` finds rows with `is_suspended = 0`
   and attempts to spawn them, BUT:
   - The companion's group membership is lost (group was disbanded on logout)
   - If `Companion::Spawn()` requires the owner to not already be grouped, it may fail silently

## 5. Additional Data Issue: No `recruited_at` Timestamp Column in SELECT

The repository `FindOne()` and `GetWhere()` methods do NOT select the
`recruited_at` column. The table has it (DESCRIBE confirms it) but the C++
struct does not include it, so it's never read back. This is harmless for
functionality but means `recruited_at` is write-once (set by INSERT default).

## 6. Summary of Root Causes

| # | Issue | Location | Impact |
|---|-------|----------|--------|
| 1 | **No companion save/depop on camp** | `client_process.cpp:191-211` | Companions not persisted on /camp |
| 2 | **No companion save/depop on disconnect** | `client_process.cpp:691-744` | Companions not persisted on disconnect |
| 3 | **No companion zone handling on zone change** | `zoning.cpp:39-44` | Companions not saved/depoped on zone |
| 4 | **Duplicate companion records** | Recruitment logic | Multiple rows for same NPC |
| 5 | **Group membership lost on logout** | `LeaveGroup()` call | Even if data is correct, group is gone |

**Primary diagnosis: The C++ code has a `Companion::Zone()` method and
`Companion::Suspend()` method that correctly save state, but these are never
called from the camp, disconnect, or zone-change code paths. The merc and bot
equivalents ARE called in those paths. This is a C++ code issue, not a
database issue.**

## 7. Recommended Fix (for c-expert)

Add companion handling alongside merc handling in these three locations:

1. **Camp timer** (`client_process.cpp:~205`): After merc save/depop, iterate
   companions and call `Suspend()` on each
2. **OnDisconnect** (`client_process.cpp:~696`): Same pattern
3. **Zone change** (`zoning.cpp:~40`): Call a companion zone-out method similar
   to `Bot::ProcessClientZoneChange()`

The `Companion::Zone()` and `Companion::Suspend()` methods already exist and
correctly call `Save()` + `Depop()`. They just need to be invoked from the
right places.
