# XP Retune — Architecture & Implementation Plan

> **Feature branch:** `feature/xp-retune`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-04-27
> **Status:** Approved

---

## Executive Summary

Lower the kill-XP multiplier from 3.0x to 2.0x while leaving the AA-XP
multiplier at 3.0x. Implementation is a **single-row UPDATE on the
`peq.rule_values` table** (ruleset_id = 1, rule_name = `Character:ExpMultiplier`),
applied live via the `#reloadrulesworld` GM command. No code, no rebuild, no
restart, no protocol changes. One implementation task owned by config-expert.

## Existing System Analysis

### Current State

The server reads server-wide tunables from the `rule_values` table at
boot and caches them in the `RuleManager` singleton (`common/rulesys.h` /
`common/ruletypes.h`). Each zone process loads the active ruleset
(`zone.ruleset` column, default = ruleset_id = 1) and exposes individual
values via macros: `RuleI`, `RuleR`, `RuleB`, `RuleS`. The kill-XP path
in `zone/exp.cpp` consults `RuleR(Character, ExpMultiplier)` and
`RuleR(Character, AAExpMultiplier)` to scale the awarded XP/AA-XP per kill.

Live values (verified against the running PEQ DB by config-expert):

| ruleset_id | rule_name                       | rule_value |
|-----------:|---------------------------------|-----------:|
| 1          | `Character:ExpMultiplier`       | `3.0`      |
| 1          | `Character:AAExpMultiplier`     | `3.0`      |

A second, **inactive** ruleset_id = 10 also stores `Character:ExpMultiplier = 3.0`.
It is not loaded by any running zone (no zone has `ruleset = 10` in `zone`),
so it is out of scope and the WHERE clause below is already scoped correctly.

### Gap Analysis

PRD wants `Character:ExpMultiplier` at `2.0` on ruleset 1 with everything
else unchanged. Gap is one column update. Reload command needs to be the
broadcast variant so all 8 dynamic zone processes pick up the new value
without zone visits.

## Technical Approach

### Architecture Decision

Pure **rule-value tuning**. No code, no scripts, no schema. This is the
top of the least-invasive-first ladder.

| Component             | Change Type                  | Justification                                                              |
|-----------------------|------------------------------|----------------------------------------------------------------------------|
| `rule_values` table   | UPDATE single row            | The exact tunable (`Character:ExpMultiplier`) already exists for this purpose. |
| C++ source            | None                         | Rule is read at runtime through `RuleR(...)`; no formula change needed.    |
| Quest scripts         | None                         | No script reads or modifies kill XP through `Character:ExpMultiplier`.     |
| Server config         | None                         | Behavior is rule-driven, not config-driven.                                |
| Protocol / packets    | None                         | Server-internal calculation; client just receives `OP_ExpUpdate` ratios.   |

**No engagement needed with protocol-agent** — the change is a server-side
scalar applied before the client sees any XP update. `OP_ExpUpdate` /
`ExpUpdate_Struct` (per PROTOCOL-CODE.md §5) carry only a 0–330 progress
ratio; no struct, opcode, or wire format is touched.

### Data Model

Existing table only. No DDL.

```
peq.rule_values (
  ruleset_id  INT,
  rule_name   VARCHAR,
  rule_value  VARCHAR,
  notes       VARCHAR
)
PRIMARY KEY (ruleset_id, rule_name)
```

### Code Changes

#### C++ Changes
None.

#### Lua/Script Changes
None.

#### Database Changes

**Forward (apply the retune):**

```sql
UPDATE peq.rule_values
   SET rule_value = '2.0'
 WHERE ruleset_id = 1
   AND rule_name  = 'Character:ExpMultiplier';
```

Expected affected rows: **1**. If the UPDATE reports 0 rows or >1 row, **abort
and escalate** — the WHERE clause is the integrity check.

**Rollback (revert to 3.0x):**

```sql
UPDATE peq.rule_values
   SET rule_value = '3.0'
 WHERE ruleset_id = 1
   AND rule_name  = 'Character:ExpMultiplier';
```

Followed by `#reloadrulesworld` again.

**Pre-update verification query (record the "before" state in PR notes):**

```sql
SELECT ruleset_id, rule_name, rule_value
  FROM peq.rule_values
 WHERE ruleset_id = 1
   AND rule_name IN ('Character:ExpMultiplier', 'Character:AAExpMultiplier');
```

Expected:
- `Character:ExpMultiplier` = `3.0`
- `Character:AAExpMultiplier` = `3.0`

**Post-update verification query (must run after the UPDATE, before reload):**

Same query. Expected:
- `Character:ExpMultiplier` = `2.0`
- `Character:AAExpMultiplier` = `3.0` (unchanged — guard against accidental edit)

#### Configuration Changes

None (no `eqemu_config.json` / `.env` / login.json edits).

### Live Reload

After the UPDATE commits, run **in-game** as a GM:

```
#reloadrulesworld
```

This propagates the rule reload to **every running zone process** (per
config-expert's verification of `zone/gm_commands/rules.cpp` and
`command_settings`). The local-only variant `#reloadallrules` is **not**
sufficient — it would only refresh the issuing zone, leaving the other
seven dynamic zones still using the cached 3.0x value until they reboot.

> **Why not `#reloadrules`?** That command does not exist. config-expert
> verified this against `command_settings` and `zone/gm_commands/rules.cpp`.
> The PRD's reference to `#reloadrules` is shorthand; the actual commands are
> `#reloadallrules` (zone-local) and `#reloadrulesworld` (broadcast). We
> require the broadcast variant.

The new rate takes effect on the **next kill in each zone** after the
reload. No client-visible event fires; players will only notice via the
slower XP bar.

## Implementation Sequence

| # | Task                                                                    | Agent          | Depends On | Estimated Scope |
|---|-------------------------------------------------------------------------|----------------|------------|-----------------|
| 1 | Apply XP retune: run pre-check SELECT, execute UPDATE, run post-check SELECT, then `#reloadrulesworld` in-game; capture before/after output for the PR. | config-expert  | —          | ~5 min          |

That is the only task. There is no second implementation task because no
other layer is touched.

### Task 1 — Detailed Brief for config-expert

1. Run the pre-update SELECT and paste the result into the implementation
   notes (`config-expert/dev-notes.md` or PR description).
2. Execute the UPDATE inside a single-statement transaction (or with a row-count
   assertion). Confirm "1 row affected".
3. Run the post-update SELECT; both rows must show
   `ExpMultiplier=2.0`, `AAExpMultiplier=3.0`.
4. From a logged-in GM client, issue `#reloadrulesworld`.
5. Tail `akk-stack/server/logs/world.log` (and one zone log) for the
   reload acknowledgment and confirm no rule-parse warnings.
6. Hand off to game-tester with the captured before/after SELECT output
   and the reload log lines.

## Risk Assessment

### Technical Risks

| Risk                                                          | Likelihood | Impact | Mitigation                                                                                |
|---------------------------------------------------------------|-----------:|-------:|-------------------------------------------------------------------------------------------|
| UPDATE matches 0 or >1 rows (typo in rule_name, schema drift) | Low        | Medium | Pre-check SELECT confirms the row exists with current value `3.0`; abort if 0 or >1.       |
| `'2'` vs `'2.0'` string-format mismatch breaks float parse    | Low        | Low    | Use `'2.0'` to match existing format; `RuleManager` parses both, but consistency reduces risk. |
| `#reloadallrules` issued instead of `#reloadrulesworld`       | Medium     | Low    | Documented explicitly in this plan and in the implementation task. Zone-local reload would leave 7 zones stale until next reboot. |
| Other XP-bearing rules accidentally modified                  | Low        | High   | UPDATE WHERE clause names exactly one rule; post-check SELECT validates `AAExpMultiplier` is still `3.0`. |
| Inactive ruleset 10 confuses operator                         | Low        | Low    | WHERE clause scopes to `ruleset_id = 1`; ruleset 10 is not loaded by any zone.            |

### Compatibility Risks

`Character:ExpMultiplier` is consumed only on the kill-XP path in
`zone/exp.cpp` (per config-expert's pre-audit) and is independent from:
- group/raid bonus rules
- HotZone bonus
- `level_exp_mods` per-level curve (levels 66-70 brake)
- death XP-loss rule
- companion XP rules (custom, separate)

No regression in those paths is expected. The PRD explicitly requires
the game-tester to spot-check each of those paths to confirm.

### Performance Risks

None. One scalar read per kill; no extra queries, no cache invalidation
beyond the single rule reload.

## Review Passes

### Pass 1: Feasibility

Can we build this? **Yes.** The rule already exists at the right name with
the right semantics. The reload mechanism is a built-in GM command. No new
code paths are introduced. config-expert confirmed all three points (rule
exists, value format, reload command) against the live DB and source.

Hardest part: making sure the operator types `#reloadrulesworld` (broadcast)
and not `#reloadallrules` (zone-local). Documented in two places.

### Pass 2: Simplicity

Is this the simplest approach? **Yes.** Alternatives considered and
rejected:

- **C++ formula edit in `zone/exp.cpp`** — would require rebuild and restart.
  Wastes time when a rule already exists.
- **Lua mod hook (`SetEXP` / `GetExperienceForKill`)** — `lua_mod` provides
  these hooks (per LUA-CODE.md §Mod System), but inserting Lua to multiply
  by 2/3 is strictly worse than tuning the rule that already does the same
  thing.
- **Zone-level override via `zone.zone_exp_multiplier`** — that is per-zone,
  not server-wide, and is multiplicative on top of the global rule. Wrong tool.

Nothing to remove. Nothing to defer.

### Pass 3: Antagonistic

What could go wrong?

- **Operator typos `'2'` instead of `'2.0'`** — `RuleManager::SetRule` parses
  both as floats; behavior is identical. Mitigation: documented exact string
  `'2.0'` to match the existing format and avoid confusing future operators
  who diff the table.
- **Operator runs the UPDATE on the wrong DB** — `peq.` is qualified in the
  UPDATE; the docker mysql connection in CLAUDE.md is already the correct
  database. Low risk.
- **Operator forgets to reload** — change persists to disk but zones run on
  the cached 3.0x value until each zone reboots. Mitigation: implementation
  task explicitly sequences UPDATE → SELECT → `#reloadrulesworld` and asks
  for the world.log line confirming reload.
- **Reload fires but cache fails to refresh in some zones** — inspectable in
  zone logs. If a zone shows no reload entry, restart that zone process;
  game-tester will catch this in the per-zone XP spot-check.
- **Player exploit: leveling alt right before the reload** — the change is
  a slowdown, not a speed-up; there is no exploit window worth gaming. A
  player racing to level before the reload still earns 3.0x for the seconds
  it takes to apply the UPDATE; this is harmless and stops the moment the
  reload broadcasts.
- **Hidden quest XP path that multiplies by `Character:ExpMultiplier`** —
  config-expert confirmed `quest::exp()` and task rewards do **not** route
  through this rule; they award flat XP and are governed by separate
  quest-XP modifiers. PRD rollback criteria already cover this case.
- **Companion XP rules accidentally affected** — companion XP uses custom
  rules unrelated to `Character:ExpMultiplier` (per game-designer's
  pre-audit). Verified out-of-scope.
- **Server crash mid-UPDATE** — the UPDATE is a single statement on a
  ~hundreds-of-rows table; transaction commit is atomic. Either the new
  value is persisted or the old value remains. No partial state possible.
- **Rolling back** — symmetric UPDATE with the same WHERE clause flips
  `'2.0'` back to `'3.0'`. Same `#reloadrulesworld`. Recovery is a
  one-liner.

### Pass 4: Integration

How do the pieces fit together?

- One task. No ordering dependencies between tasks because there is only
  one task.
- The implementation task contains its own internal sequence
  (pre-SELECT → UPDATE → post-SELECT → reload → log-tail). Each step is a
  pre-check for the next.
- Hand-off to game-tester is a single artifact: the captured SQL output
  and reload log lines.
- No protocol-agent, c-expert, lua-expert, data-expert, or infra-expert
  involvement is needed. Spawning them would be wasted tokens.

## Required Implementation Agents

| Agent           | Task(s) | Rationale                                                                 |
|-----------------|--------:|---------------------------------------------------------------------------|
| `config-expert` | 1       | Owns rule_values audits and tunings; already verified the SQL and reload command against live DB. |

Do **not** spawn `c-expert`, `lua-expert`, `perl-expert`, `data-expert`,
`infra-expert`, or `protocol-agent` for this feature. None of them have
work to do.

## Validation Plan

What game-tester should verify after config-expert applies the change:

- [ ] `rule_values` row for `Character:ExpMultiplier`, ruleset_id=1 reads
      `2.0`. (`SELECT` query captured in implementation notes.)
- [ ] `rule_values` row for `Character:AAExpMultiplier`, ruleset_id=1
      still reads `3.0`. (Same `SELECT` query.)
- [ ] `world.log` shows the `#reloadrulesworld` reload broadcast and at
      least one zone-side ack with no rule-parse warnings.
- [ ] In-game spot check: kill a controlled mob (recorded baseline from
      before the change) and confirm awarded XP is roughly 2/3 (~0.667x)
      of the prior amount. Use a low-level character against a fixed mob
      type (e.g., a snake in qeynos2 hills) for a reproducible baseline.
- [ ] In-game spot check at max level: kill the same controlled mob and
      confirm AA-XP gained per kill matches pre-change rate exactly.
- [ ] Group XP bonus regression check: a 2-player group kill of the same
      mob still applies the group bonus on top of the new 2.0x base.
- [ ] HotZone bonus regression check: in a hotzone, the +0.75x bonus
      still stacks on top of 2.0x base (i.e. effective ~2.75x in hotzones).
- [ ] Death XP loss spot check: a controlled death still removes 1.5%
      (rule unchanged).
- [ ] Companion XP regression check: companion-attributed kills still
      award XP per the existing companion rules; the kill-XP retune does
      not bleed into companion-specific paths.
- [ ] No server rebuild was performed and no zone process was restarted
      during the change (timestamp on zone process startup unchanged).

---

> **Next step:** Spawn the implementation team with **only** `config-expert`.
> Do not spawn any other expert. Implementation is a single ~5-minute task.
