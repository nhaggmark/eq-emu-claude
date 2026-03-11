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

---

## Implementation Audit — 2026-03-11

### Files Reviewed
- `akk-stack/server/quests/lua_modules/companion.lua` (full — group commands section lines 599–1156)
- `akk-stack/server/quests/global/global_npc.lua`
- `akk-stack/server/quests/lua_modules/companion_culture.lua`

### Audit Results

| Area | Rating | Notes |
|------|--------|-------|
| Era compliance | PASS | No post-Luclin content anywhere in new code |
| !equipmentupgrade routing | PASS | Static formatted output confirmed; LLM sidecar not used; racial voice constraints not triggered |
| !flee hate retention | PASS | No WipeHateList call; lore-correct per Norrath combat behavior |
| Ogre voice constraints | PASS | N/A — all command responses are static system output, not LLM dialogue |
| Mercenary voice constraints | PASS | !balanced correctly returns "Understood." for mercenary type (companion_type==1) |
| Iksar/Vah Shir/Erudite constraints | PASS | No city, faction, or cultural references in new code |
| Dialogue tone | PASS | Terse, functional, era-appropriate throughout |
| Pre-existing recruitment lines | PASS WITH NOTES | Ogre saying "I will join you." is slightly verbose for the race; pre-existing issue outside this feature's scope |

### Key Findings

1. **!equipmentupgrade** (lines 1033–1150): Confirmed static string formatting only. Output format is `[name]: [new_item] (score: N) is an upgrade over [cur_item] (score: N) in my [slot] slot.` The companion name is a label prefix, not voiced dialogue — consistent with EQ system output conventions. Racial voice constraints from `companion_culture.lua` do not apply.

2. **!flee** (lines 856–877): Comment on line 856 explicitly states hate list retention is intentional and lore-correct. Implementation calls `SetStance(0)`, `SetGuardMode(false)`, `RunTo()` — but NOT `WipeHateList()`. Correct. Compare to `!passive` (line 491) which does call `WipeHateList()`. The distinction is correct per lore.

3. **!buffme / !buffs** (lines 941–987): SpellType_Buff=8 and SpellType_PreCombatBuff=1048576 constants are era-appropriate. Caster-only restriction implemented via `GetMaxMana() == 0` check. Correct for Classic EQ (warriors/rogues have 0 max mana).

4. **!status** (lines 600–694): "Mana: N/A" for pure melee companions (line 623). Correct for Classic EQ.

5. **Recruitment lines** (lines 456–459): `npc:Say("I will join you.")` applies to all races uniformly. An Ogre speaking this line is slightly verbose — Ogre vocabulary should be 1-2 words per `companion_culture.lua`. This is pre-existing code outside this feature's scope. Flagged for future lore refinement if desired; not blocking.

### Final Sign-Off

- **Date:** 2026-03-11
- **Verdict:** APPROVED
- **Summary:** Implementation is era-clean, tone-correct, and respects all established companion culture constraints. The primary concern from the PRD review — whether !equipmentupgrade would use the LLM sidecar — is resolved: it does not. All nine new commands use static formatted output only. No lore violations found in scope.
- **Out-of-scope note:** Ogre recruitment line verbosity is a pre-existing issue; track separately if desired.
