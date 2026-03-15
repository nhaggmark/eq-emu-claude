# Companion Resurrection System — Architecture & Implementation Plan

> **Feature branch:** `feature/companion-resurrection`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-03-15
> **Status:** Draft

---

## Executive Summary

This feature adds autonomous resurrection capability to healer companions (Cleric, Paladin, Necromancer). After combat ends, surviving healer companions detect dead group member corpses within range and cast era-appropriate resurrection spells. Companion corpses auto-accept the rez and respawn at the corpse location with reduced HP/mana. Player corpses use the standard EQ rez consent dialog. The implementation requires: (1) extending the `SpellEffect::Revive` handler to support companion NPC corpses, (2) implementing the rez AI logic in `companion_ai.cpp` (replacing the existing stub), (3) adding companion XP death penalty, (4) stripping loot from companion corpses, (5) adding rez spells to `companion_spell_sets`, and (6) implementing deity-themed rez dialogue. Five new rules control all tunable values.

## Existing System Analysis

### Current State

**Companion Death Flow** (`companion.cpp:571-678`):
1. `Companion::Death()` calls `NPC::Death()` which creates a standard NPC corpse at `attack.cpp:2887` (via `new Corpse(this, &m_loot_items, ...)`)
2. `SetDepop(false)` keeps the companion entity alive post-death for the despawn window
3. `m_death_despawn_timer` starts (30 min, from `Companions:DeathDespawnS`)
4. Companion is marked `is_suspended=1` in `companion_data` table
5. Group slot is NULLed via `MemberZoned()` — dead companion stays conceptually in group
6. Owner gets message: "You have X seconds to resurrect them, or they will return home."
7. When timer fires (`companion.cpp:1774`), companion is marked dismissed and entity returns false from `Process()`

**Companion Corpse (Problem):** The NPC corpse created at `attack.cpp:2887` passes `&m_loot_items` — the companion's NPC loot table items. Companion corpses should have NO loot.

**Rez Spell Effect** (`spell_effects.cpp:1707-1720`):
- `SpellEffect::Revive` (effect ID 81) only processes `IsPlayerCorpse()` — NPC corpses are silently ignored
- `Corpse::CastRezz()` (`corpse.cpp:2290-2359`) sends `OP_RezzRequest` via world server for player consent
- This flow is designed for player corpses only

**Companion Spell AI — Rez Stub** (`companion_ai.cpp:1136-1142`):
- `AI_Cleric()` idle path has a `SpellType_Resurrect` block that finds a rez spell via `SelectFirstSpell()` but does nothing with it
- Comment: "Rezzing is done via the quest system; placeholder for future extension. For now skip automatic corpse rezzing (needs corpse targeting logic)"
- Paladin and Necromancer AI handlers have NO rez stub at all

**AI_IdleCastCheck** (`companion.cpp:2114-2118`):
- Currently passes `SpellType_Buff | SpellType_Heal | SpellType_Pet` — does NOT include `SpellType_Resurrect`
- Even if the Cleric AI stub worked, idle cast checks would never pass the Resurrect type

**Merc Rez Pattern** (reference implementation, `merc.cpp:2003-2018, 3719-3738`):
- `Merc::GetGroupMemberCorpse()` iterates group members, finds player corpses within range via `entity_list.GetCorpseByOwnerWithinRange()`
- Only searches for player corpses (via `IsPlayerCorpse()` check in `GetCorpseByOwnerWithinRange`)
- Casts rez on corpse via `AIDoSpellCast()` with `DontRootMeBefore` timer to prevent spam

**SpellType_Resurrect:** Defined as `(1 << 16)` in `common/spdat.h:648`. Already used in `companion_spell_sets` spell type field — ready for data population.

**Companion XP System:** `m_companion_xp` exists in `companion.h`, `AddExperience()` and `CheckForLevelUp()` are implemented. Death does NOT currently deduct XP.

**Deity Field:** `Mob::GetDeity()` returns `deity` (uint16) from the NPC's data. Available at runtime on all companions.

### Gap Analysis

| # | Gap | Current State | Required State |
|---|-----|--------------|----------------|
| 1 | Companion corpses have loot | `NPC::Death()` passes `&m_loot_items` to Corpse constructor | Loot must be cleared before/after corpse creation for companions |
| 2 | Rez spell effect ignores NPC corpses | `SpellEffect::Revive` only checks `IsPlayerCorpse()` | Must also handle companion NPC corpses |
| 3 | No companion corpse identification on Corpse object | Corpse has no `m_companion_id` or `m_owner_char_id` field | Need to store companion metadata on the corpse for rez targeting and restoration |
| 4 | Rez AI is a stub | Cleric has placeholder, PAL/NEC have nothing | Full rez AI: corpse scanning, priority, mana management, meditation, dialogue |
| 5 | AI_IdleCastCheck excludes SpellType_Resurrect | Only passes Buff/Heal/Pet | Must include SpellType_Resurrect |
| 6 | No XP death penalty | Death doesn't deduct XP | Must deduct configurable % of level XP on death |
| 7 | No rez spell data in companion_spell_sets | Table exists but has no SpellType_Resurrect entries | Must populate CLR/PAL/NEC rez spells |
| 8 | No corpse-finding for companion corpses | `GetCorpseByOwnerWithinRange()` only finds player corpses | Need new method to find companion corpses by owner within range |
| 9 | No companion respawn from corpse | Only `Unsuspend()` exists (full HP/mana) | Need rez-specific respawn: low HP, 0 mana, no buffs, at corpse position |
| 10 | No deity dialogue system | No rez dialogue infrastructure | Need deity→dialogue mapping and group say integration |
| 11 | No post-combat rez delay | No settling timer concept | Need configurable delay after combat before rez attempts |

## Technical Approach

### Architecture Decision

This feature is primarily a **C++ engine change** because the core rez mechanic (spell effect handling, corpse management, AI spell casting, entity lifecycle) lives entirely in the C++ zone server. The tunable values go into **rule values**. Rez spell data goes into the existing **SQL table** `companion_spell_sets`. Rez dialogue goes into a **Lua module** to keep strings data-driven and editable without recompilation.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| Rule values (`ruletypes.h`) | New rules | 5 new tunable values — least invasive for all configuration |
| `companion_spell_sets` (SQL) | New data rows | Rez spells for CLR/PAL/NEC — uses existing table, no schema change |
| `corpse.h/cpp` | Extend Corpse class | Add companion metadata fields for rez targeting |
| `spell_effects.cpp` | Extend Revive handler | Add companion corpse path alongside player corpse path |
| `companion.h/cpp` | New methods | Rez-from-corpse lifecycle, XP death penalty, loot stripping |
| `companion_ai.cpp` | Implement rez AI | Replace stub with full corpse targeting, priority, mana management |
| `entity.h/cpp` | New corpse-finding method | Find companion corpses by owner char ID within range |
| Lua module (`rez_dialogue.lua`) | New module | Deity→dialogue mapping table, called from C++ via quest event or direct |

### Data Model

No new database tables are needed. Changes to existing tables:

**`companion_spell_sets`** — New rows only (no schema change):
```sql
-- Cleric rez spells (class_id=2)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct) VALUES
(2, 12, 28, <Reanimation_ID>, 65536, 0, 1, 0, 0),  -- SpellType_Resurrect = 65536 = 1<<16
(2, 29, 38, 391, 65536, 0, 1, 0, 0),               -- Revive
(2, 39, 48, <Resuscitate_ID>, 65536, 0, 1, 0, 0),  -- Resuscitate
(2, 49, 55, 392, 65536, 0, 1, 0, 0),               -- Resurrection
(2, 56, 65, 1524, 65536, 0, 1, 0, 0);              -- Reviviscence
-- Paladin rez spells (class_id=3)
-- Necromancer Convergence (class_id=11)
```

**Note:** Spell IDs for Reanimation and Resuscitate must be queried from `spells_new` by the data-expert. The architect has confirmed the spell effect type is `SpellEffect::Revive` (81) which is the `base_value` lookup key for XP restoration percentage.

**`rule_values`** — 5 new entries:
```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value) VALUES
(1, 'Companions:RezEnabled', 'true'),
(1, 'Companions:RezPostCombatDelayS', '10'),
(1, 'Companions:RezRange', '200'),
(1, 'Companions:XPDeathPenaltyPct', '10'),
(1, 'Companions:RezWaiveReagents', 'true');
```

### Code Changes

#### C++ Changes

**1. `common/ruletypes.h`** — Add 5 new rules to `RULE_CATEGORY(Companions)`:
```cpp
RULE_BOOL(Companions, RezEnabled, true, "Master toggle for companion autonomous resurrection")
RULE_INT(Companions, RezPostCombatDelayS, 10, "Seconds after combat ends before healer attempts rez")
RULE_INT(Companions, RezRange, 200, "Maximum distance in units to target a corpse for rez")
RULE_INT(Companions, XPDeathPenaltyPct, 10, "Percentage of current level XP lost on companion death")
RULE_BOOL(Companions, RezWaiveReagents, true, "Waive spell reagent requirements for companion rez casters")
```

**2. `zone/corpse.h`** — Add companion metadata to Corpse class:
```cpp
// In private section:
uint32 m_companion_id;        // 0 = not a companion corpse
uint32 m_companion_owner_id;  // owner char ID for companion corpses

// In public section:
bool IsCompanionCorpse() const { return m_companion_id > 0; }
uint32 GetCompanionID() const { return m_companion_id; }
uint32 GetCompanionOwnerID() const { return m_companion_owner_id; }
void SetCompanionData(uint32 companion_id, uint32 owner_id);
```

**3. `zone/corpse.cpp`** — Initialize companion fields in NPC Corpse constructor, add `SetCompanionData()`:
```cpp
// In Corpse::Corpse(NPC*, LootItems*, ...) constructor initialization:
m_companion_id = 0;
m_companion_owner_id = 0;

void Corpse::SetCompanionData(uint32 companion_id, uint32 owner_id) {
    m_companion_id = companion_id;
    m_companion_owner_id = owner_id;
}
```

**4. `zone/spell_effects.cpp`** — Extend `SpellEffect::Revive` handler at line 1712:
```cpp
case SpellEffect::Revive:
{
    if (IsCorpse()) {
        if (CastToCorpse()->IsPlayerCorpse()) {
            // Existing player corpse rez path
            if (caster) LogSpells("corpse being rezzed using spell [{}] by [{}]", spell_id, caster->GetName());
            CastToCorpse()->CastRezz(spell_id, caster);
        }
        else if (CastToCorpse()->IsCompanionCorpse()) {
            // NEW: Companion corpse rez path — auto-accept, no consent dialog
            if (caster) LogSpells("companion corpse being rezzed using spell [{}] by [{}]", spell_id, caster->GetName());
            // Delegate to Companion static method that handles respawn
            Companion::ResurrectFromCorpse(CastToCorpse(), spell_id, caster);
        }
    }
    break;
}
```

**5. `zone/companion.h`** — Add new methods and members:
```cpp
// New public methods:
static void ResurrectFromCorpse(Corpse* corpse, uint16 spell_id, Mob* caster);
void ApplyDeathXPPenalty();
uint32 GetXPForCurrentLevel() const;

// New rez AI methods:
bool AI_ResurrectDeadGroupMember();
Corpse* FindDeadGroupMemberCorpse();
int GetRezPriority(Corpse* corpse);

// New protected members:
Timer m_rez_delay_timer;  // post-combat settling before rez attempts
bool m_rez_meditation_announced;
```

**6. `zone/companion.cpp`** — Major changes:

a) **Death() method** — Add XP death penalty, strip loot from corpse:
```cpp
// After NPC::Death() creates the corpse, find it and strip loot + set companion data
// Add before the owner notification block:
ApplyDeathXPPenalty();
// After corpse creation, find the corpse entity and configure it
Corpse* companion_corpse = entity_list.GetCorpseByNPCTypeIDAndPosition(GetNPCTypeID(), GetPosition());
if (companion_corpse) {
    companion_corpse->SetCompanionData(m_companion_id, m_owner_char_id);
    // Strip NPC loot — companion corpses have no loot
    companion_corpse->RemoveAllLoot(); // or clear m_item_list
}
```

b) **ApplyDeathXPPenalty()** — Deduct configurable XP on death:
```cpp
void Companion::ApplyDeathXPPenalty() {
    int penalty_pct = RuleI(Companions, XPDeathPenaltyPct);
    if (penalty_pct <= 0) return;
    uint32 level_xp = GetXPForCurrentLevel();
    uint32 xp_loss = (level_xp * penalty_pct) / 100;
    // Floor at 0 — can't go negative
    if (m_companion_xp >= xp_loss) {
        m_companion_xp -= xp_loss;
    } else {
        m_companion_xp = 0;
    }
    // Store the loss amount for rez restoration later (on the corpse or via member var)
}
```

c) **ResurrectFromCorpse()** — Static method for companion rez:
```cpp
static void Companion::ResurrectFromCorpse(Corpse* corpse, uint16 spell_id, Mob* caster) {
    // 1. Look up companion_data by corpse->GetCompanionID()
    // 2. Calculate XP restoration from spell's base_value (rez %)
    // 3. Create new Companion entity at corpse position
    // 4. Set HP to ~10-20% of max, mana to 0, no buffs
    // 5. Add XP restoration
    // 6. Add to entity list and group
    // 7. Delete the corpse entity
    // 8. Send group message: "[Dead] has been resurrected/raised by [Caster]."
}
```

d) **AI_IdleCastCheck()** — Add SpellType_Resurrect:
```cpp
bool Companion::AI_IdleCastCheck() {
    return AICastSpell(GetChanceToCastBySpellType(0),
        SpellType_Buff | SpellType_Heal | SpellType_Pet | SpellType_Resurrect);
}
```

e) **Process()** — Add rez delay timer management:
```cpp
// In the idle section of Process(), after combat ends:
// Start rez delay timer when transitioning from engaged to idle
if (m_rez_delay_timer.Enabled() && m_rez_delay_timer.Check()) {
    m_rez_delay_timer.Disable();
    // Rez delay expired — normal idle cast will now include SpellType_Resurrect
}
```

**7. `zone/companion_ai.cpp`** — Implement full rez AI:

a) Replace the `AI_Cleric()` rez stub (lines 1136-1142) with:
```cpp
if (iSpellTypes & SpellType_Resurrect) {
    if (AI_ResurrectDeadGroupMember()) {
        return true;
    }
}
```

b) Add same block to `AI_Paladin()` idle path (after heal, before buff)

c) Add same block to `AI_Necromancer()` idle path (after buff)

d) Implement `AI_ResurrectDeadGroupMember()`:
```cpp
bool Companion::AI_ResurrectDeadGroupMember() {
    if (!RuleB(Companions, RezEnabled)) return false;
    if (m_rez_delay_timer.Enabled()) return false;  // still in post-combat cooldown
    
    Corpse* target = FindDeadGroupMemberCorpse();
    if (!target) return false;
    
    // Select best rez spell we can afford
    uint32 now_ms = Timer::GetCurrentTime();
    uint16 rez_spell = SelectBestRezSpell(m_companion_spells, m_current_stance, now_ms, GetMana());
    
    if (!rez_spell) {
        // No rez spell affordable — meditate
        if (!m_rez_meditation_announced) {
            CompanionGroupSay(this, "I must gather my strength before I can call anyone back.");
            m_rez_meditation_announced = true;
            Sit(); // Begin meditation
        }
        return false;
    }
    
    // Stand up if meditating
    if (IsSitting()) Stand();
    m_rez_meditation_announced = false;
    
    // Deity dialogue before cast
    std::string cast_line = GetRezCastDialogue();
    if (!cast_line.empty()) {
        CompanionGroupSay(this, cast_line.c_str());
    }
    
    // Cast rez on corpse
    bool cast_ok = AIDoSpellCast(rez_spell, target, spells[rez_spell].mana);
    if (cast_ok) {
        SetSpellTimeCanCast(rez_spell, spells[rez_spell].recast_time);
    }
    return cast_ok;
}
```

e) Implement `FindDeadGroupMemberCorpse()` — scans for corpses by priority:
```cpp
Corpse* Companion::FindDeadGroupMemberCorpse() {
    int rez_range = RuleI(Companions, RezRange);
    Client* owner = GetCompanionOwner();
    if (!owner) return nullptr;
    
    // Build prioritized list of rez targets
    // Priority 1: Player corpse
    // Priority 2: Rez-capable companion corpses (CLR > PAL > NEC)
    // Priority 3: Other healer companion corpses (DRU, SHM)
    // Priority 4: Tank companion corpses
    // Priority 5: DPS companion corpses
    
    // Scan corpse_list for matching corpses within range
    // For player: check entity_list.GetCorpseByOwnerWithinRange()
    // For companions: check IsCompanionCorpse() && GetCompanionOwnerID() == owner->CharacterID()
    // Return highest priority, closest corpse
}
```

f) Implement `SelectBestRezSpell()` — finds highest-level rez spell affordable:
```cpp
static uint16 SelectBestRezSpell(const std::vector<CompanionSpell>& spells,
    uint8 stance, uint32 now_ms, int64 current_mana) {
    // Iterate spells in reverse slot order (highest level first)
    // Find the best SpellType_Resurrect spell that:
    //   - passes stance check
    //   - is off recast cooldown
    //   - caster has enough mana for
    // If best is unaffordable, fall back to lower-tier rez
    // Returns 0 if nothing affordable
}
```

**8. `zone/entity.h/cpp`** — Add companion corpse finder:
```cpp
// entity.h:
Corpse* GetCompanionCorpseByOwnerWithinRange(uint32 owner_char_id, Mob* center, int range);

// entity.cpp:
Corpse* EntityList::GetCompanionCorpseByOwnerWithinRange(uint32 owner_char_id, Mob* center, int range) {
    // Iterate corpse_list
    // Check IsCompanionCorpse() && GetCompanionOwnerID() == owner_char_id
    // Check DistanceSquaredNoZ < range*range
    // Check !IsRezzed()
    // Return first match (caller handles priority)
}
```

**9. `zone/attack.cpp`** — Strip loot from companion corpses after creation at line ~2897:
```cpp
// After: corpse = new Corpse(this, &m_loot_items, ...);
// Add:
if (IsCompanion()) {
    corpse->RemoveAllLoot();  // Companion corpses have no loot
    corpse->SetCompanionData(
        CastToCompanion()->GetCompanionID(),
        CastToCompanion()->GetOwnerCharacterID()
    );
}
```

This is the cleanest approach — modify the corpse right after creation in `attack.cpp` rather than in `Companion::Death()`, since the corpse entity reference is directly available.

#### Lua/Script Changes

**`akk-stack/server/quests/lua_modules/rez_dialogue.lua`** — New module for deity-themed dialogue:
```lua
-- Maps deity ID → {cast_line, completion_line}
-- Also maps class_id → fallback lines for companions with deity=0
local RezDialogue = {}

RezDialogue.deity_lines = {
    [201] = { -- Rodcet Nife
        cast = "By the Prime Healer's grace, I call your soul back.",
        complete = "%s has been resurrected by %s.",
    },
    [203] = { -- Tunare
        cast = "The Mother of All calls you back from the threshold.",
        complete = "%s has been resurrected by %s.",
    },
    -- ... (all deities from PRD)
}

RezDialogue.class_fallback = {
    [2] = { -- Cleric
        cast = "I call upon the powers that bind us. Return to the living.",
        complete = "%s has been resurrected by %s.",
    },
    [3] = { -- Paladin
        cast = "I call upon the powers that bind us. Return to the living.",
        complete = "%s has been resurrected by %s.",
    },
    [11] = { -- Necromancer
        cast = "The death-energy lingers... I will bind your soul to it.",
        complete = "%s has been raised by %s.",  -- "raised" not "resurrected"
    },
}

return RezDialogue
```

However, since the rez AI runs in C++ and calling Lua mid-AI-tick adds complexity, the **recommended approach** is to implement the dialogue table as a simple C++ lookup (a `std::unordered_map<uint16, std::pair<std::string, std::string>>`) in `companion_ai.cpp`. This avoids the Lua→C++ bridging overhead and keeps the rez AI self-contained. The dialogue strings are short and few — hardcoding them in C++ is acceptable given there are only ~10 deity entries plus 3 class fallbacks.

If the user later wants the dialogue to be editable without recompilation, a future enhancement can move the table to a Lua module or database table.

#### Database Changes

**SQL file: `companion_rez_spells.sql`** — To be executed by data-expert after verifying spell IDs from `spells_new`:

```sql
-- Companion Resurrection Spells
-- SpellType_Resurrect = 65536 (1 << 16)
-- Priority 1 = highest (rez is top idle priority)
-- Stance 0 = all stances

-- Cleric (class_id=2)
-- Spell IDs TBD by data-expert from spells_new query:
--   SELECT id, name, classes2 as clr_level, mana, cast_time, base_value
--   FROM spells_new WHERE effectid1=81 OR effectid2=81 ... (check all 12 effect slots)
--   AND (classes2 > 0 AND classes2 <= 65)

-- Paladin (class_id=3) — same query with classes3

-- Necromancer (class_id=11) — Convergence (spell_id=1733)
INSERT INTO companion_spell_sets
(class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct)
VALUES (11, 53, 65, 1733, 65536, 0, 1, 0, 0);
```

**Rule values SQL:**
```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value) VALUES
(1, 'Companions:RezEnabled', 'true'),
(1, 'Companions:RezPostCombatDelayS', '10'),
(1, 'Companions:RezRange', '200'),
(1, 'Companions:XPDeathPenaltyPct', '10'),
(1, 'Companions:RezWaiveReagents', 'true');
```

#### Configuration Changes

No `eqemu_config.json` changes needed. All tuning goes through `rule_values`.

## Lua/C++ Interface Contract

The PRD requires this section. Since the rez system is implemented entirely in C++, the interface contract is between the C++ spell AI and the C++ entity lifecycle:

### C++ Internal Interface

| Method | Location | Signature | Purpose |
|--------|----------|-----------|---------|
| `Companion::ResurrectFromCorpse` | `companion.cpp` | `static void ResurrectFromCorpse(Corpse* corpse, uint16 spell_id, Mob* caster)` | Entry point for companion rez. Called from `SpellEffect::Revive` handler. Creates new companion entity at corpse position, restores XP, deletes corpse. |
| `Companion::ApplyDeathXPPenalty` | `companion.cpp` | `void ApplyDeathXPPenalty()` | Deducts `Companions:XPDeathPenaltyPct` of level XP from `m_companion_xp`. Called from `Death()`. |
| `Companion::AI_ResurrectDeadGroupMember` | `companion_ai.cpp` | `bool AI_ResurrectDeadGroupMember()` | Full rez AI: find corpse by priority, select best rez spell, handle mana/meditation, cast. Returns true if a spell was cast. |
| `Companion::FindDeadGroupMemberCorpse` | `companion_ai.cpp` | `Corpse* FindDeadGroupMemberCorpse()` | Scans `corpse_list` for companion/player corpses belonging to the owner, within `Companions:RezRange`. Returns highest-priority closest corpse. |
| `Corpse::SetCompanionData` | `corpse.cpp` | `void SetCompanionData(uint32 companion_id, uint32 owner_id)` | Marks a corpse as a companion corpse. Called from `attack.cpp` after corpse creation. |
| `Corpse::IsCompanionCorpse` | `corpse.h` | `bool IsCompanionCorpse() const` | Returns `m_companion_id > 0`. Used by `SpellEffect::Revive` handler and corpse scanning. |
| `EntityList::GetCompanionCorpseByOwnerWithinRange` | `entity.cpp` | `Corpse* GetCompanionCorpseByOwnerWithinRange(uint32 owner_char_id, Mob* center, int range)` | Finds companion corpses matching owner within range. Used by `FindDeadGroupMemberCorpse()`. |

### Lua Exposure (Future)

Currently no Lua exposure is needed. If `!rez [target]` is added later (PRD non-goal), the following would be exposed:
- `Lua_Companion:ResurrectCorpse(corpse_entity)` — manual rez command
- `Lua_Companion:GetRezSpellID()` — returns best available rez spell

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Add 5 new rules to `ruletypes.h` and insert into `rule_values` | **c-expert** | — | Small: 10 lines in ruletypes.h + SQL insert |
| 2 | Add companion metadata to Corpse class (`corpse.h/cpp`) | **c-expert** | — | Small: 2 new fields, 3 new methods, constructor init |
| 3 | Strip loot from companion corpses and set companion data in `attack.cpp` | **c-expert** | 2 | Small: ~10 lines after corpse creation |
| 4 | Extend `SpellEffect::Revive` in `spell_effects.cpp` to handle companion corpses | **c-expert** | 2 | Small: ~15 lines in the Revive case block |
| 5 | Add `GetCompanionCorpseByOwnerWithinRange()` to `entity.h/cpp` | **c-expert** | 2 | Small: ~20 lines, follows existing `GetCorpseByOwnerWithinRange` pattern |
| 6 | Implement `ApplyDeathXPPenalty()` and `GetXPForCurrentLevel()` in `companion.cpp`, call from `Death()` | **c-expert** | 1 | Small: ~25 lines + call in Death() |
| 7 | Implement `ResurrectFromCorpse()` static method in `companion.cpp` | **c-expert** | 2, 5, 6 | Medium: ~80 lines — load companion data, create entity, set stats, join group, delete corpse |
| 8 | Add rez delay timer, update `AI_IdleCastCheck()` and `Process()` in `companion.cpp` | **c-expert** | 1 | Small: ~20 lines — timer management, add SpellType_Resurrect to idle mask |
| 9 | Implement `AI_ResurrectDeadGroupMember()`, `FindDeadGroupMemberCorpse()`, `SelectBestRezSpell()`, deity dialogue in `companion_ai.cpp` | **c-expert** | 1, 2, 5, 8 | Medium: ~150 lines — corpse scanning with priority, spell selection, meditation logic, dialogue |
| 10 | Wire rez AI into `AI_Cleric()`, `AI_Paladin()`, `AI_Necromancer()` idle paths | **c-expert** | 9 | Small: ~15 lines across 3 methods — replace stubs |
| 11 | Verify rez spell IDs and data from `spells_new`, populate `companion_spell_sets` | **data-expert** | — | Medium: query spells_new for all SE_Revive spells, verify CLR/PAL/NEC levels and mana costs, write INSERT statements |
| 12 | Multiple-healer coordination: only highest-rez-capable companion attempts | **c-expert** | 9 | Small: ~15 lines in `AI_ResurrectDeadGroupMember()` — check if another companion is already casting a rez spell |

**Implementation order:** Tasks 1-2 are independent foundations. Task 11 (data) is independent of all C++ work. Tasks 3-6 can run after 2. Tasks 7-8 need the foundations. Tasks 9-10 are the final assembly. Task 12 is a refinement.

**Critical path:** 2 → 4 → 7 → 9 → 10

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Companion corpse entity ID changes between death and rez | Low | High — stale pointer crash | `ResurrectFromCorpse()` receives Corpse* directly from SpellEffect handler, which gets it from entity_list. The corpse entity persists until explicitly deleted. |
| Race condition: two healers both find the same corpse | Medium | Low — double rez attempt | Add check in `AI_ResurrectDeadGroupMember()`: if another companion `IsCasting()` a `SpellType_Resurrect` spell, skip. Only one healer rezzes at a time. |
| Corpse despawns while rez is casting (6-7s cast time) | Low | Medium — spell completes on deleted target | The death despawn timer is 30 minutes. The corpse decay timer for NPC corpses is much shorter (minutes), but companion corpses should use the death despawn timer duration. Override the corpse decay time for companion corpses to match `DeathDespawnS`. |
| `m_loot_items` reference in corpse constructor is moved-from | Low | Low — just ensures loot is empty | Clear loot on the corpse AFTER construction using `RemoveAllLoot()` rather than trying to intercept the move. |
| Companion XP goes negative | Very Low | Low — floor at 0 | Explicit floor in `ApplyDeathXPPenalty()`. |
| Rez spell data missing from `spells_new` for some spells | Low | Medium — rez at that level tier unavailable | Data-expert validates all spell IDs. If a spell doesn't exist in the DB, that tier is simply skipped — the AI falls back to the next lower tier. |

### Compatibility Risks

| Risk | Mitigation |
|------|------------|
| Existing companion death flow changed | XP penalty and corpse metadata are ADDITIVE — the existing death/dismiss flow is untouched. Rez is a new path that short-circuits the dismiss timer. |
| `SpellEffect::Revive` handler change could affect player rez | The new companion path is gated by `IsCompanionCorpse()` — the existing `IsPlayerCorpse()` path is unchanged and checked first. |
| NPC loot stripping could affect non-companion NPCs | The loot strip is explicitly gated by `IsCompanion()` check in `attack.cpp`. |

### Performance Risks

| Risk | Mitigation |
|------|------------|
| Corpse scanning on every idle AI tick | The scan iterates `corpse_list` which is typically < 50 entities in a zone. The scan is gated by `SpellType_Resurrect` in the idle mask, which only fires when the AI tick decides to cast. This is a < 1ms operation. |
| Companion entity creation in `ResurrectFromCorpse()` | Same cost as `Unsuspend()` — one DB read, one entity creation, one group join. Happens at most a few times per combat encounter. |

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes. All the building blocks exist:

- **Corpse metadata**: Adding fields to Corpse is straightforward — it's a simple class with no serialization constraints (NPC corpses are transient entities, not persisted to DB).
- **SpellEffect::Revive extension**: The handler is a clean switch case. Adding an `else if` for companion corpses is trivial.
- **Rez AI**: The pattern is well-established by the Merc system (`merc.cpp:2003-2018`). The companion AI already has the `SelectFirstSpell()` helper, the spell type system, and the idle/engaged cast routing.
- **ResurrectFromCorpse**: Follows the same pattern as `Companion::Unsuspend()` but with reduced HP/mana and at the corpse position instead of the owner position.
- **AI_IdleCastCheck**: One-line change to add `SpellType_Resurrect` to the bitmask.

**Hardest part**: `ResurrectFromCorpse()` — this method must correctly: load companion data from DB, create a new Companion entity with the right NPCType, position at corpse location, set HP/mana to post-rez values, restore partial XP, add to entity list, rejoin group, resume following owner, and delete the corpse. This is a 80-line method with several failure points. The pattern is established by `CreateFromNPC()` but adapted for rez-specific state.

**Protocol feasibility**: Confirmed no new opcodes needed. Player rez uses existing `OP_RezzRequest` flow. Companion rez uses standard spawn/despawn packets that the client already handles. The Titanium client will display NPC names in the `rezzer_name` field correctly — it's just a string field.

### Pass 2: Simplicity

**Can anything be removed?**
- The deity dialogue system could be deferred to a follow-up. However, the PRD explicitly requires it and it's only ~50 lines of C++ (a static lookup table). Including it.
- The multiple-healer coordination (Task 12) could be skipped — if two healers both attempt rez, the second will fail because the corpse will be gone by the time it finishes casting. However, this wastes mana and looks odd. Including it as a small refinement.
- The meditation/sit behavior is already implemented in the companion system (`Sit()`, `Stand()`, `m_mana_report_timer`). Rez AI just needs to call these existing methods.

**Can anything use an existing system?**
- Yes: `SpellType_Resurrect` is already defined. `companion_spell_sets` table already exists. `SelectFirstSpell()` already works. `AIDoSpellCast()` already works. `CompanionGroupSay()` already works.
- The corpse-finding method follows the exact pattern of `GetCorpseByOwnerWithinRange()` — just with different filter criteria.

**YAGNI applied**: No Lua module for dialogue (C++ lookup is simpler). No `!rez` command (PRD non-goal). No cross-zone rez (PRD non-goal). No custom visual effects (PRD non-goal).

### Pass 3: Antagonistic

**What could go wrong?**

1. **Group wipe + zone out**: If all companions die and the player zones out, the companion entities are cleaned up by `Companion::Zone()`. The corpses remain in the old zone but nobody is there to rez them. The death despawn timer eventually fires and dismisses them. **This is correct behavior per PRD.**

2. **Server crash mid-rez**: If the server crashes after the corpse is deleted but before the new companion entity is saved, the companion is lost. **Mitigation**: `ResurrectFromCorpse()` should update `companion_data` BEFORE deleting the corpse. If the server crashes after the DB update but before entity creation, the companion is marked as suspended with restored XP — the player can unsuspend them normally.

3. **Player logs out while rez is casting**: The companion's owner leaves the zone. `Companion::Zone()` fires, saving and depopping the companion. The rez spell cast is interrupted (standard behavior when caster depops). The corpse remains until decay. **This is acceptable.**

4. **Corpse decay timer vs death despawn timer**: NPC corpses use `NPC::MajorNPCCorpseDecayTime` / `MinorNPCCorpseDecayTime` (typically 7-10 minutes). The companion death despawn timer is 30 minutes. If the NPC corpse decays before the death despawn timer fires, the rez target is gone but the companion entity still exists as a dead entity. **Mitigation**: When creating companion corpses, set the corpse decay time to match `DeathDespawnS` (30 min) so the corpse persists for the full rez window.

5. **Player exploit: repeated death/rez for XP manipulation**: Each death costs `XPDeathPenaltyPct` and rez restores a percentage of that loss. Net result is always negative XP. No exploit vector — dying repeatedly only loses XP faster.

6. **Necromancer with no mana for Convergence (700 mana)**: The rez AI handles this — if no rez spell is affordable, the companion meditates. Necromancer companions have mana and can meditate.

7. **Reagent check**: Convergence normally requires Essence Emerald. The `RezWaiveReagents` rule bypasses this. **How**: In `AIDoSpellCast()` or in the spell casting pipeline, check if the caster `IsCompanion()` and `RuleB(Companions, RezWaiveReagents)` — if so, skip the reagent check. This needs to be wired into `Mob::SpellFinished()` where reagents are consumed.

8. **Dead companion entity persists post-death**: `Companion::Death()` sets `SetDepop(false)` so the entity stays in the world. After rez, we create a NEW entity and must ensure the OLD dead entity is cleaned up. The old entity is already scheduled for cleanup via the death despawn timer. **After successful rez**: disable the death despawn timer on the old entity and trigger cleanup (set depop true).

### Pass 4: Integration

**Implementation order verification:**

1. Tasks 1, 2, 11 have no dependencies and can run in parallel.
2. Task 3 needs Task 2 (corpse metadata) — must run after.
3. Task 4 needs Task 2 — must run after.
4. Task 5 needs Task 2 — must run after.
5. Task 6 needs Task 1 (rules) — must run after.
6. Task 7 needs Tasks 2, 5, 6 — the core rez lifecycle method.
7. Task 8 needs Task 1 — timer and idle mask changes.
8. Task 9 needs Tasks 1, 2, 5, 8 — the rez AI assembly.
9. Task 10 needs Task 9 — wiring into class handlers.
10. Task 12 needs Task 9 — coordination refinement.

**No circular dependencies.** The critical path is: 2 → (3,4,5 parallel) → 7 → 9 → 10 → 12.

**Each expert has enough context:**
- c-expert gets this architecture doc which specifies every file, method, and line number.
- data-expert gets clear instructions: query `spells_new` for `SpellEffect::Revive` spells, verify CLR/PAL/NEC level requirements, write INSERT statements.

**Validation covers every changed system** — see Validation Plan below.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| **c-expert** | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12 | All C++ code changes: rules, corpse metadata, spell effect handler, entity list method, companion lifecycle, rez AI |
| **data-expert** | 11 | SQL data: verify spell IDs from `spells_new`, populate `companion_spell_sets` and `rule_values` |

Only two experts needed. The feature is heavily C++ focused. No Lua scripts are modified (dialogue is in C++). No infrastructure changes.

## Validation Plan

The game-tester agent should verify after implementation:

### Core Rez Flow
- [ ] Recruit a cleric companion level 49+. Kill a DPS companion. After combat ends + 10s delay, the cleric targets the corpse and casts Resurrection (spell 392). The dead companion auto-accepts and respawns at the corpse location with ~10-20% HP, 0 mana, no buffs.
- [ ] Verify the rezzed companion automatically re-joins the group and resumes following the owner.
- [ ] Verify the companion corpse disappears after rez.
- [ ] Verify group chat shows deity-appropriate dialogue during cast and completion message after rez.

### Player Rez
- [ ] Kill the player character while a cleric companion survives. After combat ends, the companion targets the player corpse and casts rez. Verify the standard rez consent dialog appears. Accept the rez — verify standard EQ rez behavior (teleport to corpse, XP restore, low HP/mana).
- [ ] Decline the rez — verify the companion moves to the next dead group member (if any).

### XP Death Penalty
- [ ] Note a companion's XP before death. Kill the companion. Verify XP is reduced by `XPDeathPenaltyPct` (default 10%) of current level's XP requirement.
- [ ] Rez with 90% rez spell — verify 90% of the lost XP is restored.
- [ ] Rez with 0% rez spell (Revive) — verify no XP is restored.

### Corpse Behavior
- [ ] Kill a companion and verify the corpse has NO loot (empty corpse window).
- [ ] Verify the corpse is targetable by the healer companion.
- [ ] Wait 30 minutes without rezzing — verify the companion is dismissed and the "returned home" message appears.

### Mana Management
- [ ] Kill a companion when the healer has very low mana (< rez spell cost). Verify the healer sits to meditate and announces "I must gather my strength." Verify they stand and rez when mana is sufficient.
- [ ] Verify the healer uses a lower-tier rez if the best rez is unaffordable but a cheaper one is available.

### Priority System
- [ ] Kill both the player and a DPS companion. Verify the healer rezzes the player first.
- [ ] Kill a cleric companion and a DPS companion. Verify another healer (if present) rezzes the cleric first.

### Multiple Healers
- [ ] Have two cleric companions survive while a third companion dies. Verify only one cleric attempts rez (the one with the highest-level rez spell).

### Necromancer
- [ ] Recruit a necromancer companion level 53+. Kill a companion. Verify the necromancer uses Convergence (no Essence Emerald required). Verify dialogue uses "raised" not "resurrected."

### Paladin
- [ ] Recruit a paladin companion with rez capability. Kill a companion. Verify the paladin rezzes after combat with appropriate dialogue.

### Edge Cases
- [ ] Kill all companions and the player (total wipe). Verify no rez occurs — player respawns at bind, companions are dismissed after timer.
- [ ] Have only a low-level healer (below rez spell level). Verify no rez is attempted.
- [ ] Set `Companions:RezEnabled` to false via GM command. Verify no rez is attempted even with an eligible healer.
- [ ] Have a companion die, zone out with the player, then zone back. Verify the companion corpse is gone (it stayed in the old zone) and the companion is dismissed after the timer fires.

### Reagent Waiver
- [ ] Set `Companions:RezWaiveReagents` to true. Verify necromancer Convergence works without Essence Emerald.
- [ ] Set `Companions:RezWaiveReagents` to false. Verify necromancer Convergence fails (reagent not available). _Note: This tests the rule toggle works; in practice, the rule should always be true._

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
