# Companion Rez — Agent Conversations Log

> **Feature branch:** `bugfix/companion-rez`
> **Created:** 2026-04-27

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

### 2026-04-27 — Early Lore Consult: Companion Auto-Rez Concept

**From:** game-designer → **To:** lore-master

> Kicked off the design phase for the `companion-rez` bugfix. Surfaced the
> locked invariant verbatim ("When we end a fight and one of my NPC companions
> falls, the Cleric NPC companion should be able to rez the party member.
> This is currently broken.") and the Classic-Luclin era lock. Asked four
> questions: (1) era-compliance for Cleric companions auto-rezzing,
> (2) thematic concerns with NPC companions being rezzable targets,
> (3) flavor messaging on auto-rez, (4) deity-specific edge cases (e.g.,
> should an Erudite Cleric of Quellious refuse to rez a Troll). Flagged my
> position that no deity-based restrictions should apply — UX pain for
> 1-3 player groups, not enforced in Classic mechanics.

**Response from** lore-master:

> APPROVED — Cleric auto-rez is lore-clean. Resurrection is a defining
> Classic-launch Cleric ability — every Cleric regardless of race or deity
> has rez as core class identity. No lore or faction constraint blocks rez
> on fallen party members. NPC companions as rez targets is thematically
> fine.
>
> Era compliance — in-scope Cleric spells: Resurrection (lvl 15),
> Reanimation (lvl 29), Revive (lvl 43), Resuscitate (lvl 53) — all
> Classic; Restoration (lvl 65) — Luclin, within era lock.
>
> **HARD STOP — Shaman rez:** Shamans do NOT receive a resurrection spell
> in Classic-Luclin. Any future expansion of auto-rez to Shaman companions
> must be blocked as an era violation.
>
> **Conditional — Necromancer rez:** in-era but mechanically distinct
> (shard corpse / XP penalty). Out of current scope; if ever added must
> reflect the distinction.
>
> Druid Reincarnation (lvl 52, Classic) and Paladin Revive (lvl 44, Kunark)
> are in-era options if future scope expands. Undead-companion edge case
> is game logic, not lore.
>
> Lore-master requested transcription of these findings into lore-notes.md
> (lore-master lacks Write tool). Will sign off formally after reviewing
> the complete PRD draft.

**Outcome:** Lore-master gave unconditional early approval. Three findings
folded into PRD: (1) corrected Cleric spell list in Era Compliance section,
(2) added Shaman HARD STOP note in Era Compliance + Non-Goals, (3) added
Necromancer / Druid / Paladin notes as future-scope flags in Non-Goals.
Findings transcribed to
`/mnt/d/Dev/eq/claude/project-work/companion-rez/lore-master/lore-notes.md`
on lore-master's behalf. Decisions table in this log updated.

---

### 2026-04-27 — Lore-Master Detailed Answers to Four Questions

**From:** lore-master → **To:** game-designer

> Detailed answers to the original four-question consult:
> (1) Era compliance: APPROVED — all Cleric rez spells are Classic-era.
> (2) NPC companions as rez targets: APPROVED — companion fiction
>     supports raisable NPCs, no lore objection.
> (3) Flavor lines on auto-rez: OPTIONAL / out of scope. Silent is fine.
>     Clerics in EQ don't narrate every spell. Don't require a flavor
>     line for this fix.
> (4) Deity-specific rez refusal: AGREED — NO enforcement. Classic
>     mechanics never gate rez on alignment/deity. Enforcing it would
>     be an invented restriction with zero lore payoff.
>
> Reinforced: Shaman rez is a permanent HARD STOP for any future scope
> (Shamans have no rez in Classic-Luclin). Architect should not assume
> "healers ≈ rezzers."

**Response from** game-designer:

> Acknowledged. Folded the flavor-line answer into Open Question #5
> (now RESOLVED in PRD) and into Out-of-Resources Behavior section
> (removed "or chat message" hedge). Shaman HARD STOP was already
> locked in PRD + Non-Goals + Era Compliance + lore-notes.md from
> the earlier consult. Sending revised PRD for final sign-off.

**Outcome:** Open Question #5 (Cleric OOM flavor) RESOLVED — silent /
no chat output. PRD updated. Sending revised draft for formal final
sign-off.

---

### 2026-04-27 — Full PRD Draft for Sign-Off (FINAL APPROVED)

**From:** game-designer → **To:** lore-master

> Sent full PRD draft for review and sign-off. Called out lore-relevant
> sections: Era Compliance (corrected Classic Cleric progression per
> earlier consult — Resurrection 15 / Reanimation 29 / Revive 43 /
> Resuscitate 53 / Restoration 65); Goals + Player Flow (Cleric does
> what a Cleric does, no deity restrictions); Open Question #5 (silent
> vs. flavor line on Cleric OOM); Open Question #6 (quest-NPC rez edge
> case carried forward as architect-awareness); Scenario E (Cleric down
> → graceful no-op). Held the line on no-deity-restriction.

**Response from** lore-master:

> APPROVED — no lore concerns. PRD is clear to hand off to architecture.
>
> Era compliance: APPROVED. Spell roster within Classic-Luclin lock.
> Goals + Player Flow: APPROVED. "Cleric does what a Cleric does" is
> the right framing.
> NPC companions as rez targets: APPROVED — companion-fiction framing
> is sound.
> No deity-based rez restrictions: CONFIRMED. Hold the line.
> Scenario E (Cleric down): APPROVED. Documenting as graceful expected
> behavior is correct.
> Open Question #5: silent is correct (more in keeping with EQ NPC
> terseness; flavor line can be added in a future polish pass).
> Open Question #6: correct framing — architect-awareness flag, not a
> scope expansion. No lore dimension.
> Shaman HARD STOP: already locked in PRD. No further action needed
> from game-designer unless wanting an explicit note to Non-Goals
> (already there).
>
> **Final verdict: APPROVED. No revisions required. Pass to architecture.**

**Outcome:** PRD is APPROVED. Status header updated to "APPROVED —
lore-master signed off 2026-04-27." Design phase is complete pending
status.md update + commit/push. Ready for handoff to architect.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

_(Not yet started.)_

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

_(Not yet started.)_

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | No deity-based restrictions on Cleric rez targets (e.g., a Cleric of Quellious rezzing a Troll is allowed) | game-designer + lore-master | 2026-04-27 | CONFIRMED by lore-master: not enforced in Classic mechanics; rez is core Cleric identity regardless of race/deity |
| 2 | Default to SILENT Cleric OOM behavior; no flavor chat line unless lore-master requests one | game-designer (proposed) | 2026-04-27 | Avoids chat spam; awaiting lore-master review on full PRD |
| 3 | Shaman rez is a permanent HARD STOP for any future scope expansion | lore-master | 2026-04-27 | Shamans have no rez spell in Classic-Luclin; era violation if added |
| 4 | Necromancer rez flagged as conditional, NOT included in this fix's scope | lore-master | 2026-04-27 | In-era but mechanically distinct (shard corpse / XP penalty); current fix is Cleric-only |
| 5 | Corrected Cleric spell progression in Era Compliance: Resurrection (15) / Reanimation (29) / Revive (43) / Resuscitate (53) / Restoration (65) | lore-master | 2026-04-27 | Replaces game-designer's initial draft list; ensures era accuracy |
| 6 | Cleric OOM behavior is silent — no flavor chat output as part of this fix | lore-master | 2026-04-27 | More in keeping with EQ NPC terseness; polish pass may add a one-time line later |
| 7 | PRD FINAL APPROVED for handoff to architecture | lore-master | 2026-04-27 | No revisions required; era + thematic + design coherence all confirmed |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| Lore-master initial consult (era, NPC rezzability, flavor, deity edge cases) | game-designer ↔ lore-master | RESOLVED 2026-04-27 — APPROVED with Shaman HARD STOP folded into PRD | No |
| Full PRD review for sign-off | game-designer ↔ lore-master | RESOLVED 2026-04-27 — FINAL APPROVED, no revisions required | No |

