# BUG-005: Companion 30-Minute Auto-Dismiss Timer Broken for Dead Companions

> **Severity:** Medium
> **Reported by:** c-expert (discovered during V3 Re-Triage architecture)
> **Date:** 2026-04-29
> **Feature:** companion-rez
> **Status:** Open

---

## Observed Behavior

Dead companion entities no longer auto-dismiss after 30 minutes
(`Companions:DeathDespawnS = 1800` rule). Since V2 landed, dead companions
remain in the zone indefinitely until they are rezzed or the zone restarts —
the auto-dismiss timer never fires.

This was discovered by c-expert during the V3 Re-Triage enumeration (finding
C-5 / area B.2). It is a latent regression introduced by V2 Fix R4.

## Expected Behavior

When a companion dies and is not rezzed within `Companions:DeathDespawnS`
seconds (default 1800s = 30 minutes), the dead entity should auto-dismiss:
depop from the zone and set `is_suspended=1` / `is_dismissed=true` in
`companion_data`. This is the mechanism that prevents indefinitely-accumulating
corpse-less dead entities in the zone.

## Reproduction Steps

1. Recruit a companion.
2. Kill the companion in combat (do not rez it).
3. Wait 31+ minutes without rezzing.
4. Observe: companion entity remains in zone, occupying a group slot,
   never auto-dismisses. The 30-minute cleanup does not fire.

## Evidence

**Root cause confirmed by c-expert (V3 Re-Triage Round 1, area B.2):**

V2 Fix R4 at companion.cpp:1933-1935 added:

  if (GetHP() <= 0) return NPC::Process();

This early-return fires for dead companion entities (HP=0, kept alive by
SetDepop(false) in Companion::Death()). The return bypasses the entire
Companion::Process() body, including the m_death_despawn_timer block
at companion.cpp:1937-1964 which drives the 30-minute auto-dismiss.

Pre-V2 baseline: dead companions ran the full Companion::Process() body
(no top-level guard); the despawn timer fired after DeathDespawnS seconds,
auto-dismissed the entity, wrote is_dismissed=true + is_suspended=1 to
companion_data, and called Depop().

Post-V2: dead companions skip the despawn timer block, never auto-dismiss,
accumulate as permanent zone residents until rez or server restart.

The same Fix R4 guard also causes BUG-002 (visibility heartbeat regression):
the m_ping_timer heartbeat at companion.cpp:2128-2142 is similarly bypassed.

**Bundled fix:** BUG-005 is fixed for free by the BUG-002 Fix V Option A
restructure. Moving the despawn timer block outside the if (!is_dead) guard
alongside the heartbeat restores both behaviors with zero additional code
surface. The fix is already planned in the V3 Re-Triage architecture.

## Affected Systems

- [x] C++ server source -> c-expert (Companion::Process() restructure, Fix V Option A)
- [ ] Lua quest scripts -> lua-expert
- [ ] Perl quest scripts -> perl-expert
- [ ] Database / SQL -> data-expert
- [ ] Rules / Configuration -> config-expert
- [ ] Client protocol -> protocol-agent
- [ ] Infrastructure / Docker -> infra-expert

## Investigation Hints

- companion.cpp:1933-1935 -- V2 Fix R4 early-return (root cause)
- companion.cpp:1937-1964 -- m_death_despawn_timer block (currently bypassed)
- companion.cpp:2128-2142 -- m_ping_timer heartbeat block (also bypassed; BUG-002)
- Fix: both blocks move outside if (!is_dead) guard in Fix V Option A restructure
- Rule: Companions:DeathDespawnS = 1800 (30 minutes; confirmed correct in DB)
- No DB schema change, no Lua change, no rule change needed

## Severity Justification

**Medium** -- functional gap (zombie dead entities accumulate in zone) but not
immediately player-visible. No data corruption risk; is_suspended=1 row in
companion_data was already written at Death() time. Zone slot and group slot
remain occupied until server restart. At 1-3 player scale the practical pain
is low; at high death frequency (repeated wipes) the group slot leak is
significant.

## Cross-Reference

- **BUG-002** -- Same root cause (Fix R4 early-return); same fix (Fix V Option A)
- **V3 Re-Triage** -- Discovered during customized-system enumeration (c-expert C-5)
- Architecture: companion.cpp:1933-1935 Fix R4 + companion.cpp:1937-1964 despawn timer
