# Raid Scaling — Dev Notes: infra-expert

> **Feature branch:** `feature/raid-scaling`
> **Agent:** infra-expert
> **Task(s):** 9 (conditional)
> **Date started:** 2026-04-22
> **Current stage:** Standby — waiting on config-expert Task 8 result

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 9 | Full-stack restart if `#reloadworld` doesn't propagate npc_spells_entries cache | config-expert Task 8 result | STANDBY (conditional) |

---

## Stage 1: Plan

### Context

Task 9 is conditional. It runs ONLY if config-expert (Task 8) reports that `#reloadworld` failed to propagate `npc_spells_entries` cache changes into running zone processes. The architecture notes that `NPC::AICastSpell()` reads from an in-memory spell list populated at NPC spawn, and `#reloadworld` should rebuild it — but if zone processes have already-spawned NPCs with stale spell lists, a full restart is the reliable fix.

### Files Examined

| File | What I Found |
|------|-------------|
| `architect/architecture.md` | Task 9 described at Implementation Sequence #9; full-stack startup per MEMORY.md "Server Startup Order" |
| `config-expert/dev-notes.md` | Tasks 7 and 8 are WAITING on data-expert; smoke verification targets documented |
| `data-expert/dev-notes.md` | Tasks 1-6 and 10 all Complete as of 2026-04-22; SQL applied |
| MEMORY.md (user memory) | Full-stack startup order documented in detail |

### Implementation Plan (if triggered)

**Trigger condition:** config-expert Task 8 reports that smoke verification failed specifically because `npc_spells_entries` changes (spell 982 deletion) are not reflected in zone NPC behavior, even after `#reloadworld`.

**Execution sequence:**

1. `cd /mnt/d/Dev/eq/akk-stack && make restart` — restart Docker containers
2. Inside `akk-stack-eqemu-server-1`, from `/home/eqemu/server/`:
   - Run `shared_memory` (run to completion, one-shot)
   - `nohup ./bin/loginserver > logs/loginserver.log 2>&1 &` (wait 3s)
   - `nohup ./bin/world > logs/world.log 2>&1 &` (wait 8s for DB load)
   - Start 8 zone processes:
     ```
     for i in 01 02 03 04 05 06 07 08; do
       nohup ./bin/zone dynamic_$i > logs/zone_dynamic_$i.log 2>&1 &
       sleep 0.5
     done
     ```
3. Verify 8 zones running: `ps aux | grep 'zone dynamic' | grep -v grep | wc -l` (expect 8)
4. NEVER use `eqlaunch zone` alongside manually-started zones — causes crash/restart loop

**What to test after restart:**
- `ps aux | grep -E 'loginserver|world|zone' | grep -v grep` — confirm all processes running
- Notify config-expert to re-run smoke verification (Task 8) post-restart

---

## Stage 2: Research

Startup sequence verified against MEMORY.md "Server Startup Order" section (authoritative). No documentation research needed — this is a direct execution of the documented procedure with no novel Docker/Makefile changes.

### Plan Amendments

Plan confirmed — no amendments needed. The startup sequence is fully specified in project memory.

---

## Stage 3: Socialize

No socialization required. Task 9 is a standard server restart using the documented procedure. No cross-system dependencies. Config-expert will trigger this task directly if needed.

---

## Stage 4: Build

### Implementation Log — Task L-restart attempt 1 (2026-04-22, pre-smoke)

**Note:** This restart ran before config-expert completed smoke verification. It established a clean process state but was superseded by the definitive restart below.

**Step 1 — Docker containers:** SUCCESS
**Step 2 — EQ server processes:** all started (shared_memory, loginserver, world, 8 zones)
**DB spot-check (initial — FALSE ALARM):** Query ran during MariaDB reconnect window post-restart; appeared to show spell 2859 in list 196 but data-expert confirmed DELETE was already applied. Same reconnect-window issue affected config-expert earlier in the phase.

---

### Implementation Log — Task L-restart (definitive, 2026-04-22, post-smoke)

**Trigger:** Config-expert L-smoke PASS (71 checks). Required to flush akheva zone process in-memory spell list cache after npc_spells_entries DELETE (spell 2859 from list 196). Same pattern as Phase 2 Cazic Touch / Decision #16. `#reloadworld` does NOT flush zone spell-list cache.

**Step 1 — Docker containers:**
- `cd /mnt/d/Dev/eq/akk-stack && make restart` — SUCCESS
- All containers up: mariadb, eqemu-server, phpmyadmin, peq-editor, npc-llm, ftp-quests

**Step 2 — EQ server processes (inside akk-stack-eqemu-server-1, from /home/eqemu/server/):**
- Waited for MariaDB ready (`mysqladmin ping --wait=30`)
- `shared_memory` — completed successfully
- `loginserver` — started
- `world` — started (waited 8s)
- 8 zone processes (dynamic_01–08) — all started

**Verification:**
- Zone count: 8 (`ps aux | grep 'zone dynamic' | grep -v grep | wc -l` = 8)
- World log: clean — all 8 zones registered, no crash/restart loop
- Containers: all core containers healthy

**DB spot-check (post-5s settle — CLEAN):**
```sql
SELECT npc_spells_id, spellid FROM npc_spells_entries WHERE spellid=2859 AND npc_spells_id IN (179, 196);
npc_spells_id  spellid
179            2859      ← Shei Vinitras, preserved per Decision #60
                         ← list 196: zero rows (Touch of Vinitras DELETE confirmed)
```
Zone processes now boot with clean spell list from DB. Spell 2859 cannot be loaded into akheva zone cache from list 196.

### Files Modified (final)

_None — full-stack restart is an operational procedure, not a file change._

---

## Open Items

- [x] Task L-restart — COMPLETE (2026-04-22, definitive restart post-smoke). DB spot-check clean.

---

## Context for Next Agent

Task L-restart is complete. Definitive full-stack restart executed 2026-04-22 after config-expert L-smoke PASS (71 checks). Zone spell caches are now loaded from clean DB state — list 196 has zero rows for spell 2859. Server is ready for game-tester validation.

---

## Phase 5b — Task LB13b: VT Zone-Process Cache Flush Restart

> **Task:** LB13b (REQUIRED — not conditional)
> **Trigger:** config-expert #reloadworld + smoke verify LB13+LB14 complete
> **Date:** 2026-04-22
> **Dependency status:** data-expert Phase 5b SQL (spell 1948 DELETE from list 229) — STATUS UNKNOWN at time of restart (see DB spot-check below)

### Stage 4: Implementation Log — Task LB13b

**Step 1 — Docker containers:**
- `cd /mnt/d/Dev/eq/akk-stack && make restart` — SUCCESS
- All containers up: mariadb, eqemu-server, phpmyadmin, peq-editor, npc-llm, ftp-quests, fail2ban-server, fail2ban-mysqld, peq-editor-proxy, phpmyadmin-proxy

**Step 2 — MariaDB ready check:**
- `mysqladmin ping --wait=30` — `mysqld is alive`

**Step 3 — EQ server processes (inside akk-stack-eqemu-server-1, from /home/eqemu/server/):**
- `shared_memory` — completed successfully (loaded 1048 rules, Luclin expansion, 618 zones)
- `loginserver` — started (PID 430)
- `world` — started (PID 579, waited 8s)
- 8 zone processes (dynamic_01–08) — all started

**Verification:**
- Zone count: 8 (`ps aux | grep 'zone dynamic' | grep -v grep | wc -l` = 8)
- Process list: 1 loginserver + 1 world + 8 zones confirmed
- World log: clean — all 8 zones registered with auto port assignment (7000-7007), no crash/restart loop, no STARTED/STOPPED churn
- Containers: all core containers healthy

**DB spot-check (post-restart):**
```sql
SELECT npc_spells_id, spellid, priority FROM npc_spells_entries
WHERE spellid=1948 AND npc_spells_id IN (229, 489, 540) ORDER BY npc_spells_id;

npc_spells_id  spellid  priority
229            1948     35        ← STILL PRESENT — data-expert Phase 5b SQL not yet applied
489            1948     0         ← Kerafyrm list 489 present (expected)
540            (absent)           ← List 540 (Aten 158096) — no row found
```

**IMPORTANT — DB spot-check FAIL flag:** Spell 1948 is still present in list 229. This means data-expert has NOT yet applied the Phase 5b DELETE (`npc_spells_entries WHERE npc_spells_id=229 AND spellid=1948`). The server restart was executed as dispatched — the clean restart state is established — but the zone processes will NOT have a clean spell cache for list 229 until data-expert applies the DELETE and a subsequent `#reloadworld` (or another restart) propagates the change.

**Also note:** List 540 (Aten Ha Ra 158096) showed no row for spell 1948, which matches the expected pre-implementation state (spell 1948 is Kerafyrm's DT — it should NOT be in list 540 per the Phase 5b architecture).

**Server state:** Running, healthy, all 8 zones up. Ready for data-expert SQL application + config-expert #reloadworld.

### Open Items — LB13b

- [x] Full-stack restart #1 — executed pre-SQL (stale cache, superseded)
- [x] Full-stack restart #2 (definitive) — executed post-SQL DELETE (2026-04-22)
- [x] DB spot-check PASS — list 229: 0 rows; list 489: 1 row (Kerafyrm preserved); list 540: 0 rows
- [x] LB13b COMPLETE — zone processes booted from clean DB; ready for config-expert LB14 smoke verify

---

### Implementation Log — LB13b Restart #2 (definitive, 2026-04-22, post-SQL)

**Trigger:** data-expert confirmed Phase 5b DELETE applied (commit 4eb65f3). Restart #1 ran before SQL was in DB so zone caches held stale list 229. Restart #2 is the definitive cache flush.

**Step 1 — Docker containers:** `make restart` — SUCCESS, all containers up

**Step 2 — EQ server processes (from /home/eqemu/server/):**
- `shared_memory` — completed (Luclin expansion, 1048 rules, 618 zones)
- `loginserver` — started (PID 453)
- `world` — started (PID 550, waited 8s)
- 8 zone processes (dynamic_01–08) — all started, count confirmed = 8

**Verification:**
- Process list: loginserver (453) + world (550) + 8 zones confirmed
- World log: clean — all 8 zones registered on ports 7000–7007, no crash/restart loop

**DB spot-check (post-restart #2, PASS):**
```sql
SELECT npc_spells_id, spellid, priority FROM npc_spells_entries
WHERE spellid=1948 AND npc_spells_id IN (229, 489, 540) ORDER BY npc_spells_id;

npc_spells_id  spellid  priority
489            1948     0         ← Kerafyrm list 489 preserved (correct)
                                  ← list 229: 0 rows (DELETE confirmed)
                                  ← list 540: 0 rows (Aten 158096 never had this spell)
```
Zone processes booted from clean DB state. Spell 1948 cannot load into vexthal zone cache from list 229.
