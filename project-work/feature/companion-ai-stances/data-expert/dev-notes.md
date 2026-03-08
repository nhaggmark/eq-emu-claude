# companion-ai-stances — Dev Notes: Data Expert

> **Feature branch:** `feature/companion-ai-stances`
> **Agent:** data-expert
> **Task(s):** Task 1 (Insert pet spells), Task 2 (Reclassify slow/debuff spells)
> **Date started:** 2026-03-08
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Add 54 pet summoning spell rows (SpellType_Pet=32) for MAG, NEC, SHD, BST | None | Complete |
| 2 | Reclassify 18 slow spells (1→8192) and 33 debuff spells (1→16384) | None | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `claude/project-work/feature/companion-ai-stances/architect/spell-gaps-architecture.md` | All | Full architecture assessment with exact SQL, confirmed 3 gaps; Gap 1 (pet spells) and Gap 2 (slow/debuff reclassification) require data fixes; Gap 3 (level-up reload) confirmed already working |

### Key Findings

- `companion_spell_sets` had 842 rows total before changes
- Zero entries existed for spell_type=32 (SpellType_Pet), 8192 (SpellType_Slow), or 16384 (SpellType_Debuff)
- All slow and debuff spells across all classes were miscategorized as spell_type=1 (SpellType_Nuke)
- The C++ AI code in companion_ai.cpp already has full support for all three spell types — only the data was missing

### Implementation Plan

**Task 1:** INSERT 54 rows into companion_spell_sets for pet summoning spells, one per level band per class:
- MAG (class_id=13): 15 rows, Earth pets (SE_SummonPet=33), levels 5-65
- NEC (class_id=11): 18 rows, undead pets (SE_NecPet=71), levels 1-65
- SHD (class_id=5): 9 rows, undead pets (SE_NecPet=71), levels 7-65
- BST (class_id=15): 12 rows, warder pets (SE_SummonBSTPet=106), levels 8-65

**Task 2:** UPDATE existing rows to correct spell_type values:
- 18 slow spells: spell_type 1 → 8192 (rows: 600, 615, 616, 617, 637, 638, 643, 649, 1020, 1056, 1055, 1075, 495, 474, 543, 1158, 1180, 1185)
- 33 debuff spells: spell_type 1 → 16384 (rows: 581, 582, 583, 631, 653, 657, 605, 590, 591, 641, 896, 920, 921, 904, 917, 918, 922, 923, 924, 925, 929, 483, 461, 462, 545, 1150, 1151, 1177, 391, 392, 393, 424, 434)

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| INSERT ... VALUES (multi-row) | MariaDB standard syntax | Yes | Standard multi-row INSERT confirmed working |
| UPDATE ... WHERE id IN (...) | MariaDB standard syntax | Yes | Batch UPDATE by ID list confirmed working |
| ROW_COUNT() after DML | MariaDB built-in | Yes | Used to verify row counts after each statement |

### Plan Amendments

Plan confirmed — no amendments needed. Pre-execution SELECT verified all target IDs exist with spell_type=1 before UPDATEs were run.

---

## Stage 3: Socialize

Architecture doc assigned both tasks directly to data-expert with complete SQL provided. No blocking dependencies and no cross-expert coordination required for SQL-only data changes. Proceeding directly to build.

---

## Stage 4: Build

### Pre-Execution Verification

**Baseline state (before any changes):**
```
Total rows: 842
spell_type distribution:
  1  (Nuke)    = 311
  2            = 60
  4            = 44
  8            = 254
  64           = 21
  128          = 20
  256          = 84
  512          = 18
  1024         = 10
  2048         = 9
  4096         = 11
  32 (Pet)     = 0  ← gap confirmed
  8192 (Slow)  = 0  ← gap confirmed
  16384 (Debuff) = 0  ← gap confirmed
```

All 18 slow IDs pre-verified present with spell_type=1 before UPDATE.
All 33 debuff IDs pre-verified present with spell_type=1 before UPDATE.

### Implementation Log

#### 2026-03-08 — Task 1: Insert pet summoning spells

**What:** Inserted 54 rows into companion_spell_sets with spell_type=32 (SpellType_Pet)

**SQL executed:**

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
-- Result: 15 rows inserted

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
-- Result: 18 rows inserted

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
-- Result: 9 rows inserted

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
-- Result: 12 rows inserted
```

**Results:** 15 + 18 + 9 + 12 = 54 rows inserted (matches expected count)

---

#### 2026-03-08 — Task 2: Reclassify slow and debuff spells

**What:** Updated 18 slow spells (1→8192) and 33 debuff spells (1→16384) in companion_spell_sets

**SQL executed:**

```sql
-- SLOW reclassification: spell_type 1 -> 8192 (SpellType_Slow)
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
-- Result: 18 rows updated

-- DEBUFF reclassification: spell_type 1 -> 16384 (SpellType_Debuff)
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
-- Result: 33 rows updated
```

**Results:** 18 slow rows updated, 33 debuff rows updated (matches expected counts)

---

### Post-Execution Verification

**Final state (after all changes):**
```
Total rows: 896 (was 842, +54 pet spells)
spell_type distribution:
  1   (Nuke)   = 260  (was 311, -51 reclassified to slow/debuff)
  2            = 60
  4            = 44
  8            = 254
  32  (Pet)    = 54   (was 0, +54 new)
  64           = 21
  128          = 20
  256          = 84
  512          = 18
  1024         = 10
  2048         = 9
  4096         = 11
  8192 (Slow)  = 18   (was 0, +18 reclassified)
  16384 (Debuff) = 33 (was 0, +33 reclassified)
```

**Pet spells by class (spell_type=32):**
- class_id=5  (SHD): 9 rows
- class_id=11 (NEC): 18 rows
- class_id=13 (MAG): 15 rows
- class_id=15 (BST): 12 rows

**Slow spells by class (spell_type=8192):**
- class_id=8  (BRD): 4 rows
- class_id=10 (SHM): 8 rows
- class_id=14 (ENC): 3 rows
- class_id=15 (BST): 3 rows

**Debuff spells by class (spell_type=16384):**
- class_id=5  (SHD): 11 rows
- class_id=10 (SHM): 10 rows
- class_id=13 (MAG): 5 rows
- class_id=14 (ENC): 4 rows
- class_id=15 (BST): 3 rows

All counts match architecture doc exactly.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| None encountered | — | — |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `peq.companion_spell_sets` (database) | Modified | 54 rows inserted (pet spells), 51 rows updated (slow/debuff reclassification) |

---

## Open Items

- [ ] game-tester validation: recruit MAG/NEC/SHD/BST and verify pet summoning works in-game
- [ ] game-tester validation: recruit SHM/ENC/BST and verify slow/debuff spells fire in combat
- [ ] Future task (not in scope): add SpellType_Cure (32768) entries for CLR, DRU, SHM, PAL, RNG — see architecture doc "Finding 2"

---

## Context for Next Agent

All SQL-only data tasks are complete. No server restart is needed — `LoadCompanionSpells()` queries the database fresh on every companion recruitment and level-up.

**What was done:**
1. Added 54 pet summoning spell rows (spell_type=32) for MAG, NEC, SHD, BST companions. This enables the `AI_SummonPet()` handler to find spells when companions are idle.
2. Reclassified 18 slow spells (spell_type 1→8192) and 33 debuff spells (spell_type 1→16384). This enables `AI_SlowDebuff()` to find and cast appropriate spells for SHM, ENC, BST, BRD companions.

**What was NOT done (by design):**
- No C++ changes (AI code already supports all three spell types)
- No quest script changes
- No server restart required

**Next step:** game-tester validates companion behavior in-game per the validation plan in the architecture doc.
