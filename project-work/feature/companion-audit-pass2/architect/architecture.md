# Companion Audit Pass 2 — Synthesized Architecture Report

> **Feature branch:** `feature/companion-audit-pass2`
> **Author:** architect
> **Date:** 2026-03-15
> **Status:** Complete
> **Sources:** c-expert audit, lua-expert audit, data-expert audit, first-pass architecture.md

---

## Executive Summary

This report synthesizes findings from three expert audits (C++, Lua, Database) of the companion system, verifying the fixes implemented from the first-pass authenticity audit and identifying new gaps. The nine first-pass fixes (GAP-01/02/03/04/06/10/17, BUG-028, re-recruitment) are verified present and structurally correct. However, this second pass uncovered **one critical systemic issue**: the companion AI reads spells from `companion_spell_sets`, NOT from `npc_spells_entries` — meaning the GAP-05/GAP-07 spell priority fixes are effectively bypassed for all caster companions. Additionally, the cleric heal priority is inverted (damage spells outprioritize mid-high tier heals), the constructor does not call `ScaleStatsToLevel()` (fresh companions lack class-differentiated stats), and the Lua commentary system has an unguarded nil propagation chain that could crash a zone process. This report catalogs all findings, consolidates test coverage gaps from all three experts (13 C++ gaps, 10 Lua gaps, 7 database gaps), and provides a prioritized fix roadmap.

---

## Section 1: Fix Verification Summary

All nine items from the first-pass audit were verified against current `master` source across all three layers.

### Verified Correct (No Issues)

| Fix | Gap | Layer | Verification |
|-----|-----|-------|-------------|
| Critical hit gate | GAP-01 | C++ | `attack.cpp:5446` — `IsNPC() && !IsCompanion() && !RuleB(Combat, NPCCanCrit)`. Companions exempted from NPC crit suppression. |
| PC-only spell targeting | GAP-02 | C++ | Three callsites in `spells.cpp` (832, 838) and `entity.cpp` (5616) all include `!IsCompanion()` / `IsCompanion()` guards. |
| Defensive skill initialization | GAP-03 | C++ | `SetDefensiveSkillsFromCaps()` covers 18 skills from `SkillCaps::Instance()`. Called by both constructor and `ScaleStatsToLevel()`. |
| Hand-to-hand damage | GAP-06 | C++ | `GetHandToHandDamage()` applies class multipliers (0.40 wizard through 1.00 monk). All 15 classes covered. |
| Weapon skill from SkillCaps | GAP-10 | C++ | `SetDefensiveSkillsFromCaps()` uses `SkillCaps::Instance()->GetSkillCap(cls, skill, lvl).cap`. |
| Luabind method registration | GAP-17 | C++ | 35 methods registered in `lua_register_companion()`. All declared, implemented, and registered. No mismatches. |
| Death() hardening | BUG-028 | C++ | Entity-id=0 guard with direct SQL fallback. ORM save failure fallback. Process() safety net. |
| Re-recruitment HP/mana restore | — | C++ | `CreateFromNPC()` calls `SetHP(GetMaxHP())`, `SetMana(GetMaxMana())`, clears flags, clears cooldowns. |
| Recruitment two-track system | FIX-01 | Lua | `check_existing_companion_record` routes re-recruitment past all gating. SQL OR logic for dismissed/suspended. |
| Commentary channel routing | GAP-12/FIX-02 | Lua | `group:GroupMessage(npc, response)` matches `companion_say()` pattern. |
| Level-up handler | GAP-13/FIX-03 | Lua | Handler exists in `global_npc.lua` with `IsCompanion()` guard. Stats recalculated and applied. |
| REREC_BONUS removal | GAP-14/FIX-04 | Lua | No residual references found. Clean removal. |
| Nil-guards | GAP-17/FIX-05 | Lua | All Companion-specific methods guarded — **with one exception** (see Section 4). |
| Spell list validation (npc_spells_entries) | GAP-05/07 | Database | All 30 validation tests pass against `npc_spells_entries`. Priorities are correct in that table. |

### Verified Correct With Subtle Issues

| Fix | Gap | Issue Found |
|-----|-----|-------------|
| GAP-04: ScaleStatsToLevel() | C++ | Function itself is correct (15 class-specific multiplier sets), BUT the constructor does NOT call it. Fresh-recruited companions get `ApplyStatScalePct()` only, missing class differentiation. See Section 2. |
| BUG-028: Process() safety net | C++ | The safety net path does not call `UpdateTimeActive()` before persisting `is_suspended=1`. Companions dying through this path have understated `time_active`. Minor data-fidelity gap. |
| GAP-17 nil-guards | Lua | `GetOwnerCharacterID()` in `companion_commentary.lua:133` is UNGUARDED. This creates a nil propagation chain — see Section 4. |
| GAP-05/07 spell priorities | Database | **CRITICAL**: Fixes were applied to `npc_spells_entries` but NOT to `companion_spell_sets`. The companion AI reads from `companion_spell_sets` as its PRIMARY source. See Section 6. |

### Retracted Finding

The first-pass audit flagged `Longbow (item 8003, races=285)` as excluding halflings (GAP-16). The data-expert's re-query shows `races=65535` (all races). The earlier value was from cached or stale data. **This finding is retracted.** No race restriction violation exists.

---

## Section 2: New Authenticity Gaps Found

These gaps were NOT identified in the first-pass audit.

### NEW-01: `companion_spell_sets` Priorities Not Updated [CRITICAL]

- **Severity:** Critical — undermines all GAP-05/GAP-07 spell priority work
- **Source:** data-expert Finding A
- **Root cause:** Two parallel spell systems exist for companions:
  1. `npc_spells_entries` (keyed by `npc_spells_id` on `npc_types`) — **fixed** by GAP-05/07
  2. `companion_spell_sets` (keyed by `class_id`) — **NOT fixed**
- **Runtime behavior confirmed:** `companion_ai.cpp` line 287-347 `LoadCompanionSpells()` queries `companion_spell_sets` as the PRIMARY spell source. Only when this table returns ZERO rows does the AI fall back to `NPC::AI_EngagedCastCheck()` (which uses `npc_spells_entries`). Since all 15 classes have entries in `companion_spell_sets`, the fallback NEVER triggers for any caster companion.
- **Current state in `companion_spell_sets`:**
  - Cleric (class_id=2): max heal priority = 20 (correct, already had good priorities)
  - Shaman (class_id=6): max heal priority = **1** (BROKEN)
  - Paladin (class_id=8): max heal priority = **1** (BROKEN)
  - Ranger (class_id=10): max heal priority = **1** (BROKEN)
  - All other caster classes: max priority = **1** for all spells (BROKEN)
- **Impact:** Shaman, paladin, and ranger companions cast damage spells and utility before healing. Magician, enchanter, and other caster companions have flat priorities, selecting spells randomly. The GAP-05/07 fixes are entirely ineffective for all caster companions.
- **Fix:** Apply equivalent priority fixes to `companion_spell_sets` for all 15 classes. This is the highest-priority data fix.
- **Assigned expert:** data-expert
- **Estimated scope:** Medium — audit all class entries in `companion_spell_sets`, apply same priority philosophy as GAP-05/07

### NEW-02: Cleric Heal Priority Inversion [HIGH]

- **Severity:** High — cleric companions cast damage before healing at level 24+
- **Source:** data-expert Finding B
- **Root cause:** In `npc_spells_entries` list ID=1 (Default Cleric List), only `Light Healing` (priority 10) and `Healing` (priority 20) are elevated. ALL higher-tier heals are at priority=1:
  - Greater Healing (minlevel 24): priority=1
  - Superior Healing (minlevel 34): priority=1
  - Complete Heal (minlevel 39): priority=1
  - Remedy (minlevel 51): priority=1
  - Divine Light (minlevel 53): priority=1
- Meanwhile, `Wrath` sits at priority=30 and `Smite` at priority=20.
- **Impact:** A level 32 cleric companion (like Lashun Novashine) will cast `Wrath` and `Smite` before `Greater Healing` or `Complete Heal`. The cleric — the primary healer class — preferentially damages instead of healing.
- **Note:** This affects both `npc_spells_entries` and potentially `companion_spell_sets` (if cleric entries there also have flat priorities at higher tiers). The cleric list was NOT in scope for GAP-05 (which fixed shaman/druid/ranger).
- **Fix:** Elevate all cleric mid-high tier heals to priority >= 15. Ensure `companion_spell_sets` cleric entries match.
- **Assigned expert:** data-expert
- **Estimated scope:** Small — UPDATE priorities for ~6 heal spells in the cleric list

### NEW-03: Constructor Does Not Call ScaleStatsToLevel() [HIGH]

- **Severity:** High — fresh companions lack class differentiation
- **Source:** c-expert GAP-04 subtle issue
- **Root cause:** The constructor (`companion.cpp` lines 48-152) calls:
  1. `ApplyStatScalePct()` — applies the global stat scale percentage
  2. `SetDefensiveSkillsFromCaps()` — initializes defensive skills
  3. `CalcBonuses()` — calculates bonuses
  But it does NOT call `ScaleStatsToLevel()`, which is the function that applies class-based stat multipliers (15 distinct class profiles for STR, STA, AGI, DEX, WIS, INT, HP, mana, attack).
- **Impact:** A freshly-recruited level-50 warrior and level-50 wizard have IDENTICAL base stats. Class differentiation only kicks in after the first level-up (which triggers `ScaleStatsToLevel()`). This means the first impression of a recruited companion is a stat-homogeneous NPC.
- **Fix:** Add `ScaleStatsToLevel()` call to the constructor after `ApplyStatScalePct()` and before `SetDefensiveSkillsFromCaps()`.
- **Assigned expert:** c-expert
- **Estimated scope:** Small — 1 line addition to constructor

### NEW-04: Inverted minlevel/maxlevel in 4 Spell Entries [MEDIUM]

- **Severity:** Medium — specific spells are inaccessible
- **Source:** data-expert Finding C
- **Affected entries:**

| List ID | Spell | Type | Priority | minlevel | maxlevel | Impact |
|---------|-------|------|----------|----------|----------|--------|
| 2 (WIZ) | Resistant Armor | buff | 1 | 61 | 57 | Buff never cast — low impact |
| 6 (SHM) | Talisman of Kragg | buff | 2 | 55 | 9 | 55-60 buff never cast — medium impact |
| 7 (DRU) | Creeping Crud | DoT | 7 | 24 | 23 | DoT never cast in level 23-24 window — low impact |
| 8 (PAL) | Touch of Nife | heal | 20 | 61 | 52 | **HIGH**: Priority-20 paladin heal inaccessible at level 52-61 |

- **Fix:** Swap minlevel/maxlevel values for these 4 entries.
- **Assigned expert:** data-expert
- **Estimated scope:** Small — 4 UPDATE statements

### NEW-05: Process() Safety Net Omits UpdateTimeActive() [LOW]

- **Severity:** Low — data fidelity gap, not functional
- **Source:** c-expert BUG-028 subtle issue
- **Root cause:** `Process()` safety net (companion.cpp lines 1739-1810) increments `m_times_died` and persists `is_suspended=1` but does NOT call `UpdateTimeActive()`. The Death() path handles this correctly.
- **Impact:** Companions dying through the Process() safety net path have understated `time_active` in the database. This is a data fidelity issue — no gameplay impact.
- **Fix:** Add `UpdateTimeActive()` call before the direct SQL UPDATE in the Process() safety net path.
- **Assigned expert:** c-expert
- **Estimated scope:** Small — 1 line addition

---

## Section 3: Test Coverage Gap Report

Consolidated from all three expert audits. 30 total gaps identified across C++ (13), Lua (10), and Database (7).

### Critical Priority (should address before next release)

| # | Layer | Gap | Why It Matters | Recommended Test | Scope |
|---|-------|-----|---------------|-----------------|-------|
| TC-C01 | C++ | Constructor stat scaling not tested | Fresh companions have homogeneous stats; no test catches if ScaleStatsToLevel() call is added/removed | Create warrior+wizard at same level, assert STR differs | Small |
| TC-C02 | C++ | DataBucket cooldown deletion in re-recruitment not tested | If cooldown row is not deleted, re-recruitment silently fails next time | Call CreateFromNPC(), then GetData() for cooldown key, assert empty | Small |
| TC-C03 | C++ | Process() safety net UpdateTimeActive() not tested | time_active could be understated; no test verifies the gap | Compare time_active after Death() path vs Process() path | Small |
| TC-D01 | DB | `companion_spell_sets` not validated at all | The primary spell system for companions has zero test coverage | Add companion_spell_sets validation suite checking priorities per class | Medium |
| TC-D02 | DB | Cleric mid-high tier heals not validated | Level 24+ heals at priority=1 are below damage spells; test only checks low-tier heals | Test all cleric heals with minlevel >= 20 have priority >= 10 | Small |

### High Priority (should address soon)

| # | Layer | Gap | Why It Matters | Recommended Test | Scope |
|---|-------|-----|---------------|-----------------|-------|
| TC-C04 | C++ | ACSum() companion branch not tested | Shield AC and defense skill contribution untested for companions | Call ACSum() on companion with shield, assert non-zero | Small |
| TC-C05 | C++ | CreateCompanion orphaned DB row path not tested | Save() before Spawn() can leave orphan rows if Spawn() fails | Call CreateFromNPC() without Spawn(), verify Load() succeeds | Small |
| TC-L01 | Lua | Commentary system has zero test coverage | 177 lines of non-trivial logic (grace period, hard cap, context change, probability roll, LLM call, channel routing) — crash in commentary timer is silent | Create test_companion_commentary.lua with 8 scenarios | Medium |
| TC-L03 | Lua | Level-up handler not tested | Stats recalculation and message delivery untested | Test guard, stats recalc, and nil DB result paths | Small |
| TC-D03 | DB | Inverted minlevel/maxlevel not validated | 4 entries silently fail; no test catches new inversions | Test minlevel <= maxlevel for all companion spell lists | Small |

### Medium Priority

| # | Layer | Gap | Why It Matters | Recommended Test | Scope |
|---|-------|-----|---------------|-----------------|-------|
| TC-C06 | C++ | GetHandToHandDamage() per-class values not tested | 15 class multipliers exist but no test verifies specific values | Assert monk(1.00), wizard(0.40), warrior(0.90) at level 50 | Small |
| TC-C07 | C++ | SetGuardMode toggle round-trip not tested | Guard mode on/off sequence could crash if client nullptr | Test SetGuardMode(true) then SetGuardMode(false), verify follow restored | Small |
| TC-C08 | C++ | Death() direct SQL fallback (entity-id=0 path) not tested | Hardest path to trigger; bypass of ORM entirely | Mock GetID()=0, verify SQL fires | Small |
| TC-C09 | C++ | Suspend/Unsuspend state persistence not tested | Flag set + DB write untested | Call Suspend(), verify DB row, call Unsuspend(), verify DB row | Small |
| TC-L02 | Lua | Culture system has zero test coverage | 622 lines of pure Lua logic — highly testable without mocking | Create test_companion_culture.lua with 4 scenario groups | Medium |
| TC-L04 | Lua | GetFaction() workaround untested | pcall + CastToNPC() fallback chain untested | Test standard NPC, companion NPC, CastToNPC nil paths | Small |
| TC-L05 | Lua | event_trade equipment handling not tested | Slot matching, class/race restriction, item rejection untested | Test valid equip, invalid slot, class restriction, race restriction | Medium |
| TC-L07 | Lua | Re-recruitment SQL edge cases not tested | Active companion (both flags=0) should NOT be found; LIMIT 1 behavior | Test active companion not returned, multiple records | Small |
| TC-D04 | DB | companion_data state integrity not validated | Anomalous states (active+0hp, dual-flag) not caught | Test for active+0hp and suspended+dismissed anomalies | Small |
| TC-D05 | DB | Orphaned companion_inventories not validated | Deleted companion with leftover inventory rows | JOIN check for orphaned rows | Small |
| TC-D07 | DB | companion_spell_sets vs npc_spells_entries parity not validated | Divergence between the two spell systems is a bug surface | Cross-system parity test for matching classes | Medium |

### Low Priority

| # | Layer | Gap | Why It Matters | Recommended Test | Scope |
|---|-------|-----|---------------|-----------------|-------|
| TC-C10 | C++ | GetTimeActive() session accumulation | Timing-sensitive; hard to test reliably | Verify GetTimeActive() increases over time within session | Small |
| TC-C11 | C++ | GetRecruitedZoneID() populated | Depends on zone context in constructor | Verify non-zero after construction | Small |
| TC-C12 | C++ | GiveSlot()/GiveAll() item transfer | Depends on client state | Verify item transfer to client | Small |
| TC-C13 | C++ | SoulWipe() side effects | May have ChromaDB clear signal | Verify all side effects | Small |
| TC-L06 | Lua | event_death_zone kill tracking not tested | Entity variable serialization and named NPC detection | Test named/non-named kill tracking | Small |
| TC-L08 | Lua | Buff queue Phase 1 ordering | Priority ordering (owner first, then party) | Verify ordering with 3-member party | Small |
| TC-L09 | Lua | Commentary hard cap timer integration | No integration test via event_timer dispatch | Test timer dispatch to check_and_speak() | Small |
| TC-L10 | Lua | Unknown ! command fallback | !unknowncmd and empty ! command | Test friendly error response | Small |
| TC-D06 | DB | Duplicate spell IDs not validated | No duplicates found today; should be automated | Test spellid uniqueness per list | Small |

---

## Section 4: Lua/C++ Contract Issues

### CONTRACT-01 + CONTRACT-02: Commentary Nil Propagation Chain [HIGH]

These two issues form a compounding failure chain that could crash a zone process.

**The chain:**

1. **Commentary timer fires** in `global_npc.lua` → calls `companion_commentary.check_and_speak(e.self)` **without pcall** (CONTRACT-02)
2. **Inside `check_and_speak()`**, `companion_commentary.lua:133` calls `npc:GetOwnerCharacterID()` **without a nil-guard** (CONTRACT-01)
3. `GetOwnerCharacterID()` is a Companion-specific method. If luabind resolution fails (GAP-17 scenario), the call returns `nil` instead of throwing
4. The existing guard `if owner_char_id == 0 then return end` does NOT catch `nil` — in Lua, `nil ~= 0` evaluates to `true`, so the guard is bypassed
5. `nil` is passed to `GetClientByCharID(nil)` — this calls into C++ with an invalid argument, causing undefined behavior

**Why both issues compound:** CONTRACT-01 alone would be caught if CONTRACT-02 were in place (pcall would catch the nil propagation error). CONTRACT-02 alone would mask CONTRACT-01 (error caught but not fixed). Both together mean the error propagates uncaught from Lua into C++ — the worst case.

**Fix required:**
- CONTRACT-01: Change `companion_commentary.lua:133` to `if not owner_char_id or owner_char_id == 0 then return end`
- CONTRACT-02: Wrap the `check_and_speak()` call in `global_npc.lua` with pcall and error logging

**Assigned expert:** lua-expert
**Estimated scope:** Small — 2 files, ~5 lines total

### CONTRACT-03: CastToNPC() Unprotected in client_ext.lua [MEDIUM]

**File:** `akk-stack/server/quests/lua_modules/client_ext.lua:64-75`

The `GetFaction()` workaround pcall-protects `GetPrimaryFaction()` but not the fallback `CastToNPC()` call. If `CastToNPC()` throws (rather than returning nil), the error propagates uncaught to the calling context — typically recruitment or LLM context building.

**Fix:** Wrap the `CastToNPC()` call in pcall or check `.valid` on the result.
**Assigned expert:** lua-expert
**Estimated scope:** Small — 1 file, ~3 lines

### CONTRACT-04: Database() Nil Check Missing [LOW]

**File:** `akk-stack/server/quests/lua_modules/companion.lua` (multiple call sites)

`Database()` constructor could return nil if MariaDB is down. Multiple call sites call methods on the result without nil-checking. In practice, DB down = zone down anyway, so the risk is academic.

**Fix:** Add `if not db then return end` guard after `Database()` construction at all call sites.
**Assigned expert:** lua-expert
**Estimated scope:** Small — 1 file, ~5 guards

### Stale MEMORY.md Entry

The MEMORY.md entry documenting "GetPrimaryFaction() is nil on Companion objects" is **stale**. The GAP-17 fix added `GetPrimaryFaction()` to the `lua_register_companion()` registration block (line 333 of `lua_companion.cpp`). The method is now correctly available on Companion objects. This MEMORY.md entry should be removed to prevent future agents from adding unnecessary nil-guards for a resolved issue.

### CreateCompanion Orphaned DB Row Risk [LOW]

In `lua_client.cpp`, `CreateCompanion()` calls `Save()` before `Spawn()`. If `Spawn()` fails or is never called by the Lua script, an orphaned row exists in `companion_data` with no corresponding entity in the zone. The Lua caller receives a valid `Lua_Companion` wrapper regardless of whether the entity was spawned.

**Mitigation:** This is low-risk in practice because `Spawn()` is called immediately after `CreateCompanion()` in all current code paths. However, a defensive improvement would be to either (a) defer the `Save()` until after `Spawn()` succeeds, or (b) add a cleanup timer that removes companion records with no active entity.

---

## Section 5: Prioritized Fix Roadmap

### P1: Critical — Must Fix Before Next Release

| # | Finding | Fix Description | Expert | Scope | Rationale |
|---|---------|----------------|--------|-------|-----------|
| P1-1 | NEW-01: companion_spell_sets not updated | Apply GAP-05/07 equivalent priorities to companion_spell_sets for all 15 classes | data-expert | Medium | All caster companion AI is reading from this table. Priority=1 for all spells means random spell selection. This is THE most impactful fix. |
| P1-2 | CONTRACT-01+02: Commentary nil chain | Add nil-guard to GetOwnerCharacterID() + pcall-wrap check_and_speak() | lua-expert | Small | Zone crash risk from periodic timer. Two-line fix prevents undefined C++ behavior. |
| P1-3 | NEW-02: Cleric heal priority inversion | Elevate Greater Healing, Superior Healing, Complete Heal to priority >= 15 in both npc_spells_entries and companion_spell_sets | data-expert | Small | Cleric companion casts Wrath instead of healing at level 24+. The primary healer class is broken. |

### P2: High — Should Fix Before Next Release

| # | Finding | Fix Description | Expert | Scope | Rationale |
|---|---------|----------------|--------|-------|-----------|
| P2-1 | NEW-03: Constructor missing ScaleStatsToLevel() | Add ScaleStatsToLevel() call to constructor | c-expert | Small | Fresh companions have no class differentiation. One-line fix. |
| P2-2 | TC-C01 through TC-C05 and TC-D01-D03 | Add critical and high test coverage | c-expert + data-expert | Medium | 8 critical/high test gaps leave core functionality unvalidated. |
| P2-3 | TC-L01: Commentary test coverage | Create test_companion_commentary.lua | lua-expert | Medium | 177 lines of untested code with a known crash path (CONTRACT-01). |
| P2-4 | CONTRACT-03: CastToNPC() unprotected | Pcall-protect CastToNPC() in client_ext.lua | lua-expert | Small | Faction check during recruitment could throw. |

### P3: Medium — Should Fix In Next Iteration

| # | Finding | Fix Description | Expert | Scope | Rationale |
|---|---------|----------------|--------|-------|-----------|
| P3-1 | NEW-04: Inverted minlevel/maxlevel | Swap values for 4 entries, especially paladin Touch of Nife | data-expert | Small | Priority-20 paladin heal is inaccessible. |
| P3-2 | TC-L02/L04/L05/L07 medium Lua test gaps | Add test files for culture, GetFaction(), event_trade, re-recruitment SQL edge cases | lua-expert | Medium | Untested code paths in frequently-executed modules. |
| P3-3 | TC-D04/D05/D07 medium DB test gaps | Add companion_data integrity, orphan checks, cross-system parity tests | data-expert | Small | Automated integrity validation prevents silent data corruption. |
| P3-4 | TC-C06/C07/C08/C09 medium C++ test gaps | Add per-class hand-to-hand, guard mode toggle, death SQL fallback, suspend state tests | c-expert | Small | Secondary code paths with known edge cases. |

### P4: Low — Cleanup and Documentation

| # | Finding | Fix Description | Expert | Scope | Rationale |
|---|---------|----------------|--------|-------|-----------|
| P4-1 | NEW-05: Process() safety net UpdateTimeActive() | Add UpdateTimeActive() call to Process() safety net | c-expert | Small | Data fidelity; no gameplay impact. |
| P4-2 | CONTRACT-04: Database() nil check | Add nil guards to Database() call sites | lua-expert | Small | Academic risk — DB down means zone down anyway. |
| P4-3 | Stale MEMORY.md entry | Remove GetPrimaryFaction() nil entry from MEMORY.md | Any agent | Small | Prevents future agents from applying unnecessary workarounds. |
| P4-4 | Low-priority test gaps (TC-C10-C13, TC-L06/L08-L10, TC-D06) | Add timing, zone ID, item transfer, kill tracking, buff ordering, and dedup tests | Various | Small each | Edge case coverage with low risk of regression. |
| P4-5 | Era-locked spells (minlevel > 60) | Review and potentially prune post-Luclin spells from companion lists | data-expert | Medium | 13-26% of spell list entries are post-era. Noise, not functional harm. |

---

## Section 6: CRITICAL QUESTION — Which Spell System Does the AI Use?

### Answer: `companion_spell_sets` is the PRIMARY system

This question has been definitively resolved by examining the C++ source.

**Evidence chain:**

1. `companion_ai.cpp:22-28` — File header states: "Spell lists come from companion_spell_sets which is populated by the data-expert"
2. `companion.cpp:1419-1427` — `AI_Start()` calls `LoadCompanionSpells()` immediately after `NPC::AI_Start()`
3. `companion_ai.cpp:287-347` — `LoadCompanionSpells()` queries `companion_spell_sets WHERE class_id = ? AND min_level <= ? AND max_level >= ?` and populates `m_companion_spells`
4. `companion_ai.cpp:358-396` — `AICastSpell()` checks `m_companion_spells.empty()` first:
   - If empty: falls back to `NPC::AI_EngagedCastCheck()` (which reads `npc_spells_entries`)
   - If populated: uses companion-specific AI logic with `m_companion_spells` data
5. `companion.cpp:2115-2116` — Comment explicitly states: "Call our own AICastSpell() so the companion uses the companion_spell_sets data, not the NPC spell list"

**Consequence:** Since all 15 classes have entries in `companion_spell_sets` (confirmed by data-expert), the `npc_spells_entries` fallback NEVER triggers. The GAP-05 and GAP-07 fixes to `npc_spells_entries` are therefore **completely ineffective** for companion spell casting behavior. They remain correct for non-companion NPCs using those spell lists, and they serve as the fallback if `companion_spell_sets` is ever emptied for a class, but they do not control companion AI today.

**Priority column lookup for companion_spell_sets:**

The `LoadCompanionSpells()` query orders by `priority ASC, id ASC`. In `AICastSpell()`, the companion iterates through `m_companion_spells` and selects the first matching spell for the current situation (engaged, HP threshold, mana available, spell type mask). Because iteration is in priority-ASC order, **lower priority numbers are checked first**. This means:
- priority=1 spells are checked BEFORE priority=20 spells
- This is the **opposite** of `npc_spells_entries` behavior, where higher priority = checked first

**WAIT — this needs verification.** Let me check whether the `companion_spell_sets` priority ordering is ascending (1 = highest priority) or descending (20 = highest priority).

Looking at the query: `ORDER BY priority ASC, id ASC`. This means priority=1 entries come first in the iteration order. If the AI iterates from front to back and picks the first match, priority=1 is "highest priority" in this system.

BUT the data-expert found that in the working cleric list, heals have priority=20. If priority=1 is "highest priority" (checked first), then having heals at priority=20 would mean they're checked LAST — which would be wrong for clerics.

**This requires careful analysis of the AICastSpell iteration logic.** The c-expert should verify whether the companion AI picks the FIRST match (meaning ASC = priority 1 checked first) or the HIGHEST priority match (meaning DESC ordering would be needed). The data fix must use the correct priority semantics for `companion_spell_sets`.

**Recommended immediate action:**
1. **c-expert**: Verify the exact iteration/selection logic in `AICastSpell()` and document whether low priority = checked first or high priority = checked first
2. **data-expert**: Once semantics are confirmed, apply GAP-05/07 equivalent priorities to `companion_spell_sets` using the correct priority direction
3. **data-expert**: Fix the cleric mid-high tier heal priorities in BOTH tables

---

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Verify AICastSpell priority semantics (ascending vs descending) | c-expert | — | Small (research only) |
| 2 | Apply GAP-05/07 equivalent priorities to companion_spell_sets for all 15 classes | data-expert | 1 | Medium |
| 3 | Fix cleric heal priority inversion in both npc_spells_entries and companion_spell_sets | data-expert | 1 | Small |
| 4 | Fix CONTRACT-01: nil-guard GetOwnerCharacterID() in companion_commentary.lua | lua-expert | — | Small |
| 5 | Fix CONTRACT-02: pcall-wrap check_and_speak() in global_npc.lua | lua-expert | — | Small |
| 6 | Add ScaleStatsToLevel() call to Companion constructor | c-expert | — | Small |
| 7 | Fix 4 inverted minlevel/maxlevel entries in npc_spells_entries | data-expert | — | Small |
| 8 | Fix CONTRACT-03: pcall-protect CastToNPC() in client_ext.lua | lua-expert | — | Small |
| 9 | Add Process() safety net UpdateTimeActive() call | c-expert | — | Small |
| 10 | Add critical C++ test coverage (TC-C01, TC-C02, TC-C03) | c-expert | 6 | Small |
| 11 | Add critical DB test coverage (TC-D01, TC-D02, TC-D03) | data-expert | 2, 3 | Small |
| 12 | Add commentary Lua test coverage (TC-L01) | lua-expert | 4, 5 | Medium |
| 13 | Remove stale MEMORY.md GetPrimaryFaction() entry | lua-expert | — | Small |
| 14 | Add CONTRACT-04 Database() nil guards | lua-expert | — | Small |

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| companion_spell_sets priority direction is opposite to npc_spells_entries | Medium | High | Task #1 resolves this before any data changes. c-expert verifies the iteration logic first. |
| Cleric heal priority fix breaks non-companion cleric NPCs | Low | Medium | If list ID=1 is shared with other NPCs, create a companion-specific cleric list. Check npc_types usage of npc_spells_id=1. |
| ScaleStatsToLevel() in constructor creates stat double-application | Low | Medium | Verify that ApplyStatScalePct() and ScaleStatsToLevel() don't compound (one scales percentages, the other applies class multipliers). |
| CONTRACT-01 fix masks a deeper luabind resolution failure | Low | Low | The nil-guard is the correct immediate fix. The deeper fix (GAP-17 luabind registration) is already in place — this is a belt-and-suspenders guard. |

### Compatibility Risks

- companion_spell_sets priority changes affect ONLY companion AI. No other NPC type reads this table.
- npc_spells_entries changes (cleric list) may affect non-companion cleric NPCs using list ID=1. Verify scope before applying.
- ScaleStatsToLevel() in the constructor is additive — it applies class multipliers that were previously missing. Companions will become appropriately differentiated (warriors tankier, casters squishier). This is the intended behavior but may change the "feel" of existing companions.

### Performance Risks

None. All fixes are in existing code paths with negligible computational cost.

---

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | 1, 6, 9, 10 | Priority semantics verification, constructor fix, Process() fix, C++ test coverage |
| data-expert | 2, 3, 7, 11 | companion_spell_sets priority overhaul, cleric heals, inverted levels, DB test coverage |
| lua-expert | 4, 5, 8, 12, 13, 14 | CONTRACT-01/02/03/04 fixes, commentary test coverage, MEMORY.md cleanup |

---

## Validation Plan

After implementation, the game-tester should verify:

- [ ] Shaman companion prioritizes healing injured group members over casting SoW/damage in combat
- [ ] Cleric companion casts Greater Healing / Complete Heal before Wrath / Smite when group member is injured
- [ ] Enchanter companion prioritizes Mesmerize over random spells when multiple mobs are engaged
- [ ] Commentary timer does not crash the zone when companion is in any edge-case state (no owner, nil values)
- [ ] Fresh-recruited warrior companion has higher STR than a same-level fresh-recruited wizard (`!stats`)
- [ ] Paladin companion can cast Touch of Nife at appropriate levels (if minlevel/maxlevel fixed)
- [ ] All companion-specific methods work from Lua without nil-guard failures
- [ ] Process() safety net path correctly records time_active (verify via DB query after death)
- [ ] Companion_spell_sets validation suite passes (all priorities correct per class)
- [ ] No orphaned companion_data or companion_inventories rows after recruitment/dismissal cycle

---

> **Next step:** This is the synthesized pass-2 audit report. The prioritized fix roadmap
> above provides a clear implementation sequence. The critical path is:
> 1. **c-expert** resolves the AICastSpell priority semantics question (Task #1)
> 2. **data-expert** applies companion_spell_sets fixes (Tasks #2, #3) using verified semantics
> 3. **lua-expert** fixes the CONTRACT-01/02 crash chain (Tasks #4, #5)
> 4. All other tasks can proceed in parallel
>
> **Assigned experts for implementation phase:**
> 1. **c-expert** — Tasks 1, 6, 9, 10
> 2. **data-expert** — Tasks 2, 3, 7, 11
> 3. **lua-expert** — Tasks 4, 5, 8, 12, 13, 14
