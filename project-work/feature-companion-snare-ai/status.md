# Companion Snare AI: Combat Restriction — Status Tracker

> **Feature branch:** `feature/companion-snare-ai`
> **Created:** 2026-05-03
> **Last updated:** 2026-05-03

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-05-03 | 2026-05-03 |
| Design | game-designer + lore-master | Complete | 2026-05-03 | 2026-05-03 |
| Architecture | architect + protocol-agent + config-expert | Not Started | | |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Architecture

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-05-03
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Feature brief at `brief.md`. Spawn both agents as teammates for the Design phase.

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
| | | | | |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| 1 | Does the existing companion command pathway already bypass autonomous AI cast-selection gates? If yes, manual override is "free." If no, scope a bypass. | game-designer | architect | Open | |
| 2 | Where in the companion AI decision tick is the cleanest place to insert the snare gate without affecting other casts in the same pass? | game-designer | architect | Open | |
| 3 | What is the cleanest classification path to identify "snare-line" spells (effect ID list, spell-skill, spell-category) without picking up roots? | game-designer | architect | Open | |
| 4 | Where does the companion AI tick already access target flee state? Cheapest read path? | game-designer | architect | Open | |
| 5 | What signal does the companion AI receive on cast resist (callback, return value, polled flag)? | game-designer | architect | Open | |
| 6 | Where should the per-(companion, target) resist counter live? Companion entity, AI struct, or transient map keyed by target ID? | game-designer | architect | Open | |
| 7 | What constitutes "the same engagement" for resetting the resist counter — aggro-list membership or current-target change? | game-designer | architect | Open | |
| 8 | Does the project already use a `Companions:*` namespace for companion-specific rule_values? If yes, conform; if no, follow the closest existing convention. | game-designer | architect / config-expert | Open | |

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
