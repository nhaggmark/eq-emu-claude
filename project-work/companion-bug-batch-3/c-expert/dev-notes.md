# Companion Bug Batch 3 — Dev Notes: C Expert

> **Feature branch:** `bugfix/companion-bug-batch-3`
> **Agent:** c-expert
> **Task(s):** Tasks 1-4 (BUG-033, BUG-032, BUG-034)
> **Date started:** 2026-03-16
> **Current stage:** Build (Stage 4)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | BUG-033: Fix charm pet Go Away — restructure PET_GETLOST in client_packet.cpp | — | Complete |
| 2 | BUG-032: Strip all melee immunity special abilities in Companion::Spawn() | — | Complete |
| 3 | BUG-034: Diagnose mana regen slow — check SkillMeditate initialization | — | Complete |
| 4 | BUG-034: Fix based on diagnosis — SkillMeditate missing for caster classes in skill_caps | 3 | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `zone/client_packet.cpp` | 11318-11343 | PET_GETLOST case: `Charmed()` guard at 11319 fires before charm-break code at 11325 |
| `zone/companion.cpp` | 2325-2332 | Spawn() strips MeleeImmunity(19) and MagicImmunity(20) but not abilities 22,23,35,46,47,48 |
| `zone/companion.cpp` | 1397-1433 | CalcManaRegen(): formula uses `GetSkill(SkillMeditate)` which returns 0 for casters |
| `zone/companion.cpp` | 488-529 | SetDefensiveSkillsFromCaps(): includes SkillMeditate, but only sets it when cap>0 from DB |
| `common/emu_constants.h` | 549-575 | Confirms enum names: MeleeImmunityExceptBane=22, MeleeImmunityExceptMagical=23, etc. |
| `zone/mob.cpp` | 1100-1143 | GetArchetype(): Caster={Cleric,Druid,Shaman,Necro,Wiz,Mage,Enc}, Melee={War,Monk,Rogue,Bsk} |

### Key Findings

**BUG-033**: The `if (mypet->Charmed()) break;` at line 11319 fires for ALL charmed pets, including
the case where `GetPetType() == petCharmed`. The code at 11321 that calls `BuffFadeByEffect(Charm)`
is never reached. Fix: remove the early-break guard and fold the charmed check into the charm-break
path below.

**BUG-032**: `SetSpecialAbility(SpecialAbility::MeleeImmunity, 0)` strips ability 19, and
`MagicImmunity(20)` is also stripped. But abilities 22 (MeleeImmunityExceptBane), 23
(MeleeImmunityExceptMagical), 35 (HarmFromClientImmunity), 46 (RangedAttackImmunity), 47
(ClientDamageImmunity), and 48 (NPCDamageImmunity) are not stripped. Any NPC with these abilities
in their `special_abilities` field will produce INVULNERABLE when hit, blocking damage shields.

**BUG-034**: Critical finding — the `skill_caps` DB table only has SkillMeditate entries for
`class_id=7` (Monk). ALL caster classes (Cleric=2, Druid=6, Wizard=12, Enchanter=14, etc.) have
NO entries. `GetSkillCap(cls, SkillMeditate, lvl)` returns 0 for all caster companions. Since
`SetDefensiveSkillsFromCaps()` only calls `skills[skill] = cap` when `cap > 0`, SkillMeditate is
never set for casters. The regen formula degrades from ~13 to ~9 per tick at level 30.
Fix: compute meditate inline for non-Melee archetypes when DB cap is missing.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `zone/client_packet.cpp` | Modify | Remove `Charmed()` guard, fold into charm-break path |
| `zone/companion.cpp` | Modify | Add 6 more `SetSpecialAbility(..., 0)` calls in Spawn() |
| `zone/companion.cpp` | Modify | Fix SkillMeditate init in SetDefensiveSkillsFromCaps() |
| `zone/cli/tests/cli_companion_tests.cpp` | Modify | Add Suites 31, 32, 33 for BUG tests |

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `SpecialAbility::MeleeImmunityExceptBane` | `common/emu_constants.h:549` | Yes | =22 |
| `SpecialAbility::MeleeImmunityExceptMagical` | `common/emu_constants.h:550` | Yes | =23 |
| `SpecialAbility::HarmFromClientImmunity` | `common/emu_constants.h:562` | Yes | =35 |
| `SpecialAbility::RangedAttackImmunity` | `common/emu_constants.h:573` | Yes | =46 |
| `SpecialAbility::ClientDamageImmunity` | `common/emu_constants.h:574` | Yes | =47 |
| `SpecialAbility::NPCDamageImmunity` | `common/emu_constants.h:575` | Yes | =48 |
| `Mob::Charmed()` vs `IsCharmed()` | `zone/mob.h:1098,1309` | Yes | Both check `type_of_pet == PetType::Charmed` |
| `skill_caps` table structure | MariaDB query | Yes | `class_id`, `skill_id`, `level`, `cap` |
| SkillMeditate in DB | MariaDB query | Yes | ONLY class_id=7 (Monk) has entries — casters have none |
| `Archetype::Melee` classes | `zone/mob.cpp:1129-1137` | Yes | Warrior, Monk, Rogue, Berserker |

### Plan Amendments

DB query confirmed the root cause of BUG-034: casters have no SkillMeditate in `skill_caps`.
Fix is to compute it inline in `SetDefensiveSkillsFromCaps()` using the formula `min(5*level, 200)`
when DB returns 0 for a non-Melee class. This mirrors how EQ players gain meditate skill from level 1.

---

## Stage 3: Socialize

No blocking dependencies on other agents. All three bugs are C++-only. Plan is aligned with
architecture.md specification.

---

## Stage 4: Build

### Implementation Log

#### 2026-03-16 — BUG-034: Add SkillMeditate fallback for caster companions

**What:** In `SetDefensiveSkillsFromCaps()`, after the DB cap lookup, added a fallback:
if SkillMeditate cap is 0 AND the archetype is not Melee, compute meditate as `min(5*level, 200)`.
This matches the standard EQ progression (5 per level up to cap 200).
**Where:** `zone/companion.cpp:524-528`
**Why:** `skill_caps` DB only has Monk (class_id=7) meditate entries. All caster classes return 0.
**Notes:** The fallback only triggers when the DB truly has no cap (cap==0). If the DB is ever
patched with correct caster meditate caps, the DB value will take precedence automatically.

#### 2026-03-16 — BUG-032: Strip all immunity abilities in Companion::Spawn()

**What:** Added 6 more `SetSpecialAbility(..., 0)` calls after the existing two.
**Where:** `zone/companion.cpp:2330-2340`
**Why:** NPC special_abilities strings can set any of these immunity flags. If inherited, they
prevent melee hits on the companion, causing INVULNERABLE instead of damage, which blocks DS.

#### 2026-03-16 — BUG-033: Fix charm pet Go Away

**What:** Removed the early `if (mypet->Charmed()) break;` guard. Restructured PET_GETLOST
to check `GetPetType() == petCharmed || Charmed()` first and call `BuffFadeByEffect(Charm)`.
**Where:** `zone/client_packet.cpp:11318-11344`
**Why:** The guard was blocking the charm-break path. It was presumably intended to prevent
normal pet dismissal (Depop) on charmed pets, but it also blocked the charm-fade path.

#### 2026-03-16 — TDD: Added Suites 31, 32, 33

**What:** Added 3 new test suites verifying the fixes.
**Where:** `zone/cli/tests/cli_companion_tests.cpp:6943+`
**Why:** TDD requires tests before implementation. Tests verify:
- Suite 31: BUG-032 — all immunity abilities stripped in Spawn()
- Suite 32: BUG-033 — PET_GETLOST logic verification (structural, no charmed pet in unit test)
- Suite 33: BUG-034 — SkillMeditate non-zero for casters, CalcManaRegen > base for casters

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `zone/companion.cpp` | Modified | BUG-034: meditate fallback in SetDefensiveSkillsFromCaps(); BUG-032: strip additional immunity abilities in Spawn() |
| `zone/client_packet.cpp` | Modified | BUG-033: restructure PET_GETLOST to allow charm break |
| `zone/cli/tests/cli_companion_tests.cpp` | Modified | Added Suites 31-33 |

---

## Open Items

- [ ] BUG-033 cannot be unit-tested without a Client and charmed pet. The test suite verifies
      the structural fix (no Charmed() guard) via examining the logic path indirectly. In-game
      testing by game-tester is required to confirm actual charm-break behavior.

---

## Context for Next Agent

The three bugs were fixed in three files:

1. **BUG-033** (`client_packet.cpp:11318`): The `if (mypet->Charmed()) break;` guard was
   removed. PET_GETLOST now correctly calls `BuffFadeByEffect(SpellEffect::Charm)` for charmed pets.

2. **BUG-032** (`companion.cpp:Spawn()`): Added strips for abilities 22, 23, 35, 46, 47, 48
   after the existing strips for 19 and 20. Companions can now be hit normally regardless of
   source NPC special_abilities.

3. **BUG-034** (`companion.cpp:SetDefensiveSkillsFromCaps()`): Added fallback for SkillMeditate
   when DB returns 0 for non-Melee classes. Casters now get `min(5*level, 200)` as their meditate
   skill, matching standard EQ progression. This restores proper mana regen formula output.
