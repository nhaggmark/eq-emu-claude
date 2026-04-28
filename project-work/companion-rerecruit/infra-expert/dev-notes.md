# Companion Re-recruitment Fix — Dev Notes: infra-expert

> **Feature branch:** `bugfix/companion-rerecruit`
> **Agent:** infra-expert
> **Task(s):** Task 1 — `make test-companion` Makefile target
> **Date started:** 2026-04-27
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Add `make test-companion` target to akk-stack Makefile (luajit via Docker exec) | — | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `akk-stack/Makefile` | All | Existing style: `$(DOCKER) exec <service> <cmd>`. `test-llm` target at line 254 is the direct style reference for a test runner target. |
| `architecture.md` | "Test infrastructure" block, "Implementation Sequence" Task 1 | luajit path: `/home/eqemu/code/build/vcpkg_installed/x64-linux/tools/luajit/luajit`. Test files in `/home/eqemu/server/quests/tests/`. Both `test_companion_recruitment.lua` and `test_companion_rerec_edge_cases.lua`. |

### Key Findings

- luajit confirmed at `/home/eqemu/code/build/vcpkg_installed/x64-linux/tools/luajit/luajit` (not on host PATH, only in vcpkg tree inside container)
- Both test files already exist: `test_companion_recruitment.lua` (45 tests) and `test_companion_rerec_edge_cases.lua` (8 tests)
- Container service name for `$(DOCKER) exec` is `eqemu-server`
- The `-T` flag (no pseudo-TTY) is needed for non-interactive exec in Makefile recipes

### Implementation Plan

Add a `test-companion` target under a new `#-- companion tests --#` section. Target must:
1. Check each test file exists; print SKIP message and exit 1 if missing
2. Run `luajit <file>` for each test file via `$(DOCKER) exec -T eqemu-server`
3. Produce clean pass/fail output (luajit harnesses print their own summaries)

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `docker-compose exec -T` | Live test against running container | Yes | `-T` works; needed to suppress TTY in non-interactive make context |
| luajit invocation | Live test: `/home/eqemu/code/build/vcpkg_installed/x64-linux/tools/luajit/luajit -v` | Yes | LuaJIT 2.1.0-beta3 confirmed working |
| Make multi-line shell recipes | Makefile manual (continuations with `\`) | Yes | Each `\`-continued block is one shell invocation |

### Plan Amendments

Plan confirmed — no amendments needed. The `-T` flag works and the bash test-file-existence check pattern (`bash -c "test -f ..."`) is consistent with the rest of the Makefile.

### Verified Plan

See Implementation Plan above — confirmed by research.

---

## Stage 3: Socialize

Task 1 has no blocking dependencies and is explicitly first in the dependency graph. Architecture doc states: "Your task is FIRST. lua-expert needs the target to run their TDD tests. Don't gate on anyone." Proceeded to build without socializing — the spec was unambiguous and the target was self-contained.

---

## Stage 4: Build

### Implementation Log

#### 2026-04-27 — Added `make test-companion` target to akk-stack/Makefile

**What:** Added a new `#-- companion tests --#` section with a `test-companion` target immediately after the `test-llm` target (natural grouping with other test runners). Defines three Make variables for paths (LUAJIT, TEST_COMPANION_MAIN, TEST_COMPANION_REREC) and a multi-line shell recipe that checks for each file's existence, prints a SKIP message if missing, and runs luajit against each file if both are present.

**Where:** `/mnt/d/Dev/eq/akk-stack/Makefile` — after line 256 (`test-llm` target), new section spanning ~19 lines

**Why:** Architecture doc spec requires luajit invocation via Docker exec. The luajit binary only exists in the vcpkg build tree inside the container, not on the host PATH. The target must gracefully handle the pre-existing-test-file state (before lua-expert writes Task 2 tests).

**Notes:**
- The `##@companion` category comment makes the target appear under a new "companion" group in `make help` output
- Both test files already exist and pass: `test_companion_recruitment.lua` (45 tests, 0 failures), `test_companion_rerec_edge_cases.lua` (8 tests, 0 failures)
- End-to-end test of `make test-companion` confirmed clean output

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| None encountered | — | — |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `/mnt/d/Dev/eq/akk-stack/Makefile` | Modified | Added `make test-companion` target + companion tests section |

**Commit:** `7101248` on `bugfix/companion-rerecruit` in akk-stack repo
**Pushed:** Yes, to `origin/bugfix/companion-rerecruit`

---

## How to Invoke

```
cd /mnt/d/Dev/eq/akk-stack
make test-companion
```

Runs both Lua test suites inside the eqemu-server container and prints pass/fail summaries. Sub-second execution. Exits 0 on all-pass, exits non-zero if any test fails or test files are not yet present.

---

## Context for Next Agent

Task 1 is complete. lua-expert (Task 2) can now run `make test-companion` from `akk-stack/` to execute the Lua TDD test suite.

**luajit path inside container:** `/home/eqemu/code/build/vcpkg_installed/x64-linux/tools/luajit/luajit`
**Test file paths inside container:**
- `/home/eqemu/server/quests/tests/test_companion_recruitment.lua`
- `/home/eqemu/server/quests/tests/test_companion_rerec_edge_cases.lua`

lua-expert should write the 5 new failing TDD tests to `test_companion_recruitment.lua` (host path: `akk-stack/server/quests/tests/test_companion_recruitment.lua`) and verify they fail via `make test-companion` BEFORE writing the fix.
