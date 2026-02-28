# GM Commands Reference (Status 255)

Extracted from `eqemu/zone/gm_commands/*.cpp` source code. Full list: `#help` in-game.

## Movement / Zoning

| Command | Usage | Notes |
|---------|-------|-------|
| `#goto` | `#goto [x] [y] [z]` | Teleport to coordinates |
| `#goto` | `#goto [x] [y] [z] [h]` | Teleport with heading |
| `#goto` | `#goto [player_name]` | Teleport to a player (cross-zone) |
| `#goto` | `#goto` (no args) | Teleport to current target |
| `#zone` | `#zone [short_name]` | Zone to safe coords |
| `#zone` | `#zone [short_name] [x] [y] [z]` | Zone to specific coords |
| `#zone` | `#zone [zone_id]` | Zone by numeric ID |
| `#gmzone` | `#gmzone [short_name] [version] [identifier]` | Create/join GM instance |
| `#loc` | `#loc` | Show your current coordinates |

## Character

| Command | Usage | Alias | Notes |
|---------|-------|-------|-------|
| `#set level` | `#set level [Level]` | `#level` | Set character level |
| `#set hp_full` | `#set hp_full` | `#heal` | Full health |
| `#set mana_full` | `#set mana_full` | `#mana` | Full mana |
| `#set endurance_full` | `#set endurance_full` | `#endurance` | Full endurance |
| `#set invulnerable` | `#set invulnerable` | `#invul` | Toggle invulnerability |
| `#set god_mode` | `#set god_mode [on\|off]` | `#godmode` | God mode |
| `#set gm` | `#set gm [on\|off]` | `#gm` | Toggle GM flag |
| `#set gm_speed` | `#set gm_speed [on\|off]` | `#gmspeed` | Toggle GM speed |
| `#set hide_me` | `#set hide_me [on\|off]` | `#hideme` | Hide from player list |
| `#set flymode` | `#set flymode [0\|1\|2]` | `#flymode` | 0=off, 1=fly, 2=levitate |
| `#set race` | `#set race [Race ID]` | `#race` | Temporary race change |
| `#set race_permanent` | `#set race_permanent [Race ID]` | `#permarace` | Permanent race change |
| `#set class_permanent` | `#set class_permanent [Class ID]` | `#permaclass` | Permanent class change |
| `#set gender` | `#set gender [Gender ID]` | `#gender` | Temporary gender change |
| `#set skill_all_max` | `#set skill_all_max` | `#maxskills` | Max all skills |
| `#set exp` | `#set exp [aa\|exp] [Amount]` | `#setxp` | Set XP |
| `#set aa_points` | `#set aa_points [aa\|group\|raid] [Amount]` | `#setaapts` | Set AA points |
| `#set bind_point` | `#set bind_point` | `#setbind` | Set bind to current loc |
| `#set frozen` | `#set frozen [on\|off]` | `#freeze` | Freeze/unfreeze target |
| `#set haste` | `#set haste [Percentage]` | `#haste` | Set haste percentage |

## Items & Money

| Command | Usage | Notes |
|---------|-------|-------|
| `#summonitem` | `#summonitem [item_id]` | Give yourself an item |
| `#summonitem` | `#summonitem [item_id] [charges]` | Give item with charges |
| `#givemoney` | `#givemoney [plat] [gold] [silver] [copper]` | Give money to self |
| `#gearup` | `#gearup` | Auto-equip best gear |
| `#gearup` | `#gearup [expansion]` | Equip gear for expansion |
| `#grantaa` | `#grantaa` | Grant all AAs to target |

## NPCs & Spawns

| Command | Usage | Notes |
|---------|-------|-------|
| `#kill` | `#kill` | Kill current target |
| `#kill` | `#kill [entity_id]` | Kill by entity ID |
| `#depop` | `#depop` | Remove targeted NPC |
| `#depop` | `#depop [0\|1]` | 0=no respawn timer, 1=start timer |
| `#repop` | `#repop` | Respawn all NPCs in zone |
| `#repop` | `#repop force` | Force respawn all |
| `#summon` | `#summon` | Summon current target to you |
| `#summon` | `#summon [Character Name]` | Summon character (cross-zone) |
| `#npcspawn` | `#npcspawn` | Spawn NPC management |
| `#npcedit` | `#npcedit` | Edit NPC properties |

## Faction

| Command | Usage | Notes |
|---------|-------|-------|
| `#faction review` | `#faction review [criteria\|all]` | Review targeted player's faction |
| `#faction reset` | `#faction reset [faction_id]` | Reset faction to base value |
| `#faction view` | `#faction view` | View targeted NPC's primary faction |

**`#faction` is VIEW/RESET only. It CANNOT set arbitrary faction values.**
To set faction values for testing, use direct SQL:
```sql
-- Inside: docker exec -it akk-stack-mariadb-1 mysql -ueqemu -p'...' peq
INSERT INTO faction_values (char_id, faction_id, current_value)
VALUES (CHAR_ID, FACTION_ID, VALUE)
ON DUPLICATE KEY UPDATE current_value = VALUE;
-- Then rezone the character to apply.
```

## Searching

`#find [subcommand] [search text]` — search the database.

| Subcommand | Alias | Example |
|------------|-------|---------|
| `npctype` | `#fn` | `#find npctype guard` |
| `item` | `#fi` | `#find item sword` |
| `zone` | `#fz` | `#find zone everfrost` |
| `spell` | `#fs` | `#find spell fireball` |
| `faction` | `#findfaction` | `#find faction guards` |
| `race` | `#findrace` | `#find race erudite` |
| `class` | `#findclass` | `#find class wizard` |
| `aa` | `#findaa` | `#find aa firestorm` |
| `task` | `#findtask` | `#find task dragons` |
| `recipe` | `#findrecipe` | `#find recipe leather` |
| `skill` | `#findskill` | `#find skill evocation` |

## Quests & Reloading

| Command | Usage | Alias | Notes |
|---------|-------|-------|-------|
| `#reload quest` | `#reload quest` | `#rq` | Reload quests (current zone) |
| `#reload quest global` | `#reload quest global` | — | Reload across all zones |
| `#reload` | `#reload` (no args) | — | Show all reload options |

## Server

| Command | Usage | Notes |
|---------|-------|-------|
| `#worldshutdown` | `#worldshutdown` | Shut down world |
| `#zoneshutdown` | `#zoneshutdown [zonename]` | Shut down a zone |
| `#zonebootup` | `#zonebootup [zonename]` | Boot a zone |

## Information

| Command | Usage | Notes |
|---------|-------|-------|
| `#help` | `#help` | List all commands |
| `#devtools` | `#devtools` | Toggle dev tools UI |
| `#entityvariable` | `#entityvariable` | View/set entity variables |
| `#databuckets` | `#databuckets` | View/set data buckets |

## Commands That DO NOT Exist

| Guessed Command | Correct Alternative |
|-----------------|-------------------|
| `#warp` | `#goto [x] [y] [z]` |
| `#reloadquests` | `#rq` or `#reload quest` |
| `#faction set [id] [value]` | Direct SQL UPDATE (see Faction section) |

## Quick Tips

- NPC names use underscores: `Monia_Oakstone` not `Monia Oakstone`
- `#goto` works for both coordinates AND players — context determines which
- `#rq` is the fastest way to reload quest scripts after editing
- `#invul` toggles invulnerability (shortcut for `#set invulnerable`)
- `#heal` fills HP (shortcut for `#set hp_full`)
- To set faction for testing, use direct SQL then rezone
