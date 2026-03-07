# Companion Equipment Management Enhancement

**Date:** 2026-03-07
**Status:** Approved

## Core Problem

The current companion equipment system treats equipment as a single slot.
Handing a companion any item returns whatever they previously had, regardless
of slot. The `!equipment` and `!unequip` commands aren't slot-aware. It's
unclear whether equipped items affect combat calculations.

## Goals

1. **Slot-aware equipment storage** — Companions track equipment per-slot,
   matching the full player character slot list: Head, Face, Neck, Shoulders,
   Chest, Back, Arms, Wrists (x2), Hands, Fingers (x2), Legs, Feet, Waist,
   Primary, Secondary, Range, Ammo.

2. **Correct trade behavior** — Handing a companion a helmet only returns
   their current helmet, not their sword. If the slot is empty, nothing
   is returned.

3. **`!equipment` display** — Shows all slots with current equipment
   (or "empty" for unoccupied slots). All slots shown, even empty ones.

4. **Slot-aware commands** — `!unequip` and related equipment commands
   accept a slot name (e.g., `!unequip head`). The architect should audit
   the full set of equipment-related commands and make them slot-aware.

5. **Combat integration** — Verify and ensure equipped weapons and armor
   are used in damage calculations (attack damage, AC, stats). If currently
   cosmetic-only, wire equipment stats into combat.

6. **Persistence** — Equipment persists on the NPC through death and
   dismissal. Re-recruiting an NPC preserves their gear.

## Equipment Slots

Full player character parity:

| Slot | Notes |
|------|-------|
| Head | |
| Face | |
| Neck | |
| Shoulders | |
| Chest | |
| Back | |
| Arms | |
| Wrist 1 | |
| Wrist 2 | |
| Hands | |
| Finger 1 | |
| Finger 2 | |
| Legs | |
| Feet | |
| Waist | |
| Primary | Weapon |
| Secondary | Weapon/shield |
| Range | Bow/throwing |
| Ammo | Arrows/etc |

## Trade Window Behavior

- Player drags item to trade window and hits trade
- System determines the correct slot for the item
- If the companion already has an item in that slot, return ONLY that
  item to the player's inventory
- If the slot is empty, nothing is returned
- Visual appearance updates as it does today

## `!equipment` Output Format

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

## Persistence

- Equipment stays on the NPC, not the player
- Dismissing a companion does not remove their gear
- Re-recruiting an NPC preserves their gear
- Companion death preserves equipment (respawn with same gear)
- Persistence mechanism (database, etc.) is an architecture decision

## What Doesn't Change

- Trade window workflow (drag item, hit trade)
- Visual appearance updates
- Existing class/race equip restrictions (if any)

## Scope for Architect

The architect should investigate and determine:

- How equipment is currently stored (single item? database? entity variable?)
- Whether equipped items currently affect combat stats or are cosmetic-only
- The full set of equipment-related commands that need slot-awareness
- How persistence currently works and what needs to change for per-slot storage
- How the trade handler determines what to return to the player
- Whether items need class/race validation before equipping
