# Phase 1 Review: Equipment Drives Damage

> **Reviewer:** Senior Code Reviewer (Architect + Game Designer + Lore Master perspectives)
> **Date:** 2026-03-10
> **Feature:** npc-companion-realistic-stats, Phase 1
> **Files reviewed:**
> - `eqemu/zone/companion.h` (lines 116-118: new declarations)
> - `eqemu/zone/companion.cpp` (lines 442-750: Attack and SetAttackTimer)
> - `eqemu/common/ruletypes.h` (lines 1215-1218: UseWeaponDamage rule)
> - `eqemu/zone/cli/tests/cli_companion_tests.cpp` (Suite 9, lines 732-887)
> - `eqemu/zone/cli/tests/cli_companion_test_util.h` (full file)

---

## Verdict: APPROVED WITH ISSUES

Phase 1 is a solid, well-structured implementation that faithfully follows the
architecture plan. The core weapon-damage path works correctly, the rule toggle
gates all behavior as specified, and the fallback to NPC::Attack() is clean.
However, there are several issues that should be addressed before merging --
one critical safety concern, a few important omissions relative to the
architecture and the Client/Bot reference path, and several test coverage gaps.

---

## Architecture Compliance Checklist

### Does Companion::Attack() follow the Client/Bot pattern from Mob::Attack()?

**PASS.** The implementation at companion.cpp:442-640 closely mirrors
Mob::Attack() (attack.cpp:1566-1777). The overall structure is:

1. Safety checks (owner/group) -- retained from original Companion::Attack()
2. Rule gate -- falls back to NPC::Attack() when UseWeaponDamage=false
3. Weapon retrieval via GetInv().GetItem() (Client/Bot pattern, not NPC pattern)
4. IsWeapon() null-guard with fallback to NPC::Attack()
5. DivineAura, IsAttackAllowed, FaceTarget checks
6. AttackAnimation with ItemInstance* (Client pattern)
7. GetWeaponDamage() for base damage
8. DoDamageCaps, bane/elemental damage, damage bonus
9. DoAttack, Damage, MeleeLifeTap, procs

### Does it use GetWeaponDamage() for damage calculation?

**PASS.** Line 538: `my_hit.base_damage = GetWeaponDamage(other, weapon_inst, &hate);`
This is the correct shared Mob function that reads weapon->Damage and applies
immunity checks. Matches the Client path at attack.cpp:1640.

### Does it apply GetWeaponDamageBonus() for level 28+ melee classes?

**PASS.** Lines 569-573:
```cpp
if (Hand == EQ::invslot::slotPrimary && GetLevel() >= 28 && IsWarriorClass()) {
    int ucDamageBonus = static_cast<int>(GetWeaponDamageBonus(weapon));
    my_hit.min_damage = ucDamageBonus;
    hate += ucDamageBonus;
}
```
This matches the Client path at attack.cpp:1676-1685 precisely. The
`#ifndef EQEMU_NO_WEAPON_DAMAGE_BONUS` guard is also correctly applied.

### Does it handle bane/elemental damage?

**PASS.** Lines 551-564 implement bane body type, bane race, and elemental
damage with the correct formulas. The logic matches NPC::Attack() lines
2332-2347. One notable difference: the NPC::Attack path has a guard at
lines 2350-2353 that zeros out eleBane when `!RuleB(NPC, UseItemBonusesForNonPets)`
and `!GetOwner()`. The Companion path does NOT have this guard, which is
actually CORRECT behavior -- companions SHOULD use item bonuses, and they
always have item bonuses enabled via CalcBonuses. This is a deliberate and
beneficial deviation.

### Does the rule toggle correctly gate all new behavior?

**PASS.** Line 476: `if (!RuleB(Companions, UseWeaponDamage))` immediately
falls through to `NPC::Attack()`, preserving 100% of pre-change behavior.
The SetAttackTimer() override at line 650 has the same gate, falling to
`NPC::SetAttackTimer()`. Clean, clear, and correct.

### Does it fall back to NPC::Attack() when no weapon equipped?

**PASS.** Lines 491-493: When `!weapon_inst || !weapon_inst->IsWeapon()`,
the code falls back to `NPC::Attack()`. This handles unarmed companions,
monks, and freshly recruited companions correctly.

### Does it fall back to NPC::Attack() when rule is false?

**PASS.** Line 476-478. Clean delegation.

### Does SetAttackTimer() use weapon Delay correctly?

**PASS.** Lines 646-750 implement a thorough SetAttackTimer() override that
closely mirrors Client::SetAttackTimer() (attack.cpp:6682-6782). It:
- Reads weapon from GetInv() (Client pattern)
- Validates item type (IsClassCommon, Damage > 0, Delay > 0, valid ItemType)
- Falls back to GetHandToHandDelay() for unarmed primary
- Applies haste via GetHaste() * 0.01f
- Applies HundredHands modifier
- Respects MinHastedDelay cap
- Handles dual wield timer disable for classes that cannot DW
- Handles two-hander disabling DW timer
- Sets same-delay animation sync flag

### Does SetAttackTimer() apply haste modifiers?

**PASS.** Line 657: `float haste_mod = GetHaste() * 0.01f;`
Line 720: `int speed = static_cast<int>(delay / haste_mod);`
Lines 727-731: HundredHands applied with both revamp and legacy paths.

### Is SetAttackTimer() called at the right times?

**PASS.** SetAttackTimer() is virtual and called from CalcBonuses() ->
Mob::CalcBonuses() -> SetAttackTimer(). Since GiveItem() calls CalcBonuses()
and LoadEquipment() calls CalcBonuses(), the timer updates automatically
when weapons change. No additional call sites needed.

### Are there any modifications to NPC or Mob base classes?

**PASS.** No changes to NPC or Mob base classes. All changes are Companion
class overrides, as specified. The only change outside the Companion class
is the rule definition in ruletypes.h.

### Does the implementation handle dual wield / offhand attacks?

**PASS.** Line 484: Secondary hand weapon retrieval works correctly.
Lines 515-523: Secondary hand validation checks for 1H weapons only.
Lines 576-581: Sinister Strikes offhand damage bonus is handled.
SetAttackTimer() lines 678-683 correctly disable DW timer when the class
cannot dual wield or has a two-hander equipped.

### Does it handle the case where Primary is empty but Secondary has a weapon?

**PASS.** When Attack() is called with Hand=slotSecondary, it retrieves the
secondary weapon. When called with Hand=slotPrimary with no weapon,
weapon_inst is null, triggering the NPC::Attack() fallback. This is correct.

### Does it handle monks/beastlords (hand-to-hand, no weapon)?

**PASS.** For monks with no weapon equipped, GetInv().GetItem(slotPrimary)
returns null, triggering the NPC::Attack() fallback at line 492. The
SetAttackTimer() uses GetHandToHandDelay() for unarmed primary (line 708).

---

## Game Design Compliance Checklist

### Will a player notice their companion hitting harder with a better weapon?

**PASS.** The weapon's Damage field directly drives base_damage via
GetWeaponDamage(). Upgrading from a Rusty Longsword (Dmg: 5) to a Fine
Steel Long Sword (Dmg: 9) will produce visibly higher damage numbers.
The difference is dramatic and immediate.

### Will attack speed change with different weapon delays?

**PASS.** SetAttackTimer() reads weapon->Delay and converts to milliseconds.
A weapon with delay 20 produces approximately 2000ms/haste between swings,
while delay 40 produces approximately 4000ms/haste. The player will see
faster or slower attack rates depending on weapon choice.

### Does haste gear/buff affect companion attack speed now?

**PASS.** GetHaste() is called at line 657 and applied to the weapon delay.
Both spell haste (spellbonuses.haste) and item haste (itembonuses.haste)
are included in GetHaste(). HundredHands is also applied (lines 727-731).

### Is the damage formula producing reasonable values?

**PASS.** The formula is identical to the Client/Bot path: GetWeaponDamage()
+ DoDamageCaps() + bane/ele + damage bonus. Then DoAttack() applies the
full mitigation chain (CheckHitChance, AvoidDamage, MeleeMitigation,
TryCriticalHit, CommonOutgoingHitSuccess). The output will be in the same
range as a player of equivalent level and gear.

### Does the damage scale appropriately with weapon quality?

**PASS.** Weapon damage is a direct input to the damage formula. Higher
weapon damage = higher base_damage = higher average hits. The damage bonus
from weapon delay (at level 28+) also scales: slower weapons get larger
bonuses, matching the EQ damage bonus table.

### Are there scenarios where a companion would deal MORE damage than a comparably-geared player?

**Unlikely.** The damage formula is identical to the Client path. However,
companions lack AAs (no Fury of the Ages, no extra crit chance AAs, etc.)
and their offense skill comes from SkillCaps (not trained by practice).
A companion should deal slightly LESS damage than a comparably-geared player,
which is the desired behavior per the PRD (70-85% of player performance).

### Are there scenarios where upgrading a weapon would make the companion WEAKER?

**No, with one caveat.** A weapon with higher Damage will always produce
higher base_damage. However, a weapon with lower delay (faster) produces
a smaller damage bonus at level 28+. In extreme cases (very fast, high-damage
weapon), the per-hit damage bonus is lower, but this is offset by attacking
more frequently. Net DPS should always increase with a better weapon. This
matches player behavior exactly.

---

## Test Coverage Checklist

### Do the tests cover the UseWeaponDamage=true path?

**PASS.** Suite 9 (TestCompanionWeaponDamagePath) tests with the rule at
its default value (true). Tests 9.2-9.8 all exercise the UseWeaponDamage=true
code path.

### Do the tests cover the UseWeaponDamage=false fallback?

**FAIL -- MISSING.** There is no test that sets `UseWeaponDamage=false` and
verifies that Companion::Attack() and SetAttackTimer() fall back to NPC
behavior. The test scaffolding plan (Part 4) explicitly calls for this:
> "SetAttackTimer falls back to NPC delay when rule=false"

This is an important gap. The test should temporarily set the rule to false,
call SetAttackTimer() and Attack(), and verify NPC-path behavior.

### Do the tests cover unarmed/no-weapon fallback?

**PASS.** Test 9.2 calls SetAttackTimer() with no weapon (verifies no crash).
Test 9.5 verifies GetBaseDamage() remains accessible when unarmed.

### Do the tests verify damage values are in expected ranges?

**PARTIAL PASS.** Tests verify that weapon->Damage > 0 and
GetBaseDamage() > 0 (data sanity). However, no test verifies that the actual
damage dealt to a target is derived from the weapon rather than npc_types.
This is understandable since damage is RNG-dependent and hard to assert in a
single swing, but the scaffolding plan anticipated this gap.

### Do the tests verify attack speed changes with weapon delay?

**PARTIAL PASS.** Tests 9.3 verifies that slow and fast weapons have the
expected delay values, and that SetAttackTimer() does not crash. However,
since attack_timer is a protected member, the test cannot directly read the
timer period. The test verifies the INPUT (weapon delay) but not the OUTPUT
(timer value). This is a practical limitation of the test infrastructure.

### Do the tests verify damage bonus for level 28+ warriors?

**PASS.** Test 9.7 creates a level 28+ warrior, equips a weapon, and calls
GetWeaponDamageBonus() directly, asserting the return value is > 0.

### Are there tests for edge cases (monk, very fast weapon, very slow weapon)?

**FAIL -- MISSING.** No test creates a monk companion and verifies the
unarmed fallback behavior. No test uses extreme delay values (e.g., delay=10
very fast, delay=99 very slow). The scaffolding plan called for monk
testing specifically.

### Are the existing baseline tests (Suites 1-8) still passing?

**Assumed PASS.** The Suite 9 tests are additive. Suites 1-8 test pre-existing
behavior that should not be affected by the Phase 1 changes since those
suites do not set UseWeaponDamage=false.

### Are there important scenarios that are NOT tested?

Yes, several:

1. **UseWeaponDamage=false path** (mentioned above)
2. **Dual wield with weapon damage** -- no test equips weapons in both hands
   and verifies both Attack(slotPrimary) and Attack(slotSecondary) work
3. **Two-hander disables DW timer** -- not tested
4. **Monk/Beastlord unarmed fallback** -- not tested
5. **Ranged weapon delay** -- SetAttackTimer handles slotRange but no test
   exercises it
6. **Damage bonus NOT applied to non-warrior classes** -- test only checks
   that warriors get the bonus, not that wizards/rogues do NOT
7. **Damage bonus NOT applied below level 28** -- not tested
8. **Weapon swap mid-combat** -- not tested (may be impractical in CLI tests)
9. **Bane/elemental damage from weapon** -- not tested
10. **Non-weapon item in primary slot** -- what happens if armor is put in
    the primary slot? The IsWeapon() check should catch this, but no test
    verifies it.

---

## Safety Review

### Can any of the new code paths crash (null pointers, division by zero)?

**One concern identified: potential division by zero.**

At companion.cpp line 720:
```cpp
int speed = static_cast<int>(delay / haste_mod);
```

If `GetHaste()` returns 0 (or very close to zero due to inhibit melee effects),
`haste_mod` would be 0.0f, causing a floating-point division by zero. While
this typically produces infinity (not a crash) in IEEE 754, the subsequent
`static_cast<int>` of infinity is **undefined behavior** in C++.

**Severity: CRITICAL.**

The Client::SetAttackTimer() at attack.cpp:6682 has the same pattern, so this
is not a regression introduced by the Companion code -- it would also affect
Clients. However, the Companion implementation should be at least as safe as
the Client implementation. I recommend adding a guard:
```cpp
if (haste_mod <= 0.0f) haste_mod = 0.01f; // prevent division by zero
```

This is the same issue in both Client and NPC SetAttackTimer() paths, but since
this is new code being written, it should be defensive.

### Is GetInv().GetItem() null-checked before dereferencing?

**PASS.** Line 491: `if (!weapon_inst || !weapon_inst->IsWeapon())` checks
before any dereference. Line 513: `weapon_inst->GetItem()` is called only
after the IsWeapon() check (which internally verifies GetItem() is non-null).
Line 688 in SetAttackTimer: `if (ci)` before accessing `ci->GetItem()`.

### Is weapon->GetItem() null-checked?

**PASS.** The code retrieves `weapon = weapon_inst->GetItem()` at line 513,
after IsWeapon() has confirmed the item exists. In SetAttackTimer, the code
checks `if (ItemToUse != nullptr)` before accessing any fields.

### Are there any thread safety concerns?

**PASS.** The EQEmu server is single-threaded for zone processing. All
companion attack logic runs in the zone's main loop. No thread safety
concerns.

### Does the code handle the case where an item in the slot is not a weapon?

**PASS.** Line 491: `weapon_inst->IsWeapon()` check. If a non-weapon item
(like armor) is placed in the primary slot via a bug, the code falls back
to NPC::Attack(). In SetAttackTimer(), line 694-700 validates that the item
is ClassCommon, has non-zero Damage/Delay, and is a valid weapon ItemType.

---

## Issues Found

### CRITICAL Issues

**C1: Potential division by zero in SetAttackTimer (line 720)**

`float haste_mod = GetHaste() * 0.01f;` can produce 0.0f if GetHaste()
returns 0 (e.g., due to 100% melee inhibition). The subsequent
`delay / haste_mod` is undefined behavior if haste_mod is zero.

File: `eqemu/zone/companion.cpp`, line 720.

**Recommendation:** Add a minimum floor to haste_mod:
```cpp
float haste_mod = std::max(0.01f, GetHaste() * 0.01f);
```

### IMPORTANT Issues

**I1: Missing ShieldEquipDmgMod from Mob::Attack()**

The Client/Bot path at attack.cpp:1651-1655 applies ShieldEquipDmgMod:
```cpp
auto shield_inc = spellbonuses.ShieldEquipDmgMod + itembonuses.ShieldEquipDmgMod + aabonuses.ShieldEquipDmgMod;
if (shield_inc > 0 && HasShieldEquipped() && Hand == EQ::invslot::slotPrimary) {
    my_hit.base_damage = my_hit.base_damage * (100 + shield_inc) / 100;
    hate = hate * (100 + shield_inc) / 100;
}
```

The Companion::Attack() does NOT include this. While ShieldEquipDmgMod
is rare in Classic-Luclin content, it is present in the Client/Bot reference
path that the architecture says to follow.

File: `eqemu/zone/companion.cpp`, between lines 548 and 550 (after DoDamageCaps,
before bane damage).

**Recommendation:** Add the ShieldEquipDmgMod block for completeness, or
document as an intentional omission. This is a low-impact issue for
Classic-Luclin but breaks pattern fidelity.

**I2: Proc call uses ItemData* instead of the NPC overload convention**

At lines 624-628, the code calls:
```cpp
TryWeaponProc(nullptr, weapon, other, Hand);
TrySpellProc(nullptr, weapon, other, Hand);
```

Where `weapon` is `const EQ::ItemData*`. The comment at line 623 says
"TryWeaponProc expects ItemData* (NPC overload), not ItemInstance*". This is
correct for the NPC overload. However, the Client/Bot path in Mob::Attack()
passes the full `ItemInstance*` weapon pointer. Since companions have
ItemInstance objects in inventory, using the ItemInstance overload (if it
exists) would be more correct and ensure proc rate calculations that depend
on ItemInstance data work properly.

File: `eqemu/zone/companion.cpp`, lines 624-628.

**Recommendation:** Investigate whether there is an ItemInstance* overload
for TryWeaponProc/TrySpellProc and use it if available. If only the
ItemData* overload exists for NPCs, the current code is acceptable.

**I3: Missing test for UseWeaponDamage=false fallback**

The test scaffolding plan explicitly calls for a test that sets
UseWeaponDamage to false and verifies NPC-path behavior. This is missing
from Suite 9.

File: `eqemu/zone/cli/tests/cli_companion_tests.cpp`, Suite 9.

**Recommendation:** Add a test that:
1. Sets the rule to false via RuleManager
2. Calls SetAttackTimer() and Attack()
3. Verifies no crash and that the NPC path is taken
4. Restores the rule to true

**I4: Missing test for dual-wield weapon damage**

No test equips weapons in both primary and secondary slots and verifies
both attack hands work with the weapon damage path. Dual wield is
explicitly called out in the PRD:
> "Player equips a second weapon in the companion's off-hand. The companion
> now dual-wields, with the off-hand weapon's damage used for secondary attacks."

File: `eqemu/zone/cli/tests/cli_companion_tests.cpp`, Suite 9.

### SUGGESTIONS (Nice to Have)

**S1: Add LogCombatDetail calls for debugging**

The Client/Bot path at attack.cpp:1631 and 1701 includes LogCombatDetail
messages showing weapon name, skill, base damage, and min damage. The
Companion path has no logging. Adding equivalent log statements would
greatly aid debugging weapon damage issues:
```cpp
LogCombatDetail("Companion attacking with [{}] in slot [{}] using skill [{}]",
    weapon->Name, Hand, my_hit.skill);
```

File: `eqemu/zone/companion.cpp`, after line 533 and after line 563.

**S2: Consider adding a test for non-weapon item in primary slot**

Verify that placing a non-weapon item (e.g., armor) in the primary slot
falls back to NPC::Attack() correctly. This is an edge case that the
IsWeapon() check handles, but a test would document the behavior.

**S3: Consider adding a test for monk companion (class=7)**

The PRD specifically calls out monks:
> "No weapon equipped: Fall back to npc_types.max_dmg / npc_types.min_dmg
> (preserving current behavior for unarmed/monk companions)."

A test creating a monk companion, leaving it unarmed, and verifying
GetBaseDamage() > 0 and Attack() works would cover this.

**S4: Emoji usage in test output**

The test utility helpers (`cli_companion_test_util.h`) use emoji characters
in output strings (lines 225-288). While functional, these may not render
correctly in all terminal environments, particularly when running tests
inside Docker containers or via SSH. The existing `RunTest()` function in
`cli_test_util.cpp` uses plain text `[PASS]`/`[FAIL]` markers. The new
helpers should match this convention for consistency.

File: `eqemu/zone/cli/tests/cli_companion_test_util.h`, lines 225-288.

**S5: Ranged weapon timer in SetAttackTimer()**

SetAttackTimer() handles slotRange (line 669-670) with a timer and item
lookup, but no tests exercise this path. This is acceptable for Phase 1
(the PRD marks ranged attacks as lower priority), but should be tracked
for later coverage.

---

## Lore / Feel Review

### Does this make companion combat feel more like playing with a real player?

**PASS.** Before this change, giving a companion a Lamenter's Blade vs a
Rusty Longsword made zero difference to melee damage output. After this
change, weapon choice matters. The companion's attack rate changes with
weapon delay, damage scales with weapon quality, and level 28+ melee
companions get the damage bonus that all melee characters receive. This
is exactly how a real player's combat works.

### Would a Classic-Luclin EQ veteran notice anything "off" about the damage?

**No concerns.** The damage formula is the same one used for player characters.
GetWeaponDamage() reads the weapon's Damage field, GetWeaponDamageBonus()
uses the standard EQ damage bonus table, and all mitigation (AvoidDamage,
MeleeMitigation, TryCriticalHit, CommonOutgoingHitSuccess) goes through
the shared Mob pipeline. A veteran watching combat logs would see damage
numbers consistent with what they expect from a player wielding the same
weapon.

### Are there any anachronistic mechanics being applied?

**No.** All mechanics in the implementation are core Classic-era systems:
- Weapon damage has existed since EQ launch
- The damage bonus table is the pre-PoP table (standard in the codebase)
- Bane and elemental damage are Classic-era features
- Haste and HundredHands are Classic-era features
- No post-Luclin mechanics (heroic stats, combat abilities, etc.) are used

### Does weapon-based combat feel natural for an EQ group?

**PASS.** In live EQ, every group member's damage comes from their weapon.
An NPC warrior companion that hits based on its weapon creates the same
feel as grouping with a real warrior. The player's investment in finding
and equipping good weapons on their companions now has the same payoff
as equipping their own character -- which is exactly how a Classic EQ
server should work for a 1-3 player group.

---

## Summary of Findings

### What Was Done Well

1. **Clean architecture.** All changes are Companion class overrides with
   no modifications to NPC or Mob base classes. The rule toggle cleanly
   gates all new behavior. This is exactly what the architecture specified.

2. **Faithful Client/Bot path replication.** The Attack() implementation
   follows the Mob::Attack() Client/Bot path closely, including hate
   calculation, damage caps, damage bonus, bane/elemental damage, and
   the post-attack proc chain.

3. **Thorough SetAttackTimer().** The timer override handles all edge cases:
   unarmed fallback, dual wield disable, two-hander detection, ranged
   weapons, HundredHands, haste, and minimum delay cap. The item type
   validation is more thorough than strictly necessary, which is defensive
   and correct.

4. **Comprehensive test scaffolding.** Suites 1-8 provide excellent baseline
   coverage of companion subsystems. The test infrastructure (dynamic NPC
   lookup, weapon finder, cleanup helpers) is well-designed and reusable.

5. **Safety checks preserved.** The owner/group attack safety checks from
   the original Companion::Attack() are retained at the top of the method,
   ensuring companions never attack their owner or group members.

### Issues to Address Before Merge

| # | Severity | Issue | File:Line |
|---|----------|-------|-----------|
| C1 | Critical | Division by zero when haste_mod = 0 | companion.cpp:720 |
| I1 | Important | Missing ShieldEquipDmgMod block | companion.cpp:548 |
| I2 | Important | Proc calls use ItemData* not ItemInstance* | companion.cpp:624 |
| I3 | Important | Missing test: UseWeaponDamage=false fallback | cli_companion_tests.cpp |
| I4 | Important | Missing test: dual-wield weapon damage | cli_companion_tests.cpp |

### Test Coverage Summary

| Scenario | Covered? | Notes |
|----------|----------|-------|
| UseWeaponDamage=true, weapon equipped | Yes | Test 9.4 |
| UseWeaponDamage=true, no weapon | Yes | Tests 9.2, 9.5 |
| UseWeaponDamage=false fallback | NO | Missing |
| Damage bonus level 28+ warrior | Yes | Test 9.7 |
| Damage bonus < level 28 | NO | Missing |
| Damage bonus non-warrior class | NO | Missing |
| Attack timer with weapon delay | Partial | Verifies delay values, not timer output |
| Dual wield weapon damage | NO | Missing |
| Two-hander disables DW | NO | Missing |
| Monk unarmed fallback | NO | Missing |
| Bane/elemental damage | NO | Missing |
| Null target safety | Yes | Tests 9.6 |
| CalcBonuses chain | Yes | Test 9.8 |
| Non-weapon in weapon slot | NO | Missing |
| Ranged weapon | NO | Missing |
| Sinister Strikes (offhand DB) | NO | Missing |

### Recommendation

Fix C1 (division by zero guard) before merging. I1 and I2 can be addressed
in a follow-up if desired, as they are low-impact for Classic-Luclin content.
I3 and I4 (missing tests) should be added as part of the Phase 1 validation
pass or in a follow-up commit.

With C1 fixed, Phase 1 is ready to merge and will deliver the "Weapons Come
Alive" experience described in the PRD.
