# Companion Authenticity Audit — Synthesized Gap Analysis Report

> **Feature branch:** `feature/companion-authenticity-audit`
> **Author:** architect
> **Date:** 2026-03-14
> **Status:** Complete
> **Sources:** c-expert audit, lua-expert audit, data-expert audit

---

## Executive Summary

This report synthesizes findings from three expert audits (C++, Lua, Database) of the
companion system against authentic EverQuest behavior for the Classic through Luclin era.
The companion system is largely well-implemented with correct AC calculations, haste,
dual/double/triple attack, weapon damage bonuses, spell focus effects, equipment handling,
stance commands, and group integration. However, the audit identified **3 critical gaps**,
**4 major gaps**, and **7 moderate/minor gaps** across the C++, Lua, and data layers.
The most impactful findings are: companions cannot critical hit (C++ rule gate), PC-only
spells cannot target companions (missing C++ guard), defensive skills are likely zero
(missing skill initialization), all companion stats are homogeneous regardless of
class/race (data layer), and shaman heal spell priorities are not differentiated (data layer).
This document catalogs all findings, separates intentional design decisions from authenticity
gaps, and provides prioritized fix recommendations.

---

## What's Working Correctly

Before addressing gaps, it is important to acknowledge the systems that are functioning
as intended. The companion system gets a substantial number of things right.

### Combat Mechanics (C++ Layer)
- **AC calculation:** Companions get player-equivalent defense skill divisors (/3 for
  non-casters, /2 for casters), shield AC from inventory, anti-twink cap, and per-class
  AC softcaps with diminishing returns. `IsOfClientBot()` returns true for companions,
  routing them through the full player AC path. (`attack.cpp:900-976`)
- **Hit chance:** `CheckHitChance()` uses the same formula for all mob types. No
  companion-specific divergence. (`mob.cpp:331-370`)
- **Dual wield:** Correctly checks `CanThisClassDualWield()`, weapon delays from
  inventory, dual wield timer with haste application. (`companion.cpp:670-777`)
- **Double attack:** Level-gated via `SkillDoubleAttack` (NPC constructor sets
  `level*5` for levels 4-50, 250 for 50+). All companions level 4+ can double attack.
- **Triple attack:** Custom `CanCompanionTripleAttack()` correctly limits to Warriors
  56+, Monks/Rangers 60+. (`companion.cpp:1001-1071`)
- **Damage bonus:** Warrior-class companions at level 28+ get `GetWeaponDamageBonus()`
  on primary hand, identical to the Client path. (`companion.cpp:592-597`)
- **Haste:** Weapon-damage path mirrors `Client::SetAttackTimer()` with item/spell
  haste and HundredHands correction. (`companion.cpp:670-777`)
- **MaxHP:** STA-to-HP conversion for bonus STA from items/spells, scaled by class
  archetype and level. Formula is class-differentiated (tanks 8 HP/STA, melee 5, priests 4,
  casters 3). (`companion.cpp:808-868`)
- **MaxMana:** For `npc_mana=0` NPCs (most recruited casters), uses the player formula
  `((INT or WIS)/2 + 1) * level`. BUG-017 fix for `npc_mana!=0` correctly scales mana
  with level. (`companion.cpp:892-942`)
- **Spell damage and focus:** `Companion::GetFocusEffect()` override bypasses
  `NPC::GetFocusEffect()` which incorrectly gates item focus behind
  `RuleB(Spells, NPC_UseFocusFromItems)`. Companions correctly apply focus effects from
  equipped items. (`companion.cpp:987-991`)

### Equipment System (Lua Layer)
- **Trade handling:** Full slot-matching with class/race restrictions, NPC-to-player-race
  mapping for citizen/guard model races, displaced item return, stackable excess return,
  pcall error safety, ownership enforcement. (`global_npc.lua:162-319`)
- **Unequip commands:** `!unequip <slot>` and `!unequip all` correctly return items to
  player. (`companion.lua:660-698`)

### Stance and Movement (Lua Layer)
- **Three stances:** Passive (0), Balanced (1), Aggressive (2) correctly mapped to C++
  `SetStance()`. `WipeHateList()` called on passive/hold transitions.
- **Guard/follow modes:** Tracked in module-level Lua table, `SetGuardMode()` invoked on
  C++ side.
- **Buff commands:** `!buffme` and `!buffs` use queue serialization (BUG-025 fix) with
  correct spell selection from `companion_spell_sets`, sequential 2-second casting, OOM
  gating at 10%.

### Group Integration (Lua Layer)
- **Group buff targeting:** Correctly targets all group members including other companions.
  Spell-major ordering (all targets get spell 1, then spell 2, etc.).
- **Group chat routing:** All command responses go through `group:GroupMessage()` when
  grouped.
- **`@all` stagger:** Multiple companions don't speak simultaneously; C++ sets stagger
  delays and Lua delivers via timers.

### Data Layer
- **Companion level tracking:** `companion_data.level` correctly tracks progression
  independent of NPC template level. Lydl recruited at 4, now 29. Working as intended.
- **Class assignment consistency:** `class_id` in `companion_data` matches `npc_types.class`
  for all 7 companions. No mismatches.
- **Spell list class assignments:** Warriors/Rogues correctly have `npc_spells_id=0`.
  Necro/Wizard/Ranger correctly assigned to their class lists.
- **Item class restrictions:** All checked items satisfy class restriction bitmasks.

---

## Intentional Divergences (Design Decisions — NOT Gaps)

These divergences from authentic EQ behavior are documented design choices for the
1-3 player small-group experience. They should NOT be treated as bugs.

| Divergence | Current Behavior | Authentic EQ | Rationale |
|-----------|-----------------|-------------|-----------|
| Always-meditate mana regen | Companions always regen at meditation rate when `AlwaysMeditateRegen=true` (default) | Players must sit and meditate to get fast mana regen | Prevents mana starvation in single-player use. Togglable via `Companions:AlwaysMeditateRegen` rule. |
| No fizzle | Companions never fizzle (`Mob::CheckFizzle()` returns true for all non-clients) | Players fizzle based on casting skill vs spell difficulty | Same as all other NPCs/bots/mercs. Would add frustration without adding gameplay. |
| Resist caps at ~70% of player | Resist cap = `level*5 + 50` (350 at 60 vs player 500) | Players can reach ~500 resist per type | PRD design decision to keep companions vulnerable. Tunable via `ResistCapBase` rule. |
| Free first cast at full mana | NPC special case: if `current_mana == max_mana`, first cast is free | Players always pay mana costs | All NPCs share this behavior. Rarely relevant in practice. |
| OOC HP regen by MaxHP percentage | HP regen uses `MaxHP * OOCRegenPct / 100` out of combat | Players use stat/class-based regen formula | Simpler formula, tunable. Functionally equivalent. |

---

## Critical Gaps

### GAP-01: Companions Cannot Critical Hit [CRITICAL]

- **Severity:** Critical
- **Source layer(s):** C++
- **Current behavior:** `TryCriticalHit()` in `attack.cpp:5446-5448` has an early return
  for `IsNPC() && !RuleB(Combat, NPCCanCrit)`. Companions return `IsNPC()=true` and are
  NOT pets (no `GetOwner()`). When `NPCCanCrit` is `false` (server default), the function
  returns immediately — companions never attempt a crit roll.
- **Expected authentic EQ behavior:** Warriors and Berserkers have innate crit at level 12+.
  Rangers crit with archery at 12+. Rogues crit with throwing at 12+. All classes can gain
  crit from SPA 169 (CriticalHitChance) via items/spells.
- **Root cause:** `attack.cpp:5446` — missing `IsCompanion()` exemption in the `NPCCanCrit`
  gate. The gate was designed to prevent generic NPCs from critting, not companion NPCs.
- **Impact:** A level 60 warrior companion will never deliver a crippling blow. This is a
  significant DPS reduction (typical player crit rate at 60 adds ~5-15% average DPS from
  crits alone). For warrior-class companions in the level 12-60 range, this effectively
  removes an entire combat mechanic.
- **Recommended fix:** Add `&& !IsCompanion()` guard at `attack.cpp:5446`:
  ```cpp
  if (IsNPC() && !IsCompanion() && !RuleB(Combat, NPCCanCrit)) { return; }
  ```
- **Estimated scope:** Small (1 file, 1 line change)
- **Assigned expert:** c-expert

### GAP-02: PC-Only Spells Cannot Target Companions [CRITICAL]

- **Severity:** Critical
- **Source layer(s):** C++
- **Current behavior:** `SpellFinished()` / `SpellOnTarget()` in `spells.cpp:831-844`
  checks `pcnpc_only_flag == PCNPCOnlyFlagType::PC` and blocks the spell if the target
  `!IsClient() && !IsMerc() && !IsBot()`. Companions are NOT listed. The same missing
  guard exists at `spells.cpp:3935-3945` (AE radius path) and `spells.cpp:6999/7094`
  (AE range paths).
- **Expected authentic EQ behavior:** Player buffs should work on companions. Companions
  are the player's ally and primary party members. Bots and mercs are already exempted.
- **Root cause:** `IsCompanion()` was not added to the `pcnpc_only_flag` exemption list
  when the Companion class was created. Bots and mercs were added but companions were
  overlooked.
- **Impact:** Any spell with `pcnpc_only_flag = 1` (PC-only) cannot be cast on companions.
  This includes common group buffs, heals, and utility spells. Players will see "This spell
  only works on other PCs" when trying to buff their companions. This is a severe usability
  issue.
- **Recommended fix:** Add `|| spell_target->IsCompanion()` to all three `pcnpc_only_flag`
  checks in `spells.cpp` (lines ~832, ~3940, ~6999/7094).
- **Estimated scope:** Small (1 file, 3-4 line changes)
- **Assigned expert:** c-expert

### GAP-03: Missing Defensive Skills (Parry, Riposte, Dodge, Block, Defense) [CRITICAL]

- **Severity:** Critical
- **Source layer(s):** C++ + Database (cross-cutting)
- **Current behavior:** `CanThisClassParry()`, `CanThisClassRiposte()`,
  `CanThisClassBlock()`, `CanThisClassDodge()` in `mob.cpp:4714-4748` check
  `GetSkill(SkillParry) > 0` etc. for non-clients. The NPC constructor (`npc.cpp:382-393`)
  sets `SkillDoubleAttack` and `SkillDualWield` but does NOT set parry, riposte, dodge,
  block, or defense skills. These come from the `npc_types` `skills` field, which is
  typically empty for most NPCs.
- **Expected authentic EQ behavior:** A level 60 warrior should parry, riposte, block, and
  dodge. A monk should have excellent dodge. Defense skill contributes to AC via the
  `SkillDefense/3` term in `ACSum()`. A level 60 warrior with Defense 255 should get
  255/3 = 85 AC from this term alone. With Defense=0, that AC is lost entirely.
- **Root cause:** NPC constructor initializes combat offense skills but not defensive skills.
  Companions inherit whatever the recruited NPC had in the database. Data-expert confirmed
  that `npc_scale_global_base` does not set per-skill values — stats are uniform.
  The `skills` blob in `npc_types` for most NPCs does not include defensive skill values.
- **Impact:** Companions cannot parry, riposte, dodge, or block. They lose ~85 AC from
  missing Defense skill. A level 60 warrior companion is dramatically more fragile than a
  player warrior, taking significantly more hits and losing avoidance-based damage reduction.
  Tank companions are most affected.
- **Recommended fix:** Set class-appropriate defensive skills in the Companion constructor
  or `Spawn()` method using player skill caps. For example, at recruitment/level-up:
  - Warriors: Defense=level*5 (cap 252), Parry=level*5 (cap 252), Riposte=level*5 (cap 252),
    Dodge=level*5 (cap 137), Block=level*5 (cap 252)
  - Monks: Dodge=level*5 (cap 252), Defense=level*5 (cap 252), Riposte=level*5 (cap 200)
  - Rogues: Dodge=level*5 (cap 210), Parry=level*5 (cap 200), Defense=level*5 (cap 200)
  - etc. per class skill tables
  The C++ fix is more reliable than a database fix because it ensures all companions
  get correct skills regardless of the recruited NPC's `npc_types` data.
- **Estimated scope:** Medium (1-2 files, ~50-80 lines — skill cap table + setter in
  `companion.cpp`)
- **Assigned expert:** c-expert

---

## Major Gaps

### GAP-04: Homogeneous Base Stats (No Class/Race Differentiation) [MAJOR]

- **Severity:** Major
- **Source layer(s):** Database
- **Current behavior:** `npc_scale_global_base` type=0 makes ALL stats identical per level
  (STR=STA=DEX=AGI=WIS=INT=CHA). At level 30: all stats = 97. A wizard companion has
  the same STR as a warrior companion. A dark elf has the same WIS as a high elf.
- **Expected authentic EQ behavior:** Players have race-based stat starting values and
  class-based stat priorities. A human warrior has STR ~85, STA ~85, INT ~75, WIS ~75.
  A high elf wizard has INT ~115, STR ~70. Stats define class identity.
- **Root cause:** The `npc_scale_global_base` table provides uniform stats for all NPC
  types. It was not designed for class-differentiated companion use. The C++ scaling
  formula (`companion.cpp:312-343`) simply multiplies the base NPC stats by a level ratio,
  preserving the homogeneity.
- **Impact:** Moderate gameplay impact. Primary stats (INT for wizards, WIS for priests,
  STR for melee) drive key combat formulas: mana pool, spell damage, melee damage, HP.
  A wizard companion with INT=97 at level 30 has a smaller mana pool and weaker nukes than
  a wizard with INT=115. A warrior with STR=97 misses out on damage bonus scaling.
  However, the linear scaling and stat scaling percentage rule (`StatScalePct`) partially
  compensate.
- **Recommended fix:** One of:
  1. **Database approach:** Create class-specific scaling entries or a `companion_stat_overrides`
     table that applies class/race-based stat modifiers on top of the base scale values.
  2. **C++ approach:** In `Companion::ScaleStatsToLevel()`, apply class-based stat multipliers
     (e.g., warriors get STR*1.15, INT*0.85; wizards get INT*1.15, STR*0.75).
  3. **Hybrid:** Use player `character_create_combinations` base stats as seed values scaled
     by level, replacing the uniform NPC scale values entirely.
- **Estimated scope:** Medium (C++ stat scaling function + data tuning)
- **Assigned expert:** c-expert (C++ scaling) + data-expert (stat multiplier tables)

### GAP-05: Shaman Spell Healing Priority Not Differentiated [MAJOR]

- **Severity:** Major
- **Source layer(s):** Database
- **Current behavior:** Default Shaman List (npc_spells ID 6) has 93 spells with ALL heals
  at priority 1, competing equally with SoW, debuffs, damage spells, and wolf form. The NPC
  AI will randomly select among all eligible spells at the same priority, meaning a shaman
  companion may cast Spirit of Wolf instead of healing a dying tank.
- **Expected authentic EQ behavior:** Shaman should prioritize healing injured group members
  over casting utility or damage spells. The Default Cleric List (ID 1) correctly has heals
  at priority 20 and 10, ensuring clerics heal before doing anything else.
- **Root cause:** The shaman spell list was designed for NPC shaman mobs (who don't need
  to triage heals for group members), not for companion shaman who serve a healer role.
- **Impact:** Any recruited shaman companion will be an unreliable healer. Since shamans are
  one of the primary healer classes in Classic-Luclin EQ, this significantly degrades the
  viability of shaman companions.
- **Cross-reference:** Lua-expert confirmed there is no Lua-side combat AI. All autonomous
  spell casting comes from C++ `Companion::AICastSpell()` which reads from `npc_spells`
  entries. The data layer priority values directly control companion healing behavior.
- **Recommended fix:** Create a companion-specific shaman spell list (or modify the existing
  one) with heals elevated to priority 15-20, damage spells at priority 5-10, and utility
  at priority 1-3. Same pattern as the existing cleric list. Alternatively, populate
  `companion_spell_sets` with correctly prioritized shaman entries.
- **Estimated scope:** Medium (database changes — new spell list entries or companion_spell_sets
  population)
- **Assigned expert:** data-expert

### GAP-06: Class-Neutral Base Melee Damage [MAJOR]

- **Severity:** Major
- **Source layer(s):** Database + C++
- **Current behavior:** `npc_scale_global_base` provides the same `mindmg` and `maxdmg` for
  all classes at a given level. At level 30: mindmg=8, maxdmg=51 for both a wizard and a
  warrior. When `UseWeaponDamage=true` (the normal path), companions use weapon damage
  instead of NPC base damage, which partially addresses this. However, when no weapon is
  equipped or `UseWeaponDamage=false`, the NPC base damage applies uniformly.
- **Expected authentic EQ behavior:** Warriors hit much harder in melee than wizards.
  Class-appropriate melee strength is a defining characteristic.
- **Root cause:** `npc_scale_global_base` was designed for generic NPC scaling, not
  class-differentiated companion use. The C++ weapon-damage path mitigates this when
  weapons are equipped, but the fallback NPC damage path treats all classes identically.
- **Impact:** When companions have appropriate weapons equipped (`UseWeaponDamage=true`),
  the impact is minimal because weapon damage provides class differentiation naturally (a
  warrior equips a 15-damage sword, a wizard equips a 3-damage dagger). When weapons are
  not equipped, caster companions auto-attack with warrior-equivalent damage.
- **Recommended fix:** Two approaches:
  1. Ensure all companions always have `UseWeaponDamage=true` and appropriate weapons
     equipped (equipment quality gap, GAP-08, addresses the weapon side).
  2. For the fallback path: apply a class-based damage multiplier in
     `Companion::GetBaseDamage()` (e.g., casters 40%, priests 60%, melee 100%).
- **Estimated scope:** Small-Medium (C++ method + optional data tuning)
- **Assigned expert:** c-expert

### GAP-07: Autonomous Combat Spell Casting Quality [MAJOR]

- **Severity:** Major
- **Source layer(s):** C++ + Database (cross-cutting)
- **Current behavior:** Lua-expert confirmed there is ZERO autonomous combat casting in the
  Lua layer. All autonomous spell casting must come from C++ `Companion::AICastSpell()`
  (`companion_ai.cpp:358-396`). This function exists and loads spells from
  `companion_spell_sets`. The C++ code appears to implement combat casting, but its
  effectiveness is directly gated by the quality of the `companion_spell_sets` data and
  the `npc_spells` priority values.
- **Expected authentic EQ behavior:** Caster companions should autonomously nuke targets,
  healers should triage group members, enchanters should mez adds, etc. This requires
  both correct C++ AI logic AND correctly prioritized spell data.
- **Root cause:** The C++ AI exists but the database spell priority data (GAP-05) undermines
  it. Additionally, the Lua-expert flagged that no `event_combat` or `event_damage_taken`
  handlers exist in Lua, meaning there is no Lua-side fallback if C++ AI is insufficient.
- **Impact:** Caster companion effectiveness in combat depends entirely on the quality of
  the C++ AI code and the spell priority data. The shaman priority issue (GAP-05) is one
  concrete example. Other class spell lists may have similar issues that haven't been
  individually audited for every class.
- **Recommended fix:** This is addressed by fixing GAP-05 (shaman priorities) and conducting
  a broader spell list priority review for all healer and caster classes. If C++ AI logic
  has specific deficiencies, those would require c-expert investigation.
- **Estimated scope:** Medium-Large (data audit + potential C++ AI tuning)
- **Assigned expert:** data-expert (spell priorities) + c-expert (AI logic review)

---

## Moderate Gaps

### GAP-08: Equipment Quality Not Scaling with Companion Level [MODERATE]

- **Severity:** Moderate
- **Source layer(s):** Gameplay / Data
- **Current behavior:** Data-expert found level 29 companions wearing starter-tier gear:
  Bronze Two Handed Sword (damage 9, delay 47) on a level 29 warrior; level 25 necromancer
  with only cloth armor and no weapon. Gear quality is entirely player-driven (player must
  find and trade items to companions).
- **Expected authentic EQ behavior:** A level 29 warrior player would have a weapon dealing
  15-25+ damage. Equipment scales with progression.
- **Root cause:** There is no automatic gear scaling system. Companions keep whatever the
  player gives them.
- **Impact:** Moderate. Companion DPS and survivability depend heavily on equipment. With
  starter gear at level 29, a warrior companion does significantly less damage than
  appropriate for that level.
- **Recommended fix:** This is primarily a game design/UX issue, not a bug. Options:
  1. Document expected gear progression for companion levels in a player guide
  2. Add a `!equipmentupgrade` hint system that suggests zone-appropriate gear
  3. Auto-scale NPC base damage as a floor regardless of weapon (class-gated)
- **Estimated scope:** Small (documentation) to Medium (auto-scaling system)
- **Assigned expert:** game-designer (design decision) + data-expert (if DB changes needed)

### GAP-09: Attack Delay Compression at Level 40+ [MODERATE]

- **Severity:** Moderate
- **Source layer(s):** Database + C++
- **Current behavior:** `npc_scale_global_base` drops `attack_delay` from 30 to 21 between
  levels 30-40. This makes ALL companions attack at delay 21 at level 40+ regardless of
  class. A player at level 40 uses weapon delay (typically 25-38 for 1HS).
- **Expected authentic EQ behavior:** Attack speed should be determined by equipped weapon
  delay + haste effects, not a universal level-based acceleration.
- **Root cause:** When `UseWeaponDamage=true`, companion attack speed comes from the equipped
  weapon's delay (`companion.cpp:670-777`), NOT from the NPC scale table. The scale table
  `attack_delay` only applies in the fallback NPC path when no weapon is equipped. So this
  gap only materializes for unarmed companions.
- **Impact:** Low when companions have weapons equipped (weapon delay overrides scale table).
  High for unarmed companions or when `UseWeaponDamage=false`.
- **Recommended fix:** Ensure `UseWeaponDamage=true` is always set for companions with
  weapons. For unarmed companions, apply a class-based delay multiplier in the fallback
  path.
- **Estimated scope:** Small (verify rule setting + optional C++ fallback)
- **Assigned expert:** config-expert (rule verification) + c-expert (if fallback needed)

### GAP-10: Attack Bonus Zero for Levels 1-30 [MODERATE]

- **Severity:** Moderate
- **Source layer(s):** Database
- **Current behavior:** `npc_scale_global_base` has `attack=0` for levels 1-30, rising to
  40 at level 40 and 50 at level 50. Players at levels 20-30 have attack bonuses from STR
  and skills.
- **Expected authentic EQ behavior:** Players accumulate attack rating from STR, items, and
  buffs throughout leveling.
- **Root cause:** The NPC scale table was designed for generic NPCs who don't use the player
  attack formula. For companions, the C++ weapon-damage path uses `GetTotalToHit()` which
  includes offense (level*5+50 for NPCs), item bonuses, and spell bonuses — so the NPC
  scale `attack` field may not be the primary driver.
- **Impact:** Needs C++ verification. If `GetTotalToHit()` is the primary hit chance
  driver (which the c-expert confirmed it is), then the scale table `attack=0` has minimal
  gameplay impact because offense = level*5+50 already provides substantial to-hit value.
- **Recommended fix:** Low priority. Verify that `GetTotalToHit()` adequately compensates.
  If not, set `attack` values in scale table for levels 1-30.
- **Estimated scope:** Small (verification + optional data change)
- **Assigned expert:** data-expert (if DB change needed)

---

## Minor Gaps

### GAP-11: NPC Offense Formula vs Player Skill-Based Formula [MINOR]

- **Severity:** Minor
- **Source layer(s):** C++
- **Current behavior:** `offense()` in `attack.cpp:153-165` uses `level*5+50` for NPCs
  (including companions) instead of `GetSkill(weapon_skill)+50` (player formula). At level
  60: companion offense = 350, player offense = ~300 (with skill 250).
- **Expected authentic EQ behavior:** Player offense is skill-based.
- **Impact:** Companion offense is slightly HIGHER than player equivalent. This favors
  companions rather than penalizing them. The 15% advantage is minor.
- **Recommended fix:** No fix needed. The formulas converge at typical levels and the
  slight companion advantage is acceptable for the small-group design.
- **Estimated scope:** N/A

### GAP-12: Commentary Channel Inconsistency [MINOR]

- **Severity:** Minor (Cosmetic)
- **Source layer(s):** Lua
- **Current behavior:** Unprompted companion commentary uses `npc:Say()` (public say
  channel, visible to all nearby) while all command responses use `companion_say()` which
  routes to `group:GroupMessage()` (group chat only).
- **Expected behavior:** All companion dialogue should route through group chat for
  consistency and privacy.
- **Recommended fix:** Change `companion_commentary.lua` to use `companion_say()` or
  `group:GroupMessage()` instead of `npc:Say()`.
- **Estimated scope:** Small (1 file, 1 line change)
- **Assigned expert:** lua-expert

### GAP-13: Level-Up LLM Dialogue Not Implemented [MINOR]

- **Severity:** Minor (Cosmetic)
- **Source layer(s):** Lua
- **Current behavior:** `companion_culture.lua` defines a `"level_up"` event type for LLM
  dialogue context, but no `event_level_up` NPC handler exists in `global_npc.lua`. If C++
  fires an NPC event on companion level-up, Lua won't handle it.
- **Expected behavior:** Companion should make a personalized remark when leveling up.
- **Recommended fix:** Add `event_level_up` handler in `global_npc.lua` that checks
  `IsCompanion()` and triggers LLM dialogue via `companion_culture`.
- **Estimated scope:** Small (1 file, ~15-20 lines)
- **Assigned expert:** lua-expert

### GAP-14: Re-Recruitment Bonus Defined but Never Applied [MINOR]

- **Severity:** Minor (Design inconsistency)
- **Source layer(s):** Lua
- **Current behavior:** `REREC_BONUS = 10` is defined in `companion.lua:74` but the
  re-recruitment track bypasses the persuasion roll entirely (always succeeds). The
  `!dismiss` help text says "re-recruit later with +10% bonus" — this is incorrect per
  current code.
- **Expected behavior:** Either apply the +10% bonus to a roll, or update the help text.
- **Recommended fix:** Either: (a) apply the bonus to a modified roll for re-recruitment,
  or (b) remove the misleading help text and the unused constant. Game-designer should
  decide which.
- **Estimated scope:** Small (1 file, 1-5 lines)
- **Assigned expert:** lua-expert (after game-designer decision)

### GAP-15: SkillMeditate Likely Zero Affecting Mana Regen [MINOR]

- **Severity:** Minor
- **Source layer(s):** C++ + Database
- **Current behavior:** `CalcManaRegen()` uses `GetSkill(SkillMeditate)` in its formula
  (`companion.cpp:1172`). If the recruited NPC's meditate skill is 0 (likely for most NPCs),
  regen = `(0 + (level - level/4)) / 4 + 4`. With meditate 250 (player cap): `(25 + 45) / 4
  + 4 = 21.5`. The difference is ~6.5 mana/tick at level 60.
- **Impact:** Minor. The `AlwaysMeditateRegen` rule already provides enhanced regen. The
  meditate skill component adds ~30% more regen at high levels.
- **Recommended fix:** Set `SkillMeditate` as part of GAP-03 defensive skill fix (set all
  class-appropriate skills, not just defensive ones).
- **Estimated scope:** Included in GAP-03 fix
- **Assigned expert:** c-expert (part of GAP-03)

### GAP-16: Item Race Restriction Mismatch [MINOR]

- **Severity:** Minor
- **Source layer(s):** Database
- **Current behavior:** Companion Jimble Woodentoe (halfling ranger) has a Longbow equipped
  where `races=285` excludes halflings (bit 1024). The Lua equipment system maps non-player
  NPC races to player equivalents, and for unmappable races uses Human (race 1) as fallback.
  This may have allowed the equip to succeed despite the race restriction.
- **Impact:** Minimal. Single item on one companion. May not affect stats if C++ validates
  race at stat application time vs. equip time.
- **Recommended fix:** Review the Lua race-bypass fallback logic for edge cases. Consider
  whether "unmappable race = Human" is too permissive.
- **Estimated scope:** Small (Lua review + optional guard)
- **Assigned expert:** lua-expert

### GAP-17: Luabind Inheritance Nil-Guard Fragility [MINOR]

- **Severity:** Minor (Systemic)
- **Source layer(s):** C++ (luabind) + Lua (workaround)
- **Current behavior:** All `Lua_Companion`-specific methods (SetStance, GetStance,
  SetGuardMode, GetCompanionType, GetCombatRole, GetCompanionID) use nil-guards in Lua
  (`npc.SetStance and npc:SetStance(0)`) because luabind doesn't resolve inherited methods
  at runtime for the Companion class. When nil, commands silently succeed (NPC says
  acknowledgment text) but the actual C++ method is never called.
- **Root cause:** `lua_companion.cpp` needs explicit method bindings for all
  companion-specific methods rather than relying on inheritance resolution.
- **Impact:** When the nil-guard fires, the player sees a successful response but the
  companion doesn't actually change stance/mode. This is documented in MEMORY.md and is a
  known systemic issue.
- **Recommended fix:** Add explicit bindings in `lua_companion.cpp` for all companion-specific
  methods.
- **Estimated scope:** Medium (1 C++ file, ~30-50 lines of luabind registration)
- **Assigned expert:** c-expert

---

## Unknown Items (Require Further Investigation)

| Item | Question | Raised By | Expected Owner |
|------|----------|-----------|---------------|
| Companion mana calculation | Lydl (wiz, lvl 29) shows cur_mana=1798. Expected ~778 per formula. Is mana stored or calculated? | data-expert | c-expert |
| XP loss on death | Do companions lose XP on death like players? | lua-expert | c-expert |
| Buff stripping on death | Do companions lose all buffs when they die and are resurrected? | lua-expert | c-expert |
| Group spell targeting | Do standard group spells (Group Heal, Aegolism) hit companion NPCs? | lua-expert | c-expert |
| Equipment stat application | Do equip/unequip events trigger `CalcBonuses()` recalculation? | lua-expert | c-expert |

---

## Prioritized Fix Roadmap

### Phase 1: Critical Fixes (High Impact, Low Effort)

These should be fixed first as they have the highest impact-to-effort ratio.

| Priority | Gap | Fix | Agent | Effort |
|----------|-----|-----|-------|--------|
| P1 | GAP-01 | Add `!IsCompanion()` to NPCCanCrit gate | c-expert | Small |
| P2 | GAP-02 | Add `IsCompanion()` to pcnpc_only_flag checks | c-expert | Small |
| P3 | GAP-03 | Set class-appropriate defensive skills in Companion constructor | c-expert | Medium |

### Phase 2: Major Fixes (High Impact, Medium Effort)

| Priority | Gap | Fix | Agent | Effort |
|----------|-----|-----|-------|--------|
| P4 | GAP-05 | Create companion-specific healer spell lists with correct priorities | data-expert | Medium |
| P5 | GAP-04 | Apply class/race stat modifiers in ScaleStatsToLevel() | c-expert + data-expert | Medium |
| P6 | GAP-06 | Apply class-based damage multiplier in fallback melee path | c-expert | Small-Medium |

### Phase 3: Polish (Moderate Impact, Low-Medium Effort)

| Priority | Gap | Fix | Agent | Effort |
|----------|-----|-----|-------|--------|
| P7 | GAP-12 | Fix commentary channel to use group chat | lua-expert | Small |
| P8 | GAP-13 | Add level-up LLM dialogue handler | lua-expert | Small |
| P9 | GAP-14 | Resolve re-recruitment bonus text vs behavior | lua-expert | Small |
| P10 | GAP-17 | Fix luabind inheritance for companion methods | c-expert | Medium |

### Phase 4: Data Tuning (Low-Moderate Impact)

| Priority | Gap | Fix | Agent | Effort |
|----------|-----|-----|-------|--------|
| P11 | GAP-07 | Audit all caster class spell list priorities | data-expert | Medium |
| P12 | GAP-08 | Document gear progression or add auto-scaling floor | game-designer + data-expert | Medium |
| P13 | GAP-09 | Verify UseWeaponDamage overrides scale delay | config-expert | Small |
| P14 | GAP-10 | Verify GetTotalToHit compensates for attack=0 | c-expert | Small |

---

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Fix critical hit gate: add `!IsCompanion()` to TryCriticalHit() | c-expert | -- | Small |
| 2 | Fix PC-only spell targeting: add `IsCompanion()` to pcnpc_only_flag checks | c-expert | -- | Small |
| 3 | Set class-appropriate defensive skills in Companion constructor/Spawn | c-expert | -- | Medium |
| 4 | Create companion-specific shaman/druid/ranger heal spell lists | data-expert | -- | Medium |
| 5 | Apply class-based stat multipliers in ScaleStatsToLevel() | c-expert | -- | Medium |
| 6 | Apply class-based melee damage multiplier in fallback path | c-expert | -- | Small |
| 7 | Fix commentary channel to use group:GroupMessage() | lua-expert | -- | Small |
| 8 | Add event_level_up handler in global_npc.lua | lua-expert | -- | Small |
| 9 | Resolve re-recruitment bonus constant vs help text | lua-expert | -- | Small |
| 10 | Fix luabind companion method bindings | c-expert | -- | Medium |
| 11 | Audit all caster class spell list priorities | data-expert | 4 | Medium |
| 12 | Verify UseWeaponDamage and GetTotalToHit compensation | c-expert | -- | Small |

---

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | 1, 2, 3, 5, 6, 10, 12 | Critical hits, spell targeting, defensive skills, stat scaling, melee damage, luabind |
| data-expert | 4, 11 | Spell list priorities for companion healers and casters |
| lua-expert | 7, 8, 9 | Commentary channel, level-up handler, recruitment text |

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| GAP-01 fix enables crits for ALL NPCs if done incorrectly | Low | High | Use `IsCompanion()` guard specifically, not `NPCCanCrit=true` globally |
| GAP-03 skill values don't match authentic EQ caps | Medium | Medium | Reference `skill_caps` table for player skill caps per class/level |
| GAP-04 stat multipliers create overpowered companions | Medium | Medium | Use conservative multipliers (10-15% deviation from uniform), tune via rule values |
| Spell list changes affect non-companion NPC shaman | Medium | Medium | Create separate companion-specific spell lists rather than modifying shared lists |

### Compatibility Risks

- GAP-01 and GAP-02 fixes are pure additions (new guard conditions). No existing behavior
  changes for non-companion entities.
- GAP-03 adds skills that were previously zero. Companions will become meaningfully tankier.
  This is the intended fix, but may need tuning if companions become too strong.
- GAP-04 stat changes affect all stat-derived calculations (HP, mana, damage, AC). Test
  thoroughly after implementation.

### Performance Risks

- No performance concerns. All fixes are in existing code paths with negligible computational
  cost.

---

## Validation Plan

After implementation, the game-tester should verify:

- [ ] Level 12+ warrior companion delivers critical hits in combat (visible in combat log)
- [ ] Player can cast PC-only buffs on companions (e.g., Blessing of Aego, Aegolism)
- [ ] Level 60 warrior companion has non-zero Defense, Parry, Riposte, Dodge skills (`!stats`)
- [ ] Level 60 warrior companion parries/ripostes attacks (visible in combat log)
- [ ] Shaman companion prioritizes healing injured group members over casting SoW in combat
- [ ] Wizard companion has higher INT than STR at equivalent level (`!stats`)
- [ ] Warrior companion has higher STR than INT at equivalent level (`!stats`)
- [ ] Companion commentary appears in group chat, not public say
- [ ] Companion says something on level-up (LLM dialogue)
- [ ] `!dismiss` help text matches actual re-recruitment behavior
- [ ] Companion stance commands (SetStance) actually change stance behavior, not just show text

---

> **Next step:** This is a research/audit deliverable. The gap analysis is complete.
> The prioritized fix roadmap above can be used to create implementation tasks in a
> separate feature branch (e.g., `feature/companion-authenticity-fixes`) when the user
> is ready to proceed with fixes.
>
> **Assigned experts for implementation phase:**
> 1. **c-expert** — Tasks 1, 2, 3, 5, 6, 10, 12 (critical hits, spell targeting, skills, stats, damage, luabind)
> 2. **data-expert** — Tasks 4, 11 (spell list priorities)
> 3. **lua-expert** — Tasks 7, 8, 9 (commentary, level-up, re-recruitment text)
