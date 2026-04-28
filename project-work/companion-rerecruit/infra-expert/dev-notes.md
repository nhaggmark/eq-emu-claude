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

---

# Task V2-6 — Full Stack Rebuild & Restart (v2 implementation)

> **Task:** V2-6
> **Date started:** 2026-04-27
> **Current stage:** Stage 1 — Waiting for V2-2 (lua-expert) AND V2-5 (c-expert) to complete

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| V2-6 | Server restart (containers + EQ processes per MEMORY) so new C++ binary and reloaded Lua go live | V2-2 (lua-expert complete) AND V2-5 (c-expert complete — Suite 35 + Suite 20 + 34 prior suites all pass) | Waiting |

---

## Stage 1: Plan

### What V2-6 Must Do

1. Confirm V2-2 and V2-5 are both complete and committed on `bugfix/companion-rerecruit`.
2. Run ninja rebuild inside the eqemu-server container to compile the new C++ binary.
3. Run `make restart` from `/mnt/d/Dev/eq/akk-stack/` to bring Docker containers back up.
4. Start EQ server processes IN ORDER inside the container (from `/home/eqemu/server/`):
   - `shared_memory` (run to completion — one-shot)
   - `loginserver` (wait 3s)
   - `world` (wait 8s)
   - 8 dynamic zones via loop: `for i in 01..08; do nohup ./bin/zone dynamic_$i > logs/zone_dynamic_$i.log 2>&1 & sleep 0.5; done`
5. Verify 8 zone processes are alive: `ps aux | grep 'zone dynamic' | grep -v grep | wc -l` (expect 8).
6. Verify new binary is loaded — check world boot log for build timestamp or grep binary for new diagnostic log string.
7. Notify team lead (orchestrator) that the stack is live and V2-7 (game-tester) can proceed.
8. Commit dev-notes to `bugfix/companion-rerecruit` in the claude repo.

### Critical Rules (from MEMORY.md)

- NEVER use `eqlaunch zone` alongside manually-started zones — causes crash/restart loop.
- Start zone processes FROM `/home/eqemu/server/` so relative log paths resolve.
- `make restart` only restarts Docker containers — EQ processes do NOT auto-start.
- Do NOT notify orchestrator until ALL processes (world + 8 zones) are confirmed running.

### Files to Check / Paths

| What | Path |
|------|------|
| Build command | `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"` |
| make restart | `cd /mnt/d/Dev/eq/akk-stack && make restart` |
| EQ server start | Inside container at `/home/eqemu/server/` |
| World boot log | `akk-stack/server/logs/` (world log, most recent) |
| Zone logs | `akk-stack/server/logs/zone_dynamic_0N.log` |

### Dependency Gate

I must NOT proceed until c-expert sends a message confirming:
- V2-5 complete: Suite 35 passes, Suite 20 passes, all 34 prior suites pass
- C++ fix committed and pushed on `bugfix/companion-rerecruit` in eqemu repo

---

## Stage 1 Status: Complete

---

## Stage 4: Build — Implementation Log

### 2026-04-27 — V2-6 Full Stack Rebuild and Restart

**Dependency gate cleared:**
- V2-2 (lua-expert): akk-stack commit `6358c48` — companion.lua name-match fix, 61/61 Lua tests pass
- V2-5 (c-expert): eqemu commit `478d154b` — companion.cpp:218-220 name-based lookup fix, Suite 35 + Suite 20 + 34 prior suites all pass

**Build:**
- `docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"` → `ninja: no work to do.`
- Binary was already compiled by c-expert during V2-4. ninja confirmed no dirty state.
- Zone binary: `/home/eqemu/code/build/bin/zone` — timestamp `Apr 28 11:06` (today)
- `/home/eqemu/server/bin/zone` is a symlink to build output — running processes use the new binary directly

**make restart:**
- Ran from `/mnt/d/Dev/eq/akk-stack/`
- All containers stopped cleanly, all containers started cleanly
- MariaDB was not immediately ready on first shared_memory attempt (connection refused `#2002`)
- Waited for `mysqladmin ping` to return `mysqld is alive` before retrying — succeeded on second attempt

**EQ process startup (from /home/eqemu/server/):**

| Process | PID | Status | Notes |
|---------|-----|--------|-------|
| shared_memory | one-shot | Completed | Loaded 618 zones, 1,048 rules, DB connected |
| loginserver | 442 | Running | Started 11:10 |
| world | 550 | Running | Started 11:10, version 23.10.3-dev |
| zone dynamic_01 | 686 | Running | Started 11:11 |
| zone dynamic_02 | 689 | Running | Started 11:11 |
| zone dynamic_03 | 692 | Running | Started 11:11 |
| zone dynamic_04 | 698 | Running | Started 11:11 |
| zone dynamic_05 | 706 | Running | Started 11:11 |
| zone dynamic_06 | 708 | Running | Started 11:11 |
| zone dynamic_07 | 711 | Running | Started 11:11 |
| zone dynamic_08 | 713 | Running | Started 11:11 |

**Verification:**
- `ps aux | grep 'zone dynamic' | grep -v grep | wc -l` → `8` (expected 8)
- World boot log: connected to DB, version `23.10.3-dev`, all systems normal
- No `eqlaunch zone` used — all zones started manually per MEMORY.md

**Problems and solutions:**

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| `docker exec -it` failed with "input device is not a TTY" | Non-interactive shell context | Dropped `-it` flag |
| shared_memory failed on first run: `Can't connect to server on 'mariadb' (115)` | MariaDB container not yet accepting connections after `make restart` | Polled with `mysqladmin ping` until ready, then retried — succeeded immediately |

**Stack status:** HEALTHY. New C++ binary (Apr 28 11:06) and updated companion.lua (commit 6358c48) are both live.
