# Companion Snare AI: Combat Restriction — Product Requirements Document

> **Feature branch:** `feature/companion-snare-ai`
> **Author:** game-designer
> **Date:** 2026-05-03
> **Status:** Draft

---

## Problem Statement

On a 1–3 player server, every companion ability slot matters. Druid, Ranger,
Necromancer, and Shaman companions currently treat their snare-line spells as
a default combat option and re-cast them throughout an engagement. This
behavior is a net negative in active combat for three reasons:

1. **Aggro pollution.** Snare casts generate hate on the companion. The
   player typically wants threat held by the tank (player or another
   companion), not bled off to the support caster.
2. **Mana waste.** Each Ensnare cast is mana that could have funded a heal,
   a damage nuke, or another utility cast. On a small server roster, mana
   efficiency directly determines how long a fight or chain-pull can go.
3. **DPS opportunity cost.** A snare cast slot is a damage cast slot the
   companion did not take. The mob is already pinned in melee — applying
   movement slow to a stationary target adds nothing.

Snare DOES have legitimate value at the very end of a fight when a mob hits
its flee threshold and starts running. The goal of this feature is to keep
that value while eliminating the spam in the other 95% of the encounter.

## Goals

1. **Eliminate snare spam during normal combat.** A snare-capable companion
   in a typical 1–3 player fight should not cast snare while the target is
   above 20% HP, full stop.
2. **Preserve snare's tactical use against fleeing mobs.** When a mob hits
   its flee threshold and starts running, the companion should still be
   able to snare it so the group can finish it without chasing.
3. **Stop wasting casts on resistant targets.** If a target has resisted
   the companion's snare twice in a row in the current engagement, the
   companion gives up on snaring that specific target and goes back to
   doing something useful.
4. **Keep player agency intact.** Direct player commands to the companion
   to snare must continue to work and bypass the AI restriction. The rule
   governs autonomous behavior only.
5. **Provide tunable thresholds.** Server operators should be able to
   adjust the HP threshold and the resist limit without a code change.

## Non-Goals

- Changing root-line spells. Root (immobilize) is a legitimate CC tool
  used deliberately — it is not part of this feature.
- Changing player-character casting. Players can cast snare whenever they
  want; this is companion AI behavior only.
- Changing the existing flee-behavior implementation. We consume flee
  state as a signal; we do not redefine when mobs flee.
- Adding new emotes, dialogue, or flavor text when the companion declines
  to snare. Silence is the desired behavior. (See Lore Considerations.)
- Changing snare resist mechanics or success rates. Snare casts that DO
  fire follow the existing resist math.
- Changing companion AI for spell choice in any other category (DoTs,
  heals, debuffs, nukes).

## User Experience

### Player Flow — Before vs After

**Before this feature (current behavior):**
1. Player engages a mob with a Druid companion in tow.
2. Druid companion casts Ensnare immediately.
3. Druid companion re-casts Ensnare each time the duration ticks down,
   throughout the entire fight.
4. Each cast pulls partial aggro to the companion, costs ~16 mana, and
   takes a cast slot away from heals/nukes.
5. By the time the mob is at 20% and starting to flee, the companion is
   often low on mana and may not have an Ensnare available when it
   actually matters.

**After this feature:**
1. Player engages a mob with a Druid companion in tow.
2. Druid companion does NOT cast Ensnare. It uses its cast slots for
   damage, heals, or other utility.
3. Mob hits flee threshold and starts running.
4. Druid companion now sees a valid snare target (≤20% HP AND fleeing)
   and casts Ensnare. Mob is slowed, group catches it, kills it.
5. If that snare resisted, companion tries one more time. If the second
   attempt also resisted, companion stops trying to snare that target
   and reverts to other casts. The mob continues to flee unsnared, but
   that is a better outcome than five more wasted mana-costly resists.

### Example Scenario

A duo (player Cleric + recruited Druid companion) is killing giants in
Eastern Karana. They pull a Hill Giant.

- The Cleric tanks (sword and board) while the Druid stays at range.
- Under the OLD behavior, the Druid would Ensnare the giant immediately,
  re-cast Ensnare three or four times during the fight, and at 20% HP
  the giant would already be snared (so the cast at the flee moment is
  redundant). Druid mana is half-gone from snare alone.
- Under the NEW behavior, the Druid never casts Ensnare while the giant
  is above 20%. It nukes and heals instead. At 20% HP the giant flees;
  the Druid casts Ensnare; the giant is slowed; the Cleric catches up
  and finishes it.

Edge case in the same scenario:
- The giant resists Ensnare at flee. Druid tries again — second cast
  also resists. Druid stops trying. Giant continues to flee at full
  speed. Cleric uses Root to lock it down. Druid spends remaining mana
  on damage to finish the kill.

### What the player notices

- Companion casts dramatically fewer snares per fight.
- Companion mana lasts longer.
- Companion holds noticeably less aggro from spell casts.
- When a mob actually flees, the companion still slows it (most of the
  time) — the moment the snare matters most.
- No new combat log spam, no new emotes, no new flavor text. The change
  is felt, not announced.

## Game Design Details

### Mechanics

**The Snare Restriction Rule (autonomous AI only):**

A snare-capable companion may autonomously cast a snare-line spell on a
target during active combat ONLY if BOTH of the following are true:
- The target's current HP is at or below 20% of its maximum HP.
- The target is currently in flee behavior.

If either condition is false, the companion does not autonomously cast
snare on that target.

**Out-of-combat behavior:**

The rule does not apply outside of active combat. Companions may snare
freely during pulls, kiting setups, pre-engagement positioning, or any
other non-active-combat scenario. The rule activates only when the
companion is engaged with the target it would snare.

**The Resist Counter:**

A per-(companion, target) counter tracks how many of the companion's
snare-line casts have been resisted on that target during the current
engagement.

- Counter increments only on a full resist of the snare-line cast.
- Counter does NOT increment on a successful land that was later
  dispelled, cured, faded, or expired.
- When the counter reaches 2, the companion stops attempting snare on
  that target for the remainder of the engagement.
- The counter is fresh for each new engagement (target re-aggro
  counts as a new engagement) and fresh for each new target.

**Manual command override:**

Direct player commands to the companion (the existing companion command
interface — the architect should confirm exact mechanism) bypass the
restriction. If a player explicitly commands the companion to snare,
the companion attempts to snare regardless of HP/flee state and
regardless of the resist counter. The override applies only to that
specific commanded cast — the autonomous AI rule resumes immediately
afterward.

### Classes Affected

Every companion class with a snare-line spell in its repertoire is in
scope:

| Class | Notes |
|-------|-------|
| Druid | Primary offender — Ensnare is a foundational snare spell |
| Ranger | Inherits Druid snare line |
| Necromancer | Has snare-line spells in its arsenal |
| Shaman | Has snare-line spells in its arsenal |

The rule applies uniformly across all four. Spell selection within the
snare line (lower vs higher tier snare) is unchanged — only the gating
condition changes.

### Tunable Rules (recommended)

The architect should expose two values via the existing `rule_values`
system:

| Recommended Rule Name | Default | Purpose |
|-----------------------|---------|---------|
| `Companions:SnareHpThreshold` | 20 | Target HP percentage at or below which companions are allowed to autonomously snare. Server operators can tune up (looser rule, e.g., 30) or down (stricter, e.g., 10). |
| `Companions:SnareResistLimit` | 2 | Number of consecutive resists on a target after which the companion stops attempting snare on that target for the engagement. Set to 0 to disable the resist counter entirely; set to 99+ to effectively disable the cap. |

(Rule names are recommendations — the architect should select naming
that matches existing `Companions:*` rule conventions in the codebase.)

### Balance Considerations

**Why this works for 1–3 players:**

The rule is strictly a buff to companion effectiveness. It eliminates a
known-bad behavior (snare spam) without removing any meaningful tactical
option. Companions become more mana-efficient, which directly extends
how long a small group can chain-pull. There is no scenario where a
1-player or 2-player group is *worse off* under this rule than under
current behavior.

**Why this won't trivialize content:**

The rule does not buff snare's effect, success rate, or duration. It
does not give companions any new spell. It only removes wasted casts.
Encounters that demand snare CC (e.g., training a fleeing mob into
adds) still rely on the player's own snare or root, or on the player
issuing an explicit command to the companion.

**Edge cases — design intent:**

| Situation | Intended Behavior |
|-----------|-------------------|
| Mob is healed back above 20% after companion snared it | Companion does not refresh the snare during the heal-up window. If the mob drops to ≤20% AND is fleeing again, snare may re-fire (subject to resist counter). |
| Mob enters flee behavior at >20% HP (scripted flee, fear effect, quest-driven) | Both conditions must be true. ≤20% AND fleeing. So scripted flee at 80% HP does not trigger snare under the rule. (Player can still issue manual command if desired.) |
| Mob is at 15% HP but NOT fleeing (e.g., calm-temperament mob, or flee disabled) | Both conditions must be true. No autonomous snare. |
| Existing snare on the target lands, then is dispelled or fades | Resist counter does not increment (no resist occurred). Companion may attempt to re-cast if conditions are still met (≤20% AND fleeing). |
| Snare lands successfully but breaks early due to damage | Treated as a successful land that ended; not a resist. Same behavior as fade — no counter increment. |
| Two snare-capable companions in the same group | Each companion has its own per-target resist counter. Companion A reaching the 2-resist cap on a target does not stop Companion B from trying. |
| Companion swap mid-fight (player dismisses one, recruits another) | The new companion has a fresh resist counter for any target. |
| Multi-mob fight | Counter is per (companion, target). Resists on Mob A do not affect snare attempts on Mob B or Mob C. |
| Mob de-aggros and resets, then is re-pulled later | New engagement → fresh resist counter. |
| Player explicitly commands the companion to snare a target above 20% HP that isn't fleeing | Manual command overrides the rule. The cast attempts. (Architect to confirm command path bypasses AI gates.) |

### Era Compliance

- All snare-line spells referenced are Classic-through-Luclin era (Ensnare,
  Snare, etc.). No post-Luclin spell content is introduced.
- No new spells, no new spell IDs, no new icons. Spell data is unchanged.
- Lore-master sign-off recorded in `agent-conversations.md`.

### Lore Considerations

This is a behavior tuning change with no narrative surface area. There is
no NPC dialogue, no quest text, no zone content, no faction interaction.

Recommendation (confirmed with lore-master): no flavor text or emote when
the companion declines to snare. Silent suppression. Adding combat-log
emotes would replace one form of spam with another.

## Affected Systems

- [x] C++ server source (`eqemu/`) — companion AI cast decision logic
- [ ] Lua quest scripts (`akk-stack/server/quests/`)
- [ ] Perl quest scripts (maintenance only)
- [ ] Database tables (`peq`)
- [x] Rule values — two new tunable rules recommended
- [ ] Server configuration
- [ ] Infrastructure / Docker

(Architect to validate exact files. Companion AI lives in `eqemu/zone/`
based on existing project topography; the lua_companion binding is a
known interaction surface but the gate may live entirely in C++.)

## Dependencies

None. This feature stands alone. It depends only on existing systems:
- Existing companion AI cast-decision pathway
- Existing flee-behavior tracking on NPCs
- Existing target HP percentage calculation
- Existing snare-line spell categorization (presumably already a
  spell-effect or spell-category lookup)
- Existing resist event signal from the spell casting code
- Existing `rule_values` system for the two tunables
- Existing companion command pathway (for the manual override case)

## Open Questions

These are the architect's to answer during the architecture phase. Several
are carried forward from the brief:

1. **Companion command override mechanism.** Does the existing companion
   command path (player explicitly telling the companion to snare a
   specific target) bypass autonomous AI gates today? If yes, we get
   the override "for free." If no, the architect should determine
   whether plumbing a bypass is in scope or whether it warrants a
   follow-up feature.
2. **Where the gate sits.** Where in the companion AI decision tick is
   the cleanest place to insert the snare gate, such that snare is
   suppressed without affecting other casts in the same decision pass?
3. **Snare-line spell classification.** Is there an existing
   spell-effect ID, spell-category enum, or tag that already identifies
   "movement-slow snare-line" cleanly? If not, what is the architect's
   preferred way to identify these spells (effect ID list, spell-skill
   lookup, etc.)?
4. **Flee-state observability.** Where does the AI tick already access
   the target's flee state? If it doesn't, what is the cheapest read
   path (entity flag, NPC method, fear state machine)?
5. **Resist-event hookup.** What signal does the companion AI receive
   when a cast resists? Is it a callback, a return value from the cast
   call, or something polled? The resist counter depends on this.
6. **Per-target counter storage.** Where should the per-(companion,
   target) resist counter live? On the companion entity? On the AI
   state struct? In a transient map keyed by target ID? Architect
   choice.
7. **Engagement boundary definition.** What constitutes "the same
   engagement" for resetting the resist counter? Aggro-list membership
   is one option; "current target" change is another. The architect
   should pick the cleanest boundary that gives the player the
   intended experience.
8. **Rule-values naming convention.** Does the project already use a
   `Companions:*` namespace for companion-specific rules? If yes, use
   it. If no, follow whichever convention is closest.

## Acceptance Criteria

These are observable in-game scenarios. Game-tester validates each.

- [ ] **AC-1: No snare during normal combat.** Player engages a 100% HP
  mob with a Druid companion. The Druid does NOT cast Ensnare or any
  other snare-line spell while the mob is above 20% HP and not fleeing.
  Verified across at least 3 separate engagements lasting at least 60
  seconds each.
- [ ] **AC-2: Snare fires at flee threshold.** Player engages a mob.
  Mob hits flee threshold (drops to flee HP and starts running). The
  Druid companion casts Ensnare on it within a reasonable AI tick window
  (e.g., 2–3 ticks). Mob is snared.
- [ ] **AC-3: Two-resist cutoff.** Player engages a mob with high
  magic resist. At flee threshold, Druid casts Ensnare — resists.
  Druid casts again — resists. Druid does NOT cast Ensnare on that
  target again for the rest of the engagement, even though the mob
  remains ≤20% AND fleeing.
- [ ] **AC-4: Counter resets on new target.** During a chain-pull,
  Druid hits the 2-resist cap on Mob A. Mob A dies. Player pulls
  Mob B. At Mob B's flee threshold, Druid casts Ensnare on Mob B
  (counter for Mob B is fresh). If Mob B resists once, Druid may
  attempt one more time before capping out for Mob B.
- [ ] **AC-5: Multi-mob isolation.** In a multi-mob fight, Druid
  caps out on Mob A (2 resists). Mob B reaches flee threshold during
  the same fight. Druid casts Ensnare on Mob B (Mob B's counter is
  fresh).
- [ ] **AC-6: All four classes obey the rule.** Repeat AC-1 and AC-2
  with a Ranger companion, a Necromancer companion, and a Shaman
  companion. Each behaves identically with respect to the snare rule.
- [ ] **AC-7: Out-of-combat snare unaffected.** Player commands or
  observes a snare cast outside of active combat (e.g., during a pull
  setup or kite positioning). The companion is willing to snare
  without the 20%/flee gate.
- [ ] **AC-8: Manual command override works.** Player explicitly
  commands the companion to snare a target above 20% HP that is not
  fleeing. Companion attempts the cast (subject to mana, range, line
  of sight — same as any normal forced cast). The autonomous rule
  resumes for subsequent ticks. (Pending architect confirmation that
  manual command currently bypasses AI gating.)
- [ ] **AC-9: Root spells unaffected.** A Necromancer companion's
  root behavior is identical before and after the change. Root casts
  fire under the same conditions they always have.
- [ ] **AC-10: Player snare unaffected.** A player Druid casting
  Ensnare on any target works exactly as before. The rule does not
  touch player-character casting.
- [ ] **AC-11: Tunables work.** Setting `Companions:SnareHpThreshold`
  to 30 causes the gate to activate at 30% HP instead of 20%. Setting
  `Companions:SnareResistLimit` to 1 caps the companion at 1 resist
  per target.
- [ ] **AC-12: Mana savings observable.** Compare a Druid companion's
  mana pool at fight-end across 5 fights pre-change vs post-change.
  Post-change mana pools should be visibly higher on average due to
  saved snare casts. (Sanity check, not a hard pass/fail.)

---

## Appendix: Technical Notes for Architect

These are advisory pointers to help the architect orient. The architect
makes all implementation decisions.

**Suggested rule names** (if `Companions:*` namespace is the established
convention):
- `Companions:SnareHpThreshold` (default 20)
- `Companions:SnareResistLimit` (default 2)

**Likely identification of snare-line spells:**
- Snare-line spells share a movement-slow effect (the same effect ID
  family used by spells that reduce target run speed). The architect
  should verify the cleanest classification path — by effect ID, by
  spell-skill, or by spell-category. This is the "what counts as a
  snare?" question.
- Root-line spells (immobilize, full stop) use a different effect.
  The classification must NOT pick up roots.

**Per-target counter lifetime:**
- The simplest mental model: a small map on the companion entity
  keyed by target entity ID, value is the per-engagement resist
  count. Cleared on engagement end (target dies, target despawns,
  companion changes target).
- The architect may prefer to attach this to whatever existing
  per-target tracking the companion AI already has (hate list
  entries, target memory, etc.).

**Manual command path:**
- The brief flags this as architect-to-confirm. If the existing
  companion command pathway already routes around AI cast-selection
  gates, the override requires no additional work. If not, the
  architect should scope the bypass.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
