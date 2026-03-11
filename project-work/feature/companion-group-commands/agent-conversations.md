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

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| !equipmentupgrade response: static vs LLM-routed | lore-master flagged, architect to decide | Deferred to architecture phase | No |
