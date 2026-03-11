# npc-companion-realistic-stats — Dev Notes: C Expert

> **Feature branch:** `feature/npc-companion-realistic-stats`
> **Agent:** c-expert
> **Task(s):** Phase 3 — Stats Drive Survivability
> **Date started:** 2026-03-10
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| Phase 1 | Weapon damage path, SetAttackTimer, rules | — | **Complete** |
| Phase 2 | Triple attack, CheckTripleAttack, DoAttackRounds | Phase 1 | **Complete** |
| Phase 3 | STA-to-HP, sitting regen, defense AC divisor | Phase 2 | **In Progress** |

---

## Phase 3 Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `zone/attack.cpp` | 896-965 | `Mob::ACSum()` — IsNPC() branch uses defense_skill/5; IsCompanion() must be guarded out |
| `zone/mob.cpp` | 989-994 | `Mob::CalcMaxHP()` — virtual, uses base_hp + itembonuses.HP; no STA contribution |
| `zone/client_mods.cpp` | 314-340 | `Client::CalcMaxHP()` — uses CalcBaseHP() which applies STA formula |
| `zone/client_mods.cpp` | 479-506 | `Client::CalcBaseHP()` — STA-based formula: `5 + (level * lm/10) + STA * level * lm / 3000` |
| `zone/companion.cpp` | 891-904 | `Companion::CalcHPRegen()` — already overridden; returns max(native_regen, floor_regen) |
| `zone/npc.cpp` | 645-690 | `NPC::Process()` regen section — sitting adds 3 HP/tick; OOC regen used via ooc_regen field |
| `common/ruletypes.h` | 1181-1219 | All existing Companion rules; need to add STAToHPFactor, SittingRegenMult |

### Key Findings

1. **ACSum defense divisor bug**: At attack.cpp:920, the `if (IsNPC())` block uses `GetSkill(SkillDefense) / 5`. Companions have `IsNPC()=true` so they enter this block. Fix: add `&& !IsCompanion()` to the condition so companions fall into the else branch and get `/3` or `/2`.

   BUT: the NPC block also adds `GetAC()` (base NPC AC) and `GetPetACBonusFromOwner()`. Companions need `GetAC()` but not necessarily `GetPetACBonusFromOwner()` (they're not pets). Since companions DO have a meaningful `GetAC()` from their npc_types, we can't skip the whole NPC block. We must keep `GetAC()` and `GetPetACBonusFromOwner()` for companions too (companion owner bonus is 0 anyway), and only change the defense skill divisor.

   **Revised approach**: Within the NPC branch, add an additional `if (IsCompanion())` check just for the defense skill part. Specifically:
   ```cpp
   // NPC branch keeps: ac += GetAC(); ac += GetPetACBonusFromOwner(); spell_aa_ac stuff
   // Change just the defense skill line:
   if (IsCompanion()) {
       // Use Client/Bot divisor: /3 for melee, /2 for casters
       if (EQ::ValueWithin(static_cast<int>(GetClass()), Class::Necromancer, Class::Enchanter))
           ac += GetSkill(EQ::skills::SkillDefense) / 2 + spell_aa_ac / 3;
       else
           ac += GetSkill(EQ::skills::SkillDefense) / 3 + spell_aa_ac / 4;
   } else {
       // NPC path: /5
       ac += GetSkill(EQ::skills::SkillDefense) / 5;
       if (EQ::ValueWithin(...))
           ac += spell_aa_ac / 3;
       else
           ac += spell_aa_ac / 4;
   }
   ```

2. **STA-to-HP**: Override `CalcMaxHP()` in Companion. Base formula from Mob::CalcMaxHP() adds `itembonuses.HP` to `base_hp`. We extend this: AFTER `Mob::CalcMaxHP()`, add STA bonus HP:
   ```
   bonus_hp = (itembonuses.STA + spellbonuses.STA) * hp_per_sta
   ```
   where `hp_per_sta` is level/class dependent, scaled by `Companions::STAToHPFactor` rule.

   HP-per-STA table (per PRD): tanks ~8, melee DPS ~5, priest ~4, caster DPS ~3. These are at level 60; scale linearly with level.

3. **Sitting HP regen bonus**: The `CalcHPRegen()` override already returns a base value. The NPC::Process() regen section adds 3 HP/tick for sitting (`npc_sitting_regen_bonus += 3`). For companions, the PRD wants 2-3x regen when sitting OOC. The approach: intercept in `Companion::CalcHPRegen()` — when sitting and not engaged, return a higher value. OR override the regen calculation in Process() before calling NPC::Process().

   **Revised approach**: Instead of overriding Process() regen, let NPC::Process() use our CalcHPRegen() result. The issue is NPC::Process() at line 648 calls `GetNPCHPRegen()` (not `CalcHPRegen()`). Let's check what GetNPCHPRegen() returns.

   Need to verify: does NPC::Process() call CalcHPRegen() or GetNPCHPRegen()? Looking at npc.cpp:648: `int64 npc_hp_regen = GetNPCHPRegen();` — this is what sets the regen rate. And CalcHPRegen() is only used in AI_Start() to seed `hp_regen`. So the sitting bonus is applied in NPC::Process via `npc_sitting_regen_bonus += 3`.

   **Cleanest approach**: Add a `Companion::CalcHPRegen()` behavior that accounts for sitting, but the real sitting bonus comes from modifying the value set in `hp_regen`. Since companions' `hp_regen` is seeded in AI_Start() via CalcHPRegen(), we can't change hp_regen mid-process for sitting.

   Alternative: Override the sitting bonus in Companion::Process() BEFORE calling NPC::Process(). Read the current HP, call NPC::Process(), then apply additional regen if we were sitting and not engaged and HP went up by the regular amount. This is messy.

   **Better approach**: Override `GetNPCHPRegen()` if virtual. If not, we can add a `Companion::Process()` HP top-up after NPC::Process() returns. The simplest correct approach is to intercept in Process() and apply the sitting regen multiplier manually.

   The plan:
   - In `Companion::Process()`, AFTER calling `NPC::Process()`, check if we are sitting and not engaged.
   - If sitting OOC, apply an additional `SittingRegenMult` percentage bonus to what NPC::Process() already added.
   - Since we can't easily tell how much NPC::Process() added, we calculate the sitting bonus separately.

   Actually the cleanest approach: in `Companion::Process()` BEFORE `NPC::Process()`, calculate the sitting bonus HP to add, add it manually, then call NPC::Process(). NPC::Process() will see HP below max and add its own regen. We effectively layer our sitting bonus on top.

   Wait - that double-counts. Let's think differently.

   **Final approach for sitting regen**: Override `CalcHPRegen()` to return a higher value when sitting. Then re-seed `hp_regen` in Process() before NPC::Process() runs.

   Looking at npc.cpp:648: `int64 npc_hp_regen = GetNPCHPRegen();`
   And GetNPCHPRegen() returns: `hp_regen + itembonuses.HPRegen + spellbonuses.HPRegen`
   Where `hp_regen` is the field set in AI_Start().

   If we update `hp_regen` in Companion::Process() based on sitting state, then NPC::Process() will use the updated value via GetNPCHPRegen(). This is clean and correct.

   So: in `Companion::Process()`, BEFORE calling `NPC::Process()`, do:
   ```cpp
   // Update hp_regen based on sitting state for NPC::Process to use
   hp_regen = CalcHPRegen(); // base value
   if (IsSitting() && !IsEngaged()) {
       int mult = RuleI(Companions, SittingRegenMult); // default 200 = 2x
       hp_regen = (hp_regen * mult) / 100;
   }
   ```

   But wait: CalcHPRegen() already returns `max(native_regen, floor_regen)`. If native_regen is already 0, floor is 1 HP/tick. With 2x that's 2 HP/tick. But companions use OOC regen (5% of max HP, set as `ooc_regen` field) which is much larger and is computed separately in NPC::Process() via `ooc_regen_calc`. So for companions, the dominant regen is OOC, not hp_regen.

   The sitting bonus should multiply the OOC regen too. But `ooc_regen` is an integer percentage and NPC::Process() uses it directly.

   **Simplest correct approach**: In Companion::Process(), after NPC::Process(), if sitting and not engaged and HP < max_hp, add extra HP based on sitting multiplier * base_regen. This gives the ADDITIVE sitting bonus on top of OOC regen.

   Actually, re-reading npc.cpp:662-666:
   ```cpp
   npc_regen = std::max(npc_hp_regen, ooc_regen_calc);
   if (GetHP() < GetMaxHP() && !IsPet()) {
       if (!IsEngaged()) {
           SetHP(GetHP() + npc_regen + npc_sitting_regen_bonus);
   ```

   For companions (not pets, not engaged), regen is `max(hp_regen, ooc_regen_calc) + 3`.
   The `+ 3` sitting bonus is small. We want the SITTING state to amplify the total regen to 2-3x.

   Cleanest approach: Override `CalcHPRegen()` to check IsSitting() and multiply the base by SittingRegenMult/100 when sitting. Then re-seed hp_regen from this at the start of each Process() call. This affects `npc_hp_regen` but NOT `ooc_regen_calc`.

   To also multiply OOC regen when sitting, we'd need to change `ooc_regen` dynamically. That's possible.

   **FINAL DECISION**: Keep it simple. In Companion::Process(), before NPC::Process():
   ```cpp
   // Sitting regen multiplier: when sitting OOC, amplify OOC regen
   if (IsSitting() && !IsEngaged() && GetHP() < GetMaxHP()) {
       int mult = RuleI(Companions, SittingRegenMult);
       int base_ooc = (GetMaxHP() * RuleI(Companions, OOCRegenPct)) / 100;
       int sitting_bonus = (base_ooc * (mult - 100)) / 100; // additive bonus beyond base
       if (sitting_bonus > 0) {
           SetHP(std::min(GetHP() + sitting_bonus, GetMaxHP()));
       }
   }
   ```
   This adds the extra sitting regen BEFORE NPC::Process() (which adds the OOC regen). Total sitting regen = ooc_regen + sitting_bonus. At SittingRegenMult=200 (2x), the bonus equals the base OOC amount, so total is 2x OOC.

### Implementation Plan

**Files to modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | Modify | Add STAToHPFactor and SittingRegenMult rules before RULE_CATEGORY_END |
| `eqemu/zone/attack.cpp` | Modify | ACSum() — add IsCompanion() branch for defense skill divisor |
| `eqemu/zone/companion.h` | Modify | Declare `CalcMaxHP()` override |
| `eqemu/zone/companion.cpp` | Modify | Implement `CalcMaxHP()` with STA bonus; add sitting regen in Process() |
| `eqemu/zone/cli/tests/cli_companion_tests.cpp` | Modify | Add Suite 12: Phase 3 STA-to-HP, sitting regen, defense AC divisor tests |

**Change sequence (TDD):**
1. Write Suite 12 tests (failing) for STA-to-HP, sitting regen, defense AC divisor
2. Add rules to ruletypes.h
3. Fix ACSum() in attack.cpp
4. Add CalcMaxHP() declaration to companion.h
5. Implement CalcMaxHP() in companion.cpp
6. Add sitting regen intercept in Companion::Process()
7. Build and run ALL tests (suites 1-12)

---

## Phase 3 Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `Mob::CalcMaxHP()` | mob.cpp:989 | Yes | Virtual, uses base_hp + itembonuses.HP |
| `Mob::ACSum()` | attack.cpp:896 | Yes | IsNPC() at line 920, defense_skill/5 for NPCs |
| `NPC::Process()` regen | npc.cpp:645-690 | Yes | npc_sitting_regen_bonus=3, ooc_regen used for OOC |
| `Companion::CalcHPRegen()` | companion.cpp:891 | Yes | Already overridden, returns max(native, floor) |
| `GetNPCHPRegen()` | Mob function | Yes | Returns hp_regen + itembonuses.HPRegen + spellbonuses.HPRegen |
| Client::CalcBaseHP() STA formula | client_mods.cpp:503 | Yes | level * ClassLevelFactor * STA / 3000 at pre-SoD |
| `itembonuses.STA` / `spellbonuses.STA` | bonuses.cpp | Yes | Set by CalcSpellBonuses/CalcItemBonuses |

### Plan Amendments

**Amendment 1**: The ACSum fix should keep the companion IN the NPC branch (to preserve GetAC() addition) but use client/bot defense divisor within that branch. This avoids disrupting the AC softcap logic which is in the `else if (!skip_caps && IsOfClientBot())` section that already applies to companions correctly.

**Amendment 2**: For CalcMaxHP() override, call `Mob::CalcMaxHP()` first to get the NPC base calculation (base_hp + itembonuses.HP), then add the STA bonus HP on top. This preserves full compatibility.

**Amendment 3**: HP per STA per level. Use simplified formula rather than Client formula (which is complex). Per PRD: tanks 8, melee 5, priests 4, casters 3 at level 60. Scale by (level/60) to give proportional values at lower levels. Apply `STAToHPFactor` as percentage modifier (100 = full, 50 = half).

Formula: `hp_per_sta = base_per_sta * level / 60 * STAToHPFactor / 100`
where base_per_sta is 8 (tank), 5 (melee), 4 (priest), 3 (caster).

Only bonus STA (itembonuses.STA + spellbonuses.STA) contributes, NOT base STA.

---

## Phase 3 Stage 3: Socialize

No other agents in scope. Cross-system check: The defense divisor change in ACSum() (attack.cpp) only affects the code path for companions via `IsCompanion()` guard. It does not affect regular NPCs or bots. The STA-to-HP change is in Companion::CalcMaxHP() override — no shared code changed. The sitting regen is in Companion::Process(). All changes are companion-specific and additive.

---

## Phase 3 Stage 4: Build

### Status: Complete (2026-03-10)

### Implementation Log

#### 2026-03-10 — Phase 3 TDD and implementation

**What:** Suite 12 tests + implementation of STA-to-HP, sitting regen, defense AC divisor fix

**Where:**
- `eqemu/common/ruletypes.h` — new rules
- `eqemu/zone/attack.cpp` — ACSum() companion defense divisor
- `eqemu/zone/companion.h` — CalcMaxHP() declaration
- `eqemu/zone/companion.cpp` — CalcMaxHP() + Process() sitting regen
- `eqemu/zone/cli/tests/cli_companion_tests.cpp` — Suite 12

### Files Modified

| File | Action | Description |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | Modified | Added STAToHPFactor and SittingRegenMult rules |
| `eqemu/zone/attack.cpp` | Modified | ACSum() — companion uses /3 or /2 for defense skill |
| `eqemu/zone/companion.h` | Modified | CalcMaxHP() override declaration |
| `eqemu/zone/companion.cpp` | Modified | CalcMaxHP() STA bonus + Process() sitting regen |
| `eqemu/zone/cli/tests/cli_companion_tests.cpp` | Modified | Suite 12 tests (13 tests; test 12.12 corrected: Cleric->Wizard, since only Necromancer..Enchanter range gets /2) |

**TDD result: All 12 suites pass (120+ tests, 2 expected skips)**

---

## Context for Next Agent

Phase 1-3 complete. Key implementation files:
- `companion.h`: SetAttackTimer, Attack, CalcMaxHP, CanCompanionTripleAttack, CheckTripleAttack, DoAttackRounds
- `companion.cpp`: All above implemented + Process() intercepts for melee and sitting regen
- `attack.cpp`: ACSum() has IsCompanion() guard for defense skill divisor
- Tests: Suites 9-12 cover weapon damage, ACSum regression, triple attack, Phase 3 survivability

---

## Phase 4 Stage 1: Plan

### Task Assignment Update

| # | Task | Status |
|---|------|--------|
| Phase 4 | Spell AI Tuning | In Progress |

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `zone/companion_ai.cpp` | 1-1411 | All class-specific AI handlers. Key findings below. |
| `zone/companion.cpp` | 1592-1636 | AI_EngagedCastCheck passes 0xFFFFFFFF (all types), AI_IdleCastCheck passes Buff|Heal|Pet |
| `common/spdat.h` | 632-653 | SpellType_Buff=(1<<3), SpellType_InCombatBuff=(1<<10), SpellType_PreCombatBuff=(1<<20) |
| `common/ruletypes.h` | 1181-1227 | Companions category — no HealThresholdPct or ManaCutoffPct rules yet |

### Key Findings

**Current behavior that needs changing:**

1. **Cleric heal threshold**: `AI_HealGroupMember()` uses `lowest_hp = engaged ? 90 : 99`.
   PRD says: heal below 80%. Fix: change 90 → 80.

2. **Shaman slow priority**: `AI_Shaman()` uses `zone->random.Roll(70)` for slow.
   PRD says: always attempt slow as first action (100% chance).
   Fix: remove the roll (always attempt, or use roll(100) which always succeeds).
   NOTE: The slow will only actually fire if the slow is available and target isn't immune.

3. **Mana cutoff for DPS nuking**:
   - Global OOM bail: `GetManaRatio() < 10.0f` in `AICastSpell()`.
   - Wizard: `GetManaRatio() > 15.0f` check before nuking. PRD says 20%.
   - Magician: `GetManaRatio() > 20.0f` — already 20%, correct.
   - Necromancer: no mana check on nukes (50% roll for DoT, 40% for nuke). Add mana check.
   - New rule `ManaCutoffPct` (default 20): DPS casters stop nuking below this %. Wizard + Necro need update.
   - NOTE: We should also update the global OOM bail from 10% to use the ManaCutoffPct rule for cleanliness, but only for DPS — healers need to heal even when low mana.

4. **No standard buffs during combat**:
   - `AI_Cleric` (engaged) at line 857: calls `AI_BuffGroupMember()` when mana > 50%. REMOVE.
   - `AI_IdleCastCheck()` already uses `SpellType_Buff | SpellType_Heal | SpellType_Pet` — correct.
   - `AI_EngagedCastCheck()` passes 0xFFFFFFFF — includes SpellType_Buff and SpellType_PreCombatBuff.
   - Simplest fix: in the engaged handlers, do NOT call `AI_BuffGroupMember()` unless the spell type is InCombatBuff.
   - The AI_Cleric change is the main code fix; other class handlers already don't buff in combat.

5. **Enchanter mez before slow**: Already implemented. `AI_Enchanter()` calls `AI_MezTarget()` first
   then slow. PRD requirement is already satisfied.

6. **Healers use efficient heals below 30% mana**:
   - The current `SelectHealSpell()` helper picks spells from SpellType_Heal ordered by slot.
   - To prefer efficient heals at low mana, we need to either tag spells with efficiency metadata
     OR use the existing min_hp_pct / max_hp_pct column to order by mana cost.
   - Simplest approach: when mana < 30%, skip expensive heals (mana cost > threshold) and use
     smallest available heal. But spell data structures don't expose mana cost easily in the current
     SelectHealSpell function.
   - Better approach: add a `SelectEfficientHealSpell()` helper that picks the spell with the
     lowest mana cost from the available heal spells. Use `spells[spellid].mana` for cost.
   - When mana < `HealerManaConservePct` (30%), use SelectEfficientHealSpell instead.

7. **Rebuff on combat→idle transition**:
   - This requires detecting the transition from engaged to not-engaged.
   - The `AI_IdleCastCheck()` already handles buffing via `SpellType_Buff | SpellType_Heal | SpellType_Pet`.
   - The buffing will happen naturally on the next idle spell check tick.
   - No code change needed — the idle check fires on the first idle tick after combat ends.
   - PRD says "companions rebuff the group when transitioning from combat to idle" — this already works.

### Rules to Add

```cpp
RULE_INT(Companions, HealThresholdPct, 80,
    "HP percentage below which companion healers begin healing in combat (default 80)")
RULE_INT(Companions, ManaCutoffPct, 20,
    "Mana percentage below which companion DPS casters stop nuking (default 20)")
RULE_INT(Companions, HealerManaConservePct, 30,
    "Mana percentage below which healer companions use their most mana-efficient heal (default 30)")
```

### Implementation Plan

**Files to modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | Modify | Add HealThresholdPct, ManaCutoffPct, HealerManaConservePct rules |
| `eqemu/zone/companion_ai.cpp` | Modify | AI_HealGroupMember (80% threshold), AI_Shaman (100% slow), AI_Wizard/AI_Necromancer (mana cutoff), AI_Cleric (remove engaged buff), SelectEfficientHealSpell helper |
| `eqemu/zone/cli/tests/cli_companion_tests.cpp` | Modify | Add Suite 13: Phase 4 Spell AI Tuning tests |

**Change sequence (TDD):**
1. Write Suite 13 failing tests (rules existence + behavioral checks)
2. Add new rules to ruletypes.h
3. Implement changes in companion_ai.cpp:
   a. `AI_HealGroupMember`: change 90 → `RuleI(Companions, HealThresholdPct)`
   b. `AI_Shaman`: remove 70% roll, always attempt slow
   c. `AI_Wizard`: update mana cutoff to `RuleI(Companions, ManaCutoffPct)`
   d. `AI_Necromancer`: add mana cutoff guard
   e. `AI_Cleric`: remove buff casting during combat (remove line 857 block)
   f. Add `SelectEfficientHealSpell()` helper and use it when mana < HealerManaConservePct
4. Build and run ALL tests (suites 1-13)

### TDD Test Design for Suite 13

**Discriminating tests** (will FAIL before implementation):

- `13.1`: Rule `HealThresholdPct` exists, default is 80
- `13.2`: Rule `ManaCutoffPct` exists, default is 20
- `13.3`: Rule `HealerManaConservePct` exists, default is 30
- `13.4`: `AI_HealGroupMember()` behavior — threshold check. Since we can't call it directly with a mock group, we test via AICastSpell() with a cleric at low mana. But AICastSpell needs spells loaded and engaged state set. This is complex.

The behavioral tests are hard to unit-test without a full group + engagement state. The most practical discriminating tests for Phase 4 are:
- Rule existence tests (13.1-13.3) — trivial but verify rules were added
- AICastSpell early-exit for OOM: test that a wizard with mana < 20% returns false from AICastSpell when mana OOM bail is set (but the 10% bail is global; this is harder to test)
- Direct verification of the engagement-mode buff prevention: check that when the Cleric AI is in engaged state (IsEngaged() = false by default for test companions), AI_Cleric does not attempt to buff

Since test companions are NOT engaged by default, and AI_Cleric only buffs in engaged state, the Cleric buff-in-combat change won't be directly testable without forcing engagement.

**Pragmatic approach for Suite 13:**
- Test rules exist (13.1-13.3) — will FAIL before rules are added
- Test AICastSpell returns false for companion with no spells (already tested but validate)
- Test AICastSpell called on a Wizard companion with mana below ManaCutoffPct — when spells loaded, should return false due to mana cutoff. This requires LoadCompanionSpells() + manipulating companion mana.
- Test `AI_HealGroupMember` threshold indirectly: verify that the threshold constant comes from the rule (check RuleI value = 80).

Given the difficulty of behavioral testing without a real group/engagement state, Suite 13 will:
1. Test new rule existence and default values (3 tests)
2. Test AICastSpell OOM behavior (wizard with 0 mana should return false)
3. Test healer threshold value matches the PRD (80, not 90)
4. Test that Shaman does not have a rand check — we can test the code path by calling AI_Shaman when mana is available but no target is set (should return false, not crash)

---

## Phase 4 Stage 2: Research

### Verified Patterns

| API / Function | Source | Verified? | Notes |
|----------------|--------|-----------|-------|
| `AI_HealGroupMember()` threshold | companion_ai.cpp:374 | Yes | `lowest_hp = engaged ? 90 : 99` — change 90 to RuleI |
| `AI_Shaman()` slow roll | companion_ai.cpp:981 | Yes | `zone->random.Roll(70)` — change to always attempt |
| `AI_Wizard()` mana guard | companion_ai.cpp:1180 | Yes | `GetManaRatio() > 15.0f` — change to ManaCutoffPct |
| `AI_Magician()` mana guard | companion_ai.cpp:1214 | Yes | `GetManaRatio() > 20.0f` — already 20%, no change needed |
| `AI_Necromancer()` no mana guard on nukes | companion_ai.cpp:1248-1261 | Yes | DoT at 70% roll, nuke at 40% roll — add mana check |
| `AI_Cleric()` buff in engaged path | companion_ai.cpp:857 | Yes | Calls AI_BuffGroupMember() when mana > 50% during combat |
| `spells[spellid].mana` | spdat.h | Yes | Mana cost field on SPDat_Spell_Struct |
| Rule access pattern | rulesys.h | Yes | `RuleI(Companions, RuleName)` |

### Plan Amendments from Research

**Amendment 1**: For `SelectEfficientHealSpell()`, since the mana cost is in `spells[spellid].mana` (an int), sort candidates by ascending mana cost and return the cheapest one that satisfies HP threshold constraints. This is a new static helper function.

**Amendment 2**: The `AI_HealGroupMember` threshold change from hardcoded 90 to `RuleI(Companions, HealThresholdPct)` needs to handle the case where the rule returns 80 but the function signature accepts `bool engaged`. When NOT engaged (idle), use 99 (same as before). When engaged, use the rule value.

**Amendment 3**: For Shaman slow, simply remove `zone->random.Roll(70)` condition entirely. The slow attempt will always happen if:
- SpellType_Slow is in iSpellTypes
- A slow spell is available
- Target is not slow-immune

**Amendment 4**: Necromancer mana cutoff guard — add `GetManaRatio() > RuleI(Companions, ManaCutoffPct)` check for DoT and Nuke paths, same as wizard.

---

## Phase 4 Stage 3: Socialize

No other agents in scope for Phase 4. All changes are in `companion_ai.cpp` (spell AI logic) and `ruletypes.h` (new rules). No cross-system dependencies.

The changes:
- Do NOT affect the `companion_spell_sets` database table (per PRD: "unchanged")
- Do NOT change the SpellTypes bitmask system
- Do NOT affect Phases 1-3 implementations
- All gated by rule values (can revert by changing rules)

---

## Phase 4 Stage 4: Build

### Status: Complete (2026-03-11)

### Implementation Log

#### 2026-03-11 — Phase 4 TDD and implementation

**What:** Suite 13 tests (12 tests) + implementation of spell AI tuning

**Where:**
- `eqemu/common/ruletypes.h` — new rules HealThresholdPct, ManaCutoffPct, HealerManaConservePct
- `eqemu/zone/companion_ai.cpp` — AI tuning in 6 handlers + new SelectEfficientHealSpell helper
- `eqemu/zone/cli/tests/cli_companion_tests.cpp` — Suite 13

### Files Modified

| File | Action | Description |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | Modified | Added HealThresholdPct (80), ManaCutoffPct (20), HealerManaConservePct (30) rules |
| `eqemu/zone/companion_ai.cpp` | Modified | 6 changes: (1) SelectEfficientHealSpell() helper, (2) AI_HealGroupMember 90→80% threshold via rule, (3) AI_HealGroupMember uses efficient heal below 30% mana, (4) AI_Shaman removes 70% slow roll, (5) AI_Wizard mana cutoff 15→20% via rule, (6) AI_Necromancer adds mana cutoff guards, (7) AI_Cleric removes buff-during-combat |
| `eqemu/zone/cli/tests/cli_companion_tests.cpp` | Modified | Suite 13 tests (12 tests), updated Suite listing at top |

**TDD result: All 13 suites pass (177 tests passing, 2 expected skips)**

### Changes Summary

1. **`SelectEfficientHealSpell()` helper**: new static helper that picks the heal spell with the lowest mana cost, used when healer mana < HealerManaConservePct.

2. **`AI_HealGroupMember()` threshold**: `lowest_hp = engaged ? 90 : 99` changed to `engaged ? RuleI(Companions, HealThresholdPct) : 99`. Default 80%.

3. **`AI_HealGroupMember()` mana conservation**: when mana < HealerManaConservePct, try SelectEfficientHealSpell first before falling back to SelectHealSpell.

4. **`AI_Shaman()` slow**: removed `zone->random.Roll(70)` roll. Slow is now always attempted when the spell type is requested and a slow spell is available.

5. **`AI_Wizard()` mana cutoff**: `GetManaRatio() > 15.0f` changed to `GetManaRatio() > static_cast<float>(RuleI(Companions, ManaCutoffPct))`. Default 20%.

6. **`AI_Necromancer()` mana cutoff**: DoT and Nuke paths now also check `GetManaRatio() > ManaCutoffPct`. Lifetap is exempt (always allow for survival).

7. **`AI_Cleric()` no combat buffs**: removed the engaged-path `AI_BuffGroupMember()` call. Replaced with `AI_InCombatBuff()` (only in-combat-type buffs during engagement). Idle path unchanged.

8. **`AI_Shaman()` DoT mana guard**: added ManaCutoffPct check to DoT casting in engaged state.

### PRD Acceptance Criteria Coverage

| Criterion | Status |
|-----------|--------|
| Cleric begins healing at 80% HP in combat | Implemented (HealThresholdPct rule, default 80) |
| Shaman reliably slows primary target as first action | Implemented (removed 70% roll, always attempts) |
| DPS casters stop nuking below 20% mana | Implemented (ManaCutoffPct rule for Wizard + Necromancer; Magician was already 20%) |
| No standard buffs cast during combat engagement | Implemented (AI_Cleric engaged buff removed; other classes already compliant) |
| Enchanter prioritizes mez on adds | Already implemented (mez is first in AI_Enchanter engaged path) |
| Healers switch to efficient heal below 30% mana | Implemented (HealerManaConservePct rule + SelectEfficientHealSpell) |
| Companions rebuff on transition to idle | Already works (AI_IdleCastCheck includes SpellType_Buff) |

---

## Audit Fix Phase Stage 1–4

### Task Assignment Update

| # | Task | Status |
|---|------|--------|
| Audit Fixes | 8 issues identified by architect audit | In Progress |

### Implementation Date: 2026-03-11

### Issues Fixed

| Issue | Priority | Fix Applied |
|-------|----------|------------|
| #1 Sitting regen timing | Critical | Added m_sitting_regen_timer(6000) to companion.h/cpp; gate sitting bonus behind timer in Process() |
| #2 Magician mana cutoff | Medium | Replaced 20.0f hardcode with RuleI(Companions, ManaCutoffPct) in AI_Magician |
| #3 Enchanter mana reserve | Medium | Added ManaCutoffPct+10 guard on nuke path in AI_Enchanter |
| #4 int8 overflow | Medium | Widened int8 to int for lowest_hp, hpr, self_hp in AI_HealGroupMember; also widened SelectHealSpell/SelectEfficientHealSpell target_hp_pct param |
| #5 Druid HoT preference | Enhancement | Added SelectHoTSpell() static helper; AI_Druid now prefers HoT above 50% HP, direct heal below |
| #6 Shaman Cannibalize | Enhancement | Added FindCannibalizeSpell() method; AI_Shaman engaged+idle paths try canni at mana<40%/HP>80% |
| #7 Pet spam | Enhancement | Added GetManaRatio()>25.0f guard to AI_Magician, AI_Necromancer, AI_Beastlord pet summon paths |
| #8 Wizard DS spam | Enhancement | Added IsDamageShieldSpell() static helper; new AI_WizardBuff() restricts DS to melee targets only |

### Files Modified

| File | Changes |
|------|---------|
| `eqemu/zone/companion.h` | Added m_sitting_regen_timer to protected section; added FindCannibalizeSpell() and AI_WizardBuff() declarations |
| `eqemu/zone/companion.cpp` | Added m_sitting_regen_timer(6000) to constructor initializer list; added .Check() gate on sitting regen in Process() |
| `eqemu/zone/companion_ai.cpp` | Added #include "common/spdat.h"; widened SelectHealSpell/SelectEfficientHealSpell to int; added SelectHoTSpell(), IsDamageShieldSpell() helpers; fixed int8 in AI_HealGroupMember; fixed ManaCutoffPct in AI_Magician; added mana guard to AI_Enchanter nuke; added 25% mana guard to pet summon in 3 classes; added AI_WizardBuff(); updated AI_Wizard idle to use AI_WizardBuff; added cannibalize logic to AI_Shaman; added FindCannibalizeSpell() |
| `eqemu/zone/cli/tests/cli_companion_tests.cpp` | Added Suite 14 (TestCompanionAuditFixes), 27 tests for all 8 issues; added #include "common/spdat.h"; registered suite in entry point |

### TDD Status

All tests written BEFORE implementation. Tests will be verified passing after Docker/build is available.

**NOTE on Test 14.20:** Test 14.20 (Cannibalize data presence in companion_spell_sets) is a SQL verification task belonging to the data-expert. It is listed in the architect's plan but was not written as a C++ test here — the C++ implementation correctly handles the case where no Cannibalize spells exist (safe degradation: FindCannibalizeSpell returns 0 and no cast happens).

**NOTE on test discriminability:** Several tests (14.5, 14.6) verify structural correctness (no crash, mana ratio math) rather than behavioral output since behavioral testing requires a fully engaged entity with a group and valid spell targets. For tests that require real behavioral discrimination (e.g., 14.1 sitting regen), we test the guard condition directly by calling Process() twice and verifying the second call doesn't produce additional bonus.

### Build Status

COMPLETE — Build and tests verified on 2026-03-11.

All 15 suites pass: Suite 14 (27 tests) + prior suites all green.
2 expected SKIPs (Monk below-60 NPC not in DB; ScaleStatsToLevel NPC at max level).

---

## Phase 5 Stage 1: Plan

### Task Assignment Update

| # | Task | Status |
|---|------|--------|
| Phase 5 | Resist Caps + Focus Effects + Balance Documentation | **Complete** |

### Files Modified in Phase 5

| File | Action |
|------|--------|
| `eqemu/common/ruletypes.h` | Added `Companions::ResistCapBase` rule (default 50) |
| `eqemu/zone/companion.h` | Added `#include <algorithm>`, `GetMaxResist()`, 5 resist getter overrides (GetMR/FR/DR/PR/CR inline), `GetFocusEffect()` override |
| `eqemu/zone/companion.cpp` | Implemented `GetMaxResist()` (level*5+base, 0=disable), `GetFocusEffect()` (delegates to Mob:: base) |
| `eqemu/zone/cli/tests/cli_companion_tests.cpp` | Suite 15 (27 tests): resist caps + focus effects + rule defaults |
| `claude/project-work/.../architect/context/balance-tuning.md` | Balance documentation created |

---

## Phase 5 Stage 4: Build (TDD)

### Status: Complete (2026-03-11)

### Implementation Log

#### 2026-03-11 — Phase 5 TDD and implementation

**What:** Resist caps (GetMaxResist + 5 inline getter overrides) + focus effect fix
(GetFocusEffect override delegating to Mob base class) + ResistCapBase rule +
Suite 15 tests (27 assertions).

**TDD Order:**
1. Suite 15 tests written FIRST (all discriminating: FAIL before implementation)
2. ResistCapBase rule added → tests 15.1, 15.16 pass
3. companion.h declarations + companion.cpp implementations added
4. All Suite 15 tests pass
5. All 14 prior suites verified still passing

**Build result:** 244 targets, 0 errors, 0 warnings.
**Test result:** All 15 suites pass. 2 expected SKIPs. 0 failures.

### Key Design Decisions

1. **Resist cap as inline GetMR/FR/DR/PR/CR overrides** (not CalcMR pre-calculation):
   - Matches the plan: on-the-fly clamping, always reflects current state
   - Bot uses CalcMR (pre-accumulation), we use the simpler inline pattern
   - Requires `std::min` in companion.h → added `#include <algorithm>`

2. **GetFocusEffect delegates to Mob::**
   - Single line bypasses both NPC problems (rule gate + wrong array access)
   - No changes to NPC, Mob, Client, or Bot code — zero regression risk

3. **ResistCapBase=0 disables capping** (returns 32000):
   - Clean disable mechanism: set rule to 0 via `#rules set` in-game
   - Value 32000 is unreachable by realistic companion resists

### PRD Acceptance Criteria Coverage

| Criterion | Status |
|-----------|--------|
| No companion resist stat exceeds level-appropriate cap | Implemented (cap = level*5+ResistCapBase, default 350@60) |
| Focus effect items produce measurable benefit | Implemented (GetFocusEffect → Mob::, bypasses NPC rule gate) |
| Overall companion power evaluated + tuning knobs documented | Done (`balance-tuning.md` created) |
