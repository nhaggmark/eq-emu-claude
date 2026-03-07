# Group Chat Companion Addressing — Dev Notes: Data Expert

> **Feature branch:** `feature/group-chat-addressing`
> **Agent:** data-expert
> **Task(s):** Task #2
> **Date started:** 2026-03-07
> **Current stage:** Waiting for blocker (Task #1 must complete first)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Insert rule_values rows for 3 Companion rules | Task #1 (c-expert adds rules to ruletypes.h) | Blocked — waiting for Task #1 |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `claude/project-work/feature/group-chat-addressing/architect/architecture.md` | 1-619 | Full architecture; exact SQL specified in "Database Changes" section |
| `claude/docs/topography/SQL-CODE.md` | 1-100 | Rule system uses `rule_values` table with columns: ruleset_id, rule_name, rule_value, notes |
| `claude/project-work/feature/group-chat-addressing/status.md` | 1-149 | Implementation phase Not Started; Task #1 not yet begun by c-expert |

### Key Findings

- The `rule_values` table stores per-ruleset overrides. `ruleset_id=1` is the default active ruleset.
- No new tables, no schema changes — only 3 INSERT rows into existing `rule_values`.
- The SQL is fully specified in the architecture doc. No research gaps.
- Task #1 (c-expert adding `RULE_CATEGORY(Companion)` block to `ruletypes.h`) must complete first. The database rows are logically downstream: the server reads rule_values at startup and maps them against the compiled rule definitions. If the C++ definitions don't exist, the rows are harmless but serve no purpose until the binary is built.
- Architecture note: "Task 2 can run in parallel with Task 3 (SQL doesn't block compilation)" — meaning once Task #1 is done, I can insert immediately without waiting for Task #3.

### Implementation Plan

**SQL to execute:**
```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes)
VALUES
(1, 'Companion:GroupChatAddressingEnabled', 'true',
 'Enable @Name companion addressing via /gsay group chat'),
(1, 'Companion:GroupChatResponseStaggerMinMS', '1000',
 'Min stagger delay in ms between companion LLM responses in group chat'),
(1, 'Companion:GroupChatResponseStaggerMaxMS', '2000',
 'Max stagger delay in ms between companion LLM responses in group chat');
```

**Verification SELECT:**
```sql
SELECT ruleset_id, rule_name, rule_value, notes
FROM rule_values
WHERE rule_name LIKE 'Companion:%'
ORDER BY rule_name;
```

**Change sequence:**
1. Wait for Task #1 to be marked Complete
2. Run SELECT to confirm no pre-existing `Companion:*` rows (avoid duplicates)
3. Execute the INSERT
4. Verify with SELECT — confirm 3 rows returned
5. Update status.md Task #2 to Complete
6. Mark Task #2 in task list as completed
7. Notify team-lead

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `rule_values` table schema | SQL-CODE.md topography doc | Yes | ruleset_id, rule_name, rule_value, notes columns confirmed |
| INSERT syntax | MariaDB standard — no exotic syntax used | Yes | Plain INSERT ... VALUES, no JSON, no window functions |
| Duplicate check | SELECT before INSERT | Yes | Best practice before inserting named config rows |

### Plan Amendments

Plan confirmed — no amendments needed. The SQL is verbatim from the architecture doc. The only
risk is duplicate rows if the INSERT is run twice; the pre-insert SELECT guards against that.

### Verified Plan

See Implementation Plan above — confirmed by research.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| team-lead | Task #2 blocked waiting for Task #1 | Notified team-lead that c-expert must complete Task #1 before I can proceed |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| (awaiting Task #1 completion) | | |

### Consensus Plan

**Agreed approach:** Execute the 3 INSERT statements verbatim from architecture.md once Task #1 is complete.
Pre-check with SELECT to avoid duplicate rows. Verify with SELECT after insert.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `peq.rule_values` (DB table) | INSERT | 3 new rows for Companion:* rules |
| `claude/project-work/feature/group-chat-addressing/status.md` | Modify | Update Task #2 status to Complete |
| `claude/project-work/feature/group-chat-addressing/data-expert/dev-notes.md` | Modify | Stage 4 implementation log |

**Change sequence (final):**
1. Confirm Task #1 complete
2. SELECT to verify no existing Companion:* rows
3. INSERT 3 rows
4. SELECT to verify 3 rows present
5. Update status.md + mark task complete + notify team-lead

---

## Stage 4: Build

### Implementation Log

#### 2026-03-07 — Insert 3 Companions group chat rule_values rows

**What:** Inserted 3 new rows into `rule_values` for the Companions group chat addressing feature.

**Where:** `peq.rule_values` table, ruleset_id=1

**Why:** Populates default rule values so the server can read `RuleB(Companions, GroupChatAddressingEnabled)`,
`RuleI(Companions, GroupChatResponseStaggerMinMS)`, and `RuleI(Companions, GroupChatResponseStaggerMaxMS)`
at runtime. Matches the RULE_CATEGORY(Companions) block added by c-expert in Task #1.

**Notes:**
- Category name confirmed as `Companions` (plural) — c-expert found the existing category was already
  plural. Architecture doc said `Companion` (singular) but the actual ruletypes.h uses `Companions`.
- Pre-check SELECT confirmed the 3 new rules did not already exist (21 other Companions:* rows present).
- Post-insert SELECT confirmed all 3 rows inserted correctly with correct values and notes.

**SQL executed:**
```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes)
VALUES
(1, 'Companions:GroupChatAddressingEnabled', 'true',
 'Enable @Name companion addressing via /gsay group chat'),
(1, 'Companions:GroupChatResponseStaggerMinMS', '1000',
 'Min stagger delay in ms between companion LLM responses in group chat'),
(1, 'Companions:GroupChatResponseStaggerMaxMS', '2000',
 'Max stagger delay in ms between companion LLM responses in group chat');
```

**Verification result:**
```
ruleset_id  rule_name                                  rule_value  notes
1           Companions:GroupChatAddressingEnabled      true        Enable @Name companion addressing via /gsay group chat
1           Companions:GroupChatResponseStaggerMaxMS   2000        Max stagger delay in ms between companion LLM responses in group chat
1           Companions:GroupChatResponseStaggerMinMS   1000        Min stagger delay in ms between companion LLM responses in group chat
```

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| Category name mismatch | Architecture doc used `Companion` (singular) but ruletypes.h already had `Companions` (plural) | c-expert notified me before execution; used `Companions:*` in all inserts |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `peq.rule_values` (DB table) | INSERT | 3 rows: Companions:GroupChatAddressingEnabled, GroupChatResponseStaggerMinMS, GroupChatResponseStaggerMaxMS |

---

## Open Items

- [x] Wait for Task #1 (c-expert: ruletypes.h) — COMPLETE
- [x] Task #2 INSERT — COMPLETE

---

## Context for Next Agent

Task #2 is complete. 3 rows inserted and verified in `peq.rule_values`:
- `Companions:GroupChatAddressingEnabled` = `true`
- `Companions:GroupChatResponseStaggerMinMS` = `1000`
- `Companions:GroupChatResponseStaggerMaxMS` = `2000`

Note: category name is `Companions` (plural), not `Companion` as written in the architecture doc.
