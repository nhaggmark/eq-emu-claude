# Companion Audit Pass 2 — Agent Conversations Log

> **Feature branch:** `feature/companion-audit-pass2`
> **Created:** 2026-03-15

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

### 2026-03-15 — companion_spell_sets priority semantics (CRITICAL BLOCKER)

**From:** c-expert → **To:** data-expert

> Sent full analysis of AICastSpell priority semantics after reading companion_ai.cpp.
> Key findings:
> - `ORDER BY priority ASC` + sequential slot assignment means priority=1 is slot 0
> - `GetSpellsForType()` sorts by slot ascending, all selectors pick first match
> - **Result: priority=1 = HIGHEST PRIORITY (checked first). OPPOSITE of npc_spells_entries.**
> - Cleric heals at priority=20 are checked LAST — damage at priority=1 always fires first
> - Shaman heals at priority=1 are correct by accident (already highest priority)
> - Recommended priority scheme for companion_spell_sets: heals=1, cures=2, debuffs=5, buffs=8, damage=10+

**Outcome:** data-expert unblocked to apply companion_spell_sets priority fixes using correct semantics.

### 2026-03-15 — data-expert self-correction: initial cleric fix was wrong

**From:** data-expert (self-correction after c-expert response)

> Initial cleric companion_spell_sets fix set Complete Heal to priority=50 (WRONG — lowest priority,
> checked last). After c-expert confirmation, reverted all cleric heals back to priority=1 and
> bumped all offensive spells from priority=1 to priority=30. The correct fix was the OPPOSITE
> of what was initially applied.

**Outcome:** Reverted and reapplied. All 12 spellcasting classes updated. All 16 validation tests PASS.

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | `companion_spell_sets` priority=1 means HIGHEST priority (checked first). Opposite of `npc_spells_entries`. | c-expert → data-expert | 2026-03-15 | Data-expert was blocked on priority direction before applying companion_spell_sets fixes. |
| 2 | Constructor call order: ScaleStatsToLevel() → ApplyStatScalePct() → CalcBonuses(). ApplyStatScalePct must come AFTER ScaleStatsToLevel or the % scale is overwritten. | c-expert | 2026-03-15 | NEW-03 fix — fresh companions had homogeneous stats until first level-up. |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| | | | |
