# Companion Re-recruitment Fix — Dev Notes: data-expert

> **Feature branch:** `bugfix/companion-rerecruit`
> **Agent:** data-expert
> **Task(s):** Task #3 — Data layer triage for re-recruit blockers
> **Date started:** 2026-04-27
> **Current stage:** Stage 3 COMPLETE — released from architecture team 2026-04-27

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Triage DB tables blocking re-recruit: data_buckets cooldowns, companion_data flags | None | Complete |

---

## Stage 1: Plan

Read PRD to understand the invariant. Three blockers to triage at DB level:
1. Level cap enforcement — is it a rule_values entry?
2. Cooldown — data_buckets key pattern, verify MEMORY entry
3. Dismissed/suspended flag — companion_data fields, what persists after death/dismissal

### Files Examined

| File | What You Found |
|------|----------------|
| `data_buckets` live schema | VARCHAR(100) key, composite UNIQUE on (key, character_id, npc_id, bot_id, account_id, zone_id, instance_id), expires = 0 means "never" |
| `companion_data` live schema | Contains is_dismissed, is_suspended, cur_hp, experience, level. Default is_suspended=1. No FK constraints. No UNIQUE on (owner_id, npc_type_id) |
| `companion_inventories` live schema | Keyed by companion_id (FK to companion_data.id by convention — no enforced FK). UNIQUE on (companion_id, slot_id) |
| `companion_buffs` live schema | Keyed by companion_id. No FK constraint enforced |
| `companion_exclusions` | npc_type_id, reason, exclusion_type — blocklist for recruitability |
| `companion_culture_persuasion` | Race-based recruitment type/disposition rules |
| `companion_spell_sets` | Class/level-range spell assignments |
| `rule_values` | Full set of Companions:* rules including LevelRange=50, RecruitCooldownS=900 |
| `data_buckets` live data | 8 rows, all soul_wipe_* keys. Zero companion_cooldown rows currently |

### Key Findings

**Blocker 1 — Level cap (rule_values):**
- `Companions:LevelRange` = 50 (+/- 50 levels from player level)
- This is an application-level rule, no DB-level enforcement
- The architect/c-expert must identify where this rule is read in C++ and whether it gates re-recruitment separately from first-recruitment
- No DB constraint enforces this — all enforcement is in C++ application code

**Blocker 2 — Cooldown (data_buckets):**
- MEMORY entry (45 days old) stated: cooldown keys stored as `companion_cooldown_{npc_type_id}_{char_id}` with character_id=0, npc_id=0
- VERIFIED: The data_buckets schema confirms character_id and npc_id columns exist but can be 0 (non-scoped)
- VERIFIED: No companion_cooldown rows currently in data_buckets (either expired or previously cleared)
- KEY DISCREPANCY: rule_values notes for `Companions:RecruitCooldownS` say "Cooldown in seconds after a FAILED recruitment attempt" — this contradicts MEMORY which says it fires on dismissal/death. The actual trigger is application-level (C++/Lua). C-expert and lua-expert must confirm when the cooldown bucket is written.
- The soul_wipe_* key pattern (currently in DB) shows the key format: `{keyname}_{owner_char_id}_{npc_companion_id}` — the companion cooldown pattern likely mirrors this
- DELETE pattern to clear cooldowns: `DELETE FROM data_buckets WHERE key LIKE 'companion_cooldown_%'` — matches by key prefix, works regardless of character_id column value

**Blocker 3 — Dismissed/suspended flags (companion_data):**
- `is_dismissed` tinyint — default 0. When set to 1, marks companion as intentionally dismissed
- `is_suspended` tinyint — default 1. When set to 1, companion is NOT currently active/spawned
- `cur_hp` bigint — when 0 after death, companion is dead
- The composite index `idx_owner_active` on `(owner_id, is_dismissed, is_suspended)` confirms these flags are used together in queries that list a character's active companions
- No DB-level constraint prevents re-recruitment of a dismissed companion — it's application-level (C++/Lua check)
- Duplicate companion_data rows CAN exist: Hollish Tnoops (npc_type_id=9144) has rows id=18 (level 53, is_suspended=0) and id=21 (level 14, is_suspended=1) both for owner_id=6. No UNIQUE constraint blocks this.

**No DB-level blockers (constraints/triggers/procedures):**
- `SHOW TRIGGERS FROM peq` — empty (no triggers)
- `SHOW PROCEDURE STATUS WHERE Db='peq'` — empty (no stored procedures)
- `KEY_COLUMN_USAGE` for companion tables — zero FK constraints
- All three blockers are 100% application-level (C++ and/or Lua). The DB enforces nothing about recruitment eligibility.

**companion_inventories integrity note:**
- `companion_inventories.companion_id` references `companion_data.id` by convention only — no FK enforced
- UNIQUE on `(companion_id, slot_id)` prevents duplicate slot entries per companion
- Safe to UPDATE/DELETE companion_data rows; orphaned companion_inventories rows won't trigger a cascade error but may accumulate if not cleaned up

### Implementation Plan

At data layer, the fix involves:

1. **Cooldown bypass** — the C++/Lua layer must bypass writing the data_buckets cooldown row when re-recruiting a previously-recruited NPC. No DB schema change needed. If a defensive cleanup is needed, the DELETE pattern is:
   ```sql
   DELETE FROM data_buckets WHERE `key` LIKE 'companion_cooldown_%';
   -- or scoped to specific char:
   DELETE FROM data_buckets WHERE `key` LIKE 'companion_cooldown_%_{char_id}';
   ```

2. **Dismissed flag** — the C++/Lua re-recruit path must set `is_dismissed=0` and `is_suspended=0` (and restore cur_hp if dead) when re-recruiting. The UPDATE pattern:
   ```sql
   UPDATE companion_data SET is_dismissed=0, is_suspended=0
   WHERE owner_id=? AND npc_type_id=? AND id=?;
   ```

3. **Level cap** — `Companions:LevelRange` rule value gates recruitment. The fix likely needs a rule update (`RecruitLevelRangeRerecruit` or similar) or a C++ bypass check. This is the architect's decision. No DB schema change required — only a possible `rule_values` INSERT/UPDATE.

4. **No schema migrations needed** — existing tables support the fix. All enforcement is application-level.

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| data_buckets schema (column types, indexes) | Live DB DESCRIBE + SHOW INDEX | Yes | Composite UNIQUE on all scope columns including key |
| companion_data schema | Live DB DESCRIBE + SHOW CREATE | Yes | No FK constraints, no UNIQUE on owner+npc |
| companion_inventories schema | Live DB SHOW CREATE | Yes | UNIQUE on (companion_id, slot_id), no FK |
| Companions:LevelRange rule | Live rule_values query | Yes | Value=50, application-level only |
| Companions:RecruitCooldownS rule | Live rule_values query | Yes | Value=900, notes say "failed attempt" — may contradict MEMORY |
| FK constraints on companion tables | information_schema.KEY_COLUMN_USAGE | Yes | Zero FK constraints |
| Triggers and procedures | SHOW TRIGGERS, SHOW PROCEDURE STATUS | Yes | None exist |

### Plan Amendments

MEMORY entry on cooldown clearing is structurally still correct (DELETE by key pattern), but the trigger condition for when cooldowns are written may differ from what MEMORY states. The architect's C++ read may find the cooldown is written on failed-recruit only (not on death/dismissal). This is critical for understanding Blocker 2. Plan confirmed for DB operations — no amendments to SQL patterns needed.

### Verified Plan

See Implementation Plan above — SQL patterns confirmed by live schema inspection.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Data layer triage complete | Confirmed: no DB-level enforcement of blockers, all application-level. Key discrepancy: RecruitCooldownS notes say "failed attempt" — does cooldown also fire on death/dismissal? |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| architect | Three follow-up questions: tie-breaker rule for duplicate rows, one-time cleanup sweep decision, companion_exclusions row details | Answered with live queries 2026-04-27 |

### Architect Follow-up Q&A (2026-04-27)

**Q-A: Tie-breaker for duplicate (owner_id, npc_type_id) rows**

Hollish Tnoops duplicate confirmed:
- id=18: level 53, is_suspended=0, experience=18707712, 15 inventory items, recruited_at=2026-03-09 (CANONICAL)
- id=21: level 14, is_suspended=1, experience=0, 0 inventory items, recruited_at=2026-03-11 (GHOST)

"Highest id" and "most recent recruited_at" both pick the wrong row. Recommended tie-breaker:
`ORDER BY level DESC, experience DESC LIMIT 1`
Do NOT use is_suspended in the tie-breaker — legitimately suspended companions would be deprioritized.

Ghost row id=21 was likely created by a code bug (re-recruit inserted new row instead of reusing existing). Recommend adding UNIQUE constraint on (owner_id, npc_type_id) as a schema-level fix to prevent future ghosts.

**Q-B: One-time cleanup sweep**

- is_dismissed=1 rows: 0 (re-confirmed)
- cur_hp=0 rows: 0 (re-confirmed)
- No stuck rows exist in production

Recommendation: Do NOT include a broad UPDATE sweep — it would be a no-op. Do include a targeted DELETE of ghost row id=21 (Hollish Tnoops duplicate):
```sql
-- Verify first:
SELECT * FROM companion_data WHERE id = 21;
-- Then delete:
DELETE FROM companion_data WHERE id = 21;
```

**Q-C: companion_exclusions production data**

- Total rows: 7,269 (information_schema TABLE_ROWS estimate was 8,541 — always use COUNT(*) for accuracy)
- exclusion_type=1: 7,262 rows — automated (non-sentient bodytypes, bankers, merchants, guildmasters)
- exclusion_type=0: 7 rows — manual lore-anchor exclusions (Sir Lucan D'Lere, Lord Antonius Bayle, etc.)
- None of the user's active companions are in the exclusion list

Architecture note flagged to architect: the exclusion check should happen BEFORE the "previously recruited" bypass check in the recruit gate, so the bypass can short-circuit past exclusions for already-recruited NPCs.

### Architect Second Round Follow-up (2026-04-27)

**Q-A confirmed:** Lydl id=10, companion level=53, npc_types.level (base)=4, is_suspended=1, is_dismissed=0, cur_hp=1504. If the level-cap check uses npc_types.level=4 instead of companion_data.level=53, any player above level 54 trips LevelRange=50. That is the Track 2 bug path.

**Q-B dedup query — architect's sketch had a logic flaw:** ORDER BY inside a subquery for IN() includes all rows, not just the winner. Correct approach is targeted DELETE by known id=21 only. Generalized dedup belongs in a migration script, not inline SQL.

**Q-C exclusions:** All user companion NPCs (10162, 9144, 22014, 2029, 2032) confirmed absent from companion_exclusions. No corner case for repro candidates.

**Q-D UNIQUE INDEX recommendation:** YES — but only after dedup DELETE and after C++ updated to UPSERT semantics. Schema change needs custom migration entry in database_update_manifest_custom.h. Deployment sequence critical: (1) targeted DELETE id=21, (2) ALTER TABLE ADD UNIQUE INDEX uk_owner_npc (owner_id, npc_type_id), (3) deploy C++ with UPSERT. C-expert must confirm no legitimate multi-row use case before adding constraint.

### Architect Sign-off (2026-04-27)

All three decisions locked by architect:
1. Tie-breaker `ORDER BY level DESC, experience DESC LIMIT 1` — accepted, recorded in architecture.md
2. No retroactive UPDATE sweep — accepted; only targeted DELETE of id=21 with SELECT-confirm pattern
3. UNIQUE INDEX on (owner_id, npc_type_id) — flagged out-of-scope-but-tracked; engineers investigate after dismiss fix lands
4. Track 1 already short-circuits past is_eligible_npc() — exclusion ordering concern confirmed already correct in code
5. Repro candidates (Lydl, Hollish, Jimble, Jracol, Lashun) removed from architecture risk register — none in exclusions

Data-expert released from architecture team. Awaiting build-phase task assignment.

### Consensus Plan

Established via architect sign-off. Key DB-side deliverables for build phase:
- Targeted DELETE: `DELETE FROM companion_data WHERE id = 21` (after SELECT-confirm)
- companion_data row selection rule: `ORDER BY level DESC, experience DESC LIMIT 1`
- All three blockers are application-level; no schema migrations needed beyond optional future UNIQUE INDEX
- data_buckets cooldown DELETE pattern (key format to be confirmed by c-expert/lua-expert):
  `DELETE FROM data_buckets WHERE key LIKE 'companion_cooldown_%_{char_id}'`
- companion_data UPDATE on re-recruit: `SET is_dismissed=0, is_suspended=0 WHERE id=? AND owner_id=?`

---

## Stage 4: Build

**Task:** Task 7 — Targeted DELETE of ghost row `companion_data.id=21`
**Date:** 2026-04-27
**Status:** Complete

### Pre-state (verified before DELETE)

**Ghost row (id=21):**
```
id  owner_id  npc_type_id  name            level  experience  times_died  is_suspended  is_dismissed  items
21  6         9144         Hollish Tnoops  14     0           0           1             0             0
```
Matches architecture spec exactly: owner_id=6, npc_type_id=9144, name=Hollish Tnoops, level=14, experience=0, times_died=0, is_suspended=1, is_dismissed=0, items=0.

**Canonical row (id=18) — confirmed healthier:**
```
id  owner_id  npc_type_id  name            level  experience  is_suspended  items
18  6         9144         Hollish Tnoops  53     18707712    0             15
```

### Executed SQL

```sql
-- Step 3: Defensive companion_inventories delete (0 rows affected — confirmed)
DELETE FROM companion_inventories WHERE companion_id = 21;
-- ROW_COUNT() = 0

-- Step 4: Ghost row delete
DELETE FROM companion_data WHERE id = 21;
-- ROW_COUNT() = 1
```

### Post-state (verified after DELETE)

`SELECT * FROM companion_data WHERE id = 21` → empty result set. Ghost row is gone.

**Full companion_data for owner_id=6 post-delete:**
```
id  owner_id  npc_type_id  name                level  experience  is_suspended  is_dismissed  items
23  6         2029         Jracol Brestiage    53     22716517    0             0             11
24  6         2032         Lashun Novashine    53     21745789    0             0             13
18  6         9144         Hollish Tnoops      53     18707712    0             0             15
10  6         10162        Lydl the Great      53     8106020     1             0             14
22  6         22014        Jimble Woodentoe    53     22940525    0             0             17
```

5 rows total (was 6). Hollish Tnoops now has exactly 1 row (canonical id=18). Lydl the Great remains with is_suspended=1 (death state, correct).

### SQL Artifact

`context/task-7-cleanup.sql` — full SELECT-confirm-DELETE script with comments.

---

## Open Items (v1 — resolved via architecture.md)

- [x] Cooldown trigger — confirmed: fires only on failed persuasion roll (Track 2), NOT on death/dismissal
- [x] Level-range check — confirmed: only in Track 2 `is_eligible_npc()`; re-recruit uses Track 1 bypass
- [x] Level cap fix — architect decided: no rule_value change, one-character Lua fix closes the gap
- [x] Duplicate rows — architect decided: targeted DELETE of id=21 only; UNIQUE constraint deferred

---

## Stage 4 — v2 Addendum: Multi-Variant NPC Scope Investigation

**Date:** 2026-04-27
**Dispatched by:** team-lead / architect team `companion-rerecruit-architecture-v2`
**Question:** Can we safely switch re-recruit lookup to name-based instead of npc_type_id-based?

### Investigation Queries Run (all read-only)

1. `spawnentry` schema confirmed: column is `spawngroupID` (not `spawngroup_id`)
2. Lydl_the_Great in spawngroup 5765 (freporte_140): **5 entries** — npc_type_ids 10159 (Orc Centurion), 10162, 10178, 10181 (three Lydl variants), 10166 (another Orc Centurion). Three Lydl variants share the same spawngroup and same zone (freporte).
3. Total distinct Lydl_the_Great npc_type_ids: **4** (10162, 10178, 10181, 392011). 392011 spawns in northro (different zone).
4. `npc_types.name` is a `TEXT` column with collation `latin1_swedish_ci` (case-insensitive). **No index on `name`.**
5. Total multi-variant names in npc_types: **9,202 names** have more than one npc_type_id.
6. Proper-named NPC multi-variant count: **3,038 names** matching `^[A-Z][a-zA-Z]+_[A-Za-z]` have > 1 npc_type_id.
7. Companion_data integrity: **0 stale rows** — all 5 companion_data npc_type_ids have matching npc_types rows. No orphaned companions.

### Name Normalization

All 5 recruitable NPC names confirmed:
- No trailing whitespace: YES (`name = TRIM(name)` = 1 for all)
- No mixed case quirks: standard Title_Case_With_Underscores
- Name column is `latin1_swedish_ci` (case-insensitive comparisons)
- No suffix patterns like `_002` observed for the recruitable NPCs
- Underscore-as-space: EQEmu standard convention. Lua likely uses `npc:GetName()` which returns the DB value directly.

### Multi-Variant Scope — Key Findings

| Finding | Value |
|---------|-------|
| Total npc_types rows | 67,530 |
| Total names with > 1 npc_type_id | 9,202 |
| Proper-named NPCs with > 1 npc_type_id | 3,038 |
| Recruitable NPCs with multi-variant issue | 2 of 5 (Lydl_the_Great: 4 variants; Hollish_Tnoops: 2 variants) |
| Lydl variants in freporte (same zone) | **3 variants** (10162, 10178, 10181) |
| Name + zone uniqueness for Lydl | **NOT UNIQUE** — 3 ids share freporte |
| companion_data stale npc_type_id rows | **0** |

### Recruitable NPC Name Collision Analysis

**Lydl_the_Great (4 variants):**

| npc_type_id | level | zone | hp | faction |
|-------------|-------|------|----|---------|
| 10162 | 4 | freporte, highpass | 28 | 186 |
| 10178 | 2 | freporte | 12 | 186 |
| 10181 | 3 | freporte | 20 | 186 |
| 392011 | 2 | northro | unknown | 0 |

Same race (1), same class (12), same loottable/spells/faction for 10162/10178/10181. 392011 has faction_id=0 (different). Three share freporte.

**Hollish_Tnoops (2 variants):**

| npc_type_id | level | hp | loottable_id | faction |
|-------------|-------|----|----|---------|
| 9144 | 14 | 168 | 12316 | 294 |
| 383271 | 14 | 175 | 0 | 294 |

383271 has **no spawnentry** (0 spawnentry rows). It is an **orphan npc_types row** — exists in the table but never spawns. Effectively not a real spawn concern. companion_data uses 9144.

**Other recruitable NPCs (3 of 5 are unique):**
- Jracol_Brestiage (2029): only 1 npc_type_id in the DB
- Lashun_Novashine (2032): only 1 npc_type_id in the DB
- Jimble_Woodentoe (22014): only 1 npc_type_id in the DB

### Name-Based Lookup Safety Assessment

**Name-based lookup is NOT safe for Lydl_the_Great without zone disambiguation.**

Reason: Three npc_type_ids (10162, 10178, 10181) all have `name = 'Lydl_the_Great'` AND all spawn in `freporte`. A SELECT WHERE name='Lydl_the_Great' returns 4 rows. Even adding zone filter still returns 3 rows in freporte.

**Disambiguation options considered:**

1. **Name + npc_faction_id**: 10162/10178/10181 all share faction_id=186, 392011 has faction_id=0. Faction does not disambiguate within freporte.

2. **Name + zone + npc_type_id tie-breaker**: Use lowest npc_type_id (10162) as canonical within each zone. Requires storing which variant was recruited OR always recruiting the lowest id.

3. **Name + companion_data.npc_type_id**: companion_data already stores the exact npc_type_id that was recruited. The STORED id is the truth. The problem is only on INITIAL lookup when the spawned NPC's id doesn't match the stored id — i.e., player recruited 10162 but the zone spawned 10178 this time.

4. **Keep npc_type_id with same-name fallback**: Primary lookup remains `WHERE npc_type_id=?`. If no match, secondary lookup by `WHERE name=(SELECT name FROM npc_types WHERE id=?) AND is_dismissed=1 OR is_suspended=1`. This is safer than pure name-based.

### Specific Bug Scenario Confirmed

If the player recruited Lydl when npc_type_id=10162 was spawned, `companion_data` stores `npc_type_id=10162`. On re-recruit attempt, the zone spawns npc_type_id=10178 (a different variant). The current lookup `WHERE npc_type_id=10178` finds nothing. Track 1 fails → Track 2 fires → all gates apply.

**This is the actual v2 bug.** The v1 fix (Dismiss(false)) is still correct and necessary, but even after v1, a player could be blocked on re-recruit by variant mismatch.

### Index Recommendation

`npc_types.name` is `TEXT` type — an index on a `TEXT` column in MariaDB requires a prefix length specification (e.g., `INDEX(name(100))`). Without an index, any name-based lookup performs a full table scan on 67,530 rows.

**Recommendation:** If name-based lookup is added to any hot path (e.g., re-recruit fallback), add a prefix index:
```sql
ALTER TABLE npc_types ADD INDEX idx_name_prefix (name(100));
```
This is a schema migration and requires a `database_update_manifest_custom.h` entry. Performance impact of the full scan is low at 67k rows, but the index should be added for correctness as the table grows.

### companion_data Integrity Check

All 5 current companion_data rows have valid npc_type_id FK references (no stale rows). No data cleanup needed here.

### Recommendations to Architect

1. **Name-only lookup is unsafe.** 9,202 names have multiple npc_type_ids. For Lydl specifically, 3 variants share the same zone (freporte). Name + zone is still not unique.

2. **Safe v2 approach: keep stored npc_type_id as primary, add name-based GROUP match as secondary.** The companion_data row already knows which npc_type_id was recruited. The fix should accept any variant of the same NPC name as a valid re-recruit trigger. Logic: "if the spawned NPC's name matches the name of any of my companion_data rows with the same owner_id, treat it as a re-recruit candidate." This maps N spawned variants → 1 companion_data row by name lookup.

3. **Name + npc_faction_id as disambiguation strategy.** For cases where the player has TWO different companions with the same display name but different factions (currently impossible but theoretically possible), faction can disambiguate. For Lydl, 392011 (faction=0) vs others (faction=186) provides a partial disambiguation.

4. **Hollish_Tnoops 383271 is an orphan row.** No spawnentry exists. Not a real concern for name-based lookup — it will never be in the world.

5. **Index needed if name-based lookup goes hot.** TEXT prefix index `idx_name_prefix(name(100))` should be added as a schema migration.

6. **No companion_data cleanup required** for v2 — all rows are valid.

---

## Context for Next Agent

**What was done:** Read-only DB triage of all companion-related tables. No rows modified.

**Key facts established:**
- 6 companion tables: companion_data, companion_inventories, companion_buffs, companion_exclusions, companion_culture_persuasion, companion_spell_sets
- companion_data has is_dismissed (default 0) and is_suspended (default 1) flags. No FK constraints. No UNIQUE on (owner_id, npc_type_id) — duplicate rows possible and observed.
- data_buckets cooldown key pattern: `companion_cooldown_{npc_type_id}_{char_id}` (per MEMORY, structurally consistent with soul_wipe key pattern observed in live data). Zero companion cooldown rows currently present in DB.
- All three re-recruit blockers (level cap, cooldown, dismissed flag) are 100% application-level. No DB constraints/triggers/procedures enforce any of them.
- `Companions:LevelRange=50` and `Companions:RecruitCooldownS=900` are in rule_values. The rule notes for cooldown say "after failed attempt" — may not fire on death/dismissal at all (c-expert to confirm).

**Recommended SQL operations for fix:**
1. Cooldown bypass: No DB change needed if bypass is in application code. Defensive cleanup: `DELETE FROM data_buckets WHERE key LIKE 'companion_cooldown_%'`
2. Dismissed flag: `UPDATE companion_data SET is_dismissed=0, is_suspended=0 WHERE id=? AND owner_id=?`
3. Level cap: Likely a new rule_value or C++ conditional. No schema change needed.
