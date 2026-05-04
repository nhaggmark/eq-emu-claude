# Companion Snare AI: Combat Restriction — Status Tracker

> **Feature branch:** `feature/companion-snare-ai`
> **Created:** 2026-05-03
> **Last updated:** 2026-05-04

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-05-03 | 2026-05-03 |
| Design | game-designer + lore-master | Complete | 2026-05-03 | 2026-05-03 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-05-03 | 2026-05-04 |
| Implementation | c-expert + config-expert + data-expert | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-05-03
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Feature brief at `brief.md`. Spawn both agents as teammates for the Design phase.

### architect → implementation team (Phase 4)
- **Date:** 2026-05-04
- **Architecture doc:** `architect/architecture.md`
- **Open questions:** All 8 resolved (see Open Questions table — all marked Resolved).
- **Implementation team composition:**
  - **c-expert** (tasks 3-11) — owns all C++ in `eqemu/zone/`
  - **config-expert** (tasks 1, 12) — owns RULE_INT macros and rule_values seed
  - **data-expert** (task 2) — owns companion_spell_sets audit
- **Sequencing:** Tasks 1 and 2 in parallel. Task 3 after task 1. Tasks 4-10 sequential after task 3 (single-file serialization). Task 11 (rebuild) gates task 12 (rule_values seed via `#reloadrules`).
- **Critical do-not-skip detail:** classify snare-line spells ONLY by `SpellType_Snare` bitmask in `companion_spell_sets.spell_type`. Do NOT name-match. Necromancer Clinging Darkness / Dooming Darkness do not contain "snare" in their names.
- **Sustained-play test scenarios required** in the validation plan per architect discipline on customized systems (see `feedback_refactor_regression_discipline.md`). Specifically: long engagements (5+ min), chain pulls (10+ targets), companion death+rez during the same fight, companion zone-in mid-engagement, and verification that all four named classes (DRU/RNG/NEC/SHM) actually cast snare in the right conditions.
- **No commits expected to eqemu/, akk-stack/, or spire/ during architecture** — architecture phase produced documentation only in `claude/`.

### design team → architect (Phase 3)
- **Date:** 2026-05-03
- **PRD:** `project-work/feature-companion-snare-ai/game-designer/prd.md`
- **Lore sign-off:** APPROVED by lore-master 2026-05-03 — no narrative implications,
  no era issues, no class-identity concerns, silent-suppression approach concurred.
  Full exchange logged in `agent-conversations.md`.
- **Scope summary:** Restrict autonomous companion snare-line casting in
  active combat to targets that are simultaneously ≤ 20% HP AND fleeing.
  Per-(companion, target) resist counter caps autonomous attempts at 2
  resists per engagement. Out-of-combat unaffected. Manual `/command`
  overrides bypass the rule. Two new tunable rules recommended:
  `Companions:SnareHpThreshold` (default 20) and
  `Companions:SnareResistLimit` (default 2). Affected classes: Druid,
  Ranger, Necromancer, Shaman.
- **Open questions surfaced for the architect:** documented in the PRD
  Open Questions section — companion command override mechanism, AI tick
  insertion point, snare-line spell classification, flee-state
  observability, resist-event hookup, per-target counter storage,
  engagement boundary definition, rule-values naming convention.
- **No edits expected to eqemu/, akk-stack/, or spire/ during design** —
  design phase produced documentation only in `claude/`.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Add 2 RULE_INT entries to `common/ruletypes.h` (`Companions:SnareHpThreshold` default 20, `Companions:SnareResistLimit` default 2). | config-expert | Not Started | Required before C++ build. |
| 2 | Audit `companion_spell_sets` for DRU/RNG/NEC/SHM snare-line entries with `spell_type = 128`. Add missing rows by spell ID. | data-expert | Not Started | Parallel with task 1. |
| 3 | Implement `Companion::AI_AttemptSnare`, `OnSpellResisted`, `ClearSnareResistCounters`. Add `m_snare_resist_counts`, `m_last_snare_target_id` members. | c-expert | Not Started | Depends on task 1. |
| 4 | Replace AI_Ranger snare branch with `AI_AttemptSnare` call. Preserve 30% throttle. | c-expert | Not Started | Depends on task 3. |
| 5 | Replace AI_Bard snare branch with `AI_AttemptSnare` call. Preserve 20% throttle. | c-expert | Not Started | Depends on task 3. |
| 6 | Add SpellType_Snare branch to AI_Druid (50% throttle). | c-expert | Not Started | Depends on task 3. |
| 7 | Add SpellType_Snare branch to AI_Necromancer (50% throttle). | c-expert | Not Started | Depends on task 3. |
| 8 | Add SpellType_Snare branch to AI_Shaman (50% throttle). | c-expert | Not Started | Depends on task 3. |
| 9 | Hook `m_was_engaged` transition site in `Companion::Process` to call `ClearSnareResistCounters()`. | c-expert | Not Started | Depends on task 3. |
| 10 | Hook `Mob::SpellOnTarget` full-resist branch in `spells.cpp:4554` to call `OnSpellResisted` when `IsCompanion()`. | c-expert | Not Started | Depends on task 3. |
| 11 | Build (`ninja -j$(nproc)`), restart container + zone processes, smoke test. | c-expert | Not Started | Gates task 12. |
| 12 | Insert 2 default rule_values rows for the new rules. Run `#reloadrules` to activate. | config-expert | Not Started | Depends on task 11 (rebuild required for `_FindRule()` to match). |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Does the existing companion command pathway already bypass autonomous AI cast-selection gates? If yes, manual override is "free." If no, scope a bypass. | game-designer | architect | Resolved | No `!snare` or `!cast` command exists in the companion command system today. The PRD's "manual override" requirement is moot in current scope. AC-8 is N/A. Deferred to a follow-up feature if/when a manual snare command is added. |
| 2 | Where in the companion AI decision tick is the cleanest place to insert the snare gate without affecting other casts in the same pass? | game-designer | architect | Resolved | A new shared helper `Companion::AI_AttemptSnare(Mob*)` in `companion_ai.cpp` is the single insertion point. Each class handler that wants snare calls it. Centralizes the rule. |
| 3 | What is the cleanest classification path to identify "snare-line" spells (effect ID list, spell-skill, spell-category) without picking up roots? | game-designer | architect | Resolved | `SpellType_Snare` bitmask (`(1 << 7) = 128`) tagged in `companion_spell_sets.spell_type`. NO name pattern matching. Necromancer Clinging/Dooming Darkness names verified by lore-master and would silently bypass any name filter. |
| 4 | Where does the companion AI tick already access target flee state? Cheapest read path? | game-designer | architect | Resolved | `Mob::IsFleeing()` (`mob.h:1251`). O(1) member read of `flee_mode`. Cleanly distinguishes low-HP flee (PRD intent) from spell-fear. |
| 5 | What signal does the companion AI receive on cast resist (callback, return value, polled flag)? | game-designer | architect (with protocol-agent) | Resolved | Hook `Mob::SpellOnTarget` at the existing full-resist branch (`spells.cpp:4508-4555`). protocol-agent recommended `Companion::CastedSpellFinished` as alternative; architect chose `SpellOnTarget` for surgical precision. Fallback documented. |
| 6 | Where should the per-(companion, target) resist counter live? Companion entity, AI struct, or transient map keyed by target ID? | game-designer | architect | Resolved | `std::unordered_map<uint16, uint8>` private member on Companion, keyed by target entity ID. Runtime-only. Cleared on engagement-end and target change. |
| 7 | What constitutes "the same engagement" for resetting the resist counter — aggro-list membership or current-target change? | game-designer | architect | Resolved | Piggyback the existing `m_was_engaged && !currently_engaged` transition in `Companion::Process` (`companion.cpp:1992-2000`). Target-change detected via `m_last_snare_target_id` comparison at top of `AI_AttemptSnare`. Counters wipe on either edge. |
| 8 | Does the project already use a `Companions:*` namespace for companion-specific rule_values? If yes, conform; if no, follow the closest existing convention. | game-designer | architect / config-expert | Resolved | `Companions:*` exists and is heavily used (44+ rules in `ruletypes.h:1182-1255`, 47 live DB rows). Conform with `Companions:SnareHpThreshold` (default 20) and `Companions:SnareResistLimit` (default 2). |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| _(none)_ | | | |

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
| 1 | HP threshold default = 20%, resist limit default = 2 | game-designer (per brief) | 2026-05-03 | Locked in during user brainstorming; carried into PRD as the default values for the recommended tunable rules. |
| 2 | Both conditions (≤ HP threshold AND fleeing) must be true for autonomous snare; either alone is insufficient | game-designer (per brief) | 2026-05-03 | Locked in during user brainstorming. The intent is "allow snare only when it actually matters." |
| 3 | Resist counter is per (companion, target); resets on new target and new engagement | game-designer (per brief) | 2026-05-03 | Locked in during user brainstorming. Multi-mob fights and chain-pulls don't get penalized for prior bad luck on a different target. |
| 4 | No flavor text/emote on AI-suppressed snare cast — silent suppression | game-designer + lore-master | 2026-05-03 | Replacing snare-cast spam with emote spam would defeat the purpose. Lore-master concurred there's no narrative reason to announce. |
| 5 | Manual player commands bypass the AI rule | game-designer (per brief) | 2026-05-03 | Player agency must be preserved. Architect to confirm the current command path already routes around AI gating. |
| 6 | Out-of-combat snare unaffected — companions may snare freely during pulls/positioning | game-designer (per brief) | 2026-05-03 | The complaint is about combat spam, not pulls. Out-of-combat snare has clear utility (kiting, controlled pulls). |
| 7 | Root-line spells explicitly OUT of scope | game-designer (per brief) | 2026-05-03 | Different spell category, different player intent. Root is used for deliberate CC; snare is the spam offender. |
| 8 | Snare classification = `SpellType_Snare` bitmask in `companion_spell_sets.spell_type`. NO name pattern matching. | architect | 2026-05-04 | Necromancer Clinging Darkness / Dooming Darkness names don't contain "snare" — name-match would silently miss Necromancer companions. Lore-master verified per-class spell names 2026-05-03. |
| 9 | Resist hook site = `Mob::SpellOnTarget` full-resist branch (`spells.cpp:4508-4555`), guarded by `IsCompanion()`. | architect (in dialogue with protocol-agent) | 2026-05-04 | Single source of truth for "fully resisted on this target." protocol-agent's alternative `CastedSpellFinished()` documented as fallback if scope issues arise. |
| 10 | Manual `/command` snare override = N/A in current scope. No `!snare` or `!cast` command exists today. AC-8 marked N/A. | architect | 2026-05-04 | Verified against `claude/docs/companion-commands-reference.md`. PRD's "override bypass" is forward-looking; if a future feature adds `!snare`, the override is small additional plumbing. |
| 11 | `Companions:SnareResistLimit = 0` means "no cap, attempt every eligible tick." | architect (confirming config-expert flagged ambiguity) | 2026-05-04 | Encoded as `if (resist_limit > 0)` in the gate. Matches PRD intent. |
| 12 | Scope expansion — Druid/Necromancer/Shaman class AI handlers do not currently route `SpellType_Snare`. Adding branches is part of this feature, not optional. Bard's existing snare branch is also gated for consistency. | architect | 2026-05-04 | The PRD names DRU/RNG/NEC/SHM but only RNG and BRD have snare branches in the code today. Without adding the missing branches, the feature would only apply to RNG. Bard included for uniform application of the rule. |

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

- Design phase produced documentation only in `claude/`. No edits to
  `eqemu/`, `akk-stack/`, or `spire/`. Architecture phase will do
  technical assessment and generate the implementation plan; that may
  surface code/data changes that the implementation team executes
  in Phase 4.
