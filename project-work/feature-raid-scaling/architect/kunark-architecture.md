# Raid Scaling — Architecture & Implementation Plan (Phase 3: Kunark)

> **Feature branch:** `feature/raid-scaling`
> **PRD:** `game-designer/prd.md`
> **Audit:** `game-designer/raid-scaling-audit.md` (Kunark section lines 935-1190)
> **Lore catalog:** `lore-master/kunark-chains.md`
> **Phase 2 reference:** `architect/architecture.md` (Classic)
> **DB investigation:** `architect/context/kunark-db-investigation.md`
> **Author:** architect
> **Date:** 2026-04-22
> **Status:** Draft — ready for implementation pending two user decisions (see "Items flagged to user" section)
> **Scope:** **Phase 3 (Kunark) ONLY.** Trakanon (standard + triggered), Veeshan's Peak (7 revamp dragons), outdoor Kunark dragons (Gorenaire, Severilous, Talendor, Faydedar), Sebilis & Karnor's Castle bosses (Venril Sathir, Drusella), Chardok Royals, City of Mist (Kilidna, Lhranc), plus Kunark-era Q13 NPC resolution.

---

## Executive Summary

Phase 3 scales Kunark raid content using the **same 100% SQL pattern established in Phase 2**: `npc_types` UPDATEs for HP/damage, `spawn2` UPDATEs for respawn timers, plus backup tables for rollback. Kunark differs from Classic in two significant ways:

1. **Veeshan's Peak has dual NPC populations.** Revamp variants (108040-108053, L70, 454-814k HP) are the live encounters — confirmed via `spawn_condition_values` (condition 2 "VeeshanNew" = 1 enabled). Classic-era variants (108509-108517, L65-67, 144-192k HP) are dormant (condition 1 "VeeshanOld" = 0 disabled). Per Decision #5 we scale only the revamp variants; classic variants stay dormant but are captured in the backup table for safety.

2. **No death-touch spells to remove.** DB audit for free-cast instakill spells (0 mana, 0 cast time, damage < -10,000) across all Kunark raid bosses returned zero rows. The highest-damage direct-damage spell is Nexona's "Dragon Harm Touch" at -4,000 HP (45s recast). No `npc_spells_entries` DELETE needed for Phase 3.

**Change footprint:**
- ~20 `npc_types` UPDATEs (outdoor dragons, Sebilis/Karnor bosses, Chardok royals, City of Mist pair, 7 VP revamp dragons, triggered Trakanon, weak Faydedar variant)
- ~14 `spawn2` UPDATEs (only where an active spawn2 row exists for a raid_target NPC; script-spawned variants with no spawnentry silently skip)
- **0** `npc_spells_entries` changes
- Backup tables: reuse Phase 2 naming convention with `_kunark` suffix

**No C++ changes. No rule_values changes. No Lua/Perl script changes. No `eqemu_config.json` changes.**

Protocol-agent confirmed zero client-visibility impact (same as Phase 2). Config-expert confirmed no new rules or config levers since Phase 2 apply (2026-04-22), and that Kunark mid-tier 12h respawn (Decision #5) is the correct target for Trakanon, VP, and outdoor dragons.

Two items require user decision before implementation (see below): Chardok Royals respawn direction (currently 1.5h, shorter than the 12h mid-tier target), and whether to include Renux Herkanor 448200 (L72 500k HP, script-spawned Monk epic terminus — exceeds the 55-70 in-era band).

---

## Existing System Analysis

### Current State

**Phase 2 Classic scaling landed 2026-04-23** and user validated Lady Vox in-game. Prior-pass globals remain authoritative:
- `NPCFlurryChance=12`, `MaxRampageTargets=2`, `NPCAssistCap=3`, `StartEnrageValue=5`, `GlobalLootMultiplier=2`
- `rule_values` count: 1,112 (unchanged since Phase 2). No Kunark-specific rules exist.
- No zone-scoped rules — `zone.ruleset=1` (default) applies to all Kunark zones.

**Kunark raid content at PEQ defaults.** Per game-designer audit and DB confirmation:
- 4 outdoor dragons at 32k HP, 54h respawn
- Trakanon at 32k HP, 54h respawn
- Venril Sathir (triggered form) at 22k HP, 54h respawn (but triggered — no active spawn2)
- 3 Chardok royals at 25-34.5k HP, **already 1.5h respawn** (unusually short for raid tier)
- Kilidna at 100k HP with catastrophic 4,600 max damage (1.5h respawn)
- Lhranc at 19k HP (13.67h respawn — already in target range)
- 7 VP revamp dragons at 454-814k HP, 75-81h respawn
- Guardian of the Seal (39115): **already scaled in Phase 2** (HP 87k, 12h respawn). No Phase 3 action.

**Live vs dormant VP variants:**
- `spawn_condition_values`: condition 1 VeeshanOld=0 (disabled), condition 2 VeeshanNew=1 (enabled)
- Revamp variants (108040-108053) use `_condition=2` → live
- Classic-era variants (108509-108517) use `_condition=1` → dormant
- Per Decision #5: keep revamp variants, scale down deeply

**Relevant topography:**
- `claude/docs/topography/SQL-CODE.md` — npc_types, spawn2, spawnentry, spawngroup chain
- `zone/mob.cpp:7572-7620` — `Mob::ProcessSpecialAbilities()` CSV parser
- `zone/mob_ai.cpp` — `NPC::AICastSpell()` with in-memory spell list populated at NPC spawn
- `common/emu_constants.h:527-591` — SpecialAbility enum

### Gap Analysis

| Gap | Lever |
|-----|-------|
| 7 VP revamp dragons at 454-814k HP (11-27× scaled-named L70 target ~30k) | `npc_types.hp` 80-85% cut per audit |
| 3 VP dragons with one-shot damage (Nexona 2,475 max, Xygoz 2,266 max, Phara Dar 1,621 max) | `npc_types.maxdmg` 40-60% cut |
| 4 outdoor dragons at 32k HP / 54h respawn (2× scaled-named, 9× target respawn) | HP 30% cut, damage trim on some, respawn → 12h |
| Trakanon 32k HP / 54h (1.5× scaled-named but signature flurry + rampage) | HP 30% cut, respawn → 12h, keep special_abilities as-is per Decision #11 |
| Triggered Trakanon (#Trakanon 89181) at 16k HP (already near named-tier) | Minimal / no HP change; apply consistent damage/respawn treatment |
| Triggered Venril Sathir (#Venril_Sathir 102112) at 22k HP | 25% HP cut per audit; no spawn2 update (script-spawned) |
| Chardok Royals 25-34.5k HP, **already 1.5h respawn** | HP trim 20-25%. Respawn direction: **USER DECISION NEEDED.** |
| Kilidna 100k HP / **4,600 max damage = one-shot hazard** | HP 70% cut, **damage 75% cut to ~1,000** — per Decision #11 "scale HP/damage" guidance |
| Lhranc 19k HP / 13.67h respawn — already close to named tier, respawn in range | Minimal / no HP change. Respawn already fits |
| Drusella Sathir 15,750 HP — already named-tier | No HP change or 10% cut |
| Faydedar duplicate #Faydedar 96073 at 32k HP (script-spawned, no spawnentry) | Same 40% HP cut as main Faydedar for consistency |
| VP classic-era variants (108509-108517) dormant | **No scaling needed** — they don't spawn. Backup only for safety over-capture. |

### What is NOT gap for Phase 3

- **No C++ changes.** Same rationale as Phase 2.
- **No rule_values changes.** No config-expert finding requires rule edits.
- **No Lua/Perl script changes.** Triggered Trakanon and triggered VS are spawned by quest scripts that read `npc_types` values at spawn time — scripts don't encode HP.
- **No loot table changes.** Per Decision #3.
- **No npc_spells_entries changes.** Zero death-touch-profile spells found in Kunark raid boss spell lists.
- **No spawn_conditions changes.** VeeshanOld/VeeshanNew flags remain as-is.
- **Phase 2 already handled Guardian of the Seal 39115 (hole, L70, 87k HP, 12h respawn).** No Phase 3 action on The Hole SK-epic NPCs — per Q13 they're all named-tier already.

---

## Technical Approach

### Architecture Decision

**Every Phase 3 change is a database UPDATE.** Per the layer priority (rules > config > Lua > SQL > C++):

1. **Rules — NOT APPLICABLE.** Same reasoning as Phase 2. Config-expert confirmed no new rules.
2. **Config (eqemu_config.json / .env) — NOT APPLICABLE.** Same reasoning as Phase 2.
3. **Lua/Perl scripts — NOT APPLICABLE.** Script-spawned NPCs read `npc_types` at spawn time; scripts contain no HP/damage literals.
4. **SQL — YES.** All changes target `npc_types` and `spawn2`. No `npc_spells_entries` changes for Phase 3.
5. **C++ — NOT APPLICABLE.** No engine change needed.

### Component Change Table

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `npc_types.hp` (~20 Kunark bosses) | UPDATE per-NPC | Audit targets vary 0-85% cut; per-NPC precision required |
| `npc_types.maxdmg` (VP dragons + Kilidna) | UPDATE per-NPC | One-shot-risk bosses need damage caps |
| `npc_types.mindmg` (Kilidna) | UPDATE per-NPC | 700 min → 300 (proportional scale-down) |
| `spawn2.respawntime` (~14 Kunark raid-boss spawns with active spawn2 rows) | UPDATE per-spawn | Target 12h per Decision #5 for mid-tier (Trakanon/VP/outdoor dragons); 6h for Kilidna/Lhranc (damage outlier & already-near-target); Chardok Royals TBD per user decision |
| `npc_types.special_abilities` | **NO CHANGE** | Decision #11 preserves signature mechanics. No CSV edits needed. |
| `npc_spells_entries` | **NO CHANGE** | No death-touch-profile spell found in Kunark raid bosses |
| Backup tables `npc_types_backup_raid_scaling_kunark`, `spawn2_backup_raid_scaling_kunark` | CREATE + INSERT-SELECT | Kunark-specific snapshot; mirrors Phase 2 `_raid_scaling` pattern with `_kunark` suffix |
| `rule_values` | NO CHANGE | Confirmed by config-expert |
| `eqemu_config.json` | NO CHANGE | Same as Phase 2 |
| Lua/Perl scripts | NO CHANGE | None control HP/damage/respawn |
| C++ source | NO CHANGE | N/A |

### Data Model

#### Backup tables (captured BEFORE any other change)

Phase 2 already created `npc_types_backup_raid_scaling`, `spawn2_backup_raid_scaling`, and `npc_spells_entries_backup_raid_scaling` with an intentional over-capture `WHERE nt.level BETWEEN 45 AND 70`. This over-capture **already covers every Kunark NPC we're touching in Phase 3**.

**Decision: create Phase 3-specific backup tables scoped tightly to just the Kunark NPC IDs we are UPDATE-ing.** This gives a precise rollback target for Phase 3 without polluting the Phase 2 backup tables. Naming mirrors Phase 2 with `_kunark` suffix.

```sql
CREATE TABLE npc_types_backup_raid_scaling_kunark AS
SELECT id, hp, mindmg, maxdmg, AC, special_abilities, npcspecialattks
FROM npc_types
WHERE id IN (
    -- Outdoor dragons
    86014, 94009, 91093, 96089, 96073,
    -- End-dungeon bosses
    89154, 89181, 102112, 105153,
    -- Chardok royals
    103055, 103056, 103080,
    -- City of Mist
    90186, 90093,
    -- VP revamp (live)
    108040, 108042, 108043, 108047, 108048, 108050, 108053,
    -- VP classic (dormant, backup for safety)
    108509, 108510, 108511, 108512, 108513, 108517
);
-- Expected rows: 26

CREATE TABLE spawn2_backup_raid_scaling_kunark AS
SELECT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance, s2._condition, s2.cond_value
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID IN (
    86014, 94009, 91093, 96089,
    89154, 105153,
    103055, 103056, 103080,
    90186, 90093,
    108040, 108042, 108043, 108047, 108048, 108050, 108053,
    108509, 108510, 108511, 108512, 108513, 108517
);
-- Expected rows: ~20 (triggered bosses like 102112, 89181, 96073 have no spawn2)
```

#### Phase 3 change sketch (data-expert emits final SQL; these are authoritative targets from audit)

**Outdoor dragons (Decision: 30-40% HP cut, damage trim on 3 of 4, 12h respawn):**

```sql
UPDATE npc_types SET hp = 22000, maxdmg = 400 WHERE id = 86014;  -- Gorenaire 32k→22k, 500→400
UPDATE npc_types SET hp = 22000, maxdmg = 400 WHERE id = 94009;  -- Severilous 32k→22k
UPDATE npc_types SET hp = 22000, maxdmg = 400 WHERE id = 91093;  -- Talendor 32k→22k
UPDATE npc_types SET hp = 19000 WHERE id = 96089;                 -- Faydedar 32k→19k (40% cut, damage already low)
UPDATE npc_types SET hp = 19000 WHERE id = 96073;                 -- #Faydedar weak variant (consistency)
```

**End-dungeon bosses (30% HP cut; Trakanon damage stays per audit; triggered Trakanon minimal):**

```sql
UPDATE npc_types SET hp = 22000 WHERE id = 89154;  -- Trakanon 32k→22k (keep SERFMCNDf + flurry per Decision #11; global MaxRampageTargets=2 already caps rampage)
UPDATE npc_types SET hp = 16000 WHERE id = 89181;  -- #Trakanon triggered (16k stays — already named-tier per audit)
UPDATE npc_types SET hp = 16500, maxdmg = 365 WHERE id = 102112;  -- #Venril_Sathir triggered 22k→16.5k, 404→365
-- Drusella Sathir 105153 already at 15,750 HP — no change (named-tier per audit)
```

**Chardok royals (HP trim 10-25%; RESPAWN DIRECTION TBD):**

```sql
UPDATE npc_types SET hp = 26000 WHERE id = 103056;  -- Overking Bathezid 34.5k→26k (25% cut)
UPDATE npc_types SET hp = 24000 WHERE id = 103055;  -- Queen Velazul 30k→24k (20% cut)
-- Prince Selrach 103080: no HP change (already near named-tier per audit)
```

**City of Mist:**

```sql
UPDATE npc_types SET hp = 30000, mindmg = 300, maxdmg = 1000 WHERE id = 90186;  -- Kilidna 100k→30k, 700-4600→300-1000 (critical one-shot fix)
-- Lhranc 90093: no HP change (already near named-tier, respawn already 13.67h)
```

**VP revamp (the headline fight — 80-85% HP cuts, 40-60% damage cuts; level stays at 70):**

```sql
UPDATE npc_types SET hp = 120000, maxdmg = 900 WHERE id = 108053;   -- Xygoz 814k→120k, 2266→900
UPDATE npc_types SET hp = 120000, maxdmg = 1000 WHERE id = 108047;  -- Nexona 800k→120k, 2475→1000
UPDATE npc_types SET hp = 120000, mindmg = 450, maxdmg = 750 WHERE id = 108048;  -- Phara Dar 681k→120k, 1032-1621→450-750
UPDATE npc_types SET hp = 120000, mindmg = 230, maxdmg = 750 WHERE id = 108042;  -- Guardian of Veeshan 600k→120k, 380-1273→230-750
UPDATE npc_types SET hp = 110000, maxdmg = 800 WHERE id = 108043;   -- Hoshkar 536k→110k, 1603→800
UPDATE npc_types SET hp = 95000, maxdmg = 780 WHERE id = 108040;    -- Druushk 470k→95k, 1567→780
UPDATE npc_types SET hp = 90000, mindmg = 332, maxdmg = 777 WHERE id = 108050;  -- Silverwing 454k→90k, 554-1295→332-777 (40% cuts)
```

**Respawn timers (12h = 43,200s for Kunark mid-tier per Decision #5):**

```sql
-- Outdoor dragons, Trakanon, Sebilis, Karnor's: 12h
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID IN (86014, 94009, 91093, 96089, 89154, 105153);

-- VP revamp: 12h (per Decision #5)
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 43200
WHERE se.npcID IN (108040, 108042, 108043, 108047, 108048, 108050, 108053)
  AND s2._condition = 2;  -- scope to live VP only (VeeshanNew)

-- Kilidna: 6h (damage outlier, keep accessible for Paladin/SK epic navigation)
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 21600
WHERE se.npcID = 90186;

-- Lhranc 90093: leave at 13.67h (already near target; signature Paladin/SK epic boss)
-- Chardok Royals 103055, 103056, 103080: CURRENTLY 1.5h. NEED USER DECISION (see below).
```

### Code Changes

No code changes. Zero files modified in `eqemu/`, `akk-stack/server/quests/`, or `akk-stack/npc-llm-sidecar/`.

### Configuration Changes

No `rule_values` changes. No `eqemu_config.json` changes. No `.env` changes.

### Database Changes

| File path | Type | Rows affected (approx) |
|-----------|------|------------------------|
| `npc_types_backup_raid_scaling_kunark` | CREATE TABLE AS SELECT | 26 rows snapshot |
| `spawn2_backup_raid_scaling_kunark` | CREATE TABLE AS SELECT | ~20 rows snapshot |
| `npc_types` | UPDATE | ~20 rows |
| `spawn2` | UPDATE | ~14 rows (depends on Chardok Royals decision) |
| `npc_spells_entries` | NO CHANGE | 0 rows |

Data-expert should produce a single SQL reference document at
`data-expert/context/phase3-kunark-implementation.sql` with:
1. Backup table creates first.
2. All UPDATEs ordered by zone cluster (outdoor dragons → Sebilis → Karnor → Chardok → CoM → VP).
3. Post-change verification queries (assert HP bounds, count changed rows, confirm VP only touches `_condition=2` rows).
4. Full rollback script using backup tables.

---

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Build backup tables `npc_types_backup_raid_scaling_kunark` and `spawn2_backup_raid_scaling_kunark`; verify row counts (26 and ~20); emit SQL reference doc structure | data-expert | — | ~30m |
| 2 | Emit per-boss HP/damage UPDATE SQL for 20 Kunark bosses (outdoor dragons, Sebilis/Karnor, Chardok royals, City of Mist, VP revamp 7); cross-check with audit targets; commit to `data-expert/context/phase3-kunark-implementation.sql` | data-expert | 1 | ~1.5h |
| 3 | Emit respawn-timer UPDATE SQL (12h for Trakanon/VP/outdoor dragons; 6h for Kilidna; Chardok Royals per user decision); scope VP UPDATE to `_condition=2` only | data-expert | 1 | ~30m |
| 4 | Emit rollback script (INSERT … SELECT from backup tables, transactional) + verification queries comparing row counts before/after | data-expert | 2,3 | ~20m |
| 5 | Apply all SQL changes via `docker exec akk-stack-mariadb-1 mysql -ueqemu -p'…' peq < phase3-kunark-implementation.sql`; capture before/after row counts and diff stats | data-expert | 4 | ~15m |
| 6 | `#reloadworld` via Spire or world telnet port 9000 so zone processes re-load modified `npc_types` and `spawn2` caches | config-expert | 5 | ~5m |
| 7 | Smoke verification: run SQL queries confirming Trakanon HP, Nexona HP+damage, Phara Dar stats, Gorenaire respawn, Kilidna damage cap, VP revamp only (condition=2) touched; document findings in config-expert notes | config-expert | 6 | ~30m |
| 8 | Full-stack restart (via infra-expert) if `#reloadworld` fails to propagate changes — e.g., if VP dragon spawn2 changes don't pick up | infra-expert | 7 (conditional) | ~10m if needed |
| 9 | Commit + push all changed files in `claude/` repo (architecture doc, context files, status updates, implementation SQL reference) to `feature/raid-scaling` branch; no eqemu/ or akk-stack/ commits needed since only data-layer modified | data-expert | 5 | ~10m |

**Critical ordering constraint:** Task 1 MUST complete before Tasks 2-3. Task 5 (apply) MUST happen after 1-4 review. Task 6 (reload) is required before game-tester validation.

**Tasks NOT required:**
- lua-expert: no quest script changes.
- perl-expert: no quest script changes.
- c-expert: no C++ changes.
- protocol-agent: already advised; no implementation role.

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| A VP dragon script (e.g. `akk-stack/server/quests/veeshan/108040.pl`) depends on old HP thresholds for phase triggers | Low | Medium | Spot-check 2-3 VP dragon scripts before apply. Most EQ boss scripts use percentage-based `event_hp` / `eq.set_next_hp_event(50)` which scales automatically. If absolute-HP triggers are found, flag and discuss before apply. |
| Triggered Trakanon (89181) spawned via An_Undead_Bard script inherits HP value from npc_types at spawn time — no quest script breakage expected | Near zero | Low | Same as Phase 2 Q13 Enraged Golem pattern — NPC constructor reads npc_types, script doesn't encode stats. Confirmed by protocol-agent Q3 response. |
| VP `_condition=2` spawn2 UPDATE accidentally touches condition=1 (dormant) rows | Near zero | Low | WHERE clause explicitly filters `s2._condition = 2`. Data-expert verification query counts updated rows per condition. |
| Chardok Royals 1.5h respawn is actually the desired tier per audit ("already short") — bumping to 12h would punish players | Medium | Medium | **USER DECISION GATE** before Task 3 emits the Chardok UPDATE. Default: leave at 1.5h. |
| Faydedar duplicate #Faydedar 96073 is a legacy artifact, not a live encounter — scaling has no effect | Medium | None | Safe no-op. Consistent with main Faydedar for future-proofing. |
| Drusella Sathir 15,750 HP is already named-tier — no change is the right call, not a gap | — | Nil | Per audit, leave as-is. Included in backup for rollback safety only. |
| Kilidna damage cut to 1,000 breaks Paladin/SK epic pathing through CoM — she's meant to be a hazard | None | Nil | She is still a hazard with 1,000 max damage; just not an automatic one-shot. Passing her without engaging remains the recommended route. Lore-master flagged Kilidna as a "navigation hazard, not a required kill." |
| Backup tables occupy disk space | Near zero | Nil | ~50KB combined. Accept. |
| VP revamp dragons have diverse special_abilities (SEFQMCNIDf, SERFTUMCNIDfm for GoV) and we're not editing them — does Decision #11 hold? | None | Nil | Decision #11: preserve signature mechanics, scale HP/damage to compensate. This plan does exactly that. |

### Compatibility Risks

- **Prior-pass rule values remain authoritative.** None are changed, so regression risk is zero. Kunark raid bosses inherit the existing `NPCFlurryChance=12`, `MaxRampageTargets=2`, `NPCAssistCap=3` caps on top of per-NPC changes.
- **Kunark epic quest scripts.** Per lore-master's `kunark-chains.md`, all raid-gated epic steps route through the NPCs we're scaling. Quest scripts (Perl/Lua) don't encode absolute HP values — they fire on percentage thresholds or item turn-ins. Scaling is transparent to scripts.
- **Companion AI.** Same reasoning as Phase 2 — scaled Kunark bosses remain in companion capability range.
- **LLM NPC conversation sidecar.** No change. Sidecar reads name/level/faction, not stats.

### Performance Risks

- **Zero.** ~20 UPDATEs + ~14 UPDATEs against a database that handles thousands of writes per minute.
- **No new indexes needed.**
- **No opcode-layer impact** (verified by protocol-agent).

---

## Review Passes

### Pass 1: Feasibility

Every lever used is established Phase 2 practice:
- `npc_types.hp`, `npc_types.mindmg`, `npc_types.maxdmg` UPDATEs — 58 rows touched in Phase 2 without incident.
- `spawn2.respawntime` UPDATEs — 40+ rows touched in Phase 2.
- Backup table pattern — established by Phase 2.
- VP `_condition=2` scoping — new for Phase 3 but uses well-documented `spawn_conditions` gating. Config-expert flagged it explicitly.

**Hardest part:** The VP `_condition=2` filter. If data-expert writes the UPDATE without the condition filter, both revamp and classic-era VP spawn2 rows get set to 12h. That's not catastrophic (classic-era rows are dormant so timer change is invisible) but it pollutes the backup diff. Data-expert MUST include the `s2._condition = 2` filter on VP respawn UPDATEs and verify row-count (expect 7 rows touched, not 13).

**Confirmed feasibility:** all tasks executable by data-expert + config-expert in one session, same agents as Phase 2.

### Pass 2: Simplicity

**Challenge: Can we do less?**

- **Could we skip the backup tables?** No — Decision #11 preservation goal plus the Phase 2 precedent make backups standard practice.
- **Could we skip Faydedar duplicate 96073?** Yes, technically. It has no spawnentry so the UPDATE is symbolic. **Including it for consistency** — cost is one row in the backup table and one UPDATE statement.
- **Could we skip the triggered Trakanon (#Trakanon 89181) entirely?** It's already at 16k HP (named-tier). **Leave HP unchanged**; no UPDATE needed. Including it in the backup is safety over-capture only.
- **Could we handle VP classic-era variants (108509-108517)?** No — they're dormant (condition=1=0). Scaling them is wasted work. Backup only.
- **Could we defer Chardok Royals entirely?** Yes, if the user decision flags it. Default: apply the HP trim (no respawn change); respawn stays at 1.5h.

**Removed / deferred:**
- **Q13 Q-list NPCs in named-tier zones** (Xenevorash, Vessel Drozlin, Thrackin Griften, Caradon, Kyrenna, Mummy of Glohnor, Tortured Soul 51144/214078, a_tortured_soul 214078): all at named-tier HP already. No Phase 3 action. Documented in `context/kunark-db-investigation.md`.
- **The Tangrin (78070)**: L54 16,350 HP, fieldofbone. raid_target=0. 2× scaled-named. Enchanter Pearlescent Fragment source per lore-master. **Deferred — not raid-tier enough to justify.** Can revisit if Enchanter epic blocks small-group testing.
- **Renux Herkanor 448200 (L72 500k HP)**: raid_target=1, no spawnentry. L72 exceeds in-era band. Monk epic terminus. **USER DECISION NEEDED** — see flagged items.
- **#The_Fabled_Drolvarg_Captain 102127 (L70 300k HP)**: Fabled variant is post-Luclin content per Phase 2 exclusion filter. **Skip.**

### Pass 3: Antagonistic — what could go wrong

1. **VP condition state flips during apply.** If a GM or script toggles `spawn_condition_values` condition 2 to 0 (and condition 1 to 1) between backup and apply, we'd scale dormant variants and miss live ones. **Mitigation:** data-expert captures condition state in backup metadata; apply script asserts condition 2 = 1 before executing VP UPDATEs.

2. **Classic-era VP variants (108509-108517) get re-enabled post-apply.** If GM flips condition, players see unsccaled 144-192k HP dragons. **Mitigation:** this is a separate user action with known-good fallback (those variants are intentionally easier than revamp). Backup captures them for rollback if needed.

3. **Chardok Royals 1.5h respawn interacts with raid_target=1 global loot rules.** Loot is per-kill; short respawn means more loot farming. **Mitigation:** Decision #3 (loot unchanged) is explicit; Chardok royals being loot pinatas at 1.5h is pre-existing behavior, not Phase 3 regression.

4. **Kilidna max damage cut to 1,000 makes her trivial for a small-group tank.** She was designed as a roaming hazard, not a farmed boss. **Mitigation:** her 30k HP post-scaling + special_abilities (TNID flags) keep her a meaningful threat; 1,000 max is still a serious hit on unbuffed characters. Per audit, this damage cut is the clearest "needs rework" entry in the Kunark audit — the gap between 4,600 and 1,000 is intentional to remove the one-shot.

5. **Triggered VS (102112) with no spawn2 — scaling HP but no respawn UPDATE.** Intended. Script-spawned via `akk-stack/server/quests/karnor/` event chain. On next trigger, NPC constructor reads new HP.

6. **Phara Dar damage trim from 1032-1621 to 450-750 feels too aggressive.** Audit recommends 55% cut. The mindmg cut from 1032 → 450 (56%) and maxdmg 1621 → 750 (54%) matches. Dragon is still hitting hard; she's just not a tank-gibber.

7. **VP dragon spell lists have high-damage direct-damage spells (Nexona's Dragon Harm Touch -4,000 HP, 45s recast).** These are signature mechanics per Decision #11. With HP scaled to 120k, a -4,000 DD that can land every 45s is still survivable for a group with healing. Not a Phase 3 change.

8. **Backup table name collision.** Phase 2 used `npc_types_backup_raid_scaling`; Phase 3 uses `npc_types_backup_raid_scaling_kunark`. No collision. Verified.

9. **Over-capture in Phase 2 backup already includes Kunark NPCs.** True. If a Phase 3 rollback is needed and we use Phase 2 backup tables, we'd restore **Kunark** stats to pre-Phase-2 values — which is the same as current (since Phase 2 didn't touch Kunark). Phase 3 backup is redundant in one sense but precise: rolling back from `_kunark` tables is an exact Phase 3-only reversal.

10. **VP `_condition=2` scoping missed by data-expert.** If the SQL omits `s2._condition = 2`, dormant rows get the 12h respawn, too. Verification query: `SELECT _condition, COUNT(*) FROM spawn2 WHERE zone='veeshan' AND respawntime = 43200 GROUP BY _condition` — expect only condition=2 rows.

11. **Lhranc at 19k HP with 13.67h respawn — leaving both unchanged. Validator might flag as "gap."** No: audit explicitly says "already near named tier" and "respawn already in brief's 6-24h target." Leaving unchanged is the correct action.

12. **Damage-spell scaling.** HP cut 80%+ on VP dragons plus high-DD spells could make fights shorter than intended. Example: Nexona 800k→120k HP / 4000 DD every 45s means 40 seconds of burst damage to kill if player DPS is ~3000. This is fine — still a multi-minute fight with threat of death. Decision #11 explicitly trades HP for mechanic fidelity.

### Pass 4: Integration

**Task ordering is linear:**
```
1 (backups) ──> 2 (HP/damage SQL) ──> ┐
              ──> 3 (respawn SQL) ──── ┼──> 5 (apply) ──> 6 (reload) ──> 7 (verify) ──> 9 (commit)
                                      ──> 4 (rollback SQL) ─┘
                                                            8 (full restart, conditional)
```

- Tasks 2, 3 can be done in parallel by data-expert.
- Task 6 (`#reloadworld`) required before smoke verification.
- Task 8 (infra-expert full-stack restart) is ONLY needed if `#reloadworld` fails — primarily for `npc_spells_entries` cache, but Phase 3 doesn't touch that table. Zone cache for `npc_types` and `spawn2` reloads cleanly via `#reloadworld`. Task 8 likely unneeded.
- Task 9 (commit) closes Phase 3.

**Cross-agent dependencies all resolved:**
- game-designer (PRD + audit): inputs consumed.
- lore-master (Kunark chains): inputs consumed; Q13 Kunark resolution complete.
- protocol-agent: confirmed zero client-visible changes for Phase 3.
- config-expert: confirmed no rule changes needed; VP condition filter flagged and incorporated; two user-decision items surfaced.
- game-tester: will receive validation hooks below.

---

## Items flagged to user (decision required before implementation)

### Decision #21 needed — Chardok Royals respawn direction

The three Chardok royals currently respawn at **1.5h (5,400s)**:
- 103055 Queen Velazul Di`zok
- 103056 Overking Bathezid
- 103080 Prince Selrach Di`zok

Decision #5 (respawn tier) says mid-tier = 12h (43,200s). But 1.5h is already *shorter* than 12h — bumping to 12h would *slow down* progression, which contradicts the "reduce raid respawn" brief intent.

**Three options:**
- **Option A (leave unchanged — 1.5h):** Treat Chardok Royals as a separate "short-tier" respawn. Pro: existing design intent; Chardok royals are a sub-raid. Con: inconsistent with 12h mid-tier for VP/Trakanon.
- **Option B (bump to 12h):** Consistent with mid-tier Decision #5. Con: *lengthens* player friction for Warrior epic (Ancient Blade), Cleric epic (Singed Scroll), VP key chain.
- **Option C (intermediate — 6h):** Split the difference. Con: new tier not aligned with Decision #5.

**Recommended: Option A.** Leave at 1.5h. Architecturally the cleanest — "raid-tier" respawn normalization applies to bosses that were already at 54-130h (the Phase 2/3 problem). Chardok royals were already tuned for small-group friendliness.

### Decision #22 needed — Renux Herkanor 448200

NPC 448200 `#Renux_Herkanor`:
- Level 72 (*exceeds* in-era 55-70 band)
- HP 500,000 / damage 786-1605
- raid_target=1
- NO spawnentry (script-spawned — Monk epic Kunark-era terminus per lore-master)

**Two options:**
- **Option A (in scope for Phase 3):** Apply HP cut (500k → 120k or so) and damage trim. Pro: unblocks Monk epic. Con: violates L55-70 in-era filter established in Phase 2.
- **Option B (defer):** Mark as out-of-scope per level cap. Revisit in a later phase or as a one-off fix. Con: blocks Monk epic completion on small-group server.

**Recommended: Option A.** The L72 level is a PEQ-era scripting artifact (Monk epic boss should have been L65-70). Scaling him now unblocks Monk epic (mirroring Phase 2 Decision #13 unblocking 4 other epics via death-touch removal).

If approved, add to Phase 3 SQL:
```sql
UPDATE npc_types SET hp = 120000, maxdmg = 900 WHERE id = 448200;
```

---

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| data-expert | 1, 2, 3, 4, 5, 9 | Owns all SQL emission, backup creation, apply, and commit. Primary agent. |
| config-expert | 6, 7 | `#reloadworld` via world telnet port 9000 and post-change smoke verification. Same role as Phase 2 Tasks 7-8. |
| infra-expert | 8 (conditional) | Only if `#reloadworld` fails to propagate; then runs MEMORY.md full-stack restart. Likely unneeded since Phase 3 doesn't touch `npc_spells_entries`. |

**Agents NOT needed:** c-expert, lua-expert, perl-expert, protocol-agent (already advised).

---

## Validation Plan

_game-tester should verify each of the following after the implementation team completes Tasks 1-9:_

- [ ] **Backup tables exist and are populated.**
  ```sql
  SELECT COUNT(*) FROM npc_types_backup_raid_scaling_kunark;  -- expect 26
  SELECT COUNT(*) FROM spawn2_backup_raid_scaling_kunark;     -- expect ~20
  ```
- [ ] **Trakanon HP at target.** `SELECT hp FROM npc_types WHERE id=89154` returns 22000 (was 32000).
- [ ] **Gorenaire HP + respawn.** `SELECT hp, maxdmg FROM npc_types WHERE id=86014` returns 22000, 400. `SELECT s2.respawntime FROM spawn2 s2 JOIN spawnentry se ON se.spawngroupID=s2.spawngroupID WHERE se.npcID=86014` returns 43200.
- [ ] **Faydedar HP.** `SELECT hp FROM npc_types WHERE id=96089` returns 19000.
- [ ] **Nexona HP + damage.** `SELECT hp, maxdmg FROM npc_types WHERE id=108047` returns 120000, 1000.
- [ ] **Phara Dar HP + damage range.** `SELECT hp, mindmg, maxdmg FROM npc_types WHERE id=108048` returns 120000, 450, 750.
- [ ] **Kilidna damage capped.** `SELECT hp, mindmg, maxdmg FROM npc_types WHERE id=90186` returns 30000, 300, 1000.
- [ ] **VP classic variants untouched.** `SELECT hp FROM npc_types WHERE id IN (108509, 108510, 108511, 108512, 108513, 108517)` returns unchanged values (153500, 191500, 144500, 156500, 152500, 151500).
- [ ] **VP respawn only on condition=2.** `SELECT _condition, COUNT(*), MIN(respawntime), MAX(respawntime) FROM spawn2 WHERE zone='veeshan' AND respawntime=43200 GROUP BY _condition` returns only condition=2 rows.
- [ ] **Triggered Trakanon HP unchanged.** `SELECT hp FROM npc_types WHERE id=89181` returns 16000 (no Phase 3 change planned).
- [ ] **Chardok respawn decision honored.** Per user decision (A, B, or C), spawn2 respawntime for 103055/103056/103080 matches intent.
- [ ] **In-game smoke test (1 player + 5 companions):**
  - Kill Gorenaire in Dreadlands: completable in 1-3 attempts, summon/enrage/triple still fire.
  - Kill Trakanon in Old Sebilis: flurry + rampage still fire (globally capped at 2 targets), fight plays out as HP encounter.
  - Navigate past Kilidna in City of Mist: she hits for up to ~1,000 now, not ~4,600 — survivable if she procs on you mid-cross.
  - Kill Nexona in Veeshan's Peak: Dragon Harm Touch still fires (-4,000 HP) but 120k HP means fight is ~10-15 min with a balanced group.
- [ ] **Rollback dry-run.** Using backup tables, restore `npc_types` for 3 sample NPCs (one outdoor dragon, one VP revamp, one Chardok royal) and verify pre-change values match.
- [ ] **Quest script integrity.** Give An_Undead_Bard (sebilis) the Mystical Lute Body turn-in → verify triggered Trakanon (#Trakanon 89181) spawns with its stats intact. Trigger Venril Sathir via Firefly Globe + Rez scroll handoff to VS Remains in karnor → verify #Venril_Sathir 102112 spawns at 16,500 HP with Paw of Opolla loot.
- [ ] **No regression on unchanged NPCs.** Spot-check Lhranc (90093, should stay 19k HP / 13.67h respawn) and Drusella Sathir (105153, should stay 15.75k HP — untouched per audit).

---

## Appendix — Flagged items not in Phase 3 scope

The following are noted for future phases:

- **Q8 — Coldain Ring War + Prayer Shawl** (Velious). Defer to **Phase 4**.
- **Velious dragons, NToV, ToV, Kael, Sleeper's Tomb, AoW** — Phase 4.
- **Luclin — Ssraeshza, Vex Thal, Luclin raid content** — Phase 5.
- **Q13 Kunark-era named-tier NPCs** (Xenevorash, Vessel Drozlin, Thrackin Griften, Caradon, Kyrenna, Mummy of Glohnor, a_tortured_soul 51144/214078): all at named-tier HP already per DB investigation. No scaling action needed in Kunark pass. Documented in `context/kunark-db-investigation.md`.
- **The Tangrin (78070)**: Enchanter epic Pearlescent Fragment source. 2× scaled-named, raid_target=0. Deferred — monitor during small-group testing; revisit if Enchanter epic blocks.
- **Truespirit / Keepers of the Art / Iksar faction grinds** (structural blockers per lore-master): out of scope for scaling. Flagged for possible separate feature.
- **Necromancer PoSky Thunder Spirit Princess destructive turn-in** (shared-instance concern): out of scope for Phase 3. On a 1-3 player server this is not grief but self-impact. Flag for possible Phase 5 or separate bug fix.

---

> **Next step:** User decides on Decision #21 (Chardok Royals respawn) and Decision #22 (Renux Herkanor 448200). Then spawn the implementation team with:
> - **data-expert** (Tasks 1-5, 9)
> - **config-expert** (Tasks 6-7)
> - **infra-expert** (Task 8, conditional)
>
> Do NOT spawn c-expert, lua-expert, perl-expert, or protocol-agent — they have no Phase 3 work.

---

## Addendum 2026-04-22 — Fabled Chardok variant exclusion (config-expert flag)

Config-expert flagged during Phase 3 consultation: **`#The_Fabled_Prince_Selrach_Di'zok` (ID 103218, HP 1.5M)** has a standing `spawn2` row in chardok. This is a Fabled variant — post-Luclin content excluded per the Phase 2 filter (`name NOT LIKE '#The_Fabled%'`).

**Action for data-expert:** Apply the same Fabled exclusion filter as Phase 2 for any zone-scoped queries against Chardok. For the Phase 3 plan specifically:

- Chardok Royals in scope: **103055 Queen Velazul, 103056 Overking Bathezid, 103080 Prince Selrach** only.
- **NOT in scope:** 103218 `#The_Fabled_Prince_Selrach_Di'zok` (Fabled — post-Luclin era).
- Similarly confirmed excluded: **102127 `#The_Fabled_Drolvarg_Captain`** in karnor (already noted in Existing System Analysis "Other" table).

Since the Phase 3 `npc_types` UPDATE and backup are both ID-list-scoped (not zone-sweep), the Fabled NPCs won't leak in. This addendum documents the filter for any future data-expert query that uses a zone or level predicate.

**No change to task breakdown.** Just a belt-and-suspenders documentation note per config-expert flag.

---

## Addendum 2026-04-22 — Protocol-agent VP script verification

Protocol-agent final review surfaced two additional script-level verifications:

**1. Phara Dar HP-event add-wave** (`akk-stack/server/quests/veeshan/108048.pl`): uses `quest::setnexthpevent(N)` which fires at HP *percentages*, not absolute values. Scaling Phara Dar HP from 681k to 120k **preserves the 80/60/40/20% add-wave triggers exactly**. No script edit needed.

**2. Venril Sathir two-form transition** (`akk-stack/server/quests/karnor/Spirit_of_Venril_Sathir.pl`): uses pure `quest::spawn2` / `quest::depop` pattern — no absolute HP state stored. Scaling HP on both NPC IDs (102112 Spirit triggered form, 102126 standard VS Lich) is safe. The lich transition depends on event_death, not on HP thresholds.

**3. VP door-gate** (`akk-stack/server/quests/veeshan/player.pl`): uses `quest::forcedooropen()` which sends `OP_MoveDoor` — a standard Titanium opcode. VP is a flat open zone (no DZ/Expedition). Entity presence check for the 5 outer dragons scales transparently — HP change doesn't affect kill detection.

**Implication for data-expert:** no quest script review required for Phase 3 apply. The HP cuts for VP dragons (especially Phara Dar) will not break scripted phase transitions.
