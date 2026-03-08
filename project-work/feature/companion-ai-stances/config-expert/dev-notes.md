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

### Architecture.md Review — 2026-03-08

Read full architecture.md. Key findings:

- **Only 2 new rules confirmed** — `AggressiveScanRadius` (INT, 75) and `CompanionFleeEnabled` (BOOL, true). Matches Stage 2 plan exactly. No additional rules identified.
- **Task 1 is config-expert's:** Add the two macros to ruletypes.h directly (not delegated to c-expert).
- **DB inserts NOT required:** Verified against `rulesys.cpp._SaveRule()` — `SaveRules()` auto-INSERTs missing rule_values rows on world startup. Compile-time defaults used at runtime for any rule without a DB row.

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| team-lead | Rules audit complete, 2 new rules needed | Summary of findings |
| architect | Confirmed: 2 new rules, C++ changes required | Answered 3 questions on existing rules, naming, config-only feasibility |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| architect | Architecture complete. Task 1: add 2 macros to ruletypes.h. No manual DB inserts needed. | Verified auto-populate claim against rulesys.cpp. Confirmed correct. |

### Consensus Plan

**Agreed approach:** Add exactly two new RULE macros to `eqemu/common/ruletypes.h` after line 1208. No manual DB inserts — rows auto-created on first post-build server startup.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | Modify | Add 2 RULE macros to Companions category after line 1208 |

**Change sequence (final):**
1. Open `/mnt/d/Dev/eq/eqemu/common/ruletypes.h`, locate line 1208 (`EquipmentPersistsThroughDeath`)
2. Insert two lines immediately after, before `RULE_CATEGORY_END()`:
   ```cpp
   RULE_INT(Companions, AggressiveScanRadius, 75, "Distance in game units that Aggressive stance scans for hostile targets")
   RULE_BOOL(Companions, CompanionFleeEnabled, true, "Whether companions retain NPC flee behavior after recruitment")
   ```
3. Commit to feature branch.
4. Notify c-expert that rules are defined — Task 4 (Process rewrite) can proceed.
5. After build + restart: verify `#rules set Companions:AggressiveScanRadius` works; confirm DB rows auto-inserted.

---

## Stage 4: Build

### 2026-03-08 — Added two RULE macros to ruletypes.h

**What:** Added `RULE_INT(Companions, AggressiveScanRadius, 75, ...)` and `RULE_BOOL(Companions, CompanionFleeEnabled, true, ...)` to `eqemu/common/ruletypes.h` after line 1208.

**Where:** `/mnt/d/Dev/eq/eqemu/common/ruletypes.h` lines 1209–1210 (inserted after `EquipmentPersistsThroughDeath`)

**Why:** Required for c-expert Tasks 4 and 5 — `companion.cpp` reads `RuleI(Companions, AggressiveScanRadius)` and `RuleB(Companions, CompanionFleeEnabled)`. Code won't compile without these macro definitions.

**Notes:** No DB inserts needed. `SaveRules()` auto-inserts missing rows on world startup. Committed to feature branch. Notifying c-expert to proceed with Tasks 2–5.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| Architect's claim that "X-macro auto-registers at compile time" was ambiguous | `SaveRules()` auto-insert behavior not obvious from ruletypes.h alone | Verified against `rulesys.cpp._SaveRule()` — confirmed compile-time defaults used at runtime, rows auto-created on SaveRules call |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `eqemu/common/ruletypes.h` | Modified | Added 2 new RULE macros to Companions category (lines 1209–1210) |

---

## Open Items

- [x] Read architecture.md
- [x] Confirm rule names/types with architect
- [x] Add macros to ruletypes.h (Task 1) — DONE
- [ ] After build + restart: verify `#rules set Companions:AggressiveScanRadius` recognized
- [ ] Confirm rule_values rows auto-inserted by checking DB post-restart

---

## Context for Next Agent

If picking this up after context compaction:

**What's done:** Full audit of existing Companion rules (27 rules, none stance-related). Confirmed `companion_data.stance` column exists. Added 2 new RULE macros to `eqemu/common/ruletypes.h` lines 1209–1210: `AggressiveScanRadius` (INT, 75) and `CompanionFleeEnabled` (BOOL, true). Committed to feature branch.

**What remains:** Post-build verification only — after c-expert builds and restarts server, confirm rules appear via `#rules set Companions:AggressiveScanRadius` and check DB for auto-inserted rows.

**Key files:**
- `/mnt/d/Dev/eq/eqemu/common/ruletypes.h` lines 1181–1210 — Companions rule category (now includes 2 new rules)
- `peq.rule_values` — will auto-populate on first post-build world startup (no manual inserts)
- `peq.companion_data.stance` — already exists, no change needed

**DB credentials:** `docker exec akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq`
