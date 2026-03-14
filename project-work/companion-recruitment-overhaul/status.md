# Companion Recruitment & Re-recruitment Overhaul — Status Tracker

> **Feature branch:** `feature/companion-recruitment-overhaul`
> **Created:** 2026-03-14
> **Last updated:** 2026-03-14

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-03-14 | 2026-03-14 |
| Design | game-designer + lore-master | Complete | 2026-03-14 | 2026-03-14 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-03-14 | 2026-03-14 |
| Implementation | lua-expert + c-expert | In Progress | 2026-03-14 | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-03-14
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

### design team → architect
- **Date:** 2026-03-14
- **Notes:** PRD complete and approved. Lore-master sign-off confirmed (no lore
  concerns). PRD at `game-designer/prd.md`. Scope summary:
  - Two-track recruitment system: first-time (full checks) vs re-recruitment
    (bypasses cooldown, level range, faction, persuasion roll)
  - Primary change in Lua (`companion.lua:attempt_recruitment()`)
  - C++ `CreateFromNPC()` already handles re-recruitment correctly
  - Mandatory Lua/C++ contract alignment gate before implementation
  - Comprehensive acceptance criteria covering 7 test categories

### architect → implementation team (lua-expert + c-expert)
- **Date:** 2026-03-14
- **Notes:** Architecture plan complete at `architect/architecture.md`. Summary:
  - **Task 1 → lua-expert**: Rewrite `attempt_recruitment()` with two-track detection.
    Add `check_existing_companion_record()` (checks `is_dismissed=1 OR is_suspended=1`),
    add `is_re_recruitment_eligible()` (5 minimal safety checks), restructure flow
    to detect existing record first and bypass all first-time checks. Clean up stale
    cooldown on re-recruitment success. ~100 lines changed in companion.lua.
  - **Task 2 → c-expert**: Add cooldown data_bucket cleanup and HP/mana restoration
    in `CreateFromNPC()` re-recruitment path. ~10 lines in companion.cpp. Found a bug:
    dead companions (cur_hp=0) would spawn with 0 HP without this fix.
  - **Task 3**: Integration verification (both experts, after tasks 1+2).
  - Lua/C++ interface contract defined: `client:CreateCompanion(npc)` is the single
    entry point for both tracks. No new C++ methods needed.
  - All three PRD open questions resolved.
  - No database schema changes. No new rules. No protocol changes.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Rewrite `attempt_recruitment()` with two-track detection | lua-expert | Complete | companion.lua + tests/test_companion_recruitment.lua |
| 2 | Add cooldown cleanup and HP restoration in `CreateFromNPC()` | c-expert | Complete | companion.cpp + cli_companion_tests.cpp Suite 19 |
| 3 | Integration verification: end-to-end testing | lua-expert + c-expert | Complete | All 4 contract points confirmed — sign-off granted 2026-03-14 |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Should is_suspended=1 with cur_hp > 0 (zoned-out alive companion) also bypass checks? | game-designer | architect | Resolved | Yes — companion was alive and traveling with the player. All is_suspended states treated identically. |
| 2 | Should re-recruitment work from any NPC of same npc_type_id? | game-designer | architect | Resolved | Yes — keep current behavior. Forcing exact spawn point is too punishing. |
| 3 | Edge case: two NPCs of same npc_type_id, one recruited then dies, recruit the other? | game-designer | architect | Resolved | Works correctly. LIMIT 1 in both Lua and C++ queries. Second NPC becomes vessel for restored companion. |

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
| | | | | | | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Two-track recruitment system (first-time vs re-recruitment) | game-designer | 2026-03-14 | Separates first-time checks from re-recruitment to solve blocking issues |
| 2 | Re-recruitment bypasses ALL first-time checks (cooldown, level, faction, roll) | game-designer | 2026-03-14 | Companion already has established relationship; natural friction (travel, lost buffs) is sufficient |
| 3 | "I remember you" narrative framing approved by lore-master | game-designer + lore-master | 2026-03-14 | Consistent with Classic-era NPC memory conventions |
| 4 | No cost or delay on re-recruitment | game-designer | 2026-03-14 | Small-group server; death is already punishment enough |
| 5 | No protocol changes needed — feature is entirely server-side | architect | 2026-03-14 | Titanium client sees identical packets for both tracks |
| 6 | No config-only solution — code path bypass required | architect | 2026-03-14 | Rules control thresholds, not code flow |
| 7 | HP/mana restoration needed in C++ for dead companions | architect | 2026-03-14 | Load() restores cur_hp=0; Spawn() doesn't call RestoreHealth() |
| 8 | Both Lua and C++ clean up stale cooldowns (belt-and-suspenders) | architect | 2026-03-14 | Defense in depth |
| 9 | All is_suspended states treated identically (regardless of cur_hp) | architect | 2026-03-14 | Simplest approach; matches C++ behavior |
| 10 | Any NPC of same npc_type_id can serve as re-recruitment vessel | architect | 2026-03-14 | Current behavior; forcing exact spawn point is too punishing |

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

Companion Recruitment & Re-recruitment Overhaul — Fix re-recruitment blocking issues (cooldowns, flags, level caps) so previously recruited companions can always be re-recruited. Enforce Lua/C++ contract alignment.
