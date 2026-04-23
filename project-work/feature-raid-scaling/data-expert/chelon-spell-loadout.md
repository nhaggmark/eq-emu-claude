# Chelon Spell Scroll Loadout

**Date:** 2026-04-22 (v2 — combat-priority reorder)
**Character:** Chelon (character_id=6, class=14 Enchanter, level=52)
**Branch:** feature/raid-scaling

## Summary

Inserted 9 bags (Pouch of Quellious, item_id=57261) into Chelon's main inventory
slots 22-30, then inserted 90 Enchanter spell scrolls ordered by raid combat
priority (mana regen, runes, haste, mez, tash/debuffs, stuns, nukes, group
utility, animations, tradeskill enchants). Illusion/cosmetic scrolls are fully
excluded from the 90 slots.

| Stat | Value |
|------|-------|
| Character ID | 6 |
| Class | 14 (Enchanter) |
| Level | 52 |
| Enchanter spells up to level 52 in spells_new | 321 |
| Already in spellbook (character_spells) | 119 |
| Missing from spellbook | 202 |
| Missing spells with no scroll item in items table | 35 |
| Missing spells with scroll available | 167 |
| Bags inserted (slots 22-30) | 9 |
| Bag capacity (9 bags x 10 slots) | 90 |
| Scrolls inserted | 90 |
| Overflow scrolls (not inserted, bags full) | 77 |
| -- Overflow: illusion/cosmetic | 50 |
| -- Overflow: Focus spell line | 17 |
| -- Overflow: Wuggan's (item appraisal) line | 9 |
| -- Overflow: Mass Enchant (low-tier metals) | 1 |

## Version History

- **v1 (2026-04-22):** Initial insert ordered by level_req ASC, name ASC — first 90 slots filled with illusion scrolls (42 illusion/cosmetic before any combat spell)
- **v2 (2026-04-22):** Reversed v1 and reloaded with combat-priority ordering — all illusion/cosmetic scrolls pushed to overflow

## Bags Inserted

Item: **Pouch of Quellious** (item_id=57261)
- bagslots=10, bagtype=0 (general purpose, any item), bagsize=4 (large), bagwr=0
- Inserted in main inventory slots 22, 23, 24, 25, 26, 27, 28, 29, 30
- charges=0 (bags do not use charges)

## Slot Formula Used

```
slot_id = (bag_inventory_slot * 200) - 590 + bag_index
```

| Bag Slot | Base Slot ID | Slot Range |
|----------|-------------|------------|
| 22 | 3810 | 3810-3819 |
| 23 | 4010 | 4010-4019 |
| 24 | 4210 | 4210-4219 |
| 25 | 4410 | 4410-4419 |
| 26 | 4610 | 4610-4619 |
| 27 | 4810 | 4810-4819 |
| 28 | 5010 | 5010-5019 |
| 29 | 5210 | 5210-5219 |
| 30 | 5410 | 5410-5419 |

All scroll inserts used charges=1 (required for scrolls to be visible in Titanium client).

## Scrolls Inserted (90 total — combat-priority order)

### TIER 1 — Mana Regen (slots 3810-4010)

| Slot | Item ID | Spell | Level |
|------|---------|-------|-------|
| 3810 | 15695 | Distill Mana | 38 |
| 3811 | 15696 | Purify Mana | 45 |
| 3812 | 19379 | Clarity II | 52 |
| 3813 | 19386 | Boon of the Clear Mind | 42 |
| 3814 | 7661 | Intellectual Advancement | 11 |
| 3815 | 7662 | Intellectual Superiority | 17 |
| 3816 | 59529 | Mass Clarify Mana | 29 |
| 3817 | 59530 | Mass Crystallize Mana | 20 |
| 3818 | 59531 | Mass Distill Mana | 39 |
| 3819 | 59557 | Mass Purify Mana | 47 |
| 4010 | 59558 | Mass Thicken Mana | 11 |

### TIER 2 — Runes (slots 4011-4015)

| Slot | Item ID | Spell | Level |
|------|---------|-------|-------|
| 4011 | 15483 | Rune III | 33 |
| 4012 | 15484 | Rune IV | 40 |
| 4013 | 19377 | Rune V | 52 |
| 4014 | 59641 | Ward of Alendar | 29 |
| 4015 | 59642 | Guard of Alendar | 44 |

### TIER 3 — Haste / Speed (slots 4016-4018)

| Slot | Item ID | Spell | Level |
|------|---------|-------|-------|
| 4016 | 15171 | Celerity | 39 |
| 4017 | 15172 | Swift Like the Wind | 47 |
| 4018 | 15176 | Berserker Spirit | 47 |

### TIER 4 — Mez / Stun (slots 4019-4219)

| Slot | Item ID | Spell | Level |
|------|---------|-------|-------|
| 4019 | 15132 | Immobilize | 39 |
| 4210 | 15133 | Paralyzing Earth | 45 |
| 4211 | 15163 | Incapacitate | 40 |
| 4212 | 15183 | Cajoling Whispers | 37 |
| 4213 | 15192 | Mind Wipe | 36 |
| 4214 | 15193 | Blanket of Forgetfulness | 46 |
| 4215 | 15194 | Reoccurring Amnesia | 45 |
| 4216 | 15195 | Gasping Embrace | 47 |
| 4217 | 15673 | Discordant Mind | 43 |
| 4218 | 19380 | Fascination | 52 |
| 4219 | 59622 | Bounce | 43 |

### TIER 5 — Charm (slots 4410-4412)

| Slot | Item ID | Spell | Level |
|------|---------|-------|-------|
| 4410 | 15184 | Allure | 46 |
| 4411 | 15647 | Adorning Grace | 46 |
| 4412 | 30474 | Boon of the Garou | 40 |

### TIER 6 — Tash / Debuffs (slots 4413-4610)

| Slot | Item ID | Spell | Level |
|------|---------|-------|-------|
| 4413 | 15025 | Pillage Enchantment | 42 |
| 4414 | 15045 | Pacify | 35 |
| 4415 | 15127 | Invoke Fear | 35 |
| 4416 | 15175 | Insight | 35 |
| 4417 | 15180 | Insipid Weakness | 34 |
| 4418 | 15181 | Weakness | 42 |
| 4419 | 15186 | Shiftless Deeds | 41 |
| 4610 | 15678 | Tashania | 41 |

### TIER 7 — Damage / Nukes (slots 4611-4616)

| Slot | Item ID | Spell | Level |
|------|---------|-------|-------|
| 4611 | 15073 | Gravity Flux | 36 |
| 4612 | 15178 | Color Skew | 43 |
| 4613 | 15648 | Rampage | 38 |
| 4614 | 19378 | Color Slant | 52 |
| 4615 | 59016 | Scryer's Trespass | 52 |
| 4616 | 59645 | Ordinance | 52 |

### TIER 8 — Group Combat Utility / Buffs (slots 4617-5010)

| Slot | Item ID | Spell | Level |
|------|---------|-------|-------|
| 4617 | 15033 | Brilliance | 41 |
| 4618 | 15064 | Resist Magic | 37 |
| 4619 | 15067 | Arch Shielding | 40 |
| 4810 | 15072 | Group Resist Magic | 48 |
| 4811 | 15653 | Shade | 37 |
| 4812 | 15654 | Shadow | 48 |
| 4813 | 30406 | Improved Invisibility | 50 |
| 4814 | 19215 | Wake of Tranquility | 51 |
| 4815 | 19374 | Theft of Thought | 50 |
| 4816 | 19376 | Collaboration | 50 |
| 4817 | 7663 | Haunting Visage | 26 |
| 4818 | 7664 | Calming Visage | 36 |
| 4819 | 7665 | Illusion: Imp | 45 |
| 5010 | 7666 | Trickster's Augmentation | 52 |

### TIER 9 — Animations / Pets / Utility (slots 5011-5016)

| Slot | Item ID | Spell | Level |
|------|---------|-------|-------|
| 5011 | 15688 | Aanya's Animation | 37 |
| 5012 | 15689 | Yegoreff's Animation | 41 |
| 5013 | 15690 | Kintaz's Animation | 48 |
| 5014 | 19502 | Summon Companion | 43 |
| 5015 | 26970 | Tiny Companion | 19 |
| 5016 | 26972 | Entrancing Lights | 30 |

### TIER 10 — Tradeskill Enchanting + Combat Support (slots 5017-5216)

| Slot | Item ID | Spell | Level |
|------|---------|-------|-------|
| 5017 | 30407 | Wandering Mind | 38 |
| 5018 | 30408 | Gift of Magic | 34 |
| 5019 | 15797 | Enchant Velium | 43 |
| 5210 | 15889 | Enchant Mithril | 48 |
| 5211 | 15890 | Enchant Adamantite | 48 |
| 5212 | 15892 | Enchant Steel | 46 |
| 5213 | 15893 | Enchant Brellium | 49 |
| 5214 | 19523 | Everlasting Breath | 51 |
| 5215 | 19534 | Levitation | 51 |
| 5216 | 59015 | Leviathan Eyes | 44 |

### TIER 11 — Fill slots (Dazzle + Mass Enchants) (slots 5217-5419)

| Slot | Item ID | Spell | Level |
|------|---------|-------|-------|
| 5217 | 15190 | Dazzle | 47 |
| 5218 | 59532 | Mass Enchant Adamantite | 49 |
| 5219 | 59533 | Mass Enchant Brellium | 49 |
| 5410 | 59537 | Mass Enchant Mithril | 49 |
| 5411 | 59540 | Mass Enchant Steel | 49 |
| 5412 | 37595 | Greater Mass Enchant Velium | 44 |
| 5413 | 59541 | Mass Enchant Velium | 44 |
| 5414 | 37593 | Greater Mass Enchant Platinum | 38 |
| 5415 | 59538 | Mass Enchant Platinum | 32 |
| 5416 | 37592 | Greater Mass Enchant Gold | 28 |
| 5417 | 59536 | Mass Enchant Gold | 24 |
| 5418 | 37591 | Greater Mass Enchant Electrum | 19 |
| 5419 | 59535 | Mass Enchant Electrum | 14 |

## Overflow Scrolls (77 total — not inserted)

### Non-Illusion Overflow (27 scrolls) — low combat priority

All Focus spell line (crude through spellcaster-level) and Wuggan's identification
line. None of these are needed for a Lady Vox fight.

| Spell | Level | Item ID |
|-------|-------|---------|
| Mass Enchant Silver | 7 | 59539 |
| Mass Enchant Clay | 8 | 59534 |
| Greater Mass Enchant Silver | 11 | 37594 |
| Wuggan's Lesser Appraisal | 13 | 59660 |
| Wuggan's Lesser Discombobulation | 14 | 59672 |
| Wuggan's Lesser Extrication | 14 | 59684 |
| Focus Crude Spellcaster's Empowering Essence | 16 | 36366 |
| Focus Makeshift Spellcaster's Empowering Essence | 16 | 36367 |
| Focus Primitive Spellcaster's Empowering Essence | 16 | 36364 |
| Focus Rudimentary Spellcaster's Empowering Essence | 16 | 36365 |
| Focus Mass Crude Spellcaster's Empowering Essence | 20 | 36379 |
| Focus Mass Makeshift Spellcaster's Empowering Essence | 20 | 36380 |
| Focus Mass Primitive Spellcaster's Empowering Essence | 20 | 36377 |
| Focus Mass Rudimentary Spellcaster's Empowering Essence | 20 | 36378 |
| Wuggan's Appraisal | 23 | 59661 |
| Wuggan's Discombobulation | 24 | 59673 |
| Wuggan's Extrication | 24 | 59685 |
| Focus Elementary Spellcaster's Empowering Essence | 25 | 36368 |
| Focus Mass Elementary Spellcaster's Empowering Essence | 29 | 36381 |
| Wuggan's Greater Appraisal | 33 | 59662 |
| Wuggan's Greater Discombobulation | 34 | 59674 |
| Wuggan's Greater Extrication | 34 | 59686 |
| Focus Modest Spellcaster's Empowering Essence | 35 | 36369 |
| Focus Mass Modest Spellcaster's Empowering Essence | 39 | 36382 |
| Focus Simple Spellcaster's Empowering Essence | 45 | 36370 |
| Focus Mass Simple Spellcaster's Empowering Essence | 49 | 36383 |
| Focus Spellcaster's Empowering Essence | 50 | 36371 |

### Cosmetic / Illusion Overflow (50 scrolls)

All 50 illusion scrolls overflow. Names: Illusion: Arcane Scrykin, Aviak Rook,
Banshee (x2), Barraki, Bixie Drone, Bixie Queen, Blood Runed Gargoyle, Brownie,
Brownie Noble, Butterfly, Centaur, Corrupted Shiliskin, Crystal Golem,
Crystalline Sessiloid, Crystalline Trichordont, Drachnid, Drakkin of Draton'ra,
Drakkin of Osh'vir, Dry Bone, Eagle Aviak, Embattled Minotaur, Fairy,
Fire Elemental, Frost Goblin, Gelatinous Cube, Gelidran, Gnomish Pirate,
Gunthak Pirate, Guktan, Hideous Harpy, Hooded Scrykin, Ice Golem, Iksar Skeleton,
Kobold King, Ogre Pirate, Primal Kerran, Pyrilen, Raptor Predator, Recluse Spider,
Scaled Wolf, Silver Gnomework, Siren Enticer, Snow Kobold, Spectre, Spirit Wolf,
Spirited Satyr, Vitrik, Werewolf, Visage of the Daft Trickster.

## Spells With No Scroll in Items Table (35 total, not insertable)

These spells are on Enchanter's class list up to level 52 but have no itemtype=20
scroll with matching scrolleffect in the items table (likely quest/faction/vendor rewards).

## Reversal SQL

To undo everything inserted here (bags and scrolls):
```sql
DELETE FROM inventory
WHERE character_id = 6
  AND (slot_id BETWEEN 22 AND 30
    OR slot_id BETWEEN 3810 AND 3819
    OR slot_id BETWEEN 4010 AND 4019
    OR slot_id BETWEEN 4210 AND 4219
    OR slot_id BETWEEN 4410 AND 4419
    OR slot_id BETWEEN 4610 AND 4619
    OR slot_id BETWEEN 4810 AND 4819
    OR slot_id BETWEEN 5010 AND 5019
    OR slot_id BETWEEN 5210 AND 5219
    OR slot_id BETWEEN 5410 AND 5419
  );
```

## Notes

- Chelon had zero inventory items before this operation.
- All 90 scroll slots contain combat/utility spells — zero illusion scrolls inserted.
- Overflow is entirely low-priority material (Focus lines, Wuggan's ID utilities, illusions).
- No important raid spells are in overflow — all mez, charm, tash, haste, rune, mana regen,
  and damage spells fit within the 90-slot cap.
- Chelon needs to zone or relog for the new items to appear in her bags.
