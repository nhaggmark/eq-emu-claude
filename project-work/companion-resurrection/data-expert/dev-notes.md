# Companion Resurrection System — Dev Notes: Data Expert

> **Feature branch:** `feature/companion-resurrection`
> **Agent:** data-expert
> **Task(s):** Task 11 (architecture.md)
> **Date started:** 2026-03-15
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 11 | Verify rez spell IDs from `spells_new`, populate `companion_spell_sets` + `rule_values` | — | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | What You Found |
|------|----------------|
| `companion_spell_sets` table | 10-column schema: `id`, `class_id`, `min_level`, `max_level`, `spell_id`, `spell_type`, `stance`, `priority`, `min_hp_pct`, `max_hp_pct`. No SpellType_Resurrect (65536) entries exist yet. |
| `spells_new` table | Effect columns are `effectid1`–`effectid12` and `effect_base_value1`–`effect_base_value12`. Class level columns are `classes1`–`classes16`. |
| `rule_values` table | Ruleset 1 = "default" — all existing `Companions:*` rules live here. No `Companions:Rez*` or `Companions:XPDeathPenalty*` rules exist. |
| `rule_sets` table | Ruleset 1 = "default", active ruleset. |

### Key Findings

**Rez spells found (effectid=81, id<3000, era-appropriate):**

| ID | Name | CLR lvl | PAL lvl | NEC lvl | Mana | XP% | Cast ms |
|----|------|---------|---------|---------|------|-----|---------|
| 388 | Resuscitate | 37 | 255 | 255 | 500 | 60% | 6000 |
| 391 | Revive | 27 | 39 | 255 | 300 | 35% | 6000 |
| 392 | Resurrection | 47 | 59 | 255 | 700 | 90% | 6000 |
| 1524 | Reviviscence | 56 | 255 | 255 | 600 | 96% | 7000 |
| 1733 | Convergence | 255 | 255 | 53 | 700 | 93% | 6000 |
| 2168 | Reanimation | 12 | 22 | 255 | 150 | 0% | 6000 |
| 2169 | Reconstitution | 18 | 30 | 255 | 200 | 10% | 6000 |
| 2170 | Reparation | 22 | 31 | 255 | 250 | 20% | 6000 |
| 2171 | Renewal | 32 | 49 | 255 | 400 | 50% | 6000 |
| 2172 | Restoration | 42 | 55 | 255 | 600 | 75% | 6000 |

**Excluded spells (post-Luclin per PRD):**
- 994: Customer Service Resurrect (level 255, non-player spell)
- 1342: Larger Reviviscence (CLR 61)
- 1344: Greater Reviviscence (CLR 66)
- 1345: Eminent Reviviscence (CLR 71)
- 1346: Superior Reviviscence (CLR 76)
- 2738: Divine Resurrection (level 254, GM-only)

**Architecture doc discrepancies found:**
- Architecture doc listed only: Reanimation, Revive, Resuscitate, Resurrection, Reviviscence (CLR); Revive, Resurrection (PAL); Convergence (NEC)
- Database has 5 additional spells: Reconstitution (CLR 18, PAL 30), Reparation (CLR 22, PAL 31), Renewal (CLR 32, PAL 49), Restoration (CLR 42, PAL 55)
- PRD says "only era-appropriate rez spells" — these are all Classic era, so include all of them
- PRD says use "highest-level rez spell" — C++ will pick highest affordable; having all spells in the table gives the AI more fallback options when mana is low

**Priority scheme:** Existing `companion_spell_sets` entries use `priority=1` for heals, buffs, and most spell types. Architecture doc confirms `priority=1` is highest for this table. Use `priority=1` for all rez entries.

**min_hp_pct / max_hp_pct:** All existing combat-healing spells use hp thresholds. Rez spells target corpses (not living targets) — set both to 0 to not filter by HP percentage. The C++ rez AI handles targeting logic separately.

**stance:** All existing entries use `stance=0` (all stances). Use 0.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `claude/project-work/companion-resurrection/data-expert/context/add_rez_spells.sql` | Create | Migration SQL: INSERT into `companion_spell_sets` and `rule_values` |

**Change sequence:**
1. Build INSERT statements for `companion_spell_sets` — CLR (9 spells), PAL (6 spells), NEC (1 spell)
2. Build INSERT statements for `rule_values` — 5 new rules
3. Execute against the database
4. Verify with SELECT queries

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| Multi-row INSERT syntax | Context7 `/mariadb-corporation/mariadb-docs` | Yes | `INSERT INTO t (cols) VALUES (row1), (row2), ...` — confirmed valid |
| `effectid1` column name | Live DB query `SHOW COLUMNS FROM spells_new` | Yes | Column is `effectid1`, not `effect_id1` |
| `effect_base_value1` column name | Live DB query `SHOW COLUMNS FROM spells_new` | Yes | Column is `effect_base_value1`, not `base1` |
| `companion_spell_sets` schema | Live DB `DESCRIBE companion_spell_sets` | Yes | 10 columns confirmed; `id` is auto_increment |
| Existing priority scheme | Live DB SELECT on CLR/PAL/NEC rows | Yes | `priority=1` is standard for high-priority spells |
| Active ruleset | Live DB `SELECT * FROM rule_sets` | Yes | `ruleset_id=1` = "default" is the active ruleset |

### Plan Amendments

The architecture doc listed only 5 CLR rez spells and 2 PAL rez spells. The actual DB has a richer set:
- CLR: 9 era-appropriate rez spells (Reanimation through Reviviscence)
- PAL: 6 era-appropriate rez spells (Reanimation through Resurrection)
- NEC: 1 spell (Convergence)

Including all of them maximizes the AI's fallback options when mana is limited. This is consistent with the PRD's mana management design ("if no rez spell is affordable, sit and meditate") and the PRD's goal of including all Classic-Luclin era rez spells.

The architecture doc's SQL example had some placeholder IDs — all IDs are now confirmed from the live database.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| c-expert | Confirmed rez spell IDs and effect data for C++ implementation | Sharing spell IDs, XP restore %, mana costs for `ResurrectFromCorpse()` and `SelectBestRezSpell()` |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| c-expert | Pending | — |

### Consensus Plan

**Agreed approach:** Insert all era-appropriate rez spells into `companion_spell_sets` for CLR (class_id=2), PAL (class_id=3), and NEC (class_id=11) with `spell_type=65536` (`SpellType_Resurrect = 1<<16`), `priority=1`, `stance=0`, `min_hp_pct=0`, `max_hp_pct=0`. Insert 5 new rules into `rule_values` for ruleset_id=1.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `claude/project-work/companion-resurrection/data-expert/context/add_rez_spells.sql` | Create | Full migration SQL |

**Change sequence (final):**
1. Create SQL migration file
2. Execute migration
3. Verify with SELECT queries
4. Commit SQL to feature branch

---

## Stage 4: Build

### Implementation Log

#### 2026-03-15 — Query database to confirm spell IDs and schema

**What:** Ran `DESCRIBE companion_spell_sets`, `SHOW COLUMNS FROM spells_new`, and `SELECT ... FROM spells_new WHERE effectid1=81 ...` queries to confirm all spell IDs, XP restore percentages, mana costs, and class level requirements.

**What:** Ran `SELECT * FROM companion_spell_sets WHERE spell_type=65536` — confirmed no rez entries exist yet.

**What:** Ran `SELECT ... FROM rule_values WHERE rule_name LIKE 'Companions:Rez%'` — confirmed no rez rules exist yet.

#### 2026-03-15 — Execute migration SQL

**What:** Created and executed `add_rez_spells.sql` — 16 rows inserted into `companion_spell_sets`, 5 rows inserted into `rule_values`.

**Where:** `claude/project-work/companion-resurrection/data-expert/context/add_rez_spells.sql`

**Why:** Populates the data required by the C++ rez AI (`companion_ai.cpp`) to find and cast rez spells via `SelectBestRezSpell()`. Also creates the 5 rule values needed by the C++ implementation for compile-time rule macros.

**Notes:**
- min_level/max_level set to exact class level — the C++ AI picks the highest-level spell the companion can cast that it has enough mana for
- max_level set to 65 for all (no upper cap — higher spells aren't available anyway in era)
- All 9 CLR rez spells included (Reanimation through Reviviscence) for full mana-management fallback ladder
- All 6 PAL rez spells included (Reanimation through Resurrection — PAL doesn't get Reviviscence)
- NEC gets only Convergence (only rez spell available in era at level 53)
- XP restore base_value confirmed from `effect_base_value1`: 0, 10, 20, 35, 50, 60, 75, 90, 93, 96%

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| Architecture doc spell ID for Reanimation was "TBD" | Not yet queried when architecture was written | Found in spells_new: ID 2168. Also found 4 additional spells the architecture hadn't accounted for. |
| Architecture doc used `base1` column name | Wrong column name | Correct column is `effect_base_value1` — verified via SHOW COLUMNS |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `claude/project-work/companion-resurrection/data-expert/context/add_rez_spells.sql` | Created | Migration SQL for companion_spell_sets rez entries + rule_values |

---

## Open Items

- [ ] Wait for c-expert to confirm the spell IDs and XP values work correctly in their implementation

---

## Context for Next Agent

Task 11 is complete. The migration SQL at `context/add_rez_spells.sql` has been executed against the live database. 16 new rows are in `companion_spell_sets` (9 CLR + 6 PAL + 1 NEC) and 5 new rows in `rule_values` (ruleset_id=1).

Key facts for the C++ implementation:
- SpellType_Resurrect = 65536 (1 << 16) — matches `spell_type` in companion_spell_sets
- All rez spells use `effectid1=81` and `effect_base_value1` = XP restore percentage
- Convergence (ID 1733) `effect_base_value2 = -90` — this is the HP restore to the TARGET, not the XP %, which is in effect_base_value1=93
- Rule values are in ruleset_id=1 ("default")
