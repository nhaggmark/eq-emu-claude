# companion-group-debugging — Status Tracker

> **Feature branch:** `bugfix/companion-group-debugging`
> **Created:** 2026-03-11
> **Last updated:** 2026-03-11

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-11 | 2026-03-11 |
| Design | game-designer + lore-master | Skipped (bug triage) | — | — |
| Architecture | architect | Complete | 2026-03-11 | 2026-03-11 |
| Implementation | lua-expert | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

### bootstrap-agent → architect
- **Date:** 2026-03-11
- **Notes:** Workspace created. Bug reports filed. Direct triage by architect
  (skipping design phase for bug-fix workflow).

### architect → implementation team (lua-expert)
- **Date:** 2026-03-11
- **Notes:** Root cause identified for both bugs. Single root cause:
  Companion-only Lua methods called on Lua_NPC objects (luabind inheritance
  issue). Fix plan: nil-guards + GMMove replacement. All changes in
  `companion.lua`. Spawn lua-expert only.

---

## Implementation Tasks

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Fix BUG-021: nil-guard GetStance/SetStance in cmd_assist | lua-expert | Not Started | Line 924-925 |
| 2 | Fix BUG-022: replace RunTo with GMMove in cmd_tome | lua-expert | Not Started | Line 851 |
| 3 | Apply nil-guards to ALL companion commands using Companion-only methods | lua-expert | Not Started | See architecture.md fix table |
| 4 | Fix cmd_flee: replace RunTo with GMMove (same override issue) | lua-expert | Not Started | Line 870 |

---

## Open Questions

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| | | | | | |

---

## Blockers

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| | | | |

---

## Bug Reports

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| BUG-021 | !assist stack trace — GetStance nil on Lua_NPC | Critical | user | Investigating | lua-expert | |
| BUG-022 | !tome no effect — RunTo overridden by follow AI | High | user | Investigating | lua-expert | |

---

## Decision Log

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Use nil-guard pattern (not C++ event dispatch fix) | architect | 2026-03-11 | Simpler, proven pattern in codebase (MEMORY.md). C++ fix would require changes to quest_parser_collection, lua_parser, and lua_parser_events — much larger scope. |
| 2 | Replace RunTo with GMMove for !tome and !flee | architect | 2026-03-11 | RunTo is overridden by follow-target AI on next tick. GMMove sets position directly, matching existing !recall approach. |

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

Root cause is the well-known luabind inheritance issue documented in MEMORY.md:
"Lua_Companion inherits from Lua_NPC in C++ but luabind doesn't resolve inherited
methods at runtime." The companion.lua module was written assuming `npc` would be
a Lua_Companion, but the event dispatch system (`EventBotMercNPC` →
`e->CastToNPC()`) always wraps it as Lua_NPC. This affects every command that
calls Companion-only methods.
