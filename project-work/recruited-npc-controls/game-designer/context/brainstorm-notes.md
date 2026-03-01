# Command Prefix Brainstorm Notes

## Problem Summary
Current companion commands use keyword matching via /say. This collides with
natural conversation -- saying "follow the trail" triggers follow mode, saying
"leave the castle" triggers dismissal. The LLM conversation system makes this
worse: players WANT to talk freely to companions, but any message containing
a keyword triggers a command instead.

## Key Technical Findings (from c-expert audit)

- `#` = GM commands (COMMAND_CHAR, C++ hardcoded)
- `^` = Bot commands (BOT_COMMAND_CHAR, C++ hardcoded)
- Pet commands use OP_PetCommands packet, not chat text
- `!` is available, not intercepted by any C++ system
- Implementation is pure Lua -- no C++ changes needed
- global_npc.lua checks: IsCompanion() management > recruitment > LLM
- Per-NPC scripts take priority over global_npc.lua

## Lore-Master Input Summary

- Avoid abbreviated prefixes (c, comp) -- feels like text messaging
- Name-based prefix most immersive but complex (NPC name parsing)
- Symbol prefix acceptable -- players already accept # and ^
- All current command vocabulary is era-clean
- Command responses should stay terse (1-2 sentences)

## Design Approaches Considered

### Approach A: Symbol Prefix (! recommended by c-expert)
- `!follow`, `!guard`, `!dismiss`, `!passive`, `!help`
- Everything without ! goes to LLM for natural dialogue
- Consistent with EQ's existing # and ^ conventions
- Pure Lua implementation
- PRO: Simple, discoverable, no collision risk
- CON: Not immersive -- mechanical command prefix

### Approach B: Name-Based Prefix (lore-master's top pick)
- "Monia, follow" or "Guard Tael, guard here"
- Most immersive -- you're addressing your companion by name
- PRO: Natural language, in-character
- CON: NPC names have spaces ("a Qeynos guard"), parsing is complex
- CON: What if two companions have similar names?
- CON: Companion names can be anything (recruit-any-NPC)
- VERDICT: Beautiful idea but too fragile for primary system

### Approach C: Hybrid -- Symbol primary + name-based as enhancement
- `!follow` always works (primary, reliable)
- "Monia, follow" also works (optional, immersive alternative)
- Best of both worlds but more implementation complexity
- VERDICT: Could be done as Phase 2 enhancement

## Recommended Approach: Symbol Prefix with `!`
- Primary: `!command` syntax for all management commands
- Unprefixed speech to companions goes to LLM conversation
- `!help` lists all available commands
- Recruitment commands stay keyword-based (these are one-time, spoken
  to non-companions, and the natural phrasing IS the experience)

## New Commands to Consider
1. `!status` -- show companion stats/level/HP/stance at a glance
2. `!name <name>` -- rename companion (cosmetic)
3. `!who` -- list all active companions and their stances/modes
4. `!target` -- have companion target your current target
5. `!assist` -- companion assists you in combat
6. `!cast <spell>` -- tell companion to use a specific spell/ability
7. `!equip` -- open trade window to give equipment (vs. current "give me your" verbal)
8. `!recall` -- summon companion to your location if stuck/lost

## Equipment Management Refinement
Current system: verbal commands only (show equipment, give me your <slot>)
Problem: giving items TO a companion requires... what? Currently not in the system.
The trade window is the EQ-native way to exchange items.
Proposal: `!equip` opens a trade window with the companion for item exchange.

## Edge Cases
1. Player says `!follow` with a non-companion NPC targeted -- error message
2. Player says `!follow` with no target -- error message  
3. Player says `!invalidcommand` -- help suggestion
4. Player says `!` alone -- show help
5. Multiple companions -- which one gets the command? The targeted one.
6. Command while in combat -- some commands should be restricted
7. Recruitment stays keyword-based, not prefixed -- intentional design choice
