# NPC Conversation Memory (Pinecone Integration) — Agent Conversations Log

> **Feature branch:** `feature/npc-llm-integration`
> **Created:** 2026-02-24

This file preserves cross-agent communication for context durability. When
context windows compact, this log ensures decisions, coordination, and
rationale are never lost.

**Every agent on a team MUST log their SendMessage exchanges here.**

**Rules:**
1. Log ALL exchanges, including "no concerns" / "no constraints" responses
2. Log the date, sender, recipient, content summary, and outcome
3. An empty section for a team phase means the team process was skipped
4. "APPROVED — no issues" is a valid and valuable finding; it must be logged
5. This file is the audit trail that proves peer review actually happened

---

## Design Team Conversations

_game-designer + lore-master exchanges during Phase 2._

### 2026-02-24 — Early Lore Concept Review

**From:** game-designer → **To:** lore-master

> Sent initial Phase 2 concept for early feedback. Key questions:
> 1. Memory scope by NPC type — should all sentient NPCs remember equally?
> 2. Memory and faction changes — is "I remember when you were not welcome" lore-appropriate?
> 3. Cross-character memory — memories per character ID, not account (lore-consistent?)
> 4. Memory of notable events — NPCs proactively referencing past conversations
> 5. Luclin-era NPCs — Vah Shir cultural framework for remembering outsiders
> 6. Era compliance with stored memory content

**Response from** lore-master:

> (Answered as part of formal PRD review below — early concept questions folded into full review.)

**Outcome:** Folded into formal review.

### 2026-02-24 — Formal PRD Lore Review

**From:** game-designer → **To:** lore-master

> Sent complete PRD for formal lore review. Highlighted 6 example scenarios,
> faction change acknowledgment mechanic, memory scope/limits, and 5 specific
> lore questions about scenario accuracy, faction acknowledgment plausibility,
> impressionistic memory style, era compliance, and city-culture-specific
> memory behavior.

**Response from** lore-master:

> **Verdict: APPROVED WITH NOTES**
>
> **Approved items:**
> - All 6 example scenarios lore-accurate (Sabertooth gnolls, Befallen, Deathfist orcs, Crushbone, Neriak Scowling, fresh character)
> - Guard Hanlon (Qeynos): Civic-duty tone, Rodcet Nife invocation approved
> - Merchant Talia (Commonlands): Befallen reference, return-visit phrasing approved
> - Guard Brixton (Freeport, faction change): "Best scenario in the PRD" — perfect cynical voice
> - Guard Leafwalker (Kelethin): "This moon" phrasing authentic, Crushbone losses accurate
> - Impressionistic recall approach approved ("characters, not log files")
> - Era compliance: Phase 2 inherits Phase 1 correctly, 90-day TTL invisible to players
> - Per-character memory: Lore-consistent
> - No gameplay advantage: Correct design choice
>
> **Revision requested:** Add Scenario 7 showing memory in a tonally extreme city (Neriak at positive faction). Current scenarios only show warm cities or Freeport cynicism — implementation team might conclude Ally/Amiable always produces warm callbacks, which would be a lore violation for Neriak, Cabilis, Oggok.
>
> **Suggestion (optional):** Add role-memory framing table showing how guards, merchants, scholars, guildmasters, and Iksar NPCs frame memory differently.
>
> **Lore-notes.md:** City-culture tone constraints documented for Neriak, Iksar/Cabilis, Ogre/Troll, Vah Shir.

**Outcome:**
- Scenario 7 (Neriak Foreign Quarter merchant with cold/transactional memory tone) added to PRD
- Role-memory framing table added (9 NPC role/culture combinations with example phrasing)
- Key design constraint documented: "City culture always governs tone, even in memory callbacks"
- PRD header updated: "Approved with notes by lore-master (2026-02-24)"

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 2 Architecture._

### 2026-02-24 — Architect Consultation with protocol-agent

**From:** architect → **To:** protocol-agent

> Sent Phase 2 scope summary for client feasibility review. Key questions:
> 1. Phase 2 is Python sidecar + Lua only — no new opcodes, packet structs, or
>    client-server protocol changes. Confirm no protocol concerns.
> 2. The only Lua-side change is adding `player_id = e.other:CharacterID()` to
>    the context sent via HTTP to the sidecar (curl over io.popen). This is an
>    HTTP payload field, not a client-server packet change.
> 3. No Titanium client interaction — all memory logic is server-side (sidecar)
>    and the client sees only the same `/say` response format as Phase 1.

**Response from** protocol-agent:

> **CONFIRMED — No protocol concerns.** Phase 2 makes zero changes to the
> client-server protocol layer. The Pinecone memory system operates entirely
> within the sidecar (Python process) and the Lua-to-sidecar HTTP bridge.
> The Titanium client is unaware of memory — it receives the same Say packet
> format it always has. No opcodes, packet structs, or translation layer
> changes are needed.

**Outcome:** No protocol constraints for Phase 2. Architecture proceeds without
any client-side considerations.

### 2026-02-24 — Architect Consultation with config-expert

**From:** architect → **To:** config-expert

> Sent Phase 2 scope summary for configuration review. Key questions:
> 1. Are there any existing EQEmu rules (in `ruletypes.h` or `rule_values`)
>    that could be used to control memory behavior without code changes?
> 2. Phase 2 configuration is all sidecar-specific (Pinecone API key, TTL,
>    top-K, score threshold). These are environment variables in Docker compose,
>    not C++ rule values. Confirm this is the correct configuration approach.
> 3. Are there any `eqemu_config.json` settings relevant to the sidecar or
>    NPC conversation system?

**Response from** config-expert:

> **CONFIRMED — No applicable existing rules.** The EQEmu rule system governs
> C++ server runtime behavior — it has no mechanism to reach the Python sidecar.
> Environment variables in Docker compose are the correct configuration
> mechanism for container-level settings like Pinecone API keys, memory TTL,
> retrieval parameters, etc.
>
> No existing rules in `ruletypes.h` govern NPC conversation memory, LLM
> behavior, or external service integration. The Phase 1 NPC LLM system
> already established the pattern of using Docker environment variables for
> sidecar configuration.
>
> `eqemu_config.json` has no NPC LLM or memory-related settings.
>
> **Recommendation:** The proposed environment variable approach
> (`MEMORY_ENABLED`, `MEMORY_TOP_K`, `MEMORY_SCORE_THRESHOLD`,
> `MEMORY_TTL_DAYS`, etc.) follows the correct pattern. All tunables are
> configurable without code changes or container rebuilds (just
> restart the service).

**Outcome:** No existing rules or config settings apply. Docker environment
variables confirmed as the correct approach. Architecture proceeds with
env-var-based configuration for all memory tunables.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

_(Not yet started)_

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | City culture governs tone of memory callbacks, not just content | game-designer, lore-master | 2026-02-24 | Lore-master flagged that warm-city-only scenarios could mislead implementation. Neriak memory callbacks must remain cold/transactional even at positive faction. |
| 2 | Role-memory framing table added to PRD | game-designer, lore-master | 2026-02-24 | Optional suggestion accepted. 9 NPC role/culture combinations documented to guide system prompt construction. |
| 3 | No protocol changes needed for Phase 2 | architect, protocol-agent | 2026-02-24 | Protocol-agent confirmed Phase 2 is entirely sidecar-side. No opcodes, packet structs, or Titanium changes. |
| 4 | Docker env vars are correct config mechanism (no C++ rules apply) | architect, config-expert | 2026-02-24 | Config-expert confirmed no existing rules govern NPC memory. Sidecar config via env vars follows Phase 1 pattern. |
| 5 | Score threshold lowered from 0.7 to 0.4 | architect | 2026-02-24 | all-MiniLM-L6-v2 cosine similarity scores are typically lower than expected. 0.7 would filter most relevant results. 0.4 recommended as starting point, configurable via env var. |
| 6 | Turn summaries for embedding quality | architect | 2026-02-24 | Embedding raw dialogue produces worse retrieval than summarized exchange topics. LLM generates ~20-token summary per turn at negligible cost. |
| 7 | player_id required in Lua bridge (contradicts PRD "no Lua changes") | architect | 2026-02-24 | CharacterID is more reliable than player_name for memory keying. 2-line change is minimal and necessary. PRD contradiction noted and resolved. |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| (none) | | | |
