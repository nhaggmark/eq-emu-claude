# companion-experience — Lore Notes

> **Feature branch:** `bugfix/companion-experience`
> **Author:** lore-master
> **Date started:** 2026-03-05

---

## Feature Concept

This feature addresses two related systems:

1. **XP sharing fix (BUG-001):** When a companion NPC lands the killing blow,
   the player and companion should both receive experience as if it were a
   normal group kill. Currently the post-death hooks do not fire correctly
   when a companion lands the kill.

2. **Companion leveling:** Companions accumulate experience and level up
   alongside their owner. The `companion_data` table already has `level`,
   `experience`, and `recruited_level` columns, indicating the infrastructure
   for this was partially planned.

Lore implication: this feature asks us to accept that NPCs of Norrath can
grow in power through shared combat experience. The existing companion system
already commits to this premise through its faction/disposition recruitment
gates; XP and leveling extend it naturally.

---

## Lore Research

### Zones

This feature is not zone-specific. It applies universally to any zone where
a companion is active. No zone-specific lore research is required unless
the PRD proposes zone-restricted leveling mechanics.

### NPCs & Characters

This feature is not tied to specific named NPCs. No individual NPC lore
review required unless the PRD proposes named-NPC examples that need
verification.

### Factions

| Faction | Notes |
|---------|-------|
| All factions | Recruitment already requires Kindly+ standing. Leveling does not change faction standing directly. If the PRD proposes faction rewards from companion leveling milestones, that requires review before approval. |

### Deities & Races

**Beastlord / Vah Shir (Luclin era):**
The most relevant canonical precedent for companion leveling within the era
is the Beastlord class introduced in Shadows of Luclin. Beastlord warders
scale in power with their owner through a spiritual bond forged in battle.
This is the in-era model for a persistent companion gaining capability
alongside a player. The companion system achieves the same outcome through
mutual combat experience rather than magical binding.

**Racial persuasion stat table:**
The recruitment system already uses race-specific persuasion stats (STR for
warrior-type races such as Barbarian, Ogre, and Troll; INT for caster races
such as Erudite and Gnome; CHA as default). This reflects genuine cultural
differences in how different races respond to leadership. The leveling
mechanic must not flatten these distinctions. Dialogue flavor for level-up
acknowledgment should vary by race and class — handled through the LLM
sidecar, but the PRD should not propose one-size-fits-all level-up lines.

**Froglok exclusion:**
Already hard-coded in companion.lua (races 74 and 330 excluded). This is
correct. Frogloks do not exist as a free, recruitable race in Classic-Luclin.
They appear as enslaved NPCs in Kunark (Guk, Lower Guk) but are not freed
until Planes of Power — post-era lock. This exclusion must be maintained in
any new documentation, design examples, or dialogue.

**Iksar (Kunark era):**
Iksar NPCs can be companions (no exclusion). Iksar lore emphasizes individual
strength earned through hardship and combat. A Scaled Mystic or Iksar warrior
companion growing stronger through shared battle is entirely consistent with
Iksar cultural values.

**Teir`Dal (Dark Elf):**
A Teir`Dal companion is serving their own ambitions. They grow more capable
because capability serves their goals — not out of loyalty. Level-up
dialogue for a Dark Elf companion should reflect cold ambition or growing
power, not warmth or gratitude.

**Vah Shir (Luclin era):**
Vah Shir honor bonds between warriors who fight together. Growth through
shared combat is a core cultural value. A Vah Shir companion acknowledging
increased power frames it as honorable growth, not celebration.

### Historical Context

**Power growth in Norrath:**
EverQuest does not explain "experience points" as an in-world phenomenon.
Power growth through combat and hardship is an accepted abstraction across
all Classic-Luclin eras. No lore contradicts NPCs growing stronger through
the same means as player characters.

**Companion disposition system (existing):**
The disposition system (Eager / Restless / Curious / Content / Rooted) is
already a lore-consistent framing. Restless and Eager NPCs are those
dissatisfied with their current existence and seeking more. They are the
ones most likely to grow through adventure. An NPC disposition of Rooted
(already -30% recruitment chance) is canonically an NPC who belongs where
they are — they would not seek power through adventuring. This framing
supports companion leveling without any lore adjustment.

**Companion_data schema (existing):**
The table already has `level`, `experience`, and `recruited_level` columns.
The leveling infrastructure was partially planned from the start. This is
not a new lore commitment — it is completing existing design.

---

## Era Compliance Review

| Element | Era | Compliant? | Notes |
|---------|-----|------------|-------|
| XP sharing mechanic | Classic | Yes | Group XP splitting is core Classic; companion XP share is identical in nature |
| Companion leveling 1–60 | Classic–Luclin | Yes | Level 60 cap is consistent with all eras in scope |
| Beastlord warder precedent | Luclin | Yes | Canonical in-era model for a companion scaling with its owner |
| Froglok exclusion | Classic–Luclin | Yes | Correctly excluded; not a free race until PoP |
| companion_data schema | Custom | Yes | Custom table, no era conflict |
| Disposition system framing | Custom (lore-consistent) | Yes | Era-neutral; consistent with NPC characterization across all eras |
| 15 Classic-Luclin classes, no Berserker | Classic–Luclin | Yes | Berserker is post-Luclin; correctly excluded |
| No AA for companions | Luclin | Yes | AA is player-only in era; correct non-goal |
| Spells from era-filtered npc_spells tables | Classic–Luclin | Yes | No post-Luclin spell lines introduced |

**Hard stops — these would violate era lock if they appear in the PRD:**

- **Companion levels exceeding 60.** The Classic-Luclin level cap is 60. Any
  companion level value above 60 is post-era content. (PRD edge case text
  contained a minor error implying player could be level 61+ — flagged and
  correction requested from game-designer.)
- **Mercenary framing or terminology.** Mercenaries were introduced in Seeds
  of Destruction (2008). "Mercenary tier" language must not appear.
- **"Heroic Adventures" or "Partisan" quest terminology.** These are post-PoP.
- **Froglok companions.** Must remain excluded.
- **Companion abilities from post-Luclin spell lines.** Level-up ability gains
  must come exclusively from Classic-Luclin spell tiers.

---

## PRD Section Reviews

### Review: Full PRD — companion-experience (2026-03-06)

- **Date:** 2026-03-06
- **Verdict:** APPROVED WITH NOTES (one fix required before architect handoff)
- **Approved items:**
  - Problem statement and goals: accurate, no lore conflicts
  - XP distribution mechanics (XPSharePct, XPContribute): era-neutral
  - Level cap at player_level - MaxLevelOffset: lore-consistent with follower/leader dynamic
  - No XP loss on companion death: actually more lore-consistent than imposing one
  - 15 Classic-Luclin classes, no Berserker: correct
  - No AA for companions: correct non-goal
  - Spells from era-filtered tables: correct
  - Acceptance criteria: all check out against lore
  - East Karana zone reference: real Classic zone, plausible setup
  - Surefall Glade druid companion: plausible, Surefall druids are accessible from EK area
- **Issues found:**
  - PRD line 279-281: "requires player to be level 61+, which is above the Luclin cap of 65 AAs / level 60" — conflates AAs with character levels; implies player could be level 61+ which is impossible on a Classic-Luclin server. Correction requested: state that this edge case cannot occur because the player level cap is 60.
- **Suggestions offered (non-blocking):**
  - Level-up message tone: "Guard Archus has grown stronger!" — exclamation is post-EQ UI style. EQ observes, it doesn't celebrate. Minimum fix: drop the exclamation mark. Better: have the companion speak it. Suggested the PRD explicitly note that level-up dialogue delegates to the LLM sidecar with class+race context.
  - East Karana gnoll scenario: EK gnolls are typically levels 5-25; a "blue-con level 29 gnoll" is unlikely for a level 30 player. Suggested Kithicor Forest (undead 25-35, excellent ranger lore atmosphere) or specifying Splitpaw-clan gnolls near the EK southeast border.
- **Game-designer response:** All six items incorporated — level-up messaging corrected to terse EQ dialogue with LLM sidecar noted, level 60 hard cap added explicitly in three places and AC-5, era compliance hard stops table added, no structured advancement tiers added as non-goal, Beastlord warder narrative precedent added, Froglok exclusion explicitly stated, example scenario updated to human guard from Highpass garrison / wood elf druid / half-elf ranger.

---

## Decisions & Rationale

| # | Decision | Rationale | Alternatives Rejected |
|---|----------|-----------|----------------------|
| 1 | Companion leveling is lore-consistent within era | Beastlord warder precedent exists in Luclin; disposition system already frames NPCs as having adventuring potential; faction requirement establishes a trust relationship | Rejecting the concept on grounds of "EQ NPCs are static" — this custom server commits to the premise through recruitment mechanics; leveling extends it naturally |
| 2 | Froglok exclusion must be maintained | Frogloks are not a free race until PoP, which is post-era lock | No alternative; this is a hard stop |
| 3 | Level cap of 60 is mandatory | Classic-Luclin level cap; any higher is post-era content | No alternative; this is a hard stop |
| 4 | Level-up dialogue must vary by race/class | EQ characterization is race- and class-specific; one-size-fits-all dialogue breaks immersion and contradicts established NPC personality | Generic "I feel stronger!" lines rejected as tonally wrong for EQ; LLM sidecar handles differentiation |
| 5 | No XP loss on companion death is lore-consistent | NPCs in Norrath do not lose experience when they die — they simply respawn; companions are a middle ground; 30-min despawn is the appropriate consequence | XP loss on companion death would raise unanswerable lore questions about de-leveling |

---

## Final Sign-Off

- **Date:** 2026-03-06
- **Verdict:** APPROVED
- **Summary:** The companion XP sharing and leveling PRD is fully lore-sound.
  All feedback incorporated. Level 60 hard cap is explicit in rule definition,
  edge case section, and AC-5. Level-up messaging uses EQ's terse register with
  companion speaking in character; LLM sidecar handles race/personality variation.
  Era compliance hard stops table added to PRD. Example scenario uses historically
  accurate Classic-Luclin zone references. Froglok exclusion explicitly documented.
  Beastlord warder canonical precedent included. PRD cleared for architect handoff.
- **Remaining concerns:** None. Implementation team should follow the dialogue
  tone reference in Context for Next Phase.

---

## Context for Next Phase

**For the architect:**
- Level 60 is a hard cap. If the companion_data schema or any rule value
  allows levels above 60, flag it and correct it.
- The `companion_data` table already has `level`, `experience`, and
  `recruited_level` columns. Audit these before designing new infrastructure
  around them.
- Faction does not change from the leveling mechanic itself. Do not design
  faction side-effects from companion leveling unless the PRD explicitly
  specifies them and they have been reviewed here.
- The PRD edge case text (line 279-281) contains a minor error about level
  61+ — the game-designer is correcting it. The intent is clear: on this
  server, a companion's absolute max is level 59 (player cap 60 - offset 1).

**For the implementation team:**
- Companion level-up dialogue (via LLM sidecar) must reflect race and class
  personality. A Teir`Dal shadow knight growing in power expresses cold
  ambition, not warmth. A Vah Shir warrior frames it as honorable growth.
  A Gnome notes it analytically.
- Do not add post-Luclin terminology to level-up messages or status displays.
  No "Heroic," "Partisan," "Mercenary tier."
- The level-up notification to the player should be understated. Recommended:
  "Guard Archus has grown stronger. They are now level 25." (no exclamation).
  Better: companion speaks it — "Guard Archus says, 'I have honed my skills.
  I am now level 25.'"
- The !status command displaying level + XP progress should use terse language.
  "Guard Archus — Level 29 (1,234 / 900,000 XP)" is sufficient. No flourish.

**EQ dialogue tone reference:**
EQ NPCs are terse and atmospheric. Level-up acknowledgment follows this pattern:
- Warrior/Knight: "I have honed my skills through our battles."
- Ranger/Rogue: "My instincts have sharpened."
- Wizard/Magician: "My command of the arcane has deepened."
- Shaman: "The spirits speak to me with greater clarity."
- Cleric/Paladin: "My faith has been strengthened through trial."
- Necromancer/Shadow Knight: "I grow more capable. Good."
- On resummon after death: "That battle cost me. I will not fall so easily again."
