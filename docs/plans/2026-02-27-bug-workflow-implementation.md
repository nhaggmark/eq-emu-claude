# Bug Workflow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add formal bug reporting and resolution workflow to the EQ agent system.

**Architecture:** Four file changes — one new template, one new status file, two edits to existing docs. No code, no agents, no branches.

**Tech Stack:** Markdown templates, existing agent workflow

---

### Task 1: Create the Bug Report Template

**Files:**
- Create: `claude/templates/bug-report.md`

**Step 1: Write the template**

```markdown
# BUG-NNN: [Short Title]

> **Severity:** Critical | High | Medium | Low
> **Reported by:** [user | game-tester]
> **Date:** YYYY-MM-DD
> **Feature:** [feature-name or "general"]
> **Status:** Open | Investigating | Fix In Progress | Resolved

---

## Observed Behavior

_What happened?_

## Expected Behavior

_What should have happened?_

## Reproduction Steps

1.
2.
3.

## Evidence

_Logs, screenshots, error messages, SQL queries, or test case reference
(e.g. "Test #8 from validation-report.md")._

## Affected Systems

_Check all that apply. These determine which expert agents are assigned
during triage._

- [ ] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
```

**Step 2: Verify the file exists**

Run: `cat claude/templates/bug-report.md | head -5`
Expected: Shows the `# BUG-NNN:` header line.

**Step 3: Commit**

```bash
git add claude/templates/bug-report.md
git commit -m "feat(workflow): add bug report template"
```

---

### Task 2: Add Bug Reports Section to Status Template

**Files:**
- Modify: `claude/templates/status.md:56-63` (after Blockers section, before Decision Log)

**Step 1: Add the Bug Reports table**

Insert the following after line 63 (`| | | | |`) and its trailing `---`:

```markdown
## Bug Reports

_Bugs discovered during testing or play. Status flow:
Open → Investigating → Fix In Progress → Resolved._

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| | | | | | | |

---
```

The insertion point is between the existing `## Blockers` section and `## Decision Log` section. The `---` separator after Blockers (line 64) should be replaced by the new section followed by its own `---`.

**Step 2: Verify the section appears**

Run: `grep -n "Bug Reports" claude/templates/status.md`
Expected: Shows the line number of the new section header.

**Step 3: Commit**

```bash
git add claude/templates/status.md
git commit -m "feat(workflow): add Bug Reports section to status template"
```

---

### Task 3: Create General Bugs Status Tracker

**Files:**
- Create: `claude/project-work/bugs/status.md`

**Step 1: Create the directory and file**

```bash
mkdir -p claude/project-work/bugs
```

Write `claude/project-work/bugs/status.md`:

```markdown
# General Bugs — Status Tracker

> **Last updated:** YYYY-MM-DD

---

## Bug Reports

_Bugs not tied to a specific feature. Status flow:
Open → Investigating → Fix In Progress → Resolved._

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| | | | | | | |

---

## Notes

_Free-form notes or context about general bugs._
```

**Step 2: Verify the file exists**

Run: `cat claude/project-work/bugs/status.md | head -5`
Expected: Shows the `# General Bugs` header.

**Step 3: Commit**

```bash
git add claude/project-work/bugs/status.md
git commit -m "feat(workflow): add general bugs status tracker"
```

---

### Task 4: Add Bug Workflow Section to AGENTS.md

**Files:**
- Modify: `claude/AGENTS.md:659` (after Phase 6 Completion `---` separator, before Template Flow)

**Step 1: Insert the Bug Workflow section**

Insert the following between the `---` on line 659 and `## Template Flow` on line 661:

```markdown

## Bug Workflow

A parallel track to the feature pipeline for reporting and resolving bugs.
Lighter-weight: no PRD, no architecture team. Bugs found during feature
testing live inside the feature workspace. General bugs get a standalone
workspace.

```
┌──────────────┐    ┌────────────────────────┐    ┌────────────────────┐
│  TRIAGE       │───▶│  DIAGNOSE (team)        │───▶│  FIX & VERIFY      │
│  (Phase 1)    │    │  (Phase 2)              │    │  (Phase 3)         │
└──────────────┘    └────────────────────────┘    └────────────────────┘
 Orchestrator        TeamCreate → relevant        Solo expert fixes,
 reads report,       experts investigate          game-tester verifies
 selects agents
```

### Bug Report Submission

Anyone (user or game-tester) can submit a bug using `claude/templates/bug-report.md`.

**Feature bugs:** Copy template to `project-work/<feature>/bugs/BUG-NNN-short-name/report.md`
**General bugs:** Copy template to `project-work/bugs/BUG-GNNN-short-name/report.md`

Create the bug workspace:
```bash
mkdir -p claude/project-work/<feature>/bugs/BUG-NNN-short-name/{diagnosis,fix}
# or for general bugs:
mkdir -p claude/project-work/bugs/BUG-GNNN-short-name/{diagnosis,fix}
```

### Phase 1: Triage (orchestrator)

The orchestrator reads the bug report and:

1. **Sets severity** if not already specified by the submitter.
2. **Selects expert agents relevant to the bug.** The Affected Systems
   checklist in the report determines which agents are needed:
   - C++ server source → c-expert
   - Lua quest scripts → lua-expert
   - Perl quest scripts → perl-expert
   - Database / SQL → data-expert
   - Rules / Configuration → config-expert
   - Client protocol → protocol-agent
   - Infrastructure / Docker → infra-expert
   - Multiple systems → multiple experts
   - Unclear root cause → start with systematic-debugging skill to narrow
     down, then assign the relevant expert(s)
3. **Evaluates complexity.** Trivial bugs (wrong rule value, typo, obvious
   one-line fix) skip diagnosis and go directly to a solo expert fix.
4. **Updates status.md** — adds a row to the Bug Reports table with status
   `Investigating` and the assigned expert agents.
5. **Creates the bug workspace** — folder, report.md, diagnosis/ and fix/
   directories.

### Phase 2: Diagnose (small team)

A team of expert agents relevant to the bug is spawned via TeamCreate.
The team composition is determined during triage based on the bug's
Affected Systems — only agents whose expertise matches the bug are included.

```
TeamCreate(team_name="<feature>-bug-NNN", description="Diagnose BUG-NNN")
  → Task(name="<expert-1>", team_name=...) + Task(name="<expert-2>", ...)
  → Agents investigate root cause
  → Findings written to diagnosis/ in the bug workspace
  → Inter-agent discussion logged to agent-conversations.md
  → SendMessage(type="shutdown_request") to each agent
  → TeamDelete
```

The team:
- Reads the bug report
- Investigates root cause using the systematic-debugging approach
- Writes findings to `diagnosis/` in the bug workspace
- Identifies the fix (which files, what changes)

### Phase 3: Fix & Verify

- The expert identified during diagnosis implements the fix (commits on
  the feature branch or relevant branch)
- Status.md row updated to `Fix In Progress`
- Game-tester runs the reproduction steps to confirm the fix
- Status.md row updated to `Resolved` with the date

### Trivial Bug Shortcut

For bugs where triage determines the fix is obvious:

```
Triage → Solo expert fixes → Game-tester verifies
```

No team spawn, no diagnosis artifacts. The orchestrator makes this call.

### Bug Status Flow

```
Open → Investigating → Fix In Progress → Resolved
```

Tracked in the feature's `status.md` Bug Reports table (feature bugs)
or `project-work/bugs/status.md` (general bugs).

---
```

**Step 2: Verify the section appears**

Run: `grep -n "Bug Workflow" claude/AGENTS.md`
Expected: Shows the line number of the new section header.

**Step 3: Commit**

```bash
git add claude/AGENTS.md
git commit -m "feat(workflow): add Bug Workflow section to AGENTS.md"
```

---

### Task 5: Update CLAUDE.md Orchestrator Instructions

**Files:**
- Modify: `claude/CLAUDE.md` — add bug workflow to the orchestrator's responsibilities

**Step 1: Add bug triage to the "orchestrator DOES" list**

In the `### The orchestrator DOES:` section, add after the existing items:

```markdown
- Triage bug reports (read report, set severity, select relevant expert agents)
- Create bug workspaces and update Bug Reports tables in status.md
```

**Step 2: Add bug workflow to the Feature Workflow Summary**

After the existing pipeline in `## Feature Workflow Summary`, add:

```markdown
### Bug Workflow Summary

Bugs follow a lighter pipeline. The orchestrator triages and selects
expert agents relevant to the bug based on its Affected Systems checklist.

```
1. Triage     → orchestrator (read report, select experts, create workspace)
2. Diagnose   → TeamCreate → relevant experts investigate root cause
3. Fix/Verify → solo expert fixes, game-tester verifies
```

Trivial bugs skip diagnosis: Triage → solo expert → game-tester.
```

**Step 3: Commit**

```bash
git add claude/CLAUDE.md
git commit -m "feat(workflow): add bug workflow to orchestrator instructions"
```
