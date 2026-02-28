# Phase 2 Brainstorm Notes — NPC Conversation Memory

## Key Design Decisions

### 1. Memory Is Atmospheric, Not Mechanical
The most important design decision: memory never grants gameplay advantages. It exists
purely for immersion. This prevents exploitation and keeps the feature firmly in the
"delight" category rather than the "players must engage to min-max" category.

### 2. Per-NPC-Type, Per-Character Memory
Memories are scoped to NPC type ID + player character ID. This means:
- Same NPC type across zones shares memory (e.g., Guard Hanlon in different instances)
- Different characters start fresh (consistent with in-world logic)
- Different NPC types are independent (no cross-NPC knowledge)

Considered alternatives:
- Per-spawn memory (different spawns are different entities): rejected because players
  expect "Guard Hanlon" to be the same person wherever they find him
- Per-zone + NPC type memory: rejected as over-complicated for 1-6 players

### 3. Topic-Relevant Retrieval over Chronological
Pinecone's semantic similarity search naturally returns topically relevant results.
This is better than "last 5 conversations" because it means the NPC references what
matters to the current conversation, not just the most recent exchanges.

### 4. No Memory at Hostile Factions
Threatening (8) and Scowling (9) NPCs refuse conversation in Phase 1. Storing or
retrieving memories for these NPCs would waste resources and create odd situations
(NPC remembers you but refuses to speak). Clean exclusion.

### 5. Faction Change as a Narrative Tool
One of the most interesting emergent behaviors: when a player's faction changes, the
NPC has memories from a different era of the relationship. A guard who remembers being
hostile to you but now sees you as friendly creates genuine narrative moments. This
happens naturally from the memory metadata (faction_at_time field).

### 6. 90-Day TTL with Recency Weighting
Long enough for infrequent players to benefit, short enough to prevent unbounded growth.
The recency weighting formula (from the integration plan) ensures fresh memories beat
stale ones when relevance scores are similar.

## Rejected Ideas

### Memory Tiers by NPC Role
Initially considered having guards remember less than guildmasters. Rejected because:
- Adds complexity for questionable benefit
- The 5-memory retrieval limit naturally constrains context
- A guard who remembers you well is a good experience, not a bad one
- Role-based memory scope is better suited for Phase 4's personality system

### Player-Visible Memory
Considered a "/remember" command to see what an NPC knows about you. Rejected because:
- Breaks immersion (meta-game interface)
- Players will naturally discover memory through conversation
- Admin clear endpoint covers the admin use case

### Memory Sharing Between NPCs
"NPC A tells NPC B about you" — deferred to Phase 4 cross-NPC gossip system.
Too complex for Phase 2 and opens difficult design questions about what gets shared.

## What Makes This Impactful for 1-6 Players

On a live server with hundreds of players, no individual player's relationship with
a specific NPC is meaningful — the NPC "sees" too many people. On our server, with
1-6 players, each player visits the same NPCs over and over. The Qeynos guard IS
your guard. The class guildmaster IS your guildmaster. Memory transforms these from
props that reset to characters that know you.

This is the single highest-impact improvement possible for world immersion on a
small-player-count server.
