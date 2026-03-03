# NPC Companion Context — Product Requirements Document

> **Feature branch:** `feature/npc-companion-context`
> **Author:** game-designer
> **Date:** 2026-03-02
> **Status:** Draft
> **Lore review:** Approved by lore-master (2026-03-02)

---

## Problem Statement

On our 1-3 player Custom EverQuest server (Classic through Luclin), the
signature feature is a recruit-any-NPC companion system. Players can
persuade guards, adventurers, citizens, and other NPCs to join their
group as traveling companions. These companions fight alongside the player,
follow commands, wear equipment, and converse through an LLM-powered
dialogue system backed by persistent per-NPC memory (a "soul").

**The problem:** Once recruited, companions continue to talk as if they
are still performing their original role. A guard companion still speaks
like a guard on patrol. A merchant companion still speaks like a merchant
behind a counter. They have no awareness that they have left their post
and joined the player's group. This breaks immersion and makes companions
feel like NPCs on a leash rather than real traveling partners.

**Why it matters:** For a 1-3 player server, companions are not optional
flavor — they are the core party-filling mechanism. Players will spend
the vast majority of their gameplay hours in conversation range of their
companions. If companions feel hollow or stuck in their old identity, the
signature feature of the server falls flat. The difference between "a guard
following you" and "a former guard adventuring with you" is the difference
between an NPC and a character.

The existing infrastructure is already in place to solve this. The LLM
sidecar receives a context payload from `llm_bridge.build_context()` that
describes the NPC (race, class, level, zone, faction). The sidecar uses
this context plus a soul/memory system to generate dialogue. The problem
is that `build_context()` sends the same payload whether the NPC is a
guard standing at their post or a companion fighting gnolls in Blackburrow.
There is no companion-aware context layer — no signal to the LLM that
this NPC's situation has fundamentally changed.

---

## Goals

1. **Identity shift at recruitment.** When an NPC becomes a companion,
   the LLM context should shift so their origin (guard, merchant, citizen)
   becomes backstory rather than current identity. They are a group member
   first, a former guard second.

2. **Situational awareness.** Companions should reference the current zone,
   what the group is doing, what they have been fighting, and the time of
   day. Camping gnolls in a forest should produce different conversation
   than resting in a city.

3. **Personality variety.** Different companions should feel meaningfully
   different based on their race, class, culture, and hometown. An Erudite
   wizard from Erudin and a Troll warrior from Grobb should have wildly
   different perspectives on the same situation.

4. **Emergent character continuity.** The LLM invents character details
   through conversation (a daughter, a grudge, a fear). These inventions
   persist via the existing memory system. The companion context should
   amplify this by providing a richer ongoing relationship that gives the
   LLM more room to develop the character over time.

5. **Natural conversation cadence.** Player initiates most conversations.
   Unprompted companion commentary is rare, surprising, and contextual.
   Should feel like traveling with a real person who is mostly focused on
   the journey but occasionally says something interesting.

---

## Non-Goals

- **Companion preference/opinion systems.** No tracking whether a companion
  likes or dislikes certain zones, enemies, or activities. Not yet.

- **Mechanical mood effects.** No combat bonuses or penalties based on
  companion emotional state.

- **Complex relationship tracking.** No loyalty meters, trust scores, or
  relationship milestones. The LLM memory handles relationship organically.

- **Companion-to-companion interaction.** Companions do not talk to each
  other. Potential future feature, but out of scope.

- **Milestone conversation triggers.** No scripted conversations on level-up,
  first kill in a zone, or quest completion. Potential future feature.

- **New UI elements.** No companion mood bar, relationship indicator, or
  chat window modifications. Uses existing EQ say/tell channels only.

- **Sidecar architecture changes.** The sidecar's internal prompt
  engineering, memory retrieval, and model selection are out of scope.
  This feature provides the sidecar with richer context; the sidecar
  decides how to use it.

---

## User Experience

### Player Flow

1. **Player recruits an NPC.** The player says a recruitment keyword
   (e.g., "join me") to an eligible NPC. The recruitment roll succeeds.
   The NPC becomes a companion and joins the player's group. (This already
   works today.)

2. **First conversation after recruitment.** The player says something to
   their new companion (via /say without the ! prefix). The companion
   responds as a group member, not as their former role. Example: Instead
   of "Move along, citizen" (guard script), they might say "So where are
   we headed? I know these roads well from my years on patrol."

3. **Ongoing conversation in the field.** As the player and companion
   travel, fight, and explore, conversations reference the current
   situation. In East Karana fighting gnolls: "These gnolls are more
   organized than the ones I used to run off from the gates." In
   Befallen: "This place reeks of undeath. Stay close."

4. **Character emergence over time.** Through extended conversation,
   the companion develops personality quirks, backstory details, and
   opinions that the LLM invents and the memory system preserves. A
   guard companion might gradually reveal a fear of the ocean, a
   preference for ale over wine, or regret about a decision they made
   before joining you. These emerge naturally through dialogue, not
   through scripted triggers.

5. **Unprompted commentary (rare).** Occasionally, without being spoken
   to, a companion says something contextual. Entering a new zone for
   the first time: "Huh. I've heard stories about this place but never
   thought I'd see it." After a difficult fight: "That was too close."
   This is rare — perhaps once per play session, not every few minutes.

6. **Dismiss and re-recruit.** When a companion is dismissed and later
   re-recruited, they remember the player and their shared history.
   "Back again? I was wondering when you would come find me." Their
   companion context reactivates, and they pick up where they left off.

### Example Scenario

**Setup:** A level 15 Human Ranger in West Karana recruits Tegea Prendyn,
a level 14 Human Druid from Surefall Glade who is flagged as an outdoor
NPC in the zone.

**Recruitment:** The ranger says "Join me." The recruitment roll succeeds.
Tegea joins the group.

**First conversation:**
- Player: "Hail, Tegea"
- Tegea: "Well met, friend. It feels good to stretch my legs beyond the
  Glade. These plains are beautiful this time of year — though I hear the
  gnolls have been more aggressive lately."

Note what changed: Tegea is not saying "Welcome to the Qeynos Hills
ranger station" or reciting druid guild dialogue. She is speaking as a
traveling companion who happens to know the local area from her Surefall
Glade background.

**In the field (West Karana, fighting gnolls):**
- Player: "What do you think of these gnolls?"
- Tegea: "Sabertooth gnolls. They've been raiding the caravans on the
  road to Qeynos for years. Some of us from the Glade used to run
  patrols out here, but there were never enough of us to push them back
  for good."

Note: Her druid/Surefall Glade background informs her perspective, but
she talks about it as past experience, not current duty. She correctly
identifies the Sabertooth clan (based in Blackburrow, operating in West
Karana) rather than the Splitpaw clan (based in Southern Karana).

**Zone change (entering Blackburrow):**
- Player: "Watch yourself in here."
- Tegea: "Underground... not my favorite. I can feel the earth pressing
  in. But I can hear running water deeper inside — there may be a way
  through. Let me know if you need healing."

Note: She references her class (druid — uncomfortable underground, offers
healing), the zone environment (Blackburrow's tunnels and underground
river), and her role in the group.

**Extended conversation (at camp, resting):**
- Player: "Tell me about Surefall Glade."
- Tegea: "It's home. Or it was. The rangers and druids there watch over
  the forest and keep the peace with the bears — though peace is a strong
  word for it some days. I miss the waterfall. You could hear it from
  anywhere in the Glade."

Note: Backstory as memory, not current role.

---

## Game Design Details

### Mechanics

#### Companion Context Layer

When an NPC is recruited as a companion, the system should construct a
**companion context** that augments the standard NPC context sent to the
LLM sidecar. This context layer communicates to the LLM that the NPC's
situation has changed and provides the information needed to generate
appropriate companion dialogue.

The companion context includes:

1. **Companion status flag.** A clear signal that this NPC is currently
   an active companion in the player's group, not an NPC at their
   original post.

2. **Origin summary.** The companion's original role and location,
   framed as backstory. Not "You are a guard in Qeynos" but "You were a
   guard in Qeynos before you joined this adventurer's party."

3. **Current situation.** Information about where the group is and what
   they are doing right now:
   - Current zone (short name and long name)
   - Zone type (outdoor, dungeon, city, underwater)
   - Whether the companion is currently in combat
   - Whether the group recently finished a fight
   - Time of day (in-game time: dawn, day, dusk, night)
   - How long the companion has been recruited (rough duration — hours,
     days — to establish relationship depth)

   **Luclin zone note:** Several Luclin zones have fixed lighting — one
   side of the moon is permanently dark, the other permanently lit. The
   context system should not generate standard day/night commentary
   (e.g., "it's getting dark") for zones where time of day does not
   change. The architect should determine whether zone-specific flags
   are needed or if this can be handled by the sidecar's zone knowledge.

4. **Group composition.** Who else is in the group:
   - Player name, race, class, level
   - Other companions in the group (if any), with their names and races
   - Group size

5. **Cultural identity markers.** Data that helps the LLM differentiate
   companion personalities:
   - Companion's race and the cultural associations of that race
   - Companion's class and the worldview associated with that class
   - Companion's home zone (where they were recruited from)
   - Companion's deity (if applicable)

6. **Activity hints.** Recent activity data to ground the conversation
   in the moment:
   - The NPC types the group has recently killed (by name, not ID)
   - Whether the group is moving or stationary
   - Whether the companion has taken significant damage recently

#### Context Delivery

The companion context is delivered to the LLM sidecar as additional
fields in the existing context payload (the same payload built by
`llm_bridge.build_context()`). The sidecar already receives NPC identity
data; companion context adds situation and relationship data on top.

When `is_companion` is true in the context payload, the sidecar should
use a companion-appropriate system prompt rather than the standard NPC
system prompt. The companion system prompt instructs the LLM to:
- Treat the NPC's original role as backstory, not current identity
- Reference the current zone, situation, and group members naturally
- Maintain personality consistency with race, class, and cultural traits
- Build on existing memory/soul data for character continuity
- Keep responses conversational and in-character

#### Unprompted Commentary System

Companions should occasionally speak without being prompted by the player.
This creates the feeling of traveling with a living character rather than
an NPC that only responds when spoken to.

**Trigger conditions (all must be met):**
- The companion has been active for at least 10 minutes since last
  unprompted comment (minimum interval)
- A significant context change has occurred:
  - The group entered a new zone
  - A notable fight just ended (boss or named NPC killed)
  - An extended period of idle time has passed (camping/resting)
- A random roll succeeds (low probability — approximately 25% when
  conditions are met)

**Constraints:**
- Maximum one unprompted comment per 15 minutes (hard cap)
- No unprompted commentary during active combat
- No unprompted commentary in the first 2 minutes after recruitment
  (let the player initiate)
- Unprompted commentary uses the same LLM pathway as regular
  conversation, with an additional flag indicating the comment is
  unprompted so the sidecar can adjust tone (shorter, more observational,
  less conversational)

**Commentary types (selected by the sidecar based on context):**
- Zone observation: "I've never been this far south before."
- Post-combat reaction: "That was a tough one. I thought we were done
  for a moment there."
- Idle musing: "Do you ever wonder what's beyond the ocean?"
- Environmental awareness: "It's getting dark. We should be careful."

#### Identity Shift Mechanics

The identity shift is not binary — it is a reframing. The companion's
original identity data (race, class, level, faction, home zone, NPC name)
is still sent to the sidecar. What changes is the framing context around
that data.

**Before recruitment (standard NPC context):**
The LLM receives: "You are [Name], a level [N] [Race] [Class] in [Zone].
[Faction instruction]."
The NPC talks as their current role: guard, merchant, quest giver, etc.

**After recruitment (companion context):**
The LLM receives the same identity data plus: "You are now an active
companion in [Player]'s adventuring party. You were formerly a [Role] in
[Original Zone], but you have left that life behind to travel with this
group. Your background informs your perspective but is no longer your
daily reality. You are a group member first."

The companion context does not erase the original identity — it wraps it
in a new frame. A guard who becomes a companion is still martial,
disciplined, and aware of Qeynos politics. But they talk about those
things as an ex-guard, not an on-duty guard.

#### Personality Variation by Race and Culture

Different races and cultures in Norrath have distinct worldviews,
speech patterns, and values. The companion context should provide
cultural identity markers that the LLM can use to differentiate
companions.

**Examples of cultural variation (illustrative, not exhaustive):**

- **Erudite:** Intellectual, verbose, references magical theory and
  scholarly knowledge. Might analyze a situation rather than react to
  it emotionally. Values wisdom and learning. *Note: Erudin Erudites
  (good-aligned) and Paineel Erudites (heretics — necromancers, shadow
  knights, evil clerics) are deeply hostile to each other. A companion's
  class can identify their origin city: a necromancer is from Paineel,
  a paladin from Erudin. This distinction significantly shapes their
  personality and worldview.*

- **Barbarian:** Direct, physical, values strength and loyalty. Speaks
  plainly. References the harsh conditions of Halas and the Northlands.
  Respects warriors and combat prowess.

- **Dark Elf:** Suspicious, calculating, sophisticated. May reference
  Neriak politics or Innoruuk's teachings. Trust is earned slowly.
  Observes others carefully before speaking.

- **Halfling:** Cheerful, practical, fond of food and drink and home
  comforts. References Rivervale and the simple life. May seem lighthearted
  but surprisingly perceptive.

- **Troll:** Blunt, aggressive, references hunger and violence casually.
  Simple speech patterns. Grudging respect must be earned through
  demonstrated strength.

- **Iksar:** Disciplined, insular, proud of Sebilisian Empire heritage.
  *Important constraint: Iksar are killed on sight in all old-world
  good-aligned cities (Qeynos, Freeport, Felwithe, Kaladim, Erudin).
  An Iksar companion must never reference these cities as familiar or
  friendly places. They are welcome only in Cabilis (Kunark), Thurgadin
  (Velious), and Luclin cities (Shadowhaven, Shar Vahl).*

- **Vah Shir (Luclin era):** Proud, spiritual, references Shar Vahl,
  the grimling incursions, and the Akheva. Feline mannerisms and
  cultural references. *Defining cultural trait: written records are
  banned among the Vah Shir. Knowledge is passed through oral tradition
  — through hymnists (elite memory-keeper bards) and mnemonic scribes.
  This ban exists because they blame Erudite written magic for their
  exile to Luclin. A Vah Shir companion would be distrustful of books,
  scrolls, and written magic. They tell stories and reference what
  "the hymnists say" rather than what is written. They may distrust or
  question companions who rely on texts.* For deeper Luclin exploration,
  they may also reference the Shissar in the Grey as a distant threat.

The companion context should include the companion's race ID so the
sidecar can apply cultural modifiers. The actual cultural prompt
engineering happens in the sidecar, not in the game code — the game
provides the data, the sidecar provides the personality.

### Balance Considerations

This feature has **no mechanical balance impact**. It affects only the
content of LLM-generated dialogue, not combat, loot, experience, or
any game system. Companion power, AI behavior, stance, and equipment
are all handled by the existing companion system and are unaffected.

The only resource cost is the LLM sidecar call latency, which already
exists for all NPC conversation. The companion context adds minimal
additional data to the payload (a handful of extra fields). The
unprompted commentary system adds occasional additional sidecar calls,
but the rate limits (maximum one per 15 minutes, low probability roll)
ensure this is negligible.

**1-3 player relevance:** Since players on this server will have 3-5
companions filling out their group at any given time, the quality of
companion conversation directly impacts the core gameplay loop. Better
companion context makes solo and duo play more engaging without
affecting game balance.

### Era Compliance

This feature is fully era-compliant. It does not introduce any new
game content — no items, spells, zones, or NPCs. It modifies only the
conversational context sent to the LLM sidecar.

**Era-sensitive areas to verify:**
- Cultural identity markers must reference only Classic-through-Luclin
  content. No Planes of Power zones, deities, or cultural references.
- Vah Shir (race 130) companions are only available in Luclin content;
  cultural markers should reference Shar Vahl, grimlings, and Akheva.
- Zone type classifications must use Classic-Luclin zone lists only.
- Any example dialogue in sidecar prompts must avoid post-Luclin
  references.
- **Froglok** (races 74, 330) exist only as monsters in Classic-Luclin.
  They became a playable race in Legacy of Ykesha (2003, post-Luclin).
  No companion personality framework is needed for Frogloks — they are
  already excluded from recruitment.
- **Berserker class** does not exist in Classic-Luclin (added in Gates
  of Discord, 2004). Must not appear in companion context or dialogue.
- **Iksar KOS constraints** must be enforced in companion dialogue —
  an Iksar companion cannot reference old-world good-aligned cities as
  familiar or friendly (see Personality Variation section above).

---

## Affected Systems

- [x] Lua quest scripts (`akk-stack/server/quests/`)
  - `lua_modules/llm_bridge.lua` — needs a companion-aware context
    builder (the core change)
  - `global/global_npc.lua` — may need timer/event hooks for unprompted
    commentary triggers
  - Potentially a new `lua_modules/companion_context.lua` for context
    construction logic

- [x] C++ server source (`eqemu/`)
  - May need to expose additional companion state to Lua (e.g., time
    since recruitment, recent kill history). The architect will determine
    what is already available vs. what needs new bindings.

- [ ] Perl quest scripts (maintenance only) — No changes needed.

- [ ] Database tables (`peq`) — No schema changes anticipated. All
  companion context data should be derivable from existing game state
  (zone, entity list, companion data tables).

- [ ] Rule values — No new rules anticipated. Unprompted commentary
  timing could use hardcoded constants rather than server rules, since
  these are creative tuning values not server configuration.

- [ ] Server configuration — No changes needed.

- [ ] Infrastructure / Docker — No changes needed. The LLM sidecar
  is already running.

---

## Dependencies

1. **Existing companion system must be functional.** The companion
   recruitment, follow, fight, command, equipment, and dismiss systems
   must all be working. (They are.)

2. **LLM sidecar must be running.** The sidecar that receives context
   and generates NPC dialogue must be available. (It is.)

3. **Companion soul/memory system must be functional.** The memory
   persistence layer that makes LLM-invented details stick across
   conversations must be working. (It is.)

4. **No blocking dependencies on other features.** This feature builds
   on existing infrastructure and does not require any other feature to
   be implemented first.

---

## Open Questions

1. **What companion state is already exposed to Lua?** The architect
   needs to determine which companion data is accessible from Lua
   scripts today (e.g., time since recruitment, companion type, stance)
   vs. what needs new C++ bindings. The PRD does not prescribe specific
   API additions — the architect determines this.

2. **How does the sidecar currently structure its system prompt?** The
   companion context changes require the sidecar to use a different
   system prompt frame for companions vs. regular NPCs. The architect
   needs to assess the sidecar's current prompt template system and
   determine how to integrate companion context.

3. **What recent activity data is readily available?** The PRD calls
   for "recent kill history" and "recently taken damage" as context
   data. The architect needs to determine whether this data is available
   in the zone process's entity state or whether it would need tracking
   infrastructure.

4. **Unprompted commentary implementation approach.** The PRD describes
   the desired behavior (triggers, constraints, rate limits). The
   architect needs to determine the best implementation approach — timer
   events, zone change hooks, signal-based triggers, etc.

5. **Luclin fixed-lighting zones.** Several Luclin zones have fixed
   day/night conditions. The architect should determine whether zone
   metadata flags are needed to prevent incorrect time-of-day commentary,
   or whether the sidecar can handle this via zone knowledge.

---

## Acceptance Criteria

- [ ] A recruited companion responds to conversation as a group member,
  not as their original role. A former guard does not say "Move along,
  citizen" or refer to their patrol duties as current activity.

- [ ] A companion references the current zone by name or description
  in conversation when contextually appropriate (e.g., "These tunnels
  are treacherous" in Blackburrow).

- [ ] A companion references their origin (home zone, former role) as
  backstory when appropriate (e.g., "Back in Qeynos, I used to see
  gnolls at the gates, but never this deep in their territory").

- [ ] Two companions of different races (e.g., Erudite and Barbarian)
  produce noticeably different conversational styles when asked the
  same question in the same zone.

- [ ] Unprompted companion commentary occurs at a natural rate — no
  more than once per 15 minutes, and not during active combat.

- [ ] Unprompted commentary is contextually relevant to the current
  zone or recent activity, not random generic statements.

- [ ] A dismissed and re-recruited companion resumes companion-style
  conversation (not reverting to original NPC dialogue) and references
  shared history when appropriate.

- [ ] The companion context system works for all recruitable NPC races
  in the Classic-through-Luclin era (including Vah Shir when Luclin
  content is enabled).

- [ ] No post-Luclin lore references appear in any companion dialogue
  or context data.

- [ ] An Iksar companion does not reference old-world good-aligned
  cities (Qeynos, Freeport, Felwithe, Kaladim, Erudin) as familiar
  or friendly places.

- [ ] The system does not introduce noticeable additional latency
  beyond the existing LLM sidecar response time (companion context
  adds minimal payload data).

- [ ] Companions in a group with other companions do not interact
  with each other or reference each other in conversation (out of
  scope for this feature).

---

## Appendix: Technical Notes for Architect

_These are advisory observations from reading the existing codebase.
The architect makes all implementation decisions._

**Existing context builder (`llm_bridge.build_context()`):** Currently
builds a flat table with NPC identity data (type ID, name, race, class,
level, INT, faction, gender, deity, zone info, player info). The simplest
approach may be to add an `is_companion` boolean plus companion-specific
fields (home zone, recruitment duration, group composition, activity
hints) to this same payload. The sidecar can then branch its system
prompt template based on `is_companion`.

**Companion eligibility bypass:** `llm_bridge.is_eligible()` already
has a special case for companions (`if e.self:IsCompanion() then return
true end`), so companions always reach the LLM pathway regardless of
local script or body type filters.

**Companion methods available in Lua (from `companion.lua` usage):**
- `npc:IsCompanion()` — boolean
- `npc:GetOwnerCharacterID()` — returns owner's character ID
- `npc:GetCompanionType()` — returns 0 (loyal) or 1 (mercenary)
- `npc:GetStance()` — returns 0/1/2
- `npc:GetCompanionID()` — returns companion data ID
- `npc:GetCleanName()` — NPC name
- Standard Mob/NPC methods (GetRace, GetClass, GetLevel, etc.)

**Data available without new C++ bindings (likely):**
- Current zone: `eq.get_zone_short_name()`, `eq.get_zone_long_name()`
- Game time: `eq.get_time()` (if exposed — needs verification)
- Entity list: `eq.get_entity_list()` for group composition
- Recent kills: may need a simple Lua-side tracking table (incremented
  in `event_death_zone` or similar)

**Unprompted commentary:** Could use `eq.set_timer()` on the companion
entity to fire periodic checks, with the companion context builder
consulted to decide whether to generate an unprompted remark. The
timer would fire every N minutes, check context change conditions,
roll probability, and if all pass, call `llm_bridge.generate_response()`
with an unprompted flag in the context.

**Sidecar prompt consideration:** The sidecar likely has a system prompt
template that includes the NPC context data. For companion mode, the
system prompt needs a different frame: "You are a companion traveling
with [Player], formerly a [Role] from [Zone]..." rather than "You are
[Name], a [Role] in [Zone]." The exact prompt engineering is the
sidecar's concern, but the game-side context must provide all the data
the sidecar needs to construct this prompt.

**Lore-master notes for implementation (from lore review):**
- The richest companion personalities emerge from race + class + deity
  combinations (e.g., Barbarian Shaman = warrior culture + Tribunal's
  cosmic justice; Iksar Monk = fallen empire pride + physical perfection;
  Halfling Rogue = Bristlebane mischief + genuine loyalty; Vah Shir
  Beastlord = oral tradition + beast-bond + Luclin threats).
- Dialogue tone should be terse and atmospheric — EQ style. Companions
  observe; they do not narrate.
- Existing race framings in companion_culture.lua (Ogre panic behavior,
  Dark Elf cold precision, Iksar disciplined/insular, Troll feral
  aggression) are lore-accurate and should be preserved as-is. This
  feature extends that system to the remaining races.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
