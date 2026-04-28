# Companion Re-recruitment Fix — Dev Notes: lua-expert

> **Feature branch:** `bugfix/companion-rerecruit`
> **Agent:** lua-expert
> **Task(s):** Lua-side triage (architecture phase) + implementation tasks (implementation phase)
> **Date started:** 2026-04-27
> **Current stage:** Stage 3 — Socialized (architecture locked; awaiting implementation phase dispatch)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| Triage | Trace recruit flow in Lua; report to architect | None | Complete |
| L-1 | Add 2 failing TDD tests to `test_companion_recruitment.lua` BEFORE fix | Arch locked | Pending |
| L-2 | Fix `companion.lua:1434` — `Dismiss(true)` → `Dismiss(false)` | L-1 tests written | Pending |
| L-3 | Fix `companion.lua:15` — invert doc comment parameter semantics | L-2 | Pending |
| L-4 | Fix `companion.lua:207` — LevelRange fallback `or 3` → `or 50` | L-2 | Pending |
| L-5 | Fix `companion.lua:394-397` — add `ORDER BY level DESC, experience DESC, id DESC` to re-recruit query | L-2 | Pending |

**ORDER BY rationale (architect decision):** `level DESC, experience DESC` picks the row with the most player investment (not the most recently inserted row). `id DESC` as the final tiebreaker handles equal-level/equal-XP duplicates deterministically. C++ query at `companion.cpp:218` intentionally left without ORDER BY (future work — requires build cycle).

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `global/global_npc.lua` | ~712 | Entry point: dispatches to `companion_lib.attempt_recruitment(npc, client)` on recruitment keyword; `companion_lib.dispatch_prefix_command` for `!` commands |
| `lua_modules/companion.lua` | ~1475 | Core: all recruitment logic including two-track system, cooldown, level check, dismiss/suspend detection |
| `lua_modules/client_ext.lua` | ~340 | No recruitment logic; helper methods on Client class |
| `lua_modules/llm_bridge.lua` | N/A (partial scan) | No recruitment logic; only LLM-hostile cooldowns via entity variables |
| `tests/test_companion_recruitment.lua` | ~1001 | Comprehensive LuaJIT test suite for recruitment (38+ tests) |
| `tests/test_companion_rerec_edge_cases.lua` | ~346 | Edge-case tests for SQL and DB-nil guards |

### Key Findings

#### The recruit flow — complete trace

1. Player says a recruitment keyword to a non-companion NPC
2. `global/global_npc.lua:event_say()` (line 21) calls `companion_lib.is_recruitment_keyword(e.message)` — returns true
3. `global/global_npc.lua:event_say()` (line 22) calls `companion_lib.attempt_recruitment(e.self, e.other)` and returns
4. `companion.lua:attempt_recruitment()` (line 454):
   - Builds `cooldown_key = "companion_cooldown_" .. npc_type_id .. "_" .. char_id`
   - **RE-RECRUITMENT TRACK** (line 462): calls `check_existing_companion_record(npc_type_id, char_id)` — queries `companion_data WHERE owner_id=? AND npc_type_id=? AND (is_dismissed=1 OR is_suspended=1) LIMIT 1`
     - If record found → `is_re_recruitment_eligible(npc, client)` (minimal checks: enabled, group capacity, not-already-recruited, combat, not-a-Companion-instance) → `_on_recruitment_success(npc, client, existing_record)` → `client:CreateCompanion(npc)` (C++ call)
     - Stale cooldown deleted via `eq.delete_data(cooldown_key)` on re-recruit success
   - **FIRST-TIME TRACK** (line 479): checks cooldown via `eq.get_data(cooldown_key)` → full 11-check `is_eligible_npc()` including level range → persuasion roll → success or `_on_recruitment_failure` (sets cooldown)

#### Three blockers — Lua layer status

**Blocker 1 — Level check (Companions:LevelRange)**
- **Location:** `companion.lua:207-213` inside `is_eligible_npc()`
- **Rule used:** `eq.get_rule("Companions:LevelRange")` — returns string, cast to tonumber, default 3
- **Status:** Already bypassed for re-recruitment. The level check is in `is_eligible_npc()` which is ONLY called on the first-time track. `is_re_recruitment_eligible()` (line 409) does NOT include a level check.
- **Conclusion:** If the level blocker is firing, it means `check_existing_companion_record()` is returning nil when it should be returning a row. The Lua fix is already in place — the C++ or DB layer is the culprit.

**Blocker 2 — Cooldown (data_buckets)**
- **Location:** `companion.lua:479-482` — `eq.get_data(cooldown_key)` on first-time track only
- **Key pattern:** `companion_cooldown_{npc_type_id}_{char_id}` — confirmed at line 457
- **Status:** Already bypassed for re-recruitment. The cooldown check is ONLY on the first-time track. Re-recruitment track at line 464 runs before the cooldown check at line 479.
- **MEMORY.md reference confirms:** key pattern `companion_cooldown_{npc_type_id}_{char_id}` matches current code exactly (not stale).
- **Conclusion:** Same as Blocker 1 — if cooldown is blocking, `check_existing_companion_record()` returned nil. The Lua layer is already correct.

**Blocker 3 — Dismissed flag (is_dismissed=1)**
- **Location:** `companion.lua:390-402` — `check_existing_companion_record()` queries `is_dismissed=1 OR is_suspended=1`
- **Status:** Already handled. The query covers both dead (is_suspended=1) and dismissed (is_dismissed=1) states. The deprecated `check_dismissed_record()` (line 371) which only checked `is_dismissed=1` is no longer called from `attempt_recruitment()`.
- **Conclusion:** Lua layer correctly detects both dismiss states. If the flag is blocking, the problem is that the C++ `CreateCompanion` does not call `Unsuspend()` / clear flags after detecting the record, OR the DB record is not being found (query mismatch with how C++ writes the flags).

#### Root cause hypothesis

All three Lua-side bypasses are already correctly implemented. The two-track system (re-recruit vs. first-time) is already in the code. **The likely failure point is one of:**

1. `check_existing_companion_record()` returns nil when the player re-recruits — meaning the DB query does not find the record. This routes to the first-time track which enforces all blockers.
   - Possible cause: C++ writes flags to a different column name, or does not set `is_suspended=1` on death, or `is_dismissed` is cleared before Lua can read it.
2. `client:CreateCompanion(npc)` silently fails or re-applies restrictions inside C++ even after the Lua two-track bypass succeeds.

#### Cooldown key pattern — verified

`companion.lua:457`: `"companion_cooldown_" .. npc_type_id .. "_" .. char_id`

This matches MEMORY.md exactly. The key uses live values (not character_id=0). MEMORY.md note about `character_id=0` in the `data_buckets` table refers to how the EQEmu engine stores `data_buckets` rows — the character_id column is 0 but the key string encodes the real char_id. This is consistent.

#### Test harness — EXISTS

Location: `/mnt/d/Dev/eq/akk-stack/server/quests/tests/`

Relevant files:
- `test_companion_recruitment.lua` — 38+ tests covering both tracks, all blockers, edge cases
- `test_companion_rerec_edge_cases.lua` — SQL edge cases and DB-nil guards

Run command: `luajit tests/test_companion_recruitment.lua` from `akk-stack/server/quests/`

**Blocker:** `luajit` is not installed as a system command. It exists only inside the vcpkg build tree at `eqemu/build/vcpkg_installed/x64-linux/share/luajit`. The tests need either a `luajit` symlink or to be run inside the Docker container where the server binary's embedded LuaJIT is accessible. The architect should confirm the test execution method.

**TDD implication:** The existing test suite already covers the invariant. New tests for the specific bug scenarios (Lydl-style level gap, immediate post-death re-recruit) should be added to `test_companion_recruitment.lua` before implementing any fix.

#### `llm_bridge.lua` — not involved

Scanned for `recruit` and `cooldown` patterns. `llm_bridge.lua` only manages LLM-hostile cooldowns via NPC entity variables (`llm_cd_<char_id>`). No recruitment logic touches it.

#### `client_ext.lua` — not involved

Utility extensions on the `Client` class. No recruitment logic.

### Implementation Plan

**No implementation in this phase.** This is triage. The current state is:

- Lua layer: two-track bypass system is ALREADY implemented and correct
- The bug is likely in the C++ `CreateCompanion` path or the DB record not being detected
- The architect needs to verify whether C++ correctly sets `is_suspended=1` on companion death, and whether `CreateCompanion` respects the re-recruit track without re-applying level rules

**If a Lua fix IS needed** (architect determines `check_existing_companion_record()` is returning nil due to a query mismatch):
- Fix target: `companion.lua:390-402` — the SQL query for `check_existing_companion_record()`
- Fix would be: adjust the WHERE clause column names to match what C++ actually writes

**If tests need additions for TDD (PRD AC-9):**
- File: `tests/test_companion_recruitment.lua`
- Add: test cases for Lydl scenario (level 12 companion, level 35 player), immediate post-death re-recruit, immediate post-dismiss re-recruit — these may already be covered but should be verified against the failing production scenario

---

## Stage 2: Research

Not needed for triage phase. API patterns verified by direct source reading.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Initial triage: two-track bypass already correct | What sets is_suspended/is_dismissed in C++? |
| architect | Full 7-question response + cmd_dismiss SoulWipe discovery | Is Dismiss(true) the dismiss blocker root cause? |
| architect | Follow-up: 4 live-data questions answered | Does C++ re-find independently? Duplicate row risk? |
| architect | Final follow-ups: test gap, Dismiss(true) only site, ORDER BY rec | All confirmed — architecture locked |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| architect | Root cause confirmed: `cmd_dismiss` → `Dismiss(true)` = SoulWipe | Recorded in implementation tasks |
| architect | LevelRange fallback `or 3` → `or 50` hardening | Added as task L-4 |
| architect | TDD: 2 failing tests before fix (test Dismiss arg) | Added as task L-1 |
| architect | `!dismiss permanent` out of scope; `!dismiss` always calls `Dismiss(false)` | Confirmed; no `permanent` path from Lua |
| architect | ORDER BY: use `level DESC, experience DESC, id DESC` not `id DESC` — picks highest-investment row, not most-recently-inserted | Updated task L-5 |

### Consensus Plan

**Architecture locked 2026-04-27.**

The three PRD blockers (level range, cooldown, dismissed flag) all cascade from a single root cause: `cmd_dismiss` calling `Dismiss(true)` (permanent SoulWipe) instead of `Dismiss(false)` (voluntary, preserves record). The two-track bypass system in `attempt_recruitment()` is already correct — it simply never fires because the record is deleted before re-recruitment.

**Agreed approach:** Fix `cmd_dismiss` to call `Dismiss(false)`. Add TDD tests first that assert the argument value. Add belt-and-suspenders hardening for LevelRange fallback and ORDER BY determinism.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/tests/test_companion_recruitment.lua` | Modify | Add 2 failing TDD tests asserting `cmd_dismiss` calls `Dismiss(false)` |
| `akk-stack/server/quests/lua_modules/companion.lua` | Modify | 4 targeted changes: line 1434 fix, line 15 doc, line 207 fallback, line 394 ORDER BY |

**Change sequence (final):**
1. Write 2 failing tests to `test_companion_recruitment.lua` (L-1) — tests must fail against current code
2. Apply one-character fix at `companion.lua:1434` (L-2) — tests now pass
3. Fix doc comment at `companion.lua:15` (L-3)
4. Fix LevelRange fallback `or 3` → `or 50` at `companion.lua:207` (L-4)
5. Add `ORDER BY level DESC, experience DESC, id DESC` to re-recruit query at `companion.lua:394` (L-5)
6. Verify all existing tests still pass
7. Commit to `bugfix/companion-rerecruit` in akk-stack and claude repos

---

## Stage 4: Build

**Started:** 2026-04-27
**Status:** Complete

### Pre-fix baseline

Ran `make test-companion` against unmodified code — 53 tests pass (45 main + 8 edge cases), 0 fail.

### Step A: Failing TDD tests (Task 2 / architecture task 2)

Added 5 tests to `akk-stack/server/quests/tests/test_companion_recruitment.lua` before the fix:

| Test | What it asserts | Why it fails pre-fix |
|------|-----------------|----------------------|
| TDD-1 | `cmd_dismiss` calls `Dismiss(false)` | cmd_dismiss calls `Dismiss(true)` today |
| TDD-2 | `Dismiss` called once with `permanent=false` | same — permanent=true today |
| TDD-3 | After cmd_dismiss(false), DB row preserved → Track 1 fires | Dismiss(true) = SoulWipe = no row |
| TDD-4 | LevelRange fallback=50: 4-level gap allowed | fallback=3 blocks 4-level gap today |
| TDD-5 | SQL includes `ORDER BY` for deterministic row selection | no ORDER BY in current query |

Pre-fix result: **45 pass, 5 fail** (exactly the 5 new TDD tests).

Committed: `akk-stack` commit `76e6753`
Pushed to `origin/bugfix/companion-rerecruit`

### Step B: Fix (Tasks 3, 4, 5 / architecture tasks 3, 4, 5)

Four changes to `akk-stack/server/quests/lua_modules/companion.lua`:

1. **Line 15** — doc comment: `companion:Dismiss(voluntary_bool)` corrected to `companion:Dismiss(permanent)` with accurate semantics (false=preserve, true=SoulWipe)
2. **Line 207** — LevelRange fallback: `or 3` → `or 50`
3. **Lines 394-397** — re-recruit query: added `ORDER BY level DESC, experience DESC, id DESC` before `LIMIT 1`
4. **Line 1434** — root-cause fix: `npc:Dismiss(true)` → `npc:Dismiss(false)`

Committed: `akk-stack` commit `ad79630`
Pushed to `origin/bugfix/companion-rerecruit`

### Step C: Post-fix verification (Task 6 / architecture task 6)

Ran `make test-companion` after the fix:

```
=== Results: 50 passed, 0 failed ===
All tests passed.
--- test_companion_rerec_edge_cases.lua ---
8 passed, 0 failed
```

Total: **58 tests pass, 0 fail.** All 5 TDD tests green. All 53 prior tests still green. No regressions.

### Architecture deviations

None. All 4 changes match architecture.md exactly:
- Line 1434: `Dismiss(true)` → `Dismiss(false)` ✓
- Line 15: doc comment corrected ✓
- Line 207: `or 3` → `or 50` ✓
- Lines 394-397: ORDER BY added ✓
- 5 TDD tests written before fix ✓

---

## Open Items

- [ ] Architect to confirm whether C++ sets `is_suspended=1` correctly on companion death (key question — if it does not, `check_existing_companion_record()` returns nil and routes to first-time track, firing all three blockers)
- [ ] Architect to confirm test execution method for `luajit` (Docker exec vs. host binary vs. installed luajit)
- [ ] If DB query is the fix target: architect to provide the exact column names C++ writes on death/dismiss
- [ ] TDD: new tests should be written before any fix — which PRD test scenarios are not yet covered in the existing suite?

---

## Context for Next Agent

The Lua re-recruitment system is a **two-track dispatch in `companion.lua:attempt_recruitment()`**.

Track 1 (re-recruit): checks `companion_data WHERE owner_id=? AND npc_type_id=? AND (is_dismissed=1 OR is_suspended=1)` — if found, bypasses cooldown, level range, faction, and persuasion roll; calls `client:CreateCompanion(npc)` directly.

Track 2 (first-time): if no DB record found, runs full 11-check eligibility + persuasion roll.

**All three PRD blockers are already bypassed in Lua for Track 1.** The bug is almost certainly that Track 1 is not being triggered — meaning `check_existing_companion_record()` returns nil when it should return a row. Root cause is likely in C++ (companion death not setting `is_suspended=1`) or a DB schema mismatch.

Test suite exists at `akk-stack/server/quests/tests/`. LuaJIT must be run inside the Docker container or via a local build.
