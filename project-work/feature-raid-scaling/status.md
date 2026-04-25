# Raid Scaling — Status Tracker

> **Feature branch:** `feature/raid-scaling`
> **Created:** 2026-04-21
> **Last updated:** 2026-04-22 (Phase 4b server-side validation PASS — 127 checks; in-game testing guide ready for user)

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-04-21 | 2026-04-21 |
| Design | game-designer + lore-master | Complete 2026-04-21. Classic epics canonically authored by lore-master 2026-04-22; Kunark/Velious/Luclin quest-chain re-review still pending for Phase 4 prep | 2026-04-21 | 2026-04-21 |
| Architecture | architect + protocol-agent + config-expert + lore-master | Phase 2-4b: all Complete 2026-04-23. **Phase 5a Luclin non-VT: Complete 2026-04-25** — all advisors cleared (protocol-agent + config-expert 2026-04-22; lore-master 2026-04-25 APPROVED). **All 4 user decisions resolved 2026-04-25:** Q50=A INCLUDE (joint), Q51=B INCLUDE USER OVERRIDE, Q52=B SOFTEN USER OVERRIDE, Q59=A INCLUDE (joint). **41 npc_types UPDATEs** + 1 npc_spells_entries DELETE (Touch of Vinitras list 196 only) + ~17-18 spawn2 UPDATEs + 1 perl edit (`#EmpCycle.pl:3`). Implementation team: data-expert + config-expert + perl-expert + infra-expert (contingent). Ready for implementation dispatch. | 2026-04-22 | 2026-04-25 |
| Implementation | data-expert + config-expert + perl-expert + infra-expert | Phases 2/3/4a/4b/5a all Complete. Phase 5a included 1 Perl edit (`#EmpCycle.pl:3` for Q52 user override) + cross-repo akk-stack commit. | 2026-04-22 | 2026-04-25 |
| Validation | game-tester + user | Phases 2-5a: all server-side validations PASS. Phase 5a: 117 checks PASS (Touch of Vinitras DELETE confirmed list 196 cleared / list 179 preserved, Spirit of Akelha`Ra unchanged, Phase 5b reservations clean, all prior phases clean). | 2026-04-22 | 2026-04-25 |
| Completion | _user_ | Phases 2, 3, 4a, 4b, 5a all Complete — proceeding to Phase 5b Luclin VT (final phase) | 2026-04-23 | 2026-04-25 |

**Current phase:** Phase 5b (Luclin VT + 13-shard key rework) Architecture starting 2026-04-25. **FINAL PHASE OF PROJECT.** Scope: Vex Thal proper (Aten Ha Ra at audit-flagged 63× HP gap, Diabo trio, Thall Va tier, all 158xxx-range VT inner bosses), Yaemiu elite trash (~80 mobs, Q4 in scope), Va_Dyn_Khar 158081, Akhevan Warders 158087-94 (vexthal-zoned), 13-shard VT key quest (Q7 = keep all 13).

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
| Phase 4a — Velious non-ToV | Outdoor Velious dragons, Kael (non-AoW), Western Wastes, Siren's Grotto, Skyshrine, Plane of Growth/Mischief, Velious epic steps, Coldain Ring War (Q8) | **Complete 2026-04-23** (BUG-001 Tunare fixed; user accepted DB-verified state) |
| Phase 4b — Velious ToV+Sleeper+Vulak+AoW | Temple of Veeshan proper (16 lords + 16 NToV mid-tier + 4 Defenders), Sleeper's Tomb (5 Ancients + 4 Warders + Progenitor + Final Arbiter + MotG + Milas), AoW, Vulak = 51 NPCs. Kerafyrm trio untouched per Decision #12. | **Complete 2026-04-23** (server-side PASS 127 checks; user accepted) |
| Phase 5a — Luclin non-VT | ssratemple (13 + 2 cycle serpents per Q50=A), akheva (8 primary + 3 elite-named per Q51=B), sseru/katta (7), griegsend (3), acrylia (2 + 1 Spiritual Arcanist per Q59=A), thedeep (1), umbral (3) = **41 NPCs**. Touch of Vinitras DT removal list 196 only (list 179 preserved per Decision #60). Q52=B perl edit `#EmpCycle.pl:3` softens Emperor cycle 3-5d → 22-24h. | **Complete 2026-04-25** (server-side PASS 117 checks; user accepted) |
| Phase 5b — Luclin VT+shards | Vex Thal proper (Aten Ha Ra, Diabo trio, Thall Va tier, all 158xxx VT inner bosses), Yaemiu elite trash (~80 mobs Q4=A), Va_Dyn_Khar 158081, Akhevan Warders 158087-94, 13-shard VT key quest (Q7=A keep all 13) | In Progress — Architecture starting 2026-04-25 |

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

### architect → user (Phase 4a Velious non-ToV architecture complete; 4 user decisions required)
- **Date:** 2026-04-23
- **Deliverables:**
  - `architect/velious-a-architecture.md` — full Phase 4a architecture doc:
    executive summary, per-zone scope (Kael non-AoW + Skyshrine + Plane of Growth +
    Plane of Mischief Jester + outdoor Velious dragons + Siren's Grotto + Velketor +
    Dain's Icewell + Narandi), mechanical levers, 11-task breakdown with dependencies,
    risk assessment, 4 review passes, validation plan for game-tester
  - `architect/context/velious-a-db-investigation.md` — complete DB confirmation:
    in-scope raid bosses list, out-of-scope / out-of-era NPCs explicitly excluded,
    Coldain Ring War spawn_conditions mechanism, wave composition analysis,
    death-touch sweep (zero results), Lord Yelinak duplicate resolution (both live)
  - Appendix in main doc includes Phase 4b deferred list (AoW, ToV proper, Sleeper,
    Vulak) and future user-decision flags (faction grind, Ring 8/9 UX)
- **Key decisions made during architecture:**
  - **Q8 resolution (lore-master-endorsed, supersedes my original draft):** Option D =
    Lever 1 (SQL wave-mob HP cuts — 8 Kromrif IDs exclusive to greatdivide conditions
    3-15 + Seneschal 10k→30k bump) + conditional Lever 2 (one-line `wave_cooldown_time`
    5min→8min Lua edit, invoked only if game-tester shows Lever 1 insufficient).
    Preserves all 13 waves + Narandi. Event duration ~45-90 min.
  - **Default: 100% SQL** (Lever 1 only). Three tables touched: `npc_types`
    (~44 UPDATEs incl. 8 Kromrif wave mobs + Seneschal), `spawn2` (~14-16 UPDATEs),
    backup tables. **No** `npc_spells_entries` changes (death-touch sweep returned zero
    rows). **Conditional:** 1 Lua file edit only if Lever 2 triggered.
  - **Lord Yelinak dual scaling** — both 114106 (500k→110k) and 114618 (297k→110k).
  - **Event-trigger NPCs and Jaled Dar's Shade left untouched** — quest-NPC / event-control
    design per lore-master and audit. Protocol-agent confirmed no client-visibility issue.
  - **lua-expert is CONDITIONAL only** (Lever 2 fallback). Default Phase 4a team
    is data-expert + config-expert (identical to Phases 2/3). lua-expert invoked only
    after game-tester validation + user approval.
- **FIVE USER DECISIONS RAISED (#23-27):**
  - **#23 Coldain Ring War lever** — **lore-master-endorsed Option D** (Lever 1 SQL + Lever 2 fallback). Architect now recommends Option D.
  - **#24 Yelinak duplicates** — architect recommends scale both to 110k
  - **#25 Faction grind acceleration** — architect recommends out-of-Phase-4a
  - **#26 Ring 8/9 UX softening** — architect recommends out-of-Phase-4a
  - **#27 Plane of Mischief Jester inclusion** — lore-master recommends exclude; architect defers to user
- **Protocol-agent Phase 4a consultation confirmed** zero client impact (logged 2026-04-22).
- **Config-expert Phase 4a consultation confirmed** no rule changes needed, all prior-pass
  globals unchanged, no zone-scoped rulesets (logged 2026-04-22).
- **Lore-master Q8 re-engagement complete 2026-04-23** — Option D (Lever 1 + conditional Lever 2) adopted.
- **Required agents for implementation (default path):** data-expert (primary), config-expert
  (reload + smoke). lua-expert and infra-expert are CONDITIONAL fallback only.
- **NOT needed:** c-expert, perl-expert, protocol-agent (already advised).
- **Ready for:** user decisions #23-#26 → then implementation team dispatch (includes
  lua-expert for first time in raid-scaling project).


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

### game-tester → data-expert (Phase 4a Velious non-ToV server-side validation complete — BUG-001 filed)
- **Date:** 2026-04-23
- **Server-side result:** FAIL (1 bug — BUG-001)
- **Deliverables:**
  - `game-tester/velious-a-server-validation.md` — 108-check validation report; 107 PASS, 1 FAIL
  - `game-tester/velious-a-in-game-testing-guide.md` — 8 sessions, Ring War is Session 1 (highest priority)
  - `bugs/BUG-001-tunare-wrong-npc-id/report.md` — Tunare combat boss (127098) at 530k HP; fix is one SQL UPDATE
- **Key notes:**
  - BUG-001: `#Tunare` combat boss (NPC 127098) is at 530,000 HP. The implementation targeted 127001 (`#_Tunare`, passive trigger NPC that depops on engage and script-spawns 127098). Fix: `UPDATE npc_types SET hp = 150000 WHERE id = 127098;` — also add 127098 to backup table. No spawn2 change needed (127098 has no spawn2 row, always script-spawned).
  - BUG-001 does NOT block Ring War, Kael, Skyshrine, outdoor dragons, Velketor, Sirens, or Mischief sessions — only PoG Tunare fight is affected.
  - All Kromrif wave mob HP cuts (Lever 1) confirmed. Ring War Lever 2 NOT applied (wave_cooldown_time = 5 min, unchanged).
  - spawn2 backup has 227 rows (vs estimate 55-65) — correctly captures all Ring War wave mob spawn2 rows in greatdivide (193 rows, all confirmed exclusive to Ring War NPC IDs).
  - Phase 4b exclusions confirmed: AoW at 900k, Vulak at 890k — untouched.
- **Handoff to:** data-expert (BUG-001 fix), then user for in-game testing

### Phase 4a Velious non-ToV Implementation Tasks

_Populated by the architect for Phase 4a (Velious non-ToV). Awaiting user decisions #23, #24 (and optionally #25, #26) before dispatch. Also awaiting lore-master's Q8 final recommendation to finalize Decision #23._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| V1 | Build backup tables `npc_types_backup_raid_scaling_velious_a` (42 rows incl. 8 Kromrif + Seneschal) and `spawn2_backup_raid_scaling_velious_a` (~35-40 rows); emit SQL reference doc structure | data-expert | **Not Started** | Mirrors Phase 3 pattern with `_velious_a` suffix |
| V2 | Emit per-boss HP/damage UPDATE SQL (~35 Velious non-ToV bosses: Kael 4 + Skyshrine 6 + PoG 9 + Jester (pending Decision #27) + WW dragons 3 + Velketor pair + Kelorek + WW trim 3 + Sirens 2 + Dain + Chamberlain + Taskmaster + Wuoshi + Lodizal) | data-expert | **Not Started** | Commit to `data-expert/context/phase4a-velious-a-implementation.sql` |
| V3 | Emit Ring War Lever 1 SQL (8 Kromrif wave-mob HP cuts + Seneschal Aldikar 10k→30k bump + Narandi 150k→45k) | data-expert | **Not Started** | Lore-master-endorsed Q8 resolution. Kromrif IDs confirmed exclusive to greatdivide conditions 3-15. |
| V4 | Emit `spawn2.respawntime` UPDATE SQL (12h for ~15 mid-tier bosses; skip already-short; skip Narandi condition-gated; Kromrif wave mobs no respawn change) | data-expert | **Not Started** | Mirror Phase 3 pattern |
| V5 | Emit rollback script (INSERT…SELECT from backup tables, transactional) + verification queries | data-expert | **Not Started** | Mirror `06-kunark-rollback.sql` pattern |
| V6 | Apply SQL via `docker exec akk-stack-mariadb-1 mysql … < phase4a-velious-a-implementation.sql`; capture before/after row counts | data-expert | **Not Started** | — |
| V7 | `#reloadworld` via Spire or world telnet port 9000 | config-expert | **Not Started** | No `ring_war.lua` edit by default — no `#reloadquests` needed. |
| V8 | Smoke verify: Kael bosses HP, Skyshrine Yelinak duals at 110k, Tunare 150k, outdoor dragons 35-40k, respawn 12h applied to correct IDs, Kromrif wave-mob HP at Lever 1 targets, Seneschal at 30k | config-expert | **Not Started** | — |
| V9 | Commit + push `claude/` repo changes (architecture doc, context files, status, SQL) to `feature/raid-scaling` branch. `akk-stack/` untouched unless Lever 2 triggered. | game-tester | **In Progress** | Validation deliverables committed this pass; BUG-001 fix commit pending |
| V_BUG001 | Fix BUG-001: `UPDATE npc_types SET hp = 150000 WHERE id = 127098;` — add 127098 to backup table; then `#reloadworld` | data-expert | **Complete 2026-04-23** | Backup row inserted (hp=530000), UPDATE applied (hp=150000), reloadworld issued. SQL: 09-bug-001-tunare-fix.sql. Pending game-tester re-verification. |
| V10 | (**CONDITIONAL Lever 2**) IF game-tester validation shows ≥3 consecutive waves overlapping with Lever 1 alone, AND user approves: lua-expert edits `ring_war.lua:26` wave_cooldown_time from 5min to 8min | lua-expert | **Not Started (conditional)** | Fallback only. lua-expert invoked post-validation, not in default dispatch. |
| V11 | (**CONDITIONAL**) `#reloadquests` via Spire, OR full-stack restart (infra-expert) if `#reloadquests` doesn't propagate Lua script change | config-expert OR infra-expert | **Not Started (conditional)** | Only needed after V10. |



### architect → user (Phase 4b Velious ToV+Sleeper+Vulak+AoW architecture complete; 3 user decisions required)
- **Date:** 2026-04-23
- **Deliverables:**
  - `architect/velious-b-architecture.md` — full Phase 4b architecture doc:
    executive summary, per-zone scope (ToV 16 dragon lords + 16 NToV mid-tier named +
    Sleeper's Tomb 13 bosses incl. 4 Warders + AoW 113457 + Vulak 124155), mechanical
    levers (endgame HP cuts 70-87%, 24h respawn tier, no spell-list edits, no script
    edits), 11-task breakdown (B1-B11), risk assessment, 4 review passes, Kerafyrm
    Isolation Proof (§2), validation plan
  - `architect/context/velious-b-db-investigation.md` — complete DB confirmation:
    47-NPC in-scope catalog, defender cluster exclusion rationale, full
    Kerafyrm awake chain code trace (4 Warder `.pl` files + `#The_Sleeper.pl` +
    `#Kerafyrm.pl`) proving HP-independent behavioral gating, death-touch sweep
    (only hits: Vyskudra Lightning Breath signature + Kerafyrm Destroy untouched),
    spawn_conditions state verification (Warders dormant / Ancients live), Vulak
    altar-summon mechanism via Thylex entity-presence check, AoW Phase 4a chain
    closure clean
- **Key decisions made during architecture:**
  - **Phase 4b is 100% SQL** (same pattern as Phases 2/3/4a). Zero Lua/Perl/C++/
    rule changes. Tables touched: `npc_types` (47 UPDATEs), `spawn2` (~32 UPDATEs),
    backup tables.
  - **Kerafyrm awake chain is script-driven, not HP-driven.** Full code trace in
    `context/velious-b-db-investigation.md` §2 proves scaling Warder HP from 200k
    → 60k has ZERO effect on awake trigger logic. Kerafyrm trio (128089/94/95),
    "Destroy" death-touch spell (1948), The Sleeper (128094), and all
    Warder/Sleeper/Kerafyrm `.pl` scripts UNTOUCHED per Decision #12.
  - **Warders currently DORMANT** (spawn_conditions condition 1 = 0 in sleeper
    zone). No script auto-flips condition 1; only GM intervention activates
    Warders + The Sleeper.
  - **Vulak altar-summon mechanism verified** via `#Thylex_of_Veeshan.pl`:
    60-second tick checks all 6 altar dragons (Mirenilla/Nevederia/Feshlak/
    Aaryonar/Kreizenn/Vyemm) absent, then `quest::spawn2(124155)` with
    6-minute qglobal cooldown. Presence-check not HP-threshold. Phase 4b
    scaling of the 6 altar dragons propagates Vulak accessibility; no script
    edit needed.
  - **AoW chain (Statue 113071 → Idol 113341 → AoW 113457)** now closes with
    Phase 4b scaling AoW directly. Phase 4a handled Statue+Idol. Protocol-agent
    confirmed `eq.unique_spawn()` staggered scaling is clean.
  - **0 `npc_spells_entries` DELETEs.** Death-touch sweep: only hits were
    Vyskudra Lightning Breath (-1500, 12s recast, signature per Decision #11)
    and Kerafyrm "Destroy" (-100,000 instant, out-of-scope per Decision #12).
  - **Defender cluster (124050/51/52/79) EXCLUDED** per audit line 1673-1677 +
    Decision #2 ("elite trash — no action needed"). Decision #37 flag.
- **Advisor consultations:**
  - **protocol-agent 2026-04-22** — Phase 4b cleared with 7-question response;
    zero client-visibility impact; static zones (no DZ); behavioral gates not
    HP-based for Kerafyrm awake + Vulak altar event + AoW chain.
  - **config-expert 2026-04-23** — Phase 4b 6-question consult dispatched;
    architect working with zero-change default pending response.
  - **lore-master 2026-04-23** — Phase 4b 10-question consult dispatched
    covering Sleeper Awake boundary (Option A/B/C for Decision #36), ToV/ST
    keying confirmations, Vulak altar lore, signature mechanics catalog,
    respawn tier validation; architect working with Option A default (include
    Warders) pending response.
- **THREE USER DECISIONS REQUIRED:**
  - **Decision #36** — Warder scaling: Option A (include, scale to 60k HP; event
    becomes reachable for small group but Kerafyrm event preserved) — ARCHITECT
    RECOMMENDS. Option B (exclude; Warders stay at 200k HP; event remains
    unreachable for small group; stricter Decision #12 interpretation).
  - **Decision #37** — Defenders cluster (124050/51/52/79) exclusion: Option A
    (exclude per audit + Decision #2) — ARCHITECT RECOMMENDS. Option B (include,
    scale as mid-tier named; +4 UPDATEs).
  - **Decision #38** — Lendiniara (124020) respawn tier: Option A (accept endgame
    24h per Decision #8; alternative Klandicar/Sontalak 12h paths preserved from
    Phase 4a) — ARCHITECT RECOMMENDS. Option B (keep 12h mid-tier because of
    Sleeper's Tomb key talisman role; breaks tier consistency).
- **Required agents for implementation:** data-expert (primary, B1-B8 + B11),
  config-expert (reload + smoke, B9-B10). Same team as Phases 2 and 3.
- **NOT needed:** c-expert, lua-expert, perl-expert, infra-expert (no spell-cache
  flush needed), protocol-agent (already advised).
- **Sleeper Awake Event Boundary — architect verification summary (for orchestrator):**
  - Kerafyrm trio (128089 combat, 128094 The Sleeper, 128095 Kerafyrm zone-clone) and
    their spell lists (489) and all `#Kerafyrm.pl`/`#Kerafyrm_.pl`/`#The_Sleeper.pl`
    scripts UNTOUCHED. Zero Phase 4b DB UPDATEs or file edits target these.
  - Scaling the 4 Warders (if Option A) does NOT trigger the awake event — the
    trigger is `quest::signalwith(128094, 66)` called in each Warder's
    EVENT_DEATH_COMPLETE after confirming the other 3 are all dead (via
    `GetMobByNpcTypeID` count, NOT HP). HP column is not referenced.
  - Condition 1 (Warders) is currently 0 (dormant) on our server. No script
    in `/akk-stack/server/quests/sleeper/` flips condition 1 from 0→1. Only
    GM intervention activates Warders + The Sleeper spawns.
  - Phase 4b is safe under Decision #12. User's choice on #36 determines
    whether the event becomes *reachable* for small group (unchanged) vs stays
    *mathematically unreachable* (Warder 200k HP barrier preserved).
- **Ready for:** user decisions #36-#38 → then implementation team dispatch
  (data-expert + config-expert; same team as Phase 3).


### Phase 4b Velious ToV+Sleeper+Vulak+AoW Implementation Tasks

_Populated by the architect for Phase 4b. Awaiting user decisions #36, #37, #38 before dispatch. See `architect/velious-b-architecture.md` for full plan._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| B1 | Build backup tables `npc_types_backup_raid_scaling_velious_b` (**51 rows**: 16 ToV lords + 16 NToV mid-tier + **4 Defenders per Q37 override** + 13 Sleeper's Tomb + AoW + Vulak) and `spawn2_backup_raid_scaling_velious_b` (**~46-49 rows**: +11 Defender spawn2 rows); emit SQL reference doc | data-expert | **Not Started** | Mirrors Phase 3/4a pattern with `_velious_b` suffix |
| B2 | Emit per-boss HP/damage UPDATE SQL for 16 ToV dragon lords (Koi`Doken/Nevederia/Kreizenn/Feshlak/Cekenar/Aaryonar/Dozekar/Mirenilla/Vyemm/Lendiniara/Dagarn/Telkorenar/Gozzrem/Ikatiar/Jorlleag/Eashen); preserve Vyemm/Telkorenar/Gozzrem MR=1000 walls, Dagarn HP-regen, Aaryonar breath | data-expert | **Not Started** | Commit to `data-expert/context/phase4b-velious-b-implementation.sql` |
| B3 | Emit per-boss HP UPDATE SQL for 16 NToV mid-tier named (8 Midayor cluster L60 → 40k + 8 L65-66 named → 40-50k per audit) + **4 NToV Defenders** (124050/51/52/79 → 45k HP, 550 maxdmg per user Q37 override 2026-04-23); Defenders respawn NOT updated | data-expert | **Not Started** | — |
| B4 | Emit per-boss HP/damage UPDATE SQL for 13 Sleeper's Tomb bosses (4 Ancients + Progenitor + Arbiter main/alt + MotG + Milas + 4 Warders); preserve Vyskudra Lightning Breath, Kildrukaun MR=400, MotG 8-sentry wave | data-expert | **Not Started** | Warders only applies if Decision #36 Option A; else skip 128090/91/92/93 + 128045 |
| B5 | Emit Vulak`Aerr UPDATE (890k→150k HP, 355-1400 → 250-800 dmg) and AoW UPDATE (900k→120k HP, 299-1154 → 200-700 dmg); AoW rampage 6×6 preserved via global MaxRampageTargets=2 cap | data-expert | **Not Started** | Closes the Kael chain (Phase 4a scaled Statue+Idol) |
| B6 | Emit `spawn2.respawntime` UPDATE SQL (86,400s = 24h for ~32 rows: 16 ToV + 8 Midayor + Zlexak + Sevalak + 11 Sleeper's Tomb); EXCLUDE mid-tier L65-66 named already at 18h; EXCLUDE Milas (4h); EXCLUDE Defenders; EXCLUDE Kerafyrm trio | data-expert | **Not Started** | Endgame tier per Decision #8 |
| B7 | Emit rollback script (INSERT…SELECT from backup tables, transactional) + verification queries comparing row counts before/after; mirror Phase 3 `06-kunark-rollback.sql` pattern | data-expert | **Not Started** | — |
| B8 | Apply SQL via `docker exec akk-stack-mariadb-1 mysql … < phase4b-velious-b-implementation.sql`; capture before/after row counts | data-expert | **Not Started** | — |
| B9 | `#reloadworld` via Spire or world telnet port 9000 | config-expert | **Not Started** | No `npc_spells_entries` changes — no full-stack restart needed |
| B10 | Smoke verify: Koi`Doken/Vyemm/Vulak/AoW/Kildrukaun HP targets; respawn 24h applied to correct IDs; **Defenders 45k/550** per Q37 override with respawn UNCHANGED (11,250-16,200s); Kerafyrm trio (128089/94/95) UNTOUCHED at 3.5M HP; Destroy spell (1948) still in list 489; Warder HPs per Decision #36 Option A (60k); Thylex (124000) UNTOUCHED at 100 HP | config-expert | **Not Started** | — |
| B11 | Commit + push `claude/` repo changes (architecture doc, context files, status, implementation SQL) to `feature/raid-scaling` branch. `akk-stack/` and `eqemu/` untouched. | data-expert | **Complete 2026-04-22** | Commits 55fe92f + 57ee369 pushed on feature/raid-scaling |

### Phase 5a Luclin non-VT Implementation Tasks

_Populated by the architect for Phase 5a (Luclin non-VT). Awaiting user decisions #50/#51/#52 before dispatch. Lore-master sign-off pending (default architect recommendations stand)._

| # | Task | Assigned Agent | Status | Notes |
|---|------|---------------|--------|-------|
| L1 | Build 3 backup tables (`npc_types_backup_raid_scaling_luclin_a` **41 rows** post-Q50/Q51/Q59 inclusions, `spawn2_backup_raid_scaling_luclin_a` ~22-23 rows incl. 5 Akheva elite-named rows, `npc_spells_entries_backup_raid_scaling_luclin_a` 1 row); verify counts | data-expert | **Not Started** | Mirrors Phase 4b backup pattern with `_luclin_a` suffix. All 4 user decisions resolved 2026-04-25. |
| L2 | Emit per-boss HP/damage UPDATE SQL for ssratemple cluster (13 bosses + 2 flagged rune/glyph serpents per Decision #50 default include); preserve Emperor cycle/Leash 290/spell list 227 | data-expert | **Not Started** | Excludes Emperor placeholder 162065, EmpCycle controller 162260, keycheck 162269. Includes Blood (162189) + Blood Golem (162064) + 17×spawn2 pre-Emperor named at 1080s farming-tier preserved |
| L3 | Emit per-boss HP/damage UPDATE SQL for akheva cluster: 8 primary (3 Vyzh\`dra variants + Itraer Vius + Shei Vinitras REAL 179032 + MERCHANT 179157 + Insanity Crawler + Va\`Dyn + Shar Vinitras) + **3 Q51=B elite-named** (Sheleric Vis 179133 116k→35k+550, Sheleric Vis 179046 70k→30k, Xaui Tatrua 179044 70k→30k) = **11 NPCs total** | data-expert | **Not Started** | Q51=B USER OVERRIDE 2026-04-25 — INCLUDE elite-named. Respawn UNCHANGED on 5 Akheva elite-named spawn2 rows per Q51 named-tier philosophy. |
| L4 | Emit Touch of Vinitras DT DELETE: `DELETE FROM npc_spells_entries WHERE npc_spells_id = 196 AND spellid = 2859;` (1 row affected; Vyzh\`dra Exiled + Banished). Vyzh\`dra Cursed list 197 untouched. | data-expert | **Not Started** | Decision #16 (Cazic Touch) + Decision #13 (PoSky DT removal) precedent |
| L5 | Emit per-boss HP/damage UPDATE SQL for sseru/katta cluster (Lord Inquisitor Seru with MR=800 PRESERVED + 4 Praesertum + Lcea Katta + Nathyn Illuminious = 7 NPCs) | data-expert | **Not Started** | Bella/Heracus Helsin (160177/178) excluded per protocol-agent event-control list |
| L6 | Emit per-boss HP/damage UPDATE SQL for griegsend (3) + acrylia (**3** — Khati Sha 154145 90k + evolved burrower 154142 60k + **Q59=A Spiritual Arcanist 154153 → 40k**) + thedeep (1 Thought Horror Overfiend) + umbral (3 incl. Doomshade 176088 audit-missed) = **10 NPCs** | data-expert | **Not Started** | Q59=A joint recommendation 2026-04-25. Excludes 163051/52 (LoN OOE), 154161 (Fabled), 176111 (Netherbian L73 OOE), 176110 Keymaster, 153095 Blaystich (elite-named tier per Decision #2). 154151/154152 (Khati event quest NPCs, raid_target=0) NOT scope. |
| L7 | Emit `spawn2.respawntime` UPDATE SQL (86,400s = 24h endgame for ~17-18 rows). EXCLUDE: pre-Emperor 1080s short-tier (Ring of the Shissar farming), Rhozth pair (Taskmaster's Pouch farming), Shar Vinitras 10800s (audit-preserved), Sheleric Vis + Xaui Tatrua (Decision #51 elite-named). | data-expert | **Not Started** | Endgame tier per Decision #8. Script-spawned bosses have NO spawn2 — their cycle timers live in scripts (preserved). |
| L8 | Emit rollback script: 3-stage transactional INSERT…SELECT from backup tables (npc_types restore + spawn2 restore + npc_spells_entries re-insert spell 2859) + verification queries; mirror Phase 4b `06-velious-b-rollback.sql` pattern | data-expert | **Not Started** | — |
| L9 | Apply SQL via `docker exec akk-stack-mariadb-1 mysql … < phase5a-luclin-a-implementation.sql`; capture before/after row counts | data-expert | **Not Started** | — |
| L10 | `#reloadworld` via Spire or world telnet port 9000. **Caveat:** `npc_spells_entries` DELETE may need akheva zone-process restart to flush spell list 196 cache (Phase 2 Cazic Touch DELETE worked with `#reloadworld` only — same pattern expected). | config-expert | **Not Started** | Phase 2 Decision #16 precedent — same DELETE-then-reload behavior. |
| L11 | Smoke verify: HP targets for Emperor (120k) / Lord Seru (120k MR=800) / Vyzh\`dra Cursed (90k) / Khati Sha (90k) / Doomshade (70k) / Thought Horror Overfiend (90k); **Q51=B Akheva elite-named** (Sheleric Vis 179133 35k/550, 179046 30k, Xaui 30k); **Q59=A Spiritual Arcanist 154153 40k**; respawn 24h on ~17-18 rows + **5 Akheva elite-named spawn2 rows preserved at 5400s**; **Touch of Vinitras DELETE list 196 only** (`SELECT COUNT(*) FROM npc_spells_entries WHERE npc_spells_id=196 AND spellid=2859` returns 0); **Shei Vinitras list 179 PRESERVED** (`SELECT COUNT(*) FROM npc_spells_entries WHERE npc_spells_id=179 AND spellid=2859` returns 1 per Decision #60); **Q52=B `#EmpCycle.pl:3` EDITED** (line reads `$EmpRepopTime = int(rand(7200)) + 79200;` — 22-24h); Spirit of Akelha\`Ra (179144) UNTOUCHED at 1M HP; vexthal NPCs (158081 + 158087-94) UNTOUCHED; OOE + event-control NPCs UNTOUCHED | config-expert | **Not Started** | — |
| L12 | Commit + push `claude/` repo changes (architecture doc, context files, status, implementation SQL) to `feature/raid-scaling` branch. `akk-stack/` and `eqemu/` untouched. | data-expert | **Not Started** | — |
| L13 | **Q52=B USER OVERRIDE — REQUIRED.** perl-expert edits `akk-stack/server/quests/ssratemple/#EmpCycle.pl:3` to change `$EmpRepopTime = int(rand(2880)) + 4320;` (3-5d) to `$EmpRepopTime = int(rand(7200)) + 79200;` (22-24h endgame tier). Verify Perl syntax (`perl -c #EmpCycle.pl`). Commit on akk-stack repo `feature/raid-scaling`. **DO NOT edit** `$BloodCoolDownTime` (3-4h failure cooldown preserved). | perl-expert | **Complete 2026-04-22** | Commit 2155bc1 on akk-stack feature/raid-scaling pushed. File force-added (server/ is gitignored — matches prior quest script commit pattern). perl -c syntax OK. |

**Required implementation agents (post-user-decisions 2026-04-25):** data-expert + config-expert + **perl-expert (L13 REQUIRED per Q52=B)** + **infra-expert (L10b CONTINGENT — single zone-process restart for akheva if `#reloadworld` doesn't flush spell list 196 cache)**.

### game-tester → user (Phase 5a Luclin non-VT server-side validation complete — in-game testing pending)
- **Date:** 2026-04-22
- **Server-side result:** PASS (117 checks)
- **Deliverables:**
  - `game-tester/luclin-a-server-validation.md` — 117-check validation report; all DB values confirmed
  - `game-tester/luclin-a-in-game-testing-guide.md` — 10 sessions in priority order (Touch of Vinitras cache flush → Emperor → Lord Seru → Vyzh`dra chain → Khati Sha → Shei Vinitras → Akheva elite-named → Umbral cluster → The Deep → Grieg's End)
- **Key notes:**
  - All 41 npc_types UPDATEs (45 in backup — 4 additional safety captures) confirmed in DB at architecture target values
  - All 21 spawn2 respawn timers confirmed at 86,400s (24h) for endgame content
  - CRITICAL safety confirmed: Spirit of Akelha`Ra (179144) at 1,000,000 HP unchanged; Emperor placeholder (162065) at 6,516 HP unchanged; all event-control NPCs unchanged; all vexthal NPCs (Phase 5b scope) unchanged
  - Touch of Vinitras DELETE confirmed: spell 2859 = 0 rows in list 196. List 179 (Shei Vinitras REAL) preserved with 1 row of spell 2859 per Decision #60
  - Emperor special_abilities `32,1,290` (Leash 290) preserved; Lord Seru MR=800 preserved
  - Perl edit L13 confirmed: `#EmpCycle.pl:3` reads `$EmpRepopTime = int(rand(7200)) + 79200;` (22-24h). Perl syntax OK
  - All preserved respawn timers intact: pre-Emperor 1080s, Rhozth pair 5400s/21600s, Shar Vinitras 10800s, Akheva elite-named (Q51) 5400s
  - Phase 2/3/4a/4b regressions clean: Nagafen 14,400, Vox 14,400, Trakanon 16,000, AoW 120,000, Vulak 150,000, Kerafyrm 3,500,000
  - Cazic Touch (spell 982) absent from all Phase 5a boss spell lists; 12 remaining instances are non-Phase-5a NPCs
  - No Phase 5a-related errors in server logs
  - Session 1 (Touch of Vinitras cache flush) MUST be done first — validates full-stack restart actually flushed spell list 196 from zone memory
- **Handoff to:** user for in-game testing execution (10 sessions)

### game-tester → user (Phase 4b server-side validation complete — in-game testing pending)
- **Date:** 2026-04-22
- **Server-side result:** PASS (127 checks)
- **Deliverables:**
  - `game-tester/velious-b-server-validation.md` — 127-check validation report; all DB values confirmed
  - `game-tester/velious-b-in-game-testing-guide.md` — 8 sessions in priority order (Vyemm → Aaryonar → Kildrukaun/Sleeper safety → MotG → Defender → Lendiniara → AoW → Vulak)
- **Key notes:**
  - All 51 npc_types UPDATEs confirmed in DB at architecture target values
  - All spawn2 respawn timers confirmed at 86,400s (24h) for endgame content
  - CRITICAL safety confirmed: Kerafyrm 128089/95 at 3,500,000 HP, The Sleeper 128094 at 3,500,000 HP, Thylex 124000 at 100 HP — all unchanged
  - Destroy spell (1948) confirmed in spell list 489 — Kerafyrm's death-touch preserved
  - Kerafyrm trio absent from backup table — Decision #12 boundary respected
  - spawn_condition_values: Warders dormant (cond1=0), Ancients live (cond2=1) — confirmed; note spawn_conditions.value column represents default-after-onchange state, not current runtime state
  - DT sweep clean: only Vyskudra Lightning Breath (-1,500 dmg, 12s recast, signature preserved per Decision #11)
  - MR signature mechanics confirmed: Vyemm/Telkorenar/Gozzrem MR=1000, Kildrukaun MR=400
  - AC signature mechanics confirmed: AoW AC=850, Vulak AC=950
  - Dagarn HP-regen flag (10^8) confirmed present; AoW rampage 6x6 (5,1^6,1) confirmed present
  - Defenders (Q37 override): all 4 at 45k HP / 550 maxdmg, respawn 16,200s unchanged
  - Backup table row counts: npc_types 51 rows (matches architecture), spawn2 62 rows (architecture estimated 46-49; difference from shared spawngroups, all correct Phase 4b rows)
  - Phase 2/3/4a regressions: all clean (Nagafen 14,400, Vox 16,000, Innoruuk 60,000, Trakanon 16,000, Klandicar 40,000, Yelinak 110,000, Derakor 60,000, Kromrif Captain 6,000)
  - No Phase 4b-related errors in server logs
  - NOTE: Sevalak (124075) maxdmg is 950 (not cut) — architecture did not specify a damage cap for Sevalak; the HP cut to 40k is the primary lever; 950 maxdmg is a NOTE, not a blocker
- **Handoff to:** user for in-game testing execution (8 sessions)

### architect → user (Phase 5a Luclin non-VT architecture complete; 3 user decisions required)
- **Date:** 2026-04-23
- **Deliverables:**
  - `architect/luclin-a-architecture.md` — full implementation plan, 37 npc_types UPDATEs + 1 DELETE + ~17-18 spawn2 respawn UPDATEs
  - `architect/context/luclin-a-db-investigation.md` — DB-grounded scope dossier (35 raid_target NPCs catalogued; 9 confirmed script-spawned with no spawn2; Khati Sha zone resolved = acrylia; Yaemiu confirmed vexthal-only Phase 5b; Va_Dyn_Khar + Akhevan Warders confirmed vexthal Phase 5b; OOE NPC filtering verified; Spirit of Akelha\`Ra Decision #30 precedent applied)
  - `agent-conversations.md` — full Phase 5a advisor exchanges (protocol-agent Q1-Q10 + 3 architect flags; config-expert pattern carryover; lore-master 17-question consult + 6-question follow-up — pending response)
- **Pattern:** SQL-only continuation of Phases 2/3/4a/4b. Zero C++/Lua/Perl/rule/config changes by default (perl-expert conditional only if user picks Decision #52 alternative).
- **Major scope realities:**
  - **9 of 35 in-scope bosses are SCRIPT-SPAWNED with no spawn2 row** — Emperor (162227), Blood (162189), Blood Golem (162064), all 3 Vyzh\`dra variants (162206/214/232), Arch Lich Rhag\`Zadune (162177), Rhag\`Mozdezh (162192), Doomshade (176088), Khati Sha (154145), Grieg main (163075). Pattern matches Phase 4b's AoW + Vulak (script-spawned) at 4× scale. Their cycle timers live in scripts; per Decision #11 NOT edited.
  - **Touch of Vinitras DT removal — single-row DELETE.** Spell 2859 (-20,000 HP, 0 mana, 0 cast, 120s recast) in spell list 196, used by Vyzh\`dra Exiled + Banished. Phase 2 Decision #16 precedent (Cazic Touch DELETE). Vyzh\`dra Cursed (list 197) clean.
  - **Shei Vinitras dual-form** (179032 REAL 690k + 179157 MERCHANT 400k) — both scaled per protocol-agent Flag B.
  - **Two newly-discovered raid_target=1 NPCs** (Decision #50): rune/glyph serpents 162253/162261 in ssratemple, audit-missed, part of `#cursed_controller.pl` chain orchestration per protocol-agent Flag C.
  - **Doomshade (176088, umbral, 350k HP) audit-missed** — added to scope (HP 70k target).
  - **Cross-era unblock complete:** Phase 4b Vulak`Aerr (150k) → Key to Luclin → Phase 5a Luclin progression.
- **User decisions required:**
  - **Decision #50** — Rune/glyph serpent inclusion (162253/162261, ssratemple): Option A (INCLUDE per protocol-agent Flag C, architect default) or Option B (exclude per Decision #2 elite-trash). +2 UPDATEs.
  - **Decision #51** — Akheva elite-named (Sheleric Vis 179133/179046, Xaui Tatrua 179044): Option A (EXCLUDE per Decision #2, architect default — same posture as Phase 4b Defenders pre-override) or Option B (include for scope consistency, akin to Phase 4b Q37 user override). +3-4 UPDATEs.
  - **Decision #52** — Emperor Ssraeshza cycle respawn (`#EmpCycle.pl:3` `$EmpRepopTime` 3-5 day): Option A (KEEP NATIVE per Decision #11 + #45 Thylex precedent, architect strongly recommends) or Option B (invoke perl-expert task L13 to soften to 22-24h endgame tier). +1 conditional Perl edit.
  - **Decision #59 (NEW 2026-04-25)** — A_Spiritual_Arcanist 154153 (acrylia, L68, 150k HP, raid_target=1, script-spawned, audit-missed): Option A (INCLUDE in Phase 5a scope, scale to 45k HP, architect default) or Option B (exclude pending lore-master deeper investigation). +1 UPDATE.
- **Lore-master Phase 5a sign-off received 2026-04-25:** APPROVED with Q1-Q17 comprehensive review. Decision #50 resolved Option A (joint architect+lore-master recommendation). Decision #60-62 added (Touch of Vinitras boundary, Khati Sha event SQL-safe, Vyzh`dra cycle trigger HP-independent). Five architect adjustments incorporated into architecture doc Addenda.
- **Required implementation agents (default path):**
  - **data-expert** — L1-L9, L12 (SQL emission, backup creation, apply, commit)
  - **config-expert** — L10-L11 (`#reloadworld` + smoke verify)
  - **(perl-expert)** — only if Decision #52 = Option B
- **Risks flagged:**
  - `#reloadworld` may not flush `npc_spells_entries` cache for spell list 196 in live akheva zone — contingent zone-process restart for akheva
  - Lord Inquisitor Seru MR=800 caster-wall preserved per Decision #11 (intentional friction for caster comps; same as Vyemm Phase 4b)
  - Lore-master sign-off pending — if findings shift Decisions #50 or Doomshade scope, addendum to architecture doc

- **Handoff to:** user for decisions #50/#51/#52 → orchestrator for implementation team dispatch

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

| 23 | Coldain Ring War (Q8) — Option A (accept-as-is, rejected), Option B (wave-skip +2 via Lua; ~7 effective waves; cadence preserved), Option C (reduce wave-mob HP alone), or Option D (Lever 1 SQL wave-mob HP + Lever 2 conditional Lua cooldown bump) | architect | user | **Resolved 2026-04-23 — REVISED** | Initial choice Option B; revised to **Option D** after lore-master's Ring War deep-dive landed post-decision. Lever 1 = SQL HP cuts on 8 Kromrif wave mobs (exclusive to greatdivide conditions 3-15) + Seneschal Aldikar safety bump; Lever 2 = conditional `ring_war.lua:26 wave_cooldown_time` 5min→8min if in-game testing shows Lever 1 insufficient. Preserves full 13-wave event structure. |
| 24 | Lord Yelinak duplicates (114106 500k / 114618 297k) both live per DB sweep — scale both to 110k HP (Option A, architect-recommended) or scale only main 114106 (Option B) | architect | user | **Resolved 2026-04-23** | Option A — scale both for consistency |
| 25 | Faction grind acceleration (CoV/Coldain/Kromzek three-way) | architect | user | **Resolved 2026-04-23** | Deferred out of Phase 4a scope (accept architect recommendation); revisit after user tests content |
| 26 | Ring 8 / Ring 9 failure-reset UX | architect | user | **Resolved 2026-04-23** | Deferred out of Phase 4a scope (accept architect recommendation); script-level UX, not scaling |

| 36 | Phase 4b: Warder scaling (128090/91/92/93 + Final Arbiter alt 128045) — Option A (scale to 60k HP, awake event reachable for small group with Kerafyrm consequence preserved, **architect + lore-master joint recommendation**) or Option B (leave at 200k HP, awake event mathematically unreachable for small group)? | architect | user | **Resolved 2026-04-23** | Option A accepted (joint architect+lore-master recommendation). 4 Warders 200k→60k + Final Arbiter alt 200k→60k. Kerafyrm trio untouched; awake chain preserved. User acknowledges the awake event becomes reachable for small group. |
| 37 | Phase 4b: Defender cluster (124050 Emerald / 124051 Sky / 124052 Onyx / 124079 Lava) — Option A (exclude per audit + Decision #2, architect-recommended) or Option B (include, scale 120k → 45-50k)? | architect | user | **Resolved 2026-04-23 — USER OVERRIDE** | Option B chosen. Architect originally recommended Option A (exclude); user overrode for scope consistency. Implementation targets (architect-specified per user request): HP 120k→45k, maxdmg 700→550, mindmg unchanged, respawn UNCHANGED at native 11,250-16,200s (3-5h), special_abilities preserved. +4 npc_types UPDATEs, +11 spawn2 backup rows. |
| 38 | Phase 4b: Lendiniara the Keeper (124020) — Option A (accept 24h endgame respawn per Decision #8, architect-recommended) or Option B (keep 12h mid-tier because of Sleeper's Tomb key talisman role)? | architect | user | **Resolved 2026-04-23** | Option A accepted (architect recommendation). Lendiniara 320k→80k HP, respawn 72h→24h endgame. Klandicar 40k/12h + Sontalak 40k/12h from Phase 4a remain as lower-gap alternatives for Sleeper's Tomb talisman acquisition. |

| 50 | Phase 5a: rune/glyph-covered serpents (162253 221k HP / 162261 300k HP, ssratemple, raid_target=1, audit-missed, part of `#cursed_controller.pl` chain) — Option A (INCLUDE per architect default, scale to 60k/70k HP) or Option B (exclude per Decision #2 elite-trash interpretation)? | architect | user | **Resolved 2026-04-25 (joint architect+lore-master recommendation)** | Option A INCLUDE. Lore-master Q2 confirmed: ALL Vyzh\`dra-related NPCs in ssratemple, cycle trigger = 7 Taskmasters + Mekuzh + 2 Rhozths within 1h → Glyph Serpent → Exiled → Cursed (recovery: Rune Serpent + Banished). Both 162253 + 162261 are raid_target=1 cycle gates and progression blockers if unkillable. |
| 51 | Phase 5a: Akheva elite-named (Sheleric Vis 179133/179046, Xaui Tatrua 179044, all 70-116k HP / 5400s respawn) — Option A (EXCLUDE per Decision #2 elite-trash, architect-recommended) or Option B (include for scope consistency, akin to Q37 user override)? | architect | user | **Resolved 2026-04-25 — USER OVERRIDE** | Option B chosen. Architect-specified targets: Sheleric Vis 179133 116k→35k HP, maxdmg 746→550; Sheleric Vis 179046 70k→30k HP, damage unchanged; Xaui Tatrua 179044 70k→30k HP, damage unchanged. Respawn UNCHANGED at native 5400s. +3 npc_types UPDATEs, +5 spawn2 backup rows. |
| 52 | Phase 5a: Emperor Ssraeshza cycle respawn (`#EmpCycle.pl:3` `$EmpRepopTime` 3-5 day) — Option A (KEEP NATIVE per Decision #11 + #45 Thylex precedent, architect-recommended) or Option B (invoke perl-expert task L13 to soften to 22-24h endgame tier)? | architect | user | **Resolved 2026-04-25 — USER OVERRIDE** | Option B chosen. perl-expert task L13 promoted from conditional to required. Edit: `#EmpCycle.pl:3` `$EmpRepopTime = int(rand(2880)) + 4320;` → `int(rand(7200)) + 79200;` (22-24h endgame tier per Decision #8). `$BloodCoolDownTime` (3-4h failure cooldown) UNCHANGED. |
| 59 | Phase 5a: A_Spiritual_Arcanist 154153 (L68, 150k HP, raid_target=1, acrylia, script-spawned) — Khati Sha event Phase 2 "wrong choice penalty" combat target per lore-master 2026-04-25. Option A (INCLUDE in Phase 5a, scale to 40k HP, joint architect+lore-master recommendation) or Option B (exclude — leave at 150k as harder penalty)? | architect | user | **Resolved 2026-04-25 (joint architect+lore-master recommendation)** | Option A INCLUDE. 154153 → 40k HP. 154151/154152 (raid_target=0 quest NPCs) remain OUT of scope. |

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
| BUG-001 | Phase 4a: Tunare combat boss (127098) unscaled — implementation targeted passive trigger NPC (127001) instead of killable combat NPC | High | game-tester | Resolved (2026-04-23) | data-expert | 2026-04-23 |

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

| 23 | Coldain Ring War lever — **Option D (Lever 1 SQL wave-mob HP cuts + conditional Lever 2 Lua cooldown bump)** — lore-master-endorsed | architect + lore-master | 2026-04-23 | Lore-master Q8 re-engagement: event has no overall timer, only per-wave cooldowns. SQL HP cuts make each wave tractable while preserving all 13 waves + Narandi + lore-consistent "epic multi-wave defense" feel. 8 Kromrif NPC IDs confirmed exclusive to greatdivide conditions 3-15 (zero static-zone ID-sharing). Narandi 150k→45k + Seneschal 10k→30k bump. Lever 2 (`wave_cooldown_time` 5min→8min at `ring_war.lua:26`) is conditional fallback only if game-tester shows ≥3 waves overlapping. Supersedes my original Option B+ wave-skip draft. |
| 24 | Lord Yelinak duplicates — scale both (Option A) recommended | architect | 2026-04-23 | DB sweep confirms both 114106 and 114618 are live with independent spawn2 rows. Consistency > partial scaling. |
| 27 | Phase 4a scope excludes AoW (113457) and Vulak`Aerr (124155); scope limited to non-ToV, non-Sleeper Velious content | architect | 2026-04-23 | Per Decision #4 phased delivery; AoW and ToV proper go to Phase 4b. Idol of Rallos Zek (113341) in scope as part of Kael chain; Statue→Idol→AoW chain completes in 4b. |
| 28 | Phase 4a introduces first Lua quest-script change in raid-scaling project | architect | 2026-04-23 | Coldain Ring War wave gate cannot be solved by SQL alone (it's a DPS-over-time gate, not a boss-HP gate). Lua change is required. lua-expert added to implementation team for first time. |
| 29 | No `npc_spells_entries` DELETEs needed for Phase 4a | architect | 2026-04-23 | DB sweep of Phase 4a in-scope bosses' spell lists vs death-touch profile (mana=0, cast_time=0, damage<=-10000): zero rows. Highest 0-cast damage spell is Kelorek Entomb in Ice (-1000, 18s recast) — signature mechanic, not death-touch. Keep per Decision #11. |
| 30 | Jaled Dar's Shade (3M HP uncombattable turn-in NPC) left untouched | architect | 2026-04-23 | Per lore-master Section 4 (velious-chains.md): intentional quest-NPC design. Client renders HP as percentage so 3M HP is visually indistinguishable from any other full-HP NPC to player. |
| 31 | Plane of Growth event-trigger NPCs (a_warm_light, a_thifling_focuser, #Lantaric`Dar) left untouched | architect | 2026-04-23 | Per audit and lore-master Section 6 guidance. Event-control NPCs, not kill targets. Protocol-agent confirmed no Titanium client anomaly from L1/1M HP combination. |
| 32 | **Wave count corrected from 21 to 13** per live script review | architect + lore-master | 2026-04-23 | Phase 1 audit cited P99 wiki's "21 waves" figure. Live `ring_war.lua:9-12` says 13 mob waves + Narandi = 14 conditions. DB confirmed via spawn_conditions 3-16. All Phase 4a docs use 13-wave structure. |
| 33 | **lua-expert needed CONDITIONALLY only** — Phase 4a default is SQL-only | architect + lore-master | 2026-04-23 | Default Phase 4a implementation team is data-expert + config-expert (identical to Phases 2/3). lua-expert only invoked if Lever 2 (one-line `wave_cooldown_time` edit) is triggered by game-tester validation AND approved by user. This is simpler than my draft (which had lua-expert primary on V5-V6). |
| 34 | **Kromrif wave-mob HP cuts acceptable under Decision #2** per lore-master Q8 | architect + lore-master | 2026-04-23 | Decision #2 (trash/named untouched) applies to standing-zone content, not scripted event waves. Kromrif wave mobs are event-trash within a raid event. 8 NPC IDs confirmed exclusive to greatdivide conditions 3-15 — zero impact on static zone content. Lore-master explicitly endorses this scoping. |
| 35 | **Seneschal Aldikar HP bump 10k→30k** — fail prevention | architect + lore-master | 2026-04-23 | Seneschal death fails the Ring War event. At 10k HP, AOE overflow during wave cooldowns could nuke him. 30k HP provides belt-and-suspenders margin. Per lore-master flag (2026-04-23). |
| 36 | **Phase 4b: Warder scaling** — architect + **lore-master joint recommendation** (Option A: scale 4 Warders + Final Arbiter alt to 60k HP). Kerafyrm trio untouched per Decision #12; awake event becomes reachable for small group if GM flips condition 1; event consequence (Kerafyrm 3.5M HP + Destroy death-touch) preserved. | architect + lore-master | 2026-04-23 | Lore-master Q1 (2026-04-23) confirmed Decision #12 means Kerafyrm himself + trigger scripts stay untouched — not an artificial Warder barrier. Scaling Warders is the lore-correct way to make the Sleeper's Tomb climax reachable for a small group. **USER APPROVAL REQUIRED (acknowledgment, not technical choice).** |
| 37 | **Phase 4b: Defenders (124050/51/52/79) excluded.** Architect recommends Option A (exclude per audit line 1673-1677 + Decision #2 "trash/named untouched"). 4 NPCs at 120k HP / 3-5h respawn are raid_target=1 but elite-trash-tier. | architect | 2026-04-23 | Consistent with Phase 2 "Night Crew" exclusion pattern. **USER APPROVAL REQUIRED.** |
| 38 | **Phase 4b: Lendiniara the Keeper (124020) endgame respawn tier (24h).** Architect recommends Option A (accept 24h per Decision #8 endgame tier). Lendiniara is CoV-faction Sleeper's Tomb key talisman source but Phase 4a alternatives (Klandicar 40k/12h, Sontalak 40k/12h) remain as lower-gap paths. | architect | 2026-04-23 | Tier consistency wins over key-path convenience. **USER APPROVAL REQUIRED.** |
| 39 | **Phase 4b is 100% SQL — no C++, Lua, Perl, spell-list, rule, or config changes.** | architect | 2026-04-23 | Same pattern as Phases 2/3/4a default. Three tables touched: `npc_types` (47 UPDATEs), `spawn2` (~32 UPDATEs), backup tables. `special_abilities` CSV untouched — signature mechanics (Vyemm/Telkorenar/Gozzrem MR=1000 walls, Dagarn HP-regen, Vyskudra Lightning Breath, MotG 8-sentry wave, Ancient Kerafyrm-alive depop, Aaryonar breath, AoW rampage 6×6 capped globally) all preserved. |
| 40 | **Kerafyrm awake chain verified HP-independent.** Full code trace of 4 Warder `.pl` files + `#The_Sleeper.pl` + `#Kerafyrm.pl` confirms trigger uses `GetMobByNpcTypeID()` presence checks + `quest::signalwith(128094, 66)`, NEVER HP thresholds. Scaling Warder HP cannot accidentally fire the event. | architect | 2026-04-23 | Evidence in `architect/context/velious-b-db-investigation.md` §2. Sleeper Awake Event Boundary formally validated for Phase 4b dispatch. |
| 41 | **Vulak altar-summon verified entity-presence-based, not HP-threshold.** `#Thylex_of_Veeshan.pl` 60s tick checks all 6 altar dragons (Mirenilla/Nevederia/Feshlak/Aaryonar/Kreizenn/Vyemm) absent, then `quest::spawn2(124155)` with `vulak` qglobal 6-min cooldown. Presence check unaffected by HP scaling. | architect | 2026-04-23 | No script edit needed to propagate Vulak accessibility. |
| 42 | **Vulak trigger list correction:** audit's "six altars" is INCORRECT. Actual trigger is 6 North Wing Lords/Ladies — Aaryonar (124010), Mirenilla (124077), Nevederia (124076), Feshlak (124008), Kreizenn (124074), Vyemm (124017). **Lord Koi`Doken (124103) is NOT a Vulak trigger.** No altar system exists. | architect + lore-master | 2026-04-23 | Verified via `#Thylex_of_Veeshan.pl` DB-backed spawn coordinator script. Matches lore-master Q2 2026-04-23 finding. Koi`Doken is still a Phase 4b boss scaled in his own right (580k HP → 130k) but his kill does not contribute to Vulak summoning. |
| 43 | **Aaryonar assist-link preservation required.** Aaryonar (124010) is assist-linked to all other NToV dragons — must be pulled first or he assists others being engaged. Structural pull-order mechanic (AI behavior, not HP). Phase 4b MUST NOT touch behavior flags that control this. | architect + lore-master | 2026-04-23 | Per lore-master Q9 (2026-04-23). Phase 4b only touches `npc_types.hp/mindmg/maxdmg` columns; `npc_aggro` / `assistradius` / `npc_faction_id` / `special_abilities` behavior columns untouched. Validation plan adds post-scale Aaryonar assist-link smoke test. |
| 44 | **East Wing quest-drop dependency confirmed LORE-ENDORSED for Phase 4b scaling.** Dozekar the Cursed (124037) drops **Tears** + Midayor-cluster named (124030-040) + other mid-tier named drop **Symbols** for Halls of Testing → Skyshrine armor turn-ins. Under-scaling would break armor progression. Phase 4b's 40-50k HP cuts on 16 NToV mid-tier named are REQUIRED and validated. | architect + lore-master | 2026-04-23 | Per lore-master Q6 (2026-04-23). Decision #3 preserves loot tables (Tears + Symbols drop rates unchanged). Turn-in NPCs: Gozzrem (124105), Lendiniara (124020), Telkorenar (124104). |
| 45 | **Thylex of Veeshan (124000) respawn exception.** Thylex's 258,000s (~71.67h) respawn is mechanically load-bearing for Vulak re-engagement post-Vulak-death. **Do NOT update to 24h.** DB-verified Thylex is already out of Phase 4b respawn UPDATE list. | architect + lore-master | 2026-04-23 | Per lore-master Q10 (2026-04-23). Thylex is a L10 100 HP coordinator NPC with special_abilities immunity flags (19/20/24/25/35) — untouched in Phase 4b entirely. |
| 46 | **Q36 resolved — Option A (scale 4 Warders + Final Arbiter alt 200k → 60k HP).** Joint architect + lore-master recommendation accepted. User acknowledges the Sleeper Awake event becomes reachable for small group; Kerafyrm trio (128089/94/95) and Destroy death-touch spell remain untouched per Decision #12. | user | 2026-04-23 | Accepted joint recommendation. |
| 47 | **Q37 resolved — Option B (INCLUDE Defenders 124050/51/52/79) via USER OVERRIDE.** Architect originally recommended Option A (exclude per audit + Decision #2); user chose Option B for scope consistency with the 16 NToV mid-tier named. Architect-specified targets: HP 120k → 45k, maxdmg 700 → 550, mindmg unchanged, respawn UNCHANGED at native 11,250-16,200s (3-5h), special_abilities flags (5 summon + 90 assist + standard raid immunities) preserved. | user + architect | 2026-04-23 | +4 npc_types UPDATEs, +11 spawn2 backup rows. Total Phase 4b npc_types UPDATEs: 51 (was 47). Respawn UPDATE count unchanged at ~32 rows. |
| 48 | **Q38 resolved — Option A (Lendiniara 124020 accepts 24h endgame respawn).** Architect recommendation accepted. Lendiniara 320k → 80k HP, respawn 72h → 24h endgame. Alternative Sleeper's Tomb talisman paths (Klandicar/Sontalak 40k HP / 12h respawn from Phase 4a) remain as lower-gap options. | user | 2026-04-23 | Accepted architect recommendation. |
| 49 | **Defender scaling targets specified** (architect decision per Q37 Option B user override): HP 45k (between Midayor L60 40k and Cyndor L65 50k band — L65 Defender sits at lower end), maxdmg 550 (same as post-scale NToV L65-66 mid-tier named Cyndor/Yrrindor/Kalkar), mindmg 225 unchanged, respawn unchanged at native 3-5h (below Decision #8 endgame 24h — a bump would over-extend natural farm-tier cadence), special_abilities unchanged per Decision #11. | architect | 2026-04-23 | Chosen to align Defenders with the NToV mid-tier named band while preserving their native short-respawn farmable character. |
| 50 | **Phase 5a: rune/glyph serpents — RESOLVED Option A INCLUDE (joint architect+lore-master recommendation 2026-04-25).** Per protocol-agent Flag C + lore-master Q2: 162253 (Rune-Covered Serpent, 221k HP) is recovery-chain stage 1; 162261 (Glyph-Covered Serpent, 300k HP) is cycle stage 1; both raid_target=1 cycle gates. Cycle trigger = kill 7 Taskmasters + Warden Mekuzh + 2 Rhozths within 1 hour → Glyph Serpent → Exiled → Cursed (or Rune Serpent + Banished recovery). Both must be scaled — progression blockers if unkillable. Phase 5a target: 162253 → 60k HP; 162261 → 70k HP. | architect + lore-master | 2026-04-25 | Joint recommendation accepted as architecture default. **USER FINAL APPROVAL REQUIRED to confirm.** |
| 51 | **Phase 5a: Akheva elite-named architect-recommends EXCLUDE.** Sheleric Vis (179133 116k HP / 179046 70k HP variant) and Xaui Tatrua (179044 70k HP) at 5400s respawn are elite-named tier per Decision #2. Same posture as Phase 4b Defenders pre-Q37-override. User can override for scope consistency. | architect | 2026-04-23 | **USER APPROVAL REQUIRED.** |
| 52 | **Phase 5a: Emperor Ssraeshza cycle respawn architect-strongly-recommends KEEP NATIVE.** `#EmpCycle.pl:3` `$EmpRepopTime = int(rand(2880)) + 4320` (3-5 day post-kill respawn) is Perl local variable, not SQL-tunable. Per Decision #11 + #45 (Thylex precedent), script-driven cycle timers preserved. Alternative Option B invokes perl-expert task L13 (one-line edit to 22-24h). 3-5 day cadence is signature pinnacle-event feel. | architect | 2026-04-23 | **USER APPROVAL REQUIRED.** |
| 53 | **Phase 5a is 100% SQL — no C++, no Lua, no Perl edits in default path.** Same pattern as Phases 2/3/4b. Three tables touched: `npc_types` (37 UPDATEs), `spawn2` (~17-18 UPDATEs), `npc_spells_entries` (1 DELETE), backup tables. `special_abilities` CSV untouched — signature mechanics (Lord Seru MR=800, Emperor Leash 290 + 30/40-min timers + add waves, Vyzh\`dra trio chain orchestration, Shei Vinitras dual-form, Khati Sha behaviors, Doomshade behaviors, Grieg cycle, all Rhag lich line spells, Praesertum cluster, Itraer Vius, Insanity Crawler, Va\`Dyn) all preserved. | architect | 2026-04-23 | Confirmed by protocol-agent Q1-Q10 and config-expert pattern carryover (both 2026-04-22). |
| 54 | **Touch of Vinitras DT removal — Phase 5a applies Decision #16 / Decision #13 precedent.** Spell 2859 (-20,000 HP, 0 mana, 0 cast, 120s recast) in npc_spells_entries list 196 used by Vyzh\`dra Exiled (162232) and Vyzh\`dra Banished (162214). DELETE 1 row from npc_spells_entries; backup table captures pre-DELETE state. List 197 (Vyzh\`dra Cursed) is clean. | architect | 2026-04-23 | Same pattern as Phase 2 Cazic Touch DELETE (Decision #16). |
| 55 | **Khati Sha the Twisted (154145) zone confirmed = acrylia.** Audit listed her zone as "grimling?" (with question mark). DB has no spawn2 row for 154145; quest script `Khati_Sha_the_Twisted.lua` lives in `akk-stack/server/quests/acrylia/`. Confirmed acrylia. No VT variant exists. Phase 5a scope (not Phase 5b). | architect + protocol-agent | 2026-04-23 | Resolves audit's open question. |
| 56 | **Doomshade (176088, umbral, L66 350k HP, raid_target=1, script-spawned) added to Phase 5a scope.** Audit-missed; lore-master `luclin-chains.md` Section 5 flagged "Umbral Plains hosts Doomshade." Architect adds with HP target 70k (mid-band between Servitor 40k and Khati Sha 90k). | architect | 2026-04-23 | Lore-master Q10 (response pending) covers any Doomshade-specific quest dependency. |
| 57 | **Spirit of Akelha\`Ra (179144, akheva, L65 1M HP, raid_target=1) UNTOUCHED.** VT-key turn-in NPC per `luclin-chains.md` Section 1. Decision #30 precedent (Jaled Dar's Shade left untouched as quest turn-in NPC; client renders HP as percentage). Excluded from Phase 5a SQL scope. | architect | 2026-04-23 | Same posture as Phase 4a Decision #30. |
| 58 | **Phase 5a/5b boundary confirmed:** Vex Thal proper (Aten Ha Ra, Diabo trio, Thall Va tier, 158xxx ID range), Yaemiu elite trash (vexthal-exclusive, ~80 mobs), Va_Dyn_Khar (158081, vexthal), Akhevan Warders (158087-94, vexthal — name-misleading but VT-zoned per DB), and 13-shard VT key rework all defer to Phase 5b. Khati Sha (154145, acrylia) belongs in Phase 5a. | architect + protocol-agent + config-expert | 2026-04-23 | All advisors confirmed boundary 2026-04-22. |
| 59 | **A_Spiritual_Arcanist 154153 (acrylia, L68, 150k HP, raid_target=1, script-spawned, no spawn2) — REFINED per lore-master 2026-04-25.** She is the Khati Sha event Phase 2 "wrong choice penalty" combat target, NOT one of the three outer AC raids. Per `#Raidman.lua`: spawned with Arcanist V1 (154151) + V2 (154152) — player picks via `/tar a_spiritual_arcanist00`; wrong choice → fight 154153 (right choice → she's a quest-NPC turn-in). 154151/154152 (75k HP, raid_target=0) remain OUT of scope (quest NPCs). Phase 5a HP target: **150k → 40k** (joint architect+lore-master recommendation). | architect + lore-master | 2026-04-25 | **USER APPROVAL REQUIRED.** |
| 60 | **Touch of Vinitras spell 2859 boundary CONFIRMED** — DELETE scoped to (npc_spells_id=196 AND spellid=2859) ONLY. Cross-check during lore-master review revealed spell 2859 also appears in list 179 (Shei Vinitras REAL 179032). Per lore-master Q15: Shei's Touch of Vinitras (DT on initial aggro + every 2 minutes, 120s recast) is INTEGRAL to her identity per live-era sources — PRESERVE. Vyzh\`dra Exiled/Banished list 196 instance has no signature role and is removed per Decision #54. | architect + lore-master | 2026-04-25 | Validation Plan §"No npc_spells_entries changes" expanded: smoke test confirms list 179 row for spell 2859 STILL EXISTS post-DELETE. |
| 61 | **Khati Sha 2-phase event verified SQL-safe — no lua-expert required.** Architect script audit (Khati_Sha_the_Twisted.lua) confirmed 2-phase event: Phase 1 combat-engage spawns 4× Defiled Minion (154054, 5k HP); Phase 2 player crosses y=-545 → Khati Sha depops/respawns inside chamber + 4× a_diseased_grimling (154129, 9.5k HP); 2-hour timer. All add NPCs are elite-trash per Decision #2. Khati Sha HP cut (475k→90k) is HP-independent of script logic. | architect | 2026-04-25 | Lore-master Q12 caveat ("may need lua-expert conditional") resolved as NOT NEEDED. |
| 62 | **Vyzh\`dra cycle trigger verified HP-independent.** 10-mob kill count trigger (7 Taskmasters + Warden Mekuzh + 2 Rhozths within 1 hour, per #cursed_controller.pl + lore-master Q2) fires on entity-death events, not HP thresholds. Phase 5a HP cuts on Rhozth pair (Ssrakezh 119k→40k, Ssravizh 105k→38k) preserve cycle trigger logic. Taskmasters and Warden Mekuzh remain OUT of Phase 5a scope (elite-tier per Decision #2). | architect + lore-master | 2026-04-25 | Cycle trigger preserved. |
| 63 | **Q51 RESOLVED — Option B INCLUDE Akheva elite-named (USER OVERRIDE).** User chose scope consistency over architect's EXCLUDE default — same Q37 Defender override pattern. Architect-specified targets per named-tier-but-included philosophy: Sheleric Vis 179133 (116k → 35k HP, maxdmg 746 → 550, mindmg 176 unchanged), Sheleric Vis 179046 variant (70k → 30k HP, damage 59/173 unchanged), Xaui Tatrua 179044 (70k → 30k HP, damage 110/376 unchanged). Respawn UNCHANGED at native 5400s. special_abilities UNCHANGED per Decision #11. +3 npc_types UPDATEs + 5 spawn2 backup rows. | user + architect | 2026-04-25 | Total Phase 5a npc_types UPDATEs: 41 (was 38). |
| 64 | **Q52 RESOLVED — Option B SOFTEN Emperor cycle (USER OVERRIDE).** User chose Decision #8 endgame respawn tier alignment (22-24h) over architect's KEEP NATIVE recommendation (3-5d signature). perl-expert task L13 promoted from conditional to required. Edit: `akk-stack/server/quests/ssratemple/#EmpCycle.pl:3` `$EmpRepopTime = int(rand(2880)) + 4320;` (3-5d) → `$EmpRepopTime = int(rand(7200)) + 79200;` (22-24h). Companion `$BloodCoolDownTime` (3-4h failure cooldown) UNCHANGED — preserves raid attempt cadence. | user + architect | 2026-04-25 | First Phase 5a Perl script edit. perl-expert added to implementation team. |
| 65 | **Q59 RESOLVED — Option A INCLUDE Spiritual Arcanist (joint architect+lore-master).** A_Spiritual_Arcanist 154153 (Khati Sha event Phase 2 wrong-choice penalty, L68, 150k HP, raid_target=1, script-spawned via `#Raidman.lua`) scaled to 40k HP. 154151 V1 + 154152 V2 (75k HP, raid_target=0 quest NPCs in succeed path) remain OUT of scope. | user + architect + lore-master | 2026-04-25 | Joint recommendation accepted. |
| 66 | **Phase 5a Lua/Perl edit count = 1** (was 0 default). Q52=B introduces a single one-line Perl edit at `#EmpCycle.pl:3`. All other scripts untouched per Decision #11 (Vyzh\`dra chain, Khati Sha event, Doomshade, Grieg cycle, Shei dual-form spawn-swap, Lord Seru placeholder swap, Rhag cycle, EmpCycle state machine logic except respawn timer, Emperor real boss script, Blood/Blood Golem scripts). | architect | 2026-04-25 | Confirms Phase 5a is no longer "100% SQL" — but the Perl edit footprint is minimal and scoped to a single tunable variable. |

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
