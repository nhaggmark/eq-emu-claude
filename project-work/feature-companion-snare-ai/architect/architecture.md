# Companion Snare AI: Combat Restriction — Architecture & Implementation Plan

> **Feature branch:** `feature/companion-snare-ai`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-05-04
> **Status:** Approved (Architecture phase)

---

## Executive Summary

Restrict autonomous companion-AI casting of snare-line (movement-slow)
spells in active combat to targets that are simultaneously at or below
the configured HP threshold AND in low-HP flee state. Track a per-
(companion, target) full-resist counter and stop autonomous snare
attempts on a target after the configured limit is reached. Counter
resets on engagement-end and on target change. Out-of-combat behavior
unchanged. The implementation is **pure C++** in `eqemu/zone/`, with
two new rules in `common/ruletypes.h`, two `INSERT INTO rule_values`
seeds, and a small data-expert task to ensure the snare-line spells
for DRU/RNG/NEC/SHM are present in `companion_spell_sets` tagged
with `spell_type = SpellType_Snare`.

The gate is centralized in **one shared helper**
(`Companion::AI_AttemptSnare`) that every class handler calls, so the
rule lives in one place. The Druid, Necromancer, and Shaman class AI
handlers in `companion_ai.cpp` do **not** currently route
`SpellType_Snare` — adding a branch that calls `AI_AttemptSnare` is
part of the work, not optional. Bard already routes snare today and
gets the same gate treatment for consistency, even though the PRD
doesn't enumerate it.

The most consequential design call: classify snare-line spells **only**
by the existing `SpellType_Snare` bitmask tag stored in
`companion_spell_sets.spell_type`. Do not name-match — Necromancer
snare-line names ("Clinging Darkness", "Dooming Darkness") do not
contain the word "snare" and would silently bypass any name filter,
leaving Necromancer snare spam in place. Lore-master verified this
load-bearing detail.

## Existing System Analysis

### Current State

**Entity hierarchy.** Companion is a customized subclass of NPC
(`eqemu/zone/companion.h:77`), holding its spell list in
`m_companion_spells` (`std::vector<CompanionSpell>`,
`companion.h:524`). Each `CompanionSpell` has `spellid`, `type`
(SpellType bitmask), `stance`, `slot` (priority), `time_cancast`
(per-spell cooldown), and HP-threshold fields (`min_hp_pct`,
`max_hp_pct`).

**AI dispatch.** Companion AI cast pipeline (call chain):

```
NPC::AI_Process (zone/mob_ai.cpp)
  → Companion::AI_EngagedCastCheck   (companion.cpp:2271)
  → Companion::AICastSpell           (companion_ai.cpp:359)
    → switch(GetClass())
       ├ AI_Druid       (companion_ai.cpp:1160)
       ├ AI_Ranger      (companion_ai.cpp:1459)
       ├ AI_Necromancer (companion_ai.cpp:1643)
       ├ AI_Shaman      (companion_ai.cpp:1283)
       ├ AI_Bard        (companion_ai.cpp:1758)
       └ ...others
    → Companion::AIDoSpellCast       (companion.cpp:2320)
      → Mob::CastSpell
        → ... eventually Mob::SpellOnTarget (spells.cpp:3907)
          → ResistSpell (spells.cpp:5306)
            → resist branch at spells.cpp:4508 (full resist)
```

**Snare classification.** `SpellType_Snare` is a bit in the
`SpellTypes` enum (`common/spdat.h:639`, `(1 << 7)`). Each row in
`companion_spell_sets` carries a `spell_type` column populated by the
data-expert. Selection helper: `GetSpellsForType` and
`SelectFirstSpell` in `companion_ai.cpp` filter by mask.

**Existing snare cast branches in companion AI.**

| Class      | File                  | Behavior today |
|-----------|----------------------|----------------|
| Ranger    | companion_ai.cpp:1467-1483 | `if (iSpellTypes & SpellType_Snare && zone->random.Roll(30))`, gated only by `SnareImmunity` and `GetSnaredAmount() >= 0`. **No HP / flee gate.** This is the spam offender for Ranger. |
| Bard      | companion_ai.cpp:1788-1802 | `if (iSpellTypes & SpellType_Snare && zone->random.Roll(20))`, same gates as Ranger. **No HP / flee gate.** Spam offender for Bard, even though PRD doesn't enumerate Bard. |
| Druid     | AI_Druid              | **No `SpellType_Snare` branch.** If the data-expert lists Ensnare with `spell_type = SpellType_Snare`, nothing in AI_Druid will fire it today. |
| Necromancer | AI_Necromancer      | **No `SpellType_Snare` branch.** Same gap as Druid. |
| Shaman    | AI_Shaman             | **No `SpellType_Snare` branch.** Same gap. (Shaman has a `SpellType_Slow` branch — different effect.) |
| NPC fallback | mob_ai.cpp:321-339 | Base-NPC SpellType_Snare branch fires when `m_companion_spells` is empty (Companion falls back to NPC native AI). 50% roll, no HP/flee gate. |

**Flee state observability.** `Mob::IsFleeing()` (`mob.h:1251`)
returns the `flee_mode` member, set by `Mob::StartFleeing()` from
`fearpath.cpp` when a mob's HP ratio drops below `Combat:FleeHPRatio`
(default 25). This is an O(1) member read — cheap, no scan, no
allocations. Same `flee_mode` clears via `StopFleeing()` when the
mob is healed back above threshold or pacified. Distinct from
`Mob::IsFeared()` which returns `(spellbonuses.IsFeared || flee_mode)`
— our gate consumes `IsFleeing()` only (low-HP flee), per PRD intent
"reach flee threshold and start running."

**Resist signal pathway.** `Mob::SpellOnTarget` (`spells.cpp:3907`)
runs the resist roll through `Mob::ResistSpell` (`spells.cpp:5306`).
At `spells.cpp:4508-4555`, when `spell_effectiveness < 100` AND
either fully resisted or non-partial-resistable, the spell is
treated as a full resist: `LogSpells("Spell [{}] was completely
resisted by [{}]", ...)`, message strings sent, hate added if
applicable, `safe_delete(action_packet)`, `return false`. The
caster (`this`) is the Companion in our scenarios.

There is already precedent for **owner-visible resist messaging**
for bots: `if (IsBot() && RuleB(Bots, ShowResistMessagesToOwner))`
at `spells.cpp:4519`. Companions do not currently emit a parallel
message. This is fine — silent suppression is intended.

**Engagement-boundary signal.** Companion already maintains a
previous-tick engagement state member: `m_was_engaged`
(`companion.h:587`). Each tick of `Companion::Process`
(`companion.cpp:1992-2000`):

```cpp
bool currently_engaged = IsEngaged();
if (m_was_engaged && !currently_engaged) {
    // Combat just ended — start the rez delay timer
    ...
}
m_was_engaged = currently_engaged;
```

This is a clean transition signal already used by the rez subsystem.
We piggyback the snare-resist counter clear on the same edge.

**Rule namespace.** `common/ruletypes.h:1182-1255` defines
`RULE_CATEGORY(Companions)` with 44+ existing companion rules,
including patterns like `Companions:HealThresholdPct`,
`Companions:ManaCutoffPct`, `Companions:HealerManaConservePct`,
`Companions:LOMThresholdPct`. Our two new rules conform exactly.

**Companion command system.** Per
`claude/docs/companion-commands-reference.md`, no `!snare` or
generic `!cast` command exists today. The closest analogues are
`!buffme`/`!buffs` (buff queue) and `!assist` (forced melee
engagement). There is **no current path** for a player to manually
direct a companion to cast a specific spell at a specific target.
The PRD's "manual command override bypasses the rule" is therefore
moot in current scope — there is nothing to bypass.

### Gap Analysis

What's missing between current state and PRD requirements:

1. **Gate logic.** No HP-threshold-AND-fleeing gate exists in any
   companion snare branch today.
2. **Resist counter.** No per-(companion, target) snare-resist
   tracking exists.
3. **Counter reset on engagement boundary.** No hook on
   `m_was_engaged` transition for snare counters (the hook itself
   exists for rez; we add a sibling action).
4. **AI handler routing.** Druid, Necromancer, Shaman class AI
   does not route `SpellType_Snare` at all — their handlers must
   be extended to call the shared snare attempt helper. (The
   feature is incomplete without these branches even after the
   gate is built.)
5. **Two tunable rules.** `Companions:SnareHpThreshold` and
   `Companions:SnareResistLimit` do not exist.
6. **Data tagging.** `companion_spell_sets` must contain rows for
   DRU/RNG/NEC/SHM snare-line spells with `spell_type =
   SpellType_Snare` (data-expert verifies; small or no work).

Out of current scope (per PRD, deliberate non-goals):

- No manual `/command` snare override — there is no existing path
  to override, and adding one is a separate feature.
- No client-side change. Pure server-side AI gating.
- No new opcodes, no new packets, no Titanium-format work.

## Technical Approach

### Architecture Decision

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `common/ruletypes.h` (Companions category) | Add 2 RULE_INTs | Tunable thresholds without rebuild for tuning passes. Conforms to existing `Companions:*` namespace. |
| `rule_values` table | INSERT 2 default rows | Seed defaults (20, 2) into ruleset 1. |
| `eqemu/zone/companion.h` | Add 1 method, 2 helpers, 1 member | New: `CompanionSnareCounters m_snare_resist_counts` (per-target map), `OnSpellResisted(spellid, target)` hook, `AI_AttemptSnare(target)` shared helper, `ClearSnareResistCounters()` on engagement-end. |
| `eqemu/zone/companion_ai.cpp` | Add shared helper, route through 5 class handlers | Implements gate (HP <= rule, IsFleeing(), counter < limit). Each existing handler that should snare calls it. |
| `eqemu/zone/companion.cpp` | Hook engagement transition, target change | At the existing `m_was_engaged` site, clear the counter map on engaged→idle. Also clear on target change. |
| `eqemu/zone/spells.cpp` | One ~3-line hook in `SpellOnTarget` | Call `caster->CastToCompanion()->OnSpellResisted(spell_id, spelltar)` inside the existing full-resist branch when `caster->IsCompanion()` and `spell_type & SpellType_Snare`. Zero behavioral change for non-companion casters. |
| `companion_spell_sets` | Verify (or add) DRU/RNG/NEC/SHM snare-line entries with `spell_type = SpellType_Snare` | Data-expert verification. May be no-op if already tagged. |

**Least-invasive ladder.** No Lua change. No SQL schema change. No
new tables. No new opcodes. No client work. The work is one
~80-line C++ addition centered on a single shared method, two
rules, two seed inserts, and (likely) a data-expert audit pass.

### Data Model

**No schema changes.** The `companion_spell_sets` table already has
the `spell_type` column. The work for data-expert is to ensure
the right rows exist with the right tag.

**Per-(companion, target) counter** lives in **runtime memory only**:

```cpp
// In Companion (private):
//   Maps target entity ID -> consecutive full-resist count.
//   Cleared on engagement boundary, on target change.
std::unordered_map<uint16, uint8> m_snare_resist_counts;
```

Map size: one entry per target-the-companion-tried-to-snare during
the current engagement. Practical max: handful per fight. Zero
persistent storage — counters are per-fight and per-engagement.

**Two new rule rows:**

```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES
(1, 'Companions:SnareHpThreshold', '20',
 'Target HP percentage at or below which companions are allowed to autonomously cast snare-line spells. The target must ALSO be in flee state. Lower = stricter. Set to 100 to disable the HP gate (allow snare anywhere a fleeing target exists). Default 20 per PRD.'),
(1, 'Companions:SnareResistLimit', '2',
 'Number of consecutive full resists on the same target after which the companion stops attempting autonomous snare on that target for the remainder of the engagement. Counter resets on engagement-end and on target change. Set to 0 to disable the cap. Set high (99+) to effectively disable. Default 2 per PRD.');
```

### Code Changes

#### C++ Changes

**1. `common/ruletypes.h` — add 2 rules, just before
`RULE_CATEGORY_END()` at line 1256:**

```cpp
RULE_INT(Companions, SnareHpThreshold, 20,
    "Target HP percent at or below which a companion's autonomous AI is allowed to "
    "cast snare-line spells. The target must ALSO be in flee state (Mob::IsFleeing()). "
    "Set to 100 to disable the HP gate. PRD default 20.")
RULE_INT(Companions, SnareResistLimit, 2,
    "Consecutive full-resists per (companion, target) at which companion stops "
    "attempting autonomous snare on that target for the engagement. Counter resets "
    "on engagement-end and on target change. Set to 0 to disable. PRD default 2.")
```

**2. `eqemu/zone/companion.h` — additions in the Companion class
declaration:**

In the public AI section (near the existing `AI_SlowDebuff` entry,
companion.h:268):

```cpp
// Shared snare attempt with HP-threshold + flee + resist-counter gate.
// Returns true if a snare cast was attempted on `target`. Replaces
// the previous unconditional snare branches in AI_Ranger / AI_Bard,
// and is the entry point that AI_Druid / AI_Necromancer / AI_Shaman
// must call when those handlers want to snare.
bool AI_AttemptSnare(Mob* target);

// Resist event hook fired from Mob::SpellOnTarget when this companion's
// cast is fully resisted. Increments the snare-resist counter only when
// the spell carries SpellType_Snare in its companion-spell-set entry.
// No-op for any other resist (heals, nukes, debuffs, etc.).
void OnSpellResisted(uint16 spell_id, Mob* target);

// Clears all per-target snare resist counters. Called on engaged->idle
// transition (existing m_was_engaged hook) and on target change.
void ClearSnareResistCounters();
```

In the private section (near `m_xp_lost_on_death`):

```cpp
// Per-(this companion, target_entity_id) consecutive full-resist count
// for SpellType_Snare casts. Cleared on engagement-end and target change.
// Runtime-only; not persisted.
std::unordered_map<uint16, uint8> m_snare_resist_counts;
```

**3. `eqemu/zone/companion_ai.cpp` — implement the shared gate
helper. Add this near the existing `AI_SlowDebuff` (around line
869):**

```cpp
// ============================================================
// AI_AttemptSnare — shared snare gate
//
// PRD requirements:
//   * Out-of-combat: gate does not apply (return early -> proceed normally)
//   * In-combat: target HP <= Companions:SnareHpThreshold AND target
//     IsFleeing(). Both must be true.
//   * Per-(companion, target) full-resist counter, cap at
//     Companions:SnareResistLimit. Cleared on engagement-end and
//     target change.
//   * No chat spam on suppression.
//
// Returns true if a snare cast was attempted (CastSpell started),
// false otherwise (gate failed, no spell available, or target ineligible).
//
// Centralizing all snare-cast logic here means there is exactly one
// place that decides "should this companion snare this target right
// now." Class handlers call this from their engaged branch.
// ============================================================
bool Companion::AI_AttemptSnare(Mob* target)
{
    if (!target || target->GetHP() <= 0) {
        return false;
    }

    // Cheap eligibility checks (preserve pre-existing behavior — these
    // are NOT part of the new rule, just the same checks the old
    // Ranger/Bard branches already did).
    if (target->GetSpecialAbility(SpecialAbility::SnareImmunity)) {
        return false;
    }
    if (target->GetSnaredAmount() >= 0) {
        // Already snared — no need to re-cast.
        return false;
    }

    // Spell availability check
    uint32 now_ms = Timer::GetCurrentTime();
    uint16 snare_spell = SelectFirstSpell(
        m_companion_spells, SpellType_Snare, m_current_stance, now_ms);
    if (!snare_spell) {
        return false;
    }

    // ---------------- THE NEW GATE ----------------
    // Out-of-combat: rule does not apply. Companion may snare freely
    // during pulls / kiting / pre-engagement positioning.
    if (IsEngaged()) {
        // In-combat: both conditions required.
        const int hp_threshold = RuleI(Companions, SnareHpThreshold);
        const int target_hpr   = static_cast<int>(target->GetHPRatio());
        const bool fleeing     = target->IsFleeing();

        if (target_hpr > hp_threshold || !fleeing) {
            // Silent suppression — no chat, no emote, no log spam.
            return false;
        }

        // Resist-counter cap. Lookup is O(1) on small per-fight map.
        const int resist_limit = RuleI(Companions, SnareResistLimit);
        if (resist_limit > 0) {
            auto it = m_snare_resist_counts.find(target->GetID());
            if (it != m_snare_resist_counts.end() &&
                it->second >= static_cast<uint8>(resist_limit)) {
                return false;
            }
        }
    }
    // ----------------------------------------------

    // Standard cast path — preserved from existing snare branches.
    bool cast_ok = AIDoSpellCast(snare_spell, target, spells[snare_spell].mana);
    if (cast_ok) {
        SetSpellTimeCanCast(snare_spell, spells[snare_spell].recast_time);
    }
    return cast_ok;
}

// ============================================================
// OnSpellResisted — called from Mob::SpellOnTarget on full resist.
// Only counts SpellType_Snare resists. Heal/buff/debuff/nuke
// resists are ignored.
// ============================================================
void Companion::OnSpellResisted(uint16 spell_id, Mob* target)
{
    if (!target) {
        return;
    }

    // Only count snare-line resists. Look up the spell type from
    // m_companion_spells (the per-companion spell list, which is the
    // source of truth for "what type is this spell for this companion").
    bool is_snare = false;
    for (const auto& cs : m_companion_spells) {
        if (cs.spellid == spell_id && (cs.type & SpellType_Snare)) {
            is_snare = true;
            break;
        }
    }
    if (!is_snare) {
        return;
    }

    // Increment per-target counter (default-initialized to 0 on insert).
    uint16 tid = target->GetID();
    uint8& count = m_snare_resist_counts[tid];
    if (count < 255) {
        ++count;
    }

    LogAIDetail("Companion [{}] OnSpellResisted: snare [{}] on target [{}] (entity_id [{}]) — count now [{}]",
                GetName(), spell_id, target->GetName(), tid, count);
}

// ============================================================
// ClearSnareResistCounters — wipe all counters on engagement-end
// or target change.
// ============================================================
void Companion::ClearSnareResistCounters()
{
    if (!m_snare_resist_counts.empty()) {
        m_snare_resist_counts.clear();
    }
}
```

**4. `eqemu/zone/companion_ai.cpp` — replace the existing Ranger
snare branch (lines 1467-1483) with a call to the shared helper:**

```cpp
// Snare to prevent fleeing enemies — gated by HP/flee rule.
// (Preserves the original 30% throttle so we don't try every tick.)
if ((iSpellTypes & SpellType_Snare) && zone->random.Roll(30)) {
    if (AI_AttemptSnare(GetTarget())) {
        return true;
    }
}
```

**5. `eqemu/zone/companion_ai.cpp` — replace the existing Bard
snare branch (lines 1788-1802) similarly:**

```cpp
// Snare fleeing targets — gated by HP/flee rule.
if ((iSpellTypes & SpellType_Snare) && zone->random.Roll(20)) {
    if (AI_AttemptSnare(GetTarget())) {
        return true;
    }
}
```

**6. `eqemu/zone/companion_ai.cpp` — add a snare branch to AI_Druid,
inside the `if (engaged)` block, ordered AFTER heal/cure but BEFORE
the existing Root branch (so snare is preferred over root for low-HP
fleeing targets):**

```cpp
// Snare fleeing low-HP enemies — gated by HP/flee rule.
if ((iSpellTypes & SpellType_Snare) && zone->random.Roll(50)) {
    if (AI_AttemptSnare(GetTarget())) {
        return true;
    }
}
```

**7. `eqemu/zone/companion_ai.cpp` — add a snare branch to
AI_Necromancer, inside `if (engaged)`, ordered after lifetap and
before generic nuke (so necro will land snare on fleeing low-HP
targets without competing with DoT priorities):**

```cpp
// Snare fleeing low-HP enemies — gated by HP/flee rule.
if ((iSpellTypes & SpellType_Snare) && zone->random.Roll(50)) {
    if (AI_AttemptSnare(GetTarget())) {
        return true;
    }
}
```

**8. `eqemu/zone/companion_ai.cpp` — add a snare branch to AI_Shaman,
inside `if (engaged)`, ordered after slow and heal (slow is the
shaman's signature debuff; snare is supplemental):**

```cpp
// Snare fleeing low-HP enemies — gated by HP/flee rule.
if ((iSpellTypes & SpellType_Snare) && zone->random.Roll(50)) {
    if (AI_AttemptSnare(GetTarget())) {
        return true;
    }
}
```

**9. `eqemu/zone/companion.cpp` — at the existing `m_was_engaged`
transition site (line ~1993, currently used to start the rez delay
timer), also clear the snare resist counters on engagement-end. Also
clear when the companion's target changes mid-fight:**

```cpp
bool currently_engaged = IsEngaged();
if (m_was_engaged && !currently_engaged) {
    // Combat just ended — start the rez delay timer
    if (RuleB(Companions, RezEnabled)) {
        m_rez_delay_timer.Start(RuleI(Companions, RezPostCombatDelayS) * 1000);
        m_rez_meditation_announced = false;
    }
    // Snare gate: clear per-target resist counters when combat ends.
    ClearSnareResistCounters();
}
m_was_engaged = currently_engaged;
```

For the target-change case, the simplest hook is in
`Companion::AICastSpell` near the top: capture the
`current_target_id_for_snare` and compare against last tick's. But
the cleaner fix is to override `Mob::SetTarget` on Companion. Inspect
existing SetTarget pattern: there is no Companion::SetTarget today.
Adding one is a small Mob override — risky. **Defer to AICastSpell-
local detection**: at the top of `AI_AttemptSnare`, read the current
target ID and compare to a `m_last_snare_target_id` member; on
mismatch, clear the map first. This avoids touching SetTarget.

```cpp
// At top of AI_AttemptSnare:
uint16 tid = target->GetID();
if (tid != m_last_snare_target_id) {
    m_snare_resist_counts.clear();
    m_last_snare_target_id = tid;
}
```

(Adds `uint16 m_last_snare_target_id = 0;` private member.)

**Resist hook site choice — architect note.** protocol-agent
recommended hooking `Companion::CastedSpellFinished()` instead of
`Mob::SpellOnTarget`. Architect chose `SpellOnTarget` for surgical
clarity: it is the single source of truth for "this spell was
fully resisted by this target" and works uniformly across
single-target / AE / group spells. `CastedSpellFinished` is broader
(covers fizzle / interrupt / OOM / resist) and would require
internal differentiation. The fallback is documented: if c-expert
hits scope or include challenges with the SpellOnTarget hook,
moving the hook to `Companion::CastedSpellFinished` (overriding
`Mob::CastedSpellFinished`) is acceptable and produces equivalent
behavior for our case.

**10. `eqemu/zone/spells.cpp` — hook the resist branch (around line
4554, just before `safe_delete(action_packet); return false;`):**

```cpp
// Companion snare gate: count this resist if caster is a Companion
// and the spell is in its snare-line spell set. No-op for any other
// caster type or spell type. Safe inside the resist branch — only
// runs on confirmed full resist.
if (this->IsCompanion()) {
    this->CastToCompanion()->OnSpellResisted(spell_id, spelltar);
}
```

The hook is a single line at one site. Other resist sites
(`spelltar->MessageString(Chat::SpellFailure, YOU_RESIST...)`,
hate addition, sneak/feign break) are unaffected.

#### Lua/Script Changes

**None.** This is pure server-side AI logic.

#### Database Changes

**No schema changes.**

**Two `INSERT INTO rule_values` seeds** (the data-expert task is
trivial; config-expert produces the SQL):

```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES
(1, 'Companions:SnareHpThreshold', '20',
 'Target HP percent at or below which companions may autonomously snare. Target must ALSO be IsFleeing(). Default 20 per PRD.'),
(1, 'Companions:SnareResistLimit', '2',
 'Consecutive full-resists per (companion, target) before companion stops attempting autonomous snare on that target for the engagement. Counter resets on engagement-end and target change. Default 2 per PRD.');
```

**Optional data-expert audit:** verify `companion_spell_sets` has
rows for DRU/RNG/NEC/SHM snare-line spells with `spell_type =
SpellType_Snare` (= 128, decimal value of `(1 << 7)`). For Necro,
the relevant in-era spells are Clinging Darkness and Dooming
Darkness — confirm by spell ID, not by name. If absent, add rows.
If already present, no-op.

#### Configuration Changes

Two new entries in `common/ruletypes.h`:

- `Companions:SnareHpThreshold` (RULE_INT, default 20)
- `Companions:SnareResistLimit` (RULE_INT, default 2)

No `eqemu_config.json` changes. No `.env` changes.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Add 2 RULE_INT entries to `common/ruletypes.h` (Companions category) for `SnareHpThreshold` (default 20) and `SnareResistLimit` (default 2). | config-expert | — | ~10 lines, one file |
| 2 | Audit `companion_spell_sets` for DRU/RNG/NEC/SHM rows with the appropriate snare-line spell IDs and `spell_type = 128` (SpellType_Snare). For each missing class+level slot in the in-era range (1-65), add a row. Document by spell ID, never by name. Flag any data-divergence. | data-expert | — | Mostly verification; small INSERT set if gaps exist. Run in parallel with task 1. |
| 3 | Implement `Companion::AI_AttemptSnare(Mob*)`, `Companion::OnSpellResisted(uint16, Mob*)`, `Companion::ClearSnareResistCounters()`. Add `m_snare_resist_counts` and `m_last_snare_target_id` private members in `companion.h`. | c-expert | 1 (rules must exist for `RuleI(Companions, SnareHpThreshold)` to compile) | ~80 lines C++ |
| 4 | Replace the existing `SpellType_Snare` branch in `AI_Ranger` (companion_ai.cpp:1467-1483) with a call to `AI_AttemptSnare`. Preserve the existing 30% throttle. | c-expert | 3 | ~6 line replacement |
| 5 | Replace the existing `SpellType_Snare` branch in `AI_Bard` (companion_ai.cpp:1788-1802) with a call to `AI_AttemptSnare`. Preserve the existing 20% throttle. | c-expert | 3 | ~6 line replacement |
| 6 | Add a `SpellType_Snare` branch to `AI_Druid`. Position after heal/cure, before existing Root branch. 50% throttle. Calls `AI_AttemptSnare`. | c-expert | 3 | ~6 lines |
| 7 | Add a `SpellType_Snare` branch to `AI_Necromancer`. Position after lifetap, before generic nuke. 50% throttle. Calls `AI_AttemptSnare`. | c-expert | 3 | ~6 lines |
| 8 | Add a `SpellType_Snare` branch to `AI_Shaman`. Position after slow/heal/cure. 50% throttle. Calls `AI_AttemptSnare`. | c-expert | 3 | ~6 lines |
| 9 | Add `ClearSnareResistCounters()` call to the existing `m_was_engaged && !currently_engaged` site in `Companion::Process` (companion.cpp:1993-2000). | c-expert | 3 | ~2 lines |
| 10 | Add the `SpellOnTarget` resist hook in `eqemu/zone/spells.cpp` (~line 4554, inside the existing full-resist branch, right before `safe_delete(action_packet)`). Guarded by `this->IsCompanion()`. Calls `CastToCompanion()->OnSpellResisted(spell_id, spelltar)`. | c-expert | 3 | ~3 lines |
| 11 | Build and restart the eqemu-server container. Confirm no compile warnings, server boots clean, no test regressions. Build path: `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`. Restart via `make restart` from akk-stack/, then start zone processes per project memory. | c-expert | 4,5,6,7,8,9,10 | Build + restart + smoke test |
| 12 | After rebuild + restart, insert the 2 default `rule_values` rows for `Companions:SnareHpThreshold` and `Companions:SnareResistLimit`. Use `INSERT IGNORE` or guard with `WHERE NOT EXISTS` for idempotence. Run `#reloadrules` in-game to pick up the values without further restart. | config-expert | 11 (rebuild must complete first — `_FindRule()` only finds compile-time-defined rules) | ~6 lines SQL |

**Sequence summary.** Tasks 1 and 2 are independent and can run
in parallel. Task 3 depends on Task 1 only (needs RULE_INT to
exist for the C++ to compile). Tasks 4-10 are sequential after
task 3 (each touches `companion_ai.cpp` and serializing avoids
merge friction). Task 11 (rebuild + restart) is the integration
step. Task 12 (rule_values seed) MUST come after rebuild +
restart because `#reloadrules` calls `_FindRule()` which only
matches compile-time-registered rules — see config-expert's note
in `agent-conversations.md` 2026-05-03 entry.

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `Combat:FleeHPRatio` (default 25) is HIGHER than `Companions:SnareHpThreshold` (default 20). A mob enters flee at 25% but our gate doesn't unlock until 20%, so there's a 25%-to-20% window where the mob is fleeing but the companion still won't snare. AC-2 ("Snare fires at flee threshold") might miss by ~5% of HP. | Medium | Low — players will see a slightly delayed snare instead of immediate. Not a regression vs current behavior (current snares from 100% HP, so even with the gap players gain end-of-fight reliability). | Document the relationship in the rule description string. game-tester confirms the snare lands within a few ticks of the mob entering the 20% band, not the 25% band. If the user wants tighter tracking, set `Companions:SnareHpThreshold` to 25 to match `Combat:FleeHPRatio`. |
| `m_snare_resist_counts` could grow unbounded if a fight has many distinct targets. | Very Low | Very Low — typical engagement has 1-3 targets. Map clears on combat end. | `clear()` on engagement-end and target change. Cap at 255 per-counter (uint8). Realistic memory cost: < 30 bytes per companion per fight. |
| If the user changes `Companions:SnareHpThreshold` mid-fight via `#rule_set`, the new value takes effect on the next AI tick. A target currently in the "old window" could suddenly become eligible/ineligible. | Low | Trivial — rule changes mid-fight are an admin action, not a player action. | Document. Don't bother with cooldowns. |
| Necromancer Clinging Darkness and Dooming Darkness combine SE_MovementSpeed with detrimental DoT effects in the same spell. Tagging them `SpellType_Snare` means they show up in the snare branch — but they ARE the necro snare-line. Correct behavior. The risk is double-tagging (also `SpellType_DOT`) which would route the same spell through two branches. | Low | Low — the AI cycle uses a "first hit wins" pattern; the snare branch returning true short-circuits the rest of the engaged path. | Data-expert confirms each row has a single primary `spell_type` bit. If multi-tagged, the routing order in `AI_Necromancer` decides — snare branch ordered AFTER lifetap and BEFORE DoT/nuke is intentional. |
| Adding new branches to AI_Druid, AI_Necromancer, AI_Shaman could shift the relative priority of OTHER existing spells (heals, lifetaps, DoTs). | Low | Low — the new branch only fires if there is a snare spell loaded AND target is in the gate window. In normal combat (target above 20% / not fleeing), the branch returns false within microseconds and downstream branches run normally. | Game-tester runs full-engagement scenarios pre vs post change for each affected class, with no snare spell in companion_spell_sets, and confirms no behavior delta. |
| The `m_was_engaged` transition site is shared with the rez delay timer. Adding `ClearSnareResistCounters()` here is single-line. Potential coupling: if a future engineer changes the rez transition logic, they may forget snare counters. | Low | Low — counters auto-clear on next combat anyway. | Inline comment on both lines explaining the shared edge, citing this architecture doc. |
| The resist hook in `Mob::SpellOnTarget` runs on EVERY full resist for EVERY caster — clients, NPCs, bots, mercs. Adding a `IsCompanion()` branch is one comparison + cheap virtual dispatch. Hot path concern: `Mob::SpellOnTarget` is on the spell-resolution critical path. | Low | Very Low — `IsCompanion()` is a virtual returning a constant. The hook adds < 5ns when not a companion, ~50ns when it is. Modern zones cast O(few) resistable spells per second per zone. Negligible. | None needed. Verified branch is single-comparison, no allocation. |

### Compatibility Risks

**Could this break existing behavior?**

- **Ranger snare today fires at 30% roll on any non-immune,
  non-already-snared target.** After this change, Ranger snare
  fires only when target is fleeing at <=20% HP, with a 2-resist
  cap. **Player-observable behavior change.** Player will notice
  Ranger no longer Ensnaring during normal pulls. Per PRD this is
  the intended outcome — the entire purpose of the feature.
- **Bard snare today fires at 20% roll on any non-immune target.**
  Same change applies. PRD doesn't enumerate Bard but the fix
  generalizes correctly.
- **Druid, Necromancer, Shaman previously NEVER cast snare in
  companion_ai.cpp** (no branch). After this change they will cast
  snare when conditions match. **Net behavior gain** for those
  classes — net behavior loss for Ranger/Bard during the >20% HP
  window.
- **NPC fallback path (`mob_ai.cpp:321`)** still runs the
  un-gated snare logic when `m_companion_spells` is empty.
  Companions with empty spell sets are an edge case (data-expert
  ensures spell sets are populated for all companion classes).
  **Out-of-scope for this feature** — the gate sits on the
  Companion class AI path, not the fallback NPC path. If the
  fallback fires, the gate doesn't apply. game-tester should
  confirm production companions don't drop into the fallback.
- **Non-companion NPC snares unchanged.** The NPC AI path at
  `mob_ai.cpp:321` is unchanged. Hostile NPCs still snare players
  per their original logic.

**What needs regression testing?**

- AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8 (manual command
  is N/A — see below), AC-9, AC-10, AC-11 from the PRD.
- Druid HoT-vs-direct-heal selection unchanged.
- Necromancer DoT/lifetap/pet routing unchanged.
- Shaman slow/cannibalize routing unchanged.
- Existing companion mana conservation behavior unchanged (gate
  short-circuits early — does not consume mana on suppressed casts).

### Performance Risks

- **Per-tick gate evaluation cost.** Per AI tick, the gate adds:
  1 RuleI lookup (cached), 1 GetHPRatio() call, 1 IsFleeing()
  member read, 1 unordered_map lookup. < 200ns per tick per
  candidate snare cast. Negligible.
- **Resist hook cost.** Per full resist, the hook adds 1
  IsCompanion() virtual dispatch and (when companion) 1
  unordered_map insert + linear scan of m_companion_spells (~10-20
  entries) to confirm spell type. < 1μs per snare resist.
  Snare resists are infrequent enough this is irrelevant.
- **Memory.** O(targets-this-fight) entries in the counter map.
  Typically 1-3. ~30 bytes per companion per active fight.
  Wiped on combat end.

## Review Passes

### Pass 1: Feasibility

**Can we actually build this with the existing codebase?**

Yes. Every required hook already exists:

- `IsCompanion()` / `CastToCompanion()` — confirmed present
  (`entity.h:85, 103`).
- `Mob::IsFleeing()` — confirmed present (`mob.h:1251`).
- `m_was_engaged` transition site — confirmed present
  (`companion.cpp:1992-2000`).
- `Mob::SpellOnTarget` full-resist branch — confirmed present
  (`spells.cpp:4508-4555`).
- `SpellType_Snare` bitmask — confirmed present (`spdat.h:639`).
- `Companions:*` rule namespace — confirmed present
  (`ruletypes.h:1182-1255`).
- Existing class-specific AI dispatch — confirmed working
  (`companion_ai.cpp` AI_Ranger, AI_Bard already cast snare
  successfully today).

**Hardest part:** verifying that the data-expert task (ensuring
DRU/NEC/SHM snare-line spells are in `companion_spell_sets` with
`spell_type = SpellType_Snare`) is complete. Without that, only
Ranger and Bard get the new behavior. Mitigation: data-expert
runs a query to enumerate all current SpellType_Snare entries by
class, and the architect's audit checklist names the in-era
spells per class so gaps are obvious.

### Pass 2: Simplicity

**Is this the simplest approach? Can anything be removed or
deferred?**

What's in scope and necessary:
- Shared `AI_AttemptSnare` helper (reduces five copies of gate
  logic to one).
- Resist hook in `SpellOnTarget` (cleanest signal pathway —
  alternatives polled state or returning a "did this resist?"
  bool from `AIDoSpellCast` would require deeper plumbing).
- Counter clear on engagement-end (piggybacks an existing edge).
- Counter clear on target-change (one comparison at top of
  `AI_AttemptSnare`).
- New rules (PRD requires tunability for AC-11).
- New AI branches for DRU/NEC/SHM (without these, the feature
  doesn't apply to 3 of the 4 named classes).

What's deferred:
- **Manual `/command` snare override.** No `!snare` command
  exists today. Adding one is a separate feature. PRD Open
  Question #1 is answered: there's nothing to bypass.
  Game-tester marks AC-8 as "N/A — no manual snare command
  exists; rule applies to all autonomous casts only."
- **Owner-visible resist messages.** Could mirror
  `Bots:ShowResistMessagesToOwner`. Out of scope per PRD's
  silent-suppression directive. Skip.
- **Per-class snare throttle rules.** Each class handler keeps
  its existing `zone->random.Roll()` throttle as a hardcoded
  constant. Could expose as `Companions:SnareCastChancePct` or
  per-class equivalents. Skip for now — config-expert can add
  later if needed; not required by PRD.

What's removed:
- **No new tables.** The runtime counter is in-memory only.
  Persistence is unnecessary — counters are per-engagement.
- **No new opcodes.** No client-visible packet changes.
- **No new emote / chat / sound.** Silent suppression per PRD.
- **No Lua bindings.** No script-side need to read or mutate
  counters.

### Pass 3: Antagonistic

**What could go wrong?**

| Edge case | Behavior |
|-----------|----------|
| Mob enters flee at 25% HP, immediately drops to 20%. Gate unlocks; snare fires. Mob is healed back to 30%. | `flee_mode` is cleared by `Mob::StopFleeing()` (fearpath.cpp:182) when HP recovers above flee threshold. Gate locks again next tick. Companion does not refresh the snare during heal-up window (the existing snare buff continues until natural fade). PRD edge-case #1 satisfied. |
| Scripted flee at 80% HP (e.g., quest mob, fear spell on enemy NPC). | `IsFleeing()` returns true (flee_mode set) but `target_hpr > hp_threshold`. Gate denies. No snare. PRD edge-case #2 satisfied. |
| Calm-temperament mob below 20% HP that doesn't flee. | `IsFleeing()` returns false. Gate denies. No snare. PRD edge-case #3 satisfied. |
| Existing snare lands, then gets dispelled or fades naturally. | No resist event fired. Counter does not increment. Gate may re-fire if conditions still met. PRD edge-case #4 satisfied. |
| Snare lands, then breaks early due to damage. | No resist event fired (the break is a different code path). Counter does not increment. PRD edge-case #5 satisfied. |
| Two snare-capable companions in the same group. | Each Companion has its own `m_snare_resist_counts` map. PRD edge-case #6 satisfied. |
| Companion dies and is rezzed mid-fight. | On death the Companion enters suspended state; the map persists in memory until the entity is destroyed or the engagement-end edge fires. After rez, `m_was_engaged` may not reflect the gap correctly. **Risk noted.** Mitigation: clear counters in `Companion::Death` and on `Unsuspend`. Add to task 4 implementation — `ClearSnareResistCounters()` calls in those two methods as defense-in-depth. |
| Companion swap mid-fight (player dismisses one, recruits another). | New Companion entity = fresh map. PRD edge-case #8 satisfied. |
| Multi-mob fight, snare on Mob A resists, target switches to Mob B. | `m_last_snare_target_id` differs from Mob B's ID; map clears at top of `AI_AttemptSnare`. Mob B counter fresh. PRD edge-case "multi-mob isolation" satisfied. **CAVEAT:** because target-change clears the WHOLE map (not just removes Mob A's entry), if the companion later switches back to Mob A, Mob A's counter is also fresh. This is a relaxed interpretation of PRD AC-5. PRD AC-5 says "Druid caps out on Mob A. Mob B reaches flee threshold. Druid casts on Mob B." It doesn't specify what happens when Druid switches back to Mob A. The relaxed interpretation is more forgiving; conservative would be to keep per-target counts indefinitely until engagement-end. **Architect choice: relaxed semantics — wipe-on-switch.** Rationale: target-changes in companion combat are rare and almost always reflect a meaningful "this is a new fight from the AI's perspective." Documented as a known semantic; game-tester verifies AC-5 works with the relaxed semantics (it does — Mob B's counter is fresh as required). |
| Mob de-aggros and resets, then is re-pulled later. | `m_was_engaged && !currently_engaged` fires when the companion drops off the hate list (no targets). Counter clears. New pull = fresh counter. PRD edge-case #9 satisfied. |
| Player explicitly commands the companion to snare a >20% HP target. | **Cannot occur in current scope.** No `!snare` command exists. AC-8 is N/A. |
| Race condition: spell cast START fires, mob dies before resolution, target is gone when SpellOnTarget runs. | `Mob::SpellOnTarget` already handles missing target (`spelltar` is the resolved target object; if dead, the existing resist branch never fires because the spell never resolves). Hook is safe. |
| Mob is healed above 20% HP while snared. | `flee_mode` clears (StopFleeing). Existing snare buff continues until duration end. Gate locks against re-snare. Correct. |
| Rule `SnareHpThreshold` set to 100 (operator wants the gate effectively disabled). | Gate condition `target_hpr > 100` is always false. Snare fires whenever target IsFleeing(). Resist counter still applies. Effectively reverts to "snare only fleeing targets" — looser than PRD default but tighter than current behavior. Reasonable. |
| Rule `SnareResistLimit` set to 0 (operator wants resist cap disabled). | Code branch: `if (resist_limit > 0)` skips the cap check. Companion attempts snare every tick the gate passes. Reasonable. |
| Companion's `m_companion_spells` is empty (data missing). Falls back to `NPC::AI_EngagedCastCheck` -> `mob_ai.cpp:321` snare branch. | Gate does NOT apply (we did not modify mob_ai.cpp). This is the pre-feature behavior. **In production, all companions should have spell sets** — data-expert verifies. If a class somehow doesn't, snare spam will return for that class only. Game-tester runs an audit query confirming every companion class has at least 1 spell set entry per level band. |

**Player-exploit vectors.**
- Could a player abuse the rule to manipulate enemy AI? No — the
  gate is purely on the companion's autonomous AI. The TARGET
  mob's behavior is unchanged.
- Could a player force the rule by manipulating their own
  companion's state? No — the rule reads `IsEngaged()`,
  `GetHPRatio()`, `IsFleeing()` from the target NPC. Player
  cannot directly toggle these on the target.
- Could the resist counter be drained (e.g., by repeatedly
  triggering target-change to wipe it)? Yes — but to do this the
  player must direct the companion to switch targets, which
  costs a positioning/AI cycle and means the companion isn't
  attacking the previous target anyway. Net effect: no exploit
  worth defending against.

### Pass 4: Integration

**How do the pieces fit together?**

The work flows through the implementation team in order:

1. **config-expert** lands the rule definition + seed SQL first.
   This is required before c-expert can compile code that uses
   `RuleI(Companions, SnareHpThreshold)`.
2. **data-expert** runs in parallel — verifying spell-set rows
   exist. May insert missing rows. Does not block c-expert
   directly but DOES block game-tester (without data, AC-6 fails
   for DRU/NEC/SHM).
3. **c-expert** lands the C++ work in one logical commit:
   ruletypes inclusion verified, helper + members in companion.h
   / companion_ai.cpp / companion.cpp / spells.cpp. Commit is
   self-contained — all five classes (DRU/RNG/NEC/SHM/BRD) work
   after this single commit.
4. **c-expert** builds and runs unit tests.
5. **Validation hand-off** to game-tester.

**Ordering hazards to flag for the implementation team:**

- Don't rebuild or rerun until config-expert's `INSERT INTO
  rule_values` has been applied to the running DB — `RuleI`
  returns 0 for an undefined rule, which means the gate
  evaluates as "target_hpr > 0" (always true except for already-
  dead targets) and the gate effectively SUPPRESSES ALL SNARE.
  Check `SELECT * FROM rule_values WHERE rule_name LIKE
  'Companions:Snare%'` returns 2 rows before testing.
- The `IsCompanion()` virtual dispatch from `Mob::SpellOnTarget`
  must include `companion.h` if not already pulled in. Check the
  existing `spells.cpp` includes — `IsCompanion()` is on Entity
  base so `entity.h` (already included) is enough; the
  `CastToCompanion()` call includes `companion.h`. Add the
  include if missing.
- The `m_was_engaged` site already exists. The new
  `ClearSnareResistCounters()` line goes INSIDE the existing
  `if (m_was_engaged && !currently_engaged)` block — same
  scope, same edge.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| config-expert | 1, 12 | Owns `common/ruletypes.h` (task 1) and the `rule_values` SQL seed (task 12). The two tasks are split across the rebuild boundary because `#reloadrules` only finds compile-time-defined rules. |
| data-expert | 2 | Owns `companion_spell_sets` content. Verification + small INSERTs only. Runs in parallel with task 1. |
| c-expert | 3, 4, 5, 6, 7, 8, 9, 10, 11 | Owns all C++ work in `eqemu/zone/` plus the rebuild/restart integration step. |

protocol-agent has no implementation work for this feature.

lua-expert, perl-expert, infra-expert have no work for this feature.

## Validation Plan

Game-tester verifies each PRD acceptance criterion in-game. The
gate's invisible nature (silent suppression) means most ACs are
verified by **not seeing** snare casts. Server logs (`LogAIDetail`)
help confirm the gate is actually firing rather than the spell
just being absent.

- [ ] **AC-1 (no snare during normal combat).** Pull a non-trivial
      mob with a Druid companion. Verify in chat / spell log that
      Druid does NOT cast Ensnare while target HP > 20%. Run for
      at least 60 seconds across 3 separate engagements.
- [ ] **AC-2 (snare fires at flee threshold).** Engage a mob to
      ~20% HP. Mob enters flee. Druid casts Ensnare within 2-3 AI
      ticks. Verify cast appears in chat / spell log.
- [ ] **AC-3 (two-resist cutoff).** Engage a high-MR mob (e.g.,
      Hill Giant). At flee+20% HP, observe Druid casts Ensnare —
      first cast resists. Druid casts again — second cast resists.
      Druid does NOT cast Ensnare a third time on that mob even
      though it's still at <=20% HP and fleeing.
- [ ] **AC-4 (counter resets on new target).** During a chain
      pull, Druid 2-resists Mob A, Mob A dies. Pull Mob B.
      At Mob B flee, Druid casts Ensnare on Mob B (counter is
      fresh). If Mob B resists once, Druid attempts a second
      time. If second resists, no third attempt.
- [ ] **AC-5 (multi-mob isolation).** In a 2-mob fight, Druid
      caps on Mob A. Mob B reaches flee threshold. Druid casts
      Ensnare on Mob B (Mob B counter is fresh). [Note: with the
      relaxed wipe-on-target-change semantics, Mob A's counter
      ALSO clears when Druid switches to Mob B. PRD AC-5 is
      satisfied; the relaxation is in the architect's favor.]
- [ ] **AC-6 (all four classes obey the rule).** Repeat AC-1
      and AC-2 with a Ranger, Necromancer, and Shaman companion.
      Each must:
      - NOT cast snare while target > 20% HP / not fleeing
      - Cast snare when target <= 20% HP AND fleeing
      - Cap at 2 resists per target
- [ ] **AC-7 (out-of-combat snare unaffected).** Verify a Ranger
      companion will cast snare on a target during pull setup
      (companion not yet engaged) when conditions are otherwise
      ineligible. **Implementation note:** the gate only applies
      `IsEngaged() == true`. Out-of-combat path falls through
      without checking HP/flee. game-tester should confirm by
      observing snare casts during pull positioning.
- [ ] **AC-8 (manual command override).** **N/A — no manual
      snare command exists in current scope.** Architect resolved
      open question #1: there is no companion command path that
      directly invokes a snare cast. The PRD's "manual override"
      is a forward-looking concern to be addressed if/when a
      `!snare` command is added in a future feature. Game-tester
      records this as N/A with the architectural reason.
- [ ] **AC-9 (root spells unaffected).** Necromancer (or Druid)
      root behavior is identical pre vs post change. The Druid
      `AI_Druid` Root branch is unmodified.
- [ ] **AC-10 (player snare unaffected).** A player Druid casts
      Ensnare on any target — works exactly as before. The hook
      is on `IsCompanion()` only; player Clients are skipped.
- [ ] **AC-11 (tunables work).** Set
      `Companions:SnareHpThreshold` to 30 via `#rule_set` —
      gate now opens at 30% HP. Set `Companions:SnareResistLimit`
      to 1 — companion stops at 1 resist. Set
      `SnareResistLimit` to 0 — no cap, companion will attempt
      snare every eligible tick.
- [ ] **AC-12 (mana savings observable).** Compare a Druid
      companion's end-of-fight mana % across 5 fights pre vs
      post change. Post-change should be visibly higher.
      Sanity check, not pass/fail.

**Sustained-play test scenarios** (per architect discipline on
customized systems — see `feedback_refactor_regression_discipline.md`):

- [ ] **Long engagement (5+ minutes).** Verify that
      `m_snare_resist_counts` does not leak. Companion's memory
      footprint stable. Counters clear cleanly on
      engagement-end.
- [ ] **Chain pull (10+ targets).** Verify counter resets on
      each new pull. No state from previous fights bleeds into
      new ones.
- [ ] **Companion death + rez during the same fight.** Verify
      the rez flow does not double-fire the engagement-end
      transition in a way that prematurely clears counters,
      causing repeated cap-resets. Test specifically: pull,
      Druid resists 2x, Druid dies, gets rezzed, fight
      continues, target still at 20%+ — Druid does NOT
      attempt snare again on that target.
- [ ] **Companion zone-in mid-engagement.** Verify
      `m_snare_resist_counts` initializes to empty on Spawn /
      Unsuspend. Counter map should be a fresh `{}` after
      zone load.
- [ ] **All four named classes (DRU/RNG/NEC/SHM) verify they
      can actually cast snare-line spells in the right
      conditions.** This implicitly verifies the data-expert's
      audit task (task 3) was complete.

---

> **Next step:** Spawn the implementation team with exactly
> three agents:
> - **c-expert** (tasks 3-11)
> - **config-expert** (tasks 1, 12)
> - **data-expert** (task 2)
>
> Tasks 1 and 2 can run in parallel. Tasks 3-10 are sequential
> after task 1. Task 11 (rebuild + restart) gates task 12
> (rule_values seed via INSERT + `#reloadrules`). After task 12,
> hand off to game-tester.
