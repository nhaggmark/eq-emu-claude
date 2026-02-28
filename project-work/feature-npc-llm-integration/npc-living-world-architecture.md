# NPC Living World — Technical Architecture & Implementation

> **Date:** 2026-02-25
> **Status:** Active — guides all NPC-related implementation work
> **Companion doc:** [npc-living-world-dream.md](npc-living-world-dream.md) (vision & philosophy)

---

## System Overview

The NPC Living World system uses a 4-layer context architecture to produce
culturally grounded, lore-accurate NPC dialogue through a local LLM sidecar.

```
┌───────────────────────────────────────────────────────────────┐
│                     NPC LIVING WORLD                          │
│                                                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────────┐   │
│  │  Global   │ │  Local   │ │  Soul    │ │   Memory       │   │
│  │  Context  │ │  Context │ │  (Who    │ │   (What we     │   │
│  │  (What    │ │  (Where  │ │   I AM)  │ │    DID         │   │
│  │   I am    │ │   I am)  │ │          │ │    together)   │   │
│  │   made    │ │          │ │  Shared  │ │                │   │
│  │   of)     │ │          │ │  across  │ │  Private to    │   │
│  │          │ │          │ │  ALL     │ │  ONE player    │   │
│  │  Static  │ │  Static  │ │  players │ │                │   │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └───────┬────────┘   │
│       │            │            │                │            │
│       ▼            ▼            ▼                ▼            │
│  Race, deity,   Zone spawns,  Emergent       Per-player      │
│  class, faction politics,     backstory,     conversation    │
│  lore, culture  dangers,      opinions,      history         │
│                 named mobs    relationships                  │
└───────────────────────────────────────────────────────────────┘
```

### Layer Priority (Prompt Injection Order)

```
1. Global Context  — foundational, static, always present
2. Local Context   — zone-specific, static, always present
3. Soul Elements   — emergent identity, always present
4. Memory          — per-player history, semantically retrieved
```

An NPC's established soul identity overrides generic lore when they conflict.
But global and local context constrain what kinds of souls can emerge.

---

## Layer 1: Global Context ("What I Am Made Of")

**Status:** Partially implemented (zone_cultures.json — thin), lore bible
written (npc-lore-bible.md — comprehensive but not yet integrated)

Pre-compiled, static cultural paragraphs for every NPC based on database
attributes. Loaded at sidecar startup as a lookup table.

### Lookup Key Structure (with Fallback Chain)

1. Race + Class + Deity + Primary Faction (most specific)
2. Race + Class + Deity
3. Race + Class
4. Race alone (most general)

### Content Format

- Second-person voice ("You are...", "You believe...")
- Under 200 tokens per entry
- Covers: racial worldview, speech style, deity relationship, faction
  loyalties, cultural prejudices
- Derived from the lore bible — no invented content

### Example Entries

**Human + Warrior + Rodcet Nife + Guards of Qeynos:**
> "You are a guard of Qeynos, sworn to protect the people under Antonius
> Bayle's rule. The Prime Healer, Rodcet Nife, guides your moral compass.
> You speak with professional duty, slightly world-weary. You know the gnolls
> of Blackburrow push south every season, and something is wrong beneath the
> city though you do not discuss it openly on duty. You refer to people as
> 'citizen.' You distrust Freeport and pity its people under Lucan's rule."

**Dark Elf + Necromancer + Innoruuk:**
> "You are Teir'Dal, child of Hate, dwelling in Neriak. Innoruuk's whispers
> are your scripture. You view other races with contempt barely disguised as
> tolerance. Power is the only currency that matters. You speak in measured,
> deliberate phrases — never revealing more than intended. The living are
> tools; the dead are more reliable tools."

**Ogre + Warrior + Rallos Zek:**
> "You strong. You guard Oggok. Rallos Zek make ogres to fight. You fight.
> Short words. Big hits. Food good. Elves bad. Dat all you need know."

### Canonical NPC Overrides

13+ NPCs have backstory elements already defined in quest dialogue. These are
ground truth — they must never be contradicted. Override entries keyed by
`npc_type_id` supersede the generic race+class+deity lookup.

| NPC | Canonical Soul Element |
|-----|-----------------------|
| Plagus Ladeson | Left Qeynos searching for lost love Milea Clothspinner |
| Valeron Dushire | Personally trained Sir Lucan D'Lere when Lucan was a street orphan |
| Lady Shae | Ex-lover of Antonius Bayle IV, relocated to Freeport |
| Guard Kwint | Brother Earron is master brewer at Lion's Mane Tavern |
| Captain Rohand | World traveler (Odus, Faydwer, Kunark) before settling as captain |
| Behroe Dlexon | Bard-guard writing unrequited songs for Aenia |
| Ebon Strongbear | Corrupt guard Beris stole his sister's coinpurse |
| Dok | Failed inventor of the "cigar," switched to candle-making |
| Trooper Shestar | Father was blacksmith; chose warrior life over smithing |

### Why Pre-Compilation Matters (Phase 2 Testing Lesson)

Mistral-7B-Q4 cannot reliably infer cultural context from sparse attribute
data. When given only "Human Paladin, Level 40, West Freeport," it produced:
- Non-EQ deities ("Elandar, Keeper of the Sacred Flame")
- Non-EQ locations ("Eldoria", "the Grand Bazaar")
- Generic high fantasy with no Freeport character
- Contradicted its own prior statements on follow-up

The model needs explicit, pre-written cultural grounding — not hints. The
smaller the model, the more explicit the context must be.

### Storage

`config/global_contexts.json` — loaded at sidecar startup, keyed by
composite lookup keys with fallback chain.

---

## Layer 2: Local Context ("Where I Am")

**Status:** Raw data extracted (zone NPC census, zone connections), needs
structuring as prompt-injectable reference

Per-zone knowledge that every NPC in a zone shares. Static, determined by
`zone_short`. Three detail tiers gated by NPC INT stat.

### Content Per Zone

- Political landscape (who controls, faction dynamics)
- Creature populations (spawns, faction affiliations, level ranges)
- Named monsters (notable named mobs, danger level, lore significance)
- Danger zones (hazardous areas within the zone)
- Travel routes (safe paths, dangerous paths, zone connections)
- Landmarks (docks, arena, tunnel, bridge, etc.)
- Time-based changes (e.g., Kithicor Forest undead after dark)
- Adjacent zone awareness (what lies beyond each exit)

### INT-Gated Detail Levels

| INT Range | Tier | Delivery |
|-----------|------|----------|
| Below 75 | Low | Vague warnings, simple directions, no specific names |
| 75-120 | Medium | General awareness, faction names, basic travel advice |
| Above 120 | High | Specific tactical intel, named mobs, level ranges, historical context |

### Role-Gated Framing

NPC class determines how zone knowledge is expressed:

| Class Category | Framing |
|---------------|---------|
| Warrior, Paladin, SK, Ranger | Military: threat assessment, patrol reports |
| Rogue, Merchant types | Commerce: trade routes, supply concerns |
| Wizard, Enchanter, Mage, Necro | Scholar: historical context, ecological knowledge |
| Cleric, Druid, Shaman | Spiritual: deity connections, moral framing |
| Bard, Monk, Beastlord | Social: gossip, rumor, community impact |

### Storage

`config/local_contexts.json` — per-zone references with three detail tiers,
loaded at sidecar startup.

---

## Layer 3: Soul Memory ("Who I Am" — Emergent, Shared)

**Status:** Designed, not yet implemented (Phase 3)

### Soul vs Conversation Memory

| Property | Soul | Conversation Memory |
|----------|------|-------------------|
| Scope | One NPC → ALL players | One NPC ↔ one player |
| Content | Backstory, opinions, fears, relationships | Turn summaries, specific exchanges |
| Retrieval | Always injected (identity) | Semantic search (relevance) |
| TTL | Permanent until death | 90 days |
| Deletion | Soft delete on death | Soft delete on death or TTL |

### Classification Signals

| Signal | Classification |
|--------|---------------|
| NPC talks about their past | Soul |
| NPC reveals an opinion/belief | Soul |
| NPC mentions family | Soul |
| NPC references a fear | Soul |
| NPC references THIS conversation | Memory |
| NPC references a PAST conversation with this player | Memory |
| NPC gives this player specific advice | Memory |

### ChromaDB Storage Model

```
Collections:
  npc_{type_id}_soul       → Shared identity (ALL players see this)
                              metadata: {category, source_date, active, deleted_at}

  npc_{type_id}_memories   → Private per-player experiences
                              metadata: {player_id, player_name, timestamp,
                                         turn_summary, player_message,
                                         npc_response, active, deleted_at}
```

### Soft Delete Architecture

Nothing is ever hard-deleted immediately. Every record has `active` and
`deleted_at` fields:

- **On NPC death:** `active = false, deleted_at = NOW()` for all soul + memory
- **On cleric restoration:** `active = true, deleted_at = null` (full or partial)
- **On TTL expiration:** Hard-delete where `active = false AND deleted_at < NOW() - RESURRECTION_WINDOW`

Resurrection window: configurable duration (e.g., 7 days) after death during
which soft-deleted records can be restored. After this window, records are
hard-deleted and the soul is truly gone.

---

## Layer 4: Conversation Memory (Phase 2 — Complete)

Per-player conversation memory via ChromaDB and sentence-transformers.

### Current Implementation

- **Storage:** ChromaDB PersistentClient, `npc_{type_id}` collections
- **Embedding:** all-MiniLM-L6-v2 (384-dim, runs on CPU)
- **Retrieval:** Semantic search, top-5, score threshold 0.4
- **Diversity filter:** Over-fetch 3x, pairwise cosine similarity, keep older
  when >0.7 similar (breaks feedback loops)
- **Turn summary:** LLM-generated in async background task
- **TTL:** 90 days, scheduled cleanup every 24 hours
- **Per-player limit:** 100 memories per NPC per player

### Memory Context Format

Includes recency labels, faction-at-time notes, and actual NPC dialogue
snippets (`You said: "..."`) for grounding consistency.

### Feedback Loop Mitigation (Phase 2 Fix)

When the model gives a bad answer, it gets stored, then retrieved as top match
for similar future queries, reinforcing the error. The diversity filter breaks
this by keeping the older (original, likely correct) memory when two memories
are semantically similar (>0.7 cosine).

---

## Prompt Assembly Pipeline

### Architectural Decision: No Framework (2026-02-25)

**Decision:** Stay framework-free. Do not adopt LangChain or LlamaIndex.

**Why not LangChain:**
- Massive dependency footprint (+200-500MB image size)
- Designed for multi-step agentic workflows we don't need
- Doesn't solve the grounding problem (it also just stuffs docs into prompts)

**Why not LlamaIndex:**
- Fights our architecture — 3 of 4 layers are dictionary lookups, not RAG
- Version churn risk with llama-cpp-python compatibility

**What we build instead:**
- `PromptAssembler` class (~80 lines) with token budgeting
- Context provider classes per layer (independently testable)
- Structured rules template as a constant
- Zero new dependencies

### Prompt Stack

```
┌──────────────────────────────────────────────────────────────────┐
│                      LLM System Prompt                           │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ 1. GLOBAL CONTEXT (static, pre-compiled)                   │  │
│  │    ~100-200 tokens                                          │  │
│  ├────────────────────────────────────────────────────────────┤  │
│  │ 2. LOCAL CONTEXT (static, per-zone)                        │  │
│  │    ~100-200 tokens                                          │  │
│  ├────────────────────────────────────────────────────────────┤  │
│  │ 3. SOUL ELEMENTS (emergent, always injected)               │  │
│  │    ~0-200 tokens (grows over time)                          │  │
│  ├────────────────────────────────────────────────────────────┤  │
│  │ 4. CONVERSATION MEMORY (per-player, semantic retrieval)    │  │
│  │    ~100-300 tokens                                          │  │
│  ├────────────────────────────────────────────────────────────┤  │
│  │ 5. RULES & CONSTRAINTS                                     │  │
│  │    ~150 tokens (never truncated)                            │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Total budget: ~500-1050 tokens system prompt                    │
│  Remaining: ~500-1000 tokens for user message + response         │
│  (at n_ctx=2048)                                                 │
└──────────────────────────────────────────────────────────────────┘
```

### Token Budget Management

Truncation priority (bottom-up when over budget):
1. Memory (fewer entries)
2. Soul (fewer elements)
3. Local context (lower detail tier)
4. Global context (shorter version)
5. Rules (never truncated)

Token counting uses the model's actual tokenizer (`llm.tokenize()`), not
character estimation.

### Context Window

Increased from `n_ctx=1024` to `n_ctx=2048` in Phase 2.5. The model supports
32K — we were artificially constraining it. At 2048, the full 4-layer prompt
fits without aggressive truncation.

Expected impact: ~500MB-1GB additional VRAM for KV cache. Minimal inference
speed impact for short responses.

---

## Async Post-Processing Architecture

```
SYNCHRONOUS (player waits):
  1. Retrieve soul elements (fast ChromaDB read)
  2. Retrieve per-player memories (fast ChromaDB query)
  3. Build system prompt (string assembly)
  4. LLM inference (~2-4s GPU)
  5. Era compliance check (fast regex/rules)
  6. SEND RESPONSE TO PLAYER

ASYNCHRONOUS (fire-and-forget):
  7. Generate turn summary (lightweight LLM call)
  8. Generate embedding + store conversation memory
  9. Classify response: soul vs memory vs both (Phase 3)
 10. Extract + store soul elements if new (Phase 3)
```

---

## Performance Findings (Phase 2 Testing)

| Metric | Value | Notes |
|--------|-------|-------|
| Simple greeting | ~1.2s | Short prompt, short response |
| Complex question | ~3-4s | Longer prompts, more tokens |
| Memory embedding | ~10-50ms | sentence-transformers on CPU |
| ChromaDB query | ~5-20ms | Local PersistentClient |
| Turn summary | ~0.5-1s | Async, doesn't block response |
| Total end-to-end | **2-5s** | Dominated by LLM inference (95%+) |

**Transport overhead:** HTTP ~5ms, `io.popen("curl")` spawn ~50-100ms.
Switching protocols would save ~5ms. Not worth optimizing.

**Zone blocking:** Current Lua bridge blocks the zone process during sidecar
call. All players in the zone freeze for 2-5s. Acceptable for 1-3 players.
Future: non-blocking Lua with timer-based callback.

---

## Model Capability Findings

### 7B Quantized Limitations (Mistral-7B-Q4_K_M)

- Ignores memory context even with explicit consistency instructions
- Invents non-EQ lore without explicit cultural grounding
- Contradicts own prior statements on follow-up questions
- CAN generate acceptable dialogue with rich, explicit context
- CANNOT infer cultural nuance from sparse attribute data

### Evaluation Path

| Approach | Pros | Cons |
|----------|------|------|
| 13B model | Better instruction following | More VRAM, slower |
| Cloud API | Excellent grounding, huge context | Latency, cost |
| Fine-tuned 7B | Best of both worlds | Training pipeline needed |
| Better prompts | Free, immediate | Limited gains at 7B |

**Recommendation:** Test 13B first if VRAM permits. Richer pre-compiled
context (Phase 2.5) is the highest-impact fix before model changes.

---

## Confirmed Data Findings

### Finding 1: All City NPCs Are Individually Named

4,889 unique named NPCs across 28 Classic-Luclin city zones. Zero generic
"a guard" or "a merchant" in any city.

### Finding 2: Canonical Soul Elements in Quest Scripts

13+ verified backstory elements in quest dialog (see canonical NPC overrides
table above). These are ground truth.

### Finding 3: Cross-NPC Relationships Documented

10+ scripted relationships: siblings, romances, trainer/student bonds,
institutional ties spanning cities.

---

## Implementation Phases

| Phase | What | Status |
|-------|------|--------|
| Phase 1 | NPC LLM conversations (base system) | **Complete** |
| Phase 2 | Conversation memory (ChromaDB, per-player) | **Complete** |
| **Phase 2.5** | **Lore integration + prompt pipeline** | **In Progress** |
| Phase 3 | Soul memory (emergent NPC identity) | Designed |
| Phase 3.5 | Death/resurrection mechanics | Designed |
| Phase 4 | Recruit-any-NPC companion system | Future |

### Phase 2.5 Implementation Sequence

1. Create `PromptAssembler` class with token budgeting
2. Create context provider classes (Global, Local, Soul placeholder)
3. Build global context data (`config/global_contexts.json`)
4. Build local context data (`config/local_contexts.json`)
5. Refactor `prompt_builder.py` to use assembler + providers
6. Update Lua bridge to send `npc_deity`, `npc_int`, `npc_primary_faction`, `npc_gender`
7. Bump `n_ctx` to 2048

### Already Completed (Phase 2 Bug Fixes)

- Diversity filter in retrieval (breaks feedback loops)
- NPC dialogue in memory context ("You said: ...")
- Stronger consistency instruction
- Turn summary moved to async path
- App source volume-mounted for dev iteration
- Curl timeout increased from 3s to 10s

---

## Key Open Questions

1. **Soul element limits:** How many before identity becomes unwieldy?
2. **Soul conflicts:** NPC says they hate elves — player B is an elf?
3. **Model selection:** 13B viable on current GPU? Fine-tuned 7B?
4. **Token budget tuning:** Dynamic allocation as soul grows?
5. **Global context granularity:** Every combo or broad categories + overrides?
6. **Local context generation:** Hand-written, auto-generated, or hybrid?
7. **Recruitment dialog:** Does NPC response draw from soul?
8. **Soul restoration spell:** Level, reagent, cooldown, partial restoration?
9. **Performance at scale:** Response time with 4 layers under 5s?
10. **Non-blocking Lua:** Timer-based async for higher player counts?

---

*For the aspirational vision, emotional design rationale, and "why this
matters" philosophy, see the companion document:
[npc-living-world-dream.md](npc-living-world-dream.md)*
