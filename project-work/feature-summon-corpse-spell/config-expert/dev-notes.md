# Universal Summon Corpse Spell — Dev Notes: Config Expert

> **Feature branch:** `feature/summon-corpse-spell`
> **Agent:** config-expert
> **Task(s):** Rule definition for `Spells:UniversalSummonCorpseCooldown`; rule_values insert; eqemu_config/login.json assessment
> **Date started:** 2026-05-03
> **Current stage:** Socialize

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Define and insert `Spells:UniversalSummonCorpseCooldown` rule | c-expert adds rule to ruletypes.h and consumes it | Awaiting architect review |
| 2 | Confirm no eqemu_config.json or login.json changes needed | None | Complete (confirmed: no changes needed) |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/common/ruletypes.h` | 425–549 | Full `Spells` rule category. No existing summon-corpse or UniversalSummonCorpse rule. New rule appends before `RULE_CATEGORY_END()` at line 549. |
| `eqemu/zone/spells.cpp` | 1419, 1800–1836, 2817–2845 | `recast_time` from `spells_new` drives the per-gem cooldown. `EndurTimerIndex` drives cross-spell shared timers. |
| `eqemu/common/spdat.h` | 1686 | `timer_id` (maps to `EndurTimerIndex` DB column) is an `int8`, valid range 1–19. The C++ code explicitly returns early if `timer_id > 19`. |
| `peq.spells_new` | — | `Summon Corpse` (id=3) and `Lesser Summon Corpse` (id=2213) both have `EndurTimerIndex=0` (no shared timer) and `recast_time=12000` (12 seconds). |
| `peq.rule_sets` | — | Active server ruleset is `ruleset_id=1` (`default`). Other rulesets (2–20) exist but are not used by zones on this server. |
| `peq.rule_values` | — | All existing `Spells:*` rules use `ruleset_id=1`. No collision with `Spells:UniversalSummonCorpseCooldown`. |

### Key Findings

1. **No existing rule collision.** The key `Spells:UniversalSummonCorpseCooldown` does not exist in `ruletypes.h` or `rule_values`. Safe to add.

2. **Cooldown is data-driven, not code-enforced independently.** The `recast_time` field in `spells_new` (milliseconds) is the source of the per-gem cooldown. The spell engine reads it directly at cast completion. A rule that controls cooldown must be consumed by C++ code that writes the appropriate `recast_time` into the spell data at load time, OR the c-expert needs to plumb a runtime override of the recast timer when the spell fires.

3. **Critical: all EndurTimerIndex slots (1–19) are fully taken.** The 12 new spells cannot share a single cross-spell cooldown timer using the existing `EndurTimerIndex` mechanism. Each of the 12 spells will enforce its own `recast_time` independently per memorized gem slot. This means a character with two of the 12 spells memorized could theoretically cast one, wait for that gem's recast, then cast a different class's version — but since each of the 12 spells is restricted to a single class (class bitmask), a player will never have more than one of the 12 in their spellbook. Cross-class abuse is architecturally impossible. The shared-timer problem does not exist.

4. **Rule type should be int (seconds), default 180.** Matching the PRD. The c-expert will read this rule and use it as `RuleI(Spells, UniversalSummonCorpseCooldown) * 1000` to set `recast_time` on the new spells at load time, or pass it as the cooldown duration at cast completion.

5. **Per-character scope is correct.** The spell recast timer is per-character per-gem-slot, tracked in `ptimers` (persisted in `timers` table). No `rule_values` scoping issue — rules are global; per-character tracking is handled by the existing spell engine.

6. **eqemu_config.json and login.json: no changes needed.** The PRD explicitly flags server configuration as out of scope. Confirmed: this feature touches only the database (spell data, rule values, items, merchants) and C++ source (rule definition + consumption). No config file changes.

### Implementation Plan

The config-expert's scope is:
- Add `RULE_INT(Spells, UniversalSummonCorpseCooldown, 180, ...)` to `ruletypes.h` (c-expert task — I flag where to insert)
- Insert the rule row into `rule_values` for `ruleset_id=1`

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | c-expert modifies | New `RULE_INT` line inserted before `RULE_CATEGORY_END()` at line 549 |
| `peq.rule_values` | data-expert inserts | One new row for `ruleset_id=1` |

**Change sequence:**
1. c-expert adds rule definition to `ruletypes.h`
2. c-expert consumes `RuleI(Spells, UniversalSummonCorpseCooldown)` in the cast-completion path for the new spells
3. data-expert inserts `rule_values` row (can be done in parallel with step 1–2, before or after; the rule row is only consumed at server start)
4. After server restart, `#reloadrules` is not sufficient for a new rule — a full server restart is required since new rules must be compiled in first

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `RULE_INT(category, name, default, description)` macro | `eqemu/common/ruletypes.h` directly inspected | Yes | Pattern confirmed from 100+ existing examples in the file |
| `RuleI(Spells, ...)` access macro | `eqemu/common/rulesys.h` (referenced in C-CODE.md) | Yes | `#define RuleI(category, rule) RuleManager::Instance()->GetIntRule(RuleManager::Int__##rule)` |
| `recast_time` field in `spells_new` | DB query + `spells.cpp` source | Yes | In milliseconds; read at `CastedSpellFinished()` path |
| `EndurTimerIndex` shared timer | DB query + `spdat.h` source | Yes | int8, max value 19, all slots 1–19 occupied |
| `rule_sets` / `rule_values` schema | DB query | Yes | `ruleset_id=1` is active default ruleset |
| `eqemu_config.json` / `login.json` scope | PRD §Affected Systems | Yes | Explicitly listed as no changes expected; confirmed |

### Plan Amendments

**EndurTimerIndex exhaustion is a notable finding** but does not block the feature — it only means the 12 spells cannot share a timer group. Since each spell is class-restricted, a single character can only have one of the 12, making cross-spell timer sharing unnecessary. The rule still makes sense: it controls the `recast_time` value baked into the spell data at creation time.

**One amendment to the original approach:** The PRD implied the rule would let the operator "adjust live without a content patch." Strictly, adjusting the rule at runtime with `#reloadrules` will NOT change the spell's in-flight `recast_time` because `recast_time` is loaded from the DB into shared memory at server start (via `shared_memory` process). Changing the rule requires: (1) update `rule_values`, (2) update `spells_new.recast_time` for the 12 spells, (3) restart `shared_memory` + zone processes. This is still better than a full C++ recompile — the architect should document this limitation in the architecture doc.

**Alternative the architect should consider:** The c-expert could read the rule dynamically at cast time (bypass the `spells_new.recast_time` check) and set the recast timer directly, making the rule truly hot-reloadable. This decision belongs to the architect and c-expert, not config-expert.

### Verified Plan

Rule definition confirmed. SQL insert confirmed. Scope confirmed. No eqemu_config.json or login.json changes needed.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Rule plan summary (proactive) | Confirm rule shape, flag EndurTimerIndex exhaustion, flag recast_time hot-reload limitation |
| architect | Answers to architect's two questions | (1) No generated header needed beyond ruletypes.h; (2) Recommend option (b) dynamic cast-time rule lookup |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| architect | Asked: correct macro syntax? anything beyond ruletypes.h? which of 3 cooldown options? | Answered both questions in full; awaiting architect confirmation to proceed to Stage 4 |

### Consensus Plan

_Awaiting architect sign-off on option (b) dynamic cast-time lookup and the C++ hook key. All other decisions are settled._

**Agreed approach (pending architect confirmation of Q2):**

- `RULE_INT(Spells, UniversalSummonCorpseCooldown, 180, ...)` added to `ruletypes.h` by c-expert
- C++ reads `RuleI(Spells, UniversalSummonCorpseCooldown)` dynamically at cast completion for the 12 new spells (hook key to be chosen by architect + c-expert — recommend `spell_category` or `spell_group` field, not `SE_SummonCorpse` which would also hit existing Necro/Shaman spells)
- `rule_values` row inserted by data-expert in same migration as spell data, `ruleset_id=1` only
- `#reloadrules` sufficient to tune cooldown without restart (if option b is confirmed)

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | c-expert modifies | New `RULE_INT` line before `RULE_CATEGORY_END()` at line 549 |
| `peq.rule_values` | data-expert inserts | One row: `ruleset_id=1`, `'Spells:UniversalSummonCorpseCooldown'`, `'180'` |

**Change sequence (final):**
1. c-expert adds `RULE_INT` line to `ruletypes.h` and rebuilds binary
2. c-expert adds cast-time rule lookup in `spells.cpp` for new spells
3. data-expert inserts `rule_values` row (can be done in parallel with steps 1–2; row is read after restart)

---

## Rule Definition

### Rule to add to `eqemu/common/ruletypes.h`

Insert before `RULE_CATEGORY_END()` at line 549, after the last existing `Spells` rule:

```cpp
RULE_INT(Spells, UniversalSummonCorpseCooldown, 180, "Cooldown in seconds for the universal self-summon-corpse spell available to all 12 casting classes. Default 180 (3 minutes). Range: 0-3600. Requires spell data update and server restart to take effect.")
```

**Category:** `Spells`
**Type:** `int` (seconds)
**Default:** `180`
**Suggested valid range:** 0–3600 (0 = no cooldown, 3600 = 1 hour max)
**C++ macro access:** `RuleI(Spells, UniversalSummonCorpseCooldown)`

### SQL insert into `rule_values`

```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes)
VALUES (
  1,
  'Spells:UniversalSummonCorpseCooldown',
  '180',
  'Cooldown in seconds for the universal self-summon-corpse spell available to all 12 casting classes. Default 180 (3 minutes). Range: 0-3600. Requires spell data update and server restart to take effect.'
);
```

**Ruleset:** `ruleset_id=1` (`default`) only. No other rulesets need this row — they inherit from the default ruleset.

**When to run:** After c-expert adds the rule to `ruletypes.h` and the binary is rebuilt. The `rule_values` row can be inserted before the binary change without harm; the server simply won't read it until the new binary exists.

---

## Stage 4: Build

**Started:** 2026-05-03

### Implementation Log

**Task 1 — ruletypes.h edit:**
- File: `eqemu/common/ruletypes.h`
- Inserted at line 549 (before `RULE_CATEGORY_END()`, after last existing `Spells` rule `AlwaysStackSpells`):
  ```cpp
  RULE_INT(Spells, UniversalSummonCorpseCooldown, 180, "Cooldown in seconds for the universal self-summon-corpse spell line (12 class-flavored level-1 spells). 0 disables the cooldown. Default 180 (3 minutes). Range: 0-3600. Hot-reloadable via #reloadrules.")
  ```
- `RULE_CATEGORY_END()` now at line 550.
- Build step owned by infra-expert (task 10).

**Task 8 — rule_values SQL:**
- File: `claude/project-work/feature-summon-corpse-spell/config-expert/migrations/08-rule-values.sql`
- SQL: `INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES (1, 'Spells:UniversalSummonCorpseCooldown', '180', '...')`
- data-expert includes this in the bundled transactional migration (task 9).

**Status: Both tasks complete. Committed to feature/summon-corpse-spell.**

---

## Open Items

- [ ] Architect to confirm: should the rule be applied dynamically at cast time (making `#reloadrules` sufficient to change cooldown) or baked into `spells_new.recast_time` at server start (requiring a spell data update + restart)?
- [ ] Architect to confirm: is `ruleset_id=1` the only ruleset to insert into, or should the data-expert insert into all active zone rulesets?
- [ ] c-expert to confirm: the rule macro is being inserted at the right line in `ruletypes.h` (before `RULE_CATEGORY_END()` at line 549, i.e., the Spells category end).

---

## Context for Next Agent

The config-expert scope for this feature is minimal: one new `RULE_INT` in `ruletypes.h` (c-expert writes it, config-expert specifies it) and one `rule_values` DB insert.

**The key finding is that `EndurTimerIndex` slots 1–19 are all taken.** This means the 12 new spells cannot use the linked-timer mechanism to share a cooldown group. Each spell enforces its own `recast_time` independently. This is fine because each spell is class-restricted — a character can only ever have one of the 12 in their spellbook.

**The cooldown rule is not hot-reloadable by default.** Changing `rule_values` + `#reloadrules` is insufficient; the rule value must be read by C++ at cast time (dynamic path) or at spell-data load time, not just by the rule cache. The architect decides which path.

**Active ruleset is `ruleset_id=1` only.** Other rulesets in the DB are unused by zones on this server.

**No eqemu_config.json or login.json changes needed.**
