# Small-Group Scaling -- Dev Notes: config-expert

> **Feature branch:** `feature/small-group-scaling`
> **Agent:** config-expert
> **Task(s):** 7, 15, 16
> **Date started:** 2026-02-23
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 7 | Verify rule_values applied correctly | 6 | Complete |
| 15 | Server restart and rule reload | 6-13 | Complete |
| 16 | Smoke test validation | 15 | Complete |

---

## Task 7: Rule Values Verification

**Method:** Queried `rule_values` table for `ruleset_id = 1` with all 34 expected rule names. Cross-referenced each returned value against the expected values from the architecture document.

**Result: 34/34 PASS -- zero mismatches.**

| Rule | Expected | Actual | Status |
|------|----------|--------|--------|
| Character:AAExpMultiplier | 3.0 | 3.0 | PASS |
| Character:BindAnywhere | true | true | PASS |
| Character:DeathExpLossMultiplier | 1 | 1 | PASS |
| Character:DeathKeepLevel | true | true | PASS |
| Character:EnduranceRegenMultiplier | 175 | 175 | PASS |
| Character:ExpMultiplier | 3.0 | 3.0 | PASS |
| Character:GreenModifier | 30 | 30 | PASS |
| Character:GroupExpMultiplier | 0.8 | 0.8 | PASS |
| Character:HealOnLevel | true | true | PASS |
| Character:HPRegenMultiplier | 200 | 200 | PASS |
| Character:ItemHealthRegenCap | 50 | 50 | PASS |
| Character:ItemManaRegenCap | 25 | 25 | PASS |
| Character:ManaRegenMultiplier | 175 | 175 | PASS |
| Character:MaxDraggedCorpses | 5 | 5 | PASS |
| Character:RestRegenTimeToActivate | 15 | 15 | PASS |
| Character:SkillUpModifier | 200 | 200 | PASS |
| Character:TradeskillUpAlchemy | 1.0 | 1.0 | PASS |
| Character:TradeskillUpBaking | 1.0 | 1.0 | PASS |
| Character:TradeskillUpBlacksmithing | 1.0 | 1.0 | PASS |
| Character:TradeskillUpBrewing | 1.5 | 1.5 | PASS |
| Character:TradeskillUpFletching | 1.0 | 1.0 | PASS |
| Character:TradeskillUpJewelcrafting | 1.0 | 1.0 | PASS |
| Character:TradeskillUpMakePoison | 1.0 | 1.0 | PASS |
| Character:TradeskillUpPottery | 2.0 | 2.0 | PASS |
| Character:TradeskillUpTailoring | 1.0 | 1.0 | PASS |
| Combat:FleeHPRatio | 20 | 20 | PASS |
| Combat:MaxRampageTargets | 2 | 2 | PASS |
| Combat:NPCAssistCap | 3 | 3 | PASS |
| Combat:NPCFlurryChance | 12 | 12 | PASS |
| Expansion:CurrentExpansion | 3 | 3 | PASS |
| NPC:StartEnrageValue | 5 | 5 | PASS |
| Spells:BaseCritChance | 5 | 5 | PASS |
| Zone:GlobalLootMultiplier | 2 | 2 | PASS |
| Zone:LevelBasedEXPMods | true | true | PASS |

---

## Task 15: Server Restart

**Method:** Ran `docker compose restart eqemu-server` from the akk-stack directory.

**Result: SUCCESS.** Container `akk-stack-eqemu-server-1` restarted cleanly. No errors. Allowed 15 seconds for server initialization before proceeding to smoke tests.

**Command:**
```bash
cd /mnt/d/Dev/EQ/akk-stack && docker compose restart eqemu-server
```

**Output:**
```
Container akk-stack-eqemu-server-1 Restarting
Container akk-stack-eqemu-server-1 Started
```

---

## Task 16: Smoke Test Validation

### Check 1: NPC Stat Reduction -- PASS

Spot-checked `a_decaying_skeleton`, `a_fire_beetle` by comparing `npc_types` to `npc_types_backup_sgs`.

| NPC | Level | HP (new) | HP (orig) | Reduction | maxdmg (new) | maxdmg (orig) | AC (new) | AC (orig) |
|-----|-------|----------|-----------|-----------|--------------|---------------|----------|-----------|
| a_decaying_skeleton | 2 | 12 | 24 | 50% | 6 | 8 | 8 | 10 |
| a_fire_beetle | 2 | 12 | 24 | 50% | 6 | 8 | 8 | 10 |
| a_decaying_skeleton | 1 | 6 | 11 | ~55% | 5 | 6 | 7 | 8 |

HP reduced to approximately 50% of original. Max damage reduced to approximately 75%. AC reduced to approximately 80%. All within expected ranges from architecture doc (HP 50%, maxdmg 75%, AC 82%).

### Check 2: Raid Bosses Untouched -- PASS

Compared raid boss stats to backup. All four bosses have identical values:

| Boss | HP (new) | HP (orig) | maxdmg (new) | maxdmg (orig) | AC (new) | AC (orig) | raid_target |
|------|----------|-----------|--------------|---------------|----------|-----------|-------------|
| Lord_Nagafen | 32,000 | 32,000 | 218 | 218 | 230 | 230 | 1 |
| Lady_Vox | 32,000 | 32,000 | 218 | 218 | 230 | 230 | 1 |
| Phinigel_Autropos | 18,000 | 18,000 | 156 | 156 | 222 | 222 | 1 |
| Trakanon | 32,000 | 32,000 | 630 | 630 | 315 | 315 | 1 |

Raid bosses confirmed completely unchanged, as specified in architecture.

### Check 3: Backup Tables Exist with Correct Row Counts -- PASS

| Table | Row Count |
|-------|-----------|
| npc_types_backup_sgs | 46,184 |
| loottable_entries_backup_sgs | 2,326 |
| lootdrop_entries_backup_sgs | 12,511 |
| spawn2_backup_sgs | 3,564 |
| rule_values_backup_sgs | 42 |

All 5 backup tables present and populated. Row counts match what data-expert reported during task completion.

### Check 4: Expansion Lock -- PASS

```
Expansion:CurrentExpansion = 3
```

Confirmed locked to Luclin (expansion ID 3), changed from previous value of 9.

### Check 5: Loot Improvements Applied -- PASS

Sample of changed loottable_entries probabilities:

| loottable_id | probability (new) | probability (orig) | Increase |
|-------------|-------------------|--------------------| ---------|
| 161 | 15 | 10 | 1.5x |
| 164 | 15 | 10 | 1.5x |
| 169 | 22 | 15 | ~1.5x |
| 293 | 30 | 20 | 1.5x |
| 331 | 52 | 35 | ~1.5x |
| 411 | 45 | 30 | 1.5x |
| 982 | 45 | 30 | 1.5x |

All changes show the expected 1.5x multiplier on probability values.

### Check 6: Spawn Timer Reduction -- PASS

Sample of changed spawn2 respawn times:

| spawn2 id | respawntime (new) | respawntime (orig) | Reduction |
|-----------|-------------------|--------------------| ----------|
| 108 | 480 | 640 | 75% |
| 118 | 480 | 640 | 75% |
| 248 | 10,800 | 14,400 | 75% |
| 250 | 10,800 | 14,400 | 75% |
| 356 | 480 | 640 | 75% |

All changes show the expected 0.75x multiplier on respawn timers.

---

## Summary

**All 3 tasks complete. All checks PASS.**

- Task 7: 34/34 rules verified, zero mismatches
- Task 15: Server restart successful
- Task 16: 6/6 smoke test checks passed

The Small-Group Scaling implementation is verified and ready for game-tester validation.

---

## Context for Next Agent

The game-tester should now perform in-game validation per the Validation Plan in `architect/architecture.md`. Key items to test:
- Create a fresh character and verify accelerated leveling
- Test NPC difficulty at various level ranges (should be soloable but challenging)
- Verify named NPC loot drops within 1-3 kills
- Confirm expansion lock hides post-Luclin content
- Test death penalty (should not cause deleveling)
- Verify regen activates within ~15 seconds out of combat
- Confirm raid bosses are NOT trivially soloable (they should still be very difficult)
- Test rollback script from `data-expert/context/rollback_sgs.sql` to confirm reversibility
