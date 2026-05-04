# Universal Summon Corpse Spell — Dev Notes: Infra Expert

> **Feature branch:** `feature/summon-corpse-spell`
> **Agent:** infra-expert
> **Task(s):** Task 10
> **Date started:** 2026-05-03
> **Current stage:** Plan (holding — waiting for tasks 4 and 9 to complete)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 10 | Rebuild zone/world binaries; restart full stack per MEMORY.md startup order; apply data-expert's auto-scribe migration SQL and config-expert's rule_values seed SQL | Tasks 4 (c-expert), 9 (data-expert) | Holding |

---

## Stage 1: Plan

### Key Findings from Architecture Read

- **No infra changes required** — no new Docker services, no volume changes, no compose file modifications. Task 10 is purely build + deploy.
- **SQL expected locations:** Data-expert will produce a bundled transactional migration (tasks 3, 5, 6, 7, 8 bundled in task 9). Config-expert's rule_values seed (task 8) is included in that same bundle via data-expert. Need to confirm exact file path once data-expert commits — expected at `claude/project-work/feature-summon-corpse-spell/data-expert/` or possibly `akk-stack/server/sql/`.
- **Build target:** `docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`. Container is currently running (confirmed: Up 28 hours).
- **Critical ordering from architecture §Risk Assessment:** The new `spells_new` rows MUST be in the DB before `shared_memory` starts, because `shared_memory` reads the spell table into the in-memory dat file. If shared_memory runs before migration, the new spell IDs won't be in the shared dat and the server won't recognize them. Therefore: **migration FIRST, then full-stack restart**.
- **Migration caution:** Architecture §Pass 3 item 12 notes that players logged in during migration won't see the auto-scribed spell until next login. Full-stack restart forces all sessions to re-login, so this is covered.
- **`kUniversalSummonCorpseCategory` constant:** C-expert will set this to whatever value data-expert assigns. Both have to agree — this is a cross-agent coordination item. I don't need to know the value; I just need the build to succeed.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `claude/project-work/feature-summon-corpse-spell/infra-expert/dev-notes.md` | Modify | Stage 4 implementation log |
| `claude/project-work/feature-summon-corpse-spell/status.md` | Modify | Task 10 status → In Progress → Complete |
| `claude/tmp/feature-summon-corpse-spell/` | Create dir | Backup SQL dump stored here (gitignored) |

**Change sequence:**
1. Pull latest `feature/summon-corpse-spell` in all repos (eqemu, akk-stack, claude) to get c-expert's and data-expert's committed work.
2. Rebuild server binary inside container: `docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`. Capture last 20 lines. If build fails, STOP and report to team-lead.
3. Back up affected tables before any SQL: `docker exec akk-stack-mariadb-1 sh -c "mariadb-dump -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq spells_new items merchantlist character_spells rule_values > /tmp/pre-summon-corpse-deploy-$(date +%s).sql"` then copy to `claude/tmp/feature-summon-corpse-spell/`.
4. Apply config-expert's rule_values SQL (if delivered as a separate file) or confirm it's included in data-expert's bundled migration.
5. Apply data-expert's bundled transactional migration SQL.
6. Run data-expert's validation queries (expected in their dev-notes or migration file header comments) — confirm row counts.
7. Restart full stack per MEMORY.md: `make restart` → shared_memory → loginserver → world → 8 zone processes (dynamic_01..dynamic_08). Do NOT use eqlaunch zone.
8. Verify all processes: `ps aux | grep -E "loginserver|world|zone" | grep -v grep`.

**What to test / verify:**
- Ninja build exits 0
- Backup SQL written and copied to `claude/tmp/`
- Migration applies without SQL errors (transaction commits)
- Validation query row counts match expectations
- `ps aux` confirms loginserver + world + 8 zone dynamic processes running

### Hold Conditions

Do not proceed to Stage 4 until team-lead explicitly gives the go-ahead AND:
- Task 4 (c-expert engine changes) is marked Complete in status.md
- Task 9 (data-expert bundled migration) is marked Complete in status.md
- SQL file path is known (data-expert confirms location)

---

## Stage 2: Research

### Documentation Consulted

The architecture doc fully specifies every command needed. No novel syntax to verify via Context7 — all commands are standard docker exec, mariadb-dump, and the project's established build pattern.

Key architecture cross-references verified:
- Build command: matches `akk-stack/` conventions (`docker exec akk-stack-eqemu-server-1`)
- Startup order: matches MEMORY.md "Server Startup Order (FULL STACK)" verbatim
- Migration-before-shared_memory requirement: architecture §Risk Assessment item 4
- Backup path: `claude/tmp/feature-summon-corpse-spell/` (gitignored per CLAUDE.md)

### Plan Amendments

Plan confirmed — no amendments needed.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| team-lead | Ready and standing by | Confirming readiness, awaiting go-ahead |

### Feedback Received

_Waiting._

### Consensus Plan

See Implementation Plan in Stage 1 — no amendments from socialization yet. Will update when team-lead confirms go-ahead and SQL file location is known.

---

## Stage 4: Build

_Not started — holding for team-lead go-ahead._

### Implementation Log

_To be filled in when build starts._

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| | | |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| | | |

---

## Open Items

- [ ] Confirm SQL file location from data-expert once task 9 is complete
- [ ] Confirm c-expert's task 4 is committed before pulling repos
- [ ] Await team-lead go-ahead to begin Stage 4

---

## Context for Next Agent

If picking up this task after context compaction: infra-expert is responsible for Task 10 only. The plan is in Stage 1 above. The hold condition is team-lead explicitly saying "go". Once given the green light:
1. Pull all repos on feature/summon-corpse-spell
2. Rebuild with ninja inside akk-stack-eqemu-server-1
3. Backup tables (spells_new, items, merchantlist, character_spells, rule_values) to `/tmp/` inside mariadb container, copy to `claude/tmp/feature-summon-corpse-spell/`
4. Apply data-expert's bundled migration SQL (find path in data-expert/dev-notes.md or migrations/)
5. Run validation queries
6. Full-stack restart per MEMORY.md (shared_memory → loginserver → world → 8 zones via loop, NOT eqlaunch)
7. Verify processes
8. Report to team-lead
