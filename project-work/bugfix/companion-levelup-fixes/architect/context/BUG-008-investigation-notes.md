# BUG-008 Investigation Notes

## Server-Side Verification (CONFIRMED WORKING)

### Database State
All 3 companions have correct DB state:
- `is_suspended = 0` (not suspended)
- `is_dismissed = 0` (not dismissed)
- All have valid `npc_type_id`, `owner_id`, `level`, etc.

### Server Logs
All 3 companions spawn and join group on zone-in to NRO:
```
[Companions] Companion [Guard Liben] joined new group with [Chelon]
[Companions] Companion [Hyrill Pon] joined existing group with [Chelon]
[Companions] Companion [Lydl the Great] joined existing group with [Chelon]
```

## Packet Timing Analysis

### The Core Problem

Two different packet delivery paths during the connect phase:

1. **Spawn packets** — sent via `EntityList::QueueClients()` which passes
   `CLIENT_CONNECTED` to `QueuePacket()`. During connect phase,
   `client_state != CLIENT_CONNECTED`, so these go through `AddPacket()`
   (deferred queue) and only flush during `SendAllPackets()` in
   `CompleteConnect()`.

2. **Group packets** — sent via `Client::QueuePacket()` with default
   `CLIENT_CONNECTINGALL` state. Since `required_state` IS
   `CLIENT_CONNECTINGALL`, the condition at line 1176 is FALSE, so the
   packet goes directly to `eqs->QueuePacket()` (immediate send).

### Code Evidence

`entity.cpp:1804`:
```cpp
ent->QueuePacket(app, ackreq, Client::CLIENT_CONNECTED);
```

`client.cpp:1170-1182`:
```cpp
if (client_state != CLIENT_CONNECTED && required_state == CLIENT_CONNECTED) {
    AddPacket(app, ack_req);  // DEFERRED
    return;
}
if (required_state != CLIENT_CONNECTINGALL && client_state != required_state) {
    AddPacket(app, ack_req);  // DEFERRED
}
else if (eqs) {
    eqs->QueuePacket(app, ack_req);  // IMMEDIATE
}
```

For group packets: `required_state = CLIENT_CONNECTINGALL` (default).
- Line 1170: `CLIENT_CONNECTINGALL != CLIENT_CONNECTED` → FALSE
- Line 1176: `CLIENT_CONNECTINGALL != CLIENT_CONNECTINGALL` → FALSE
- Line 1180: reaches `eqs->QueuePacket()` → IMMEDIATE

For spawn packets: `required_state = CLIENT_CONNECTED`.
- Line 1170: `client_state != CLIENT_CONNECTED` is TRUE (during connect),
  AND `CLIENT_CONNECTED == CLIENT_CONNECTED` is TRUE → enters block
- `AddPacket()` → DEFERRED

### Implementation Notes for c-expert

The fix (moving `SpawnCompanionsOnZone()` to after `CompleteConnect()`)
works because `CompleteConnect()` sets `client_state = CLIENT_CONNECTED`
at line 521. After that, ALL packets go through `eqs->QueuePacket()`
immediately — both spawn AND group packets. No timing split.

The change is in `Handle_Connect_OP_ClientReady` (`client_packet.cpp:1060`):

Current:
```cpp
void Client::Handle_Connect_OP_ClientReady(const EQApplicationPacket *app) {
    conn_state = ClientReadyReceived;
    if (!Spawned())
        SendZoneInPackets();
    CompleteConnect();
    SendHPUpdate();
}
```

New:
```cpp
void Client::Handle_Connect_OP_ClientReady(const EQApplicationPacket *app) {
    conn_state = ClientReadyReceived;
    if (!Spawned())
        SendZoneInPackets();
    CompleteConnect();
    SpawnCompanionsOnZone();
    SendHPUpdate();
}
```

And remove from `Handle_Connect_OP_SendExpZonein`:
```cpp
void Client::Handle_Connect_OP_SendExpZonein(const EQApplicationPacket *app) {
    auto outapp = new EQApplicationPacket(OP_SendExpZonein, 0);
    QueuePacket(outapp);
    safe_delete(outapp);
    if (ClientVersion() < EQ::versions::ClientVersion::SoF) {
        SendZoneInPackets();
        // REMOVE: SpawnCompanionsOnZone();
    }
    return;
}
```

### Zone-Out Cascade Detail

Companion removal order during zone-out (3 companions, group count 4):

1. Companion 1: `RemoveCompanionFromGroup` → `GroupCount()` is 4 > 2 →
   `DelMember()` → count drops to 3
2. Companion 2: `RemoveCompanionFromGroup` → `GroupCount()` is 3 > 2 →
   `DelMember()` → count drops to 2
3. Companion 3: `RemoveCompanionFromGroup` → `GroupCount()` is 2 ≤ 2 →
   `DisbandGroup()` triggered

Inside DisbandGroup:
- Safety net (lines 955-964) iterates members looking for companions
- Companion 3 is still in members[] (wasn't DelMember'd yet)
- Safety net calls `comp->Zone()` on Companion 3 → recursive Depop()
- Second Depop: GetGroup() returns nullptr (group removed) → skip
- First Depop continues after DisbandGroup returns

This recursive call is messy but not functionally broken because the
second Depop's RemoveCompanion/NPC::Depop calls are no-ops on already-
cleaned state.
