# Companion Bug Batch 3 — Agent Conversations

> **Feature branch:** `bugfix/companion-bug-batch-3`

---

## Implementation Team

### team-lead → c-expert (initial dispatch)

**Date:** 2026-03-16

Dispatched c-expert with three bug assignments:
- BUG-033: PET_GETLOST charm guard blocks charm-break
- BUG-032: Companion spawns inherit immunity abilities that block DS
- BUG-034: Companion mana regen slow (diagnose then fix)

Provided architecture plan, bug reports, and files/line references.

---

### c-expert → team-lead (completion report)

**Date:** 2026-03-16

Implementation complete. Summary of findings:

**BUG-033:** Confirmed `client_packet.cpp:11319` has `if (mypet->Charmed()) break;` that blocks the charm-break path. Removed guard. Charm pets now reach `BuffFadeByEffect(SpellEffect::Charm)`.

**BUG-032:** Confirmed DB has NPCs (e.g., Crysta_Tagglefoot npc_id=33164) with `special_abilities` including abilities 22, 23, 35 in addition to 19/20. Added 6 additional `SetSpecialAbility(..., 0)` calls in `Spawn()`.

**BUG-034 diagnosis:**
- SkillMeditate IS correctly initialized — skill_caps DB has entries for skill_id=31 for all caster classes (I initially looked up wrong skill_id=32 which is something else). Wizard at level 35 gets meditate=200 from DB cap.
- Character:ManaRegenMultiplier=175, CompanionManaRegenMult=100. Formula produces ~26/tick at level 35.
- Added periodic diagnostic logging (first tick + every 300 ticks) to confirm Clarity spellbonuses apply in-game.
- Side note: Bard CalcManaRegen path (line 1411) is missing `spellbonuses.ManaRegen` — potential future bug.

Tests: Suites 31, 32, 33 added. All 33 suites pass, zero regressions.
Commits: `19c9abddd` (BUG-033), `627aed644` (BUG-032 + BUG-034 diagnostic)
Pushed to `bugfix/companion-bug-batch-3`.
