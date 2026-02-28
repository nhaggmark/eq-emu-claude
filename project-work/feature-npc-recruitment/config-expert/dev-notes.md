# NPC Recruitment / Recruit-Any-NPC Companion System — Dev Notes: Config Expert

> **Feature branch:** `feature/npc-recruitment`
> **Agent:** config-expert
> **Task(s):** Task #3 — Rule system and configuration planning (Architecture phase)
> **Date started:** 2026-02-25
> **Current stage:** Stage 1: Plan (Architecture advisory, no code changes yet)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Plan rule system and configuration for NPC recruitment | PRD complete (Task #1, #2) | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/common/ruletypes.h` | 1186 | All 47 rule categories; confirmed no existing Companions category |
| `claude/docs/topography/C-CODE.md` | Section 3.10 / 4.3 / 6 | Rule system details: RULE_CATEGORY, RULE_INT/BOOL/REAL/STRING macros, 47 categories |
| `claude/docs/topography/SQL-CODE.md` | Section 19 | rule_sets and rule_values tables; rule_name format "Category:RuleName" |
| `claude/project-work/feature-npc-recruitment/game-designer/prd.md` | Full | PRD balance levers, recruitment roll, persuasion formula, disposition modifiers, exclusion list |
| `akk-stack/server/eqemu_config.json` | Full | No companion-related config currently; standard world/zone/DB config |
| DB: `rule_values WHERE rule_name LIKE 'Mercs:%'` | 14 rows | Existing Mercs rules: AllowMercs=false, ScaleRate=100, AggroRadius=100, ResurrectRadius=50, SuspendIntervalMS=10000 |
| DB: `rule_values WHERE rule_name LIKE 'Bots:%'` | Many | Extensive bot rules; confirmed no Companion/recruitment rules exist |

### Key Findings

**No existing Companions category.** There are zero rules in `ruletypes.h` under a Companions category. The new feature requires its own category to be added to `common/ruletypes.h` by c-expert.

**Mercs rules we can reference/mirror (not reuse directly):**
- `Mercs:ScaleRate` (int, 100) — pattern for our `Companions:StatScalePct`
- `Mercs:AggroRadius` (int, 100) — pattern for aggro tuning
- `Mercs:AllowMercs` (bool, false) — pattern for master enable toggle
- `Mercs:SuspendIntervalMS` (int, 10000) — pattern for suspend timing

**Rule macro syntax confirmed** (from ruletypes.h source):
```cpp
RULE_CATEGORY(Companions)
RULE_BOOL(Companions, Enabled, true, "Enable NPC recruitment system")
RULE_INT(Companions, LevelRange, 2, "...")
RULE_CATEGORY_END()
```
These are accessed in C++ via `RuleB(Companions, Enabled)`, `RuleI(Companions, LevelRange)`, etc.

**eqemu_config.json does NOT need changes.** The recruitment system is pure game logic controlled via rules and Lua scripts. No server-level config entries are required. LLM sidecar config (if any) would live in a separate config file managed by lua-expert/infra-expert.

**Faction constants confirmed** (`common/faction.h`):
- FACTION_DUBIOUS = 2, FACTION_APPREHENSIVE = 1 (hostile zone)
- FACTION_KINDLY = 3 (minimum for recruitment)
- FACTION_WARMLY = 4, FACTION_ALLY = 5

### Proposed Rule Structure

**Category name: `Companions`** (consistent with EQEmu naming conventions; "Recruitment" is too narrow since rules cover ongoing behavior too)

#### Core Toggle and Limits

| Rule Name | Type | Default | Notes |
|-----------|------|---------|-------|
| `Companions:Enabled` | BOOL | true | Master enable/disable toggle. false = no recruitment |
| `Companions:MaxPerPlayer` | INT | 5 | Hard cap on recruits per player (group-size formula still applies) |
| `Companions:MaxGroupSlots` | INT | 6 | Group size cap; max_recruits = this - current_group_size |

#### Recruitment Eligibility

| Rule Name | Type | Default | Notes |
|-----------|------|---------|-------|
| `Companions:LevelRange` | INT | 2 | NPC must be within ±LevelRange of player level |
| `Companions:MinFaction` | INT | 3 | Minimum faction value for recruitment attempt (3 = Kindly) |
| `Companions:RecruitCooldownS` | INT | 900 | Cooldown in seconds after a failed recruitment attempt (15 min) |
| `Companions:AllowRecruitInCombat` | BOOL | false | If false, block recruitment while player or NPC is in combat |

#### Recruitment Roll Modifiers

| Rule Name | Type | Default | Notes |
|-----------|------|---------|-------|
| `Companions:BaseRecruitChance` | INT | 50 | Base recruitment success chance (%) before modifiers |
| `Companions:MinRecruitChance` | INT | 5 | Minimum clamped chance (%) regardless of negatives |
| `Companions:MaxRecruitChance` | INT | 95 | Maximum clamped chance (%) regardless of bonuses |
| `Companions:FactionAllyBonus` | INT | 30 | Bonus (%) for Ally faction |
| `Companions:FactionWarmlyBonus` | INT | 20 | Bonus (%) for Warmly faction |
| `Companions:FactionKindlyBonus` | INT | 10 | Bonus (%) for Kindly faction (minimum eligible) |
| `Companions:DispositionEagerBonus` | INT | 25 | Bonus (%) for Eager NPC disposition |
| `Companions:DispositionRestlessBonus` | INT | 15 | Bonus (%) for Restless NPC disposition |
| `Companions:DispositionCuriousBonus` | INT | 5 | Bonus (%) for Curious NPC disposition |
| `Companions:DispositionContentPenalty` | INT | 10 | Penalty (%) for Content NPC disposition (stored positive, applied negative) |
| `Companions:DispositionRootedPenalty` | INT | 30 | Penalty (%) for Rooted NPC disposition |
| `Companions:LevelDiffModifier` | INT | 5 | Per-level bonus/penalty (%) for level difference |
| `Companions:PreviousRecruitBonus` | INT | 10 | Bonus (%) if NPC was previously recruited by this player |

#### Balance Tuning

| Rule Name | Type | Default | Notes |
|-----------|------|---------|-------|
| `Companions:StatScalePct` | INT | 100 | Global stat scale factor for recruits (100 = full NPC stats) |
| `Companions:SpellScalePct` | INT | 100 | Heal/damage scale factor for recruit spells |
| `Companions:HealThresholdPct` | INT | 70 | HP percentage at which healer recruits begin healing group members |
| `Companions:AggroRadius` | INT | 100 | Distance from which a recruit will engage group member's target |
| `Companions:ResurrectRadius` | INT | 50 | Distance from which healer recruits attempt to resurrect |

#### Recruit Lifecycle

| Rule Name | Type | Default | Notes |
|-----------|------|---------|-------|
| `Companions:DeathDespawnS` | INT | 1800 | Seconds before unresurrected recruit returns to spawn (30 min) |
| `Companions:ReplacementSpawnDelayS` | INT | 45 | Delay in seconds before replacement NPC spawns at original location |
| `Companions:SuspendIntervalMS` | INT | 10000 | Time interval for recruit suspend operation (mirrors Mercs pattern) |
| `Companions:XPContribute` | BOOL | true | If true, recruits contribute to group XP split as full members |

#### Mercenary Retention

| Rule Name | Type | Default | Notes |
|-----------|------|---------|-------|
| `Companions:MercRetentionWarningS` | INT | 30 | Seconds after faction drops below Warmly before departure warning |
| `Companions:MercRetentionDepartureS` | INT | 600 | Seconds after warning before auto-dismiss (10 min) |

#### Hard Cap (Override)

| Rule Name | Type | Default | Notes |
|-----------|------|---------|-------|
| `Companions:HardCapEnabled` | BOOL | false | If true, use HardCap instead of group-size formula |
| `Companions:HardCap` | INT | 3 | Hard cap on recruits when HardCapEnabled=true |

### Total: 28 proposed rules

### eqemu_config.json Assessment

**No changes required.** Reviewing the current config:
- DB connection, zone ports, UCS, world address — all unaffected
- LLM sidecar config (if any) lives outside eqemu_config.json (it's a separate service)
- The recruitment system is server-side game logic, not a server binary configuration concern

### Implementation Plan (for c-expert coordination)

The c-expert must add `RULE_CATEGORY(Companions)` to `eqemu/common/ruletypes.h` with all 28 rules above. Once c-expert confirms the rule names in `ruletypes.h`, I (config-expert) will:

1. Run `INSERT INTO rule_values` statements to populate the database
2. Verify the `#reloadrules` command picks them up correctly
3. Set initial tuned values based on the PRD defaults

**NOTE:** Rules added to `ruletypes.h` are NOT automatically in `rule_values`. They must be explicitly inserted. The server will use the compiled default if a row is missing, but for our custom server it's better to have explicit rows with notes.

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| Rule macro syntax (RULE_CATEGORY, RULE_INT, etc.) | `eqemu/common/ruletypes.h` source | Yes | Confirmed X-macro pattern |
| Rule access pattern (RuleI/RuleB/RuleR) | C-CODE.md section 4.3 | Yes | `RuleI(Category, Name)` |
| rule_values table schema | SQL-CODE.md section 19 | Yes | ruleset_id, rule_name, rule_value, notes |
| Faction constants (FACTION_KINDLY=3) | `common/faction.h` (via C-CODE.md) | Yes | FACTION_KINDLY=3 confirmed |
| Mercs:ScaleRate pattern | `rule_values` DB query | Yes | ScaleRate=100 (int), same pattern for StatScalePct |
| eqemu_config.json schema | Config file direct read | Yes | No companion-relevant sections exist |

### Plan Amendments

Plan confirmed — no amendments needed. The faction constant FACTION_KINDLY=3 matches the PRD's MinFaction=3 default. The Mercs:ScaleRate=100 pattern is a clean model for Companions:StatScalePct=100.

One addition: Added `Companions:HealThresholdPct` (INT, 70) after reviewing the PRD's healer AI description, which needs a configurable HP threshold for triggering heals. This wasn't in the PRD's rule suggestion list but is clearly needed for balance tuning.

---

## Stage 3: Socialize

_Pending — message sent to architect with full findings._

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Proposed Companions rule category (28 rules) | Confirm naming convention and any additions/removals before I socialize with c-expert |

---

## Open Items

- [ ] Await architect review of proposed rule list
- [ ] Coordinate with c-expert on ruletypes.h additions (they write the C++, I write the DB inserts)
- [ ] After architecture plan finalizes, write Stage 4 (DB INSERT statements for rule_values)

---

## Context for Next Agent

**Architecture Phase Summary:** The config-expert role in this phase is advisory. No config changes are made until Stage 4 (Build).

**Core finding:** Zero existing rules can be reused for the companion system. A new `Companions` category must be added to `ruletypes.h` (c-expert task) and populated in `rule_values` (config-expert task). 28 rules proposed covering: core toggle, eligibility, recruitment roll modifiers, balance tuning, lifecycle, and mercenary retention.

**eqemu_config.json:** No changes needed.

**Key constraint:** The Titanium client has no merc UI opcodes, so all interaction is via say commands — this is a Lua/protocol concern, not a config concern.

See Consensus Plan (Stage 3) when it's filled in for the final agreed rule list to implement.
