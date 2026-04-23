# Chelon Spell Scroll Loadout

**Date:** 2026-04-22
**Character:** Chelon (character_id=6, class=14 Enchanter, level=52)
**Branch:** feature/raid-scaling

## Summary

Inserted 9 bags (Pouch of Quellious, item_id=57261) into Chelon's main inventory
slots 22-30, then inserted 90 Enchanter spell scrolls into those bags.

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

## Scrolls Inserted (90 total, ordered by level_req ASC, name ASC)

| # | Slot ID | Item ID | Item Name | Spell ID | Spell Name | Level Req |
|---|---------|---------|-----------|----------|------------|-----------|
| 1 | 3810 | 57334 | Spell: Illusion: Arcane Scrykin | 27719 | Illusion: Arcane Scrykin | 1 |
| 2 | 3811 | 57337 | Spell: Illusion: Aviak Rook | 27722 | Illusion: Aviak Rook | 1 |
| 3 | 3812 | 57332 | Spell: Illusion: Banshee | 27717 | Illusion: Banshee | 1 |
| 4 | 3813 | 57350 | Spell: Illusion: Banshee | 27735 | Illusion: Banshee | 1 |
| 5 | 3814 | 57347 | Spell: Illusion: Barraki | 27732 | Illusion: Barraki | 1 |
| 6 | 3815 | 57327 | Spell: Illusion: Bixie Drone | 27712 | Illusion: Bixie Drone | 1 |
| 7 | 3816 | 57326 | Spell: Illusion: Bixie Queen | 27711 | Illusion: Bixie Queen | 1 |
| 8 | 3817 | 57351 | Spell: Illusion: Blood Runed Gargoyle | 27736 | Illusion: Blood Runed Gargoyle | 1 |
| 9 | 3818 | 57328 | Spell: Illusion: Brownie | 27713 | Illusion: Brownie | 1 |
| 10 | 3819 | 57329 | Spell: Illusion: Brownie Noble | 27714 | Illusion: Brownie Noble | 1 |
| 11 | 4010 | 57138 | Spell: Illusion: Butterfly | 42282 | Illusion: Butterfly | 1 |
| 12 | 4011 | 57349 | Spell: Illusion: Centaur | 27734 | Illusion: Centaur | 1 |
| 13 | 4012 | 57335 | Spell: Illusion: Corrupted Shiliskin | 27720 | Illusion: Corrupted Shiliskin | 1 |
| 14 | 4013 | 57333 | Spell: Illusion: Crystal Golem | 27718 | Illusion: Crystal Golem | 1 |
| 15 | 4014 | 57361 | Spell: Illusion: Crystalline Sessiloid | 27747 | Illusion: Crystalline Sessiloid | 1 |
| 16 | 4015 | 57359 | Spell: Illusion: Crystalline Trichordont | 27745 | Illusion: Crystalline Trichordont | 1 |
| 17 | 4016 | 57357 | Spell: Illusion: Drachnid | 27743 | Illusion: Drachnid | 1 |
| 18 | 4017 | 57352 | Spell: Illusion: Eagle Aviak | 27737 | Illusion: Eagle Aviak | 1 |
| 19 | 4018 | 57344 | Spell: Illusion: Embattled Minotaur | 27729 | Illusion: Embattled Minotaur | 1 |
| 20 | 4019 | 57319 | Spell: Illusion: Fairy | 27704 | Illusion: Fairy | 1 |
| 21 | 4210 | 57339 | Spell: Illusion: Frost Goblin | 27724 | Illusion: Frost Goblin | 1 |
| 22 | 4211 | 55745 | Scroll: Illusion: Gelatinous Cube | 33999 | Illusion: Gelatinous Cube | 1 |
| 23 | 4212 | 57331 | Spell: Illusion: Gelidran | 27716 | Illusion: Gelidran | 1 |
| 24 | 4213 | 57343 | Spell: Illusion: Gnomish Pirate | 27728 | Illusion: Gnomish Pirate | 1 |
| 25 | 4214 | 57136 | Spell: Illusion: Gunthak Pirate | 39280 | Illusion: Gunthak Pirate | 1 |
| 26 | 4215 | 57321 | Spell: Illusion: Hideous Harpy | 27706 | Illusion: Hideous Harpy | 1 |
| 27 | 4216 | 57323 | Spell: Illusion: Hooded Scrykin | 27708 | Illusion: Hooded Scrykin | 1 |
| 28 | 4217 | 57336 | Spell: Illusion: Ice Golem | 27721 | Illusion: Ice Golem | 1 |
| 29 | 4218 | 57340 | Spell: Illusion: Iksar Skeleton | 27725 | Illusion: Iksar Skeleton | 1 |
| 30 | 4219 | 57325 | Spell: Illusion: Kobold King | 27710 | Illusion: Kobold King | 1 |
| 31 | 4410 | 57358 | Spell: Illusion: Ogre Pirate | 27744 | Illusion: Ogre Pirate | 1 |
| 32 | 4411 | 57346 | Spell: Illusion: Primal Kerran | 27731 | Illusion: Primal Kerran | 1 |
| 33 | 4412 | 57330 | Spell: Illusion: Pyrilen | 27715 | Illusion: Pyrilen | 1 |
| 34 | 4413 | 57342 | Spell: Illusion: Raptor Predator | 27727 | Illusion: Raptor Predator | 1 |
| 35 | 4414 | 57356 | Spell: Illusion: Recluse Spider | 27742 | Illusion: Recluse Spider | 1 |
| 36 | 4415 | 117702 | Spell: Illusion: Silver Gnomework | 37869 | Illusion: Silver Gnomework | 1 |
| 37 | 4416 | 57338 | Spell: Illusion: Siren Enticer | 27723 | Illusion: Siren Enticer | 1 |
| 38 | 4417 | 57354 | Spell: Illusion: Snow Kobold | 27740 | Illusion: Snow Kobold | 1 |
| 39 | 4418 | 57317 | Spell: Illusion: Spectre | 27702 | Illusion: Spectre | 1 |
| 40 | 4419 | 57345 | Spell: Illusion: Spirited Satyr | 27730 | Illusion: Spirited Satyr | 1 |
| 41 | 4610 | 57360 | Spell: Illusion: Vitrik | 27746 | Illusion: Vitrik | 1 |
| 42 | 4611 | 64579 | Spell: Illusion: Daft Trickster | 32200 | Visage of the Daft Trickster | 1 |
| 43 | 4612 | 59539 | Spell: Mass Enchant Silver | 3991 | Mass Enchant Silver | 7 |
| 44 | 4613 | 59534 | Spell: Mass Enchant Clay | 3986 | Mass Enchant Clay | 8 |
| 45 | 4614 | 37594 | Spell: Greater Mass Enchant Silver | 7988 | Greater Mass Enchant Silver | 11 |
| 46 | 4615 | 7661 | Spell: Intellectual Advancement | 2561 | Intellectual Advancement | 11 |
| 47 | 4616 | 59558 | Spell: Mass Thicken Mana | 4010 | Mass Thicken Mana | 11 |
| 48 | 4617 | 59660 | Spell: Wuggan's Lesser Appraisal | 4255 | Wuggan's Lesser Appraisal | 13 |
| 49 | 4618 | 59535 | Spell: Mass Enchant Electrum | 3987 | Mass Enchant Electrum | 14 |
| 50 | 4619 | 59672 | Spell: Wuggan's Lesser Discombobulation | 4267 | Wuggan's Lesser Discombobulation | 14 |
| 51 | 4810 | 59684 | Spell: Wuggan's Lesser Extrication | 4279 | Wuggan's Lesser Extrication | 14 |
| 52 | 4811 | 36366 | Spell: Focus Crude Spellcaster's Essence | 7676 | Focus Crude Spellcaster's Empowering Essence | 16 |
| 53 | 4812 | 36367 | Spell: Focus Makeshift Spellcaster's Essence | 7677 | Focus Makeshift Spellcaster's Empowering Essence | 16 |
| 54 | 4813 | 36364 | Spell: Focus Primitive Spellcaster's Essence | 7674 | Focus Primitive Spellcaster's Empowering Essence | 16 |
| 55 | 4814 | 36365 | Spell: Focus Rudimentary Spellcaster's Essence | 7675 | Focus Rudimentary Spellcaster's Empowering Essence | 16 |
| 56 | 4815 | 7662 | Spell: Intellectual Superiority | 2562 | Intellectual Superiority | 17 |
| 57 | 4816 | 37591 | Spell: Greater Mass Enchant Electrum | 7985 | Greater Mass Enchant Electrum | 19 |
| 58 | 4817 | 26970 | Spell: Tiny Companion | 3583 | Tiny Companion | 19 |
| 59 | 4818 | 36379 | Spell: Focus Mass Crude Spellcaster's Essence | 7689 | Focus Mass Crude Spellcaster's Empowering Essence | 20 |
| 60 | 4819 | 36380 | Spell: Focus Mass Makeshift Spellcaster's Ess. | 7690 | Focus Mass Makeshift Spellcaster's Empowering Essence | 20 |
| 61 | 5010 | 36377 | Spell: Focus Mass Primitive Spellcaster's Essence | 7687 | Focus Mass Primitive Spellcaster's Empowering Essence | 20 |
| 62 | 5011 | 36378 | Spell: Focus Mass Rudimentary Spellcaster's Ess. | 7688 | Focus Mass Rudimentary Spellcaster's Empowering Essence | 20 |
| 63 | 5012 | 59530 | Spell: Mass Crystallize Mana | 3982 | Mass Crystallize Mana | 20 |
| 64 | 5013 | 59661 | Spell: Wuggan's Appraisal | 4256 | Wuggan's Appraisal | 23 |
| 65 | 5014 | 59536 | Spell: Mass Enchant Gold | 3988 | Mass Enchant Gold | 24 |
| 66 | 5015 | 59673 | Spell: Wuggan's Discombobulation | 4268 | Wuggan's Discombobulation | 24 |
| 67 | 5016 | 59685 | Spell: Wuggan's Extrication | 4280 | Wuggan's Extrication | 24 |
| 68 | 5017 | 36368 | Spell: Focus Elementary Spellcaster's Essence | 7678 | Focus Elementary Spellcaster's Empowering Essence | 25 |
| 69 | 5018 | 7663 | Spell: Haunting Visage | 2563 | Haunting Visage | 26 |
| 70 | 5019 | 37592 | Spell: Greater Mass Enchant Gold | 7986 | Greater Mass Enchant Gold | 28 |
| 71 | 5210 | 36381 | Spell: Focus Mass Elementary Spellcaster's Essence | 7691 | Focus Mass Elementary Spellcaster's Empowering Essence | 29 |
| 72 | 5211 | 59529 | Spell: Mass Clarify Mana | 3981 | Mass Clarify Mana | 29 |
| 73 | 5212 | 59641 | Spell: Ward of Alendar | 4073 | Ward of Alendar | 29 |
| 74 | 5213 | 26972 | Spell: Entrancing Lights | 3585 | Entrancing Lights | 30 |
| 75 | 5214 | 53590 | Devious Drakkin Disguise | 10605 | Illusion: Drakkin of Draton`ra | 30 |
| 76 | 5215 | 78943 | Spell: Illusion: Drakkin Rk. II | 10606 | Illusion: Drakkin of Osh`vir | 30 |
| 77 | 5216 | 59538 | Spell: Mass Enchant Platinum | 3990 | Mass Enchant Platinum | 32 |
| 78 | 5217 | 15598 | Spell: Illusion: Fire Elemental | 598 | Illusion: Fire Elemental | 33 |
| 79 | 5218 | 15483 | Spell: Rune III | 483 | Rune III | 33 |
| 80 | 5219 | 59662 | Spell: Wuggan's Greater Appraisal | 4257 | Wuggan's Greater Appraisal | 33 |
| 81 | 5410 | 30408 | Spell: Gift of Magic | 1408 | Gift of Magic | 34 |
| 82 | 5411 | 15180 | Spell: Insipid Weakness | 180 | Insipid Weakness | 34 |
| 83 | 5412 | 59674 | Spell: Wuggan's Greater Discombobulation | 4269 | Wuggan's Greater Discombobulation | 34 |
| 84 | 5413 | 59686 | Spell: Wuggan's Greater Extrication | 4281 | Wuggan's Greater Extrication | 34 |
| 85 | 5414 | 36369 | Spell: Focus Modest Spellcaster's Essence | 7679 | Focus Modest Spellcaster's Empowering Essence | 35 |
| 86 | 5415 | 15175 | Spell: Insight | 175 | Insight | 35 |
| 87 | 5416 | 15127 | Spell: Invoke Fear | 127 | Invoke Fear | 35 |
| 88 | 5417 | 15045 | Spell: Pacify | 45 | Pacify | 35 |
| 89 | 5418 | 7664 | Spell: Calming Visage | 2564 | Calming Visage | 36 |
| 90 | 5419 | 15073 | Spell: Gravity Flux | 73 | Gravity Flux | 36 |

## Overflow Scrolls (77 total - bags full, not inserted)

These spells are available as scrolls in the items table but did not fit in the 9 bags.
To insert them, give Chelon more bag space or clear some bag slots and re-run.

| Spell ID | Spell Name | Level Req | Item ID | Item Name |
|----------|------------|-----------|---------|-----------|
| 192 | Mind Wipe | 36 | 15192 | Spell: Mind Wipe |
| 688 | Aanya's Animation | 37 | 15688 | Spell: Aanya`s Animation |
| 183 | Cajoling Whispers | 37 | 15183 | Spell: Cajoling Whispers |
| 596 | Illusion: Dry Bone | 37 | 15596 | Spell: Illusion: Drybone |
| 64 | Resist Magic | 37 | 15064 | Spell: Resist Magic |
| 653 | Shade | 37 | 15653 | Spell: Shade |
| 695 | Distill Mana | 38 | 15695 | Spell: Distill Mana |
| 7987 | Greater Mass Enchant Platinum | 38 | 37593 | Spell: Greater Mass Enchant Platinum |
| 600 | Illusion: Spirit Wolf | 38 | 15600 | Spell: Illusion: Spirit Wolf |
| 648 | Rampage | 38 | 15648 | Spell: Rampage |
| 1407 | Wandering Mind | 38 | 30407 | Spell: Wandering Mind |
| 171 | Celerity | 39 | 15171 | Spell: Celerity |
| 7692 | Focus Mass Modest Spellcaster's Empowering Essence | 39 | 36382 | Spell: Focus Mass Modest Spellcaster's Essence |
| 132 | Immobilize | 39 | 15132 | Spell: Immobilize |
| 3983 | Mass Distill Mana | 39 | 59531 | Spell: Mass Distill Mana |
| 67 | Arch Shielding | 40 | 15067 | Spell: Arch Shielding |
| 1474 | Boon of the Garou | 40 | 30474 | Spell: Boon of the Garou |
| 163 | Incapacitate | 40 | 15163 | Spell: Incapacitate |
| 484 | Rune IV | 40 | 15484 | Spell: Rune IV |
| 33 | Brilliance | 41 | 15033 | Spell: Brilliance |
| 186 | Shiftless Deeds | 41 | 15186 | Spell: Shiftless Deeds |
| 678 | Tashania | 41 | 15678 | Spell: Tashania |
| 689 | Yegoreff's Animation | 41 | 15689 | Spell: Yegoreff`s Animation |
| 1694 | Boon of the Clear Mind | 42 | 19386 | Spell: Boon of the Clear Mind |
| 585 | Illusion: Werewolf | 42 | 15585 | Spell: Illusion: Werewolf |
| 25 | Pillage Enchantment | 42 | 15025 | Spell: Pillage Enchantment |
| 181 | Weakness | 42 | 15181 | Spell: Weakness |
| 4099 | Bounce | 43 | 59622 | Spell: Bounce |
| 178 | Color Skew | 43 | 15178 | Spell: Color Skew |
| 673 | Discordant Mind | 43 | 15673 | Spell: Discordant Mind |
| 1797 | Enchant Velium | 43 | 15797 | Spell: Enchant Velium |
| 1285 | Summon Companion | 43 | 19502 | Spell: Summon Companion |
| 7989 | Greater Mass Enchant Velium | 44 | 37595 | Spell: Greater Mass Enchant Velium |
| 4074 | Guard of Alendar | 44 | 59642 | Spell: Guard of Alendar |
| 3586 | Illusion: Scaled Wolf | 44 | 26973 | Spell: Illusion: Scaled Wolf |
| 3696 | Leviathan Eyes | 44 | 59015 | Spell: Leviathan Eyes |
| 3993 | Mass Enchant Velium | 44 | 59541 | Spell: Mass Enchant Velium |
| 7680 | Focus Simple Spellcaster's Empowering Essence | 45 | 36370 | Spell: Focus Simple Spellcaster's Essence |
| 2565 | Illusion: Imp | 45 | 7665 | Spell: Illusion: Imp |
| 133 | Paralyzing Earth | 45 | 15133 | Spell: Paralyzing Earth |
| 696 | Purify Mana | 45 | 15696 | Spell: Purify Mana |
| 194 | Reoccurring Amnesia | 45 | 15194 | Spell: Reoccurring Amnesia |
| 647 | Adorning Grace | 46 | 15647 | Spell: Adorning Grace |
| 184 | Allure | 46 | 15184 | Spell: Allure |
| 193 | Blanket of Forgetfulness | 46 | 15193 | Spell: Blanket of Forgetfulness |
| 1892 | Enchant Steel | 46 | 15892 | Spell: Enchant Steel |
| 176 | Berserker Spirit | 47 | 15176 | Spell: Berserker Spirit |
| 190 | Dazzle | 47 | 15190 | Spell: Dazzle |
| 195 | Gasping Embrace | 47 | 15195 | Spell: Gasping Embrace |
| 4009 | Mass Purify Mana | 47 | 59557 | Spell: Mass Purify Mana |
| 172 | Swift Like the Wind | 47 | 15172 | Spell: Swift like the Wind |
| 1890 | Enchant Adamantite | 48 | 15890 | Spell: Enchant Adamantite |
| 1889 | Enchant Mithril | 48 | 15889 | Spell: Enchant Mithril |
| 72 | Group Resist Magic | 48 | 15072 | Spell: Group Resist Magic |
| 690 | Kintaz's Animation | 48 | 15690 | Spell: Kintaz`s Animation |
| 654 | Shadow | 48 | 15654 | Spell: Shadow |
| 1893 | Enchant Brellium | 49 | 15893 | Spell: Enchant Brellium |
| 7693 | Focus Mass Simple Spellcaster's Empowering Essence | 49 | 36383 | Spell: Focus Mass Simple Spellcaster's Essence |
| 3984 | Mass Enchant Adamantite | 49 | 59532 | Spell: Mass Enchant Adamantite |
| 3985 | Mass Enchant Brellium | 49 | 59533 | Spell: Mass Enchant Brellium |
| 3989 | Mass Enchant Mithril | 49 | 59537 | Spell: Mass Enchant Mithril |
| 3992 | Mass Enchant Steel | 49 | 59540 | Spell: Mass Enchant Steel |
| 1687 | Collaboration | 50 | 19376 | Spell: Collaboration |
| 7681 | Focus Spellcaster's Empowering Essence | 50 | 36371 | Spell: Focus Spellcaster's Essence |
| 1406 | Improved Invisibility | 50 | 30406 | Spell: Improved Invisibility |
| 1686 | Theft of Thought | 50 | 19374 | Spell: Theft of Thought |
| 2881 | Everlasting Breath | 51 | 19523 | Spell: Everlasting Breath |
| 2894 | Levitation | 51 | 19534 | Spell: Levitation |
| 1541 | Wake of Tranquility | 51 | 19215 | Spell: Wake of Tranquility |
| 1693 | Clarity II | 52 | 19379 | Spell: Clarity II |
| 1696 | Color Slant | 52 | 19378 | Spell: Color Slant |
| 1690 | Fascination | 52 | 19380 | Spell: Fascination |
| 4017 | Illusion: Guktan | 52 | 67011 | Spell: Illusion Guktan |
| 4077 | Ordinance | 52 | 59645 | Spell: Ordinance |
| 1689 | Rune V | 52 | 19377 | Spell: Rune V |
| 3697 | Scryer's Trespass | 52 | 59016 | Spell: Scryer's Trespass |
| 2566 | Trickster's Augmentation | 52 | 7666 | Spell: Tricksters Augmentation |

## Spells With No Scroll in Items Table (35 total, not insertable)

These spells are on Enchanter's class list up to level 52 but have no itemtype=20
scroll with matching scrolleffect in the items table.

Run this query to see the full list:
```sql
SELECT s.id, s.name, s.classes14
FROM spells_new s
WHERE s.classes14 <= 52 AND s.classes14 > 0 AND s.classes14 != 255
  AND s.id NOT IN (SELECT spell_id FROM character_spells WHERE id = 6)
  AND s.id NOT IN (
    SELECT DISTINCT scrolleffect FROM items WHERE itemtype = 20 AND scrolleffect > 0
  )
ORDER BY s.classes14, s.name;
```

## Reversal SQL

To undo everything inserted here:
```sql
-- Remove all bags and scrolls added in this operation
DELETE FROM inventory
WHERE character_id = 6
  AND (slot_id BETWEEN 22 AND 30  -- the 9 bags
    OR slot_id BETWEEN 3810 AND 3819  -- bag 22 contents
    OR slot_id BETWEEN 4010 AND 4019  -- bag 23 contents
    OR slot_id BETWEEN 4210 AND 4219  -- bag 24 contents
    OR slot_id BETWEEN 4410 AND 4419  -- bag 25 contents
    OR slot_id BETWEEN 4610 AND 4619  -- bag 26 contents
    OR slot_id BETWEEN 4810 AND 4819  -- bag 27 contents
    OR slot_id BETWEEN 5010 AND 5019  -- bag 28 contents
    OR slot_id BETWEEN 5210 AND 5219  -- bag 29 contents
    OR slot_id BETWEEN 5410 AND 5419  -- bag 30 contents
  );
```

## Notes

- Chelon had zero inventory items before this operation.
- The scroll ordering prioritizes lower-level spells first (level 1 through 36),
  meaning the overflow scrolls are all level 36+ spells.
- The most important missing high-level spells in the overflow include:
  Clarity II (52), Rune V (52), Trickster's Augmentation (52), Fascination (52),
  Summon Companion (43), Enchant Velium (43), Tashania (41), Brilliance (41).
- Chelon needs to zone or relog for the new items to appear in her bags.
- The 35 spells with no scrolls are likely faction reward, quest reward, or
  vendor-only spells not available as drops/scrolls in the PEQ database.
