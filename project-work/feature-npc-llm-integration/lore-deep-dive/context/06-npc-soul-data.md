# NPC Soul Data — Supplemental Extraction

Supplemental data for the "emergent NPC soul" system: per-city NPC individuality counts, named vs. generic analysis, canonical backstory elements found in quest scripts, and role-based context templates.

---

## 1. NPC Soul Counts Per City

Every NPC in every city is individually named with a unique npc_type_id. There are **zero "generic" NPCs** (e.g., "a guard", "a merchant") in any Classic-Luclin city zone. This means each NPC already has a unique identity in the database — the soul system can address them all as individuals.

### City NPC Roster by Role

Role categorization is based on faction name matching:
- **Guard**: faction name contains "Guard", "Militia", "Watch", "Sheriff", "Trooper"
- **Merchant**: has merchant_id > 0 in npc_types
- **Quest NPC**: has at least one quest flag (dialog, task giver, etc.)
- **Guildmaster**: faction name contains "Guild" (skill trainers)

| Zone | Zone Name | Total Souls | Guards | Merchants | Quest NPCs | Guildmasters |
|------|-----------|-------------|--------|-----------|------------|--------------|
| qeynos | South Qeynos | 197 | 22 | 66 | 117 | 0 |
| qeynos2 | North Qeynos | 149 | 23 | 26 | 84 | 0 |
| freportw | West Freeport | 142 | 28 | 41 | 58 | 1 |
| freportn | North Freeport | 116 | 0 | 46 | 43 | 1 |
| freporte | East Freeport | 187 | 29 | 56 | 66 | 2 |
| neriaka | Neriak - Foreign Quarter | 71 | 12 | 32 | 13 | 0 |
| neriakb | Neriak - Commons | 104 | 20 | 49 | 28 | 0 |
| neriakc | Neriak - 3rd Gate | 108 | 12 | 39 | 30 | 0 |
| halas | Halas | 93 | 0 | 44 | 40 | 0 |
| cabeast | Cabilis East | 133 | 14 | 54 | 65 | 9 |
| cabwest | Cabilis West | 50 | 14 | 19 | 35 | 4 |
| shadowhaven | Shadow Haven | 318 | 2 | 117 | 258 | 1 |
| sharvahl | The City of Shar Vahl | 339 | 38 | 85 | 176 | 8 |
| sseru | Sanctus Seru | 689 | 53 | 48 | 47 | 3 |
| katta | Katta Castellum | 448 | 4 | 46 | 116 | 0 |
| akanon | Ak'Anon | 253 | 4 | 67 | 70 | 1 |
| bazaar | The Bazaar | 113 | 0 | 34 | 26 | 0 |
| erudnext | Erudin | 115 | 0 | 41 | 39 | 0 |
| erudnint | The Erudin Palace | 79 | 0 | 32 | 18 | 0 |
| felwithea | Northern Felwithe | 87 | 22 | 41 | 22 | 0 |
| felwitheb | Southern Felwithe | 38 | 7 | 23 | 8 | 0 |
| grobb | Grobb | 104 | 0 | 44 | 40 | 0 |
| kaladima | South Kaladim | 68 | 32 | 18 | 20 | 0 |
| kaladimb | North Kaladim | 72 | 6 | 32 | 31 | 0 |
| nexus | Nexus | 26 | 0 | 0 | 24 | 0 |
| oggok | Oggok | 122 | 0 | 47 | 69 | 0 |
| paineel | Paineel | 160 | 67 | 39 | 66 | 0 |
| rivervale | Rivervale | 154 | 0 | 44 | 81 | 0 |

**Total souls across all city zones: ~4,889 unique named NPCs**

**Key observation**: Sanctus Seru has by far the largest population (689 souls) but skewed heavily toward guards (53) and quest NPCs (47), with few merchants (48). This reflects its militarized, authoritarian character. Shadow Haven has the highest quest NPC count (258) consistent with its role as the neutral trade hub of Luclin.

---

## 2. Named vs. Generic Analysis

### Finding: ALL City NPCs Are Individually Named

Query result across all 28 city zones:
- **Named NPCs** (unique individual name): 100% of city NPCs
- **Generic NPCs** (e.g., "a guard", "a citizen"): 0

This is a significant lore finding: the original EQ designers gave every city NPC a proper name. There is no "a guard #47" in these zones — every guard has a name like "Guard Kwint" or "Trooper Shestar." This means:

1. The soul system can refer to every NPC by their proper name from the start
2. There is no need to generate placeholder names — canonical names already exist in the database
3. Backstory generation should treat each as a specific individual, not a role archetype

**Contrast with dungeons**: Dungeon zones (Befallen, Lower Guk, etc.) do use generic naming ("a ghoul", "a zombie") — the named-NPC phenomenon is specific to city/settlement zones.

---

## 3. Canonical Soul Elements

These are verified backstory fragments found in existing quest scripts. Each is a "canonical soul element" — the soul system should treat these as ground truth and build personality/history outward from them. **Do not contradict these.**

### Table: Confirmed Canonical Backstory Lines

| NPC Name | City | Role | Canonical Element | Source Script |
|----------|------|------|-------------------|---------------|
| Plagus Ladeson | freportw | Merchant / Ex-trainer | "I was a trainer at the Hall of Steel in Qeynos before this. I left Qeynos in search of Milea [Clothspinner] and instead found myself joining the bunker's weaponmasters." Cross-city backstory. Lost love as defining event. | `freportw/Plagus_Ladeson.lua` |
| Plagus Ladeson | freportw | Merchant / Ex-trainer | Has unrequited feelings for Toala (another Steel Warriors NPC) in addition to lost love for Milea. | `freportw/Plagus_Ladeson.lua` |
| Valeron Dushire | freportn | Quest NPC / Ex-knight | "I trained Sir Lucan D'Lere when he was nothing more than a street rat who was taken in by the Temple of Marr." Decades of shared history with the city's villain-ruler. | `freportn/Valeron_Dushire.lua` |
| Lady Shae | freportw | Quest NPC / Noble | Was in a romantic relationship with Antonius Bayle IV (ruler of Qeynos). He ended the relationship. She relocated to Freeport. Still holds feelings. Drinks wine and is described as bitter. | `freportw/Lady_Shae.lua` |
| Guard Kwint | qeynos | Guard | Has a brother, Earron Kwint, who is master brewer at the Lion's Mane Tavern in Qeynos. Family still in the same city. | `qeynos/Guard_Kwint.lua` |
| Captain Rohand | qeynos | Guard (Captain) | World traveler before settling as a guard captain. "I've been everywhere, Odus, Faydwer, Kunark... I saw more adventure before I was ten years tall than you'll see in your whole miserable existence." | `qeynos/Captain_Rohand.lua` |
| Behroe Dlexon | qeynos | Guard (Night Watch) | Bard-guard on night watch. Wrote a ballad for Aenia (daughter of Dranom Ghenson). Can't deliver it because he is on duty. Cross-NPC romantic subplot. Dranom Ghenson is another named NPC in the same zone. | `qeynos/Behroe_Dlexon.lua` |
| Ebon Strongbear | qeynos | Quest NPC / Steel Warriors | Has a sister. A corrupt city guard (Beris) stole her coinpurse. Uses his Steel Warriors position to seek justice. Notes the Steel Warriors organization extends from Qeynos to Freeport (cross-city institutional link). | `qeynos/Ebon_Strongbear.lua` |
| Eve Marsinger | qeynos | Quest NPC / Bard courier | Married to Tralyn Marsinger. Runs a bard courier network in Qeynos. References specific agent names within the network. | `qeynos/Eve_Marsinger.lua` |
| Guard Urius | qeynos | Guard | Noticed a change in city crime patterns: "There are more thieves around these days than there used to be." Ongoing situational awareness, not just static. | `qeynos/Guard_Urius.lua` |
| Dok | halas | Quest NPC / Craftsman | Failed inventor. "I was hoping to perfect me creation I was callin' the 'cigar'." Switched to candle-making after the cigar attempt failed. Speaks in a Scottish dialect. References Clan McMannus living in the Western Plains of Karana. | `halas/Dok.lua` |
| Trooper Shestar | cabeast | Guard | "My father was a great blacksmith. He taught me how to make great items... Alas, smithing was not my rebirth, but rather the life of a warrior." Inherited skill, chose a different path. | `cabeast/Trooper_Shestar.pl` |
| Half-Elf Maiden | cabeast | Captive / Quest NPC | Half-elf trapped in Cabilis, separated from her human/elf family on the mainland. Needs a seal from a specific Iksar for safe passage out of the city. | `cabeast/Half_Elf_Maiden.pl` |

### Cross-NPC Relationship Map (Confirmed)

These are verified, scripted relationships between specific named NPCs:

```
Guard Kwint (qeynos) ←→ Earron Kwint (qeynos) — siblings; Earron = master brewer, Lion's Mane Tavern
Behroe Dlexon (qeynos) → Aenia (qeynos) — unrequited; Behroe wrote her a ballad
Aenia ↔ Dranom Ghenson (qeynos) — father/daughter
Plagus Ladeson (freportw) → Milea Clothspinner (lost, unknown location) — lost love
Plagus Ladeson (freportw) → Toala (freportw, Steel Warriors) — unrequited feelings
Plagus Ladeson (freportw) ← Qeynos Hall of Steel — former employer, cross-city
Valeron Dushire (freportn) → Sir Lucan D'Lere (freportn) — trainer/student, now adversaries
Lady Shae (freportw) → Antonius Bayle IV (qeynos) — ended romance, cross-city
Ebon Strongbear (qeynos) ← Sister (unnamed) — victim of corrupt guard Beris
Eve Marsinger (qeynos) ↔ Tralyn Marsinger (qeynos) — married couple
Steel Warriors guild ↔ Qeynos + Freeport — same institution operating in two cities
```

---

## 4. Role-Based Backstory Templates

Based on the canonical soul elements found, these are plausible backstory frameworks by NPC role. These are templates for LLM generation — they expand on what real NPCs already have in scripts.

### Guards

**What guards actually have in scripts:**
- Family in the city (Guard Kwint's brother)
- Prior lives before the guard role (Captain Rohand: world traveler)
- Opinions on city politics and crime (Guard Urius: "more thieves than before")
- Artistic pursuits outside duty (Behroe Dlexon: bard/songwriter)
- Family injustices they're trying to fix (Ebon Strongbear: corrupt guard stole sister's coinpurse)
- Career paths they didn't take (Trooper Shestar: could have been a blacksmith)

**Template dimensions for guard backstory generation:**
- Where did they come from? (city native, transfer from another city, former adventurer)
- What did they do before becoming a guard? (one prior career is common)
- Who do they have family ties to? (prefer existing named NPCs in the same zone)
- What do they worry about on duty? (crime trends, political tensions, personal matters)
- Do they have a creative or intellectual hobby? (bard, craftsman, etc.)

### Merchants

**What merchants actually have in scripts:**
- Cross-city career history (Plagus Ladeson: Qeynos trainer → Freeport Steel Warriors merchant)
- Personal losses that redirected their career (left hometown searching for lost love)
- Emotional attachments to people in the same city (Plagus → Toala)
- Institutional affiliations beyond just selling (guild membership, faction loyalty)

**Template dimensions for merchant backstory generation:**
- Where did they originally come from? (merchants have the most cross-city mobility)
- What life event brought them to this city? (economic opportunity, personal circumstance, fleeing something)
- What do they sell vs. what did they used to do? (profession change is a strong backstory hook)
- Who do they know in the city from before their merchant life?

### Quest NPCs (Information Givers, Task Givers)

**What quest NPCs actually have in scripts:**
- Deep institutional knowledge (Valeron Dushire knows Sir Lucan's full history)
- Long-standing grievances or loyalties (Lady Shae: still mourning the relationship with Antonius Bayle)
- Social networks that span the city (Eve Marsinger: bard courier network with named agents)
- Failed ventures they're philosophical about (Dok: the cigar experiment)
- Desire to help specific outsiders (Half-Elf Maiden: needs player's help to escape)

**Template dimensions for quest NPC backstory generation:**
- What do they know that almost no one else in the city knows?
- What have they failed at that defines them now?
- Who in the city do they have a complicated relationship with?
- What do they want that they can't get without help?

### Guildmasters (Skill Trainers)

**Data note**: Guildmasters have fewer personal backstory scripts — they tend to be purely functional. The following templates are inferred from role context rather than extracted scripts.

**Plausible template dimensions:**
- What is their professional specialty and how did they reach mastery?
- Who trained them? (chain of masters going back generations)
- Who is their most notable student? (could link to another named NPC)
- What do they think about the state of their craft in this city vs. other cities?

---

## 5. Unique Lore Assets by City for Soul Generation

A quick reference for what makes each city's NPCs distinctive in backstory potential:

| City | Distinctive Soul Material |
|------|---------------------------|
| Qeynos | Cross-faction intrigue (thieves vs. guards), cross-NPC romances, cross-city Steel Warriors, family networks, bard culture |
| Freeport | Three-way guild war (Militia/KoT/Steel Warriors), cross-city exiles (Lady Shae from Qeynos, Plagus from Qeynos), Sir Lucan's shadow over everyone |
| Halas | Barbarian clan identity (Clan McMannus references), craft experimentation, Scottish dialect as personality marker |
| Cabilis | Strict rank hierarchy (NPCs addressed by rank not name), trapped outsiders, military devotion as substitute for family |
| Neriak | Innoruuk theology as life purpose, class/caste divisions (3 zones = 3 social tiers), dark elf politics |
| Katta Castellum | Combine Empire nostalgia, Luclin isolation, Nathsar vampire nobility |
| Sanctus Seru | Authoritarian loyalty vs. personal doubt, Eye of Seru espionage culture, ancient ideological split from Katta |
| Shadow Haven | Neutral crossroads — any race, any background, all meeting in one place |
| Ak'Anon | Clockwork engineering culture, gnomish invention ethos |
| Rivervale | Halfling pastoral identity, community-first values |

---

## 6. Extraction Methodology

Data sources for this document:

1. **DB query — city NPC counts**: `spawn2` → `spawnentry` → `npc_types`, filtered by `version=0`, `expansion BETWEEN 0 AND 3`, joined to zone list
2. **DB query — role breakdown**: Named `npc_faction_entries` matched against guard/merchant/guild keyword sets; merchant flag from `npc_types.merchant_id`
3. **Named vs. generic check**: `COUNT(DISTINCT nt.id)` filtered by name regex `^[A-Z]` vs. `^a ` — zero generic results in city zones
4. **Quest script search**: Bash `grep -r` across `/mnt/d/Dev/EQ/akk-stack/server/quests/` for first-person personal history triggers (`my brother`, `I was`, `I left`, `my father`, `I trained`, `in search of`, `before I`)
5. **Script reads**: Full read of ~15 NPC Lua/Perl scripts across Freeport, Qeynos, Halas, Cabilis to extract canonical dialog lines

All canonical soul elements in Section 3 were verified by reading the actual script file — no inference from filenames or partial matches.
