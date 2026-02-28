# NPC Recruitment — Technical Research Notes

## Date: 2026-02-25
## Author: game-designer

---

## Critical Finding: Titanium Client Has No Mercenary UI

The Titanium client (`titanium_ops.h`) has **zero** mercenary-related opcodes.
Mercenary opcodes (OP_MercenaryDataUpdate, OP_MercenaryHire, OP_MercenaryTimer,
etc.) are only present in SoD+ client patches (`sod_ops.h`, `uf_ops.h`, `rof_ops.h`).

**Implication:** We CANNOT use the mercenary client window. All companion
management must happen through alternative UI: chat commands, NPC dialogue
(say-links), or repurposed existing Titanium UI elements (pet window, group window).

## Three NPC Companion Subsystems in EQEmu

### 1. Merc System (`zone/merc.h`, `zone/merc.cpp`)
- `class Merc : public NPC`
- Full combat AI with roles: TANK(1), HEALER(2), MELEEDPS(9), CASTERDPS(12)
- Stances: Passive, Balanced, Efficient, Reactive, Aggressive, Assist, Burn
- Spell lists loaded from `merc_spell_list_entries` DB table
- Stats from `merc_stats` DB table (per level/class/proficiency)
- Suspend/Unsuspend persistence across zones
- Owner tracking via `owner_char_id`
- Rule: `Mercs, AllowMercs` (default: false)
- `MAXMERCS = 1` per client
- **Server-side infrastructure is complete but NO Titanium client support**

### 2. Bot System (`zone/bot.h`, `zone/bot_command.h`)
- `class Bot : public NPC`
- Full class/race system with valid race-class combos
- Controlled via `^bot` chat commands (botcreate, botspawn, botcamp, etc.)
- Persistent DB storage (bot_data, bot_inventories, bot_spells, etc.)
- Full equipment, spell, and skill systems
- Group/raid support
- Rule: `Bots, Enabled` (default: false)
- Up to 150 bots per account
- **Works on ALL client versions including Titanium**
- Chat commands are the primary interface

### 3. Pet System
- `class Pet : public NPC` (thin subclass)
- Titanium has `OP_PetCommands` (attack, back off, follow, guard, sit, stand)
- Pet window available in Titanium client
- Limited to one per player (class pets)
- Simple AI: follows owner, attacks target

## Group Size Constraint

`MAX_GROUP_MEMBERS = 6` — hardcoded in Titanium client protocol structs
(`titanium_structs.h:764`). A group can have at most 6 members total.

For a 1-6 player server:
- 1 player → up to 5 companion slots
- 2 players → up to 4 companion slots
- 6 players → 0 companion slots (group full)

## Faction System

FACTION_VALUE enum (common/faction.h):
1. FACTION_ALLY
2. FACTION_WARMLY
3. (gap)
4. (gap)
5. FACTION_INDIFFERENTLY
6. FACTION_APPREHENSIVELY
7. FACTION_DUBIOUSLY
8. FACTION_THREATENINGLY
9. FACTION_SCOWLS

## Merc Database Tables

- merc_types — Merc archetypes (tank, healer, etc.)
- merc_subtypes — Sub-categories within types
- merc_stats — Per-level stats for each merc type/proficiency
- merc_spell_lists — Spell list definitions
- merc_spell_list_entries — Individual spells in spell lists
- merc_stance_entries — Available stances per merc type
- merc_templates — Template definitions linking type+subtype+stats
- merc_npc_types — NPC type data for merc appearances
- merc_inventory — Equipment for mercs
- merc_armorinfo — Armor appearance data
- merc_weaponinfo — Weapon appearance data
- merc_buffs — Persistent buff data
- merc_name_types — Name generation data
- merc_merchant_templates — What mercs merchants sell
- merc_merchant_template_entries — Individual merc offerings
- merc_merchant_entries — Which merchants sell mercs
- mercs — Active merc instances (per character)

## Merc Rules (ruletypes.h)

- Mercs, AllowMercs (bool, default false)
- Mercs, SuspendIntervalMS (int, 10000)
- Mercs, UpkeepIntervalMS (int, 180000)
- Mercs, ChargeMercPurchaseCost (bool, false)
- Mercs, ChargeMercUpkeepCost (bool, false)
- Mercs, AggroRadius (int, 100)
- Mercs, ScaleRate (int, 100)
- Mercs, AllowMercSuspendInCombat (bool, true)
- Mercs, MercsHasteCap (int, 100)

## Key Merc Code Patterns

LoadMercenary flow:
1. Get MercTemplate from zone->merc_templates
2. Query merc_npc_types for NPCType data at client's level
3. Copy NPCType, set name/race/gender/size/class
4. Create Merc instance at owner's position
5. Add to entity_list, join owner's group
6. Load equipment and spells

Spawn flow:
1. entity_list.AddMerc() — registers in zone entity system
2. SentPositionPacket() — makes merc visible to clients
3. MercJoinClientGroup() — adds to owner's group

## Design Implications

1. **Server-side merc infrastructure can be leveraged** for AI, stats, and
   combat behavior even though the client UI cannot be used.
2. **Chat commands (bot-style) or NPC dialogue (say-links)** must be the
   primary player interface on Titanium.
3. **Group window IS the companion management UI** — companions appear as
   group members, just like mercs and bots do.
4. **The Merc class's AI_Process() is well-suited** for companion combat
   behavior: it handles healing, tanking, DPS, medding, follow-owner.
5. **The 6-member group limit is a hard constraint** from the Titanium
   client protocol. The companion count must respect this.
