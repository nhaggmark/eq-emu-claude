# Companion System Bug Fixes — Agent Conversations Log

> **Feature branch:** `bugfix/companion-system-fixes`
> **Created:** 2026-03-01

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

### 2026-03-01 — Initial Bug-Fix Concept Review

**From:** game-designer → **To:** lore-master

> Notified lore-master of three companion system bugs being documented:
> 1. LLM Chat Bug — companions show thinking emotes but don't respond
> 2. Equipment Display Bug — traded items don't visually appear on companions
> 3. Equipment Persistence Bug — equipment lost on zone/relog
>
> Asked for initial lore concerns, era compliance review, and any context
> about companion chat/equipment from a lore perspective.

**Response from** lore-master:

> Provided detailed proactive lore research covering all three bugs. Key findings:
>
> **Bug 1 (LLM Chat):** companion_culture.lua injects race-specific and
> companion_type-specific framing — the "soul" layer. Examples: Ogres speak in
> survival panic due to Rallos Zek's divine punishment; Teir'Dal mercenaries
> speak with cold calculation; Iksar speak rarely with warrior precision.
> companion_type 0 (loyal) vs 1 (mercenary) get different relationship framing.
> Prior lore-master review recorded 2026-02-27 in companion_culture.lua header.
> **Key constraint:** fix must preserve cultural voice pathways, not flatten
> companions to generic responses. Bug is a routing/eligibility failure, not
> a dialogue content failure.
>
> **Bug 2 (Equipment Display):** No lore implications. Purely technical.
> event_trade companion says "Thank you." — no dialogue changes needed.
>
> **Bug 3 (Equipment Persistence):** No lore implications. Purely a data
> persistence / C++ layer concern.
>
> **Era compliance:** All three bugs involve internal companion system code.
> No references to post-Luclin content. Era compliance issues extremely unlikely.
>
> **Guidance for PRD:**
> 1. Companion dialogue examples must align with cultural voice system
> 2. Bug 1 is routing, not content — PRD should frame it that way
> 3. Acceptance criteria must not require modern chatbot tone — EQ tone is
>    terse, atmospheric, in-character

**Outcome:** Lore context incorporated into PRD design. Bug 1 framed as
routing/integration failure (aligned with lore-master guidance). No acceptance
criteria require specific dialogue content.

### 2026-03-01 — Complete PRD Final Lore Review

**From:** game-designer → **To:** lore-master

> Sent complete PRD (`game-designer/prd.md`) for final lore review.
> Highlighted era compliance section (Classic-Luclin lock maintained),
> no new lore/NPCs/factions/narrative content introduced, LLM soul/memory
> system unchanged (only fixing integration path), equipment slots match
> Titanium client (no post-Luclin slots).
>
> Requested sign-off on: lore concerns, era compliance, thematic issues
> with acceptance criteria.

**Response from** lore-master:

> APPROVED — lore-master completed review (task #2 marked completed).
> Bug fixes to existing companion systems with no narrative changes.
> Era compliance confirmed. No lore concerns.

**Outcome:** Lore sign-off recorded. PRD approved for handoff to architect.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Bug-fix PRD approved with no lore concerns | game-designer, lore-master | 2026-03-01 | Pure technical fixes, no narrative changes, era compliance confirmed |
| 2 | Bug 1 framed as routing failure, not content failure | game-designer, lore-master | 2026-03-01 | Lore-master confirmed cultural voice system (companion_culture.lua) must be preserved; fix is about sidecar connectivity, not dialogue |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| _None_ | | | |
