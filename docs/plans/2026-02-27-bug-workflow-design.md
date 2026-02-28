# Bug Workflow Design

> **Date:** 2026-02-27
> **Status:** Approved

---

## Overview

A formal bug reporting and resolution workflow that runs parallel to the
feature pipeline. Supports bugs found during feature testing (co-located with
the feature) and general server bugs (standalone workspace). Lighter-weight
than the feature workflow — no PRD, no architecture team, no lore-master
unless the bug touches lore.

## Bug Report Template

Lives at `claude/templates/bug-report.md`. Used by both humans and the
game-tester agent.

Fields: severity, reporter, date, feature reference, status, observed vs
expected behavior, reproduction steps, evidence, and affected systems
checklist.

## Bug Workspaces

### Feature bugs

```
project-work/<feature>/bugs/BUG-NNN-short-name/
├── report.md       ← filled-in bug-report template
├── diagnosis/      ← investigation notes, root cause analysis
└── fix/            ← fix plan, verification notes
```

Numbered sequentially per feature: BUG-001, BUG-002, etc.

### General bugs

```
project-work/bugs/
├── status.md       ← general bug status tracker
├── BUG-G001-short-name/
│   ├── report.md
│   ├── diagnosis/
│   └── fix/
```

Prefixed with `G` to avoid collisions: BUG-G001, BUG-G002, etc.

## Status Tracking

Bugs are tracked in the feature's existing `status.md` via a new "Bug Reports"
table section:

```markdown
## Bug Reports

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| BUG-001 | [Title](bugs/BUG-001-name/report.md) | High | user | Open | | |
```

Status flow: `Open` → `Investigating` → `Fix In Progress` → `Resolved`

General bugs use the same table format in `project-work/bugs/status.md`.

## Bug Pipeline

```
┌──────────┐    ┌──────────────────────┐    ┌──────────────────┐
│  TRIAGE   │───▶│  DIAGNOSE (team)      │───▶│  FIX & VERIFY    │
│           │    │                      │    │                  │
└──────────┘    └──────────────────────┘    └──────────────────┘
 Orchestrator     TeamCreate → experts       Solo expert fixes,
 reads report,    investigate root cause     game-tester verifies
 selects agents
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
4. **Updates status.md** — adds a row with status `Investigating` and the
   assigned agents.
5. **Creates the bug workspace** — folder, report.md, diagnosis/ and fix/
   directories.

### Phase 2: Diagnose (small team)

A team of 2-3 expert agents relevant to the bug is spawned via TeamCreate.
They:

- Read the bug report
- Investigate root cause using the systematic-debugging approach
- Write findings to `diagnosis/` in the bug workspace
- Identify the fix (which files, what changes)
- Log inter-agent discussion to the feature's `agent-conversations.md`

Team is shut down after diagnosis is complete.

### Phase 3: Fix & Verify

- The expert identified as the fixer implements the change (commits on the
  feature branch or the relevant branch)
- Status moves to `Fix In Progress`
- Game-tester runs the reproduction steps to confirm the fix
- Status moves to `Resolved` with the date

### Shortcut: Trivial Bugs

Triage → solo expert fixes directly → game-tester verifies. No team spawn,
no diagnosis artifacts needed. The orchestrator makes this call during triage.

## What Changes

| File | Change |
|------|--------|
| `claude/templates/bug-report.md` | New file — bug submission template |
| `claude/templates/status.md` | Add Bug Reports table section |
| `claude/AGENTS.md` | Add Bug Workflow section documenting the pipeline |
| `claude/project-work/bugs/status.md` | New file — general bugs tracker |

## What Doesn't Change

- No new agent definitions — existing experts + systematic-debugging skill
- Bootstrap-agent unchanged — bugs don't need bootstrapping
- Feature workflow unchanged — bugs are a parallel track
