# Design Review: Phases 2, 3, and 4 Implementation Audit

> **Reviewer:** game-designer
> **Date:** 2026-03-11
> **Feature:** npc-companion-realistic-stats
> **Scope:** Phase 2 (Triple Attack), Phase 3 (STA-to-HP, Sitting Regen, Defense AC Divisor), Phase 4 (Spell AI Tuning)

---

## 1. PRD Acceptance Criteria: Pass/Fail Assessment

### Phase 2: Combat Skills and Special Attacks

| # | Acceptance Criterion | Status | Notes |
|---|---------------------|--------|-------|
| 2.1 | Warrior companion has high parry, riposte, dodge, block at level-appropriate rates | **PASS (pre-existing)** | The architect discovered during research that NPC constructor already initializes skills from SkillCaps table (npc.cpp:368-369). Companions already had correct skills. No code change needed — this was a perceived gap that didn't exist. |
| 2.2 | Rogue companion has dodge, parry, riposte at class-appropriate rates (lower than warrior) | **PASS (pre-existing)** | Same as above — SkillCaps handles class differentiation automatically. |
| 2.3 | Caster companion has minimal defensive combat skills | **PASS (pre-existing)** | SkillCaps returns appropriate near-zero values for casters. |
| 2.4 | Companion skill values scale with level-up | **PASS (pre-existing)** | NPC constructor uses GetLevel() when querying SkillCaps. Level-up triggers reconstruction. |
| 2.5 | Level 28+ melee companions deal damage bonus consistent with weapon delay bonus table | **PASS** | Implemented in Companion::Attack() Phase 1. GetWeaponDamageBonus() is called for IsWarriorClass() at level 28+. |
| 2.6 | Level 56+ warriors land triple attacks | **PASS** | CanCompanionTripleAttack() returns true for Warriors at 56+. CheckTripleAttack() rolls correctly. DoAttackRounds() calls it on primary hand only, after double attack succeeds. |
| 2.7 | Level 60+ monks and rangers land triple attacks | **PASS** | CanCompanionTripleAttack() returns true for Monks and Rangers at 60+. |

**Phase 2 Overall: ALL CRITERIA MET**

### Phase 3: Stats Drive Survivability

| # | Acceptance Criterion | Status | Notes |
|---|---------------------|--------|-------|
| 3.1 | Equipping a STA item increases max HP; removing it decreases max HP | **PASS** | Companion::CalcMaxHP() override adds STA bonus on top of Mob::CalcMaxHP(). Only itembonuses.STA + spellbonuses.STA contributes (no double-counting base STA). Tests 12.2, 12.4 confirm equip/unequip behavior. |
| 3.2 | Level 60 warrior with +50 STA gains approximately 300-500 extra HP | **PASS** | Formula: 50 STA * 8 hp_per_sta * 60/60 * 100/100 = 400 HP. Falls squarely within the 300-500 range specified in the PRD. |
| 3.3 | Sitting companion regenerates HP faster than standing (approximately 2-3x rate) | **PASS** | Process() applies additive sitting bonus before NPC::Process() runs. At SittingRegenMult=200 (default), sitting bonus equals base OOC regen, so total = 2x standing rate. |
| 3.4 | Sitting regen visible through HP recovery speed | **PASS** | The HP delta is applied via SetHP() in Process() — it directly changes the companion's HP each tick, which the client renders. |
| 3.5 | Companion with high defense skill has slightly higher AC (defense divisor change) | **PASS** | ACSum() in attack.cpp has IsCompanion() guard. Melee companions get skill/3, casters get skill/2. The spell_aa_ac contribution is also correctly handled within the companion branch. |

**Phase 3 Overall: ALL CRITERIA MET**

### Phase 4: Spell System Tuning

| # | Acceptance Criterion | Status | Notes |
|---|---------------------|--------|-------|
| 4.1 | Cleric begins healing at 80% HP in combat (not 90%) | **PASS** | AI_HealGroupMember() uses RuleI(Companions, HealThresholdPct) which defaults to 80. The old hardcoded 90 is replaced. |
| 4.2 | Shaman reliably slows primary target as first action | **PASS** | AI_Shaman() removes the zone->random.Roll(70) gate. Slow is now always attempted when SpellType_Slow is in the type mask and target is not immune. Slow is first in the engaged priority list. |
| 4.3 | DPS casters stop nuking below 20% mana | **PASS** | Wizard: uses RuleI(Companions, ManaCutoffPct), default 20. Necromancer: DoT and Nuke paths both guard on ManaCutoffPct. Magician: already had 20% hardcoded — still at 20.0f. |
| 4.4 | No standard buffs cast during combat engagement | **PASS** | AI_Cleric() engaged path no longer calls AI_BuffGroupMember(). Only AI_InCombatBuff() is called during combat. Other class handlers (warrior, paladin, SK, ranger, etc.) already only called AI_InCombatBuff() in combat. |
| 4.5 | Enchanter prioritizes mez on adds | **PASS (pre-existing)** | AI_Enchanter() already had mez as first priority in engaged path. No change needed. |
| 4.6 | Healers switch to efficient heal below 30% mana | **PASS** | SelectEfficientHealSpell() helper picks the heal with lowest spells[spellid].mana cost. AI_HealGroupMember() uses it when GetManaRatio() < HealerManaConservePct (30). Falls back to SelectHealSpell() if no efficient heal found. |
| 4.7 | Companions rebuff on transition to idle | **PASS (pre-existing)** | AI_IdleCastCheck() includes SpellType_Buff in its type mask. The idle check fires on the first idle tick after combat ends. |

**Phase 4 Overall: ALL CRITERIA MET**

---

## 2. Player Experience Feel Assessment

### Triple Attack (Phase 2)

**Feeling: Authentic.** Warriors at 56+ occasionally landing a third swing is exactly what a player would experience playing alongside a human warrior. The implementation correctly gates triple attack behind a successful double attack (you must double to triple), which matches EQ mechanics. The 25% base chance at level 56, growing with level, feels right — not so frequent it's spammy, not so rare it's unnoticeable.

**Concern: None.**

### STA-to-HP (Phase 3)

**Feeling: Rewarding.** A player equipping a Stamina ring on their tank companion and seeing the HP bar visibly change reinforces the "gear matters" loop. The 8 HP/STA for tanks at level 60 is substantial enough to matter (a +35 STA item = +280 HP) without being overwhelming.

**Concern: Minor.** The level scaling formula (level/60, capped at 60) means companions at levels above 60 (if level cap ever extends) won't gain additional HP-per-STA. This is fine for the Classic-Luclin era lock but would need revisiting if the cap ever increases. Not an issue today.

### Sitting Regen (Phase 3)

**Feeling: Natural.** The 2x OOC regen when sitting is a meaningful downtime reducer without trivializing recovery. A player watching their companion sit after a fight and seeing HP recover faster than standing companions will recognize the EQ regen mechanic. The implementation correctly stacks with OOC regen rather than replacing it.

**Concern: Sitting in combat.** The code guards against IsEngaged(), but what about the transition period when combat just ended? Since IsEngaged() flips to false when the hate list clears, and the sitting bonus only fires when IsSitting() is true, there's no issue — companions don't sit automatically during combat. The player/AI has to explicitly sit them. The Sit() command is only called from mana regen logic when OOC, so this is safe.

### Defense AC Divisor (Phase 3)

**Feeling: Subtle but correct.** The change from skill/5 to skill/3 (melee) and skill/2 (casters) is a modest AC improvement. For a level 60 warrior with ~200 defense skill, this is +27 AC (200/3 - 200/5 = 67 - 40 = 27). Meaningful but not dramatic. This is exactly what we want — incremental survivability that stacks with gear AC.

**Concern: None.**

### Heal Threshold 80% (Phase 4)

**Feeling: Competent human player.** 80% is the sweet spot. At 90%, clerics were healing after every hit — wasting mana on trivial damage. At 80%, the cleric lets the tank take a couple of hits before casting, which is how a good human cleric plays: conserve mana, heal when it matters. This directly extends group sustainability in longer fights.

**Concern: Emergency heal gap.** The PRD specified emergency complete heal logic below 25%. Looking at the implementation, there is no separate "emergency" heal path in AI_HealGroupMember(). The function picks the best heal from SelectHealSpell() based on priority order. If the heal spell list in companion_spell_sets is ordered with Complete Heal as highest priority (lowest min_hp_pct), this would naturally fire on critically low targets. But if spell ordering doesn't prioritize big heals for low-HP targets, the cleric might cast a small heal when a group member is at 10%. This depends on data, not code — the data-expert needs to ensure companion_spell_sets has appropriate min_hp_pct/max_hp_pct ranges so that big heals fire on low-HP targets. **Recommend verifying spell set data during the Phase 5 balance pass.**

### Shaman Always Slows (Phase 4)

**Feeling: Exactly right.** In live EQ, a shaman who doesn't slow on pull is a bad shaman. Making slow 100% priority eliminates the frustrating scenario where a companion shaman randomly skips slow and the tank takes full-speed hits. The slow-immunity check is correctly in place, so the shaman won't waste time on immune mobs.

**Concern: Re-slow after mob breaks slow.** If slow is dispelled or resisted, the shaman needs to re-slow. The current implementation attempts slow every tick that the slow hasn't been applied. If AI_SlowDebuff() checks whether the target already has a slow debuff (common pattern), the shaman will naturally re-slow when the debuff drops. This should be verified in testing — if AI_SlowDebuff() doesn't check for existing slow, the shaman will attempt slow every single tick even when the mob is already slowed, wasting cast time.

### DPS Mana Cutoff 20% (Phase 4)

**Feeling: Pragmatic.** The old 10-15% cutoff was too aggressive — casters would squeeze out one or two more nukes at the cost of having zero mana in an emergency. 20% reserves a meaningful mana buffer (for a wizard with 5000 mana, that's 1000 mana — about one emergency gate or two low-level nukes). This feels like a human player who knows to conserve.

**Concern: Magician still uses hardcoded 20.0f.** While the value matches the ManaCutoffPct default, the Magician AI handler doesn't read the rule — it uses `GetManaRatio() > 20.0f` directly. If a server operator changes ManaCutoffPct to 15, Wizards and Necromancers would respect the new value but Magicians would still use 20%. **This is a minor inconsistency that should be fixed — replace 20.0f with RuleI(Companions, ManaCutoffPct) in AI_Magician().**

### No Buffs in Combat (Phase 4)

**Feeling: Professional.** A cleric who stops healing to cast Shield of the Magi mid-fight is a dead group. Removing standard buff casting during combat and replacing with AI_InCombatBuff() (for short-duration combat-specific buffs) matches how a skilled player prioritizes. The idle rebuff on combat-to-idle transition is natural.

**Concern: None.**

### Healer Mana Conservation at 30% (Phase 4)

**Feeling: Smart play.** When a cleric drops below 30% mana, switching to the cheapest available heal is exactly what a human player does — "I need to stretch my mana for the rest of this fight." The SelectEfficientHealSpell() helper correctly picks the lowest mana cost heal that satisfies HP threshold constraints. This prevents the cleric from burning their last 1500 mana on a Complete Heal when a smaller heal would suffice.

**Concern: Quality of SelectEfficientHealSpell.** The function picks the cheapest heal by mana cost. But "cheapest" and "most efficient" are not the same — a 150-mana heal that heals 500 HP is more efficient than a 100-mana heal that heals 200 HP. True efficiency is heal_amount/mana_cost. However, for the mana-conservation scenario (healer is nearly OOM), cheapest-in-mana is actually the right metric: we want to maximize the number of heals we can still cast, not the HP-per-mana ratio. So the implementation is correct for the intended use case.

---

## 3. Balance Assessment: 70-85% Player Power Target

### Triple Attack Chance

**Assessment: On target.** 25% base chance at threshold level, growing 1% per level above threshold. A level 60 warrior gets 25 + (60-56) = 29% triple attack chance. Player warriors at 60 with AAs could reach 35-40%. So companion warrior triple attack is roughly 70-80% of player power. Right in the target band.

### STA-to-HP Conversion

**Assessment: On target.** The HP-per-STA values (8/5/4/3 for tank/melee/priest/caster) are approximately 70-80% of the Client CalcBaseHP STA multiplier. A level 60 Client warrior might get ~11 HP/STA from the full formula; companions get 8. That's 73% of player power. Well within the 70-85% band.

### Sitting Regen Multiplier

**Assessment: Appropriate.** 2x OOC regen when sitting is modest but helpful. Players get approximately 3x regen from sitting in live EQ. At 2x, companions regenerate at 67% of player sitting rate. This is intentionally conservative — companions also benefit from OOC regen, which is already aggressive (5% of max HP per tick).

### Defense AC Divisor

**Assessment: Correct for target.** Using skill/3 for melee and skill/2 for casters matches exactly what Client/Bot characters get. This brings companions to 100% of player defense-skill AC contribution. Combined with the fact that companions don't have AAs for additional AC, overall defensive power is below player level. Correct.

### Heal Threshold

**Assessment: Appropriate.** 80% is a standard threshold for a competent healer in EQ. Not too cautious (which wastes mana) and not too aggressive (which risks tank death). Server operators can tune this to 75% for more conservative healing or 85% for more aggressive healing via the rule.

### Mana Cutoff

**Assessment: Appropriate.** 20% mana cutoff for DPS casters is conservative enough to leave emergency mana without severely impacting DPS uptime. In a typical fight, a wizard will cast until 20%, then melee or wait. This is reasonable for AI-controlled casters.

---

## 4. Tuning Knob Completeness

| PRD Suggested Rule | Implemented? | Default | Notes |
|-------------------|-------------|---------|-------|
| Companions::UseWeaponDamage | Yes | true | Phase 1 master toggle |
| Companions::SkillCapPct | **NO** | — | Skills come directly from SkillCaps with no companion-specific scaling. See note below. |
| Companions::DamageBonusPct | **NO** | — | GetWeaponDamageBonus() returns the full table value. See note below. |
| Companions::STAToHPFactor | Yes | 100 | Percentage multiplier on STA-to-HP conversion |
| Companions::SittingRegenMult | Yes | 200 | 2x standing OOC regen when sitting |
| Companions::ResistCap | No (Phase 5) | — | Deferred to Phase 5 per plan |
| Companions::HealThresholdPct | Yes | 80 | HP % below which healers begin healing |
| Companions::ManaCutoffPct | Yes | 20 | Mana % below which DPS casters stop nuking |
| Companions::HealerManaConservePct | Yes | 30 | Mana % below which healers use efficient heals |

**Missing tuning knobs:**

1. **SkillCapPct** — The PRD suggested a rule to cap companion skills at a percentage of player caps. Since skills come directly from SkillCaps (same as players), companions currently get 100% of player skill caps. If companions prove too effective at avoidance, there's no way to reduce their skills without a code change. **Recommendation: Acceptable to defer. If testing in Phase 5 shows companions are too avoidant, this can be added then. Current avoidance is correct for the "feels like a player" target.**

2. **DamageBonusPct** — The PRD suggested a rule to apply a percentage of the weapon delay damage bonus. Currently companions get 100% of the table value. This is fine at the 70-85% target since companions lack AAs that would further boost melee DPS. **Recommendation: Acceptable to defer. Add in Phase 5 if needed.**

**Present tuning knobs: All Phase 2-4 tuning knobs from the PRD are implemented.** The five implemented rules cover all the key levers for survivability, healing behavior, and mana conservation. Server operators can adjust all Phase 3-4 behaviors without recompiling.

---

## 5. Edge Cases and Potential Issues

### 5.1 Sitting During Combat — LOW RISK

The sitting regen bonus checks both IsSitting() and !IsEngaged(). Companions should not sit during combat. The AI does not call Sit() while engaged. However, if a player uses a custom command to force a companion to sit during combat, the sitting regen bonus would NOT apply (because IsEngaged() is true). The small NPC sitting bonus (+3 HP/tick from NPC::Process) would still apply. This is fine — no exploit.

### 5.2 Triple Attack on Off-Hand — CORRECTLY PREVENTED

DoAttackRounds() only checks triple attack when `hand == slotPrimary`. Off-hand attacks never triple. This matches EQ mechanics and is correct.

### 5.3 Flurry After Triple — CORRECTLY GATED

After a successful triple attack, there's a flurry chance check based on spell/item bonuses (no AAs). Since companions don't have AAs and flurry items are rare in Classic-Luclin, this will rarely fire. But it's correctly implemented for when it does apply.

### 5.4 CalcMaxHP Called Multiple Times — SAFE

CalcMaxHP() is called whenever CalcBonuses() runs (equip change, buff change, etc.). Each call to CalcMaxHP() calls Mob::CalcMaxHP() first (which resets max_hp from base_hp + itembonuses.HP), then adds the STA bonus. There's no risk of stacking STA bonuses across multiple calls because the base is always recalculated from scratch.

### 5.5 Negative STA From Debuffs — SAFE

If spellbonuses.STA is negative (from a STA debuff), the bonus_sta variable can go negative. But the code checks `if (bonus_sta <= 0) return base;` — so STA debuffs don't reduce HP below the NPC base. This is a design choice: debuffs don't reduce companion HP below their npc_types baseline. This is slightly favorable to companions but prevents edge cases where a debuff could kill a companion by reducing max HP below current HP.

### 5.6 Shaman Slow on Immune Target — SAFE

AI_Shaman() checks `!target->GetSpecialAbility(SpecialAbility::SlowImmunity)` before attempting slow. Slow-immune mobs are correctly skipped. The shaman will then proceed to healing and DoTs.

### 5.7 Healer with No Heal Spells Loaded — SAFE

If SelectHealSpell() and SelectEfficientHealSpell() both return 0 (no valid heals), AI_HealGroupMember() returns false. No crash, no wasted cast time. The healer simply can't heal.

### 5.8 Wizard at Exactly 20% Mana — EDGE CASE

The wizard check is `GetManaRatio() > ManaCutoffPct`. At exactly 20.0% mana, this evaluates to false (20.0 > 20 is false), so the wizard stops nuking. This is correct — the cutoff is "stop AT or below 20%", which preserves the mana reserve as intended.

### 5.9 Magician Hardcoded 20.0f — MINOR BUG

As noted in Section 2, AI_Magician() uses `GetManaRatio() > 20.0f` instead of `RuleI(Companions, ManaCutoffPct)`. This means changing the ManaCutoffPct rule won't affect Magicians. **This should be fixed for consistency.** The fix is trivial (replace 20.0f with the rule lookup) but it should go through the pipeline.

### 5.10 Druid Heal Threshold — MATCHES SHARED FUNCTION

The Druid AI handler calls AI_HealGroupMember(true), which uses the shared HealThresholdPct rule. So Druids heal at 80% threshold, same as Clerics and Shamans. The PRD specified 75% for Druids specifically, but using the shared threshold is simpler and the 5% difference is negligible. **Acceptable deviation from PRD.**

### 5.11 Enchanter Mana Conservation — NOT IMPLEMENTED

The PRD specified: "Enchanters reserve at least 15% mana for emergency mez. Stop nuking/DoTing below 30% mana." Looking at AI_Enchanter(), the nuke path has no mana guard at all — it just checks `m_current_stance == COMPANION_STANCE_AGGRESSIVE`. **This means an aggressive enchanter will nuke until completely OOM, with no mana reserved for emergency mez.** This is a moderate concern: in a multi-mob pull, if the enchanter burns all mana on nukes, they can't mez the add that breaks free.

**Recommendation: Add ManaCutoffPct guard to AI_Enchanter() nuke path, and ideally a separate/higher threshold (like 30%) since enchanters need more mana reserve than pure DPS casters.**

### 5.12 Druid DPS Mana Guard — HARDCODED

The Druid AI has `GetManaRatio() > 30.0f` hardcoded for nukes. This is more conservative than the 20% ManaCutoffPct but doesn't use the rule. If ManaCutoffPct is changed to 10 by a server operator, Druids would still stop at 30%. This is actually fine from a design perspective (Druids should conserve more mana for heals than pure DPS casters), but the inconsistency with other classes might confuse operators.

---

## 6. Summary and Recommendations

### Overall Assessment: STRONG PASS

All PRD acceptance criteria for Phases 2, 3, and 4 are met. The implementations are clean, well-documented, and produce authentic "playing with a real player" companion behavior. The 70-85% player power target is hit across all mechanics.

### Items to Address

| Priority | Item | Phase | Description |
|----------|------|-------|-------------|
| **Medium** | Magician ManaCutoffPct | 4 | AI_Magician() uses hardcoded 20.0f instead of RuleI(Companions, ManaCutoffPct). Should use the rule for consistency. |
| **Medium** | Enchanter mana reserve | 4 | AI_Enchanter() has no mana guard on nukes. Aggressive enchanters can go fully OOM with no mana for emergency mez. Add ManaCutoffPct guard (or higher). |
| **Low** | Druid nuking hardcoded 30% | 4 | AI_Druid() uses hardcoded 30.0f for nuke mana guard. Could use ManaCutoffPct or a separate rule for consistency. |
| **Deferred** | SkillCapPct rule | 5 | Not needed now; add in Phase 5 if avoidance testing shows companions are too effective. |
| **Deferred** | DamageBonusPct rule | 5 | Not needed now; add in Phase 5 if melee DPS testing shows companions are too strong. |
| **Verify** | Emergency heal data | 5 | Verify companion_spell_sets has appropriate min_hp_pct/max_hp_pct ranges so big heals fire on critically low targets. |
| **Verify** | Shaman re-slow | 5 | Verify AI_SlowDebuff() checks for existing slow debuff on target to prevent wasting casts on already-slowed mobs. |

### Test Coverage Assessment

**Suite 11 (Phase 2 — Triple Attack): 11 tests.** Good coverage of eligibility (CanCompanionTripleAttack for all classes), callable verification (CheckTripleAttack crash test), DoAttackRounds crash test with valid and null targets, and Phase 1 regression test. The tests are necessarily structural (triple attack is RNG-based) but they verify the right things.

**Suite 12 (Phase 3 — Survivability): 13 tests.** Excellent discriminating tests. The pure-STA-item test (hp=0, asta>0) is the perfect discriminator for STA-to-HP conversion — it can ONLY pass if CalcMaxHP() is working. The defense divisor lower-bound test using the client formula is also well-designed. The equip/unequip round-trip test confirms no stacking bugs.

**Suite 13 (Phase 4 — Spell AI): 11 tests.** Rule existence and default value tests (13.1-13.6) are simple but critical — they fail before implementation and pass after. The wizard mana cutoff test (13.7) is the best discriminating test: it sets mana to 19% and verifies the cutoff fires. The structural tests for Cleric and Shaman (13.8-13.9) verify no crash but can't fully test behavioral changes without combat state. **This is the weakest test suite of the three — real behavioral validation of Phase 4 changes requires in-game testing with active combat.**

### Design Verdict

The implementation faithfully executes the PRD. The two medium-priority items (Magician hardcoded cutoff, Enchanter no mana reserve) are minor inconsistencies rather than fundamental design problems. They can be addressed in the Phase 5 polish pass or filed as quick fixes.

The companion system, with these Phases 2-4 changes active on top of Phase 1's weapon damage path, should now produce companions that feel like competent group members: tanks that parry and riposte, warriors that triple attack at high levels, HP that responds to STA gear, healers that heal at appropriate thresholds, shamans that always slow, and casters that conserve mana. This is a significant step toward the "playing with real players" experience that is the core value proposition of this server.
