# Raid Scaling — Architecture & Implementation Plan (Phase 5b: Luclin VT — FINAL PHASE)

> **Feature branch:** `feature/raid-scaling`
> **PRD:** `game-designer/prd.md`
> **Audit:** `game-designer/raid-scaling-audit.md` (Vex Thal section lines 2166-2253; cross-era VT-key correction lines 2407-2428)
> **Lore catalog:** `lore-master/luclin-chains.md` (all 9 sections — VT key Phase 1=10 Lucid Shards is canonical)
> **Phase 2 reference:** `architect/architecture.md` (Classic — pattern)
> **Phase 3 reference:** `architect/kunark-architecture.md`
> **Phase 4a reference:** `architect/velious-a-architecture.md`
> **Phase 4b reference:** `architect/velious-b-architecture.md` (most-recent prior endgame tier — DT preserve precedent for Kerafyrm Destroy)
> **Phase 5a reference:** `architect/luclin-a-architecture.md` (most-recent pattern; Luclin non-VT closed)
> **DB investigation:** `architect/context/luclin-b-db-investigation.md`
> **Author:** architect
> **Date:** 2026-04-25
> **Status:** **READY FOR USER DECISIONS — 3 of 3 advisor sign-offs CONFIRMED 2026-04-25.** config-expert CONFIRMED (initial + deep 12-Q; LB13b zone-restart REQUIRED for Q67=B DELETE — promoted to default). protocol-agent CONFIRMED (zero protocol impact + PBAE DT flag → Q67 default reversed to DELETE; **Q12 spawn2-zone disagreement OPEN** pending re-verify — architect's 2 independent DB queries show all 1,089 rows in vexthal). lore-master CONFIRMED (VT deep-dive APPROVED with 3 DB-disagreed flags pushed back via DB evidence). Three user-decision items surfaced (Q67 Aten Destroy DT disposition [architect default now DELETE per protocol-agent PBAE finding], Q68 burrower-parasite Phase 5a leak, Q69 13-shard briefing correction). Ready for lore-master sign-off + user decisions, then implementation dispatch.
> **Scope:** **Phase 5b ONLY — FINAL PHASE OF PROJECT.** Vex Thal proper (vexthal zone): Aten Ha Ra dual-form (158006/158096), 9 inner-VT bosses (158007-015), Thall Va Xakra dual (158016/158125), Va_Dyn_Khar (158081, drops Palace Key), 6 Akhevan Warders (158087/88/89/90/91/94 — script-spawned ADDS, NOT 8 as briefing assumed), 104 Yaemiu elite trash mobs (per Q4=A user decision). PLUS one Phase 5a audit-leak: A_burrower_parasite (164089, thedeep, 840k HP, Glowing Orb of Luclinite dropper). Touch of Vinitras DT not present in vexthal — only DT in zone is `Destroy` spell 1948 in list 229 (used by 158006 "Destroy Aten" form, script-gated by Aten_Trigger).

---

## Executive Summary

Phase 5b closes the raid-scaling project by scaling Vex Thal proper — the deepest raid zone in the entire game. **This is the final implementation phase.** Aten Ha Ra at 1,901,500 HP is the **63× scaled-named gap** flagged in the original audit (the largest in the project).

The phase preserves the **same SQL-only pattern established in Phases 2/3/4a/4b/5a** with one decision-point variant: the disposition of spell 1948 "Destroy" (-100,000 HP DT) in spell list 229 used by the "Destroy Aten" form (158006). Unlike Phase 4b Kerafyrm (Decision #12 PRESERVE Destroy as awake-event punishment) and Phase 5a Touch of Vinitras (Decision #16/#54 DELETE the Vyzh\`dra-list-196 instance, PRESERVE the Shei-list-179 instance), the Aten Destroy is **script-gated** — the Aten_Trigger script (158095) only spawns the Destroy form (158006) when other VT bosses are still alive; otherwise it spawns the safe non-Destroy form (158096). This shifts the user-decision: "remove the DT explicitly" vs "leave the DT and rely on the script gate."

**Five significant differences from Phase 5a:**

1. **The single largest HP cut in the project.** Aten Ha Ra dual at 1,901,500 → architect target **180k** (90.5% cut, mirroring audit's `-91%` recommendation). Kaas Thox Xi Aten Ha Ra at 1,900,000 + 1,650 max dmg → **160k + 800 max** (92% cut + 51% damage trim). These are the single hardest fights in the game.

2. **First Phase since Phase 2/Decision #16 to face a -100,000 DT spell — and the FIRST PBAE DT in the project.** Spell 1948 "Destroy" appears in only one VT spell list (229 = "Destroy Aten" 158006). It is the SAME spell ID as Kerafyrm's Destroy (Phase 4b Decision #12 — PRESERVE) but with one critical difference: Aten Destroy is **targettype=4 PBAE** (per protocol-agent 2026-04-25), whereas Cazic Touch + Touch of Vinitras + Kerafyrm's Destroy are all targettype=5 single-target. PBAE wipes the entire 1-3 player group simultaneously — no recovery state. Architect default flipped 2026-04-25 to **DELETE** (Decision #16/#54 precedent — selective DT removal where DT is small-group-blocker not signature mechanic). Q67 user decision still surfaces but architect now defaults to Option B.

3. **Major add-wave architecture.** The 6 Akhevan Warders (158087/88/89/90/91/094) are NOT standing spawns — they're **script-summoned by 6 specific Diabo/Thall boss .pl files**, totaling **45 Warder summons across the zone when all bosses are up**. Phase 5b cuts Warder HP from 901k → ~80-90k (mirrors Phase 5a 158087-094 audit-flag noting "vexthal-zoned despite Akhevan name"). **This is the biggest small-group play unblocker in the phase** — Va_Xi_Aten_Ha_Ra alone summons 14 Warders at 901k HP each on engage.

4. **Dual-ID forms across two separate boss-pairs.** Aten Ha Ra (158006/158096) and Thall Va Xakra (158016 south + 158125 north). Aten dual is script-driven (DT-gate); Thall Va Xakra dual is wing-positional (south/north). Both forms get full HP cuts (90% / 91% respectively).

5. **Briefing inconsistency surfaced.** User briefing said "13-shard VT key quest." DB query + lore-master canonical research confirm **10 Lucid Shards + 3 components = 13 component items total, but only 10 are formally "shards"**. All 10 shards drop from non-raid mobs (sub-15k HP, raid_target=0); 2 of 3 component items (Frame + Planes Rift + Glowing Orb) are already addressed by Phase 5a. **Phase 5b does NOT need to scale shard sources** — they're already accessible. **Architect surfaces as user-decision Q69** (preserve "13" framing as 10+3, vs explicit acknowledgment that there are only 10 shards).

**Change footprint:**
- **~125 `npc_types` HP/damage UPDATEs** — 13 inner bosses + 6 Akhevan Warders + 1 Va_Dyn_Khar + 104 Yaemiu trash + 1 burrower-parasite (Q68=A architect default) = 125. Subset breakdown: Aten dual (2) + 9 inner-VT bosses + Thall Va Xakra dual (2) + Va_Dyn_Khar + Warders (6) + Yaemiu (104) + burrower (1).
- **~12 `spawn2.respawntime` UPDATEs** to 86,400s (24h endgame) — 9 inner-VT bosses (158007 has 2 rows, others 1 each = 10 rows) + 2 Thall Va Xakra rows = 12 rows. Va_Dyn_Khar at 21,600s preserved (already 6h short-tier; Palace Key cycle).
- **1 `npc_spells_entries` DELETE** (default per Q67 reversal 2026-04-25) — spell 1948 Destroy from list 229 only. List 489 (Kerafyrm Decision #12) untouched. List 540 (Aten 158096 non-Destroy form) untouched.
- **0 script edits required by default** — `#Aten_Ha_Ra.pl`, `#Aten_Ha_Ra_.pl`, `#Aten_Trigger.pl`, the 6 Diabo/Thall warder-control scripts, `158016.lua`, `158125.lua` all preserve verbatim per Decision #11.
- Backup tables: `npc_types_backup_raid_scaling_luclin_b` (~125 rows), `spawn2_backup_raid_scaling_luclin_b` (~110 rows incl. trap respawn rows for safety), `npc_spells_entries_backup_raid_scaling_luclin_b` (0-1 rows depending on Q67).

**No C++ changes. No `rule_values` changes. No `eqemu_config.json` changes. No `.env` changes. No Lua edits. No Perl edits by default.** SQL-only changes + infra-expert vexthal zone-restart required for spell list 229 cache flush post-DELETE (per config-expert Q7 2026-04-25; same pattern as Phase 2 + Phase 5a).

**User decisions surfaced 2026-04-25 (Phase 5b):**
- **Q67 — Aten Destroy DT disposition:** Option A (PRESERVE the spell 1948 row in list 229; rely on Aten_Trigger script-gate) — architect default. Option B (DELETE the row entirely; Decision #16 precedent for absolute safety).
- **Q68 — A_burrower_parasite Phase 5a audit-leak:** Option A (INCLUDE in Phase 5b's npc_types UPDATE batch — one extra row, project-closure clean) — architect default. Option B (defer to a Phase 5a fixup ticket post-project).
- **Q69 — VT key "13-shard" briefing correction:** Option A (acknowledge: it's 10 Lucid Shards + 3 components = 13 items total; no scaling action required because Phase 1 sources are non-raid and Phases 2-4 are addressed in Phase 5a). Option B (deeper investigation if user intended something other than what the lore-master canonical says).

---

## Existing System Analysis

### Current State

**Phases 2, 3, 4a, 4b, 5a all landed and validated.** Phase 5a accepted 2026-04-25 (server-side PASS 117 checks; user accepted). **This is the final phase of the entire raid-scaling project.**

**Prior-pass globals remain authoritative and unchanged:**
- `NPCFlurryChance=12`, `MaxRampageTargets=2`, `NPCAssistCap=3`, `StartEnrageValue=5`, `GlobalLootMultiplier=2`, `CurrentExpansion=3`, `AllowRaidTargetBlind=false`
- `rule_values` count: **1,112** (re-verified by config-expert Phase 5a — pending Phase 5b reconfirmation)
- `zone.ruleset=1` (default) for `vexthal` per DB confirmation. expansion=3 (Luclin). No DZ/instancetype.

**Phase 5b content at PEQ defaults** per audit + DB confirmation:

**Vex Thal — Aten Ha Ra dual-form (script-spawned):**
- **158006 #Aten_Ha_Ra "Destroy form" (L66, 1,901,500 HP, 294-1054 dmg, MR 162, spell list 229 INCLUDING Destroy 1948 -100k DT, special_abilities flag rampage 13 = 13,1 enabled).** Spawned by Aten_Trigger when ANY of the 9 gating bosses (158007/008/009/010/011/012/013/014/015) is still up. Has 1s `atenha` self-depop timer if `qglobals.aten` is set.
- **158096 #Aten_Ha_Ra_ "non-Destroy form" (L66, 1,901,500 HP, 294-1054 dmg, MR 144, spell list 540 = Word of Command self-heal +3000, Silence, Fling — NO Destroy).** Spawned by Aten_Trigger when ALL 9 gating bosses are dead. Has 172,800s (48h) self-depop timer.
- **158095 #Aten_Trigger (L90, 50,000,000 HP, raid_target=0, spawn2-backed at 259,200s = 72h, single spawn at 1153.3,-0.4,235.3) — controller NPC.** EXCLUDED.

**Vex Thal — 9 gating-tier inner bosses (spawn2-backed, 130h respawn):**

| ID | Name | L | HP | mindmg-maxdmg | special_abilities | Notes |
|---|---|---|---|---|---|---|
| 158007 | #Kaas_Thox_Xi_Aten_Ha_Ra | 66 | 1,900,000 | 320-**1650** | SERQMCNIDf | DAMAGE OUTLIER. 2 spawn2 rows. |
| 158008 | #Thall_Va_Kelun | 66 | 1,825,000 | 240-1000 | SRQMCNIDf | Spawns Akhevan Warder 158090 ×2 |
| 158009 | #Va_Xi_Aten_Ha_Ra | 66 | 1,601,500 | 304-1254 | SERQMCNIDf | Spawns Akhevan Warder 158094 ×14 (heaviest add wave) |
| 158010 | #Diablo_Xi_Va_Temariel | 66 | 1,706,000 | 165-**1400** | SRFMCNIDf | DAMAGE OUTLIER. Spawns 158091 ×5 |
| 158011 | #Thall_Xundraux_Diabo | 66 | 1,475,000 | 274-654 | SERFQUMCNIDf (rampage 20) | Spawns 158091 ×5 (shared pool with 158010) |
| 158012 | #Diabo_Xi_Xin_Thall | 66 | 1,501,500 | 180-750 | SRTMCNIDfU (rampage 20) | Spawns 158089 ×7 |
| 158013 | #Kaas_Thox_Xi_Ans_Dyek | 66 | 1,201,500 | 270-650 | SEFQUMCNIDf (rampage 15) | Spawns 158087 ×2 |
| 158014 | #Diabo_Xi_Va | 66 | 1,050,000 | 274-654 | SRFUMCNIDf | Spawns 158088 ×5 |
| 158015 | #Diabo_Xi_Xin | 66 | 1,106,500 | 250-**1200** | SERMCNIDf (rampage 25) | DAMAGE OUTLIER. Spawns 158088 ×5 (shared pool with 158014) |

**Vex Thal — Thall Va Xakra dual (zone-trash boss tier, 39h respawn):**
- **158016 #Thall_Va_Xakra (south)** L60, 900k HP, 285-950 dmg, spell list 233, train-pull adds via `158016.lua` (27 spawn IDs).
- **158125 #Thall_Va_Xakra (north)** L60, 900k HP, identical, train-pull via `158125.lua` (27 different spawn IDs for north wing).

**Vex Thal — Va_Dyn_Khar (key-drop boss):**
- **158081 Va_Dyn_Khar (L66, 600,000 HP, 265-455 dmg, spawn2-backed at 21,600s = 6h short-tier, spell list 0)** — drops **Palace Key (item 8010)** which gates door 8010 (the only keyed door in vexthal). 6h respawn preserves Palace Key cycle.

**Vex Thal — 6 Akhevan Warder add-wave NPCs (script-summoned only):**

| ID | Name | L | HP | mindmg-maxdmg | special_abilities | Spawned by | Count |
|---|---|---|---|---|---|---|---|
| 158087 | Akhevan_Warder | 60 | 901,000 | 0-4 | QUMCNIDABfWO | 158013 | 2 |
| 158088 | Akhevan_Warder | 60 | 901,000 | 0-4 | QUMCNIDABfWO | 158014 + 158015 (shared pool) | 5 each |
| 158089 | Akhevan_Warder | 60 | 901,000 | 0-4 | QUMCNIDABfWO | 158012 | 7 |
| 158090 | Akhevan_Warder | 60 | 901,000 | 0-4 | RFQUMCNIDABfWO | 158008 | 2 |
| 158091 | Akhevan_Warder | 60 | 901,000 | 0-4 | QUMCNIDABfWO | 158010 + 158011 (shared pool) | 5 each |
| 158094 | Akhevan_Warder | 60 | 901,000 | 0-4 | QUMCNIDABfWO | 158009 | 14 |

All Warders use spell list 236 (Shadow Warding 5 self-buff, Black Winds 35s PBAE root, Lure of Shadows 15s tash, Silence of the Shadows 30s PBAE silence, Fling 45s knockback). 0-base damage Warders rely on spells + procs.

**Vex Thal — 104 Yaemiu raid_target=1 trash mobs:**
- **75 standing-spawn Yaemiu** (1710-3240s respawn) at 50-101k HP across 5 level tiers (L55 Qua, L58 Zov, L61 Zun, L64 Pli, L66 Eom) with 6 role suffixes (Centien, Thall, Zethon, Liako, Va_Liako, Senshali).
- **29 trap-only Yaemiu** spawned by 158128 shade_trigger (67 trap rows) and 158129 akhevan_trigger (18 trap rows) — proximity-triggered, 30-min depop. Same naming pattern.
- HP distribution: 50-55k (16 NPCs), 60-66k (21), 70-76k (38), 80-84k (18), 90-101k (11).
- Damage range: 200-450 (well within scaled-named tolerance).

**Phase 5a audit-leak (cross-zone, Phase 5b cleanup):**
- **164089 A_burrower_parasite (thedeep, L63, 840,000 HP, raid_target=1, no spell list, no spawn2 — script-spawned by `thedeep/A_burrower_parasite.pl`).** Drops Glowing Orb of Luclinite (item 22196) at 100% chance. Phase 5a addressed thedeep's Thought Horror Overfiend (164078) but missed this script-spawned variant.

### Gap Analysis

| Gap | Lever | Current → Target |
|-----|-------|---|
| Aten Ha Ra dual 1,901,500 HP (63× gap, audit's deepest finding) | `npc_types.hp` 90.5% cut | 1,901,500 → **180,000** (per audit recommendation) |
| Kaas Thox Xi Aten Ha Ra 1,900,000 + 1,650 max dmg | HP 91.6% cut + damage trim 51% | 1,900,000 → **160,000**, 1,650 → **800** |
| Thall Va Kelun 1,825,000 + 1,000 max dmg | HP 91.8% cut + damage trim 40% | 1,825,000 → **150,000**, 1,000 → **600** |
| Diabo Xi Va Temariel 1,706,000 + 1,400 max dmg | HP 91.8% cut + damage trim 45% | 1,706,000 → **140,000**, 1,400 → **770** |
| Va Xi Aten Ha Ra 1,601,500 + 1,254 max dmg | HP 91.9% cut + damage trim 40% | 1,601,500 → **130,000**, 1,254 → **750** |
| Diabo Xi Xin Thall 1,501,500 (damage ok) | HP 91.7% cut | 1,501,500 → **125,000** |
| Thall Xundraux Diabo 1,475,000 (damage ok) | HP 91.9% cut | 1,475,000 → **120,000** |
| Kaas Thox Xi Ans Dyek 1,201,500 (damage ok) | HP 91.7% cut | 1,201,500 → **100,000** |
| Diabo Xi Xin 1,106,500 + 1,200 max dmg | HP 91.9% cut + damage trim 46% | 1,106,500 → **90,000**, 1,200 → **650** |
| Diabo Xi Va 1,050,000 (damage ok) | HP 91.9% cut | 1,050,000 → **85,000** |
| Thall Va Xakra dual (158016/158125) 900,000 each + 950 max dmg | HP 91.1% cut + damage trim 26% | 900,000 → **80,000** each, 950 → **700** |
| Va_Dyn_Khar 158081 600,000 HP (Palace Key dropper) | HP 90% cut | 600,000 → **60,000** (matches audit recommendation) |
| Akhevan Warder 158087/88/89/90/91/094 901,000 HP × 6 NPC IDs (45 simultaneous summons across full zone) | HP 90% cut, preserve spell list 236 | 901,000 → **80,000** each (allows small group to handle 14×Warder add waves) |
| 104 Yaemiu raid_target=1 trash at 50-101k HP | HP 70-85% cuts, level-tiered (see §Yaemiu Scaling Plan) | Eom 70-101k → 20-25k; Pli 55-100k → 18-22k; Zun 50-90k → 15-18k; Zov 50-82k → 12-15k; Qua 50-80k → 10-12k; shadow tier 65-91k → 15-20k |
| 9 inner-VT boss spawn2 rows + 1 second-spawn (Kaas Thox Xi Aten Ha Ra ×2) at 468,720s (130h, 5.4 days) | `spawn2.respawntime` 86,400s (Decision #8 endgame 24h) | 468,720 → **86,400** for ~10 rows |
| 2 Thall Va Xakra spawn2 rows at 140,616s (39h) | `spawn2.respawntime` 86,400s | 140,616 → **86,400** for 2 rows |
| Spell 1948 Destroy (-100,000 HP DT) in list 229, used by 158006 "Destroy Aten" | **Q67 USER DECISION** — Option A PRESERVE (rely on script-gate; architect default) OR Option B DELETE (Decision #16 precedent) | 0-1 row affected |
| 164089 A_burrower_parasite 840,000 HP (thedeep, audit-leak Phase 5a, Glowing Orb dropper) | **Q68 USER DECISION** — Option A INCLUDE in Phase 5b (architect default; HP 89% cut to ~90k matching Thought Horror) OR Option B defer to fixup ticket | 0-1 row affected |

### What is NOT gap for Phase 5b

- **No C++ changes.** Same rationale as Phases 2-5a.
- **No `rule_values` changes.** Confirmed by config-expert Phase 5a (pending Phase 5b reconfirm).
- **No loot table changes.** Per Decision #3.
- **No script edits.** Decision #11. `#Aten_Trigger.pl`, `#Aten_Ha_Ra.pl`, `#Aten_Ha_Ra_.pl`, all 6 Diabo/Thall warder-control scripts, `158016.lua`, `158125.lua`, `shade_trigger.lua`, `akhevan_trigger.lua` preserved verbatim.
- **No `special_abilities` CSV edits.** Decision #11. All boss immunity/rampage flags preserved (Thall Va Kelun rampage 30, Diabo Xi Xin rampage 25, Diabo Xi Xin Thall rampage 20, etc.).
- **No spawn_conditions edits.** vexthal does not use raid-gate spawn_conditions (verified by DB query — single ruleset, no condition-gated variants).
- **No `npc_spells_entries` DELETE for Yaemiu spell lists.** DT sweep across all VT spell lists (sources tsv 09 of DB investigation) shows ZERO DT-profile hits beyond spell 1948 Destroy in list 229. Yaemiu spell lists 2/8/9 (basic combat), 233 (Thall Va Xakra), 236 (Akhevan Warder), 540 (non-Destroy Aten) all clean of DT.
- **No Yaemiu damage UPDATEs.** Audit shows 200-450 max damage range across all 104 Yaemiu — already small-group-tractable.
- **No Yaemiu respawn UPDATEs.** Per Decision #2 (trash unchanged) — short respawns preserve natural attrition gameplay.
- **No 158128/158129 trigger NPC changes.** Proximity-trap controller scripts untouched per Decision #11.
- **No 158095 Aten_Trigger changes.** Controller NPC — same posture as Phase 5a 162260 EmpCycle / 162269 keycheck.
- **No VT key Phase 1 (10 Lucid Shards) changes.** All shard-source mobs are raid_target=0, sub-15k HP, accessible to small group already (lore-master Section 1).
- **No Spirit of Akelha\`Ra (179144) edit.** Phase 5a Decision #57 PRESERVED.
- **No Akheva Sacrificed Remains chain edits.** Phase 5a scope — Phase 5b doesn't re-touch.
- **No A_shissar_wraith (162210) edit.** Drops Planes Rift; already addressed by Phase 5a Emperor cut.
- **No Glowing Orb dropper edits except 164089.** All other Glowing Orb sources are Phase 5a-scaled bosses.
- **No Fabled / LoN / out-of-era NPCs in 158xxx range** — confirmed clean by DB query.
- **MR=144-185 on Aten/Kaas Thox/Diabo bosses NOT hardened to MR=800 wall.** No "caster-blocker" mechanic preserve required (pattern-aligned with Phase 5a Lord Inquisitor Seru being the singular MR-wall in Luclin).

**Relevant topography:**
- `claude/docs/topography/SQL-CODE.md` — npc_types, spawn2, spawnentry, npc_spells_entries chain
- `claude/docs/topography/PERL-CODE.md` — `quest::spawn2`, `quest::depopall`, `$entity_list->IsMobSpawnedByNpcTypeID`, `quest::setglobal`, `quest::settimer` Perl API
- `claude/docs/topography/LUA-CODE.md` — `eq.spawn2`, `eq.set_proximity`, `eq.ChooseRandom`, encounter system

---

## Technical Approach

### Architecture Decision

**Every Phase 5b change is either a single-column `UPDATE` on `npc_types`/`spawn2` or one targeted DELETE on `npc_spells_entries` (conditional on Q67).** Per the layer priority (rules > config > Lua > SQL > C++):

1. **Rules — NOT APPLICABLE.** Same as Phases 2-5a.
2. **Config (`eqemu_config.json` / `.env`) — NOT APPLICABLE.** No structural changes.
3. **Lua/Perl scripts — NOT APPLICABLE BY DEFAULT.** Phase 5b targets NPC stats only. All signature behaviors (Aten dual-form trigger, Akhevan Warder summon waves, Thall Va Xakra train-pull, proximity traps, Va_Dyn_Khar Palace Key drop) are scripted/configured — but read NPC stats at runtime, not at script load.
4. **SQL — YES.** `npc_types` UPDATEs for HP/damage, `spawn2` UPDATEs for respawn, optional `npc_spells_entries` DELETE (Q67=B only).
5. **C++ — NOT APPLICABLE.** No engine change needed.

### Component Change Table

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `npc_types.hp` (~125 in-scope NPCs) | UPDATE per-NPC | Bosses 90-92% cuts, Yaemiu 70-85% level-tiered, Va_Dyn_Khar 90%, Warders 91% |
| `npc_types.maxdmg` (5 boss damage outliers: Kaas Thox 158007, Diablo Va Temariel 158010, Va Xi Aten Ha Ra 158009, Diabo Xi Xin 158015, Thall Va Kelun 158008, Thall Va Xakra dual 158016/158125) | UPDATE per-NPC | Damage outliers (1054-1650) one-shot tank risk |
| `npc_types.mindmg` (Aten dual 158006/158096 only — proportional pair with maxdmg) | UPDATE per-NPC | Pinnacle fights |
| `spawn2.respawntime` (~12 rows: 9 inner-VT bosses incl. 158007 ×2 + 2 Thall Va Xakra) | UPDATE per-spawn | Target 86,400s = 24h endgame per Decision #8 |
| `npc_spells_entries` DELETE WHERE npc_spells_id=229 AND spellid=1948 | DELETE 1 row (CONDITIONAL on Q67=B) | Decision #16 / Decision #54 precedent IF user picks DELETE option |
| `npc_types.special_abilities` | **NO CHANGE** | Decision #11 preserves all signature mechanics (rampage on Diabo Xi Xin/Thall, Diabo Xi Xin Thall, Thall Va Xakra; quad attacks; standard immunities) |
| `npc_types.MR` | **NO CHANGE** | No MR-wall preservation (no Lord Seru / Vyemm-equivalent) |
| Backup tables `npc_types_backup_raid_scaling_luclin_b`, `spawn2_backup_raid_scaling_luclin_b`, `npc_spells_entries_backup_raid_scaling_luclin_b` | CREATE + INSERT-SELECT | Mirrors prior phase patterns with `_luclin_b` suffix |
| `rule_values` | NO CHANGE | Confirmed by config-expert Phase 5a (pending Phase 5b reconfirm) |
| `eqemu_config.json` / `.env` | NO CHANGE | Same as Phases 2-5a |
| Lua scripts (vexthal/) | NO CHANGE | All signature behaviors HP-independent |
| Perl scripts (vexthal/) | NO CHANGE BY DEFAULT | Aten_Trigger script-gate logic preserved; Warder summon scripts preserved |
| C++ source | NO CHANGE | N/A |

### Data Model

#### Backup tables (captured BEFORE any other change)

```sql
CREATE TABLE npc_types_backup_raid_scaling_luclin_b AS
SELECT id, hp, mindmg, maxdmg, AC, MR, special_abilities, npcspecialattks, npc_spells_id, raid_target
FROM npc_types
WHERE id IN (
    -- Aten Ha Ra dual-form (script-spawned, no spawn2)
    158006, 158096,
    -- 9 inner-VT gating bosses
    158007, 158008, 158009, 158010, 158011, 158012, 158013, 158014, 158015,
    -- Thall Va Xakra dual (south + north)
    158016, 158125,
    -- Va_Dyn_Khar (Palace Key dropper)
    158081,
    -- 6 Akhevan Warder NPC IDs (script-summoned adds)
    158087, 158088, 158089, 158090, 158091, 158094,
    -- 104 Yaemiu raid_target=1 trash
    158000, 158001, 158002, 158003, 158004, 158005,
    158017, 158018, 158019, 158020, 158021, 158022, 158023, 158024, 158025, 158026,
    158027, 158028, 158029, 158030, 158031, 158032, 158033, 158034, 158035, 158036,
    158037, 158038, 158039, 158040, 158041, 158042, 158043, 158044, 158045, 158046,
    158047, 158048, 158049, 158050, 158051, 158052, 158053, 158054, 158055, 158056,
    158057, 158058, 158059, 158060, 158061, 158062, 158063, 158064, 158065, 158066,
    158067, 158068, 158069, 158070, 158071, 158072, 158073, 158074, 158075, 158076,
    158077, 158078, 158079, 158080, 158082, 158083, 158084, 158085, 158086,
    158092, 158093, 158097, 158098, 158099, 158100, 158101, 158102, 158103, 158104,
    158105, 158106, 158107, 158108, 158109, 158110, 158111, 158115, 158116, 158117,
    158118, 158119, 158120, 158121, 158122, 158124, 158126, 158127
    -- Plus Q68=A (default): 164089 A_burrower_parasite (Phase 5a audit-leak)
    , 164089
);
-- Expected rows: 125 (Q67/Q68 default = INCLUDE)

CREATE TABLE spawn2_backup_raid_scaling_luclin_b AS
SELECT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance,
       s2._condition, s2.cond_value, s2.x, s2.y, s2.z, s2.heading
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE s2.zone = 'vexthal'
  AND se.npcID IN (
    -- Inner-VT bosses (9 IDs, ~10 spawn2 rows incl. 158007 dual)
    158007, 158008, 158009, 158010, 158011, 158012, 158013, 158014, 158015,
    -- Thall Va Xakra dual
    158016, 158125,
    -- Va_Dyn_Khar
    158081,
    -- All Yaemiu standing-spawn rows (75) + trap-spawn rows (29) for safety completeness
    158000, 158001, 158002, 158003, 158004, 158005,
    158017, 158018, 158019, 158020, 158021, 158022, 158023, 158024, 158025, 158026,
    158027, 158028, 158029, 158030, 158031, 158032, 158033, 158034, 158035, 158036,
    158037, 158038, 158039, 158040, 158041, 158042, 158043, 158044, 158045, 158046,
    158047, 158048, 158049, 158050, 158051, 158052, 158053, 158054, 158055, 158056,
    158057, 158058, 158059, 158060, 158061, 158062, 158063, 158064, 158065, 158066,
    158067, 158068, 158069, 158070, 158071, 158072, 158073, 158074, 158075, 158076,
    158077, 158078, 158079, 158080, 158082, 158083, 158084, 158085, 158086,
    158092, 158093, 158097, 158098, 158099, 158100, 158101, 158102, 158103, 158104,
    158105, 158106, 158107, 158108, 158109, 158110, 158111, 158115, 158116, 158117,
    158118, 158119, 158120, 158121, 158122, 158124, 158126, 158127
);
-- Expected rows: ~110 (12 boss respawn UPDATEs + 75 standing Yaemiu spawn2 + 24 trap-spawn rows
--                     [shade/akhevan trigger spawn2 rows captured for completeness] + Va_Dyn_Khar)
-- Note: Aten dual (158006/158096) and Akhevan Warders (158087-094) have NO spawn2 rows — script-spawned

CREATE TABLE npc_spells_entries_backup_raid_scaling_luclin_b AS
SELECT * FROM npc_spells_entries
WHERE npc_spells_id = 229 AND spellid = 1948;
-- Expected rows: 0 (Q67=A PRESERVE, default) OR 1 (Q67=B DELETE)
-- Captured for safety in either case
```

#### Phase 5b change sketch

**Aten Ha Ra dual-form:**

```sql
-- Decision #11 preserves Aten_Trigger script + dual-form gate logic + Word of Command self-heal + 172800s self-depop
UPDATE npc_types SET hp = 180000, mindmg = 200, maxdmg = 600 WHERE id = 158006;  -- Destroy Aten 1.9M→180k, 1054→600
UPDATE npc_types SET hp = 180000, mindmg = 200, maxdmg = 600 WHERE id = 158096;  -- non-Destroy Aten 1.9M→180k, 1054→600
```

**9 inner-VT bosses (each script-spawns a Warder cluster on engage; Warder HP cut handled separately):**

```sql
UPDATE npc_types SET hp = 160000, maxdmg =  800 WHERE id = 158007;  -- Kaas Thox Xi Aten Ha Ra 1.9M→160k, 1650→800
UPDATE npc_types SET hp = 150000, maxdmg =  600 WHERE id = 158008;  -- Thall Va Kelun 1.825M→150k, 1000→600
UPDATE npc_types SET hp = 130000, maxdmg =  750 WHERE id = 158009;  -- Va Xi Aten Ha Ra 1.6M→130k, 1254→750
UPDATE npc_types SET hp = 140000, maxdmg =  770 WHERE id = 158010;  -- Diablo Xi Va Temariel 1.7M→140k, 1400→770
UPDATE npc_types SET hp = 120000                 WHERE id = 158011;  -- Thall Xundraux Diabo 1.475M→120k (damage 654 ok)
UPDATE npc_types SET hp = 125000                 WHERE id = 158012;  -- Diabo Xi Xin Thall 1.5M→125k (damage 750 ok)
UPDATE npc_types SET hp = 100000                 WHERE id = 158013;  -- Kaas Thox Xi Ans Dyek 1.2M→100k (damage 650 ok)
UPDATE npc_types SET hp =  85000                 WHERE id = 158014;  -- Diabo Xi Va 1.05M→85k (damage 654 ok)
UPDATE npc_types SET hp =  90000, maxdmg =  650 WHERE id = 158015;  -- Diabo Xi Xin 1.1M→90k, 1200→650
```

**Thall Va Xakra dual (zone-trash-tier boss):**

```sql
UPDATE npc_types SET hp = 80000, maxdmg = 700 WHERE id = 158016;  -- Thall Va Xakra south 900k→80k, 950→700
UPDATE npc_types SET hp = 80000, maxdmg = 700 WHERE id = 158125;  -- Thall Va Xakra north 900k→80k, 950→700
```

**Va_Dyn_Khar (Palace Key dropper):**

```sql
UPDATE npc_types SET hp = 60000 WHERE id = 158081;  -- Va_Dyn_Khar 600k→60k (audit recommendation; respawn unchanged at 21,600s 6h short-tier preserves Palace Key cycle)
```

**Akhevan Warder add-wave (6 NPC IDs, script-summoned, 45 simultaneous Warders zone-wide):**

```sql
UPDATE npc_types SET hp = 80000 WHERE id = 158087;  -- Warder 901k→80k (Kaas Thox Xi Ans Dyek's 2 Warders)
UPDATE npc_types SET hp = 80000 WHERE id = 158088;  -- Warder 901k→80k (Diabo Xi Va + Diabo Xi Xin's 5 each)
UPDATE npc_types SET hp = 80000 WHERE id = 158089;  -- Warder 901k→80k (Diabo Xi Xin Thall's 7 Warders)
UPDATE npc_types SET hp = 80000 WHERE id = 158090;  -- Warder 901k→80k (Thall Va Kelun's 2 Warders)
UPDATE npc_types SET hp = 80000 WHERE id = 158091;  -- Warder 901k→80k (Diablo Va Temariel + Thall Xundraux's 5 each)
UPDATE npc_types SET hp = 80000 WHERE id = 158094;  -- Warder 901k→80k (Va Xi Aten Ha Ra's 14 Warders)
```

**Yaemiu trash (104 NPCs by level/role tier):**

```sql
-- Eom-tier (L66) — top Yaemiu tier
UPDATE npc_types SET hp = 25000 WHERE id IN (158001, 158039, 158056, 158033, 158034, 158017, 158027, 158044, 158057, 158061, 158073, 158097, 158100, 158109, 158110, 158115, 158116, 158127, 158126);  -- Eom_*Centien/Thall/Liako/Va_Liako/Senshali/Zethon variants → 25k
UPDATE npc_types SET hp = 25000 WHERE id IN (158004);  -- Eom_Senshali_Xakra special case
UPDATE npc_types SET hp = 22000 WHERE id IN (158028, 158092);  -- Eom_Va_Dyn duplicates → 22k
UPDATE npc_types SET hp = 25000 WHERE id IN (158050);  -- a_writhing_shadow L66 → 25k

-- Pli-tier (L64)
UPDATE npc_types SET hp = 22000 WHERE id IN (158000, 158005, 158035, 158036, 158037, 158046, 158053, 158054, 158059, 158060, 158098, 158101, 158105, 158111, 158117, 158118);  -- Pli_*variants → 22k
UPDATE npc_types SET hp = 20000 WHERE id IN (158029, 158031, 158082, 158051);  -- Pli_Va_Dyn / Pli_Senshali / a_corporeal_shadow → 20k
UPDATE npc_types SET hp = 22000 WHERE id IN (158072);  -- Pli_Va_Liako_Xakra → 22k

-- Zun-tier (L61)
UPDATE npc_types SET hp = 18000 WHERE id IN (158003, 158018, 158023, 158030, 158038, 158040, 158041, 158045, 158049, 158058, 158071, 158099, 158102, 158108, 158124);  -- Zun_*variants → 18k
UPDATE npc_types SET hp = 18000 WHERE id IN (158032, 158083);  -- Zun_Va_Dyn duplicates → 18k
UPDATE npc_types SET hp = 18000 WHERE id IN (158052, 158070);  -- a_mass_of_shadows + Zun_Zethon_Xakra → 18k

-- Zov-tier (L58)
UPDATE npc_types SET hp = 14000 WHERE id IN (158002, 158025, 158026, 158042, 158055, 158062, 158063, 158065, 158066, 158076, 158077, 158103, 158106, 158121, 158122);  -- Zov_*variants → 14k
UPDATE npc_types SET hp = 14000 WHERE id IN (158022);  -- Zov_Zethon_Xakra → 14k
UPDATE npc_types SET hp = 15000 WHERE id IN (158080, 158084, 158093);  -- Zov_Va_Dyn duplicates + a_pool_of_shadows L58 → 15k

-- Qua-tier (L55)
UPDATE npc_types SET hp = 11000 WHERE id IN (158019, 158020, 158021, 158024, 158047, 158048, 158064, 158067, 158068, 158075, 158078, 158079, 158104, 158107, 158119, 158120);  -- Qua_*variants → 11k
UPDATE npc_types SET hp = 12000 WHERE id IN (158043, 158085);  -- Qua_Va_Dyn duplicates → 12k
UPDATE npc_types SET hp = 12000 WHERE id IN (158074);  -- a_living_shadow L55 → 12k

-- Va_Xakra mid-tier (L60, neutral level)
UPDATE npc_types SET hp = 14000 WHERE id IN (158069, 158086);  -- Va_Xakra L60 → 14k
```

**Q68=A burrower-parasite (Phase 5a audit-leak):**

```sql
UPDATE npc_types SET hp = 90000 WHERE id = 164089;  -- A_burrower_parasite (thedeep) 840k→90k (matches 164078 Thought Horror's Phase 5a target for thedeep tier consistency)
```

**Q67=B Aten Destroy DT removal (CONDITIONAL — only if user picks Option B):**

```sql
DELETE FROM npc_spells_entries WHERE npc_spells_id = 229 AND spellid = 1948;
-- 1 row affected (Aten Destroy form). Other lists (489 Kerafyrm, etc.) untouched.
```

**Respawn timer UPDATEs (Decision #8 endgame = 86,400s / 24h):**

```sql
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 86400
WHERE s2.zone = 'vexthal'
  AND se.npcID IN (
    -- 9 inner-VT bosses (~10 spawn2 rows; 158007 has 2)
    158007, 158008, 158009, 158010, 158011, 158012, 158013, 158014, 158015,
    -- Thall Va Xakra dual (2 rows)
    158016, 158125
);
-- Expected rows: ~12

-- NOT updated (preserved):
--   158081 Va_Dyn_Khar — already 21,600s (6h short-tier; Palace Key cycle preserved per audit)
--   158006/158096 Aten dual — script-spawned (no spawn2; 60s timer + 108-120m post-kill qglobal lockout in scripts, preserved per Decision #11)
--   158087-094 Akhevan Warders — script-summoned ADDS (no spawn2; spawn-on-boss-spawn / depop-on-boss-death lifecycle preserved)
--   158095 Aten_Trigger — controller NPC, raid_target=0 (event-control exclusion)
--   158128 shade_trigger / 158129 akhevan_trigger — proximity-trap controllers (raid_target=0; 1800s respawn for trap reset)
--   ALL Yaemiu standing-spawn rows (75) — Decision #2 trash respawn unchanged (1710-3240s natural farming cadence)
--   ALL Yaemiu trap-spawn rows (29) — proximity-triggered, 30-min depop on engage; preserved
```

### Code Changes

**None.** Zero files modified in `eqemu/`, `akk-stack/server/quests/`, or `akk-stack/npc-llm-sidecar/`.

All Phase 5b behavioral preservation works because quest scripts query NPC state via `entity_list->IsMobSpawnedByNpcTypeID()` / `entity_list->GetMobByNpcTypeID()` (returns live NPC if present) and signal/spawn-target by NPC ID. None of these APIs read HP thresholds (verified by source review of all 8 affected `vexthal/*.pl` and 2 `vexthal/15801[6,125].lua` scripts; zero `setnexthpevent` / `EVENT_HP` usage in vexthal scripts).

### Configuration Changes

No `rule_values` changes. No `eqemu_config.json` changes. No `.env` changes. Confirmed pattern carryover from Phase 5a (rule_values count 1,112 unchanged; vexthal ruleset=1; no DZ on this PEQ schema).

### Database Changes

| Item | Type | Rows affected (approx) |
|------|------|------------------------|
| `npc_types_backup_raid_scaling_luclin_b` | CREATE TABLE AS SELECT | **125 rows** snapshot (default Q67/Q68=A) |
| `spawn2_backup_raid_scaling_luclin_b` | CREATE TABLE AS SELECT | **~110 rows** snapshot (incl. trap-spawn rows for completeness) |
| `npc_spells_entries_backup_raid_scaling_luclin_b` | CREATE TABLE AS SELECT | **0 rows (Q67=A default) OR 1 row (Q67=B DELETE)** |
| `npc_types` | UPDATE | **125 rows** (Q67/Q68=A defaults) |
| `spawn2` | UPDATE | ~12 rows (9 boss + 2 Thall Va Xakra + 1 second 158007 row) |
| `npc_spells_entries` | DELETE (CONDITIONAL on Q67=B) | 0 OR 1 row (Aten Destroy spell 1948 from list 229 only) |

Data-expert produces a single SQL reference at `data-expert/context/phase5b-luclin-b-implementation.sql` with:
1. Backup table creates first (3 backups; npc_spells_entries backup empty if Q67=A).
2. All `npc_types` UPDATEs ordered by tier (Aten dual → 9 inner bosses → Thall Va Xakra dual → Va_Dyn_Khar → 6 Warders → Yaemiu by level tier → burrower-parasite if Q68=A).
3. `spawn2.respawntime` UPDATEs.
4. Conditional Aten Destroy DELETE if Q67=B.
5. Post-change verification queries.
6. Full rollback script using backup tables (INSERT…SELECT for npc_types & spawn2; INSERT for the deleted spell entry if Q67=B; transactional).

---

## Aten Ha Ra Dual-Form Isolation Proof (§2 of Architecture)

**The Aten Ha Ra encounter is the most complex script-driven encounter in the project, comparable to Phase 5a Vyzh\`dra trio. This section confirms Phase 5b HP scaling and Q67-A Destroy DT preservation cannot accidentally break the dual-form gate.**

### 2.1 NPC roles

| NPC ID | Role | HP | Spell list | DT? |
|---|---|---|---|---|
| 158095 | #Aten_Trigger (controller) | 50,000,000 | None | No |
| 158006 | #Aten_Ha_Ra "Destroy form" | 1,901,500 | **229 (with Destroy spell 1948)** | **YES — Destroy -100,000 HP** |
| 158096 | #Aten_Ha_Ra_ "non-Destroy form" | 1,901,500 | 540 (no Destroy) | No |
| 158007-015 | 9 gating-tier inner bosses | 1.05M-1.9M each | Various | No |

### 2.2 Trigger orchestration

Per source review of `vexthal/#Aten_Trigger.pl` (full code transcribed in DB investigation §4):

```
Aten_Trigger (158095) every 60 seconds:
  IF qglobals.aten is NOT set (no Aten currently up):
    IF any of the 9 gating bosses (158007-015) is alive:
      → Spawn 158006 "Destroy Aten" (with Destroy DT) at fixed location
    ELIF none of the 9 alive:
      → Despawn 158006 (if up)
      → Spawn 158096 "non-Destroy Aten" (no DT) at fixed location
      → Self-depop the trigger NPC

On 158006 (or 158096) death:
  → Set qglobals.aten = 1 with M$spawntime expiry (rand(720) + 6480 = 108-120 minutes)
  → Aten_Trigger waits out the lockout, then re-evaluates spawn conditions
```

**Encounter logic is HP-INDEPENDENT.** The trigger checks for entity presence via `IsMobSpawnedByNpcTypeID()` (returns true/false on alive/depop). HP thresholds are not consulted.

### 2.3 What Phase 5b touches vs preserves

| Artifact | Phase 5b touches? | Rationale |
|---|---|---|
| `npc_types.hp` for 158006/158096 (Aten dual) | **YES** | Bring both to 180k for tractability (audit recommendation) |
| `npc_types.hp` for 158007-015 (9 gating bosses) | **YES** | Bring all 9 to 85-160k for tractability (audit recommendations) |
| `npc_types.hp` for 158095 (Aten_Trigger) | **NO** | Controller NPC (raid_target=0, 50M HP). Same posture as Phase 5a 162260 EmpCycle / 162269 keycheck. |
| `npc_spells_entries` for spell list 229 (Destroy DT) | **CONDITIONAL on Q67** | A: PRESERVE (script-gate handles it); B: DELETE (Decision #16 precedent) |
| `npc_spells_entries` for spell list 540 (non-Destroy Aten) | **NO** | Clean — no DT. Word of Command (self-heal +3000), Silence, Fling preserved. |
| `#Aten_Trigger.pl` script | **NO** | Trigger orchestration preserved verbatim |
| `#Aten_Ha_Ra.pl` (158006) / `#Aten_Ha_Ra_.pl` (158096) | **NO** | Dual-form lifecycle preserved. 60s timer / 172800s timer / 108-120m qglobal lockout intact. |

### 2.4 Scenarios evaluated

**Scenario A (Q67=A PRESERVE):** Small group enters vexthal, full-clears the 9 gating bosses one-by-one (each at 85-160k HP, 5-15min per fight depending on Warder add waves). After last gating boss death, Aten_Trigger spawns 158096 (non-Destroy) at 180k HP. Group engages 158096. No Destroy DT cast. Group completes encounter. ✅ Safe path.

**Scenario B (Q67=A PRESERVE, edge case):** Small group attempts Aten before clearing all 9 gating bosses (or attempts the encounter before re-clearing if a boss respawned). Aten_Trigger spawns 158006 (Destroy) at 180k HP. Group engages. Destroy casts every (recast=0s? — needs investigation; likely AI-controlled by gcd) — likely instakill on first cast. Group wipes. Player learns sequencing. ✅ Intended difficulty cliff. **Same gameplay function as Phase 4b Kerafyrm Decision #12 (engage = Destroy = wipe; intended to gate the encounter).**

**Scenario C (Q67=B DELETE):** Spell 1948 row removed from list 229. Aten_Trigger still spawns 158006 if gating bosses are alive, but 158006 no longer has Destroy. Group can engage 158006 directly (without clearing bosses) and complete the encounter. **Removes the script-gate's punishment effect. Encounter trivializes the dual-form mechanic.**

**Architect recommendation: Q67 = Option A (PRESERVE).**

Rationale:
1. **Decision #11 — preserve all signature mechanics.** Aten dual-form is a signature mechanic; the Destroy DT is the punishment that gives the gate teeth.
2. **Phase 4b Kerafyrm precedent.** Decision #12 explicitly preserved Kerafyrm's Destroy spell (also list 489, same spell ID 1948). Phase 5b should align.
3. **Decision #54/#60 nuance.** Phase 5a applied DT removal selectively (Vyzh\`dra Touch of Vinitras list 196 DELETE, but Shei list 179 PRESERVE) based on whether the DT was a gameplay barrier (Vyzh\`dra: yes) or signature mechanic (Shei: yes — KEEP). Aten Destroy is closer to "signature gate" than "general barrier" because the script gates *which form spawns* — a small group can ALWAYS face the safe form by sequencing clears.
4. **Asymmetry: small group is forced into the correct sequencing anyway.** Even at 180k HP each, the 9 gating bosses are easier than Aten 158096 (180k + 600 dmg + Word of Command self-heal). A small group naturally clears them first, hitting only the safe Aten.
5. **Decision #16 precedent does NOT cleanly apply.** Cazic Touch was an unconditional cast on aggro (no script-gate); the only mitigation was DELETE. Aten Destroy is gate-controlled; the script provides the mitigation.

**User can override to Q67=B for absolute-safety posture if preferred.** Architecture supports both.

---

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| LB1 | Build 3 backup tables (`npc_types_backup_raid_scaling_luclin_b` ~125 rows; `spawn2_backup_raid_scaling_luclin_b` ~110 rows; `npc_spells_entries_backup_raid_scaling_luclin_b` 0-1 rows depending on Q67); verify counts | data-expert | — | ~30m |
| LB2 | Emit per-boss HP/damage UPDATE SQL for Aten Ha Ra dual-form (158006 Destroy + 158096 non-Destroy → 180k each + damage cuts; preserve Aten_Trigger script + 60s evaluation cycle + qglobal lockout) | data-expert | LB1 | ~15m |
| LB3 | Emit per-boss HP/damage UPDATE SQL for 9 inner-VT gating bosses (158007/008/009/010/011/012/013/014/015 → 85-160k HP per audit + 5 damage outliers trimmed) | data-expert | LB1 | ~30m |
| LB4 | Emit per-boss HP/damage UPDATE SQL for Thall Va Xakra dual (158016 south + 158125 north → 80k + 700 damage each); preserve train-pull lua scripts | data-expert | LB1 | ~10m |
| LB5 | Emit Va_Dyn_Khar HP UPDATE SQL (158081 → 60k; PRESERVE 21,600s spawn2 respawn for Palace Key cycle); confirm Palace Key (item 8010) still drops via lootdrop_id 20537 | data-expert | LB1 | ~10m |
| LB6 | Emit Akhevan Warder HP UPDATE SQL for 6 NPC IDs (158087/088/089/090/091/094 → 80k each); preserve 6 Diabo/Thall .pl warder-control scripts (HP-independent) | data-expert | LB1 | ~15m |
| LB7 | Emit Yaemiu trash HP UPDATE SQL (104 NPCs by level/role tier; Eom L66 → 22-25k, Pli L64 → 20-22k, Zun L61 → 18k, Zov L58 → 14-15k, Qua L55 → 11-12k, shadow tier → 12-25k by level); damage UNCHANGED | data-expert | LB1 | ~60m (largest single batch) |
| LB8 | (**Q68=A default**) Emit A_burrower_parasite (164089) UPDATE SQL (840k → 90k HP); add 164089 to npc_types backup table | data-expert | LB1 | ~5m |
| LB9 | (**REQUIRED per Q67 reversal 2026-04-25**) Emit Aten Destroy DELETE: `DELETE FROM npc_spells_entries WHERE npc_spells_id = 229 AND spellid = 1948;` (1 row, list 229 only). List 489 Kerafyrm Decision #12 UNTOUCHED. | data-expert | LB1 | ~5m |
| LB10 | Emit `spawn2.respawntime` UPDATE SQL (86,400s for ~12 rows: 9 inner-VT boss IDs incl. 158007 second row + 2 Thall Va Xakra rows; EXCLUDE Va_Dyn_Khar 21600s; EXCLUDE Yaemiu standing/trap rows; EXCLUDE script-spawned which have no spawn2) | data-expert | LB1 | ~15m |
| LB11 | Emit rollback script: 3-stage transactional INSERT…SELECT from backup tables + verification queries comparing row counts before/after; mirror Phase 5a `06-luclin-a-rollback.sql` pattern | data-expert | LB2-LB10 | ~30m |
| LB12 | Apply all SQL changes via `docker exec akk-stack-mariadb-1 mysql -ueqemu -p'…' peq < phase5b-luclin-b-implementation.sql`; capture before/after row counts and diff stats | data-expert | LB11 | ~15m |
| LB13 | `#reloadworld` via Spire or world telnet port 9000 — propagates `npc_types` HP changes + `spawn2.respawntime` changes. **Then immediately invoke LB13b zone-process restart for `vexthal`** to flush the in-memory spell list 229 cache (Q67=B DELETE requires it per config-expert 2026-04-25 — same pattern as Phase 2 PoSky Cazic Touch + Phase 5a Akheva Touch of Vinitras DELETEs). | config-expert | LB12 | ~5m |
| LB13b | **REQUIRED** infra-expert full-stack restart (or single-zone restart for vexthal if supported) to flush spell list 229 in-memory cache after Q67=B DELETE. Promoted from CONDITIONAL to default per config-expert Q7 finding 2026-04-25. | infra-expert | LB13 | ~10m |
| LB14 | Smoke verification: HP targets for Aten dual / 9 inner bosses / Thall Va Xakra dual / Va_Dyn_Khar / 6 Warders / 104 Yaemiu / 164089 burrower-parasite (Q68=A); respawn 24h targets for ~12 rows; **(Q67=B only) Aten Destroy DELETE confirmed** spell 1948 NOT in list 229; Aten 158096 list 540 untouched (Word of Command 2157 / Silence 2164 / Fling 2167 still present); Kerafyrm list 489 spell 1948 PRESERVED (Phase 4b Decision #12 untouched); Spirit of Akelha\`Ra (179144) PRESERVED; Phase 5a IDs (162227 Emperor 120k, 159691 Lord Seru 120k, etc.) all preserved | config-expert | LB13 | ~50m (largest validation batch) |
| LB15 | Commit + push all changed files in `claude/` repo (architecture doc, context files, status updates, implementation SQL) to `feature/raid-scaling` branch. `akk-stack/` and `eqemu/` untouched (no script edits). | data-expert | LB12 | ~10m |

**Critical ordering constraint:** LB1 gates LB2-LB10. LB11 depends on all of LB2-LB10. LB12-LB14 sequential. LB15 git-commit only, can run in parallel with LB14.

**Tasks NOT required by default:**
- **lua-expert** — NO Lua script changes. All vexthal Lua scripts (158016.lua, 158125.lua, shade_trigger.lua, akhevan_trigger.lua, ChooseRandom mob trap selectors) HP-independent.
- **perl-expert** — NO Perl script changes by default. All vexthal Perl scripts (Aten_Trigger, Aten_Ha_Ra dual, 6 Diabo/Thall warder-control, 158081 Va_Dyn_Khar) HP-independent.
- **c-expert** — no C++ changes.
- **protocol-agent** — already advised (consult sent 2026-04-25; pending response).

**Required implementation agents (default path = Q67=B DELETE / Q68=A INCLUDE per advisor consultations 2026-04-25):**

| Agent | Role | Tasks |
|-------|------|-------|
| data-expert | primary | LB1, LB2, LB3, LB4, LB5, LB6, LB7, LB8, LB9, LB10, LB11, LB12, LB15 — **125 npc_types UPDATEs + ~12 spawn2 UPDATEs + 1 DELETE (Q67=B default)** |
| config-expert | reload + smoke | LB13, LB14 |
| **infra-expert** | **REQUIRED** zone-process restart for vexthal post-DELETE | LB13b (promoted from CONTINGENT to default per config-expert Q7 2026-04-25 — spell list 229 cache flush required, same as Phase 2 + Phase 5a precedent) |

Same default team composition as Phases 2/3/4b/5a (data-expert + config-expert).

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `#reloadworld` doesn't propagate `npc_types` HP changes in live vexthal zone | Very Low | Low | Same pattern as Phases 2-5a. If failure, config-expert triggers infra-expert vexthal-zone restart. |
| `#reloadworld` doesn't flush `npc_spells_entries` cache for spell list 229 if Q67=B (live vexthal zone) | Low | Low | Phase 2 Cazic Touch + Phase 5a Touch of Vinitras DELETEs both worked with `#reloadworld`. Architect flags as risk; if smoke test shows Aten 158006 still casting Destroy, vexthal zone restart needed. Rare. |
| Aten dual-form spawn-swap (158006 → 158096) breaks due to either-form HP cut | Nil | Medium | Per architect §2 isolation proof: Aten_Trigger uses entity-list checks; HP cut on either form is invisible to the trigger. |
| 9 gating-boss HP cuts cause Aten_Trigger to misfire (e.g., tick before all bosses considered dead) | Nil | Medium | Trigger's 60s tick + entity-list polling handles death correctly via `EVENT_DEATH_COMPLETE` cascade. Verified by source review. Same pattern as Phase 5a Vyzh\`dra cycle. |
| Akhevan Warder summon scripts (6 boss .pl files) break due to Warder HP cut | Nil | Medium | Scripts use `quest::spawn2(NPC_ID, ...)` and `quest::depopall(NPC_ID)` — both NPC-ID-based, not HP-thresholded. Verified by source review. |
| Thall Va Xakra train-pull scripts (158016.lua / 158125.lua) break due to either Xakra HP cut | Nil | Low | Scripts use `eq.get_entity_list():GetNPCBySpawnID(spawn_id)` and `:MoveTo()` — spawn-ID-based, not HP-thresholded. Verified by source review. |
| Va_Dyn_Khar HP cut (600k → 60k) accelerates Palace Key farming faster than intended | Low | Low | Audit explicitly recommends 60k. Palace Key is single-key, repeatable per character. 6h respawn cycle preserved. Acceptable acceleration for small-group play. |
| Yaemiu trash HP cuts cause balance regression (whole zone trivialized) | Medium | Low | Cuts are level-tiered: L66 Eom 22-25k vs scaled-named L66 ~30k baseline. Yaemiu remain 17-25% harder than scaled-named at top tier. "Elite trash" feel preserved. Per Q4 user decision, this is the intended outcome. |
| Yaemiu damage UNCHANGED — possible one-shot risk on Eom-tier (200-450 max dmg) | Nil | Nil | 200-450 max is well within scaled-named tolerance for L65-66 player. No damage trim needed. |
| Trap-spawn proximity scripts (shade_trigger / akhevan_trigger) break due to trap-content HP cut | Nil | Low | Scripts use `eq.spawn2(mob, ...)` — NPC-ID-based, HP-independent. |
| **(Q67=A PRESERVE)** Small group accidentally engages Aten 158006 with Destroy active | Medium | High | **Intended.** Same posture as Phase 4b Kerafyrm engage = wipe. Player learns sequencing. Document for user awareness. |
| **(Q67=A PRESERVE)** Aten_Trigger fails to despawn 158006 when 9 bosses dead → group keeps facing Destroy form | Nil | Medium | Trigger logic: if no boss alive, `quest::depopall(158006)` then spawn 158096. Verified by source review. The script depops, not gates respawn. |
| **(Q67=B DELETE)** DELETE accidentally affects Kerafyrm list 489 (same spell 1948) | Nil | Medium | DELETE scoped to `npc_spells_id = 229 AND spellid = 1948` — exactly 1 row. List 489 (Kerafyrm Destroy, Phase 4b Decision #12) untouched. Verified by smoke test. |
| 158007 Kaas Thox Xi Aten Ha Ra has 2 spawn2 rows — both must be UPDATE'd | Low | Low | Confirmed by DB query (tsv 03 + tsv 05). Implementation SQL `UPDATE … WHERE npcID IN (...)` covers both rows. |
| 164089 burrower-parasite (Q68=A) HP cut accidentally affects standing-spawn variant | Nil | Nil | 164089 has NO spawn2 row (script-spawned). Different from 164078 Thought Horror Overfiend (has spawn2). UPDATE on 164089 only. |
| MobHealth percentage at 1.9M HP overflows on Titanium client | Nil | Low | Phase 5a confirmed 1.25M HP no overflow. 1.9M is 50% higher; bigint(20) supports up to 9.2 quintillion. Confirmed by config-expert pending Phase 5b reconfirm. |
| Ramping `_condition` filter overlooked (similar to Phase 3 VP _condition=2) | Nil | Nil | DB query confirms vexthal spawn2 rows have no condition gating. |
| Backup tables disk space | Near zero | Nil | ~250KB combined. Accept. |

### Compatibility Risks

- **Prior-pass rule values remain authoritative.** None changed.
- **All Epic 1.0 quests untouched.** Epics complete in Classic/Kunark, no Luclin steps. Decision #14 preserved.
- **VT Key Quest progression UNAFFECTED beyond what's already addressed:**
  - Phase 1 (10 Lucid Shards): non-raid mobs in 10 Luclin zones — accessible already, no scaling needed.
  - Phase 2 (Shadowed Scepter Frame): Akheva Sacrificed Remains chain → Spirit of Akelha\`Ra (179144) — Phase 5a Decision #57 PRESERVED 179144 untouched.
  - Phase 3 (Planes Rift): drops from A_shissar_wraith 162210 (Emperor death event) — Phase 5a Emperor cut unblocks.
  - Phase 4 (Glowing Orb of Luclinite): drops from many Luclin raid bosses — Phase 5a addressed all except 164089 burrower-parasite (Q68=A closes the gap).
- **Ring of the Shissar quest chain — UNAFFECTED.** Quest is in ssratemple, addressed in Phase 5a.
- **Cross-era Vulak\`Aerr → Key to Luclin gate UNAFFECTED.** Phase 4b 150k Vulak (Decision #4 era progression) preserved.
- **Companion AI unchanged.** Same scaling patterns as Phases 2-5a.
- **LLM NPC conversation sidecar unchanged.** Reads name/level/faction only.

### Performance Risks

- **Zero.** ~125 UPDATEs + ~12 UPDATEs + 0-1 DELETEs. Trivial workload.
- **No new indexes needed.**
- **No opcode-layer impact** — pending protocol-agent confirmation.
- **No zone boot overhead** — `#reloadworld` refreshes `npc_types` cache in minutes. Optional vexthal zone restart is 5min if Q67=B.

---

## Review Passes

### Pass 1: Feasibility

Every lever used is established Phase 2/3/4a/4b/5a practice:
- `npc_types.hp/mindmg/maxdmg` UPDATEs — 41 Phase 5a + 51 Phase 4b + 35 Phase 4a + 21 Phase 3 + 49 Phase 2 = 197 rows previously touched. Phase 5b adds 125 (largest single phase by row count, driven by Yaemiu inclusion per Q4=A).
- `spawn2.respawntime` UPDATEs — 17 Phase 5a + 32 Phase 4b + 15 Phase 4a + 14 Phase 3 + 40+ Phase 2 = ~118 rows previously. Phase 5b adds ~12 (smaller than typical because most VT NPCs are script-spawned or trash-respawn-preserved).
- `npc_spells_entries` DELETE — 1 Phase 5a + 3 Phase 2 = 4 rows previously. Phase 5b adds 0-1 (Q67-dependent).
- Backup tables — established pattern across all phases.

**Hardest part:** The Aten dual-form / 9 gating boss / 6 Akhevan Warder triple-layer integration. Verified by source review of `#Aten_Trigger.pl` + 6 Diabo/Thall warder-control `.pl` files + 158016/158125 train-pull `.lua` files. **All scripts use entity-list NPC-ID checks, not HP thresholds.**

**Edge case:** Va_Xi_Aten_Ha_Ra (158009) summons 14 Akhevan_Warders 158094 simultaneously on engage. At 901k Warder HP (current) this is impossible for small group. At 80k Warder HP (Phase 5b) and 130k Va_Xi_Aten_Ha_Ra HP, the encounter is a 14×80k = 1.12M Warder HP pool + 130k boss = 1.25M total = clearable in 8-15min by 1+5 group at 1500-2500 DPS. **The Warder HP cut is the single biggest small-group play unblocker in Phase 5b.**

**Advisor confirmations (in flight 2026-04-25):**
- **protocol-agent — pending Phase 5b consult response (sent 2026-04-25).** Architect's expectation: zero protocol/client impact, same as Phases 2-5a. Aten dual-form spawn-swap is server-internal (no opcode change). MobHealth at 1.9M HP percentage-only (bigint).
- **config-expert — pending Phase 5b consult response (sent 2026-04-25).** Architect's expectation: rule_values count 1,112 unchanged (zero drift); vexthal ruleset=1; no DZ; no condition-gated spawns; backup naming pattern `_raid_scaling_luclin_b` consistent.
- **lore-master — pending Phase 5b consult response (sent 2026-04-25).** Architect's expectation: confirms VT internal progression (Diabo trio + Thall Va tier + Akhevan Warder add-wave context + Aten dual-form lore); confirms 13-shard correction (10 Lucid + 3 components per Section 1); no Khati Sha VT variant exists; Diabo trio specific encounter linkage confirmed; signature-mechanic preservation per Decision #11.

**Confirmed feasibility:** all 15 tasks (LB1-LB15) executable by data-expert + config-expert in one session. Same team composition as prior phases. Default path adds NO new agents.

### Pass 2: Simplicity

**Challenge: Can we do less?**

- **Could we skip the Yaemiu trash (104 NPCs)?** Per Q4 user decision (INCLUDE), it's already affirmatively in scope. Skipping = 104 fewer UPDATEs but leaves the ~80 elite-trash as 2-3× small-group's typical zone-trash difficulty. The user explicitly chose to include them as an "elite trash that becomes named-tier" treatment.
- **Could we skip the 6 Akhevan Warders?** No. They are encounter-defining add waves (45 simultaneous Warders zone-wide). Without HP cut, no inner-VT boss is engageable. **Mandatory.**
- **Could we skip Va_Dyn_Khar?** No. He gates the only keyed door in vexthal (Palace Key, item 8010). At 600k HP he's a wall for small group; at 60k he's a gate-opener. **Mandatory.**
- **Could we skip Thall Va Xakra dual?** No. They're zone-trash boss tier (900k each), audit-flagged for scaling. Train-pull mechanic is small-group-impactful but tractable at 80k boss HP.
- **Could we skip Aten Ha Ra dual scaling?** No. Final boss of Vex Thal — the encounter the entire phase exists to make small-group-tractable.
- **Could we skip Q68 burrower-parasite (164089)?** Yes — defer to a Phase 5a fixup ticket. Adds 1 UPDATE if INCLUDED. Architect default INCLUDE for project-closure cleanness. User can override.
- **Could we skip Q67 Aten Destroy DELETE?** Yes — architect default PRESERVE (rely on script-gate). User can override to DELETE for absolute safety.
- **Could we skip damage cuts on the 5 outliers (Kaas Thox 1650, Diabo Va Temariel 1400, Va Xi Aten Ha Ra 1254, Diabo Xi Xin 1200, Thall Va Kelun 1000, Thall Va Xakra dual 950)?** Audit explicitly flags 1054-1650 max as one-shot risks. Trim required for L65 player tank survival.
- **Could we skip respawn updates?** No — VT bosses at 130h respawn directly contradict Decision #8 (24h endgame).
- **Could we skip backup tables?** No — Phase 2-5a precedent. Phase 4a BUG-001 Tunare rollback relied on them.

**Removed / deferred:**
- ~~158087-094 Akhevan Warder count of 8~~ — DB confirms only 6 (158087, 88, 89, 90, 91, 94). 158092/093 are unrelated NPCs (Eom_Va_Dyn / a_pool_of_shadows). Briefing was wrong.
- ~~"13-shard" framing~~ — DB confirms 10 Lucid Shards + 3 components = 13 items, but only 10 are formally "shards." Q69 surfaces correction; no scaling action required.
- ~~Khati Sha VT variant inclusion~~ — DB query confirms zero 158xxx-range Khati Sha NPC. 154145 (acrylia, Phase 5a) is the only Khati Sha. Decision #55 boundary holds.
- ~~Yaemiu damage UPDATEs~~ — All 104 within 200-450 max dmg, no outliers.
- ~~Yaemiu respawn UPDATEs~~ — Decision #2 trash respawn unchanged.
- ~~158095 Aten_Trigger inclusion~~ — Controller NPC, raid_target=0 (not a fight target).
- ~~158128/158129 trigger NPC inclusion~~ — Proximity-trap controllers, raid_target=0.

### Pass 3: Antagonistic — what could go wrong

1. **Aten 158006 spawns with Destroy active.** Group engages by mistake. Destroy fires. Group wipes. **Intended per Q67=A.** Same posture as Phase 4b Kerafyrm. Document.

2. **Group kills 8 of 9 gating bosses, leaves 1 alive (e.g., Diabo Xi Va 158014 at 85k HP → respawns at 24h while group is still farming). Aten_Trigger keeps spawning Destroy form.** Player must re-clear the respawned boss, OR wait until Destroy form depops on `qglobals.aten` lockout (108-120m). **Intentional cycle friction.**

3. **Akhevan Warder add wave overwhelms tank during Va_Xi_Aten_Ha_Ra fight.** 14 Warders at 80k HP each summoned on engage. Even cut, this is a 14-mob simultaneous AoE-tank scenario. **Friction expected.** Documenting this as the highest-risk specific encounter for small-group play.

4. **Thall Va Xakra train-pull pulls existing Yaemiu to boss location, exceeding small-group's AoE capacity.** 27 spawn IDs called per Xakra. With Yaemiu HP cut to 11-25k, the train is tractable but cluttered. Document.

5. **Va_Dyn_Khar respawn at 6h is fast enough that Palace Key farming becomes trivial.** Intended per audit ("respawn already short").

6. **Aten_Trigger 60s evaluation tick fires DURING the 108-120m qglobal lockout — does it cause a dual-spawn?** Source review confirms: trigger checks `if (!defined $qglobals{aten})` first. If lockout active, no spawn occurs. Safe.

7. **`qglobals.aten` race condition between Destroy form death and non-Destroy form spawn.** Death sets the global with `M$spawntime` expiry; the trigger only checks `defined`. After expiry, trigger re-evaluates. No race.

8. **Yaemiu HP cut accidentally affects Akheva Sacrificed Remains (a different but similar 'shadow' name pattern).** Akheva NPCs are 179xxx range, not 158xxx — DB query scope filter prevents bleed.

9. **Q68=A 164089 burrower-parasite cut accidentally affects 154142 acrylia evolved burrower (Phase 5a target).** Different NPC IDs, different zones (164xxx vs 154xxx). UPDATE WHERE id=164089 only. Safe.

10. **Cross-era unblock: Phase 5a Vulak\`Aerr (Phase 4b 150k) → Key to Luclin → Phase 5a Luclin → Phase 5b Vex Thal closes the chain.** Phase 5b is the terminal step. ✅

11. **What if user picks Q67=B (DELETE Aten Destroy)?** DELETE row from list 229 only. Kerafyrm list 489 untouched. Phase 4b Decision #12 preserved. Verified by smoke test.

12. **What if user picks Q68=B (defer 164089)?** Skip task LB8. Burrower-parasite remains at 840k post-project. User-acknowledged pending fixup ticket. Phase 5b otherwise unchanged.

13. **What if a Yaemiu carries an unflagged DT spell missed by §3 sweep?** §3 sweep covered all spell lists referenced by 158xxx NPCs. ZERO DT-profile hits except spell 1948. Sweep is comprehensive.

14. **What if 158096 (non-Destroy Aten) Word of Command +3000 self-heal stacks to make encounter unwinnable at 180k HP?** Recast 30s, +3000 base = 100/s effective regen. At 180k HP and 1500-2500 group DPS, group out-DPSes regen by 14× minimum. ✅ Tractable.

15. **What if Aten 158096 list 540 Silence (PBAE 80-range, 30s recast) silences the entire group's casters for 1s every 30s?** Friction expected. Same posture as Phase 5a Lord Seru MR=800 (caster comp must adapt). Document.

16. **What if 158087-094 Warders' Black Winds (4.8s cast 60-range PBAE root) traps the entire group during a 14-Warder add wave?** Possible AoE friction. Cleric/Druid `Stunning Strike` or escape mechanics required. Document for advanced encounter notes.

### Pass 4: Integration

**Task ordering:**
```
LB1 (3 backups) ──┬──> LB2 (Aten dual SQL)
                  ├──> LB3 (9 inner bosses SQL)
                  ├──> LB4 (Thall Va Xakra dual SQL)
                  ├──> LB5 (Va_Dyn_Khar SQL)
                  ├──> LB6 (6 Akhevan Warders SQL)
                  ├──> LB7 (104 Yaemiu by tier SQL — largest batch)
                  ├──> LB8 (Q68=A burrower parasite SQL — conditional but default INCLUDE)
                  ├──> LB9 (Q67=B Aten Destroy DELETE — conditional)
                  └──> LB10 (~12 spawn2 respawn SQL)
                         │
                         └──> LB11 (rollback) ──> LB12 (apply) ──> LB13 (reload) ──> LB14 (smoke verify)
                                                                        │
                                                                        └──> LB15 (commit)
```

- LB1 gates everything.
- LB2-LB10 can run in parallel after LB1 (same agent, sequential writing).
- LB11 depends on LB2-LB10.
- LB12-LB14 sequential.
- LB15 git-commit only, can start after LB12.

**Cross-agent dependencies all resolvable:**
- **game-designer** (PRD + audit): inputs consumed from Phase 1 + Phase 5b analysis (audit-leak burrower-parasite + 13-shard correction surfaced).
- **lore-master** (Luclin chains): primary reference (`luclin-chains.md` Sections 1-9) confirms 10-shard reality + Aten dual-form + Akhevan Warder context. Phase 5b consult sent 2026-04-25; pending response.
- **protocol-agent** (Phase 5b protocol clearance): consult sent 2026-04-25; pending response.
- **config-expert** (rule posture + DB cross-checks): consult sent 2026-04-25; pending response.
- **game-tester** (Phase 5b validation): will receive 125-NPC smoke-verify hooks + Aten dual verify + Warder verify + (Q67=B) Destroy DELETE verify.

**Task dependencies all linear within Phase 5b.** Same shape as Phase 5a (L1 → L2-L7 → L8 → L9 → L10 → L11 → L12), with LB7 (Yaemiu) as the largest single batch and LB13 reload as the only multi-zone risk point.

---

## Items flagged to user — PHASE 5b USER DECISIONS

### Decision #67 — Aten Destroy DT disposition — **OPEN (architect default UPDATED 2026-04-25 post-protocol-agent finding)**

Spell **1948 "Destroy"** (-100,000 HP, 0 mana, 0 cast, **recast=-1 unlimited**, **targettype=4 PBAE**) appears in spell list **229** which is used by **158006 #Aten_Ha_Ra "Destroy form"**. The Aten_Trigger script (158095) gates the Destroy form: it spawns 158006 only when at least one of 9 inner-VT bosses (158007-015) is alive, and spawns 158096 (non-Destroy form) when all 9 are dead.

**Architect recommendation: Option B — DELETE** (REVERSED 2026-04-25 after protocol-agent flagged targettype=4 PBAE — see Phase 5b protocol-agent addendum).

Rationale (revised):
- **PBAE Destroy wipes the entire 1-3 player group simultaneously.** Cazic Touch (Phase 2) and Touch of Vinitras (Phase 5a) were targettype=5 single-target — tank takes hit, group recovers. **Aten Destroy is targettype=4 area-of-effect** — player + all companions in range take -100,000 HP simultaneously. No survivable state for a small group.
- **Unlimited recast (recast_delay=-1)** means Destroy fires every AI cooldown tick once cast, not once-per-fight. Makes the encounter literally impossible at small-group scale.
- **Phase 4b Decision #12 Kerafyrm parallel does NOT hold.** Kerafyrm's Destroy is the lore-intended punishment of a deliberately-triggered Sleeper-awake event — an explicit "this fight is supposed to wipe a 72-player raid" feature. Aten 158006 spawns automatically on a 60s Aten_Trigger script tick based on entity-list state the player cannot query — a small group that mis-sequences by 30 seconds (last gating boss respawns mid-attempt) gets one-shotted as a group with no recovery path. That's an unwinnable trap, not an intended difficulty cliff.
- **List 229's other 3 spells** (2157 Word of Command AE charm, 2164 Silence of the Shadows PBAE silence, 2167 Fling knockback) are preserved by the DELETE. These provide the Aten 158006 encounter's signature character. DT removal leaves a meaningfully harder fight than 158096, just no longer instakill.
- **Phase 5a Decision #54/#60 selective-DT precedent applies cleanly.** Touch of Vinitras DELETE'd from list 196 (Vyzh\`dra forms — small-group-blocker not signature) but PRESERVED in list 179 (Shei Vinitras — signature mechanic). Aten 158006 Destroy is "small-group-blocker not signature" — same posture as Vyzh\`dra list 196.

**Alternative — Option A: PRESERVE.**

Keep spell 1948 row in list 229. Aten_Trigger script-gate handles which form spawns; players who perfectly sequence kills face only 158096 (safe). **Trade-off:** any sequencing error or boss-respawn timing mishap → unwinnable PBAE wipe. Architect's prior reasoning (Decision #11 signature mechanic + Decision #12 Kerafyrm precedent) holds in spirit but the PBAE distinction breaks the small-group analogy.

**Implementation impact:**
- **Q67=B (NEW DEFAULT):** task LB9 PROMOTED from CONDITIONAL to default required. 1-row DELETE on `npc_spells_entries WHERE npc_spells_id=229 AND spellid=1948`. backup table `npc_spells_entries_backup_raid_scaling_luclin_b` captures 1 row pre-DELETE. List 489 (Kerafyrm Decision #12) UNTOUCHED. Spell 1948 row in `spells_new` UNTOUCHED (Kerafyrm still uses it).
- **Q67=A:** task LB9 skipped. backup table 0 rows. Architect-flagged risk: small group faces unwinnable PBAE if sequencing slips.

**Implementation impact:**
- Q67=A: Skip task LB9. backup table empty for npc_spells_entries.
- Q67=B: Run task LB9 — 1 row DELETE. backup table captures 1 row.

### Decision #68 — A_burrower_parasite (164089) Phase 5a audit-leak — **OPEN**

`A_burrower_parasite` (164089, thedeep, L63, 840,000 HP, raid_target=1, no spawn2 — script-spawned) drops Glowing Orb of Luclinite (item 22196, 100% chance). It's a Phase 5a audit-miss — Phase 5a addressed thedeep's Thought Horror Overfiend (164078, 90k HP scaled) but missed this script-spawned variant.

**Architect recommendation: Option A — INCLUDE in Phase 5b** (one extra UPDATE: 840k → 90k HP, matching Thought Horror Phase 5a target for thedeep tier consistency).

**Alternative — Option B: defer to a Phase 5a fixup ticket** post-project closure.

**Implementation impact:**
- Q68=A: 1 extra `npc_types` UPDATE. Backup table +1 row. 164089 added to scope.
- Q68=B: Skip task LB8. Burrower-parasite remains at 840k. Pending separate fixup.

### Decision #69 — VT key "13-shard" briefing correction — **OPEN**

User briefing said: _"13-shard VT key quest (Q7 = keep all 13 per Decision #10)"_. 

DB query + lore-master canonical research (`luclin-chains.md:30-77`) confirms:
- **10 Lucid Shards** (items 22185-22194), all from non-raid mobs in 10 Luclin zones (already accessible to small group).
- **3 component items**: Shadowed Scepter Frame (17323) + Planes Rift (9410) + Glowing Orb of Luclinite (22196). The 3 components are the "raid-tier" gates and are mostly addressed by Phase 5a (Frame chain, Planes Rift from Emperor wraith, Glowing Orb from any Luclin raid boss).

So the "13" number = 10 shards + 3 components. **Only 10 are formally "shards."** The Phase 1 collection step is fully accessible already; Phase 5a unlocks the 3 component gates; Phase 5b doesn't need to scale any shard sources.

**Architect recommendation: Option A** — acknowledge the breakdown (10 + 3 = 13 items), no scaling action needed (all sources already accessible per Phase 5a + non-raid).

**Alternative — Option B**: deeper investigation if user intended a different scope (e.g., 13-shard *count reduction* from 10 to a smaller number, or restructuring the quest).

**Implementation impact:** None on Phase 5b SQL. Q69 is a documentation/clarity issue — the architecture and validation plan are already correct.

---

## Required Implementation Agents

**Default path (Q67=A PRESERVE, Q68=A INCLUDE):**

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| data-expert | LB1-LB8, LB10-LB12, LB15 | Owns all SQL emission, backup creation, apply, and commit. Primary agent. Same role as Phases 2/3/4a/4b/5a. |
| config-expert | LB13, LB14 | `#reloadworld` via world telnet port 9000 + post-change smoke verification. Same role as Phases 2/3/4b/5a. |

**Q67=B variant (DELETE Aten Destroy):**

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| data-expert | LB1-LB12, LB15 | Adds task LB9 (1-row DELETE) |
| config-expert | LB13, LB14 | as above |
| infra-expert | LB13b CONTINGENT | Vexthal zone-process restart if `#reloadworld` doesn't flush spell list 229 cache (low likelihood, Phase 2/5a precedent) |

**Agents NOT needed:** c-expert, lua-expert, perl-expert, protocol-agent (already advised pending response).

---

## Validation Plan

_game-tester should verify each of the following after the implementation team completes Tasks LB1-LB15:_

### Backup integrity
- [ ] **3 backup tables exist and are populated.**
  ```sql
  SELECT COUNT(*) FROM npc_types_backup_raid_scaling_luclin_b;          -- expect 125 (Q67/Q68=A defaults)
  SELECT COUNT(*) FROM spawn2_backup_raid_scaling_luclin_b;              -- expect ~110
  SELECT COUNT(*) FROM npc_spells_entries_backup_raid_scaling_luclin_b;  -- expect 0 (Q67=A) OR 1 (Q67=B)
  ```

### Aten Ha Ra dual-form HP targets
- [ ] **158006 #Aten_Ha_Ra (Destroy form): hp=180000, mindmg=200, maxdmg=600**
- [ ] **158096 #Aten_Ha_Ra_ (non-Destroy form): hp=180000, mindmg=200, maxdmg=600**
- [ ] **158095 #Aten_Trigger UNCHANGED: hp=50000000** (controller NPC preserved)
- [ ] (Q67=A only) Spell 1948 STILL PRESENT in list 229: `SELECT COUNT(*) FROM npc_spells_entries WHERE npc_spells_id=229 AND spellid=1948;` returns 1.
- [ ] (Q67=B only) Spell 1948 REMOVED from list 229: `SELECT COUNT(*) FROM npc_spells_entries WHERE npc_spells_id=229 AND spellid=1948;` returns 0.
- [ ] Spell 1948 STILL PRESENT in list 489 (Phase 4b Kerafyrm Decision #12): `SELECT COUNT(*) FROM npc_spells_entries WHERE npc_spells_id=489 AND spellid=1948;` returns 1.
- [ ] List 540 (non-Destroy Aten) untouched: `SELECT spellid FROM npc_spells_entries WHERE npc_spells_id=540;` returns 2157, 2164, 2167 (Word of Command, Silence, Fling).

### 9 inner-VT boss HP targets
- [ ] ```sql
  SELECT id, name, hp, mindmg, maxdmg FROM npc_types
  WHERE id IN (158007,158008,158009,158010,158011,158012,158013,158014,158015)
  ORDER BY hp DESC;
  ```
  **Expected:**
  - Kaas Thox Xi Aten Ha Ra 158007: hp=160000, maxdmg=800
  - Thall Va Kelun 158008: hp=150000, maxdmg=600
  - Diablo Xi Va Temariel 158010: hp=140000, maxdmg=770
  - Va Xi Aten Ha Ra 158009: hp=130000, maxdmg=750
  - Diabo Xi Xin Thall 158012: hp=125000
  - Thall Xundraux Diabo 158011: hp=120000
  - Kaas Thox Xi Ans Dyek 158013: hp=100000
  - Diabo Xi Xin 158015: hp=90000, maxdmg=650
  - Diabo Xi Va 158014: hp=85000

### Thall Va Xakra dual + Va_Dyn_Khar HP targets
- [ ] **158016 (south) Thall Va Xakra: hp=80000, maxdmg=700**
- [ ] **158125 (north) Thall Va Xakra: hp=80000, maxdmg=700**
- [ ] **158081 Va_Dyn_Khar: hp=60000** (mindmg/maxdmg unchanged at 265/455 per audit)
- [ ] **158081 Va_Dyn_Khar spawn2 respawntime UNCHANGED at 21600** (Palace Key cycle preserved)

### Akhevan Warder HP targets (6 NPC IDs)
- [ ] ```sql
  SELECT id, name, hp FROM npc_types WHERE id IN (158087, 158088, 158089, 158090, 158091, 158094);
  -- Expected: all hp=80000
  ```
- [ ] **158092 Eom_Va_Dyn (NOT a Warder) UNCHANGED at 101k → cut to Yaemiu Eom-tier 22000 only.**
- [ ] **158093 a_pool_of_shadows (NOT a Warder) UNCHANGED at 65k → cut to Yaemiu shadow-tier 15000 only.**

### 104 Yaemiu trash HP targets — sample verification
- [ ] L66 Eom-tier: `SELECT hp FROM npc_types WHERE id IN (158001, 158039, 158056);` returns 25000.
- [ ] L66 Eom_Va_Dyn duplicates: `SELECT hp FROM npc_types WHERE id IN (158028, 158092);` returns 22000.
- [ ] L64 Pli-tier: `SELECT hp FROM npc_types WHERE id IN (158000, 158005, 158035);` returns 22000.
- [ ] L61 Zun-tier: `SELECT hp FROM npc_types WHERE id IN (158003, 158023, 158030);` returns 18000.
- [ ] L58 Zov-tier: `SELECT hp FROM npc_types WHERE id IN (158002, 158022, 158025);` returns 14000.
- [ ] L55 Qua-tier: `SELECT hp FROM npc_types WHERE id IN (158019, 158020, 158068);` returns 11000.
- [ ] Shadow-tier: `SELECT hp FROM npc_types WHERE id IN (158050 [a_writhing_shadow], 158051 [a_corporeal_shadow], 158052 [a_mass_of_shadows], 158074 [a_living_shadow], 158093 [a_pool_of_shadows]);` returns 25000, 20000, 18000, 12000, 15000 respectively (level-tiered).

### Q68=A burrower-parasite verification
- [ ] **164089 A_burrower_parasite (thedeep): hp=90000** (Q68=A default — INCLUDE in Phase 5b)
- [ ] (Q68=B only) **164089 UNCHANGED at 840000** (deferred)
- [ ] **164078 Thought Horror Overfiend (Phase 5a) PRESERVED at hp=90000** — no Phase 5b regression on Phase 5a target.

### Respawn verification (24h endgame tier)
- [ ] All 9 inner-VT boss spawn2 rows updated to 86400:
  ```sql
  SELECT s2.id, s2.respawntime, n.name FROM spawn2 s2
    JOIN spawnentry se ON se.spawngroupID=s2.spawngroupID
    JOIN npc_types n ON n.id=se.npcID
   WHERE s2.zone='vexthal' AND n.id IN (158007,158008,158009,158010,158011,158012,158013,158014,158015,158016,158125)
   ORDER BY n.id;
  -- Expected: ~12 rows (158007 has 2), all respawntime=86400
  ```
- [ ] **Va_Dyn_Khar 158081 spawn2 PRESERVED at 21600** (per audit + Palace Key cycle).
- [ ] **All Yaemiu spawn2 respawn UNCHANGED** (sample 10 rows: respawntime in 1710/2280/2700/3240/4320 distribution).
- [ ] **Trap-spawn rows (158128 shade_trigger, 158129 akhevan_trigger) UNCHANGED at 1800.**
- [ ] **Aten_Trigger 158095 spawn2 UNCHANGED at 259200.**

### Untouched-NPC verification (Phase 5a + cross-era preservations)
- [ ] **Spirit of Akelha\`Ra 179144 PRESERVED at hp=1000000** (VT-key turn-in NPC, Phase 5a Decision #57):
  ```sql
  SELECT hp FROM npc_types WHERE id = 179144;  -- expect 1000000
  ```
- [ ] **Phase 5a IDs PRESERVED:**
  ```sql
  SELECT id, hp FROM npc_types WHERE id IN (162227, 159691, 154145, 162206, 162076, 162190, 162177, 164078);
  -- expect Emperor 120000, Lord Seru 120000, Khati Sha 90000, Vyzh`dra Cursed 90000, High Priest 90000, Xerkizh 80000, Arch Lich 75000, Thought Horror 90000
  ```
- [ ] **Phase 4b Kerafyrm trio PRESERVED:**
  ```sql
  SELECT id, hp FROM npc_types WHERE id IN (128089, 128094, 128095);  -- expect 3500000 each (Decision #12 untouched)
  ```
- [ ] **Phase 4b Vulak\`Aerr PRESERVED at hp=150000** (Phase 4b target).
- [ ] **No regression on Phase 5a Touch of Vinitras boundary:** Spell 2859 in list 196 = 0 rows; spell 2859 in list 179 = 1 row (Shei Vinitras preserved per Decision #60).

### Aten Ha Ra trigger script integrity
- [ ] `vexthal/#Aten_Trigger.pl`, `vexthal/#Aten_Ha_Ra.pl`, `vexthal/#Aten_Ha_Ra_.pl` mtimes BEFORE Phase 5b apply timestamp (NOT modified per Decision #11).
- [ ] All 6 Diabo/Thall warder-control scripts mtimes BEFORE: `#Kaas_Thox_Xi_Ans_Dyek.pl`, `#Diabo_Xi_Va.pl`, `#Diabo_Xi_Xin.pl`, `#Diabo_Xi_Xin_Thall.pl`, `#Thall_Va_Kelun.pl`, `#Diablo_Xi_Va_Temariel.pl`, `#Thall_Xundraux_Diabo.pl`, `#Va_Xi_Aten_Ha_Ra.pl`.
- [ ] `158016.lua`, `158125.lua`, `shade_trigger.lua`, `akhevan_trigger.lua` mtimes BEFORE.

### In-game smoke tests (1 player + 5 companions)

- [ ] **Enter Vex Thal:** zone enters cleanly. Yaemiu trash at first checkpoint feels "elite-named-tier hard but tractable" (~25-30s per Yaemiu kill).
- [ ] **Akhevan Warder add-wave test:** engage Kaas_Thox_Xi_Ans_Dyek (158013, 100k). 2× 158087 Warders spawn (80k each). Combined fight clears in ~5-10min. ✅
- [ ] **Va_Xi_Aten_Ha_Ra fight (heaviest add wave):** engage 158009 (130k). 14× 158094 Warders spawn (80k each = 1.12M Warder pool). Combined fight clears in ~15-30min for prepared 1+5 group. **Document as longest single fight in Phase 5b.**
- [ ] **Thall Va Xakra train-pull test:** engage 158016 (south, 80k). Lua script pulls 27 Yaemiu spawn IDs to boss. Group AoEs through. Confirm fight completes.
- [ ] **Va_Dyn_Khar Palace Key cycle:** kill 158081 (60k HP, 6h respawn). Loot Palace Key (item 8010). Use Palace Key on door 8010. Door opens. Re-spawn cycle in 6h.
- [ ] **9 inner-VT bosses kill sequence:** clear all 9 (each 85-160k HP + Warder add wave per boss). Total kill duration ~2-3 hours for prepared 1+5 group across multiple zone visits.
- [ ] **Aten 158096 (non-Destroy form) spawn check:** after all 9 gating bosses dead + Aten_Trigger 60s tick, 158096 spawns at 1412/0/248.63 (audit-confirmed coordinates). NO Destroy DT. Word of Command self-heal +3000 every 30s. Group clears at 180k HP in ~2-5min.
- [ ] **(Q67=A only) Aten 158006 (Destroy form) spawn check:** if any of 9 gating bosses respawns mid-attempt, Aten_Trigger spawns 158006. Engage = Destroy = wipe (intended). Verify Destroy still casts.
- [ ] **(Q67=B only) Aten 158006 (Destroy form) spawn check:** spawn-trigger still fires, but Aten 158006 has no Destroy. Group can engage at 180k HP without DT risk.
- [ ] **VT key Phase 4 unblock:** kill 164089 burrower-parasite (Q68=A scaled to 90k) → Glowing Orb of Luclinite drops at 100% → combine into VT key.

### No regression on unchanged NPCs
- [ ] Spot-check Phase 5a non-raid Akheva/ssratemple/etc. NPCs unchanged.
- [ ] Spot-check Phase 4b ToV/Sleeper/Vulak/AoW NPCs unchanged.
- [ ] Spot-check Phase 4a Kael/Skyshrine/PoG NPCs unchanged.
- [ ] Spot-check Phase 3 Trakanon/VP/Chardok NPCs unchanged.
- [ ] Spot-check Phase 2 Classic NPCs unchanged.

### Rollback dry-run
- [ ] **Using backup tables, restore `npc_types` for 3 sample NPCs** (Aten 158006, Va_Xi_Aten_Ha_Ra 158009, Va_Dyn_Khar 158081) and verify pre-change values match (1901500, 1601500, 600000).
- [ ] **(Q67=B only) Aten Destroy restore:** `INSERT INTO npc_spells_entries SELECT * FROM npc_spells_entries_backup_raid_scaling_luclin_b;` re-creates the deleted row. Verify spell 1948 now in list 229.
- [ ] **Rollback script syntax-verified** (DRY RUN: BEGIN; UPDATE...; SELECT COUNT; ROLLBACK).

---

## Appendix — Project closure summary

**Phases 2-5b cumulative (raid-scaling project totals):**

| Metric | Phase 2 | Phase 3 | Phase 4a | Phase 4b | Phase 5a | Phase 5b | **Total** |
|---|---|---|---|---|---|---|---|
| `npc_types` UPDATEs | 49 | 21 | 35 | 51 | 41 | **125** | **322** |
| `spawn2.respawntime` UPDATEs | 40+ | 14 | 15 | 32 | 17 | 12 | **130+** |
| `npc_spells_entries` DELETEs | 3 | 0 | 0 | 0 | 1 | 0-1 | **4-5** |
| Lua/Perl edits | 0 | 0 | 0-1 | 0 | 1 | 0 | **1-2** |
| C++ edits | 0 | 0 | 0 | 0 | 0 | 0 | **0** |
| Rule changes | 0 | 0 | 0 | 0 | 0 | 0 | **0** |

**No C++ changes across the entire raid-scaling project.** All 322 NPC stat changes + 130+ respawn changes + 4-5 DT removals achieved purely through SQL on a stock EQEmu codebase + 1-2 surgical Lua/Perl edits.

**Phase 5b closes:**
- The **largest single HP gap in the project** (Aten Ha Ra 63× → 91% cut).
- The **largest single-phase NPC count** (125 NPCs scaled, driven by Yaemiu trash inclusion per Q4=A).
- The **last raid-tier zone** in Classic-Luclin scope.
- The **VT Key quest progression** (in conjunction with Phase 5a Emperor + Akheva chain + Glowing Orb dropper coverage).

After Phase 5b validation passes, the raid-scaling project is **COMPLETE**.

---

> **Next step:** Three user decisions required (Q67 Aten Destroy DT disposition, Q68 burrower-parasite Phase 5a leak, Q69 13-shard briefing correction). Lore-master + protocol-agent + config-expert consults in flight. Once advisor responses received and incorporated (and user resolves Q67-Q69), spawn the implementation team:
> - **data-expert** (Tasks LB1-LB8, LB10-LB12, LB15 — 125 npc_types UPDATEs + ~12 spawn2 UPDATEs + 0-1 DELETEs depending on Q67)
> - **config-expert** (Tasks LB13-LB14 — `#reloadworld` + smoke verify)
> - **infra-expert** (Task LB13b CONTINGENT — single zone-process restart for vexthal if `#reloadworld` doesn't flush spell list 229 cache; Q67=B only)
>
> Do NOT spawn c-expert, lua-expert, perl-expert, or protocol-agent — they have no Phase 5b implementation work.

---

## Addenda

### 2026-04-25 — Architect Phase 5b initial scope confirmation (DRAFT)

Architecture doc finalized as DRAFT pending three open advisor consults (lore-master, protocol-agent, config-expert; sent 2026-04-25) and three open user decisions (Q67-Q69). Default architect recommendations stand.
### 2026-04-25 — Config-expert Phase 5b consultation (CONFIRMED)

Config-expert delivered Phase 5b configuration sweep with zero new rules + zero config changes. Full transcript in `agent-conversations.md`. Summary:

1. **rule_values count = 1,112** (zero drift across all phases of the project — final tally).
2. **vexthal zone clean standard:** ruleset=1, instancetype=0, expansion=3, min_status=0. Zero `spawn_condition_values` rows. No condition-gated variants.
3. **No DZ / expedition configuration** for vexthal on this PEQ schema (consistent with all Phase 5a zones).
4. **No Vex Thal-specific rules.** `Zone:ZoneShardQuestMenuOnly = false` is a UI access gate, not a scaling parameter — no action.
5. **127 raid_target=1 NPCs in 158000-158200** matches architect's 130 total (3 are trigger NPCs raid_target=0).
6. **#reloadworld sufficient** — no zone-restart caveat by default. Q67=B alternative path may need vexthal restart for spell list 229 cache flush (low risk per Phase 2/5a precedent).
7. **MobHealth percentage** at 1.9M HP confirmed bigint(20) safe — no overflow on Titanium.
8. **Two flagged questions resolved by architect:**
   - **Q1 Akhevan Warders** (HP=901k, maxdmg=4) ARE combat targets. They're 0-base-damage casters relying on spell list 236 (Black Winds PBAE root, Silence PBAE silence, Lure tash, Fling knockback, Shadow Warding 5 self-buff). Add-wave summons by 6 specific Diabo/Thall scripts. 45 simultaneous Warders zone-wide at peak. Phase 5b LB6 cuts 901k → 80k each. Architecture's existing scope confirmed.
   - **Q1b Warder count CORRECTION:** config-expert's "8 NPCs (158087-158094)" included 158092 (Eom_Va_Dyn = Yaemiu) and 158093 (a_pool_of_shadows = Yaemiu) which are NOT Akhevan Warders. **Actual Warder count = 6** (158087/088/089/090/091/094). Captured in Decision #70.
   - **Q2 Thall Va Xakra respawn:** Both 158016 + 158125 get the same 24h endgame cut (140,616s → 86,400s) per Decision #8 tier-consistency. LB10 confirmed.
9. **Aten cycle respawn preservation:** Architect default = PRESERVE native 108-120 min cycle in `#Aten_Ha_Ra.pl/#Aten_Ha_Ra_.pl` (Decision #11 + #45 precedent). No perl-expert task added.
10. **DT sweep gap flagged:** Config-expert's filter at `base_value < -5000` did not surface spell 1948 "Destroy" (-100,000) in list 229 (which sits well below -5000 but should have been included in `<` predicate); architect's broader sweep found it independently. Q67 user decision surfaces — same spell ID as Phase 4b Kerafyrm list 489 (Decision #12 PRESERVED). Asked config-expert to re-verify.

**Verdict: Phase 5b is 100% SQL-only by default. Zero rule changes. Zero config changes. SQL-only pattern holds across the entire raid-scaling project (Phases 2-5b cumulative).**

### 2026-04-25 — Protocol-agent Phase 5b consultation (CONFIRMED — 1 DT FLAGGED)

Protocol-agent confirmed **zero Titanium client protocol impact** for Phase 5b. Full transcript in `agent-conversations.md`. Summary:

1. **Phase 5b is 100% server-side.** Zero new opcodes, no struct changes, no Titanium translation layer impact. Same conclusion as Phases 2-5a.
2. **vexthal is a standard static zone.** `player.lua` is 3 lines (illegal-bind guard only). Zero DZ/expedition API usage anywhere in `vexthal/`. `dynamic_zones` table 0 rows confirmed (Phase 5a holds).
3. **Zone change flow:** standard `ZoneChange_Struct` → `ZoneServerInfo_Struct` entry, same as every prior phase.
4. **Zero HP-percentage event hooks in vexthal:** No `setnexthpevent` / `EVENT_HP` usage anywhere in vexthal scripts. Boss HP freely scalable.
5. **Aten dual-form spawn-swap (Flag B):** Same pattern as Phase 5a Shei Vinitras. Both 158006 + 158096 must be HP UPDATE'd. Aten_Trigger entity-list spawn-swap is server-internal — no client wire impact.
6. **Akhevan Warders no spawn2 (Flag C):** Confirmed all Warder NPC IDs have `spawn2.respawntime=NULL` (script-summoned only). HP UPDATE on `npc_types.hp` propagates on next repop via standard path.
7. **Thall Va Xakra duplication (Flag D):** 158016 + 158125 both 900k HP, both spawn2-backed. Both HP-UPDATE per LB4. Server-side AI MoveTo() train-pull, no protocol impact.
8. **Yaemiu trash scope:** All in 158000-158086 / 158097-127 range, standard SQL UPDATE path. `akhevan_trigger.lua` proximity-trap spawner is server-side only (Ring War-pattern).
9. **Spirit of Akelha\`Ra preservation:** Standard `event_trade` / `SummonItem` sequence. Decision #30 precedent. 1M HP UNTOUCHED.
10. **Akhevan Warder count discrepancy** (architect cross-check): protocol-agent's "8 NPCs (158087-94)" included 158092 + 158093 — DB confirms these are Yaemiu, not Warders. Decision #70 captures correction.

**CRITICAL — Flag A: AE Death-Touch found.** Spell 1948 "Destroy" in list 229 (used by 158006 #Aten_Ha_Ra Destroy form):
- mana=0, cast_time=0, recast_delay=**-1 (unlimited)**, effect_base_value1=**-100,000**, effectid1=0 (SE_CurrentHP)
- **targettype=4 PBAE** — fundamentally different from prior phase DT removals (Cazic Touch + Touch of Vinitras were targettype=5 single-target)
- Wipes entire 1-3 player group simultaneously when in melee range
- Protocol impact of removal: zero (standard CombatDamage_Struct/Death_Struct path)
- List 229's other 3 spells (2157 Word of Command, 2164 Silence, 2167 Fling) MUST be preserved
- 158096 list 540 confirmed clean of spell 1948

**Protocol-agent recommended DELETE.** Architect concurs and **REVERSES Q67 default to Option B — DELETE**. The PBAE distinction is decisive: it wipes the entire small group with no recovery state. Decision #67 updated above. Task LB9 promoted from CONDITIONAL to default required.

**Verdict: Phase 5b is 100% server-side, SQL-only, with one mandatory `npc_spells_entries` DELETE (per architect's revised Q67 default). Zero opcode additions, zero struct changes, zero Titanium translation layer changes.**




### 2026-04-25 — Config-expert Phase 5b deep-Q response (12 questions)

Config-expert delivered comprehensive 12-question Phase 5b response aligning with prior consultation. Full transcript in `agent-conversations.md`. Highlights:

1. **Q1 rule_values count = 1,112** (zero drift). **Q12 cumulative project rule drift = ZERO across all phases (2 → 5b).**
2. **Q4 DT HIT CONFIRMED:** spell 1948 in list 229 — config-expert's deeper sweep matched protocol-agent's finding. min_hp=0, max_hp=0 (no HP gating — fires any time). DELETE recommended. **Q67 default already reversed to DELETE in commit 25f4e8b.**
3. **Q5 Yaemiu trash spell lists CLEAN.** Lists 1/2/8/9 are standard class libraries (largest -2,740 wizard DD, cast=7000ms, not DT). Lists 448/1472/1473 are empty. Zero DT-profile spells across all 104 Yaemiu.
4. **Q7 ZONE-RESTART CAVEAT APPLIES** for the Q67=B DELETE (was previously characterized as low-risk contingency by architect; config-expert confirms Phase 2 + Phase 5a precedent both required full zone restart for spell list cache flush). **Architecture updated 2026-04-25:** task LB13b PROMOTED from CONDITIONAL to default required. infra-expert added to default implementation team. Same expectation as Phase 2 PoSky Cazic Touch DELETE + Phase 5a Akheva Touch of Vinitras DELETE.
5. **Q10 spawn_conditions / spawn_condition_values both 0 rows for vexthal.** All 451 vexthal spawn2 rows use _condition=0, cond_value=1 (unconditional). No VP-style filtering, no Ring War wave conditions, no Sleeper-style dormant/active variants. Clean UPDATE path with zero accidental variants.
6. **Q11 Out-of-era exclusion:** Only 158095 #Aten_Trigger (L90, 50M HP, raid_target=0). Belt-and-suspenders guard: architecture's existing `raid_target=1` scope already excludes it; LB1 backup also confirms.
7. **Q6 Aten cycle respawn note:** Aten Ha Ra has NO spawn2 rows — post-death respawn is Perl-hardcoded at ~1.8-2.0h via `$spawntime = 6480 + rand(720)` in `#Aten_Ha_Ra.pl`. If 24h alignment is wanted for AHR, that's a perl-expert task (1-line edit). **Architect default = PRESERVE Phase 5b** (Decision #11 + Phase 5a #45 Thylex precedent).
8. **Q9 Backup naming pattern confirmed:** `_raid_scaling_luclin_b` suffix.
9. **Q3 dynamic_zones = 0 rows** — no expedition configuration.
10. **Q8 Titanium MobHealth at 1.9M HP** — bigint(20) safe, percentage-based render. Confirmed.
11. **Q2 vexthal zone:** ruleset=1, expansion=3, insttype=0, version=0. Default ruleset.

**Verdict: Q67=B DELETE required + zone restart required.** Implementation impact: data-expert (LB1-LB12, LB15) + config-expert (LB13, LB14) + **infra-expert (LB13b — required vexthal zone restart, NOT contingent)**.

**Q12 cumulative project rule drift across Phases 2/3/4a/4b/5a/5b: ZERO rule_values changes.** Entire raid-scaling project has been data-layer: ~322 npc_types UPDATEs + ~130 spawn2 UPDATEs + 5 npc_spells_entries DELETEs (Phase 2 = 3 Cazic Touch + Phase 5a = 1 Touch of Vinitras + Phase 5b = 1 Destroy) + 1 Perl edit (Phase 5a #EmpCycle.pl). Confirms architect's "100% SQL with one Perl edit" project-closure framing.


### 2026-04-25 — Lore-master Phase 5b consultation (CONFIRMED — APPROVED with 3 DB-disagreed flags)

Lore-master delivered comprehensive Phase 5b sign-off. Files: `lore-master/vt-internals.md`, `lore-master/13-shard-quest.md`, `lore-master/luclin-chains.md` (Section 10 appended). Full transcript in `agent-conversations.md`. Highlights:

1. **Boss progression: 12 named bosses with enforced kill order via Akhevan Warders.** Mandatory sequence (per lore-master): Va_Dyn_Khar → Thall Va Xakra dual → Kaas Thox Xi Ans Dyek "Blob 1" → Diabo Xi Va + Xin → Diabo Xi Xin Thall → Thall Va Kelun → Diabo Xi Va Temariel + Thall Xundraux → Va Xi Aten Ha Ra (mini-Aten) → Kaas Thox Xi Aten Ha Ra "Blobs" → Aten Ha Ra (final).
2. **13-shard clarification:** Decision #10 intent = full progression preserved (10 Lucid Shards + 3 components = 13 acquisition items total). Q69 architect framing matches lore-master canonical interpretation.
3. **Class epics: NO Epic 1.0 quest terminates in VT.** Decision #14 unaffected.
4. **Lore Flag 4 CONFIRMED — Kaas Thox Xi Aten Ha Ra (158007) dual spawn2.** Architecture LB10 already covers both rows.
5. **Lore Flag 5 CONFIRMED — Aten Silence of Shadows long-fight mana drain.** spell 2164 in list 229 + 540, 30s recast, effect 96 silence. Architect adds game-tester smoke note: 12 silence intervals during a 6-min Aten 180k fight; small group must time mana cooldowns. Not a scope blocker; HP scaling proceeds per Decision #11.
6. **Lore Flag 6 CONFIRMED — Yaemiu gating mobs.** Eom/Pli/Zun Thall/Zethon suffix can gate 20+ add pulls. Architecture's Yaemiu HP cuts (LB7) bring 60-101k → 14-25k, a 4-5× reduction that helps multi-add scenarios. Game-tester monitoring required.

**Three lore flags DB-disagreed** (architecture LB6/LB9/LB5 unchanged):

7. **Flag 1 DB DISAGREES — Akhevan Warders ARE targetable combat adds, not "non-targetable banishers."** DB: 158087-094 have `raid_target=1`, `no_target_hotkey=0`, full combat stats (901k HP, spell list 236, npcspecialattks `QUMCNIDABfWO` includes B=Banish ability so they CAST banish, special_abilities `7,1^12,1^...` includes flag 12 Banish enabled). They are **combat targets that CAN cast banish on aggro**, not "non-targetable banishers." Lore-master flag reflects live-era pre-EQEmu memory; PEQ DB implements them as killable adds (matches protocol-agent's prior analysis). **Architecture LB6 unchanged — 6 Akhevan Warder NPC IDs scaled 901k → 80k.**

8. **Flag 2 PARTIAL — Va_Dyn_Khar respawn 21,600s (6h) confirmed in DB.** Audit said "respawn already short"; live-era 30min-1h is era memory; PEQ default is 6h. Architect default = PRESERVE 21,600s (Decision #11 + audit). User can surface a Q for faster Palace Key cycle if desired (not currently in Q67-Q69).

9. **Flag 3 DB DISAGREES — No Complete Heal in Diabo Xi Xin Thall (158012) spell list 237.** DB query confirms list 237 contains ONLY spell 2164 Silence of the Shadows. `#Diabo_Xi_Xin_Thall.pl` script only manages Warder spawn/depop, no `quest::set_hp` heal triggers. Lore-master flag is live-era memory; PEQ doesn't implement CH on this boss. **Architecture LB9 stays scoped to spell 1948 Destroy in list 229 only — no second DELETE.**

**LORE SIGN-OFF:** Phase 5b scope APPROVED 2026-04-25 with documented architecture pushbacks on Flags 1/3 (DB disagrees) and Flag 2 (PEQ default preserved).

**Architecture sign-off status — 3 of 3 advisor consultations CONFIRMED 2026-04-25:**
- config-expert (initial sweep + deep 12-Q response): aligned; LB13b promoted from CONTINGENT to default required
- protocol-agent (Flag A PBAE DT + full 13-Q response): aligned; Q67 reversed PRESERVE → DELETE; **Q12 spawn2-zone disagreement OPEN** pending protocol-agent re-verify (architect's two independent DB queries show all 1,089 rows in vexthal, not overthere/nurga/dulak)
- lore-master (VT deep-dive): APPROVED with 3 lore flags DB-disagreed (architecture LB6/LB9 unchanged; LB5 preserved per Decision #11)

Architecture is READY for user decisions Q67/Q68/Q69, then implementation dispatch. Same default team as Phases 2-5a (data-expert + config-expert) plus infra-expert (LB13b zone restart required).

