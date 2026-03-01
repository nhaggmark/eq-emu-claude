# Recruited NPC Controls — Dev Notes: Config Expert

> **Feature branch:** `feature/recruited-npc-controls`
> **Agent:** config-expert
> **Task(s):** #2 — Review rules and configuration needs for command prefix system
> **Date started:** 2026-02-28
> **Current stage:** Socialize

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Review rules and configuration needs for command prefix system | — | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/common/ruletypes.h` | 1181–1202 | All 20 existing Companions rules — full inventory below |
| `claude/project-work/feature/recruited-npc-controls/game-designer/prd.md` | 1–494 | PRD: `!` prefix system, 14 commands, 3 PRD-suggested rules |
| `claude/docs/topography/C-CODE.md` | Rule System section | Rule macro syntax and access patterns confirmed |
| `claude/docs/topography/SQL-CODE.md` | Rule System section | `rule_values` table structure confirmed |
| DB: `rule_values` WHERE `rule_name LIKE 'Companions:%'` | — | 20 rows confirmed live in DB, matching ruletypes.h |

### Key Findings

**Existing Companions rules (all 20, current DB values):**

| Rule Name | Type | DB Value | Default in ruletypes.h | Purpose |
|-----------|------|----------|------------------------|---------|
| Companions:CompanionsEnabled | bool | true | true | Master toggle |
| Companions:MaxPerPlayer | int | 5 | 5 | Max active companions |
| Companions:LevelRange | int | 3 | 3 | Recruit eligibility range |
| Companions:BaseRecruitChance | int | 100 | 50 | Base recruit % (customized) |
| Companions:StatScalePct | int | 100 | 100 | Stat multiplier |
| Companions:SpellScalePct | int | 100 | 100 | Spell scaling |
| Companions:RecruitCooldownS | int | 900 | 900 | Failed recruit cooldown (s) |
| Companions:DeathDespawnS | int | 1800 | 1800 | Auto-dismiss after death (s) |
| Companions:MinFaction | int | 3 | 3 | Min faction to recruit |
| Companions:XPContribute | bool | true | true | XP split participation |
| Companions:MercRetentionCheckS | int | 600 | 600 | Merc retention check interval |
| Companions:ReplacementSpawnDelayS | int | 30 | 30 | Replacement spawn delay (s) |
| Companions:XPSharePct | int | 50 | 50 | XP share % to companion |
| Companions:MaxLevelOffset | int | 1 | 1 | Companion max level = player - N |
| Companions:ReRecruitBonus | real | 0.10 | 0.10 | Voluntary dismiss re-recruit bonus |
| Companions:DismissedRetentionDays | int | 30 | 30 | DB retention after dismiss (days) |
| Companions:CompanionSelfPreservePct | real | 0.20 | 0.20 | Self-preservation HP threshold |
| Companions:MercSelfPreservePct | real | 0.10 | 0.10 | Merc self-preservation threshold |
| Companions:HPRegenPerTic | int | 1 | 1 | Min HP regen per tic |
| Companions:OOCRegenPct | int | 5 | 5 | OOC HP regen % per tic |

**None of the 20 existing rules are affected by command prefix changes.** They cover recruitment, scaling, retention, and combat behavior — none touch command routing or input parsing.

**PRD-suggested rules (advisory):**
The PRD's technical appendix suggests three new rules:
1. `Companions:CommandPrefix` (string, default "!") — configurable prefix character
2. `Companions:RecallCooldownS` (int, default 30) — recall cooldown in seconds
3. `Companions:RecallMinDistance` (float, default 200) — min distance for recall

### Implementation Plan

**Question 1: Should the `!` prefix be configurable via a rule, or hardcoded in Lua?**

Recommendation: **hardcode in Lua, do not create a rule.**

Rationale:
- The `!` character was deliberately chosen after multi-agent review (c-expert, lore-master, game-designer). It was selected because it is: not reserved by any C++ system, not used by `#` (GM commands) or `^` (bot commands), ergonomic, and lore-acceptable. Decision is in status.md Decision Log #5.
- A string rule (`RULE_STR`) would require a C++ recompile to add. The EQEmu rule system does not support `RULE_STR` in the standard RuleS macro without additional plumbing — the rule categories use `RULE_INT`, `RULE_REAL`, `RULE_BOOL`, and `RULE_STR` but string rules are rare and less commonly used.
- Changing the prefix character would break player muscle memory and any documentation. There is no operator use case for changing it on this private server.
- Hardcoding in Lua (e.g., `local COMMAND_PREFIX = "!"` at the top of `companion.lua`) achieves the same configurability with a simple file edit, which is fine for a private single-server deployment.
- **Decision: hardcode as a Lua local constant, no rule needed.**

**Question 2: Is a RecallCooldownS rule needed for `!recall`?**

Recommendation: **yes, create `Companions:RecallCooldownS` (int, default 30).**

Rationale:
- The `!recall` command is a quality-of-life fix, not a power feature. The PRD specifically asks whether a cooldown is appropriate (Open Question #2).
- A 30-second cooldown is reasonable to prevent spam positioning in combat. This is a gameplay tuning parameter that a server operator might want to adjust.
- This IS a candidate for a rule because: it's a time-based tuning parameter, it has a sensible default, it's the kind of value that might need server-specific adjustment, and it parallels existing rules like `RecruitCooldownS` and `DeathDespawnS`.
- Implementation: the cooldown is enforced in Lua via a data bucket (TTL-based, as the PRD suggests). The Lua script reads `RuleI(Companions, RecallCooldownS)` to get the TTL duration. This requires a new entry in `ruletypes.h` (c-expert task) and a matching `rule_values` INSERT (config-expert or data-expert task).

**Question 3: Is a RecallMinDistance rule needed?**

Recommendation: **no, hardcode 200 units in Lua.**

Rationale:
- The 200-unit minimum is a gameplay design constraint, not a tuning parameter. Its purpose is to prevent `!recall` from being used as a combat positioning tool. Changing it would affect game balance, not just operation.
- Unlike cooldown (which varies by server preferences), the distance threshold is tied to the game design intent. Hardcode at 200 and document in code comments.

**Question 4: Any eqemu_config.json changes needed?**

No. This feature is entirely Lua-layer. The `eqemu_config.json` controls DB connections, zone ports, logging, and world settings — none of which are relevant to companion command prefix routing. No config file changes required.

**Summary of rule changes:**
- **Create:** `Companions:RecallCooldownS` (int, default 30) — recall teleport cooldown in seconds
- **No change:** all 20 existing Companions rules are unaffected
- **Do not create:** `Companions:CommandPrefix` (hardcode in Lua instead)
- **Do not create:** `Companions:RecallMinDistance` (hardcode 200 in Lua instead)

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | Modify | Add `RULE_INT(Companions, RecallCooldownS, 30, ...)` — c-expert task |
| DB: `rule_values` | INSERT | Add `Companions:RecallCooldownS` row — config-expert task (after c-expert adds to ruletypes.h) |

**Change sequence:**
1. c-expert adds `RULE_INT(Companions, RecallCooldownS, 30, "...")` to `ruletypes.h` after existing Companions rules
2. c-expert rebuilds server so the rule is registered
3. config-expert (me) INSERTs matching row into `rule_values`
4. lua-expert reads `RuleI(Companions, RecallCooldownS)` in `!recall` handler

**What to test:**
- Verify `#reloadrules` or server restart picks up new rule
- Confirm Lua can read the rule value via the standard binding
- Test that `!recall` respects the cooldown correctly

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `RULE_INT` macro syntax | `eqemu/common/ruletypes.h` lines 1181–1202 (direct source read) | Yes | Pattern confirmed: `RULE_INT(Category, Name, default, "description")` |
| `rule_values` schema | DB live query | Yes | `rule_name`, `rule_value`, `notes` columns confirmed |
| Existing Companions rules | DB live query + ruletypes.h | Yes | 20 rules, all present and matching |
| `RULE_STR` availability | `eqemu/common/ruletypes.h` | Yes | `RULE_STR` macro exists but is not used in Companions category; string rules are uncommon |
| eqemu_config.json schema | Not consulted — no changes needed | N/A | Feature is Lua-layer only |

### Plan Amendments

Plan confirmed — no amendments needed based on research. Source code inspection of `ruletypes.h` validates the `RULE_INT` macro pattern. DB query confirms all 20 Companions rules are live and unaffected. The `RULE_STR` macro exists but the hardcode-in-Lua approach for the prefix character is clearly superior for this deployment.

### Verified Plan

See Implementation Plan above — confirmed by research. Only one new rule is needed: `Companions:RecallCooldownS`.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Rule recommendations for command prefix system | Should RecallCooldownS be a rule? Confirm prefix hardcode. No eqemu_config.json changes. |

### Feedback Received

_Awaiting response from architect._

### Consensus Plan

_Pending architect feedback._

---

## Stage 4: Build

_Not started. Awaiting architecture doc completion and task assignment._

---

## Open Items

- [ ] Awaiting architect confirmation on rule recommendations before writing ruletypes.h / rule_values changes
- [ ] After architect confirms: coordinate with c-expert on ruletypes.h addition (they own C++ files)
- [ ] After c-expert adds rule to ruletypes.h and rebuilds: INSERT rule_values row

---

## Context for Next Agent

If another agent (or a future you after context compaction) needs to pick up this work:

**The feature:** Add `!` prefix-based command system for companion management. Separates commands from natural LLM conversation. Pure Lua implementation.

**Config-expert scope:** One new rule is needed — `Companions:RecallCooldownS` (int, default 30). No eqemu_config.json changes. No other rules are affected.

**The rule addition requires:**
1. c-expert adds `RULE_INT(Companions, RecallCooldownS, 30, "Cooldown in seconds between !recall teleport uses per companion")` to `eqemu/common/ruletypes.h` after the `Companions:OOCRegenPct` line (currently line 1201)
2. Server must be rebuilt for the rule to be recognized
3. config-expert INSERTs into DB: `INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES (0, 'Companions:RecallCooldownS', '30', 'Cooldown in seconds between !recall teleport uses per companion');`
4. lua-expert reads it as `RuleI(Companions, RecallCooldownS)` in the `!recall` handler

**All 20 existing Companions rules are unaffected by this feature.**

**The `!` command prefix is hardcoded in Lua (not a rule) by design.**
