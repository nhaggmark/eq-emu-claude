# Group Chat Companion Addressing — Status Tracker

> **Feature branch:** `feature/group-chat-addressing`
> **Created:** 2026-03-07
> **Last updated:** 2026-03-07

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-07 | 2026-03-07 |
| Design | game-designer + lore-master | Complete | 2026-03-07 | 2026-03-07 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-03-07 | 2026-03-07 |
| Implementation | c-expert + lua-expert + data-expert | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-07
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.
  Design doc reference: `claude/docs/plans/2026-03-07-group-chat-companion-addressing-design.md`

### design team → architecture team (architect + protocol-agent + config-expert)
- **Date:** 2026-03-07
- **Notes:** PRD approved by lore-master. Prefix list expanded with 5 additions.
  No lore concerns. PRD at `game-designer/prd.md`.

### architecture team → implementation team (c-expert + lua-expert + data-expert)
- **Date:** 2026-03-07
- **Notes:** Architecture plan complete at `architect/architecture.md`.
  5 implementation tasks assigned to 3 experts. Dependency chain:
  Task 1 (rules) → Task 2 (SQL, parallel with 3) → Task 3 (C++ parser) → Task 4 (Lua routing) → Task 5 (build/deploy).
  No database schema changes. No new opcodes. Entity variable signaling
  for LLM response channel routing.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Add Companion rule category + 3 rules to ruletypes.h | c-expert | Complete | Companions (plural) category; build verified |
| 2 | Insert rule_values rows for the 3 Companion rules | data-expert | Complete | 3 rows inserted and verified (Companions:* prefix) |
| 3 | Implement @-mention parser and dispatch in client.cpp | c-expert | Complete | HandleGroupChatMentions() implemented, build clean |
| 4 | Modify global_npc.lua for group chat response routing + stagger | lua-expert | Not Started | Medium: entity variable check + timer delivery |
| 5 | Build, deploy, and validate | c-expert | Not Started | Small: ninja build, make restart, start processes |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Should non-player group members see @mentions in raw form? | PRD | architect | Resolved | Yes — show as-is for transparency |
| 2 | Should there be feedback on unmatched @names? | PRD | architect | Resolved | No — silent failure per PRD design |
| 3 | How to pass response channel flag to LLM sidecar? | PRD | architect | Resolved | Entity variable on companion; sidecar is unaware of channel |
| 4 | Should companions respond to non-owner @mentions? | PRD | architect | Resolved | Yes — all group members can interact with all members |
| 5 | Should prefix list be configurable via rules? | PRD | config-expert | Resolved | No — hardcode 20 prefixes in C++ |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| None | — | — | — |

---

## Bug Reports

_Bugs discovered during testing or play. Status flow:
Open → Investigating → Fix In Progress → Resolved._

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| | | | | | | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Entity variable signaling for LLM response channel | architect | 2026-03-07 | Simpler than EVENT_GROUP_SAY; entity vars already used for companion state |
| 2 | New Companion rule category with 3 rules | architect + config-expert | 2026-03-07 | Feature toggle + stagger timing; follows Bots:Enabled pattern |
| 3 | Hardcode prefix strip list in C++ | architect + config-expert | 2026-03-07 | Rules are scalar-only; 20-prefix list is stable content |
| 4 | Anti-spam does not affect group chat | architect | 2026-03-07 | Verified: EnableAntiSpam only checks Shout/Auction/OOC/Tell |
| 5 | Non-owners can @mention companions | architect | 2026-03-07 | Matches EQ group chat semantics |
| 6 | Show raw @mention text to all group members | architect | 2026-03-07 | Transparency; helps players understand companion commands |

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

Design doc saved at: `claude/docs/plans/2026-03-07-group-chat-companion-addressing-design.md`
Architecture doc saved at: `claude/project-work/feature/group-chat-addressing/architect/architecture.md`
