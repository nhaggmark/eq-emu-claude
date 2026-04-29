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
| Implementation | c-expert + infra-expert + game-tester | Complete | 2026-04-27 | 2026-04-28 |
| Validation | game-tester | In Progress | 2026-04-28 | |
| Completion | _user_ | Not Started | | |

**Current phase:** Validation

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

### game-tester → user (in-game validation pending)
- **Date:** 2026-04-28
- **Notes:** Server-side validation: PASS. All 35 companion test suites pass (Suite 29
  tests 29.14-29.17 GREEN post-fix; 29.1-29.13 still passing — no regressions). DB
  integrity clean (0 orphaned FK refs). All 5 rez rules confirmed at correct values.
  Running binary confirmed to contain `IsCompanionCorpse` and `ResurrectFromCorpse`
  code paths. No rez-related errors in zone or world logs. One pre-existing WARN
  (inventory slot_id 3810-3819 for char_id=6 in The Hole/West Freeport — unrelated
  to this fix). Full in-game test plan at `game-tester/test-plan.md`: 8 numbered
  tests (AC-1 through AC-10) + 5 regression tests. Awaiting user in-game confirmation.

### game-tester → user (V2 in-game validation pending)
- **Date:** 2026-04-28
- **Notes:** V2 server-side validation: PASS WITH ANOMALY (binary symlink mtime — benign, actual binary Apr 28 17:26).
  All 36 companion test suites GREEN including new Suite 36 (17 V2 tests). Suite 29 V1 tests still PASS.
  DB clean: 5 companion rows all alive (is_suspended=0), 0 stuck dead companions.
  V2 binary confirmed: Fix A (membername[] slot clear), Fix R4 (alive guard), Fix B (Spawn routing), Fix C (atomic rez + Option D pre-flight) all present.
  8 zone processes running. No post-restart errors beyond pre-existing inventory slot warnings.
  V2 test plan at `game-tester/test-plan.md` (V2 section): 7 in-game scenarios (V2-1 through V2-8, V2-3 skipped per descope) + 3 regression tests.
  Awaiting user in-game confirmation to close BUG-001 V2.

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
| 5 | Server restart: `make restart` from akk-stack/, then full server start (loginserver / world / 8 dynamic_NN zones per documented startup procedure). | infra-expert | Complete 2026-04-28 | Full stack restart confirmed (dedb777). 8 zones running. |
| 6 | In-game validation: 7 game-tester scenarios per Validation Plan (Scenarios 1, 2, 3, 4, 5, 6, 12 in architecture.md). User confirms. | game-tester | In Progress 2026-04-28 | Server-side PASS. In-game test guide at game-tester/test-plan.md. Awaiting user. |
| 7 | Commit and push all changes on `bugfix/companion-rez` in eqemu and claude repos. (akk-stack and spire have no changes.) | c-expert | Complete 2026-04-27 | eqemu pushed (30f6d6ef5, 83a96f655). claude pushed after dev-notes update. |
| V2.1 | Write 4 failing-first tests in Suite 36 of `cli_companion_tests.cpp` for V2 fixes. | c-expert | Complete 2026-04-27 | TDD red commit: b8c771a4f. Suite 36 confirmed RED at assertion 4 of test 36.1. |
| V2.2 | Implement Fix A: clear membername[] slot in Companion::Death() at companion.cpp:713-718. | c-expert | Complete 2026-04-27 | Part of fix commit 17662d4ba. |
| V2.3 | Implement Fix R4: IsAlive() guard at companion_ai.cpp:1935 + companion.cpp Process(). | c-expert | Complete 2026-04-27 | Part of fix commit 17662d4ba. |
| V2.4 | Implement Fix B: route ResurrectFromCorpse entity creation through Spawn(owner). | c-expert | Complete 2026-04-27 | Part of fix commit 17662d4ba. |
| V2.5 | Implement Fix C: atomic rez chain + Option D pre-flight group-capacity check. | c-expert | Complete 2026-04-27 | Part of fix commit 17662d4ba. |
| V2.7 | Rebuild + verify: all 36 suites PASS, no warnings. | c-expert | Complete 2026-04-27 | Build clean. Suite 36: 17 tests GREEN. Full suite: no regressions. |
| V2.10 | Commit + push V2 changes on bugfix/companion-rez in eqemu and claude repos. | c-expert | Complete 2026-04-27 | eqemu: b8c771a4f (red tests), 17662d4ba (fixes). claude: pending dev-notes commit. |

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
| BUG-001 | Cleric companion attempts rez post-combat but NPC companion stays down | High | user | Resolved (V2) — user-confirmed in-game 2026-04-28 (Jimble Woodentoe rez succeeded) | c-expert | 2026-04-28 |
| BUG-002 | NPC companions vanish from screen during combat if stationary (visibility heartbeat regressed) | High | user | Open | TBD (V3 architecture) | |
| BUG-003 | Companion HP/mana regen drastically slowed (~1%/report when sitting); possibly regen tick or gsay reporting cadence | High | user | Open | TBD (V3 architecture) | |

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
- [x] Suite 29 tests 29.14-29.17 PASS in `./bin/zone tests:companion`
- [x] Existing 13 Suite 29 tests still PASS (no regression)
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

---

# V2 — ResurrectFromCorpse Pipeline Fix

> In-game validation found the V1 fix made the spell reach the rez handler,
> but the handler itself has multiple bugs preventing the rez from succeeding
> end-to-end. V2 reopens the workflow at the architecture phase.

## V2 Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| V2 Architecture | architect + c-expert + data-expert advisors | Complete | 2026-04-28 | 2026-04-28 |
| V2 Implementation | c-expert + infra-expert + game-tester | Complete | 2026-04-27 | All V2 tasks complete; V2 binary running |
| V2 Validation | game-tester + user | In Progress | 2026-04-28 | Server-side PASS; awaiting user in-game confirmation |
| V2 Completion | _user_ | Not Started | | |

**Current phase:** V2 Validation — server-side PASS, awaiting user in-game confirmation.

## V2 Handoff Log

### V2: c-expert + data-expert (advisors) → architect (v2 plan)
- **Date:** 2026-04-28
- **Notes:** v2 architecture plan written and committed. Five C++ fixes
  identified across `companion.cpp` and `companion_ai.cpp`:
  - **Fix A:** Free dead companion's group `membername[]` slot at
    `Companion::Death` (`companion.cpp:713-718`). Prerequisite for B.
  - **Fix R4:** Add `IsAlive()` guards at `companion_ai.cpp:1935`
    (`AI_ResurrectDeadGroupMember`) and `companion.cpp:1908`
    (`Companion::Process`). Confirmed real (no existing guard; mana-at-death
    edge case allows dead Cleric self-rez).
  - **Fix B:** Route `ResurrectFromCorpse` through `Spawn(owner)` instead of
    manual `AddNPC`+setup (`companion.cpp:3632-3680`). Fixes wrong entity
    list, missing name normalization, missing immunity strip.
  - **Fix C:** Atomic rez chain — defer `corpse->DepopNPCCorpse()` until
    after `Spawn()` + `CompanionJoinClientGroup()` confirm success; pre-flight
    group-capacity check at top of `AI_ResurrectDeadGroupMember` (Option D).
  - ~~**Fix R2:**~~ **DEFERRED 2026-04-28 by user.** Fix R2 (cross-zone
    auto-unsuspend at 10% HP) is moved out of V2 to a separate future
    bugfix that will go through proper design-phase consultation with
    game-designer (R2 expands the AC-10 contract beyond what was
    originally locked, so it warrants its own design pass).
  - Plus 5–6 new tests in a new Suite 30 of `cli_companion_tests.cpp`.
  - **No DB schema changes. No Lua changes. No protocol changes. No new
    rules. Engine MAX_GROUP_MEMBERS=6 cap retained.**
  - **BUG-028 stays out of V2 scope** — corpse `m_companion_id` is independent
    of entity ID; existing fallback at `companion.cpp:662-701` handles the
    DB write correctly when entity id=0.
- **Spawn for V2 implementation:** c-expert, infra-expert, game-tester
  ONLY. Do NOT spawn lua-expert / data-expert / config-expert /
  protocol-agent / perl-expert (no V2 implementation tasks).

## V2 Implementation Tasks

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| V2.1 | Write 5–6 failing-first tests in Suite 30 of `cli_companion_tests.cpp` per architecture.md V2 test table. Build inside container; run via `./bin/zone tests:companion`; verify all V2 tests FAIL today. | c-expert | Not Started | TDD red commit before fix. |
| V2.2 | Implement Fix A: clear `membername[]` slot in `Companion::Death()` at `companion.cpp:713-718`. | c-expert | Not Started | Localized to companion.cpp; do not modify groups.cpp. |
| V2.3 | Implement Fix R4: `IsAlive()` guards at `companion_ai.cpp:1935` AND `companion.cpp:1908`. | c-expert | Not Started | Two-line fix; independent of A/B/C. |
| V2.4 | Implement Fix B: route `ResurrectFromCorpse` entity creation through `Spawn(owner)` at `companion.cpp:3632-3680`. Match `SpawnCompanionsOnZone` pattern. Don't double-call AI_Start. | c-expert | Not Started | Depends on V2.2 (Spawn calls CompanionJoinClientGroup which needs slot freed). |
| V2.5 | Implement Fix C: atomic rez — defer DepopNPCCorpse until Spawn+group-join confirm; reset IsRezzed(false) on failure; Option D pre-flight group-capacity check at top of `AI_ResurrectDeadGroupMember`. | c-expert | Not Started | Depends on V2.4. |
| ~~V2.6~~ | ~~Implement Fix R2~~ — **DEFERRED 2026-04-28 by user.** Removed from V2. Tracked as known-pending follow-up below. | — | DEFERRED | Cross-zone auto-unsuspend moved to separate future bugfix with game-designer involvement. |
| V2.7 | Rebuild zone binary. Re-run Suite 29 + Suite 30 — verify all 17 V1 tests still PASS and all V2 tests now PASS. Run full companion test suite (35 suites). | c-expert | Not Started | Zero new compiler warnings expected. |
| V2.8 | Server restart: `make restart` from akk-stack/, then full server start (loginserver / world / 8 dynamic_NN zones per documented startup procedure). | infra-expert | Not Started | Same pattern as V1 Task 5. |
| V2.9 | In-game validation: 8 game-tester scenarios per V2 Validation Plan (V2-1 through V2-8). User confirms BUG-001 closed. | game-tester | In Progress 2026-04-28 | Server-side: PASS WITH ANOMALY (symlink mtime — benign). All 36 suites GREEN. DB clean. V2 binary confirmed. In-game test plan at game-tester/test-plan.md V2 section. Awaiting user confirmation. |
| V2.10 | Commit and push V2 changes on `bugfix/companion-rez` in eqemu and claude repos. (akk-stack and spire have no V2 changes.) | c-expert | Not Started | After V2.7 confirms green; per fix or batched per c-expert preference. |

## V2 Open Questions

All V2 architectural questions resolved during the architecture phase.

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| V2.1 | Group cap policy — keep `MAX_GROUP_MEMBERS=6` or expand for companions? | team-lead | architect | RESOLVED 2026-04-28 | Keep engine default. Touches client/server boundary if expanded. Fix A returns the leaked slot — real capacity restored. |
| V2.2 | Cross-zone rez persistence — should pending rez state survive owner zoning? | team-lead | architect | DEFERRED 2026-04-28 | Initial decision was to include Fix R2 in V2. User reviewed v2 plan and chose to descope R2 because it expands the AC-10 contract beyond original PRD. R2 successor bugfix will go through design phase with game-designer. `!unsuspend` is the recovery path until then. |
| V2.3 | BUG-028 entity-id-0 in V2 scope or separate? | team-lead | architect | RESOLVED 2026-04-28 | Out of V2 scope. Both c-expert and data-expert verified `m_companion_id` is independent of entity id; existing fallback at `companion.cpp:662-701` is correct; BUG-028 does not corrupt corpse metadata or amplify rez bugs. |
| V2.4 | Atomicity approach — DB transaction, defer UPDATE, or other? | architect | data-expert | RESOLVED 2026-04-28 | Option D (pre-flight group-capacity check) + Option C (defer corpse depop until after Spawn+group join). NO MariaDB transaction (cannot un-depop the corpse). NO pure Option A defer-UPDATE (creates worse crash window). Direct SQL UPDATE on rollback. |
| V2.5 | Is R-4 dead-caster self-rez a real bug? | architect | c-expert | RESOLVED 2026-04-28 | YES. No alive guard exists in `AI_ResurrectDeadGroupMember` or upstream `Process()`/`AI_Process()`/`CastSpell()`. OOM gate prevents normal case; mana-at-death edge case allows it. Fix R4 adds two `IsAlive()` guards (~6 lines total). |

## V2 Bug Reports

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| BUG-001 (V2 reopen) | Cleric companion attempts rez post-combat; rez fires (V1 fix) but rezzed companion not in same zone as group; second companion never rezzed | High | user | V2 Architecture Complete | c-expert (V2 implementation pending) | |

## V2 Decision Log

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| V2-1 | Four C++ fixes (A, R4, B, C) in `companion.cpp` + `companion_ai.cpp`. No DB / Lua / protocol / rule changes. (Originally five; Fix R2 descoped 2026-04-28 — see V2-8.) | architect | 2026-04-28 | Bugs are entity-lifecycle / atomicity — all C++ application logic. data-expert v2: no DB transactions help (corpse is in-memory). lua-expert v1: no Lua hooks in rez path. protocol-agent v1: no Titanium client packet changes needed. |
| V2-2 | Keep `MAX_GROUP_MEMBERS=6`. Do NOT expand for companions. | architect | 2026-04-28 | Engine constant flows through dozens of code paths + Titanium client UI assumptions. Fix A returns the leaked dead slot — restoring real capacity for the 1 player + 5 companions target. |
| V2-3 | ~~Cross-zone rez persistence in scope via Fix R2.~~ **REVERSED 2026-04-28** — see V2-8 for the descope decision. | architect → user | 2026-04-28 | Originally judged in-scope by architect; user reviewed and chose to descope because R2 expands the AC-10 contract beyond original PRD (warrants its own design phase with game-designer). |
| V2-4 | BUG-028 out of V2 scope. | architect | 2026-04-28 | Both c-expert and data-expert verified BUG-028 does not corrupt corpse `m_companion_id` or amplify rez bugs. Existing fallback at companion.cpp:662-701 handles the DB save correctly. Stays in backlog. |
| V2-5 | Atomicity via Option D + Option C, NOT MariaDB transaction. | architect | 2026-04-28 | data-expert v2: corpse is in-memory only (no DB row), so transactions cannot un-depop. Pure Option A (defer UPDATE) creates worse crash window. Option D (pre-flight check) prevents most common failure mode; Option C (defer depop with rollback) handles late failures. |
| V2-6 | R-4 dead-caster self-rez confirmed real; Fix R4 (two `IsAlive()` guards) included in V2. | architect | 2026-04-28 | c-expert v2 traced full call chain; no alive guard anywhere; mana-at-death edge case allows dead Cleric to self-rez. Defense-in-depth at minimal cost (~6 lines). |
| V2-7 | ~~Cross-zone auto-unsuspend HP percentage hardcoded at 10%.~~ **MOOT 2026-04-28** — Fix R2 was descoped; HP percentage decision moves to the R2 successor bugfix's design phase. | architect → user | 2026-04-28 | Decision irrelevant to V2 minus R2; preserved as a starting point for future R2 design. |
| V2-8 | **Fix R2 (cross-zone auto-unsuspend) DESCOPED from V2 to a separate future bugfix.** | user (via team-lead) | 2026-04-28 | R2 expands the AC-10 contract beyond what was originally locked in the PRD. It deserves its own design pass with game-designer involvement (10% HP recovery semantics, fire-always vs gated, flavor message tone, interaction with future class extensions). V2 ships A/R4/B/C only. The "second companion not rezzed when owner zones out" symptom is moved to known-pending follow-ups (workaround: `!unsuspend`). |

## V2 Completion Checklist

### V2 Implementation Complete (agents check these)

- [ ] All V2 implementation tasks (V2.1–V2.10) marked Complete
- [ ] Suite 30 tests V2 set PASS in `./bin/zone tests:companion`
- [ ] Existing 17 Suite 29 tests still PASS (no V1 regression)
- [ ] All 35 companion test suites still PASS (no broader regression)
- [ ] game-tester V2 in-game validation: PASS for all 8 V2 scenarios
- [ ] User completed in-game testing: PASS (BUG-001 V2 fully resolved)
- [ ] V2 changes committed and pushed to `bugfix/companion-rez` in eqemu and claude repos
- [ ] All V2 phases marked Complete in V2 Workflow Status

### V2 Merge & Cleanup (USER-INITIATED ONLY)

- [ ] User confirmed V2 fix is complete
- [ ] (User to decide whether to also merge V1 + V2 together to main when project is fully complete)

## V2 Known-Pending Follow-ups (post-V2)

_Items intentionally deferred from V2 scope. These are not blockers for V2
shipping; they are tracked here so they don't get lost between bugfixes._

| # | Item | Symptom | Workaround | Future Action |
|---|------|---------|-----------|---------------|
| FU-1 | **Cross-zone rez resilience (was Fix R2)** | When the owner zones out while NPC companions are dead, the dead companions stay `is_suspended=1` indefinitely until the owner manually `!unsuspend`s them. The "second companion was never rezzed" portion of the user's BUG-001 V2 report falls in this category. | `!unsuspend <companion-name>` after the owner returns to a zone with the dead companion in their roster. | A separate bugfix workspace (suggested branch: `bugfix/companion-rez-crosszone`) goes through the full pipeline starting at design phase with game-designer involvement to settle: (a) recovery semantics (10% HP / 0% rez XP vs alternative), (b) fire-always vs gated by player setting / rule, (c) flavor message tone, (d) interaction with future Necromancer/Druid/Paladin auto-rez extensions. The architectural foundation for this work is preserved in the V2 architecture doc's "Fix R2" section (marked DEFERRED) and in c-expert's dev-notes Stage 5 Q6 + Stage 6 Q6 — engineers can pick up the design context when the R2 successor enters its own design phase. |

## V2 Notes

- The V2 plan respects the V1 fix as load-bearing — V2 builds on top of
  V1's `spells.cpp:2051` `ST_Corpse` extension and `FindDeadGroupMemberCorpse`
  player-corpse extension. V2 does NOT touch those V1 changes.
- V2 is the second pass after V1's "make the spell reach the handler" pass.
  V2's pass is "make the handler succeed end-to-end." This separation is
  natural: V1's signal was "nothing happens at all"; V2's signal is
  "something happens but the result is wrong." Different layers of bug,
  different fixes, but same architecture document.
- The companion-rerecruit foundation (`is_suspended=1` death-state row
  preserved) is what Fix R2 reads when auto-unsuspending on zone-in (NOTE: Fix R2 is DEFERRED from V2 — see V2-8 in Decision Log).
  Without companion-rerecruit, V2 would have no row to recover from. V2
  builds on companion-rerecruit cleanly.
