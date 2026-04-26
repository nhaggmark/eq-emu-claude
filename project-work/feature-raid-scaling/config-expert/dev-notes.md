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

---

## Phase 4a (Velious Non-ToV) — Config Consultation (2026-04-22)

### Summary

**Phase 2/3 config findings carry forward unchanged to Phase 4a. No new rules exist for Velious content. No eqemu_config.json or .env changes needed. SQL is the mechanism. The #reloadworld/telnet pattern and npc_spells_entries zone-restart caveat are identical.**

### Rule Query Results

No Velious-specific, Coldain-specific, Ring War-specific, or zone-event-specific rules exist in `rule_values`. Queried for keywords: Ring, Wave, Growth, Mischief, Velious, Coldain, Event, Script, Spawn. Zero matches relevant to raid scaling or scripted event behavior. All combat-tuning rules from Phase 2 remain in effect unchanged.

### Zone Table Findings — All Velious Non-ToV Zones

All Velious non-ToV zones (`kael`, `skyshrine`, `growthplane`, `mischiefplane`, `westwastes`, `eastwastes`, `sleeper`, `templeveeshan`) have:
- `ruleset = 1` (default ruleset, same as all standard zones)
- `min_status = 0` (player-accessible, no GM restriction)
- `expansion = 2` (Velious)

**No Velious zone has a custom ruleset override.** Plane of Mischief and Plane of Growth are standard zones from a ruleset perspective — no special global rule governs their mob behavior.

### Velious Non-ToV Raid Boss NPC Stats (Key Samples)

| Zone | NPC | ID | Level | HP | maxdmg | mindmg | respawn |
|------|-----|----|-------|----|---------|--------|---------|
| kael | King Tormax | 113215 | 70 | 452,000 | 575 | 195 | 259,200s (72h) |
| kael | Derakor the Vindicator | 113118 | 70 | 180,000 | 700 | 225 | 43,200s (12h) |
| kael | Statue of Rallos Zek | 113071 | 59 | 400,750 | 1,100 | 245 | 194,400s (54h) |
| skyshrine | Lord Yelinak | 114106 | 70 | 500,000 | 804 | 204 | 259,200s (72h) |
| skyshrine | Lord Yelinak (alt) | 114618 | 70 | 297,000 | 804 | 204 | 259,200s (72h) |
| westwastes | Sontalak | 120005 | 70 | 97,500 | 425 | 140 | 259,200s (72h) |
| westwastes | Klandicar | 120084 | 70 | 97,500 | 540 | 198 | 259,200s (72h) |
| westwastes | Sir Elmonious Falmont | 120133 | 70 | 400,000 | 3,667 | 500 | 7,200s (2h) |
| growthplane | Tunare | 127001 | 66 | 530,000 | 926 | 166 | 259,200s (72h) |
| growthplane | Guardian of Tunare | 127007 | 60 | 310,000 | 187 | 92 | 64,800s (18h) |
| mischiefplane | Bristlebane | 126160 | 75 | 1,000,000 | 1,904 | 680 | 345,600s (96h) |
| mischiefplane | All-Seeing Eye | 126374 | 75 | 709,000 | 1,300 | 350 | 1,200s (20min — likely event-triggered) |
| mischiefplane | Mischievous Jester | 126012 | 70 | 200,000 | 1,431 | 235 | 281,232s (78h) |
| sleeper | Warder bosses (x4) | 128090-128093 | 70 | 200,000 | 405-509 | 115-137 | 259,200s (72h) |
| sleeper | Kildrukaun et al. (x4) | 128041-128044 | 70 | 352,000-377,000 | 705-929 | 284-372 | 259,200s (72h) |
| eastwastes | An Egg Hunter | 116605 | 75 | 981,589 | 2,222 | 1,048 | 640s (ambient — event target) |
| eastwastes | A Legendary Velious Dragon | 116607 | 72 | 312,500 | 1,504 | 225 | 10,800s (3h) |

**Notable outlier:** Bristlebane has 1M HP and 96h respawn — extreme values. Sir Elmonious Falmont has 3,667 maxdmg at 70 — very high. Both are architect decisions.

**Lord Yelinak dupe:** Two rows for Lord Yelinak in skyshrine (IDs 114106 and 114618, HP 500k vs 297k). Data-expert will need to scope correctly.

**Plane of Growth population note:** PoG has 80+ raid_target=1 entries, most at 64,800s (18h) respawn and 16k-310k HP. The majority are trash-tier named mobs (feral amalgams, gale wolves, rolling plains steeds) at 16-30k HP — these are NOT boss-tier. Architect should tier these carefully: Tunare and Guardian of Tunare are true bosses; the rest are named trash.

**Sleeper's Tomb note:** Many sleeper NPCs (IDs 128057-128088) have `name = Area8mob6dead`, `hp=11`, `raid_target=1` — these are scripted event placeholder/dead-body NPCs. They should be explicitly excluded from any HP/damage UPDATE. Any `raid_target=1` sweep on `sleeper` must exclude NPC IDs with hp <= 100 or names matching `Area%dead`, `StaticShout%`, `A_warning`, `Area%starter`.

### Coldain Ring War — Scripted Event Analysis

The 10th Ring War is implemented in `akk-stack/server/quests/greatdivide/encounters/ring_war.lua`.

**Architecture:**
- 13 waves of Kromrif mobs, each terminated by a WaveMaster (Captain 118130, General 118120, Warlord 118158)
- Wave timer controlled by `ringtenmaster` NPC (ID 118173) which receives signals from WaveMaster deaths
- The master NPC has special_abilities `19,1^20,1^24,1` (immune to flee, spell control, taunt) — a pure script controller, non-combat

**Globally-tunable parameters:**
- **Wave cooldown:** `local wave_cooldown_time = 5 * 60 * 1000` — 5 minutes hardcoded in Lua. This is the inter-wave delay. **Not a rule, not a DB column.** Changing it requires editing the Lua script (`ring_war.lua:26`).
- **Wave count:** 13 combat waves + Narandi (wave 14). Controlled by `spawn_condition` values 3-16 in `greatdivide`. Not a rule.

**Config/rule implication:** There are NO globally-tunable parameters (rules, eqemu_config.json entries, DB columns) controlling Ring War wave counts, timers, or Narandi's behavior. Any tuning requires lua-expert changes to `ring_war.lua`.

**Key Ring War NPCs (all in greatdivide, raid_target varies):**
| NPC | ID | Level | HP | raid_target | respawn |
|-----|----|-------|----|-------------|---------|
| Narandi the Wretched | 118145 | 65 | 150,000 | 1 | 749,999s (scripted — effectively event-only) |
| Seneschal Aldikar | 118166 | 65 | 10,000 | 1 | 900s (event-spawned) |
| Taskmaster Abyott | 118088 | 62 | 72,000 | 1 | 64,800s (18h) |
| ringtenmaster | 118173 | 80 | 100,000 | 0 | 1s (immortal event controller) |

Narandi's 749,999s respawn timer means he effectively only spawns via the event. His HP (150,000) is within normal boss range. **No death-touch or instakill mechanics identified in Ring War NPCs** — the PoSky spell 982 issue from Phase 2 has no Velious equivalent here.

### Plane of Growth / Plane of Mischief Zone Quirk Assessment

**Plane of Growth:**
- Standard zone, ruleset=1, no special rules
- The `a_warm_light` NPC (ID 127004, L1, HP 1,000,000, raid_target=1) is almost certainly a scripted trigger/event entity. Architect should exclude it from HP cuts (hp=1M at L1 is a red flag).
- `a_thifling_focuser` (127005/127006, L65, HP 1,000,000, raid_target=1) — also suspicious at 1M HP for L65. Architect should verify these are intended combat targets.

**Plane of Mischief:**
- Standard zone, ruleset=1, no special rules
- All-Seeing Eye (126374) has a 1,200s (20min) respawn — anomalously short for a raid boss. Likely event-triggered, not a standing spawn. Architect should verify before including in respawn timer changes.
- No Maze or random-geometry rule entries exist — PoM's infamous maze is zone geometry, not a server rule.

### Config-Expert Role in Phase 4a Implementation

Identical to Phase 2 and Phase 3:
1. No rule changes needed.
2. No `eqemu_config.json` or `.env` changes.
3. Post-SQL: issue `#reloadworld` via world telnet (port 9000) to propagate `npc_types`/`spawn2` changes.
4. Smoke verification via DB read-back (same pattern as Tasks 8 and K7).
5. If Ring War is tested and wave timing needs adjustment — that is lua-expert's domain (`ring_war.lua:26`), not config-expert.
6. sleeper zone: any `npc_types` UPDATE must explicitly exclude the Area%dead / StaticShout% / placeholder NPCs (hp=11, raid_target=1 false-positives).

---

## Phase 4a (Velious Non-ToV) — Implementation Tasks V-reload / V-smoke

> **Stage 4: Build Log — 2026-04-22**
> Dispatched by team-lead after data-expert confirmed V1-V6 complete.

### Task V-reload: #reloadworld — COMPLETE

Dependency gate: data-expert confirmed Tasks V1-V6 applied and all 63 verification checks passed. Backup tables present before reload issued.

Command issued:
```
docker exec akk-stack-eqemu-server-1 bash -c "(echo 'reloadworld'; sleep 3) | telnet 127.0.0.1 9000"
```

Response: `Reloading World...`

Note: Phase 4a has zero `npc_spells_entries` changes — reloadworld propagates `npc_types` and `spawn2` cleanly to all running zone processes. No full-stack restart needed.

### Task V-smoke: Smoke Verification — PASS (all checks)

#### HP Verification (14/14 PASS)

| Check | NPC | ID | DB Value | Expected | Result |
|-------|-----|-----|----------|----------|--------|
| King Tormax HP | King_Tormax | 113215 | 100,000 | 100,000 | PASS |
| Lord Yelinak main HP | Lord_Yelinak | 114106 | 110,000 | 110,000 | PASS |
| Lord Yelinak variant HP (Q24) | Lord_Yelinak | 114618 | 110,000 | 110,000 | PASS |
| Tunare HP | #_Tunare | 127001 | 150,000 | 150,000 | PASS |
| Klandicar HP | Klandicar | 120084 | 40,000 | 40,000 | PASS |
| Zlandicar HP | Zlandicar | 123115 | 35,000 | 35,000 | PASS |
| Wuoshi HP | Wuoshi | 119112 | 37,000 | 37,000 | PASS |
| Dain Frostreaver IV HP | #Dain_Frostreaver_IV | 129003 | 80,000 | 80,000 | PASS |
| Mischievous Jester HP | #the_Mischievous_Jester | 126012 | 60,000 | 60,000 | PASS |
| Kromrif Captain HP (Q23 Lever 1) | Kromrif_Captain | 118130 | 6,000 | 6,000 | PASS |
| Kromrif High Priest HP (Q23 Lever 1) | Kromrif_High_Priest | 118210 | 15,000 | 15,000 | PASS |
| Seneschal Aldikar HP (safety bump) | Seneschal_Aldikar | 118166 | 30,000 | 30,000 | PASS |
| AoW UNCHANGED (Phase 4b safety) | The_Avatar_of_War | 113457 | 900,000 | 900,000 | PASS |
| Vulak`Aerr UNCHANGED (Phase 4b safety) | #Vulak`Aerr | 124155 | 890,000 | 890,000 | PASS |

#### Respawn Timer Verification (6/6 PASS — 12h = 43,200s)

| NPC | ID | respawntime | Expected | Result |
|-----|----|-------------|----------|--------|
| Derakor the Vindicator (was already 12h) | 113118 | 43,200 | 43,200 | PASS |
| Lord Yelinak main | 114106 | 43,200 | 43,200 | PASS |
| Lord Yelinak variant | 114618 | 43,200 | 43,200 | PASS |
| Klandicar | 120084 | 43,200 | 43,200 | PASS |
| #_Tunare | 127001 | 43,200 | 43,200 | PASS |
| Dain Frostreaver IV | 129003 | 43,200 | 43,200 | PASS |

#### Phase 4b Exclusion Verification (10/10 PASS — all untouched)

| NPC | ID | HP | Result |
|-----|----|----|--------|
| The_Avatar_of_War | 113457 | 900,000 | PASS |
| #Vulak`Aerr | 124155 | 890,000 | PASS |
| #Kildrukaun_the_Ancient | 128041 | 352,000 | PASS |
| #Vyskudra_the_Ancient | 128042 | 352,000 | PASS |
| #Tjudawos_the_Ancient | 128043 | 352,000 | PASS |
| #Zeixshi-Kar_the_Ancient | 128044 | 377,000 | PASS |
| #Nanzata_the_Warder | 128090 | 200,000 | PASS |
| #Ventani_the_Warder | 128091 | 200,000 | PASS |
| #Tukaarak_the_Warder | 128092 | 200,000 | PASS |
| #Hraashna_the_Warder | 128093 | 200,000 | PASS |

#### Backup Table Integrity

| Table | Rows |
|-------|------|
| npc_types_backup_raid_scaling_velious_a | 46 |
| spawn2_backup_raid_scaling_velious_a | 227 |

Both backup tables intact post-reload. No Phase 4b rows touched.

**All-clear: V-reload and V-smoke COMPLETE. Ready for game-tester validation.**

---

## Phase 4b (Velious ToV + Sleeper + Vulak + AoW) — Config Consultation (2026-04-22)

### Summary

**Phase 2/3/4a config findings carry forward unchanged to Phase 4b. Zero concerns on all six questions. No new rules exist for ToV/Sleeper/Vulak/AoW. No eqemu_config.json or .env changes needed. 100% SQL pattern confirmed.**

### Verified Findings (per architect's six questions)

**1. rule_values drift check**
Current count: **1,112** — identical to Phase 2 baseline. Zero drift across all phases to date.

**2. Zone-scoped rulesets — templeveeshan and sleeper**
Both Phase 4b zones confirmed:
- `templeveeshan`: `ruleset=1`, `min_status=0`, `expansion=2`
- `sleeper`: `ruleset=1`, `min_status=0`, `expansion=2`

Neither has a custom ruleset override. Identical posture to all prior phases. No endgame-tier rule overrides apply to these zones.

**3. Endgame-specific globals**
All seven prior-pass globals still in effect. No dragon-breath modifier, no MR-cap rule, no endgame-tier HP/damage rule exists. The only dragon-adjacent rule found: `Combat:DragonPunchBaseDamage=12` — this is the monk skill Dragon Punch base damage, completely unrelated to dragon NPCs. Vyemm's MR=1000 and all NPC magic resistance values are stored in `npc_types.MR` as plain DB columns. No rule can override them. Architect's "preserve MR via npc_types.MR only" posture is correct.

**4. Signature-mechanics rule interactions**
No `RaidTargetFlurryMultiplier` or equivalent rule exists. Rules touching special abilities:
- `Bots:DisableSpecialAbilitiesAtMaxMelee` = true — Bots only, not NPC special abilities
- `Spells:CharmDisablesSpecialAbilities` = false — charm-stripping toggle, not relevant

No rule amplifies or overrides `special_abilities` on `raid_target` NPCs. "Don't touch rules" posture is correct for Phase 4b.

**5. Respawn timer rules**
No min/max respawn clamp rules, no respawn randomization rules, no raid-tier respawn overrides in `rule_values`. Respawn is purely `spawn2.respawntime`.

**CRITICAL Phase 4b finding:** All 10 Phase 4b bosses (AoW 113457, Vulak 124155, Warders 128090-128093, Kildrukaun siblings 128041-128044) have **zero standing spawn2 rows**. They are all event-triggered or condition-gated. There are no `spawn2.respawntime` rows to update. Decision #8 endgame=24h (86400s) has no applicable rows — no spawn2 timer changes for Phase 4b. Smoke verification will focus on `npc_types` HP/damage only.

**6. Data buckets / spawn_conditions for Sleeper's Tomb**
`spawn_condition_values` for sleeper zone: two conditions:
- condition_id=1, value=0 (dormant state)
- condition_id=2, value=1 (active state)

`data_buckets` table: zero rows matching sleep/keraf/awake/warder patterns. `variables` table: same, zero rows. Kerafyrm awake event is controlled purely via `spawn_conditions` in-zone — not via `data_buckets` or any server config. No config-expert concern. Per Decision #12 (Kerafyrm untouched), this is out of Phase 4b scope entirely.

**Death-touch sweep (bonus finding):**
Full sweep of all 9 Phase 4b bosses with spell lists (AoW has npc_spells_id=0):
- Criteria: mana=0, cast_time=0, effect_base_value1 < -5000
- Result: **zero rows** — no death-touch profile spells on any Phase 4b boss

No `npc_spells_entries` DELETEs needed for Phase 4b. Zone-restart caveat does not apply. `#reloadworld` will be sufficient post-SQL.

**SCOPE CORRECTION (architect, 2026-04-22):** Initial sweep examined only 10 headline bosses. Full Phase 4b scope is 47 NPCs. Only AoW (113457) and Vulak (124155) have zero spawn2 rows — both are script-spawned. The other 45 have 1-3 spawn2 rows each: all 16 ToV dragon lords, all 16 NToV mid-tier named, Ancients + Progenitor + Final Arbiter + Master of Guard + Milas in sleeper, and the 4 Warders (`_condition=1 cond_value=1` dormant). Phase 4b WILL update `spawn2.respawntime` for ~32 rows to 86,400s (24h per Decision #8). Six L65-66 mid-tier named already at 18h stay; Milas at 4h stays; Defenders (124050/51/52/79, audit-excluded per Decision #2) stay. All core rule/config findings still hold — the spawn2 zero-rows claim was a scope error from examining only the 10 bosses confirmed in the Phase 4a exclusion smoke check.

### Config-Expert Role in Phase 4b Implementation

Identical to Phase 2/3/4a:
1. No rule changes needed.
2. No `eqemu_config.json` or `.env` changes.
3. Post-SQL: `#reloadworld` via world telnet (port 9000).
4. Smoke verification via DB read-back on `npc_types` HP/damage for 47 NPCs + `spawn2.respawntime` for ~32 rows per architect's UPDATE list.
5. No `npc_spells_entries` changes — no zone-restart caveat.
6. Additional untouched-verification: Kerafyrm trio (128089/94/95), spell 1948 in list 489, spawn_conditions state (condition 1=0, condition 2=1), Defenders (124050/51/52/79 at 120k HP unchanged).

---

## Phase 4b (Velious ToV + Sleeper + Vulak + AoW) — Implementation Tasks B-reload / B-smoke

> **Stage 4: Build — COMPLETE 2026-04-22**

### Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| B-reload | `#reloadworld` via world telnet port 9000 | data-expert B1-B8 complete + DB backup tables confirmed | **Complete 2026-04-22** |
| B-smoke | Smoke verification (representative Phase 4b NPCs per team-lead brief) | B-reload | **Complete 2026-04-22** |

### Stage 4: Build Log — Phase 4b Velious-B (2026-04-22)

#### Pre-reload DB Verification

data-expert confirmed B1-B8 applied. DB gate confirmed before reload:
- `npc_types_backup_raid_scaling_velious_b`: **51 rows** (expected 51)
- `spawn2_backup_raid_scaling_velious_b`: **62 rows**

#### Task B-reload: #reloadworld — COMPLETE

Command issued:
```
docker exec akk-stack-eqemu-server-1 bash -c "(echo 'reloadworld'; sleep 3) | telnet 127.0.0.1 9000"
```

Response: `Reloading World...`

No `npc_spells_entries` changes this phase — reloadworld propagates `npc_types` and `spawn2` cleanly. No full-stack restart required.

#### Task B-smoke: Smoke Verification — PASS (all checks)

**HP / Damage / MR Checks:**

| Check | NPC | ID | DB Value | Expected | Result |
|-------|-----|----|----------|----------|--------|
| Lord Vyemm HP | #Lord_Vyemm | 124017 | 90,000 | 90,000 | PASS |
| Lord Vyemm maxdmg | 124017 | 700 | 700 | PASS |
| Lord Vyemm MR (preserved) | 124017 | MR=1000 | 1000 | PASS |
| Aaryonar HP | #Aaryonar | 124010 | 95,000 | 95,000 | PASS |
| Aaryonar maxdmg | 124010 | 550 | 550 | PASS |
| Midayor HP (NToV mid-tier sample) | #Midayor | 124030 | 40,000 | 40,000 | PASS |
| An Emerald Defender HP (Q37) | An_Emerald_Defender | 124050 | 45,000 | 45,000 | PASS |
| An Emerald Defender maxdmg (Q37) | 124050 | 550 | 550 | PASS |
| Nanzata the Warder HP (Q36) | #Nanzata_the_Warder | 128090 | 60,000 | 60,000 | PASS |
| Kildrukaun the Ancient HP | #Kildrukaun_the_Ancient | 128041 | 85,000 | 85,000 | PASS |
| Kildrukaun MR (preserved) | 128041 | MR=400 | 400 | PASS |
| Lendiniara the Keeper HP | #Lendiniara_the_Keeper | 124020 | 80,000 | 80,000 | PASS |
| Avatar of War HP | The_Avatar_of_War | 113457 | 120,000 | 120,000 | PASS |
| Avatar of War mindmg | 113457 | 200 | 200 | PASS |
| Avatar of War maxdmg | 113457 | 700 | 700 | PASS |
| Vulak`Aerr HP | #Vulak`Aerr | 124155 | 150,000 | 150,000 | PASS |
| Vulak`Aerr mindmg | 124155 | 250 | 250 | PASS |
| Vulak`Aerr maxdmg | 124155 | 800 | 800 | PASS |
| Thylex UNCHANGED | #Thylex_of_Veeshan | 124000 | HP=100 | 100 | PASS |
| Kerafyrm combat UNCHANGED | #Kerafyrm | 128089 | HP=3,500,000 | 3,500,000 | PASS |
| The Sleeper UNCHANGED | #The_Sleeper | 128094 | HP=3,500,000 | 3,500,000 | PASS |
| Kerafyrm zone-clone UNCHANGED | #Kerafyrm_ | 128095 | HP=3,500,000 | 3,500,000 | PASS |

**Respawn Timer Checks:**

| NPC | ID | respawntime | Expected | Result |
|-----|----|-------------|----------|--------|
| Lord Vyemm | 124017 | 86,400 (24h) | 86,400 | PASS |
| Lendiniara the Keeper (Q38) | 124020 | 86,400 (24h) | 86,400 | PASS |
| Midayor | 124030 | 86,400 (24h) | 86,400 | PASS |
| An Emerald Defender (UNCHANGED, Q37) | 124050 | 16,200 (~4.5h) | 16,200 | PASS |
| Nanzata the Warder (UNCHANGED, cond=1) | 128090 | 259,200 (72h) | 259,200 | PASS |

**Kerafyrm Trio Safety Check:**

| Check | Result |
|-------|--------|
| IDs 128089/128094/128095 absent from `npc_types_backup_raid_scaling_velious_b` | PASS (0 rows returned) |
| Kerafyrm (128089) HP in npc_types | 3,500,000 — UNCHANGED |
| The Sleeper (128094) HP in npc_types | 3,500,000 — UNCHANGED |
| Kerafyrm zone-clone (128095) HP in npc_types | 3,500,000 — UNCHANGED |

**Backup Table Integrity:**

| Table | Rows |
|-------|------|
| npc_types_backup_raid_scaling_velious_b | 51 |
| spawn2_backup_raid_scaling_velious_b | 62 |

Both backup tables intact post-reload.

**All-clear: B-reload and B-smoke COMPLETE. Ready for game-tester validation.**

---

## Phase 5a (Luclin Non-VT) — Config Consultation (2026-04-22)

### Summary

**Phase 2/3/4a/4b config findings carry forward unchanged to Phase 5a. No new rules. No config changes. SQL-only pattern confirmed. One structural flag: SSra/Akheva bosses have zero or event-only spawn2 rows — #reloadworld caveat applies to npc_types only for those NPCs.**

### Verification

**rule_values count:** 1,112 — identical to Phase 4b baseline. Zero drift across all five phases to date.

**No Luclin-specific rules exist:** Searched `rule_values` for Luclin, SSra, Akheva, Seru, Grieg, Acrylia keyword matches. Zero hits on zone-specific or era-specific rule names. All seven prior-pass combat-tuning globals still in effect unchanged.

**Zone ruleset/insttype check — all Luclin non-VT zones:**

| Zone | ruleset | min_status | expansion | insttype |
|------|---------|-----------|-----------|---------|
| ssratemple | 1 | 0 | 3 | 0 |
| akheva | 1 | 0 | 3 | 0 |
| griegsend | 1 | 0 | 3 | 0 |
| acrylia | 1 | 0 | 3 | 0 |
| sseru | 1 | 0 | 3 | 0 |

All `insttype=0` — none are flagged as DZ zones. `dynamic_zones` table has 0 rows. No Akheva DZ system is active. Standard `spawn2` pattern applies for all zones with standing rows.

**griegsend has two zone table rows** (ruleset=1 and ruleset=0). This is a duplicate — same pattern seen in other zones. The ruleset=1 row is the active one. No gameplay implication for NPC stats.

### Luclin Non-VT Boss spawn2 Coverage

| NPC | ID | Zone | spawn2_rows | respawntime | spawn2 writable? |
|-----|----|------|-------------|-------------|-----------------|
| Lord Inquisitor Seru | 159691 | sseru | 1 | 259,200s (72h) | YES |
| High Priest of Ssraeshza | 162076 | ssratemple | 1 | 259,200s (72h) | YES |
| Xerkizh The Creator | 162190 | ssratemple | 1 | 259,200s (72h) | YES |
| Emperor Ssraeshza | 162227 | — | 0 | N/A | NO — event-only |
| Arch Lich Rhag`Zadune | 162177 | — | 0 | N/A | NO — event-only |
| Vyzh`dra the Cursed | 162206 | — | 0 | N/A | NO — event-only |
| Vyzh`dra the Exiled | 162232 | — | 0 | N/A | NO — event-only |
| Vyzh`dra the Banished | 162214 | — | 0 | N/A | NO — event-only |
| Shei Vinitras (primary) | 179032 | — | 0 | N/A | NO — event-only |
| Shei Vinitras (variant) | 179157 | akheva | 1 | 194,474s (~54h) | YES |
| Shar Vinitras | 179134 | akheva | 1 | 10,800s (3h) | YES |
| The Itraer Vius | 179037 | akheva | 1 | 210,924s (~58.6h) | YES |
| Spirit of Akelha`Ra | 179144 | — | 0 | N/A | NO — event-only |
| Grieg Veneficus | 163075 | griegsend | 0 | N/A | NO — no spawn2 row |
| Ancient Necromantic Shade | 163052 | griegsend | 1 | 7,200s (2h) | YES |
| Thought Horror Overfiend | 164078 | thedeep | 1 | 194,400s (54h) | YES |
| Nathyn Illuminious | 160135 | katta | 1 | 194,400s (54h) | YES |
| Lcea Katta | 160375 | katta | 1 | 258,750s (~71.9h) | YES |
| Va_Dyn_Khar | 158081 | vexthal | 1 | 21,600s (6h) | YES — NOTE: in vexthal |

**IMPORTANT: VT bosses (158xxx) are Phase 5b scope**, not 5a. Confirmed in `vexthal` zone with standing spawn2 rows at 468,720s (~130h). Va_Dyn_Khar (158081) appears in vexthal at 21,600s — this may already be at a scaled value or is an outlier; architect should verify Phase 5b scope boundary.

**Akhevan Warders (158087-158094):** HP 901,000, zero spawn2 rows. Event-triggered only.

### Death-Touch Sweep

No spell 982 (Cazic Touch) found in any Luclin non-VT boss spell list (npc_id range 155000-185000, raid_target=1). Zero `npc_spells_entries` DELETEs needed for Phase 5a. Zone spell-list cache restart caveat does not apply.

Grieg's End NPCs have standard special_abilities (ability codes 1,2,5,8,13,14,15,16,17,21,31). No instakill mechanics found. The `an_ancient_necromantic_shade` (163052) has ability 4 with parameters `4,1,25,0,50` — this is a charm/mez-immunity or enrage flag; not a death-touch. No `npc_spells_entries` action needed.

### Config-Expert Role in Phase 5a Implementation

Identical to all prior phases:
1. No rule changes needed.
2. No `eqemu_config.json` or `.env` changes.
3. Post-SQL: `#reloadworld` via world telnet (port 9000) to propagate `npc_types`/`spawn2` changes.
4. Smoke verification via DB read-back on `npc_types` HP/damage + `spawn2.respawntime` for rows that exist.
5. No `npc_spells_entries` changes — no zone-restart caveat.

**Special note for architect:** Many SSra and Akheva headline bosses (Emperor Ssraeshza, Arch Lich, Vyzh`dra trio, Shei Vinitras primary, Spirit of Akelha`Ra) have ZERO standing spawn2 rows. Their HP cuts will apply via `npc_types` UPDATE and will propagate with `#reloadworld`. Respawn timer changes are not applicable for those NPCs. The `npc_types` HP change will take effect on the next time those NPCs are spawned (event trigger). No separate spawn2 concern.

---

## Phase 5a (Luclin Non-VT) — Implementation Tasks L-reload / L-smoke

> **Stage 4: Build Log — 2026-04-22**
> Dispatched by team-lead after perl-expert confirmed L13 complete.

### Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| L-reload | `#reloadworld` via world telnet port 9000 | data-expert L1-L9 complete + DB backup tables confirmed | **Complete 2026-04-22** |
| L-smoke | Smoke verification (per team-lead brief + architecture doc) | L-reload | **Complete 2026-04-22** |

### Pre-reload DB Gate Check (2026-04-22)

Dependency gate check run before issuing `#reloadworld`. Results:

**GATE FAILED — data-expert SQL not applied:**

- `npc_types_backup_raid_scaling_luclin_a` — DOES NOT EXIST
- `spawn2_backup_raid_scaling_luclin_a` — DOES NOT EXIST
- `npc_spells_entries_backup_raid_scaling_luclin_a` — DOES NOT EXIST
- Emperor Ssraeshza (162227) HP = 1,250,500 — PEQ default, unscaled (expected 120,000 post-L2)
- Lord Inquisitor Seru (159691) HP = 1,201,500 — PEQ default, unscaled (expected 120,000 post-L5)
- Vyzh`dra the Cursed (162206) HP = 900,000 — unscaled (expected 90,000 post-L3)
- Khati Sha the Twisted (154145) HP = 475,000 — unscaled (expected 90,000 post-L6)
- Spirit of Akelha`Ra (179144) HP = 1,000,000 — UNCHANGED per Decision #57/30 (correct; should NOT be scaled)

**Context:** Docker stack was restarting when config-expert first connected (containers briefly down). All prior phase backup tables (velious_a, velious_b, kunark, classic) are present and intact — only Phase 5a tables are absent, confirming this is not a DB wipe.

**Good news — perl-expert L13 CONFIRMED COMPLETE:**
`akk-stack/server/quests/ssratemple/#EmpCycle.pl:3` reads:
`$EmpRepopTime = int(rand(7200)) + 79200; #Respawn time for Emp after success (22-24h endgame tier per Decision #52 user override)`
L13 is done.

**Action taken:** Pinged data-expert + team-lead. Config-expert is standing by. Will issue `#reloadworld` and run full smoke verification as soon as data-expert confirms L1-L9 applied and backup table row counts match expected (41 / ~22-23 / 1).

### Task L-reload: #reloadworld — COMPLETE

Data-expert confirmed L1-L9 applied. Backup tables pre-verified:
- `npc_types_backup_raid_scaling_luclin_a`: **45 rows**
- `spawn2_backup_raid_scaling_luclin_a`: **80 rows**
- `npc_spells_entries_backup_raid_scaling_luclin_a`: **1 row**

Command issued:
```
docker exec akk-stack-eqemu-server-1 bash -c "(echo 'reloadworld'; sleep 3) | telnet 127.0.0.1 9000"
```

Response: `Reloading World...`

Zone-spell cache caveat: Phase 5a has one `npc_spells_entries` DELETE (Touch of Vinitras spell 2859 from list 196). `#reloadworld` propagates `npc_types` and `spawn2` cleanly. In-memory spell list 196 in running akheva zone processes requires a full-stack restart to flush. DB DELETE is confirmed (list 196 row count = 0). Infra-expert full-stack restart required per architecture doc to flush zone caches.

### Task L-smoke: Smoke Verification — PASS (all checks)

#### Core Boss HP / Damage / MR

| Check | ID | DB Value | Expected | Result |
|-------|----|----------|----------|--------|
| Emperor Ssraeshza HP | 162227 | 120,000 | 120,000 | PASS |
| Emperor mindmg | 162227 | 200 | 200 | PASS |
| Emperor maxdmg | 162227 | 620 | 620 | PASS |
| Emperor Leash `32,1,290` preserved | 162227 | YES | YES | PASS |
| #EmpCycle.pl:3 EmpRepopTime | — | `int(rand(7200)) + 79200` | 22-24h | PASS |
| Lord Inquisitor Seru HP | 159691 | 120,000 | 120,000 | PASS |
| Lord Seru mindmg | 159691 | 220 | 220 | PASS |
| Lord Seru maxdmg | 159691 | 620 | 620 | PASS |
| Lord Seru MR (preserved) | 159691 | 800 | 800 | PASS |
| Khati Sha HP | 154145 | 90,000 | 90,000 | PASS |
| Khati Sha maxdmg | 154145 | 750 | 750 | PASS |
| Shei Vinitras REAL HP | 179032 | 85,000 | 85,000 | PASS |
| Shei Vinitras REAL maxdmg | 179032 | 600 | 600 | PASS |
| Shei Vinitras MERCHANT HP | 179157 | 60,000 | 60,000 | PASS |
| Doomshade HP | 176088 | 70,000 | 70,000 | PASS |
| Vyzh`dra Cursed HP | 162206 | 90,000 | 90,000 | PASS |
| Vyzh`dra Exiled HP | 162232 | 70,000 | 70,000 | PASS |
| Vyzh`dra Banished HP | 162214 | 65,000 | 65,000 | PASS |

#### Q51 Akheva Elite-Named

| Check | ID | DB Value | Expected | Result |
|-------|----|----------|----------|--------|
| Sheleric Vis (L61) HP | 179133 | 35,000 | 35,000 | PASS |
| Sheleric Vis (L61) maxdmg | 179133 | 550 | 550 | PASS |
| Sheleric Vis variant HP | 179046 | 30,000 | 30,000 | PASS |
| Xaui Tatrua HP | 179044 | 30,000 | 30,000 | PASS |

#### Q50 Serpents + Q59 Arcanist + Decision #57 Safety

| Check | ID | DB Value | Expected | Result |
|-------|----|----------|----------|--------|
| Rune Serpent HP | 162253 | 60,000 | 60,000 | PASS |
| Glyph Serpent HP | 162261 | 70,000 | 70,000 | PASS |
| A_Spiritual_Arcanist HP | 154153 | 40,000 | 40,000 | PASS |
| Spirit of Akelha`Ra (UNCHANGED) | 179144 | 1,000,000 | 1,000,000 | PASS |

#### Decision #60 — Spell 2859

| Check | Result | Expected | Result |
|-------|--------|----------|--------|
| List 196 spell 2859 row count | 0 | 0 | PASS |
| List 179 spell 2859 row count (retained) | 1 | 1 | PASS |

#### All Remaining SSra/Akheva/Seru/Katta/Grieg/Acrylia/Deep/Umbral HP

| NPC | ID | HP | Expected | Result |
|-----|----|----|----------|--------|
| High_Priest_of_Ssraeshza | 162076 | 90,000 | 90,000 | PASS |
| Xerkizh_The_Creator | 162190 | 80,000 | 80,000 | PASS |
| #Arch_Lich_Rhag`Zadune | 162177 | 75,000 | 75,000 | PASS |
| #Rhag`Mozdezh | 162192 | 60,000 | 60,000 | PASS |
| #Rhag`Zhezum | 162178 | 55,000 | 55,000 | PASS |
| #Blood_of_Ssraeshza | 162189 | 60,000 | 60,000 | PASS |
| #Ssraeshzian_Blood_Golem | 162064 | 60,000 | 60,000 | PASS |
| #General_Kizuhx | 162066 | 60,000 | 60,000 | PASS |
| #Arbiter_Korazhk | 162191 | 55,000 | 55,000 | PASS |
| #Advisor_Zekuzh | 162067 | 45,000 | 45,000 | PASS |
| #Rhozth_Ssrakezh | 162258 | 40,000 | 40,000 | PASS |
| #Rhozth_Ssravizh | 162089 | 38,000 | 38,000 | PASS |
| The_Itraer_Vius | 179037 | 80,000 | 80,000 | PASS |
| #The_Insanity_Crawler | 179180 | 60,000 | 60,000 | PASS |
| The_Va`Dyn | 179178 | 50,000 | 50,000 | PASS |
| #Praesertum_Vantorus | 159113 | 55,000 | 55,000 | PASS |
| #Praesertum_Rhugol | 159112 | 50,000 | 50,000 | PASS |
| #Praesertum_Bikun | 159115 | 45,000 | 45,000 | PASS |
| #Praesertum_Matpa | 159114 | 45,000 | 45,000 | PASS |
| Lcea_Katta | 160375 | 80,000 | 80,000 | PASS |
| #Nathyn_Illuminious | 160135 | 80,000 | 80,000 | PASS |
| #Grieg_Veneficus (main) | 163075 | 80,000 | 80,000 | PASS |
| #Grieg_Veneficus (variant, HP preserved) | 163231 | 162,500 | UNCHANGED | PASS |
| #Servitor_of_Luclin | 163013 | 40,000 | 40,000 | PASS |
| #Praetorian_Myral | 163078 | 35,000 | 35,000 | PASS |
| #an_evolved_burrower | 154142 | 60,000 | 60,000 | PASS |
| Thought_Horror_Overfiend | 164078 | 90,000 | 90,000 | PASS |
| #Zelnithak | 176089 | 60,000 | 60,000 | PASS |
| #Rumblecrush | 176002 | 45,000 | 45,000 | PASS |

#### Respawn Timers — 24h Updated (86,400s)

| NPC | ID | Zone | respawntime | Result |
|-----|----|------|-------------|--------|
| #Lord_Inquisitor_Seru_ | 159691 | sseru | 86,400 | PASS |
| High_Priest_of_Ssraeshza | 162076 | ssratemple | 86,400 | PASS |
| Xerkizh_The_Creator | 162190 | ssratemple | 86,400 | PASS |
| #Rhag`Zhezum | 162178 | ssratemple | 86,400 | PASS |
| The_Itraer_Vius | 179037 | akheva | 86,400 | PASS |
| #Shei_Vinitras_ (merchant) | 179157 | akheva | 86,400 | PASS |
| #The_Insanity_Crawler | 179180 | akheva | 86,400 | PASS |
| The_Va`Dyn | 179178 | akheva | 86,400 | PASS |
| #Praesertum_Vantorus | 159113 | sseru | 86,400 | PASS |
| #Praesertum_Rhugol | 159112 | sseru | 86,400 | PASS |
| #Praesertum_Bikun | 159115 | sseru | 86,400 | PASS |
| #Praesertum_Matpa | 159114 | sseru | 86,400 | PASS |
| Lcea_Katta | 160375 | katta | 86,400 | PASS |
| #Nathyn_Illuminious | 160135 | katta | 86,400 | PASS |
| #Grieg_Veneficus (variant) | 163231 | griegsend | 86,400 | PASS |
| #Servitor_of_Luclin | 163013 | griegsend | 86,400 | PASS |
| #Praetorian_Myral | 163078 | griegsend | 86,400 | PASS |
| #an_evolved_burrower | 154142 | acrylia | 86,400 | PASS |
| Thought_Horror_Overfiend | 164078 | thedeep | 86,400 | PASS |
| #Zelnithak | 176089 | umbral | 86,400 | PASS |
| #Rumblecrush | 176002 | umbral | 86,400 | PASS |

#### Preserved Respawn Timers (UNCHANGED)

| NPC | ID | respawntime | Expected | Result |
|-----|----|-------------|----------|--------|
| #Shar_Vinitras (short-tier) | 179134 | 10,800 | 10,800 | PASS |
| Sheleric_Vis ×2 rows | 179133 | 5,400 | 5,400 (Q51) | PASS |
| Sheleric_Vis variant ×2 rows | 179046 | 5,400 | 5,400 (Q51) | PASS |
| Xaui_Tatrua | 179044 | 5,400 | 5,400 (Q51) | PASS |
| #Rhozth_Ssrakezh | 162258 | 5,400 | 5,400 (mid-tier) | PASS |
| #Rhozth_Ssravizh | 162089 | 21,600 | 21,600 (mid-tier) | PASS |
| #General_Kizuhx (3 spawn2 rows) | 162066 | 1,080 | 1,080 (pre-Emperor) | PASS |

#### Safety — Untouched NPCs

| NPC | ID | HP | Result |
|-----|----|----|--------|
| Emperor placeholder (no-target) | 162065 | 6,516 | PASS — untouched |
| keycheck (event-control) | 162269 | 999,999,999 | PASS — untouched |
| #Keymaster (event-control) | 176110 | 99,999,999 | PASS — untouched |
| Bella_Helsin (event-control) | 160177 | 1,000,000 | PASS — untouched |
| Heracus_Helsin (event-control) | 160178 | 1,000,000 | PASS — untouched |
| Va_Dyn_Khar (vexthal, Phase 5b) | 158081 | 600,000 | PASS — untouched |
| Akhevan_Warder (vexthal sample) | 158087 | 901,000 | PASS — untouched |

#### Backup Table Integrity Post-Reload

| Table | Rows |
|-------|------|
| npc_types_backup_raid_scaling_luclin_a | 45 |
| spawn2_backup_raid_scaling_luclin_a | 80 |
| npc_spells_entries_backup_raid_scaling_luclin_a | 1 |

**ALL-CLEAR: L-reload and L-smoke COMPLETE. 41+ HP/dmg checks PASS, 21 respawntime checks PASS, 2 spell-list DELETE checks PASS, 7 safety checks PASS.**

**Outstanding action: infra-expert full-stack restart required to flush akheva zone spell list 196 cache (Touch of Vinitras zone-memory flush).**

---

## Phase 5b (Luclin VT + Shards) — Config Consultation (2026-04-22)

### Summary

**Phase 2/3/4a/4b/5a config findings carry forward unchanged to Phase 5b. No new rules exist for VT or shard content. No `eqemu_config.json` or `.env` changes needed. 100% SQL + possibly Perl/Lua script pattern confirmed. Two rule entries are present but irrelevant.**

### rule_values Count and Drift Check

Current count: **1,112** — identical to every prior phase baseline. Zero drift across all six phases to date.

Two rule entries matched "Shard" keyword search:
- `HotReload:QuestsAutoReloadGlobalScripts = false` — quest hot-reload toggle, completely unrelated to shard mechanics
- `Zone:ZoneShardQuestMenuOnly = false` — this is a zone-shard UI flag (shard quest menu gate), NOT a scaling parameter. Already false; no change needed or appropriate.

No rule controls VT boss HP, damage, respawn, or shard-drop behavior.

### vexthal Zone Config

| Field | Value |
|-------|-------|
| ruleset | 1 (default — same as all standard zones) |
| min_status | 0 (player-accessible) |
| expansion | 3 (Luclin) |
| insttype | 0 (NOT a DZ zone) |
| maxclients | 0 (no cap) |

No custom ruleset override. No DZ system active. `dynamic_zones` table has 0 rows (confirmed Phase 5a). `spawn_condition_values` for vexthal: **0 rows** — VT has no spawn_conditions system. All boss sequencing is handled via qglobals + Perl quest scripts.

### VT Boss Population — NPC Stats

VT has **127 raid_target=1 NPCs** in the 158000-158200 range. Key headline boss data:

| NPC | ID | Level | HP (current) | maxdmg | mindmg | MR | npc_spells_id |
|-----|----|-------|-------------|--------|--------|----|---------------|
| #Aten_Ha_Ra (non-destroy) | 158006 | 66 | 1,901,500 | 1,054 | 294 | 162 | 229 |
| #Aten_Ha_Ra_ (destroy variant) | 158096 | 66 | 1,901,500 | 1,054 | 294 | 144 | 540 |
| #Kaas_Thox_Xi_Aten_Ha_Ra | 158007 | 66 | 1,900,000 | 1,650 | 320 | 110 | 231 |
| #Thall_Va_Kelun | 158008 | 66 | 1,825,000 | 1,000 | 240 | 128 | 232 |
| #Va_Xi_Aten_Ha_Ra | 158009 | 66 | 1,601,500 | 1,254 | 304 | 144 | 234 |
| #Diabo_Xi_Va_Temariel | 158010 | 66 | 1,706,000 | 1,400 | 165 | 125 | 238 |
| #Thall_Xundraux_Diabo | 158011 | 66 | 1,475,000 | 654 | 274 | 185 | 1353 |
| #Diabo_Xi_Xin_Thall | 158012 | 66 | 1,501,500 | 750 | 180 | 106 | 237 |
| #Kaas_Thox_Xi_Ans_Dyek | 158013 | 66 | 1,201,500 | 650 | 270 | 120 | 230 |
| #Diabo_Xi_Va | 158014 | 66 | 1,050,000 | 654 | 274 | 185 | 239 |
| #Diabo_Xi_Xin | 158015 | 66 | 1,106,500 | 1,200 | 250 | 164 | 0 |
| #Thall_Va_Xakra | 158016 | 60 | 900,000 | 950 | 285 | 125 | 233 |
| Va_Dyn_Khar | 158081 | 66 | 600,000 | 455 | 265 | 120 | 0 |
| Akhevan_Warders (x8) | 158087-158094 | 60 | 901,000 | 4 | 0 | 157 | 236 |

Non-headline VT named (shard source NPCs, ~100 NPCs in 158000-158093): HP range 45k-101k, maxdmg 352-438. These are the "Xakra" and "Centien" etc. mobs that drop shards. They were already confirmed untouched in Phase 5a L-smoke (Va_Dyn_Khar at 600,000, Akhevan_Warder at 901,000).

### Spawn2 Coverage for VT Bosses

| NPC | ID | spawn2 rows | respawntime | Notes |
|-----|----|------------|-------------|-------|
| #Aten_Ha_Ra (non-destroy) | 158006 | **0** | N/A | Event-spawned via #Aten_Trigger.pl |
| #Aten_Ha_Ra_ (destroy variant) | 158096 | **0** | N/A | Event-spawned via #Aten_Trigger.pl |
| #Kaas_Thox_Xi_Aten_Ha_Ra | 158007 | 2 | 468,720s (~130h) | Standing spawn2, updatable |
| #Thall_Va_Kelun | 158008 | 1 | 468,720s (~130h) | Standing spawn2, updatable |
| #Va_Xi_Aten_Ha_Ra | 158009 | 1 | 468,720s (~130h) | Standing spawn2, updatable |
| #Diabo_Xi_Va_Temariel | 158010 | 1 | 468,720s (~130h) | Standing spawn2, updatable |
| #Thall_Xundraux_Diabo | 158011 | 1 | 468,720s (~130h) | Standing spawn2, updatable |
| #Diabo_Xi_Xin_Thall | 158012 | 1 | 468,720s (~130h) | Standing spawn2, updatable |
| #Kaas_Thox_Xi_Ans_Dyek | 158013 | 1 | 468,720s (~130h) | Standing spawn2, updatable |
| #Diabo_Xi_Va | 158014 | 1 | 468,720s (~130h) | Standing spawn2, updatable |
| #Diabo_Xi_Xin | 158015 | 1 | 468,720s (~130h) | Standing spawn2, updatable |
| #Thall_Va_Xakra | 158016 | 1 | 140,616s (~39h) | Anomalous respawn — NOT 130h; already at a shorter timer |
| Va_Dyn_Khar | 158081 | 1 | 21,600s (6h) | Already confirmed untouched in Phase 5a smoke |

**IMPORTANT:** Aten Ha Ra (158006 and 158096) are **both event-spawned via `#Aten_Trigger.pl`** — a controller NPC checks if all 9 prerequisite wing bosses are dead, then spawns either the non-destroy or destroy variant. The destroy variant's respawn post-death is controlled by `quest::setglobal("aten",1,3,"M$spawntime")` where `$spawntime = 6480 + rand(720)` ≈ **1.8-2.0 hours**. This is hardcoded in `#Aten_Ha_Ra_.pl` and `#Aten_Ha_Ra.pl`. There are no spawn2 rows to update for either Aten Ha Ra variant — any respawn tuning requires Perl script changes (lua/perl-expert domain), not SQL.

**Thall Va Xakra (158016):** Already at 140,616s (~39h) — shorter than the other 9 wing bosses at 468,720s. This may already reflect prior tuning or a deliberate design difference. Architect should confirm whether this gets the standard endgame respawn cut or stays differentiated.

**Va_Dyn_Khar (158081):** Already at 21,600s (6h) — already in low-boss range. No change needed; confirmed untouched in Phase 5a smoke.

### Shard Quest Mechanics — Rule-Tunable Parameters

**No rules control shard quest behavior.** The 13-shard quest for Vex Thal access uses:

1. **Shard drops from named mobs** — controlled by `lootdrop_entries.chance` (plain DB data, already covered by Phase 2 loot multiplier ×1.5 via `Zone:GlobalLootMultiplier=2`)
2. **Aten Ha Ra event sequencing** — controlled entirely by Perl scripts (`#Aten_Trigger.pl`, `#Aten_Ha_Ra.pl`, `#Aten_Ha_Ra_.pl`) using qglobals. Not a rule. Not a DB config column.
3. **Aten Ha Ra respawn timing** — set via `quest::setglobal("aten",1,3,"M$spawntime")` where spawntime ≈ 1.8-2.0h post-kill. Hardcoded in Perl. No rule. Any changes require lua/perl-expert.
4. **Zone access gate** — `Zone:ZoneShardQuestMenuOnly = false` is present but already false, meaning standard access (not shard-gated). This is the correct state.

**Shard source NPC scaling:** The non-headline Xakra/Centien/etc. named mobs (HP 45k-101k) were already in Phase 5a scope but their IDs start at 158000. They were excluded from Phase 5a (which covered non-VT Luclin only). Phase 5b will need to include them. No rule governs their stats — standard `npc_types` UPDATE pattern.

### Death-Touch Sweep — VT Headline Boss Spell Lists

Sweep of spell lists 229, 230, 231, 232, 233, 234, 236, 237, 238, 239, 540, 1353, 1472, 1473, 448 for spells with `base_value1 < -5000` or `base_value2 < -5000`:

**Result: ZERO rows.** No death-touch profile spells in any VT boss spell list.

- List 233 (Thall Va Xakra): empty — confirmed 0 entries
- Akhevan Warder list 236: confirmed no death-touch (warders use `7,1` rampage + immunity flags only)

**No `npc_spells_entries` DELETEs needed for Phase 5b.** Zone spell-list cache restart caveat does NOT apply. `#reloadworld` will be sufficient post-SQL.

### Akhevan Warder Special Note

Warders (158087-158094, 8 NPCs): HP 901,000, maxdmg=4, mindmg=0. These look like scripted event entities — maxdmg=4 at L60 is not a combat NPC, it's a script controller or checkpoint guard. Architect should confirm whether these are actual combat targets requiring HP cuts or event placeholders that should be excluded (similar to Area%dead NPCs in sleeper).

Special abilities: `7,1^12,1^13,...^23,1` — ability 7 = rampage, ability 12 = innate dual wield. Very heavy immunity stack. If these are meant to be combat, they may be intentionally unkillable (maxdmg=4 means they do essentially zero damage — possible lore event guardians).

**RESOLVED (architect 2026-04-22):** Akhevan Warders are combat targets — pure caster adds, fight entirely via spell list 236 (Black Winds root, Silence, Lure of Shadows tash, Fling knockback). maxdmg=4 is the weapon-swing default for caster NPCs, not an event-entity flag. 6 Warder IDs: 158087-158091 and 158094. IDs 158092 (Eom_Va_Dyn) and 158093 (a_pool_of_shadows) are NOT Warders — confirmed via `WHERE name LIKE 'Akhevan%'` (6 rows returned). The original query ranged 158087-158094 without a name filter and caught 2 non-Warder NPCs. Decision #70: 158092 and 158093 scale in LB7 (Yaemiu trash tier), not LB6 (Warder tier). Phase 5b LB6 HP cut: 901,000 → 80,000 for all 6 true Warders.

### Config-Expert Role in Phase 5b Implementation

Identical to all prior phases:
1. No rule changes needed.
2. No `eqemu_config.json` or `.env` changes.
3. Post-SQL: `#reloadworld` via world telnet (port 9000) to propagate `npc_types`/`spawn2` changes.
4. Smoke verification via DB read-back.
5. **npc_spells_entries: 1 DELETE needed** — spell 1948 "Destroy" from list 229 (Aten Ha Ra non-destroy). Zone-restart caveat applies — infra-expert full-stack restart required post-SQL to flush in-memory spell list 229. Q67 decision: DELETE (confirmed per architect commit 25f4e8b + protocol-agent PBAE finding).
6. **Aten Ha Ra respawn: NO perl-expert task.** Architect default is to preserve native 1.8-2.0h cycle (`6480 + rand(720)` seconds). Decision #11/#45 precedent — no change needed.
7. **Akhevan Warder count CORRECTED:** 6 Warders (158087-158091, 158094), not 8. IDs 158092 (Eom_Va_Dyn) and 158093 (a_pool_of_shadows) are Yaemiu trash (LB7), not Warders (LB6). Decision #70 captured.
8. **LB13b PROMOTED to required** (Decision #79, 2026-04-22): infra-expert zone-process restart is now a required default task, not contingent. infra-expert joins implementation team alongside data-expert and config-expert.

---

## Phase 5b — Architect 12-Question Response (2026-04-22)

Architect asked 12 specific questions. Answers follow, all based on live DB queries.

### Q1: rule_values count (drift check)
**1,112 — confirmed, zero drift.** Same count since Phase 2 baseline.

### Q2: vexthal zone ruleset
```
short_name=vexthal, ruleset=1, expansion=3, insttype=0, version=0
```
**Confirmed:** ruleset=1 (default), expansion=3 (Luclin), insttype=0 (not a DZ zone). No version flag. No custom ruleset override.

### Q3: DZ/expedition check
`dynamic_zones` table: **0 rows** — confirmed. No DZ/expedition-only configuration for vexthal. All content is standard static-zone access.

### Q4: DT/Cazic-Touch sweep across VT headline boss spell lists

All VT headline boss spell list IDs confirmed:
- 229 (#Aten_Ha_Ra non-destroy), 230 (#Kaas_Thox_Xi_Ans_Dyek), 231 (#Kaas_Thox_Xi_Aten_Ha_Ra), 232 (#Thall_Va_Kelun), 233 (#Thall_Va_Xakra), 234 (#Va_Xi_Aten_Ha_Ra), 236 (Akhevan_Warder), 237 (#Diabo_Xi_Xin_Thall), 238 (#Diabo_Xi_Va_Temariel), 239 (#Diabo_Xi_Va), 540 (#Aten_Ha_Ra_ destroy), 1353 (#Thall_Xundraux_Diabo)

Spell IDs present across all 15 npc_spells_entries rows for these lists: 1948, 2144, 2157, 2162, 2163, 2164, 2167.

**DT HIT FOUND — spell 1948 "Destroy" in list 229 (#Aten_Ha_Ra non-destroy, NPC 158006):**
- cast_time=0, mana=0, effect_base_value1=-100,000
- npc_spells_entries for this row: `min_hp=0, max_hp=0` — fires at ANY HP level, no HP-threshold gating
- This IS a death-touch profile. Same mechanism as spell 982 (Phase 2 PoSky) and spell 2859 (Phase 5a Shei Vinitras).
- **Action required: DELETE FROM npc_spells_entries WHERE npc_spells_id=229 AND spellid=1948**

**Destroy variant (158096, list 540): CLEAN** — spell 1948 NOT in list 540. Only spells 2157, 2164, 2167.

Note: spell 1948 "Destroy" also exists in list 489 (Kerafyrm — Decision #12, untouched/out of scope).

Other spells in the VT boss lists — **all normal, no DT profile:**
- 2144 "Shadow Warding 5": cast_time=0, mana=0, effect_base_value1=0 — immunity buff, not damage
- 2157 "Word of Command": cast_time=0, mana=0, value=3000 — positive value, not damage
- 2162 "Black Winds": cast_time=4800, mana=180 — standard AoE, not DT profile
- 2163 "Lure of Shadows": cast_time=5000, mana=400 — standard, not DT
- 2164 "Silence of the Shadows": cast_time=1000, mana=0, value=1 — silence effect
- 2167 "Fling": cast_time=0, mana=0, value=-1 — knockback (1-point), NOT -100k DT

**Summary: 1 DT DELETE needed.** data-expert task: `DELETE FROM npc_spells_entries WHERE npc_spells_id=229 AND spellid=1948`

Zone-restart caveat APPLIES: npc_spells_entries changes require full zone process restart to flush in-memory spell list 229 (same as Phase 2 PoSky and Phase 5a Akheva precedent). infra-expert full-stack restart required after data-expert SQL.

### Q5: Yaemiu trash spell list audit

Non-headline VT raid_target=1 NPCs with spell lists: lists 1, 2, 8, 9, 448, 1472, 1473.

**Lists 448, 1472, 1473: EMPTY — 0 entries** (Eom_Centien_Xakra, Eom_Thall_Xakra, Eom_Senshali_Xakra families). No spells at all.

**Lists 1, 2, 8, 9 fully audited:** Standard cleric/wizard/paladin/shadow knight spell libraries respectively. All spells have cast_time > 0 or mana > 0 or effect_base_value1 > -5000. No DT profile spells in any trash spell list.

Largest negative values in trash lists: list 2 "Garrison's Superior Sundering" (-2000), "Agnarr's Thunder" (-2350), "Strike of Solusek" (-2740) — these are wizard DD spells, not DT profile (all have cast_time > 5000, mana > 400). Not a concern.

**VERDICT: No DT instakills in VT trash spell lists. Clear.**

### Q6: Phase 5b respawn philosophy — 24h on Aten Ha Ra

Decision #8 = 24h for endgame tier. For VT:
- 9 wing bosses (158007-158015): standing spawn2 at 468,720s (~130h). These have spawn2 rows and CAN be updated to 86,400s (24h).
- #Thall_Va_Xakra (158016): standing spawn2 at 140,616s (~39h). Already different from wing bosses — architect to decide whether to normalize to 24h or leave.
- Aten Ha Ra (158006 and 158096): **no spawn2 rows**. Event-spawned. Post-death respawn hardcoded in Perl at ~1.8-2.0h via `quest::setglobal("aten",1,3,"M$spawntime")`. No `spawn2.respawntime` UPDATE possible for Aten Ha Ra — SQL can't touch it.
- Va_Dyn_Khar (158081): already at 21,600s (6h) — already in range.

**No config/rule concern with 24h on VT wing bosses.** The 63× HP gap (1.9M→~30k) is a data-expert concern, not config. There is no minimum respawn rule, no respawn-floor rule, no raid-tier respawn rule. The spawn2 UPDATE to 86,400s is safe from a rules/config standpoint.

Aten Ha Ra's 1.8-2.0h post-death respawn via Perl qglobal is **already very short** relative to Decision #8's 24h intent. If architect wants to lengthen it to align with Decision #8, that requires perl-expert editing `#Aten_Ha_Ra.pl` line `$spawntime = 6480 + $variance` — currently targeting ~1.8-2.0h. A 24h equivalent would be `$spawntime = 86400`.

### Q7: #reloadworld behavior for vexthal

Same as all prior phases. `npc_types` (HP/damage) and `spawn2` (respawn timer) changes propagate cleanly via `#reloadworld` (world telnet port 9000). No VT-specific cache behavior.

**EXCEPTION: Q4 DT DELETE.** The `npc_spells_entries` DELETE (spell 1948 from list 229) requires a full zone process restart to flush vexthal's in-memory spell list — same as Phase 2 PoSky (list 118/449/969) and Phase 5a Akheva (list 196). `#reloadworld` alone will NOT flush it. infra-expert full-stack restart required after Phase 5b SQL.

### Q8: npc_types.hp bigint at 1,901,500

`npc_types.hp` column type: **bigint(20)**. Max value ≈ 9.2×10¹⁸. 1,901,500 is well within range — no overflow risk. Phase 5a confirmed Emperor Ssraeshza at 1,250,500 without issue; 1,901,500 is ~52% larger, no concern.

Titanium client HP bar rendering: the `hp_percent` display on the Titanium client is percentage-based, not absolute. The client renders a health bar from the `HP_Regen` opcode percentage field. Absolute HP values above ~2.1B can cause client-side rendering issues on some clients (32-bit signed integer limit), but 1,901,500 is orders of magnitude below that threshold. Clean.

### Q9: Backup table naming

Pattern confirmed: `_raid_scaling_luclin_b` — mirrors Phase 5a's `_luclin_a` and Phase 4b's `_velious_b`. Full set:
- `npc_types_backup_raid_scaling_luclin_b`
- `spawn2_backup_raid_scaling_luclin_b`
- `npc_spells_entries_backup_raid_scaling_luclin_b` (for the spell 1948 DELETE row)

### Q10: Spawn condition / spawn_conditions check

- `spawn_conditions` table for vexthal: **0 rows**
- `spawn_condition_values` table for vexthal: **0 rows**
- All 451 spawn2 rows in vexthal have `_condition=0, cond_value=1` — the unconditional default

**No VP-style condition filtering, no Ring War wave conditions, no Sleeper dormant/active conditions.** Standard unconditional spawn2 throughout. No accidental variant hits possible.

### Q11: Out-of-era / Fabled / expansion-filtered VT NPCs

Query on `id BETWEEN 158000 AND 158999 AND level >= 70`: **1 result:**
- ID 158095, `#Aten_Trigger`, L90, HP=50,000,000, `raid_target=0`

This is the event controller NPC from `#Aten_Trigger.pl`. L90, 50M HP, non-combat (raid_target=0). **Must be excluded from all npc_types UPDATEs.** It is already raid_target=0 so a `WHERE raid_target=1` scope guard will correctly exclude it. For belt-and-suspenders: architect should also add `AND id != 158095` or `AND level < 70` to any HP UPDATE scoped to vexthal.

No Fabled NPCs (name LIKE '%Fabled%') in 158000-158999 range: **0 rows**.

`npc_types` table has no min_expansion/max_expansion columns — expansion filtering is zone-level only (`zone.expansion=3` already correct). No per-NPC expansion exclusion columns exist in this schema.

### Q12: Cumulative rule drift summary — full project record

| Phase | rule_values count | Changes | Notes |
|-------|------------------|---------|-------|
| Pre-project baseline | 1,112 | — | Starting state |
| Phase 2 (Classic) | 1,112 | 0 | SQL only, no rules |
| Phase 3 (Kunark) | 1,112 | 0 | SQL only, no rules |
| Phase 4a (Velious non-ToV) | 1,112 | 0 | SQL only, no rules |
| Phase 4b (Velious ToV/Sleeper) | 1,112 | 0 | SQL only, no rules |
| Phase 5a (Luclin non-VT) | 1,112 | 0 | SQL + 1 Perl change (L13 EmpCycle respawn) |
| Phase 5b (Luclin VT) | 1,112 | 0 | SQL + DT DELETE + zone restart |

**Zero rule_values changes across the entire raid-scaling project.** The prior-pass rules (34 rows set during Phase 1 small-group-scaling) remain the governing ruleset. No new rules were added, modified, or removed in Phases 2-5b.

The project has been entirely data-layer: `npc_types` HP/damage updates, `spawn2` respawn timer updates, `npc_spells_entries` DT DELETEs (3 in Phase 2, 1 in Phase 5a, 1 in Phase 5b), and one Perl script respawn variable (Phase 5a #EmpCycle.pl).

---

## Phase 5b (Luclin VT) — Implementation Tasks LB13 / LB14

> **Stage 4: Build Log — 2026-04-22**
> Dispatched by team-lead after architecture complete + all 3 advisor sign-offs confirmed.

### Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| LB13 | `#reloadworld` via world telnet port 9000 | data-expert LB1-LB12 complete + backup tables confirmed | **Complete 2026-04-22** |
| LB14 | Smoke verification (per team-lead brief + architecture doc) | LB13 | **Complete 2026-04-22** |

### Pre-reload DB Gate Check (2026-04-22) — GATE FAILED

Ran same pre-reload dependency check as Phase 5a before issuing `#reloadworld`. Results:

**GATE FAILED — data-expert SQL not applied:**

- `npc_types_backup_raid_scaling_luclin_b` — DOES NOT EXIST
- `spawn2_backup_raid_scaling_luclin_b` — DOES NOT EXIST
- `npc_spells_entries_backup_raid_scaling_luclin_b` — DOES NOT EXIST
- Aten Ha Ra 158006 HP = 1,901,500 — PEQ default, unscaled (expected ~30k post-LB)
- Kaas Thox Xi Aten Ha Ra 158007 HP = 1,900,000 — PEQ default, unscaled
- Va_Dyn_Khar 158081 HP = 600,000 — unscaled (expected ~30k post-LB)
- Akhevan Warder 158087 HP = 901,000 — unscaled (expected 80,000 post-LB6)
- A_burrower_parasite 164089 HP = 840,000 — unscaled (expected 90,000 per Q68=A)

**Context:** DB is up and responsive, eqemu container running, all prior phase backup tables intact. Only Phase 5b tables absent, confirming this is not a DB wipe — data-expert's LB tasks simply have not been applied yet.

**Action taken:** Pinged data-expert + team-lead. Config-expert is standing by. Will re-run gate check and proceed to LB13 (#reloadworld) + LB14 (smoke) immediately upon data-expert confirmation.

---

### Pre-reload DB Gate Check (2026-04-22) — GATE PASS (data-expert confirmed)

data-expert confirmed LB1-LB12 complete. Gate re-run:

- `npc_types_backup_raid_scaling_luclin_b`: **124 rows** — PRESENT
- `spawn2_backup_raid_scaling_luclin_b`: **990 rows** — PRESENT
- `npc_spells_entries_backup_raid_scaling_luclin_b`: **1 row** — PRESENT

Gate PASS. Proceeding to LB13.

---

### Task LB13: #reloadworld — COMPLETE (2026-04-22)

Command issued:
```
docker exec akk-stack-eqemu-server-1 bash -c "(echo 'reloadworld'; sleep 3) | telnet 127.0.0.1 9000"
```

Response: `Reloading World...`

Zone-spell cache caveat: Phase 5b has one `npc_spells_entries` DELETE (spell 1948 from list 229). `#reloadworld` propagates `npc_types` and `spawn2` cleanly. In-memory spell list 229 in running vexthal zone processes requires a full zone-process restart to flush. Infra-expert vexthal zone restart required per Decision #79 (LB13b) before spell DELETE is live.

---

### Task LB14: Smoke Verification — PASS (all checks, 2026-04-22)

#### Critical Safety Checks

| Check | Expected | DB Value | Result |
|-------|----------|----------|--------|
| Kerafyrm 128089 HP | 3,500,000 UNCHANGED | 3,500,000 | PASS |
| The Sleeper 128094 HP | 3,500,000 UNCHANGED | 3,500,000 | PASS |
| Kerafyrm zone-clone 128095 HP | 3,500,000 UNCHANGED | 3,500,000 | PASS |
| List 229 spell 1948 (DELETED) | 0 rows | 0 | PASS |
| List 540 spell 1948 (UNCHANGED) | 0 rows | 0 | PASS |
| List 489 Kerafyrm spell 1948 (UNCHANGED) | 1 row | 1 | PASS |
| List 540 total spells (Word of Command/Silence/Fling) | 3 | 3 | PASS |

#### Aten Ha Ra Dual-Form (158006 / 158096)

| NPC | ID | HP | maxdmg | mindmg | npc_spells_id | Result |
|-----|----|----|--------|--------|---------------|--------|
| #Aten_Ha_Ra (non-Destroy) | 158006 | 180,000 | 600 | 200 | 229 | PASS |
| #Aten_Ha_Ra_ (Destroy variant) | 158096 | 180,000 | 600 | 200 | 540 | PASS |

#### Inner-VT Bosses 158007-158015 + Thall Va Xakra Dual 158016/158125

| NPC | ID | HP | maxdmg | Result |
|-----|----|----|--------|--------|
| #Kaas_Thox_Xi_Aten_Ha_Ra | 158007 | 160,000 | 800 | PASS |
| #Thall_Va_Kelun | 158008 | 150,000 | 600 | PASS |
| #Va_Xi_Aten_Ha_Ra | 158009 | 130,000 | 750 | PASS |
| #Diabo_Xi_Va_Temariel | 158010 | 140,000 | 770 | PASS |
| #Thall_Xundraux_Diabo | 158011 | 120,000 | 654 | PASS |
| #Diabo_Xi_Xin_Thall | 158012 | 125,000 | 750 | PASS |
| #Kaas_Thox_Xi_Ans_Dyek | 158013 | 100,000 | 650 | PASS |
| #Diabo_Xi_Va | 158014 | 85,000 | 654 | PASS |
| #Diabo_Xi_Xin | 158015 | 90,000 | 650 | PASS |
| #Thall_Va_Xakra (standing) | 158016 | 80,000 | 700 | PASS |
| #Thall_Va_Xakra (variant) | 158125 | 80,000 | 700 | PASS |

#### 6 Akhevan Warders + Va_Dyn_Khar + A_burrower_parasite (Q68=A)

| NPC | ID | HP | maxdmg | Result |
|-----|----|----|--------|--------|
| Akhevan_Warder | 158087 | 80,000 | 4 | PASS |
| Akhevan_Warder | 158088 | 80,000 | 4 | PASS |
| Akhevan_Warder | 158089 | 80,000 | 4 | PASS |
| Akhevan_Warder | 158090 | 80,000 | 4 | PASS |
| Akhevan_Warder | 158091 | 80,000 | 4 | PASS |
| Akhevan_Warder | 158094 | 80,000 | 4 | PASS |
| Va_Dyn_Khar | 158081 | 60,000 | 455 | PASS |
| A_burrower_parasite (thedeep) | 164089 | 90,000 | 1,100 | PASS |

#### Yaemiu Trash — Level-Tiered HP Sample

| Tier | Level | ID | Name | HP | Expected Range | Result |
|------|-------|----|------|----|----------------|--------|
| Eom | L66 | 158001 | Eom_Centien | 25,000 | 22-25k | PASS |
| Eom | L66 | 158028 | Eom_Va_Dyn | 22,000 | 22-25k | PASS |
| Pli | L64 | 158000 | Pli_Centien | 22,000 | 20-22k | PASS |
| Pli | L64 | 158029 | Pli_Va_Dyn | 20,000 | 20-22k | PASS |
| Zun | L61 | 158003 | Zun_Senshali | 18,000 | 18k | PASS |
| Zun | L61 | 158030 | Zun_Centien | 18,000 | 18k | PASS |
| Zov | L58 | 158002 | Zov_Va_Liako | 14,000 | 14-15k | PASS |

#### Spawn2 Respawn Timers

| NPC | ID | spawn2_id | respawntime | Expected | Result |
|-----|----|-----------|-----------|----|--------|
| #Kaas_Thox_Xi_Aten_Ha_Ra (row 1) | 158007 | 36361 | 86,400 | 86,400 (24h) | PASS |
| #Kaas_Thox_Xi_Aten_Ha_Ra (row 2) | 158007 | 36360 | 86,400 | 86,400 (both rows) | PASS |
| #Thall_Va_Kelun | 158008 | 36362 | 86,400 | 86,400 | PASS |
| #Va_Xi_Aten_Ha_Ra | 158009 | 36363 | 86,400 | 86,400 | PASS |
| #Diabo_Xi_Va_Temariel | 158010 | 36364 | 86,400 | 86,400 | PASS |
| #Thall_Xundraux_Diabo | 158011 | 36365 | 86,400 | 86,400 | PASS |
| #Diabo_Xi_Xin_Thall | 158012 | 36366 | 86,400 | 86,400 | PASS |
| #Kaas_Thox_Xi_Ans_Dyek | 158013 | 36367 | 86,400 | 86,400 | PASS |
| #Diabo_Xi_Va | 158014 | 36368 | 86,400 | 86,400 | PASS |
| #Diabo_Xi_Xin | 158015 | 36369 | 86,400 | 86,400 | PASS |
| #Thall_Va_Xakra (standing) | 158016 | 36370 | 86,400 | 86,400 | PASS |
| #Thall_Va_Xakra (variant) | 158125 | 36371 | 86,400 | 86,400 | PASS |
| Va_Dyn_Khar | 158081 | 36665 | 21,600 | 21,600 UNCHANGED | PASS |

#### Phase 5a Cross-Check (Safety — All Prior Work Intact)

| Check | ID | DB Value | Expected | Result |
|-------|----|----------|----------|--------|
| Emperor Ssraeshza HP | 162227 | 120,000 | 120,000 | PASS |
| Lord Inquisitor Seru HP | 159691 | 120,000 | 120,000 | PASS |
| List 179 spell 2859 (Shei Vinitras — PRESERVED) | — | 1 row | 1 | PASS |
| List 196 spell 2859 (Touch of Vinitras — DELETED) | — | 0 rows | 0 | PASS |

#### Backup Table Integrity Post-Reload

| Table | Rows |
|-------|------|
| npc_types_backup_raid_scaling_luclin_b | 124 |
| spawn2_backup_raid_scaling_luclin_b | 990 |
| npc_spells_entries_backup_raid_scaling_luclin_b | 1 |

Post-reload counts match pre-reload counts — no table corruption.

**ALL-CLEAR: LB13 (#reloadworld) COMPLETE. LB14 smoke PASS — all checks verified.**

**Outstanding action: infra-expert vexthal zone-process restart required (LB13b, Decision #79) to flush in-memory spell list 229 cache. spell 1948 DELETE will not be live in vexthal until zone reboots. Pinged infra-expert.**
