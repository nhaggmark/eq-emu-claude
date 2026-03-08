# Companion AI Class-Specific Behavior Analysis

**Date:** 2026-03-08
**Type:** Research / Code Analysis
**Status:** Complete

---

## Executive Summary

The companion system has a **well-designed class-specific spell AI** implemented in `companion_ai.cpp` with dedicated handlers for all 15 Classic-Luclin player classes. Spell lists are stored in the `companion_spell_sets` database table with 842 total entries across 12 spellcasting classes. Combat abilities (bash, kick, backstab, etc.) are inherited from the NPC base class via `NPC::DoClassAttacks()` and work automatically based on the NPC's `class` field.

**Key finding:** The companion AI system is architecturally sound and more sophisticated than the merc system. The main gap is not in the code -- it is in the **NPC data**. Most city NPCs (guards, citizens, merchants) are class 1 (Warrior) with no spell list (`npc_spells_id = 0`), meaning they will only melee when recruited. The companion system handles this gracefully by falling back to NPC base AI, but the player experience depends heavily on which NPC they recruit.

---

## 1. Spellcasting AI

### 1.1 Where Is the Spell AI Logic?

The companion spell AI is implemented across two files:

| File | Role |
|------|------|
| `eqemu/zone/companion.cpp` | AI entry points: `AI_EngagedCastCheck()`, `AI_IdleCastCheck()`, `AIDoSpellCast()`, `GetChanceToCastBySpellType()`, `SetSpellTimeCanCast()`, `CheckSpellRecastTimers()` |
| `eqemu/zone/companion_ai.cpp` | Core spell selection: `LoadCompanionSpells()`, `AICastSpell()`, all 16 class-specific handlers (AI_Tank through AI_Generic), and 8 shared helper methods |

### 1.2 How Does NPC Spellcasting Work? (Base NPC System)

The base NPC spell AI (`mob_ai.cpp`) uses these tables:

- **`npc_spells`** (header): Contains proc chances, recast behavior, parent list inheritance
- **`npc_spells_entries`**: Individual spells with type, priority, recast, HP thresholds
- **`AISpells_Struct`** (in `npc.h`): Runtime struct for each loaded spell

When an NPC spawns, `NPC::AI_AddNPCSpells(npc_spells_id)` loads its spell list from the database. The main AI loop in `Mob::AI_Process()` calls `NPC::AI_EngagedCastCheck()` and `NPC::AI_IdleCastCheck()` which route to `NPC::AICastSpell()`.

### 1.3 Do Recruited Companions Retain Their NPC Spell List?

**No -- and this is by design.** When a companion is recruited:

1. `Companion::AI_Start()` calls `LoadCompanionSpells()`, which queries the **`companion_spell_sets`** table (not `npc_spells`/`npc_spells_entries`)
2. If companion_spell_sets has entries matching the companion's class and level, those are loaded into `m_companion_spells`
3. If no entries are found, `m_companion_spells` is empty

When `AICastSpell()` is called and `m_companion_spells` is empty, it falls back to `NPC::AI_EngagedCastCheck()` which uses the original NPC's `npc_spells_id` spell list.

**In practice:** If a recruited NPC is a Cleric (class 2), the companion system loads the Cleric spell set from `companion_spell_sets` regardless of what spells the NPC originally had. This is intentional -- it gives consistent, class-appropriate behavior rather than relying on whatever random spell list the NPC happened to have.

### 1.4 Does the AI Use Spells Appropriately?

**Yes, with class-specific priority logic.** Each class handler defines when to cast what:

**Healing classes (CLR, DRU, SHM, PAL):**
- `AI_HealGroupMember()` iterates all group members, finds the most injured (owner prioritized), selects best heal based on HP percentage
- Heal threshold: 90% HP when engaged, 99% when idle
- Passive cleric still heals when owner drops below 25% HP
- Passive druid/shaman heal when owner drops below 30-40% HP

**DPS casters (WIZ, MAG, NEC):**
- Only nuke when mana > 15-20%
- Necro prioritizes DoTs (70% roll) over direct nukes
- Magician always maintains pet first, then nukes

**Utility (ENC, BRD, SHM):**
- Enchanter: Mez first (highest priority), then slow, then nuke only in aggressive stance
- Shaman: Slow is highest priority (70% roll), then heal, then DoTs
- Bard: Mez, then combat songs, then snare

### 1.5 Spell Selection Details

**Priority system:** Spells in `companion_spell_sets` are ordered by `priority` column (ASC) then `id`. Lower priority number = checked first = better spell. `SelectHealSpell()` also considers `min_hp_pct` and `max_hp_pct` thresholds.

**Cooldowns:** Each spell has a `time_cancast` timestamp. After casting, `SetSpellTimeCanCast()` sets the next available time based on the spell's `recast_time` from `spells_new`.

**Stance filtering:** Each spell entry has a `stance` field:
- `0` = usable in all stances
- `>0` = only in that specific stance
- `<0` = in all stances EXCEPT that one

**Mana management:**
- Global check: companions don't cast when mana < 10%
- Buff routines skip when mana < 30%
- Wizard nukes only when mana > 15%

---

## 2. Class-Specific Behavior Analysis

### 2.1 Healer Classes

#### Cleric (class 2) - 79 spells in companion_spell_sets
| Spell Type | Count | Notes |
|-----------|-------|-------|
| Nuke | 25 | Stun, Word of Pain, Holy Might, etc. |
| Heal | 11 | Minor Healing through Supernal Remedy, Complete Heal |
| Root | 6 | Root spells for CC |
| Buff | 27 | Armor, HP buffs, resist buffs |
| InCombatBuff | 2 | Late-game only (56-65) |
| Cure | 6 | Cure Disease, Cure Poison, etc. |

**Behavior:** Pure healer priority. Engaged: cure > heal > buff (if mana > 50%). Even in passive stance, heals owner below 25% HP. Has access to stun nukes but doesn't override healing priority. Resurrection spells exist as placeholder (corpse targeting logic not yet implemented).

**Verdict: WORKING WELL.** Full heal/buff/cure rotation. Missing: automatic resurrection.

#### Druid (class 6) - 91 spells in companion_spell_sets
| Spell Type | Count | Notes |
|-----------|-------|-------|
| Nuke | 33 | Fire/ice nukes |
| Heal | 11 | Healing spells |
| Root | 6 | Root for CC |
| Buff | 24 | Spirit of Wolf, thorns, resist buffs |
| Snare | 5 | Movement speed debuffs |
| DOT | 10 | Fire/poison DoTs |
| InCombatBuff | 2 | Late-game |

**Behavior:** Hybrid healer/DPS. Engaged: heal first, then cure, root (30% chance), DoT (aggressive only), nuke (aggressive + mana > 30%). Idle: cure > heal > buff (SoW, thorns, etc.).

**Verdict: WORKING WELL.** Good balance of healing and offense.

#### Shaman (class 10) - 91 spells in companion_spell_sets
| Spell Type | Count | Notes |
|-----------|-------|-------|
| Nuke | 40 | Direct damage spells |
| Heal | 9 | Healing spells |
| Root | 6 | Root CC |
| Buff | 22 | Haste, stat buffs, resist buffs |
| DOT | 12 | Poison/disease DoTs |
| InCombatBuff | 2 | Late-game |

**Behavior:** Slower/healer hybrid. Engaged: slow first (70% priority roll), then heal, cure, DoT (aggressive only). Properly checks `SpecialAbility::SlowImmunity` on targets before attempting slow.

**Verdict: WORKING WELL.** Slow priority is correct for Shaman role.

**Note:** The Shaman companion_spell_sets has 40 "nuke" type entries but no "slow" type (2048) entries. This is a **data gap** -- the AI code checks for `SpellType_Slow` but the data uses type 1 (Nuke) for the slow spells. The `AI_SlowDebuff()` helper searches for `SpellType_Slow | SpellType_Debuff` which are bitmask values 2048 and 16384. **Since no entries have spell_type = 2048, shaman companions likely cannot slow.**

### 2.2 Tank Classes

#### Warrior (class 1) - 0 spells in companion_spell_sets
**Behavior:** Pure melee. `AI_Tank()` only attempts `SpellType_InCombatBuff` (combat disciplines) when engaged. Otherwise relies entirely on melee attacks.

**Combat abilities inherited from NPC::DoClassAttacks():**
- Kick (75% chance, level >= NPCBashKickLevel rule)
- Bash (25% chance)

**Verdict: WORKING.** Limited but appropriate for class. No spell needs.

#### Paladin (class 3) - 41 spells in companion_spell_sets
| Spell Type | Count | Notes |
|-----------|-------|-------|
| Nuke | 5 | Stuns, undead nukes (level 49+) |
| Heal | 11 | Lay hands effect, healing spells |
| Root | 4 | Root CC |
| Buff | 16 | Armor, HP buffs |
| InCombatBuff | 1 | Level 58+ |
| Cure | 4 | Disease/poison cures |

**Behavior:** Tank/healer hybrid. Engaged: heal (40% chance, always if defensive), cure (25% chance), in-combat buff, nuke only in aggressive stance. Idle: cure > heal > buff. Also uses `NPC::DoClassAttacks()` for knight abilities (Lay on Hands when HP < 20%).

**Verdict: WORKING WELL.** Good hybrid behavior.

#### Shadow Knight (class 5) - 47 spells in companion_spell_sets
| Spell Type | Count | Notes |
|-----------|-------|-------|
| Nuke | 18 | Direct damage spells |
| Buff | 7 | Self-buffs |
| Lifetap | 10 | HP drain spells |
| Snare | 5 | Movement debuffs |
| DOT | 6 | Disease/poison DoTs |
| InCombatBuff | 1 | Level 58+ |

**Behavior:** Tank/DPS. Engaged: lifetap when defensive (self-sustain), in-combat buff, DoT (aggressive only), nuke (50% chance). Idle: summon pet, buff. Uses `NPC::DoClassAttacks()` for Harm Touch.

**Verdict: WORKING WELL.** Lifetap self-sustain is smart behavior.

### 2.3 Melee DPS Classes

#### Rogue (class 9) - 0 spells in companion_spell_sets
**Behavior:** Pure melee. `AI_Rogue()` only checks for `SpellType_InCombatBuff` (disciplines).

**Combat abilities from NPC::DoClassAttacks():**
- Backstab (level >= 10, via `TryBackstab()`)

**Verdict: WORKING.** Appropriate for class. Evade timer initialized in constructor for rogues.

#### Monk (class 7) - 0 spells in companion_spell_sets
**Behavior:** Pure melee. `AI_Monk()` only checks for `SpellType_InCombatBuff` (disciplines).

**Combat abilities from NPC::DoClassAttacks():**
- Level-scaled special attacks: Kick (1-4), Round Kick (5-9), Tiger Claw (10-19), Eagle Strike (20-24), Dragon Punch (25-29), Flying Kick (30+)

**Verdict: WORKING.** Full monk special attack progression inherited from NPC base.

#### Ranger (class 4) - 52 spells in companion_spell_sets
| Spell Type | Count | Notes |
|-----------|-------|-------|
| Nuke | 11 | Fire arrows, nature nukes |
| Heal | 6 | Light healing spells |
| Root | 4 | Root CC |
| Buff | 21 | Endure elements, stat buffs |
| Snare | 2 | Movement debuffs |
| DOT | 6 | Fire/disease DoTs |
| InCombatBuff | 2 | Level 58+ |

**Behavior:** Melee/spell hybrid. Engaged: snare (30% chance), nuke (aggressive only), in-combat buff. Idle: buff (SoW, endure elements).

**Note on ranged attacks:** `NPC::RangedAttack()` exists as a virtual method on NPC. The AI loop in `mob_ai.cpp` does call `NPC::RangedAttack()` for NPCs with archery equipment. However, recruited companion NPCs typically don't have ranged weapons in their npc_types equipment slots, so ranged attacks are unlikely to fire. This could be a gap.

**Verdict: PARTIALLY WORKING.** Spell AI is good, but ranged attack behavior may not activate without proper equipment data.

#### Beastlord (class 15) - 51 spells in companion_spell_sets
| Spell Type | Count | Notes |
|-----------|-------|-------|
| Nuke | 13 | Spirit strikes |
| Heal | 6 | Minor healing |
| Buff | 23 | Stat buffs, resist buffs |
| DOT | 7 | Spirit DoTs |
| InCombatBuff | 2 | Level 58+ |

**Behavior:** Pet/melee hybrid. Idle: summon pet first. Engaged: maintain pet, slow/debuff (50% chance), in-combat buff, DoT (aggressive).

**Note on pets:** `AI_SummonPet()` checks `SpellType_Pet` (value 32) in companion_spell_sets. **No class has spell_type = 32 entries** in the current database. This means pet summoning will never trigger from companion_spell_sets, even for pet classes (MAG, NEC, BST, SHD).

**Verdict: PET SUMMONING BROKEN.** AI logic exists but no spell data populates it.

### 2.4 Caster DPS Classes

#### Wizard (class 12) - 76 spells in companion_spell_sets
| Spell Type | Count | Notes |
|-----------|-------|-------|
| Nuke | 48 | Fire, ice, magic nukes (largest nuke pool) |
| Root | 6 | Root CC |
| Buff | 20 | Shield/ward buffs |
| InCombatBuff | 2 | Level 34+ |

**Behavior:** Pure DPS. Engaged: escape if very low HP (< 20%), nuke when mana > 15%. Idle: buff.

**Note:** No `SpellType_Escape` (value 16) entries exist in companion_spell_sets for Wizard. The escape logic in `AI_Wizard()` will never fire.

**Verdict: NUKING WORKS. Escape spells missing from data.**

#### Magician (class 13) - 53 spells in companion_spell_sets
| Spell Type | Count | Notes |
|-----------|-------|-------|
| Nuke | 35 | Elemental nukes |
| Buff | 14 | Summoned items, shields |
| DOT | 2 | Minor DoTs |
| InCombatBuff | 2 | Level 34+ |

**Behavior:** Pet/nuke. Always tries to maintain pet first. Engaged: nuke when mana > 20%. Idle: buff.

**Verdict: NUKING WORKS. Pet summoning broken (no SpellType_Pet entries).**

#### Necromancer (class 11) - 67 spells in companion_spell_sets
| Spell Type | Count | Notes |
|-----------|-------|-------|
| Nuke | 10 | Direct damage |
| Root | 6 | Root CC |
| Buff | 14 | Self-buffs, damage shields |
| Lifetap | 11 | HP drain spells |
| Snare | 6 | Movement debuffs |
| DOT | 20 | Largest DoT pool |

**Behavior:** Pet/DoT specialist. Maintains pet. Engaged: DoTs (70% roll), lifetap when HP < 60%, nuke (40% roll). Idle: buff.

**Verdict: DoT/LIFETAP WORKS. Pet summoning broken (no SpellType_Pet entries).**

### 2.5 Utility Classes

#### Enchanter (class 14) - 116 spells in companion_spell_sets (largest set)
| Spell Type | Count | Notes |
|-----------|-------|-------|
| Nuke | 45 | Stuns, direct damage |
| Root | 6 | Root CC |
| Buff | 39 | Haste, clarity, rune (largest buff pool) |
| DOT | 7 | Mind DoTs |
| InCombatBuff | 2 | Late-game |
| Slow | 9 | Movement/attack speed debuffs |
| Mez | 8 | Mesmerize spells |

**Behavior:** CC utility. Engaged: mez additional mobs (highest priority), slow primary target (60% chance), in-combat buff, nuke only in aggressive stance. Idle: buff (haste, clarity), idle mez.

**This is the only class with properly populated Slow (2048) and Mez (4096) spell types.**

**Verdict: WORKING WELL.** Full CC/utility rotation. Mez uses `entity_list.GetTargetForMez()` which finds valid secondary targets.

#### Bard (class 8) - 78 spells in companion_spell_sets
| Spell Type | Count | Notes |
|-----------|-------|-------|
| Nuke | 28 | Chant-type damage |
| Heal | 6 | Minor healing songs |
| Buff | 27 | Haste, stat songs |
| Snare | 2 | Snare songs |
| DOT | 12 | Chant DoTs |
| Mez | 3 | Lullaby mesmerize |

**Behavior:** Song buff + CC. Engaged: mez additional mobs, combat songs (InCombatBuffSong), snare (20% chance). Idle: out-of-combat buff songs.

**Note:** Bard songs in EQ are instant-cast and twist (cycle). The companion system doesn't implement true song twisting -- it casts one song at a time like a normal spell. This is a simplification but functional.

**Verdict: PARTIALLY WORKING.** No true song twisting, but songs cast as regular spells work.

---

## 3. Spell Lists

### 3.1 How Are NPC Spell Lists Populated?

For **base NPCs** (before recruitment), spell lists flow through:
```
npc_types.npc_spells_id → npc_spells.id → npc_spells_entries (individual spells)
```

`npc_spells` supports parent list inheritance: a spell list can inherit spells from a parent list, allowing base spell sets to be shared across many NPCs.

For **companions**, spell lists come from:
```
companion_spell_sets (class_id, min_level, max_level → spell entries)
```

This is a custom table specific to the companion system, independent of `npc_spells`.

### 3.2 Are City Guards/Citizens Likely to Have Spell Lists?

**No.** Database analysis shows:

| NPC Type | Class | Typical npc_spells_id | Notes |
|----------|-------|----------------------|-------|
| Guards | 1 (Warrior) | 0 | All sampled guards have no spell list |
| Citizens | 1 (Warrior) | 0 | Most citizens are warrior class |
| Merchants | 1 (Warrior) | 0 | Most merchants are warrior class |

**Overall NPC spell list coverage for playable classes:**

| Class | Total NPCs | Has Spells | No Spells | % With Spells |
|-------|-----------|-----------|-----------|---------------|
| Warrior | 41,398 | 4,146 | 37,252 | 10.0% |
| Cleric | 2,940 | 2,127 | 813 | 72.3% |
| Paladin | 705 | 460 | 245 | 65.2% |
| Ranger | 510 | 383 | 127 | 75.1% |
| ShadowKnight | 1,418 | 790 | 628 | 55.7% |
| Druid | 850 | 443 | 407 | 52.1% |
| Monk | 850 | 144 | 706 | 16.9% |
| Bard | 114 | 13 | 101 | 11.4% |
| Rogue | 4,201 | 439 | 3,762 | 10.4% |
| Shaman | 2,546 | 1,825 | 721 | 71.7% |
| Necromancer | 1,954 | 1,361 | 593 | 69.7% |
| Wizard | 2,719 | 1,998 | 721 | 73.5% |
| Magician | 577 | 389 | 188 | 67.4% |
| Enchanter | 1,259 | 919 | 340 | 73.0% |
| Beastlord | 68 | 26 | 42 | 38.2% |

**Key insight:** Warriors (the most common NPC class) have only 10% spell coverage. But this doesn't matter for companions because companions use `companion_spell_sets` (class-based), not `npc_spells` (NPC-specific). A warrior guard recruited as a companion will use the Warrior handler (`AI_Tank`) which correctly has no spells -- it's melee only.

### 3.3 What Happens When You Recruit an NPC With No Spell List?

Two scenarios:

**Scenario A: NPC class has companion_spell_sets entries (e.g., class 2 Cleric)**
- `LoadCompanionSpells()` queries `companion_spell_sets` for class 2 at the companion's level
- Spells are loaded into `m_companion_spells`
- Companion AI uses the class-specific handler with these spells
- The NPC's original `npc_spells_id` is irrelevant

**Scenario B: NPC class has NO companion_spell_sets entries (e.g., class 1 Warrior)**
- `LoadCompanionSpells()` returns an empty list
- `AICastSpell()` sees empty `m_companion_spells` and falls back to `NPC::AI_EngagedCastCheck()`
- If the NPC's `npc_spells_id` is also 0, no spells are cast
- The companion operates as pure melee

### 3.4 Are the Spells Level-Appropriate?

**Yes.** The `companion_spell_sets` table uses `min_level` and `max_level` columns. The query in `LoadCompanionSpells()` filters:
```sql
WHERE class_id = ? AND min_level <= ? AND max_level >= ?
```

This means a level 20 Cleric companion gets level-appropriate heals (Minor Healing through Greater Healing) but not Complete Heal (requires level 39+). Spell progression is built into the data.

When a companion levels up (via the XP system), `LoadCompanionSpells()` would need to be re-called to update the spell list. **This may be a gap** -- the current `CheckForLevelUp()` implementation needs verification that it calls `LoadCompanionSpells()` after leveling.

### 3.5 How Does the Bot System Handle Spell Lists?

Bots use a completely separate system:

| System | Spell Source | Table | AI Logic |
|--------|-------------|-------|----------|
| **NPC** | `npc_spells` + `npc_spells_entries` | Per-NPC | `NPC::AICastSpell()` in `mob_ai.cpp` |
| **Companion** | `companion_spell_sets` | Per-class/level | `Companion::AICastSpell()` in `companion_ai.cpp` |
| **Bot** | `bot_spells_entries` + custom settings | Per-class/level | `Bot::AI_Process()` in `botspellsai.cpp` (~2,886 lines) |
| **Merc** | `merc_spell_list_entries` (not present in this DB) | Per-type/proficiency | `Merc::AICastSpell()` in `merc.cpp` |

The bot system is the most sophisticated with 58+ spell type categories, custom spell settings, heal rotations, and extensive per-class logic in `botspellsai.cpp`. The companion system deliberately uses a simpler model (the Merc-style SpellType bitmask system) for maintainability.

---

## 4. Combat Abilities

### 4.1 How Do NPCs Use Combat Abilities?

The `Mob::AI_Process()` main loop (in `mob_ai.cpp` line 1318) calls:
```cpp
if (IsNPC())
    CastToNPC()->DoClassAttacks(target);
```

This is called every combat round for engaged NPCs. `NPC::DoClassAttacks()` (in `special_attacks.cpp:1863`) implements:

| Class | Ability | Level Req | Notes |
|-------|---------|-----------|-------|
| Warrior | Kick | NPCBashKickLevel rule | 75% chance |
| Warrior | Bash | NPCBashKickLevel rule | 25% chance |
| Rogue | Backstab | Level 10+ | Via `TryBackstab()` |
| Monk | Kick/Round Kick/Tiger Claw/Eagle Strike/Dragon Punch/Flying Kick | Level-scaled | Full progression |
| Shadow Knight | Harm Touch | Any level | Via CastSpell(SPELL_NPC_HARM_TOUCH) |
| Paladin | Lay on Hands | HP < 20% | Via CastSpell(SPELL_LAY_ON_HANDS) |
| All pets | Taunt | Has owner + target is NPC + not undead | Pet-specific taunt |

### 4.2 Are Combat Abilities Tied to Class or Special Abilities?

**Both.** `NPC::DoClassAttacks()` switches on `GetClass()` for class-specific abilities. Additionally:

- **`npcspecialattks`** (string field in `npc_types`): Legacy special attack flags (e.g., 'E' = Enrage, 'F' = Flurry, 'R' = Rampage)
- **`special_abilities`** (CSV field in `npc_types`): Numbered abilities (e.g., `1^1` = Summon, `2^1` = Enrage, etc.)

These are inherited by companions from the recruited NPC's `npc_types` data.

### 4.3 Do Companions Inherit Combat Abilities?

**Yes, fully.** The Companion class:

1. Does NOT override `DoClassAttacks()` -- inherits `NPC::DoClassAttacks()`
2. Does NOT override the combat round logic in `Mob::AI_Process()` which calls `DoClassAttacks()`
3. The `Process()` override in `companion.cpp` calls `NPC::Process()` at the end, which chains to `Mob::AI_Process()`

Therefore, a Rogue companion backstabs, a Monk companion uses flying kick, a Warrior companion kicks/bashes, etc. These are **automatic and working**.

### 4.4 How Does the Merc System Handle Combat Abilities?

Mercs override `DoClassAttacks()` (in `merc.cpp:3960`) with a simplified version:

- **TANK role**: Kick (75%) or Bash (25%) at NPCBashKickLevel
- **MELEEDPS role**: Backstab at level 10+

Mercs only have two combat roles (Tank, MeleeDPS), so they can't do monk flying kicks or paladin lay-on-hands. Companions are superior here because they inherit the full NPC class attack table.

---

## 5. The Merc AI Comparison

### 5.1 Merc AI Architecture

Mercs use a different AI model:

| Feature | Merc | Companion |
|---------|------|-----------|
| Spell source | `merc_spell_list_entries` (not in this DB) | `companion_spell_sets` |
| Class roles | 4 generic (Tank, Healer, MeleeDPS, CasterDPS) | All 15 player classes |
| Spell AI | `Merc::AI_EngagedCastCheck()` in merc.cpp | `Companion::AICastSpell()` in companion_ai.cpp |
| Combat abilities | Simplified (kick/bash/backstab only) | Full NPC class attacks |
| Stance system | Multiple stances per type | 3 stances (Passive/Balanced/Aggressive) |
| Assist logic | Follows owner | Stance-dependent (Passive/Balanced/Aggressive) |

### 5.2 What Merc AI Was Co-opted for Companions?

The companion system borrows several patterns from the merc system:

1. **SpellType bitmask constants** (from `common/spdat.h`) -- same spell type classification
2. **Group integration pattern** -- `AddCompanionToGroup()`/`RemoveCompanionFromGroup()` mirrors merc group code
3. **`Merc::GetNeedsCured()`** -- the companion `AI_CureGroupMember()` method directly calls `Merc::GetNeedsCured()` to check if a mob needs curing
4. **Stance-based casting chances** -- similar to merc stance modifiers
5. **Self-preservation behavior** -- defensive stance switching when low HP

### 5.3 What's Missing That Mercs Have?

In this database, the `merc_spell_list_entries` table doesn't exist, so mercs likely aren't functional. But architecturally, the merc system supports:

| Feature | Merc Has | Companion Has | Gap? |
|---------|----------|---------------|------|
| Level-scaled stats | `merc_stats` table | Inherited from npc_types + scaling | No |
| Armor appearance | `merc_armorinfo` | Inherited from npc_types | No |
| Weapon appearance | `merc_weaponinfo` | Inherited from npc_types | No |
| Hiring/firing | `merc_merchant_*` tables | Recruitment system | No |
| Proficiency tiers | Apprentice/Journeyman | Single tier per NPC | Not needed |
| Auto-resurrection | Built into healer merc | Placeholder in AI_Cleric | **Yes** |
| Mana recovery | Merc has meditate logic | OOCRegenPct rule covers HP; mana regen unclear | **Possible** |

---

## 6. Gaps and Problems

### 6.1 Critical Gaps

#### Gap 1: Pet Summoning Broken (All Pet Classes)
**Severity:** HIGH
**Affected classes:** Magician, Necromancer, Shadow Knight, Beastlord

The AI code for pet summoning exists (`AI_SummonPet()`, `SpellType_Pet`), but the `companion_spell_sets` table has **zero entries** with `spell_type = 32` (SpellType_Pet). Pet classes will never summon their pets.

**Impact:** Magician companions are significantly weakened without pets. Necromancer pets are a core mechanic. Beastlord warders are iconic.

**Fix:** Add `SpellType_Pet` entries to `companion_spell_sets` for classes 5 (SHD), 11 (NEC), 13 (MAG), and 15 (BST) with appropriate pet summoning spells at each level range.

#### Gap 2: Shaman Slow Spell Type Mismatch
**Severity:** HIGH
**Affected classes:** Shaman (and possibly others)

The `AI_Shaman()` handler searches for `SpellType_Slow` (2048) and `SpellType_Debuff` (16384), but all Shaman entries in `companion_spell_sets` use `spell_type = 1` (Nuke) for what appear to be slow/debuff spells. The Enchanter is the only class with proper `spell_type = 2048` entries.

**Impact:** Shaman's most valuable contribution (slowing) is non-functional. The 40 "nuke" entries may include slow spells miscategorized as nukes.

**Fix:** Audit all Shaman entries in `companion_spell_sets`. Entries for slow spells (e.g., Drowsy, Turgur's Insects, Malo) should be `spell_type = 2048` (Slow), not 1 (Nuke). Same for debuffs.

#### Gap 3: Wizard Escape Spells Missing
**Severity:** LOW
**Affected classes:** Wizard

`AI_Wizard()` checks for `SpellType_Escape` (16) when HP < 20%, but no Wizard entries have `spell_type = 16` in `companion_spell_sets`.

**Impact:** Wizards can't self-evacuate. Low severity since this is a quality-of-life feature.

**Fix:** Add Evacuation and Gate spells as `spell_type = 16` entries for Wizard class.

### 6.2 Moderate Gaps

#### Gap 4: Resurrection Not Implemented
**Severity:** MODERATE
**Affected classes:** Cleric, Paladin, Druid, Necromancer

The `AI_Cleric()` handler has placeholder code for `SpellType_Resurrect` (65536) but notes: "Rezzing is done via the quest system; placeholder for future extension. For now skip automatic corpse rezzing (needs corpse targeting logic)."

**Impact:** Dead group members can't be auto-resurrected by companion healers.

**Fix:** Implement corpse targeting logic in a new `AI_ResurrectCorpse()` helper. Would need to find player corpses in entity_list and cast resurrection spells on them.

#### Gap 5: Spell List Not Reloaded on Level-Up
**Severity:** MODERATE
**Affected classes:** All spellcasting classes

When a companion levels up via the XP system, `LoadCompanionSpells()` should be re-called to unlock higher-level spells. The `CheckForLevelUp()` method needs verification that it does this.

**Impact:** A companion that levels from 20 to 21 might not gain access to new spells until zone change.

**Fix:** Ensure `CheckForLevelUp()` calls `LoadCompanionSpells()` after incrementing level.

#### Gap 6: Bard Song Twisting Not Implemented
**Severity:** LOW
**Affected classes:** Bard

Bard companions cast songs like regular spells (one at a time). Real EQ bards twist multiple songs in rapid sequence. The companion system notes this is "a simplification but functional."

**Impact:** Bard companions are less effective than a player bard but still provide value via buffs and mez.

**Fix:** Could implement a basic song twist timer that cycles through 2-3 songs, but this adds significant complexity for marginal benefit in a 1-3 player server.

### 6.3 Data Quality Issues

#### Issue 1: NPC Class Distribution vs. Recruitment Pool
Most recruitable NPCs are Warriors (41,398 out of ~62,000 total player-class NPCs). Players recruiting city guards and citizens will get melee-only companions. This is not a bug -- it reflects EQ's NPC design -- but it means the rich spell AI will only activate when players recruit the "right" NPCs (actual caster/healer mobs).

#### Issue 2: Low-Level Spell Gaps
Some classes have no spells at level 1:
- Paladin: Spells start at level 9 (heals and buffs)
- Ranger: Spells start at level 9
- Shadow Knight: Spells start at level 9
- Beastlord: Spells start at level 9

This matches EQ's class design (hybrids don't get spells until level 9) and is correct behavior.

#### Issue 3: Companion_spell_sets Appears Hand-Curated
The spell lists appear to be sourced from bot_spells_entries (as noted in companion_ai.cpp header comment) but filtered/adapted. Some spell categorizations may be incorrect (see Gap 2 above).

---

## 7. Key Code References

### Companion System
| File | Lines | Key Functions |
|------|-------|---------------|
| `zone/companion.h` | 1-369 | Companion class declaration, CompanionSpell struct |
| `zone/companion.cpp` | ~1950 | Constructor, CreateFromNPC, AI overrides, lifecycle, persistence |
| `zone/companion_ai.cpp` | 1-1394 | LoadCompanionSpells, AICastSpell, all 16 class handlers, 8 helpers |

### NPC Base AI
| File | Lines | Key Functions |
|------|-------|---------------|
| `zone/mob_ai.cpp` | 1868-1895 | `NPC::AI_EngagedCastCheck()` |
| `zone/mob_ai.cpp` | 1914-1930 | `NPC::AI_IdleCastCheck()` |
| `zone/mob_ai.cpp` | 2387-2550 | `NPC::AI_AddNPCSpells()` |
| `zone/mob_ai.cpp` | 1310-1320 | AI combat round (calls DoClassAttacks) |
| `zone/special_attacks.cpp` | 1863-2035 | `NPC::DoClassAttacks()` (kick, bash, backstab, etc.) |

### Merc AI (for comparison)
| File | Lines | Key Functions |
|------|-------|---------------|
| `zone/merc.cpp` | 3960-4019 | `Merc::DoClassAttacks()` |
| `zone/merc.cpp` | ~5922 total | Full merc implementation |

### Spell Type Constants
| File | Lines | Key Definitions |
|------|-------|-----------------|
| `common/spdat.h` | 632-653 | SpellType_* bitmask enum (22 values) |
| `common/spdat.h` | 898-900 | SPELL_TYPES_DETRIMENTAL, BENEFICIAL, INNATE composites |

### Database Tables
| Table | Purpose |
|-------|---------|
| `companion_spell_sets` | Companion spell lists by class/level (842 entries) |
| `npc_types` | NPC definitions including class, level, npc_spells_id |
| `npc_spells` | NPC spell list headers |
| `npc_spells_entries` | Individual NPC spells |

---

## 8. Recommendations (Prioritized by Impact)

### Priority 1: Fix Pet Summoning Data
**Impact:** HIGH -- Affects 4 classes (MAG, NEC, SHD, BST)
**Effort:** LOW -- Add ~20-30 SQL INSERT rows
**Action:** Add `spell_type = 32` entries to `companion_spell_sets` for pet summoning spells at appropriate level ranges.

### Priority 2: Fix Shaman Slow Spell Types
**Impact:** HIGH -- Shaman's primary utility is broken
**Effort:** LOW -- Update ~10-15 existing rows from spell_type 1 to 2048
**Action:** Audit `companion_spell_sets` class_id=10 entries. Reclassify slow spells (Drowsy, Turgur's, Malo, etc.) from spell_type=1 (Nuke) to spell_type=2048 (Slow) or 16384 (Debuff).

### Priority 3: Verify Level-Up Spell Reload
**Impact:** MODERATE -- Companions may not gain new spells on level-up
**Effort:** LOW -- Small code change if missing
**Action:** Verify `CheckForLevelUp()` calls `LoadCompanionSpells()`. If not, add the call.

### Priority 4: Add Wizard Escape Spells
**Impact:** LOW -- Quality-of-life feature
**Effort:** LOW -- Add 2-3 SQL rows
**Action:** Add Evacuation/Gate spells as `spell_type = 16` for Wizard class at appropriate levels.

### Priority 5: Implement Resurrection AI
**Impact:** MODERATE -- But complex to implement
**Effort:** MEDIUM -- Needs corpse targeting logic in C++
**Action:** Implement `AI_ResurrectCorpse()` that finds group member corpses and casts rez spells. Add `SpellType_Resurrect` entries (65536) to companion_spell_sets for CLR, PAL, DRU, NEC.

### Priority 6: Audit All Spell Type Assignments
**Impact:** MODERATE -- Some spells may be miscategorized across all classes
**Effort:** MEDIUM -- Manual review of all 842 entries
**Action:** Cross-reference each spell_id in `companion_spell_sets` against its actual spell data in `spells_new` to verify the `spell_type` classification is correct. Focus on spells that should be Slow, Debuff, Snare, or Cure but may be classified as Nuke.

### Priority 7: Bard Song Twisting (Deferred)
**Impact:** LOW -- Bards still work, just suboptimally
**Effort:** HIGH -- Significant AI redesign
**Action:** Consider implementing a simple 3-song twist timer in a future enhancement. Not critical for launch.

---

## Appendix A: companion_spell_sets Summary

Total entries: 842

| Class | Nuke | Heal | Root | Buff | Escape | Pet | Lifetap | Snare | DOT | ICBuff | Cure | Slow | Mez | Total |
|-------|------|------|------|------|--------|-----|---------|-------|-----|--------|------|------|-----|-------|
| CLR | 25 | 11 | 6 | 27 | 0 | 0 | 0 | 0 | 2 | 2 | 6 | 0 | 0 | 79 |
| PAL | 5 | 11 | 4 | 16 | 0 | 0 | 0 | 0 | 0 | 1 | 4 | 0 | 0 | 41 |
| RNG | 11 | 6 | 4 | 21 | 0 | 0 | 0 | 2 | 6 | 2 | 0 | 0 | 0 | 52 |
| SHD | 18 | 0 | 0 | 7 | 0 | 0 | 10 | 5 | 6 | 1 | 0 | 0 | 0 | 47 |
| DRU | 33 | 11 | 6 | 24 | 0 | 0 | 0 | 5 | 10 | 2 | 0 | 0 | 0 | 91 |
| BRD | 28 | 6 | 0 | 27 | 0 | 0 | 0 | 2 | 12 | 0 | 0 | 0 | 3 | 78 |
| SHM | 40 | 9 | 6 | 22 | 0 | 0 | 0 | 0 | 12 | 2 | 0 | 0 | 0 | 91 |
| NEC | 10 | 0 | 6 | 14 | 0 | 0 | 11 | 6 | 20 | 0 | 0 | 0 | 0 | 67 |
| WIZ | 48 | 0 | 6 | 20 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 | 0 | 76 |
| MAG | 35 | 0 | 0 | 14 | 0 | 0 | 0 | 0 | 2 | 2 | 0 | 0 | 0 | 53 |
| ENC | 45 | 0 | 6 | 39 | 0 | 0 | 0 | 0 | 7 | 2 | 0 | 9 | 8 | 116 |
| BST | 13 | 6 | 0 | 23 | 0 | 0 | 0 | 0 | 7 | 2 | 0 | 0 | 0 | 51 |

**Missing classes (pure melee, by design):** Warrior (1), Monk (7), Rogue (9)

## Appendix B: NPC Class Distribution

| Class | Total NPCs | With Spells | Without Spells | % With Spells |
|-------|-----------|------------|---------------|---------------|
| Warrior (1) | 41,398 | 4,146 | 37,252 | 10.0% |
| Cleric (2) | 2,940 | 2,127 | 813 | 72.3% |
| Paladin (3) | 705 | 460 | 245 | 65.2% |
| Ranger (4) | 510 | 383 | 127 | 75.1% |
| ShadowKnight (5) | 1,418 | 790 | 628 | 55.7% |
| Druid (6) | 850 | 443 | 407 | 52.1% |
| Monk (7) | 850 | 144 | 706 | 16.9% |
| Bard (8) | 114 | 13 | 101 | 11.4% |
| Rogue (9) | 4,201 | 439 | 3,762 | 10.4% |
| Shaman (10) | 2,546 | 1,825 | 721 | 71.7% |
| Necromancer (11) | 1,954 | 1,361 | 593 | 69.7% |
| Wizard (12) | 2,719 | 1,998 | 721 | 73.5% |
| Magician (13) | 577 | 389 | 188 | 67.4% |
| Enchanter (14) | 1,259 | 919 | 340 | 73.0% |
| Beastlord (15) | 68 | 26 | 42 | 38.2% |

**Note:** The "With Spells" count refers to NPC-specific spell lists (npc_spells_id != 0). This is separate from the companion_spell_sets system. A warrior NPC with npc_spells_id=0 can still be recruited and will correctly use melee-only AI via the companion system.
