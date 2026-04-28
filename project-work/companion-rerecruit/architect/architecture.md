# Companion Re-recruitment Fix — Architecture & Implementation Plan

> **Feature branch:** `bugfix/companion-rerecruit`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-04-27
> **Status:** Approved

---

## Executive Summary

The companion re-recruitment system is **already correctly architected**. A two-track dispatch in `companion.lua:attempt_recruitment()` routes previously-recruited NPCs through `is_re_recruitment_eligible()` — a minimal-checks path that bypasses level range, faction, cooldown, and the persuasion roll — while first-time recruits go through the full `is_eligible_npc()` pipeline. The C++ side at `Companion::CreateFromNPC()` independently re-detects existing `companion_data` rows (matching `is_dismissed=1 OR is_suspended=1`), restores them via `Load()`, and atomically clears both flags.

The PRD's three named blockers (level cap, cooldown, dismissed flag) are not three independent bugs. They are **one root cause plus two cascading symptoms**: `cmd_dismiss` in `companion.lua:1434` invokes `npc:Dismiss(true)` which maps to `Companion::Dismiss(permanent=true)` → `SoulWipe()` → DELETEs the `companion_data` row entirely. With the row gone, Track 1 has nothing to find on re-recruit, falls through to Track 2, and the level/cooldown/persuasion gates fire as designed. The Lua doc comment at `companion.lua:15` documents the parameter inverted.

**The fix is a single character.** Change `Dismiss(true)` to `Dismiss(false)` at `companion.lua:1434`. Add TDD tests proving the invariant. Harden the `LevelRange` fallback. Delete one ghost duplicate row. Land a `make test-companion` target so engineers can run the existing 38-test suite via Docker.

Zero C++ changes. Zero SQL schema changes. Zero rule_values changes.

---

## Existing System Analysis

### Current State

**Recruit dispatch entry point**

```
Player /say "recruit" → global_npc.lua:event_say (line 21)
  → companion.is_recruitment_keyword(message)
  → companion.attempt_recruitment(npc, client)             [companion.lua:454]
```

**Two-track dispatch in companion.lua:attempt_recruitment()**

```
Track 1 (re-recruit):
  check_existing_companion_record(npc_type_id, char_id)    [companion.lua:462]
    → SQL: SELECT ... FROM companion_data
       WHERE owner_id=? AND npc_type_id=?
       AND (is_dismissed=1 OR is_suspended=1) LIMIT 1      [companion.lua:390-402]
    → row found:
      → is_re_recruitment_eligible(npc, client)            [companion.lua:409-443]
        → only minimal safety checks (system enabled, group
           capacity, not-already-recruited, combat, not-a-Companion)
        → NO level check, NO cooldown, NO faction, NO persuasion
      → _on_recruitment_success(npc, client, existing)     [companion.lua:514-536]
        → SetEntityVariable("is_recruited", "1")  (concurrency guard)
        → client:CreateCompanion(npc)              (C++ entry)
        → eq.delete_data(cooldown_key)             (clear stale cooldown)
        → npc:Say("I remember you. Let us continue.")

Track 2 (first-time):
  cooldown_check via eq.get_data(cooldown_key)            [companion.lua:479]
    → if set: "won't discuss joining you again so soon"
  is_eligible_npc(npc, client)                            [companion.lua:170]
    → 11 checks including level range (companion.lua:207-213)
    → message: "is too far from your level to recruit."
  persuasion_roll                                          [companion.lua:494-509]
    → success: _on_recruitment_success
    → failure: _on_recruitment_failure (sets cooldown)
```

**C++ side (independent re-detection)**

```
client:CreateCompanion(npc)
  → Lua_Client::CreateCompanion(npc_lua)                  [lua_client.cpp:3639-3681]
  → Companion::CreateFromNPC(self, npc)                   [companion.cpp:188-307]
    → Query: WHERE owner_id=? AND npc_type_id=?
       AND (is_dismissed=1 OR is_suspended=1)             [companion.cpp:215-222]
    → row found:
      → Load() restores level, XP, equipment, stats
      → SetHP(GetMaxHP())
      → m_suspended = false; m_is_dismissed = false
      → UPDATE companion_data SET is_dismissed=0, is_suspended=0
                                  WHERE id=?              [companion.cpp:259-265]
      → DataBucket::DeleteData(cooldown_key)              [companion.cpp:272-275]
      → return existing companion (Spawn handles entity list)
    → row not found:
      → INSERT new companion_data row, Load NPC defaults,
         spawn fresh
```

**Drop-out paths**

| Path | Code | Effect on companion_data |
|------|------|--------------------------|
| Death | `Companion::Death()` `companion.cpp:1881` | `is_suspended=1`, row preserved, cur_hp NOT zeroed |
| Death (Process safety net) | `companion.cpp:646-678` | Same — `is_suspended=1` written |
| Voluntary dismiss `Dismiss(false)` | `companion.cpp:2561-2564` (else branch) | Sets both flags, calls `Save()` — row preserved |
| Permanent dismiss `Dismiss(true)` | `companion.cpp:2553` (if branch) | Calls `SoulWipe()` — DELETES row |
| Zone disconnect | not traced — out of scope for this fix | unknown, default behavior assumed (suspend on logout) |
| Server restart | suspended companions correctly skipped on `SpawnCompanionsOnZone` `companion.cpp:4131-4134` | row preserved |
| Death despawn timer (after `DeathDespawnS=1800s` no resurrection) | `companion.cpp:1888-1913` | Sets BOTH `is_dismissed=1` AND `is_suspended=1`, calls Save() |

**Key data points (live DB, 2026-04-27)**

| Fact | Value |
|------|-------|
| `companion_data` total rows | 6 (all owner_id=6, character "Chelon") |
| Rows with `is_dismissed=1` | **0** (theoretical-only blocker per PRD) |
| Rows with `is_suspended=1` | 2 (Lydl id=10, ghost Hollish id=21) |
| Rows with `cur_hp=0` | 0 (death preserves cur_hp) |
| Lydl row state | id=10, level=53, is_suspended=1, is_dismissed=0, cur_hp=1504 |
| Stale cooldown rows in `data_buckets` | 0 |
| `companion_exclusions` rows | 7,269 (none match user's repro candidates) |
| `Companions:LevelRange` (DB) | 50 (default 3) |
| `Companions:RecruitCooldownS` (DB) | 900 (default 900) |

**Test infrastructure**

- **Lua:** `akk-stack/server/quests/tests/test_companion_recruitment.lua` (38+ tests) and `test_companion_rerec_edge_cases.lua` — inline harness, no external deps. `luajit` is **not on host PATH** — only available in `eqemu/build/vcpkg_installed/x64-linux/`. Engineers must run via Docker exec or symlink.
- **C++:** `eqemu/zone/cli/tests/cli_companion_tests.cpp` — 35+ suites, run via `./bin/zone tests:companion` (NOT gtest; uses zone CLI test runner). Suite 20 `TestCompanionReRecruitmentHP` partially covers re-recruit. The `EQEMU_BUILD_TESTS=OFF` flag and `eqemu/tests/` directory are a separate, mostly empty system; companion tests live in the zone CLI test runner.

**Direct ground-truth verification (2026-04-27):**

```lua
-- companion.lua:13-16 (doc comment, INVERTED semantic):
--   companion:Dismiss(voluntary_bool)    - true=voluntary (preserves record for re-recruitment), false=forced

-- companion.lua:1430-1434 (cmd_dismiss):
function companion.cmd_dismiss(npc, client, args)
    npc:Say("Farewell.")
    npc:Dismiss(true)         -- passes TRUE, intending "voluntary preserve"
end
```

```cpp
// companion.cpp:2553-2570 (C++ implementation):
void Companion::Dismiss(bool permanent)
{
    if (permanent) {
        SoulWipe();             // DELETEs the companion_data row
    } else {
        SetSuspended(true);
        SetDismissed(true);
        Save();
    }
    Depop();
}
```

The C++ parameter is named `permanent`. The Lua doc comment has the parameter sense inverted. `cmd_dismiss(true)` invokes the SoulWipe branch — destroying the re-recruit hint.

### Gap Analysis

What the PRD requires vs. what exists today:

| PRD requirement | Current state | Gap |
|-----------------|--------------|-----|
| Re-recruit bypasses level rules | Track 1 already skips `is_eligible_npc()` | None — already correct |
| Re-recruit bypasses cooldown | Track 1 skips cooldown check; both Lua and C++ delete stale cooldowns belt-and-suspenders | None — already correct |
| Dismissed/dropped-out state is reversible | Death writes `is_suspended=1` correctly; voluntary dismiss SHOULD do the same but instead invokes SoulWipe | **GAP — `cmd_dismiss` calls wrong overload** |
| Level preserved on re-recruit | `Companion::Load()` restores `level` from companion_data row | None — already correct (when row exists) |
| Gear preserved on re-recruit | `Companion::Load()` reads `companion_inventories` | None — already correct (when row exists) |
| First-recruit gating preserved | Track 2 enforces all 11 checks unchanged | None — already correct |
| Machine-verified invariant (TDD) | Test harness exists; specific dismiss-then-rerecruit case not covered | **GAP — TDD tests required by AC-9** |
| Concurrent re-recruit safety | `is_recruited` entity variable guard at `_on_recruitment_success` | Adequate for single-zone; worth a regression test |
| Multi-character isolation | `companion_data.owner_id` scoping | Already correct |

**Two minor robustness gaps surfaced by triage:**

- `companion.lua:207` Lua fallback for `Companions:LevelRange` is `or 3`. If `rule_values` is ever wiped, first-recruit becomes far more restrictive than DB intent. Hardening to `or 50` matches current DB and is defensive.
- `companion_data` has no UNIQUE constraint on `(owner_id, npc_type_id)`. A ghost row exists in production (Hollish Tnoops id=21, level 14, 0 inventory) — strong circumstantial evidence of a write-path bug where a re-recruit INSERTed a new row instead of reusing the existing one. Out of scope for this fix; tracked as future work.

---

## Technical Approach

### Architecture Decision

The least-invasive-first principle applies cleanly here. Triage walked through the layer hierarchy and found:

| Layer | Considered? | Decision | Rationale |
|-------|-------------|----------|-----------|
| Rule values | Yes | **No change** | All five recruit-gating rules are read at single Lua sites already inside Track 2. Loosening rule values would weaken first-recruit gating (PRD Non-Goal #1). |
| Server config | Yes | **No change** | No companion settings exist in `eqemu_config.json` or `.env`. |
| Lua scripts | Yes | **One-line fix + tests + fallback hardening** | Root cause is here. Fix is targeted. |
| SQL tables | Yes | **One-time DELETE** | Ghost row id=21 is dead weight. No schema migration needed. |
| C++ source | Yes | **No change** | C++ already does the right thing on re-recruit (CreateFromNPC re-detects, clears flags, restores). Death path correctly persists `is_suspended=1`. The bug is the Lua command invoking the wrong overload. |

The architecture is decisively **Lua-only with a small DB cleanup**.

### Data Model

**No schema changes.** The existing tables already support the invariant:

- `companion_data` (owner_id, npc_type_id, level, experience, is_dismissed, is_suspended, cur_hp, ...) — soft-delete model preserves history.
- `companion_inventories` (companion_id, slot_id, item_id, charges, aug_slot_1..5) — normalized item rows.
- `companion_buffs` — keyed by companion_id.
- `data_buckets` — cooldown storage with key pattern `companion_cooldown_{npc_type_id}_{char_id}`.

**Read-path duplicate handling.** Engineers MUST select duplicate rows by:

```sql
ORDER BY level DESC, experience DESC LIMIT 1
```

Rationale (per data-expert): `is_suspended=0` weighting would deprioritize legitimately suspended-on-death companions. `recruited_at DESC` would pick the ghost row (recruited later). `level DESC, experience DESC` correctly picks the row with the most player investment.

**One-time DELETE of ghost row id=21** (Hollish Tnoops): SELECT-confirm-DELETE pattern documented in implementation tasks below.

**Out of scope (tracked future work):** Adding `UNIQUE (owner_id, npc_type_id)` constraint on `companion_data`. Risk: may break C++ paths that rely on duplicates being possible. Investigate after the dismiss fix lands and prove no other code path INSERTs duplicates.

### Code Changes

#### C++ Changes

**None.** The C++ side is correct end-to-end.

#### Lua/Script Changes

All changes in `akk-stack/server/quests/lua_modules/companion.lua`:

1. **Line 1434** — `npc:Dismiss(true)` → `npc:Dismiss(false)`
   - One-character change. Routes voluntary `!dismiss` through the preserve-row branch of `Companion::Dismiss(bool permanent)`.
2. **Line 15** — Doc comment correction.
   - Current text says `true=voluntary (preserves record)`. Actual semantics: `true=permanent SoulWipe`, `false=voluntary preserve`. Fix the inversion.
3. **Line 207** — LevelRange fallback hardening: `or 3` → `or 50`.
   - Defense against future `rule_values` reset. Matches current DB value.
4. **Lines 394-397** — Add `ORDER BY level DESC, experience DESC, id DESC` before `LIMIT 1` in `check_existing_companion_record()`.
   - Makes duplicate-row selection deterministic (per data-expert's tie-breaker rule). With multiple rows matching `(owner_id, npc_type_id)` AND `(is_dismissed=1 OR is_suspended=1)`, picks the row with most player investment. Currently moot in production (no two flagged rows for same pair) but defensive against future ghost-creation paths. Lua-only — does not affect C++ which independently re-queries (its ORDER BY tracked as future work).

New tests in `akk-stack/server/quests/tests/test_companion_recruitment.lua` (added BEFORE the fix per PRD AC-9):

1. **`test_cmd_dismiss_calls_dismiss_false`** — stub NPC with a `Dismiss` method that records the boolean argument; call `cmd_dismiss(npc, client, "")`; assert recorded arg is `false`. **Fails today (cmd_dismiss passes true), passes after fix.** This is the most direct test of the bug.
2. **`test_dismiss_preserves_companion_data_row`** — integration-level: dismiss companion, query companion_data — row still present. Existing harness stubs the DB layer so this is verified by inspecting which Dismiss overload is invoked (overlaps test #1; can be folded together).
3. **`test_rerecruit_after_dismiss_uses_track_1`** — dismiss, then re-recruit, then assert `is_re_recruitment_eligible()` was called and `is_eligible_npc()` was NOT called. Existing harness has a similar test (lines 462-494) that pre-bakes `is_dismissed=1` in the stub DB; that test continues to pass after the fix and serves as regression coverage.
4. **`test_rerecruit_after_death_uses_track_1`** — regression coverage. Confirms death path remains unaffected (death writes is_suspended=1 directly via C++; no Lua change needed).
5. **`test_first_recruit_still_gates`** — never-recruited NPC at level outside LevelRange — still rejected with level message. Confirms no regression on first-recruit gating.

#### Database Changes

One-time targeted DELETE — run as a named step. **Targeted, not generalized:** there is exactly ONE known-bad row in production (Hollish Tnoops id=21, verified by data-expert), so the cleanup is unambiguous. A generalized dedup query would be complex and error-prone; if a future ghost row appears, handle it with another targeted DELETE.

```sql
-- Step 1: Verify the ghost row matches expected profile
SELECT id, owner_id, npc_type_id, name, level, experience, times_died, is_suspended, is_dismissed,
       (SELECT COUNT(*) FROM companion_inventories WHERE companion_id = companion_data.id) AS items
FROM companion_data
WHERE id = 21;
-- Expected: owner_id=6, npc_type_id=9144, name="Hollish Tnoops", level=14,
--           experience=0, times_died=0, is_suspended=1, is_dismissed=0, items=0

-- Step 2: Confirm the canonical row exists and is healthier
SELECT id, owner_id, npc_type_id, name, level, experience, is_suspended,
       (SELECT COUNT(*) FROM companion_inventories WHERE companion_id = companion_data.id) AS items
FROM companion_data
WHERE owner_id = 6 AND npc_type_id = 9144 AND id <> 21;
-- Expected: id=18, level=53, experience=18707712, is_suspended=0, items=15

-- Step 3: Delete inventory rows (defensive, will be 0 rows for ghost)
DELETE FROM companion_inventories WHERE companion_id = 21;

-- Step 4: Delete the ghost
DELETE FROM companion_data WHERE id = 21;
```

**Do NOT use generalized dedup SQL.** An earlier sketch in this doc used `ORDER BY` inside an `IN()` subquery, which does NOT filter the IN-set as intended (data-expert flagged the flaw). If a future generalized dedup is ever needed, implement it in application code (a standalone migration script with testable selection logic), not inline SQL.

**No schema changes. No new tables. No migrations.**

#### Configuration Changes

**None.**

---

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Add `make test-companion` target to akk-stack Makefile that runs `docker exec` with luajit from the vcpkg path against `tests/test_companion_recruitment.lua` | infra-expert | — | ~10 lines of Makefile |
| 2 | Write 5 new failing TDD tests in `test_companion_recruitment.lua` per the test list above. Run via `make test-companion` and verify the dismiss-then-rerecruit tests fail today | lua-expert | 1 | ~150 lines Lua test code |
| 3 | One-character fix at `companion.lua:1434` (`Dismiss(true)` → `Dismiss(false)`) | lua-expert | 2 | 1 character |
| 4 | Doc comment correction at `companion.lua:15` (parameter semantics) | lua-expert | 3 | 1 line |
| 5 | LevelRange fallback hardening at `companion.lua:207` (`or 3` → `or 50`) | lua-expert | 3 | 1 character |
| 6 | Run TDD test suite via `make test-companion`. Verify all 5 new tests pass + 38 existing tests still pass | lua-expert | 3, 4, 5 | runtime |
| 7 | Targeted DELETE of ghost row `companion_data.id=21` (SELECT-confirm-DELETE pattern). Document the SELECT output in agent dev-notes for audit. | data-expert | 6 | 5 lines SQL |
| 8 | Server rebuild not required (no C++ change). `#reloadquest` to reload Lua. Verify in-game with game-tester scenarios. | game-tester | 7 | manual |

**Dependency graph:**

```
1 (infra) ──┐
            ├─→ 2 (TDD tests) ──→ 3 (fix) ──→ 4 (doc) ──→ 6 (verify) ──→ 7 (cleanup) ──→ 8 (validate)
                                  └─→ 5 (fallback) ─┘
```

Tasks 4 and 5 are independent of each other; both depend only on task 3 (the fix) and feed task 6.

---

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| infra-expert | 1 | Owns Makefile and Docker exec wiring for the test runner |
| lua-expert | 2, 3, 4, 5, 6 | Owns all Lua quest scripts and Lua test files |
| data-expert | 7 | Owns all DB modifications, including one-time cleanup |
| game-tester | 8 | Owns in-game scenario validation post-implementation |

**Not needed:** c-expert (zero C++ changes), config-expert (zero rule changes), perl-expert (no Perl involved), protocol-agent (no client packet changes).

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `Dismiss(false)` has a side effect we haven't anticipated (entity stays in zone? group not properly removed?) | Low | Medium | TDD test 1 verifies row preservation; game-tester scenarios verify entity behavior |
| Removing the SoulWipe path from gameplay leaves orphan companion_data rows accumulating over time | Low | Low | `Companions:DismissedRetentionDays=30` rule already triggers periodic GC; verify it works (out of scope for this fix, tracked) |
| LevelRange fallback change breaks an edge case where the rule was intentionally absent for some test | Very Low | Low | Defensive change with same value as DB; engineer can roll back the one character if needed |
| Ghost-row DELETE accidentally targets the wrong row | Low | Medium | SELECT-confirm-DELETE pattern with documented expected profile; engineer verifies before DELETE |
| Lua test harness can't run `luajit` due to environment differences | Medium | Medium | infra-expert owns Task 1; if `make test-companion` fails, engineer can fall back to `apt install luajit` or run tests inside the Docker container manually |
| `companion_data` write-path bug (causes ghost rows) is NOT fixed by this change | Certain | Low | Out of scope; the dismiss fix prevents the most common ghost-creation vector. Investigate separately. |

### Compatibility Risks

- **Charm pets, swarm pets, mercs:** Unaffected. `Companion` inherits `NPC`, not `Bot` or `Merc`. `Companion::Dismiss` is companion-specific. Confirmed by c-expert.
- **Existing companion data:** No migration needed. Live DB has zero `is_dismissed=1` rows; the dismissed-flag blocker is theoretical-only. After the fix lands, future `!dismiss` invocations will correctly set `is_dismissed=1` on existing rows.
- **Existing `!dismiss permanent` workflows:** None exist. There is no current Lua path to `Dismiss(false)` — the only invocation is the buggy one we're fixing. No user-facing feature to deprecate.

### Performance Risks

None. Lua change has no runtime cost difference. One-time DELETE is single row. No additional queries added to hot paths.

---

## Review Passes

### Pass 1: Feasibility

**Can we actually build this with the existing codebase?**

Yes, trivially. The fix is a one-character change in a Lua file. The supporting tests live in an existing Lua test harness. The DB change is a one-row DELETE. No build of C++ binaries is required. No restart of the Docker stack is required (a `#reloadquest` in-game suffices).

**The hardest part** is establishing the test execution path. `luajit` isn't on the host PATH and only exists inside the vcpkg build tree. infra-expert needs to land a `make test-companion` target before lua-expert can run TDD tests. This is a one-time infrastructure cost that benefits all future companion test work.

**Protocol-agent consultation:** Not needed. Zero packet/opcode changes. The recruit dialog uses `OP_ChannelMessage` (existing) for keyword recognition and existing spawn/buff packets for companion appearance. No client modifications required.

### Pass 2: Simplicity

**Is this the simplest approach?**

Yes. The implementation surface is the smallest possible — one character to fix the bug, plus:
- 5 TDD tests (mandatory per PRD AC-9, not removable)
- 1 doc comment (correctness, no code change)
- 1 fallback hardening (defensive, optional but cheap)
- 1 SQL DELETE (cleanup, optional but warranted)
- 1 Makefile target (required for engineers to run tests)

We considered and rejected:
- New rule values (`BypassLevelOnReRecruit` etc.) — rejected because the bypass already exists in the two-track system; toggle rules add misconfiguration surface area without benefit.
- C++-side bypass — rejected because the C++ side already does the right thing; the bug is in Lua.
- Schema migration to add `UNIQUE (owner_id, npc_type_id)` — deferred as future work; investigation needed to confirm no C++ path requires duplicates.
- One-time UPDATE sweep of stuck rows — rejected because zero rows are currently stuck.

### Pass 3: Antagonistic

**What could go wrong?**

- **Edge case: player dismisses a companion mid-zoning.** The companion is already despawning. `Dismiss(false)` writes to DB; if the zone process crashes between `SetSuspended/SetDismissed` and `Save()`, the row may be stale on the next zone load. Mitigation: existing `Save()` is atomic at the SQL level; if it commits, the flags are persisted. If it doesn't commit, the row is effectively "still active" and will be loaded next time — slight inconsistency but recoverable (player can dismiss again).
- **Race condition: simultaneous `!dismiss` from two clients.** Not possible — companion is owned by single client; the command requires targeting the companion. Concurrent re-recruit attempts are guarded by the `is_recruited` entity variable at `_on_recruitment_success`.
- **Player exploit: dismiss at full health, re-recruit immediately to "reset" buff timers / position.** Exists today already (death path does the same). Not introduced by this fix. Out of scope.
- **Performance under load: 1000 dismissed companions per character.** `MaxPerPlayer=5` and `DismissedRetentionDays=30` cap this. Existing GC handles it.
- **Data corruption from server crash mid-dismiss.** Same as edge case 1 above.
- **Backward compat: existing `is_dismissed=1` rows in production.** None exist. Even if they did, the new bypass logic routes through Track 1 which clears them on re-recruit. Self-healing.
- **Removing the SoulWipe code path could regress a future feature.** No current consumer; if someone wants permanent SoulWipe later, add an explicit `!dismiss permanent` opt-in.

**Protocol-level edge cases:** Asked protocol-agent to consider client packet behavior. No packets involved in `!dismiss` beyond chat (`OP_ChannelMessage`) and entity despawn (`OP_DeleteSpawn`) — both already used elsewhere with no Titanium quirks.

**Rule-value boundary conditions:** config-expert verified all five recruit-gating rules are single-site reads. Boundary conditions on `LevelRange` (very large values, negative values, zero) all map correctly through `tonumber()`. No bypass logic to test boundary on (the bypass is a code-flow bypass, not a value comparison).

### Pass 4: Integration

**How do the pieces fit together?**

The dependency graph is linear with two parallel branches at the end of step 3:

```
1 (infra: make test-companion)
  ↓
2 (lua-expert: write failing tests, verify they fail)
  ↓
3 (lua-expert: companion.lua:1434 fix)
  ├──→ 4 (doc comment fix)
  └──→ 5 (LevelRange fallback)
         ↓
6 (lua-expert: run tests, verify all pass)
  ↓
7 (data-expert: ghost row DELETE)
  ↓
8 (game-tester: in-game validation)
```

**Ordering matters:**
- TDD tests MUST be written before the fix (AC-9 requirement and discipline).
- The Makefile target MUST exist before tests can be run.
- The fix MUST land before tests can be expected to pass.
- The DELETE MUST happen after the fix (otherwise a dismiss could create a new ghost row in the same session).
- game-tester runs after everything else.

**No circular dependencies. No missing prerequisites. Each expert has the file:line citations needed to do their work independently.**

---

## Resolved PRD Open Questions

The PRD posed four open questions for the architect. Resolutions:

### Question 1 — First-recruit cooldown semantics

**Question:** Preserve the cooldown for first-recruits (anti-thrash protection) or remove the rule entirely if it only ever served as a re-recruit gate?

**Resolution:** **Preserve.** `Companions:RecruitCooldownS=900` continues to apply to Track 2 only. It is set on `_on_recruitment_failure` (failed persuasion roll) at `companion.lua:542`. It is read in Track 2 at `companion.lua:479`. Track 1 already deletes stale cooldowns at `companion.lua:474` and C++ does the same at `companion.cpp:272-275`. The cooldown serves a real purpose for first-time recruit anti-spam, and the bypass for re-recruits is already correct. No rule change needed.

### Question 2 — In-memory cache flushing

**Question:** If the cooldown is bypassed at the validation layer, cache staleness is irrelevant; if deleted at the DB layer, cache invalidation must be considered.

**Resolution:** **Bypass is at the validation layer (Track 1 dispatch).** The cache is irrelevant — Track 1 short-circuits before any cache lookup. The defensive `eq.delete_data(cooldown_key)` at `companion.lua:474` and C++ `DataBucket::DeleteData` at `companion.cpp:272-275` are belt-and-suspenders that go to the DB directly. lua-expert confirmed via live SQL that no stale cooldown rows currently exist. **No cache-invalidation work required.**

### Question 3 — "Other drop-out conditions" enumeration

**Question:** Confirm the system handles zone-disconnect, server-restart, group-disband, and any other drop-out paths consistently.

**Resolution:**

| Path | Handled? | Evidence |
|------|----------|----------|
| Death | Yes | `is_suspended=1` written at `companion.cpp:1881` (Death) and `:646-678` (Process safety net). Live data confirms (Lydl row). |
| Voluntary dismiss | **After this fix** | One-character fix at `companion.lua:1434`. |
| Permanent dismiss (SoulWipe) | N/A | No Lua path currently invokes this. After fix, it remains unreachable from gameplay. |
| Zone disconnect | Out of scope | Not traced in this triage. Existing `SpawnCompanionsOnZone` correctly skips suspended companions on zone-in (`companion.cpp:4131-4134`), so behavior is at least consistent on resume. If suspend isn't being written on disconnect, that's a separate bug. **Tracked as future work, not blocking this fix.** |
| Server restart | Yes | Same `SpawnCompanionsOnZone` behavior. Companions with `is_suspended=1` persist through restart and don't auto-spawn on next session. |
| Group disband | Out of scope | `MaxPerPlayer=5` plus group capacity check ensures no orphan companions in groups. Disband behavior not traced. **Tracked as future work, not blocking.** |

For the PRD invariant to hold, what matters is that **once a companion is dropped out, the row is preserved with at least one of `(is_dismissed=1, is_suspended=1)` set, and re-recruit detects it via the existing OR predicate.** The dismiss fix closes the largest gap. Death already works. Zone disconnect and group disband are noted for future investigation but are not currently failing per the bug report.

### Question 4 — Quest-state interaction on re-recruit of quest-target NPCs

**Question:** Does re-recruit logic need to consider active-quest state (e.g., Lydl Mastat quest where Lydl is also a kill-target)?

**Resolution:** **No. Invariant overrides quest gating.**

Per AC-10: "Re-recruitment of an NPC who is also a kill target or dialogue node in an active quest still succeeds per the invariant."

The re-recruit path does not check quest state today, and adding quest-state awareness would expand scope significantly without a clear win. If a player has previously recruited Lydl, they can re-recruit him whether or not the Lydl Mastat quest is active. The quest's expected interaction (kill Lydl, complete quest objective) is unaffected — the player can still kill the re-recruited Lydl, which would trigger `Companion::Death` and the quest's `EVENT_DEATH` (or equivalent) on the underlying NPC. This is identical to vanilla EQ behavior with charmed/befriended quest targets.

**No special handling. No code change. The invariant is absolute for previously-recruited NPCs.**

If a quest designer in the future wants to gate re-recruit on quest state for narrative reasons, they can add the gate as a per-NPC `companion_exclusions` row of type 0 (manual lore-anchor exclusion). Even then, the invariant still holds for previously-recruited NPCs because Track 1 short-circuits past `is_eligible_npc()` (which contains the exclusion check).

---

## Validation Plan

### What game-tester should verify (post-implementation)

1. **AC-3:** Recruit any NPC. Wait for combat death. Approach the same NPC (after corpse decay/respawn). Use recruit keyword. Companion rejoins immediately, no cooldown wait, same level, same gear.

2. **AC-4:** Recruit any NPC. Use `!dismiss`. Approach the same NPC. Use recruit keyword. Companion rejoins immediately, no cooldown wait, same level, same gear. **This is the canonical bug repro.**

3. **AC-6:** Equip a uniquely-identifiable no-drop item on a companion. Drop them out (death OR dismiss). Re-recruit. Verify the item is still equipped.

4. **AC-7:** Approach a never-before-recruited NPC at a level outside `LevelRange`. Use recruit keyword. Companion rejects with "is too far from your level to recruit." This should still happen — first-recruit gating must not regress.

5. **AC-10:** Recruit Lydl the Great in East Freeport. Activate the Lydl Mastat Freeport wizard-guild quest. Re-recruit Lydl after dismiss. Verify re-recruit succeeds. Optionally: kill the re-recruited Lydl and verify quest credit fires correctly.

6. **Regression — group capacity:** With 5 active companions (cap), attempt to recruit a 6th. Verify rejection with "Your party is full." This is c-expert's "current real-world failure" diagnosis — confirmed working as designed.

7. **Regression — first-recruit cooldown:** Approach a never-recruited NPC, fail the persuasion roll (or simulate via test fixture), immediately re-attempt. Verify cooldown applies (15-min). Then dismiss a previously-recruited NPC and immediately re-recruit. Verify NO cooldown.

### Engineer-side validation (pre-implementation)

Before declaring task 6 complete, lua-expert MUST:

- All 5 new TDD tests pass
- All 38+ existing `test_companion_recruitment.lua` tests still pass
- All `test_companion_rerec_edge_cases.lua` tests still pass
- `make test-companion` exits cleanly with status 0

### Acceptance criteria coverage

| AC | Validation method | Owner |
|----|-------------------|-------|
| AC-1 (re-recruit at any player level) | TDD test #2 + game-tester scenario | lua-expert + game-tester |
| AC-2 (no "too low level" reachable for re-recruit) | TDD test #2 (asserts `is_eligible_npc` not called) | lua-expert |
| AC-3 (re-recruit after death) | game-tester scenario 1 | game-tester |
| AC-4 (re-recruit after dismiss) | game-tester scenario 2 + TDD tests #1, #2, #3 | both |
| AC-5 (level preserved) | game-tester scenario 1 + 2 | game-tester |
| AC-6 (gear preserved) | game-tester scenario 3 | game-tester |
| AC-7 (first-recruit gating preserved) | TDD test #5 + game-tester scenario 4 | both |
| AC-8 (concurrent re-recruit safety) | Existing `is_recruited` guard; covered by inline test in test_companion_recruitment.lua | lua-expert |
| AC-9 (TDD-first delivery) | All 5 new tests written + verified failing BEFORE the fix; verified passing AFTER | lua-expert |
| AC-10 (quest-target NPC re-recruit) | game-tester scenario 5 | game-tester |

---

## Out-of-Scope Future Work

These are intentionally NOT addressed in this fix and are tracked as future work:

1. **`UNIQUE (owner_id, npc_type_id)` constraint on `companion_data`** — prevents future ghost rows. Requires (a) C++ code update to use UPSERT semantics (ON DUPLICATE KEY UPDATE or SELECT-then-INSERT/UPDATE) and (b) database_update_manifest_custom.h migration entry. Sequencing: dedup DELETE → C++ code deploy with upsert → ALTER TABLE ADD UNIQUE INDEX. Reverse-order deployment will fail second-recruit INSERTs. **Out of scope for this bugfix** because it requires C++ changes (this fix is Lua-only).
1a. **C++ ORDER BY for defensive determinism** — `companion.cpp:218` query for re-recruit detection should mirror the Lua ORDER BY (`level DESC, experience DESC, id DESC LIMIT 1`). Currently the C++ query has only `LIMIT 1` with no ORDER BY, so duplicate-row selection is undefined. Lua-side determinism (covered in this fix) controls Track 1 vs Track 2 selection; C++ determinism only matters once Track 1 is firing and C++ is loading the row. Out of scope here because requires a build cycle.
2. **Ghost row write-path investigation** — id=21 was created LATER than id=18, suggesting a re-recruit INSERTed instead of UPDATEing. Likely fixed by the dismiss fix indirectly (most ghosts come from dismiss-then-recruit sequences), but should be confirmed.
3. **`Companions:ReRecruitBonus` rule cleanup** — defined and overridden in DB but never read in Lua or C++. Either wire it into the persuasion roll or remove the rule. Cosmetic.
4. **`Companions:MinFaction` C++ stub at `companion.cpp:3853-3860`** — placeholder log-and-continue. If/when fleshed out, will need its own bypass consideration for re-recruits.
5. **Zone-disconnect and group-disband drop-out paths** — not traced; verify they correctly set `is_suspended=1` so re-recruit works after them.
6. **Permanent SoulWipe as opt-in feature** — if ever desired, add `!dismiss permanent` with explicit confirmation. Currently not reachable from gameplay after this fix.

---

## Decision Log Summary

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Single-character Lua fix at `companion.lua:1434` | Minimal-diff fix at root cause; preserves existing two-track architecture |
| 2 | No C++ changes | C++ side already correctly handles re-recruit (CreateFromNPC, Load, flag clearing); bug is Lua-only |
| 3 | No rule_values changes | All recruit-gating rules read at single Lua sites already inside Track 2; bypass is at dispatch level, not value level |
| 4 | No schema changes | No FK constraints, no triggers, no migrations needed; one-time DELETE of single ghost row |
| 5 | TDD tests added BEFORE the fix per PRD AC-9 | Tests must fail today and pass after — proves invariant is machine-verified |
| 6 | LevelRange fallback hardening (`or 3` → `or 50`) | Defensive against future rule_values reset; matches DB intent |
| 7 | Targeted DELETE of ghost row id=21 with SELECT-confirm pattern | One known-bad row; no broad UPDATE sweep needed (zero stuck rows) |
| 8 | Duplicate row tie-breaker in Lua = `ORDER BY level DESC, experience DESC, id DESC LIMIT 1` | Picks the row with most player investment; `id DESC` is final tie-breaker for equally-invested rows. Applied Lua-only; C++ ORDER BY tracked as future work to preserve "zero C++ changes" boundary. |
| 9 | Zone-disconnect, group-disband, and `UNIQUE` constraint deferred to future work | Not currently failing per bug report; out of scope for this fix |
| 10 | Quest-state interaction (AC-10) does NOT require special handling | Invariant overrides quest gating; killing a re-recruited quest-target still triggers EVENT_DEATH on the underlying NPC |

---

> **Next step:** Spawn the implementation team with the four agents listed in "Required Implementation Agents" above (infra-expert, lua-expert, data-expert, game-tester). They will coordinate via SendMessage and work through the 8-task list in dependency order.
