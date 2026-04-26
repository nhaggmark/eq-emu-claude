# Raid Scaling — Dev Notes: perl-expert

> **Feature branch:** `feature/raid-scaling`
> **Agent:** perl-expert
> **Task(s):** L13
> **Date started:** 2026-04-22
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| L13 | Q52=B USER OVERRIDE — Edit `#EmpCycle.pl:3` to soften Emperor respawn from 3-5d to 22-24h | Independent | Complete |

---

## Stage 4: Build

### Implementation Log

#### 2026-04-22 — L13: EmpCycle.pl $EmpRepopTime softened to 22-24h

**What:** Changed `$EmpRepopTime` on line 4 of `#EmpCycle.pl` from `int(rand(2880)) + 4320` (3-5 day range) to `int(rand(7200)) + 79200` (22-24h range). Updated inline comment to reference Decision #52 user override.

**Where:** `/mnt/d/Dev/eq/akk-stack/server/quests/ssratemple/#EmpCycle.pl` line 4

**Why:** Decision #52=B user override per architecture doc line 54. Endgame tier respawn policy (Decision #8) is 24h; Emperor's native 3-5 day script-cycle makes the encounter too infrequent for a 1-3 player server. One-line change to the script-driven timer variable only — no other script logic touched.

**Notes:**
- Architecture doc references "line 3" but actual line with `$EmpRepopTime` is line 4 (blank line 2 in the file). Content match was exact.
- `$BloodCoolDownTime` (line 3, 3-4h failure cooldown) was NOT changed per Decision #11 and architecture doc.
- File was never previously git-tracked in akk-stack (server/ is gitignored). Used `git add -f` to force-add, matching the pattern of prior quest script commits (e.g. f98843d).
- `perl -c` syntax check passed clean before commit.
- Commit: `2155bc1` on `feature/raid-scaling` in akk-stack repo, pushed to origin.

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/ssratemple/#EmpCycle.pl` | Modified + first-time tracked | `$EmpRepopTime` 3-5d → 22-24h per Decision #52 |

---

## Context for Next Agent

L13 is complete and committed. The Emperor cycle respawn is now 22-24h post-kill. The script is now tracked in git for the first time (force-added over gitignore). The git history in akk-stack is the rollback mechanism for this change per architecture doc.

The change does NOT take effect until the world/zone process reloads the script — config-expert and infra-expert handle that.
