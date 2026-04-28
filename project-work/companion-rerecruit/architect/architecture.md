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
| Lydl row state | id=10, level=53, is_suspended=1, is_dismissed=0, cur_hp=1504 (post-death; row preserved correctly) |
| Lydl current re-recruit-ability | **Re-recruitable RIGHT NOW.** Track 1 query returns row id=10; group capacity check passes (5 members vs `>= 6` threshold). The bug repro requires a fresh `!dismiss` cycle, which deletes the row via SoulWipe. |
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
6. **`test_dismiss_true_deletes_row`** — call `Dismiss(true)` directly, assert row is removed from stub DB. Documents the permanent SoulWipe semantics for any future `!dismiss permanent` opt-in feature. Currently passes today (SoulWipe IS implemented correctly); this test guards against a regression that breaks the permanent path.
7. **`test_check_existing_finds_row_after_dismiss_false`** — full chain integration: call `Dismiss(false)`, then call `check_existing_companion_record()` with the stubbed character/NPC ids, assert returns the row. Fails today indirectly (because production code never calls Dismiss(false)), passes after the fix.

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

6. **Regression — group capacity:** With 5 active companions in the group (player + 5 companions = 6 members), attempt to recruit a 7th NPC. Verify rejection with "Your party is full." Confirms the >= 6 threshold gates as designed. (Note: c-expert initially diagnosed this as the current Lydl blocker but recanted on direct re-trace; with 4 companions + 1 player = 5 < 6, the group check passes.)

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
1b. **Rename Lua binding parameter `voluntary` → `permanent`** at `lua_companion.cpp:103-107` to match the C++ `Companion::Dismiss(bool permanent)` semantic. The current naming is a *latent hazard*: anyone reading only the Lua binding without checking C++ would assume `voluntary=true → preserve`, but C++ implements `true=permanent SoulWipe`. The Lua doc comment at companion.lua:15 inherited this misreading. The one-character fix at companion.lua:1434 closes the immediate bug, but the binding rename eliminates the underlying naming-mismatch defect. **Out of scope for this bugfix** because it requires a C++ build cycle. Tracked here for future cleanup.
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

---

# V2: Multi-Variant NPC Lookup Fix

> **Date:** 2026-04-28
> **Trigger:** In-game validation of v1 fix surfaced a second, deeper bug.
> **Status:** Draft — pending user review before implementation.
> **Branch:** `bugfix/companion-rerecruit` (still active across all four repos; v1 commits land before v2).

## V2 Executive Summary

The v1 fix (preserve `companion_data` row on voluntary dismiss) is correct and necessary, but it is incomplete. Live testing surfaced that `Lydl_the_Great` exists in spawngroup `freporte_140` (id 5765) as **three distinct `npc_type_id` values** (10162 level 4, 10178 level 2, 10181 level 3) all sharing the same name and same wizard-guild faction (186). A fourth variant exists in northro (392011, faction 0). The user's `companion_data` row stores `npc_type_id=10162` — the variant that spawned at the time of original recruitment. When the zone re-rolls and spawns a different variant (10178 or 10181), Track 1's strict `npc_type_id` lookup misses, Track 2 fires, and the player gets the level-cap rejection again — for an NPC they have already recruited and gear/leveled up.

**This is not Lydl-specific.** Per data-expert: 9,202 distinct names in `npc_types` have more than one `npc_type_id`; 3,038 of those follow the proper-name pattern that recruitable NPCs use. Per lua-expert: NPCs like `orc_centurion` (44 variants), `Priest_of_Discord` (20), `Clockwork_Merchant` (29) carry the same risk if recruited. Two of the user's five active companions are already affected (Lydl with a 60% spawn-mismatch rate; Hollish_Tnoops nominally — but its second variant 383271 is an orphan with zero spawnentries, so practically safe).

**The fix is to widen the re-recruit lookup from `npc_type_id` match to `companion_data.name` match,** keyed off the spawned NPC's `GetCleanName()`. Both Lua (`companion.lua:390-403`) and C++ (`companion.cpp:215-222`) must change in lockstep — Lua's Track 1 gating doesn't help if C++'s `CreateFromNPC` independently re-queries by ID and falls through to a fresh INSERT that orphans the original row.

The v1 boundary "zero C++ changes" cannot hold for v2. **C++ rebuild is required.** Lua-only would leave the fix half-broken: Track 1 finds the row, calls `client:CreateCompanion(npc)`, and C++ promptly creates a duplicate fresh-recruit row.

Surface area: ~30 lines of Lua, ~25 lines of C++, two new TDD tests in each layer, no schema changes, no rule_values changes, no migrations. Build cycle required (ninja rebuild of zone).

## V2 Existing System Re-Analysis

### What v1 missed

v1's triage ran the live SQL `SELECT ... FROM companion_data WHERE owner_id=6 AND npc_type_id=10162 ...` and confirmed the row was present and findable. That confirmation was correct *for the variant that happened to be spawned during testing*. The investigation didn't enumerate spawngroup membership, so we never caught that other variants of the same NPC could occupy the spawn slot. The PRD's "previously recruited" language treats "the NPC" as a singular thing, but PEQ's data model treats each variant as a distinct `npc_type_id`. v1's test harness `make_db_stub(row)` always returned the seeded row regardless of params — so even the TDD coverage didn't expose the variant-mismatch case.

### v2 ground-truth (verified live, 2026-04-28)

| Fact | Source | Value |
|------|--------|-------|
| Lydl variants | data-expert / `npc_types` | 4 (10162, 10178, 10181, 392011) |
| Lydl variants in `freporte_140` spawngroup | data-expert / `spawnentry` | 3 (10162, 10178, 10181 — equal 20% weight each) |
| Lydl spawn-mismatch rate per attempt | derived | 60% (player's row stores 10162; 2 of 3 variants miss) |
| Multi-variant scope (proper-named NPCs) | data-expert / aggregate | 3,038 names with >1 npc_type_id |
| Orphan variant for Hollish_Tnoops (383271) | data-expert / `spawnentry` | 0 spawnentries → never spawns → not a real risk |
| `npc_types.name` indexing | data-expert / SHOW INDEX | TEXT column, no index, 67,530 rows |
| `companion_data.name` content | c-expert + lua-expert / `companion.cpp:2800` | Stored via `GetCleanName()` → CleanMobName strips digits and `_`→space; e.g. `Lydl_the_Great_001` → `Lydl the Great` |
| `Lua_Mob::GetCleanName` luabind binding | architect / `lua_mob.cpp:3773` | Bound and available to scripts as `npc:GetCleanName()` |
| C++ CreateFromNPC strict-ID query | c-expert / `companion.cpp:215-222` | Same bug shape as Lua |
| Other C++ companion_data lookups | c-expert / Finding v2-7 | All use PK or owner_id; only one site needs changing |
| GM commands querying companion_data by npc_type_id | c-expert / grep gm_commands | 0 matches |
| Pre-existing stale-name risk | c-expert / Finding | If admin renames an NPC in `npc_types` after recruitment, `companion_data.name` becomes stale; pre-existing, unrelated to v2 |
| companion_data integrity | data-expert | All 5 production rows have valid npc_types FK; no cleanup needed for v2 |

### Why the bug bites both layers

```
Player /say "recruit" near Lydl variant 10178 in freporte
  → Lua Track 1: SELECT … WHERE npc_type_id=10178 → MISS (row stores 10162)
  → Lua Track 2: full eligibility → "is too far from your level to recruit" (or whatever Track 2 returns)
                                          ↑ what the user just experienced

Even if Lua Track 1 were widened to find the row:
  → Lua calls client:CreateCompanion(npc_10178)
  → C++ CreateFromNPC: SELECT … WHERE npc_type_id=10178 → MISS (row stores 10162)
  → C++ falls through to fresh-recruit branch → INSERT new row with npc_type_id=10178
  → Player gets a duplicate level-1 row; original 10162 row is orphaned
```

Both queries must widen together. The C++ side is load-bearing: it owns the row creation and is the last layer to filter.

## V2 Technical Approach

### Approach selection (A vs B vs C vs D)

| Option | Description | Verdict |
|--------|-------------|---------|
| **A.** Lua-only name lookup | Match `npc_types.name` between current NPC and stored row's npc_type_id | **Reject.** Lua-only doesn't fix C++; bug persists. |
| **B.** Lua + C++: try ID first, fall back to name | Two queries per recruit attempt; preserves exact-match for legacy data | **Acceptable but unnecessary.** No gain over D — name match catches the ID-equal case for free since `companion_data.name` is derived from the same NPC the ID points to. Two queries per recruit is wasteful. |
| **C.** Data-only — collapse Lydl variants to one | DELETE 10178/10181, repoint spawnentries to 10162 | **Reject.** Doesn't fix systemic issue (3,038 other affected names). Doesn't help if first-recruit picked a non-canonical variant. Touches PEQ content data — fragile against PEQ updates. |
| **D.** Lua + C++: name lookup using `companion_data.name` | Single name-based query in both layers, no JOIN, no `npc_types.name` scan | **Selected.** Index-friendly (uses idx_owner_active), no schema migration, equivalent semantics for the single-variant case (name matches because ID matches), generic across all multi-variant NPCs. |

c-expert independently arrived at the same shape ("Option B" in their writeup, which is what we're calling Option D here — terminology confusion across two reports; the SQL is identical). lua-expert independently confirmed `companion_data.name` already stores the clean form.

**Why not JOIN on `npc_types.name`?** Two reasons. First, `npc_types.name` is unindexed `TEXT` over 67,530 rows; every recruit attempt would table-scan. Second, `npc_types.name` retains underscores and digits while `companion_data.name` is the cleaned form — joining would either require a `REPLACE(name, '_', ' ')` (still doesn't strip digits, breaks for `Lydl_the_Great_001`) or `CleanMobName` semantics in SQL (impossible). Pulling the clean name from `npc:GetCleanName()` at the call site sidesteps both problems.

### The new query (both layers, identical shape)

```sql
SELECT id, level, experience, recruited_level, stance, name, companion_type,
       is_dismissed, is_suspended, npc_type_id
FROM companion_data
WHERE owner_id = ?
  AND name = ?                                -- bound to npc:GetCleanName()
  AND (is_dismissed = 1 OR is_suspended = 1)
ORDER BY level DESC, experience DESC, id DESC
LIMIT 1
```

**Indexing:** the `idx_owner_active` composite (`owner_id, is_dismissed, is_suspended`) filters to ~5–10 rows per player; the `name` predicate then evaluates against that handful — negligible cost, no `companion_data.name` index needed. data-expert verified zero index work required.

**Backward compatibility:** for any single-variant NPC, `companion_data.name` resolves to the same clean string regardless of whether we look up by ID or by name. Existing behavior is preserved bit-for-bit. Multi-variant NPCs gain the new behavior. No data migration. No row mutation. Old rows continue working.

**Returning `npc_type_id` in the SELECT:** added to make the row's stored variant ID available for downstream code (currently used in `Load()` and identification). The original ID is preserved in `companion_data.npc_type_id`; only the *trigger* (which entity in the world re-activates the row) widens.

### Code Changes

#### Lua — `akk-stack/server/quests/lua_modules/companion.lua`

1. **Function signature change at line 390** — `check_existing_companion_record(npc_type_id, char_id)` → `check_existing_companion_record(clean_name, char_id)`. Rename for clarity. Drops `npc_type_id` parameter.
2. **SQL replacement at lines 393-399** — replace `npc_type_id = ?` with `name = ?`, keep ORDER BY and LIMIT 1 unchanged. Bind `clean_name` instead of `npc_type_id`.
3. **Caller change at line 463** — `check_existing_companion_record(npc_type_id, char_id)` → `check_existing_companion_record(npc:GetCleanName(), char_id)`. The `npc_type_id` local at line 456 stays (still used for the cooldown_key construction at line 458 and in `_on_recruitment_success`).
4. **Doc comment update at lines 385-389** — update the comment block to say "looks up by clean name instead of npc_type_id; matches the C++ CreateFromNPC name-based fallback."

The deprecated `check_dismissed_record` at line 371 is left untouched (dead code, no callers, marked DEPRECATED).

#### C++ — `eqemu/zone/companion.cpp`

1. **Replace SQL at lines 218-220** — replace the strict `npc_type_id = {}` predicate with `name = '{}'`. Bind `source_npc->GetCleanName()`. Add the same `ORDER BY level DESC, experience DESC, id DESC` for deterministic selection (currently absent in C++ — picks up "v1 future-work item 1a" from the old plan as part of v2). Use `SQL escape` (existing `Strings::Escape` helper or fmt with content-side sanitization) to prevent SQL injection from a maliciously named NPC entity. The recommended pattern uses `CompanionDataRepository::EscapeString(database, source_npc->GetCleanName())` if such a helper exists; otherwise `Strings::Escape` from `common/strings.h`.

   **Skeleton:**
   ```cpp
   std::string clean_name = Strings::Escape(source_npc->GetCleanName());
   auto existing = CompanionDataRepository::GetWhere(
       database,
       fmt::format(
           "owner_id = {} AND name = '{}' AND (is_dismissed = 1 OR is_suspended = 1) "
           "ORDER BY level DESC, experience DESC, id DESC LIMIT 1",
           owner->CharacterID(),
           clean_name
       )
   );
   ```
   Engineer (c-expert) confirms the canonical escape helper at implementation time.

2. **Cooldown deletion at lines 272-275** — keep keyed on `source_npc->GetNPCTypeID()` for now. The cooldown key is per-variant by design (Track 1 doesn't read it; only Track 2 does). data-expert confirmed leaving stale per-variant cooldowns in `data_buckets` is harmless. No change.

3. **Update comment block at lines 209-214** — replace the current rationale with a multi-variant note: "Match by stored clean name rather than npc_type_id, so that multi-variant NPCs (e.g. `Lydl_the_Great` with three spawn variants in freporte) are correctly recognized as previously-recruited regardless of which variant the spawngroup picks this time."

4. **`SetRecruitedNPCTypeID` at line 296** — unchanged. The fresh-recruit branch still stores the variant the player actually triggered against. This is the correct semantic: if a player has *never* recruited any Lydl variant, they recruit the variant they trigger on; `companion_data.name` then receives `GetCleanName()` and any future variant resolves Track 1.

#### SQL / schema changes

**None.** No migrations, no index additions, no row updates, no row deletes. Existing `idx_owner_active` carries the load.

#### Configuration changes

**None.**

### Open questions resolved

| Question | Resolution |
|----------|------------|
| `_000` suffix on entity name | Non-issue. `GetCleanName()` strips digits before either layer queries. `companion_data.name` already stores the stripped form. |
| Track 1 dispatch when name-matched | Track 1 still fails-closed for first-time recruits: a player with NO `companion_data` row for a given `name` gets nil from the query, falls through to Track 2 unchanged. The exclusion check, level range, etc. all live in Track 2's `is_eligible_npc()` and remain untouched. |
| Cross-character bleed | `companion_data.owner_id` scopes the query. Character A's row is never visible to Character B's lookup. |
| Multi-variant within `companion_exclusions` | Lua Track 1 short-circuits past `is_eligible_npc` (which holds the exclusion check), so an excluded variant of a previously-recruited NPC will *still* re-recruit. This is the intended invariant per AC-10 (invariant overrides quest gating). data-expert confirmed none of the 5 active companions are in the exclusions table. |
| Stale-name (admin renames NPC in `npc_types` after recruit) | Documented edge case. Workaround if it ever happens: admin updates `companion_data.name` in lockstep, or simply re-recruits the NPC fresh. Not blocking v2. |
| Cross-zone same-name (e.g. freporte Lydl vs northro Lydl variant 392011) | Edge case the team flagged. Data-expert noted faction differs (186 vs 0). Two perspectives: (a) "same name = same character, accept any" — generous, matches PRD's player-experience framing; (b) "different faction = different lore character, require disambiguation." For v2 we go with (a) — the PRD invariant prioritizes "this is the NPC I recruited" by player perception, and faction-based disambiguation can be added later if needed. **Surface to user for explicit confirmation before implementation.** |

## V2 Implementation Sequence

| # | Task | Agent | Depends On | Scope |
|---|------|-------|------------|-------|
| V2-1 | Extend Lua test harness `make_db_stub` to dispatch on bound params (returns nil when name doesn't match, returns row when it does); add 2 failing TDD tests covering multi-variant detection in `test_companion_recruitment.lua`: (a) `test_rerecruit_finds_row_via_name_when_npc_type_id_differs` — row with npc_type_id=10162 + name="Lydl the Great", queried against current npc with type_id=10178 + same clean name, asserts Track 1 fires; (b) `test_rerecruit_falls_through_when_name_does_not_match` — row exists but name differs, asserts Track 2 fires (regression guard for first-recruit dispatch). Run via `make test-companion`; verify both fail. | lua-expert | — | ~80 lines test code; ~15 lines harness change |
| V2-2 | Apply the Lua fix per "Code Changes → Lua" section (signature change, SQL change, caller change, doc comment). Run `make test-companion`; verify the 2 new tests pass; verify all 58 v1 tests still pass. | lua-expert | V2-1 | ~30 lines |
| V2-3 | Add C++ Suite 35 (`TestCompanionReRecruitmentVariantNameMatch`) in `eqemu/zone/cli/tests/cli_companion_tests.cpp`. Tests the query logic directly via `CompanionDataRepository::GetWhere` with the new SQL — same pattern as Suite 20. Two cases: (a) row stored with npc_type_id=A and name="Foo"; query with name="Foo" returns the row; (b) row stored with name="Foo"; query with name="Bar" returns empty. Plus regression: existing Suite 20 (HP/mana restoration via re-recruit) must still pass after the C++ query change. | c-expert | — | ~60 lines |
| V2-4 | Apply the C++ fix per "Code Changes → C++" section (SQL replacement at companion.cpp:218-220 with `Strings::Escape`-protected name binding, ORDER BY tie-breaker, comment block update). Build via `docker exec ... ninja -j$(nproc)` — full zone rebuild. | c-expert | V2-3 | ~25 lines |
| V2-5 | Run `./bin/zone tests:companion` inside the container; verify Suite 35 passes and all prior 34 suites still pass. | c-expert | V2-4 | runtime |
| V2-6 | Restart server (Spire or `make restart` + infra-expert process startup per MEMORY) so the new C++ binary and reloaded Lua are live. | infra-expert | V2-5 | ~5 minutes |
| V2-7 | In-game scenario validation — see "V2 Validation Plan" below. Append results to existing test plan. | game-tester | V2-6 | manual |

**Dependency graph:**

```
V2-1 ─→ V2-2 ─┐
              ├─→ V2-6 ─→ V2-7
V2-3 ─→ V2-4 ─┘
       └─→ V2-5 ┘
```

V2-1/V2-2 (Lua) and V2-3/V2-4/V2-5 (C++) can run in parallel up to V2-6.

### Required v2 implementation agents

| Agent | Tasks | Rationale |
|-------|-------|-----------|
| lua-expert | V2-1, V2-2 | Lua change owner; harness extension owner |
| c-expert | V2-3, V2-4, V2-5 | C++ change owner; test suite owner |
| infra-expert | V2-6 | Server rebuild + restart sequencing per MEMORY |
| game-tester | V2-7 | In-game validation owner |

**Not needed:** data-expert (zero DB changes), config-expert (zero rule changes), perl-expert, protocol-agent (zero packet changes), lore-master (no narrative content touched).

## V2 Risk Assessment

### Technical risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `companion_data.name` is stale because admin renamed an NPC after recruitment | Very Low | Medium | Pre-existing risk; document only. Workaround: admin updates the row by hand. |
| Two distinct previously-recruited NPCs share a clean name | Very Low for current 5 companions; theoretically possible | Medium | `ORDER BY level DESC, experience DESC, id DESC LIMIT 1` picks the most-invested row. Acceptable. If user wants stricter semantics, add `npc_faction_id` predicate later — flagged in Out-of-Scope. |
| Cross-zone variant collision (freporte Lydl 186 vs northro Lydl 0) treated as same NPC | Low (player would have to physically travel zones with a never-recruited variant in the new zone) | Low | v2 picks "name = same NPC" semantics. **Confirm with user before implementation.** |
| C++ name binding allows SQL injection if NPC display name contains a quote | Very Low (PEQ NPC names are alphanumeric+underscore) | High if it occurs | Use `Strings::Escape` (or repository's escape helper) on the bound name. |
| Replacing C++ SQL changes the row found in a way Load() doesn't expect | Low | Medium | The found row's PK is fed into `Load(existing[0].id)`; everything downstream works on PK. Only the *which row gets found* changes. Suite 35 verifies. |
| Zone rebuild fails or introduces an unrelated build break | Low | High | Engineer reverts the one C++ patch hunk; Lua-only state still leaves us no worse than v1. |
| Lua test harness change breaks one of the 58 v1 tests | Low | Low | Harness extension is additive (dispatch on params); old tests that don't exercise dispatch see identical behavior. CI catches it. |
| Stale per-variant cooldowns accumulate in `data_buckets` | Certain (no GC) | Trivial | Already happens today; pre-existing. Track 1 ignores cooldowns. data-expert flagged but agreed harmless. |

### Compatibility risks

- **Charm pets, swarm pets, mercs, bots:** unaffected. None query `companion_data`. c-expert confirmed `Companion::CreateFromNPC` is the only site changing.
- **Existing companion_data rows:** zero migration. `companion_data.name` is already populated correctly via `GetCleanName()` for every existing row (data-expert verified all 5 production rows).
- **GM commands and admin tooling:** c-expert confirmed zero `npc_type_id`-keyed companion_data lookups in `gm_commands/`. No admin path requires strict ID match.
- **PEQ content updates:** unaffected. `companion_data.name` is computed at recruit time from the live NPC, not pulled from `npc_types`.

### Performance risks

- New query: same access pattern as v1 (`idx_owner_active` filter to 5-10 rows, then string compare on a single column). Equivalent to v1 within measurement noise.
- `npc_types.name` is **not** queried by either layer in v2. The unindexed-TEXT-table-scan concern data-expert raised is avoided entirely by using `companion_data.name`.

## V2 Review Passes

### Pass 1: Feasibility

Yes, end-to-end. Lua change is mechanical (rename param, swap predicate, update caller). C++ change is mechanical (swap predicate, add escape, add ORDER BY). Test infrastructure exists in both layers; only delta is the harness dispatch extension on the Lua side. Build cycle is the standard ninja rebuild already documented in CLAUDE.md.

**protocol-agent consultation:** not needed for v2 — zero packets change. Recruitment dialog and spawn packets are unaffected; the change is purely DB-query-shape.

**config-expert consultation:** not needed for v2 — zero rules change.

### Pass 2: Simplicity

Yes. Single behavioral change in two synchronized sites: widen the predicate from ID-match to name-match. No new tables, no new columns, no rules, no migrations, no UPSERT redesign, no data dedup. Two new TDD tests in each layer (4 total). Build + restart is standard.

We considered and rejected:
- **JOIN on `npc_types.name`**: rejected for unindexed-TEXT scan and digit-stripping mismatch.
- **Add `idx_name_prefix` index on `npc_types.name`**: not needed once we use `companion_data.name` directly. Defer indefinitely.
- **Collapse Lydl variants in PEQ data** (Option C): rejected — doesn't fix the systemic issue, breaks PEQ updates, doesn't help first-recruits on non-canonical variants.
- **`UNIQUE (owner_id, name)` on `companion_data`**: would prevent two rows with the same clean name for the same player. Currently desirable but premature: would require a deduplication pass first, and the v1 future-work `UNIQUE (owner_id, npc_type_id)` is still tracked. Defer both.
- **Add `npc_faction_id` to the predicate**: rejected for v2 (over-constrains the simple case and the user has not asked for it). Tracked as future work if cross-zone collisions become a real problem.
- **Triple-fallback (id → name → fuzzy)**: rejected as over-engineered.

### Pass 3: Antagonistic

What could go wrong:

- **Edge: player recruited Lydl 10162 in freporte, never visited northro. Travels to northro and triggers recruit on Lydl 392011 (faction 0).** Track 1 fires — recognizes 392011's clean name `Lydl the Great` matches the freporte row. The freporte Lydl re-spawns from the existing row. **Is that correct?** Per current PRD invariant ("the NPC the player has previously recruited"): debatable. Treating same-name as same-character is the player-friendly read. **This is the user-confirmation question above. Surfaced explicitly.**

- **Edge: player has TWO `companion_data` rows with the same clean name from two genuinely different NPCs.** Currently impossible (5 active companions, all unique names). Future risk if NPC content adds unrelated NPCs that share a name. ORDER BY tie-breaker selects highest-level row — the one with most player investment. Acceptable. data-expert agreed.

- **Edge: SQL injection via NPC display name.** PEQ names are alphanumeric+underscore by content rule. Even so, escape the bound name. `Strings::Escape` covers it.

- **Edge: race — player simultaneously triggers recruit on two different variants of the same NPC.** The `is_recruited` entity variable guard at `_on_recruitment_success` (companion.lua:514+) prevents double-add; the second call sees the entity flag and aborts. Same protection as v1.

- **Edge: server crash mid-recruit.** Same as v1 — atomic SQL commit at `Save()` level. If the row is committed, restart restores; if not, the row stays in its dropped-out state and is re-recruitable.

- **Edge: a future feature or admin tool inserts a `companion_data` row with a hand-typed name that has different casing or whitespace from `GetCleanName()`'s output.** The `latin1_swedish_ci` collation is case-insensitive so casing doesn't matter; whitespace is the genuine risk (e.g. trailing space in the row). Acceptable to ignore for v2 since no path produces such rows today.

- **Edge: the user's "deeper bug" might have ANOTHER hidden dimension we haven't found yet.** This is the second time triage missed something. To address: (a) lua-expert, c-expert, and data-expert each independently audited their layer in v2 and converged on the same root cause and fix shape; (b) game-tester's v2 scenario list (below) covers all four variant cases; (c) we explicitly surface the cross-zone faction question to the user before implementation. If a third surprise lands, we treat it as v3 with the same discipline.

### Pass 4: Integration

Pieces fit cleanly. Lua-side and C++-side changes are independent up to V2-6 (server restart) and parallelizable. The single integration touchpoint is that BOTH must land before a server-restart: a Lua-only restart leaves C++ creating duplicate rows; a C++-only restart leaves Track 1 unable to fire because Lua's Track 1 query still misses. The implementation sequence enforces this — V2-6 only happens after both V2-2 (Lua tests pass) and V2-5 (C++ tests pass).

Each agent has a complete file:line citation list and exact SQL to write. No reverse dependencies; no circular blocks.

## V2 Validation Plan

### Engineer-side (pre-server-restart)

- **lua-expert (V2-2):** all 58 v1 tests pass + 2 new v2 tests pass. `make test-companion` exits 0.
- **c-expert (V2-5):** Suite 35 passes; Suite 20 (regression) passes; all 34 prior suites pass.

### Game-tester (V2-7, post-server-restart)

Append these to the v1 test plan; do not replace it. Run BOTH plans.

1. **Multi-variant re-recruit (canonical Lydl repro).** With Lydl row id=10 in `is_suspended=1` state (level 53, full gear), enter freporte, locate Lydl in the tavern. Repeat the recruit attempt across multiple zone re-spawns until each of the three variants (10162, 10178, 10181) has been observed at least once (the user can `#zone freporte` to force re-spawns). Re-recruit succeeds on all three. Companion rejoins as level 53 with all 14 inventory items. **This is the canonical AC-1/AC-3/AC-4/AC-5/AC-6 case for v2.**

2. **Single-variant regression — Hollish_Tnoops, Jracol_Brestiage, Lashun_Novashine, Jimble_Woodentoe.** For each previously-recruited single-variant companion, dismiss → re-recruit → verify Track 1 fires (not Track 2 with cooldown). Confirms backward compat for non-multi-variant NPCs.

3. **First-recruit regression — never-before-recruited NPC.** Approach a never-recruited NPC at a level outside `LevelRange`. Recruit attempt rejected with "is too far from your level to recruit." Confirms Track 2 first-recruit gating still fires when no `companion_data` row exists.

4. **Cross-zone variant** *(only if user confirms the same-name = same-character semantics; otherwise skip).* Travel to northro, locate Lydl 392011 (different faction), trigger recruit. Expectation depends on user's design call: either Track 1 fires re-using freporte row (current plan), or specific guidance per user input.

5. **Concurrent recruit regression — two simultaneous recruit attempts on the same variant of a previously-recruited NPC.** Existing `is_recruited` entity variable guard ensures only one companion is created.

6. **C++ duplicate-row check.** After scenario 1, query `SELECT id, npc_type_id FROM companion_data WHERE owner_id=6 AND name='Lydl the Great';` — must return exactly ONE row (id=10, npc_type_id=10162). No duplicates from variant-mismatch INSERTs.

### Acceptance criteria coverage (v2-specific)

| AC | Scenario | Owner |
|----|----------|-------|
| AC-1, AC-3, AC-5, AC-6 (variant re-recruit) | game-tester scenario 1 + Lua TDD V2-1(a) + C++ Suite 35 case (a) | game-tester + engineers |
| AC-7 (first-recruit gating) | game-tester scenario 3 + Lua TDD V2-1(b) | game-tester + lua-expert |
| AC-8 (concurrent re-recruit) | game-tester scenario 5; existing v1 coverage | game-tester |
| AC-9 (TDD-first) | V2-1 and V2-3 written before V2-2 and V2-4 respectively; verify failing first | lua-expert + c-expert |
| AC-10 (quest-target NPC) | unaffected by v2; v1 coverage stands | game-tester |
| Regression: no duplicate rows after multi-variant recruit | game-tester scenario 6 | game-tester |
| Regression: single-variant NPCs unaffected | game-tester scenario 2 | game-tester |

## V2 Out-of-Scope (tracked for future work)

1. **`UNIQUE (owner_id, name)` constraint on `companion_data`** — paired with the v1-tracked `UNIQUE (owner_id, npc_type_id)`. Both deferred. Requires UPSERT semantics in C++ and a dedup pass first.
2. **`npc_faction_id` disambiguation** — if cross-zone same-name collisions become a real problem (currently theoretical), add faction predicate to Track 1. Defer pending real evidence.
3. **`Strings::Escape` audit of all `companion_data` queries** — c-expert noted only the new query needs it; existing ID-keyed queries don't. Future hardening if any other text-keyed lookup is added.
4. **Stale-name handling if admin renames `npc_types`** — pre-existing, low-frequency, document-only.
5. **Companion rename cascade** — if v2 introduces a companion-rename feature, `companion_data.name` would need to update. Not in scope.
6. **`lua_companion.cpp:103` parameter rename** (`voluntary` → `permanent`) — still tracked from v1. Defer.
7. **Cooldown GC for stale per-variant `data_buckets` rows** — harmless accumulation; defer indefinitely.
8. **Add `idx_name_prefix(name(100))` on `npc_types.name`** — only relevant if we ever revert to JOIN-on-npc_types-name. Not needed for v2.
9. **`check_dismissed_record` (deprecated function)** — v2 leaves it untouched. Could be deleted in cleanup pass.

## V2 Decision Log

| # | Decision | Rationale |
|---|----------|-----------|
| V2-1 | Use `companion_data.name` for re-recruit lookup, bound to `npc:GetCleanName()` | Avoids unindexed `npc_types.name` scan. Avoids digit-stripping mismatch between `npc_types.name` and `CleanMobName`. Keeps query scope inside the per-player rowset (~5-10 rows). |
| V2-2 | Both Lua and C++ must change in lockstep | C++ `CreateFromNPC` runs an independent query; Lua-only fix would be silently undone by C++ falling through to fresh-recruit and inserting a duplicate row. |
| V2-3 | Reject Option A (JOIN on `npc_types.name`) | Unindexed TEXT, 67k rows, table-scan per recruit. `REPLACE(name, '_', ' ')` doesn't strip digits. |
| V2-4 | Reject Option C (data dedup of Lydl variants) | Doesn't fix systemic 3,038-name pattern; touches PEQ content; fragile against PEQ updates. |
| V2-5 | Reject `UNIQUE` constraint and faction-disambiguation work for now | Premature; no current evidence either is needed. Track as future work. |
| V2-6 | C++ ORDER BY added at the new query in lockstep with Lua's existing one | Picks up the v1 future-work item 1a; deterministic selection across both layers. |
| V2-7 | Use `Strings::Escape` (or repository's canonical helper) on the bound NPC name | Defense against pathological NPC display names with SQL metacharacters; cheap. |
| V2-8 | Cross-zone same-name (freporte Lydl vs northro Lydl) treated as same character | Player-experience semantics per PRD invariant; flagged for explicit user confirmation before implementation. |
| V2-9 | TDD discipline carries from v1: failing tests before fix in BOTH layers | PRD AC-9. |

## V2 Rollback

Per-layer revert is independent and additive:

1. **Lua revert (V2-2 only):** revert `companion.lua` to v1 state. Track 1 no longer matches multi-variant; bug reappears. C++ side may stay v2-fixed without harm — when Lua falls through to Track 2, C++'s `CreateFromNPC` is never called.
2. **C++ revert (V2-4 only):** revert `companion.cpp:218-220` to v1 state. Lua Track 1 finds the row, calls `client:CreateCompanion`, C++ then runs the strict-ID query, misses, INSERTs a duplicate. **This rollback ordering is unsafe** — only roll back C++ if Lua is reverted in lockstep.
3. **Test rollback:** new TDD tests stay in the repo as known-broken markers if either implementation is reverted. PRD discipline: tests survive even a revert.

The atomic-rollback path is "revert both V2-2 and V2-4." Engineers do not roll back C++ alone.

---

> **Next step:** User reviews this v2 plan. Open question to confirm: cross-zone same-name semantics (Decision V2-8). Once confirmed, the orchestrator spawns the implementation team — lua-expert (V2-1, V2-2), c-expert (V2-3, V2-4, V2-5), infra-expert (V2-6), game-tester (V2-7).

---

## V2 Refinements (post-c-expert full audit, 2026-04-28)

c-expert delivered the comprehensive 7-question C++ audit after the v2 plan was drafted. Three findings are worth folding into the plan; none change the selected approach.

### Refinement R1: Appearance behavior is correct under the fix

The targeted entity's `npc_type_id` controls appearance and base stats (NPC constructor at `companion.cpp:226` uses `npc_type_data` loaded from the variant the player targeted at line 201). `Load()` then restores saved level/XP/gear and overwrites `m_recruited_npc_type_id` with the stored ORIGINAL id (e.g. 10162) but does not re-run the constructor — so visual appearance stays the targeted variant. For Lydl's three freporte variants (same race/gender/texture) this is invisible; for hypothetical visually-distinct multi-variant NPCs, the player sees whatever they targeted. This matches the intuitive player expectation ("I'm recruiting THIS Lydl in front of me") and requires zero additional code.

### Refinement R2: Stable identity preserved across zone reloads

`companion_data.npc_type_id` is preserved by `Load()`. `SpawnCompanionsOnZone` at `companion.cpp:4137` uses `cd.npc_type_id` to load the NPCType for zone-in spawns — which means a re-recruited Lydl, after the player zones out and back, will spawn as the ORIGINAL variant (10162) rendered from `LoadNPCTypesData(10162)`. Subsequent re-recruits that trigger on a different variant in another session will again temporarily render as the targeted variant until the next zone reload. This is acceptable: the DB row is the stable identity; the trigger is the per-session activation surface. **No action needed.**

### Refinement R3: Two latent Lua bindings flagged for future-work

`lua_client.cpp:3683` `GetCompanionByNPCTypeID(npc_type_id)` and `lua_client.cpp:3697` `HasActiveCompanion(npc_type_id)` scan the in-memory companion list by `GetRecruitedNPCTypeID()`. After v2, `GetRecruitedNPCTypeID()` returns the STORED original variant id (10162). A future script that calls `client:GetCompanionByNPCTypeID(10178)` to find a Lydl-recruited-via-10178-variant will miss. **c-expert confirmed via grep that zero production scripts call either function** — they appear only in module header comments. Adding this to V2 Out-of-Scope item 10 (new): "If these Lua bindings are ever used by future scripts, they should accept either ID and resolve via `companion_data.name` lookup (mirroring this v2 fix)." Not blocking. Documenting only.

### Refinement R4: Suite 35 test harness confirmed

c-expert verified the test harness supports real DB writes with a sentinel `owner_id=99999` for isolation. Suite 35 will:
1. Seed a row with `npc_type_id=10162, name='Lydl the Great', is_suspended=1, owner_id=99999`
2. Run the new query with `name='Lydl the Great'` against an unrelated `npc_type_id` (e.g. 10178)
3. Assert row IS found
4. Assert old strict-ID query returns empty for the same `npc_type_id=10178` (proves the test exercises the bug)
5. Cleanup `DELETE WHERE owner_id=99999`

Live DB already has the variants needed (`Lydl_the_Great` at 10162/10178/10181/392011) — no test fixtures to seed in `npc_types`.

### Refinement R5: Out-of-Scope item added

10. **`Lua_Client::GetCompanionByNPCTypeID` / `HasActiveCompanion` variant-aware lookup** — currently unused in production scripts; defer until any script depends on them. Future fix would mirror the v2 query shape (accept either ID, resolve by stored name).

These refinements are documentation-only; no change to task list, SQL shape, or implementation sequence.

---

## V2 Refinements Round 2 (post-lua-expert full investigation, 2026-04-28)

lua-expert delivered the comprehensive 6-question Lua investigation after the v2 plan was drafted. The findings confirm the plan; one terminology clarification and one harness detail are worth folding in.

### Refinement R6: "Option B = Option D" terminology reconciliation

c-expert's writeup labeled the chosen approach "Option B" (use `companion_data.name`); lua-expert's labeled it "Option D" (the same SQL). Internally the team used these labels interchangeably. **The architecture doc commits to the single-query name-only form** (predicate is `name = ?`, no `npc_type_id` in the WHERE clause).

lua-expert proposed an "ID-first, name-fallback" pattern (two queries when the ID misses, one when it hits). This is functionally equivalent to the single name query for the multi-variant case but slightly more complex to test and reason about. The architect retains the single-query form for these reasons:

| Criterion | Single name query (architect's plan) | ID-first + name fallback (lua-expert's pattern) |
|-----------|--------------------------------------|------------------------------------------------|
| Queries per recruit attempt | 1 always | 1 if canonical (~99%), 2 if variant (~1%) |
| Code complexity | One SQL string | Two SQL strings + branching |
| Test surface | One execution path | Two execution paths to cover |
| Multi-variant correctness | identical (name match) | identical (name match in fallback) |
| Single-variant correctness | identical (name resolves to same row as ID) | identical |
| Same-name collision (two distinct NPCs) | ORDER BY tie-breaker selects most-invested row | ID-first path resolves canonical row when targeting canonical variant |

The single-query approach is simpler, faster on average, and produces identical results for every case the user is likely to encounter. The same-name collision concern is theoretical (no current `companion_data` rows have it; data-expert verified) and the ORDER BY tie-breaker handles it deterministically.

**Engineers implementing v2:** use the single name-only query as documented in "V2 Technical Approach → The new query." Do NOT implement the ID-first/fallback two-query pattern.

### Refinement R7: Lua test harness extension shape (lua-expert's `make_db_stub_v2`)

lua-expert proposed `make_db_stub_v2(id_row, name_row)` that inspects the SQL string at `prepare()` time to dispatch — returns `id_row` for the legacy ID query and `name_row` for the new name query. Since v2 uses a SINGLE name query (not ID-first-fallback), the harness is even simpler: stub returns the seeded row when the SQL contains `name = ?`, returns nil otherwise. Existing 58 v1 tests continue to use the standard `make_db_stub(row)` unchanged because their SQL still contains `name = ?` (v2 query) — the v1 tests will need a one-line adjustment to either (a) use a v2-aware stub or (b) seed rows whose `name` matches the test setup. lua-expert (Task V2-1) owns the harness shape; recommendation is to make `make_db_stub` SQL-agnostic by default (return seeded row for any query) so v1 tests pass unmodified, and add an explicit `make_db_stub_name_aware(name_row)` for v2 multi-variant tests.

### Refinement R8: Underscore-vs-space in `companion_data.name`

lua-expert verified via `HEX(name)` that all four Lydl variants in `npc_types` store the exact bytes `4C79646C5F7468655F4772656174` (Lydl_the_Great with underscores). After `CleanMobName`, this becomes `Lydl the Great` (space-separated, no digits). `companion_data.name` therefore stores the space-separated form. `npc:GetCleanName()` returns the same space-separated form.

`MakeNameUnique` (entity.cpp:3303-3341) appends `_001`, `_002`, etc. to the entity name when multiple entities share a prefix; `CleanMobName` strips these digits. So world entities like `Lydl_the_Great_001` are correctly resolved to `Lydl the Great` by `GetCleanName()`. **No special handling needed in v2.**

### Refinement R9: Cooldown variant leak (Track 2 only) is acceptable

lua-expert flagged that cooldowns are stored per-variant (`companion_cooldown_10162_6` vs `companion_cooldown_10178_6`). A player who fails first-time recruit on variant 10162 would not be blocked from immediately attempting variant 10178 because the cooldown key differs. This is technically a first-recruit anti-spam bypass; it doesn't affect re-recruit (Track 1 ignores cooldowns) and only matters for never-recruited NPCs. Per c-expert's earlier finding, harmless. **No action needed for v2.** Documented as a future-work note if first-recruit anti-spam ever becomes a tight requirement.

### Refinement R10: `check_dismissed_record` (companion.lua:371) deprecated

lua-expert confirmed the deprecated function still uses strict ID match and has zero callers. v2 leaves it untouched. Out-of-Scope item 9 already covers this.

These refinements are documentation-only; no change to task list, SQL shape, or implementation sequence.
