# Raid Scaling — Architecture & Implementation Plan (Phase 5a: Luclin non-VT)

> **Feature branch:** `feature/raid-scaling`
> **PRD:** `game-designer/prd.md`
> **Audit:** `game-designer/raid-scaling-audit.md` (Luclin section lines 2166-2515)
> **Lore catalog:** `lore-master/luclin-chains.md` (all 9 sections — Luclin epic phase has zero Epic 1.0 dependency)
> **Phase 2 reference:** `architect/architecture.md` (Classic — pattern)
> **Phase 3 reference:** `architect/kunark-architecture.md`
> **Phase 4a reference:** `architect/velious-a-architecture.md`
> **Phase 4b reference:** `architect/velious-b-architecture.md` (most-recent pattern — Phase 5a mirrors this structure)
> **DB investigation:** `architect/context/luclin-a-db-investigation.md`
> **Author:** architect
> **Date:** 2026-04-23
> **Status:** **READY FOR USER REVIEW 2026-04-23.** Two advisors cleared (protocol-agent 2026-04-22 full Q1-Q10 + initial flags; config-expert 2026-04-22 — pattern holds, zero rule changes, DT sweep clean from their angle). Lore-master Phase 5a consultation in flight (luclin-chains.md serves as primary lore reference; six follow-up questions sent 2026-04-23 — sign-off pending). Three user-decision items surfaced.
> **Scope:** **Phase 5a ONLY.** Ssraeshza Temple (13 bosses + 2 flagged-for-lore), Akheva Ruins (8 bosses), Sanctus Seru / Katta Castellum (7 bosses), Grieg's End (3 bosses), Acrylia Caverns (2 bosses including Khati Sha), The Deep (1 boss), Umbral Plains (3 bosses), Echo Caverns (0 — Decision #2 elite-named tier). **Out of scope permanently for Phase 5a:** Vex Thal proper, Yaemiu elite trash (vexthal-exclusive per protocol-agent verification), Va_Dyn_Khar (158081, vexthal), Akhevan Warders (158087-94, vexthal — name-misleading but VT-zoned), 13-shard VT key rework, Spirit of Akelha`Ra (179144, VT-key turn-in NPC — Decision #30 precedent).

---

## Executive Summary

Phase 5a scales the Luclin non-VT raid tier — Ssraeshza Temple, Akheva Ruins, Sanctus Seru / Katta Castellum, Grieg's End, Acrylia Caverns, The Deep, and Umbral Plains — using the **same 100% SQL pattern established in Phases 2, 3, 4a, and 4b**. Zero script edits. Zero rule changes. Zero C++.

This is the **final-era endgame tier** per Decision #1 — the hardest in-era fights before the Phase 5b Vex Thal pinnacle. HP cuts are the deepest in the project (target -85% to -92%) because Luclin has the largest current gap (Emperor Ssraeshza 1.25M HP = 42× scaled-named L66 target). Endgame respawn per Decision #8 is 24h (86,400s), matching Phase 4b.

**Six significant differences from Phase 4b:**

1. **Heavy script-spawn population.** 9 of 35 in-scope bosses (Emperor Ssraeshza, Blood of Ssraeshza, Ssraeshzian Blood Golem, all 3 Vyzh\`dra variants, Arch Lich Rhag\`Zadune, Rhag\`Mozdezh, Doomshade, Khati Sha, Grieg Veneficus main 163075) are spawned by Lua/Perl scripts via `quest::spawn2`/`unique_spawn`/`eq.unique_spawn` and have NO `spawn2` rows. Pattern matches Phase 4b's AoW 113457 + Vulak`Aerr 124155 (script-spawned, no respawn UPDATE), but at much larger scale. Phase 4b had 2 script-spawned bosses; Phase 5a has 9. Their cycle timers live in scripts and per Decision #11 are NOT edited — preserved native (Emperor's 3-5 day post-kill `$EmpRepopTime` and 3-4h `$BloodCoolDownTime` failure cooldown stay as-is).

2. **First Phase to need a death-touch DELETE since Phase 2.** DT sweep found exactly one hit: spell **2859 "Touch of Vinitras"** (-20,000 HP, mana 0, cast 0, recast 120s) in spell list 196, used by Vyzh\`dra the Exiled (162232) and Vyzh\`dra the Banished (162214). DELETE follows Decision #16 (Cazic Touch DELETE) and Decision #13 (PoSky DT removal unblocks epic progression) precedent. List 197 (Vyzh\`dra the Cursed) is clean. **One row DELETE.** Config-expert's independent sweep returned zero hits across their list of "spell 982 Cazic Touch" — confirms Phase 2's specific spell is not redeployed in Luclin; the Luclin-era DT is a different spell ID with the same DT signature.

3. **Two newly-discovered raid_target=1 NPCs not in audit** (Phase 5a flag for user/lore-master decision):
   - **162253 #a_rune_covered_serpent** (L63, 221k HP, ssratemple)
   - **162261 #a_glyph_covered_serpent** (L63, 300k HP, ssratemple)
   Both have scripts in ssratemple quest dir; both are part of `#cursed_controller.pl` orchestration per protocol-agent. Architect default: include in Phase 5a scope as Vyzh\`dra-chain stepping stones (per protocol-agent Flag C — they are intermediate forms). Lore-master sign-off pending — see Decision #50 below.

4. **Vyzh\`dra trio (162206 / 162232 / 162214) is the most complex script-driven encounter in Phase 5a.** Per protocol-agent Flag C, these are sequential forms: Cursed (final boss, 900k) preceded by Banished (403k) and Exiled (450k). All three carry boss-tier HP. Phase 5a scales all three — the Cursed gets the deepest cut (90% to 90k); the two intermediate forms get proportional cuts (~85% to 60-70k each). Touch of Vinitras DT removal (item 2 above) makes the intermediate forms tractable for a small group.

5. **Shei Vinitras has TWO npc_type IDs (Flag B from protocol-agent).** Audit listed only 179157 (#Shei_Vinitras_, the merchant/decoy form, 400k HP, 145-400 dmg, standard-immunity-only flags, spawn2-backed at 194,474s respawn). The REAL fight boss is **179032 #Shei_Vinitras (no underscore)** — L64, **690k HP**, 273-700 dmg, has spell list 179. Architect scope: scale BOTH. The merchant form 179157 gets a deeper cut (400k → 60k per audit) because trigger-killing it should not itself be a raid-tier wall; the real boss 179032 gets the standard cut to ~85k.

6. **Two Lord Inquisitor Seru-tier "MR walls."** Lord Inquisitor Seru (159691, MR=800) and Lord Vyemm-style caster-resist signature carries forward into Phase 5a. Decision #11 preserve. Small-group caster-heavy comps need a backup melee plan for Seru (same friction as Vyemm in Phase 4b). Plus the Praesertum cluster all use spell list 1086/1087 with no DT but standard combat spells.

**Change footprint:**
- **~37 `npc_types` HP/damage UPDATEs** — 13 ssratemple + 2 lore-master-flagged serpents (default include) + 8 akheva (3 Vyzh\`dra + Itraer Vius + Shei real + Shei merchant + Insanity Crawler + Va\`Dyn) + 7 sseru/katta + 3 griegsend + 2 acrylia + 1 thedeep + 3 umbral. Plus 2 elite-named-tier akheva (Sheleric Vis, Xaui Tatrua) flagged for user — see Decision #51.
- **~16-18 `spawn2.respawntime` UPDATEs** to 86,400s (24h endgame tier). Most Phase 5a bosses are script-spawned (no spawn2 row), so the respawn UPDATE list is far smaller than Phase 4b's ~32 rows.
- **1 `npc_spells_entries` DELETE** — Touch of Vinitras spell 2859 from list 196 (precedent: Decision #16). Architect-recommended.
- **0 Lua or Perl script edits.** Per Decision #11. Emperor cycle timers, Vyzh\`dra script chain, Doomshade mechanics, Khati Sha script, Grieg Veneficus chain, Shei Vinitras trigger-and-real spawn-swap, Lord Inquisitor Seru placeholder swap — all preserved untouched.
- Backup tables: `npc_types_backup_raid_scaling_luclin_a`, `spawn2_backup_raid_scaling_luclin_a`, `npc_spells_entries_backup_raid_scaling_luclin_a` (the third backup is 1-row, capturing the Touch of Vinitras DELETE for rollback).

**No C++ changes. No `rule_values` changes. No `eqemu_config.json` changes. No `.env` changes.** Protocol-agent confirmed zero client-visibility impact (2026-04-22 full Q1-Q10 log). Config-expert confirmed pattern carryover with zero rule changes, ruleset=1 across all Phase 5a zones, and zero DZ/instance configuration on this PEQ version.

**User-decision items surfaced:**
- **Decision #50** — Rune/glyph serpent inclusion (162253/162261, ssratemple, 221k/300k HP, raid_target=1, audit-missed). Architect recommends INCLUDE per protocol-agent Flag C (they're chain stepping-stones). Lore-master sign-off pending.
- **Decision #51** — Akheva elite-named tier (Sheleric Vis 179133/179046, Xaui Tatrua 179044, all 70-116k HP, 5,400s respawn). Architect recommends EXCLUDE per Decision #2 (elite-named tier untouched) — same posture as Phase 2's "Night Crew" exclusion. User can override.
- **Decision #52** — Emperor Ssraeshza 3-5 day post-kill respawn (`#EmpCycle.pl` `$EmpRepopTime`). Architect recommends KEEP NATIVE per Decision #11 + Decision #45 (Thylex precedent — script-driven respawn timers preserved). Alternative: invoke perl-expert to soften to 24h endgame tier (per protocol-agent Flag A — would require `#EmpCycle.pl` edit). User decision.

---

## Existing System Analysis

### Current State

**Phases 2, 3, 4a, and 4b landed.** User has validated all four prior phases. Phase 4b accepted 2026-04-23 (server-side PASS 127 checks; user accepted in-game-deferred). Final era beginning.

**Prior-pass globals remain authoritative and unchanged:**
- `NPCFlurryChance=12`, `MaxRampageTargets=2`, `NPCAssistCap=3`, `StartEnrageValue=5`, `GlobalLootMultiplier=2`, `CurrentExpansion=3`, `AllowRaidTargetBlind=false`
- `rule_values` count: **1,112** (re-verified by config-expert 2026-04-22 for Phase 5a — zero drift)
- `zone.ruleset=1` (default) applies to ALL Phase 5a zones (`ssratemple`, `akheva`, `sseru`, `katta`, `griegsend`, `acrylia`, `thedeep`, `umbral`, `echo`) per config-expert 2026-04-22.

**Phase 5a content at PEQ defaults** per audit + DB confirmation:

**Ssraeshza Temple — 13 in-scope bosses + 2 flagged serpents:**
- **Emperor Ssraeshza (162227, L66, 1.25M HP, 904 max dmg, MR=386).** Script-spawned via `#EmpCycle.pl`. Signature: 2-phase encounter (Blood phase + Emperor phase), 30-min engagement timer, 40-min combat timer, post-mortem 5×shissar_wraith, qglobal-driven 3-5 day respawn. special_abilities includes `32,1,290` = Leash with 290 distance.
- **High Priest of Ssraeshza (162076, L66, 941k HP), Xerkizh the Creator (162190, L66, 806k HP), Arch Lich Rhag\`Zadune (162177, L64, 790k HP), Rhag\`Mozdezh (162192, L63, 226k HP), Rhag\`Zhezum (162178, L63, 201k HP).** Rhag lich line.
- **Blood of Ssraeshza (162189, L63, 200k HP)** — Emperor phase-1 gate (must be killed before Emperor real spawns). Script-spawned by `#EmpCycle.pl` and `#Blood_of_Ssraeshza.lua`.
- **Ssraeshzian Blood Golem (162064, L63, 201k HP)** — Emperor failure-retry gate. Script-spawned.
- **Pre-Emperor named (Advisor Zekuzh 162067 L53 150k HP, Arbiter Korazhk 162191 L55 205k HP, General Kizuhx 162066 L53 250k HP)** — static spawns, 17 spawn2 rows each at 1,080s (18m) respawn — short-tier farmable. Per `luclin-chains.md` Section 2 these drop Ssraeshzian Insignia for Ring of the Shissar.
- **Rhozth Ssrakezh (162258, L60, 119k HP, 5,400s respawn) + Rhozth Ssravizh (162089, L60, 105k HP, 21,600s respawn).** Mid-tier named. Lore-master Section 2 confirms basement Taskmaster's Pouch source includes "Rhozth Ssravizh" — quest-drop dependency.
- **Flagged for lore-master (Decision #50): #a_rune_covered_serpent (162253, 221k HP) + #a_glyph_covered_serpent (162261, 300k HP).** raid_target=1, scripted via `#cursed_controller.pl`. Audit-missed.

**Akheva Ruins — 8 in-scope bosses (+ 2 elite-named flagged):**
- **3 Vyzh\`dra variants (162206 Cursed 900k / 162232 Exiled 450k / 162214 Banished 403k).** All script-spawned. Touch of Vinitras DT in list 196 (Exiled + Banished only). The Cursed uses clean list 197.
- **The Itraer Vius (179037, L63, 601k HP)** — spawn2-backed at 210,924s.
- **Shei Vinitras dual form: 179032 REAL (L64, 690k HP, 273/700) + 179157 MERCHANT (L65, 400k HP, 145/400, only-immunities special_abilities, spell list 0)** — protocol-agent Flag B. Both in scope.
- **The Insanity Crawler (179180, L63, 401k HP)** — 210,924s respawn.
- **The Va\`Dyn (179178, L63, 250k HP)** — 194,400s respawn.
- **Shar Vinitras (179134, L63, 460.9k HP, 250-1010 dmg)** — 10,800s (3h) respawn already short-tier.
- **Flagged for user Decision #51 (default EXCLUDE):** Sheleric Vis (179133 + 179046 variant, 70-116k HP, 5,400s respawn — elite named tier per Decision #2). Xaui Tatrua (179044, 70k HP, 5,400s — elite named).

**Sanctus Seru / Katta Castellum — 7 in-scope bosses:**
- **Lord Inquisitor Seru (159691, L66, 1.2M HP, 915 max dmg, MR=800)** — caster-wall signature per Decision #11 preserve.
- **4 Praesertum (Vantorus 159113 250k / Rhugol 159112 200k / Bikun 159115 160k / Matpa 159114 150k, all L66, 259,200s respawn)**.
- **Lcea Katta (160375, L60, 401k HP, 827 max)** — Katta endboss, 258,750s respawn.
- **Nathyn Illuminious (160135, L64, 430k HP)** — 194,400s respawn.

**Grieg's End — 3 in-scope bosses + variant:**
- **Grieg Veneficus (163075, L65, 475.5k HP, MAIN, script-spawned).** No spawn2.
- **Grieg Veneficus variant (163231, L65, 162.5k HP, spawn2-backed at 561,600s = 156h respawn outlier).** Already at scaled-tier HP; respawn UPDATE only.
- **Servitor of Luclin (163013, L65, 120k HP)** — 194,400s respawn. "Easiest Luclin raid boss" per `luclin-chains.md` Section 4.
- **Praetorian Myral (163078, L60, 95k HP)** — 70,308s (~19.5h) respawn.

**Acrylia Caverns — 2 in-scope bosses:**
- **Khati Sha the Twisted (154145, L68, 475k HP, 400-1004 dmg)** — script-spawned (`acrylia/Khati_Sha_the_Twisted.lua`). Zone confirmed `acrylia` (NOT grimling per audit's "?").
- **#an_evolved_burrower (154142, L63, 300.75k HP, 200-693 dmg)** — 97,200s (27h) respawn. Audit line 2345 says "reduce respawn."

**The Deep — 1 in-scope boss:**
- **Thought Horror Overfiend (164078, L63, 807k HP, 282-776 dmg)** — 194,400s respawn.

**Umbral Plains — 3 in-scope bosses:**
- **#Doomshade (176088, L66, 350k HP, 127-412 dmg, no spell list)** — script-spawned (`umbral/#Doomshade.lua`). **Audit-missed; new find.**
- **#Zelnithak (176089, L60, 251k HP, 115-400)**.
- **#Rumblecrush (176002, L66, 150k HP, 226-720)**.

**Echo Caverns — 0 in-scope:**
- General Jared Blaystich (153095, L55, 60k HP, 78-254) — already elite-named tier per audit line 2350. Decision #2 applies.

### Gap Analysis

| Gap | Lever |
|-----|-------|
| Emperor Ssraeshza 1.25M HP / 904 max dmg (42× scaled-named L66 target ~30k) | `npc_types.hp` 90% cut to 120k; `maxdmg` 31% trim to 620 per audit |
| High Priest of Ssraeshza 941k HP (31× gap) | HP 90% cut to 90k |
| Xerkizh the Creator 806k HP (27× gap) | HP 90% cut to 80k |
| Arch Lich Rhag\`Zadune 790k HP (26× gap) | HP 90% cut to 75k |
| Vyzh\`dra the Cursed 900k HP / 588 dmg (30× gap) | HP 90% cut to 90k |
| Vyzh\`dra Exiled 450k + Banished 403k (15× gap) | HP 85% cuts to 65-70k each + Touch of Vinitras DT DELETE |
| Lord Inquisitor Seru 1.2M HP / 915 dmg / **MR=800** (40× gap, MR-wall preserved) | HP 90% cut to 120k; damage trim 30% to 620; **MR=800 untouched** per Decision #11 |
| Lcea Katta 401k HP / 827 max (13× gap) | HP 80% cut to 80k; damage trim 25% to 620 |
| Nathyn Illuminious 430k HP (14× gap) | HP 81% cut to 80k |
| The Itraer Vius 601k HP (20× gap) | HP 87% cut to 80k |
| Shar Vinitras 460.9k HP / 1010 dmg (15× gap; 1010 dmg outlier) | HP 85% cut to 70k; damage 40% trim to 600 |
| Shei Vinitras REAL 179032 690k (23× gap) + MERCHANT 179157 400k (13× gap) | REAL: HP 85k; MERCHANT: HP 60k (deeper cut so trigger-kill is not raid-tier itself) |
| The Insanity Crawler 401k HP (13× gap) | HP 85% cut to 60k |
| The Va\`Dyn 250k HP (8× gap) | HP 80% cut to 50k |
| Khati Sha the Twisted 475k HP / 1004 dmg (16× gap) | HP 81% cut to 90k; damage 25% trim to 750 per audit |
| Thought Horror Overfiend 807k HP (27× gap) | HP 89% cut to 90k |
| #Doomshade 350k HP (audit-missed; 12× gap) | HP 80% cut to 70k (architect target — split between Servitor 40k and Khati Sha 90k) |
| Grieg Veneficus 475.5k HP (16× gap) | HP 83% cut to 80k per audit |
| Servitor of Luclin 120k HP (4× gap, "easiest Luclin raid") | HP 67% cut to 40k per audit |
| Praetorian Myral 95k HP | HP 63% cut to 35k per audit |
| #an_evolved_burrower 300.75k HP / 27h respawn | HP 80% cut to 60k; respawn 24h per Decision #8 |
| Zelnithak 251k HP / Rumblecrush 150k HP | Zelnithak HP 76% cut to 60k; Rumblecrush HP 70% cut to 45k per audit |
| Pre-Emperor named (Kizuhx 250k / Korazhk 205k / Zekuzh 150k) | HP 76-70% cuts to 50-60k per audit (preserve Ring of the Shissar drop chain) |
| Rhozth Ssrakezh 119k / Rhozth Ssravizh 105k | HP 60-65% cuts to 40k each (preserves Taskmaster's Pouch quest-drop dependency) |
| Touch of Vinitras DT (-20,000 in spell list 196) | DELETE row from `npc_spells_entries` |
| Most Phase 5a spawn2 at 54-72h respawn (Decision #8 endgame = 24h) | `spawn2.respawntime` 86,400s on ~16-18 rows |

### What is NOT gap for Phase 5a

- **No C++ changes.** Same rationale as Phases 2, 3, 4a, 4b.
- **No `rule_values` changes.** Confirmed by config-expert 2026-04-22.
- **No loot table changes.** Per Decision #3.
- **No script edits.** Decision #11. Emperor cycle / Vyzh\`dra chain / Doomshade / Khati Sha / Shei Vinitras spawn-swap / Lord Inquisitor Seru placeholder / Grieg cycle all preserved untouched.
- **No `special_abilities` CSV edits.** Decision #11. Lord Inquisitor Seru MR=800 preserved. Emperor's Leash 290 preserved. Vyzh\`dra trio's chain orchestration preserved.
- **No spawn_conditions edits.** Phase 5a zones don't use raid-gate spawn_conditions (verified by config-expert and DB query).
- **No Spirit of Akelha\`Ra (179144) edit.** VT-key turn-in NPC at 1M HP, raid_target=1 — Decision #30 precedent (Jaled Dar's Shade).
- **No Akhevan Warder (158087-94) edits — they're vexthal-zoned.** Phase 5b scope. Confirmed by DB.
- **No Va_Dyn_Khar (158081) edit.** vexthal-zoned. Phase 5b scope. Confirmed by DB.
- **No Yaemiu trash edits.** vexthal-exclusive. Phase 5b scope (Decision #7 covers 5b).
- **Echo Caverns General Blaystich** — already elite-named tier. Decision #2.
- **Emperor placeholder 162065 (6.5k HP, no-target).** Per protocol-agent's flag in initial findings — not a fight target. Excluded from SQL.
- **Event-control NPCs (162269 keycheck 999M HP, 176110 Keymaster 99M HP, 160177/178 Helsin twins 1M HP each).** Excluded per protocol-agent Q6.
- **Out-of-era NPCs**: 163051 (L75 LoN), 163052 (L80 LoN), 154161 (L80 Fabled Khati Sha), 176111 (L73 Netherbian Swarmfiend OOE) — all excluded by `min_expansion`/`max_expansion` filtering at runtime per config-expert verification.

**Relevant topography:**
- `claude/docs/topography/SQL-CODE.md` — npc_types, spawn2, spawnentry, npc_spells_entries chain
- `claude/docs/topography/PERL-CODE.md` — `quest::unique_spawn`, `quest::signalwith`, `quest::setglobal` Perl API
- `claude/docs/topography/LUA-CODE.md` — `eq.spawn2`, `eq.unique_spawn`, `eq.set_timer`, encounter system

---

## Technical Approach

### Architecture Decision

**Every Phase 5a change is either a single-column `UPDATE` on `npc_types`/`spawn2` or one targeted DELETE on `npc_spells_entries`.** Per the layer priority (rules > config > Lua > SQL > C++):

1. **Rules — NOT APPLICABLE.** Confirmed by config-expert 2026-04-22; rule_values count 1,112 unchanged.
2. **Config (`eqemu_config.json` / `.env`) — NOT APPLICABLE.** No structural changes.
3. **Lua/Perl scripts — NOT APPLICABLE.** Phase 5a targets NPC stats only. All signature behaviors (Emperor cycle, Vyzh\`dra chain, Shei dual-form, Lord Seru placeholder, Grieg cycle, Doomshade/Khati Sha mechanics, Emperor 30/40-min timers, post-mortem wraiths, Rage of Ssraeshza buff, Leash 290) are scripted/configured — but read NPC stats at runtime, not at script load — scripts need no edits to accommodate new HP values.
4. **SQL — YES.** `npc_types` UPDATEs for HP/damage, `spawn2` UPDATEs for respawn, `npc_spells_entries` DELETE for Touch of Vinitras.
5. **C++ — NOT APPLICABLE.** No engine change needed.

### Component Change Table

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `npc_types.hp` (~37 Phase 5a bosses) | UPDATE per-NPC | Audit targets vary 60-90% cut; per-NPC precision required |
| `npc_types.maxdmg` (Emperor / Lord Seru / Lcea Katta / Khati Sha / Shar Vinitras / Rumblecrush) | UPDATE per-NPC | Damage outliers (904/915/827/1004/1010/720) need caps |
| `npc_types.mindmg` (Emperor + Lord Seru — proportional pair with maxdmg) | UPDATE per-NPC | Pinnacle fights |
| `spawn2.respawntime` (~16-18 rows at >24h or where audit calls for reduction) | UPDATE per-spawn | Target 86,400s = 24h endgame per Decision #8 |
| `npc_spells_entries` DELETE WHERE npc_spells_id=196 AND spellid=2859 | DELETE 1 row | Touch of Vinitras DT removal — Decision #16 / Decision #13 precedent |
| `npc_types.special_abilities` | **NO CHANGE** | Decision #11 preserves all signature mechanics |
| `npc_types.MR` | **NO CHANGE** | Lord Inquisitor Seru MR=800 wall preserved |
| Backup tables `npc_types_backup_raid_scaling_luclin_a`, `spawn2_backup_raid_scaling_luclin_a`, `npc_spells_entries_backup_raid_scaling_luclin_a` | CREATE + INSERT-SELECT | Mirrors prior phase patterns with `_luclin_a` suffix |
| `rule_values` | NO CHANGE | Confirmed by config-expert |
| `eqemu_config.json` / `.env` | NO CHANGE | Same as Phase 4b |
| Lua/Perl scripts | NO CHANGE | All signature behaviors read NPC stats at runtime |
| C++ source | NO CHANGE | N/A |

### Data Model

#### Backup tables (captured BEFORE any other change)

```sql
CREATE TABLE npc_types_backup_raid_scaling_luclin_a AS
SELECT id, hp, mindmg, maxdmg, AC, MR, special_abilities, npcspecialattks, npc_spells_id
FROM npc_types
WHERE id IN (
    -- ssratemple — 13 + 2 flagged serpents (Decision #50 default include)
    162227, 162076, 162190, 162177, 162192, 162178,
    162189, 162064,                                 -- Blood + Blood Golem
    162066, 162067, 162191,                         -- pre-Emperor named L53/55
    162258, 162089,                                 -- Rhozth pair
    162253, 162261,                                 -- rune/glyph serpents (Decision #50)
    -- akheva — 8 (excludes Sheleric Vis + Xaui Tatrua per Decision #51)
    162206, 162232, 162214,                         -- Vyzh`dra trio
    179037, 179032, 179157, 179180, 179178, 179134, -- Itraer Vius + Shei real + Shei merchant + Insanity Crawler + Va`Dyn + Shar Vinitras
    -- sseru/katta — 7
    159691, 159113, 159112, 159115, 159114,
    160375, 160135,
    -- griegsend — 3 (+ 1 variant)
    163075, 163231, 163013, 163078,
    -- acrylia — 2
    154145, 154142,
    -- thedeep — 1
    164078,
    -- umbral — 3
    176088, 176089, 176002
);
-- Expected rows: 37 (assuming Decision #50 includes 162253/162261; Decision #51 excludes)
-- If Decision #50 = exclude: 35 rows. If Decision #51 = include: 39 rows.

CREATE TABLE spawn2_backup_raid_scaling_luclin_a AS
SELECT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance,
       s2._condition, s2.cond_value, s2.x, s2.y, s2.z, s2.heading
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID IN (
    162076, 162190, 162178,                         -- ssratemple standing-spawn (3 rows)
    162066, 162067, 162191,                         -- pre-Emperor 17 spawn2 each = 51 rows (already short-tier 1080s; backup for safety, NOT in respawn UPDATE)
    162258, 162089,                                 -- Rhozth pair (2 rows; mid-tier respawn already)
    179037, 179032, 179157, 179180, 179178, 179134, -- akheva 6 rows
    159691, 159113, 159112, 159115, 159114,         -- sseru 5 rows
    160375, 160135,                                 -- katta 2 rows
    163231, 163013, 163078,                         -- griegsend variant + Servitor + Praetorian (3 rows; 163075 has no spawn2)
    154142,                                         -- acrylia evolved burrower (1 row)
    164078,                                         -- thedeep Thought Horror (1 row, if exists — query confirmation needed)
    176089, 176002                                  -- umbral Zelnithak + Rumblecrush (rows TBD)
);
-- Expected rows: ~16-18 standing-spawn rows + ~51 pre-Emperor rows captured (but only the standing-spawn raid-tier ~16-18 get respawn UPDATE; pre-Emperor preserved)
-- Note: 162227 Emperor + 162065 placeholder + 162064 Blood Golem + 162189 Blood + 162177 Rhag`Zadune + 162192 Rhag`Mozdezh + 162206/214/232 Vyzh`dra trio + 162253/261 serpents + 154145 Khati Sha + 176088 Doomshade + 163075 Grieg main have NO spawn2 rows (script-spawned)

CREATE TABLE npc_spells_entries_backup_raid_scaling_luclin_a AS
SELECT * FROM npc_spells_entries
WHERE npc_spells_id = 196 AND spellid = 2859;
-- Expected rows: 1 (Touch of Vinitras DT)
```

#### Phase 5a change sketch (data-expert emits final SQL; values sourced from `context/luclin-a-db-investigation.md` + audit lines 2222-2375)

**Ssraeshza Temple:**

```sql
-- Top-tier (Decision #11 preserves Emperor add waves, 30/40-min timers, Leash 290)
UPDATE npc_types SET hp = 120000, mindmg = 200, maxdmg = 620 WHERE id = 162227;  -- Emperor Ssraeshza 1.25M→120k, 904→620
UPDATE npc_types SET hp =  90000                              WHERE id = 162076;  -- High Priest 941k→90k
UPDATE npc_types SET hp =  80000                              WHERE id = 162190;  -- Xerkizh 806k→80k
UPDATE npc_types SET hp =  75000                              WHERE id = 162177;  -- Arch Lich Rhag`Zadune 790k→75k
UPDATE npc_types SET hp =  60000                              WHERE id = 162192;  -- Rhag`Mozdezh 226k→60k
UPDATE npc_types SET hp =  55000                              WHERE id = 162178;  -- Rhag`Zhezum 201k→55k

-- Emperor cycle gate mobs (preserves cycle behavior; HP cuts make gate tractable for small group)
UPDATE npc_types SET hp =  60000                              WHERE id = 162189;  -- Blood of Ssraeshza 200k→60k
UPDATE npc_types SET hp =  60000                              WHERE id = 162064;  -- Blood Golem 201k→60k

-- Pre-Emperor named (Ring of the Shissar Insignia drop preserved; 17 spawn2 rows each; respawn UNCHANGED at 1080s short-tier)
UPDATE npc_types SET hp =  60000, maxdmg = 510 WHERE id = 162066;  -- General Kizuhx 250k→60k
UPDATE npc_types SET hp =  55000               WHERE id = 162191;  -- Arbiter Korazhk 205k→55k
UPDATE npc_types SET hp =  45000               WHERE id = 162067;  -- Advisor Zekuzh 150k→45k

-- Rhozth pair (Taskmaster's Pouch quest-drop dependency)
UPDATE npc_types SET hp =  40000               WHERE id = 162258;  -- Rhozth Ssrakezh 119k→40k
UPDATE npc_types SET hp =  38000               WHERE id = 162089;  -- Rhozth Ssravizh 105k→38k

-- Decision #50 default include — rune/glyph serpents (architect recommends)
UPDATE npc_types SET hp =  60000               WHERE id = 162253;  -- rune-covered serpent 221k→60k
UPDATE npc_types SET hp =  70000               WHERE id = 162261;  -- glyph-covered serpent 300k→70k
```

**Akheva Ruins:**

```sql
-- Vyzh`dra trio (script-spawned)
UPDATE npc_types SET hp =  90000               WHERE id = 162206;  -- Vyzh`dra the Cursed 900k→90k
UPDATE npc_types SET hp =  70000               WHERE id = 162232;  -- Vyzh`dra the Exiled 450k→70k (post-DT-removal tractable)
UPDATE npc_types SET hp =  65000               WHERE id = 162214;  -- Vyzh`dra the Banished 403k→65k

-- Akheva spawn2-backed
UPDATE npc_types SET hp =  80000               WHERE id = 179037;  -- Itraer Vius 601k→80k
UPDATE npc_types SET hp =  85000, maxdmg = 600 WHERE id = 179032;  -- Shei Vinitras REAL 690k→85k, 700→600
UPDATE npc_types SET hp =  60000               WHERE id = 179157;  -- Shei Vinitras MERCHANT 400k→60k (deeper cut so trigger-kill not raid-tier)
UPDATE npc_types SET hp =  60000               WHERE id = 179180;  -- Insanity Crawler 401k→60k
UPDATE npc_types SET hp =  50000               WHERE id = 179178;  -- Va`Dyn 250k→50k
UPDATE npc_types SET hp =  70000, maxdmg = 600 WHERE id = 179134;  -- Shar Vinitras 460.9k→70k, 1010→600 (signature-damage cap)

-- Touch of Vinitras DT removal (Phase 2 Decision #16 pattern)
DELETE FROM npc_spells_entries WHERE npc_spells_id = 196 AND spellid = 2859;
-- 1 row affected
```

**Sanctus Seru / Katta Castellum:**

```sql
-- Lord Inquisitor Seru — MR=800 PRESERVED (signature mechanic per Decision #11)
UPDATE npc_types SET hp = 120000, mindmg = 220, maxdmg = 620 WHERE id = 159691;  -- Lord Seru 1.2M→120k, 915→620

-- Praesertum cluster (4 NPCs)
UPDATE npc_types SET hp =  55000               WHERE id = 159113;  -- Praesertum Vantorus 250k→55k
UPDATE npc_types SET hp =  50000               WHERE id = 159112;  -- Praesertum Rhugol 200k→50k
UPDATE npc_types SET hp =  45000               WHERE id = 159115;  -- Praesertum Bikun 160k→45k
UPDATE npc_types SET hp =  45000               WHERE id = 159114;  -- Praesertum Matpa 150k→45k

-- Katta endbosses
UPDATE npc_types SET hp =  80000, maxdmg = 620 WHERE id = 160375;  -- Lcea Katta 401k→80k, 827→620
UPDATE npc_types SET hp =  80000               WHERE id = 160135;  -- Nathyn Illuminious 430k→80k
```

**Grieg's End / Acrylia / The Deep / Umbral:**

```sql
-- Grieg's End
UPDATE npc_types SET hp =  80000               WHERE id = 163075;  -- Grieg Veneficus MAIN 475k→80k (script-spawned)
-- 163231 variant already at 162.5k HP — leave HP unchanged; only respawn UPDATE
UPDATE npc_types SET hp =  40000               WHERE id = 163013;  -- Servitor of Luclin 120k→40k
UPDATE npc_types SET hp =  35000               WHERE id = 163078;  -- Praetorian Myral 95k→35k

-- Acrylia
UPDATE npc_types SET hp =  90000, maxdmg = 750 WHERE id = 154145;  -- Khati Sha the Twisted 475k→90k, 1004→750
UPDATE npc_types SET hp =  60000               WHERE id = 154142;  -- evolved burrower 300.75k→60k

-- The Deep
UPDATE npc_types SET hp =  90000               WHERE id = 164078;  -- Thought Horror Overfiend 807k→90k

-- Umbral Plains
UPDATE npc_types SET hp =  70000               WHERE id = 176088;  -- Doomshade 350k→70k (audit-missed, architect target)
UPDATE npc_types SET hp =  60000               WHERE id = 176089;  -- Zelnithak 251k→60k
UPDATE npc_types SET hp =  45000, maxdmg = 600 WHERE id = 176002;  -- Rumblecrush 150k→45k, 720→600
```

**Respawn timer UPDATEs (Decision #8 endgame = 86,400s / 24h):**

```sql
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 86400
WHERE se.npcID IN (
    -- ssratemple (3 rows; pre-Emperor 1080s preserved as short-tier farmable; Rhozth pair preserved at 5400s/21600s mid-tier)
    162076, 162190, 162178,
    -- akheva (6 rows; Shar Vinitras 10800s preserved as short-tier per audit)
    179037, 179032, 179157, 179180, 179178,
    -- sseru/katta (7 rows)
    159691, 159113, 159112, 159115, 159114,
    160375, 160135,
    -- griegsend (3 rows; 163075 main has no spawn2)
    163231, 163013, 163078,
    -- acrylia (1 row)
    154142,
    -- thedeep (1 row, if spawn2 confirmed)
    164078,
    -- umbral (2 rows)
    176089, 176002
);
-- Expected: ~17-18 rows updated
-- NOT updated (preserved):
--   162066, 162067, 162191 — pre-Emperor 17 spawn2 rows each at 1080s (Ring of the Shissar farming cadence)
--   162258, 162089 — Rhozth at 5400s/21600s mid-tier (Taskmaster's Pouch farming cadence)
--   179134 Shar Vinitras at 10800s (audit explicitly says "respawn fine" — short-tier preserved)
--   179133, 179046, 179044 — Sheleric Vis + Xaui Tatrua at 5400s (Decision #51 elite-named exclude)
--   163075 Grieg main, 162227 Emperor, 162177 Rhag`Zadune, 162192 Rhag`Mozdezh, 162064 Blood Golem, 162189 Blood, 162206/214/232 Vyzh`dra trio, 162253/261 serpents, 154145 Khati Sha, 176088 Doomshade — script-spawned, no spawn2 row
```

### Code Changes

**None.** Zero files modified in `eqemu/`, `akk-stack/server/quests/`, or `akk-stack/npc-llm-sidecar/`.

All Phase 5a behavioral preservation works because quest scripts query NPC state via `entity_list->GetMobByNpcTypeID()` / `entity_list:GetNPCByNPCTypeID()` (returns live NPC if present) and signal/spawn-target by NPC ID. None of these APIs read HP thresholds (verified by protocol-agent's grep — zero `setnexthpevent` / `EVENT_HP` usage in Phase 5a quest scripts; sole HP-thresholded encounter is Phara Dar in Phase 3).

### Configuration Changes

No `rule_values` changes. No `eqemu_config.json` changes. No `.env` changes. Confirmed by config-expert 2026-04-22 (rule_values count 1,112 unchanged; Phase 5a zone ruleset=1; no DZ).

### Database Changes

| Item | Type | Rows affected (approx) |
|------|------|------------------------|
| `npc_types_backup_raid_scaling_luclin_a` | CREATE TABLE AS SELECT | 37 rows snapshot (35 if Decision #50 = exclude; 39 if Decision #51 = include) |
| `spawn2_backup_raid_scaling_luclin_a` | CREATE TABLE AS SELECT | ~16-18 rows snapshot |
| `npc_spells_entries_backup_raid_scaling_luclin_a` | CREATE TABLE AS SELECT | 1 row snapshot |
| `npc_types` | UPDATE | 37 rows (per Decision #50 default include + Decision #51 default exclude) |
| `spawn2` | UPDATE | ~17-18 rows |
| `npc_spells_entries` | DELETE | 1 row (Touch of Vinitras spell 2859 from list 196) |

Data-expert produces a single SQL reference at `data-expert/context/phase5a-luclin-a-implementation.sql` with:
1. Backup table creates first (3 backups).
2. All `npc_types` UPDATEs ordered by zone cluster (ssratemple → akheva → sseru/katta → griegsend → acrylia → thedeep → umbral).
3. `spawn2.respawntime` UPDATEs.
4. Touch of Vinitras DELETE.
5. Post-change verification queries.
6. Full rollback script using backup tables (INSERT…SELECT for npc_types & spawn2; INSERT for the deleted spell entry; transactional).

---

## Vyzh`dra Chain Isolation Proof (§2 of Architecture)

**Per protocol-agent Flag C, the Vyzh`dra encounter is a multi-form chain managed by `#cursed_controller.pl`. This section confirms Phase 5a HP scaling and Touch of Vinitras DT removal cannot accidentally break the chain.**

### 2.1 NPC roles

| NPC ID | Role | HP | Spell list | DT? |
|---|---|---|---|---|
| 162206 | Vyzh`dra the Cursed (final form) | 900k | 197 | No |
| 162232 | Vyzh`dra the Exiled (intermediate form) | 450k | 196 | **YES — spell 2859** |
| 162214 | Vyzh`dra the Banished (intermediate form) | 403k | 196 | **YES — spell 2859** |
| 162261 | a_glyph_covered_serpent (chain stepping-stone) | 300k | 190 | No |
| 162253 | a_rune_covered_serpent (chain stepping-stone) | 221k | 190 | No |

### 2.2 Chain orchestration

Per protocol-agent's grep of `#cursed_controller.pl`, chain control uses entity-list checks and qglobals — NOT HP thresholds. HP scaling is HP-independent at the trigger level. Standard pattern matches Kerafyrm chain (Phase 4b).

### 2.3 What Phase 5a touches vs preserves

| Artifact | Phase 5a touches? | Rationale |
|---|---|---|
| `npc_types.hp` for 162206/214/232 (Vyzh`dra trio) | **YES** | Bring all three down to 65-90k for tractability |
| `npc_types.hp` for 162253/261 (chain serpents) | **YES per Decision #50 default include** | Architect recommends; lore-master sign-off pending |
| `npc_spells_entries` for spell list 196 (Touch of Vinitras DT) | **DELETE 1 row** | Decision #16 / Decision #13 precedent |
| `npc_spells_entries` for spell list 197 (Vyzh`dra Cursed) | **NO** | Clean — no DT in list 197 |
| `#cursed_controller.pl` script | **NO** | Chain orchestration preserved verbatim |
| `#Vyzh-dra_the_Cursed.lua` / `#Vyzh-dra_the_Exiled.lua` / `#Vyzh-dra_the_Banished.pl` | **NO** | Per-form scripts preserved |

### 2.4 Scenarios evaluated

**Scenario A:** Phase 5a applied; small group engages Vyzh`dra Banished (62k HP post-scale, list 196 minus DT). Group DPSes through; Banished depops or signals next form via controller; Exiled spawns at 70k HP; group continues; Cursed final form at 90k HP. Group completes encounter. ✅ Chain orchestration preserved.

**Scenario B:** Touch of Vinitras DT was the small-group blocker for Banished + Exiled (instant-kill at -20k against 6-person comp). Removing it makes the intermediate forms tractable. ✅ Decision #16 / #13 precedent honored.

**Scenario C:** What if the rune/glyph serpents (162253/261) need to spawn for the chain to progress, and Phase 5a HP scaling causes them to die before the controller is ready? `#cursed_controller.pl` orchestration logic is unchanged — controller logic doesn't depend on HP threshold timings. ✅ Behavior preserved.

**Architect concern flagged for lore-master Decision #50:** If lore-master indicates the rune/glyph serpents should NOT be scaled (they should remain at 221k/300k as deliberate gate guards), Phase 5a removes them from the npc_types UPDATE list. Default INCLUDE (architect recommendation per protocol-agent Flag C — they're chain stepping-stones).

---

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| L1 | Build 3 backup tables (`npc_types_backup_raid_scaling_luclin_a` 37 rows; `spawn2_backup_raid_scaling_luclin_a` ~16-18 rows; `npc_spells_entries_backup_raid_scaling_luclin_a` 1 row); verify counts | data-expert | — | ~30m |
| L2 | Emit per-boss HP/damage UPDATE SQL for ssratemple cluster (13 + 2 flagged serpents per Decision #50 default; preserve Emperor cycle/Leash/spell list 227) | data-expert | L1 | ~50m |
| L3 | Emit per-boss HP/damage UPDATE SQL for akheva cluster (3 Vyzh`dra + Itraer Vius + Shei real + Shei merchant + Insanity Crawler + Va`Dyn + Shar Vinitras = 8) | data-expert | L1 | ~30m |
| L4 | Emit Touch of Vinitras DELETE: `DELETE FROM npc_spells_entries WHERE npc_spells_id = 196 AND spellid = 2859;` (1 row) | data-expert | L1 | ~5m |
| L5 | Emit per-boss HP/damage UPDATE SQL for sseru/katta cluster (Lord Seru MR=800 preserved, 4 Praesertum, Lcea Katta, Nathyn Illuminious) | data-expert | L1 | ~25m |
| L6 | Emit per-boss HP/damage UPDATE SQL for griegsend (3) + acrylia (2) + thedeep (1) + umbral (3) = 9 NPCs | data-expert | L1 | ~30m |
| L7 | Emit `spawn2.respawntime` UPDATE SQL (86,400s for ~17-18 rows; EXCLUDE Shar Vinitras 10800s short-tier; EXCLUDE pre-Emperor 1080s farming-tier; EXCLUDE Rhozth pair already mid-tier; EXCLUDE script-spawned which have no spawn2) | data-expert | L1 | ~20m |
| L8 | Emit rollback script: 3-stage transactional INSERT…SELECT from backup tables (npc_types restore, spawn2 restore, npc_spells_entries re-insert spell 2859 row) + verification queries comparing row counts before/after; mirror Phase 4b `06-velious-b-rollback.sql` pattern | data-expert | L2, L3, L4, L5, L6, L7 | ~30m |
| L9 | Apply all SQL changes via `docker exec akk-stack-mariadb-1 mysql -ueqemu -p'…' peq < phase5a-luclin-a-implementation.sql`; capture before/after row counts and diff stats | data-expert | L8 | ~15m |
| L10 | `#reloadworld` via Spire or world telnet port 9000 — propagates `npc_types` HP changes + `spawn2.respawntime` changes. **Caveat:** the `npc_spells_entries` DELETE may need a full zone-process restart to flush the spell list cache (config-expert Phase 2 precedent — Cazic Touch DELETE worked with `#reloadworld` only, but architect flags as risk and asks game-tester to confirm). | config-expert | L9 | ~5m (or ~5m + zone restart contingency) |
| L11 | Smoke verification: HP targets for Emperor / Lord Seru / Vyzh`dra Cursed / Khati Sha / Thought Horror / Doomshade / Grieg / Servitor; respawn 24h targets for ~17-18 rows; **Touch of Vinitras DELETE confirmed (spell 2859 NOT in list 196 anymore)**; Lord Seru MR=800 preserved; Emperor placeholder 162065 untouched; Spirit of Akelha`Ra (179144) untouched; vexthal NPCs (158081 Va_Dyn_Khar, 158087-94 Akhevan Warders) untouched; OOE NPCs (163051/52, 154161, 176111) untouched; event-control NPCs (162269, 176110, 160177/178) untouched | config-expert | L10 | ~40m |
| L12 | Commit + push all changed files in `claude/` repo (architecture doc, context files, status updates, implementation SQL) to `feature/raid-scaling` branch. `akk-stack/` and `eqemu/` untouched. | data-expert | L9 | ~10m |

**Critical ordering constraint:** L1 gates L2-L7. L8 depends on all of L2-L7. L9 depends on L8. L10 depends on L9. L11 depends on L10. L12 is git-commit only, can run in parallel with L11.

**Tasks NOT required:**
- **lua-expert / perl-expert** — NO script changes by default. (If user invokes Decision #52 alternative — soften Emperor's `$EmpRepopTime` from 3-5d to 24h — perl-expert would do a one-line edit at `#EmpCycle.pl:3`. Conditional task L13 below.)
- **c-expert** — no C++ changes.
- **infra-expert** — no full-stack restart expected by default. If `#reloadworld` doesn't propagate the `npc_spells_entries` DELETE for spell list 196 in live Akheva zone, L10b (zone-process restart for akheva) is contingent.

**Conditional task (only if user picks Decision #52 alternative):**
- L13 (CONDITIONAL) — **perl-expert** edits `akk-stack/server/quests/ssratemple/#EmpCycle.pl:3` to change `$EmpRepopTime = int(rand(2880)) + 4320;` (3-5 days) to `$EmpRepopTime = int(rand(7200)) + 79200;` (22-24 hours). Triggers Emperor cycle to align with Decision #8 endgame respawn tier. Default: NOT invoked (preserve native per Decision #11).

**Required implementation agents:**

| Agent | Role | Tasks |
|-------|------|-------|
| data-expert | primary | L1, L2, L3, L4, L5, L6, L7, L8, L9, L12 |
| config-expert | reload + smoke | L10, L11 |
| (perl-expert) | CONDITIONAL — Decision #52 alternative only | L13 |

Same default team composition as Phases 2/3/4b. (Phase 4a invoked lua-expert conditionally; Phase 5a invokes perl-expert conditionally with same posture.)

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `#reloadworld` doesn't propagate `npc_types` HP changes in live zones | Very Low | Low | Same pattern as Phase 2/3/4a/4b. If failure, config-expert triggers infra-expert full-stack restart. |
| `#reloadworld` doesn't flush `npc_spells_entries` cache for spell list 196 in live akheva zone | Low | Medium | Phase 2 Cazic Touch DELETE worked with `#reloadworld` per Decision #16. Architect flags this as risk; if smoke test shows Vyzh`dra Exiled/Banished still casting Touch of Vinitras, akheva zone process restart is needed. Rare — same DELETE-then-reload pattern. |
| Emperor cycle (`#EmpCycle.pl`) breaks due to Blood/Blood Golem HP cuts | Nil | Medium | Cycle uses `qglobals.Emperor` state machine and `entity_list:GetNPCByNPCTypeID()` presence checks. NOT HP-thresholded. Verified by protocol-agent Q4. |
| Vyzh`dra chain (`#cursed_controller.pl`) breaks due to multi-form HP cuts or Touch of Vinitras removal | Nil | Medium | Per protocol-agent Q2/Q4 + architect §2 isolation proof: chain uses entity-list checks; DT removal makes intermediate forms tractable rather than instant-kill. |
| Shei Vinitras dual-form spawn-swap (179157 → 179032) breaks due to merchant-form HP cut | Nil | Low | Per protocol-agent Flag B: spawn-swap is event-driven via `event_death_complete` on 179157 → spawn 179032. HP cut on either form is invisible to the trigger. |
| Lord Inquisitor Seru MR=800 stops all caster companion DPS | **Expected** | **Intended** | Decision #11 preserves signature. Small-group melee/hybrid comps succeed. Document for user (same as Vyemm in Phase 4b). |
| Khati Sha L68 still hard for L65-cap small group | Medium | Low | Audit's 90k HP target accounts for L68; 1+5 companion comp at 65 averages 600-800 DPS — completable in ~2 min. Damage cap 750 (was 1004) prevents one-shot risk. |
| Emperor 30-min engagement timer stresses small-group setup time | Medium | Medium | Decision #11 preserves. 30 min from Blood phase to Emperor engagement is feasible for prepared 1+5 group. Document in test plan. |
| Emperor 40-min combat timer (post-engagement) ends fight prematurely if small group DPS is low | Medium | Medium | At 120k HP target (post-scale), 1+5 group at 1500-2500 DPS clears in 50-80 sec. 40 min is generous. Risk near zero. Flag for user awareness. |
| Emperor's 5×shissar_wraith post-mortem trash overwhelms exhausted small group | Low | Low | Wraiths at L59 50 HP each (per DB). Small group should tolerate. Document. |
| Touch of Vinitras DELETE accidentally affects an unrelated NPC | Nil | Low | DELETE scoped to `npc_spells_id = 196 AND spellid = 2859` — exactly 1 row. Backup table captures pre-DELETE state. |
| Pre-Emperor 17×spawn2 farming load increases too much (Decision #50 includes serpents = +2 NPCs at full respawn) | Nil | Nil | Pre-Emperor respawn UNCHANGED at 1080s — preserves Ring of the Shissar Insignia farming cadence. Serpents respawn unchanged (script-spawned). |
| Rhozth pair (mid-tier 5400s/21600s) preserves Taskmaster's Pouch farming, but HP cut to 38-40k makes them trivial | Low | Low | Lore-master `luclin-chains.md` Section 2 says basement Taskmasters are "uncommon drop" — RNG-paced farming is the gate, not HP. Cut acceptable. |
| Doomshade audit-missed surprise — quest dependency? | Low | Low | Lore-master consult question 10 covers Doomshade. Architect default 70k HP. If lore-master flags Cleric/Paladin epic Luclin step (per `luclin-chains.md` she's Umbral raid-tier), HP can be adjusted. Decision #14 preserves epic scripts. |
| Grieg Veneficus variant 163231 (162.5k HP, 156h respawn) interaction with main 163075 | Low | Low | Two distinct npc_type IDs — likely different encounter versions. Architect leaves variant HP at 162.5k unchanged (already scaled-tier), only respawn UPDATE to 24h. Lore-master question 3 covers. |
| Khati Sha at L68 with native L65 player cap creates con/XP issue | Nil | Nil | Server still treats raid kills normally; the level disparity is on her side, not the player's. No special handling needed. |
| Out-of-era NPCs (163051/52, 154161, 176111) appear when expected to be filtered | Nil | Nil | Config-expert verifies expansion filtering at runtime (`min_expansion`/`max_expansion`). If they leak, separate bug; not Phase 5a's problem to solve. |
| Backup tables disk space | Near zero | Nil | ~150KB combined. Accept. |

### Compatibility Risks

- **Prior-pass rule values remain authoritative.** None changed.
- **Epic 1.0 quest scripts untouched.** `luclin-chains.md` Section 6 confirms Luclin has ZERO Epic 1.0 dependencies. All 14 class epics complete in Classic+Kunark. Decision #14 preserved.
- **Ring of the Shissar quest chain unchanged in structure.** HP cuts on Advisor/Arbiter/General + Rhozth pair preserve drop chain (Insignia + Taskmaster's Pouch sources). Decision #3 preserves loot tables.
- **VT Key Phase 3 (Planes Rift from Emperor)** — Phase 5a Emperor scaling enables this drop for small group. No script gate per `luclin-chains.md` Section 1 + lore-master question 6 (response pending; default architect read: standard loot drop, not scripted).
- **VT Key Phase 4 (Glowing Orb of Luclinite from any Luclin raid boss)** — Phase 5a Khati Sha/Grieg/Doomshade scaling enables small-group Glowing Orb access. Per `luclin-chains.md` Section 1.
- **Akheva Sacrificed Remains chain (VT key Phase 2)** — chain uses non-raid Sacrificed Remains mobs + The Spirit of Akelha`Ra (179144, untouched per Decision #30 precedent). Phase 5a does not interfere.
- **Sanctus Seru / Katta faction-war structure** — Phase 5a HP scaling does not touch faction state. Pro-Seru faction still hostile to Lcea Katta encounter; pro-Katta hostile to Seru. Lore-master question 4 (response pending).
- **Cross-era Vulak`Aerr → Key to Luclin gate** — Phase 4b scaled Vulak`Aerr to 150k HP. Small group can now reach Phase 5a. Cross-era unblock complete.
- **Companion AI unchanged.** Same scaling patterns as Phases 2/3/4a/4b.
- **LLM NPC conversation sidecar unchanged.** Reads name/level/faction only.

### Performance Risks

- **Zero.** ~37 UPDATEs + ~17 UPDATEs + 1 DELETE. Trivial workload.
- **No new indexes needed.**
- **No opcode-layer impact** — confirmed by protocol-agent Q1-Q10.
- **No zone boot overhead** — `#reloadworld` refreshes `npc_types` cache in minutes. `npc_spells_entries` DELETE may trigger one akheva zone restart (5 min).

---

## Review Passes

### Pass 1: Feasibility

Every lever used is established Phase 2/3/4a/4b practice:
- `npc_types.hp/mindmg/maxdmg` UPDATEs — 51 Phase 4b + 35 Phase 4a + 21 Phase 3 + 58 Phase 2 = 165 rows previously touched. Phase 5a adds 37.
- `spawn2.respawntime` UPDATEs — 32 Phase 4b + 15 Phase 4a + 14 Phase 3 + 40+ Phase 2 = ~101 rows. Phase 5a adds ~17-18.
- `npc_spells_entries` DELETE — Phase 2 Decision #16 (Cazic Touch) precedent. Phase 5a adds 1 row.
- Backup tables — established pattern.

**Hardest part:** Vyzh`dra chain orchestration. Verified by protocol-agent's `#cursed_controller.pl` grep and architect §2 isolation proof. HP scaling and Touch of Vinitras DT removal preserve chain trigger logic.

**Edge case:** Emperor 30-min engagement + 40-min combat timers at 120k HP post-scale. At 1+5 companion DPS of 1500-2500/sec, fight clears in 50-80 seconds gross — well within 40-min window. Engagement (30-min from Blood phase to Emperor engagement) requires player to know the cycle — instructional rather than mechanical risk.

**Advisor confirmations:**
- **protocol-agent (2026-04-22):** Full Q1-Q10 + 3 architect flags answered. Phase 5a 100% server-side. Zero protocol changes. Khati Sha confirmed acrylia. Yaemiu confirmed vexthal-only. DT sweep clean (zero Phase 2-style hits; the Touch of Vinitras was found independently by architect's separate sweep — protocol-agent flagged it as `npc_spells_entries` boundary). Event-control NPC exclusion list compiled. MobHealth percentage-only at 1.25M HP confirmed.
- **config-expert (2026-04-22):** Pattern carryover confirmed. rule_values count 1,112. Zone ruleset=1 across all Phase 5a zones. Zero DZ. Zero Cazic Touch (spell 982) DT hits across Luclin lists — confirms Phase 2 spell is not redeployed. Standard `spawn2` event-only pattern for the 9 script-spawned bosses. `#reloadworld` mechanism unchanged.
- **lore-master (consultation in flight 2026-04-23):** 17-question prompt + 6-question follow-up sent. Sign-off pending. `luclin-chains.md` serves as primary reference and has no contradictions with architect's scope.

**Confirmed feasibility:** all 12 tasks (L1-L12) executable by data-expert + config-expert in one session. Same team composition as Phases 2, 3, 4b.

### Pass 2: Simplicity

**Challenge: Can we do less?**

- **Could we skip the rune/glyph serpents (162253/261)?** Decision #50 — architect default INCLUDE per protocol-agent Flag C. Lore-master can override. Skipping = 2 fewer UPDATEs.
- **Could we skip Sheleric Vis + Xaui Tatrua + variants (Akheva elite-named)?** Decision #51 — architect default EXCLUDE per Decision #2 (elite-named tier). Including would be 3-4 more UPDATEs. Architect recommends skip (consistent with Phase 4b's Defenders default exclude before user override).
- **Could we skip the pre-Emperor named (Kizuhx/Korazhk/Zekuzh)?** They're L53/55 with 17 spawn2 rows each at 1080s short-tier respawn. They're the Ring of the Shissar Insignia drop. Audit calls for HP cuts to 50-60k. Including makes them tractable for solo/duo runs. Skip → small group cannot complete Ring of the Shissar. Include.
- **Could we skip Shei Vinitras MERCHANT form (179157)?** Per protocol-agent Flag B — if we don't scale the merchant form, the trigger-kill itself becomes a raid-tier wall. Include with deeper cut so it's not a pre-fight blocker.
- **Could we skip the Touch of Vinitras DELETE?** No. -20,000 HP instant-cast death-touch on Vyzh`dra Banished + Exiled is a small-group blocker (insta-kills tank or any companion). Phase 13 PoSky precedent + Decision #16 Cazic Touch precedent both apply.
- **Could we defer Vyzh`dra trio to Phase 5b?** No — they're akheva-zoned, Phase 5a scope per phasing decision.
- **Could we skip damage cuts on Emperor / Lord Seru / Khati Sha / Shar Vinitras / Lcea Katta / Rumblecrush?** Audit damage outliers (904/915/1004/1010/827/720) are one-shot risks for L65 companions. Include.
- **Could we skip respawn updates on the script-spawned bosses?** They have NO spawn2. Nothing to update. Their cycle timers live in scripts and per Decision #11 are preserved. Decision #52 alternative (perl-expert edits `#EmpCycle.pl`) is opt-in only.
- **Could we skip backup tables?** No — Phase 2/3/4a/4b precedent. BUG-001 Phase 4a rollback relied on them.

**Removed / deferred:**
- ~~Khati Sha grimling-zone investigation~~ — resolved via script path: acrylia. No deferred work.
- ~~Yaemiu boundary~~ — resolved: vexthal-exclusive, Phase 5b.
- ~~Va_Dyn_Khar 158081 inclusion~~ — resolved: vexthal, Phase 5b.
- ~~Akhevan Warders 158087-94 inclusion~~ — resolved: vexthal (despite "Akhevan" name, they're VT entry guardians), Phase 5b.
- ~~Spirit of Akelha`Ra 179144 inclusion~~ — Decision #30 precedent: VT-key turn-in NPC, leave untouched.
- ~~Emperor placeholder 162065 inclusion~~ — protocol-agent flagged: not a fight target.

### Pass 3: Antagonistic — what could go wrong

1. **Lord Inquisitor Seru MR=800 stops caster companion DPS.** Intended per Decision #11. Same pattern as Vyemm (Phase 4b). Document for user.

2. **Vyzh`dra chain Banished form spawns AFTER Touch of Vinitras DELETE — no DT.** Group can engage. ✅ Safe.

3. **Emperor cycle 30/40-min timers + 3-5 day post-kill respawn.** Per Decision #11 + Decision #45 (Thylex) precedent — preserve. Respawn cooldown is the friction; user Decision #52 covers.

4. **Khati Sha L68 — boss is L68, scaled-named-tier player target is L66.** 90k HP target compensates for the 2-level gap. 1+5 group at L65 cap clears in ~2 min. Acceptable.

5. **Doomshade audit-missed.** Architect added 70k HP target. If lore-master flags as Cleric/Paladin epic Luclin step (unlikely per `luclin-chains.md`), reassess. Default safe.

6. **Touch of Vinitras DELETE may inadvertently flush other Akheva spell list cache.** DELETE is scoped to `(npc_spells_id = 196 AND spellid = 2859)` — exactly 1 row. List 197 (Cursed) and other lists untouched. ✅ Safe.

7. **Shei Vinitras spawn-swap on death of merchant form.** Merchant 179157 at 60k HP post-scale → killable by small group → triggers spawn of REAL 179032 at 85k HP → group continues. Both forms scaled per protocol-agent Flag B. ✅ Safe.

8. **Grieg Veneficus dual-guardian gate + 163097 trigger event.** Per protocol-agent: 163045 + 163046 + 163097 must be present/dead to spawn Grieg. HP scaling on 163075 (main, script-spawned) doesn't affect the gate logic. ✅ Safe.

9. **Pre-Emperor 17 spawn2 rows × 3 NPCs = 51 short-tier static spawns.** Phase 5a HP cut to 45-60k each. With 1080s (18m) respawn, this is the main farmable cluster of Ssraeshza Temple. Insignia drop pacing preserved. ✅ Intended.

10. **Akheva quest-drop dependency for Shar Vinitras (3h respawn) preserved.** Audit explicitly says respawn fine; Phase 5a leaves at 10800s. ✅ Safe.

11. **Cross-era unblock: Vulak`Aerr (Phase 4b 150k) → Key to Luclin → Phase 5a Luclin progression.** Phase 5a closes the small-group Luclin chain before Phase 5b Vex Thal. ✅ Phase 4b precedent.

12. **What if user does not pick Decision #50 (rune/glyph serpents)?** Architecture supports both options. Default INCLUDE. Skipping reduces UPDATE count by 2 and removes 2 backup rows. Clean.

13. **What if user picks Decision #52 alternative (Emperor cycle softer respawn)?** perl-expert task L13 invoked. One-line edit at `#EmpCycle.pl:3`. Backup the script before edit (commit on feature branch). Risk: small.

14. **Emperor's special_abilities `32,1,290` (Leash 290).** Untouched per Decision #11. Confirmed by protocol-agent Q4 (Leash is movement constraint, not damage/HP). ✅ Safe.

15. **Spell 2310 "Rage of Ssraeshza" in list 227.** Self-haste + target debuff. mana=0, cast=0, recast=60s. NOT a DT. NOT a summon. Confirmed by protocol-agent Q4. Preserved. ✅ Safe.

### Pass 4: Integration

**Task ordering:**
```
L1 (3 backups) ──┬──> L2 (ssratemple SQL)
                 ├──> L3 (akheva SQL)
                 ├──> L4 (Touch of Vinitras DELETE)
                 ├──> L5 (sseru/katta SQL)
                 ├──> L6 (griegsend/acrylia/thedeep/umbral SQL)
                 └──> L7 (respawn SQL)
                        │
                        └──> L8 (rollback) ──> L9 (apply) ──> L10 (reload) ──> L11 (smoke verify)
                                                                  │
                                                                  └──> L12 (commit)
                                                                  │
                                                                  └──> [L13 conditional: perl-expert Emperor respawn softening]
```

- L1 gates everything.
- L2-L7 can run in parallel after L1 (same agent, sequential writing).
- L8 depends on L2-L7.
- L9-L11 sequential.
- L12 git-commit only, can start after L9.
- L13 (conditional) only invoked if user picks Decision #52 alternative.

**Cross-agent dependencies all resolvable:**
- **game-designer** (PRD + audit): inputs consumed from Phase 1 + Phase 5a updates.
- **lore-master** (Luclin chains): primary reference (`luclin-chains.md`); 17-question consultation in flight; sign-off pending.
- **protocol-agent** (Phase 5a protocol clearance): cleared 2026-04-22 (full Q1-Q10 + 3 flags).
- **config-expert** (rule posture + DB cross-checks): cleared 2026-04-22.
- **game-tester** (Phase 5a validation): will receive 37-boss smoke-verify hooks + Touch of Vinitras DELETE verify.

**Task dependencies all linear within Phase 5a.** Same shape as Phase 4b (B1 → B2-B6 → B7 → B8 → B9 → B10 → B11), with addition of L4 DELETE and conditional L13.

---

## Items flagged to user (decisions required before implementation)

### Decision #50 — Rune/glyph serpent inclusion (architect-recommended INCLUDE; lore-master sign-off pending)

Two ssratemple NPCs not in audit:
- **162253 #a_rune_covered_serpent** (L63, 221k HP, raid_target=1, script-spawned)
- **162261 #a_glyph_covered_serpent** (L63, 300k HP, raid_target=1, script-spawned)

Both are part of `#cursed_controller.pl` chain orchestration per protocol-agent Flag C — they appear to be Vyzh`dra-chain stepping stones.

**Architect recommendation: INCLUDE (Option A).** Scale to 60k / 70k HP respectively (matches Vyzh`dra Exiled/Banished post-scale band). Preserves chain narrative; gives small group 5 forms to defeat in sequence (rune serpent → glyph serpent → Banished → Exiled → Cursed) at progressive difficulty.

**Alternative (Option B):** Exclude per Decision #2 elite-trash interpretation. Skip 2 UPDATEs. Leaves 221k/300k HP barriers in chain — likely impassable for small group.

User decision required. **Lore-master sign-off pending — final recommendation may shift.**

### Decision #51 — Akheva elite-named exclusion (architect-recommended EXCLUDE)

Three Akheva NPCs at elite-named tier:
- **179133 Sheleric Vis** (L61, 116k HP, raid_target=1, 5400s × 2 spawn2 rows)
- **179046 Sheleric Vis** (variant, L62, 70k HP, raid_target=1, 5400s × 2 spawn2 rows)
- **179044 Xaui Tatrua** (L60, 70k HP, raid_target=1, 5400s × 1 spawn2 row)

**Architect recommendation: EXCLUDE (Option A).** Decision #2 precedent — these are at 70-116k HP / 5400s short-tier respawn — elite-named tier, not raid-tier. Same posture as Phase 4b's Defenders pre-override.

**Alternative (Option B, scope-consistency override):** Include (akin to Phase 4b Q37 override). +3-4 UPDATEs. HP target ~30-40k each.

User decision required. (If user follows the Phase 4b Q37 pattern of "include for scope consistency," this should be re-evaluated.)

### Decision #52 — Emperor Ssraeshza cycle respawn timer (architect-recommended KEEP NATIVE)

`#EmpCycle.pl:3` defines `$EmpRepopTime = int(rand(2880)) + 4320;` = 3-5 day post-kill respawn (4320s+ = 72h-120h range). This is a Perl local variable, NOT `spawn2.respawntime` — config-expert and protocol-agent confirmed. SQL cannot tune it; only perl-expert can.

**Architect recommendation: KEEP NATIVE (Option A).** Per Decision #11 (preserve signature mechanics) + Decision #45 (Thylex precedent — script-driven respawn timers preserved as load-bearing for cycle integrity). Emperor is the pinnacle of Phase 5a; 3-5 days between kills enforces "earn the loot pinata" feel per brief.

**Alternative (Option B):** Invoke perl-expert (task L13) to soften to 22-24h endgame tier (`$EmpRepopTime = int(rand(7200)) + 79200;`). Aligns with Decision #8 endgame respawn tier. +1 small Perl edit; +1 commit; +1 smoke test.

User decision required. **Architect strongly recommends Option A** — Emperor at 24h respawn would feel less like a once-per-week event and more like a daily target. The 3-5 day cadence is signature.

---

## Required Implementation Agents

**Default path (Decision #52 = Option A, no perl-expert):**

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| data-expert | L1-L9, L12 | Owns all SQL emission, backup creation, apply, and commit. Primary agent. Same role as Phases 2/3/4a/4b. |
| config-expert | L10, L11 | `#reloadworld` via world telnet port 9000 + post-change smoke verification. Same role as Phases 2/3/4b. |

**Conditional path (Decision #52 = Option B):**

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| data-expert | L1-L9, L12 | as above |
| config-expert | L10, L11 | as above |
| perl-expert | L13 | One-line `#EmpCycle.pl` edit |

**Agents NOT needed in default path:** c-expert, lua-expert, infra-expert (full-stack restart not expected — single zone process restart for akheva is contingent fallback only), protocol-agent (already advised).

---

## Validation Plan

_game-tester should verify each of the following after the implementation team completes Tasks L1-L12:_

### Backup integrity
- [ ] **3 backup tables exist and are populated.**
  ```sql
  SELECT COUNT(*) FROM npc_types_backup_raid_scaling_luclin_a;          -- expect 37 (35-39 per Decisions #50/#51)
  SELECT COUNT(*) FROM spawn2_backup_raid_scaling_luclin_a;              -- expect ~16-18 (excluding pre-Emperor static rows preserved)
  SELECT COUNT(*) FROM npc_spells_entries_backup_raid_scaling_luclin_a;  -- expect 1 (Touch of Vinitras pre-DELETE)
  ```

### Ssraeshza Temple HP targets
- [ ] ```sql
  SELECT id, name, hp, mindmg, maxdmg, MR, special_abilities FROM npc_types
  WHERE id IN (162227,162076,162190,162177,162192,162178,162189,162064,
               162066,162067,162191,162258,162089,162253,162261)
  ORDER BY hp DESC;
  ```
  **Expected:**
  - **Emperor 162227: hp=120000, mindmg=200, maxdmg=620, special_abilities includes `32,1,290`** ← Leash preservation check
  - High Priest 162076: 90000
  - Xerkizh 162190: 80000
  - Arch Lich Rhag\`Zadune 162177: 75000
  - Glyph serpent 162261 (Decision #50): 70000
  - Blood 162189: 60000
  - Blood Golem 162064: 60000
  - Rune serpent 162253 (Decision #50): 60000
  - Rhag\`Mozdezh 162192: 60000
  - General Kizuhx 162066: 60000, 510 maxdmg
  - Rhag\`Zhezum 162178: 55000
  - Arbiter Korazhk 162191: 55000
  - Advisor Zekuzh 162067: 45000
  - Rhozth Ssrakezh 162258: 40000
  - Rhozth Ssravizh 162089: 38000

### Akheva Ruins HP targets + Touch of Vinitras DELETE
- [ ] Vyzh\`dra trio: Cursed 162206 hp=90000, Exiled 162232 hp=70000, Banished 162214 hp=65000.
- [ ] Itraer Vius 179037: 80000.
- [ ] Shei Vinitras REAL 179032: 85000, maxdmg=600.
- [ ] Shei Vinitras MERCHANT 179157: 60000.
- [ ] Insanity Crawler 179180: 60000.
- [ ] Va\`Dyn 179178: 50000.
- [ ] Shar Vinitras 179134: 70000, maxdmg=600.
- [ ] **Touch of Vinitras DT REMOVED:**
  ```sql
  SELECT COUNT(*) FROM npc_spells_entries WHERE npc_spells_id = 196 AND spellid = 2859;  -- expect 0
  SELECT id, name, effect_base_value1 FROM spells_new WHERE id = 2859;                   -- expect (2859, 'Touch of Vinitras', -20000) — spell still exists, just not in list 196
  ```
- [ ] **Vyzh\`dra Cursed list 197 untouched:**
  ```sql
  SELECT spellid FROM npc_spells_entries WHERE npc_spells_id = 197;  -- expect 2814 (Caustic Mist) and 2813 (Mass Insanity), no DT
  ```

### Sanctus Seru / Katta HP targets
- [ ] **Lord Inquisitor Seru 159691: hp=120000, mindmg=220, maxdmg=620, MR=800** ← MR preservation check
- [ ] Praesertum Vantorus 159113: 55000.
- [ ] Praesertum Rhugol 159112: 50000.
- [ ] Praesertum Bikun 159115: 45000.
- [ ] Praesertum Matpa 159114: 45000.
- [ ] Lcea Katta 160375: 80000, maxdmg=620.
- [ ] Nathyn Illuminious 160135: 80000.

### Grieg's End / Acrylia / The Deep / Umbral HP targets
- [ ] Grieg Veneficus 163075 (main, script-spawned): 80000.
- [ ] Grieg Veneficus 163231 (variant, spawn2-backed): UNCHANGED at 162500 (already scaled-tier).
- [ ] Servitor of Luclin 163013: 40000.
- [ ] Praetorian Myral 163078: 35000.
- [ ] Khati Sha the Twisted 154145: 90000, maxdmg=750.
- [ ] evolved burrower 154142: 60000.
- [ ] Thought Horror Overfiend 164078: 90000.
- [ ] Doomshade 176088: 70000.
- [ ] Zelnithak 176089: 60000.
- [ ] Rumblecrush 176002: 45000, maxdmg=600.

### Respawn verification (24h endgame tier)
- [ ] All standing-spawn raid bosses listed in §Data Model spawn2 UPDATE list have `respawntime = 86400`.
- [ ] **Pre-Emperor named (162066/162067/162191) preserved at 1080s** — 17 spawn2 rows each unchanged for Ring of the Shissar Insignia farming.
- [ ] **Rhozth Ssrakezh 162258 preserved at 5400s, Rhozth Ssravizh 162089 preserved at 21600s** — Taskmaster's Pouch farming.
- [ ] **Shar Vinitras 179134 preserved at 10800s** — audit explicitly notes "respawn fine."
- [ ] **Sheleric Vis 179133/179046 + Xaui Tatrua 179044 preserved at 5400s** — Decision #51 elite-named exclude.
- [ ] **Decision #52 Option A: Emperor cycle `#EmpCycle.pl` UNCHANGED** — `$EmpRepopTime` line unchanged at `int(rand(2880)) + 4320`.

### Untouched-NPC verification
- [ ] **Spirit of Akelha\`Ra 179144 UNTOUCHED** at 1M HP (VT-key turn-in NPC, Decision #30 precedent):
  ```sql
  SELECT hp FROM npc_types WHERE id = 179144;  -- expect 1000000
  ```
- [ ] **Vexthal NPCs UNTOUCHED (Phase 5b boundary):**
  ```sql
  SELECT id, hp FROM npc_types WHERE id IN (158081, 158087, 158088, 158089, 158090, 158091, 158092, 158093, 158094);
  -- expect Va_Dyn_Khar 158081 = 600000; Akhevan Warders 158087-94 = 901000 each
  ```
- [ ] **Yaemiu trash UNTOUCHED** (verify by sampling 5 NPCs from Eom_/Pli_/Zun_ name pattern in vexthal — all retain native HP).
- [ ] **Out-of-era NPCs UNTOUCHED:**
  ```sql
  SELECT id, hp FROM npc_types WHERE id IN (163051, 163052, 154161, 176111);
  -- expect 163051=200875, 163052=1007200, 154161=475000 (Fabled), 176111=600000
  ```
- [ ] **Event-control NPCs UNTOUCHED:**
  ```sql
  SELECT id, hp FROM npc_types WHERE id IN (162269, 176110, 160177, 160178, 162065, 162260);
  -- expect 162269=999999999, 176110=99999999, 160177=1000000, 160178=1000000, 162065=6516, 162260=4375
  ```

### Quest-script verification
- [ ] `#EmpCycle.pl`, `#Emperor_Ssraeshza_.pl`, `#Blood_of_Ssraeshza.lua`, `#Ssraeshzian_Blood_Golem.lua` mtimes BEFORE Phase 5a apply timestamp (NOT modified — Decision #52 = Option A).
- [ ] `#cursed_controller.pl`, `#Vyzh-dra_the_Cursed.lua`, `#Vyzh-dra_the_Exiled.lua`, `#Vyzh-dra_the_Banished.pl` mtimes BEFORE.
- [ ] `Khati_Sha_the_Twisted.lua` mtime BEFORE.
- [ ] `#Doomshade.lua` mtime BEFORE.
- [ ] `#Lord_Inquisitor_Seru.pl`, `#Lord_Inquisitor_Seru_.pl` mtimes BEFORE.
- [ ] All Grieg Veneficus scripts (163045/46/47/189/190/etc. trigger scripts) mtimes BEFORE.

### In-game smoke tests (1 player + 5 companions)

- [ ] **Kill Lord Inquisitor Seru in Sanctus Seru:** completable with melee/hybrid comp. **MR=800 blocks caster DPS — expected behavior.** Confirm melee comp succeeds. 24h respawn applies.
- [ ] **Kill Lcea Katta in Katta Castellum:** completable. 80k HP target. 24h respawn.
- [ ] **Kill 4 Praesertum in Sanctus Seru:** all four completable in sequence. 24h respawn.
- [ ] **Kill High Priest of Ssraeshza + Xerkizh the Creator in Ssraeshza Temple:** both completable at 80-90k HP.
- [ ] **Trigger Emperor Ssraeshza cycle:** kill Blood of Ssraeshza (60k HP) → 150s prep → Emperor real spawns (120k HP, 904 max dmg → 620 capped) → kill Emperor within 40-min combat timer → 5×shissar_wraith trash phase → BloodCoolDown 3-4h before retry. Decision #11 mechanic preserved.
- [ ] **Decision #50 verification (default Option A):** rune/glyph serpents engageable + completable. Chain progression works.
- [ ] **Vyzh\`dra chain in Akheva:** Banished form (65k post-scale, no Touch of Vinitras DT) → Exiled (70k, no DT) → Cursed (90k). Chain completes.
- [ ] **Kill Khati Sha the Twisted in Acrylia Caverns:** completable at 90k HP. Damage cap 750.
- [ ] **Kill Doomshade in Umbral Plains:** completable at 70k HP.
- [ ] **Kill Grieg Veneficus chain in Grieg's End:** Servitor of Luclin (40k) → Praetorian Myral (35k) → Grieg Veneficus main (80k). 24h respawn on standing spawns.
- [ ] **Kill Thought Horror Overfiend in The Deep:** completable at 90k HP.
- [ ] **Kill Zelnithak + Rumblecrush in Umbral Plains:** completable at 60k / 45k HP.
- [ ] **Ring of the Shissar quest progresses:** kill pre-Emperor named (Kizuhx 60k / Korazhk 55k / Zekuzh 45k) → Insignia drops → kill Rhozth Ssravizh + Warden Mekuzh → Taskmaster's Pouch components drop → combine in Pouch → Ring of the Shissar received. 1080s respawn preserves farming cadence.
- [ ] **VT key Phase 3 unblocks:** Emperor Ssraeshza death → Planes Rift drops in cache. Standard loot table.
- [ ] **VT key Phase 4 unblocks:** Khati Sha / Grieg / Doomshade / any Phase 5a raid kill drops Glowing Orb of Luclinite. Standard loot table.

### Rollback dry-run
- [ ] **Using backup tables, restore `npc_types` for 3 sample NPCs** (Emperor 162227, Lord Seru 159691, Khati Sha 154145) and verify pre-change values match (1250500, 1201500, 475000).
- [ ] **Touch of Vinitras restore:** `INSERT INTO npc_spells_entries SELECT * FROM npc_spells_entries_backup_raid_scaling_luclin_a;` re-creates the deleted row. Verify spell 2859 now in list 196.
- [ ] **Rollback script syntax-verified** (DRY RUN: BEGIN; UPDATE...; SELECT COUNT; ROLLBACK).

### No regression on unchanged NPCs
- [ ] Spot-check ssratemple non-raid named (Yasiz the Devourer 162124 / Slakiz 162129 / Heriz 162123 etc. — all 34-45k HP elite trash) unchanged.
- [ ] Spot-check akheva non-raid mobs (Sacrificed Remains, A_shadow_reaver, A_rock — all event/flavor NPCs) unchanged.
- [ ] Spot-check sseru non-raid Centurions / Custos / Decurion — all unchanged.
- [ ] Spot-check katta non-raid Theurgus / Praecantor / Vahn — all unchanged.
- [ ] Spot-check umbral non-raid Shak Dathor / netherbian flesheaters — all unchanged.
- [ ] Phase 4b scaled IDs (113457 AoW = 120k, 124155 Vulak = 150k, 124017 Vyemm = 90k, 128090 Hraashna = 60k) unchanged.

---

## Appendix — Flagged items not in Phase 5a scope

- **Phase 5b (Vex Thal proper):** Aten Ha Ra line, Diabo trio, Thall Va tier, Khati Sha of VT (if exists — DB shows only 154145 in acrylia; no VT variant), Va_Dyn_Khar 158081, Akhevan Warders 158087-94, Yaemiu elite trash, 13-shard VT key rework.
- **Spirit of Akelha`Ra 179144** — VT-key turn-in NPC, Decision #30 precedent.
- **General Jared Blaystich (Echo Caverns)** — already elite-named tier, Decision #2.
- **Out-of-era NPCs** — 163051/52 (LoN), 154161 (Fabled), 176111 (post-Luclin) excluded by `min_expansion`/`max_expansion`.
- **Akheva elite-named (Sheleric Vis, Xaui Tatrua)** — Decision #51 default exclude, user can override.
- **Emperor cycle `$EmpRepopTime`** — Decision #52 default keep, user can soften.
- **Grimling War event (Acrylia)** — `luclin-chains.md` Section 3 flag. Wave-event scope similar to Phase 4a Coldain Ring 10. NOT in Phase 5a (architect default; Phase 5b or separate event-scaling phase).

---

> **Next step:** User decisions on Decisions #50 (rune/glyph serpents — architect recommends include), #51 (Akheva elite-named — architect recommends exclude), #52 (Emperor cycle respawn — architect recommends keep native). Lore-master sign-off pending. Then spawn the implementation team with:
> - **data-expert** (Tasks L1-L9, L12)
> - **config-expert** (Tasks L10-L11)
> - **(perl-expert)** — only if Decision #52 = Option B
>
> Do NOT spawn c-expert, lua-expert, infra-expert, or protocol-agent — they have no Phase 5a default-path implementation work.

---

## Addenda

### 2026-04-22 — Protocol-agent Phase 5a consultation (CONFIRMED)

Protocol-agent confirmed **zero Titanium client protocol impact** for Phase 5a. Full transcript logged in `agent-conversations.md` Phase 5a section. Summary:

1. **All Phase 5a zones static, no DZ/instancetype.** zone table has no `instancetype` column on this PEQ version. Standard `ZoneChange_Struct` → `ZoneServerInfo_Struct` entry. `#reloadworld` propagates `npc_types` HP changes normally.
2. **Khati Sha 154145 zone confirmed = acrylia** (script-spawned, no spawn2; quest script in `acrylia/`). No VT variant. Resolves audit's "grimling?" placeholder.
3. **Yaemiu elite trash confirmed vexthal-exclusive.** Phase 5b only.
4. **Emperor add waves all script-spawned, NOT spell-summoned.** Spell list 227 has spell 2310 "Rage of Ssraeshza" (self-haste + target debuff, no summon). special_abilities `32,1,290` = Leash 290 (movement constraint, not damage).
5. **DT sweep clean from protocol-agent's angle** (no spell 982 or other Phase 2-style hits). Architect's separate sweep found Touch of Vinitras (spell 2859) — handled by Phase 5a Decision #16 pattern.
6. **Event-control NPC exclusion list:** 162269 keycheck, 176110 Keymaster, 160177 Bella_Helsin, 160178 Heracus_Helsin, 162065 Emperor placeholder, 162260 #EmpCycle controller.
7. **MobHealth percentage-only confirmed at 1.25M HP (Emperor) and 1.2M HP (Lord Seru).** No overflow. `npc_types.hp` is bigint(20).
8. **Zero Luclin-specific Titanium quirks** affecting scaling. Vertical geometry, faction states, Vah Shir cat models, shissar/snake models — all unaffected.
9. **Three architect flags surfaced and addressed:**
   - **Flag A:** Emperor cycle `$EmpRepopTime` is Perl local variable in `#EmpCycle.pl`, not SQL. Decision #52 covers; perl-expert task L13 is conditional.
   - **Flag B:** Shei Vinitras has TWO npc_type IDs (179032 REAL + 179157 MERCHANT). Both in scope. Architecture's §Existing System Analysis + §Data Model both include.
   - **Flag C:** Vyzh\`dra trio is multi-form chain via `#cursed_controller.pl`. Plus rune/glyph serpents (162253/261) are chain stepping-stones. Architecture's §Vyzh\`dra Chain Isolation Proof addresses; Decision #50 covers serpent inclusion.
10. **Respawn change wire impact: zero.** Server-internal. `spawn2.respawntime` UPDATE invisible to client.

**Verdict: Phase 5a is 100% server-side. Zero opcode additions, zero struct changes, zero Titanium translation layer changes.** Same conclusion as Phases 2, 3, 4a, 4b.

### 2026-04-22 — Config-expert Phase 5a consultation (CONFIRMED)

Config-expert confirmed pattern carryover. Summary:

1. **rule_values count = 1,112** (zero drift from Phase 4b baseline).
2. **All Phase 5a zones have ruleset=1, min_status=0, expansion=3.** No custom rulesets. (griegsend has 2 rows — version 0 ruleset=0, version 1 ruleset=1 — both expansion=3; explained as static zone version revision pair, not DZ.)
3. **No Luclin-specific or zone-specific rules.** "Don't touch rules" posture correct.
4. **Death-touch sweep clean for spell 982 (Cazic Touch).** Phase 2 spell not redeployed in Luclin. (Architect's separate broader sweep found Touch of Vinitras — see §Data Model L4.)
5. **No DZ configuration on this PEQ version.** dynamic_zones table has 0 rows.
6. **Boundary confirmed:** 158xxx VT bosses are vexthal-zoned (Phase 5b). Va_Dyn_Khar 158081 specifically flagged for architect verification — confirmed vexthal, Phase 5b.
7. **`#reloadworld` mechanism unchanged.** World telnet port 9000.

**Verdict: zero rule/config changes for Phase 5a. SQL-only pattern holds.**

### 2026-04-23 — Lore-master Phase 5a consultation (PENDING)

17-question prompt + 6-question follow-up sent. `luclin-chains.md` serves as primary lore reference. Architect's scope and signature mechanic preservation aligns with `luclin-chains.md` Sections 1-9. Sign-off awaited; if lore-master findings shift any of:
- Decision #50 (rune/glyph serpent inclusion) — change Phase 5a UPDATE count
- Doomshade quest dependency — adjust HP target if epic-related
- Emperor 30/40-min timer lore canonicality
- Vyzh\`dra trio scaling boundary
- Akheva Sacrificed Remains chain interaction
the architecture doc will receive an addendum incorporating the corrections. **Default architect recommendations stand pending.**

### 2026-04-25 — Lore-master Phase 5a consultation (CONFIRMED — APPROVED with notes)

Lore-master delivered comprehensive Phase 5a sign-off. Full transcript logged in `agent-conversations.md`. Reference doc filed at `lore-master/luclin-non-vt-additions.md`. Summary by question:

**Q1. Emperor Ssraeshza add-wave mechanic — CONFIRMED canonical.**
The mechanic in `#EmpCycle.pl` and `#Emperor_Ssraeshza_.pl` matches live-era sources:
- Blood/Blood Golem trigger → `qglobals.Emperor` state machine → BloodCoolDown → 30-min engage timer / 40-min combat timer → 5× shissar wraith on death
- **Snake/golem add wave:** 8 aggro-linked snakes (4 mezzable, 4 offtank; 2 non-mezzable cast 75% heal debuff, curse-removable). Snakes respawn every 2-2.5 min if killed — must be maintained throughout. Golem triggers Emperor 3-6 min after death.
- **Emperor: cold-only slow, Ssra bane weapons required for non-casters.**
- **Shissar wraiths drop Planes Rift from their loot tables** (not script-created items) — HP scaling on Emperor does not break Planes Rift availability.
- Preservation: snake respawn + bane weapon requirement are core encounter identity. **Phase 5a does NOT touch these (special_abilities CSV untouched, npc_spells_entries untouched for Emperor list 227, scripts untouched).**

**Q2. Vyzh\`dra zone split — RESOLVED: ALL Vyzh\`dra-related NPCs are in ssratemple.**
Confirmed via Allakhazam zone page + community guides. Zone = ssratemple for all 5 IDs:
- 162253 Glyph-Covered Serpent (cycle Stage 1) — **Phase 5a scope**
- 162232 Vyzh\`dra the Exiled (cycle Stage 2) — Phase 5a scope
- 162206 Vyzh\`dra the Cursed (cycle Stage 3, final boss) — Phase 5a scope
- 162261 Rune-Covered Serpent (recovery chain) — **Phase 5a scope**
- 162214 Vyzh\`dra the Banished (recovery chain, no loot) — Phase 5a scope

**Cycle trigger:** kill 7 Taskmasters + 1 Warden Mekuzh + 2 Rhozths within 1 hour → Glyph Serpent spawns → kill → Exiled spawns → kill → Cursed spawns. If Exiled killed but Cursed not: Rune Serpent + Banished spawn (recovery, no loot).

**Decision #50 RESOLVED — joint architect+lore-master recommendation: Option A INCLUDE.** 162253 + 162261 are raid_target=1 cycle-gate NPCs. Both must be scaled. They are progression blockers if unkillable. Architecture's existing default INCLUDE is endorsed.

**Cycle trigger preservation note:** Phase 5a leaves Taskmasters (50.2k HP elite-trash), Warden Mekuzh (33k HP elite-named), and Rhozth pair (105k/119k HP) — wait, **Phase 5a DOES scale Rhozth Ssrakezh 162258 (119k→40k) and Rhozth Ssravizh 162089 (105k→38k)**. Lore-master Q5 confirms Rhozths are in the 10-mob trigger. Architect verifies: HP cuts on Rhozths do NOT affect cycle trigger logic — trigger fires on KILL count (entity_list death events), not HP thresholds. Cycle trigger preserved.

**Q3. Touch of Vinitras DT deletion — APPROVED.**
No lore objection. Vyzh\`dra the Exiled/Banished identity comes from cycle mechanic (timed 10-mob → serpent → chain), not from DT. Phase 2 Decision #16 / PoSky Decision #13 precedent applies exactly.

**Lore-master also asked for re-audit of Vyzh\`dra Cursed (162206) list 197 for any DT spell.** Architect confirmed: list 197 contains only Mass Insanity (effect 16 = mez) and Caustic Mist (effect 10). **No DT in list 197.** ✅

**HOWEVER — CRITICAL CROSS-CHECK FINDING (architect 2026-04-25):**
Re-running the Touch of Vinitras (spell 2859) usage query revealed **spell 2859 also appears in list 179 (Shei Vinitras REAL boss 179032).** Per lore-master Q15: "Shei Vinitras: DT on initial aggro + every 2 minutes" — this 120s recast matches spell 2859's recast_time = 120000ms exactly. **Touch of Vinitras IS Shei Vinitras's signature mechanic.** Lore-master Q15 explicitly says "DO NOT modify fake-pull script or remove DT from Shei."

**Architect resolution:** Phase 5a `npc_spells_entries` DELETE is **scoped strictly to (npc_spells_id = 196 AND spellid = 2859)** — Vyzh\`dra Exiled/Banished only. The Shei Vinitras list 179 instance is **PRESERVED per Decision #11 + lore-master Q15.** This is correct in the existing Phase 5a SQL plan; no change needed, but the boundary now has a documented lore reason. Smoke test must verify list 179 row for spell 2859 STILL EXISTS post-DELETE.

**Q4. Seru/Katta faction-war scaling — CONFIRMED safe.**
HP scaling does not touch faction states. Faction war preserved. Pro-Seru fights Lcea Katta; pro-Katta fights Lord Inquisitor Seru. On 1-player server, user manages factions between attempts.

**Lord Seru "Inquisition" add mechanic:** No public source confirms a "spawn-additional-inquisitors-on-pull" mechanic. Architect's script grep returned zero `quest::spawn2` / `eq.spawn2` calls in `#Lord_Inquisitor_Seru.pl` / `#Lord_Inquisitor_Seru_.pl` for combat-time adds. **No add-spawn mechanic to preserve beyond what's already in special_abilities.** Standard boss encounter.

**Bella Helsin (160177) + Heracus Helsin (160178):** confirmed event-control NPCs (Katta rebellion-event triggers). Excluded from Phase 5a per architect's existing event-control NPC list.

**Q5. Ring of the Shissar Phase 5a scope — CONFIRMED architect's existing scoping.**
- Commanders Zazuzh/Zherozsh (9k HP each): OUT of Phase 5a — already scaled-named tier. ✅
- Warden Mekuzh (33k HP): OUT of Phase 5a — elite-named tier. ✅
- **Pre-Emperor named (Advisor Zekuzh / Arbiter Korazhk / General Kizuhx):** IN Phase 5a — drop Ssraeshzian Insignia (Ring of the Shissar). HP cuts to 45-60k preserve quest function (Insignia is standard loot-table drop). ✅

**Q6. VT key Planes Rift — CONFIRMED no HP condition.**
Planes Rift drops from Shissar wraith loot tables (event-spawned wraiths from Emperor's `EVENT_DEATH_COMPLETE` per architect's read of `#Emperor_Ssraeshza_.pl`). HP scaling on Emperor is safe for VT key Phase 3 progression.

**Q7. Akheva Sacrificed Remains chain — CONFIRMED architect's existing scope.**
Sacrificed Remains: regular akheva mob, not raid-tier, not Phase 5a scope. Spirit of Akelha\`Ra (179144): turn-in NPC, not kill target — **excluded per Decision #57 (Decision #30 precedent / Jaled Dar's Shade pattern).** No Akheva raid boss is part of VT key Scepter Frame chain.

**Q8. Grieg's End — CONFIRMED architect's existing scope.**
- 5 key-drop named (Amnarra/Deoreo/Hyraja/Khemot/Prast): elite-named tier, NOT Phase 5a. ✅
- Servitor + Grieg: no scripted sequence. Standard kill order (typically Servitor first, easier).
- 163051/163052 OOE confirmed (LoN anniversary).

**Q9. Grimling War event Phase 5a scope — CONFIRMED OUT of Phase 5a.**
Wave-event treatment matches Phase 4a Coldain Ring 10 posture. Out of Phase 5a SQL scope. Spiritist Kama Resan (154052) not scope.

**Architect-flagged Acrylia inner raids (Ring of Fire + Vah Shir Captive):** lore-master has no confirmed PEQ NPC IDs. Architect's own DB query returned no raid_target=1 NPCs in acrylia beyond 154142 (evolved burrower) + 154145 (Khati Sha) + **154153 A_Spiritual_Arcanist (L68, 150k HP, raid_target=1, no spawn2 — script-spawned).** This is a NEW audit-missed find — see Decision #59 below.

**Q10. Doomshade — CONFIRMED Phase 5a.**
ID 176088, L66, 350k HP, umbral, **event-spawned (4 Dark Masters killed → Doomshade spawns).** Per lore-master + architect DB query: Dark Masters (176042 A_Dark_Master) are L60, 32.6k HP, **raid_target=0** — **NOT scope (elite-trash per Decision #2).** Doomshade has no Epic 1.0 dependency. 350k → 70k HP target preserved. Architect's existing Phase 5a scope confirmed.

**Q11. Thought Horror Overfiend signature — Feeblemind + Thought Drain.**
Psychic-predator signature mechanics. Preserved per Decision #11. Phase 5a only touches `npc_types.hp` — list 204 (Thought Horror's spell list) untouched.

**Q12. Khati Sha zone lore — CONFIRMED Acrylia Caverns.**
Vah Shir general Tashakhi, transformed by Shissar. **No Beastlord 1.0 epic dependency** (epic uses different Khati Sha NPCs in Shar Vahl as turn-in NPCs).

**Architect script audit (2026-04-25):** `Khati_Sha_the_Twisted.lua` is a **2-phase scripted event** (Phase 1: combat-engage → 4× Defiled Minion 154054 spawn; Phase 2: player crosses y=-545 → Khati Sha depops/respawns inside chamber + 4× a_diseased_grimling 154129; 2-hour kill timer). **Add NPCs (Defiled Minion 154054 5k HP, diseased grimling 154129 9.5k HP) are elite-trash — NOT in Phase 5a scope per Decision #2.** Khati Sha HP cut (475k → 90k) is **safe** — script doesn't read HP thresholds. **No lua-expert needed for Phase 5a Khati Sha event preservation.**

**Q13. Epic 1.0 dependency on Phase 5a bosses — CONFIRMED ZERO.**
Same finding as Velious. All 14 epics complete in Classic+Kunark. Decision #14 preserved.

**Q14. Respawn tier exceptions — CONFIRMED no exceptions.**
- Emperor (162227): event-gated via BloodCoolDown qglobal in script. No standing spawn2 row to update. **Phase 5a HP-only on Emperor** — architect's existing plan confirmed.
- Vyzh\`dra cycle: event-spawned via 10-mob trigger. No spawn2 respawntime updates appropriate.
- Grieg (163075): no lore reason for extended respawn. 24h endgame per Decision #8.

**Q15. Signature mechanics per boss (PRESERVE ALL per Decision #11) — comprehensive list:**

| Boss | Signature | Phase 5a touches? |
|---|---|---|
| Emperor Ssraeshza | snake respawn + bane weapons + cold-only slow + 95% deaggro/4000DD debuff proc + BloodCoolDown state machine | NO — only HP cut |
| High Priest of Ssraeshza | unslowable + permarooted + Ssraeshza's Command (targeted AE 9s stun + 100DD) + 12 room adds (healing Priests, kill first) + LoS pillar | NO — only HP cut. spell list 202 untouched (Ssraeshza's Command 2048 preserved). |
| Xerkizh the Creator | **Balance of Zebuxoruk** (PBAE 75% heal reduction, unresistable, curse-curable 9 counters) — signature; healers must decurse rapidly. Plus Weakening Spray PBAE debuff. Slowable. | NO — list 203 untouched (Weakening Spray 2045 preserved). Balance of Zebuxoruk may be event-triggered, not in list 203 by ID — verify if game-tester reports issue. |
| Arch Lich Rhag\`Zadune | Cycle stage 3 (script-triggered by Rhag\`Mozdezh death — `#Rhag-Mozdezh.pl`) | NO — script untouched |
| Lord Inquisitor Seru | **MR=800** + bane weapons + cold/disease-only slow + Stunning Strike (20s stun) + Torturing Winds + Enchanter charm advantage | NO — MR preserved. spell list 228 untouched. |
| Lcea Katta | **Dictate charm** — unresistable, affects L58- only (L59+ immune) — DO NOT REMOVE | NO — list 581 untouched. Dictate may be ability-driven, not spell-list — preserved either way. |
| Vyzh\`dra Cursed | Cycle spawn (script — `#cursed_controller.pl`) | NO — script untouched. List 197 clean. |
| Vyzh\`dra Exiled / Banished | Cycle stage forms — Touch of Vinitras (-20k DT) DELETED per Decision #54 | DT removed; cycle script untouched |
| Shar Vinitras | 1010 max dmg + summon + triple attack | YES — damage cap 600 (Phase 5a target). HP cut. |
| **Shei Vinitras (REAL 179032)** | **Touch of Vinitras DT (spell 2859 in list 179)** — on initial aggro + every 2 minutes — INTEGRAL identity. **PRESERVE.** Plus fake-pull trigger (script-spawned by Shei merchant 179157 death) + Thought Vortex (PBAE -350 mana) + Storm Tremor (PBAE stun) + permarooted. | HP cut only. **List 179 NOT touched** — DT preserved. Script untouched. |
| Grieg Veneficus | Summon + quad + mez/charm/normal/dispel immune + flee-disabled (SQMCNDWf) | NO — only HP cut |
| Khati Sha the Twisted | 2-phase scripted event (chamber boundary trigger + add waves) + rampages + fire/cold/magic resist | NO — script untouched. HP cut only. |
| Thought Horror Overfiend | Feeblemind PBAE + Thought Drain + permarooted | NO — list 204 untouched. HP cut only. |
| Doomshade | Hits 550+ + flurries + cannot be slowed + no spell casting + event-spawned by 4 Dark Masters | NO — only HP cut. Dark Masters elite-trash, not scope. |

**Q16. Lord Inquisitor Seru MR=800 — CONFIRMED PRESERVE.**
Lore: Seru commands the Combine Empire's magical forces; magic immunity is narratively appropriate. Identical pattern to Vyemm in Phase 4b. Cold/disease slow only. Non-casters need Seru bane weapons. Decision #11 applies.

**Faction-gate flags (lore-master Q4 + Q16):** No structural-wall faction gates. Two prep-cost grinds for the user:
1. Seru faction grinding for evil-race chars before Sanctus Seru
2. Arx Key chain (4 Praesertum kills + turn-in in Katta Castellum) for easy access to Lord Seru's tower

Neither prevents Phase 5a HP scaling from working. Player-prep requirements only.

**Q17. Lore sign-off — APPROVED with notes.**

Era compliance: All Phase 5a bosses are Luclin (expansion 3). No post-Luclin content. OOE items correctly excluded. Event-control NPCs correctly excluded.

**Scripted encounters investigated and verified safe for SQL-only Phase 5a:**
- Khati Sha: 2-phase scripted event verified — wave mobs are elite-trash (5-9.5k HP), not scope. **No lua-expert needed.**
- Vyzh\`dra cycle: 10-mob trigger logic verified HP-independent. Phase 5a HP cuts on Rhozths (cycle trigger participants) safe — trigger fires on kill count, not HP threshold.
- Rhag cycle: Rhag\`Zhezum death → spawn Rhag\`Mozdezh; Rhag\`Mozdezh death → spawn Rhag\`Zadune (architect read scripts). HP-independent.
- Shei Vinitras dual-form spawn-swap: 179157 merchant death → spawn 179032 real. **DT (Touch of Vinitras) in list 179 is signature — DO NOT remove.**
- Emperor cycle: HP-independent state machine + qglobal-driven BloodCoolDown.

**LORE SIGN-OFF:** Phase 5a scope APPROVED. Decision #50 resolves to Option A (joint architect+lore-master recommendation) — INCLUDE rune/glyph serpents. Architect's plan is dispatch-ready.

### 2026-04-25 — Architect incorporations of lore-master Phase 5a findings

Five adjustments made based on lore-master review:

1. **Decision #50 RESOLVED** — Joint architect+lore-master recommendation: INCLUDE rune/glyph serpents (162253 + 162261). Decision Log entry updated.

2. **Touch of Vinitras DELETE scope CONFIRMED list 196 only** — Cross-check revealed spell 2859 also appears in list 179 (Shei Vinitras REAL). Per lore-master Q15: Shei's Touch of Vinitras IS her signature mechanic — PRESERVE. Phase 5a DELETE statement in Data Model already correctly scoped to `(npc_spells_id = 196 AND spellid = 2859)`. **Validation Plan §"No npc_spells_entries changes" expanded** to verify list 179 row for spell 2859 STILL EXISTS post-DELETE.

3. **A_Spiritual_Arcanist 154153 (L68, 150k HP, raid_target=1, acrylia, script-spawned) audit-missed — Decision #59 added.** Architect default INCLUDE in Phase 5a scope (HP target 45k — between Khati Sha 90k and Defiled Minion 5k). Pending user confirmation.

4. **Khati Sha 2-phase event verified SQL-safe** — script audit confirmed wave mobs are elite-trash (Defiled Minion 5k, diseased grimling 9.5k). Lore-master's "may need lua-expert conditional for wave mob HP" caveat resolved as NOT NEEDED.

5. **Vyzh\`dra cycle trigger verified HP-independent** — 10-mob kill count trigger doesn't read HP thresholds. Phase 5a HP cuts on Rhozth pair (cycle participants) confirmed safe.

