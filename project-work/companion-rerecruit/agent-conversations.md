# Companion Re-recruitment Fix — Agent Conversations Log

> **Feature branch:** `bugfix/companion-rerecruit`
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

### 2026-04-27 — Lore touchpoint: re-recruit invariant + Lydl the Great

**From:** game-designer → **To:** lore-master

> Drafting PRD for `companion-rerecruit` (BUG-001). Bug is mechanical: re-recruiting a previously-recruited NPC is blocked by level caps, cooldown timers, and a stale "dismissed" flag. User invariant: "Once I recruit a companion, I should always be able to re-recruit that companion after they die or otherwise drop out of the group. They become re-recruited with their gear and levels intact. There should be no rules around levels on re-recruiting companions. The idea is that I can recruit an NPC at level 5 and take them through the entire game with me."
>
> Asked lore-master two questions before sending full PRD for sign-off:
> 1. Lydl the Great (East Freeport) — anything in his lore (faction, deity, race, role, allegiances) that makes him a poor exemplar for a "follow the player from level 5 to 60+" companion arc?
> 2. Does the invariant itself ("an NPC can be recruited once and re-recruited indefinitely after death/dismissal, gear and level preserved") carry narrative landmines across Norrath at large — e.g., guards-with-jobs vanishing from their post needing flavor handling?

**Response from** lore-master:

> APPROVED — no lore blockers. Detailed findings:
>
> **Lydl the Great:** Level 4 human wizard, wandering "insane" Innoruuk-corrupted figure in North Ro / East Freeport. No stable city role, no home faction, no quest-giver function — framed as a hostile/kill target. Killing him helps Knights of Truth and hurts Dismal Rage / Opal Dark Briar. The companion system has never filtered by deity affiliation; cleared as repro NPC. **Edge case noted:** Lydl is himself a kill target in the Lydl Mastat Freeport wizard-guild quest — re-recruit of a quest kill-target may interact oddly with quest state. Flagged for architect.
>
> **Re-recruit invariant at Norrath scale:** Approved, no era-compliance issues. NPC level is a game abstraction, not narrative; NPC death/respawn was never canonized in EQ fiction; the companion system is a custom feature with no in-world fiction. Two flavor-level landmines worth one sentence each in the PRD (NOT design changes):
>   - Landmine A — NPCs with functional world roles (guards/merchants/quest-givers) vanishing from their post. Same fiction break vanilla EQ already has via static respawn. Suggest one sentence in PRD lore section.
>   - Landmine B — Quest-chain NPCs mid-quest. Mechanical edge case, not a lore constraint. Flag for architect to evaluate.

**Outcome:** Lore-master initial review APPROVED. Two flavor-level edge cases folded into PRD:
1. Static-respawn fiction note added to Era Compliance section.
2. Quest-chain NPC edge case (incl. Lydl Mastat) added to Open Question #1 and as new acceptance criterion AC-10.
Lore-notes.md transcribed and updated. Full PRD draft sent to lore-master for formal sign-off; awaiting response.

---

### 2026-04-27 — Full PRD draft sent for formal sign-off

**From:** game-designer → **To:** lore-master

> Full PRD draft (with all lore-master findings incorporated as of initial review) sent for formal sign-off. Asked lore-master to confirm two specifics: (1) Cyrla the Healer is a generic example name, flag if real EQ NPC with conflicting lore; (2) Sebilis as a death-location flavor reference creates no faction/race conflict. Asked for APPROVED / REVISE / specific changes verdict.

**Response from** lore-master:

> **APPROVED WITH MINOR NOTE.** Verdict 2026-04-27.
>
> - Lydl the Great (Scenario A): APPROVED — confirmed level 4 human wizard, East Freeport, no stable world role, no lore conflict.
> - **Cyrla the Healer (Scenario B): NAME FLAG.** "Cyrla" collides with Cyrla Shadowstepper, a real EQ NPC (level 61 Rogue guild master, Highpass Hold — emphatically not a healer). Recommended rename to a generic invented name like "Mira the Healer" to avoid noise for architect/implementation. Not a sign-off condition.
> - Sebilis (Scenario C): APPROVED — Kunark-era zone, neutral dungeon, no alignment/faction conflict.
> - Era Compliance section: APPROVED as written. Nothing post-Luclin.
>
> Final verdict: APPROVED. PRD may proceed to commit.

**Outcome:** Lore-master signed off APPROVED 2026-04-27. Cyrla rename recommendation applied: "Cyrla the Healer" → "Mira the Healer" in Scenario B (zero-cost, removes collision noise). Final sign-off block appended to lore-notes.md. PRD status bumped to APPROVED. Cleared to commit and hand off to architect.

---



---


## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### [Date] — [Topic]

**From:** [agent] → **To:** [agent]

> [Message content or summary]

**Response from** [agent]:

> [Response content or summary]

**Outcome:** _What was decided or changed as a result_

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
| 1 | Lore review APPROVED — companion re-recruit invariant has no lore blockers; two edge cases (static-respawn fiction note, quest-NPC interaction) folded into PRD as flavor notes for architect awareness | game-designer, lore-master | 2026-04-27 | Mechanical bugfix; companion system is a custom feature with no in-world fiction |
| 2 | Rename "Cyrla the Healer" → "Mira the Healer" in Scenario B | game-designer, lore-master | 2026-04-27 | Cyrla collides with real EQ NPC Cyrla Shadowstepper (level 61 Rogue, Highpass) — generic invented name removes noise for downstream readers |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| | | | |
