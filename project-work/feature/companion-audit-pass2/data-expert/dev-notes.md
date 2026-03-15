# Companion Audit Pass 2 — Dev Notes: Data Expert

> **Feature branch:** `feature/companion-audit-pass2`
> **Agent:** data-expert
> **Task:** #3 — Database audit pass 2: verify spell priorities, data integrity, test coverage
> **Date started:** 2026-03-15
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Database audit pass 2: verify spell priorities, data integrity, test coverage | — | Complete |

---

## Focus 1: Spell Priority Fix Verification

Both validation scripts were run against the live `peq` database on 2026-03-15.

### GAP-05 (Healer lists: shaman, druid, ranger) — All PASS

```
PASS: Shaman heals all priority >= 15
PASS: Shaman heal priority > Shaman damage priority
PASS: Shaman slows/debuffs all have mid-priority (5 < priority < 20)
PASS: Druid heals all priority >= 10
PASS: Druid heal priority > Druid damage priority
PASS: Ranger heals all priority >= 5
PASS: Cleric baseline heals unchanged (CH=20, Celestial=10)
PASS: No healer list (6, 7, 10) has heals at priority=1
PASS: List 6 hierarchy: heal(20) > damage(10) > utility(3)
PASS: List 7 hierarchy: heal(15) > damage(7) > utility(3)
PASS: List 10 hierarchy: heal(8) > damage(6) > utility(3)
```

### GAP-07 (Caster lists: mage, enchanter, paladin, SK) — All PASS

```
PASS  M1: Magician has >= 8 distinct priorities (actual: 10)
PASS  M2: Magician top-tier nukes priority >= 14 (actual: 18)
PASS  M3: Magician high-tier nukes have higher priority than low-tier
PASS  M4: Magician Malo debuffs priority >= 8 (actual: 10)
PASS  M5: Magician buffs (type=8) all remain at priority=1
PASS  E1: Enchanter mez (type=2048) is highest-priority type (18 > 12 > 10)
PASS  E2: All Enchanter mez spells at priority >= 18 (9 spells)
PASS  E3: Enchanter charm priority > Tash debuff priority
PASS  E4: Enchanter Gravity Flux and Command of Druzzil at priority=15
PASS  P1: Paladin heals are highest priority (20 > 10 > 1)
PASS  P2: All Paladin heals at priority >= 15 (actual min: 20)
PASS  P3: Paladin stuns have higher priority than DD nuke
PASS  P4: Paladin buffs (type=8) all remain at priority=1
PASS  S1: SK lifetaps are highest priority (20 > 12 > 8)
PASS  S2: All SK lifetaps at priority >= 18 (actual: 20, 10 spells)
PASS  S3: SK hierarchy: lifetap > snare > DoT > STR debuff (20 > 12 > 8 > 6)
PASS  S4: SK buffs (type=8) all remain at priority=1
PASS  R1: Wizard (ID 2) unchanged — still has >= 20 distinct priorities (actual: 24)
PASS  R2: Necromancer (ID 3) unchanged — still has >= 20 distinct priorities (actual: 22)
```

**Conclusion: All 30 tests pass. `npc_spells_entries` priorities are fully correct.**

---

## Focus 2: Data Integrity Deep Dive

### 2a. companion_data — Current State (2026-03-15)

6 companions exist (previously 7 — companion id=15 Olunea Miltin and id=20 Moldrak Drin have been removed; new companion id=24 Lashun Novashine added):

| id | name | level | class_id | race_id | is_suspended | is_dismissed | cur_hp | cur_mana | state |
|----|------|-------|---------|---------|-------------|-------------|--------|---------|-------|
| 10 | Lydl the Great | 32 | 12 (WIZ) | 1 (HUM) | 0 | 0 | 490 | 2146 | active |
| 18 | Hollish Tnoops | 32 | 1 (WAR) | 6 (DEF) | 0 | 0 | 611 | 0 | active |
| 21 | Hollish Tnoops | 14 | 1 (WAR) | 6 (DEF) | 1 | 0 | 168 | 0 | suspended |
| 22 | Jimble Woodentoe | 32 | 4 (RNG) | 11 (HFL) | 0 | 0 | 532 | 1508 | active |
| 23 | Jracol Brestiage | 32 | 9 (ROG) | 6 (DEF) | 0 | 0 | 395 | 0 | active |
| 24 | Lashun Novashine | 32 | 2 (CLR) | 1 (HUM) | 0 | 0 | 1365 | 9267 | active |

**State anomalies: NONE.** No companion has `is_suspended=0 AND is_dismissed=0 AND cur_hp=0`.

**Notable observation:** Companion 22 (Jimble, ranger) has `cur_mana=1508` despite rangers having no dedicated mana pool at level 32. This may be legitimate (rangers have a small mana pool for heals) or a stale value — not a structural anomaly.

**Companion 24 (Lashun Novashine, CLR, level 32):** New since the previous audit. NPC type 2032 (level 5 base, scalerate=100), npc_spells_id=1 (Default Cleric List). No inventory items recorded in companion_inventories. This is expected if the player has not equipped the cleric.

### 2b. data_buckets Cooldowns

No `companion_cooldown%` entries exist in `data_buckets`. No stale cooldowns.

### 2c. Orphaned companion_inventories

No orphaned records found. All companion_inventories rows have a matching companion_data record. Companions with inventory:
- id=10 Lydl (14 slots)
- id=18 Hollish Tnoops (15 slots)
- id=22 Jimble Woodentoe (13 slots)

Companions with no inventory: id=21, id=23, id=24.

### 2d. NPC Types — Spell List Validity

| Companion | class_id | npc_type_id | npc_spells_id | Spell List | Correct for class? |
|-----------|---------|-------------|--------------|------------|-------------------|
| Hollish Tnoops | 1 (WAR) | 9144 | 0 | None | CORRECT |
| Lashun Novashine | 2 (CLR) | 2032 | 1 | Default Cleric List | CORRECT |
| Jimble Woodentoe | 4 (RNG) | 22014 | 10 | Default Ranger List | CORRECT |
| Jracol Brestiage | 9 (ROG) | 2029 | 0 | None | CORRECT |
| Lydl the Great | 12 (WIZ) | 10162 | 2 | Default Wizard List | CORRECT |

All npc_spells_id assignments are correct for each companion's class.

### 2e. Item Race Restriction — Previous Audit Correction

The previous audit flagged `Longbow (item 8003, races=285)` as excluding halflings.

**Correction:** The item query shows `races=65535` for item 8003 Longbow — this is all races. The earlier audit value of `285` was from cached data or a different item. **No race restriction violation exists for Jimble's longbow.** This finding is retracted.

---

## Focus 3: Critical New Findings

### FINDING A: `companion_spell_sets` — GAP-05/GAP-07 Fixes NOT Applied

**This is the most critical finding of this audit.**

There are two parallel spell systems for companions:
1. `npc_spells_entries` (keyed by `npc_spells_id` on `npc_types`) — this was fixed by GAP-05 and GAP-07
2. `companion_spell_sets` (keyed by `class_id` directly) — this was NOT fixed

The `companion_spell_sets` table has 15 class entries. Checking heal priorities:

| class_id | System | Heals | Max Heal Priority | Status |
|---------|--------|-------|------------------|--------|
| 2 (CLR) | companion_spell_sets | 11 | 20 | OK — already correct |
| 6 (SHM) | companion_spell_sets | 11 | **1** | **BROKEN** |
| 8 (PAL) | companion_spell_sets | 6 | **1** | **BROKEN** |
| 10 (RNG) | companion_spell_sets | 13 | **1** | **BROKEN** |

Classes 3 (NEC), 4 (MAG), 5 (ENC), 13 (BST), 14 (BRD), 15 (BER) also show `max_prio=1` for all spells in this table.

**The GAP-05 and GAP-07 fixes applied to `npc_spells_entries` were NOT propagated to `companion_spell_sets`.**

Which system takes precedence at runtime is a C++ question (for c-expert to determine). If `companion_spell_sets` takes precedence, the priority fixes are entirely ineffective. If `npc_spells_entries` takes precedence, the fixes work but `companion_spell_sets` is orphaned data. Either way, this gap must be documented and the c-expert must clarify the precedence chain.

### FINDING B: Cleric Spell List — Only Low-Tier Heals Are Elevated

In `npc_spells_entries` list ID=1 (Default Cleric List), only `Light Healing` (priority 10) and `Healing` (priority 20) are elevated. The entire upper heal progression is at priority=1:

| Spell | Min Level | Priority |
|-------|----------|---------|
| Minor Healing | 1 | 1 |
| Light Healing | 5 | 10 |
| Healing | 14 | **20** |
| Greater Healing | 24 | **1** — PROBLEM |
| Superior Healing | 34 | **1** — PROBLEM |
| Complete Heal | 39 | **1** — PROBLEM |
| Remedy | 51 | 1 |
| Divine Light | 53 | 1 |

At companion level 32, the cleric Lashun Novashine should primarily be casting `Greater Healing` and `Complete Heal`. Both are at priority=1, competing equally with `Wrath` (priority=30), `Smite` (priority=20), and other offensive spells. The cleric companion at level 32+ will cast damage nukes before healing — this is a correctness bug.

Note: GAP-05 fixed shaman/druid/ranger lists but the cleric list (id=1) was not part of GAP-05 scope. The cleric list has `Wrath` at priority=30 (highest), which means a cleric companion may attack rather than heal even with a dying player present.

### FINDING C: Inverted `minlevel`/`maxlevel` in 4 Spell Lists

Four entries in `npc_spells_entries` have `minlevel > maxlevel` (which logically means the spell is inaccessible at any level):

| List ID | Spell ID | Spell Name | Type | Priority | minlevel | maxlevel |
|---------|---------|-----------|------|---------|---------|---------|
| 2 (WIZ) | 3326 | Resistant Armor | 8 (buff) | 1 | 61 | 57 |
| 6 (SHM) | 1585 | Talisman of Kragg | 8 (buff) | 2 | 55 | 9 |
| 7 (DRU) | 99 | Creeping Crud | 256 (DoT) | 7 | 24 | 23 |
| 8 (PAL) | 3429 | Touch of Nife | 2 (heal) | 20 | 61 | 52 |

**Paladin is the most significant:** `Touch of Nife` (a high-priority heal at 20) has minlevel=61 and maxlevel=52. A paladin companion at any level 52-61 range would have `minlevel > maxlevel=52` so the spell is never castable. This is a heal the paladin companion should be using.

`Talisman of Kragg` in the shaman list has maxlevel=9, minlevel=55 — effectively never castable (all conditions fail). This is a 55-60 range buff that was probably misconfigured.

### FINDING D: Era-Locked Spells (minlevel > 60) in All Lists

All 10 spell lists contain spells with `minlevel > 60`. These are Planes of Power (PoP) and later-era spells. The server era lock is Classic through Luclin (level cap 60). Companions reaching level 60 would never enter the minlevel window for these post-60 spells, but they do occupy list slots and add noise. Higher-priority spells above level 60 (e.g., Wizard list has level 65 spells at priority=24) may block mid-tier spells in the rotation logic depending on how the AI handles out-of-range entries.

Count of entries with minlevel > 60 by list:

| List | Total spells | minlevel > 60 | pct |
|------|-------------|--------------|-----|
| 1 (CLR) | 87 | 23 | 26% |
| 2 (WIZ) | 81 | 17 | 21% |
| 3 (NEC) | 68 | 11 | 16% |
| 4 (MAG) | 54 | 10 | 19% |
| 5 (ENC) | 121 | 17 | 14% |
| 6 (SHM) | 93 | 20 | 22% |
| 7 (DRU) | 91 | 12 | 13% |
| 8 (PAL) | 41 | 10 | 24% |
| 9 (SK) | 48 | 8 | 17% |
| 10 (RNG) | 52 | 10 | 19% |

---

## Focus 3: Test Coverage Assessment

### What the Existing Scripts Validate Well

**GAP-05 script (`test_spell_priorities.sql`):**
- Shaman heals elevated (type=2, priority >= 15) ✓
- Shaman damage/utility in correct hierarchy ✓
- Named slow/debuff spells have mid-priority ✓
- Druid heals elevated (priority >= 10) ✓
- Druid hierarchy: heal > damage ✓
- Ranger heals elevated (priority >= 5) ✓
- Cleric baseline unchanged ✓
- No healer list has heals at priority=1 ✓
- Per-list hierarchy: heal > damage > utility ✓

**GAP-07 script (`gap07_validation.sql`):**
- Magician distinct priorities, tier ordering, buffs unchanged ✓
- Enchanter mez/charm/debuff hierarchy ✓
- Paladin heal/stun/buff hierarchy ✓
- SK lifetap/snare/dot/debuff hierarchy ✓
- Wizard and necromancer regression tests ✓

### Gaps in Existing Coverage

**1. companion_spell_sets NOT validated**

Neither script queries `companion_spell_sets`. If this is the active spell system at runtime (vs `npc_spells_entries`), all 30 tests above are testing the wrong table. A critical validation gap.

**Recommended test to add:**
```sql
-- Verify companion_spell_sets healer heal priorities match npc_spells_entries
SELECT class_id, MAX(CASE WHEN spell_type = 2 THEN priority ELSE 0 END) AS max_heal_prio
FROM companion_spell_sets
WHERE class_id IN (2, 6, 8, 10)
GROUP BY class_id;
-- Expected: 2->20, 6->20, 8->20, 10->8 (or better)
```

**2. Cleric list mid-high heal tier not validated**

The cleric baseline test only checks `Complete Heal (spellid=12)` at priority=20 and `Celestial Healing (spellid=17)` at priority=10. It does NOT check `Greater Healing` (priority=1), `Superior Healing` (priority=1), or `Remedy`/`Divine Light` (priority=1). A level 30-60 cleric companion primarily uses these higher-tier heals, which are at priority=1 — below `Wrath` at priority=30.

**Recommended test to add:**
```sql
-- All cleric mid-tier heals should be elevated
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS: Cleric mid-tier heals all elevated'
  ELSE CONCAT('FAIL: ', COUNT(*), ' cleric heals at priority=1 above minlevel 20')
  END
FROM npc_spells_entries
WHERE npc_spells_id = 1
  AND type = 2
  AND minlevel >= 20
  AND priority < 10;
```

**3. Inverted minlevel/maxlevel not validated**

No test checks for `minlevel > maxlevel` across any list. The 4 inversions found here would all silently fail.

**Recommended test to add:**
```sql
-- No spell entry should have minlevel > maxlevel (when maxlevel > 0)
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS: No inverted level ranges in companion spell lists'
  ELSE CONCAT('FAIL: ', COUNT(*), ' entries with minlevel > maxlevel: ',
    GROUP_CONCAT(CONCAT('list=', npc_spells_id, ' spell=', spellid) ORDER BY npc_spells_id))
  END
FROM npc_spells_entries
WHERE npc_spells_id IN (1,2,3,4,5,6,7,8,9,10)
  AND maxlevel > 0
  AND minlevel > maxlevel;
```

**4. companion_data state integrity not validated**

No automated test checks for the anomalous state `is_suspended=0 AND is_dismissed=0 AND cur_hp=0`, or for negative/impossible values in `level`, `cur_hp`, `cur_mana`.

**Recommended test to add:**
```sql
-- No companion should be active but have 0 HP (would be stuck dead)
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS: No companion active with 0 HP'
  ELSE CONCAT('FAIL: ', COUNT(*), ' companions active with 0 HP')
  END
FROM companion_data
WHERE is_suspended = 0 AND is_dismissed = 0 AND cur_hp = 0;

-- No companion should have both suspended AND dismissed
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS: No companion has both flags set'
  ELSE CONCAT('FAIL: ', COUNT(*), ' companions have is_suspended=1 AND is_dismissed=1')
  END
FROM companion_data
WHERE is_suspended = 1 AND is_dismissed = 1;
```

**5. Orphaned companion_inventories not validated**

No test checks for inventory records whose companion was deleted. This runs clean today but should be automated.

**Recommended test to add:**
```sql
-- No orphaned companion_inventories
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS: No orphaned companion_inventories'
  ELSE CONCAT('FAIL: ', COUNT(*), ' orphaned inventory rows (companion_data deleted)')
  END
FROM companion_inventories ci
LEFT JOIN companion_data cd ON ci.companion_id = cd.id
WHERE cd.id IS NULL;
```

**6. Duplicate spell IDs in same list not validated**

No test checks for `spellid` appearing more than once per `npc_spells_id`. None found today, but this should be automated.

**Recommended test to add:**
```sql
-- No duplicate spellids in the same list
SELECT CASE
  WHEN COUNT(*) = 0 THEN 'PASS: No duplicate spells in any companion list'
  ELSE CONCAT('FAIL: ', COUNT(*), ' duplicate spell entries found')
  END
FROM (
  SELECT npc_spells_id, spellid, COUNT(*) AS cnt
  FROM npc_spells_entries
  WHERE npc_spells_id IN (1,2,3,4,5,6,7,8,9,10)
  GROUP BY npc_spells_id, spellid
  HAVING cnt > 1
) dups;
```

**7. companion_spell_sets vs npc_spells_entries cross-system parity not validated**

There is no test verifying that priorities in `companion_spell_sets` match priorities in `npc_spells_entries` for the same class. Since both tables may influence companion behavior, divergence between them is a bug surface.

---

## Summary of Findings

| # | Finding | Severity | Area |
|---|---------|---------|------|
| A | `companion_spell_sets` GAP-05/07 fixes NOT applied — healer/caster classes all at priority=1 | CRITICAL | Database |
| B | Cleric list: `Greater Healing`, `Superior Healing`, `Complete Heal` all at priority=1 (below `Wrath` at 30) | HIGH | Database |
| C | 4 inverted minlevel/maxlevel entries — `Touch of Nife` (PAL heal, priority=20) is inaccessible | MEDIUM | Database |
| D | All 10 spell lists contain 13-26% post-era (minlevel > 60) spell entries | LOW | Database |

| # | Coverage Gap | Recommended Fix |
|---|-------------|----------------|
| 1 | companion_spell_sets not tested at all | Add companion_spell_sets validation suite |
| 2 | Cleric mid-high tier heals not tested | Add cleric mid-tier heal elevation test |
| 3 | Inverted level ranges not tested | Add minlevel > maxlevel test |
| 4 | companion_data state integrity not tested | Add active+0hp, dual-flag anomaly tests |
| 5 | Orphaned companion_inventories not tested | Add orphan check |
| 6 | Duplicate spell IDs not tested | Add dedup check |
| 7 | companion_spell_sets vs npc_spells_entries parity not tested | Add cross-system parity test |

---

## Open Items

- [ ] **C-expert must determine:** Does the companion AI use `companion_spell_sets` or `npc_spells_entries` as the authoritative spell source? If `companion_spell_sets`, all GAP-05/07 fixes need to be applied there too.
- [ ] **Data work needed:** Fix cleric list — `Greater Healing`, `Superior Healing`, `Complete Heal` should be elevated to priority >= 15 (higher priority than `Wrath` at 30).
- [ ] **Data work needed:** Fix 4 inverted minlevel/maxlevel entries, especially `Touch of Nife` in paladin list.
- [ ] **Data work needed:** If `companion_spell_sets` is the active system, apply GAP-05/07 equivalents to that table for SHM, DRU, RNG, PAL, SK, MAG, ENC classes.

---

## Context for Next Agent

All 30 GAP-05 and GAP-07 validation tests pass in `npc_spells_entries`. However, this audit discovered a parallel spell system (`companion_spell_sets`) that was NOT updated by those fixes. The architect must determine which system the companion AI actually uses at runtime. Additionally, the cleric spell list was not in scope for either GAP — it has a serious heal priority inversion where damage nukes outprioritize all mid-high tier heals.

Key facts:
- `npc_spells_entries` spell lists 1-10: all fixed, all tests pass
- `companion_spell_sets` classes 6,8,10 (SHM,PAL,RNG): max heal priority = 1 (NOT fixed)
- Cleric list (npc_spells_id=1): `Healing` at priority=20 but `Greater Healing`, `Superior Healing`, `Complete Heal` all at priority=1
- 4 entries have inverted minlevel/maxlevel, most impactful being paladin `Touch of Nife` (heal, priority=20, minlevel=61 > maxlevel=52 — inaccessible)
