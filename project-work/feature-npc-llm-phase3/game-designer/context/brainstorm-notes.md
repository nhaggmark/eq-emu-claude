# Phase 3: Soul & Story — Brainstorm Notes

## Research Findings

### Current System State (as of Phase 2.5)
- Prompt assembler has 8 layers; Layer 6 is a placeholder for soul elements
- `global_contexts.json` has 14 npc_overrides, ~14 race entries, ~27 race_class entries, ~22 race_class_faction entries
- `llm_bridge.lua` has eligibility checks, hostile cooldown, thinking indicators
- `global_npc.lua` handles Tier 1 (unscripted NPC) LLM fallback
- No quest scripts currently use Tier 2 (script + LLM fallback)
- Token budgets: global=200, local=150, soul=0, memory=200

### Design Decisions Made

1. **Backstory approach: Hybrid** — Templates for common roles, hand-written for lore NPCs.
   Chose this over pure manual (too slow) or pure template (too generic).

2. **Quest hints location: In quest scripts** — Co-locating hints with quest logic
   keeps everything in one file. Rejected external config file (harder to maintain,
   context separated from code).

3. **Soul element axes: 5 pairs** — Courage, Generosity, Honesty, Piety, Curiosity.
   Chose -3 to +3 scale for granularity without complexity. Rejected boolean (too flat)
   and 0-100 (too precise for narrative use).

4. **Recruitment disposition: 5-tier scale** — Rooted/Content/Curious/Restless/Eager.
   Intentionally broad categories, not numeric scores. Phase 3 = dialogue influence only,
   Phase 4 = actual mechanics.

5. **Perl scripts out of scope** — LLM bridge is Lua-only. Converting Perl to Lua is
   separate work. Keeps scope manageable.

6. **No async C++ binding** — Current sync curl works for 1-6 players. Deferred to
   future phase.

### Risks Identified
- Token budget pressure: adding quest hints + soul elements adds ~300 tokens to prompts
- Author burden: 80-110 backstories is significant content authoring work
- Consistency checking: soul elements must match faction/deity/race constraints
- Say-link auto-injection: need to verify server rule handles LLM-generated [brackets]

### Open Items for Architect
- Soul element storage format (in global_contexts.json vs separate file)
- Quest hint injection layer position in prompt assembler
- NPC role detection for default soul elements
- Hot-reload mechanism for soul data
- Say-link compatibility with LLM output
