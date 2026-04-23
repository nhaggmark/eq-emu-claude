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

### Implementation Log

_Not yet triggered. Will be populated if config-expert Task 8 reports #reloadworld failure._

### Files Modified (final)

_None — full-stack restart is an operational procedure, not a file change._

---

## Open Items

- [ ] Waiting on config-expert Task 8 result to determine if Task 9 is needed

---

## Context for Next Agent

Task 9 is a conditional full-stack restart. It runs only if config-expert reports that `#reloadworld` (Task 7) failed to propagate `npc_spells_entries` changes into running zone processes after data-expert's SQL was applied.

Data-expert Tasks 1-6 and 10 are all Complete as of 2026-04-22. SQL has been applied to the `peq` DB. Config-expert is waiting to execute Task 7 (`#reloadworld`) and Task 8 (smoke verification).

If triggered, follow the startup sequence in Stage 1 Implementation Plan above. Do NOT use `eqlaunch zone` alongside manually-started zones. After restart, notify config-expert to re-run smoke verification.
