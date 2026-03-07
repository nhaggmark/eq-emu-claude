# Companion Equipment Management Enhancement — Dev Notes: Data Expert

> **Feature branch:** `feature/companion-equipment`
> **Agent:** data-expert
> **Task(s):** Task #2 — Insert 3 rule_values rows
> **Date started:** 2026-03-07
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Insert 3 rule_values rows for equipment rules | None | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| SQL-CODE.md (topography) | Rule System section | rule_values PK is (ruleset_id, rule_name); existing Companions: rules use ruleset_id=1 |
| rule_values (live SELECT) | 3 rows | None of the 3 target rules existed; ruleset_id=1 is "default" ruleset |

### Key Findings

- `rule_values` schema: `ruleset_id` (tinyint unsigned), `rule_name` (varchar 64), `rule_value` (text), `notes` (text nullable)
- Primary key is composite: `(ruleset_id, rule_name)` — no auto-increment, plain INSERT
- Ruleset 1 = "default" — confirmed via `rule_sets` SELECT
- 24 existing `Companions:*` rules; none of the 3 equipment rules existed

### Implementation Plan

Straight INSERT of 3 rows into `rule_values` with ruleset_id=1. No dependencies. Verify with SELECT after.

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| MariaDB INSERT syntax | Live schema inspection | Yes | Standard INSERT INTO ... VALUES, no auto-increment PK |

### Plan Amendments

Plan confirmed — no amendments needed.

---

## Stage 3: Socialize

Task was self-contained (data-only, no cross-system dependencies). No socialization required per team-lead instructions.

---

## Stage 4: Build

### Implementation Log

#### 2026-03-07 — Insert 3 Companions equipment rule_values

**What:** Inserted 3 rows into `rule_values` for companion equipment management rules.

**Where:** MariaDB `peq` database, `rule_values` table, ruleset_id=1

**Why:** C++ code (Task #1) reads these rule names via `RuleB(Companions, EnforceClassRestrictions)` etc. The rows must exist in the DB for the server to load them at startup.

**SQL executed:**
```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES
(1, 'Companions:EnforceClassRestrictions', 'true', 'Enforce class-based item restrictions when equipping items on companions'),
(1, 'Companions:EnforceRaceRestrictions', 'true', 'Enforce race-based item restrictions when equipping items on companions'),
(1, 'Companions:EquipmentPersistsThroughDeath', 'true', 'If true, companion equipment is retained after death (not dropped on corpse)');
```

**Verified:** SELECT confirmed all 3 rows present with correct values.

**Notes:** No schema changes needed — `rule_values` table already exists. No migration file required; these are content rows, not schema.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| None | — | — |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `peq.rule_values` (DB) | 3 rows inserted | Equipment restriction and death-persistence rules for companion system |

---

## Open Items

- None

---

## Context for Next Agent

Task #2 is complete. Three `rule_values` rows now exist in ruleset_id=1:

- `Companions:EnforceClassRestrictions` = `true`
- `Companions:EnforceRaceRestrictions` = `true`
- `Companions:EquipmentPersistsThroughDeath` = `true`

These correspond to the `RULE_BOOL` entries being added in `common/ruletypes.h` (Task #1, c-expert). The C++ server reads these at startup via the rule system — no further DB work needed for this feature unless new rules are added.
