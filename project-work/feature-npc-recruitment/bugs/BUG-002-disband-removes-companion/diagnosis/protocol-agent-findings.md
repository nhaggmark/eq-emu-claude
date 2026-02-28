# BUG-002 Protocol Diagnosis: Disband Removes Companion

**Agent:** protocol-agent
**Date:** 2026-02-27
**Status:** Complete

---

## 1. What Packet Does the Disband Button Send?

The Titanium client's "Disband" button sends **`OP_GroupDisband`**, mapped to
wire opcode `0x0e76` in `utils/patches/patch_Titanium.conf:430`.

The packet body is a **`GroupGeneric_Struct`** (128 bytes):

```c
// common/eq_packet_structs.h:2486
struct GroupGeneric_Struct {
    char name1[64];  // The person performing the action (or the target, see below)
    char name2[64];  // The person being acted upon
};
```

There is **no action code** in the struct -- `OP_GroupDisband` serves both
"leave group" and "disband group" scenarios. The server determines which
action to take based on:
- Whether the sender is the group leader
- The sender's current target (`GetTarget()`)
- The group member count (`GroupCount()`)

**Key**: The Titanium client does NOT use `OP_GroupDelete` (mapped to `0x0000`
in `patch_Titanium.conf:436`, meaning disabled). All group disband/leave
actions route through a single opcode: `OP_GroupDisband`.

**No Titanium translation needed**: `OP_GroupDisband` is not listed in
`common/patches/titanium_ops.h` for either ENCODE or DECODE, meaning the
packet passes through the translation layer unchanged.

---

## 2. How Does the Server Handle the Disband Packet?

Handler: `Client::Handle_OP_GroupDisband` at `zone/client_packet.cpp:7197`

The handler is registered at line 233:
```cpp
ConnectedOpcodes[OP_GroupDisband] = &Client::Handle_OP_GroupDisband;
```

### Handler Flow (annotated):

```
7197  Handle_OP_GroupDisband(app)
7199  ├── Size validation: sizeof(GroupGeneric_Struct) == 128
7209  ├── Raid check: if in a raid, handle raid-specific disband → return
7264  ├── Bot check: if Bots:Enabled AND group has bots, special bot handling
7288  │   (Bot handling does NOT return for all cases -- can fall through!)
7293  ├── Determine memberToDisband:
7293  │     1. GetTarget() — the player's current target
7296  │     2. Fallback: entity_list.GetMob(gd->name2)
7298  │     3. If found mob not in same group → reset to self
7311  ├── COMPANION PROTECTION BLOCK (if CompanionsEnabled):
7314  │   ├── Scan group for any IsCompanion() member
7321  │   ├── If companion found:
7323  │   │   ├── Case 1: Leader targeting companion → Dismiss() + return
7331  │   │   ├── Case 2: GroupCount() <= 2 → hint message + return
7340  │   │   └── Case 3: Multi-player group → eject non-owner, non-companion + return
7362  │   └── All three cases return; code below is unreachable when companion present
7364  └── Normal disband logic (should be unreachable with companion):
7364      ├── GroupCount() < 3 → DisbandGroup()
7370      ├── Leader, no target → DisbandGroup()
7384      ├── Leader, targeting self → LeaveGroup()
7392      └── Else: DelMember() for targeted member
```

### Companion Protection Analysis

The protection block at lines 7311-7362 (added in commit `26056651d`) handles
three cases when a companion is detected in the group:

1. **Case 1** (line 7323): Leader explicitly targeting the companion and
   clicking Disband. Treated as intentional dismissal -- calls
   `companion->Dismiss()`. This is by design.

2. **Case 2** (line 7331): Only owner + companion remain (GroupCount <= 2).
   Sends a hint message ("Say 'dismiss' if you wish to release me") and
   returns without disbanding. **This is the primary protection for 2-person
   groups.**

3. **Case 3** (line 7340): Multi-player group with companion. Ejects all
   non-owner, non-companion members while keeping the owner + companion
   grouped. Returns without calling DisbandGroup().

**If the protection fires correctly, `DisbandGroup()` and other disband
logic at lines 7364+ should never be reached.**

---

## 3. Is There a Difference Between "Leave Group" and "Disband Group"?

**No, at the packet level.** The Titanium client sends the same opcode
(`OP_GroupDisband` / `0x0e76`) and the same struct (`GroupGeneric_Struct`)
for both actions. The server-side handler determines behavior based on:

- `group->IsLeader(this)` — is the sender the leader?
- `GetTarget()` — who is the player targeting?
- `group->GroupCount()` — how many members?

In a 2-person group (player + companion), clicking "Disband":
- Player is the leader (they created the group when recruiting)
- GroupCount() == 2
- The handler hits line 7331 (Case 2): blocked with hint message

**However**, there is a subtle interaction with the `memberToDisband`
determination at lines 7293-7301. If the player happens to have the
companion NPC targeted when they click Disband:

- `GetTarget()` returns the companion
- `memberToDisband` = companion
- Line 7323: Case 1 fires — `Dismiss()` is called

This means **the player's target at the moment of clicking Disband
determines whether the companion is protected or dismissed**.

---

## 4. How Do Bots Survive Disband?

Bots have a dedicated pre-handler block at `client_packet.cpp:7264-7286`:

```cpp
if (RuleB(Bots, Enabled) && Bot::GroupHasBot(group)) {
    if (group->IsLeader(this)) {
        if ((GetTarget() == 0 || GetTarget() == this) || (group->GroupCount() < 3)) {
            Bot::ProcessBotGroupDisband(this, std::string());
        }
        else {
            Mob* tempMember = entity_list.GetMob(gd->name1);
            if (tempMember && tempMember->IsBot()) {
                Bot::RemoveBotFromGroup(b, group);
                // ...
                return;  // <-- early return, bot handled
            }
        }
    }
}
```

Key differences from companion protection:
1. **Bots check happens BEFORE memberToDisband is determined** (line 7264 vs 7293)
2. **`ProcessBotGroupDisband` removes one bot at a time** — it does NOT call
   `DisbandGroup()` directly. Instead it calls `RemoveBotFromGroup` which
   handles the bot gracefully.
3. **Bot block does NOT always return** — the `ProcessBotGroupDisband` path
   at line 7267 does NOT have a `return`. It falls through to the rest of
   the handler. Only the explicit bot removal at line 7282 returns.

**Bots:Enabled is `false` on this server**, so the entire bot block is
skipped. This is not a factor.

---

## 5. Identified Vulnerability: Case 1 Targeting

The most likely cause of the reported bug:

**When the player has the companion NPC targeted and clicks "Disband" in the
Group Window, Case 1 (line 7323) fires and calls `Dismiss()`.**

In the Titanium client, a player might have the companion targeted for
various reasons (inspecting, interacting, etc.). Clicking "Disband" while
the companion is targeted would trigger the dismiss path, which was
designed for "explicitly kick the companion from group" but is
indistinguishable from "accidentally clicked Disband while companion
targeted."

### Why this is likely the bug:
- The user says "clicking Disband removes the companion"
- If the companion is the player's only group member, it's also likely
  the player's current target (especially right after recruitment)
- Case 2 protection (hint message) only fires when `memberToDisband`
  is NOT the companion

---

## 6. Other DisbandGroup() Bypass Paths (Lower Probability)

For completeness, these paths call `DisbandGroup()` without companion
protection:

| Location | Trigger | Risk |
|----------|---------|------|
| `client_packet.cpp:7189` | `OP_GroupDelete` handler | **None** — Titanium maps this to 0x0000 (disabled) |
| `groups.cpp:687` | `DelMember()` when removing group leader | Low — companion isn't the leader |
| `groups.cpp:734` | `DelMember()` when leader name is empty | Low — edge case |
| `groups.cpp:1313` | `Client::LeaveGroup()` when count < 3 | **Medium** — if a third party triggers LeaveGroup |
| `worldserver.cpp:1334` | `ServerOP_DisbandGroup` from world | Low — cross-zone only |
| `companion.cpp:799` | `RemoveCompanionFromGroup()` | Downstream of Dismiss — not a bypass |
| Lua/Perl scripts | `group:DisbandGroup()` | Possible but no known trigger |

---

## 7. Recommendation

**Primary fix**: Remove Case 1 from the companion protection block. The
Disband button should NEVER dismiss a companion, regardless of targeting.
Dismissal should only be possible via the explicit "dismiss" chat command.

Replace lines 7322-7328:
```cpp
// Case 1: leader is explicitly targeting the companion to kick them
if (group->IsLeader(this) && memberToDisband == companion_in_group) {
    companion_in_group->Dismiss();
    if (LFP)
        UpdateLFP();
    return;
}
```

With:
```cpp
// Companion is targeted — treat same as Case 2/3, never dismiss via Disband
// Dismissal only happens through the explicit chat command.
```

Then let Cases 2 and 3 handle all scenarios:
- 2-person group (owner + companion): Case 2 blocks with hint
- Multi-player group: Case 3 ejects non-companion members

**Secondary hardening**: Add companion protection to `Group::DisbandGroup()`
itself as a safety net against the bypass paths listed in section 6.

---

## 8. Wire Format Reference

```
OP_GroupDisband (Titanium wire opcode: 0x0e76)
Internal opcode: OP_GroupDisband (common/emu_oplist.h:215)
No Titanium ENCODE/DECODE translation required

Packet body: GroupGeneric_Struct (128 bytes, #pragma pack(1))
  Offset  Size  Field    Description
  0x00    64    name1    Action performer's name (char[64])
  0x40    64    name2    Target of action (char[64])

Related opcodes (all disabled in Titanium, 0x0000):
  OP_GroupDelete      — alternate disband (not used)
  OP_GroupDisbandOther — used by RoF2+ only
  OP_GroupDisbandYou   — used by RoF2+ only
```
