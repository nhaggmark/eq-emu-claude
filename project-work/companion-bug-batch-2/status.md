# Companion Bug Batch 2 — Status Tracker

> **Feature branch:** `bugfix/companion-bug-batch-2`
> **Created:** 2026-03-15
> **Last updated:** 2026-03-15

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-15 | 2026-03-15 |
| Design | game-designer + lore-master | Skipped | — | — |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-03-15 | 2026-03-15 |
| Implementation | c-expert | Complete | 2026-03-15 | 2026-03-15 |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-15
- **Notes:** Workspace created. Bug reports for BUG-029, BUG-030, and BUG-031
  already exist in `bugs/`. Design phase skipped — bug reports serve as design input.

### architect → implementation team (c-expert)
- **Date:** 2026-03-15
- **Notes:** Architecture plan complete. Three bugs diagnosed with root causes:
  1. **BUG-029** (buffs): Missing `SetAllowBeneficial(true)` on companions + missing
     NPC group member resolution in `SpellOnTarget()`. Fix in companion.cpp + spells.cpp.
  2. **BUG-031** (duplication): Dual EVENT_TRADE handler firing. Fix in trading.cpp to
     skip local scripts for companions.
  3. **BUG-030** (charm): Investigation needed — add diagnostic logging, determine if
     server-side or Titanium client issue.

  **Only c-expert needed.** All fixes are in C++ zone code.

---

## Implementation Tasks

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | BUG-029: Add SetAllowBeneficial(true) to Companion constructor + NPC group member resolution in SpellOnTarget | c-expert | Complete | companion.cpp, spells.cpp, quest_parser_collection.h — commit c1dbbfe |
| 2 | BUG-031: Skip local EVENT_TRADE for companions in FinishTrade | c-expert | Complete | trading.cpp — commit c1dbbfe |
| 3 | BUG-030: Add diagnostic logging to pet command handler for charmed pets; investigate and fix if server-side | c-expert | Complete (diagnostic) | client_packet.cpp — commit 6b541e5; follow-up may be needed after log review |

---

## Open Questions

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Is BUG-030 a Titanium client limitation or server-side issue? | architect | c-expert | In Progress | Diagnostic logging added to Handle_OP_PetCommands — requires enchanter session to confirm |
| 2 | Is EventNPCGlobal public or private in QuestParserCollection? | architect | c-expert | Resolved | Was private — moved to public section in quest_parser_collection.h (commit c1dbbfe) |

---

## Blockers

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| _(none)_ | | | |

---

## Bug Reports

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| BUG-029 | Buffs not taking hold on companion | High | user | Fixed | c-expert | 2026-03-15 |
| BUG-030 | Charm pet controls UX issues | Medium | user | Investigation Complete / Diagnostic Added | c-expert | Pending log review |
| BUG-031 | Gear duplication on trade | Critical | user | Fixed | c-expert | 2026-03-15 |

---

## Decision Log

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Use SetAllowBeneficial(true) for BUG-029 | architect | 2026-03-15 | Matches existing temp pet pattern (npc.cpp:2204). Simpler than modifying IsBeneficialAllowed(). |
| 2 | Skip local EVENT_TRADE for companions for BUG-031 | architect | 2026-03-15 | Companion trade logic is centralized in global_npc.lua. Local PEQ scripts don't know about companions. |
| 3 | Investigation-first for BUG-030 | architect | 2026-03-15 | Server code appears correct; may be Titanium limitation. |
| 4 | Only c-expert needed for implementation | architect | 2026-03-15 | All three bugs are C++ zone code fixes. No Lua, SQL, or config changes required. |

---

## Completion Checklist

### Implementation Complete (agents can check these)

- [x] All implementation tasks marked Complete
- [ ] No open Blockers
- [ ] game-tester server-side validation: PASS
- [ ] User completed in-game testing guide: PASS
- [x] All changes committed and pushed to feature branch in ALL repos
- [x] Server rebuilt (if C++ changed)
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

Companion Bug Batch 2 — BUG-029 (buffs not taking hold), BUG-030 (charm pet
controls UX), BUG-031 (gear duplication on trade). Architecture analysis complete.
Implementation requires only c-expert — all fixes are in C++ zone code.

Architecture doc: `architect/architecture.md`
