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

> Full analysis from companion_ai.cpp:
> - `LoadCompanionSpells()` queries `ORDER BY priority ASC, id ASC` — priority=1 rows come first
> - Each row assigned sequential `slot` counter (0, 1, 2...) on insertion into `m_companion_spells`
> - `GetSpellsForType()` sorts by `a.slot < b.slot` (ascending). Comment at line 117: "lower slot = higher priority in DB"
> - All selectors (`SelectHealSpell()`, `SelectFirstSpell()`, etc.) iterate front-to-back and return FIRST eligible spell
> - **CONFIRMED: priority=1 = HIGHEST PRIORITY (checked first). OPPOSITE of npc_spells_entries.**
> - Cleric heals at priority=20 are checked LAST — damage at priority=1 always fires first
> - Shaman heals at priority=1 are correct by accident (already highest priority)
> - Recommended scheme: heals=1, cures=2, debuffs=5, buffs=8, damage=10+
> - AI handles healer-vs-DPS routing via class-specific methods (AI_Cleric, AI_Shaman etc.) — priority within a spell type determines WHICH spell is selected when multiple options exist

**Outcome:** data-expert applied all fixes using confirmed semantics. All 16 validation tests PASS.

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
