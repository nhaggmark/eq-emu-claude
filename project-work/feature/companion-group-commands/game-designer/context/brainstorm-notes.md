# Feature Brief: Companion Group Commands

## Overview
9 new commands for interacting with NPC companions via group chat, using the existing `@name` / `@all` addressing system.

## Commands

### !status
Report companion state: HP (current/max), mana (current/max), current stance (aggressive/balanced/passive), current target, sit/stand state, and full buff list with minutes remaining on each buff.

### !buffme
Queue the targeted companion to refresh their available buffs on the player only. Does NOT interrupt current activity — waits for the next idle window. Only works on caster companions with buff spells.

### !buffs
Queue the targeted companion to refresh their available buffs on all party members. Same queuing behavior as !buffme — waits for idle window. Only works on caster companions with buff spells.

### !tome
Command the companion to come to the player's current location. ("To me")

### !flee
Macro command that chains: set passive stance + come to player location + follow player. Does NOT clear the companion's hate list — this is meant to be realistic, as if telling a real player to run away. Mobs will continue to chase/aggro the fleeing companion.

### !assist
Command the companion to attack the player's current target. If the companion is currently in passive stance, automatically switch them to balanced stance first, then engage the target.

### !help
Display a complete list of ALL companion commands (both existing and new) with brief descriptions of each. This is the player's reference card for the companion system.

### !equipmentupgrade
Player links an item in chat. The companion evaluates whether the linked item is an upgrade for them:
- First checks if they can actually wear the item (class, race, type restrictions)
- If they can't wear it, no response
- If they can wear it, compares against their current item in the appropriate slot
- Comparison uses simple stat sum: AC + all stats (STR, STA, AGI, DEX, WIS, INT, CHA, HP, Mana) for armor; DPS + all stats sum for weapons
- Responds YES (it's an upgrade) or NO (current is better) and links their currently equipped item for manual inspection
- If the slot is empty, always responds YES

### !equipmentmissing
Companion lists ALL equipment slots that currently have no item equipped. Lists every empty slot regardless of class — the player decides what matters.

## Design Constraints
- All commands target the specific companion addressed (use @all for broadcast to all companions)
- Buff commands (!buffme, !buffs) queue for idle, never interrupt combat
- !flee is realistic — no hate clearing, companions will still be chased
- !equipmentupgrade stat comparison is intentionally simple — gives actionable info, not perfect optimization
- Must have comprehensive test coverage for all commands
- Follow existing command handling patterns in the codebase
