# Companion Re-recruitment Fix — Status Tracker

> **Feature branch:** `bugfix/companion-rerecruit`
> **Created:** 2026-04-27
> **Last updated:** 2026-04-27

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-04-27 | 2026-04-27 |
| Design | game-designer + lore-master | In Progress | 2026-04-27 | |
| Architecture | architect + protocol-agent + config-expert | Not Started | | |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Design

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-04-27
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Bug report BUG-001 seeded at `bugs/BUG-001-rerecruit-level-cap/report.md`.
  Spawn both agents as teammates for the Design phase.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| | | | | |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| | | | | | |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| | | | |

---

## Bug Reports

_Bugs discovered during testing or play. Status flow:
Open → Investigating → Fix In Progress → Resolved._

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| BUG-001 | Re-recruitment blocked by level cap (and possibly cooldowns + dismissed flag) | High | user | Open | TBD | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Fix all three known blockers (level caps, cooldown timers, dismissed flag) as one coordinated change | user | 2026-04-27 | The re-recruitment invariant must hold completely; partial fixes leave the system broken |
| 2 | TDD approach: engineers write tests first proving the invariant, then implement to make tests pass | user | 2026-04-27 | Ensures invariant is machine-verified, not just manually tested |

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

### Re-recruitment Invariant (stated by user)

Once an NPC has been recruited as a companion at any point, the player must
ALWAYS be able to re-recruit that NPC after death, dismissal, or any other
drop-out condition. The companion is re-recruited with their gear and level
intact. There must be no level rules around re-recruiting. The whole point of
the companion system is that a player can recruit an NPC at level 5 and take
them through the entire game.

### Known Blockers (from MEMORY.md)

1. **Level caps** — today's reported blocker (Lydl the Great "too low level")
2. **Cooldown timers** — `data_buckets` companion cooldowns keyed on
   `character_id=0`; must be deleted by key pattern, not column filter
3. **Dismissed flag** — persists incorrectly after death/dismissal

### Reference Docs

- MEMORY.md entries: `project_companion_rerecruit_pain`, `reference_companion_cooldown_clearing`
- Companion Lua binding: `eqemu/zone/lua_companion.cpp`
- LLM bridge: `akk-stack/server/quests/lua_modules/llm_bridge.lua`
- Client extensions: `akk-stack/server/quests/lua_modules/client_ext.lua`
- Global NPC handler: `akk-stack/server/quests/global/global_npc.lua`
