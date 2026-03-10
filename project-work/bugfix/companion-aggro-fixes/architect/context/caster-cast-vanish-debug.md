# Companion Caster Casting + NPC Vanishing Debug Analysis

**Date:** 2026-03-09
**Author:** architect (systems)
**Status:** Complete

---

## Issue 1: Wizard and Cleric Companions NEVER Cast Spells

### Symptoms

- Melee companions (warrior, rogue) work perfectly — taunt, bash, backstab all functional
- Caster/healer companions (wizard, cleric) stand at range doing NOTHING
- NO gsay messages about casting ever appear (the gsay fires inside AIDoSpellCast,
  meaning AIDoSpellCast is never reached)
- The caster/healer correctly holds position at range (m_hold_combat_position works)

### Code Flow Trace

The engaged caster companion follows this path every AI tick:

```
1. Companion::Process() [companion.cpp:724]
   ↓
2. UpdateCombatPositioning() [companion.cpp:574]
   → m_hold_combat_position = true  (for COMBAT_ROLE_CASTER_DPS / COMBAT_ROLE_HEALER)
   ↓
3. NPC::Process() → AI_Process() [mob_ai.cpp]
   ↓
4. AI_Process() engaged branch [mob_ai.cpp:1154]
   → is_combat_range = CombatRange(target)
   ↓
5. NOT in combat range (caster is at ~70 units, melee range is ~15)
   → Falls to else branch [mob_ai.cpp:1341]
   ↓
6. HateSummon() returns false
   ↓
7. AI_PursueCastCheck() called [mob_ai.cpp:1353]
   → Companion::AI_PursueCastCheck() returns FALSE (override, companion.cpp:933)
   ↓
8. else if (m_hold_combat_position) [mob_ai.cpp:1360]
   → TRUE for casters — enters this branch
   ↓
9. AI_EngagedCastCheck() called [mob_ai.cpp:1364]
   → Companion::AI_EngagedCastCheck() (virtual override, companion.cpp:921)
   ↓
10. AICastSpell(GetChanceToCastBySpellType(0), 0xFFFFFFFF)
    [companion.cpp:924 → companion_ai.cpp:255]
```

So the flow reaches AICastSpell correctly. The question is what happens INSIDE.

### Root Cause: EMPTY companion_spell_sets Table

**Companion::AICastSpell() at companion_ai.cpp:255-260:**

```cpp
bool Companion::AICastSpell(int8 iChance, uint32 iSpellTypes)
{
    if (m_companion_spells.empty()) {
        // No companion spells loaded — fall back to base NPC AI
        return NPC::AI_EngagedCastCheck();  // <--- DEAD PATH
    }
    ...
}
```

**The fallback is a dead path because:**
- `NPC::AI_EngagedCastCheck()` at mob_ai.cpp:1905 first checks `AIautocastspell_timer->Check(false)`
- But `Companion::AI_Start()` at companion.cpp:499 **DISABLED** that timer:
  ```cpp
  if (AIautocastspell_timer) {
      AIautocastspell_timer->Disable();
  }
  ```
- A disabled timer always returns false from `Check()`
- So `NPC::AI_EngagedCastCheck()` returns false immediately
- **Result: companions with empty spell lists NEVER cast**

**The spell list is empty because:**

The `companion_spell_sets` table is populated by an INSERT...SELECT from `npc_spells_entries`:
```sql
-- database_update_manifest.h:7296
INSERT INTO companion_spell_sets (class_id, ...)
SELECT 2, minlevel, ... FROM npc_spells_entries WHERE npc_spells_id = 1 AND minlevel <= 65;
```

The source tables use `npc_spells_id` values 1-12. **These IDs were likely cleaned out of
`npc_spells_entries` when the bot spell system was migrated to `bot_spells_entries`** (manifest
version 9105, the 2017 bot migration). The INSERT...SELECT would have executed successfully but
inserted ZERO rows because the source had no matching data.

**Verification**: Run these queries to confirm:
```sql
SELECT COUNT(*) FROM companion_spell_sets;
-- Expected: 0 (if migration source was empty)

SELECT COUNT(*) FROM npc_spells_entries WHERE npc_spells_id IN (1,2,3,4,5,6,7,8,9,10,11,12);
-- Expected: 0 (data was moved to bot_spells_entries)

SELECT COUNT(*) FROM bot_spells_entries WHERE npc_spells_id IN (701,702,703,704,705,706,707,708,709,710,711,712);
-- Expected: many rows (this is where the spell data lives now)
```

### Complete Failure Chain

```
1. companion_spell_sets TABLE IS EMPTY
   ↓
2. LoadCompanionSpells() returns false, m_companion_spells stays empty
   (log message: "loaded [0] spells from companion_spell_sets")
   ↓
3. AI_EngagedCastCheck() → AICastSpell(50, 0xFFFFFFFF)
   ↓
4. AICastSpell() sees m_companion_spells.empty() == true
   ↓
5. Falls back to NPC::AI_EngagedCastCheck()
   ↓
6. NPC::AI_EngagedCastCheck() checks AIautocastspell_timer->Check(false)
   ↓
7. Timer is DISABLED (companion.cpp:499) → returns false
   ↓
8. NO SPELL IS EVER CAST. No gsay messages. Caster stands idle forever.
```

### Fix: Two-Part Approach

#### Fix A: Populate companion_spell_sets From Correct Source (Primary Fix)

The data needs to be populated from `bot_spells_entries` instead of the empty
`npc_spells_entries`. The bot spell system uses npc_spells_id values 701-712 for
the same class mapping:

| class_id | bot npc_spells_id | Class |
|----------|-------------------|-------|
| 2 | 701 | Cleric |
| 12 | 702 | Wizard |
| 11 | 703 | Necromancer |
| 13 | 704 | Magician |
| 14 | 705 | Enchanter |
| 10 | 706 | Shaman |
| 6 | 707 | Druid |
| 3 | 708 | Paladin |
| 5 | 709 | Shadow Knight |
| 4 | 710 | Ranger |
| 8 | 711 | Bard |
| 15 | 712 | Beastlord |

```sql
-- Clear and re-populate from bot_spells_entries
TRUNCATE TABLE companion_spell_sets;

INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
SELECT 2, minlevel, LEAST(maxlevel, 65), spellid, type, 0, priority, COALESCE(min_hp, 0), COALESCE(max_hp, 100)
FROM bot_spells_entries WHERE npc_spells_id = 701 AND minlevel <= 65;

-- ... repeat for all 12 classes
```

**NOTE:** The `bot_spells_entries` table column names may differ from `npc_spells_entries`.
Verify column names before executing. Key columns: `npc_spells_id`, `spellid`, `type`,
`minlevel`, `maxlevel`, `priority`, `min_hp`, `max_hp`.

#### Fix B: Fix the Dead Fallback Path (Defense-in-Depth)

Even if Fix A works, the fallback should not be a dead path. When `m_companion_spells` is
empty, the system should attempt the NPC's native spell list:

```cpp
// companion_ai.cpp:257
if (m_companion_spells.empty()) {
    // Re-enable the autocast timer for NPC fallback casting
    if (AIautocastspell_timer && !AIautocastspell_timer->Enabled()) {
        AIautocastspell_timer->Start(1000, false);
    }
    return NPC::AI_EngagedCastCheck();
}
```

This ensures that even if companion_spell_sets has no data, the companion can still use
whatever spells the NPC natively has from its `npc_spells_id` in `npc_types`.

#### Fix C: Increase Cast Chance (Optional Tuning)

The 50% chance gate per tick (BALANCED stance) is fine mathematically but can feel unresponsive.
Consider making it 100 for BALANCED/AGGRESSIVE and relying on spell recast timers for pacing:

```cpp
int8 Companion::GetChanceToCastBySpellType(uint32 spell_type)
{
    switch (m_current_stance) {
        case COMPANION_STANCE_PASSIVE:    return 30;
        case COMPANION_STANCE_BALANCED:   return 100;  // was 50
        case COMPANION_STANCE_AGGRESSIVE: return 100;  // was 80
        default:                          return 100;
    }
}
```

### Spell Range Check

Even after fixing the data, spell range must be verified. The caster stands at ~70 units
from the target (set by `RuleI(Companions, CasterCombatRange)`). The `AI_NukeTarget()` method
at companion_ai.cpp:549 checks:

```cpp
float dist2 = DistanceSquared(m_Position, target->GetPosition());
float range  = GetActSpellRange(nuke_spell, spells[nuke_spell].range);
if (dist2 > range * range) {
    return false;  // Out of range — won't cast
}
```

**Verification needed:** Check `spells_new.range` for typical wizard nukes and cleric heals:
```sql
SELECT id, name, range FROM spells_new WHERE id IN (
    -- Some wizard nukes
    SELECT spellid FROM bot_spells_entries WHERE npc_spells_id = 702 AND type = 1
) LIMIT 10;
```

Most EQ spells have range 200 (max casting distance). At 70 units the companion should be
comfortably in range. But some lower-level spells may have shorter ranges.

---

## Issue 2: NPCs Vanish From Client Screen After ~5 Seconds of Standing Still

### Symptoms

- Companion NPCs disappear from the Titanium client's rendering after ~5 seconds of
  standing completely still
- They reappear immediately when they start moving
- The server still has the entity — it's purely a client-side rendering optimization
- This is NOT a server despawn (the entity remains in entity_list)

### Root Cause: Titanium Client Idle Entity Culling

The Titanium client has a client-side optimization that stops rendering entities that
haven't sent a position update recently. This is a known behavior — the client assumes
NPCs that aren't moving don't need to be rendered, likely an LOD/culling optimization
from the original game where most NPCs were constantly patrolling.

Stationary companions never send position updates because:
1. They're not patrolling a grid (no waypoints)
2. They're holding position (m_hold_combat_position = true)
3. The movement manager has no reason to send position packets
4. After ~5 seconds of no position updates, the client culls them from rendering

### Bot System Already Solves This

The Bot system has an identical problem and solves it with a **keep-alive ping timer**:

```cpp
// bot.h:36
constexpr uint32 BOT_KEEP_ALIVE_INTERVAL = 5000; // 5 seconds

// bot.h:1161
Timer m_ping_timer;

// bot.cpp:1737-1748 (inside Bot::Process())
if (IsMoving()) {
    m_ping_timer.Disable();
}
else {
    if (!m_ping_timer.Enabled()) {
        m_ping_timer.Start(BOT_KEEP_ALIVE_INTERVAL);
    }
    if (m_ping_timer.Check()) {
        SentPositionPacket(0.0f, 0.0f, 0.0f, 0.0f, 0);
    }
}
```

**How it works:**
- When the bot is NOT moving, it starts a 5-second timer
- Every 5 seconds, it sends a position packet with zero deltas
- This packet tells the client "I'm still here at these coordinates"
- The client keeps rendering the entity
- When the bot IS moving, the timer is disabled (movement already sends updates)

### Fix: Add Keep-Alive Timer to Companion

Add the same m_ping_timer mechanism from Bot to Companion:

**companion.h changes:**
```cpp
// Add near the other timers in the protected section
Timer m_ping_timer;
```

**companion.cpp constructor changes:**
```cpp
// In the constructor initializer list, add:
m_ping_timer(1)

// In the constructor body:
m_ping_timer.Disable();
```

**companion.cpp Process() changes:**
```cpp
// Add BEFORE the NPC::Process() call, after UpdateCombatPositioning():

// Keep-alive position packet: prevents Titanium client from culling
// stationary companions. Same pattern as Bot::Process() (bot.cpp:1737).
if (IsMoving()) {
    m_ping_timer.Disable();
} else {
    if (!m_ping_timer.Enabled()) {
        m_ping_timer.Start(5000); // 5 second interval, matches BOT_KEEP_ALIVE_INTERVAL
    }
    if (m_ping_timer.Check()) {
        SentPositionPacket(0.0f, 0.0f, 0.0f, 0.0f, 0);
    }
}
```

**Key implementation details:**
- `SentPositionPacket()` is a method on `Mob` (mob.cpp:1714), inherited by Companion
- It sends an `OP_ClientUpdate` packet with `PlayerPositionUpdateServer_Struct`
- Zero deltas (0.0f for dx, dy, dz, dh) mean "no movement, same position"
- The `0` animation parameter means "standing idle"
- Uses `entity_list.QueueClients()` to send to all nearby clients

### Alternative: NPC::SendPositionToClients()

There's also `NPC::SendPositionToClients()` at npc.cpp:3739 which could be used:
```cpp
void NPC::SendPositionToClients()
{
    static EQApplicationPacket p(OP_ClientUpdate, sizeof(PlayerPositionUpdateServer_Struct));
    auto *s = (PlayerPositionUpdateServer_Struct *)p.pBuffer;
    for (auto &c: entity_list.GetClientList()) {
        MakeSpawnUpdate(s);
        c.second->QueuePacket(&p, false);
    }
}
```

However, `SentPositionPacket()` is preferred because:
- It's what Bot uses (proven working solution)
- It sends zero deltas explicitly (confirming no movement)
- It uses `QueueClients()` which respects distance filtering

---

## Summary of Required Changes

### Issue 1 (Caster Not Casting) — Three fixes, all needed:

| Fix | Layer | Priority | Description |
|-----|-------|----------|-------------|
| A | SQL | Critical | Populate companion_spell_sets from bot_spells_entries |
| B | C++ | High | Fix the dead fallback path in AICastSpell |
| C | C++ | Low | Increase cast chance to 100% for non-passive stances |

### Issue 2 (NPC Vanishing) — One fix:

| Fix | Layer | Priority | Description |
|-----|-------|----------|-------------|
| D | C++ | Critical | Add m_ping_timer keep-alive to Companion, matching Bot pattern |

### Files to Modify

| File | Changes |
|------|---------|
| `eqemu/zone/companion.h` | Add `Timer m_ping_timer;` member |
| `eqemu/zone/companion.cpp` | Add m_ping_timer init + keep-alive logic in Process() |
| `eqemu/zone/companion_ai.cpp` | Fix dead fallback path in AICastSpell() |
| SQL (data fix) | Truncate and re-populate companion_spell_sets |
| Database migration | Update manifest to use bot_spells_entries as source |

### Verification Steps

1. **Verify empty table**: `SELECT COUNT(*) FROM companion_spell_sets;`
2. **Verify data source**: `SELECT COUNT(*) FROM npc_spells_entries WHERE npc_spells_id IN (1,2,3,4,5,6,7,8,9,10,11,12);`
3. **Verify bot data exists**: `SELECT COUNT(*) FROM bot_spells_entries WHERE npc_spells_id BETWEEN 701 AND 712;`
4. **After fix**: Recruit a wizard, enter combat → expect gsay about casting + visible spell effects
5. **After fix**: Recruit a cleric, enter combat → expect gsay about healing + visible heals
6. **After vanish fix**: Stand still with companion → companion stays visible for >10 seconds
