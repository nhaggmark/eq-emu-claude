# BUG-007: Companion Does Not Regenerate HP — C-Expert Diagnosis

## Summary

The BUG-006 commit (a1a7d605d) correctly added the `CalcHPRegen()` override and
the two rules (`Companions::HPRegenPerTic`, `Companions::OOCRegenPct`), and seeds
`hp_regen` and `ooc_regen` in `AI_Start()`. These are necessary but not sufficient.

**Root cause:** `EntityList::RemoveFromHateLists()` only iterates `npc_list`.
Companions live in `companion_list` (and `mob_list`), not `npc_list`. When an
enemy NPC dies, the companion's hate list is never cleaned up. `IsEngaged()`
stays `true` indefinitely (up to 10 minutes, when `RemoveStaleEntries` fires).
The OOC regen branch in `NPC::Process()` requires `!IsEngaged()`, so it never
fires after combat ends.

---

## Code Path Analysis

### Regen infrastructure (added in BUG-006 commit)

**`eqemu/zone/companion.cpp:396–408`** — `Companion::CalcHPRegen()`
```cpp
int64 Companion::CalcHPRegen() const {
    int64 native_regen = NPCTypedata ? NPCTypedata->hp_regen : 0;
    int64 floor_regen  = static_cast<int64>(RuleI(Companions, HPRegenPerTic));
    return std::max(native_regen, floor_regen);
}
```
This is correctly implemented. It returns the higher of the NPC's native
`hp_regen_rate` from `npc_types` and the rule floor.

**`eqemu/zone/companion.cpp:420–436`** — `Companion::AI_Start()`
```cpp
hp_regen = CalcHPRegen();
ooc_regen = RuleI(Companions, OOCRegenPct);
```
Both values are correctly seeded when AI starts.

**`eqemu/common/ruletypes.h:1200–1201`** — Rules exist:
```
RULE_INT(Companions, HPRegenPerTic, 1, ...)
RULE_INT(Companions, OOCRegenPct, 5, ...)
```

### NPC::Process() regen block

**`eqemu/zone/npc.cpp:621–681`** — The regen tic fires every 6 seconds.
For companions (not pets, `IsPet()` returns false because `GetOwnerID()` == 0):

```cpp
// Line 655-661
if ((GetHP() < GetMaxHP()) && !IsPet()) {
    if (!IsEngaged()) {
        SetHP(GetHP() + npc_regen + npc_sitting_regen_bonus);  // OOC path
    } else {
        SetHP(GetHP() + npc_hp_regen);                          // combat path
    }
}
```

- `npc_regen = max(npc_hp_regen, ooc_regen_calc)` where `ooc_regen_calc = GetMaxHP() * ooc_regen / 100`
- In combat: companion regens at `hp_regen` rate (default floor: 1 HP/tic)
- OOC: never reached because `IsEngaged()` stays true

### Why `IsEngaged()` stays true after combat ends

**`eqemu/zone/mob.h:785`**
```cpp
bool IsEngaged() { return(!hate_list.IsHateListEmpty()); }
```

**`eqemu/zone/entity.cpp:3220–3237`** — `EntityList::RemoveFromHateLists()`:
```cpp
void EntityList::RemoveFromHateLists(Mob *mob, bool settoone)
{
    auto it = npc_list.begin();      // ← only npc_list!
    while (it != npc_list.end()) {
        if (it->second->CheckAggro(mob)) {
            it->second->RemoveFromHateList(mob);
            // ...
        }
        ++it;
    }
}
```

**`eqemu/zone/companion.cpp:1682–1711`** — `EntityList::AddCompanion()`:
```cpp
companion_list.emplace(...);
mob_list.emplace(...);
// Note: companions are also NPCs, but we do NOT add to npc_list
```

Companions are in `mob_list` + `companion_list` only — NOT in `npc_list`. When
an enemy dies and triggers `RemoveFromHateLists`, the companion is skipped.

### Hate list cleanup fallback

**`eqemu/zone/mob_ai.cpp:1052–1058`** — `RemoveStaleEntries()` fires on
`hate_list_cleanup_timer` (10 minutes or out-of-range). This eventually clears
the stale entry, but only after 10 minutes, making OOC regen effectively broken
for any post-combat scenario shorter than that window.

---

## What Works vs. What Doesn't

| Behavior | Status | Reason |
|----------|--------|--------|
| In-combat HP regen | Works | `hp_regen` seeded in AI_Start(), used in engaged branch |
| OOC HP regen after combat | Broken | `IsEngaged()` stays true; hate list not cleared |
| OOC HP regen if never in combat | Works | Hate list is empty from the start |
| Regen for NPCs with hp_regen=0 | Works (in combat) | CalcHPRegen() floor = 1 HP/tic |

---

## Required Fix

Extend `EntityList::RemoveFromHateLists()` in `eqemu/zone/entity.cpp` to also
iterate `companion_list`, mirroring the `npc_list` loop:

```cpp
void EntityList::RemoveFromHateLists(Mob *mob, bool settoone)
{
    // Existing: clear dead mob from NPC hate lists
    for (auto it = npc_list.begin(); it != npc_list.end(); ++it) {
        if (it->second->CheckAggro(mob)) {
            if (!settoone) {
                it->second->RemoveFromHateList(mob);
                it->second->RemoveFromRampageList(mob);
                if (mob->IsClient()) {
                    mob->CastToClient()->RemoveXTarget(it->second, false);
                }
            } else {
                it->second->SetHateAmountOnEnt(mob, 1);
            }
        }
    }

    // NEW: also clear from companion hate lists
    for (auto it = companion_list.begin(); it != companion_list.end(); ++it) {
        if (it->second->CheckAggro(mob)) {
            if (!settoone) {
                it->second->RemoveFromHateList(mob);
            } else {
                it->second->SetHateAmountOnEnt(mob, 1);
            }
        }
    }
}
```

Note: Companions don't have rampage lists and `mob->IsClient()` XTarget cleanup
is not needed for companions (companions don't track xtarget like clients do
vs. NPCs), so the companion loop is intentionally simpler.

---

## Secondary Observation: `RemoveNPC` called on Companion Death

At `eqemu/zone/entity.cpp:571`:
```cpp
} else if (mob->IsCompanion()) {
    entity_list.RemoveCompanion(id);
    entity_list.RemoveNPC(id);    // companion never added to npc_list
```
`RemoveNPC` silently fails on a key it doesn't have — not a crash, but
misleading. Low priority; document for cleanup.
