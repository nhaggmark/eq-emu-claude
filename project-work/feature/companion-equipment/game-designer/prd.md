# Companion Equipment Management Enhancement — Product Requirements Document

> **Feature branch:** `feature/companion-equipment`
> **Author:** game-designer
> **Date:** 2026-03-07
> **Status:** Approved

---

## Problem Statement

On our 1–3 player Custom EverQuest server, companions are the backbone of every
group. They fill the roles that a full guild roster would normally cover — tank,
healer, DPS, crowd control. But the current equipment system undermines this
core experience in three ways:

1. **No slot awareness.** Equipment is treated as a single undifferentiated slot.
   Handing a companion a helmet returns whatever they last had equipped,
   regardless of slot — it could be their sword, their boots, or their ring.
   Players cannot predictably gear their companions without losing track of
   what was replaced.

2. **No equipment visibility.** The `!equipment` command does not show a
   slot-by-slot breakdown. Players have no way to see what a companion is
   wearing across all their gear slots, making it impossible to plan upgrades
   or identify gaps.

3. **Uncertain combat impact.** It is unclear whether equipped items actually
   affect a companion's combat performance (damage, AC, stats). If equipment
   is cosmetic-only, players are wasting time and loot on companions that gain
   no mechanical benefit.

For a server where 1–3 players must gear and manage a full party of companions
to tackle all Classic-through-Luclin content, these gaps make the equipment
experience frustrating and opaque. Players need the same level of equipment
management control for companions that they have for their own characters.

## Goals

1. **Per-slot equipment storage** — Companions track equipment across 19
   distinct slots matching full player character slot parity (Head, Face, Neck,
   Shoulders, Chest, Back, Arms, Wrist 1, Wrist 2, Hands, Finger 1, Finger 2,
   Legs, Feet, Waist, Primary, Secondary, Range, Ammo). Each slot holds exactly
   one item.

2. **Correct trade-window slot replacement** — When a player hands a companion
   an item, only the item currently in the matching slot is returned. If the
   target slot is empty, nothing is returned. Players never accidentally lose
   an item in a different slot.

3. **Full equipment visibility** — The `!equipment` command displays all 19
   slots with the current item name or "(empty)" for each. Players can see
   at a glance what gear their companion has and what gaps remain.

4. **Slot-aware equipment commands** — `!unequip` and any other equipment
   management commands accept a slot name (e.g., `!unequip head`,
   `!unequip primary`). Players can surgically remove specific pieces of gear.

5. **Combat stat integration** — Equipped weapons and armor measurably affect
   companion combat performance: weapon damage and delay affect melee DPS,
   armor contributes to AC, and stat bonuses from gear apply to the companion's
   effective stats. Companions with better gear are meaningfully stronger.

6. **Equipment persistence** — A companion's equipment persists through death,
   dismissal, and re-recruitment. If a player dismisses Guard Iskarr and
   re-recruits him later, Guard Iskarr still has the Longsword of Flame and
   Breastplate of Valor the player gave him. No equipment is lost on death.

7. **Class/race equipment validation** — Items equipped on companions respect
   the same class and race restrictions that apply to player characters.
   A warrior companion can equip plate armor; a magician companion cannot.
   A Halfling companion cannot equip Giant-only items. If a player tries to
   equip a restricted item, the trade is rejected with a message explaining
   why.

## Non-Goals

- **Inventory or bag slots for companions** — Companions do not get general
  inventory space, bags, or the ability to hold items beyond their equipment
  slots. They are warriors, not pack mules.

- **Advanced equipment restriction edge cases** — Basic class/race item
  restrictions are enforced (a Magician companion cannot equip plate armor, a
  Halfling companion cannot equip Giant-only items). However, edge cases around
  deity-restricted items, expansion-locked items, or required-level items are
  out of scope for this feature and may be refined later.

- **Equipment loss on death** — Companions do not drop or lose equipment when
  they die. This is a deliberate design choice for our small-group server where
  re-gearing companions after every death would be punishing.

- **Companion-to-companion trading** — Players cannot move items directly
  between two companions. Items must be unequipped to the player first.

- **Auto-equip or loot integration** — Companions do not automatically pick up
  or equip loot from kills. All equipment changes go through the player via the
  trade window or commands.

- **Augmentation support** — Augmentations on companion equipment are out of
  scope. Items are equipped as-is without augment socket management.

- **Equipment comparison or recommendation UI** — No automatic "this item is
  an upgrade" display. Players evaluate gear upgrades themselves.

## User Experience

### Player Flow

1. **Equipping an item:** The player opens the trade window with their
   companion (same as any NPC trade). They place the item in the trade window
   and confirm the trade. The system determines the correct equipment slot for
   the item. If the companion already has an item in that slot, that item is
   returned to the player's inventory. If the slot was empty, nothing is
   returned. The companion's visual appearance updates immediately.

2. **Checking equipment:** The player targets their companion and types
   `!equipment`. They see a formatted list of all 19 equipment slots with the
   item name or "(empty)" for each slot. This gives them a complete picture of
   the companion's gear state.

3. **Unequipping a specific slot:** The player types `!unequip head` (or any
   other slot name). The item in that slot is returned to the player's
   inventory, and the companion's slot becomes empty. The companion's visual
   appearance updates. If the slot was already empty, the player sees a message:
   "Guard Iskarr has nothing equipped in that slot."

4. **Unequipping all gear:** The player types `!unequip all`. All equipped
   items are returned to the player's inventory. If the player's inventory
   cannot hold all items, as many items as possible are returned and the player
   is warned that some items remain equipped.

5. **Dismissing and re-recruiting:** The player dismisses a companion who has
   a Longsword of Flame equipped. Later, they find the same NPC and recruit
   them again. When they check `!equipment`, the Longsword of Flame is still
   in the Primary slot.

6. **Companion death:** A companion dies in combat with gear equipped. When
   they are resurrected or respawn, all their equipment is intact. No items
   are lost or placed on a corpse.

### Example Scenario

A level 45 warrior is adventuring in the Burning Woods with two companions:
Guard Iskarr (a warrior) and Priest Delar (a cleric).

The warrior loots a **Mithril Helm** from a giant. They open a trade window
with Guard Iskarr and place the Mithril Helm in the trade window. Guard Iskarr
was wearing a **Rusty Helm** — the Rusty Helm is returned to the warrior's
inventory, and Guard Iskarr's appearance updates to show the Mithril Helm.

Later, the warrior loots a **Cloak of Flames** and opens a trade window with
Priest Delar. The cleric had nothing in their Back slot, so nothing is returned.
Priest Delar's appearance updates to show the cloak.

The warrior types `!equipment` while targeting Guard Iskarr and sees:

```
Guard Iskarr's Equipment:
  Head:        Mithril Helm
  Face:        (empty)
  Neck:        (empty)
  Shoulders:   (empty)
  Chest:       Breastplate of Valor
  Back:        (empty)
  Arms:        (empty)
  Wrist 1:     (empty)
  Wrist 2:     (empty)
  Hands:       (empty)
  Finger 1:    (empty)
  Finger 2:    (empty)
  Legs:        Greaves of the Guard
  Feet:        (empty)
  Waist:       (empty)
  Primary:     Longsword of Flame
  Secondary:   (empty)
  Range:       (empty)
  Ammo:        (empty)
```

The warrior notices Guard Iskarr's Secondary slot is empty and hands him a
shield via the trade window. Nothing is returned (slot was empty), and Guard
Iskarr's AC improves from the shield's stats.

Later, Guard Iskarr dies in a fight against a named mob. After the warrior
resurrects Guard Iskarr, the warrior checks `!equipment` again — all gear is
still equipped. Nothing was lost.

## Game Design Details

### Mechanics

#### Equipment Slots

Companions have 19 equipment slots matching player character slot parity:

| # | Slot Name | Slot Type | Notes |
|---|-----------|-----------|-------|
| 1 | Head | Armor | |
| 2 | Face | Armor | |
| 3 | Neck | Jewelry | |
| 4 | Shoulders | Armor | |
| 5 | Chest | Armor | |
| 6 | Back | Armor/Cloak | |
| 7 | Arms | Armor | |
| 8 | Wrist 1 | Armor/Jewelry | |
| 9 | Wrist 2 | Armor/Jewelry | |
| 10 | Hands | Armor | |
| 11 | Finger 1 | Jewelry | |
| 12 | Finger 2 | Jewelry | |
| 13 | Legs | Armor | |
| 14 | Feet | Armor | |
| 15 | Waist | Armor | |
| 16 | Primary | Weapon | Main-hand weapon |
| 17 | Secondary | Weapon/Shield | Off-hand weapon or shield |
| 18 | Range | Ranged | Bow, throwing weapon |
| 19 | Ammo | Ammunition | Arrows, bolts, throwing items |

Each slot holds exactly one item. Items are assigned to slots based on the
item's equipment slot data (the same data that determines which slot a player
can equip the item in).

#### Slot Resolution

When a player trades an item to a companion, the system must determine which
slot the item goes into:

- Items that can only go in one slot (e.g., a helmet) go directly into that
  slot.
- Items that can go in multiple slots (e.g., a ring that fits Finger 1 or
  Finger 2) go into the first available slot. If both slots are occupied, the
  item goes into the first slot (e.g., Finger 1) and displaces whatever was
  there.
- If an item cannot be equipped in any slot (e.g., a food item, a spell
  scroll), the trade is rejected and the item is returned to the player with
  a message: "[Companion Name] cannot equip that item."
- If an item has class or race restrictions that the companion does not meet
  (e.g., plate armor on a caster, Gnome-only item on a Human), the trade is
  rejected and the item is returned with a message: "[Companion Name] cannot
  use that item (class/race restricted)."

#### Trade Window Behavior

1. Player opens trade window with their companion.
2. Player places one or more items and confirms the trade.
3. For each item traded:
   a. The system determines the target slot.
   b. If the item cannot be equipped, it is returned to the player.
   c. If the target slot has an existing item, that item is returned to the
      player.
   d. The new item is placed in the target slot.
   e. The companion's visual appearance updates for visible slots.
4. If the player's inventory is full when an item needs to be returned, the
   returned item is placed on the player's cursor.

#### Command Reference

| Command | Description | Example |
|---------|-------------|---------|
| `!equipment` | Shows all 19 slots with current item or (empty) | Target companion, type `!equipment` |
| `!unequip <slot>` | Removes item from specified slot, returns to player | `!unequip head`, `!unequip primary` |
| `!unequip all` | Removes all equipped items, returns to player | `!unequip all` |

**Slot name aliases** — The following slot names should be recognized
(case-insensitive):

| Canonical Name | Accepted Aliases |
|----------------|------------------|
| head | helm, helmet |
| face | mask |
| neck | necklace |
| shoulders | shoulder |
| chest | body, torso |
| back | cloak, cape |
| arms | arm |
| wrist1 | wrist 1, leftwrist |
| wrist2 | wrist 2, rightwrist |
| hands | hand, gloves |
| finger1 | finger 1, leftfinger, ring1 |
| finger2 | finger 2, rightfinger, ring2 |
| legs | leg |
| feet | foot, boots |
| waist | belt |
| primary | mainhand, main |
| secondary | offhand, off |
| range | ranged, bow |
| ammo | ammunition, arrows |

If the player uses an unrecognized slot name, they see:
"Unknown slot name. Valid slots: head, face, neck, shoulders, chest, back,
arms, wrist1, wrist2, hands, finger1, finger2, legs, feet, waist, primary,
secondary, range, ammo"

#### Equipment Persistence

- Equipment is stored per-NPC (identified by the NPC's unique identity in the
  companion system, not just their NPC type).
- Equipment survives companion death — the companion keeps all gear when
  resurrected or respawned.
- Equipment survives dismissal — a dismissed companion retains their gear.
  Re-recruiting the same NPC restores them with all their equipment.
- The persistence mechanism is an architecture decision; from the player's
  perspective, gear simply "stays" on the companion.

#### Combat Stat Integration

Equipped items affect companion combat performance in the same way they affect
player characters:

- **Weapons:** Weapon damage and delay determine the companion's melee DPS.
  A companion wielding a Longsword of Flame deals more damage than one with a
  Rusty Short Sword.
- **Armor:** AC values from equipped armor contribute to the companion's
  effective AC, reducing incoming damage.
- **Stats:** STR, STA, AGI, DEX, WIS, INT, CHA bonuses from equipment apply
  to the companion's effective stats, influencing hit chance, damage, mana
  pool, spell effectiveness, etc.
- **HP/Mana:** HP and mana bonuses from gear increase the companion's maximum
  HP and mana pools.
- **Resists:** Fire resist, cold resist, etc. from gear add to the companion's
  effective resistances.
- **Special effects:** Haste, damage shields, proc effects, and other item
  special effects that are wearable (not click-activated) should apply to the
  companion.

The goal is that gearing a companion feels exactly like gearing a player
character — better items make a noticeable, measurable difference in combat
performance.

### Balance Considerations

#### Interaction with 1–3 Player Constraint

This feature is essential for the small-group design. With only 1–3 real
players, companions must be able to fill all party roles effectively. Proper
equipment management is the primary way players scale their companions'
power to match the content difficulty:

- **Solo player (1 player + 5 companions):** The player must be able to fully
  equip all companions to handle group content. Equipment management is
  the player's main progression lever for their entire party.
- **Duo (2 players + 4 companions):** Players split loot between themselves
  and their companions, prioritizing key roles (tank gear, healer gear).
- **Trio (3 players + 3 companions):** Companions supplement the party and
  need appropriate gear to fill their roles.

#### Power Scaling

- Equipment does not create a compound power problem because companions are
  already limited by their NPC stats and level. Gear augments their base
  capabilities rather than multiplying them exponentially.
- The same gear that makes a player character appropriately powerful for their
  level does the same for a companion. No special scaling or reduction is
  needed — if a Longsword of Flame is balanced for a level 50 warrior player,
  it is equally balanced for a level 50 warrior companion.
- Natural balance is maintained by loot availability: there is only so much
  gear available from drops, and players must distribute it across themselves
  and all their companions.

#### Preventing Abuse

- **No equipment duplication:** Items are moved from player inventory to
  companion slot (or vice versa). They are never copied.
- **No item laundering:** Items retain all their properties (no-drop status,
  lore flags, etc.) when equipped on companions. If an item is NO DROP, a
  player who loots it can equip it on a companion, but it cannot later be
  traded to another player via the companion.
- **Inventory limits on unequip:** `!unequip all` returns items only to
  available inventory space. If inventory is full, remaining items stay on the
  companion. Items are never destroyed.

### Era Compliance

This feature is fully era-compliant:

- **No post-Luclin mechanics:** Per-slot equipment is how EverQuest has always
  worked for player characters since Classic. This extends the same system to
  companions.
- **No new items:** This feature does not introduce any items. It only allows
  existing era-appropriate items to be equipped on companions.
- **Standard EQ slot model:** The 19-slot model matches the Titanium client's
  equipment slot structure exactly.
- **Trade window:** Uses the existing EQ trade window mechanic, which has been
  in the game since Classic.

## Affected Systems

- [x] C++ server source (`eqemu/`) — Companion equipment storage, combat stat
  integration, trade handler slot logic
- [x] Lua quest scripts (`akk-stack/server/quests/`) — `!equipment`,
  `!unequip` command handlers, trade event handling
- [ ] Perl quest scripts (maintenance only)
- [x] Database tables (`peq`) — Companion equipment persistence storage
- [ ] Rule values
- [ ] Server configuration
- [ ] Infrastructure / Docker

## Dependencies

- **Existing companion system** — This feature requires the companion
  recruitment system to be functional. Companions must be recruitable,
  targetable, and trade-able. The companion identity/persistence system must
  exist so equipment can be tied to a specific companion instance.

- **Trade window functionality** — The existing NPC trade window mechanic must
  work for companion NPCs.

- **Visual appearance system** — The existing system that updates NPC visual
  appearance when items are equipped must be functional (confirmed working per
  design doc).

## Open Questions

1. **How is equipment currently stored?** The architect should investigate
   whether the current single-slot system uses entity variables, a database
   table, or some other mechanism. This determines the migration path to
   per-slot storage.

2. **Do equipped items currently affect combat stats?** The architect should
   verify whether the existing equipment system is cosmetic-only or already
   wired into damage/AC/stat calculations. If cosmetic-only, combat
   integration is a larger scope item.

3. **What is the full set of equipment-related commands?** The architect should
   audit all commands that interact with companion equipment (beyond
   `!equipment` and `!unequip`) to ensure they all become slot-aware.

4. **How does the trade handler currently determine returns?** The architect
   should trace the trade handler logic to understand how it decides what to
   return to the player, so it can be modified for per-slot behavior.

5. **How are companions uniquely identified for persistence?** The persistence
   system needs a stable identifier for each companion instance (not just NPC
   type ID, since there could be multiple guards of the same type). The
   architect should determine what identifier the companion system uses.

6. **Multi-slot item resolution edge cases:** When an item can go in multiple
   slots (rings, wrists), what happens if both slots are full and the player
   trades a third ring? The design says it displaces Finger 1, but the
   architect should confirm this is implementable with the current trade system.

7. **NO DROP item handling:** Can a player equip a NO DROP item on a companion?
   If so, can the player later unequip it back to themselves? The architect
   should determine the correct behavior — the design recommendation is YES to
   both (the player already "owns" the item by virtue of having looted it).

8. **Class/race restriction enforcement:** Items in EQ have class and race
   bitmask flags. The architect should verify that companion NPCs have class
   and race values that can be checked against these item flags. If companions
   use non-standard class/race identifiers (e.g., NPC-specific values), the
   architect needs to determine how to map them to the item restriction system.

## Acceptance Criteria

- [ ] Player can equip items on a companion via the trade window, with items
  going into the correct equipment slot based on item type.
- [ ] When equipping into an occupied slot, only the item in that specific slot
  is returned to the player — not items from other slots.
- [ ] When equipping into an empty slot, no item is returned to the player.
- [ ] `!equipment` displays all 19 slots with current item name or "(empty)"
  for each slot, in the format specified in the design doc.
- [ ] `!unequip <slot>` removes the item from the specified slot and returns it
  to the player's inventory.
- [ ] `!unequip all` removes all equipped items and returns them to the
  player's inventory (as space permits).
- [ ] Slot names are case-insensitive and accept documented aliases.
- [ ] Invalid slot names produce a helpful error message listing valid names.
- [ ] Equipment persists through companion death (gear intact after
  resurrection/respawn).
- [ ] Equipment persists through companion dismissal (re-recruiting restores
  gear).
- [ ] Equipped weapons affect companion melee damage output (measurable DPS
  difference between a rusty weapon and a high-end weapon).
- [ ] Equipped armor affects companion AC (measurable damage reduction
  difference).
- [ ] Stat bonuses from equipment apply to companion effective stats.
- [ ] Companion visual appearance updates when items are equipped or unequipped
  in visible slots.
- [ ] Items that cannot be equipped in any slot are returned to the player with
  an appropriate message.
- [ ] No item duplication occurs during equip/unequip/trade operations.
- [ ] Items retain their properties (NO DROP, lore, etc.) when equipped on
  companions.
- [ ] Items with class restrictions cannot be equipped on companions of the
  wrong class (e.g., plate armor rejected on a caster companion).
- [ ] Items with race restrictions cannot be equipped on companions of the
  wrong race, with a clear rejection message.

---

## Appendix: Technical Notes for Architect

The following notes are advisory only — the architect makes all implementation
decisions.

### Existing Systems to Investigate

- The **bot system** (`bot_inventories` table, `Bot` class in `zone/bot.h`)
  already implements per-slot equipment for player-created bots. This is the
  closest existing analog and may inform the companion equipment architecture.

- The **item slot constants** in `common/emu_constants.h` define the canonical
  slot IDs used throughout the codebase. The companion system should use these
  same constants for consistency.

- The **`Lua_Companion`** class (noted in project memory as inheriting from
  `Lua_NPC`) has known luabind inheritance issues where methods like
  `GetPrimaryFaction()` resolve as nil. The architect should be aware of this
  when designing the Lua API surface for equipment management.

- The **trade event** (`event_trade` in Lua) receives `e.trade` with
  `item1..item4` as `ItemInst` objects. The current trade handler likely
  processes these items without slot awareness.

- **Data buckets** (`data_buckets` table) could be used for lightweight
  equipment persistence if a dedicated table is not warranted, though a
  structured table would be cleaner for 19 slots per companion.

### Suggested Rule Names

If configurable behavior is desired:
- `Companion:EquipmentPersistsThroughDeath` (bool, default true)
- `Companion:EquipmentPersistsThroughDismissal` (bool, default true)
- `Companion:EnforceClassRaceRestrictions` (bool, default false — for future use)

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
