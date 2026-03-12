# Companion Group Commands — Agent Conversations Log

> **Feature branch:** `feature/companion-group-commands`
> **Created:** 2026-03-11

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

### 2026-03-11 — Proactive Lore Context (Pre-PRD)

**From:** lore-master → **To:** game-designer

> Proactive lore review of brainstorm notes. Key findings:
> - All 9 commands are mechanically clean, no era concerns
> - !flee hate retention is lore-correct (mobs pursue in Norrath)
> - !buffme/!buffs caster-only restriction matches Norrath class design
> - !equipmentupgrade/!equipmentmissing are purely mechanical, no lore issues
> - Companion response tone should respect racial voice from companion_culture.lua
>   (Ogres: terse, Mercenaries: no warmth, Iksar: disciplined)
> - !assist: loyal vs mercenary companions differ in flavor, not behavior

**Response from** game-designer:

> Acknowledged all points. PRD uses functional message templates (not
> personality-driven dialogue). Racial voice is a downstream implementation
> concern handled by companion_culture.lua. Asked lore-master to do formal
> review of completed PRD.

**Outcome:** Lore context incorporated into PRD design decisions. No PRD changes needed.

---

### 2026-03-11 — Formal Lore Review: Complete PRD

**From:** game-designer → **To:** lore-master

> Sent completed PRD (game-designer/prd.md) for formal lore sign-off.
> Requested review of: era compliance, feedback message tone, named NPCs
> in examples, error messages for non-caster companions, thematic
> appropriateness of !flee and !equipmentupgrade mechanics.

**Response from** lore-master:

> **VERDICT: APPROVED**
>
> Section-by-section review:
> - Era Compliance: APPROVED — all stats, spells, equipment are Classic-Luclin
> - !flee hate retention: APPROVED — lore-correct, authentic to Norrath
> - !assist auto-stance-switch: APPROVED — pragmatic and lore-neutral
> - Feedback message tone: APPROVED — functional system messages, correct approach
> - !status output format: APPROVED — informational, no narrative needed
> - !buffme/!buffs caster restriction: APPROVED — matches Norrath class design
> - !help categories: APPROVED — logical organization, no lore concerns
> - Named NPCs in examples: APPROVED — illustrative placeholders, no conflicts
>
> **One note (non-blocking):** !equipmentupgrade responses — clarify during
> architecture whether these are static formatted output or LLM-routed dialogue.
> If LLM-routed, racial voice constraints apply (e.g., Ogre cannot say
> "stat sum: 45 vs 12"). This is an architecture question, not a PRD revision.

**Outcome:** Lore sign-off granted. PRD approved for handoff to architect.
One architecture-phase note logged about !equipmentupgrade response routing.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-03-11 — Architect Rule Review Request

**From:** architect → **To:** config-expert

> Pre-architecture rule review request. Questions:
> 1. Do existing rules cover buff conservation threshold (30% in companion_ai.cpp), !buffme mana threshold (PRD's 10%), command cooldowns?
> 2. What new rules are needed? (buff OOM threshold, !tome proximity, !equipmentupgrade formula weights?)
> 3. Rule interactions: CompanionFleeEnabled vs !flee command, GroupChatAddressingEnabled as master toggle?

**Response from** config-expert:

> **Q1 answers:**
> - HealerManaConservePct (30%) IS a rule — governs healer spell selection, not buff request acceptance. Separate concern from !buffme check.
> - !buffme mana threshold (10%): NO existing rule. ManaCutoffPct (20) and HealerManaConservePct (30) don't cover this. New rule needed.
> - Command cooldowns: NO existing rule. RecallCooldownS is !recall-specific. New commands are lightweight, spam not a concern.
>
> **Q2 answers:**
> - 2 new rules recommended: `BuffRequestManaMinPct` (10) and `TomeNearbyRadiusUnits` (50)
> - !equipmentupgrade formula weights: NOT rules — PRD intentionally fixes the formula as "simplistic"; making weights configurable adds complexity without value
>
> **Q3 answers:**
> - CompanionFleeEnabled: does NOT interact with !flee command. Controls NPC self-preservation flee (low HP panic). !flee is player-issued tactical retreat. No conflict.
> - GroupChatAddressingEnabled: IS the master toggle for @name/@all. Hard dependency for all new commands via /gsay path. Must be documented in architecture.
>
> **Summary:** No eqemu_config.json changes. No C++ changes. 2 new RULE_INT entries in ruletypes.h Companions category. rule_values inserts (data-expert). GroupChatAddressingEnabled=true is a hard dependency.

**Outcome:** Architect has complete rule picture for architecture finalization. Config-expert findings confirmed: 2 new rules, no config file changes.

---

### 2026-03-11 — Architect Protocol Feasibility Request (Round 1: Pre-Architecture)

**From:** architect → **To:** protocol-agent

> Pre-architecture protocol review request. Questions:
> 1. Can the Titanium client handle rapid sequential client:Message() calls from @all dispatches (up to 5 companions responding)?
> 2. Do item links in /gsay messages pass through HandleGroupChatMentions to EVENT_SAY intact, or are they stripped/modified?
> 3. Any practical length limits on client:Message() output for commands like !status (which may show 42 buffs)?
> 4. Are there packet-level concerns with the !flee movement chain (SetStance + RunTo + SetGuardMode in rapid succession)?

**Response from** protocol-agent:

> **Q1:** No concerns. client:Message() sends individual OP_SpecialMesg packets. Titanium handles rapid sequential packets well — the client queues and renders them in order. No flooding threshold for server-to-client messages at this rate (5 companions * ~10 lines each = ~50 packets is trivial).
>
> **Q2:** Item links pass through intact. HandleGroupChatMentions extracts the payload after @name but does not modify the content. The \x12-delimited link bytes are preserved in e.message by the time they reach EVENT_SAY in Lua.
>
> **Q3:** No practical limit on client:Message() content length. Each call is a separate packet with its own text payload. The client's chat window handles arbitrary message counts. The only concern would be readability, not protocol limits.
>
> **Q4:** No packet concerns. SetStance, RunTo, and SetGuardMode are server-side state changes that generate position/animation updates through the normal entity update pipeline. They don't produce client-targeted packets that could conflict.

**Outcome:** No Titanium protocol constraints for any of the 9 commands. All client-facing operations use standard, well-exercised packet paths. No modifications to opcodes, structs, or the translation layer needed.

---

### 2026-03-11 — Architect Protocol Feasibility Request (Round 2: Post-Architecture)

**From:** architect → **To:** protocol-agent

> Architecture complete. 4 specific questions for protocol review:
> 1. Chat message length limits: !status and !help use client:Message() (~20+ lines). Any Titanium truncation?
> 2. Item link parsing from group chat: How are links encoded in ChannelMessage_Struct? Can Lua access raw item link data from e.message? Does server strip them?
> 3. Group chat dispatch timing: Risk of packet flooding or ordering issues when @all dispatches to 5 companions?
> 4. OP_ChannelMessage constraints: Any opcode/struct constraints for using group chat as command channel?

**Response from** protocol-agent:

> **Q1:** No truncation. Server limit is 4095 bytes per `ChannelMessageSend` call. The real constraint: `\n` does not render as newlines in Titanium group chat — each line must be a separate `CompanionGroupSay()` call (one call = one line). The existing codebase already follows this pattern. 20 lines is fine protocol-wise; UX concern only (chat flood for `!help`, `@all !status` producing 30-50 lines).
>
> **Q2:** Item links survive the group chat round trip intact. `titanium.cpp:DECODE(OP_ChannelMessage)` (line 2587) runs `TitaniumToServerSayLink()`, converting Titanium's 45-char link body to the 56-char internal format. By the time `e.message` arrives in Lua's `event_say`, `\x12` delimiters are present and the link body is in internal format. Item ID is at bytes 1-5 after `\x12` as hex (`strtol(body.substr(1,5), nullptr, 16)`). Parsing precedent: `gm_commands/summonitem.cpp:15-20`. Implementation note: Lua can do the hex parsing manually (`tonumber(hex_str, 16)`) or a C++ helper binding can be added — C++ path is cleaner and well-tested.
>
> **Q3:** No protocol risk. Titanium client handles rapid sequential `OP_ChannelMessage` packets transparently. Architecture note: the current `HandleGroupChatMentions` stagger mechanism ONLY staggers LLM conversations (`is_conversation = payload[0] != '!'`), so `@all !status` dispatches to all 5 companions simultaneously with no stagger. This is fine at the protocol level.
>
> **Q4:** No constraints. Correction to earlier analysis: `OP_ChannelMessage` IS in titanium.cpp ENCODE/DECODE (lines 349-376, 2587-2604) for say link body size conversion — but this is transparent. No opcode changes, no struct changes, no translation layer modifications needed.
>
> **Architecture correction needed:** Architecture doc (line 311) says "Protocol-agent consultation: Confirmed no Titanium client constraints. Chat messages via `client:Message()` have no practical length limit." This is correct for `client:Message()` but the PRD requires group chat responses, which means `CompanionGroupSay()` not `client:Message()`. The architecture (line 88, 92) specifies Lua-only changes — this is correct, but the handler implementations must use `group:GroupMessage()` for group chat output, not `client:Message()` for private output. The architecture should clarify this for lua-expert.

**Outcome:** No protocol changes needed. Architecture confirmed feasible. One clarification flagged for lua-expert: response channel must be `group:GroupMessage()` not `client:Message()` for commands requiring group-visible responses.

---

### 2026-03-11 — Architect Decision: Rules Override

**From:** architect (decision note)

> Config-expert recommended 2 new rules: `BuffRequestManaMinPct` (10) and `TomeNearbyRadiusUnits` (50). After reviewing the full architecture, the architect decided **against adding new rules** for this feature.
>
> **Rationale:** The PRD thresholds (10% mana OOM, 50-unit proximity) are intentional game design constants, not server-configurable tunables. Making them rules adds unnecessary complexity (C++ ruletypes.h changes, rule_values inserts, Lua rule lookups) for values that should never change independently of the game design. If the PRD says "10% mana," that is the design, not a suggestion to create a tunable.
>
> This keeps the implementation pure Lua with zero C++ or database changes.

**Outcome:** Architecture doc finalized with no new rules. Config-expert's recommendation was considered and respectfully overridden. The thresholds remain hardcoded in the Lua handlers.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | !flee does NOT clear hate list — realistic retreat | game-designer, lore-master | 2026-03-11 | Lore-master confirmed: lore-correct, mobs pursue in Norrath |
| 2 | !equipmentupgrade uses simple stat sum (AC + all stats + HP + Mana) | game-designer | 2026-03-11 | Intentionally simplistic for quick actionable signal |
| 3 | !buffme/!buffs queue for idle, never interrupt combat | game-designer | 2026-03-11 | Prevents breaking heal/combat spell rotations |
| 4 | !assist auto-switches passive→balanced before engaging | game-designer, lore-master | 2026-03-11 | Lore-master confirmed: pragmatic and lore-neutral |
| 5 | Feedback messages are functional templates, not personality-driven | game-designer, lore-master | 2026-03-11 | Racial voice handled downstream by companion_culture.lua |
| 6 | !equipmentupgrade response routing TBD at architecture phase | lore-master | 2026-03-11 | If LLM-routed, racial voice constraints apply |
| 7 | NO new rules — architect overrode config-expert recommendation | config-expert, architect | 2026-03-11 | Config-expert recommended BuffRequestManaMinPct and TomeNearbyRadiusUnits; architect decided thresholds are game design constants, not tunables |
| 8 | !equipmentupgrade formula weights are NOT rules — kept hardcoded in Lua | config-expert, architect | 2026-03-11 | PRD intentionally simplistic; configurability adds complexity without value |
| 9 | CompanionFleeEnabled does NOT interact with !flee command | config-expert, architect | 2026-03-11 | CompanionFleeEnabled = NPC self-preservation; !flee = player tactical retreat |
| 10 | GroupChatAddressingEnabled is hard dependency for @name/@all path | config-expert, architect | 2026-03-11 | All new /gsay commands require this rule=true; /say path still works |
| 11 | No Titanium protocol constraints — all 9 commands use standard packet paths | protocol-agent, architect | 2026-03-11 | Item links pass through intact, rapid Message() calls are fine, no opcode changes needed |
| 12 | !equipmentupgrade responses are static formatted output, NOT LLM-routed | architect | 2026-03-11 | Resolves lore-master's architecture-phase question; racial voice constraints not applicable |
| 13 | OP_ChannelMessage HAS ENCODE/DECODE in titanium.cpp — not pass-through | protocol-agent | 2026-03-11 | Lines 349-376 (ENCODE) and 2587-2604 (DECODE) handle say link body size conversion (56-char server ↔ 45-char Titanium). Transparent to feature. |
| 14 | Item link body in e.message is 56-char internal format after DECODE | protocol-agent | 2026-03-11 | TitaniumToServerSayLink() converts on inbound. Item ID parseable at bytes 1-5 as hex. |
| 15 | Command responses must use group:GroupMessage() not client:Message() for group-visible output | protocol-agent | 2026-03-11 | client:Message() sends OP_SpecialMesg (private); PRD requires group chat visibility |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| !equipmentupgrade response: static vs LLM-routed | lore-master flagged, architect decided | RESOLVED — static formatted output, not LLM-routed | No |
| !buffme mana threshold: rule vs hardcoded | architect overrode config-expert | RESOLVED — hardcoded in Lua (10%), no new rule | No |
| !tome proximity threshold: rule vs hardcoded | architect overrode config-expert | RESOLVED — hardcoded in Lua (50 units), no new rule | No |
