# Companion Rez — Status Tracker

> **Feature branch:** `bugfix/companion-rez`
> **Created:** 2026-04-27
> **Last updated:** 2026-04-27

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-04-27 | 2026-04-27 |
| Design | game-designer + lore-master | Complete | 2026-04-27 | 2026-04-27 |
| Architecture | architect + protocol-agent + config-expert (+ c-expert, lua-expert, data-expert as advisors) | Complete | 2026-04-27 | 2026-04-27 |
| Implementation | c-expert + infra-expert + game-tester | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-04-27
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  BUG-001 filed at `bugs/BUG-001-cleric-rez-broken/report.md`.
  Spawn both agents as teammates for the Design phase.

### design team (game-designer + lore-master) → architect
- **Date:** 2026-04-27
- **Notes:** PRD finalized at `game-designer/prd.md` — APPROVED by
  lore-master 2026-04-27, no revisions required. Bug invariant locked
  verbatim: a Cleric NPC companion auto-rezzes downed party members
  (player + recruited NPC companions) post-combat, reliably (AC-10).
  TDD discipline locked as design constraint (AC-9). All 10 acceptance
  criteria from team-lead brief covered; Validation Plan covers all 7
  team-lead scenarios plus 5 additional regression cases. Era
  compliance reviewed and signed off (Classic-Luclin Cleric rez
  progression: Resurrection 15 / Reanimation 29 / Revive 43 /
  Resuscitate 53 / Restoration 65). Shaman rez locked as a HARD STOP
  for any future scope expansion. Necromancer / Druid / Paladin noted
  as future-scope only. Open questions remaining are all
  architect-domain (post-combat delay N value, NPC corpse rez
  confirmation gap, tier preference policy, multi-target ordering,
  quest-NPC edge case, TDD test-scope mapping). Lore-master sign-off
  recorded in `lore-master/lore-notes.md` and exchanges logged in
  `agent-conversations.md`. Architect inherits a clean PRD with no
  lore blockers and a clear AC-10 reliability contract.

### architect → implementation team (c-expert + infra-expert + game-tester)
- **Date:** 2026-04-27
- **Notes:** Architecture phase complete. The auto-rez subsystem is
  ALREADY substantially built end-to-end (post-combat trigger, AI
  pipeline, corpse marking, `Companion::ResurrectFromCorpse` server-side
  auto-accept handler, all rules and spell data populated).
  **Root cause of BUG-001 is a single guard at `eqemu/zone/spells.cpp:2051`:**
  `Mob::DetermineSpellTargets` rejects `ST_Corpse` casts whose target
  is not `IsPlayerCorpse()`. NPC companion corpses fail this check and
  the spell is canceled before reaching `SpellEffect::Revive` (which
  already correctly routes companion corpses).
  **Fix is two narrowly-scoped C++ edits + 4 failing-first tests:**
  (1) extend the `ST_Corpse` guard to admit companion corpses
  (`IsCompanionCorpse()`), (2) extend `Companion::FindDeadGroupMemberCorpse`
  to ALSO discover the owner's player corpse (priority: player first),
  (3) Suite 29 tests 29.14, 29.15, 29.16, 29.17 in
  `eqemu/zone/cli/tests/cli_companion_tests.cpp`.
  No Lua, no SQL, no rule, no protocol changes.
  All 6 architect-domain open questions resolved in the architecture
  doc with reasoning. PRD AC-9 TDD discipline maintained (failing-first
  tests, retained on rollback). Implementation sequence: 7 tasks,
  c-expert owns 5, infra-expert 1, game-tester 1.
  **Spawn: c-expert, infra-expert, game-tester only. Do NOT spawn
  lua-expert / data-expert / config-expert / protocol-agent — they had
  no assigned tasks.**

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Write 4 failing-first tests in Suite 29 (29.14–29.17) of `eqemu/zone/cli/tests/cli_companion_tests.cpp` per the test table in architecture.md. Build the test binary inside the container; run via `./bin/zone tests:companion`; verify all 4 new tests FAIL today. | c-expert | Complete 2026-04-27 | TDD red commit: 30f6d6ef5. Tests 29.14, 29.15, 29.17 fail pre-fix. 29.16 is structural no-crash guard. |
| 2 | Implement `ST_Corpse` extension at `eqemu/zone/spells.cpp:2049-2063` per the architecture doc. Admit `IsCompanionCorpse()` alongside `IsPlayerCorpse()`. | c-expert | Complete 2026-04-27 | Part of fix commit 83a96f655 |
| 3 | Implement player-corpse discovery extension at `eqemu/zone/companion_ai.cpp:1861-1876` (`FindDeadGroupMemberCorpse`). Priority 1: owner's player corpse via `EntityList::GetCorpseByOwnerWithinRange`. Priority 2: existing companion corpse path. | c-expert | Complete 2026-04-27 | Part of fix commit 83a96f655. Passes rez_range*rez_range per dist_sq convention. |
| 4 | Rebuild zone binary via `docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`. Re-run Suite 29 — verify all 4 new tests PASS, all 13 existing Suite 29 tests still PASS. Run full companion test suite. | c-expert | Complete 2026-04-27 | All 35 suites PASS. 29.14/15/17 GREEN. No regressions. Zero build warnings. |
| 5 | Server restart: `make restart` from akk-stack/, then full server start (loginserver / world / 8 dynamic_NN zones per documented startup procedure). | infra-expert | Not Started | Depends on 4 |
| 6 | In-game validation: 7 game-tester scenarios per Validation Plan (Scenarios 1, 2, 3, 4, 5, 6, 12 in architecture.md). User confirms. | game-tester | Not Started | Depends on 5 |
| 7 | Commit and push all changes on `bugfix/companion-rez` in eqemu and claude repos. (akk-stack and spire have no changes.) | c-expert | Complete 2026-04-27 | eqemu pushed (30f6d6ef5, 83a96f655). claude pushed after dev-notes update. |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | What is N — post-combat delay before Cleric scans for corpses? | game-designer | architect | RESOLVED 2026-04-27 | N=10. Existing `RuleI(Companions, RezPostCombatDelayS)` default 10. data-expert confirmed live value=10. |
| 2 | NPC corpse rez confirmation gap: auto-accept server-side, bypass rez request, or other approach? | game-designer (BUG-001) | architect | RESOLVED 2026-04-27 | User hypothesis CONFIRMED; bypass ALREADY in place at `spell_effects.cpp:1707-1730` → `Companion::ResurrectFromCorpse`. Real bug is upstream `ST_Corpse` validation at `spells.cpp:2051`. Fix admits companion corpses to the existing bypass path. |
| 3 | Rez tier preference policy (highest affordable vs. other) | game-designer | architect | RESOLVED 2026-04-27 | Existing C++ policy retained: ≥50% mana → highest tier; <50% mana → cheapest. Hardcoded (no rule). |
| 4 | Multi-target ordering policy (player-first / tank-first / discovery-order) | game-designer | architect | RESOLVED 2026-04-27 | Player corpse FIRST, then closest companion. 20s recast timer naturally sequences. Hardcoded in `FindDeadGroupMemberCorpse` extension. |
| 5 | Cleric OOM flavor chat line — silent or one-time line? | game-designer | lore-master | RESOLVED 2026-04-27 | Silent. Out of scope for this fix; polish pass may revisit. Existing `m_rez_meditation_announced` already does this. |
| 6 | Quest-NPC rez interaction (rezzing an NPC who is also a kill target / quest-state node) | game-designer | architect | RESOLVED 2026-04-27 | No special handling. Awareness flag only. Matches charm-pet behavior in vanilla EQ. Quest designers can add `companion_exclusions` rows in the future if needed. |
| 7 | TDD test-scope mapping (unit / integration / game-tester per scenario) | game-designer | architect | RESOLVED 2026-04-27 | 4 required Suite 29 unit tests (29.14–29.17). 7 game-tester live scenarios. 2 optional unit tests for AC-5 tier preference. Mapping table in architecture.md "Resolved PRD Open Questions / Q7". |

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
| BUG-001 | Cleric companion attempts rez post-combat but NPC companion stays down | High | user | Fix In Progress | c-expert (Phase 4) | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | No deity / race / alignment restrictions on Cleric rez targets | game-designer + lore-master | 2026-04-27 | Not enforced in Classic mechanics; UX pain on 1-3 player server |
| 2 | Shaman rez is a permanent HARD STOP for any future scope expansion | lore-master | 2026-04-27 | No Shaman rez in Classic-Luclin — era violation if added |
| 3 | Necromancer rez is conditional / out of current scope | lore-master | 2026-04-27 | In-era but mechanically distinct (damaged corpse / XP penalty); not part of this fix |
| 4 | Cleric OOM behavior is silent (no flavor chat output) | lore-master | 2026-04-27 | EQ NPC terseness; flavor lines out of scope for this fix |
| 5 | TDD discipline locked as design constraint (AC-9) | game-designer | 2026-04-27 | Pattern-match to companion-rerecruit; machine-verified invariant |
| 6 | AC-10 reliability bar: every prereq-met rez attempt MUST succeed | game-designer | 2026-04-27 | Closes BUG-001 verbatim user pain ("attempting to rez but nothing happens") |
| 7 | Mid-combat rez initiation explicitly disallowed (AC-8) | game-designer | 2026-04-27 | Rezzed targets re-die instantly; better to spend Cleric mana on heals/CC |
| 8 | Bug Reports table — BUG-001 status updated from Open to Investigating | game-designer | 2026-04-27 | PRD locks the invariant; architect now triages root cause |
| 9 | Root cause of BUG-001 = `eqemu/zone/spells.cpp:2051` `ST_Corpse` guard rejecting non-player-corpse targets | architect (c-expert findings) | 2026-04-27 | Verified end-to-end: cast pipeline cancels at target validation BEFORE `SpellEffect::Revive` can route to existing companion-corpse bypass |
| 10 | Fix scope: pure-C++, two narrowly-scoped edits + 4 TDD tests | architect | 2026-04-27 | Lua/SQL/protocol/config audits all returned clean; the auto-rez subsystem is already built; only the upstream guard needs to admit companion corpses |
| 11 | N (post-combat delay) = 10 seconds | architect | 2026-04-27 | Existing rule default; data-expert confirmed live value; satisfies AC-1 framing |
| 12 | Tier preference policy: ≥50% mana → highest tier; <50% → cheapest | architect | 2026-04-27 | Existing implementation; sensible default; hardcoded (no rule) |
| 13 | Multi-target ordering: player FIRST, then closest companion | architect | 2026-04-27 | Player rez higher UX impact; 20s recast naturally sequences; hardcoded |
| 14 | No new rules, no new DB rows, no Lua changes for this fix | architect | 2026-04-27 | Verified by all five advisors; least-invasive layer is C++; YAGNI on rule expansion |
| 15 | BUG-001 status updated from Investigating to Fix In Progress | architect | 2026-04-27 | Root cause identified; implementation tasks scheduled |

---

## Completion Checklist

### Implementation Complete (agents can check these)

_Filled in after game-tester validation passes._

- [ ] All implementation tasks marked Complete
- [ ] No open Blockers
- [ ] Suite 29 tests 29.14-29.17 PASS in `./bin/zone tests:companion`
- [ ] Existing 13 Suite 29 tests still PASS (no regression)
- [ ] game-tester server-side validation: PASS for all 7 scenarios
- [ ] User completed in-game testing guide: PASS (BUG-001 resolved verbatim)
- [ ] All changes committed and pushed to feature branch in eqemu and claude repos
- [ ] Server rebuilt (zone binary fresh)
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

- The auto-rez subsystem was substantially scaffolded during the
  `companion-rerecruit` bugfix or just before it. The architecture
  intent was "build the pipeline end-to-end and ship the fix in two
  passes." This rez fix is the second pass, removing the upstream
  guard that prevented the pipeline from working. This is a small,
  surgical fix on top of significant existing infrastructure.
- The `is_suspended=1` death-state established in `companion-rerecruit`
  is a hard prerequisite for rez (`ResurrectFromCorpse` reads the
  preserved `companion_data` row at `companion.cpp:3563-3567`).
  companion-rerecruit is already merged; rez builds on it cleanly.
- The "AC-2 player rez" extension to `FindDeadGroupMemberCorpse` is
  a small but visible additive scope expansion beyond "fix the
  spells.cpp guard". It's necessary to satisfy PRD AC-2; without it,
  the cleric would still ignore player corpses. The extension is
  trivial (one method call to an existing `EntityList` helper).
