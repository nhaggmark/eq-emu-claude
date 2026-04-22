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
| Architecture | architect + protocol-agent + config-expert | Complete (Phase 2 scope) | 2026-04-22 | 2026-04-22 |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Phase 2 (Classic) architecture complete. Architecture doc at `architect/architecture.md`. Implementation team dispatch next — only data-expert + config-expert + infra-expert (conditional) needed. Q13 resolved for Classic scope; Q8 deferred to Phase 4 per architecture plan.

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

### architect → implementation team (Phase 2 plan complete)
- **Date:** 2026-04-22
- **Deliverables:**
  - `architect/architecture.md` — full Phase 2 (Classic) architecture doc:
    executive summary, per-raid scope (PoFear, PoHate-revamp, PoSky, Nagafen,
    Vox, Classic dragons, Classic epic-adjacent NPCs), mechanical levers,
    10-task breakdown with dependencies, risk assessment, 4 review passes,
    validation plan for game-tester
  - `architect/context/q13-npc-investigation.md` — Q13 resolution: 13 Classic
    triggered-spawn NPCs added to scope (Ireblind Imp, Enraged Golem, Enraged
    Imp, Overseer of Air, Protector of Sky, Hand of Veeshan, essence tamer,
    Bazzt Zzzt, Keeper of Souls, Sister of the Spire, Innoruuk revamp,
    hateplaneb event adds, cazicthule Avatars)
  - `architect/context/classic-bosses-respawns.txt` — DB dump of current HP
    and respawn timers for all in-scope NPCs
- **Key decisions made during architecture:**
  - **Live Plane of Hate = `hateplaneb`** (revamp). Verified via DB
    (491 spawns vs hateplane's 213) and via `oasis/player.lua:4` which
    does `MovePCDynamicZone("hateplaneb")` — the actual Titanium entry path.
  - **Death-touch removal mechanism corrected**: not `special_abilities`
    ability 35 (which is an immunity flag); it is spell 982 "Cazic Touch"
    in `npc_spells_entries` for spell lists 118 (Spiroc Lord), 449 (Bazzt
    Zzzt), 969 (Keeper of Souls). Single DELETE statement handles it.
  - **100% SQL implementation.** No C++, no Lua, no Perl, no rules changes.
    Three tables touched: `npc_types` (~55 UPDATEs), `spawn2` (~40 UPDATEs),
    `npc_spells_entries` (3 DELETEs).
  - **essence tamer (71071) is NOT a true death-touch boss** — spell 303
    "Whirl till you hurl" is effect 64 (throw), not instant kill. Scaling HP
    still applies; no spell-list edit needed.
  - **Kithicor Night Crew (6 NPCs) included** in Phase 2 for consistency
    (20% HP cut per audit recommendation).
- **Required agents for implementation:** data-expert (primary),
  config-expert (reload + verification), infra-expert (conditional
  full-stack restart).
- **NOT needed:** c-expert, lua-expert, perl-expert, protocol-agent.
- **Ready for:** implementation team dispatch.

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
| 1 | Create backup tables for `npc_types`, `spawn2`, `npc_spells_entries` raid-target rows | data-expert | Not Started | Backs up ~750+1500+20 rows; architecture §Data Model |
| 2 | Emit per-boss HP/damage/special_abilities UPDATE SQL (30 audit bosses + 13 Q13 + 23 hateplaneb = ~55 rows) | data-expert | Not Started | Depends on #1; authoritative values in architecture §Data Model sketch and audit summary table |
| 3 | Emit respawn-timer UPDATE SQL (6h low-tier / 12h Cazic+Guardian of Seal) | data-expert | Not Started | Depends on #1; leave hateplaneb 900s DZ timers untouched |
| 4 | Emit `npc_spells_entries` DELETE for Cazic Touch (spell 982) from lists 118, 449, 969 | data-expert | Not Started | Depends on #1; exactly 3 rows deleted |
| 5 | Emit rollback script (INSERT SELECT from backup tables) + verification queries | data-expert | Not Started | Depends on #2-4 |
| 6 | Apply SQL via `docker exec ... mysql` ; capture before/after row counts | data-expert | Not Started | Depends on #5 |
| 7 | `#reloadworld` (via Spire or in-game GM command) to refresh zone caches | config-expert | Not Started | Depends on #6 |
| 8 | Smoke verify: Nagafen HP, CT rampage string, Keeper spell list, hateplaneb Innoruuk HP, respawn timer for Nagafen | config-expert | Not Started | Depends on #7 |
| 9 | Full-stack restart if `#reloadworld` doesn't propagate npc_spells_entries cache | infra-expert | Not Started | Conditional; depends on #8 result |
| 10 | Commit + push `claude/` repo changes (architecture, context, status, implementation SQL) to `feature/raid-scaling` branch | data-expert | Not Started | Depends on #6 success |

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
| 8 | Coldain Ring War + Prayer Shawl event scripts: accept small-group scripted events or simplify wave counts? | game-designer | architect | **Deferred to Phase 4 (Velious non-ToV)** 2026-04-22 | Velious content; out of Phase 2 Classic scope. Will be addressed in Phase 4 architecture pass. |
| 9 | Signature mechanic preservation vs. small-group tractability (Vyemm MR wall, Aaryonar breath, Emperor add waves, etc.) | game-designer | user | **Resolved 2026-04-22** | Preserve all signature mechanics; scale HP/damage to compensate |
| 10 | Sleeper-awake event (Kerafyrm L99 3.5M HP): leave untouched (recommended) or change? | game-designer | user | **Resolved 2026-04-22** | Leave untouched |
| 11 | Plane of Sky Islands 4-8 death-touch mechanics: convert to survivable damage, or accept as small-group walls? | lore-master | architect+user | **Resolved 2026-04-22** | Remove death-touch entirely on these mobs — the 4 affected epics (Necro, Ranger, Magician, Warrior) become doable |
| 12 | Class-skill-gated epic steps (Rogue pickpocket, Enchanter charm, Druid/Ranger Firefly Globe): allow 1-player servers to bypass class-gate, or accept "not every epic is doable on 1 character"? | lore-master | user | **Resolved 2026-04-22** | Keep class-gates — accept "not every epic is doable on any character; roll alts for other epics" |
| 13 | Enraged Golem (Plane of Fear, Wizard epic) lvl 65 150k HP — NOT in raid_target=1 spawnentry queries. Confirm ID and add to boss catalog scaling pass | lore-master | architect | **Resolved 2026-04-22 (Classic scope)** | Classic-scope: Enraged Golem 72106, Ireblind Imp 72069, Enraged Imp 72108, Overseer of Air 71034, Protector of Sky 71059, Hand of Veeshan 71060, Bazzt Zzzt 71072, Keeper of Souls 71075, Sister of Spire 71076, essence tamer 71071 (not true DT — spell 303 is throw), Innoruuk revamp 186158, hateplaneb event adds, cazicthule Avatars. Kunark subset (Xenevorash 85208, Renux Herkanor 448200/2033/12032/56172, Vessel Drozlin 106008, General V'ghera 20205, Thrackin Griften 12172) deferred to Phase 3. The Hole SK-epic NPCs (Caradon 39069, Kyrenna 39155, Mummy of Glohnor 39165) deferred to Phase 3 (SK epic is Kunark-era). Triggered Trakanon: deferred to Phase 3. Full details in `architect/context/q13-npc-investigation.md`. |

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
| 13 | PoSky Islands 4-8: remove death-touch abilities on affected mobs | user | 2026-04-22 | Unblocks Necro, Ranger, Magician, Warrior epic progressions for small-group play |
| 14 | Epic class-gate steps: keep as-is | user | 2026-04-22 | Accept "roll alts for other epics"; don't rewrite quest scripts to remove skill gates |
| 20 | Kithicor Night Crew (NPC IDs 20054-20064): exclude from raid scaling, treat as named-tier | user | 2026-04-22 | These sit closer to named tier than raid tier; current difficulty is fine |
| 15 | Phase 2 live Plane of Hate layout: `hateplaneb` (revamp) | architect | 2026-04-22 | Confirmed via DB (491 spawns vs 213) + Titanium entry path is `oasis/player.lua:4 MovePCDynamicZone("hateplaneb")`. Classic hateplane only reachable from potactics (PoP, out of era). |
| 16 | Death-touch removal mechanism: DELETE spell 982 from `npc_spells_entries` for spell lists 118/449/969 | architect | 2026-04-22 | Config-expert initially proposed `special_abilities` ability 35 — verified incorrect (ability 35 is `HarmFromClientImmunity`, an immunity flag). Real mechanism is spell 982 "Cazic Touch" (-100,000 HP, 0 cast, 0 mana) in spell list. Single DELETE of 3 rows. |
| 17 | Phase 2 is 100% SQL — no C++, no Lua, no Perl, no rule changes | architect | 2026-04-22 | All levers (HP, damage, respawn, rampage trim, death-touch) are expressible as `npc_types`+`spawn2`+`npc_spells_entries` DB changes. Rule system offers no per-raid-boss lever and would require C++ recompile. |
| 18 | essence tamer 71071 is NOT a death-touch boss despite lore-master classification | architect | 2026-04-22 | Its spell list (npc_spells_id=212) has only spell 303 "Whirl till you hurl" = effect 64 (throw/fling), not instant death. HP/damage scaling still applies but no spell-list edit needed. |
| 19 | Q13 triggered NPCs identified for Classic scope; Kunark subset deferred to Phase 3 | architect | 2026-04-22 | 13 Classic triggered-spawn NPCs added to Phase 2 UPDATE scope. 5 Kunark-era triggered NPCs (Xenevorash, Vessel Drozlin, Renux Herkanor variants, Thrackin Griften, Kunark SK-epic NPCs in The Hole) deferred. |

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
