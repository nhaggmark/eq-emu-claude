# BUG-005: Companion AI commands unresponsive — stance, guard, and combat assist

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-02-28
> **Feature:** feature-npc-recruitment
> **Status:** Open

---

## Observed Behavior

1. **Stance commands** (passive, aggressive, balanced) — produce no visible
   effect. The companion does not change behavior.
2. **Guard command** — produces no visible effect. The companion does not
   stop moving or hold position.
3. **Combat assist** — when the player is attacked, the companion does not
   come to their aid. The companion is passive/unresponsive during combat.

## Expected Behavior

- Stance commands should change the companion's combat behavior:
  - **Aggressive**: companion attacks anything that attacks the owner
  - **Passive**: companion does not engage in combat
  - **Balanced**: companion assists owner but uses abilities conservatively
- **Guard** should make the companion stop and hold position
- By default, the companion should assist the owner when the owner is attacked

## Reproduction Steps

1. Log in with an active companion
2. Say "aggressive" — no visible change
3. Say "guard" — no visible change
4. Get attacked by a mob — companion does not assist

## Evidence

BUG-004 fix confirmed the Lua → C++ binding path now works (dismiss
succeeded). The commands may be reaching the C++ methods but the AI
is not acting on the stance/state changes. Alternatively, the companion
AI combat loop may not be processing at all.

## Affected Systems

- [x] C++ server source → c-expert (companion AI: companion_ai.cpp, AI loop)
- [x] Lua quest scripts → lua-expert (command handlers in companion.lua)
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
