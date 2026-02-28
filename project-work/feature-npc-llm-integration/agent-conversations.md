# NPC LLM Integration — Agent Conversations Log

> **Feature branch:** `feature/npc-llm-integration`
> **Created:** 2026-02-23

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

_game-designer + lore-master exchanges during Phase 2 (Design)._

### 2026-02-23 — Early Lore Consultation: NPC LLM Feature Concept

**From:** game-designer → **To:** lore-master

> Sent the feature concept and 5 specific lore questions before writing the PRD:
> 1. Faction-to-behavior mapping: Should hostile NPCs refuse conversation or give threatening one-liners? What's lore-appropriate for a guard at Scowling who hasn't attacked?
> 2. Intelligence filter (INT < 30): Does the threshold feel right for Classic-Luclin? Any named NPCs with artificially low INT who should still talk?
> 3. Era compliance: Specific lore boundaries — should NPCs know about Planes of Power? Vah Shir?
> 4. NPC personality by role: Lore-specific traits for different city factions (Freeport guards vs Qeynos guards vs Kelethin guards)?
> 5. Which NPCs should NOT speak beyond INT filter (constructs, elementals, specific race/class combos)?

**Response from** lore-master:

> Detailed response covering all 5 questions plus 3 additional lore risks. Key findings:
>
> **Faction mapping**: Approved with refinement — Threatening (8) should give a pre-combat warning (city-culture-dependent), while Scowling (9) should refuse all verbal conversation. These are mechanically and narratively distinct. Integration plan's 6-level simplification noted but the PRD already used all 9 levels.
>
> **INT filter**: Approved. Threshold is lore-sound. Ogre/Troll city NPCs have INT 30-60 and should speak in simple/direct cultural speech, not be mute. Named quest mobs with low INT are protected by the dispatch chain (local scripts take priority). Suggested reframing as "non-sentient = mute" not "dumb = mute."
>
> **Era compliance**: Multiple hard stops identified — Planes of Power, Plane of Knowledge hub, Berserker class, Discord references, all post-Luclin content. Luclin itself should be treated as exotic/distant by Norrath NPCs, not a casual travel destination. Vah Shir: Norrath NPCs would know old legends of "Kerrans" but not the name "Vah Shir." Beastlord class is Luclin-era and allowed.
>
> **City personalities**: Detailed personality profiles provided for 8+ cities, sourced from actual quest scripts (Guard_Aerryn.lua, Guard_Bribbely.lua, etc.). Qeynos = civic duty/Rodcet Nife. Freeport = cynical militia/Lucan. Neriak = contempt/Innoruuk. Kelethin = alert brevity/Tunare. Plus Erudin, Oggok, Grobb, Cabilis, others.
>
> **Lore-mute NPCs**: Beyond INT filter — golems (magical automata), elementals (bound constructs), basic constructs. Intelligent undead (wights, spectres, liches) SHOULD speak. Classic-era Frogloks are hostile/feral (NOT friendly redeemed characterization from later era). Gnolls/Kobolds: wild = mute, city-adjacent = broken Common.
>
> **Additional risks flagged**:
> 1. Modern concept bleed: "mental health" → "malady of the mind," "economy" → "trade of goods," "democracy" → councils/kings, "technology" → "artifice/craft." System prompt must explicitly forbid with in-world equivalents.
> 2. Deity reference errors: NPCs must reference correct patron deity per city. Qeynos = Rodcet Nife/Karana, Freeport = varied, Neriak = Innoruuk, etc.
> 3. Post-Luclin framing of Luclin: NPCs on Norrath treat moon travel as strange and unsettling, not routine.
>
> **No lore blockers** — approved to proceed with revisions incorporated.

**Outcome:** All 5 original questions answered. 10 specific revisions incorporated into the PRD:
1. Threatening vs Scowling distinction (verbal warning vs hostile emote only)
2. INT filter reframed as sentience check
3. Lore-mute creature categories added (golems, elementals, constructs)
4. Creature speech notes (Frogloks, Gnolls, intelligent undead)
5. Era hard stops expanded with specific examples
6. Luclin knowledge asymmetry section added
7. Zone Cultural Context table (15 cities with culture, deity, threats)
8. Deity awareness as response characteristic
9. Forbidden modern concepts table
10. Acceptance criteria expanded from 11 to 15

---

### 2026-02-23 — PRD Sections Review Request

**From:** game-designer → **To:** lore-master

> Sent the 5 lore-relevant PRD sections for review before finalizing:
> 1. Faction-to-behavior mapping (all 9 levels)
> 2. Example NPC dialogues (Qeynos guard, Neriak guard, Commonlands merchant)
> 3. Era compliance boundaries (allowed/forbidden content)
> 4. Intelligence filter design (INT < 30 threshold)
> 5. No quest fabrication rule
>
> Asked specific question about whether Norrath NPCs should talk about Luclin casually or treat it as exotic.

**Response from** lore-master:

> (Covered in the comprehensive response above — both messages were answered together in the lore-master's detailed analysis.)

**Outcome:** All sections reviewed. Feedback incorporated as described above.

---

### 2026-02-23 — Final PRD Review Request

**From:** game-designer → **To:** lore-master

> Sent summary of all 10 revisions incorporated from the lore review. Requested final sign-off on the complete PRD at `/mnt/d/Dev/EQ/claude/project-work/feature-npc-llm-integration/game-designer/prd.md`.

**Response from** lore-master:

> Lore review task (#2) marked as completed. No further objections raised.

**Outcome:** Lore sign-off recorded. PRD finalized with all lore revisions incorporated.

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Threatening (8) gives verbal warning; Scowling (9) gives only hostile emote — no verbal response | game-designer, lore-master | 2026-02-23 | Lore-master identified these as mechanically and narratively distinct faction levels |
| 2 | INT filter is a sentience check, not intelligence commentary | game-designer, lore-master | 2026-02-23 | Prevents generating offensive dialogue about "dumb" NPCs |
| 3 | Golems, elementals, and basic constructs are lore-mute regardless of INT | game-designer, lore-master | 2026-02-23 | Magical automata follow orders but don't converse |
| 4 | Classic-era Frogloks are hostile/feral — NOT friendly redeemed characterization | game-designer, lore-master | 2026-02-23 | Legacy of Ykesha redeemed Frogloks are post-era |
| 5 | Luclin is exotic/distant for Norrath NPCs — not a casual travel destination | game-designer, lore-master | 2026-02-23 | Knowledge asymmetry: Norrath NPCs know "Kerran" legends but not "Vah Shir" details |
| 6 | Zone Cultural Context table added with 15 cities | game-designer, lore-master | 2026-02-23 | City-specific culture, patron deity, and key threats dramatically improve NPC authenticity |
| 7 | Modern concepts explicitly forbidden with in-world equivalents | game-designer, lore-master | 2026-02-23 | "Technology" → "artifice," "economy" → "trade of goods," etc. |
| 8 | Deity awareness required per city | game-designer, lore-master | 2026-02-23 | Qeynos = Rodcet Nife, Neriak = Innoruuk, Oggok = Rallos Zek, etc. |
| 9 | All Phase 1 config via llm_config.lua, not ruletypes.h | architect, config-expert | 2026-02-23 | No C++ changes means no rule categories; Lua config is hot-reloadable |
| 10 | Typing indicator via e.other:Message(10), not Emote() | architect | 2026-02-23 | Emote() broadcasts to all; Message() sends to single client (speaker-only) |
| 11 | Zone culture as static JSON in sidecar config dir | architect | 2026-02-23 | Data is static, loaded once at startup, no per-request overhead |
| 12 | 11 body types excluded; Undead/Dragon/Monster NOT excluded | architect, lore-master | 2026-02-23 | Sentient creatures in those categories should speak; INT filter handles the rest |
| 13 | Sidecar is model-agnostic; RAM constraint managed by model swapping | architect, infra-expert | 2026-02-23 | Host has ~8GB RAM; Q4_K_M needs 4-6GB; can swap to smaller model without code changes |
| 14 | Strip [square brackets] from LLM output (saylink prevention) | architect, config-expert | 2026-02-23 | Chat:AutoInjectSaylinksToSay = true; brackets in LLM text would create clickable saylinks |

---

## Architecture Team Conversations

_infra-expert + config-expert + architect exchanges during Phase 3 (Architecture)._

### 2026-02-23 — infra-expert Docker deployment design sent to architect

**From:** infra-expert → **To:** architect

> Completed Docker deployment design for the LLM sidecar (Task #3). Summary sent to architect
> for inclusion in the Phase 1 architecture document:
>
> - Compose overlay: `docker-compose.npc-llm.yml` (third overlay, alongside base + dev)
> - Service name: `npc-llm` (Docker DNS: `http://npc-llm:8100` from eqemu-server container)
> - Network: `backend` (same network as eqemu-server; external name `akk-stack_backend`)
> - Memory limit: `deploy.resources.limits.memory: 8g`
> - Healthcheck: `GET /v1/health` with `start_period: 90s` for model load time
> - Restart policy: `unless-stopped`
> - Volumes: `./npc-llm-sidecar/models:/models:ro`, `./npc-llm-sidecar/config:/config:ro`, logs
> - No external port binding — internal only
> - GPU passthrough commented out (future Phase 3, requires nvidia-container-toolkit)
> - Phase 1 is stateless: Pinecone env vars commented out, ready for Phase 2
>
> Key correction from integration plan: plan said `akk-stack_default` — actual network is
> `backend` in compose (external: `akk-stack_backend`). Lua bridge should use `http://npc-llm:8100`.
>
> Questions for architect:
> 1. Confirm `npc-llm` as service name (must match Lua bridge `sidecar_url`)
> 2. Confirm compose overlay approach is acceptable (vs inline addition to base compose)
> 3. Is `curl` available inside eqemu-server container? (Affects Lua `io.popen` curl invocation)

**Response from architect (2026-02-23):**

> Architect sent 7 specific questions before writing the architecture doc: compose file strategy,
> base image choice, model file management, networking/port, curl availability in eqemu-server,
> resource limits, and health check configuration.

**infra-expert response to architect (2026-02-23) — all questions answered with live verification:**

> 1. **Compose strategy**: Separate `docker-compose.npc-llm.yml` overlay (keeps feature opt-in, consistent with dev overlay pattern)
> 2. **Base image**: Custom Dockerfile from `python:3.11-slim` — avoids 3-5GB pre-built llama-cpp-python images, consistent with existing akk-stack container build pattern
> 3. **Model file**: `./npc-llm-sidecar/models/` on host (D:\Dev\EQ\akk-stack\npc-llm-sidecar\models\), mounted `:ro`; *.gguf gitignored; downloaded separately via wget
> 4. **Networking**: Docker DNS resolves service name `npc-llm` within `backend` network; Lua uses `http://npc-llm:8100`; no external port binding needed
> 5. **curl in eqemu-server**: CONFIRMED `/usr/bin/curl` (v7.88.1, Debian bookworm) — Lua `io.popen`/curl approach valid, no changes to eqemu-server container needed
> 6. **Resource limits**: `deploy.resources.limits.memory: 8g`; no CPU constraint needed. CRITICAL: host has only ~8GB total RAM (~4.3GB free). Mistral 7B Q4_K_M needs ~4-6GB. This is the entire host budget. Recommend architect explicitly address: either require 16GB host, or use smaller model (Q2_K ~2.5GB, or Phi-2 ~1.7GB).
> 7. **Health check**: `CMD curl -sf http://localhost:8100/v1/health`, `interval: 30s`, `timeout: 10s`, `retries: 3`, `start_period: 90s` (model load is slow — critical to avoid restart loop)

**Outcome:** All 7 questions answered. Design is fully specified. RAM constraint is the one unresolved
risk — architect decides model size recommendation vs hardware requirement.

**Architect confirmation (2026-02-23):**

> 1. `npc-llm` service name: CONFIRMED. Matches `llm_config.lua` sidecar_url.
> 2. Compose overlay approach: CONFIRMED. `docker-compose.npc-llm.yml` as third overlay is correct.
> 3. curl: CONFIRMED. Final sanity check will be done in Task 6 (implementation phase).
> 4. RAM constraint: Architecture doc documents Q4_K_M as baseline with explicit RAM risk note.
>    Sidecar is model-agnostic — swap GGUF file + .env to use Q2_K or Phi-2 if needed. No code changes.
> 5. infra-expert implementation tasks in next phase: Task 5 (Docker deployment files), Task 6 (curl verification).

**Final outcome:** Design fully confirmed. Stage 3 complete. All infra decisions locked for implementation phase.

---

### 2026-02-23 — config-expert rules and config assessment sent to architect

**From:** config-expert → **To:** architect

> Completed Task #2 rules and config assessment. Key findings for architecture doc:
>
> **No rule changes needed for Phase 1.** Store LLM parameters in `llm_config.lua`
> (hot-reloadable Lua), not rule_values (adding a new C++ rule category requires rebuild).
>
> **Critical discrepancy:** PRD appendix cites `Range:Say` as "200 units default."
> This server's actual DB override value is **135 units** (code default is 15; our DB
> overrides to 135). Architecture doc should use 135, not 200.
>
> **Chat rules — confirmed no changes needed:**
> - `Chat:AutoInjectSaylinksToSay` = true: LLM response post-processing MUST strip
>   `[square brackets]` from output — otherwise any brackets in LLM text become
>   clickable saylinks, which is wrong for Phase 1.
> - `Chat:QuestDialogueUsesDialogueWindow` = false: Correct. LLM responses go through
>   standard chat channel via `e.self:Say()`. Leave at false.
>
> **Data buckets — confirmed correct API:**
> - `eq.get_data("llm_enabled-" .. npc_type_id)` is the correct opt-out key pattern.
> - Empty string = LLM on (default). "0" = disabled.
> - C++ source confirmed: simple string key, no auto NPC ID scoping.
> - No quest_globals (character-scoped, legacy) — data_buckets is correct.
>
> **eqemu_config.json — no changes needed:**
> - Quest `hotReload: true` means Lua module changes don't require server restart.
> - No sidecar config section needed (Lua handles it).
>
> **Phase 3 deferred (C++ required):** LLM:Enabled, LLM:MinNPCIntelligence,
> LLM:SidecarURL, LLM:TimeoutSeconds, LLM:HostileCooldownSeconds, LLM:MaxResponseLength
> rules in ruletypes.h. Until then, llm_config.lua handles all these.

**Response from architect (2026-02-23):**

> Architecture document complete. All findings incorporated:
> 1. No rule changes for Phase 1 — confirmed. All config via llm_config.lua (hot-reloadable via #reloadquest). Phase 3 migration to ruletypes.h if needed.
> 2. Range:Say = 135 — acknowledged. LLM feature doesn't gate on this value (Say channel routing handles it), but referenced in arch doc.
> 3. Chat:AutoInjectSaylinksToSay = true — CRITICAL finding incorporated. Python sidecar post_processor.py will strip [square brackets] from LLM output. Added to validation plan.
> 4. Data buckets API confirmed — eq.get_data("llm_enabled-" .. npc_type_id), empty = enabled, "0" = disabled.
> 5. eqemu_config.json no changes — confirmed, hotReload=true already set.
> No Phase 1 implementation tasks assigned to config-expert — role was advisory.

**Outcome:** All findings incorporated into architecture document. Config-expert advisory role for Phase 1 complete. Range:Say discrepancy resolved.

---

## Implementation Team Conversations

_infra-expert, lua-expert, python-dev exchanges during Phase 4 (Implementation)._

### 2026-02-23 — lua-expert: Tasks #3 and #4 complete

**Tasks completed:** #3 (Lua modules), #4 (global_npc.lua modification)

**Files created/modified:**

| File | Action |
|------|--------|
| `akk-stack/server/quests/lua_modules/llm_config.lua` | Created — all tunable LLM config values |
| `akk-stack/server/quests/lua_modules/llm_faction.lua` | Created — 9-level EQ faction → tone/instruction mapping |
| `akk-stack/server/quests/lua_modules/llm_bridge.lua` | Created — core LLM bridge: eligibility, context, HTTP call |
| `akk-stack/server/quests/global/global_npc.lua` | Modified — added event_say handler; event_spawn preserved exactly |

**API verification findings:**
- `json.encode()` / `json.decode()`: confirmed JSON4Lua v1.2.1 API (not json.stringify)
- `Client:GetFaction(npc)`: confirmed in client_ext.lua line 64 — method on Client object, wraps 7-param GetFactionLevel. Call as `e.other:GetFaction(e.self)`.
- `e.other:Message(type, text)`: confirmed speaker-only delivery per architecture doc
- `io.popen(cmd)`: available in LuaJIT, blocking — typing indicator fires before call
- `os.time()`: standard Lua 5.1, returns POSIX integer timestamp
- `e.self:GetEntityVariable(key)`: returns `""` (empty string) when not set — checked with `~= ""`
- Shell escaping: single quotes escaped via `gsub("'", "'\\''")`
- `json.null` sentinel: checked in generate_response return (`decoded.response == json.null`)

**Note on git:** `akk-stack/server/` is gitignored (runtime data directory). Lua scripts are deployed as files, not tracked in git. Files are live on disk at the paths above and will be picked up by `#reloadquest`.

---

### 2026-02-23 — infra-expert: Tasks #5 and #6 complete

**Tasks completed:** #5 (Docker deployment files), #6 (curl verification)

**Files created/modified:**

| File | Action |
|------|--------|
| `akk-stack/docker-compose.npc-llm.yml` | Created — Compose overlay with npc-llm service |
| `akk-stack/npc-llm-sidecar/.gitignore` | Extended — added *.bin, *.safetensors, !models/.gitkeep |
| `akk-stack/npc-llm-sidecar/config/.gitkeep` | Created |
| `akk-stack/.env` | Modified — added LLM_MODEL_PATH, LLM_PORT, LLM_MAX_TOKENS, LLM_TEMPERATURE |
| `akk-stack/Makefile` | Modified — added up-llm, down-llm, build-llm targets |

**Note:** python-dev agent created Dockerfile, requirements.txt, app/ Python files, and models/.gitkeep before infra-expert ran. The Dockerfile uses `app.main:app` entry point (correct for the subdirectory layout). No conflicts.

**Compose validation:** `docker compose config` confirmed npc-llm service resolves with 8GB memory limit, healthcheck curl -sf, 90s start_period, read-only volumes, backend network, no external ports.

**Task #6 — curl verification:**
- `docker exec akk-stack-eqemu-server-1 which curl` → `/usr/bin/curl`
- `curl --version` → `curl 7.88.1 (Debian bookworm, OpenSSL 3.0.15)`
- Supports HTTP/HTTPS. CONFIRMED — no workaround needed. Lua `io.popen`/curl approach is valid.

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| Golem/elemental body type IDs for exclusion list | game-designer, architect (future) | Open — deferred to architect | No — listed in Open Questions |
| Zone cultural context delivery mechanism (JSON config vs Lua table vs request metadata) | game-designer, architect (future) | Open — deferred to architect | No — listed in Open Questions |
| Host RAM constraint: 8GB total; Q4_K_M needs 4-6GB | infra-expert, architect | FLAGGED — architect must decide model size vs hardware req | Yes — affects which model variant is recommended |
| Range:Say PRD discrepancy (PRD says 200, server is 135) | config-expert, architect | RESOLVED — architect confirmed 135, incorporated into arch doc | No |
