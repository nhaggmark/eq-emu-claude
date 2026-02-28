# NPC Conversation Memory (Pinecone Integration) — Product Requirements Document

> **Feature branch:** `feature/npc-llm-integration`
> **Author:** game-designer
> **Date:** 2026-02-24
> **Status:** Draft
> **Lore review:** Approved with notes by lore-master (2026-02-24) — Scenario 7 added per revision request

---

## Existing Planning Docs

- `claude/docs/NPC-CONVERSATION-SYSTEM.md` — deep dive into existing NPC chat system
- `claude/docs/plans/2026-02-23-llm-npc-integration-plan.md` — full integration plan (all phases), Section 5 covers Pinecone memory
- `claude/project-work/feature-npc-llm-integration/game-designer/prd.md` — Phase 1 PRD (stateless conversations)
- `claude/project-work/feature-npc-llm-integration/architect/architecture.md` — Phase 1 architecture

This PRD covers **Phase 2 (Memory) only** — adding persistent conversation memory via Pinecone vector database so NPCs remember past interactions with individual players. Phase 1 (stateless LLM conversations) must be complete before Phase 2 begins.

---

## Problem Statement

Phase 1 gave ~45,000 silent NPCs the ability to hold a conversation. A player can walk up to a Qeynos guard and ask about local threats, and the guard responds in character with faction-appropriate dialogue. This is a dramatic improvement over silence.

But every conversation starts from zero. The guard who told you about gnoll raids yesterday has no memory of the exchange today. The merchant you chatted with about trade routes in the Commonlands greets you as a stranger every time. The Freeport militia guard who warned you to leave last week delivers the exact same warning today, with no awareness that you have been here before.

On a 1–6 player server, this lack of continuity is especially noticeable. With only a handful of players, each player visits the same NPCs repeatedly — the same city guards, the same class guildmaster, the same local merchants. These are "their" NPCs in a way that does not exist on a server with thousands of players. When those NPCs cannot remember them, the world feels like it resets every time the player logs in.

Memory transforms NPCs from responsive props into something closer to inhabitants. A guard who remembers you helped with the gnoll problem and asks how it went. A merchant who remembers you were heading east and asks if you made it back safely. A guildmaster who remembers your last training visit and comments on your progress. These small continuities create the feeling that the world persists when the player is away — that their actions have been noticed and retained.

This is also the foundation for richer NPC relationships in later phases. Phase 3's quest integration and Phase 4's NPC personality system both benefit from memory. A quest NPC who remembers you asked about Blackburrow can guide you more naturally. A recruitable companion who remembers traveling with you has a deeper sense of partnership. Memory is the bridge from "NPCs that talk" to "NPCs that know you."

## Goals

1. **NPCs remember individual players across sessions** — When a player returns to an NPC they have spoken with before, the NPC references relevant details from past conversations naturally. A guard who told the player about gnoll raids remembers the exchange and asks for an update. A merchant who discussed trade routes recalls the topic.

2. **Memory is contextually relevant, not total recall** — NPCs do not recite transcripts of past conversations. They recall the most relevant past exchanges based on what the player is currently saying. If the player asks about gnolls, the NPC remembers the gnoll-related conversation, not the one about the weather three weeks ago. Irrelevant or very old memories naturally fade.

3. **Memory reflects the NPC's character** — A guard remembers security concerns and your helpfulness (or lack thereof). A merchant remembers trade topics and your purchases. A scholar remembers knowledge you shared or inquired about. Memory content is shaped by what the NPC would plausibly retain, not by raw data storage.

4. **Memory enhances faction progression** — When a player's faction standing changes over time, NPCs with memories of the old standing acknowledge the shift. A guard who was hostile to you last month but now sees you as friendly might say "I remember when you were not welcome in these parts." This makes faction work feel more impactful and personal.

5. **Memory creates a sense of world persistence** — On a 1–6 player server, players should feel that the world remembers them. Coming back to a city after a long adventure and having guards recognize you, merchants ask how your journey went, and guildmasters note your growth creates the feeling of a living, persistent world.

6. **No gameplay advantage from memory** — Memory is entirely atmospheric. NPCs never reveal quest solutions, grant items, share secrets, or provide mechanical advantages because they remember a player. Memory enhances immersion, not power.

7. **Admin control over memory** — Server administrators can clear all memories for a specific NPC, a specific player, or a specific NPC-player pair. This enables cleanup after bad interactions, testing, or character resets.

## Non-Goals

- **No NPC backstory seeding** — Pre-seeding NPC namespaces with lore/backstory vectors is Phase 4. Phase 2 memories come only from actual player conversations.
- **No cross-NPC memory sharing** — NPC A does not know what you told NPC B. Each NPC's memory is completely independent. Cross-NPC gossip is Phase 4.
- **No quest script integration** — Memory does not interact with scripted quest NPCs. Those NPCs still use their keyword-based scripts. Quest integration with memory is Phase 3.
- **No memory-based behavior changes** — An NPC with memories of a player does not change its faction standing, offered services, or mechanical behavior. Memory affects only dialogue content.
- **No player-visible memory interface** — Players cannot view, manage, or delete their memories with NPCs. There is no "relationship status" UI. The memory is experienced only through conversation.
- **No memory for Threatening/Scowling NPCs** — NPCs at Threatening (8) or Scowling (9) faction do not store or retrieve memories. They refuse conversation (Phase 1 behavior), so there is nothing to remember.
- **No C++ server modifications** — Phase 2, like Phase 1, requires no changes to the EQEmu server source. Memory logic lives entirely in the Python sidecar.
- **No Lua bridge changes** — The existing Lua bridge sends the same request payload as Phase 1. The sidecar handles memory internally. No changes to `llm_bridge.lua`, `llm_config.lua`, or `global_npc.lua` are required.

## User Experience

### Player Flow

1. **First visit — same as Phase 1.** The player approaches an unscripted NPC and speaks. The NPC responds with faction-appropriate, in-character dialogue. This is identical to the Phase 1 experience. Behind the scenes, the exchange is stored as a memory.

2. **Return visit — the NPC remembers.** The player returns to the same NPC (same NPC type) later — hours, days, or weeks later. When the player speaks, the NPC's response weaves in relevant details from past conversations. This is the visible difference from Phase 1.

3. **Memory is natural, not mechanical.** The NPC does not say "I recall our conversation on February 15th at 3:47 PM." It says things like "Ah, you are the one who asked about the gnolls. Did you venture into Blackburrow?" or "Back again? Last time you were heading east toward the desert." The memory feels like natural human recall — impressionistic, focused on the important parts, and occasionally hazy.

4. **Memory is topic-sensitive.** If the player talked to a guard about gnolls last week and about the city gates yesterday, and today asks about gnolls again, the NPC recalls the gnoll conversation, not the gates conversation. The most relevant past exchanges surface based on what the player is currently discussing.

5. **Memory fades over time.** Very old conversations (90+ days) are eventually cleaned up. Recent exchanges are prioritized over distant ones. A conversation from yesterday is more likely to be referenced than one from two months ago, unless the older one is highly relevant to the current topic.

6. **Faction shifts are acknowledged.** If a player's faction standing has changed since their last conversation, the NPC may acknowledge the change. A guard who remembers hostility now seeing friendliness, or vice versa, creates a sense that the NPC has an actual opinion about the player's trajectory.

### Example Scenarios

**Scenario 1: Guard Remembers a Previous Conversation**

Day 1 — A level 12 half-elf ranger with Ally faction speaks to Guard Hanlon in South Qeynos:

> /say What should I watch out for around here?

*Guard Hanlon considers your words carefully...*

> Guard Hanlon says, 'The Sabertooth gnolls have been pushing closer to the city walls of late. If you are heading toward Qeynos Hills, stay on the road and keep your weapons ready. Rodcet Nife watch over you.'

Day 3 — The same ranger returns, now level 14:

> /say Hail, guard.

*Guard Hanlon considers your words carefully...*

> Guard Hanlon says, 'Good to see you again, ranger. You asked about the gnolls a few days past — I hope you fared well out there. The raids have not let up. If anything, they have grown bolder.'

**Scenario 2: Merchant Recalls Trade Discussion**

Day 1 — A level 20 human wizard with Indifferent faction speaks to Merchant Talia in East Commonlands:

> /say What supplies do you carry for someone heading into Befallen?

*Merchant Talia considers your words carefully...*

> Merchant Talia says, 'Befallen? You will want torches, rations, and perhaps a few vials of holy water if you can find them. The undead there do not take kindly to the living.'

Day 5 — The wizard returns:

> /say I need more supplies.

*Merchant Talia considers your words carefully...*

> Merchant Talia says, 'Ah, the one bound for Befallen. I trust you survived your expedition? I have the usual provisions. If the undead were as thick as they say, you may want to double your torch supply this time.'

**Scenario 3: Faction Change Acknowledged**

Week 1 — A level 10 dark elf necromancer with Apprehensively faction speaks to a Freeport militia guard:

> /say I seek passage through the city.

*Guard Brixton studies you briefly...*

> Guard Brixton says, 'A dark elf in Freeport. Your kind is tolerated here, barely. Keep your head down and your spells to yourself. The Militia has eyes everywhere.'

Week 3 — After doing faction work, the same necromancer is now at Amiably:

> /say Any news from the city?

*Guard Brixton ponders your question...*

> Guard Brixton says, 'Well now, you have been making friends around here. I remember when the Militia kept a closer eye on you. Word is the Deathfist orcs massed another warband east of the tunnel. Might be worth checking if you are looking for work.'

**Scenario 4: Memory with Different Topics**

A player has had three past conversations with a Kelethin guard: one about Crushbone orcs, one about the lifts in Kelethin, and one about the Greater Faydark forest. Today the player asks:

> /say Have the orcs been causing trouble?

The guard recalls the Crushbone conversation (most relevant to the current topic) and responds:

> Guard Leafwalker says, 'You asked me about the Crushbone before, and the answer has not changed. They test our borders every fortnight. We have lost two scouts this moon alone. If you mean to help, speak with the ranger captain near the southern platform.'

The lift and forest conversations are not referenced because they are not relevant to the current question.

**Scenario 5: No Memory for Hostile NPCs**

A player at Scowling faction speaks to a Neriak guard:

> /say Remember me?

*Darkguard Kaylorn glares at you with undisguised contempt.*

No verbal response. No memory stored or retrieved. Phase 1 hostile behavior is unchanged.

**Scenario 6: Fresh Character, No Memories**

A brand-new character speaks to Guard Hanlon for the first time:

> /say Hail, guard.

The guard responds with a standard Phase 1 greeting — no memories exist, so the conversation is indistinguishable from a Phase 1 interaction. Memory accumulates naturally over time through repeated visits.

**Scenario 7: Memory in a Hostile City (Neriak — Positive Faction)**

A human rogue with Kindly faction to the Indigo Brotherhood (earned through extensive faction work) has visited a Neriak Foreign Quarter merchant twice before — once asking about the Bloodsaber cult and once buying provisions. The rogue returns:

> /say I need information about the city.

*a Neriak merchant regards you with cool disinterest.*

> Neriak Merchant says, 'You were here before — asking about the Bloodsabers, if I recall. Curiosity like that is a liability in Neriak. What specific information, and what is it worth to you?'

The memory callback is present ("asking about the Bloodsabers, if I recall") but the tone is cold, transactional, and faintly threatening — even at Kindly faction. This is correct. Neriak NPCs never express warmth. Even allies receive only grudging tolerance. The same memory that a Qeynos guard frames as "I hope you fared well" is framed by a Neriak merchant as "that curiosity of yours is a liability."

**Design constraint demonstrated:** City culture governs the tone of memory acknowledgment, not just the content. A warm city (Qeynos, Rivervale) wraps memory in friendliness. A cold city (Neriak, Cabilis) wraps memory in suspicion and pragmatism. An Oggok Ogre wraps memory in blunt simplicity ("You were here. You asked about food. I remember."). The system prompt must enforce city-culture tone for memory references just as it does for all other dialogue.

## Game Design Details

### Mechanics

#### How Memory Works (Player-Facing)

When a player converses with an NPC, the exchange is remembered by that NPC. On future visits, the NPC draws on relevant past exchanges to inform its response. The player does not need to do anything special to trigger memory — it happens automatically as a natural part of conversation.

Memory is **per-NPC-type, per-player-character**. This means:
- Guard Hanlon remembers what *your character* said to Guard Hanlon
- A different Guard Hanlon in a different zone is the same NPC type and shares the memory (they are "the same guard" for memory purposes)
- Your alt character has no memories with Guard Hanlon even if your main does
- Guard Hanlon does not know what you said to Merchant Talia

#### What NPCs Remember

NPCs retrieve the 5 most relevant past exchanges when responding to a player. "Relevant" means topically similar to what the player is currently saying — not necessarily the most recent. If a player had 20 conversations with a guard over the past month but is now asking about gnolls, the gnoll-related conversations are what surface, regardless of when they happened.

The NPC is instructed to use memories naturally:
- **Reference, do not recite**: "You mentioned gnolls before" not "On your previous visit, you said 'Tell me about the gnolls' and I responded with..."
- **Impressionistic recall**: NPCs remember the gist, not exact quotes
- **Appropriate to role**: A guard remembers threats and your helpfulness. A merchant remembers trade needs. A scholar remembers knowledge topics.
- **Not forced**: If no past memories are relevant to the current conversation, the NPC simply responds without referencing memory. Not every conversation needs a callback to the past.

#### Memory Framing by NPC Role and City Culture

How an NPC frames a memory callback depends on their role and their city's culture. The same memory — "player asked about a local threat" — sounds completely different depending on who is speaking:

| NPC Role / Culture | Memory Framing Style | Example |
|---|---|---|
| **Guard (Qeynos, Kelethin)** | Civic recognition, warm concern | "You asked about the gnolls last time — I hope you were careful out there." |
| **Guard (Freeport)** | Cynical acknowledgment | "Still poking around, are you? You asked about the orcs before. That problem has not gone away." |
| **Guard (Neriak)** | Cold suspicion | "You were here before. What do you want this time?" |
| **Merchant** | Commerce-oriented recall | "Back for supplies? Last time you were heading east." |
| **Scholar / Wizard** | Knowledge-oriented | "Your question about the undead prompted me to consult the texts further." |
| **Guildmaster** | Professional assessment | "Your progress since your last visit has been noted." |
| **Iksar NPC (Cabilis)** | Achievement-only, no warmth | "You return. Your service to the empire has been noted." |
| **Ogre (Oggok) / Troll (Grobb)** | Blunt simplicity | "You were here. You asked about food. I remember." |
| **Halfling (Rivervale)** | Cheerful familiarity | "Oh! You are the one who asked about the Misty Thicket last time! Come in, come in." |

This table is a guide for the system prompt, not an exhaustive ruleset. The key constraint: **city culture always governs tone, even in memory callbacks.** A Neriak NPC with positive faction and fond memories still sounds cold. A Rivervale halfling with negative faction and unpleasant memories still sounds more hurt than hostile.

#### When Memory Is NOT Used

Memory is bypassed in these situations:
- **Faction level 8 (Threatening) or 9 (Scowling)** — The NPC refuses conversation entirely (Phase 1 behavior). No memory is stored or retrieved.
- **NPC is ineligible for LLM** — Non-sentient creatures, excluded body types, opted-out NPCs (same Phase 1 filters). No memory involvement.
- **No relevant memories exist** — First-time conversations or conversations on entirely new topics produce Phase 1-equivalent responses. Memory only enhances when there is something relevant to remember.
- **Sidecar or memory service unavailable** — If the memory backend is unreachable, the sidecar falls back to Phase 1 stateless behavior. The conversation still works; it just lacks memory context. Memory storage for that exchange is skipped.

### Memory Scope and Limits

#### Retention Period

Memories persist for **90 days** from the date of the conversation. After 90 days, memories are eligible for cleanup. This is long enough for even infrequent players to benefit from memory, but prevents unbounded growth.

#### Relevance Threshold

When retrieving memories, only exchanges with a relevance score above a minimum threshold are included. Very weak matches (low semantic similarity to the current conversation) are discarded. This prevents the NPC from referencing tangentially related or irrelevant past conversations.

#### Per-NPC Memory Capacity

Each NPC type can store up to **100 conversation exchanges per player**. This is a soft cap — when a player exceeds 100 exchanges with a single NPC, the oldest exchanges are pruned first. For the 1–6 player server, this limit is generous (it would take 100+ separate conversations with the same NPC to reach it).

#### Recency Weighting

More recent conversations are given a slight boost in relevance scoring. A conversation from yesterday about gnolls is slightly more likely to surface than an equally topically relevant conversation from 60 days ago. This creates a natural "freshness" to NPC memory without completely burying old exchanges.

#### Memory at Faction Boundaries

When a player's faction level changes, the NPC's memories from the old faction level are preserved but annotated with the faction at the time of the exchange. This allows the NPC to acknowledge faction shifts:

- Memories from a hostile era can inform a "you were not welcome before" reference
- Memories from a friendly era can inform a "we used to get along" lament if faction deteriorates
- The current faction level always governs the NPC's behavior and tone — memories just add context

#### Memory Is Not Transferable

- Memories are tied to a player's character ID, not account ID. Alts start fresh.
- Memories are tied to an NPC type ID. Different NPC types are independent.
- Memories cannot be viewed, exported, or manipulated by players. They exist only as internal context for NPC dialogue generation.

### Balance Considerations

#### 1–6 Player Impact

- **Positive: Deep NPC relationships.** With only 1–6 players, each player talks to the same NPCs much more often than on a populated server. Memory amplifies this — the Qeynos guards become "your" guards who know you. This is the single biggest immersion improvement for a small-group server.
- **Positive: World persistence.** Coming back to a city after a week of adventuring and having NPCs acknowledge your absence and ask about your travels creates a powerful sense of world continuity.
- **Positive: Faction work payoff.** Grinding faction from Scowling to Ally now has a narrative arc. NPCs who remember your hostile past and acknowledge your changed standing make the faction grind feel meaningful beyond just merchant access.
- **No gameplay advantage.** NPCs with memories never grant items, reveal quest locations, share mechanical information, or provide any gameplay benefit. Memory is purely atmospheric.
- **Low storage concern.** 1–6 players generate far less memory data than a populated server. Even aggressive conversationalists would produce manageable vector counts.

#### Latency Impact

Memory retrieval adds a small amount of latency to each conversation:
- The sidecar must embed the player's message (fast, ~10-50ms with a small embedding model)
- The sidecar must query Pinecone for relevant memories (~50-100ms)
- The sidecar must include memory context in the prompt (slightly longer prompt, slightly more tokens to generate)

Total additional latency: approximately 100-200ms on top of Phase 1's 600-2200ms. This is within the same "NPC thinking" window that Phase 1 established with the typing indicator. Players will not perceive a difference.

#### Memory Storage After Each Exchange

After each conversation, the sidecar stores the exchange (player message + NPC response) as a new memory vector. This is an asynchronous operation — it does not block the response to the player. The memory is available for future conversations but does not affect the current one.

If the storage operation fails (Pinecone unavailable, network error), the conversation still completes normally. The exchange is simply not remembered. This is acceptable — occasional lost memories are indistinguishable from natural forgetting.

### Era Compliance

Phase 2 does not introduce any new era compliance concerns. The same system prompt era boundaries from Phase 1 apply. Memories are just past conversation exchanges — they inherit whatever era compliance the original responses had.

One potential edge case: if a Phase 1 response contained an era violation that slipped past the post-processor, that violation would be stored as a memory and could resurface in a future conversation. The mitigation is:
- The post-processor continues to filter all final responses (including memory-influenced ones)
- Memories are included as context, not quoted verbatim — the LLM rephrases them
- Any era-violating content in the final response is caught by the same filter

No additional era compliance measures are needed beyond what Phase 1 already provides.

## Affected Systems

- [ ] C++ server source (`eqemu/`) — Phase 2: **NO**
- [ ] Lua quest scripts (`akk-stack/server/quests/`) — Phase 2: **NO** (no changes to Lua bridge or global hook)
- [ ] Perl quest scripts (maintenance only) — **NO**
- [ ] Database tables (`peq`) — **NO** (memories stored in Pinecone, not MariaDB)
- [ ] Rule values — **NO**
- [x] Server configuration — Pinecone API key and index name added to sidecar environment variables
- [x] Infrastructure / Docker — Sidecar container updated with Pinecone client and embedding model dependencies; new environment variables for Pinecone credentials

## Dependencies

- **Phase 1 must be complete and working** — The stateless conversation pipeline (sidecar, Lua bridge, global hook, Docker deployment) must be operational before adding memory. Phase 2 extends the sidecar; it does not replace or redesign it.
- **Phase 1 open blockers must be resolved** — The game-tester flagged two issues during Phase 1 validation: (1) model file name case mismatch in `.env`, and (2) `post_processor.py` missing "stress" in ERA_BLOCKLIST. These should be fixed before Phase 2 work begins.
- **Pinecone account and API key** — A Pinecone account must be provisioned with an API key and an index. The free tier supports 100K vectors, which is more than sufficient for 1–6 players. The API key is stored as an environment variable in the sidecar container.
- **Embedding model** — The sentence-transformers `all-MiniLM-L6-v2` model (or equivalent) must be available in the sidecar container for generating vector embeddings. This is a ~80MB download, included in the Docker image build.
- **Internet connectivity for Pinecone API** — Unlike Phase 1 (entirely local), Phase 2 requires outbound HTTPS access from the sidecar container to Pinecone's API endpoints. The sidecar container must be able to reach the internet.

## Open Questions

1. **Pinecone free tier limits**: The free tier supports 100K vectors across all namespaces in a single index. With the namespace-per-NPC architecture and 1–6 players, is 100K vectors sufficient for months of play? The architect should estimate vector consumption rate (conversations per day x storage per conversation) and determine if the free tier is adequate or if a paid tier is needed.

2. **Embedding model resource impact**: The `all-MiniLM-L6-v2` model is small (~80MB) but still adds memory and CPU usage to the sidecar container. The architect should evaluate whether the existing 8GB memory limit for the sidecar container is sufficient for both the LLM model and the embedding model running simultaneously.

3. **Memory retrieval latency with Pinecone serverless**: Pinecone serverless may have cold-start latency on infrequently accessed namespaces. For NPCs that a player has not visited in weeks, the first query may be slower. The architect should measure actual latency and determine if this affects the 3-second timeout.

4. **Player character ID availability in Lua**: The Phase 1 Lua bridge sends `player_name` but the integration plan uses `player_id` (character ID) for memory lookup. The architect should confirm that `e.other:CharacterID()` is available and reliable, and whether the Lua bridge already sends it or needs a minor addition.

5. **Memory cleanup scheduling**: The integration plan specifies a monthly cleanup job for memories older than 90 days. How should this be scheduled? Options: cron job inside the sidecar container, a separate maintenance script, or an admin endpoint. The architect should determine the simplest approach.

6. **Graceful degradation mode selection**: When Pinecone is unavailable, the sidecar should fall back to Phase 1 stateless behavior. The architect should determine how to detect Pinecone unavailability (connection timeout, API error codes) and ensure the fallback is seamless — the NPC still responds, just without memory context.

7. **Memory for NPC types with multiple spawns**: An NPC type ID may have multiple spawns across different zones (e.g., generic "a guard" NPC type). Should memories be shared across all spawns of the same type, or should zone be a filter? Sharing feels more natural for named NPCs but potentially odd for generic types. The architect should propose a strategy.

## Acceptance Criteria

- [ ] **AC1: NPC references a past conversation** — A player speaks to an NPC, then returns later (at least 5 minutes apart) and speaks again on a related topic. The NPC's second response references or builds upon the first conversation in a natural way.

- [ ] **AC2: Memory is per-character** — Two different player characters speak to the same NPC. The NPC's memories with each character are independent — mentioning a topic discussed with character A does not bleed into conversations with character B.

- [ ] **AC3: Memory is per-NPC** — A player discusses gnolls with Guard Hanlon and trade routes with Merchant Talia. Guard Hanlon does not reference trade routes, and Merchant Talia does not reference gnolls.

- [ ] **AC4: Memory retrieval is topic-relevant** — A player has had 5+ conversations with an NPC on various topics. When the player asks about a specific topic, the NPC references the most relevant past exchange for that topic, not simply the most recent conversation.

- [ ] **AC5: No memory at hostile factions** — A player at Threatening (8) or Scowling (9) faction speaks to an NPC. No memory is stored or retrieved. The NPC exhibits standard Phase 1 hostile behavior (warning or hostile emote).

- [ ] **AC6: Faction change acknowledged** — A player who previously conversed with an NPC at a negative faction level returns after improving their faction. The NPC acknowledges the changed relationship (e.g., "I remember when you were not welcome here").

- [ ] **AC7: Graceful degradation without Pinecone** — If the Pinecone service is unavailable (API key removed, network error), the sidecar falls back to Phase 1 stateless behavior. The NPC still responds to speech; responses simply lack memory context. No errors, no crashes.

- [ ] **AC8: Memory clear endpoint works** — An admin calls the `/v1/memory/clear` endpoint to clear memories for a specific NPC-player pair. The next conversation with that NPC shows no memory of past exchanges.

- [ ] **AC9: Memory does not add noticeable latency** — Response time with memory (including embedding + Pinecone query + longer prompt) remains within the 3-second timeout established in Phase 1. The typing indicator bridges any additional delay.

- [ ] **AC10: First conversation is indistinguishable from Phase 1** — A new character's first conversation with any NPC looks and feels identical to a Phase 1 stateless conversation. Memory only becomes visible on return visits.

- [ ] **AC11: NPC does not recite transcripts** — Over 10 return-visit conversations, NPCs reference past exchanges in natural, impressionistic language. They never quote exact player messages or repeat their own prior responses verbatim.

- [ ] **AC12: Memory respects the 90-day retention limit** — Memories older than 90 days are cleaned up and no longer influence NPC responses. (May require accelerated testing with artificial timestamps.)

- [ ] **AC13: Response stays in character and era** — Over 10 memory-influenced conversations, all responses remain in-character, era-appropriate, and consistent with Phase 1 quality standards (no modern language, no post-Luclin references, no meta-knowledge).

- [ ] **AC14: Sidecar health check reports memory status** — The `/v1/health` endpoint reports whether the memory system (Pinecone connection, embedding model) is operational, in addition to the existing LLM model status.

---

## Appendix: Technical Notes for Architect

_This section is advisory only. The architect makes all implementation decisions._

### Phase 2 Deliverables from Integration Plan

The following deliverables are specified in
`claude/docs/plans/2026-02-23-llm-npc-integration-plan.md` (Section 12, Phase 2):

1. Pinecone client integration in sidecar
2. Embedding model (all-MiniLM-L6-v2) for conversation turns
3. Memory storage after each exchange
4. Memory retrieval (top-5 relevant) before prompt construction
5. Namespace-per-NPC architecture (`npc_{npc_type_id}`)
6. Memory management (TTL cleanup, per-NPC limits)
7. `/v1/memory/clear` endpoint for admin use

### Vector Schema (from integration plan)

```json
{
    "id": "conv_{player_id}_{timestamp}",
    "values": [...],
    "metadata": {
        "player_id": 5678,
        "player_name": "Soandso",
        "player_message": "Tell me about the gnolls",
        "npc_response": "The Sabertooth gnolls...",
        "zone": "qeynos2",
        "timestamp": 1740355200,
        "faction_at_time": 2,
        "turn_number": 3
    }
}
```

### Memory Context in Prompt

The integration plan (Section 5) specifies memory context is injected between the system prompt and the current message:

```
[System Prompt — NPC identity, zone culture, faction behavior, rules]

Previous interactions with {player_name}:
- 2 days ago: Player asked about gnoll raids, you described the Blackburrow threat
- 5 days ago: Player brought up a gnoll fang as proof of a kill

{player_name} says, '{message}'
```

The sidecar's `prompt_builder.py` would need to accept an optional list of memory summaries and format them as prompt context. The LLM then naturally incorporates relevant memories into its response.

### Recency Weighting Formula (from integration plan)

The integration plan suggests: `adjusted_score = pinecone_score * (1 / (1 + days_since))`

This applies a recency decay to the raw Pinecone similarity score. The architect may adjust this formula based on testing.

### Embedding Text Strategy

Each conversation turn is embedded as a single string combining the player message and NPC response:

```
"Player asked: {player_message}. NPC responded about: {npc_response_summary}"
```

The architect should determine the exact embedding format that produces the best retrieval quality.

### Sidecar Changes Summary

The Phase 1 sidecar (`app/main.py`) currently:
1. Receives a chat request
2. Builds system prompt from NPC context
3. Calls Mistral 7B for inference
4. Post-processes the response
5. Returns the response

Phase 2 adds steps between 2 and 3, and after 4:
1. Receives a chat request
2. Builds system prompt from NPC context
3. **NEW: Embed the player's message**
4. **NEW: Query Pinecone for relevant past exchanges**
5. **NEW: Format memories and add to prompt context**
6. Calls Mistral 7B for inference (with memory-enriched prompt)
7. Post-processes the response
8. Returns the response
9. **NEW: Embed the full exchange and store in Pinecone (async, non-blocking)**

### ChatRequest Model Extension

The existing `ChatRequest` model (`app/models.py`) includes `player_name` but the memory system needs `player_id` (character ID) for reliable player identification. The architect should determine whether to:
- Add `player_id` to the request model (requires a minor Lua bridge update to include `e.other:CharacterID()`)
- Use `player_name` as the memory key (simpler but potentially fragile if names can be reused)

### ChatResponse Model Extension

The existing `ChatResponse` model could optionally report memory usage:

```json
{
    "response": "...",
    "tokens_used": 142,
    "memory_stored": true,
    "memories_retrieved": 3
}
```

The `memory_stored` and `memories_retrieved` fields would be informational for debugging/monitoring. The Lua bridge can ignore them.

### Phase 1 Open Blockers to Resolve

Before Phase 2 in-game testing can be validated, the game-tester flagged:
- Model file name case mismatch (rename file or update `.env`)
- `post_processor.py` missing "stress" in ERA_BLOCKLIST (note: current code already includes `\bstress\b` — verify this was fixed)

### Memory Clear Endpoint

The integration plan specifies a `/v1/memory/clear` endpoint:

```
POST /v1/memory/clear
    Request: { "npc_type_id": 1234, "player_id": 5678 }
    Response: { "cleared": 12 }
```

Additional clearing granularity to consider:
- Clear all memories for a player (across all NPCs): `{ "player_id": 5678 }`
- Clear all memories for an NPC (across all players): `{ "npc_type_id": 1234 }`
- Clear everything (testing/reset): `{ "clear_all": true }`

### Pinecone Configuration

The integration plan specifies:
- **Index**: One shared index for all NPC memories
- **Namespaces**: `npc_{npc_type_id}` — one namespace per NPC type
- **Dimension**: 384 (matches all-MiniLM-L6-v2 output)
- **Metric**: Cosine similarity

Environment variables to add to the sidecar:
```
PINECONE_API_KEY=<api_key>
PINECONE_INDEX=<index_name>
PINECONE_ENVIRONMENT=<environment>  # for serverless: region like us-east-1
MEMORY_ENABLED=true                 # feature flag for Phase 2
MEMORY_TOP_K=5                      # number of memories to retrieve
MEMORY_SCORE_THRESHOLD=0.7          # minimum similarity score
MEMORY_MAX_PER_PLAYER=100           # per-NPC per-player memory cap
MEMORY_TTL_DAYS=90                  # memory retention period
```

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
