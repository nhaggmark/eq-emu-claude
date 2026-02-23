# Lua Code Topography

## Summary

Lua is the **primary quest scripting language** in the EQEmu server, used alongside Perl. In
this project's quest repository, Lua scripts outnumber Perl scripts (~4,209 Lua vs ~3,790 Perl).
Lua was registered with higher load precedence -- the server tries `.lua` files **before** `.pl`
files when resolving which script to execute for a given NPC, player, item, spell, or zone event.

The Lua integration uses **LuaJIT 2.1** (via vcpkg) with **luabind** for C++ binding. The
entire quest API surface (entity manipulation, spawning, tasks, instances, factions, items,
timers, encounters, database access, etc.) is exposed through the `eq.*` namespace and
object methods on bound C++ classes.

---

## Lua vs Perl Comparison

### At a Glance

| Aspect | Lua | Perl |
|---|---|---|
| File extension | `.lua` | `.pl` |
| Script count | ~4,209 | ~3,790 |
| Zone coverage | ~313 directories | ~200 directories |
| Load priority | **First** (higher precedence) | Second |
| Registration | `main.cpp:433` | `main.cpp:438` |
| Runtime | LuaJIT 2.1 (embedded) | Embedded Perl (PerlembParser) |
| Global functions | `eq.*` namespace | `quest::*` functions |
| Event handler syntax | `function event_say(e)` | `sub EVENT_SAY { }` |
| Entity references | `e.self`, `e.other` | `$npc`, `$client`, `$mob` |
| Module system | `require("items")` from `lua_modules/` | `use` / `plugin::` from `plugins/` |
| String matching | `e.message:findi("hail")` | `$text =~ /hail/i` |
| Shared modules dir | `quests/lua_modules/` (23 files) | `quests/plugins/` (~20+ files) |
| Init script | `global/script_init.lua` | (none equivalent) |
| Encounter system | Native (Lua-only feature) | Not available |
| Mod system (hooks) | `lua_mod.cpp` -- combat/XP hooks | Not available |
| Database access | `Lua_Database` class with prepared statements | `plugin::MySQL` |

### Priority Resolution

When the server needs to execute a quest script, it iterates through `_load_precedence`
(Lua first, Perl second) for each candidate filename. **The first matching file wins.** This
means if both `NPC_Name.lua` and `NPC_Name.pl` exist, the `.lua` file is used exclusively.

In practice, the PEQ quest repository has been migrated largely to Lua. Most zones contain only
Lua scripts. The remaining Perl scripts tend to be in zones or for NPCs that haven't been
converted yet, or in the global player script (`global/global_player.pl`) which runs alongside
its Lua counterpart.

### Syntax Comparison: Same Quest in Both Languages

**Lua** (`global/global_player.lua`):
```lua
function event_enter_zone(e)
    if eq.is_lost_dungeons_of_norrath_enabled() and eq.get_zone_short_name() == "lavastorm" then
        e.self:Message(MT.DimGray, "There are GM commands available...")
    end
end

function event_connect(e)
    local age = e.self:GetAccountAge();
    for aa, v in pairs(vet_aa) do
        if v[3] and (v[2] or age >= v[1]) then
            e.self:GrantAlternateAdvancementAbility(aa, 1)
        end
    end
end
```

**Perl** (`global/global_player.pl`):
```perl
sub EVENT_ENTERZONE {
    if ($ulevel >= 15 && !defined($qglobals{Wayfarer}) && quest::is_lost_dungeons_of_norrath_enabled()) {
        $client->Message(15, "A mysterious voice whispers...");
    }
}

sub EVENT_CONNECT {
    my $age = $client->GetAccountAge();
    for (my ($aa, $v) = each %vet_aa) {
        if ($v[2] && ($v[1] || $age >= $v[0])) {
            $client->GrantAlternateAdvancementAbility($aa, 1);
        }
    }
}
```

Key differences visible here:
- Lua uses `function event_name(e)` with an event table `e`; Perl uses `sub EVENT_NAME` with magic globals
- Lua accesses the player as `e.self`; Perl uses `$client` (auto-exported)
- Lua calls `eq.*` functions; Perl calls `quest::*` functions
- Lua uses `:` for method calls on bound objects (same as Perl's `->`)

---

## Quest Script Structure

### File Discovery and Naming

The quest parser collection (`zone/quest_parser_collection.cpp`, function `GetQIByNPCQuest`)
resolves scripts in this priority order for each quest path directory:

1. **Versioned zone, by NPC ID**: `quests/<zone>/v<version>/<npc_id>.lua`
2. **Versioned zone, by NPC name**: `quests/<zone>/v<version>/<npc_name>.lua`
3. **Versioned zone, by ID+name**: `quests/<zone>/v<version>/<npc_name>_<npc_id>.lua`
4. **Zone, by NPC ID**: `quests/<zone>/<npc_id>.lua`
5. **Zone, by NPC name**: `quests/<zone>/<npc_name>.lua`
6. **Zone, by ID+name**: `quests/<zone>/<npc_name>_<npc_id>.lua`
7. **Global, by NPC ID**: `quests/global/<npc_id>.lua`
8. **Global, by NPC name**: `quests/global/<npc_name>.lua`
9. **Global, by ID+name**: `quests/global/<npc_name>_<npc_id>.lua`
10. **Versioned default**: `quests/<zone>/v<version>/default.lua`
11. **Zone default**: `quests/<zone>/default.lua`
12. **Global default**: `quests/global/default.lua`

At each step, `.lua` is tried before `.pl`.

### Naming Conventions

- **NPC name scripts**: `Captain_Tillin.lua` -- backticks in DB names become hyphens
- **NPC ID scripts**: `1173.lua` -- numeric NPC type ID
- **`#` prefix**: `#Guard_Sylus.lua` -- NPC names starting with `#` in the database
- **Player scripts**: `player.lua` (zone-specific) or `global/global_player.lua`
- **NPC global**: `global/global_npc.lua`
- **Default scripts**: `default.lua` -- fallback for any NPC without a specific script
- **Script init**: `script_init.lua` -- runs at Lua parser initialization per zone
- **Encounters**: `encounters/<name>.lua` -- loaded via `eq.load_encounter("name")`

### Directory Layout

```
akk-stack/server/quests/
    global/
        global_npc.lua          -- runs for ALL NPC events, every zone
        global_player.lua       -- runs for ALL player events, every zone
        global_player.pl        -- Perl equivalent (both can coexist for globals)
        script_init.lua         -- loaded once at startup; bootstraps modules
    lua_modules/                -- shared Lua libraries (require-able)
        items.lua
        string_ext.lua
        command.lua
        general_ext.lua
        ...
    plugins/                    -- Perl plugin equivalents
        check_handin.pl
        ...
    <zone_short_name>/          -- per-zone scripts (e.g., qeynos/, befallen/)
        <NPC_Name>.lua
        <npc_id>.lua
        player.lua              -- zone-specific player events
        default.lua             -- fallback for NPCs without scripts
        script_init.lua         -- zone-specific initialization
        encounters/
            <encounter_name>.lua
```

---

## Event System

### Complete Event List

The full list of Lua event names is defined in `zone/lua_parser.cpp` (the `LuaEvents` array).
There are **147 events** total. Here are the most commonly used:

#### NPC Events
| Event Function | Trigger |
|---|---|
| `event_say(e)` | Player says something to NPC |
| `event_trade(e)` | Player trades items to NPC |
| `event_spawn(e)` | NPC spawns |
| `event_death(e)` | NPC dies |
| `event_death_complete(e)` | NPC death fully processed |
| `event_combat(e)` | NPC enters/leaves combat |
| `event_aggro(e)` | NPC aggros |
| `event_slay(e)` | NPC slays a player |
| `event_hp(e)` | NPC reaches HP threshold |
| `event_timer(e)` | Timer fires |
| `event_signal(e)` | Signal received |
| `event_waypoint_arrive(e)` | NPC arrives at waypoint |
| `event_waypoint_depart(e)` | NPC departs waypoint |
| `event_enter(e)` | Player enters NPC proximity |
| `event_exit(e)` | Player exits NPC proximity |
| `event_cast_on(e)` | Spell cast on NPC |
| `event_killed_merit(e)` | NPC killed (merit credit) |
| `event_hate_list(e)` | Hate list changes |
| `event_target_change(e)` | NPC changes target |
| `event_damage_given(e)` | NPC deals damage |
| `event_damage_taken(e)` | NPC takes damage |
| `event_loot_added(e)` | Loot added to NPC corpse |
| `event_despawn(e)` | NPC despawns |

#### Player Events
| Event Function | Trigger |
|---|---|
| `event_enter_zone(e)` | Player enters a zone |
| `event_connect(e)` | Player connects to server |
| `event_disconnect(e)` | Player disconnects |
| `event_level_up(e)` | Player levels up |
| `event_level_down(e)` | Player levels down |
| `event_task_complete(e)` | Player completes a task |
| `event_task_accepted(e)` | Player accepts a task |
| `event_click_door(e)` | Player clicks a door |
| `event_click_object(e)` | Player clicks an object |
| `event_combine_success(e)` | Tradeskill combine succeeds |
| `event_combine_failure(e)` | Tradeskill combine fails |
| `event_combine_validate(e)` | Tradeskill combine validation |
| `event_command(e)` | Player uses custom command |
| `event_loot(e)` | Player loots an item |
| `event_forage_success(e)` | Player forages successfully |
| `event_fish_success(e)` | Player fishes successfully |
| `event_discover_item(e)` | Player discovers new item |
| `event_cast(e)` | Player casts a spell |
| `event_duel_win(e)` | Player wins a duel |
| `event_popup_response(e)` | Player responds to popup |
| `event_test_buff(e)` | Test buff event |
| `event_equip_item_client(e)` | Player equips item |
| `event_exp_gain(e)` | Player gains experience |
| `event_aa_buy(e)` | Player buys AA |

#### Encounter Events
| Event Function | Trigger |
|---|---|
| `event_encounter_load(e)` | Encounter loaded |
| `event_encounter_unload(e)` | Encounter unloaded |

#### Zone Events
| Event Function | Trigger |
|---|---|
| `event_spawn_zone(e)` | Any NPC spawns in zone |
| `event_death_zone(e)` | Any NPC dies in zone |
| `event_loot_zone(e)` | Any loot event in zone |

### Event Data Object

All Lua event handlers receive a single parameter `e` (a Lua table) containing context:

```lua
function event_say(e)
    -- e.self    = the NPC (Lua_NPC object)
    -- e.other   = the player who spoke (Lua_Mob object)
    -- e.message = what the player said (string)
end

function event_trade(e)
    -- e.self    = the NPC
    -- e.other   = the trading player
    -- e.trade   = table with item1..item4 (ItemInst), platinum, gold, silver, copper
end

function event_death(e)
    -- e.self    = the dying NPC
    -- e.other   = the killer
    -- e.killer_id, e.killer_damage, e.killer_spell, e.killer_skill
end

function event_timer(e)
    -- e.self    = the entity
    -- e.timer   = timer name (string)
end
```

---

## Lua API

### The `eq.*` Namespace

The `eq` namespace is the primary API surface, registered in `zone/lua_general.cpp`
(`lua_register_general` function, ~950 function bindings). Major categories:

#### Spawning and Entities
```lua
eq.spawn2(npc_type, grid, unused, x, y, z, heading)  -- spawn NPC
eq.unique_spawn(npc_type, grid, unused, x, y, z)      -- spawn if not already up
eq.spawn_from_spawn2(spawn2_id)                        -- spawn from spawn2 entry
eq.depop()                                             -- depop current NPC
eq.depop_all()                                         -- depop all of this NPC type
eq.get_entity_list()                                   -- returns EntityList object
eq.get_initiator()                                     -- returns initiating client
eq.get_owner()                                         -- returns NPC owner
```

#### Timers
```lua
eq.set_timer("name", milliseconds)     -- start a timer
eq.stop_timer("name")                  -- stop a timer
eq.pause_timer("name")                 -- pause a timer
eq.resume_timer("name")               -- resume a paused timer
eq.has_timer("name")                   -- check if timer exists
eq.get_remaining_time("name")          -- get remaining time
eq.stop_all_timers()                   -- stop all timers
```

#### Tasks
```lua
eq.task_selector({task_id1, task_id2})  -- show task selector
eq.assign_task(task_id)                 -- assign task
eq.fail_task(task_id)                   -- fail task
eq.complete_task(task_id)               -- complete task
eq.is_task_active(task_id)              -- check if active
eq.update_task_activity(task_id, activity_id, count)
eq.is_task_activity_active(task_id, activity_id)
```

#### Zone and World
```lua
eq.get_zone_id()                        -- current zone ID
eq.get_zone_short_name()                -- e.g., "qeynos"
eq.zone(zone_short_name, x, y, z)       -- zone a player
eq.zone_emote(color, message)            -- emote to whole zone
eq.world_emote(color, message)           -- emote to whole world
eq.set_time(hour, minute)               -- set game time
eq.signal(npc_entity_id, signal_value)  -- signal an NPC
```

#### Globals and Data
```lua
eq.set_global("name", "value", options, duration)
eq.delete_global("name")
eq.get_qglobals(client)                 -- returns table of qglobals
eq.get_data("key")                      -- data bucket get
eq.set_data("key", "value")             -- data bucket set
eq.set_data("key", "value", "expires")  -- with expiration
eq.delete_data("key")                   -- data bucket delete
```

#### Items and Commerce
```lua
eq.collect_items(item_id, quantity)
eq.count_item(item_id)
eq.remove_item(item_id)
eq.item_link(item_id)                   -- generate item link
eq.say_link("text")                     -- generate say link
eq.get_item_name(item_id)
```

#### Expansion Checks
```lua
eq.is_classic_enabled()
eq.is_the_ruins_of_kunark_enabled()
eq.is_the_scars_of_velious_enabled()
eq.is_the_shadows_of_luclin_enabled()
eq.is_the_planes_of_power_enabled()
eq.is_content_flag_enabled("flag_name")
-- ... (all expansions through Torment of Velious)
```

#### Encounters (Lua-only)
```lua
eq.load_encounter("encounter_name")
eq.unload_encounter("encounter_name")
eq.register_npc_event("encounter_name", Event.say, npc_id, callback_func)
eq.register_player_event("encounter_name", Event.enter_zone, callback_func)
eq.register_item_event("encounter_name", Event.item_click, item_id, callback_func)
eq.register_spell_event("encounter_name", Event.spell_effect, spell_id, callback_func)
eq.unregister_npc_event("encounter_name", Event.say, npc_id)
```

### Bound Object Classes

The C++ class hierarchy is fully exposed to Lua through luabind. Each `.h`/`.cpp` pair in
`zone/lua_*.{h,cpp}` binds one C++ class:

| Lua Class | C++ Source | Methods (approx) | Description |
|---|---|---|---|
| `Lua_Mob` (Mob) | `lua_mob.cpp` (623 lines in header) | ~300 | Base mobile entity |
| `Lua_Client` (Client) | `lua_client.cpp` (652 lines in header) | ~350 | Player client |
| `Lua_NPC` (NPC) | `lua_npc.cpp` (207 lines in header) | ~100 | NPC entity |
| `Lua_Bot` | `lua_bot.cpp` | ~50 | Bot entity |
| `Lua_Merc` | `lua_merc.cpp` | ~20 | Mercenary entity |
| `Lua_EntityList` | `lua_entity_list.cpp` | ~50 | Zone entity list |
| `Lua_ItemInst` | `lua_iteminst.cpp` | ~30 | Item instance |
| `Lua_Item` | `lua_item.cpp` | ~100 | Item data |
| `Lua_Spell` | `lua_spell.cpp` | ~30 | Spell data |
| `Lua_Group` | `lua_group.cpp` | ~20 | Group |
| `Lua_Raid` | `lua_raid.cpp` | ~20 | Raid |
| `Lua_Corpse` | `lua_corpse.cpp` | ~20 | Corpse |
| `Lua_Door` | `lua_door.cpp` | ~15 | Door |
| `Lua_Object` | `lua_object.cpp` | ~15 | World object |
| `Lua_Packet` | `lua_packet.cpp` | ~10 | Network packet |
| `Lua_Spawn` | `lua_spawn.cpp` | ~40 | Spawn point data |
| `Lua_Expedition` | `lua_expedition.cpp` | ~30 | Expedition/DZ |
| `Lua_Buff` | `lua_buff.cpp` | ~15 | Buff data |
| `Lua_Encounter` | `lua_encounter.cpp` | ~5 | Encounter |
| `Lua_StatBonuses` | `lua_stat_bonuses.cpp` | ~40 | Stat bonuses |
| `Lua_Inventory` | `lua_inventory.cpp` | ~15 | Inventory |
| `Lua_HateList` | `lua_hate_list.cpp` | ~10 | Hate list |
| `Lua_Database` | `lua_database.cpp` | ~5 | MySQL prepared statements |
| `Lua_Zone` | `lua_zone.cpp` | ~30 | Zone data |

### Constant Namespaces

Also registered through `lua_register_*` functions:

- `Event.*` -- event IDs (e.g., `Event.say`, `Event.death`, `Event.spawn`)
- `Faction.*` -- faction constants
- `Slot.*` -- inventory slot constants
- `Material.*` -- texture material constants
- `ClientVersion.*` -- client version constants
- `Appearance.*` -- appearance constants
- `Class.*` -- class IDs (e.g., `Class.WARRIOR`, `Class.CLERIC`)
- `Skill.*` -- skill IDs
- `BodyType.*` -- body type constants
- `Filter.*` -- message filter constants
- `MT.*` -- message type colors (e.g., `MT.Yellow`, `MT.Red`, `MT.White`)
- `Zone.*` -- zone ID constants (e.g., `Zone.qeynos`, `Zone.poknowledge`)
- `Language.*` -- language IDs
- `Rule.*` -- server rule access
- `Random.*` -- random number utilities (`Random.Int`, `Random.Real`, `Random.Roll`)

---

## Lua Modules

### Location

Shared modules live in `akk-stack/server/quests/lua_modules/` (23 files). The Lua `package.path`
is configured in `lua_parser.cpp` (line ~1128) to include paths returned by
`PathManager::Instance()->GetLuaModulePaths()`.

### Bootstrap: `global/script_init.lua`

This file runs once at Lua parser initialization and loads core modules:

```lua
require("string_ext");      -- case-insensitive string methods
require("command");          -- custom command dispatch system
require("client_ext");       -- Client class extensions
require("mob_ext");          -- Mob class extensions
require("npc_ext");          -- NPC class extensions
require("entity_list_ext");  -- EntityList extensions
require("general_ext");      -- eq.* helper functions
require("bit");              -- bitwise operations
require("directional");      -- directional calculations
require("constants/instance_versions");  -- instance version constants
```

### Key Modules

| Module | File | Purpose |
|---|---|---|
| `items` | `items.lua` | `check_turn_in()`, `return_items()` -- core trade handling |
| `string_ext` | `string_ext.lua` | `findi()`, `gmatchi()`, `gsubi()`, `matchi()` -- case-insensitive string ops |
| `command` | `command.lua` | `eq.DispatchCommands()` -- custom player command routing |
| `general_ext` | `general_ext.lua` | `eq.ChooseRandom()`, `eq.ClassType()`, `eq.Set()`, `eq.ExpHelper()`, etc. |
| `mob_ext` | `mob_ext.lua` | `Mob:ForeachHateList()`, `Mob:CountHateList()`, `Mob:CastedSpellFinished()` |
| `dragons_of_norrath` | `dragons_of_norrath.lua` | DoN content integration |
| `thread_manager` | `thread_manager.lua` | Coroutine-based conversation threading |
| `json` | `json.lua` | JSON encode/decode |
| `instance_requests` | `instance_requests.lua` | Instance request handling |
| `translocators` | `translocators.lua` | Translocator NPC handling |
| `directional` | `directional.lua` | Heading/direction calculations |
| `ellipse_box` | `ellipse_box.lua` | Geometric boundary checks |
| `lockouts_def` | `lockouts_def.lua` | Lockout timer definitions |

### Module Usage Pattern

```lua
-- In any quest script:
local item_lib = require("items");

function event_trade(e)
    if (item_lib.check_turn_in(e.trade, {item1 = 13915})) then
        e.self:Say("Thank you!");
        e.other:SummonItem(10070);
    end
    item_lib.return_items(e.self, e.other, e.trade)
end
```

---

## Encounter System (Lua-Only)

The encounter system is a powerful Lua-exclusive feature for creating dynamic, zone-wide
scripted behaviors without modifying individual NPC scripts. It uses coroutine-based threading
for natural conversation flows.

### How It Works

1. A `script_init.lua` in a zone directory loads encounters:
   ```lua
   -- quests/qeynos/script_init.lua
   eq.load_encounter("trumpy");
   ```

2. The encounter script lives in `encounters/<name>.lua`:
   ```lua
   -- quests/qeynos/encounters/trumpy.lua
   function event_encounter_load(e)
       eq.register_npc_event("trumpy", Event.waypoint_arrive, 1042, TrumpyWaypoint);
       eq.register_npc_event("trumpy", Event.timer, 1042, TrumpyHeartbeat);
       eq.register_npc_event("trumpy", Event.spawn, 1042, TrumpySpawn);
   end
   ```

3. Registered callbacks fire for specified NPCs across the zone, enabling complex multi-NPC
   interactions, boss mechanics, and environmental storytelling.

### Thread Manager

The `thread_manager.lua` module provides coroutine-based "threads" for natural conversation
pacing:

```lua
local ThreadManager = require("thread_manager");

function SunsaConversation()
    trumpy:Say("Time to drain the dragon..");
    ThreadManager:Wait(0.65);  -- pause ~650ms
    local sunsa = eq.get_entity_list():GetMobByNpcTypeID(1074);
    if (sunsa.valid) then
        sunsa:Say("Trumpy, you are one sick little man!");
    end
end

function event_encounter_load(e)
    eq.register_npc_event("trumpy", Event.waypoint_arrive, 1042, function(e)
        if (e.wp == 2) then
            ThreadManager:Create("SunsaConversation", SunsaConversation);
        end
    end);
end
```

There are **53 `script_init.lua` files** across zones, indicating widespread encounter usage.

---

## Mod System (Lua-Only)

The `lua_mod.cpp`/`lua_mod.h` system provides **engine-level hooks** that let Lua scripts
override core game mechanics. These are not available in Perl.

### Available Mod Hooks

| Hook | Purpose |
|---|---|
| `MeleeMitigation` | Modify melee damage mitigation |
| `ApplyDamageTable` | Override damage table |
| `AvoidDamage` | Override damage avoidance |
| `CheckHitChance` | Override hit chance |
| `TryCriticalHit` | Override critical hit logic |
| `CommonOutgoingHitSuccess` | Modify outgoing hit results |
| `GetRequiredAAExperience` | Override AA experience requirements |
| `GetEXPForLevel` | Override experience-per-level formula |
| `GetExperienceForKill` | Override kill experience |
| `CalcSpellEffectValue_formula` | Override spell effect calculations |
| `UpdatePersonalFaction` | Override faction adjustments |
| `RegisterBug` | Override bug report handling |
| `CommonDamage` | Override all damage processing |
| `HealDamage` | Override healing |
| `SetEXP` | Override experience setting |
| `SetAAEXP` | Override AA experience setting |
| `IsImmuneToSpell` | Override spell immunity |

Each mod hook includes an `ignoreDefault` flag -- if set to `true`, the mod's return value
replaces the engine's default calculation entirely.

---

## C++ Integration Architecture

### Source Files

All Lua integration code lives in `eqemu/zone/`:

| File | Lines | Purpose |
|---|---|---|
| `lua_parser.h` | 363 | `LuaParser` class -- the `QuestInterface` implementation |
| `lua_parser.cpp` | ~1500 | Parser init, event dispatch, script loading |
| `lua_parser_events.h` | 1459 | Event argument handler typedefs and declarations |
| `lua_parser_events.cpp` | (large) | Event argument packaging implementations |
| `lua_general.h` | 31 | Registration function declarations |
| `lua_general.cpp` | 8086 | **Largest file** -- all `eq.*` function implementations + registration |
| `lua_mod.h` | 62 | Mod hook class |
| `lua_mod.cpp` | (moderate) | Mod hook implementations |
| `lua_mob.cpp` | (large) | Mob class bindings |
| `lua_client.cpp` | (large) | Client class bindings |
| `lua_npc.cpp` | (moderate) | NPC class bindings |
| (20+ more) | varies | Other entity type bindings |

### Integration Flow

```
Game Event (e.g., player says something to NPC)
    |
    v
QuestParserCollection::EventNPC()
    |
    +-- tries Local script  (per-NPC or default.lua)
    +-- tries Global script (global_npc.lua)
    +-- tries Encounter registrations
    |
    v
LuaParser::EventNPC()
    |
    +-- LuaParser::_EventNPC()
    |       |
    |       +-- Packages event arguments into Lua table (e)
    |       +-- Calls function in loaded Lua script
    |       +-- e.g., calls event_say(e) where e = {self=npc, other=client, message="hail"}
    |
    v
Lua script runs, calls eq.* functions and object methods
    |
    v
C++ functions execute via luabind, modifying game state
```

### Key Design Points

1. **Singleton pattern**: `LuaParser::Instance()` -- single Lua state for all scripts
2. **Package isolation**: Each script gets its own Lua package namespace to prevent collisions
3. **LuaJIT**: Uses LuaJIT 2.1 for performance (JIT compilation of Lua bytecode)
4. **luabind**: C++ binding library that maps classes and functions to Lua
5. **Event table**: All events pass a single table `e` with named fields -- cleaner than Perl's
   magic global variables
6. **Module path**: Configured at init time to search `lua_modules/` directories

---

## Common Patterns

### Basic NPC Say Handler

```lua
function event_say(e)
    if (e.message:findi("hail")) then
        e.self:Say("Hello, " .. e.other:GetName() .. "!");
    elseif (e.message:findi("quest")) then
        e.self:Say("Bring me 4 [gnoll fangs] and I shall reward you.");
    end
end
```

### Item Turn-In

```lua
function event_trade(e)
    local item_lib = require("items");
    if (item_lib.check_turn_in(e.trade, {item1 = 13915})) then
        e.self:Say("Thank you for the gnoll fang!");
        e.other:SummonItem(10070);
        e.other:AddEXP(7000);
        e.other:Faction(219, 1, 0);
    end
    item_lib.return_items(e.self, e.other, e.trade)
end
```

### Timer Pattern

```lua
function event_spawn(e)
    eq.set_timer("check_players", 30000);  -- 30 seconds
end

function event_timer(e)
    if (e.timer == "check_players") then
        local clients = eq.get_entity_list():GetClientList();
        for client in clients.entries do
            if (client.valid) then
                e.self:Say("I see you, " .. client:GetName());
            end
        end
    end
end
```

### Proximity with Waypoints

```lua
function event_waypoint_arrive(e)
    if (e.wp == 23) then
        local x = e.self:GetX();
        local y = e.self:GetY();
        eq.set_proximity(x - 40, x + 40, y - 40, y + 40);
    elseif (e.wp == 1) then
        eq.clear_proximity();
    end
end

function event_enter(e)
    e.other:Message(MT.Yellow, "You feel an evil presence...");
end
```

### HP-Based Boss Mechanics

```lua
function event_spawn(e)
    eq.set_next_hp_event(50);
end

function event_hp(e)
    if (e.hp_event == 50) then
        e.self:Say("You will not defeat me so easily!");
        eq.spawn2(12345, 0, 0, e.self:GetX(), e.self:GetY(), e.self:GetZ(), 0);
        eq.set_next_hp_event(25);
    elseif (e.hp_event == 25) then
        e.self:Say("ENOUGH!");
        e.self:SetSpecialAbility(24, 1);  -- enrage
    end
end
```

### Zone Player Script

```lua
-- player.lua (zone-specific)
function event_enter_zone(e)
    e.self:BuffFadeAll();  -- strip all buffs on zone-in (e.g., Plane of Air)
end
```

### Database Access

```lua
-- Lua_Database provides prepared statement access
local db = Database()
local stmt = db:Prepare("SELECT name FROM character_data WHERE id = ?")
stmt:Execute({char_id})
local row = stmt:FetchHash()
if row then
    e.self:Say("Found character: " .. row.name)
end
db:Close()
```

---

## Global Scripts

### `global/global_npc.lua`

Runs for every NPC spawn in every zone. Current content:
- Halloween event: changes NPC appearances in specific zones when `peq_halloween` flag is set

### `global/global_player.lua`

Runs for every player event in every zone. Current content:
- LDoN Wayfarer Brotherhood mysterious voice message
- Tradeskill combine validation (zone restrictions)
- Epic quest tradeskill combine rewards (1.5, 2.0 epics for multiple classes)
- Custom command dispatch (`event_command`)
- Veteran AA granting on connect
- Free skill training on level up
- Test buff event handler

### `global/script_init.lua`

Bootstraps all core Lua modules (string extensions, command system, class extensions, etc.)
at Lua parser initialization. Runs before any quest scripts.

---

## Scale and Coverage

| Metric | Count |
|---|---|
| Total Lua quest scripts | ~4,209 |
| Total Perl quest scripts | ~3,790 |
| Directories with Lua files | ~313 |
| Directories with Perl files | ~200 |
| Total zone directories | ~276 (excluding meta dirs) |
| Lua modules | 23 files |
| Perl plugins | ~20+ files |
| Encounter directories | 10+ zones |
| Script init files | 53 zones |
| C++ Lua binding files | ~40 files (`lua_*.{h,cpp}`) |
| eq.* functions registered | ~950 |
| Event types | 147 |
| Lua object classes | ~25 |

The quest repository uses Lua as the dominant language. Many zones are **Lua-only**. The
remaining Perl scripts are primarily in zones that haven't been fully converted, or for
backward compatibility.

---

## Where to Start

### Writing Your First Lua Quest

1. **Find the zone**: Quest scripts go in `akk-stack/server/quests/<zone_short_name>/`

2. **Name the file**: Use the NPC's clean name with underscores:
   `Captain_Tillin.lua` or the NPC type ID: `1077.lua`

3. **Write event handlers**: Start with `event_say`:
   ```lua
   function event_say(e)
       if (e.message:findi("hail")) then
           e.self:Say("Greetings, " .. e.other:GetName() .. "!");
       end
   end
   ```

4. **Use modules**: For item turn-ins, always use the items module:
   ```lua
   local item_lib = require("items");
   ```

5. **Reload**: Use `#reloadquest` in-game or reload via Spire to pick up changes

### Key References

- **Event list**: `eqemu/zone/lua_parser.cpp` lines 47-194 (all 147 event names)
- **eq.* API**: `eqemu/zone/lua_general.cpp` lines 5897-6847 (all registered functions)
- **Mob methods**: `eqemu/zone/lua_mob.h` (~300 methods)
- **Client methods**: `eqemu/zone/lua_client.h` (~350 methods)
- **NPC methods**: `eqemu/zone/lua_npc.h` (~100 methods)
- **Example scripts**: `akk-stack/server/quests/qeynos/Captain_Tillin.lua` (say/trade pattern)
- **Global scripts**: `akk-stack/server/quests/global/global_player.lua` (comprehensive example)
- **Encounter example**: `akk-stack/server/quests/qeynos/encounters/trumpy.lua`
- **Module example**: `akk-stack/server/quests/lua_modules/items.lua`

### Learning Path

1. Read `global/script_init.lua` to understand what's globally available
2. Read `lua_modules/string_ext.lua` for the `findi()` method used everywhere
3. Read `lua_modules/items.lua` for the `check_turn_in` pattern
4. Read a simple NPC like `qeynos/Captain_Tillin.lua` for say/trade patterns
5. Read `global/global_player.lua` for player event patterns
6. Read `qeynos/encounters/trumpy.lua` for the encounter system
7. Browse `lua_general.cpp` for the full `eq.*` API surface

---

## Notes for Python Migration Planning

Lua and Python share several characteristics that make migration planning relevant:

### Similarities with Python
- **First-class functions**: Lua supports closures, callbacks, and passing functions as arguments
- **Tables as dictionaries**: Lua tables serve as both arrays and dictionaries (like Python's lists/dicts)
- **Dynamic typing**: Both are dynamically typed
- **Module system**: Lua's `require()` is conceptually similar to Python's `import`
- **Coroutines**: Lua has built-in coroutine support (used in thread_manager.lua)

### Migration Considerations
- **Event model**: Lua's `function event_say(e)` pattern maps naturally to Python's
  `def event_say(e):` -- the event table approach is already very Pythonic
- **Object methods**: Lua's `e.self:GetName()` would become `e.self.get_name()` in Python
- **String operations**: Lua's `e.message:findi("hail")` would map to
  `"hail" in e.message.lower()` in Python
- **Modules**: The `lua_modules/` library could be ported to Python packages relatively
  directly
- **C++ binding**: Would need a Python embedding library (e.g., pybind11) instead of luabind
- **Performance**: LuaJIT is very fast; Python would likely be slower but acceptable for
  quest scripting where logic is simple and I/O-bound
- **Encounter system**: The encounter/registration pattern could map to Python decorators
- **Mod system**: The `lua_mod` hooks could be replicated with Python callables

### What Perl Cannot Do (but Lua Can)
- **Encounter system**: Dynamic event registration across NPCs (Lua-only)
- **Mod hooks**: Engine-level combat/XP/damage formula overrides (Lua-only)
- **Coroutine threading**: Natural conversation pacing with `ThreadManager` (Lua coroutines)
- **Database prepared statements**: `Lua_Database` class with bound MySQL access
- **Script init**: Automatic module loading via `script_init.lua`

### What Perl Has (that Lua Handles Differently)
- **Regex**: Perl has native regex; Lua uses pattern matching (extended by `string_ext.lua`)
- **Global variables**: Perl exports `$client`, `$npc`, `$mob` etc. as globals; Lua bundles
  them in the event table `e`
- **CPAN ecosystem**: Perl has a vast module ecosystem; Lua's is smaller but adequate for
  quest scripting

A Python migration would most naturally start from the Lua codebase rather than Perl, since
Lua's event-table paradigm, module system, and cleaner syntax are closer to Pythonic patterns.
