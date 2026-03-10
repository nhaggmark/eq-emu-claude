# BUG-011: Zone Crash When Companion Dies in Combat

## Root Cause Analysis

### Executive Summary

When a companion NPC dies in combat, its pointer is left dangling in the
group's `members[]` array. The companion object is deleted (via `safe_delete`)
during the entity cleanup pass, but the group is never notified. On the next
(or same) tick, `Group::QueueClients()` iterates `members[]`, dereferences the
freed pointer, and crashes the zone process.

### Crash Stack Trace

```
#4  Group::QueueClients (distance=-300) — groups.cpp:2600
#5  Client::Handle_OP_ClientUpdate — client_packet.cpp:5062
#7  Client::Process — client_process.cpp:625
```

Frame 3 is an unmapped address — dangling pointer dereference.

---

## Detailed Analysis

### 1. The Companion Death Path

When a companion's HP reaches 0, the death sequence is:

```
1. Companion::Death() called
2.   -> NPC::Death() called (attack.cpp:2472, base class)
3.     -> SetHP(0)                                    (line 2541)
4.     -> entity_list.RemoveFromTargets(this, p_depop) (line 2553)
5.     -> BuffFadeAll()                                (line 2563)
6.     -> Creates corpse (Corpse object)               (line 2875)
7.     -> entity_list.LimitRemoveNPC(this)             (line 2891)
8.     -> entity_list.RemoveNPC(GetID())               (line 2902) *** Removes from npc_list ***
9.     -> SetID(0)                                     (line 2905) *** Zeroes entity ID ***
10.    -> p_depop = true                               (line 3017)
11.    -> NPC::Death() returns true
12. Back in Companion::Death():
13.   -> Starts m_death_despawn_timer                  (line 368)
14.   -> Does NOT remove companion from group
15.   -> Returns true
```

**Key observation:** At no point during the death sequence is the companion
removed from the group's `members[]` array. The companion remains in the group
with a `p_depop = true` flag, entity ID = 0, and removed from `npc_list`.

### 2. Why `HasOwner()` Returns False

The corpse creation path at line 2823 checks `!HasOwner()`. For companions,
`HasOwner()` returns false because:

- `HasOwner()` (mob.h:1096) checks `GetOwnerID()` which uses the standard Mob
  `ownerid` field
- Companions use their own `m_owner_char_id` field instead — they do NOT set
  the standard Mob `ownerid`
- This means companions are treated like regular NPCs during death, getting a
  corpse created and being removed from `npc_list`

### 3. Entity Cleanup: The Dangling Pointer

After NPC::Death() returns, the entity cleanup code in `EntityList::MobProcess()`
(entity.cpp:481) iterates `mob_list` and checks each mob:

```cpp
// entity.cpp:542
mob_dead = !mob->Process();
// or:
// entity.cpp:546
mob_dead = mob->CastToNPC()->GetDepop();
```

When `mob_dead` is true for a companion (entity.cpp:564-571):

```cpp
if (mob->IsCompanion()) {
    entity_list.RemoveCompanion(id);   // removes from companion_list
    entity_list.RemoveNPC(id);          // already gone (no-op), but tries
}
// ...
entity_list.RemoveMob(id);             // calls safe_delete(mob) !!!
```

**Critical bug:** Lines 569-571 do NOT remove the companion from its group.
Compare with the Client cleanup path at lines 581-584:

```cpp
} else {
    Group* g = GetGroupByMob(mob);
    if (g) {
        g->DelMember(mob);             // <-- Client removes from group!
    }
    // ...
}
```

After `RemoveMob(id)` calls `safe_delete(it->second)` at entity.cpp:2816,
the companion object is freed. The group's `members[i]` pointer is now
dangling.

### 4. The Crash

On the next (or same) main loop tick:

```
Client::Process()
  -> Client::Handle_OP_ClientUpdate()     (client_packet.cpp:5062)
    -> Group *group = GetGroup()
    -> group->QueueClients(this, &outapp, true, true, -300)
      -> for (i = 0; i < MAX_GROUP_MEMBERS; i++)
        -> if (!members[i]) continue      // line 2597: NULL check passes (pointer is non-zero)
        -> members[i]->IsClient()         // line 2600: CRASH - dereferencing freed memory
```

The NULL check at line 2597 does NOT catch this because the freed pointer is
non-zero (it's the old heap address). The vtable lookup for `IsClient()` reads
garbage memory from the freed heap allocation, causing the crash.

### 5. Timing

The crash can happen:

- **Same tick as death:** If the client has a higher entity ID than the companion,
  the mob_list iteration processes the companion cleanup (safe_delete) before
  the client's Process(). The client then dereferences the freed pointer.
  
- **Next tick:** If the client has a lower entity ID, the companion cleanup
  happens on the next tick. But the next client update tick after cleanup will
  crash.

Either way, the crash is deterministic — it WILL happen once the companion
dies and the entity cleanup runs.

---

## Comparison with Bot/Merc Death Handling

### Bot::Death() (bot.cpp:4924)

```cpp
bool Bot::Death(...) {
    NPC::Death(...);           // Base death handling
    // ...
    Zone();                    // <-- THIS IS THE KEY
    entity_list.RemoveBot(GetID());
}
```

`Bot::Zone()` (bot.cpp:6971):
```cpp
void Bot::Zone() {
    if (auto raid = entity_list.GetRaidByBot(this)) {
        raid->MemberZoned(CastToClient());
    }
    else if (HasGroup()) {
        GetGroup()->MemberZoned(this);  // <-- Removes from group BEFORE depop
    }
    Save();
    Depop();
}
```

**Bots handle this correctly:** `Bot::Death()` calls `Zone()` which calls
`GetGroup()->MemberZoned(this)` to NULL out the group's `members[]` entry
BEFORE depoping. This prevents the dangling pointer.

### Merc::Death() (merc.cpp:4073)

```cpp
bool Merc::Death(...) {
    NPC::Death(...);
    Save();
    if (!Suspend()) {
        Depop();               // <-- Merc::Depop handles group cleanup
    }
}
```

`Merc::Suspend()` (merc.cpp:5187) calls `Depop()` which handles group removal.

**Mercs also handle this correctly** by removing from the group during Suspend/Depop.

### Companion::Death() — THE BUG

```cpp
bool Companion::Death(...) {
    NPC::Death(...);           // Creates corpse, removes from npc_list, sets p_depop
    // ... equipment, notification, save ...
    m_death_despawn_timer.Start();
    return result;
    // <-- MISSING: No group removal!
}
```

The companion's Death handler does NOT remove itself from the group. It starts
a despawn timer and returns. The companion stays in the group's `members[]`
array as a ticking time bomb.

---

## Proposed Fix

### Primary Fix: Remove companion from group on death

In `Companion::Death()` (companion.cpp:325), add group removal BEFORE returning:

```cpp
bool Companion::Death(Mob* killer_mob, int64 damage, uint16 spell_id,
                      EQ::skills::SkillType attack_skill,
                      KilledByTypes killed_by, bool is_buff_tic)
{
    bool result = NPC::Death(killer_mob, damage, spell_id, attack_skill, killed_by, is_buff_tic);

    // [existing equipment handling code]

    Client* owner = GetCompanionOwner();
    if (owner) {
        // [existing notification and save code]
    }

    // FIX: Remove from group BEFORE the entity cleanup pass can delete us.
    // This prevents the dangling pointer in group->members[].
    // Matches how Bot::Death() calls Zone() -> MemberZoned() to clean up
    // the group reference before the entity is depopulated.
    if (HasGroup()) {
        Group* g = GetGroup();
        if (g) {
            g->MemberZoned(this);  // NULLs out our members[] slot
        }
    }

    return result;
}
```

### Safety Net Fix: Add group cleanup to entity list companion cleanup

In `EntityList::MobProcess()` (entity.cpp:569-571), add group cleanup for
companions, matching the Client path:

```cpp
} else if (mob->IsCompanion()) {
    // Safety net: ensure companion is removed from group before deletion
    Group* g = entity_list.GetGroupByMob(mob);
    if (g) {
        g->MemberZoned(mob);  // NULL out the members[] entry
    }
    entity_list.RemoveCompanion(id);
    entity_list.RemoveNPC(id);
}
```

### Second Safety Net Fix: Add group cleanup to Process() death timer path

In `Companion::Process()` (companion.cpp:470-484), add group cleanup before
returning false:

```cpp
if (m_death_despawn_timer.Enabled() && m_death_despawn_timer.Check()) {
    // ... existing code ...
    SoulWipe();

    // Clean up group membership before entity deletion
    if (HasGroup()) {
        Group* g = GetGroup();
        if (g) {
            g->MemberZoned(this);
        }
    }

    return false;
}
```

### Why `MemberZoned()` Instead of `DelMember()`

`Group::MemberZoned()` (groups.cpp:572) simply NULLs out the `members[]` entry
without sending packets or touching the world server. This is appropriate
because:

1. The companion is dead/being removed — no need for a "leave group" packet
2. `DelMember()` sends ServerOP_GroupLeave to world and OP_GroupUpdate to clients,
   which could cause issues for a dead entity
3. Bot::Zone() uses `MemberZoned()` for the same reason
4. After MemberZoned, the members[] slot is NULL, so QueueClients skips it

### Additional Consideration: IsOfClientBotMerc() Override

The companion overrides `IsOfClientBotMerc()` to return `true` (companion.h:104).
This causes code paths that check `IsOfClientBotMerc()` to treat the companion
like a client/bot/merc. However, `Group::QueueClients()` does NOT use
`IsOfClientBotMerc()` — it uses `IsClient()`. So this override is NOT the
direct cause of the crash. But it should be reviewed for other potential issues
where code assumes `IsOfClientBotMerc() == true` entities are always valid/alive.

---

## Files Requiring Changes

| File | Line(s) | Change |
|------|---------|--------|
| `zone/companion.cpp` | ~370 (Death method) | Add group removal before return |
| `zone/entity.cpp` | 569-571 (MobProcess cleanup) | Add group cleanup for companions |
| `zone/companion.cpp` | 470-484 (Process death timer) | Add group cleanup before return false |

## Testing

1. Recruit a companion into the group
2. Enter combat with a hostile NPC
3. Let the companion die (use a high-level NPC)
4. Verify the zone does NOT crash
5. Verify the companion is removed from the group window
6. Verify the death despawn timer works (if not resurrected, companion is soul-wiped)
7. Verify resurrection path still works (if implemented)

## Risk Assessment

- **Low risk:** The fix uses `MemberZoned()` which is the established pattern
  used by bots for the identical scenario (death during group membership)
- **Regression risk:** None expected — the fix only adds cleanup that was
  missing, following existing patterns
- **Edge cases:**
  - Multiple companions dying simultaneously: Each Death() call handles its own
    group cleanup independently
  - Companion dying while owner is zoning: Group may already be disbanded;
    `HasGroup()` check handles this
  - Companion dying from buff tick (not direct attack): Same Death() path,
    same fix applies
