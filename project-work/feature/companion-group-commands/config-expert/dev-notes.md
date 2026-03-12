# Companion Group Commands — Dev Notes: Config Expert

> **Feature branch:** `feature/companion-group-commands`
> **Agent:** config-expert
> **Task(s):** Task #2 — Review for config/rule system needs
> **Date started:** 2026-03-11
> **Current stage:** Research (preliminary — architecture not yet available)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Review for config/rule system needs | Task #1 (architect) | Pending — blocked by Task #1 |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/common/ruletypes.h` | 1181–1242 | Full Companions category: 36 existing rules |
| `claude/docs/topography/C-CODE.md` | 441–556 | Rule system architecture, macro patterns |
| `claude/docs/topography/SQL-CODE.md` | Rule System section | rule_sets/rule_values table schema |
| `claude/docs/companion-commands-reference.md` | All | Existing command set, implementation files |
| `claude/project-work/feature/companion-group-commands/game-designer/prd.md` | All | Full PRD for 10 new/updated commands |

### Key Findings

**Existing Companions category rules (ruletypes.h lines 1181–1242):**

36 rules already exist in the `Companions` category covering:
- Master toggle (`CompanionsEnabled`)
- Recruitment (`MaxPerPlayer`, `LevelRange`, `BaseRecruitChance`, `MinFaction`, `RecruitCooldownS`)
- Scaling (`StatScalePct`, `SpellScalePct`)
- Death/retention (`DeathDespawnS`, `DismissedRetentionDays`)
- XP (`XPContribute`, `XPSharePct`)
- Regen (`HPRegenPerTic`, `CompanionManaRegenMult`, `OOCRegenPct`, `SittingRegenMult`)
- Behavior (`CompanionSelfPreservePct`, `MercSelfPreservePct`, `RecallCooldownS`)
- Group chat (`GroupChatAddressingEnabled`, `GroupChatResponseStaggerMinMS`, `GroupChatResponseStaggerMaxMS`)
- Equipment (`EnforceClassRestrictions`, `EnforceRaceRestrictions`, `EquipmentPersistsThroughDeath`)
- AI/combat (`AggressiveScanRadius`, `CompanionFleeEnabled`, `FormationDistance`, `CasterCombatRange`, `RogueBehindMob`, `UseWeaponDamage`)
- Stat scaling (`STAToHPFactor`, `HealThresholdPct`, `ManaCutoffPct`, `HealerManaConservePct`, `ResistCapBase`, `MaxLevelOffset`, `ReRecruitBonus`, `ReplacementSpawnDelayS`, `MercRetentionCheckS`)

**Relevant existing rules for this feature:**
- `RecallCooldownS` (30s) — already governs recall-type mechanics; `!tome` is movement, not recall, so may not apply
- `GroupChatAddressingEnabled` — the foundation `@name`/`@all` system this feature depends on
- `FormationDistance` (15 units) — used for follow mode; `!follow` and `!flee` rely on this
- `ManaCutoffPct` (20) — existing mana floor for DPS casters; related but different from buff mana check
- `HealerManaConservePct` (30) — existing mana conservation threshold for healers

**PRD-specified hardcoded thresholds that could become rules:**

1. `!buffme`/`!buffs` — PRD says: "If the companion is out of mana (below 10% threshold)" — this 10% is specified as a fixed value in the PRD, not currently a rule
2. `!tome` — PRD says: "Companion is already at the player's location (within 50 units): No movement needed" — this 50-unit radius is specified as a fixed value in the PRD

**PRD commands with NO tunable behavior (no rules needed):**
- `!status` — pure read, no configurable behavior
- `!flee` — chains existing stance + movement + follow; no new tunables
- `!assist` — uses existing stance system; no new tunables
- `!equipmentupgrade` — pure item stat comparison; evaluation formula is intentionally fixed (AC + stats + HP + Mana)
- `!equipmentmissing` — pure slot enumeration; no tunables
- `!help` — static text display; no tunables
- `!follow` — existing command routed via group chat; no new tunables

### Implementation Plan

**Recommendation: 2 new rules to add to `eqemu/common/ruletypes.h` Companions category**

Both values are explicitly called out as specific numbers in the PRD but have no corresponding rule. Making them rules allows server operators to tune without recompilation.

**Rule 1: `BuffRequestManaMinPct`**
- Type: `RULE_INT`
- Default: `10`
- Description: `"Minimum mana percentage required for a companion to honor a !buffme or !buffs request (below this, companion responds with too-low-on-mana message)"`
- Category: `Companions`
- Rationale: PRD hardcodes 10% but this is a tunable threshold. Analogous to `ManaCutoffPct` (DPS casters) and `HealerManaConservePct` (healers) — a consistent pattern in the existing rules.

**Rule 2: `TomeNearbyRadiusUnits`**
- Type: `RULE_INT`
- Default: `50`
- Description: `"Distance in game units within which a companion is considered 'already nearby' and skips movement when !tome is issued"`
- Category: `Companions`
- Rationale: PRD specifies 50 units as the "already nearby" threshold. Same pattern as `AggressiveScanRadius` (75 units) and `FormationDistance` (15 units) — distance thresholds are consistently exposed as rules.

**No eqemu_config.json changes needed.** All behavior is within the game server's rule system. No new database schema changes needed from the config-expert side.

**Implementation (Stage 4) will add these two lines to `ruletypes.h` after line 1242:**
```
RULE_INT(Companions, BuffRequestManaMinPct, 10, "Minimum mana percentage required for a companion to honor a !buffme or !buffs request (below this, companion responds with too-low-on-mana message)")
RULE_INT(Companions, TomeNearbyRadiusUnits, 50, "Distance in game units within which a companion is considered 'already nearby' and skips movement when !tome is issued")
```

**`rule_values` inserts (data-expert task):**
```sql
INSERT INTO rule_values (rule_set_id, rule_name, rule_value)
SELECT rule_set_id, 'Companions:BuffRequestManaMinPct', '10' FROM rule_sets WHERE rule_set_name = 'default';

INSERT INTO rule_values (rule_set_id, rule_name, rule_value)
SELECT rule_set_id, 'Companions:TomeNearbyRadiusUnits', '50' FROM rule_sets WHERE rule_set_name = 'default';
```

**What to test:**
- `!buffme` on a companion with exactly 10% mana triggers "too low on mana" message
- `!buffme` on a companion with 11% mana queues successfully
- `!tome` with companion 49 units away moves companion
- `!tome` with companion 51 units away responds "already nearby"
- Rules update correctly via `#reloadrules` in-game

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `RULE_INT` macro pattern | `eqemu/common/ruletypes.h` lines 1181–1242 (Companions category) | Yes | Pattern confirmed: `RULE_INT(Category, Name, Default, "Description")` |
| `rule_values` table schema | SQL-CODE.md Rule System section | Yes | `rule_set_id`, `rule_name` (format: `Category:Name`), `rule_value` (string) |
| Existing Companions category | `ruletypes.h` lines 1181–1242 | Yes | 36 rules confirmed; no `BuffRequestManaMinPct` or `TomeNearbyRadiusUnits` exists |
| `RuleI()` macro access pattern | C-CODE.md section 4.3 | Yes | `RuleI(Companions, BuffRequestManaMinPct)` — c-expert uses this in C++ |

### Plan Amendments

Plan confirmed — no amendments needed. Both proposed rules follow established patterns in the Companions category. The `rule_values` insert uses the correct `Category:Name` format confirmed from SQL-CODE.md.

### Verified Plan

See Implementation Plan above — confirmed by research.

**Note:** This research was completed before the architecture doc was finalized (Task #1 still in_progress). If the architect identifies additional tunable values in their implementation plan, this dev-notes must be updated before Stage 4.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Rule landscape review (pre-architecture) | Do existing rules cover feature needs? What new rules are needed? Rule interactions? |
| architect | Pre-architecture rule answers | Confirmed HealerManaConservePct separate from !buffme check; recommended 2 new rules |
| team-lead | Preliminary findings | 2 new rules recommended pending architecture |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| architect | Architecture complete. Overriding 2 rule recommendations — thresholds are game design constants, not tunables. Pure Lua implementation, zero C++ or DB changes. Config-expert findings on GroupChatAddressingEnabled and CompanionFleeEnabled incorporated. | Acknowledged. Reviewed architecture.md. Rationale is sound — see Consensus Plan. |

### Consensus Plan

**Agreed approach: NO new rules. NO eqemu_config.json changes. Zero config-expert deliverables for this feature.**

The architect's rationale is correct: the 10% mana floor for `!buffme` and the 50-unit proximity threshold for `!tome` are game design constants fixed by the PRD, not values server operators would tune independently. The correct pattern for rules is server-configurable behavior (e.g., `MaxPerPlayer`, `AggressiveScanRadius`); these thresholds are design invariants.

The implementation is entirely in Lua. No C++ changes means no ruletypes.h changes. No database changes means no rule_values inserts.

**Files to create or modify:** None.

**Config-expert deliverables:** None beyond this analysis.

The findings that WERE incorporated into the architecture:
- `GroupChatAddressingEnabled` documented as hard dependency for @name/@all path
- `CompanionFleeEnabled` confirmed as non-interacting with !flee command
- `HealerManaConservePct` confirmed as separate from !buffme mana check (AI spell selection vs. player request gate)

---

## Stage 4: Build

**Nothing to build.** This feature requires zero config or rule changes.

The config-expert role for this feature was advisory: landscape analysis, rule interaction review, and confirming that the architect's pure-Lua approach correctly avoids unnecessary C++ or database changes.

---

## Open Items

_None — task complete._

---

## Context for Next Agent

This agent reviewed the companion group commands feature (10 commands) for config/rule system needs.

**Final verdict: No config changes needed for this feature.**

Key findings preserved for reference:
- `HealerManaConservePct` (30%) governs healer AI spell selection — NOT the !buffme OOM check
- `GroupChatAddressingEnabled` is the master toggle for @name/@all — hard dependency, must be true
- `CompanionFleeEnabled` controls NPC self-preservation flee — does NOT interact with !flee command
- The 10% mana floor and 50-unit proximity threshold are hardcoded in Lua per architect decision (game design constants, not tunables)
- Full rule landscape: 36 existing rules in Companions category, ruletypes.h lines 1181–1242
