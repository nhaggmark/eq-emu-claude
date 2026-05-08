# Companion Rez Vanish — Status Tracker

> **Feature branch:** `bugfix/companion-rez-vanish`
> **Created:** 2026-05-03
> **Last updated:** 2026-05-03

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-05-03 | 2026-05-03 |
| Design | game-designer | Complete | 2026-05-03 | 2026-05-03 |
| Architecture | architect (+ protocol-agent + config-expert advisory) | Complete | 2026-05-03 | 2026-05-03 |
| Implementation | c-expert (+ infra-expert if needed) | Complete | 2026-05-03 | 2026-05-03 |
| Validation | game-tester | Next | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Validation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-05-03
- **Notes:** Workspace created. Bug report BUG-001 filed at
  `bugs/BUG-001-companion-rez-vanish/report.md`. PRD template ready at
  `game-designer/prd.md`. Spawn both agents as teammates for the Design phase.

### design team (game-designer) → architect
- **Date:** 2026-05-03
- **Notes:** PRD finalized at `game-designer/prd.md`. Documents observed
  vs expected behavior, two independent repro plans (time-only and
  zone-only) per team-lead spec, a combined sustained-play repro backing
  AC-5, and seven acceptance criteria covering time persistence, zone
  persistence, command parity, no-regression on prior companion-rez/
  re-recruit fixes, sustained-play resilience, observable log-line
  signal, and full repro retirement.
  - **Out of scope explicitly enumerated:** auto-rez configurability,
    rez UI, player-extendable rez timer, cross-companion-rez expansion,
    rez XP/sickness/effectiveness changes.
  - **User's hypothesis** (uncleared death-timer / despawn clock on
    rez) flagged as priority-1 question for the architect. Six other
    open questions logged for triage.
  - **Lore review:** N/A — no narrative/lore content in this bug fix.
    Lore-master not on the team for this bug-fix workspace per
    team-lead instruction.
  - **Adjacent prior work** (cb95baa41, 83a96f655, 17662d4ba, 035d33348,
    84ac6a204, 478d154bf, akk-stack e230ee3) flagged in the PRD's
    Technical Notes appendix for the architect to review.
  - **Candidate affected systems:** C++ server source (companion
    lifecycle, death timers, rez handler) + Lua quest scripts
    (companion.lua, lua_modules). Architect to confirm during triage.

### architect → implementation team (c-expert)
- **Date:** 2026-05-03
- **Notes:** Architecture complete at `architect/architecture.md`. Root
  cause identified: `Companion::ResurrectFromCorpse()` does not depop
  the OLD dead Companion entity before creating the NEW rezzed entity.
  Both entities share `m_companion_id` and the same `companion_data`
  row. The OLD entity (a) keeps ticking `Process()`, (b) has its
  `m_death_despawn_timer` running and at fire writes
  `is_dismissed=1, is_suspended=1` to the shared DB row, and (c) is
  iterated by `Handle_OP_ZoneChange` and other companion-list scans,
  which call `Save()` and write `is_suspended=1` to the shared DB row
  (Save() ordering is non-deterministic via unordered_map iteration).
  Either path corrupts the row so the next zone-in's
  `SpawnCompanionsOnZone` filter (`WHERE is_dismissed=0` and
  `cd.is_suspended==0`) silently skips the rezzed companion → vanish.
  - **User's hypothesis is partially correct** — there IS a
    death-timer/despawn-clock on the dead entity, but the issue is not
    that the timer fires on a live rezzed entity (the rezzed entity is
    a different C++ object with a fresh disabled timer). The issue is
    that the OLD dead entity is never removed and its later Save()
    corrupts the shared persistence row.
  - **Fix:** add OLD-entity lookup + Depop() to ResurrectFromCorpse()
    BEFORE the new Companion() / Spawn() chain runs. Single C++ file
    change, ~25 lines, plus 3 TDD red→green tests in Suite 38.
  - **Implementation team composition:** c-expert only (with
    infra-expert as standby for restart support during validation).
    No Lua, SQL, rules, or protocol changes.
  - **Validation team composition:** game-tester runs all four PRD
    repros (A, B, C, D) and confirms AC-1 through AC-7.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Add Suite 38 TDD red tests (38.1, 38.2, 38.3) for OLD-entity-leak rez vanish | c-expert | Complete 2026-05-03 | 19 tests, all GREEN |
| 2 | Implement OLD-entity depop in `Companion::ResurrectFromCorpse()` (eqemu/zone/companion.cpp, before line 3699) | c-expert | Complete 2026-05-03 | 29 lines, clean build 244/244 |
| 3 | Verify Suite 38 GREEN; verify Suites 35, 36, 37 (and all earlier) still GREEN | c-expert | Complete 2026-05-03 | 587 PASSED, 1 pre-existing FAIL (36.4a, unrelated) |
| 4 | Build binary in dev container | c-expert | Complete 2026-05-03 | ninja 244/244, no errors |
| 5 | Commit + push to `bugfix/companion-rez-vanish` in eqemu/ | c-expert | Complete 2026-05-03 | Commits 3bd91a645 (tests) + 3ed5f852a (fix), pushed |
| 6 | Restart server processes (if needed for validation phase) | infra-expert | Not Started | Standby — only if game-tester does not self-service |
| 7 | Validate AC-1 through AC-7 across all 4 PRD repros (A, B, C, D) | game-tester | Not Started | Capture zone logs, verify AC-6 log line appears on rez |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Is there a death-timer / corpse reaper / despawn clock on the dead companion entity that is NOT cleared on rez success? (User's hypothesis, priority-1) | game-designer | architect | **Resolved** | YES — `Companion::m_death_despawn_timer` is set in `Death()` (companion.cpp:707) and is never cleared on rez. The OLD dead Companion entity persists in `companion_list` post-rez with this timer running. When it fires (T_death + DeathDespawnS, default 1800s), OLD writes `is_dismissed=1, is_suspended=1` to the shared `companion_data` row at `Process()` line 1986. |
| 2 | Is the bug time-triggered, zone-triggered, or both? Repro plan covers each path independently. | game-designer | architect | **Resolved** | BOTH paths share a root cause (OLD entity not depopped on rez) but reach the corrupt-DB outcome via different mechanisms. Time-only: OLD's death-timer fire writes is_dismissed=1. Zone-only: `Handle_OP_ZoneChange` iterates BOTH OLD and NEW in companion_list, calls Save() on each; if OLD saves last (non-deterministic unordered_map iteration), is_suspended=1 wins. Single fix (OLD depop on rez) closes both paths. |
| 3 | Does the rez code path clear all "dead" state (Dismiss flag, follow state, group slot, name-based lookup keys) per the bugfix/companion-rerecruit invariants? | game-designer | architect | **Resolved** | The NEW rezzed entity has its own clean state (constructor disables m_death_despawn_timer, m_suspended=false, m_is_dismissed=false). NEW correctly joins the group via Spawn() → CompanionJoinClientGroup. The OLD entity already had its group slot and name slot cleared in Death() (companion.cpp:716-738) per the V2 atomicity fix. The bug is NOT in rez clearing NEW's state — it's in failing to depop the OLD entity entirely so it cannot Save() over the shared DB row. |
| 4 | Is this a regression from the recent merged companion-rez/rerecruit fixes, or has it existed since the autonomous rez feature first merged (cb95baa)? | game-designer | architect | **Resolved** | Pre-existing. The original rez implementation (cb95baa41) used `entity_list.AddNPC()` which had the same OLD-leak issue (just routed differently). The V2 fix (17662d4ba) changed the Spawn path to use the companion_list path but did NOT add OLD-entity cleanup. The heartbeat hoist (84ac6a204) is unrelated. So this bug has existed since rez was first implemented; it just became more visible after V2 because the V2 fix correctly registered NEW in companion_list, which is the same list that ZoneChange iterates. |
| 5 | Is the bug deterministic on every rez, or intermittent? | game-designer | architect / game-tester | **Resolved (analysis)** | Time-only path: deterministic — every rez leaves OLD in companion_list with timer running; OLD's death-timer fire path is deterministic. Zone-only path: non-deterministic in the WIN condition — depends on `std::unordered_map` iteration order, which depends on entity_id hash bucket layout. About half of post-rez zones will produce the corrupt DB row; the other half NEW saves last and DB ends up correct. In practice the user will hit it eventually. game-tester should still see consistent test failures because each repro chains multiple zones. |
| 6 | If a despawn timer is the culprit, is it the same timer used for un-rezzed dead companions whose corpses naturally decay? | game-designer | architect | **Resolved** | YES — `m_death_despawn_timer` is the same timer instance for both rezzed and un-rezzed dead companions. The bug is that for rezzed companions, the OLD entity (which holds this timer) is not removed; for un-rezzed companions, the timer correctly fires and dismisses the absent companion. After our fix, OLD is removed on rez so its timer never fires — strictly correct. |
| 7 | Does the vanish leave artifacts in `data_buckets`, `character_corpses`, etc., that distinguish "scheduled despawn fired" from "group eviction" from "entity destroyed"? | game-designer | architect / data-expert | **Resolved** | The diagnostic signature is in `companion_data.is_dismissed` and `companion_data.is_suspended` for the affected companion_id. Time-only path (death-timer-fire): `is_dismissed=1, is_suspended=1`. Zone-only path (Save() race): typically `is_dismissed=0, is_suspended=1`. game-tester should query the row at end of each repro to confirm pre-fix corruption signature, post-fix expected (0, 0). No artifacts in data_buckets or character_corpses. |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| _none_ | | | |

---

## Bug Reports

_Bugs discovered during testing or play. Status flow:
Open → Investigating → Fix In Progress → Resolved._

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| BUG-001 | Rez'd NPC companion vanishes from group a few minutes after rez | High | User (player), 2026-05-05 | Fix implemented — awaiting game-tester validation | game-tester | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Lore-master excluded from design team for this bug fix | team-lead → game-designer | 2026-05-03 | No lore/narrative content in a behavior bug fix; design team is game-designer solo |
| 2 | Repro plan splits time-only and zone-only paths into independent scenarios (Repro A and Repro B), with a combined sustained-play scenario (Repro C) backing AC-5 | game-designer | 2026-05-03 | User could not confirm which trigger fired; fix must address both paths and tester must independently verify both |
| 3 | AC-6 requires an explicit log-line signal that the death-timer / despawn clock was cleared on rez | game-designer | 2026-05-03 | Future regressions of this exact bug class need to be detectable from logs, not just from manual play observation |
| 4 | Fix layer: C++ only (no Lua, SQL, rules, protocol) | architect | 2026-05-03 | The bug is in `Companion::ResurrectFromCorpse()` entity-management. Lua/SQL would be putting bandages over the wound. Single-function C++ change is the surgical fix. |
| 5 | Approach: depop OLD entity on rez instead of disabling timer | architect | 2026-05-03 | Disabling the timer would still leave OLD in companion_list, where it can Save()-corrupt the row at zone/camp/disconnect time. Depop closes ALL Save() paths at once. Simplest sound fix. |
| 6 | TDD red→green discipline mandatory (Suite 38) | architect | 2026-05-03 | Per `feedback_refactor_regression_discipline.md` — customized-system fixes that lack TDD coverage become V2 fixes later. Suite 38 makes the invariant testable in CI. |
| 7 | Implementation team is c-expert solo (no other experts spawned) | architect | 2026-05-03 | Single-language fix. Spawning unused experts wastes tokens per architect-agent guidance. |

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

- Design phase did not coordinate with lore-master because this bug
  fix has no narrative/lore content. Per team-lead instruction,
  lore-master is not on the design team for this workspace.
  `agent-conversations.md` Design Team section is intentionally empty.
- Architecture phase advisory consultations (protocol-agent,
  config-expert) were performed inline in the architect's review
  passes; both confirmed no constraints (no client packet changes
  required, no rule changes required). Logged in agent-conversations.md
  Architecture Team Conversations section.
