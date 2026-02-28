# NPC LLM Phase 3: Soul & Story — Architecture & Implementation Plan

> **Feature branch:** `feature/npc-llm-phase3`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-02-25
> **Status:** Draft

---

## Executive Summary

Phase 3 enriches the NPC LLM sidecar with three data-driven enhancements: (1) individual backstory overrides for 80-110 key NPCs in `global_contexts.json`, (2) a quest hint system that lets Tier 2 Lua quest scripts fall back to the LLM for off-keyword speech with guided responses, and (3) a soul element framework that populates Layer 6 of the prompt assembler with personality traits, motivations, and recruitment disposition. All changes are confined to the Python sidecar, Lua quest scripts, and JSON configuration files — no C++ server changes, no database schema changes, and no protocol modifications are required.

## Existing System Analysis

### Current State

The NPC LLM system consists of three interconnected layers:

**1. Lua Bridge** (`akk-stack/server/quests/lua_modules/llm_bridge.lua`):
- `is_eligible(e)` — checks NPC eligibility (INT, body type, opt-out, local script)
- `build_context(e)` — builds a context table with NPC stats, faction, zone, and player info
- `generate_response(context, message)` — calls the sidecar via curl and returns NPC dialogue
- Called from `global_npc.lua:event_say()` for NPCs **without** local quest scripts (Tier 1 only)

**2. Python Sidecar** (`akk-stack/npc-llm-sidecar/app/`):
- `models.py` — `ChatRequest` model with 20 fields including `npc_deity` (exists but not populated from Lua), `npc_type_id`, faction data
- `prompt_assembler.py` — 8-layer prompt pipeline with token budgeting:
  - Layer 1: Identity + era line (~50 tokens, fixed)
  - Layer 2: Global context (race/class/faction lookup, up to 200 tokens)
  - Layer 3: Local context (zone knowledge, up to 150 tokens)
  - Layer 4: Role framing (~30 tokens, fixed)
  - Layer 5: Faction instruction (fixed)
  - **Layer 6: Soul elements (placeholder — 0 budget, empty)**
  - Layer 7: Memory context (up to 200 tokens)
  - Layer 8: Rules block (fixed, never truncated)
- `context_providers.py` — `GlobalContextProvider` with fallback chain: npc_override > race_class_faction > race_class > race > empty
- `post_processor.py` — Response cleanup: strip quotes, prefix removal, era violation filter, 450-char truncation

**3. Configuration** (`akk-stack/npc-llm-sidecar/config/`):
- `global_contexts.json` — 12 `npc_overrides`, 20 `race_class_faction`, 20 `race_class`, 14 `race` entries
- `local_contexts.json` — per-zone knowledge at INT-gated tiers
- Docker compose env vars control token budgets: `LLM_BUDGET_SOUL=0`

**4. Current Tier Architecture**:
- **Tier 1** (unscripted NPCs): `global_npc.lua:event_say()` → `llm_bridge` → sidecar. NPCs with local quest scripts are skipped entirely.
- **Tier 2** (scripted NPCs with LLM fallback): Not yet implemented. This is what Phase 3 adds.

### Gap Analysis

| Gap | Current State | Required State |
|-----|--------------|----------------|
| Key NPC identity | 12 npc_overrides in global_contexts.json | 80-110 overrides covering guildmasters, city leaders, guards |
| Quest NPC fallback | Scripted NPCs go silent on off-keyword speech | LLM fallback with quest hints guides players to valid keywords |
| NPC personality | Layer 6 is empty (0 budget placeholder) | Soul elements (traits, motivations, disposition) color dialogue |
| NPC deity context | `npc_deity` field exists in ChatRequest but is never populated | Deity passed from Lua to sidecar for soul alignment |
| Tier 2 pattern | No mechanism for quest scripts to call LLM | `llm_bridge` exposes `build_quest_context()` for scripted NPCs |
| Config reload | Sidecar loads config at startup only | Reload endpoint allows iteration without container restart |

## Technical Approach

### Architecture Decision

This feature is entirely **configuration + Lua + Python sidecar**. No C++ server changes are needed. No database schema changes. No protocol modifications.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `global_contexts.json` | Data expansion | 80-110 new NPC backstory overrides — pure JSON content authoring |
| `soul_elements.json` (new) | New config file | Soul element definitions with role defaults and per-NPC overrides |
| `prompt_assembler.py` | Code modification | Populate Layer 6 with soul element text; inject quest hints between L5 and L6 |
| `context_providers.py` | Code addition | New `SoulElementProvider` class to load and serve soul data |
| `models.py` | Model extension | Add optional `quest_hints` and `quest_state` fields to ChatRequest |
| `main.py` | Minor update | Initialize soul provider; add `/v1/config/reload` endpoint |
| `llm_bridge.lua` | Code addition | Add `build_quest_context()` and populate `npc_deity` |
| Quest scripts (20-30) | Script extension | Add Tier 2 LLM fallback blocks with quest_hints |
| `docker-compose.npc-llm.yml` | Config update | Set `LLM_BUDGET_SOUL=150`, add `SOUL_ELEMENTS_PATH` |

**Why no C++ changes:**
- `GetDeity()` already exists on `Lua_Mob` (inherited by `Lua_NPC`) — confirmed at `eqemu/zone/lua_mob.h:107`
- `npc_deity` already exists as a field in `ChatRequest` (models.py:11) — just needs to be populated from Lua
- `AutoInjectSaylinksToSay` rule (ruletypes.h:930) defaults to `true` — [bracketed keywords] in NPC Say() automatically become clickable saylinks without any code changes
- The sidecar's `/v1/chat` endpoint accepts arbitrary JSON fields via the Pydantic model — we just add optional fields

### Data Model

No database changes. All new data is stored in JSON config files.

#### Soul Elements Config (`soul_elements.json`)

```json
{
  "_meta": {
    "version": "1.0",
    "description": "NPC soul elements — personality traits, motivations, and recruitment disposition",
    "axes": ["courage", "generosity", "honesty", "piety", "curiosity", "loyalty"],
    "axis_range": "-3 to +3 (0 = neutral, unset = no influence)",
    "dispositions": ["rooted", "content", "curious", "restless", "eager"]
  },
  "role_defaults": {
    "guard": {
      "courage": 1,
      "loyalty": 1,
      "desires": ["duty"],
      "fears": ["dishonor"],
      "disposition": "content"
    },
    "merchant": {
      "generosity": -1,
      "curiosity": 1,
      "desires": ["wealth"],
      "disposition": "content"
    },
    "guildmaster": {
      "piety": 1,
      "loyalty": 2,
      "desires": ["knowledge"],
      "disposition": "rooted"
    },
    "priest": {
      "piety": 2,
      "generosity": 1,
      "desires": ["faith"],
      "disposition": "rooted"
    }
  },
  "npc_overrides": {
    "1077": {
      "courage": 2,
      "generosity": -1,
      "honesty": 1,
      "curiosity": 1,
      "desires": ["recognition"],
      "fears": ["being_forgotten"],
      "disposition": "restless"
    }
  }
}
```

**Separate file rationale:** Soul data has different authoring cadence from backstories and different structure (structured numeric traits vs prose paragraphs). Separate files allow independent editing, review, and hot-reload. The fallback chain (npc_override > role_default > empty) mirrors the existing global context fallback.

#### Quest Hints (in ChatRequest)

```json
{
  "quest_hints": [
    "You are concerned about gnoll raids from Blackburrow to the north.",
    "You offer a quest: bring you 4 gnoll fangs as proof of kills.",
    "Valid keywords the player can ask about: [gnolls], [Blackburrow], [gnoll fangs]."
  ],
  "quest_state": "Player has not yet accepted the quest."
}
```

Quest hints live in the quest script itself (co-located with the quest logic), not in a config file. This is a deliberate design choice: the content author editing a quest script should be able to define the hints right next to the keywords they describe.

### Code Changes

#### Python Sidecar Changes

**`models.py`** — Add optional fields to ChatRequest:
```python
class ChatRequest(BaseModel):
    # ... existing fields ...
    quest_hints: list[str] | None = None     # Tier 2: hint sentences for quest guidance
    quest_state: str | None = None           # Tier 2: current quest progress descriptor
```

**`context_providers.py`** — Add SoulElementProvider class:
```python
class SoulElementProvider:
    """Loads and serves soul element data for NPC personality.
    
    Fallback chain:
    1. npc_overrides[npc_type_id]  -- specific NPC soul
    2. role_defaults[detected_role] -- role-based defaults (guard, merchant, etc.)
    3. ""                           -- no soul elements (majority of NPCs)
    """
    
    def __init__(self, config_path=None):
        # Load from SOUL_ELEMENTS_PATH env var or default
        
    def get_soul(self, npc_type_id, npc_name, npc_class, is_merchant) -> dict | None:
        # Check npc_overrides first, then detect role and use role_defaults
        
    def detect_role(self, npc_name, npc_class, is_merchant) -> str | None:
        # Merchant: is_merchant flag or class == 41
        # Guard: name contains "Guard", "Captain", "Lieutenant", "Trooper", "Legionnaire"
        # Guildmaster: name contains "Guildmaster" or class-based detection
        # Priest: class in (2, 6, 10) — Cleric, Druid, Shaman
        
    def format_soul_text(self, soul: dict, npc_deity: int) -> str:
        # Convert structured soul data to natural language prompt text
        # Include deity name lookup for deity-aligned language
```

**Role detection strategy:** Use NPC name pattern matching rather than database queries. This is reliable because EQ NPC naming is highly conventional:
- Guards: "Guard_*", "Captain_*", "Lieutenant_*", "Trooper_*", "Legionnaire_*", "*_Guard"
- Merchants: `is_merchant` flag (already passed in context)
- Guildmasters: "Guildmaster_*" or detected via class trainer patterns
- Priests/Clerics: NPC class in {2, 6, 10}

Name patterns are checked case-insensitively against the clean NPC name.

**`prompt_assembler.py`** — Populate Layer 6 and add quest hint injection:

```python
# --- Layer 5.5: Quest hints (Tier 2 only) ---
if req.quest_hints:
    hint_text = self._build_quest_hint_block(req.quest_hints, req.quest_state)
    if hint_text:
        truncated_hints = self._truncate_to_budget(hint_text, self.budget_quest_hints)
        if truncated_hints:
            lines.append(truncated_hints)
            lines.append("")

# --- Layer 6: Soul elements ---
if self.soul_provider and self.budget_soul > 0:
    soul = self.soul_provider.get_soul(
        npc_type_id=req.npc_type_id,
        npc_name=req.npc_name,
        npc_class=req.npc_class,
        is_merchant=req.npc_is_merchant,
    )
    if soul:
        soul_text = self.soul_provider.format_soul_text(soul, req.npc_deity)
        truncated_soul = self._truncate_to_budget(soul_text, self.budget_soul)
        if truncated_soul:
            lines.append(truncated_soul)
            lines.append("")
```

Quest hint block format:
```
This person has specific concerns. Here is what you know:
- [hint 1]
- [hint 2]
When responding, try to naturally guide conversation toward these topics.
Include at least one keyword in [brackets] so they can ask about it directly.
Current situation: [quest_state if provided]
```

**`main.py`** — Add config reload endpoint and soul provider initialization:
```python
@app.post("/v1/config/reload")
async def reload_config():
    """Hot-reload all config files without container restart."""
    global _assembler
    global_provider = GlobalContextProvider()
    local_provider = LocalContextProvider()
    soul_provider = SoulElementProvider()
    _assembler = PromptAssembler(
        llm=_llm,
        global_provider=global_provider,
        local_provider=local_provider,
        soul_provider=soul_provider,
    )
    return {"status": "reloaded"}
```

#### Lua Script Changes

**`llm_bridge.lua`** — Add Tier 2 support:

```lua
-- Build context for Tier 2 (scripted) NPCs with quest hints.
-- Adds quest_hints and quest_state to the standard context.
function llm_bridge.build_quest_context(e, quest_hints, quest_state)
    local context = llm_bridge.build_context(e)
    context.quest_hints = quest_hints
    context.quest_state = quest_state
    return context
end
```

Also modify `build_context()` to populate `npc_deity`:
```lua
function llm_bridge.build_context(e)
    -- ... existing fields ...
    return {
        -- ... existing ...
        npc_deity = e.self:GetDeity(),  -- ADD THIS LINE
        -- ... rest ...
    }
end
```

And add `npc_deity` to the `generate_response()` request body construction.

**Quest Script Tier 2 Pattern** (example: `Captain_Tillin.lua`):

```lua
local llm_bridge = require("llm_bridge")

local quest_hints = {
    "You are concerned about gnoll raids from Blackburrow to the north.",
    "You have a task: bring 4 gnoll fangs as proof of kills.",
    "Valid keywords: [gnolls], [Blackburrow], [gnoll fangs].",
}

function event_say(e)
    if e.message:findi("hail") then
        e.self:Say("Greetings, citizen. The watch stands vigilant...")
        return
    end
    
    if e.message:findi("gnolls") then
        e.self:Say("The gnolls of Blackburrow grow bolder...")
        return
    end
    
    -- No keyword matched -> LLM fallback with quest hints
    llm_bridge.send_thinking_indicator(e)
    local context = llm_bridge.build_quest_context(e, quest_hints)
    local response = llm_bridge.generate_response(context, e.message)
    if response then
        e.self:Say(response)
    end
end
```

**Key design notes for Tier 2 scripts:**
- `quest_hints` is defined as a local at the top of the script file, co-located with the quest logic
- The LLM fallback is the **last** block in `event_say()`, after all keyword checks
- `quest_state` can be dynamically constructed if the quest tracks state (via data buckets or globals)
- The `is_eligible()` check is NOT used for Tier 2 — the quest script explicitly opts in to LLM fallback

#### Configuration Changes

**`docker-compose.npc-llm.yml`** — Update env vars:
```yaml
- LLM_BUDGET_SOUL=${LLM_BUDGET_SOUL:-150}        # Was 0, now 150
- SOUL_ELEMENTS_PATH=${SOUL_ELEMENTS_PATH:-/config/soul_elements.json}
- LLM_BUDGET_QUEST_HINTS=${LLM_BUDGET_QUEST_HINTS:-150}
```

**No rule value changes needed.** `Chat:AutoInjectSaylinksToSay` already defaults to `true`, which handles [bracketed keyword] conversion to saylinks automatically.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Create `soul_elements.json` config with role defaults and empty npc_overrides structure; create `SoulElementProvider` class in `context_providers.py` with role detection logic and soul text formatting | sidecar-expert | — | Medium |
| 2 | Extend `ChatRequest` model with `quest_hints` and `quest_state` fields; add quest hint injection block to `prompt_assembler.py` between Layer 5 and Layer 6; populate Layer 6 with soul element text; add `self.budget_quest_hints = int(os.environ.get("LLM_BUDGET_QUEST_HINTS", "150"))` to `PromptAssembler.__init__()`; wire `SoulElementProvider` into assembler | sidecar-expert | 1 | Medium |
| 3 | Add `/v1/config/reload` endpoint to `main.py`; update `_init_assembler()` to initialize `SoulElementProvider`; update `docker-compose.npc-llm.yml` with new env vars (`LLM_BUDGET_SOUL=150`, `SOUL_ELEMENTS_PATH`, `LLM_BUDGET_QUEST_HINTS=150`) and Phase 3 comment header; update `akk-stack/.env` with all missing Phase 2.5 vars and 3 new Phase 3 vars (see config-expert review action items below) | sidecar-expert | 2 | Small |
| 4 | Extend `llm_bridge.lua`: add `npc_deity` to `build_context()`; add `build_quest_context()` function; add `npc_deity` to `generate_response()` request body | lua-expert | — | Small |
| 5 | Create Tier 2 quest script pattern: upgrade 20-30 quest scripts across starting cities with LLM fallback blocks and quest_hints definitions. Priority: Qeynos (5-10 scripts), then 2-3 per remaining starting city | lua-expert | 4 | Large |
| 6 | Author 80-110 NPC backstory overrides for `global_contexts.json` covering guildmasters, city leaders, and key NPCs across all 15 starting cities. Entries must follow the existing backstory format and be lore-accurate | content-author | — | Large (content) |
| 7 | Author soul element data for Tier A/B NPCs (30-50 entries) in `soul_elements.json` npc_overrides section. Must satisfy deity alignment rules and faction political constraints from PRD | content-author | 1, 6 | Large (content) |

**Dependency notes:**
- Tasks 1-3 (sidecar) and Task 4 (Lua bridge) can proceed in parallel
- Task 5 (quest scripts) depends on Task 4 (Lua bridge extension)
- Task 6 (backstory content) has no code dependencies — can start immediately
- Task 7 (soul element content) needs the config structure from Task 1

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| LLM generates [brackets] that don't match valid keywords | Medium | Low | Quest hint instruction tells LLM which keywords are valid. Post-processor doesn't filter brackets. Worst case: player clicks a saylink that doesn't match any keyword, which triggers the LLM fallback again — this is harmless. |
| Soul element text exceeds token budget | Low | Low | `_truncate_to_budget()` already handles truncation at sentence boundaries. Budget set to 150 tokens (~600 chars), which fits 3-5 personality sentences comfortably. |
| NPC deity lookup returns 0 for NPCs without deity | Low | None | `format_soul_text()` skips deity language when deity is 0. The `npc_types.deity` field is 0 for most NPCs, which is the correct default. |
| Role detection false positives (e.g., "Guardon" matched as guard) | Low | Low | Use word-boundary matching in the name pattern. False positives only add mild default personality (Courage +1), which is harmless. |
| Hot-reload endpoint doesn't re-initialize properly | Low | Medium | The reload endpoint re-creates all providers from scratch. If any config file has a JSON parse error, the old providers remain active (no crash). Add error reporting to response body. |

### Compatibility Risks

- **Tier 1 regression**: No changes to the Tier 1 code path. `global_npc.lua:event_say()` is unchanged. The `build_context()` change (adding `npc_deity`) is additive — the sidecar already accepts it as an optional field with default 0.
- **Quest script regression**: Tier 2 fallback is the last block in event_say, after all keyword checks. If no keyword matches AND the LLM call fails, the NPC stays silent — same as current behavior.
- **AutoInjectSaylinksToSay**: This rule converts [text] to saylinks in NPC Say() calls. It works on the server side before the packet is sent to the client. LLM-generated text passes through `e.self:Say()` identically to scripted text — no compatibility concern.

### Performance Risks

- **Token budget growth**: With soul elements (150) + quest hints (150), the total prompt grows by ~300 tokens. Combined with existing layers (identity 50 + global 200 + local 150 + role 30 + faction ~50 + memory 200 + rules ~150), total is ~980 tokens. With `LLM_N_CTX=2048` and `LLM_BUDGET_RESPONSE=500`, this fits with margin (~570 tokens headroom).
- **Config file size**: `global_contexts.json` grows from ~12KB to ~40KB with 80-110 overrides. `soul_elements.json` will be ~15KB. Both are loaded once at startup and held in memory — negligible impact.
- **Tier 2 latency**: Same as Tier 1 — one blocking curl call to the sidecar (~1-3 seconds). The quest script already pauses for the LLM response. No additional latency from quest hints or soul elements (they're injected into the prompt, not separate calls).

## Review Passes

### Pass 1: Feasibility

**Can we build this with the existing codebase?**

Yes. Every required extension point already exists:

1. **`npc_deity`** field exists in `ChatRequest` (models.py:11, default 0) — just needs population from Lua
2. **`GetDeity()`** exists on `Lua_Mob` (lua_mob.h:107) — Lua scripts can call `e.self:GetDeity()`
3. **Layer 6** is explicitly reserved as a placeholder (prompt_assembler.py:157-158) with `LLM_BUDGET_SOUL` env var already defined
4. **`AutoInjectSaylinksToSay`** defaults to true (ruletypes.h:930) — [brackets] in Say() automatically become clickable saylinks
5. **ChatRequest** accepts additional optional fields via Pydantic model extension
6. **GlobalContextProvider** already has the `npc_overrides` lookup pattern — expanding it is pure data work
7. **`generate_response()`** in llm_bridge.lua constructs a request table from context — adding new fields is straightforward

**Hardest part:** Content authoring. Writing 80-110 lore-accurate backstories and 30-50 soul element assignments requires significant lore expertise and manual effort. The technical implementation is straightforward.

**Advisor consultation:**
- Protocol-agent: Confirmed no protocol changes needed. Say-link injection works automatically with Titanium client.
- Config-expert: Confirmed no existing rules govern fallback dialogue. LLM_BUDGET_SOUL change from 0 to 150 is correct. Separate soul_elements.json file recommended.

### Pass 2: Simplicity

**Is this the simplest approach?**

Evaluated alternatives:

1. **Could soul elements live in global_contexts.json?** Yes, but it would mix prose backstories with structured numeric data in one file. Separate files allow independent authoring, review, and reload. The added complexity of a second config file is justified by cleaner separation of concerns.

2. **Could quest hints be stored in a config file instead of in the quest script?** Yes, but co-location with the quest logic is better for maintainability. The person editing quest keywords should edit quest hints at the same time, in the same file.

3. **Could we use a file-watcher instead of a reload endpoint?** Yes, but file-watching adds a dependency (watchdog library) and creates subtle timing issues. A POST endpoint is explicit, testable, and dependency-free.

4. **Could role detection use database queries instead of name patterns?** Yes, but it would require the sidecar to have database access (currently it has none). Name patterns are 95%+ accurate for conventional EQ NPC names and add zero infrastructure complexity.

5. **Do we need a separate budget for quest hints?** We could share the soul budget, but quest hints and soul elements have different truncation priorities (quest hints should be truncated before soul elements if both are present). Separate budgets give content authors more control.

**Nothing deferred.** All three PRD deliverables are implementable as described. No scope reduction needed.

### Pass 3: Antagonistic

**What could go wrong?**

1. **LLM generates invalid keywords in brackets.** If the LLM puts [made-up term] in brackets, the saylink system creates a clickable link that, when clicked, sends that text to the NPC's event_say. Since it doesn't match any keyword, the LLM fallback fires again, potentially creating a loop. **Mitigation:** The quest hint instruction explicitly lists valid keywords. Additionally, each LLM call is independent (no loop detection needed because the player must click/type each time — not automated). The worst case is the player clicks a bad link, gets another LLM response, and the NPC says something like "Perhaps ask me about [wolves] instead." This is acceptable behavior.

2. **Soul elements override racial/cultural voice.** If soul element text is too dominant, NPCs might sound personality-generic rather than culturally specific. **Mitigation:** The PRD explicitly states soul elements are "within" cultural voice, not replacing it. Layer 2 (global context with racial identity) and Layer 5 (faction instruction) are positioned before Layer 6 in the prompt. The LLM processes them in order, establishing cultural voice before personality nuance is applied. The soul text itself includes a reminder: "Express these traits through your racial and cultural voice."

3. **Config file JSON parse error crashes the sidecar.** **Mitigation:** The existing providers already handle JSON parse errors gracefully (log error, continue with empty data). The soul provider follows the same pattern. The reload endpoint catches parse errors and returns them in the response without crashing.

4. **Quest scripts with many keywords have long quest_hints arrays.** **Mitigation:** The `LLM_BUDGET_QUEST_HINTS` budget caps the injected text. Truncation drops hints from the end, preserving the most important (first-listed) hints. Authors should list keywords in priority order.

5. **Race between config reload and in-flight requests.** The reload endpoint replaces the assembler reference atomically (`_assembler = new_assembler`). Python's GIL ensures the reference swap is atomic. In-flight requests using the old assembler continue to completion with the old config — no corruption possible.

6. **Tier 2 fallback fires on Tier 1 NPCs by accident.** Impossible. Tier 2 is opt-in per quest script — only scripts that explicitly call `build_quest_context()` and `generate_response()` get LLM fallback. The Tier 1 path in `global_npc.lua` is completely separate and unchanged.

### Pass 4: Integration

**How do the pieces fit together?**

End-to-end flow for a Tier 2 quest NPC with backstory + soul + quest hints:

1. Player says "What's going on around here?" to Captain Tillin
2. `Captain_Tillin.lua:event_say()` checks keywords: "hail", "gnolls", etc. — no match
3. Script reaches LLM fallback block
4. `llm_bridge.build_quest_context(e, quest_hints)` builds context including `npc_deity` and `quest_hints`
5. `llm_bridge.generate_response(context, message)` sends POST to sidecar
6. Sidecar's `PromptAssembler.assemble()` builds prompt:
   - Layer 1: "You are Captain Tillin, a level X Human Warrior in South Qeynos..."
   - Layer 2: GlobalContextProvider finds `npc_overrides["1077"]` → Tillin's backstory
   - Layer 3: Local context for qeynos zone
   - Layer 4: Military role framing
   - Layer 5: Faction instruction based on player standing
   - Layer 5.5: Quest hints block with valid keywords
   - Layer 6: Soul elements for NPC 1077 (courage +2, restless disposition)
   - Layer 7: Memory context (if player has prior conversations)
   - Layer 8: Rules block
7. LLM generates response: "The roads north of the city have grown dangerous of late. The [gnolls] of Blackburrow test our defenses daily, and we need capable swords. Perhaps you might ask about the [gnolls] specifically."
8. Post-processor cleans response (truncate, strip quotes, era check)
9. Response returned to Lua via JSON
10. `e.self:Say(response)` sends the text to the client
11. `AutoInjectSaylinksToSay` converts [gnolls] to a clickable saylink
12. Player clicks [gnolls] → fires event_say with message "gnolls" → matches keyword → scripted response

**Task ordering verification:**
- Tasks 1-3 (sidecar) and Task 4 (Lua bridge) have no cross-dependencies — can run in parallel
- Task 5 (quest scripts) needs Task 4's Lua changes first
- Tasks 6-7 (content) can start any time, but soul content (7) needs the config structure from Task 1

**Expert independence verification:**
- sidecar-expert works only in `akk-stack/npc-llm-sidecar/` — no overlap with other experts
- lua-expert works in `akk-stack/server/quests/` — no overlap with sidecar-expert
- content-author works on JSON config files and doesn't touch code

## Open Questions Resolved

| # | Question | Resolution |
|---|----------|------------|
| 1 | Soul element storage format | **Separate `soul_elements.json` file.** Cleaner separation from prose backstories, independent reload, different authoring cadence. Loaded by new `SoulElementProvider` class. |
| 2 | Quest hint injection point | **Layer 5.5 — between faction (L5) and soul (L6).** Quest hints are contextual directives that should be processed after the NPC's attitude is established but before personality traits color the response. Separate token budget (`LLM_BUDGET_QUEST_HINTS=150`). |
| 3 | Say-link generation | **`AutoInjectSaylinksToSay` rule handles it automatically.** Confirmed at ruletypes.h:930, defaults to `true`. No Lua post-processing needed. LLM-generated text with [brackets] in `e.self:Say()` gets saylinks automatically. |
| 4 | Hot-reload mechanism | **POST endpoint at `/v1/config/reload`.** Re-initializes all providers from config files. Explicit, testable, no dependency on file-watching libraries. Returns error details if any config file fails to parse. |
| 5 | Quest state passing | **Script-side construction.** The quest script builds different `quest_hints` arrays based on quest state (data buckets, globals, etc.). This keeps the sidecar simple (it never queries game state) and gives content authors full control over what the NPC "knows" at each quest stage. |
| 6 | NPC deity lookup | **Lua context builder.** Add `npc_deity = e.self:GetDeity()` to `build_context()` in llm_bridge.lua. The method exists on Lua_Mob (lua_mob.h:107), and the `npc_deity` field already exists in ChatRequest (models.py:11, default 0). Zero C++ changes needed. |

### Config-Expert Review (Post-Architecture)

Config-expert reviewed the architecture plan and **APPROVED** with 3 action items incorporated into the implementation tasks above:

**Action Item 1 (CRITICAL — added to Task 3):** Update `akk-stack/.env` with all missing Phase 2.5 vars (`MEMORY_TOP_K`, `MEMORY_SCORE_THRESHOLD`, `MEMORY_MAX_PER_PLAYER`, `MEMORY_TTL_DAYS`, `MEMORY_CLEANUP_INTERVAL_HOURS`, `LLM_DEBUG_PROMPTS`, `LLM_BUDGET_GLOBAL`, `LLM_BUDGET_LOCAL`, `LLM_BUDGET_MEMORY`, `LLM_BUDGET_RESPONSE`, `GLOBAL_CONTEXTS_PATH`, `LOCAL_CONTEXTS_PATH`) plus the 3 new Phase 3 vars (`LLM_BUDGET_SOUL=150`, `LLM_BUDGET_QUEST_HINTS=150`, `SOUL_ELEMENTS_PATH`). Without this, operators have no visible control surface.

**Action Item 2 (MINOR — added to Task 2):** Explicitly add `self.budget_quest_hints = int(os.environ.get("LLM_BUDGET_QUEST_HINTS", "150"))` to `PromptAssembler.__init__()` alongside the existing four budget reads (lines 52-55).

**Action Item 3 (MINOR — added to Task 3):** Update `docker-compose.npc-llm.yml` line 2 comment header to include Phase 3.

**Observations (no action needed):**
- `soul_elements.json` is automatically covered by the existing config volume mount (`./npc-llm-sidecar/config:/config:ro`). No compose volumes changes needed.
- Cabilis NPC naming variants (`a_Legionnaire`, `Legion_Guard`) may not all match guard role detection patterns. Acceptable — key Iksar NPCs get per-NPC overrides from content-author anyway.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| sidecar-expert | 1, 2, 3 | Python/FastAPI changes: SoulElementProvider, prompt assembler Layer 6 + quest hints, ChatRequest model extension, config reload endpoint, docker-compose updates |
| lua-expert | 4, 5 | Lua bridge extension (build_quest_context, npc_deity), Tier 2 quest script upgrades (20-30 scripts with LLM fallback and quest_hints) |
| content-author | 6, 7 | Backstory authoring (80-110 NPC overrides), soul element data for key NPCs (30-50 entries with deity/faction compliance) |

## Validation Plan

### Sidecar Validation
- [ ] `SoulElementProvider` loads `soul_elements.json` at startup without errors
- [ ] Role detection correctly identifies guards, merchants, guildmasters from NPC names
- [ ] `format_soul_text()` produces natural-language personality text from structured data
- [ ] Layer 6 of assembled prompt contains soul element text when soul data exists
- [ ] Layer 6 is empty when no soul data exists for an NPC (no regression)
- [ ] Quest hints appear in assembled prompt between Layer 5 and Layer 6 when present
- [ ] Quest hint text includes instruction to use [bracketed keywords]
- [ ] Token budgets are respected: soul elements truncated at 150 tokens, quest hints at 150 tokens
- [ ] `/v1/config/reload` endpoint re-reads all config files and returns success
- [ ] Config reload with malformed JSON returns error without crashing sidecar
- [ ] `npc_deity` field is accepted in chat requests and passed to soul text formatting

### Lua Bridge Validation
- [ ] `build_context()` now includes `npc_deity` field from `e.self:GetDeity()`
- [ ] `build_quest_context()` returns context with `quest_hints` and optional `quest_state`
- [ ] `generate_response()` includes `quest_hints`, `quest_state`, and `npc_deity` in the request body
- [ ] Tier 1 behavior unchanged: unscripted NPCs still respond via global_npc.lua without quest hints

### Quest Script Validation (Tier 2)
- [ ] At least 20 quest scripts upgraded with LLM fallback blocks
- [ ] Keyword matching still works: saying a valid keyword triggers scripted response (not LLM)
- [ ] Off-keyword speech triggers LLM fallback with quest-appropriate response
- [ ] LLM response includes at least one [bracketed keyword] that becomes a clickable saylink
- [ ] Clicking the saylink sends the keyword text, which matches and triggers scripted dialogue
- [ ] If sidecar is down, off-keyword speech produces silence (same as current Tier 1 failure mode)

### Content Validation
- [ ] At least 50 new NPC backstory overrides in `global_contexts.json`
- [ ] Backstories cover all 15 starting cities
- [ ] Backstories reference correct deities, factions, and city-specific threats
- [ ] Soul elements for key NPCs satisfy deity alignment rules (per PRD table)
- [ ] Soul elements respect faction political constraints (per PRD section)
- [ ] Role-based defaults produce appropriate mild personality for guards, merchants, guildmasters
- [ ] No soul element flattens racial/cultural identity (Iksar sounds different from High Elf with same traits)

### Integration Validation
- [ ] All three features work together: backstoried quest NPC with soul elements responds to off-keyword speech using quest hints, with personality colored by soul elements
- [ ] Token budget total stays within `LLM_N_CTX=2048` for prompts with all layers active
- [ ] No regression in Tier 1 unscripted NPC conversation quality
- [ ] No regression in existing quest script keyword matching

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
>
> **Implementation sequence:**
> 1. Create SoulElementProvider and soul_elements.json config → **sidecar-expert**
> 2. Extend ChatRequest, prompt assembler (L5.5 + L6), docker-compose → **sidecar-expert**
> 3. Add config reload endpoint → **sidecar-expert**
> 4. Extend llm_bridge.lua (npc_deity, build_quest_context) → **lua-expert**
> 5. Upgrade 20-30 quest scripts to Tier 2 → **lua-expert**
> 6. Author 80-110 NPC backstories → **content-author**
> 7. Author soul element data for key NPCs → **content-author**
>
> **Assigned experts:** sidecar-expert, lua-expert, content-author
