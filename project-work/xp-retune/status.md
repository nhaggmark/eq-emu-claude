# XP Retune — Status Tracker

> **Feature branch:** `feature/xp-retune`
> **Created:** 2026-04-27
> **Last updated:** 2026-04-27 (v2 architecture plan complete — pending user review)

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-04-27 | 2026-04-27 |
| Design v1 | game-designer + lore-master | Complete | 2026-04-27 | 2026-04-27 |
| Architecture v1 | architect + protocol-agent + config-expert | Complete (superseded by v2 scope expansion) | 2026-04-27 | 2026-04-27 |
| Design v2 (companion XP parity) | game-designer + lore-master (team `xp-retune-design-v2`) | Complete | 2026-04-27 | 2026-04-27 |
| Architecture v2 (re-triage) | architect + c-expert + config-expert (team `xp-retune-architecture-v2`) | Complete — pending user review | 2026-04-27 | 2026-04-27 |
| Implementation | _implementation team_ | In Progress | 2026-04-27 | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Architecture v2 — complete, pending user review of `architect/architecture.md` v2 plan before Implementation phase begins

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

### design team v2 → architect (re-triage for companion XP parity)
- **Date:** 2026-04-27
- **Team:** `xp-retune-design-v2` (game-designer + lore-master)
- **Notes:** PRD scope expanded. v1 covered only the rule_values rate change
  (`Character:ExpMultiplier` 3.0 → 2.0). v2 adds **Companion XP Parity** — a
  C++ refactor of the companion XP distribution path so a companion in a
  group earns the same per-share XP as the player on every flat-XP event
  (kill, `quest::exp()`, Lua `:AddEXP()`, flat task rewards), in all group
  sizes from 1+1 through 1+4. v2 also adds a forward-looking design
  constraint: the refactor must leave **AA-friendly seams** so a future
  companion-AA feature can attach without re-doing the parity work.
  Companion AA implementation is explicitly OUT of scope for this feature.

  Lore-master v2 sign-off: APPROVED. No lore concerns, no era-pacing
  concern, no narrative surface (companion system is wholly custom; no
  Classic-Luclin canon establishes a player/companion power-growth
  hierarchy). Logged in `agent-conversations.md` and `lore-master/lore-notes.md`.

  **Implementation Note (changed from v1):** This is no longer pure config.
  v2 requires a C++ refactor in `eqemu/zone/` (companion XP entry point
  `Companion::AddExperience` and the post-split divergence at
  `Group::SplitExp` / `exp.cpp:1180-1213`), plus removal or repurposing
  of the hardcoded max-100 cap on `Companions:XPSharePct` at
  `exp.cpp:1199`. Build + restart cycle required. The rule_values UPDATE
  from v1 still ships under this feature.

  **For the architect:** the v1 architecture doc covers ONLY the rate
  change. A v2 re-triage is needed to plan the companion XP parity
  refactor. Likely experts: c-expert (XP path refactor), config-expert
  (rule_values + any new rule introduced for parity scaling). The v1
  config-expert task (Task 1) is still valid for the rate piece but
  should be re-sequenced to ship together with the parity refactor on
  `feature/xp-retune`. See PRD Appendix for the file/line landmarks
  the team-lead has already gathered.

  **Open questions for architect:** how to break the max-100 cap
  cleanly (remove vs. repurpose `Companions:XPSharePct`); whether to
  introduce a new rule (e.g. `Companions:XPMultiplier` or similar) for
  the parity-scaling knob; where exactly to seam the AA accrual hook so
  a future feature can plug in without churn. The PRD does not
  prescribe — architect's call.

### architect → implementation team (v2)
- **Date:** 2026-04-27
- **Notes:** Architecture v2 plan finalized at `architect/architecture.md`.
  v1 plan preserved as appendix for revert reference. Architecture team
  consultations (architect ↔ c-expert, architect ↔ config-expert) logged
  in `agent-conversations.md` under "Architecture Team Conversations".

  **Approach:** Mirror Pipeline. New `Companion::CalculateExp` mirrors
  `Client::CalculateExp` minus AA/race-class/leadership concerns. Called
  from `Companion::AddExperience(uint32 xp, uint8 conlevel = 0xFF)` which
  also applies `Companions:XPSharePct` as a post-multiplier scalar (default
  100 = parity, clamp retained). `GetConLevelModifierPercent` extracted to
  `Mob` protected static. AA-extensibility seam: future feature adds
  `uint32& add_aaxp` out-parameter to `Companion::CalculateExp` exactly
  mirroring `Client::CalculateExp`.

  **All 4 review passes complete** — feasibility, simplicity, antagonistic,
  integration. Documented in architecture.md.

  **Implementation team to spawn (Phase 4):** c-expert, config-expert,
  infra-expert. game-tester comes solo in Phase 5. Do NOT spawn
  lua-expert, perl-expert, data-expert, or protocol-agent.

  **Five tasks (A–E)** in dependency order:
  - A: config-expert applies `Character:ExpMultiplier` 3.0→2.0 + reload
  - B: c-expert implements C++ refactor across 7 files
  - C: infra-expert rebuilds + restarts full server stack
  - D: config-expert applies `Companions:XPSharePct` 50→100 + reload
  - E: game-tester validates 15 PRD cases server-side

  **Critical sequencing constraint:** Task D MUST run after Task C
  (post-restart). Pre-restart, the new C++ is not live and Task D would
  apply the rule under old semantics.

  **The user will REVIEW this v2 architecture plan before any code is
  written.** Implementation phase does not begin until user approval.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| A | Apply XP rate UPDATE: pre-check SELECT → UPDATE `Character:ExpMultiplier` to `'2.0'` (ruleset_id=1) → post-check SELECT → `#reloadrulesworld` in-game; capture before/after output for PR | config-expert | Complete (2026-04-27) | Pre-check: `'3.0'`; UPDATE confirmed 1 row; Post-check: `'2.0'`. AAExpMultiplier guard: `'3.0'` unchanged. Reload needed in-game. Migration artifact at `config-expert/context/task-a-migration.sql`. |
| B | C++ refactor: mirror-pipeline approach across mob.h, mob.cpp/attack.cpp, companion.h, companion.cpp, exp.cpp:1196-1218, lua_companion.cpp; ruletypes.h `Companions:XPSharePct` default 50→100; AA-seam comment in `Companion::CalculateExp`. Build clean. | c-expert | Not Started | See `architect/architecture.md` Task B detailed brief. Depends on A only conventionally. |
| C | Restart server stack: rebuild eqemu, then loginserver → world → 8 dynamic zone processes (`dynamic_01` through `dynamic_08`) per `MEMORY.md` startup order. Verify all 8 zones connect cleanly. | infra-expert | Not Started | Depends on B (clean build). See `architect/architecture.md` Task C detailed brief. |
| D | Apply companion XPSharePct UPDATE: pre-check SELECT (expect `'50'`) → UPDATE to `'100'` → post-check SELECT → `#reloadrulesworld` in-game. Verify post-rebuild stack health before applying. | config-expert | Not Started | Depends on C. See `architect/architecture.md` Task D detailed brief. |
| E | Validate against PRD's 15 numbered cases — kill XP rate (1-2), companion parity (3-6), flat-XP grants (7-9), untouched paths (10-15). Server-side validation; hand to user for in-game confirmation. | game-tester | Not Started | Depends on D. See `architect/architecture.md` Validation Plan section. |

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
| 5 | `Character:ExpMultiplier` scope is broader than PRD framing — covers flat XP from `quest::exp()`, Lua `:AddEXP()`, and flat task rewards via `Client::AddEXP()`; only `AddLevelBasedExp` (percentage path) is unaffected | architect + config-expert | 2026-04-27 | Source trace; architecture.md updated with quest-XP and percentage-control validation checks |
| 6 | Scope expanded to include Companion XP Parity — companion must earn same per-share XP as player on every flat-XP event, in all group sizes 1+1 through 1+4 | user | 2026-04-27 | Companions are the signature feature for the 1–3 player server; current architectural ~50% gap is a feel and power-curve problem |
| 7 | Companion XP parity refactor must leave AA-friendly seams; companion AAs explicitly out of scope this feature | user | 2026-04-27 | Avoid re-doing the parity work when companion AAs are added later |
| 8 | PRD v2 (companion XP parity) approved with no lore concerns | game-designer + lore-master | 2026-04-27 | Companion system is wholly custom; no Classic-Luclin lore establishes companion advancement narrative; era compliance unaffected |
| 9 | Companion XP parity approach: **Mirror Pipeline** — new `Companion::CalculateExp` mirrors `Client::CalculateExp` minus AA/race-class/leadership; called from `Companion::AddExperience(uint32 xp, uint8 conlevel)` | architect (ratifying c-expert proposal) | 2026-04-27 | Cleanest separation; quest::exp / Lua paths automatically benefit because multiplier applies inside AddExperience; alternative routings (polymorphic Client, pre-compute in SplitExp) had specific failures |
| 10 | `Companions:XPSharePct` repurposed as **post-multiplier scalar** (default 100 = parity, clamp retained at 0-100); applied **inside `Companion::AddExperience`** after `CalculateExp` returns | architect (ratifying c-expert option B) | 2026-04-27 | Reuses existing rule with semantically-coherent meaning; config-expert verified rule is 100% custom (no stock-EQEmu compat concern); single application site ensures all entry points (group split, quest, Lua) receive scaling |
| 11 | `GetConLevelModifierPercent` exposed via `exp.h` (NOT extracted to Mob static); single source of truth preserved with minimal refactor | architect (revised after c-expert second-round trace) | 2026-04-27 | c-expert source read confirmed the function is already a file-scope `static` in `exp.cpp:218`, not a Client method as initially assumed. Promoting to Mob static would have required touching mob.h/mob.cpp and updating callers — heavier refactor for no semantic gain. exp.h exposure is a one-line declaration. |
| 12 | AA-extensibility seam is structural: future companion-AA feature adds `uint32& add_aaxp` out-parameter to `Companion::CalculateExp` and `Companion::AddAAExperience` method; no rule_values changes for AA in this feature; `Companions:` namespace reserved for future AA rules | architect (with config-expert) | 2026-04-27 | Mirrors Client::CalculateExp signature exactly; future feature can attach with two-line addition; PRD requires AA-friendliness without implementing AAs now |
| 13 | Deployment sequencing: rate UPDATE → rebuild → restart → XPSharePct UPDATE → validation. XPSharePct UPDATE goes AFTER restart so its effect is observable as the parity activation, not muddied with prior pre-multiplier behavior | architect (with config-expert) | 2026-04-27 | Task A is harmless before rebuild; Task D effective only with new C++ in place; this ordering makes validation cause-and-effect clean |
| 14 | Implementation team for v2: **c-expert + config-expert + infra-expert**; game-tester comes solo in Phase 5. Do NOT spawn lua-expert, perl-expert, data-expert, or protocol-agent — none have v2 work | architect | 2026-04-27 | Lua binding update is in C++; no schema changes; OP_ExpUpdate wire format unchanged (carries 0-330 ratio only) |
| 15 | TWO companion XP dispatch sites identified — `exp.cpp:1196-1218` (group split) AND `attack.cpp:2791-2810` (solo-kill path). Both must be patched in v2. | c-expert (source grep) | 2026-04-27 | XPSharePct has exactly two readers across the codebase. Initial architecture pass missed the attack.cpp site; c-expert second-round trace caught it. Both sites apply the same fix (raw XP + conlevel pass-through). |
| 16 | Process discipline: c-expert dev-notes pre-recorded architect "consensus" before architect had sent confirmations. Architect flagged this; c-expert corrected the audit trail. Going forward, only feedback actually received goes in dev-notes "Feedback Received" tables. | architect (process feedback) | 2026-04-27 | Audit trail integrity matters: if architect's call had differed from c-expert's proposal, dev-notes would have shown false consensus. Corrected via explicit "received date" annotations. |
| 17 | Option C-modified (split into XPSharePct=100 parity gate + new Companions:XPMultiplier=1.0 post-multiplier) considered and REJECTED on PRD scope grounds. Approach (B) retained. | architect (rejecting config-expert second-round rec) | 2026-04-27 | PRD non-goal at prd.md:61-63 explicitly out-of-scopes new companion XP rules not load-bearing for parity. XPMultiplier (default 1.0) is not load-bearing — parity works without it. Documented under "Considered and rejected alternatives" as a candidate for future feature work. config-expert's ergonomics argument was sound; rejection is on scope grounds, not technical merit. |
| 18 | Three config-expert second-round findings adopted into architecture doc without changing design call: (a) two-site clamp removal — both exp.cpp:1198-1199 and attack.cpp:2795-2796 dispatch-site clamps become dead code and must be removed; (b) ZEM/hotzone first-time coverage flag — companions get +0.75x hotzone for the first time after this refactor (correct per PRD case 2; flagged for game-tester explicit verification); (c) Companions:XPContribute gate must be preserved by the refactor. | architect + config-expert | 2026-04-27 | These improve precision of the design without scope expansion. Folded into architecture.md and c-expert Task B brief. |

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
