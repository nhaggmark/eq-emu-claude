# Quest Dialog Samples by City

This document contains representative dialog extracted from quest scripts in the major cities. All scripts are from `/mnt/d/Dev/EQ/akk-stack/server/quests/`. Dialog reveals personality, worldview, and lore.

---

## Freeport (freportw / freportn / freporte)

Freeport is the center of political intrigue in Classic EQ. The central conflict is between the Freeport Militia (corrupt city watch) and the Knights of Truth (honorable paladins resisting militia control). A third faction — the Steel Warriors — represents martial pride without political alignment.

### Captain Hazran (Freeport Militia, freportw)
File: `Captain_Hazran.lua`

**Hail:**
> "Hail, [name]! We are the Militia of Freeport. Our training disciplines have created some of the finest guards ever to walk upon Norrath. To prove your loyalty and ability your first mission is to be the extermination of Clan Deathfist."

**On "Clan Deathfist":**
> "The orcs of the Commonlands call themselves Clan Deathfist. They have committed many vile acts upon the residents of the Commonlands as well as persons traveling to and from Freeport. They must be destroyed. Go forth to slay them. I shall pay a bounty for every two Deathfist belts."

**After turning in orc belts:**
> "Very fine work [name]. With your help, we shall soon rid the commonlands of the orcs. Then we can move on to a bigger problem."

**On "bigger problem":**
> "The bigger problem is the Knights of Truth. We have already started our campaign to rid the city of the Knights. The so-called Knights of Truth are not to be trusted."

*Faction notes: Rewards Freeport Militia, penalizes Knights of Truth and Priests of Marr.*

---

### Cain Darkmoore (Steel Warriors, freportw)
File: `Cain_Darkmoore.lua`

**Hail:**
> "Hail, [name]! We are the Steel Warriors of Freeport. Our training disciplines have created some of the finest warriors ever to walk upon Norrath. Perhaps the bards shall sing songs of you one day. Let your first mission be the extermination of Clan Deathfist."

**On "bigger problem":**
> "The bigger problem is the Freeport Militia. Go to the Hall of Truth and speak with the Knights of Truth about that. They have already started their campaign to rid the city of the militia. The so-called Freeport Militia is not to be trusted."

*Note: Captain Hazran and Cain Darkmoore give identical surface-level quests (kill Deathfist orcs) but their "bigger problem" responses are mirror images of each other — each points to the other faction as the real enemy.*

---

### Guard Alayle (undercover agent, freportw)
File: `Guard_Alayle.lua`

A Freeport Militia guard who is secretly a spy for the Knights of Truth.

**Hail:**
> "Greetings, citizen! You should not be in the Militia House. These are restricted grounds. Please leave at once unless you have business here."

**To Paladins only, with secret code:**
> "Ssshhh!! Pipe down. The others might hear you. You must have something for me. Kalatrina must have given you something if you serve the Hall of Truth. If you have nothing please leave. You will blow my cover."

**After receiving sealed letter:**
> "This is not good news. I must leave immediately. Here. Take this to Kala.. I mean my father. I found it on the floor of Sir Lucan D'Lere's quarters. Thanks again, messenger. I got this just in time."

**When signal is received (enemy arrives):**
> "Oh no!! It is too late!! Run!!"

*Note: This NPC is one of the most lore-rich in Freeport — an embedded spy, moral complexity, reference to Sir Lucan D'Lere (the militia's evil leader), and the Knights of Truth's hidden network.*

---

## North Qeynos (qeynos2)

Qeynos is the "good" city of Antonica. Its lore focuses on civic virtue, corruption within its own guard ranks, and the constant gnoll threat from Blackburrow.

### Dranom Ghenson (merchant, qeynos2)
File: `Dranom_Ghenson.lua`

**Hail:**
> "Hello there, [name]. My name's Dranom Ghenson. My daughter, Aenia, and I moved out here from Freeport about a year ago. That dump of a city is just horrible! I feel that Qeynos is a much safer place for Aenia and myself to set up our shop. I only have a few things to sell right now, but hopefully business will pick up soon."

**On "Aenia":**
> "Aenia is my beautiful daughter. Many so-called men have tried to win her hand in marriage, but none of them have been able to live up to my standards. My daughter shall have a nobleman or a wealthy merchant... certainly not some lowly bard, like that Behroe she's been seeing. If I ever catch him, or one of his cronies, around my daughter again, I'll bash their good-for-nothing heads in."

*Note: This NPC has a hidden storyline — his daughter Aenia has a secret romance with a bard, creating a minor social conflict subplot. The merchant's prejudice against bards is period-appropriate (bards were seen as vagabonds).*

### Guard Deregan (city guard, qeynos2)
File: `Guard_Deregan.lua`

**Hail:**
> "Hail, [name]. I am Deregan. I used to be an adventurer much like yourself. Of course I was not as frail and childlike as you appear to be."

*The retired adventurer trope — a guard who talks down to new adventurers from experience.*

### Faldor Hendrys (merchant/scholar, qeynos2)
File: `Faldor_Hendrys.lua`

**Hail:**
> "What, [name]? Do I look like a merchant to you? Just because all these merchants are in my library, it doesn't mean that I am one. If you are interested in something other than spell scrolls, then, we can talk."

---

## Halas (halas)

Halas is the Barbarian city in Everfrost Peaks. The culture is martial, clannish, and cold-weather adapted. The Rogues of the White Rose operate as a surprisingly sophisticated thieves' guild within this rough-edged city.

### Cappi McTarnigal (Rogues of the White Rose, halas)
File: `Cappi_McTarnigal.lua`

**Hail:**
> "Hail there, [name]! If you are not a member of the White Rose, then it be best that you stay on the lower level. This here floor is for honest... ermm respectable rogues only."

**On "member of the White Rose":**
> "I hope that you are indeed respectable and loyal to Halas and the Rogues of the White Rose. To do otherwise would bring the wrath of the Six Hammers down on you. But enough with talk! Our caravan to the frigid north leaves in less than two days, and we are short on mammoth calf hides. Return four of them and you will be given items that show your loyalty to our Clan."

**After successful turn-in:**
> "You returned? We believed the gnoll pups got you. The caravan has already left, and these do me little good now. But, as I said before, one must remain respectable. Here is what I promised."

*Note: "The Six Hammers" is a reference to internal Halas enforcement. Mammoths are the key survival resource in the Everfrost region. The mild humor of "honest... ermm respectable rogues" acknowledges the contradiction of the guild's name.*

---

## Neriak (neriaka / neriakb / neriakc)

Neriak is the Dark Elf city, a place of rigid hierarchy, devotion to Innoruuk (god of hatred), and thinly-veiled contempt for all outsiders. The city has three sections with increasing prestige: Foreign Quarter (common trade), Neriak Commons (residential), 3rd Gate (the inner sanctum of power).

### Guard Lumpin (Foreign Quarter guard, neriaka)
File: `Guard_Lumpin.pl`

A troll employed as a guard in Neriak's Foreign Quarter.

**Hail:**
> "Hullo citizen. Me am here to guard you so puts away any wepuns."

**On "happy love bracers":**
> "Hmm... Me seen green bracers on troll named Ratraz."

**On "Ratraz":**
> "Ratraz is dumb troll who werk in dark elf bar. Him tink he smart because dark elves raise him. Tink he know everyting. Him just as stewpid as all us trolls is!"

**On death:**
> "My comrades will avenge my death."

*Note: The broken grammar is characteristic of Troll NPCs in Classic EQ. The dialog reveals Neriak's social structure: trolls serve as low-level muscle while aware enough to note their own diminished status ("just as stewpid as all us trolls is!").*

### High Priestess Alexandria (Neriak 3rd Gate)
File: `High_Priestess_Alexandria.pl`

**Hail:**
> "Greetings child, what business do you have here? I'm sorry but I will only deal with Clerics that are willing to prove their loyalty to Innoruuk. I cannot deal with every single heathen that feels it is necessary to bid me a good day. If you are a Cleric of Innoruuk I might be able to aid you in your training."

**To Dark Elf Clerics only — on "Cleric of Innoruuk":**
> "Is that so [race] [name]. Well from the looks of you I wouldn't say you are much of anything yet. However, if you have the willingness and determination to serve your God then there might just be more hope for you then I would have thought."

**On the armor quest — setting tone:**
> "Obviously, to move forward in your training, you will need to shield yourself from your enemies and from the elements. I believe I have something that could help you if you are still interested in proving yourself."

**On the helmet quest:**
> "A Helm you say [name]? This should be a good test for you to see if you are able to gather the correct items and annihilate those disgusting clerics that follow that worthless God Rodcet Nife. Seek out 1 Helm of the Lifebringer..."

*Note: The explicit command to hunt and kill priests of Rodcet Nife (the healing god) establishes the theological conflict central to Neriak. Innoruuk and Rodcet Nife are diametrically opposed — hatred vs. restoration.*

**On the final test:**
> "Well, I must say that I did not expect you to progress in your training at the rate you have. For your final test, I will need you to collect journal pages from the Ultricle. You have come too far to fail me now. I hope to see you soon... alive, that is."

### Lokar To-Biath (Scribe of Innoruuk, Neriak 3rd Gate)
File: `Lokar_To-Biath.pl`

**Hail:**
> "I am the Scribe of Innoruuk. If you do not have business with me, begone!"

**On "Innoruuk":**
> "I am his scribe, and He is our god. There is nothing else to be said."

**On "Scribe of Dal" (lore breadcrumb):**
> "The Scribes of Dal? All of them are long since dead... or at least most would say that."

**On "dead":**
> "Perhaps, perhaps not. I cannot remember, but perhaps Innoruuk would help me remember should you tithe him a bottle of red wine from the Blind Fish."

**After tithe (red wine):**
> "Ah, yes, let me pray to our god... Yes, Innoruuk has given me wisdom. A Scribe of Dal still exists, disguised as a barkeep in the Blind Fish. This information will not help you though, for she has sworn a vow of silence and will not speak of the Dal."

*Note: This dialog is part of the "Tome of Ages" quest chain, a classic EQ lore quest. The Dal are an ancient Dark Elf sect with forbidden knowledge. The NPC's combination of contempt for outsiders and genuine religious devotion is characteristic of 3rd Gate Neriak.*

---

## Cabilis (cabwest / cabeast)

Cabilis is the Iksar city in Kunark. The Iksar are a reptilian race who once ruled a great empire before its fall. Now they rebuild slowly under the Legion of Cabilis while pursuing ancient Iksar traditions of necromancy and shadowknight arts. The tone is cold, hierarchical, and militaristic.

### Harbinger Glosk (Necromancer Guildmaster, cabwest)
File: `Harbinger_Glosk.pl`

**On first approach (if player has Guild Summons):**
> "I am Harbinger Glosk. The time has come young one. You have chosen the path of the Necromancer. Open your inventory and read the note within. Once you are ready to begin your training, hand the note to me and we will continue."

**Hail:**
> "You dare to interrupt me? You had best have a good reason. I care not for small talk."

**On "new revenant" (higher rank):**
> "Yes. You are [a new revenant]. You shall do as I command. Take this. It is incomplete and must be ready for the emperor within the half season. You must find the Four Missing Gems. When you have them, then you will have to Quest for the Grand Forge of Dalnir. Within it's fire, all shall combine. Return the Sceptre to me with your Revenant Skullcap. Go."

**On "Forge of Dalnir":**
> "I know little of it other than that it once belonged to the ancient Haggle Baron, Dalnir. From what I have read, its fires require no skill, but will melt any common forge hammer used. Dalnir was said to have called upon the ancients for a hammer which could tolerate the magickal flames."

**After receiving initiation:**
> "Another apprentice has reached rebirth. You now have become one with the Brood of Kotiz. We study the ancient writing of Kotiz. Through his writing we have found the power of the dark circles. Listen well to the scholars within this tower and seek the Keepers Grotto for knowledge of our spells. This drape shall be the sign to all Iksar that you walk with the Brood. Now go speak with Xydoz."

*Note: The tone throughout is command-oriented, impersonal, and allusive. "The Brood of Kotiz" and "Kotiz's writings" reference Iksar lore without fully explaining it — classic EQ's approach to in-world lore (the world exists, you discover it).*

### Master Kyvix (Rank 5 trainer, cabwest)
File: `Master_Kyvix.pl`

**Hail:**
> "Quite busy!! Quite busy!! Things must be done. New components to be collected!!"

**On "New components":**
> "Yes, yes!! I will need components from beyond the gates. I must find an apprentice of the third rank."

**On "apprentice of the third rank":**
> "If you truly be an apprentice of the third circle, then there is a Dark Binder skullcap to be earned. Take this sack and fill it with a creeper cabbage, a heartsting telson with venom, brutling choppers and a scalebone femur."

**On becoming Revenant (after final turn-in):**
> "Welcome, Revenant [name]. You have done well. The Harbinger awaits you. He seeks a new revenant."

*Note: Master Kyvix's frenetic energy contrasts with Harbinger Glosk's cold contempt — showing range within the Cabilis NPC roster.*

---

## Katta Castellum (Luclin)

Katta Castellum is the city of Combine Empire refugees on Luclin. The lore is more complex and mysterious than Classic-era cities, dealing with ancient conflicts, vampirism, and Luclin's alien environment.

### Autarkic Lord Sfarosh (Order of Autarkic Umbrage, katta)
File: `Autarkic_Lord_Sfarosh.pl`

A vampire lord who was imprisoned in the castellum by Nathyn Illuminious.

**After being freed:**
> "Meddling fleshlings! Why have you pulled back to this forsaken castellum? Do you fear that I will seek vengeance on Nathyn Illuminious and the city that shelters him for my years of captivity here? Or do you seek something more dangerous, knowledge of the dark path of shadows?"

**On his dealings (signal 2):**
> "A simple question indeed. I simply supplied him with Akhevan blood for his experimentation, that is all. The Order of Autarkic Umbrage is no friend of the Akheva and it was possible that his research could uncover some useful information for my order."

**On Akhevan blood effects (signal 3):**
> "I am amazed at how little you fleshlings know of what occurs within the very walls of your own castellum. It is known by my Order that Akhevan blood has strange mutagenic effects on the bodies of non-akheves if introduced to their circulatory systems. The process by which the Shadow Tegi are infused with the blood is quite complicated and painful but I would deduce that a vampyre like Valdanov merely had to ingest the blood for the mutagenic agents to effect his physiology, causing the permanent change into what I believe you call a Vampyre Volatilis."

**When combat begins:**
> "Attempt to slay me if you so desire, and if you succeed it matters not. I will return as I am a creature of shadows and shadows never die, merely slumber!"

*Note: Sfarosh's dialog establishes the Akheva as biologically unique (their blood is mutagenic to other creatures) and introduces the "Vampyre Volatilis" as a distinct vampire type created by Akhevan blood exposure. The Order of Autarkic Umbrage is a Luclin-specific faction.*

---

## Shadow Haven (Luclin)

Shadow Haven is the neutral hub city on Luclin, openly accepting travelers from all factions. Its tone is businesslike and welcoming compared to the faction-gated cities of Norrath.

### Adept Arnthus (Shadow Haven entry area)
File: `Adept_Arnthus.pl`

**Hail:**
> "Due to the problems we have had lately with dishonorable visitors to the Haven we require all newcomers to see Daloran and Mistala for some simple tasks to prove that your intentions are good. I hope to see you soon."

*Note: Even the "neutral" city requires a trust-building step. Shadow Haven has been tested by bad actors and now screens newcomers. The tone is politely cautious rather than hostile.*

---

## Deity-Aligned Dialog Patterns

Across cities, faction-gated dialog reveals how deities shape NPC attitudes:

**Innoruuk (Neriak):** NPCs are contemptuous of non-Dark Elves, demanding of devotees, and explicitly hostile to Rodcet Nife worshippers. Quests require killing "enemy" clerics.

**Rallos Zek (Halas, Oggok):** Dialog emphasizes strength, martial prowess, and clan loyalty. Barbarians test adventurers by belittling them ("not as frail as you appear").

**Brell Serilis (Kaladim):** Dwarven NPCs are businesslike and guild-focused, centered on mining and crafting. Less religiously explicit than Innoruuk devotees.

**Tunare (Felwithe, Kelethin):** High and Wood Elf NPCs are graceful, nature-connected, and suspicious of non-elf races. Quests involve protecting the forest.

**Cazic-Thule (Feerrott, Oggok adjacent):** Fear-theme NPCs are cruel and threatening. The Feerrott is dominated by Lizardmen (Allize Taeew / Allize Volew) who serve Cazic-Thule.

**Combine Empire (Katta Castellum, Luclin):** Combine citizens are cosmopolitan, scholarly, and concerned with ancient history. Dialog references the old empire frequently.
