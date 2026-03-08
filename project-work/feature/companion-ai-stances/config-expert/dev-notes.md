# companion-ai-stances — Dev Notes: Config Expert

> **Feature branch:** `feature/companion-ai-stances`
> **Agent:** config-expert
> **Task(s):** Task #2 — Review rules and configuration needs
> **Date started:** 2026-03-08
> **Current stage:** Research (Stage 1 + 2 complete, awaiting architect architecture.md for Stage 3)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Review existing Companions rules; identify new rules needed for stance AI; insert new rule_values | Architect architecture.md | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/common/ruletypes.h` | 1181–1208 | Full Companions rule category (27 rules). No stance-related rules exist yet. |
| `peq.rule_values` (DB query) | n/a | 27 Companions rules in DB, all matching ruletypes.h defaults except `BaseRecruitChance=100` (overridden from default 50). |
| `peq.companion_data` (DB query) | n/a | `stance` column exists: `tinyint unsigned`, default `1` (Balanced). Persistence infrastructure already in place. |
| `eqemu/common/ruletypes.h` | 244–258 | Mercs category for reference. `Mercs:AggroRadius=100`, `Mercs:AggroRadiusPuller=25` are directly analogous to what companions need for Aggressive stance scanning. |

### Key Findings

**Existing Companions rules (27 total, lines 1181–1208 in ruletypes.h):**

| Rule | Type | Default | DB Value | Purpose |
|------|------|---------|----------|---------|
| CompanionsEnabled | BOOL | true | true | Master toggle |
| MaxPerPlayer | INT | 5 | 5 | Max active companions |
| LevelRange | INT | 3 | 3 | Recruitment level window |
| BaseRecruitChance | INT | 50 | **100** | Recruitment success % |
| StatScalePct | INT | 100 | 100 | Stat multiplier |
| SpellScalePct | INT | 100 | 100 | Spell damage/heal scaling |
| RecruitCooldownS | INT | 900 | 900 | Failed recruit cooldown |
| DeathDespawnS | INT | 1800 | 1800 | Auto-dismiss after death |
| MinFaction | INT | 3 | 3 | Min faction for recruitment |
| XPContribute | BOOL | true | true | XP split contribution |
| MercRetentionCheckS | INT | 600 | 600 | Merc retention check interval |
| ReplacementSpawnDelayS | INT | 30 | 30 | Replacement NPC spawn delay |
| XPSharePct | INT | 50 | 50 | Companion XP share % |
| MaxLevelOffset | INT | 1 | 1 | Companion max level = player - N |
| ReRecruitBonus | REAL | 0.10 | 0.10 | Re-recruit persuasion bonus |
| DismissedRetentionDays | INT | 30 | 30 | Days to keep dismissed data |
| CompanionSelfPreservePct | REAL | 0.20 | 0.20 | HP% to trigger self-preservation |
| MercSelfPreservePct | REAL | 0.10 | 0.10 | HP% for merc-type self-preservation |
| HPRegenPerTic | INT | 1 | 1 | Min HP regen per tic |
| OOCRegenPct | INT | 5 | 5 | OOC HP regen % of max HP |
| RecallCooldownS | INT | 30 | 30 | !recall cooldown |
| GroupChatAddressingEnabled | BOOL | true | true | @Name group chat |
| GroupChatResponseStaggerMinMS | INT | 1000 | 1000 | LLM response stagger min |
| GroupChatResponseStaggerMaxMS | INT | 2000 | 2000 | LLM response stagger max |
| EnforceClassRestrictions | BOOL | true | true | Class-based item restrictions |
| EnforceRaceRestrictions | BOOL | true | true | Race-based item restrictions |
| EquipmentPersistsThroughDeath | BOOL | true | true | Keep gear on death |

**No stance-specific rules exist.** Neither `AggressiveScanRadius` nor `CompanionFleeEnabled` (nor any variant) appear in ruletypes.h or rule_values.

**Stance persistence:** The `companion_data.stance` column already handles persistence — default 1 (Balanced), integer type. The data-expert does not need to add a column. The c-expert needs to ensure `SetStance()` writes this column on change and that re-recruitment restores it.

### Implementation Plan

Two new rules are needed based on the PRD (Section "Suggested Rule Values"):

**Rule 1: `Companions:AggressiveScanRadius`**
- Type: RULE_INT
- Default: 75
- Description: "Distance in game units that a companion in Aggressive stance scans for hostile targets to engage"
- Rationale: PRD specifies 75 as starting point (comparable to `Mercs:AggroRadius=100`). Tunable if aggressive companions trivialize content.
- Position in ruletypes.h: Append at end of Companions category (after line 1208)

**Rule 2: `Companions:CompanionFleeEnabled`**
- Type: RULE_BOOL
- Default: true
- Description: "Whether companions retain their original NPC flee behavior at low HP (adds personality, may be disabled if frustrating in practice)"
- Rationale: PRD explicitly calls for this as a future toggle; better to add now than require code change later.
- Position in ruletypes.h: Append after AggressiveScanRadius

**Database inserts needed:**
Two `INSERT INTO rule_values` rows for the new rules (after c-expert adds the macros and builds). Cannot insert until the C++ code defines the rules — the rule names must exist in the binary before the DB rows are meaningful (or at minimum they should be inserted before the next server restart that loads rules).

**Change sequence:**
1. Verify exact macro syntax and position in ruletypes.h with c-expert (c-expert owns the C++ file)
2. c-expert adds the two RULE_INT/RULE_BOOL macros to ruletypes.h
3. After build: I insert the two rule_values rows in the DB
4. Verify with `#rules Companions` in-game that new rules appear

**What to test:**
- `#rules Companions` shows `AggressiveScanRadius` and `CompanionFleeEnabled`
- Rule values are at expected defaults (75, true)
- `#setrule Companions:AggressiveScanRadius 100` persists across zone reload

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| RULE_INT / RULE_BOOL macro syntax | `eqemu/common/ruletypes.h` lines 1181–1208 (direct read) | Yes | Pattern: `RULE_INT(Category, Name, Default, "Description")` |
| RULE_CATEGORY / RULE_CATEGORY_END | `eqemu/common/ruletypes.h` lines 1181, after 1208 | Yes | Category already exists — just append rules inside it |
| rule_values table schema | `peq.companion_data` / live DB query | Yes | Columns: rule_name (varchar), rule_value (varchar), notes (text). `rule_name` is `Category:Name` format. |
| companion_data.stance column | Live DB query (DESCRIBE companion_data) | Yes | tinyint unsigned, default 1. Already exists. No DB schema change needed from config-expert. |
| Mercs:AggroRadius | `eqemu/common/ruletypes.h` line 251 | Yes | INT, default 100 — comparable reference for scan radius sizing |

### Plan Amendments

Plan confirmed — no amendments needed. The two rules from the PRD are the right additions. The macro syntax is verified from reading adjacent rules in the same file. No new DB columns are required from config-expert (stance column already exists). Rule insertion into rule_values is straightforward.

One note: I cannot insert rule_values rows until after the c-expert adds the macros and the server is rebuilt. The rules won't be recognized at runtime until the binary knows about them. However, the insert CAN be done speculatively before the build — the server will simply ignore unknown rule_names on startup until the binary is updated. For safety, I will insert after the c-expert confirms the build succeeds.

### Verified Plan

**Two new rules to add (by c-expert to ruletypes.h):**

```
RULE_INT(Companions, AggressiveScanRadius, 75, "Distance in game units that a companion in Aggressive stance scans for hostile targets to engage")
RULE_BOOL(Companions, CompanionFleeEnabled, true, "Whether companions retain their original NPC flee behavior at low HP")
```

**Two new rule_values rows to insert (by config-expert after build):**

```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes)
VALUES
  (1, 'Companions:AggressiveScanRadius', '75', 'Tunable — increase if aggressive companions are too passive, decrease if they pull too many mobs'),
  (1, 'Companions:CompanionFleeEnabled', 'true', 'Set to false if flee behavior proves frustrating in small-group play');
```

**Position in ruletypes.h:** Append at end of Companions category, before `RULE_CATEGORY_END()`. Current last rule is line 1208 (`EquipmentPersistsThroughDeath`).

---

## Stage 3: Socialize

**Waiting on:** Architect to complete architecture.md. The architect's analysis may identify additional configurable parameters beyond what the PRD suggests (e.g., balanced-stance assist radius, passive stance HP regen modifier, AI tick rate tuning). I should not finalize the rule list until the architect's assessment is complete.

**Plan to send:** When architect posts architecture.md, I will:
1. Read the Configuration Changes section
2. Compare architect's rule recommendations against my Stage 2 plan
3. Confirm rule names and types with c-expert (they own ruletypes.h)
4. Finalize and post consensus plan

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| (pending architect completion) | | |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| (pending) | | |

### Consensus Plan

_Pending architect architecture.md completion. See Stage 2 Verified Plan for current best understanding._

---

## Stage 4: Build

_Not started. Blocked on: (1) architect architecture.md, (2) c-expert adding macros to ruletypes.h, (3) server rebuild._

### Implementation Log

_No entries yet._

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| | | |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | Modify (c-expert task) | Add 2 new RULE macros to Companions category |
| `peq.rule_values` (DB) | Insert | 2 new rows for AggressiveScanRadius and CompanionFleeEnabled |

---

## Open Items

- [ ] Wait for architect architecture.md — may reveal additional rules needed
- [ ] Confirm with c-expert: exact line number and macro text for ruletypes.h additions
- [ ] Insert rule_values rows after c-expert confirms build succeeds
- [ ] Verify rules appear in-game via `#rules Companions`

---

## Context for Next Agent

If picking this up after context compaction:

**What's done:** Full audit of existing Companion rules (27 rules, none stance-related). Confirmed `companion_data.stance` column exists (no schema change needed). Identified 2 new rules needed: `Companions:AggressiveScanRadius` (INT, 75) and `Companions:CompanionFleeEnabled` (BOOL, true).

**What's blocked:** Waiting for architect to finalize architecture.md (may add more rules). Waiting for c-expert to add macros to `eqemu/common/ruletypes.h` (lines 1181–1208, append before category end). After build, insert 2 rows into `peq.rule_values` (ruleset_id=1).

**Key files:**
- `/mnt/d/Dev/eq/eqemu/common/ruletypes.h` lines 1181–1208 — Companions rule category (c-expert modifies)
- `peq.rule_values` — needs 2 new rows (config-expert inserts after build)
- `peq.companion_data.stance` — already exists, no change needed

**DB credentials:** `docker exec akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq`
