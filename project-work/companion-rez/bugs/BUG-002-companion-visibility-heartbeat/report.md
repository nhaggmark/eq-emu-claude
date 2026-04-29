# BUG-002: NPC Companion Visibility Heartbeat Regressed in Combat

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-04-28
> **Feature:** companion-rez
> **Status:** Open

---

## Observed Behavior

In combat, NPC companions vanish from the player's screen if they don't move for several seconds. They reappear when they next move. This is a regression — a long-time prior bug that was previously fixed via a "heartbeat" mechanism that kept the entity visible.

The user observed this immediately after the V2 companion-rez fix landed. The rez itself works (V2-1 canonical scenario passed — Jimble was rezzed). But the visibility heartbeat appears broken specifically during combat.

User's verbatim report:
> "A long time ago we fixed an issue where my NPC companions would vanish off of the screen if they don't move for a number of seconds during combat. That bug seems to have returned. Something that was changed seems to have disrupted a heartbeat that was kept that prevented the NPC companions from vanishing from the screen until they move again. This only seems to be happening in combat."

## Expected Behavior

NPC companions remain visible to the player during combat regardless of movement. The "heartbeat" (whatever mechanism the prior fix introduced) keeps the entity in the client's render set or sends periodic position updates so the client doesn't cull the entity.

## Reproduction Steps

1. Recruit one or more NPC companions
2. Engage a mob in combat
3. Allow combat to play out — observe a stationary companion (e.g., a caster who hasn't moved)
4. After several seconds of no movement, the companion vanishes from the client view
5. Forced movement (e.g., aggro shift) brings them back into view

## Evidence

- Reproduces consistently after V2 companion-rez fix landed (eqemu commits `b8c771a4f` test, `17662d4ba` fix)
- Did NOT reproduce immediately before V2 (V1 was in place)
- Strong suspect: **Fix B** in V2 routed `ResurrectFromCorpse` through `Spawn(owner)` instead of manual `AddNPC + setup`. This is the most likely place the entity-list registration changed in a way that affects visibility ticks.
- The fix may also affect newly-recruited or newly-spawned companions, not just rezzed ones — depends on whether the `Spawn(owner)` path is shared with normal recruitment or only used post-rez.

## Affected Systems

- [x] C++ server source → c-expert (entity-list registration, AI tick, visibility/heartbeat path)
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [x] Client protocol → protocol-agent (position updates, entity visibility opcodes)
- [ ] Infrastructure / Docker → infra-expert

## Investigation Hints

- Search the eqemu codebase for the prior heartbeat fix — likely in `Companion::Process()`, `NPC::Process()`, or related AI tick loop
- Check whether `Spawn(owner)` in `companion.cpp:3643-3727` (Fix B) registers the companion in the same entity list / processing list as the prior `AddNPC` path did
- Check whether visibility-related state (e.g., last position update timestamp, AI processing flags) is initialized correctly through the `Spawn()` path
- Diff the manual-setup path (pre-V2) vs the Spawn-routed path (V2) — what's missing on the Spawn path?
- Check `Mob::SendPosUpdate` or similar — is it being called at the right cadence during combat?

## Severity Justification

**High** — companions disappearing from view during combat is a major gameplay disruption. Players can't see their party, can't track companion HP/positioning, can't tell if companions are alive or dead. This affects every combat encounter, not edge cases.
