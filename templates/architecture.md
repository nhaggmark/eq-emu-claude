# [Feature Name] — Architecture & Implementation Plan

> **Feature branch:** `<branch-name>`
> **PRD:** `<link to prd.md>`
> **Author:** architect
> **Date:** YYYY-MM-DD
> **Status:** Draft | In Review | Approved

---

## Executive Summary

_One paragraph: what we're building, why, and the high-level approach._

## Existing System Analysis

_What currently exists that this feature builds on or modifies? Reference
specific files, tables, and systems from the topography docs._

### Current State

_How the relevant systems work today._

### Gap Analysis

_What's missing between current state and what the PRD requires._

## Technical Approach

### Architecture Decision

_Which layer(s) own this feature? Justify using the least-invasive-first
principle: rules > config > Lua > SQL > C++._

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| | | |

### Data Model

_New or modified tables, columns, relationships. Include SQL sketches._

### Code Changes

_Key files to modify or create, organized by subsystem._

#### C++ Changes
_Files, classes, methods affected. New classes if needed._

#### Lua/Script Changes
_New or modified quest scripts, modules, encounter scripts._

#### Database Changes
_INSERT/UPDATE statements, new table definitions._

#### Configuration Changes
_Rule values, eqemu_config.json settings._

## Implementation Sequence

_Ordered list of tasks with dependencies. Each task assigned to a specific
expert agent._

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | | | — | |
| 2 | | | 1 | |
| 3 | | | 1 | |

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| | | | |

### Compatibility Risks

_Could this break existing behavior? What needs regression testing?_

### Performance Risks

_Any concerns about database query load, zone server CPU, memory usage?_

## Review Passes

_The architect performs multiple review passes before finalizing._

### Pass 1: Feasibility
_Can we actually build this with the existing codebase? What's the hardest
part?_

### Pass 2: Simplicity
_Is this the simplest approach? Can anything be removed or deferred?_

### Pass 3: Antagonistic
_What could go wrong? Edge cases, race conditions, exploits, data
corruption scenarios. Steel-man the argument against this approach._

### Pass 4: Integration
_How do the pieces fit together? Are there ordering dependencies the
implementation team needs to know about?_

## Validation Plan

_What the game-tester agent should verify after implementation._

- [ ]
- [ ]
- [ ]

---

> **Next step:** Distribute implementation tasks to the expert agents per
> the sequence above.
