# Companion Recruitment & Re-recruitment Overhaul — Agent Conversations Log

> **Feature branch:** `feature/companion-recruitment-overhaul`
> **Created:** 2026-03-14

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

### 2026-03-14 — Lore Review: Recruitment Narrative Framing (Initial)

**From:** game-designer → **To:** lore-master

> Requested review of narrative framing for two-track recruitment system:
> 1. First-time recruitment: "getting to know you" — persuasion roll, faction,
>    level proximity. Stays as-is.
> 2. Re-recruitment after death/dismissal: "I remember you" — companion already
>    knows the player. No cooldown, no level restriction, no persuasion roll.
>    Companion willingly rejoins based on established relationship.
> 3. Death flavor text: "I remember you. Let us continue." (already in code).
>
> Asked: Does this fit Classic-Luclin lore? Any era-specific reasons a companion
> would NOT rejoin? Is "instant rejoin" framing sufficient?

**Response from** lore-master:

> Task #2 (Lore review of recruitment overhaul PRD) marked COMPLETED.
> No lore issues flagged. Approval granted via task completion.

**Outcome:** Lore sign-off recorded. Narrative framing approved.

### 2026-03-14 — Lore Review: Full PRD Final Review

**From:** game-designer → **To:** lore-master

> Sent full PRD lore-relevant sections for final review:
> - Era compliance assessment (custom feature, no expansion-specific content)
> - "I remember you" narrative framing for re-recruitment
> - Dismissal/death flavor text
> - Balance justification (narrative: companion has proven loyalty)
>
> Asked for sign-off on: era compliance, narrative framing, any lore concerns.

**Response from** lore-master:

> APPROVED — Task #2 marked completed. No lore concerns raised.
> The "I remember you" framing is consistent with Classic-era NPC memory
> conventions (faction-based recognition, quest completion tracking).

**Outcome:** Lore sign-off confirmed. PRD finalized without lore changes.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

_(Not yet started — pending PRD handoff to architect)_

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

_(Not yet started — pending architecture phase)_

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Two-track recruitment: first-time (full checks) vs re-recruitment (all checks bypassed except safety) | game-designer, lore-master | 2026-03-14 | Lore-master approved narrative framing |
| 2 | "I remember you. Let us continue." dialogue for re-recruitment is era-compliant | game-designer, lore-master | 2026-03-14 | Consistent with Classic-era NPC memory |
| 3 | No cost or delay on re-recruitment — natural friction (travel, lost buffs) is sufficient | game-designer | 2026-03-14 | Balance consideration for 1-3 player server |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| (none) | | | |
