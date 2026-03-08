# companion-ai-stances — Dev Notes: Lua Expert

> **Feature branch:** `feature/companion-ai-stances`
> **Agent:** lua-expert
> **Task(s):** #6 (Task 6 from architecture.md)
> **Date started:** 2026-03-08
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 6 | Update `cmd_passive` in `companion.lua` to call `WipeHateList()` | — (independent) | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | 735 | `cmd_passive` at line 447-450. Currently calls `SetStance(0)` and `Say()` only. No hate list clear. |
| `claude/project-work/feature/companion-ai-stances/architect/architecture.md` | 404 | Lua Changes section specifies exactly: add `npc:WipeHateList()` after `SetStance(0)`. Notes WipeHateList() is already in Lua_Mob bindings. |

### Key Findings

- `cmd_passive` is at line 447–450 in companion.lua.
- Architecture doc specifies the exact change: add `npc:WipeHateList()` after `npc:SetStance(0)`.
- `WipeHateList()` is confirmed available via `Lua_Mob` bindings (architecture doc "Compatibility Risks" section).
- `cmd_balanced` and `cmd_aggressive` require no Lua-side changes — no hate list manipulation needed on stance transition to those stances.
- This task is independent — no dependency on c-expert tasks.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modify | Add `npc:WipeHateList()` between `SetStance(0)` and `Say()` in `cmd_passive` |

**Change sequence:**
1. Add `npc:WipeHateList()` to `cmd_passive` at line 449.

**What to test:**
- Switch to passive while companion is in combat — companion should immediately disengage (belt-and-suspenders with C++ Companion::Process() which also clears hate list)

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `npc:WipeHateList()` | architecture.md "Compatibility Risks" section | Yes | "WipeHateList() is already exposed via the Lua_Mob bindings (lua_mob.cpp)" — confirmed by architect |

### Plan Amendments

Plan confirmed — no amendments needed.

### Verified Plan

See Implementation Plan above — confirmed by research.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| team-lead | Task 6 is independent per architecture.md | No cross-agent coordination needed |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| team-lead | Dispatched as independent parallel task | Proceeded directly to build |

### Consensus Plan

This task is independent per the architecture doc (Task 6 — no dependencies). The change is a single line addition. No cross-agent consultation required before building.

**Agreed approach:** Add `npc:WipeHateList()` to `cmd_passive` in companion.lua.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modify | Add `npc:WipeHateList()` at line 449 |

**Change sequence (final):**
1. Add `npc:WipeHateList()` between `npc:SetStance(0)` and `npc:Say(...)` in `cmd_passive`.

---

## Stage 4: Build

### Implementation Log

#### 2026-03-08 — Add WipeHateList() to cmd_passive

**What:** Added `npc:WipeHateList()` between `npc:SetStance(0)` and `npc:Say("I will stand down.")` in `companion.cmd_passive`.

**Where:** `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion.lua`, lines 447–451.

**Why:** When a player issues `!passive`, the companion should immediately disengage from any ongoing combat. `SetStance(0)` marks the stance, but without clearing the hate list the companion continues attacking its current target until the C++ `Companion::Process()` tick clears it (~100ms later). `WipeHateList()` provides immediate Lua-side disengagement. The C++ side also clears the hate list in `Companion::Process()` on every tick when stance is passive — this is the belt-and-suspenders guarantee from the architecture doc.

**Notes:** `cmd_balanced` and `cmd_aggressive` do not need hate list manipulation — switching to those stances does not require clearing existing hate entries (the companion should continue fighting if already engaged).

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| None | — | — |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modified | Added `npc:WipeHateList()` to `cmd_passive` at line 449 |

---

## Open Items

- None.

---

## Context for Next Agent

Task 6 is complete. The only Lua change for this feature was adding `npc:WipeHateList()` to `cmd_passive` in companion.lua. The c-expert's changes to `Companion::Process()` (Task 4) also clear the hate list every tick when in passive stance — so there is redundancy by design. Lua changes require no build or restart; `#reloadquests` in-game picks them up immediately.
