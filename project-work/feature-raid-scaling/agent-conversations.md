# Raid Scaling — Agent Conversations Log

> **Feature branch:** `feature/raid-scaling`
> **Created:** 2026-04-21

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

### 2026-04-21 — Kick-off and task assignment

**From:** game-designer → **To:** lore-master

> Welcome message: framed the audit scope, assigned tasks #7-10
> (Classic / Kunark / Velious / Luclin quest-chain catalogs), pointed at
> feature brief, status.md, and the prior small-group-scaling PRD in
> `claude/tmp/raid-scaling/prior-prd.md`. Shared the crucial finding:
> prior scaling pass excluded `raid_target = 1` NPCs, so raid boss HP /
> damage / AC are at default PEQ values — that's the gap this project
> addresses. Asked lore-master to begin raw research on the 14 Epic 1.0
> quests while I finish the skeleton document.

**Response from** lore-master:

> _Pending — response will be logged here when received._

**Outcome:** Lore-master dispatched to research quest-chain progression.
Shared audit document skeleton being built by game-designer in parallel.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

_(Empty — architecture phase has not started.)_

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

_(Empty — implementation phase has not started.)_

---

## Key Decisions from Conversations

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Audit structure: one consolidated document (`raid-scaling-audit.md`) with per-era sections, bosses before quest chains in each era, cross-reference matrix and headline findings at the end | game-designer | 2026-04-21 | Single document keeps context together for architect in Phase 3; per-era splits were considered but rejected as fragmenting — can split later if size becomes unwieldy |
| 2 | Classification: `raid_target = 1` flag in PEQ is over-inclusive (includes raid-zone trash like Plane of Fear scarelings). Audit classifies each as BOSS / EVENT MOB / ELITE TRASH. Only BOSS + some EVENT MOB entries target for scaling | game-designer | 2026-04-21 | Flag count of 878 raid_targets across Classic-Luclin is dominated by trash-in-raid-zones; true boss count is a fraction of that |
| 3 | Fabled (`#The_Fabled_*`) NPCs at level 70+ flagged as OUT OF ERA, no action | game-designer | 2026-04-21 | Post-Luclin anniversary content; expansion lock should prevent them from spawning |

---

## Unresolved Threads

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| | | | |
