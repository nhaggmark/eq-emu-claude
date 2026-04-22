# Raid Scaling — Architecture & Implementation Plan (Phase 2: Classic)

> **Feature branch:** `feature/raid-scaling`
> **PRD:** `game-designer/prd.md`
> **Audit:** `game-designer/raid-scaling-audit.md`
> **Lore catalog:** `lore-master/epics.md`
> **Author:** architect
> **Date:** 2026-04-22
> **Status:** Draft — ready for implementation
> **Scope:** **Phase 2 (Classic raids + Classic-phase epic steps) ONLY.** Kunark, Velious non-ToV, Velious ToV+Sleeper+Vulak, Luclin non-VT, Luclin VT+shards are each their own future architecture pass.

---

## Executive Summary

Phase 2 scales every in-era Classic raid boss (Plane of Fear, Plane of Hate (revamp layout `hateplaneb`), Plane of Sky, Lord Nagafen, Lady Vox, Phinigel Autropos, Cazic Thule, and miscellaneous Classic raid NPCs) to the "slightly harder than scaled named" difficulty target per Decision #1, while preserving signature mechanics per Decision #11. The plan is **100% SQL** — no C++ changes, no Lua/Perl script rewrites, no rule value changes. Three data layers are touched: `npc_types` (HP/damage/special_abilities per boss), `spawn2` (respawn times per raid-boss spawn), and `npc_spells_entries` (surgical removal of spell 982 "Cazic Touch" from three Plane of Sky spell lists to implement the death-touch removal decision). All changes are reversible via pre-change backup tables captured from `raid_target=1` rows. Zero client protocol impact (verified by protocol-agent). One data-expert task, one config-expert verification task, one infra-expert restart task.

---

## Existing System Analysis

### Current State

**Prior small-group-scaling pass (2026-02-23)** is in effect server-wide. It globally tuned overland and group content via:
- `rule_values`: `NPC:NPCFlurryChance=12`, `Combat:MaxRampageTargets=2`, `NPC:NPCAssistCap=3`, `Combat:StartEnrageValue=5`, `Character:GlobalLootMultiplier=2`, server-wide XP/regen multipliers. These remain active and apply to raid bosses.
- `npc_types` per-row UPDATEs to HP/damage/AC with explicit `WHERE raid_target = 0` — deliberately excluding raid bosses.
- `spawn2.respawntime` reductions for some raid_target NPCs (25% cut), but core endgame timers still in the 54-130h range.

**Result:** every `raid_target = 1` boss is at stock PEQ values. Classic boss HP pools: 15,750 (Drusella — edge case, not in Phase 2) to 451,000 (Cazic Thule). Respawns: 194,400s (54h) typical for L55-70 bosses.

**Relevant topography:**
- `eqemu/common/emu_constants.h:527-591` — `SpecialAbility` namespace enum (IDs 1-57). `HarmFromClientImmunity = 35` is a CLIENT-DAMAGE-IMMUNITY flag, not an attack.
- `eqemu/zone/mob.cpp:7572-7620` — `Mob::ProcessSpecialAbilities()` parses the CSV string `ability,value,param0,param1,...^ability,value,...` from `npc_types.special_abilities`.
- `eqemu/zone/mob_ai.cpp` — `NPC::AICastSpell()` iterates `AISpells_Struct` populated from `npc_spells` and `npc_spells_entries`. Spells with 0 cast_time / 0 recast_time / 0 mana can fire on every AI think-cycle when the NPC is engaged.
- `claude/docs/topography/SQL-CODE.md:112-134` — `npc_types` (~150 columns), `npc_spells` → `npc_spells_entries` → `spells_new` chain, `loottable` chain.
- `claude/docs/topography/PROTOCOL-CODE.md` — `MobHealth` packet sends % only; client never receives absolute NPC HP or max-damage values.

### Gap Analysis

| Gap | Lever |
|-----|-------|
| 30 Classic-era raid bosses at PEQ defaults (HP 18k-451k) | Per-NPC UPDATE `npc_types.hp` (and `maxdmg` for outliers) |
| Respawn timers 54-72h outside brief's 6-24h target | Per-spawn UPDATE `spawn2.respawntime` |
| Cazic Thule rampage 10 targets is untractable for small group | Edit param0 on ability 3 in `npc_types.special_abilities` |
| Three PoSky bosses (Keeper, Spiroc Lord, Bazzt Zzzt) cast spell 982 "Cazic Touch" (-100k HP, 0 cast, 0 mana) — instant kill regardless of player HP | DELETE from `npc_spells_entries` where `npc_spells_id IN (118, 449, 969) AND spellid = 982` |
| 13 "triggered / script-spawned" Classic bosses NOT captured by `raid_target=1 + spawnentry` join — missed by initial audit (Q13) | Extend in-scope NPC ID list; same UPDATE patterns apply |
| 23 revamp Plane of Hate (`hateplaneb`) bosses populated but untreated | Include hateplaneb in scaling scope (DB and scripts confirm hateplaneb is the live Titanium-reachable PoH layout) |

### What is NOT gap for Phase 2

- **No C++ changes.** The existing special_abilities parser and spell AI handle every lever cleanly.
- **No rule_values changes.** Global combat rules remain at prior-pass settings.
- **No Lua/Perl quest script changes.** Classic epic quest scripts are untouched per Decision #14 (class-gate steps preserved); no quest script currently controls the death-touch, HP, or respawn values — those are pure DB content.
- **No loot table changes.** Decision #3 (loot pinatas preserved).

---

## Technical Approach

### Architecture Decision

**Every Phase 2 change is a database UPDATE/DELETE.** Per the layer priority (rules > config > Lua > SQL > C++):
1. **Rules — NOT APPLICABLE.** No rule exists for per-boss HP/damage/respawn. Adding a new rule would require C++ recompile, which violates the "reversible via DB" precedent of the prior pass. Global rules are already tuned.
2. **Config (eqemu_config.json / .env) — NOT APPLICABLE.** These are structural server settings, not content tuning.
3. **Lua/Perl scripts — NOT APPLICABLE.** Decision #14 keeps class-gate steps as-is; Decision #11 preserves signature mechanics (script-driven behaviors remain). No script currently controls HP/damage/respawn.
4. **SQL — YES.** All changes target `npc_types`, `spawn2`, and `npc_spells_entries`. This matches the prior-pass pattern and is fully reversible via backup tables.
5. **C++ — NOT APPLICABLE.** No engine change needed.

### Component Change Table

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `npc_types.hp` (30 Classic bosses + 13 Q13 additions) | UPDATE per-NPC | Per-boss HP targets vary (20% to 75% cut) per audit; global scalar inappropriate |
| `npc_types.maxdmg` (2-3 Classic outliers — Cazic, dracoliche, Bazzt Zzzt max > 900) | UPDATE per-NPC | Audit lever 2; only apply where one-shot risk |
| `npc_types.special_abilities` (Cazic Thule) | UPDATE per-NPC (string edit) | Trim ability 3 param0 from 10 to 3 for rampage target count |
| `spawn2.respawntime` (all Classic raid-boss spawns) | UPDATE per-spawn | Target 6h low-tier (21,600s) for most; 12h (43,200s) for Cazic Thule per Decision #8 |
| `npc_spells_entries` (3 PoSky spell lists 118, 449, 969) | DELETE | Remove spell 982 "Cazic Touch" per Decision #13 |
| Backup tables `npc_types_backup_raid_scaling`, `spawn2_backup_raid_scaling`, `npc_spells_entries_backup_raid_scaling` | CREATE + INSERT-SELECT | Pre-change snapshot; mirrors prior pass's `_backup_sgs` pattern |
| `rule_values` | NO CHANGE | Confirmed with config-expert; no rule-level lever exists and none needed |
| `eqemu_config.json` | NO CHANGE | Expansion lock already at Luclin |
| Lua/Perl scripts | NO CHANGE | Decisions #11 and #14 preserve all scripted behavior |
| C++ source | NO CHANGE | N/A |

### Data Model

#### Backup tables (captured BEFORE any other change)

```sql
CREATE TABLE npc_types_backup_raid_scaling AS
SELECT id, hp, mindmg, maxdmg, AC, special_abilities, npcspecialattks
FROM npc_types
WHERE raid_target = 1
  AND level BETWEEN 45 AND 70
  AND name NOT LIKE '#The_Fabled%';
-- Expected rows: ~750 (Classic + Kunark + Velious + Luclin raid_target=1 rows in era).
-- Intentional over-capture: covers all eras for cross-phase rollback safety.

CREATE TABLE spawn2_backup_raid_scaling AS
SELECT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
JOIN npc_types nt ON nt.id = se.npcID
WHERE nt.raid_target = 1
  AND nt.level BETWEEN 45 AND 70
  AND nt.name NOT LIKE '#The_Fabled%';

CREATE TABLE npc_spells_entries_backup_raid_scaling AS
SELECT npc_spells_id, spellid, minlevel, maxlevel, priority, resist_adjust, min_hp, max_hp
FROM npc_spells_entries
WHERE npc_spells_id IN (118, 449, 969);
-- Phase 2 only touches 3 rows (spell 982 in each list). Full lists captured for safety.
```

#### Phase 2 change sketch (data-expert emits final SQL; these are authoritative targets)

**Per-boss HP/damage (illustrative — full table in audit + Q13 context):**

```sql
-- Low-tier Classic dragons (Decision target: 50-65% HP cut, keep damage)
UPDATE npc_types SET hp = 14400 WHERE id = 32040;  -- Nagafen 32000 -> 14400 (55% cut)
UPDATE npc_types SET hp = 14400 WHERE id = 73057;  -- Vox 32000 -> 14400
UPDATE npc_types SET hp = 13500 WHERE id = 64001;  -- Phinigel 18000 -> 13500 (25% cut)

-- Plane of Fear bosses (30-40% HP cut)
UPDATE npc_types SET hp = 20000 WHERE id = 72000;  -- Dread 32500 -> 20000
UPDATE npc_types SET hp = 20000 WHERE id = 72002;  -- Terror
UPDATE npc_types SET hp = 20000 WHERE id = 72004;  -- Fright
UPDATE npc_types SET hp = 21000 WHERE id = 72012;  -- Tempest Reaver 35000 -> 21000
UPDATE npc_types SET hp = 17500 WHERE id = 72001;  -- Wraith of Shissar 25000 -> 17500

-- Plane of Fear outliers (70-80% cut)
UPDATE npc_types SET hp = 40000, maxdmg = 420 WHERE id = 72090;  -- dracoliche 175k -> 40k, trim max
UPDATE npc_types SET hp = 80000 WHERE id = 72003;  -- Cazic Thule 451k -> 80k
UPDATE npc_types SET maxdmg = 450 WHERE id = 72003;  -- Also trim CT max (from 603 -> 450, Lever 2 outlier)
UPDATE npc_types SET
  special_abilities = REPLACE(special_abilities, '3,1,10', '3,1,3')
WHERE id = 72003;  -- Rampage param0 from 10 -> 3 per PRD
-- Q13 Plane of Fear additions
UPDATE npc_types SET hp = 35000 WHERE id = 72069;  -- Ireblind Imp 139.5k -> 35k
UPDATE npc_types SET hp = 40000 WHERE id = 72106;  -- Enraged Golem 175k -> 40k
UPDATE npc_types SET hp = 18000 WHERE id = 72108;  -- Enraged Imp 25k -> 18k (already near named-tier)

-- Plane of Hate (CLASSIC hateplane — optional; current traffic nil, but back up for safety)
UPDATE npc_types SET hp = 20000, maxdmg = 300 WHERE id = 76007;  -- Innoruuk classic
UPDATE npc_types SET hp = 14600 WHERE id = 76011;  -- Maestro of Rancor 16228 -> 14600 (minimal cut)
UPDATE npc_types SET hp = 20500 WHERE id IN (76017, 76042, 76043, 76044, 76045);  -- Hate Council 29305 -> 20500

-- Plane of Hate REVAMP (hateplaneb) — live layout; scale all 23+ bosses
UPDATE npc_types SET hp = 60000, maxdmg = 500 WHERE id = 186158;  -- Innoruuk revamp 100200 L70 -> 60k
UPDATE npc_types SET hp = 20000 WHERE id = 186154;  -- Lord of Ire 32k -> 20k
-- (23 rows in data-expert's implementation SQL)

-- Plane of Sky (30% cut; leave close-to-named bosses alone)
UPDATE npc_types SET hp = 22000 WHERE id = 71012;  -- Spiroc Lord 32k -> 22k
UPDATE npc_types SET hp = 22000 WHERE id = 71057;  -- Noble Dojorn 32k -> 22k
UPDATE npc_types SET hp = 20000 WHERE id = 71021;  -- Gorgalosk 29k -> 20k
UPDATE npc_types SET hp = 17000 WHERE id = 71032;  -- a_thunder_spirit_princess 20k -> 17k
UPDATE npc_types SET hp = 25600 WHERE id = 71065;  -- Eye of Veeshan 32k -> 25.6k
UPDATE npc_types SET hp = 22000 WHERE id = 71075;  -- Keeper of Souls 32k -> 22k
UPDATE npc_types SET hp = 22000, maxdmg = 700 WHERE id = 71072;  -- Bazzt Zzzt 32k -> 22k, cap 941 -> 700
-- Q13 PoSky additions
UPDATE npc_types SET hp = 22000 WHERE id = 71034;  -- Overseer of Air 32k -> 22k
UPDATE npc_types SET hp = 17000 WHERE id = 71059;  -- Protector of Sky 21400 -> 17000
UPDATE npc_types SET hp = 22000 WHERE id = 71060;  -- Hand of Veeshan 32k -> 22k
UPDATE npc_types SET hp = 12000 WHERE id = 71076;  -- Sister of Spire 17k -> 12k
-- Note 71071 (essence tamer): leave HP alone, already 11500 (near-named)

-- Misc Classic
UPDATE npc_types SET hp = 26000 WHERE id = 91090;  -- Zordakalicus 33k -> 26k
UPDATE npc_types SET hp = 25000 WHERE id = 48041;  -- Thul Tae Ew HP 50k -> 25k
UPDATE npc_types SET hp = 87000 WHERE id = 39115;  -- Guardian of Seal 124k -> 87k (30% cut)

-- Kithicor Night Crew (20% cut)
UPDATE npc_types SET hp = 14400 WHERE id = 20054;  -- 18k -> 14.4k
UPDATE npc_types SET hp = 16000 WHERE id = 20055;  -- 20k -> 16k
-- ... (6 NPCs)
```

**Per-boss respawn (6h universal for Classic low-tier; 12h for Cazic Thule):**

```sql
-- All Classic raid bosses: 6h respawn (21600s). Do a JOIN-based UPDATE scoped by NPC ID list.
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
JOIN npc_types nt ON nt.id = se.npcID
SET s2.respawntime = 21600
WHERE nt.id IN (
    32040, 73057, 64001,                                       -- Nagafen, Vox, Phinigel
    72000, 72002, 72004, 72001, 72012, 72090,                  -- PoFear (excluding CT)
    76007, 76011, 76015,                                       -- PoH classic gods
    76017, 76042, 76043, 76044, 76045, 76018,                  -- PoH council
    71012, 71057, 71021, 71032, 71065,                         -- PoSky with spawnentry
    91090, 48041
);

-- Cazic Thule only: 12h per PRD (5-tier decision: endgame adjacent)
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
JOIN npc_types nt ON nt.id = se.npcID
SET s2.respawntime = 43200
WHERE nt.id = 72003;

-- Guardian of the Seal 12h (70-level boss, mid tier)
UPDATE spawn2 s2 ... SET s2.respawntime = 43200 WHERE nt.id = 39115;

-- Wraith of Shissar is an oddball at 210924s — normalize to 21600
-- hateplaneb bosses: most already at 900s (DZ) — leave; the 194,400s and 70,308s outliers cut to 21600
```

**Death-touch removal (3 rows):**

```sql
DELETE FROM npc_spells_entries
WHERE npc_spells_id IN (118, 449, 969)
  AND spellid = 982;  -- Cazic Touch (-100,000 HP single-target instant kill)
-- Other spell_list entries (988 Greater Spiroc Thunder, 897 Rotting Flesh, 899 Whirl)
-- remain — those are survivable AE/DOT effects that define boss identity.
```

### Code Changes

No code changes. Zero files modified in `eqemu/`, `akk-stack/server/quests/`, or `akk-stack/npc-llm-sidecar/`.

### Configuration Changes

No `rule_values` changes. No `eqemu_config.json` changes. No `.env` changes.

### Database Changes

| File path | Type | Rows affected (approx) |
|-----------|------|------------------------|
| `npc_types_backup_raid_scaling` | CREATE TABLE | 750 rows snapshot |
| `spawn2_backup_raid_scaling` | CREATE TABLE | 1500 rows snapshot |
| `npc_spells_entries_backup_raid_scaling` | CREATE TABLE | ~20 rows snapshot |
| `npc_types` | UPDATE | ~55 rows (30 audit-listed + 13 Q13 additions + 23 hateplaneb bosses, minus double-counts) |
| `spawn2` | UPDATE | ~40 rows (non-triggered bosses only; DZ-spawned bosses have no spawn2 entry) |
| `npc_spells_entries` | DELETE | 3 rows |

Data-expert should produce a single SQL reference document at
`data-expert/context/phase2-classic-implementation.sql` with:
1. Backup table creates first.
2. All UPDATEs and DELETE ordered by zone cluster.
3. Post-change verification queries (assert HP bounds, count changed rows).
4. Full rollback script using backup tables.

---

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Build backup tables for `npc_types`, `spawn2`, `npc_spells_entries` raid-target rows; emit SQL reference doc structure | data-expert | — | ~1h (3 CREATE TABLE AS statements + sanity count verification) |
| 2 | Emit per-boss HP/damage/special_abilities UPDATE SQL for all 30 audit bosses + 13 Q13 additions + 23 hateplaneb bosses; cross-check with audit summary table; commit to `data-expert/context/phase2-classic-implementation.sql` | data-expert | 1 | ~2h (mostly translating audit targets to UPDATE rows) |
| 3 | Emit respawn-timer UPDATE SQL for all Classic raid-boss spawn2 rows (6h low / 12h CT & Guardian of Seal); verify hateplaneb DZ bosses are left alone at 900s | data-expert | 1 | ~45m |
| 4 | Emit `npc_spells_entries` DELETE for Cazic Touch (spell 982) from spell lists 118, 449, 969; include verification query to confirm exactly 3 rows deleted | data-expert | 1 | ~15m |
| 5 | Emit rollback script (INSERT ... SELECT from backup tables, wrapped in a transaction) + verification queries comparing row counts before/after | data-expert | 2,3,4 | ~30m |
| 6 | Apply all SQL changes via `docker exec akk-stack-mariadb-1 mysql -ueqemu -p'...' peq < phase2-classic-implementation.sql`; capture before/after row counts and diff stats | data-expert | 5 | ~15m execution + logs |
| 7 | `#reloadworld` in-game (or Spire restart) so zone processes re-load modified `npc_types`, `npc_spells_entries`, and `spawn2` caches | config-expert | 6 | ~5m |
| 8 | Smoke verification: run SQL queries confirming Nagafen HP, Cazic Thule rampage string, Keeper of Souls spell list, and a hateplaneb boss each match target values; document findings in config-expert notes | config-expert | 7 | ~30m |
| 9 | If server needs full restart (ninja build not required since no C++ change, but zone processes must re-read DB on boot if #reloadworld is incomplete), run the standard full-stack startup sequence from MEMORY.md | infra-expert | 8 (conditional) | ~10m if needed |
| 10 | Commit + push all changed files in `claude/` repo (architecture doc, context files, status updates, implementation SQL reference) to `feature/raid-scaling` branch; no eqemu/ or akk-stack/ commits needed since only data-layer modified | data-expert | 6 | ~10m |

**Critical ordering constraint:** Task 1 (backup tables) MUST complete before Tasks 2-4. Task 6 (apply) MUST happen after 1-5 review. Task 7 (reload) is required before game-tester can validate.

**Tasks NOT required:**
- lua-expert: no quest script changes.
- perl-expert: no quest script changes.
- c-expert: no C++ changes.
- protocol-agent: already advised in Phase 3; no implementation role.

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| A raid boss NPC ID is used by an active quest script that depends on the old HP threshold (e.g., `event_hp` with percentage triggers) | Low | Medium | HP % thresholds (50%, 25%) scale proportionally with max HP; absolute-HP checks in scripts are rare. If discovered post-deploy, rollback via backup table. Lua `event_hp(e)` uses `eq.set_next_hp_event(50)` style (percentage) in the PoFear/PoSky/Cazic scripts we audited. |
| `special_abilities` string edit for Cazic Thule corrupts other ability params if REPLACE string happens to match elsewhere | Low | High | Use exact-substring REPLACE (`'3,1,10'` → `'3,1,3'`) against the known current string `1,1^2,1^3,1,10^7,...`. data-expert must include an assertion query: `SELECT special_abilities FROM npc_types WHERE id=72003` post-change to verify pattern. Alternative: full-string explicit write. |
| `hateplaneb` DZ-based bosses have `spawn2.respawntime = 900s` — cutting further could create encounter loops | None | N/A | Leave DZ timers alone. JOIN-based respawn UPDATE is scoped to bosses with respawntime > 21600. |
| Q13 triggered NPCs (e.g. Enraged Golem 72106) have no spawn2 row — respawn UPDATE silently skips them | Medium | Low | This is intended: their spawn is script-controlled from a PH (`a_broken_golem` 72074). Their HP/damage UPDATE still applies to npc_types and takes effect on next script spawn. |
| Backup tables occupy disk space (~0.5 MB) | Near zero | Nil | Accept; deletion is user-discretion after feature graduates. |
| A duplicate NPC ID variant (e.g. Innoruuk 76007 classic vs 186158 revamp) gets both changed, confusing a future investigator | Low | Low | Architecture doc explicitly calls out both; live-traffic is hateplaneb. Classic `hateplane` is dormant but updated to same scale for future-proofing. Backup captures both. |
| `npc_spells_entries` DELETE affects a sibling NPC we didn't intend | None | Nil | Spell lists 118 (Spiroc Lord), 449 (Bazzt Zzzt), 969 (Keeper of Souls) are NPC-unique. Verified: `SELECT DISTINCT nt.id FROM npc_types nt WHERE nt.npc_spells_id IN (118, 449, 969)` returns exactly 3 rows. |

### Compatibility Risks

- **Prior-pass rule values remain authoritative.** None are changed, so regression risk is zero. Raid bosses will inherit the existing `NPCFlurryChance=12`, `MaxRampageTargets=2`, `NPCAssistCap=3` caps on top of the per-NPC changes.
- **Classic epic quest scripts (Perl legacy).** Checked — none of `fearplane/Cazic_Thule.lua`, `airplane/Noble_Dojorn.lua`, `soldungb/Lord_Nagafen.pl`, `permafrost/Lady_Vox.pl`, `airplane/The_Spiroc_Lord.lua`, `fearplane/a_dracoliche.lua`, `airplane/Keeper_of_Souls.lua`, `airplane/Bazzt_Zzzt.lua` reference the `npc_types.hp` or `spawn2.respawntime` values. They set `eq.set_next_hp_event(percent)` which scales automatically.
- **Companion AI.** Companions tuned against named-tier. Scaled raid bosses are "slightly harder than named" per Decision #1, still in companion capability range. Companion aggro/healing thresholds are percentage-based.
- **LLM NPC conversation sidecar.** No change: sidecar reads NPC context (name, level, faction) not stats. Out of scope.

### Performance Risks

- **Zero.** 58 UPDATEs + 3 DELETEs across a database that sees thousands of writes per minute under normal play. `npc_types` is read-at-zone-boot and cached; the change takes effect on next `#reloadworld` or zone boot. `spawn2.respawntime` is read when a spawn point fires its respawn timer.
- **No new indexes needed.** Queries hit existing PKs.
- **No opcode-layer impact** (verified by protocol-agent).

---

## Review Passes

### Pass 1: Feasibility

Every lever used is a well-established PEQ-standard mechanism:
- `npc_types.hp` UPDATEs → verified in prior pass (2026-02-23) across 30,000+ non-raid rows without incident.
- `spawn2.respawntime` UPDATEs → verified in prior pass.
- `npc_types.special_abilities` CSV edits → used by PEQ content editors (Spire) routinely.
- `npc_spells_entries` row DELETE → standard catalog operation; individual rows are keyed by (npc_spells_id, spellid).
- Backup table pattern → established by prior pass (`npc_types_backup_sgs`).

**Hardest part:** Cazic Thule's special_abilities CSV edit. The substring `3,1,10` might conflict with abilities where param0=3 followed by something else — but scanning the full CT string `1,1^2,1^3,1,10^7,1^10,1^12,1^13,1^14,1^15,1^16,1^17,1^21,1^23,1^31,1`, `3,1,10` appears exactly once (the rampage entry). A `REPLACE(..., '3,1,10^', '3,1,3^')` with the trailing `^` delimiter is bulletproof. Verified no other NPC uses this exact substring pattern with a different meaning.

**Confirmed feasibility:** all tasks executable by data-expert + config-expert in one session.

### Pass 2: Simplicity

**Challenge: Can we do less?**
- Could we skip the backup tables? No — Decision #11 preserves signature mechanics; if a preservation goal is missed post-deploy, rollback is essential.
- Could we batch all HP UPDATEs into a single statement with CASE? Possible, but per-row UPDATEs are the established prior-pass pattern — readability and selective rollback beats minor IO savings.
- Could we skip hateplaneb scaling and use classic hateplane instead? No — confirmed via `oasis/player.lua:4` that Titanium players actually get hateplaneb. Leaving hateplane dormant but backed up costs nothing.
- Could we skip the Kithicor Night Crew adjustment? Maybe. They're already at 12k-27k HP, 1.5-3× scaled-named tier. Audit recommended "minimal change, 10-20% HP cut". Phase 2 applies a 20% cut for consistency with the bulk. The alternative (leave as-is) is one decision line; architect choice is to include for uniformity.
- Could we defer death-touch removal? No — Decision #13 explicitly resolved this; four epics unblock with it (Necro, Ranger, Magician, Warrior).

**Removed / deferred:**
- Q8 (Coldain Ring War + Prayer Shawl): Velious — **deferred to Phase 4.**
- Xenevorash (Kunark), Renux Herkanor (Kunark), Vessel Drozlin (Kunark), SK-epic Caradon/Kyrenna/Mummy of Glohnor (Kunark SK epic), General V'ghera (Kithicor Rogue epic, 16k HP already in named tier): **all deferred.**
- Kunark `outdoor dragons` (Gorenaire, Severilous, Talendor, Faydedar), Trakanon, VS, all VP dragons, Chardok royals: **Phase 3.**

### Pass 3: Antagonistic — what could go wrong

1. **Cazic Touch removal creates an orphan cast attempt?** Spell 982 is the only "free-cast" instakill on these NPCs. After DELETE, their `AISpells_Struct` simply won't include it; `AICastSpell()` iterates what's present. No null-deref risk (luabind Lua binding for Mob spell list is read-only and guarded). Verified: `npc_spells_entries` DELETE is the intended removal path.

2. **Backup rollback failure mid-restore.** Mitigated by transactional rollback script; data-expert wraps the restore INSERT ... SELECT in `BEGIN/COMMIT`. Backup tables never drop until user approves feature.

3. **Player using a GM-only `#heal` or `#repopclose` on Cazic Thule DURING a scaling apply.** Not our concern — GMs have their own tooling; in the typical case the server is a few zone processes re-reading `npc_types` on `#reloadworld`. Apply SQL when server idle.

4. **Rampage param edit inadvertently zeros out CT's rampage entirely.** Substring `'3,1,10'` → `'3,1,3'` preserves ability 3 with value 1 and param 3 — verified by reparsing with `Mob::ProcessSpecialAbilities` format: `3,1,3` → ability=3 (Rampage), value=1 (on), param0=3 (target count). Correct.

5. **hateplaneb bosses at 900s respawn inside DZ are script-fire controlled.** Confirmed — `oasis/a_wayward_kiraikuei.lua` creates a 1-hour DZ instance; the 900s timers are intra-instance. Scaling HP inside them preserves DZ feel.

6. **Q13 NPC (e.g. Enraged Golem) HP change breaks Wizard epic trigger chain.** Enraged Golem spawns from `a_broken_golem` giveitem. The spawn script (if Lua) will spawn a new instance of NPC 72106 with whatever stats the DB row currently has — it won't encode "old HP value" anywhere. HP drop from 175k to 40k is transparent to the script.

7. **Hate Council mini-respawn (1440s = 24min in classic hateplane) should NOT be increased to 6h.** Confirmed — JOIN-based UPDATE is scoped by NPC ID list with explicit exclusion: Council IDs 76017, 76042-76045 are NOT in the respawn UPDATE list. Only their HP changes.

8. **Backup over-captures non-Phase-2 NPCs.** Intentional. Kunark/Velious/Luclin raid_target rows go into the same backup so Phase 3/4/5 rollback remains available. The WHERE clause uses `level BETWEEN 45 AND 70 AND name NOT LIKE '#The_Fabled%'` — safe superset.

9. **Essence tamer 71071 is NOT on the death-touch list (contrary to audit assumption).** Verified — its spell list npc_spells_id=212 contains only spell 303 "Whirl till you hurl" (effect 64 = throw/fling, not instant death). Lore-master referred to it as a "death touch" but the spell is actually survivable; it throws player high and damage comes from fall. Not in the Phase 2 spell-list DELETE. HP and damage scale still apply.

### Pass 4: Integration

**Task ordering is linear with one fork:**
```
1 (backups) ──> 2 (HP/damage SQL) ──> ┐
              ──> 3 (respawn SQL) ──── ┼──> 6 (apply) ──> 7 (reload) ──> 8 (verify) ──> 10 (commit)
              ──> 4 (death-touch SQL) ─┘
              ──> 5 (rollback SQL) ────┘ (needed at apply time)
```

- Tasks 2, 3, 4, 5 can be done in parallel by data-expert in the same session (they're four separate SQL blocks in the same implementation document).
- Task 7 (config-expert `#reloadworld`) is required before smoke verification.
- Task 9 (infra-expert full-stack restart) is ONLY needed if `#reloadworld` fails to pick up `npc_spells_entries` cache changes — which it should. Zone processes' `NPC::AICastSpell()` reads from the in-memory spell list populated at NPC spawn; `#reloadworld` rebuilds this.
- Task 10 (commit) closes Phase 2. Phase 3 (Kunark) would follow as its own architecture pass.

**Single point of contention:** Task 7 requires Spire/console access to send `#reloadworld`. If config-expert doesn't have this, escalate to infra-expert immediately (add cross-link in implementation SQL doc).

**Cross-agent dependencies all resolved:**
- game-designer (PRD + audit): inputs consumed.
- lore-master (Classic epics catalog): inputs consumed; identified Q13 gaps now resolved via DB.
- protocol-agent: confirmed zero client-visible changes.
- config-expert: confirmed no rule changes needed; corrected on death-touch mechanism.
- game-tester: will receive validation hooks below.

---

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| data-expert | 1, 2, 3, 4, 5, 6, 10 | Owns all SQL emission, backup creation, apply, and commit. Solo agent for the bulk of the work. |
| config-expert | 7, 8 | `#reloadworld` execution and post-change smoke verification. Confirmed in Architecture Team Conversations as the reload role. |
| infra-expert | 9 (conditional) | Only if `#reloadworld` fails to propagate changes; then runs MEMORY.md full-stack restart. |

**Agents NOT needed:** c-expert, lua-expert, perl-expert, protocol-agent (already advised).

---

## Validation Plan

_game-tester should verify each of the following after the implementation team completes Tasks 1-10:_

- [ ] **Backup tables exist and are populated.**
  ```sql
  SELECT COUNT(*) FROM npc_types_backup_raid_scaling; -- expect ~750
  SELECT COUNT(*) FROM spawn2_backup_raid_scaling;    -- expect ~1500
  SELECT COUNT(*) FROM npc_spells_entries_backup_raid_scaling; -- expect ~20
  ```
- [ ] **Lord Nagafen HP at target.** `SELECT hp FROM npc_types WHERE id=32040` returns 14400 (was 32000).
- [ ] **Cazic Thule HP and rampage trimmed.** `SELECT hp, maxdmg, special_abilities FROM npc_types WHERE id=72003` returns hp=80000, maxdmg=450, special_abilities contains `3,1,3^` (rampage param 3, not 10).
- [ ] **Death-touch removed.** `SELECT COUNT(*) FROM npc_spells_entries WHERE npc_spells_id IN (118,449,969) AND spellid=982` returns 0.
- [ ] **Plane of Sky scaling.** `SELECT hp FROM npc_types WHERE id=71075` returns 22000 (was 32000).
- [ ] **hateplaneb Innoruuk scaled.** `SELECT hp, maxdmg FROM npc_types WHERE id=186158` returns hp=60000, maxdmg=500.
- [ ] **Respawn 6h for most Classic bosses.** `SELECT MIN(respawntime) FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID=s2.spawngroupID WHERE se.npcID=32040` returns 21600.
- [ ] **Cazic Thule respawn 12h.** Same query for id=72003 returns 43200.
- [ ] **In-game smoke test (1 player + 5 companions):**
  - Kill Lord Nagafen: completable in 1-3 attempts, signature summon/enrage still fires, not trivialized.
  - Zone into Plane of Sky, reach Island 4 (Keeper of Souls), engage: no instant kill; fight plays out as HP/damage encounter.
  - Zone into hateplaneb via Oasis door 20: Innoruuk final encounter beatable by companion party.
- [ ] **Rollback dry-run.** Using a backup copy on a scratch environment, restore from backup tables and verify `npc_types.hp` for one sample NPC matches pre-change value.
- [ ] **No regression on named mobs.** Spot-check 3 prior-pass-touched named NPCs in the same zones (e.g. Plane of Fear trash like `a_scareling` 72005, PoSky Island 1 `azarack` — should be untouched by Phase 2 since `raid_target=0`).
- [ ] **Quest scripts still fire.** Trigger `a_dracoliche` in PoFear (Cleric epic dependency) and verify `event_death` / loot drop chain proceeds (Cleric Soulfire quest item drops).

---

## Flagged items not in Phase 2 scope

The following are noted for future phases:

- **Q8 — Coldain Ring War + Prayer Shawl** (Velious). Defer to **Phase 4 architecture** (Velious non-ToV).
- **Xenevorash (Kunark Monk epic), Renux Herkanor (Kunark Steamfont Rogue epic), Vessel Drozlin (Cabilis East Enchanter), Caradon / Kyrenna / Mummy of Glohnor (The Hole SK epic), General V'ghera (Kithicor Rogue epic)**. Defer to **Phase 3 (Kunark)** architecture.
- **Thrackin Griften (W.Karana Enchanter epic)** — HP 7875 already in named tier; defer review to Phase 3.
- **71071 essence tamer** despite lore-master classification, is NOT a true death-touch encounter (spell 303 is a throw, not instant kill). Architecture notes this as resolved; no further action needed.

---

> **Next step:** Spawn the implementation team with ONLY:
> - **data-expert** (Tasks 1-6, 10)
> - **config-expert** (Tasks 7-8)
> - **infra-expert** (Task 9, conditional)
>
> Do NOT spawn c-expert, lua-expert, perl-expert, or protocol-agent — they have no Phase 2 work.
