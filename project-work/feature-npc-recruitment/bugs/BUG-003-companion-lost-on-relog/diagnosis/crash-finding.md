# BUG-003 Follow-up: Client Crash After Fix Attempt 2

**Date:** 2026-02-28
**Investigator:** orchestrator (ad-hoc, code tracing)

---

## What Happened

Fix attempt 2 moved `SpawnCompanionsOnZone()` from `Handle_Connect_OP_WorldObjectsSent`
(SoF+ only) to `Handle_Connect_OP_ZoneEntry` (universal). This caused a Titanium
client crash after character selection — the client crashes before fully entering
the zone.

## Why It Crashes

`Handle_Connect_OP_ZoneEntry` fires very early in the connection sequence
(`conn_state = ReceivedZoneEntry → PlayerProfileLoaded`). At this point the
client hasn't received zone content, doors, objects, or entity spawns yet.

`Companion::Spawn()` does three things that are unsafe at this stage:
1. `entity_list.AddCompanion(this, true, true)` — sends spawn packet immediately
2. `AI_Start()` — starts NPC AI tick
3. `CompanionJoinClientGroup()` — sends group packets to the client

Sending spawn and group packets before the client has reached `ZoneContentsSent`
state crashes the Titanium client.

## Why Bots Don't Crash

`Bot::LoadAndSpawnAllZonedBots()` (also in ZoneEntry at line 1645) has a guard:
```cpp
if (bot_owner && bot_owner->HasGroup()) { ... }
```

Bots only spawn if the player already has a **saved group** in the database.
The bot is already recorded as a group member in the DB, so `Bot::Spawn()` +
`g->UpdatePlayer(b)` updates an existing group rather than creating one. The
group packets are updates to known state, not new group creation.

Companions, by contrast, call `CompanionJoinClientGroup()` which may CREATE
a new group and send full group initialization packets.

**However**, the more fundamental issue is timing — even if companions had
the same group-guard pattern, sending spawn packets this early is risky for
Titanium.

## Titanium Connection State Machine

```
1. OP_ZoneEntry       → ReceivedZoneEntry → PlayerProfileLoaded
                         (character data loaded, Bots spawned)
2. OP_ReqNewZone      → NewZoneRequested (zone data sent)
3. OP_ReqClientSpawn  → ClientSpawnRequested → ZoneContentsSent
                         (doors, objects, entities sent to client)
                         Server sends OP_SendExpZonein + OP_WorldObjectsSent
4. OP_SendExpZonein   → Titanium responds here: SendZoneInPackets()
5. OP_WorldObjectsSent → SoF+ responds here: SendZoneInPackets() + MercSpawn
6. OP_ClientReady     → ClientReadyReceived → ClientConnectFinished
```

For Titanium, step 4 (`Handle_Connect_OP_SendExpZonein`) is the equivalent of
step 5 for SoF+. That's where `SendZoneInPackets()` runs for pre-SoF clients.

## Recommended Fix

Add `SpawnCompanionsOnZone()` to the **correct per-client-version handler**:

1. **Remove** from `Handle_Connect_OP_ZoneEntry` (current crash location)
2. **Add to** `Handle_Connect_OP_SendExpZonein` inside the
   `if (ClientVersion() < EQ::versions::ClientVersion::SoF)` block — for Titanium
3. **Add back to** `Handle_Connect_OP_WorldObjectsSent` — for SoF+ clients

This mirrors exactly how `SendZoneInPackets()` and `SpawnMercOnZone()` are placed:
each client version gets its companion spawn at the right point in its connection
sequence.
