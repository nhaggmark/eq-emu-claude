# Companion Authenticity Fixes — Dev Notes: lua-expert

> **Feature branch:** `feature/companion-authenticity-fixes`
> **Agent:** lua-expert
> **Task:** Lua tests — recruitment overhaul edge cases and regression (Task #2)
> **Date started:** 2026-03-14
> **Current stage:** Build (Stage 4)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Lua tests: recruitment overhaul edge cases and regression | — | Complete |

---

## Stage 1: Plan

### Context

The two-track companion recruitment overhaul was implemented on
`feature/companion-recruitment-overhaul` (commit 5544ec5). The current branch
(`feature/companion-authenticity-fixes`) does NOT have those changes.
Task #2 requires:
1. Bringing the overhaul changes to this branch
2. Expanding the 35 existing tests with additional edge cases

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `akk-stack/server/quests/lua_modules/companion.lua` (current) | ~1100 | Missing `check_existing_companion_record()`, `is_re_recruitment_eligible()`, and updated `attempt_recruitment()` |
| `5544ec5:server/quests/lua_modules/companion.lua` (overhaul) | 1472 | Has all new functions; `attempt_recruitment()` rewrote with two-track logic |
| `5544ec5:server/quests/tests/test_companion_recruitment.lua` | 793 lines | 35 tests — covers core paths but missing 9 specific edge cases |

### Key Findings

- The overhaul commit adds `check_existing_companion_record()` which queries for
  `is_dismissed=1 OR is_suspended=1` (vs the old `check_dismissed_record()` which
  only checked `is_dismissed=1`)
- `is_re_recruitment_eligible()` is a new minimal-safety-check subset of
  `is_eligible_npc()` — skips level range, faction, exclusions, persuasion
- `attempt_recruitment()` now checks for existing record FIRST (before cooldown check),
  routing to re-recruitment track if found
- Stale cooldown `eq.delete_data()` happens AFTER `_on_recruitment_success()` in the
  re-recruitment track
- `check_dismissed_record()` deprecated but kept for backward compat

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modify | Apply overhaul diff: add `check_existing_companion_record()`, `is_re_recruitment_eligible()`, rewrite `attempt_recruitment()` |
| `akk-stack/server/quests/tests/test_companion_recruitment.lua` | Create | 35 base tests + 9 new edge case tests = 44 total |

**Missing edge cases to add:**
1. Re-recruitment when `cur_hp=0` in DB row (Lua proceeds, C++ handles HP)
2. `is_suspended=1 AND is_dismissed=1` simultaneously (both flags set — still re-recruits)
3. Re-recruitment ignores faction (faction=4/Amiably would block first-time but not re-recruit)
4. Re-recruitment ignores persuasion roll (math.random always returns 100 but still succeeds)
5. Re-recruitment: `is_recruited=1` entity var blocks (safety check still enforced)
6. Cooldown NOT cleaned up after first-time failure
7. Multiple companions from same npc_type_id: LIMIT 1 — first result used
8. `check_existing_companion_record()` with both flags=0 returns nil (neither dismissed nor suspended)
9. Re-recruitment: first-time NPC exclusion/bodytype checks are bypassed

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `eq.delete_data(key)` | LUA-CODE.md | Yes | Data bucket delete — verified in module |
| `eq.get_data(key)` | LUA-CODE.md | Yes | Returns nil or empty string when no record |
| `eq.set_data(key, val, ttl)` | LUA-CODE.md | Yes | TTL in seconds as string |
| `Database():prepare()` / `fetch_hash()` | LUA-CODE.md | Yes | Lua_Database prepared statement pattern |
| `client:GetAggroCount()` | companion.lua source | Yes | Returns 0 when not in combat |
| `npc:IsCompanion()` | companion.lua source | Yes | Returns false for regular NPC |

### Plan Amendments

Plan confirmed — no amendments needed. The overhaul diff is clean and the test
gap analysis is complete.

---

## Stage 3: Socialize

This is a testing-only task on a standalone branch. No dependencies on other agents'
current work — the overhaul companion.lua is fully defined in the overhaul branch.
No socialization needed.

---

## Stage 4: Build

### Implementation Log

#### 2026-03-14 — Apply companion.lua overhaul to this branch

**What:** Applied the two-track recruitment diff from `feature/companion-recruitment-overhaul`
(commit 5544ec5) to the current `companion.lua`:
- Updated `check_dismissed_record()` comment to mark as DEPRECATED
- Added `check_existing_companion_record()` (queries `is_dismissed=1 OR is_suspended=1`)
- Added `is_re_recruitment_eligible()` (minimal safety checks subset)
- Rewrote `attempt_recruitment()` with two-track dispatch
- Updated `_on_recruitment_success()` parameter name: `dismissed_record` → `existing_record`

**Where:** `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion.lua` lines 365-471

**Why:** The overhaul functions are required for the tests to load and pass.
The test file calls `companion.check_existing_companion_record()` and
`companion.is_re_recruitment_eligible()` which don't exist on this branch yet.

#### 2026-03-14 — Create test_companion_recruitment.lua with full coverage

**What:** Created test file with 44 tests total:
- 35 base tests ported from overhaul branch (all existing scenarios)
- 9 new edge case tests covering the scenarios listed in Task #2

**Where:** `/mnt/d/Dev/eq/akk-stack/server/quests/tests/test_companion_recruitment.lua`

**New edge case tests added:**
1. `cur_hp=0` in DB row — Lua proceeds (C++ handles HP)
2. `is_suspended=1 AND is_dismissed=1` simultaneously — re-recruits (either flag triggers track 1)
3. Re-recruitment ignores faction below Kindly
4. Re-recruitment ignores persuasion roll (always-fail random returns 100)
5. `is_recruited=1` entity var blocks re-recruitment (safety check enforced)
6. Cooldown NOT deleted after first-time failure
7. `check_existing_companion_record()` returns nil when both flags=0
8. Multiple companions same npc_type_id: LIMIT 1 returns first (whichever DB returns)
9. Re-recruitment bypasses bodytype/exclusion checks

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modified | Two-track overhaul applied |
| `akk-stack/server/quests/tests/test_companion_recruitment.lua` | Created | 44-test suite |
