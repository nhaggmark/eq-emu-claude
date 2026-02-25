# Faction System Reference

This document explains the EQ faction system and provides data on all major factions.

## How Factions Work

**Standing values** range from roughly -2000 (maximum hatred) to +2000 (maximum love). The visible labels are:

| Range | Label |
|---|---|
| +1001 to +2000 | Ally |
| +501 to +1000 | Warmly |
| +100 to +500 | Kindly |
| 0 to +99 | Amiably |
| -100 to -1 | Indifferent |
| -500 to -101 | Apprehensively |
| -750 to -501 | Dubiously |
| -1001 to -751 | Threateningly |
| below -1001 | Ready to Attack |

**Base standing** (`faction_list.base`) is what every character starts at, before racial/class/deity modifiers.

**faction_list_mod** stores starting adjustments by race (`r` prefix), class (`c` prefix), or deity (`d` prefix). The modifier values shown in the database are applied on top of the base standing.

**NPC attitude** (`npc_faction_entries.npc_value`):
- `-1` = NPC is hostile regardless of faction
- `0` = NPC uses faction standing to determine attitude
- `1` = NPC is friendly regardless of faction

**Killing an NPC** applies the faction hits defined in `npc_faction_entries` for that NPC's faction set. Positive values = gain faction, negative values = lose faction.

---

## Major City Faction Profiles

### Qeynos (South/North Qeynos)

Qeynos is a dual-natured city with both a legitimate government and an active criminal underground.

**Factions present:**

| Faction ID | Faction Name | Role | Base Standing |
|---|---|---|---|
| 219 | Antonius Bayle | City ruler / nobility | 0 |
| 262 | Guards of Qeynos | City watch | 0 |
| 121 | Qeynos Citizens | General populace | 0 |
| 291 | Merchants of Qeynos | Trade district | 0 |
| 223 | Circle of Unseen Hands | Thieves' guild (covert) | 0 |
| 230 | Corrupt Qeynos Guards | Corrupt faction of guards | 0 |
| 214 | Priests of Life | Temple of Rodcet Nife | 0 |
| 207 | Karana | Druids and rangers | 0 |

**Faction Relationships (killing NPCs of one faction affects others):**

Guards of Qeynos NPCs are allied with `Antonius Bayle`, `Merchants of Qeynos`, and `Qeynos Citizens`. When you kill a Qeynos guard, you lose standing with ALL of these factions simultaneously, while gaining standing with `Circle of Unseen Hands` and `Corrupt Qeynos Guards`.

The corrupt guard system creates a moral axis: players who side with the thieves' guild (CoUH) and corrupt guards become enemies of legitimate Qeynos.

**Key NPCs:**
- Guards with faction set "Antonius Bayle" — lose -30 to multiple Qeynos factions when killed
- Merchants — lose -30 to Qeynos factions, -30 to merchant factions
- Fippy Darkpaw (a gnoll who repeatedly tries to raid the city — iconic encounter)

**Racial standing modifiers to "Antonius Bayle" faction:**
- Trolls (r9): -375 penalty
- Ogres (r10): -375 penalty
- Dark Elves (r6): -200 penalty

This means Trolls, Ogres, and Dark Elves start at a severe disadvantage in Qeynos.

---

### Freeport (West/North/East Freeport)

Freeport is the "evil" counterpart to Qeynos — a chaotic port city controlled by Sir Lucan D'Lere and the Freeport Militia. Three competing power factions create conflict.

**Factions present:**

| Faction ID | Faction Name | Role | Base Standing |
|---|---|---|---|
| 330 | The Freeport Militia | City watch / corrupt power | 0 |
| 311 | Steel Warriors | Warrior guild | 0 |
| 281 | Knights of Truth | Paladin guild, opposes militia | 0 |
| 279 | Priests of Marr | Clerical order | 0 |
| 362 | Priests of Marr | (alt ID) | 0 |
| 336 | Coalition of Tradefolk Underground | Merchant guild | 0 |
| 234 | Crushbone Orcs | Enemy faction in nearby zones | 0 |

**Faction Conflict:**

The critical story of Freeport is the conflict between the Freeport Militia (corrupt, controlling) and the Knights of Truth (honorable, resisting). Siding with one costs you standing with the other.

- Kill Clan Deathfist orcs for Freeport Militia: gain Militia faction, slight loss to Knights of Truth
- Collect Deathfist belts for Steel Warriors: gain Steel Warriors faction, loss to Militia
- Turn in items to Knights of Truth: gain Knights, lose Militia

**Key Quest Dialogs (from quest scripts):**

*Captain Hazran (Freeport Militia):*
> "Hail! We are the Militia of Freeport. Our training disciplines have created some of the finest guards ever to walk upon Norrath. To prove your loyalty and ability your first mission is to be the extermination of Clan Deathfist."
> "The orcs of the Commonlands call themselves Clan Deathfist. They have committed many vile acts upon the residents of the Commonlands as well as persons traveling to and from Freeport. They must be destroyed."

*Cain Darkmoore (Steel Warriors):*
> "Hail! We are the Steel Warriors of Freeport. Our training disciplines have created some of the finest warriors ever to walk upon Norrath. Perhaps the bards shall sing songs of you one day. Let your first mission be the extermination of Clan Deathfist."
> [When asked about bigger problem:] "The bigger problem is the Freeport Militia. Go to the Hall of Truth and speak with the Knights of Truth about that. They have already started their campaign to rid the city of the militia. The so-called Freeport Militia is not to be trusted."

*Guard Alayle (undercover agent):*
> "Greetings, citizen! You should not be in the Militia House. These are restricted grounds. Please leave at once unless you have business here."
> [To Paladins, secretly:] "Ssshhh!! Pipe down. The others might hear you. You must have something for me. Kalatrina must have given you something if you serve the Hall of Truth. If you have nothing please leave. You will blow my cover."

---

### Neriak (Foreign Quarter, Commons, 3rd Gate)

Neriak is the Dark Elf city, divided into three zones that represent increasing levels of privilege and danger. It is devoted to the god Innoruuk, the Prince of Hatred.

**Factions present:**

| Faction ID | Faction Name | Role | Base Standing |
|---|---|---|---|
| 236 | Dark Bargainers | Merchant guild / Teir'Dal traders | 0 |
| 334 | Dreadguard Outer | City guards (outer) | 0 |
| 370 | Dreadguard Inner | Elite city guards (inner) | 0 |
| 133 | Fel Guard | Additional guard faction | 0 |
| 134 | Neriak_Guards | Guard variant | 0 |

**Innoruuk Devotion:**

The Neriak quests revolve entirely around service to Innoruuk. The High Priestess Alexandria's dialog is emblematic:
> "Greetings child, what business do you have here? I'm sorry but I will only deal with Clerics that are willing to prove their loyalty to Innoruuk."
> "Were you to take this box that I have been keeping for quite some time... it can be used to refine certain metals into a magical compound used in crafting Initiate Darkpriest armor."

The armor quests require collecting "Helms of the Lifebringer" — meaning Neriak clerics must slay priests of Rodcet Nife (the healing god, enemy of Innoruuk) to advance.

**Dark Bargainers Racial/Alignment Modifiers:**
- Dark Elves: +50 (r6) — natural advantage
- Rogues (c5): +50 — favored class
- Necromancers (c11): +50 — favored class
- Paladins (c3), Clerics of good gods: -600 — heavily penalized
- Worshippers of Innoruuk (d206): +50

**Lokar To-Biath (Scribe of Innoruuk, 3rd Gate):**
> "I am the Scribe of Innoruuk. If you do not have business with me, begone!"
> [On Innoruuk:] "I am his scribe, and He is our god. There is nothing else to be said."

---

### Halas

Halas is the Barbarian city in Everfrost Peaks. The Barbarians worship Rallos Zek (god of war) and value martial strength above all.

**Factions present:**

| Faction ID | Faction Name | Role | Base Standing |
|---|---|---|---|
| 113 | Merchants of Halas | Trade | 0 |
| 115 | Warriors of the North | Warrior guild | 0 |
| 116 | Shamans of the Tribunal (Rogues of White Rose) | Rogue/shaman guild | 0 |
| 305 | Rogues of the White Rose | Thieves' guild | 0 |

**Character of Halas:**

Halas has a clan-based, rough-edged personality. The Rogues of the White Rose quest from Cappi McTarnigal:
> "Hail there! If you are not a member of the White Rose, then it be best that you stay on the lower level. This here floor is for honest... ermm respectable rogues only."
> "Our caravan to the frigid north leaves in less than two days, and we are short on mammoth calf hides. Return four of them and you will be given items that show your loyalty to our Clan."

The guard Deregan reflects Barbarian attitudes:
> "Hail, [name]. I am Deregan. I used to be an adventurer much like yourself. Of course I was not as frail and childlike as you appear to be."

---

### Neriak — Guard Personality (from quest scripts)

Neriak guards in the Foreign Quarter (Guard Lumpin):
> [On Hail:] "Hullo citizen. Me am here to guard you so puts away any wepuns."
> [On happy love bracers:] "Hmm... Me seen green bracers on troll named Ratraz."
> [On Ratraz:] "Ratraz is dumb troll who werk in dark elf bar. Him tink he smart because dark elves raise him. Tink he know everyting. Him just as stewpid as all us trolls is!"
> [On death:] "My comrades will avenge my death."

Note: Neriak Foreign Quarter has mixed-race inhabitants including Trolls and Ogres who serve the Dark Elves.

---

### Kaladim (South and North Kaladim)

Kaladim is the Dwarven city in Butcherblock Mountains. Dwarves worship Brell Serilis (god of the underworld).

**Factions:**

| Faction ID | Faction Name | Role |
|---|---|---|
| 144 | Kaladim Citizens | General populace |
| 145 | Merchants of Kaladim | Trade |
| 283 | Miners Guild 628 | Mining guild |
| 284 | Miners Guild 249 | Mining guild (rival) |

---

### Oggok

Oggok is the Ogre city in The Feerrott. Ogres worship Rallos Zek.

**Factions:**

| Faction ID | Faction Name | Role |
|---|---|---|
| 211 | Rallos Zek | Religious devotion |
| Ogre-specific factions | Various guards and merchants | City services |

---

### Grobb

Grobb is the Troll city in Innothule Swamp. Trolls worship Cazic-Thule (god of fear).

---

### Erudin

Erudin is the Erudite city on Odus. It has a split: the main city is good-aligned, while Paineel (the city created by Erudite heretics) is evil-aligned.

**Erudin Factions:**

| Faction ID | Faction Name | Role |
|---|---|---|
| 128 | Erudin Citizens | General populace |
| 129 | Craftkeepers | Crafting guild |
| 130 | High Guard of Erudin | City guard |
| 265 | Heretics | Enemy faction (Paineel) |

---

### Cabilis (Kunark)

Cabilis is the Iksar city in The Field of Bone / Lake of Ill Omen area. Split into East (more populated) and West (more specialized).

**Factions:**

| Faction ID | Faction Name | Role | NPC Count |
|---|---|---|---|
| 441 | Legion of Cabilis | City guard / military | 86 |
| 443 | Brood of Kotiz | Necromancer guild | ~50 |
| 444 | Scaled Mystics | Shaman guild | ~30 |
| 445 | Crusaders of Greenmist | Shadowknight guild | ~30 |
| 442 | Cabilis Residents | General populace | ~50 |

**Cabilis Quest Flavor:**

Harbinger Glosk (Necromancer guild master, West Cabilis):
> "You dare to interrupt me? You had best have a good reason. I care not for small talk."
> "Yes. You are [a new revenant]. You shall do as I command. Take this. It is incomplete and must be ready for the emperor within the half season. You must find the Four Missing Gems."

Master Kyvix (5th rank trainer):
> "Quite busy!! Quite busy!! Things must be done. New components to be collected!!"
> [On becoming revenant:] "Welcome, Revenant [name]. You have done well. The Harbinger awaits you."

The Iksar society is militaristic and hierarchical — NPCs address players by rank (apprentice, dark binder, occultist, revenant) rather than by name until higher ranks are earned.

---

### Shadow Haven (Luclin)

Shadow Haven is the main neutral city on Luclin, serving as a hub for travelers from all factions.

**Factions:**

| Faction ID | Faction Name | Role | NPC Count |
|---|---|---|---|
| 1509 | Haven Defenders | City guard | 176 |

**Character:**

Adept Arnthus (on Hail):
> "Due to the problems we have had lately with dishonorable visitors to the Haven we require all newcomers to see Daloran and Mistala for some simple tasks to prove that your intentions are good. I hope to see you soon."

Shadow Haven accepts all races and classes but requires trust-building via minor tasks for newcomers.

---

### Katta Castellum (Luclin)

Katta Castellum is a Combine Empire city on Luclin, home to diverse races unified under former Combine Empire loyalists.

**Factions:**

| Faction ID | Faction Name | Role | NPC Count |
|---|---|---|---|
| 1502 | Katta Castellum Citizens | General populace | 83 |
| 1503 | Validus Custodus | City guard | 229 |
| 1541 | Hand Legionnaries | Military guard | 165 |
| 1485 | Eye of Seru | Intelligence/spy faction | 88 |

The lore centers on the ancient conflict between the Combine Empire (Katta) and the Seru Loyalists (Sanctus Seru). The Order of Autarkic Umbrage (shadow vampires) operates covertly within the castellum:

*Autarkic Lord Sfarosh:*
> "Meddling fleshlings! Why have you pulled back to this forsaken castellum? Do you fear that I will seek vengeance on Nathyn Illuminious and the city that shelters him for my years of captivity here?"
> "I will return as I am a creature of shadows and shadows never die, merely slumber!"

---

## Major Hostile Faction Summary

These are the most numerically significant hostile factions in Classic-Luclin zones:

| Faction ID | Faction Name | NPC Count | Primary Location | Notes |
|---|---|---|---|---|
| 5013 | KOS (generic hostile) | 3,276 | Everywhere | Generic hostile tag |
| 430 | Claws of Veeshan | 710 | Velious/Skyshrine | Dragons |
| 5023 | Noobie Monsters | 440 | All newbie zones | Hostile to city guards |
| 1516 | Grimlings of the Forest | 380 | Luclin / Grimling Forest | Luclin natives |
| 259 | Goblins of Mountain Death | 372 | Steamfont area | Steamfont goblins |
| 406 | Coldain | 361 | Velious / Thurgadin | Dwarven Coldain |
| 419 | Kromrif | 312 | Velious / Kael | Ice Giants (enemy of Coldain) |
| 448 | Kromzek | 258 | Velious / Kael | Storm Giants |
| 1499 | Citizens of Seru | 251 | Luclin / Sanctus Seru | Rival to Katta |
| 425 | Inhabitants of Hate | 234 | Plane of Hate | Innoruuk's servants |
| 251 | Frogloks of Guk | 202 | Innothule/Guk | Classic Guk frogloks |
| 285 | Mayong Mistmoore | 148 | Castle Mistmoore | Vampire lord's faction |
| 234 | Crushbone Orcs | 85 | Crushbone/GFaydark | Classic orc zone |
| 5024 | Death Fist Orcs | 92 | Commonlands | Freeport-area orcs |

---

## Hostile Creatures Near Major Cities

### Near Freeport (Commonlands area)
- **Clan Deathfist** (Death Fist Orcs): Level 1-20, 24+ NPCs in East Commonlands, 12 in West Commonlands. Primary low-level enemy for Freeport quest givers.
- **Dervish Cutthroats**: Level 10-15, human bandits, both East and West Commonlands.
- **Freeport Militia (KOS variants)**: Level 11-41, East Commonlands — corrupt militia patrols outside the city.
- **Shadowed Men**: Level 25-26, West Commonlands — mysterious dark entities.

### Near Qeynos (Karana Plains, Qeynos Hills)
- **Gnolls (Sabertooths of Blackburrow)**: Level 1-30, the signature Qeynos enemy. Blackburrow dungeon is their stronghold. Fippy Darkpaw (a named gnoll) repeatedly attacks North Qeynos gates.
- **Karana Bandits**: Level 4-15, human raiders on the Karana plains.
- **Kithicor Undead**: After dark, Kithicor Forest (adjacent to Qeynos Hills) fills with high-level undead — a deadly surprise for low-level players.

### Near Neriak (Nektulos Forest)
- **Priests of Rodcet Nife**: Set up in Nektulos, which Neriak clerics must kill for armor quests.
- **Dark Elves (various hostile factions)**: Nektulos has some hostile dark elf factions as well as the city-friendly ones.

### Near Greater Faydark / Kelethin
- **Crushbone Orcs**: Level 1-12, 21 NPCs in Greater Faydark. The Crushbone dungeon (adjacent) has 60 NPCs level 1-65. Major threat to Kelethin.
- **Fairies**: Level 6-21, not always hostile but can be.
- **Emerald Warriors**: Level 38-61, High Elven elite troops in the forest.

### Near Innothule / Grobb
- **Frogloks of Guk**: Level 3-11, natural enemies of the Trolls.
- **Fungus Men**: Level 1-10, Innothule.
- **Kobolds**: Level 2-18, Innothule area.

### Near Halas / Everfrost
- **Sabertooths of Blackburrow**: Level 1-5, gnolls near Blackburrow entrance.
- **Polar Bears / Wolves of the North**: Level 2-50, natural predators.
- **Mammoth**: Large creatures on Everfrost plains.

### Near Feerrott / Oggok
- **Allize Taeew** (Lizardmen): Level 18-49, 38 NPCs — dominant hostile force in the Feerrott.
- **Allize Volew** (more lizardmen): Level 4-26, 6 NPCs.
