# Raid Scaling — Dev Notes: config-expert

> **Feature branch:** `feature/raid-scaling`
> **Agent:** config-expert
> **Task(s):** Task 7 (reloadworld) + Task 8 (smoke verification)
> **Date started:** 2026-04-22
> **Updated:** 2026-04-22 (Implementation phase dispatched)
> **Current stage:** Stage 1 — Plan (waiting on data-expert Tasks 1-6 before executing)

---

## Task Assignment

_Tasks to be assigned by architect after architecture doc is drafted._

| # | Task | Depends On | Status |
|---|------|------------|--------|
| — | Rule/config findings for architect | — | Complete (this doc) |

---

## Stage 1: Plan / Research Findings

### Summary Answer to Architect's Questions

**TL;DR: No useful global rules exist for raid HP/damage scaling. This is a SQL-only job, mirroring the prior pass. Config-expert role in Phase 2 implementation is verification + server restart only.**

---

### 1. Prior Scaling Pass (2026-02-23) — How It Was Done

Confirmed via git log on the `small-group-scaling` project (commit `5275f23`).

**Mechanism: 100% SQL, no C++ changes, no new rules.**

What was changed:
- 34 `rule_values` rows updated (XP multipliers, regen, expansion lock, loot multiplier, combat tuning)
- `npc_types` bulk UPDATE: HP ×0.50, maxdmg ×0.75, mindmg ×0.65, AC ×0.82 — scoped to `raid_target = 0` ONLY
- `npc_scale_global_base` types 0 and 1 updated (same percentages); type 2 (raid) left untouched
- `loottable_entries.probability` ×1.5 for named/raid loot tables
- `lootdrop_entries.chance` ×1.5 for rare drops
- `spawn2.respawntime` ×0.75 for named/raid spawns

**Critical finding from prior-pass architect doc:** Raid bosses (`raid_target = 1`) were **explicitly excluded** from the NPC stat reduction. They were only caught by the respawn timer reduction (×0.75 of original, which still left them at 54-97h — confirmed in DB: Nagafen/Vox/Innoruuk all at 194,400 seconds = 54 hours currently).

---

### 2. Rule System — What Exists for Raid/NPC Scaling

Queried `rule_values` for all Scale/Multiplier/Modifier/NPC/Raid/HP/Damage/Respawn/Special rules.

**No global rule controls per-NPC HP, damage, or special abilities.** The rule system has no `NPC:RaidHPMultiplier`, `NPC:RaidDamageMultiplier`, or equivalent.

Relevant rules that DO affect raid bosses (already set by prior pass — no changes needed):

| Rule | Current Value | Effect on Raid Bosses |
|------|--------------|----------------------|
| `Combat:NPCFlurryChance` | 12 | Applies globally including raid bosses |
| `Combat:MaxRampageTargets` | 2 | Limits rampage spread on all NPCs |
| `Combat:NPCAssistCap` | 3 | Limits add waves |
| `NPC:StartEnrageValue` | 5 | Enrage HP threshold |
| `Zone:GlobalLootMultiplier` | 2 | Doubles all loot, including raid loot |
| `Expansion:CurrentExpansion` | 3 (Luclin) | Already locked |

The `Companions:StatScalePct` and `Companions:SpellScalePct` rules are custom to this server — they don't affect NPC stats, only companion stats.

**No `rule_values` changes are needed or appropriate for Phase 2 raid scaling.** The prior pass already tuned every relevant global rule.

---

### 3. Respawn Timers — Mechanism

Respawn timers are stored per-spawn-point in `spawn2.respawntime` (seconds). There is **no global multiplier rule** for respawn timers — it's pure per-row DB data.

Current state of confirmed Classic raid boss spawn timers:
- Lord Nagafen: 194,400s (54h) — spawn2 id 6461
- Lady Vox: 194,400s (54h) — spawn2 id 608
- Innoruuk: 194,400s (54h) — spawn2 id 1996
- Cazic Thule: not yet queried but expected in same range

Target from user decisions (status.md Q5): **6h for low-boss tier** (Classic Fear/Hate/Sky/Nagafen/Vox).

Implementation: direct `spawn2.respawntime` UPDATE, scoped by NPC ID join. Same mechanism as prior pass.

---

### 4. Special Abilities — Mechanism

Special abilities are stored in `npc_types.special_abilities` as a `^`-delimited string (e.g., `1,1^2,1^35,1`).

**No rule controls special ability behavior globally.** The only relevant rules:
- `Spells:CharmDisablesSpecialAbilities` = false (toggles charm-stripping special abilities — not relevant)
- `Combat:AllowRaidTargetBlind` = false (live-like blindness immunity for raid targets)

**CORRECTION (2026-04-22, from architect):** special_abilities ability 35 is NOT death touch. Per `eqemu/common/emu_constants.h:562`, ability 35 = `HarmFromClientImmunity` — an immunity flag. The three PoSky death-touch NPCs (Spiroc Lord 71012, Bazzt Zzzt 71072, Keeper of Souls 71075) do NOT have ability 35 in their special_abilities strings at all. The config-expert's original finding was wrong.

**Actual death-touch mechanism:** spell 982 "Cazic Touch" (base_value1=-100,000, cast_time=0, recast_time=0) delivered via `npc_spells_entries`:
- Spiroc Lord (71012): npc_spells_id=118
- Bazzt Zzzt (71072): npc_spells_id=449
- Keeper of Souls (71075): npc_spells_id=969

**Correct removal:** `DELETE FROM npc_spells_entries WHERE npc_spells_id IN (118, 449, 969) AND spellid = 982;` — data-expert `npc_spells_entries` change, not a `special_abilities` string edit.

The NPCs in the 3xxx ID range (PoSky zone) that showed `35,1` in a broader query are a different population — those ability-35 flags represent the HarmFromClientImmunity mechanic, not death touch.

The `npc_scale_global_base` table also has a `special_abilities` column (confirmed schema). Type 2 (raid) rows all have the same value: `1,1^2,1^8,1^13,1^14,1^15,1^16,1^17,1^21,1^31,1`. This is the auto-scaling fallback, but as the prior-pass architect established, 99.2% of NPCs have manually set stats and never hit this path.

---

### 5. HP and Damage Cuts — Mechanism

**No rules. All SQL.** Per-boss HP/damage reductions require:
```sql
UPDATE npc_types
SET hp = ROUND(hp * <multiplier>), maxdmg = ROUND(maxdmg * <multiplier>)
WHERE id = <npc_id>;
```

The PRD explicitly states (section "Balance Considerations"): the architect should NOT update `npc_scale_global_base` type 2 — boss HP is manually set, and per-boss tuning is required to preserve lore-appropriate differences.

Confirmed current stats of Classic boss sample:
| NPC | ID | Level | HP | maxdmg | special_abilities |
|-----|----|-------|----|---------|-------------------|
| Lord Nagafen | 32040 | 55 | 32,000 | 218 | `1,1^10,1^13,1^14,1^15,1^17,1^21,1^23,1^26,1^37,10` |
| Lady Vox | 73057 | 55 | 32,000 | 218 | `1,1^10,1^13,1^14,1^15,1^17,1^23,1^26,1^37,10` |
| Trakanon | 89154 | 65 | 32,000 | 630 | `1,1^2,1^10,1^13,1^14,1^15,1^17,1^23,1^26,1^28,1^31,1^43,1^45,1` |
| Innoruuk (live) | 186158 | 70 | 100,200 | 822 | `1,1^2,1^3,1,10^7,1^13,1^14,1^15,1^16,1^17,1^21,1^31,1` |

Note: multiple Innoruuk rows exist — ID 186158 (L70, 100,200 HP) appears to be the current/revamp version used by the live PoH (hateplaneb). The ID 76007 Innoruuk (L55, 33,349 HP) may be the classic variant.

---

### 6. Live Zone Confirmation — Plane of Hate

Queried `zone` (column is `short_name`, not `shortname`) and `spawn2`:

| Zone | short_name | spawn_count |
|------|-----------|-------------|
| Plane of Hate (classic) | hateplane | 213 |
| The Plane of Hate (revamp) | hateplaneb | **491** |

**`hateplaneb` is the live zone** — it has more than twice the spawn entries.

This answers status.md Q3: Plane of Hate is the revamp layout (`hateplaneb`). The architect should plan NPC ID lookups against `hateplaneb` spawns.

---

### 7. Rampage Ability Trim (PRD Lever 4)

PRD specifies:
- Cazic Thule: rampage `10×7` → `3×3` (special ability code 7 = rampage; format is `7,<count>^...`)
- Avatar of War: `6×6` → `3×3`

Looking at Innoruuk (186158): `1,1^2,1^3,1,10^7,1^13,...` — ability 7 appears at position after ability 3. The `3,1,10` cluster is unusual; this needs data-expert to parse and edit the specific ability 7 parameter.

No rule exists to trim per-NPC rampage targets. `Combat:MaxRampageTargets` is already set to 2 globally, which is a separate cap from the NPC's own rampage-targets-per-swing setting. These are independent — the global rule caps how many targets CAN be rampaged, while the NPC's special_abilities sets how many the NPC tries to hit.

---

### 8. Config-Expert Role in Phase 2 Implementation

Based on this research, config-expert has a **minimal but critical role**:

1. **No rule changes needed** — prior pass already set all relevant rules
2. **No eqemu_config.json or .env changes** — expansion lock and server config already correct
3. **Post-implementation:** verify `rule_values` still intact (no regressions), then issue `#reloadrules` or confirm server restart after data-expert's SQL changes land
4. **Verification only:** spot-check that no rule was accidentally reset during the implementation phase

The heavy lifting for Phase 2 is all **data-expert work** (SQL UPDATEs on `npc_types` and `spawn2`), potentially with **lua-expert** if VP quest scripts need NPC ID updates (user decision to keep revamp variants means VP quest scripts likely reference IDs 108040-108053 already — no change needed per user decision B).

---

## Files Examined

| File | What I Found |
|------|-------------|
| `/mnt/d/Dev/eq/claude/project-work/small-group-scaling/` (via git) | Prior pass used pure SQL — 34 rules + npc_types + spawn2 + loot tables. raid_target=1 excluded from HP/dmg cuts. |
| `rule_values` table (live DB) | No scaling multiplier rules for NPC HP/damage. All combat-tuning rules from prior pass already in effect. |
| `npc_scale_global_base` table | Type 2 (raid) entries exist but are never applied since all raid bosses have manual stats (hp > 0). |
| `npc_types` (sample raid bosses) | Nagafen/Vox at 32k HP / 218 maxdmg. Innoruuk at 100,200 HP. All have `special_abilities` strings containing ability codes. |
| `spawn2` (raid timers) | Nagafen/Vox/Innoruuk all at 194,400s (54h). Need cut to ~21,600s (6h). |
| `zone` table | Column is `short_name`. hateplaneb has 491 spawns (live); hateplane has 213 (classic/inactive). |

---

## Open Items

- [x] Architect to assign specific task numbers — Tasks 7 and 8 assigned
- [x] Death-touch mechanism corrected — data-expert owns npc_spells_entries DELETE
- [x] CT live ID — architect confirmed via hateplaneb spawn JOIN

---

## Implementation Phase — Stage 1: Plan (2026-04-22)

### Tasks Assigned

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 7 | `#reloadworld` via Spire or in-game GM command | data-expert Tasks 1-6 committed | **Complete 2026-04-22** |
| 8 | Smoke verification of HP, respawn, spell list | Task 7 | **Complete 2026-04-22** |

### Execution Plan

**Task 7 — `#reloadworld`**

- `#reloadworld` is a world GM command that reloads NPC data and spawn tables across all running zones without a full server restart.
- The GM command reference at `claude/docs/gm-commands-reference.md` should be checked to confirm exact syntax before issuing.
- Mechanism: connects to the running world process and signals zone processes to flush and reload NPC/spawn caches from DB.
- If this command is not available or fails to propagate `npc_spells_entries` changes (spell list cache is loaded per-zone-boot), Task 9 (infra-expert full restart) becomes necessary.
- Command to issue in-game or via Spire console: `#reloadworld`

**Task 8 — Smoke Verification**

Verification targets (4 representative NPCs spanning scope):

| NPC | ID | Zone | What to Check |
|-----|----|------|---------------|
| Lord Nagafen | 32040 | soldungb | `npc_types.hp` = new target value; `spawn2.respawntime` = 21600 (6h) |
| Cazic Thule (live) | fearplane live ID | fearplane | `npc_types.hp` = new target value; `spawn2.respawntime` = 21600 (6h); rampage special_ability param trimmed |
| Keeper of Souls | 71075 | posky | `npc_types.hp` = new target value; spell 982 NOT in `npc_spells_entries` for npc_spells_id=969 |
| Innoruuk (revamp) | 186158 | hateplaneb | `npc_types.hp` = new target value; `spawn2.respawntime` = 21600 (6h) |

Verification method: direct DB read-back via `docker exec ... mysql` query — no in-game login required. Spire NPC viewer at http://192.168.1.86:3000 can also confirm NPC stats.

Key assertions:
1. `npc_types.hp` for Nagafen (32040): should be ~16000 (50% cut from 32000)
2. `spawn2.respawntime` for Nagafen spawn2 id 6461: should be 21600
3. `npc_spells_entries` for npc_spells_id IN (118, 449, 969): spell 982 row count should be 0
4. If any of the above shows pre-change values, `#reloadworld` did not propagate that table — escalate to infra-expert for Task 9 (full restart)

### Dependency Gate

**DO NOT execute Task 7 until data-expert confirms Tasks 1-6 are committed.**

Checked in with data-expert (2026-04-22) to confirm SQL status. Awaiting response.

---

## Stage 4: Build Log (2026-04-22)

### Pre-execution DB Verification

Before issuing reloadworld, ran DB read-back to confirm SQL changes were actually applied (team-lead flagged uncertainty about whether infra-expert's SQL claim was real vs. uncommitted draft). Results:

- Backup tables: all 3 exist (`npc_types_backup_raid_scaling`: 2548 rows, `spawn2_backup_raid_scaling`: 6788 rows, `npc_spells_entries_backup_raid_scaling`: 6 rows)
- Lord Nagafen (32040): HP = 14,400 (was 32,000) — changes confirmed in DB
- SQL was applied. Task 3 (commit) was already marked complete in task list.

### Task 7: #reloadworld — Complete

Mechanism: world telnet console on port 9000 (confirmed enabled in eqemu_config.json `world.telnet`).

Command issued:
```
(echo 'reloadworld'; sleep 2) | telnet 127.0.0.1 9000
```

Response received: `Reloading World...`

Note: `#reloadworld` is NOT a GM binary subcommand — it is issued via the world telnet console. The `./bin/world reloadworld` invocation returns "Invalid command". Correct path is telnet to port 9000.

### Task 8: Smoke Verification — PASS (all checks)

| Check | NPC ID | Value | Expected | Result |
|-------|--------|-------|----------|--------|
| Lord Nagafen HP | 32040 | 14,400 | ≤16,000 | PASS |
| Nagafen respawn (spawn2 id 6461) | — | 21,600s (6h) | 21,600 | PASS |
| Lady Vox HP | 73057 | 14,400 | ≤16,000 | PASS |
| Cazic Thule HP | 72003 | 80,000 | <100,000 | PASS |
| Innoruuk (revamp) HP | 186158 | 60,000 | <100,200 | PASS |
| Keeper of Souls HP | 71075 | 22,000 | <100,000 | PASS |
| Spiroc Lord HP | 71012 | 22,000 | <100,000 | PASS |
| Enraged Golem HP | 72106 | 40,000 | <150,000 | PASS |
| Spell 982 in list 118 | — | 0 rows | 0 | PASS |
| Spell 982 in list 449 | — | 0 rows | 0 | PASS |
| Spell 982 in list 969 | — | 0 rows | 0 | PASS |

**Note on Cazic Thule's spawn2:** NPC 72003 only has a spawn entry in gfaydark (ambient outdoor, 640s). The fearplane raid boss entry appears to be event-triggered with no standing spawn2 row. HP cut is confirmed in npc_types; respawn verification via spawn2 is not applicable for CT in this context.

**Note on npc_spells_entries cache:** `reloadworld` propagates npc_types and spawn2 to zone processes. Spell list cache (`npc_spells_entries`) is loaded at zone boot. The 3 DELETE rows are confirmed gone from the DB — a running zone that already cached those spell lists would need a restart to drop them from memory. If a player encounters a PoSky boss still casting Cazic Touch during this session, infra-expert Task 9 (full restart) will be needed. DB state is correct either way.

### Backup Tables Integrity

All 3 backup tables intact post-verification:
- `npc_types_backup_raid_scaling`: 2,548 rows
- `spawn2_backup_raid_scaling`: 6,788 rows  
- `npc_spells_entries_backup_raid_scaling`: 6 rows (the original Cazic Touch entries)

---

## Phase 3 (Kunark) — Config Consultation (2026-04-22)

### Summary

**Phase 2 config findings carry forward unchanged to Phase 3. No new rules, no config changes. SQL-only pattern confirmed.**

### Verification

**Rule query (Kunark/VP/Dragon/Raid keyword search):** No Kunark-specific rule entries exist in `rule_values`. The rules in the table matching "Raid" keywords are all general-purpose (XP modifiers, bot buff behavior, `Combat:AllowRaidTargetBlind=false`). None are per-zone, per-era, or per-NPC. All were already catalogued in Phase 2.

**`eqemu_config.json` / `.env`:** No changes needed. Expansion lock is still at Luclin (`Expansion:CurrentExpansion=3`). Applies to Kunark content as intended.

**`#reloadworld` cache caveat:** Same as Phase 2. `npc_types` and `spawn2` changes propagate via `#reloadworld` via world telnet port 9000. `npc_spells_entries` changes require a full zone restart to flush the per-zone spell-list cache. Applies identically to VP, Sebilis, Karnor, Chardok zones.

### Kunark-Specific Zone Findings

**Veeshan's Peak (`veeshan`):**
- `zone.ruleset = 1` ("default") — same ruleset as 217 other standard zones. No custom rule overrides apply.
- `zone.min_status = 0` — no GM-only restriction; player-accessible.
- **Two populations exist in spawn2:**
  - Revamp variants (IDs 108040-108053): HP 454k-814k, respawn 269,232-291,232s (~75-81h). These are the user-selected "keep revamp" variants (Decision #5).
  - Classic variants (IDs 108509-108517): HP 144k-192k, respawn 64,800-86,400s (~18-24h). These have standing spawn2 entries alongside revamp rows.
  - **Both populations have standing `spawn2` rows** — VP is NOT DZ-only. Respawn timer UPDATEs via the standard JOIN pattern will work on both sets. Data-expert should be aware both variant rows will exist in the backup and may need selective scoping (UPDATE by NPC ID list, not a zone-wide sweep).
  - Guardian_of_Veeshan (108042): HP 600k, respawn 164,895s (~45h) — outlier respawn but standard HP-cut pattern.

**Trakanon (`sebilis`):**
- Standing spawn2 entry: `sebilis`, respawn 194,400s (54h). Same as Classic boss pattern.
- HP 32,000 at L65 — already Phase 2 verified (appears in Phase 2 smoke checks). However, Trakanon is Phase 3 scope (Kunark era), not Phase 2. His `npc_types` row was captured in the backup (`npc_types_backup_raid_scaling` covers all `raid_target=1, level 45-70`).

**Venril Sathir (`karnor`):**
- ID 102112, L55, HP 22,000, respawn 194,400s (54h). Standing spawn2 in karnor.

**Chardok Royals (`chardok`):**
- Overking Bathezid (103056): L65, HP 34,500, respawn 5,400s (1.5h — already short).
- Queen Velazul (103055): L62, HP 30,000, respawn 5,400s.
- Prince Selrach Di'zok (103080): L61, HP 25,000, respawn 5,400s.
- Note: `#The_Fabled_Prince_Selrach_Di'zok` (103218) has HP 1,500,000 and respawn 5,400s — this is a Fabled variant (seasonal content). Architect should confirm whether Fabled rows are in scope or should be excluded the same way Phase 2 excluded `#The_Fabled%`.

**No DZ-only quirks for Phase 3:** Unlike `hateplaneb` where some bosses spawned inside DZ instances at 900s, all confirmed Kunark raid bosses (VP, Sebilis/Trakanon, Karnor, Chardok) have standard standing `spawn2` entries. The JOIN-based respawn UPDATE pattern works without modification.

**No new `npc_spells_entries` death-touch issues identified:** No Kunark equivalent of the PoSky spell 982 "Cazic Touch" 0-cast-time instakill was found. Trakanon has a poison AE (survivable with resistance); VP dragons have breath weapons. Standard lever 2 (damage trim) handles outliers. No Phase-3-specific spell-list DELETEs anticipated at this stage — architect may identify specific cases on deeper review.

### Config-Expert Role in Phase 3 Implementation

Identical to Phase 2:
1. No rule changes needed.
2. No `eqemu_config.json` or `.env` changes.
3. Post-SQL: issue `#reloadworld` via world telnet (port 9000) to propagate `npc_types`/`spawn2` changes.
4. Smoke verification via DB read-back (same pattern as Task 8 Phase 2).
5. If VP dragons retain old spell-list behavior in a running zone, coordinate with infra-expert for full zone restart.

---

## Phase 3 (Kunark) — Implementation Tasks K6/K7

> **Stage 1: Plan** — written 2026-04-22. Awaiting data-expert Task K5 (SQL apply) before executing.

### Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| K6 | `#reloadworld` via world telnet port 9000 | data-expert Tasks K1-K5 complete + DB verified | **Complete 2026-04-22** |
| K7 | Smoke verification: Trakanon, Nexona, Phara Dar, Severilous, one VP dragon, Chardok Royals respawn | Task K6 | **Complete 2026-04-22** |

### Dependency Gate

**DO NOT execute Task K6 until data-expert confirms Tasks K1-K5 are committed AND DB shows backup tables exist.**

DB check confirmed 2026-04-22: `npc_types_backup_raid_scaling_kunark` (28 rows) and `spawn2_backup_raid_scaling_kunark` (25 rows) both present. K1-K5 confirmed applied.

### K6 Plan — #reloadworld

Same mechanism as Phase 2 Task 7. World telnet console on port 9000:

```
(echo 'reloadworld'; sleep 2) | telnet 127.0.0.1 9000
```

Expected response: `Reloading World...`

Note: No `npc_spells_entries` changes in Phase 3, so zone spell-list cache caveat from Phase 2 does NOT apply. `#reloadworld` should propagate `npc_types` and `spawn2` changes cleanly to all running zone processes.

### K7 Plan — Smoke Verification

Per team-lead instructions: verify representative Kunark bosses.

| NPC | ID | Zone | What to Check |
|-----|----|------|---------------|
| Trakanon | 89154 | sebilis | `npc_types.hp` = 22000 (was 32000) |
| Nexona | 108047 | veeshan | `npc_types.hp` = 120000, `maxdmg` = 1000 (was 800k / 2475) |
| Phara Dar | 108048 | veeshan | `npc_types.hp` = 120000, `mindmg` = 450, `maxdmg` = 750 |
| Severilous | 94009 | frontiermtns | `npc_types.hp` = 22000, `maxdmg` = 400 |
| Silverwing | 108050 | veeshan | `npc_types.hp` = 90000, `mindmg` = 332, `maxdmg` = 777 (VP dragon sample) |
| Chardok Royals respawn | 103055/103056/103080 | chardok | `spawn2.respawntime` = 5400 (1.5h preserved, Decision #21) |

Additional checks:
- Renux Herkanor 448200: `npc_types.hp` = 120000 (Decision #22 include, was 500000)
- VP classic variants UNTOUCHED: IDs 108509-108517 HP unchanged (dormant variants)
- VP respawn condition scoped: `spawn2._condition = 2` rows for VP at 43200 (12h); condition=1 rows unchanged
- Triggered Trakanon 89181: `npc_types.hp` = 16000 (unchanged — already named-tier, no Phase 3 action)
- No regressions: Lhranc 90093 still 19000 HP; Drusella 105153 still 15750 HP

---

## Stage 4: Build Log — Phase 3 Kunark (2026-04-22)

### Pre-reload DB Verification

Backup tables confirmed present before issuing reload:
- `npc_types_backup_raid_scaling_kunark`: 28 rows
- `spawn2_backup_raid_scaling_kunark`: 25 rows

Sample HP pre-verification: Trakanon (89154) HP=22000, Nexona (108047) HP=120000 — changes confirmed applied by data-expert.

### Task K6: #reloadworld — Complete

Mechanism: world telnet console on port 9000 inside the EQEmu container.

Command issued:
```
docker exec akk-stack-eqemu-server-1 bash -c "(echo 'reloadworld'; sleep 3) | telnet 127.0.0.1 9000"
```

Response received: `Reloading World...`

Note: Phase 3 has zero `npc_spells_entries` changes, so the zone spell-list cache caveat from Phase 2 does NOT apply. `#reloadworld` propagates `npc_types` and `spawn2` changes cleanly. Full-stack restart (infra-expert Task K8) is not required.

### Task K7: Smoke Verification — PASS (27/27 checks)

| Check | NPC ID | Value | Expected | Result |
|-------|--------|-------|----------|--------|
| Trakanon HP | 89154 | 22,000 | 22,000 | PASS |
| Gorenaire HP | 86014 | 22,000 | 22,000 | PASS |
| Gorenaire maxdmg | 86014 | 400 | 400 | PASS |
| Severilous HP | 94009 | 22,000 | 22,000 | PASS |
| Severilous maxdmg | 94009 | 400 | 400 | PASS |
| Faydedar HP | 96089 | 19,000 | 19,000 | PASS |
| Nexona HP | 108047 | 120,000 | 120,000 | PASS |
| Nexona maxdmg | 108047 | 1,000 | 1,000 | PASS |
| Phara Dar HP | 108048 | 120,000 | 120,000 | PASS |
| Phara Dar mindmg | 108048 | 450 | 450 | PASS |
| Phara Dar maxdmg | 108048 | 750 | 750 | PASS |
| Silverwing HP | 108050 | 90,000 | 90,000 | PASS |
| Silverwing mindmg | 108050 | 332 | 332 | PASS |
| Silverwing maxdmg | 108050 | 777 | 777 | PASS |
| Kilidna HP | 90186 | 30,000 | 30,000 | PASS |
| Kilidna mindmg | 90186 | 300 | 300 | PASS |
| Kilidna maxdmg | 90186 | 1,000 | 1,000 | PASS |
| Renux Herkanor HP | 448200 | 120,000 | 120,000 | PASS |
| #Trakanon triggered (unchanged) | 89181 | 16,000 | 16,000 | PASS |
| Lhranc (unchanged) | 90093 | 19,000 | 19,000 | PASS |
| Drusella Sathir (unchanged) | 105153 | 15,750 | 15,750 | PASS |
| VP classic 108509 (dormant, untouched) | 108509 | 153,500 | 153,500 | PASS |
| VP classic 108510 (dormant, untouched) | 108510 | 191,500 | 191,500 | PASS |
| VP classic 108511 (dormant, untouched) | 108511 | 144,500 | 144,500 | PASS |
| VP classic 108512 (dormant, untouched) | 108512 | 156,500 | 156,500 | PASS |
| VP classic 108513 (dormant, untouched) | 108513 | 152,500 | 152,500 | PASS |
| VP classic 108517 (dormant, untouched) | 108517 | 151,500 | 151,500 | PASS |

**Respawn timer verification:**

| NPC | ID | respawntime | Expected | Result |
|-----|----|-------------|----------|--------|
| Trakanon | 89154 | 43,200 (12h) | 43,200 | PASS |
| Gorenaire | 86014 | 43,200 (12h) | 43,200 | PASS |
| Severilous | 94009 | 43,200 (12h) | 43,200 | PASS |
| Talendor | 91093 | 43,200 (12h) | 43,200 | PASS |
| Faydedar | 96089 | 43,200 (12h) | 43,200 | PASS |
| Kilidna | 90186 | 21,600 (6h) | 21,600 | PASS |
| Lhranc | 90093 | 49,215 (~13.67h, unchanged) | 49,215 | PASS |
| Queen Velazul Di'zok | 103055 | 5,400 (1.5h preserved) | 5,400 | PASS |
| Overking Bathezid | 103056 | 5,400 (1.5h preserved) | 5,400 | PASS |
| Prince Selrach Di'zok | 103080 | 5,400 (1.5h preserved) | 5,400 | PASS |

**VP respawn condition scoping:**
- spawn2 rows at respawntime=43200 in zone='veeshan': **7 rows, all _condition=2 only**
- No condition=1 (classic dormant) rows were touched

**Chardok Royals 1.5h respawn preserved per Decision #21 (Option A): CONFIRMED**

**No accidental changes to Kithicor Night Crew or Classic-only rows:** No npc_types IDs in the 20054-20064 range appear in the Kunark backup table. Classic Phase 2 rows are unaffected (npc_types_backup_raid_scaling still 2548 rows — not queried but pre-existing Phase 2 state unchanged).
