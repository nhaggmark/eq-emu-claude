# NPC Recruitment Companion System — User Stories

> **Feature branch:** `feature/npc-recruitment`
> **Author:** game-designer
> **Date:** 2026-02-27
> **Status:** Complete — lore-approved, architect-reviewed
> **Baseline:** PRD (`game-designer/prd.md`), Architecture (`architect/architecture.md`),
> Feasibility Review (`architect/user-story-feasibility.md`)

---

## Scope Expansion Note

The original PRD listed companion leveling, equipment management, and long-term
persistence as explicit **non-goals**. The user has since requested these features
be included. The architect's feasibility review (`user-story-feasibility.md`)
confirmed technical feasibility for all three expansions. This user stories document
treats them as in-scope and includes full stories for each.

**Stories within original PRD scope:** US-R01-R07, US-C01-C04, US-PM01-PM05, US-M01-M03
**Stories from expanded scope:** US-G01-G04 (leveling), US-E01-E05 (equipment),
US-P01-P04 (persistence/soul), US-D01-D03 (death/soul wipe), US-RR01-RR03
(re-recruitment)


## Design Decisions: Architect's 6 Open Questions

Before the user stories, these design decisions answer the 6 open questions
raised in the architect's feasibility review. Each decision includes reasoning
and is referenced by the relevant user stories.

### Decision 1: Level Scaling Formula

**Question:** Linear scaling from base stats, or use player stat tables?

**Decision: Linear scaling from base stats.**

Formula: `scaled_stat = base_stat * (current_level / recruited_level)`

**Implementation note:** This formula MUST use floating-point division to avoid
integer truncation. In C++, `(int)(base_stat * (float)current_level / (float)recruited_level)`.
Without the cast, a level 15 companion recruited at level 10 would compute
`15/10 = 1` (integer division), producing zero stat growth until the companion
doubles their recruited level.

Where `base_stat` is the value from `npc_types` at the time of recruitment,
and `recruited_level` is the NPC's level when first recruited.

**Reasoning:**
- NPC stats in `npc_types` are already tuned for the NPC's role and identity.
  A guard has guard-appropriate stats. A wizard has wizard-appropriate stats.
  Scaling preserves these relative strengths.
- Player stat tables (`base_data`) are designed for player races/classes and
  would produce alien stat curves when applied to NPC race/class combinations
  that don't exist in the player table (e.g., an Ogre Enchanter NPC).
- Linear scaling is simple, predictable, and easy to tune via the existing
  `StatScalePct` rule. If a level 20 guard with 150 STR reaches level 40,
  their STR becomes 300 — strong but not gamebreaking.
- Bot stat formulas are tightly coupled to Bot's data structures and would
  require significant adaptation for diminishing returns.

**Edge case handling:**
- HP and mana scale with level using the same linear formula applied to the
  NPC's max_hp and max_mana from npc_types.
- AC scales linearly. Resists scale linearly.
- Attack/damage scale linearly but are soft-capped at the level-appropriate
  values from the NPC's class (warrior caps differ from wizard caps).
- If scaled stats produce values that would be gamebreaking (e.g., a level 10
  NPC with unusually high base stats scaled to 65), the `StatScalePct` rule
  provides a global dampener. Default 100% can be lowered to 80-90% if needed.

### Decision 2: Equipment on Dismissal

**Question:** Do equipped items return to player, or persist on the companion?

**Decision: Items persist on the companion.**

When a companion is dismissed, their equipped items stay with them in the
`companion_inventories` table. If re-recruited, the companion returns with
all their gear. If the companion suffers a permanent soul wipe (death without
resurrection), their gear is destroyed — lost with them.

**Reasoning:**
- Items persisting creates emotional investment. "I gave Guard Noyan my old
  Blackened Iron armor and he's still wearing it." This supports the lifelong
  companion fantasy.
- Returning items on dismissal makes companions feel like gear mules, not
  characters. It reduces them to a storage mechanic.
- The risk of losing gear on soul wipe creates genuine emotional stakes. The
  player must decide: do I invest good gear in this companion knowing it could
  be lost? This is the same decision players make with twink gear on alts.
- If a player wants their gear back before dismissal, they can use the trade
  window to retrieve it manually. This is an intentional step, not automatic.

**Edge case handling:**
- Players can trade with their companion to retrieve specific items before
  dismissal (trade window works both ways — give and take).
- Visual appearance updates when gear changes (via `OP_WearChange` packets).
- If the player deletes their character, companion data and inventories are
  cleaned up in the character deletion flow.

### Decision 3: Equipment Class Restrictions

**Question:** Use the item table's existing race/class flags, or define custom rules?

**Decision: Use existing item table race/class flags.**

The `items` table already has `races` and `classes` bitmask columns that define
which races and classes can equip each item. Companions respect these restrictions
based on their NPC's class and race from `npc_types`.

**Reasoning:**
- The item restriction system is battle-tested and comprehensive. Every item
  in the database already has correct race/class flags.
- Custom companion rules would require a new table and maintenance burden with
  no clear player benefit.
- Players already understand "this item is Warrior-only" or "this item is
  All/All." The same rules applying to companions is intuitive.
- NPC races that don't have player equivalents (e.g., race IDs not in the
  standard player race list) use the "All Races" flag check — if an item
  allows all races, any companion can equip it.

**Edge case handling:**
- NPCs with non-standard race IDs (skeleton, elemental, werewolf, etc.):
  `GetPlayerRaceValue()` returns a sentinel value for these races, so they
  fail ALL race-restricted checks. Only items with `races` bitmask = 0 or
  65535 (All Races) are equippable. This naturally limits gear options for
  exotic NPCs, which is thematically appropriate.
- NPCs with class 0 (GM/Unknown): mapped to class 1 (Warrior) for equipment
  class bitmask checks. Most guards and generic NPCs have warrior-adjacent
  stats, making this the correct default.
- Feedback message when an item is rejected: "[Companion name] cannot use
  this item." No detailed class/race breakdown — keep it simple.

### Decision 4: XP Rate for Companions

**Question:** Same share as player split, or reduced (e.g., 50%)?

**Decision: Companions receive 50% of a full group member's XP share.**

When `Group::SplitExp()` runs, companions count toward the member divisor
(they take up a group slot) but only accumulate half the XP that a player
member would receive. The other 50% is effectively lost — it does not
redistribute to other group members.

**Reasoning:**
- Full XP share (100%) would mean companions level at the same rate as players.
  In a solo + 5 companion group, the player and all companions get 1/6 share.
  Companions would quickly catch up to the player and the level cap system
  (Decision 5) would be the only brake.
- Zero XP for companions means they never level, which defeats the purpose
  of the expanded scope.
- 50% creates a natural lag where companions level slower than the player.
  The player always leads. Over time, a long-term companion gradually grows
  but never outpaces the player. This creates a satisfying "growing together"
  arc where the player is always the mentor figure.
- The 50% rate is configurable — if it feels too fast or slow, a new rule
  `Companions:XPSharePct` (default 50) provides the tuning knob.
- The lost 50% is intentional: it represents the "cost" of having AI party
  members. A full group of 6 players earns more total XP than 1 player +
  5 companions, rewarding human grouping.

**Edge case handling:**
- Companion XP is tracked per-companion in `companion_data.experience`.
- Level-up thresholds use the same XP table as players (`level_exp_mods`).
- Companions cannot level while dead. XP only accumulates while alive and
  active (not suspended).

### Decision 5: Level Cap for Companions

**Question:** Can a level 10 recruit reach level 65? Or cap at original + N?

**Decision: Companions can level up to `player_level - 1`, with no absolute cap.**

A companion can never equal or exceed their owner's level. They are always at
least 1 level behind. There is no artificial cap based on original level —
a level 10 guard recruited at level 12 can eventually reach level 64 if the
player reaches level 65.

**Reasoning:**
- An absolute cap (original + N) would make low-level recruits disposable.
  The entire point of the expanded scope is "keep a companion for the whole
  game." Capping a level 10 recruit at level 20 kills this fantasy.
- The `player_level - 1` cap ensures the player is always stronger. The
  companion is a follower, not a peer. This maintains the power dynamic
  where the player is the leader.
- Leveling a companion from 10 to 64 is a massive time investment (50%
  XP rate means they level roughly twice as slowly as the player). This
  is a marathon, not a sprint. The investment itself creates attachment.
- At level 65, the player has a level 64 companion who has been with them
  through dozens of zones, hundreds of fights, and has accumulated a rich
  ChromaDB memory of their shared history. This IS the lifelong companion
  fantasy.

**Edge case handling:**
- When the companion reaches `player_level - 1`, excess XP is discarded.
  The companion cannot "bank" XP for later.
- If the player de-levels (rare but possible via GM commands), companions
  above `player_level - 1` do not de-level. They simply stop gaining XP
  until the player catches up.
- Stat scaling at extreme level gaps (10 -> 64) may produce odd values.
  The `StatScalePct` rule provides a global dampener if needed.
- Spell list updates happen automatically on level-up. The
  `companion_spell_sets` table is level-ranged, so `LoadCompanionSpells()`
  picks up new spells at each level boundary.

### Decision 6: Re-recruitment Cost

**Question:** Is re-recruiting a dismissed companion free, or harder than first time?

**Decision: Re-recruitment is easier than first time (+10% bonus), and free
of faction/persuasion checks if the companion was dismissed voluntarily
(not soul-wiped).**

When a player returns to a voluntarily dismissed companion, the companion
remembers the relationship (ChromaDB memories persist, companion_data row
has `is_dismissed=1`). The re-recruitment attempt gets a +10% bonus to the
recruitment roll (the "Previous recruitment history" modifier from the PRD).
No cooldown applies.

For soul-wiped companions (died without resurrection), the NPC is a stranger.
Standard recruitment rules apply — full faction, persuasion, and disposition
checks. The +10% bonus does NOT apply. The companion starts at their original
level with no gear, no memories, and no relationship. This is the emotional
cost of letting a companion die.

**Reasoning:**
- Easy re-recruitment of dismissed companions supports the "companion went
  back to their post but the experience changed them" narrative. They
  remember you and want to come back.
- Making re-recruitment harder would punish players for experimenting with
  different party compositions. "I'll try a different healer" should not
  permanently lock out the old one.
- The soul wipe distinction creates a clear consequence hierarchy:
  - Dismissal: temporary separation, easy reunion, everything preserved.
  - Death + resurrection: close call, companion restored, emotional moment.
  - Death + no resurrection: permanent loss. The NPC returns but doesn't
    know you. Everything is gone.
- For mercenary-type companions (auto-dismissed due to faction drop), the
  re-recruitment bonus still applies. The mercenary remembers the arrangement
  even if they left. "You again. I trust your coin has improved."

**Edge case handling:**
- Companion_data row persists with `is_dismissed=1` after voluntary dismissal.
  The row is deleted only on soul wipe.
- Multiple dismissed companions: a player can have multiple dismissed
  companions stored in the database. Re-recruiting any of them restores
  that specific companion's full state (level, gear, memories).
- Database cleanup: dismissed companion records older than 30 days with no
  re-recruitment are eligible for cleanup (configurable retention period).

---

## Category 1: Recruitment

### US-R01: Basic NPC Recruitment via Dialogue

**Story:** As a player, I want to target an eligible NPC and say "recruit" so
that I can add them to my adventuring party.

**Acceptance Criteria:**
- Player targets an NPC and says "recruit" (or "join me", "come with me",
  "I could use your help") in /say chat
- The system evaluates eligibility: level range (+/- 3 levels), faction
  (minimum Kindly), NPC type (not excluded), group capacity (< 6 members),
  not already recruited, not in combat, no active cooldown
- On success: NPC despawns from world, joins player's group, recruitment
  success message is displayed via LLM dialogue
- On failure: NPC responds with culturally-appropriate refusal via LLM,
  15-minute cooldown is applied for this specific NPC+player combination
- The recruitment roll uses the formula from the PRD: base 50% + faction
  modifier + persuasion bonus + disposition modifier + level difference,
  clamped to [5%, 95%]

**Design Notes:**
- Keywords are intercepted in `global/global_npc.lua` before reaching the
  LLM layer. The Lua script performs the eligibility check and recruitment
  roll, then provides success/failure context to the LLM for dialogue.
- The cooldown is stored as a data bucket:
  `companion_cooldown_{npc_type_id}_{char_id}`, duration = RecruitCooldownS.
- The level range is controlled by `Companions:LevelRange` rule (default 3).

### US-R02: Culture-Specific Persuasion Checks

**Story:** As a player, I want the recruitment check to use the stat my target
NPC's culture actually respects, so that recruiting feels authentic to each
culture's values.

**Acceptance Criteria:**
- Human/Elf/Halfling NPCs use CHA as the primary persuasion stat
- Ogre/Barbarian/Troll NPCs use STR as the primary persuasion stat
- Erudite/Gnome NPCs use INT as the primary persuasion stat
- Iksar NPCs use player level relative to NPC level as the primary factor
- Secondary factors (faction, level, stat) contribute at ~50% the weight of
  the primary stat
- Persuasion bonus formula: `(primary_stat - 75) / 5 + secondary_bonus`
- Culture-to-stat mapping is loaded from `companion_culture_persuasion` table
- Changing the mapping in the database changes behavior without code changes

**Design Notes:**
- The `companion_culture_persuasion` table maps NPC race_id to primary_stat,
  secondary_type, and secondary_stat. The Lua recruitment module reads this
  table to determine which stats to check.
- Erudites have a zone-based override: NPCs in Paineel/The Hole use
  mercenary-type INT-based persuasion; NPCs in Erudin use companion-type
  CHA-based persuasion. The Lua module checks zone context.
- Freeport NPCs: Steel Warriors and Knights of Truth are companion-type;
  Freeport Militia are mercenary-type. Determined by NPC faction, not zone.

### US-R03: Companion vs. Mercenary Recruitment Types

**Story:** As a player, I want NPCs from different cultures to join as either
loyal companions or tactical mercenaries, so that recruitment reflects the
cultural identity of Norrath.

**Acceptance Criteria:**
- NPCs from good/neutral cultures (Qeynos, Halas, Kelethin, Rivervale,
  Erudin, Kaladim, Ak'Anon, Felwithe, Shar Vahl, Shadow Haven, Katta
  Castellum, Freeport Steel Warriors/Knights of Truth) join as **companions**
- NPCs from evil/self-interest cultures (Neriak, Cabilis, Oggok, Grobb,
  Paineel, Freeport Militia) join as **mercenaries**
- The companion/mercenary type is stored in `companion_data.companion_type`
  (0=companion, 1=mercenary)
- Both types function identically in combat
- The type is determined at recruitment time and does not change
- Companion type affects dialogue tone, memory framing, and retention behavior
  (see US-M01 for mercenary retention)

**Design Notes:**
- The type is determined by the `recruitment_type` column in
  `companion_culture_persuasion`. The Lua module reads this at recruitment time.
- LLM dialogue context is different for companions vs. mercenaries:
  companions can express warmth and loyalty; mercenaries never do.
- This distinction is the core of the system's lore authenticity. It must
  never be flattened to a single type.

### US-R04: Racial Disposition Caps

**Story:** As a player, I want NPC disposition to reflect cultural reality,
so that a Teir'Dal is never eagerly waiting to follow a stranger and an Ogre
never has complex emotional motivations for joining.

**Acceptance Criteria:**
- Qeynos, Halas, Kelethin, Rivervale, Shar Vahl NPCs: max disposition = Eager
- Erudin, Felwithe, Kaladim, Ak'Anon NPCs: max disposition = Restless
- Freeport (non-Militia), Shadow Haven, Katta Castellum: max = Eager
- Neriak (Teir'Dal): max = Content
- Cabilis (Iksar): max = Content
- Oggok (Ogre): max = Curious
- Grobb (Troll): max = Restless
- Paineel (Heretics): max = Restless
- Disposition caps are enforced by the soul element system, not the
  recruitment system — the recruitment system reads the capped value
- The `max_disposition` column in `companion_culture_persuasion` stores
  the cap per race

**Design Notes:**
- The soul element system (npc-llm-phase3) assigns dispositions. The cap
  ensures that even randomly assigned dispositions respect cultural limits.
- Disposition values: 0=Rooted, 1=Content, 2=Curious, 3=Restless, 4=Eager.

### US-R05: Recruitment Exclusion List

**Story:** As a player, I want quest-critical NPCs, merchants, bankers,
guildmasters, bosses, and lore anchor NPCs to be non-recruitable, so that the
world's infrastructure remains intact.

**Acceptance Criteria:**
- NPCs with class 40 (Banker), 41 (Merchant), or classes 20-35 (Guildmasters)
  are automatically excluded
- NPCs with `rare_spawn=1` or bodytype 11/64+ are automatically excluded
- NPCs on the curated exclusion list (`companion_exclusions` table) are
  excluded regardless of all other factors
- Named lore anchors (Lucan D'Lere, Antonius Bayle, King Thex, Raja Kerrath,
  Captain Tillin, Dreadguard Inner, etc.) are hard-blocked
- Hard blocks bypass the 5% minimum clamp — excluded NPCs can NEVER be
  recruited
- The exclusion check happens BEFORE the recruitment roll
- Player bots, pets, mercs, and other companion NPCs cannot be recruited
- Frogloks cannot be recruited (not an organized civilization in Classic-Luclin)
- Attempting to recruit an excluded NPC produces a contextual refusal:
  "This NPC cannot be recruited" (system message, not LLM dialogue)

**Design Notes:**
- The `companion_exclusions` table has two exclusion types: 0=manual (curated
  lore anchors), 1=auto-detected (class/bodytype/flag-based).
- Auto-detection runs as a seed query that populates the table based on NPC
  class, bodytype, and flags. Manual entries are added by the lore-master.
- The Lua eligibility check queries this table. If the NPC is found, recruitment
  is blocked immediately.

### US-R06: Recruitment Cooldown

**Story:** As a player, I want a cooldown after failing to recruit an NPC,
so that I cannot spam recruitment attempts until I get lucky.

**Acceptance Criteria:**
- After a failed recruitment attempt, a 15-minute cooldown is applied for
  that specific NPC+player combination
- The cooldown is tracked via data buckets (existing EQEmu mechanism)
- The cooldown key format is `companion_cooldown_{npc_type_id}_{char_id}`
- During cooldown, attempting to recruit the same NPC produces: "[NPC name]
  has already considered your offer."
- The cooldown does NOT apply to different NPCs — failing with Guard Noyan
  does not prevent recruiting Guard Ethan
- The cooldown timer is controlled by `Companions:RecruitCooldownS` rule
  (default 900 seconds = 15 minutes)
- Successful recruitment does not trigger a cooldown (why would it?)

**Design Notes:**
- Data buckets are the standard EQEmu mechanism for temporary per-entity data.
  They auto-expire after the specified duration. No manual cleanup needed.

### US-R07: No Recruitment During Combat

**Story:** As a player, I understand that I cannot recruit NPCs while I or the
target NPC is in combat, so that recruitment is a deliberate social interaction.

**Acceptance Criteria:**
- If the player is in combat (has aggro, combat timer active), recruitment
  attempt is blocked with message: "You cannot recruit while in combat."
- If the target NPC is in combat, recruitment is blocked with message:
  "[NPC name] is busy fighting."
- "In combat" is determined by the standard EQEmu combat state
  (`Mob::IsEngaged()` or `Client::GetAggroCount() > 0`)

**Design Notes:**
- This prevents exploiting recruitment as a combat mechanic (e.g., recruiting
  a high-level NPC mid-fight to have them help, then dismissing).

---

## Category 2: Combat & AI

### US-C01: Class-Based Combat AI

**Story:** As a player, I want my recruited companions to fight competently
according to their class, so that a recruited cleric heals, a recruited
warrior tanks, and a recruited wizard nukes.

**Acceptance Criteria:**
- All 15 Classic-Luclin classes have functional combat AI:
  - **Tank (WAR/PAL/SK):** Taunts target, engages in melee, uses defensive
    abilities. Maintains highest aggro priority in the group.
  - **Healer (CLR/DRU/SHM):** Heals group members below HP thresholds
    (default 70%). Buffs out of combat. Cures debuffs. Resurrects dead
    group members.
  - **Melee DPS (ROG/MNK/RNG/BST):** Engages target in melee. Uses class
    abilities (backstab, kick, flying kick, etc.). Follows the group's
    assist target.
  - **Caster DPS (WIZ/MAG/NEC):** Nukes from range. Manages mana (sits
    when low, resumes when recovered). Pet classes summon and manage pets.
  - **Utility (ENC/BRD):** Enchanter mezzes adds, slows primary target,
    casts haste on group. Bard runs appropriate song rotations.
- Companion spell lists are loaded from `companion_spell_sets` by class
  and current level
- Companions use spells appropriate to their level — a level 20 cleric
  uses level-appropriate heals, not level 1 heals
- AI must be competent enough that a solo player + 5 companions can clear
  level-appropriate group content

**Design Notes:**
- Spell AI is adapted from the Bot system (`botspellsai.cpp`) which already
  has logic for all 16 classes. The adaptation simplifies it to work with
  the companion's stance-based system rather than Bot's full settings.
- The initial implementation may start with 4 archetypes (like Merc) and
  expand to full class-specific behavior iteratively. But the architecture
  supports all 15 classes from day one via `companion_spell_sets`.

### US-C02: Stance System

**Story:** As a player, I want to set my companion's combat stance, so that
I can control whether they fight aggressively, defensively, or not at all.

**Acceptance Criteria:**
- Three stances are available: Passive, Balanced, Aggressive
- Player sets stance by targeting the companion and saying "passive",
  "balanced", or "aggressive"
- **Passive:** Companion does not engage in combat. Follows player. Will
  not auto-attack or cast offensive spells. Healers still heal in passive.
- **Balanced (default):** Companion fights when the group is engaged.
  Healers heal when needed. Tanks taunt engaged enemies. DPS attacks
  the assist target.
- **Aggressive:** Companion engages anything the player attacks immediately.
  Maximum DPS. Reduced threat awareness (may pull aggro from tank).
- Stance is stored in `companion_data.stance` and persists across zones
  and sessions
- Stance changes take effect immediately
- Confirmation message: "[Companion name] is now in [stance] stance."

**Design Notes:**
- Stance affects spell selection in `companion_ai.cpp`. The
  `companion_spell_sets` table has a `stance` column (0=all, 1=passive,
  2=balanced, 3=aggressive) that filters which spells are available.
- Healers in passive stance still heal — this is intentional. A passive
  healer companion is a common and valid use case (pocket healer that
  doesn't draw aggro).

### US-C03: Companion Follow and Positioning

**Story:** As a player, I want my companion to follow me when not in combat
and hold position when told, so that I can manage their location.

**Acceptance Criteria:**
- By default, companions follow their owner at melee range distance
- Player can say "guard here" to make the companion hold position
- Player can say "follow me" to resume following
- During combat, companions move to engage targets based on their class:
  tanks close to melee range, casters stay at range, healers position
  between melee and range
- After combat ends, companions return to follow behavior (or guard
  position if set)
- Companions do not path through walls or terrain obstacles (use existing
  NPC pathing system)

**Design Notes:**
- Follow behavior uses the existing NPC follow mechanic (`Mob::SetFollowID()`).
- Guard behavior uses the existing NPC guard mechanic (set position, do not
  move unless engaged in combat).
- Movement speed matches the player's current movement speed.

### US-C04: Companion Threat Management

**Story:** As a player, I want tank companions to maintain aggro and non-tank
companions to manage their threat, so that combat functions like a real group.

**Acceptance Criteria:**
- Warrior/Paladin/Shadowknight companions generate extra threat (taunt,
  high-hate spells)
- Non-tank companions delay engagement slightly (0.5-1 second) to let the
  tank establish aggro
- Healers generate heal aggro as normal, but tank companions compensate
  with taunt
- If a non-tank companion pulls aggro, they continue fighting (no
  aggro-dump AI behavior) but tank companions will attempt to taunt off
- Companions do not pull mobs that the player hasn't engaged (unless
  aggressive stance)

**Design Notes:**
- Threat management uses the existing EQEmu hate list system. Tank companion
  AI calls `Mob::AddHate()` with high values, matching the Merc tank pattern.
- The engagement delay for non-tanks is implemented as a timer in the AI
  process loop — don't cast offensive spells until N ticks after combat start.

---

## Category 3: Growth & Leveling

### US-G01: Companion XP Accumulation

**Story:** As a player, I want my companions to gain experience from kills
we make together, so that they grow stronger over time as we adventure.

**Acceptance Criteria:**
- When the group kills a mob and XP is distributed via `Group::SplitExp()`,
  each active (alive, not suspended) companion receives 50% of a full group
  member's share
- The 50% rate is configurable via a new rule `Companions:XPSharePct`
  (default 50)
- Companion XP is tracked in `companion_data.experience` (new BIGINT column)
- Companions cannot gain XP while dead, suspended, or in passive stance
  during the kill
- The companion's XP contribution to the group divisor is unchanged — they
  count as a full member for XP split purposes (the 50% rate affects what
  THEY receive, not how the pool is divided)
- XP gained is visible to the player via companion dialogue: on significant
  milestones, the companion may comment (LLM-generated)

**Design Notes:**
- The XP hook is added to `Group::SplitExp()` in `zone/exp.cpp`. After the
  player XP calculation, iterate companions in the group and call
  `Companion::AddExperience(xp * XPSharePct / 100)`.
- XP thresholds use the same level table as players. This means companions
  level at player-appropriate rates (adjusted by the 50% share).
- The lost 50% is intentional: it represents the cost of AI party members
  and incentivizes human grouping.

### US-G02: Companion Level-Up

**Story:** As a player, I want my companion to level up when they accumulate
enough experience, so that they become measurably stronger and gain new
abilities.

**Acceptance Criteria:**
- When companion XP reaches the threshold for the next level (from player
  level XP tables), the companion levels up
- Level-up triggers:
  1. Level display updates (visible in group window)
  2. Stats recalculate using linear scaling:
     `scaled_stat = base_stat * (new_level / recruited_level)`
  3. Max HP and max mana recalculate using the same formula
  4. Spell list refreshes — `LoadCompanionSpells()` is called with the
     new level, potentially unlocking new spells
  5. Current HP and mana are fully restored (level-up heal)
  6. A level-up message is sent to the owner: "[Companion name] has reached
     level [N]!"
- Companions cannot level above `player_level - 1`
- When the companion reaches `player_level - 1`, excess XP is discarded
- Level-up is immediate — no "training" step required

**Design Notes:**
- `Companion::AddExperience()` checks for level-up threshold after adding XP.
  If threshold is met, calls `Companion::LevelUp()`.
- `Companion::LevelUp()` calls `Companion::RecalculateStats()` which applies
  the linear scaling formula to all base stats from the original `npc_types`
  entry. The original stats are stored at recruitment time as the baseline.
- The `recruited_level` is stored in `companion_data` (new column) and never
  changes. It is the denominator in the scaling formula.
- New fields needed in `companion_data`: `experience BIGINT`, `recruited_level
  TINYINT UNSIGNED`.

### US-G03: Stat Scaling on Level-Up

**Story:** As a player, I want my companion's stats to scale proportionally
as they level, preserving their original identity (a strong guard stays
strong, a wise cleric stays wise).

**Acceptance Criteria:**
- All base stats (STR, STA, DEX, AGI, INT, WIS, CHA) scale linearly:
  `stat = original_stat * (current_level / recruited_level)`
- Max HP scales linearly: `max_hp = original_hp * (current_level /
  recruited_level)`
- Max mana scales linearly (for caster classes):
  `max_mana = original_mana * (current_level / recruited_level)`
- AC scales linearly
- Attack and damage scale linearly but are subject to level-appropriate
  soft caps for the companion's class
- Resists scale linearly
- The global `StatScalePct` rule is applied after scaling:
  `final_stat = scaled_stat * StatScalePct / 100`
- Stat changes are reflected immediately in combat performance
- Equipment bonuses (from US-E01) are added ON TOP of scaled base stats

**Design Notes:**
- The original stats at recruitment time are stored in the companion's
  data (either a snapshot in a new table or preserved in the companion_data
  row). These never change — they are the baseline for all scaling.
- `Companion::RecalculateStats()` is called on: level-up, equipment change,
  unsuspend, zone-in, and rule reload.
- The scaling formula is intentionally simple. Complex diminishing returns
  or stat curve fitting would add unpredictable behavior. Linear scaling
  is predictable and tunable.
- **Expected stat ranges for testing:** A level 10 NPC with 150 base STR
  recruited at level 10 would reach: ~480 STR at level 32 (3.2x), ~720 STR
  at level 48 (4.8x), and ~960 STR at level 64 (6.4x) — all before
  StatScalePct. These values are comparable to end-game NPC stats in the
  database and should not be gamebreaking. If they prove too high in
  playtesting, StatScalePct (default 100) can be lowered to 80-90% as a
  global dampener.

### US-G04: Spell List Updates on Level-Up

**Story:** As a player, I want my companion to learn new spells as they level
up, so that a level 30 cleric has better heals than they did at level 20.

**Acceptance Criteria:**
- When a companion levels up, `LoadCompanionSpells()` is called with the
  new level
- The `companion_spell_sets` table is filtered by `class_id` and `min_level
  <= current_level <= max_level`
- New spells become available as the companion crosses level thresholds
- Old spells are replaced by upgraded versions (e.g., Heal -> Greater Heal)
- The companion immediately begins using new spells in combat
- Spell effectiveness scales with the companion's level (caster level =
  companion level for all spell calculations)
- The `SpellScalePct` rule provides an additional scaling factor

**Design Notes:**
- The `companion_spell_sets` table uses min_level/max_level ranges. A cleric's
  level 1-19 entry might include Minor Healing; the level 20-38 entry includes
  Healing; level 39+ includes Greater Healing. On level-up past 20, the old
  heal is replaced.
- Priority values in the spell set determine which spell the AI prefers when
  multiple options are available at the same level.

---

## Category 4: Equipment & Gearing

### US-E01: Trade Items to Companion via Trade Window

**Story:** As a player, I want to give equipment to my companion using the
standard trade window, so that I can improve their combat effectiveness with
gear I find.

**Acceptance Criteria:**
- Player targets their own companion and initiates a trade (standard EQ
  trade window — press Trade hotkey or right-click trade)
- Player places items in the trade window and clicks "Give"
- The companion evaluates each item:
  - If the item is equippable (matches companion's class and race from
    item table restrictions), it is equipped in the appropriate slot
  - If the item replaces existing equipment, the old item is returned to
    the player's inventory
  - If the item is not equippable, it is returned to the player with
    message: "[Companion name] cannot use this item."
- Equipment is stored in `companion_inventories` table
- Equipment persists across zones, sessions, suspension, and dismissal
- Only the companion's owner can trade with them

**Design Notes:**
- The trade window is intercepted in `Companion::FinishTrade()`, adapted
  from `Bot::PerformTradeWithClient()`.
- Item slot assignment follows the same logic as Bot equipment: primary
  slot check based on item type (1H weapon -> primary hand, armor -> body
  slot matching item type).
- The Titanium client trade window is standard EQ UI — works with any NPC.
  No custom UI needed.

### US-E02: Equipment Stat Contribution

**Story:** As a player, I want equipment I give to my companion to actually
improve their stats, so that gearing them is meaningful.

**Acceptance Criteria:**
- Equipped items contribute their stat bonuses to the companion:
  AC, HP, mana, STR, STA, DEX, AGI, INT, WIS, CHA, attack, resists
- Stats from equipment are added ON TOP of the companion's scaled base stats
- Weapon items change the companion's attack damage and speed
- Stats are recalculated whenever equipment changes
- The stat contribution is visible in combat performance (more HP, harder
  hits, better heals)
- Equipment does not affect the companion's level or XP gain

**Design Notes:**
- `Companion::CalcItemBonuses()` sums stat contributions from all equipped
  items. Called during `RecalculateStats()`.
- Weapon damage uses the item's `damage` and `delay` fields, replacing the
  NPC's base melee damage values from `npc_types`.
- This is adapted from `Bot::CalcItemBonuses()` which already handles
  all item stat types.

### US-E03: Equipment Visual Changes

**Story:** As a player, I want to see my companion wearing the equipment I
give them, so that gearing them has visible impact.

**Acceptance Criteria:**
- When a companion equips armor, their visible appearance changes to reflect
  the new equipment (chest armor, helm, gloves, etc.)
- When a companion equips a weapon, it is visible in their hand(s)
- Appearance updates are sent to all nearby players via `OP_WearChange`
- Only humanoid NPC models render equipment visually — non-humanoid
  companions (if any) get stat benefits but no visual change
- Armor tinting from items is reflected (if the item has tint data)

**Design Notes:**
- `Companion::SendWearChange()` sends the equipment texture update, adapted
  from `Bot::SendWearChange()`.
- The Titanium client renders equipment on NPC models the same way it renders
  equipment on player models, as long as the NPC uses a playable race model.
- NPCs with non-playable race models (e.g., skeleton, elemental) cannot
  render equipment visually. Stat benefits still apply.

### US-E04: Retrieve Equipment from Companion

**Story:** As a player, I want to take equipment back from my companion before
dismissing them, so that I can reclaim valuable items if needed.

**Acceptance Criteria:**
- Player targets their companion and says "give me [slot]"
  (e.g., "give me your weapon", "give me your armor")
- Player can also say "give me everything" to retrieve all equipped items
- Player can say "show equipment" to list the companion's currently equipped
  items by slot (response via say/tell)
- Retrieved items are placed in the player's inventory
- If the player's inventory is full, the item is not removed and a message
  is displayed: "Your inventory is full."
- The companion's stats are recalculated after equipment removal
- Visual appearance updates to reflect removed equipment

**Design Notes:**
- The say commands are handled by the companion management section
  of `global_npc.lua`.
- The standard EQ trade window does NOT support browsing the other party's
  equipped items — it only shows items placed in trade slots. Therefore,
  say commands are the primary mechanism for equipment retrieval, matching
  the Bot system's `^inventory` command pattern.
- The trade window remains the mechanism for GIVING items (US-E01). This
  story covers RETRIEVING items, which requires the say command approach.

### US-E05: Equipment Persistence Across Dismissal

**Story:** As a player, I want my companion to keep their equipment when I
dismiss them, so that when I re-recruit them later they still have everything
I gave them.

**Acceptance Criteria:**
- When a companion is voluntarily dismissed, their equipment persists in
  `companion_inventories` (linked to `companion_data.id`)
- When re-recruited, the companion spawns with all their stored equipment
- Equipment contributes to the companion's stats immediately on re-recruitment
- The companion's visual appearance reflects stored equipment on spawn
- If the companion suffers a soul wipe (permanent death), their equipment
  is destroyed along with all other companion data

**Design Notes:**
- This is the natural consequence of Decision 2 (items persist on dismissal).
- The `companion_inventories` table is linked to `companion_data.id`, not
  to a session. As long as the companion_data row exists, equipment persists.
- Soul wipe deletes the `companion_data` row and cascading delete removes
  the `companion_inventories` entries.

---

## Category 5: Long-term Persistence & Soul

### US-P01: Lifelong Companion Journey

**Story:** As a player, I want to keep a companion for my entire adventure
from level 10 to level 65, watching them grow and develop alongside me, so
that I have a meaningful long-term relationship with an NPC.

**Acceptance Criteria:**
- A companion recruited at level 10 can remain with the player through all
  content up to level 65 (Luclin cap)
- The companion levels up via shared XP (see US-G01/G02), eventually
  reaching level 64 (player_level - 1 cap)
- The companion's stats scale proportionally (see US-G03) so they remain
  combat-viable at all levels
- The companion's spell list updates as they level (see US-G04)
- ChromaDB memories accumulate across the entire journey — the companion
  remembers dungeons explored, bosses fought, zones visited
- The companion can be equipped with progressively better gear (see US-E01)
- The companion's dialogue evolves via LLM using accumulated memory context
- Companion-type NPCs develop warmer, more personal dialogue over time
- The companion survives server restarts, zone transitions, and logouts

**Design Notes:**
- This is the flagship use case. Everything else supports it.
- The `companion_data` row stores: current level, experience, recruited_level,
  base stats snapshot, equipment (via companion_inventories), stance, and
  all metadata needed for reconstruction.
- ChromaDB stores conversation history keyed by `npc_{npc_type_id}` with
  `player_id` metadata. This persists independently of companion_data.
- Long-term tracking fields (see US-P02) feed the LLM context to enable
  rich reflective dialogue.

### US-P02: Companion History Tracking

**Story:** As a player, I want my companion to reference our shared history
in conversation, so that they feel like a character who remembers our journey.

**Acceptance Criteria:**
- The system tracks per-companion statistics in `companion_data`:
  - `total_kills INT` — lifetime kills while in the party
  - `zones_visited TEXT` — JSON array of zone IDs visited together
  - `time_active INT` — total seconds spent as an active companion
  - `times_died INT` — death count
  - `recruited_at DATETIME` — original recruitment timestamp
- These stats are passed to the LLM as context when the player talks to
  the companion
- The LLM uses this context to generate history-aware dialogue:
  - "We have fought through Blackburrow, Permafrost, and the Hole together."
  - "You brought me back from death in Unrest. I have not forgotten."
  - "Forty days we have traveled. I barely remember my post in Qeynos."
- Stats update in real-time as events occur (kills increment, zone list grows)

**Design Notes:**
- Zone tracking uses a JSON array in a TEXT column. On each zone transition,
  the companion's zone list is checked — if the new zone isn't in the array,
  it is added. This produces a unique list of all zones visited.
- The LLM context template for long-term companions includes a "shared history"
  block built from these stats. The template converts raw numbers into
  natural language prompts.

### US-P03: Memory Continuity Across Zones and Sessions

**Story:** As a player, I want my companion to remember our conversations
across zone transitions and play sessions, so that our relationship develops
continuously.

**Acceptance Criteria:**
- ChromaDB conversation memories persist across:
  - Zone transitions
  - Server restarts
  - Player logouts and logins
  - Companion suspension and unsuspension
  - Voluntary dismissal and re-recruitment
- When talking to a companion, the LLM system retrieves relevant past
  conversations from ChromaDB as context
- The companion can reference past conversations naturally:
  - "You asked me about the gnolls last time. They are worse now."
  - "In Blackburrow, you said we would end the raids. We did."
- Memory is keyed by `npc_{npc_type_id}` + `player_id` — the same NPC
  always has the same memory with the same player

**Design Notes:**
- ChromaDB already handles this. The conversation memory system from
  npc-llm-phase3 stores all dialogue interactions persistently. No new
  code is needed for basic memory continuity.
- The companion system just needs to ensure that the NPC's `npc_type_id`
  is preserved across all lifecycle events (zone, suspend, dismiss) so
  that ChromaDB lookups find the correct memories.

### US-P04: Companion Identity Evolution

**Story:** As a player, I want my long-term companion's identity to naturally
evolve from their original role, so that a Qeynos guard who has traveled
across Norrath feels different from one who just left his post.

**Acceptance Criteria:**
- The LLM context for long-term companions (time_active > threshold) includes
  identity evolution prompts:
  - Early (0-10 hours active): NPC references their original role frequently.
    "I miss the south gate sometimes." Formal, new-to-adventure tone.
  - Mid (10-50 hours): NPC begins identifying as an adventurer. "The road
    suits me better than the wall." References to past adventures mix with
    original identity.
  - Late (50+ hours): NPC has fully embraced their new life but carries the
    tension of their old identity. "The south gate is someone else's problem
    now." or "I serve better out here than I ever did on that wall." But
    personality core (soul elements) remains constant — a warm guard stays
    warm, a stern guard stays stern.
- Evolution is gradual and driven by time_active, not sudden level thresholds
- The NPC's core personality (soul elements) never changes — only their
  relationship to their original role evolves
- Mercenary-type companions evolve differently: they become more pragmatic
  and experienced, but never warm. "Your coin has been sufficient. Continue."

**Design Notes:**
- This is implemented entirely in the LLM context layer. The companion's
  `time_active` value is included in the LLM prompt along with conditional
  personality framing based on the threshold tiers.
- No C++ changes needed. The Lua `companion_culture.lua` module provides
  the evolution context templates.
- The soul element system's static traits remain the personality core. The
  evolution is about the NPC's *self-concept* changing, not their fundamental
  character.

---

## Category 6: Party Management

### US-PM01: Suspend and Unsuspend Companions

**Story:** As a player, I want my companions to automatically suspend when I
log off and restore when I log back in, preserving their state.

**Acceptance Criteria:**
- When the player logs off, all active companions are suspended:
  - Current HP, mana, endurance saved to `companion_data`
  - Active buffs saved to `companion_buffs`
  - Stance and position saved
  - Companions despawn from the world
- When the player logs back in, suspended companions are restored:
  - Companions spawn at the player's location
  - HP, mana, endurance restored from saved values
  - Buffs restored from `companion_buffs`
  - Stance restored
  - Companions auto-join the player's group
- Buff timers continue to tick during offline time (buffs can expire while
  the player is offline)
- Companion data survives server restarts

**Design Notes:**
- This follows the Merc pattern: `Suspend()` saves state to DB tables,
  `Unsuspend()` restores from DB and spawns.
- The companion is set to `is_suspended=1` at the START of suspension (before
  save completes) as a safety measure — if the server crashes during save,
  the companion is in a known safe state.

### US-PM02: Zone Transitions

**Story:** As a player, I want my companions to follow me when I zone, so
that my party stays together across the world.

**Acceptance Criteria:**
- When the player zones, all active companions automatically zone with them
- Companion state is saved before leaving the old zone (HP, mana, buffs)
- Companions spawn at the player's location in the new zone
- State is restored in the new zone (HP, mana, buffs)
- Companions auto-rejoin the player's group in the new zone
- The process is seamless — the player does not need to resummon or
  re-recruit companions after zoning
- Companion history tracking is updated (zone added to zones_visited)

**Design Notes:**
- Uses the Merc zone transition pattern: `ProcessClientZoneChange()` triggers
  `Companion::Zone()` which calls `Save()` then `Depop()`. In the new zone,
  `Client::SpawnCompanionsOnZone()` creates companions from `companion_data`.
- Cross-zone state sync uses `ServerOP_CompanionZone` for world server
  coordination.

### US-PM03: Group Size Management

**Story:** As a player, I want the system to manage group size automatically,
so that adding a human player to a full group does not break anything.

**Acceptance Criteria:**
- Maximum group size is 6 (hard limit from Titanium client)
- Companions occupy standard group slots
- If a new human player joins and the group is full, the most recently
  recruited companion is automatically dismissed
- The auto-dismissed companion gets a farewell message:
  "[Companion name] steps aside to make room."
- The dismissed companion returns to their spawn point with all state
  preserved (can be re-recruited later with all progress)
- The player receives a notification: "[Companion name] has been dismissed
  to make room for [Player name]."
- Human players always take priority over companion NPCs

**Design Notes:**
- The auto-dismiss logic is added to `Group::AddMember()`. When a new
  Client is being added and the group is full, iterate backwards through
  the member list to find the most recently added companion (by
  `recruited_at` timestamp) and dismiss them.
- Dismissed companions go through the standard dismiss flow (companion_data
  preserved with is_dismissed=1).

### US-PM04: Replacement NPC Spawning

**Story:** As a player, I want a replacement NPC to appear at my companion's
original post, so that the world doesn't have holes when I recruit NPCs.

**Acceptance Criteria:**
- When an NPC is recruited, a generic replacement spawns at the original
  NPC's spawn point after a configurable delay (default 30 seconds,
  controlled by `Companions:ReplacementSpawnDelayS`)
- The replacement uses the same NPC type but with a generic name:
  "Guard Noyan" becomes "a Qeynos guard"
- The replacement has the same race, class, level, and appearance as
  the original
- The replacement has NO quest scripts — no LLM dialogue, no say handlers
  beyond default hail response
- The replacement patrols the same grid/path as the original
- When the companion is dismissed (or soul-wiped), the replacement despawns
  and the original NPC respawns at their post
- Only one replacement exists per recruited NPC

**Design Notes:**
- The replacement NPC is spawned using a modified copy of the original's
  NPCType struct (name changed to generic form, quest scripts cleared).
- The original NPC's `spawn2_id` and `spawngroupid` are stored in
  `companion_data` for restoration on dismiss.
- The replacement is tracked via an entity variable on the spawn point
  so that the system knows to clean it up when the companion returns.

### US-PM05: Chat Commands for Companion Management

**Story:** As a player, I want to manage my companions through simple say
commands, so that I can control them without custom UI.

**Acceptance Criteria:**
- All commands are issued by targeting a companion and typing in /say:
  - **"recruit"** (targeting unrecruited NPC): initiate recruitment
  - **"dismiss"** / **"return home"** / **"you're free to go"**: dismiss
  - **"guard here"**: hold position
  - **"follow me"**: resume following
  - **"aggressive"** / **"passive"** / **"balanced"**: set stance
- Commands only work when targeting the correct entity:
  - "recruit" only works on unrecruited, eligible NPCs
  - Management commands only work on the player's own companions
- Each command produces a confirmation message from the companion in
  character (via LLM when possible, or a simple confirmation when LLM
  is not available)
- Unrecognized management commands are passed through to the LLM for
  normal conversation

**Design Notes:**
- Commands are intercepted in `global/global_npc.lua` event_say handler.
  The companion.lua module checks if the target is a companion and the
  speaker is the owner before processing management commands.
- Non-management say text is passed to the LLM for conversation.

---

## Category 7: Death & Consequences

### US-D01: Companion Death in Combat

**Story:** As a player, I want my companion to die when their HP reaches
zero, leaving a corpse that can be resurrected, so that death has stakes
but is recoverable.

**Acceptance Criteria:**
- When a companion's HP reaches 0, they die (standard EQ death mechanics)
- A corpse is created at the death location
- The companion is removed from the group
- A death message is sent to the player: "[Companion name] has fallen!"
- The companion's `times_died` counter increments
- A resurrection timer begins (30 minutes, controlled by
  `Companions:DeathDespawnS`)
- During the resurrection window, the companion can be resurrected by:
  - A player cleric/paladin using resurrection spells
  - Another companion with resurrection capability (cleric/paladin/druid
    companion with appropriate spell level)
- If resurrected within the window, the companion is fully restored:
  rejoins group, retains all level/gear/memories
- The resurrection follows standard EQ resurrection mechanics (XP
  recovery percentage based on spell rank)

**Design Notes:**
- Companion death follows the standard NPC death path (`NPC::Death()`).
  The Companion override adds corpse creation, timer start, and owner
  notification.
- Resurrection uses the existing spell system — resurrection spells target
  corpses and restore the entity.
- The companion's death is a significant emotional event. The LLM system
  can reference deaths in future dialogue: "You brought me back in Unrest.
  I owe you my life."

### US-D02: Soul Wipe on Permanent Death

**Story:** As a player, I understand that if my companion dies and is not
resurrected in time, they are permanently lost — returning to their post
as a complete stranger, so that death carries real emotional weight.

**Acceptance Criteria:**
- If a companion's resurrection timer expires (default 30 minutes) without
  resurrection, the companion suffers a "soul wipe"
- Soul wipe consequences:
  1. The companion corpse despawns
  2. The `companion_data` row is deleted (level, gear, stats, all gone)
  3. The `companion_inventories` entries are deleted (equipped items lost)
  4. The `companion_buffs` entries are deleted
  5. ChromaDB memories for this NPC+player combination are cleared
  6. The original NPC respawns at their home post (replacement NPC despawns)
  7. The NPC is a stranger — no memory of the player, original level,
     default behavior
- The player receives a solemn notification: "[Companion name]'s spirit
  fades. They have returned to [zone name], but the [companion name] you
  knew is gone."
- The player CAN re-recruit the same NPC, but it starts completely fresh:
  - New recruitment roll required (no +10% previous recruitment bonus)
  - Level is the NPC's original database level
  - No equipment
  - No memories
  - No accumulated history
- Soul wipe is IRREVERSIBLE. There is no undo.

**Design Notes:**
- The soul wipe is the emotional core of the death system. It must feel
  significant. The notification text should be somber, not mechanical.
- ChromaDB clearing: the Lua module calls the LLM sidecar with a memory
  wipe request for `npc_{npc_type_id}` + `player_id` metadata.
- This creates the emotional hierarchy:
  - Quick death + resurrection = close call, story moment, bond deepened
  - Soul wipe = genuine loss, grief, starting over
- The 30-minute timer is generous enough that players in a dungeon can
  fight their way back or get a resurrection, but short enough that
  "I'll do it later" risks real consequences.

### US-D03: Resurrection Mechanics

**Story:** As a player, I want to resurrect my fallen companion using
standard EQ resurrection spells, so that death is recoverable if I act
within the time window.

**Acceptance Criteria:**
- Standard resurrection spells (Resurrect, Reviviscence, etc.) work on
  companion corpses
- The resurrection spell must be cast by someone with line of sight to
  the corpse
- Resurrection restores the companion with HP/mana based on the
  resurrection spell's rank (same as player resurrection)
- The resurrected companion automatically rejoins the group
- All companion data is preserved: level, gear, memories, history
- The companion's LLM context includes "you were just resurrected" for
  appropriate dialogue:
  - Companion type: "I... thank you. I was in darkness. I will not
    forget this."
  - Mercenary type: "An acceptable outcome. Our arrangement continues."
- The resurrection timer stops when resurrection is successfully cast
- Multiple companion corpses can exist simultaneously (if multiple
  companions die)

**Design Notes:**
- Resurrection uses the existing spell system. The Companion class overrides
  the corpse's resurrection handler to trigger `Companion::Unsuspend()`
  with restored state rather than standard NPC respawn.
- This is one of the most narratively powerful moments in the system. A
  player desperately getting a resurrection off on their long-time companion
  before the soul wipe timer is a memorable game experience.

---

## Category 8: Mercenary-Specific

### US-M01: Mercenary Faction Retention Check

**Story:** As a player, I understand that mercenary-type companions monitor
my faction standing and may leave if I fail to maintain it, so that the
transactional nature of our arrangement is real.

**Acceptance Criteria:**
- Every `MercRetentionCheckS` seconds (default 600 = 10 minutes), the system
  checks the player's faction with the mercenary's home faction
- If faction has dropped below Warmly (FACTION_WARMLY = 2):
  1. First check: Warning message from the mercenary in character:
     "Our arrangement grows less favorable. Rectify this."
  2. Subsequent check (another 10 minutes later): The mercenary auto-dismisses
     and returns to their spawn point
- The auto-dismiss follows the standard dismiss flow — companion_data
  is preserved with `is_dismissed=1` (can be re-recruited later when
  faction is restored)
- Companion-type recruits NEVER auto-dismiss due to faction changes
- The retention check only applies to mercenary-type companions
  (`companion_type = 1`)
- Faction is checked against the NPC's original `npc_faction_id`

**Design Notes:**
- The retention check is implemented as a timer in `Companion::Process()`.
  Every MercRetentionCheckS seconds, if companion_type=1, check the owner's
  faction with the companion's faction ID.
- The warning state is tracked via an entity variable on the companion
  (`merc_warned`). On first below-threshold check, set warned=true and
  start the departure countdown. On second check, if still below threshold,
  auto-dismiss.
- If faction is restored above Warmly between the warning and departure,
  the warning is cleared: "The arrangement is acceptable once more."

### US-M02: Mercenary Dialogue Tone

**Story:** As a player, I want mercenary-type companions to maintain their
calculating, transactional tone in all interactions, so that the cultural
distinction between companions and mercenaries is always present.

**Acceptance Criteria:**
- Mercenary dialogue NEVER uses these words in an emotional or bonding
  context: loyal, friend, together, bond, cherish, grateful, love, family,
  home, protect, guard
  - "together" is prohibited in emotional usage ("we've been through so
    much together") but permitted in tactical usage ("we advance together,"
    "together we hold the line")
  - "home" is prohibited when referring to the player's company or party
    as home, but permitted when referencing the mercenary's actual home
    city ("Neriak is home," "Cabilis awaits")
  - "protect" and "guard" are prohibited in caring/personal contexts
    ("I will protect you") but permitted in tactical contexts ("guard
    the left flank," "protect the chokepoint")
  - Prohibited terms apply to emotional/relational contexts only. Tactical
    and geographic usage is permitted.
- Mercenary dialogue DOES use: arrangement, contract, terms, satisfactory,
  acceptable, sufficient, noted, advantage, profitable
- On level-up, mercenary dialogue is pragmatic:
  - "This arrangement has been... productive. My capabilities have expanded."
  - NOT: "I've grown stronger with you!"
- On receiving equipment, mercenary dialogue is transactional:
  - "Adequate compensation. These are acceptable tools of war."
  - NOT: "Thank you for the gift!"
- On resurrection, mercenary dialogue is cold:
  - "An acceptable outcome. Our arrangement continues."
  - NOT: "I owe you my life."
- On dismissal, mercenary dialogue is clinical:
  - "Our arrangement concludes. Do not seek me unless you have something
    worth my time."
  - NOT: "I'll miss you."

**Design Notes:**
- All mercenary dialogue constraints are implemented in the LLM context
  layer via `companion_culture.lua`. The LLM system prompt for mercenary
  companions includes explicit word prohibition and tone guidance.
- This is the key differentiator that makes the two recruitment types feel
  distinct. If a Teir'Dal mercenary ever says "my friend," the system
  has failed.

### US-M03: Mercenary Self-Preservation in Combat

**Story:** As a player, I want mercenary-type companions to fight effectively
but with a subtly different survival instinct than loyal companions, so that
their self-interest is mechanically expressed.

**Acceptance Criteria:**
- Mercenary companions have identical combat effectiveness to companions
  (same spell lists, same AI logic, same stats)
- The ONLY mechanical difference: mercenaries in balanced stance have a
  slightly higher self-preservation threshold — they begin to disengage
  when below 20% HP (vs. 10% for companions)
- This means mercenaries are marginally more likely to retreat from a
  losing fight
- In passive and aggressive stances, behavior is identical to companions
- This is a subtle difference, not a punitive one. Mercenaries are still
  fully effective party members.
- The disengagement behavior is expressed differently by culture in LLM
  dialogue:
  - Teir'Dal: cold calculation — "This engagement is no longer favorable."
    Retreats deliberately, with contempt for the situation.
  - Iksar: disciplined withdrawal — disengages silently, repositions. The
    Iksar survives to fight again; retreat is not shame but strategy.
  - Ogre: survival panic — grunts and runs. No internal monologue, no
    tactical reasoning. The Ogre's primitive mind does not calculate odds;
    the body reacts when pain exceeds tolerance.
  - Troll: feral self-preservation — snarls and backs away. Similar to
    Ogre but with more aggression in the retreat.

**Design Notes:**
- The self-preservation threshold is a constant in `companion_ai.cpp`,
  not a rule. It's a narrative touch, not a balance knob.
- The mechanical trigger (20% HP) is identical for all mercenary cultures.
  The difference is purely in how the LLM expresses the disengagement
  through dialogue. The `companion_culture.lua` module provides culture-
  specific retreat dialogue templates.
- This is a "feel" difference. Players may notice that their Teir'Dal
  mercenary backs off with cold words when the fight goes badly, while
  their Ogre mercenary panics and flees, while their Qeynos guard
  companion fights to the death. This reinforces the narrative distinction
  without making mercenaries mechanically worse.
- Ogre framing note: Classic-era Ogres were stripped of intelligence as
  divine punishment for Rallos Zek's assault on the Plane of Earth. An
  Ogre does not have the cognitive capacity for "tactical retreat." The
  same 20% threshold applies, but the in-character expression is primal
  fear, not calculated withdrawal.

---

## Category 9: Re-recruitment and Dismissal Flow

### US-RR01: Voluntary Dismissal

**Story:** As a player, I want to dismiss a companion when I no longer need
them, sending them back to their original post with all their progress
preserved.

**Acceptance Criteria:**
- Player targets their companion and says "dismiss" (or "return home",
  "you're free to go")
- The companion responds with culturally-appropriate farewell dialogue (LLM)
- The companion despawns from the group
- The companion's data is preserved in `companion_data` with `is_dismissed=1`:
  - Level, experience, recruited_level preserved
  - Equipment preserved in `companion_inventories`
  - ChromaDB memories preserved
  - History stats preserved
- The replacement NPC at the original spawn point despawns
- The original NPC respawns at their home location
- The player is notified: "[Companion name] has returned to [zone name]."

**Design Notes:**
- Voluntary dismissal is non-destructive. The companion_data row stays in
  the database. This is the foundation for re-recruitment.
- The original NPC respawns with their database-default stats and behavior.
  They are "back at their post" but changed by their experience (in terms
  of conversation memory via ChromaDB).

### US-RR02: Re-recruit a Dismissed Companion

**Story:** As a player, I want to return to a companion I previously dismissed
and recruit them again with all their progress intact, so that taking a break
from a companion is not permanent.

**Acceptance Criteria:**
- When the player finds the NPC and says "recruit," the system checks
  `companion_data` for a dismissed record matching this npc_type_id and
  owner character_id
- If a dismissed record exists:
  - Recruitment roll gets +10% bonus ("previous recruitment history")
  - No cooldown applies (even if one existed from a past failure)
  - On success, the companion is restored with full state:
    - Level and experience from companion_data
    - Equipment from companion_inventories
    - Stance from companion_data
    - ChromaDB memories already present (never deleted on dismissal)
    - History stats continue from where they left off
  - Companion dialogue on re-recruitment is memory-aware:
    - Companion type: "You came back. I kept your armor polished."
    - Mercenary type: "You again. Our previous arrangement was acceptable.
      I assume the terms are similar."
  - Companion_data.is_dismissed is set back to 0
- If no dismissed record exists, standard first-time recruitment applies
- Re-recruitment still requires faction minimum (Kindly) — you cannot
  re-recruit someone whose faction you've tanked

**Design Notes:**
- The re-recruitment check is: does `companion_data` have a row with
  `owner_id = char_id AND npc_type_id = target_npc_type_id AND is_dismissed = 1`?
  If yes, this is a re-recruitment, not a fresh recruitment.
- The companion spawns at their re-recruited level, not their original
  database level. A dismissed level 40 companion re-recruited later comes
  back at level 40.
- New fields needed in `companion_data`: `is_dismissed TINYINT UNSIGNED
  DEFAULT 0`.

### US-RR03: Soul Wipe Resets the Relationship

**Story:** As a player, I understand that if my companion is soul-wiped (dies
without resurrection), recruiting them again starts completely fresh, so that
permanent death has real consequences.

**Acceptance Criteria:**
- After a soul wipe (see US-D02), the companion_data row is deleted
- If the player later returns to the NPC and says "recruit":
  - No previous recruitment bonus (+10% does NOT apply)
  - Standard full recruitment check applies (faction, persuasion, disposition)
  - Standard cooldown on failure applies
  - If successful, the companion starts fresh:
    - Original NPC level from npc_types
    - No equipment
    - No experience
    - No history stats
    - No conversation memories (ChromaDB was cleared)
  - The NPC does not recognize the player — they are a stranger
  - Dialogue is identical to first-time recruitment
- The player can build the relationship again from scratch, but nothing
  from the previous incarnation carries over

**Design Notes:**
- This is the emotional consequence that gives the soul system weight. A
  player who loses a level 64 companion they've traveled with for months
  feels genuine loss. The NPC is still there, but the person they became
  is gone.
- The clean-slate mechanic also prevents exploit concerns about accumulating
  infinite dismissed companions in the database — soul wipe removes the row.

---

## Story Summary

| Category | Count | Stories |
|----------|-------|---------|
| Recruitment | 7 | US-R01 through US-R07 |
| Combat & AI | 4 | US-C01 through US-C04 |
| Growth & Leveling | 4 | US-G01 through US-G04 |
| Equipment & Gearing | 5 | US-E01 through US-E05 |
| Long-term Persistence & Soul | 4 | US-P01 through US-P04 |
| Party Management | 5 | US-PM01 through US-PM05 |
| Death & Consequences | 3 | US-D01 through US-D03 |
| Mercenary-Specific | 3 | US-M01 through US-M03 |
| Re-recruitment & Dismissal | 3 | US-RR01 through US-RR03 |
| **Total** | **38** | |

---

## Design Decision Summary

| # | Question | Decision | Reasoning |
|---|----------|----------|-----------|
| 1 | Level scaling formula | Linear: `stat = base * (current / recruited)` | Simple, predictable, preserves NPC identity |
| 2 | Equipment on dismissal | Persists on companion | Creates emotional investment; trade to retrieve |
| 3 | Equipment class restrictions | Use existing item race/class flags | Battle-tested, intuitive, no maintenance burden |
| 4 | XP rate for companions | 50% of player share | Companions lag behind player; tunable via rule |
| 5 | Level cap for companions | player_level - 1, no absolute cap | Enables lifelong companion fantasy |
| 6 | Re-recruitment cost | Easier (+10% bonus), full state restore | Supports experimentation; soul wipe is the real cost |
