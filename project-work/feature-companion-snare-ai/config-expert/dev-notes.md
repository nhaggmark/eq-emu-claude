# Companion Snare AI: Combat Restriction — Dev Notes: config-expert

> **Feature branch:** `feature/companion-snare-ai`
> **Agent:** config-expert
> **Task(s):** TBD — architecture.md not yet filled in (working in parallel with architect)
> **Date started:** 2026-05-03
> **Current stage:** Stage 3 (Socialize) — awaiting architect confirmation before Stage 4

---

## Task Assignment

Assigned during Architecture phase to plan and seed two new `Companions:*` rule values.

| # | Task | Depends On | Status |
|---|------|------------|--------|
| — | Plan SnareHpThreshold + SnareResistLimit rule shape | — | Complete |
| — | Confirm namespace with architect | architect | Pending |
| — | Seed rule_values rows | c-expert RULE_INT registration | Pending |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/common/ruletypes.h` | 1182–1256 | `Companions:*` category already exists with ~40 rules |
| `eqemu/common/ruletypes.h` | 770–912 | `Bots:*` category for comparison — includes `Bots:PercentChanceToCastSnare` (line 824) |
| `eqemu/common/ruletypes.h` | 543 | `Spells:SnareOverridesSpeedBonuses` — no collisions with proposed names |
| DB `rule_values` | — | Queried live DB — 47 existing `Companions:*` rows, no snare entries |

### Key Findings

1. **Namespace confirmed: `Companions:*`** — This project already has a mature `Companions:*` rule category (lines 1182–1256 of `ruletypes.h`). This is the unambiguous correct namespace. `Bots:*` is the upstream bot system and not used for companion-specific rules on this server.

2. **No name collisions** — Neither `Companions:SnareHpThreshold` nor `Companions:SnareResistLimit` exist in `ruletypes.h` or in the live `rule_values` table. Safe to add both.

3. **Existing snare-related rules are in other namespaces** — `Spells:SnareOverridesSpeedBonuses` (spell mechanics) and `Bots:PercentChanceToCastSnare` (bot casting probability) are unrelated to this feature. No risk of semantic overlap.

4. **RULE_INT macro is correct** — Both new rules are integer values (HP percent, resist count). `RULE_INT(Companions, SnareHpThreshold, 20, "...")` is the correct pattern. No RULE_REAL or RULE_BOOL needed.

5. **Rule access macro pattern** — In C++, these rules are accessed as:
   - `RuleI(Companions, SnareHpThreshold)`
   - `RuleI(Companions, SnareResistLimit)`

6. **DB seed pattern** — All other Companions rules in the live DB follow the format:
   ```
   ruleset_id=1, rule_name='Companions:RuleName', rule_value='<value>', notes='<description>'
   ```

### Implementation Plan

**Two new rules to register in `eqemu/common/ruletypes.h`** (c-expert's job):

```cpp
RULE_INT(Companions, SnareHpThreshold, 20,
    "HP percentage at or below which companions may autonomously cast snare during combat "
    "(combined with flee-state check). Default 20.")
RULE_INT(Companions, SnareResistLimit, 2,
    "Maximum snare resists per (companion, target) per engagement before the companion "
    "stops attempting snare on that target. Default 2.")
```

**Two new rows to INSERT into `rule_values`** (config-expert's job, after c-expert registers the rules):

```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES
(1, 'Companions:SnareHpThreshold', '20',
 'HP percentage at or below which companions may autonomously cast snare during combat (combined with flee-state check).'),
(1, 'Companions:SnareResistLimit', '2',
 'Maximum snare resists per companion/target per engagement before companion stops trying. Default 2, min 0.');
```

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | Modify (c-expert task) | Add 2 RULE_INT entries to `Companions:` category |
| DB `rule_values` table | Insert (config-expert task) | 2 new rows |

**Change sequence:**
1. c-expert adds `RULE_INT(Companions, SnareHpThreshold, ...)` and `RULE_INT(Companions, SnareResistLimit, ...)` to `ruletypes.h`
2. c-expert implements the AI gating logic using `RuleI(Companions, SnareHpThreshold)` and `RuleI(Companions, SnareResistLimit)`
3. config-expert inserts the two `rule_values` rows
4. Server rebuild + restart picks up the new rules; `#reloadrules` is NOT sufficient for newly registered rules (requires rebuild)

**What to test:**
- AC-11 from the PRD: setting `Companions:SnareHpThreshold` to 30 should change gate to 30% HP
- AC-11: setting `Companions:SnareResistLimit` to 1 should cap at 1 resist per target

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `RULE_INT` macro signature | `eqemu/common/ruletypes.h` lines 1182–1256 | Yes | Pattern confirmed from existing Companions rules |
| `RuleI(category, name)` access macro | `eqemu/common/rulesys.h` (referenced in C-CODE.md) | Yes (via topography doc) | Used as `RuleI(Companions, SnareHpThreshold)` |
| `rule_values` schema | Live DB query | Yes | `ruleset_id`, `rule_name`, `rule_value`, `notes` columns |
| Name collision check | `ruletypes.h` grep + live DB query | Yes | No existing `SnareHp*` or `SnareResist*` in either |
| `Companions:*` namespace | `ruletypes.h` lines 1182–1256 + live DB | Yes | 47 existing Companions rules confirm namespace |
| Existing AI cast-gating rules | `ruletypes.h` lines 1228–1240 | Yes | `HealThresholdPct`, `ManaCutoffPct`, `HealerManaConservePct` exist but cannot be extended for snare (no flee-state, no per-target counter) |
| `#reloadrules` / `LoadRules` source | `eqemu/common/rulesys.cpp` lines 204–220, 258–332 | Yes | `_FindRule` searches compile-time `s_RuleInfo[]` — new rules silently ignored until binary rebuilt; after rebuild `#reloadrules` updates live values immediately |

### Plan Amendments

Plan confirmed — no amendments needed. Research validated all assumptions.

Additional findings from architect Q&A:

1. **No existing rules can be extended** — `HealThresholdPct`, `ManaCutoffPct`, `HealerManaConservePct` are single-dimension with no flee-state or per-target resist logic. New rules required.

2. **`#reloadrules` requires rebuild first** — `_FindRule()` in `rulesys.cpp` searches compile-time static `s_RuleInfo[]`. New `RULE_INT` entries are invisible to `#reloadrules` until the binary is rebuilt. After rebuild, runtime tuning via `#reloadrules` works correctly and AC-11 will pass.

One note on min/max constraints: `RULE_INT` macros in EQEmu do not encode min/max in the rule definition itself — valid ranges are documented in the `notes` string only. The architect's C++ code enforces meaningful clamping if desired. Ranges documented in notes string.

### Verified Plan

See Implementation Plan above — confirmed by research. Rule shape and namespace are solid.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Namespace confirmation + rule shape (proactive) | Confirming Companions:* namespace and RULE_INT types for both rules |
| architect | Full Q1-Q4 response (in reply to architect request) | All 4 items answered: namespace, existing rules, exact definitions, reloadrules behavior |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| architect | Pending final sign-off | — |

### Consensus Plan

**Pending architect sign-off.** The plan below is the config-expert's proposed consensus, ready to execute once architect confirms.

**Agreed approach:**

Use `Companions:SnareHpThreshold` (RULE_INT, default 20) and `Companions:SnareResistLimit` (RULE_INT, default 2) in the existing `Companions:*` category. No new category needed.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | Modify (c-expert) | Two RULE_INT entries at end of Companions category |
| DB `rule_values` | Insert (config-expert) | Two rows, ruleset_id=1 |

**Change sequence (final):**
1. c-expert registers `RULE_INT(Companions, SnareHpThreshold, 20, ...)` and `RULE_INT(Companions, SnareResistLimit, 2, ...)` in `ruletypes.h`
2. c-expert implements AI gate code referencing these rules via `RuleI()`
3. config-expert inserts seed rows into `rule_values`
4. Server rebuild required (new RULE_INT registration); `#reloadrules` alone is not enough for newly registered rules

---

## Stage 4: Build

_Pending architect sign-off and c-expert RULE_INT registration._

### Implementation Log

_Not started._

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| — | — | — |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| DB `rule_values` | Insert | Two rows — to be executed once c-expert confirms RULE_INT is in ruletypes.h |

---

## Open Items

- [ ] Architect to confirm rule names, types, and namespace (Q8 from PRD)
- [ ] Architect to clarify: should `SnareResistLimit = 0` mean "never give up" or "never try"? Default is 2; the PRD implies 0 should disable the cap (never give up). Document in notes string accordingly.
- [ ] c-expert to add RULE_INT entries before config-expert can insert rule_values rows
- [ ] After architect confirmation: execute Stage 4 (INSERT rule_values rows) and commit

---

## Context for Next Agent

If picking this up after context compaction:

**The work here is entirely in the database.** No C++ changes for config-expert — that belongs to c-expert. Config-expert's sole deliverable is two `INSERT INTO rule_values` rows.

**The namespace is `Companions:*`.** This is confirmed by examining `eqemu/common/ruletypes.h` lines 1182–1256 and the live DB (47 existing `Companions:*` rows). No ambiguity.

**The two rules:**
- `Companions:SnareHpThreshold` — RULE_INT, default 20 — HP% gate for autonomous snare
- `Companions:SnareResistLimit` — RULE_INT, default 2 — per-target resist cap per engagement

**Dependency:** c-expert must add the `RULE_INT(Companions, SnareHpThreshold, ...)` and `RULE_INT(Companions, SnareResistLimit, ...)` entries to `eqemu/common/ruletypes.h` AND the server must be rebuilt before the `rule_values` rows are meaningful. The rows can be inserted before the rebuild but they won't be loaded until the next server start after rebuild.

**INSERT SQL (ready to run):**
```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES
(1, 'Companions:SnareHpThreshold', '20',
 'HP percentage at or below which companions may autonomously cast snare during active combat. Combined with flee-state check. Range 1-100, default 20.'),
(1, 'Companions:SnareResistLimit', '2',
 'Snare resists per (companion, target) per engagement before companion stops attempting snare on that target. 0 = no cap (never give up). Default 2.');
```

Run from host with:
```
docker exec akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e "<sql>"
```
