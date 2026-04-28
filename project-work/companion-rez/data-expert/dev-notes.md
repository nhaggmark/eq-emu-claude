# Companion Rez — Dev Notes: data-expert

> **Feature branch:** `bugfix/companion-rez`
> **Agent:** data-expert
> **Task(s):** Data layer triage (architecture support)
> **Date started:** 2026-04-27
> **Current stage:** Complete (triage delivered to architect)

---

## Task Assignment

Architecture support triage — read-only DB audit to feed findings to the architect.

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | DB triage: pending rez state, companion death state, AI config, spell rules | — | Complete |

---

## Stage 1: Plan

Read PRD and SQL topography docs. Run live DB queries to audit:
1. Pending rez state in `data_buckets`
2. Rez-related tables (any `rez_requests` table?)
3. `companion_data` death state (`is_suspended` semantics)
4. AI/cast config gating NPC rez
5. `spells_new` for the five Cleric rez spells

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `claude/docs/topography/SQL-CODE.md` | All | Table inventory, `data_buckets` schema (column is `key` not `key_`), `spells_new` class columns |
| `claude/project-work/companion-rerecruit/architect/architecture.md` | death/rez sections | `is_suspended=1` is death state; `is_dismissed=0` on death; row preserved with cur_hp |

### Key Findings

See Stage 4 Implementation Log (triage results below).

---

## Stage 2: Research

All findings are from live DB queries. No external documentation needed — this is
a data audit, not a new implementation.

---

## Stage 3: Socialize

No consensus plan required — this is read-only triage. Findings sent to architect
via SendMessage after Stage 4.

---

## Stage 4: Build (Triage)

### Implementation Log

#### 2026-04-27 — DB Triage: Rez and Companion State Audit

**What:** Live read-only queries against `peq` DB.

---

### FINDING 1: No pending rez state stored in DB

**Tables checked:** `data_buckets`, `character_corpses`, `timers`

`data_buckets` contains zero rows with rez- or companion-related keys. Current
live keys are only `soul_wipe_6_*` entries. No pending-rez state is DB-stored.

`character_corpses` has `is_rezzed`, `rezzable`, and `rez_time` columns, but
these are player-corpse fields only. NPC corpses do not persist in this table.

**Conclusion:** The rez bug has NO data-layer enforcement. There is no pending
rez request table, no NPC rez state table, no DB row blocking or gating the rez.
The problem is purely application-layer (C++ rez request/accept flow).

---

### FINDING 2: No rez-specific tables exist

**Tables checked:** All tables via `SHOW TABLES LIKE '%rez%'` and `SHOW TABLES LIKE '%resurrect%'`

Result: zero tables. No `rez_requests` table or equivalent. The standard EQ rez
flow uses in-memory opcode handling (`OP_RezzRequest`, `OP_RezzAnswer`) with no
persistent DB component. Confirmation of purely application-layer issue.

---

### FINDING 3: companion_data — is_suspended=1 correctly flags death state

**Current live data (5 rows, all active):**

| id | name | class_id | level | is_suspended | is_dismissed | cur_hp | times_died |
|----|------|----------|-------|-------------|--------------|--------|-----------|
| 10 | Lydl the Great | 12 | 54 | 0 | 0 | 402 | 4 |
| 18 | Hollish Tnoops | 1 | 54 | 0 | 0 | 728 | 10 |
| 22 | Jimble Woodentoe | 4 | 54 | 0 | 0 | 674 | 2 |
| 23 | Jracol Brestiage | 9 | 54 | 0 | 0 | 674 | 2 |
| 24 | Lashun Novashine (Cleric) | 2 | 54 | 0 | 0 | 2052 | 4 |

All companions are currently alive and active. `is_suspended=1` is the death
state per companion-rerecruit architecture (written at `companion.cpp:1881`
and `:646-678`). When a companion dies, `is_suspended=1, is_dismissed=0` with
`cur_hp` preserved (not zeroed). This is established, working behavior.

**Conclusion:** Companion death state is correctly modeled in `companion_data`.
No schema change needed for the rez feature. The C++ rez logic needs to query
`companion_data WHERE is_suspended=1 AND is_dismissed=0` to identify rez targets.

---

### FINDING 4: Rez spells ARE populated in companion_spell_sets (spell_type=65536)

**companion_spell_sets for class_id=2 (Cleric), spell_type=65536:**

| id | spell_id | name | min_level | max_level | priority |
|----|----------|------|-----------|-----------|----------|
| 1252 | 2168 | Reanimation | 12 | 65 | 1 |
| 1253 | 2169 | Reconstitution | 18 | 65 | 1 |
| 1254 | 2170 | Reparation | 22 | 65 | 1 |
| 1255 | 391 | Revive | 27 | 65 | 1 |
| 1256 | 2171 | Renewal | 32 | 65 | 1 |
| 1257 | 388 | Resuscitate | 37 | 65 | 1 |
| 1258 | 2172 | Restoration | 42 | 65 | 1 |
| 1259 | 392 | Resurrection | 47 | 65 | 1 |
| 1260 | 1524 | Reviviscence | 56 | 65 | 1 |

**spell_type=65536** is the companion system's custom rez spell type. All nine
spells cover the full Classic-Luclin Cleric rez progression (including the
PRD's five canonical spells plus additional in-era Cleric rez spells).
`min_hp_pct=0, max_hp_pct=0` — no HP gate on these spells (correct for rez,
since rez is cast out of combat, not in response to HP threshold).

**Critical:** The rez spells do NOT appear in any `npc_spells_entries` row
(checked against spell IDs 388, 391, 392, 2168, 2172 — zero matches). The
companion system uses `companion_spell_sets` exclusively, not `npc_spells_entries`.

**Conclusion:** The spell data is correct and complete. No spell data changes
needed. The C++ rez logic needs to read from `companion_spell_sets WHERE
class_id=2 AND spell_type=65536 AND min_level <= companion_level` to select
the appropriate rez spell tier.

---

### FINDING 5: Companions:Rez* rules ALREADY EXIST in rule_values

This is a significant finding. Four rez-specific Companion rules are already
populated in `rule_values`:

| rule_name | rule_value | notes |
|-----------|------------|-------|
| Companions:RezEnabled | true | Master toggle for companion autonomous resurrection |
| Companions:RezPostCombatDelayS | 10 | Seconds after combat ends before healer companion attempts resurrection |
| Companions:RezRange | 200 | Maximum distance in game units to target a corpse for resurrection |
| Companions:RezWaiveReagents | true | Waive spell reagent requirements for companion rez casters |

These rules answer PRD Open Question 1 (N=10 seconds) and pre-define the
master toggle, range, and reagent-waive behavior. They were written in advance
of the C++ implementation, or they are stubs from a partially-implemented
feature. The architect needs to verify whether the C++ code that READS these
rules is implemented and working.

**Conclusion:** The rule_values data layer is complete and correct for the rez
feature. No new rules need to be added. The architect should confirm C++ reads
these rules (especially `RezEnabled` as a guard) and that `RezPostCombatDelayS=10`
is the intended answer to AC-1's N value.

---

### FINDING 6: No AI/cast config tables gate NPC rez behavior

Checked:
- `npc_types` for Lashun Novashine (id=2032): `npcspecialattks=NULL, special_abilities=NULL` — no behavior flags set
- `rule_values` for NPC rez blocking rules: zero results
- No `companion_ai_config` or similar table exists

**Conclusion:** No DB-level AI config gates rez. The rez failure is application-layer only.

---

### FINDING 7: Spell details for the five PRD Cleric rez spells

| id | name | mana | cast_time | recast_time | cleric_col (classes2) | targettype | effectid1 | xp_return (effect_base_value1) |
|----|------|------|-----------|-------------|----------------------|-----------|-----------|-------------------------------|
| 2168 | Reanimation | 150 | 6000ms | 20000ms | 12 | 15 | 81 | 0% |
| 391 | Revive | 300 | 6000ms | 20000ms | 27 | 15 | 81 | 35% |
| 388 | Resuscitate | 500 | 6000ms | 20000ms | 37 | 15 | 81 | 60% |
| 2172 | Restoration | 600 | 6000ms | 20000ms | 42 | 15 | 81 | 75% |
| 392 | Resurrection | 700 | 6000ms | 20000ms | 47 | 15 | 81 | 90% |

Notes:
- `targettype=15` = "corpse" — confirmed these are corpse-targeted spells
- `effectid1=81` = resurrection effect
- `classes2` is the Cleric column (class 2 = Cleric in EQ). All are 255 in classes1 (Warrior) — not warrior-castable.
- NPC rez is NOT gated by the classes column — NPCs cast from their spell lists/companion_spell_sets, not from class column checks.
- 6-second cast time, 20-second recast. The recast timer matters for sequential multi-target rez (AC-6) — the Cleric must wait 20 seconds between rezzes.
- Mana cost escalates with tier (150 → 300 → 500 → 600 → 700). The Companions:RezWaiveReagents rule handles the bone chip/components issue.

---

### Summary for Architect

**The rez bug is PURELY application-layer. The data layer is fully set up:**

1. **No pending rez state in DB** — rez request/accept is in-memory only (opcodes). No DB persistence needed.
2. **No rez-blocking DB enforcement** — no table, column, or rule_value blocks NPC rez.
3. **companion_data death state is correct** — `is_suspended=1` = dead/rezzable candidate. No schema change needed.
4. **Rez spells are fully populated** in `companion_spell_sets` with `spell_type=65536`. The architect needs to verify the C++ spell-selection logic reads this correctly for rez (vs. combat spells which likely use a different type).
5. **Rez rule_values already exist** — `Companions:RezEnabled`, `RezPostCombatDelayS=10`, `RezRange=200`, `RezWaiveReagents=true` are all in `rule_values`. The C++ code that reads these may or may not be implemented. **This is the architect's critical investigation point.**
6. **No data changes recommended** — the data layer is complete. If the C++ rez reading from rule_values is stubbed/broken, that's the C++ fix, not a data fix.

**One flag for the architect:** `RezPostCombatDelayS=10` already answers PRD Open Question 1 (what is N?). Architect should verify this is the intended value and document it in the architecture plan.

---

#### 2026-04-27 — DB Audit Round 2 (architect's specific questions)

Full query results saved to `context/db-audit-round2.md`.

**Item 1 — npc_spells/npc_spells_entries audit:**
All Cleric NPCs (class=2, lvl 10–65) use `npc_spells_id=1`. No rez spells in
list 1 — confirmed zero `npc_spells_entries` rows with `effectid1=81`. The
`npc_spells_entries.type` column uses the same SpellType bitmask enum as
`companion_spell_sets.spell_type`. `SpellType_Resurrect = (1<<16) = 65536`
per `common/spdat.h:648`. No type=65536 rows exist in `npc_spells_entries`
— this is correct and by design. The companion system uses `companion_spell_sets`
exclusively (loaded via `LoadCompanionSpells()` at companion_ai.cpp:288).

**Item 2 — spells_new full row details:**
Confirmed 5 rows loaded. effectid1=81 (SE_Revive), goodEffect=1, targettype=15
(ST_Corpse), mana 150→700 by tier, recast 20s uniform, cast 6s uniform.
`spells_new` has NO `min_expansion`/`max_expansion` columns on this schema.
No inline expansion gate on spell records.

**Item 3 — companion_data schema:**
All expected columns confirmed present. Live counts: 5 total rows, 0 suspended,
0 dismissed, 0 cur_hp=0 (no zombie rows — clean state).

**Item 5 — rule_values:**
All 7 requested rules present and correctly set. `RezEnabled=true`,
`RezPostCombatDelayS=10`, `RezRange=200`, `RezWaiveReagents=true`,
`XPDeathPenaltyPct=10`, `DeathDespawnS=1800`, `EquipmentPersistsThroughDeath=true`.
No mis-set rules.

**Item 6 — data_buckets:** Zero rez-related keys.

**Item 7 — companion corpse:** No companion_corpse table exists. Corpses are
entity-only (zone memory). Confirmed via SHOW TABLES.

**Item 8 — expansion gates:**
- `spells_new`: no expansion columns — no gate
- `npc_spells_entries`: has min/max_expansion cols, all set to -1 (all eras)
- `companion_spell_sets`: no expansion columns — no gate
No expansion gate blocks the rez spells anywhere in the data layer.

**C++/DB alignment verified:**
`LoadCompanionSpells()` query at companion_ai.cpp:288-308 matches
`companion_spell_sets` schema exactly. `SelectFirstSpell()` at line 1964
uses `SpellType_Resurrect` bitmask = 65536 — exact match to DB value.

**Flag for architect:** `SpellType_Resurrect` is NOT included in the
`SPELL_TYPES_BENEFICIAL` constant at `spdat.h:899`. Architect should verify
this doesn't cause BENEFICIAL-gate failures in AI dispatch or resist checks.

---

## Open Items

- [x] Architect confirmed C++ reads Companions:RezEnabled — yes, via rule system
- [x] spell_type=65536 confirmed aligned with SpellType_Resurrect — pipeline correct
- [ ] Architect to verify SpellType_Resurrect not in SPELL_TYPES_BENEFICIAL is not a problem

---

## Context for Next Agent

The data layer is clean and complete for this feature. companion_spell_sets has
all rez spells under spell_type=65536. rule_values has all four rez tuning rules.
companion_data uses is_suspended=1 for death state. No schema changes are needed.
The fix is entirely in C++ (and possibly Lua for the trigger). This report was
sent to the architect as input to their triage.
