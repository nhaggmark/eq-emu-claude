# NPC LLM Phase 3: Soul & Story — Agent Conversations Log

> **Feature branch:** `feature/npc-llm-phase3`
> **Created:** 2026-02-25

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

_game-designer + lore-master exchanges during Design phase._

### 2026-02-25 — Early Concept Notification

**From:** game-designer → **To:** lore-master

> Notified lore-master of Phase 3 scope: three deliverables (NPC backstory
> seeding, quest hint system, soul element framework). Listed key lore areas
> needing review: backstory examples, personality traits, recruitment
> disposition model, quest hint examples. Requested lore-master flag any
> conflicts, era violations, or thematic concerns.

**Response from** lore-master:

> Acknowledged. Lore-master began preliminary research.

**Outcome:** Lore-master engaged and aware of scope.

### 2026-02-25 — PRD Draft Lore Review Request

**From:** game-designer → **To:** lore-master

> Sent complete PRD draft for lore review. Posed 6 specific lore questions:
> 1. Is "15 starting cities" count correct for Classic-Luclin?
> 2. Key guildmasters/faction leaders for backstory priority?
> 3. Are the 5 personality axes appropriate for EQ world?
> 4. Are consistency rules reasonable?
> 5. Does NPC recruitment willingness fit EQ world fiction?
> 6. Holly Windstalker — real quest NPC in QHills?

**Response from** lore-master:

> Provided extensive preliminary lore research covering:
> - City-specific guard force identities (Qeynos Guards vs Militia vs Wolves of North, etc.)
> - Warning that Freeport Militia is NOT virtuous — serves corrupt Lucan D'Lere
> - Halas guards use brogue accent ("ye", "o'", "dinnae")
> - Cabilis Legion is xenophobic and rigid
> - Racial personality archetype table (14 races with traits, deities, accents, hostilities)
> - Deity relationship constraints (10 deities with specific behavioral requirements)
> - Era compliance hard constraints (no Froglok Grobb capture, no Crescent Reach, no PoK, no Wayfarer's Brotherhood)
> - Faction political map (6 key conflicts that must be consistent)
> - Real quest script dialogue examples for tone calibration
> - Critical warning: soul system must NEVER flatten racial/cultural identity
> - Guard force identity per city is distinct and faction-specific, not generic

**Outcome:** Major PRD revision required. See next entry.

### 2026-02-25 — PRD Revised Per Lore Feedback

**From:** game-designer → **To:** lore-master

> Revised PRD with 11 specific changes based on lore-master feedback:
> 1. Added Goal 5: "Racial and cultural identity is preserved"
> 2. Added 15-row City-Specific Guard Identity table
> 3. Added Guildmaster Identity section (class + racial culture)
> 4. Added 6th personality axis: Loyalty/Ambition
> 5. Added Deity Alignment Rules table (10 deities, required minimums)
> 6. Added Faction Political Constraints section (6 constraints)
> 7. Hardened Era Compliance with explicit exclusion list
> 8. Added Dialogue Tone Reference with real script examples
> 9. Added Cross-City Contrast player flow section
> 10. Added Open Question 6: NPC deity lookup needed
> 11. Strengthened acceptance criteria (guard identity, deity, anti-flattening)
>
> Posed 3 remaining questions: city count validation, Holly Windstalker
> validity, any remaining lore concerns.

**Response from** lore-master:

> PRD APPROVED with 2 required corrections:
> 1. CRITICAL: Elisi Nasin is a Rogue Guildmaster in East Freeport, NOT a
>    Ranger in West Freeport. Replace with a real Ranger guildmaster.
> 2. MINOR: "Leatherfoot Tales" is not a real NPC/faction name. Use Mayor
>    Gubbin or Leatherfoot Raiders.

**Outcome:** Lore review complete. Two corrections required — see next entry.

### 2026-02-25 — Final Lore Corrections Applied

**From:** game-designer (self-directed, per lore-master feedback)

> Applied 2 corrections to PRD:
> 1. Replaced Elisi Nasin (Rogue GM, East Freeport) with Maesyn Trueshot
>    (Ranger GM, Kelethin). Updated entire combined scenario: player is now
>    a ranger visiting Kelethin, backstory references Greater Faydark and
>    Crushbone orc patrols, dialogue uses Wood Elf nature idiom.
> 2. "Leatherfoot Tales" was already absent from the revised PRD (removed
>    during earlier revision). No change needed.

**Outcome:** Both corrections resolved. PRD finalized with lore-master approval.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Architecture phase._

### 2026-02-25 — Config-expert preparatory research while waiting for architecture plan

**From:** team-lead → **To:** config-expert

> Requested preparatory research while task #2 is blocked on task #1 (architect plan).
> Specific asks: read docker-compose.npc-llm.yml, .env, prompt_assembler.py, and PRD.

**Response from** config-expert (findings logged here):

> Completed preparatory research. Key findings:
> 1. `.env` is missing all Phase 2.5 vars (LLM_BUDGET_*, MEMORY_TOP_K, etc.) — they rely
>    on docker-compose defaults only. Phase 3 should add them with comments.
> 2. `LLM_BUDGET_SOUL` infrastructure already exists (compose + assembler) at value 0.
>    Phase 3 just needs to set it to 100-150.
> 3. `ChatRequest` already has `npc_deity: int = 0` but `prompt_assembler.py` does not
>    use it yet. Soul element implementation can leverage this field.
> 4. No `quest_hints` or `quest_state` fields in `ChatRequest` — need to add both as
>    `Optional` fields with `None` defaults (backward-compatible).
> 5. No hot-reload mechanism exists. Config files load at startup only. Container restart
>    is the current approach to pick up config changes.
> 6. Token budget arithmetic: all layers populated simultaneously = ~1050 tokens system
>    prompt + response, fits within `LLM_N_CTX=2048`. No context window increase needed
>    unless architect identifies additional layers.
> 7. Soul element storage: recommend separate `soul_elements.json` file (cleaner than
>    adding to `global_contexts.json`; different authoring cadence).
>
> Full findings in `config-expert/dev-notes.md` Stage 1 section.

**Outcome:** Config-expert has full picture of existing config/sidecar state.
Ready to review architecture plan immediately upon completion.

### 2026-02-25 — Architect feasibility questions to config-expert

**From:** architect → **To:** config-expert

> Five specific questions:
> 1. Any EQEmu rules governing quest keyword fallback or NPC dialogue beyond AutoInjectSaylinksToSay?
> 2. LLM_BUDGET_SOUL: change to 150 — any other env vars to add/modify?
> 3. Hot-reload approach: reload endpoint vs. file-watch vs. container restart?
> 4. Soul element storage: global_contexts.json vs. separate soul_elements.json?
> 5. New env vars: SOUL_ELEMENTS_PATH — any others needed?

**Response from** config-expert:

> 1. **No rules for quest keyword fallback exist.** Confirmed by reading all Chat and
>    NPC categories in ruletypes.h and querying rule_values DB. Only relevant rule is
>    `Chat:AutoInjectSaylinksToSay=true` (confirmed live in DB). No EQEmu rule governs
>    what happens when EVENT_SAY finds no keyword match. Quest hint fallback is entirely
>    quest-script-side — 100% Lua, zero rule changes needed.
>
> 2. **LLM_BUDGET_SOUL=150 approved — no additional budget vars needed for Phase 3.**
>    Also recommend adding all missing Phase 2.5 vars to .env (currently absent — rely
>    on docker-compose defaults only). Suggest reusing SOUL budget for combined
>    soul+hints region rather than adding a separate LLM_BUDGET_QUEST_HINTS var, unless
>    architect makes quest hints a separate independently-truncated layer.
>
> 3. **Reload endpoint recommended.** File-watch adds a watchdog dependency with no
>    clear advantage. Container restart is 5 seconds (acceptable for content authors).
>    Reload endpoint is cleanest: explicit, no new dependency, testable, and supports
>    future lore-master workflow (edit file, POST /v1/config/reload, done). Simple to
>    implement: re-init GlobalContextProvider, LocalContextProvider, and SoulElementProvider
>    in-place. No container restart required.
>
> 4. **Separate soul_elements.json strongly recommended.** global_contexts.json holds
>    prose strings; soul_elements.json holds structured numeric data. Different authoring
>    cadences. Keeps GlobalContextProvider focused on one concern. SoulElementProvider
>    follows the exact same load pattern. Supports independent reload via the endpoint.
>
> 5. **SOUL_ELEMENTS_PATH is sufficient.** One note: if quest hints and soul elements
>    are separate independently-truncated layers, add LLM_BUDGET_QUEST_HINTS. If they
>    share one layer with a single budget, SOUL budget covers both — no extra var needed.
>    Architect decides the layer structure; either is implementable.

**Outcome:** All five questions answered. No blocking config concerns.
Architect has all information needed to finalize the implementation plan.


### 2026-02-25 — Architect feasibility questions to protocol-agent

**From:** architect → **To:** protocol-agent

> Three specific protocol questions:
> 1. Does AutoInjectSaylinksToSay work correctly with LLM-generated text passed through
>    Lua e.self:Say()? Any Titanium client limits on saylink length/count per message?
> 2. Confirm no C++ packet changes, new opcodes, or struct modifications needed for
>    this feature (entirely sidecar + Lua + config).
> 3. Does the Titanium client have a lower limit on ChannelMessage_Struct for NPC Say
>    messages that could truncate 450-char LLM responses?

**Response from** protocol-agent:

> 1. **AutoInjectSaylinksToSay works correctly.** The rule is processed server-side in
>    the C++ code before the ChannelMessage packet is sent to the client. Any text in
>    e.self:Say() goes through the same processing path — LLM-generated text is
>    indistinguishable from scripted text at the packet level. Titanium saylinks use the
>    `saylink` database table for persistent links. Limit: saylink text up to 256 chars,
>    but individual [keyword] brackets are typically 1-3 words (well under limit).
>    No practical limit on count per message for this use case.
>
> 2. **Confirmed: no protocol changes needed.** This feature is entirely sidecar-side
>    (Python), Lua quest scripts, and JSON configuration files. No new opcodes, no
>    struct modifications, no client-server packet changes. The NPC dialogue flows
>    through existing OP_ChannelMessage/Say infrastructure unchanged.
>
> 3. **No lower limit concern.** ChannelMessage_Struct uses a variable-length message
>    field (message[0] array in the struct definition). The 450-char LLM cap is well
>    within what the Titanium client can display in the chat window. The client's chat
>    window wraps long messages automatically. No truncation risk.

**Outcome:** No protocol constraints. Feature is fully implementable without C++ changes.

### 2026-02-25 — Config-expert reviews completed architecture plan

**From:** architect → **To:** config-expert

> Architecture plan complete. Incorporated config-expert's prior findings:
> separate soul_elements.json, LLM_BUDGET_SOUL=150, reload endpoint, no keyword rules.
> Added LLM_BUDGET_QUEST_HINTS=150 (quest hints as Layer 5.5 with independent budget).
> Requested config-expert review for any remaining concerns.

**Response from** config-expert:

> Plan APPROVED — no blocking concerns. Three action items for sidecar-expert:
>
> 1. CRITICAL GAP: `.env` update is missing from plan scope. Plan specifies
>    docker-compose.npc-llm.yml changes but not `.env`. All Phase 2.5 vars are
>    currently absent from .env (rely on compose defaults only). sidecar-expert
>    Task 3 must also add all missing Phase 2.5 vars + 3 Phase 3 vars to .env.
>
> 2. MINOR GAP: `PromptAssembler.__init__()` must add `self.budget_quest_hints`
>    reading from `LLM_BUDGET_QUEST_HINTS` env var. The plan shows this var used in
>    assembler pseudocode but doesn't explicitly call out the __init__ addition.
>
> 3. MINOR: docker-compose.npc-llm.yml line 2 comment should be updated to
>    include Phase 3.
>
> Additional observations (no action required):
> - soul_elements.json volume mount already in place — no compose volumes change needed
> - Reload endpoint async implementation in plan is correct
> - Token budget arithmetic: ~1050 tokens for full prompt, fits 2048 with ~500 headroom
> - Role detection edge case (Cabilis naming) is acceptable — per-NPC overrides cover key NPCs
>
> Full findings in config-expert/dev-notes.md Stage 2 section.

**Outcome:** Architecture review complete. Three action items delivered to architect
for relay to sidecar-expert. Plan approved.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Implementation phase._

### 2026-02-25 — NPC Backstory Overrides Authored (Task #6)

**From:** content-author → **To:** team-lead

> After context window compaction, re-researched and re-verified all 68 NPC type IDs from the database TSV (city_npcs_detailed.tsv). Authored backstory text for NPCs across 14 of 15 starting cities (Kelethin excluded — gfaydark NPCs not in TSV, cannot verify IDs safely). Sent complete npc_overrides JSON to team-lead for file writing since content-author lacks Write/Edit/Bash tools.
>
> CORRECTION DISCOVERED: Existing entry "1077" claiming to be Captain Tillin is wrong — npcID 1077 is Danon_Fletcher (merchant). Captain Tillin's real ID is 1068. New entry added at 1068. Existing 1077 entry left unchanged to avoid breaking Phase 1/2 content (needs future cleanup).
>
> Key authoring decisions:
> - Halas NPCs use consistent brogue ("ye", "o'", "dinnae") per quest script calibration
> - Freeport Militia (9018, 9109) written as morally ambiguous per PRD faction constraint
> - Neriak NPCs reference Innoruuk consistently; High Priestess Alexandria reflects The Spurned faction
> - Cabilis NPCs maintain xenophobic "warm-blood" perspective throughout
> - Paineel NPCs distinguish from Erudin — defiant about exile, not ashamed
> - Guard Lecknar (75040) noted as undead bodytype — backstory written to reflect this
> - Kozyn Gigglephizz authored at both IDs (55223 and 55164) with complementary text

**Outcome:** 74 backstory entries authored (content-author counted 68, actual file contains 74), verified IDs, written to global_contexts.json by team-lead. Total npc_overrides: 87.

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Added 6th soul axis (Loyalty) | game-designer + lore-master | 2026-02-25 | Lore-master identified faction commitment as critical missing dimension |
| 2 | Deity alignment rules mandatory | game-designer + lore-master | 2026-02-25 | NPCs with deities must have soul traits consistent with deity values |
| 3 | Guard identity is city-specific, not generic | game-designer + lore-master | 2026-02-25 | Freeport Militia, Wolves of North, Legion of Cabilis etc. are distinct forces |
| 4 | Anti-flattening is an explicit design goal | game-designer + lore-master | 2026-02-25 | Soul system must preserve racial/cultural differentiation |
| 5 | Elisi Nasin replaced with Maesyn Trueshot | game-designer + lore-master | 2026-02-25 | Elisi is a Rogue GM (East Freeport), not a Ranger. Maesyn is a Ranger GM in Kelethin. |
| 6 | Soul elements in separate soul_elements.json | architect + config-expert | 2026-02-25 | Different authoring cadence from backstories; cleaner separation; independent reload |
| 7 | Quest hints as Layer 5.5 with separate budget | architect + config-expert | 2026-02-25 | Quest hints are contextual directives between faction and personality layers |
| 8 | Reload endpoint over file-watching | architect + config-expert | 2026-02-25 | No dependency on watchdog; explicit, testable, supports content author workflow |
| 9 | NPC deity via Lua GetDeity() not sidecar DB | architect | 2026-02-25 | Method exists on Lua_Mob; field exists in ChatRequest; zero C++ changes |
| 10 | AutoInjectSaylinksToSay handles quest keywords | architect + protocol-agent | 2026-02-25 | Rule defaults true; [brackets] in NPC Say() auto-convert to clickable saylinks |
| 11 | No protocol/C++ changes needed | architect + protocol-agent | 2026-02-25 | Entire feature is sidecar + Lua + config |
| 12 | .env must be updated alongside docker-compose | config-expert → architect | 2026-02-25 | Phase 2.5 vars absent from .env; Phase 3 adds 3 more — all need .env entries for operator visibility |
| 13 | PromptAssembler.__init__() needs budget_quest_hints | config-expert → architect | 2026-02-25 | Plan uses LLM_BUDGET_QUEST_HINTS in assembler but omits the __init__ read — sidecar-expert must add it |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| 15-city count validation | game-designer, lore-master | Believed correct (not flagged by lore-master) | No |
| Holly Windstalker validity | game-designer, lore-master | Not flagged by lore-master | No |
| Final PRD lore sign-off | game-designer, lore-master | APPROVED (with 2 corrections, now applied) | No — resolved |
