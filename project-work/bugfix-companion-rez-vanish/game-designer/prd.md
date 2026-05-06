# Companion Rez Vanish — Product Requirements Document

> **Feature branch:** `bugfix/companion-rez-vanish`
> **Author:** game-designer
> **Date:** 2026-05-03
> **Status:** Approved (Design)

---

## Problem Statement

The recruit-any-NPC companion system is the signature feature of this 1–3
player server. Companions are designed to function as durable substitutes
for human group members, including the full classic group-content lifecycle:
death, corpse run / rez, return to combat. The autonomous in-group
resurrection feature (a Cleric companion casting Rez on a fallen Wizard
companion's corpse) was implemented in `feat(companion-rez): implement full
autonomous resurrection system` and has since received two follow-up bug
fixes (`bugfix/companion-rez` heartbeat hoist, `bugfix/companion-rerecruit`
re-recruit invariant V1+V2).

Despite those fixes, a player has now reported that a successfully
in-group-rez'd companion **rejoins the group, plays normally for a few
minutes, and then vanishes outright** — disappearing from the group
without warning, requiring the player to travel back to recruit the
companion from scratch. This regresses one of the core combat-loop
promises of the companion system: that "kill, rez, keep playing" is a
real, repeatable cycle. If rez success is silently undone after a few
minutes, the player learns not to trust rez at all and the feature loses
its purpose.

This PRD formalizes the bug for architect triage.

## Goals

1. Identify and eliminate whatever timer, flag, or state transition is
   causing a successfully-rezzed companion to be removed from the group
   shortly after rez. The companion must remain in the group indefinitely
   after rez, the same as a companion that never died.
2. Confirm the fix holds across BOTH a time-elapsed code path and a
   zone-transition code path. The original report could not distinguish
   which trigger fired, so the fix must address both possibilities.
3. Preserve all prior companion-rez and re-recruitment fixes — no regression
   on heartbeat, dismissed flag, group slot, alive guard, or name-based
   re-recruitment lookup.

## Non-Goals

- Redesigning the companion-rez or companion-recruitment flow. This is a
  bug fix, not a feature.
- Adding new player-facing UI for "companion is rez-able" indicators or
  rez-state visibility — separate feature.
- Allowing players to extend the companion rez timer, refuse rez, or
  control rez priority — separate feature.
- Auto-rez behavior changes (Cleric companion auto-detection of corpses,
  rez priority, line-of-sight rules) — that system already exists and is
  out of scope.
- Adding new spell mechanics, rez xp, or summon-corpse companion behavior.
- Changes to player (PC) rez behavior. This bug is companion-specific.

## User Experience

### Player Flow

1. Player is grouped with at least a Cleric companion and a Wizard
   companion (or equivalent rez-capable + non-rez-capable pair).
2. Combat begins. The Wizard companion takes lethal damage and dies.
   Wizard's corpse lands on the ground.
3. Combat ends. The Cleric companion (still alive) autonomously casts
   Resurrection on the Wizard's corpse.
4. The rez succeeds. The Wizard companion is restored to life with the
   appropriate post-rez stats (HP, mana, XP penalty per existing rules)
   and **rejoins the group in the slot it occupied before death.**
5. The player and group continue to play normally for an indefinite
   amount of time and through any number of zone transitions.
6. **Expected:** the rez'd Wizard companion remains in the group as a
   first-class member, identical in every observable way to a companion
   that never died. The companion accepts `/commands`, follows, fights,
   levels, and zones with the player permanently.
7. **Observed (the bug):** after a few minutes — possibly correlated with
   a timer expiry, possibly correlated with a zone transition — the rez'd
   Wizard companion vanishes from the group entirely. The slot is empty.
   The player must travel back to the original recruit point and re-recruit
   the Wizard from scratch. Any equipment, level, or progression state on
   the rezzed instance is lost.

### Example Scenario

A level 35 Warrior player is grouped with `Cleric Companion #A`,
`Wizard Companion #B`, and `Enchanter Companion #C` in Lower Guk. During
a fight against a frenzied ghoul, the Wizard companion dies. The fight
ends successfully. Within ~30 seconds the Cleric companion casts
Resurrection on the Wizard corpse. The Wizard rezzes, returns to the
group slot, and resumes following. The group keeps clearing for ~5
minutes and then zones to upper Guk via the standard zone line.

After the zone, OR a few minutes later in the same zone (the player
cannot recall which), the Wizard companion is suddenly gone. The group
window shows the slot empty. The player checks `/who` — the Wizard is
not in the zone. The player must hearth out and travel back to the
original recruit NPC to re-recruit the Wizard, losing the rezzed
instance entirely.

## Game Design Details

### Mechanics

A rez'd companion must behave **identically** to a never-died companion
in every observable way that affects the group lifecycle:

- **Group membership persistence.** The companion stays in the player's
  group across time, zones, sleep, log-in/log-out cycles, and any other
  normal play interruption — exactly as a companion that never died would.
- **Despawn-clock cleared.** Whatever cleanup timer or "dead corpse
  reaper" state was set when the companion died and dropped its corpse
  must be fully cleared on successful rez. The companion must not be
  scheduled for any later despawn / cleanup event tied to its prior death.
- **Death-state flags cleared.** Any internal "dead" / "dismissed" /
  "out-of-group" / "scheduled for cleanup" flag set during the death-and-
  corpse-drop sequence must be reset to its alive, in-group default on
  successful rez.
- **Heartbeat / re-recruit invariants preserved.** All prior fixes from
  the previous companion-rez line of work (heartbeat hoist, re-recruit
  invariant V1+V2, alive guard, group slot routing, atomicity) must
  continue to function. The fix to this bug must not regress any of them.
- **Command parity.** The rezzed companion responds to all `/commands`
  (assist, hold, follow, tome, stats, etc.) the same as a never-died
  companion. No silent partial state where the entity exists but commands
  no-op.
- **Zoning parity.** The rezzed companion zones with the player exactly
  as a never-died companion does — re-spawning into the new zone in the
  same group slot, with full state preserved.

### Balance Considerations

This is a bug fix that restores intended behavior, not a balance change.
The intended balance is already encoded in the existing autonomous-rez
feature: rez carries an XP penalty per the existing rules, has an
in-combat cast time the Cleric companion must complete, and consumes a
Cleric mana bar. None of those existing constraints change.

The 1–3 player constraint amplifies the severity of this bug: with only
1–3 humans, every companion lost to a silent vanish is a substantial
fraction of the group's combat capability, and the cost of traveling
back to re-recruit (potentially across multiple zones) eats a meaningful
share of a play session. The fix tightens the feature's existing
balance promise rather than altering it.

### Era Compliance

No new content. No new spells, NPCs, zones, items, or mechanics. The
feature being fixed (autonomous companion rez) is already era-compliant.

## Affected Systems

The architect determines the actual fix surface during triage. The
candidate surfaces below are flagged from the user's hypothesis and
adjacent recent fixes, not prescriptive:

- [x] C++ server source (`eqemu/`) — companion entity lifecycle, death
      timers, group membership, rez handler. Most recent companion-rez
      fixes (`84ac6a2`, `1766266`, `8a5f4565` and adjacent) live here.
- [x] Lua quest scripts (`akk-stack/server/quests/`) — companion.lua and
      lua_modules. Heartbeat / dismissed flag / re-recruit logic is here.
- [ ] Perl quest scripts (maintenance only)
- [ ] Database tables (`peq`)
- [ ] Rule values
- [ ] Server configuration
- [ ] Infrastructure / Docker

## Dependencies

None. The autonomous companion-rez system already exists, has merged
prior fixes, and is the system this bug is filed against. No new
dependencies.

## Open Questions

1. **(User's hypothesis — start here.)** Is there a death-timer / corpse
   reaper / despawn clock attached to the companion entity at the moment
   of death that is NOT cleared when rez succeeds? If so, the timer would
   continue ticking on the live (rezzed) entity and would despawn it at
   the originally-scheduled time, producing exactly the observed vanish
   behavior.
2. Is the bug time-triggered, zone-triggered, or both? The repro plan
   below tests each path independently because the user could not
   distinguish them.
3. Does the rez code path actually clear all "dead" state on the entity?
   Specifically: does it touch the same fields that the
   `bugfix/companion-rerecruit` fix established as invariants
   (Dismiss flag, follow state, group slot, name-based lookup keys)?
4. Is this a regression from one of the recent merged fixes
   (`bugfix/companion-rez` heartbeat hoist, `bugfix/companion-rerecruit`,
   companion-rez V2), or has the bug existed since the autonomous rez
   feature was first merged (`cb95baa`)?
5. Does the bug reproduce in 100% of post-rez sessions, or is it
   intermittent? The repro plan assumes deterministic — if it turns out
   to be flaky, the fix plan must include a way to confirm the fix held.
6. If a despawn timer is the culprit, is it the same timer used for
   un-rezzed dead companions whose corpses naturally decay? (i.e., is
   the bug "rez doesn't cancel the corpse-cleanup timer" or "rez creates
   a fresh entity that inherits a stale timer from the corpse"?)
7. Does the vanish leave any artifacts in `data_buckets`,
   `character_corpses`, or related tables that could distinguish
   "scheduled despawn fired" from "group eviction" from "entity
   destroyed"?

## Acceptance Criteria

Player-facing, observable from in-game testing or zone server logs:

- [ ] **AC-1: Time persistence (no time-based vanish).** A rez'd companion
      remains in the group for at least **30 minutes** of continuous play
      in the same zone after the rez completes. The companion is still
      listed in the group window, still responds to `/commands`, and is
      still visible at the end of the 30-minute window.
- [ ] **AC-2: Zone persistence (no zone-based vanish).** A rez'd companion
      remains in the group across **at least 3 zone transitions** following
      the rez. The companion correctly de-spawns from the previous zone,
      re-spawns into the new zone in the correct group slot, and retains
      full state (HP/mana scaling per normal zone behavior, equipment,
      level, follow target).
- [ ] **AC-3: Command parity.** A rez'd companion responds to all of the
      following commands the same way a never-died companion would:
      `/assist`, `/hold`, `/follow`, `/tome`, `/stats`, `/help`, plus any
      other commands in the standard companion command surface. No silent
      no-ops, no error messages, no commands that succeed for a never-died
      companion but fail for a rez'd one.
- [ ] **AC-4: No regression on prior companion-rez fixes.** All prior
      validated behaviors continue to work:
      - Heartbeat fires above all early-returns
        (commit `84ac6a204`).
      - Re-recruit invariant V1+V2 holds for multi-variant npc_type_id
        lookup (`bugfix/companion-rerecruit`).
      - Companion-rez V2 invariants: rez pipeline group slot, alive guard,
        Spawn routing, atomicity (`commit 17662d4ba`).
      - Companion still re-recruitable by name after the rezzed instance
        is voluntarily dismissed.
- [ ] **AC-5: Sustained-play resilience.** A rez'd companion survives a
      **30-minute combat session** that includes the following arc:
      death → rez → resume combat → second death → second rez → continue
      combat → end of session. At the end of the session the companion
      is still in the group, still responds to commands, and has not
      vanished at any point during the session.
- [ ] **AC-6: Logging.** Zone server logs from a successful repro-then-fix
      run show the companion's death-timer / despawn-clock state being
      explicitly cleared on rez (whatever specific log line the architect
      and engineer agree to add). This gives the game-tester an
      observable signal beyond "companion is still there" so future
      regressions are catchable in logs.
- [ ] **AC-7: Two-track repro retired.** Whatever scenario from the
      Repro Steps below originally triggered the bug now consistently
      produces the rez-and-stay outcome. Both the time-only and zone-only
      paths are verified independently.

## Reproduction Steps

The original report could not isolate whether time elapse, zone
transition, or both triggered the vanish. The architect and game-tester
must repro **both paths independently** and verify the fix on both.

### Repro A: Time-only (no zoning)

1. Log in player. Pick a flat, low-traffic zone with safe pull-and-rest
   space (e.g., East Karana, Lake Rathetear).
2. Recruit a Cleric companion and a Wizard companion. Confirm both are
   in the group window and respond to `/commands`.
3. Pull mobs sufficient to kill the Wizard companion (or use `#kill` /
   GM commands per `claude/docs/gm-commands-reference.md` to script
   the death deterministically).
4. End combat with the Cleric still alive.
5. Wait for the Cleric to autonomously cast Resurrection on the Wizard
   corpse. Confirm rez success: Wizard returns to the group slot and is
   responding to commands.
6. Note the wall-clock time of rez completion as `T_REZ`.
7. **Stay in the same zone.** Do not zone. Continue normal play
   (light combat, conversation, sitting/standing, casting, /con) for
   at least 30 minutes elapsed since `T_REZ`.
8. At `T_REZ + 30min`, verify all of: Wizard is in the group window,
   Wizard is visible in the world, Wizard responds to `/assist` and
   `/hold` and `/stats`. Capture zone server logs for the full window.
9. **PASS:** Wizard is still in the group at `T_REZ + 30min`.
   **FAIL:** Wizard vanished at any point in the window — note the
   approximate `T_REZ + N` at which the slot went empty.

### Repro B: Zone-only (minimum elapsed time)

1. Log in player. Start in a zone with at least three contiguous
   adjacent zones reachable by zone line (e.g., East Karana → North
   Karana → Qeynos Hills → West Karana).
2. Recruit a Cleric companion and a Wizard companion. Confirm both
   are in the group window.
3. Kill the Wizard companion as quickly as feasible (fast pull, GM
   command, etc.).
4. End combat. Wait for Cleric to rez the Wizard. Confirm rez success.
5. **Immediately** (within 60 seconds of rez completion) zone to the
   adjacent zone. Verify Wizard still in group on the new zone side.
6. Continue immediately to the next adjacent zone. Verify Wizard
   still in group.
7. Continue immediately to a third adjacent zone. Verify Wizard
   still in group.
8. **PASS:** Wizard is in the group on the third zone. **FAIL:**
   Wizard vanished on any transition or in any of the three zones —
   note which transition or zone the vanish occurred on.

### Repro C: Combined (full sustained-play, AC-5 backing)

1. Recruit Cleric + Wizard companions in a fight-rich zone.
2. Begin a 30-minute continuous combat session.
3. During the session, ensure the Wizard dies and is rezzed by the
   Cleric at least twice (use GM `#kill` if natural deaths don't
   occur within ~10 minutes).
4. During the session, zone at least once after a rez has completed
   (and ideally also after a second rez has completed).
5. At the 30-minute mark, verify Wizard is still in the group, still
   responds to commands, still on the correct group slot.
6. **PASS:** All of the above. **FAIL:** Any vanish at any point
   during the session.

### Repro logging requirements

For all three repros, capture:
- Zone server log (`akk-stack/server/logs/zone_dynamic_NN.log`) covering
  the full repro window.
- World server log if available.
- Player /log output of the group window or `#whogroup` snapshot
  before and after each death/rez/zone event, plus at the end of the
  window.
- Note the exact wall-clock timestamp of the vanish (if one occurs).

## Out of Scope

Explicitly NOT being addressed in this bug fix (each is a separate
feature if pursued):

- **Auto-rez configurability.** The Cleric companion's autonomous
  rez detection, priority, and rules are out of scope. The system as
  it exists is what we're fixing rez-vanish against.
- **Player-facing rez UI.** No new UI to indicate a companion is
  rez-able, mid-rez, recently rez'd, or at-risk-of-vanish. Out of scope.
- **Player-extendable rez timer.** No mechanic for the player to
  pause/extend/refuse the rez. Out of scope.
- **Companion auto-rez of other dead players or companions in
  arbitrary configurations** beyond the existing autonomous rez
  feature. Out of scope.
- **Cross-companion-rez (Wizard rezzing Cleric, etc.)** beyond the
  classes that natively cast Resurrection in era. Out of scope.
- **Rez XP penalty changes, rez sickness changes, rez effectiveness
  changes.** Out of scope.

---

## Appendix: Technical Notes for Architect

These are advisory hints for the architect's triage, NOT a prescribed
fix. The architect makes the call.

### User's hypothesis (priority to investigate first)

> "There may be a death timer or despawn clock on the dead companion
> that isn't being cleared when the rez succeeds, so the companion's
> underlying entity ticks forward and despawns at the originally-
> scheduled time even after the rez."

If the hypothesis holds, the fix surface likely includes:
- The function that schedules / sets the despawn timer when an NPC
  companion dies and drops its corpse.
- The rez success handler — wherever the companion entity is
  re-spawned / restored — must explicitly cancel or reset that
  despawn timer.

### Adjacent prior work to review

These recent merged fixes operate in directly adjacent code. The
architect should read them before proposing a fix to ensure no
regression and to spot if this bug is an incomplete extension:

- `cb95baa41 feat(companion-rez): implement full autonomous resurrection system`
  — original feature, baseline behavior.
- `83a96f655 fix(companion-rez): extend ST_Corpse guard + FindDeadGroupMemberCorpse for companion rez`
  — corpse-targeting behavior.
- `17662d4ba fix(companion-rez-v2): close BUG-001 V2 — rez pipeline group slot, alive guard, Spawn routing, atomicity`
  — rez pipeline invariants. Note: this previous "BUG-001" is a
  different BUG-001 from a different feature workspace; it is not the
  same bug as this PRD's BUG-001.
- `035d33348 fix(companion): Fix V Option A + Fix W α for BUG-002/004/005`
  and `84ac6a204 fix(companion): hoist heartbeat above all early-returns`
  — heartbeat invariants. These must continue to hold.
- `478d154bf fix(companion): name-based re-recruitment lookup handles multi-variant NPCs (BUG-036)`
  and `e230ee3 Merge bugfix/companion-rerecruit` (akk-stack) — re-recruit
  invariants V1+V2. Must continue to hold.

### Candidate code paths (advisory, not prescriptive)

- C++ companion lifecycle / death handling in `eqemu/zone/`
  (companion-related .cpp/.h files; the architect knows the names).
- `eqemu/zone/lua_companion.cpp` — luabind surface (per MEMORY: GAP-17
  resolved luabind inheritance issues here; relevant if entity_list
  retrieval paths touch the rez flow).
- `akk-stack/server/quests/lua_modules/` — companion.lua and adjacent
  modules. Heartbeat, dismissed flag, re-recruit logic.

### Suggested log-line targets for AC-6

If a despawn timer is the culprit, the engineer should add a log line
at the point the timer is cleared on rez, of the form:
`[companion-rez] cleared despawn-timer for entity_id=NNN on rez success`
This gives game-tester a positive signal that the fix path executed.

