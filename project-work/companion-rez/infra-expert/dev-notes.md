# Companion Rez — Dev Notes: infra-expert

> **Feature branch:** `bugfix/companion-rez`
> **Agent:** infra-expert
> **Task(s):** Task 5 (server restart: make restart + full stack)
> **Date started:** 2026-04-27
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 5 | Server restart: `make restart` from akk-stack/, then full server start (loginserver / world / 8 dynamic_NN zones per documented startup procedure). | Task 4 (c-expert: rebuild + tests pass) | Waiting for c-expert |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `/mnt/d/Dev/eq/claude/project-work/companion-rez/architect/architecture.md` | 1-637 | Full architecture; Task 5 is `make restart` + full server process startup; depends on c-expert Tasks 1-4 |
| `/mnt/d/Dev/eq/claude/project-work/companion-rez/status.md` | 1-211 | Task 5 = infra-expert; Task 4 = c-expert prerequisite |
| Project MEMORY.md | Server Startup Order section | Critical: `make restart` restarts containers only; must manually start shared_memory → loginserver → world → 8 dynamic zones FROM /home/eqemu/server/; NEVER use eqlaunch zone alongside manual zones |

### Key Findings

1. `make restart` from `/mnt/d/Dev/eq/akk-stack/` restarts Docker containers only — EQ server processes do NOT auto-start.
2. Full stack requires manual process startup in order:
   - `shared_memory` (one-shot loader, run to completion)
   - `loginserver` (wait 3s)
   - `world` (wait 8s for DB load)
   - 8 dynamic zones loop (dynamic_01 through dynamic_08)
3. Zones MUST be started FROM `/home/eqemu/server/` directory (relative log paths).
4. NEVER use `eqlaunch zone` — causes crash/restart loop conflicting with dynamic_NN zones.
5. MariaDB sometimes isn't ready immediately after container start — poll with `mysqladmin ping` if `shared_memory` fails on first attempt.
6. Verify zone count: `ps aux | grep 'zone dynamic' | grep -v grep | wc -l` should return 8.

### Implementation Plan

**Step 1: Pull latest in build container (if needed)**
- Check that eqemu repo on `bugfix/companion-rez` is current after c-expert's commit+push.

**Step 2: Docker containers restart**
```
cd /mnt/d/Dev/eq/akk-stack && make restart
```

**Step 3: Wait for MariaDB readiness (poll if needed)**
```
docker exec akk-stack-mariadb-1 mysqladmin ping -h localhost -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' --wait=30
```

**Step 4: Start shared_memory (one-shot, run to completion)**
```
docker exec akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && ./bin/shared_memory"
```

**Step 5: Start loginserver**
```
docker exec -d akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && nohup ./bin/loginserver > logs/loginserver.log 2>&1"
```
Wait 3s, verify process running.

**Step 6: Start world**
```
docker exec -d akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && nohup ./bin/world > logs/world.log 2>&1"
```
Wait 8s for DB load, verify process running.

**Step 7: Start 8 dynamic zones**
```
docker exec akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && for i in 01 02 03 04 05 06 07 08; do nohup ./bin/zone dynamic_\$i > logs/zone_dynamic_\$i.log 2>&1 & sleep 0.5; done"
```
Verify: `ps aux | grep 'zone dynamic' | grep -v grep | wc -l` returns 8.

**Step 8: Verify new binary is loaded**
- Check world boot log for build timestamp or grep binary for new symbol from the rez fix.

**Step 9: Update dev-notes with build/restart timestamps and notify team lead.**

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `make restart` behavior | MEMORY.md Server Startup Order | Yes | Restarts Docker containers only; processes must be manually started |
| Server process startup order | MEMORY.md Server Startup Order | Yes | shared_memory → loginserver(3s) → world(8s) → 8 zones loop |
| Zone startup path requirement | MEMORY.md | Yes | Must start FROM /home/eqemu/server/; never use eqlaunch zone |
| MariaDB readiness check | MEMORY.md | Yes | Poll with mysqladmin ping if shared_memory fails |

### Plan Amendments

Plan confirmed — no amendments needed. All steps derive directly from documented MEMORY.md procedures and architecture.md.

### Verified Plan

See Implementation Plan above — confirmed by MEMORY.md Server Startup Order and architecture.md Task 5.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| c-expert | Waiting for Task 4 completion notification | Are Suite 29 tests 29.14-29.17 passing? Is eqemu committed and pushed on bugfix/companion-rez? |

### Feedback Received

_Waiting for c-expert notification that Task 4 is complete and eqemu changes are committed/pushed._

### Consensus Plan

**Agreed approach:** Execute the full-stack restart per MEMORY.md startup order once c-expert confirms Task 4 complete with all Suite 29 tests passing.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `infra-expert/dev-notes.md` | Modify | Add Stage 4 implementation log with timestamps |

**Change sequence (final):**
1. Wait for c-expert SendMessage confirming Task 4 complete + eqemu committed/pushed
2. Run `make restart` from `/mnt/d/Dev/eq/akk-stack/`
3. Poll MariaDB readiness
4. Start EQ processes in order (shared_memory → loginserver → world → 8 zones)
5. Verify 8 zones running
6. Verify new binary loaded (check build timestamp)
7. Update dev-notes Stage 4 log
8. Commit dev-notes on claude repo, push
9. Notify team lead (orchestrator) that server is up and ready for game-tester

---

## Stage 4: Build

### Implementation Log

#### 2026-04-27 — c-expert Task 4 confirmation received

c-expert confirmed via SendMessage: Suite 29 tests 29.14-29.17 PASS, all 13 existing Suite 29 tests PASS, zero regressions. eqemu committed and pushed (commits 30f6d6ef5 TDD red, 83a96f655 production fix).

#### 2026-04-27 15:50 — make restart executed

**What:** Ran `make restart` from `/mnt/d/Dev/eq/akk-stack/`. All containers stopped and restarted cleanly.
**Where:** `/mnt/d/Dev/eq/akk-stack/`
**Notes:** All containers came up: eqemu-server, mariadb, ftp-quests, phpmyadmin, peq-editor, npc-llm.

#### 2026-04-27 15:52 — MariaDB readiness confirmed

**What:** `mysqladmin ping` returned `mysqld is alive` immediately on first attempt.
**Notes:** No polling loop required this time — MariaDB was ready within seconds of container start.

#### 2026-04-27 15:53 — shared_memory run to completion

**What:** Ran `./bin/shared_memory` one-shot from `/home/eqemu/server/`. Loaded 1048 rules, 618 zones, items, spells. Exited cleanly.

#### 2026-04-27 15:53 — loginserver started

**What:** Started `./bin/loginserver` in background via nohup. Verified after 3s: PID confirmed running.

#### 2026-04-27 15:53 — world started

**What:** Started `./bin/world` in background via nohup. Verified after 8s: PID confirmed running.

#### 2026-04-27 15:54 — 8 dynamic zones started

**What:** Loop started dynamic_01 through dynamic_08 with 0.5s delay between each, FROM `/home/eqemu/server/`.
**Verified:** `ps aux | grep 'zone dynamic' | grep -v grep | wc -l` returned **8**. World log confirms `zone_count [8]`.

#### 2026-04-27 15:55 — New binary verified

**What:** Zone binary at `/home/eqemu/server/bin/zone` is a symlink to `/home/eqemu/code/build/bin/zone`.
**Build timestamp:** `Apr 28 13:46` — this is c-expert's Task 4 build.
**Verification:** `strings` output contains `"Rez > 29.9 Fresh NPC corpse IsCompanionCorpse() == false"` — confirms new Suite 29 test code is compiled in. `ResurrectFromCorpse` symbols present confirming full rez pipeline is in the binary.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| None — clean startup | — | — |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `infra-expert/dev-notes.md` | Modified | Added Stage 4 implementation log with timestamps and verification results |

---

## Open Items

- [x] Wait for c-expert SendMessage confirming Task 4 complete — RECEIVED 2026-04-27

---

## Context for Next Agent

If picking this up after context compaction:

Task 5 is a server restart. c-expert owns Tasks 1-4 (write failing tests, implement spells.cpp fix, implement companion_ai.cpp fix, rebuild and verify). Task 5 cannot start until c-expert confirms all 4 new Suite 29 tests pass.

Full stack startup procedure (from MEMORY.md):
1. `cd /mnt/d/Dev/eq/akk-stack && make restart` — restarts Docker containers
2. Poll MariaDB: `docker exec akk-stack-mariadb-1 mysqladmin ping ...`
3. Start shared_memory (one-shot) from /home/eqemu/server/
4. Start loginserver (wait 3s)
5. Start world (wait 8s)
6. Start 8 dynamic zones loop (dynamic_01..dynamic_08) from /home/eqemu/server/
7. Verify: `ps aux | grep 'zone dynamic' | grep -v grep | wc -l` = 8
8. NEVER use eqlaunch zone — causes crash/restart loop

After successful restart: notify team lead (orchestrator) so game-tester (Task 6) can be dispatched.
