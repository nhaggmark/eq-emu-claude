# Companion Re-recruitment Fix — Status Tracker

> **Feature branch:** `bugfix/companion-rerecruit`
> **Created:** 2026-04-27
> **Last updated:** 2026-04-28 (v2 architecture phase opened)

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-04-27 | 2026-04-27 |
| Design | game-designer + lore-master | Complete | 2026-04-27 | 2026-04-27 |
| Architecture (v1) | architect + protocol-agent + config-expert | Complete | 2026-04-27 | 2026-04-27 |
| Implementation (v1) | infra-expert + lua-expert + data-expert | Complete | 2026-04-27 | 2026-04-28 |
| Validation (v1) | game-tester | Complete (v1 fix verified working in-game; surfaced multi-variant bug) | 2026-04-28 | 2026-04-28 |
| Architecture (v2) | architect + lua-expert + c-expert + data-expert | Complete (pending user review) | 2026-04-28 | 2026-04-28 |
| Implementation (v2) | lua-expert + c-expert + infra-expert | Complete (V2-1 through V2-6) | 2026-04-27 | 2026-04-28 |
| Validation (v2) | game-tester | In Progress (server-side PASS; awaiting user in-game confirmation) | 2026-04-28 | |
| Completion | _user_ | Not Started | | |

**Current phase:** Validation v2 in progress — server-side PASS (50 checks); user in-game testing pending

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### game-tester → user (v2 in-game testing required)
- **Date:** 2026-04-28
- **Notes:** Server-side validation PASS (50/50 checks). 61 Lua TDD tests green (53 main + 8 edge case). 569 C++ test cases green (35 suites, Suite 35 new). All v1 + v2 code changes confirmed live in running server. Ghost row id=21 still absent. No stale cooldowns. No duplicate companion rows. Lydl (id=10, is_suspended=1, level=53, 14 gear, stored npc_type_id=10162) is ready for all three freporte variant tests and cross-zone test V3.
  - **Test plan updated:** `game-tester/test-plan.md` now contains 6 v2-specific scenarios (V1-V6) plus the original 10 v1 scenarios. Primary validation target: Test V1 (canonical multi-variant Lydl re-recruit) and Test V6 (no duplicate row after multi-variant re-recruit).
  - **Deployment:** Full server restart complete (V2-6). No in-game reload required before testing.
  - **No blockers found.** All server-side checks passed.

### architect (v2) → user (review gate)
- **Date:** 2026-04-28
- **Notes:** v2 architecture appended to `architect/architecture.md` ("V2: Multi-Variant NPC Lookup Fix" section). Three-advisor consultations (lua-expert, c-expert, data-expert) all converged on Option D / B (same SQL): widen Track 1 lookup from `npc_type_id` match to `companion_data.name` match, keyed off `npc:GetCleanName()`. **C++ rebuild required this time** — Lua-only fix is provably insufficient because C++ `Companion::CreateFromNPC` runs an independent strict-ID query that creates a duplicate row and orphans the original.
  - **Scope:** ~30 lines Lua + ~25 lines C++ + 4 new TDD tests + standard build cycle. Zero schema changes, zero rule changes, zero migrations.
  - **One open user decision:** Decision V2-8 — cross-zone same-name semantics (treat freporte Lydl 186 and northro Lydl 392011 faction-0 as the same character or as distinct?). v2 default = same character (player-friendly). Confirm before implementation.
  - **7 v2 implementation tasks** populated in the Implementation Tasks table; assigned experts: lua-expert (V2-1, V2-2), c-expert (V2-3, V2-4, V2-5), infra-expert (V2-6), game-tester (V2-7).
  - **Advisor reports preserved** in `agent-conversations.md` under "Implementation Team Conversations (v2 — companion-rerecruit-architecture-v2 team)".
  - **Decision Log** entries 11-19 added covering all v2 decisions.

### game-tester → completion (pending user in-game confirmation)
- **Date:** 2026-04-28
- **Notes:** Server-side validation PASS (21/21 checks). 58/58 TDD tests green.
  Ghost row id=21 deleted. All 4 code changes confirmed live. No Lua errors in logs.
  Deployment: user must run `#reload quest global` in-game before testing.
  Test plan at `game-tester/test-plan.md` — 10 scenario tests + 2 edge cases.
  Lydl (companion_data id=10, is_suspended=1, level 53, 14 gear items) is ready
  to re-recruit immediately after reload. No blockers.

### implementation team → game-tester (Task 8 handoff)
- **Date:** 2026-04-27
- **Notes:** All 7 implementation tasks complete. Commits:
  - akk-stack 7101248: make test-companion target (infra-expert)
  - akk-stack 76e6753: 5 failing TDD tests (lua-expert, pre-fix)
  - akk-stack ad79630: Dismiss(true)→false + doc comment + LevelRange + ORDER BY (lua-expert)
  - claude 5decc45: ghost row id=21 deleted (data-expert)
  - claude f55ffbf: lua-expert dev-notes
  Test results: 50/50 main + 8/8 edge case = 58/58 PASS.

### architect → implementation team (infra-expert + lua-expert + data-expert + game-tester)
- **Date:** 2026-04-27
- **Notes:** Architecture finalized at `architect/architecture.md`. Full triage of all four advisor consultations resolved a major architectural pivot:
  - **Root cause discovered:** `companion.lua:1434` — `cmd_dismiss` calls `npc:Dismiss(true)` which maps to `Companion::Dismiss(permanent=true)` → `SoulWipe()` → DELETEs the companion_data row. The Lua doc comment at line 15 has the parameter semantics inverted. Every voluntary `!dismiss` destroys the re-recruit hint.
  - **Three named blockers reframed as one root cause + two cascading symptoms.** Death path is correct (writes is_suspended=1). Cooldown is already bypassed by Track 1. Dismissed-flag query is already correct in current code.
  - **Fix surface area:** 1-character Lua fix at companion.lua:1434, doc comment correction at line 15, LevelRange fallback hardening at line 207, 5 new TDD tests, 1 SQL DELETE of ghost row id=21, 1 Makefile target. **Zero C++ changes. Zero schema changes. Zero rule_values changes.**
  - **8 implementation tasks** in linear dependency order (infra → tests → fix → verify → cleanup → validate). See architecture.md "Implementation Sequence" section.
  - **All 4 PRD open questions resolved** in architecture.md "Resolved PRD Open Questions" section.
  - **Advisor team contributions logged** in `agent-conversations.md` Architecture Team Conversations section. config-expert (rule audit, no changes needed), data-expert (schema verification, ghost-row dedup), c-expert (C++ trace, test infrastructure), lua-expert (smoking-gun root cause, live SQL reproduction, disagreement resolution).
  - **Spawn ONLY** these implementation agents: infra-expert (Task 1), lua-expert (Tasks 2-6), data-expert (Task 7), game-tester (Task 8). Do NOT spawn c-expert, config-expert, perl-expert, or protocol-agent — they have no assigned tasks.

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-04-27
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Bug report BUG-001 seeded at `bugs/BUG-001-rerecruit-level-cap/report.md`.
  Spawn both agents as teammates for the Design phase.

### design team (game-designer + lore-master) → architect
- **Date:** 2026-04-27
- **Notes:** PRD finalized at `game-designer/prd.md` (status: APPROVED).
  Locks the re-recruitment invariant: any previously-recruited NPC is
  re-recruitable indefinitely, with level and gear preserved, no level
  rules, no cooldown, no dismissed-flag persistence. All three known
  blockers (level cap, cooldown, dismissed flag) in scope as a single
  coordinated fix.
  - **TDD as design constraint:** engineers write failing tests first;
    test suite ships in repo as machine-verified evidence.
  - **10 acceptance criteria** + **10 validation scenarios**, split
    between engineer-side (1,2,5,8,9,10) and game-tester in-game
    (3,4,6,7).
  - **Lore-master sign-off:** APPROVED 2026-04-27. No lore blockers.
    Two flavor-level edge cases folded into PRD: static-respawn
    fiction note (Era Compliance), quest-NPC interaction (Open
    Question #1 and new AC-10 covering Lydl Mastat-style cases).
    "Cyrla the Healer" renamed to "Mira the Healer" in Scenario B to
    avoid collision with real EQ NPC Cyrla Shadowstepper.
  - **Open questions for architect:** first-recruit cooldown semantics
    (preserve or remove?); in-memory cache flushing on bypass vs.
    delete; "other drop-out conditions" enumeration (zone disconnect,
    server restart, group disband); quest-state interaction on
    re-recruit of quest-target NPCs.
  - **Reference docs:** `eqemu/zone/lua_companion.cpp`,
    `akk-stack/server/quests/global/global_npc.lua`,
    `akk-stack/server/quests/lua_modules/client_ext.lua`,
    MEMORY entries `project_companion_rerecruit_pain` and
    `reference_companion_cooldown_clearing` (both 44 days old —
    architect to verify against current code).
  - **Lore-master transcription note:** lore-master lacked Write
    tooling this session; their findings transcribed verbatim into
    `lore-master/lore-notes.md` and SendMessage exchanges preserved
    in `agent-conversations.md` as the canonical audit trail.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Add `make test-companion` target to akk-stack Makefile (luajit via Docker exec) | infra-expert | Complete 2026-04-27 | Unblocks Task 2 |
| 2 | Write 5 new failing TDD tests in `test_companion_recruitment.lua` per architecture.md test list | lua-expert | Complete 2026-04-27 | akk-stack commit 76e6753 — 5 tests red pre-fix |
| 3 | One-character fix at `companion.lua:1434` (`Dismiss(true)` → `Dismiss(false)`) | lua-expert | Complete 2026-04-27 | akk-stack commit ad79630 |
| 4 | Doc comment correction at `companion.lua:15` (parameter semantics) | lua-expert | Complete 2026-04-27 | akk-stack commit ad79630 |
| 5 | Lua hardening: LevelRange fallback at `companion.lua:207` (`or 3` → `or 50`) AND `ORDER BY level DESC, experience DESC, id DESC` at `companion.lua:394-397` | lua-expert | Complete 2026-04-27 | akk-stack commit ad79630 |
| 6 | Run `make test-companion`; verify 5 new tests pass + 38 existing tests still pass | lua-expert | Complete 2026-04-27 | 58 total tests pass (50+8); all 5 TDD tests green |
| 7 | Targeted DELETE of ghost row `companion_data.id=21` (SELECT-confirm-DELETE) | data-expert | Complete 2026-04-27 | Depends on Task 6 |
| 8 | In-game scenario validation (AC-3, AC-4, AC-6, AC-7, AC-10 + regressions) | game-tester | In Progress 2026-04-28 | Server-side PASS; test-plan.md written; awaiting user in-game runs |

### v2 Implementation Tasks (multi-variant lookup fix)

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| V2-1 | Extend Lua test harness `make_db_stub` for param-aware dispatch + write 3 failing TDD tests: (a) name-match finds row when ID differs, (b) regression name-mismatch falls through to Track 2, (c) Q7 mitigation — Track 1 blocked when target NPC is in `companion_exclusions` | lua-expert | Complete 2026-04-27 | akk-stack commit eb88551 — all 3 tests red pre-fix |
| V2-2 | Apply Lua fix in `companion.lua` — (a) rename `check_existing_companion_record` param to `clean_name`, swap SQL predicate to `name = ?` + `name != ''` guard, change caller at line 463 to pass `npc:GetCleanName()`, update doc comment; (b) add Q7 mitigation: new exclusion check in `is_re_recruitment_eligible()` calling shared `_lookup_exclusion(npc:GetNPCTypeID())` helper (refactor from `is_eligible_npc()` if not shared); (c) add diagnostic log when name-match resolves to a different `npc_type_id` than the targeted spawn; run `make test-companion`; verify 3 new tests pass + 58 v1 tests pass | lua-expert | Complete 2026-04-27 | akk-stack commit 6358c48 — 61 total tests pass (53+8) |
| V2-3 | Add Suite 35 (`TestCompanionReRecruitmentVariantNameMatch`) in `cli_companion_tests.cpp` — TWO test cases: (a) name-match finds row when ID differs, (b) name-mismatch returns empty. Q7 exclusion test is Lua-only (V2-1 owns it). | c-expert | Not Started | Tests must fail BEFORE V2-4 per AC-9 |
| V2-4 | Apply C++ fix at `companion.cpp:218-220`: SQL predicate `name = '{}'` with `Strings::Escape`-protected binding of `source_npc->GetCleanName()` + `name != ''` guard + ORDER BY tie-breaker + diagnostic `LogInfo` when name-match resolves to a different `npc_type_id` than the targeted spawn; update comment block; rebuild zone via ninja. **No C++ exclusion check** (Q7 is Lua-only for v2; tracked as future-work item 11). | c-expert | Not Started | Depends on V2-3 |
| V2-5 | Run `./bin/zone tests:companion`; verify Suite 35 passes + Suite 20 (regression for re-recruit HP) passes + all 34 prior suites pass | c-expert | Not Started | Depends on V2-4 |
| V2-6 | Server restart (containers + EQ processes per MEMORY: shared_memory, loginserver, world, 8 zone dynamics) so the new C++ binary and reloaded Lua go live | infra-expert | Not Started | Depends on V2-2 AND V2-5 (both layers must land in lockstep) |
| V2-7 | In-game validation — 6 v2 scenarios + 10 v1 regression scenarios (comprehensive) | game-tester | In Progress (server-side PASS; user in-game testing pending) | Depends on V2-6 |


---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | First-recruit cooldown semantics | game-designer | architect | **Resolved** | Preserve. RecruitCooldownS=900 continues to apply to Track 2 only. Bypass is at dispatch level (Track 1 short-circuit), not at rule-value level. See architecture.md "Resolved PRD Open Questions" Q1. |
| 2 | In-memory cache flushing | game-designer | architect | **Resolved** | Bypass is at the validation layer (Track 1 dispatch). Cache is irrelevant. lua-expert confirmed zero stale cooldown rows in data_buckets currently. See architecture.md Q2. |
| 3 | Other drop-out conditions enumeration | game-designer | architect | **Resolved** | Death works correctly. Voluntary dismiss fixed by this change. Permanent dismiss N/A (no Lua path invokes it). Zone-disconnect and group-disband flagged as future work — not currently failing per bug report. See architecture.md Q3. |
| 4 | Quest-state interaction on re-recruit of quest-target NPCs | lore-master | architect | **Resolved** | No special handling. Invariant overrides quest gating per AC-10. Killing a re-recruited quest-target still fires EVENT_DEATH on the underlying NPC. See architecture.md Q4. |
| 5 | (v2) Cross-zone same-name semantics — treat freporte Lydl (faction 186) and northro Lydl 392011 (faction 0) as the same character (current plan) or as distinct NPCs requiring disambiguation? | architect | user | **Open — needs user input before V2 implementation** | Default: same character (player-friendly per PRD invariant). Alternative: add `npc_faction_id` predicate to Track 1 to keep cross-faction variants distinct. See architecture.md V2 Decision V2-8. |

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
| BUG-001 | Re-recruitment blocked by level cap (and possibly cooldowns + dismissed flag) | High | user | Resolved (v1 fix; verified in-game 2026-04-28) | architect → lua-expert + data-expert | 2026-04-28 |
| BUG-002 | Re-recruitment fails for multi-variant NPCs (e.g. Lydl_the_Great in freporte) when zone spawns a different `npc_type_id` variant than originally recruited | High | game-tester / user (in-game v1 validation) | Investigating → Fix Planned (v2 architecture complete) | architect → lua-expert + c-expert | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Fix all three known blockers (level caps, cooldown timers, dismissed flag) as one coordinated change | user | 2026-04-27 | The re-recruitment invariant must hold completely; partial fixes leave the system broken |
| 2 | TDD approach: engineers write tests first proving the invariant, then implement to make tests pass | user | 2026-04-27 | Ensures invariant is machine-verified, not just manually tested |
| 3 | Lore review APPROVED — no blockers; two flavor edge cases (static-respawn fiction, quest-NPC interaction) folded into PRD as architect-awareness notes, not scope changes | game-designer + lore-master | 2026-04-27 | Companion system is a custom feature with no in-world fiction; invariant is purely mechanical |
| 4 | Rename "Cyrla the Healer" → "Mira the Healer" in Scenario B | game-designer + lore-master | 2026-04-27 | Cyrla collides with real EQ NPC Cyrla Shadowstepper (level 61 Rogue, Highpass Hold). Generic invented name avoids noise for downstream readers |
| 5 | Added AC-10: re-recruit of an NPC who is also a quest kill target (e.g., Lydl Mastat) still succeeds per the invariant; architect evaluates whether quest state needs special handling | game-designer + lore-master | 2026-04-27 | Lore-master flagged Lydl Mastat quest as an example of the broader edge case; invariant must hold regardless |
| 6 | Root cause of dismiss blocker is `companion.lua:1434` invoking `Dismiss(true)` (permanent SoulWipe) instead of `Dismiss(false)` (voluntary preserve). Three PRD blockers reframed as one root cause + two cascading symptoms. | architect (after lua-expert smoking-gun) | 2026-04-27 | lua-expert traced companion.cpp:2553 if(permanent) SoulWipe branch; c-expert independently confirmed the else branch sets flags + Save(). Both readings reconciled — they describe different branches of the same conditional. |
| 7 | Architecture is Lua-only with one-time DB cleanup. Zero C++ changes, zero schema changes, zero rule_values changes. | architect | 2026-04-27 | Triage confirmed C++ side already does the right thing on re-recruit (CreateFromNPC re-detects, clears flags, restores). Death path correctly persists is_suspended=1. The bug is Lua command invoking the wrong overload. |
| 8 | TDD tests added BEFORE the fix per PRD AC-9 — must fail today, pass after. | architect | 2026-04-27 | PRD design constraint. The test suite is the deliverable that survives in the repo as machine-verified evidence. |
| 9 | LevelRange fallback hardened from `or 3` to `or 50` at companion.lua:207 | architect | 2026-04-27 | Defense against future rule_values reset. Matches DB intent. |
| 10 | Targeted DELETE of ghost row companion_data.id=21 (Hollish Tnoops level=14, 0 inventory). No broad UPDATE sweep needed — zero rows currently stuck. | architect (after data-expert) | 2026-04-27 | data-expert verified live state: zero is_dismissed=1 rows, zero cur_hp=0 rows. Only single targeted DELETE warranted. |
| 11 | (v2) v1 fix is correct but incomplete; v2 widens re-recruit lookup to handle multi-variant `npc_type_id` patterns (e.g. Lydl_the_Great with 3 freporte variants in spawngroup_140) | architect | 2026-04-28 | In-game testing surfaced 60% spawn-mismatch rate for Lydl. Multi-variant pattern is pervasive (3,038 proper-named NPCs world-wide have >1 npc_type_id) — generic fix preferred over data-specific dedup. |
| 12 | (v2) Selected approach D/B: widen Track 1 from strict `npc_type_id` match to `companion_data.name` match keyed off `npc:GetCleanName()` | architect (after lua-expert + c-expert convergence) | 2026-04-28 | lua-expert and c-expert independently arrived at identical SQL shape. Avoids unindexed `npc_types.name` table scan (66K rows). Avoids digit-stripping mismatch between `npc_types.name` and `CleanMobName`. Single query per layer; backward compatible bit-for-bit for single-variant NPCs. |
| 13 | (v2) C++ rebuild required — both Lua AND C++ must change in lockstep | architect (after lua-expert proof) | 2026-04-28 | C++ `CreateFromNPC` at companion.cpp:218 runs an INDEPENDENT strict-ID query. Lua-only fix would be silently undone: Track 1 finds row → calls `client:CreateCompanion(npc)` → C++ falls through to fresh-recruit INSERT → duplicate row, original orphaned. v1 boundary "zero C++ changes" cannot hold for v2. |
| 14 | (v2) Reject Option A (JOIN on `npc_types.name`) | architect | 2026-04-28 | `npc_types.name` is unindexed TEXT, 67K rows; JOIN per recruit attempt = table scan. `REPLACE(name, '_', ' ')` doesn't strip digits while `CleanMobName` does — JOIN would miss for names with digit suffixes. |
| 15 | (v2) Reject Option C (data dedup of Lydl variants) | architect | 2026-04-28 | Doesn't fix systemic 3,038-name pattern. Touches PEQ content. Fragile against PEQ updates. Doesn't help if first-recruit picked a non-canonical variant. |
| 16 | (v2) `Strings::Escape` (or repository's canonical helper) on the bound NPC name in C++ SQL | architect | 2026-04-28 | Defense against pathological NPC display names with SQL metacharacters. Cheap and standard. |
| 17 | (v2) ORDER BY `level DESC, experience DESC, id DESC LIMIT 1` added to C++ query in lockstep with Lua's existing one | architect | 2026-04-28 | Closes v1 future-work item 1a (C++ deterministic selection) as part of v2 since we're touching the C++ query anyway. |
| 18 | (v2) Defer `UNIQUE (owner_id, name)` constraint and `npc_faction_id` disambiguation | architect | 2026-04-28 | Premature without evidence of need. Adding constraints requires UPSERT redesign and dedup pass first. v1 already tracks UNIQUE (owner_id, npc_type_id) — same fate. |
| 19 | (v2) Cross-zone same-name semantics: treat as same character by default; surface to user for explicit confirmation | architect | 2026-04-28 | freporte Lydl 186 vs northro Lydl 0 share name only. PRD invariant prioritizes player perception; same-name = same character is the player-friendly read. User can override before implementation. |
| 20 | (v2-Q7) Add target-NPC exclusion check to Track 1 short-circuit in BOTH layers (Lua `is_re_recruitment_eligible` and C++ `CreateFromNPC` re-recruit hit path) | architect (after data-expert Q7) | 2026-04-28 | data-expert Q7 found 789 auto-excluded NPCs with non-excluded same-name siblings. Without mitigation, v2 name-match enables an exclusion bypass (e.g. recruit non-excluded Renux_Herkanor 12032, then "re-recruit" excluded guildmaster 2033 by name-association). Current production exposure is zero, but mitigation is preventative. |
| 21 | (v2-Q7) `exclusion_type=0` lore-anchor list confirmed unique-named — zero bypass risk by construction | data-expert + architect | 2026-04-28 | Sir Lucan, Lord Bayle, etc. all have unique names. Defense-in-depth from the same target-NPC check covers any future lore additions. |
| 22 | (v2-Q7) No `companion_exclusions` table change needed | architect | 2026-04-28 | Mitigation is code-side; table remains keyed on `npc_type_id`. data-expert confirmed lore-anchor list is unique-named so no name-keyed exclusion table needed. |
| 23 | (v2-correction) Q7 mitigation narrowed to Lua-only for v2 | architect (after c-expert pushback + call-graph verification) | 2026-04-28 | `Companion::CreateFromNPC` has exactly one production caller (`lua_client.cpp:3647` from Lua `client:CreateCompanion`). Lua-side Track 1 gate is binding for all current code. C++ exclusion check would be defense-in-depth for hypothetical future callers; tracked as Out-of-Scope item 11. |
| 24 | (v2-correction) Reject `REPLACE(npc_types.name, '_', ' ')` SQL subquery; bind `GetCleanName()` from the call site | architect | 2026-04-28 | `CleanMobName` strips digits AND converts `_` to space; `REPLACE(_, ' ')` only handles underscores. Names with digits (e.g. runtime `MakeNameUnique` suffixes `_001`/`_002`) produce different output. lua-expert verified at byte level via `HEX(name)` (Refinement R8). |
| 25 | (v2-correction) Adopt data-expert's two defensive SQL guards: `AND name != ''` and diagnostic log on `npc_type_id` divergence | architect (after data-expert recommendation, c-expert confirmation) | 2026-04-28 | Empty-name guard closes a malformed-NPC corner case. Diagnostic log surfaces stale-name cases (admin renamed `npc_types` after recruit) for ops visibility without changing behavior. |

---

## Completion Checklist

### Implementation Complete (agents can check these)

_Filled in after game-tester validation passes._

- [x] All implementation tasks marked Complete (v1: 1-8; v2: V2-1 through V2-6)
- [x] No open Blockers
- [x] game-tester server-side validation: PASS (50/50 checks, 2026-04-28)
- [ ] User completed in-game testing guide: PENDING (12 scenarios: Tests 1-10, E1, E2 v1; Tests V1-V6 v2)
- [x] All changes committed and pushed to feature branch in ALL repos (confirmed via git log)
- [x] Server rebuilt (C++ changed in v2 — zone binary Apr 28 11:06, post-fix)
- [ ] All phases marked Complete in Workflow Status table (pending user in-game confirmation)

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
