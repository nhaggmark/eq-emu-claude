# Phase 2-4 Audit Fix Plan

> **Feature branch:** `feature/npc-companion-realistic-stats`
> **Author:** architect
> **Date:** 2026-03-11
> **Status:** Ready for Implementation

---

## Overview

This plan addresses 8 issues identified during the Phase 2-4 audit, organized by
priority. Each issue includes root cause analysis with file:line references, the
specific fix approach, any new rules needed, comprehensive test requirements, and
regression risks.

**Recommended implementation order:**
1. Issue #1 (Critical: sitting regen timing) — must be first, fixes a live bug
2. Issue #4 (Medium: int8 overflow) — trivial, prevents potential crash
3. Issue #2 (Medium: magician hardcoded mana cutoff) — consistency fix
4. Issue #3 (Medium: enchanter no mana reserve) — correctness fix
5. Issue #7 (Enhancement: necro pet spam) — quality improvement
6. Issue #8 (Enhancement: wizard DS spam) — quality improvement
7. Issue #5 (Enhancement: druid HoT preference) — feature addition
8. Issue #6 (Enhancement: shaman cannibalize) — feature addition

Issues #1-4 have no inter-dependencies. Issues #5-8 have no inter-dependencies.
All can technically be implemented in any order, but the recommended order
prioritizes correctness fixes before enhancements.

---

## Test Infrastructure Notes

**Existing test suites:** 13 suites (177 tests, 2 expected skips) in
`eqemu/zone/cli/tests/cli_companion_tests.cpp`.

**Recommendation:** Create **Suite 14** ("Phase 2-4 Audit Fixes") to hold all
new tests for these 8 issues. Organize tests as 14.1-14.N with sub-numbering
by issue. This keeps the audit fixes grouped and avoids renumbering existing
suites.

**Test companion creation:** The existing `CreateTestCompanionByClass()` utility
in `cli_companion_test_util.h` provides the scaffolding for creating test
companions with specific classes and levels.

---

## Issue #1: Sitting Regen Timing Bug (CRITICAL)

### Root Cause Analysis

**File:** `eqemu/zone/companion.cpp`, lines 1556-1582

The sitting regen bonus code runs in `Companion::Process()` BEFORE
`NPC::Process()` is called. `Companion::Process()` runs on every entity
tick (~100-250ms depending on zone frame rate). However, NPC regen in
`NPC::Process()` is gated behind `tic_timer.Check()` (`npc.cpp:630`) which
fires every 6 seconds (one EQ "tic").

The sitting regen code at line 1568:
```cpp
if (IsSitting() && !IsEngaged() && GetHP() < GetMaxHP()) {
    int mult = RuleI(Companions, SittingRegenMult);
    if (mult > 100) {
        int ooc_pct = RuleI(Companions, OOCRegenPct);
        if (ooc_pct > 0) {
            int64 base_ooc = (GetMaxHP() * ooc_pct) / 100;
            int64 sitting_bonus = (base_ooc * (mult - 100)) / 100;
            if (sitting_bonus > 0) {
                SetHP(std::min(GetHP() + sitting_bonus, GetMaxHP()));
            }
        }
    }
}
```

This applies the sitting bonus on EVERY Process() call (24-60 times per
6-second tic) instead of once per tic. At default values (SittingRegenMult=200,
OOCRegenPct=5), a companion with 10,000 max HP gets:
- **Intended:** 500 HP bonus per 6-second tic (base_ooc=500, mult bonus=500)
- **Actual:** 500 HP bonus per ~150ms tick = ~12,000-20,000 HP per 6-second tic
- **Overregen factor:** 24-40x the intended amount

This means a sitting companion heals to full HP almost instantly regardless
of max HP, completely breaking combat pacing.

### Fix Approach

Gate the sitting regen bonus behind the same 6-second cadence as NPC regen.
Two approaches:

**Option A (Recommended):** Add a `Timer m_sitting_regen_timer(6000)` member
to Companion. Check it in Process() before applying the sitting bonus. This
is clean, self-contained, and doesn't require access to `tic_timer` (which
is a `Mob` member but not easily referenced from Companion).

**Option B:** Move the sitting regen code to AFTER `NPC::Process()` and
detect whether `tic_timer` fired by comparing HP before and after. This
is fragile and creates coupling.

**Implementation (Option A):**

1. In `companion.h`, add a timer member:
   ```cpp
   Timer m_sitting_regen_timer;  // 6-second cadence for sitting HP bonus
   ```

2. In the Companion constructor (`companion.cpp`), initialize:
   ```cpp
   m_sitting_regen_timer(6000)
   ```

3. In `Companion::Process()`, replace lines 1568-1582 with:
   ```cpp
   if (IsSitting() && !IsEngaged() && GetHP() < GetMaxHP()
       && m_sitting_regen_timer.Check()) {
       int mult = RuleI(Companions, SittingRegenMult);
       if (mult > 100) {
           int ooc_pct = RuleI(Companions, OOCRegenPct);
           if (ooc_pct > 0) {
               int64 base_ooc = (GetMaxHP() * ooc_pct) / 100;
               int64 sitting_bonus = (base_ooc * (mult - 100)) / 100;
               if (sitting_bonus > 0) {
                   SetHP(std::min(GetHP() + sitting_bonus, GetMaxHP()));
               }
           }
       }
   }
   ```

### New Rules Needed

None. Uses existing `SittingRegenMult` and `OOCRegenPct`.

### Test Requirements

**Test 14.1: Sitting regen fires at most once per 6-second interval**
- **Setup:** Create a level 60 warrior companion. Set HP to 50% of max.
  Set companion to sitting state. Record current HP.
- **Action:** Call `Process()` in a tight loop 100 times (simulating ~25
  seconds of 250ms ticks).
- **Expected (after fix):** HP increases by the sitting bonus amount at
  most 4-5 times (once per ~6s across ~25s). Total HP gain should be
  approximately 4-5x the per-tic sitting bonus.
- **Before fix would FAIL:** HP would increase 100 times (once per call),
  resulting in ~100x the intended gain.
- **Mock/setup:** Need to be able to call Process() repeatedly. The test
  timer may need to be advanced manually — if Timer uses real clock, the
  test may need to sleep briefly or mock time. If testing is impractical
  due to Timer dependency, use a simpler discriminating test: call Process()
  twice rapidly and verify HP increased at most once.

**Test 14.2: Sitting regen does not fire when standing**
- **Setup:** Same as 14.1, but companion is standing (not sitting).
- **Action:** Call Process() multiple times.
- **Expected:** No sitting bonus HP applied (only NPC::Process() regen).

**Test 14.3: Sitting regen does not fire when engaged in combat**
- **Setup:** Same as 14.1, but companion has a target and IsEngaged()=true.
- **Action:** Call Process() multiple times.
- **Expected:** No sitting bonus HP applied.

**Test 14.4: Timer member exists and is initialized**
- **Setup:** Create a companion.
- **Expected:** `m_sitting_regen_timer` is a valid Timer with a ~6000ms
  interval. (This may be tested by verifying the timer doesn't immediately
  fire on first Process() call if constructed with `enabled=false` initially.)

### Regression Risks

- **Timer initialization race:** If the timer is not initialized in the
  constructor's initializer list, it could have undefined state. Ensure it's
  in the initializer list.
- **Timer not firing at all:** If the timer starts disabled, the sitting
  bonus would never fire. Initialize enabled or call `Start()` during
  construction / AI_Start().
- **NPC::Process() sitting bonus (+3) unaffected:** The NPC sitting bonus
  of +3 HP per tic at `npc.cpp:650-651` is separate and runs on tic_timer
  cadence already. This fix does not touch that path.

---

## Issue #2: Magician Hardcoded Mana Cutoff (MEDIUM)

### Root Cause Analysis

**File:** `eqemu/zone/companion_ai.cpp`, line 1279

In `AI_Magician()`, the nuke mana guard is:
```cpp
if ((iSpellTypes & SpellType_Nuke) && GetManaRatio() > 20.0f) {
```

This uses a hardcoded `20.0f` instead of `RuleI(Companions, ManaCutoffPct)`.
While the current default of ManaCutoffPct is 20 (so behavior matches), if a
server operator changes ManaCutoffPct via `#rules set`, the magician will
ignore the change while all other DPS casters (wizard, necromancer) respect it.

For comparison:
- **Wizard** (line 1245): `GetManaRatio() > static_cast<float>(RuleI(Companions, ManaCutoffPct))` — CORRECT
- **Necromancer** (line 1314): `GetManaRatio() > static_cast<float>(RuleI(Companions, ManaCutoffPct))` — CORRECT
- **Magician** (line 1279): `GetManaRatio() > 20.0f` — WRONG

### Fix Approach

Replace the hardcoded `20.0f` with the rule:

```cpp
// Line 1279, change:
if ((iSpellTypes & SpellType_Nuke) && GetManaRatio() > 20.0f) {
// To:
if ((iSpellTypes & SpellType_Nuke) &&
    GetManaRatio() > static_cast<float>(RuleI(Companions, ManaCutoffPct))) {
```

### New Rules Needed

None. Uses existing `ManaCutoffPct`.

### Test Requirements

**Test 14.5: Magician respects ManaCutoffPct rule**
- **Setup:** Create a magician companion. Load spells. Set mana to 15% of max
  (below default ManaCutoffPct of 20).
- **Action:** Call `AI_Magician()` with `SpellType_Nuke` in spell types, engaged=true.
- **Expected (after fix):** Returns false (no nuke attempted because mana < 20%).
- **Before fix would FAIL:** The hardcoded 20.0f would also block it, BUT this
  test is about demonstrating the rule is used. A more discriminating test:

**Test 14.6: Magician obeys dynamic ManaCutoffPct change**
- **Setup:** Create a magician companion with mana at 18%. Temporarily set
  `Companions:ManaCutoffPct` to 15 via rule override.
- **Expected (after fix):** AI_Magician allows nuking (18% > 15%).
- **Before fix would FAIL:** Magician uses hardcoded 20.0f, so 18% < 20%
  would still block nuking despite the rule saying 15%.
- **Mock/setup:** Requires ability to set rule values in test context. If
  `RuleManager::Instance()->SetRule()` is available, use it. Otherwise,
  test at boundary: set mana to 19% and verify behavior differs from 21%.

### Regression Risks

- **None significant.** The current value matches the rule default. The only
  risk is if someone had intentionally set the rule to a different value and
  magicians were already "correctly" ignoring it — but that would be a bug,
  not intentional.

---

## Issue #3: Enchanter No Mana Reserve for Emergency Mez (MEDIUM)

### Root Cause Analysis

**File:** `eqemu/zone/companion_ai.cpp`, lines 1375-1378

In `AI_Enchanter()`, the nuke path has no mana guard:
```cpp
// Nuke when aggressive
if ((iSpellTypes & SpellType_Nuke) && m_current_stance == COMPANION_STANCE_AGGRESSIVE) {
    return AI_NukeTarget(SpellType_Nuke);
}
```

Enchanters will nuke until the global 10% OOM bail in `AICastSpell()` fires.
This leaves insufficient mana for emergency mez (their most critical ability).
A mez at level 60 costs ~200 mana; if the enchanter nukes to 10% mana on a
3000 mana pool, they have 300 mana — enough for one mez. But if a second add
comes, they're useless.

The PRD specifies enchanters should "reserve at least 15% mana for emergency
mez" and "stop nuking/DoTing below 30% mana."

### Fix Approach

Add a mana guard to the enchanter nuke path, using a higher threshold than
ManaCutoffPct to reserve mana for mez. Since enchanters need more mana
reserve than pure DPS casters, use a hardcoded 30% or, better, use a
value of `ManaCutoffPct + 10` (so it tracks with rule changes).

**Recommended: Use `ManaCutoffPct + 10`** (defaults to 30) rather than
introducing yet another rule. This keeps the rule count manageable while
still being tunable.

```cpp
// Line 1375-1378, change:
// Nuke when aggressive
if ((iSpellTypes & SpellType_Nuke) && m_current_stance == COMPANION_STANCE_AGGRESSIVE) {
    return AI_NukeTarget(SpellType_Nuke);
}
// To:
// Nuke when aggressive — reserve extra mana for emergency mez.
// Uses ManaCutoffPct + 10 (default 30%) to ensure mez capability.
if ((iSpellTypes & SpellType_Nuke) && m_current_stance == COMPANION_STANCE_AGGRESSIVE &&
    GetManaRatio() > static_cast<float>(RuleI(Companions, ManaCutoffPct) + 10)) {
    return AI_NukeTarget(SpellType_Nuke);
}
```

### New Rules Needed

None. Uses `ManaCutoffPct + 10` as the enchanter nuke threshold.

### Test Requirements

**Test 14.7: Enchanter stops nuking at ManaCutoffPct+10 (default 30%)**
- **Setup:** Create an enchanter companion. Set stance to AGGRESSIVE. Set
  mana to 25% (below 30% threshold but above 20% global cutoff). Give it
  a nuke spell in m_companion_spells. Set engaged state.
- **Action:** Call `AI_Enchanter()` with SpellType_Nuke in spell types.
- **Expected (after fix):** Returns false — nuke blocked because 25% < 30%.
- **Before fix would FAIL:** Nuke would be attempted (no mana guard existed).

**Test 14.8: Enchanter still nukes above threshold**
- **Setup:** Same as 14.7 but mana at 35%.
- **Expected:** Nuke is attempted (35% > 30%).

**Test 14.9: Enchanter mez still works at low mana**
- **Setup:** Enchanter with mana at 15%. Has mez spell. Engaged with
  multiple hostiles (or at least AI_MezTarget returns a valid target).
- **Expected:** Mez is attempted (mez has no mana cutoff — it's always
  the highest priority). This test verifies that mez remains functional
  even when nukes are blocked.
- **Note:** This test may be hard to set up without mocking entity_list.
  If so, verify that the mez path (lines 1355-1358) has no mana guard.

### Regression Risks

- **Reduced enchanter DPS in aggressive stance.** Enchanters will stop
  nuking sooner (30% vs effectively 10%). This is the intended behavior
  — enchanters are CC utility, not DPS.
- **Edge case: ManaCutoffPct set to 0.** Then threshold is 10%. Still
  reasonable for enchanter mez reserve.

---

## Issue #4: int8 Cast Overflow in AI_HealGroupMember (MEDIUM)

### Root Cause Analysis

**File:** `eqemu/zone/companion_ai.cpp`, line 418

```cpp
int8 lowest_hp = engaged ? static_cast<int8>(RuleI(Companions, HealThresholdPct)) : 99;
```

`int8` is a signed 8-bit integer with range -128 to 127. `HealThresholdPct`
defaults to 80, which fits. But if a server operator sets it above 127
(e.g., 130, meaning "heal below 130%", which is nonsensical but legal as a
rule value), the `static_cast<int8>` silently overflows to a negative number
(-126 for 130), meaning the healer would NEVER heal anyone (no one's HP
ratio is below -126%).

The same `int8` type is used for `self_hp` (line 402, 444) and `hpr`
(line 427), which are `GetHPRatio()` return values (double->int8 truncation).
HP ratio is always 0-100, so these won't overflow. But the pattern is
still fragile — if a buff/spell pushes HP above max, GetHPRatio() could
return >100.

### Fix Approach

Change all `int8` HP ratio variables in `AI_HealGroupMember()` to `int`:

```cpp
// Line 418, change:
int8 lowest_hp = engaged ? static_cast<int8>(RuleI(Companions, HealThresholdPct)) : 99;
// To:
int lowest_hp = engaged ? RuleI(Companions, HealThresholdPct) : 99;

// Line 402, change:
int8 self_hp = static_cast<int8>(GetHPRatio());
// To:
int self_hp = static_cast<int>(GetHPRatio());

// Line 427, change:
int8 hpr = static_cast<int8>(g->members[i]->GetHPRatio());
// To:
int hpr = static_cast<int>(g->members[i]->GetHPRatio());

// Line 444, change:
int8 self_hp = static_cast<int8>(GetHPRatio());
// To:
int self_hp = static_cast<int>(GetHPRatio());
```

### New Rules Needed

None.

### Test Requirements

**Test 14.10: HealThresholdPct at boundary value 127 works correctly**
- **Setup:** Set `HealThresholdPct` to 127. Create a cleric companion.
  Group member at 126% HP ratio (impossible in practice but validates the
  type). Actually, more practically: set rule to 100 and verify behavior.
- **Expected:** Healer attempts to heal when any member is below 100% HP.

**Test 14.11: HealThresholdPct at value > 127 does not cause negative wrap**
- **Setup:** Temporarily set `HealThresholdPct` to 200 (absurd but legal).
  Create a cleric companion in a group.
- **Expected (after fix):** `lowest_hp` = 200. No group member's HP ratio
  exceeds 200, so healer always attempts to heal anyone below 200% HP
  (i.e., everyone). This is a degenerate case but NOT broken.
- **Before fix would FAIL:** `static_cast<int8>(200)` = -56. No one has
  HP ratio below -56, so healer never heals.
- **Mock/setup:** Requires ability to set rule value to 200 in test context.

**Test 14.12: Normal HealThresholdPct (80) works correctly**
- **Setup:** Default rule (80). Cleric companion in group. One member at 75% HP.
- **Expected:** Healer selects that member as heal target.

### Regression Risks

- **None.** Widening from `int8` to `int` only increases range. All existing
  values (0-100 for HP ratio, 80 for default threshold) fit in both types.
  The implicit comparison `hpr >= lowest_hp` works identically for `int`.

---

## Issue #5: Druid HoT Preference (ENHANCEMENT)

### Root Cause Analysis

**File:** `eqemu/zone/companion_ai.cpp`, lines 954-1019

`AI_Druid()` calls `AI_HealGroupMember()` which calls `SelectHealSpell()`
(or `SelectEfficientHealSpell()` when mana-conserving). These shared helpers
select heals without distinguishing between HoT (heal-over-time) and direct
heals. The PRD specifies druids should prefer HoTs when the target is above
50% HP and switch to direct heals below 50%.

The issue: the `companion_spell_sets` table tags HoT spells (like Chloroplast,
Regrowth, Nature's Recovery) as `SpellType_Heal` alongside direct heals
(like Greater Healing). The `SelectHealSpell()` function picks the first
valid heal by slot order, not by spell characteristics.

### Fix Approach

Add a druid-specific heal selection path in `AI_Druid()` that chooses
between HoT and direct heal based on target HP:

1. **New helper function:** `SelectHoTSpell()` — iterates companion spells
   for `SpellType_Heal`, filters for spells with duration > 0 AND that have
   a `SE_HealOverTime` (effect ID 100) or `SE_CurrentHP` with duration.
   A simpler heuristic: any heal spell with `spells[id].buff_duration > 0`
   is a HoT.

2. **In AI_Druid engaged heal path:** Replace the single
   `AI_HealGroupMember(true)` call with:
   ```cpp
   // Druid heal preference: HoT above 50% HP, direct below 50%
   if (iSpellTypes & SpellType_Heal) {
       Group* g = GetGroup();
       Mob* heal_target = FindMostInjuredGroupMember(g, RuleI(Companions, HealThresholdPct));
       if (heal_target) {
           int target_hp_pct = static_cast<int>(heal_target->GetHPRatio());
           uint16 heal_spell = 0;
           if (target_hp_pct > 50) {
               // Above 50%: prefer HoT for efficiency
               heal_spell = SelectHoTSpell(m_companion_spells, m_current_stance, target_hp_pct, Timer::GetCurrentTime());
           }
           if (!heal_spell) {
               // Below 50% or no HoT available: use direct heal
               heal_spell = SelectHealSpell(m_companion_spells, m_current_stance, target_hp_pct, Timer::GetCurrentTime());
           }
           if (heal_spell) {
               return AIDoSpellCast(heal_spell, heal_target, spells[heal_spell].mana);
           }
       }
   }
   ```

3. **Extract `FindMostInjuredGroupMember()`** from `AI_HealGroupMember()`
   into a reusable helper, or duplicate the target-finding logic in
   AI_Druid. Duplication is acceptable since it's < 20 lines and the
   druid's logic diverges from the shared path.

### New Rules Needed

None. The 50% HP threshold for HoT vs direct heal preference could be a
rule, but for simplicity, hardcode it at 50. This can be parameterized
later if needed.

### Test Requirements

**Test 14.13: Druid prefers HoT above 50% HP**
- **Setup:** Create a druid companion with both a HoT spell (buff_duration > 0)
  and a direct heal (buff_duration = 0) in m_companion_spells. Set up a
  group member at 65% HP. Engaged state.
- **Action:** Call AI_Druid() or the relevant heal selection.
- **Expected (after fix):** The HoT spell is selected.
- **Before fix would FAIL:** SelectHealSpell picks whichever comes first
  by slot, which may be the direct heal.
- **Mock/setup:** Requires adding test spells to m_companion_spells manually.
  May need to mock spells[] data with appropriate buff_duration values.

**Test 14.14: Druid uses direct heal below 50% HP**
- **Setup:** Same as 14.13 but group member at 35% HP.
- **Expected:** Direct heal is selected (or at least, the HoT path is
  bypassed and SelectHealSpell is used).

**Test 14.15: Druid falls back to direct heal when no HoT available**
- **Setup:** Druid with only direct heal spells (no HoTs). Target at 65% HP.
- **Expected:** Direct heal is selected (fallback path).

### Regression Risks

- **Druid healing delay:** If the HoT selection path takes too long to
  iterate spells, healing could be delayed. Unlikely given spell list
  size is small (< 20 spells per companion).
- **HoT misidentification:** If `buff_duration > 0` incorrectly identifies
  a non-HoT buff-type heal, the druid might cast an inappropriate spell.
  Mitigate by also checking that the spell has SpellType_Heal tag.
- **Target already has HoT running:** If the HoT is already ticking on
  the target, `CanBuffStack()` should prevent re-casting. No additional
  check needed.

---

## Issue #6: Shaman Cannibalize (ENHANCEMENT)

### Root Cause Analysis

**File:** `eqemu/zone/companion_ai.cpp`, lines 1026-1084

The PRD describes shamans using Cannibalize (HP to mana conversion) when
mana drops below 40% and HP is above 80%. This is not implemented. The
shaman AI has no mana-recovery logic beyond natural meditation regen.

Cannibalize is a defining shaman class ability in Classic-Luclin:
- Cannibalize I (level 23): costs 100 HP, returns ~100 mana
- Cannibalize II (level 35): costs 150 HP, returns ~250 mana
- Cannibalize III (level 49): costs 200 HP, returns ~420 mana
- Cannibalize IV (level 55): costs 250 HP, returns ~600 mana

These are self-only spells that trade HP for mana. In the spell data,
they use spell effect `SE_CurrentMana` (mana gain) with `SE_CurrentHP`
(HP loss) as side effects.

### Fix Approach

This requires two coordinated changes:

**Part A — Data:** Cannibalize spells must be tagged in `companion_spell_sets`
with a recognizable spell type. Since there's no `SpellType_Cannibalize`,
the simplest approach is to tag them as `SpellType_Lifetap` (self-targeted
lifetap that works in reverse: HP -> mana). OR, add a new dedicated
SpellType flag. Since we're out of common bits (22 of 32 used), a simpler
approach is to use `SpellType_HateRedux` (bit 17, currently unused by
companions) as a surrogate tag for "self-mana-recovery" spells. This is
a pragmatic hack.

**Better approach:** Don't use SpellType tagging at all. Instead, identify
Cannibalize spells by their spell data characteristics. In the AI, look
for self-only spells in the companion's spell list that have `SE_CurrentMana`
effect with a positive base value (mana gain). This is cleaner and requires
no data changes.

**Part B — AI Logic:** In `AI_Shaman()`, add a Cannibalize check after
healing priorities. When mana < 40% and HP > 80%, attempt to cast a
Cannibalize spell:

```cpp
// In AI_Shaman(), engaged block, after heal/cure, before DoT:
// Cannibalize: convert HP to mana when mana is low and HP is healthy.
// This is the shaman's signature mana recovery ability.
if (GetMaxMana() > 0 && GetManaRatio() < 40.0f && GetHPRatio() > 80.0f) {
    uint16 canni_spell = FindCannibalizeSpell();
    if (canni_spell) {
        bool cast_ok = AIDoSpellCast(canni_spell, this, spells[canni_spell].mana);
        if (cast_ok) {
            SetSpellTimeCanCast(canni_spell, spells[canni_spell].recast_time);
            return true;
        }
    }
}
```

Also add to idle path (when sitting and low mana, canni to refuel faster).

**New helper:** `FindCannibalizeSpell()` scans `m_companion_spells` for
spells with `spells[id].effect_id[slot] == SE_CurrentMana` and
`spells[id].base_value[slot] > 0` (positive mana effect) that are
self-only (`target_type == ST_Self`). Returns the highest-level match.

### New Rules Needed

**Optional:** `Companions::CannibalizeHPPct` (default 80) — HP threshold
above which shaman will use Cannibalize. `Companions::CannibalizeManaThresholdPct`
(default 40) — mana threshold below which shaman will use Cannibalize.

For now, hardcode these at 80% HP and 40% mana. Add rules only if tuning
is needed.

### Test Requirements

**Test 14.16: FindCannibalizeSpell identifies correct spell**
- **Setup:** Create a shaman companion. Manually add a mock spell to
  m_companion_spells that has SE_CurrentMana effect with positive value
  and is self-only.
- **Expected:** FindCannibalizeSpell() returns the spell ID.

**Test 14.17: Shaman attempts Cannibalize when mana < 40% and HP > 80%**
- **Setup:** Shaman companion with canni spell loaded. Set mana to 30%,
  HP to 90%. Engaged state.
- **Expected (after fix):** Cannibalize path is taken.
- **Before fix would FAIL:** No canni logic exists.
- **Note:** Actual spell casting may fail without full zone context. Test
  the condition check, not the cast result.

**Test 14.18: Shaman does NOT Cannibalize when HP < 80%**
- **Setup:** Same as 14.17 but HP at 60%.
- **Expected:** Cannibalize path is NOT taken (HP too low, unsafe).

**Test 14.19: Shaman does NOT Cannibalize when mana > 40%**
- **Setup:** Same as 14.17 but mana at 60%.
- **Expected:** Cannibalize path is NOT taken (mana is fine).

**Test 14.20: Cannibalize spells are in companion_spell_sets**
- **This is a data-expert task:** Verify that Cannibalize I-IV are
  present in companion_spell_sets for shaman class at appropriate levels.
  This test would be a SQL query, not a C++ test.

### Regression Risks

- **Shaman kills itself with Cannibalize:** If HP drops below a safe
  threshold during combat, the shaman could cannibalize into a dangerous
  HP range. Mitigate with the HP > 80% guard.
- **FindCannibalizeSpell performance:** Scanning spell effects for every
  AI tick is O(n*12) where n is the number of shaman spells (~15) and 12
  is effects per spell. This is ~180 comparisons per tick, which is
  negligible.
- **Spell data dependency:** If Cannibalize spells are not in
  companion_spell_sets, the feature does nothing (safe degradation).
  Requires data-expert to add the spells.

---

## Issue #7: Necromancer Pet Spam at Low Mana (ENHANCEMENT)

### Root Cause Analysis

**File:** `eqemu/zone/companion_ai.cpp`, lines 1304-1309

```cpp
// Maintain pet
if (iSpellTypes & SpellType_Pet) {
    if (AI_SummonPet()) {
        return true;
    }
}
```

This runs unconditionally — the necromancer always attempts to summon a pet
if it doesn't have one, regardless of mana level. `AI_SummonPet()` (line 698)
calls `AIDoSpellCast()` which does check if the caster has enough mana for
the spell. If mana is insufficient, the cast fails and returns false. But
this happens EVERY AI tick, causing:

1. Wasted AI cycles — the necro checks for pet summon, finds a spell,
   attempts to cast, fails mana check, returns false — every tick.
2. The pet summon check is BEFORE DoT/nuke/lifetap logic (lines 1311-1330).
   When it returns false, execution falls through to the damage logic. So
   behavior is correct, but the unnecessary cast attempt adds overhead.
3. More importantly: at very low mana (e.g., 5%), the necro might have
   enough mana for a lifetap (cheap) but will waste time trying to summon
   a pet (expensive) first, delaying the lifetap.

The fix should add a mana threshold for pet summoning. A pet summon spell
typically costs 200-600 mana. At 25% mana on a 3000-mana necro, that's
750 mana — barely enough for a level 60 pet summon. Below 25%, pet summoning
is wasteful.

### Fix Approach

Add a mana guard to the pet summon path in AI_Necromancer (and AI_Magician
for consistency):

```cpp
// Line 1304-1309, change:
// Maintain pet
if (iSpellTypes & SpellType_Pet) {
    if (AI_SummonPet()) {
        return true;
    }
}
// To:
// Maintain pet — don't try to summon when mana is critically low
// (pet spells are expensive; save mana for lifetap/DoTs)
if ((iSpellTypes & SpellType_Pet) &&
    (HasPet() || GetManaRatio() > 25.0f)) {
    if (AI_SummonPet()) {
        return true;
    }
}
```

Wait — `AI_SummonPet()` already returns false if the companion has a pet
(`HasPet()` check at line 700). So the `HasPet()` guard in the condition
is redundant. Simplify:

```cpp
if ((iSpellTypes & SpellType_Pet) && GetManaRatio() > 25.0f) {
    if (AI_SummonPet()) {
        return true;
    }
}
```

Apply the same fix to `AI_Magician()` (line 1271-1275) and
`AI_Beastlord()` (line 1177-1181) for consistency.

### New Rules Needed

**Optional:** `Companions::PetSummonManaThresholdPct` (default 25). For now,
hardcode at 25%. This threshold can be extracted to a rule later if needed.

### Test Requirements

**Test 14.21: Necromancer does not attempt pet summon below 25% mana**
- **Setup:** Create a necromancer companion with no pet. Set mana to 15%.
  Load a pet summon spell. Engaged state.
- **Action:** Call AI_Necromancer() with SpellType_Pet in spell types.
- **Expected (after fix):** Pet summon is not attempted. AI falls through
  to DoT/nuke/lifetap logic.
- **Before fix would FAIL:** Pet summon would be attempted (and fail due
  to insufficient mana, but the attempt still occurs).

**Test 14.22: Necromancer summons pet above 25% mana when petless**
- **Setup:** Same as 14.21 but mana at 50%.
- **Expected:** Pet summon is attempted.

**Test 14.23: Magician has same mana guard for pet summon**
- **Setup:** Magician companion, no pet, mana at 15%.
- **Expected (after fix):** Pet summon not attempted.

### Regression Risks

- **Pet never summoned in long fights:** If mana is perpetually below 25%
  due to nuking, the necro/mage won't try to re-summon a lost pet until
  mana recovers. This is arguably correct behavior — spending 400+ mana
  on a pet when you only have 450 mana total is wasteful.
- **Idle pet summon unaffected:** The idle path runs through the same
  AI handler. When idle (sitting, meditating), mana should quickly rise
  above 25%, enabling pet summon. No regression.

---

## Issue #8: Wizard Damage Shield Spam (ENHANCEMENT)

### Root Cause Analysis

**File:** `eqemu/zone/companion_ai.cpp`, lines 1248-1252

```cpp
} else {
    if (iSpellTypes & SpellType_Buff) {
        return AI_BuffGroupMember();
    }
}
```

When idle, the wizard calls `AI_BuffGroupMember()` which iterates ALL
buff spells on ALL group members. If the wizard has damage shield (DS)
spells (like O'Keil's Radiation or Shield of Lava) tagged as
`SpellType_Buff` in `companion_spell_sets`, it will cast them on every
group member — including casters and healers where DS is mostly wasted
(they don't get hit in melee often).

Two sub-problems:
**(a) DS cast on casters is wasteful:** DS only triggers when the buffed
entity is hit in melee. Casters/healers positioned at range rarely get
melee'd. Casting DS on them wastes wizard mana.
**(b) DS should ideally only be cast during idle (pre-combat):** The
current wizard AI already doesn't buff during combat (the engaged path
has no buff call). So (b) is already correct. The issue is purely (a).

### Fix Approach

The cleanest fix is to make `AI_BuffGroupMember()` smarter about DS
spells. However, modifying the shared helper to understand DS would
add complexity for all classes. Instead, add wizard-specific buff logic
in `AI_Wizard()`:

**Option A (Simple):** In `AI_Wizard()` idle path, filter buff targets
to only include melee companions (tanks, melee DPS, rogues) when the
buff is a damage shield. This requires identifying DS spells.

A damage shield spell has `SE_DamageShield` (effect ID 59) as one of
its effects. We can check `spells[id].effect_id[slot]` for this.

**Option B (Simpler):** Create a `AI_BuffMeleeGroupMembers()` helper
that only targets melee-role companions. Wizard uses this instead of
`AI_BuffGroupMember()` for its buff path.

**Recommended: Option A with spell filtering.**

Replace the wizard idle buff logic:

```cpp
} else {
    // Wizard buff path: only buff melee companions with damage shields,
    // but buff everyone with other buffs (fire resist, etc.)
    if (iSpellTypes & SpellType_Buff) {
        return AI_WizardBuff();
    }
}
```

New helper `AI_WizardBuff()`:
- Iterates buff spells like `AI_BuffGroupMember()`
- For each spell, check if it has `SE_DamageShield` effect
- If it's a DS spell, only target group members with melee combat roles
  (COMBAT_ROLE_MELEE_TANK, COMBAT_ROLE_MELEE_DPS, COMBAT_ROLE_ROGUE)
- If it's not a DS spell, target everyone (same as current behavior)

### New Rules Needed

None.

### Test Requirements

**Test 14.24: Wizard does NOT cast DS on caster companions**
- **Setup:** Create a wizard companion in a group with a wizard buddy
  (caster role). Give the wizard a DS buff spell. Idle state.
- **Action:** Call the wizard buff logic.
- **Expected (after fix):** DS spell is NOT cast on the caster companion.
- **Before fix would FAIL:** DS would be cast on the caster (wasting mana).
- **Mock/setup:** Requires two companions in a group. May need to mock
  group membership. If not feasible, test via the spell filtering logic
  directly.

**Test 14.25: Wizard DOES cast DS on melee companions**
- **Setup:** Same as 14.24 but with a warrior companion (melee tank role).
- **Expected:** DS spell IS cast on the warrior.

**Test 14.26: Wizard casts non-DS buffs on all group members**
- **Setup:** Wizard with a non-DS buff (e.g., fire resist buff) in a
  group with both melee and caster companions.
- **Expected:** Non-DS buff is cast on everyone (unchanged behavior).

**Test 14.27: DS spell identification helper works correctly**
- **Setup:** Create mock spell data with SE_DamageShield effect.
- **Expected:** `IsDamageShieldSpell(spell_id)` returns true.
- **Setup 2:** Create mock spell data without SE_DamageShield.
- **Expected:** Returns false.

### Regression Risks

- **Wizard stops buffing entirely:** If the `AI_WizardBuff()` helper
  has a bug in role detection, the wizard might not buff anyone. Mitigate
  by falling through to `AI_BuffGroupMember()` if no DS-specific logic
  was needed.
- **SE_DamageShield detection misses augmented DS:** Some DS effects
  might use different effect IDs. Verify against the spells_new table
  for Classic-Luclin DS spells.
- **IsCompanion() check on group members:** Group members might be
  Clients (the player), not Companions. Clients don't have
  `GetCombatRole()`. The helper must handle Client targets — Clients
  are always eligible for DS (the player controls their positioning).

---

## Summary: Implementation Tasks for c-expert

| # | Issue | Priority | Files Modified | Est. Lines | New Tests |
|---|-------|----------|---------------|-----------|-----------|
| 1 | Sitting regen timing | Critical | companion.h, companion.cpp | ~15 | 4 |
| 2 | Magician mana cutoff | Medium | companion_ai.cpp | 1 | 2 |
| 3 | Enchanter mana reserve | Medium | companion_ai.cpp | 3 | 3 |
| 4 | int8 overflow | Medium | companion_ai.cpp | 4 | 3 |
| 5 | Druid HoT preference | Enhancement | companion_ai.cpp | ~40 | 3 |
| 6 | Shaman Cannibalize | Enhancement | companion_ai.cpp | ~50 | 5 |
| 7 | Necro pet spam | Enhancement | companion_ai.cpp | ~6 | 3 |
| 8 | Wizard DS spam | Enhancement | companion_ai.cpp | ~50 | 4 |
| | **All tests** | | cli_companion_tests.cpp | ~200 | **27** |

### New Rules Summary

No new rules required. All fixes use existing rules or hardcoded
thresholds that can be extracted to rules later if tuning is needed.

### Test Suite Organization

All 27 new tests go in **Suite 14: Phase 2-4 Audit Fixes**.

```
14.1  — Sitting regen fires at most once per 6-second interval
14.2  — Sitting regen does not fire when standing
14.3  — Sitting regen does not fire when engaged
14.4  — Sitting regen timer initialized correctly
14.5  — Magician respects ManaCutoffPct rule (boundary test)
14.6  — Magician obeys dynamic ManaCutoffPct change
14.7  — Enchanter stops nuking at ManaCutoffPct+10
14.8  — Enchanter still nukes above threshold
14.9  — Enchanter mez still works at low mana
14.10 — HealThresholdPct at boundary 127
14.11 — HealThresholdPct > 127 does not wrap negative
14.12 — Normal HealThresholdPct (80) works correctly
14.13 — Druid prefers HoT above 50% HP
14.14 — Druid uses direct heal below 50% HP
14.15 — Druid falls back to direct heal when no HoT available
14.16 — FindCannibalizeSpell identifies correct spell
14.17 — Shaman Cannibalize when mana < 40% and HP > 80%
14.18 — Shaman no Cannibalize when HP < 80%
14.19 — Shaman no Cannibalize when mana > 40%
14.20 — Cannibalize data presence (SQL verification)
14.21 — Necromancer no pet summon below 25% mana
14.22 — Necromancer summons pet above 25% mana
14.23 — Magician same mana guard for pet summon
14.24 — Wizard no DS on caster companions
14.25 — Wizard DS on melee companions
14.26 — Wizard non-DS buffs on all members
14.27 — DS spell identification helper
```

### Build and Verification

After all fixes are implemented:
1. Build: `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
2. Run ALL test suites: `cd ~/server && ~/code/build/bin/zone tests:companion`
3. Verify: All 14 suites pass (177 existing + 27 new = 204 tests)
4. Manual smoke test: recruit a shaman and wizard companion, observe:
   - Sitting regen is gradual (not instant)
   - Wizard does not DS the enchanter
   - Shaman cannibalizes when OOM

---

## Appendix: Data-Expert Tasks

Issue #6 (Shaman Cannibalize) requires companion_spell_sets entries for
Cannibalize I-IV at appropriate shaman levels. The data-expert should:

1. Identify Cannibalize spell IDs from `spells_new`:
   - Cannibalize I: likely spell ID around 744
   - Cannibalize II: around 2239
   - Cannibalize III: around 2240
   - Cannibalize IV: around 2241
2. Insert into `companion_spell_sets` with class_id = 10 (Shaman),
   min_level matching the spell's original level requirement.
3. Tag with `SpellType_Heal` (since it's a self-mana-recovery, closest
   available type) or a unique type if the c-expert needs differentiation.
   The c-expert's `FindCannibalizeSpell()` helper will identify them by
   their spell effects rather than spell type, so the type tag is
   less critical.
