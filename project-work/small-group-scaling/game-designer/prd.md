# Small-Group Scaling -- Product Requirements Document

> **Feature branch:** `feature/small-group-scaling`
> **Author:** game-designer
> **Date:** 2026-02-22
> **Status:** Approved

---

## Problem Statement

EverQuest was designed for groups of 6 and raids of 24-72 players. Our server targets 1-3 human connections. Without rebalancing, these players face:

- **XP grind measured in years**, not months, because solo/duo kill rates are a fraction of a full group's.
- **Group content that is numerically impossible** -- dungeon mobs with HP pools, damage output, and add mechanics balanced for 6 players simply cannot be overcome by 1-3.
- **Raid content that is entirely inaccessible** -- bosses tuned for 24-72 players.
- **Loot progression that stalls** -- named mobs in group dungeons drop gear at rates balanced for server populations of hundreds; 1-3 players camping a mob will see critical items on a timeline of weeks.
- **Hard-gated content** -- some flags, keys, and access quests assume a full group or raid is available.

The server must feel challenging but achievable. The goal is nostalgia with agency -- players should recognize the world they remember but be able to experience it at their scale.

## Goals

1. **A level 1-60 (Classic) or 1-65 (Luclin) character can reach max level in 40-80 hours of played time** through normal solo or duo gameplay, without powerleveling.
2. **A group of 1-3 players can clear any group dungeon in its intended level range** with appropriate class composition and gear, experiencing real challenge (deaths happen, strategy matters).
3. **Named NPCs and loot drops feel rewarding** -- a 1-3 player group camping a named mob should see its key loot within 1-3 hours of camping, not 8+.
4. **All Classic-Luclin content zones are accessible** -- no hard blocks on keys, flags, or level requirements that assume a full group or raid to obtain.
5. **Raid bosses remain special** -- they should not be trivially soloable, but should be deferred to the companion system (Phase 4) rather than being numerically trivialized now. Document which raid encounters are hardwalled for 1-3 players.
6. **All changes are reversible** -- prefer `rule_values` and database tuning over C++ code changes. Changes can be reverted with `#reloadrules` or SQL without a server rebuild.

## Non-Goals

- **Companion/NPC recruitment system** -- that is Phase 4. This project does not design around having AI party members.
- **Custom items, quests, or NPCs** -- no new content creation. We are tuning existing systems only.
- **Class redesign** -- we are not changing spell effects, adding new AAs, or altering class mechanics. Spell/ability effectiveness is tuned via global multipliers only.
- **Post-Luclin content** -- nothing from Planes of Power or later.
- **Making the game trivially easy** -- this is a rebalancing, not a god-mode server. Deaths should still happen. Strategy should still matter.

## User Experience

### Player Flow

1. Player creates a character and enters the world. They notice XP flows at a pace where levels come every 20-40 minutes in the early game, gradually slowing to 1-2 hours per level at 50+.
2. A solo player can handle outdoor zones and simple dungeons at their level. Dungeon named mobs are tough but killable with preparation and consumables.
3. Two players grouping together can handle any group dungeon in their level range. Three players can push into content slightly above their level.
4. Named mobs drop their loot at improved rates. A camping session of 1-2 hours typically yields the target item.
5. Key and flag requirements are met through normal gameplay -- quest NPCs are accessible, key mobs are killable by small groups, and flagging events do not require a full raid.
6. Raid targets (Nagafen, Vox, Venril Sathir, the Velious dragons, Ssraeshza Temple bosses, etc.) remain formidable. Players know these are "come back later with companions" content.

### Example Scenario

A level 45 ranger and a level 44 enchanter decide to duo Upper Guk. They zone in and begin pulling frogloks. Each pull of 1-2 mobs is manageable -- the enchanter mezzes the add while the ranger tanks and DPSes. XP is meaningful; they gain roughly 10-15% of a level per hour. After 45 minutes of clearing toward the Frenzied Ghoul, they reach his spawn point. The named is tougher than the trash -- higher HP, hits harder -- but the duo can handle it with mez-rotation and kiting. He drops the Flowing Black Silk Sash on their second kill. They feel accomplished and move on to the next camp.

## Game Design Details

### Area 1: Experience Rate Scaling

**Problem:** At default rates, reaching level 65 solo takes thousands of hours. A full group of 6 gets a 2.16x group modifier; 1-3 players get far less.

**Approach:** Increase the global experience multiplier so that solo and small-group play yields a satisfying progression pace.

**Rule changes:**

| Rule | Default | Proposed | Rationale |
|------|---------|----------|-----------|
| `Character:ExpMultiplier` | 0.5 | 3.0 | 6x increase over default. Solo kills at-level yield meaningful progress. |
| `Character:AAExpMultiplier` | 0.5 | 3.0 | Matches regular XP scaling so AA progression is not a separate grind wall. |
| `Character:GroupExpMultiplier` | 0.5 | 0.8 | Slightly increased so 2-3 player groups get rewarded for grouping without making solo inferior. |
| `Character:FinalExpMultiplier` | 1.0 | 1.0 | Keep at 1.0 as a reserved "event multiplier" knob. |
| `Character:DeathExpLossMultiplier` | 3 | 1 | Reduce death penalty from 3.5% to 1.5%. With fewer players to recover from setbacks, harsh death penalties become server-quitting moments. |
| `Character:DeathKeepLevel` | false | true | Players cannot delevel from death. Prevents the demoralizing cycle of losing a level solo. |
| `Zone:LevelBasedEXPMods` | false | true | Enable per-level XP modifiers from `level_exp_mods` table, giving us fine-grained control. |
| `Character:UseXPConScaling` | true | true | Keep con-based scaling active -- killing greens should give very little XP. |
| `Character:GreenModifier` | 20 | 30 | Slightly increase green con XP since small groups may need to farm slightly below their level. |
| `Character:SkillUpModifier` | 100 | 200 | 2x skill-up rate. With fewer mobs killed overall, skill progression should keep pace. |

**Target progression curve:**
- Levels 1-20: 15-25 minutes per level solo
- Levels 20-40: 25-45 minutes per level solo
- Levels 40-55: 45-90 minutes per level solo
- Levels 55-65: 90-180 minutes per level solo (AA grind begins)
- Total to 65: approximately 60-100 hours

**Fine-tuning mechanism:** The `level_exp_mods` table allows per-level adjustment. If certain level ranges feel too fast or too slow during playtesting, individual levels can be tuned without changing global multipliers.

### Area 2: Combat Difficulty -- NPC Tuning

**Problem:** Group dungeon mobs are tuned to be fought by 6 players (1 tank, 1 healer, 1 slower, 3 DPS). Their HP, damage, and AC assume that incoming damage, healing, and crowd control are distributed across a full group.

**Approach:** Use the `npc_scale_global_base` table to reduce NPC stats globally by level range, and supplement with rule-based adjustments. This is a database-only change that applies to all auto-scaled NPCs.

**NPC stat reduction targets (relative to default PEQ values):**

| Stat | Solo Target | 2-Player Target | 3-Player Target | Implementation |
|------|-------------|-----------------|-----------------|----------------|
| HP | 35-45% of default | 50-60% of default | 65-75% of default | `npc_scale_global_base` table |
| Max Damage | 60-70% of default | 70-80% of default | 80-90% of default | `npc_scale_global_base` table |
| Min Damage | 50-60% of default | 60-70% of default | 70-80% of default | `npc_scale_global_base` table |
| AC | 70-80% of default | 80-85% of default | 85-95% of default | `npc_scale_global_base` table |

**Design decision -- which target to balance for:** Since we cannot dynamically scale based on group size (without Lua scripting), we must pick a single set of values. **Balance for 2 players.** This means:
- Solo players face a genuine challenge -- they cannot mindlessly steamroll content, but skilled play makes it possible.
- 3-player groups find content slightly easier than intended, which is acceptable because they are already exceeding our minimum design target.

**Rule changes:**

| Rule | Default | Proposed | Rationale |
|------|---------|----------|-----------|
| `Combat:NPCAssistCap` | 5 | 3 | Reduce the number of NPCs that assist at once. Large assist trains are a group-wipe for 1-3 players. |
| `Combat:FleeHPRatio` | 25 | 20 | NPCs flee at lower HP. Fleeing NPCs pulling adds is especially dangerous for small groups. |
| `NPC:StartEnrageValue` | 9 | 5 | NPCs enrage at lower HP. Gives small groups more time to finish the kill before enrage. |
| `Combat:NPCFlurryChance` | 20 | 12 | Reduce flurry frequency. Each flurry hit is proportionally more dangerous when your tank is the only target. |
| `Combat:MaxRampageTargets` | 3 | 2 | Rampage hits fewer people. In a 3-player group, rampage hitting all 3 is a wipe. |
| `Combat:NPCCanCrit` | false | false | Keep NPC crits disabled. Spike damage is especially lethal for small groups. |
| `Spells:BaseImmunityLevel` | 55 | 55 | Keep default -- this controls stun/mez/fear immunity thresholds. |

**Named NPC handling:** Named NPCs in the PEQ database often have manually set stats (not auto-scaled). These will need individual SQL review. The architect should plan for a query that identifies named NPCs with `rare_spawn = 1` and flags those with stats significantly above the adjusted scaling curve.

### Area 3: Loot Accessibility

**Problem:** With 1-3 players, named camp times are multiplied because kill speed is lower and competition is zero (private server). Drop rates balanced for large server populations feel punishing.

**Approach:** Increase global loot multiplier and adjust named spawn timers where possible.

**Rule changes:**

| Rule | Default | Proposed | Rationale |
|------|---------|----------|-----------|
| `Zone:GlobalLootMultiplier` | 1 | 2 | Double global loot drops. Each kill has twice the chance of yielding useful items. |

**Database adjustments:**

| Table | Change | Rationale |
|-------|--------|-----------|
| `loottable_entries.probability` | Increase by 50% for named NPC loottables (capped at 100) | Named mob items should drop more frequently. |
| `loottable_entries.multiplier` | No change | Multiplier increases total rolls, but can lead to excessive loot. |
| `lootdrop_entries.chance` | Increase by 25-50% for items with chance < 20% (capped at reasonable values) | Very rare drops become merely uncommon. The goal is 1-3 hour camp sessions yielding the target item. |
| `spawn2.respawntime` | Reduce by 25% for spawns linked to named NPCs (`rare_spawn = 1`) | Faster respawn means more attempts per hour. |

**Lockout timers:** EQEmu supports expedition lockouts via `dynamic_zone_lockouts`. For Classic-Luclin content, most lockout mechanics are not relevant (LDoN/instanced content is post-era). No changes needed.

**Cash drops:** No changes to `loottable.mincash/maxcash`. Economy inflation is not a concern for a 1-3 player server.

### Area 4: Spell and Ability Effectiveness

**Problem:** In a small group, every class must perform above its typical role efficiency. A solo cleric must be able to sustain themselves; a duo without a dedicated healer must survive through other means.

**Approach:** Use global multipliers to slightly boost player effectiveness without changing individual spell data.

**Rule changes:**

| Rule | Default | Proposed | Rationale |
|------|---------|----------|-----------|
| `Character:HPRegenMultiplier` | 100 | 200 | 2x HP regen. Compensates for not having a dedicated healer in every group. |
| `Character:ManaRegenMultiplier` | 100 | 175 | 1.75x mana regen. Casters in small groups cannot afford long med breaks between every pull. |
| `Character:EnduranceRegenMultiplier` | 100 | 175 | Match mana regen scaling for melee endurance users. |
| `Character:ItemManaRegenCap` | 15 | 25 | Raise the cap so FT items are more impactful. |
| `Character:ItemHealthRegenCap` | 30 | 50 | Raise the cap so regen gear matters more. |
| `Character:HasteCap` | 100 | 100 | Keep default. Haste is already powerful. |
| `Character:RestRegenEnabled` | true | true | Keep out-of-combat regen active. |
| `Character:RestRegenTimeToActivate` | 30 | 15 | Halve the time to enter rest regen state. Reduces downtime between pulls. |
| `Spells:BaseCritChance` | 0 | 5 | Give all casters a 5% base spell crit chance. Helps compensate for fewer DPS in group. |
| `Spells:BaseCritRatio` | 100 | 100 | Keep crit damage at 2x (100% bonus). |

**Spell data (spells_new table):** No changes to individual spell data. The Lua Mod system (`lua_mod.h`) provides hooks for `CalcSpellEffectValue_formula`, `HealDamage`, and `CommonDamage` that could be used for targeted adjustments in Phase 2 if global multipliers prove insufficient. Document these hooks for the architect.

**Charm/Pet effectiveness:** Charm and pet classes (Enchanter, Necromancer, Magician, Beastlord) are disproportionately powerful in small groups because their pets effectively add a party member. No nerfs are planned -- this is working as intended for our use case. Charmed mobs using the `charm_*` columns in `npc_types` will naturally be strong.

### Area 5: Zone Accessibility

**Problem:** Several Classic-Luclin zones have hard gates that require specific keys, flags, or quest completions. Some of these gates assume group or raid capability to obtain.

**Approach:** Audit all zone access requirements for Classic-Luclin content and identify any that are impossible or impractical for 1-3 players. Propose solutions per-zone.

**Key accessibility issues by expansion:**

#### Classic

| Zone | Requirement | Issue for 1-3 Players | Proposed Solution |
|------|-------------|----------------------|-------------------|
| Plane of Fear | Level 46+ | Level gate only -- no issue | None needed |
| Plane of Hate | Level 46+ | Level gate only -- no issue | None needed |
| Plane of Sky | Level 46+, quest islands | Island mechanics require group coordination | Defer to companion system (Phase 4). Note: Sky is clearable by well-geared duo with strategy. |

#### Kunark

| Zone | Requirement | Issue for 1-3 Players | Proposed Solution |
|------|-------------|----------------------|-------------------|
| Sebilis | Key from Trakanon's Teeth | Key quest is solo-friendly | None needed |
| Howling Stones (Charasis) | Key from Lake of Ill Omen | Key quest is solo-friendly | None needed |
| Veeshan's Peak | Multiple raid-level key drops | Key requires killing raid-level dragons | Defer to companion system. Or: grant key via GM command/custom quest for playtesting. |

#### Velious

| Zone | Requirement | Issue for 1-3 Players | Proposed Solution |
|------|-------------|----------------------|-------------------|
| Sleeper's Tomb | Key from multiple Velious raids | Requires killing Temple of Veeshan bosses | Defer to companion system. |
| Kael Drakkel | Faction/level | Accessible but dangerous; NPC scaling handles difficulty | NPC scaling covers this |
| Temple of Veeshan | Faction + key from Kael | Key mob in Kael needs to be killable by small group | Covered by NPC stat reduction |

#### Luclin

| Zone | Requirement | Issue for 1-3 Players | Proposed Solution |
|------|-------------|----------------------|-------------------|
| Ssraeshza Temple | Key from Emperor's group | Emperor Ssraeshza is a raid target | Defer to companion system. |
| Vex Thal | Multiple keys from Luclin zones | VT key quest requires extensive raid completion | Defer to companion system. |
| Akheva Ruins | Accessible | Group dungeon -- NPC scaling handles it | NPC scaling covers this |

**General approach:** Group-accessible zones (those requiring keys obtainable by small groups) are handled by NPC stat reduction alone. Raid-gated zones are explicitly deferred to Phase 4 (companion system). A placeholder note in the MOTD or a custom `/serverinfo` command should inform players which zones are deferred.

**Rule changes:**

| Rule | Default | Proposed | Rationale |
|------|---------|----------|-----------|
| `Expansion:CurrentExpansion` | -1 | 3 | Lock to Luclin (expansion ID 3). Prevents post-Luclin content from appearing. |

### Area 6: Raid Content Accessibility

**Problem:** Raid bosses in Classic-Luclin have HP pools in the hundreds of thousands to millions, with abilities designed for 24-72 players. Even with NPC scaling, 1-3 players cannot meaningfully engage most raid content.

**Approach:** Explicitly categorize raid content into tiers of accessibility and document what is achievable now vs. what requires the companion system.

**Raid content tiers:**

#### Tier 1: Achievable by 3 well-geared players (with NPC scaling applied)
- Mini-bosses and "group raid" targets: Phinigel Autropos, Ragefire, Talendor
- Lower-tier named in outdoor zones

#### Tier 2: Achievable by 2-3 players with specific class composition and excellent gear
- Lord Nagafen (with NPC scaling, 2-3 geared 50+ players should be able to attempt)
- Lady Vox (similar to Nagafen)
- Some Kunark raid bosses (Venril Sathir, Trakanon -- with scaling)

#### Tier 3: Requires companion system (Phase 4) -- defer
- Temple of Veeshan dragons (Vulak, Dozekar, etc.)
- Sleeper's Tomb (The Sleeper, warders)
- Ssraeshza Temple (Emperor Ssraeshza)
- Vex Thal (Aten Ha Ra)
- Plane of Sky island bosses (mechanics-dependent)

**For this phase:** Apply NPC scaling uniformly (including to raid targets). This will make Tier 1 and some Tier 2 content accessible. Tier 3 content will be "easier than default" but still not achievable by 1-3 players -- that is by design. The companion system will bridge the gap.

**No special raid-specific rules are changed.** The global NPC stat reduction applies to raid targets too, which will lower their HP and damage substantially.

### Tradeskill Adjustments

**Rule changes:**

| Rule | Default | Proposed | Rationale |
|------|---------|----------|-----------|
| `Character:TradeskillUpAlchemy` | 2.0 | 1.0 | 2x faster alchemy skill-ups. Small server means fewer combine opportunities. |
| `Character:TradeskillUpBaking` | 2.0 | 1.0 | Same rationale. |
| `Character:TradeskillUpBlacksmithing` | 2.0 | 1.0 | Same. |
| `Character:TradeskillUpBrewing` | 3.0 | 1.5 | Same, proportional reduction. |
| `Character:TradeskillUpFletching` | 2.0 | 1.0 | Same. |
| `Character:TradeskillUpJewelcrafting` | 2.0 | 1.0 | Same. |
| `Character:TradeskillUpMakePoison` | 2.0 | 1.0 | Same. |
| `Character:TradeskillUpPottery` | 4.0 | 2.0 | Same. |
| `Character:TradeskillUpTailoring` | 2.0 | 1.0 | Same. |

### Miscellaneous Quality-of-Life

| Rule | Default | Proposed | Rationale |
|------|---------|----------|-----------|
| `Character:CorpseDecayTime` | 604800000 (7 days) | 604800000 | Keep default -- generous enough. |
| `Character:LeaveCorpses` | true | true | Keep corpse runs -- they add to the experience. |
| `Character:MaxDraggedCorpses` | 2 | 5 | Allow dragging more corpses. Solo players may die multiple times. |
| `Character:HealOnLevel` | false | true | Full heal on level-up. Feels good and reduces downtime at a moment of progression. |
| `Items:DisableNoDrop` | false | false | Keep No Drop items. Gear progression should still feel earned. |
| `World:FVNoDropFlag` | 0 | 0 | Do not enable FV-style trading. Keep items meaningful. |
| `Character:BindAnywhere` | false | true | Allow binding anywhere. Solo players need more flexible bind points. |
| `Bots:Enabled` | false | false | Keep bots disabled. The companion system (Phase 4) is the intended companion mechanism. |
| `Mercs:AllowMercs` | false | false | Keep mercs disabled. Same rationale as bots. |

## Affected Systems

- [ ] C++ server source (`eqemu/`) -- **Not required for initial implementation**
- [ ] Lua quest scripts (`akk-stack/server/quests/`) -- **Optional**: Lua Mods could provide dynamic group-size scaling in a future iteration
- [ ] Perl quest scripts -- **Not touched**
- [x] Database tables (`peq`) -- `rule_values`, `npc_scale_global_base`, `loottable_entries`, `lootdrop_entries`, `spawn2`, `level_exp_mods`
- [x] Rule values -- Primary implementation mechanism (~30 rules changed)
- [x] Server configuration -- `Expansion:CurrentExpansion` set to 3
- [ ] Infrastructure / Docker -- **Not touched**

## Dependencies

1. **Phase 0 completion** -- Server must be running with admin access verified (already done).
2. **Expansion lock** -- `Expansion:CurrentExpansion` must be set to 3 (Luclin) before NPC/loot tuning to ensure only era-appropriate content is loaded.
3. **Backup** -- Full database backup before any changes. All changes are SQL-based and reversible, but a backup is essential.

## Lua Mod Hooks (Future Enhancement Reference)

The following Lua Mod hooks from `zone/lua_mod.h` are available for dynamic scaling if static rules prove insufficient. These are NOT part of the initial implementation but should be documented for the architect:

- `GetExperienceForKill()` -- Could scale XP based on group size dynamically.
- `MeleeMitigation()` -- Could reduce NPC damage based on group size.
- `CommonOutgoingHitSuccess()` -- Could boost player damage when solo.
- `HealDamage()` -- Could boost healing when group is small.
- `CommonDamage()` -- Could apply a global damage modifier based on group composition.
- `CalcSpellEffectValue_formula()` -- Could scale spell effects based on group size.

These hooks allow Lua scripts in `quests/global/` to intercept and modify core formulas without C++ changes. They are hot-reloadable.

## Era Compliance

All systems being tuned exist in Classic-Luclin:
- Experience rules: present since Classic
- NPC scaling (`npc_scale_global_base`): server-side only, does not affect client
- Loot tables: present since Classic
- Spell system: present since Classic
- Zone access (keys, flags): all audited zones are Classic-Luclin
- Tradeskills: present since Classic
- AAs: introduced in Luclin (expansion 3), within our era lock

**No new game mechanics or client-facing features are introduced.** All changes are server-side numerical adjustments that the Titanium client handles transparently.

## Lore Review

This feature involves numerical tuning only -- no new NPCs, quests, dialogue, items, or narrative content. Lore review is **minimal and complete**:

- No NPC names, factions, or relationships are changed.
- No quest text or dialogue is modified.
- No items are added or renamed.
- Zone access changes are limited to unlocking existing content, not creating new paths.
- The world narrative remains intact; only the difficulty curve is adjusted.

**Lore review status: PASSED -- no lore concerns identified.**

## Open Questions

1. **npc_scale_global_base vs per-NPC stats:** What percentage of Classic-Luclin NPCs use auto-scaling vs. manually set stats? The architect needs to quantify this to determine if `npc_scale_global_base` changes cover enough of the NPC population or if bulk SQL updates to `npc_types` are also needed.

2. **Named NPC identification:** How reliably does `rare_spawn = 1` identify named NPCs in the PEQ database? Are there named mobs that lack this flag?

3. **Group XP formula specifics:** The group XP modifier applies as: 2 members = 1.2x, 3 = 1.4x, 4 = 1.6x, 5 = 1.8x, 6 = 2.16x. With `GroupExpMultiplier` at 0.8 (up from 0.5), confirm the effective multipliers are: 2 members = ~1.6x, 3 = ~1.8x. Validate this with the C++ code in `zone/exp.cpp`.

4. **Respawn timer reduction scope:** Reducing `spawn2.respawntime` globally by 25% affects ALL spawns, not just named mobs. Should this be scoped to only spawns linked to `rare_spawn = 1` NPCs, or is a global reduction acceptable?

5. **NPC scaling interaction with raid targets:** Does `npc_scale_global_base` affect raid bosses, or do they have manually set stats that bypass auto-scaling? The architect should verify this.

## Acceptance Criteria

- [ ] All rule_values changes are applied and verified via `#rules` in-game command
- [ ] Expansion locked to Luclin (`Expansion:CurrentExpansion = 3`)
- [ ] A fresh level 1 character gains levels at the target pace (15-25 min/level in early game)
- [ ] A level 50 character can solo outdoor zone content at-level with appropriate class
- [ ] Two level 50+ characters can clear a dungeon (e.g., Lower Guk, Sebilis) without wipes on trash
- [ ] Named NPC drops their loot within 1-3 camp sessions (not 8+)
- [ ] Death does not result in deleveling
- [ ] Out-of-combat regen activates in 15 seconds
- [ ] Tradeskill skill-ups occur at approximately 2x default rate
- [ ] No post-Luclin content appears in game
- [ ] All changes can be reverted with a SQL script restoring original rule_values

## Summary of All Rule Changes

For quick reference and implementation, here is the complete list of rule changes:

```sql
-- Experience
UPDATE rule_values SET rule_value = '3.0' WHERE rule_name = 'Character:ExpMultiplier';
UPDATE rule_values SET rule_value = '3.0' WHERE rule_name = 'Character:AAExpMultiplier';
UPDATE rule_values SET rule_value = '0.8' WHERE rule_name = 'Character:GroupExpMultiplier';
UPDATE rule_values SET rule_value = '1' WHERE rule_name = 'Character:DeathExpLossMultiplier';
UPDATE rule_values SET rule_value = 'true' WHERE rule_name = 'Character:DeathKeepLevel';
UPDATE rule_values SET rule_value = 'true' WHERE rule_name = 'Zone:LevelBasedEXPMods';
UPDATE rule_values SET rule_value = '30' WHERE rule_name = 'Character:GreenModifier';
UPDATE rule_values SET rule_value = '200' WHERE rule_name = 'Character:SkillUpModifier';

-- Combat
UPDATE rule_values SET rule_value = '3' WHERE rule_name = 'Combat:NPCAssistCap';
UPDATE rule_values SET rule_value = '20' WHERE rule_name = 'Combat:FleeHPRatio';
UPDATE rule_values SET rule_value = '5' WHERE rule_name = 'NPC:StartEnrageValue';
UPDATE rule_values SET rule_value = '12' WHERE rule_name = 'Combat:NPCFlurryChance';
UPDATE rule_values SET rule_value = '2' WHERE rule_name = 'Combat:MaxRampageTargets';

-- Regen and Sustainability
UPDATE rule_values SET rule_value = '200' WHERE rule_name = 'Character:HPRegenMultiplier';
UPDATE rule_values SET rule_value = '175' WHERE rule_name = 'Character:ManaRegenMultiplier';
UPDATE rule_values SET rule_value = '175' WHERE rule_name = 'Character:EnduranceRegenMultiplier';
UPDATE rule_values SET rule_value = '25' WHERE rule_name = 'Character:ItemManaRegenCap';
UPDATE rule_values SET rule_value = '50' WHERE rule_name = 'Character:ItemHealthRegenCap';
UPDATE rule_values SET rule_value = '15' WHERE rule_name = 'Character:RestRegenTimeToActivate';

-- Spell Effectiveness
UPDATE rule_values SET rule_value = '5' WHERE rule_name = 'Spells:BaseCritChance';

-- Quality of Life
UPDATE rule_values SET rule_value = '5' WHERE rule_name = 'Character:MaxDraggedCorpses';
UPDATE rule_values SET rule_value = 'true' WHERE rule_name = 'Character:HealOnLevel';
UPDATE rule_values SET rule_value = 'true' WHERE rule_name = 'Character:BindAnywhere';

-- Tradeskills (lower = faster)
UPDATE rule_values SET rule_value = '1.0' WHERE rule_name = 'Character:TradeskillUpAlchemy';
UPDATE rule_values SET rule_value = '1.0' WHERE rule_name = 'Character:TradeskillUpBaking';
UPDATE rule_values SET rule_value = '1.0' WHERE rule_name = 'Character:TradeskillUpBlacksmithing';
UPDATE rule_values SET rule_value = '1.5' WHERE rule_name = 'Character:TradeskillUpBrewing';
UPDATE rule_values SET rule_value = '1.0' WHERE rule_name = 'Character:TradeskillUpFletching';
UPDATE rule_values SET rule_value = '1.0' WHERE rule_name = 'Character:TradeskillUpJewelcrafting';
UPDATE rule_values SET rule_value = '1.0' WHERE rule_name = 'Character:TradeskillUpMakePoison';
UPDATE rule_values SET rule_value = '2.0' WHERE rule_name = 'Character:TradeskillUpPottery';
UPDATE rule_values SET rule_value = '1.0' WHERE rule_name = 'Character:TradeskillUpTailoring';

-- Loot
UPDATE rule_values SET rule_value = '2' WHERE rule_name = 'Zone:GlobalLootMultiplier';

-- Expansion Lock
UPDATE rule_values SET rule_value = '3' WHERE rule_name = 'Expansion:CurrentExpansion';
```

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning. The architect should:
> 1. Verify which NPCs use auto-scaling vs manual stats
> 2. Design the `npc_scale_global_base` modification plan
> 3. Design the loot table SQL update queries
> 4. Create the rollback/revert SQL script
> 5. Plan the implementation task breakdown for the team
