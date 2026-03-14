# Companion Authenticity Fixes — Dev Notes: c-expert

> **Feature branch:** `feature/companion-authenticity-fixes`
> **Agent:** c-expert
> **Task(s):** GAP-01, GAP-02, GAP-03, GAP-04, GAP-06
> **Date started:** 2026-03-14
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| GAP-01 | Enable critical hits for companions | — | In Progress |
| GAP-02 | Enable PC-only spells to target companions | — | In Progress |
| GAP-03 | Set class-appropriate defensive skills | — | In Progress |
| GAP-04 | Apply class-based stat differentiation | — | In Progress |
| GAP-06 | Class-based unarmed damage multiplier | — | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `zone/attack.cpp` | 5446 | NPC crit guard: `if (IsNPC() && !RuleB(Combat, NPCCanCrit)) { return; }` |
| `zone/spells.cpp` | 832, 838, 3940-3948 | pcnpc_only_flag checks — 832/838 use explicit IsClient/IsMerc/IsBot, 3940 uses IsOfClientBotMerc() |
| `zone/entity.cpp` | 5616-5619 | GetTargetsForConeArea: `if (pcnpc == 1 && !ptr->IsClient() && !ptr->IsMerc() && !ptr->IsBot())` |
| `zone/companion.cpp` | 290-321 | ScaleStatsToLevel — uniform scaling, no class differentiation |
| `zone/companion.cpp` | 48-148 | Constructor — no skill initialization |
| `zone/attack.cpp` | 3545-3584 | GetHandToHandDamage — returns 2 for non-Monk/Beastlord |
| `zone/bot.cpp` | 7347-7348 | Bot skill init: `skills[sindex] = SkillCaps::Instance()->GetSkillCap(class, skill, level).cap` |
| `common/skill_caps.h` | all | SkillCaps singleton, GetSkillCap(class_id, skill_id, level) returns .cap |

### Key Findings

1. **GAP-01**: Companions are blocked from crits because `IsNPC()=true` and the NPC crit guard fires before any crit logic. Adding `!IsCompanion()` to the guard bypasses it.

2. **GAP-02**: Three distinct checks exist for pcnpc_only_flag=PC:
   - `spells.cpp:832` — explicit list without companion (BUG: excludes companions)
   - `spells.cpp:3940` — uses `IsOfClientBotMerc()` which Companion overrides to return true (ALREADY WORKS)
   - `entity.cpp:5616` — explicit list without companion (BUG: excludes companions from cone spells)

3. **GAP-03**: Companion constructor never calls `SkillCaps`. Skills array is zero. This means `SkillDefense` is 0, `SkillParry` is 0, etc. Must call SkillCaps after each level change.

4. **GAP-04**: ScaleStatsToLevel uniformly multiplies all stats. No class differentiation.

5. **GAP-06**: `GetHandToHandDamage()` returns 2 for all non-Monk/Beastlord classes. Override in Companion to apply class-based multiplier using level.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `zone/attack.cpp` | Modify | GAP-01: add `!IsCompanion()` to NPC crit guard |
| `zone/spells.cpp` | Modify | GAP-02: add `!spell_target->IsCompanion()` at line 832, `\|\| spell_target->IsCompanion()` at 838 |
| `zone/entity.cpp` | Modify | GAP-02: add `&& !ptr->IsCompanion()` at line 5616 |
| `zone/companion.cpp` | Modify | GAP-03: new SetDefensiveSkillsFromCaps(), call in constructor and ScaleStatsToLevel |
| `zone/companion.cpp` | Modify | GAP-04: add class multipliers in ScaleStatsToLevel after base scaling |
| `zone/companion.cpp` | Modify | GAP-06: override GetHandToHandDamage() |
| `zone/companion.h` | Modify | Declare new methods |
| `zone/cli/tests/cli_companion_tests.cpp` | Modify | Add Suite 19 |

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `SkillCaps::Instance()->GetSkillCap(class, skill, level).cap` | bot.cpp:7348, skill_caps.h | Yes | Returns cap value for class/skill/level combo |
| `skills[sindex]` array on Mob | bot.cpp:7347 | Yes | Direct member array, populated in bot init |
| `IsOfClientBotMerc()` on Companion | companion.h:114 | Yes | Returns true — spells.cpp:3940 already works |
| `GetHandToHandDamage()` | attack.cpp:3545 | Yes | Returns 2 for non-Monk/Beastlord |

### Plan Amendments

Plan confirmed — no amendments needed after research.

---

## Stage 3: Socialize

Standalone C++ changes. No cross-system dependencies to socialize.

---

## Stage 4: Build

### Implementation Log

#### 2026-03-14 — Suite 19 tests added (TDD)

Added `TestCompanionAuthenticityFixes()` suite covering:
- 19.1: Companion IsCompanion() returns true (guard validity)
- 19.2: GAP-01 — crit guard bypassed for companions (structural check)
- 19.3: GAP-02 — PC-only spell target check includes companions (structural check)
- 19.4: GAP-03 — Defense skill is non-zero after construction
- 19.5: GAP-03 — Parry skill is non-zero for warrior-class companion
- 19.6: GAP-04 — Warrior STR > INT after stat scaling
- 19.7: GAP-04 — Caster INT > STR after stat scaling
- 19.8: GAP-06 — Unarmed caster does less damage than melee

#### 2026-03-14 — GAP-01: attack.cpp

**What:** Added `!IsCompanion()` to the NPC crit guard
**Where:** `eqemu/zone/attack.cpp:5446`
**Why:** Companions return IsNPC()=true but should behave like PCs for crits

#### 2026-03-14 — GAP-02: spells.cpp + entity.cpp

**What:** Added companion to PC-type spell targeting checks
**Where:** `spells.cpp:832`, `spells.cpp:838`, `entity.cpp:5616`
**Why:** PC-only spells excluded companions from beneficial targeting

#### 2026-03-14 — GAP-03: companion.cpp

**What:** Added `SetDefensiveSkillsFromCaps()` method, called from constructor and ScaleStatsToLevel
**Where:** `eqemu/zone/companion.cpp`, `eqemu/zone/companion.h`
**Why:** Zero skills means AC formula uses zero defense, parry/dodge never fire

#### 2026-03-14 — GAP-04: companion.cpp

**What:** Added class-based stat multipliers in ScaleStatsToLevel() after base scaling
**Where:** `eqemu/zone/companion.cpp:300-320`
**Why:** All classes should have class-appropriate primary stat emphasis

#### 2026-03-14 — GAP-06: companion.cpp

**What:** Override `GetHandToHandDamage()` in Companion with class-based multiplier
**Where:** `eqemu/zone/companion.cpp`, `eqemu/zone/companion.h`
**Why:** All unarmed companions were doing 2 damage regardless of class

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| spells.cpp:3940 already handles companions | IsOfClientBotMerc() returns true | No change needed for that location |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `zone/attack.cpp` | Modified | GAP-01 crit guard |
| `zone/spells.cpp` | Modified | GAP-02 PC-only targeting (2 locations) |
| `zone/entity.cpp` | Modified | GAP-02 cone spell targeting |
| `zone/companion.cpp` | Modified | GAP-03 skills, GAP-04 stat multipliers, GAP-06 unarmed damage |
| `zone/companion.h` | Modified | New method declarations |
| `zone/cli/tests/cli_companion_tests.cpp` | Modified | Suite 19 |

---

## Open Items

- [ ] Build and run full test suite to confirm all 19 suites pass

---

## Context for Next Agent

All 5 gaps implemented. See Implementation Log above. Full test suite must pass.
Build command: `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
Test command: `docker exec akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && ./bin/zone tests:companion 2>&1"`
