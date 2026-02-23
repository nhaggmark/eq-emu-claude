# Perl Code Topography

## Summary

Perl is the primary scripting language for quest logic in the EQEmu server. It powers NPC dialogues, item hand-in quests, spawn events, boss mechanics, zone progression, tradeskill validation, and more. The server embeds a full Perl interpreter (via `libperl`) into each zone process, exposing C++ game objects (`$client`, `$npc`, `$entity_list`) and a large `quest::` API directly to Perl scripts.

There are **3,790 Perl quest scripts** across **200 zone directories**, plus **40 shared plugin files**. Additionally, **4,209 Lua scripts** coexist alongside Perl -- the server supports both languages and loads whichever file it finds first (Lua takes precedence since it is registered before Perl in the load order).

Key paths:
- `akk-stack/server/quests/` -- runtime quest scripts, organized by zone short name
- `akk-stack/server/quests/plugins/` -- shared Perl plugin library (40 files)
- `akk-stack/server/quests/global/` -- global scripts that run in every zone
- `eqemu/zone/embparser.cpp` -- the Perl parser integration (event dispatch, variable export)
- `eqemu/zone/embparser_api.cpp` -- the `quest::` namespace API (877 function overloads, 7,060 lines)
- `eqemu/zone/perl_*.cpp` -- object method bindings ($client->, $npc->, $mob->, etc.)
- `eqemu/zone/event_codes.h` -- canonical list of all 154 quest event IDs

---

## 1. Quest Script Organization

### Directory Structure

Scripts live under `akk-stack/server/quests/` in subdirectories named by **zone short name**:

```
quests/
  global/             # Runs in every zone
    global_player.pl  # Player events in all zones
    global_npc.lua    # NPC events in all zones (Lua version)
    items/            # Global item scripts (click/cast events)
    spells/           # Global spell scripts (effect hooks)
  plugins/            # Shared Perl plugins (loaded once)
  qeynos/             # Zone: South Qeynos
  freeportwest/       # Zone: West Freeport
  poknowledge/        # Zone: Plane of Knowledge
  shadowhaven/        # Zone: Shadow Haven (259 scripts -- most of any zone)
  ...                 # ~200 zone directories total
```

### Top Zones by Script Count

| Zone | Perl Scripts | Notes |
|------|-------------|-------|
| shadowhaven | 259 | Luclin hub city |
| poknowledge | 205 | PoP hub, many NPC services |
| sharvahl | 177 | Vah Shir home city |
| katta | 120 | Katta Castellum |
| thurgadina | 86 | Thurgadin |
| gunthak | 81 | LDoN launch point |
| paineel | 65 | Erudite city |
| cabeast | 62 | Cabilis East |
| skyshrine | 56 | Dragon faction hub |
| kael | 56 | Giant faction hub |

### Version Subdirectories

Some zones have versioned subdirectories for instanced content:

```
quests/droga/v1/a_goblin_stone_seer.pl
quests/lavastorm/v1/player.pl
```

The server resolves these based on the zone's instance version.

---

## 2. Naming Conventions

The server's file resolution logic (in `quest_parser_collection.cpp` lines 1050-1125) searches for NPC scripts in this priority order:

1. `quests/{zone}/v{version}/{npc_id}.pl` -- versioned, by NPC type ID
2. `quests/{zone}/v{version}/{NPC_Name}.pl` -- versioned, by NPC name
3. `quests/{zone}/v{version}/{NPC_Name}_{npc_id}.pl` -- versioned, by name and ID
4. `quests/{zone}/{npc_id}.pl` -- by NPC type ID
5. `quests/{zone}/{NPC_Name}.pl` -- by NPC clean name
6. `quests/{zone}/{NPC_Name}_{npc_id}.pl` -- by name and ID
7. `quests/global/{npc_id}.pl` -- global by ID
8. `quests/global/{NPC_Name}.pl` -- global by name
9. `quests/global/{NPC_Name}_{npc_id}.pl` -- global by name and ID
10. `quests/{zone}/v{version}/default.pl` -- versioned zone default
11. `quests/{zone}/default.pl` -- zone default
12. `quests/global/default.pl` -- global default (fallback for all NPCs)

Backticks in NPC names are replaced with hyphens. Lua (`.lua`) is checked before Perl (`.pl`) at each step.

### File Name Prefixes

- **No prefix** -- Standard NPC scripts: `Adept_Arnthus.pl`
- **`#` prefix** -- Alternate or special NPC scripts: `#Alexsa_Whyte.pl` (commonly used for quest-specific spawned NPCs)
- **`##` prefix** -- Event/holiday NPC scripts: `##Booberella.pl`, `##Captain_Scareyface.pl` (Halloween event NPCs in Kithicor)
- **Numeric names** -- Scripts keyed by NPC type ID: `48030.pl`, `999201.pl`
- **`player.pl`** -- Zone-specific player event handlers
- **`global_player.pl`** -- Player events that run in every zone
- **`default.pl`** -- Fallback NPC behavior for unscripted NPCs

### Special Script Types

| File | Location | Purpose |
|------|----------|---------|
| `player.pl` | Per zone | Player events (enter zone, click doors, etc.) |
| `global_player.pl` | `global/` | Player events across all zones |
| `global_npc.lua` | `global/` | NPC events across all zones |
| `default.pl` | `plugins/` or zone | Fallback NPC behavior |
| `items/script_{id}.pl` | `global/items/` | Item click/cast event scripts |
| `spells/{id}.pl` | `global/spells/` | Spell effect event scripts |

---

## 3. Event System

Events are defined in `eqemu/zone/event_codes.h` as a C enum (`QuestEventID`). There are **154 event types**. In Perl scripts, events are implemented as subroutines named `sub EVENT_XXX { }`.

### Most Commonly Used Events (by file count in the Perl scripts)

| Event | Files Using It | Context | Description |
|-------|---------------|---------|-------------|
| `EVENT_SAY` | 2,458 | NPC | Player says something to the NPC |
| `EVENT_ITEM` (EVENT_TRADE) | 1,648 | NPC | Player hands item(s) to NPC |
| `EVENT_SPAWN` | 682 | NPC | NPC first spawns into the zone |
| `EVENT_DEATH` | 564 | NPC | NPC is killed |
| `EVENT_TIMER` | 479 | NPC/Player | A named timer fires |
| `EVENT_SIGNAL` | 337 | NPC | Receives an inter-NPC signal |
| `EVENT_COMBAT` | 183 | NPC | Entering or leaving combat |
| `EVENT_ENTERZONE` | 24 | Player | Player enters a zone |

### Complete Event Categories

**NPC Events (core):**
`EVENT_SAY`, `EVENT_TRADE`, `EVENT_DEATH`, `EVENT_SPAWN`, `EVENT_ATTACK`, `EVENT_COMBAT`, `EVENT_AGGRO`, `EVENT_SLAY`, `EVENT_NPC_SLAY`, `EVENT_TIMER`, `EVENT_SIGNAL`, `EVENT_HP`, `EVENT_ENTER`, `EVENT_EXIT`, `EVENT_WAYPOINT_ARRIVE`, `EVENT_WAYPOINT_DEPART`, `EVENT_TARGET_CHANGE`, `EVENT_HATE_LIST`, `EVENT_CAST_ON`, `EVENT_AGGRO_SAY`, `EVENT_PROXIMITY_SAY`, `EVENT_DEATH_COMPLETE`, `EVENT_RESPAWN`, `EVENT_DESPAWN`, `EVENT_TICK`, `EVENT_CONSIDER`, `EVENT_DAMAGE_GIVEN`, `EVENT_DAMAGE_TAKEN`, `EVENT_TEST_BUFF`, `EVENT_SPELL_BLOCKED`

**Player Events:**
`EVENT_ENTER_ZONE`, `EVENT_CLICK_DOOR`, `EVENT_ZONE`, `EVENT_LOOT`, `EVENT_LEVEL_UP`, `EVENT_LEVEL_DOWN`, `EVENT_CONNECT`, `EVENT_DISCONNECT`, `EVENT_GROUP_CHANGE`, `EVENT_DUEL_WIN`, `EVENT_DUEL_LOSE`, `EVENT_FORAGE_SUCCESS`, `EVENT_FORAGE_FAILURE`, `EVENT_FISH_START`, `EVENT_FISH_SUCCESS`, `EVENT_FISH_FAILURE`, `EVENT_DISCOVER_ITEM`, `EVENT_COMBINE_SUCCESS`, `EVENT_COMBINE_FAILURE`, `EVENT_COMBINE_VALIDATE`, `EVENT_POPUP_RESPONSE`, `EVENT_COMMAND`, `EVENT_GM_COMMAND`, `EVENT_WARP`, `EVENT_USE_SKILL`, `EVENT_SKILL_UP`, `EVENT_AA_BUY`, `EVENT_EXP_GAIN`, `EVENT_MERCHANT_BUY`, `EVENT_MERCHANT_SELL`, `EVENT_INSPECT`, `EVENT_EQUIP_ITEM_CLIENT`, `EVENT_UNEQUIP_ITEM_CLIENT`

**Item Events:**
`EVENT_ITEM_CLICK`, `EVENT_ITEM_CLICK_CAST`, `EVENT_SCALE_CALC`, `EVENT_ITEM_ENTER_ZONE`, `EVENT_ITEM_TICK`, `EVENT_DROP_ITEM`, `EVENT_DESTROY_ITEM`, `EVENT_AUGMENT_ITEM`, `EVENT_AUGMENT_INSERT`, `EVENT_AUGMENT_REMOVE`, `EVENT_WEAPON_PROC`

**Spell Events:**
`EVENT_SPELL_EFFECT_CLIENT`, `EVENT_SPELL_EFFECT_NPC`, `EVENT_SPELL_EFFECT_BUFF_TIC_CLIENT`, `EVENT_SPELL_EFFECT_BUFF_TIC_NPC`, `EVENT_SPELL_FADE`, `EVENT_SPELL_EFFECT_TRANSLOCATE_COMPLETE`, `EVENT_CAST`, `EVENT_CAST_BEGIN`

**Task Events:**
`EVENT_TASK_ACCEPTED`, `EVENT_TASK_STAGE_COMPLETE`, `EVENT_TASK_UPDATE`, `EVENT_TASK_COMPLETE`, `EVENT_TASK_FAIL`, `EVENT_TASK_BEFORE_UPDATE`

**Zone Events:**
`EVENT_SPAWN_ZONE`, `EVENT_DEATH_ZONE`, `EVENT_LOOT_ZONE`, `EVENT_DESPAWN_ZONE`

### Exported Variables

The C++ engine exports variables into the Perl namespace before calling each event. Key variables available in scripts:

**Always available:**
- `$name` -- player's character name
- `$race` -- player's race name
- `$class` -- player's class name
- `$ulevel` -- player's level
- `$userid` -- player's entity ID
- `$charid` -- player's character ID
- `$zoneid`, `$zonesn`, `$zoneln` -- zone ID, short name, long name
- `$zonetime`, `$zonehour`, `$zonemin` -- in-game time
- `$instanceid`, `$instanceversion` -- instance info
- `%qglobals` -- hash of quest global variables

**NPC context:**
- `$npc` -- blessed Perl reference to the NPC object
- `$client` -- blessed Perl reference to the interacting client
- `$entity_list` -- blessed reference to the zone's entity list
- `$mname` -- NPC name
- `$mobid` -- NPC entity ID
- `$mlevel` -- NPC level
- `$hpratio` -- NPC HP percentage
- `$x`, `$y`, `$z`, `$h` -- NPC position/heading
- `$faction` -- player's faction with the NPC

**Event-specific:**
- `$text` -- what the player said (EVENT_SAY)
- `$timer` -- timer name (EVENT_TIMER)
- `$signal` -- signal value (EVENT_SIGNAL)
- `$item1`..`$item4` -- item IDs handed in (EVENT_TRADE)
- `$copper`, `$silver`, `$gold`, `$platinum` -- money handed in
- `$doorid` -- door clicked (EVENT_CLICK_DOOR)
- `$wp` -- waypoint reached (EVENT_WAYPOINT_*)
- `$hpevent` / `$inchpevent` -- HP threshold crossed (EVENT_HP)
- `$combat_state` -- 1=entering, 0=leaving (EVENT_COMBAT)
- `$killed_npc_id`, `$killed_raid_id` -- kill info (EVENT_KILLED_MERIT)
- `$spell_id`, `$caster_id` -- spell info (spell events)
- `$recipe_id` -- recipe ID (combine events)
- `$itemid` -- item ID (item events)

---

## 4. Quest API (`quest::` Namespace)

The `quest::` namespace provides **877 function overloads** implemented in `eqemu/zone/embparser_api.cpp` (7,060 lines). These are the primary tools quest scripts use.

### Categories of `quest::` Functions

**Communication:**
- `quest::say("text")` -- NPC says text to nearby players
- `quest::emote("text")` -- NPC emotes
- `quest::shout("text")` -- NPC shouts zone-wide
- `quest::me("text")` -- emote-style message
- `quest::echo(color, "text")` -- debug output
- `quest::gmsay("text", color)` -- GM broadcast

**Spawning and Despawning:**
- `quest::spawn(npc_type, grid, unused, x, y, z)` -- spawn an NPC
- `quest::spawn2(npc_type, grid, unused, x, y, z, heading)` -- spawn with heading
- `quest::unique_spawn(npc_type, grid, unused, x, y, z)` -- spawn only if not already up
- `quest::spawn_from_spawn2(spawn2_id)` -- spawn from a spawn2 entry
- `quest::depop()` / `quest::depop(npc_type)` -- remove NPC
- `quest::depop_withtimer()` -- remove and restart spawn timer
- `quest::depopall(npc_type)` -- remove all of a type

**Items and Rewards:**
- `quest::summonitem(item_id)` / `quest::summonitem(item_id, charges)` -- give item to player
- `quest::givecash(copper, silver, gold, platinum)` -- give money
- `quest::addloot(item_id, charges)` -- add item to NPC's loot table

**Movement and Zones:**
- `quest::moveto(x, y, z)` -- move NPC to location
- `quest::follow(entity_id, distance)` -- follow an entity
- `quest::zone("zone_name")` -- send player to zone
- `quest::zonegroup("zone_name")` -- send group to zone
- `quest::safemove()` -- move player to safe coordinates

**Timers:**
- `quest::settimer("name", seconds)` -- start a named timer
- `quest::stoptimer("name")` -- stop a timer
- `quest::stopalltimers()` -- stop all timers
- `quest::hastimer("name")` -- check if timer exists

**Character Manipulation:**
- `quest::exp(amount)` -- give experience
- `quest::level(new_level)` -- set level
- `quest::traindisc(tome_id)` -- train a discipline
- `quest::scribespells(max_level)` -- scribe spells up to level
- `quest::castspell(spell_id, target_id)` -- cast a spell
- `quest::selfcast(spell_id)` -- cast spell on self
- `quest::surname("name")` -- set surname
- `quest::setstat(stat_id, value)` -- modify a stat

**Faction and Flags:**
- `quest::faction(faction_id, value)` -- modify faction
- `quest::set_zone_flag(zone_id)` -- grant zone access flag
- `quest::setglobal("name", "value", options, duration)` -- set a quest global
- `quest::targlobal("name", "value", duration, npc_id, char_id, zone_id)` -- targeted global

**Tasks:**
- `quest::taskselector(task_id, ...)` -- offer tasks to player
- `quest::istaskactivityactive(task_id, activity_id)` -- check task progress
- `quest::updatetaskactivity(task_id, activity_id, count)` -- update progress

**Miscellaneous:**
- `quest::doanim(anim_id)` -- play animation
- `quest::set_proximity(x1, x2, y1, y2, z1, z2)` -- set NPC proximity trigger
- `quest::spawn_condition("zone", condition_id, value)` -- control spawn conditions
- `quest::voicetell(name, type, race, gender)` -- voice greeting
- `quest::forcedooropen(door_id)` -- open a door
- `quest::rain(type)` / `quest::snow(type)` -- weather control
- `quest::signal(npc_id, signal_value)` -- send signal to another NPC
- `quest::signalwith(npc_id, signal_value, wait_ms)` -- delayed signal

---

## 5. Object APIs (`$client->`, `$npc->`, `$mob->`, `$entity_list->`)

The C++ game objects are exposed as blessed Perl references with extensive method APIs:

### `$mob->` (Mob base class) -- 557 methods
File: `eqemu/zone/perl_mob.cpp` (4,261 lines)

Common methods: `GetName()`, `GetCleanName()`, `GetLevel()`, `GetHP()`, `GetMaxHP()`, `SetHP()`, `GetX()`, `GetY()`, `GetZ()`, `GetHeading()`, `GetRace()`, `GetClass()`, `GetGender()`, `GetTarget()`, `GetID()`, `GetNPCTypeID()`, `CastToNPC()`, `CastToClient()`, `IsNPC()`, `IsClient()`, `Depop()`, `ChangeSize()`, `GetSize()`, `GetEntityVariable()`, `SetEntityVariable()`

### `$client->` (Client/Player) -- 519 methods
File: `eqemu/zone/perl_client.cpp` (3,973 lines)

Common methods: `Message(color, "text")`, `SendMarqueeMessage(...)`, `GetName()`, `GetStartZone()`, `GetAccountAge()`, `GuildID()`, `GuildRank()`, `Admin()`, `GetItemIDAt(slot)`, `GetItemAt(slot)`, `NukeItem(item_id)`, `SummonItem(item_id, charges, attuned)`, `Save()`, `Kick()`, `Connected()`, `InZone()`, `GrantAlternateAdvancementAbility(aa_id, value)`, `SendToInstance(...)`, `GetCorpseCount()`, `GetAugmentIDAt(slot, aug_slot)`

### `$npc->` (NPC) -- 140 methods
File: `eqemu/zone/perl_npc.cpp` (1,069 lines)

Common methods: `CheckHandin(client, itemcount, required, ...)`, `GetNPCTypeID()`, `GetLoottableID()`, `ModifyNPCStat(stat, value)`, `AddItem(item_id, charges)`, `RemoveItem(item_id)`, `GetSwarmOwner()`

### `$entity_list->` (EntityList) -- 59 methods
File: `eqemu/zone/perl_entity.cpp` (912 lines)

Common methods: `GetClientByID(id)`, `GetMobByID(id)`, `GetNPCByID(id)`, `GetNPCList()`, `GetClientList()`, `GetMobID(id)`, `SignalAllClients(signal)`

### Other Exposed Classes

| Class | File | Methods |
|-------|------|---------|
| `$group` | `perl_groups.cpp` | Group operations |
| `$raid` | `perl_raids.cpp` | Raid operations |
| `$inventory` | `perl_inventory.cpp` | Inventory access |
| `$quest_item` | `perl_questitem.cpp` | Quest item manipulation |
| `$spell` | `perl_spell.cpp` | Spell data access |
| `$corpse` | `perl_player_corpse.cpp` | Corpse operations |
| `$door` | `perl_doors.cpp` | Door operations |
| `$object` | `perl_object.cpp` | World object operations |
| `$bot` | `perl_bot.cpp` | Bot operations |
| `$merc` | `perl_merc.cpp` | Mercenary operations |
| `$buff` | `perl_buff.cpp` | Buff operations |
| `$database` | `perl_database.cpp` | Direct DB queries |
| `$zone` | `perl_zone.cpp` | Zone object access |
| `$spawn` | `perl_spawn.cpp` | Spawn point data |
| `$stat_bonuses` | `perl_stat_bonuses.cpp` | Stat bonus access |
| `$expedition` | `perl_expedition.cpp` | Expedition/DZ operations |
| `$hate_entry` | `perl_hateentry.cpp` | Hate list entries |
| `$packet` | `perl_perlpacket.cpp` | Raw packet creation |

---

## 6. Plugin System

Plugins live in `akk-stack/server/quests/plugins/` and provide shared functions accessible via the `plugin::` namespace. They are loaded once and available to all quest scripts.

### Core Plugins

| Plugin | Purpose |
|--------|---------|
| `globals.pl` | Variable access (`plugin::val`, `plugin::var`, `plugin::setval`), item/coin checking |
| `check_handin.pl` | `plugin::check_handin(\%itemcount, item_id => count)` -- validates item hand-ins |
| `check_hasitem.pl` | `plugin::check_hasitem($client, $item_id)` -- checks inventory/bank/corpse |
| `constants.pl` | Lookup functions: `plugin::Class()`, `plugin::Race()`, `plugin::Zone()`, etc. |
| `default.pl` | Default NPC event handlers (say, item, combat, slay, death) |
| `default-actions.pl` | Smart default behaviors for soulbinders, guards, merchants |
| `client_messages.pl` | `plugin::Whisper()`, `plugin::ClientSay()`, `plugin::MM()` (marquee) |
| `soulbinders.pl` | Shared soulbinder dialogue/binding logic |
| `guildmasters.pl` | Guild master tome handling (stub) |

### Utility Plugins

| Plugin | Purpose |
|--------|---------|
| `utility.pl` | Distance calculations, entity variables, loot helpers |
| `mob_utils.pl` | `plugin::MobHealPercentage()`, `plugin::SpawnInPlace()`, `plugin::SpawnChest()` |
| `npc_tools.pl` | `plugin::fixNPCName()`, `plugin::humanoid()`, `plugin::SetProx()`, `plugin::CountNPCTYPE()` |
| `random_utils.pl` | Random number helpers |
| `spawn_tools.pl` | Spawn manipulation |
| `zone_tools.pl` | Zone-related helpers |
| `time_tools.pl` | Time conversion utilities |
| `text_formatting.pl` | Text formatting helpers |
| `popup_window_utils.pl` | Popup window helpers |
| `group_utility.pl` | Group helper functions |
| `formation_tools.pl` | NPC formation positioning |
| `directional.pl` | Directional calculations |

### Special Plugins

| Plugin | Purpose |
|--------|---------|
| `Instances.pl` | `plugin::SendToInstance()` -- instance zone transport |
| `MySQL.pl` | Direct MySQL query helpers |
| `Doors_Manip.pl` | Door manipulation utilities |
| `Task_Utils.pl` | Task system helpers |
| `MP3.pl` | Music/sound playback |
| `DiaWind.pl` | Dialogue window helpers |
| `ArcheryAttack.pl` | Archery combat helpers |
| `Multiple_QGlobals.pl` | Batch quest global operations |
| `Quest_Credit.pl` / `Quest_Credit2.pl` | Quest completion credit |

### How Plugin Variable Access Works

Plugins cannot directly access script variables. The `globals.pl` plugin provides `plugin::val()` and `plugin::var()` which walk the Perl call stack to find variables in the calling script's namespace:

```perl
# Inside a plugin:
my $client = plugin::val('$client');     # Returns the value of $client from the calling script
my $npc = plugin::val('$npc');           # Returns the NPC object reference
my $itemcount = plugin::var('itemcount'); # Returns a reference to %itemcount hash
```

---

## 7. Common Patterns

### Pattern 1: Simple Dialogue NPC

The most common pattern. NPC responds to "Hail" and keyword triggers.

```perl
# akk-stack/server/quests/shadowhaven/Adept_Arnthus.pl
sub EVENT_SAY {
  if ($text =~ /Hail/i) {
    quest::say("Due to the problems we have had lately with dishonorable visitors...");
  }
}
```

### Pattern 2: Item Hand-In Quest

Player gives items to NPC, NPC validates and rewards.

```perl
sub EVENT_SAY {
  if ($text =~ /hail/i) {
    quest::say("I need some [supplies] from the field.");
  }
  if ($text =~ /supplies/i) {
    quest::say("Bring me 4 bone chips and I will reward you.");
  }
}

sub EVENT_ITEM {
  if (plugin::check_handin(\%itemcount, 13073 => 4)) {  # 4 bone chips
    quest::say("Excellent work! Here is your reward.");
    quest::summonitem(12345);   # Reward item
    quest::exp(500);            # Experience reward
    quest::faction(123, 10);    # Faction adjustment
  }
  plugin::return_items(\%itemcount);  # Return unneeded items
}
```

### Pattern 3: Zone Progression / Flag Quest

Uses quest globals (`%qglobals`) to track multi-step progression.

```perl
# akk-stack/server/quests/poknowledge/A_Planar_Projection.pl
sub EVENT_SAY {
  if ($text =~ /Darkness Beckons/i
      && defined $qglobals{pop_pon_construct}
      && defined $qglobals{pop_pon_hedge_jezith}) {
    $client->Message(1, "Very well mortal... you shall pass into the Lair of Terris Thule");
    quest::set_zone_flag(221);
  }
}
```

### Pattern 4: Spawn + Timer Mechanics (Boss/Event NPC)

NPC sets up proximity, uses timers and signals for scripted behavior.

```perl
sub EVENT_SPAWN {
  quest::set_proximity($x - 200, $x + 200, $y - 200, $y + 200);
  quest::settimer("check_phase", 30);
}

sub EVENT_TIMER {
  if ($timer eq "check_phase") {
    if ($npc->GetHPRatio() < 50) {
      quest::say("You will not defeat me so easily!");
      quest::spawn2(999999, 0, 0, $x + 10, $y, $z, 0);  # Spawn add
      quest::stoptimer("check_phase");
    }
  }
}

sub EVENT_DEATH_COMPLETE {
  quest::signal(123456, 1);  # Signal another NPC
  quest::spawn_condition($zonesn, 1, 1);  # Enable a spawn group
}
```

### Pattern 5: Day/Night Cycle Spawn Control

```perl
# akk-stack/server/quests/global/DayNight.pl
sub EVENT_SPAWN {
  EVENT_CYCLE();
  quest::settimer(1, 20);
}

sub EVENT_TIMER {
  EVENT_CYCLE();
  quest::stoptimer(1);
}

sub EVENT_CYCLE {
  if ($zonesn eq 'commons' || $zonesn eq 'kithicor' || ...) {
    if ($zonetime < 600 || $zonetime > 1999) {
      quest::spawn_condition($zonesn, 2, 0);  # Night spawns off
      quest::spawn_condition($zonesn, 1, 1);  # Day spawns on
    } else {
      quest::spawn_condition($zonesn, 2, 1);
      quest::spawn_condition($zonesn, 1, 0);
    }
  }
}
```

### Pattern 6: Player Zone Entry

```perl
# akk-stack/server/quests/cabeast/player.pl
sub EVENT_ENTERZONE {
  if (($ulevel >= 15) && (!defined($qglobals{Wayfarer}))
      && ($client->GetStartZone() == $zoneid)) {
    $client->Message(15, "A mysterious voice whispers to you...");
  }
}
```

### Pattern 7: Global Item Click/Cast

```perl
# akk-stack/server/quests/global/items/script_11668.pl
sub EVENT_ITEM_CLICK_CAST {
  my %transmute = ();
  $transmute[11668] = 1824;  # Gauntlets -> Hammer spell
  $transmute[11669] = 1823;  # Hammer -> Gauntlets spell

  if ($itemid && $transmute[$itemid]) {
    $client->NukeItem($itemid);
    $client->CastSpell($transmute[$itemid], 0, 10, 0, 0);
  }
}
```

### Pattern 8: Spell Effect Hooks

```perl
# akk-stack/server/quests/global/spells/251.pl -- Growth spell cap
sub EVENT_SPELL_EFFECT_CLIENT {
  my $ClientID = $entity_list->GetClientByID($caster_id);
  if ($ClientID) {
    my $Target = $ClientID->GetTarget();
    DoGrowth($Target || $ClientID);
  }
}
```

### Pattern 9: Default NPC Behavior (Fallback)

The `default.pl` plugin chains to `default-actions.pl` which provides generic behaviors based on NPC name patterns:

```perl
# plugins/default.pl -- loaded as fallback for NPCs without a specific script
sub EVENT_SAY  { plugin::defaultSay(); }
sub EVENT_ITEM { plugin::defaultItem(); }
sub EVENT_DEATH { plugin::defaultDeath(); }

# plugins/default-actions.pl
sub defaultSay {
  if ($mname =~ /^Soulbinder\w/) {
    # Soulbinder dialogue
  } elsif ($mname =~ /^Guard\w/) {
    # Guard dialogue based on faction
  } elsif ($mname =~ /^Merchant\w/ || $mname =~ /^Innkeep/ || ...) {
    # Merchant greeting
  }
}
```

---

## 8. Global Scripts

### `global_player.pl`

Located at `akk-stack/server/quests/global/global_player.pl`. Runs for **all players** in **every zone**. Handles:

- **EVENT_ENTERZONE**: Wayfarer Brotherhood recruitment messages (LDoN)
- **EVENT_COMBINE_VALIDATE**: Recipe zone restrictions
- **EVENT_COMBINE_SUCCESS**: Special combine rewards (class-based)
- **EVENT_CONNECT**: Veteran AA grants based on account age

### `global_npc.lua`

The global NPC script currently exists as a Lua file, not Perl. It would handle NPC events that apply server-wide.

### Global Item and Spell Scripts

- `global/items/` -- 40+ scripts for items with special click/cast behavior
- `global/spells/` -- ~10 scripts for spells with custom effects (Growth spell size caps, etc.)

---

## 9. C++ Integration Architecture

### Embedding Architecture

```
zone process startup (main.cpp)
  |
  +-- QuestParserCollection created
  |     |
  |     +-- LuaParser registered (extension: "lua")
  |     +-- PerlembParser registered (extension: "pl")
  |
  +-- Embperl (PerlInterpreter) initialized
        |
        +-- perl_register_quest()       -- quest:: namespace (877 functions)
        +-- perl_register_mob()         -- $mob methods (557)
        +-- perl_register_client()      -- $client methods (519)
        +-- perl_register_npc()         -- $npc methods (140)
        +-- perl_register_entitylist()  -- $entity_list methods (59)
        +-- perl_register_group()       -- $group methods
        +-- perl_register_raid()        -- $raid methods
        +-- perl_register_inventory()   -- $inventory methods
        +-- perl_register_*()           -- 20+ other class registrations
```

### Event Dispatch Flow

1. Game event occurs (player says something, NPC dies, timer fires, etc.)
2. `QuestParserCollection::EventNPC()` / `EventPlayer()` / etc. is called
3. Parser checks if NPC has a loaded script; if not, searches file system (priority order above)
4. `PerlembParser::EventCommon()` is called which:
   - Determines the quest type (NPC, Player, Item, Spell, Zone, etc.)
   - Exports variables into the Perl namespace (`ExportVar`, `ExportHash`)
   - Exports quest globals (`%qglobals`)
   - Exports object references (`$npc`, `$client`, `$entity_list`)
   - Calls `SendCommands()` which invokes the Perl subroutine via `Embperl::dosub()`
5. The Perl subroutine runs, calling `quest::` functions which proxy to `quest_manager` C++ methods

### Key C++ Files

| File | Lines | Role |
|------|-------|------|
| `embparser.cpp` | ~1,800 | Event dispatch, variable export, script loading |
| `embparser.h` | 314 | PerlembParser class definition |
| `embparser_api.cpp` | 7,060 | `quest::` namespace implementation (877 overloads) |
| `embperl.cpp` | ~200 | Perl interpreter wrapper (eval, dosub, file loading) |
| `embperl.h` | 153 | Embperl class definition |
| `perl_mob.cpp` | 4,261 | $mob method bindings (557 methods) |
| `perl_client.cpp` | 3,973 | $client method bindings (519 methods) |
| `perl_npc.cpp` | 1,069 | $npc method bindings (140 methods) |
| `perl_entity.cpp` | 912 | $entity_list method bindings (59 methods) |
| `quest_parser_collection.cpp` | ~1,400 | Script file resolution, event routing |
| `quest_parser_collection.h` | 403 | QuestParserCollection class, PerlEventExportSettings |
| `quest_interface.h` | 386 | QuestInterface base class |
| `event_codes.h` | 158 | QuestEventID enum (154 events) |
| `questmgr.cpp/h` | varies | QuestManager -- the C++ implementation behind `quest::` |

### Lua Coexistence

Both Lua and Perl are registered as quest interfaces. **Lua is registered first**, giving it priority. When searching for a script file, the system checks `.lua` before `.pl` at each path location. This means:

- If both `NPC_Name.lua` and `NPC_Name.pl` exist, the Lua version is used
- Perl serves as the fallback when no Lua script exists
- The default NPC behavior (`default.pl`) is Perl
- Many zones are migrating from Perl to Lua (Qeynos zone has all `.lua` scripts)

---

## 10. Where to Start

### Writing a New Quest Script

1. **Find the zone short name** -- e.g., "qeynos" for South Qeynos
2. **Find the NPC name** -- e.g., "Guard_Fippy" (underscores replace spaces)
3. **Create the file**: `akk-stack/server/quests/{zone}/{NPC_Name}.pl`
4. **Define event subroutines**: at minimum `sub EVENT_SAY { }`
5. **Reload quests**: use `#reloadquests` in game or via Spire

### Minimal Example

```perl
# akk-stack/server/quests/qeynos/My_New_NPC.pl

sub EVENT_SAY {
  if ($text =~ /hail/i) {
    quest::say("Greetings, $name! Would you like to help me with a [task]?");
  }
  if ($text =~ /task/i) {
    quest::say("Bring me a Rusty Dagger and I shall reward you.");
  }
}

sub EVENT_ITEM {
  if (plugin::check_handin(\%itemcount, 12850 => 1)) {  # Rusty Dagger
    quest::say("Thank you, $name! Take this as your reward.");
    quest::summonitem(13005);  # Some reward
    quest::exp(100);
  }
  plugin::return_items(\%itemcount);
}
```

### Debugging

- `quest::echo(color, "message")` -- prints to server console
- `$client->Message(color, "message")` -- sends message to player
- Quest errors appear in server logs under `[QuestErrors]`
- Use `#reloadquests` to reload without restarting the zone

### Key Reference Points

- **Event list**: `eqemu/zone/event_codes.h`
- **quest:: API**: `eqemu/zone/embparser_api.cpp` -- search for `Perl__functionname`
- **$client methods**: `eqemu/zone/perl_client.cpp`
- **$mob methods**: `eqemu/zone/perl_mob.cpp`
- **$npc methods**: `eqemu/zone/perl_npc.cpp`
- **Plugin library**: `akk-stack/server/quests/plugins/`
- **Example scripts**: `akk-stack/server/quests/shadowhaven/` (largest zone)

---

## 11. Notes on Python Migration

One of the project goals is exploring Python as a quest scripting language. Key considerations:

### What Would Be Involved

1. **New Quest Interface**: Create a `PythonQuestParser` class implementing `QuestInterface` (like `PerlembParser` for Perl and `LuaParser` for Lua). Register it in `main.cpp` with extension `"py"`.

2. **Embedded Python Interpreter**: Embed CPython (or similar) into the zone process, analogous to how `Embperl` wraps `PerlInterpreter`. The `pybind11` library would be the natural analog to `perlbind`.

3. **API Binding**: Re-expose the `quest::` namespace and all object methods ($client, $npc, $mob, etc.) to Python. This is the bulk of the work -- the existing 877 `quest::` functions and ~1,300 object methods would need Python bindings.

4. **Variable Export**: Replicate the variable export system (currently `ExportVar`/`ExportHash`) for Python -- making `name`, `text`, `npc`, `client`, `qglobals`, etc. available as Python variables or function parameters.

5. **Script Migration**: Convert 3,790 Perl scripts. Most are simple enough for automated translation (regex matching, function calls). Complex scripts with Perl-specific idioms (regex operators, hash references, `$_` usage) would need manual attention.

### Scale of the Binding Work

| Component | Perl Lines | Binding Effort |
|-----------|-----------|----------------|
| `quest::` API | 7,060 lines | High -- 877 function overloads |
| `$mob->` methods | 4,261 lines | High -- 557 methods |
| `$client->` methods | 3,973 lines | High -- 519 methods |
| `$npc->` methods | 1,069 lines | Medium -- 140 methods |
| `$entity_list->` methods | 912 lines | Medium -- 59 methods |
| Other classes (15+) | ~3,000 lines | Medium -- ~200 methods total |
| Event dispatch | ~1,800 lines | Medium -- variable export logic |
| **Total** | **~22,000 lines** | Significant C++ work |

### Migration Strategy Options

- **Parallel support**: Add Python alongside Perl/Lua (like Lua was added alongside Perl). New scripts in Python, old scripts remain in Perl. The file resolution already supports multiple extensions.
- **Transpiler approach**: Write a Perl-to-Python transpiler for the simple/common patterns (90%+ of scripts follow a few patterns). Review and fix the remaining 10% manually.
- **API compatibility layer**: Design the Python API to be as close to the Perl API as possible, making script translation mostly mechanical.

### Advantages of Python

- Modern language with better tooling, testing, and IDE support
- Larger developer community
- Better string handling and data structures
- No need for `plugin::val()` hacks to access variables from plugins
- Natural class/module system instead of Perl's namespace-based plugins
- Easier to write complex quest logic (AI, state machines, etc.)
