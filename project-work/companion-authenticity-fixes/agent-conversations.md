# Companion Authenticity Fixes — Agent Conversations Log

> **Feature branch:** `feature/companion-authenticity-fixes`
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

### [Date] — [Topic]

**From:** [agent] → **To:** [agent]

> [Message content or summary]

**Response from** [agent]:

> [Response content or summary]

**Outcome:** _What was decided or changed as a result_

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

### 2026-03-14 — c-expert completion report to team-lead

**From:** c-expert → **To:** team-lead

> All 5 C++ tasks complete (GAP-01/02/03/04/06). Implemented crit guard fix,
> PC-only spell targeting, defensive skills from SkillCaps, class-based stat
> multipliers in ScaleStatsToLevel(), and unarmed damage override.
> Suite 19 added (10 tests). All 19 suites pass. Committed to eqemu + claude repos.

**Outcome:** Implementation phase complete for c-expert deliverables.

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Companions bypass NPC crit guard via !IsCompanion() in TryCriticalHit() | c-expert | 2026-03-14 | GAP-01 |
| 2 | spells.cpp:3940 AE path already handled via IsOfClientBotMerc(); only single-target (832) and cone (entity.cpp:5616) needed fixing | c-expert | 2026-03-14 | GAP-02 |
| 3 | Use SkillCaps::Instance()->GetSkillCap() for all defensive skills — same approach as Bot | c-expert | 2026-03-14 | GAP-03 |
| 4 | HP/mana not re-derived from stat multipliers — preserved through CalcMaxHP/CalcMaxMana overrides | c-expert | 2026-03-14 | GAP-04 |
| 5 | Unarmed base = level/5+2 (scales with level); multiplied by class archetype factor | c-expert | 2026-03-14 | GAP-06 |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| | | | |
