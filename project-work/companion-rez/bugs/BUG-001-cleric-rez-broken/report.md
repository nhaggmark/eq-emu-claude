# BUG-001: Cleric Companion Rez Broken — NPC Companion Stays Down After Attempted Rez

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-04-27
> **Feature:** companion-rez
> **Status:** Open

---

## Observed Behavior

After combat ends and an NPC companion falls, the Cleric NPC companion is
observed attempting to cast a rez spell on the downed party member. The rez
attempt is visually or mechanically observable, but the target (NPC companion
or player) is not actually rezzed — the corpse remains down and the companion
does not return to the party.

User's verbatim description:
> "When we end a fight and one of my NPC companions falls, the Cleric NPC
> companion should be able to rez the party member. This is currently broken."
>
> "I can see that he's attempting to rez but nothing happens. The NPC
> companion does not return."

## Expected Behavior

**The invariant:** When combat ends and a party member (player OR NPC
companion) is down, a Cleric NPC companion in the party should automatically
rez them so the group can keep playing. Rez after a fight is crucial to
gameplay tempo for 1-3 player small-group play.

Specifically:
- Cleric NPC companion should scan for downed party members automatically
  at the end of a fight (no player input required)
- The rez should succeed and restore downed NPC companions AND the player
- Post-rez, the rezzed companion should return to the party and be playable

## Reproduction Steps

1. Have a Cleric NPC companion in the party
2. Enter combat with enemies alongside at least one other NPC companion (or
   let the player die)
3. Allow the non-Cleric party member (or player) to die during the fight
4. Win the fight and wait for the Cleric to attempt the rez
5. Observe: the Cleric attempts to cast rez but the corpse remains down

## Evidence

- User reports the rez attempt is observable (spell cast animation / messaging
  is visible) but has no effect
- No additional logs or screenshots captured at time of report

## Working Hypothesis (UNVERIFIED -- for architect to validate or reject)

The Cleric's rez spell may be cast successfully and create a rez request
(as in standard EverQuest behavior), but the NPC companion corpse has no UI
to "accept" the rez. In live EQ, a rez creates a request the corpse owner
must confirm via a dialog box -- NPCs have no such UI and thus cannot confirm.

Two possible fix paths for the architect to evaluate:
1. Auto-accept logic for NPC companion corpses: when the rez target is an
   NPC companion, automatically accept the rez request server-side
2. Bypass the rez request mechanism entirely for NPC targets: apply the rez
   effect directly without going through the request/accept flow

This hypothesis is NOT confirmed. The architect must investigate the actual
rez code path (RezzPlayer, OP_RezzAnswer, OP_RezzRequest, etc.) and
determine the true root cause.

## Reference Docs / Files for Architect

- Companion AI: eqemu/zone/companion.cpp -- death/rez/recruit lifecycle.
  See death handling at companion.cpp:1888-1913 and is_suspended state
  semantics (confirmed in companion-rerecruit architecture)
- Companion Lua module: akk-stack/server/quests/lua_modules/companion.lua --
  recruit/dismiss/death paths (touched by companion-rerecruit v1+v2 fix)
- Spell-cast logic for NPCs: eqemu/zone/spells.cpp, eqemu/zone/npc.cpp
- Rez confirmation UI path: search C++ for RezzPlayer, OP_RezzAnswer,
  OP_RezzRequest
- Companion death state: is_suspended flag in companion_data table (used
  as death state per companion-rerecruit architecture)
- Prior art: claude/project-work/companion-rerecruit/architect/architecture.md
  for companion lifecycle context

## Affected Systems

- [ ] C++ server source -> c-expert (rez confirmation / auto-accept logic)
- [ ] Lua quest scripts -> lua-expert (Cleric companion post-combat behavior / rez trigger)
- [ ] Perl quest scripts -> perl-expert
- [ ] Database / SQL -> data-expert (companion_data is_suspended death state, if relevant)
- [ ] Rules / Configuration -> config-expert
- [ ] Client protocol -> protocol-agent (OP_RezzAnswer / OP_RezzRequest flow)
- [ ] Infrastructure / Docker -> infra-expert

## Out of Scope

- Player-commanded rez (!rez) -- automatic rez only; manual rez is a
  separate feature
- Charm pets, swarm pets, mercenaries -- different system and death model
- Real-player party members beyond the player + recruited companions
- Spell selection (which rez spell to cast) -- architect/c-expert decides
