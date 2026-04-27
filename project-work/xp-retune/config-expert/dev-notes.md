# XP Retune — Dev Notes: Config Expert

> **Feature branch:** `feature/xp-retune`
> **Agent:** config-expert
> **Task(s):** Validate architecture plan — rule name, SQL syntax, reload command, rollback SQL
> **Date started:** 2026-04-27
> **Current stage:** Socialize (validation complete, messaging architect)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Validate rule name, current value, SQL syntax, reload command, rollback | Architecture plan from architect | Complete |

---

## Stage 1: Plan

### Key Findings

Queried live DB (ruleset_id=1) and verified rule_values. Cross-referenced
`#reload` commands against C++ source (`zone/gm_commands/rules.cpp` and
`common/database/database_update_manifest.h` command_settings table).

### Implementation Plan

Validation only — no changes in this phase.

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `Character:ExpMultiplier` rule name | Live DB query | Yes | Exact spelling confirmed |
| Current value ruleset_id=1 | Live DB query | Yes | Value is `3.0` |
| `Character:AAExpMultiplier` current value | Live DB query | Yes | Value is `3.0`, stays unchanged |
| `#reloadallrules` command | `command_settings` table + `rules.cpp` | Yes | Correct command for zone-scoped reload |
| `#reloadrulesworld` command | `command_settings` table | Yes | Propagates reload to ALL running zones |
| `#reloadrules` | Source search | NO — does not exist | See critical finding below |

### Plan Amendments — Critical Finding

**`#reloadrules` does NOT exist.** The architect's plan likely names the
wrong command. The correct reload commands are:

- `#reloadallrules` — reloads the active ruleset in the **current zone only**
  (calls `RuleManager::Instance()->LoadRules(...)` in `rules.cpp:91`)
- `#reloadrulesworld` — sends reload signal to **all running zone processes**
- `#rules reload` — also zone-scoped, same effect as `#reloadallrules`

For an XP rule change affecting all zones, `#reloadrulesworld` is the
correct command to use so all zone processes pick up the new value immediately
without requiring individual zone visits.

### Verified Plan

Rule name: `Character:ExpMultiplier`
Current value in ruleset_id=1: `3.0`
Target value: `2.0`

Forward SQL:
```sql
UPDATE rule_values
SET rule_value = '2.0'
WHERE ruleset_id = 1
  AND rule_name = 'Character:ExpMultiplier';
```

Rollback SQL (symmetric and safe — restores exact original value):
```sql
UPDATE rule_values
SET rule_value = '3.0'
WHERE ruleset_id = 1
  AND rule_name = 'Character:ExpMultiplier';
```

Reload command (apply live without restart):
```
#reloadrulesworld
```

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Validation result | Confirm `#reloadrules` does not exist; correct command is `#reloadrulesworld` |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| | | |

### Consensus Plan

Pending architect acknowledgment. Plan is otherwise confirmed.

---

## Stage 4: Build

Not applicable — this phase is validation only. DB changes happen in
implementation phase.

---

## Operational Notes

- Rule reload via `#reloadrulesworld` affects all currently-loaded zones simultaneously.
  New XP rate takes effect on the **next kill** after reload in any zone.
- Ruleset_id=10 also has `Character:ExpMultiplier = 3.0` — this is a separate
  ruleset (not the active one). The active ruleset for the server is **ruleset_id=1**.
  Do NOT modify ruleset_id=10.
- The `Character:AAExpMultiplier` stays at `3.0` — confirmed, no change needed.
- No server restart required. `#reloadrulesworld` is sufficient.

---

## Open Items

- [x] Architect confirmed `#reloadrulesworld` in architecture plan (resolved v1)

---

## Context for Next Agent

Rule `Character:ExpMultiplier` in `rule_values` WHERE `ruleset_id=1` currently
has value `3.0`. The implementation task is a single UPDATE setting it to `2.0`,
followed by `#reloadrulesworld` in-game. Rollback is the symmetric UPDATE back
to `3.0`. Do NOT touch ruleset_id=10.

---

## Stage 1–3 (v2): Companion XP Parity Rule Validation

> **Triggered by:** v2 scope expansion — architect team needs rule_values
> validation before finalizing the companion XP parity approach.
> **Date:** 2026-04-27

### Live DB Query Results

**Companion rules on ruleset_id=1 (active ruleset):**

| Rule | Value | Notes |
|------|-------|-------|
| `Companions:XPSharePct` | `50` | "Percentage of a companion's XP share that actually goes to the companion (remainder to player pool)" |
| `Companions:XPContribute` | `true` | Whether companions count in group XP split calculations |
| `Companions:XPDeathPenaltyPct` | `10` | Percentage of current level XP lost when companion dies |
| `Companions:XPMultiplier` | _does not exist_ | No such rule present |

**Companion rules in non-active rulesets:**
- Zero rows. All `Companions:*` rules exist ONLY on ruleset_id=1.
  This confirms these are fully custom rules — EQEmu stock rulesets have
  none of them (ruleset_id=10 "EQEmu_Default" has no Companion category at all).

**`Character:ExpMultiplier` state (unchanged from v1):**
- ruleset_id=1: `'3.0'` — still the original value (implementation not yet run)
- ruleset_id=10: `'3.0'` — inactive, do not touch

### Key Findings for Architect

**Finding 1: `Companions:XPSharePct` is a 100% custom rule.**
It does not appear in any stock EQEmu ruleset. No backward-compat concern:
there is no upstream default to reconcile against. The architect can freely
repurpose or ignore it without risk of diverging from a stock baseline.

**Finding 2: No `Companions:XPMultiplier` rule exists.**
If the architect proposes a new rule named `Companions:XPMultiplier` (or
similar), the `rule_values` INSERT schema is clean — no collision.

Schema for inserting a new rule on ruleset_id=1:
```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes)
VALUES (1, 'Companions:XPMultiplier', '1.0',
        'Post-split XP multiplier applied to the companion XP share. 1.0 = parity with player. Intended range 0.0–2.0.');
```

The `rule_values` PK is `(ruleset_id, rule_name)` — any INSERT must be
scoped to a specific ruleset. A new rule inserted on ruleset_id=1 will
not propagate to ruleset_id=10 or others unless separately inserted.

**Finding 3: Current `Companions:XPSharePct = 50` is the root-cause blocker.**
Combined with the hardcoded max-100 cap at `exp.cpp:1199`, the companion
receives at most 50% of its per-member share. To reach parity (100% of
per-share), the architect must either:
- Remove/raise the cap AND set `Companions:XPSharePct` to `100`, OR
- Repurpose `Companions:XPSharePct` as a post-multiplier scaler and route
  companions through the same `CalculateExp` pipeline as the player (cap removal
  not needed if the rule is no longer the gating mechanism), OR
- Introduce a new rule (e.g. `Companions:XPMultiplier`) that scales the
  post-`CalculateExp` result, making `Companions:XPSharePct` semantically
  obsolete for parity purposes.

Any of these approaches is cleanly accommodated by the current `rule_values`
schema. No schema changes are required.

**Finding 4: Operational sequencing — can the two pieces ship separately?**

The `Character:ExpMultiplier` 3.0 → 2.0 UPDATE is rule-only and can land
via `#reloadrulesworld` at any time, with no code dependency.

The companion XP parity refactor requires a C++ rebuild + server-process
restart cycle. `#reloadrulesworld` does NOT cover C++ changes.

Therefore:
- The rule UPDATE can land independently at any time.
- The parity refactor must be followed by: rebuild → stop processes →
  start processes (loginserver → world → 8 zone processes).
- If the architect wants them to land together in one maintenance window,
  the recommended sequence is: (1) apply rule UPDATE first (no downtime),
  (2) rebuild C++, (3) restart server processes. Rule is already live when
  zones come back up.
- If they land in separate windows, the player will briefly have 2.0x kill XP
  with the companion still at ~50% parity — which is acceptable but should
  be noted in the architecture plan so the game-tester knows to test parity
  AFTER the restart, not after the rule reload.

**Finding 5: AA-friendly seam — no rule implications.**
The AA-seam requirement is a C++ structural concern, not a rule concern.
The only rule-level implication would arise if the architect introduces
a `Companions:AAExpMultiplier` or similar rule for future companion AAs.
No such rule should be created in this feature — the AA feature will INSERT
its own rule when the time comes. The rule_values schema will accommodate it.

### Validated Approach Summary

Regardless of which approach the architect chooses, the config-expert
implementation tasks for v2 are:

**Always required:**
- UPDATE `Character:ExpMultiplier` to `'2.0'` on ruleset_id=1 (same as v1 Task 1)
- `#reloadrulesworld` after the UPDATE

**If architect introduces a new rule (e.g. `Companions:XPMultiplier`):**
- INSERT new rule into rule_values on ruleset_id=1 with the architect-specified
  default value (suggest `1.0` for parity)
- This INSERT can be part of the rebuild+restart maintenance window since
  a new rule requires the C++ `ruletypes.h` macro to exist before it's
  meaningful at runtime

**If architect repurposes `Companions:XPSharePct`:**
- UPDATE `Companions:XPSharePct` to a new value on ruleset_id=1 (e.g. `100`)
- This also requires the C++ cap removal to be effective, so it ships in
  the rebuild+restart window

**If architect removes the cap without touching the rule:**
- No additional rule_values changes needed beyond the rate UPDATE

### Consensus Plan (pending architect confirmation)

The architecture approach is the architect's call. Config-expert's job is:
1. Rate UPDATE: `Character:ExpMultiplier` `'3.0'` → `'2.0'` via `#reloadrulesworld`
2. Any rule_values changes the architect specifies for the parity mechanism
   (INSERT or UPDATE, with exact values to be provided by architect)

No rule_values changes are made until Stage 4 (implementation phase).
