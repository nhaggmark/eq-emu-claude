# BUG-004: Player Harmful AoE Spells Affect Own NPC Companions

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-04-29
> **Feature:** companion-rez
> **Status:** Open

---

## Observed Behavior

When the player casts a harmful AoE spell (e.g., AoE mez, AoE stun), the
spell affects the player's own NPC companion party members in addition
to (or instead of) the intended enemy targets. The companions get mezzed
or stunned by their own player's AoE.

User's verbatim report:
> "an additional regression i noted is that my harmful AoE spells (mez,
> stun) affect my party NPC companions as well as the enemies, which I
> don't believe should be the case."
>
> "when i cast a harmful AoE spell like my mez or stun it also stuns and
> mez's my NPC companions which should not happen"

The user reported this in the same window as BUG-002 (visibility
heartbeat regression) and BUG-003 (regen regression), both of which
followed the V2 companion-rez fix. This is the third regression in the
same family.

## Expected Behavior

Player-cast harmful AoE spells (debuffs, mez, stun, etc.) should respect
the friend/foe filter — the player's own NPC companions are party
members and must NOT be valid targets for the player's own harmful
AoE effects.

This is the standard EverQuest behavior: AoE friend-or-foe targeting
treats group members and pets as "friend" and excludes them from the
hostile-target sweep performed by player-cast harmful AoE spells.

## Reproduction Steps

1. Recruit one or more NPC companions
2. Engage at least one enemy mob in combat
3. Position so that companions are within the AoE radius alongside
   the enemy
4. Cast a player harmful AoE spell — e.g.:
   - AoE mez (Bind Sight / Lull / etc., depending on caster class)
   - AoE stun
5. Observe that companions take the debuff (mez / stun) along with
   (or instead of) the intended enemy

## Evidence

- Reproduces consistently after V2 companion-rez fix landed
  (eqemu commits `b8c771a4f` test, `17662d4ba` fix)
- Member of the same regression family as BUG-002 (visibility heartbeat)
  and BUG-003 (regen). Strong correlation — all three suggest that
  V2's entity-registration changes affected downstream subsystems that
  filter "is this entity a companion / friendly party member"
- The friend/foe AoE filter likely consults the same group-membership
  / companion-list metadata that:
  - The visibility heartbeat consumes (BUG-002)
  - The regen tick consumes (BUG-003)
  - The pet/charm exclusion in Mob::AreYouMyPet / IsPetOwner /
    GetGroup() / similar consumes for AoE friendly-fire
- Possible causes:
  - **Fix B** in V2 routed `ResurrectFromCorpse` through `Spawn(owner)`.
    If the new path differs from the manual setup in how the companion
    is registered as a group/raid/pet member of the owner, the AoE
    target sweep may not see the companion as friendly
  - **Fix A** in V2 clears `membername[]` slot at Death — if the
    re-population path on rez/spawn doesn't restore the slot the same
    way the manual path did, group-membership filters miss the companion
  - **Pre-existing** bug exposed by V2 — possible the "AoE excludes
    own companions" logic was implicit in the old entity-registration
    path and was never explicitly coded for companions

## Affected Systems

- [x] C++ server source → c-expert (AoE target selection, friend/foe
      filter, group-membership lookup, companion entity registration)
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert (verify whether any rule
      controls companion-friend-fire policy and whether it is set
      correctly for this server)
- [x] Client protocol → protocol-agent (verify spell target packet
      flags and AoE radius computation honor the friend/foe filter)
- [ ] Infrastructure / Docker → infra-expert

## Investigation Hints

- Search the eqemu codebase for AoE target selection — likely
  `EntityList::AESpell`, `Mob::AreYouMyPet`, `Mob::IsPetOwner`,
  `Mob::GetOwner`, `Mob::CheckSpellSafe`, and the AoE radius sweep
  that builds the spell's target list
- Check whether companions are correctly identified as "owner's pet"
  or "owner's group member" by the AoE filter — V2's `Spawn(owner)`
  reroute may have changed the answer
- Diff the manual-setup companion registration path (pre-V2) vs the
  Spawn-routed path (V2) — does Spawn correctly set `m_owner` or
  the equivalent ownership pointer that the friend/foe filter consults?
- Verify whether companions are being registered as "pet" of the owner
  (which would put them in the `EntityList::AreYouMyPet` exclusion)
  vs "group member" (which would put them in the group-membership
  exclusion). The custom companion system may use a different
  registration that the AoE filter doesn't know about
- Check `RuleB(Pets, AESpellHittingPet)` and similar rules — there
  may be a pet/companion friend-fire toggle that is incorrectly
  defaulted for the custom companion system

## Severity Justification

**High** — player AoE spells (especially mez and stun) self-inflicting
on companions makes the player unable to use AoE crowd control without
breaking their own party. CC-class players (Enchanter mez, etc.) are
crippled; melee players using AoE stun cannot rely on the spell. This
is a sustained-play regression that impacts every encounter where
companions are within AoE radius.

## Cross-Reference

This bug is a member of the **V2 entity-registration regression family**
along with BUG-002 (visibility heartbeat) and BUG-003 (regen). Architect
should treat all three as a single triage cluster and enumerate every
downstream subsystem that consumes companion entity-list / group /
ownership metadata before designing the V3 fix. See
`feedback_refactor_regression_discipline.md` for the user's standing
discipline directive on refactor regressions.
