# Companion Authenticity Fixes — Dev Notes: data-expert

> **Feature branch:** `feature/companion-authenticity-fixes`
> **Agent:** data-expert
> **Task(s):** #5 — GAP-05: Fix shaman and healer spell list priorities
> **Date started:** 2026-03-14
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 5 | GAP-05: Fix shaman and healer spell list priorities | — | Complete |

---

## Stage 1: Plan

### Files Examined

| File | What You Found |
|------|----------------|
| npc_spells (DB) | IDs: Default Shaman=6, Default Cleric=1, Default Druid=7, Default Ranger=10 |
| npc_spells_entries (DB) | All spells in each list; column name is `spellid` (not `spells_id`) |
| spells_new (DB) | effectid1 used to classify spell category (0=DD, 10=slow, 35=disease, etc.) |

### Key Findings

- Default Cleric List (ID 1) is the correct reference model: heals at priority 20 and 10, damage at 30/20/10, buffs at priority 1.
- Default Shaman List (ID 6): ALL 93 spells at priority=1. Heals compete equally with nukes and SoW.
- Default Druid List (ID 7): ALL 91 spells at priority=1. Same problem.
- Default Ranger List (ID 10): ALL 52 spells at priority=1. Same problem.

**Shaman spell type breakdown:**
- type=2 (heals): 9 spells — Superior Healing through Regeneration
- type=1 (mixed): 41 spells — further classified by effectid1:
  - effectid1=10: 16 spells — slows/ATK debuffs (Malo group, Tagar's Insects, etc.)
  - effectid1=5: 1 spell — Cripple (ATK debuff)
  - effectid1=46: 1 spell — Malosini (resist debuff, grouped with slows)
  - effectid1=35: 5 spells — disease debuffs (Insidious series, Plague of Insects)
  - effectid1=367: 1 spell — Feralize (special buff/debuff)
  - effectid1=0: 17 spells — DD nukes
- type=256 (DoTs): 12 spells
- type=4 (roots): 6 spells
- type=8 (buffs): 23 spells — Spirit of Wolf, Talisman series, etc.
- type=512 (dispel): 2 spells

### Implementation Plan

Modify existing `priority` values in `npc_spells_entries` using UPDATE statements.
Do NOT add or remove spell entries. Follow the cleric list as the model.

**Priority hierarchy decided:**
- 20 = Shaman heals (primary healer)
- 15 = Druid heals (secondary healer)
- 10 = Shaman slows + ATK debuffs (critical combat utility)
- 8  = Shaman disease debuffs + Ranger heals (emergency heals)
- 7  = Shaman/Druid DoTs
- 6  = Ranger DoTs
- 5  = All DD nukes (type=1)
- 3  = Roots (type=4)
- 2  = Snares (type=128) + Druid buffs
- 1  = Buffs (type=8), Dispel (type=512)

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| MariaDB UPDATE ... WHERE IN | Context7 /mariadb-corporation/mariadb-docs | Yes | Standard syntax confirmed |
| MariaDB CASE WHEN in UPDATE | Context7 | Yes | Not needed — separate UPDATE statements per group cleaner |
| autocommit behavior | Live DB query | Yes | autocommit=ON, START TRANSACTION/COMMIT safe to use |

### Plan Amendments

Plan confirmed — no amendments needed. Using explicit spellid IN lists for shaman type=1 subgroups (slows vs. nukes vs. disease debuffs) since `effectid1` column in spells_new provides reliable classification.

---

## Stage 3: Socialize

No blocking dependencies. This task is pure database data — no C++ or Lua changes required. The npc_spells_entries priority values are read at runtime by the NPC AI spell casting logic. No build required; changes take effect on next zone load.

No teammates needed to confirm before proceeding — this is a self-contained data fix.

---

## Stage 4: Build

### Implementation Log

#### 2026-03-14 — Created and applied spell priority migration

**What:** Updated `priority` column in `npc_spells_entries` for npc_spells_id IN (6, 7, 10).

**Where:** `/mnt/d/Dev/eq/akk-stack/server/quests/sql/gap05_fix_healer_spell_priorities.sql`

**Why:** All three lists had every spell at priority=1, causing NPC AI to randomly cast
any spell regardless of urgency. Shaman companions were unreliable healers because heals
competed equally with Spirit of Wolf and DD nukes. The fix differentiates priorities so
heals fire first when group HP is low.

**Notes:**
- The `npc_spells_entries` column is `spellid` (not `spells_id` — the task description had a typo in the verification query).
- File must be applied via `docker exec -i` (not `-it`) to allow stdin pipe from host.
- Feralize (spellid=9999) is a special NPC-only debuff. Assigned priority=8 with disease debuffs — important utility but not as critical as slows.
- Malosini (spellid=1577) has effectid1=46 but functionally is a resist debuff in the Malo family; treated as priority=10 with other Malo-group debuffs.

### SQL Applied

```sql
-- SHAMAN (ID 6)
UPDATE npc_spells_entries SET priority = 20 WHERE npc_spells_id = 6 AND type = 2;
UPDATE npc_spells_entries SET priority = 10 WHERE npc_spells_id = 6 AND type = 1
  AND spellid IN (505,270,3380,506,507,1589,1588,281,163,162,110,111,1578,3395,112,3387,1577,1592);
UPDATE npc_spells_entries SET priority = 8 WHERE npc_spells_id = 6 AND type = 1
  AND spellid IN (1573,526,527,3386,2527,9999);
UPDATE npc_spells_entries SET priority = 7 WHERE npc_spells_id = 6 AND type = 256;
UPDATE npc_spells_entries SET priority = 5 WHERE npc_spells_id = 6 AND type = 1
  AND spellid IN (275,508,1586,510,509,282,93,3390,1427,3573,1429,3574,438,437,1587,3379,3385);
UPDATE npc_spells_entries SET priority = 3 WHERE npc_spells_id = 6 AND type = 4;
UPDATE npc_spells_entries SET priority = 2 WHERE npc_spells_id = 6 AND type = 8;
UPDATE npc_spells_entries SET priority = 1 WHERE npc_spells_id = 6 AND type = 512;

-- DRUID (ID 7)
UPDATE npc_spells_entries SET priority = 15 WHERE npc_spells_id = 7 AND type = 2;
UPDATE npc_spells_entries SET priority = 7 WHERE npc_spells_id = 7 AND type = 256;
UPDATE npc_spells_entries SET priority = 5 WHERE npc_spells_id = 7 AND type = 1;
UPDATE npc_spells_entries SET priority = 3 WHERE npc_spells_id = 7 AND type = 4;
UPDATE npc_spells_entries SET priority = 2 WHERE npc_spells_id = 7 AND type = 128;
UPDATE npc_spells_entries SET priority = 1 WHERE npc_spells_id = 7 AND type = 8;
UPDATE npc_spells_entries SET priority = 1 WHERE npc_spells_id = 7 AND type = 512;

-- RANGER (ID 10)
UPDATE npc_spells_entries SET priority = 8 WHERE npc_spells_id = 10 AND type = 2;
UPDATE npc_spells_entries SET priority = 6 WHERE npc_spells_id = 10 AND type = 256;
UPDATE npc_spells_entries SET priority = 5 WHERE npc_spells_id = 10 AND type = 1;
UPDATE npc_spells_entries SET priority = 3 WHERE npc_spells_id = 10 AND type = 4;
UPDATE npc_spells_entries SET priority = 2 WHERE npc_spells_id = 10 AND type = 128;
UPDATE npc_spells_entries SET priority = 1 WHERE npc_spells_id = 10 AND type = 8;
UPDATE npc_spells_entries SET priority = 1 WHERE npc_spells_id = 10 AND type = 512;
```

### Verification Results

After applying migration:

**Shaman (ID 6) — priority distribution:**
| Priority | Type | Count | Category |
|----------|------|-------|----------|
| 20 | 2 | 9 | Heals |
| 10 | 1 | 18 | Slows + ATK debuffs |
| 8 | 1 | 6 | Disease debuffs + Feralize |
| 7 | 256 | 12 | DoTs |
| 5 | 1 | 17 | DD Nukes |
| 3 | 4 | 6 | Roots |
| 2 | 8 | 23 | Buffs |
| 1 | 512 | 2 | Dispel |

**Druid (ID 7) — priority distribution:**
| Priority | Type | Count | Category |
|----------|------|-------|----------|
| 15 | 2 | 11 | Heals |
| 7 | 256 | 10 | DoTs |
| 5 | 1 | 33 | DD Nukes |
| 3 | 4 | 6 | Roots |
| 2 | 128 | 5 | Snares |
| 1 | 8 | 24 | Buffs |
| 1 | 512 | 2 | Dispel |

**Ranger (ID 10) — priority distribution:**
| Priority | Type | Count | Category |
|----------|------|-------|----------|
| 8 | 2 | 6 | Heals |
| 6 | 256 | 6 | DoTs |
| 5 | 1 | 11 | DD Nukes |
| 3 | 4 | 4 | Roots |
| 2 | 128 | 2 | Snares |
| 1 | 8 | 21 | Buffs |
| 1 | 512 | 2 | Dispel |

Verification confirmed: heals appear at top of shaman list (priority 20).

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/sql/gap05_fix_healer_spell_priorities.sql` | Created | Migration script; also idempotent (safe to re-apply) |

---

## Open Items

None.

---

## Context for Next Agent

Task is fully complete. The migration was applied to the live `peq` database
and committed. The SQL file at `akk-stack/server/quests/sql/gap05_fix_healer_spell_priorities.sql`
is the canonical migration script.

**Key fact for game-tester:** No server rebuild or restart required. Changes
take effect on the next zone load (when the NPC spell list is re-read). To
test: zone into an area with a shaman companion, get a group member low on HP,
and confirm the shaman prioritizes heals over nukes and SoW.

**The cleric list (ID 1) remains unchanged** — it was already correctly
configured and served as the reference model for this work.
