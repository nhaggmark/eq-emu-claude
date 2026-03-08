# Companion AI Spell Data Gaps — Architecture Assessment

**Date:** 2026-03-08
**Author:** architect (systems)
**Input:** Research doc `claude/docs/research/2026-03-08-companion-ai-class-behavior.md`
**Status:** Complete

---

## Executive Summary

Three data gaps were identified in the companion AI spell system. Investigation reveals:

1. **Gap 1 (Pet Summoning):** Confirmed. Zero `SpellType_Pet` (32) entries exist in `companion_spell_sets`. Pet summoning code works but has no data to operate on. Affects MAG, NEC, SHD, BST. **Fix: Add SQL rows.**
2. **Gap 2 (Shaman Slow Miscategorized):** Confirmed and broader than reported. The issue affects ALL classes that have slow or debuff spells, not just shaman. There are zero entries with `SpellType_Slow` (8192) or `SpellType_Debuff` (16384) in the entire table. Slow and debuff spells are universally miscategorized as `SpellType_Nuke` (1). **Fix: UPDATE existing SQL rows.**
3. **Gap 3 (Level-up Spell Reload):** NOT A GAP. `CheckForLevelUp()` at companion.cpp:1629 already calls `LoadCompanionSpells()`. The spell list is correctly reloaded on every level-up. **No fix needed.**

---

## Gap 1: Pet Summoning — Missing SpellType_Pet Entries

### Root Cause

The `companion_spell_sets` table contains zero rows with `spell_type = 32` (SpellType_Pet). The companion AI code in `companion_ai.cpp` has a fully functional `AI_SummonPet()` method (line 623) that queries for SpellType_Pet spells via `SelectFirstSpell()`, but finds nothing.

**Affected AI handlers:**
- `AI_ShadowKnight()` (line 794): `if (iSpellTypes & SpellType_Pet) { if (AI_SummonPet()) ... }`
- `AI_Beastlord()` (line 1097): `if (iSpellTypes & SpellType_Pet) { if (AI_SummonPet()) ... }`
- `AI_Magician()` (line 1189): `if (iSpellTypes & SpellType_Pet) { if (AI_SummonPet()) ... }`
- `AI_Necromancer()` (line 1223): `if (iSpellTypes & SpellType_Pet) { if (AI_SummonPet()) ... }`

### Spell Effect Analysis

Pet summoning spells use different effect IDs per class:
- **Magician (class 13):** `effectid1 = 33` (SE_SummonPet) — elemental pets
- **Necromancer (class 11):** `effectid1 = 71` (SE_NecPet) — undead pets
- **Shadow Knight (class 5):** `effectid1 = 71` (SE_NecPet) — undead pets (shared with NEC)
- **Beastlord (class 15):** `effectid1 = 106` (SE_SummonBSTPet) — warder pets

### The Specific Fix

Add one pet summoning spell per level range for each affected class. Use the **best available pet** at each tier (companions should pick the highest-level pet they can use, not cycle through four elements).

For **Magician**, use Earth pets (highest DPS/tank utility) as the default. One spell per 5-level band:

```sql
-- MAG pet spells (class_id=13, spell_type=32=SpellType_Pet)
-- Using Earth pets for consistency (highest melee DPS)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct) VALUES
(13, 5, 8, 58, 32, 0, 1, 0, 100),    -- Elementalkin: Earth (MAG 5)
(13, 9, 12, 397, 32, 0, 1, 0, 100),   -- Elementaling: Earth (MAG 9)
(13, 13, 16, 401, 32, 0, 1, 0, 100),  -- Elemental: Earth (MAG 13)
(13, 17, 20, 335, 32, 0, 1, 0, 100),  -- Minor Summoning: Earth (MAG 17)
(13, 21, 24, 496, 32, 0, 1, 0, 100),  -- Lesser Summoning: Earth (MAG 21)
(13, 25, 28, 569, 32, 0, 1, 0, 100),  -- Summoning: Earth (MAG 25)
(13, 29, 33, 573, 32, 0, 1, 0, 100),  -- Greater Summoning: Earth (MAG 29)
(13, 34, 38, 620, 32, 0, 1, 0, 100),  -- Minor Conjuration: Earth (MAG 34)
(13, 39, 43, 624, 32, 0, 1, 0, 100),  -- Lesser Conjuration: Earth (MAG 39)
(13, 44, 45, 628, 32, 0, 1, 0, 100),  -- Conjuration: Earth (MAG 44)
(13, 46, 50, 632, 32, 0, 1, 0, 100),  -- Greater Conjuration: Earth (MAG 46)
(13, 51, 56, 1671, 32, 0, 1, 0, 100), -- Vocarate: Earth (MAG 51)
(13, 57, 60, 1675, 32, 0, 1, 0, 100), -- Greater Vocaration: Earth (MAG 57)
(13, 61, 64, 3320, 32, 0, 1, 0, 100), -- Servant of Marr (MAG 62)
(13, 65, 65, 3324, 32, 0, 1, 0, 100); -- Rathe's Son (MAG 65)
```

For **Necromancer** (class 11, effect 71 = SE_NecPet):

```sql
-- NEC pet spells (class_id=11, spell_type=32=SpellType_Pet)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct) VALUES
(11, 1, 3, 338, 32, 0, 1, 0, 100),    -- Cavorting Bones (NEC 1)
(11, 4, 7, 491, 32, 0, 1, 0, 100),    -- Leering Corpse (NEC 4)
(11, 8, 11, 351, 32, 0, 1, 0, 100),   -- Bone Walk (NEC 8)
(11, 12, 15, 362, 32, 0, 1, 0, 100),  -- Convoke Shadow (NEC 12)
(11, 16, 19, 492, 32, 0, 1, 0, 100),  -- Restless Bones (NEC 16)
(11, 20, 23, 440, 32, 0, 1, 0, 100),  -- Animate Dead (NEC 20)
(11, 24, 28, 493, 32, 0, 1, 0, 100),  -- Haunting Corpse (NEC 24)
(11, 29, 32, 441, 32, 0, 1, 0, 100),  -- Summon Dead (NEC 29)
(11, 33, 38, 494, 32, 0, 1, 0, 100),  -- Invoke Shadow (NEC 33)
(11, 39, 43, 442, 32, 0, 1, 0, 100),  -- Malignant Dead (NEC 39)
(11, 44, 47, 495, 32, 0, 1, 0, 100),  -- Cackling Bones (NEC 44)
(11, 48, 52, 443, 32, 0, 1, 0, 100),  -- Invoke Death (NEC 48)
(11, 53, 55, 1621, 32, 0, 1, 0, 100), -- Minion of Shadows (NEC 53)
(11, 56, 58, 1622, 32, 0, 1, 0, 100), -- Servant of Bones (NEC 56)
(11, 59, 60, 1623, 32, 0, 1, 0, 100), -- Emissary of Thule (NEC 59)
(11, 61, 62, 3304, 32, 0, 1, 0, 100), -- Legacy of Zek (NEC 61)
(11, 63, 64, 3310, 32, 0, 1, 0, 100), -- Saryrn's Companion (NEC 63)
(11, 65, 65, 3314, 32, 0, 1, 0, 100); -- Child of Bertoxxulous (NEC 65)
```

For **Shadow Knight** (class 5, effect 71 = SE_NecPet):

```sql
-- SHD pet spells (class_id=5, spell_type=32=SpellType_Pet)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct) VALUES
(5, 7, 13, 491, 32, 0, 1, 0, 100),    -- Leering Corpse (SHD 7)
(5, 14, 21, 351, 32, 0, 1, 0, 100),   -- Bone Walk (SHD 14)
(5, 22, 29, 362, 32, 0, 1, 0, 100),   -- Convoke Shadow (SHD 22)
(5, 30, 37, 492, 32, 0, 1, 0, 100),   -- Restless Bones (SHD 30)
(5, 38, 45, 440, 32, 0, 1, 0, 100),   -- Animate Dead (SHD 38)
(5, 46, 51, 441, 32, 0, 1, 0, 100),   -- Summon Dead (SHD 46)
(5, 52, 57, 442, 32, 0, 1, 0, 100),   -- Malignant Dead (SHD 52)
(5, 58, 63, 495, 32, 0, 1, 0, 100),   -- Cackling Bones (SHD 58)
(5, 64, 65, 443, 32, 0, 1, 0, 100);   -- Invoke Death (SHD 64)
```

For **Beastlord** (class 15, effect 106 = SE_SummonBSTPet):

```sql
-- BST warder spells (class_id=15, spell_type=32=SpellType_Pet)
INSERT INTO companion_spell_sets (class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct) VALUES
(15, 8, 14, 2612, 32, 0, 1, 0, 100),  -- Spirit of Sharik (BST 8)
(15, 15, 20, 2633, 32, 0, 1, 0, 100), -- Spirit of Khaliz (BST 15)
(15, 21, 29, 2614, 32, 0, 1, 0, 100), -- Spirit of Keshuval (BST 21)
(15, 30, 38, 2616, 32, 0, 1, 0, 100), -- Spirit of Herikol (BST 30)
(15, 39, 45, 2618, 32, 0, 1, 0, 100), -- Spirit of Yekan (BST 39)
(15, 46, 53, 2621, 32, 0, 1, 0, 100), -- Spirit of Kashek (BST 46)
(15, 54, 55, 2623, 32, 0, 1, 0, 100), -- Spirit of Omakin (BST 54)
(15, 56, 57, 2626, 32, 0, 1, 0, 100), -- Spirit of Zehkes (BST 56)
(15, 58, 59, 2627, 32, 0, 1, 0, 100), -- Spirit of Khurenz (BST 58)
(15, 60, 61, 2631, 32, 0, 1, 0, 100), -- Spirit of Khati Sha (BST 60)
(15, 62, 63, 3457, 32, 0, 1, 0, 100), -- Spirit of Arag (BST 62)
(15, 64, 65, 3461, 32, 0, 1, 0, 100); -- Spirit of Sorsha (BST 64)
```

### Assigned Agent: **data-expert**

### Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Pet spell mana cost may exceed companion mana pool | LOW | `AI_SummonPet()` already checks mana via `AIDoSpellCast()` which validates mana. Companion will wait until it has enough mana. |
| Companion pet + companion creates visual clutter | LOW | Acceptable for 1-3 player server. Pet is a core class mechanic. |
| Pet spell cast time blocks companion from combat | LOW | Pets are only summoned when idle (not engaged). All AI handlers check `IsEngaged()` before calling `AI_SummonPet()`. |
| NEC/SHD pets use SE_NecPet (71), not SE_SummonPet (33) | MEDIUM | The `AIDoSpellCast()` function calls the standard `CastSpell()` path which handles all pet effect types. The SpellType_Pet classification in companion_spell_sets is a routing tag, not an effect filter. Verified: `AI_SummonPet` casts the spell normally — the engine's spell effect handler (SE_NecPet=71 in spell_effects.cpp) handles the actual pet creation. No code change needed. |
| BST pets use SE_SummonBSTPet (106) | MEDIUM | Same as above — the engine handles effect 106. The SpellType_Pet tag just tells the AI "this is a pet summoning spell." |

---

## Gap 2: Slow/Debuff Spells Miscategorized — Broader Than Reported

### Root Cause

The research document identified shaman slow spells as miscategorized. Investigation reveals the problem is systemic:

**The entire `companion_spell_sets` table has ZERO entries with:**
- `spell_type = 8192` (SpellType_Slow)
- `spell_type = 16384` (SpellType_Debuff)

All slow and debuff spells across ALL classes are classified as `spell_type = 1` (SpellType_Nuke).

**Note on the research document's error:** The research claimed "SpellType_Slow = 2048" and stated enchanter had "properly populated Slow (2048) entries." This is incorrect. `SpellType_Slow = (1 << 13) = 8192`. The value 2048 is `SpellType_Mez = (1 << 11)`. The enchanter entries at spell_type=2048 are correctly classified mez spells. No class has any SpellType_Slow entries.

### Affected Spells by Class

The following spells are currently `spell_type = 1` (Nuke) but should be reclassified. Classification is based on spell effect analysis:

**SpellType_Slow (8192)** — spells with `effectid2 = 11` (SE_AttackSpeed) as primary function:

| class_id | Row ID | spell_id | Spell Name | Current Type | Correct Type |
|----------|--------|----------|------------|-------------|--------------|
| 10 (SHM) | 600 | 270 | Drowsy | 1 (Nuke) | 8192 (Slow) |
| 10 (SHM) | 615 | 505 | Walking Sleep | 1 (Nuke) | 8192 (Slow) |
| 10 (SHM) | 616 | 506 | Tagar's Insects | 1 (Nuke) | 8192 (Slow) |
| 10 (SHM) | 617 | 507 | Togor's Insects | 1 (Nuke) | 8192 (Slow) |
| 10 (SHM) | 637 | 1588 | Turgur's Insects | 1 (Nuke) | 8192 (Slow) |
| 10 (SHM) | 638 | 1589 | Tigir's Insects | 1 (Nuke) | 8192 (Slow) |
| 10 (SHM) | 643 | 2527 | Plague of Insects | 1 (Nuke) | 8192 (Slow) |
| 10 (SHM) | 649 | 3380 | Cloud of Grummus | 1 (Nuke) | 8192 (Slow) |
| 8 (BRD) | 1020 | 705 | Largo's Melodic Binding | 1 (Nuke) | 8192 (Slow) |
| 8 (BRD) | 1056 | 1751 | Largo's Assonant Binding | 1 (Nuke) | 8192 (Slow) |
| 8 (BRD) | 1055 | 1748 | Angstlich's Assonance | 1 (Nuke) | 8192 (Slow) |
| 8 (BRD) | 1075 | 3066 | Requiem of Time | 1 (Nuke) | 8192 (Slow) |
| 14 (ENC) | 495 | 302 | Languid Pace | 1 (Nuke) | 8192 (Slow) |
| 14 (ENC) | 474 | 185 | Tepid Deeds | 1 (Nuke) | 8192 (Slow) |
| 14 (ENC) | 543 | 1712 | Forlorn Deeds | 1 (Nuke) | 8192 (Slow) |
| 15 (BST) | 1158 | 270 | Drowsy | 1 (Nuke) | 8192 (Slow) |
| 15 (BST) | 1180 | 2634 | Sha's Lethargy | 1 (Nuke) | 8192 (Slow) |
| 15 (BST) | 1185 | 3462 | Sha's Revenge | 1 (Nuke) | 8192 (Slow) |

**SpellType_Debuff (16384)** — spells whose primary function is stat/resist reduction without attack speed slow:

| class_id | Row ID | spell_id | Spell Name | Current Type | Correct Type |
|----------|--------|----------|------------|-------------|--------------|
| 10 (SHM) | 581 | 110 | Malaise | 1 (Nuke) | 16384 (Debuff) |
| 10 (SHM) | 582 | 111 | Malaisement | 1 (Nuke) | 16384 (Debuff) |
| 10 (SHM) | 583 | 112 | Malosi | 1 (Nuke) | 16384 (Debuff) |
| 10 (SHM) | 631 | 1578 | Malo | 1 (Nuke) | 16384 (Debuff) |
| 10 (SHM) | 653 | 3387 | Malosinia | 1 (Nuke) | 16384 (Debuff) |
| 10 (SHM) | 657 | 3395 | Malos | 1 (Nuke) | 16384 (Debuff) |
| 10 (SHM) | 605 | 281 | Disempower | 1 (Nuke) | 16384 (Debuff) |
| 10 (SHM) | 590 | 162 | Listless Power | 1 (Nuke) | 16384 (Debuff) |
| 10 (SHM) | 591 | 163 | Incapacitate | 1 (Nuke) | 16384 (Debuff) |
| 10 (SHM) | 641 | 1592 | Cripple | 1 (Nuke) | 16384 (Debuff) |
| 5 (SHD) | 896 | 343 | Siphon Strength | 1 (Nuke) | 16384 (Debuff) |
| 5 (SHD) | 920 | 2571 | Despair | 1 (Nuke) | 16384 (Debuff) |
| 5 (SHD) | 921 | 2572 | Scream of Hate | 1 (Nuke) | 16384 (Debuff) |
| 5 (SHD) | 904 | 370 | Shadow Vortex | 1 (Nuke) | 16384 (Debuff) |
| 5 (SHD) | 917 | 1457 | Shroud of Hate | 1 (Nuke) | 16384 (Debuff) |
| 5 (SHD) | 918 | 1458 | Shroud of Pain | 1 (Nuke) | 16384 (Debuff) |
| 5 (SHD) | 922 | 2575 | Abduction of Strength | 1 (Nuke) | 16384 (Debuff) |
| 5 (SHD) | 923 | 2577 | Torrent of Hate | 1 (Nuke) | 16384 (Debuff) |
| 5 (SHD) | 924 | 2578 | Torrent of Pain | 1 (Nuke) | 16384 (Debuff) |
| 5 (SHD) | 925 | 2579 | Torrent of Fatigue | 1 (Nuke) | 16384 (Debuff) |
| 5 (SHD) | 929 | 3403 | Aura of Pain | 1 (Nuke) | 16384 (Debuff) |
| 14 (ENC) | 483 | 281 | Disempower | 1 (Nuke) | 16384 (Debuff) |
| 14 (ENC) | 461 | 162 | Listless Power | 1 (Nuke) | 16384 (Debuff) |
| 14 (ENC) | 462 | 163 | Incapacitate | 1 (Nuke) | 16384 (Debuff) |
| 14 (ENC) | 545 | 1715 | Largarn's Lamentation | 1 (Nuke) | 16384 (Debuff) |
| 15 (BST) | 1150 | 162 | Listless Power | 1 (Nuke) | 16384 (Debuff) |
| 15 (BST) | 1151 | 163 | Incapacitate | 1 (Nuke) | 16384 (Debuff) |
| 15 (BST) | 1177 | 2492 | Ensnaring Concoction II | 1 (Nuke) | 16384 (Debuff) |
| 13 (MAG) | 391 | 110 | Malaise | 1 (Nuke) | 16384 (Debuff) |
| 13 (MAG) | 392 | 111 | Malaisement | 1 (Nuke) | 16384 (Debuff) |
| 13 (MAG) | 393 | 112 | Malosi | 1 (Nuke) | 16384 (Debuff) |
| 13 (MAG) | 424 | 1772 | Mala | 1 (Nuke) | 16384 (Debuff) |
| 13 (MAG) | 434 | 3387 | Malosinia | 1 (Nuke) | 16384 (Debuff) |

**Edge cases — spells with mixed effects (debuff + other):**

| class_id | Row ID | spell_id | Spell Name | Decision | Rationale |
|----------|--------|----------|------------|----------|-----------|
| 6 (DRU) | 756 | 1437 | Ro's Fiery Sundering | Keep as Nuke | Primary effect is DD; resist debuff is secondary |
| 6 (DRU) | 755 | 1436 | Fixation of Ro | Keep as Nuke | Primary effect is DD; debuff is secondary |
| 6 (DRU) | 788 | 3695 | Frost Zephyr | Keep as Nuke | Primary effect is DD |
| 6 (DRU) | 773 | 2518 | Ro's Smoldering Disjunction | Keep as Nuke | Primary effect is DD |
| 2 (CLR) | 58 | 1545 | The Unspoken Word | Keep as Nuke | Primary effect is stun (effectid1=20); debuff is secondary |
| 2 (CLR) | 69 | 3464 | The Silent Command | Keep as Nuke | Mixed effect, primarily offensive |
| 8 (BRD) | 1022 | 707 | Fufil's Curtailing Chant | Keep as Nuke | DD with minor resist debuff |
| 8 (BRD) | 1057 | 1753 | Song of Twilight | Keep as Nuke | Mez+debuff, but already not used as mez due to type=1 |
| 8 (BRD) | 1053 | 1451 | Occlusion of Sound | Keep as Nuke | FR/CR debuff but used offensively |
| 8 (BRD) | 1064 | 1761 | Cassindra's Insipid Ditty | Keep as Nuke | Mana drain with debuff |
| 8 (BRD) | 1088 | 3375 | Harmony of Sound | Keep as Nuke | FR/CR debuff but used offensively |
| 11 (NEC) | 308 | 2014 | Incinerate Bones | Keep as Nuke | Primary is DD vs undead |
| 11 (NEC) | 309 | 2015 | Conglaciation of Bone | Keep as Nuke | DD with resist debuff |

### The Specific Fix

A batch UPDATE statement to reclassify affected rows:

```sql
-- SLOW reclassification: spell_type 1 → 8192 (SpellType_Slow)
-- These spells have effectid2=11 (AttackSpeed) as primary utility
UPDATE companion_spell_sets SET spell_type = 8192 WHERE id IN (
  -- SHM slows
  600, 615, 616, 617, 637, 638, 643, 649,
  -- BRD slows
  1020, 1056, 1055, 1075,
  -- ENC slows
  495, 474, 543,
  -- BST slows
  1158, 1180, 1185
);

-- DEBUFF reclassification: spell_type 1 → 16384 (SpellType_Debuff)
-- These spells reduce stats/resists without attack speed component
UPDATE companion_spell_sets SET spell_type = 16384 WHERE id IN (
  -- SHM debuffs (Malo line, Cripple, stat debuffs)
  581, 582, 583, 631, 653, 657, 605, 590, 591, 641,
  -- SHD debuffs (strength/stat drains)
  896, 920, 921, 904, 917, 918, 922, 923, 924, 925, 929,
  -- ENC debuffs (stat debuffs)
  483, 461, 462, 545,
  -- BST debuffs (stat debuffs)
  1150, 1151, 1177,
  -- MAG debuffs (Malo line)
  391, 392, 393, 424, 434
);
```

### AI Code Impact

The `AI_SlowDebuff()` helper (companion_ai.cpp:566) already searches for `SpellType_Slow | SpellType_Debuff` (8192 | 16384). After the data fix, it will find the appropriate spells.

Classes with slow/debuff AI logic that will benefit:
- **Shaman** (`AI_Shaman`, line 960): Calls `AI_SlowDebuff()` with 70% roll — will now actually slow targets
- **Enchanter** (`AI_Enchanter`, line 1275): Calls `AI_SlowDebuff()` with 60% roll — will now use Languid Pace/Tepid Deeds/Forlorn Deeds
- **Beastlord** (`AI_Beastlord`, line 1108): Calls `AI_SlowDebuff()` with 50% roll — will now slow with Drowsy/Sha's Lethargy
- **Shadow Knight** (`AI_ShadowKnight`): Does NOT currently call `AI_SlowDebuff()`. The debuff entries will be available if the handler is updated later, but for now SHD debuffs remain unused by the AI. This is acceptable — SHD's primary role is tank/DPS, not debuffer.

**No code changes needed for Gap 2.** The AI code already supports these spell types; only the data is wrong.

### Assigned Agent: **data-expert**

### Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Reclassifying removes spells from nuke rotation | EXPECTED | These spells do negligible damage; their utility is as slows/debuffs. Removing them from nuke rotation is correct behavior. |
| Shaman runs out of nukes after reclassification | LOW | After removing 17 slow/debuff spells from the 40 "nuke" entries, shaman retains 23 true nuke spells. Sufficient for DPS rotation. |
| SHD debuff entries unused by AI | NONE | Correct: SHD AI doesn't call `AI_SlowDebuff()`. Entries are properly classified for future use. |
| Some edge-case spells may be wrongly reclassified | LOW | Each spell was individually verified against `spells_new` effect data. The classification is based on primary effect ID, not spell name. |

---

## Gap 3: Level-Up Spell Reload — NOT A GAP

### Investigation Result

The `CheckForLevelUp()` method in `companion.cpp` at line 1629 **already calls** `LoadCompanionSpells()`:

```cpp
// companion.cpp:1621-1629
// Level up!
m_companion_xp -= xp_needed;
uint8 new_level = current_level + 1;

// Scale stats to new level
ScaleStatsToLevel(new_level);

// Reload spell list for new level
LoadCompanionSpells();  // <-- Line 1629
```

The level-up flow is:
1. `ProcessCompanionXP()` (line 1572) calls `CheckForLevelUp()` in a while loop
2. `CheckForLevelUp()` validates XP requirements and level cap
3. On success: calls `ScaleStatsToLevel(new_level)`, then `LoadCompanionSpells()`, then restores HP/mana, then `Save()`
4. The while loop handles cascading level-ups (multiple levels gained at once)

**No fix needed.** The research document flagged this as "needs verification" and the verification confirms it works correctly.

### Assigned Agent: None (no work required)

---

## Implementation Sequence

| Order | Task | Agent | Dependencies | Estimated Rows |
|-------|------|-------|-------------|----------------|
| 1 | Add pet summoning spells (Gap 1) | data-expert | None | ~54 INSERT rows |
| 2 | Reclassify slow/debuff spells (Gap 2) | data-expert | None | 2 UPDATE statements, ~49 rows total |

Both tasks are SQL-only and can be done in a single implementation pass by data-expert. No C++ changes needed. No build/restart cycle needed — quest reload or zone restart will pick up the new spell data since `LoadCompanionSpells()` queries the database on every companion recruitment and level-up.

### Validation Plan

After implementation, verify:

1. **Pet summoning**: Recruit a MAG, NEC, SHD, or BST NPC. Set stance to balanced or aggressive. Verify the companion summons a pet when idle. Verify pet despawns when companion is dismissed.
2. **Shaman slow**: Recruit a SHM NPC. Engage a mob. Verify the companion casts slow spells (Drowsy, Turgur's, etc.) on the target within the first few combat rounds.
3. **Enchanter slow**: Recruit an ENC NPC. Engage a mob. Verify the enchanter casts Languid Pace or equivalent on the target.
4. **Beastlord slow+pet**: Recruit a BST NPC. Verify it summons a warder when idle AND slows targets in combat.
5. **No regression — nukes still work**: Verify shaman companions still nuke targets (they should have ~23 true nuke spells remaining after reclassification).
6. **Level-up confirmation**: Grant a caster companion enough XP to level up. Verify new spells appear (can check via server logs: "loaded [N] spells from companion_spell_sets").

---

## Additional Findings (Not In Scope But Documented)

### Finding 1: Enchanter Charm Spells Classified as SpellType_Charm (4096)

The 8 enchanter entries with `spell_type = 4096` (SpellType_Charm) are charm spells (effectid1=22). The AI_Enchanter handler does NOT reference SpellType_Charm. These entries exist in the data but are never used by the AI.

**Impact:** None currently. Enchanter charm AI could be added later if desired.
**Action:** No change needed now.

### Finding 2: No Cure Spells in Table

Despite the research document claiming cleric has "6 cure entries," the actual data shows zero entries with `SpellType_Cure` (32768) across all classes. The 6 entries the research counted as "Cure" are actually 6 InCombatBuff (1024) entries (Yaulp series) or were miscounted from an adjacent row.

The `AI_CureGroupMember()` helper (companion_ai.cpp:497) searches for `SpellType_Cure` (32768) and will never find entries. This means clerics, druids, and shamans cannot cure disease/poison on group members.

**Impact:** MODERATE — curing is important for healer utility.
**Action:** Future task — add cure spell entries (Cure Disease, Cure Poison, Remove Curse, etc.) with `spell_type = 32768` for CLR, DRU, SHM, PAL, RNG.

### Finding 3: Magician Debuff Entries

The MAG class has 5 entries for Malaise/Malaisement/Malosi/Mala/Malosinia classified as nukes. These are resist debuffs. The MAG AI handler (`AI_Magician`) does NOT call `AI_SlowDebuff()`, so reclassifying these as SpellType_Debuff (16384) will move them out of the nuke rotation but they still won't be actively used. This is still correct — they shouldn't be in the nuke rotation since they do zero damage.

### Finding 4: BST Ensnaring Concoction II

Row 1177 (spell_id 2492, "Ensnaring Concoction II") for BST has effectid1=10 (resist debuff) and effectid2=3 (movement speed change). This could arguably be classified as SpellType_Snare (128) instead of SpellType_Debuff (16384). However, the BST AI handler doesn't check for snare, so classifying as Debuff is more useful since `AI_SlowDebuff()` checks for `SpellType_Slow | SpellType_Debuff`. The debuff classification allows this spell to be cast via the slow/debuff routine.

