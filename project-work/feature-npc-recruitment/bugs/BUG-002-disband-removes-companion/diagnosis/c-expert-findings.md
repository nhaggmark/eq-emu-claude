# BUG-002 Diagnosis: Disband Removes Companion NPCs

> **Updated:** 2026-02-27 after protocol-agent analysis

## Executive Summary

The previous fix (commit `26056651d`) has a **fatal flaw in its own Case 1
logic**: when the player has the companion targeted and clicks "Disband",
the protection code itself calls `Dismiss()` on the companion, destroying it.

**Primary root cause:** Case 1 at `client_packet.cpp:7322-7328` treats
"player targeting companion + clicking Disband" as an intentional dismiss
request, when it should block the action entirely.

**Secondary concern:** `Group::DisbandGroup()` itself has no companion
awareness, so any code path that calls it directly (LeaveGroup, DelMember,
disconnect, cross-zone, scripting) would also orphan the companion.

---

## All Code Paths That Can Remove a Companion From a Group

### Path 1: `Handle_OP_GroupDisband` (client_packet.cpp:7197)
**Protected by commit 26056651d? YES** (lines 7311-7362)

The OP_GroupDisband handler. The previous fix added companion detection and
blocking here. When a companion is present, it intercepts the disband and
either blocks it (2-member group), dismisses the companion (if targeted),
or ejects other players (multi-player group).

### Path 2: `Handle_OP_GroupDelete` (client_packet.cpp:7184)
**Protected? NO — but not reachable from Titanium**

```cpp
void Client::Handle_OP_GroupDelete(const EQApplicationPacket *app)
{
    Group* group = GetGroup();
    if (group)
        group->DisbandGroup();    // <-- NO companion check
    if (LFP)
        UpdateLFP();
    return;
}
```

This is a separate opcode handler registered at line 232:
`ConnectedOpcodes[OP_GroupDelete] = &Client::Handle_OP_GroupDelete;`

**Protocol-agent confirmed:** Titanium maps `OP_GroupDelete` to wire opcode
`0x0000` (disabled). This path is NOT reachable from the Titanium client.
However, it remains unprotected for other client versions (SoF, SoD, etc.).

### Path 3: `Client::LeaveGroup()` (groups.cpp:1283)
**Protected? NO**

```cpp
void Client::LeaveGroup() {
    Group *g = GetGroup();
    if (g) {
        int32 MemberCount = g->GroupCount();
        // Subtracts mercs and bots from count, but NOT companions
        if (MemberCount < 3) {
            g->DisbandGroup();    // <-- NO companion check
        }
        // ...
    }
}
```

When a player + companion group has exactly 2 members (count = 2 < 3), any
LeaveGroup call triggers `DisbandGroup()`. Companions are NOT subtracted from
the MemberCount like bots and mercs are.

Called from:
- `Handle_OP_GroupDisband` line 7386 (leader targets self)
- `Handle_OP_GroupDisband` line 7475 (non-leader removes self)
- `Client::OnDisconnect(true)` line 693 (hard disconnect, camp, linkdead)

### Path 4: `Client::OnDisconnect(true)` (client_process.cpp:691)
**Protected? NO**

```cpp
void Client::OnDisconnect(bool hard_disconnect) {
    if (hard_disconnect) {
        LeaveGroup();    // <-- triggers DisbandGroup via Path 3
        // ...
    }
}
```

When a player camps, linkdeads, or disconnects, `OnDisconnect(true)` calls
`LeaveGroup()` which calls `DisbandGroup()`. The companion gets `SetGrouped(false)`
and its group membership is cleared at lines 985-987 of DisbandGroup.

### Path 5: `Group::DelMember()` -> `DisbandGroup()` (groups.cpp:674)
**Protected? NO**

```cpp
bool Group::DelMember(Mob* oldmember, bool ignoresender) {
    if (oldmember == GetLeader()) {
        DisbandGroup();    // <-- line 687, NO companion check
        return true;
    }
    // ... also:
    if (GetLeaderName().empty()) {
        DisbandGroup();    // <-- line 734, NO companion check
        return true;
    }
}
```

When the group leader is removed via `DelMember`, it calls `DisbandGroup()`
directly. This can happen via various external triggers.

### Path 6: `worldserver.cpp` ServerOP_DisbandGroup handler (worldserver.cpp:1326)
**Protected? NO**

```cpp
case ServerOP_DisbandGroup: {
    ServerDisbandGroup_Struct* sd = (ServerDisbandGroup_Struct*)pack->pBuffer;
    if (zone) {
        if (sd->zoneid == zone->GetZoneID() && sd->instance_id == zone->GetInstanceID())
            break;
        Group *g = entity_list.GetGroupByID(sd->groupid);
        if (g)
            g->DisbandGroup();    // <-- NO companion check
    }
    break;
}
```

When world server broadcasts a disband to other zones (for cross-zone groups),
the receiving zone calls `DisbandGroup()` directly.

### Path 7: Lua/Perl scripting API
**Protected? NO**

Both `Lua_Group::DisbandGroup()` (lua_group.cpp:15) and
`Perl_Group_DisbandGroup()` (perl_groups.cpp:9) expose `DisbandGroup()` to
scripts with no protection.

---

## What `Group::DisbandGroup()` Does to Companions

In the loop at groups.cpp:953-988:

```cpp
for (i = 0; i < MAX_GROUP_MEMBERS; i++) {
    if (members[i] == nullptr) { ... continue; }
    if (members[i]->IsClient())  { /* remove client */ }
    if (members[i]->IsMerc())    { /* remove merc */ }
    // NO IsCompanion() check -- companion falls through!
    members[i]->SetGrouped(false);    // line 985
    members[i] = nullptr;             // line 986
    membername[i][0] = '\0';          // line 987
}
```

The companion is not a Client and not a Merc, so it skips both blocks. But
lines 985-987 execute unconditionally for every non-null member: the companion
gets `SetGrouped(false)`, its slot is nulled out, and its name is cleared. The
companion entity still exists in the zone but is no longer in any group.

After the loop, `database.ClearGroup(GetID())` wipes the group from the DB.

---

## What the Previous Fix (26056651d) Did

The commit added 61 lines of companion protection logic inside
`Handle_OP_GroupDisband` at lines 7304-7362:

1. Scans group members for a companion using `IsCompanion()`
2. If companion found:
   - **Targeted kick of companion** -> calls `Dismiss()`
   - **2-member group (owner + companion)** -> blocks with hint message
   - **Multi-player group** -> ejects non-owner, non-companion members

### Why It's Insufficient

The fix is a **caller-side guard** that only protects ONE of SIX+ code paths
to `DisbandGroup()`. It correctly handles the `OP_GroupDisband` packet, but:

1. `OP_GroupDelete` bypasses it entirely (separate handler)
2. `Client::LeaveGroup()` bypasses it (called on disconnect, camp, zone)
3. `Group::DelMember()` bypasses it (leader removal triggers full disband)
4. `ServerOP_DisbandGroup` bypasses it (cross-zone disband from world)
5. Lua/Perl scripts bypass it

---

## How Bots Handle Group Disband

Bots take a **different approach** from what companions need. The bot system:

1. Has `Bot::ProcessBotGroupDisband()` (bot.cpp:7203) which removes bots from
   the group one at a time and then camps/zones them
2. Has a dedicated block in `Handle_OP_GroupDisband` (lines 7264-7286) that
   intercepts before the generic group disband logic
3. In `Client::LeaveGroup()` (groups.cpp:1293-1310), bots are subtracted from
   the MemberCount so the count doesn't trigger DisbandGroup prematurely

**Key difference:** Bots are MEANT to leave when the group disbands — they camp
or zone with their owner. Companions need to PERSIST through disband. This is a
fundamentally different requirement that the bot pattern doesn't solve.

---

## Root Cause (Confirmed with protocol-agent)

**Primary cause: Case 1 in the companion protection block calls Dismiss().**

Protocol-agent confirmed that Titanium sends `OP_GroupDisband` (0x0e76) for the
Disband button. `OP_GroupDelete` is disabled in Titanium (mapped to 0x0000).
My original hypothesis about OP_GroupDelete was incorrect.

The actual bug is in the protection code itself. At `client_packet.cpp:7322-7328`:

```cpp
// Case 1: leader is explicitly targeting the companion to kick them
if (group->IsLeader(this) && memberToDisband == companion_in_group) {
    companion_in_group->Dismiss();  // <-- THIS DESTROYS THE COMPANION
    if (LFP)
        UpdateLFP();
    return;
}
```

`memberToDisband` is set to `GetTarget()` at line 7293. When the player has the
companion targeted (common after recruitment, or when checking on them), clicking
"Disband" fires Case 1 instead of Case 2 (the hint-message protection). The
protection code interprets "targeted companion + Disband button" as an intentional
kick, when the Disband button is a general group action unrelated to targeting.

**Secondary concern:** `Group::DisbandGroup()` has no companion awareness, so
code paths that bypass the handler entirely (disconnect, LeaveGroup, cross-zone)
would also orphan the companion by clearing its group membership.

---

## Consensus Fix Approach (c-expert + protocol-agent)

### Fix 1 (Primary): Remove Case 1 from Handle_OP_GroupDisband

Remove lines 7322-7328 entirely. The Disband button should NEVER dismiss a
companion, regardless of what the player is targeting. Dismissal is only
possible through the explicit "dismiss" chat command.

Cases 2 and 3 already handle all valid scenarios:
- **Case 2** (owner + companion only): Blocks with hint message
- **Case 3** (multi-player group): Ejects non-owner, non-companion members

### Fix 2 (Secondary Hardening): Guard inside DisbandGroup

Add companion-aware logic to `Group::DisbandGroup()` (groups.cpp:940):

```cpp
void Group::DisbandGroup(bool joinraid) {
    // Companion protection: suspend companions before disbanding so they
    // persist and can rejoin on next login/zone-in.
    if (RuleB(Companions, CompanionsEnabled)) {
        for (uint32 i = 0; i < MAX_GROUP_MEMBERS; i++) {
            if (members[i] && members[i]->IsCompanion()) {
                members[i]->CastToCompanion()->Suspend();
            }
        }
    }
    // ... rest of existing DisbandGroup logic
}
```

This ensures that no matter HOW DisbandGroup is reached — LeaveGroup,
OnDisconnect, DelMember, cross-zone, scripting — the companion is always
suspended (saved to DB) before the group is destroyed.

### Fix 3 (Hardening): Client::LeaveGroup companion count

Subtract companion count from MemberCount in `Client::LeaveGroup()`
(groups.cpp:1283) so a player + companion group doesn't trigger premature
DisbandGroup when the player leaves.

---

## Files to Modify

| File | Line | Change |
|------|------|--------|
| `zone/client_packet.cpp` | 7322-7328 | Remove Case 1 (companion dismiss via Disband) |
| `zone/groups.cpp` | 940+ | Add companion suspension in DisbandGroup() |
| `zone/groups.cpp` | 1283+ | Subtract companions from MemberCount in LeaveGroup() |

---

## Protocol-Agent Answers (2026-02-27)

1. **Titanium sends `OP_GroupDisband` (0x0e76)** for the Disband button.
   `OP_GroupDelete` is mapped to 0x0000 (disabled) in Titanium.
2. **No difference at the packet level** between Leave and Disband. Same opcode,
   same struct. Server determines behavior based on IsLeader, GetTarget, GroupCount.
3. **No Titanium-specific translation** needed for OP_GroupDisband — passes through
   unchanged.
