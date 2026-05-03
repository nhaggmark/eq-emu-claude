# Companion Rez — Product Requirements Document

> **Feature branch:** `bugfix/companion-rez`
> **Author:** game-designer
> **Date:** 2026-04-27
> **Status:** APPROVED — lore-master signed off 2026-04-27

---

## Problem Statement

The companion system is the signature feature of this server. For 1–3 player
small-group play, a Cleric NPC companion is the standard answer to "what
happens when someone dies mid-zone?" In Classic EverQuest, post-fight rez is
a routine, expected beat: the fight ends, the Cleric raises the dead, the
group keeps playing. This is the core gameplay loop.

That loop is broken today. When a party member (NPC companion or the player)
falls in combat, a Cleric NPC companion in the party is observed *attempting*
the rez — spell cast animation, messaging — but the rez does not take. The
target stays down. The companion does not return.

For our server, with one player and a small handful of NPC companions, every
unrezzed companion is either a long corpse run, a manual `#kill` workaround,
a re-recruitment dance, or a session-ending event. Cleric companions exist
specifically to prevent that. They are currently failing at the one job that
defines their value in the party.

**Locked invariant (verbatim from user):**
> "When we end a fight and one of my NPC companions falls, the Cleric NPC
> companion should be able to rez the party member. This is currently broken."

## Goals

1. **Lock the post-combat rez invariant:** when combat ends and a party
   member is down, a Cleric NPC companion in the party automatically rezzes
   them. No player input required. No manual command. The Cleric does what
   a Cleric does.
2. **Cover both target types:** the player AND recruited NPC companions
   are valid rez targets. The hypothesis in BUG-001 is that NPC corpses
   have no UI to confirm a rez request — the architect must close that
   gap so the rez "takes" without player intervention for NPC targets.
3. **Reliability is the bar.** When the prerequisites are met (Cleric is
   alive, has mana, has a rez component if required, target corpse is
   valid and in range, post-combat), the rez MUST succeed. The user's
   pain point is "this is broken" — design must require deterministic
   success, not best-effort.
4. **Deliver via TDD** so the invariant is machine-verified, consistent
   with the prior `companion-rerecruit` bugfix discipline. Engineers
   write failing tests first, then implement.

## Non-Goals

- **Player-commanded rez (`!rez`).** Manual rez triggered by the player is
  a separate feature. This bugfix is scoped strictly to automatic
  post-combat behavior.
- **Mid-combat rez.** Explicitly disallowed (see AC-8). A Cleric reviving
  a dead companion in the middle of an active pull breaks the fight tempo,
  exposes the rezzed (low-HP, low-mana) companion to instant re-death, and
  burns the Cleric's mana on someone who can't fight effectively yet. Rez
  is a post-combat beat.
- **Generic "any party member" rez.** Targets are limited to the player
  and recruited NPC companions on the player's group. Charm pets, swarm
  pets, mercenaries, summoned pets, mob corpses, and unrelated player
  characters in the zone are out of scope.
- **Charm pets, swarm pets, mercenaries, summoned pets.** Different system
  and different death model. Untouched.
- **Spell selection algorithm details.** The architect chooses the policy
  for tier preference (e.g., "highest available rez first"). The PRD only
  requires that *some* tier-preference policy exists and that fallback
  behavior is graceful (AC-5, AC-7).
- **Rezzers other than Cleric.** Paladins (Revive, lvl 44, Kunark) and
  Druids (Reincarnation, lvl 52, Classic) are in-era options if scope
  ever expands, but the user's invariant is Cleric-specific. The
  architect may generalize the implementation if natural, but this PRD
  only contracts the Cleric path. **Shaman rez is a HARD STOP for any
  future expansion** — Shamans have no rez spell in Classic-Luclin and
  must never be added (per lore-master, era violation). Necromancer rez
  is in-era but mechanically distinct (damaged corpse / XP penalty); if
  ever added in a future feature, it must reflect that distinction.
- **Player rez UI redesign.** The player still gets the standard EQ rez
  prompt and decides accept/decline themselves (AC-4). No changes to the
  player-side rez window.
- **Cleric self-rez or "rez-the-rezzer".** A Cleric cannot rez itself in
  Classic EQ. With one player and a small companion roster, if the Cleric
  dies, no other rezzer may be present. Documented expected behavior:
  graceful no-op (see Validation).

## User Experience

### Post-Combat Rez Invariant (THE design contract)

> When combat ends and a party member (player or recruited NPC companion)
> is down, a Cleric NPC companion in the party automatically casts an
> appropriate rez spell on each downed target in sequence. Rez succeeds
> deterministically when prerequisites are met. NPC companion targets
> return to the active group at the rez spell's HP/mana spec. The player
> receives the standard EQ rez prompt and decides accept/decline.

### Player Flow

1. Player and party (including a Cleric NPC companion) engage in combat.
2. During the fight, one or more party members fall (the player, an NPC
   companion, or both). The Cleric does NOT rez during the fight.
3. The fight ends — last hostile in-combat target is dead, fled, or out
   of aggro range. The party returns to the post-combat state.
4. Within a small window (architect specifies N seconds — see AC-1), the
   Cleric automatically begins rezzing downed party members.
5. For each downed NPC companion: rez completes, the companion returns
   to the active group at the spell-specified HP/mana, ready to play.
6. For a downed player: the standard EQ rez prompt appears for the
   player; player accepts or declines per normal rules.
7. If multiple party members are down, the Cleric handles them in
   sequence — rezzes one, then the next, until all eligible targets are
   rezzed (or the Cleric runs out of resources, see edge cases below).
8. The next fight can begin. The session continues without player
   intervention beyond normal post-fight regen.

### Example Scenarios

**Scenario A — Single NPC companion down post-fight.**
Player + Cleric + Warrior NPC companion are clearing in Najena. Warrior
takes a bad pull and dies just before the last mob falls. Mob dies. The
Cleric, alive at full mana, scans for downed party members, identifies
the Warrior corpse, casts rez. The Warrior is back, on its feet, in the
group, at the spell's HP/mana spec. Total elapsed: a few seconds. No
player input required.

**Scenario B — Player down post-fight, Cleric alive.**
Player is tanking in Lake of Ill Omen and dies on the final blow against
a sarnak. Mob dies on its own (DoTs / pet finish it). The Cleric scans,
finds the player corpse, casts rez. The player sees the standard EQ rez
prompt and accepts. The session resumes normally.

**Scenario C — Multiple party members down.**
Player + Cleric + Wizard + Warrior in Permafrost. A bad add wave wipes
everyone except the Cleric, who finishes the last mob with a stun chain
and Yaulp burst. Combat ends. Cleric rezzes the Warrior first, then the
Wizard, then the player. All three are back in sequence. Cleric mana is
low but no error spam, no infinite loop.

**Scenario D — Cleric out of mana mid-rez-queue.**
Player + Cleric + two NPC companions. Both NPC companions die in a long
fight. Cleric finishes the fight at low mana, rezzes the first companion,
runs out of mana before the second rez. The Cleric does NOT spam errors.
The Cleric does NOT loop attempting to cast. The Cleric either uses a
lower-tier rez (if one is available and affordable), waits to regen
mana before the next attempt, or sits and meditates per normal NPC
companion behavior. The remaining corpse stays down until the Cleric
has enough mana, then gets rezzed automatically.

**Scenario E — Cleric down, no other rezzer available.**
Player + Cleric + Warrior. Cleric dies, then Warrior dies, fight ends
with the player and pet finishing the mob. No alive Cleric in party —
no auto-rez occurs. This is graceful: no error spam, no failed cast
loop, no surprise behavior. The player handles recovery (corpse run,
re-recruit, etc.) using existing systems. **This is the documented
expected behavior, not a bug.** A future feature may address this; it
is out of scope here.

**Scenario F — Back-to-back fights.**
Player pulls fight #1, Warrior dies, fight #1 ends, Cleric rezzes the
Warrior. Before the rez fully completes, the player pulls fight #2.
The rez should still complete on the now-still-dead Warrior; the
Warrior should rejoin the group during fight #2 if rez resolves before
fight #2 ends. (Mid-combat rez is disallowed for *initiating* a rez —
see AC-8 — but a rez that began pre-combat completes on its own
schedule.)

**Scenario G — Companion falls during the rez cast.**
Cleric is rezzing the Warrior. Mid-cast, the Wizard takes a hit from a
lingering DoT and dies. The Warrior rez completes successfully. The
Cleric then targets the Wizard corpse and rezzes the Wizard.

## Game Design Details

### Mechanics — five rules to enforce

The invariant decomposes into five rules. The architect determines how
each is enforced; the design contract is that all five must hold.

1. **Auto-trigger on combat end.** A Cleric NPC companion in the party
   automatically scans for downed party members when the party
   transitions from in-combat to out-of-combat. The trigger is the
   combat-end transition itself — not a timer that runs constantly,
   not a player command. Architect picks the exact post-combat delay
   (small enough to feel responsive, large enough to confirm combat is
   actually over and not a brief lull); see AC-1.

2. **Eligible targets are player + recruited NPC companions.** The
   Cleric's rez scan covers exactly this set. Charm pets, swarm pets,
   mercenaries, summoned pets, mob corpses, and unrelated players are
   ignored. The architect determines how to identify the eligible set
   (group membership, companion-data records, etc.).

3. **Tier preference.** When a Cleric has multiple rez spells available
   at its level (e.g., Reviving Resuscitation, Resurrection, etc.), it
   prefers the higher-tier rez (more XP returned) when affordable.
   Architect picks the policy — design only requires that *some*
   policy exists and that the player benefits from the Cleric's best
   available rez when conditions allow.

4. **Sequential multi-target handling.** When multiple party members
   are down, the Cleric rezzes them one at a time, in sequence. The
   architect picks the ordering policy (player first vs. tank first
   vs. corpse-discovery order). The contract is "all of them get
   rezzed if conditions allow, not just one."

5. **NPC corpses must accept rez without UI.** This is the crux of the
   bug. In live EQ, rez creates a request the corpse owner confirms
   via dialog. NPC companions have no such UI. The architect must close
   this gap so the rez completes server-side for NPC targets without
   any external confirmation. Player targets continue to use the
   standard rez prompt (per AC-4).

### Reliability Guarantee (the AC-10 contract)

**When all prerequisites are met, the rez MUST succeed:**

- Cleric is alive
- Cleric has sufficient mana for at least one rez spell tier
- Cleric has any required reagent / component
- Target corpse is in valid line-of-sight / range per the rez spell
- Combat is ended (no in-combat status on the party)
- Target is an eligible party member (player or recruited NPC companion)

If all of these are true, the rez succeeds — no transient failures, no
flaky state, no "the cast went off but nothing happened." The user's
verbatim pain is "I can see that he's attempting to rez but nothing
happens." The PRD's hard requirement is that this never happens again
when the prerequisites hold.

If any prerequisite is NOT met, the Cleric falls back gracefully:
out-of-mana waits for regen; out-of-component waits or downgrades tier;
out-of-range moves into range or skips with no error spam.

### Out-of-Resources Behavior

- **Out of mana:** Cleric stops attempting rez until mana regenerates
  past the cost of an available rez tier. No spam. No infinite loop.
  Sit/meditate per normal NPC companion behavior. Resume when ready.
- **Out of reagent/component:** if a lower-tier rez is available and
  affordable in components, the Cleric falls back to that. If no
  affordable tier is available, the Cleric waits silently. No chat
  output (lore-master confirmed flavor lines are out of scope).
- **No fallback available:** silent. Player can investigate via
  companion inventory. No error spam to chat.

### Mid-Combat Rez is Disallowed

A Cleric must NOT initiate a rez while combat is ongoing on the party.
Reasons:
- Rezzed targets come back at low HP/mana; instant re-death is likely.
- The Cleric's mana is better spent on heals/CC during the fight.
- The standard EQ rez cast is long (~10s) — interrupting heals to rez
  mid-fight breaks the heal rotation.

A rez cast that *began* before combat re-initiates may complete (per
Scenario F). The disallow is on *initiation*, not in-flight casts.

### Balance Considerations

- This is not a power increase. The companion system already includes
  a Cleric whose canonical role is to rez. The fix restores broken
  behavior; it does not add a new capability.
- Reliability is required (AC-10) but is not "free." The rez still
  costs Cleric mana, still respects spell timers, still requires
  corpse range. Players who wipe their Cleric still face full
  recovery costs (Scenario E).
- The 1–3 player constraint is the whole reason the invariant exists.
  Without auto-rez, every companion death is a manual cleanup event.
  A Cleric companion that automatically rezzes is what makes the
  companion system feel like a real party.
- No XP economy distortion: rez returns XP per the spell's spec, same
  as a player Cleric would. The architect must NOT add custom "free
  XP" or "no XP loss" semantics — the spell's normal numbers stand.

### Era Compliance

The fix is mechanical and uses Classic-Luclin spell content only. The
in-scope Cleric rez progression (per lore-master review):

| Spell | Level | Era |
|-------|-------|-----|
| Resurrection | 15 | Classic |
| Reanimation | 29 | Classic |
| Revive | 43 | Classic |
| Resuscitate | 53 | Classic |
| Restoration | 65 | Luclin (within era lock) |

No post-Luclin spells. No deity-based, race-based, or alignment-based
restrictions on rez targets — Cleric rez is canonical class identity in
Classic regardless of player or target characteristics (lore-master
confirmed 2026-04-27).

**HARD STOP — Shaman rez:** Shamans do NOT receive a resurrection spell
in Classic through Luclin. Any future expansion of auto-rez to Shaman
companions is an era violation and must be rejected. This PRD scopes
Cleric only; the HARD STOP is documented here for downstream awareness.

**Conditional — Necromancer rez:** Necromancers have a Resurrection
spell in Classic, but it is mechanically distinct (yields a damaged /
shard corpse with experience penalty, not a clean Cleric rez). Out of
current scope. If any future feature expands auto-rez to Necromancer
companions, the implementation must reflect that distinction (inferior,
dark-flavored). Not a current concern.

The Cleric class itself is the Classic-launch rezzer; no narrative
content introduced by this fix.

## Affected Systems

The architect determines exact touchpoints during triage. The PRD lists
the systems plausibly involved:

- [x] C++ server source (`eqemu/`) — companion AI / post-combat behavior;
      rez spell cast logic; the rez request/answer flow
      (`RezzPlayer`, `OP_RezzAnswer`, `OP_RezzRequest`); NPC corpse
      auto-accept gap. See `eqemu/zone/companion.cpp` death/rez path
      (per BUG-001 reference) and `eqemu/zone/spells.cpp`,
      `eqemu/zone/npc.cpp`.
- [x] Lua quest scripts (`akk-stack/server/quests/`) — Cleric companion
      post-combat behavior trigger; possible companion AI hooks via
      `companion.lua` and global NPC handlers.
- [ ] Perl quest scripts (maintenance only) — only if the Cleric AI
      flow uses Perl.
- [x] Database tables (`peq`) — `companion_data` (`is_suspended`,
      `cur_hp`, death-state semantics per companion-rerecruit
      architecture); spell-data tables for tier selection.
- [ ] Rule values — possibly a `Companions:AutoRez*` rule for tuning
      knobs (architect to decide).
- [ ] Server configuration — unlikely; flag if architect finds
      otherwise.
- [ ] Client protocol — `OP_RezzAnswer` / `OP_RezzRequest` flow may
      need a server-side bypass for NPC targets. Protocol-agent to
      validate during architecture phase.
- [ ] Infrastructure / Docker — n/a.

## Dependencies

- `bugfix/companion-rerecruit` (already merged per status of that
  workspace). The death-state / `is_suspended` semantics established
  in companion-rerecruit are the foundation this fix builds on. Death
  remains the primary path that produces a "downed" target — it must
  cleanly distinguish a rezzable corpse from a dismissed/inactive
  companion record.

No other feature dependencies.

## Open Questions

1. **Post-combat delay (architect).** What is N — the number of
   seconds between combat end and Cleric scan? Must be small enough
   to feel responsive (player isn't waiting), large enough to confirm
   combat is genuinely over (no in-flight aggro). Architect picks N;
   the PRD requires the number be defined (AC-1).

2. **NPC corpse rez confirmation gap (architect).** BUG-001 hypothesis
   is that NPC companion corpses lack a UI to confirm rez requests, so
   the rez request is created but never answered. Architect must
   investigate the actual rez code path (`RezzPlayer`,
   `OP_RezzAnswer`, `OP_RezzRequest`) and either:
   - Add server-side auto-accept logic for NPC companion rez targets,
   - Or bypass the rez request mechanism entirely for NPC targets and
     apply the rez effect directly,
   - Or some other approach the architect identifies.
   The PRD does not prescribe — only requires that NPC targets are
   reliably rezzed (AC-3, AC-10).

3. **Rez tier preference policy (architect).** "Highest affordable"
   is the natural default. Architect confirms or selects an
   alternative. PRD only requires the policy is documented and
   consistent (AC-5).

4. **Multi-target ordering (architect).** Player-first, tank-first, or
   corpse-discovery-order — architect picks. Document the choice in
   the architecture plan so game-tester can validate sequence (AC-6).

5. **Cleric out-of-mana flavor message.** RESOLVED 2026-04-27 by
   lore-master: silent is correct, flavor lines are OPTIONAL and
   out of scope for this bugfix. Cleric performs the rez (or waits
   for mana) without narration. A future polish pass may add a
   one-time line if desired, but the architect should NOT add chat
   output as part of this fix.

6. **Quest-NPC rez interaction.** A recruited NPC who is also a
   kill-target or quest-state node in an active quest: rezzing them
   may produce odd quest-state interactions. This was flagged as a
   future-edge in companion-rerecruit; flagged again here for
   architect awareness. Not a scope expansion.

7. **TDD test scope (architect).** Which scenarios are unit-testable
   vs. integration-testable vs. game-tester-only. Architect maps the
   Validation Plan scenarios to test types per the
   companion-rerecruit pattern.

## Acceptance Criteria

The PRD is complete when ALL of these are demonstrably true. Each
criterion maps to one or more test scenarios in the Validation Plan.

- [ ] **AC-1: Auto-rez on NPC companion within N seconds.** When
      combat ends and an NPC companion is down, a Cleric NPC
      companion in the party automatically casts an appropriate rez
      spell on the downed companion within N seconds of combat
      ending. The architect specifies N. The PRD requires that N
      is defined and observable in testing.

- [ ] **AC-2: Auto-rez on player when player is down.** When the
      player is down, the Cleric automatically casts rez on the
      player corpse if the Cleric is alive and prerequisites are met.

- [ ] **AC-3: Rez "takes" on NPC companion targets.** A rezzed NPC
      companion returns to the active group at the rez spell's HP /
      mana spec. The companion is back in the group and playable —
      the rez actually succeeds, not just "the cast goes off but
      nothing happens." This closes BUG-001's primary symptom.

- [ ] **AC-4: Player rez window appears for player targets.** A
      rezzed player gets the standard EQ rez window per normal
      rules. Player decides accept/decline. The auto-rez does NOT
      bypass player consent for player targets.

- [ ] **AC-5: Higher-tier rez preferred.** When a Cleric has
      multiple rez spells available at its level, it prefers the
      higher-tier rez (more XP returned to the target) when
      affordable. The architect picks the policy; this AC requires
      the policy is consistent and documented.

- [ ] **AC-6: Multi-target sequencing.** When multiple party
      members are down, the Cleric rezzes all of them in sequence
      until all eligible targets are rezzed (or resources run out
      per AC-7). Not just one.

- [ ] **AC-7: Out-of-mana / out-of-component graceful behavior.**
      When the Cleric runs out of mana or rez component mid-queue,
      the Cleric does NOT spam errors, does NOT enter an infinite
      cast-fail loop, and either falls back to a lower-tier rez (if
      affordable) or waits to regen mana before the next attempt.
      Remaining corpses are rezzed automatically when the Cleric
      can resume.

- [ ] **AC-8: No mid-combat rez initiation.** The Cleric does NOT
      *initiate* a rez while combat is active on the party. (A rez
      that began before combat re-initiates may complete; the
      restriction is on initiation.)

- [ ] **AC-9: TDD discipline maintained.** Engineers ship failing
      tests FIRST that prove the invariant, then implement to make
      tests pass. The test suite survives in the repo as
      machine-verified evidence the invariant holds. Consistent with
      the companion-rerecruit bugfix pattern.

- [ ] **AC-10: Reliability — every prereq-met rez attempt succeeds.**
      When the prerequisites are met (Cleric alive, sufficient mana,
      reagent if required, target in range, valid party member,
      post-combat), the rez MUST succeed. This is the deterministic
      contract that closes BUG-001's verbatim pain point: "I can
      see that he's attempting to rez but nothing happens."

## Validation Plan

The architect translates these into specific test types (unit /
integration / in-game). The game-designer specifies the scenarios
that must be covered.

### TDD Approach (design constraint)

Engineers implementing this fix MUST write failing tests first. Each
acceptance criterion above gets at least one test that fails before
the fix lands and passes after. The tests are part of the deliverable.
This mirrors the companion-rerecruit bugfix discipline.

### Required Test Scenarios

1. **Single companion down post-fight → rezzed within N seconds.**
   Player + Cleric + Warrior. Warrior dies during fight. Fight ends.
   Within N seconds, Warrior is rezzed and back in group at spell-
   spec HP/mana.

2. **Player down post-fight, Cleric alive → rez window appears for
   player.** Player dies on final blow. Mob dies. Cleric scans, casts
   rez on player. Standard EQ rez prompt appears for the player.

3. **Multiple party members down → all rezzed in sequence.** Two or
   more corpses post-fight (mix of NPC companions and possibly the
   player). Cleric rezzes all in sequence. None left behind unless
   resources run out (AC-7 covered separately).

4. **Cleric out of mana → no error spam, recovers when mana
   available.** Cleric finishes fight at low mana, rezzes one
   companion, runs out of mana. No log spam. No infinite loop. Cleric
   regenerates (sit/meditate per normal AI), rezzes remaining
   companion when mana suffices.

5. **Cleric down (no other rezzer) → graceful no-op, no error spam.**
   Cleric dies during fight. Fight ends. No alive rezzer in party.
   Documented expected behavior: no auto-rez, no error spam, no
   surprise side-effects. Player handles recovery via existing
   systems.

6. **Back-to-back fights — rez completes before next pull (or
   in-flight if pull initiated mid-cast).** Fight #1 ends, Cleric
   begins rez, player pulls fight #2 mid-cast. The in-flight rez
   completes on the now-still-dead target. New rez initiations on
   newly-dead targets do NOT fire during fight #2 (AC-8).

7. **Edge case: party member falls during rez cast → rez completes
   against now-dead target gracefully.** Cleric is rezzing target A.
   Mid-cast, target B dies (DoT, lingering AoE, etc.). The rez on
   target A completes. The Cleric then targets B and rezzes B.

8. **Higher-tier rez preferred when affordable.** Cleric has both
   Resurrection (high tier) and Reviving Resuscitation (low tier)
   memorized and has mana for both. Cleric uses Resurrection.

9. **Tier fallback on insufficient mana.** Cleric has both tiers
   memorized but only enough mana for the low-tier. Cleric uses the
   low-tier. (Separate scenario: fall through to AC-7 behavior if
   even low-tier is unaffordable.)

10. **NPC companion rez actually "takes" — corpse-stays-down
    regression test.** This is the BUG-001 reproduction case. After
    the fix, every observed Cleric rez attempt on an NPC companion
    target results in the companion returning to the group, not
    staying as a corpse. This is the primary regression guard.

11. **No mid-combat initiation.** During an active fight with a
    downed companion, the Cleric does NOT begin rezzing. (Verify by
    monitoring for cast initiation against the combat-state flag.)

12. **Range / line-of-sight failure → graceful skip.** Companion
    corpse outside spell range / behind geometry. Cleric does not
    spam-cast or error-loop. Either repositions (architect's call) or
    skips that target until conditions change.

### Validation Phases

- **Engineer-side (unit / integration):** Scenarios 1, 4, 6, 8, 9,
  10, 11 are most amenable to automated verification. Architect
  confirms what the C++/Lua test harness supports.
- **Game-tester (in-game):** Scenarios 2 (player rez window),
  3 (multi-target), 5 (Cleric down), 7 (party member falls
  mid-cast), 12 (range/LoS) require live-server reproduction.
  Game-tester runs these in-game with a scripted checklist.
- **User confirmation:** Final sign-off after game-tester reports
  PASS.

## Rollback

The fix may span C++ (rez code path / NPC auto-accept) and Lua
(Cleric companion AI trigger). Rollback is per-fix, with each
component independently revertable:

1. **NPC corpse auto-accept (C++) rollback:** revert the change(s)
   that allow rez to "take" on NPC companion targets without UI
   confirmation. Returns to BUG-001 state where the rez cast
   completes but the corpse stays down. No data corruption risk;
   companion records unchanged.

2. **Cleric auto-rez trigger (Lua / C++) rollback:** revert the
   change(s) that wire post-combat scanning + rez initiation into
   Cleric companion AI. Returns to no-auto-rez behavior; player
   resumes manual recovery. Independent of the NPC auto-accept
   change.

3. **Multi-target sequencing rollback:** if the multi-target queue
   is implemented as a separable layer, it can be reverted to
   "single rez per scan cycle." The auto-rez still functions for
   one target at a time. AC-6 is regressed but AC-1, AC-2, AC-3,
   AC-10 still hold.

4. **Tier-preference rollback:** revert tier-selection logic to
   "first available rez memorized." AC-5 regresses, but the auto-
   rez still functions.

All four reverts are independent and additive. Reverting one does
not require reverting the others. The architect documents the revert
boundary for each fix in the implementation plan.

The TDD test suite stays in the repo even on rollback — the tests
become "known broken" markers for the regressed behavior rather than
being deleted. This preserves the design intent.

---

## Appendix: Technical Notes for Architect

**This appendix is advisory only. The architect makes all
implementation decisions.**

### Context from Bug Report BUG-001

**Locked invariant (verbatim user statement):**
> "When we end a fight and one of my NPC companions falls, the
> Cleric NPC companion should be able to rez the party member.
> This is currently broken."
>
> "I can see that he's attempting to rez but nothing happens. The
> NPC companion does not return."

### Working Hypothesis (from BUG-001)

The Cleric's rez spell may be cast successfully and create a rez
request (per standard EQ behavior), but NPC companion corpses have
no UI to "accept" the rez. In live EQ, a rez creates a request the
corpse owner confirms via a dialog box — NPCs have no such UI and
thus cannot confirm.

Two possible fix paths flagged in BUG-001:

1. **Auto-accept logic for NPC companion corpses:** when the rez
   target is an NPC companion, automatically accept the rez
   request server-side.

2. **Bypass the rez request mechanism entirely for NPC targets:**
   apply the rez effect directly without going through the
   request/accept flow.

This hypothesis is **NOT confirmed.** The architect must
investigate the actual rez code path and determine the true root
cause. The fix may be neither of the above.

### Reference Files (from BUG-001)

- Companion AI: `eqemu/zone/companion.cpp` — death/rez/recruit
  lifecycle. See death handling at `companion.cpp:1888-1913` and
  `is_suspended` state semantics (confirmed in
  companion-rerecruit architecture).
- Companion Lua module:
  `akk-stack/server/quests/lua_modules/companion.lua` —
  recruit/dismiss/death paths (touched by companion-rerecruit
  v1+v2 fix).
- Spell-cast logic for NPCs: `eqemu/zone/spells.cpp`,
  `eqemu/zone/npc.cpp`.
- Rez confirmation UI path: search C++ for `RezzPlayer`,
  `OP_RezzAnswer`, `OP_RezzRequest`.
- Companion death state: `is_suspended` flag in `companion_data`
  table (used as death state per companion-rerecruit
  architecture).
- Prior art:
  `claude/project-work/companion-rerecruit/architect/architecture.md`
  for companion lifecycle context.

### TDD as a Hard Design Constraint

The user has established TDD as the bugfix discipline (see
companion-rerecruit). Engineers write failing tests first, then
implement. The architect translates the Validation Plan scenarios
into concrete test types:

- **Unit tests** for tier-selection logic, multi-target sequencing,
  combat-state guard.
- **Integration tests** for rez-cast → NPC-corpse → return-to-group
  flow.
- **In-game scripted scenarios** for the game-tester where live
  server state and player-side rez UI are required.

### Suggested Tunables (advisory, not prescriptive)

If the post-combat trigger is rule-driven, candidate rule names
(architect picks the actual approach):

- `Companions:AutoRezEnabled` (master switch — emergency disable)
- `Companions:AutoRezPostCombatDelaySeconds` (the N from AC-1)
- `Companions:AutoRezTierPreference` (e.g., "highest" /
  "memorized-order")

These are advisory placeholders only. The architect may choose to
hard-code the policy if rule-based tuning is overkill, or to
generalize to other rezzer classes (Paladin, Necromancer) if the
implementation falls out naturally.

---

> **Next step:** Pass this PRD to the **architect** for technical
> feasibility assessment and implementation planning.
