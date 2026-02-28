# BUG-003: Companion lost on logout/login

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-02-27
> **Feature:** feature-npc-recruitment
> **Status:** Open

---

## Observed Behavior

When the player logs out and logs back in, their recruited companion is
gone. The companion does not reappear in the group and is no longer
associated with the player.

## Expected Behavior

A recruited companion persists indefinitely until explicitly dismissed.
The companion should survive:
- Logout and login
- Zone transitions
- Server restarts
- Client crashes

A player might recruit an NPC at level 1 and keep that companion through
the entire game. The companion and all its memories (LLM context) should
persist across all sessions.

This is explicitly in the architecture spec: "Merc lifecycle patterns
for zone persistence: Save/Depop on zone-out, Load/Spawn on zone-in."

## Reproduction Steps

1. Log in and recruit an NPC as a companion
2. Verify companion is in group and functional
3. Log out (camp to character select or close client)
4. Log back in
5. Observe: companion is gone from group and not present in zone

## Evidence

Architecture doc specifies Merc lifecycle pattern. Implementation includes
SpawnCompanionsOnZone() method and companion_data table with persistence
columns. The save or load path (or both) may not be firing correctly.

## Affected Systems

_Check all that apply. These determine which expert agents are assigned
during triage._

- [x] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [x] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
