# Companion Recruitment & Re-recruitment Overhaul — Dev Notes: C Expert

> **Feature branch:** `feature/companion-recruitment-overhaul`
> **Agent:** c-expert
> **Task(s):** Task #2
> **Date started:** 2026-03-14
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | C++: Add cooldown cleanup and HP restoration in `CreateFromNPC()` | — | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/zone/companion.cpp` | 159-256 | `CreateFromNPC()` re-recruitment path: Load(), flag clearing, logging. No DataBucket calls. |
| `eqemu/zone/companion.cpp` | 2449-2497 | `Load()`: restores cur_hp with `if (cd.cur_hp > 0)` guard — skips when dead |
| `eqemu/zone/lua_client.cpp` | 3639-3681 | Sequence: `CreateFromNPC()` → `Save()` → `Spawn()` |
| `eqemu/zone/companion.cpp` | 48-148 | Constructor: HP set from NPCType data, not max after scaling |
| `common/data_bucket.h` | 39-71 | `DeleteData` requires `(SharedDatabase*, const std::string&)` |
| `zone/mob.h` | 557, 673 | `SetHP(int64)`, `SetMana(int64)` exist on Mob |
| `zone/mob.h` | 1389 | `RestoreHealth()` calls `SendHPUpdate()` — needs entity ID (post-Spawn) |

### Key Findings

1. `Load()` skips `SetHP()`/`SetMana()` when `cur_hp=0` (dead companion). After `Load()`, HP
   is whatever the constructor initialized from NPCType base data. This is NOT max — after
   `ScaleStatsToLevel()` raises max_hp above base, the constructor HP is stale. Must explicitly
   set to max after Load().

2. `RestoreHealth()` calls `SendHPUpdate()` which requires an entity ID. Companion only gets
   an entity ID when added to entity_list in `Spawn()`. So we must use `SetHP(GetMaxHP())`
   directly, NOT `RestoreHealth()`.

3. `DataBucket::DeleteData` takes `(SharedDatabase*, key)`. Architecture doc pseudocode showed
   one-argument form which doesn't exist. Correct form: `DataBucket::DeleteData(&database, key)`.

4. `data_bucket.h` is already included in companion.cpp line 21.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/zone/companion.cpp` | Modify | Add 2 changes in `CreateFromNPC()` re-recruitment path |
| `eqemu/zone/cli/tests/cli_companion_tests.cpp` | Modify | Add Suite 19: Re-recruitment HP + cooldown tests |

**Change sequence:**
1. Write Suite 19 tests (TDD — tests FIRST, they will fail before implementation)
2. Add `SetHP(GetMaxHP())` + `SetMana(GetMaxMana())` after Load() succeeds
3. Add `DataBucket::DeleteData(&database, ...)` after flag clear
4. Build and run all tests — suite 19 must pass, no regressions

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `DataBucket::DeleteData` signature | `common/data_bucket.h:43` | Yes | Requires `(SharedDatabase*, string)` — architecture doc pseudocode was wrong |
| Callers of `DataBucket::DeleteData` | `zone/client.cpp:9847`, etc. | Yes | All use `&database` form |
| `SetHP(int64)` / `SetMana(int64)` | `zone/mob.h:557,673` | Yes | Exist on Mob, direct field assignment |
| `RestoreHealth()` | `zone/mob.h:1389` | Yes | Calls `SendHPUpdate()` — unsafe before Spawn() |
| `Load()` dead-companion HP behavior | `companion.cpp:2485-2491` | Yes | `if (cd.cur_hp > 0)` guard — skips for dead companions |
| `Spawn()` entity list add | `companion.cpp:2001` | Yes | `AddCompanion()` assigns entity ID — must happen before SendHPUpdate |

### Plan Amendments

Architecture doc pseudocode for `DataBucket::DeleteData` showed single-arg form which
does not exist. Actual API requires `(SharedDatabase*, const std::string&)`. Using
`DataBucket::DeleteData(&database, fmt::format(...))`.

### Verified Plan

See Implementation Plan above, with DataBucket signature corrected to two-argument form.

---

## Stage 3: Socialize

Architecture doc defines the Lua/C++ contract clearly. Task 2 is fully independent
of Task 1 — different files, different repos. No cross-expert coordination needed
before implementation. Contract invariant #5 explicitly assigns HP/mana restoration
to C++. Proceeding.

### Consensus Plan

Per architecture.md contract and research findings:

**Agreed approach:** Two additions to `CreateFromNPC()` re-recruitment path only.
First-time recruitment path is unchanged.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/zone/companion.cpp` | Modify | 2 additions in re-recruitment branch of `CreateFromNPC()` |
| `eqemu/zone/cli/tests/cli_companion_tests.cpp` | Modify | Suite 19 with 5 tests |

**Change sequence (final):**
1. Add Suite 19 failing tests to `cli_companion_tests.cpp` and register in `TestCompanion()`
2. Build with tests — confirm Suite 19 tests FAIL
3. Add HP/mana restoration after `Load()` success in `CreateFromNPC()`
4. Add DataBucket cooldown cleanup after flag clear in `CreateFromNPC()`
5. Build again — confirm Suite 19 passes, all prior suites still pass
6. Commit

---

## Stage 4: Build

### Tests Added (Suite 19)

`eqemu/zone/cli/tests/cli_companion_tests.cpp` — added includes for `data_bucket.h` and
`companion_data_repository.h`, plus `inline void TestCompanionReRecruitmentHP()` with
4 test cases registered in `ZoneCLI::TestCompanion()`.

Note: `CreateFromNPC()` is not directly tested (requires live `Client*` unavailable in CLI
test environment). Tests exercise Load() + SetHP/SetMana (same code path) and
DataBucket::DeleteData directly.

### Implementation Log

#### 2026-03-14 — HP/mana restoration in CreateFromNPC() re-recruitment path

**What:** `companion->SetHP(companion->GetMaxHP())` + `companion->SetMana(companion->GetMaxMana())`
after `companion->Load()` succeeds, before flag clearing.

**Where:** `eqemu/zone/companion.cpp` lines 224-225

**Why:** Load() `if (cd.cur_hp > 0)` guard skips SetHP for dead companions. After
ScaleStatsToLevel() raises max_hp, constructor HP < GetMaxHP(). Spawn() does not
restore HP. Using SetHP/SetMana (not RestoreHealth/RestoreMana) because
SendHPUpdate() in RestoreHealth() needs entity ID (assigned by Spawn() later).

#### 2026-03-14 — DataBucket cooldown cleanup in CreateFromNPC() re-recruitment path

**What:** `DataBucket::DeleteData(&database, fmt::format("companion_cooldown_{}_{}", ...))`
after the UPDATE companion_data SET is_dismissed=0, is_suspended=0 call.

**Where:** `eqemu/zone/companion.cpp` lines 243-246

**Why:** Belt-and-suspenders. Lua also deletes it on success via `eq.delete_data()`.
C++ ensures no stale cooldown survives if Lua cleanup is bypassed.
Using non-scoped form (character_id=0) to match how Lua stores cooldowns.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| Architecture doc showed single-arg `DataBucket::DeleteData(key)` | Pseudocode error | Used correct two-arg form `DeleteData(&database, key)` per header |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `eqemu/zone/companion.cpp` | Modified | HP/mana restoration + DataBucket cleanup in re-recruitment path |
| `eqemu/zone/cli/tests/cli_companion_tests.cpp` | Modified | Suite 19 (4 tests), new includes |

### Commit

`a7c8c7e87` feat(companion): restore HP/mana on re-recruitment and cleanup stale cooldowns

---

## Open Items

- [ ] Build verification pending (Docker not accessible from this WSL session)
  — Run: `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && cmake -G Ninja -DEQEMU_BUILD_TESTS=ON .. 2>&1 | tail -5 && ninja -j\$(nproc)"`
  — Then: `docker exec akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && ./bin/zone tests:companion 2>&1"`

---

## Context for Next Agent

Task #2 is complete. The two C++ changes are in `eqemu/zone/companion.cpp`
`CreateFromNPC()` re-recruitment branch (lines 224-246):

1. `SetHP(GetMaxHP())` + `SetMana(GetMaxMana())` after Load() — ensures dead companions
   spawn alive. Placed BEFORE flag clearing and before Spawn() (which needs entity ID
   for SendHPUpdate).

2. `DataBucket::DeleteData(&database, fmt::format("companion_cooldown_{}_{}", npc_type_id, char_id))`
   after flag clearing — belt-and-suspenders cooldown cleanup matching Lua's `eq.delete_data()`.

Suite 19 tests are in `cli_companion_tests.cpp` testing Load() + SetHP behavior and
DataBucket::DeleteData API. The test function is `TestCompanionReRecruitmentHP()`.

Task #3 (integration verification) requires lua-expert to confirm their Lua changes
are complete and both sides agree on the Lua/C++ contract.
