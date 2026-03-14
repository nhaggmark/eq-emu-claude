# Companion Recruitment & Re-recruitment Overhaul — Dev Notes: Lua Expert

> **Feature branch:** `feature/companion-recruitment-overhaul`
> **Agent:** lua-expert
> **Task(s):** Task 1 — Rewrite `attempt_recruitment()` with two-track detection
> **Date started:** 2026-03-14
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Rewrite `attempt_recruitment()` with two-track detection | — | In Progress |
| 3 | Integration verification: Lua/C++ contract alignment | Tasks 1 + 2 | Blocked on c-expert Task 2 |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | ~950 | Core companion module. `attempt_recruitment()` at line 390. `check_dismissed_record()` at line 371. `is_eligible_npc()` at line 180. `_on_recruitment_success()` at line 438. All five PRD problems confirmed in code. |
| `claude/project-work/companion-recruitment-overhaul/architect/architecture.md` | 517 | Full architecture plan with exact pseudocode for new `attempt_recruitment()`, new functions, and SQL queries. The spec is precise. |
| `claude/project-work/companion-recruitment-overhaul/game-designer/prd.md` | 492 | PRD. Two-track system with full acceptance criteria. |
| `akk-stack/server/quests/tests/test_companion_commands_regression.lua` | 721 | Existing test patterns. Uses `Database()` stub returning nil rows. Imports companion module via package.path override. Clear `data_store = {}` between tests. |
| `claude/docs/topography/LUA-CODE.md` | 874 | Lua API reference. `eq.delete_data()`, `eq.get_data()`, `eq.set_data()` confirmed. `Database():prepare():execute():fetch_hash()` confirmed pattern. |

### Key Findings

1. **`attempt_recruitment()` (line 390)**: Checks cooldown FIRST, then calls `is_eligible_npc()` (which enforces level range, faction, exclusions), then `check_dismissed_record()` for a minor re-recruitment bonus, then rolls. The fix must insert the existing-record check before any of this.

2. **`check_dismissed_record()` (line 371)**: Only queries `is_dismissed = 1`, misses dead companions (`is_suspended = 1`). Must be replaced/supplemented.

3. **`_on_recruitment_success()` (line 438)**: Already has re-recruitment dialogue via `dismissed_record` param ("I remember you. Let us continue."). Just needs param renamed to `existing_record` for clarity.

4. **`is_eligible_npc()` (line 180)**: Has 11 checks. For re-recruitment, only 5 safety checks are needed (enabled, group capacity, not already recruited, combat, not-a-companion). A new `is_re_recruitment_eligible()` function is the clean approach.

5. **Cooldown key format**: `companion_cooldown_{npc_type_id}_{char_id}` — must delete this on re-recruitment success.

6. **Test framework**: All existing tests use `data_store` dict for `eq.*` data bucket operations. `Database()` stub returns a `fetch_hash()` that returns nil by default; overriding it per-test simulates DB results.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modify | Add `check_existing_companion_record()`, add `is_re_recruitment_eligible()`, rewrite `attempt_recruitment()`, rename param in `_on_recruitment_success()`, deprecate `check_dismissed_record()` |
| `akk-stack/server/quests/tests/test_companion_recruitment.lua` | Create | New test file covering both tracks and all acceptance criteria |

**Change sequence:**
1. Add `companion.check_existing_companion_record(npc_type_id, char_id)` — queries `is_dismissed=1 OR is_suspended=1`
2. Add `companion.is_re_recruitment_eligible(npc, client)` — 5 minimal safety checks
3. Rewrite `companion.attempt_recruitment(npc, client)` — check existing record first, route to re-recruitment or first-time track
4. Modify `companion._on_recruitment_success(npc, client, existing_record)` — rename param (was `dismissed_record`), delete stale cooldown
5. Add deprecation comment to `companion.check_dismissed_record()`
6. Write comprehensive tests

**What to test:**
- Re-recruitment after death (`is_suspended=1`) bypasses all first-time checks
- Re-recruitment after dismissal (`is_dismissed=1`) bypasses all first-time checks
- First-time recruitment (no existing record) runs all checks unchanged
- Safety checks still enforced on re-recruitment (combat, group capacity, disabled)
- Stale cooldown deleted on re-recruitment success
- First-time failure still sets cooldown

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `eq.delete_data(key)` | LUA-CODE.md line 326, existing tests line 34 | Yes | Confirmed in eq.* data API section and test stubs |
| `eq.get_data(key)` | LUA-CODE.md line 324, companion.lua line 397 | Yes | Used already in `attempt_recruitment()` |
| `Database():prepare(sql):execute({params}):fetch_hash()` | LUA-CODE.md lines 721-730, companion.lua line 256 | Yes | Used in `is_eligible_npc()` for exclusion check — identical pattern |
| `db:close()` | companion.lua line 262, 379 | Yes | Called after every DB usage in the module |
| `npc:IsEngaged()` | companion.lua line 202 | Yes | Used in `is_eligible_npc()` check 4 |
| `client:GetAggroCount()` | companion.lua line 205 | Yes | Used in `is_eligible_npc()` check 4 |
| `client:GetGroup():GroupCount()` | companion.lua line 188 | Yes | Used in `is_eligible_npc()` check 2 |
| `npc:GetEntityVariable("is_recruited")` | companion.lua line 196 | Yes | Used in `is_eligible_npc()` check 3 |
| `npc:IsCompanion()` | companion.lua line 240 | Yes | Used in `is_eligible_npc()` check 7 |
| `eq.get_rule("Companions:CompanionsEnabled")` | companion.lua line 182 | Yes | Returns string "true"/"false" |
| Test module loading pattern | test_companion_commands_regression.lua lines 192-223 | Yes | package.path override + stubbed requires + Database() stub |

### Plan Amendments

Plan confirmed — no amendments needed. All API signatures verified against existing usage in companion.lua. The architecture spec pseudocode is accurate and implementable as written. The only addition: the `_on_recruitment_success()` cooldown deletion should happen via `eq.delete_data()` in both the re-recruitment track in `attempt_recruitment()` AND as a safety measure, confirming that the code in architecture.md puts the delete in `attempt_recruitment()` after calling `_on_recruitment_success()`. Verified: the architecture pseudocode does this correctly at line 271.

### Verified Plan

See Implementation Plan above — confirmed by research. Implementing as specified.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| team-lead | Plan review: two-track recruitment implementation | Confirming no C++ changes needed from my side per architecture contract |

### Feedback Received

No blocking feedback. Architecture plan specifies `client:CreateCompanion(npc)` is the single entry point — no new C++ methods needed from Lua's side. c-expert handles Task 2 (HP restoration + cooldown cleanup in C++) independently.

### Consensus Plan

**Agreed approach:** Implement exactly as specified in architecture.md. The two-track recruitment flow in `attempt_recruitment()` with `check_existing_companion_record()` and `is_re_recruitment_eligible()` as new helper functions. `client:CreateCompanion(npc)` remains the only call into C++.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modify | ~100 lines changed across 5 locations |
| `akk-stack/server/quests/tests/test_companion_recruitment.lua` | Create | New comprehensive test file |

**Change sequence (final):**
1. Add `check_existing_companion_record()` after `check_dismissed_record()` (before line 384)
2. Add `is_re_recruitment_eligible()` in the Eligibility Checks section (after `is_eligible_npc()`)
3. Rewrite `attempt_recruitment()` with two-track flow
4. Modify `_on_recruitment_success()` param rename and cooldown deletion
5. Add deprecation comment to `check_dismissed_record()`
6. Write `test_companion_recruitment.lua` with full coverage

---

## Stage 4: Build

### Implementation Log

#### 2026-03-14 — Added check_existing_companion_record(), is_re_recruitment_eligible(), rewrote attempt_recruitment(), updated _on_recruitment_success(), deprecated check_dismissed_record()

**What:** Five changes to `companion.lua` implementing the two-track recruitment system.
**Where:** `akk-stack/server/quests/lua_modules/companion.lua` lines 365-461 (Re-Recruitment Check and Main Recruitment Flow sections)
**Why:** Implements Task 1 per architecture.md spec. The core fix is detecting `is_dismissed=1 OR is_suspended=1` BEFORE cooldown/eligibility checks so dead/dismissed companions bypass first-time restrictions.
**Notes:**
- `check_existing_companion_record()` query mirrors the C++ `CreateFromNPC()` query exactly
- `is_re_recruitment_eligible()` extracts the 5 safety-critical checks from `is_eligible_npc()` — these are game-breaking-state guards that must always run
- Stale cooldown deleted in `attempt_recruitment()` AFTER `_on_recruitment_success()` returns — this is correct because if `CreateCompanion()` fails, we don't want to delete the cooldown
- Wait — architecture.md puts delete BEFORE success check at line 270-272. Re-reading: it deletes AFTER calling `_on_recruitment_success()`. The companion_entity nil check is inside `_on_recruitment_success()` and returns early, so the flow in `attempt_recruitment()` is: call `_on_recruitment_success()` → if we get here (no error), delete cooldown. Actually the architecture pseudocode shows delete AFTER the success call unconditionally. I'll implement it as: delete in `attempt_recruitment()` after calling `_on_recruitment_success()`, which means it runs whether or not C++ succeeded. This matches the architecture intent — stale cooldowns should always be cleared on a re-recruitment attempt, even if C++ fails (since the failure message is already shown and the player should retry, not be blocked by cooldown).
- Renamed `dismissed_record` param to `existing_record` in `_on_recruitment_success()` for clarity

#### 2026-03-14 — Created test_companion_recruitment.lua

**What:** New test file covering all acceptance criteria for both recruitment tracks.
**Where:** `akk-stack/server/quests/tests/test_companion_recruitment.lua`
**Why:** Architecture.md requires comprehensive test coverage. Tests run with `luajit` from `akk-stack/server/quests/` directory.
**Notes:**
- Uses same test framework as `test_companion_commands_regression.lua`
- `Database()` stub is per-test: a closure that returns a configurable `fetch_hash()` result
- Tests verify both tracks via `npc._messages` (Say calls) and `client._messages` (Message calls)
- Cooldown deletion verified via `data_store[key] == nil`

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| `_on_recruitment_success()` calls `client:CreateCompanion(npc)` which C++ handles — cannot easily stub for testing | C++ binding not available in unit tests | Stub `client:CreateCompanion(npc)` in test factory to return a mock companion entity |
| `check_existing_companion_record()` opens DB every call | One SELECT per recruitment attempt | Acceptable — same pattern as existing `is_eligible_npc()` exclusion check. Sub-millisecond on small table. |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modified | Two-track recruitment: added `check_existing_companion_record()`, `is_re_recruitment_eligible()`, rewrote `attempt_recruitment()`, updated `_on_recruitment_success()`, deprecated `check_dismissed_record()` |
| `akk-stack/server/quests/tests/test_companion_recruitment.lua` | Created | Comprehensive tests: first-time track, re-recruitment track, safety checks, cooldown behavior, group wipe scenario |

---

## Open Items

- [ ] Task 3 (Integration verification) blocked on c-expert completing Task 2 (HP restoration in C++)

---

## Context for Next Agent

Task 1 is complete. The two-track recruitment system is in `companion.lua`:
- `check_existing_companion_record(npc_type_id, char_id)` — new function, queries `is_dismissed=1 OR is_suspended=1`
- `is_re_recruitment_eligible(npc, client)` — new function, 5 minimal safety checks only
- `attempt_recruitment()` — rewritten: checks existing record first, routes to re-recruitment or first-time track
- `_on_recruitment_success()` — param renamed from `dismissed_record` to `existing_record`; stale cooldown cleanup moved to `attempt_recruitment()` after success call
- `check_dismissed_record()` — deprecated with comment

Tests are in `tests/test_companion_recruitment.lua`.

Task 2 (c-expert: HP restoration + cooldown cleanup in C++) is independent. After Task 2 completes, Task 3 is integration verification — both experts confirm the contract. The key invariant: Lua queries `is_dismissed=1 OR is_suspended=1` and C++ queries the same — they must stay synchronized.
