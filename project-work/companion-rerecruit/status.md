# Companion Re-recruitment Fix — Status Tracker

> **Feature branch:** `bugfix/companion-rerecruit`
> **Created:** 2026-04-27
> **Last updated:** 2026-04-27

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-04-27 | 2026-04-27 |
| Design | game-designer + lore-master | Complete | 2026-04-27 | 2026-04-27 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-04-27 | 2026-04-27 |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation (architecture handoff complete)

---

## Handoff Log

_Record each handoff between agents with context and any notes._

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
| 2 | Write 5 new failing TDD tests in `test_companion_recruitment.lua` per architecture.md test list | lua-expert | Not Started | Depends on Task 1 |
| 3 | One-character fix at `companion.lua:1434` (`Dismiss(true)` → `Dismiss(false)`) | lua-expert | Not Started | Depends on Task 2 |
| 4 | Doc comment correction at `companion.lua:15` (parameter semantics) | lua-expert | Not Started | Depends on Task 3 |
| 5 | Lua hardening: LevelRange fallback at `companion.lua:207` (`or 3` → `or 50`) AND `ORDER BY level DESC, experience DESC, id DESC` at `companion.lua:394-397` | lua-expert | Not Started | Depends on Task 3 |
| 6 | Run `make test-companion`; verify 5 new tests pass + 38 existing tests still pass | lua-expert | Not Started | Depends on Tasks 3, 4, 5 |
| 7 | Targeted DELETE of ghost row `companion_data.id=21` (SELECT-confirm-DELETE) | data-expert | Complete 2026-04-27 | Depends on Task 6 |
| 8 | In-game scenario validation (AC-3, AC-4, AC-6, AC-7, AC-10 + regressions) | game-tester | Not Started | Depends on Task 7 |

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
| 3 | Lore review APPROVED — no blockers; two flavor edge cases (static-respawn fiction, quest-NPC interaction) folded into PRD as architect-awareness notes, not scope changes | game-designer + lore-master | 2026-04-27 | Companion system is a custom feature with no in-world fiction; invariant is purely mechanical |
| 4 | Rename "Cyrla the Healer" → "Mira the Healer" in Scenario B | game-designer + lore-master | 2026-04-27 | Cyrla collides with real EQ NPC Cyrla Shadowstepper (level 61 Rogue, Highpass Hold). Generic invented name avoids noise for downstream readers |
| 5 | Added AC-10: re-recruit of an NPC who is also a quest kill target (e.g., Lydl Mastat) still succeeds per the invariant; architect evaluates whether quest state needs special handling | game-designer + lore-master | 2026-04-27 | Lore-master flagged Lydl Mastat quest as an example of the broader edge case; invariant must hold regardless |
| 6 | Root cause of dismiss blocker is `companion.lua:1434` invoking `Dismiss(true)` (permanent SoulWipe) instead of `Dismiss(false)` (voluntary preserve). Three PRD blockers reframed as one root cause + two cascading symptoms. | architect (after lua-expert smoking-gun) | 2026-04-27 | lua-expert traced companion.cpp:2553 if(permanent) SoulWipe branch; c-expert independently confirmed the else branch sets flags + Save(). Both readings reconciled — they describe different branches of the same conditional. |
| 7 | Architecture is Lua-only with one-time DB cleanup. Zero C++ changes, zero schema changes, zero rule_values changes. | architect | 2026-04-27 | Triage confirmed C++ side already does the right thing on re-recruit (CreateFromNPC re-detects, clears flags, restores). Death path correctly persists is_suspended=1. The bug is Lua command invoking the wrong overload. |
| 8 | TDD tests added BEFORE the fix per PRD AC-9 — must fail today, pass after. | architect | 2026-04-27 | PRD design constraint. The test suite is the deliverable that survives in the repo as machine-verified evidence. |
| 9 | LevelRange fallback hardened from `or 3` to `or 50` at companion.lua:207 | architect | 2026-04-27 | Defense against future rule_values reset. Matches DB intent. |
| 10 | Targeted DELETE of ghost row companion_data.id=21 (Hollish Tnoops level=14, 0 inventory). No broad UPDATE sweep needed — zero rows currently stuck. | architect (after data-expert) | 2026-04-27 | data-expert verified live state: zero is_dismissed=1 rows, zero cur_hp=0 rows. Only single targeted DELETE warranted. |

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
