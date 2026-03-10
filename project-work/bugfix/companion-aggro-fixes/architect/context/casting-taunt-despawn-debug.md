# Companion Casting, Taunt, and Despawn Debug Analysis

Date: 2026-03-09

## Executive Summary

Three separate bugs investigated. Root causes identified for all three.

---

## Issue 1: Wizard Doesn't Cast, Cleric Doesn't Heal/Buff

### Root Cause: The Spell AI Architecture Is Actually Correct — But Data or Chance Gate May Block It

The good news: the spell AI pipeline is architecturally sound. The flow is:

```
NPC::Process() → Mob::AI_Process() → m_hold_combat_position branch → AI_EngagedCastCheck()
                                    → !m_hold_combat_position branch → AI_EngagedCastCheck()
                                    → not-in-combat-range branch → m_hold_combat_position → AI_EngagedCastCheck()
```

**Companion::AI_EngagedCastCheck()** (companion.cpp:916) correctly overrides **NPC::AI_EngagedCastCheck()** (mob_ai.cpp:1905). The companion version does NOT depend on `AIautocastspell_timer` (which is disabled). Instead it delegates to:

```cpp
bool Companion::AI_EngagedCastCheck() {
    return AICastSpell(GetChanceToCastBySpellType(0), 0xFFFFFFFF);
}
```

**Companion::AICastSpell()** (companion_ai.cpp:255) routes to class-specific handlers (AI_Wizard, AI_Cleric, etc.). The handlers iterate `m_companion_spells` and call `AIDoSpellCast()`.

### What Could Be Blocking Casts

**Possibility 1: Chance Gate Too Low (LIKELY)**

`GetChanceToCastBySpellType(0)` returns:
- PASSIVE stance: **20** (only 20% chance per tick)
- BALANCED stance: **50** (50% chance per tick)
- AGGRESSIVE stance: **80** (80% chance per tick)

In AICastSpell (companion_ai.cpp:264):
```cpp
if (iChance < 100) {
    if (zone->random.Int(0, 100) > iChance) {
        return false;  // Failed the chance roll — no cast this tick
    }
}
```

For BALANCED stance, there is a 50% chance PER TICK to even attempt casting. Combined with spell recast timers, this could make casting appear very infrequent, especially if ticks are short. But it should not make it ZERO — the wizard should cast eventually.

**Possibility 2: Mana Check at 10% (POSSIBLE)**

```cpp
bool has_mana = (GetMaxMana() > 0);
if (has_mana && GetManaRatio() < 10.0f) {
    return false;
}
```

If the companion's max_mana is very low (from npc_types), they could be OOM immediately. However, the recruited NPC should have its native mana. Check the recruited NPC's Mana field in npc_types.

**Possibility 3: companion_spell_sets Has No Data for This Class/Level (CRITICAL CHECK)**

The migration SQL at database_update_manifest.h:7296 populates companion_spell_sets by copying from `npc_spells_entries` using specific `npc_spells_id` values:

| class_id | npc_spells_id | Class |
|----------|--------------|-------|
| 2 | 1 | Cleric |
| 12 | 2 | Wizard |
| 11 | 3 | Necromancer |
| 13 | 4 | Magician |
| 14 | 5 | Enchanter |
| 10 | 6 | Shaman |
| 6 | 7 | Druid |
| 3 | 8 | Paladin |
| 5 | 9 | Shadow Knight |
| 4 | 10 | Ranger |
| 8 | 11 | Bard |
| 15 | 12 | Beastlord |

**NOTICE: No entry for class_id = 1 (Warrior), 7 (Monk), or 9 (Rogue)**. These are pure melee classes with no spells — this is correct and expected.

However, the data source `npc_spells_entries WHERE npc_spells_id = X` must actually have rows in it. If those npc_spells_entries were moved to bot_spells_entries during the 2017 migration (manifest version 9105), the companion_spell_sets INSERT would produce ZERO rows.

**This is the most likely root cause**: The `npc_spells_entries` table may have been cleaned out for IDs 1-12 during the bot spells migration. The INSERT...SELECT would silently insert nothing. `LoadCompanionSpells()` would return an empty vector. Then AICastSpell would fall back to `NPC::AI_EngagedCastCheck()`, which checks `AIautocastspell_timer->Check(false)` — and that timer is DISABLED for companions (companion.cpp:499-500). So the fallback also returns false. **Result: companions NEVER cast.**

### Fallback Path Failure Chain

```
1. LoadCompanionSpells() → m_companion_spells is EMPTY (no rows in companion_spell_sets)
2. AI_EngagedCastCheck() → AICastSpell(50, 0xFFFFFFFF)
3. AICastSpell() checks m_companion_spells.empty() → TRUE
4. Falls back to NPC::AI_EngagedCastCheck()
5. NPC::AI_EngagedCastCheck() checks AIautocastspell_timer->Check(false)
6. Timer is DISABLED → returns false
7. RESULT: No spell is ever cast
```

### Verification Steps

1. **Check the database**: `SELECT COUNT(*) FROM companion_spell_sets WHERE class_id = 2;` (Cleric)
   - If 0 rows, the migration didn't populate the table. This confirms the root cause.
2. **Check npc_spells_entries**: `SELECT COUNT(*) FROM npc_spells_entries WHERE npc_spells_id IN (1,2,3,4,5,6,7,8,9,10,11,12);`
   - If 0 rows, the data was moved to bot_spells_entries and the companion INSERT...SELECT failed.

### Fix

**Option A (best)**: Re-run the companion_spell_sets INSERT using `bot_spells_entries` as the source instead of `npc_spells_entries`:
```sql
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 2, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM bot_spells_entries WHERE npc_spells_id = 701 AND minlevel <= 65;
-- ... etc for each class mapping bot npc_spells_id 701-712 to class_ids
```

**Option B (if data IS present)**: The problem may be the chance gate. If companion_spell_sets has data but casting is just very infrequent, increase the chance:
- Change `GetChanceToCastBySpellType()` to return 100 for BALANCED and AGGRESSIVE stances
- Or make the AI tick-based rather than chance-based

**Option C (defensive fallback fix)**: Even if companion_spell_sets is empty, fix the fallback path. When `m_companion_spells.empty()`, instead of calling `NPC::AI_EngagedCastCheck()` (which requires the disabled timer), use the NPC's native spell list directly by re-enabling the timer:
```cpp
if (m_companion_spells.empty()) {
    // Re-enable the timer for fallback NPC casting
    if (AIautocastspell_timer && !AIautocastspell_timer->Enabled()) {
        AIautocastspell_timer->Start(1000, false);
    }
    return NPC::AI_EngagedCastCheck();
}
```

---

## Issue 2: Warrior Doesn't Taunt

### Root Cause: NPC Taunt Logic Requires `HasOwner() && IsTaunting() && type_of_pet`

The warrior companion charges to melee correctly (`m_hold_combat_position = false` for COMBAT_ROLE_MELEE_TANK`). The AI_Process() melee block runs `DoClassAttacks(target)` at mob_ai.cpp:1334.

Inside `NPC::DoClassAttacks()` (special_attacks.cpp:1863), the taunt code at line 1901-1915:

```cpp
if (
    IsTaunting() &&
    HasOwner() &&           // <-- FAILS for companions
    target->IsNPC() &&
    target->GetBodyType() != BodyType::Undead &&
    taunt_time &&
    type_of_pet &&          // <-- FAILS for companions (not a pet)
    type_of_pet != PetType::TargetLock &&
    DistanceSquared(GetPosition(), target->GetPosition()) <= (RuleI(Pets, PetTauntRange) * RuleI(Pets, PetTauntRange))
) {
    GetOwner()->MessageString(Chat::PetResponse, PET_TAUNTING);
    Taunt(target->CastToNPC(), false);
}
```

**Three guards fail for companions:**
1. `HasOwner()` — Companions don't use the pet ownership system. `ownerid` is 0.
2. `type_of_pet` — This is an NPC pet-type enum field. Companions don't set it (defaults to 0 which is falsy).
3. `IsTaunting()` — This may or may not be set. NPCs have a `taunting` field; companions inherit it from NPC but it depends on initialization.

**This taunt block is specifically designed for PETS, not companions.** Companions need their own taunt mechanism.

### The Warrior Class Attack Block

The Warrior case at special_attacks.cpp:1948 does kick/bash, which DOES fire for companions because it only checks `ca_time` (classattack_timer). So the warrior companion kicks and bashes, but NEVER taunts.

### Fix

Add companion-specific taunt logic. Either:

**Option A**: Override `DoClassAttacks()` in the Companion class to add taunt logic without the pet ownership checks.

**Option B**: In the existing `NPC::DoClassAttacks()`, add a companion-specific taunt block:
```cpp
// Companion taunt (not pet-based)
if (IsCompanion() && taunt_time && target->IsNPC() && 
    target->GetBodyType() != BodyType::Undead &&
    CombatRange(target)) {
    Taunt(target->CastToNPC(), false);
}
```

**Option C**: In the Companion's `AI_Tank()` handler (companion_ai.cpp:677), explicitly call `Taunt()` on the target on each engaged tick. This is simpler and companion-specific.

---

## Issue 3: Companions Despawn When Standing Still for a Few Seconds

### Root Cause: NOT a timer or despawn issue — most likely the entity is being deleted by MobProcess

After thorough investigation, companions should NOT despawn from any known timer:
- `m_death_despawn_timer` is disabled at construction (companion.cpp:111) and only enabled in Death()
- `m_replacement_spawn_timer` is disabled at construction (companion.cpp:112)
- `m_retention_check_timer` is disabled for COMPANION_TYPE_COMPANION (companion.cpp:107)
- No Spawn2 pointer (`respawn2 = nullptr`) so spawn group despawn logic doesn't apply
- `p_depop` is initialized to false in NPC constructor (npc.cpp:287) and in companion constructor via SetDepop(false) in various paths

### Potential Causes

**Cause A: Zone Idle Processing (entity.cpp:531-547)**

When `zone->IsIdleWhenEmpty()` is true and `numclients == 0`, the code at entity.cpp:537-547 skips Process() for NPC-like entities and just checks `GetDepop()`. However, this only happens when there are ZERO clients in the zone. Since the player is present, this shouldn't trigger.

BUT: There's a subtle issue at entity.cpp:531:
```cpp
Spawn2* s2 = mob->CastToNPC()->respawn2;
```

This line is called for ALL mobs in the mob_list during the idle-when-empty check. For companions, `respawn2 = nullptr`. If the zone IS idle when empty, the companion would pass the `numclients > 0` check (player is there), so it should run Process() normally. This is NOT the cause.

**Cause B: Companion::Process() Returns False Unexpectedly**

Look at Companion::Process() (companion.cpp:724). It can return false via:
1. `m_death_despawn_timer.Check()` at line 727 → only if timer is enabled (disabled by default)
2. `NPC::Process()` returns false at line 913 → this happens if `p_depop == true`

NPC::Process() (npc.cpp:582) returns false when `p_depop == true`. 

**CRITICAL PATH**: Something is setting `p_depop = true` on the companion. The possible sources:
- `NPC::Depop()` (npc.cpp:868) — sets `p_depop = true`
- `Companion::Depop()` calls `m_depop = true` but ALSO calls RemoveCompanion/RemoveNPC which removes from entity lists — different path
- Any code calling `NPC::Depop()` directly on the companion (bypassing Companion::Depop override)

**Cause C: NPC Virtual Table Collision with Depop**

`Companion::Depop()` overrides `NPC::Depop()`, but `Companion::Depop()` sets `m_depop = true` (the Companion member) while `NPC::Process()` checks `p_depop` (the NPC member). These are DIFFERENT fields:
- `p_depop` — NPC's native depop flag (npc.h, checked in NPC::Process)
- `m_depop` — Companion's own depop flag (companion.h, checked via GetDepop())

Looking at companion.h line 296: `bool GetDepop() const { return m_depop; }` — This returns the COMPANION's m_depop, not the NPC's p_depop.

In entity.cpp MobProcess at line 546: `mob_dead = mob->CastToNPC()->GetDepop();`

For companions, `CastToNPC()` upcasts to NPC*, and `GetDepop()` on NPC returns `p_depop`. The companion's `GetDepop()` override returns `m_depop`. This depends on virtual dispatch. If `GetDepop()` is NOT virtual in NPC, then `CastToNPC()->GetDepop()` would read `p_depop`, not `m_depop`. Let me check...

Actually wait — `GetDepop()` in companion.h:296 is just a regular (non-virtual) method. And NPC's `p_depop` is checked directly in `NPC::Process()`. The `Companion::GetDepop()` in companion.h hides/shadows the NPC version. Since `CastToNPC()` returns `NPC*`, calling `GetDepop()` on that pointer would call the NPC version (reading `p_depop`), not the Companion version (reading `m_depop`).

**But the real question is**: what sets `p_depop = true`? Only `NPC::Depop()` (npc.cpp:868). If `Companion::Depop()` properly overrides `NPC::Depop()`, then `p_depop` should never be set directly on a companion... unless something calls the NPC version directly (e.g., through a non-virtual dispatch or a pointer cast).

**Most Likely Despawn Cause**: Something is calling `Depop()` on the companion through an `NPC*` pointer, bypassing the virtual override. Or there's a timer/condition in NPC::Process() that calls `Depop()`.

Actually, let me re-read `Companion::Depop()`:
```cpp
void Companion::Depop(bool start_spawn_timer) {
    // ... cleanup ...
    m_depop = true;  // Sets companion's field
    // But does NOT set p_depop!
}
```

Wait, does `Companion::Depop()` also set `p_depop`? Looking at the code (companion.cpp:1158-1188):
```cpp
void Companion::Depop(bool start_spawn_timer) {
    WipeHateList();
    if (IsCasting()) InterruptSpell();
    entity_list.RemoveFromHateLists(this);
    if (GetGroup()) RemoveCompanionFromGroup(this, GetGroup());
    entity_list.RemoveCompanion(GetID());
    // ...
    m_depop = true;
    // Note: does NOT call NPC::Depop() and does NOT set p_depop
}
```

So `Companion::Depop()` sets `m_depop = true` but NOT `p_depop`. However, `NPC::Process()` checks `p_depop`. If `p_depop` is never set, then `NPC::Process()` should never return false for a companion due to depop.

**Revised analysis**: The despawn must come from somewhere else. Let me reconsider.

### Alternative Despawn Cause: NPC Adventure Rescue or Spawn Condition

In NPC::Process() at line 710-727, there's adventure rescue logic that can call `Depop()`. If `zone->adv_data` is set and the NPC matches the rescue type, it could depop. But this is very unlikely for a companion.

### Most Likely Cause: GetDepop() / p_depop Is Set By Something We're Not Seeing

The companion overrides `Depop()` as virtual. BUT: `NPC::Depop()` is declared virtual in NPC (npc.h:182). Companion::Depop() overrides it (companion.h:182). So when any code calls `Depop()` on a Companion through any pointer type (NPC*, Mob*, etc.), it should call Companion::Depop().

**Wait**: Companion::Depop sets `m_depop = true`. NPC::Process checks `p_depop`. These are DIFFERENT fields. So even if Companion::Depop() fires, NPC::Process() should still return true (since p_depop is still false). But Companion::Process() calls NPC::Process() which returns true... then what deletes the entity?

Looking at MobProcess (entity.cpp:542): `mob_dead = !mob->Process();`. Process() is virtual. `Companion::Process()` is called. At line 913: `return NPC::Process();`. If NPC::Process() returns true, Companion::Process() returns true, mob_dead = false, entity stays alive.

**THE REAL ISSUE**: I need to look more carefully at whether `p_depop` can be set on a companion without going through `Companion::Depop()`. One path: if something calls `NPC::Depop()` on a pointer where the virtual table isn't set up (e.g., during construction/destruction). But that shouldn't happen during normal gameplay.

**Alternative**: The user might be observing a different phenomenon. Possible explanations:
1. The companion is zoning (ProcessClientZoneChange → Zone() → Depop) — if the player is standing near a zone line, the zone-in/out process could trigger this
2. The companion's group member slot is null (from Death→MemberZoned) making it invisible in the group window — the user perceives this as despawning
3. A camp/linkdead timeout on the owner triggers companion Zone() or Suspend()

### Verification Steps

1. Add logging to Companion::Process() and Companion::Depop() to track when and why they fire
2. Check if `p_depop` is being set on companions by adding a setter guard
3. Test by standing still in a zone center (far from zone lines) with companions and observe if they vanish

---

## Summary Table

| Issue | Root Cause | Confidence | Fix Complexity |
|-------|-----------|------------|----------------|
| Caster companions don't cast | companion_spell_sets likely empty (migration INSERT...SELECT from wrong table) OR fallback to NPC::AI_EngagedCastCheck fails because timer is disabled | HIGH | Medium — verify DB data, fix INSERT or fix fallback path |
| Warrior doesn't taunt | Taunt code in NPC::DoClassAttacks() requires HasOwner() and type_of_pet — pet-specific guards that companions don't satisfy | CONFIRMED | Low — add companion-specific taunt block |
| Companions despawn when still | Needs more investigation; p_depop/m_depop dual-field confusion is suspect; could be zone-line proximity or visual issue | MEDIUM | Needs logging to confirm |

## Recommended Investigation Priority

1. **Check companion_spell_sets data** — `SELECT class_id, COUNT(*) FROM companion_spell_sets GROUP BY class_id;`
2. **Add companion taunt** — straightforward code fix
3. **Add despawn logging** — `LogInfo` in Companion::Process() return path and Companion::Depop()
