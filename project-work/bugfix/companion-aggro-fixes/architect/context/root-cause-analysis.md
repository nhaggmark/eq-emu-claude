# BUG-009 Root Cause Analysis — Companion Aggro

## Investigation Summary

The root cause is that `Companion` does not override `IsOfClientBotMerc()`,
causing it to return `false` (inherited from `Entity` base class). This
causes companions to be treated as plain NPCs by the hate list maintenance
system, which periodically purges all NPC entries from mob hate lists.

## Code Path Trace

### How hate is generated (works correctly)

1. `Companion::Attack()` → `NPC::Attack()` (companion.cpp:416)
2. `NPC::Attack()` → `other->AddToHateList(this, hate)` (attack.cpp:2381)
3. `NPC::Attack()` → `other->Damage(this, ...)` (attack.cpp:2397)
4. `Mob::CommonDamage()` → `AddToHateList(attacker, 0, damage, ...)` (attack.cpp:4124)
5. `Mob::AddToHateList()` → `hate_list.AddEntToHateList()` (attack.cpp:3228)

**Companion IS successfully added to the mob's hate list.**

### How hate is wiped (the bug)

1. Mob is engaged, running `Mob::AI_Process()` (mob_ai.cpp)
2. `AI_target_check_timer->Check()` fires (mob_ai.cpp:1066)
3. Guard check: `IsNPC() && !IsCompanion() && !GetSwarmInfo() && ...` (mob_ai.cpp:1067-1072)
   - For a regular NPC mob (not a companion), this is TRUE
4. `WipeHateList(true)` is called (mob_ai.cpp:1074)
5. In `HateList::WipeHateList(bool npc_only)` (hate_list.cpp:44-72):
   - For each hate entry, check if it should be KEPT:
     ```cpp
     m->IsOfClientBotMerc() ||
     (m->IsPet() && m->GetOwner() && m->GetOwner()->IsOfClientBotMerc())
     ```
   - Client: `IsOfClientBotMerc()` = true → KEPT
   - Bot: `IsOfClientBotMerc()` = true → KEPT
   - Merc: `IsOfClientBotMerc()` = true → KEPT
   - Pet of Client/Bot: `IsPet()` = true, owner = client/bot → KEPT
   - **Companion: `IsOfClientBotMerc()` = FALSE, `IsPet()` = FALSE → WIPED**

### Secondary issue: SmartAggroList

Even if the companion stayed on the hate list, `GetMobWithMostHateOnList()`
in SmartAggroList mode (hate_list.cpp:481-506) checks if the top-hate
entity is a "client type":

```cpp
bool is_top_client_type = top_hate->IsClient();
if (!is_top_client_type) { if (top_hate->IsBot()) ... }
if (!is_top_client_type) { if (top_hate->IsMerc()) ... }
if (!is_top_client_type) { if (top_hate->GetSpecialAbility(AllowedToTank)) ... }
if (!is_top_client_type) {
    return top_client_type_in_range;  // prefer client-type in range
}
```

Companions are not checked here, so even with maximum hate, a client/bot/merc
in melee range would be preferred as the target.

## Files Modified by Companions (for reference)

| File | What was changed | Purpose |
|------|-----------------|---------|
| `aggro.cpp:409` | `IsCompanion()` guard in `CheckWillAggro()` | Prevent companions from initiating faction-based aggro scanning |
| `npc.cpp:776` | `!IsCompanion()` in assist_timer block | Prevent companions from calling `AIYellForHelp()` |
| `mob_ai.cpp:1069` | `!IsCompanion()` in AI_target_check | Prevent companions from running `WipeHateList(true)` on themselves |

These three guards are CORRECT and must remain. The bug is NOT in these
guards — it's in the hate list maintenance of OTHER mobs that attack or
are attacked by companions.

## Comparison with Bot/Merc

| Check | Client | Bot | Merc | Companion (current) | Companion (fixed) |
|-------|--------|-----|------|---------------------|--------------------|
| `IsOfClientBot()` | true | true | false | **false** | true |
| `IsOfClientBotMerc()` | true | true | true | **false** | true |
| `IsPet()` | false | false | false | false | false |
| Preserved by WipeHateList? | YES | YES | YES | **NO** | YES |
| SmartAggroList tank? | YES | YES | YES | **NO** | YES |
