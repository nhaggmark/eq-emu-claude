# Raid Scaling — Status Tracker

> **Feature branch:** `feature/raid-scaling`
> **Created:** 2026-04-21
> **Last updated:** 2026-04-23 (Phase 3 Kunark server-side validation complete)

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-04-21 | 2026-04-21 |
| Design | game-designer + lore-master | Complete 2026-04-21. Classic epics canonically authored by lore-master 2026-04-22; Kunark/Velious/Luclin quest-chain re-review still pending for Phase 4 prep | 2026-04-21 | 2026-04-21 |
| Architecture | architect + protocol-agent + config-expert | Phase 2: Complete 2026-04-22. Phase 3 (Kunark): **Complete 2026-04-22** — architecture doc delivered, 2 user decisions required before implementation dispatch | 2026-04-22 | 2026-04-22 |
| Implementation | data-expert + config-expert + infra-expert | Complete (Phase 2 Classic) 2026-04-23. Complete (Phase 3 Kunark) 2026-04-23 — Kunark SQL applied, reload verified (27/27 pass) | 2026-04-22 | 2026-04-23 |
| Validation | game-tester + user | Phase 2: Complete — Server-side PASS; Lady Vox PASS; remaining tests deferred. Phase 3 Kunark: Server-side PASS 2026-04-23 (86 checks); user in-game testing deferred per user decision to proceed | 2026-04-22 | 2026-04-23 |
| Completion | _user_ | Phase 2 Classic Complete 2026-04-23. Phase 3 Kunark Complete 2026-04-23 — proceeding to Phase 4a Velious non-ToV | 2026-04-23 | 2026-04-23 |

**Current phase:** Phase 4a (Velious non-ToV) Architecture starting 2026-04-23. Lore-master re-engagement noted as recommended for Velious scripted-event content (Coldain Ring War / Q8). Architecture team will include lore-master for progression-chain consultation.

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
| Phase 2 — Classic | Fear, Hate, Sky, Nagafen, Vox, dragons + Classic epic steps | **Complete 2026-04-23** |
| Phase 3 — Kunark | Trakanon, Veeshan's Peak + Kunark epic steps | **Complete 2026-04-23** |
| Phase 4a — Velious non-ToV | Outdoor Velious dragons, Kael (non-AoW), Western Wastes, Siren's Grotto, Skyshrine, Plane of Growth/Mischief, Velious epic steps, Coldain Ring War (Q8) | In Progress — Architecture starting 2026-04-23 |
| Phase 4b — Velious ToV+Sleeper+Vulak | Temple of Veeshan proper, Sleeper's Tomb, Avatar of War, Vulak'Aerr | Not Started |
| Phase 5a — Luclin non-VT | Ssraeshza, Grieg's End, Akheva, Luclin raid content ex-VT | Not Started |
| Phase 5b — Luclin VT+shards | Vex Thal proper, VT key shard rework | Not Started |

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
    Three tables touched: `npc_types` (~49 UPDATEs after Night Crew exclusion), `spawn2` (~40 UPDATEs),
    `npc_spells_entries` (3 DELETEs).
  - **essence tamer (71071) is NOT a true death-touch boss** — spell 303
    "Whirl till you hurl" is effect 64 (throw), not instant kill. Scaling HP
    still applies; no spell-list edit needed.
  - **Kithicor Night Crew (6 NPCs, IDs 20054-20064) EXCLUDED** per user
    override 2026-04-22 (Decision #20, Option B). They sit at 12k-27k HP in the
    scaled-named range already. Treat as named-tier — no Phase 2 action.
- **Required agents for implementation:** data-expert (primary),
  config-expert (reload + verification), infra-expert (conditional
  full-stack restart).
- **NOT needed:** c-expert, lua-expert, perl-expert, protocol-agent.
- **Ready for:** implementation team dispatch.

### game-tester → user (server-side validation complete, in-game testing pending)
- **Date:** 2026-04-22
- **Server-side result:** PASS WITH NOTES
- **Deliverables:**
  - `game-tester/server-validation.md` — 60-check validation report; all DB values confirmed
  - `game-tester/in-game-testing-guide.md` — 20 test cases across 6 zones
  - `game-tester/test-plan.md` — summary test plan
- **Key notes:**
  - All ~49 npc_types UPDATEs, ~40 spawn2 UPDATEs, and 3 npc_spells_entries DELETEs confirmed in DB
  - Critical: PoSky tests S1-S3 must be done first to confirm death-touch removal is live in zone memory
  - If any PoSky boss still casts Cazic Touch: dispatch infra-expert for full-stack restart (zone spell list cache flush), then retest
  - Innoruuk revamp has loottable_id=0 (pre-existing, script loot via event_loot) — not a Phase 2 regression
- **Handoff to:** user for in-game testing execution

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

### architect → user (Phase 3 Kunark architecture complete; 2 user decisions required)
- **Date:** 2026-04-22
- **Deliverables:**
  - `architect/kunark-architecture.md` — full Phase 3 (Kunark) architecture doc:
    executive summary, per-raid scope (4 outdoor dragons, Trakanon + triggered,
    Venril Sathir + Drusella, Chardok royals, City of Mist pair, 7 VP revamp
    dragons), mechanical levers, 9-task breakdown with dependencies, risk
    assessment, 4 review passes, validation plan for game-tester
  - `architect/context/kunark-db-investigation.md` — complete DB confirmation:
    live raid_target=1 NPC list, VP condition-gated variant resolution
    (revamp=condition 2=1=live; classic=condition 1=0=dormant), Q13 Kunark
    NPC resolution (most are named-tier, no action), death-touch audit
    (zero free-cast instakill spells found)
- **Key decisions made during architecture:**
  - **VP variant resolution definitive:** spawn_condition_values shows revamp
    variants (108040-108053) are live via condition 2, classic variants
    (108509-108517) are dormant via condition 1. Per Decision #5 we scale
    only revamp variants. Classic variants backed up for safety over-capture.
  - **No `npc_spells_entries` DELETE for Phase 3.** DB audit for Cazic-Touch-
    profile spells (mana=0, cast_time=0, damage < -10000) across all Kunark
    raid bosses returned zero rows. Highest-damage spell is Nexona's Dragon
    Harm Touch at -4000 HP / 45s recast — signature mechanic per Decision #11.
  - **Q13 Kunark NPC resolution complete:** Xenevorash, Vessel Drozlin,
    Thrackin Griften, Caradon, Kyrenna, Mummy of Glohnor, two "Tortured Soul"
    variants — all confirmed named-tier HP already. No Phase 3 action needed.
    The Tangrin (78070) flagged for later if Enchanter epic blocks.
  - **100% SQL implementation** (same pattern as Phase 2). No C++, Lua, Perl,
    rules, or config changes. Three tables touched: `npc_types` (~20 UPDATEs),
    `spawn2` (~14 UPDATEs), plus Kunark-scoped backup tables.
  - **Protocol-agent confirmed zero client-visible changes.** Config-expert
    confirmed no new rules since Phase 2 apply (2026-04-22); no zone-scoped
    rules; 12h mid-tier respawn correct for Kunark per Decision #5.
- **TWO USER DECISIONS REQUIRED BEFORE IMPLEMENTATION:**
  - **Decision #21:** Chardok Royals respawn — leave at 1.5h (Option A, recommended)
    or bump to 12h (Option B) or intermediate 6h (Option C)
  - **Decision #22:** Renux Herkanor 448200 (L72 500k HP, script-spawned,
    Monk epic terminus) — include in Phase 3 (Option A, recommended) or
    defer past L70 in-era filter (Option B)
- **Required agents for implementation:** data-expert (primary), config-expert
  (reload + verification), infra-expert (conditional full-stack restart).
- **NOT needed:** c-expert, lua-expert, perl-expert, protocol-agent.
- **Ready for:** user decisions on #21 and #22 → then implementation team dispatch.

### game-tester → user (Phase 3 Kunark server-side validation complete)
- **Date:** 2026-04-23
- **Server-side result:** PASS
- **Deliverables:**
  - `game-tester/kunark-server-validation.md` — 86-check validation report; all DB values confirmed
  - `game-tester/kunark-in-game-testing-guide.md` — 7 sessions, 12 test cases across Kunark zones
- **Key notes:**
  - All 21 npc_types UPDATEs and all spawn2 respawn UPDATEs confirmed in DB
  - VP _condition=2 filter held correctly — only revamp dragons (condition=2) at 43200s; classic
    variants (condition=1) untouched at 64800-86400s
  - Intentionally unchanged NPCs confirmed: #Trakanon 89181 at 16k, Drusella 105153 at 15.75k,
    Prince Selrach 103080 at 25k, Lhranc 90093 at 19k, Fabled variant 103218 at 1.5M
  - Kilidna one-shot fix confirmed: maxdmg 4600→1000, HP 100k→30k; respawn 1.5h→6h
  - Decision #21 honored: Chardok Royals respawn at 5400s (1.5h), unchanged
  - Decision #22 honored: Renux Herkanor 448200 at 120k HP, maxdmg 900
  - Backup tables: npc_types_backup 28 rows (27+1 from Q22), spawn2_backup 25 rows
  - No crash logs in Kunark zones; world log clean of Phase 3 errors
  - No npc_spells_entries changes (zero death-touch spells in Kunark) — no spell cache caveat
    applies for Phase 3 (unlike Phase 2 Cazic Touch deletion)
- **Handoff to:** user for in-game testing execution

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Create backup tables for `npc_types`, `spawn2`, `npc_spells_entries` raid-target rows | data-expert | **Complete 2026-04-22** | npc_types_backup: 2548 rows; spawn2_backup: 6669 rows; npc_spells_entries_backup: 6 rows; Cazic Touch captured: 3 rows |
| 2 | Emit per-boss HP/damage/special_abilities UPDATE SQL (30 audit bosses + 13 Q13 + 23 hateplaneb - 6 Night Crew excluded = ~49 rows) | data-expert | **Complete 2026-04-22** | All verification checks passed. CT special_abilities NOT edited — global MaxRampageTargets=2 cap sufficient. |
| 3 | Emit respawn-timer UPDATE SQL (6h low-tier / 12h Cazic+Guardian of Seal) | data-expert | **Complete 2026-04-22** | 6h applied to all Classic low-tier; 12h for CT (72003) and Guardian of Seal (39115); hateplaneb outlier 186183 cut to 6h; DZ 900s untouched |
| 4 | Emit `npc_spells_entries` DELETE for Cazic Touch (spell 982) from lists 118, 449, 969 | data-expert | **Complete 2026-04-22** | Exactly 3 rows deleted (confirmed). Remaining entries in each list preserved. |
| 5 | Emit rollback script (INSERT SELECT from backup tables) + verification queries | data-expert | **Complete 2026-04-22** | `03-rollback.sql` written — transactional JOIN-UPDATE + INSERT IGNORE for spell 982 re-insert |
| 6 | Apply SQL via `docker exec ... mysql` ; capture before/after row counts | data-expert | **Complete 2026-04-22** | All verification queries passed. See data-expert/dev-notes.md Stage 4 for full output. |
| 7 | `#reloadworld` (via Spire or in-game GM command) to refresh zone caches | config-expert | **Complete 2026-04-22** | Issued via world telnet console (port 9000). Response: "Reloading World..." |
| 8 | Smoke verify: Nagafen HP, CT rampage string, Keeper spell list, hateplaneb Innoruuk HP, respawn timer for Nagafen | config-expert | **Complete 2026-04-22** | All checks pass: Nagafen 14400/21600s, Vox 14400, CT 80000, Innoruuk 60000, Keeper 22000, Spiroc Lord 22000, Enraged Golem 40000, spell 982 = 0 rows. Commit 41ebfc4 pushed. |
| 9 | Full-stack restart if `#reloadworld` doesn't propagate npc_spells_entries cache | infra-expert | **Conditional — pending in-game observation** | npc_spells_entries cache loads at zone boot, not on #reloadworld. DB DELETE confirmed. If player observes PoSky death-touch in-game, infra-expert must run full restart to clear spell list cache. |
| 10 | Commit + push `claude/` repo changes (architecture, context, status, implementation SQL) to `feature/raid-scaling` branch | data-expert | **Complete 2026-04-22** | Committed on feature/raid-scaling |

---


### Phase 3 Kunark Implementation Tasks

_Populated by the architect for Phase 3 (Kunark). Awaiting user decisions #21, #22 before dispatch._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| K1 | Create backup tables `npc_types_backup_raid_scaling_kunark` (26 rows) and `spawn2_backup_raid_scaling_kunark` (~20 rows) | data-expert | **Complete 2026-04-22** | 28 rows in npc_types backup (27+1 for Renux Herkanor Q22=Option A); 25 rows in spawn2 backup |
| K2 | Emit per-boss HP/damage UPDATE SQL (~20 Kunark bosses: 4 outdoor dragons + Trakanon + triggered VS + Chardok royals + Kilidna + 7 VP revamp + Faydedar duplicate) | data-expert | **Complete 2026-04-22** | All 21 npc_types UPDATEs confirmed in DB by game-tester server-side validation |
| K3 | Emit respawn-timer UPDATE SQL (12h for Trakanon/VP/outdoor dragons; 6h for Kilidna; Chardok Royals per Decision #21; VP scoped to `_condition=2` only) | data-expert | **Complete 2026-04-22** | All spawn2 respawn UPDATEs confirmed. VP condition=2 filter held (7 rows only). Decision #21 honored (Royals at 5400s). |
| K4 | Emit rollback script (INSERT…SELECT from backup tables, transactional) + verification queries | data-expert | **Complete 2026-04-22** | `06-kunark-rollback.sql` confirmed present |
| K5 | Apply SQL via `docker exec akk-stack-mariadb-1 mysql … < phase3-kunark-implementation.sql`; capture before/after row counts | data-expert | **Complete 2026-04-22** | All changes applied and confirmed in DB |
| K6 | `#reloadworld` via Spire or world telnet port 9000 to refresh zone caches | config-expert | **Complete 2026-04-22** | Issued via world telnet console (port 9000). Response: "Reloading World..." No full-stack restart needed (no npc_spells_entries changes in Phase 3). |
| K7 | Smoke verify: Trakanon HP, Nexona stats, Phara Dar stats, Gorenaire respawn, Kilidna damage cap, VP `_condition=2` only touched | config-expert | **Complete 2026-04-22** | 27/27 checks PASS. All HP/damage targets confirmed. VP condition=2 only (7 rows). Chardok Royals at 5400s (Decision #21 honored). Classic VP variants untouched. Lhranc/Drusella unchanged. No Night Crew regressions. |
| K8 | Full-stack restart (conditional) if `#reloadworld` doesn't propagate | infra-expert | **Not Needed** | Phase 3 doesn't touch npc_spells_entries; #reloadworld sufficient |
| K9 | Commit + push `claude/` repo changes (architecture, context, status, implementation SQL) to `feature/raid-scaling` branch | game-tester | **Pending** | game-tester to commit kunark-server-validation.md, kunark-in-game-testing-guide.md, status.md updates |

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

| 21 | Chardok Royals (Queen Velazul 103055, Overking Bathezid 103056, Prince Selrach 103080) currently respawn at 1.5h. Decision #5 mid-tier is 12h, but 1.5h is shorter. Leave at 1.5h (Option A, architect-recommended), bump to 12h for tier consistency (Option B), or 6h intermediate (Option C)? | architect | user | **Resolved 2026-04-23** | Option A — leave at 1.5h (preserve farming cadence) |
| 22 | Renux Herkanor 448200 (L72 500k HP raid_target=1, script-spawned, Monk epic Kunark-era terminus): include in Phase 3 scaling (Option A, architect-recommended) or defer past L70 in-era filter (Option B)? | architect | user | **Resolved 2026-04-23** | Option A — include in Phase 3 scaling (apply HP cut) |

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
| 21 | Chardok Royals: respawn stays at 1.5h (Option A) | user | 2026-04-23 | Preserve farming cadence; 1.5h was intentional per audit |
| 22 | Renux Herkanor 448200: include in Phase 3 scaling (Option A) | user | 2026-04-23 | Monk epic Kunark-era terminus must be doable by small group |

---

## Completion Checklist

### Implementation Complete (agents can check these)

_Filled in after game-tester validation passes._

- [x] All implementation tasks marked Complete
- [x] No open Blockers
- [x] game-tester server-side validation: PASS WITH NOTES (2026-04-22)
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
