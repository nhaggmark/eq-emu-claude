# NPC LLM Phase 2.5 — Lore Integration + Prompt Pipeline — Product Requirements Document

> **Feature branch:** `feature/npc-llm-phase2.5`
> **Author:** game-designer
> **Date:** 2026-02-25
> **Status:** Draft

---

## Problem Statement

Phase 2 testing proved that the NPC conversation system works mechanically — the LLM generates dialogue, ChromaDB stores per-player memories, the Lua bridge connects the client to the sidecar. But the quality of conversations is unacceptable. NPCs sound like generic high-fantasy chatbots, not inhabitants of Norrath.

The root cause is insufficient cultural grounding in the system prompt. The current prompt tells the model "You are Guard Hanlon, a level 20 Human Warrior in South Qeynos" and provides a thin zone culture blurb ("civic virtue, law-and-order, duty-bound"). The 7B quantized model (Mistral-7B-Q4_K_M) cannot infer the cultural richness of Norrath from these sparse hints. Testing showed:

- **Hallucinated deities:** The model invents non-EQ gods ("Elandar, Keeper of the Sacred Flame") because it has no list of real Norrath deities in context.
- **Hallucinated locations:** The model references "Eldoria," "the Grand Bazaar," and other invented places because it has no knowledge of actual zone geography.
- **Generic fantasy tone:** Every NPC sounds like a medieval innkeeper regardless of race, class, or city. A Neriak dark elf sounds the same as a Qeynos guard. An Oggok ogre speaks in complex sentences.
- **Contradiction on follow-up:** When asked to elaborate on something it previously said, the model invents a new, contradictory answer because it cannot reliably ground to injected memory context.

This matters enormously for our server. With 1-6 players, NPCs ARE the community. If Guard Hanlon sounds like every other guard in every other fantasy game, the world feels hollow. If he references Elandar instead of Mithaniel Marr, the illusion breaks. The entire NPC Living World vision depends on conversations that feel specifically, unmistakably Norrathian.

Phase 2.5 solves this by replacing the thin, improvised system prompt with a structured, layered prompt pipeline that feeds the model pre-written, lore-accurate cultural context. The model stops guessing and starts speaking from knowledge.

## Goals

1. **Eliminate lore hallucination.** NPCs must reference only real Norrath deities, locations, factions, and cultural concepts. Zero tolerance for invented lore in any conversation.

2. **Deliver culturally distinct NPC voices.** A Neriak dark elf must sound cold and calculating. An Oggok ogre must speak in short, simple sentences. A Qeynos guard must reference Antonius Bayle and the gnoll threat. Each race, class, deity, and city combination should produce a recognizably different conversational voice.

3. **Give NPCs useful local knowledge.** When a player asks a Qeynos guard about dangers nearby, the guard should mention Blackburrow gnolls, Kithicor undead at night, and Karana bandits — not generic "dark forces." NPCs should be genuinely useful sources of zone-specific information, gated by their intelligence and role.

4. **Establish a scalable prompt architecture.** Build a 4-layer system (global context, local context, soul placeholder, memory) with token budgeting so that Phase 3 (soul emergence) and Phase 4 (recruitment) can plug in without refactoring.

5. **Maintain response time under 5 seconds.** The richer prompt must not push inference latency beyond the acceptable threshold established in Phase 2 testing.

## Non-Goals

- **Soul emergence system.** Phase 2.5 reserves token budget space for soul elements but does not implement soul generation, classification, or storage. That is Phase 3.
- **Model upgrade.** The PRD assumes the current Mistral-7B-Q4_K_M model. If quality remains insufficient after implementing rich context, a model upgrade (13B, cloud API) is a separate decision.
- **New Lua bridge transport.** The blocking `io.popen("curl")` approach remains. Non-blocking Lua is a future optimization for higher player counts.
- **Quest script integration.** NPCs with existing quest scripts (`.lua` or `.pl` files) continue to use those scripts. Phase 2.5 affects only NPCs routed through the global LLM hook.
- **Fine-tuning.** No model fine-tuning or training data pipeline.
- **Companion recruitment.** Recruitment mechanics are Phase 4.

## User Experience

### Player Flow

1. **Player approaches an NPC and says something.** The Lua bridge checks LLM eligibility (no local quest script, INT above threshold, sentient body type). If eligible, it gathers NPC attributes and sends the request to the sidecar.

2. **The sidecar assembles a culturally rich prompt.** Before Phase 2.5, the prompt was a flat string: name, level, race, class, zone, a thin culture blurb, faction tone, memories, and rules. After Phase 2.5, the prompt is assembled from four distinct layers:
   - **Global context:** A pre-written paragraph that captures this NPC's racial worldview, class identity, deity worship, and faction allegiances. Written in second-person voice so the model adopts the NPC's perspective directly.
   - **Local context:** A per-zone reference covering politics, creatures, dangers, landmarks, and travel routes — filtered by this NPC's intelligence (how much detail they know) and role (how they frame what they know).
   - **Soul elements:** Empty in Phase 2.5 (placeholder for Phase 3's emergent NPC identity).
   - **Memory:** Per-player conversation history retrieved from ChromaDB, unchanged from Phase 2 but now properly token-budgeted.

3. **The model generates a response grounded in real Norrath lore.** Because the prompt now contains explicit deity names, real zone names, actual faction dynamics, and culturally appropriate speech patterns, the model's generation stays within EQ's lore boundaries. It does not need to invent deities because Mithaniel Marr, Innoruuk, Tunare, and Cazic-Thule are already in the prompt. It does not need to invent locations because Blackburrow, the Commonlands, and Neriak are already referenced.

4. **The player receives a response that sounds like it belongs in Norrath.** The post-processor applies era compliance checks and character limits, then delivers the message through the existing in-game chat channel.

### Example Scenarios

#### Scenario A: Qeynos Guard (Human Warrior, Rodcet Nife)

**Before Phase 2.5 (actual Phase 2 output):**
> Player: "What dangers lie ahead?"
> Guard: "Brave traveler, the lands beyond are fraught with peril. Dark forces gather in the shadows, and creatures of the night stalk the unwary. Seek the blessing of Elandar before you venture forth."

**After Phase 2.5 (expected):**
> Player: "What dangers lie ahead?"
> Guard: "Depends where you are headed, citizen. The gnolls hold Blackburrow to the northwest — do not go alone unless you can handle a pack. And whatever you do, stay out of Kithicor Forest after dark. The dead walk that road."

The difference: The guard references real locations (Blackburrow, Kithicor), real threats (gnolls, undead), and speaks with the pragmatic, duty-bound voice of a Qeynos guard. No invented deity. No generic "dark forces."

#### Scenario B: Neriak Dark Elf Merchant (Dark Elf Rogue, Innoruuk)

**Before Phase 2.5:**
> Player: "Tell me about your city."
> Merchant: "Welcome, friend! Our fair city is a beacon of culture and refinement. The people here are warm and welcoming to visitors."

**After Phase 2.5 (expected):**
> Player: "Tell me about your city."
> Merchant: "You are in Neriak. That should tell you everything you need to know. State your business or leave. I have no interest in being your guide."

The difference: The merchant is cold and transactional — not warm, not welcoming. The response reflects the cultural rule that Neriak NPCs never show warmth, even at positive faction. The voice is distinctly Teir'Dal.

#### Scenario C: Oggok Ogre Guard (Ogre Warrior, Rallos Zek)

**Before Phase 2.5:**
> Player: "What do you do here?"
> Guard: "I serve as a guardian of this great fortress, upholding the ancient traditions of our people and ensuring the safety of all who dwell within these walls."

**After Phase 2.5 (expected):**
> Player: "What do you do here?"
> Guard: "Me guard. You no cause trouble, me no smash you. Dat simple."

The difference: The ogre speaks in short, simple sentences appropriate to an INT-cursed race. Rallos Zek made ogres to fight, not to philosophize. The vocabulary and sentence structure reflect the racial curse.

#### Scenario D: Scholarly NPC Asked for Zone Intel (Erudite Wizard, High INT)

> Player: "What can you tell me about the Feerrott?"
> Wizard: "The Feerrott is a swampland south of here, territory of the Allize Taeew — the lizardfolk who serve Cazic-Thule. Their warriors range from seasoned to quite dangerous. The ogres of Oggok hold the northern approach, but the true peril lies in the Accursed Temple deeper within. I would not venture there without considerable preparation."

This NPC has high INT, so they deliver specific tactical information: faction names, level characterizations, deity affiliations, landmark references. A low-INT guard in the same zone would say something like: "Swamp bad. Big lizards there. You go, you maybe die."

## Game Design Details

### Mechanics

#### Layer 1: Global Context (Static, Pre-Compiled)

Global context is the cultural foundation of every NPC conversation. It is a pre-written paragraph, stored in a lookup table, that captures who this NPC fundamentally is based on their database attributes.

**Lookup key structure (with fallback chain):**
1. Race + Class + Deity + Primary Faction (most specific)
2. Race + Class + Deity
3. Race + Class
4. Race alone (most general)

The sidecar resolves the most specific match available. Every NPC gets at least a racial context paragraph, even if no class/deity/faction-specific entry exists.

**Content requirements for each global context entry:**
- Written in second-person voice ("You are...", "You believe...", "You speak...")
- Under 200 tokens
- Covers: racial worldview, speech style, deity relationship, faction loyalties, cultural prejudices, and what this NPC would and would not say
- Derived exclusively from the lore bible — no invented content

**Example entries (from the lore bible):**

*Human + Warrior + Rodcet Nife + Guards of Qeynos:*
> "You are a guard of Qeynos, sworn to protect the people under Antonius Bayle's rule. The Prime Healer, Rodcet Nife, guides your moral compass — you believe every life has value and corruption must be rooted out. You speak with professional duty, slightly world-weary from years on patrol. You know the gnolls of Blackburrow push south every season, the Kithicor road turns deadly after dark, and something is wrong in the catacombs beneath the city. You refer to people as 'citizen.' You distrust Freeport and pity its people under Lucan's rule."

*Dark Elf + Necromancer + Innoruuk + (any Neriak faction):*
> "You are Teir'Dal, child of Hate, dwelling in Neriak. Innoruuk's whispers are your scripture. You view other races with contempt barely disguised as tolerance. Power is the only currency that matters. You speak in measured, deliberate phrases — never revealing more than intended. The living are tools; the dead are more reliable tools. You never show warmth, even to those who have earned your grudging respect. Sentimentality is weakness. Love is the lie the Koada'Dal tell themselves."

*Ogre + Warrior + Rallos Zek + (any Oggok faction):*
> "You strong. You guard Oggok. Rallos Zek make ogres to fight. You fight. Short words. Big hits. Food good. Elves bad. Dat all you need know. You no use big words. You no understand big words. Outsiders talk too much."

**Coverage requirements:**
- All 16 playable races must have a baseline racial context paragraph
- All race+class combinations found in city NPC populations must have entries
- Major deity+race combinations must have specific entries (Dark Elf + Innoruuk, Human + Rodcet Nife, Ogre + Rallos Zek, etc.)
- City-defining factions must have specific entries (Freeport Militia, Knights of Truth, Guards of Qeynos, Dreadguard, etc.)

**Fallback behavior:** If no exact match exists, the system falls back through the key chain. A Human Wizard with no deity-specific entry still gets "Human + Wizard" context. A Gnome with no class-specific entry still gets the Gnome racial baseline. No NPC ever receives zero global context.

#### Layer 2: Local Context (Static, Per-Zone, INT-Gated, Role-Gated)

Local context gives NPCs knowledge about their surroundings. Every NPC in a zone shares the same base zone knowledge, but how much they know and how they express it depends on their intelligence and role.

**Zone knowledge content (per zone):**
- Political landscape: who controls this area, what factions are present, power dynamics
- Creature populations: what spawns, faction affiliations, approximate level ranges, general locations
- Named monsters: notable named mobs, danger level, lore significance
- Danger zones: areas within the zone that are more dangerous
- Travel routes: safe paths, dangerous paths, zone connections
- Landmarks: notable locations NPCs would reference (docks, arena, tunnel, bridge)
- Time-based changes: zones that change at night (e.g., Kithicor Forest undead)
- Adjacent zone awareness: what lies beyond each zone exit

**INT-gated detail levels:**

The NPC's INT stat (already available via `e.self:GetINT()` in the Lua bridge) determines how much detail they can articulate:

| INT Range | Knowledge Tier | What the NPC Can Express |
|-----------|---------------|-------------------------|
| Below 75 | Low | Vague warnings, simple directions, basic friend/foe awareness. Short sentences. No specific names or numbers. |
| 75-120 | Medium | General awareness of zone threats, faction names, basic travel advice. Can name specific locations and creatures. |
| Above 120 | High | Specific tactical intelligence: faction names, level range characterizations, named mob references, historical context, strategic advice. |

**Role-gated framing:**

Different NPC roles frame the same zone knowledge through their professional lens. The role is inferred from the NPC's class:

| NPC Class Category | Framing | How They Express Zone Knowledge |
|-------------------|---------|-------------------------------|
| Warrior, Paladin, Shadow Knight, Ranger | Guard/Military | Threat assessment, patrol reports, tactical warnings |
| Merchant classes, Rogues | Trade/Commerce | Trade route safety, supply concerns, economic impact of threats |
| Wizard, Enchanter, Magician, Necromancer | Scholar/Arcane | Historical context, ecological knowledge, arcane significance |
| Cleric, Druid, Shaman | Spiritual/Religious | Spiritual framing, deity connections, moral assessment of threats |
| Bard, Monk, Beastlord | Social/Cultural | Gossip, rumor, community impact, stories heard from travelers |

**Example — Same zone knowledge, three different deliveries:**

Zone: South Qeynos. Topic: Blackburrow gnolls.

*Low INT Ogre visitor:* "Bad dogs in holes. North. You go, you fight lots."

*Medium INT Human Guard:* "The gnolls hold Blackburrow to the northwest. Stay on the road and you should be fine. They push south every season — we beat them back, but they always come again."

*High INT Erudite Scholar:* "The Sabertooth gnolls have inhabited the tunnel system they call Blackburrow since before Qeynos was founded. Their numbers range from mere pups to battle-hardened commanders. Their shaman elders are the true tactical threat — they coordinate the packs and heal their wounded. If you venture there, bring companions."

**Adjacent zone awareness:**

NPCs know about their own zone AND zones that connect to it. A Qeynos guard knows about Qeynos Hills, Blackburrow, and has heard reports from the Karana Plains. They do not know the specific layout of Neriak or Cabilis — those are too far away. The zone connection map (already extracted in the lore deep-dive) determines the radius of knowledge.

#### Layer 3: Soul Elements (Placeholder for Phase 3)

Phase 2.5 reserves space in the token budget for soul elements but does not populate them. The prompt assembler allocates a configurable token budget for the soul layer (default: 0 in Phase 2.5, expandable to 200 tokens in Phase 3). This ensures the architecture is ready for emergent NPC identity without requiring any Phase 2.5 changes to how soul elements are generated or stored.

When soul elements are empty, their token budget is redistributed to other layers (primarily memory).

#### Layer 4: Conversation Memory (Existing, Now Token-Budgeted)

The existing Phase 2 memory system (ChromaDB, per-player conversation history, semantic retrieval, diversity filtering) continues unchanged. The difference in Phase 2.5 is that memory context is now subject to token budgeting — if the system prompt is approaching the token limit, memory entries are truncated from the bottom (oldest/least-relevant first) rather than silently overflowing the context window.

Memory context format is unchanged: recency labels, faction-at-time notes, and actual NPC dialogue snippets for grounding consistency.

#### Token Budget Management

The prompt assembler manages a hard token budget derived from the model's context window size:

| Component | Token Budget | Priority | Truncation Behavior |
|-----------|-------------|----------|-------------------|
| Rules & constraints | ~150 tokens | Non-negotiable | Never truncated |
| Global context | ~100-200 tokens | High | Truncated at sentence boundary if over budget |
| Local context | ~100-200 tokens | High | Detail tier reduced (high to medium, medium to low) if over budget |
| Soul elements | ~0-200 tokens | Medium | Oldest/least-referenced elements dropped first |
| Memory | ~100-300 tokens | Lower | Fewer memories retrieved; oldest dropped first |
| User message + response | ~450-900 tokens | Reserved | Fixed minimum reservation for player input and model output |

**Total system prompt budget at n_ctx=2048:** ~550-850 tokens, leaving ~700-1000 tokens for the user message and model response. This is a substantial improvement over the current n_ctx=1024, which leaves barely 200-300 tokens for response after the system prompt.

**Truncation priority (bottom-up):** When the total prompt exceeds budget, layers are compressed in this order: memory (fewer entries) -> soul (fewer elements) -> local context (lower detail tier) -> global context (shorter version) -> rules (never truncated).

Token counting must use the model's actual tokenizer (not character-count estimation) for accuracy. The llama-cpp-python binding provides `llm.tokenize()` for this purpose.

#### Context Window Increase (n_ctx 1024 to 2048)

The model's context window is increased from 1024 to 2048 tokens. The model itself supports up to 32K context — the 1024 limit was an artificial constraint set during Phase 1 for performance caution. At 2048:

- System prompt has room for all four context layers without aggressive truncation
- Model response can be longer and more detailed when warranted
- Memory retrieval can include more conversation history

**Expected performance impact:** Doubling n_ctx approximately doubles the model's memory footprint for KV cache. For Mistral-7B-Q4_K_M, this is roughly an additional 500MB-1GB VRAM. Inference speed should be minimally affected for short responses (the model still generates the same number of output tokens). The primary risk is VRAM exhaustion — this must be tested on the target GPU before deployment.

#### Data Required for New Context Layers

The Lua bridge currently sends race, class, level, zone, player info, and faction data to the sidecar. Phase 2.5 requires additional NPC attributes:

| New Field | Source | Used For |
|-----------|--------|----------|
| `npc_deity` | `e.self:GetDeity()` | Global context lookup (deity-specific cultural paragraphs) |
| `npc_int` | `e.self:GetINT()` | Local context INT-gating (detail level selection) |
| `npc_primary_faction` | `e.self:GetPrimaryFaction()` | Global context lookup (faction-specific paragraphs) |
| `npc_gender` | `e.self:GetGender()` | Pronoun consistency in context paragraphs |

The `npc_deity` field already exists in the `ChatRequest` Pydantic model (with a default of 0) but is never populated by the Lua bridge. The other fields need to be added to both the Lua bridge payload and the sidecar request model.

### Balance Considerations

Phase 2.5 does not affect combat mechanics, loot tables, or character progression. It is purely a conversation quality improvement. However, there are balance-adjacent concerns:

**Information balance:** High-INT NPCs providing detailed zone intelligence could give players a significant navigation and threat-assessment advantage. This is intentional — talking to NPCs should be rewarding, and intelligent NPCs should be more useful than simple ones. A wizard in Erudin SHOULD know more about the Desert of Ro than an ogre in Oggok. This creates a meaningful reason to seek out scholarly NPCs for information, which enriches the world.

**Faction gating is preserved:** NPCs at hostile faction levels still refuse to help or provide useful information. The existing faction instruction system (KOS NPCs insult and threaten, indifferent NPCs are minimal, friendly NPCs are helpful) remains unchanged. Local context is only fully delivered when the NPC is willing to talk.

**1-6 player constraint:** This feature benefits solo players most — in a full group, players share knowledge. A solo player talking to NPCs for zone intelligence is exactly the kind of world-engagement the server is designed to encourage.

### Era Compliance

All content injected through the global and local context layers must comply with the Classic-through-Luclin era lock:

- **No Planes of Power references:** No Plane of Knowledge, no PoP-era zone names, no Planar Projection NPCs
- **No Berserker class:** The Berserker class does not exist in our era
- **No Gates of Discord:** No Muramites, no Discord zones, no OoW content
- **Luclin is recent and strange:** NPCs on Norrath proper treat the moon as a new, strange phenomenon. Only NPCs on Luclin itself speak of it with familiarity.
- **Deity references must use canonical names:** Mithaniel Marr (not "the God of Light"), Innoruuk (not "the Dark One"), Cazic-Thule (not "the Fear God"). The lore bible provides the canonical names and titles.

The existing post-processor era blocklist (`post_processor.py`) serves as a safety net, but the goal is to prevent era violations at the prompt level, not catch them in post-processing.

## Affected Systems

- [ ] C++ server source (`eqemu/`)
- [x] Lua quest scripts (`akk-stack/server/quests/`)
  - `llm_bridge.lua` — add `npc_deity`, `npc_int`, `npc_primary_faction`, `npc_gender` to payload
- [ ] Perl quest scripts (maintenance only)
- [ ] Database tables (`peq`)
- [ ] Rule values
- [ ] Server configuration
- [x] Infrastructure / Docker
  - Docker compose config — `LLM_N_CTX` environment variable bump from 1024 to 2048
- [x] NPC LLM sidecar (`akk-stack/npc-llm-sidecar/`)
  - Prompt assembly pipeline (new PromptAssembler class)
  - Context provider modules (GlobalContextProvider, LocalContextProvider)
  - Token budgeting with model tokenizer
  - Request model update for new NPC fields
  - New config data files for global and local context

## Dependencies

- **Phase 1 (NPC LLM Foundation)** — Complete. Sidecar service, Lua bridge, global_npc.lua hook all operational.
- **Phase 2 (Conversation Memory)** — Complete. ChromaDB memory, semantic retrieval, diversity filtering, async turn summary all operational.
- **Lore Bible** — Complete. `npc-lore-bible.md` provides comprehensive cultural data for all races, deities, cities, and factions through Luclin.
- **Zone Overview Data** — Complete. `01-zone-overview.md` provides zone populations, level ranges, race variety, and zone connections for all Classic-Luclin zones.
- **Faction System Data** — Complete. `02-faction-system.md` provides faction IDs, relationships, racial modifiers, and quest dialogue examples for all major city factions.

## Reference Docs

- Vision + implementation plan: `claude/project-work/feature-npc-llm-integration/npc-living-world-vision.md` (Phase 2.5 section)
- Lore bible: `claude/project-work/feature-npc-llm-integration/lore-deep-dive/context/npc-lore-bible.md`
- Zone overview: `claude/project-work/feature-npc-llm-integration/lore-deep-dive/context/01-zone-overview.md`
- Faction data: `claude/project-work/feature-npc-llm-integration/lore-deep-dive/context/02-faction-system.md`
- NPC census: `claude/project-work/feature-npc-llm-integration/lore-deep-dive/context/03-zone-npc-census.md`
- Current sidecar code: `akk-stack/npc-llm-sidecar/app/` (prompt_builder.py, main.py, models.py, memory.py, post_processor.py)
- Current Lua bridge: `akk-stack/server/quests/lua_modules/llm_bridge.lua`
- Current zone cultures: `akk-stack/npc-llm-sidecar/config/zone_cultures.json`

## Open Questions

1. **Global context coverage scope:** How many race+class+deity+faction combinations should be authored for Phase 2.5? The full combinatorial space is enormous (16 races x 16 classes x ~20 deities x ~300 factions). A pragmatic approach would be to cover all combinations that actually exist in city NPC populations (~4,889 unique NPCs across 28 city zones) and let the fallback chain handle rare combos. The architect should determine the minimum viable coverage set.

2. **Local context authoring method:** Should per-zone local context be hand-written from the lore bible (higher quality, slower), auto-generated from the zone NPC census database data (faster, may need manual polish), or a hybrid approach? The zone overview and NPC census data provide raw material, but translating that into natural-language zone references at three INT tiers requires authoring effort.

3. **NPC role inference accuracy:** The current plan maps NPC class to role (warrior -> guard, wizard -> scholar, etc.). But some NPCs have a class that does not match their social role — a warrior NPC placed at a shop counter is functionally a merchant, not a guard. Should the system also consider the NPC's merchant_id or other database flags to determine role? The architect should investigate what role signals are available.

4. **Performance impact of n_ctx=2048:** The doubling of context window needs to be tested on the target GPU (the system running the sidecar container). If VRAM is insufficient, we may need to keep n_ctx=1024 and compress the context layers more aggressively. The architect should benchmark this early.

5. **Token budget tuning:** The initial token budget allocations (150 for rules, 200 for global, 200 for local, 0-200 for soul, 300 for memory) are estimates. They need to be validated against actual prompt sizes once the context data is authored. The assembler should support configurable budgets via environment variables for easy tuning.

6. **Canonical soul elements from quest scripts:** Phase 2 testing identified 13+ NPCs with backstory elements already defined in quest dialogue (e.g., Plagus Ladeson's lost love, Valeron Dushire training Lucan, Guard Kwint's brother the brewer). These canonical facts must never be contradicted by LLM-generated content. Should Phase 2.5 seed specific NPC override entries in the global context data for these NPCs, or defer to Phase 3's soul system to handle canonical backstories?

## Acceptance Criteria

- [x] **No hallucinated deities.** In 20 test conversations across different races and cities, no NPC references a non-EQ deity. Every deity name used is from the canonical Norrath pantheon (Tunare, Innoruuk, Cazic-Thule, Mithaniel Marr, Rallos Zek, Brell Serilis, Bristlebane, Rodcet Nife, Erollisi Marr, The Tribunal, Quellious, Bertoxxulous, Solusek Ro, Karana, Prexus, Veeshan).
- [x] **No hallucinated locations.** In 20 test conversations, no NPC references a non-EQ location. Every zone, city, landmark, and dungeon referenced exists in the Classic-Luclin zone table.
- [x] **Culturally distinct voices.** A Neriak dark elf NPC must be cold and calculating. An Oggok ogre must speak simply. A Qeynos guard must sound civic and duty-bound. A Rivervale halfling must be lighthearted. Qualitative review of 5+ conversations per city confirms cultural voice distinction.
- [x] **Accurate local knowledge.** A Qeynos guard asked about local dangers mentions Blackburrow gnolls (not generic threats). A Freeport merchant asked about trade routes references the Commonlands and Deathfist orcs. NPCs provide zone-specific, factually correct information.
- [x] **INT-gated responses.** A low-INT NPC (ogre guard) gives vague, simple responses about zone threats. A high-INT NPC (wizard, scholar) gives detailed, specific information about the same zone. The detail level visibly correlates with NPC intelligence.
- [x] **Token budget respected.** The system prompt (all layers combined) never exceeds the token budget. Truncation, when needed, happens gracefully at sentence boundaries without cutting mid-word or mid-concept.
- [x] **Response time under 5 seconds.** End-to-end latency (player message to displayed response) remains under 5 seconds with the richer prompt at n_ctx=2048.
- [x] **Fallback works gracefully.** An NPC with no specific global context entry (unusual race+class+deity combo) still receives racial baseline context. No NPC ever gets an empty or broken system prompt.
- [x] **Existing memory system unaffected.** Per-player conversation memory continues to function: memories are stored, retrieved, and injected into prompts. The diversity filter still breaks feedback loops.
- [x] **Era compliance maintained.** No NPC references Planes of Power, Berserker class, Gates of Discord, or other post-Luclin content. The post-processor era blocklist continues to function as a safety net.

---

## Appendix: Technical Notes for Architect

*This section is advisory only. The architect makes all implementation decisions.*

### Suggested New Files

| File | Purpose |
|------|---------|
| `app/prompt_assembler.py` | ~80-100 line class that assembles the system prompt from context layers with token budgeting using `llm.tokenize()` |
| `app/context_providers.py` | GlobalContextProvider and LocalContextProvider classes — load JSON at startup, return context strings for given NPC attributes |
| `config/global_contexts.json` | Pre-compiled cultural paragraphs keyed by race+class+deity+faction combinations with fallback keys |
| `config/local_contexts.json` | Per-zone knowledge references with three detail tiers (low/medium/high) per zone |

### Suggested Modifications

| File | Change |
|------|--------|
| `app/prompt_builder.py` | Replace `build_system_prompt()` with call to PromptAssembler. Extract rules block as constant. |
| `app/models.py` | Add `npc_int`, `npc_primary_faction`, `npc_gender` fields to ChatRequest |
| `app/main.py` | Pass context providers and LLM tokenizer reference to assembler at startup |
| `llm_bridge.lua` | Add `npc_deity = e.self:GetDeity()`, `npc_int = e.self:GetINT()`, `npc_primary_faction = e.self:GetPrimaryFaction()`, `npc_gender = e.self:GetGender()` to `build_context()` and `generate_response()` |
| `docker-compose.npc-llm.yml` | Set `LLM_N_CTX=2048` |

### Key Technical Insight from Phase 2 Testing

The grounding failure is not a retrieval problem or a framework problem. Both LangChain and LlamaIndex stuff documents into prompts — exactly what our code already does. The highest-impact fix is richer pre-compiled context data so the model has less to "figure out," combined with proper token budgeting so nothing gets silently truncated. The architect confirmed this: zero new framework dependencies, refactor existing code into a structured pipeline.

### NPC INT Distribution Consideration

The INT-gating thresholds (below 75, 75-120, above 120) need validation against the actual NPC INT distribution in the database. If 99% of NPCs have INT in the 75-120 range, the three-tier system degenerates to one tier. The architect should query the `npc_types` table to understand the actual distribution before finalizing thresholds.

### Lua API Availability

The new fields require these EQEmu Lua API calls:
- `e.self:GetDeity()` — returns deity ID (int)
- `e.self:GetINT()` — returns NPC INT stat (already used in eligibility check)
- `e.self:GetPrimaryFaction()` — returns primary faction ID (int). Needs verification that this API exists in the Lua bindings.
- `e.self:GetGender()` — returns gender ID (0=male, 1=female, 2=neutral)

If `GetPrimaryFaction()` is not available in the Lua API, the architect may need to look up the NPC's faction from the database at sidecar level using `npc_type_id`.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility assessment and implementation planning.
