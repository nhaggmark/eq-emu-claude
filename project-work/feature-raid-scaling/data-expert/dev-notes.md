# Raid Scaling — Dev Notes: data-expert

> **Feature branch:** `feature/raid-scaling`
> **Agent:** data-expert
> **Task(s):** 1, 2, 3, 4, 5, 6, 10
> **Date started:** 2026-04-22
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Create backup tables for `npc_types`, `spawn2`, `npc_spells_entries` | — | Complete (applied 2026-04-22) |
| 2 | Emit per-boss HP/damage/special_abilities UPDATE SQL | 1 | Complete (applied 2026-04-22) |
| 3 | Emit respawn-timer UPDATE SQL | 1 | Complete (applied 2026-04-22) |
| 4 | Emit `npc_spells_entries` DELETE for Cazic Touch (spell 982) | 1 | Complete (applied 2026-04-22) |
| 5 | Emit rollback script + verification queries | 2,3,4 | Complete (2026-04-22) |
| 6 | Apply SQL via `docker exec ... mysql` | 5 | Complete (2026-04-22) |
| 10 | Commit + push `claude/` repo | 6 | Complete (2026-04-22) |

---

## Stage 1: Plan

### Files Examined

| File | What You Found |
|------|----------------|
| `architect/architecture.md` | Authoritative targets for all HP/damage/respawn/special_abilities/spell changes |
| `architect/context/q13-npc-investigation.md` | 13 additional triggered/scripted NPCs for Classic scope |
| `architect/context/classic-bosses-respawns.txt` | Pre-change HP and respawn snapshot for all in-scope NPCs |
| `npc_types` (SELECT) | Verified current HP/maxdmg/special_abilities/npc_spells_id for key bosses |
| `npc_spells_entries` (SELECT) | Confirmed spell 982 exists in lists 118, 449, 969 (3 rows total) |
| `rule_values` (SELECT) | `Combat:DefaultRampageTargets=1`, `Combat:MaxRampageTargets=2` |
| hateplaneb NPCs (SELECT) | Full current stats for all 35 hateplaneb raid_target bosses |
| cazicthule event NPCs (SELECT) | Confirmed 48211, 48237, 48239, 48240, 48245-48252 all exist |

### Key Findings

1. **Cazic Thule rampage — NO EDIT NEEDED.** Architecture addendum raised a concern about param indexing. Investigation confirmed: `Combat:DefaultRampageTargets=1` and `Combat:MaxRampageTargets=2` are both already set server-wide. CT's string `3,1,10` has param0=10 but `GetSpecialAbilityParam(Rampage, 1)` reads param index 1 (unset=0), so CT falls through to DefaultRampageTargets=1, capped at MaxRampageTargets=2. CT's effective rampage target count is already ≤2. The `3,1,10` edit to `3,1,3` would change param0 only (unused by rampage AI). **Phase 2 action: leave CT's special_abilities string as-is; document that global cap is sufficient.**

2. **Innoruuk (186158) has same `3,1,10` rampage pattern.** Same logic applies — leave as-is.

3. **hateplaneb DZ bosses.** Most have respawn 900s (DZ-internal). Three exceptions: 186025 at 70308s, 186183 at 194400s, 186189 at 10800s. Per architecture, only 194400s outliers get cut to 21600s; 900s timers stay; 70308s and 10800s timers are borderline — architecture says "leave DZ timers alone" so only 186183 (194400s) gets reduced.

4. **Backup tables don't exist yet** — confirmed via information_schema query.

5. **All cazicthule event NPC IDs confirmed** in DB. Architecture sketch had ranges 48245-48252 — all 8 IDs exist.

6. **PoSky NPCs with NULL respawntime** (71034, 71059, 71060, 71071, 71072, 71075, 71076) have no spawn2 row — confirmed by NULL in respawn data. Their JOIN-based respawn UPDATE will silently skip them (intended per architecture).

7. **Eye of Veeshan (71065)** already has respawn 21600s in respawns.txt — respawn UPDATE is a no-op for it but harmless to include.

### Implementation Plan

Three SQL files:
- `01-backup-tables.sql` — CREATE TABLE AS SELECT for all three tables
- `02-implementation.sql` — all UPDATEs, DELETEs, verification queries
- `03-rollback.sql` — transactional rollback script using backup tables

Apply order: 01 → 02. Keep 03 as emergency rollback.

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `CREATE TABLE ... AS SELECT` | MariaDB standard (confirmed by prior pass pattern) | Yes | Same pattern as `npc_types_backup_sgs` from 2026-02-23 |
| JOIN-based UPDATE syntax | MariaDB standard — `UPDATE t1 JOIN t2 ON ... SET t1.col = val WHERE ...` | Yes | Used in architecture sketch |
| `Combat:DefaultRampageTargets` / `Combat:MaxRampageTargets` | rule_values SELECT | Yes | Both confirmed in DB |
| special_abilities CT string | npc_types SELECT | Yes | `1,1^2,1^3,1,10^7,1^...` — param0=10 confirmed unused by rampage AI |
| npc_spells_entries spell 982 | SELECT verified | Yes | Exactly 3 rows across lists 118, 449, 969 |

### Plan Amendments

**CT rampage edit removed from scope.** Architecture's Addendum recommended data-expert verify and either pin or document. After verifying that `Combat:DefaultRampageTargets=1` and `Combat:MaxRampageTargets=2` are both set, the per-NPC edit provides no additional benefit. Recording this as a resolved decision.

**Innoruuk (186158) rampage string** also `3,1,10` — same conclusion: no edit needed.

---

## Stage 3: Socialize

Since this is 100% SQL with no cross-system dependencies (no C++, no Lua, no Perl per architecture), and the architecture doc was produced with config-expert, protocol-agent, and architect input, no additional socialization is required before build. The consensus plan is the architecture doc itself.

---

## Stage 4: Build

### Implementation Log

#### 2026-04-22 — Backup tables created and applied (Task 1)

**What:** Created `npc_types_backup_raid_scaling`, `spawn2_backup_raid_scaling`, `npc_spells_entries_backup_raid_scaling` via `01-backup-tables.sql`.
**Where:** `data-expert/sql/01-backup-tables.sql` applied to `peq` DB.
**Why:** Mandatory pre-change gate per architecture. Row counts verified.
**Row counts:**
- `npc_types_backup_raid_scaling`: 2548 rows (over-captures all era raid_target=1 L45-70 rows — intentional for Phase 3/4/5 rollback coverage)
- `spawn2_backup_raid_scaling`: 6669 rows (same over-capture)
- `npc_spells_entries_backup_raid_scaling`: 6 rows (all entries for lists 118, 449, 969)
- Cazic Touch (spell 982) captured: 3 rows confirmed

#### 2026-04-22 — HP/damage/respawn/death-touch SQL applied (Tasks 2-4)

**What:** Applied all Phase 2 changes via `02-implementation.sql`:
- ~49 npc_types HP/damage UPDATEs (PoFear, PoHate classic, hateplaneb, PoSky, Nagafen/Vox/Phinigel, cazicthule event mobs, misc Classic)
- ~40 spawn2 respawntime UPDATEs (6h for low-tier; 12h for CT, Guardian of Seal; hateplaneb 194400s outlier 186183 cut to 21600)
- 3 npc_spells_entries DELETEs (spell 982 from lists 118, 449, 969)
**Where:** `data-expert/sql/02-implementation.sql` applied to `peq` DB.
**Verification output (all passed):**

| Check | Expected | Actual |
|-------|----------|--------|
| Nagafen HP | 14400 | 14400 |
| Vox HP | 14400 | 14400 |
| Phinigel HP | 13500 | 13500 |
| CT HP | 80000 | 80000 |
| CT maxdmg | 450 | 450 |
| CT special_abilities | unchanged (3,1,10) | `1,1^2,1^3,1,10^7,1^...` — confirmed unchanged |
| dracoliche HP | 40000 | 40000 |
| dracoliche maxdmg | 420 | 420 |
| Dread/Terror/Fright HP | 20000 | 20000 |
| Wraith of Shissar HP | 17500 | 17500 |
| Tempest Reaver HP | 21000 | 21000 |
| Ireblind Imp HP | 35000 | 35000 |
| Enraged Golem HP | 40000 | 40000 |
| Enraged Imp HP | 18000 | 18000 |
| Innoruuk classic HP | 20000 | 20000 |
| Innoruuk classic maxdmg | 300 | 300 |
| Maestro HP | 14600 | 14600 |
| Innoruuk revamp HP | 60000 | 60000 |
| Innoruuk revamp maxdmg | 500 | 500 |
| Evangelist of Hate HP | 60000 | 60000 |
| Evangelist of Hate maxdmg | 600 | 600 |
| Spiroc Lord HP | 22000 | 22000 |
| Keeper of Souls HP | 22000 | 22000 |
| Bazzt Zzzt HP | 22000 | 22000 |
| Bazzt Zzzt maxdmg | 700 | 700 |
| Eye of Veeshan HP | 25600 | 25600 |
| essence tamer HP | 11500 unchanged | 11500 |
| Cazic Touch rows (expect 0) | 0 | 0 |
| Remaining entries 118/449/969 | 3 | 3 |
| Nagafen respawn | 21600 | 21600 |
| CT respawn | 43200 | 43200 |
| Guardian of Seal respawn | 43200 | 43200 |
| PoHate council respawn (76017) | — | 21600 (was 1440; updated to 6h per Decision #8 low-tier — verification comment expected 1440 but council ARE in the 21600 update list, this is correct) |

**Anomaly note:** The SQL verification comment for PoHate council (76017) said "expect 1440" — but the implementation correctly included them in the 6h respawn update (they are Classic raid bosses subject to Decision #8 low-tier 6h target). The comment was wrong; the SQL is correct.

#### 2026-04-22 — Rollback script written (Task 5)

**What:** `03-rollback.sql` written. Transactional UPDATE…JOIN from backup tables for npc_types and spawn2; INSERT IGNORE for the 3 Cazic Touch rows in npc_spells_entries.

### Files Created

| File | Description |
|------|-------------|
| `data-expert/sql/01-backup-tables.sql` | Pre-change backup tables (CREATE TABLE AS SELECT) |
| `data-expert/sql/02-implementation.sql` | All UPDATEs and DELETEs + verification queries |
| `data-expert/sql/03-rollback.sql` | Emergency rollback using backup tables |

---

## Open Items

- [ ] CT rampage param0 cleanup — Decision: leave as-is. `3,1,10` param0 is unused; global cap is sufficient. Logged for Phase 3/future cleanup if desired.

---

## Phase 3 Kunark — Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| K1 | Create Kunark backup tables | — | Complete (applied 2026-04-22) |
| K2 | Emit Kunark HP/damage UPDATE SQL | K1 | Complete (applied 2026-04-22) |
| K3 | Emit Kunark respawn UPDATE SQL | K1 | Complete (applied 2026-04-22) |
| K4 | Emit Kunark rollback script | K2,K3 | Complete (2026-04-22) |
| K5 | Apply all SQL changes | K1-K4 | Complete (2026-04-22) |
| K6 | Commit + push claude/ repo | K5 | In Progress |

---

## Phase 3 Kunark — Stage 1: Plan

### DB State Confirmed (pre-apply SELECT queries)

All Kunark bosses verified at PEQ default values before any changes:

| NPC | ID | Pre-change HP | Pre-change maxdmg | Pre-change respawn |
|-----|----|---------------|-------------------|-------------------|
| Gorenaire | 86014 | 32000 | 500 | 194400s (54h) |
| Severilous | 94009 | 32000 | 500 | 194400s |
| Talendor | 91093 | 32000 | 500 | 194400s |
| Faydedar | 96089 | 32000 | 236 | 194400s |
| #Faydedar | 96073 | 32000 | 236 | no spawn2 |
| Trakanon | 89154 | 32000 | 630 | 194400s |
| #Trakanon | 89181 | 16000 | 473 | no spawn2 |
| #Venril_Sathir | 102112 | 22000 | 404 | 194400s (spawn2 exists) |
| Drusella_Sathir | 105153 | 15750 | 310 | 194400s |
| Queen Velazul | 103055 | 30000 | 220 | 5400s (1.5h) |
| Overking Bathezid | 103056 | 34500 | 320 | 5400s |
| Prince Selrach | 103080 | 25000 | 250 | 5400s |
| Kilidna | 90186 | 100000 | 4600 | 5400s |
| Lhranc | 90093 | 19000 | 305 | 49215s (~13.67h) |
| Druushk | 108040 | 470000 | 1567 | 291232s, cond=2 |
| Guardian of Veeshan | 108042 | 600000 | 1273 | 164895s, cond=2 |
| Hoshkar | 108043 | 536000 | 1603 | 290001s, cond=2 |
| Nexona | 108047 | 800000 | 2475 | 269232s, cond=2 |
| Phara Dar | 108048 | 681000 | 1621 | 291232s, cond=2 |
| Silverwing | 108050 | 454000 | 1295 | 281232s, cond=2 |
| Xygoz | 108053 | 814000 | 2266 | 271232s, cond=2 |
| VP classic (108509-108517) | — | 144-191k | — | 64800-86400s, cond=1 |
| #Renux_Herkanor | 448200 | 500000 | 1605 | no spawn2 |

**VP condition state confirmed:** condition=2 (VeeshanNew) = live. Condition=1 (VeeshanOld) = dormant.
**Backup tables did not exist** before this phase — confirmed via SHOW TABLES.

### User decisions applied
- Q21 = Option A: Chardok Royals respawn stays at 5400s (1.5h). No spawn2 UPDATE.
- Q22 = Option A: Renux Herkanor 448200 in scope. Applied HP cut 500k → 120k.

---

## Phase 3 Kunark — Stage 4: Build

### Implementation Log

#### 2026-04-22 — Kunark backup tables created (Task K1)

**What:** Created `npc_types_backup_raid_scaling_kunark` and `spawn2_backup_raid_scaling_kunark` via `04-kunark-backup-tables.sql`.
**Row counts:**
- `npc_types_backup_raid_scaling_kunark`: 28 rows (expected 27 — one extra row, harmless over-capture)
- `spawn2_backup_raid_scaling_kunark`: 25 rows
- VP condition split: condition=1 (6 rows), condition=2 (7 rows) — confirmed correct

#### 2026-04-22 — Kunark HP/damage/respawn SQL applied (Tasks K2-K3)

**What:** Applied all Phase 3 changes via `05-kunark-implementation.sql`.

**npc_types UPDATEs applied:**

| NPC | ID | HP old→new | Damage old→new |
|-----|----|-----------|----------------|
| Gorenaire | 86014 | 32000→22000 | maxdmg 500→400 |
| Severilous | 94009 | 32000→22000 | maxdmg 500→400 |
| Talendor | 91093 | 32000→22000 | maxdmg 500→400 |
| Faydedar | 96089 | 32000→19000 | unchanged |
| #Faydedar | 96073 | 32000→19000 | unchanged |
| Trakanon | 89154 | 32000→22000 | unchanged |
| #Trakanon | 89181 | 16000 (NO CHANGE) | — |
| #Venril_Sathir | 102112 | 22000→16500 | maxdmg 404→365 |
| Drusella_Sathir | 105153 | 15750 (NO CHANGE) | — |
| Queen Velazul | 103055 | 30000→24000 | unchanged |
| Overking Bathezid | 103056 | 34500→26000 | unchanged |
| Prince Selrach | 103080 | 25000 (NO CHANGE) | — |
| Kilidna | 90186 | 100000→30000 | mindmg 700→300, maxdmg 4600→1000 |
| Lhranc | 90093 | 19000 (NO CHANGE) | — |
| Xygoz | 108053 | 814000→120000 | maxdmg 2266→900 |
| Nexona | 108047 | 800000→120000 | maxdmg 2475→1000 |
| Phara Dar | 108048 | 681000→120000 | mindmg 1032→450, maxdmg 1621→750 |
| Guardian of Veeshan | 108042 | 600000→120000 | mindmg 380→230, maxdmg 1273→750 |
| Hoshkar | 108043 | 536000→110000 | maxdmg 1603→800 |
| Druushk | 108040 | 470000→95000 | maxdmg 1567→780 |
| Silverwing | 108050 | 454000→90000 | mindmg 554→332, maxdmg 1295→777 |
| #Renux_Herkanor | 448200 | 500000→120000 | maxdmg 1605→900 |
| VP classic 108509-108517 | — | NO CHANGE | — |

**spawn2 UPDATEs applied:**

| NPC | ID | Respawn old→new |
|-----|----|-----------------|
| Gorenaire | 86014 | 194400→43200 (12h) |
| Severilous | 94009 | 194400→43200 |
| Talendor | 91093 | 194400→43200 |
| Faydedar | 96089 | 194400→43200 |
| Trakanon | 89154 | 194400→43200 |
| Drusella_Sathir | 105153 | 194400→43200 |
| #Venril_Sathir spawn2 | 102112 | 194400→43200 |
| VP revamp (7) | cond=2 | ~270k-291k→43200 |
| Kilidna | 90186 | 5400→21600 (6h) |
| Lhranc | 90093 | 49215 (NO CHANGE) |
| Chardok Royals | 103055/056/080 | 5400 (NO CHANGE, Q21=A) |
| VP classic (6) | cond=1 | 64800-86400 (NO CHANGE) |

**All 43 verification checks passed.** Critical VP condition filter confirmed:
- Only condition=2 VP rows have respawntime=43200 (7 rows)
- Condition=1 VP rows untouched (min 56250s / max 86400s, unchanged)

#### 2026-04-22 — Rollback script written (Task K4)

**What:** `06-kunark-rollback.sql` written. Transactional UPDATE…JOIN from `_kunark` backup tables for npc_types and spawn2.

### Files Created

| File | Description |
|------|-------------|
| `data-expert/sql/04-kunark-backup-tables.sql` | Pre-change Kunark backup tables |
| `data-expert/sql/05-kunark-implementation.sql` | All UPDATEs + verification queries |
| `data-expert/sql/06-kunark-rollback.sql` | Emergency rollback using Kunark backup tables |

---

## Context for Next Agent

Phase 3 Kunark SQL is complete. Two new backup tables exist: `npc_types_backup_raid_scaling_kunark` (28 rows) and `spawn2_backup_raid_scaling_kunark` (25 rows).

**config-expert** needs to run `#reloadworld` and smoke-verify a representative sample of Kunark bosses (Trakanon, Nexona, Phara Dar, Severilous, Kilidna, Chardok royals).

Key confirmed post-apply values:
- Trakanon (89154): hp=22000, respawn=43200
- Nexona (108047): hp=120000, maxdmg=1000, respawn=43200 (cond=2 only)
- Kilidna (90186): hp=30000, mindmg=300, maxdmg=1000, respawn=21600
- Chardok Royals: HP trimmed, respawn stays at 5400s (Q21=Option A)
- VP classic variants: hp/respawn UNCHANGED
- #Renux_Herkanor (448200): hp=120000, maxdmg=900

---

## BUG-001 Fix — Phase 4a Tunare Combat Boss (2026-04-23)

**Bug:** Phase 4a implementation targeted NPC 127001 (`#_Tunare`, passive trigger in tree) instead of NPC 127098 (`#Tunare`, actual killable combat boss spawned via `eq.spawn2(127098,...)`). NPC 127098 was left at 530,000 HP.

**Fix applied:**

1. Inserted pre-change row for 127098 into `npc_types_backup_raid_scaling_velious_a` (9-column slim backup, hp=530000 captured).
2. `UPDATE npc_types SET hp = 150000 WHERE id = 127098;` — consistent with Phase 4a Velious mid-tier target (Yelinak 110k, Tormax 100k; 150k is upper-mid which matches Tunare's lore stature).
3. `#reloadworld` issued via world telnet port 9000. Response: "Reloading World..."
4. No spawn2 change needed — 127098 has no spawn2 row; always script-spawned by 127001's event_combat handler.

**Verification:**
- `npc_types_backup_raid_scaling_velious_a` WHERE id=127098: 1 row, hp=530000 (pre-change captured)
- `npc_types` WHERE id=127098: hp=150000, maxdmg=926, raid_target=1 (fix confirmed)

**SQL file:** `data-expert/sql/09-bug-001-tunare-fix.sql`

**Architecture sanity check:** 150k is consistent with the architect's stated target for Tunare in `velious-a-architecture.md` (same value applied to 127001). Velious mid-tier context: King Tormax 100k, Lord Yelinak 110k, Tunare 150k. No flag needed.
