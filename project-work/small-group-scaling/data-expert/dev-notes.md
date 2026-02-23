# Small-Group Scaling -- Dev Notes: data-expert

> **Feature branch:** `feature/small-group-scaling`
> **Agent:** data-expert
> **Task(s):** 1-6, 8-14
> **Date started:** 2026-02-23
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Create full database backup | -- | Complete |
| 2 | Create npc_types stat backup table | 1 | Complete |
| 3 | Create loottable_entries backup table | 1 | Complete |
| 4 | Create lootdrop_entries backup table | 1 | Complete |
| 5 | Create spawn2 backup table | 1 | Complete |
| 6 | Apply rule_values changes (~34 rules) | 1 | Complete |
| 8 | Reduce non-raid NPC stats in npc_types | 2 | Complete |
| 9 | Update npc_scale_global_base types 0,1 | 1 | Complete |
| 10 | Increase loottable_entries probability | 3 | Complete |
| 11 | Increase lootdrop_entries chance | 4 | Complete |
| 12 | Reduce spawn2 respawntime for named | 5 | Complete |
| 13 | Populate level_exp_mods table | 6 | Complete |
| 14 | Generate rollback SQL script | 8-12 | Complete |

---

## Execution Summary

All data-expert tasks executed successfully on 2026-02-23 with zero errors.

### Task 1: Full Database Backup
- Output: `data-expert/context/peq_backup_pre_sgs.sql.gz` (31MB gzipped)
- Complete mysqldump of the `peq` database before any modifications

### Tasks 2-5: Backup Tables Created

| Backup Table | Row Count | Description |
|---|---|---|
| `npc_types_backup_sgs` | 46,184 | id, hp, mindmg, maxdmg, AC for NPCs level 1-65 |
| `loottable_entries_backup_sgs` | 2,326 | loottable_id, lootdrop_id, probability for named/raid loot tables |
| `lootdrop_entries_backup_sgs` | 12,511 | lootdrop_id, item_id, chance for rare drops (chance < 20) |
| `spawn2_backup_sgs` | 3,564 | id, respawntime for named/raid spawn points |
| `rule_values_backup_sgs` | 41 | Full rows (all rulesets) for the 34 modified rule names |

### Task 6: Rule Values Applied (34 rules)
- All 34 target rules existed in the database (no INSERTs needed)
- UPDATEs applied across all rulesets (1, 5, 6, 10) where rules existed
- Verification query confirmed all ruleset_id=1 values match expected
- Key changes: ExpMultiplier 0.65->3.0, Expansion 9->3, HPRegenMultiplier 100->200

### Task 8: NPC Stats Reduced (non-raid, levels 1-65)

| Stat | Reduction | Rows Changed |
|---|---|---|
| HP | *0.50 | 44,384 |
| maxdmg | *0.75 | 44,259 |
| mindmg | *0.65 | 31,840 |
| AC | *0.82 | 44,318 |

- Spot-checked Cassius_Messus (level 20): HP 600->300, maxdmg 44->33, AC 86->71
- Verified raid targets (raid_target=1) NOT modified (Elite_Guard_Evanet HP=3,000,000 unchanged)
- mindmg had fewer changes because ~12,000 NPCs have mindmg=0 (excluded by WHERE mindmg > 0)

### Task 9: npc_scale_global_base Updated
- 130 rows updated (types 0 and 1, levels 1-65)
- Same percentage reductions as npc_types
- Type 2 (raid) entries left unchanged

### Task 10: loottable_entries Probability Increased
- 102 rows changed out of 2,326 backed up
- probability * 1.5 (capped at 100)
- Most entries already had probability=100 so were not affected

### Task 11: lootdrop_entries Chance Increased
- 12,188 rows changed out of 12,511 backed up
- chance * 1.5 (capped at 25) for items with chance < 20 and chance > 0
- 323 rows unchanged (had chance=0, excluded by WHERE chance > 0)

### Task 12: spawn2 Respawntime Reduced
- 3,564 rows changed (all backed-up rows)
- respawntime * 0.75 (minimum 60 seconds)

### Task 13: level_exp_mods Populated
- Table already existed with 100 rows
- 65 rows (levels 1-65) set to baseline 1.0 exp_mod, 1.0 aa_exp_mod
- Used INSERT...ON DUPLICATE KEY UPDATE to handle existing rows

### Task 14: Rollback Script Generated
- Output: `data-expert/context/rollback_sgs.sql`
- Covers: npc_types, npc_scale_global_base, loottable_entries, lootdrop_entries, spawn2, rule_values

---

## Observations

1. **Multiple rulesets:** The server has rules across rulesets 1, 5, 6, and 10. The UPDATE statements applied to all rulesets (no WHERE ruleset_id filter), so all rulesets now have SGS values. The backup table preserves the original per-ruleset values for rollback.

2. **mindmg gap:** Only 31,840 NPCs had mindmg changed vs ~44,000 for other stats. About 12,000 NPCs have mindmg=0, excluded by the WHERE mindmg > 0 filter. This is correct -- NPCs with mindmg=0 use a different damage calculation path.

3. **loottable_entries mostly at 100%:** Only 102 of 2,326 backed-up rows were changed. The vast majority of named/raid loot table entries already have probability=100. Loot improvement mainly comes from GlobalLootMultiplier=2 and lootdrop_entries.chance increases.

4. **npc_scale_global_base no dedicated backup:** The rollback script uses inverse math for this table. For a perfect restore, the full mysqldump backup should be used.

---

## Artifacts Produced

| File | Purpose |
|---|---|
| `data-expert/context/peq_backup_pre_sgs.sql.gz` | Full database backup (31MB) |
| `data-expert/context/rollback_sgs.sql` | Complete rollback script |
| `data-expert/dev-notes.md` | This execution log |

---

## Remaining Tasks (config-expert)

- **Task 7:** Verify rule_values against ruletypes.h
- **Task 15:** Server restart / rule reload (`#reloadrules` + `#reloadworld` or restart via Spire)
- **Task 16:** Smoke test validation (XP rates, NPC difficulty, loot drops, expansion lock)

---

## Context for Next Agent

All SQL data modifications for the Small-Group Scaling feature are complete. The database has been modified in place with backup tables for rollback. A rollback script exists at `data-expert/context/rollback_sgs.sql`.

The config-expert needs to:
1. Verify the rule changes (Task 7)
2. Restart the server or reload rules (Task 15)
3. Run smoke tests to validate the changes in-game (Task 16)

After config-expert completes, the game-tester agent should perform the full validation checklist from the architecture document.
