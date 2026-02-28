# NPC Conversation Memory (Pinecone Integration) — Architecture & Implementation Plan

> **Feature branch:** `feature/npc-llm-integration`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-02-24
> **Status:** Approved

---

## Executive Summary

Phase 2 adds persistent conversation memory to the NPC LLM system via Pinecone vector database. When a player speaks to an NPC, the sidecar embeds the exchange using the all-MiniLM-L6-v2 model (~22M parameters, ~90MB), queries Pinecone for the top 5 semantically relevant past exchanges with that player, injects them as context into the LLM prompt, and asynchronously stores the new exchange after responding. Memory is scoped per-NPC-type per-player-character using Pinecone namespaces (`npc_{npc_type_id}`) with metadata filtering on `player_id`. The Pinecone free tier provides 2GB storage (~300K vectors) — more than sufficient for 1–6 players. The only code changes are to the Python sidecar (new memory module, modified chat flow, new endpoints) and the Lua bridge (adding `player_id` to the request payload — a single-line addition). No C++ changes. No database schema changes.

## Existing System Analysis

### Current State

Phase 1 delivered a working NPC conversation pipeline:

**Python sidecar** (`akk-stack/npc-llm-sidecar/app/`):
- `main.py` — FastAPI app with `/v1/chat` and `/v1/health` endpoints. Loads Mistral 7B GGUF model at startup. The chat endpoint builds a system prompt, calls the LLM, post-processes the response, and returns it.
- `models.py` — `ChatRequest` (18 fields including `npc_type_id`, `npc_name`, `player_name`, `faction_level`, `message`) and `ChatResponse` (response text, tokens_used, error).
- `prompt_builder.py` — Constructs system prompt from NPC context, zone culture, and faction behavior. Loads `zone_cultures.json` at startup (25 zones configured).
- `post_processor.py` — Strips quotes, removes character name prefix, filters era violations (14 blocklisted terms), truncates at 450 characters.

**Lua bridge** (`akk-stack/server/quests/lua_modules/llm_bridge.lua`):
- `is_eligible(e)` — Checks INT >= 30, body type exclusion, per-NPC opt-out, local script check
- `build_context(e)` — Gathers NPC/player/zone/faction data. **Currently sends `player_name` but NOT `player_id`**
- `generate_response(context, message)` — `io.popen`/curl to sidecar, JSON encode/decode
- `check_hostile_cooldown(e)` / `set_hostile_cooldown(e)` — Uses `e.other:CharacterID()` for entity variable keys (confirming CharacterID is available in Lua)

**Infrastructure**:
- Docker compose overlay (`docker-compose.npc-llm.yml`) — `npc-llm` service on `backend` network
- 6GB memory limit, NVIDIA GPU reservation, 90s health check start period
- Model mounted read-only from `./npc-llm-sidecar/models/`
- `requirements.txt`: fastapi 0.115.6, uvicorn 0.34.0, llama-cpp-python 0.3.4, pydantic 2.10.4

### Gap Analysis

| PRD Requirement | Current State | Gap |
|----------------|---------------|-----|
| NPC remembers past conversations | Stateless — each request independent | Need Pinecone client, embedding model, memory retrieval/storage pipeline |
| Memory per-NPC-type per-character | No player_id sent to sidecar | Need `player_id` in Lua bridge context + ChatRequest model |
| Topic-relevant retrieval (top-5) | No embedding or vector search | Need sentence-transformers embedding + Pinecone query |
| Memory context in LLM prompt | prompt_builder has no memory injection | Need memory context section in prompt construction |
| Async memory storage after response | Chat endpoint is synchronous | Need background task for vector upsert |
| 90-day TTL cleanup | No cleanup mechanism | Need scheduled cleanup (delete old vectors) |
| Memory clear admin endpoint | No such endpoint | Need `/v1/memory/clear` endpoint |
| Graceful degradation without Pinecone | N/A | Need try/except around all Pinecone operations |
| Health check reports memory status | Only reports LLM model status | Need Pinecone connection check in health endpoint |
| City culture governs memory tone | Zone culture in prompt but no memory-specific guidance | Need memory-tone instructions in system prompt |
| Faction change acknowledged | No faction tracking in memory | Need `faction_at_time` in vector metadata |

## Answers to PRD Open Questions

### Q1: Pinecone free tier limits — is 100K vectors sufficient?

**Answer: Yes, more than sufficient. The free tier now supports ~300K vectors (2GB storage).**

Estimation for 1–6 players:
- Active conversations per player per day: ~10-20 (generous estimate)
- Players: 6 (max)
- Vectors per conversation: 1
- Daily vectors: 6 × 20 = 120
- Monthly vectors: 120 × 30 = 3,600
- Yearly vectors: 3,600 × 12 = 43,200
- With 90-day TTL: Maximum steady-state ≈ 10,800 vectors

The Pinecone Starter plan provides 2GB storage (~300K vectors at 384 dimensions), 2M write units/month (~300K writes), and 1M read units/month (~100K reads). Our estimated 3,600 writes and ~3,600 reads per month uses roughly 1% of the monthly allowance. The free tier is more than adequate for years of play.

**One concern**: Starter plan indexes are paused after 3 weeks of inactivity. For a personal 1–6 player server that might sit idle during vacations, a periodic keepalive query (weekly cron or sidecar heartbeat) prevents auto-pause.

### Q2: Embedding model resource impact — does all-MiniLM-L6-v2 fit alongside Mistral 7B?

**Answer: Yes, with margin.** all-MiniLM-L6-v2 requires ~90MB disk and ~44MB RAM at inference time. It has 22M parameters (vs Mistral 7B's 7B) and processes text in single-digit milliseconds on CPU. Current sidecar container has a 6GB memory limit. Mistral 7B Q4_K_M uses ~4–5GB. Adding 44MB for the embedding model is negligible. The 6GB limit is sufficient — no increase needed.

The embedding model loads via the `sentence-transformers` library, which depends on PyTorch. PyTorch adds ~500MB-1GB to the Docker image and ~200-400MB to runtime memory. This is the main resource cost, not the embedding model itself. **Recommendation**: Use the `sentence-transformers` library with CPU-only PyTorch to minimize image size. The total runtime memory with both models should stay under 5.5GB.

### Q3: Pinecone serverless cold-start latency

**Answer: Expect 1-3 seconds for the first query to an inactive namespace, ~10-50ms for subsequent queries.**

Pinecone serverless caches frequently accessed namespaces. For NPCs that haven't been visited in weeks, the first query may take 1-3 seconds as data is loaded. For small namespaces (which ours will be — at most a few hundred vectors per NPC-player pair), fast linear scans deliver ~10ms response times once warm.

**Mitigation strategy**: The Phase 1 typing indicator ("considers your words carefully...") already absorbs 1-3 seconds of latency. Adding 1-3 seconds of cold-start on top of LLM inference (1-2 seconds) could push total latency to 4-5 seconds for the first interaction with a long-dormant NPC. This is a one-time cost per namespace per session.

To handle this:
1. Set a Pinecone query timeout of 3 seconds
2. If Pinecone times out, proceed without memory (fallback to Phase 1 stateless)
3. The memory storage still happens async, so the next interaction will be warm
4. Log cold-start timeouts for monitoring

### Q4: Player character ID availability in Lua

**Answer: Available and already in use.** `e.other:CharacterID()` is confirmed in the Lua API:
- Binding: `zone/lua_client.cpp:3698` — `.def("CharacterID", ...)`
- Declaration: `zone/lua_client.h:156` — `uint32 CharacterID()`
- Already used in `llm_bridge.lua:51` for hostile cooldown keys

The Phase 1 `build_context()` sends `player_name` but not `player_id`. **A one-line addition to `build_context()` and a corresponding one-line addition to `generate_response()` is required.** This contradicts the PRD's "No Lua bridge changes" non-goal, but the change is minimal (two lines) and necessary for reliable memory keying. Using `player_name` as the memory key would be fragile — character names could theoretically be reused if a character is deleted and a new one created with the same name.

### Q5: Memory cleanup scheduling

**Answer: Use a background task inside the sidecar, triggered by a daily timer.**

Options considered:
1. **Cron job inside container** — requires installing cron, managing pid files, adds Dockerfile complexity
2. **Separate maintenance script** — requires separate scheduling infrastructure
3. **Admin endpoint** — manual only, could be forgotten
4. **In-app background task** — asyncio timer in FastAPI, no external dependencies

**Decision: In-app background task (option 4).** FastAPI supports background tasks via `asyncio`. A daily timer (configurable via `MEMORY_CLEANUP_INTERVAL_HOURS` env var, default 24) triggers cleanup:
1. List all namespaces in the index
2. For each namespace, query for vectors with `timestamp < (now - TTL_DAYS)`
3. Delete matched vector IDs in batches

This is the simplest approach — no cron, no separate scripts, no external scheduling. The cleanup runs in the existing sidecar process. For 1–6 players with ~10K steady-state vectors, cleanup takes seconds.

### Q6: Graceful degradation when Pinecone is unavailable

**Answer: Wrap all Pinecone operations in try/except; on any failure, proceed without memory.**

The degradation strategy has three layers:

1. **Startup**: If `PINECONE_API_KEY` is not set or `MEMORY_ENABLED=false`, the memory module initializes in disabled mode. All memory operations become no-ops. The sidecar operates exactly as Phase 1.

2. **Per-request retrieval failure**: If Pinecone query fails (timeout, API error, network issue), log the error and proceed with an empty memory list. The LLM generates a Phase 1-equivalent stateless response. No error is returned to the player.

3. **Per-request storage failure**: Memory storage is asynchronous (background task). If the upsert fails, log the error. The conversation still completes normally — the exchange is simply not remembered. This is indistinguishable from natural forgetting.

Detection: The Pinecone Python client raises `PineconeException` subtypes for connection errors, timeout errors, and API errors. A simple try/except catches all of them.

### Q7: Memory for NPC types with multiple spawns

**Answer: Shared memory for all spawns of the same NPC type, with zone recorded in metadata.**

The PRD states: "A different Guard Hanlon in a different zone is the same NPC type and shares the memory (they are 'the same guard' for memory purposes)." This means memories are keyed by `npc_type_id`, not by individual spawn.

For **named NPCs** (Guard Hanlon, Merchant Talia), this is correct — they represent the same individual regardless of where they spawn.

For **generic NPC types** (e.g., `a_guard` with npc_type_id 999 spawned 50 times across a city), all 50 spawns share memory. This could feel odd — but on a 1–6 player server, players are unlikely to notice because:
1. Generic guards of the same type are meant to be interchangeable
2. The zone is stored in vector metadata and can be used as a soft filter (prioritize memories from the same zone in relevance scoring)
3. A player doesn't typically have deep conversations with generic guards

**Implementation**: Namespace = `npc_{npc_type_id}`. Zone is stored in metadata but NOT used as a hard filter — it's available for future use (e.g., Phase 4 could add zone-scoped memory for generic types).

## Technical Approach

### Architecture Decision

Phase 2 extends the Python sidecar with a new memory module. No C++ changes. Minimal Lua change (2 lines to add `player_id` to the request). All memory logic is contained in the sidecar.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `app/memory.py` | Create (new module) | Core memory operations: embed, query, store, cleanup. Encapsulates all Pinecone interaction. |
| `app/main.py` | Modify | Add memory retrieval before prompt building, async storage after response, new endpoints, startup initialization |
| `app/models.py` | Modify | Add `player_id` optional field to ChatRequest; add memory fields to ChatResponse |
| `app/prompt_builder.py` | Modify | Accept memory context list; inject between system prompt and user message |
| `requirements.txt` | Modify | Add `pinecone-client`, `sentence-transformers`, `torch` (CPU) |
| `Dockerfile` | Modify | Install sentence-transformers dependencies |
| `docker-compose.npc-llm.yml` | Modify | Add Pinecone environment variables, increase memory limit if needed |
| `llm_bridge.lua` | Modify (2 lines) | Add `player_id = e.other:CharacterID()` to build_context and generate_response |

**Why not C++ rules?** Phase 2's configuration (Pinecone API key, embedding model path, TTL, top-K) is sidecar-specific. Server rules govern C++ runtime behavior; they have no mechanism to reach the Python sidecar. Environment variables in Docker compose are the correct configuration mechanism for container-level settings.

### Data Model

**No new database tables.** All memory data is stored in Pinecone (external vector database).

#### Pinecone Index Schema

**Index**: One shared index, name configured via `PINECONE_INDEX` env var
**Dimension**: 384 (all-MiniLM-L6-v2 output)
**Metric**: Cosine similarity
**Cloud/Region**: AWS us-east-1 (Starter plan constraint)

#### Namespace Strategy

Each NPC type gets its own namespace: `npc_{npc_type_id}`

Example: `npc_1234` for Guard Hanlon (NPC type ID 1234)

#### Vector Schema

```json
{
    "id": "conv_{player_id}_{unix_timestamp}",
    "values": [0.023, -0.118, ...],
    "metadata": {
        "player_id": 5678,
        "player_name": "Soandso",
        "player_message": "Tell me about the gnolls",
        "npc_response": "The Sabertooth gnolls have been raiding...",
        "zone": "qeynos2",
        "timestamp": 1740355200,
        "faction_at_time": 2,
        "turn_summary": "Player asked about gnoll raids, NPC described Sabertooth threat near Qeynos"
    }
}
```

**Embedding text**: The text embedded for semantic search is `turn_summary` — a brief summary combining the player's question and NPC's response topic. This produces better retrieval than embedding raw dialogue because it captures the semantic meaning of the exchange rather than exact phrasing.

The `turn_summary` is generated by the LLM as a one-line summary appended to the chat completion request (a cheap additional generation of ~20 tokens). If summary generation fails, fall back to: `"Player asked: {player_message_truncated}. NPC responded about: {npc_response_first_sentence}"`.

### Code Changes

#### C++ Changes

**None.** Phase 2 requires no C++ server modifications.

#### Lua/Script Changes

**`akk-stack/server/quests/lua_modules/llm_bridge.lua`** — Modified (2 lines)

In `build_context(e)`, add:
```lua
player_id = e.other:CharacterID(),
```

In `generate_response(context, message)`, add `player_id` to the request table:
```lua
player_id = context.player_id,
```

**No other Lua changes.** `global_npc.lua`, `llm_config.lua`, and `llm_faction.lua` are unchanged.

#### Python Sidecar Changes

**1. `app/memory.py`** — Created (new module, ~200 lines)

Core memory operations:

```python
class MemoryManager:
    """Manages NPC conversation memory via Pinecone and sentence-transformers."""

    def __init__(self, api_key, index_name, enabled=True):
        # Initialize Pinecone client and sentence-transformers model
        # If api_key is empty or enabled=False, operate in disabled (no-op) mode

    def embed(self, text: str) -> list[float]:
        # Generate 384-dim embedding using all-MiniLM-L6-v2
        # Returns empty list on error

    async def retrieve(self, npc_type_id: int, player_id: int, query_text: str,
                       top_k: int = 5, score_threshold: float = 0.7) -> list[dict]:
        # Query Pinecone namespace npc_{npc_type_id}
        # Filter: player_id == player_id
        # Apply recency weighting: adjusted_score = score * (1 / (1 + days_since))
        # Return list of memory dicts with player_message, npc_response, timestamp, zone, faction
        # Returns empty list on any error (graceful degradation)

    async def store(self, npc_type_id: int, player_id: int, player_name: str,
                    player_message: str, npc_response: str, zone: str,
                    faction_level: int, turn_summary: str):
        # Embed turn_summary, upsert to Pinecone namespace npc_{npc_type_id}
        # Check per-player vector count; prune oldest if > MEMORY_MAX_PER_PLAYER
        # No-op on any error (fire-and-forget)

    async def clear(self, npc_type_id: int = None, player_id: int = None,
                    clear_all: bool = False) -> int:
        # Delete vectors matching the specified criteria
        # Returns count of deleted vectors

    async def cleanup_expired(self, ttl_days: int = 90):
        # List all namespaces, delete vectors with timestamp older than ttl_days
        # Called by the scheduled background task
```

**2. `app/main.py`** — Modified

Changes:
- Import and initialize `MemoryManager` at startup (in `lifespan`)
- In `/v1/chat`: retrieve memories before prompt building, generate turn summary, store memory async
- Add `/v1/memory/clear` endpoint
- Add scheduled cleanup background task
- Update `/v1/health` to report memory status

Modified chat flow:
```
1. Receive ChatRequest
2. Check if model loaded
3. NEW: Retrieve memories (MemoryManager.retrieve)
4. Build system prompt (with memory context)
5. Build user message
6. LLM inference
7. Post-process response
8. NEW: Generate turn summary (additional short LLM call)
9. Return response
10. NEW: Store memory async (MemoryManager.store as background task)
```

**3. `app/models.py`** — Modified

```python
class ChatRequest(BaseModel):
    # ... existing fields unchanged ...
    player_id: int = 0  # NEW: optional, for memory lookup. 0 = no memory.

class ChatResponse(BaseModel):
    response: Optional[str] = None
    tokens_used: int = 0
    error: Optional[str] = None
    memories_retrieved: int = 0  # NEW: how many memories were used
    memory_stored: bool = False  # NEW: whether the exchange was stored

class MemoryClearRequest(BaseModel):
    npc_type_id: Optional[int] = None
    player_id: Optional[int] = None
    clear_all: bool = False

class MemoryClearResponse(BaseModel):
    cleared: int = 0
```

**4. `app/prompt_builder.py`** — Modified

Add function `format_memory_context(memories: list[dict], player_name: str) -> str`:
- Formats retrieved memories as natural-language context for the LLM
- Includes recency info ("a few days ago", "last week", "some time ago")
- Includes faction-at-time for faction-change detection
- Returns empty string if no memories

Modified `build_system_prompt(req, memories=None)`:
- After zone cultural context and faction behavior, inject memory-specific instruction:
  ```
  When referencing past conversations, maintain the same cultural voice and
  attitude appropriate to your city and role. Do not shift to warm or familiar
  phrasing simply because you remember the player. Your memory of past
  interactions should be impressionistic — you recall the gist and your
  feelings about it, not exact words. Only reference memories when they are
  naturally relevant to the current conversation.
  ```
- Inject formatted memory context between system prompt and user message

Memory context format in prompt:
```
Previous interactions with {player_name}:
- A few days ago: Player asked about gnoll raids. You described the Sabertooth
  threat near Qeynos. (Player was at Warmly faction at the time)
- Last week: Player mentioned heading toward Blackburrow. You warned about
  the dangers within.
```

#### Database Changes

**None.** All memory data is in Pinecone.

#### Configuration Changes

**Docker compose overlay** (`docker-compose.npc-llm.yml`) — add environment variables:

```yaml
environment:
  # ... existing Phase 1 vars ...
  - PINECONE_API_KEY=${PINECONE_API_KEY:-}
  - PINECONE_INDEX=${PINECONE_INDEX:-npc-memory}
  - MEMORY_ENABLED=${MEMORY_ENABLED:-true}
  - MEMORY_TOP_K=${MEMORY_TOP_K:-5}
  - MEMORY_SCORE_THRESHOLD=${MEMORY_SCORE_THRESHOLD:-0.4}
  - MEMORY_MAX_PER_PLAYER=${MEMORY_MAX_PER_PLAYER:-100}
  - MEMORY_TTL_DAYS=${MEMORY_TTL_DAYS:-90}
  - MEMORY_CLEANUP_INTERVAL_HOURS=${MEMORY_CLEANUP_INTERVAL_HOURS:-24}
```

**`.env` additions**:
```
PINECONE_API_KEY=<your-api-key>
PINECONE_INDEX=npc-memory
MEMORY_ENABLED=true
```

**Memory limit**: The current 6GB limit should be sufficient (Mistral 7B ~4.5GB + sentence-transformers ~0.5GB + overhead ~1GB). Monitor during testing; increase to 8GB if needed.

**`requirements.txt`** — add:
```
pinecone-client>=5.0.0
sentence-transformers>=3.0.0
torch>=2.0.0  # CPU-only; will be constrained to CPU in Dockerfile
```

**Dockerfile** — modify to install CPU-only PyTorch:
```dockerfile
# In builder stage, before pip install:
RUN python3.11 -m pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu
```

**Score threshold note**: The PRD suggests 0.7 as the score threshold. Based on experience with all-MiniLM-L6-v2 and cosine similarity, 0.7 is quite high — many topically relevant but differently-worded exchanges score 0.4–0.6. **Recommend starting at 0.4 and tuning up if irrelevant memories surface.** This is configurable via `MEMORY_SCORE_THRESHOLD` env var.

## Implementation Sequence

| # | Task | Agent | Depends On | Scope |
|---|------|-------|------------|-------|
| 1 | Create `app/memory.py` — MemoryManager class with embed, retrieve, store, clear, cleanup methods | python-expert | — | ~200 lines Python |
| 2 | Modify `app/main.py` — integrate MemoryManager into chat flow, add `/v1/memory/clear` endpoint, add scheduled cleanup, update health check | python-expert | 1 | ~80 lines modified |
| 3 | Modify `app/models.py` — add `player_id` to ChatRequest, memory fields to ChatResponse, new MemoryClear models | python-expert | — | ~20 lines added |
| 4 | Modify `app/prompt_builder.py` — add `format_memory_context()`, update `build_system_prompt()` with memory injection and city-culture memory tone instructions | python-expert | — | ~60 lines added |
| 5 | Modify `llm_bridge.lua` — add `player_id` to `build_context()` and `generate_response()` | lua-expert | — | 2 lines Lua |
| 6 | Update Docker configuration — add Pinecone env vars to compose overlay, add dependencies to requirements.txt, update Dockerfile for CPU PyTorch + sentence-transformers | infra-expert | — | ~30 lines config |
| 7 | Integration testing — verify memory storage, retrieval, degradation, and clear endpoint | python-expert | 1–6 | Manual testing |

**Dependency graph:**
```
Tasks 1, 3, 4, 5, 6 are independent — can run in parallel
Task 2 depends on Tasks 1, 3, 4 (needs MemoryManager, models, and prompt builder changes)
Task 7 depends on all previous tasks
```

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Pinecone cold-start adds 1-3s to first query | Certain (first access) | Low | Typing indicator absorbs delay. Fallback to stateless if query times out at 3s. One-time cost per session per NPC. |
| Embedding model + LLM exceed container memory | Low | Medium | all-MiniLM-L6-v2 adds ~500MB total (model + PyTorch). Current 6GB limit has ~1.5GB headroom. Monitor; increase to 8GB if needed. |
| Pinecone Starter plan pauses after 3 weeks idle | Medium | Low | Add weekly keepalive query in the scheduled cleanup task. If paused, sidecar degrades to stateless mode until manually resumed. |
| Turn summary generation adds latency | Low | Low | Summary is ~20 tokens, generated in ~50-100ms. If it times out, use fallback concatenation of player message + NPC first sentence. |
| Memory retrieval returns irrelevant results | Medium | Low | Score threshold (configurable, starting at 0.4) + recency weighting filter weak matches. Prompt instructs NPC to only reference memories when naturally relevant. |
| Player attempts memory manipulation via prompt injection | Medium | Low | Memories are stored as metadata, not as user-editable content. The LLM sees memories in the system portion of the prompt, not the user portion. Standard prompt injection defenses from Phase 1 apply. |

### Compatibility Risks

**Zero risk to existing gameplay.** Phase 2 changes are entirely additive:
- The 2-line Lua change adds an optional field (`player_id`) that the sidecar treats as 0 if missing (backward compatible)
- All Pinecone operations are wrapped in try/except — any failure degrades to Phase 1 behavior
- The `/v1/chat` endpoint remains backward compatible — old requests without `player_id` work exactly as before
- Memory can be disabled entirely via `MEMORY_ENABLED=false`

### Performance Risks

| Concern | Analysis | Mitigation |
|---------|----------|------------|
| Embedding latency | all-MiniLM-L6-v2 on CPU: ~5-20ms per text. Two embeddings per request (query + storage). | Negligible — adds ~40ms total. |
| Pinecone query latency | Warm: ~10-50ms. Cold: 1-3 seconds. | Typing indicator absorbs delay. Timeout at 3s. |
| PyTorch memory footprint | CPU-only PyTorch adds ~200-400MB RAM. | Within the 6GB container limit. |
| Docker image size increase | sentence-transformers + PyTorch CPU adds ~1-2GB to image. | One-time build cost. Acceptable. |
| Async storage overhead | Background task for Pinecone upsert runs after response is sent. | No impact on response latency. uvicorn handles background tasks natively. |

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes, with high confidence.

1. **Pinecone Python client**: Well-documented, actively maintained. The `pinecone-client` package (v5+) supports serverless indexes, namespace operations, and metadata filtering natively.

2. **sentence-transformers**: Mature library. `all-MiniLM-L6-v2` is the most popular model on HuggingFace with excellent documentation. CPU inference is fast (<20ms per embedding).

3. **Memory injection in prompt**: The existing `prompt_builder.py` constructs prompts as string concatenation. Adding a memory section between system context and user message is straightforward.

4. **Async storage**: FastAPI's `BackgroundTasks` or `asyncio.create_task()` handle fire-and-forget operations. Pinecone's Python client supports async operations.

5. **player_id in Lua**: `e.other:CharacterID()` confirmed available and already used in the codebase.

**Hardest part**: Tuning the memory retrieval quality — getting the right score threshold, recency weighting formula, and embedding text format to surface relevant memories without including irrelevant ones. This requires iterative testing with real conversations.

### Pass 2: Simplicity

**Is this the simplest approach?** Yes.

1. **Could we skip Pinecone and use local storage?** We could store embeddings in SQLite or even flat files, but Pinecone provides managed vector similarity search with metadata filtering out of the box. Building this from scratch would be more complex, not less. The free tier handles our scale easily.

2. **Could we skip the embedding model and use keyword matching?** Keyword matching would be simpler but would miss semantic similarity ("gnoll raids" wouldn't match "Sabertooth clan attacks"). The embedding model is small (~90MB) and fast (<20ms). The quality improvement justifies the minimal added complexity.

3. **Could we skip turn summaries and embed raw dialogue?** We could, but raw dialogue like "Tell me about the gnolls" and "The Sabertooth gnolls have been raiding..." would produce worse retrieval than a summary like "Player asked about gnoll raids near Qeynos." The summary generation is ~20 tokens of additional LLM output — trivial cost.

4. **Could we defer the cleanup task?** With 90-day TTL and 1–6 players, vector count stays low for months without cleanup. But the in-app timer is ~20 lines of code and prevents technical debt from accumulating.

5. **What can be deferred?**
   - Zone-based memory filtering for generic NPCs (Phase 4)
   - Memory-aware quest integration (Phase 3)
   - Cross-NPC gossip (Phase 4)
   - NPC backstory seeding (Phase 4)

### Pass 3: Antagonistic

**What could go wrong?**

1. **Pinecone API key leaked**: The API key is in `.env` which is gitignored. Docker environment variables are visible in `docker inspect`. **Mitigation**: The `.env` file pattern is already established for database credentials. Same security model applies. The Pinecone Starter plan has limited blast radius (read/write to one index only).

2. **Memory causes NPC to reveal quest information**: An NPC remembers a past conversation where the player discussed a quest location, and in a future interaction references it, effectively giving a hint. **Mitigation**: The system prompt already instructs "Never offer quests, promise rewards, or claim to provide services." Memory content is context, not instruction. The LLM filters what it references based on the system prompt rules.

3. **Stale memory from pre-fix era violations**: If Phase 1 produced an era-violating response that was stored as memory, it could resurface. **Mitigation**: The post-processor runs on ALL final responses, including memory-influenced ones. Era violations in memory context are rephrased by the LLM, and any remaining violations are caught by the post-processor filter.

4. **Player has deep conversation with one NPC type, then speaks to a different spawn**: The PRD says same-type NPCs share memory. If a player has a 20-exchange history with Guard Hanlon (type 1234) in South Qeynos, and then speaks to Guard Hanlon (same type 1234) in North Qeynos, the NPC references the South Qeynos conversations. This is by design per the PRD but could feel slightly odd. **Mitigation**: Zone is stored in metadata. The prompt says "previous interactions with {player_name}" without specifying location, making the reference location-agnostic.

5. **Concurrent requests to the same NPC namespace**: Two players talking to the same NPC type simultaneously trigger concurrent Pinecone queries. **Mitigation**: Pinecone handles concurrent reads natively. Writes are upserts (idempotent). The `conv_{player_id}_{timestamp}` vector ID ensures no collisions because player_ids differ.

6. **Turn summary fails to generate**: The LLM produces garbage or empty summary. **Mitigation**: Fallback to simple concatenation: `"Player asked: {first_50_chars_of_message}. NPC responded about: {first_sentence_of_response}"`. This is less semantic but still functional for retrieval.

7. **City-culture tone broken in memory callbacks**: An NPC in Neriak references past conversations with warm phrasing like "Good to see you again." **Mitigation**: The system prompt includes explicit memory-tone instruction: "When referencing past conversations, maintain the same cultural voice and attitude appropriate to your city and role. Do not shift to warm or familiar phrasing simply because you remember the player." The zone culture data already loaded in Phase 1 reinforces this. The lore-master's 5 binding constraints (Neriak cold, Cabilis suspicious, Oggok simple, Vah Shir honor-based) are enforced via the existing city culture mechanism in the system prompt.

8. **Pinecone Starter plan rate limit hit**: With 1M read units and 2M write units per month, and our estimated 3,600 reads and 3,600 writes, we use ~1% of the allowance. Even 10x the estimated usage would stay well within limits. **Not a concern.**

### Pass 4: Integration

**Implementation sequence walkthrough:**

1. **Tasks 1, 3, 4, 5, 6 run in parallel** — MemoryManager, models, prompt builder, Lua change, and Docker config are independent. Maximum parallelism.

2. **Task 2 depends on 1, 3, 4** — The main.py integration needs the MemoryManager class (Task 1), the updated models (Task 3), and the updated prompt builder (Task 4). This is the integration point where everything comes together.

3. **Task 7 depends on everything** — Integration testing requires all components deployed.

**Context each agent needs:**
- **python-expert**: This architecture doc (for all Python changes), the existing sidecar code (4 files), the PRD (for memory behavior requirements and lore constraints)
- **lua-expert**: This architecture doc (Lua section only — 2 lines), existing `llm_bridge.lua`
- **infra-expert**: This architecture doc (Docker/config section), existing compose overlay and Dockerfile

**Pinecone index creation**: The python-expert should create the Pinecone index as part of the MemoryManager initialization (create-if-not-exists pattern). The index spec:
- Name: from `PINECONE_INDEX` env var
- Dimension: 384
- Metric: cosine
- Cloud: aws, Region: us-east-1 (Starter plan constraint)

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| python-expert | 1 (memory.py), 2 (main.py), 3 (models.py), 4 (prompt_builder.py), 7 (integration test) | All Python sidecar development. The memory module, endpoint integration, prompt changes, and testing are tightly coupled Python work best done by one agent. |
| lua-expert | 5 (llm_bridge.lua) | Minimal Lua change (2 lines). Could be done by python-expert, but keeping it separate preserves the pattern of Lua changes going through a Lua expert. |
| infra-expert | 6 (Docker config) | Docker compose, Dockerfile, requirements.txt changes. Follows same pattern as Phase 1. |

## Validation Plan

The game-tester agent should verify all 14 acceptance criteria from the PRD:

- [ ] **AC1: NPC references a past conversation** — Speak to an NPC, wait 5+ minutes, speak again on a related topic. Second response references first conversation naturally.
- [ ] **AC2: Memory is per-character** — Two different characters speak to the same NPC. Memories are independent (NPC does not cross-reference).
- [ ] **AC3: Memory is per-NPC** — A player discusses gnolls with Guard Hanlon and trade with Merchant Talia. Each NPC only references their own conversations.
- [ ] **AC4: Memory retrieval is topic-relevant** — After 5+ conversations on various topics, ask about a specific topic. NPC references the most relevant past exchange, not the most recent.
- [ ] **AC5: No memory at hostile factions** — Speak to an NPC at Threatening/Scowling faction. No memory stored or retrieved. Standard hostile behavior.
- [ ] **AC6: Faction change acknowledged** — Converse with an NPC at negative faction, improve faction, return. NPC acknowledges the changed relationship.
- [ ] **AC7: Graceful degradation without Pinecone** — Remove `PINECONE_API_KEY`, restart sidecar. NPC still responds (Phase 1 stateless). No errors, no crashes.
- [ ] **AC8: Memory clear endpoint works** — Call `POST /v1/memory/clear` with npc_type_id and player_id. Next conversation shows no memory.
- [ ] **AC9: Memory does not add noticeable latency** — Response time with memory stays within 3-second timeout. Typing indicator bridges delay.
- [ ] **AC10: First conversation indistinguishable from Phase 1** — New character's first conversation with any NPC has no memory references.
- [ ] **AC11: NPC does not recite transcripts** — Over 10 return visits, NPC references memories in natural, impressionistic language. Never quotes exact player messages or own prior responses.
- [ ] **AC12: 90-day retention limit** — Memories older than 90 days are cleaned up (test with artificial timestamps if needed).
- [ ] **AC13: Response stays in character and era** — Over 10 memory-influenced conversations, all responses remain in-character, era-appropriate.
- [ ] **AC14: Health check reports memory status** — `GET /v1/health` returns memory system status (Pinecone connected, embedding model loaded).

**Additional technical verification:**
- [ ] **T1: player_id sent from Lua** — Verify curl request to sidecar includes `player_id` field (check sidecar logs).
- [ ] **T2: Memory stored asynchronously** — Verify response returns before Pinecone upsert completes (check timing).
- [ ] **T3: Keepalive prevents index pause** — Verify weekly keepalive query runs (check sidecar logs).
- [ ] **T4: City-culture tone in memory callbacks** — Verify Neriak NPC uses cold phrasing, Oggok NPC uses simple syntax when referencing memories.

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
>
> **Implementation sequence:**
> 1. Create memory.py + models.py + prompt_builder.py changes → **python-expert** (parallel)
> 2. Lua bridge player_id addition → **lua-expert** (parallel)
> 3. Docker config changes → **infra-expert** (parallel)
> 4. main.py integration → **python-expert** (after 1)
> 5. Integration testing → **python-expert** (after all above)
>
> **Assigned experts:** python-expert, lua-expert, infra-expert
