# Companion Recruitment & Re-recruitment Overhaul — Dev Notes: Data Expert

> **Feature branch:** `feature/companion-recruitment-overhaul`
> **Agent:** data-expert
> **Task(s):** BUG-028 data recovery — restore lost companion_data for Lashun Novashine
> **Date started:** 2026-03-14
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| BUG-028 | Data recovery: restore companion_data for Lashun Novashine (npc_type_id=2032), delete stale cooldown | architect investigation | Complete 2026-03-14 |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `companion-recruitment-overhaul/bugs/BUG-028-re-recruitment-still-blocked/investigation.md` | 212 | Full root cause analysis from architect. Record id=17 lost during death event (entity id=0). Stale cooldown key confirmed. Last known level=29 from zone logs. |

### Key Findings

- `companion_data` record id=17 (npc_type_id=2032, Lashun Novashine) was deleted/lost during death event on 2026-03-13 at 22:32 in guktop when entity id became 0 before `Companion::Death()` could call `Save()`
- A stale cooldown `companion_cooldown_2032_6` in `data_buckets` was blocking re-recruitment (set by a failed first-time recruitment roll after the record was missing)
- `owner_id` = 6 (character "Chelon") confirmed from existing companion_data records
- `npc_types` for id=2032: race=1 (Human), class=2 (Cleric), gender=0
- Last known level from zone logs: 29 (leveled at 22:22:44 on 2026-03-13)

### Implementation Plan

1. Verify current state: confirm no existing companion_data for npc_type_id=2032, confirm cooldown record exists
2. Delete stale cooldown from data_buckets WHERE key LIKE '%companion_cooldown_2032%'
3. Insert recovery companion_data record with is_suspended=1, is_dismissed=1, level=29, class_id=2, race_id=1
4. Verify both changes

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| companion_data schema | DESCRIBE companion_data (live DB) | Yes | 29 columns confirmed, all nullable/default checked |
| data_buckets column name | DESCRIBE data_buckets (live DB) | Yes | Column is `key` (reserved word), not `key_` as investigation noted |
| Existing companion_data rows | SELECT * FROM companion_data LIMIT 5 | Yes | Confirmed owner_id=6 is the pattern; verified column order and data types |
| npc_types record | SELECT id, name, race, class, gender, level FROM npc_types WHERE id=2032 | Yes | race=1, class=2, gender=0 |
| character_data | SELECT id, name WHERE id=6 | Yes | id=6 = "Chelon" |

### Plan Amendments

Investigation notes referenced `key_` but the actual column name is `key`. Amended the DELETE query to use backtick-quoted `\`key\`` and LIKE pattern `%companion_cooldown_2032%` (matching `companion_cooldown_2032_6`).

### Verified Plan

See Stage 1 Implementation Plan — amended with correct column name for data_buckets.

---

## Stage 3: Socialize

This was an immediate emergency data recovery dispatched directly by the orchestrator. No pre-build socialization round was required — the architect's investigation.md already contained the full consensus plan with specific INSERT values.

---

## Stage 4: Build

### Implementation Log

#### 2026-03-14 — BUG-028 data recovery: Lashun Novashine

**What:** Deleted stale recruitment cooldown and restored companion_data record for Lashun Novashine

**Step 1 — Pre-verification:**
```sql
-- Confirmed no existing record
SELECT * FROM companion_data WHERE npc_type_id = 2032;
-- Empty result set (as expected)

-- Confirmed stale cooldown exists
SELECT * FROM data_buckets WHERE `key` LIKE '%companion_cooldown%2032%';
-- id=30, key=companion_cooldown_2032_6, expires=1773540118
```

**Step 2 — Delete stale cooldown:**
```sql
DELETE FROM data_buckets WHERE `key` LIKE '%companion_cooldown_2032%';
-- 1 row deleted (id=30, companion_cooldown_2032_6)
```

**Step 3 — Insert recovery record:**
```sql
INSERT INTO companion_data (
    owner_id, npc_type_id, name, companion_type, level, class_id, race_id,
    gender, zone_id, x, y, z, heading, cur_hp, cur_mana, cur_endurance,
    is_suspended, stance, spawn2_id, spawngroupid, recruited_at, experience,
    recruited_level, is_dismissed, total_kills, zones_visited, time_active, times_died
) VALUES (
    6, 2032, 'Lashun Novashine', 0, 29, 2, 1,
    0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 0, 0, '2026-03-08 00:00:00', 0,
    1, 1, 0, NULL, 0, 1
);
-- new id = 24
```

Value rationale:
- `owner_id=6` — character "Chelon", confirmed from other companion_data rows
- `npc_type_id=2032` — Lashun Novashine's NPC ID
- `name='Lashun Novashine'` — display name (no underscore, unlike npc_types.name)
- `level=29` — last known from zone log ("leveled up to [29]" at 22:22:44)
- `class_id=2` — Cleric, from npc_types
- `race_id=1` — Human, from npc_types
- `gender=0` — Male, from npc_types
- `is_suspended=1` — required for re-recruitment track to find this record
- `is_dismissed=1` — required for re-recruitment track to find this record
- `stance=1` — default (aggressive=1 matches other active companions)
- `recruited_at='2026-03-08 00:00:00'` — conservative estimate (first seen in logs March 9)
- `experience=0` — unknown, defaulting to 0 (re-recruitment will continue from here)
- `recruited_level=1` — conservative default (level at recruitment unknown)
- `times_died=1` — records the March 13 death event
- `zones_visited=NULL` — history lost with the record

**Step 4 — Verification:**
```sql
SELECT * FROM companion_data WHERE npc_type_id = 2032;
-- id=24 confirmed: is_suspended=1, is_dismissed=1, level=29, class_id=2, race_id=1

SELECT * FROM data_buckets WHERE `key` LIKE '%companion_cooldown_2032%';
-- Empty result set (cooldown deleted)
```

**Notes:**
- companion_inventories for old id=17 were also lost with the record. Lashun will need to be re-equipped after re-recruitment.
- The player should be able to re-recruit immediately. Zone or `#reloadquests` may be needed.
- Experience, recruited_level, and zones_visited were reset to defaults — this is unavoidable without a backup.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| `data_buckets.key_` column not found | Investigation noted `key_` but actual column is `key` (reserved word) | Used backtick-quoted `` `key` `` in all queries |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `data_buckets` (DB) | Deleted 1 row | Removed stale cooldown `companion_cooldown_2032_6` (id=30) |
| `companion_data` (DB) | Inserted 1 row | Recovery record for Lashun Novashine, id=24, npc_type_id=2032, is_suspended=1, is_dismissed=1, level=29 |

---

## Open Items

- [ ] c-expert: Harden `Companion::Death()` against entity ID=0 state to prevent recurrence (see investigation.md)
- [ ] companion_inventories for Lashun (old id=17) are gone — player must re-equip after re-recruitment

---

## Context for Next Agent

Lashun Novashine's companion_data record was lost during a death event when entity ID became 0 before Save() could run. This is a systemic bug in `Companion::Death()` that c-expert needs to address.

Data recovery is complete. The re-recruitment system should now find `companion_data` id=24 (npc_type_id=2032, is_dismissed=1, is_suspended=1) and route through the bypass track on next recruitment attempt.

The player (Chelon, character_id=6) will need to:
1. Approach Lashun Novashine in-game
2. Trigger recruitment keyword
3. Re-equip Lashun after re-recruitment (equipment was lost)
