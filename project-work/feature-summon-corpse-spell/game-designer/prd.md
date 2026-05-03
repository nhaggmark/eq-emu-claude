# Universal Summon Corpse Spell — Product Requirements Document

> **Feature branch:** `feature/summon-corpse-spell`
> **Author:** game-designer
> **Date:** 2026-05-03
> **Status:** Approved — all lore-master blocking issues resolved; final-pass review request on file

---

## Problem Statement

On a 1–3 player Classic-through-Luclin server, the EverQuest death penalty
remains brutal: the player drops their corpse where they died, must travel
back unequipped, and must reach the corpse's exact location to loot their
gear and recover XP. In retail EQ this was tolerable because the social
fabric of a populated server provided two safety valves:

1. A friendly Necromancer (or Shaman, post-Velious) could cast Summon Corpse
   and pull the corpse to a safe location.
2. Other players could form impromptu corpse-recovery groups for high-risk
   pulls.

Neither of those exists on this server. There is rarely (or never) a second
Necromancer player available, and the companion system cannot reliably
fight its way back into a high-level dungeon to escort a naked, low-level
corpse-runner to their gear. The result is a hard fail-state: a player who
dies deep in Sol B, Velks, or Howling Stones with no means to retrieve
their corpse before it rots is effectively softlocked on that character's
progression for the night, and at worst loses gear to corpse decay.

This feature gives every casting-capable class a free, level-1, low-risk
*Summon Corpse* spell. It does not eliminate the death penalty (XP is still
lost, gear is still unequipped, the player still has to physically reach
the zone), but it removes the catastrophic case of "my corpse is in a place
I cannot reach without dying again."

## Goals

1. **Eliminate corpse-stranding softlocks.** A player who dies anywhere
   in a zone they can re-enter alive must be able to recover their gear
   without help from a second player.
2. **Preserve the death penalty.** XP loss, gear unequip, the trip back
   to the zone, and the resurrection-window decision (rez vs. corpse run)
   all remain unchanged. The spell only affects *where in the zone* the
   corpse can be looted.
3. **Make the spell feel class-appropriate.** Each of the 12 casting
   classes scribes a uniquely-named, lore-flavored spell with the same
   mechanical effect. The player's class identity is honored.
4. **Zero friction acquisition.** New characters can buy the scroll on
   any starting-city class spell vendor for trivial gold. Existing
   characters at the time of the patch get the spell auto-scribed
   silently — no MOTD, no quest, no fetch step.
5. **Cooldown long enough to feel like a planned safety valve, short
   enough that a chained-death scenario is recoverable.** 3 minutes.

## Non-Goals

- **Other players' corpses.** This spell only summons the caster's own
  corpse. Cross-player corpse summoning remains the historical
  Necromancer/Shaman privilege using their existing spells.
- **Companion corpses.** Companions handle their own death/restoration
  loop and do not leave lootable corpses; they are out of scope here.
- **Cross-zone summoning.** Caster and corpse must be in the same zone.
  Cross-zone corpse retrieval requires the player to physically zone in
  first, exactly as today.
- **Changes to XP loss, equipment-on-corpse, resurrection timers, or
  corpse-decay duration.** None of those numbers move.
- **Changes to the existing Necromancer/Shaman cross-player summon
  spells.** Those keep their existing high level, mana cost, reagent,
  and scroll acquisition. Only the new low-level self-summon line is
  added.
- **PvP considerations.** This server is PvE; PvP rule interactions are
  not designed for. If a PvP zone is ever introduced, the spell behavior
  in that zone will be revisited as a separate feature.
- **Melee classes** (Warrior, Monk, Rogue, Berserker — though Berserker
  is post-Luclin and not relevant). The 12 casting classes are the
  scope. Pure melees rely on the same channels they always did
  (companions, the new spell on a grouped caster, the 90-minute corpse
  decay timer to make a second attempt).

## User Experience

### Player Flow — happy path

1. The player creates a new character of any of the 12 casting classes,
   or logs in an existing character of any of those classes after the
   patch deploys.
2. **For new characters:** at any starting-city class spell vendor, a
   new scroll appears in the level-1 inventory. The player buys it for
   the standard nominal copper-piece cost and scribes it like any other
   spell.
3. **For existing characters:** the spell is already scribed in their
   spellbook on first login after the patch. No notification is shown.
4. The player goes adventuring and dies somewhere in a zone — say, deep
   inside Najena, in a room they cannot easily fight back to with no
   gear and no companions.
5. The player is bound at a safer location (Cabilis, Freeport, etc.),
   accepts release-to-bind, and respawns there.
6. The player travels back to Najena and zones in at the entrance.
7. The player memorizes their class's *Summon Corpse* spell, casts it
   (6-second cast, 0 mana, no reagent, no target needed).
8. The corpse appears at the player's feet inside the entrance area.
   The player loots gear, kneels for an in-zone rez if available
   (companion cleric, etc.), and continues their session.

### Player Flow — repeated-death scenario

1. The player dies a second time in the same zone before the cooldown
   expires (within 3 minutes of the first cast).
2. The player attempts to cast the spell and receives the standard "Spell
   recast time not yet met" message that other cooldown-gated spells
   produce.
3. The player either waits up to 3 minutes for cooldown, or proceeds
   to the second corpse manually if it is reachable, or accepts the
   delay.
4. After 3 minutes, the player can cast again and pull the most-recent
   *or any* of their corpses — same behavior as the existing
   Necromancer/Shaman summon line, which pulls one corpse per cast and
   the player chooses which (or it follows the existing engine default —
   see Open Questions).

### Example Scenario

A level 32 Wizard is duo'ing The Hole with a recruited Cleric companion.
The pair pulls a frenzied named mob, the Cleric goes down before they
can mez-pull, and the Wizard is killed 30 seconds later before they can
gate. Both bodies lie in a trash-pulled corner of Echo Caverns interior.

The player respawns at their bind point in Erudin, takes the boat-and-
travel route back, and zones into The Hole. They are level 32, naked,
have a small starter wand from the bank, and have no allies in zone.

In the old behavior they would now have to either: (a) abandon the run
and wait for corpse decay, losing all their gear; (b) try to sneak past
multiple aggressive mobs they cannot fight to reach the corpse; or
(c) park the character for the night and find a Necromancer in /ooc
hoping someone is online.

With this feature, they cast *Spectral Translocation* at the zone
entrance. After the 6-second cast, their corpse appears at their feet.
They loot, re-equip, and now have the choice to either summon the
companion's corpse (separate problem — out of scope) or simply re-recruit
the Cleric NPC and continue. The death penalty (XP loss, the travel
back) was paid in full; the run was salvaged.

## Game Design Details

### Mechanics

| Property | Value |
|----------|-------|
| Spell level | 1 |
| Available to | Cleric, Druid, Shaman, Necromancer, Wizard, Magician, Enchanter, Paladin, Shadow Knight, Ranger, Beastlord, Bard (12 classes) |
| Mana cost | 0 |
| Reagents | None |
| Cast time | 6 seconds |
| Recast (cooldown) | 3 minutes (180 seconds) |
| Target type | Self (no target required) |
| Range | N/A — same zone as caster |
| Effect | Summons the caster's own corpse to the caster's current location |
| Interruptible | Yes — standard cast rules: damage interrupts, movement interrupts, stun interrupts |
| Usable while invis | Yes (the cast itself drops invis as normal) |
| Usable while feigned | No (must stand to cast) |
| Usable while dead | No (the corpse-owner must be alive — see Failure Modes) |
| Usable while sitting | Yes |

The mechanical effect is **identical to the existing Necromancer
*Summon Corpse* line** with the only difference being who can scribe it,
the cost, and the cooldown. Implementation should reuse the existing
engine path (see Appendix).

### Universal In-World Framing — The Compact of the Awakened

Lore rationale (lore-master approved, era-grounded in Luclin):

> Following the discovery of Luclin and study of the Nexus, scholars across
> Norrath documented an ancient rite predating the Combine — a compact
> inscribed on the Nexus stones by the same artificers who bound the Shissar
> to the moon. The compact holds that any mortal who has crossed the
> boundaries of the planes through arcane transit (i.e., has teleported or
> otherwise bent the fabric of the world) carries a resonant mark on their
> body. A sufficiently focused spellcaster can use that resonance as a
> tether, drawing the marked flesh across any mundane distance. The rite was
> known to necromancers for ages but has now spread to other traditions who
> found their own interpretations of the underlying principle.

This framing explains universality without deity gymnastics — every casting
class works with planar/arcane forces (or with spirit/nature/song equivalents)
and so each tradition has independently arrived at its own expression of the
underlying rite. Non-casters lack the sympathetic training to anchor the
tether, which is why pure melee classes do not get the spell.

This framing is era-safe (Luclin Nexus content, no Planes of Power references)
and gives spell-vendor and scroll flavor text a consistent through-line if
the data-expert wants one.

### Class Spell Names (lore-master approved)

| Class | Spell Name | Flavor Text |
|-------|-----------|-------------|
| Cleric | Divine Reclamation | By the authority of the gods, what has fallen in service shall be returned to its servant's reach. |
| Druid | Nature's Reclamation | The living world recognizes its own and moves the fallen vessel to where it is needed. |
| Shaman | Ancestral Summons | The ancestors hear the plea and guide the fallen vessel home across the spirit roads. |
| Necromancer | Conjure Cadaver | Commands the dead matter to obey, drawing the caster's corpse across any mundane distance. |
| Wizard | Spectral Translocation | The body is matter; matter has coordinates. The wizard calculates, and the corpse arrives. |
| Magician | Summon Mortal Remains | The elements that composed this form still answer — the magician gathers them back. |
| Enchanter | Phantasmal Reclamation | The fading impression of the self is enough — the enchanter follows the thread and calls the body home. |
| Paladin | Solemn Retrieval | A sacred duty: the holy warrior's remains shall not be left to the profane. |
| Shadow Knight | Death's Recall | Death does not release what is claimed — the shadow knight's remains return at the master's command. |
| Ranger | Warden's Claim | No warden abandons the fallen to the wild — the land yields what is theirs to reclaim. |
| Beastlord | Ancestral Call | The spirits of those who hunted before answer, returning the fallen hunter's form to living hands. |
| Bard | Dirge of Homecoming | Every life leaves a note unresolved. The bard plays it, and what was lost finds its way back. |

### Hard-Fit Class Notes

For four classes the universal-framing rationale needs a class-specific gloss:

- **Paladin** — extension of the resurrection authority their deity already
  grants them. The deity who permits return of the soul also permits
  reclamation of the vessel. Casting framing is a preparatory rite for last
  rites or rescue from profane hands.
- **Ranger** — nature-assisted wayfinding, not death magic. The forest
  knows where the body is and the ranger asks it to bring the body home.
  Lean into the warden role, not necromancy.
- **Bard** — sympathetic acoustics. Every life leaves an unresolved note;
  the bard plays it and the resonance pulls the physical anchor with it.
  Pure Bardic lore, no necromantic overlay.
- **Enchanter** — psychic-thread perception. A dead body retains the
  fading impression of the person; the enchanter pulls that thread and
  the matter follows. Mind-over-matter perception, in-school for them.

### Failure Modes & Edge Cases

The spell must handle these cases gracefully. Player-facing message
suggestions in italics; final wording is the data-expert/architect's
call.

1. **No corpse exists for this character in this zone.**
   The cast completes but produces no corpse. Player-facing message:
   *"You have no corpse in this zone."* Cooldown should NOT trigger if
   no corpse was found, so the player isn't punished for an information
   check. (This is a design preference, not strict EQ-engine behavior —
   see Open Questions.)

2. **Multiple corpses exist for this character in this zone.**
   The spell summons ONE corpse per cast. Default to the **most
   recently created corpse** (the one most likely to hold the freshest
   gear). The player can cast again after the cooldown to pull older
   corpses. This matches the existing summon-corpse semantics and
   avoids surprise behavior.

3. **Corpse is in an unreachable / out-of-bounds part of the zone.**
   The summon uses the engine's existing summon-corpse logic. If the
   existing logic handles bad-geometry corpses (e.g., corpse fell
   through world), the new spell inherits that behavior unchanged. If
   the engine fails to retrieve a stuck corpse, that is a pre-existing
   bug not in scope here. Architect/c-expert should note any known
   limitations.

4. **Caster is in combat / being attacked.**
   Standard cast-interrupt rules apply. A 6-second cast in active
   combat will frequently be interrupted; this is acceptable — the
   spell is designed for retrieval *after* a death, not as a combat
   tactic.

5. **Caster is dead.**
   The caster must be alive to cast. (You cannot cast spells while
   dead in the engine; this is a non-issue.) Player tries to cast
   while a ghost — engine default behavior of "you cannot do that
   while dead."

6. **Corpse decay timer is about to expire.**
   No special handling. If the player casts and the corpse rots
   mid-cast, the cast resolves with the same "no corpse" path as
   case 1. Edge case is rare enough that no extra messaging is
   warranted.

7. **Caster zones during cast.**
   Standard interrupt; the cast fizzles. No special handling.

8. **Corpse is in a different zone.**
   The cast completes but no corpse is found in the *current* zone.
   Same handling as case 1: no corpse summoned, cooldown not
   triggered, message *"You have no corpse in this zone."*

9. **Cast attempted before cooldown expires.**
   Standard recast-not-ready message. No spell consumed, no cast
   animation.

10. **Caster has no mana / is silenced / is feared / etc.**
    Standard cast-prevention rules. Mana cost is 0 so silence/mana
    are not blockers; fear and stun prevent the cast as usual.

### Balance Considerations

**Risk: trivializes the death penalty.** Mitigation: the death penalty
in EQ is composed of (a) XP loss, (b) equipment unequip, (c) the trip
back to the zone, and (d) the social cost of asking for help. This
spell only removes (d) for the specific failure mode of "corpse is in
an inaccessible spot." The player still pays (a), (b), and (c) on
every death. Empirically, the existing Necromancer summon-corpse
service in retail EQ removed the same friction without trivializing
death — and that service was *available to other classes via paying
a Necro player*, so the only thing this spell changes is removing the
need for that intermediary on a low-pop server.

**Risk: 3-minute cooldown is too forgiving in chained-death scenarios.**
Mitigation: 3 minutes is long enough that a player chain-dying in a
hostile zone will spend more time waiting for the cooldown than they
saved by avoiding a manual corpse run, but short enough that a single
tactical mistake doesn't end the night. This number is the primary
tuning knob — if play-testing shows abuse, the architect can make it
a `Spells:UniversalSummonCorpseCooldown` rule to enable adjustment
without a content patch.

**Risk: 6-second cast is too short — the spell becomes an in-combat
panic button.** Mitigation: 6 seconds with normal interrupt rules is
plenty long enough that any incoming damage during active combat
will fizzle the cast. The spell is not intended to be cast in
combat; combat-cast attempts will simply fail more often than they
succeed, which is the desired outcome.

**Risk: companion deaths leave a player without a tank/healer they
can recruit back fast enough.** Out of scope for this spell — the
companion re-recruitment friction is its own concern (see the
"Companion Re-recruitment Pain" memory). This spell does NOT summon
companion corpses.

**Risk: degrades the value of the existing high-level Necromancer /
Shaman summon corpse service to other players.** Not a concern on
this server (1–3 players, no broader player economy to degrade), and
the existing spells *also* let you summon *other people's* corpses
which is still strictly more powerful and remains unchanged.

**Risk: existing Necromancer player feels their unique class identity
is diluted.** The Necromancer keeps their high-level cross-player
summon-corpse spell, AND their level-1 version is named *Conjure
Cadaver* — the most flavor-forward of all 12 names — leaning into
the class identity rather than washing it out. This is the best
mitigation given that we have to give the spell to all casters.

### Era Compliance

- All 12 classes (including Beastlord, Luclin-era) are era-legal.
- The mechanical effect (summon a corpse to the caster) exists in
  Classic and Velious already (Necromancer and Shaman). This is not
  a post-Luclin invention.
- No spell name collides with a known post-Luclin or expansion-
  introduced spell — lore-master verified era compliance for all 12
  names. The "Compact of the Awakened" framing is grounded in
  Luclin Nexus lore, not Planes of Power.
- 0-mana, 0-reagent, level-1 self-utility spells are era-precedent:
  Gate (level 14, mana cost), Bind Affinity (level 12, mana cost),
  the racial languages, etc. The closest precedent is the Necromancer
  *Locate Corpse* line which was a low-level utility spell. This
  fits the existing design language.
- Auto-scribing on patch is a server-operator action, not a content
  change visible inside the game world's lore. No era issue.

## Affected Systems

- [x] **C++ server source** (`eqemu/`) — the existing summon-corpse
      effect handler must be invocable by the new spells. If the
      effect is already a generic SPA (spell-effect attribute) usable
      by any class, no C++ change is needed; if it is hard-gated to
      necromancer/shaman class IDs anywhere, that gate must be
      relaxed. Architect to verify.
- [x] **Database tables** (`peq`) — 12 new rows in `spells_new` (one
      per class) and corresponding scroll items in `items` plus
      vendor entries in `merchantlist`. Auto-scribe on patch requires
      a one-time migration touching `character_spells`. Data-expert
      to plan.
- [x] **Rule values** — recommend a new rule (e.g.
      `Spells:UniversalSummonCorpseCooldown`) so the cooldown is
      tunable without a spell re-patch. Architect/config-expert
      decision.
- [ ] **Lua quest scripts** — none expected. The spell uses the
      standard spell engine, not quest hooks.
- [ ] **Perl quest scripts** — none.
- [ ] **Server configuration** — no config file changes expected.
- [ ] **Infrastructure / Docker** — none.

## Dependencies

None. This feature is self-contained. It does not depend on the
companion system, the small-group-scaling work, or any other
in-flight feature. It can be designed, built, tested, and shipped
independently.

## Open Questions

For the architect / implementation team:

1. **Cooldown enforcement on no-corpse case.** Design preference is
   that a "no corpse in this zone" cast does NOT trigger the 3-minute
   cooldown — the player shouldn't be punished for a quick check. Is
   this feasible in the spell engine, or is recast-timer always
   triggered on cast-completion regardless of effect outcome? If the
   latter, this becomes an acceptable wart, not a blocker.
2. **Multiple-corpses selection order.** Engine should default to
   "summon most recently created corpse first" if not already
   default. Architect to verify against the existing summon-corpse
   path.
3. **Bard cast vs. song.** Bards use song-window slots, not standard
   spell-bar slots, for class abilities. Is this spell scribed into
   the song window or the spell-gem window? Recommend: standard
   spell-gem window so the cast is consistent across all 12 classes
   (6-second cast, interruptible). Bard player loses one spell-gem
   slot to a utility spell, which is acceptable. Lore-master agreed
   it should still be flavored as a "dirge". Architect to confirm
   feasibility.
4. **Auto-scribe migration timing.** The 12 spells must already exist
   in `spells_new` *before* the migration runs over `character_spells`.
   Data-expert to sequence.
5. **Vendor placement — RESOLVED 2026-05-03 by lore-master.**
   Use the standard class spell vendor in each starting city for all
   12 scrolls. Do NOT scatter to guild-specific or faction-gated
   vendors (e.g., do not put the Necromancer scroll on a Necropolis
   guild vendor only). Lore-master rationale: (a) this is a universal
   utility spell, not a guild-prestige reward, so it belongs on
   infrastructure-level vendors; (b) Classic-era convention is that
   level-1 spells are sold uniformly at the class spell vendor in the
   starting city, not at faction-gated guild vendors; (c) faction-
   restricted guild vendors (e.g., Necromancer guild vendor in
   Neriak/Paineel) would lock the scroll behind faction the player
   may not have at level 1, creating inconsistency. Architect/data-
   expert: place each of the 12 scrolls on the canonical class spell
   vendor in each city that supports that class as a starting city.
6. **Animation / sound effect.** The existing summon-corpse effect
   has an animation. Reuse as-is for all 12 classes, or do we want
   class-flavored animations? Recommend: reuse, scope-creep
   otherwise.
7. **Spell icon.** The existing summon-corpse icon. Reuse or pick
   class-flavored icons? Recommend: reuse one icon for all 12 to
   minimize art-pipeline work.

For the lore-master:

(All resolved — see Class Spell Names table above. Lore-master sign-off
recorded in agent-conversations.md.)

## Acceptance Criteria

Player-observable, in-game:

- [ ] A newly-created character of each of the 12 casting classes can
      walk to their starting-city class spell vendor and purchase
      a scroll of the appropriate spell name for trivial gold.
- [ ] Scribing the scroll adds the spell to the spellbook at level 1.
- [ ] An existing pre-patch character of each of the 12 casting
      classes has the spell already scribed on their first login
      after the patch deploys, with no UI message.
- [ ] Memming and casting the spell completes a 6-second cast bar
      with no mana cost, no reagent consumed, no target required.
- [ ] After cast completion, if the caster has a corpse in the
      current zone, the corpse appears at the caster's feet and is
      lootable.
- [ ] After cast completion, if the caster has no corpse in the
      current zone, the caster sees *"You have no corpse in this
      zone."* (or engine-equivalent) and the corpse is not summoned.
- [ ] Recasting within 3 minutes shows the standard "spell not
      ready" message, regardless of whether the prior cast summoned
      a corpse.
- [ ] After 3 minutes, the spell is castable again.
- [ ] Damage during cast interrupts the cast as expected.
- [ ] Casting while moving fails as expected.
- [ ] The Necromancer's existing high-level cross-player Summon
      Corpse spell still works exactly as before — no regression.
- [ ] The Shaman's existing high-level Summon Corpse spell still
      works exactly as before — no regression.
- [ ] No melee class (Warrior, Monk, Rogue) can scribe the new
      spell — the scroll is not in their class's spellbook
      rune-class compatibility.
- [ ] In a 1–3 player session, a player who dies deep in any
      Classic/Kunark/Velious/Luclin zone can return to the zone
      entrance, cast the spell, and recover their corpse without
      assistance.

---

## Appendix: Technical Notes for Architect

These are *advisory* observations from the design pass. The architect
makes all implementation decisions.

- **Reuse, don't reinvent.** The Necromancer summon-corpse effect
  (SPA — see `spells_new.effectid1` etc. in the Necromancer summon
  corpse spell rows) is the existing engine path. The 12 new spells
  should all use the same SPA, just with different scribed-class
  bitmasks, names, icons (or not), and the new cooldown.

- **Recommended rule name.** `Spells:UniversalSummonCorpseCooldown`,
  default 180. Lets the user adjust live without a content patch.

- **Existing spell to clone.** Necromancer "Summon Corpse" (the
  classic-era version, not the higher-level "Greater Summon Corpse"
  unless that one is more permissive). Data-expert should pick
  the closest mechanical match in `spells_new` and clone-mutate.

- **`classes` field in `spells_new`.** Each of the 12 spells will
  set its own class as level 1 and all other classes as 255
  (unscribable). 12 rows, not 1 row with 12 classes — this gives
  per-class spell names cleanly.

- **Item scrolls.** Each of the 12 spells needs its own scroll item
  in `items` with the appropriate `scrolleffect` pointing at the
  spell ID, restricted to its class via `classes` bitmask.

- **Auto-scribe migration.** A one-time SQL pass: for every row in
  `character_data` whose class is one of the 12 casting classes
  and where the new spell ID for that class is not already in
  `character_spells` for that character, insert a row at the next
  available slot index. Data-expert to design the slot-pick logic
  (probably first empty slot, or slot 0 if no spells scribed at
  level 1 yet — needs care with existing Necro/Sham who already
  have summon-corpse-like spells at higher levels).

- **Bard spell-gem slot vs. song-window slot.** The bard's
  spellbook stores both. Recommend the new spell goes into the
  standard spell-gem section so it casts identically to the other
  11 classes (6-second cast, no chant-loop). Architect to verify
  bard scribed-spell handling does not auto-route to song window.

- **Cooldown on missed cast.** If the engine cannot decouple
  "cooldown applies" from "effect succeeded", accept the wart and
  document in player-facing patch notes ("the spell does enter
  cooldown even if you have no corpse in zone — check before you
  cast").

- **Sanity check for class IDs.** The internal class IDs as of
  Luclin are CLR=2, PAL=3, RNG=4, SHD=5, DRU=6, MNK=7 (excluded),
  BRD=8, ROG=9 (excluded), SHM=10, NEC=11, WIZ=12, MAG=13,
  ENC=14, BST=15, WAR=1 (excluded). Twelve casting classes is
  correct.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
