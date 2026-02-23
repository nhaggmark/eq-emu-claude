# Research Findings — Small-Group Scaling Architecture

> Date: 2026-02-23
> Researcher: architect

---

## Open Question 1: Auto-Scaling vs Manual Stats

**Query:** What % of Classic-Luclin NPCs use auto-scaling (npc_scale_global_base) vs manually set stats?

**Method:** An NPC is "auto-scaled" if hp=0 AND all base stats are 0 (the NpcScaleManager fills them in at spawn time). If hp > 0, the NPC has manually set stats.

**Results (levels 1-65):**

| Metric | Count | Percentage |
|--------|-------|------------|
| Total NPCs | 46,184 | 100% |
| Auto-scaled (hp=0) | 356 | 0.8% |
| Manual stats (hp>0) | 45,828 | 99.2% |

**Breakdown by level range:**

| Level Range | Total | Auto-Scaled | Manual | Auto % |
|-------------|-------|-------------|--------|--------|
| 1-10 | 5,712 | 144 | 5,568 | 2.5% |
| 11-20 | 4,578 | 1 | 4,577 | 0.0% |
| 21-30 | 4,771 | 6 | 4,765 | 0.1% |
| 31-40 | 8,120 | 11 | 8,109 | 0.1% |
| 41-50 | 8,740 | 13 | 8,727 | 0.1% |
| 51-60 | 8,108 | 21 | 8,087 | 0.3% |
| 61-65 | 6,155 | 160 | 5,995 | 2.6% |

**Conclusion:** The vast majority (99.2%) of PEQ NPCs have manually set stats. Modifying `npc_scale_global_base` alone would only affect ~356 NPCs. To reduce NPC difficulty for the full population, we must either:
1. Directly UPDATE `npc_types` HP/damage/AC columns via SQL, OR
2. Use the ScaleNPC mechanism: however, the code only applies scaling to stats that are 0 in npc_types

**Critical finding from C++ code (`npc_scale_manager.cpp` line 66):**
```cpp
if (always_scale || npc->GetMaxHP() == 0) {
    npc->ModifyNPCStat("max_hp", std::to_string(scale_data.hp));
}
```
Scaling only applies when the NPC's stat is 0. NPCs with hp > 0 keep their manual values. This means npc_scale_global_base changes will NOT affect the 99.2% majority.

---

## Open Question 2: rare_spawn=1 Reliability

**Query:** Does `rare_spawn = 1` reliably identify named NPCs in PEQ?

**Results:**
- Total NPCs (levels 1-65): 46,184
- NPCs with `rare_spawn = 1`: 354
- NPCs with loot tables but NO `rare_spawn` flag: 34,266

**Well-known named NPCs checked:**

| NPC | Level | HP | rare_spawn | raid_target |
|-----|-------|----|-----------|-------------|
| Lord Nagafen | 55 | 32,000 | 0 | 1 |
| Lady Vox | 55 | 32,000 | 0 | 1 |
| Phinigel Autropos | 53 | 18,000 | 0 | 1 |
| Trakanon | 65 | 32,000 | 0 | 1 |
| Venril Sathir | 55 | 30,750 | 0 | 0 |

**Conclusion:** `rare_spawn = 1` is NOT reliable for identifying named NPCs. Major named/raid bosses like Nagafen, Vox, Phinigel, and Trakanon all have `rare_spawn = 0`. They use `raid_target = 1` instead.

The `rare_spawn` flag is used by the NPC scale manager to classify NPCs as type 1 (named), but only 354 NPCs have it. Additionally, the scale manager also classifies NPCs as named if their name starts with `#` or with an uppercase letter (see `GetNPCScalingType()`).

For loot/spawn adjustments, we need a different approach than relying solely on `rare_spawn = 1`.

---

## Open Question 3: Group XP Formula Verification

**Source:** `zone/exp.cpp`, `Group::SplitExp()` method (line 1122)

**Code analysis:**
```cpp
auto group_modifier = 1.0f;
if (RuleB(Character, EnableGroupMemberEXPModifier)) {
    if (EQ::ValueWithin(member_count, 2, 5)) {
        group_modifier = 1 + RuleR(Character, GroupMemberEXPModifier) * (member_count - 1);
    } else if (member_count == 6) {
        group_modifier = RuleR(Character, FullGroupEXPModifier);
    }
}

if (EQ::ValueWithin(member_count, 2, 6)) {
    if (RuleB(Character, EnableGroupEXPModifier)) {
        group_experience += static_cast<uint64>(
            static_cast<float>(exp) *
            group_modifier *
            RuleR(Character, GroupExpMultiplier)
        );
    }
}
```

**Formula:** `group_experience = exp + (exp * group_modifier * GroupExpMultiplier)`

Where `group_modifier` for 2-5 members = `1 + GroupMemberEXPModifier * (members - 1)`

**With default values (GroupMemberEXPModifier=0.2, GroupExpMultiplier=0.5):**
- 2 members: group_modifier = 1.2, bonus = exp * 1.2 * 0.5 = 0.6x, total = 1.6x, per-person = 0.8x
- 3 members: group_modifier = 1.4, bonus = exp * 1.4 * 0.5 = 0.7x, total = 1.7x, per-person = 0.567x

**With proposed values (GroupMemberEXPModifier=0.2, GroupExpMultiplier=0.8):**
- 2 members: bonus = exp * 1.2 * 0.8 = 0.96x, total = 1.96x, per-person = 0.98x
- 3 members: bonus = exp * 1.4 * 0.8 = 1.12x, total = 2.12x, per-person = 0.707x

**Current server values:** GroupExpMultiplier is already set to 0.65 (not the default 0.5).

**Conclusion:** With GroupExpMultiplier=0.8 and ExpMultiplier=3.0:
- Solo: 3.0x base XP
- 2-player group: each gets roughly 2.94x (0.98 * 3.0) -- nearly identical to solo
- 3-player group: each gets roughly 2.12x (0.707 * 3.0) -- slightly less per person but faster kills compensate

This is well-balanced for the PRD goals. Grouping is rewarded but not mandatory.

---

## Open Question 4: Respawn Timer Reduction Scope

**Current respawn times for rare_spawn=1 NPCs (sample):**
- Highest: 75,000 sec (~21 hours) - an_ancient_racnar in Veeshan
- Common range: 5,400-21,600 sec (1.5-6 hours) for dungeon named
- Some: 7,200 sec (2 hours) for outdoor named

**Analysis:** A global 25% reduction to ALL spawn2.respawntime would affect every mob in the game, including trash mobs. This would:
- Increase zone density (more mobs up at once relative to kill speed)
- Could make zones overwhelming for solo players (faster respawns = more adds)
- Would be a large, hard-to-test change affecting ~120,000+ spawn entries

**Recommendation:** Scope respawn reduction to named spawns ONLY. However, since `rare_spawn=1` only covers 354 NPCs, we need a better identification strategy:
1. Join spawn2 -> spawnentry -> npc_types WHERE (rare_spawn=1 OR raid_target=1)
2. Or identify named by loottable significance (NPCs whose loottables contain unique/no-drop items)

For Phase 1, use `rare_spawn=1 OR raid_target=1` as the filter. This covers the known flagged named and raid bosses. Missing named NPCs can be addressed in playtesting.

---

## Open Question 5: NPC Scale Global Base and Raid Bosses

**NPC Scaling Type Classification (from `npc_scale_manager.cpp` line 557):**
```cpp
int8 NpcScaleManager::GetNPCScalingType(NPC *&npc) {
    if (npc->IsRaidTarget()) return 2;       // raid type
    if (npc->IsRareSpawn() || name has '#' || name starts uppercase) return 1; // named type
    return 0;                                 // trash type
}
```

**Scale data exists for all three types (0, 1, 2) from level 1-90.**

Type 2 (raid) scale data at high levels:

| Level | HP | Min Dmg | Max Dmg | AC |
|-------|----|---------|---------|-----|
| 55 | 170,000 | 140 | 507 | 399 |
| 60 | 450,813 | 185 | 740 | 476 |
| 65 | 867,333 | 262 | 875 | 525 |

**But critically:** All known raid bosses have hp > 0 (manually set stats). Every raid boss checked has non-zero HP values (Lord Nagafen: 32,000 HP, Grieg Veneficus: 475,500 HP, etc.). The scaling manager only applies when hp=0.

**All raid bosses have `scalerate = 100`** but this is irrelevant because they all have manual stats.

**Conclusion:** `npc_scale_global_base` does NOT effectively affect raid bosses in PEQ because raid bosses all have manually set stats (hp > 0). The auto-scaling system was designed as a fallback for NPCs without manual stats, and PEQ has thoroughly populated manual stats for all significant NPCs.

Additionally, bots and mercs have `skip_auto_scale = true` hardcoded, so they bypass scaling entirely.

---

## Additional Findings

### Scalerate Distribution (levels 1-65)
| scalerate | Count |
|-----------|-------|
| 100 | 41,756 |
| 300 | 4,122 |
| 0 | 235 |
| Other | ~71 |

The 4,122 NPCs with scalerate=300 are likely already boosted NPCs (3x scaling). These should be investigated during implementation.

### Loot Table Counts
- Total unique loot tables (levels 1-65): 12,853
- Loot tables linked to rare_spawn=1 NPCs: 333
- Loot tables linked to raid_target=1 NPCs: 598

### Current Server State
- ExpMultiplier is already 0.65 (not the default 0.5)
- GroupExpMultiplier is already 0.65
- CurrentExpansion is set to 9 (needs to change to 3)
