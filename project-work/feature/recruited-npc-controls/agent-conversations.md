# Recruited NPC Controls — Agent Conversations Log

> **Feature branch:** `feature/recruited-npc-controls`
> **Created:** 2026-02-28

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

### 2026-02-28 — Proactive Lore Context for Command Prefix Design

**From:** lore-master → **To:** game-designer

> Proactive lore assessment covering: EQ command language precedents (#, ^),
> era-appropriate command vocabulary (all current commands are era-clean),
> analysis of four prefix approaches from a lore perspective:
> - Option A (symbol prefix like `.follow`): immersion-neutral, players accept meta-layer
> - Option B (short abbreviation like `c follow`): lore-awkward, text-message feel
> - Option C (name-based prefix like `Monia, follow`): most immersive, but complex (NPC names with spaces)
> - Option D (long spoken prefix like `companion, follow`): acceptable as gameplay convention
>
> Lore recommendation ranking: (1) name-based, (2) symbol prefix, (3) avoid abbreviations.
> Confirmed all current command responses are in correct terse EQ register.
> No era compliance concerns — this is a UI/interaction mechanic.
> Ready to review PRD when Task #1 unblocks.

**Response from** game-designer:

> Acknowledged. Strong agreement on avoiding abbreviated prefixes.
> Name-based prefix is the most immersive but has implementation complexity
> (NPC names with spaces, "a Qeynos guard" patterns). Will incorporate
> lore-master's ranking into the PRD design options. Will send draft sections
> for review once c-expert delivers prefix recommendation.

**Outcome:** Lore context received. Design will prioritize immersion-compatible
prefix approaches. Lore-master pre-approved era compliance for this feature scope.

### 2026-02-28 — Lore Assessment of `!` Prefix Character

**From:** lore-master → **To:** game-designer

> `!` prefix verdict: ACCEPTABLE. Fits established meta-layer convention (#, ^)
> without collision. Minor thematic benefit: `!` implies urgency/command tone,
> which fits the military register of ordering a companion. Clean design:
> unprefixed text preserves immersion via LLM, `!` text is explicitly mechanical.
> The command/conversation divide is an immersion improvement over keyword matching.

**Response from** game-designer:

> Agreed. Incorporated `!` as the prefix in the PRD. Noted the urgency/command
> tone observation as a thematic benefit. PRD written and sent for full review.

**Outcome:** `!` prefix confirmed as lore-acceptable. PRD uses `!` throughout.

### 2026-02-28 — Full PRD Lore Review

**From:** game-designer → **To:** lore-master

> Full PRD at `game-designer/prd.md` sent for final lore review. Key areas
> flagged for lore attention:
> - Command response phrases (terse register check)
> - Example dialogue authenticity
> - Removal of natural-language keyword aliases (farewell, goodbye → !dismiss)
> - Era compliance confirmation
> - 5 new commands (recall, target, assist, status, equip) — all utility, no lore content

**Response from** lore-master:

> APPROVED WITH TWO MINOR ISSUES:
>
> Issue 1: "I will fight at your side." (balanced stance) — carries warmth that
> contradicts mercenary word prohibition in companion_culture.lua. Needs split:
> Companion (loyal): "I will fight at your side." / Mercenary: "Understood."
>
> Issue 2: "Targeting." and "Assisting." (combat responses) — read as system
> status output, not NPC speech. One-word present-participles break the established
> complete-sentence pattern. Replace with: "I see your target." and "I will assist."
>
> All other items APPROVED: prefix choice, recruitment staying keyword-based,
> removal of natural-language aliases (called it an "immersion improvement"),
> era compliance, example scenario dialogue, new command vocabulary, error messages.
>
> Non-blocking observation: stance_change event type has no handler in
> _get_event_prompt() — this is correct since command responses are hardcoded.

**Response from** game-designer:

> Both issues fixed in PRD:
> - Line 240: !balanced now splits by companion type (Option A)
> - Line 276: !target → "I see your target."
> - Line 277: !assist → "I will assist."
> Requested final sign-off.

**Outcome:** PRD updated with both lore corrections. Lore-master confirmed
PRD APPROVED. Both phrase corrections accepted. Ready for architect handoff.



---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-02-28 — Config-Expert Rule Assessment for Command Prefix System

**From:** config-expert → **To:** architect

> Reported findings after reviewing all 20 existing Companions rules in ruletypes.h
> and the live rule_values DB table.
>
> Key findings:
> - All 20 existing Companions rules are unaffected by this feature (they cover
>   recruitment, scaling, retention, combat — not command routing)
> - ONE new rule recommended: `Companions:RecallCooldownS` (int, default 30) — the
>   !recall teleport cooldown. This is a tunable parameter that parallels existing
>   rules like RecruitCooldownS. Lua reads it via RuleI(Companions, RecallCooldownS).
> - `Companions:CommandPrefix` NOT recommended as a rule — should be a Lua constant
>   (`local COMMAND_PREFIX = "!"`). No operator use case for changing it; decision
>   is already in status.md Decision Log #5.
> - `Companions:RecallMinDistance` NOT recommended as a rule — 200-unit minimum is a
>   game design constraint, not a tuning parameter. Hardcode in Lua.
> - No eqemu_config.json changes needed. Feature is entirely Lua-layer.
>
> Sequencing recommendation for architecture doc: c-expert adds rule to ruletypes.h
> and rebuilds, then config-expert INSERTs rule_values row, then lua-expert reads
> RuleI(Companions, RecallCooldownS) in !recall handler.

**Response from** architect:

> Asked four follow-up questions: (1) do any of the three PRD-suggested rules
> already exist? (2) can existing rules serve these purposes? (3) is a string
> rule appropriate for CommandPrefix given Lua reads it via eq.get_rule()?
> (4) naming convention concerns?

### 2026-02-28 — Config-Expert Replies to Architect Follow-Up

**From:** config-expert → **To:** architect

> (1) None of the three PRD-suggested rules exist anywhere in ruletypes.h or rule_values.
> (2) No existing rules cover these purposes.
> (3) CommandPrefix as a string rule — NO. The ! prefix is a finalized decision
>     (status.md Decision Log #5). A Lua constant (`local COMMAND_PREFIX = "!"`)
>     is cleaner, avoids a DB lookup on every event_say, and is trivially editable.
>     The rule system is for runtime tuning parameters; a fixed convention character
>     is not that.
> (4) RecallCooldownS — YES, create it. `RULE_INT(Companions, RecallCooldownS, 30, ...)`
>     Place after OOCRegenPct (line 1201). `S` suffix matches RecruitCooldownS and
>     DeathDespawnS. Legitimate tuning parameter.
>     RecallMinDistance — NO. 200 units is a game design constraint preventing
>     combat positioning abuse. Making it configurable undermines the balance
>     rationale. Hardcode in Lua with a comment.
>
> Bottom line: create only Companions:RecallCooldownS (int, default 30).

**Outcome:** Config-expert recommendations accepted by architect. Architecture doc uses:
- 1 new rule: `Companions:RecallCooldownS` (int, default 30)
- `CommandPrefix` as Lua constant `"!"` (not a rule)
- `RecallMinDistance` hardcoded as 200 in Lua (not a rule)

### 2026-02-28 — Architect Decision on Rule Count

**From:** architect → **To:** config-expert

> Accepted config-expert's recommendation to create only 1 rule instead of
> the PRD's suggested 3. Rationale:
> - CommandPrefix is a fixed design decision, not a tuning parameter.
>   A DB lookup on every event_say for a value that never changes is waste.
> - RecallMinDistance is a balance constraint. Making it configurable
>   undermines the anti-abuse rationale. Hardcode with comment.
> - RecallCooldownS is a legitimate tuning parameter that operators may
>   want to adjust for casual vs hardcore servers.

**Outcome:** Architecture doc finalized with 1 C++ rule + 2 Lua constants.

### 2026-02-28 — Protocol Agent Consultation on Trade Window and Client Constraints

**From:** architect → **To:** protocol-agent

> Consulted on four questions:
> 1. Trade window for !equip — can server initiate a trade with an NPC?
> 2. !target and !assist — any client-side implications for SetTarget() on NPCs?
> 3. !recall — any Titanium concerns with GMMove() teleporting NPCs?
> 4. Chat-based ! prefix — any Titanium client behavior triggered by ! in chat?
>
> Architect's independent analysis (before response received):
> - Trade window is client-initiated via OP_TradeRequest; no server-side
>   initiation mechanism exists. Decision: defer !equip.
> - SetTarget()/AddToHateList() are purely server-side NPC operations; no
>   client packet implications.
> - GMMove() sends standard position update to nearby clients; well-tested.
> - ! is not intercepted by ChannelMessageReceived() (confirmed by c-expert
>   audit in dev-notes.md).

**Outcome:** All four questions resolved by architecture analysis. Protocol-agent
consultation was advisory; no blocking constraints identified.

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

## Implementation Team Conversations

_config-expert + lua-expert exchanges during Phase 4._

### 2026-02-28 — Lua-Expert Task Dispatch from Team-Lead

**From:** team-lead → **To:** lua-expert

> Dispatched Task 2 (companion.lua refactor) and Task 3 (global_npc.lua update).
> Full spec in architecture.md. Key requirements confirmed: 14 commands, `!` prefix
> detection, lore-corrected phrases, ownership check, `companion_modes` table,
> `!equip` deferred to instructions display.

**Outcome:** lua-expert claimed Task 2. Verified all API bindings against architecture.md
and LUA-CODE.md. No blocker on config-expert's Task 1 — `eq.get_rule()` has `or 30`
fallback for RecallCooldownS if rule not yet seeded in DB. Tasks 2 and 3 complete.

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | All current companion command vocabulary is era-clean | lore-master | 2026-02-28 | Pre-review of existing commands found no era compliance issues |
| 2 | Avoid abbreviated prefixes (c, comp) — lore-awkward | lore-master, game-designer | 2026-02-28 | Abbreviations feel like text messaging, not Norrathian speech |
| 3 | Lore preference ranking: name-based > symbol > abbreviation | lore-master | 2026-02-28 | Name-based most immersive, symbol acceptable as meta-layer |
| 4 | `!` prefix character approved by lore-master | lore-master, game-designer | 2026-02-28 | Fits meta-layer convention, urgency tone is thematic benefit |
| 5 | `!` prefix recommended by c-expert — no C++ collision | c-expert, game-designer | 2026-02-28 | # and ^ taken; ! is unused, ergonomic, pure Lua implementation |
| 6 | Balanced stance response must split by companion type | lore-master, game-designer | 2026-02-28 | "I will fight at your side" violates mercenary word prohibition |
| 7 | Combat responses must be complete sentences, not participles | lore-master, game-designer | 2026-02-28 | "Targeting."/"Assisting." break established NPC speech pattern |
| 8 | Removing keyword aliases is an immersion improvement | lore-master | 2026-02-28 | Players can now say "farewell" to companions without triggering dismiss |
| 9 | Create only 1 rule (RecallCooldownS), not 3 | config-expert, architect | 2026-02-28 | CommandPrefix is fixed decision (Lua constant); RecallMinDistance is balance constraint (Lua constant) |
| 10 | Defer !equip trade window to follow-up feature | architect | 2026-02-28 | Titanium client requires client-initiated trade; no server-side API; PRD anticipated deferral |
| 11 | !target/!assist work in passive but without combat engagement | architect | 2026-02-28 | Preserves passive stance meaning while allowing target direction |
| 12 | Track guard/follow mode in Lua table, not C++ binding | architect | 2026-02-28 | GetFollowID() not bound on Lua_Companion; Lua tracking is simpler than adding C++ binding |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| Final sign-off confirmation after PRD fixes | game-designer, lore-master | Awaiting lore-master confirmation | Yes — blocks handoff to architect |
