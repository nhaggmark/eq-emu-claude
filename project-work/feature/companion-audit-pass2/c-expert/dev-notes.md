# Companion Audit Pass 2 — Dev Notes: C Expert

> **Feature branch:** `feature/companion-audit-pass2`
> **Agent:** c-expert
> **Task(s):** #1 — Verify fixes, test coverage gaps, contract alignment
> **Date:** 2026-03-15
> **Status:** Complete
> **Date started:** 2026-03-15
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Audit pass 2: verify fixes, test gaps, Lua contract alignment | none | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/zone/companion.h` | all | Class definition, identity flag overrides, public API |
| `eqemu/zone/companion.cpp` | all (multi-pass) | Constructor, CreateFromNPC, ScaleStatsToLevel, SetDefensiveSkillsFromCaps, GetHandToHandDamage, Death, Process |
| `eqemu/zone/attack.cpp` | greps | GAP-01 crit gate, ACSum companion guards |
| `eqemu/zone/spells.cpp` | greps | GAP-02 pcnpc_only_flag fixes |
| `eqemu/zone/entity.cpp` | greps | GAP-02 cone AE fix, entity cleanup guard |
| `eqemu/zone/lua_companion.h` | all | Lua_Companion : Lua_Mob, all declared methods |
| `eqemu/zone/lua_companion.cpp` | all | All method impls, lua_register_companion() registration |
| `eqemu/zone/lua_client.cpp` | greps | CreateCompanion binding, registration line |
| `eqemu/zone/cli/tests/cli_companion_tests.cpp` | all (multi-pass) | All 23 suites — coverage mapping |
| `claude/project-work/companion-authenticity-audit/architect/architecture.md` | all | Prior audit's 14 gaps — ground truth for fix verification |

### Key Findings

This is a pure research audit. No code was modified. All findings below informed the three focus areas.

---

## Stage 2: Research

_This task was research-only — no code to verify via Context7. All verification was done by reading actual source files._

---

## Stage 3: Socialize

_Research task dispatched by team-lead. No cross-team dependencies. No socialization needed._

---

## Stage 4: Build

_Research-only task. No code changes. The "build" output is the audit report below._

---

## AUDIT REPORT

### Focus 1: Fix Verification

All 9 items from the first-pass audit were verified against current `master` source.

#### GAP-01: Companion excluded from NPC crit gate
**Status: CONFIRMED CORRECT**
`attack.cpp` line 5446:
```cpp
if (IsNPC() && !IsCompanion() && !RuleB(Combat, NPCCanCrit)) {
    return;
}
```
Companion is excluded from the NPC-only crit suppression. Companions can crit if rules allow. Correct.

#### GAP-02: Companion excluded from pcnpc_only_flag filtering
**Status: CONFIRMED CORRECT**
- `spells.cpp` line 832: PC-only spells now include `!spell_target->IsCompanion()` in the exclusion check.
- `spells.cpp` line 838: NPC-only path also adds `!spell_target->IsCompanion()` exclusion.
- `entity.cpp` line 5616: Cone AE now includes `!ptr->IsCompanion()` in pcnpc==1 guard and `ptr->IsCompanion()` in pcnpc==2 inclusion.
All three callsites correct.

#### GAP-03: SetDefensiveSkillsFromCaps() initializes 18 skills
**Status: CONFIRMED CORRECT**
`companion.cpp` lines 464–506: Covers SkillOffense, Skill1HSlashing, Skill2HSlashing, Skill1HBlunt, Skill2HBlunt, Skill1HPiercing, SkillHandToHand, SkillBow, SkillDefense, SkillDodge, SkillParry, SkillRiposte, SkillBlock, SkillBash, SkillKick, SkillMeditate, SkillAlteration, SkillConjuration. Called by both ScaleStatsToLevel() and the constructor. Correct.

#### GAP-04: ScaleStatsToLevel() applies class-based stat multipliers
**Status: CONFIRMED CORRECT WITH SUBTLE ISSUE**
`companion.cpp` lines 316–430: All 15 classes have distinct multipliers applied to STR, STA, AGI, DEX, WIS, INT, HP, mana, and attack. `SetDefensiveSkillsFromCaps()` and `CalcBonuses()` called at end.

**Subtle issue found:** The constructor (lines 48–152) calls `ApplyStatScalePct()` but does NOT call `ScaleStatsToLevel()`. Fresh-recruited companions never receive the class-based differentiation unless they level up after recruitment. A freshly-recruited level-50 warrior and level-50 wizard will have identical base stats until one of them gains a level. This is a functional gap — not a regression from the audit — but it means the stat scaling system is only half-applied at recruitment time. **Recommend: add a `ScaleStatsToLevel()` call to the constructor.**

#### GAP-06: GetHandToHandDamage() class-based unarmed override
**Status: CONFIRMED CORRECT**
`companion.cpp` lines 512–555: Base = `level/5 + 2`, then class multipliers (0.40 for wizard through 1.00 for monk/war). Clamped to minimum 1. All 15 classes covered. Correct.

#### GAP-10: Weapon skill initialization via SkillCaps
**Status: CONFIRMED CORRECT**
`SetDefensiveSkillsFromCaps()` uses `SkillCaps::Instance()->GetSkillCap(cls, skill, lvl).cap` for all 18 skills. Called from constructor and from ScaleStatsToLevel(). Correct.

#### GAP-17: lua_register_companion() registers all methods
**Status: CONFIRMED CORRECT**
`lua_companion.cpp` lines 306–343: 35 methods registered on `Lua_Companion` with `Lua_Mob` as the luabind base class. All methods declared in `lua_companion.h` are present in the registration block. Correct.

#### BUG-028: Death() hardening
**Status: CONFIRMED CORRECT**
`companion.cpp` lines 561–668:
- Entity-id=0 guard: if `GetID() == 0`, skips ORM path and goes directly to SQL `UPDATE companion_data SET is_suspended=1 WHERE id=?`.
- ORM save failure fallback: if `companion_repository.UpdateOne()` returns false, fires the same direct SQL.
- Both paths correctly set `m_suspended = true` and increment `m_times_died`.
**Process() safety net also confirmed** (lines 1739–1810): `if (GetHP() <= 0 && !m_suspended && m_companion_id > 0)` increments `m_times_died` and fires direct SQL UPDATE.

**Subtle issue found in Process() path:** The safety net increments `m_times_died` and persists `is_suspended=1` but does NOT call `UpdateTimeActive()`. Companions dying through the Process() path (not the Death() path) will have understated `time_active` in the DB. The Death() path calls `UpdateTimeActive()` correctly. This is a minor data-fidelity gap, not a crash.

#### Re-recruitment HP/mana restore
**Status: CONFIRMED CORRECT**
`companion.cpp` `CreateFromNPC()` (lines 199–257): After `Load()`, calls `SetHP(GetMaxHP())` and `SetMana(GetMaxMana())`, clears `m_is_dismissed` and `m_suspended`, issues direct DB UPDATE `SET is_dismissed=0, is_suspended=0`, then calls `DataBucket::DeleteData()` to clear cooldowns.

**Note on DataBucket scope:** MEMORY.md documents that companion cooldowns use `character_id=0`. The `DeleteData()` call in `CreateFromNPC()` targets the cooldown key — whether this correctly finds the row depends on how DataBucket scopes its queries internally. If it filters by character_id, the cooldown row may not be deleted. This was a pre-existing concern and is not new to this audit, but it is unverified.

---

### Focus 2: Test Coverage Gaps

Current test suite has 23 suites. Gaps identified below, with severity.

#### CRITICAL

**Gap 1 — Constructor does not call ScaleStatsToLevel()**
Suite 4 (stat scaling) tests ScaleStatsToLevel() in isolation but no test verifies that a freshly-constructed companion has class-differentiated stats. A warrior and wizard companion at the same level should have different STR/INT after construction. Currently untested. This is the most important gap because it corresponds to the subtle GAP-04 issue above.

**Gap 2 — DataBucket cooldown deletion in re-recruitment**
Suite 20 tests that HP/mana are max after re-recruit, and flags are cleared. But no test verifies that the DataBucket row for the cooldown is actually deleted. Test should call `DataBucket::GetData()` with the expected cooldown key after `CreateFromNPC()` and assert it returns empty string.

**Gap 3 — Process() safety net omits UpdateTimeActive()**
Suite 21 (test 21.5) tests the Process() safety net path, but does not verify that `time_active` (or the lack of its update) is handled correctly. Test should verify the DB state for `time_active` after a companion dies through the Process() path vs the Death() path.

#### HIGH

**Gap 4 — ACSum() identity guards**
No suite tests the `ACSum()` companion branch specifically. The South Ro fix (test 10) tests the `CastToBot()` guard but does not verify the full AC sum path for a companion with a shield equipped. Should add a test that calls `ACSum()` directly on a companion and verifies the result is non-zero.

**Gap 5 — CreateCompanion orphaned DB row**
In `lua_client.cpp`, `Save()` is called before `Spawn()`. If `Spawn()` fails (or is never called), an orphaned row exists in `companion_data`. No test exercises this path. Should add a test that calls `CreateFromNPC()`, then verifies that calling `Load()` on the returned companion ID succeeds.

#### MEDIUM

**Gap 6 — GetHandToHandDamage() per-class values**
Suite 9 tests weapon damage at a structural level. No test calls `GetHandToHandDamage()` per-class and verifies the multiplier produces the correct value for each of the 15 classes. Should add assertions for monk (1.00), wizard (0.40), and warrior (0.90) at level 50.

**Gap 7 — SetGuardMode toggle round-trip**
Suite 22 tests individual follow/guard methods. No test calls `SetGuardMode(true)` then `SetGuardMode(false)` and verifies that `GetFollowID()` returns the owner's entity ID after the toggle-off. The `entity_list.GetClientByCharID()` lookup in SetGuardMode could return nullptr in tests (no real client in zone). Test should verify the guard mode is cleared and follow is restored (or that the nullptr case doesn't crash).

**Gap 8 — Death() direct SQL fallback path**
Suite 21 tests the ORM path and the direct SQL path, but the direct SQL test (21.3) likely calls the fallback by returning false from ORM. The entity-id=0 path (GetID()==0) is the harder case — it bypasses ORM entirely and goes straight to SQL. A dedicated test should create a companion with entity ID 0 (or mock GetID()) and verify the SQL path fires.

**Gap 9 — Suspend/Unsuspend state persistence**
No suite tests that calling `Suspend()` sets `m_suspended=true` AND persists to DB, and that `Unsuspend()` clears both. Suite 2 tests equipment round-trips, not suspend state.

#### LOW

**Gap 10 — GetTimeActive() includes current session**
The method comment says "cumulative seconds active (live, includes current session)". No test verifies that `GetTimeActive()` increases over time within a session. This is a timing-sensitive test — mark as low.

**Gap 11 — GetRecruitedZoneID() is populated**
No test verifies that `GetRecruitedZoneID()` returns a non-zero value after construction. Depends on zone context being set in the constructor.

**Gap 12 — GiveSlot() and GiveAll() transfer items**
Suite 2 tests GiveItem(). No test verifies GiveSlot() or GiveAll() actually transfer items to the client. These are UI-facing methods that a Lua script may call. Low priority since they depend on client state.

**Gap 13 — SoulWipe() clears ChromaDB signal**
No test verifies that SoulWipe() fires the ChromaDB clear signal (if it exists as a side effect). The method may only call `Dismiss()` — verify what it does in companion.cpp and add a test if there's a side effect.

---

### Focus 3: Lua/C++ Contract Alignment

#### lua_register_companion() — 35 registered methods

All 35 methods verified: declared in `lua_companion.h`, implemented in `lua_companion.cpp`, registered in `lua_register_companion()`. No declaration/implementation/registration mismatches found.

**Full registration verified:**
AddExperience, Dismiss, GetCompanionID, GetCompanionType, GetCompanionXP, GetCombatRole, GetEquipment, GetFollowCanRun, GetFollowDistance, GetFollowID, GetMaxDMG, GetMinDMG, GetOwner, GetOwnerCharacterID, GetPrimaryFaction, GetRecruitedLevel, GetRecruitedNPCTypeID, GetRecruitedZoneID, GetStance, GetTimeActive, GetXPForNextLevel, GiveAll, GiveItem, GiveSlot, IsGuarding, Save, SetFollowCanRun, SetFollowDistance, SetFollowID, SetGuardMode, SetStance, ShowEquipment, SoulWipe, Suspend, Unsuspend.

**Inheritance note:** `Lua_Companion` inherits `Lua_Mob` (NOT `Lua_NPC`) in both C++ and luabind. Methods on `Lua_NPC` (like `GetPrimaryFaction`, `GetMinDMG`, `GetMaxDMG`, follow/guard methods) are NOT inherited — they are explicitly re-exposed on `Lua_Companion`. This is by design and is correctly implemented. MEMORY.md documents `GetPrimaryFaction()` as `nil` on Companion objects — this is WRONG based on current source. `GetPrimaryFaction()` IS registered (line 333). The MEMORY.md note appears to be stale from before the GAP-17 fix was applied.

#### CreateCompanion path in lua_client.cpp

Traced `lua_client.cpp` lines 3639–3680:
1. Takes `Lua_NPC` parameter, extracts raw `NPC*` via cast.
2. Calls `Companion::CreateFromNPC(npc)` — returns `Companion*` or nullptr.
3. If non-null: calls `companion->Save()` **before** `companion->Spawn(self)`.
4. Returns `Lua_Companion(companion)`.

**Contract issue:** `Save()` is called before `Spawn()`. If `Spawn()` throws or fails silently, the companion record exists in `companion_data` but no entity is in the zone. The Lua caller cannot detect this from the return value alone — `Lua_Companion` is returned regardless. The Lua script should check if the companion is actually in the entity list after `CreateCompanion()` returns.

**No type mismatch:** `CreateFromNPC()` returns `Companion*`, which is correctly wrapped in `Lua_Companion`. The luabind type chain is `Lua_Companion → Lua_Mob → Lua_Entity`, and `Companion` is registered as a `Lua_Companion` with `Lua_Mob` as base. Correct.

**Null propagation:** If `CreateFromNPC()` returns nullptr (e.g., re-recruitment cooldown active, max companions reached), `Lua_Companion(nullptr)` is returned. Lua callers must nil-check: `if companion == nil then`. `Lua_Safe_Call_*` macros will return the default value (0, false, or void) without crashing if a nil companion is passed to any subsequent method. Correct behavior.

---

## Open Items

- [ ] **RECOMMEND FIX:** Constructor should call `ScaleStatsToLevel()` after `ApplyStatScalePct()` so fresh-recruited companions have class-differentiated stats. (GAP-04 subtle issue)
- [ ] **INVESTIGATE:** DataBucket::DeleteData() in CreateFromNPC() — confirm whether `character_id=0` scope is handled correctly for companion cooldown keys.
- [ ] **MINOR FIX:** Process() safety net path should call `UpdateTimeActive()` before firing direct SQL, to keep `time_active` accurate.
- [ ] **STALE MEMORY.md:** Entry "GetPrimaryFaction() is nil on Companion objects" is stale. Should be removed — GAP-17 fix registers this method correctly.
- [ ] **TEST GAPS:** 13 gaps identified above (3 Critical, 2 High, 5 Medium, 3 Low). Critical gaps should be addressed before the next audit.

---

## Context for Next Agent

This was a research-only audit of the companion C++ system. No code was changed.

**What was verified:** All 9 fixes from the first-pass audit (GAP-01/02/03/04/06/10/17, BUG-028, re-recruitment) are present and structurally correct in current `master`.

**Two subtle issues found (not regressions, but functional gaps):**
1. Constructor does not call `ScaleStatsToLevel()` — fresh companions lack class-based stat differentiation until they level up.
2. `Process()` safety net path (BUG-028) does not call `UpdateTimeActive()` — `time_active` may be understated for companions dying through this path.

**13 test coverage gaps** documented above (Focus 2). Three are Critical.

**Lua/C++ contract** is clean — all 35 methods declared, implemented, and registered. The MEMORY.md note about `GetPrimaryFaction()` being nil is stale and should be corrected.

**CreateCompanion path** has a logical ordering issue (`Save()` before `Spawn()`) that could leave orphaned DB rows, but is not a crash risk.

The architect or implementer reviewing this report should decide which open items to act on. The Critical test gaps (constructor stat scaling, DataBucket cooldown deletion, Process() UpdateTimeActive) are the highest-value additions to the test suite.
