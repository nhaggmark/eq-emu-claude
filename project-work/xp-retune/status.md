# XP Retune — Status Tracker

> **Feature branch:** `feature/xp-retune`
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

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-04-27
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Spawn both agents as teammates for the Design phase.

  **Feature brief seeded from brainstorming:**
  Reduce kill XP multiplier from 3.0x to 2.0x while keeping AA XP at 3.0x.
  The original server-wide 3x XP boost is leveling players too fast.
  Scope is a pure `rule_values` UPDATE — no rebuild needed; `#reloadrules` applies it live.

  **Confirmed scope:**
  - `Character:ExpMultiplier`: 3.0 → 2.0
  - `Character:AAExpMultiplier`: stays 3.0
  - All other XP rules untouched (group, raid, hotzone, level_exp_mods, death loss, companion XP)

  **Config-expert audit findings (pre-confirmed):**
  - Active ruleset_id = 1 ("default")
  - Group/raid bonuses at EQEmu defaults
  - Death XP loss at 1.5%/death (already softened vs 3.5% default — keep)
  - Levels 66–70 braked via level_exp_mods (intentional era-lock pacing — keep)
  - HotZone bonus at default +0.75x (keep)
  - Companion XP rules custom but unrelated (keep)

### design team → architect
- **Date:** 2026-04-27
- **Notes:** PRD finalized at `game-designer/prd.md`. Lore-master sign-off
  recorded — APPROVED, no concerns, no constraints. PRD scope is a pure
  numerical rule tune: `Character:ExpMultiplier` 3.0 → 2.0,
  `Character:AAExpMultiplier` unchanged at 3.0. Single-row UPDATE on
  `peq.rule_values` (ruleset_id = 1), applied live via `#reloadrules`. No
  rebuild required. All other XP-related rules explicitly out of scope per
  Non-Goals section. Acceptance criteria, success metrics, and rollback
  criteria all spelled out in the PRD. No open questions remain.

  **For the architect:** triage which expert(s) are needed (likely
  data-expert only) and produce the implementation plan. The Appendix
  section of the PRD has the exact UPDATE shape from the config-expert
  pre-audit.

### architect → implementation team
- **Date:** 2026-04-27
- **Notes:** Architecture doc finalized at `architect/architecture.md`.
  Plan is a single-row UPDATE on `peq.rule_values`
  (`ruleset_id=1`, `rule_name='Character:ExpMultiplier'`,
  `rule_value '3.0' → '2.0'`), applied live via `#reloadrulesworld`.
  No code, no rebuild, no restart, no protocol changes.

  **Key correction from architect↔config-expert verification:**
  - Reload command is `#reloadrulesworld` (broadcast), NOT `#reloadrules`
    (which does not exist). The PRD's `#reloadrules` reference is shorthand;
    the implementation task uses the correct command.
  - Rule values use string format `'2.0'` / `'3.0'` to match the existing
    table format.

  **Implementation team to spawn:** ONLY `config-expert`. Do not spawn
  c-expert, lua-expert, perl-expert, data-expert, infra-expert, or
  protocol-agent — none have work.

  **Single task (Task 1):** config-expert runs pre-check SELECT, executes
  UPDATE, runs post-check SELECT, then `#reloadrulesworld` in-game,
  capturing before/after output for the PR. Hand off to game-tester with
  the captured SQL output and reload log lines.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Apply XP retune: pre-check SELECT → UPDATE `Character:ExpMultiplier` to `'2.0'` (ruleset_id=1) → post-check SELECT → `#reloadrulesworld` in-game; capture before/after output for PR | config-expert | Not Started | See `architect/architecture.md` Task 1 detailed brief |

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
| | | | | | | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Kill XP reduced 3.0x → 2.0x; AA XP stays 3.0x | user | 2026-04-27 | Kill XP was leveling players too fast; AA grind should stay accelerated |
| 2 | Pure rule_values UPDATE; no C++ rebuild | user | 2026-04-27 | No code change needed; #reloadrules applies live |
| 3 | PRD approved with no lore concerns | game-designer + lore-master | 2026-04-27 | Pure numerical tune, no content references, era compliance unaffected |
| 4 | Reload command is `#reloadrulesworld` (broadcast), not `#reloadrules` (does not exist); rule_value format `'2.0'`/`'3.0'` | architect + config-expert | 2026-04-27 | Verified against `command_settings`, `zone/gm_commands/rules.cpp`, and live `rule_values` rows |

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
