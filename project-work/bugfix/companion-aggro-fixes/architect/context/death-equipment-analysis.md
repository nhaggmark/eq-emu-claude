# BUG-012: Companion Loses Equipment on Death and Re-Recruitment

## Root Cause Analysis

### Summary

**The bug has two distinct failure modes**, both caused by the same underlying defect:
`Companion::Save()` never writes `is_dismissed = 1` to the database, so the
re-recruitment path in `CreateFromNPC()` cannot find the dismissed companion record
and falls through to the "fresh recruitment" path, creating a new companion record
without the old companion's equipment, XP, or state.

### Detailed Analysis

#### The `is_dismissed` Column Gap

The `companion_data` table has an `is_dismissed` column (uint8, 0 or 1). The
`CompanionData` struct in `companion_data_repository.h` includes `is_dismissed` as
a field. However:

1. **There is no C++ member variable `m_is_dismissed`** on the `Companion` class.
   The header (`companion.h`) has no such field. The comment at line 186 of
   `companion.cpp` confirms: "is_dismissed has no C++ member".

2. **`Save()` always writes `is_dismissed = 0`** because it builds the struct from
   `CompanionDataRepository::NewEntity()` (which defaults `is_dismissed = 0`) and
   never modifies `cd.is_dismissed` before calling `InsertOne()` or `UpdateOne()`.

3. **`Dismiss(false)` (voluntary dismissal)** calls `SetSuspended(true)` + `Save()`,
   which writes `is_suspended = 1, is_dismissed = 0`.

4. **Re-recruitment in `CreateFromNPC()`** queries:
   ```sql
   WHERE owner_id = ? AND npc_type_id = ? AND is_dismissed = 1 LIMIT 1
   ```
   This query NEVER matches because `is_dismissed` is never set to 1.

5. **Result**: `CreateFromNPC()` falls through to the "fresh recruitment" path,
   creating a brand new `companion_data` record with id=NEW. The old record
   (id=OLD) remains orphaned in the database. Equipment stored in
   `companion_inventories` references `companion_id = OLD`, not the new record.
   The new companion has no equipment.

#### Failure Mode 1: Voluntary Dismissal + Re-Recruitment

1. Player trades equipment to companion (saved to `companion_inventories` with `companion_id = X`)
2. Player dismisses companion (`!dismiss`) -> `Dismiss(false)` -> `Save()` writes `is_suspended=1, is_dismissed=0`
3. Player re-recruits same NPC -> `CreateFromNPC()` looks for `is_dismissed=1`, finds nothing
4. Fresh companion created with `companion_id = Y` (new record)
5. Equipment is in `companion_inventories` with `companion_id = X` (old record)
6. New companion has `companion_id = Y`, calls `LoadEquipment()` -> finds no rows -> no equipment

#### Failure Mode 2: Death + Re-Recruitment (Before Despawn Timer)

1. Companion dies -> `Death()` -> `Save()` writes `is_suspended=1, is_dismissed=0, cur_hp=0`
2. Player re-recruits same NPC BEFORE the death despawn timer fires
3. `CreateFromNPC()` looks for `is_dismissed=1`, finds nothing
4. Fresh companion created, equipment lost (same as Mode 1)

#### Failure Mode 3: Death + Despawn Timer (Permanent Loss)

1. Companion dies, death despawn timer fires
2. `SoulWipe()` is called which:
   - Deletes ALL `companion_inventories` rows for this companion
   - Deletes ALL `companion_buffs` rows for this companion
   - Deletes the `companion_data` record entirely
3. Equipment is permanently destroyed

### The Fix (Two Parts)

#### Part 1: Add `m_is_dismissed` member and wire it through Save()

1. Add `bool m_is_dismissed = false;` to `Companion` class private members in `companion.h`
2. Add getter/setter: `bool IsDismissed() const` / `void SetDismissed(bool)`
3. In `Save()`, set `cd.is_dismissed = m_is_dismissed ? 1 : 0;` before insert/update
4. In `Load()`, restore: `m_is_dismissed = (cd.is_dismissed == 1);`

#### Part 2: Set `is_dismissed = 1` in the voluntary dismissal path

In `Companion::Dismiss(bool permanent)`:
- When `permanent == false` (voluntary dismissal): set `m_is_dismissed = true` BEFORE calling `Save()`
- When `permanent == true`: `SoulWipe()` deletes the record entirely, so `is_dismissed` is moot

#### Part 3: Handle death-then-re-recruitment correctly

The death path currently writes `is_suspended=1, is_dismissed=0`. For re-recruitment
after death (before despawn timer fires), `CreateFromNPC()` should ALSO check for
`is_suspended=1` records, not just `is_dismissed=1`. Two options:

**Option A (Recommended)**: Change the `CreateFromNPC()` re-recruitment query to:
```sql
WHERE owner_id = ? AND npc_type_id = ? AND (is_dismissed = 1 OR is_suspended = 1)
```
This allows re-recruitment of both voluntarily dismissed AND dead companions.

**Option B**: In `Death()`, also set `m_is_dismissed = true` before `Save()`. This
semantically conflates "dismissed" with "dead", which may cause confusion. Option A
is cleaner.

#### Part 4: SaveEquipment() in Death() path

The `Death()` method currently saves equipment only if the
`EquipmentPersistsThroughDeath` rule is FALSE (to return items to owner). When
the rule is TRUE (default), `Death()` calls `Save()` but NOT `SaveEquipment()`.
Since `Save()` saves the companion_data record (with HP=0), equipment should
already be persisted from when it was last `GiveItem()`'d. But we should verify
this is robust by adding an explicit `SaveEquipment()` call in `Death()` after
`Save()` when equipment persists through death.

### Files to Modify

| File | Change |
|------|--------|
| `eqemu/zone/companion.h` | Add `m_is_dismissed` member, getter/setter |
| `eqemu/zone/companion.cpp` | Wire `m_is_dismissed` through Save(), Load(), Dismiss(), CreateFromNPC() |

### Risk Assessment

- **Low risk**: The `is_dismissed` column already exists in the DB and repository
- **No schema changes needed**: The column is already there, just never written
- **No client-side changes**: This is purely server-side persistence logic
- **Backward compatible**: Existing companion records with `is_dismissed=0` will
  work correctly -- they just won't be found by the re-recruitment path until
  the companion is dismissed again (which will now correctly set `is_dismissed=1`)

### Orphaned Records

Any companion records created by the "fresh recruitment" fallback path are now
orphaned in the database (old records with stale equipment). These should be
cleaned up with a one-time SQL migration:

```sql
-- Find orphaned companion_data records (multiple records for same owner+npc_type)
SELECT owner_id, npc_type_id, COUNT(*) as record_count
FROM companion_data
GROUP BY owner_id, npc_type_id
HAVING COUNT(*) > 1;

-- For each duplicate set, keep the newest record and delete older ones
-- (The newest record is the active one; older ones are orphans from the bug)
```

Equipment in `companion_inventories` referencing deleted companion_ids will be
automatically orphaned. A cleanup query should also delete those:

```sql
DELETE FROM companion_inventories
WHERE companion_id NOT IN (SELECT id FROM companion_data);
```
