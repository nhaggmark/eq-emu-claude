# Balance Tuning Reference — npc-companion-realistic-stats

> **Feature branch:** `feature/npc-companion-realistic-stats`
> **Date:** 2026-03-11
> **Phase:** 5 (final)

---

## Current Tuning Knob Values

All values reflect defaults as of Phase 5 completion. Adjust via `#rules set`
without a server rebuild.

| Rule | Category | Default | Effect of Increase | Effect of Decrease |
|------|----------|---------|-------------------|-------------------|
| `StatScalePct` | Companions | 100 | More STR/STA/etc → more damage + HP | Less damage + HP |
| `UseWeaponDamage` | Companions | true | Master toggle for weapon-based damage | Falls back to NPC base damage |
| `STAToHPFactor` | Companions | 100 | More HP from STA gear | Less HP from gear STA |
| `SittingRegenMult` | Companions | 200 | Faster OOC sitting recovery | Slower recovery |
| `HPRegenPerTic` | Companions | 1 | Higher floor regen | Lower floor |
| `OOCRegenPct` | Companions | 5 | Faster OOC regen (% of max HP/tic) | Slower OOC recovery |
| `HealThresholdPct` | Companions | 80 | Earlier healing → more mana used | Later healing → more efficient |
| `ManaCutoffPct` | Companions | 20 | More mana reserve → less DPS | Less reserve → more DPS |
| `HealerManaConservePct` | Companions | 30 | Lower: normal heals longer | Higher: efficient heals sooner |
| `ResistCapBase` | Companions | 50 | Higher resist cap (less debuffable) | Lower cap (more debuffable) |

---

## Phase 5 Resist Cap Values at Key Levels

Formula: `cap = level * 5 + ResistCapBase`

| Level | ResistCapBase=50 | ResistCapBase=100 | Client cap |
|-------|-----------------|------------------|-----------|
| 20    | 150             | 200              | 500       |
| 40    | 250             | 300              | 500       |
| 50    | 300             | 350              | 500       |
| 60    | 350             | 400              | 500       |
| 65    | 375             | 425              | 500       |

At default (50), a level 60 companion is capped at 350 — 70% of the player
resist cap. This activates only when companions stack base resists + gear +
buffs aggressively. In normal play (moderate resist gear, no resist buffs),
companions rarely approach this cap.

**To disable resist caps entirely:** Set `ResistCapBase` to 0.

---

## Companion Power Target: 70-85% of Player

### Why This Range Works Naturally

The AA gap between companions and players provides the primary power
differential. Players can invest 100-300+ AAs in combat abilities that
companions do not have:

**AAs companions lack:**
- Combat Fury (melee critical hit chance)
- Ambidexterity (dual-wield hit rate)
- Natural Durability / Physical Enhancement (HP/regen)
- Combat Agility (AC/avoidance)
- Slaying Strike, Assassinate (instant kill abilities)
- Hastened Disciplines

At level 60 with moderate AA investment (100-150 AAs), player combat
abilities exceed companion abilities by 15-25%. This naturally places
companions at 75-85% of player power with identical gear.

### If Companions Are Overpowered

1. Reduce `StatScalePct` to 90 (10% stat reduction across the board)
2. If still too strong, reduce `STAToHPFactor` to 80 (less HP from gear STA)
3. If DPS specifically is the problem, reduce `ManaCutoffPct` to 30 (more
   mana reserve → casters DPS less) or lower `OOCRegenPct` to 3 (slower
   caster mana recovery between fights)

### If Companions Are Underpowered

1. Verify Phases 1-4 are all active (check `UseWeaponDamage=true`, etc.)
2. Increase `StatScalePct` to 110
3. Consider increasing `OOCRegenPct` to 7 for faster mana between fights
4. Consider reducing `ManaCutoffPct` to 10 for more caster DPS

---

## Test Scenarios for Balance Validation

### Scenario 1: Solo Warrior Companion vs. Level-Appropriate Content

**Setup:** Level 60 warrior companion with era-appropriate gear (classic
plate: ~300 AC, ~3000 HP, ~150 ATK from items).

**Target NPC:** Level 58-60 warrior-class NPC (e.g., typical dungeon mob).

**Metrics to measure:**
- Companion TTK (time to kill): compare to player warrior TTK
- Companion TtD (time to die): how long the companion tanks without healing
- Expected result: companion should last 60-80% as long as a comparably
  geared player warrior

### Scenario 2: Cleric-Warrior Companion Pair

**Setup:** Level 60 cleric companion + level 60 warrior companion, both
with era-appropriate gear.

**Target:** Standard group content at level 55-58 (Plane of Hate, Kael,
etc.)

**Metrics:**
- Can the cleric keep the warrior alive through a fight with a yellow-con mob?
- Does the cleric exhaust mana after 3-4 fights or sustain longer?
- Expected result: 3-5 fight chain without med break, then sit to med

### Scenario 3: Wizard Companion Single-Target DPS

**Setup:** Level 60 wizard companion, focus gear with Improved Damage items.

**Target:** Training dummy equivalent (fixed AC, doesn't fight back).

**Metrics:**
- Total damage/minute: aim for 70-80% of a player wizard's output
- Mana efficiency: with ManaCutoffPct=20, wizard should conserve mana

---

## Recommended Starting Configuration

**All rules at defaults.** No tuning required for initial deployment.

The natural AA differential (players have AAs, companions don't) provides
the 15-25% power gap needed to land companions at 70-85% of player power.

**Document actual measured values here after live testing:**

| Metric | Player Value | Companion Value | % of Player |
|--------|-------------|----------------|-------------|
| Warrior DPS (lv60) | TBD | TBD | TBD |
| Warrior TTL (lv60) | TBD | TBD | TBD |
| Wizard DPS (lv60) | TBD | TBD | TBD |
| Cleric heal chains | TBD | TBD | TBD |

---

## Phase 5 Summary

### Code Changes

| File | Change |
|------|--------|
| `common/ruletypes.h` | Added `Companions::ResistCapBase` (default 50) |
| `zone/companion.h` | Added `GetMaxResist()`, resist getter overrides (GetMR/FR/DR/PR/CR), `GetFocusEffect()` override |
| `zone/companion.cpp` | Implemented `GetMaxResist()` and `GetFocusEffect()` |
| `zone/cli/tests/cli_companion_tests.cpp` | Suite 15: 27 tests for resist caps + focus effects + rule defaults |

### PRD Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| No companion resist stat exceeds level-appropriate cap | Implemented (cap = level*5+ResistCapBase) |
| Focus effect items produce measurable benefit | Implemented (GetFocusEffect delegates to Mob base, bypassing NPC rule gate) |
| Overall companion power evaluated with tuning knobs documented | Documented above |
