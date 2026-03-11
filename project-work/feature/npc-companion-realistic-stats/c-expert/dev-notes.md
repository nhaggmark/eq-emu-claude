# npc-companion-realistic-stats — Dev Notes: C Expert

> **Feature branch:** `feature/npc-companion-realistic-stats`
> **Agent:** c-expert
> **Task(s):** Phase 2 — Combat Skills & Special Attacks
> **Date started:** 2026-03-10
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| Phase 1 | Weapon damage path, SetAttackTimer, rules | — | **Complete** (prior session) |
| Phase 2 | Triple attack, CheckTripleAttack, DoAttackRounds | Phase 1 | **In Progress** |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `zone/companion.h` | 432 | SetAttackTimer declared, Attack declared, Phase 1 done |
| `zone/companion.cpp` | ~1500 | Attack() override with weapon damage + damage bonus already done in Phase 1 |
| `zone/attack.cpp` | 6938-7000 | `Mob::DoMainHandAttackRounds()` — UseLiveCombatRounds=true path only does double attack, NO triple attack |
| `zone/mob.cpp` | 4696-4712 | `CanThisClassTripleAttack()` — for non-IsClient, uses `GetSkill(SkillTripleAttack) > 0` |
| `zone/bot.cpp` | 2047-2088 | `Bot::CheckTripleAttack()` — skill-based with ClassicTripleAttack=false path |
| `zone/bot.cpp` | 2851-2947 | `Bot::DoAttackRounds()` — includes triple attack check, flurry |
| `zone/mob_ai.cpp` | 1182-1183 | `DoMainHandAttackRounds(target)` called from `Mob::AI_Process()` |
| `zone/mob.h` | 270-283 | `DoMainHandAttackRounds` NOT virtual; `ProcessAttackRounds` NOT virtual |
| `common/ruletypes.h` | 606 | `UseLiveCombatRounds=true` (default and DB value confirmed) |
| DB: skill_caps | skill_id=74 | Only class_id=16 (Berserker) has SkillTripleAttack; Warriors, Monks, Rangers do NOT |
| DB: rule_values | | `UseLiveCombatRounds=true`, `ClassicTripleAttack=false`, `ClassicTripleAttackChance*=100` |

### Key Findings

1. **Phase 1 is fully done**: Damage bonus (GetWeaponDamageBonus) is already applied in Companion::Attack() at lines 566-581 of companion.cpp. Skills (dodge, parry, riposte, defense, offense) already work via the NPC constructor populating from SkillCaps.

2. **Triple attack gap**: `UseLiveCombatRounds=true` causes `Mob::DoMainHandAttackRounds()` to skip the triple attack block entirely. Only Bot (which has its own `DoAttackRounds()` called from Bot's Process) gets triple attack.

3. **No SkillTripleAttack in DB for Warriors/Monks/Rangers**: The skill_caps table only has SkillTripleAttack (74) for class_id=16 (Berserker). So `CanThisClassTripleAttack()` via GetSkill() returns false for all companion classes that should triple attack. We need our own level/class check.

4. **Correct approach**: Add `CheckTripleAttack()` and `DoAttackRounds()` to Companion (same pattern as Bot), then intercept the attack_timer in Companion::Process() before NPC::Process() consumes it.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/zone/companion.h` | Modify | Declare `CheckTripleAttack()`, `DoAttackRounds(Mob*, int)` |
| `eqemu/zone/companion.cpp` | Modify | Implement both, intercept attack_timer in Process() |
| `eqemu/zone/cli/tests/cli_companion_tests.cpp` | Modify | Add Suite 11: Phase 2 triple attack tests |

**Change sequence:**
1. Write failing tests (Suite 11) for triple attack behavior
2. Add declarations to companion.h
3. Implement `CheckTripleAttack()` in companion.cpp
4. Implement `DoAttackRounds()` in companion.cpp (mirrors Bot's version, no AA extras)
5. Intercept attack_timer in Companion::Process() before NPC::Process()
6. Build and run ALL tests (suites 1-11)

**What to test:**
- Warrior at 55 (below 56): CheckTripleAttack returns false
- Warrior at 56+: CheckTripleAttack returns true (can triple)
- Monk at 59 (below 60): CheckTripleAttack returns false
- Monk at 60+: CheckTripleAttack returns true
- Ranger at 60+: CheckTripleAttack returns true
- Rogue at 60: CheckTripleAttack returns false (rogues don't triple)
- Cleric at 60: CheckTripleAttack returns false
- DoAttackRounds() doesn't crash with target
- SetAttackTimer and Attack still work with Phase 1 (regression)

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `Bot::CheckTripleAttack()` | bot.cpp:2047 | Yes | Direct source read |
| `Bot::DoAttackRounds()` | bot.cpp:2851 | Yes | Direct source read |
| `Mob::CanThisClassTripleAttack()` | mob.cpp:4696 | Yes | Only Client/Bot via IsOfClientBot() |
| `ClassicTripleAttack` rule | DB query | Yes | false on this server |
| `UseLiveCombatRounds` rule | DB query | Yes | true on this server — confirms triple attack is blocked for base NPCs |
| `SkillTripleAttack` in DB | DB query | Yes | Only Berserker (class_id=16); Warriors/Monks/Rangers have none |
| PRD Phase 2 triple attack levels | PRD | Yes | Warriors 56+, Monks/Rangers 60+ |

### Plan Amendments

**Amendment 1**: Since `ClassicTripleAttack=false` on our server but `ClassicTripleAttack` code checks level 60 for warrior even in classic mode, and PRD wants warrior at 56+, we bypass CanThisClassTripleAttack() entirely in our CheckTripleAttack() and implement our own level/class check.

**Amendment 2**: The DoAttackRounds() does NOT replicate Bot's AA-based extra attack logic (ExtraAttackChance, GiveDoubleAttack thresholds, etc.) since companions don't have AAs. We implement a simpler version.

**Amendment 3**: For the Process() interception - we check attack_timer.Check(false) first (non-consuming peek) to see if it's ready. Then handle melee ourselves. NPC::Process() will then see attack_timer already consumed and skip the attack block. This works because `attack_timer.Check()` calls `Check(true)` internally which resets the timer.

Actually on re-reading: `Timer::Check()` with no arg resets the timer by default. If we call `attack_timer.Check()` in our Process() code, NPC::Process() will see it as NOT fired and won't attack again. This is exactly what we want.

### Verified Plan

**Plan confirmed with amendments above.**

The companion's Companion::Process() will:
1. Check if engaged and able to attack (same guard as Mob::AI_Process)
2. If attack_timer.Check() fires, call DoAttackRounds(target, slotPrimary)
3. If CanThisClassDualWield() and CheckDualWield() and attack_dw_timer.Check(), call DoAttackRounds(target, slotSecondary)
4. Call NPC::Process() which handles movement, spell AI, regen, everything except the (now-consumed) attack timer

---

## Stage 3: Socialize

No other agents are in the team for this phase. The architecture was reviewed and the approach is consistent with the architect's guidance (Bot pattern for DoAttackRounds). No cross-system impacts.

---

## Stage 4: Build

### Implementation Log

#### 2026-03-10 — Phase 2 TDD and implementation

**What:** Added Suite 11 tests for triple attack, implemented CheckTripleAttack() and DoAttackRounds(), intercepted attack_timer in Companion::Process()

**Where:**
- `eqemu/zone/companion.h` — declarations
- `eqemu/zone/companion.cpp` — implementations + Process() intercept
- `eqemu/zone/cli/tests/cli_companion_tests.cpp` — Suite 11

**Why:** Warriors at 56+, Monks/Rangers at 60+ should triple attack. This is blocked by UseLiveCombatRounds=true which skips the NPC triple attack path. Following Bot pattern to add companion-specific attack round handling.

**Notes:**
- CheckTripleAttack uses our own level/class check (not CanThisClassTripleAttack()) since SkillCaps lacks SkillTripleAttack for Warriors/Monks/Rangers
- DoAttackRounds omits AA-based extra attacks (companions don't have AAs)
- Process() intercepts attack_timer.Check() before NPC::Process() to take over melee

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| SkillCaps has no SkillTripleAttack for Warriors/Monks/Rangers | DB has it only for Berserker | Own level/class check in CheckTripleAttack() |
| UseLiveCombatRounds=true skips triple attack | Mob::DoMainHandAttackRounds live path only does double | Intercept attack_timer in Companion::Process() |
| DoMainHandAttackRounds is not virtual | mob.h design | Can't override, must intercept before NPC::Process() |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `eqemu/zone/companion.h` | Modified | Added CheckTripleAttack() and DoAttackRounds() declarations |
| `eqemu/zone/companion.cpp` | Modified | Implemented both + Process() timer intercept |
| `eqemu/zone/cli/tests/cli_companion_tests.cpp` | Modified | Added Suite 11 triple attack tests |

---

## Open Items

- [ ] After build succeeds, verify tests pass in Docker
- [ ] Damage bonus (already in Phase 1 Attack()) — confirmed working
- [ ] Combat skills (already working via SkillCaps) — confirmed by Suite 4 tests

---

## Context for Next Agent

Phase 2 adds triple attack to companion combat. The key implementation files:
- `companion.h`: `CheckTripleAttack()`, `DoAttackRounds()` declared
- `companion.cpp`: Both implemented + Process() intercept
- Test Suite 11 validates the level/class gating

Phase 1 (weapon damage, weapon delay, damage bonus) is fully implemented in the existing `Companion::Attack()` and `Companion::SetAttackTimer()` overrides. Damage bonus is at companion.cpp lines ~566-581. Skills work via NPC constructor.
