# Raid Scaling — Architecture & Implementation Plan (Phase 4a: Velious non-ToV)

> **Feature branch:** `feature/raid-scaling`
> **PRD:** `game-designer/prd.md`
> **Audit:** `game-designer/raid-scaling-audit.md` (Velious section lines 1510-1940)
> **Lore catalog:** `lore-master/velious-chains.md`
> **Phase 2 reference:** `architect/architecture.md` (Classic)
> **Phase 3 reference:** `architect/kunark-architecture.md` (Kunark — most recent pattern)
> **DB investigation:** `architect/context/velious-a-db-investigation.md`
> **Author:** architect
> **Date:** 2026-04-23
> **Status:** Ready for user approval — all three advisor consultations confirmed (protocol-agent + config-expert 2026-04-22; lore-master 2026-04-23). Q8 resolution adopted from lore-master (Lever 1 SQL + conditional Lever 2 Lua). Awaiting user decisions #23-27 before implementation dispatch.
> **Scope:** **Phase 4a (Velious non-ToV) ONLY.** Kael (minus Avatar of War), Skyshrine, Plane of Growth, Plane of Mischief Jester, Western Wastes/Cobaltscar/Velketor/Siren's Grotto/Iceclad/Wakening/Dragon Necropolis/Great Divide/Icewell Keep outdoor and dungeon raid bosses, Coldain Ring War (Q8), Coldain Prayer Shawl assessment.
> **OUT OF SCOPE** (Phase 4b): Temple of Veeshan proper, Sleeper's Tomb, Avatar of War (113457), Vulak`Aerr (124155). Sleeper-awake event (Decision #12): untouched permanently.

---

## Executive Summary

Phase 4a scales Velious non-ToV raid content using the **same 100% SQL + scoped-Lua pattern** established in Phases 2 and 3, with one small Lua script change for the Coldain Ring War event (Q8).

**Four significant differences from Phase 3:**

1. **Coldain Ring War solved via SQL wave-mob HP cuts (lore-master-endorsed Lever 1).** The Coldain Ring War (`akk-stack/server/quests/greatdivide/encounters/ring_war.lua`) is a 13-wave scripted event that gates Narandi the Wretched (Ring 10 terminus). Lore-master confirmed: **the event has no overall timeout** — only per-wave 5-min cooldowns. Dropping each wave-mob type to named-tier HP lets a small group clear each wave in 2-4 min. Total event duration becomes ~45-90 min (lore-consistent "epic multi-wave defense" experience). **Lever 1 is pure SQL** — 8 Kromrif NPC IDs (118130, 118160, 118150, 118120, 118209, 118158, 118156, 118210), all exclusive to greatdivide conditions 3-15 (confirmed via DB sweep — zero ID-sharing with static zone or other zones). **Lever 2 (lua-expert wave_cooldown_time increase)** is a fallback if game-tester shows Lever 1 alone insufficient. Architect-assigned Q8 per Decision #8.

2. **Duplicate-NPC handling.** Lord Yelinak exists as two distinct npc_types IDs (114106 main 500k HP, 114618 variant 297k HP), both with active spawn2 entries in skyshrine. Per DB sweep both are live (neither is spawn-condition-gated). We scale both to consistent target values (110k HP each).

3. **Faction-gated content stays as-is per Decision #14.** Coldain / Claws of Veeshan / Kromzek three-way faction exclusivity is preserved. Boss HP/damage cuts help small-group combat but do not soften faction grinds. Flag for user.

4. **Event-trigger NPCs left untouched.** Plane of Growth has `a_warm_light` (L1 1M HP passive) and `a_thifling_focuser` (L65 1M HP) — per audit and lore-master these are event-control NPCs, not kill targets. Similarly Jaled Dar's Shade at 3M HP in Dragon Necropolis is a quest-NPC (Sleeper's Tomb key turn-in) intentionally uncombattable. All remain untouched.

**Change footprint (preliminary):**
- **~44 `npc_types` UPDATEs** — 3 Kael named-tier bosses + Idol triggered + 4 Skyshrine Crusaders + 2 Yelinak variants + ~9 Plane of Growth + Jester (pending Decision #27) + 5 outdoor dragons + Velketor pair + Kelorek`Dar + 5 misc outdoor + Dain + Chamberlain + 2 Sirens + Narandi + Taskmaster Abyott + **8 Ring War Kromrif wave mob IDs** + **Seneschal Aldikar HP bump**
- ~14-16 `spawn2.respawntime` UPDATEs (12h for mid-tier bosses; short respawns preserved; Narandi is condition-gated, not respawn-driven)
- **0** `npc_spells_entries` changes (DB sweep: zero death-touch-profile spells on Phase 4a bosses)
- **0 Lua file changes** (Lever 1 = SQL only per lore-master). Lever 2 (`ring_war.lua:26` wave_cooldown_time increase) is a conditional fallback if game-tester validation shows Lever 1 alone insufficient.
- Backup tables: `npc_types_backup_raid_scaling_velious_a`, `spawn2_backup_raid_scaling_velious_a`

**No C++ changes. No rule_values changes. No `eqemu_config.json` changes. No `.env` changes.** Protocol-agent confirmed zero client-visibility impact 2026-04-22. Config-expert confirmed all Phase 2/3 rule patterns carry forward, `rule_values` count=1,112 unchanged, zero zone-scoped rulesets 2026-04-22 (both logged in `agent-conversations.md`).

**User-decision items surfaced** (see "Items flagged to user"):
- Decision #23 — Coldain Ring War (Q8) resolution — **lore-master-endorsed: Lever 1 SQL wave-mob HP cuts** (primary) + conditional Lever 2 Lua timer increase (fallback only)
- Decision #24 — Lord Yelinak duplicate handling — architect recommends scaling both variants
- Decision #25 — Faction grind acceleration (optional flag) — architect recommends out of scope for Phase 4a (separate future initiative)
- Decision #26 — Ring 8/Ring 9 UX softening — architect recommends out of Phase 4a scope
- Decision #27 — Plane of Mischief Jester (126012) inclusion — lore-master recommends exclude unless user specifically wants Mischief Plane content; architect defers to user

---

## Existing System Analysis

### Current State

**Phases 2 and 3 complete as of 2026-04-23.** User has validated Phase 2 Classic (Lady Vox in-game PASS) and Phase 3 Kunark (server-side validation PASS, in-game deferred).

**Prior-pass globals remain authoritative and unchanged:**
- `NPCFlurryChance=12`, `MaxRampageTargets=2`, `NPCAssistCap=3`, `StartEnrageValue=5`, `GlobalLootMultiplier=2`
- `rule_values` count: 1,112 (confirmed unchanged by config-expert 2026-04-22).
- `zone.ruleset=1` (default) applies to all Velious zones (confirmed by config-expert 2026-04-22).

**Velious raid content at PEQ defaults** per game-designer audit and DB confirmation:

**Kael Drakkel (in-scope, minus AoW):**
- King Tormax at 452k HP, 72h respawn
- Statue of Rallos Zek at 400,750 HP, 54h respawn
- Idol of Rallos Zek (triggered) at 650k HP — spawns on Statue death
- Derakor the Vindicator at 180k HP, 12h respawn (already in target tier)

**Skyshrine:**
- Lord Yelinak (2 IDs, both live): 500k and 297k HP, 72h respawn each
- 4 Crusaders (Charayan/Susarrak/Grendish/Jortreva) at 233k HP each, 10.7 min respawn

**Plane of Growth:**
- #_Tunare (final boss) at 530k HP, 72h respawn
- Guardian of Tunare x2 duplicates at 310k HP, 18h respawn
- Ail the Elder, Rumbleroot, Treah Greenroot at 150-215k HP, 18h
- Guardian of Takish at 200k HP, 24h
- Fayl Everstrong at 150k HP, 18h
- Prince Thirneg at 69,719 HP, 18h (near named-tier already)
- Event-trigger NPCs: a_warm_light (8 spawn2, L1 1M HP), a_thifling_focuser (2+2 spawn2, L65 1M HP) — untouched

**Outdoor Velious dragons (Western Wastes / Cobaltscar / Dragon Necropolis):**
- Sontalak, Klandicar at 97.5k HP each, 72h respawn (both Sleeper's Tomb key path)
- Zlandicar at 110k HP, 72h respawn (also ST key path)
- Kelorek`Dar at 100k HP, 54h respawn
- Harla Dar, Mraaka at 60-65k HP (near named-tier, already short respawn)
- Melalafen at 70k HP, 54h respawn

**Siren's Grotto:**
- Faleniel of Darkwater at 300k HP, 2h respawn (damage one-shot risk — 1,900 max)
- Wygrish at 200k HP, 2h respawn (damage one-shot risk — 1,575 max)

**Velketor's Labyrinth:**
- Velketor the Sorcerer at 201,500 HP, 72h respawn
- Lord Doljonijiarnimorinar at 147k HP, 18h respawn

**Misc outdoor:**
- Wuoshi (wakening) at 46k HP, 54h respawn (near named-tier)
- Lodizal (iceclad) at 40,561 HP, 9h respawn (near named-tier, Velious Shawl giver)
- Narandi the Wretched at 150k HP, 208h respawn (but actually script-spawned via Ring War condition 16; the 208h respawn is effectively irrelevant)
- Taskmaster Abyott (greatdivide) at 72k HP, 18h respawn
- Dain Frostreaver IV (thurgadinb) at 352k HP, 120h respawn
- Chamberlain Krystorf (thurgadinb) at 80k HP, 18h respawn

**Plane of Mischief in-era Jester:**
- #the_Mischievous_Jester at 200k HP, 78h respawn (`_condition=2` gated; live)
- Bristlebane (L75) and All-Seeing Eye (L75) out-of-era — SKIP

**Coldain Ring War:**
- Wave mob NPCs at 7k-50k HP each (Kromrif Recruits, Captains, Warriors, Priests, Generals, Veterans, Warlords, High Priests)
- Narandi at 150k HP terminus
- Script drives 13 waves via 14 spawn_conditions (greatdivide RingWarWave1-15, with final = Narandi)
- `wave_cooldown_time = 5 * 60 * 1000` (5 min between waves)
- ~190 total wave giants before Narandi

**Coldain Prayer Shawl:**
- Quest chain (turn-in driven, not a scripted raid event)
- Kills needed are Kromrif giants (named-tier/trash, NOT raid-tier) and rescue mission (Tanik)
- **Out of Phase 4a raid-scaling scope** per DB + script review

### Gap Analysis

| Gap | Lever |
|-----|-------|
| Kael endgame HP gap: King Tormax 15×, Statue 20×, Idol 20×, Derakor 6× scaled-named L70 (~30k) | `npc_types.hp` 67-87% cuts per audit |
| Statue of Rallos Zek one-shot damage risk (max 1,100) | `npc_types.maxdmg` 55% cut to 500 |
| Skyshrine Yelinak x2 at 500k/297k HP (both live — DB sweep confirmed) | HP cut both to 110k consistent target |
| Skyshrine Crusaders 233k HP at L70 (5× scaled-named) | HP cut 78% to 50k; respawn already short (keep) |
| Plane of Growth endgame gap: Tunare 17×, Guardian of Tunare 10×, Ail/Rumbleroot/Treah 6-7× | HP cuts 70-75% per audit; damage trims 20% on 700-dmg bosses |
| Plane of Mischief Jester 200k HP L70 in-era with max 1,431 damage | HP cut 70% to 60k; max damage cut 45% to 780 |
| Outdoor dragons (Klandicar/Sontalak 97.5k at 72h, Zlandicar 110k at 72h) — 3-4× scaled-named, 6× target respawn | HP 59-68% cut, respawn 72h → 12h |
| Western Wastes near-named dragons (Harla Dar 65k, Mraaka 60k, Melalafen 70k) already close to named-tier | Small HP trims (30-40%); respawn already short for Harla/Mraaka |
| Velketor the Sorcerer 201,500 HP at 72h respawn (6× gap) | HP 70% cut, respawn 72h → 12h; signature Sunstrike/Sundering preserved |
| Lord Doljonijiarnimorinar 147k HP 18h — respawn already fits | HP 69% cut, respawn unchanged |
| Siren's Grotto pair 200-300k HP at 2h respawn + one-shot damage (1,900 and 1,575) | HP 70% cut, damage 50% cut — short respawn preserved |
| Narandi 150k HP at 208h — but actually script-spawned (condition-gated) | HP 70% cut to 45k (boss-tier cut); no spawn2 respawn change needed (script drives) |
| Dain Frostreaver IV 352k HP at 120h (Ring 10 terminus, faction-gated) | HP 77% cut to 80k, respawn 120h → 12h |
| Jaled Dar's Shade 3M HP (Dragon Necropolis ST key turn-in NPC) | **NO CHANGE** — intentional uncombattable design per lore-master |
| Event-trigger NPCs (a_warm_light, a_thifling_focuser, #Lantaric`Dar) | **NO CHANGE** — event control, not kill targets |
| Coldain Ring War 13 waves at 5-min cadence + Kromrif wave mobs at 7-50k HP = wave-DPS gate for small group | **SQL wave-mob HP cuts (lore-master Lever 1):** Kromrif Captain (118130 L52 10k→6k), Kromrif Recruit (118160 L48 7k→5k), Kromrif Warrior (118150 L53 11k→7k), Kromrif General (118120 L56 13k→9k), Kromrif Priest (118209 L53 27.5k→12k), Kromrif High Priest (118210 L60 50k→15k), Kromrif Veteran (118156 L58 42.5k→12k), Kromrif Warlord (118158 L60 20k→12k). No overall event timeout; 5-min per-wave cooldown preserved; event duration ~45-90 min post-scaling. |
| Seneschal Aldikar (118166) at 10k HP — fails event if killed by AOE overflow during wave cooldowns | HP bump 10k→30k (belt-and-suspenders per lore-master Flag 2) |

### What is NOT gap for Phase 4a

- **No C++ changes.** Same rationale as Phases 2 and 3.
- **No rule_values changes.** Confirmed by config-expert 2026-04-22 — rule_values count 1,112 unchanged, no new rules needed.
- **No loot table changes.** Per Decision #3.
- **No npc_spells_entries changes.** DB sweep confirmed zero death-touch-profile spells on Phase 4a bosses (see `context/velious-a-db-investigation.md` section 6).
- **No ToV / Sleeper / AoW / Vulak touches.** Explicitly 4b scope.
- **No Sleeper awakening event touches.** Decision #12.
- **No faction system changes.** Decision #14.
- **No script changes beyond Ring War.** Ring 4-9 named encounters are low-HP (<6k) named-tier mobs, not raid targets. Ring 8/Ring 9 UX resets are script behavior out of scope.
- **No wave-count reduction.** Lore-master-endorsed solve is SQL wave-mob HP cuts (Lever 1), not wave-skip. Wave count stays at 13 + Narandi, preserving event identity.

---

## Technical Approach

### Architecture Decision

**Every Phase 4a change is either a database UPDATE or a scoped Lua-script edit.** Per the layer priority (rules > config > Lua > SQL > C++):

1. **Rules — NOT APPLICABLE.** Same rationale as Phases 2/3. Confirmed by config-expert 2026-04-22.
2. **Config (`eqemu_config.json` / `.env`) — NOT APPLICABLE.** No structural changes.
3. **Lua/Perl scripts — CONDITIONAL.** `ring_war.lua` edit is a **fallback-only** Lever 2 if Lever 1 (SQL wave-mob HP cuts) proves insufficient during game-tester validation. Default path: SQL-only. Lever 2 is a one-line change to `wave_cooldown_time` (ring_war.lua:26) from 5-min to 8-min, which lua-expert would execute after explicit user approval. All other boss NPCs have no HP/damage values encoded in scripts.
4. **SQL — YES.** `npc_types` UPDATEs for HP/damage, `spawn2` UPDATEs for respawn. No `npc_spells_entries` changes.
5. **C++ — NOT APPLICABLE.** No engine change needed.

### Component Change Table

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `npc_types.hp` (~35 Velious non-ToV bosses) | UPDATE per-NPC | Audit targets vary 14-87% cut; per-NPC precision required |
| `npc_types.maxdmg` (Statue of Rallos Zek, Faleniel, Wygrish, Jester, PoG bosses with 700 max) | UPDATE per-NPC | One-shot-risk bosses need damage caps |
| `npc_types.mindmg` (limited — PoG bosses and Sirens where proportional) | UPDATE per-NPC | Proportional scale-down paired with maxdmg |
| `spawn2.respawntime` (~20-25 Velious non-ToV raid-boss spawns with active spawn2 rows at >12h) | UPDATE per-spawn | Target 12h = 43,200s per Decision #5 Velious non-ToV mid-tier |
| `ring_war.lua` (`wave_cooldown_time` literal at line 26, 5min→8min) | EDIT (Lua) — **CONDITIONAL Lever 2** | Fallback only if Lever 1 (SQL wave-mob HP cuts) insufficient per game-tester. Default: no change. |
| Kromrif wave mob HP (8 Ring War NPC IDs: 118130, 118160, 118150, 118120, 118209, 118158, 118156, 118210) | UPDATE per-NPC (Lever 1) | Lore-master-endorsed solve for Ring War small-group tractability |
| Seneschal Aldikar HP (118166, 10k→30k) | UPDATE per-NPC | Belt-and-suspenders against AOE overflow failing event |
| `npc_types.special_abilities` | **NO CHANGE** | Decision #11 preserves signature mechanics |
| `npc_spells_entries` | **NO CHANGE** | No death-touch-profile spells in Velious Phase 4a scope |
| Backup tables `npc_types_backup_raid_scaling_velious_a`, `spawn2_backup_raid_scaling_velious_a` | CREATE + INSERT-SELECT | Mirrors Phase 2/3 naming pattern with `_velious_a` suffix |
| Ring War script backup | COPY (text snapshot) | `ring_war.lua.backup_velious_a` — preserves pre-change script for rollback |
| `rule_values` | NO CHANGE | Confirmed by config-expert 2026-04-22 — Phase 2/3 pattern holds |
| `eqemu_config.json` | NO CHANGE | Same as Phases 2/3 |
| C++ source | NO CHANGE | N/A |

### Data Model

#### Backup tables (captured BEFORE any other change)

```sql
CREATE TABLE npc_types_backup_raid_scaling_velious_a AS
SELECT id, hp, mindmg, maxdmg, AC, special_abilities, npcspecialattks
FROM npc_types
WHERE id IN (
    -- Kael (non-AoW): 3 named + 1 triggered Idol
    113215, 113071, 113341, 113118,
    -- Skyshrine: 2 Yelinaks + 4 Crusaders
    114106, 114618, 114242, 114243, 114245, 114246,
    -- Plane of Growth: 1 Tunare + 2 Guardian dups + 6 mid-tier + Prince Thirneg
    127001, 127007, 127106, 127020, 127019, 127021, 127035, 127018, 127096,
    -- Outdoor/misc named: Velketor pair, Kelorek, Sontalak, Klandicar, Zlandicar,
    --   Narandi, Dain, Chamberlain, Sirens pair, Harla Dar, Mraaka, Melalafen,
    --   Wuoshi, Lodizal, Taskmaster Abyott
    112025, 112049, 117073, 120005, 120084, 123115,
    118145, 129003, 129028, 125070, 125072,
    120057, 120064, 120126, 119112, 110099, 118088,
    -- Plane of Mischief in-era Jester (conditional on Decision #27)
    126012,
    -- Ring War wave mobs (lore-master Lever 1 SQL cuts) — exclusive to greatdivide
    --   spawn_conditions 3-15 per DB sweep; zero ID-sharing with static zones
    118130, 118160, 118150, 118120, 118209, 118158, 118156, 118210,
    -- Seneschal Aldikar (HP bump to prevent AOE overflow event fail)
    118166
);
-- Expected rows: 42

CREATE TABLE spawn2_backup_raid_scaling_velious_a AS
SELECT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance,
       s2._condition, s2.cond_value
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID IN (
    113215, 113071, 113118,
    114106, 114618, 114242, 114243, 114245, 114246,
    127001, 127007, 127106, 127020, 127019, 127021, 127035, 127018, 127096,
    112025, 112049, 117073, 120005, 120084, 123115,
    118145, 129003, 129028, 125070, 125072,
    120057, 120064, 120126, 119112, 110099, 118088,
    126012
);
-- Expected rows: ~35-40 (skipping 113341 Idol — no spawn2)
```

**Ring War script snapshot (text backup):**
```bash
cp akk-stack/server/quests/greatdivide/encounters/ring_war.lua \
   akk-stack/server/quests/greatdivide/encounters/ring_war.lua.backup_velious_a
# Or use git's checkout mechanism to restore if needed.
```

#### Phase 4a change sketch (data-expert emits final SQL; values from audit + DB investigation)

**Kael Drakkel:**

```sql
UPDATE npc_types SET hp = 100000                         WHERE id = 113215;  -- King Tormax 452k→100k
UPDATE npc_types SET hp = 50000, maxdmg = 500            WHERE id = 113071;  -- Statue of Rallos Zek 400k→50k, 1100→500
UPDATE npc_types SET hp = 130000, maxdmg = 700           WHERE id = 113341;  -- Idol of Rallos Zek (triggered) 650k→130k, 1100→700
UPDATE npc_types SET hp = 60000, maxdmg = 560            WHERE id = 113118;  -- Derakor the Vindicator 180k→60k, 700→560
```

**Skyshrine:**

```sql
UPDATE npc_types SET hp = 110000                         WHERE id = 114106;  -- Lord Yelinak main 500k→110k
UPDATE npc_types SET hp = 110000                         WHERE id = 114618;  -- Lord Yelinak variant 297k→110k (both live per DB)
UPDATE npc_types SET hp = 50000                          WHERE id = 114242;  -- Charayan 233k→50k
UPDATE npc_types SET hp = 50000                          WHERE id = 114243;  -- Susarrak 233k→50k
UPDATE npc_types SET hp = 50000                          WHERE id = 114245;  -- Grendish 233k→50k
UPDATE npc_types SET hp = 50000                          WHERE id = 114246;  -- Jortreva 233k→50k
```

**Plane of Growth:**

```sql
UPDATE npc_types SET hp = 150000                         WHERE id = 127001;  -- #_Tunare 530k→150k
UPDATE npc_types SET hp = 80000                          WHERE id = 127007;  -- Guardian of Tunare (main) 310k→80k
UPDATE npc_types SET hp = 80000                          WHERE id = 127106;  -- Guardian of Tunare (dup) — consistency
UPDATE npc_types SET hp = 60000, maxdmg = 560            WHERE id = 127020;  -- Ail the Elder 215k→60k, 700→560
UPDATE npc_types SET hp = 55000, maxdmg = 560            WHERE id = 127019;  -- Rumbleroot 193k→55k, 700→560
UPDATE npc_types SET hp = 55000, maxdmg = 560            WHERE id = 127021;  -- Treah Greenroot 191k→55k, 700→560
UPDATE npc_types SET hp = 60000                          WHERE id = 127035;  -- Guardian of Takish 200k→60k
UPDATE npc_types SET hp = 45000, maxdmg = 560            WHERE id = 127018;  -- Fayl Everstrong 150k→45k, 700→560
UPDATE npc_types SET hp = 60000                          WHERE id = 127096;  -- Prince Thirneg 69,719→60,000 (~14% trim)
```

**Plane of Mischief (in-era Jester only):**

```sql
UPDATE npc_types SET hp = 60000, maxdmg = 780            WHERE id = 126012;  -- #Jester 200k→60k, 1,431→780
-- NOTE: Bristlebane (126160) and All-Seeing Eye (126374) OUT-OF-ERA (L75). SKIP.
```

**Outdoor dragons (Sleeper's Tomb key path bosses):**

```sql
UPDATE npc_types SET hp = 40000                          WHERE id = 120005;  -- Sontalak 97.5k→40k
UPDATE npc_types SET hp = 40000                          WHERE id = 120084;  -- Klandicar 97.5k→40k
UPDATE npc_types SET hp = 35000                          WHERE id = 123115;  -- Zlandicar 110k→35k
UPDATE npc_types SET hp = 35000                          WHERE id = 117073;  -- Kelorek`Dar 100k→35k
```

**Western Wastes near-named-tier:**

```sql
UPDATE npc_types SET hp = 28000                          WHERE id = 120057;  -- Harla Dar 65k→28k (per audit)
UPDATE npc_types SET hp = 42000                          WHERE id = 120064;  -- Mraaka 60k→42k (30% trim)
UPDATE npc_types SET hp = 42000                          WHERE id = 120126;  -- Melalafen 70k→42k (40% trim)
```

**Velketor's Labyrinth:**

```sql
UPDATE npc_types SET hp = 60000, maxdmg = 680            WHERE id = 112025;  -- Velketor 201.5k→60k, 850→680 (20% trim; signature Sunstrike/Sundering preserved)
UPDATE npc_types SET hp = 45000                          WHERE id = 112049;  -- Lord Doljonijiarnimorinar 147k→45k
```

**Siren's Grotto (damage cuts critical — one-shot risk):**

```sql
UPDATE npc_types SET hp = 90000, mindmg = 190, maxdmg = 950   WHERE id = 125070;  -- Faleniel 300k→90k, 380-1,900 → 190-950 (50% cut)
UPDATE npc_types SET hp = 60000, mindmg = 294, maxdmg = 780   WHERE id = 125072;  -- Wygrish 200k→60k, 587-1,575 → 294-780 (50% cut)
```

**Misc outdoor:**

```sql
UPDATE npc_types SET hp = 37000                          WHERE id = 119112;  -- Wuoshi 46k→37k (20% trim)
UPDATE npc_types SET hp = 32000                          WHERE id = 110099;  -- Lodizal 40,561→32,000 (20% trim; keep Velious Shawl giver accessible)
UPDATE npc_types SET hp = 30000                          WHERE id = 118088;  -- Taskmaster Abyott 72k→30k
```

**Ring War — Narandi + wave mobs (lore-master Lever 1 SQL cuts):**

```sql
-- Narandi terminus
UPDATE npc_types SET hp = 45000                          WHERE id = 118145;  -- #Narandi the Wretched 150k→45k
-- No spawn2 respawn change for Narandi — script-spawned via condition 16

-- Kromrif wave mobs (8 IDs, all exclusive to greatdivide conditions 3-15 per DB sweep)
UPDATE npc_types SET hp = 6000                           WHERE id = 118130;  -- Kromrif Captain 10k→6k
UPDATE npc_types SET hp = 5000                           WHERE id = 118160;  -- Kromrif Recruit 7k→5k
UPDATE npc_types SET hp = 7000                           WHERE id = 118150;  -- Kromrif Warrior 11k→7k
UPDATE npc_types SET hp = 9000                           WHERE id = 118120;  -- Kromrif General 13k→9k
UPDATE npc_types SET hp = 12000                          WHERE id = 118209;  -- Kromrif Priest 27.5k→12k
UPDATE npc_types SET hp = 12000                          WHERE id = 118158;  -- Kromrif Warlord 20k→12k (wave master — keep identifiable hp band)
UPDATE npc_types SET hp = 12000                          WHERE id = 118156;  -- Kromrif Veteran 42.5k→12k
UPDATE npc_types SET hp = 15000                          WHERE id = 118210;  -- Kromrif High Priest 50k→15k

-- Seneschal Aldikar safety bump
UPDATE npc_types SET hp = 30000                          WHERE id = 118166;  -- Seneschal Aldikar 10k→30k (prevent AOE overflow event fail)
```

**Icewell Keep (Coldain Ring 10 terminus):**

```sql
UPDATE npc_types SET hp = 80000                          WHERE id = 129003;  -- Dain Frostreaver IV 352k→80k (faction-gated per Decision #14)
UPDATE npc_types SET hp = 30000                          WHERE id = 129028;  -- Chamberlain Krystorf 80k→30k
```

**Respawn timers (12h = 43,200s for Velious non-ToV mid-tier per Decision #5):**

```sql
-- Kael main bosses, Skyshrine Yelinak x2, Tunare, outdoor dragons, Velketor,
--   Dain, Jester, Kelorek`Dar, Melalafen, Wuoshi
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID IN (
    113215, 113071,  -- Kael main (not Derakor — already 12h)
    114106, 114618,  -- Yelinak x2
    127001,          -- Tunare
    120005, 120084, 123115,  -- outdoor First Brood dragons
    112025,          -- Velketor
    129003,          -- Dain
    126012,          -- Jester
    117073,          -- Kelorek`Dar
    120126,          -- Melalafen
    119112           -- Wuoshi
);

-- Respawns already in 12h or shorter target range — NOT UPDATED:
--   113118 Derakor (12h), 114242-46 Crusaders (10.7min), 118088 Taskmaster Abyott (18h),
--   127007/106 Guardian of Tunare (18h), 127019-21 PoG mid (18h), 127035 Takish (24h),
--   127018 Fayl (18h), 127096 Prince Thirneg (18h), 112049 Doljoni (18h),
--   125070/72 Sirens pair (2h), 120057 Harla Dar (5h), 120064 Mraaka (6h),
--   110099 Lodizal (9h), 129028 Chamberlain (18h)
-- Narandi 118145 is script-spawned via condition 16; no spawn2 respawn change.
```

**Ring War Lua change — CONDITIONAL Lever 2 only:**

Default Phase 4a: **no Lua change.** Lever 1 (SQL wave-mob HP cuts above) is the primary solve per lore-master.

If game-tester validation shows Lever 1 alone is insufficient (wave clear still exceeds 5-min cooldown), lua-expert applies this one-line change:

```lua
-- akk-stack/server/quests/greatdivide/encounters/ring_war.lua, line 26:
-- OLD:
local wave_cooldown_time = 5 * 60 * 1000;  -- 5 minutes
-- NEW:
local wave_cooldown_time = 8 * 60 * 1000;  -- 8 minutes (small-group recovery buffer)
```

**Lever 2 trigger criterion (for user approval):** if small-group testing shows ≥3 consecutive waves starting before the prior wave is cleared, escalate to Lever 2.

**Net Ring War effect (Lever 1 only):** 13 waves preserved with original 5-min cadence. Each wave clearable by small group at reduced wave-mob HP. Event duration ~45-90 min. Lore-consistent "epic multi-wave defense" preserved.

**Net Ring War effect (Lever 1 + Lever 2):** 8-min cadence per wave provides larger recovery window. Event duration ~65-130 min. Still preserves event identity.

**Wave-skip approach rejected** after lore-master review — reducing wave count via `Master_Timer` advance-by-2 removes event content; Lever 1 preserves all 13 waves while making each tractable.

### Code Changes

**Default: no code changes.** Lever 1 is SQL-only.

**Conditional (Lever 2 fallback):** `akk-stack/server/quests/greatdivide/encounters/ring_war.lua` line 26 one-line `wave_cooldown_time` edit, only if game-tester validation triggers escalation per user approval.

**No C++, no Perl, no Python.**

### Configuration Changes

No `rule_values` changes. No `eqemu_config.json` changes. No `.env` changes. Confirmed by config-expert 2026-04-22.

### Database Changes

| Item | Type | Rows affected (approx) |
|------|------|------------------------|
| `npc_types_backup_raid_scaling_velious_a` | CREATE TABLE AS SELECT | 42 rows snapshot (33 bosses + 8 Kromrif wave mobs + Seneschal) |
| `spawn2_backup_raid_scaling_velious_a` | CREATE TABLE AS SELECT | ~35-40 rows snapshot |
| `npc_types` | UPDATE | ~44 rows (35 bosses + 8 Kromrif + Seneschal) |
| `spawn2` | UPDATE | ~14-16 rows (12h target set; others already shorter; Kromrif spawn2 respawntime unchanged — condition-gated) |
| `npc_spells_entries` | NO CHANGE | 0 rows |

Data-expert should produce a single SQL reference document at `data-expert/context/phase4a-velious-a-implementation.sql` with:
1. Backup table creates first.
2. All `npc_types` UPDATEs ordered by zone cluster (Kael → Skyshrine → PoG → PoM → WW dragons → Velketor → Sirens → misc).
3. All `spawn2.respawntime` UPDATEs scoped to the IDs listed above.
4. Post-change verification queries (assert HP bounds, count changed rows).
5. Full rollback script using backup tables.

Lua-expert edits `ring_war.lua` directly and commits the file backup alongside.

---

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| V1 | Build backup tables `npc_types_backup_raid_scaling_velious_a` (42 rows incl. 8 Kromrif wave mobs + Seneschal) and `spawn2_backup_raid_scaling_velious_a` (~35-40 rows); verify row counts; emit SQL reference doc structure | data-expert | — | ~30m |
| V2 | Emit per-boss HP/damage UPDATE SQL for ~35 Velious non-ToV bosses (Kael + Skyshrine + PoG + Jester pending Decision #27 + outdoor dragons + Velketor + Sirens + misc); cross-check audit targets; commit to `data-expert/context/phase4a-velious-a-implementation.sql` | data-expert | V1 | ~2h |
| V3 | Emit Ring War wave-mob HP UPDATE SQL (Lever 1: 8 Kromrif IDs per DB-confirmed exclusive-to-greatdivide sweep) + Seneschal Aldikar HP bump (10k→30k) + Narandi HP cut; include in same reference doc | data-expert | V1 | ~20m |
| V4 | Emit `spawn2.respawntime` UPDATE SQL (12h for Kael main bosses, Yelinak x2, Tunare, First Brood dragons, Velketor, Dain, Jester, Kelorek`Dar, Melalafen, Wuoshi); skip already-short respawns; Kromrif wave mobs condition-gated, no respawn change | data-expert | V1 | ~30m |
| V5 | Emit rollback script (INSERT…SELECT from backup tables, transactional) + verification queries comparing row counts before/after; mirror Phase 3 `06-kunark-rollback.sql` pattern | data-expert | V2, V3, V4 | ~20m |
| V6 | Apply all SQL changes via `docker exec akk-stack-mariadb-1 mysql -ueqemu -p'…' peq < phase4a-velious-a-implementation.sql`; capture before/after row counts and diff stats | data-expert | V5 | ~15m |
| V7 | `#reloadworld` via Spire or world telnet port 9000 so zone processes re-load modified `npc_types` and `spawn2` caches | config-expert | V6 | ~5m |
| V8 | Smoke verification: run SQL queries confirming HP targets for Tormax/Yelinak/Tunare/Klandicar/Zlandicar/Jester; respawn targets for 12h-tier bosses; Kromrif wave-mob HP at Lever 1 targets; Seneschal at 30k | config-expert | V7 | ~30m |
| V9 | Commit + push all changed files in `claude/` repo (architecture doc, context files, status updates, implementation SQL) to `feature/raid-scaling` branch. `akk-stack/` untouched unless Lever 2 triggered. | data-expert | V6 | ~10m |
| V10 | (**CONDITIONAL Lever 2**) If game-tester validation shows Lever 1 insufficient (≥3 consecutive waves starting before prior wave is cleared), escalate to user; on user approval, lua-expert edits `ring_war.lua:26` wave_cooldown_time from 5min to 8min | lua-expert | V8 + game-tester validation + user approval | ~15m if needed |
| V11 | (**CONDITIONAL**) `#reloadquests` via Spire or full-stack restart after Lever 2 edit | config-expert OR infra-expert | V10 (conditional) | ~5-10m if needed |

**Critical ordering constraint:** V1-V5 gate V6. V7 depends on V6. V8 depends on V7. V9 is git-commit only.

**Tasks V10-V11 are fallback-only** — triggered exclusively if game-tester validation (post-V9) shows Lever 1 insufficient AND user approves Lever 2. Default Phase 4a scope is V1-V9 SQL-only.

**Tasks NOT required (default path):**
- lua-expert: no Lua changes (unless Lever 2 triggered)
- c-expert: no C++ changes
- perl-expert: no Perl changes
- protocol-agent: already advised; no implementation role

**Required implementation agents (updated from prior draft):**

| Agent | Role | Tasks |
|-------|------|-------|
| data-expert | primary | V1, V2, V3, V4, V5, V6, V9 |
| config-expert | reload + smoke | V7, V8 |
| lua-expert | **conditional fallback only** | V10 (only if Lever 2 triggered post-validation) |
| infra-expert | conditional | V11 alternate (full-stack restart if #reloadquests fails after Lever 2) |

This is a **simpler implementation team than my draft** — lua-expert moves from primary (V5-V6 in draft) to conditional-only (V10 in revised plan).

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Ring War encounter re-load requires full zone restart, not `#reloadquests` | Medium | Low | Task V10 conditional — infra-expert runs full-stack restart if `#reloadquests` fails. Encounter scripts register on `event_encounter_load` which runs at encounter load, typically after zone boot. |
| `Master_Timer` wave-skip breaks event if a live Ring War is in-progress at apply time | Low | Medium | Apply during server quiet time (user coordinates). Event is relatively rare. Rollback via git restore of Lua file is ~10s. |
| Skipping wave conditions (3→5, 9→11, 13→15) means some Kromrif wave NPCs never spawn — but they also don't despawn | Near zero | Low | `Stop_Event()` clears all conditions 2-21 at end, so skipped-wave NPCs are depopped correctly. Event state remains consistent. |
| Plane of Growth Tunare-trigger script depends on specific Guardian of Tunare kill thresholds | Low | Medium | Spot-check `akk-stack/server/quests/growthplane/` for phase-trigger scripts during V6. PoG events typically use `event_death`, not absolute HP, so scaling is transparent. |
| Lord Yelinak duplicate variants actually are script-spawned / condition-gated despite no spawn_conditions entries | Very Low | Low | DB sweep confirmed both `_condition=0` (always spawn). If any script toggles their activity, both ID HP values are scaled to 110k so either behaves the same post-scale. |
| Plane of Mischief `#Jester` `_condition=2` means an alternate condition (1=classic layout?) coexists; scaling only touches Jester (not the other conditions) | Very Low | Nil | Jester is scoped by NPC ID, not zone sweep. DB query confirmed condition=2 is live. Other conditions untouched. |
| Statue of Rallos Zek → Idol → Avatar of War chain: 4a scales Statue + Idol, but AoW is 4b. Staggered scaling could create "easy Statue+Idol, unscaled AoW wall." | **HIGH for players** | Medium | **Expected per Decision #4 phasing**. Architect explicitly scopes AoW to 4b. User should be aware: clearing Kael progression requires waiting for 4b to land AoW scaling. Flag this in handoff. |
| Ring War script edit deviates from PEQ upstream | Nil | Nil | The Ring War script is already heavily custom (uses our custom encounter system and data_buckets pattern). Adding a 2-line wave-skip is a localized modification. Full script is already in `akk-stack/server/quests/` (custom, not PEQ vendored). |
| Two Guardian of Tunare duplicates (127007 + 127106) — are both live at same spawn location? | Low | Nil | DB sweep confirms both have active spawn2 rows. Scaling both for consistency; if one is vestigial, no harm. |
| Faleniel and Wygrish have fast 2h respawn — scaling HP+damage but keeping respawn means they're farmable | Medium | Nil | Per audit: intentional. They are rare spawns in Siren's Grotto; short respawn compensates. Damage cut fixes the one-shot risk without changing their "strong solo-tier" feel. |
| Event-trigger NPCs (a_warm_light 8 spawn2 rows, a_thifling_focuser 4 spawn2) — leaving them at 1M HP means they dominate "highest HP in zone" queries | Nil | Nil | Not a gameplay issue — they're non-combat triggers. Leave. |
| Backup tables occupy disk space | Near zero | Nil | ~70KB combined. Accept. |
| `npc_types.special_abilities` untouched but Vyemm-style MR walls are in 4b | Nil | Nil | Phase 4a has no MR-wall bosses in scope. PoG bosses have regular MR (40-400), Kael AC+MR standard. |

### Compatibility Risks

- **Prior-pass rule values remain authoritative.** None changed.
- **Epic quest scripts untouched per Decision #14.** Lore-master Section 5 confirms no Velious Epic 1.0 steps exist.
- **Faction scripts untouched.** CoV / Coldain / Kromzek three-way preserved per Decision #14.
- **Coldain Prayer Shawl quest chain unchanged** — architect DB review confirmed it's turn-in driven, not a scripted event. Boss-stats scaling is transparent.
- **Sleeper's Tomb key quest** — none of its talisman-dropping dragons (Sontalak, Klandicar, Zlandicar, Yelinak, Lendiniara) are Phase 4a-scaled at `_condition` values that would shift talisman drop rates. Loot per Decision #3 is unchanged.
- **Ring 10 Ring War completion** — scaled Narandi (150k→45k) + scaled wave-skip event = still a full raid event. Rings 1-9 are out of scope (named-tier mobs).
- **Companion AI unchanged.** Same scaling patterns as Phases 2/3.
- **LLM NPC conversation sidecar unchanged.** Reads name/level/faction only.

### Performance Risks

- **Zero.** ~35 UPDATEs + ~15 UPDATEs + 1 Lua-file edit. Trivial workload.
- **No new indexes needed.**
- **No opcode-layer impact** — to be confirmed by protocol-agent.
- **No zone boot overhead** — scripted encounters reload via `#reloadquests` without full restart in most cases.

---

## Review Passes

### Pass 1: Feasibility

Every lever used is established Phase 2/3 practice plus one new lever:
- `npc_types.hp`, `npc_types.mindmg`, `npc_types.maxdmg` UPDATEs — 58 Phase 2 + 21 Phase 3 = 79 rows previously touched without issue.
- `spawn2.respawntime` UPDATEs — 40+ Phase 2 + 14 Phase 3 = 54 rows previously touched.
- Backup table pattern — well established.
- **New for Phase 4a:** Lua-script edit in `ring_war.lua`. The change is two lines in an existing encounter-script function and fully reversible via git. Lua encounters use our standard encounter system; `#reloadquests` picks up script changes. Fallback: full-stack restart (infra-expert task V10).

**Hardest part:** Ring War wave-skip logic. The `Master_Timer` advance-by-2 works because:
1. Conditions 3-15 are continuous (no gaps in wave spawn2 rows per DB confirmation).
2. Condition 16 is Narandi (one row). The clamp `if current_spawn_condition > 15 then current_spawn_condition = 16 end` ensures Narandi always fires even if advance goes past the wave range.
3. `Stop_Event()` already clears conditions 2-21, so skipped-wave NPCs depop correctly at end.

**Edge case:** If a player starts the event and the first advance lands on condition 5 (instead of 3), the first wave is 3-6 Kromrif Captain+Recruit spawns (condition 5 has 6 spawn rows per DB). This is appropriate — small group gets a manageable first wave.

**Advisor confirmations received:**
- protocol-agent confirmed zero client-visible impact 2026-04-22 — zone-by-zone analysis in agent-conversations.md
- config-expert confirmed rule pattern carryover, zero new rules, no zone-scoped rulesets for Velious 2026-04-22

**Pending (lore-master):** final A/B/C recommendation on Ring War Q8 lever (architect draft: Option B+); faction-gate listing confirmations for Yelinak/Tormax/Dain; re-confirm Velious has no Epic 1.0 steps.

**Confirmed feasibility:** all tasks executable by data-expert + lua-expert + config-expert in one session. Adds lua-expert to the Phase 2/3 team of data-expert + config-expert + conditional infra-expert.

### Pass 2: Simplicity

**Challenge: Can we do less?**

- **Could we skip the Ring War Lua change and only scale Narandi?** No — lore-master's Section 2 is definitive: the event is a DPS-over-time gate, not a boss fight. A small group at 1+5 cannot sustain the DPS for 13 waves even if Narandi is weak. Scaling only Narandi leaves the event unwinnable.
- **Could we keep all 13 waves but reduce cadence to 3 min?** Possible but less effective. Reducing cadence doesn't reduce total DPS burden; it just compresses the timeline.
- **Could we skip Prince Thirneg (69,719 HP, near named-tier)?** Yes, technically. Audit explicitly says "already mid-tier — HP trim 15%." **Including the trim for consistency** — one extra UPDATE row.
- **Could we skip Mraaka (60k HP raid_target=1 but near named-tier)?** Borderline. Audit says "HP trim 30%" — including for consistency.
- **Could we skip both Yelinak variants and pick one?** No — DB sweep confirms both are live. Scaling both keeps behavior consistent regardless of which spawn2 row fires.
- **Could we skip Plane of Mischief entirely?** Possible but Jester is live in-era per `_condition=2`. Including for completeness.
- **Could we skip Taskmaster Abyott (72k HP)?** Already near mid-tier. Including HP trim for consistency with Phase 3 pattern of "already-close-but-visible target."
- **Could we defer `spawn2.respawntime` updates?** No — the 72-120h timers are the critical small-group friction point per Decision #5.
- **Could we defer the backup tables?** No — Phase 2/3 precedent.

**Removed / deferred:**
- **Bristlebane (126160) and All-Seeing Eye (126374)** — L75 out-of-era. SKIP.
- **A Legendary Velious Dragon (116607) eastwastes L72** — LoN anniversary. SKIP.
- **#An Egg Hunter (116605) eastwastes L75** — LoN. SKIP.
- **Sir Elmonious Falmont (120133)** — PoP-tier damage. SKIP.
- **Scout Leader Plavo (57156) wakening L70 300k HP** — Lesser Faydark NPC ID range. OUT-OF-ERA per audit; SKIP.
- **#Lantaric`Dar (119165) wakening** — 0-4 damage = event trigger passive. SKIP.
- **Corudoth (110037) iceclad L5 60k HP** — oddity (non-combat by level). SKIP.
- **~25 westwastes named dragons L51-62 at 24-50k HP** — named-tier per Decision #2. Prior-pass globals apply. SKIP.
- **~95 growthplane raid_target=1 at 13-40k HP** — named/trash per Decision #2. SKIP.
- **Jaled Dar's Shade (123011)** — 3M HP quest-NPC (ST key turn-in). Leave as uncombattable by design.
- **Event-trigger NPCs (127004 a_warm_light, 127005/6 a_thifling_focuser)** — event control, not kill targets. Leave.

**Ring 8/9 failure-reset UX** — script-level behavior, not a scaling lever. Deferred as a potential future user-decision.

### Pass 3: Antagonistic — what could go wrong

1. **Ring War `Master_Timer` advance-by-2 on first fire lands on condition 5 directly (skipping 3 and 4).** Intentional — small-group gets wave 5 (6 spawn rows) as first engagement, not wave 3. Consistent, not a bug.

2. **`Master_Signal` with signal=1 sets condition 3 (first wave) directly** — not via timer. The wave-skip change only affects `Master_Timer` (subsequent waves). First wave is always condition 3. Skip-increment applies from wave 2 onward. Still 7 waves total.

3. **If Narandi dies mid-event but before the final wave fires,** `Narandi_Death → Stop_Event()` clears all conditions. Safe.

4. **If Seneschal Aldikar dies (fail condition) mid-event,** `Seneschal_Death → Stop_Event()` clears all conditions. Safe.

5. **GM testing: GM says "start" to Zrelik bypasses the item handin requirement but otherwise follows the same flow.** Wave-skip logic applies identically in GM-triggered test. Safe.

6. **Lord Yelinak variant 114618 has lower HP (297k vs 500k main)** — after scaling both to 110k, the "weaker" variant is now identical to the "main" variant. Player can't tell difference. Acceptable.

7. **Plane of Growth Tunare spawn trigger** — if a_thifling_focuser kills trigger Tunare spawn via script, and a small group can't kill the 1M HP focusers, Tunare is unreachable. **Architect to verify** in `akk-stack/server/quests/growthplane/` during V6. If focuser kills are required, may need a separate user-decision. Current assumption: focusers are passive triggers activated by other means (quest turn-in or event signal).

8. **Dain Frostreaver IV scaled to 80k HP but remains Coldain-faction-gated (Ring War quest giver + Ring 10 terminus).** Small groups who haven't completed Coldain faction grind cannot approach him. Per Decision #14 (keep class-gates / faction-gates). Flag as a user-facing UX note; no architectural change needed.

9. **Idol of Rallos Zek (113341) scaled to 130k HP but triggered by Statue kill which is ALSO scaled (50k HP).** Statue is easier to kill, Idol spawns, Idol is also scaled. Chain is tractable. **But the Avatar of War (113457) terminus is Phase 4b — remains at 900k HP until 4b.** Players may reach Idol kill and find AoW is the wall. Expected per phasing.

10. **Faleniel/Wygrish damage cuts (1,900/1,575 → 950/780)** — still significant hits but not one-shots. These are Siren's Grotto NPCs with raid-tier respawn (2h) — farmable.

11. **`_condition=2` on Jester** — if some GM or script ever disables condition 2 in mischiefplane, Jester doesn't spawn at all. This is pre-existing behavior, not introduced by Phase 4a. Audit flag only.

12. **Narandi 118145's own `_condition=16 cond_value=1`** — Phase 4a does NOT change this. HP cut only. The condition-gating mechanism is preserved. Script advances condition to 16 when wave 15 clears, spawning Narandi. Unaffected by our wave-skip. Narandi fires after the skipped-wave sequence completes.

13. **`spawn2.respawntime = 43200` for Narandi would be meaningless** because Narandi is condition-gated. We intentionally skip Narandi's spawn2 in the respawn UPDATE list. But if data-expert accidentally includes it, the 43200 value just replaces the existing 749999 in `spawn2.respawntime` — still condition-gated, still no in-zone respawn. **Harmless.** Clarify in V3 SQL.

14. **Lord Yelinak main 500k→110k cut may feel too aggressive for the "dragon king of Skyshrine" feel.** Audit target is 110k per -78% guidance. Per Decision #11 we preserve signature mechanics (SEFQUMCNIDf list). The HP cut is proportional to other ToV-adjacent bosses. Accept.

15. **Post-scaling Jester at 60k HP / 780 dmg is now very solo-tractable. Mischief Plane Jester is supposed to be an "elite raid-boss" in-era.** Per audit guidance and Decision #11 scaling pattern. The fight's mechanical identity (special_abilities 1,1^7,1^12,1^13,1^14,1^17,1^21,1^31,1^32,1,60) is preserved — it's now a tractable fight rather than an unwinnable wall.

### Pass 4: Integration

**Task ordering:**
```
V1 (backups) ──> V2 (HP/dmg SQL) ──┐
               ──> V3 (respawn SQL) ──┼──> V4 (rollback)
                                      │         │
V5 (script backup) ──> V6 (ring_war.lua edit)   │
                                                v
                                V7 (apply SQL) ──> V8 (#reloadquests/world) ──> V9 (verify) ──> V11 (commit)
                                                                                    │
                                                                                    v
                                                                         V10 (full restart, conditional)
```

- Tasks V1, V5 can run first in parallel.
- V2 and V3 can be done in parallel by data-expert after V1.
- V6 can be done in parallel with V1-V4 (different repo).
- V7 depends on V4 (complete SQL reference doc).
- V8 depends on V6 AND V7 both complete.
- V9 runs after V8.
- V10 is conditional on V9 finding Ring War script not loaded.
- V11 closes Phase 4a.

**Cross-agent dependencies all resolvable:**
- game-designer (PRD + audit): inputs consumed.
- lore-master (Velious chains): inputs consumed; re-engagement complete for Q8 (pending final recommendation).
- protocol-agent: consultation in-flight; expected zero client impact.
- config-expert: consultation in-flight; expected Phase 2/3 pattern carryover.
- game-tester: will receive validation hooks below.

---

## Items flagged to user (decisions required before implementation)

### Decision #23 — Coldain Ring War (Q8) resolution — ARCHITECT-ASSIGNED, LORE-MASTER-ENDORSED

**Architect revised recommendation after lore-master Q8 deep dive (2026-04-23): Lever 1 (SQL wave-mob HP cuts) + conditional Lever 2 (Lua timer increase)**

**Critical correction:** Phase 1 catalog stated 21 waves. Live script states **13 waves + Narandi = 14 conditions**. Decision #23 narrative uses 13-wave structure.

**Key insight from lore-master (not in my original draft):** **There is no overall event timeout.** Only per-wave 5-minute cooldowns. Cutting each wave's total HP budget so each can be cleared in 2-4 min makes the event tractable without breaking its identity or reducing content.

**Three options considered:**
- **Option A (accept-as-is)** — leave wave structure untouched. Small group cannot clear waves before giants reach Thurgadin. Rejected.
- **Option B (wave-count reduction via Lua wave-skip)** — *my original draft.* Advance `current_spawn_condition` by 2 per fire. Clears event faster but removes 6 waves of content and reduces "epic multi-wave" feel. **Superseded by Option D below** after lore-master consultation.
- **Option C (reduce wave-mob HP via SQL alone)** — DB UPDATE on 8 Kromrif IDs. Lore-master's preferred primary lever. Exclusive-to-greatdivide per DB sweep (zero ID-sharing). Preserves all 13 waves. **Architect now recommends this as Lever 1.**
- **Option D (Lever 1 + conditional Lever 2)** — Lever 1 is Option C. Lever 2 is a one-line Lua edit to `ring_war.lua:26` increasing `wave_cooldown_time` from 5 min to 8 min, applied ONLY if game-tester validation shows Lever 1 insufficient. **Architect's final recommendation.**

**Recommended Lever 1 implementation (SQL):**
```sql
-- Kromrif wave mobs (exclusive to greatdivide conditions 3-15 per DB sweep)
UPDATE npc_types SET hp =  6000 WHERE id = 118130;  -- Kromrif Captain (wave master R1)
UPDATE npc_types SET hp =  5000 WHERE id = 118160;  -- Kromrif Recruit
UPDATE npc_types SET hp =  7000 WHERE id = 118150;  -- Kromrif Warrior
UPDATE npc_types SET hp =  9000 WHERE id = 118120;  -- Kromrif General (wave master R2)
UPDATE npc_types SET hp = 12000 WHERE id = 118209;  -- Kromrif Priest
UPDATE npc_types SET hp = 12000 WHERE id = 118158;  -- Kromrif Warlord (wave master R3)
UPDATE npc_types SET hp = 12000 WHERE id = 118156;  -- Kromrif Veteran
UPDATE npc_types SET hp = 15000 WHERE id = 118210;  -- Kromrif High Priest

-- Seneschal Aldikar safety bump
UPDATE npc_types SET hp = 30000 WHERE id = 118166;  -- Seneschal Aldikar 10k→30k

-- Narandi boss cut
UPDATE npc_types SET hp = 45000 WHERE id = 118145;  -- #Narandi the Wretched 150k→45k
```

**Recommended Lever 2 fallback (ONLY if triggered):**
```lua
-- akk-stack/server/quests/greatdivide/encounters/ring_war.lua, line 26:
local wave_cooldown_time = 8 * 60 * 1000;  -- was: 5 * 60 * 1000
```

**Net effect (Lever 1 only, default):** 13 waves preserved. Each wave clearable by 1+5 in 2-4 min at reduced wave-mob HP. 5-min cadence provides recovery time. Event duration ~45-90 min. Narandi terminus at 45k HP (standard boss-tier). Lore-consistent "epic multi-wave defense" preserved.

**Lever 2 trigger criterion (for user approval escalation):** game-tester observes ≥3 consecutive waves starting before the prior wave is cleared — indicates wave-mob HP cuts alone didn't produce enough margin. Lua-expert then edits wave_cooldown_time from 5min to 8min.

**Decision #2 compliance note:** Lever 1 touches trash/named-tier NPC HP (Kromrif wave mobs are raid_target=0). Lore-master explicitly endorses this per Q8 architect-assigned guidance — the Ring War is a raid event, and these NPCs are its event-trash, not baseline-zone trash. The Decision #2 principle (named/trash difficulty feels good) applies to standing-zone content, not scripted event waves.

**User approval needed:** confirm Lever 1 + Lever 2 fallback plan for implementation dispatch.

### Decision #24 — Lord Yelinak duplicate handling

Two `npc_types` IDs exist for Lord Yelinak:
- 114106 main: 500k HP
- 114618 variant: 297k HP

Both have active `spawn2` rows in `skyshrine` with `_condition=0` (always spawn). No spawn_conditions entries exist for the zone.

**Two options:**
- **Option A (scale both):** 114106 HP 500k→110k, 114618 HP 297k→110k. Players encounter a consistent "Lord Yelinak" regardless of which spawn2 row fires. **Architect recommends.**
- **Option B (scale only main 114106):** Leaves 114618 at 297k HP — still raid-tier but less consistent. Audit flagged "one likely deprecated" but DB sweep shows both live.

Decision is primarily about whether 114618 is a legacy/deprecated NPC or a legitimate "second spawn location." Since DB evidence shows both active, Option A is safer.

### Decision #25 — Faction grind acceleration (flag only)

Per Decision #14 (keep class-gates / faction-gates), Coldain/Kromzek/CoV three-way faction gating stays. On a 1-3 player server, reaching Ally with any of the three takes many hours of outdoor-giant killing.

**Not a Phase 4a deliverable** — architect flags as a potential future initiative.

**Options surfaced:**
- Leave as-is (current Decision #14 position)
- Boost faction-hit rate via rule change (`Character:FactionHitRate` or similar)
- Add faction-bypass items (quest rewards that grant faction standing)

**Architect recommendation:** leave as-is for Phase 4a. Re-evaluate after user tests Phase 4a content and assesses whether faction grind is the actual small-group blocker (vs. boss-stats, which Phase 4a addresses).

### Decision #26 — Ring 8 / Ring 9 failure-reset UX softening (flag only)

Per lore-master Section 2:
- Ring 8: 4-minute Chief Ry'Gorr kill window during fort war. Miss it → Rings 1-7 reset.
- Ring 9: Juliash Lockheart 10-minute hard despawn timer.

These are **script-level UX concerns**, not scaling levers. All Ring 4-9 encounters are raid_target=0 at 870-6,000 HP (DB-confirmed) — not raid-tier content.

**Not a Phase 4a deliverable.** Architect flags for potential future user decision.

**Options surfaced:**
- Leave as-is — respects classic-era "progression reset" feel
- Soften Ring 8 reset (e.g., reset only to Ring 7 not Ring 1)
- Remove 10-minute Juliash timer

**Architect recommendation:** leave as-is; out of Phase 4a scope.


### Decision #27 — Plane of Mischief Jester (126012) inclusion

Per lore-master Phase 4a re-review (Section 5): recommended to **exclude** `#the_Mischievous_Jester` (126012 L70 200k HP) from Phase 4a scope unless user specifically wants Mischief Plane content.

Rationale from lore-master: Plane of Mischief is "era-boundary" content — the zone itself was post-Luclin revamped on PEQ, and the in-era Jester spawn is a remnant. Bristlebane (L75) and All-Seeing Eye (L75) are firmly out-of-era; only Jester sits in the gray zone.

**Three options:**
- **Option A (include, as my draft plans):** scale Jester 200k→60k HP, 1431→780 maxdmg, respawn 78h→12h. Architect's original draft position.
- **Option B (exclude):** remove from Phase 4a UPDATE scope. Jester remains at current 200k HP / 78h respawn, unscaled. Align with lore-master's recommendation.
- **Option C (defer to user-driven re-add):** exclude from Phase 4a; user can request a one-off scaling later if they want to visit Plane of Mischief.

**Architect defers to user.** No strong architectural preference. If user excludes (Option B or C), remove 126012 from the `npc_types` UPDATE list and backup table; implementation footprint drops by 1 row.
---

## Required Implementation Agents

**Default path (Lever 1 only — SQL-only, lore-master-endorsed):**

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| data-expert | V1, V2, V3, V4, V5, V6, V9 | Owns all SQL emission, backup creation, apply, and commit. Primary agent. |
| config-expert | V7, V8 | `#reloadworld` via world telnet port 9000 and post-change smoke verification. Same role as Phases 2/3. |

**Conditional additions (Lever 2 fallback — only if Lever 1 insufficient per game-tester + user approval):**

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| lua-expert | V10 | One-line edit to `ring_war.lua:26` wave_cooldown_time (5min→8min). Only invoked on Lever 2 escalation. |
| infra-expert | V11 alternate | Full-stack restart if `#reloadquests` doesn't propagate Lua encounter script change. |

**Agents NOT needed:** c-expert, perl-expert, protocol-agent (already advised, no implementation role).

---

## Validation Plan

_game-tester should verify each of the following after the implementation team completes Tasks V1-V11:_

### Backup integrity
- [ ] **Backup tables exist and are populated.**
  ```sql
  SELECT COUNT(*) FROM npc_types_backup_raid_scaling_velious_a;  -- expect 33
  SELECT COUNT(*) FROM spawn2_backup_raid_scaling_velious_a;     -- expect ~35-40
  ```
- [ ] **Ring War script backup exists.**
  ```bash
  ls akk-stack/server/quests/greatdivide/encounters/ring_war.lua.backup_velious_a
  # OR verify via git that pre-change version is recoverable
  ```

### HP target verification
- [ ] **Kael Drakkel:** `SELECT id, hp, maxdmg FROM npc_types WHERE id IN (113215, 113071, 113341, 113118)` returns (113215, 100000), (113071, 50000, 500), (113341, 130000, 700), (113118, 60000, 560).
- [ ] **Skyshrine:** `SELECT id, hp FROM npc_types WHERE id IN (114106, 114618, 114242, 114243, 114245, 114246)` returns 110000 for both Yelinak variants, 50000 for all 4 Crusaders.
- [ ] **Plane of Growth Tunare:** `SELECT hp FROM npc_types WHERE id = 127001` returns 150000.
- [ ] **Plane of Growth mid-tier:** `SELECT id, hp, maxdmg FROM npc_types WHERE id IN (127020, 127019, 127021, 127018)` returns HPs (60000, 55000, 55000, 45000) and maxdmg 560 for all four.
- [ ] **Outdoor dragons:** `SELECT hp FROM npc_types WHERE id IN (120005, 120084, 123115, 117073)` returns (40000, 40000, 35000, 35000).
- [ ] **Velketor:** `SELECT hp, maxdmg FROM npc_types WHERE id = 112025` returns (60000, 680).
- [ ] **Siren's Grotto:** `SELECT id, hp, mindmg, maxdmg FROM npc_types WHERE id IN (125070, 125072)` returns (125070, 90000, 190, 950), (125072, 60000, 294, 780).
- [ ] **Jester:** `SELECT hp, maxdmg FROM npc_types WHERE id = 126012` returns (60000, 780).
- [ ] **Narandi:** `SELECT hp FROM npc_types WHERE id = 118145` returns 45000.
- [ ] **Dain Frostreaver IV:** `SELECT hp FROM npc_types WHERE id = 129003` returns 80000.

### Respawn verification
- [ ] **12h respawn applied:** `SELECT s2.respawntime FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID=s2.spawngroupID WHERE se.npcID IN (113215, 114106, 114618, 127001, 120005, 120084, 123115, 112025, 129003, 126012, 117073, 120126, 119112)` all return 43200.
- [ ] **Already-short respawns preserved:** `SELECT respawntime FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID=s2.spawngroupID WHERE se.npcID = 118088` returns 64800 (Taskmaster Abyott 18h — unchanged).
- [ ] **Narandi respawn unchanged:** `SELECT s2.respawntime, s2._condition FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID=s2.spawngroupID WHERE se.npcID = 118145` returns 749999 and condition 16 (Narandi is script-spawned; respawn is effectively irrelevant).

### Ring War script verification (default: NO Lua change)

- [ ] **`ring_war.lua` unchanged by default:** `wave_cooldown_time = 5 * 60 * 1000;` at line 26 (unchanged per Lever 1). `Master_Timer` advances `current_spawn_condition + 1` (unchanged per Lever 1).
- [ ] **Encounter still loads:** zone log for greatdivide shows `event_encounter_load` fired for 'ring_war'.

**Lever 2 ring_war.lua verification (ONLY if Lever 2 triggered):**
- [ ] Line 26: `wave_cooldown_time = 8 * 60 * 1000;` (was 5 min)
- [ ] `Master_Timer` unchanged (still + 1)
- [ ] Post-`#reloadquests` zone log shows encounter reloaded with new timer value (or full zone restart applied).

### Untouched NPC verification
- [ ] **Jaled Dar's Shade untouched:** `SELECT hp FROM npc_types WHERE id = 123011` returns 3002000 (unchanged).
- [ ] **Event triggers untouched:** `SELECT hp FROM npc_types WHERE id IN (127004, 127005, 127006)` returns 1000000 for all.
- [ ] **#Lantaric`Dar untouched:** `SELECT hp, maxdmg FROM npc_types WHERE id = 119165` returns 800000, 4 (unchanged).
- [ ] **Out-of-era dragons untouched:** `SELECT hp FROM npc_types WHERE id IN (116605, 116607, 120133, 57156, 126160, 126374)` all unchanged.
- [ ] **No npc_spells_entries changes:** `SELECT COUNT(*) FROM npc_spells_entries_backup_raid_scaling` unchanged from Phase 2 value (or no such table for Phase 4a).

### In-game smoke tests (1 player + 5 companions)

- [ ] **Kill King Tormax in Kael Drakkel:** completable in 1-3 attempts. Signature SERQUMCNDf flags active (summon, enrage, flurry, rampage). Respawn confirms 12h.
- [ ] **Kill Statue of Rallos Zek in Kael:** completable. Verify Idol of Rallos Zek spawns on Statue death. Kill Idol; confirm Avatar of War spawns (but do NOT engage AoW — it's Phase 4b unscaled, user should flee).
- [ ] **Kill Lord Yelinak in Skyshrine (either variant):** completable. Dragon breath mechanic preserved. Respawn 12h.
- [ ] **Kill Skyshrine Crusaders quad:** all 4 killable as a group fight. Respawn 10.7 min.
- [ ] **Plane of Growth:** kill Rumbleroot, Ail the Elder, Treah Greenroot. Each completable. Damage trims prevent one-shot risk.
- [ ] **Kill Klandicar or Sontalak in Western Wastes:** completable. Pick up Sleeper's Tomb Talisman. Hand to Jaled Dar's Shade (still uncombattable 3M HP by design). Receive Key of Sleeper's Tomb. (Do not proceed to Sleeper's Tomb — Phase 4b.)
- [ ] **Kill Velketor the Sorcerer in Velketor:** completable. Sunstrike/Sundering spells still cast. No death-touch events.
- [ ] **Kill Faleniel and Wygrish in Siren's Grotto:** both killable. Max damage ~950 and ~780 respectively (was 1,900 and 1,575 = one-shot).
- [ ] **Kill Mischievous Jester in Plane of Mischief:** completable. Signature mechanics preserved.

### Coldain Ring War event (post-Lever 1)

- [ ] **Kromrif wave-mob HP at Lever 1 targets:**
  ```sql
  SELECT id, name, hp FROM npc_types WHERE id IN (118130, 118160, 118150, 118120, 118209, 118158, 118156, 118210);
  -- Expected: Captain 6k, Recruit 5k, Warrior 7k, General 9k, Priest 12k, Warlord 12k, Veteran 12k, High Priest 15k
  ```
- [ ] **Seneschal Aldikar HP bump:** `SELECT hp FROM npc_types WHERE id = 118166;` returns 30000 (was 10000).
- [ ] **Narandi HP cut:** `SELECT hp FROM npc_types WHERE id = 118145;` returns 45000 (was 150000).
- [ ] **Ring War script unchanged by default:** `wave_cooldown_time = 5 * 60 * 1000` at `ring_war.lua:26`. `Master_Timer` still advances `current_spawn_condition + 1`. Only Lever 2 changes these.
- [ ] **Trigger Ring War event** (hand item 18511 to Zrelik in greatdivide, or use GM "start" trigger): event fires, Seneschal Aldikar shouts, first wave spawns (condition 3).
- [ ] **Kill first wave (condition 3 Kromrif Captain + Recruits):** small group clears in 2-4 min. Wave master Captain dies → 5-min timer → condition 4 advances normally.
- [ ] **Kill all 13 waves in sequence:** conditions 3-15 fire one per wave-master-death + 5-min-cooldown cycle. Round 1 (waves 3-8) = Captain + Recruits. Round 2 (waves 9-12) = General + Priest + Warrior. Round 3 (waves 13-15) = Warlord + Veteran + High Priest.
- [ ] **Seneschal Aldikar survives event:** not killed by AOE overflow during wave cooldowns. Bump to 30k HP should prevent fail.
- [ ] **Wave 15 clears → Narandi spawns (condition 16).** Narandi at 45k HP killable by small group. Loot Shorn Head of Narandi.
- [ ] **Hand Shorn Head to Churn the Axeman** → receive Crown of Narandi. Similarly Kargin (Eye), Corbin (Earring), Dobbin (Faceguard), Garadain (Choker).
- [ ] **Total event duration:** ~45-90 min (wave clear, Lever 1 target) + 3-5 min (Narandi). Longer than my draft's ~30-35 min but more lore-consistent.

**Lever 2 trigger check:** if ≥3 consecutive waves start before prior wave is cleared, escalate to user for Lever 2 (8-min cadence). Otherwise Lever 1 is sufficient.

### Rollback dry-run
- [ ] **Using backup tables, restore `npc_types` for 3 sample NPCs** (King Tormax 113215, Nexona-equivalent Klandicar 120084, Tunare 127001) and verify pre-change values match.
- [ ] **Using git revert, restore `ring_war.lua`** and verify original `current_spawn_condition + 1` line is present.

### Quest chain integrity
- [ ] **Coldain Prayer Shawl chain** — give 4 Kromrif toes to Loremaster Borannin (thurgadina). Receive Burlap Coldain Prayer Shawl (item 1175). Chain proceeds per Prayer Shawl script. Unaffected by boss-stats changes.
- [ ] **Ring 10 → post-event turn-ins** — Shorn Head to Garadain → Choker of the Wretched. Narandi's Crown, Eye, Earring, Faceguard from Churn/Kargin/Corbin/Dobbin. All item summons fire correctly.

### No regression on unchanged NPCs
- [ ] Spot-check Harla Dar (120057, should stay at 28k HP per 40% trim) and Lodizal (110099, should stay at 32k HP per 20% trim).
- [ ] Westwastes named dragons (L51-62 range) HP unchanged (prior-pass named-tier pass handled).
- [ ] Growthplane trash mobs (L48-62 range) HP unchanged.

---

## Appendix — Flagged items not in Phase 4a scope

The following are noted for future phases:

- **Phase 4b (Velious ToV+Sleeper+Vulak):** Temple of Veeshan 16 dragon lords, Sleeper's Tomb 13 encounter bosses, Avatar of War (113457), Vulak`Aerr (124155). NToV mid-tier named (124030-124040 range) + ToV defender-class (124050-124052, 124079) + Midayor cluster.
- **Sleeper-awake event (Kerafyrm L99)** — untouched per Decision #12.
- **Phase 5a (Luclin non-VT):** Ssraeshza, Grieg's End, Akheva, Luclin raid content ex-VT.
- **Phase 5b (Luclin VT+shards):** Vex Thal, 13-shard key rework.
- **Ring 4-9 named encounters (raid_target=0, 870-6,000 HP):** not raid-tier. Script-UX softening possible (Ring 8 reset, Ring 9 Juliash timer) — Decision #26 flagged.
- **Faction grind acceleration:** Decision #25 flagged.
- **Coldain Prayer Shawl quest:** out of raid-scaling scope (turn-in chain, not raid event).
- **Plane of Mischief out-of-era bosses (Bristlebane L75, All-Seeing Eye L75):** out of era filter. If user wants them in-scope later, separate scaling pass.
- **Scout Leader Plavo (57156) wakening L70 300k HP:** audit flagged as OUT-OF-ERA (Lesser Faydark NPC ID range, possibly revamp content). User can re-evaluate.

---

> **Next step:** User decisions on Decisions #23 (Ring War lever — architect recommends Option B+), #24 (Yelinak duplicate — architect recommends both scaled), #25 (faction grind — recommend out of scope), #26 (Ring 8/9 UX — recommend out of scope). Then spawn the implementation team with:
> - **data-expert** (Tasks V1-V4, V7, V11)
> - **lua-expert** (Tasks V5, V6) — new to Phase 4a
> - **config-expert** (Tasks V8-V9)
> - **infra-expert** (Task V10, conditional)
>
> Do NOT spawn c-expert, perl-expert, or protocol-agent — they have no Phase 4a implementation work.

---

## Addenda

### 2026-04-22 — Protocol-agent Phase 4a consultation (confirmed)

Protocol-agent confirmed **zero Titanium client protocol impact** for Phase 4a. Key
findings (full transcript in `agent-conversations.md`):

- **Kael Avatar chain (Statue→Idol→Avatar):** Clean staggered scaling. `eq.unique_spawn()` on
  `event_death_complete` sends standard `NewSpawn_Struct`. Scaling Statue and Idol in 4a while
  holding Avatar for 4b produces zero client anomaly.
- **Plane of Growth event NPCs (a_warm_light L1/1M, a_thifling_focuser L65/1M):** No Titanium
  anomaly. Client renders HP as percentage (uint8); no level/HP coherence check. Leave as-is.
- **Jaled Dar's Shade (3M HP uncombattable turn-in NPC):** No client concern. `MobHealth`
  packets are percentage-only on the wire. Leave at 3M HP.
- **thurgadinb:** Standard static outdoor zone. No DZ/Expedition. Dain Frostreaver IV is a
  normal static spawn; standard `npc_types` UPDATE applies.
- **Ring War Lua changes:** `eq.spawn_condition()` is server-internal state. Client only sees
  NewSpawn/DeleteSpawn per wave mob. No "wave N of 21" concept on client side.
- **Respawn timer / Ring War interaction:** Zero interaction. Ring War uses `spawn_condition`
  gating (not `spawn2.respawntime`) for wave mobs. Narandi's out-of-event respawn is
  independent of event mechanics.
- **Velious opcodes:** None. All Phase 4a zones use standard `ZoneChange_Struct` entry flow.
  No Velious-era client protocol additions.

**Verdict: Phase 4a is 100% server-side; proceed without client-layer constraints.**

### 2026-04-22 — Config-expert Phase 4a consultation (confirmed)

Config-expert confirmed **all Phase 2/3 rule patterns hold for Phase 4a**. Key findings
(full transcript in `agent-conversations.md`):

- **rule_values count:** 1,112 (exact, zero drift).
- **All seven prior-pass globals unchanged:** `NPCFlurryChance=12`, `MaxRampageTargets=2`,
  `NPCAssistCap=3`, `StartEnrageValue=5`, `GlobalLootMultiplier=2`, `CurrentExpansion=3`,
  `AllowRaidTargetBlind=false`.
- **All Velious zones confirmed `ruleset=1, min_status=0`:** kael, skyshrine, growthplane,
  mischiefplane, westwastes, eastwastes, sleeper, templeveeshan, greatdivide, thurgadinb.
  **No zone overrides anywhere in the table.**
- **Zero rules for Ring War.** `wave_cooldown_time = 5 * 60 * 1000` at `ring_war.lua:26` is
  a Lua local — not a rule, not a DB column. `eq.spawn_condition()` and `eq.signal()` are
  pure engine calls with no rule-layer backing.
- **No `Character:FactionHitRate` or `Character:FactionOverride` rules exist.** Only faction
  threshold band definitions are present. Velious faction gates operate through
  `npc_faction_id` / `faction_list` / `faction_list_mod` tables (pure DB data).
- **Nothing non-default Velious-adjacent.** No Kael/Skyshrine/Growth/ToV-adjacent rule exists.

**Verdict: zero `rule_values` changes, zero config file changes. SQL-only + 1 Lua file same
as Phase 2/3 pattern. Config-expert implementation role identical to Phases 2/3 — Tasks V8
(`#reloadworld`) and V9 (smoke verification).**

### 2026-04-23 — Lore-master Phase 4a re-engagement (confirmed)

Lore-master delivered Q8 resolution and comprehensive Phase 4a sign-off. Full transcript in
`agent-conversations.md`.

**Wave count correction:** Phase 1 catalog stated 21 waves (from P99 wiki). Live script
confirmed 13 mob waves + Narandi = 14 total event conditions. All Phase 4a documentation
uses 13-wave structure.

**Q8 Resolution — architect adopts lore-master's Lever 1 recommendation over my draft Option B+:**

- **Primary (Lever 1 — SQL wave-mob HP cuts):** 8 Kromrif NPC IDs (exclusive to greatdivide
  conditions 3-15 per DB sweep) plus Seneschal Aldikar HP bump. Standard `npc_types` UPDATE
  pattern. No Lua changes by default.
- **Fallback (Lever 2 — conditional Lua edit):** one-line `wave_cooldown_time` change at
  `ring_war.lua:26` from 5min to 8min. Invoked ONLY if game-tester validation shows
  Lever 1 insufficient AND user approves escalation.

**Decision rationale:** Lore-master noted the Ring War has no overall event timeout — only
per-wave 5-min cooldowns. The lore-consistent solve is to make each wave clearable, not to
skip waves. My original draft (Option B+ wave-skip) was superseded.

**Coldain Prayer Shawl (1-8) confirmed NOT raid-tier:**
- Shawls 1-7 are Velious-era, quest turn-in driven (Frost Giant Toes, Kromrif Heads, baked
  food items, Velketor spider tradeskill, multi-zone tailoring combines, Kael/Siren's Grotto
  gathering). No raid bosses required.
- Shawl 8 is Luclin-era (Avatar of Below in Wakening Lands). Out of Phase 4a scope.
- Dain Frostreaver IV (129003) serves as audience NPC for Shawl 8 turn-in. HP cuts on Dain
  do not affect Shawl 8 progression (non-combat interaction).

**Velious Epic 1.0 re-confirmed absent.** All 14 class Epic 1.0 chains complete in
Classic + Kunark. No Velious steps. Druid/Wizard Velious port spells are independent
tradeskills, not epic steps.

**Faction gate listing:**
- Thurgadin / Icewell Keep: Coldain Amiable+
- Kael Drakkel: Kromzek Dubious+ for vendor; KoS = combat-only approach
- Skyshrine: Claws of Veeshan Amiable+
- Western Wastes: open (most dragons KoS)
- Plane of Growth: open (CoV-aligned)
- Siren's Grotto / Velketor / Great Divide / Eastern Wastes: open zones

**Quest-NPC flags reconfirmed:**
- Jaled Dar's Shade (123011, 3M HP): quest turn-in NPC, not kill target — leave untouched
- Lantaric`Dar (119165, 800k HP, 0-4 dmg): event mob — skip
- a_warm_light (127004) / a_thifling_focuser (127005-06) (L1/L65, 1M HP): event triggers — skip

**Out-of-era exclusions confirmed:**
- Sir Elmonious Falmont (120133 PoP-tier dmg): exclude
- Scout Leader Plavo (57156 Lesser Faydark ID range): exclude
- Legendary Velious Dragon (116607 LoN L72): exclude
- #An Egg Hunter (116605 L75): exclude
- #Bristlebane (126160 L75) / All-Seeing Eye (126374 L75): exclude
- **#the Mischievous Jester (126012 L70)**: lore-master recommends exclude unless user
  specifically wants Mischief Plane content. **Decision #27 raised.**

**Architect flags to verify before apply:**
- Statue → Idol → Avatar of War spawn chain: scripted trigger — verified in Phase 3 protocol
  review; chain uses `eq.unique_spawn()` on `event_death_complete`, not HP-percentage gates.
  Safe to scale Statue and Idol with Avatar held for 4b.
- Dain Frostreaver IV HP cuts: Shawl 8 turn-in is faction-based not combat. Safe.
- Wuoshi (119112, 46k HP): already near named-tier, minor trim only (confirmed in my plan).

**Ring 8 failure-reset (Chief Ry'Gorr 4-min window):** lore-master agrees this is outside
Phase 4a raid-scaling scope. Document as known limitation (Decision #26 flag only). Script
UX softening is a separate future decision.

**Phase 4a non-ToV scope signed off by lore-master** — all zones, all bosses, all
quest-chain routing verified lore-correct and era-appropriate.
