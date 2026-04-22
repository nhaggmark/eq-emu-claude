# Raid Scaling — Status Tracker

> **Feature branch:** `feature/raid-scaling`
> **Created:** 2026-04-21
> **Last updated:** 2026-04-22

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-04-21 | 2026-04-21 |
| Design | game-designer + lore-master | Complete 2026-04-21. Classic epics canonically authored by lore-master 2026-04-22; Kunark/Velious/Luclin quest-chain re-review still pending for Phase 4 prep | 2026-04-21 | 2026-04-21 |
| Architecture | architect + protocol-agent + config-expert | Not Started | | |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** User answered Q1-Q10 on 2026-04-22. Q11 and Q12 (surfaced during lore-master polish) still pending user review. Architecture phase queued for Phase 2 (Classic raids) planning once Q11/Q12 answered.

---

## Phase Notes

### IMPORTANT: Phase 1 is an AUDIT phase

The game-designer's first deliverable is **not code changes** — it is a
comprehensive scaling-status document cataloging every raid boss and raid-tier
quest chain across Classic through Luclin, with its current scaling state:

- Scaled by prior pass
- Partially scaled
- Untouched
- Special-case (requires unique handling)

**Prior work reference:** Overland/group content has an existing scaling pass.
The audit MUST cross-reference it to identify gaps where raid content was missed
or only partially addressed.

**USER DECISION GATE after Phase 1:** After the audit document is delivered and
approved, the user must be consulted before proceeding to Phase 2 (Classic raids).
The user will decide whether to continue as one sustained effort or split the era
phases (Classic, Kunark, Velious, Luclin) into separate projects.

### Phased delivery plan

| Phase | Scope | Status |
|-------|-------|--------|
| Phase 1 — Audit | All raid bosses + raid quest chains catalogued with scaling status | **Complete 2026-04-21** |
| Phase 2 — Classic | Fear, Hate, Sky, Nagafen, Vox, dragons + Classic epic steps | Not Started |
| Phase 3 — Kunark | Trakanon, Veeshan's Peak + Kunark epic steps | Not Started |
| Phase 4 — Velious | NToV, ToV, Kael, Sleeper's Tomb, AoW, Velious dragons | Not Started |
| Phase 5 — Luclin | Ssraeshza, Vex Thal, Luclin raid content | Not Started |

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-04-21
- **Notes:** Workspace created. Feature brief at `feature-brief.md`. PRD template
  ready at `game-designer/prd.md`. Phase 1 deliverable is an audit document, not
  code. Spawn both agents as teammates for the Design phase.

### design team → user / architect (Phase 1 audit complete)
- **Date:** 2026-04-21
- **Deliverables:**
  - `game-designer/raid-scaling-audit.md` (2,400+ lines, ~127KB)
    — full per-era boss catalog + quest-chain summary + headline
    findings + 8 user decisions + quest-chain dependency graph
  - `game-designer/prd.md` — audit-driven design intent with 4
    mechanical levers (HP cut, damage cut, respawn, narrow ability
    trims) and appendix of architect technical notes
- **Key findings:**
  - Prior small-group-scaling pass (2026-02-23) explicitly excluded
    `raid_target = 1` from stat cuts — all ~140 true-boss encounters
    sit at PEQ defaults
  - True-boss count: ~30 Classic / 19 Kunark / 60-65 Velious / ~30
    Luclin (filtered from raw 878 raid_target NPCs)
  - HP gap ranges from 2× (Classic dragons) to 63× (Aten Ha Ra);
    damage one-shot outliers (Kilidna 4,600 max) require priority
    trimming
  - Prior pass DID touch loot and respawn for raid targets — respawn
    still at 54-130h vs. brief's 6-24h
- **User decisions requested before Phase 2:** 8 questions A-H
  (phased delivery strategy, VP variant, Hate layout, VT Yaemiu
  trash scope, respawn targets, Sleeper event, Cazic Thule era
  alignment, signature-mechanic preservation)
- **Lore-master participation note:** lore-master marked Tasks #7-10
  completed but did not produce detailed content. Game-designer
  wrote summary-level quest-chain sections from public-domain EQ
  knowledge to keep Phase 1 deliverable usable. Lore-master
  re-engagement recommended before Phase 4 implementation touches
  scripted event content (Ring War, VT internals, Sleeper event).
- **Ready for:** user decision gate → architect Phase 3 (triage
  + implementation plan for Phase 2 Classic raids, based on user's
  phased-delivery choice)

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
| 1 | After Phase 1 audit: continue as one project or split into per-era projects? | bootstrap-agent | user | **Resolved 2026-04-22** | Per-era with sub-splits — 6 phases: 2 Classic, 3 Kunark, 4a non-ToV Velious, 4b ToV+Sleeper+Vulak, 5a non-VT Luclin, 5b VT+shards |
| 2 | Veeshan's Peak: keep revamp variants (108040-108053 at 454-814k HP) or switch to classic-era variants (108509-108517 at 144-192k HP)? | game-designer | user | **Resolved 2026-04-22** | Keep revamp variants, scale down deeply |
| 3 | Plane of Hate: classic layout (hateplane) or revamp (hateplaneb)? | game-designer | user | **Resolved 2026-04-22** | Use whichever is currently live (architect to verify in-game/DB) |
| 4 | Vex Thal Yaemiu elite trash (~80 mobs at 55-100k HP): include in scaling scope or leave? | game-designer | user | **Resolved 2026-04-22** | Include in scaling scope |
| 5 | Respawn targets by tier (endgame/mid/low) — specific values? | game-designer | user | **Resolved 2026-04-22** | 24h endgame (ToV, VT, Sleeper's) / 12h mid (PoSky, Trak, VP, most Velious) / 6h low (Classic dragons, PoF, PoH) |
| 6 | Cazic Thule: leave at L70 with HP cut, or drop to L65 for Classic-era alignment? | game-designer | user | **Resolved 2026-04-22** | Leave at L70, cut HP for small-group |
| 7 | Vex Thal 13-shard key quest: reduce shard count for small-group server? | game-designer | user | **Resolved 2026-04-22** | Keep all 13 shards — full progression experience |
| 8 | Coldain Ring War + Prayer Shawl event scripts: accept small-group scripted events or simplify wave counts? | game-designer | architect | Pending — requires script review in Phase 3 | TBD (architect decides) |
| 9 | Signature mechanic preservation vs. small-group tractability (Vyemm MR wall, Aaryonar breath, Emperor add waves, etc.) | game-designer | user | **Resolved 2026-04-22** | Preserve all signature mechanics; scale HP/damage to compensate |
| 10 | Sleeper-awake event (Kerafyrm L99 3.5M HP): leave untouched (recommended) or change? | game-designer | user | **Resolved 2026-04-22** | Leave untouched |
| 11 | Plane of Sky Islands 4-8 death-touch mechanics: convert to survivable damage, or accept as small-group walls? | lore-master | architect+user | Pending — lore-master's Classic epic catalog surfaced this; affects Necro, Ranger, Magician, Warrior epic progressions | TBD |
| 12 | Class-skill-gated epic steps (Rogue pickpocket, Enchanter charm, Druid/Ranger Firefly Globe): allow 1-player servers to bypass class-gate, or accept "not every epic is doable on 1 character"? | lore-master | user | Pending | TBD |
| 13 | Enraged Golem (Plane of Fear, Wizard epic) lvl 65 150k HP — NOT in raid_target=1 spawnentry queries. Confirm ID and add to boss catalog scaling pass | lore-master | architect | Pending — 10 similar NPCs to investigate: Xenevorash, triggered Trakanon, Renux Herkanor, General V'ghera, Thrackin Griften, Vessel Drozlin, Caradon+Kyrenna, Mummy of Glohnor, Tortured Soul | TBD |

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
| 1 | Deliver as phased project; Phase 1 is audit-only | user | 2026-04-21 | Scope too large for single pipeline run; audit first to understand gap before committing to full implementation |
| 2 | Trash/named mobs untouched; only raid bosses scaled | user | 2026-04-21 | Current named difficulty feels good; only raid tier needs adjustment |
| 3 | Loot tables unchanged; respawn timers reduced to 6-24h range | user | 2026-04-21 | Keep loot piñata feel; reduce lockout friction for small group |
| 4 | Delivery strategy: per-era with sub-splits (6 phases: 2 Classic, 3 Kunark, 4a non-ToV, 4b ToV+Sleeper+Vulak, 5a non-VT, 5b VT+shards) | user | 2026-04-22 | ToV and VT are each large enough to warrant own sub-phase; keeps blast radius manageable |
| 5 | VP: keep revamp variants, scale deeply | user | 2026-04-22 | Quest scripts already target revamp IDs; switching would break scripts |
| 6 | PoH: use whichever layout is live on server | user | 2026-04-22 | Avoid unnecessary zone switch; architect verifies current state |
| 7 | Yaemiu trash (VT): included in scaling scope | user | 2026-04-22 | Raid-tier content should follow raid-scaling; applies principle consistently |
| 8 | Respawn tiers: 24h endgame / 12h mid / 6h low | user | 2026-04-22 | Brief's 6-24h range realized; endgame still feels event-like, low tier farmable |
| 9 | Cazic Thule: L70 with HP cut | user | 2026-04-22 | Accept current Luclin-era revamp level; no cross-era drift |
| 10 | VT key: keep all 13 shards | user | 2026-04-22 | Preserve full progression experience even at high friction for small group |
| 11 | Signature mechanics: preserve all, scale HP/damage to compensate | user | 2026-04-22 | Fights must keep their identity; difficulty comes from mechanics, not just numbers |
| 12 | Sleeper-awake event (Kerafyrm): leave untouched | user | 2026-04-22 | World event preserving server lore; unbeatable-by-design is part of identity |

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
