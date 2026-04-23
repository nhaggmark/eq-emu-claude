# Raid Scaling — Architecture & Implementation Plan (Phase 4b: Velious ToV + Sleeper's Tomb + Vulak + AoW)

> **Feature branch:** `feature/raid-scaling`
> **PRD:** `game-designer/prd.md`
> **Audit:** `game-designer/raid-scaling-audit.md` (Velious section lines 1510-1940; ToV line 1625; Sleeper's Tomb line 1681; AoW/Vulak lines 1568, 1648-1654)
> **Lore catalog:** `lore-master/velious-chains.md` (Sections 3, 4, and 7 — ToV/Sleeper keying + Sleeper Awake boundary)
> **Phase 2 reference:** `architect/architecture.md` (Classic — pattern)
> **Phase 3 reference:** `architect/kunark-architecture.md`
> **Phase 4a reference:** `architect/velious-a-architecture.md` (most-recent pattern — Phase 4b mirrors this structure)
> **DB investigation:** `architect/context/velious-b-db-investigation.md` (NPC ID confirms, Kerafyrm awake chain trace, death-touch sweep)
> **Author:** architect
> **Date:** 2026-04-23
> **Status:** Draft — awaiting user sign-off on 3 clarifying decisions (see "Items flagged to user"). Protocol-agent Phase 4b cleared 2026-04-22. Config-expert + lore-master consultations in flight; architect proceeding with draft under Phase 4a pattern carryover.
> **Scope:** **Phase 4b ONLY.** Temple of Veeshan proper (16 dragon lords + 16 NToV mid-tier named), Sleeper's Tomb (4 Ancients + Progenitor + Final Arbiter main & alt + Master of the Guard + Milas + 4 Warders), Avatar of War (113457), Vulak`Aerr (124155). **Out of scope permanently (Decision #12):** Kerafyrm / The Sleeper / Sleeper Awake event.

---

## Executive Summary

Phase 4b scales the Velious endgame tier — Temple of Veeshan proper, Sleeper's Tomb, Avatar of War, and Vulak`Aerr — using the **same 100% SQL pattern established in Phases 2, 3, and 4a**. Zero script edits. Zero rule changes. Zero C++.

This is the **"peak mastery" tier** per Decision #1 — the hardest in-era fights. Cuts are aggressive relative to mid-tier (Phase 4a cut ~70-77%) but respect Decision #11's signature-mechanic preservation. Endgame respawn per Decision #8 is 24h (86,400s), the longest respawn tier in the project.

**Four significant differences from Phase 4a:**

1. **Endgame respawn tier (24h).** Phase 2/3/4a used 6-12h respawn. Phase 4b's endgame content (Decision #8) uses 86,400s = 24h. Applied to 38 spawn2 rows (ToV dragons + Midayor cluster + Sleeper's Tomb bosses). Mid-tier named already at 64,800s (18h) stay unchanged.

2. **Kerafyrm awake event — architected isolation, not avoidance.** The 4 Warders (128090-93) are in scope per audit. A full code trace of `akk-stack/server/quests/sleeper/*.pl` confirmed the Sleeper Awake trigger is **behavioral** (kill all 4 Warders → `signalwith(128094, 66)` → Kerafyrm spawns), NOT HP-threshold-based. Scaling Warder HP from 200k → 60k makes them tractable for a small group but does NOT touch the trigger chain. Kerafyrm (128089/94/95), his "Destroy" death-touch spell (spell 1948 in list 489), and The Sleeper (128094) are untouched per Decision #12. See §2 Kerafyrm Isolation Proof for full chain analysis.

3. **Script-spawned endgame bosses (AoW 113457, Vulak 124155) have NO spawn2 rows.** AoW closes the Phase 4a Kael chain (Statue→Idol→AoW); Phase 4b scales AoW directly. Vulak is spawned by `Thylex_of_Veeshan.pl` on a 60-second tick when all 6 altar dragons (Mirenilla, Nevederia, Feshlak, Aaryonar, Kreizenn, Vyemm) are absent. Scaling the 6 altar dragons propagates Vulak accessibility without any script edit.

4. **More NToV raid_target=1 NPCs than audit listed.** DB sweep revealed 16 mid-tier named (8 Midayor cluster L60 + 8 L65-66 named) within the 100-140k HP band. Audit recommended 60-70% HP cut to 40-50k. All 16 are in scope. **The 4 Defender types (124050/51/52/79, L65, 120k HP, 3-5h respawn)** are raid_target=1 but explicitly excluded per audit line 1673-1677 ("elite trash in ToV — out of scope") and Decision #2 (trash/named untouched).

**Change footprint:**
- **~47 `npc_types` HP/damage UPDATEs** — 16 ToV dragon lords + 16 NToV mid-tier named + 13 Sleeper's Tomb bosses (including 4 dormant Warders) + AoW + Vulak
- **~35-38 `spawn2.respawntime` UPDATEs** to 86,400s (24h endgame tier)
- **0** `npc_spells_entries` changes — sweep returned only one signature mechanic (Vyskudra Lightning Breath) and Kerafyrm's untouched "Destroy"
- **0** Lua or Perl script edits
- Backup tables: `npc_types_backup_raid_scaling_velious_b`, `spawn2_backup_raid_scaling_velious_b`

**No C++ changes. No `rule_values` changes. No `eqemu_config.json` changes. No `.env` changes.** Protocol-agent confirmed zero client-visibility impact (2026-04-22 log, addendum §1). Config-expert Phase 2/3/4a pattern carries forward (consultation in flight; default posture: zero-change).

**User-decision items surfaced** (see "Items flagged to user"):
- **Decision #36** — Warder scaling acknowledgment (scaling Warders makes the Sleeper Awake event reachable by small group; Kerafyrm himself is untouched; user must acknowledge this expansion of reachability despite Decision #12 preserving the event)
- **Decision #37** — Defenders cluster exclusion (architect recommends exclude per audit + Decision #2; user confirms)
- **Decision #38** — Lendiniara respawn impact (Lendiniara 124020 is a Sleeper's Tomb key talisman source; 24h respawn creates meaningful gate — user confirms endgame tier applies)

---

## Existing System Analysis

### Current State

**Phases 2, 3, and 4a landed.** User has validated Phase 2 Classic (Lady Vox in-game PASS) and accepted Phase 4a Velious non-ToV after BUG-001 Tunare fix. Phase 3 Kunark server-side PASS; in-game deferred.

**Prior-pass globals remain authoritative and unchanged:**
- `NPCFlurryChance=12`, `MaxRampageTargets=2` (**critical for AoW rampage 6×6 cap**), `NPCAssistCap=3`, `StartEnrageValue=5`, `GlobalLootMultiplier=2`, `CurrentExpansion=3`, `AllowRaidTargetBlind=false`
- `rule_values` count: 1,112 (confirmed unchanged by config-expert 2026-04-22; re-verifying for Phase 4b).
- `zone.ruleset=1` (default) applies to `sleeper`, `templeveeshan`, and `kael` (confirmed 2026-04-22).

**Phase 4b content at PEQ defaults** per audit and DB confirmation:

**Temple of Veeshan (templeveeshan) — 16 dragon lords at L66-70, 240k-580k HP, 259,200s (72h) respawn:**
- Three MR=1000 walls: Lord Vyemm (350k HP, MR=1000, max dmg 1,200 — signature mechanic per Decision #11), Telkorenar (280k HP, MR=1000), Gozzrem (280k HP, MR=1000).
- Dagarn the Destroyer: 300k HP, AC=900 (distinctive — tanky dragon), HP-regen ability flag (1,10^8) — signature.
- Aaryonar: 390k HP, 900 max dmg, AC=560, MR=225. Signature breath mechanic.
- Other 10 at 240k-525k HP with max dmg 480-960.

**NToV mid-tier named:**
- 8 Midayor-cluster (L60 120k HP, respawn 194,400s / 54h): Midayor, Grozzmel, Ymmeln, Krigara, Lepethida, Essedera, Tavekalem, Casalen.
- 8 L65-66 named (respawn 64,800s / 18h except Zlexak & Sevalak at 72h): Cyndor, Zlexak, Yrrindor, Kalkar, Vyldin, Zyerek, Malteor, Sevalak.

**NToV Defenders (EXCLUDED per audit):** 4 NPCs at 120k HP, 3-5h respawn — `An_Emerald_Defender`, `A_Sky_Defender`, `An_Onyx_Defender`, `A_Lava_Defender`.

**Sleeper's Tomb (sleeper):**
- **spawn_conditions state:** condition 1 "Warders" = 0 (DORMANT), condition 2 "Ancients" = 1 (LIVE).
- **Condition 2 (live):** 4 Ancients (Kildrukaun 352k MR=400, Vyskudra 352k + Lightning Breath, Tjudawos 352k, Zeixshi-Kar 377k), Final Arbiter main (128143, 357k), Progenitor main (128144, 327k), Master of the Guard main (128145, 326.5k + 8-sentry wave encounter), Milas An`Rev (128040, 210k, respawn 14,400s / 4h).
- **Condition 1 (dormant):** 4 Warders (Hraashna/Nanzata/Tukaarak/Ventani at 200k HP each), Final Arbiter alt (128045, 200k).
- **The Sleeper (128094, L99 3.5M HP)** + **Kerafyrm (128089 combat + 128095 zone-clone, L99 3.5M HP)**: permanently untouched per Decision #12. Kerafyrm holds spell 1948 "Destroy" (-100,000 damage, mana 0, cast 0) — his signature mechanic. Untouched.

**Avatar of War (kael, 113457):** 900k HP, max dmg 1,154, AC=850, MR=190, special_abilities include rampage 6×6 (capped by global MaxRampageTargets=2). No spawn2 row; script-spawned by Idol death (Phase 4a chain).

**Vulak`Aerr (templeveeshan, 124155):** 890k HP, max dmg 1,400, AC=950, MR=80. No spawn2 row; spawned by `Thylex_of_Veeshan.pl` 60-second tick when all 6 altar dragons (Mirenilla, Nevederia, Feshlak, Aaryonar, Kreizenn, Vyemm) are dead (qglobal `vulak` cooldown 6 min).

**Thylex_of_Veeshan (124000, the Vulak coordinator NPC):** L10, 100 HP, raid_target=0, special_abilities flags 19/20/24/25/35 (immunity cluster — untargetable/uncharmable/unstunnable). DB-verified non-combat coordinator. Protocol-agent flagged that accidentally killing Thylex would break Vulak spawns, but DB state shows the immunity flags already prevent this. **Phase 4b does NOT edit Thylex** (not in `npc_types_backup_raid_scaling_velious_b` or the UPDATE list). Smoke check §B10 adds a "Thylex untouched at 100 HP" verification line.

**Relevant topography:**
- `claude/docs/topography/SQL-CODE.md` — npc_types, spawn2, spawnentry, spawngroup chain
- `claude/docs/topography/PERL-CODE.md` — `quest::signalwith`, `quest::spawn_condition` Perl API
- `claude/docs/topography/LUA-CODE.md` — encounter system (`event_encounter_load`, `eq.register_npc_event`, `eq.signal`, `eq.set_timer`)

### Gap Analysis

| Gap | Lever |
|-----|-------|
| 16 ToV dragon lords at 240k-580k HP (12-27× scaled-named L66-70 target ~22-30k) | `npc_types.hp` 72-78% cuts per audit (targets 65-130k) |
| 3 ToV damage outliers (Vyemm 1,200 max, Feshlak 960, Nevederia 892) | `npc_types.maxdmg` 27-41% cut per audit |
| 16 NToV mid-tier named at 100-140k HP (3-5× gap) | HP 58-70% cut to 40-50k per audit |
| 4 Defenders at 120k HP (raid_target=1 but elite-trash tier) | **NO CHANGE** per Decision #2 + audit |
| Sleeper's Tomb: 4 Ancients + Progenitor + Arbiter main + MotG at 326k-377k HP (11-17× gap) | HP 75-76% cut to 80-90k |
| Sleeper's Tomb: Final Arbiter alt + 4 Warders at 200k HP (6× gap) | HP 70% cut to 60k |
| Sleeper's Tomb: Milas An`Rev at 210k HP (mid-tier, 4h respawn) | HP 71% cut to 60k; respawn unchanged (mid-tier) |
| Vulak`Aerr 890k HP / 1,400 max dmg (30× gap — ToV pinnacle) | HP 83% cut to 150k, damage 43% cut to 250-800 |
| Avatar of War 900k HP / 1,154 max dmg / rampage 6×6 (30× gap) | HP 87% cut to 120k, damage 39% cut to 200-700. Global MaxRampageTargets=2 cap preserves rampage signature safely. |
| ToV dragons + Sleeper's Tomb at 72h respawn (Decision #8 endgame = 24h) | `spawn2.respawntime` 259,200 → 86,400s (24h) |
| Midayor cluster at 54h respawn (endgame tier) | `spawn2.respawntime` 194,400 → 86,400s |
| Kerafyrm trio (128089/94/95) + Sleeper spawn2 + Destroy spell + awake scripts | **NO CHANGE** per Decision #12 |

### What is NOT gap for Phase 4b

- **No C++ changes.** Same rationale as Phases 2, 3, and 4a.
- **No `rule_values` changes.** Confirmed pattern carryover; config-expert re-verifying for Phase 4b sleeper/templeveeshan zones.
- **No loot table changes.** Per Decision #3.
- **No `npc_spells_entries` changes.** DB sweep confirmed zero death-touch-profile spells on Phase 4b in-scope bosses. Only matches were Vyskudra Lightning Breath (-1,500, 12s recast, signature per Decision #11) and Kerafyrm "Destroy" (-100,000 instant-kill, out-of-scope per Decision #12).
- **No `special_abilities` CSV edits.** All Phase 4b bosses retain their signature mechanics per Decision #11 (Vyemm MR-wall, Telkorenar MR-wall, Gozzrem MR-wall, Kildrukaun MR=400, Dagarn HP-regen, Aaryonar breath, AoW rampage 6×6, MotG 8-sentry wave, Ancient Kerafyrm-alive depop behavior).
- **No Kerafyrm trio edits.** 128089 / 128094 / 128095 untouched by HP, damage, AC, MR, special_abilities, or npc_spells_entries (Destroy spell preserved).
- **No Sleeper's Tomb script edits.** `#Hraashna_the_Warder.pl` (and 3 other Warder scripts) remain untouched — the `quest::signalwith(128094, 66)` chain is the Sleeper Awake trigger, preserved intact.
- **No `spawn_conditions` edits.** sleeper condition 1 / condition 2 gating preserved; templeveeshan condition 1 (legacy Vulak flag, unused by Thylex) untouched.
- **No defender cluster (124050/51/52/79) edits.** Per audit line 1673-1677 + Decision #2.
- **No `Thylex_of_Veeshan` or `#The_Sleeper` edits.** Both are quest coordinator NPCs; not kill targets.
- **No AoW / Vulak spawn-chain script edits.** Phase 4a precedent held that `eq.unique_spawn()` / `quest::spawn2()` staggered-scaling is clean with zero client anomaly.

---

## Technical Approach

### Architecture Decision

**Every Phase 4b change is a single-column `UPDATE` on `npc_types` or `spawn2`.** Per the layer priority (rules > config > Lua > SQL > C++):

1. **Rules — NOT APPLICABLE.** Confirmed by pattern carryover; Phase 2/3/4a rule posture holds.
2. **Config (`eqemu_config.json` / `.env`) — NOT APPLICABLE.** No structural changes.
3. **Lua/Perl scripts — NOT APPLICABLE.** Phase 4b targets NPC stats only. All signature behaviors (Warder signal chain, MotG 8-sentry wave, Thylex Vulak summon, Ancient Kerafyrm-alive depop, Kerafyrm awake chain, AoW triggered spawn) are scripted but **read NPC stats at runtime, not at script load** — scripts need no edits to accommodate new HP values.
4. **SQL — YES.** `npc_types` UPDATEs for HP/damage, `spawn2` UPDATEs for respawn. No `npc_spells_entries` changes.
5. **C++ — NOT APPLICABLE.** No engine change needed.

### Component Change Table

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `npc_types.hp` (~47 Phase 4b bosses) | UPDATE per-NPC | Audit targets vary 70-87% cut; per-NPC precision required |
| `npc_types.maxdmg` (ToV high-damage dragons + Vulak + AoW) | UPDATE per-NPC | Damage outliers need caps to avoid one-shot risk |
| `npc_types.mindmg` (Vulak, AoW — proportional scale-down paired with maxdmg) | UPDATE per-NPC | Pinnacle fights |
| `spawn2.respawntime` (~35-38 Phase 4b spawns at >24h) | UPDATE per-spawn | Target 86,400s = 24h per Decision #8 endgame tier |
| `npc_types.special_abilities` | **NO CHANGE** | Decision #11 preserves all signature mechanics |
| `npc_types.MR` | **NO CHANGE** | Vyemm/Telkorenar/Gozzrem MR=1000 walls preserved |
| `npc_spells_entries` | **NO CHANGE** | Zero death-touch hits on Phase 4b in-scope bosses; Vyskudra Lightning Breath + Kerafyrm Destroy both preserved |
| Backup tables `npc_types_backup_raid_scaling_velious_b`, `spawn2_backup_raid_scaling_velious_b` | CREATE + INSERT-SELECT | Mirrors Phase 4a pattern with `_velious_b` suffix |
| `rule_values` | NO CHANGE | Confirmed pattern from Phase 2/3/4a |
| `eqemu_config.json` / `.env` | NO CHANGE | Same as Phase 2/3/4a |
| Lua/Perl scripts | NO CHANGE | All signature behaviors read NPC stats at runtime |
| C++ source | NO CHANGE | N/A |

### Data Model

#### Backup tables (captured BEFORE any other change)

```sql
CREATE TABLE npc_types_backup_raid_scaling_velious_b AS
SELECT id, hp, mindmg, maxdmg, AC, MR, special_abilities, npcspecialattks, npc_spells_id
FROM npc_types
WHERE id IN (
    -- ToV 16 dragon lords
    124001, 124004, 124008, 124010, 124011, 124017, 124020, 124037,
    124071, 124072, 124074, 124076, 124077, 124103, 124104, 124105,
    -- NToV 16 mid-tier named (Midayor cluster + L65-66)
    124018, 124073, 124007, 124106, 124107, 124003, 124009, 124075,
    124030, 124031, 124034, 124035, 124036, 124038, 124039, 124040,
    -- Vulak + AoW
    124155, 113457,
    -- Sleeper's Tomb 13 (5 Ancients + Progenitor + Arbiter main & alt + MotG + Milas + 4 Warders)
    128040, 128041, 128042, 128043, 128044, 128045,
    128090, 128091, 128092, 128093,
    128143, 128144, 128145
);
-- Expected rows: 47

CREATE TABLE spawn2_backup_raid_scaling_velious_b AS
SELECT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance,
       s2._condition, s2.cond_value, s2.x, s2.y, s2.z, s2.heading
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID IN (
    124001, 124004, 124008, 124010, 124011, 124017, 124020, 124037,
    124071, 124072, 124074, 124076, 124077, 124103, 124104, 124105,
    124073, 124075, 124030, 124031, 124034, 124035, 124036, 124038, 124039, 124040,
    128040, 128041, 128042, 128043, 128044, 128045,
    128090, 128091, 128092, 128093,
    128143, 128144, 128145
);
-- Expected rows: ~35-38
-- Note: 113457 AoW + 124155 Vulak + 128089/94/95 Kerafyrm trio have NO spawn2 rows (script-spawned / untouched)
-- Note: 128040 Milas has a spawn2 (id 25245, respawn 14400s); backed up but respawn NOT updated (4h mid-tier)
```

#### Phase 4b change sketch (data-expert emits final SQL; values sourced from `context/velious-b-db-investigation.md` §5)

**Temple of Veeshan — 16 dragon lords (audit line 1629-1646):**

```sql
UPDATE npc_types SET hp = 130000, maxdmg =  690               WHERE id = 124103;  -- Lord Koi`Doken 580k→130k
UPDATE npc_types SET hp = 120000, maxdmg =  600               WHERE id = 124076;  -- Lady Nevederia 525k→120k, 892→600
UPDATE npc_types SET hp = 110000, maxdmg =  600               WHERE id = 124074;  -- Lord Kreizenn 465k→110k, 950→600
UPDATE npc_types SET hp = 110000, maxdmg =  600               WHERE id = 124008;  -- Lord Feshlak 455k→110k, 960→600
UPDATE npc_types SET hp = 100000                              WHERE id = 124071;  -- Cekenar 425k→100k (700 dmg OK)
UPDATE npc_types SET hp =  95000, maxdmg =  550               WHERE id = 124010;  -- Aaryonar 390k→95k, 900→550 (signature breath preserved)
UPDATE npc_types SET hp =  95000, maxdmg =  550               WHERE id = 124037;  -- Dozekar the Cursed 386.5k→95k
UPDATE npc_types SET hp =  95000, maxdmg =  600               WHERE id = 124077;  -- Lady Mirenilla 380k→95k, 950→600
UPDATE npc_types SET hp =  90000, maxdmg =  700               WHERE id = 124017;  -- Lord Vyemm 350k→90k, 1200→700 (MR=1000 PRESERVED)
UPDATE npc_types SET hp =  80000                              WHERE id = 124020;  -- Lendiniara the Keeper 320k→80k (ST key talisman source)
UPDATE npc_types SET hp =  80000                              WHERE id = 124011;  -- Dagarn the Destroyer 300k→80k (HP-regen ability PRESERVED)
UPDATE npc_types SET hp =  75000                              WHERE id = 124104;  -- Telkorenar 280k→75k (MR=1000 PRESERVED)
UPDATE npc_types SET hp =  75000                              WHERE id = 124105;  -- Gozzrem 280k→75k (MR=1000 PRESERVED)
UPDATE npc_types SET hp =  65000, maxdmg =  550               WHERE id = 124001;  -- Ikatiar the Venom 250k→65k
UPDATE npc_types SET hp =  65000, maxdmg =  600               WHERE id = 124072;  -- Jorlleag 250k→65k, 916→600
UPDATE npc_types SET hp =  65000, maxdmg =  550               WHERE id = 124004;  -- Eashen of the Sky 240k→65k
```

**NToV mid-tier named (16 NPCs, audit line 1664-1671):**

```sql
-- Midayor cluster L60 (8 NPCs)
UPDATE npc_types SET hp = 40000 WHERE id = 124030;  -- Midayor
UPDATE npc_types SET hp = 40000 WHERE id = 124031;  -- Grozzmel
UPDATE npc_types SET hp = 40000 WHERE id = 124034;  -- Ymmeln
UPDATE npc_types SET hp = 40000 WHERE id = 124035;  -- Krigara
UPDATE npc_types SET hp = 40000 WHERE id = 124036;  -- Lepethida
UPDATE npc_types SET hp = 40000 WHERE id = 124038;  -- Essedera
UPDATE npc_types SET hp = 40000 WHERE id = 124039;  -- Tavekalem
UPDATE npc_types SET hp = 40000 WHERE id = 124040;  -- Casalen

-- L65-66 named (8 NPCs)
UPDATE npc_types SET hp = 50000 WHERE id = 124018;  -- Cyndor Lightningfang 140k→50k
UPDATE npc_types SET hp = 45000 WHERE id = 124073;  -- Zlexak 121.5k→45k
UPDATE npc_types SET hp = 45000 WHERE id = 124007;  -- Yrrindor Emerald Claw 120k→45k
UPDATE npc_types SET hp = 45000 WHERE id = 124106;  -- Kalkar of the Maelstrom 120k→45k
UPDATE npc_types SET hp = 45000 WHERE id = 124107;  -- Vyldin Flamereaver 120k→45k
UPDATE npc_types SET hp = 42000 WHERE id = 124003;  -- Zyerek Onyxblood 110k→42k
UPDATE npc_types SET hp = 42000 WHERE id = 124009;  -- Malteor Flamecaller 110k→42k
UPDATE npc_types SET hp = 40000 WHERE id = 124075;  -- Sevalak 101.5k→40k
```

**Sleeper's Tomb — 13 bosses:**

```sql
-- Ancients (condition 2 — currently LIVE)
UPDATE npc_types SET hp = 90000, maxdmg = 700 WHERE id = 128044;  -- Zeixshi-Kar the Ancient 377k→90k, 929→700
UPDATE npc_types SET hp = 85000               WHERE id = 128143;  -- Final Arbiter main 357k→85k (629 dmg OK)
UPDATE npc_types SET hp = 85000               WHERE id = 128041;  -- Kildrukaun the Ancient 352k→85k (MR=400 PRESERVED)
UPDATE npc_types SET hp = 85000, maxdmg = 700 WHERE id = 128042;  -- Vyskudra the Ancient 352k→85k, 789→700 (Lightning Breath PRESERVED)
UPDATE npc_types SET hp = 85000, maxdmg = 700 WHERE id = 128043;  -- Tjudawos the Ancient 352k→85k
UPDATE npc_types SET hp = 80000               WHERE id = 128144;  -- Progenitor main 327k→80k
UPDATE npc_types SET hp = 80000               WHERE id = 128145;  -- Master of the Guard main 326.5k→80k (8-sentry wave PRESERVED)
UPDATE npc_types SET hp = 60000               WHERE id = 128040;  -- Milas An`Rev 210k→60k

-- Warders (condition 1 — currently DORMANT; scaling preserves future accessibility via GM trigger)
UPDATE npc_types SET hp = 60000 WHERE id = 128093;  -- Hraashna the Warder 200k→60k
UPDATE npc_types SET hp = 60000 WHERE id = 128090;  -- Nanzata the Warder 200k→60k
UPDATE npc_types SET hp = 60000 WHERE id = 128092;  -- Tukaarak the Warder 200k→60k
UPDATE npc_types SET hp = 60000 WHERE id = 128091;  -- Ventani the Warder 200k→60k

-- Final Arbiter alt variant (condition 1)
UPDATE npc_types SET hp = 60000 WHERE id = 128045;  -- Final Arbiter alt 200k→60k
```

**Vulak`Aerr + Avatar of War (the two pinnacle fights):**

```sql
-- Vulak`Aerr — 890k HP / 1,400 max dmg (audit line 1648-1654)
UPDATE npc_types SET hp = 150000, mindmg = 250, maxdmg = 800 WHERE id = 124155;

-- Avatar of War — 900k HP / 1,154 max dmg + rampage 6×6 (audit line 1568)
UPDATE npc_types SET hp = 120000, mindmg = 200, maxdmg = 700 WHERE id = 113457;
```

**Respawn timer UPDATEs (Decision #8 endgame = 86,400s / 24h):**

```sql
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 86400
WHERE se.npcID IN (
    -- ToV 16 dragon lords
    124001, 124004, 124008, 124010, 124011, 124017, 124020, 124037,
    124071, 124072, 124074, 124076, 124077, 124103, 124104, 124105,
    -- NToV mid-tier named (8 L65-66 stay at 64,800s / 18h; Zlexak + Sevalak go to 24h; 8 Midayor go to 24h)
    124073, 124075,
    124030, 124031, 124034, 124035, 124036, 124038, 124039, 124040,
    -- Sleeper's Tomb: 4 Ancients + Final Arbiter main + alt + Progenitor + MotG + 4 Warders
    128041, 128042, 128043, 128044, 128045,
    128090, 128091, 128092, 128093,
    128143, 128144, 128145
);

-- NOT updated (already acceptable):
--   124018, 124007, 124106, 124107, 124003, 124009 — already 18h respawn (tier-appropriate for mid-tier named)
--   128040 Milas An`Rev — already 14,400s (4h mid-tier accessibility, appropriate)
--   124050/51/52/79 — Defenders, EXCLUDED entirely
--   113457 AoW — no spawn2 (script-spawned by Phase 4a chain)
--   124155 Vulak — no spawn2 (script-spawned by Thylex)
--   128089/94/95 Kerafyrm trio — EXCLUDED per Decision #12
```

### Code Changes

**None.** Zero files modified in `eqemu/`, `akk-stack/server/quests/`, or `akk-stack/npc-llm-sidecar/`.

All Phase 4b behavioral preservation works because quest scripts query NPC state via `entity_list->GetMobByNpcTypeID()` (returns live NPC if present) or `quest::signalwith()` (sends signal to NPC by ID). None of these APIs read HP thresholds. Phase 4b stat changes are transparent to the scripting layer.

### Configuration Changes

No `rule_values` changes. No `eqemu_config.json` changes. No `.env` changes. Confirmed by Phase 2/3/4a pattern carryover; config-expert re-verification for sleeper/templeveeshan zones in flight.

### Database Changes

| Item | Type | Rows affected (approx) |
|------|------|------------------------|
| `npc_types_backup_raid_scaling_velious_b` | CREATE TABLE AS SELECT | 47 rows snapshot |
| `spawn2_backup_raid_scaling_velious_b` | CREATE TABLE AS SELECT | ~35-38 rows snapshot |
| `npc_types` | UPDATE | 47 rows (16 ToV + 16 NToV + 13 Sleeper + Vulak + AoW) |
| `spawn2` | UPDATE | 32 rows (16 ToV + 10 NToV: 8 Midayor + Zlexak + Sevalak + 11 Sleeper's Tomb) |
| `npc_spells_entries` | NO CHANGE | 0 rows |

Data-expert produces a single SQL reference at `data-expert/context/phase4b-velious-b-implementation.sql` with:
1. Backup table creates first.
2. All `npc_types` UPDATEs ordered by zone cluster (ToV dragons → NToV mid-tier → Sleeper's Tomb Ancients → Sleeper's Tomb Warders → AoW → Vulak).
3. `spawn2.respawntime` UPDATEs.
4. Post-change verification queries.
5. Full rollback script using backup tables (INSERT…SELECT transactional).

---

## Kerafyrm Isolation Proof (§2 of Architecture)

**Decision #12 requires the Sleeper Awake event (Kerafyrm L99 3.5M HP) stay permanently untouched. This section proves Phase 4b HP scaling on the Warders cannot accidentally trigger the event at the code level.**

### 2.1 DB state

```
spawn_conditions:
  sleeper | id=1 | value=0 | onchange=2 | "Warders"     ← currently OFF (dormant)
  sleeper | id=2 | value=1 | onchange=2 | "Ancients"    ← currently ON (live)

spawn2 entries on condition 1 (dormant):
  id 58547: Nanzata the Warder   (128090, respawn 259,200s, variance 43,200s)
  id 58548: Tukaarak the Warder  (128092, same)
  id 58549: Ventani the Warder   (128091, same)
  id 58546: Hraashna the Warder  (128093, same)
  id 151668: Final Arbiter alt   (128045, same)
  id 26883: The Sleeper          (128094, respawn 1,200s)
```

### 2.2 Trigger chain (behavioral, verified in `akk-stack/server/quests/sleeper/*.pl`)

1. **Player kills all 4 Warders** (only possible if GM flips condition 1 to 1; Warders are currently unreachable by normal gameplay — no script auto-flips the condition).
2. **Last Warder's EVENT_DEATH_COMPLETE fires.** Example from `#Hraashna_the_Warder.pl`:
   ```perl
   if (!$nanzata && !$ventani && !$tukaarak) {
       quest::signalwith(128094, 66, 0);   # ← Sleeper Awake signal
       quest::shout("Warders, I have fallen. ...");
   }
   ```
3. **The Sleeper's EVENT_SIGNAL (signal=66) fires** (`#The_Sleeper.pl`):
   ```perl
   quest::shout("I AM FREE!");
   quest::depop_withtimer();
   quest::spawn2(128089, 1, 0, -1499, -2344.8, -1052.8, 0);   # Kerafyrm at hard-coded coords
   ```
4. **Kerafyrm EVENT_SPAWN** fires (`#Kerafyrm.pl`):
   ```perl
   quest::shout("ZERZURA!");
   quest::setglobal("kerafyrm", 1, 7, "F");
   quest::spawn_condition(sleeper, 2, 1);   # re-enable Ancients
   quest::spawn_condition(sleeper, 1, 0);   # disable Warders
   ```

### 2.3 What Phase 4b touches vs what's preserved

| Artifact | Phase 4b touches? | Rationale |
|---|---|---|
| `npc_types.hp` for 128090/91/92/93 (Warder HP) | **YES** — 200k → 60k | No gameplay-visible trigger depends on HP |
| `npc_types.hp` for 128089/95 (Kerafyrm) | **NO** | Decision #12 |
| `npc_types.hp` for 128094 (The Sleeper) | **NO** | Uncombattable quest NPC, 0/4 damage, integral to event chain |
| `npc_spells_entries` for spell list 489 (Kerafyrm's Destroy spell) | **NO** | Signature death-touch for awake event |
| `spawn_conditions` table (condition 1/2 gating) | **NO** | Gating mechanism preserved |
| `spawn2` rows for Warders (58546-58549), Final Arbiter alt (151668), Sleeper (26883), Kerafyrm (14691) | **NO** respawn change (Warders stay at 259,200s since condition=1; Sleeper/Kerafyrm untouched) — note backup table captures Warder rows for completeness but the respawn UPDATE does NOT include them |
| `quests/sleeper/*.pl` script files | **NO** | Trigger chain preserved verbatim |
| `quests/sleeper/encounters/motg.lua` (MotG 8-sentry wave) | **NO** | Signature mechanic preserved |

### 2.4 Scenarios evaluated

**Scenario A: Phase 4b applied, Warders stay dormant (current state).** Warder HP changes from 200k to 60k in `npc_types`. No player interaction possible because condition 1 = 0 (Warders not spawned). Sleeper Awake event cannot fire. ✅ Decision #12 honored.

**Scenario B: Phase 4b applied, GM flips condition 1 to 1 in the future.** Warders + The Sleeper spawn. Small group can now kill all 4 Warders (60k HP each = tractable). Last-Warder-death fires signal 66 → Sleeper spawns Kerafyrm at full 3.5M HP with Destroy death-touch intact. Small group attempting Kerafyrm wipes (as designed). World event fires normally. **The event itself is unchanged — only the barrier to entry is lowered.** ✅ This matches Decision #12's "leave the EVENT untouched" — the event (Kerafyrm's arrival and rampage) is untouched; only the preceding Warder fights are made tractable for a small group.

**Scenario C: Unintended interaction — does scaling ToV dragons, AoW, or any other Phase 4b boss affect the Sleeper Awake chain?** No. The chain depends on:
- `GetMobByNpcTypeID(128090/91/92)` presence checks (IDs 128090-128093 only)
- `quest::signalwith(128094, 66)` (targets 128094 only)
- `quest::spawn2(128089)` (spawns 128089 only)
- `quest::spawn_condition(sleeper, …)` (sleeper zone condition values only)

No Phase 4b NPC outside the sleeper zone touches any of these artifacts. ✅ Zero cross-contamination risk.

### 2.5 Flag for user acknowledgment (Decision #36)

**Scenario B means: if the user or a GM ever intentionally activates the Warders, a small group can reach the Sleeper Awake event for the first time.** This is a change in reachability, though not a change in the event itself. Architect surfaces this as a user-visible implication of Phase 4b. Architect recommendation: proceed — Decision #12 preserves the event's permanent uniqueness; Decision #1 tier curve (endgame tier tractable with preparation) supports small-group access to trigger the event as a deliberate choice.

**Alternative (user's call):** leave all 4 Warders at native 200k HP. This creates a permanent "can't reach Kerafyrm awake event" floor on small-group servers — which may be preferable given Decision #12's spirit. If user selects this alternative, remove Warder IDs 128090-93 (and optionally Final Arbiter alt 128045) from the UPDATE list and backup table.

---

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| B1 | Build backup tables `npc_types_backup_raid_scaling_velious_b` (47 rows) and `spawn2_backup_raid_scaling_velious_b` (~35-38 rows); verify row counts; emit SQL reference doc structure | data-expert | — | ~30m |
| B2 | Emit per-boss HP/damage UPDATE SQL for 16 ToV dragon lords (Kael/Skyshrine pattern but with endgame targets); cross-check audit targets; commit to `data-expert/context/phase4b-velious-b-implementation.sql` | data-expert | B1 | ~1h |
| B3 | Emit per-boss HP UPDATE SQL for 16 NToV mid-tier named (Midayor cluster + L65-66 cluster); 40-50k targets per audit | data-expert | B1 | ~30m |
| B4 | Emit per-boss HP/damage UPDATE SQL for 13 Sleeper's Tomb bosses (4 Ancients + Progenitor + Arbiter main/alt + MotG + Milas + 4 Warders) | data-expert | B1 | ~30m |
| B5 | Emit Vulak`Aerr UPDATE (890k→150k HP, 355-1400 → 250-800 dmg) and AoW UPDATE (900k→120k HP, 299-1154 → 200-700 dmg) | data-expert | B1 | ~15m |
| B6 | Emit `spawn2.respawntime` UPDATE SQL (86,400s for ~32 rows covering ToV + Midayor + Sleeper's Tomb; EXCLUDE Warder spawn2 rows from respawn change, INCLUDE from backup) | data-expert | B1 | ~30m |
| B7 | Emit rollback script (INSERT…SELECT from backup tables, transactional) + verification queries comparing row counts before/after; mirror Phase 4a `06-velious-a-rollback.sql` pattern | data-expert | B2, B3, B4, B5, B6 | ~30m |
| B8 | Apply all SQL changes via `docker exec akk-stack-mariadb-1 mysql -ueqemu -p'…' peq < phase4b-velious-b-implementation.sql`; capture before/after row counts and diff stats | data-expert | B7 | ~15m |
| B9 | `#reloadworld` via Spire or world telnet port 9000 so zone processes re-load modified `npc_types` and `spawn2` caches | config-expert | B8 | ~5m |
| B10 | Smoke verification: run SQL queries confirming HP targets for Koi`Doken/Vyemm/Vulak/AoW/Kildrukaun/Hraashna; respawn targets for 24h-tier bosses; Kerafyrm trio (128089/94/95) untouched; Destroy spell (1948) still in list 489; Warders preserved in backup table | config-expert | B9 | ~30m |
| B11 | Commit + push all changed files in `claude/` repo (architecture doc, context files, status updates, implementation SQL) to `feature/raid-scaling` branch. `akk-stack/` and `eqemu/` untouched. | data-expert | B8 | ~10m |

**Critical ordering constraint:** B1 gates B2-B6. B7 depends on all of B2-B6 complete. B8 depends on B7. B9 depends on B8. B10 depends on B9. B11 is git-commit only, can run in parallel with B10.

**Tasks NOT required:**
- **lua-expert / perl-expert** — NO script changes. Sleeper zone `.pl` scripts, templeveeshan `.pl` scripts, MotG encounter, and all Kerafyrm chain scripts are untouched.
- **c-expert** — no C++ changes.
- **protocol-agent** — already advised 2026-04-22 (Phase 4b cleared); no implementation role.
- **infra-expert** — no full-stack restart expected. If `#reloadworld` doesn't propagate `npc_types` HP changes (they should — this has worked in Phases 2/3/4a), a follow-up full-stack restart is contingent.

**Required implementation agents:**

| Agent | Role | Tasks |
|-------|------|-------|
| data-expert | primary | B1, B2, B3, B4, B5, B6, B7, B8, B11 |
| config-expert | reload + smoke | B9, B10 |

Same team composition as Phases 2 and 3 — simpler than Phase 4a (lua-expert was conditional fallback only there; Phase 4b has no Lua-script lever at all).

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `#reloadworld` doesn't propagate `npc_types` HP changes in live zones | Very Low | Low | Same pattern as Phase 2/3/4a (all worked). If it fails for sleeper/templeveeshan, config-expert triggers infra-expert full-stack restart. |
| Kerafyrm awake event chain breaks due to Warder HP change | Nil | Medium | Chain uses `GetMobByNpcTypeID()` presence, not HP thresholds. Verified by code trace. See §Kerafyrm Isolation Proof. |
| Vulak altar event breaks due to 6 altar-dragon HP changes | Nil | Medium | `#Thylex_of_Veeshan.pl` uses `entity_list` presence checks, not HP. Scaling the 6 dragons makes them killable; Vulak spawns normally when all 6 are dead (same as current). |
| AoW triggered chain breaks due to scaling | Nil | Low | Phase 4a precedent confirmed `eq.unique_spawn()` pattern is HP-independent. |
| MotG 8-sentry wave encounter breaks | Nil | Medium | No script edit; timer intervals unchanged; signal targets unchanged. HP scaling affects only kill-pace, not behavior. |
| Dagarn HP-regen ability trivialized at 80k HP | Low | Low | Regen rate is fixed via special_abilities flag 10; at 80k HP, player DPS still outpaces regen. If game-tester shows regen out-dps, adjust maxdmg or flag for user decision. |
| Vyemm/Telkorenar/Gozzrem MR=1000 walls defeat small-group casters | **Expected** | **Intended** | Decision #11 preserves signature. Small-group caster DPS is blocked on these three; melee/hybrid DPS is the intended counter. Document for user. |
| Warders scaled, but server-wide impact if event triggers | Medium | Medium (lore) | **Decision #36 flag.** Kerafyrm still 3.5M HP with Destroy intact — event wipes small group and proceeds. Awake consequence unchanged. |
| Defender cluster (124050/51/52/79) left at 120k HP feels inconsistent with scaled 16 dragon lords | Low | Low | Per Decision #2 + audit guidance. Defenders are raid-tier trash with 3-5h respawn (farmable). Keep. |
| Lendiniara the Keeper (124020, 80k HP post-scale) is the Sleeper's Tomb key talisman source for CoV-friendly players | Medium | Low | Path intended. 80k HP + 24h respawn = tractable key acquisition. Parallel paths (Klandicar/Sontalak 40k from Phase 4a) remain lower-gap alternatives. |
| Phase 4a scaled the 6 altar-dragon gate for Vulak; Phase 4b completes Vulak accessibility | **HIGH for players** | **Intended** | Phase 4b closes the ToV pinnacle. Vulak becomes reachable by small group for first time. Expected per Decision #1 tier curve. |
| NToV L60 Midayor cluster cut to 40k HP feels like raid-trash tier | Low | Nil | Audit line 1669: "HP cut 60-70% → 40-50k each, damage already mostly in named range — minor trim." Aligns with audit. These are lore-flavor bosses; 40k is appropriate for L60 named-adjacent. |
| Backup tables occupy disk space | Near zero | Nil | ~80KB combined. Accept. |

### Compatibility Risks

- **Prior-pass rule values remain authoritative.** None changed.
- **Epic quest scripts untouched.** Lore-master Section 5 confirmed no Velious Epic 1.0 steps; no class epic requires AoW, ToV dragon, Vulak, Warder, or Ancient kills. Decision #14 preserved.
- **Halls of Testing quest chain (Dozekar the Cursed + East Wing named drakes) unchanged in structure.** HP cut on Dozekar (386.5k→95k) makes Halls of Testing gem turn-in raids tractable for small group — intended per audit line 1892-1897.
- **Skyshrine Armor Quest Chain unaffected.** Chain uses named drake drops (raid-tier, Phase 4b scope). Dozekar scaling aligns.
- **Sleeper's Tomb key quest (Phase 4a scope, untouched in Phase 4b)** — Lendiniara is a Phase 4b boss and key talisman source; her scaling completes the talisman path. Other talisman sources (Sontalak/Klandicar/Zlandicar/Yelinak) are Phase 4a content already scaled. Shard of Hsagra path (Derakor/Tormax/Statue/Velketor) all Phase 4a scaled.
- **Faction grinds unchanged** per Decision #14. CoV access for ToV, Coldain for Icewell (Dain scaled in Phase 4a), Kromzek for Kael — all preserved.
- **Companion AI unchanged.** Same scaling patterns as Phases 2/3/4a.
- **LLM NPC conversation sidecar unchanged.** Reads name/level/faction only.

### Performance Risks

- **Zero.** ~47 UPDATEs + ~32 UPDATEs. Trivial workload.
- **No new indexes needed.**
- **No opcode-layer impact** — confirmed by protocol-agent 2026-04-22.
- **No zone boot overhead** — `#reloadworld` refreshes `npc_types` cache in minutes.

---

## Review Passes

### Pass 1: Feasibility

Every lever used is established Phase 2/3/4a practice:
- `npc_types.hp`, `npc_types.mindmg`, `npc_types.maxdmg` UPDATEs — 58 Phase 2 + 21 Phase 3 + 44 Phase 4a = 123 rows previously touched without issue. Phase 4b adds 47.
- `spawn2.respawntime` UPDATEs — 40+ Phase 2 + 14 Phase 3 + 15 Phase 4a = 69 rows previously touched. Phase 4b adds ~32.
- Backup table pattern — established and robust (rollback tested in Phase 2, 3, and 4a BUG-001 fix).

**Hardest part:** Kerafyrm awake event isolation. The chain is complex (4 Warders → signal 66 → Sleeper → Kerafyrm), but fully traced in source (§Kerafyrm Isolation Proof). HP scaling has ZERO effect on the trigger logic. Validated by code inspection of 4 Warder scripts + `#The_Sleeper.pl` + `#Kerafyrm.pl`.

**Edge case:** Dagarn the Destroyer's HP-regen ability (special_abilities flag 10) at 80k HP post-scale. If regen out-paces small-group DPS, fight becomes unwinnable. Architect expects regen rate to be outpaced by 1+5 companion DPS at 80k HP target, but flags for game-tester validation.

**Advisor confirmations:**
- **protocol-agent (2026-04-22, already logged):** All 7 Phase 4b questions answered. Zero client-visibility impact confirmed. Static zones, no DZ. Kerafyrm chain is script-driven, not HP-driven. Vulak spawn is presence-check. No Titanium quirks.
- **config-expert (consultation in flight 2026-04-23):** Expected zero changes per pattern carryover. Will log response in agent-conversations when received.
- **lore-master (consultation in flight 2026-04-23):** 10 questions on Sleeper Awake boundary, ToV keying, signature mechanics. Will log response.

**Confirmed feasibility:** all 11 tasks (B1-B11) executable by data-expert + config-expert in one session. Same team composition as Phase 3.

### Pass 2: Simplicity

**Challenge: Can we do less?**

- **Could we skip Midayor cluster (8 L60 NPCs)?** They're raid_target=1 but low-tier. Audit explicitly flags them for HP cut to 40-50k. Including them — 8 UPDATEs is trivial, and excluding them creates an inconsistent "some NToV bosses scaled, others not" feel.
- **Could we skip the Warders?** Per Decision #36 flag — this is a genuine user choice. Default: include (audit recommends). Alternative: exclude (preserves Decision #12 "reachability floor").
- **Could we skip Final Arbiter alt (128045)?** It's on condition 1 alongside the Warders. If Warders are in, this should be in. Including.
- **Could we skip Milas An`Rev (128040, already at 4h respawn)?** Respawn is fine, but HP (210k) is still raid-tier. Include HP cut, skip respawn change. One UPDATE.
- **Could we skip the Defenders?** Yes — per audit + Decision #2 (elite trash). Excluding. Decision #37 flag.
- **Could we defer AoW + Vulak to a Phase 4c?** No — per user's original phasing (Decision #4), Phase 4b is "ToV + Sleeper + Vulak + AoW." All four are in scope.
- **Could we skip damage cuts (keep HP cuts only)?** For Vyemm (1,200 max dmg) + Vulak (1,400) + AoW (1,154) — these are one-shot risks. Include. Other bosses in 600-900 range are trimmed modestly per audit guidance.
- **Could we defer `spawn2.respawntime` updates?** No — Decision #8 endgame tier is 24h; 72h respawn is the pain point for small-group cadence.
- **Could we skip backup tables?** No — Phase 2/3/4a precedent. BUG-001 rollback relied on them.

**Removed / deferred:**
- **Defenders (124050/51/52/79)** — raid_target=1 elite trash per audit + Decision #2.
- **`Thylex_of_Veeshan` (unknown ID in npc_types)** — coordinator NPC, not kill target. Per protocol-agent 2026-04-22 flag.
- **`a_foreboding_sentry1-8` (128000-128007)** — adds spawned by MotG wave encounter. raid_target status TBD; treated as trash per encounter design.
- **Various templeveeshan low-HP event-trigger NPCs (124120 Feshlak_ChkOne, 124125 A_Glowing_Orb, 124142 Spawn_Master, 124154 Infusion, etc.)** — L50-55 scripted triggers at 8-14k HP. Not raid-tier.
- **Sleeper's Tomb low-HP event NPCs (128057-128088 Area*mob*dead / AreaNstarter etc. at L1 11 HP)** — event flag NPCs, not kill targets.

### Pass 3: Antagonistic — what could go wrong

1. **Player triggers Kerafyrm by killing all 4 Warders for the first time after Phase 4b applies.** Kerafyrm retains 3.5M HP + Destroy death-touch. Small group wipes. Awake event proceeds normally. **Expected and preserved per Decision #12.**

2. **Vyemm MR=1000 stops all caster companion DPS.** Intended per Decision #11. Small group with caster-heavy composition will struggle. Melee/hybrid comps succeed. Document in test plan.

3. **Telkorenar and Gozzrem also have MR=1000.** Three MR-wall bosses in ToV. Small group must plan party composition deliberately for these. Expected.

4. **Dagarn HP-regen at 80k HP** — if 1+5 companion DPS is < regen rate, fight stalemates. Architect estimate: companion party sustains ~1,500-2,500 DPS (varies by comp); regen ability 10 ticks ~20-40 HP/sec; fight completes in 80k ÷ 1,500 ≈ 53s to 80k ÷ 2,500 ≈ 32s gross, well above regen rate. Safe.

5. **AoW rampage 6×6 in a 1+5 small group == 6 companions rampaged simultaneously.** Global `MaxRampageTargets=2` cap (Phase 2 rule, unchanged) limits to 2 targets per rampage burst. 6×6 spec survives via global cap. No special_abilities edit needed.

6. **Vulak 1,400 max dmg cut to 800 — still high for mitigation-light companions.** Vulak remains hardest fight. 150k HP means companions must survive 3-5 min of melee; tank spec matters. Documented.

7. **Lendiniara 124020 scaled to 80k HP + 24h respawn = Sleeper's Tomb key talisman takes up to 24h to re-acquire if first attempt fails.** Acceptable. Other key talisman paths (Klandicar/Sontalak 40k, Phase 4a) remain faster.

8. **Dozekar the Cursed 386.5k → 95k HP cut** — Halls of Testing gem drops RNG-dependent (audit line 1892-1897). Multi-clear farming required. 24h respawn + 95k HP = accessible. Gem RNG unchanged per Decision #3 (loot untouched).

9. **Sevalak (124075) at 101.5k HP already closest to target — is 40k cut too aggressive?** -60% is consistent with Midayor cluster (120k→40k = -67%). Cluster internal consistency wins. Keep 40k.

10. **Ikatiar the Venom (124001) respawn 93,744s (26h) — current value is nearly endgame 24h.** 24h target is a modest trim (6h shorter). Include for consistency.

11. **Phase 4a scaled the 6 altar-dragon gates for Vulak. Phase 4b scales Vulak himself.** The altar-dragon gates are also Phase 4b scope (they're ToV dragon lords — Mirenilla/Nevederia/Feshlak/Aaryonar/Kreizenn/Vyemm). Wait — let me re-verify: these 6 are Phase 4b in-scope per audit line 1629-1646 (ToV dragon lords). Phase 4a did NOT scale them. Correcting executive summary if needed: Phase 4b both scales the altar gates (as part of 16 ToV dragons) AND Vulak simultaneously. Vulak becomes reachable only in Phase 4b, not before.

12. **What if the user activates the Warder condition (condition 1 = 1) DURING Phase 4b validation?** Phase 4b is applied; user triggers Warders; small group kills them; Kerafyrm spawns; wipes small group. Then user sees "full event triggered for first time on small-group server" — which is the Decision #36 outcome. Handle via pre-flight user acknowledgment.

13. **spawn2 rows for condition-1 Warders backed up but not respawn-updated.** By design: Warders' respawn at 259,200s is fine since condition 1 = 0 means they don't spawn. If user flips condition later, respawn will fire; 259,200s remains current. Acceptable. Alternatively, architect could update Warder respawn to 86,400s for consistency — no impact. Leaving unchanged to minimize blast radius.

14. **Kerafyrm post-awake despawn — does the trigger chain ever re-enable condition 1?** Per `#Kerafyrm.pl`, EVENT_SPAWN sets condition 2=1, condition 1=0. EVENT_DEATH_COMPLETE sets `kerafyrm` qglobal to 3 and depops. **No script re-enables condition 1.** So once Kerafyrm spawns, he runs his course; when he dies (or the zone reboots), the state returns to condition 2=1 / condition 1=0 (Ancients live, Warders dormant). This is correct — the awake event is a one-shot per zone boot cycle.

15. **The Sleeper (128094) respawntime is 1,200s — is that a concern for restart scenarios?** Only relevant if condition 1 = 1. At condition 1 = 0, respawn time is moot (NPC doesn't spawn). Acceptable.

### Pass 4: Integration

**Task ordering:**
```
B1 (backups) ──┬──> B2 (ToV dragons SQL)
               ├──> B3 (NToV mid-tier SQL)
               ├──> B4 (Sleeper's Tomb SQL)
               ├──> B5 (Vulak + AoW SQL)
               └──> B6 (respawn SQL)
                    │
                    └──> B7 (rollback) ──> B8 (apply) ──> B9 (reload) ──> B10 (smoke verify)
                                                              │
                                                              └──> B11 (commit)
```

- B1 gates everything.
- B2-B6 can run in parallel after B1 (same agent, sequential writing).
- B7 depends on B2-B6.
- B8-B10 sequential.
- B11 git-commit only, can start after B8.

**Cross-agent dependencies all resolvable:**
- **game-designer** (PRD + audit): inputs consumed from Phase 1 + Phase 4 updates.
- **lore-master** (Velious chains): inputs consumed for keying + Sleeper Awake boundary; response to Phase 4b consult pending.
- **protocol-agent** (Phase 4b protocol clearance): cleared 2026-04-22 per existing log.
- **config-expert** (rule posture): re-verification in flight; default posture zero-change.
- **game-tester** (Phase 4b validation): will receive 47-boss smoke-verify hooks.

**Task dependencies all linear within Phase 4b.** Same shape as Phase 3 (V1 → V2/V3 → V4 → V5 → V6 → V7 → V8 → V9).

---

## Items flagged to user (decisions required before implementation)

### Decision #36 — Warder scaling acknowledgment (ARCHITECT-ASSIGNED)

**Architect recommendation: INCLUDE Warders in Phase 4b HP scaling (current default).**

Context: the 4 Warders (128090/91/92/93, L70, 200k HP each) are currently DORMANT on the server (spawn_conditions condition 1 = 0). No script flips the condition — only GM intervention or a custom activation script would spawn them. Scaling their HP to 60k (per audit line 1693-1696) makes them tractable for a small group IF a GM or script activates the condition.

**Implication:** if activated, the 4 Warder kills trigger `quest::signalwith(128094, 66)` → The Sleeper shouts "I AM FREE" → Kerafyrm spawns at 3.5M HP with Destroy death-touch intact. The awake event fires normally. **Kerafyrm himself is UNTOUCHED per Decision #12** — the event's consequence (server-wipe-style rampage) is preserved.

Options:
- **Option A (recommended):** Scale 4 Warders HP 200k → 60k + Final Arbiter alt (128045) 200k → 60k. Event becomes reachable for small group; event consequence unchanged.
- **Option B:** Leave all 4 Warders + Final Arbiter alt at 200k HP. Event remains mathematically unreachable for small group (default companion DPS can't clear 4 × 200k HP encounters even at L70). Creates a "permanent floor" where the Sleeper Awake event is untouched AT THE EVENT-TIER ENTRY LEVEL, not just at the Kerafyrm fight.

Architect recommends A on the grounds that Decision #12 is specifically about "Sleeper-awake event (Kerafyrm L99 3.5M HP): leave untouched" — i.e., the event's pinnacle, not the entire chain. Option A preserves Kerafyrm; only the Warder barrier is reduced.

**User approval required.** If Option B, remove NPC IDs 128090/91/92/93 and 128045 from the `npc_types` UPDATE list and backup table (but keep for historical reference).

### Decision #37 — Defenders cluster inclusion/exclusion

**Architect recommendation: EXCLUDE.**

Four NPCs (124050 Emerald, 124051 Sky, 124052 Onyx, 124079 Lava) at L65, 120k HP, 3-5h respawn. raid_target=1 but per audit line 1673-1677: "elite trash in ToV (out of scope) — ~20 drakes, wyverns, racnar, dancers at 50-75k HP. Already handled — these sit between named and boss tier and the brief explicitly said 'current named difficulty feels good'. No action needed." The 4 Defenders are the high-HP end of this cluster.

Options:
- **Option A (recommended):** Exclude from Phase 4b. Keep at 120k HP / 3-5h respawn.
- **Option B:** Include. Scale HP 120k → 45-50k per mid-tier named pattern.

Architect defers to user. Audit + Decision #2 favor exclusion. If included, 4 additional `npc_types` UPDATEs and 6-8 additional `spawn2` rows (some Defender types span multiple spawn2 entries).

### Decision #38 — Lendiniara the Keeper talisman-path gate

**Architect recommendation: ACCEPT endgame-tier respawn (24h).**

Lendiniara (124020) is:
- A Phase 4b ToV dragon lord (scope per audit)
- The CoV-faction Sleeper's Tomb key talisman source (per lore-master Section 4)
- Currently 320k HP / 72h respawn

Phase 4b scales her to 80k HP / 24h respawn. Impact: if a small group fails on first kill attempt, next talisman attempt is 24h away (assuming this specific dragon's talisman is the path taken). Alternative paths (Klandicar/Sontalak 40k at 12h respawn, Phase 4a) are available.

Options:
- **Option A (recommended):** Accept endgame tier. 24h respawn consistent with Decision #8.
- **Option B:** Keep Lendiniara at 12h respawn (mid-tier) because of her ST-key role. Breaks tier consistency.

Architect recommends A; Phase 4a Klandicar/Sontalak paths preserved as 12h alternatives. User deliberately chose "peak mastery" per Decision #1 for endgame tier.

---

## Required Implementation Agents

**Default path:**

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| data-expert | B1-B8, B11 | Owns all SQL emission, backup creation, apply, and commit. Primary agent. Same role as Phases 2/3/4a. |
| config-expert | B9, B10 | `#reloadworld` via world telnet port 9000 and post-change smoke verification. Same role as Phases 2/3/4a. |

**Agents NOT needed:** c-expert, lua-expert, perl-expert, infra-expert (full-stack restart not expected — no `npc_spells_entries` changes to flush), protocol-agent (already advised).

---

## Validation Plan

_game-tester should verify each of the following after the implementation team completes Tasks B1-B11:_

### Backup integrity
- [ ] **Backup tables exist and are populated.**
  ```sql
  SELECT COUNT(*) FROM npc_types_backup_raid_scaling_velious_b;   -- expect 47
  SELECT COUNT(*) FROM spawn2_backup_raid_scaling_velious_b;      -- expect ~35-38
  ```

### Temple of Veeshan — 16 dragon lords HP targets
- [ ] ```sql
  SELECT id, name, hp, maxdmg, MR FROM npc_types
  WHERE id IN (124103,124076,124074,124008,124071,124010,124037,124077,
               124017,124020,124011,124104,124105,124001,124072,124004)
  ORDER BY hp DESC;
  ```
  **Expected:**
  - Koi`Doken 130000 / 690
  - Nevederia 120000 / 600
  - Kreizenn 110000 / 600
  - Feshlak 110000 / 600
  - Cekenar 100000 / 700
  - Aaryonar 95000 / 550
  - Dozekar 95000 / 550
  - Mirenilla 95000 / 600
  - **Vyemm 90000 / 700 / MR=1000** ← MR preservation check
  - Lendiniara 80000 / 652
  - Dagarn 80000 / 755
  - **Telkorenar 75000 / 480 / MR=1000** ← MR preservation check
  - **Gozzrem 75000 / 480 / MR=1000** ← MR preservation check
  - Ikatiar 65000 / 550
  - Jorlleag 65000 / 600
  - Eashen 65000 / 550

### NToV mid-tier named
- [ ] All 8 Midayor cluster IDs (124030,124031,124034,124035,124036,124038,124039,124040) have hp=40000.
- [ ] Cyndor 124018 hp=50000; Zlexak 124073 hp=45000; Yrrindor/Kalkar/Vyldin (124007/106/107) hp=45000 each.
- [ ] Zyerek 124003 hp=42000; Malteor 124009 hp=42000; Sevalak 124075 hp=40000.

### Sleeper's Tomb
- [ ] Ancients: Kildrukaun (128041) 85000, Vyskudra (128042) 85000, Tjudawos (128043) 85000, Zeixshi-Kar (128044) 90000.
- [ ] Progenitor main (128144) 80000; Master of the Guard main (128145) 80000; Milas (128040) 60000.
- [ ] Final Arbiter main (128143) 85000; Final Arbiter alt (128045) 60000.
- [ ] **Warders: Hraashna (128093) 60000, Nanzata (128090) 60000, Tukaarak (128092) 60000, Ventani (128091) 60000.** (Option A adopted per Decision #36.)

### Vulak + AoW
- [ ] Vulak 124155: hp=150000, mindmg=250, maxdmg=800.
- [ ] AoW 113457: hp=120000, mindmg=200, maxdmg=700.

### Respawn verification (24h endgame tier)
- [ ] All 16 ToV dragon lords: `spawn2.respawntime = 86400` via spawnentry join.
- [ ] All 8 Midayor cluster: `spawn2.respawntime = 86400`.
- [ ] Zlexak + Sevalak: 86400.
- [ ] Sleeper's Tomb 4 Ancients + Progenitor + Arbiter main + MotG + 4 Warders + Arbiter alt: 86400.
- [ ] **Already-mid-tier named respawns preserved:**
  - Cyndor/Yrrindor/Kalkar/Vyldin/Zyerek/Malteor (124018/007/106/107/003/009): still 64800s (18h).
  - Milas (128040): still 14400s (4h).
  - Defenders (124050/51/52/79): UNCHANGED at 11250-16200s.

### Untouched-NPC verification (Decision #12 critical)
- [ ] **Kerafyrm trio UNTOUCHED:** `SELECT id, hp, maxdmg FROM npc_types WHERE id IN (128089, 128094, 128095);`
  **Expected:** 128089 (3500000, 7003), 128094 (3500000, 4), 128095 (3500000, 7003) — all unchanged.
- [ ] **Kerafyrm "Destroy" spell preserved:** `SELECT * FROM npc_spells_entries WHERE npc_spells_id=489 AND spellid=1948;` returns exactly 1 row.
- [ ] **Kerafyrm's spell 1948 still exists:** `SELECT id, name, effect_base_value1 FROM spells_new WHERE id=1948;` returns (1948, "Destroy", -100000).
- [ ] **Thylex_of_Veeshan (124000) untouched** — `SELECT hp, raid_target, special_abilities FROM npc_types WHERE id = 124000;` returns (100, 0, `19,1^20,1^24,1^25,1^35,1`). Vulak coordinator; already immune via special_abilities flags.
- [ ] **MotG encounter script untouched:** `akk-stack/server/quests/sleeper/encounters/motg.lua` file mtime before Phase 4b apply timestamp.
- [ ] **Warder scripts untouched:** `akk-stack/server/quests/sleeper/#Hraashna_the_Warder.pl` etc. unchanged.
- [ ] **Sleeper + Kerafyrm scripts untouched:** `#The_Sleeper.pl`, `#Kerafyrm.pl`, `#Kerafyrm_.pl` unchanged.
- [ ] **spawn_conditions state preserved:** `SELECT * FROM spawn_conditions WHERE zone='sleeper';` returns the same 2 rows (Warders + Ancients with same onchange and values).
- [ ] **Defenders excluded verification:** `SELECT id, hp FROM npc_types WHERE id IN (124050,124051,124052,124079);` all return 120000 unchanged.

### No `npc_spells_entries` changes
- [ ] `npc_spells_entries` row count matches pre-apply baseline (exclude Phase 2 Cazic Touch deletions from baseline).

### In-game smoke tests (1 player + 5 companions)

- [ ] **Kill Lord Koi`Doken in ToV:** completable. Respawn 24h. Loot drops normally.
- [ ] **Kill Lord Vyemm in ToV:** completable with melee/hybrid comp. **MR=1000 blocks caster DPS — expected behavior.** Confirm melee comp succeeds.
- [ ] **Kill Lord Telkorenar:** completable. MR=1000 wall preserved.
- [ ] **Kill Lord Gozzrem:** completable. MR=1000 wall preserved.
- [ ] **Kill Aaryonar:** signature breath mechanic active, damage at 550 max (was 900), HP 95k. Completable.
- [ ] **Kill Dagarn the Destroyer:** HP-regen ability active; 1+5 DPS outpaces regen. Complete within 2-3 min.
- [ ] **Kill all 6 altar dragons (Mirenilla/Nevederia/Feshlak/Aaryonar/Kreizenn/Vyemm) across 1-2 sessions → Vulak`Aerr spawns.** Confirm Thylex_of_Veeshan logic still works. Kill Vulak (150k HP, 800 max dmg). Completable with preparation. **ToV pinnacle achieved.**
- [ ] **Kill Dozekar the Cursed in ToV East Wing:** Halls of Testing gem turn-in chain now accessible. Dropped gems turn in normally. Respawn 24h.
- [ ] **Kill Zeixshi-Kar the Ancient + Kildrukaun + Vyskudra + Tjudawos in Sleeper's Tomb:** all four Ancients clearable. Vyskudra's Lightning Breath still casts at -1500 dmg 12s recast — signature preserved. Ancients depop if Kerafyrm ever spawns (scripted behavior preserved).
- [ ] **Kill Master of the Guard + 8-sentry wave encounter:** MotG signals 8 foreboding sentries in sequence; sentries spawn visible adds; signature mechanic preserved. 80k HP on MotG completable.
- [ ] **Kill Final Arbiter main + Progenitor main:** both completable at 80-85k HP.
- [ ] **Statue → Idol → Avatar of War (kael):** Phase 4a scaled Statue+Idol; Phase 4b scales AoW. Full Kael chain completable. AoW 120k HP + rampage 6×6 (capped to 2 targets globally) + 700 max dmg. Completable with tank-heavy comp.

### Post-apply Warder verification (Option A adopted)
- [ ] **Warder HPs updated in npc_types** but Warders DO NOT SPAWN in sleeper zone (condition 1 = 0 preserved).
- [ ] **If user chooses to test awake event (GM command `#spawncondition sleeper 1 1` or equivalent):**
  - 4 Warders + Final Arbiter alt + The Sleeper spawn in sleeper zone.
  - Warders killable at 60k HP each.
  - Last Warder's death triggers signal 66 → The Sleeper shouts "I AM FREE" → depops → Kerafyrm spawns at 3.5M HP.
  - Kerafyrm "Destroy" (100k damage instant cast) confirms death-touch intact.
  - Kerafyrm script flips conditions back (2=1, 1=0) restoring Ancient rotation.
  - This is the DELIBERATE Decision #36 scenario.

### Rollback dry-run
- [ ] **Using backup tables, restore `npc_types` for 3 sample NPCs** (Koi`Doken 124103, Vyemm 124017, Hraashna 128093) and verify pre-change values match (580000, 350000, 200000).
- [ ] **Rollback script syntax-verified** (DRY RUN: BEGIN; UPDATE...; SELECT COUNT; ROLLBACK).

### No regression on unchanged NPCs
- [ ] Spot-check Defenders (124050/51/52/79) at 120k HP unchanged.
- [ ] Spot-check low-HP event NPCs (124120, 124125, 128057, 128058, etc.) unchanged.
- [ ] Phase 4a scaled IDs (113215 Tormax = 100k, 114106 Yelinak = 110k, 127001 Tunare = 150k, 129003 Dain = 80k) unchanged.

---

## Appendix — Flagged items not in Phase 4b scope

- **Phase 5a (Luclin non-VT):** Ssraeshza, Grieg's End, Akheva, Luclin raid content ex-VT.
- **Phase 5b (Luclin VT+shards):** Vex Thal, 13-shard key rework.
- **Sleeper-awake event (Kerafyrm L99)** — untouched per Decision #12 permanently.
- **Defender cluster (124050/51/52/79)** — excluded per Decision #37 recommendation.
- **Faction grind acceleration** — still deferred per Decision #25 (Phase 4a).
- **Ring 8/Ring 9 UX softening** — still deferred per Decision #26 (Phase 4a).

---

> **Next step:** User decisions on Decisions #36 (Warder scaling — architect recommends include), #37 (Defenders exclusion — architect recommends exclude), #38 (Lendiniara 24h respawn — architect recommends accept). Then spawn the implementation team with:
> - **data-expert** (Tasks B1-B8, B11)
> - **config-expert** (Tasks B9-B10)
>
> Do NOT spawn c-expert, lua-expert, perl-expert, infra-expert, or protocol-agent — they have no Phase 4b implementation work.

---

## Addenda

### 2026-04-22 — Protocol-agent Phase 4b consultation (CONFIRMED)

Protocol-agent confirmed **zero Titanium client protocol impact** for Phase 4b. Summary from `agent-conversations.md` Phase 4b section:

1. **ToV + Sleeper's Tomb: standard static zones.** No DZ/expedition APIs referenced. Entry via standard `ZoneChange_Struct` → `ZoneServerInfo_Struct`. Same `#reloadworld` refresh applies as Phase 4a zones.
2. **Kerafyrm awakening: behavioral gate only. HP scaling cannot trigger it.** All 4 Warder scripts check `entity_list` count before `quest::signalwith(128094, 66, 0)`. Client packets are standard (`OP_MoveDoor` door 46, `NewSpawn_Struct`, `DeleteSpawn_Struct`). Decision #12 fully safe.
3. **Vulak summoning: entity-presence check, not altar-item-based.** Thylex checks `GetMobByNpcTypeID()` for 6 lords. HP scaling doesn't affect presence check.
4. **AoW chain closure: zero new concern** — same `eq.unique_spawn()` / `event_death_complete` pattern as Phase 4a.
5. **MobHealth ultra-high HP: percentage-only, no wire impact** (confirmed `mob.cpp:1500`).
6. **Vyemm MR=1000: server-side only** — MR column never sent to client. Invisible on wire.
7. **No zone-specific Titanium quirks** in sleeper or templeveeshan.

**Verdict: Phase 4b is 100% server-side. Zero opcode additions, zero struct changes, zero Titanium translation layer changes.** Same conclusion as Phases 2, 3, 4a. Thylex_of_Veeshan flagged as coordinator NPC to exclude from scaling SQL (architect incorporated — Thylex not in the Phase 4b UPDATE list).

### 2026-04-22 — Config-expert Phase 4b consultation (CONFIRMED with one scope correction)

Config-expert confirmed **zero concerns across all six questions**. Summary:

1. **rule_values count = 1,112** (identical to Phase 2 baseline; zero drift).
2. **Both Phase 4b zones (templeveeshan + sleeper) confirmed ruleset=1, min_status=0, expansion=2.** No custom ruleset overrides.
3. **Seven prior-pass globals unchanged.** No dragon-breath modifier, no MR-cap rule, no endgame-tier HP/damage rule exists. Vyemm's MR=1,000 is stored in `npc_types.MR` only — no rule can override.
4. **No special_abilities rule amplifiers.** `Bots:DisableSpecialAbilitiesAtMaxMelee` and `Spells:CharmDisablesSpecialAbilities` are not applicable to raid_target NPCs. "Don't touch rules" posture correct.
5. **No respawn timer rule clamps or randomizers.** Respawn is purely `spawn2.respawntime`.
6. **Kerafyrm awake state is spawn_conditions only.** Zero `data_buckets` / `variables` entries. No config concern. Kerafyrm out-of-scope per Decision #12.
7. **Bonus death-touch sweep: zero rows.** Confirms no `npc_spells_entries` DELETEs needed for Phase 4b.

**Scope correction required in config-expert's note:** Config-expert's Phase 4b sweep examined only the 10 "headline bosses" (AoW 113457, Vulak 124155, 4 Warders, 4 Ancients) and concluded "all 10 Phase 4b bosses have zero standing spawn2 rows" — which is true only for the 10 examined. Architect's full-roster DB re-verification (2026-04-23) confirms:
- **Only 2 of the 47 Phase 4b in-scope NPCs have zero spawn2 rows:** AoW (113457) and Vulak`Aerr (124155). Both script-spawned.
- **The other 45 Phase 4b NPCs have 1-3 spawn2 rows each** (16 ToV dragon lords, 16 NToV mid-tier named, 8 Sleeper's Tomb Ancients + Arbiter main + Progenitor + MotG + Milas, 4 Warders + Final Arbiter alt on condition 1).
- **Phase 4b WILL UPDATE `spawn2.respawntime` for ~32 of those rows** to 86,400s (24h endgame per Decision #8). The 6 L65-66 mid-tier named already at 64,800s (18h) stay; Milas at 14,400s (4h) stays; Defender cluster excluded.

**Adjusted verdict:** Config-expert's "zero rule/config changes" conclusion holds. `spawn2.respawntime` UPDATEs are still valid as SQL-only changes (not rule changes). Architect has incorporated the broader spawn2 update list into implementation task B6.

**Config-expert role in Phase 4b implementation is identical to Phases 2/3/4a:**
1. No rule changes needed.
2. No `eqemu_config.json` / `.env` changes.
3. Post-SQL: `#reloadworld` via world telnet (port 9000) — Task B9.
4. Smoke verification via DB read-back on `npc_types` HP/damage + `spawn2.respawntime` for ~32 rows — Task B10.
5. No zone-restart caveat (no `npc_spells_entries` changes).

### 2026-04-23 — Lore-master Phase 4b consultation (in flight)

Architect dispatched 10 questions to lore-master on 2026-04-23:
1. Sleeper Awake boundary clarification (Option A/B/C for Warder scaling)
2. Vulak altar-summon chain details
3. ToV keying confirmation
4. Sleeper's Tomb keying confirmation (Lendiniara talisman role)
5. Vulak / ToV Epic 1.0 dependency check
6. NToV mid-tier named quest-chain ties
7. AoW quest chain / progression ties
8. NToV Defenders (Emerald/Sky/Onyx/Lava) scope confirmation
9. Signature mechanics list per boss
10. Respawn tier confirmation (24h endgame)

**Expected response:** Decision #36 resolution (Option A/B/C), signature mechanics list per boss, any gap-flagging for NToV mid-tier named. Will be appended here and in agent-conversations.

