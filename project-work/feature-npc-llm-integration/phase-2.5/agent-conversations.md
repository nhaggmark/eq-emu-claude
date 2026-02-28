# NPC LLM Phase 2.5 — Lore Integration + Prompt Pipeline — Agent Conversations Log

> **Feature branch:** `feature/npc-llm-phase2.5`
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

_game-designer + lore-master exchanges during Phase 2.5 design._

### 2026-02-25 — Phase 2.5 Feature Concept and Lore Questions

**From:** game-designer → **To:** lore-master

> Sent overview of Phase 2.5 concept: 4-layer prompt architecture (global context, local context, soul placeholder, memory) to replace thin zone_cultures.json. Asked for lore feedback on:
> - Whether the 4-layer approach captures all dimensions of NPC cultural identity
> - Whether race+class+deity+faction is the right keying for global context
> - Whether INT-gated detail levels (low/medium/high) align with EQ lore on racial intelligence
> - Any era compliance concerns

**Response from** lore-master:

> (Awaiting response)

**Outcome:** Pending lore-master review.

---

### 2026-02-25 — PRD Lore Review Request (4 Sections)

**From:** game-designer → **To:** lore-master

> Sent 4 key PRD sections for lore review:
> 1. Example global context entries (Human/Qeynos Guard, Dark Elf/Neriak Necromancer, Ogre/Oggok Warrior)
> 2. Example scenario dialogues (Qeynos guard, Neriak merchant, Oggok ogre — before/after Phase 2.5)
> 3. INT-gated knowledge examples (low/medium/high INT responses about Blackburrow gnolls)
> 4. Era compliance requirements (deity list, no PoP/Berserker/Discord, Luclin treatment)
>
> Asked lore-master to flag any issues with cultural accuracy, deity references, faction relationships, era compliance, or contradictions with established EQ lore.

**Response from** lore-master:

> (Awaiting response)

**Outcome:** Pending lore-master review. PRD will be finalized after lore-master approval.

---

## Architecture Team Conversations

_architect + config-expert exchanges during Phase 2.5 architecture._

### 2026-02-25 — Config/Rule Feasibility Consultation

**From:** architect → **To:** config-expert

> Sent initial consultation asking about 4 areas:
> 1. **Existing rules:** Are there any entries in `rule_values` or `ruletypes.h` that govern NPC conversation, LLM integration, or prompt construction? (Expected: no — the LLM sidecar is external to EQEmu's rule system.)
> 2. **Docker compose / env var conventions:** Review current `docker-compose.npc-llm.yml` for patterns. Need to add env vars: `LLM_N_CTX=2048`, `LLM_BUDGET_GLOBAL`, `LLM_BUDGET_LOCAL`, `LLM_BUDGET_SOUL`, `LLM_BUDGET_MEMORY`, `LLM_BUDGET_RESPONSE`, `GLOBAL_CONTEXTS_PATH`, `LOCAL_CONTEXTS_PATH`, `LLM_DEBUG_PROMPTS`.
> 3. **Token budget tunables:** Should token budgets be in docker-compose env vars, sidecar config file, or Lua-side config? Architect's recommendation: docker-compose env vars (consistent with existing LLM_N_CTX pattern).
> 4. **Config file paths:** Best practice for mounting new JSON config files into the sidecar container.

**Response from** config-expert:

> (Pending — context compacted before response received. Follow-up sent.)

---

### 2026-02-25 — Config Review Follow-Up

**From:** architect → **To:** config-expert

> Follow-up message confirming key findings from architect's own investigation:
> 1. No existing EQEmu server rules apply to the sidecar (standalone Python service)
> 2. No C++ changes needed — all work is sidecar + Lua + config
> 3. Configuration handled via docker-compose env vars, not EQEmu rule_values
> 4. llm_config.lua handles Lua-side tunables (min_npc_intelligence, sidecar_url, etc.)
> Asked config-expert to confirm no eqemu_config.json settings interact with NPC conversation/LLM systems, and flag any docker-compose/.env conventions for new env vars.

**Response from** config-expert:

> (Awaiting response)

**Outcome:** Architect proceeded with architecture doc based on investigation findings:
- No EQEmu rule_values interaction confirmed (sidecar is external)
- New env vars follow existing pattern (LLM_N_CTX already uses docker-compose env vars)
- Token budgets as env vars with defaults is consistent with current approach
- Config JSON files mounted via existing volumes section in docker-compose
- config-expert assigned Task 8 (docker-compose update) in implementation plan

---

### 2026-02-25 — Protocol Agent Not Required

**From:** architect (internal decision)

> Determined that protocol-agent consultation is not required for Phase 2.5. Rationale:
> - No client-server packet changes — all changes are server-side sidecar + Lua
> - No new opcodes, struct modifications, or Titanium translation changes
> - The Lua bridge communicates with the sidecar via localhost HTTP (curl), not the EQ client protocol
> - The client sees only the final text response via `e.self:Say()`, same as today

**Outcome:** Protocol-agent consultation skipped. No protocol-related risks identified.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### 2026-02-24 — lua-expert plan confirmation to team-lead

**From:** lua-expert → **To:** team-lead

> Confirmed implementation plan ready to execute. Tasks 3, 5, 4, 6, 7 will be implemented in sequence (3+5 in parallel, then 4 depends on 3, then 6 depends on all three, then 7). Task 9 (integration test) blocked on data-expert tasks 1+2 and config-expert task 8.
>
> Key design decisions confirmed from architecture doc:
> - All provider classes handle missing JSON gracefully (empty string fallback)
> - Assembler falls back to legacy build_system_prompt() if init fails
> - Merchant detection via GetClass()==41 in Lua (architecture decision #2)
> - All new ChatRequest fields have defaults for backward compat with old Lua bridges

**Outcome:** Proceeded with implementation. All code tasks (3-7) complete. Committed to feature/npc-llm-phase2.5 branch in akk-stack.

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | NPC deity unavailable — derive religious identity from primary faction | architect | 2026-02-25 | `npc_types` has no deity column. C++ struct has it but marked "not loaded from DB". GetDeity() returns 0 for all NPCs. Solution: bake deity references into faction-keyed global context paragraphs. |
| 2 | Merchant detection via GetClass()==41 not merchant_id | architect | 2026-02-25 | `merchant_id` not exposed in Lua NPC API. Class 41 (GM/Merchant) catches most merchants. Minor accuracy loss for dual-role NPCs is acceptable. |
| 3 | No C++ or database changes needed | architect | 2026-02-25 | All required NPC data (INT, primary faction, gender, class) already accessible via Lua API. Sidecar is standalone Python service outside EQEmu rule system. |
| 4 | Token budgets as docker-compose env vars | architect, config-expert | 2026-02-25 | Follows existing LLM_N_CTX pattern. Allows tuning without code changes or rebuilds. |
| 5 | Protocol-agent consultation not required | architect | 2026-02-25 | No client-server packet changes. All changes are sidecar + Lua, communicating via localhost HTTP. |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| Lore review of PRD sections 1-4 | game-designer, lore-master | Awaiting response | No — PRD was approved per status.md handoff log. Design team conversation log may not have been updated. |
| Config-expert review of Phase 2.5 architecture | architect, config-expert | Awaiting response | No — architect proceeded based on own investigation. Config-expert has Task 8 in implementation plan. |

