# NPC LLM Phase 3: Soul & Story — Product Requirements Document

> **Feature branch:** `feature/npc-llm-phase3`
> **Author:** game-designer
> **Date:** 2026-02-25
> **Status:** Approved (lore-master reviewed 2026-02-25)

---

## Problem Statement

Phases 1 and 2 of the NPC LLM integration gave unscripted NPCs the ability
to converse naturally and remember past interactions. The result is impressive
for guards, merchants, and filler NPCs — but three gaps remain:

1. **Most NPCs feel generic.** An unscripted guard in Qeynos draws personality
   from the `race_class_faction` context layer, which covers "Human Warrior of
   the Qeynos Guard." But Captain Tillin and a nameless gate guard produce
   similar responses. Key NPCs — guildmasters, faction leaders, notable merchants —
   deserve individual backstories that make them memorable.

2. **Scripted quest NPCs go silent on off-keyword speech.** When a player
   targets a quest NPC and says something that doesn't match a keyword (e.g.,
   "What's going on around here?" instead of "hail"), the NPC says nothing.
   This silence breaks immersion because the player just had a natural
   conversation with the guard next door. The quest NPC feels broken by
   comparison.

3. **NPCs have no inner life.** Every NPC of the same race/class/faction speaks
   with roughly the same personality. There is no sense that this guard is brave
   while that merchant is cowardly, or that a particular NPC might dream of
   adventure. This flatness makes the world feel like a stage set rather than a
   living place — and it provides no foundation for Phase 4's companion
   recruitment, which requires NPCs to have individual disposition toward
   joining the player.

For a 1–6 player server where every NPC interaction matters more (fewer players
means more reliance on NPCs), these gaps directly undermine the world's sense
of life.

## Goals

1. **Key NPCs feel distinct.** A player speaking to Captain Tillin in South
   Qeynos gets a response shaped by Tillin's specific history, personality, and
   concerns — not just "generic Qeynos guard." At least 50 NPCs across all
   starting cities should have individual backstory overrides.

2. **Quest NPCs never go silent.** When a player speaks off-keyword to any
   scripted quest NPC that has been upgraded to Tier 2, the NPC responds
   naturally in character and gently steers the player toward valid quest
   keywords. The player should feel like they're talking to a person who
   happens to have quest-relevant information, not a keyword-matching machine.

3. **NPCs have soul.** Every NPC eligible for LLM conversation has personality
   traits, motivations, and a recruitment disposition score that subtly
   influence their dialogue. A brave guard speaks differently from a timid
   merchant. An NPC who dreams of adventure occasionally hints at wanderlust.
   This creates the narrative foundation for Phase 4 companion recruitment
   without implementing any actual recruitment mechanics yet.

4. **Data-driven and author-friendly.** Backstories, quest hints, and soul
   elements are defined in configuration files and quest scripts that a
   content author can edit without touching Python code or restarting the
   sidecar service.

5. **Racial and cultural identity is preserved.** The soul element system must
   never flatten NPCs into generic fantasy characters. An Iksar guildmaster
   must feel fundamentally different from a High Elf guildmaster, even if both
   teach the same class. Race, deity, and faction override generic role
   defaults when they conflict.

## Non-Goals

- **Actual companion recruitment.** Phase 3 lays the data foundation. NPCs may
  hint at their disposition, but no recruitment dialogue, persuasion mechanics,
  or party-join behavior is implemented. That is Phase 4.
- **Automatic backstory generation.** Backstories are hand-written by the
  lore-master and curated for accuracy. We do not use the LLM to generate
  backstories for itself.
- **Converting all quest scripts to Tier 2.** This phase establishes the
  pattern and converts a representative set of quest NPCs. Full conversion
  of all ~4,200 Lua quest scripts is future work.
- **Async HTTP binding (C++ changes).** The integration plan identified this
  as a Phase 3 option, but the current synchronous curl approach works
  acceptably for 1–6 players. Defer to a future phase if latency becomes
  a concern.
- **Perl quest script support for Tier 2.** The LLM bridge is Lua-only.
  Perl scripts that want Tier 2 fallback would need to be converted to Lua
  first. This is out of scope.
- **NPC-to-NPC conversation.** NPCs do not talk to each other.
- **Cross-NPC gossip.** NPC A does not reference conversations NPC B had.

## User Experience

### Player Flow: Backstory Seeding

1. A player enters South Qeynos and targets Captain Tillin.
2. The player says "Tell me about yourself."
3. Captain Tillin responds with dialogue drawn from his personal backstory:
   his long service, the guard rotations he manages, his concern about the
   increasing gnoll raids, and his awareness of corruption in the ranks. He
   closes with a deity-appropriate farewell: "May the Prime Healer walk with
   you." The response feels specific to Tillin, not generic.
4. The player then targets a nameless guard nearby and asks the same question.
5. The nameless guard responds with the standard Qeynos Guard faction context —
   competent and professional, but without the personal depth Tillin has.
6. The contrast makes Tillin feel like a real character. The nameless guard is
   still immersive (thanks to Phase 1/2), but Tillin stands out.

### Player Flow: Quest Hint System

1. A player enters Qeynos Hills and targets Holly Windstalker (a ranger NPC
   with a scripted Lua file involving wildlife threats).
2. The player says "hail" — Holly responds with her scripted greeting about
   the dangers in the hills and mentions "[wolves]" as a keyword.
3. The player says "What kind of wolves?" — this does NOT match Holly's
   keyword "wolves" exactly (she expects the player to say just "wolves").
4. Instead of silence, Holly responds naturally via LLM fallback: "The wolves
   of the Qeynos Hills have grown bolder of late. Their attacks on the road
   are a serious matter. Perhaps you should ask me more about the [wolves]
   specifically." The response is informed by quest_hints embedded in Holly's
   script, which tell the LLM that her quest involves wolves and pelts.
5. The player says "wolves" — the keyword matches, and Holly's scripted
   quest dialogue takes over normally.
6. At no point does the player experience silence or a dead end. The
   conversation flows naturally whether they use exact keywords or not.

### Player Flow: Soul Elements

1. A player speaks to Guard Noyan in North Qeynos. Noyan has soul elements
   that include high courage, moderate loyalty, and a recruitment disposition
   of "restless" — he privately wishes for more excitement than guard duty.
2. When the player asks about his day, Noyan's response reflects his
   personality: "Another quiet patrol. The gnolls keep their distance today.
   Sometimes I wonder what lies beyond the Karanas — but that is not a
   guardsman's thought to dwell on. May the Prime Healer walk with you."
3. The subtle hint of wanderlust comes from his soul elements, not from
   an explicit script. Note that even with wanderlust, Noyan still speaks
   in Qeynos guard idiom (formal, civic, deity reference to Rodcet Nife).
   His soul does not override his cultural voice.
4. By contrast, Guard Dunson nearby has soul elements with high devotion and
   rooted disposition. When asked the same question, Dunson says: "The walls
   stand, the gate is manned, and Antonius Bayle's peace holds. That is all
   a guardsman needs." No hint of wanderlust — Dunson is content where he is.

### Player Flow: Cross-City Contrast

A player who has visited multiple starting cities should feel the cultural
difference between them through NPC souls:

1. **Qeynos guard** (formal, civic): "May the Prime Healer walk with you,
   citizen. The roads are clear this evening."
2. **Halas guard** (brogue, blunt): "Hail! Ye've nothing to fear here, so
   long as ye've no quarrel with Halas. The Wolves o' the North keep watch."
3. **Freeport Militia** (pragmatic, morally ambiguous): "Keep your hands
   where I can see them. Sir Lucan's law runs these streets, and I enforce
   it. Move along."
4. **Cabilis Legionnaire** (cold, xenophobic): "You are not of the Legion.
   State your purpose in Cabilis or leave. We have no patience for
   warm-blood curiosity."

These differences come from the interaction of racial context (Layer 2),
faction context (Layer 5), and soul elements (Layer 6) — not from any
single layer alone.

### Example Scenario: All Three Features Combined

A level 15 ranger enters Kelethin and approaches Maesyn Trueshot (Ranger
guild). The player says "I want to learn about tracking."
Maesyn's scripted dialogue expects the keyword "train" but not "tracking."

1. **Quest hint system** activates. The LLM receives quest_hints about
   Maesyn's training services and the keyword "train."
2. **Backstory seeding** provides Maesyn's personal history: a Wood Elf
   who has patrolled the Greater Faydark for decades, intimately familiar
   with every Crushbone orc trail and animal path beneath the canopy.
3. **Soul elements** indicate Maesyn is vigilant (Courage +2), nature-devoted
   (Piety +1), and has curious recruitment disposition (she takes her
   teaching role seriously but sometimes misses ranging the deep forest).

Maesyn responds: "Tracking is a craft the Faydark teaches — every broken
branch and bent blade of grass tells a tale. If you wish to sharpen your
skills, tell me you are ready to [train] and we shall begin."

The player learns the keyword naturally. Maesyn felt like a real Wood Elf
ranger with a real connection to her forest, not a training menu.

## Game Design Details

### Deliverable 1: NPC Backstory Seeding

#### What It Is

Individual backstory paragraphs for key NPCs, stored in the
`npc_overrides` section of `global_contexts.json`. These override the
generic race/class/faction context and give the NPC a unique voice.

#### Which NPCs Get Backstories

Priority tiers:

**Tier A — Must Have (30-40 NPCs):**
- Guildmasters in all 15 starting cities (one per class per city where that
  class guild exists). These are the NPCs players interact with most
  frequently for training.
- City leaders / rulers (Antonius Bayle IV, King Naythox Thex, King Ak'Anon,
  Raja Kerrath of Shar Vahl, etc.)
- Major faction leaders (Lucan D'Lere, High Priestess Alexandria in Neriak,
  the Harbinger in Cabilis, etc.)

Starting cities (15 total, Classic through Luclin):
Qeynos, Freeport, Halas, Erudin, Paineel, Kaladim, Ak'Anon, Felwithe,
Kelethin, Neriak, Oggok, Grobb, Rivervale, Cabilis, Shar Vahl.

**Tier B — Should Have (30-40 NPCs):**
- Named city guards with dialogue relevance (Captain Tillin already done,
  expand to other named captains/lieutenants)
- Key quest NPCs in starting cities
- Bank/guild hall NPCs who players see frequently
- Notable innkeepers and merchants with story hooks

**Tier C — Nice to Have (20-30 NPCs):**
- Wilderness quest NPCs in newbie zones
- NPCs referenced in other NPCs' backstories (creates a web of relationships)
- Class trainers in secondary cities (Thurgadin, Shadow Haven, etc.)

Total target: 80-110 new backstory overrides, reviewed by the lore-master
for era compliance and faction accuracy.

#### Backstory Content Guidelines

Each backstory paragraph should be 2-4 sentences and include:
- The NPC's role and how they came to it (history)
- One personal detail that distinguishes them (a lost comrade, a pet peeve,
  a secret hobby, a notable achievement)
- A connection to their zone's current threats or events
- Their stance toward their faction's enemies (informs faction-based dialogue)
- Their deity, if applicable, referenced by name (not generic "the gods")

**City-Specific Guard Identity:**

Guard backstories must reflect the distinct character of their city's guard
force. Guards are NOT interchangeable watchmen:

| City | Guard Force | Character | Key Conflicts |
|------|------------|-----------|---------------|
| Qeynos | Guards of Qeynos | Formal, civic, loyal to Antonius Bayle IV. Deity: Rodcet Nife. Must be aware of Corrupt Qeynos Guards and Bloodsaber infiltration. | Kane Bayle faction, Circle of Unseen Hands, gnolls |
| Freeport | Freeport Militia | Pragmatic, morally ambiguous, loyal to Lucan D'Lere. NOT virtuous peacekeepers — they serve a corrupt authority. | Knights of Truth (active street conflict), Steel Warriors |
| Halas | Wolves of the North | Brogue accent ("ye", "o'", "dinnae"). Honor-bound, Tribunal worship. Contemptuous of weakness and "southern" sophistication. | Snow orcs, ice goblins |
| Neriak | Dreadguard (Outer/Inner) | Cold, hierarchical, contemptuous of non-Teir'Dal. Three tiers of authority across city districts. | All non-Dark Elf races, internal faction competition |
| Cabilis | Legion of Cabilis | Xenophobic, rigid, steeped in fallen Sebilisian Empire's glory. Deeply suspicious of all non-Iksar. | All warm-bloods, Ring of Scale |
| Shar Vahl | Guardians of Shar Vahl | Proud, communal, loyal to Raja Kerrath. The Grimling War is current, not historical. | Grimlings (constant existential threat) |
| Erudin | High Guard of Erudin | Intellectual, slightly self-important. Guard duty beneath their potential but taken seriously. | Heretics of Paineel |
| Kelethin | Scouts/Rangers | Nature-connected, alert, communal. The forest is home and the orcs are the eternal threat. | Crushbone orcs |
| Oggok | Oggok Guard | Direct, strength-focused. Very simple speech. Rallos Zek worship. | Lizardmen of the Feerrott |
| Grobb | Grobb Guard | Blunt, Cazic-Thule worship through action. The swamp is home and danger. | Frogloks of Guk |
| Rivervale | Rivervale Guard | Cheerful but competent. Bristlebane humor even on duty. Underestimated by outsiders. | Runnyeye goblins, Misty Thicket dangers |
| Kaladim | Kaladim Guard | Gruff, guild-loyal, honor-bound. Mining and craft terminology. Brell Serilis worship. | Estate of Unrest |
| Ak'Anon | Ak'Anon Guard | Excitable, tangent-prone, tinkering references. Brell Serilis / Bristlebane. | Mountain Death goblins |
| Felwithe | Felwithe Guard | Formal, elegant, quietly superior. Tunare worship with patrician guardianship. | Dark Elves, Crushbone orcs |
| Paineel | Paineel Guard | Cold, scholarly, defiant. Heretic pride. The Hole is a source of power and dread. | Erudin, the Hole's inhabitants |

**Guildmaster Identity:**

Guildmaster backstories must combine class philosophy with racial culture.
The same class taught in different cities should feel fundamentally different:
- A Human Warrior guildmaster in Qeynos emphasizes discipline and service to Bayle
- A Barbarian Shaman guildmaster in Halas emphasizes the Tribunal's justice
  and the cold proving one's worth
- A Dark Elf Necromancer guildmaster in Neriak takes pleasure in power over
  death and distrust of non-Teir'Dal
- An Erudite Wizard guildmaster in Erudin is intellectually condescending and
  dismissive of "lesser" races
- A Halfling Rogue guildmaster in Rivervale is cheerful, teasing, and
  mischievous — Bristlebane's trickster influence

**Merchant Identity:**

Merchants reflect their city's commercial character:
- Qeynos merchants: civic-minded traders allied with Antonius Bayle
- Freeport merchants: pragmatic, watchful, operating in a lawless environment
- Neriak merchants (Dark Bargainers): every transaction is a power calculation

**Dialogue Tone Reference:**

Backstories should enable NPC dialogue that sounds like authentic EverQuest.
Real quest script examples for calibration:

- *Qeynos formal*: "Greetings to you, citizen. By order of the Council of
  Qeynos I have been given the duty of apprehending the individuals
  responsible for unleashing this terrible plague upon the people."
- *Qeynos guard farewell*: "May the Prime Healer walk with you!"
- *Halas brogue*: "Hail! Ye've come to serve Halas, have ye not?"
- *Halas shaman*: "Justice is our way. Within Halas, there are none who are
  above the scales o' justice."
- *Style rules*: No modern slang. No meta-game language ("buff", "DPS",
  "tank"). Keep responses to 2-3 sentences. Use specific lore references
  (named rulers, factions, deities), not generic ones.

#### Duplicate NPC Type IDs

Some NPCs exist as both regular spawns and "global" spawns (different
npc_type_ids for the same named NPC). Both IDs need override entries pointing
to the same backstory text. This pattern is already established — see
Plagus Ladeson (IDs 9112 and 382059) in the current config.

### Deliverable 2: Quest Hint System (Tier 2 Adoption)

#### What It Is

Scripted quest NPCs with existing keyword-based dialogue add a fallback
block: when the player says something that matches no keyword, the NPC's
quest script calls the LLM bridge with supplemental `quest_hints` context.
The LLM produces a natural in-character response that nudges the player
toward valid quest keywords.

#### How It Works (Player-Facing)

1. Player targets a quest NPC and speaks.
2. If the speech matches a keyword, the scripted response fires normally.
   The LLM is never involved. This is identical to current behavior.
3. If no keyword matches, the script calls the LLM bridge with:
   - Standard NPC context (identity, zone, faction — same as Tier 1)
   - `quest_hints`: a short list of hints about what this NPC's quest involves
     and which keywords the player should try
   - `quest_state` (optional): current quest progress for this player, so the
     LLM can give stage-appropriate hints
4. The LLM responds in character, weaving the hint information into natural
   dialogue. The response should mention at least one valid keyword in
   [brackets] to create a clickable say-link.
5. The player clicks the keyword or types it, and the scripted dialogue path
   resumes.

#### Quest Hint Content

Quest hints are short directive sentences written for the LLM, not shown to
the player. They tell the NPC "what you know about your quest" so the LLM
can guide conversation naturally. Examples:

```
quest_hints = {
    "You are concerned about gnoll raids from Blackburrow to the north.",
    "You offer a quest: bring you 4 gnoll fangs as proof of kills.",
    "Valid keywords the player can ask about: gnolls, Blackburrow, gnoll fangs.",
}
```

For multi-step quests with state tracking:

```
quest_hints = {
    "You asked this player to collect 4 gnoll fangs. They have not returned yet.",
    "If they ask about the quest, remind them about the gnoll fangs.",
    "Valid keywords: gnoll fangs, Blackburrow.",
}
```

#### Which Quest Scripts Get Upgraded

Phase 3 targets a representative set to establish the pattern:

- **5-10 quest NPCs in Qeynos/Freeport starting areas** — most familiar to
  new players, highest impact for first impressions
- **2-3 quest NPCs in each other starting city** — ensures the pattern works
  across all race/class combinations
- **1-2 quest NPCs in a Kunark or Luclin zone** — verifies era-specific
  content works

Total: 20-30 quest scripts upgraded to Tier 2.

All upgraded scripts must be Lua (not Perl). If a target quest NPC only has
a Perl script, it should be converted to Lua as part of this work.

#### Sidecar Handling

The sidecar's `/v1/chat` endpoint already accepts arbitrary context fields.
When `quest_hints` is present in the request, the prompt assembler should
inject them into the system prompt as a special instruction block:

> "This person is involved in something specific. Here is what you know
> about it: [quest_hints joined as sentences]. When responding to off-topic
> questions, try to naturally guide the conversation back to these topics.
> Include at least one [bracketed keyword] in your response."

This instruction sits between the faction instruction (Layer 5) and the
soul elements (Layer 6) in the prompt assembler.

### Deliverable 3: Soul Element Framework

#### What It Is

A structured data model that gives each NPC a unique inner life. Soul
elements are injected into Layer 6 of the prompt assembler, subtly shaping
how the NPC speaks and what they reveal about themselves.

**Critical design principle:** The soul element system must never flatten
racial or cultural identity. The worst outcome would be all NPCs sounding
like generic fantasy medieval characters with a thin racial accent
sprinkled on. Soul elements add individual variation WITHIN a cultural
voice — they do not replace it.

#### The Soul Data Model

Each NPC's soul consists of three components:

**1. Personality Axes (3-6 trait pairs, scored -3 to +3)**

| Axis | -3 (Low) | 0 (Neutral) | +3 (High) |
|------|----------|-------------|-----------|
| Courage | Cowardly, avoids risk | Cautious | Brave, confronts danger |
| Generosity | Greedy, self-interested | Fair | Generous, self-sacrificing |
| Honesty | Deceptive, manipulative | Diplomatic | Blunt, forthright |
| Piety | Secular, pragmatic | Observant | Devout, zealous |
| Curiosity | Incurious, set in ways | Open-minded | Scholarly, restless |
| Loyalty | Ambitious, self-serving | Dutiful | Devoted, self-sacrificing |

Each NPC has 3-6 of these axes set (not all 6 are required). Unset axes
default to 0 (neutral) and produce no special prompt instruction.

Extreme values (-3 or +3) produce strong personality coloring. Moderate
values (-1 or +1) produce subtle influence. Zero produces nothing.

**2. Motivations (1-2 entries)**

Each NPC has 1-2 motivations drawn from a defined vocabulary:

| Category | Examples |
|----------|----------|
| Desires | glory, knowledge, wealth, peace, revenge, recognition, freedom, family, order, power |
| Fears | death, dishonor, abandonment, darkness, outsiders, change, failure, corruption, irrelevance |

Motivations are injected as brief character notes:
> "Deep down, you desire recognition for your service. You fear being
> forgotten when you retire from the guard."

**3. Recruitment Disposition (Phase 4 preview)**

A single composite descriptor that captures how open this NPC is to
leaving their current role and joining an adventurer:

| Disposition | Description | Dialogue Influence |
|-------------|-------------|-------------------|
| Rooted | Deeply committed to their post. Would never leave. | "My duty is here." |
| Content | Satisfied with their life. No desire to change. | No hints either way. |
| Curious | Sometimes wonders about life beyond their role. | Occasional wistful comment. |
| Restless | Actively desires something more. Could be convinced. | Regular hints of wanderlust. |
| Eager | Would jump at the right opportunity. | Open interest in adventure. |

Disposition does NOT trigger recruitment dialogue in Phase 3. It only
influences the emotional texture of the NPC's responses. A "restless"
guard might sigh about monotony. An "eager" merchant might ask about the
player's adventures with obvious envy. A "rooted" cleric never wavers.

#### Deity Alignment Rules

Every NPC with a deity should have that deity's values reflected in their
soul traits. The soul system must enforce these constraints:

| Deity | Required Soul Alignment | Typical NPCs |
|-------|------------------------|--------------|
| Rodcet Nife (Prime Healer) | Generosity +1 or higher; Piety +1 or higher. NPCs bless with "May the Prime Healer walk with you." | Qeynos clerics, guards |
| Tribunal (Six Hammers) | Honesty +2 or higher; Loyalty +1 or higher. Justice-obsessed, consequences-focused. | Halas shamans, warriors |
| Innoruuk (Prince of Hatred) | Generosity -2 or lower; Honesty -1 or lower. Hatred is a gift, not a flaw. Cruelty is strength. | Neriak Dark Elves |
| Cazic-Thule (The Faceless) | Courage -1 or lower (fear-based power); Loyalty +2 (hierarchy). Fear as motivator. | Iksar, Trolls |
| Tunare (Mother of All) | Generosity +1; Piety +1. Nature stewardship — patrician for High Elves, communal for Wood Elves. | Elven clerics, druids |
| Brell Serilis (Duke of Below) | Loyalty +2; Honesty +1. Craft, stone, underground kinship. | Dwarves, Gnomes |
| Bristlebane (King of Thieves) | Honesty -1 to +1 (flexible); Curiosity +1. Mischief as worship. Humor in everything. | Halflings, some Gnomes |
| Mithaniel Marr (Lightbearer) | Courage +2; Honesty +2; Loyalty +2. Honor above survival. | Knights of Truth, Paladins |
| Rallos Zek (Warlord) | Courage +3; Generosity -1. War is glory. Peace is suspect. | Ogre warriors, Barbarian warriors |
| Bertoxxulous (Plaguebringer) | Generosity -3; Piety +2 (but to decay). Everything decays — you help it along. | Bloodsabers |

These are minimum constraints, not exact values. An individual NPC can
exceed the minimum (a particularly devout Paladin might have Piety +3)
but should never violate it (a Paladin of Mithaniel Marr cannot have
Honesty -2).

#### Faction Political Constraints

Soul elements must be consistent with active faction conflicts:

1. **Qeynos Guards** — Must carry awareness of Corrupt Qeynos Guards and
   Bloodsaber cult. A guard's soul might include Loyalty +2 (to Bayle) but
   also Fears: "corruption in the ranks."
2. **Freeport Militia** — Loyalty to Lucan, not to justice. A Militia guard
   with Honesty +3 contradicts their factional identity. Militia guards
   should be Loyalty +1 (to Lucan), Honesty -1 to +1 (pragmatic).
3. **Knights of Truth** — Loyalty +2 (to Marr), Courage +2. They are in
   ACTIVE conflict with the Militia. A Knight of Truth cannot be content
   with the status quo.
4. **Neriak Dreadguard** — Outer guards are professional enforcers. Inner
   guards are elite zealots. Outer: Loyalty +1, Courage +1. Inner:
   Loyalty +2, Piety +2, Generosity -2.
5. **Erudin vs. Paineel** — An Erudin NPC considers Paineel Erudites
   disgraces. A Paineel NPC considers Erudin soft and cowardly. They
   do NOT cooperate or speak neutrally about each other.
6. **Iksar isolation** — All Cabilis NPCs should have Fear: "outsiders" or
   equivalent xenophobia. No Iksar NPC should have Generosity +2 toward
   non-Iksar.

#### How Soul Elements Influence Dialogue

The prompt assembler injects soul elements into Layer 6 as a character
direction block. Example for a Qeynos guard with Courage +2, Generosity -1,
Curiosity +1, who desires glory, fears being forgotten, and is "restless":

> "Your personality: You are notably brave — you confront threats directly
> and speak confidently about danger. You are somewhat self-interested — you
> look out for yourself first, though not at others' expense. You have a
> keen curiosity about the wider world.
> Deep down, you desire glory and recognition. You fear being forgotten.
> You sometimes feel restless in your current role — the routine weighs on
> you, though you would not admit it unprompted."

This is a system-prompt-level instruction, not player-visible text. The LLM
uses it to color dialogue naturally. The player never sees the raw soul data.

**Important:** Soul elements add flavor within the NPC's established cultural
voice. They do not override racial context (Layer 2), faction context (Layer 5),
or the rules block (Layer 8). A restless Qeynos guard still speaks formally,
still references Rodcet Nife, still worries about gnolls. The restlessness
adds a subtle additional dimension, not a personality transplant.

#### Default Soul Elements

Not every NPC needs hand-assigned soul elements. The system should support
defaults:

- **Unassigned NPCs** get no soul elements (Layer 6 remains empty, as it is
  today). This is the majority of NPCs.
- **Role-based defaults** can be defined per NPC role: guards default to
  Courage +1, merchants to Generosity -1 / Curiosity +1, etc. These provide
  mild personality without per-NPC authoring.
- **Per-NPC overrides** provide full custom soul elements for key NPCs.
  These take priority over role defaults.

The fallback chain mirrors the existing context system:
per-NPC override > role-based default > no soul elements.

**Role-based defaults must be general enough to work across all races.**
A default of Courage +1 for guards is safe because it means "slightly brave"
regardless of whether the guard is a Qeynos Human or a Cabilis Iksar. The
racial and faction context layers handle cultural differentiation. Role
defaults add only mild universal role-appropriate traits.

#### Soul Element Authoring

Soul elements for key NPCs (Tier A/B from the backstory list) are authored
alongside their backstories by the lore-master. Each backstory entry gains
companion soul data. The lore-master ensures that soul traits are consistent
with the NPC's faction, deity, race, and backstory.

Consistency checks (enforced during lore review):
- Deity alignment rules (see table above) are satisfied
- Faction political constraints (see above) are not violated
- Racial cultural identity is not contradicted (no cheerful Iksar, no
  grim Halfling merchants, no intellectually humble Erudite wizards)
- Recruitment disposition matches role stability (guildmasters: rooted;
  city leaders: rooted; random guards: any disposition; merchants: content
  to curious; quest NPCs with active quests: rooted during quest)

### Balance Considerations

#### 1-6 Player Impact

- **Backstory seeding**: Pure flavor, no mechanical impact. Enhances immersion
  for solo players who spend more time talking to NPCs.
- **Quest hints**: Significant quality-of-life improvement for small groups.
  With fewer players to share knowledge ("just say 'wolves' to her"), players
  rely more on NPC guidance. The hint system prevents frustrating dead ends.
- **Soul elements**: No mechanical impact in Phase 3. The recruitment
  disposition data will matter in Phase 4, where soul elements determine
  which NPCs can be recruited and how difficult the persuasion is. A 1-player
  server especially benefits from soul-enriched NPCs since the player's
  primary social interaction is with NPCs rather than other players.

#### Token Budget Impact

Soul elements add to the system prompt length. The prompt assembler already
has a `LLM_BUDGET_SOUL` env var (currently 0). Phase 3 should set this to
a reasonable limit — 100-150 tokens is sufficient for personality axes +
motivation + disposition. Quest hints add similarly (100-150 tokens).

Combined with existing budgets (global: 200, local: 150, memory: 200),
the total prompt grows by ~300 tokens. This is within Mistral 7B's context
window and should not meaningfully affect latency.

### Era Compliance

All content in this feature is author-curated and reviewed by the lore-master.

**What is IN era and can be referenced:**
- Classic: All 15 starting cities listed above
- Kunark: Cabilis, Firiona Vie, Overthere, Field of Bone, Howling Stones,
  Sebilis, Chardok, Veeshan's Peak, City of Mist
- Velious: Thurgadin (Coldain Dwarves), Kael Drakkel (Frost Giants),
  Skyshrine (Dragons), Eastern/Western Wastes, Great Divide
- Luclin: Shar Vahl, Shadow Haven, Nexus (spire teleport only), Paludal
  Caverns, Vah Shir society, Shissar ruins (ancient history)

**What must NEVER appear in backstories, quest hints, or soul data:**
- Post-Luclin expansions (Planes of Power, Gates of Discord, etc.)
- Plane of Knowledge as a travel hub (does not exist in this era)
- Froglok capture of Grobb / city of Gukta (Gates of Discord era; in our
  era, Grobb is Troll territory)
- Crescent Reach / Drakkin (Prophecy of Ro era)
- Wayfarer's Brotherhood (Lost Dungeons of Norrath era)
- Berserker class (Planes of Power era)
- The Nexus as a social hub (it is only a spire teleport system in Luclin)

The existing era-lock rules in Layer 8 of the prompt assembler (no Planes of
Power, no Berserker class, etc.) continue to apply and constrain LLM output
regardless of what soul elements or quest hints are injected.

## Affected Systems

- [ ] C++ server source (`eqemu/`)
- [x] Lua quest scripts (`akk-stack/server/quests/`)
- [ ] Perl quest scripts (maintenance only)
- [ ] Database tables (`peq`)
- [ ] Rule values
- [x] Server configuration
- [x] Infrastructure / Docker

Specifically:
- **Lua quest scripts**: 20-30 quest scripts get Tier 2 LLM fallback blocks
  added. The `llm_bridge.lua` module needs a new function to accept and
  forward `quest_hints` context.
- **Server configuration**: `global_contexts.json` expands with 80-110 new
  `npc_overrides`. A new configuration file (or new section in existing
  config) stores soul element definitions and role-based defaults.
- **Infrastructure / Docker**: The sidecar's `prompt_assembler.py` Layer 6
  needs to be populated instead of the current placeholder. The sidecar's
  `/v1/chat` request model gains optional `quest_hints` and `quest_state`
  fields. The `LLM_BUDGET_SOUL` env var changes from 0 to 100-150.

## Dependencies

- **NPC LLM Phase 1 (Foundation)** — Must be complete. The sidecar, Lua
  bridge, global_npc.lua hook, and basic prompt pipeline must all be working.
  **Status: Complete.**

- **NPC LLM Phase 2 (Memory)** — Must be complete. Pinecone integration
  and the layered prompt assembler must be in place (Layer 6 placeholder
  is the target for soul elements). **Status: Complete.**

- **Lore-master availability** — Backstories and soul elements require
  lore review. The lore-master must be available to author/review 80-110
  backstory paragraphs and their companion soul data.

## Open Questions

1. **Soul element storage format.** Should soul data live in
   `global_contexts.json` alongside backstories, in a separate
   `soul_elements.json` config file, or in a new section of the sidecar's
   config? The architect should determine the best approach for
   maintainability and hot-reload support.

2. **Quest hint injection point.** The integration plan placed quest hints
   between Layer 5 (faction) and Layer 6 (soul). Should quest hints be a
   sub-layer of Layer 6, or a separate layer (Layer 5.5)? The architect
   should decide based on token budget management.

3. **Say-link generation for quest hints.** When the LLM response includes
   a keyword in [brackets], does the existing `AutoInjectSaylinksToSay`
   rule handle this automatically, or does the Lua bridge need to post-process
   the response to inject say-links? This needs investigation.

4. **Hot-reload of soul data.** Can the sidecar reload configuration files
   without restarting the container? If not, the architect should add a
   reload endpoint or file-watch mechanism so content authors can iterate
   without downtime.

5. **Quest state passing.** For multi-step quests, should the quest script
   pass the full quest state to the sidecar (requiring the script to
   construct different quest_hints per state), or should the sidecar query
   quest state from an external source? Script-side construction is simpler
   but more verbose.

6. **NPC deity lookup.** The current Lua bridge does not pass deity ID to
   the sidecar. The soul element system needs deity information to enforce
   deity alignment rules. Should deity be added to the Lua context builder,
   or should the sidecar look it up from the NPC type ID?

## Acceptance Criteria

### Backstory Seeding
- [ ] At least 50 new NPC backstory overrides added to `global_contexts.json`
      covering guildmasters and key NPCs across all 15 starting cities.
- [ ] Each backstory reviewed and approved by the lore-master for era
      compliance, faction accuracy, and deity-appropriate language.
- [ ] A player speaking to a backstoried NPC receives dialogue that reflects
      the NPC's individual history, distinguishable from a generic NPC of
      the same race/class/faction.
- [ ] Backstories for NPCs with duplicate type IDs (regular + global spawn)
      are present for both IDs.
- [ ] Guard backstories reflect city-specific guard force identity (Freeport
      Militia is NOT virtuous, Halas guards use brogue, etc.).

### Quest Hint System
- [ ] At least 20 quest scripts upgraded to Tier 2 with LLM fallback and
      quest_hints context.
- [ ] When a player speaks off-keyword to an upgraded quest NPC, the NPC
      responds naturally in character and includes at least one valid quest
      keyword in [brackets].
- [ ] When a player speaks a valid keyword, the scripted quest dialogue fires
      normally — the LLM fallback does not interfere.
- [ ] Quest hints are defined in the quest script itself, co-located with
      the quest logic they describe.
- [ ] The sidecar handles the `quest_hints` field in chat requests and
      injects hint context into the system prompt.

### Soul Element Framework
- [ ] Layer 6 of the prompt assembler is populated with soul element text
      when soul data is available for the requested NPC.
- [ ] Soul elements influence dialogue tone observably: a brave NPC speaks
      more boldly about threats than a cowardly one; a restless NPC
      occasionally hints at wanderlust.
- [ ] Role-based default soul elements are applied to guards, merchants,
      and guildmasters when no per-NPC override exists.
- [ ] Per-NPC soul elements override role-based defaults.
- [ ] Soul data for key NPCs (Tier A/B) is reviewed by the lore-master
      for thematic consistency with deity and faction constraints.
- [ ] Deity alignment rules are satisfied for all NPCs with assigned deities.
- [ ] Faction political constraints are not violated in any soul assignment.
- [ ] Recruitment disposition influences dialogue subtly but does NOT
      trigger any recruitment mechanics or explicit recruitment dialogue.
- [ ] The `LLM_BUDGET_SOUL` token budget is set and soul element text is
      truncated appropriately when exceeding budget.
- [ ] Soul elements do NOT flatten racial/cultural identity: an Iksar
      guildmaster sounds fundamentally different from a High Elf guildmaster
      even when both have similar soul trait scores.

### Integration
- [ ] All three features work together: a backstoried quest NPC with soul
      elements responds to off-keyword speech using quest hints, with
      personality influenced by soul elements.
- [ ] No regression in Tier 1 (unscripted NPC) conversation quality.
- [ ] No regression in existing quest script keyword matching behavior.
- [ ] Token budget stays within Mistral 7B context window for prompts that
      include all layers (identity + global + local + role + faction +
      quest hints + soul + memory + rules).

---

## Appendix: Technical Notes for Architect

_These are advisory observations from reading the codebase. The architect
makes all implementation decisions._

### Prompt Assembler Layer 6

The current placeholder at `prompt_assembler.py:157-158`:
```python
# --- Layer 6: Soul elements (Phase 3 placeholder — 0 budget) ---
# No content here yet. Reserved space in token budget.
```

The `LLM_BUDGET_SOUL` env var exists and defaults to 0. The assembler already
has the budget infrastructure; Layer 6 just needs content.

### Quest Hints and the Sidecar Request Model

The sidecar's `/v1/chat` request model (in `models.py` or equivalent) will
need optional fields:
- `quest_hints: list[str] | None` — hint sentences for quest guidance
- `quest_state: str | None` — optional quest progress descriptor

The prompt assembler should inject these as a directive block, perhaps
between Layer 5 (faction) and Layer 6 (soul).

### llm_bridge.lua Extension

The `build_context()` function in `llm_bridge.lua` currently builds a fixed
set of context fields. For Tier 2, quest scripts need to pass additional
fields. Options:
- Add a `build_context_with_hints(e, quest_hints, quest_state)` function
- Make `build_context()` accept an optional overrides table that gets merged
- The quest script builds context, adds quest_hints, then calls
  `generate_response()` — this is the pattern shown in the integration plan
  Section 7

### Global Contexts JSON Structure

For soul elements, consider adding a `soul_elements` section to
`global_contexts.json` or a separate `soul_elements.json`:

```json
{
  "role_defaults": {
    "guard": { "courage": 1, "loyalty": 1, "desires": ["duty"], "disposition": "content" },
    "merchant": { "generosity": -1, "curiosity": 1, "desires": ["wealth"], "disposition": "content" },
    "guildmaster": { "piety": 1, "loyalty": 2, "desires": ["knowledge"], "disposition": "rooted" }
  },
  "npc_overrides": {
    "1077": {
      "courage": 2, "generosity": -1, "honesty": 1, "curiosity": 1,
      "desires": ["recognition"], "fears": ["being_forgotten"],
      "disposition": "restless"
    }
  }
}
```

### NPC Role Detection

To apply role-based soul defaults, the system needs to identify NPC roles
(guard, merchant, guildmaster). Options:
- `npc_is_merchant` flag already passed in context (class 41 check)
- Guard detection: check NPC name pattern ("Guard", "Captain", etc.) or
  faction membership
- Guildmaster detection: check if NPC offers training services (could query
  from NPC data)
- The architect should determine the most reliable detection method.

### Say-Link Auto-Injection

The server rule `Chat, AutoInjectSaylinksToSay` controls whether [bracketed
text] in NPC Say() calls gets converted to clickable say-links. If this rule
is enabled, quest hint responses that include [keywords] will automatically
become clickable — no extra Lua processing needed. The architect should
verify this rule's current state and whether it works with LLM-generated text.

### NPC Deity Lookup

The current Lua bridge (`llm_bridge.lua:84-108`) does not pass NPC deity
to the sidecar. For soul element deity alignment, the sidecar needs to know
the NPC's deity. Options:
- Add `e.self:GetDeity()` to the Lua context builder (if the method exists)
- Look up deity from `npc_types` table via npc_type_id in the sidecar
- Store deity in the soul element data alongside personality traits

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
