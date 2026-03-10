# companion-aggro-fixes — Status Tracker

> **Feature branch:** `bugfix/companion-aggro-fixes`
> **Created:** 2026-03-08
> **Last updated:** 2026-03-08

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-08 | 2026-03-08 |
| Design | game-designer + lore-master | Skipped | — | — |
| Architecture | architect | Complete | 2026-03-08 | 2026-03-08 |
| Implementation | c-expert | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-08
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.

### architect → implementation team (c-expert)
- **Date:** 2026-03-08
- **Notes:** Root cause identified: `Companion` class does not override
  `IsOfClientBotMerc()` or `IsOfClientBot()`, causing companions to be
  wiped from NPC hate lists every AI tick by `WipeHateList(true)`.
  Fix requires 2 lines in `companion.h` and ~6 lines in `hate_list.cpp`.
  Only c-expert is needed — no SQL, Lua, or config changes required.
  Architecture doc at `architect/architecture.md`.

---

## Implementation Tasks

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Add `IsOfClientBot()` and `IsOfClientBotMerc()` overrides to `companion.h` | c-expert | Not Started | 2 lines, type identification section |
| 2 | Add companion recognition in SmartAggroList in `hate_list.cpp` | c-expert | Not Started | ~6 lines, after Merc check |
| 3 | Build and verify compilation | c-expert | Not Started | Single build cycle |

---

## Open Questions

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| | None | | | | |

---

## Blockers

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| None | | | |

---

## Bug Reports

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| 1 | Companions generate no hate/aggro on mobs — melee, spells, heals, and taunt all ignored | Critical | user | Fix Planned | c-expert | |

---

## Decision Log

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Override `IsOfClientBotMerc()` and `IsOfClientBot()` rather than modifying `WipeHateList()` | architect | 2026-03-08 | Fixing the classification at the source (Companion class) fixes all systems that check these methods, not just the hate list wipe. Matches Bot and Merc patterns. |
| 2 | Add companion check to SmartAggroList rather than using `AllowedToTank` special ability | architect | 2026-03-08 | `AllowedToTank` is a per-NPC special ability that would need to be set on every companion spawn. A class-level check is cleaner and guaranteed. |

---

## Completion Checklist

### Implementation Complete (agents can check these)

- [ ] All implementation tasks marked Complete
- [ ] No open Blockers
- [ ] game-tester server-side validation: PASS
- [ ] User completed in-game testing guide: PASS
- [ ] All changes committed and pushed to feature branch in ALL repos
- [ ] Server rebuilt (if C++ changed)
- [ ] All phases marked Complete in Workflow Status table

### Merge & Cleanup (USER-INITIATED ONLY)

- [ ] User confirmed feature is complete
- [ ] Feature branch merged to main in ALL affected repos
- [ ] Main pushed to origin in ALL affected repos
- [ ] Stale feature branches deleted (local + remote)

**Merged by:** _name_
**Merge date:** _YYYY-MM-DD_

---

## Notes

**Root cause:** `Companion::IsOfClientBotMerc()` returns `false` (inherited
default), causing `WipeHateList(true)` in `mob_ai.cpp:1074` to purge
companion entries from NPC hate lists every AI tick. Fix is 2 overrides in
companion.h + SmartAggroList recognition in hate_list.cpp.

**Detailed analysis:** See `architect/context/root-cause-analysis.md`
