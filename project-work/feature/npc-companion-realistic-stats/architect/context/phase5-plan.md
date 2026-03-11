# Phase 5 Implementation Plan: Resist Caps + Focus Effects + Balance Pass

> **Feature branch:** `feature/npc-companion-realistic-stats`
> **Author:** architect
> **Date:** 2026-03-11
> **Status:** Ready for Implementation
> **Prerequisite:** Phases 1-4 + audit fixes complete (204+ tests passing)

---

## 1. What Phase 5 Requires (PRD Summary)

Phase 5 is the polish and balance pass on top of Phases 1-4. Three deliverables:

### A. Resist Caps
Companion resistances must be capped at level-appropriate values to prevent
base resists + gear resists + buff resists from creating spell immunity.

- Cap formula: approximately `level * 5 + 50` (matching Classic-Luclin Client
  resist cap).
- Applied after all bonuses (base + items + spells) are summed.
- Each resist (MR, FR, CR, DR, PR) capped independently.
- Cap value should be a configurable rule.

### B. Focus Effects
Spell focus effects from equipped items (improved damage, improved healing,
mana conservation, extended duration) must work on companion spell casts.

- Key focus types to verify: Improved Damage, Improved Healing, Mana
  Conservation, Extended Enhancement.
- Since companions call `SpellOnTarget()` and `SpellEffect()` which call
  `GetFocusEffect()`, focus effects should theoretically work through the
  Mob focus code path. Test and fix if broken.

### C. Balance Tuning Pass
After all phases active, evaluate and tune:
- Companion DPS vs player DPS at equivalent gear (target: 70-85% of player).
- Tank companion survivability vs player tank.
- Adjust `StatScalePct` and other rules as needed.
- Document tuning knob values for current balance point.

### PRD Acceptance Criteria
- [ ] No companion resist stat can exceed the resist cap.
- [ ] Equipping a focus effect item produces measurably increased spell
      damage, healing, or reduced mana cost.
- [ ] Overall companion power level evaluated and documented with tuning
      knob values recorded.

---

## 2. Root Cause Analysis

### A. Resist Caps — Why They Are Currently Missing

**Current state:** Companions inherit `Mob::GetMR()` which returns
`MR + itembonuses.MR + spellbonuses.MR` with NO cap enforcement.

The class hierarchy for resist handling:

| Entity | GetMR() behavior | Cap mechanism |
|--------|-----------------|---------------|
| **Mob (base)** | `MR + itembonuses.MR + spellbonuses.MR` | `GetMaxMR()` returns 255, but nothing calls it to enforce |
| **Client** | Just `MR` (pre-capped) | `CalcMR()` enforces `MR <= GetMaxMR()` (base 500) |
| **Bot** | Just `MR` (pre-capped) | `CalcMR()` enforces `MR <= GetMaxMR()` (base 500) |
| **NPC** | Inherits Mob (uncapped) | No CalcMR exists for NPCs |
| **Companion** | Inherits NPC → Mob (uncapped) | **No cap mechanism at all** |

**The gap:** NPCs never needed resist caps because their resists come from
`npc_types` database values which are authored by content designers. But
companions can stack base resists (from their NPC source) + item resists +
buff resists, potentially reaching unreasonable values.

Example: A level 60 companion with base MR 75 (from npc_types) + resist
gear (+100 MR from multiple items) + resist buffs (Resist Magic +40, etc.)
could reach MR 215+, making them highly resistant to magical effects.

**The fix:** Override `GetMR()`, `GetFR()`, `GetDR()`, `GetPR()`, `GetCR()`
in the Companion class to cap at `GetMaxResist()`. Also implement
`Companion::GetMaxResist()` matching the Client/Bot formula.

### B. Focus Effects — Why They Are Currently Broken

**Current state:** Companions inherit `NPC::GetFocusEffect()` which has
TWO independent problems:

**Problem 1: Rule gate blocks item focus effects**

At `spell_effects.cpp:6899`:
```cpp
if (RuleB(Spells, NPC_UseFocusFromItems) && itembonuses.FocusEffects[type]) {
```

`Spells:NPC_UseFocusFromItems` defaults to **false** (`ruletypes.h:488`).
This means item-derived focus effects are completely disabled for all NPCs,
including companions. Even though `CalcItemBonuses()` correctly populates
`itembonuses.FocusEffects[type]` when a focus item is equipped, the
`GetFocusEffect()` check short-circuits before iterating items.

**Problem 2: Wrong item access pattern**

Even if the rule were enabled, `NPC::GetFocusEffect()` at line 6910 uses:
```cpp
const EQ::ItemData *cur = database.GetItem(equipment[i]);
```

This reads from the NPC `equipment[]` array (raw item IDs from npc_types).
Companions store their equipped items in the **inventory profile** (via
`GetInv().PutItem()` in `GiveItem()`). The `equipment[]` array may not
reflect companion equipment. The correct access pattern is the Mob base
class pattern:
```cpp
EQ::ItemInstance* ins = GetInv().GetItem(x);
```

**Problem 3: Spell focus effects are partially working**

At `spell_effects.cpp:6949`:
```cpp
if ((RuleB(Spells, NPC_UseFocusFromSpells) || IsTargetedFocusEffect(type))
    && spellbonuses.FocusEffects[type]) {
```

`Spells:NPC_UseFocusFromSpells` defaults to **true**. So buff-derived focus
effects DO work for companions already. Only item-derived focus effects are
broken.

**The fix:** Override `GetFocusEffect()` in the Companion class. The override
should call `Mob::GetFocusEffect()` (the base class implementation) which
uses `GetInv().GetItem()` and has no `NPC_UseFocusFromItems` rule gate.
This bypasses both NPC-specific problems in one clean override.

### C. Balance Tuning — What Needs Evaluation

The balance pass requires Phases 1-4 + resist caps + focus effects all
active, then measuring:

1. **Melee DPS:** Compare companion warrior/rogue DPS with equivalent
   player character DPS at level 60 with matching gear.
2. **Tank survivability:** Compare companion warrior HP, AC, avoidance
   with equivalent player warrior.
3. **Healer effectiveness:** Verify companion cleric keeps the group alive
   in level-appropriate content.
4. **Caster DPS:** Compare wizard companion DPS with player wizard
   (factoring in AI vs human decision-making).

The balance pass is primarily a documentation/tuning exercise, not a code
exercise. The implementation consists of:
- A new rule `Companions::ResistCapFormula` (optional; the cap can be
  hardcoded matching Client formula).
- Recording current tuning knob values in a balance document.
- Recommending adjustments if needed.

---

## 3. Implementation Approach

### Task 1: Resist Cap System

**Files to modify:**
- `eqemu/zone/companion.h` — Declare `GetMaxResist()`, `GetMR()`, `GetFR()`,
  `GetDR()`, `GetPR()`, `GetCR()` overrides, and a new `ResistCap` rule
- `eqemu/zone/companion.cpp` — Implement resist cap overrides
- `eqemu/common/ruletypes.h` — Add `Companions::ResistCapBase` rule

**Implementation:**

```cpp
// companion.h — in public section, after CalcMaxHP override:

// -------------------------------------------------------
// Resist cap overrides — Phase 5
// -------------------------------------------------------
// Companions use Client-style resist caps to prevent immunity stacking.
// Base cap formula: level * 5 + ResistCapBase (default 50).
// GetMaxResist() returns the cap; Get{X}R() enforce it.
int32 GetMaxResist() const;
inline int32 GetMR() const override {
    return std::min(MR + itembonuses.MR + spellbonuses.MR, GetMaxResist());
}
inline int32 GetFR() const override {
    return std::min(FR + itembonuses.FR + spellbonuses.FR, GetMaxResist());
}
inline int32 GetDR() const override {
    return std::min(DR + itembonuses.DR + spellbonuses.DR, GetMaxResist());
}
inline int32 GetPR() const override {
    return std::min(PR + itembonuses.PR + spellbonuses.PR, GetMaxResist());
}
inline int32 GetCR() const override {
    return std::min(CR + itembonuses.CR + spellbonuses.CR, GetMaxResist());
}
```

```cpp
// companion.cpp
int32 Companion::GetMaxResist() const
{
    int rule_base = RuleI(Companions, ResistCapBase);
    if (rule_base <= 0) {
        // Rule set to 0 or negative = no cap (return very high value)
        return 32000;
    }
    // Classic-Luclin formula: base 500 for level 65
    // Simplified for companions: level * 5 + base
    // At level 60: 60 * 5 + 50 = 350
    // At level 65: 65 * 5 + 50 = 375
    // Client base is 500 for all levels up to 65.
    // For companions, use a lower cap to keep them below player power.
    return static_cast<int32>(GetLevel()) * 5 + rule_base;
}
```

**New rule:**
```cpp
RULE_INT(Companions, ResistCapBase, 50,
    "Phase 5: Base value for companion resist cap formula. "
    "Cap = level * 5 + this value. At level 60 with default 50, cap is 350. "
    "Set to 0 to disable resist capping entirely.")
```

**Design rationale for cap value:**

The Client resist cap is a flat 500 (for levels <= 65). Using `level*5 + 50`
gives a cap of 350 at level 60, which is 70% of the Client cap — matching
the 70-85% power target from the PRD. At level 60 with good resist gear
(+40-60 per resist from items) and resist buffs (+30-50), total resists
typically reach 150-250 for a well-buffed companion. The 350 cap only
activates in extreme stacking scenarios (e.g., base 100 MR NPC + full
resist gear + multiple resist buffs). This prevents immunity without
affecting normal gameplay.

### Task 2: Focus Effects Fix

**Files to modify:**
- `eqemu/zone/companion.h` — Declare `GetFocusEffect()` override
- `eqemu/zone/companion.cpp` — Implement the override

**Implementation:**

```cpp
// companion.h — in public section:

// -------------------------------------------------------
// Focus effect override — Phase 5
// -------------------------------------------------------
// Companions use the Mob base class GetFocusEffect() instead of the
// NPC override. The NPC override (a) gates item focus behind
// NPC_UseFocusFromItems rule (default false), and (b) reads items
// from the NPC equipment[] array instead of the inventory profile.
// Both are wrong for companions. The Mob base implementation uses
// GetInv().GetItem() (correct for companions) and has no rule gate.
int64 GetFocusEffect(focusType type, uint16 spell_id,
                     Mob *caster = nullptr,
                     bool from_buff_tic = false) override;
```

```cpp
// companion.cpp
int64 Companion::GetFocusEffect(focusType type, uint16 spell_id,
                                 Mob *caster, bool from_buff_tic)
{
    // Bypass NPC::GetFocusEffect (which uses NPC equipment[] array and
    // NPC_UseFocusFromItems rule gate). Call Mob::GetFocusEffect directly,
    // which uses GetInv().GetItem() — the correct access pattern for
    // companions whose items live in the inventory profile.
    return Mob::GetFocusEffect(type, spell_id, caster, from_buff_tic);
}
```

**Why this works:**

`Mob::GetFocusEffect()` (spell_effects.cpp:6512):
1. Checks `itembonuses.FocusEffects[type]` — this IS populated for companions
   because `NPC::CalcBonuses()` calls `CalcItemBonuses()` which sets it.
2. Iterates `GetInv().GetItem(x)` for equipment slots — companions populate
   their inventory profile via `GiveItem()` -> `GetInv().PutItem()`.
3. Also checks `spellbonuses.FocusEffects[type]` for buff-derived focus.
4. Has no NPC-specific rule gates.

This single override enables all item focus effects for companions without
needing to change any server-wide rules or modify NPC behavior.

### Task 3: Balance Documentation

**Files to create:**
- `claude/project-work/feature/npc-companion-realistic-stats/architect/context/balance-tuning.md`

**Content:**

Document current rule values and their effects:

| Rule | Default | Description | Phase 5 Recommendation |
|------|---------|-------------|----------------------|
| `Companions::StatScalePct` | 100 | Global stat multiplier | Start at 100, reduce if overpowered |
| `Companions::UseWeaponDamage` | true | Phase 1 master toggle | Keep true |
| `Companions::STAToHPFactor` | 100 | STA-to-HP conversion | Start at 100 |
| `Companions::SittingRegenMult` | 200 | Sitting regen 2x | Keep at 200 |
| `Companions::HealThresholdPct` | 80 | Healer trigger point | 80 is good |
| `Companions::ManaCutoffPct` | 20 | DPS nuke cutoff | 20 is good |
| `Companions::HealerManaConservePct` | 30 | Efficient heal threshold | 30 is good |
| `Companions::ResistCapBase` | 50 | Resist cap base | 50 gives 350@60 |

The balance document should include:
- Methodology for comparing companion vs player power
- Test scenarios (solo warrior companion tanking, full group DPS check)
- Recommended starting values
- What to adjust if companions are too strong or too weak

This task is documentation only — no code changes.

---

## 4. New Rules

```cpp
RULE_INT(Companions, ResistCapBase, 50,
    "Phase 5: Base value for companion resist cap formula. "
    "Cap = level * 5 + this value. At level 60 with default 50, cap is 350. "
    "Set to 0 to disable resist capping entirely.")
```

One new rule. All other Phase 5 functionality uses existing rules or
inherits from the Mob base class.

---

## 5. Test Requirements — Suite 15

Suite 15: "Phase 5 — Resist Caps + Focus Effects"

### Resist Cap Tests

**15.1: Rule ResistCapBase exists, default is 50**
- Setup: Query `RuleI(Companions, ResistCapBase)`.
- Expected: Returns 50.
- Discriminating: Will FAIL before the rule is added to ruletypes.h.

**15.2: GetMaxResist returns correct cap for level 60**
- Setup: Create a level 60 companion.
- Expected: `GetMaxResist()` returns 350 (60 * 5 + 50).
- Discriminating: Will FAIL before GetMaxResist is implemented (Mob base
  returns 255, but Companion has no override).

**15.3: GetMaxResist scales with level**
- Setup: Create companions at levels 1, 30, 60.
- Expected: GetMaxResist returns 55 (1*5+50), 200 (30*5+50), 350 (60*5+50).
- Discriminating: Same as 15.2.

**15.4: GetMR is capped at GetMaxResist**
- Setup: Create a level 60 companion. Set base MR to 200. Add itembonuses.MR = 100, spellbonuses.MR = 100. Total uncapped would be 400.
- Expected: GetMR() returns 350 (capped at GetMaxResist).
- Discriminating: Will FAIL before GetMR override (currently returns 400).

**15.5: GetFR is capped at GetMaxResist**
- Setup: Same pattern as 15.4 but for FR.
- Expected: GetFR() returns 350.

**15.6: GetDR is capped at GetMaxResist**
- Setup: Same pattern as 15.4 but for DR.
- Expected: GetDR() returns 350.

**15.7: GetPR is capped at GetMaxResist**
- Setup: Same pattern as 15.4 but for PR.
- Expected: GetPR() returns 350.

**15.8: GetCR is capped at GetMaxResist**
- Setup: Same pattern as 15.4 but for CR.
- Expected: GetCR() returns 350.

**15.9: Resists below cap are not reduced**
- Setup: Level 60 companion with base MR 50, itembonuses.MR = 30, spellbonuses.MR = 20. Total = 100.
- Expected: GetMR() returns 100 (below cap of 350, no clamping).
- Discriminating: Validates that the cap is a ceiling, not a modifier.

**15.10: ResistCapBase = 0 disables capping**
- Setup: Set ResistCapBase rule to 0. Level 60 companion with MR totaling 600.
- Expected: GetMR() returns 600 (cap disabled, returns 32000).
- Discriminating: Validates the disable mechanism.

**15.11: GetMaxResist for level 1 companion**
- Setup: Level 1 companion.
- Expected: GetMaxResist() returns 55 (1*5 + 50).
- This validates the formula doesn't break at low levels.

### Focus Effect Tests

**15.12: GetFocusEffect override calls Mob base, not NPC**
- Setup: Create a companion. Equip a focus item with a known Focus.Effect
  spell ID. Populate itembonuses.FocusEffects[type] appropriately.
- Action: Call GetFocusEffect(focusImprovedDamage, test_spell_id).
- Expected (after fix): Returns non-zero (focus applies).
- Before fix would FAIL: NPC::GetFocusEffect checks NPC_UseFocusFromItems
  (false), returns 0 for item focus.
- Note: This test requires mock spell data. If CalcFocusEffect cannot be
  called without full spell initialization, test at a structural level:
  verify that Companion::GetFocusEffect calls Mob::GetFocusEffect by
  checking that the item access pattern uses GetInv() not equipment[].

**15.13: Focus effect with no focus items returns 0**
- Setup: Create a companion with no equipment.
- Expected: GetFocusEffect returns 0 (no crash, clean zero).

**15.14: Spell-derived focus effects still work**
- Setup: Create a companion with spellbonuses.FocusEffects[focusImprovedDamage] set.
- Expected: GetFocusEffect returns the spell-derived focus value.
- This validates we didn't break spell focus by overriding GetFocusEffect.

**15.15: Focus effect reads from inventory profile, not equipment array**
- Setup: Create a companion. Put an item with Focus.Effect into the
  inventory profile via GetInv().PutItem(). Do NOT set it in equipment[].
- Action: Set itembonuses.FocusEffects appropriately. Call GetFocusEffect.
- Expected: Focus is found (reads from GetInv, not equipment[]).
- Discriminating: NPC::GetFocusEffect reads equipment[], would return 0.

### Balance Documentation Tests

**15.16: All Phase 5 rules exist**
- Setup: Check existence of ResistCapBase rule.
- Expected: Rule exists and has documented default value.

**15.17: All existing companion rules retain defaults**
- Setup: Verify StatScalePct=100, UseWeaponDamage=true, STAToHPFactor=100,
  SittingRegenMult=200, HealThresholdPct=80, ManaCutoffPct=20,
  HealerManaConservePct=30.
- Expected: All defaults match PRD specifications.
- Discriminating: Validates no accidental rule default changes during Phase 5.

**Total: 17 tests in Suite 15**

---

## 6. Implementation Order and Dependencies

| # | Task | Agent | Depends On | Est. Scope |
|---|------|-------|------------|------------|
| 1 | Add `ResistCapBase` rule to `ruletypes.h` | **c-expert** | — | Small (3 lines) |
| 2 | Declare resist cap + focus overrides in `companion.h` | **c-expert** | — | Small (15 lines) |
| 3 | Implement `GetMaxResist()`, resist getter overrides in `companion.cpp` | **c-expert** | 1, 2 | Small (15 lines) |
| 4 | Implement `GetFocusEffect()` override in `companion.cpp` | **c-expert** | 2 | Small (8 lines) |
| 5 | Write Suite 15 tests (TDD: tests first, then implementation) | **c-expert** | — | Medium (200-250 lines) |
| 6 | Insert `ResistCapBase` rule value into database | **data-expert** | 1 | Small (1 INSERT) |
| 7 | Create balance tuning documentation | **c-expert** | 3, 4 | Small (documentation) |
| 8 | Build, run all 15 suites, verify | **c-expert** | 1-5 | Medium |

**Recommended TDD order:**
1. Write Suite 15 tests (all FAILING)
2. Add rule to ruletypes.h (15.1, 15.16 pass)
3. Add declarations to companion.h
4. Implement GetMaxResist + resist overrides (15.2-15.11 pass)
5. Implement GetFocusEffect override (15.12-15.15 pass)
6. Run all 15 suites (204 existing + 17 new = 221 tests)
7. Write balance documentation

**Total estimated code changes: ~60 lines of C++ implementation + ~250 lines of tests**

This is a small phase. The resist caps are simple clamping overrides. The
focus effect fix is a single-line delegation to the Mob base class.

---

## 7. Balance Pass Details

### Metrics to Validate

The PRD target is 70-85% of player character power. The specific metrics:

#### Melee DPS (70-85% target)

**Measure:** Total damage dealt per minute against a known target NPC.

**Variables:**
- Weapon damage and delay (Phase 1) — identical to player with same weapon
- Damage bonus (Phase 2) — identical to player (same formula)
- Double attack chance — from SkillCaps, identical to player
- Triple attack chance — from Companion::CheckTripleAttack(), ~20-25% at 60
- Stats (STR for damage, DEX for crit) — from npc_types base + item/spell bonuses, scaled by StatScalePct
- Critical hits — from Mob::TryCriticalHit, same formula for all

**Expected shortfall vs player:** Companions lack AAs (no combat fury, no
ambidexterity, no slaying strike). AA combat abilities add roughly 10-20%
DPS at level 60 with good AA investment. This naturally places companions
at 80-90% of player DPS even with identical gear. If this is too high,
reduce `StatScalePct` to 85-90.

#### Tank Survivability (70-85% target)

**Measure:** Time to death against a known DPS mob.

**Variables:**
- HP — base from npc_types + STA-to-HP conversion (Phase 3)
- AC — from npc_types base + item AC + defense skill / 3 (Phase 3)
- Avoidance — dodge/parry/riposte from SkillCaps, identical to player
- Resists — capped at 350 at level 60 (Phase 5)

**Expected shortfall vs player:** Companions lack AA defensive abilities
(no combat agility, no physical enhancement, no natural durability). Player
warriors also benefit from disciplines (defensive, evasive). These are
significant: AA + disciplines can add 15-25% effective HP. This naturally
places companion tanks at 75-85% of player tank survival.

#### Healer Effectiveness

**Measure:** Can a cleric companion keep a warrior companion alive tanking
a level 60 mob in Classic-Luclin content?

**Variables:**
- Heal amount — from spell data (same as player) + focus effects (Phase 5)
- Heal timing — from AI thresholds (Phase 4: 80% trigger)
- Mana pool — from npc_types base + INT/WIS bonuses
- Mana regen — from meditation formula + CompanionManaRegenMult

**Expected behavior:** With Phase 4 AI tuning, healers should be reliable
for group content. The AI will never match a human healer's ability to
pre-heal or chain-cast, but the 80% threshold + efficient heal switching
should provide adequate group healing.

### Tuning Knobs Available

| Knob | Current | Effect of Increase | Effect of Decrease |
|------|---------|-------------------|-------------------|
| `StatScalePct` | 100 | More STR/STA/etc = more damage + HP | Less damage + HP |
| `STAToHPFactor` | 100 | More HP from STA gear | Less HP from STA gear |
| `ResistCapBase` | 50 | Higher resist cap = more resist stacking | Lower cap = less resist immunity |
| `HealThresholdPct` | 80 | Earlier healing = more mana used | Later healing = more mana efficient |
| `ManaCutoffPct` | 20 | More mana reserve = less DPS | Less reserve = more DPS |
| `SittingRegenMult` | 200 | Faster downtime recovery | Slower recovery |

### Recommended Starting Configuration

Start with all defaults. The natural AA gap between companions and players
should provide the 70-85% power differential without requiring rule tuning.

If testing shows companions are overpowered:
1. First reduce `StatScalePct` to 90 (10% stat reduction across the board)
2. If still too strong, reduce `STAToHPFactor` to 80 (less HP from gear)
3. If DPS specifically is too high, companions don't have a dedicated DPS
   multiplier rule — one could be added as `Companions::DamageOutputPct`
   but defer unless needed

If testing shows companions are underpowered:
1. Verify all Phases 1-4 are working correctly
2. Consider increasing `StatScalePct` to 110
3. Consider reducing `ManaCutoffPct` to 10 for more caster DPS

---

## 8. Regression Risks

### Resist Cap Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Resist cap set too low, companions get debuffed/nuked too easily | Low | Medium | Rule-based cap; adjustable via `#rules set`. Start at 350@60 which is generous. |
| GetMR/GetFR override introduces compilation error due to inline virtual | Low | Build fail | Use exact same pattern as Mob base class (inline virtual with override keyword). |
| Resist cap affects spell resist checks incorrectly | Very Low | Medium | Resist checks use `GetMR()` etc. which now returns capped value. This is the correct behavior — it's what Client does too. |

### Focus Effect Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Mob::GetFocusEffect reads GetInv() items that don't exist | Low | Crash | GetInv().GetItem(x) returns nullptr for empty slots; Mob::GetFocusEffect already handles nullptr (line 6543-6546). |
| Focus effects make companion casters too powerful | Low | Balance | Focus items in Classic-Luclin era are modest (5-25% improvement). Not game-breaking. |
| Overriding GetFocusEffect breaks buff-derived focus | Very Low | Spell focus | Mob::GetFocusEffect handles both item AND spell focus. The NPC override also handles spell focus. By calling Mob:: we get both. Test 15.14 validates this. |
| CalcItemBonuses doesn't populate FocusEffects for companion items | Low | Focus not found | CalcItemBonuses uses GetInv().GetItem() (bonuses.cpp:32-60 shows NPC::CalcBonuses calls CalcItemBonuses). Verify in testing. |

### Balance Pass Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Companions are overpowered after all phases | Medium | Game balance | StatScalePct is the primary tuning knob. Can be adjusted from 100 to 80-90 without code changes. |
| Companions are underpowered | Low | Player frustration | Increase StatScalePct or review if Phases 1-4 are working correctly. |

### Cross-Phase Regression

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Phase 5 changes break Phase 1-4 tests | Very Low | Test failure | Run all 15 suites (204+ existing tests) after Phase 5 changes. No existing code is modified — only new overrides added. |
| inline resist getters conflict with existing Mob inline virtuals | Low | Compilation | The pattern is well-established (see mob.h:627-631 for existing inline virtual getters). |

---

## 9. Summary

Phase 5 is the smallest phase in terms of code changes:

- **Resist caps:** ~15 lines of implementation (5 inline overrides + GetMaxResist)
- **Focus effects:** 8 lines (override that delegates to Mob::GetFocusEffect)
- **New rule:** 3 lines in ruletypes.h
- **Tests:** ~250 lines (17 tests in Suite 15)
- **Balance doc:** Documentation only

The resist cap implementation follows the exact pattern used by Client and
Bot (GetMaxResist + clamping). The focus effect fix is a single override
that correctly routes around the NPC-specific equipment access pattern.

Both changes are clean Companion class additions with no modifications to
existing NPC, Mob, Client, or Bot code. Zero regression risk to non-companion
entities.

**Required agents:** c-expert (Tasks 1-5, 7-8), data-expert (Task 6)
