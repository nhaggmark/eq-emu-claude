# companion-experience — Status Tracker

> **Feature branch:** `bugfix/companion-experience`
> **Created:** 2026-03-05
> **Last updated:** 2026-03-05 (game-tester validation)

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-05 | 2026-03-05 |
| Design | game-designer + lore-master | Complete | 2026-03-05 | 2026-03-05 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-03-05 | 2026-03-05 |
| Implementation | c-expert + lua-expert | Complete | 2026-03-05 | 2026-03-05 |
| Validation | game-tester | In Progress — awaiting build+restart | 2026-03-05 | |
| Completion | _user_ | Not Started | | |

**Current phase:** Validation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-05
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architecture team (architect + protocol-agent + config-expert)
- **Date:** 2026-03-05
- **Notes:** PRD and lore notes completed and approved. PRD covers BUG-001 fix,
  companion XP distribution, and companion leveling. Lore-master approved all
  era compliance items. Level 60 hard cap confirmed as mandatory.

### architect → implementation team (c-expert + lua-expert)
- **Date:** 2026-03-05
- **Notes:** Architecture plan completed. 5 tasks in dependency order:
  1. Kill credit fix in attack.cpp (c-expert) — no dependencies
  2. XP distribution in exp.cpp + attack.cpp (c-expert) — depends on 1
  3. Leveling fixes in companion.cpp (c-expert) — depends on 1
  4. GetXPForNextLevel Lua binding (c-expert) — depends on 3
  5. !status XP display in companion.lua (lua-expert) — depends on 4

  Only two experts needed: c-expert (tasks 1-4) and lua-expert (task 5).

### implementation team → game-tester
- **Date:** 2026-03-05
- **Notes:** All 5 tasks verified complete by code review (commits eqemu 5c10f2cf6,
  akk-stack cd382fb). Code review confirms all architecture plan changes are correctly
  implemented. Server-side validation result: PASS WITH WARNINGS (build rebuild required,
  log analysis pending). In-game testing guide delivered at
  `game-tester/test-plan.md`. User must rebuild the server before testing.
  11 tests covering AC-1 through AC-11, plus 5 edge case tests.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Fix kill credit resolution for companions in NPC::Death | c-expert | Complete | Root cause of BUG-001. Verified in attack.cpp lines 2642-2653. |
| 2 | Wire companion XP distribution in Group::SplitExp + solo path | c-expert | Complete | Verified in exp.cpp lines 1193-1218 and attack.cpp lines 2780-2799. |
| 3 | Fix CheckForLevelUp: cascading level-ups + level 60 hard cap + HP/mana restore | c-expert | Complete | Verified in companion.cpp lines 1432-1513. |
| 4 | Add GetXPForNextLevel Lua binding | c-expert | Complete | Verified in lua_companion.h line 78, lua_companion.cpp lines 135-139 and 251. |
| 5 | Update !status command to show XP progress | lua-expert | Complete | Verified in companion.lua lines 564-566. |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| | (none — all questions resolved during architecture) | | | | |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| Server not rebuilt after C++ implementation (2026-03-05) — live binary is from 2026-02-21. Must rebuild with ninja before in-game testing. | game-tester | 2026-03-05 | |
| Bash tool denied in validation session — docker exec commands (ninja, luajit, mysql) could not run. User must run manually (see validation-report.md). | game-tester | 2026-03-05 | |

---

## Bug Reports

_Bugs discovered during testing or play. Status flow:
Open → Investigating → Fix In Progress → Resolved._

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| BUG-001 | No XP when companion lands killing blow | Critical | user | Fix Implemented — Code Review PASS — Awaiting Build+Restart+In-Game Verification | c-expert (Task 1) | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Companion XP uses simplified curve (level^2 * 1000) | game-designer | 2026-03-05 | Faster than player curve but still meaningful at high levels |
| 2 | No XP loss on companion death | game-designer, lore-master | 2026-03-05 | Death/despawn timer is sufficient penalty |
| 3 | XPSharePct default 50% | game-designer | 2026-03-05 | Balances companion growth vs. player XP |
| 4 | MaxLevelOffset default 1 | game-designer | 2026-03-05 | Companion always 1 level below player |
| 5 | Absolute hard cap of level 60 | game-designer, lore-master | 2026-03-05 | Classic-Luclin era ceiling |
| 6 | BUG-001 root cause: companions don't set ownerid | architect | 2026-03-05 | HasOwner() returns false, give_exp chain skips companions |
| 7 | Fix pattern: mirror loot fix (IsCompanion + GetCompanionOwner) | architect | 2026-03-05 | Loot fix at attack.cpp:2827 proves the pattern works |
| 8 | No new DB tables or schema changes needed | architect | 2026-03-05 | companion_data already has experience, level, recruited_level |
| 9 | No new rules needed | architect | 2026-03-05 | XPContribute, XPSharePct, MaxLevelOffset already exist |
| 10 | Clamp rule values defensively in C++ | architect | 2026-03-05 | XPSharePct [0,100], MaxLevelOffset [0,59] at point of use |

---

## Completion Checklist

### Implementation Complete (agents can check these)

_Filled in after game-tester validation passes._

- [ ] All implementation tasks marked Complete
- [ ] No open Blockers
- [ ] game-tester server-side validation: PASS
- [ ] User completed in-game testing guide: PASS
- [ ] All changes committed and pushed to feature branch in ALL repos
- [ ] Server rebuilt (if C++ changed)
- [ ] All phases marked Complete in Workflow Status table

### Merge & Cleanup (USER-INITIATED ONLY)

_These items happen ONLY when the user explicitly confirms the feature is done.
The orchestrator NEVER initiates merge or branch cleanup on its own._

- [ ] User confirmed feature is complete
- [ ] Feature branch merged to main in ALL affected repos
- [ ] Main pushed to origin in ALL affected repos
- [ ] Stale feature branches deleted (local + remote)

**Merged by:** _name_
**Merge date:** _YYYY-MM-DD_

---

## Notes

_Free-form notes, observations, or context that doesn't fit above._

- BUG-001 root cause identified by architect: Companions track ownership via
  `m_owner_char_id` / `GetCompanionOwner()` rather than the Mob `ownerid` field.
  This means `HasOwner()` returns false for companions, and the kill credit
  resolution chain in NPC::Death (attack.cpp:2620) skips them entirely.
  The loot fix (already at attack.cpp:2827-2832) proves the resolution pattern.
