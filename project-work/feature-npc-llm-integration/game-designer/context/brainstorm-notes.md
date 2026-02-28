# Phase 1 PRD — Brainstorm & Research Notes

## Database Landscape

- 67,530 total NPC types in database
- 61,289 unique NPCs actually spawned in world
- ~7,718 zone-specific quest scripts (4,065 Lua + 3,653 Perl)
- ~48,000+ spawned NPCs with no quest script and INT >= 30 (the target population)
- 4,894 NPCs with INT < 30 (animals, mindless undead, insects)
- 10,829 NPCs have emotes assigned (16% of total)
- 40,681 NPCs have faction assignments

### Body Type Analysis
- Body type 21 (Animal): 5,317 NPCs
- Body type 11 (Untargetable): 2,218 NPCs  
- Body type 33 (Plant): 686 NPCs
- Body type 28 (No Target): 119 NPCs

### Class Distribution (top 5)
- Class 1 (Warrior): 41,398 — vast majority, includes guards
- Class 9 (Rogue): 4,201
- Class 2 (Cleric): 2,940
- Class 12 (Wizard): 2,719
- Class 10 (Necromancer): 2,546

### Faction System
- 9 faction levels: FACTION_ALLY(1) through FACTION_SCOWLS(9)
- Defined in eqemu/common/faction.h
- Lua access: e.other:GetFactionLevel(...) returns int matching enum

## Design Approaches Considered

### Approach 1: Broad Rollout (CHOSEN)
Every unscripted NPC with INT >= 30 gets LLM conversations. Global hook catches all.
- Pro: Maximum world-alive feeling, zero per-NPC configuration needed
- Pro: global_npc.lua naturally only fires for unscripted NPCs
- Con: ~48K NPCs eligible, quality may vary
- Mitigation: Per-NPC opt-out via data buckets

### Approach 2: Conservative Rollout (REJECTED)
Start with specific NPC roles in starting cities only.
- Pro: More controlled, easier to test
- Con: Smaller impact, requires manual NPC selection
- Con: Defeats the purpose of the global hook approach

### Approach 3: Opt-in Per Zone (REJECTED)
Enable LLM zone-by-zone via data bucket flags.
- Pro: Gradual expansion
- Con: Requires configuration work per zone
- Con: Players notice inconsistency between zones

## Key Design Decisions

1. **9-level faction mapping** (not 6): Used all 9 EQ faction levels for full granularity
2. **Scowling cooldown**: 60-second ignore after one hostile line to prevent spam
3. **No quest fabrication**: LLM instructed never to offer quests or promise rewards
4. **Typing indicator**: Emote fires before LLM call for instant feedback
5. **Opt-out not opt-in**: Default is enabled for maximum coverage
6. **INT >= 30 threshold**: Matches ~4,894 excluded creatures, feels right for animals/mindless

## Existing Infrastructure

- json.lua module already exists in lua_modules (JSON4Lua)
- global_npc.lua currently only has event_spawn (Halloween costumes) — event_say can coexist
- Quest dispatch chain: local script -> global_npc.lua -> default.lua
- Say channel = 8, requires player targeting NPC within 200 units
- NPC response via Mob::Say() → MessageCloseString() → OP_FormattedMessage
