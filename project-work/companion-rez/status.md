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
| BUG-002 | NPC companions vanish from screen during combat if stationary (visibility heartbeat regressed) | High | user | Re-Triage (V3-redo) — prior V3 plan superseded 2026-04-29 | TBD (V3-redo architecture) | |
| BUG-003 | Companion HP/mana regen drastically slowed (~1%/report when sitting); possibly regen tick or gsay reporting cadence | High | user | Re-Triage (V3-redo) — prior V3 plan superseded 2026-04-29 | TBD (V3-redo architecture) | |
| BUG-004 | Player harmful AoE spells (mez, stun) affect own NPC companions; AoE friend/foe filter regressed | High | user | Open — Re-Triage (V3-redo) 2026-04-29 | TBD (V3-redo architecture) | |
| BUG-005 | Companion 30-minute auto-dismiss timer broken for dead companions (same Fix R4 root cause as BUG-002) | Medium | c-expert (V3 Re-Triage) | Open — bundled with BUG-002 Fix V Option A 2026-04-29 | c-expert (V3 Re-Triage implementation) | |

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

---

# V3 — Visibility & Regen Regression Fix

> User reported two regressions of previously-fixed behavior after V2 landed:
> BUG-002 (companions vanish from screen during combat when stationary) and
> BUG-003 (HP/mana regen reports show ~1%/report when sitting). V3 reopens
> the workflow at the architecture phase.

## V3 Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| V3 Architecture | architect + c-expert + protocol-agent + lua-expert (advisors) | Complete | 2026-04-28 | 2026-04-28 |
| V3 Implementation | c-expert + infra-expert + game-tester | Not Started | | |
| V3 Validation | game-tester | Not Started | | |
| V3 Completion | _user_ | Not Started | | |

**V3 Current phase:** Architecture (complete) — awaiting user review before
implementation team is spawned. Will transition to Implementation after user
confirms the V3 plan.

---

## V3 Handoff Log

### V3 architect → V3 implementation team (c-expert + infra-expert + game-tester)
- **Date:** 2026-04-28
- **Notes:** V3 architecture posted to `architect/architecture.md` as new section
  "V3: Visibility & Regen Regression Fix" (preserves V1 + V2 sections intact).
  **Confirmed root cause for BUG-002:** V2 Fix R4 at `companion.cpp:1933-1935`
  blanket early-return for HP=0 entities skips the prior heartbeat (`m_ping_timer`
  → `SentPositionPacket`) at `companion.cpp:2128-2142` AND the death-despawn timer
  at `companion.cpp:1937-1964`. Pre-V2 baseline: dead companion entities ran the
  full `Companion::Process()` body (no top-level guard); the heartbeat fired every
  5s and Titanium kept rendering the body until rez or auto-dismiss. Post-V2,
  dead entities skip both → Titanium culls after 5-10s → user perceives
  "companion vanished mid-combat."
  **BUG-003 likely NOT a V2 regression** — empirical math (level 54 cleric,
  meditate=295 → `final_regen=36/tick`) shows "1%/report at 15s cadence" is
  consistent with freshly-rezzed companion at 0 mana climbing toward a large
  max_mana pool. lua-expert + c-expert independently verified all regen and
  reporting code unchanged from before V2. V3-5 + V3-6 game-tester baselines
  required to differentiate misperception vs real regression.
  **V3 Fix V (Option A recommended):** restructure `Companion::Process()`
  top-section to capture `bool is_dead = (GetHP() <= 0);` and wrap AI-dispatch-only
  sections in `if (!is_dead)` guards — preserves heartbeat, despawn timer, and
  group-cleanup runs for dead entities. Defensive layer at heartbeat block:
  bypass `IsMoving()` when `m_hold_combat_position == true` to close
  protocol-agent's open `IsMoving()` hypothesis.
  **Spawn: c-expert (V3.1, V3.2, V3.3, V3.7), infra-expert (V3.4), game-tester
  (V3.5). Architect rejoins at V3.6 to decide BUG-003 follow-up.** Do NOT spawn
  lua-expert / data-expert / config-expert / protocol-agent / perl-expert —
  they have no V3 implementation tasks.

---

## V3 Implementation Tasks

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| V3.1 | Write 4 new failing tests in Suite 36 of `cli_companion_tests.cpp` (V3.1 heartbeat-for-dead, V3.2 despawn-timer-for-dead, V3.3 defensive-heartbeat-in-held-position, V3.4 alive-companion-regression-guard). Build + run. Verify V3.1, V3.2, V3.3 fail and V3.4 passes pre-fix. | c-expert | Not Started | TDD red |
| V3.2 | Implement Fix V Option A: restructure `Companion::Process()` top-section per architecture.md. `bool is_dead = (GetHP() <= 0);` capture + `if (!is_dead)` guards on AI dispatch sections. Plus defensive heartbeat layer (`m_hold_combat_position` bypass). | c-expert | Not Started | ~25 lines C++ |
| V3.3 | Rebuild zone binary inside container. Re-run Suite 36 — verify V3.1-V3.3 now PASS, V3.4 still passes, all V1/V2 tests unchanged. Run full companion test suite. | c-expert | Not Started | runtime |
| V3.4 | `make restart` + full server stack startup (loginserver / world / 8 dynamic_NN zones per documented procedure). | infra-expert | Not Started | runtime |
| V3.5 | In-game validation per V3 Validation Plan: 8 scenarios (V3-1 sustained combat 5+ min PRIMARY, V3-2 caster held position 60+s, V3-3 dead-entity 30-min lifecycle, V3-4 V1+V2 regression re-run, V3-5 BUG-003 non-rezzed sit baseline, V3-6 BUG-003 post-rez sit baseline, V3-7 multi-zone-cycle, V3-8 multi-rez-cycle). | game-tester | Not Started | manual + sustained |
| V3.6 | Architect decides BUG-003 follow-up scope based on V3.5 game-tester data. Close as misperception vs scope V3-followup bugfix. | architect | Not Started | analysis |
| V3.7 | Commit and push V3 changes on `bugfix/companion-rez` in eqemu and claude repos. (akk-stack and spire have no V3 changes.) | c-expert | Not Started | git |

---

## V3 Open Questions

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| V3-Q1 | Is V2's Fix B `Spawn()` reroute shared with normal recruit + zone-in? | architect | c-expert | RESOLVED 2026-04-28 | YES — three call sites; Spawn() itself unchanged by V2; first-recruit + zone-in unaffected. |
| V3-Q2 | What was the prior heartbeat fix? | architect | c-expert | RESOLVED 2026-04-28 | Commit `9e4b7dfd1` (2026-03-09). `m_ping_timer(5000)` + `SentPositionPacket(0,0,0,0,0)` keepalive at `companion.cpp:2128-2142`. Code intact post-V2 but bypassed by Fix R4 for HP=0 entities. |
| V3-Q3 | Is BUG-003 actual regen broken or reporting cadence broken? | architect | lua-expert + c-expert | LIKELY MISPERCEPTION 2026-04-28 | Empirical math shows "1%/report" consistent with freshly-rezzed companion at 0 mana. V2 made no change to regen/reporting code. game-tester V3-5 + V3-6 baselines required to confirm before any code change. |
| V3-Q4 | Is there a fourth bug we haven't seen? | architect | c-expert | TWO LATENTS 2026-04-28 | (1) `entity.cpp:2044` `GetCorpseByOwnerWithinRange` range fragility (pre-existing, accidentally correct at default rule). (2) Fix A cross-zone group risk (low real-world risk; companions are zone-local). Neither in V3 scope. |
| V3-Q5 | Does BUG-003 need to ship in same V3 round or as follow-up? | architect | architect | RESOLVED 2026-04-28 | FOLLOW-UP. Bundling speculative fix violates user's regression-discipline feedback. game-tester V3-5/V3-6 verifies first; architect decides at V3.6. |

---

## V3 Bug Reports (status updates)

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| BUG-002 | NPC companions vanish from screen during combat if stationary (visibility heartbeat regressed) | High | user | **Investigating** — V3 architecture complete; fix in V3 implementation queue | c-expert (V3.2) | |
| BUG-003 | Companion HP/mana regen drastically slowed (~1%/report when sitting); possibly regen tick or gsay reporting cadence | High | user | **Investigating** — likely misperception per c-expert + lua-expert empirical math; game-tester V3-5/V3-6 baselines pending; architect decides V3.6 follow-up scope | game-tester (V3.5) → architect (V3.6) | |

---

## V3 Decision Log

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| V3-1 | BUG-002 root cause = V2 Fix R4 blanket early-return for HP=0 entities skips heartbeat + despawn timer | architect (c-expert + protocol-agent triage) | 2026-04-28 | Pre-V2 dead companions ran full Process() body; heartbeat fired every 5s; Titanium kept rendering. Post-V2 they skip the body. |
| V3-2 | BUG-003 likely NOT a V2 regression; empirical verification first | architect (lua-expert + c-expert math) | 2026-04-28 | All regen and reporting code unchanged from before V2; "1%/report" math consistent with freshly-rezzed climb-from-zero. User regression-discipline feedback explicitly disallows speculative fixes. |
| V3-3 | Fix V Option A (Process() restructure with `is_dead` capture + AI-dispatch guards) over Option B (early-return + inline heartbeat duplication) | architect | 2026-04-28 | Cleaner long-term shape; reads inline; no code duplication of despawn timer body; Option B is fallback if engineer prefers. |
| V3-4 | Defensive heartbeat layer (`m_hold_combat_position` bypass on `IsMoving()` gate) included in same Fix V | architect (protocol-agent hypothesis) | 2026-04-28 | Closes protocol-agent's open hypothesis (NPC AI rotation may set `moving=true` mid-combat) defensively without waiting for empirical confirmation. Risk zero. |
| V3-5 | Sustained-play game-tester scenarios mandatory in V3 (per user regression-discipline feedback) | architect | 2026-04-28 | V2's brief-encounter scenarios missed BUG-002/003. V3-1 (5+ min combat), V3-3 (30-min dead lifecycle), V3-7 (multi-zone), V3-8 (multi-rez) added. |
| V3-6 | Two latent bugs flagged but NOT in V3 scope: `entity.cpp:2044` range fragility and Fix A cross-zone group risk | architect (c-expert fourth-bug scan) | 2026-04-28 | Neither is V2 regression nor user-visible. File separately to keep V3 surface tight. |
| V3-7 | BUG-003 follow-up bugfix conditional on V3-5/V3-6 verification result | architect | 2026-04-28 | If misperception, close with runbook note. If real regression, scope separate bugfix with new evidence — do NOT bundle with V3 visibility fix. |

---

## V3 Notes

- The V3 plan is the third architecture cycle on this bugfix branch. The user has
  explicitly flagged regression discipline (`feedback_refactor_regression_discipline.md`):
  "make sure that when we do these large refactors we are being extremely careful not
  to break existing functionality." The V3 plan responds with: enumeration of adjacent
  functionality (c-expert fourth-bug scan), sustained-play test scenarios (V3-1 5+ min,
  V3-3 30-min, V3-7 multi-zone, V3-8 multi-rez), empirical-first BUG-003 approach
  (no speculative code change), and explicit deferral of latent bugs out of V3 scope
  to keep the surface tight.
- The V3 fix is structurally smaller than V1 or V2 — one targeted change in one
  function — but the validation plan is intentionally larger to compensate for the
  V2 oversight that missed the sustained-play regressions.
- Per the user's regression-discipline feedback, the V3 plan explicitly does NOT
  bundle a speculative BUG-003 fix with the confirmed BUG-002 fix. game-tester
  empirical baseline runs first; architect decides BUG-003 scope at V3.6.


---

## V3 Amendment — IsMoving() Hypothesis Ruled Out (2026-04-29)

c-expert ruled out protocol-agent's open hypothesis with code-grounded RotateToCommand math (`td ≈ 380 ≥ max heading delta 256` → rotation completes in one tick → `IsMoving()=false` at next Process() tick). The defensive `m_hold_combat_position` heartbeat bypass (Fix V Subtlety #2) is removed from V3 scope per the user's regression-discipline feedback (no defensive layers without empirical justification). V3 Fix V is now strictly Option A — restructure `Companion::Process()` top-section.

**V3 Implementation Tasks (Revised — supersedes earlier table)**

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| V3.1 | Write 3 new failing tests in Suite 36: heartbeat-for-dead, despawn-timer-for-dead, alive-companion-regression-guard. (Removed: defensive-heartbeat-in-held-position — hypothesis ruled out.) | c-expert | Not Started | TDD red |
| V3.2 | Implement Fix V Option A: restructure `Companion::Process()` top-section. `bool is_dead = (GetHP() <= 0);` capture + `if (!is_dead)` guards on AI dispatch. (Removed: `m_hold_combat_position` bypass at heartbeat block.) | c-expert | Not Started | ~25 lines C++ |
| V3.3 | Rebuild + verify all V1/V2 tests still pass + new V3 tests pass. | c-expert | Not Started | runtime |
| V3.4 | `make restart` + full server stack startup. | infra-expert | Not Started | runtime |
| V3.5 | In-game validation: 8 scenarios (V3-1 through V3-8 per architecture.md). | game-tester | Not Started | manual + sustained |
| V3.6 | Architect decides BUG-003 follow-up scope based on V3.5 game-tester data. | architect | Not Started | analysis |
| V3.7 | Commit and push V3 changes on `bugfix/companion-rez` in eqemu and claude repos. | c-expert | Not Started | git |

**V3 Decision Log addition**

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| V3-8 | Defensive `m_hold_combat_position` heartbeat bypass (Fix V Subtlety #2) REMOVED from V3 scope | architect (c-expert empirical math) | 2026-04-29 | c-expert ruled out the IsMoving() flicker hypothesis with code-grounded math: RotateToCommand completes in one movement-manager tick (`td≈380 ≥ max delta 256`), main loop ordering ensures `IsMoving()=false` at next Process() tick. Defensive layers without empirical justification are risk surface for zero gain (regression-discipline feedback). YAGNI applied. |

---

# V3 — RE-TRIAGED (2026-04-29)

> The earlier V3 architecture cycle (above) is **SUPERSEDED**. The user
> directed a complete re-process of BUG-002, BUG-003, and BUG-004
> together, with explicit emphasis on the customized NPC and Spawn
> systems and their downstream consumers. The prior V3 plan was scoped
> only to BUG-002 + BUG-003 and was produced before the architect agent
> definition was updated with customized-system awareness discipline.
>
> This V3 Re-Triage section is the new ground truth. The prior V3 plan
> remains on disk as historical reference but is NOT to be implemented
> as-is. The new architecture team starts fresh and may arrive at a
> different fix shape for BUG-002/003 once BUG-004 and the
> customized-system enumeration are factored in.

## V3 Re-Triage Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| V3 Re-Triage Architecture | architect (lead) + c-expert + protocol-agent + lua-expert + data-expert (advisors) | Not Started | | |
| V3 Re-Triage Implementation | TBD per architect's task breakdown | Not Started | | |
| V3 Re-Triage Validation | game-tester | Not Started | | |
| V3 Re-Triage Completion | _user_ | Not Started | | |

**V3 Re-Triage current phase:** Architecture (re-engaging fresh).

## V3 Re-Triage Scope

Three open bugs in the same regression family:

- **BUG-002** — NPC companions vanish from screen during combat
  when stationary (visibility heartbeat regression).
- **BUG-003** — Companion HP/mana regen drastically slowed
  (~1%/report when sitting); user uncertain whether actual regen
  or gsay reporting cadence.
- **BUG-004** — Player harmful AoE spells (mez, stun) affect own
  NPC companions; AoE friend/foe filter regressed.

**Working hypothesis (architect to confirm or refute):** All three
bugs share a root cause in V2's entity-registration / Spawn-pipeline
changes. V2's Fix B routed `ResurrectFromCorpse` through `Spawn(owner)`
and Fix A cleared `membername[]` slot at Death. Downstream subsystems
that consume customized companion entity-list metadata, group-membership
state, or owner-pointer ownership may have been silently affected.

## V3 Re-Triage Architecture Mandates

The architect MUST satisfy these mandates in the re-triage architecture
doc, not optional:

1. **Customized-system enumeration is the primary deliverable.** Per
   updated architect agent definition, the architect must enumerate
   every downstream consumer of the customized NPC / Spawn / entity-list
   / group / AI-tick metadata that V2 touched. The fix shape comes
   second; the enumeration comes first. A shallow enumeration means the
   architecture phase is incomplete.
2. **All three bugs analyzed together.** Do not silo BUG-002, BUG-003,
   and BUG-004 into separate analyses. They are a triage cluster — find
   the shared root cause(s) before designing fixes.
3. **Empirical-first on BUG-003.** Prior V3 verdict was "likely
   misperception"; that verdict is preserved as a hypothesis, not a
   conclusion. Mandate empirical measurement before any code change for
   BUG-003 (SQL polling of mana field cadence vs gsay frequency).
4. **Sustained-play test scenarios mandatory.** Per
   `feedback_refactor_regression_discipline.md`, the validation plan
   includes long-duration combat (5+ min), long-duration sitting
   regen, multi-zone cycles, multi-rez cycles, and sustained AoE
   encounter scenarios.
5. **Adjacent-system regression coverage.** For each customized
   subsystem the fix touches, the validation plan must include a
   regression test for at least one consumer — not only the symptom
   the fix targets.
6. **Treat the prior V3 plan as one input among many.** It is not
   gospel. The new architect cycle may arrive at a different fix
   shape if the BUG-004 + customized-system enumeration changes the
   picture.

## V3 Re-Triage Decision Log

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| V3R-1 | Prior V3 architecture plan (V3-1 through V3-8) is superseded; fresh architecture cycle re-engaged with all three bugs in scope | user (via team-lead) | 2026-04-29 | Prior V3 was scoped only to BUG-002 + BUG-003 and predates the architect agent's updated customized-system awareness discipline. User explicitly directed a complete re-process. |
| V3R-2 | Architect agent definition updated 2026-04-29 to add "CRITICAL: Customized System Awareness" section with mandate to enumerate downstream consumers before designing fixes on customized NPC/Spawn paths | user (via team-lead) | 2026-04-29 | Two prior bugfix V2 cycles silently broke adjacent customized-system behaviors. The discipline addition is structural, not advisory. |
| V3R-3 | All three bugs (BUG-002, BUG-003, BUG-004) analyzed as a triage cluster; not siloed | user (via team-lead) | 2026-04-29 | Strong correlation across all three: V2 entity-registration changes affect downstream subsystems that consume companion metadata. Root cause likely shared. |




## V3 Re-Triage Workflow Status (UPDATED 2026-04-29)

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| V3 Re-Triage Architecture | architect (lead) + c-expert + protocol-agent + lua-expert + data-expert + config-expert (advisors) | **Complete** | 2026-04-29 | 2026-04-29 |
| V3 Re-Triage Implementation | c-expert + infra-expert + game-tester (data-expert conditionally for V3R.6.5) | Awaiting User Approval | | |
| V3 Re-Triage Validation | game-tester | Not Started | | |
| V3 Re-Triage Completion | _user_ | Not Started | | |

**V3 Re-Triage current phase:** Architecture COMPLETE — awaiting user review of architecture-complete summary before implementation team is spawned.

## V3 Re-Triage Handoff Log

### game-tester → user (V3R in-game validation pending)
- **Date:** 2026-04-29
- **Notes:** V3R server-side validation: PASS. Binary built 2026-04-29 14:15 with Fix V Option A + Fix W α (commits 1c03ce9ea TDD red + 035d33348 fix). All Suite 37 V.1/V.2/W.1 GREEN. All 36 prior suites still pass (0 regressions). DB: 5 companion rows, 0 orphaned FKs, 1 pre-existing suspended row (Jimble). All V3R rules confirmed. 8 zones running, no errors in logs. Full in-game test plan at `game-tester/test-plan.md` V3R section: 7 numbered scenarios (V3R-1 heartbeat, V3R-2 auto-dismiss 30min, V3R-3 AoE, V3R-5 5+min combat, V3R-7 multi-zone, V3R-8 multi-rez, V3R-9 sustained AoE) + 3 regression tests. Awaiting user in-game confirmation to close BUG-002 + BUG-004 + BUG-005.

### V3R architect → V3R implementation team (c-expert + infra-expert + game-tester)
- **Date:** 2026-04-29
- **Notes:** V3R Architecture posted to `architect/architecture.md` as new section "V3 Re-Triage Architecture (2026-04-29)" — preserves V1, V2, prior V3 sections intact as historical record.

  **Working hypothesis REFUTED.** Three independent root causes (not a shared V2 root cause):
  - **BUG-002** = V2 Fix R4 early-return at companion.cpp:1933 skips `m_ping_timer` heartbeat → Titanium culls. Two-advisor convergence (c-expert C-1 + protocol-agent P-1).
  - **NEW BUG-005** = Same Fix R4 early-return ALSO skips `m_death_despawn_timer.Check()` → 30-min auto-dismiss not enforced. Discovered by c-expert C-5 / B.2 enumeration. **The prior V3 plan missed this.** Same root cause as BUG-002, same fix, zero additional surface.
  - **BUG-004** = Pre-existing gap (NOT V2 regression). Companions don't `SetOwnerID()`; `_NPC(x)` matrix in `Mob::IsAttackAllowed` returns true; client-vs-NPC branch unconditionally allows attack. Two paths: base IsAttackAllowed + IsPetOwnerOfClientBot for ST_TargetAENoPlayersPets. Three-advisor convergence (c-expert C-2 + config-expert G-3 + data-expert D-3). V2 Fix B may have made it more visible by ensuring rezzed companions are reliably registered.
  - **BUG-003** = Most likely **rule-tuning divergence** (G-10): player has `Character:ManaRegenMultiplier=175` (1.75x), companions have `Companions:CompanionManaRegenMult=100` (no scaling). Four-advisor convergence on regen code path being unchanged by V2. Empirical-first per Mandate 3.

  **Fix surface:**
  - **Fix V (Option A):** ~25 lines C++ restructure of `Companion::Process()` top-section. `bool is_dead` capture + `if (!is_dead)` guards on AI-dispatch sections (B.3 / B.4 / B.7 / B.8 / B.9 / B.10 / B.11). Heartbeat (B.1) and despawn timer (B.2) UNCONDITIONAL. **Fixes BUG-002 + BUG-005.**
  - **Fix W (α):** ~10-15 lines C++ across 2 sites. Site 1: `Mob::IsAttackAllowed` `_CLIENT vs _NPC` matrix — surgical insert checking `mob2->IsCompanion() && CastToCompanion()->GetOwnerCharacterID() == caster_char_id`. Site 2: `IsPetOwnerOfClientBot` extension or sibling check at `effects.cpp:1143-1145` for `ST_TargetAENoPlayersPets`. Codebase precedent at `entity.cpp:5636`. **Fixes BUG-004.**
  - **V3R-Empirical-1 (BUG-003 protocol):** 4-test in-game protocol with rule-bump branch (data-expert D-13 + config-expert G-11 inserted as Test 1.5). Discriminator is in-game `!status` mana observation (not SQL polling — D-11 invalidated SQL polling because `companion_data.cur_mana` only writes at lifecycle Save() events). Decision matrix routes outcomes: Branch B-misperception (close with note), Branch B-rule (one rule UPDATE), Branch A/C/D (escalate to follow-up bugfix).

  **Tests added:** 4 new failing-first tests in Suite 36 of `cli_companion_tests.cpp` — V.1 (heartbeat-for-dead), V.2 (despawn-timer-for-dead), V.3 (alive-companion-regen-regression-guard), W.1 (aoe-excludes-owner-companion).

  **No Lua, Perl, schema, or protocol changes.** All Lua-side consumers enumerated by lua-expert are LOW or NONE risk; gsay reporting confirmed C++-only. No data_buckets keys affected. No schema migration between V1 and V2.

  **Spawn for V3R implementation:** c-expert (V3R.1, V3R.2, V3R.3, V3R.4, V3R.8), infra-expert (V3R.5), game-tester (V3R.6). Architect rejoins at V3R.7. data-expert conditionally re-spawned for V3R.6.5 only if Branch B-rule confirmed. **Do NOT spawn lua-expert / config-expert / protocol-agent** — they have no V3R implementation tasks; Round 1 advisory work is complete.

  **Workflow gate:** Implementation does NOT proceed until user explicitly approves the architecture-complete summary per the V3R brief.

  **Orchestrator-owned follow-up:** BUG-005 needs a formal bug-report file at `claude/project-work/companion-rez/bugs/BUG-005-companion-auto-dismiss-timer-broken/report.md`. Per CLAUDE.md, orchestrator (not architect) creates BUG-NNN files. Architect surfaces this in the architecture-complete summary.

## V3 Re-Triage Implementation Tasks

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| V3R.1 | Write 4 failing-first tests in Suite 36 of `cli_companion_tests.cpp`: V.1 (heartbeat-for-dead), V.2 (despawn-timer-for-dead), V.3 (alive-companion-regen-regression-guard), W.1 (aoe-excludes-owner-companion). Build the test binary inside the container. Verify V.1, V.2, W.1 FAIL pre-fix; V.3 PASSES pre-fix. | c-expert | Not Started | TDD red commit before any fix |
| V3R.2 | Implement Fix V Option A: restructure `Companion::Process()` top-section. `bool is_dead = (GetHP() <= 0);` capture + `if (!is_dead)` guards on AI-dispatch sections (B.3, B.4, B.7, B.8, B.9, B.10, B.11). Keep B.1 heartbeat AND B.2 `m_death_despawn_timer.Check()` UNCONDITIONAL. Reference c-expert formal enumeration B.1–B.11 for exact line guard mapping. ~25 lines C++. | c-expert | Not Started | Replaces V2 Fix R4 alive-guard with Option A pattern |
| V3R.3 | Implement Fix W α: two-site IsCompanion-aware AoE exclusion. Site 1 in `aggro.cpp` `Mob::IsAttackAllowed` `_CLIENT vs _NPC` matrix — surgical insert before the matrix returns true. Site 2 in `effects.cpp:1143-1145` `IsPetOwnerOfClientBot` extension or sibling check for `ST_TargetAENoPlayersPets`. Reference codebase precedent at `entity.cpp:5636`. ~10-15 lines C++ across 2 sites. | c-expert | Not Started | Parallelizable with V3R.2 |
| V3R.4 | Rebuild zone binary (`docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`). Re-run Suite 36 — verify V.1, V.2, W.1 PASS, V.3 still PASSES, all V1/V2 tests unchanged. Run full companion test suite. | c-expert | Not Started | Build verification |
| V3R.5 | `make restart` from akk-stack/, then full server stack startup (loginserver / world / 8 dynamic zones per documented procedure). | infra-expert | Not Started | runtime |
| V3R.6 | In-game validation per V3R Validation Plan: 9 sustained-play scenarios (V3R-1 through V3R-9 in architecture.md V3R section) + V3R-Empirical-1 4-test protocol for BUG-003. Branch routing per decision matrix. | game-tester | Not Started | manual + sustained |
| V3R.7 | Architect rejoins for BUG-003 final decision based on V3R.6 results. Routes to: (a) close with no V3R action (Branch B-misperception), (b) trigger V3R.6.5 (Branch B-rule), (c) file follow-up bugfix (Branch A/C/D). | architect | Not Started | analysis |
| V3R.6.5 (conditional) | Execute BUG-003 rule UPDATE: `UPDATE rule_values SET rule_value='175' WHERE rule_name='Companions:CompanionManaRegenMult';` + `#rules reload` (or `#rules set <Rule> <Value>` for transient test) + verify. ONLY runs if Branch B-rule confirmed at V3R.7. | data-expert | Conditional | One UPDATE + reload |
| V3R.8 | Commit and push V3R changes on `bugfix/companion-rez` in eqemu and claude repos. Includes code commits for Fix V + Fix W + tests, the rule UPDATE if applied, architecture and status updates. | c-expert | Not Started | git |

## V3 Re-Triage Decision Log (UPDATED)

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| V3R-D1 | Three independent root causes for BUG-002 / BUG-003 / BUG-004; not a shared V2 root cause | architect (Round 1 three-advisor convergence) | 2026-04-29 | Working hypothesis refuted by c-expert C-2 + lua-expert L-5 + data-expert D-3 + config-expert G-3 |
| V3R-D2 | NEW BUG-005 discovered during enumeration: 30-minute auto-dismiss timer broken by Fix R4 | architect (c-expert C-5 / B.2 finding) | 2026-04-29 | Same root cause as BUG-002; same fix; zero additional surface. The prior V3 plan missed this. |
| V3R-D3 | BUG-002 + BUG-005 fix: Option A pattern with heartbeat + despawn timer kept UNCONDITIONAL | architect | 2026-04-29 | Two-advisor convergence on shape; despawn timer must be unconditional too |
| V3R-D4 | BUG-004 fix shape α (narrow IsCompanion exclusion at 2 sites) over β (SetOwnerID with wide blast radius) and γ (Client-side override only) | architect | 2026-04-29 | β rejected per Mandate principle of minimum blast radius; γ insufficient (doesn't address Site 2); α follows codebase precedent at entity.cpp:5636 |
| V3R-D5 | BUG-003 empirical-first via D-13 4-test protocol + G-11 rule-bump as Test 1.5 | architect | 2026-04-29 | Mandate 3; strongest hypothesis (G-10 rule-tuning divergence) is testable without code change |
| V3R-D6 | BUG-003 fix is conditional: Branch B-rule (rule UPDATE only) is the most likely outcome; Branch A/C/D escalate to follow-up bugfix | architect | 2026-04-29 | Per regression-discipline feedback: do not bundle speculative code changes with confirmed code changes |
| V3R-D7 | BUG-005 documented in V3R architecture section; orchestrator owns BUG-005 report file creation | architect | 2026-04-29 | Per CLAUDE.md, orchestrator (not architect) creates BUG-NNN report files |
| V3R-D8 | C-10 atomic-rez coexistence window flagged for game-tester awareness in V3R-8; no fix needed | architect | 2026-04-29 | Single-threaded zone tick eliminates real race; verification-only scenario |
| V3R-D9 | Optional rule `Companions:AoEExcludesCompanions` (config-expert G-7 proposal) NOT added | architect | 2026-04-29 | Per minimum-surface principle, hardcoded is preferred over operator-tuning toggle |
| V3R-D10 | Fix V Option A's `if (!is_dead)` guards include B.3 / B.4 / B.7 / B.8 / B.9 / B.10 / B.11; B.1 heartbeat + B.2 despawn timer stay UNCONDITIONAL | architect | 2026-04-29 | Per c-expert enumeration; preserves Fix R4's intent (no AI dispatch for dead) while restoring heartbeat + despawn timer |
| V3R-D11 | Empirical-measurement protocol uses in-game `!status` observation, NOT SQL polling | architect (data-expert D-11 correction) | 2026-04-29 | `companion_data.cur_mana` is only written at lifecycle Save() events, not on regen ticks; SQL polling returns stale values |

## V3 Re-Triage Bug Reports (UPDATED)

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| BUG-002 | NPC companions vanish from screen during combat if stationary (visibility heartbeat regressed) | High | user | **Investigating** — V3R architecture complete; fix in V3R implementation queue (Fix V Option A) | c-expert (V3R.2) | |
| BUG-003 | Companion HP/mana regen drastically slowed (~1%/report when sitting); possibly regen tick or gsay reporting cadence | High | user | **Investigating** — V3R architecture identified rule-tuning divergence (G-10) as leading hypothesis; empirical V3R-Empirical-1 4-test protocol will route outcome at V3R.7 | game-tester (V3R.6) → architect (V3R.7) | |
| BUG-004 | Player harmful AoE spells (mez, stun) affect own NPC companions; AoE friend/foe filter regressed | High | user | **Investigating** — V3R architecture identified pre-existing gap (NOT a V2 regression); fix in V3R implementation queue (Fix W α two-site) | c-expert (V3R.3) | |
| BUG-005 (NEW) | 30-minute auto-dismiss timer broken for dead companions (`Companions:DeathDespawnS` not enforced post-V2 Fix R4) | Medium | architect (V3R Round 1 enumeration) | **Investigating** — V3R architecture identified same root cause as BUG-002; fix in V3R implementation queue (Fix V Option A — same fix as BUG-002, zero additional surface) | c-expert (V3R.2) | |

## V3 Re-Triage Open Questions (UPDATED)

| # | Question | Owner | Status | Notes |
|---|---|---|---|---|
| V3R-Q1 | `Companions:CompanionManaRegenMult` history audit (was it ever higher than 100?) | c-expert | Pending git audit | Documentation-only; not load-bearing for fix |
| V3R-Q2 | HP regen parallel question: does companion HP regen have a similar tuning gap to mana regen? | config-expert | Pending follow-up 2 | May extend V3R rule fix to a parallel HP regen bump |
| V3R-Q3 | data-expert SQL column name verification (`owner_id` vs `owner_char_id`) for V3R-Empirical-1 setup query | data-expert | Pending | Affects validation plan SQL snippet correctness |
| V3R-Q4 | `NPC:OOCRegen` vs `Companions:OOCRegenPct` code-path interaction | (validation-time discrimination via V3R-6) | Empirical | If V3R-6 reveals companions on wrong path, escalate to c-expert |
| V3R-Q5 | protocol-agent formal structured enumeration (B/F sections) | protocol-agent | Pending | Pre-findings P-1/P-2/P-3 cover substantive needs; formal enumeration would add depth without changing conclusions |



## V3 Re-Triage Workflow Status (USER-APPROVED REVISION 2026-04-29)

User has reviewed and given a revised approval. BUG-003 (both mana and HP) is fully descoped from V3R and moved to a future separate "companion regen mechanics deep dive" bugfix.

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| V3 Re-Triage Architecture | architect (lead) + 5 advisors | Complete (USER-APPROVED with revisions) | 2026-04-29 | 2026-04-29 |
| V3 Re-Triage Implementation | c-expert + infra-expert + game-tester | Complete 2026-04-29 | 2026-04-29 | 2026-04-29 |
| V3 Re-Triage Fix-Iteration | c-expert + architect (audit) | Complete 2026-05-03 | 2026-04-30 | 2026-05-03 |
| V3 Re-Triage Validation | game-tester + user | Complete 2026-05-03 | 2026-04-29 | 2026-05-03 |
| V3 Re-Triage Completion | _user_ | Pending merge decision | | |

**V3 Re-Triage current phase:** Validation — server-side PASS; in-game test plan ready; awaiting user confirmation.

## V3 Re-Triage Implementation Tasks (REVISED — supersedes prior table)

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| V3R.1 | Write 3 failing-first tests in Suite 37 of `cli_companion_tests.cpp`: V.1 (heartbeat-for-dead), V.2 (despawn-timer-for-dead), W.1 (aoe-excludes-owner-companion). Build the test binary; verify V.1+V.2 FAIL pre-fix. | c-expert | **Complete** 2026-04-29 | TDD red commit 1c03ce9ea. Tests added to Suite 37 (Suite 36 was already taken). W.1 is structural prerequisite (client-vs-companion behavioral test requires in-game validation). Added IsPingTimerEnabled/TriggerPingTimer/IsDeathDespawnTimerEnabled/TriggerDeathDespawnTimer test hooks to companion.h. |
| V3R.2 | Implement Fix V Option A: restructure `Companion::Process()` top-section. `bool is_dead = (GetHP() <= 0);` capture + `if (!is_dead)` guards on AI-dispatch sections (B.3, B.4, B.7, B.8, B.9, B.10, B.11). Keep B.1 heartbeat AND B.2 `m_death_despawn_timer.Check()` UNCONDITIONAL. Reference c-expert formal enumeration B.1–B.11 for exact line guard mapping. ~25 lines C++. | c-expert | **Complete** 2026-04-29 | Implemented in companion.cpp. Fix R4 blanket early-return replaced with is_dead capture. Two `if (!is_dead)` blocks wrap AI-dispatch sections. Heartbeat + despawn timer UNCONDITIONAL. |
| V3R.3 | Implement Fix W α: single-site IsCompanion-aware AoE exclusion in `Mob::IsAttackAllowed` `_CLIENT vs _NPC` matrix at `aggro.cpp:867`. Reference c-expert C-12 code sketch. ~10-15 lines C++. | c-expert | **Complete** 2026-04-29 | Implemented in aggro.cpp:868-884. Added companion.h include. Handles owner's companion + group member's companion. Commit 035d33348. |
| V3R.4 | Rebuild zone binary. Re-run Suite 37 — verify V.1, V.2, W.1 PASS, all V1/V2 tests unchanged. Run full companion test suite. | c-expert | **Complete** 2026-04-29 | All Suite 37 tests pass. Full suite passes (Suite 36 group-ID exhaustion is pre-existing flaky, unrelated to V3R changes). Zero new compiler warnings. |
| V3R.4b (fix-iteration) | BUG-002 fix-iteration: alive-passive companion heartbeat gap. Pre-existing gap in original heartbeat fix (9e4b7dfd1) — heartbeat was always placed after passive early-return. Add V.3 TDD red test; hoist heartbeat block above all early-returns in companion.cpp with INVARIANT comment. | c-expert | **Complete** 2026-04-29 | V.3 red commit 081c6e5c8; green commit 84ac6a204. All 4 Suite 37 tests pass (V.1, V.2, W.1, V.3). Full suite green. Pushed to origin. |
| V3R.5 | `make restart` from akk-stack/, then full server stack startup (loginserver / world / 8 dynamic zones per documented procedure). | infra-expert | **Complete** 2026-04-29 | loginserver PID 383, world PID 478, 8 dynamic zones PIDs 613-642. No startup errors confirmed by infra-expert. |
| V3R.6 | In-game validation per V3R Validation Plan (post-revision): 7 sustained-play scenarios (V3R-1 heartbeat PRIMARY, V3R-2 auto-dismiss 30-min PRIMARY, V3R-3 AoE PRIMARY, V3R-5 sustained combat 5+min, V3R-7 multi-zone, V3R-8 multi-rez, V3R-9 sustained AoE). User confirms BUG-002 + BUG-005 + BUG-004 closed. | game-tester | **In Progress** 2026-04-29 | Server-side pre-checks PASS. In-game test plan at `game-tester/test-plan.md` V3R section. Awaiting user in-game confirmation. |
| V3R.7 | Commit and push V3R changes on `bugfix/companion-rez` in eqemu and claude repos. | c-expert | **Complete** 2026-04-29 | eqemu commits pushed: 1c03ce9ea (TDD red) + 035d33348 (Fix V + Fix W green). claude repo status.md update commit pending. |

**Spawn list:** c-expert (V3R.1, V3R.2, V3R.3, V3R.4, V3R.7), infra-expert (V3R.5), game-tester (V3R.6). **architect does NOT need to rejoin** (no BUG-003 decision step). **data-expert is NOT re-spawned** (no conditional rule UPDATE — empirical protocol descoped). **Do NOT spawn lua-expert / config-expert / protocol-agent.**

## V3 Re-Triage Bug Reports (REVISED)

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| BUG-002 | NPC companions vanish from screen during combat if stationary (visibility heartbeat regressed) | High | user | **RESOLVED 2026-05-03** — V3R fix-iteration confirmed in-game by user ("that works great!"). Fix: heartbeat block hoisted to top of `Companion::Process()` (commit 84ac6a204) so it runs unconditionally for all alive code paths regardless of stance. V.3 TDD test (commit 081c6e5c8) covers alive-passive heartbeat permanently. Belt-and-suspenders: architect independent audit verified c-expert's diagnosis; c-expert iterated with TDD-first discipline per `feedback_refactor_regression_discipline.md`. | c-expert | 2026-05-03 |
| BUG-003 | Companion HP/mana regen drastically slowed (~1%/report when sitting); user uncertain whether actual regen tick or gsay reporting cadence | High | user | **DESCOPED FROM V3R** — moved to future companion-regen-mechanics bugfix per user decision 2026-04-29. Both mana AND HP sides will be handled together in the deep-dive bugfix. | TBD (future regen-mechanics bugfix) | |
| BUG-004 | Player harmful AoE spells (mez, stun) affect own NPC companions; AoE friend/foe filter regressed | High | user | **RESOLVED 2026-05-03** — user confirmed in-game ("It all looks good!"). Fix W α single-site at `aggro.cpp:867` (commit 035d33348) — narrow `IsCompanion`-aware exclusion in `Mob::IsAttackAllowed` covering owner's companions and group-member companions. | c-expert | 2026-05-03 |
| BUG-005 (NEW) | 30-minute auto-dismiss timer broken for dead companions (`Companions:DeathDespawnS` not enforced post-V2 Fix R4) | Medium | architect (V3R Round 1 enumeration) | **RESOLVED 2026-05-03** — user confirmed in-game ("It all looks good!"). Fix bundled with V3R Fix V Option A (commit 035d33348) + heartbeat hoist (commit 84ac6a204) — despawn timer now runs unconditionally for dead companions. | c-expert | 2026-05-03 |

## V3 Re-Triage Decision Log (REVISED — additions)

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| V3R-D1 through V3R-D11 | (preserved from prior section) | architect | 2026-04-29 | (see prior entries) |
| V3R-D12 | (preserved from prior section: HP regen parity α-HP fix added conditional) | architect | 2026-04-29 | DEFERRED — moved to future regen-mechanics bugfix per V3R-D14 |
| V3R-D13 | (preserved from prior section: A.3 SendArmorAppearance flagged then reversed) | architect | 2026-04-29 | (preserved as historical record) |
| **V3R-D14 (NEW)** | **BUG-003 (both mana and HP) fully descoped from V3R; moved to future companion-regen-mechanics bugfix** | user | 2026-04-29 | User wants regen handled holistically in a dedicated workspace, not bundled with the locked-down BUG-002/004/005 fixes. Honors regression-discipline principle of not bundling speculative work with confirmed work. |
| **V3R-D15 (NEW)** | **`Companions:AoEExcludesCompanions` rule REJECTED; hardcoded behavior locked** | user | 2026-04-29 | Architect-recommended per minimum-surface principle. AoE exclusion of owner's own companion should always be the correct default; no operator-tuning toggle needed. |

## V3 Re-Triage Known-Pending Follow-ups (post-user-revision)

| # | Item | Symptom | Workaround | Future Action |
|---|------|---------|-----------|---------------|
| V3R-FU-1 | **Companion Regen Mechanics Deep Dive (BUG-003 mana + HP together)** | User reported "Mana and health regen seem to be screwed up again. ~1% per report when sitting." Multiple advisor reads converge on regen code path being unchanged by V2; G-14 corrected the G-10 hypothesis (companions DO get Character:ManaRegenMultiplier); G-16 surfaced a real HP regen structural gap predating V2 (Companion::CalcHPRegen does not apply Character:HPRegenMultiplier; Bots/Mercs/Clients all do). | None during V3R; user accepts current regen behavior pending the deep-dive. | A separate bugfix workspace (suggested branch: `bugfix/companion-regen-mechanics`) goes through the full pipeline starting at design phase to settle: (a) empirical measurement of mana + HP regen vs expected formulas, (b) code-path verification (custom CalcManaRegen / CalcHPRegen vs base NPC fall-through), (c) HP regen multiplier asymmetry decision (align with Bot/Merc/Client pattern via one-line C++ OR maintain asymmetry intentionally), (d) buff-state interaction across Death/rez cycles, (e) misperception vs regression resolution. Architecture context preserved in V3R section (Refinements II findings G-14/G-16) and architect/context/ working artifacts. |

