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
| 7 | `#reloadworld` via Spire or in-game GM command | data-expert Tasks 1-6 committed | WAITING |
| 8 | Smoke verification of HP, respawn, spell list | Task 7 | WAITING |

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
