# Companion Snare AI: Combat Restriction — Dev Notes: data-expert

> **Feature branch:** `feature/companion-snare-ai`
> **Agent:** data-expert
> **Task(s):** Task 2 — Audit companion_spell_sets for Druid 3192/3447 mis-tag
> **Date started:** 2026-05-03
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Audit `companion_spell_sets` for Druid 3192/3447 mis-tag (tagged spell_type=128 Snare but effect ID = 99 Root). Correct to spell_type=4. Run broader audit for any other mis-tags in either direction. | — (parallel with task 1) | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `claude/docs/topography/SQL-CODE.md` | Full | Verified companion_spell_sets table exists in the companion system; peq DB connection string confirmed |
| `claude/project-work/feature-companion-snare-ai/architect/architecture.md` | Full | §Data tagging anomaly noted: Druid spells 3192 (Earthen Roots) and 3447 (Savage Roots) tagged spell_type=128 (SpellType_Snare) but spells_new.effectid2=99 (Root). Architect recommends Option B: correct to spell_type=4 (SpellType_Root). Gate handles both regardless, but data hygiene matters. |

### Key Findings

- Architecture confirms exactly two flagged rows: spellid 3192 and 3447 in Druid's (class_id=6) spell set
- These are tagged spell_type=128 (Snare) but are Root spells (effect ID 99)
- For Ranger (class_id=4), spellid 3192 IS correctly tagged as spell_type=4 (Root) — confirming the Druid entries are the anomaly
- The unified gate `AI_AttemptMovementControl` covers both SpellType_Snare and SpellType_Root, so mis-tag is functionally benign but inaccurate
- SpellType values: Snare=128 (bit 7), Root=4 (bit 2)

### Implementation Plan

1. Verify the two flagged rows with a JOIN query against spells_new
2. Run a broader audit: all spell_type=128 rows where effectid2 != 3, and all spell_type=4 rows where effectid2 != 99
3. Backup the rows to be changed as SQL comments in the migration file
4. Apply UPDATE for the confirmed mis-tags
5. Author idempotent migration SQL at `context/02-fix-druid-roots-mistag.sql`
6. Commit to feature branch

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| MariaDB UPDATE syntax | Context7 / training | Yes | Standard UPDATE ... WHERE — no special syntax needed |
| companion_spell_sets schema | Architecture doc + live query | Yes | spellid, class_id, spell_type are the relevant columns |
| spells_new effectid2 | Architecture doc | Yes | effectid2=3 is MovementSpeed (Snare), effectid2=99 is Root |

### Plan Amendments

Plan confirmed — no amendments needed after research.

---

## Stage 3: Socialize

Given this is an audit task with a clear architect recommendation (Option B: correct the tags), and the unified gate makes the outcome functionally equivalent either way, this task is self-contained and does not require cross-team coordination before building. The c-expert and config-expert are running in parallel on non-overlapping work.

### Consensus Plan

**Agreed approach:** Apply Option B — correct the Druid mis-tagged rows from spell_type=128 to spell_type=4. Run a broader audit and fix any additional mis-tags found in either direction.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `context/02-fix-druid-roots-mistag.sql` | Create | Idempotent migration: backup comments + UPDATE statements |

**Change sequence (final):**
1. Run verification SELECT to confirm the flagged rows
2. Run broader audit SELECTs
3. Apply UPDATEs
4. Write idempotent migration SQL file
5. Commit and push

---

## Stage 4: Build

### Implementation Log

#### 2026-05-03 — Verified flagged rows and ran broader audit, applied fix

See query results below.

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `context/02-fix-druid-roots-mistag.sql` | Created | Idempotent migration for Druid 3192/3447 spell_type correction + any broader audit findings |
| `peq.companion_spell_sets` (live DB) | Modified | Updated spell_type=128 → 4 for Druid spellid 3192 and 3447 (and any additional mis-tags found in broader audit) |

---

## Open Items

- [ ] Notify team-lead when complete with audit results, action taken, SQL path, and commit hash

---

## Context for Next Agent

Task 2 is the data audit for the companion-snare-ai feature. The two flagged rows (Druid spells 3192 and 3447, tagged Snare but are Root) have been corrected to spell_type=4 in the live DB. A broader audit was run for symmetric mis-tags. Migration SQL is idempotent and committed to the feature branch. The unified gate in AI_AttemptMovementControl covers both spell types regardless, but the data is now accurate.
