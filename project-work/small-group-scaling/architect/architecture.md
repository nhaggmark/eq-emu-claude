# Small-Group Scaling -- Architecture & Implementation Plan

> **Feature branch:** `feature/small-group-scaling`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-02-23
> **Status:** Approved

---

## Executive Summary

This feature rebalances the EverQuest server for 1-3 human players by adjusting ~35 rule values, reducing NPC stats via direct SQL updates to `npc_types`, improving loot drop rates for named NPCs, and locking the expansion to Luclin. All changes are SQL-only (no C++ modifications) and fully reversible. The critical architectural finding is that PEQ's `npc_scale_global_base` auto-scaling system only covers 0.8% of NPCs -- the remaining 99.2% have manually set stats. Therefore, NPC difficulty reduction must be implemented through direct `npc_types` table modifications with a backup/restore strategy.

## Open Questions -- Resolved

### Q1: What % of Classic-Luclin NPCs use auto-scaling vs manually set stats?

**Answer: 0.8% auto-scaled, 99.2% manual.** Of 46,184 NPCs in levels 1-65, only 356 have hp=0 (auto-scaled). The remaining 45,828 have manually set HP, damage, AC, and all other stats. The `npc_scale_global_base` table is only a fallback for NPCs without manual stats.

**Impact:** Modifying `npc_scale_global_base` alone is insufficient. We must directly UPDATE the `npc_types` table to reduce HP, damage, and AC for the overwhelming majority of NPCs. This changes the implementation approach significantly from what the PRD assumed.

### Q2: Does `rare_spawn = 1` reliably identify named NPCs in PEQ?

**Answer: No.** Only 354 NPCs have `rare_spawn = 1`. Major named/raid bosses (Lord Nagafen, Lady Vox, Phinigel, Trakanon, Venril Sathir) all have `rare_spawn = 0`. They use `raid_target = 1` instead. The NPC scale manager classifies NPCs into three types: trash (type 0), named (type 1: rare_spawn=1 OR name starts with `#` or uppercase), and raid (type 2: raid_target=1).

**Impact:** For loot and spawn timer adjustments targeting "named NPCs," we must use a broader identification strategy: `raid_target = 1 OR rare_spawn = 1 OR name LIKE '#%'` combined with `loottable_id > 0`. The NPC scale manager's heuristic (uppercase first letter) is too broad for SQL updates since many trash mobs also have capitalized names.

### Q3: Confirm effective group XP multipliers with GroupExpMultiplier=0.8

**Answer: Confirmed.** From `zone/exp.cpp`, the Group::SplitExp formula is:

```
group_experience = base_exp + (base_exp * group_modifier * GroupExpMultiplier)
```

Where `group_modifier = 1 + GroupMemberEXPModifier * (members - 1)` for 2-5 members.

With proposed GroupExpMultiplier=0.8, GroupMemberEXPModifier=0.2 (unchanged default):
- 2 members: total pool = 1.96x base, per-person ~0.98x base -- nearly solo-equivalent
- 3 members: total pool = 2.12x base, per-person ~0.71x base -- slight per-person reduction offset by faster kills

Combined with ExpMultiplier=3.0, a 2-player group earns ~2.94x per person. This achieves the PRD goal of rewarding grouping without making solo inferior.

### Q4: Should spawn2.respawntime reduction be global or scoped to named spawns only?

**Answer: Scoped to named spawns only.** A global reduction would affect ~120,000+ spawn entries, increase zone mob density, and risk overwhelming solo players with faster-respawning trash. Named spawns are identified via: `rare_spawn = 1 OR raid_target = 1`. This covers 354 rare-flagged + additional raid-flagged NPCs. Missing named can be tuned during playtesting.

### Q5: Does npc_scale_global_base affect raid bosses or do they bypass auto-scaling?

**Answer: Raid bosses bypass auto-scaling in practice.** The `npc_scale_global_base` table has type-2 (raid) entries for levels 1-90, and the NPC scale manager classifies `raid_target = 1` NPCs as type 2. However, all known raid bosses in PEQ have manually set stats (hp > 0, damage > 0), so the scaling manager's conditional checks (`if hp == 0, then apply scaling`) never trigger. Raid bosses keep their manually set stats regardless of what is in `npc_scale_global_base`.

**Impact:** Raid boss difficulty must also be adjusted via direct `npc_types` UPDATE statements if desired, or left at current values as the PRD suggests (defer to companion system).

---

## Existing System Analysis

### Current State

**Rule System:** Server behavior is configured via `rule_values` table entries, loaded at boot, modifiable at runtime via `#rules` or `#reloadrules`. Rules are defined in `common/ruletypes.h` with defaults. Current server already has some non-default values (ExpMultiplier=0.65, GroupExpMultiplier=0.65, CurrentExpansion=9).

**NPC Stats:** 99.2% of NPCs in levels 1-65 have manually set HP, damage, and AC in the `npc_types` table. The `npc_scale_global_base` auto-scaling system exists but is a fallback that covers <1% of NPCs.

**Loot System:** Four-table chain: `npc_types.loottable_id` -> `loottable` -> `loottable_entries` (probability) -> `lootdrop` -> `lootdrop_entries` (individual item chance). 12,853 unique loot tables serve NPCs in levels 1-65.

**Spawn System:** `spawn2` table defines spawn points with `respawntime` in seconds. Named NPCs have respawn times ranging from 1,200 sec (20 min) to 75,000 sec (21 hours).

**XP System:** `zone/exp.cpp` implements the full XP pipeline. CalcEXP applies ExpMultiplier, zone modifier, con scaling, level-based mods, and FinalExpMultiplier. Group::SplitExp applies GroupMemberEXPModifier and GroupExpMultiplier. All governed by rules -- no C++ changes needed.

### Gap Analysis

| PRD Requirement | Current State | Gap |
|----------------|---------------|-----|
| ExpMultiplier = 3.0 | Currently 0.65 | Rule change needed |
| Expansion = Luclin (3) | Currently 9 | Rule change needed |
| NPC HP/damage reduced to ~50% | All NPCs have full manual stats | Direct npc_types UPDATE needed |
| Named loot improved | Default rates | loottable_entries/lootdrop_entries UPDATE needed |
| Named respawns faster | Default timers | spawn2 UPDATE needed (scoped) |
| Death penalty reduced | Default (3.5% loss, can delevel) | Rule changes needed |
| Regen boosted | Default (100%) | Rule changes needed |

---

## Technical Approach

### Architecture Decision

All changes use the least-invasive layers: **rules** and **SQL data modifications**. No C++ changes, no Lua scripts, no new tables. Everything is reversible by restoring backups or running rollback SQL.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `rule_values` | UPDATE ~35 rows | Rules are the primary server config mechanism. Hot-reloadable via `#reloadrules`. |
| `npc_types` | UPDATE HP/damage/AC columns | 99.2% of NPCs have manual stats. Only way to reduce difficulty without C++ changes. |
| `loottable_entries` | UPDATE probability column | Increases chance that named loot tables are rolled. |
| `lootdrop_entries` | UPDATE chance column | Increases individual item drop chances for rare items. |
| `spawn2` | UPDATE respawntime column | Reduces named NPC respawn timers for faster camp cycles. |
| `level_exp_mods` | INSERT rows | Enables fine-grained per-level XP tuning. |

### Data Model

No new tables or columns. All changes are value modifications to existing rows.

**Tables modified:**

1. **`rule_values`** -- ~35 rule updates (complete SQL in PRD)
2. **`npc_types`** -- Bulk UPDATE to reduce `hp`, `mindmg`, `maxdmg`, `AC` columns for non-raid NPCs
3. **`loottable_entries`** -- UPDATE `probability` for loot tables linked to named NPCs
4. **`lootdrop_entries`** -- UPDATE `chance` for items with low drop rates in named loot tables
5. **`spawn2`** -- UPDATE `respawntime` for spawns linked to named/raid NPCs
6. **`level_exp_mods`** -- INSERT per-level XP modifiers for fine-tuning

### NPC Stat Reduction Strategy

Since `npc_scale_global_base` only affects <1% of NPCs, we implement NPC difficulty reduction through direct `npc_types` column updates.

**Target reductions (balanced for 2-player group per PRD):**

| Stat | Reduction | SQL Expression |
|------|-----------|---------------|
| HP | 50% of current | `hp = GREATEST(1, ROUND(hp * 0.50))` |
| Max Damage | 75% of current | `maxdmg = GREATEST(1, ROUND(maxdmg * 0.75))` |
| Min Damage | 65% of current | `mindmg = GREATEST(1, ROUND(mindmg * 0.65))` |
| AC | 82% of current | `AC = GREATEST(1, ROUND(AC * 0.82))` |

**Scope:** All NPCs in levels 1-65 WHERE `raid_target = 0`. Raid targets are excluded per the PRD (defer to companion system). NPCs with `hp = 0` (auto-scaled) are also excluded since they use `npc_scale_global_base`.

**Backup strategy:** Before any UPDATE, create backup columns or a backup table:
```sql
CREATE TABLE npc_types_backup_sgs AS
SELECT id, hp, mindmg, maxdmg, AC FROM npc_types WHERE level BETWEEN 1 AND 65;
```

**Rollback:**
```sql
UPDATE npc_types nt
JOIN npc_types_backup_sgs bk ON nt.id = bk.id
SET nt.hp = bk.hp, nt.mindmg = bk.mindmg, nt.maxdmg = bk.maxdmg, nt.AC = bk.AC;
```

### NPC Scale Global Base Adjustments

Although only 0.8% of NPCs use auto-scaling, we should still update `npc_scale_global_base` for consistency. Apply the same percentage reductions to type 0 (trash) and type 1 (named) entries for levels 1-65. Type 2 (raid) entries are left unchanged.

### Loot Improvement Strategy

**loottable_entries.probability:**
- Scope: Loot tables linked to NPCs with `rare_spawn = 1 OR raid_target = 1`
- Change: Increase probability by 50%, capped at 100
- SQL: `UPDATE loottable_entries SET probability = LEAST(100, ROUND(probability * 1.5)) WHERE loottable_id IN (SELECT DISTINCT loottable_id FROM npc_types WHERE (rare_spawn = 1 OR raid_target = 1) AND loottable_id > 0)`

**lootdrop_entries.chance:**
- Scope: Items in loot drops linked to named/raid loot tables with chance < 20%
- Change: Increase chance by 50%, capped at reasonable values
- This targets the "very rare" drops that make camping painful

**GlobalLootMultiplier rule:**
- Set to 2 (doubles all loot drops server-wide)

### Spawn Timer Reduction Strategy

**Scope:** spawn2 entries linked (via spawnentry -> npc_types) to NPCs with `rare_spawn = 1 OR raid_target = 1`

**Change:** Reduce respawntime by 25%
```sql
UPDATE spawn2 s2
SET s2.respawntime = GREATEST(60, ROUND(s2.respawntime * 0.75))
WHERE s2.spawngroupID IN (
  SELECT DISTINCT se.spawngroupID
  FROM spawnentry se
  JOIN npc_types nt ON se.npcID = nt.id
  WHERE nt.rare_spawn = 1 OR nt.raid_target = 1
);
```

### Code Changes

#### C++ Changes
**None.** This is a core design constraint. All changes are data-layer only.

#### Lua/Script Changes
**None for initial implementation.** Lua Mod hooks (`GetExperienceForKill`, `MeleeMitigation`, `CommonDamage`, `HealDamage`, `CalcSpellEffectValue_formula`) are documented as future enhancement points for dynamic group-size scaling. These could be used if static tuning proves insufficient during playtesting.

#### Database Changes
See Implementation Sequence below for the complete ordered list of SQL operations.

#### Configuration Changes
All configuration is via `rule_values` table updates. The complete SQL for ~35 rule changes is provided in the PRD's Summary section and verified against `common/ruletypes.h` rule definitions.

**Rule name corrections needed (verified against ruletypes.h):**
- All rule names in the PRD match the definitions in `common/ruletypes.h`. Confirmed.
- Note: `Character:TradeskillUpBaking` etc. are `RULE_REAL` type, so values like `1.0` are correct.

---

## Implementation Sequence

All tasks are SQL-only (data-expert role) with config-expert verification support.

| # | Task | Agent | Depends On | Estimated Scope | Description |
|---|------|-------|------------|-----------------|-------------|
| 1 | Create full database backup | data-expert | -- | Small | `mysqldump` of the peq database before any changes |
| 2 | Create npc_types stat backup table | data-expert | 1 | Small | `CREATE TABLE npc_types_backup_sgs AS SELECT id, hp, mindmg, maxdmg, AC FROM npc_types WHERE level BETWEEN 1 AND 65` |
| 3 | Create loottable_entries backup table | data-expert | 1 | Small | Backup probability column for named loot tables |
| 4 | Create lootdrop_entries backup table | data-expert | 1 | Small | Backup chance column for rare-drop items |
| 5 | Create spawn2 backup table | data-expert | 1 | Small | Backup respawntime for named spawn points |
| 6 | Apply rule_values changes (~35 rules) | data-expert | 1 | Medium | Complete SQL from PRD, including expansion lock to 3 |
| 7 | Verify rule_values applied correctly | config-expert | 6 | Small | Query rule_values and cross-reference with ruletypes.h defaults |
| 8 | Reduce non-raid NPC stats in npc_types | data-expert | 2 | Large | Bulk UPDATE hp, mindmg, maxdmg, AC for ~45,000 NPCs (raid_target=0, hp>0, level 1-65) |
| 9 | Update npc_scale_global_base for types 0 and 1 | data-expert | 1 | Small | Apply same % reductions to auto-scale table (affects ~356 NPCs) |
| 10 | Increase loottable_entries probability for named | data-expert | 3 | Medium | UPDATE probability * 1.5 (cap 100) for named/raid loot tables |
| 11 | Increase lootdrop_entries chance for rare items | data-expert | 4 | Medium | UPDATE chance * 1.5 (cap at reasonable values) for low-chance items in named loot |
| 12 | Reduce spawn2 respawntime for named spawns | data-expert | 5 | Medium | UPDATE respawntime * 0.75 for spawn points linked to rare_spawn=1 or raid_target=1 NPCs |
| 13 | Populate level_exp_mods table | data-expert | 6 | Medium | INSERT per-level XP modifiers for levels 1-65 for fine-grained tuning |
| 14 | Generate rollback SQL script | data-expert | 8-12 | Small | Script to restore all backup tables to originals |
| 15 | Server restart and rule reload | config-expert | 6-13 | Small | Restart server or use `#reloadrules` / `#reloadworld` to apply changes |
| 16 | Smoke test validation | config-expert | 15 | Medium | Create test character, verify XP rates, NPC difficulty, loot drops, expansion lock |

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| npc_types bulk UPDATE corrupts data | Low | High | Backup table created BEFORE any changes. Rollback SQL prepared. |
| Rule names wrong (typo in SQL) | Low | Medium | All rule names verified against ruletypes.h source. UPDATE WHERE rule_name= will silently fail if wrong (0 rows affected). Check row counts. |
| NPC stats too low (trivial content) | Medium | Medium | Balance for 2-player as specified. Can adjust multipliers during playtesting. Level-based fine-tuning via level_exp_mods. |
| NPC stats too high (still impossible) | Low | Medium | Reduction percentages based on PRD analysis. Playtesting will reveal issues. Further reduction is a simple SQL update. |
| Loot too generous | Medium | Low | On a 1-3 player private server, mild over-generosity is acceptable. Can reduce GlobalLootMultiplier from 2 to 1.5 if needed. |
| Respawn timer too fast | Low | Low | Only affects named spawns. Minimum 60 seconds enforced. |

### Compatibility Risks

**Titan client compatibility:** All changes are server-side numerical adjustments. The Titanium client displays whatever stats the server sends. No client-facing protocol changes. Zero compatibility risk.

**Expansion lock:** Setting CurrentExpansion to 3 will filter content in zones, NPCs, items, and AAs. Content with min_expansion > 3 will not load. This is the intended behavior. Post-Luclin content should not appear.

**Existing characters:** If any characters exist from previous play sessions, their XP and level are unaffected. New XP rates apply going forward. Reduced NPC stats apply immediately on next spawn.

### Performance Risks

**None significant.** The bulk UPDATE to npc_types runs once during implementation (not at runtime). Rule values are cached in memory. No additional query load during gameplay.

---

## Review Passes

### Pass 1: Feasibility

**Can this all be done with rules + SQL?** Yes, with one major caveat discovered during research.

The PRD assumed `npc_scale_global_base` changes would cover NPC stat reduction. Research revealed that 99.2% of NPCs have manual stats and bypass auto-scaling. The solution (direct `npc_types` UPDATE) is still SQL-only and reversible, but requires careful backup/rollback planning.

All ~35 rule changes have been verified against `common/ruletypes.h`. Every rule name exists, types match (INT/REAL/BOOL), and proposed values are within reasonable ranges.

The XP formula in `zone/exp.cpp` confirms that ExpMultiplier, GroupExpMultiplier, and all other XP-related rules are applied correctly through the code path.

**Hardest part:** The npc_types bulk UPDATE affecting ~45,000 rows. Must be done carefully with a verified backup and tested rollback procedure.

### Pass 2: Simplicity

**What can be cut or deferred?**

1. **level_exp_mods population (Task 13)** -- Can be deferred to playtesting phase. The global ExpMultiplier=3.0 handles the broad strokes. Per-level tuning is a refinement.

2. **lootdrop_entries.chance adjustment (Task 11)** -- The GlobalLootMultiplier=2 rule and loottable_entries.probability increase may be sufficient. Individual item chance tuning can be deferred if initial results are satisfactory.

3. **npc_scale_global_base updates (Task 9)** -- Affects only 356 NPCs. Low priority but low effort. Keep it.

**Everything else is essential** for the PRD goals. The rule changes and npc_types stat reduction are the core of the feature.

### Pass 3: Antagonistic

**What could go wrong?**

1. **Wrong rule names:** If a rule_name in the UPDATE statement has a typo, the UPDATE silently affects 0 rows. **Mitigation:** Verify each UPDATE returns "1 row affected" (or "Rows matched: 1"). All names double-checked against ruletypes.h.

2. **NPC scaling not applying after npc_types changes:** The ScaleNPC code checks `if (hp == 0)` before applying scaling. After we set hp to 50% of original, it will still be > 0, so auto-scaling is correctly bypassed. No conflict.

3. **Loot changes being too generous:** GlobalLootMultiplier=2 doubles ALL loot, not just named. Combined with loottable_entries probability increases and lootdrop_entries chance increases, named NPCs could become loot pinatas. **Mitigation:** Apply changes incrementally. Start with rule change only, test, then add SQL loot adjustments if needed.

4. **Breaking quest NPCs:** Some quest NPCs in npc_types have hp > 0 for scripted encounters (HP-triggered events at 50%, 25%, etc.). Reducing their HP by 50% means those triggers fire at different absolute HP values but the same percentages, so quest scripts using `event_hp` are unaffected (they use percentage thresholds).

5. **Economy effects:** Faster loot and more drops could flood the economy. **Irrelevant** for a 1-3 player private server.

6. **Expansion lock breaking content:** Setting CurrentExpansion=3 will hide any content with min_expansion > 3. Some PEQ content may have incorrect expansion tags. **Mitigation:** Playtesting will reveal any wrongly-gated content. Individual content_flags can override.

7. **NPCs with scalerate=300:** 4,122 NPCs have scalerate=300 (3x scaling). These are already boosted NPCs and reducing their stats by 50% still leaves them at 1.5x standard. This seems appropriate -- they were designed to be harder than normal.

### Pass 4: Integration

**Ordering dependencies:**

1. **Backup MUST come first** (Tasks 1-5). No data modifications without backup.
2. **Rule changes (Task 6) are independent** of NPC/loot changes (Tasks 8-12). Can be applied and tested separately.
3. **NPC stat reduction (Task 8) uses the backup from Task 2.** Must run after backup.
4. **Loot changes (Tasks 10-11) use backups from Tasks 3-4.** Must run after those backups.
5. **Spawn timer changes (Task 12) use backup from Task 5.** Must run after that backup.
6. **Rollback script (Task 14) must be generated AFTER all modifications** so it references the correct backup tables.
7. **Server restart (Task 15) should come AFTER all changes** to load everything in one cycle.
8. **Smoke test (Task 16) is the final step.**

Tasks 8-13 can run in any order relative to each other (they modify different tables). Tasks 2-5 can run in parallel.

---

## Validation Plan

The game-tester agent should verify the following after implementation:

- [ ] All rule_values changes confirmed via `#rules` in-game command (spot-check 5+ rules)
- [ ] Expansion locked to Luclin: no post-Luclin content visible (check zone list, AA list)
- [ ] Fresh level 1 character gains levels at ~15-25 min/level in starting zone
- [ ] Level 50 character can solo outdoor zone mobs at-level (test in EJ or OoT)
- [ ] Two level 50+ characters can clear a dungeon (Lower Guk or Sebilis) without wipes on trash
- [ ] Named NPC has reduced HP (compare to backup values -- should be ~50%)
- [ ] Named NPC drops loot within 1-3 kills (test at a known named camp)
- [ ] Named NPC respawns faster than default (check timer)
- [ ] Death does not result in deleveling (die at exactly 0% into a level)
- [ ] Out-of-combat regen activates within ~15 seconds
- [ ] Tradeskill skill-ups occur noticeably faster than default
- [ ] Raid bosses still have significant HP pools (should NOT be trivially soloable)
- [ ] Rollback script successfully restores original npc_types values when tested
- [ ] All backup tables exist and contain correct row counts

---

> **Next step:** Distribute implementation tasks to the data-expert agent
> per the sequence above. Config-expert provides verification support
> for Tasks 7, 15, and 16.
