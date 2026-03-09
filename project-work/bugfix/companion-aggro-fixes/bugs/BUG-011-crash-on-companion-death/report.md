# BUG-011: Zone crash when companion dies in combat

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-03-08
> **Feature:** companion-aggro-fixes
> **Status:** Open

---

## Observed Behavior

When a companion NPC dies in combat, the zone process crashes. The game
freezes / "everything just sort of stopped." The zone process (dynamic_04,
Oasis of Marr) was the only process that died.

## Stack Trace

```
#4  Group::QueueClients (distance=-300) — groups.cpp:2600
#5  Client::Handle_OP_ClientUpdate — client_packet.cpp:5062
#7  Client::Process — client_process.cpp:625
```

Frame 3 is an unmapped address (`0x000063913dbb4da0 in ?? ()`) indicating
a null or dangling pointer dereference during group member iteration.

## Root Cause Hypothesis

When a companion dies in combat, its entity is cleaned up (depopulated or
marked dead), but the group still holds a pointer to it. The next time the
group iterates its members to broadcast packets (e.g., position updates via
`QueueClients`), it dereferences the now-invalid pointer and crashes.

The companion death path likely needs to properly remove the companion from
the group BEFORE the entity is cleaned up, or the group iteration needs
null-safety checks for member pointers.

## Expected Behavior

When a companion dies in combat:
- The companion should be removed from the group cleanly
- The group should update its member list before any further iteration
- No crash should occur
- The companion's death should be visible to the player (death animation,
  group window update)

## Reproduction Steps

1. Recruit companions into group
2. Engage in combat with mobs
3. Let a companion die (take lethal damage)
4. Observe: zone crashes

## Affected Systems

- [x] C++ server source -> c-expert
- [ ] Lua quest scripts -> lua-expert
- [ ] Perl quest scripts -> perl-expert
- [ ] Database / SQL -> data-expert
- [ ] Rules / Configuration -> config-expert
- [ ] Client protocol -> protocol-agent
- [ ] Infrastructure / Docker -> infra-expert
