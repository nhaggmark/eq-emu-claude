# NPC LLM Phase 2.5 — Lore Integration + Prompt Pipeline — Architecture & Implementation Plan

> **Feature branch:** `feature/npc-llm-phase2.5`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-02-25
> **Status:** Draft

---

## Executive Summary

Phase 2.5 replaces the current thin, flat system prompt in the NPC LLM sidecar with a structured 4-layer prompt pipeline that feeds culturally rich, lore-accurate context to the model. The approach is entirely sidecar-side: no C++ changes, no database schema changes, no new server rules. The implementation adds two new Python modules (`prompt_assembler.py`, `context_providers.py`), two new JSON data files (`global_contexts.json`, `local_contexts.json`), minor modifications to the existing Lua bridge and sidecar request model, and a context window increase from 1024 to 2048 tokens. Zero new framework dependencies.

## Existing System Analysis

### Current State

The NPC LLM system is a Python FastAPI sidecar (`npc-llm-sidecar/`) running Mistral-7B-Q4_K_M via llama-cpp-python. It connects to the EQEmu server via a Lua bridge (`llm_bridge.lua`) that intercepts `event_say` for NPCs without local quest scripts. The flow:

1. **Lua bridge** (`llm_bridge.lua`) checks eligibility (no local script, INT >= 30, sentient body type), builds context, calls sidecar via `io.popen("curl")`
2. **Sidecar** (`main.py`) receives ChatRequest, builds system prompt (`prompt_builder.py`), retrieves memories (`memory.py`), runs inference, post-processes (`post_processor.py`)
3. **Prompt construction** (`prompt_builder.py`) is flat: NPC identity line, era line, thin zone culture blurb from `zone_cultures.json`, faction instruction, memories, rules block. ~400-600 tokens total with n_ctx=1024.
4. **Memory system** (`memory.py`) uses embedded ChromaDB with sentence-transformers for per-player, per-NPC conversation history with semantic retrieval and diversity filtering.

Key files:
- `npc-llm-sidecar/app/main.py` (230 lines) — FastAPI app, model loading, chat endpoint
- `npc-llm-sidecar/app/prompt_builder.py` (206 lines) — system prompt + user message construction
- `npc-llm-sidecar/app/models.py` (41 lines) — Pydantic request/response models
- `npc-llm-sidecar/app/memory.py` (375 lines) — ChromaDB memory manager
- `npc-llm-sidecar/app/post_processor.py` (113 lines) — era filtering, truncation
- `npc-llm-sidecar/config/zone_cultures.json` (247 lines) — 22 city zone culture blurbs
- `server/quests/lua_modules/llm_bridge.lua` (158 lines) — Lua-to-sidecar bridge
- `server/quests/lua_modules/llm_config.lua` (39 lines) — configuration
- `server/quests/lua_modules/llm_faction.lua` (51 lines) — faction tone mappings
- `docker-compose.npc-llm.yml` (67 lines) — sidecar container definition

### Gap Analysis

| PRD Requirement | Current State | Gap |
|-----------------|---------------|-----|
| Cultural global context (race+class+deity+faction) | Thin zone culture blurb (~50 tokens) per city | Need pre-compiled cultural paragraphs keyed by NPC attributes with fallback chain |
| Local context (zone knowledge, INT-gated) | Not implemented | Need per-zone knowledge at 3 detail tiers |
| Soul element placeholder | Not implemented | Need reserved token budget space in assembler |
| Token budgeting | No budgeting; prompt grows unbounded | Need layer-based token budget with model tokenizer |
| n_ctx=2048 | Currently 1024 | Simple env var change |
| NPC deity in payload | Field exists in ChatRequest (default 0) but never sent from Lua | **NPC deity is NOT in the database** — `npc_types` has no `deity` column. `NPCType.deity` is marked "not loaded from DB" and defaults to 0 for all NPCs. Must use alternative approach. |
| NPC INT in payload | Not sent (though used for eligibility check in Lua bridge) | Add to payload |
| NPC primary faction in payload | Not sent | Lua API `GetPrimaryFaction()` confirmed available |
| NPC gender in payload | Not sent | Lua API `GetGender()` available |
| NPC merchant_id for role inference | Not sent | Need to investigate Lua API availability |
| Existing memory unaffected | Working | Must not break; only add token budget awareness |

### Critical Finding: NPC Deity Not in Database

The `npc_types` table has **no deity column**. The `NPCType` C++ struct has a `deity` field but it is explicitly commented as `//not loaded from DB` in `zone/zonedump.h:48`. It defaults to 0 for all NPCs. `GetDeity()` will always return 0 for NPCs.

**Resolution:** NPC deity cannot be used as a lookup key. Instead, we derive religious identity from the NPC's **primary faction**. Most city NPCs belong to factions with clear deity affiliations:
- Guards of Qeynos → Rodcet Nife / Karana
- Dreadguard Inner (Neriak) → Innoruuk
- Oggok Guards → Rallos Zek
- Clerics of Tunare → Tunare

The global context lookup key becomes: **race + class + primary_faction** (with fallback to race + class, then race alone). Faction-to-deity mapping is embedded in the authored context paragraphs, not computed.

### INT Distribution Analysis

Queried `npc_types` for the PRD's proposed INT tiers:

| INT Tier | Count | Percentage | Avg INT |
|----------|-------|------------|---------|
| Low (<75) | 10,845 | 16.1% | 32.5 |
| Medium (75-120) | 8,493 | 12.6% | 98.1 |
| High (>120) | 48,192 | 71.4% | 230.5 |

**In city zones specifically:**

| INT Tier | Count | Avg INT |
|----------|-------|---------|
| Low (<75) | 1,432 | 22 |
| Medium (75-120) | 731 | 99 |
| High (>120) | 1,713 | 159 |

City zones show a reasonably balanced distribution across all three tiers (37%/19%/44%). The PRD's three-tier system will produce meaningful differentiation.

### Faction Coverage

- **40,681 NPCs** (60.3%) have faction assignments via `npc_faction_id`
- **1,173 unique faction sets** exist
- Top city factions: Heretics (143 NPCs), Citizens of Shar Vahl (142), Dark Bargainers (131), King Ak'Anon (111)
- Guards of Qeynos: 40 NPCs, Freeport Militia: 69 NPCs, Oggok Guards: 40 NPCs
- NPCs without faction get no faction-specific global context (fall back to race+class)

### Race+Class Coverage

- **194 unique race+class combinations** exist in city zones (playable races only)
- **322 unique combos** exist server-wide
- Top combos: Human Warrior (1,541), Dwarf Warrior (771), Gnome Warrior (754)
- Class 41 appears frequently — this is the GM/Merchant class used for shopkeepers

### Merchant Detection

- **2,981 NPCs** have `merchant_id > 0` (functional merchants)
- This provides an accurate role signal: if `merchant_id > 0`, the NPC is a merchant regardless of their combat class

## Technical Approach

### Architecture Decision

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| Python sidecar (prompt pipeline) | Major refactor | Core of the feature — prompt assembly must be restructured |
| Python sidecar (context providers) | New module | Load and serve pre-compiled context data |
| Python sidecar (request model) | Minor addition | 3 new optional fields |
| JSON config files | New data files | Pre-compiled cultural and zone context |
| Lua bridge | Minor addition | Send 4 new fields in payload |
| Docker compose | Env var change | n_ctx 1024→2048 |
| C++ server | **No changes** | Not needed |
| Database schema | **No changes** | Not needed |
| Server rules | **No changes** | LLM is external sidecar, not governed by EQEmu rules |

This is the least-invasive approach: all changes are in the sidecar (Python + JSON config) and the Lua bridge. No C++ compilation, no database migrations, no server restarts required (only sidecar container restart).

### Data Model

No database changes. All new data is stored in JSON config files mounted into the sidecar container via the existing volume mount (`./npc-llm-sidecar/config:/config:ro`).

#### global_contexts.json Structure

```json
{
  "_meta": {
    "version": "1.0",
    "description": "Pre-compiled cultural context paragraphs",
    "fallback_chain": ["race_class_faction", "race_class", "race"]
  },
  "race": {
    "1": "You are Human. Humans are the most diverse...",
    "2": "You are Barbarian. Born of the frozen north...",
    "6": "You are Teir'Dal, a dark elf. Innoruuk's children...",
    "10": "You strong. You ogre. Short words. Big hits..."
  },
  "race_class": {
    "1_1": "You are a Human Warrior...",
    "6_11": "You are a Teir'Dal Necromancer..."
  },
  "race_class_faction": {
    "1_1_262": "You are a guard of Qeynos, sworn to protect...",
    "6_11_370": "You are a Dreadguard of Neriak's Third Gate..."
  },
  "npc_overrides": {
    "1077": "You are Captain Tillin of the Qeynos Guard...",
    "999311": "You are Plagus Ladeson. You once loved..."
  }
}
```

Key design decisions:
- **Keyed by numeric IDs** (not names) to avoid string normalization issues
- **`npc_overrides`** section for the 13+ NPCs with canonical backstories from quest scripts (per lore-master recommendation)
- **Fallback chain**: npc_override → race+class+faction → race+class → race
- **Max ~200 tokens per entry** as specified in PRD

#### local_contexts.json Structure

```json
{
  "_meta": {
    "version": "1.0",
    "description": "Per-zone knowledge at three INT-gated detail tiers"
  },
  "qeynos": {
    "low": "City safe. Bad dogs north. Big bugs south.",
    "medium": "The gnolls hold Blackburrow to the northwest. The catacombs beneath the city harbor the Bloodsaber cult. Kithicor Forest to the east turns deadly after dark.",
    "high": "The Sabertooth gnolls of Blackburrow launch seasonal raids south through Qeynos Hills. The Bloodsaber cult — Bertoxxulous worshippers — operate from the catacombs beneath the city, threatening Antonius Bayle's rule from within. Kithicor Forest fills with powerful undead at nightfall. The Karana Plains stretch east toward Freeport, patrolled by bandits and griffons."
  },
  "freporte": {
    "low": "City dangerous. Lucan boss. Orcs east.",
    "medium": "Sir Lucan D'Lere controls the Militia. The Deathfist orcs camp in the East Commonlands. The Knights of Truth oppose Lucan from within.",
    "high": "..."
  }
}
```

Key design decisions:
- **Three tiers map directly to INT ranges**: low (<75), medium (75-120), high (>120)
- **Adjacent zone awareness** is embedded in the high-tier text (not computed)
- **Role framing** is NOT per-zone data — it is applied as a suffix instruction in the prompt assembler based on the NPC's class category

### Code Changes

#### Python/Sidecar Changes

##### New: `app/prompt_assembler.py` (~120 lines)

The core of Phase 2.5. Replaces the flat `build_system_prompt()` with a layered, token-budgeted assembler.

```python
class PromptAssembler:
    """Assembles system prompts from 4 context layers with token budgeting."""
    
    def __init__(self, llm, global_provider, local_provider, budgets):
        self.llm = llm  # For tokenizer access
        self.global_provider = global_provider
        self.local_provider = local_provider
        self.budgets = budgets  # Dict of layer name -> max tokens
    
    def count_tokens(self, text: str) -> int:
        """Count tokens using the model's actual tokenizer."""
        return len(self.llm.tokenize(text.encode("utf-8")))
    
    def assemble(self, req, memories=None) -> str:
        """Build the complete system prompt from all layers."""
        # 1. Identity line (always present, ~30 tokens)
        # 2. Global context (race+class+faction lookup with fallback)
        # 3. Local context (zone knowledge at INT-gated tier)
        # 4. Role framing instruction (class-based)
        # 5. Faction instruction (existing)
        # 6. Soul elements (placeholder — empty in 2.5)
        # 7. Memory context (existing, now token-budgeted)
        # 8. Rules block (existing, always last)
        # Token budget enforcement with truncation priority
```

Token budget defaults (configurable via env vars):

| Layer | Budget | Env Var |
|-------|--------|---------|
| Identity + era | ~50 tokens | Fixed |
| Rules block | ~150 tokens | Fixed |
| Global context | 200 tokens | `LLM_BUDGET_GLOBAL` |
| Local context | 150 tokens | `LLM_BUDGET_LOCAL` |
| Role framing | ~30 tokens | Fixed |
| Soul elements | 0 tokens (Phase 3) | `LLM_BUDGET_SOUL` |
| Memory | 200 tokens | `LLM_BUDGET_MEMORY` |
| Response reserve | 500 tokens | `LLM_BUDGET_RESPONSE` |

Total at n_ctx=2048: ~1280 tokens for system prompt + ~500 for user message and response + ~268 margin.

Truncation priority (bottom-up): memory → soul → local context (drop to lower tier) → global context (truncate at sentence boundary) → rules (never truncated).

##### New: `app/context_providers.py` (~100 lines)

```python
class GlobalContextProvider:
    """Loads and serves pre-compiled cultural context paragraphs."""
    
    def __init__(self, config_path: str):
        # Load global_contexts.json at startup
    
    def get_context(self, npc_type_id: int, race: int, class_: int, 
                    primary_faction: int) -> str:
        """Return the best-match cultural context paragraph.
        
        Lookup chain:
        1. npc_overrides[npc_type_id]
        2. race_class_faction[f"{race}_{class_}_{primary_faction}"]
        3. race_class[f"{race}_{class_}"]
        4. race[str(race)]
        5. "" (empty — should never happen if all 16 races are covered)
        """


class LocalContextProvider:
    """Loads and serves zone knowledge at INT-gated detail tiers."""
    
    def __init__(self, config_path: str):
        # Load local_contexts.json at startup
    
    def get_context(self, zone_short: str, npc_int: int) -> str:
        """Return zone knowledge at the appropriate detail tier.
        
        INT mapping:
        - <75: "low" tier
        - 75-120: "medium" tier
        - >120: "high" tier
        """
    
    def get_int_tier(self, npc_int: int) -> str:
        if npc_int < 75:
            return "low"
        elif npc_int <= 120:
            return "medium"
        else:
            return "high"


# Class-to-role mapping for role framing
ROLE_FRAMES = {
    "military": {
        "classes": [1, 3, 5, 4],  # Warrior, Paladin, SK, Ranger
        "frame": "Frame your knowledge as tactical intelligence and threat assessment."
    },
    "commerce": {
        "classes": [9],  # Rogue (+ merchant_id check)
        "frame": "Frame your knowledge through trade, commerce, and practical concerns."
    },
    "scholar": {
        "classes": [12, 14, 13, 11],  # Wizard, Enchanter, Magician, Necromancer
        "frame": "Frame your knowledge with scholarly analysis and historical context."
    },
    "spiritual": {
        "classes": [2, 6, 10],  # Cleric, Druid, Shaman
        "frame": "Frame your knowledge through spiritual and moral assessment."
    },
    "social": {
        "classes": [8, 7, 15],  # Bard, Monk, Beastlord
        "frame": "Frame your knowledge as stories, rumors, and community concerns."
    }
}

def get_role_frame(npc_class: int, is_merchant: bool) -> str:
    """Return role framing instruction. Merchants override class-based role."""
    if is_merchant:
        return ROLE_FRAMES["commerce"]["frame"]
    for role_data in ROLE_FRAMES.values():
        if npc_class in role_data["classes"]:
            return role_data["frame"]
    return ""  # Class 41 (GM) and others — no specific framing
```

##### Modified: `app/models.py`

Add 3 new optional fields to `ChatRequest`:

```python
class ChatRequest(BaseModel):
    # ... existing fields ...
    npc_int: int = 80          # NPC INT stat for knowledge tier gating
    npc_primary_faction: int = 0  # Primary faction ID for cultural context
    npc_gender: int = 0        # 0=male, 1=female, 2=neutral
    npc_is_merchant: bool = False  # Whether NPC has merchant_id > 0
```

All fields have defaults for backward compatibility — Phase 2 Lua bridges that haven't been updated will still work.

##### Modified: `app/prompt_builder.py`

- Extract `RACE_NAMES`, `CLASS_NAMES`, `FACTION_LABELS`, and `format_memory_context()` into a shared location (or leave in prompt_builder and import from assembler)
- `build_system_prompt()` is **kept but deprecated** — the assembler calls it as a fallback if context providers fail to load
- `build_user_message()` is unchanged
- `load_zone_cultures()` remains for backward compatibility but is superseded by LocalContextProvider

##### Modified: `app/main.py`

- Initialize `GlobalContextProvider` and `LocalContextProvider` in `lifespan()`
- Create `PromptAssembler` instance with LLM tokenizer reference
- Replace `build_system_prompt(req, memories)` call in `/v1/chat` with `assembler.assemble(req, memories)`
- Pass `_llm` reference to assembler for `tokenize()` access

#### Lua/Script Changes

##### Modified: `server/quests/lua_modules/llm_bridge.lua`

Add 4 new fields to `build_context()` and `generate_response()`:

```lua
function llm_bridge.build_context(e)
    local faction_level = e.other:GetFaction(e.self)
    local faction_data = faction_map[faction_level] or faction_map[5]

    return {
        -- ... existing fields ...
        npc_int = e.self:GetINT(),
        npc_primary_faction = e.self:GetPrimaryFaction(),
        npc_gender = e.self:GetGender(),
        npc_is_merchant = (e.self:MerchantType() > 0),
        -- npc_deity intentionally omitted — not in DB, always 0
    }
end
```

And add the same 4 fields to the `request` table in `generate_response()`.

**Lua API verification:**
- `e.self:GetINT()` — confirmed available (already used in eligibility check)
- `e.self:GetPrimaryFaction()` — confirmed available in `lua_npc.cpp:194` and registered in `lua_npc.cpp:1032`
- `e.self:GetGender()` — confirmed available (inherited from `Mob` via `lua_mob.cpp`)
- `e.self:MerchantType()` — need to verify. Alternative: check `GetClass() == 41` (Merchant class) as a heuristic

**MerchantType verification:** Searching the Lua bindings...

The `Lua_NPC` class does not expose `MerchantType()` directly. However, `GetClass()` is available. The workaround:
- NPCs with class 41 (GM/Merchant) are merchants
- NPCs with any other class but `merchant_id > 0` in the DB are also merchants (dual-role NPCs)
- Since we cannot access `merchant_id` from Lua directly, we use class 41 as the merchant signal. This covers the vast majority of merchants. For the rare dual-role NPC (e.g., a Warrior who is also a merchant), they will get their combat-class framing instead of commerce framing — an acceptable trade-off.

Updated approach: `npc_is_merchant = (e.self:GetClass() == 41)` in Lua.

#### Configuration Changes

##### Modified: `docker-compose.npc-llm.yml`

```yaml
environment:
  # Changed:
  - LLM_N_CTX=${LLM_N_CTX:-2048}        # Was 1024
  - LLM_MAX_TOKENS=${LLM_MAX_TOKENS:-200}  # Was 150 — allow slightly longer responses
  # Added:
  - LLM_BUDGET_GLOBAL=${LLM_BUDGET_GLOBAL:-200}
  - LLM_BUDGET_LOCAL=${LLM_BUDGET_LOCAL:-150}
  - LLM_BUDGET_SOUL=${LLM_BUDGET_SOUL:-0}
  - LLM_BUDGET_MEMORY=${LLM_BUDGET_MEMORY:-200}
  - LLM_BUDGET_RESPONSE=${LLM_BUDGET_RESPONSE:-500}
  - GLOBAL_CONTEXTS_PATH=${GLOBAL_CONTEXTS_PATH:-/config/global_contexts.json}
  - LOCAL_CONTEXTS_PATH=${LOCAL_CONTEXTS_PATH:-/config/local_contexts.json}
```

Memory limit stays at 6g. At n_ctx=2048, Mistral-7B-Q4_K_M needs approximately:
- Model weights: ~4GB VRAM
- KV cache at 2048 tokens: ~1GB VRAM
- Total: ~5GB — within the 6GB container limit

#### C++ Changes

**None.** No C++ changes are needed for Phase 2.5. All NPC data needed (INT, primary faction, gender, class) is already accessible through the existing Lua API bindings.

#### Database Changes

**None.** No database changes needed.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Author `global_contexts.json` — pre-compiled cultural paragraphs for all 16 playable races, top race+class combos in cities, major city factions, and 13 NPC overrides | data-expert | — | Large (JSON data authoring from lore bible) |
| 2 | Author `local_contexts.json` — per-zone knowledge at 3 INT tiers for all 22 city zones + 10-15 high-traffic outdoor zones | data-expert | — | Large (JSON data authoring from zone overview + NPC census) |
| 3 | Implement `context_providers.py` — GlobalContextProvider, LocalContextProvider, role framing logic | lua-expert | — | Small (~100 lines Python) |
| 4 | Implement `prompt_assembler.py` — layered prompt assembly with token budgeting | lua-expert | 3 | Medium (~120 lines Python) |
| 5 | Update `models.py` — add `npc_int`, `npc_primary_faction`, `npc_gender`, `npc_is_merchant` fields | lua-expert | — | Trivial (4 lines) |
| 6 | Update `main.py` — integrate prompt assembler, init context providers at startup | lua-expert | 3, 4, 5 | Small |
| 7 | Update `llm_bridge.lua` — add 4 new fields to `build_context()` and `generate_response()` | lua-expert | 5 | Small |
| 8 | Update `docker-compose.npc-llm.yml` — n_ctx bump, new env vars | config-expert | — | Trivial |
| 9 | Integration test — verify prompt assembly with real NPC data, check token budgets, test fallback chain | lua-expert | 1-8 | Medium |

**Dependency graph:**
```
Tasks 1, 2 (data authoring) ─────────────┐
Tasks 3, 5 (providers, models) ──→ Task 4 ──→ Task 6 ──→ Task 9
Task 8 (docker config) ──────────────────→ Task 9
Task 7 (lua bridge) ─────────────────────→ Task 9
```

Tasks 1+2 and Tasks 3+5 can proceed in parallel. Task 4 depends on Task 3. Task 6 depends on 3, 4, 5. Tasks 7 and 8 are independent. Task 9 requires everything.

**Note on agent assignment:** Tasks 1-2 are assigned to `data-expert` because they require systematic transformation of the lore bible and zone data into structured JSON. Tasks 3-7 and 9 are assigned to `lua-expert` because they span both Python sidecar code and Lua bridge code — a single agent familiar with both the sidecar architecture and the Lua bridge avoids handoff overhead. Task 8 is assigned to `config-expert` because it involves Docker compose and environment variable configuration.

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| n_ctx=2048 exceeds GPU VRAM | Low | High — sidecar crashes | Memory limit already 6g, model needs ~5g at 2048. Monitor VRAM usage in testing. Fall back to 1536 if needed. |
| Token budget miscalculation | Medium | Medium — prompt truncation or overflow | Use actual tokenizer (`llm.tokenize()`) not char estimates. Add debug logging for token counts per layer. |
| Global context data quality | Medium | High — defeats purpose of Phase 2.5 | Data-expert must source exclusively from lore bible. Review pass by architect before integration. |
| Inference latency increase from larger prompt | Low | Medium — exceeds 5s target | Prompt is larger but response generation is the bottleneck, not prompt processing. Monitor in testing. |
| Lua API `GetPrimaryFaction()` returns unexpected values | Low | Low — falls back to race+class context | Tested via grep: confirmed in `lua_npc.cpp`. Returns `npc_faction.primaryfaction` via the NPC's `npc_faction_id`. For NPCs without faction, returns 0 → falls back gracefully. |

### Compatibility Risks

- **Backward compatibility:** All new `ChatRequest` fields have defaults. An old Lua bridge that doesn't send the new fields will still work — the sidecar falls back to race-only global context and no local context. This is the same behavior as today.
- **Existing memory system:** Completely unchanged. Memory retrieval and storage continue to work identically. Only change is that memory entries may be truncated by the token budget if the system prompt is large.
- **Existing quest scripts:** Phase 2.5 only affects NPCs routed through the LLM global hook. NPCs with local quest scripts are unaffected.

### Performance Risks

- **VRAM usage:** Doubling n_ctx adds ~500MB-1GB KV cache. Current 6g limit should accommodate this. If not, reduce to n_ctx=1536 (still a 50% improvement).
- **Prompt construction CPU:** Negligible — JSON lookups and string concatenation. Token counting via `llm.tokenize()` adds a small cost but is cached per-request.
- **Startup time:** Loading two JSON files adds milliseconds to startup. Negligible.
- **Zone server impact:** Zero — the only server-side change is 4 additional fields in the Lua curl payload (~50 bytes).

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes. All required data is accessible:
- NPC INT: `GetINT()` — confirmed in Lua API, already used for eligibility
- NPC primary faction: `GetPrimaryFaction()` — confirmed in `lua_npc.cpp:1032`
- NPC gender: `GetGender()` — confirmed in `lua_mob.cpp`
- NPC class for role inference: `GetClass()` — confirmed, already used

**Hardest part:** Authoring the global and local context JSON data files. This is not technically hard but requires careful, systematic work translating the 133KB lore bible into ~200-token cultural paragraphs. The data-expert must cover:
- 16 racial baselines
- ~30-50 race+class combinations (prioritized by city NPC count)
- ~20-30 race+class+faction combinations (major city factions)
- 13 NPC-specific overrides
- ~30-35 zones with 3 detail tiers each

**Deity gap resolved:** NPC deity is not in the database and `GetDeity()` always returns 0 for NPCs. This is handled by deriving religious identity from primary faction in the pre-compiled global context paragraphs. A guard in faction "Guards of Qeynos" gets a paragraph that mentions Rodcet Nife — the faction-to-deity mapping is baked into the authored text, not computed.

### Pass 2: Simplicity

**Is this the simplest approach?** Yes. The alternatives considered and rejected:

1. **LangChain/LlamaIndex integration:** Rejected in Phase 2 testing. These frameworks add complexity without solving the core problem (insufficient context quality). Our approach is simpler: pre-compile the context, look it up, inject it.

2. **RAG with vector database for lore:** Would require embedding the entire lore bible and doing semantic search per request. Adds latency, complexity, and a vector database dependency. Pre-compiled lookup is faster, simpler, and more deterministic.

3. **C++ changes to add deity to npc_types:** Would require a database migration, schema change, data backfill for ~67K NPCs, C++ repository regeneration, and server rebuild. Massive overkill when faction already encodes the same information.

4. **Separate deity lookup table in sidecar:** Would require the sidecar to query the EQEmu database directly. Adds a database dependency to the sidecar (currently stateless except for ChromaDB). Rejected in favor of faction-based derivation.

**Can anything be deferred?**
- Role framing is lightweight and adds value. Keep.
- NPC overrides (13 NPCs) could be deferred but are specifically requested by lore-master. Keep.
- Local context for non-city zones could be deferred to a follow-up. **Decision: include top 10-15 outdoor zones, defer the rest.** Start with zones that have the most player traffic: Commonlands, Greater Faydark, Kithicor, Blackburrow, Crushbone, Qeynos Hills, etc.

### Pass 3: Antagonistic

**What could go wrong?**

1. **Global context paragraph quality:** If the authored text is generic or inaccurate, the model will produce generic or inaccurate output. **Mitigation:** Data-expert sources exclusively from lore bible. Architect reviews before integration.

2. **Fallback chain produces bad results:** If a Vah Shir Beastlord (race 130, class 15) has no race+class entry and falls back to the generic Vah Shir racial paragraph, the beastlord-specific identity is lost. **Mitigation:** The racial baseline is still far better than zero context. Expand coverage in follow-up phases.

3. **Token budget squeezes memory:** A long global context + local context could leave little room for memory entries. **Mitigation:** Truncation priority puts memory below global/local context. In practice, 200 tokens of memory = ~3 memory entries, which is sufficient for grounding consistency.

4. **Player gaming the system:** A player could exploit the INT-gating by finding high-INT NPCs to extract complete zone intelligence. **Mitigation:** This is explicitly intended by the PRD ("talking to NPCs should be rewarding"). It's a feature, not a bug.

5. **Large JSON files slow startup:** The global_contexts.json file could grow large if many entries are authored. **Mitigation:** Even with 200 entries at 200 tokens each, the file is ~100KB. Loading takes milliseconds.

6. **Race condition in prompt assembler:** If the LLM model reference is None (model failed to load), the assembler cannot count tokens. **Mitigation:** Fall back to character-based estimation (~4 chars per token) when tokenizer is unavailable.

7. **Merchant role override misfire:** Class 41 check catches most merchants but misses NPCs with other classes who also sell items. **Mitigation:** Acceptable — a warrior-merchant getting military framing instead of commerce framing is a minor quality issue, not a correctness issue.

### Pass 4: Integration

**End-to-end flow verification:**

1. Player says something to an NPC in Qeynos
2. `global_npc.lua` fires `event_say`, calls `llm_bridge.is_eligible(e)` — passes
3. `llm_bridge.build_context(e)` gathers all fields including new INT, primary_faction, gender, is_merchant
4. `llm_bridge.generate_response(context, message)` sends JSON to sidecar via curl
5. Sidecar receives `ChatRequest` with all fields (new fields have defaults if missing)
6. `PromptAssembler.assemble(req, memories)`:
   a. `global_provider.get_context(req.npc_type_id, req.npc_race, req.npc_class, req.npc_primary_faction)` → returns "You are a guard of Qeynos..."
   b. `local_provider.get_context(req.zone_short, req.npc_int)` → returns zone knowledge at appropriate tier
   c. `get_role_frame(req.npc_class, req.npc_is_merchant)` → returns military framing
   d. Memory context formatted (existing code)
   e. Token budgets applied, layers truncated if needed
   f. Rules block appended
7. LLM generates response grounded in rich cultural context
8. Post-processor filters era violations, truncates at sentence boundary
9. Response returned to Lua bridge → displayed in game

**Task dependency verification:**
- Tasks 1+2 (data) and Tasks 3+5 (code) are independent → can proceed in parallel
- Task 4 (assembler) needs Task 3 (providers) — correct dependency
- Task 6 (main.py integration) needs 3, 4, 5 — correct
- Task 7 (Lua bridge) needs Task 5 (models) to know the field names — correct
- Task 8 (docker) is independent — correct
- Task 9 (integration test) needs everything — correct

**Context for implementation agents:**
- lua-expert needs: current sidecar code (main.py, prompt_builder.py, models.py), PRD for requirements, this architecture doc for specifications
- data-expert needs: lore bible, zone overview, NPC census, faction data, this architecture doc for JSON structure specs
- config-expert needs: docker-compose.npc-llm.yml, this architecture doc for env var specs

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| **data-expert** | 1, 2 | Authors JSON context data files from lore bible and zone data. Requires systematic data transformation, not code writing. |
| **lua-expert** | 3, 4, 5, 6, 7, 9 | Implements all code changes (Python sidecar + Lua bridge). Single agent avoids handoff overhead between two codebases. |
| **config-expert** | 8 | Docker compose configuration. Trivial scope but must be done by config specialist. |

## Answers to PRD Open Questions

### 1. Global Context Coverage Scope

**Answer:** Author entries at three tiers, prioritized by actual city NPC population:

- **Tier 1 (mandatory):** 16 racial baselines — every NPC gets at least this
- **Tier 2 (high priority):** ~40 race+class combinations — covers the top combos by NPC count in city zones (Human Warrior, Gnome Warrior, Dwarf Warrior, etc.)
- **Tier 3 (high priority):** ~25 race+class+faction combinations — covers major city factions (Guards of Qeynos, Freeport Militia, Dreadguard, Oggok Guards, etc.)
- **Tier 4 (specific):** 13 NPC-specific overrides for NPCs with canonical quest backstories

Total: ~94 entries. This covers all NPCs in city zones via the fallback chain. Entries can be expanded incrementally without code changes.

### 2. Local Context Authoring Method

**Answer:** Hybrid approach. Start with the zone overview and NPC census data as the structural foundation, then hand-write the natural-language paragraphs for each tier. The data provides the facts (what spawns, what factions, what level ranges); the authoring provides the voice (how an NPC would describe this). Auto-generation is not suitable because the three tiers require different vocabulary, sentence complexity, and framing — not just different amounts of detail.

**Scope:** 22 city zones (mandatory) + 10-15 high-traffic outdoor zones (Commonlands, Greater Faydark, Kithicor, Blackburrow, Crushbone, Qeynos Hills, Butcherblock, Everfrost, Nektulos, Innothule, Feerrott). ~35 zones total with 3 tiers each = ~105 zone entries.

### 3. NPC Role Inference Accuracy

**Answer:** Use a two-signal approach:
1. If `GetClass() == 41` (GM/Merchant class), classify as merchant → commerce framing
2. Otherwise, map class to role category (warrior→military, wizard→scholar, etc.)

This handles 95%+ of NPCs correctly. The rare dual-role NPC (e.g., a Warrior with merchant_id who isn't class 41) will get military framing instead of commerce framing — an acceptable minor inaccuracy. The `npc_is_merchant` field is sent in the payload so the sidecar can use it for role determination, but the Lua-side detection relies on class since `merchant_id` is not directly exposed in the Lua API.

### 4. Performance Impact of n_ctx=2048

**Answer:** Low risk. Mistral-7B-Q4_K_M at n_ctx=2048 requires ~5GB VRAM total (4GB weights + ~1GB KV cache). The container memory limit is 6GB with GPU reservation. This should fit within constraints. If VRAM is exhausted, fall back to n_ctx=1536 (still 50% improvement over 1024). The prompt length does not significantly affect generation speed — the model generates the same number of output tokens regardless of prompt length. Must be verified in testing.

### 5. Token Budget Tuning

**Answer:** All token budgets are configurable via environment variables with sensible defaults. The initial budget allocation (200 global + 150 local + 0 soul + 200 memory + 500 response = 1100 allocated of 2048) leaves ~948 tokens for identity, rules, role framing, faction instruction, and margin. This is generous. Budgets can be tuned via env vars without code changes or container rebuilds (just restart the container).

### 6. Canonical Soul Elements from Quest Scripts

**Answer:** Implement as NPC-specific overrides in `global_contexts.json`. The `npc_overrides` section keyed by `npc_type_id` takes highest priority in the fallback chain. When an NPC override exists, it replaces the race+class+faction paragraph entirely. This handles the 13 known canonical backstories without waiting for Phase 3's soul system. New overrides can be added by editing the JSON file — no code changes needed.

## Validation Plan

- [ ] **No hallucinated deities:** 20 test conversations across 5+ cities — every deity reference must be canonical Norrath pantheon
- [ ] **No hallucinated locations:** 20 test conversations — every zone/city/dungeon reference must exist in Classic-Luclin
- [ ] **Culturally distinct voices:** Compare NPC responses across Qeynos guard, Neriak dark elf, Oggok ogre, Rivervale halfling, Erudin erudite — each must have recognizably different tone and vocabulary
- [ ] **INT-gated responses:** Ask the same question to low-INT, medium-INT, and high-INT NPCs in the same zone — detail level must visibly correlate with INT
- [ ] **Token budget respected:** Enable `LLM_DEBUG_PROMPTS=true`, verify system prompt token count never exceeds budget, verify truncation happens gracefully at sentence boundaries
- [ ] **Response time under 5 seconds:** Measure end-to-end latency for 10 conversations at n_ctx=2048
- [ ] **Fallback chain works:** Test with an NPC that has no faction (should get race+class context), an NPC with unusual race+class combo (should get race-only context), and an NPC override (should get override text)
- [ ] **Backward compatibility:** Verify that a Lua bridge without the new fields still produces valid responses (new fields default to 0/false)
- [ ] **Memory system unaffected:** Verify memories are stored and retrieved correctly with the new prompt structure
- [ ] **Era compliance:** Verify post-processor era blocklist still functions as safety net

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
