# EQEmu C++ Codebase Topography

## Summary

The EQEmu server is a C++20 EverQuest emulator structured around multiple cooperating executables: **world** (central coordinator), **zone** (one per loaded zone, handles all gameplay), **loginserver** (authentication), **shared_memory** (pre-computes item/spell data), **ucs** (chat), **queryserv** (logging), and **eqlaunch** (process supervisor). The `zone/` directory contains approximately 70% of the code and nearly all gameplay logic. The `common/` directory provides shared libraries used by all binaries, including database access, networking, packet structures, and the rule system.

All paths below are relative to `eqemu/`.

---

## 1. Top-Level Directory Structure

| Directory | Role |
|---|---|
| `zone/` | All gameplay logic: combat, spells, AI, items, quests, scripting. ~116 headers, ~161 source files. The largest directory by far. |
| `common/` | Shared library linked by all executables. Database, networking, packet structs, rules, item/spell data definitions, logging, repositories (ORM). |
| `world/` | World server: zone coordination, login server communication, client routing, guild management, adventure system. |
| `loginserver/` | Authentication server: account management, world server registration, encryption. |
| `shared_memory/` | Offline tool that loads item/spell data from the database into memory-mapped files for fast runtime access. |
| `ucs/` | Universal Chat Service: in-game chat channels, mail. |
| `queryserv/` | Query server: player event logging, LFGuild, zone tracking. |
| `eqlaunch/` | Process launcher: starts and monitors zone processes on behalf of world. |
| `libs/` | Binding libraries: `luabind/` (Lua C++ bindings) and `perlbind/` (Perl C++ bindings). |
| `cmake/` | CMake modules (e.g., `FindLuaJit.cmake`). |
| `common/repositories/` | Auto-generated ORM layer: ~254 repository files mapping directly to database tables. |
| `common/patches/` | Client version adapters: translates internal structs to/from each client format (Titanium, SoF, SoD, UF, RoF, RoF2). |
| `common/net/` | Low-level networking: EQ UDP stream, TCP connections, server-to-server talk, WebSocket server. |
| `submodules/` | Git submodules, primarily `vcpkg` for dependency management. |
| `tests/` | Unit/integration tests. |
| `client_files/` | Tools for importing/exporting client data files. |
| `build/` | Build output directory. |
| `dependencies/` | Legacy dependency support. |

---

## 2. Server Binaries

### zone (the gameplay engine)
- **Entry:** `zone/main.cpp`
- One instance per loaded zone. Handles all in-zone gameplay: combat, spells, NPC AI, loot, quests, movement.
- Creates the global `entity_list` (all entities in the zone) and connects to `world` via `WorldServer` (TCP).
- Boots a zone either statically (named zone) or dynamically (on demand from world).
- Main loop calls `Zone::Process()` which ticks all entities, timers, spawns, and weather.

### world (the coordinator)
- **Entry:** `world/main.cpp`
- Single instance. Central hub that routes players between zones, manages guilds, groups, raids across zones.
- Maintains `ClientList` (all connected players), `ZoneList` (all running zone processes), `LoginServerList`.
- Handles inter-zone communication via `ServerOP_*` opcodes defined in `common/servertalk.h`.
- Runs the adventure manager, shared task manager, dynamic zone manager, and event scheduler.

### loginserver (authentication)
- **Entry:** `loginserver/main.cpp`
- Handles player login, account creation, server selection.
- Communicates with world servers to relay authenticated clients.
- Supports local DB or EQEmu login server network.

### shared_memory (data preloader)
- **Entry:** `shared_memory/main.cpp`
- Runs once at startup before zone processes. Loads items and spells from the database into memory-mapped files (`shared/items.bin`, `shared/spells.bin`) that zone processes map into their address space for fast, zero-copy access.
- Key files: `shared_memory/items.cpp`, `shared_memory/spells.cpp`.

### ucs (Universal Chat Service)
- **Entry:** `ucs/ucs.cpp`
- Handles in-game chat channels and cross-zone mail.
- Connects to world for player presence information.

### queryserv (query/logging server)
- **Entry:** `queryserv/queryserv.cpp`
- Receives player event data from zones for logging and analytics.
- Handles LFGuild functionality.

### eqlaunch (process supervisor)
- **Entry:** `eqlaunch/eqlaunch.cpp`
- Named launcher process that starts zone processes as directed by world.
- Monitors child processes and restarts them if they crash.
- Communicates with world via `eqlaunch/worldserver.cpp`.

---

## 3. Key Subsystems

### 3.1 Entity Hierarchy (the class backbone)

The entire gameplay object model is built on a single inheritance chain:

```
Entity                    -- base: has ID, type-checking virtuals (IsClient, IsNPC, etc.)
  +-- Mob                 -- anything that moves/fights: stats, combat, spells, buffs, position
       +-- Client         -- player character: inventory, quests, packet handling, AA, exp
       +-- NPC            -- server-controlled mob: AI, spawn data, loot tables, merchants
       |    +-- Pet       -- summoned/charmed pets (thin subclass of NPC)
       |    +-- Merc      -- mercenaries: hire/fire, stances, AI spell casting
       |    +-- Bot       -- player-controlled bot companions: persistent DB storage, spell AI, raid support
       |    +-- Aura      -- aura effects emanating from a mob
       +-- Corpse         -- dead mob/player: loot, resurrection, decay
  +-- Object             -- world objects: forges, ground spawns
  +-- Doors              -- clickable doors, teleporters
  +-- Trap               -- proximity traps
  +-- Beacon             -- invisible spell-effect markers
  +-- Encounter          -- scripted encounter containers
```

The `EntityList` class (global `entity_list`) manages all entities in a zone using typed maps:

```cpp
// zone/entity.h
std::map<uint16, Client *>  client_list;
std::map<uint16, NPC *>     npc_list;
std::map<uint16, Merc *>    merc_list;
std::map<uint16, Corpse *>  corpse_list;
std::map<uint16, Object *>  object_list;
std::map<uint16, Doors *>   door_list;
// ... etc.
```

**Key files:**
- `zone/entity.h` -- `Entity` base class and `EntityList` container
- `zone/mob.h` -- `Mob` class (~1950 lines), the central gameplay class
- `zone/client.h` -- `Client` class (player)
- `zone/npc.h` -- `NPC` class
- `zone/bot.h` -- `Bot` class (~1264 lines)
- `zone/merc.h` -- `Merc` class

### 3.2 Combat System

Combat is primarily implemented in `zone/attack.cpp` (~7030 lines) with supporting logic spread across `Mob` methods.

**Attack flow:**
1. `Mob::Attack()` -- entry point, determines weapon skill, animation
2. `Mob::DoAttack()` -- rolls hit/miss, applies damage
3. `Mob::CheckHitChance()` -- to-hit vs defense calculation
4. `Mob::AvoidDamage()` -- dodge, parry, riposte, block checks
5. `Mob::MeleeMitigation()` -- AC-based damage reduction
6. `Mob::TryCriticalHit()` -- critical hit/crippling blow rolls
7. `Mob::CommonOutgoingHitSuccess()` -- final damage mods, procs, damage shields

**Special attacks:**
- `Mob::TryBackstab()`, `Mob::RogueBackstab()`, `Mob::RogueAssassinate()`
- `Mob::MonkSpecialAttack()` (flying kick, dragon punch, etc.)
- `Mob::TryHeadShot()`, `Mob::TryAssassinate()`, `Mob::TryFinishingBlow()`
- `Mob::DoMainHandAttackRounds()`, `Mob::DoOffHandAttackRounds()` -- multi-attack logic

**Key structs:**
```cpp
// zone/common.h
struct DamageHitInfo {
    int base_damage;
    int min_damage;
    int damage_done;
    int offense;
    int tohit;
    int hand;      // primary or secondary
    EQ::skills::SkillType skill;
};
```

**Key files:**
- `zone/attack.cpp` -- melee attack logic, damage calculation
- `zone/special_attacks.cpp` -- rampage, flurry, special abilities
- `zone/bonuses.cpp` (~5905 lines) -- stat bonus calculations from gear, spells, AAs
- `zone/tune.cpp` -- tuning/testing combat formulas

### 3.3 Spell System

Spells are one of the most complex subsystems. The casting flow is well-documented at the top of `zone/spells.cpp`:

```
Client clicks spell -> CastSpell()
  -> (if cast time) set timer, SpellProcess() watches it
  -> CastedSpellFinished() -- checks interrupts, movement
    -> SpellFinished() -- LoS, reagents, target validation
      -> SpellOnTarget() -- single target
      -> AESpell() -- area effect
      -> CastGroupSpell() -- group spells
        -> SpellEffect() -- applies individual spell effects
```

**Spell data:** The `SPDat_Spell_Struct` (defined in `common/spdat.h`, ~1919 lines) holds all spell parameters loaded from the database. Each spell has up to 12 effect slots, each with a formula, base value, limit, and max value.

**Key files:**
- `zone/spells.cpp` (~7530 lines) -- casting pipeline, resist checks, buff management
- `zone/spell_effects.cpp` (~10709 lines) -- `Mob::SpellEffect()`, giant switch on spell effect IDs
- `zone/effects.cpp` -- buff tick processing
- `zone/bonuses.cpp` -- how spell buffs affect stats
- `common/spdat.h` -- spell data structure, spell ID constants

### 3.4 AI and NPC Behavior

NPC AI is driven by `NPC::Process()` which calls `Mob::AI_Process()` on each tick.

**AI states:**
- **Idle:** patrol waypoints, check for aggro targets
- **Engaged:** cast spells, pursue target, perform melee
- **Pursuing:** chase fleeing target

**Aggro system:**
- `zone/aggro.cpp` -- aggro detection, faction checks, assist calls
- `zone/aggromanager.h` -- `AggroManager` tracks aggro proximity scanning
- `zone/hate_list.h/cpp` -- `HateList` class: manages who an NPC is fighting and hate amounts

```cpp
struct struct_HateList {
    Mob    *entity_on_hatelist;
    int64  hatelist_damage;
    int64  stored_hate_amount;
    bool   is_entity_frenzy;
    int8   oor_count;       // out-of-range tracking
    uint32 last_modified;
};
```

**NPC Spell AI:**
- `zone/mob_ai.cpp` -- `NPC::AICastSpell()`, spell selection logic
- `zone/npc.h` -- `AISpells_Struct`: per-NPC spell list with type, priority, recast, HP thresholds
- NPC spells come from `npc_spells` and `npc_spells_entries` database tables

**Pathing:**
- `zone/pathfinder_interface.h` -- abstract pathing interface
- `zone/pathfinder_nav_mesh.h/cpp` -- RecastNavigation-based navmesh pathfinding
- `zone/pathfinder_waypoint.h/cpp` -- legacy waypoint-based grid pathing
- `zone/mob_movement_manager.h/cpp` -- coordinates movement across pathing systems
- `zone/waypoints.cpp` -- waypoint grid processing
- `zone/fearpath.cpp` -- flee/fear path logic

### 3.5 Bot and Mercenary Systems

**Bots** (`zone/bot.h`, `zone/bot.cpp` ~13464 lines):
- `Bot` inherits from `NPC` (which inherits from `Mob`)
- Persistent: stored in database tables (`bot_data`, `bot_inventories`, `bot_buffs`, etc.)
- Full class/race/level system mirroring players
- Own spell AI in `zone/botspellsai.cpp` (~2886 lines)
- Configurable settings via `BotSettingCategories` namespace
- Support groups and raids (`zone/bot_raid.cpp`)
- Commands via `zone/bot_command.h/cpp`
- Database access via `zone/bot_database.h/cpp`
- Heal rotation system: `zone/heal_rotation.h/cpp`

**Mercenaries** (`zone/merc.h`, `zone/merc.cpp` ~5922 lines):
- `Merc` inherits from `NPC`
- Four roles: Tank (1), Healer (2), MeleeDPS (9), CasterDPS (12)
- Simpler than bots: template-based, not fully persistent
- Own spell AI: `Merc::AICastSpell()`, `Merc::AI_EngagedCastCheck()`

### 3.6 Item System

**Item data model:**
- `common/item_data.h` -- `EQ::ItemData` struct: all static item properties from the database
- `common/item_instance.h` -- `EQ::ItemInstance`: a specific instance of an item with charges, augments, custom data
- `common/inventory_profile.h` -- `EQ::InventoryProfile`: full character inventory with slot management
- `common/loot.h` -- `LootItem` struct: items on corpses/NPCs

**Inventory slots** are defined by constants in `common/emu_constants.h` (worn, personal, bank, shared bank, cursor, etc.).

**Loot system:**
- `zone/loot.cpp` -- `NPC::AddLootTable()`: loads loot from `loottable` -> `lootdrop` -> `lootdrop_entries` chain
- `zone/zone_loot.cpp` -- zone-level loot table caching
- `zone/global_loot_manager.h/cpp` -- global loot rules applied to all NPCs

**Tradeskills:** `zone/tradeskills.cpp` -- recipe validation, combine logic, skill-ups.

**Key files:**
- `zone/inventory.cpp` -- client inventory manipulation
- `zone/trading.cpp` -- player-to-player and NPC trading
- `zone/parcels.cpp` -- parcel/mail item system

### 3.7 Zone Management

**Zone lifecycle:**
1. World tells eqlaunch to start a zone process
2. `zone/main.cpp` connects to world, receives zone assignment
3. `Zone::Bootup()` loads zone data (spawns, doors, objects, grids, loot tables)
4. `Zone::Init()` initializes pathfinding (navmesh/waypoints), weather, event scheduler
5. `Zone::Process()` runs the main game loop tick

**Key classes:**
- `zone/zone.h` -- `Zone` class: zone state, settings, spawn management, blocked spells
- `zone/spawn2.h` -- `Spawn2`: individual spawn point with respawn timer and conditions
- `zone/spawngroup.h` -- `SpawnGroup`: group of NPC types that can spawn at a point
- `zone/map.h` -- `Map`: BSP collision/LoS data loaded from `.map` files
- `zone/water_map.h` -- `WaterMap`: underwater region detection

**Zone-to-world communication:** `zone/worldserver.h/cpp` wraps a TCP connection using `ServerOP_*` opcodes from `common/servertalk.h`.

**World-side zone management:**
- `world/zonelist.h/cpp` -- tracks all running zone processes
- `world/zoneserver.h/cpp` -- represents a single zone process connection

### 3.8 Player Systems

**Experience:** `zone/exp.cpp` -- XP gain, group/raid splitting, con-based scaling, AA XP.

**Alternate Advancement (AA):**
- `zone/aa.h/cpp` -- AA purchase, activation, cooldowns
- `zone/aa_ability.h` -- `AA::Ability` and `AA::Rank` classes
- Database tables: `aa_ability`, `aa_ranks`, `aa_rank_effects`

**Skills:** `common/skills.h` -- `EQ::skills::SkillType` enum (77 skills from 1HBlunt to Frenzy).

**Faction:**
- `common/faction.h` -- `FACTION_VALUE` enum, `NPCFactionList` struct
- `zone/zone_npc_factions.cpp` -- faction check and modification logic
- Faction values range from ALLY (1) to SCOWLS (9)

**Groups/Raids:**
- `zone/groups.h/cpp` -- `Group` class: XP sharing, leadership
- `zone/raids.h/cpp` -- `Raid` class: multi-group coordination

### 3.9 Networking and Packet Handling

**Architecture:**
- Clients communicate via a custom UDP protocol (EQ's original protocol)
- Zone processes and world communicate via TCP (`ServerPacket` with `ServerOP_*` opcodes)
- Login server uses its own protocol

**Client packet flow:**
1. `common/net/eqstream.h/cpp` -- UDP stream management, sequencing, ack/nak, fragmentation
2. `common/eq_stream_ident.h` -- identifies client version from initial handshake
3. `common/patches/*.cpp` -- translates between internal structs and client-version-specific wire formats
4. `zone/client_packet.cpp` (~17356 lines) -- handles every client opcode, the main packet dispatch

**Supported client versions** (via patches):
- Titanium (`common/patches/titanium.*`)
- Secrets of Faydwer (SoF) (`common/patches/sof.*`)
- Seeds of Destruction (SoD) (`common/patches/sod.*`)
- Underfoot (UF) (`common/patches/uf.*`)
- Rain of Fear (RoF) (`common/patches/rof.*`)
- Rain of Fear 2 (RoF2) (`common/patches/rof2.*`)

**Opcodes:**
- `common/emu_opcodes.h` -- internal opcode enumeration
- `common/patches/*_ops.h` -- per-client opcode mapping files
- `common/eq_packet_structs.h` (~6566 lines) -- wire-format struct definitions

**Server-to-server:**
- `common/servertalk.h` (~1783 lines) -- `ServerOP_*` opcode defines and inter-server packet structures
- `common/net/servertalk_client_connection.h/cpp` -- zone-to-world TCP connection
- `common/net/servertalk_server.h/cpp` -- world-side TCP listener

### 3.10 Database Layer

**Hierarchy:**
```
DBcore                  -- raw MySQL/MariaDB connection, query execution
  +-- Database          -- common queries (accounts, characters, variables)
       +-- SharedDatabase  -- item/spell loading, shared between world/zone
            +-- ZoneDatabase   -- zone-specific queries (spawns, loot, doors, grids)
            +-- WorldDatabase  -- world-specific queries
```

**Key files:**
- `common/dbcore.h` -- `DBcore`: MySQL connection wrapper, `QueryDatabase()`, transactions
- `common/database.h` -- `Database`: account management, character creation
- `common/shareddb.h` -- `SharedDatabase`: item/spell shared memory, inventory persistence
- `zone/zonedb.h` -- `ZoneDatabase`: NPC types, spawn groups, loot tables, grids, doors

**Repository pattern (ORM):**
The `common/repositories/` directory contains ~254 auto-generated repository files, one per database table. Each provides CRUD operations:

```cpp
// Example: common/repositories/npc_types_repository.h extends base
class NpcTypesRepository : public BaseNpcTypesRepository {
    // Custom queries go here
};

// Base provides: FindAll(), FindOne(), InsertOne(), UpdateOne(), DeleteOne(), etc.
// Generated by: utils/scripts/generators/repository-generator.pl
```

The `base/` subdirectory contains auto-generated files -- never edit these. Custom queries go in the parent repository file.

**SQL helper macro:**
```cpp
#define SQL(...) #__VA_ARGS__
// Usage: auto results = database.QueryDatabase(SQL(SELECT * FROM npc_types WHERE id = 1));
```

### 3.11 Scripting Interface (Perl/Lua)

The scripting system allows quest/event logic to be written in Perl or Lua (or both simultaneously).

**Architecture:**
```
QuestInterface (abstract)          -- zone/quest_interface.h
  +-- PerlembParser                -- zone/embparser.h (Perl implementation)
  +-- LuaParser                   -- zone/lua_parser.h (Lua implementation)

QuestParserCollection              -- zone/quest_parser_collection.h
  - Manages both parsers
  - Routes events to the correct parser based on file extension (.pl or .lua)
  - Dispatches events: EventNPC, EventPlayer, EventItem, EventSpell, EventBot, EventMerc, EventZone
```

**Event system:** `zone/event_codes.h` defines ~100+ event types (`EVENT_SAY`, `EVENT_DEATH`, `EVENT_SPAWN`, `EVENT_TIMER`, `EVENT_COMBAT`, etc.).

**Lua bindings** expose C++ classes to Lua scripts via wrapper classes:
- `zone/lua_mob.h/cpp` -- Lua API for `Mob` methods
- `zone/lua_client.h/cpp` -- Lua API for `Client` methods
- `zone/lua_npc.h/cpp` -- Lua API for `NPC` methods
- `zone/lua_bot.h/cpp` -- Lua API for `Bot` methods
- `zone/lua_entity_list.h/cpp` -- Lua API for `EntityList`
- `zone/lua_general.h/cpp` -- global quest functions
- `zone/lua_zone.h/cpp`, `zone/lua_group.h/cpp`, `zone/lua_raid.h/cpp`, etc.

**Perl bindings** follow the same pattern:
- `zone/perl_mob.cpp`, `zone/perl_client.cpp`, `zone/perl_npc.cpp`, etc.
- `zone/embparser_api.cpp` -- registers Perl API functions

**Lua Mods** (`zone/lua_mod.h/cpp`): A special system that lets Lua scripts override core C++ combat/damage formulas:
```cpp
// zone/lua_mod.h
void MeleeMitigation(Mob *self, Mob *attacker, DamageHitInfo &hit, ...);
void TryCriticalHit(Mob *self, Mob *defender, DamageHitInfo &hit, ...);
void CommonOutgoingHitSuccess(Mob *self, Mob* other, DamageHitInfo &hit, ...);
// etc.
```

---

## 4. Code Patterns

### 4.1 Entity List Pattern
All game entities live in the global `entity_list` (type `EntityList`). Code commonly iterates over specific entity types:
```cpp
auto &mob_list = entity_list.GetMobList();
for (auto &[id, mob] : mob_list) {
    if (mob->IsClient()) { /* ... */ }
}
```

### 4.2 Timer Pattern
The `Timer` class (`common/timer.h`) is used pervasively for timed events:
```cpp
Timer my_timer(5000);  // 5 seconds
// in Process():
if (my_timer.Check()) {
    // timer fired, do work
}
```

### 4.3 Rule System
Server behavior is configured via ~1186 lines of rule definitions in `common/ruletypes.h`, organized into ~47 categories (Character, Combat, Spells, NPC, Bots, etc.). Rules are accessed via macros:
```cpp
RuleI(Character, MaxLevel)      // integer rule
RuleR(Combat, MeleeBaseCritChance)  // float rule
RuleB(Bots, Enabled)            // boolean rule
RuleS(World, LoginHost)         // string rule
```

Rules are stored in the `rule_values` database table and loaded at startup. They can be changed at runtime via GM commands.

### 4.4 Server Opcodes (Inter-Process Communication)
Zone-to-world communication uses `ServerOP_*` constants defined in `common/servertalk.h`. A zone sends a `ServerPacket` with an opcode and serialized data struct:
```cpp
auto pack = new ServerPacket(ServerOP_ZonePlayer, sizeof(ServerZonePlayer_Struct));
auto szp = (ServerZonePlayer_Struct *)pack->pBuffer;
// fill in szp fields...
worldserver.SendPacket(pack);
```

### 4.5 Repository/ORM Pattern
Database access for CRUD operations uses the repository pattern:
```cpp
auto npc = NpcTypesRepository::FindOne(database, npc_id);
npc.name = "New Name";
NpcTypesRepository::UpdateOne(database, npc);
```

### 4.6 CastTo Pattern
Type narrowing from `Entity*` or `Mob*` to specific types:
```cpp
if (target->IsClient()) {
    Client *c = target->CastToClient();
    c->Message(Chat::White, "Hello");
}
```

### 4.7 Content Filtering
The `WorldContentService` (`common/content/world_content_service.h`) filters database content by expansion era:
```cpp
// Expansion enum: Classic=0, Kunark=1, Velious=2, Luclin=3, ...
```
Spawn entries, items, and quests can be filtered by `min_expansion`/`max_expansion` and content flags.

### 4.8 Logging System
`common/eqemu_logsys.h` provides categorized logging:
```cpp
LogInfo("Zone [{}] booted", zone_name);
LogCombat("Damage dealt: [{}]", damage);
Log(Logs::Detail, Logs::AI, "NPC thinking...");
```
Categories include: AA, AI, Aggro, Attack, Combat, Doors, Loot, Pathing, Quests, Spells, Trading, and many more.

---

## 5. Build System

### CMake Structure
- **Root** `CMakeLists.txt`: Sets C++20, finds dependencies via vcpkg, adds subdirectories
- `common/CMakeLists.txt`: Builds `common` static library
- `zone/CMakeLists.txt`: Builds `zone` executable, links common + libs
- `world/CMakeLists.txt`: Builds `world` executable
- Similarly for `loginserver/`, `shared_memory/`, `ucs/`, `queryserv/`, `eqlaunch/`
- `libs/CMakeLists.txt`: Builds `luabind` and `perlbind` libraries

### Dependencies (via vcpkg)
| Dependency | Purpose |
|---|---|
| MariaDB (libmariadb) | Database connectivity |
| Boost | Dynamic bitset, foreach, tuple utilities |
| fmt | String formatting |
| glm | 3D math (vec3/vec4 for positions) |
| cereal | Binary serialization (server-to-server packets) |
| LuaJIT | Lua scripting engine |
| Perl | Perl scripting engine |
| OpenSSL | TLS/encryption |
| RecastNavigation | Navmesh pathfinding |
| zlib | Compression |
| libuv | Async I/O event loop |
| libsodium | Cryptography |

### Build Options
```cmake
EQEMU_BUILD_SERVER    # ON  -- world, zone, shared_memory, ucs, queryserv, eqlaunch
EQEMU_BUILD_LOGIN     # ON  -- loginserver
EQEMU_BUILD_PERL      # ON  -- Perl scripting (if Perl found)
EQEMU_BUILD_LUA       # ON  -- Lua scripting
EQEMU_BUILD_TESTS     # OFF -- unit tests
EQEMU_BUILD_CLIENT_FILES  # ON -- import/export tools
```

---

## 6. Rule System (Detail)

Rules are the primary way to configure server behavior without code changes. They are defined in `common/ruletypes.h` using X-macros that generate both enum values and storage:

```cpp
// common/ruletypes.h
RULE_CATEGORY(Combat)
RULE_INT(Combat, MinDamageMod, 100, "Minimum damage modifier for melee")
RULE_REAL(Combat, MeleeBaseCritChance, 0.0, "Base crit chance for melee")
RULE_BOOL(Combat, UseIntervalAC, true, "Whether to use interval AC")
RULE_CATEGORY_END()
```

**Categories** (47 total): Character, Mercs, Guild, Skills, Pets, GM, World, Zone, Map, Pathing, Watermap, Spells, Combat, NPC, Aggro, TaskSystem, Range, Bots, Chat, Merchant, Bazaar, Mail, Channels, EventLog, Adventure, AA, Console, Network, QueryServ, Inventory, Client, Bugs, Faction, Analytics, Logging, HotReload, Expansion, Instances, Expedition, DynamicZone, Cheat, Command, Doors, Items, Parcel, EvolvingItems.

**Access pattern:**
```cpp
// common/rulesys.h
#define RuleI(category, rule) RuleManager::Instance()->GetIntRule(RuleManager::Int__##rule)
#define RuleR(category, rule) RuleManager::Instance()->GetRealRule(RuleManager::Real__##rule)
#define RuleB(category, rule) RuleManager::Instance()->GetBoolRule(RuleManager::Bool__##rule)
```

---

## 7. Extension Points

### 7.1 Quest Events
The primary extension point. Add handlers in Lua or Perl scripts for any of the ~100+ events in `zone/event_codes.h`:
- Per-NPC scripts: `quests/zone_shortname/npc_id.pl` or `.lua`
- Global NPC scripts: `quests/global/global_npc.pl`
- Player scripts: `quests/global/player.pl`
- Item scripts, spell scripts, zone scripts, bot scripts, merc scripts

### 7.2 GM Commands
Add new commands in `zone/command.cpp` via `command_add()`:
```cpp
command_add("mycommand", "[usage]", AccountStatus::GMAdmin, command_mycommand);
```
Then implement `void command_mycommand(Client *c, const Seperator *sep)` in a command file.

### 7.3 Bot Commands
Similar to GM commands but prefixed with `^`: `zone/bot_command.h/cpp`.

### 7.4 Rule Values
Add new rules in `common/ruletypes.h` under the appropriate category. They automatically become available via `RuleI/RuleR/RuleB/RuleS` macros and the `#rules` GM command.

### 7.5 Lua Mods (Combat Formula Overrides)
`zone/lua_mod.h` exposes hooks to override core combat calculations from Lua:
- `MeleeMitigation`, `ApplyDamageTable`, `AvoidDamage`, `CheckHitChance`
- `TryCriticalHit`, `CommonOutgoingHitSuccess`
- `GetExperienceForKill`, `CalcSpellEffectValue_formula`
- `CommonDamage`, `HealDamage`, `SetEXP`, `SetAAEXP`

### 7.6 Server Opcodes
For new inter-process features, add `ServerOP_*` defines in `common/servertalk.h` and handle them in the appropriate `HandleMessage()` methods.

### 7.7 Database Repositories
Add new tables by creating repository files. The generator script (`utils/scripts/generators/repository-generator.pl`) auto-generates base repositories; custom queries go in the non-base file.

### 7.8 Data Buckets
`common/data_bucket.h` provides arbitrary key-value storage scoped to account, character, NPC, bot, or zone -- useful for quest state without modifying schemas.

---

## 8. Key Files -- Reading Order for New Developers

### Phase 1: Understand the Architecture
1. **`CMakeLists.txt`** (root) -- what gets built and what depends on what
2. **`zone/main.cpp`** -- zone process startup, global objects, main loop
3. **`world/main.cpp`** -- world process startup (first 100 lines)
4. **`zone/entity.h`** -- `Entity` base class and `EntityList` (the backbone)

### Phase 2: Understand the Entity Model
5. **`zone/mob.h`** -- skim the `Mob` class methods (attack, spell, movement, stats)
6. **`zone/npc.h`** (first 180 lines) -- NPC-specific: AI, spawn, loot
7. **`zone/client.h`** (first 100 lines) -- Client-specific: inventory, packets
8. **`zone/bot.h`** (lines 230-400) -- Bot class declaration

### Phase 3: Understand Key Systems
9. **`common/rulesys.h`** + **`common/ruletypes.h`** (first 100 lines) -- the rule system
10. **`zone/spells.cpp`** (first 80 lines) -- read the spell casting flow comment
11. **`zone/attack.cpp`** (first 100 lines) -- combat entry point
12. **`zone/mob_ai.cpp`** (first 80 lines) -- NPC AI spell casting
13. **`zone/quest_interface.h`** -- scripting API contract
14. **`zone/event_codes.h`** -- all quest event types

### Phase 4: Understand Data Flow
15. **`common/dbcore.h`** -- database connection interface
16. **`common/database.h`** / **`common/shareddb.h`** -- database hierarchy
17. **`common/repositories/base/base_npc_types_repository.h`** -- example ORM repository
18. **`common/servertalk.h`** (first 80 lines) -- inter-server communication opcodes
19. **`common/eq_packet_structs.h`** (first 60 lines) -- client packet structures

### Phase 5: For the Companion System (Bot-Specific)
20. **`zone/bot.h`** -- full Bot class, settings, spell config
21. **`zone/botspellsai.cpp`** -- bot spell casting AI
22. **`zone/bot_command.h/cpp`** -- bot player commands
23. **`zone/bot_database.h/cpp`** -- bot persistence
24. **`zone/heal_rotation.h/cpp`** -- coordinated healing
25. **`zone/merc.h/cpp`** -- mercenary system (simpler companion reference)
