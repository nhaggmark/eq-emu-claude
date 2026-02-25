# Faction Relationship Matrix

This document details the concrete faction relationships encoded in the database. Data is drawn from `npc_faction_entries` — what killing an NPC of one faction does to related factions.

## Reading Guide

When an NPC is killed:
- **Positive values** = you **gain** this faction standing
- **Negative values** = you **lose** this faction standing
- **npc_value = 1** = that NPC is friendly regardless of your faction standing
- **npc_value = -1** = that NPC is hostile regardless of your faction standing

---

## Qeynos Faction Web

### Killing a "Guards of Qeynos" NPC (faction set: Antonius Bayle)

| Faction Hit | Faction Name | Amount |
|---|---|---|
| Antonius Bayle | City ruler | -30 |
| Guards of Qeynos | City watch | -30 |
| Merchants of Qeynos | Trade district | -30 |
| Qeynos Citizens | General populace | -30 |
| Circle of Unseen Hands | Thieves' guild | +10 |
| Corrupt Qeynos Guards | Corrupt faction | +10 |

**Interpretation:** Killing Qeynos guards damages your standing with the entire legitimate power structure of the city simultaneously. You become known to the criminal underground as useful.

### Key Qeynos Factions with Base Values

| Faction ID | Name | Base | Notes |
|---|---|---|---|
| 219 | Antonius Bayle | 0 | Ruler faction — guards, nobility |
| 262 | Guards of Qeynos | 0 | City watch |
| 121 | Qeynos Citizens | 0 | Merchants, common folk |
| 291 | Merchants of Qeynos | 0 | Trade NPC faction |
| 223 | Circle of Unseen Hands | 0 | Rogues' guild (secret) |
| 230 | Corrupt Qeynos Guards | 0 | Corrupt guard subgroup |
| 273 | Kane Bayle | 0 | Kane Bayle — brother of Antonius, rival |

**Antonius Bayle vs. Kane Bayle:** The city's political drama includes the ruler Antonius Bayle and his brother Kane. An Investigator NPC (faction set Antonius Bayle) gives +25 to Kane Bayle on kill — indicating an investigator looking into Kane represents a threat to him.

---

## Freeport Faction Web

### Killing a "Freeport Militia" NPC

When a Freeport Militia guard is killed, the expected relationships fire:
- Freeport Militia: -30 (lose militia standing)
- Priests of Marr: varies (Militia and Priests of Marr have a tense alliance)
- Knights of Truth: +varies (benefit from militia being weakened)
- Steel Warriors: +varies

### The Three-Way Conflict

The three major Freeport guilds (Militia, Knights of Truth, Steel Warriors) have interlocking faction systems:

**Siding with Militia (Captain Hazran quests):**
- +5 Freeport Militia
- -1 Priests of Marr
- -1 Knights of Truth
- +1 Coalition of Tradefolk Underground

**Siding with Steel Warriors (Cain Darkmoore quests):**
- +1 Steel Warriors
- +1 Knights of Truth
- -1 Freeport Militia

**Knights of Truth quests** give:
- +Knights of Truth
- +Guards of Qeynos (surprising — the Qeynos guards support the Knights)
- -Corrupt Qeynos Guards
- -Freeport Militia

Note: The Guard Alayle spy quest directly links Knights of Truth with Qeynos — showing a cross-city alliance between Qeynos's legitimate power and Freeport's resistance movement.

---

## Neriak Faction Web

### Dark Bargainers Base Modifiers

The Dark Bargainers faction starts at 0 for everyone, but racial/class adjustments heavily determine starting standing:

**Favorable races/classes (positive mod):**
- Dark Elves (r6): +50
- Rogues (c5): +50
- Necromancers (c11): +50
- Iksar (c specific — neutral to mildly positive)

**Penalized races/classes:**
- Paladins (c3): -600
- Clerics of good alignment (c4 certain deities): -600
- Druids (c6): -600
- Various good-aligned deities (d202-d216 range): -200 to -300
- Innoruuk worshippers (d206): +50

**Dreadguard Inner (most powerful Neriak guard faction):**
Even more extreme modifiers:
- Paladins: -750
- Good clerics: -750
- Druids: -750
- Rodcet Nife worshippers (d204): -750
- Mithaniel Marr worshippers (d202): -750
- Innoruuk worshippers: +50
- Dark Elves (r6): substantial bonus (implied from r10 Ogre penalty of -450)

---

## Cabilis (Iksar) Faction Web

### Legion of Cabilis + Brood of Kotiz

When completing necromancer guild quests:
- +Legion of Cabilis: +20 per rank advancement
- +Brood of Kotiz: +20 per rank advancement

These two factions are permanently linked — advancement in one always advances the other. The city military and the necromancer guild are mutually supportive.

### Iksar vs. Frogloks of Kunark

The Frogloks of Kunark (252) are natural enemies of the Iksar. Their faction entry data shows they are hostile to Iksar-associated factions. In Kunark's lore, the Iksar enslaved the Frogloks and the Frogloks eventually revolted, becoming an independent species.

---

## Velious Faction Triangle

The key Velious three-way conflict:

**Coldain (Thurgadin Dwarves, faction 406):**
- Allied with: Claws of Veeshan (dragons of Skyshrine)
- Enemies: Kromzek (Storm Giants), Kromrif (Ice Giants)

**Claws of Veeshan (faction 430):**
- Allied with: Coldain
- Enemies: Kromzek, Kromrif

**Kromzek/Kromrif (Kael Giants, factions 448/419):**
- Allied with each other
- Enemies: Coldain, Claws of Veeshan

This creates hard faction choices: to be neutral in Kael (need Giant faction), you must actively harm your Coldain standing.

---

## Luclin Faction Split: Katta vs. Seru

**Katta Castellum (Citizens of Katta, faction 1502):**
- Validus Custodus (guard, 1503): protects the city
- Hand Legionnaries (1541): military arm
- Eye of Seru (1485): this is noteworthy — the Eye of Seru faction is ALSO present in Katta, suggesting espionage

**Sanctus Seru (Citizens of Seru, faction 1499):**
- Validus Custodus (military, same faction ID 1503 — shared name)

Note: The presence of the Eye of Seru (1485) faction in Katta Castellum, combined with it appearing in the Seru faction data, suggests these are competing intelligence organizations, one reporting to each city.

---

## Notable Cross-City Faction Relationships

From the `npc_faction_entries` data, these cross-city relationships are mechanically encoded:

| If you kill... | You gain standing with... |
|---|---|
| Qeynos guards | Circle of Unseen Hands (Qeynos rogues) |
| Qeynos guards | Corrupt Qeynos Guards |
| Freeport Militia | Knights of Truth |
| Freeport Militia | Steel Warriors |
| Steel Warriors | Knights of Truth |
| Clan Deathfist (orcs) | Multiple Freeport factions |
| Crushbone Orcs | Greater Faydark factions |
| Sabertooths of Blackburrow | Qeynos guards (implied) |
| Frogloks of Guk | Grobb faction (trolls who hate frogloks) |

---

## Faction Starting Standing by Race

Based on `faction_list_mod` data (modifier code r# = race ID):

### Antonius Bayle (Qeynos ruler faction):
- Trolls (r9): -375 — severely unwelcome
- Ogres (r10): -375 — severely unwelcome
- Dark Elves (r6): -200 — unwelcome

### Circle of Unseen Hands (Qeynos thieves' guild):
- Halflings (r1, r330, r522): +50 — naturally welcome (thieves' guild is halfling-friendly)
- Half Orcs (r7): +50 — neutral/welcome
- Trolls (r9): -750 — extremely unwelcome
- Ogres (r10): -500 — extremely unwelcome
- Dark Elves (r6): -50 — unwelcome but not extreme
- Gnomes (r12): -75

### Corrupt Qeynos Guards:
- Halflings (r1): +50 — corrupt guards accept halfling bribes
- Half Orcs (r7): +50
- Trolls (r9): -850
- Ogres (r10): -750

### Dark Bargainers (Neriak merchants):
- Dark Elves (r6): +50
- Trolls (r9): -99 (near hostile)
- Ogres (r10): -50
- Iksar (r128): -50

### Dreadguard Inner (Neriak elite guards):
- Dark Elves (r6): high positive (inferred)
- All non-dark elves: heavily penalized
- Ogres (r10): -450
- Trolls (r9): -875

---

## Deity Faction Modifiers

The `d` prefix codes in faction_list_mod correspond to deity IDs. Key deities:

| Code | Deity | Alignment |
|---|---|---|
| d201 | Bertoxxulous | Evil (plague) |
| d202 | Mithaniel Marr | Good (valor) |
| d203 | Rallos Zek | Evil (war) |
| d204 | Rodcet Nife | Good (healing) |
| d205 | Solusek Ro | Neutral/Evil (fire) |
| d206 | Innoruuk | Evil (hatred) |
| d207 | Cazic-Thule | Evil (fear) |
| d208 | Erollisi Marr | Good (love) |
| d209 | Bristlebane | Neutral (mischief) |
| d210 | Brell Serilis | Neutral/Good (stone, crafts) |
| d211 | Tunare | Good (nature) |
| d212 | Karana | Good (weather/plains) |
| d213 | Prexus | Good (ocean) |
| d214 | Veeshan | Neutral (dragons) |
| d215 | Quellious | Good (peace) |
| d216 | Agnostic | No deity |

**How it works:** If a character worships Innoruuk (d206), they get +50 to Dark Bargainers. If they worship Rodcet Nife (d204), they get -750 to Dreadguard Inner.

Good-deity worshippers are penalized by Neriak factions. Evil-deity worshippers are penalized by Qeynos/Felwithe/Erudin factions.
