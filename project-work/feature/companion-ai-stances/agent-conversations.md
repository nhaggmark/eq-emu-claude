# companion-ai-stances — Agent Conversations Log

> **Feature branch:** `feature/companion-ai-stances`
> **Created:** 2026-03-08

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

### 2026-03-08 — Early Lore Review: Thematic Framing of Companion AI Stances

**From:** game-designer → **To:** lore-master

> Sent feature concept for review: companion AI stances (Aggressive/Balanced/Passive) and
> recruitment as a clean break from NPC AI. Asked three questions:
> 1. Thematic framing: What's the in-world justification for a recruited NPC abandoning
>    their original duties (e.g., a guard stopping guard behavior)?
> 2. Stance names: Are Aggressive/Balanced/Passive appropriate for Classic-Luclin era?
> 3. Stance change dialogue: Any lore concerns with the companion acknowledgment lines?

**Response from** lore-master:

> Lore-master confirmed ready to review but was shut down by team lead before
> completing formal review. The team lead determined design phase is complete.

**Outcome:** Lore review deferred — team lead approved shutdown before formal response.

### 2026-03-08 — Full PRD Review Request

**From:** game-designer → **To:** lore-master

> Sent complete PRD for full lore review. Included summary of key lore-relevant
> design decisions: clean break from NPC AI on recruitment, faction perspective
> shifts to player on recruitment, flee behavior retention, Guard Gevin example
> scenario, era compliance (no post-Luclin references).

**Response from** lore-master:

> Design team shut down before lore-master could complete formal review.
> Note: This feature is primarily mechanical (AI behavior control). Lore impact
> is minimal — no new zones, NPCs, factions, or quests are created or modified.
> Stance names (Passive/Balanced/Aggressive) are generic English terms.

**Outcome:** PRD submitted for review. Team shut down by team lead before formal
sign-off. No lore concerns were raised during the session.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-03-08 — Config-expert rules audit summary sent to team-lead

**From:** config-expert → **To:** team-lead

> Completed rules audit. 27 existing Companion rules, none stance-related.
> `companion_data.stance` column already exists (no schema change needed).
> Two new rules identified: `Companions:AggressiveScanRadius` (INT, 75) and
> `Companions:CompanionFleeEnabled` (BOOL, true). Blocked on architect
> architecture.md for final confirmation — may reveal additional rules.
> c-expert adds macros to ruletypes.h; config-expert inserts DB rows after build.

**Response from** team-lead:

> Pending.

**Outcome:** Research complete. Waiting on architect architecture.md before Stage 3 (Socialize) and Stage 4 (Build).

### 2026-03-08 — Architect asks config-expert to confirm rule findings

**From:** architect → **To:** config-expert

> Asked three questions: (1) Are there any existing rules in NPC/Aggro/Mercs categories that could cover companion AI behavior or be repurposed? (2) Do the two proposed new rules match naming conventions and are the defaults appropriate? (3) Is config-only implementation feasible, or are C++ changes required?

**Response from** config-expert:

> (1) No existing rules can be repurposed. NPC and Aggro rules are server-wide, not per-entity. Mercs:AggroRadius is analogous but scoped to mercs only — changing it would affect all mercs. (2) Both proposed rules confirmed correct: naming matches Companions:* convention, AggressiveScanRadius=75 is appropriately conservative vs Mercs:AggroRadius=100, CompanionFleeEnabled=true matches PRD intent. (3) C++ changes are required — rules cannot create the if-branches that don't yet exist in Mob::AI_Process() and NPC::Process(). Rules support the feature once C++ branching is in place.

**Outcome:** Architect's rule plan confirmed. C++ changes confirmed required. Config-expert DB inserts ready to execute after c-expert build succeeds.

### 2026-03-08 — Architect consults protocol-agent on client feasibility

**From:** architect → **To:** protocol-agent

> Asked whether companion AI stance changes require any new opcodes, packet
> struct modifications, or Titanium translation layer changes. Specifically:
> (1) Does the Titanium client need to know about stance values? (2) Are there
> any client-side constraints on aggro/targeting behavior changes? (3) Does
> the balanced group-assist scanning or aggressive hostile scanning introduce
> any packet-level concerns?

**Response from** protocol-agent:

> No client-side constraints. All aggro/targeting/engagement behavior is
> server-side only. The Titanium client does not need awareness of companion
> stances — the client just renders combat animations and HP changes that the
> server sends. No new opcodes, no packet struct changes, no translation layer
> modifications needed.

**Outcome:** APPROVED — no protocol concerns. All stance AI behavior is
entirely server-side. Architecture can proceed without client-side changes.

### 2026-03-08 — Architect confirms final architecture with config-expert

**From:** architect → **To:** config-expert

> Architecture document complete. Confirmed two new rules:
> `Companions:AggressiveScanRadius` (INT, 75) and
> `Companions:CompanionFleeEnabled` (BOOL, true). Config-expert's Task 1
> in implementation sequence: add these two rules to `common/ruletypes.h`.
> No DB inserts needed — rules are loaded from the X-macro definitions.

**Response from** config-expert:

> Acknowledged. Ready to implement Task 1 when implementation phase begins.
> Confirmed: ruletypes.h X-macros auto-register rules at compile time, no
> separate DB insert step required for rule registration.

**Outcome:** Implementation task assignment confirmed. Config-expert has
clear scope for their contribution.

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
| 1 | Two new rules needed: Companions:AggressiveScanRadius (INT, 75) and Companions:CompanionFleeEnabled (BOOL, true) | architect, config-expert | 2026-03-08 | No existing rules cover stance AI; these are the only new configurables identified |
| 2 | C++ changes are required; rules alone cannot implement stance-aware AI | architect, config-expert | 2026-03-08 | AI branching doesn't exist yet in Mob::AI_Process() / NPC::Process() — rules can only tune, not create, code paths |
| 3 | companion_data.stance column already exists (default 1 = Balanced); no schema change needed | config-expert | 2026-03-08 | Persistence infrastructure already in place from prior companion system work |
| 4 | No client-side protocol changes needed; all stance AI is server-side | architect, protocol-agent | 2026-03-08 | Titanium client renders combat state from server — no awareness of stances needed |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| Formal lore sign-off on PRD | game-designer, lore-master | Deferred | No — team lead approved shutdown; feature is primarily mechanical |
