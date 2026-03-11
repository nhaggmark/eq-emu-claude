# Companion Group Commands — Lore Master Dev Notes

> **Feature branch:** `feature/companion-group-commands`
> **Author:** lore-master
> **Date:** 2026-03-11

---

## Feature Concept

9 new group chat commands for managing NPC companions: !status, !buffme, !buffs, !tome, !flee, !assist, !help, !equipmentupgrade, !equipmentmissing, plus !follow via group chat. All mechanical — no new NPC dialogue, faction references, or named content. Lore review focused on era compliance, feedback message tone, and companion characterization consistency.

---

## Lore Research

This feature introduces no new world content (no zones, NPCs, factions, or quest text). Lore research focused on:

1. **Era lock verification** — confirmed all stat categories and spell types in the design are Classic-era.
2. **Companion culture system** — reviewed `companion_culture.lua` in full to understand existing racial/cultural framing constraints that could affect companion responses.
3. **Existing command tone** — reviewed `companion.lua` for established feedback message style.

**Key constraint carried forward:** If `!equipmentupgrade` responses are ever routed through the LLM sidecar (rather than static formatted output), racial voice constraints from `companion_culture.lua` apply. Specifically: Ogres cannot produce analytical stat-comparison lines. This is flagged to the architect.

---

## Era Compliance Review

| Element | Era | Compliant? | Notes |
|---------|-----|------------|-------|
| /gsay group communication | Classic | Yes | Existed since launch |
| /assist command pattern | Classic | Yes | Classic group mechanic |
| SpellType_Buff / SpellType_PreCombatBuff | Classic | Yes | Standard spell type system |
| Stat formula: AC + STR + STA + AGI + DEX + WIS + INT + CHA + HP + Mana | Classic | Yes | All Classic-era stats, no heroic stats or AA |
| companion_spell_sets era lock | Classic-Luclin | Yes | Pre-existing constraint, unchanged by this feature |
| Sebilis scenario zone | Kunark | Yes | Within era lock |
| The Hole scenario zone | Classic | Yes | Within era lock |

**Hard stops:** None. No era violations found.

---

## PRD Section Reviews

### Review: Full PRD — 2026-03-11

- **Verdict:** APPROVED
- **Approved items:**
  - Era Compliance section: accurate and complete
  - !flee hate retention: lore-correct (Norrath mobs pursue, running does not clear hate)
  - !assist auto-stance-switch: lore-neutral, pragmatically correct
  - !buffme/!buffs caster-only restriction: correct (warriors/rogues don't cast buffs in Norrath)
  - !status output format: "Mana: N/A" for pure melee is accurate for Classic EQ
  - !help category organization: logical, no lore concerns
  - Feedback message tone: terse, functional, matches EQ's style
  - Named NPCs in examples (Guard Iskarr, Priestess Astrid, Scout Verin): illustrative placeholders, no conflict with canonical lore characters
- **Issues found:** None blocking.
- **Suggestions offered:**
  - Flag for architect: `!equipmentupgrade` responses in the UX section show companion dialogue with stat scores (e.g., "stat sum: 45 vs 12"). If these are static formatted output, no concern. If routed through the LLM sidecar, racial voice constraints apply — Ogres cannot produce analytical stat-comparison sentences. Architect should clarify the implementation path and add a note to architecture doc if LLM routing is ever considered.

---

## Decisions & Rationale

| # | Decision | Rationale | Alternatives Rejected |
|---|----------|-----------|----------------------|
| 1 | !flee hate retention APPROVED as lore-correct | EQ mobs pursue their enemies; clearing hate on flee would be unrealistic and would trivialize encounters | Clearing hate would contradict authentic Norrath combat behavior |
| 2 | Feedback messages as static system output (not LLM) APPROVED | Commands need reliable, consistent responses; personality-driven responses via LLM would be slower and could produce inconsistent tone | LLM routing flagged as a future concern only if `!equipmentupgrade` dialogue is ever changed |

---

## Final Sign-Off

- **Date:** 2026-03-11
- **Verdict:** APPROVED
- **Summary:** The companion-group-commands PRD is era-clean, mechanically sound, and consistent with EQ's design philosophy and the existing companion culture system. All 9 commands operate at the gameplay layer with no new world content, faction references, or post-Luclin material. The one item to watch during implementation is whether `!equipmentupgrade` responses are static formatted output or LLM-routed dialogue — if the latter, Ogre voice constraints prohibit analytical stat-comparison sentences. This is an architect concern, not a PRD revision.
- **Remaining concerns:** None blocking. Architect flag on `!equipmentupgrade` response routing.

---

## Context for Next Phase

**For the architect and implementation team:**

1. All command feedback messages should be static formatted output, not LLM-routed. The terse, informational tone of the PRD examples is correct. Do not add personality to these messages.

2. If `!equipmentupgrade` response text is ever considered for LLM routing, the racial voice constraints in `companion_culture.lua` must be applied. Specifically: Ogres produce 1-2 word responses only ("Oog no fit"), not analytical stat comparisons. Mercenaries use cold/transactional language. This is a future concern, not current scope.

3. The !flee hate-retention design is intentional and lore-correct. Do not "fix" it by adding hate clearing.

4. Era lock holds. No new spell types, stat categories, or item properties needed.
