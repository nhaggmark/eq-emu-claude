# XP Retune — Dev Notes: Config Expert

> **Feature branch:** `feature/xp-retune`
> **Agent:** config-expert
> **Task(s):** Validate architecture plan — rule name, SQL syntax, reload command, rollback SQL
> **Date started:** 2026-04-27
> **Current stage:** Stage 3 Consensus — awaiting architecture doc, then Stage 4

---

## Task Assignment (v2 Final — Approach B confirmed by architect 2026-04-27)

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 (v1 carry-over) | Pre-check → UPDATE `Character:ExpMultiplier` `'3.0'`→`'2.0'` (ruleset_id=1) → post-check → `#reloadrulesworld` | None (can run while build is in progress) | Not Started |
| 2 (v2 new) | Pre-check → UPDATE `Companions:XPSharePct` `'50'`→`'100'` (ruleset_id=1) → post-check → `#reloadrulesworld` | C++ rebuild + server process restart MUST complete first; verify new binary is running before applying | Not Started |

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

---

## Stage 2–3 (v2 Round 2): Architect Deep-Dive — Full Q&A Findings

> **Triggered by:** Architect detailed questions on all six topics.
> **Date:** 2026-04-27
> **Sources:** Live DB query, grep ruletypes.h, grep zone/attack.cpp, zone/exp.cpp, zone/companion.cpp

### Q1: Companions:XPSharePct — complete current state

- **Current value (ruleset_id=1):** `50` (string `'50'` in DB, integer at runtime via `RuleI`)
- **ruletypes.h definition:** `RULE_INT(Companions, XPSharePct, 50, "Percentage of a companion's XP share that actually goes to the companion (remainder to player pool)")` — type INT, default 50, no explicit bounds documented in the macro
- **C++ consumers — TWO, not one:**
  1. `eqemu/zone/exp.cpp:1197` — group XP path (`Group::SplitExp`)
  2. `eqemu/zone/attack.cpp:2794` — solo kill XP path (solo companion receives from killer's final_exp)
  Both sites have identical clamp logic: `if (xp_share_pct < 0) { xp_share_pct = 0; } if (xp_share_pct > 100) { xp_share_pct = 100; }`
  The cap must be removed or raised in BOTH files for any value above 100 to take effect.
- **ruleset_id=10 (inactive "EQEmu_Default"):** No `Companions:*` rules at all. Zero rows. This is a fully custom rule category — no stock baseline to worry about.
- **database_update_manifest.h:** Rule was seeded via the manifest as `'50'` with the same notes text. This confirms it was always custom.

### Q2: Cap-vs-repurpose-vs-new-rule recommendation

**Option A (delete clamp, leave rule alone):** Requires updating BOTH exp.cpp:1197-1199 and attack.cpp:2794-2796. Semantics become "0–N% scaler" with no upper bound — surprising and hard to reason about at values >100.

**Option B (repurpose XPSharePct as post-multiplier, default 100):** The notes say "remainder to player pool" — that framing breaks if the rule becomes a post-multiplier scaler instead of a pre-multiplier percentage. Reinterpreting a rule with existing semantics is confusing. The live value is `50`; an operator who set this intentionally would see their companion XP double on next reload without touching anything.

**Option C (introduce Companions:XPMultiplier, keep XPSharePct as-is at 100 for parity):** Cleanest. `XPSharePct` stays semantically coherent ("what % of the split goes to the companion") but is set to `100` so the full per-member share reaches the companion. `XPMultiplier` (RULE_REAL, default 1.0) is a post-`CalculateExp` scaler that can go above 1.0 if a future operator wants companions to earn more than players. The two rules are orthogonal — one gates the split, one scales after the multiplier pipeline.

**Config-expert recommendation: Option C, with a modification.**
The cleanest long-term design is:
- Set `Companions:XPSharePct` to `100` in rule_values (operator-visible: "companions get their full share")
- Remove the cap in exp.cpp and attack.cpp (both sites)
- Add `RULE_REAL(Companions, XPMultiplier, 1.0, ...)` in ruletypes.h as a post-CalculateExp scaler, INSERT into rule_values
- The parity refactor routes companions through `CalculateExp` (c-expert's job); `XPMultiplier` is the knob for any future deviation from parity without a code change

This also means no operator confusion: `XPSharePct=100` means "full share" (its natural maximum), and `XPMultiplier=1.0` means "no extra scaling" (neutral default). Both are self-documenting.

**Sole risk to flag:** Adding a new rule to `ruletypes.h` requires a C++ rebuild (confirmed below in Q5). The INSERT for `Companions:XPMultiplier` into rule_values ships in the same rebuild+restart window.

### Q3: AA-seam rule reservations (document, do NOT add now)

Suggested names that fit the existing `Companions:` convention:

| Rule | Type | Default | Purpose |
|------|------|---------|---------|
| `Companions:AAExpEnabled` | RULE_BOOL | false | Master toggle: when true, route a fraction of companion XP into AA accrual |
| `Companions:AAExpPct` | RULE_INT | 0 | Percentage of companion XP that becomes AA XP (0 = all regular XP; analogous to how live EQ splits XP at player's chosen ratio) |

Naming notes:
- `AAExpPct` over `AAExpSharePct` — keeps it parallel to `XPDeathPenaltyPct` (single-word noun + Pct suffix)
- Avoid `AAExpMultiplier` — that implies scaling above the parity amount; the future feature probably wants a split ratio, not a multiplier
- The attach point in `companion.cpp` is `Companion::AddExperience` — a future feature wraps or replaces this call with the AA split logic when `AAExpEnabled` is true

These names are not reserved in code today — the future feature inserts them into `ruletypes.h` at implementation time. Document them in the architecture plan so the name is stable.

### Q4: Other Companions:* rules that might overlap

Full XP-adjacent rule inventory (from ruletypes.h):
- `Companions:XPContribute` (BOOL, true) — gates whether companions are counted in group split at all. If false, they're excluded from `Group::SplitExp` entirely. The parity refactor must still gate on this rule.
- `Companions:XPSharePct` (INT, 50) — the rule being changed
- `Companions:XPDeathPenaltyPct` (INT, 10) — death penalty only; unrelated to parity

No per-zone or per-character overrides affect companion XP. The `zone_exp_multiplier` (ZEM) is applied inside `Client::CalculateExp` (exp.cpp:433-434) on the player path — it does NOT reach the companion path currently. This is part of the parity gap the refactor fixes: after routing companions through `CalculateExp`, the ZEM will apply to them too. That is the correct behavior (companions should benefit from hotzone bonuses just as players do) and is consistent with the PRD.

### Q5: Does #reloadrulesworld pick up a new rule without rebuild?

**No. Adding a rule to ruletypes.h requires a C++ rebuild.**

Rules are defined via X-macros in `common/ruletypes.h`. The `RuleManager` expands these macros at compile time to build the rule registry. `#reloadrulesworld` only re-reads `rule_values` from the DB into the already-compiled registry — it cannot add new rule slots that don't exist in the binary. If `Companions:XPMultiplier` is added to `ruletypes.h` but the binary isn't rebuilt, the rule is simply absent from the registry and `RuleR(Companions, XPMultiplier)` would return the default (1.0) regardless of what's in `rule_values`.

**Sequencing implication:** For Option C, the INSERT for `Companions:XPMultiplier` into `rule_values` must happen in the same maintenance window as the rebuild+restart — or after. Inserting it before the rebuild is harmless (the row sits unused in the DB) but serves no purpose. Recommend: INSERT as part of the rebuild+restart window so the rule is live immediately when zones start.

### Q6: v1 rate-change task sequencing

**Yes, v1 Task 1 is still valid.** The `Character:ExpMultiplier` 3.0→2.0 UPDATE is independent of the C++ refactor.

**Recommended order (single maintenance window):**
1. Apply `Character:ExpMultiplier` UPDATE + `#reloadrulesworld` (no downtime — can do this while building)
2. C++ build completes
3. Restart server processes (loginserver → world → 8 zones)
4. Zones come up with new binary + new rule in registry + already-live rate change

There is no reason to reverse this order. The parity refactor does not depend on the rate change, and the rate change does not depend on the refactor. Doing the rule UPDATE first means the player immediately sees 2x kill XP as soon as `#reloadrulesworld` runs, even before the restart. The companion parity improvement lands at restart. This is the cleanest UX — no window where the player has 3x AND the companion is broken.

**If shipping in separate windows:** Rule UPDATE can land any time via `#reloadrulesworld`. Companion parity requires rebuild + full restart. Note in the architecture plan that game-tester must validate companion parity AFTER the restart, not after the rule reload.

---

## Stage 3 Consensus (v2 Final): Architect Design Decision — Approach B

> **Date:** 2026-04-27
> **Architect message:** Final SQL spec received. Approach B confirmed.

### Decision Summary

Architect chose **Approach B**: keep `> 100` clamp, repurpose `Companions:XPSharePct` as a post-multiplier scalar with default changed in `ruletypes.h` from 50 → 100 (c-expert task). The existing ruleset_id=1 row has the explicit value `'50'` and must be UPDATEd to `'100'` — the `ruletypes.h` default change does not automatically update existing DB rows.

No new rule INSERT. No AA-seam rules in this feature.

### Final Implementation Tasks

**Task 1 (v1 carry-over): Character:ExpMultiplier rate change**

Timing: Pre-rebuild, can run while C++ build is in progress.

```sql
-- Pre-check (expect '3.0')
SELECT ruleset_id, rule_name, rule_value
  FROM rule_values
 WHERE ruleset_id = 1
   AND rule_name  = 'Character:ExpMultiplier';

-- Forward
UPDATE rule_values
   SET rule_value = '2.0'
 WHERE ruleset_id = 1
   AND rule_name  = 'Character:ExpMultiplier';

-- Post-check (expect '2.0')
SELECT ruleset_id, rule_name, rule_value
  FROM rule_values
 WHERE ruleset_id = 1
   AND rule_name  = 'Character:ExpMultiplier';

-- Rollback (if needed)
UPDATE rule_values
   SET rule_value = '3.0'
 WHERE ruleset_id = 1
   AND rule_name  = 'Character:ExpMultiplier';
```

After forward UPDATE: `#reloadrulesworld` in-game.

**Task 2 (v2 new): Companions:XPSharePct parity activation**

Timing: POST-rebuild + POST-restart only. Verify new binary is running before applying.
Verification step: confirm c-expert's `Companion::AddExperience` refactor is in the running binary (log line check or process timestamp) before running this UPDATE.

```sql
-- Pre-check (expect '50')
SELECT ruleset_id, rule_name, rule_value
  FROM rule_values
 WHERE ruleset_id = 1
   AND rule_name  = 'Companions:XPSharePct';

-- Forward
UPDATE rule_values
   SET rule_value = '100'
 WHERE ruleset_id = 1
   AND rule_name  = 'Companions:XPSharePct';

-- Post-check (expect '100')
SELECT ruleset_id, rule_name, rule_value
  FROM rule_values
 WHERE ruleset_id = 1
   AND rule_name  = 'Companions:XPSharePct';

-- Rollback (if needed)
UPDATE rule_values
   SET rule_value = '50'
 WHERE ruleset_id = 1
   AND rule_name  = 'Companions:XPSharePct';
```

After forward UPDATE: `#reloadrulesworld` in-game.

### Concern Flagged to Architect (2026-04-27)

The architect's sequencing rationale states: "Setting the rule to 100 BEFORE the rebuild would change companion behavior in the OLD code: companions would get 100% of pre-multiplier slice (current behavior at clamp ceiling), still no multipliers — meaning they'd still be at the same ~50% gap relative to player."

**This is not quite right.** In the OLD code, `XPSharePct=100` with the `> 100 → 100` clamp still present means companions receive `member_share * 100 / 100 = member_share` — i.e., the full pre-multiplier slice, NOT 50% of it. That is actually BETTER than the current 50% parity gap, not equivalent to it. So applying Task A before the rebuild would give companions a temporary improvement (full pre-multiplier share) while the refactor is built, then the correct post-multiplier behavior kicks in at restart.

This is still safe — no data corruption, no crash risk, no semantic inversion. The architect's "either order works for safety" conclusion is correct. Post-restart sequencing is the cleaner approach regardless, because the behavior change is unambiguous (parity via the new code) and the verification step is clean. Flagging the rationale error only so the architecture doc doesn't contain a misleading explanation that would confuse future readers.

No change to the implementation plan. Task A still runs post-restart as specified.
