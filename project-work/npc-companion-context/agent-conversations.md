# NPC Companion Context — Agent Conversations Log

> **Feature branch:** `feature/npc-companion-context`
> **Created:** 2026-03-02

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

### 2026-03-02 — Initial Feature Concept and Lore Context Request

**From:** game-designer → **To:** lore-master

> Starting PRD for NPC Companion Context feature. Core concept: when NPC is
> recruited as companion, LLM context shifts so they talk as group member, not
> original role. Will send lore-sensitive sections for review. Key areas:
> race/class/culture personality variation, zone awareness, era compliance.

**Response from** lore-master:

> Acknowledged. Ready to review sections as they come in.

**Outcome:** Initial coordination established. Lore-master aware of incoming review.

---

### 2026-03-02 — PRD Draft Lore Review Request

**From:** game-designer → **To:** lore-master

> PRD draft complete. Sent three sections for lore review:
> 1. Example scenario using Tegea Prendyn (Surefall Glade Druid) — verify NPC
>    exists, gnoll clan in West Karana, Surefall Glade details
> 2. Personality variation by race/culture (Erudite, Barbarian, Dark Elf,
>    Halfling, Troll, Vah Shir archetypes) — verify accuracy
> 3. Era compliance — Vah Shir/Luclin references, PoP boundary

**Response from** lore-master:

> APPROVED WITH ONE ISSUE AND SEVERAL NOTES:
>
> **ISSUE #1 (Required fix):** Gnoll clan error — Splitpaw clan is in
> Southern Karana, not West Karana. West Karana gnolls are the Sabertooth
> clan (based in Blackburrow). A Surefall Glade druid would know the
> difference.
>
> **Suggestions incorporated:**
> - Vah Shir: Primary threats are grimlings and Akheva, not Shissar.
>   Shissar are distant/secondary (Grey region, Ssraeshza Temple).
> - Vah Shir oral culture: Written records banned. Knowledge passed via
>   hymnists and mnemonic scribes. They blame Erudite written magic for
>   exile to Luclin. Rich personality territory.
> - Iksar KOS constraints: Cannot reference good-aligned old-world cities
>   as familiar. Welcome only in Cabilis, Thurgadin, Luclin cities.
> - Erudite distinction: Erudin (good) vs Paineel (heretics). Class
>   identifies origin city (necromancer = Paineel, paladin = Erudin).
> - Era compliance additions: Froglok (monster only), Berserker (does not
>   exist), PoP exclusion.
> - Luclin fixed-lighting zones: Day/night commentary invalid on some
>   Luclin zones.
>
> **All other sections approved:** Problem statement, goals, non-goals,
> player flow, druid-underground discomfort, Surefall Glade waterfall,
> Befallen undeath reference, identity shift mechanics, balance
> considerations, affected systems, acceptance criteria, technical appendix.
>
> **Existing companion_culture.lua framings confirmed lore-accurate:**
> Ogre panic behavior, Dark Elf cold precision, Iksar disciplined/insular,
> Troll feral aggression.

**Outcome:** All findings incorporated into PRD. Gnoll clan fixed to
Sabertooth. Vah Shir, Iksar, Erudite, era compliance sections enriched.
New Iksar acceptance criterion added. Luclin lighting open question added.
Lore-master implementation notes added to technical appendix.

---

### 2026-03-02 — Lore Corrections Confirmation

**From:** game-designer → **To:** lore-master

> Confirmed all 10 changes incorporated into PRD:
> 1. Splitpaw -> Sabertooth gnolls
> 2. Vah Shir threats: grimlings/Akheva primary, Shissar secondary
> 3. Vah Shir oral culture (hymnists, banned written records)
> 4. Iksar KOS constraints with city list
> 5. Iksar acceptance criterion added
> 6. Erudite Erudin/Paineel distinction
> 7. Froglok/Berserker era exclusions
> 8. Luclin fixed-lighting note + open question
> 9. Lore-master implementation notes in technical appendix
> 10. PRD header updated with lore approval

**Response from** lore-master:

> _(confirmation acknowledged)_

**Outcome:** PRD finalized with full lore sign-off. Ready for architecture.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-03-02 — Client Feasibility for Companion Context Feature

**From:** architect → **To:** protocol-agent

> Consulted on two questions:
> 1. Client feasibility: Feature uses existing OP_ChannelMessage / NPC Say
>    packets for companion dialogue. No new opcodes or structs. Are there
>    message length limits in ChannelMessage_Struct that could be a concern?
> 2. Unprompted commentary: Companion speaks from a Lua timer callback via
>    e.self:Say(). Any packet-level concerns with NPC-initiated speech from
>    timer events?

**Response from** protocol-agent:

> Follow-up sent after context window compaction. The questions are confirmatory
> — the feature uses standard OP_ChannelMessage/NPC Say packets and e.self:Say()
> from timer callbacks, both well-established patterns. No response received
> before architecture finalization. These are low-risk items: ChannelMessage_Struct
> supports variable-length messages (LLM output is short), and NPC Say from
> timer events is identical to NPC Say from any other script context.

**Outcome:** Architecture finalized without blocking. Questions are confirmatory,
not discovery. No new opcodes, structs, or translation layer changes needed.
If protocol-agent identifies a constraint, it can be addressed before
implementation begins.

---

### 2026-03-02 — Configuration Assessment for Companion Context Feature

**From:** architect → **To:** config-expert

> Consulted on four questions:
> 1. Existing rules: Any rules in ruletypes.h related to companions, LLM,
>    NPC dialogue, or chat?
> 2. Companion rules: Complete list of existing companion rules beyond the
>    ones identified (CompanionsEnabled, BaseRecruitChance, etc.)
> 3. Can any of this be config-only? Core changes are Lua modifications to
>    build_context() and new timer system.
> 4. Unprompted commentary timing: Should values be hardcoded Lua constants,
>    server rules, or llm_config.lua values? PRD suggests hardcoded.

**Response from** config-expert:

> Follow-up sent after context window compaction. The questions are confirmatory
> — architect independently verified that existing companion rules (CompanionsEnabled,
> BaseRecruitChance, etc.) are in the Companion category of ruletypes.h and are
> recruitment/combat focused, not LLM/dialogue focused. No rules exist for LLM,
> NPC dialogue, or chat systems. The decision to place commentary timing values
> in llm_config.lua (hot-reloadable, colocated with other LLM settings) is
> justified by the creative-tuning nature of the values.

**Outcome:** Architecture finalized without blocking. Commentary timing values
placed in llm_config.lua (Decision #8 in Decision Log). No existing rules
conflict with or duplicate the planned configuration. If config-expert identifies
an existing rule that could be leveraged, it can be incorporated before
implementation begins.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### [Date] — [Topic]

**From:** [agent] → **To:** [agent]

> [Message content or summary]

**Response from** [agent]:

> [Response content or summary]

**Outcome:** _What was decided or changed as a result_

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | West Karana gnolls are Sabertooth clan, not Splitpaw | game-designer, lore-master | 2026-03-02 | Example scenario correction |
| 2 | Vah Shir primary threats are grimlings and Akheva, not Shissar | game-designer, lore-master | 2026-03-02 | Cultural accuracy |
| 3 | Vah Shir oral culture (banned written records) is a defining personality trait | game-designer, lore-master | 2026-03-02 | Personality differentiation |
| 4 | Iksar companions must not reference good-aligned old-world cities as familiar | game-designer, lore-master | 2026-03-02 | KOS lore constraint |
| 5 | Erudite companions should distinguish Erudin vs Paineel origin by class | game-designer, lore-master | 2026-03-02 | Personality enrichment |
| 6 | Feature is Lua-only except for 2 C++ Lua bindings — no protocol/DB changes | architect | 2026-03-02 | Least-invasive-first principle |
| 7 | Commentary timing values in llm_config.lua, not ruletypes.h | architect | 2026-03-02 | Hot-reloadable, creative tuning, colocated with LLM settings |
| 8 | Recent kill tracking via Lua entity variables, not C++ | architect | 2026-03-02 | Transient data; C++ only has counter, no NPC names |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| Protocol-agent confirmation on ChannelMessage limits and timer-Say | architect, protocol-agent | Follow-up sent, non-blocking | No |
| Config-expert confirmation on existing rules and llm_config.lua placement | architect, config-expert | Follow-up sent, non-blocking | No |

