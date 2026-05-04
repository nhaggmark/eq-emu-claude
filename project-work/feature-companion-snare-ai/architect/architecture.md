# Companion Snare AI: Combat Restriction — Architecture & Implementation Plan

> **Feature branch:** `feature/companion-snare-ai`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-05-04 (amended)
> **Status:** Approved — with Amendment 2026-05-04 noted below

---

## Amendment Notice — 2026-05-04

This document was substantially amended after team-lead requested
re-verification of the AI routing claim. The original architecture
asserted that `AI_Druid`, `AI_Necromancer`, and `AI_Shaman` did
not route `SpellType_Snare` and proposed adding new branches.
Re-verification by querying the live `companion_spell_sets` table
and `spells_new` effect data revealed two crucial corrections:

1. **The user's reported "Druid ensnare spam" is NOT snare-line —
   it is actual Root spell casting** through the existing
   `AI_Druid` `SpellType_Root` branch. The Druid root spells in
   the user's spell set are named "Ensnaring Roots", "Engulfing
   Roots", "Grasping Roots", "Enveloping Roots", etc. — the user
   colloquially called these "ensnare" but they are immobilize
   roots (effect ID 99 = Root), not movement-slow snares
   (effect ID 3 = MovementSpeed).

2. **The PRD scope of "snare-line ONLY, roots OUT of scope" does
   not match the user's reported bug.** Shipping the original
   architecture as-designed (gating only `SpellType_Snare`)
   would NOT eliminate the user's observed Druid spam, because
   the Druid's spam is on the `SpellType_Root` branch — which
   the original PRD explicitly excluded from scope.

This amendment also retunes `Companions:SnareHpThreshold`
default from 20 to 25 to align with `Combat:FleeHPRatio` and
eliminate the awkward 25%-to-20% window where a mob is fleeing
but the gate denies snare. (Per user direction.)

**A scope decision is required from the user before
implementation begins** — see "§Scope Decision Required" below.
The architecture sections that follow are written to support
the most likely user choice (gate BOTH snare and root branches),
but each affected section is annotated to indicate what changes
under each scope option.

---

## Scope Decision Required

The original PRD scoped the feature as "autonomous snare-line
casting only; roots OUT of scope, players use root for legit CC."
The user's reported bug is "ranger and druids spam ensnare."

After source-code re-verification, those two statements describe
**different code paths**:

| User-reported behavior | Actual code path | PRD scope status |
|---|---|---|
| Ranger Ensnare spam | `AI_Ranger` `SpellType_Snare` branch (companion_ai.cpp:1469) | **IN scope** |
| Druid "Ensnare" spam | `AI_Druid` `SpellType_Root` branch (companion_ai.cpp:1235) — casts spells named "Ensnaring Roots", "Engulfing Roots", etc. | **OUT of scope per PRD** but IS the user's actual complaint |

Three options for the user:

**Option 1 — Strict PRD: snare-line only.**
Apply the HP/flee/resist-counter gate ONLY to `SpellType_Snare`
branches (AI_Ranger and AI_Bard). Druid root spam remains.
User will likely report "the feature didn't fix Druid" after
shipping. The Bard branch is also gated for consistency, but
Bard is not in the user's complaint.

**Option 2 — User's actual intent: gate both snare and root.**
Apply the gate to `SpellType_Snare` branches AND to
`SpellType_Root` branches (AI_Druid Root branch is the only
one in scope today). This addresses the user's actual reported
behavior. PRD scope is expanded; lore-master should sign off
on root-gating since lore-master previously approved
"silent suppression" for snare specifically. The PRD's
non-goal "Changing root-line spells" needs explicit override.

**Option 3 — Two features.**
Ship Option 1 now (matches PRD literally). File a follow-up
bug-fix feature for "Druid root spam" using the same shared
gate helper (which is designed to be reusable). This delays
addressing the user's actual complaint by one feature cycle.

**Architect recommendation: Option 2.** The gate logic is
identical for snare and root (the rule is "stop pre-emptive
movement-control casting at high HP"). The shared helper
`AI_AttemptMovementControl` (formerly `AI_AttemptSnare`)
becomes more useful, not less. The lore-master review for
roots is straightforward — same "silent suppression" reasoning
applies. Bigger blast radius is paid for by addressing the
user's actual reported behavior.

**The remainder of this document assumes Option 2.** If the
user picks Option 1 or 3, mark the Root-related tasks (#6 in
the implementation sequence below) as deferred and rename the
helper to keep `AI_AttemptSnare`. No other section changes.

---

## Executive Summary

Restrict autonomous companion-AI casting of movement-control
spells in active combat (snare-line spells AND root-line spells)
to targets that are at or below the configured HP threshold AND
in low-HP flee state. Track per-(companion, target) full-resist
counters and stop autonomous attempts on a target after the
configured limit. Counters reset on engagement-end and on target
change. Out-of-combat behavior unchanged.

Implementation is **pure C++** in `eqemu/zone/`, with two new
rules in `common/ruletypes.h`, two `INSERT INTO rule_values`
seeds, and a small data audit pass on `companion_spell_sets`.

The gate is centralized in **one shared helper**
(`Companion::AI_AttemptMovementControl`) that every applicable
class handler calls, so the rule lives in one place. The
existing `AI_Druid` Root branch (line 1235), `AI_Ranger` Snare
branch (line 1469), and `AI_Bard` Snare branch (line 1789) are
the three sites that route through the helper.

The most consequential design call: classify snare-line and
root-line spells **only** by the existing `SpellType_Snare`
and `SpellType_Root` bitmask tags stored in
`companion_spell_sets.spell_type`. Do not name-match — the
spell name "Ensnaring Roots" is misleading (it's a root, not
a snare) and similarly Necromancer "Clinging Darkness" /
"Dooming Darkness" are snare-line despite the names.

**Defaults amended per user 2026-05-04:**
`Companions:SnareHpThreshold` default = **25** (was 20),
aligning with `Combat:FleeHPRatio` default of 25 to eliminate
the window where mob is fleeing but gate denies. Operators
who want a tighter window can lower it.

## Existing System Analysis

### Current State (Verified Against Live Database 2026-05-04)

**Entity hierarchy.** Companion is a customized subclass of NPC
(`eqemu/zone/companion.h:77`), holding its spell list in
`m_companion_spells` (`std::vector<CompanionSpell>`). Loaded
from the `companion_spell_sets` table on AI_Start.

**AI dispatch.** Companion AI cast pipeline (call chain):

```
NPC::AI_Process (mob_ai.cpp)
  → Companion::AI_EngagedCastCheck (companion.cpp:2271)
  → Companion::AICastSpell (companion_ai.cpp:359)
    → switch(GetClass())
       ├ AI_Druid       (companion_ai.cpp:1160)
       ├ AI_Ranger      (companion_ai.cpp:1459)
       ├ AI_Necromancer (companion_ai.cpp:1643)
       ├ AI_Shaman      (companion_ai.cpp:1283)
       ├ AI_Bard        (companion_ai.cpp:1758)
       └ ...others
    → Companion::AIDoSpellCast (companion.cpp:2320)
      → Mob::CastSpell
        → ... Mob::SpellOnTarget (spells.cpp:3907)
          → ResistSpell (spells.cpp:5306)
            → resist branch at spells.cpp:4508 (full resist)
```

**SpellType_Snare cast branches that actually fire today.**

Verified against live `companion_spell_sets` data and AI handler
source:

| Class | Code path | SpellType_Snare data present? | Casts today? | Notes |
|---|---|---|---|---|
| Ranger | `AI_Ranger` line 1469 | Yes (242 Snare, 512 Ensnare) | **YES — fires at 30% throttle** | Existing snare branch. **THIS IS WHAT THE PRD TARGETS for Ranger.** |
| Bard | `AI_Bard` line 1789 | Yes (738 Selo's Consonant, 1758 Selo's Assonant) | **YES — fires at 20% throttle** | Existing snare branch. (Not in user complaint, but in PRD by implication.) |
| Druid | (no Snare branch) | Yes (242, 512, 1767, 3192, 3447) | **NO** — AI_Druid has no SpellType_Snare branch | The 5 entries in spell set go unreached by AI. |
| Necromancer | (no Snare branch) | Yes (344-3309 Darkness line) | **NO** — AI_Necromancer has no SpellType_Snare branch. The Necro Darkness spells also do DoT damage (effect 0) but are NOT tagged with SpellType_DOT in companion_spell_sets, so AI_Necromancer's DoT branch doesn't pick them up either. | Latent bug: Necromancer Darkness DoTs are unreachable today. |
| Shaman | (no Snare branch) | **No SpellType_Snare entries for Shaman in companion_spell_sets** | NO | Shaman has no snare-line in this spell-set data at all. Lore lists Drowsy etc. but they're not in the data. |

**SpellType_Root cast branches that actually fire today.**

| Class | Code path | SpellType_Root data present? | Casts today? | Notes |
|---|---|---|---|---|
| Druid | `AI_Druid` line 1235 | Yes (249 Grasping Roots, 76 Engulfing Roots, 490 Enveloping Roots, 77 Ensnaring Roots, 1719 Engorging Roots, 1608 Entrapping Roots) | **YES — fires at 30% throttle** | The Druid Root branch. **This is the actual code path firing the user's "ensnare spam"** because the spell names contain "Ensnaring/Engulfing/Grasping/etc." All effect ID 99 = full immobilize root, not snare. |
| Ranger | (no Root branch) | Yes (249, 76, 490, 3192) | NO — AI_Ranger has no SpellType_Root branch | Roots in data but unreached. |
| Shaman | (no Root branch) | Yes (230, 131, 132, 133, 3195, 3196) | NO | Roots in data but unreached. |
| Necromancer | (no Root branch) | Yes (369, 230, 133, 131, 132, 3195) | NO | Roots in data but unreached. |

**Data tagging anomaly noted.** The Druid spell set tags spell
3192 (Earthen Roots) and 3447 (Savage Roots) as
`spell_type = 128` (SpellType_Snare), but their actual effect
in `spells_new` is effect ID 99 (Root). This is a data
mis-tag — they should be `spell_type = 4` (SpellType_Root).
For Ranger, 3192 IS correctly tagged as `spell_type = 4`.
The data-expert audit task (#3 below) covers this.

**Flee state observability.** `Mob::IsFleeing()` (`mob.h:1251`)
returns the `flee_mode` member, set by `Mob::StartFleeing()`
when a mob's HP ratio drops below `Combat:FleeHPRatio`
(default 25). O(1) member read.

**Resist signal pathway.** `Mob::SpellOnTarget` full-resist
branch at `spells.cpp:4508-4555`. Caster is `this`. We hook
here, guarded by `caster->IsCompanion()`.

**Engagement-boundary signal.** Existing `m_was_engaged`
transition in `Companion::Process` (`companion.cpp:1992-2000`).

**Rule namespace.** `Companions:*` exists with 44+ rules
(`ruletypes.h:1182-1255`). New rules conform exactly.

**Companion command system.** Per
`claude/docs/companion-commands-reference.md`, no `!snare`,
`!root`, or generic `!cast` command exists. The PRD's "manual
override bypasses the rule" is moot in current scope.

### Gap Analysis

What's missing between current state and the corrected
understanding of user intent:

1. **Movement-control gate.** No HP-threshold-AND-fleeing gate
   exists in any companion snare or root branch today. Both
   AI_Druid Root (line 1235) and AI_Ranger Snare (line 1469)
   need the gate.
2. **Resist counter.** No per-(companion, target) resist
   tracking exists for any movement-control cast.
3. **Counter reset on engagement boundary.** No hook on the
   existing `m_was_engaged` transition for snare/root counters.
4. **Two tunable rules.** `Companions:SnareHpThreshold` and
   `Companions:SnareResistLimit` do not exist.
5. **Data audit (small).** `companion_spell_sets` should be
   audited for the data mis-tag noted above (Druid's 3192
   and 3447 tagged as Snare but effect is Root). Whether to
   fix the tags is a data-expert decision; either way, the
   gate works because both Snare and Root are gated through
   the same helper.

Out of scope (deliberate non-goals or deferred):

- No manual `/command` snare/root override — there is no
  existing path to override.
- No client-side change.
- No new opcodes/packets/Titanium-format work.
- **No new AI routing for Druid SpellType_Snare, Necromancer
  SpellType_Snare/Root, or Shaman SpellType_Root.** These
  spell types are present in companion_spell_sets data for
  some classes but their AI handlers do not route them today.
  Adding new branches would expand companion behavior beyond
  what's needed to address the user's complaint and the PRD
  scope. Defer to a separate "Companion AI completeness"
  follow-up if the user wants those classes to use those
  spells autonomously.

## Technical Approach

### Architecture Decision

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `common/ruletypes.h` (Companions category) | Add 2 RULE_INTs | Tunable thresholds. Conforms to existing `Companions:*` namespace. Default 25 for HP threshold (aligned with Combat:FleeHPRatio). Default 2 for resist limit. |
| `rule_values` table | INSERT 2 default rows | Seed defaults into ruleset 1. |
| `eqemu/zone/companion.h` | Add 1 method, 2 helpers, 2 members | New: `m_movement_control_resist_counts` (per-target map), `m_last_movement_control_target_id` (for change detection), `OnSpellResisted(spellid, target)` hook, `AI_AttemptMovementControl(target, type_mask)` shared helper, `ClearMovementControlResistCounters()` on engagement-end. |
| `eqemu/zone/companion_ai.cpp` | Add shared helper, route through 3 class branches | Replaces existing AI_Druid Root branch, AI_Ranger Snare branch, AI_Bard Snare branch. The helper accepts a type mask so the same code handles both Snare and Root. |
| `eqemu/zone/companion.cpp` | Hook engagement transition | Add `ClearMovementControlResistCounters()` call to existing `m_was_engaged` site. Target-change detected at top of `AI_AttemptMovementControl`. |
| `eqemu/zone/spells.cpp` | One ~3-line hook | In existing full-resist branch, call `caster->CastToCompanion()->OnSpellResisted(spell_id, spelltar)` when caster is a Companion. |
| `companion_spell_sets` | Optional data audit | Verify Druid 3192/3447 tagging consistency. Data mis-tag is benign because both Snare and Root are gated. |

### Data Model

**No schema changes.** Per-target counter is runtime memory only:

```cpp
// In Companion (private):
//   Maps target entity ID -> consecutive full-resist count
//   for movement-control spells (snare-line OR root-line).
//   Cleared on engagement-end and target change.
std::unordered_map<uint16, uint8> m_movement_control_resist_counts;
uint16 m_last_movement_control_target_id = 0;
```

**Two new rule rows:**

```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES
(1, 'Companions:SnareHpThreshold', '25',
 'Target HP percentage at or below which companions may autonomously cast movement-control spells (snare-line and root-line). Target must ALSO be in flee state. Default 25 to align with Combat:FleeHPRatio. Set to 100 to disable the HP gate.'),
(1, 'Companions:SnareResistLimit', '2',
 'Consecutive full-resists per (companion, target) per engagement before companion stops attempting movement-control casts on that target. Counter resets on engagement-end and target change. Set to 0 = no cap (never give up). Default 2.');
```

(Rule names retain "Snare" prefix despite gating roots too — to
avoid renaming existing rule shape proposals from config-expert.
The notes string clarifies the actual coverage. If the user
prefers, rename to `MovementControlHpThreshold` /
`MovementControlResistLimit`.)

### Code Changes

#### C++ Changes

**1. `common/ruletypes.h` — add 2 rules before
`RULE_CATEGORY_END()` at line 1256:**

```cpp
RULE_INT(Companions, SnareHpThreshold, 25,
    "Target HP percent at or below which a companion's autonomous AI is allowed to "
    "cast movement-control spells (snare-line AND root-line). The target must ALSO be "
    "in flee state (Mob::IsFleeing()). Default 25 aligns with Combat:FleeHPRatio so the "
    "gate opens exactly when targets enter flee. Set to 100 to disable the HP gate.")
RULE_INT(Companions, SnareResistLimit, 2,
    "Consecutive full-resists per (companion, target) at which companion stops "
    "attempting movement-control casts (snare/root) on that target for the "
    "engagement. Counter resets on engagement-end and target change. Set to 0 = no cap. "
    "Default 2.")
```

**2. `eqemu/zone/companion.h` — declarations:**

In public AI section:

```cpp
// Shared movement-control attempt with HP-threshold + flee +
// resist-counter gate. Type mask controls whether to attempt
// snare-line (SpellType_Snare), root-line (SpellType_Root), or
// either. Replaces the previous unconditional snare/root branches
// in AI_Ranger / AI_Bard / AI_Druid.
bool AI_AttemptMovementControl(Mob* target, uint32 spell_type_mask);

// Resist event hook fired from Mob::SpellOnTarget when this
// companion's cast is fully resisted. Increments the counter only
// when the spell carries SpellType_Snare or SpellType_Root in its
// companion-spell-set entry.
void OnSpellResisted(uint16 spell_id, Mob* target);

// Clears all per-target resist counters. Called on engaged->idle
// transition and on target change.
void ClearMovementControlResistCounters();
```

In private section:

```cpp
// Per-(this companion, target_entity_id) consecutive full-resist
// count for SpellType_Snare and SpellType_Root casts. Cleared on
// engagement-end and target change. Runtime-only; not persisted.
std::unordered_map<uint16, uint8> m_movement_control_resist_counts;
uint16 m_last_movement_control_target_id = 0;
```

**3. `eqemu/zone/companion_ai.cpp` — implement the shared helper.
Insert near AI_SlowDebuff (around line 869):**

```cpp
// ============================================================
// AI_AttemptMovementControl — shared snare/root gate
//
// PRD requirements:
//   * Out-of-combat: gate does not apply
//   * In-combat: target HP <= Companions:SnareHpThreshold AND
//     target IsFleeing(). Both required.
//   * Per-(companion, target) full-resist counter, cap at
//     Companions:SnareResistLimit. Cleared on engagement-end
//     and target change.
//   * No chat spam on suppression.
//
// `spell_type_mask` should be SpellType_Snare, SpellType_Root,
// or (SpellType_Snare | SpellType_Root). Controls which spell
// type pool to draw the cast from.
//
// Returns true if a cast was attempted, false otherwise.
// ============================================================
bool Companion::AI_AttemptMovementControl(Mob* target, uint32 spell_type_mask)
{
    if (!target || target->GetHP() <= 0) {
        return false;
    }

    // Pre-existing "don't re-cast if redundant" checks, preserved
    // from the original AI_Ranger/AI_Bard snare branches and the
    // AI_Druid root branch. NOT part of the new rule.
    if (spell_type_mask & SpellType_Snare) {
        if (target->GetSpecialAbility(SpecialAbility::SnareImmunity)) {
            return false;
        }
        if (target->GetSnaredAmount() >= 0) {
            // Already snared — skip re-cast.
            return false;
        }
    }
    if ((spell_type_mask & SpellType_Root) && target->IsRooted()) {
        // Already rooted — skip re-cast.
        return false;
    }

    // Spell availability
    uint32 now_ms = Timer::GetCurrentTime();
    uint16 cast_spell = SelectFirstSpell(
        m_companion_spells, spell_type_mask, m_current_stance, now_ms);
    if (!cast_spell) {
        return false;
    }

    // Target-change detection (clear all counters when switching
    // targets — relaxed but simple semantic).
    uint16 tid = target->GetID();
    if (tid != m_last_movement_control_target_id) {
        m_movement_control_resist_counts.clear();
        m_last_movement_control_target_id = tid;
    }

    // ---------------- THE GATE ----------------
    if (IsEngaged()) {
        const int hp_threshold = RuleI(Companions, SnareHpThreshold);
        const int target_hpr   = static_cast<int>(target->GetHPRatio());
        const bool fleeing     = target->IsFleeing();

        if (target_hpr > hp_threshold || !fleeing) {
            // Silent suppression — no chat, no emote, no log spam.
            return false;
        }

        const int resist_limit = RuleI(Companions, SnareResistLimit);
        if (resist_limit > 0) {
            auto it = m_movement_control_resist_counts.find(tid);
            if (it != m_movement_control_resist_counts.end() &&
                it->second >= static_cast<uint8>(resist_limit)) {
                return false;
            }
        }
    }
    // ------------------------------------------

    bool cast_ok = AIDoSpellCast(cast_spell, target, spells[cast_spell].mana);
    if (cast_ok) {
        SetSpellTimeCanCast(cast_spell, spells[cast_spell].recast_time);
    }
    return cast_ok;
}

// ============================================================
// OnSpellResisted — called from Mob::SpellOnTarget on full
// resist. Counts SpellType_Snare and SpellType_Root resists
// only. All other resists are ignored.
// ============================================================
void Companion::OnSpellResisted(uint16 spell_id, Mob* target)
{
    if (!target) {
        return;
    }

    bool is_movement_control = false;
    for (const auto& cs : m_companion_spells) {
        if (cs.spellid == spell_id &&
            (cs.type & (SpellType_Snare | SpellType_Root))) {
            is_movement_control = true;
            break;
        }
    }
    if (!is_movement_control) {
        return;
    }

    uint16 tid = target->GetID();
    uint8& count = m_movement_control_resist_counts[tid];
    if (count < 255) {
        ++count;
    }

    LogAIDetail("Companion [{}] OnSpellResisted: movement-control spell [{}] on target [{}] (id [{}]) — count now [{}]",
                GetName(), spell_id, target->GetName(), tid, count);
}

void Companion::ClearMovementControlResistCounters()
{
    if (!m_movement_control_resist_counts.empty()) {
        m_movement_control_resist_counts.clear();
    }
    m_last_movement_control_target_id = 0;
}
```

**4. `eqemu/zone/companion_ai.cpp` — replace existing
`AI_Druid` Root branch (lines 1235-1246):**

Before:
```cpp
if ((iSpellTypes & SpellType_Root) && m_current_stance != COMPANION_STANCE_PASSIVE) {
    uint32 now_ms = Timer::GetCurrentTime();
    uint16 root_spell = SelectFirstSpell(m_companion_spells, SpellType_Root, m_current_stance, now_ms);
    Mob* target = GetTarget();
    if (root_spell && target && !target->IsRooted() && zone->random.Roll(30)) {
        bool cast_ok = AIDoSpellCast(root_spell, target, spells[root_spell].mana);
        if (cast_ok) {
            SetSpellTimeCanCast(root_spell, spells[root_spell].recast_time);
            return true;
        }
    }
}
```

After:
```cpp
// Movement-control: root fleeing low-HP enemies — gated by
// Companions:SnareHpThreshold and IsFleeing.
if ((iSpellTypes & SpellType_Root) && m_current_stance != COMPANION_STANCE_PASSIVE
    && zone->random.Roll(30)) {
    if (AI_AttemptMovementControl(GetTarget(), SpellType_Root)) {
        return true;
    }
}
```

**5. `eqemu/zone/companion_ai.cpp` — replace existing
`AI_Ranger` Snare branch (lines 1467-1483):**

```cpp
// Movement-control: snare fleeing low-HP enemies — gated.
if ((iSpellTypes & SpellType_Snare) && zone->random.Roll(30)) {
    if (AI_AttemptMovementControl(GetTarget(), SpellType_Snare)) {
        return true;
    }
}
```

**6. `eqemu/zone/companion_ai.cpp` — replace existing
`AI_Bard` Snare branch (lines 1788-1802):**

```cpp
// Movement-control: snare fleeing targets — gated.
if ((iSpellTypes & SpellType_Snare) && zone->random.Roll(20)) {
    if (AI_AttemptMovementControl(GetTarget(), SpellType_Snare)) {
        return true;
    }
}
```

**7. `eqemu/zone/companion.cpp` — hook engagement-end at
existing `m_was_engaged` site (lines 1992-2000):**

```cpp
bool currently_engaged = IsEngaged();
if (m_was_engaged && !currently_engaged) {
    // Combat just ended — start the rez delay timer
    if (RuleB(Companions, RezEnabled)) {
        m_rez_delay_timer.Start(RuleI(Companions, RezPostCombatDelayS) * 1000);
        m_rez_meditation_announced = false;
    }
    // Movement-control gate: clear per-target resist counters.
    ClearMovementControlResistCounters();
}
m_was_engaged = currently_engaged;
```

**8. `eqemu/zone/spells.cpp` — hook the resist branch at
~line 4554, just before `safe_delete(action_packet); return false;`:**

```cpp
// Companion movement-control gate: count this resist if caster
// is a Companion and the spell is in its snare-line or root-line
// spell set. No-op for any other caster type.
if (this->IsCompanion()) {
    this->CastToCompanion()->OnSpellResisted(spell_id, spelltar);
}
```

**Resist-hook site choice — architect note.** protocol-agent
recommended hooking `Companion::CastedSpellFinished()` instead.
Architect chose `Mob::SpellOnTarget` for surgical clarity:
single source of truth across single-target / AE / group spells.
`CastedSpellFinished` is broader (fizzle/interrupt/OOM/resist).
Documented as fallback.

#### Lua/Script Changes

**None.**

#### Database Changes

**No schema changes.**

**Two `INSERT INTO rule_values` seeds** (config-expert, after
rebuild):

```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES
(1, 'Companions:SnareHpThreshold', '25',
 'Target HP percent at or below which companions may autonomously cast movement-control spells (snare-line and root-line). Target must ALSO be IsFleeing(). Default 25 aligns with Combat:FleeHPRatio.'),
(1, 'Companions:SnareResistLimit', '2',
 'Consecutive full-resists per (companion, target) per engagement before companion stops attempting movement-control casts on that target. Counter resets on engagement-end and target change. 0 = no cap. Default 2.');
```

**Optional data-expert audit:** The Druid spell set has a
mis-tag (3192 Earthen Roots and 3447 Savage Roots tagged as
`spell_type=128` (Snare) but effect ID 99 = Root). The gate
covers both types, so the mis-tag is functionally benign in
the new code. The data-expert may correct the tag for
consistency or leave as-is. Document the choice.

#### Configuration Changes

Two new entries in `common/ruletypes.h`:

- `Companions:SnareHpThreshold` (RULE_INT, default 25)
- `Companions:SnareResistLimit` (RULE_INT, default 2)

No `eqemu_config.json` changes.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Add 2 RULE_INT entries to `common/ruletypes.h` (`Companions:SnareHpThreshold` default 25, `Companions:SnareResistLimit` default 2). Updated description strings reflect movement-control coverage. | config-expert | — | ~10 lines |
| 2 | Audit `companion_spell_sets` for the noted Druid 3192/3447 mis-tag (tagged Snare but effect is Root). If correcting, update `spell_type` from 128 to 4 for these two rows in the Druid (class_id=6) entries. Optional — gate handles both. Document the choice. | data-expert | — | Either no-op (leave tag) or two `UPDATE` statements. Run in parallel with task 1. |
| 3 | Implement `Companion::AI_AttemptMovementControl(Mob*, uint32)`, `Companion::OnSpellResisted(uint16, Mob*)`, `Companion::ClearMovementControlResistCounters()`. Add `m_movement_control_resist_counts` and `m_last_movement_control_target_id` private members in `companion.h`. | c-expert | 1 (rules must exist for `RuleI(Companions, SnareHpThreshold)` to compile) | ~100 lines C++ |
| 4 | Replace `AI_Druid` Root branch (companion_ai.cpp:1235-1246) with a call to `AI_AttemptMovementControl(GetTarget(), SpellType_Root)`. Preserve 30% throttle. | c-expert | 3 | ~6 lines |
| 5 | Replace `AI_Ranger` Snare branch (companion_ai.cpp:1467-1483) with a call to `AI_AttemptMovementControl(GetTarget(), SpellType_Snare)`. Preserve 30% throttle. | c-expert | 3 | ~6 lines |
| 6 | Replace `AI_Bard` Snare branch (companion_ai.cpp:1788-1802) with a call to `AI_AttemptMovementControl(GetTarget(), SpellType_Snare)`. Preserve 20% throttle. | c-expert | 3 | ~6 lines |
| 7 | Add `ClearMovementControlResistCounters()` call to the `m_was_engaged && !currently_engaged` site in `Companion::Process` (companion.cpp:1993-2000). | c-expert | 3 | ~2 lines |
| 8 | Add the `SpellOnTarget` resist hook in `eqemu/zone/spells.cpp` (~line 4554, inside the existing full-resist branch). Guarded by `this->IsCompanion()`. | c-expert | 3 | ~3 lines |
| 9 | Build (`docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`), restart container + zone processes, smoke test. | c-expert | 4,5,6,7,8 | Build + restart |
| 10 | After rebuild + restart, insert the 2 default `rule_values` rows for `Companions:SnareHpThreshold` and `Companions:SnareResistLimit`. Run `#reloadrules` in-game to activate. | config-expert | 9 (rebuild required for `_FindRule()` to match new rules) | ~6 lines SQL |

**Sequence summary.** Task 1 and Task 2 in parallel. Task 3
after Task 1 (compilation needs RULE_INT). Tasks 4-8 sequential
after Task 3 (single-file serialization in companion_ai.cpp and
related). Task 9 (rebuild) gates Task 10 (rule_values seed).

**Note on what's NOT included.** The original architecture
proposed adding new `SpellType_Snare` branches to AI_Druid,
AI_Necromancer, and AI_Shaman. After re-verification, those
branches are unnecessary for this feature:
- AI_Druid's spam is on the existing Root branch, gated by
  Task 4.
- AI_Necromancer and AI_Shaman do not currently spam any
  movement-control spell. Adding new branches would expand
  behavior without addressing user complaint or PRD scope.
- If a future feature wants Necromancer Darkness DoTs to
  fire, that's a separate "AI completeness" effort.

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `Combat:FleeHPRatio` and `Companions:SnareHpThreshold` are now both default 25. They'll usually align — but operators may set them differently. The 25%/20% window from the original doc is gone with the default change. | Low | Low | Documented in rule notes string. game-tester confirms snare/root fires at flee threshold. |
| `m_movement_control_resist_counts` could grow unbounded if a fight has many distinct targets. | Very Low | Very Low | `clear()` on engagement-end and target change. Cap at 255 per counter. Realistic memory: < 30 bytes per companion per fight. |
| Data mis-tag (Druid 3192, 3447 tagged Snare but effect is Root). | Low | Low | Gate handles both types via the same helper. Functionally benign. data-expert decides whether to correct the tag for consistency. |
| Rule changes mid-fight via `#rule_set` take effect on next AI tick — a target currently in the "old window" could suddenly become eligible/ineligible. | Low | Trivial | Rule changes mid-fight are an admin action, not a player action. |
| Necromancer Darkness spells combine snare with DoT — but they're tagged ONLY as `SpellType_Snare`, and AI_Necromancer has no Snare branch. So they don't fire anyway. Out of scope for this feature. | N/A | N/A | Documented as latent bug; not addressed here. |
| The resist hook in `Mob::SpellOnTarget` runs on every full resist for every caster. `IsCompanion()` virtual dispatch + `m_companion_spells` linear scan when companion. < 1μs per snare/root resist. | Very Low | Very Low | Hot path is unaffected for non-Companion casters (single comparison). For Companions, scan is bounded by spell-set size (~20-30 entries). |
| Renaming `AI_Druid`'s Root branch from "Root if balanced/aggressive" semantics to "movement control if fleeing low-HP" is a player-observable behavior change. Players who rely on Druid root-locking mobs at high HP for kiting will notice. | Medium | Medium — this IS the intended user-facing change but it's broader than PRD wording originally suggested. | Document in user-facing release notes. The user's reported complaint was about Druid spam; this is the fix. Operators who want pre-feature behavior set `SnareHpThreshold = 100`. |

### Compatibility Risks

**Could this break existing behavior?**

- **AI_Druid Root branch gating** is a player-observable change.
  Pre-feature: Druid roots fleeing or non-fleeing targets at any
  HP, with the only constraint being "target not already rooted."
  Post-feature: Druid roots ONLY targets at <=25% HP and fleeing.
  This change matches what the user actually wants but exceeds
  PRD literal scope.
- **AI_Ranger Snare branch gating** is the same change pattern.
  Per PRD intent.
- **AI_Bard Snare branch gating** is the same. PRD doesn't
  enumerate Bard but the rule applies uniformly.
- **All other AI handlers (AI_Necromancer, AI_Shaman, AI_Cleric,
  etc.) are unchanged.** Any spell types they DO route are not
  in scope.
- **NPC fallback path** (`mob_ai.cpp:321` SpellType_Snare
  branch) is unchanged. Only fires when `m_companion_spells`
  is empty.
- **Non-companion NPC snares/roots unchanged.** Hostile NPCs
  still snare/root players per their original logic.

**What needs regression testing?**

- AC-1, AC-2, AC-3, AC-4, AC-5, AC-6 (now covers Druid+Ranger
  for movement-control instead of just snare-line for the four
  named classes), AC-7, AC-9 (root behavior — no longer
  unaffected; updated AC needed), AC-10, AC-11.
- Druid HoT-vs-direct-heal selection unchanged.
- Druid's other engaged branches (heal, cure, DoT, nuke) unchanged.

### Performance Risks

- Per-tick gate evaluation: 1 RuleI lookup (cached), 1
  GetHPRatio(), 1 IsFleeing(), 1 unordered_map lookup.
  < 200ns. Negligible.
- Resist hook: 1 IsCompanion() virtual + (when Companion)
  1 unordered_map insert + ~20-entry linear scan of
  m_companion_spells. < 1μs per resist. Resists are infrequent.
- Memory: O(targets-this-fight) entries. Typical 1-3.

## Review Passes

### Pass 1: Feasibility

Yes. Every required hook exists. Re-verified against live
database 2026-05-04. The corrected understanding is grounded
in actual data.

**Hardest part:** confirming the user's "Druid ensnare spam"
maps to the Root branch (not the Snare branch). Verified by:
1. Querying `companion_spell_sets` for Druid `spell_type=4`
   entries — found 6 root spells (76, 77, 249, 490, 1608,
   1719) named Engulfing/Ensnaring/Grasping/Enveloping/
   Entrapping/Engorging Roots.
2. Querying `spells_new` for those IDs — confirmed effect
   ID 99 (Root) on each.
3. Querying `companion_spell_sets` for Druid `spell_type=128`
   — found 5 spells, but AI_Druid has no SpellType_Snare branch
   to consume them.
4. Concluded: AI_Druid's actual cast pattern routes through
   the Root branch (line 1235), and the user is calling those
   "ensnare" because of the spell names.

### Pass 2: Simplicity

What's in scope and necessary:
- Shared `AI_AttemptMovementControl` helper (one place for the
  rule, replaces three branches).
- Resist hook in `SpellOnTarget` (cleanest signal).
- Counter clear on engagement-end (piggyback existing edge).
- Counter clear on target-change (one line at top of helper).
- Two new rules.

What's deferred:
- Manual `/command` override (no command exists today).
- New AI branches for unused snare/root types (not user
  complaint, expanded behavior).
- Necromancer Darkness DoT routing (latent bug, separate feature).

### Pass 3: Antagonistic

| Edge case | Behavior |
|-----------|----------|
| Mob enters flee at 25% HP. Default threshold is 25. Gate unlocks immediately on flee. | Correct alignment. |
| Mob is healed back above 25%. Existing snare/root buff continues until natural fade. Gate locks against re-cast. | Correct. |
| Scripted flee at 80% HP. | `target_hpr > hp_threshold`. Gate denies. No autonomous snare/root. |
| Calm-temperament mob below 25% HP that doesn't flee. | Gate denies. |
| Existing snare/root lands, then is dispelled or fades. | No resist event. Counter unchanged. Gate may re-fire if conditions still met. |
| Snare/root lands successfully but breaks early due to damage. | No resist event (different code path). Counter unchanged. |
| Two snare-capable companions in the same group. | Each has its own counter map. |
| Companion dies and is rezzed mid-fight. Counter persists in memory until destroyed or engagement-end. After rez, `m_was_engaged` may not reflect the gap correctly. | Defense-in-depth: clear counters in `Companion::Death` and on `Unsuspend`. Add to task 3 implementation. |
| Companion swap mid-fight. | New entity = fresh map. |
| Multi-mob fight, snare on Mob A resists, target switches to Mob B. | `m_last_movement_control_target_id` differs; map clears at top of helper. Mob B counter fresh. |
| Mob de-aggros, resets, then re-pulled. | `m_was_engaged` transitions when companion drops off hate list. Counter clears. |
| Player explicitly commands snare/root cast. | Cannot occur in current scope. AC-8 is N/A. |
| Race: cast START fires, mob dies before resolution. | Existing handling in `SpellOnTarget` covers this. |
| Rule `SnareHpThreshold = 100`. | Gate condition always opens. Snare/root fires whenever target IsFleeing. Resist counter still applies. |
| Rule `SnareResistLimit = 0`. | Cap branch skipped. Companion attempts every eligible tick. |
| Companion's `m_companion_spells` is empty. Falls back to NPC AI. | Gate does NOT apply (we did not modify mob_ai.cpp). Pre-feature behavior. Production companions should have spell sets. |

### Pass 4: Integration

Sequence:

1. **config-expert** task 1: RULE_INT macros.
2. **data-expert** task 2 (parallel): optional audit/correction.
3. **c-expert** tasks 3-8: C++ implementation, single coherent
   commit.
4. **c-expert** task 9: rebuild + restart.
5. **config-expert** task 10: rule_values seed + `#reloadrules`.
6. Hand off to game-tester.

Critical hazard: **Don't run game-tester until task 10
completes.** `RuleI()` returns 0 for missing rules; with
`SnareHpThreshold = 0`, the gate suppresses ALL movement-control
casts.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| config-expert | 1, 10 | Owns `common/ruletypes.h` (task 1, pre-build) and `rule_values` SQL seed (task 10, post-build via `#reloadrules`). |
| data-expert | 2 | Owns `companion_spell_sets` content. Audit + optional correction. |
| c-expert | 3, 4, 5, 6, 7, 8, 9 | All C++ work in `eqemu/zone/` plus rebuild integration. |

protocol-agent: no implementation work. lua-expert, perl-expert,
infra-expert: no work for this feature.

## Validation Plan

The validation plan covers movement-control casts (snare-line
AND root-line). game-tester verifies each PRD AC, with the
note that several ACs need re-interpretation under the
expanded scope (root included).

- [ ] **AC-1 (no movement-control during normal combat).**
      Pull a non-trivial mob with a Druid companion. Druid
      does NOT cast Engulfing Roots or any other root/snare
      while target HP > 25%. Run for 60s across 3 fights.
- [ ] **AC-2 (movement-control fires at flee threshold).**
      Engage a mob to ~25% HP. Mob enters flee. Druid casts
      a root within 2-3 AI ticks.
- [ ] **AC-3 (two-resist cutoff).** High-MR mob. At flee+25%,
      Druid casts root — resists. Casts again — resists.
      Druid does NOT cast root a third time on that mob.
- [ ] **AC-4 (counter resets on new target).** Chain pull.
      Druid 2-resists Mob A, Mob A dies. Pull Mob B. At Mob B
      flee, Druid casts root on Mob B (counter fresh).
- [ ] **AC-5 (multi-mob isolation).** 2-mob fight. Druid
      caps on Mob A. Mob B reaches flee. Druid casts root on
      Mob B (Mob B fresh; the wipe-on-target-change semantic
      means Mob A counter also resets, which is acceptable).
- [ ] **AC-6 (Druid AND Ranger obey the rule).** Repeat
      AC-1 and AC-2 with a Ranger companion. Ranger casts
      Snare/Ensnare under the same gate.
- [ ] **AC-7 (out-of-combat unaffected).** Companion casts
      snare/root freely during pulls / kiting setups.
- [ ] **AC-8 (manual command override).** **N/A — no manual
      snare/root command exists.** Recorded with documented
      reason.
- [ ] **AC-9 (root spells unaffected).** **REINTERPRETED
      under scope expansion:** root-line spells now ARE
      gated. Original PRD AC-9 wording is superseded by AC-1
      and AC-2 covering both snare and root.
- [ ] **AC-10 (player snare/root unaffected).** Player
      Druid casting Ensnaring Roots or Ensnare on a target
      works exactly as before. Hook is on `IsCompanion()` only.
- [ ] **AC-11 (tunables work).** `Companions:SnareHpThreshold
      = 30` opens gate at 30%. `SnareResistLimit = 1` caps
      at 1 resist.
- [ ] **AC-12 (mana savings observable).** Compare end-of-fight
      mana % across 5 fights pre vs post.

**Sustained-play test scenarios:**

- [ ] Long engagement (5+ minutes). No counter leak.
- [ ] Chain pull (10+ targets). Counters reset cleanly.
- [ ] Companion death + rez during the same fight. Counters
      don't double-fire engagement-end.
- [ ] Companion zone-in mid-engagement. `m_movement_control_
      resist_counts` initializes empty.
- [ ] Druid AND Ranger verify both classes cast their movement-
      control spells in the right conditions and refrain in
      the wrong conditions.

---

> **Next step:** Confirm scope decision with the user
> (Option 2 assumed in this document). Then spawn the
> implementation team:
>
> - **c-expert** (tasks 3-9)
> - **config-expert** (tasks 1, 10)
> - **data-expert** (task 2)
>
> Tasks 1 and 2 parallel. Task 3 after Task 1. Tasks 4-8
> sequential after Task 3. Task 9 (rebuild) gates Task 10.
> After Task 10, hand off to game-tester.
