# Companion Re-recruitment Fix — Dev Notes: data-expert

> **Feature branch:** `bugfix/companion-rerecruit`
> **Agent:** data-expert
> **Task(s):** Task #3 — Data layer triage for re-recruit blockers
> **Date started:** 2026-04-27
> **Current stage:** Stage 3 (Socialize — follow-up complete, awaiting architecture.md)

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

### Consensus Plan

(Pending architecture.md — architect has all data needed to finalize)

---

## Stage 4: Build

(Not started — planning phase only per task instructions)

---

## Open Items

- [ ] Confirm with c-expert: when exactly is the data_buckets cooldown row written? On failed recruit? On any dismissal? On death?
- [ ] Confirm with c-expert: does the level-range check use Companions:LevelRange directly or is there a separate re-recruit code path?
- [ ] Architect to decide: new rule_value for re-recruit level bypass, or C++ conditional bypass?
- [ ] Duplicate companion_data rows (same owner_id + npc_type_id): confirm with architect whether the re-recruit path targets a specific row by id or queries by owner+npc_type_id, and whether stale duplicate rows should be cleaned up as part of this fix.

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
