# DB Audit Round 2 — Architect's Specific Questions
# data-expert, 2026-04-27

## Item 1: npc_spells / npc_spells_entries audit for Cleric rez spells

### Live Cleric NPC spell lists (sample)

All sampled Cleric NPCs (class=2, level 10–65) share `npc_spells_id = 1`.
There is no Cleric-specific spell list — every Cleric NPC in the game uses
list 1 regardless of level.

```
id=238447  a_Savagefang_liturgist  lvl 10  npc_spells_id=1
id=19139   a_halfling_acolyte      lvl 10  npc_spells_id=1
id=9119    Ulia_Yovar              lvl 11  npc_spells_id=1
id=248577  a_Scion_nightwatcher    lvl 12  npc_spells_id=1
...
```

### npc_spells_entries.type bitmask values present

```
type=1     2733 rows
type=2     217
type=4     171
type=8     995
type=16    15
type=32    180
type=64    88
type=128   86
type=256   362
type=512   68
type=1024  72
type=2048  37
type=4096  53
type=8192  14
type=16384 26
```

**No type=65536 (SpellType_Resurrect = 1<<16) in npc_spells_entries.**

The `type` column in `npc_spells_entries` maps to the same SpellType enum
values as `companion_spell_sets.spell_type`. The SpellType enum (common/spdat.h:632):

```
SpellType_Nuke        = 1       (1<<0)
SpellType_Heal        = 2       (1<<1)
SpellType_Root        = 4       (1<<2)
SpellType_Buff        = 8       (1<<3)
SpellType_Escape      = 16      (1<<4)
SpellType_Pet         = 32      (1<<5)
SpellType_Lifetap     = 64      (1<<6)
SpellType_Snare       = 128     (1<<7)
SpellType_DOT         = 256     (1<<8)
SpellType_Dispel      = 512     (1<<9)
SpellType_InCombatBuff= 1024    (1<<10)
SpellType_Mez         = 2048    (1<<11)
SpellType_Charm       = 4096    (1<<12)
SpellType_Slow        = 8192    (1<<13)
SpellType_Debuff      = 16384   (1<<14)
SpellType_Cure        = 32768   (1<<15)
SpellType_Resurrect   = 65536   (1<<16)   <-- NOT in npc_spells_entries
```

### rez spells in npc_spells_entries: zero

Queried: `SELECT ... FROM npc_spells_entries JOIN spells_new WHERE effectid1=81`
Result: **0 rows**. No NPC spell list (including list 1 used by all Cleric NPCs)
contains any rez spell. The NPC spell list system never had rez spells.

The companion rez system bypasses `npc_spells_entries` entirely and uses
`companion_spell_sets` instead. This is correct by design — `LoadCompanionSpells()`
at companion_ai.cpp:288 queries `companion_spell_sets` directly.

---

## Item 2: spells_new full audit for the five Cleric rez spells

All five spells are loaded (COUNT=5 confirmed).

| id   | name         | mana | cast_time | recast_time | cleric_lvl (classes2) | targettype | goodEffect | effectid1 | effect_base_value1 (XP%) |
|------|--------------|------|-----------|-------------|----------------------|------------|------------|-----------|--------------------------|
| 2168 | Reanimation  | 150  | 6000ms    | 20000ms     | 12                   | 15         | 1          | 81        | 0                        |
| 391  | Revive       | 300  | 6000ms    | 20000ms     | 27                   | 15         | 1          | 81        | 35                       |
| 388  | Resuscitate  | 500  | 6000ms    | 20000ms     | 37                   | 15         | 1          | 81        | 60                       |
| 2172 | Restoration  | 600  | 6000ms    | 20000ms     | 42                   | 15         | 1          | 81        | 75                       |
| 392  | Resurrection | 700  | 6000ms    | 20000ms     | 47                   | 15         | 1          | 81        | 90                       |

Notes:
- `effectid1 = 81` = SE_Revive (the resurrect spell effect)
- `effectid2` through `effectid12` = 254 (SE_Blank = unused)
- `targettype = 15` = ST_Corpse (corpse-targeted)
- `goodEffect = 1` (beneficial spell)
- `classes2` is the Cleric column (class 2 in EQ). NPCs are not gated by
  classes columns — they cast from their spell list, so this column is
  irrelevant for NPC companion casting.
- spells_new has NO `min_expansion` / `max_expansion` columns on this schema.
  Expansion filtering for spells is handled by blocked_spells and content
  flags, not inline columns.

---

## Item 3: companion_data schema and live state

### Schema (confirmed complete)

All expected columns present:
id, owner_id, npc_type_id, name, companion_type, level, class_id, race_id,
gender, zone_id, x, y, z, heading, cur_hp, cur_mana, cur_endurance,
is_suspended, stance, spawn2_id, spawngroupid, recruited_at, experience,
recruited_level, is_dismissed, total_kills, zones_visited, time_active, times_died

`is_suspended` default = 1 (new rows start suspended until spawned).
`is_dismissed` default = 0.

### Live state counts

```
total_rows:    5
suspended=1:   0   (all currently active/alive)
dismissed=1:   0
cur_hp=0:      0   (no dead-but-not-suspended rows — no bug here)
dead_rezzable: 0   (is_suspended=1 AND is_dismissed=0 = 0)
```

All five companions are alive and active. No current rez candidates in DB.
The `cur_hp=0` check is clean — no zombie rows.

---

## Item 5: rule_values for companion rez and death

All seven rules requested are present and correctly set:

| rule_name | rule_value | status |
|-----------|------------|--------|
| Companions:RezEnabled | true | CORRECT — master toggle on |
| Companions:RezPostCombatDelayS | 10 | CORRECT — N=10s (answers PRD OQ-1) |
| Companions:RezRange | 200 | CORRECT |
| Companions:RezWaiveReagents | true | CORRECT — bone chips waived |
| Companions:XPDeathPenaltyPct | 10 | CORRECT — 10% XP loss on death |
| Companions:DeathDespawnS | 1800 | CORRECT — 30 min before auto-dismiss |
| Companions:EquipmentPersistsThroughDeath | true | CORRECT — gear survives death |

No mis-set rules. `RezEnabled=true` is NOT the bug.

---

## Item 6: data_buckets pending rez state

Zero rez-related keys. All keys in `data_buckets` are `soul_wipe_6_*` only.
No pending rez state is DB-stored. Rez request/accept is entirely in-memory.

---

## Item 7: companion corpse representation

Confirmed: `character_corpses` stores ONLY player character corpses (keyed by
`charid`). No companion-corpse table exists. Companion corpses are entity-only
(zone memory), created as NPC corpse objects with companion metadata from
`Corpse::SetCompanionData`. No DB persistence. This is correct and intentional.

---

## Item 8: expansion gates on rez spells

### spells_new: NO expansion columns

`spells_new` on this schema has no `min_expansion` / `max_expansion` columns.
No inline expansion gate on spell records. Expansion filtering for spells is
handled via `blocked_spells` table (zone-level blocks) and content flags.

### npc_spells_entries: expansion columns present but all -1

`npc_spells_entries` has `min_expansion` and `max_expansion` columns.
For list 1 (the universal Cleric spell list):
```
min_expansion range: -1 to -1  (all entries = -1 = all expansions)
max_expansion range: -1 to -1  (all entries = -1 = all expansions)
```
No expansion gate on any NPC spell entry. All spells available in all eras.

### companion_spell_sets: NO expansion columns

`companion_spell_sets` has NO `min_expansion` / `max_expansion` columns.
No expansion filtering possible at the companion spell set level.

**Conclusion: No expansion gate blocks the five Cleric rez spells anywhere in the data layer.**

---

## Key DB/C++ Alignment Finding

`LoadCompanionSpells()` at companion_ai.cpp:288 queries:
```sql
SELECT spell_id, spell_type, stance, priority, min_hp_pct, max_hp_pct
FROM companion_spell_sets
WHERE class_id = {class} AND min_level <= {level} AND max_level >= {level}
ORDER BY priority ASC, id ASC
```

The five rez spells in `companion_spell_sets` for class_id=2 (Cleric):
- All have `spell_type = 65536` = `SpellType_Resurrect` (1<<16) — exact match
- `min_hp_pct = 0, max_hp_pct = 0` — no HP gate
- Level ranges cover 12–65 fully

The C++ code at companion_ai.cpp:1964 calls:
```cpp
rez_spell = SelectFirstSpell(m_companion_spells, SpellType_Resurrect, m_current_stance, now_ms);
```

This will correctly find rez spells from the loaded `m_companion_spells` vector.
The spell loading path is correct. The spell selection path is correct.

**The data layer feeds the C++ pipeline correctly. The spells.cpp ST_Corpse gate
is the only thing that prevents the rez from landing on the NPC corpse target.**

Also flag: `SpellType_Resurrect` is NOT in `SPELL_TYPES_BENEFICIAL` constant
(spdat.h:899). Depending on where SPELL_TYPES_BENEFICIAL is used as a gate,
this could cause the rez spell to be treated as detrimental in some code paths.
Architect should verify this doesn't affect AI dispatch or spell resist checks.
