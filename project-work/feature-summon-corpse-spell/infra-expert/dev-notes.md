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

### Implementation Log

#### 2026-05-03 — Pre-flight checks

Confirmed all prerequisite commits in place on eqemu (c-expert tasks 1+4 committed), akk-stack (data-expert migration at `akk-stack/server/quests/sql/feature_summon_corpse_spell.sql`), and claude repos. eqemu branch: `feature/summon-corpse-spell`.

#### 2026-05-03 — DB backup

Backed up spells_new, items, merchantlist, character_spells, rule_values from live mariadb container to `/mnt/d/Dev/eq/claude/tmp/feature-summon-corpse-spell/pre-summon-corpse-deploy-1777855805.sql` (123MB).

#### 2026-05-03 — Ninja rebuild

Rebuilt all eqemu binaries inside akk-stack-eqemu-server-1. Result: 65/65 targets built, clean exit.

#### 2026-05-03 — Migration validation (pre-restart)

Summary query: new_spells=12, new_items=12, vendor_entries=57, auto_scribed=1, rule_row=1. All counts matched expected values.

#### 2026-05-03 — make restart

Restarted all Docker containers. All containers came back up.

#### 2026-05-03 — shared_memory blocker (NULL varchar columns)

shared_memory crashed at "Loading spells" with `basic_string: construction from null`. Root cause: data-expert's migration left you_cast, other_casts, cast_on_you, cast_on_other, spell_fades as SQL NULL on all 12 new spell rows. Data-expert patched to ''. Held until confirmed.

#### 2026-05-03 — shared_memory blocker (teleport_zone NULL)

shared_memory still crashed. Root cause: teleport_zone also NULL on all 12 new rows (missed in previous fix). Data-expert patched to ''. Held until confirmed.

#### 2026-05-03 — shared_memory blocker (typedescnum NULL)

shared_memory still crashed after both varchar fixes. Root cause: typedescnum (integer) was NULL on all 12 new rows and zero other spells in the entire DB. C++ loader reads this int to look up a string; NULL causes null string lookup and crashes basic_string constructor. Data-expert performed comprehensive 31-column diff against id=3, patched typedescnum=125 and confirmed all remaining nullable cols matched. Held until confirmed.

#### 2026-05-03 — shared_memory SUCCESS

Retried shared_memory after comprehensive NULL fix. Completed cleanly — no error, no exit code 1. All 12 new spell IDs now loaded into shared memory.

#### 2026-05-03 — Full server startup

Started all processes per MEMORY.md:
1. shared_memory (completed above)
2. loginserver (nohup, 3s wait)
3. world (nohup, 8s wait)
4. 8 zone processes dynamic_01..dynamic_08 (loop, 0.5s stagger — NOT eqlaunch)

All 10 processes confirmed running via `ps aux`.

Final validation: new_spells=12, new_items=12, vendor_entries=57, auto_scribed=1, rule_row=1. PASS.

#### 2026-05-04 — Client spells_us.txt regeneration and deploy

**What:** Ran `export_client_files` to regenerate Titanium client data files from the now-correct spells_new table, then deployed to `/mnt/d/EQ/`.

**Binary location:** `/home/eqemu/code/build/bin/export_client_files` (not in ~/server/bin — must be run from ~/server/ dir with export/ subdir created first).

**Commands:**
```
docker exec akk-stack-eqemu-server-1 bash -c "mkdir -p ~/server/export && cd ~/server && ~/code/build/bin/export_client_files"
```
Output: ExportSpells 40734, ExportSkillCaps 58359, ExportBaseData 1600, ExportDBStrings 44580.

**Files exported:** spells_us.txt (27MB), dbstr_us.txt (6.1MB), SkillCaps.txt (799KB), BaseData.txt (61KB).

**Client backup:** `claude/tmp/feature-summon-corpse-spell/client-backup-1777926156/` — contains previous spells_us.txt and dbstr_us.txt (SkillCaps.txt and BaseData.txt were not previously in the client dir).

**Deployed to client:** All 4 files copied to `/mnt/d/EQ/`.

**Verification:** grep confirmed all 12 new spell IDs present in `/mnt/d/EQ/spells_us.txt` with correct names (Conjure Cadaver, Death's Recall, Divine Reclamation, Solemn Retrieval, Nature's Reclamation, Warden's Claim, Ancestral Summons, Ancestral Call, Spectral Translocation, Summon Mortal Remains, Phantasmal Reclamation, Dirge of Homecoming).

**User action required:** Titanium client must be FULLY EXITED and relaunched — a character relog inside a running client is not sufficient to re-read spells_us.txt.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| shared_memory crash: basic_string from null | you_cast/other_casts/cast_on_you/cast_on_other/spell_fades NULL on new spell rows | Data-expert set all to '' |
| shared_memory crash persisted | teleport_zone also NULL on new rows | Data-expert set to '' |
| shared_memory crash persisted | typedescnum NULL on all 12 new rows (unique in entire DB) | Data-expert comprehensive 31-col diff, set typedescnum=125 |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `claude/project-work/feature-summon-corpse-spell/infra-expert/dev-notes.md` | Modified | Stage 4 implementation log |
| `claude/project-work/feature-summon-corpse-spell/status.md` | Modified | Task 10 → Complete |
| `claude/tmp/feature-summon-corpse-spell/` | Created | Pre-migration DB backup (123MB) + client file backups (gitignored) |
| `/mnt/d/EQ/spells_us.txt` | Replaced | Regenerated with 12 new spell entries (40734 total spells) |
| `/mnt/d/EQ/dbstr_us.txt` | Replaced | Regenerated (44580 DB strings) |
| `/mnt/d/EQ/SkillCaps.txt` | Added | New file — was not previously in client dir |
| `/mnt/d/EQ/BaseData.txt` | Added | New file — was not previously in client dir |

---

## Open Items

- [x] SQL file location confirmed: `akk-stack/server/quests/sql/feature_summon_corpse_spell.sql`
- [x] c-expert task 4 committed confirmed
- [x] Team-lead go-ahead received and task 10 complete

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
