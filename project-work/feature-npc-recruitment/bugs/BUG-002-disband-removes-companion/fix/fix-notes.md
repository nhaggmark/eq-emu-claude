# BUG-002 Fix Notes

**Agent:** c-expert
**Date:** 2026-02-27
**Status:** Fix applied, pending build verification

---

## Summary

Three-part fix to prevent the Disband button from ever removing or dismissing
a companion NPC. Dismissal is now exclusively handled by the explicit "dismiss"
chat command.

---

## Changes

### Fix 1: Remove Case 1 from Handle_OP_GroupDisband

**File:** `zone/client_packet.cpp` (companion protection block, ~line 7311)

**Before:** The protection block had three cases:
- Case 1: Leader targeting companion + Disband = `companion->Dismiss()` (BUG)
- Case 2: GroupCount <= 2 = hint message + return
- Case 3: Multi-player group = eject non-companion members + return

**After:** Case 1 (the dismiss path) is removed entirely. The remaining two
cases are renumbered:
- Case 1 (was 2): GroupCount <= 2 = hint message + return
- Case 2 (was 3): Multi-player group = eject non-companion members + return

**Why:** The Disband button is a general group action unrelated to targeting.
Players often have their companion targeted (after recruiting, inspecting,
etc.) when they click Disband. The old Case 1 treated this as intentional
dismissal when it was accidental. The Disband button should NEVER dismiss
a companion.

### Fix 2: Add companion suspension to Group::DisbandGroup()

**File:** `zone/groups.cpp` (DisbandGroup, ~line 940)

**Added:** Before the main member-clearing loop, scan all group slots for
companions. For each companion found:
1. `SetGrouped(false)` -- clear grouped state
2. Null the member slot and name -- break group membership
3. Call `Suspend()` -- saves to DB + depops gracefully

**Order matters:** The member slot is nulled BEFORE calling `Suspend()` to
prevent a recursive call chain:
- `Suspend()` -> `Depop()` -> `RemoveCompanionFromGroup()` -> `DisbandGroup()`
- By clearing `members[ci]` first, `GetGroup()` returns nullptr inside
  `Depop()`, so `RemoveCompanionFromGroup()` is skipped.

**Why:** `DisbandGroup()` is called from 6+ code paths:
1. `Handle_OP_GroupDisband` (normal disband logic at line 7362)
2. `Handle_OP_GroupDelete` (disabled in Titanium but active in other clients)
3. `Client::LeaveGroup()` when MemberCount < 3
4. `Group::DelMember()` when the leader is removed
5. `ServerOP_DisbandGroup` (cross-zone disband from world server)
6. Lua/Perl scripting API `group:DisbandGroup()`

The companion protection in Fix 1 only guards path #1. This fix is a safety
net that catches ALL paths.

### Fix 3: Fix Client::LeaveGroup() companion count

**File:** `zone/groups.cpp` (LeaveGroup, ~line 1298)

**Added:** After subtracting mercs from `MemberCount`, scan group slots for
companions owned by the leaving player and subtract them from the count. This
mirrors the existing bot/merc subtraction pattern.

**Why:** When a player + companion group has exactly 2 members (GroupCount==2),
any `LeaveGroup()` call (from disconnect, camp, zone) would compute
`MemberCount==2 < 3`, triggering `DisbandGroup()`. With the companion
subtracted, `MemberCount==1 < 3` still triggers `DisbandGroup()`, but Fix 2
ensures the companion is suspended rather than orphaned.

More importantly, in a 3-member group (player + companion + one other player),
if the other player leaves, `MemberCount` was 3 before this fix, so
`DisbandGroup()` was not called and `DelMember()` was used instead. This is
correct behavior. With the companion subtraction, `MemberCount` would be 2,
which triggers `DisbandGroup()` -- but Fix 2 handles that safely. The key
scenario is when the companion's OWNER leaves a multi-player group: without
this fix, the owner leaving with `MemberCount==3` causes `DelMember()` which
doesn't suspend the companion.

---

## What Was NOT Changed

- **Dismiss chat command:** Still works as before via `companion.lua` and
  `Companion::Dismiss()`
- **CompanionJoinClientGroup:** Group join logic is correct, unchanged
- **Recruitment flow:** Unchanged
- **OP_GroupDelete handler:** Unchanged (disabled in Titanium anyway, and
  Fix 2 covers it as a safety net)

---

## Verification Plan

1. Recruit a companion NPC
2. With companion targeted, click Disband -- should see hint message (NOT dismiss)
3. Without companion targeted, click Disband -- should see hint message
4. Add a third player to group, click Disband -- should eject other player, keep companion
5. Camp/disconnect with companion in group -- companion should be suspended (saved to DB)
6. Log back in -- companion should be restorable via unsuspend
7. Say "dismiss" -- companion should dismiss normally (separate path, unchanged)
