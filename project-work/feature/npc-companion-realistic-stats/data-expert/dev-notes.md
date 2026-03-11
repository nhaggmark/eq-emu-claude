# npc-companion-realistic-stats — Dev Notes: Data Expert

> **Feature branch:** `feature/npc-companion-realistic-stats`
> **Agent:** data-expert
> **Task(s):** Issue #6 (Shaman Cannibalize) — Add Cannibalize I-IV to companion_spell_sets
> **Date started:** 2026-03-11
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Add Cannibalize I-IV to companion_spell_sets (shaman, class_id=10) | audit-fix-plan.md Issue #6 | **Complete** |
| 2 | Phase 5: Insert ResistCapBase rule value into database | phase5-plan.md Task 6 | **Complete** |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `claude/project-work/feature/npc-companion-realistic-stats/architect/context/audit-fix-plan.md` | Full | Issue #6 Shaman Cannibalize — Appendix: Data-Expert Tasks section. Architect guidance: insert Cannibalize I-IV into companion_spell_sets for class_id=10 at shaman level requirements. C++ FindCannibalizeSpell() identifies them by SE_CurrentMana effect (effectid=15, positive base value) and ST_Self targettype=6 — NOT by spell_type tag. |
| DB: spells_new | Query | Cannibalize spells: id=265 (lvl 23), id=754 (lvl 38), id=1572 (lvl 54), id=1332 (lvl 58). Effects: effectid1=0 (SE_CurrentHP, negative), effectid2=15 (SE_CurrentMana, positive). targettype=6 (ST_Self). |
| DB: companion_spell_sets | Query | Schema: id, class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct. MAX(id)=1246. No Cannibalize spells exist yet. |

### Key Findings

1. **Cannibalize spell IDs from DB:**
   - Cannibalize I: spell_id=265, shaman level 23, HP cost=-50 per tick, mana gain=16
   - Cannibalize II: spell_id=754, shaman level 38, HP cost=-67, mana gain=21
   - Cannibalize III: spell_id=1572, shaman level 54, HP cost=-74, mana gain=26
   - Cannibalize IV: spell_id=1332, shaman level 58, HP cost=-148, mana gain=52

2. **Spell effects confirm era lock:** All IDs 265, 754, 1572, 1332 are Classic-Luclin era. ID 7257 (another Cannibalize II) has classes10=255 (can't use) — skip it.

3. **Spell type recommendation:** Architect recommends SpellType_Heal (bit 1 = value 2) as the type tag. The actual C++ identification uses spell effects, not type tag. Using type=2 is appropriate.

4. **No duplicates:** Confirmed none of these spell_ids exist in companion_spell_sets yet.

5. **max_level** should be set to allow using the highest tier that's learned. Standard pattern in the table: `max_level` is the level below which the NEXT tier takes over. For Cannibalize, since each higher version supersedes the lower one:
   - Cannibalize I (23): use until level 37 (one before Canni II at 38)
   - Cannibalize II (38): use until level 53 (one before Canni III at 54)
   - Cannibalize III (54): use until level 57 (one before Canni IV at 58)
   - Cannibalize IV (58): use until level 65

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `claude/project-work/feature/npc-companion-realistic-stats/data-expert/context/cannibalize-spells.sql` | Create | Migration SQL inserting Cannibalize I-IV into companion_spell_sets |
| `peq` database (live) | Execute | Run the SQL against MariaDB |

**Change sequence:**
1. Verify no duplicate entries (done — none exist)
2. Write INSERT statements for Cannibalize I-IV into companion_spell_sets
3. Execute via docker exec
4. Verify the inserts with SELECT

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| companion_spell_sets schema | DB DESCRIBE query | Yes | id, class_id, min_level, max_level, spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct |
| Cannibalize spell IDs and effects | DB SELECT on spells_new | Yes | ids 265, 754, 1572, 1332; effectid2=15 (SE_CurrentMana) confirms C++ detection will work |
| SpellType_Heal value | companion_spell_sets existing data (spell_type=2) | Yes | spell_type=2 = SpellType_Heal (1<<1) |
| No existing Cannibalize entries | DB SELECT on companion_spell_sets WHERE spell_id IN (265,754,1332,1572) | Yes | Empty result set — safe to INSERT |

### Plan Amendments

Plan confirmed — no amendments needed. The architect's approximate level numbers (23, 35, 49, 55) differ slightly from actual DB values (23, 38, 54, 58), but the DB values are authoritative.

---

## Stage 3: Socialize

No external teammates needed. The C++ `FindCannibalizeSpell()` implementation (c-expert's task) identifies Cannibalize spells purely by spell effects (effectid=15 = SE_CurrentMana, positive value, self-only target). The spell_type tag is secondary but used for loading — SpellType_Heal (2) is the agreed value per architect guidance.

### Consensus Plan

**Agreed approach:** Insert 4 rows into companion_spell_sets for shaman (class_id=10), one per Cannibalize tier, using:
- spell_type=2 (SpellType_Heal)
- stance=0 (any stance — so it loads for both engaged and idle AI)
- priority=1 (standard)
- min_hp_pct=0, max_hp_pct=100 (no HP restriction — shaman AI governs when to cast via HP check in code)
- min_level/max_level tiers to avoid duplicate loading at high levels

---

## Stage 4: Build

### Implementation Log

#### 2026-03-11 — Add Cannibalize I-IV to companion_spell_sets

**What:** Inserted 4 rows into companion_spell_sets for shaman Cannibalize spells (Cannibalize I-IV)

**Where:** `peq` database, `companion_spell_sets` table

**Why:** The c-expert's `AI_Shaman()` Cannibalize enhancement (Issue #6 from audit-fix-plan.md) needs these spells loaded into `m_companion_spells` so `FindCannibalizeSpell()` can identify them by their SE_CurrentMana effect. Without these entries, the feature silently does nothing (safe degradation confirmed by architect).

**Notes:**
- Used spell_type=2 (SpellType_Heal) per architect guidance
- min_level/max_level tiered so only the highest applicable tier is active at each level
- effectid2=15 (SE_CurrentMana) with positive base value on all four spells confirms FindCannibalizeSpell() will identify them correctly
- spell_id=7257 (duplicate Cannibalize II with classes10=255) was intentionally excluded — can't be used by shaman

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| Docker Desktop not running | Docker Desktop was stopped | Launched via PowerShell, waited for startup |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `data-expert/context/cannibalize-spells.sql` | Created | Migration SQL with 4 INSERT statements for Cannibalize I-IV |
| `peq` DB `companion_spell_sets` | 4 rows inserted | Cannibalize I (spell 265), II (754), III (1572), IV (1332) for shaman |

---

## Phase 5: ResistCapBase Rule Insertion

### Stage 1: Plan

**Task:** Insert `Companions:ResistCapBase` into `rule_values` table.

**Source:** phase5-plan.md Task 6. The c-expert's `GetMaxResist()` implementation reads `RuleI(Companions, ResistCapBase)` — this DB row is what backs that rule at runtime.

**Key decisions:**
- `ruleset_id=1` — matches all other Companions:* rules in the database
- `rule_value='50'` — default from ruletypes.h RULE_INT definition; yields cap of 350 at level 60
- Notes text mirrors the ruletypes.h description exactly for consistency

### Stage 2: Research

- Confirmed `ruleset_id=1` by querying 5 existing Companions:* rules — all use ruleset_id=1
- Confirmed table schema: `rule_values (ruleset_id TINYINT UNSIGNED, rule_name VARCHAR(64), rule_value TEXT, notes TEXT)`
- Used `WHERE NOT EXISTS` guard in INSERT to make migration idempotent (safe to re-run)

### Stage 3: Socialize

No coordination needed — this is a pure data task. The c-expert independently adds the same rule to `ruletypes.h`. The DB row and the C++ constant are parallel; the C++ rule manager loads the DB value at server startup and uses it at runtime.

### Stage 4: Build

**2026-03-11 — Insert Companions:ResistCapBase**

- SQL written to: `data-expert/context/phase5-rules.sql`
- Executed via: `docker exec akk-stack-mariadb-1 mysql ... peq`
- Verification query result:

```
ruleset_id  rule_name                   rule_value  notes
1           Companions:ResistCapBase    50          Phase 5: Base value for companion resist cap formula. ...
```

Row confirmed present with correct ruleset_id=1, rule_value=50.

---

## Open Items

- [x] Verify c-expert has implemented FindCannibalizeSpell() in companion_ai.cpp (Issue #6)
- [x] Test 14.20 (SQL verification): Cannibalize I-IV present in companion_spell_sets for shaman at appropriate levels
- [x] Phase 5: Companions:ResistCapBase=50 inserted into rule_values

---

## Context for Next Agent

The Cannibalize spells are now in `companion_spell_sets` for shaman (class_id=10):
- Cannibalize I (spell_id=265): min_level=23, max_level=37, spell_type=2
- Cannibalize II (spell_id=754): min_level=38, max_level=53, spell_type=2
- Cannibalize III (spell_id=1572): min_level=54, max_level=57, spell_type=2
- Cannibalize IV (spell_id=1332): min_level=58, max_level=65, spell_type=2

The C++ `FindCannibalizeSpell()` helper will find these via effectid2=15 (SE_CurrentMana) positive base value and targettype=6 (ST_Self). The spell_type=2 tag just ensures they load into m_companion_spells.

Migration script saved at: `data-expert/context/cannibalize-spells.sql`

### Phase 5 additions:

- `Companions:ResistCapBase` rule (`rule_value='50'`, `ruleset_id=1`) inserted into `rule_values`. Migration script: `data-expert/context/phase5-rules.sql`.
- This backs the `RuleI(Companions, ResistCapBase)` call in `Companion::GetMaxResist()` at runtime.
- cap formula: `level * 5 + ResistCapBase` → 350 at level 60 (70% of client cap 500, per PRD 70-85% target).
