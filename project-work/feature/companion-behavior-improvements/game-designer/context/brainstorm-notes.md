# Companion Behavior Improvements — Feature Brief

Three improvements to companion behavior identified during in-game testing.

## 1. Rogue Backstab Pathing (BUG-023)

**Problem:** Rogue companion takes a very wide circular arc to get behind enemies
for backstab positioning. Gets stuck on geometry in confined areas.

**Desired behavior:** Take a more direct line behind the enemy. Position a step
or two behind the mob (not on the exact same spot) to minimize shifting once
in position. The player is okay with a less "realistic" circling approach if
it means the rogue actually gets into position reliably.

**Affected system:** C++ companion AI positioning logic.

## 2. Caster LOM Announcement (BUG-024)

**Problem:** Caster companions silently run out of mana with no notification to
the player.

**Desired behavior:** All caster companions should group-chat "LOM" (Low On Mana)
when their mana drops to 15% or below. This mirrors real EQ player behavior.
Should only announce once per LOM state (not spam every tick while below 15%).

**Affected system:** C++ companion AI (mana monitoring) or Lua (group chat output).

## 3. !buffs Party Scope (BUG-025)

**Problem:** `/gsay @all !buffs` only causes casters to buff the player character.
Other companion NPCs in the group don't receive buffs.

**Desired behavior:** `!buffs` should buff ALL party members — player AND companions.
This is distinct from `!buffme` which correctly only buffs the player.

**Affected system:** Lua companion.lua / global_npc.lua buff timer handler.
