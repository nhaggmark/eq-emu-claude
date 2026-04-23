# Kunark Phase 3 — DB Investigation Findings

Date: 2026-04-22 (architect Phase 3)

## 1. Live Kunark raid_target=1 NPCs (in-era, 55-70)

All confirmed via DB queries; all have `raid_target=1` and working spawn2 entries
(excluding VP classic variants which are gated by `_condition`).

### Outdoor dragons (4)
| ID | Name | L | HP | dmg | Zone | Current respawn |
|----|------|---|----|----|------|-----------------|
| 86014 | Gorenaire | 60 | 32,000 | 139-500 | dreadlands | 54h |
| 94009 | Severilous | 60 | 32,000 | 139-500 | emeraldjungle | 54h |
| 91093 | Talendor | 60 | 32,000 | 139-500 | skyfire | 54h |
| 96089 | Faydedar | 55 | 32,000 | 103-236 | timorous | 54h |

### End-dungeon bosses (3)
| ID | Name | L | HP | dmg | Zone | Respawn |
|----|------|---|----|----|------|---------|
| 89154 | Trakanon | 65 | 32,000 | 144-630 | sebilis | 54h |
| 102112 | #Venril_Sathir (triggered) | 55 | 22,000 | 180-404 | karnor | 54h (but script-spawned) |
| 105153 | Drusella_Sathir | 55 | 15,750 | 51-310 | charasis | 54h |

### Chardok royals (3)
| ID | Name | L | HP | dmg | Zone | Respawn |
|----|------|---|----|----|------|---------|
| 103055 | Queen_Velazul_Di`zok | 62 | 30,000 | 68-220 | chardok | 1.5h |
| 103056 | Overking_Bathezid | 65 | 34,500 | 92-320 | chardok | 1.5h |
| 103080 | Prince_Selrach_Di`zok | 61 | 25,000 | 79-250 | chardok | 1.5h |

### City of Mist (2)
| ID | Name | L | HP | dmg | Zone | Respawn |
|----|------|---|----|----|------|---------|
| 90186 | Kilidna | 60 | 100,000 | 700-4,600 | citymist | 1.5h |
| 90093 | Lhranc | 60 | 19,000 | 120-305 | citymist | 13.67h |

### Veeshan's Peak — revamp variants (live — condition 2 = VeeshanNew = 1)
| ID | Name | L | HP | dmg | Respawn |
|----|------|---|----|----|---------|
| 108040 | Druushk | 70 | 470,000 | 370-1,567 | 80.9h |
| 108042 | Guardian_of_Veeshan | 70 | 600,000 | 380-1,273 | 45.8h |
| 108043 | Hoshkar | 70 | 536,000 | 406-1,603 | 80.6h |
| 108047 | Nexona | 70 | 800,000 | 385-2,475 | 74.8h |
| 108048 | Phara_Dar | 70 | 681,000 | 1,032-1,621 | 80.9h |
| 108050 | Silverwing | 70 | 454,000 | 554-1,295 | 78.1h |
| 108053 | Xygoz | 70 | 814,000 | 480-2,266 | 75.3h |

### Other
| ID | Name | L | HP | dmg | Zone | Notes |
|----|------|---|----|----|------|-------|
| 39115 | #Guardian_of_the_Seal | 70 | 87,000 | 300-900 | hole | **Already scaled in Phase 2** (12h respawn, HP 87k from 124k). No Phase 3 action. |
| 102127 | #The_Fabled_Drolvarg_Captain | 70 | 300,000 | 850-1,312 | karnor | Out of era (Fabled variant = post-Luclin). **Skip.** |

## 2. VP variant architecture — CRITICAL FINDING

VP has **two NPC sets** for the 6 dragons (not Guardian of Veeshan):
- **Revamp L70 (108040, 108043, 108047, 108048, 108050, 108053)**: spawn2 uses `_condition = 2 = VeeshanNew`
- **Classic-era L65-67 (108509-108517)**: spawn2 uses `_condition = 1 = VeeshanOld`

`spawn_condition_values`:
- Condition 1 (VeeshanOld): value = 0 → DISABLED (classic variants do NOT spawn)
- Condition 2 (VeeshanNew): value = 1 → ENABLED (revamp variants DO spawn)

**Per Decision #5 ("keep revamp variants"), we scale ONLY 108040-108053.**
Classic-era variants (108509-108517) stay dormant — they're disabled by spawn condition.
We still include them in the backup table as a safe over-capture.

## 3. Kunark raid-boss damage spells (no free-cast instakill found)

Checked all raid_target=1 L55-70 bosses in Kunark zones for `mana=0 AND cast_time=0 AND effect_base_value1 < -10000` (the Cazic Touch profile): **0 results.**

Highest-damage direct-damage spells on Kunark raid bosses:
| NPC | Spell | Base value | Mana | Cast | Recast |
|-----|-------|-----------|------|------|--------|
| 108047 Nexona | 5158 Dragon Harm Touch | -4,000 HP | 0 | 0 | 45,000ms |
| 108050 Silverwing | 5155 Breath of Turmoil | -2,500 HP | 0 | 0 | 12,000ms |
| 108040 Druushk | 5159 Shock Breath | -2,000 HP | 0 | 0 | 24,000ms |
| 108053 Xygoz | 5161 Lullaby of Xygoz | -1,500 HP | 0 | 0 | 12,000ms |
| 108048 Phara_Dar | 5163 Force Breath | -1,000 HP | 0 | 0 | 18,000ms |
| 103055 Queen_Velazul | 820 Flame Song of Ro | -850 HP | 0 | 0 | 12,000ms |

**Conclusion:** No `npc_spells_entries` DELETEs needed for Phase 3. These damage spells
are signature mechanics per Decision #11 (preserve all). Small-group compensation
via HP/damage UPDATE instead.

## 4. Q13 Kunark NPC resolution

### In-scope for Phase 3 (do nothing — already named-tier)

| ID | Name | L | HP | raid_target | spawns | Verdict |
|----|------|---|-----|-------------|--------|---------|
| 85208 | Xenevorash | 65 | 16,250 | 0 | No spawnentry | Script-spawned Monk epic NPC. Named-tier HP. **No Phase 3 action.** |
| 106008 | Vessel_Drozlin | 60 | 9,500 | 0 | cabeast (once) | Enchanter epic. Named-tier HP. **No Phase 3 action.** |
| 12172 | Thrackin_Griften | 55 | 7,875 | 0 | No spawnentry | Enchanter W.Karana step. Named-tier HP. **No Phase 3 action.** |
| 39069 | Caradon | 55 | 6,875 | 0 | hole | SK epic. Named-tier. **No Phase 3 action.** |
| 39155 | Kyrenna | 55 | 6,875 | 0 | No spawnentry | SK epic. Named-tier. **No Phase 3 action.** |
| 39165 | Mummy_of_Glohnor | 56 | 7,375 | 0 | No spawnentry | SK epic. Named-tier. **No Phase 3 action.** |
| 51144 | a_tortured_soul | 55 | 10,000 | 0 | No spawnentry | Script-spawned. Named-tier. **No Phase 3 action.** |
| 214078 | A_tortured_soul | 60 | 11,000 | 0 | potactics | Wrong zone (PoP — out of era). **No Phase 3 action.** |
| 78070 | The_Tangrin | 54 | 16,350 | 0 | fieldofbone | Enchanter epic Pearlescent Fragment. 2× scaled-named. **Optional trim — defer/skip for Phase 3.** |

### Renux Herkanor variants (all out of Kunark scope)

| ID | Name | L | HP | raid_target | Zone | Verdict |
|----|------|---|-----|-------------|------|---------|
| 2033 | Renux_Herkanor | 61 | 16,000 | 0 | qeynos2 (Classic) | Not Kunark era. **Skip.** |
| 12032 | Renux_Herkanor | 51 | 10,375 | 0 | qey2hh1 (Classic) | Not Kunark era. **Skip.** |
| 56172 | Renux_Herkanor | 51 | 16,000 | 0 | No spawns | Dormant dup. **Skip.** |
| 448200 | #Renux_Herkanor | 72 | 500,000 | 1 | No spawns (script-spawned) | L72 raid tier. Monk epic terminus. Likely spawned by a script giveitem. **Investigate / consider in-scope** — L72 with 500k HP is a hard wall. |

### Triggered Trakanon (Bard epic) — `#Trakanon` 89181

| ID | Name | L | HP | raid_target | Zone | Verdict |
|----|------|---|-----|-------------|------|---------|
| 89181 | #Trakanon | 65 | 16,000 | 0 | No spawnentry | Spawned via An_Undead_Bard (89168) → Trakanon script. Drops Undead Dragongut Strings. **HP already half standard; include in Phase 3 backup but no HP cut; apply consistent damage trim with standard Trakanon.** |

### Venril Sathir standard variant (Wizard epic) — 102126

| ID | Name | L | HP | raid_target | Verdict |
|----|------|---|-----|-------------|---------|
| 102126 | Venril_Sathir | 55 | 11,000 | 0 | **Already named-tier. No Phase 3 action.** |

### Faydedar weak variant — #Faydedar 96073

| ID | Name | L | HP | raid_target | Verdict |
|----|------|---|-----|-------------|---------|
| 96073 | #Faydedar | 55 | 32,000 | 1 | Script-spawned duplicate. No spawnentry. **Include in Phase 3 for consistency with main Faydedar 96089.** |

## 5. Special-abilities strings to consider

Only one problematic entry: **Kilidna 90186** has `4,1,0,15` — that's ability 4 (Ranged attack?) with param1=15, but combined with her 4,600 max damage this is a zone-traversal one-shot hazard.

Per audit: damage cap to ~1,000, HP cut 70% to 30k. `special_abilities` string doesn't need edit — HP+damage UPDATE is sufficient.

Other Kunark bosses with special_abilities worth noting:
- Gorenaire/Severilous/Talendor: `37,15` (SpecialAbility 37 = NPCScale? — audit target)
- VP dragons: `32,1,400` (SpecialAbility 32 with param 400) — likely hit-all-targets
- Trakanon (both): extensive immunities (10,13,14,15,17,23,26,28,31,43,45) — keep as-is per Decision #11

**No special_abilities edit planned for Phase 3.** All scaling via HP/damage/respawn.

## 6. No deferred items for Phase 4

None of the Q13 Kunark-era NPCs require deferral — all are either:
- Named-tier already (do nothing)
- Out of era (skip)
- Proper raid_target=1 in scope (handle in Phase 3)
- Script-spawned with raid_target=1 and no spawnentry (handle via npc_types UPDATE only; no spawn2 row to touch)
