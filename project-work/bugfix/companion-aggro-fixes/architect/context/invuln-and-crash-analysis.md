# Investigation: Crash at groups.cpp:2600, Invulnerable Companions, and Aimless Running

Date: 2026-03-09

## Issue 1: QueueClients Crash at Line 2600

### Key Finding: Line 2600 is NOT in QueueClients

The crash was reported as being at `Group::QueueClients` line 2600. However, in the current
source code:

- **Line 2600** is inside `GetMemberRole(const char* name)` — specifically the `if (!name)` null check
- **`QueueClients` starts at line 2619** and DOES have the `ValidateMember(i)` check at line 2623

This means either:
1. The crash happened on a build BEFORE the ValidateMember fix was compiled (line numbers shifted)
2. The crash is actually in a nearby function, not QueueClients specifically

### The ValidateMember Fix IS Present in QueueClients

```cpp
// Line 2619-2648
void Group::QueueClients(Mob *sender, const EQApplicationPacket *app, ...) {
    if (sender && sender->IsClient()) {
        for (uint32 i = 0; i < MAX_GROUP_MEMBERS; i++) {
            if (!ValidateMember(i))     // <-- FIX IS HERE at line 2623
                continue;
            if (!members[i]->IsClient())
                continue;
            // ... safe to use members[i] ...
        }
    }
}
```

### But MANY Other Functions Are STILL Unguarded

The `ValidateMember()` fix was only applied to 12 functions. There are **dozens** of other
group iteration loops that still use bare `members[i] && ...` null checks, which are
vulnerable to the same stale-pointer crash:

**Unguarded critical loops (members[] with null check only, no ValidateMember):**

| Line | Function | Risk |
|------|----------|------|
| 142 | `SplitMoney` | Dereferences `members[i]->IsClient()` |
| 173 | `SplitMoney` (second loop) | Range-for with bare null check |
| 672 | `DelMember` | `if(!members[i])` bare check |
| 745 | `DelMember` | `if(members[nl])` bare check |
| 780 | `DisbandGroup` | `if (members[i] == nullptr)` — then dereferences |
| 958 | `GetTotalGroupDamage` | `if(!members[i])` bare check |
| 1003 | `DisbandGroup` (second path) | `if (members[i] == nullptr)` |
| 1173 | `SendGroupLeadershipAA` | `if(members[i] && members[i]->IsClient())` |
| 1205 | `GetHighestLevel` | `if (members[i])` bare check |
| 1220 | `GetLowestLevel` | `if (members[i])` bare check |
| 1234 | `TeleportGroup` | `if (members[i] != nullptr && ...)` |
| 1551 | `GetAvgLevel` | `if (members[i])` bare check |
| 1663 | `DelegateMainTank` | `if(members[i] && members[i]->IsClient())` |
| 1709 | `DelegateMainAssist` | Same pattern |
| 1756 | `DelegatePuller` | Same pattern |
| 1925 | `UnDelegateMainTank` | Same pattern |
| 1959 | `UnDelegateMainAssist` | Same pattern |
| 2002 | `UnDelegatePuller` | Same pattern |
| 2037 | `SendGroupSAA` | Same pattern |
| 2050 | `UpdateGroupTankTarget` | Same pattern |
| 2063 | `UpdateGroupPullerTarget` | Same pattern |
| 2155 | `NotifyMarkNPC` | Same pattern |
| 2232 | `SendGroupUpdate` (part) | Same pattern |
| 2336 | `SendGroupMarkedNPCs` | Same pattern |
| 2358 | `GetNeedHealMember` | `if(members[i] && !members[i]->qglobal)` |
| 2468 | `UpdateXTargets` | Same pattern |
| 2478 | `SetDirtyAutoHaters` | Same pattern |
| 2488 | `SaveGroupLeaderAA` | Same pattern |
| 2584 | `GetMemberRole(Mob*)` | `if (m == members[i])` — comparison only, likely safe |
| 2605 | `GetMemberRole(const char*)` | Uses `membername[]` not `members[]`, but dereferences `leader` |
| 2659 | `AnyMemberHasDzLockout` | `members[i] && members[i]->IsClient()` |

### Stale `leader` Pointer Risk

`GetMemberRole(const char* name)` at line 2608 dereferences `leader->GetName()`:
```cpp
if (leader && !strcasecmp(leader->GetName(), name)) {
```
The `leader` pointer has the SAME stale-pointer risk as `members[]`. If the leader entity
is freed, `leader` becomes dangling. The null check `leader &&` is insufficient.

### Root Cause Hypothesis

The crash at "line 2600" is likely from a pre-fix build where QueueClients was at that
line. Alternatively, the crash could be in one of the UNGUARDED functions listed above,
and the crash report misidentified the function.

### Recommendation

Apply `ValidateMember()` to ALL remaining group iteration loops, not just the 12 that
were fixed. Also add validation for the `leader` pointer (either validate it similarly
to members, or null it when the leader entity is freed).

---

## Issue 2: Companions Showing as INVULNERABLE

### What Makes an Entity "Invulnerable"

The `DMG_INVULNERABLE` (-5) damage result is displayed to the player when:

1. **`GetInvul()` returns true** — the `invulnerable` member variable is set
2. **`DivineAura()` returns true** — `spellbonuses.DivineAura` is set (buff-based)
3. **`GetSpecialAbility(SpecialAbility::MeleeImmunity)` is true** — special ability 19
4. **`GetWeaponDamage()` returns 0** — which combines checks from #1 and #3

Code paths in `attack.cpp`:
- Line 1124: `GetInvul() || MeleeImmunity` → return 0 (no weapon damage possible)
- Line 1646: `if (my_hit.base_damage > 0)` → else sets `DMG_INVULNERABLE` at line 1722
- Line 4084: `GetInvul() || DivineAura()` → sets `damage = DMG_INVULNERABLE`

### What Sets `invulnerable = true`

1. `SpellEffect::DivineAura` buff effect (spell_effects.cpp:1332)
2. `gminvul` flag from account table (client_packet.cpp:1417) — clients only
3. `#set invulnerable` GM command
4. Bot zone-in buff restoration (bot.cpp:391) — bots only

### Companion Analysis: Why Could They Be Invulnerable?

**`invulnerable` flag initialization:** Mob constructor sets `invulnerable = false` at
mob.cpp:286. Companion inherits from NPC which inherits from Mob. No code in the
Companion constructor, `Spawn()`, `Load()`, or `LoadBuffs()` sets `invulnerable = true`.

**NPCType struct:** Does NOT have an `invulnerable` field (checked zonedump.h:36-162).
The invulnerable flag is NOT loaded from the npc_types table.

**Special abilities:** If the source NPC's `special_abilities` database field contains
`19,1` (MeleeImmunity), the companion would inherit it. This would be NPC-specific, not
a universal companion issue. Check the `npc_types.special_abilities` field for the specific
NPC being recruited.

**Buff-based invulnerability:** The `LoadBuffs()` function (companion.cpp:1287) restores
buffs from the database and calls `CalcBonuses()` at line 1335. If any saved buff has
a DivineAura spell effect, `CalcBonuses()` would set `spellbonuses.DivineAura = true`,
making the companion invulnerable to all damage via the `DivineAura()` check at
attack.cpp:4084.

**IsAttackAllowed analysis:** Companions are correctly attackable:
- `_NPC(companion)` returns true (IsNPC=true, no ownerid)
- NPC vs NPC path returns true at aggro.cpp:914
- Bot::IsBotAttackAllowed doesn't interfere (only fires when attacker/target is Bot)
- No special immunity abilities set by default

### Most Likely Causes (in order of probability)

1. **Source NPC has `special_abilities` containing MeleeImmunity (19,1)** — inherited by
   companion from the npc_types record. Easy to check in DB.

2. **A DivineAura buff was saved and restored** — check companion_buffs table for any
   spell with DivineAura effect.

3. **The `invulnerable` flag was set by a GM command** — `#set invulnerable on` while
   targeting the companion. Unlikely but possible during testing.

4. **The bodytype causes immunity** — `BodyType::NoTarget` or `BodyType::NoTarget2` would
   make the companion untargetable (aggro.cpp:810). Check the source NPC's bodytype field.

### Recommendation

1. Query the database for the specific companion NPC type:
   ```sql
   SELECT id, name, special_abilities, bodytype FROM npc_types WHERE id = <npc_type_id>;
   ```
2. Clear any MeleeImmunity special ability from companions at spawn time
3. Strip DivineAura buffs from companions at spawn/unsuspend
4. Add a safety clear in `Companion::Spawn()`:
   ```cpp
   invulnerable = false;
   ClearSpecialAbility(SpecialAbility::MeleeImmunity);
   ```

---

## Issue 3: Companion Running Aimlessly After Taking Damage

### WipeHateList Analysis

The `WipeHateList(bool npc_only)` function at hate_list.cpp:44 skips entries where
`IsOfClientBotMerc()` returns true when `npc_only=true`. Since companions now return
`IsOfClientBotMerc()=true` (companion.h:104), the behavior for enemy NPCs calling
`WipeHateList(true)` is:

- Enemy NPC keeps companion entries on hate list (correct — enemies should keep fighting companions)
- BUT: The companion's OWN hate list management could be affected

### AI Target Management

When the companion takes damage, `Companion::Damage()` (companion.cpp:387) is called,
which delegates to `NPC::Damage()`. This adds the attacker to the companion's hate list.

The companion's `Process()` method (companion.cpp:483) has custom target selection:
- **PASSIVE**: Wipes hate list, clears target
- **BALANCED**: Scans for NPCs attacking group members
- **AGGRESSIVE**: Actively seeks hostiles near the owner

The AI_Process (mob_ai.cpp:966) has this critical code at line 1069:
```cpp
if (IsNPC() && !IsCompanion() && !CastToNPC()->GetSwarmInfo() && ...) {
    WipeHateList(true); // wipe NPCs from hate list
}
```
The `!IsCompanion()` guard was correctly added to prevent wiping the companion's own
hate list during target checks. Without this, the companion's hate list would be wiped
every tick in combat.

### Potential Aimless Running Causes

1. **Owner target becomes invalid:** The companion's BALANCED stance checks at
   companion.cpp:602 look at `owner->GetTarget()`. If the owner's target dies or
   zones, the companion may lose its target and start wandering.

2. **Follow ID after combat:** When not engaged, the companion should follow its owner
   (follow ID was set during CompanionJoinClientGroup). If the follow behavior conflicts
   with combat target selection, the companion may alternate between chasing and fighting.

3. **Flee behavior:** Line 522-524 suppresses flee when `CompanionFleeEnabled` rule is
   off. But if the rule IS enabled, the companion would flee when HP drops low. The
   fear pathing code at mob_ai.cpp:993-1021 makes mobs run to random locations.

4. **Target out of range/LoS:** The AI_Process combat chase logic (mob_ai.cpp:1150+)
   has the companion chase its target. If the target is unreachable, the companion may
   run to unexpected locations.

5. **Hate list cleanup:** At mob_ai.cpp:1052, `hate_list.RemoveStaleEntries(600000, ...)` 
   removes stale hate entries. If the companion's hate entries become stale (e.g., the
   mob that damaged it ran away), the companion becomes disengaged and may wander.

### The IsOfClientBotMerc Connection

The `IsOfClientBotMerc()=true` override does NOT directly cause aimless running. Its
effects are:
- Enemy NPCs keep companion on their hate list during `WipeHateList(true)` — correct
- Various bonus caps apply (ItemSpellDmgCap, ItemHealAmtCap) — no AI effect
- Certain immunity checks change — no AI effect
- PC-only spells can land on companions — could cause unexpected buffs/debuffs

### Recommendation

1. Verify the `CompanionFleeEnabled` rule — if true, disable it to prevent flee behavior
2. Add a safety check in BALANCED stance to re-engage if the companion was just damaged:
   ```cpp
   // If we were just hit and have someone on hate list, engage them
   if (!IsEngaged() && !hate_list.IsHateListEmpty()) {
       SetTarget(hate_list.GetMobWithMostHateOnList(this));
   }
   ```
3. Check the companion's follow behavior after combat ends — ensure it returns to follow
   mode when disengaged

---

## Summary of All Group Iteration Vulnerabilities

Total member iteration loops in groups.cpp: ~60+
Loops protected by ValidateMember: ~12
Loops with bare null checks only: ~30+
Loops using membername[] (safe): ~5
Other patterns: ~13

The ValidateMember fix addressed only a fraction of the vulnerability surface.

---

## Additional Safety Net Findings

### Entity Cleanup Path (entity.cpp)

The entity cleanup tick at entity.cpp:569-578 correctly calls `g->MemberZoned(mob)`
BEFORE `RemoveCompanion(id)` and `RemoveNPC(id)`. This ensures the group `members[]`
slot is nulled before the companion entity is freed.

### Companion::Death() Group Cleanup Order

The death path is:
1. `NPC::Death()` runs (creates corpse, processes loot, XP, etc.) — companion still in group
2. `g->MemberZoned(this)` nulls the group slot — companion still exists in memory
3. Function returns, entity cleanup eventually frees the companion

This ordering is correct — the group slot is nulled before the entity is freed.

### The Real Remaining Risk: Non-Death Removal Paths

If a companion is removed from the entity list through a path that does NOT call
`MemberZoned()` or `RemoveCompanionFromGroup()`, the group will hold a dangling pointer.
The `ValidateMember()` function catches these cases by verifying `entity_list.GetMob(mob_id)`
matches the stored pointer, but only in the 12 functions where it was applied.

### Timeline of Fix vs Crash

If the server was still running a build from BEFORE the ValidateMember fix, the crash
at "line 2600" makes sense — that would have been QueueClients in the old source. After
the fix was compiled and deployed, the QueueClients function would have the guard.

**Key question for the user:** Was the server rebuilt and restarted after the ValidateMember
fix was committed? If the crash happened on a running server that wasn't restarted, it was
still running the old unpatched binary.
