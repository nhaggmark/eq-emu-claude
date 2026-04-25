# Phase 5b — Vex Thal DB Investigation

> **Author:** architect
> **Date:** 2026-04-25
> **Phase:** 5b (FINAL — closes raid-scaling project)
> **Workspace:** `architect/context/luclin-b-db-investigation.md`
> **Source dumps:** `claude/tmp/raid-scaling/luclin-b/01-09*.tsv`

---

## 1. Vex Thal NPC inventory (158xxx range)

**Total NPCs:** 130 in 158000-158999 range, all `vexthal`-zoned per spawn2.

| Bucket | Count | Notes |
|---|---|---|
| Boss-tier (hp ≥ 600k, raid_target=1) | **13** | Full Phase 5b boss roster |
| Akhevan Warder adds (raid_target=1, hp 901k) | **6** (158087/88/89/90/91/94) — NOT 8 as briefing assumed | Script-spawned as adds; no spawn2 |
| Yaemiu raid_target=1 mid-tier (hp 50-110k) | **104** | 75 spawn2-backed + 29 trap-only |
| Trigger / control NPCs (raid_target=0) | 4 | 158095 (Aten_Trigger 50M HP), 158128 (shade_trigger 1913 HP), 158129 (akhevan_trigger 1913 HP), and minor placeholder pairs |
| Misc (other raid_target=0 trash, near-zero HP) | ~3 | excluded |

## 2. Phase 5b boss roster — confirmed via DB (sources: tsv 02 + tsv 03)

| ID | Name | L | HP | mindmg-maxdmg | MR | special_abilities | spell_list | spawn2 | respawn (s) | Notes |
|----|------|---|---|---|---|---|---|---|---|---|
| **158006** | #Aten_Ha_Ra | 66 | 1,901,500 | 294-1054 | 162 | SERTQMCNIDf (rampage 13,1) | **229 (with Destroy DT)** | NONE (script) | — | "Destroy Aten" — spawned by Aten_Trigger when bosses still up |
| **158096** | #Aten_Ha_Ra_ | 66 | 1,901,500 | 294-1054 | 144 | SERTQMCNIDf (rampage 13,1) | **540 (NO Destroy)** | NONE (script) | — | "non-Destroy Aten" — spawned by Aten_Trigger after full boss clear |
| **158007** | #Kaas_Thox_Xi_Aten_Ha_Ra | 66 | 1,900,000 | 320-**1650** | 110 | SERQMCNIDf | 231 | 2 rows | 468,720 | DAMAGE OUTLIER (1650 max) |
| **158008** | #Thall_Va_Kelun | 66 | 1,825,000 | 240-1000 | 128 | SRQMCNIDf | 232 | 1 row | 468,720 | Spawns Akhevan_Warder 158090 ×2 on death |
| **158010** | #Diabo_Xi_Va_Temariel | 66 | 1,706,000 | 165-**1400** | 125 | SRFMCNIDf | 238 | 1 row | 468,720 | DAMAGE OUTLIER. Spawns 158091 ×5 |
| **158009** | #Va_Xi_Aten_Ha_Ra | 66 | 1,601,500 | 304-1254 | 144 | SERQMCNIDf | 234 | 1 row | 468,720 | Spawns 158094 ×14 (heaviest add wave) |
| **158012** | #Diabo_Xi_Xin_Thall | 66 | 1,501,500 | 180-750 | 106 | SRTMCNIDfU (rampage 20) | 237 | 1 row | 468,720 | Spawns 158089 ×7 |
| **158011** | #Thall_Xundraux_Diabo | 66 | 1,475,000 | 274-654 | 185 | SERFQUMCNIDf (rampage 20) | 1353 | 1 row | 468,720 | Spawns 158091 ×5 |
| **158013** | #Kaas_Thox_Xi_Ans_Dyek | 66 | 1,201,500 | 270-650 | 120 | SEFQUMCNIDf (rampage 15) | 230 | 1 row | 468,720 | Spawns 158087 ×2 |
| **158015** | #Diabo_Xi_Xin | 66 | 1,106,500 | 250-**1200** | 164 | SERMCNIDf (rampage 25) | 0 (none) | 1 row | 468,720 | DAMAGE OUTLIER. Spawns 158088 ×5 |
| **158014** | #Diabo_Xi_Va | 66 | 1,050,000 | 274-654 | 185 | SRFUMCNIDf | 239 | 1 row | 468,720 | Spawns 158088 ×5 (shared add pool with 158015) |
| **158016** | #Thall_Va_Xakra (south) | 60 | 900,000 | 285-950 | 125 | SERMCNIDf (rampage 30) | 233 | 1 row | 140,616 | Train-pull adds via 27 spawn IDs |
| **158125** | #Thall_Va_Xakra (north) | 60 | 900,000 | 285-950 | 125 | SERMCNIDf (rampage 30) | 233 | 1 row | 140,616 | Train-pull adds via 27 spawn IDs |
| **158087-091, 094** | Akhevan_Warder | 60 | 901,000 | 0-4 | 157 | QUMCNIDABfWO | 236 | NONE | — | 6 NPCs total. Add-wave 0-dmg melee (Black Winds 35s recast PBAE root, Lure of Shadows 15s tash). Tied to specific bosses (see column "Spawns" above). |
| **158081** | Va_Dyn_Khar | 66 | 600,000 | 265-455 | 120 | SEMCNIf (rampage 15) | 0 | 1 row | 21,600 (6h short-tier) | **Drops Palace Key (item 8010)** — gates door 8010, the only keyed door in vexthal |

**Audit-flagged HP gap:**
- Aten Ha Ra dual at 1,901,500 = **63× scaled-named L66 target ~30k** (largest gap in entire project)
- Kaas Thox Xi Aten Ha Ra at 1,900,000 + 1,650 max dmg = 63× HP + worst damage
- Diabo Xi Va Temariel at 1,706,000 + 1,400 max dmg = 57× HP + 2nd worst damage
- Va_Dyn_Khar at 600k = 20× HP

## 3. Death-touch sweep — VT spell lists (source: tsv 09)

**Sweep query:** `SELECT spells where mana=0 AND cast_time=0 AND effect_base_value1 <= -10000 across npc_spells_id IN (any vexthal-NPC-used list)`

| Spell ID | Name | Effect | Mana | Cast | Recast | Found in lists |
|---|---|---|---|---|---|---|
| **1948** | **Destroy** | -100,000 HP | 0 | 0ms | 0s | **List 229 ONLY** (used by **158006 #Aten_Ha_Ra "Destroy Aten" form**) |

**ZERO other DT-profile hits** across all VT spell lists. The only death-touch in vexthal is Destroy in list 229, and it is explicitly the "Destroy Aten" form that the Aten_Trigger script gates behind the "VT bosses still up" condition.

**Cross-check — list 540 (non-Destroy Aten 158096):** spells 2157 (Word of Command, +3000 HP heal), 2164 (Silence), 2167 (Fling). **No Destroy.**

**Comparison to Phase 4b (Sleeper):** Spell 1948 Destroy is the SAME spell ID as Kerafyrm's signature DT in spell list 489 (Phase 4b Decision #12 — UNTOUCHED). Same protective gate logic: "if you do something wrong, you face Destroy."

**VT bosses' standard combat spells (sample):**
- 2144 Shadow Warding 5 (Akhevan Warders self-buff, +83 effect)
- 2157 Word of Command (used by Aten 158096 + Kaas Thox 158007 — 30s recast self-heal +3000 HP)
- 2162 Black Winds (Warders — PBAE 60-range, 35s recast, 4.8s cast, root)
- 2163 Lure of Shadows (Warders — 5s cast tash, 15s recast)
- 2164 Silence of the Shadows (Warders + Aten 158096 — PBAE 80-range silence, 30s recast)
- 2167 Fling (multiple lists — 200-range knockback, 45s recast)

## 4. Aten Ha Ra dual-form mechanic — FULL DECODED

**Source: `vexthal/#Aten_Trigger.pl` (158095, 50M HP controller, 259200s respawn, single spawn2 row)**

```perl
sub EVENT_TIMER {  # fires every 60s
  if ($timer eq "aten") {
    if (!defined $qglobals{aten}) {  # qglobal "aten" not set = no Aten currently up
      if (!$entity_list->IsMobSpawnedByNpcTypeID(158014) && # Diabo Xi Va
          !$entity_list->IsMobSpawnedByNpcTypeID(158010) && # Diabo Xi Va Temariel
          !$entity_list->IsMobSpawnedByNpcTypeID(158015) && # Diabo Xi Xin
          !$entity_list->IsMobSpawnedByNpcTypeID(158012) && # Diabo Xi Xin Thall
          !$entity_list->IsMobSpawnedByNpcTypeID(158013) && # Kaas Thox Xi Ans Dyek
          !$entity_list->IsMobSpawnedByNpcTypeID(158007) && # Kaas Thox Xi Aten Ha Ra
          !$entity_list->IsMobSpawnedByNpcTypeID(158008) && # Thall Va Kelun
          !$entity_list->IsMobSpawnedByNpcTypeID(158011) && # Thall Xundraux Diabo
          !$entity_list->IsMobSpawnedByNpcTypeID(158009)) { # Va Xi Aten Ha Ra
       quest::depopall(158006);                    # remove Destroy Aten if present
       quest::spawn2(158096,0,0,1412,0,248.63,384); # spawn non-Destroy Aten
       quest::depop_withtimer();
      } elsif (!$entity_list->IsMobSpawnedByNpcTypeID(158006)) {
       quest::spawn2(158006,0,0,1412,0,248.63,384); # spawn Destroy Aten if not present
      }
    }
  }
}
```

**Behavior:**
- 9 boss IDs gate the Aten form (NOT including 158016/158125 Thall Va Xakra adds — they are pre-VT-inner zone-trash boss tier only).
- If ANY of the 9 gating bosses is alive: **158006 Destroy Aten** spawns (1.9M HP + Destroy -100k DT instakill).
- If ALL 9 dead: **158096 non-Destroy Aten** spawns (1.9M HP, no DT, includes self-heal Word of Command +3000).
- After Aten 158006 dies: `EVENT_DEATH_COMPLETE` sets `qglobals.aten=1` for `M$spawntime` (rand(720) + 6480 seconds = 108-120 minutes lockout).
- After Aten 158096 dies: same qglobal lockout.
- 158096 has a 172,800s = 48h built-in `depop` timer if not killed.

**Phase 5b architectural implication:** The Destroy DT in list 229 is **a script-gated punishment mechanism, not a baseline encounter blocker**. A small group that full-clears the 9 gating bosses faces 158096 (no Destroy). A small group that engages Aten before clearing faces 158006 (with Destroy). **This is a MUCH softer constraint than Phase 4b Kerafyrm** (whose Destroy is unavoidable on engage).

## 5. Akhevan Warder add-wave map (sources: vexthal scripts 6 boss .pl files)

| Boss (script) | Warder NPC ID | Warder count | Pattern |
|---|---|---|---|
| 158013 #Kaas_Thox_Xi_Ans_Dyek | 158087 | 2 | Spawned at boss spawn; depop on boss death |
| 158014 #Diabo_Xi_Va | 158088 | 5 | Spawned at boss spawn; depop on boss death |
| 158015 #Diabo_Xi_Xin | 158088 | 5 | Same Warders (shared pool with 158014) |
| 158012 #Diabo_Xi_Xin_Thall | 158089 | 7 | Spawned at boss spawn; depop on boss death |
| 158008 #Thall_Va_Kelun | 158090 | 2 | Spawned at boss spawn; depop on boss death |
| 158010 #Diablo_Xi_Va_Temariel | 158091 | 5 | Spawned at boss spawn; depop on boss death |
| 158011 #Thall_Xundraux_Diabo | 158091 | 5 | Same Warders (shared pool with 158010) |
| 158009 #Va_Xi_Aten_Ha_Ra | 158094 | 14 | Spawned at boss spawn; depop on boss death |

**Total Warders spawned across the zone simultaneously when all bosses up:** 2 + 5 + 5 + 7 + 2 + 5 + 5 + 14 = **45 Warder add-mobs** at 901k HP each. This is a major small-group blocker — **15 seconds engaging Va_Xi_Aten_Ha_Ra summons 14 Warders at 901k HP**. Phase 5b MUST scale Warder HP.

**Note:** Warders share npc_type IDs across multiple bosses, so a single HP UPDATE on (e.g.) 158088 affects both Diabo Xi Va (158014) and Diabo Xi Xin (158015) simultaneously — efficient.

## 6. Thall Va Xakra train-pull mechanic (158016 / 158125 .lua scripts)

Both Thall Va Xakras (south wing 158016, north wing 158125) **DO NOT spawn adds** — they call `MoveTo()` on 27 hard-coded `spawn_id` references each, pulling existing Yaemiu trash spawn points to the boss's location every 30s. **Trash-train mechanic.** No HP UPDATE on Yaemiu trash needed for this script to function — the script depends on spawnpoint IDs (ints 17475-17677), not HP thresholds.

## 7. Yaemiu trash spawn topology (source: tsv 03 + tsv 05)

| Source | Count | Respawn | Mechanism |
|---|---|---|---|
| Standing spawn2 (zone trash) | ~75 NPCs | 1710-3240s (typically 1710s = 28.5min, 3240s = 54min) | Patrols, room defenders |
| `158128 shade_trigger` proximity traps (1800s respawn × 67 spawn2 rows) | ~29 NPCs (chosen randomly per trap) | 30 min depop | Player walks within 40-unit prox → random Yaemiu spawn; depop after 30 min |
| `158129 akhevan_trigger` proximity traps (1800s respawn × 18 spawn2 rows) | Random Yaemiu pool | 30 min depop | Same proximity-trap mechanic |
| `158016/158125 Thall Va Xakra` train-pull | 27 each (existing spawnpoints, no new spawns) | n/a | Existing standing-spawn Yaemiu pulled to boss aggro |

**Yaemiu HP tier distribution (104 raid_target=1 NPCs):**
- 100-101k HP: 8 NPCs (Eom_Centien_Xakra/Va_Dyn — top tier elite)
- 90-91k HP: 3 NPCs (a_writhing_shadow, Zun_Va_Dyn variants)
- 80-84k HP: 18 NPCs (Eom-tier and Pli-tier)
- 70-76k HP: 38 NPCs (Eom-Senshali, Eom-Thall, etc.)
- 60-66k HP: 21 NPCs (Pli-tier mostly)
- 50-55k HP: 16 NPCs (Qua/Zov/Zun lower-tier)

## 8. Spawn2 respawn distribution (source: tsv 03 + tsv 05)

| respawntime (s) | NPC count | HP range | Tier |
|---|---|---|---|
| 1080 | 2 | 60-81k | Short-tier farmable (Yaemiu) |
| 1440 | 1 | 91k | Short-tier |
| 1710 | 70 | 45-101k | Standard Yaemiu trash respawn (28.5m) |
| 1800 | 2 | 1913 | shade_trigger / akhevan_trigger (TRAP CONTROLLERS, not raid mobs) |
| 2280 | 7 | 70-101k | Yaemiu mid-tier |
| 2700 | 1 | 65k | Yaemiu |
| 3240 | 37 | 45-100k | Yaemiu standard (54min) |
| 4320 | 4 | 70-84k | Yaemiu |
| **21,600** | **1** | **600k** | **Va_Dyn_Khar (already 6h short-tier — no change needed)** |
| **140,616** | **2** | **900k** | **Thall Va Xakra dual (39h — needs 24h cut)** |
| 259,200 | 1 | 50M | Aten_Trigger 158095 (controller) — excluded |
| **468,720** | **9** | **1.05M-1.9M** | **9 VT inner bosses (130h — needs 24h cut)** |

**Phase 5b respawn UPDATE scope:**
- 9 inner-VT boss spawn2 rows (158007/158008/158009/158010/158011/158012/158013/158014/158015): 468,720s → **86,400s** (24h endgame per Decision #8)
- Note: 158007 Kaas Thox Xi Aten Ha Ra has **2 spawn2 rows** at 468,720s — both updated.
- 2 Thall Va Xakra spawn2 rows (158016 + 158125): 140,616s → **86,400s** (24h)
- Va_Dyn_Khar 158081 already at 21,600s (6h) — **PRESERVE** (audit said "already short" + drops Palace Key, short respawn protects key cycle)
- Aten Ha Ra (158006/158096): NO spawn2 rows — script-spawned by 158095 with 60s timer + 108-120m post-kill qglobal lockout. **NOT in spawn2 UPDATE.** Cycle timer lives in `#Aten_Ha_Ra.pl:25`/`#Aten_Ha_Ra_.pl:25` (`6480 + rand(720)` = 108-120 min). Phase 5a Decision #11 precedent (script-spawned cycle timers preserved) applies.
- Akhevan Warders: NO spawn2 rows — script-spawned. **NOT in spawn2 UPDATE.**
- 75 Yaemiu trash spawn2 rows: per Decision #2 (trash unchanged) **NOT in spawn2 UPDATE** — but per Q4 user decision (Yaemiu IN scope), HP UPDATE is the lever, not respawn. Architect proposes: trash respawns are tuned for natural attrition gameplay, leave as-is.

**Total spawn2.respawntime UPDATE rows: ~12** (9 inner bosses, 2 Thall Va Xakra, ±1 for the second 158007 row).

## 9. Doors and key drops in vexthal

**1 keyed door** (`keyitem=8010`); 100 unkeyed doors (clickable navigation/visual only).

| Door | Key item | Source mob |
|---|---|---|
| 1 (palace inner door) | 8010 Palace Key | **158081 Va_Dyn_Khar** (lootdrop 20537) |

**Phase 5b implication:** Va_Dyn_Khar HP cut (600k → ~60k) directly enables small-group inner-palace access. One of the most user-relevant scaling cuts in the phase.

## 10. VT Key Quest — actual state vs. user briefing's "13-shard" framing

**CRITICAL CORRECTION SURFACED:**
The Phase 5b user briefing said: _"13-shard VT key quest (Q7 = keep all 13 per Decision #10)"_. **This is incorrect by lore-master Section 1 + DB items query.**

**Actual VT key composition (source: `lore-master/luclin-chains.md:30-77` + DB items query):**

| Phase | Component | Item ID(s) | Source(s) | Phase 5b scope? |
|---|---|---|---|---|
| 1 | **10 Lucid Shards** (NOT 13) | 22185-22194 | Non-raid mobs in 10 Luclin zones (sun reavers, Shik`nar guards, thought horror trash, etc., all raid_target=0, sub-15k HP) | **OUT — non-raid sources, no scaling needed** |
| 2 | Shadowed Scepter Frame | 17323 | Akheva Sacrificed Remains chain → Spirit of Akelha`Ra (179144) — **Decision #57: 179144 PRESERVED untouched as turn-in NPC** (Phase 5a) | **OUT — already addressed Phase 5a** |
| 3 | Planes Rift | 9410 | A_shissar_wraith 162210 (Emperor Ssraeshza death event spawn, post-mortem) — already accessible per Phase 5a Emperor cut | **OUT — Phase 5a already unblocked** |
| 4 | Glowing Orb of Luclinite | 22196 | Drops from MANY Luclin raid bosses — all already scaled in Phase 5a (Vyzh\`dra Cursed 90k, Lcea Katta 80k, Itraer Vius 80k, etc.). PLUS one audit-leak: **164089 A_burrower_parasite (thedeep, 840k HP, raid_target=1, script-spawned, audit-missed in Phase 5a)** | **AUDIT-LEAK FLAG — see §13** |
| Final | Combine in Unadorned Scepter | 17324, 22198 | Player tradeskill | n/a |

**Architect resolution:** The user briefing's "13 shards" appears to conflate the 10 Lucid Shards + 3 component items (Frame + Rift + Orb) into "13 shard-tier items." The actual mechanic is `10 + 3 = 13 components` but only **10 are formally called "shards"**. Phase 5b does NOT need to touch any Lucid Shard sources (all non-raid, accessible already), and the 3 component sources are mostly addressed by Phase 5a (Frame chain + Planes Rift + Glowing Orb) — except for **one audit-missed Glowing Orb dropper (164089 A_burrower_parasite, thedeep)** that should be flagged.

**This contradicts the briefing's Q7 framing of "keep all 13 shards" → architect surfaces as user-decision item.**

## 11. zone table for vexthal (source: tsv config-expert pending)

| short_name | long_name | expansion | ruleset | version | instancetype |
|---|---|---|---|---|---|
| vexthal | Vex Thal | 3 (Luclin) | 1 (default) | 0 | (column doesn't exist on this PEQ schema — same as Phase 5a) |

**Confirmed:** Standard ruleset, Luclin expansion, no DZ. Pattern-aligned with all Phase 5a zones.

## 12. Out-of-era / fabled / event-control NPC sweep

| ID | Name | L | HP | Status |
|---|---|---|---|---|
| **158095** | #Aten_Trigger | 90 | 50,000,000 | EXCLUDE — controller NPC (not a fight target). Same posture as Phase 5a 162260 EmpCycle controller / 162269 keycheck. |
| **158128** | shade_trigger | 55 | 1,913 | EXCLUDE — proximity-trap controller. raid_target=0. |
| **158129** | akhevan_trigger | 55 | 1,913 | EXCLUDE — proximity-trap controller. raid_target=0. |
| (no Fabled in 158xxx range) | — | — | — | OOE filtering applies via `min_expansion`/`max_expansion` per config-expert Phase 5a confirmation. |
| (no L73+ in 158xxx range) | — | — | — | All bosses L60-66 in-era. |

**No 158xxx-range Fabled/LoN/post-Luclin NPCs.** Cleaner than Phase 5a (which had 163051/52 LoN, 154161 Fabled, 176111 post-Luclin).

## 13. Phase 5a audit-leak — A_burrower_parasite 164089 (thedeep)

**Discovered during Phase 5b cross-reference of Glowing Orb sources.**

| ID | Name | Zone | L | HP | raid_target | spell list | spawn2 | Phase 5a status |
|---|---|---|---|---|---|---|---|---|
| 164089 | A_burrower_parasite | thedeep | 63 | **840,000** | 1 | 0 (none) | NONE (script-spawned) | **NOT included in Phase 5a scope** despite being a Glowing Orb dropper |

**Source:** `akk-stack/server/quests/thedeep/A_burrower_parasite.pl` exists as a script (suggests script-spawned; not on standing spawn2).

**Architect recommendation:** Flag as **post-Phase 5a/pre-Phase 5b deliverable for user decision**. Two options:
- **Option A: Address in Phase 5b** — include 164089 in the npc_types UPDATE batch (840k → ~90k HP, matching Thought Horror Overfiend's Phase 5a target). Logical given the same zone (thedeep) already has Phase 5a scaling (164078 Thought Horror Overfiend → 90k).
- **Option B: Defer to a Phase 5a fixup ticket** — address as a separate small ticket (one UPDATE) outside Phase 5b's vexthal scope.

**Architect default: Option A — include in Phase 5b** (cleaner scope-closure for the entire raid-scaling project; already-flagged audit gap; one extra UPDATE).

## 14. Yaemiu scaling proposal

Per Q4 user decision (INCLUDE Yaemiu in Phase 5b scope) and the audit's "raid-tier-but-trash" framing, architect proposes a level-tiered HP cut:

| Yaemiu prefix | L | Current HP | Phase 5b target | Cut % |
|---|---|---|---|---|
| Eom (L66) | 66 | 70-101k | **20-25k** | -71% to -75% |
| Pli (L64) | 64 | 55-100k | **18-22k** | -67% to -78% |
| Zun (L61) | 61 | 50-90k | **15-18k** | -70% to -80% |
| Zov (L58) | 58 | 50-82k | **12-15k** | -70% to -82% |
| Qua (L55) | 55 | 50-80k | **10-12k** | -75% to -85% |
| a_living_shadow / a_pool_of_shadows / a_writhing_shadow / a_corporeal_shadow / a_mass_of_shadows (L55-66) | 55-66 | 65-91k | **15-20k** | -75% to -82% |

**Rationale:**
- Aligns Yaemiu with Phase 5a Akheva elite-named tier (Sheleric Vis 30-35k post-scale at L60-62 / Xaui Tatrua 30k at L60). VT Yaemiu sit ABOVE Akheva-elite tier (L55-66 vs L60-62, deeper HP).
- L66 Eom-tier ends up at 20-25k, just under scaled-named L66 baseline (~30k). Yaemiu retain "elite trash" feel — harder than zone-trash, easier than scaled-named.
- Damage UNCHANGED — Yaemiu max damage is 200-450, already small-group-tractable.
- Respawn UNCHANGED — natural farming cadence preserved.

**Damage cap:** None of the 104 Yaemiu carry damage outliers per audit. Skip damage UPDATEs.

**Spell list 2/8/9 audit:** Several Yaemiu use spell lists 2, 8, 9 (basic combat — NOT DT-profile per §3 sweep). No DT removal needed.

## 15. Backup table scope estimate

| Backup table name | Source | Approx rows |
|---|---|---|
| `npc_types_backup_raid_scaling_luclin_b` | npc_types snapshot for all in-scope NPCs | **~125 rows** (13 inner bosses + 6 Warders + 1 Va_Dyn_Khar + 104 Yaemiu + 1 burrower-parasite if Option A = 125) |
| `spawn2_backup_raid_scaling_luclin_b` | spawn2 snapshot for affected rows | **~110 rows** (~12 boss respawn UPDATEs + 75 Yaemiu standing rows + 24 trap-spawn rows + 1 Va_Dyn_Khar + 2 Aten_Trigger/triggers for safety) |
| `npc_spells_entries_backup_raid_scaling_luclin_b` | Pre-DELETE Destroy DT row | **0-1 rows** (depends on user Decision: keep DT script-gated, or DELETE) |

