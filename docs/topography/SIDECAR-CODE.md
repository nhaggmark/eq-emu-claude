# NPC-LLM Sidecar Code Topography

## Summary

The NPC-LLM sidecar is a **Python FastAPI service** that generates NPC dialogue using a
locally-hosted LLM (Mistral 7B or Hermes 3 Llama 3.1 8B in GGUF format). It runs as a Docker
container alongside the EQEmu server stack, receiving HTTP requests from the Lua bridge
(`llm_bridge.lua`) and returning in-character NPC responses. The sidecar includes a
conversation memory system (ChromaDB + sentence-transformers), a layered prompt assembler
with token budgeting, and a post-processor that enforces era compliance and response length.

The service has evolved through multiple phases:
- **Phase 1: Foundation** -- basic LLM inference, prompt building, post-processing
- **Phase 2: Memory** -- ChromaDB-backed conversation persistence and recall
- **Phase 2.5: Context Architecture** -- layered prompt assembler with token budgets,
  global/local context providers, role framing, INT-gated knowledge tiers
- **Phase 3: Soul & Story** -- personality traits, disposition, quest hints, deity alignment

---

## Architecture Overview

```
Titanium Client
    |  /say "Hello guard"
    v
EQEmu Zone Server (C++)
    |  EVENT_SAY dispatched
    v
global_npc.lua (quest script)
    |  Calls llm_bridge.lua
    v
llm_bridge.lua (Lua HTTP module)
    |  HTTP POST http://npc-llm:8100/v1/chat
    |  JSON payload: NPC context + player message
    v
NPC-LLM Sidecar (Python FastAPI, port 8100)
    |  1. Retrieve memories from ChromaDB
    |  2. Assemble system prompt (8 layers, token-budgeted)
    |  3. LLM inference (llama-cpp-python, GGUF model)
    |  4. Post-process response (era filter, length, quote strip)
    |  5. Background: generate turn summary, store in ChromaDB
    v
JSON response: { response, tokens_used, memories_retrieved, memory_stored }
    |
    v
llm_bridge.lua receives response
    |  e.self:Say(response)
    v
NPC speaks in-game via standard dialogue pipeline
```

The sidecar communicates exclusively over the Docker internal network (`backend`). There is
no external port binding -- the EQEmu server container reaches it at `http://npc-llm:8100`
via Docker DNS.

---

## File Structure

```
akk-stack/npc-llm-sidecar/
    app/
        __init__.py              -- empty, marks app as Python package
        main.py                  -- FastAPI application, endpoints, model loading, lifespan
        models.py                -- Pydantic request/response schemas (ChatRequest, ChatResponse, etc.)
        context_providers.py     -- GlobalContextProvider, LocalContextProvider, SoulElementProvider
        prompt_builder.py        -- Legacy prompt builder (build_system_prompt, build_user_message)
        prompt_assembler.py      -- Layered token-budgeted PromptAssembler (8-layer pipeline)
        memory.py                -- MemoryManager (ChromaDB + sentence-transformers)
        post_processor.py        -- Response post-processing (era filter, truncation, quote stripping)
    config/
        global_contexts.json     -- Pre-compiled cultural context by race/class/faction
        local_contexts.json      -- Per-zone knowledge at INT-gated tiers (low/medium/high)
        zone_cultures.json       -- Zone cultural metadata (culture, deity, threats, atmosphere)
        soul_elements.json       -- NPC personality traits, motivations, disposition data
    models/
        .gitkeep
        *.gguf                   -- Model files (gitignored, ~4-8 GB each)
    data/
        chromadb/                -- ChromaDB persistent storage (vector database)
    tests/
        test_suite.py            -- Automated conversation test suite (lore, hallucination, era, memory)
    Dockerfile                   -- Multi-stage CUDA build (nvidia/cuda:12.4.1)
    requirements.txt             -- Python dependencies
    download-model.sh            -- Model download script (HuggingFace)
    .gitignore                   -- Excludes model files, __pycache__, .env
```

---

## Module Details

### `app/main.py` -- Application Core

**FastAPI app version:** 3.0.0

**Global state (module-level):**

| Variable | Type | Purpose |
|----------|------|---------|
| `_llm` | `Llama \| None` | The loaded GGUF model instance |
| `_model_name` | `str` | Stem of the model filename (for health endpoint) |
| `_memory` | `MemoryManager \| None` | ChromaDB memory manager |
| `_assembler` | `PromptAssembler \| None` | Layered prompt assembler |
| `_cleanup_task` | `asyncio.Task \| None` | Background memory cleanup task |

**Lifespan initialization order** (`lifespan()`, line 96):
1. `load_zone_cultures()` -- load zone cultural context from JSON
2. `_load_model()` -- load GGUF model via llama-cpp-python
3. `_init_memory()` -- initialize ChromaDB + embedding model
4. `_init_assembler()` -- create PromptAssembler with all three context providers
5. Start `_scheduled_cleanup()` background task

**Model loading** (`_load_model()`, line 32):
- Reads `MODEL_PATH` env var (default: `/models/model.gguf`)
- Configurable: `LLM_N_CTX` (context window, default 1024), `LLM_N_THREADS` (default 6),
  `LLM_N_GPU_LAYERS` (default 99)
- Uses `llama_cpp.Llama` for inference

**Chat endpoint flow** (`chat()`, line 188):
1. Check model loaded; return error if not
2. If memory enabled and player_id > 0: retrieve relevant memories from ChromaDB
3. Assemble system prompt via `PromptAssembler.assemble()` (falls back to legacy
   `build_system_prompt()` if assembler not initialized)
4. Build user message via `build_user_message()`
5. Call `_llm.create_chat_completion()` with system + user messages
6. Post-process response via `process_response()`
7. If response filtered (era violation with no clean content): return error
8. Schedule background task: generate turn summary via LLM, store in ChromaDB
9. Return `ChatResponse` with response text, token count, memory stats

**Turn summary generation** (`_generate_turn_summary()`, line 147):
- Uses the same LLM with `max_tokens=40`, `temperature=0.3`
- Generates a brief one-sentence summary of the exchange
- Falls back to concatenation (`fallback_turn_summary()`) on failure

---

### `app/models.py` -- Request/Response Schemas

**`ChatRequest`** -- Pydantic model for incoming chat requests:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `npc_type_id` | `int` | required | NPC type ID from database |
| `npc_name` | `str` | required | NPC clean name |
| `npc_race` | `int` | required | EQEmu race ID |
| `npc_class` | `int` | required | EQEmu class ID |
| `npc_level` | `int` | required | NPC level |
| `npc_deity` | `int` | `0` | Deity ID for soul element deity alignment |
| `zone_short` | `str` | required | Zone short name (e.g., "qeynos") |
| `zone_long` | `str` | required | Zone long name (e.g., "South Qeynos") |
| `player_name` | `str` | required | Player character name |
| `player_race` | `int` | required | Player race ID |
| `player_class` | `int` | required | Player class ID |
| `player_level` | `int` | required | Player level |
| `faction_level` | `int` | required | Faction standing (1=Ally through 9=Scowling) |
| `faction_tone` | `str` | required | Human-readable faction label |
| `faction_instruction` | `str` | required | Behavioral instruction for faction level |
| `message` | `str` | required | Player's spoken text |
| `player_id` | `int` | `0` | Player character ID (0 = no memory) |
| `npc_int` | `int` | `80` | NPC INT stat for knowledge tier gating |
| `npc_primary_faction` | `int` | `0` | Primary faction ID for cultural context |
| `npc_gender` | `int` | `0` | 0=male, 1=female, 2=neutral |
| `npc_is_merchant` | `bool` | `False` | True if NPC class == 41 (Merchant) |
| `quest_hints` | `list[str] \| None` | `None` | Tier 2: hint sentences for quest guidance |
| `quest_state` | `str \| None` | `None` | Tier 2: current quest progress descriptor |

**`ChatResponse`** -- Pydantic model for responses:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `response` | `str \| None` | `None` | NPC dialogue text |
| `tokens_used` | `int` | `0` | Total tokens consumed |
| `error` | `str \| None` | `None` | Error message if failed |
| `memories_retrieved` | `int` | `0` | Number of memories used |
| `memory_stored` | `bool` | `False` | Whether this exchange was stored |

**`MemoryClearRequest`** / **`MemoryClearResponse`** -- for the `/v1/memory/clear` endpoint.

---

### `app/prompt_assembler.py` -- Layered Prompt Pipeline

**Class: `PromptAssembler`** (line 38)

The assembler constructs system prompts from 8 ordered layers, each with a configurable
token budget. This is the primary prompt construction path (legacy `build_system_prompt`
is the fallback).

**8-Layer Structure:**

| Layer | Content | Token Budget Env Var | Default |
|-------|---------|---------------------|---------|
| 1 | Identity + era line | (fixed, ~50 tokens) | -- |
| 2 | Global context (race+class+faction) | `LLM_BUDGET_GLOBAL` | 200 |
| 3 | Local context (zone knowledge at INT tier) | `LLM_BUDGET_LOCAL` | 150 |
| 4 | Role framing instruction | (fixed, ~30 tokens) | -- |
| 5 | Faction instruction | (fixed) | -- |
| 5.5 | Quest hints (Tier 2 only) | `LLM_BUDGET_QUEST_HINTS` | 150 |
| 6 | Soul elements (personality + disposition) | `LLM_BUDGET_SOUL` | 0 (150 in docker-compose) |
| 7 | Memory context (past interactions) | `LLM_BUDGET_MEMORY` | 200 |
| 8 | Rules block | (never truncated) | -- |

**Token counting** (`count_tokens()`, line 68):
- Uses the model's tokenizer via `self.llm.tokenize()` when available
- Falls back to character estimate: `len(text) // 4` (constant `_CHARS_PER_TOKEN = 4`)

**Truncation** (`_truncate_to_budget()`, line 77):
- Breaks at sentence boundaries (splits on ". ")
- Tries progressively shorter sentence counts
- Hard fallback: character-based truncation at word boundary

**Truncation priority** (when total budget exceeded):
1. Memory -- truncated first (oldest entries dropped)
2. Soul elements -- placeholder budget
3. Local context -- dropped to lower INT tier
4. Global context -- truncated at sentence boundary
5. Rules block -- never truncated

**Quest hint block** (`_build_quest_hint_block()`, line 98):
- Only injected when `req.quest_hints` is non-empty (Tier 2 NPCs)
- Format: "This person has specific concerns..." + bulleted hints
- Instructs NPC to include `[bracketed]` keywords for say-link generation

---

### `app/prompt_builder.py` -- Legacy Prompt Builder

Contains the original (pre-assembler) prompt construction and shared utilities.

**Key constants:**

| Name | Content |
|------|---------|
| `RACE_NAMES` | Dict mapping EQEmu race IDs to names (1=Human through 330=Froglok) |
| `CLASS_NAMES` | Dict mapping EQEmu class IDs to names (1=Warrior through 16=Berserker) |
| `FACTION_LABELS` | Dict mapping faction levels 1-9 to labels (Ally through Scowling) |

**Functions:**

| Function | Purpose |
|----------|---------|
| `load_zone_cultures(config_path)` | Load `zone_cultures.json` into module-level `_zone_cultures` dict |
| `build_system_prompt(req, memories)` | Legacy full prompt builder (identity + zone culture + faction + memory + rules) |
| `build_user_message(req)` | Formats the user message: player name, spoken text, response instruction |
| `format_memory_context(memories, player_name)` | Formats retrieved memories as natural-language context with recency labels and dialogue snippets |
| `_recency_label(days_ago)` | Converts days-ago float to label: "Earlier today", "Yesterday", "A few days ago", etc. |

**`build_user_message()` format** (line 198):
```
[The player {player_name} speaks to you]
{player_name}: "{message}"

[Respond in character as {npc_name}. Dialogue only, no narration.]
{npc_name}:
```

**Memory context format** (`format_memory_context()`, line 69):
- Header: "Your previous interactions with {player_name}:"
- Per memory: "- {recency_label} [{faction_label} faction]: {turn_summary}"
- Includes NPC dialogue snippets: `You said: "{npc_response[:250]}"`
- Followed by consistency instruction: "CRITICAL: You MUST maintain absolute consistency..."

---

### `app/context_providers.py` -- Context Provider Classes

Three provider classes load JSON config files at startup and serve contextual data per request.

#### `GlobalContextProvider` (line 14)

Provides pre-compiled cultural context paragraphs based on NPC identity.

**Config file:** `config/global_contexts.json` (env: `GLOBAL_CONTEXTS_PATH`)

**Fallback chain** (`get_context()`, line 44):
1. `npc_overrides[npc_type_id]` -- specific NPC backstory
2. `race_class_faction["{race}_{class}_{primary_faction}"]` -- race + class + faction combo
3. `race_class["{race}_{class}"]` -- race + class combo
4. `race["{race}"]` -- race baseline
5. `""` -- empty (no context)

The `global_contexts.json` file contains extensive cultural paragraphs for all playable
races, many race+class combinations, and some NPC-specific overrides.

#### `LocalContextProvider` (line 76)

Provides per-zone knowledge at INT-gated detail tiers.

**Config file:** `config/local_contexts.json` (env: `LOCAL_CONTEXTS_PATH`)

**INT tier mapping** (`get_int_tier()`, line 104):

| NPC INT | Tier | Detail Level |
|---------|------|-------------|
| < 75 | `"low"` | Short, simple sentences; no names or numbers |
| 75-120 | `"medium"` | Faction names, basic travel advice, general awareness |
| > 120 | `"high"` | Named mobs, level ranges, historical context, tactical intel |

**Fallback** (`get_context()`, line 112): If the requested tier is absent for a zone, falls
back through `high -> medium -> low -> ""`.

The `local_contexts.json` file contains entries for 30+ zones with all three tiers, covering
major cities, dungeons, and overland zones across Classic, Kunark, Velious, and Luclin.

#### `SoulElementProvider` (line 211)

Provides NPC personality data (traits, motivations, disposition).

**Config file:** `config/soul_elements.json` (env: `SOUL_ELEMENTS_PATH`)

**Fallback chain** (`get_soul()`, line 267):
1. `npc_overrides[npc_type_id]` -- specific NPC personality
2. `role_defaults[detected_role]` -- role-based defaults
3. `None` -- no soul elements (majority of NPCs)

**Role detection** (`detect_role()`, line 243):
- `"merchant"` -- `npc_is_merchant` flag or class 41
- `"guard"` -- name pattern matching via regex (Guard, Captain, Lieutenant, Trooper, etc.)
- `"guildmaster"` -- name contains "guildmaster" (case-insensitive)
- `"priest"` -- class in {2, 6, 10} (Cleric, Druid, Shaman)

**Soul text formatting** (`format_soul_text()`, line 291):

Converts structured soul data to natural language. Components:

1. **Personality axes** -- 6 axes with -3 to +3 range:
   - `courage`, `generosity`, `honesty`, `piety`, `curiosity`, `loyalty`
   - Each generates a descriptive sentence (e.g., "You are notably brave...")
   - Values of 0 are skipped; |value| >= 2 drops the "somewhat" qualifier

2. **Motivations** -- `desires` and `fears` arrays
   - "Deep down, you desire {X}, and you fear {Y}."

3. **Disposition** -- one of: `rooted`, `content`, `curious`, `restless`, `eager`
   - Each maps to a sentence about the NPC's attitude toward their current role
   - Relevant for companion recruitment: `eager` NPCs are more likely to join

4. **Deity alignment** -- if `npc_deity` is set and recognized
   - "Your faith in {deity_name} shapes your worldview."

5. **Closing reminder** -- "Express these traits through your racial and cultural voice."

#### Role Framing (`get_role_frame()`, line 353)

Free function that returns a role-appropriate instruction for how the NPC should frame
knowledge in conversation.

| Role | Classes | Instruction |
|------|---------|------------|
| Military | Warrior(1), Paladin(3), SK(5), Ranger(4) | "Frame your knowledge as tactical intelligence..." |
| Commerce | Rogue(9) (overridden by merchant flag) | "Frame your knowledge through trade, commerce..." |
| Scholar | Wizard(12), Enchanter(14), Magician(13), Necromancer(11) | "Frame your knowledge with scholarly analysis..." |
| Spiritual | Cleric(2), Druid(6), Shaman(10) | "Frame your knowledge through spiritual and moral..." |
| Social | Bard(8), Monk(7), Beastlord(15) | "Frame your knowledge as stories, rumors..." |

Merchant flag overrides class-based framing.

#### Deity Names (`DEITY_NAMES`, line 161)

Dict mapping EQEmu deity IDs to names. Covers all Classic-through-Luclin deities:
Bertoxxulous(140), Brell Serilis(201), Cazic-Thule(202), Erollisi Marr(203),
Innoruuk(205), Karana(206), Mithaniel Marr(207), Prexus(208), Quellious(209),
Rallos Zek(210), Rodcet Nife(211), Solusek Ro(212), Bristlebane(213),
Tribunal(214), Tunare(215), Veeshan(216), Agnostic(396).

---

### `app/memory.py` -- Conversation Memory System

**Class: `MemoryManager`** (line 13)

Uses ChromaDB (embedded, persistent) with sentence-transformers for semantic memory.

**Initialization:**
- ChromaDB `PersistentClient` at path from `CHROMADB_PATH` (default `/data/chromadb`)
- Embedding model: `all-MiniLM-L6-v2` (384-dimensional, loaded via sentence-transformers)
- Can be disabled via `MEMORY_ENABLED=false`
- Graceful degradation: all operations wrapped in try/except

**Collection scheme:**
- One ChromaDB collection per NPC type: `npc_{npc_type_id}`
- Each collection uses cosine similarity (`hnsw:space: "cosine"`)

**Memory storage** (`store()`, line 241):
- Embeds the turn summary (not raw dialogue) for semantic search
- Vector ID format: `conv_{player_id}_{timestamp}`
- Metadata stored per vector:
  - `player_id`, `player_name`, `player_message` (first 500 chars)
  - `npc_response` (first 500 chars), `zone`, `timestamp`
  - `faction_at_time`, `turn_summary` (first 300 chars)
- Document field: turn summary (first 300 chars)
- Auto-prunes per player per NPC if exceeding `MEMORY_MAX_PER_PLAYER` (default 100)

**Memory retrieval** (`retrieve()`, line 73):
1. Embed the player's query text
2. Query ChromaDB for top `top_k * 3` results (over-fetch for diversity filtering)
3. Filter by `player_id` and `score_threshold` (default 0.4)
4. Apply recency weighting: `adjusted_score = score * (1 / (1 + days_since * 0.1))`
5. **Diversity filter**: when two memories have >0.7 cosine similarity, keep the OLDER
   one to prevent feedback loops where bad follow-up answers drown out correct originals
6. Return top `top_k` diverse results
7. **Recency fallback**: if no memories pass the similarity threshold, return the N most
   recent exchanges for conversational continuity (handles "thank you", "tell me more")

**Scheduled cleanup** (`cleanup_expired()`, line 369):
- Runs on a timer (default every 24 hours via `MEMORY_CLEANUP_INTERVAL_HOURS`)
- Deletes vectors older than `MEMORY_TTL_DAYS` (default 90 days)

**Memory clear** (`clear()`, line 317):
- Supports clearing: all memories, all for an NPC type, or for a specific player+NPC combo

**Health status** (`health_status()`, line 396):
- Reports: `memory_enabled`, `chromadb_connected`, `embedding_model_loaded`,
  `persist_path`, `collection_count`

**Utility functions:**

| Function | Purpose |
|----------|---------|
| `generate_turn_summary_prompt()` | Builds LLM prompt for turn summary generation |
| `fallback_turn_summary()` | Simple concatenation when LLM summary fails |

---

### `app/post_processor.py` -- Response Post-Processing

Processes raw LLM output through a pipeline of filters.

**Processing pipeline** (`process_response()`, line 101):
1. `strip_quotes()` -- remove wrapping single/double quotes
2. `strip_character_prefix()` -- remove echoed character name prefix (e.g., "Guard Mizraen: ...")
3. `filter_era_violations()` -- remove sentences containing banned terms
4. Return empty string if all content was filtered
5. `truncate_at_sentence()` -- truncate at sentence boundary before 450 characters

**Era blocklist** (`ERA_BLOCKLIST`, line 6):
Regex patterns for terms that should never appear in NPC dialogue:
- Post-era: `Plane of Knowledge`, `Planes of Power`, `berserker`, `Discord`, `Muramite`
- Modern language: `technology`, `democracy`, `mental health`, `economy`, `science`,
  `evolution`, `anxiety`, `stress`

**Sentence-level filtering** (`filter_era_violations()`, line 67):
- Splits text on sentence boundaries
- Removes individual sentences containing violations
- Returns remaining clean sentences joined, or empty string if all filtered

**Truncation** (`truncate_at_sentence()`, line 25):
- Max length: 450 characters (`MAX_LENGTH`)
- Finds last sentence-ending punctuation (`.!?`) before the limit
- Falls back to last space if no sentence boundary found

---

## API Endpoints

### `POST /v1/chat`

Primary dialogue generation endpoint.

**Request:** `ChatRequest` JSON body (see models.py section above)

**Response:** `ChatResponse` JSON
```json
{
  "response": "Hail, traveler. Mind yourself in these streets.",
  "tokens_used": 145,
  "error": null,
  "memories_retrieved": 2,
  "memory_stored": true
}
```

**LLM inference parameters** (from environment):
- `LLM_MAX_TOKENS` (default 200) -- max tokens in LLM response
- `LLM_TEMPERATURE` (default 0.7) -- sampling temperature
- Stop sequences: `["\n\n"]`

### `GET /v1/health`

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "model_loaded": true,
  "model_name": "Mistral-7B-Instruct-v0.3-Q4_K_M",
  "memory_enabled": true,
  "chromadb_connected": true,
  "embedding_model_loaded": true,
  "persist_path": "/data/chromadb",
  "collection_count": 14
}
```

### `POST /v1/config/reload`

Hot-reload config files without container restart. Re-initializes the `PromptAssembler`
and all context providers.

**Response:** `{"status": "reloaded"}` or `{"status": "partial", "errors": [...]}`

### `POST /v1/memory/clear`

Clear conversation memories.

**Request:**
```json
{
  "npc_type_id": 9124,       // optional: clear for specific NPC
  "player_id": 12345,         // optional: clear for specific player
  "clear_all": false           // optional: clear everything
}
```

**Response:** `{"cleared": 5}`

---

## Configuration Files

### `config/global_contexts.json`

Pre-compiled cultural context paragraphs organized in a fallback hierarchy:

```json
{
  "_meta": { "version": "1.0", "fallback_chain": ["npc_overrides", "race_class_faction", "race_class", "race"] },
  "race": {
    "1": "You are Human, the most adaptable race on Norrath...",
    "2": "You are Barbarian, born of the frozen north...",
    ...
  },
  "race_class": {
    "1_1": "You are a Human Warrior...",
    ...
  },
  "race_class_faction": {
    "1_1_219": "You are a Human Warrior serving the Guards of Qeynos...",
    ...
  },
  "npc_overrides": {
    "9018": "You are Sir Lucan D'Lere...",
    ...
  }
}
```

Covers all 14 playable races with baseline paragraphs. Race+class and
race+class+faction combinations provide increasingly specific cultural context.

### `config/local_contexts.json`

Per-zone knowledge at three INT-gated detail tiers:

```json
{
  "qeynos": {
    "low": "City good. Dogs to north. Bad dark underground. Ships go west.",
    "medium": "Qeynos is Antonius Bayle's city. The Sabertooth gnolls press...",
    "high": "Qeynos is governed by Antonius Bayle with the Guards of Qeynos..."
  },
  ...
}
```

Covers 30+ zones: all starting cities, major dungeons, overland zones, and Luclin
locations. Low-INT tiers use deliberately simple language; high-INT tiers include named
mobs, level ranges, faction IDs, and tactical information.

### `config/zone_cultures.json`

Zone cultural metadata used by the legacy prompt builder:

```json
{
  "qeynos": {
    "culture": "civic virtue, law-and-order, duty-bound",
    "patron_deity": "Rodcet Nife (Prime Healer) and Karana",
    "key_threats": ["Sabertooth gnolls from Blackburrow", "Bloodsaber cult", "Kane Bayle's corruption"],
    "atmosphere": "Guards call citizens 'citizen.' Formal, slightly paternalistic."
  },
  ...
}
```

### `config/soul_elements.json`

NPC personality data with role defaults and NPC-specific overrides:

```json
{
  "role_defaults": {
    "guard": { "courage": 1, "loyalty": 1, "desires": ["duty"], "fears": ["dishonor"], "disposition": "content" },
    "merchant": { "generosity": -1, "curiosity": 1, "desires": ["wealth"], "disposition": "content" },
    "guildmaster": { "piety": 1, "loyalty": 2, "desires": ["knowledge"], "disposition": "rooted" },
    "priest": { "piety": 2, "generosity": 1, "desires": ["faith"], "disposition": "rooted" }
  },
  "npc_overrides": {
    "382202": { "courage": 3, "loyalty": 2, "honesty": -2, ... },   // Sir Lucan D'Lere
    ...
  }
}
```

Contains ~50 NPC-specific personality overrides for named NPCs across Qeynos, Freeport,
Halas, Erudin, Paineel, Kaladim, Felwithe, Neriak, Shar Vahl, Cabilis, Rivervale, and
Ak'Anon.

---

## Docker Deployment

### Container Configuration

| Setting | Value |
|---------|-------|
| Container name | `akk-stack-npc-llm-1` |
| Build context | `./npc-llm-sidecar` |
| Internal port | 8100 (no external binding) |
| Network | `backend` (Docker internal) |
| Restart policy | `unless-stopped` |
| Memory limit | 6 GB |
| GPU | 1x NVIDIA (all capabilities) |

### Dockerfile (Multi-Stage)

**Stage 1: Builder** (`nvidia/cuda:12.4.1-devel-ubuntu22.04`):
- Python 3.11 with build tools (cmake, ninja)
- CPU-only PyTorch installed first (prevents CUDA PyTorch download by sentence-transformers)
- llama-cpp-python built with CUDA support: `CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_ARCHITECTURES=86"`

**Stage 2: Runtime** (`nvidia/cuda:12.4.1-runtime-ubuntu22.04`):
- Python 3.11 + curl + libgomp
- Python packages copied from builder
- Exposes port 8100
- CMD: `python3.11 -m uvicorn app.main:app --host 0.0.0.0 --port 8100`

### Volume Mounts

| Host Path | Container Path | Mode |
|-----------|---------------|------|
| `./npc-llm-sidecar/models` | `/models` | ro |
| `./npc-llm-sidecar/config` | `/config` | ro |
| `./npc-llm-sidecar/data` | `/data` | rw |
| `./npc-llm-sidecar/app` | `/app/app` | rw (dev mount) |
| `./npc-llm-sidecar/tests` | `/app/tests` | ro |

### Health Check

```yaml
test: ["CMD", "curl", "-sf", "http://localhost:8100/v1/health"]
interval: 30s
timeout: 10s
retries: 3
start_period: 90s    # Model loading takes time
```

### Usage

```bash
# Start with LLM sidecar (overlay compose file)
docker compose -f docker-compose.yml -f docker-compose.npc-llm.yml up -d
# Or via Makefile:
make up-llm

# Run test suite
docker exec akk-stack-npc-llm-1 python3.11 /app/tests/test_suite.py
# Or: make test-llm
```

---

## Environment Variables

### Model & Inference

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_PATH` | `/models/Mistral-7B-Instruct-v0.3-Q4_K_M.gguf` | Path to GGUF model file |
| `LLM_PORT` | `8100` | Service port |
| `LLM_MAX_TOKENS` | `200` | Max tokens in LLM response |
| `LLM_TEMPERATURE` | `0.7` | Sampling temperature |
| `LLM_N_GPU_LAYERS` | `99` | Layers to offload to GPU (99 = all) |
| `LLM_N_CTX` | `2048` | Context window size (tokens) |
| `LLM_N_THREADS` | `6` | CPU threads for inference |
| `LLM_DEBUG_PROMPTS` | `false` | Log full prompts to stdout |

### Token Budgets

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_BUDGET_GLOBAL` | `200` | Max tokens for global cultural context |
| `LLM_BUDGET_LOCAL` | `150` | Max tokens for local zone context |
| `LLM_BUDGET_SOUL` | `150` | Max tokens for soul element text |
| `LLM_BUDGET_MEMORY` | `200` | Max tokens for memory context |
| `LLM_BUDGET_RESPONSE` | `500` | Token reserve for LLM response |
| `LLM_BUDGET_QUEST_HINTS` | `150` | Max tokens for quest hint block |

### Memory System

| Variable | Default | Description |
|----------|---------|-------------|
| `CHROMADB_PATH` | `/data/chromadb` | ChromaDB persistent storage path |
| `MEMORY_ENABLED` | `true` | Enable/disable conversation memory |
| `MEMORY_TOP_K` | `5` | Max memories to retrieve per request |
| `MEMORY_SCORE_THRESHOLD` | `0.2` | Min cosine similarity for memory recall |
| `MEMORY_MAX_PER_PLAYER` | `100` | Max stored memories per player per NPC |
| `MEMORY_TTL_DAYS` | `90` | Days before memories expire |
| `MEMORY_CLEANUP_INTERVAL_HOURS` | `24` | Hours between cleanup runs |
| `MEMORY_RECENCY_WINDOW` | `3` | Recent exchanges to return as fallback |

### Config Paths

| Variable | Default | Description |
|----------|---------|-------------|
| `GLOBAL_CONTEXTS_PATH` | `/config/global_contexts.json` | Global cultural context file |
| `LOCAL_CONTEXTS_PATH` | `/config/local_contexts.json` | Local zone context file |
| `SOUL_ELEMENTS_PATH` | `/config/soul_elements.json` | Soul elements config file |

---

## Dependencies

From `requirements.txt`:

| Package | Version | Purpose |
|---------|---------|---------|
| `fastapi` | `==0.115.6` | Web framework (async, OpenAPI) |
| `uvicorn[standard]` | `==0.34.0` | ASGI server |
| `llama-cpp-python` | `==0.3.4` | GGUF model inference (with CUDA) |
| `pydantic` | `==2.10.4` | Request/response validation |
| `chromadb` | `>=0.5.0` | Vector database for conversation memory |
| `sentence-transformers` | `>=3.0.0` | Embedding model (`all-MiniLM-L6-v2`) |
| `torch` | `>=2.0.0` | PyTorch (CPU-only, for sentence-transformers) |

Note: PyTorch is installed CPU-only via `--index-url https://download.pytorch.org/whl/cpu`
in the Dockerfile before `requirements.txt` is processed, so sentence-transformers does
not trigger a CUDA PyTorch download.

---

## Test Suite

**File:** `tests/test_suite.py`

Automated conversation test suite that validates:

| Test Category | What It Checks |
|---------------|---------------|
| Lore accuracy | City guards know their own city's lore (Freeport vs Qeynos) |
| Racial voice | Dark Elf sounds sinister, references Innoruuk/Teir'Dal |
| INT-gating | Low-INT Ogre gives shorter responses than high-INT NPC |
| Merchant framing | Merchant NPCs frame answers through trade/commerce |
| Era compliance | NPC rejects Plane of Knowledge and Berserker class questions |
| Hostile tone | Scowling NPC does not say "welcome" or "glad to help" |
| Friendly tone | Warmly-regarded NPC does not threaten the player |
| Hallucination | Open-ended questions don't produce invented proper nouns |
| Memory persistence | 3-turn conversation: intro, topic shift, name recall |

**Global banned terms** (always checked): `eldoria`, `erendor`, `elysia`, `scholars' guild`,
`technology`, `economy`, `democracy`, `as an ai`, `plane of knowledge`, `berserker class`, etc.

**Usage:** `docker exec akk-stack-npc-llm-1 python3.11 /app/tests/test_suite.py`

---

## Key Data Flow

### Complete Request Lifecycle

```
1. Player types "/say Hello guard" in Titanium client
2. Client sends OP_ChannelMessage (channel 8 = Say) to zone server
3. Zone server dispatches EVENT_SAY to global_npc.lua
4. global_npc.lua calls llm_bridge.lua:generate_npc_response()
5. llm_bridge.lua builds ChatRequest JSON from NPC/player/zone data:
   - NPC: type_id, name, race, class, level, deity, INT, primary_faction, gender, is_merchant
   - Player: name, race, class, level, character_id
   - Zone: short_name, long_name
   - Faction: level (1-9), tone (text), instruction (behavioral)
   - Message: player's spoken text
6. llm_bridge.lua sends HTTP POST to http://npc-llm:8100/v1/chat
7. Sidecar receives request:
   a. Retrieves memories from ChromaDB (if player_id > 0)
   b. Assembles 8-layer system prompt:
      Layer 1: "You are Guard_Munden, a level 50 Gnome Warrior in West Freeport..."
      Layer 2: Global context (Gnome Warrior cultural paragraph)
      Layer 3: Local context (West Freeport zone knowledge at INT tier)
      Layer 4: Role framing ("Frame your knowledge as tactical intelligence...")
      Layer 5: Faction ("Your attitude toward Player is indifferent. Respond neutrally.")
      Layer 5.5: Quest hints (if Tier 2 NPC)
      Layer 6: Soul elements ("Your personality: somewhat brave... Deep down, you desire duty...")
      Layer 7: Memory context ("Your previous interactions with Player: ...")
      Layer 8: Rules block (response length, era compliance, character rules)
   c. Builds user message: "[The player X speaks to you]\nX: 'Hello guard'\n[Respond in character...]"
   d. Calls llama-cpp-python create_chat_completion()
   e. Post-processes: strip quotes, strip name prefix, filter era violations, truncate
   f. Schedules background turn summary + ChromaDB storage
8. Sidecar returns ChatResponse JSON
9. llm_bridge.lua receives response, calls e.self:Say(response)
10. Zone server sends NPC dialogue to nearby clients
11. Player sees: Guard_Munden says, 'Mind yourself in these streets, traveler.'
```

---

## Extension Points

For integrating new context (e.g., companion context), the key integration points are:

### Adding New Fields to ChatRequest

**File:** `app/models.py` -- add new fields to the `ChatRequest` Pydantic model. Any new
field with a default value is backwards-compatible (existing callers won't break).

### Adding New Prompt Layers

**File:** `app/prompt_assembler.py` -- the `assemble()` method (line 117) constructs layers
sequentially. New layers can be inserted between existing ones. Each layer follows the pattern:
1. Get context from a provider or request field
2. If non-empty, truncate to budget via `_truncate_to_budget()`
3. Append to `lines` list with a blank line separator

### Adding New Context Providers

**File:** `app/context_providers.py` -- new provider classes follow the same pattern:
1. Load config from JSON file at init
2. Expose a `get_context()` method that takes request parameters
3. Register in `main.py:_init_assembler()` and pass to `PromptAssembler`

### Extending the Lua Bridge

**File:** `akk-stack/server/quests/lua_modules/llm_bridge.lua` -- the Lua bridge constructs
the `ChatRequest` JSON payload. New fields added to the Pydantic model must also be populated
here from EQEmu Lua API calls.

### Adding New Config Files

New JSON config files should be:
1. Placed in `npc-llm-sidecar/config/`
2. Volume-mounted read-only in `docker-compose.npc-llm.yml`
3. Path configurable via environment variable
4. Loaded by a provider class that handles `FileNotFoundError` gracefully
