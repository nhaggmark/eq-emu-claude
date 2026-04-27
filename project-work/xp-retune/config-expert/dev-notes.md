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

- [ ] Architect to confirm they will update `#reloadrules` to `#reloadrulesworld` in architecture plan

---

## Context for Next Agent

Rule `Character:ExpMultiplier` in `rule_values` WHERE `ruleset_id=1` currently
has value `3.0`. The implementation task is a single UPDATE setting it to `2.0`,
followed by `#reloadrulesworld` in-game. Rollback is the symmetric UPDATE back
to `3.0`. Do NOT touch ruleset_id=10.
