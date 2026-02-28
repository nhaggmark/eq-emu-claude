# NPC Recruitment / Recruit-Any-NPC Companion System — Architecture & Implementation Plan

> **Feature branch:** `feature/npc-recruitment`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-02-25
> **Status:** Draft

---

## Executive Summary

The NPC recruitment system allows players to convince world NPCs to join their
party as combat-capable group members. The system creates a new `Companion`
C++ class inheriting from `NPC`, using the Merc class's group integration and
zone persistence patterns but deriving stats directly from the recruited NPC's
`npc_types` entry. The Bot class's full-class spell AI provides the combat
intelligence for all 15 Classic-Luclin classes. Recruitment is triggered through
chat commands intercepted by a global Lua quest script, with eligibility checks
and persuasion rolls executed server-side. The Titanium client has no mercenary
UI, so all interaction uses NPC dialogue (say-links) and the standard group
window. New database tables track companion state, and a `Companions` rule
category provides all tuning knobs without code changes.

## Existing System Analysis

### Current State

The EQEmu server has two existing companion NPC systems:

**Mercenary System** (`zone/merc.h`, `zone/merc.cpp` — 5,922 lines):
- `Merc` inherits from `NPC`, which provides full combat entity capabilities
- Template-based: stats from `merc_stats` table, spells from `merc_spell_list_entries`
- Only 4 role archetypes: Tank (1), Healer (2), MeleeDPS (9), CasterDPS (12)
- Group integration: `MercJoinClientGroup()`, `AddMercToGroup()`, `RemoveMercFromGroup()`
- Zone persistence: `ProcessClientZoneChange()` calls `Zone()` (save + depop), then `SpawnMercOnZone()` respawns in new zone
- Suspend/Unsuspend: `Suspend()` saves state to `merc_buffs` table, `Unsuspend()` restores
- Owner tracking: `owner_char_id` field, `GetMercenaryOwner()` returns owning Client
- Entity list: registered in `entity_list.merc_list` via `entity_list.AddMerc()`
- AI: Custom `AI_Process()`, `AICastSpell()`, stance-based spell selection
- Titanium constraint: **No merc opcodes exist in Titanium**. Merc UI packets (OP_MercenaryDataUpdate, OP_MercenaryHire, OP_MercenaryTimer) only exist in SoD+ clients. The Titanium translation layer has EAT_ENCODE entries that suppress merc packets.

**Bot System** (`zone/bot.h`, `zone/bot.cpp` — 13,464 lines + `zone/botspellsai.cpp` — 2,886 lines):
- `Bot` inherits from `NPC`
- All 16 player classes with full spell AI in `botspellsai.cpp`
- Persistent: `bot_data` table mirrors `character_data` for stats
- Player-created from scratch (name, race, class chosen by player)
- Chat commands via `^` prefix (`zone/bot_command.h/cpp`)
- Complex spell settings: per-spell type priorities, thresholds, holds
- Spell lists from `bot_spells_entries` table (or falls back to `npc_spells`)

**Entity Hierarchy:**
```
Entity
  +-- Mob (stats, combat, spells, buffs, position)
       +-- NPC (AI, spawn data, loot, merchants)
       |    +-- Pet
       |    +-- Merc (template-based, 4 roles, zone persist)
       |    +-- Bot (all classes, player-created, persistent DB)
       +-- Client (player character)
       +-- Corpse
```

**Group System** (`zone/groups.h`, `zone/groups.cpp`):
- `Group::AddMember(Mob*, name, char_id, is_merc)` adds any Mob to a group
- MAX_GROUP_MEMBERS = 6 (hard limit in Titanium client)
- NPCs (mercs, bots) appear in the group window when added as group members
- XP splitting via `Group::SplitExp()` includes all group members

**Faction System** (`common/faction.h`):
- FACTION_ALLY = 1, FACTION_WARMLY = 2, FACTION_KINDLY = 3
- Lower number = better faction (opposite of intuition)
- NPC faction from `npc_types.npc_faction_id` -> `npc_faction` -> `npc_faction_entries`
- Player faction checked via `Client::GetCharacterFactionLevel(faction_id)`

**NPC Data** (`npc_types` table, ~150 columns):
- Complete NPC definition: stats, appearance, behavior, combat, cross-references
- Loaded via `content_db.LoadNPCTypesData()` into `NPCType` struct
- Struct pointer used to construct NPC objects: `NPC(const NPCType* d, ...)`

### Gap Analysis

| PRD Requirement | Current State | Gap |
|----------------|---------------|-----|
| Recruit any eligible NPC | No recruitment mechanism exists | New system needed |
| All 15 Classic-Luclin classes | Merc: 4 archetypes. Bot: 16 classes. | Need Bot's spell AI breadth with Merc's simplicity |
| Stats from npc_types | Merc: stats from merc_stats. Bot: stats from bot_data. | New: derive from npc_types directly |
| Zone persistence | Merc: has it. Bot: has it. | Adapt Merc pattern for companions |
| Group integration | Merc: has it. Bot: has it. | Adapt Merc pattern for companions |
| Culture-specific persuasion | Nothing exists | New Lua + SQL system |
| Replacement NPC spawning | Nothing exists | New spawn management system |
| Companion/Mercenary type distinction | Nothing exists | New Lua/LLM integration |
| Disposition-based recruitment | Soul element system (npc-llm-phase3) | Integration point needed |
| Exclusion list | Nothing exists | New SQL table |
| Cooldown tracking | Data buckets available | Use existing data_buckets |
| Suspend/Resume on login/logout | Merc: has it. | Adapt pattern |
| Titanium UI | No merc UI available | Chat commands + group window only |

## Technical Approach

### Architecture Decision: New `Companion` class

**Decision:** Create a new `Companion` class inheriting from `NPC` (like Merc and Bot do), but with key differences:

1. **Stats derived from `npc_types`** — not merc_stats or bot_data
2. **Spell AI borrowed from Bot** — the bot spell system already handles all 16 classes
3. **Group/zone lifecycle borrowed from Merc** — simpler than Bot's full persistence
4. **Recruitment logic in Lua** — keeps the persuasion system configurable without C++ rebuilds
5. **State persistence via new `companion_data` table** — tracks recruited NPC, owner, spawn origin

**Why not subclass Merc directly?** Merc is tightly coupled to its template system (`MercTemplate`, `merc_stats`, `merc_spell_list_entries`). Every method assumes stats come from merc-specific tables. Inheriting from Merc would require overriding nearly every stat calculation method, which is more invasive than a clean NPC subclass.

**Why not subclass Bot?** Bot is designed for player-created characters with full persistence (bot_data mirrors character_data). It expects a creation flow, equipment management, and dozens of `^bot` commands. Adapting this for "recruit a world NPC" would be a square-peg-round-hole situation.

**Why a new class?** A `Companion` class inheriting directly from `NPC`:
- Gets all NPC capabilities (AI_Process, combat, movement, aggro) for free
- Can use the original `npc_types` data directly (NPCType struct is the constructor parameter)
- Adds only what's needed: owner tracking, group integration, zone persistence, spell overrides
- Keeps the codebase clean — no Merc or Bot code is modified

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `common/ruletypes.h` | New rule category | Companions rules for all tuning knobs — config-first |
| `rule_values` (DB) | New rule entries | Runtime tuning without code changes |
| `zone/companion.h/cpp` | New C++ class | Core companion entity: NPC subclass with owner, group, zone persistence |
| `zone/companion_ai.cpp` | New C++ file | Spell AI adapted from bot system for all 15 classes |
| `zone/entity.h/cpp` | Modified | Add companion_list, AddCompanion(), RemoveCompanion() |
| `zone/groups.cpp` | Minor modification | Handle companion auto-dismiss when player joins full group |
| `zone/client.h/cpp` | Minor modification | Track owned companions, spawn-on-zone, suspend/unsuspend |
| `common/servertalk.h` | New ServerOP codes | Cross-zone companion state sync |
| SQL: `companion_data` | New table | Companion persistence (owner, source NPC, state) |
| SQL: `companion_buffs` | New table | Buff persistence across zones |
| SQL: `companion_spell_sets` | New table | Class-specific spell lists for all 15 classes |
| SQL: `companion_exclusions` | New table | NPCs that can never be recruited |
| SQL: `companion_culture_persuasion` | New table | Race -> persuasion stat mapping |
| Lua: `global/global_npc.lua` | Modified | Intercept recruitment keywords |
| Lua: `lua_modules/companion.lua` | New module | Recruitment logic, persuasion rolls, eligibility checks |
| Lua: `lua_modules/companion_culture.lua` | New module | Culture-specific dialogue context for LLM |

### Data Model

#### New Table: `companion_data`

```sql
CREATE TABLE companion_data (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  owner_id        INT UNSIGNED NOT NULL,           -- character_data.id
  npc_type_id     INT UNSIGNED NOT NULL,           -- npc_types.id (source NPC)
  name            VARCHAR(64) NOT NULL,            -- NPC's original name
  companion_type  TINYINT UNSIGNED NOT NULL DEFAULT 0, -- 0=companion, 1=mercenary
  level           TINYINT UNSIGNED NOT NULL,
  class_id        TINYINT UNSIGNED NOT NULL,
  race_id         SMALLINT UNSIGNED NOT NULL,
  gender          TINYINT UNSIGNED NOT NULL DEFAULT 0,
  zone_id         INT UNSIGNED NOT NULL DEFAULT 0, -- current zone
  x               FLOAT NOT NULL DEFAULT 0,
  y               FLOAT NOT NULL DEFAULT 0,
  z               FLOAT NOT NULL DEFAULT 0,
  heading         FLOAT NOT NULL DEFAULT 0,
  cur_hp          BIGINT NOT NULL DEFAULT 0,
  cur_mana        BIGINT NOT NULL DEFAULT 0,
  cur_endurance   BIGINT NOT NULL DEFAULT 0,
  is_suspended    TINYINT UNSIGNED NOT NULL DEFAULT 1,
  stance          TINYINT UNSIGNED NOT NULL DEFAULT 1, -- 0=passive, 1=balanced, 2=aggressive
  spawn2_id       INT UNSIGNED NOT NULL DEFAULT 0,     -- original spawn point (for return)
  spawngroupid    INT UNSIGNED NOT NULL DEFAULT 0,     -- original spawn group
  recruited_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_owner (owner_id),
  INDEX idx_npc_type (npc_type_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
```

#### New Table: `companion_buffs`

```sql
CREATE TABLE companion_buffs (
  companion_id    INT UNSIGNED NOT NULL,
  spell_id        INT UNSIGNED NOT NULL DEFAULT 0,
  caster_level    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  duration_formula TINYINT UNSIGNED NOT NULL DEFAULT 0,
  ticks_remaining INT NOT NULL DEFAULT 0,
  dot_rune        INT NOT NULL DEFAULT 0,
  persistent      TINYINT NOT NULL DEFAULT 0,
  counters        INT NOT NULL DEFAULT 0,
  num_hits        INT NOT NULL DEFAULT 0,
  melee_rune      INT NOT NULL DEFAULT 0,
  magic_rune      INT NOT NULL DEFAULT 0,
  instrument_mod  INT NOT NULL DEFAULT 10,
  buff_tics       INT NOT NULL DEFAULT 0,
  caston_x        INT NOT NULL DEFAULT 0,
  caston_y        INT NOT NULL DEFAULT 0,
  caston_z        INT NOT NULL DEFAULT 0,
  extra_di_chance INT NOT NULL DEFAULT 0,
  INDEX idx_companion (companion_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
```

#### New Table: `companion_spell_sets`

Class-specific spell lists for recruited NPCs, organized by class and level range.
Uses the same spell type constants as the merc spell system.

```sql
CREATE TABLE companion_spell_sets (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  class_id        TINYINT UNSIGNED NOT NULL,
  min_level       TINYINT UNSIGNED NOT NULL DEFAULT 1,
  max_level       TINYINT UNSIGNED NOT NULL DEFAULT 65,
  spell_id        INT UNSIGNED NOT NULL,
  spell_type      INT UNSIGNED NOT NULL,     -- heal, nuke, buff, debuff, etc.
  stance          SMALLINT NOT NULL DEFAULT 0, -- 0=all, 1=passive, 2=balanced, 3=aggressive
  priority        SMALLINT NOT NULL DEFAULT 0,
  min_hp_pct      SMALLINT NOT NULL DEFAULT 0,
  max_hp_pct      SMALLINT NOT NULL DEFAULT 100,
  INDEX idx_class_level (class_id, min_level, max_level)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
```

#### New Table: `companion_exclusions`

```sql
CREATE TABLE companion_exclusions (
  npc_type_id     INT UNSIGNED NOT NULL PRIMARY KEY,
  reason          VARCHAR(255) NOT NULL DEFAULT '',
  exclusion_type  TINYINT UNSIGNED NOT NULL DEFAULT 0  -- 0=manual, 1=auto-detected
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
```

#### New Table: `companion_culture_persuasion`

```sql
CREATE TABLE companion_culture_persuasion (
  race_id         SMALLINT UNSIGNED NOT NULL PRIMARY KEY,
  primary_stat    VARCHAR(16) NOT NULL DEFAULT 'CHA',  -- CHA, STR, INT
  secondary_type  VARCHAR(16) NOT NULL DEFAULT 'faction', -- faction, level, stat
  secondary_stat  VARCHAR(16) DEFAULT NULL,             -- STR, INT, etc. (if type=stat)
  recruitment_type TINYINT UNSIGNED NOT NULL DEFAULT 0,  -- 0=companion, 1=mercenary
  max_disposition TINYINT UNSIGNED NOT NULL DEFAULT 4,  -- 0=rooted..4=eager
  notes           VARCHAR(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
```

Seed data (from PRD racial tables):

```sql
INSERT INTO companion_culture_persuasion VALUES
(1, 'CHA', 'faction', NULL, 0, 4, 'Human'),           -- Human
(2, 'STR', 'level', NULL, 0, 4, 'Barbarian'),         -- Barbarian
(3, 'CHA', 'faction', NULL, 0, 3, 'Erudite (Erudin)'),-- Erudite
(3, 'INT', 'level', NULL, 1, 3, 'Erudite (Paineel)'), -- Erudite (overridden by zone)
(4, 'CHA', 'faction', NULL, 0, 4, 'Wood Elf'),        -- Wood Elf
(5, 'CHA', 'level', NULL, 0, 3, 'High Elf'),          -- High Elf
(6, 'CHA', 'faction', NULL, 0, 4, 'Half Elf'),        -- Half Elf
(7, 'CHA', 'faction', 'STR', 0, 3, 'Dwarf'),          -- Dwarf
(8, 'STR', 'level', NULL, 1, 2, 'Troll'),             -- Troll
(9, 'STR', 'level', NULL, 1, 2, 'Ogre'),              -- Ogre
(10, 'CHA', 'faction', NULL, 0, 4, 'Halfling'),       -- Halfling
(11, 'INT', 'stat', 'CHA', 0, 3, 'Gnome'),            -- Gnome
(12, 'CHA', 'stat', 'INT', 1, 1, 'Dark Elf'),         -- Dark Elf (Neriak)
(128, 'INT', 'level', NULL, 1, 1, 'Iksar'),           -- Iksar
(130, 'CHA', 'faction', NULL, 0, 4, 'Vah Shir');      -- Vah Shir
```

Note: Race 3 (Erudite) has two entries — the Lua script uses zone context to
determine if the NPC is from Erudin (companion) or Paineel (mercenary). This
is handled in the Lua logic, not the table.

### Code Changes

#### C++ Changes

**New Files:**

1. **`zone/companion.h`** (~200 lines) — Companion class declaration
   - Inherits from `NPC`
   - Owner tracking: `owner_char_id`, `GetCompanionOwner()`
   - Companion metadata: companion_type (0/1), stance, original spawn info
   - Virtual overrides: `Death()`, `Damage()`, `AI_Process()`, `Process()`, `FillSpawnStruct()`
   - Lifecycle: `Spawn()`, `Suspend()`, `Unsuspend()`, `Dismiss()`, `Zone()`
   - Group: `CompanionJoinClientGroup()`, static `AddCompanionToGroup()`, `RemoveCompanionFromGroup()`
   - Spell: `LoadCompanionSpells()`, `AICastSpell()`
   - Static factory: `CreateFromNPC(Client* owner, NPC* source_npc)` — creates Companion from a live NPC

2. **`zone/companion.cpp`** (~2000 lines) — Companion class implementation
   - Constructor takes `NPCType*` (copied from the recruited NPC's npc_types data)
   - `CreateFromNPC()`: copies NPCType from the target NPC, creates Companion instance, sets owner
   - `Spawn()`: adds to entity_list, sends spawn packet, joins group
   - `Suspend()`: saves state (HP, mana, buffs) to `companion_data`/`companion_buffs`, depops
   - `Unsuspend()`: loads state from DB, spawns, restores buffs, joins group
   - `Zone()`: calls `Save()` then `Depop()` (same pattern as Merc)
   - `Dismiss()`: removes from group, restores original NPC at spawn point, deletes companion record
   - `ProcessClientZoneChange()`: triggers zone transition
   - `AI_Process()`: delegates to base NPC AI but with companion-specific targeting (follow owner, engage owner's target)
   - `Death()`: creates corpse, starts resurrection timer, auto-dismiss after DeathDespawnS

3. **`zone/companion_ai.cpp`** (~1500 lines) — Spell AI for all 15 classes
   - Adapts the Bot spell AI patterns from `botspellsai.cpp`
   - `LoadCompanionSpells()`: loads from `companion_spell_sets` by class and level
   - Stance-based spell selection (passive/balanced/aggressive)
   - Class-specific behaviors:
     - Tank (WAR/PAL/SK): taunt, defensive abilities
     - Healer (CLR/DRU/SHM): heal group members below HP thresholds, cure, buff, resurrect
     - MeleeDPS (ROG/MNK/RNG/BST): engage target, class abilities
     - CasterDPS (WIZ/MAG/NEC): nuke/dot from range, pet management
     - Utility (ENC/BRD): mez, slow, haste, charm

**Modified Files:**

4. **`zone/entity.h`** — Add companion list
   ```cpp
   std::unordered_map<uint16, Companion *> companion_list;
   void AddCompanion(Companion*, bool SendSpawnPacket = true, bool dontqueue = false);
   void RemoveCompanion(uint16 id);
   inline const auto &GetCompanionList() { return companion_list; }
   ```

5. **`zone/entity.cpp`** — Implement `AddCompanion()`, `RemoveCompanion()`
   Following the exact pattern of `AddMerc()`/`RemoveMerc()`.

6. **`zone/client.h`** — Add companion ownership tracking
   ```cpp
   std::vector<Companion*> m_companions;
   void SpawnCompanionsOnZone();
   void SuspendCompanions();
   uint8 GetCompanionCount();
   Companion* GetCompanionByNPCTypeID(uint32 npc_type_id);
   ```

7. **`zone/client.cpp`** — Implement companion spawn-on-zone
   In the zone-in process (after `SpawnMercOnZone()`), call `SpawnCompanionsOnZone()`
   which loads companion_data for this character and unsuspends active companions.

8. **`zone/groups.cpp`** — Handle companion auto-dismiss
   When a new player joins a full group (6 members), auto-dismiss the most recently
   added companion. This is a small addition to the `AddMember()` flow.

9. **`common/ruletypes.h`** — Add Companions rule category (see Configuration section)

10. **`common/servertalk.h`** — Add `ServerOP_CompanionZone`, `ServerOP_CompanionDismiss`
    for cross-zone companion state management.

11. **`zone/mob.h`** — Add `IsCompanion()` virtual (returns false by default, overridden in Companion)

12. **Database migration** — Add new tables via `common/database/database_update_manifest.h`

#### Lua/Script Changes

13. **`akk-stack/server/quests/global/global_npc.lua`** — Modified
    Add recruitment keyword interception in `event_say()`:
    ```lua
    function event_say(e)
        local companion_lib = require("companion")
        if companion_lib.is_recruitment_keyword(e.message) then
            companion_lib.attempt_recruitment(e.self, e.other)
            return
        end
        -- ... existing global NPC logic
    end
    ```

14. **`akk-stack/server/quests/lua_modules/companion.lua`** — New module (~500 lines)
    Core recruitment logic:
    - `is_recruitment_keyword(message)` — checks for "recruit", "join me", etc.
    - `attempt_recruitment(npc, client)` — main entry point:
      1. Check `RuleB(Companions, Enabled)`
      2. Check eligibility (level range, faction, NPC type, group capacity, exclusions)
      3. Check cooldown (data bucket: `companion_cooldown_{npc_type_id}_{char_id}`)
      4. Calculate persuasion bonus (culture-specific stats from DB)
      5. Roll recruitment check
      6. On success: trigger C++ companion creation (via new Lua API method)
      7. On failure: set cooldown, generate LLM refusal context
    - `is_eligible_npc(npc)` — checks exclusion list, class, bodytype, etc.
    - `get_persuasion_bonus(client, npc)` — culture-specific stat calculation
    - `handle_dismiss(npc, client)` — dismiss command handler
    - `handle_stance(npc, client, stance)` — stance command handler

15. **`akk-stack/server/quests/lua_modules/companion_culture.lua`** — New module (~200 lines)
    Culture-specific dialogue context for LLM integration:
    - Acceptance/refusal templates per culture
    - Companion vs. mercenary framing
    - Party tension dialogue hints

#### Database Changes

16. **Schema migration** — New tables (see Data Model above)

17. **companion_spell_sets seed data** — Spell lists for all 15 Classic-Luclin classes
    This is the largest data task. For each class, we need spells organized by level range
    and type (heal, nuke, buff, debuff, mez, slow, etc.). Sources:
    - Bot spell entries (`bot_spells_entries`) — primary source, already covers all classes
    - Merc spell lists (`merc_spell_list_entries`) — secondary reference for Tank/Healer
    - `spells_new` table — for manual additions where bot lists have gaps

18. **companion_exclusions seed data** — Curated NPC exclusion list
    - All NPCs with class 40 (Banker), 41 (Merchant), 20-35 (Guildmasters), 59-71 (special merchants)
    - Named lore anchors from PRD (Lucan, Antonius Bayle, etc.)
    - Raid bosses (rare_spawn flag or manual curation)

19. **companion_culture_persuasion seed data** — Race-to-culture mapping (see above)

20. **rule_values seed data** — Default companion rules (see Configuration section)

#### Configuration Changes

21. **New rule category: Companions**
    ```cpp
    RULE_CATEGORY(Companions)
    RULE_BOOL(Companions, Enabled, true, "Enable the companion recruitment system")
    RULE_INT(Companions, MaxPerPlayer, 5, "Maximum companions per player (group slots permitting)")
    RULE_INT(Companions, LevelRange, 3, "Level range for recruitment eligibility (+/- from player level)")
    RULE_INT(Companions, BaseRecruitChance, 50, "Base recruitment success percentage")
    RULE_INT(Companions, StatScalePct, 100, "Global stat multiplier for companions (percentage)")
    RULE_INT(Companions, SpellScalePct, 100, "Heal/damage scaling for companion spells (percentage)")
    RULE_INT(Companions, RecruitCooldownS, 900, "Cooldown in seconds after failed recruitment attempt")
    RULE_INT(Companions, DeathDespawnS, 1800, "Seconds before unresurrected companion auto-dismisses")
    RULE_INT(Companions, MinFaction, 3, "Minimum faction level for recruitment (1=Ally, 2=Warmly, 3=Kindly)")
    RULE_BOOL(Companions, XPContribute, true, "Whether companions count in XP split calculations")
    RULE_INT(Companions, MercRetentionCheckS, 600, "Seconds for mercenary-type retention check interval")
    RULE_INT(Companions, ReplacementSpawnDelayS, 30, "Delay before replacement NPC spawns at vacated spawn point")
    RULE_CATEGORY_END()
    ```

22. **rule_values INSERT** — Set defaults for ruleset 1
    ```sql
    INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES
    (1, 'Companions:Enabled', 'true', 'Master toggle for companion recruitment'),
    (1, 'Companions:MaxPerPlayer', '5', 'Maximum companions per player'),
    (1, 'Companions:LevelRange', '3', '+/- levels for recruitment'),
    (1, 'Companions:BaseRecruitChance', '50', 'Base recruitment chance percentage'),
    (1, 'Companions:StatScalePct', '100', 'Companion stat scaling percentage'),
    (1, 'Companions:SpellScalePct', '100', 'Companion spell scaling percentage'),
    (1, 'Companions:RecruitCooldownS', '900', 'Failed recruitment cooldown (seconds)'),
    (1, 'Companions:DeathDespawnS', '1800', 'Unresurrected companion dismiss timer (seconds)'),
    (1, 'Companions:MinFaction', '3', 'Minimum faction for recruitment (3=Kindly)'),
    (1, 'Companions:XPContribute', 'true', 'Companions contribute to XP split'),
    (1, 'Companions:MercRetentionCheckS', '600', 'Mercenary retention check interval'),
    (1, 'Companions:ReplacementSpawnDelayS', '30', 'Replacement NPC spawn delay');
    ```

## PRD Open Questions — Architect Answers

### Q1: Merc class vs. Bot class as foundation?

**Answer: Neither directly. New `Companion` class inheriting from `NPC`.**

The Merc class is too tightly coupled to its template system (MercTemplate, merc_stats,
merc_spell_list_entries). The Bot class is too complex and designed for player-created
characters. A new `Companion : public NPC` class takes the best of both:
- **From Merc:** Group join/leave patterns, zone persistence lifecycle (Zone/Suspend/Unsuspend), owner tracking, simple stance system
- **From Bot:** Full-class spell AI (adapted, not inherited), all 15 Classic-Luclin classes
- **Original:** Stats derived directly from `npc_types` via NPCType struct copy

### Q2: Spell list completeness?

**Answer: Derive from `bot_spells_entries` table, supplemented with manual entries.**

The bot spell system already has entries for all 16 player classes. We will:
1. Create `companion_spell_sets` table with entries adapted from `bot_spells_entries`
2. Map bot spell types to our simpler stance-based system
3. Filter to Classic-Luclin era spells only (check `spells_new` for expansion availability)
4. Add missing entries manually where bot lists have gaps for specific levels

This is a data task (SQL), not a code task. The data-expert agent populates the table.

### Q3: Replacement NPC behavior?

**Answer: Replacement NPCs are generic and do NOT serve quest functions.**

When Guard Noyan is recruited, "a Qeynos guard" spawns in his place. This replacement:
- Uses the same npc_types entry but with name changed to generic form
- Has quest scripts DISABLED (no LLM, no say handlers beyond default)
- Has the same patrol grid/spawn behavior
- Despawns when the original NPC is dismissed and returns

This is acceptable because the PRD's eligibility rules already exclude quest-critical NPCs.
If an NPC has Lua/Perl quest scripts with trade/say handlers beyond simple hail, they
should be flagged in the exclusion list. The Lua eligibility checker tests for this.

### Q4: Recruit zone persistence implementation?

**Answer: Adapt the Merc pattern directly.**

The Merc zone persistence flow is:
1. Client zones out -> `Merc::ProcessClientZoneChange()` -> `Merc::Zone()` (Save + Depop)
2. Client zones in -> `Client::SpawnMercOnZone()` -> `Merc::LoadMercenary()` -> `Merc::Spawn()`

Companion equivalent:
1. Client zones out -> `Companion::ProcessClientZoneChange()` -> `Companion::Zone()` (Save + Depop)
2. Client zones in -> `Client::SpawnCompanionsOnZone()` -> creates Companions from `companion_data`

The key difference: Merc loads from merc_stats template. Companion loads from the
original npc_types entry (stored as npc_type_id in companion_data). The NPCType struct
is reloaded from the content database on each zone-in.

### Q5: Performance impact of multiple recruits?

**Answer: Manageable with existing architecture. Mitigations identified.**

Worst case: 6 players x 5 companions = 30 companion NPCs running AI simultaneously.
This is comparable to a busy zone with 30+ NPCs already, which EQEmu handles routinely.

Mitigations:
- Companion AI ticks use the same timer system as NPC AI (no extra overhead)
- Spell AI checks are the expensive part — use the Merc's approach of checking once per
  AI cycle, not every tick
- LLM queries are async via the sidecar and rate-limited — no server blocking
- Companion process() is simpler than Bot process() (no equipment management, no saved groups)
- Server designed for hundreds of NPCs per zone; 30 companions is well within budget

### Q6: Recruit buff persistence?

**Answer: Yes, reuse the merc_buffs pattern with `companion_buffs` table.**

The `companion_buffs` table mirrors `merc_buffs` in structure. On zone-out, active buffs
are saved. On zone-in, they are restored. This is a proven pattern.

### Q7: Interaction between recruits and the pet system?

**Answer: Pets do not occupy group slots. A Magician with 4 recruits and a pet works.**

Verified in the source: pets are tracked separately in `entity_list.npc_list` with owner
references, not in the group member array. `Group::GroupCount()` only counts members
in the `members[]` array (max 6). Pets are excluded. This means a player + 5 companions +
any number of companion/player pets all work fine.

### Q8: Chat command namespace?

**Answer: Use say-link commands only. No new slash commands.**

The Titanium client's slash command list is fixed. Adding new slash commands requires
client modification. Say-links and NPC dialogue work with any client version.

Commands handled via `EVENT_SAY` in the global NPC script:
- "recruit" / "join me" / "come with me" — recruit targeted NPC
- "dismiss" / "return home" / "you're free to go" — dismiss targeted companion
- "guard here" / "follow me" — position commands
- "aggressive" / "passive" / "balanced" — stance commands

These are intercepted when the player is targeting a valid NPC (for recruit) or
their own companion (for management commands).

### Q9: Culture-specific persuasion stat lookup?

**Answer: Race-based lookup via `companion_culture_persuasion` table, with zone override logic in Lua.**

NPC race strongly correlates with culture in Classic-Luclin EQ. The `companion_culture_persuasion`
table maps race_id to primary/secondary persuasion stats and recruitment type.

Special case: Erudites from Erudin vs. Paineel. The Lua script checks the NPC's current zone
to determine which culture applies. If the NPC is in Paineel/The Hole, they use the
mercenary-type Erudite entry. If in Erudin/Toxxulia Forest, they use the companion-type entry.

Similarly, Freeport NPCs: Steel Warriors and Knights of Truth are companion-type,
while Freeport Militia are mercenary-type. The Lua script checks NPC faction to determine
which type applies.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Add Companions rule category to `common/ruletypes.h` and seed `rule_values` | c-expert | — | Small (~30 lines C++, ~20 lines SQL) |
| 2 | Create `companion_data`, `companion_buffs`, `companion_exclusions`, `companion_culture_persuasion` tables via migration manifest | data-expert | — | Medium (4 tables, ~150 lines SQL) |
| 3 | Seed `companion_exclusions` with NPC class-based auto-exclusions + named lore anchors | data-expert | 2 | Medium (~100 lines SQL) |
| 4 | Seed `companion_culture_persuasion` with racial persuasion mappings | data-expert | 2 | Small (~20 lines SQL) |
| 5 | Create `companion_spell_sets` table and seed with spell data for all 15 Classic-Luclin classes | data-expert | 2 | Large (~1000+ spell entries, sourced from bot_spells_entries + spells_new) |
| 6 | Implement `Companion` class: `zone/companion.h`, `zone/companion.cpp` — entity, lifecycle, stats, group, zone persistence | c-expert | 1, 2 | Large (~2200 lines C++) |
| 7 | Implement companion spell AI: `zone/companion_ai.cpp` — all 15 classes, stance-based | c-expert | 5, 6 | Large (~1500 lines C++) |
| 8 | Modify `zone/entity.h/cpp` — add companion_list, AddCompanion/RemoveCompanion | c-expert | 6 | Small (~50 lines C++) |
| 9 | Modify `zone/client.h/cpp` — companion ownership, SpawnCompanionsOnZone, SuspendCompanions | c-expert | 6 | Medium (~200 lines C++) |
| 10 | Modify `zone/groups.cpp` — auto-dismiss companion when player joins full group | c-expert | 6 | Small (~30 lines C++) |
| 11 | Add `ServerOP_CompanionZone`, `ServerOP_CompanionDismiss` to `common/servertalk.h` | c-expert | 6 | Small (~20 lines C++) |
| 12 | Add `IsCompanion()` virtual to `zone/mob.h`, Lua binding in `zone/lua_npc.h/cpp` | c-expert | 6 | Small (~20 lines C++) |
| 13 | Add DB migration entries to `common/database/database_update_manifest.h` | c-expert | 2 | Small (~50 lines C++) |
| 14 | Create `companion.lua` module — recruitment logic, eligibility, persuasion rolls | lua-expert | 6 | Medium (~500 lines Lua) |
| 15 | Create `companion_culture.lua` module — culture dialogue templates for LLM | lua-expert | 4, 14 | Medium (~200 lines Lua) |
| 16 | Modify `global/global_npc.lua` — intercept recruitment/management keywords | lua-expert | 14 | Small (~50 lines Lua) |
| 17 | Add Lua API methods for companion creation/management (expose C++ to Lua) | c-expert | 6, 14 | Medium (~150 lines C++) |
| 18 | Expose Companion class to Lua: `zone/lua_companion.h/cpp` | c-expert | 6 | Medium (~100 lines C++) |

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Bot spell AI too complex to adapt for companions | Medium | High | Start with simplified versions: heal/nuke/buff/debuff only, add class-specific behaviors incrementally |
| NPC stats from npc_types are not balanced for companion use (many NPCs have manual stats set for specific encounters) | High | Medium | Apply StatScalePct rule as a global modifier; most generic NPCs (guards, commoners) have reasonable stats. The +/-2 level range ensures stats are level-appropriate. |
| Zone transition timing issues (companion spawns before/after client) | Medium | Medium | Use the Merc pattern exactly — it has been battle-tested for years |
| Companion spell lists have gaps for certain class/level combinations | High | Medium | Start with bot_spells_entries as base, fill gaps as discovered during testing |
| Replacement NPC spawn races with original NPC despawn | Low | Low | Spawn replacement after a configurable delay (ReplacementSpawnDelayS rule) |

### Compatibility Risks

| Risk | Mitigation |
|------|------------|
| Existing Merc system disrupted | Companion is a separate class — Merc code is not modified |
| Existing Bot system disrupted | Companion is a separate class — Bot code is not modified |
| Existing group system disrupted | AddMember() already supports NPCs; only adds auto-dismiss logic |
| Existing quest scripts affected | Recruitment keywords intercepted in global_npc.lua before passing to LLM — existing NPC scripts unaffected |
| Data migration breaks existing schema | New tables only — no existing tables modified |

### Performance Risks

| Risk | Mitigation |
|------|------------|
| 30 companions in a zone running AI | EQEmu handles 100+ NPCs per zone routinely; 30 is well within budget |
| Companion spell AI checks on every tick | Use timer-based checks (like Merc AI), not per-tick |
| LLM queries for companion dialogue | Async via sidecar, rate-limited, only on player interaction (not during combat) |
| Database load for companion save/restore | Batch operations on zone transition; companion_data/buffs tables are small |

## Review Passes

### Pass 1: Feasibility

**Can we build this with the existing codebase?**

Yes. The architecture directly follows proven patterns:
- `Companion : public NPC` follows the exact inheritance pattern of `Merc : public NPC` and `Bot : public NPC`
- Group integration uses existing `Group::AddMember()` which already accepts any `Mob*`
- Zone persistence uses the proven Merc pattern (Save/Depop on zone-out, Load/Spawn on zone-in)
- Entity list management follows the `merc_list` pattern
- The Titanium client already renders NPCs in the group window (bots and mercs use this)
- Say-link commands are handled by existing quest event dispatch

**Hardest part:** Companion spell AI for all 15 classes. The bot system has this but it is
tightly coupled to Bot's data structures. We need to adapt (not copy) the spell selection
logic. Starting with a simplified version (4 archetypes like Merc) and expanding to
class-specific behavior is the safest approach.

**Protocol confirmation:** The Titanium client has NO mercenary opcodes (confirmed by
checking `titanium_ops.h`). All merc UI packets are either missing from the Titanium
opcode map or eaten by `EAT_ENCODE` in `titanium.cpp`. This confirms the PRD's approach:
chat commands + group window only, no merc UI hijacking.

### Pass 2: Simplicity

**Is this the simplest approach?**

Yes — with one simplification opportunity identified:

**Deferred for later:** The `companion_spell_sets` table could initially be populated with
ONLY the 4 Merc archetypes (Tank, Healer, MeleeDPS, CasterDPS). Classes without direct
merc equivalents (Enchanter, Bard, Necromancer, etc.) would fall back to NPC's native
`npc_spells_id` from npc_types. This gets the system working faster and adds class-specific
spell lists incrementally. However, this means initial companions might not use optimal
spells for their class. The PRD requires "competent" AI for all 15 classes, so we should
plan for full spell lists even if we build them incrementally.

**Removed/deferred complexity:**
- No companion equipment management (PRD non-goal)
- No companion-to-companion interaction (PRD non-goal)
- No raid support (PRD: bounded by 6-member group)
- No companion leveling (PRD: recruits stay at their database level)
- No companion persistence across dismissal (each recruitment is fresh)

### Pass 3: Antagonistic

**What could go wrong?**

1. **Exploit: recruiting boss adds or scripted NPCs.** The exclusion list must be
   comprehensive. Mitigation: auto-exclude NPCs with `rare_spawn=1`, bodytype 11/64+,
   classes 20-71 (guildmasters, merchants, etc.). Manual exclusion list for named lore anchors.

2. **Exploit: recruiting NPCs to grief other players on a shared server.** A player recruits
   all guards in a city, leaving it defenseless. Mitigation: replacement NPC spawns after
   delay. Also, this is a 1-6 player server — griefing is minimal by design.

3. **Race condition: two players try to recruit the same NPC simultaneously.** Mitigation:
   the Lua script checks if the NPC is already recruited (entity variable flag set on
   successful recruitment). First player wins; second gets "This NPC is already spoken for."

4. **Crash during zone transition with companions.** If the server crashes mid-zone, companions
   might be in a half-saved state. Mitigation: companion_data.is_suspended is set to 1 (safe
   state) at the START of zone-out, before Save() completes. On next login, suspended
   companions restore cleanly.

5. **NPC with npc_spells_id = 0 recruited as caster class.** Some NPCs have no spell list
   assigned. Mitigation: `LoadCompanionSpells()` falls back to `companion_spell_sets` by
   class and level. The NPC's native spell list is only used if companion_spell_sets has
   no matching entries.

6. **Faction manipulation: player farms faction, recruits, then tanks faction.** The
   mercenary retention check (every MercRetentionCheckS seconds) handles this for
   mercenary-type companions. Companion-type companions are loyal per PRD design.

7. **Memory leak from NPCType struct copies.** Each companion copies the NPCType struct.
   Mitigation: free the copy in Companion destructor (same pattern as Merc, which
   allocates NPCType with `new` and frees in destructor).

8. **Player logs off with companions in dangerous location, logs back in.** Companions
   respawn at the player's location on login. If the player is in a dangerous zone,
   companions immediately enter combat. Mitigation: companions spawn with full HP/mana
   on unsuspend (configurable via setMaxStats flag, like Merc).

### Pass 4: Integration

**How do the pieces fit together?**

Implementation order is critical. Dependencies form a DAG:

```
Rules (Task 1) ──┐
                  ├──> Companion class (Task 6) ──> AI (Task 7) ──> Lua API (Task 17, 18)
Tables (Task 2) ─┤                              ├──> Entity (Task 8)
                  │                              ├──> Client (Task 9)
Exclusions (3) ──┤                              ├──> Groups (Task 10)
Culture (4) ─────┤                              └──> ServerOP (Task 11)
Spells (5) ──────┘
                  Lua recruitment (14) ──> Culture Lua (15) ──> Global NPC (16)
```

**Phase 1 (Foundation — can be parallel):**
- Tasks 1-5 (rules, tables, seed data) — data-expert and c-expert work in parallel
- c-expert adds rule definitions to C++ header
- data-expert creates all SQL tables and seed data

**Phase 2 (Core C++ — sequential):**
- Task 6: Companion class (the big task, depends on Phase 1)
- Task 7: Spell AI (depends on Task 6 and Task 5 spell data)
- Tasks 8-13: Integration points (depend on Task 6)

**Phase 3 (Lua + Integration — after C++ core):**
- Tasks 14-16: Lua modules (depend on Task 6 for the Lua API)
- Tasks 17-18: Lua bindings (depend on both C++ and Lua)

**Validation can begin after Phase 2** for basic companion spawning and combat.
Full validation (recruitment flow, persuasion, culture) requires Phase 3 completion.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | 1, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18 | Core C++ class implementation, entity integration, Lua bindings |
| data-expert | 2, 3, 4, 5 | Database tables, seed data, spell list compilation |
| lua-expert | 14, 15, 16 | Recruitment logic, culture system, global script integration |

## Validation Plan

### Core Functionality
- [ ] A player can target an eligible NPC and say "recruit" to initiate recruitment
- [ ] Recruitment succeeds based on faction, persuasion, level range, and disposition
- [ ] On success, the NPC despawns and joins the player's group
- [ ] On failure, a cooldown is applied and refusal dialogue is generated
- [ ] Excluded NPCs (merchants, bankers, guildmasters, lore anchors) cannot be recruited
- [ ] NPCs outside the level range cannot be recruited
- [ ] NPCs with faction below Kindly cannot be recruited

### Combat AI
- [ ] Tank companions taunt and engage enemies in melee
- [ ] Healer companions heal group members below HP thresholds
- [ ] DPS companions deal damage to group's target
- [ ] Utility companions (Enchanter, Bard) use crowd control and buffs
- [ ] Companions respond to stance commands (passive, balanced, aggressive)
- [ ] Companions follow the player when not in combat

### Lifecycle
- [ ] Companions persist across zone transitions
- [ ] Companions are suspended on player logout and restored on login
- [ ] Companions can be dismissed via say command
- [ ] Dismissed companions return to their original spawn point
- [ ] When a companion dies, they can be resurrected within 30 minutes
- [ ] Unresurrected companions auto-dismiss after DeathDespawnS
- [ ] A replacement NPC spawns at the companion's original location
- [ ] The replacement NPC despawns when the companion is dismissed/returns

### Group Integration
- [ ] Companions appear in the group window with their NPC name
- [ ] Maximum group size of 6 is respected (including companions)
- [ ] If a player joins a full group, the most recently recruited companion is dismissed
- [ ] Companions contribute to XP split when XPContribute rule is true

### Configuration
- [ ] All Companions rules can be modified at runtime via `#rules` GM command
- [ ] StatScalePct correctly scales companion stats
- [ ] SpellScalePct correctly scales companion spell effectiveness
- [ ] Recruitment probability can be tuned via BaseRecruitChance rule
- [ ] Level range can be adjusted via LevelRange rule

### Edge Cases
- [ ] Two players cannot recruit the same NPC simultaneously
- [ ] Recruitment cannot be initiated during combat
- [ ] Companion pets (Magician, Beastlord, Necromancer) do not take group slots
- [ ] Server crash recovery: companions load correctly from suspended state on restart
- [ ] Zone crash: companions restore on next zone-in

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above: **c-expert**, **data-expert**, **lua-expert**.
> They will coordinate via `SendMessage` and work through the task list in
> dependency order, starting with the parallel Phase 1 tasks.

---

## Expanded Scope Addendum (2026-02-27)

> **Context:** The user requested that companion leveling, equipment management,
> and lifelong persistence — originally explicit non-goals — be brought into scope.
> The architect's feasibility review (`user-story-feasibility.md`) confirmed all
> three expansions are technically feasible. The game-designer wrote 38 user stories
> including 19 for the expanded scope (`user-stories.md`). This addendum extends the
> architecture with 6 new tasks (19-24) to cover the expanded scope.

### Scope Changes

| Feature | Previous Status | New Status |
|---------|----------------|------------|
| Companion leveling (XP, stat scaling) | Non-goal | In scope (US-G01-G04) |
| Equipment management (trade, equip, persist) | Non-goal | In scope (US-E01-E05) |
| Lifelong companion persistence | Non-goal | In scope (US-P01-P04) |
| Death / soul wipe | Basic version only | Full version (US-D01-D03) |
| Re-recruitment after dismissal | Fresh start each time | Full state restore (US-RR01-RR03) |
| Companion-to-companion interaction | Non-goal | Still non-goal |
| Raid support | Non-goal | Still non-goal |

### Design Decision Review (Architect Assessment)

All 6 game-designer decisions have been reviewed against the EQEmu source code.

| # | Decision | Architect Verdict | Implementation Notes |
|---|----------|-------------------|---------------------|
| 1 | Linear stat scaling: `base * (current / recruited)` | APPROVED | **CRITICAL:** Must use floating-point division. Integer `15/10 = 1` (truncation). Correct: `(int)(base * (float)current / (float)recruited)` |
| 2 | Equipment persists on dismissal | APPROVED | Cascade delete on soul wipe is explicit (no FK constraints in EQEmu). DELETE companion_inventories, then companion_data. |
| 3 | Use item table race/class flags | APPROVED | Non-player race NPCs: use `GetPlayerRaceBit()`. If no mapping, only allow items with `races == 0` (All Races). Class 0 NPCs: map to class 1 (Warrior). |
| 4 | 50% XP share | APPROVED | Hook after `Group::SplitExp()` loop (exp.cpp:1182). `GetEXPForLevel()` is Client-only; companion needs own threshold calc: `(level-1)^3 * mod * 1000`. |
| 5 | player_level - 1, no absolute cap | APPROVED | 6.4x multiplier at extreme ranges (10→64). StatScalePct provides dampener. Document expected stat ranges for testers. |
| 6 | +10% re-recruitment bonus | APPROVED | Query: `companion_data WHERE owner_id=? AND npc_type_id=? AND is_dismissed=1`. Clean data flow. |

### New Data Model

#### Modified Table: `companion_data` (additional columns)

```sql
ALTER TABLE companion_data ADD COLUMN
  experience      BIGINT UNSIGNED NOT NULL DEFAULT 0,
  recruited_level TINYINT UNSIGNED NOT NULL DEFAULT 1,
  is_dismissed    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  total_kills     INT UNSIGNED NOT NULL DEFAULT 0,
  zones_visited   TEXT DEFAULT NULL,            -- JSON array of zone IDs
  time_active     INT UNSIGNED NOT NULL DEFAULT 0,  -- total seconds active
  times_died      SMALLINT UNSIGNED NOT NULL DEFAULT 0;
```

Note: `recruited_level` stores the NPC's original level at recruitment time and
never changes. It is the denominator in the scaling formula. `is_dismissed` tracks
voluntary dismissal state for re-recruitment detection.

#### New Table: `companion_inventories`

```sql
CREATE TABLE companion_inventories (
  companion_id    INT UNSIGNED NOT NULL,
  slot_id         MEDIUMINT UNSIGNED NOT NULL,
  item_id         INT UNSIGNED NOT NULL,
  charges         SMALLINT NOT NULL DEFAULT 0,
  color           INT UNSIGNED NOT NULL DEFAULT 0,
  augment_1       INT UNSIGNED NOT NULL DEFAULT 0,
  augment_2       INT UNSIGNED NOT NULL DEFAULT 0,
  augment_3       INT UNSIGNED NOT NULL DEFAULT 0,
  augment_4       INT UNSIGNED NOT NULL DEFAULT 0,
  augment_5       INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (companion_id, slot_id),
  INDEX idx_companion (companion_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
```

Mirrors `bot_inventories` table structure. Equipment slots use the standard
`EQ::invslot::EQUIPMENT_BEGIN` to `EQ::invslot::EQUIPMENT_END` range.

### New Code Changes

#### C++ Changes (expanded scope)

**Task 19: XP Tracking + Leveling System**

New methods added to `Companion` class:

```cpp
// zone/companion.h additions
uint64 GetExperience() const { return m_experience; }
uint8  GetRecruitedLevel() const { return m_recruited_level; }
void   AddExperience(uint64 xp);
void   LevelUp();
void   RecalculateStats();
static uint32 GetCompanionEXPForLevel(uint16 check_level);

// zone/companion.cpp implementation
void Companion::AddExperience(uint64 xp) {
    if (!IsAlive() || IsSuspended()) return;
    
    Client* owner = GetCompanionOwner();
    if (!owner) return;
    
    uint8 max_level = owner->GetLevel() - RuleI(Companions, MaxLevelOffset);
    if (GetLevel() >= max_level) return; // at cap, discard XP
    
    m_experience += xp;
    
    uint32 needed = GetCompanionEXPForLevel(GetLevel() + 1);
    while (m_experience >= needed && GetLevel() < max_level) {
        LevelUp();
        needed = GetCompanionEXPForLevel(GetLevel() + 1);
    }
}

void Companion::RecalculateStats() {
    float scale = (float)GetLevel() / (float)m_recruited_level;
    float pct = (float)RuleI(Companions, StatScalePct) / 100.0f;
    
    // Scale all base stats from original npc_types snapshot
    STR = (int)(m_base_stats.STR * scale * pct);
    STA = (int)(m_base_stats.STA * scale * pct);
    DEX = (int)(m_base_stats.DEX * scale * pct);
    // ... (all stats)
    
    // Add item bonuses on top
    CalcItemBonuses();
    
    // Recalculate max HP/mana
    max_hp = (int64)(m_base_stats.max_hp * scale * pct) + item_hp_bonus;
    max_mana = (int64)(m_base_stats.max_mana * scale * pct) + item_mana_bonus;
}
```

**Hook into `Group::SplitExp()`** (zone/exp.cpp, after line 1183):

```cpp
// After the client XP loop, award companion XP
for (const auto& m : members) {
    if (m && m->IsCompanion()) {
        Companion* comp = m->CastToCompanion();
        if (comp->IsAlive() && !comp->IsSuspended()) {
            uint64 comp_xp = group_experience / member_count;
            comp_xp = comp_xp * RuleI(Companions, XPSharePct) / 100;
            comp->AddExperience(comp_xp);
        }
    }
}
```

**Task 21: Equipment System**

```cpp
// zone/companion.h additions
void FinishTrade(Client* client);
void PerformTradeWithClient(int16 begin_slot, int16 end_slot, Client* client);
bool CanEquipItem(const EQ::ItemData* item, int16 slot);
void CalcItemBonuses();
void SendWearChange(int16 slot);
void SaveEquipment();
void LoadEquipment();
EQ::ItemInstance* GetEquippedItem(int16 slot);
void UnequipItem(int16 slot, Client* return_to);
```

Key implementation details:
- `CanEquipItem()` checks item `Classes` bitmask against companion class (map class 0
  to 1). Checks item `Races` bitmask via `GetPlayerRaceBit(GetRace())` — if race has
  no player mapping, only allow items with `Races == 0` (All Races).
- `FinishTrade()` adapted from `Bot::FinishTrade()`. Validates owner, checks combat
  state, processes each trade slot.
- `CalcItemBonuses()` sums stat contributions from all equipped items. Called by
  `RecalculateStats()`.
- `SendWearChange()` sends `OP_WearChange` for visual updates. Only works for
  `IsPlayerRace(GetRace())` models.

**Task 23: Re-recruitment Logic**

```cpp
// zone/companion.cpp additions
void Companion::Dismiss(bool voluntary) {
    if (voluntary) {
        // Save state with is_dismissed=1
        m_companion_data.is_dismissed = 1;
        Save();
        // Restore original NPC at spawn point
        RestoreOriginalNPC();
    }
    // Remove from group, despawn
    RemoveCompanionFromGroup(this);
    Depop();
}

// Static method for re-recruitment detection
static bool Companion::HasDismissedRecord(uint32 owner_id, uint32 npc_type_id) {
    // Query companion_data for matching dismissed record
    auto record = CompanionDataRepository::FindByOwnerAndNpcType(
        database, owner_id, npc_type_id, /*is_dismissed=*/1);
    return record.id > 0;
}

// Static method to restore a dismissed companion
static Companion* Companion::RestoreDismissed(Client* owner, uint32 npc_type_id) {
    auto record = CompanionDataRepository::FindByOwnerAndNpcType(
        database, owner->CharacterID(), npc_type_id, /*is_dismissed=*/1);
    if (record.id == 0) return nullptr;
    
    // Load NPCType from npc_types
    auto npc_type = content_db.LoadNPCTypesData(record.npc_type_id);
    if (!npc_type) return nullptr;
    
    // Create companion at stored level (not original DB level)
    auto comp = new Companion(npc_type, owner);
    comp->SetLevel(record.level);
    comp->m_experience = record.experience;
    comp->m_recruited_level = record.recruited_level;
    comp->RecalculateStats();
    comp->LoadEquipment();  // Restore gear from companion_inventories
    
    record.is_dismissed = 0;
    CompanionDataRepository::UpdateOne(database, record);
    
    return comp;
}
```

**Task 24: Soul Wipe**

```cpp
// zone/companion.cpp
void Companion::SoulWipe() {
    uint32 companion_id = GetCompanionDataID();
    uint32 npc_type_id = GetNPCTypeID();
    Client* owner = GetCompanionOwner();
    
    // Delete equipment
    CompanionInventoriesRepository::DeleteWhere(database,
        fmt::format("companion_id = {}", companion_id));
    
    // Delete buffs
    CompanionBuffsRepository::DeleteWhere(database,
        fmt::format("companion_id = {}", companion_id));
    
    // Delete companion data
    CompanionDataRepository::DeleteOne(database, companion_id);
    
    // Clear ChromaDB memories (via Lua -> LLM sidecar)
    if (owner) {
        // Signal Lua to clear ChromaDB for this npc_type_id + player_id
        std::string signal = fmt::format("companion_soul_wipe:{}:{}",
            npc_type_id, owner->CharacterID());
        // ... dispatch to Lua handler
    }
    
    // Restore original NPC
    RestoreOriginalNPC();
    
    // Despawn companion corpse
    // (corpse handles its own despawn timer)
}
```

### New Rules (expanded scope)

Added to the Companions rule category in `common/ruletypes.h`:

```cpp
RULE_INT(Companions, XPSharePct, 50, "Percentage of player XP share companions receive")
RULE_INT(Companions, MaxLevelOffset, 1, "Companion max level = player_level - this value")
RULE_INT(Companions, ReRecruitBonus, 10, "Bonus percentage on re-recruitment roll")
RULE_INT(Companions, DismissedRetentionDays, 30, "Days before dismissed companion data cleanup")
RULE_INT(Companions, CompanionSelfPreservePct, 10, "HP% threshold where companions disengage")
RULE_INT(Companions, MercSelfPreservePct, 20, "HP% threshold where mercenary-type companions disengage")
```

Total rules: 18 (original 12 + 6 new).

### Implementation Sequence (Tasks 19-24)

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 19 | Add XP tracking + leveling system to Companion class: `AddExperience()`, `LevelUp()`, `RecalculateStats()`, `GetCompanionEXPForLevel()`. Hook `Group::SplitExp()` in `zone/exp.cpp`. Add `experience`, `recruited_level` columns to `companion_data`. | c-expert | 6 | Medium (~400 lines C++) |
| 20 | Create `companion_inventories` table via migration manifest. Add `is_dismissed`, `total_kills`, `zones_visited`, `time_active`, `times_died` columns to `companion_data`. | data-expert | 2 | Small (~50 lines SQL) |
| 21 | Implement equipment system in Companion class: `FinishTrade()`, `PerformTradeWithClient()`, `CanEquipItem()`, `CalcItemBonuses()`, `SendWearChange()`, `SaveEquipment()`, `LoadEquipment()`, `UnequipItem()`. Adapted from Bot equipment system. | c-expert | 6, 20 | Large (~600 lines C++) |
| 22 | Add companion history tracking: update `total_kills` on kill, `zones_visited` on zone change, `time_active` on suspend. Feed history stats to LLM context. | c-expert | 6, 20 | Small (~100 lines C++) |
| 23 | Implement re-recruitment logic: `Dismiss()` with voluntary flag preserving companion_data, `HasDismissedRecord()` check, `RestoreDismissed()` factory method restoring full companion state (level, gear, memories). Update Lua recruitment module for re-recruitment detection and +10% bonus. | c-expert + lua-expert | 6, 14, 20, 21 | Medium (~300 lines C++, ~50 lines Lua) |
| 24 | Implement soul wipe on permanent death: `SoulWipe()` method that cascade-deletes companion_data, companion_inventories, companion_buffs, and signals Lua to clear ChromaDB memories. Timer-based trigger when resurrection window expires. | c-expert + lua-expert | 6, 20 | Medium (~200 lines C++, ~50 lines Lua) |

### Updated Dependency DAG (Tasks 1-24)

```
Phase 1 (Foundation — parallel):
  Rules (Task 1) ──────────┐
  Tables (Task 2) ─────────┤
  Exclusions (Task 3) ─────┤
  Culture (Task 4) ────────┤
  Spells (Task 5) ─────────┤
  Expanded tables (Task 20) ┤   ← NEW: companion_inventories + companion_data columns
                            │
Phase 2 (Core C++ — sequential):
                            ├──> Companion class (Task 6) ──┬──> AI (Task 7)
                            │                               ├──> Entity (Task 8)
                            │                               ├──> Client (Task 9)
                            │                               ├──> Groups (Task 10)
                            │                               ├──> ServerOP (Task 11)
                            │                               ├──> IsCompanion (Task 12)
                            │                               ├──> Migration (Task 13)
                            │                               ├──> XP/Leveling (Task 19) ← NEW
                            │                               ├──> Equipment (Task 21)  ← NEW (also depends on 20)
                            │                               ├──> History (Task 22)    ← NEW (also depends on 20)
                            │                               └──> Soul Wipe (Task 24)  ← NEW (also depends on 20)
                            │
Phase 3 (Lua + Integration):
                            │   Lua recruitment (Task 14) ──> Culture Lua (Task 15) ──> Global NPC (Task 16)
                            │   Lua API (Task 17) ──────────┘
                            │   Lua bindings (Task 18) ─────┘
                            │   Re-recruitment (Task 23) ← NEW (depends on 6, 14, 20, 21)
```

Phase 2 now includes Tasks 19-22, 24 (expanded scope C++ work) which can proceed
in parallel with Tasks 7-13 since they all depend on Task 6 but not on each other.

Task 23 (re-recruitment) is the only cross-phase dependency — it requires both the
C++ foundation (Task 6) AND the Lua recruitment module (Task 14) AND the equipment
system (Task 21).

### Updated Review Passes (Expanded Scope)

#### Pass 1 Addendum: Feasibility (Expanded Scope)

**XP/Leveling:** Feasible. `Group::SplitExp()` has a clean hook point after the client
XP loop (exp.cpp:1183). `GetEXPForLevel()` formula is pure math — easily replicated
as a static Companion method. Spell list refresh on level-up works because
`companion_spell_sets` is already level-ranged.

**Equipment:** Feasible. Bot's trade system (`Bot::PerformTradeWithClient()`, ~300 lines)
provides a complete template. The Titanium client's standard trade window works with
any NPC. Item race/class restriction checks use existing `GetPlayerRaceBit()` and
class bitmask infrastructure.

**Persistence/Re-recruitment:** Feasible. Adding `is_dismissed` flag to companion_data
is trivial. The restore-from-dismissed flow is a variation of the existing
unsuspend pattern.

**Soul Wipe:** Feasible. Cascade delete is explicit (no FK constraints in EQEmu).
ChromaDB clearing requires a Lua → LLM sidecar API call but the sidecar already
supports memory management.

**Resurrection of companion corpses:** NEEDS VERIFICATION. Standard resurrection spell
targeting may check `IsClientCorpse()`. Protocol-agent has been consulted. If NPC
corpses cannot be targeted by resurrection spells, the implementation will need to
either: (a) create companion corpses as a special corpse subtype that passes the
client corpse check, or (b) implement resurrection via a companion-specific say
command (e.g., "resurrect [companion name]") that bypasses the standard spell
targeting. See protocol-agent consultation below.

#### Pass 3 Addendum: Antagonistic (Expanded Scope)

9. **Exploit: Item duplication via companion trade.** Player trades item to companion,
   companion is soul-wiped, player has lost the item. This is INTENTIONAL per Decision 2.
   But: what if the server crashes between "item removed from player" and "item saved to
   companion_inventories"? Mitigation: the trade is atomic — `FinishTrade()` removes
   from player AND saves to companion in a single transaction. If either fails, neither
   completes (following Bot pattern).

10. **Exploit: Dismiss companion, get gear, re-recruit with gear intact.** Player gives
    companion valuable gear, dismisses, takes gear from another source, re-recruits to
    get the gear back. This is INTENDED — companion keeps their gear across dismissal.
    The player invested the gear; the companion owns it. Not an exploit.

11. **Stat scaling abuse: intentionally recruiting low-level NPCs for maximum scaling.**
    A level 5 NPC recruited at level 7 (player level) scaled to level 64 = 12.8x multiplier.
    But the NPC's base stats at level 5 are very low (e.g., STR 30), so 30 * 12.8 = 384.
    This is lower than a level 60 NPC's base STR (~200-400). The scaling formula is
    self-balancing: low-level NPCs have low base stats, high-level NPCs have high base stats.
    The multiplier inversely correlates with the base, producing convergent final values.

12. **Integer overflow in XP tracking.** Companion XP stored as BIGINT UNSIGNED (max
    18,446,744,073,709,551,615). Player XP for level 65 is ~274 million. Even with
    continuous XP gain, overflow is impossible.

13. **Dismissed companion database bloat.** With `DismissedRetentionDays = 30`, a cleanup
    job (cron or server-startup task) deletes dismissed companion records older than 30
    days that haven't been re-recruited. This prevents unbounded table growth.

### Updated Validation Plan (Expanded Scope)

#### Leveling
- [ ] Companions receive XP from group kills (50% of player share by default)
- [ ] Companion levels up when XP threshold is reached
- [ ] Stats scale correctly using linear formula with floating-point division
- [ ] Max HP and mana scale with level
- [ ] Spell list refreshes on level-up (new spells become available)
- [ ] Companion cannot exceed player_level - 1
- [ ] Excess XP is discarded when at level cap
- [ ] Level-up message sent to owner

#### Equipment
- [ ] Player can trade items to companion via standard trade window
- [ ] Equipment is validated against item race/class restrictions
- [ ] Non-player race companions can only equip All Races items
- [ ] Class 0 NPCs are treated as Warriors for equipment checks
- [ ] Equipment stat bonuses apply to companion stats
- [ ] Weapon items change companion damage/speed
- [ ] Visual appearance updates via OP_WearChange for player race models
- [ ] Equipment persists across zones, sessions, suspension
- [ ] Equipment persists across voluntary dismissal
- [ ] Equipment is destroyed on soul wipe
- [ ] Player can retrieve equipment via say commands ("give me your weapon")

#### Persistence / Re-recruitment
- [ ] Dismissed companions retain all data (level, gear, memories, history)
- [ ] Re-recruitment detects dismissed companion record
- [ ] Re-recruitment gets +10% bonus on roll
- [ ] Re-recruited companion spawns at stored level with stored gear
- [ ] History stats continue accumulating after re-recruitment
- [ ] ChromaDB memories persist across dismissal (already the case)
- [ ] Dismissed companion records are cleaned up after 30 days

#### Death / Soul Wipe
- [ ] Companion death creates a corpse
- [ ] Resurrection spells work on companion corpses (within 30-minute window)
- [ ] Resurrection restores companion with full state
- [ ] Soul wipe triggers after resurrection timer expires
- [ ] Soul wipe deletes companion_data, companion_inventories, companion_buffs
- [ ] Soul wipe clears ChromaDB memories for this NPC+player
- [ ] Original NPC respawns at home post after soul wipe
- [ ] Soul-wiped NPC is a stranger on re-recruitment (no bonus, no progress)

### Updated Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | 1, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, **19, 21, 22, 23, 24** | Core C++ + expanded scope: leveling, equipment, persistence, soul wipe |
| data-expert | 2, 3, 4, 5, **20** | Database tables, seed data, expanded schema |
| lua-expert | 14, 15, 16, **23, 24** | Recruitment logic, re-recruitment Lua support, ChromaDB soul wipe signal |

**Revised totals:**
- c-expert: 16 tasks (was 11)
- data-expert: 5 tasks (was 4)
- lua-expert: 5 tasks (was 3), with Tasks 23 and 24 shared with c-expert

**Estimated additional C++ scope:** ~1,600 lines
**Estimated additional SQL scope:** ~70 lines
**Estimated additional Lua scope:** ~100 lines

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above: **c-expert**, **data-expert**, **lua-expert**.
> They will coordinate via `SendMessage` and work through the task list in
> dependency order, starting with the parallel Phase 1 tasks (including the
> new Task 20 for expanded schema).
