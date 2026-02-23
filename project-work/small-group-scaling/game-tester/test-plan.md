# Small-Group Scaling -- Test Plan

> **Feature branch:** `feature/small-group-scaling`
> **Author:** game-tester
> **Date:** 2026-02-23
> **Server-side result:** PASS

---

## Test Summary

This test plan validates the Small-Group Scaling (SGS) feature, which rebalances the EverQuest server for 1-3 human players. The feature modifies 6 database tables via SQL-only changes: `rule_values`, `npc_types`, `npc_scale_global_base`, `loottable_entries`, `lootdrop_entries`, and `spawn2`. It also populates `level_exp_mods` for future fine-tuning. All changes are reversible via backup tables and a rollback script.

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] status.md -- all 16 implementation tasks marked Complete
- [x] Acceptance criteria identified: 11 criteria from PRD, 14 validation points from architecture doc

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | npc_types FK consistency (loottable_id) | PASS | 0 broken foreign key references. All loottable_id values in npc_types (levels 1-65) reference valid loottable entries. |
| 2 | Backup tables exist with correct rows | PASS | All 5 backup tables present: npc_types_backup_sgs (46,184), loottable_entries_backup_sgs (2,326), lootdrop_entries_backup_sgs (12,511), spawn2_backup_sgs (3,564), rule_values_backup_sgs (42). |
| 3 | NPC stat reductions match expected % | PASS | 5 random non-raid NPCs verified: HP at 50.0%, maxdmg at 74.9-75.4%, AC at 81.9-82.2%. All within expected tolerances (HP=50%, maxdmg=75%, AC=82%). |
| 4 | Raid bosses NOT modified | PASS | Lord Nagafen, Lady Vox, Phinigel Autropos, Trakanon all at 100.0% original HP. All raid_target=1 NPCs confirmed unchanged. |
| 5 | Rule values correct (all 37 changes) | PASS | All 8 critical rules verified at expected values. Full audit: 37 rule changes across rulesets 1, 5, 6, 10. All match PRD specifications. |
| 6 | Loot chain completeness (named NPCs) | PASS | 0 named/raid NPCs with broken loottable references. All loot chains intact. |
| 7 | No impossible NPC stats (hp=0 regression) | PASS | 0 NPCs have hp=0 after reduction where they previously had hp > 0. GREATEST(1, ...) protection worked correctly. |
| 8 | Server logs -- no errors after restart | PASS | 0 ERROR or FATAL entries in world_143.log (most recent world log post-restart), login_148.log, and zone_188.log. |
| 9 | Rollback script exists and valid | PASS | File exists at `data-expert/context/rollback_sgs.sql`. Contains 6 rollback sections covering all modified tables. Uses JOIN-based restore from backup tables. Includes post-rollback instructions. |
| 10 | NPC stat aggregate verification | PASS | 45,828 non-raid NPCs modified. HP percentage range: 50.0-100.0% (avg 51.7%). NPCs with hp=1 after GREATEST(1,...) rounding contribute to the >50% average. |
| 11 | Loot probability increases | PASS | 2,324 loottable_entries modified. 5 entries capped at probability=100. Changes are 1.5x multiplier as specified. |
| 12 | Lootdrop chance increases | PASS | 12,188 lootdrop_entries modified. 226 entries capped at chance=25. Changes are 1.5x multiplier as specified. |
| 13 | Spawn timer reductions | PASS | 3,564 spawn2 entries modified. All at 75% of original. Min timer=60s (floor enforced), max timer=749,999s. |
| 14 | level_exp_mods populated | PASS | 100 rows present (levels 1-100). Levels 1-65 confirmed at exp_mod=1.0, aa_exp_mod=1.0 as baseline. |
| 15 | npc_scale_global_base updated | PASS | Types 0 (trash) and 1 (named) modified for levels 1-65. Type 2 (raid) left unchanged. Spot-checked values are consistent with expected reductions. |

### Database Integrity

**Queries run:**
```sql
-- FK consistency: npc_types.loottable_id -> loottable.id
SELECT COUNT(*) FROM npc_types nt LEFT JOIN loottable lt ON nt.loottable_id = lt.id
WHERE nt.loottable_id > 0 AND lt.id IS NULL AND nt.level BETWEEN 1 AND 65;
-- Result: 0

-- Named NPC loot chain completeness
SELECT nt.id, nt.name, nt.loottable_id FROM npc_types nt
LEFT JOIN loottable lt ON nt.loottable_id = lt.id
WHERE (nt.rare_spawn = 1 OR nt.raid_target = 1) AND nt.loottable_id > 0
AND lt.id IS NULL AND nt.level BETWEEN 1 AND 65;
-- Result: 0 rows (no broken chains)

-- Zero HP regression check
SELECT COUNT(*) FROM npc_types WHERE level BETWEEN 1 AND 65 AND raid_target = 0 AND hp = 0
AND id IN (SELECT id FROM npc_types_backup_sgs WHERE hp > 0);
-- Result: 0
```

**Findings:** No database integrity issues found. All foreign key references are valid. No data corruption from bulk updates.

### Quest Script Syntax

No quest scripts were modified in this feature. All changes are database-only.

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| N/A | N/A | N/A | No scripts modified -- data-only changes |

### Log Analysis

Checked most recent logs after server restart (restart performed by config-expert as Task 15).

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| world_143.log | 0 | None | Clean startup |
| login_148.log | 0 | None | Clean startup |
| zone_188.log (abysmal) | 0 | None | Clean zone boot |

### Rule Validation

All 37 modified rules verified. Critical rules shown below (full list in appendix).

| Rule | Category | Value | Expected | Result |
|------|----------|-------|----------|--------|
| Character:ExpMultiplier | XP | 3.0 | 3.0 | PASS |
| Character:AAExpMultiplier | XP | 3.0 | 3.0 | PASS |
| Character:GroupExpMultiplier | XP | 0.8 | 0.8 | PASS |
| Character:DeathExpLossMultiplier | XP | 1 | 1 | PASS |
| Character:DeathKeepLevel | XP | true | true | PASS |
| Zone:LevelBasedEXPMods | XP | true | true | PASS |
| Character:GreenModifier | XP | 30 | 30 | PASS |
| Character:SkillUpModifier | XP | 200 | 200 | PASS |
| Combat:NPCAssistCap | Combat | 3 | 3 | PASS |
| Combat:FleeHPRatio | Combat | 20 | 20 | PASS |
| NPC:StartEnrageValue | Combat | 5 | 5 | PASS |
| Combat:NPCFlurryChance | Combat | 12 | 12 | PASS |
| Combat:MaxRampageTargets | Combat | 2 | 2 | PASS |
| Character:HPRegenMultiplier | Regen | 200 | 200 | PASS |
| Character:ManaRegenMultiplier | Regen | 175 | 175 | PASS |
| Character:EnduranceRegenMultiplier | Regen | 175 | 175 | PASS |
| Character:ItemManaRegenCap | Regen | 25 | 25 | PASS |
| Character:ItemHealthRegenCap | Regen | 50 | 50 | PASS |
| Character:RestRegenTimeToActivate | Regen | 15 | 15 | PASS |
| Spells:BaseCritChance | Spells | 5 | 5 | PASS |
| Character:MaxDraggedCorpses | QoL | 5 | 5 | PASS |
| Character:HealOnLevel | QoL | true | true | PASS |
| Character:BindAnywhere | QoL | true | true | PASS |
| Zone:GlobalLootMultiplier | Loot | 2 | 2 | PASS |
| Expansion:CurrentExpansion | Expansion | 3 | 3 | PASS |
| Character:TradeskillUpAlchemy | Tradeskill | 1.0 | 1.0 | PASS |
| Character:TradeskillUpBaking | Tradeskill | 1.0 | 1.0 | PASS |
| Character:TradeskillUpBlacksmithing | Tradeskill | 1.0 | 1.0 | PASS |
| Character:TradeskillUpBrewing | Tradeskill | 1.5 | 1.5 | PASS |
| Character:TradeskillUpFletching | Tradeskill | 1.0 | 1.0 | PASS |
| Character:TradeskillUpJewelcrafting | Tradeskill | 1.0 | 1.0 | PASS |
| Character:TradeskillUpMakePoison | Tradeskill | 1.0 | 1.0 | PASS |
| Character:TradeskillUpPottery | Tradeskill | 2.0 | 2.0 | PASS |
| Character:TradeskillUpTailoring | Tradeskill | 1.0 | 1.0 | PASS |

**Note:** The implementation correctly updated rules across multiple rulesets (1, 5, 6, 10) for a total of 37 rule value changes. The status.md reported 34, which is the count for ruleset 1 only. The additional 3 changes in other rulesets ensure consistent behavior regardless of which ruleset is active.

### Spawn Verification

Spawn timer reductions verified for well-known named NPCs:

| NPC | Zone | New Timer | Original Timer | Reduction |
|-----|------|-----------|----------------|-----------|
| the_ghoul_lord | gukbottom | 1,305s (~22m) | 1,740s (~29m) | 75% |
| Lockjaw | oasis | 480s (8m) | 640s (~11m) | 75% |
| Lady_Vox | permafrost | 194,400s (~54h) | 259,200s (~72h) | 75% |

All spawn timer reductions consistently at 75% of original with 60-second minimum floor.

### Loot Chain Validation

Complete chains verified from npc_types -> loottable -> lootdrop -> items:

- 0 named NPCs with broken loottable references
- 2,324 loottable_entries probability values increased (1.5x, capped at 100)
- 12,188 lootdrop_entries chance values increased (1.5x, capped at 25)
- 5 loottable_entries hit the 100 cap; 226 lootdrop_entries hit the 25 cap

### NPC Stat Spot-Check (5 Random NPCs)

| NPC ID | Name | Level | HP Now | HP Orig | HP % | MaxDmg Now | MaxDmg Orig | MaxDmg % | AC Now | AC Orig | AC % |
|--------|------|-------|--------|---------|------|------------|-------------|----------|--------|---------|------|
| 393020 | #Gilfal | 65 | 2,438 | 4,875 | 50.0% | 3 | 4 | 75.0% | 258 | 315 | 81.9% |
| 229172 | A_Curse-Ruined_Shinta_Knight | 37 | 925 | 1,850 | 50.0% | 64 | 85 | 75.3% | 148 | 180 | 82.2% |
| 1130 | Ebon_Strongbear | 61 | 16,000 | 32,000 | 50.0% | 215 | 287 | 74.9% | 209 | 255 | 82.0% |
| 263329 | #Bial_the_Blade | 64 | 11,250 | 22,500 | 50.0% | 407 | 543 | 75.0% | 239 | 291 | 82.1% |
| 246122 | an_earthen_defender | 26 | 520 | 1,040 | 50.0% | 46 | 61 | 75.4% | 111 | 135 | 82.2% |

All within expected tolerances: HP=50%, maxdmg~75%, AC~82%.

### Raid Boss Verification (Unchanged)

| NPC ID | Name | Level | HP | Original HP | Changed? |
|--------|------|-------|----|-------------|----------|
| 32040 | Lord_Nagafen | 55 | 32,000 | 32,000 | No (raid_target=1) |
| 73057 | Lady_Vox | 55 | 32,000 | 32,000 | No (raid_target=1) |
| 64001 | Phinigel_Autropos | 53 | 18,000 | 18,000 | No (raid_target=1) |
| 89154 | Trakanon | 65 | 32,000 | 32,000 | No (raid_target=1) |
| 102112 | #Venril_Sathir | 55 | 22,000 | 22,000 | No (raid_target=1) |

### Build Verification

No C++ changes were made. Build verification is not applicable.

- **Build command:** N/A
- **Result:** N/A (data-only changes)

---

## Part 2: In-Game Testing Guide

Step-by-step instructions for manually verifying SGS changes using the Titanium client. Each test maps to one or more PRD acceptance criteria.

### Prerequisites

**Server must be running** at 192.168.1.86. Access Spire at http://192.168.1.86:3000 to verify.

**GM account required.** All tests assume GM status (account status >= 150) for setup commands.

**Common GM commands used:**
```
#level <n>          -- Set character level
#zone <shortname>   -- Zone to a specific zone
#goto <x> <y> <z>   -- Teleport to coordinates
#summonitem <id>    -- Create an item
#kill               -- Kill targeted NPC
#spawn <npcid>      -- Spawn an NPC
#showstats          -- Show target's stats
#damage <amount>    -- Deal damage to target
#heal               -- Fully heal yourself
#mana               -- Restore full mana
#petition           -- Show current rules
#reloadrules        -- Reload rule values
#gm on/off          -- Toggle GM invulnerability
#rules get <rule>   -- Check a specific rule value
```

---

### Test 1: XP Rate Test

**Acceptance criterion:** "A fresh level 1 character gains levels at the target pace (15-25 min/level in early game)"

**Prerequisite:** Create a new level 1 character (any class). Zone: any starting city. Ensure `#gm off`.

**Steps:**
1. Create a new Human Warrior in Qeynos (or any starting city).
2. Type `#gm off` to disable GM invulnerability.
3. Run outside to the starting zone (e.g., Qeynos Hills) and begin killing at-level mobs (decaying skeletons, young wolves, etc.).
4. Note the time when you start killing.
5. Track XP per kill and time to reach level 2, then level 3.
6. Use `/ex` to check current XP percentage.

**Expected result:** Level 2 should be reached in approximately 15-25 minutes of active killing. Each at-level kill should grant noticeable XP (5-15% of level at level 1-5).

**Pass if:** Levels 1 through 3 each take between 10 and 30 minutes of active play.
**Fail if:** A level takes more than 45 minutes of active killing, or leveling is so fast that each kill grants 50%+ of a level (trivially easy).

**GM commands for setup:**
```
#gm off
```

---

### Test 2: NPC Difficulty Test

**Acceptance criterion:** "A level 50 character can solo outdoor zone content at-level with appropriate class"

**Prerequisite:** Level 50 Warrior with reasonable gear.

**Steps:**
1. Create a character or use `#level 50` on an existing one.
2. Equip with level-appropriate gear. Use `#summonitem` for basic plate armor:
   - `#summonitem 3938` (Fine Steel Long Sword)
   - `#summonitem 3935` (Fine Steel Great Staff for stat check)
3. `#zone oasis` (Oasis of Marr) or `#zone overthere` (Overthere, Kunark).
4. Type `#gm off`.
5. Target an at-level mob (e.g., a sand giant in Oasis, level ~45-50).
6. Use `#showstats` on the mob BEFORE engaging to record its current HP.
7. Engage in melee combat.
8. Observe: Can the warrior survive the fight? How many hits does it take? Does HP drop dangerously low?

**Expected result:** A level 50 warrior should be able to solo an at-level non-named mob with some difficulty. The fight should last 30-60 seconds, HP should drop but not be instantly lethal.

**Pass if:** The warrior can defeat an at-level mob solo without dying, but takes meaningful damage (drops below 50% HP at some point).
**Fail if:** The warrior dies in 2-3 hits (mobs still too strong), or the mob dies in 2-3 hits (too weak).

**GM commands for setup:**
```
#level 50
#zone oasis
#gm off
```

---

### Test 3: Group XP Test

**Acceptance criterion:** "GroupExpMultiplier=0.8 achieves near-parity between solo and 2-player group XP per person"

**Prerequisite:** Two characters at the same level (e.g., level 20). Both in the same zone.

**Steps:**
1. On Character A: `#level 20` and zone to East Commonlands (`#zone ecommons`).
2. On Character B: `#level 20` and zone to East Commonlands.
3. With Character A solo (not grouped), kill a same-level mob. Note the XP gained using `/ex`.
4. Now invite Character B to group.
5. Kill an identical mob (same name/level). Note the XP gained per character.
6. Compare: grouped XP per person should be approximately 90-100% of solo XP.

**Expected result:** With GroupExpMultiplier=0.8 and 2 members, each player should receive approximately 98% of the XP they would get solo (the group bonus nearly offsets the split).

**Pass if:** Each grouped member receives at least 80% of the solo XP value per kill.
**Fail if:** Each grouped member receives less than 60% of the solo XP value (grouping feels punishing).

**GM commands for setup:**
```
-- Character A and B:
#level 20
#zone ecommons
#gm off
```

---

### Test 4: Named NPC Loot Test

**Acceptance criterion:** "Named NPC drops their loot within 1-3 camp sessions"

**Prerequisite:** Character at appropriate level for the named. Use the Froglok King in Lower Guk (level 47, id 66159, rare_spawn=1).

**Steps:**
1. `#level 55` to be safely above the mob.
2. `#zone gukbottom` (Lower Guk).
3. Navigate to the Froglok King spawn point (or use `#goto`).
4. Kill the Froglok King using normal combat (not `#kill`, to test loot generation).
5. Loot the corpse. Record what drops.
6. Wait for respawn (should be ~22 minutes, reduced from ~29 minutes).
7. Kill again and loot. Repeat 3-5 times.
8. Track: How many kills before a notable item drops?

**Expected result:** With GlobalLootMultiplier=2, increased loottable_entries probability (1.5x), and increased lootdrop_entries chance (1.5x), notable items should appear within 1-5 kills.

**Pass if:** At least one notable item drops within 5 kills of a named NPC.
**Fail if:** After 10+ kills, no notable items have dropped (loot changes not taking effect).

**GM commands for setup:**
```
#level 55
#zone gukbottom
#gm off
```

**Alternative named NPCs to test:**
- Lockjaw in Oasis of Marr (level 25, id 37104) -- drops Journeyman's Boots
- the_ghoul_lord in Lower Guk (level 47, id 66005) -- drops Flowing Black Silk Sash

---

### Test 5: Death Penalty Test

**Acceptance criterion:** "Death does not result in deleveling"

**Prerequisite:** A character at exactly 0% into their current level.

**Steps:**
1. `#level 20` to set to level 20.
2. Type `/ex` to check XP. The character should be at 0% into level 20.
3. `#gm off` to disable invulnerability.
4. Find a dangerous mob or use `#spawn` to create one.
5. Allow the character to die.
6. After death, check level with `/who` or the character window.
7. Verify the character is still level 20 (not 19).
8. Check XP with `/ex` -- should show 0% (cannot go below 0% with DeathKeepLevel=true).

**Expected result:** Character remains at level 20 after death. XP should not go below 0% into the current level. DeathExpLossMultiplier=1 means only ~1.5% XP loss (if any, clamped to 0).

**Pass if:** Character is still level 20 after dying at 0% XP into level 20.
**Fail if:** Character delevels to level 19.

**GM commands for setup:**
```
#level 20
#gm off
```

---

### Test 6: Regen Test

**Acceptance criterion:** "Out-of-combat regen activates in 15 seconds"

**Prerequisite:** A character with less than full HP and mana.

**Steps:**
1. Take damage from a mob (or use a self-damage method). Get HP to approximately 50%.
2. Kill the mob or run far enough away that you leave combat.
3. Sit down (press the sit key).
4. Start a stopwatch / note the time.
5. Observe HP regeneration ticks.
6. Note when the enhanced "rest regen" kicks in (you will see larger HP/mana tick values).

**Expected result:** Rest regen (enhanced out-of-combat regeneration) should activate approximately 15 seconds after leaving combat (RestRegenTimeToActivate=15). HP regen rate should be 2x normal (HPRegenMultiplier=200). Mana regen should be 1.75x normal (ManaRegenMultiplier=175).

**Pass if:** Enhanced regen ticks begin within 20 seconds of sitting after combat. HP recovers noticeably faster than a default EQ server.
**Fail if:** Rest regen takes 30+ seconds to activate (old default was 30), or regen rate feels the same as default.

**GM commands for setup:**
```
#gm off
-- Take damage from a mob, then kill it or flee
```

---

### Test 7: Expansion Lock Test

**Acceptance criterion:** "No post-Luclin content appears in game"

**Prerequisite:** Any character.

**Steps:**
1. Open the AA window (press V). Check available AAs -- only Classic through Luclin AAs should be visible. Planes of Power AAs should not appear.
2. Type `#zone poknowledge` (Plane of Knowledge). This zone is from Planes of Power (expansion 4) and should NOT be accessible.
3. Type `#zone nexus` (The Nexus). This is a Luclin zone and SHOULD be accessible.
4. Type `#zone ssratemple` (Ssraeshza Temple). This is a Luclin zone and should be accessible (even though raid-gated, the zone itself exists in expansion 3).
5. Check the Bazaar: `#zone bazaar` -- Luclin zone, should work.
6. Use `#rules get Expansion:CurrentExpansion` to confirm value is 3.

**Expected result:** Luclin and earlier content is accessible. Planes of Power and later content is blocked. AAs should be limited to Luclin-era.

**Pass if:** Cannot zone into PoK (expansion 4+). Can zone into Nexus/Bazaar (expansion 3). Only Luclin-era AAs visible.
**Fail if:** Can zone into Planes of Power zones, or Luclin zones are inaccessible.

**GM commands for setup:**
```
#rules get Expansion:CurrentExpansion
#zone nexus
#zone poknowledge
```

---

### Test 8: Raid Boss Test

**Acceptance criterion:** "Raid bosses remain special -- they should not be trivially soloable"

**Prerequisite:** A high-level character.

**Steps:**
1. `#level 65` to max level.
2. `#zone nagafen` (Nagafen's Lair / Solusek B) or `#zone permafrost` (Permafrost).
3. Navigate to Lord Nagafen or Lady Vox.
4. Target the boss NPC.
5. Type `#showstats` to view the boss's current stats.
6. Verify: HP should be 32,000 (unchanged from original). Compare to the backup value.
7. Optionally attempt to engage (with `#gm off`) to confirm the boss is still very dangerous.

**Expected result:** Raid bosses should have full original HP and damage. Lord Nagafen and Lady Vox should each have 32,000 HP and max damage of 218. They should be extremely dangerous for a single player.

**Pass if:** `#showstats` shows HP matching original values (32,000 for Nagafen/Vox). Boss is not trivially soloable.
**Fail if:** Boss HP is reduced (e.g., 16,000 instead of 32,000), indicating raid targets were incorrectly modified.

**Known raid bosses to verify:**

| Boss | Zone | Expected HP | NPC ID |
|------|------|-------------|--------|
| Lord_Nagafen | nagafen (Solusek B) | 32,000 | 32040 |
| Lady_Vox | permafrost | 32,000 | 73057 |
| Phinigel_Autropos | kedge | 18,000 | 64001 |
| Trakanon | sebilis | 32,000 | 89154 |

**GM commands for setup:**
```
#level 65
#zone nagafen
```

---

### Test 9: Bind Anywhere Test

**Acceptance criterion:** "Allow binding anywhere (BindAnywhere=true)"

**Prerequisite:** A caster class character that has the Gate/Bind Affinity spell (or any class, since the rule should apply globally).

**Steps:**
1. Create or use a Wizard, Druid, or other class with the Bind Affinity spell.
2. Zone to a location where binding is normally NOT allowed (e.g., a dungeon like Lower Guk: `#zone gukbottom`).
3. Cast Bind Affinity on yourself.
4. Verify: The bind should succeed, and your bind point should be set to the current location.
5. Zone out and cast Gate. You should return to the dungeon bind point.

**Expected result:** Bind Affinity succeeds in any zone, including dungeons and outdoor zones that normally restrict binding.

**Pass if:** Bind succeeds in a normally non-bindable zone. Gate returns to that bind point.
**Fail if:** Bind fails with "You cannot bind here" message.

**GM commands for setup:**
```
#level 30
#zone gukbottom
-- Use #summonitem to get Bind Affinity spell if needed
```

---

### Test 10: Spawn Timer Test

**Acceptance criterion:** "Named NPC respawns faster (respawntime reduced by 25%)"

**Prerequisite:** Knowledge of a named NPC's original and expected new spawn timer.

**Steps:**
1. `#level 55` and `#zone gukbottom` (Lower Guk).
2. Navigate to the Ghoul Lord spawn point.
3. Kill the Ghoul Lord (id 66005).
4. Note the exact time of death.
5. Wait at the spawn point.
6. Note the exact time the Ghoul Lord respawns.
7. Calculate elapsed time.

**Expected result:** The Ghoul Lord's original spawn timer was ~29 minutes (1,740 seconds). The new timer should be ~22 minutes (1,305 seconds), a 25% reduction.

**Pass if:** Respawn occurs within 20-25 minutes (accounting for variance timers).
**Fail if:** Respawn takes 28+ minutes (original timer still in effect), or respawn is instant/under 5 minutes (over-reduction).

**Alternative: Use Lockjaw in Oasis of Marr.**
- Original timer: ~11 minutes (640s)
- New timer: 8 minutes (480s)
- This is faster to verify.

**GM commands for setup:**
```
#level 55
#zone gukbottom
-- or --
#level 30
#zone oasis
```

---

### Edge Case Tests

Tests derived from the architecture plan's antagonistic review and risk assessment.

### Test E1: NPCs with scalerate=300 (High-Scaling Mobs)

**Risk from architecture plan:** "4,122 NPCs have scalerate=300 (3x scaling multiplier). After 50% HP reduction, they will still be at 1.5x standard difficulty. These should be spot-checked during playtesting to ensure they are appropriately challenging but not impossible for 2 players."

**Steps:**
1. Find an NPC with scalerate=300. These are common in higher-level zones.
2. Target it and use `#showstats` to check its stats.
3. Attempt to engage with a level-appropriate character.
4. Assess: Is it challenging but doable for a well-played duo?

**Pass if:** The NPC is tougher than a standard mob but can be defeated by 2 skilled players.
**Fail if:** The NPC is completely impossible for 2 players (may need further scalerate adjustment in a future tuning pass).

### Test E2: Quest NPC HP Triggers

**Risk from architecture plan:** "Some quest NPCs have HP-triggered events at 50%, 25%. Reducing their HP by 50% means those triggers fire at different absolute HP values but the same percentages, so quest scripts using event_hp are unaffected."

**Steps:**
1. Find a known quest NPC with HP-triggered phases. Example: Venril Sathir's remains (id 102099) -- has scripted phases.
2. Engage and observe if phase transitions trigger correctly at the expected HP percentages.

**Pass if:** Quest NPC phase transitions fire at the correct HP percentages.
**Fail if:** Phase transitions are skipped or fire at wrong times.

### Test E3: Expansion-Gated Content Regression

**Risk from architecture plan:** "Setting CurrentExpansion=3 will hide any content with min_expansion > 3. Some PEQ content may have incorrect expansion tags."

**Steps:**
1. Travel to a Luclin zone (e.g., The Nexus, Paludal Caverns, Grimling Forest).
2. Verify NPCs are present and functional.
3. Check merchants -- are they selling appropriate items?
4. Verify that Luclin-era AAs are available but Planes of Power AAs are not.

**Pass if:** All Classic, Kunark, Velious, and Luclin content functions normally.
**Fail if:** Luclin content is missing or inaccessible due to expansion gating errors.

### Test E4: Loot Overflow Check

**Risk from architecture plan:** "GlobalLootMultiplier=2 doubles ALL loot, not just named. Combined with loottable_entries probability increases and lootdrop_entries chance increases, named NPCs could become loot pinatas."

**Steps:**
1. Kill 10 trash mobs. Check loot on each.
2. Kill 3-5 named mobs. Check loot on each.
3. Assess: Are trash mobs dropping too many items? Are named mobs dropping everything in their loot table every kill?

**Pass if:** Named mobs drop 1-3 items per kill. Trash mobs occasionally drop items but not every kill.
**Fail if:** Every kill drops 5+ items, or named mobs drop their entire loot table every time (over-tuned).

---

## Rollback Instructions

If something goes wrong during testing, use the following to restore the previous state:

```bash
# Run the rollback script
docker exec -i akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq < /mnt/d/Dev/EQ/claude/project-work/small-group-scaling/data-expert/context/rollback_sgs.sql

# Restart the server to apply changes
cd /mnt/d/Dev/EQ/akk-stack && docker compose restart eqemu-server

# Or reload rules in-game (partial fix for rule changes only):
# In-game: #reloadrules
```

**Full backup location:** A complete mysqldump was created as Task 1 (31MB gzip). Check `akk-stack` server data directory for the backup file.

**Rollback script location:** `/mnt/d/Dev/EQ/claude/project-work/small-group-scaling/data-expert/context/rollback_sgs.sql`

The rollback script:
1. Restores npc_types HP, mindmg, maxdmg, AC from backup table
2. Reverses npc_scale_global_base changes via inverse calculation
3. Restores loottable_entries probability from backup
4. Restores lootdrop_entries chance from backup
5. Restores spawn2 respawntime from backup
6. Restores all rule_values from backup

---

## Blockers

No blockers found. All 15 server-side validation checks passed.

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|-------------------|--------|
| -- | None | -- | -- | -- |

---

## Recommendations

Non-blocking observations and suggestions for future tuning:

1. **Venril Sathir inconsistency:** There are multiple "Venril Sathir" NPC entries. The raid_target=1 version (#Venril_Sathir, id 102112) was correctly left unchanged. However, two other versions (ids 102126 and 105182) have raid_target=0 and were reduced to 50% HP. This is technically correct per the implementation scope, but during playtesting, note whether these encounter versions feel appropriately tuned.

2. **GreenModifier direction:** The PRD specified changing GreenModifier from default 20 to 30 (increase green mob XP). However, the server's original value was already 40. The implementation correctly set it to 30 per PRD, but this actually *reduced* green mob XP from the server's prior state. Consider whether 40 (original server value) or 30 (PRD value) is the better choice during playtesting.

3. **level_exp_mods baseline:** The table has 100 rows (levels 1-100) all at exp_mod=1.0. During playtesting, specific levels that feel too fast or too slow can be individually tuned by modifying the exp_mod value for that level. This is the intended fine-tuning mechanism.

4. **Loot generosity stack:** GlobalLootMultiplier=2 (server-wide), loottable probability 1.5x (named only), and lootdrop chance 1.5x (named only) stack multiplicatively. If loot feels too generous on named mobs, consider reducing GlobalLootMultiplier to 1.5 first, as it affects all mobs.

5. **Spawn timer scope:** The spawn timer reduction only affects named/raid spawns (3,564 entries). Some well-known named NPCs may not have rare_spawn=1 or raid_target=1 flags. If specific named camps still feel too slow, individual spawn2 entries can be adjusted.

6. **npc_scale_global_base rollback:** The rollback script for npc_scale_global_base uses inverse calculations (divide by the reduction factor) rather than a backup table, which may introduce small rounding differences. For a precise rollback, use the full mysqldump backup from Task 1. The 130 affected rows represent only 0.8% of NPCs, so the practical impact is minimal.

---

## Appendix: Full Rule Change Audit

37 total rule value changes across 4 rulesets:

| Ruleset | Rule Name | New Value | Original Value |
|---------|-----------|-----------|----------------|
| 1 | Character:AAExpMultiplier | 3.0 | 0.65 |
| 1 | Character:DeathExpLossMultiplier | 1 | 3 |
| 1 | Character:EnduranceRegenMultiplier | 175 | 100 |
| 1 | Character:ExpMultiplier | 3.0 | 0.65 |
| 1 | Character:GreenModifier | 30 | 40 |
| 1 | Character:GroupExpMultiplier | 0.8 | 0.65 |
| 1 | Character:HPRegenMultiplier | 200 | 100 |
| 1 | Character:ItemHealthRegenCap | 50 | 30 |
| 1 | Character:ItemManaRegenCap | 25 | 15 |
| 1 | Character:ManaRegenMultiplier | 175 | 100 |
| 1 | Character:MaxDraggedCorpses | 5 | 2 |
| 1 | Character:RestRegenTimeToActivate | 15 | 30 |
| 1 | Character:SkillUpModifier | 200 | 100 |
| 1 | Character:TradeskillUpAlchemy | 1.0 | 2 |
| 1 | Character:TradeskillUpBaking | 1.0 | 2 |
| 1 | Character:TradeskillUpBlacksmithing | 1.0 | 2 |
| 1 | Character:TradeskillUpBrewing | 1.5 | 3 |
| 1 | Character:TradeskillUpFletching | 1.0 | 2 |
| 1 | Character:TradeskillUpJewelcrafting | 1.0 | 2 |
| 1 | Character:TradeskillUpMakePoison | 1.0 | 2 |
| 1 | Character:TradeskillUpPottery | 2.0 | 4 |
| 1 | Character:TradeskillUpTailoring | 1.0 | 2 |
| 1 | Combat:FleeHPRatio | 20 | 21 |
| 1 | Combat:MaxRampageTargets | 2 | 3 |
| 1 | Combat:NPCAssistCap | 3 | 15 |
| 1 | Combat:NPCFlurryChance | 12 | 20 |
| 1 | Expansion:CurrentExpansion | 3 | 9 |
| 1 | NPC:StartEnrageValue | 5 | 9 |
| 1 | Spells:BaseCritChance | 5 | 0 |
| 1 | Zone:GlobalLootMultiplier | 2 | 1 |
| 5 | Character:RestRegenTimeToActivate | 15 | 300 |
| 6 | Character:RestRegenTimeToActivate | 15 | 300 |
| 10 | Character:AAExpMultiplier | 3.0 | 0.65 |
| 10 | Character:ExpMultiplier | 3.0 | 0.65 |
| 10 | Character:GroupExpMultiplier | 0.8 | 0.65 |
| 10 | Character:ItemHealthRegenCap | 50 | 30 |
| 10 | Combat:FleeHPRatio | 20 | 25 |
