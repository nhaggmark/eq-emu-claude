# Companion Equipment Management Enhancement — Lore Notes

> **Feature branch:** `feature/companion-equipment`
> **Author:** lore-master
> **Date started:** 2026-03-07

---

## Feature Concept

This feature upgrades the companion equipment system from a single
undifferentiated slot to a full 19-slot per-slot model matching player
character equipment parity. It adds slot-aware trade behavior, equipment
visibility commands, combat stat integration, and equipment persistence
through death and dismissal.

**Lore implications are minimal.** This is primarily a mechanics/systems
feature. No new NPCs, zones, quests, items, or faction changes are
introduced. The feature extends existing EQ equipment mechanics to
companion NPCs — making them behave more like real EverQuest characters,
which is thematically consistent with the companion system's premise that
recruited NPCs are real Norrathians, not summoned constructs.

---

## Lore Research

This feature does not reference specific zones, NPCs, factions, or deities.
No lore research was required beyond confirming general EQ equipment and
trade mechanics.

### Zones

_No specific zones affected. Equipment management works identically in all
zones._

### NPCs & Characters

_No specific NPCs created or modified. The feature applies to all companion
NPCs generically._

### Factions

_No faction changes. Equipment management is faction-agnostic._

### Deities & Races

**Relevant finding:** Companion NPCs have race and class identities inherited
from their NPC type definitions. Equipment restrictions based on these
identities are lore-appropriate — a Troll Shadowknight should be able to
equip plate armor, while a High Elf Magician should not. This was flagged
as a recommendation and incorporated into the PRD as Goal #7.

### Historical Context

Per-slot equipment has been a core EverQuest mechanic since Classic (1999).
The 19-slot model (Head, Face, Neck, Shoulders, Chest, Back, Arms, Wrist x2,
Hands, Finger x2, Legs, Feet, Waist, Primary, Secondary, Range, Ammo)
matches the Titanium client's equipment slot structure exactly. Extending
this to companions introduces no anachronistic mechanics.

---

## Era Compliance Review

| Element | Era | Compliant? | Notes |
|---------|-----|------------|-------|
| 19-slot equipment model | Classic | Yes | Standard since launch |
| Trade window mechanic | Classic | Yes | Core NPC interaction since launch |
| Equipment stat integration | Classic | Yes | How items have always worked |
| Equipment persistence | Custom | N/A | Custom companion system, no era precedent to violate |
| !equipment / !unequip commands | Custom | N/A | Custom companion commands, no era content referenced |
| Class/race item restrictions | Classic | Yes | Item class/race flags have existed since Classic |

**Hard stops:** None. No element of this feature violates the Classic-through-Luclin
era lock.

---

## PRD Section Reviews

### Review: Full PRD (Initial Draft)

- **Date:** 2026-03-07
- **Verdict:** APPROVED WITH ONE RECOMMENDATION
- **Approved items:**
  - Trade interaction via trade window — standard EQ mechanic, no lore issues
  - Equipment persistence through death — thematically correct for recruited
    Norrathians (not summoned constructs)
  - Combat stat integration — fully consistent; the single-slot system was
    actually the lore-inconsistent state
  - 19-slot equipment model — standard EQ since Classic
  - !equipment display and !unequip commands — no lore content, pure mechanics
- **Issues found:**
  - Class/race equipment restrictions were listed as a Non-Goal. Allowing any
    companion to equip any item regardless of class/race would be lore-breaking.
    A Magician wearing plate armor or equipping a Wrist of the Fay Berserker
    violates EQ's class/race identity system.
- **Suggestions offered:**
  - Basic class/race item restriction enforcement should be a Goal, not a
    Non-Goal. Items already have class/race bitmask flags; the system should
    check them on equip and reject restricted items with a clear message.
- **Game-designer response:** Incorporated fully. Added Goal #7 (class/race
  equipment validation), updated Non-Goals to defer only advanced edge cases,
  added class/race check to Slot Resolution mechanics, added Open Question #8
  for architect, and added two acceptance criteria.

### Review: Revised PRD (With Class/Race Restrictions)

- **Date:** 2026-03-07
- **Verdict:** APPROVED
- **Approved items:**
  - All changes from initial review incorporated correctly
  - Class/race validation added as Goal #7 with clear rejection messaging
  - Non-Goals appropriately scoped to advanced edge cases only
  - Open Question #8 correctly flags NPC class/race bitmask mapping for architect
- **Issues found:** None
- **Suggestions offered:** None
- **Game-designer response:** N/A — no changes needed

---

## Decisions & Rationale

| # | Decision | Rationale | Alternatives Rejected |
|---|----------|-----------|----------------------|
| 1 | Equipment persists through companion death (no corpse/loot drop) | Companions are recruited Norrathians with persistent identities, not summoned constructs. A guard who dies doesn't lose his gear on respawn. Re-gearing companions after every death would be punishing for 1-3 player groups. | Equipment drops on death (too punishing for small groups), equipment drops to corpse (adds unwanted complexity) |
| 2 | Basic class/race restrictions enforced; advanced restrictions deferred | Class/race identity is core to EQ's lore and feel. A Magician in plate armor breaks immersion. However, edge cases (deity restrictions, expansion locks, required levels) add significant complexity for marginal lore benefit and can be added later. | No restrictions at all (lore-breaking), full restriction enforcement including deity/expansion/level (over-scoped) |

---

## Final Sign-Off

- **Date:** 2026-03-07
- **Verdict:** APPROVED
- **Summary:** The Companion Equipment Management Enhancement PRD is fully
  lore-compliant. The feature introduces no anachronistic mechanics, references
  no post-Luclin content, and enhances thematic consistency by making companion
  NPCs behave more like real EverQuest characters. The one lore concern
  (class/race restrictions) was identified during initial review and incorporated
  into the PRD before final sign-off. No remaining lore blockers.
- **Remaining concerns:** When class/race restriction enforcement is implemented,
  the architect should verify that NPC class/race identifiers map correctly to
  item restriction bitmasks. NPC type definitions may use different class/race
  values than player characters. This is a technical concern, not a lore concern,
  and is captured in PRD Open Question #8.

---

## Context for Next Phase

- **No dialogue or narrative content** in this feature. The architect and
  implementation team do not need to consult lore for text/tone.
- **Rejection messages** when items fail class/race checks should be
  straightforward and mechanical (e.g., "[Companion Name] cannot use that item
  (class/race restricted).") — no flavor text or lore-specific messaging needed.
- **Item names in !equipment output** should use the item's canonical database
  name. No renaming or lore-localization needed.
- **No faction implications.** Equipping a companion with faction-affiliated gear
  (e.g., a Crushbone Belt) does not change the companion's faction standing.
  Equipment is purely mechanical, not political.
