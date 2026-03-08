# BUG-008: Companions drop from group interface when zoning

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-03-08
> **Feature:** companion-levelup-fixes
> **Status:** Root Cause Identified

---

## Observed Behavior

Player has three NPC companions in group: Lydl the Great, Guard Liben,
and Hyril Pon. After zoning into North Ro, all but the most recently
recruited companion (Lydl the Great) dropped from the group interface.
Guard Liben and Hyril Pon disappeared from the group display.

This compounds with BUG-007 (level-up group drop) — Guard Liben had
previously leveled up and was already missing from the group UI before
this zone transition.

## Expected Behavior

All recruited NPC companions should persist through zone transitions.
The group interface should show all companions after zoning, not just
the most recent one.

## Reproduction Steps

1. Recruit 3 NPC companions into group
2. Zone to a different zone (e.g., North Ro)
3. Observe: only the most recently recruited companion appears in group
4. The other companions are missing from the group interface

## Key Questions for Investigation — ANSWERED

**Are the companions still in the group server-side?**
YES. Database query confirmed all 3 companions have `is_suspended=0`,
`is_dismissed=0`. Server logs confirmed ALL 3 spawn and join the group
on zone-in.

**Are companions being removed from the group during the zone process?**
YES. During zone-out, all companions are removed via
`RemoveCompanionFromGroup()`, and the last one triggers `DisbandGroup()`
which calls `database.ClearGroup()`, wiping the group from the database
entirely.

**Does the zone-in process only restore the most recent companion?**
NO. All 3 are restored. The issue is that the Titanium client receives
group packets BEFORE it receives spawn packets for the companion entities,
causing it to fail to display all group members.

**Are the companions still in the zone as entities but just not in the group?**
YES. All 3 are spawned as entities AND added to the group server-side.
The display failure is client-side.

## Root Cause Analysis

### Primary Cause: Spawn/Group Packet Timing Mismatch

The bug is caused by a packet delivery ordering problem during the
Titanium client's zone-in connect sequence. There are two interacting
issues:

#### 1. Group is destroyed during zone-out

When the player zones out (`Handle_OP_ZoneChange` in `zoning.cpp:48-53`),
each companion's `Zone()` method is called, which calls `Depop()`,
which calls `RemoveCompanionFromGroup()`. When the last companion is
removed and `GroupCount() <= 2`, `DisbandGroup()` is triggered
(`companion.cpp:1044`), which:

- Sends `groupActDisband` to the client (groups.cpp:992)
- Calls `database.ClearGroup()` (groups.cpp:1024) — wipes group from DB
- Calls `entity_list.RemoveGroup()` (groups.cpp:1034) — destroys the
  group object

Result: the group no longer exists in the database.

#### 2. Group cannot be loaded from DB on zone-in

In `Handle_Connect_OP_ZoneEntry` (`client_packet.cpp:1591`):
```cpp
uint32 groupid = database.GetGroupID(GetName());
```
This returns 0 because the group was cleared. The else branch
(line 1611-1616) zeroes `PP.groupMembers`. The PP is then sent to the
Titanium client at line 1719-1725 with **empty group data**.

#### 3. Spawn packets are DEFERRED, group packets are IMMEDIATE

Companions are spawned in `Handle_Connect_OP_SendExpZonein`
(`client_packet.cpp:1170`), which calls `SpawnCompanionsOnZone()`.

Each companion's `Spawn()` method:
1. Calls `entity_list.AddCompanion()` which sends the spawn packet via
   `EntityList::QueueClients()` — this uses `CLIENT_CONNECTED` as the
   required state (entity.cpp:1804), so the packet is **DEFERRED** to
   `SendAllPackets()` in `CompleteConnect()`.
2. Calls `CompanionJoinClientGroup()` which sends group packets via
   `Client::QueuePacket()` with the default `CLIENT_CONNECTINGALL`
   state, so these packets are sent **IMMEDIATELY**.

**Result: The Titanium client receives group update packets
(groupActJoin/groupActUpdate) referencing companion names BEFORE it
receives the spawn packets that create those entities.** The client
cannot associate group members with entities that don't exist yet.

#### 4. The Titanium connect sequence order:

```
OP_ZoneEntry → PP sent (empty group)
OP_SendExpZonein → SpawnCompanionsOnZone()
  ├─ Companion 1: group packets sent NOW, spawn packet DEFERRED
  ├─ Companion 2: group packets sent NOW, spawn packet DEFERRED
  └─ Companion 3: group packets sent NOW, spawn packet DEFERRED
OP_ClientReady → CompleteConnect() → SendAllPackets()
  ├─ Spawn packet for Companion 1 (sent now)
  ├─ Spawn packet for Companion 2 (sent now)
  └─ Spawn packet for Companion 3 (sent now)
```

The Titanium client receives group membership information for entities
it doesn't know about yet, then receives the entity spawns later.

#### Why only the "last" companion appears:

The most recently recruited companion (highest `id` in `companion_data`)
is spawned last by the database query (no ORDER BY, defaults to PK order).
Its spawn packet is the last one flushed during `SendAllPackets()`. The
Titanium client may associate the most recent group state with the most
recent spawn, causing only that one to appear in the group window.
Alternatively, the final `groupActUpdate` packet is the most "fresh"
in the client's processing queue and may be the one that "sticks" when
the spawn packets arrive and the client reconciles.

### Secondary Issue: Zone-out Double-Depop

During zone-out, the last companion triggers `DisbandGroup()` via
`RemoveCompanionFromGroup()`. The safety net code in `DisbandGroup()`
(groups.cpp:955-964) calls `Zone()` on remaining companion group
members, which calls `Depop()` recursively. This means the last
companion gets `Depop()` called twice — once from the original
`Zone()` call and once from the DisbandGroup safety net. While this
doesn't crash (the second call is a no-op on already-cleaned state),
it is a code smell.

### Contrast with Bot System

Bots avoid this problem because they are spawned INSIDE
`Handle_Connect_OP_ZoneEntry` (line 1652) BEFORE the PP is sent
(line 1719). Bot groups are persisted across zones in the database
and loaded at line 1593-1647. The PP sent to the client already
contains bot names in `groupMembers[]`.

Companions, by contrast:
1. Destroy their group during zone-out (ClearGroup)
2. Are spawned AFTER the PP is sent (in SendExpZonein)
3. Send group packets before spawn packets due to state gating

## Evidence

- Database confirmed: all 3 companions `is_suspended=0`, `is_dismissed=0`
- Server logs confirmed: all 3 spawn and join group in NRO
- Log output shows: Guard Liben creates new group, Hyrill Pon joins
  existing group, Lydl the Great joins existing group
- User observed: only Lydl the Great (most recently recruited) visible

## Affected Code Paths

| File | Lines | Function | Issue |
|------|-------|----------|-------|
| `zone/zoning.cpp` | 48-53 | `Handle_OP_ZoneChange` | Companion zone-out loop |
| `zone/companion.cpp` | 820-828 | `Zone()` | Calls Save() then Depop() |
| `zone/companion.cpp` | 834-857 | `Depop()` | Calls RemoveCompanionFromGroup |
| `zone/companion.cpp` | 1031-1070 | `RemoveCompanionFromGroup` | DisbandGroup if count<=2 |
| `zone/groups.cpp` | 940-1035 | `DisbandGroup()` | ClearGroup wipes DB |
| `zone/client_packet.cpp` | 1591-1616 | `Handle_Connect_OP_ZoneEntry` | Group load from DB (fails) |
| `zone/client_packet.cpp` | 1719-1725 | (same) | PP sent with empty group |
| `zone/client_packet.cpp` | 1157-1174 | `Handle_Connect_OP_SendExpZonein` | SpawnCompanionsOnZone called |
| `zone/companion.cpp` | 2040-2122 | `SpawnCompanionsOnZone()` | Spawns all companions |
| `zone/companion.cpp` | 722-767 | `Spawn()` | Entity add + group join |
| `zone/companion.cpp` | 1969-1998 | `AddCompanion()` | Spawn packet via QueueClients (DEFERRED) |
| `zone/companion.cpp` | 910-997 | `CompanionJoinClientGroup()` | Group packets (IMMEDIATE) |
| `zone/entity.cpp` | 1794-1808 | `QueueClients()` | Uses CLIENT_CONNECTED → deferred |
| `zone/groups.cpp` | 225-344 | `AddMember()` | groupActJoin packet |
| `zone/groups.cpp` | 1099-1127 | `SendUpdate()` | groupActUpdate packet |

## Proposed Fix

### Recommended: Option A — Move companion spawning after CompleteConnect

Move `SpawnCompanionsOnZone()` from `Handle_Connect_OP_SendExpZonein` to
`Handle_Connect_OP_ClientReady`, AFTER `CompleteConnect()`. This ensures
`client_state == CLIENT_CONNECTED` when companions spawn, so both spawn
packets AND group packets are sent immediately rather than being split
between deferred and immediate delivery.

```
Handle_Connect_OP_ClientReady:
  1. CompleteConnect()  → client_state = CLIENT_CONNECTED
  2. SpawnCompanionsOnZone()  → spawn + group packets all sent immediately
  3. SendHPUpdate()
```

**Pros:**
- Simple change: move one function call
- Spawn and group packets arrive together
- No changes to the group lifecycle
- Mirrors how bots handle their group refresh (after login completes)

**Cons:**
- Group is still destroyed/recreated each zone (DB churn)
- Slight delay before companions appear (after loading screen)

### Alternative: Option B — Preserve group across zones

Don't disband the group during zone-out for companions. Instead of
calling `RemoveCompanionFromGroup()` in `Depop()` during `Zone()`,
preserve the group in the database and use `Group::MemberZoned()` to
mark companions as out-of-zone. On zone-in, the group loads normally
from DB (PP gets populated), and companions spawn into the existing
group.

**Pros:**
- More architecturally correct
- No DB churn (group persists)
- PP has correct data from the start

**Cons:**
- Larger change: affects zone-out path, group loading, companion spawn
- Need to handle edge cases (what if group already has 6 members from DB?)
- Risk of dangling group entries if companions fail to rejoin

### Alternative: Option C — Group refresh after CompleteConnect

After `CompleteConnect()`, call `database.RefreshGroupFromDB(this)` to
re-send the full group state to the client. This uses the group data
that was persisted by `CompanionJoinClientGroup()` during
`SpawnCompanionsOnZone()`.

**Pros:**
- Very small change: add one function call
- Group state is resynchronized regardless of timing issues

**Cons:**
- Workaround rather than root fix
- Doesn't fix the spawn packet deferral issue
- Client may still briefly show wrong group state

## Task Breakdown

### Task 1: Move SpawnCompanionsOnZone (c-expert)

In `zone/client_packet.cpp`, function `Handle_Connect_OP_ClientReady`:
- Move `SpawnCompanionsOnZone()` call to AFTER `CompleteConnect()`
- Remove the call from `Handle_Connect_OP_SendExpZonein`
- Add a `RefreshGroupFromDB()` call after spawning as a safety net

### Task 2: Fix zone-out double-depop (c-expert)

In `zone/companion.cpp`, function `RemoveCompanionFromGroup`:
- When `GroupCount() <= 2`, instead of calling `DisbandGroup()`,
  use `DelMember()` followed by a manual group cleanup to avoid
  the recursive `Zone()` → `Depop()` cascade
- Or: set a flag on the companion to prevent re-entrant Depop()

### Task 3: Fix zone-out group cleanup (c-expert)

In `zone/companion.cpp`, function `Zone()`:
- Don't call full `Depop()` during zone transitions
- Instead, call `Save()`, remove from entity list, and remove from
  group individually — skipping the DisbandGroup cascade
- Or: Set `m_depop = true` before calling `Depop()` and check it
  early to prevent re-entry

### Task 4: Validation (game-tester)

- Recruit 3 companions, zone to a new zone, verify all 3 appear in group
- Verify companions follow, respond to commands, and show HP in group window
- Test with 1, 2, 3, 4, 5 companions (varying counts)
- Test repeated zoning (zone A → B → C) with all companions persisting
- Test disconnecting and reconnecting with companions
- Test camping and logging back in

## Workaround for Current Broken State

The user can force a group refresh by:
1. Use `!dismiss` on the visible companion
2. Use `!recruit` to get them back
3. Repeat for each companion

Or use GM commands if available:
1. `#reloadgroup` or `#repop` to force refresh
2. Zone again — the server-side state IS correct, only the client
   display is wrong

Or simply zone again — each zone transition recreates the group. The
bug is that the FIRST zone-in after recruitment doesn't display
correctly, but subsequent zone-ins may also fail due to the same timing
issue. The workaround is to dismiss all and re-recruit after reaching
the destination zone.

## Affected Systems

- [x] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [x] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
