# BUG-003 Diagnosis: Companion Lost on Relog

**Diagnosed by:** c-expert
**Date:** 2026-02-27
**Severity:** Critical
**Root Cause Confidence:** High

---

## Executive Summary

The companion IS saved to the database on logout, but it is saved with
`is_suspended = 1`. On login, `SpawnCompanionsOnZone()` explicitly skips
companions with `is_suspended = 1`. The save path marks the companion as
suspended, and the load path filters out suspended companions. These two
behaviors are contradictory for the camp/logout use case.

---

## Root Cause: is_suspended Mismatch Between Save and Load Paths

### The Save Path (Camp/Logout)

When a player camps out:

1. `Handle_OP_Camp()` (client_packet.cpp:4272) starts `camp_timer(29000)`
2. `camp_timer.Check()` fires in `Client::Process()` (client_process.cpp:191)
3. Calls `LeaveGroup()` (groups.cpp:1302)
4. For a player+companion group (2 members), after companion subtraction
   `MemberCount` drops below 3, triggering `DisbandGroup()` (groups.cpp:1345)
5. `DisbandGroup()` has the BUG-002 safety net (groups.cpp:952-961) which
   iterates all members and calls `comp->Suspend()` on each companion
6. `Suspend()` (companion.cpp:527) calls:
   - `SetSuspended(true)` — sets `m_suspended = true`
   - `Save()` — writes `is_suspended = 1` to companion_data
   - `SaveBuffs()` — persists buffs
   - `Depop()` — removes from entity list

**Result:** companion_data row has `is_suspended = 1`, `is_dismissed = 0`

### The Load Path (Login/Zone-in)

When a player logs back in:

1. Zone-in completes → `SpawnCompanionsOnZone()` called (client_packet.cpp:1238)
2. Queries `companion_data WHERE owner_id = X AND is_dismissed = 0`
3. Iterates results, but line 1697 says:
   ```cpp
   if (cd.is_suspended) {
       continue;  // Skip suspended companions
   }
   ```
4. Since `is_suspended = 1`, the companion is SKIPPED

**Result:** Companion exists in DB but is never spawned because it's suspended.

### Why Zone Transitions Work But Login Doesn't

The zone-transition path uses `Companion::Zone()` (companion.cpp:574):
```cpp
void Companion::Zone()
{
    UpdateTimeActive();
    if (zone) { RecordZoneVisit(zone->GetZoneID()); }
    Save();     // <-- writes is_suspended = 0 (m_suspended is false)
    Depop();
}
```

This writes `is_suspended = 0` because `m_suspended` remains `false`. On the
destination zone, `SpawnCompanionsOnZone()` finds `is_suspended = 0` and spawns
the companion. Zone transitions work correctly.

The camp/logout path uses `Suspend()` which sets `m_suspended = true` before
calling `Save()`, so the DB record gets `is_suspended = 1`. On re-login,
`SpawnCompanionsOnZone()` skips it.

---

## The Disconnect Paths

All disconnect paths lead to the same issue:

| Path | Flow | Companion Handling |
|------|------|--------------------|
| Normal camp (29s timer) | camp_timer → LeaveGroup → DisbandGroup | BUG-002 fix calls Suspend() → is_suspended=1 |
| GM fast camp | camp_timer(100ms) → same as above | Same |
| GM no-camp | OnDisconnect(true) → LeaveGroup → DisbandGroup | BUG-002 fix calls Suspend() → is_suspended=1 |
| Client crash / linkdead | CLIENT_LINKDEAD → OnDisconnect(true) → LeaveGroup → DisbandGroup | Same |
| Kicked | CLIENT_KICKED → Save → OnDisconnect(true) | Same |
| OP_Logout | Handle_OP_Logout → Disconnect (no LeaveGroup!) | Companion NOT saved at all — even worse |

Note: `Handle_OP_Logout` (client_packet.cpp:10324) calls `Disconnect()` without
calling `LeaveGroup()`, so companions are not saved at all through this path.
However, this opcode may not be used by the Titanium client for normal logout.

### Multi-Player Group Case

For groups with 3+ real members (MemberCount >= 3 after subtractions):
- `DisbandGroup()` does NOT fire
- `DelMember(this)` fires instead (groups.cpp:1349)
- The `else` block has NO companion handling
- Companion remains in the group as an orphan, never saved or depoped

This is a secondary bug: companions in larger groups are completely orphaned.

---

## How Bots and Mercs Handle This

### Bots
- `Handle_OP_Camp()` starts `bot_camp_timer` alongside `camp_timer`
- `bot_camp_timer.Check()` fires BEFORE `camp_timer.Check()` and calls
  `CampAllBots()` → `Bot::BotOrderCampAll()` → iterates all bots and calls
  `b->Camp(true)` which saves and depops each bot
- Bots have a dedicated timer and explicit save path, independent of group flow

### Mercs
- `camp_timer.Check()` block explicitly calls:
  ```cpp
  if (GetMerc()) {
      GetMerc()->Save();
      GetMerc()->Depop();
  }
  ```
- `OnDisconnect(true)` also explicitly saves/depops the merc
- Mercs save with `IsSuspended = false` equivalent, so they respawn on login

### Key Difference
Both bots and mercs have EXPLICIT save logic in the camp/disconnect path.
Companions rely entirely on `DisbandGroup()` → `Suspend()` as a side effect,
which marks them as suspended (preventing respawn).

---

## Suggested Fix Approach

### Fix 1: Add explicit companion save to camp/disconnect paths (Primary Fix)

Mirror the Bot/Merc pattern. Add companion Save+Depop to:

**A. camp_timer.Check() block** (client_process.cpp:~207, after Merc handling):
```cpp
// Save and depop companions (mirror Merc pattern)
if (RuleB(Companions, CompanionsEnabled)) {
    auto companions = entity_list.GetCompanionsByOwnerCharID(CharacterID());
    for (auto* comp : companions) {
        comp->Zone();  // Save(is_suspended=0) + Depop — same as zone transition
    }
}
```

**B. OnDisconnect(true) block** (client_process.cpp:~698, after Merc handling):
```cpp
if (RuleB(Companions, CompanionsEnabled)) {
    auto companions = entity_list.GetCompanionsByOwnerCharID(CharacterID());
    for (auto* comp : companions) {
        comp->Zone();  // Save(is_suspended=0) + Depop
    }
}
```

Using `comp->Zone()` instead of `comp->Suspend()` ensures `is_suspended` stays
0, so `SpawnCompanionsOnZone()` will find and spawn the companion on re-login.

**C. Remove DisbandGroup companion handling OR change it to use Zone()**

The BUG-002 safety net in `DisbandGroup()` currently calls `Suspend()` which
sets `is_suspended = 1`. This should either:
- Be removed (since explicit save is added above), or
- Changed to call `Zone()` instead of `Suspend()` so companions save without
  the suspended flag

### Fix 2: Change SpawnCompanionsOnZone to handle suspended companions (Alternative)

Instead of skipping suspended companions, unsuspend them:
```cpp
if (cd.is_suspended) {
    // Companion was suspended (e.g., from logout) — unsuspend on re-login
    // Only skip if is_dismissed
}
```

This is simpler but changes the semantics of "suspended." Currently suspended
means "exists but should not be spawned." If we want to keep that meaning (e.g.,
for manual suspension), we need a different state for "saved during logout."

### Fix 3: Add a third state or flag (Most Complete)

Add a `save_reason` or use a combination of flags:
- `is_suspended = 1, is_dismissed = 0` → saved on logout, should auto-respawn
- `is_suspended = 1, is_dismissed = 1` → permanently dismissed, do not respawn

Then `SpawnCompanionsOnZone()` skips only dismissed companions, not suspended ones.

### Recommended Fix

**Fix 1A + 1B** is the cleanest approach — it mirrors how Bots and Mercs handle
camp/disconnect and uses `Zone()` (which saves without the suspended flag)
instead of `Suspend()`. The DisbandGroup BUG-002 safety net should be changed
from `Suspend()` to `Zone()` or removed entirely since the explicit save in the
camp/disconnect path will handle it.

Also need to handle the `DelMember` case (multi-player groups) in
`LeaveGroup()` — the `else` branch at line 1349 should also save/depop owned
companions.

---

## Additional Finding: Zone Change Path Missing (confirmed by data-expert)

`Handle_OP_ZoneChange` in `zoning.cpp:39` calls `Bot::ProcessClientZoneChange()`
for bots but has NO equivalent call for companions. The method
`Companion::ProcessClientZoneChange()` exists at companion.cpp:653 and correctly
calls `Zone()` (Save with is_suspended=0 + Depop). It is simply never wired up.

This means zone transitions ALSO do not properly save companions. If
`SpawnCompanionsOnZone()` appears to work during zone transitions, it's because
the initial Save() on recruitment wrote `is_suspended = 0` and that value was
never updated (no subsequent save call). But companion HP, mana, position, XP,
and kill history would be stale -- they'd reflect the state at recruitment, not
the state when the player zoned.

---

## Files to Modify

| File | Change |
|------|--------|
| `zone/client_process.cpp` | Add companion save/depop in camp_timer and OnDisconnect blocks |
| `zone/zoning.cpp` | Add companion ProcessClientZoneChange call alongside Bot version |
| `zone/groups.cpp` | Change DisbandGroup companion handling from Suspend() to Zone(); add companion handling to DelMember path in LeaveGroup |

All helpers already exist:
- `EntityList::GetCompanionsByOwnerCharacterID(uint32)` -- entity.h:649
- `Companion::ProcessClientZoneChange(Client*)` -- companion.cpp:653
- `Companion::Zone()` -- companion.cpp:574
- `Companion::Suspend()` -- companion.cpp:527

---

## Data-Expert Confirmation (2026-02-27)

data-expert verified that companion_data has 4 rows for the test character with
correct data (is_suspended=0, is_dismissed=0 after initial recruitment). The DB
layer is working correctly. The root cause is entirely in C++ -- the save/depop
calls are missing from the three disconnect paths.

data-expert also found duplicate records for Guard Simkin (npc_type_id 2114,
companion_data IDs 4 and 5). This is a separate issue -- recruitment creates a
new row each time instead of reusing existing active records for the same
NPC type. Should be filed as a separate bug.
