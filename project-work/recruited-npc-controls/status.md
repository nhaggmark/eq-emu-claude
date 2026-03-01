# Recruited NPC Controls — Status Tracker

> **Feature branch:** `feature/recruited-npc-controls`
> **Created:** 2026-02-28
> **Last updated:** 2026-02-28

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-02-28 | 2026-02-28 |
| Design | game-designer + lore-master | Complete | 2026-02-28 | 2026-02-28 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-02-28 | 2026-02-28 |
| Implementation | config-expert + lua-expert | Complete | 2026-02-28 | 2026-02-28 |
| Validation | game-tester | In Progress | 2026-02-28 | |
| Completion | _user_ | Not Started | | |

**Current phase:** Validation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-02-28
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architect
- **Date:** 2026-02-28
- **Notes:** PRD complete and approved at `game-designer/prd.md`. Lore review
  approved by lore-master (two minor phrase corrections applied). PRD scope:
  `!` prefix system separating companion commands from LLM conversation. 14
  commands across 6 categories (3 existing stance, 3 existing movement, 4
  equipment, 3 information, 2 new combat, 1 control). 5 new commands added
  (recall, target, assist, status, equip). Pure Lua implementation expected
  for core feature. 3 open questions for architect: trade window feasibility,
  recall cooldown, target/assist stance scope. C-expert prefix audit
  (dev-notes.md) confirms no C++ collision with `!` character.

### implementation team → game-tester
- **Date:** 2026-02-28
- **Notes:** Server-side validation complete. Result: PASS WITH WARNINGS.
  All 22 server-side checks pass. Two non-blocking warnings:
  (1) status.md Task 1 showed "Not Started" though rule is implemented — corrected.
  (2) Zone bootup failures in zone_187.log predate this feature; unrelated.
  One recommendation: !gear and !unequipall aliases are undocumented in !help.
  In-game testing guide is at `game-tester/test-plan.md` (25 tests + 7 edge cases).
  Awaiting user to complete in-game tests.

### architect → implementation team (config-expert + lua-expert)
- **Date:** 2026-02-28
- **Notes:** Architecture plan complete at `architect/architecture.md`.
  Pure Lua implementation confirmed — no C++ logic changes needed. All Lua
  bindings for new commands already exist (SetTarget, AddToHateList, GMMove,
  CalculateDistance, etc.). 3 open questions resolved:
  - Q1: `!equip` trade window deferred — Titanium requires client-initiated trade
  - Q2: `!recall` gets 30s cooldown via data bucket + new RecallCooldownS rule
  - Q3: `!target`/`!assist` work in passive but don't engage combat
  
  **Implementation sequence:**
  1. config-expert: Add `Companions:RecallCooldownS` rule (1 line in ruletypes.h)
  2. lua-expert: Refactor companion.lua — replace keywords with prefix dispatch
  3. lua-expert: Update global_npc.lua — prefix check instead of keyword check
  
  **Only 2 agents needed:** config-expert (1 rule) + lua-expert (all Lua work)

---

## Implementation Tasks

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Add `Companions:RecallCooldownS` rule to `ruletypes.h` | config-expert | Complete | 1 line at ruletypes.h:1202. Rule seeded in DB. World log confirms rule loaded at 16:25. Status.md incorrectly showed "Not Started" — corrected by game-tester. |
| 2 | Refactor `companion.lua`: prefix command dispatch, all 14 handlers, help system, lore phrases | lua-expert | Complete | ~350 lines changed/added |
| 3 | Update `global_npc.lua`: prefix check instead of keyword interception | lua-expert | Complete | ~10 lines changed. |

---

## Open Questions

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Can EQ trade window be opened programmatically from Lua? | game-designer | architect | **Resolved** | No — Titanium client requires client-initiated trade. `!equip` deferred; shows trade instructions instead. |
| 2 | Should !recall have a cooldown? | game-designer | architect | **Resolved** | Yes — 30s via data bucket. Configurable via `Companions:RecallCooldownS` rule. |
| 3 | Should !target/!assist work in passive stance? | game-designer | architect | **Resolved** | Yes — companion targets but does NOT engage combat (no AddToHateList in passive). |

---

## Blockers

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| | | | |

---

## Bug Reports

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| | | | | | | |

---

## Decision Log

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Use `!` as command prefix | game-designer + c-expert | 2026-02-28 | Not reserved by any C++ system; ergonomic; conventionally understood in games; pure Lua implementation |
| 2 | Keep recruitment keyword-based | game-designer | 2026-02-28 | Natural language recruitment IS the intended player experience; prefix would break immersion |
| 3 | Remove all natural-language management aliases | game-designer + lore-master | 2026-02-28 | Eliminates accidental command triggers; lore-master confirmed this is an immersion improvement |
| 4 | Split balanced stance response by companion type | lore-master | 2026-02-28 | "I will fight at your side" violates mercenary word prohibition in companion_culture.lua |
| 5 | Use complete sentences for combat responses | lore-master | 2026-02-28 | "Targeting."/"Assisting." break established NPC speech pattern; replaced with "I see your target."/"I will assist." |
| 6 | Create only 1 rule (RecallCooldownS), not 3 | config-expert + architect | 2026-02-28 | CommandPrefix is fixed decision (Lua constant); RecallMinDistance is balance constraint (Lua constant) |
| 7 | Defer !equip trade window | architect | 2026-02-28 | Titanium client requires client-initiated trade; no server-side API exists; PRD anticipated deferral |
| 8 | !target/!assist work in passive without combat | architect | 2026-02-28 | Preserves passive stance meaning while allowing target direction |
| 9 | Track guard/follow mode in Lua table | architect | 2026-02-28 | GetFollowID() not bound on Lua_Companion; Lua tracking simpler than C++ binding |

---

## Completion Checklist

_Filled in after game-tester validation passes._

- [ ] All implementation tasks marked Complete
- [ ] No open Blockers
- [ ] game-tester validation: PASS
- [ ] Feature branch merged to main
- [ ] Server rebuilt (if C++ changed)
- [ ] All phases marked Complete in Workflow Status table

**Merged by:** _name_
**Merge date:** _YYYY-MM-DD_

---

## Notes

- C-expert's full prefix audit is at `c-expert/dev-notes.md` — useful reference
  for the architect regarding message routing in client.cpp
- Lore-master's full review is at `lore-master/lore-notes.md` — includes context
  for implementers about NPC response phrase register and mercenary word prohibition
- Agent conversation audit trail at `agent-conversations.md` — all design and
  architecture team exchanges logged with 12 key decisions
- Architecture plan at `architect/architecture.md` — complete implementation spec
  with code sketches for all 14 command handlers
