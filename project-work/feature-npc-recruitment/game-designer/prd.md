# NPC Recruitment / Recruit-Any-NPC Companion System — Product Requirements Document

> **Feature branch:** `feature/npc-recruitment`
> **Author:** game-designer
> **Date:** 2026-02-25
> **Status:** In Review (lore-master feedback incorporated)

---

## Problem Statement

Our custom EverQuest server is designed for 1-6 players exploring Classic
through Luclin content originally built for dozens or hundreds. Phase 3
(small-group-scaling) rebalanced encounters to be beatable by small groups,
but a fundamental gap remains: **party composition**.

A solo player or duo lacks the tank, healer, crowd control, and DPS roles
that EverQuest's class-interdependent design demands. Even with scaled-down
encounters, a solo wizard has no healer, a solo cleric has no DPS, and a
duo of melee fighters has no slower or crowd control. The game's class
system creates hard dependencies that player count alone cannot solve.

The companion recruitment system solves this by letting players recruit
NPCs from the living world to fill missing party roles. Unlike generic
hired mercenaries, these are actual characters from Norrath — the guard
who patrols South Qeynos, the Steel Warrior who remembers when Freeport
had honor, the Coldain dwarf who has seen Kael Drakkel's shadow on the
horizon. Combined with the soul element system from Phase 3
(npc-llm-phase3), recruited companions have personalities, memories, and
ongoing conversations that develop over time. They are not disposable
helpers but party members with character.

NPC allegiance-shifting is not new to Norrath. Guard Alayle serves as a
Knight of Truth spy embedded in the Freeport Militia. The Erudite Heretics
defected from Erudin to found Paineel. Corrupt Qeynos Guards sold their
loyalty to the Circle of Unseen Hands. Even Lucan D'Lere himself was once
a paladin before his fall. NPC loyalty in Norrath has always been
conditional on circumstances and opportunity. The recruitment system taps
this existing narrative truth — it extends a pattern already woven into
the world's fabric, rather than inventing something foreign.

This is the defining feature of the server: a world where every NPC is a
potential companion, and building your adventuring party is itself an
adventure.

## Goals

1. **Any eligible NPC in the world can be recruited.** A player can
   approach any non-quest-critical, non-merchant, non-boss NPC that is
   within 3 levels of the player's level and attempt to recruit them
   through dialogue. Success depends on faction standing, persuasion
   (which varies by culture — charisma, strength, or proven deeds), and
   the NPC's individual disposition (from the soul element system).

2. **Recruited NPCs fill real party roles.** They fight, heal, tank, and
   cast spells according to their class. A recruited cleric heals. A
   recruited warrior tanks. A recruited wizard nukes. The AI must be
   competent enough that a solo player with a full party of recruits can
   clear content designed for a player group.

3. **Recruits feel like characters, not tools.** Through integration with
   the soul/LLM system, recruits can be spoken to, develop personalities
   over time, and react to events in character. The player should feel
   like they are adventuring with people, not managing combat bots.

4. **Recruitment respects the cultural identity of Norrath.** Not all NPCs
   join for the same reasons. A Qeynos guard joins out of restlessness and
   duty to a worthy cause. A Teir'Dal joins out of calculated self-interest
   and never uses the word "loyalty." An Ogre follows because you are
   strong. A Halfling joins because it sounds like fun. The system must
   honor each culture's voice and motivation, not flatten them into
   generic "willing followers."

5. **Two recruitment modes reflect lore reality.** NPCs from cultures that
   value companionship and shared purpose (Qeynos, Halas, Kelethin,
   Rivervale, Shar Vahl) can be recruited as **companions** — loyal party
   members who develop genuine attachment. NPCs from cultures built on
   self-interest and power (Neriak, Cabilis, Oggok) can only be recruited
   as **mercenaries** — tactical allies who stay as long as the arrangement
   serves them. Both function identically in combat; the difference is in
   dialogue, memory framing, and lore consistency.

6. **Group composition scales naturally with player count.** A solo player
   can recruit up to 5 NPCs (filling a full group of 6). A duo can
   recruit up to 4. A full group of 6 players needs no recruits. The
   system automatically adapts to party size.

## Non-Goals

- **Recruiting quest-critical NPCs.** NPCs who are essential to active
  quest lines, progression flags, or zone access cannot be recruited.
  Their role in the world's quest infrastructure takes priority.

- **Recruiting merchants, bankers, guildmasters, or city leaders.** NPCs
  who provide essential city services remain at their posts. You cannot
  recruit a spell vendor and carry a shop around with you.

- **Companion equipment management.** Recruits use the stats and
  equipment of their original NPC definition. Players cannot trade gear
  to recruits or customize their loadouts. (Potential future feature.)

- **Recruit-to-recruit social interaction.** Recruits do not talk to each
  other or develop relationships with other recruits. They interact with
  the player only. (Party composition tensions are expressed through
  individual dialogue, not NPC-to-NPC conversation.)

- **Raid-size companion armies.** The system is bounded by the 6-member
  group limit. You cannot have more recruits than your group has open
  slots.

- **Cross-zone persistence without the player.** Recruits exist only while
  grouped with the player. They do not independently exist in the world
  when the player logs off.

- **Permadeath.** Recruits can die and be revived. They are not permanently
  lost on death.

- **Froglok recruits.** In the Classic-Luclin era, Frogloks are dungeon
  inhabitants in Guk, not an organized civilization with recruitable
  NPCs. Grobb is Troll territory. The Froglok playable race and Gukta
  conversion are post-Luclin (Legacy of Ykesha).

## User Experience

### Player Flow: Recruiting a Companion

1. **Discovery.** The player is adventuring in South Qeynos and notices
   Guard Noyan patrolling near the gate. The player's soul element data
   (Phase 3) already established that Noyan has a "restless" disposition —
   he sometimes hints at wanderlust in conversation.

2. **Approach.** The player targets Guard Noyan and hails him. Noyan
   responds with his normal dialogue (via the LLM system). The player can
   chat with Noyan naturally.

3. **Recruitment attempt.** The player says "recruit" (or "join me", "come
   with me", "I could use your help"). This triggers the recruitment
   check. The system evaluates:
   - **Faction:** Player's standing with Noyan's faction (Guards of Qeynos).
     Must be at least Kindly to attempt recruitment.
   - **Level:** Noyan must be within 3 levels of the player.
   - **Persuasion check:** For Qeynos guards (Human culture), CHA is the
     primary persuasion stat. Noyan responds to personal magnetism.
   - **Disposition:** Noyan's soul element disposition ("restless") makes
     him more willing. A "rooted" NPC would be nearly impossible.
   - **NPC eligibility:** Noyan is not a quest NPC, merchant, banker,
     guildmaster, captain, or boss. He is eligible.

4. **Outcome — Success.** The check passes. Noyan responds through the LLM
   system: "The gnolls push south every season. Behind these walls, you can
   only hold the line. Out there, you could end the raids." Noyan joins the
   player's group as a **companion** (Qeynos culture supports genuine
   companionship). His spawn point in South Qeynos is vacated. A
   replacement guard spawns in his place after a delay.

5. **Outcome — Failure.** The check fails. Noyan responds with a refusal
   shaped by his personality: "My post is here, citizen. Antonius Bayle
   counts on the guard." The player can try again after a cooldown, or
   improve their faction/charisma first.

6. **Adventuring together.** Noyan follows the player as a group member.
   He fights using warrior AI — taunting enemies, using combat abilities,
   positioning for melee. Between fights, the player can talk to Noyan
   through the LLM system, and his responses are shaped by his soul
   elements and memories of their shared adventures.

### Player Flow: Recruiting a Mercenary (Dark Elf / Iksar)

1. A level 30 Teir'Dal shadowknight wants a companion from Neriak. He
   finds a Dreadguard Outer warrior, level 29, with "content" disposition
   (the maximum for Teir'Dal — no Neriak NPC is ever Restless or Eager).

2. He says "join me." The recruitment check uses CHA (Teir'Dal respond to
   social manipulation, though they respect it less than other cultures).
   The check passes.

3. The Dreadguard responds in authentic Teir'Dal voice: "Your offer holds
   marginal appeal. I find the arrangement may serve my purposes. Do not
   mistake this for loyalty."

4. The Dreadguard joins as a **mercenary**, not a companion. In combat,
   she functions identically. In conversation, her dialogue never expresses
   warmth, friendship, or belonging. If re-recruited later, her memory
   callbacks are calculating: "You were here before. Your service was
   noted." Never: "It is good to see you again."

5. If the player's faction with the Dreadguard Outer drops below Warmly
   while the mercenary is recruited, the mercenary may voluntarily depart
   (with warning). Mercenaries have no loyalty — the arrangement must
   remain profitable.

### Player Flow: Recruiting an Ogre (STR-Based)

1. A level 20 warrior finds an Oggok guard, level 19. Ogres do not
   respond to charisma — they respect strength and demonstrated power.

2. The player says "join me." The recruitment check uses STR (not CHA)
   and the player's level relative to the NPC. Complex emotional appeals
   do not register with Ogres.

3. **Success:** "You fight good. Me come." (Simple vocabulary only.
   Ogre dialogue must never use complex sentences.)

4. **Failure:** "No. Me stay here. You go."

### Player Flow: Managing Recruits

1. **Commands.** The player manages recruits through say commands:
   - `/say recruit` (while targeting an NPC) — attempt recruitment
   - `/say dismiss` (while targeting a recruit) — dismiss, who returns
     to their original spawn point
   - `/say guard here` (while targeting a recruit) — hold position
   - `/say follow me` (while targeting a recruit) — follow player
   - `/say aggressive` / `/say passive` / `/say balanced` — set stance

2. **Group window.** Recruits appear in the standard EQ group window as
   group members. The player can see their health, mana, and target. The
   group window is the primary status display.

3. **Recruit death.** When a recruit dies, they leave a corpse. They can
   be resurrected by a player or another recruit with resurrection spells.
   If not resurrected within 30 minutes, the corpse despawns and the
   recruit returns to their original spawn point. The player can return
   to the NPC's home location and recruit them again (the NPC remembers
   them via the LLM memory system).

4. **Zone transitions.** When the player zones, recruits zone with them
   (like mercenaries in the existing system). Recruits persist across
   zone changes as long as the player is online.

5. **Logging off.** When the player logs off, recruits are suspended.
   When the player logs back in, recruits respawn with the player.
   State (HP, mana, buffs) is preserved across sessions.

### Player Flow: Dismissing a Recruit

1. The player targets their recruit and says "dismiss" (or "return home",
   "you're free to go").
2. The recruit responds in character, shaped by their culture:
   - *Qeynos guard (companion):* "It has been an honor. Perhaps our paths
     will cross again. May the Prime Healer watch over you."
   - *Teir'Dal Dreadguard (mercenary):* "Our arrangement concludes. Do
     not seek me unless you have something worth my time."
   - *Ogre (mercenary):* "Me go back now."
3. The recruit despawns from the group.
4. The replacement NPC at the original spawn point despawns, and the
   original NPC resumes their post.
5. The recruit retains memories. If recruited again later, they remember.

### Example Scenario: Building a Full Party

A level 25 human ranger plays solo. She wants to tackle Unrest, a dungeon
designed for a full group. She needs a tank, a healer, and some DPS/utility.

1. **Recruiting a tank.** She travels to North Qeynos and finds Guard
   Ethan, a level 24 warrior with a "curious" disposition. Her faction
   with the Guards of Qeynos is Warmly. She hails him, chats about the
   dangers of Unrest, and says "join me." The recruitment check passes —
   Warmly faction + decent CHA + curious disposition. Ethan joins as a
   **companion**.

2. **Recruiting a healer.** She visits the Temple of Life and finds
   Priestess Caulria, a level 26 cleric with a "restless" disposition.
   Ally faction with the Priests of Life makes this easy. Caulria joins
   as a **companion**: "The Prime Healer teaches that suffering must be
   met where it lives. Let me walk with you."

3. **Recruiting utility.** She needs crowd control. In Qeynos Hills she
   finds Lynuga, a level 25 enchanter NPC with an "eager" disposition.
   The recruitment is almost automatic. Lynuga joins as a **companion**.

4. **Recruiting DPS.** She recruits a level 24 rogue from the Circle of Unseen
   Hands in South Qeynos. Content disposition, but Ally faction
   overcomes it. Joins as a **companion**.

5. **The party.** She now has a group of 5: herself (ranger), Guard Ethan
   (warrior/tank), Priestess Caulria (cleric/healer), Lynuga
   (enchanter/CC), and a rogue (DPS). The group enters Unrest.

6. **In combat.** Ethan taunts and positions. Caulria heals and buffs.
   Lynuga mezzes adds. The rogue backstabs. The ranger pulls and DPSes.
   Between pulls, she can talk to any recruit about the dungeon, their
   past, or just banter — and each responds according to their personality.

### Example Scenario: Cross-Cultural Recruitment

A level 35 barbarian shaman from Halas has built Warmly faction with the
Steel Warriors of Freeport through proving his strength in combat. He
finds a Steel Warrior, level 34, with "curious" disposition. The Steel
Warriors respect merit over race — the barbarian has proven himself.

He says "join me." The persuasion check uses a blend of STR and CHA
(Barbarians and Steel Warriors respect strength, but the shaman's social
skills matter too). The check passes.

The Steel Warrior responds: "I remember when this city had honor. Maybe it
still does — out on the road, at least."

The Steel Warrior joins as a **companion** (Steel Warriors are honor-focused
and capable of genuine loyalty). Later, if the shaman recruits a Neriak
Dreadguard (mercenary), the Steel Warrior's dialogue may occasionally
reference discomfort with the arrangement — but will not refuse to fight
alongside them. The player chose the party; the recruit respects the
player's judgment.

## Game Design Details

### Mechanics

#### Recruitment Types

The system distinguishes two types of recruited NPCs based on their
cultural background:

| Type | Cultures | Join Motivation | Dialogue Tone | Retention |
|------|----------|----------------|---------------|-----------|
| **Companion** | Qeynos, Halas, Erudin, Kaladim, Ak'Anon, Felwithe, Kelethin, Rivervale, Shar Vahl, Shadow Haven, Katta Castellum, Freeport (Steel Warriors, Knights of Truth) | Shared purpose, adventure, duty, honor, curiosity | Can express warmth, loyalty, friendship over time | Stable; stays unless dismissed |
| **Mercenary** | Neriak, Cabilis, Oggok, Grobb, Paineel, Freeport Militia | Self-interest, power, better opportunity, escape from boredom | Never expresses warmth or loyalty. Calculating, cold, or blunt | May depart if faction drops below Warmly |

Both types function identically in combat. The distinction is purely
narrative — it shapes dialogue, memory framing, and the emotional texture
of the relationship. This distinction is enforced by the LLM context layer,
not by mechanical differences.

#### Recruitment Eligibility

An NPC is eligible for recruitment if ALL of the following are true:

1. **Level range:** NPC level is within [player_level - 2, player_level + 2].
2. **Faction standing:** Player's faction with the NPC is at least Kindly
   (FACTION_KINDLY = 3). Warmly and Ally faction provide significant bonuses to the
   recruitment roll.
3. **NPC type:** The NPC is not on the exclusion list (see below).
4. **Group capacity:** The player's group has at least one open slot
   (fewer than 6 members).
5. **Not already recruited:** The NPC is not currently serving as another
   player's recruit.
6. **Cooldown:** The player has not failed a recruitment attempt on this
   specific NPC in the last 15 minutes.
7. **Not in combat:** Neither the player nor the NPC is currently in combat.

#### Recruitment Exclusion List

The following NPC types can NEVER be recruited:

**Structural exclusions (by NPC type/flag):**
- **Merchants** (NPC class 41 / MERCHANT)
- **Bankers** (NPC class 40 / BANKER)
- **Guildmasters / Class trainers** (identified by GM flag or trainer status)
- **Quest NPCs with active quest scripts** (identified by having Lua/Perl
  quest files that handle quest events beyond simple hail)
- **Raid bosses and named dungeon bosses** (identified by `rare_spawn` flag
  or curated exclusion list)
- **Aura, trap, or object NPCs** (non-character entity types)
- **NPCs with bodytype 11 (Untargetable) or 64+ (special/invisible)**
- **Player pets, bots, or other recruits**
- **Frogloks** (not an organized civilization in Classic-Luclin era)

**Named lore anchor exclusions (curated list — lore-master reviewed):**
- **Lucan D'Lere** — He IS the Freeport civil war. Removing him collapses
  the Knights of Truth storyline.
- **Antonius Bayle IV** — His moral authority defines Qeynos.
- **King Naythox Thex** — The entire Teir'Dal power structure descends
  from him.
- **Raja Kerrath** — The Vah Shir king fighting the Grimling War.
- **Captain Tillin** — Named city guard captain. His post is structural.
- **High Priestess Alexandria** — Theological anchor of the Dismal Rage.
- **Harbinger Glosk** — Anchors the Brood of Kotiz storyline in Cabilis.
- **Dreadguard Inner (all members)** — Under Innoruuk's direct religious
  mandate. Their loyalty is theologically bound to Neriak's inner sanctum.
- **All guildmasters in their home city** — Structural anchors of their
  guild's continuity.
- **All named city rulers and major faction leaders**
- **All named military commanders** (captains, generals, etc.)

**Named guards below captain rank may be recruited** if their disposition
permits. "Guard Noyan" is eligible; "Captain Tillin" is not.

#### Racial Disposition Caps

Not all cultures permit the full range of dispositions. The soul element
system must enforce these caps, which reflect deep cultural identity:

| Culture | Max Disposition | Recruitment Type | Rationale |
|---------|----------------|-----------------|-----------|
| Qeynos, Halas, Kelethin, Rivervale, Shar Vahl | Eager | Companion | Open cultures that value individual choice |
| Erudin, Felwithe, Kaladim, Ak'Anon | Restless | Companion | Structured cultures, but individuals can dream |
| Freeport (non-Militia) | Eager | Companion | Chaotic city; many NPCs seeking something better |
| Shadow Haven, Katta Castellum | Eager | Companion | Cosmopolitan, multi-race tolerance |
| Neriak (Teir'Dal) | Content | Mercenary | Innoruuk's theology teaches that alliance is weakness. No Teir'Dal expresses eagerness to join an outsider. |
| Cabilis (Iksar) | Content | Mercenary | Xenophobic, empire-bound identity. Even willing Iksar frame joining as tactical alliance, never belonging. |
| Oggok (Ogre) | Curious | Mercenary | Divine curse limits complex motivation. They follow strength, not aspiration. |
| Grobb (Troll) | Restless | Mercenary | Self-interest and better opportunity. They may follow a player who respects them more than Neriak does. |
| Paineel (Heretics) | Restless | Mercenary | Defiant by nature, but cold and scholarly. Never warm. |

#### The Persuasion System

Unlike a single charisma check, persuasion varies by the NPC's culture.
Each culture responds to different forms of influence:

| NPC Culture | Primary Stat | Secondary Factor | Rationale |
|-------------|-------------|-----------------|-----------|
| Human (Qeynos, Freeport) | CHA | Faction standing | Respond to personal magnetism and social standing |
| Halfling (Rivervale) | CHA | — | Value charm and wit above all; CHA has highest weight here |
| High Elf (Felwithe) | CHA | Player level | Respect both social grace and demonstrated capability |
| Wood Elf (Kelethin) | CHA | Faction standing | Communal; respond to those accepted by their people |
| Half Elf | CHA | Faction standing | Blend of human and elven social norms |
| Erudite (Erudin, Paineel) | INT | Player level | Respect intellectual achievement and demonstrated mastery |
| Dwarf (Kaladim) | CHA | STR | Respect craft and strength alongside social bonds |
| Gnome (Ak'Anon) | INT | CHA | Intellectually curious, but also socially playful |
| Barbarian (Halas) | STR | Player level | Respect proven strength; "The cold takes the weak. You are still standing." |
| Ogre (Oggok) | STR | Player level | Only understand strength and power. CHA has near-zero impact. |
| Troll (Grobb) | STR | CHA | Respect strength first, but can be swayed by a silver tongue |
| Dark Elf (Neriak) | CHA | INT | Respond to social manipulation and intellectual power, but trust neither |
| Iksar (Cabilis) | Player level | STR | Respond to demonstrated rank and martial power, not personal charm |
| Vah Shir (Shar Vahl) | CHA | Faction standing | Honor framework; proven deeds matter most, expressed through faction |

**Persuasion formula:**

```
persuasion_bonus = (primary_stat - 75) / 5 + (secondary_factor_bonus)
```

Where secondary_factor_bonus is:
- Faction standing: +0 (Kindly), +5 (Warmly), +10 (Ally)
- Player level: +(player_level - npc_level) * 3 (capped at +10)
- STR as secondary: +(STR - 75) / 10

This replaces the single CHA modifier from the base formula. The primary
stat contributes roughly 2x the weight of the secondary factor.

#### The Recruitment Roll

When a player attempts recruitment, the system performs a weighted check:

**Base chance:** 50%

**Modifiers:**

| Factor | Modifier | Notes |
|--------|----------|-------|
| Faction: Ally | +30% | Maximum faction bonus |
| Faction: Warmly | +20% | Strong faction bonus |
| Faction: Kindly | +10% | Minimum required standing |
| Persuasion bonus | Variable | Culture-specific (see Persuasion System above) |
| Disposition: Eager | +25% | Almost guaranteed (only available to open cultures) |
| Disposition: Restless | +15% | Strong bonus |
| Disposition: Curious | +5% | Mild bonus |
| Disposition: Content | -10% | Mild penalty |
| Disposition: Rooted | -30% | Very difficult |
| Level difference (NPC higher) | -5% per level | Harder to recruit higher-level NPCs |
| Level difference (NPC lower) | +5% per level | Easier to recruit lower-level NPCs |
| Previous recruitment history | +10% | If this NPC was previously recruited by this player and remembers (via LLM memory) |

**Result:** Clamp final chance to [5%, 95%]. Roll 1-100. If roll <= chance,
recruitment succeeds.

**Hard blocks bypass the roll.** NPCs on the curated exclusion list (named
lore anchors, Dreadguard Inner, guildmasters, city rulers, military commanders)
are filtered out BEFORE the recruitment roll is evaluated. The 5% minimum
clamp never applies to them — they cannot be recruited under any circumstances,
regardless of faction, persuasion, or disposition.

**Examples:**
- Ally faction + high CHA (200) + Eager Qeynos guard + same level =
  50 + 30 + 25 + 25 + 0 = 130% -> clamped to 95%. Near-certain.
- Kindly faction + low CHA (75) + Content Iksar + NPC 3 levels higher =
  50 + 10 + 0 - 10 - 10 = 40%. Difficult (and the Iksar joined as
  mercenary, not companion).
- Ally faction + high STR (200) + Curious Ogre + same level =
  50 + 30 + 25 + 5 + 0 = 110% -> clamped to 95%. Ogre follows strength.

#### Companion Behavior and AI

Recruited NPCs fight according to their class archetype:

| Archetype | Classes | AI Behavior |
|-----------|---------|-------------|
| Tank | Warrior, Paladin, Shadowknight | Taunts target, positions in melee, uses defensive abilities. Highest aggro priority. |
| Healer | Cleric, Druid, Shaman | Heals group members below HP thresholds. Buffs out of combat. Cures debuffs. Resurrects dead group members. |
| Melee DPS | Rogue, Monk, Ranger, Beastlord | Engages target in melee. Uses class abilities (backstab, kick, etc.). Follows tank's target. |
| Caster DPS | Wizard, Magician, Necromancer | Nukes from range. Manages mana. Pets for pet classes. |
| Utility | Enchanter, Bard | Mezzes adds (enchanter). Runs songs (bard). Slows targets (enchanter/shaman). Haste and other buffs. |

All 15 Classic-Luclin classes are supported. Berserker (Planes of Power)
is excluded.

Recruits use the existing mercenary AI framework (stances, spell lists,
target selection) but with spell lists derived from their actual class and
level rather than from pre-built merc templates.

**Recruit stances** (settable by the player):

| Stance | Behavior |
|--------|----------|
| Passive | Does not engage in combat. Follows player. |
| Balanced | Fights when group is engaged. Heals when needed. Default. |
| Aggressive | Engages anything the player attacks immediately. Max DPS. |

#### Recruit Stats

Recruits use the stats from their original NPC type definition in the
database (`npc_types` table). This means:

- A guard NPC recruited has the guard's HP, AC, damage, resists, and
  skills as defined in the database.
- Stats scale with the NPC's level. NPCs close to the player's level
  are viable; NPCs far below would be weak.
- The 2-level recruitment window ensures recruits are always roughly
  appropriate for current content.

When the player levels up, recruits do NOT automatically level. A level 25
guard recruited at level 25 stays level 25. When the player reaches level
28, the recruit becomes less effective. The player can:
- Keep the recruit (they still function, just slightly weaker)
- Dismiss and recruit a new NPC at the current level
- Return to the NPC's home zone and recruit them again (NPCs respawn at
  their database level)

This creates a natural cycle of recruit turnover that keeps the player
exploring and meeting new NPCs rather than keeping the same party forever.

#### Recruit Spells

Recruit spell lists are derived from the NPC's class and level:

- The system maps each EQ class to an appropriate set of spells available
  at the recruit's level.
- Spell lists draw from the existing merc spell list infrastructure where
  possible, extended to cover all 15 Classic-Luclin classes.
- For classes not covered by existing merc spell lists (Enchanter, Bard,
  Necromancer, Druid, Shaman, Monk, Beastlord, Paladin, Shadowknight,
  Ranger, Magician), new spell list entries must be created.

#### What Happens to the Original NPC

When an NPC is recruited:
1. The NPC despawns from their original location.
2. A **replacement NPC** spawns in their place after a short delay (30-60
   seconds). The replacement is a generic unnamed version of the same type
   (e.g., "a Qeynos guard" instead of "Guard Noyan"). This prevents the
   world from having gaps in guard coverage or patrol routes.
3. The original NPC's spawn entry is flagged as "recruited" so they do not
   respawn at their home point while serving as a recruit.

When the recruit is dismissed or the player logs off:
1. The recruit despawns from the player's group.
2. The replacement NPC at the original spawn point despawns.
3. The original NPC respawns at their home location with their original
   name and stats.

#### Recruitment Dialogue Integration with LLM

The recruitment process leverages the existing LLM conversation system:

1. **Recruitment keywords** ("recruit", "join me", "come with me", "I could
   use your help") are intercepted by the quest script before reaching the
   LLM. The script performs the recruitment check.

2. **Success response:** The script provides the LLM with recruitment
   context that includes:
   - Whether this is a companion or mercenary recruitment
   - The NPC's disposition and cultural voice
   - Instruction to respond in 2-3 sentences maximum, in authentic
     culturally-specific dialogue (no modern sentiment)
   - Examples of culture-appropriate acceptance phrases

3. **Failure response:** The script provides the LLM with refusal context:
   - Culture-specific refusal patterns (see Racial Dialogue Constraints)
   - The NPC's reason for staying (duty, contentment, suspicion)
   - Instruction to never break character or use generic refusals

4. **Ongoing conversation:** Once recruited, the recruit's LLM context is
   updated to include their new role. Companion recruits gradually develop
   warmer dialogue. Mercenary recruits remain calculating and transactional.

#### Racial Dialogue Constraints

Culture-specific dialogue rules enforced by the LLM context layer:

| Culture | Acceptance Pattern | Refusal Pattern | Memory Callback |
|---------|-------------------|----------------|-----------------|
| Qeynos | Formal, duty-referenced, deity farewell | "My post is here, citizen." | Warm: "Good to see you again." |
| Halas | Brogue, test-passed, strength-acknowledged | "Ye've not proven yerself." | Blunt: "Ye came back. Good." |
| Neriak | Cold, calculating, never says "loyalty" | "Your arrogance is almost admirable. Almost. Leave." | Calculating: "You were here before. Your service was noted." |
| Cabilis | Tactical, xenophobic framing | "Your request is noted and denied." | Rigid: "You have served the Legion. Do not presume this grants you belonging." |
| Oggok | Simple vocabulary only (3-5 word sentences) | "No. Me stay here. You go." | Simple: "You again. We fight?" |
| Grobb | Broken grammar, self-interest | "Me no go with you." | Practical: "You back. What you want?" |
| Shar Vahl | Honor-referenced, shared deeds | "You have not earned this." | Honorable: "You have stood against the Grimlings. The Vah Shir remember." |
| Rivervale | Cheerful, Bristlebane humor | "Oh, sounds like a lark, but I've got pies in the oven!" | Warm: "Back for more trouble? Count me in!" |
| Erudin | Intellectually condescending acceptance | "Your proposal lacks sufficient intellectual merit." | Measured: "Your previous engagement showed... adequate competence." |

#### Party Composition Tensions

Some recruited NPCs come from cultures with deep historical enmity. When
these NPCs coexist in the same party, the system creates narrative tension
through individual dialogue rather than mechanical restrictions:

| Tension Pair | Expression |
|-------------|------------|
| Erudin NPC + Paineel NPC | Both may reference the Heretic Schism in dialogue. Neither refuses to fight, but occasional barbed comments surface. |
| Neriak NPC + Qeynos Priest | The Teir'Dal may express disdain for the healer's deity. The priest may reference darkness with concern. |
| Troll NPC + Froglok reference | If the party visits near Guk or Innothule, the Troll's dialogue may reference ancestral conflict. |
| Iksar NPC + any non-Iksar | The Iksar's dialogue carries constant low-level xenophobia: references to "warm-bloods" and Iksar superiority. |

**Design decision:** Party composition tensions are NARRATIVE ONLY. No
mechanical restrictions prevent mixing cultures. The player chose this
party; each recruit respects the player's authority to lead. But their
dialogue reflects their cultural reality — they do not pretend to like
each other.

#### Mercenary Retention

Mercenary-type recruits (Neriak, Cabilis, Oggok, Grobb, Paineel) have a
retention check that companion-type recruits do not:

- If the player's faction with the mercenary's home faction drops below
  Warmly while the mercenary is recruited, the mercenary receives a
  voluntary departure warning: "Our arrangement grows... less favorable.
  Rectify this, or I depart."
- If faction remains below Warmly for 10 minutes after the warning, the
  mercenary dismisses itself and returns to its spawn point.
- Companion-type recruits do NOT have this mechanic. They are loyal to
  the player, not to a transactional arrangement.

#### Maximum Recruit Count

The maximum number of recruits per player is determined by group capacity:

```
max_recruits = 6 - current_group_size
```

- Solo player: up to 5 recruits
- Duo: up to 4 recruits (2 players + 4 recruits = 6)
- Trio: up to 3 recruits
- Full 6-player group: 0 recruits

If a new player joins the group and it exceeds 6 members, the most recently
recruited NPC is automatically dismissed (with notification) to make room.

### Balance Considerations

#### 1-6 Player Scaling

The recruit system interacts with the small-group-scaling changes from
Phase 3 (34 rule changes, ~45K NPC stat reductions). Those changes made
content beatable by 1-6 players. Recruits make it **comfortable** for
1-3 players and **trivial** for none:

- **Solo player + 5 recruits:** Effectively a full group. Content should
  feel like a properly composed group. Not trivial, but manageable.
  Recruit AI is competent but not perfect — they will not chain-pull
  optimally or handle every mechanic flawlessly.

- **Duo + 4 recruits:** Slightly stronger than solo+5 because human
  players make better tactical decisions. Still within balance range.

- **Full group of 6 players:** No recruits needed. Content is tuned for
  this via Phase 3 scaling.

**Balance levers (tuning knobs):**

1. **Recruit stat scaling.** A global scale factor (percentage) applied to
   recruit stats. Default 100%. Can be reduced if recruits make content
   too easy, or increased if too hard.

2. **Recruit spell effectiveness.** Heal amounts and damage dealt by
   recruits can be scaled independently of their stats.

3. **Recruitment difficulty.** The base chance and modifier weights in the
   recruitment roll can be tuned via rule values.

4. **Level window.** The +/- 2 level recruitment range can be adjusted.

5. **Recruit count cap.** An optional hard cap (e.g., max 3 recruits
   regardless of group size) if full-recruit groups prove too strong.

#### Preventing Abuse

- **No recruiting in combat.** Players cannot recruit mid-fight.
- **Cooldown on failed attempts.** 15-minute cooldown per NPC prevents
  save-scumming the recruitment roll.
- **Faction requirement is real.** Kindly faction standing takes effort to
  earn for non-aligned races. Recruiting outside your cultural sphere is
  an achievement, not an entitlement.
- **Recruits contribute to group XP split.** A full group of 1 player +
  5 recruits splits XP the same as a group of 6 players.
- **Mercenary retention risk.** Mercenary-type recruits can leave if faction
  drops, creating a consequence for faction mismanagement.

### Era Compliance

This feature creates new game mechanics but does not reference any
post-Luclin content:

- **No mercenary UI is used.** The mercenary system was introduced in
  Secrets of Faydwer (2007). Our implementation uses dialogue-based
  recruitment and chat commands, which are era-neutral.
- **Classes available for recruitment** are restricted to 15 Classic-Luclin
  classes only. Berserker (Planes of Power) is excluded.
- **Zones and NPCs** referenced are limited to Classic, Kunark, Velious,
  and Luclin content.
- **Spell lists** use only Classic-Luclin era spells.
- **The group window** exists in Titanium and is era-appropriate.
- **Frogloks** are not recruitable (dungeon inhabitants in Classic-Luclin,
  not an organized civilization; Gukta/playable Frogloks are post-Luclin).

**What must NEVER appear in recruitment dialogue or mechanics:**
- Plane of Knowledge as a travel mechanic
- Wayfarer's Brotherhood or Lost Dungeons references
- Grobb converted to Gukta (in our era, Grobb is Troll territory)
- Berserker class on any recruitable NPC
- Crescent Reach / Drakkin (Prophecy of Ro era)

The concept of NPC allegiance-shifting has canonical EQ precedent: Guard
Alayle (spy), Corrupt Qeynos Guards (traitors), the Erudite Heretics
(factional defection), Lucan D'Lere (fallen paladin). This feature
extends an existing pattern through social mechanics (persuasion) rather
than magical ones (charm/summon).

## Affected Systems

- [x] C++ server source (`eqemu/`)
- [x] Lua quest scripts (`akk-stack/server/quests/`)
- [ ] Perl quest scripts (maintenance only)
- [x] Database tables (`peq`)
- [x] Rule values
- [x] Server configuration
- [ ] Infrastructure / Docker

Specifically:

- **C++ server source:** The recruit management system needs to be built
  on top of the existing Merc or Bot class infrastructure. This includes
  recruit spawning, group integration, AI behavior, zone persistence,
  and suspend/unsuspend. Custom logic for recruitment checks (with
  culture-specific persuasion stats), stat derivation from npc_types,
  and the replacement-NPC spawn system.

- **Lua quest scripts:** A global quest script intercepts recruitment
  keywords from player speech and triggers the recruitment flow.
  Individual NPC scripts can override default behavior (custom recruitment
  dialogue, special conditions). The LLM bridge is extended to support
  recruitment context including companion/mercenary type and culture-
  specific dialogue constraints.

- **Database tables:** New tables or extensions for tracking recruit
  state (which NPCs are recruited, by whom, original spawn data,
  companion vs. mercenary type). The existing merc tables may be adapted.
  Recruit spell lists for all 15 Classic-Luclin classes. An NPC exclusion
  list table. A persuasion-stat-by-culture mapping table.

- **Rule values:** New rules for recruitment (base chance, level window,
  cooldown timer, stat scale factor, max recruit count, XP contribution,
  mercenary retention timer).

- **Server configuration:** LLM sidecar configuration for recruitment
  context templates (companion acceptance, mercenary acceptance, refusal,
  and culture-specific dialogue constraint prompts).

## Dependencies

- **Small-Group Scaling (Phase 3):** Must be complete. Recruit balance
  assumes encounters are already tuned for small groups. **Status: Complete.**

- **NPC LLM Integration (Phases 1-3):** Must be complete. The soul element
  system (Phase 3) provides disposition data that gates recruitment
  willingness. The LLM conversation system provides natural recruitment
  dialogue and ongoing interaction. **Status: Phase 3 in progress.**

- **Merc/Bot system foundation:** The existing C++ `Merc` and/or `Bot`
  class provides the AI, grouping, and zone persistence infrastructure
  that recruits build on. No prior modification needed — this is existing
  EQEmu code. **Status: Available.**

## Open Questions

1. **Merc class vs. Bot class as foundation.** The Merc class has simpler,
   role-focused AI (Tank/Healer/DPS) but only 4 archetypes. The Bot class
   supports all 16 classes with full spell AI but is more complex. The
   architect should evaluate which provides a better foundation, or
   whether a new class (`Companion : public NPC`) is warranted.

2. **Spell list completeness.** The existing merc spell lists only cover
   Warrior, Cleric, Wizard, and Rogue archetypes. Recruits need spell
   lists for all 15 Classic-Luclin classes. How much can be borrowed from
   the bot spell system vs. needing to be built from scratch?

3. **Replacement NPC behavior.** When a named NPC is recruited and a
   generic replacement spawns, does the replacement serve the same quest
   functions? The architect should determine how to handle borderline
   quest NPCs.

4. **Recruit zone persistence implementation.** The merc system handles
   zone transitions through `ProcessClientZoneChange()`. Can this be
   reused, or does the recruit's dependency on npc_types data require a
   different approach?

5. **Performance impact of multiple recruits.** With up to 5 recruits per
   player and 6 players, there could be up to 30 recruit NPCs in a zone
   running AI, spell checks, and LLM queries simultaneously. The architect
   should evaluate performance and recommend mitigations.

6. **Recruit buff persistence.** The merc system has `merc_buffs` for
   cross-zone buff persistence. Can this be reused for recruits?

7. **Interaction between recruits and the pet system.** Pets do not occupy
   group slots in standard EQ. The architect should verify this remains
   true with recruits (a Magician with 4 recruits and a pet should work).

8. **Chat command namespace.** Should there be slash commands (e.g.,
   `/recruit dismiss`) in addition to say-link commands? The architect
   should evaluate Titanium client command extension capabilities.

9. **Culture-specific persuasion stat lookup.** The persuasion system uses
   different stats per culture. How should the NPC-to-culture mapping be
   stored? Options include the npc_types deity field, faction membership,
   zone-based defaults, or a new mapping table.

## Acceptance Criteria

### Recruitment
- [ ] A player can target an eligible NPC and say "recruit" to initiate
      a recruitment attempt.
- [ ] Recruitment succeeds or fails based on faction, persuasion (culture-
      specific stat check), level range, and NPC disposition.
- [ ] On success, the NPC despawns from their spawn point and joins the
      player's group.
- [ ] On failure, the NPC responds with a culturally-appropriate refusal
      via the LLM system and a 15-minute cooldown is applied.
- [ ] NPCs on the exclusion list cannot be recruited under any
      circumstances.
- [ ] NPCs outside the player's level range cannot be recruited.
- [ ] NPCs whose faction is below Kindly cannot be recruited.
- [ ] Racial disposition caps are enforced (no Eager Teir'Dal, no
      Restless Iksar, etc.).

### Recruitment Types
- [ ] NPCs from companion-eligible cultures join as companions with
      loyalty-appropriate dialogue.
- [ ] NPCs from mercenary-only cultures join as mercenaries with
      transactional dialogue.
- [ ] Mercenary recruits generate a departure warning if player faction
      drops below Warmly, and auto-dismiss after 10 minutes if not
      corrected.
- [ ] Companion recruits do NOT auto-dismiss on faction changes.

### Recruit Behavior
- [ ] Recruits appear in the player's group window with their NPC name.
- [ ] Tank recruits taunt and engage enemies in melee.
- [ ] Healer recruits heal group members who drop below HP thresholds.
- [ ] DPS recruits deal damage to the group's target.
- [ ] Utility recruits (Enchanter, Bard) use crowd control and buffs.
- [ ] Recruits respond to stance commands (passive, balanced, aggressive).
- [ ] Recruits follow the player when not in combat.
- [ ] Recruit AI is competent enough that a solo player with a full
      recruit group can clear content designed for a player group.

### Recruit Lifecycle
- [ ] Recruits persist across zone transitions.
- [ ] Recruits are suspended when the player logs off and restored when
      the player logs back in.
- [ ] Recruits can be dismissed via say command, returning to their
      original spawn point.
- [ ] When a recruit dies, they can be resurrected. If not resurrected
      within 30 minutes, they return to their spawn point.
- [ ] A replacement NPC spawns at the original NPC's location when they
      are recruited, and despawns when the recruit is dismissed.

### Dialogue and Cultural Identity
- [ ] Recruitment and dismissal dialogue is generated by the LLM system,
      shaped by the NPC's soul elements, culture, and personality.
- [ ] Dialogue respects cultural voice (Ogre simple speech, Teir'Dal
      cold calculation, Halas brogue, etc.).
- [ ] Recruits can be spoken to during adventuring, with responses
      reflecting their personality, culture, and shared memories.
- [ ] Party composition tensions are expressed through dialogue, not
      mechanical restrictions.

### Integration
- [ ] Recruits contribute to group XP split like a normal group member.
- [ ] The maximum recruit count respects the 6-member group limit.
- [ ] A recruit is automatically dismissed (with notification) if a new
      player joins a full group.

### Balance
- [ ] A recruit stat scaling rule exists and can be adjusted without
      code changes.
- [ ] Recruitment probability can be tuned via rule values.
- [ ] The level window can be adjusted via rule values.
- [ ] Culture-specific persuasion stats can be configured without code
      changes.

---

## Appendix: Technical Notes for Architect

_These are advisory observations from codebase research. The architect
makes all implementation decisions._

### Titanium Client Constraint

The Titanium client (`titanium_ops.h`) has NO mercenary opcodes. All merc
UI packets (OP_MercenaryDataUpdate, OP_MercenaryHire, OP_MercenaryTimer,
etc.) only exist in SoD+ patches. This means:

- The merc merchant window cannot be used for recruitment UI
- The merc management window cannot be used for recruit management
- All interaction must use chat commands and/or NPC dialogue (say-links)
- The group window (`MAX_GROUP_MEMBERS = 6` in `titanium_structs.h:764`)
  is the primary recruit status display

### Merc vs. Bot Class as Foundation

**Merc class advantages:**
- Simpler codebase (~4300 lines vs Bot's ~13000+)
- Built-in role AI (Tank/Healer/DPS stances)
- Existing zone persistence (`ProcessClientZoneChange`)
- Existing suspend/unsuspend (`merc_buffs` table)
- Existing group join/leave logic

**Merc class disadvantages:**
- Only 4 role archetypes (Tank, Healer, MeleeDPS, CasterDPS)
- Stats come from `merc_stats` table, not `npc_types`
- Spell lists from `merc_spell_list_entries` only cover 4 class types

**Bot class advantages:**
- All 16 classes with full spell AI
- Controlled via chat commands (works on Titanium)
- Persistent DB storage

**Bot class disadvantages:**
- Much more complex
- Designed for player-created characters, not world NPCs
- Requires significant adaptation for "recruit from world" flow

**Possible approach: New `Companion` class inheriting from `NPC`**, taking
Merc's AI patterns but deriving stats from the actual `npc_types` entry.
The architect should evaluate feasibility.

### Key C++ Files

| File | Relevance |
|------|-----------|
| `zone/merc.h` / `zone/merc.cpp` | Merc class: AI, spawning, group logic |
| `zone/bot.h` / `zone/bot_command.cpp` | Bot chat commands pattern |
| `zone/groups.h` / `zone/groups.cpp` | Group management |
| `zone/npc.h` / `zone/npc.cpp` | Base NPC class |
| `zone/entity.h` / `zone/entity.cpp` | Entity list management |
| `common/ruletypes.h` | Rule definitions |
| `common/faction.h` | Faction value constants |
| `common/emu_constants.h` | Stance constants |

### Database Tables to Investigate

| Table | Use |
|-------|-----|
| `npc_types` | Source of recruit stats, class, race, level |
| `npc_faction_entries` | NPC faction assignments |
| `merc_stats` | Pattern for stat storage |
| `merc_spell_list_entries` | Pattern for spell lists |
| `merc_buffs` | Pattern for buff persistence |
| `spawn2` / `spawnentry` | Spawn point data for replacement NPCs |

### Relevant Rule Suggestions

| Rule Name | Type | Default | Purpose |
|-----------|------|---------|---------|
| `Companions, Enabled` | bool | true | Master toggle |
| `Companions, MaxPerPlayer` | int | 5 | Hard cap |
| `Companions, LevelRange` | int | 2 | +/- levels for recruitment |
| `Companions, BaseRecruitChance` | int | 50 | Base recruitment probability |
| `Companions, StatScalePct` | int | 100 | Global stat multiplier |
| `Companions, SpellScalePct` | int | 100 | Heal/damage scaling |
| `Companions, RecruitCooldownS` | int | 900 | Failed recruit cooldown |
| `Companions, DeathDespawnS` | int | 1800 | Unresurrected dismiss timer |
| `Companions, MinFaction` | int | 3 | Minimum faction (3=Kindly) |
| `Companions, XPContribute` | bool | true | XP split contribution |
| `Companions, MercRetentionCheckS` | int | 600 | Mercenary faction check |

### Spawn Replacement Pattern

When an NPC is recruited, the system needs to:
1. Record the NPC's `spawngroupID` and `spawn2` entry
2. Despawn the NPC from the spawn group
3. Spawn a replacement using a modified copy of the NPCType (generic name,
   same race/class/level, cleared quest scripts)
4. On dismiss, despawn replacement and re-enable original spawn

### Culture-Persuasion Mapping

The culture-specific persuasion system needs a lookup from NPC to culture.
Options for the architect:
- **Faction-based:** Map faction IDs to culture entries
- **Zone-based:** Default culture per zone, with NPC-level overrides
- **Race-based:** Map NPC race ID to culture (simplest, covers most cases)
- **Deity-based:** Use NPC deity to determine cultural alignment

Race-based is likely sufficient for most cases since race strongly
correlates with culture in Classic-Luclin EQ. The architect should determine
the best approach.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
