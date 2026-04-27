# XP Retune — Dev Notes: Infra Expert

> **Feature branch:** `feature/xp-retune`
> **Agent:** infra-expert
> **Task(s):** C — Rebuild + restart full server stack
> **Date started:** 2026-04-27
> **Current stage:** Waiting for c-expert (Task B) to complete before Stage 4

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| C | Rebuild eqemu, restart loginserver → world → 8 dynamic zones, verify all 8 healthy | Task B (c-expert clean build) | Waiting |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `claude/project-work/xp-retune/architect/architecture.md` | all | Full v2 plan: Task C detailed brief, startup order, 5-task dependency chain |
| `claude/project-work/xp-retune/status.md` | all | Current state: Implementation not started; Task C depends on B |
| `claude/MEMORY.md` (Server Startup Order) | — | Canonical startup order: shared_memory → loginserver (3s) → world (8s) → 8 dynamic zones |

### Key Findings

- Task C depends entirely on Task B (c-expert) producing a clean build. Nothing to do until c-expert notifies.
- The full-stack startup procedure is documented in MEMORY.md under "Server Startup Order (FULL STACK)". Must follow it exactly.
- `make restart` restarts Docker containers ONLY — EQ server processes do NOT auto-start.
- CRITICAL: Do NOT use `eqlaunch zone` alongside manual zones — causes crash/restart loop.
- Start zones FROM `/home/eqemu/server/` directory (relative log paths).
- Verify: `ps aux | grep 'zone dynamic' | grep -v grep | wc -l` should return 8.
- Two companion XP dispatch sites were patched in Task B (`exp.cpp` + `attack.cpp`); the rebuild must reflect both.
- After restart, tail `world.log` and at least one zone log to confirm no exceptions on the refactored XP path.

### Implementation Plan

**Change sequence:**

1. Receive notification from c-expert that Task B is committed + pushed on `feature/xp-retune` in eqemu.
2. Pull latest on `feature/xp-retune` inside the build container if the local copy is behind:
   `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code && git pull"`
3. Rebuild:
   `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
   - Capture full build output. Any errors → STOP. Ping team lead. Do not proceed.
4. `make restart` from `/mnt/d/Dev/eq/akk-stack/` to bring Docker containers up.
5. Start EQ server processes IN ORDER inside the container, all from `/home/eqemu/server/`:
   a. `shared_memory` — run to completion (one-shot loader):
      `docker exec akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && ./bin/shared_memory"`
   b. `loginserver` — start, then wait 3s:
      `docker exec -d akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && nohup ./bin/loginserver > logs/loginserver.log 2>&1 &"`
   c. `world` — start, then wait 8s for DB load:
      `docker exec -d akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && nohup ./bin/world > logs/world.log 2>&1 &"`
   d. 8 dynamic zones — start all with 0.5s stagger:
      ```
      docker exec akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && for i in 01 02 03 04 05 06 07 08; do nohup ./bin/zone dynamic_\$i > logs/zone_dynamic_\$i.log 2>&1 & sleep 0.5; done"
      ```
6. Verify zone count:
   `docker exec akk-stack-eqemu-server-1 bash -c "ps aux | grep 'zone dynamic' | grep -v grep | wc -l"` (expect 8)
7. Tail world.log for clean startup and no XP-path exceptions:
   `docker exec akk-stack-eqemu-server-1 bash -c "tail -50 /home/eqemu/server/logs/world.log"`
8. Verify new binary reflects new code — check build timestamp or grep binary for `CalculateExp`:
   `docker exec akk-stack-eqemu-server-1 bash -c "strings /home/eqemu/server/bin/zone | grep -i 'CalculateExp' | head -5"`
9. Notify config-expert via SendMessage: stack is healthy, proceed with Task D.
10. Update dev-notes.md Stage 4 with timestamps and any issues.
11. Commit dev-notes.md on `feature/xp-retune` in claude repo. Push.

**What to test:**
- Build exits zero (no errors, no undefined symbol)
- `ps` shows 8 zone dynamic processes
- world.log clean — no crash, no exception in companion or exp paths
- New binary symbol present (`Companion::CalculateExp` or similar)

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `ninja -j$(nproc)` inside container | MEMORY.md + architecture.md | Yes | Standard build cmd; same as all prior builds |
| `make restart` | akk-stack/Makefile (known from MEMORY.md) | Yes | Documented restart path |
| `nohup ./bin/zone dynamic_NN` startup loop | MEMORY.md "Server Startup Order" | Yes | Exact pattern from canonical memory |
| Process verification `ps aux | grep 'zone dynamic'` | MEMORY.md | Yes | Expect 8 |
| eqlaunch exclusion | MEMORY.md "CRITICAL zone pool rules" | Yes | Must NOT use eqlaunch alongside manual zones |
| `strings` / binary grep for new symbol | Standard Linux tool | Yes | Sanity check that new code is linked in |
| `docker exec -it` vs `-d` for detached | Docker docs (prior experience) | Yes | `-d` for daemonized, no `-it` needed for background procs |

### Plan Amendments

Plan confirmed — no amendments needed. The startup procedure is canonically documented in MEMORY.md and matches the architecture.md Task C brief exactly. The only addition is the binary verification step (strings grep for `CalculateExp`) which provides evidence the new code is linked before handing off to config-expert.

### Verified Plan

See Implementation Plan above — confirmed by research. Startup order, zone count, and eqlaunch exclusion all verified against MEMORY.md.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| c-expert | Task C dependency check | Will notify me when Task B build is clean and committed on feature/xp-retune? |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| c-expert | Awaiting — plan posted, waiting for Task B completion notification | Will update when received |

### Consensus Plan

Agreed approach: Execute exactly as documented in Stage 1 Implementation Plan. No changes from socialization pending — c-expert must confirm clean build before Stage 4 begins.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `claude/project-work/xp-retune/infra-expert/dev-notes.md` | Modify | Stage 4 log, timestamps, build/restart output |
| `claude/project-work/xp-retune/status.md` | Modify | Task C → In Progress, then Complete |

**Change sequence (final):**
1. Wait for c-expert notification
2. Pull latest on feature/xp-retune in container
3. Rebuild with ninja
4. `make restart` Docker containers
5. Start server processes in order (shared_memory → loginserver → world → 8 zones)
6. Verify 8 zones healthy, world.log clean
7. Verify new binary linked
8. Notify config-expert
9. Update status.md + dev-notes.md, commit + push claude repo

---

## Stage 4: Build

**Started:** 2026-04-27 ~18:05
**Completed:** 2026-04-27 ~18:10

### Implementation Log

#### 2026-04-27 — Binary verification pre-restart

**What:** Verified zone binary exists and contains new Companion::CalculateExp symbol before touching running processes.
**Where:** `/home/eqemu/code/build/bin/zone` (inside container)
**Why:** Must confirm Task B's build is live before restarting processes.
**Notes:**
- `ls -la` shows binary timestamped `Apr 27 18:03` — matches c-expert's Task B build time.
- `strings | grep CalculateExp` returned `_ZN9Companion12CalculateExpEjh` (mangled symbol, appeared twice — normal). Confirms `Companion::CalculateExp(uint32, uint8)` is linked into the zone binary.
- Build healthy. Proceeded with restart.

#### 2026-04-27 — make restart (Docker containers)

**What:** `cd /mnt/d/Dev/eq/akk-stack && make restart`
**Where:** Host WSL, akk-stack Makefile
**Why:** Bring all containers down and back up clean before starting EQ processes.
**Notes:** All containers stopped and restarted cleanly. No errors. All services back up: eqemu-server, mariadb, ftp-quests, phpmyadmin, peq-editor, npc-llm, proxies, fail2ban.

#### 2026-04-27 — shared_memory (one-shot loader)

**What:** `cd /home/eqemu/server && ./bin/shared_memory` (run to completion)
**Where:** Inside akk-stack-eqemu-server-1
**Why:** Loads game data into shared memory before world/zones start.
**Notes:** Connected to DB, loaded 1,048 rules (ruleset_id=1 "default"), 618 zones. No errors. Expansion context: Luclin (3). `Character:ExpMultiplier='2.0'` (Task A) loaded.

#### 2026-04-27 — loginserver

**What:** `nohup ./bin/loginserver > logs/loginserver.log 2>&1 &` then waited 3s
**Where:** Inside container, from `/home/eqemu/server/`
**Why:** Must be running before world starts.
**Notes:** PID 394 confirmed running after 3s. No issues.

#### 2026-04-27 — world

**What:** `nohup ./bin/world > logs/world.log 2>&1 &` then waited 8s for DB load
**Where:** Inside container, from `/home/eqemu/server/`
**Why:** Core server process; connects to DB and loginserver, manages zone registration.
**Notes:** PID 506 confirmed running after 8s. world.log clean: connected to DB and loginserver at `127.0.0.1:5998`, sending server info `long_name=[Haggmark EQ Server]`. Address warnings (LAN vs WAN IP) are pre-existing config, not errors. No XP-path exceptions.

#### 2026-04-27 — 8 dynamic zone processes

**What:** `for i in 01..08; do nohup ./bin/zone dynamic_$i > logs/zone_dynamic_$i.log 2>&1 & sleep 0.5; done`
**Where:** Inside container, from `/home/eqemu/server/`
**Why:** Zone pool for player gameplay.
**Notes:**
- All 8 dispatched with 0.5s stagger.
- After 5s: `ps aux | grep 'zone dynamic' | grep -v grep | wc -l` = **8** (verified).
- zone_dynamic_01.log: loaded rules, zones, tasks, quest scripts cleanly; entered sleep mode; world assigned port 7001; EQ network server started on 7001.
- world.log tail: `zone_count [8]` confirmed; dynamic_08 on port 7007 (ports 7001-7008 in use).
- No exceptions in companion or exp paths in any log.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| None encountered | — | — |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `claude/project-work/xp-retune/infra-expert/dev-notes.md` | Modified | Stage 4 execution log |
| `claude/project-work/xp-retune/status.md` | Modified | Tasks B and C marked Complete |
| `claude/project-work/xp-retune/agent-conversations.md` | Modified | Implementation Team section; c-expert notification logged |

---

## Open Items

- [x] Wait for c-expert notification (Task B complete, clean build on feature/xp-retune)
- [x] Execute Stage 4 build/restart procedure
- [x] Notify config-expert when stack is healthy (Task D can proceed)
- [ ] Commit dev-notes.md + status.md + agent-conversations.md on feature/xp-retune in claude repo and push

---

## Context for Next Agent

If picking up this work after context compaction: infra-expert owns Task C (rebuild + restart). The full startup procedure is in MEMORY.md under "Server Startup Order (FULL STACK)". The consensus plan in Stage 3 above is self-contained — follow it step by step. Key risk: do NOT use eqlaunch zone alongside manual zone starts. Verify 8 zones with `ps` before notifying config-expert. If the build fails, stop and ping the team lead (orchestrator) immediately — do not hand off to config-expert under a partial state.
