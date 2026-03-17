# Companion Bug Batch 3 — Architecture & Implementation Plan

> **Feature branch:** `bugfix/companion-bug-batch-3`
> **PRD:** N/A (bug batch — triaged from bug reports)
> **Author:** architect
> **Date:** 2026-03-16
> **Status:** Approved

---

## Executive Summary

This plan addresses three companion system bugs: BUG-032 (damage shields showing INVULNERABLE instead of reflecting damage), BUG-033 (charm pet "Go Away" button doing nothing), and BUG-034 (companion mana regen significantly slower than player's). BUG-033 has a clear root cause — a guard clause blocks charm break before the charm-handling code executes. BUG-032 requires investigation to determine which NPC property causes the INVULNERABLE state, with the most likely cause being inherited special abilities not stripped during companion spawn. BUG-034 requires diagnostic logging to compare actual per-tick values, as the formulas appear correct on paper but may be affected by skill initialization or multiplier rules.

## Existing System Analysis

### Current State

**BUG-032 — Damage Shield INVULNERABLE:**
- Damage shields are implemented in `zone/attack.cpp:3379` (`Mob::DamageShield()`). When a mob with a DS buff is hit in melee, `DamageShield()` is called from `CommonDamage()` at line 4126.
- The DS only fires when `damage > 0` (line 4125). If the incoming melee damage is `DMG_INVULNERABLE` (-5), the DS call is skipped entirely.
- In `NPC::Attack()` (line 2330), `GetWeaponDamage(other, weapon)` is called. If this returns 0 or negative, `my_hit.damage_done` is set to `DMG_INVULNERABLE` (-5) at line 2404.
- `GetWeaponDamage()` returns 0 if the target has `GetInvul() == true`, `SpecialAbility::MeleeImmunity` (19), `SpecialAbility::MeleeImmunityExceptBane` (22) with no matching bane damage, or `SpecialAbility::MeleeImmunityExceptMagical` (23) with no valid magical damage source.
- Companions strip `MeleeImmunity` (19) and `MagicImmunity` (20) during spawn at line 2330-2331. They do NOT strip `MeleeImmunityExceptBane` (22) or `MeleeImmunityExceptMagical` (23).
- Companions call `SetInvul(false)` at line 2332.
- The source NPC's `special_abilities` string from `npc_types` is processed via `ProcessSpecialAbilities()` inside `AI_Start()` before the companion strips abilities. If the source NPC has ability 22 or 23, those would persist.

**BUG-033 — Charm "Go Away" Button:**
- Pet commands are handled in `zone/client_packet.cpp:11126` (`Client::Handle_OP_PetCommands()`).
- The `PET_GETLOST` case (line 11318) has a guard clause on line 11319: `if (mypet->Charmed()) break;`
- `Mob::Charmed()` (defined in `mob.h:1309`) returns `type_of_pet == PetType::Charmed`.
- This means for charmed pets, the guard fires and execution breaks out of the case BEFORE reaching the charm-handling code on lines 11321-11326 which calls `BuffFadeByEffect(SpellEffect::Charm)`.
- This is a clear logic error: the `Charmed()` guard was presumably intended to prevent normal pet dismissal of charmed pets, but it also blocks the charm break path.

**BUG-034 — Companion Mana Regen:**
- Companion mana regen is calculated in `zone/companion.cpp:1397` (`Companion::CalcManaRegen()`).
- The formula for non-melee casters with `AlwaysMeditateRegen=true`: `(((meditate/10) + (level - level/4)) / 4) + 4` plus `spellbonuses.ManaRegen + itembonuses.ManaRegen + aabonuses.ManaRegen`.
- Client mana regen is calculated in `zone/client_mods.cpp:656` (`Client::CalcManaRegen()`). The client formula for sitting with meditate: `2 + meditate/15` plus `spellbonuses.ManaRegen` plus item/AA bonuses.
- At level 30 with meditate 175: companion gets ~14 base + spell bonuses; client gets ~13 base + spell bonuses. These are comparable.
- Clarity (SPA 15 = SpellEffect::CurrentMana) sets `spellbonuses.ManaRegen` via `CalcBonuses()`, which both formulas include.
- `SetDefensiveSkillsFromCaps()` (line 488) includes `SkillMeditate` in the skills array and sets it from `SkillCaps::Instance()->GetSkillCap(cls, skill, lvl).cap`.
- Applied multipliers: `Character:ManaRegenMultiplier` (default 100) and `Companions:CompanionManaRegenMult` (default 100).
- Both NPC and client tick at 6-second intervals via `tic_timer`.

### Gap Analysis

**BUG-032:**
- The companion spawn code does not strip all melee immunity variants (abilities 22, 23 are left untouched).
- There is no diagnostic logging to identify which specific check in `GetWeaponDamage()` causes the return-0 path.
- The actual NPC type being tested is unknown — the specific `special_abilities` string needs investigation.

**BUG-033:**
- The `Charmed()` guard at line 11319 blocks ALL PET_GETLOST handling for charmed pets, including the intended charm break at line 11325.
- Fix is straightforward: remove the `Charmed()` guard or restructure the case so the charm break code executes.

**BUG-034:**
- On paper, the formulas produce comparable regen. Possible issues:
  1. Meditate skill may not be initialized if `SkillCaps` returns 0 for the companion's actual class (e.g., if the NPC type's class field doesn't match a player caster class).
  2. The multiplier rules might be set to non-default values.
  3. The `Archetype::Melee` check may exclude some classes that should get meditate regen.
  4. `spellbonuses.ManaRegen` may not be populated correctly if Clarity's buff tick isn't processed through the bonus system for the companion.

## Technical Approach

### Architecture Decision

All three bugs require C++ changes only.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `zone/attack.cpp` | Bug fix — strip additional special abilities | BUG-032: companion inherits melee immunity variants that block damage and DS |
| `zone/companion.cpp` | Bug fix — strip more special abilities, add diagnostic logging | BUG-032: strip abilities 22, 23, 46; add logging for mana regen |
| `zone/client_packet.cpp` | Bug fix — fix PET_GETLOST for charmed pets | BUG-033: remove blocking guard clause |
| `zone/companion.cpp` | Bug fix — enhance mana regen diagnostics | BUG-034: add logging to identify regen bottleneck |

### Data Model

No database changes required.

### Code Changes

#### C++ Changes

**BUG-032: Damage Shield INVULNERABLE (`zone/companion.cpp`)**

In `Companion::Spawn()`, after line 2332, add stripping of ALL immunity-related special abilities that could cause INVULNERABLE:

```
Current (lines 2330-2332):
    SetSpecialAbility(SpecialAbility::MeleeImmunity, 0);          // 19
    SetSpecialAbility(SpecialAbility::MagicImmunity, 0);          // 20
    SetInvul(false);

Should be:
    SetSpecialAbility(SpecialAbility::MeleeImmunity, 0);          // 19
    SetSpecialAbility(SpecialAbility::MagicImmunity, 0);          // 20
    SetSpecialAbility(SpecialAbility::MeleeImmunityExceptBane, 0); // 22
    SetSpecialAbility(SpecialAbility::MeleeImmunityExceptMagical, 0); // 23
    SetSpecialAbility(SpecialAbility::RangedAttackImmunity, 0);   // 46
    SetSpecialAbility(SpecialAbility::HarmFromClientImmunity, 0); // 35
    SetSpecialAbility(SpecialAbility::ClientDamageImmunity, 0);   // 47
    SetSpecialAbility(SpecialAbility::NPCDamageImmunity, 0);      // 48
    SetInvul(false);
```

This ensures no inherited NPC immunity prevents damage or damage shields from functioning on companions.

Additionally, add diagnostic logging in `GetWeaponDamage()` when the target is a companion and the return is 0, to help debug any remaining issues.

**BUG-033: Charm "Go Away" (`zone/client_packet.cpp`)**

The fix is at line 11318-11327. The current code:

```cpp
case PET_GETLOST: {
    if (mypet->Charmed())    // <-- THIS BLOCKS THE CHARM BREAK CODE
        break;
    if (mypet->GetPetType() == petCharmed || !mypet->IsNPC()) {
        mypet->BuffFadeByEffect(SpellEffect::Charm);
        break;
    }
    // ... normal pet dismissal
```

The fix: remove the `if (mypet->Charmed()) break;` guard, or restructure so the charmed pet case is handled BEFORE the guard. The simplest fix:

```cpp
case PET_GETLOST: {
    // Handle charmed pets: break the charm instead of dismissing
    if (mypet->GetPetType() == petCharmed || mypet->Charmed()) {
        if (mypet->IsNPC()) {
            mypet->BuffFadeByEffect(SpellEffect::Charm);
        }
        break;
    }
    if (!mypet->IsNPC()) {
        break;
    }
    // ... normal pet dismissal continues
```

The `Charmed()` and `GetPetType() == petCharmed` checks are equivalent (`mob.h:1309` and `mob.h:1098` both check `type_of_pet == PetType::Charmed`), so we can combine them for clarity.

**BUG-034: Companion Mana Regen (`zone/companion.cpp`)**

The formulas appear correct, but there are potential issues with the meditate skill value or the archetype check. The fix approach:

1. **Add diagnostic logging** to `CalcManaRegen()` that logs the meditate skill value, the archetype, the class, the base regen before bonuses, each bonus component (`spellbonuses.ManaRegen`, `itembonuses.ManaRegen`, `aabonuses.ManaRegen`), and the final regen value. Log this on the first tick after spawn and every 10th tick thereafter.

2. **Verify meditate skill initialization**: In `SetDefensiveSkillsFromCaps()`, add a log for the meditate skill cap value that was set.

3. **If meditate is 0**: The most likely issue is that `SkillCaps::Instance()->GetSkillCap(cls, SkillMeditate, lvl).cap` returns 0 for the companion's class. This could happen if:
   - The companion's class ID doesn't match a player class ID in the skill caps table
   - The companion is level 1 (below the skill's minimum acquisition level)
   - The skill caps data hasn't been loaded

4. **Potential formula improvement**: The companion uses a different formula than the client. Consider using the client formula directly for closer parity. However, the current formula actually produces slightly HIGHER values, so this may not be the issue.

5. **Check multiplier rules**: Verify that `Character:ManaRegenMultiplier` and `Companions:CompanionManaRegenMult` are both 100 in the database.

#### Lua/Script Changes

None required.

#### Database Changes

None required.

#### Configuration Changes

None required. The relevant rules (`AlwaysMeditateRegen`, `CompanionManaRegenMult`, `ManaRegenMultiplier`) already exist with appropriate defaults.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | BUG-033: Fix charm pet Go Away — remove the `Charmed()` guard in `PET_GETLOST` case, restructure to allow charm break | c-expert | — | Small (5 lines) |
| 2 | BUG-032: Strip all melee immunity special abilities in `Companion::Spawn()` — add abilities 22, 23, 35, 46, 47, 48 to the strip list | c-expert | — | Small (10 lines) |
| 3 | BUG-034: Add diagnostic logging to `CalcManaRegen()` and `SetDefensiveSkillsFromCaps()` to identify regen bottleneck; verify meditate skill cap initialization | c-expert | — | Medium (30 lines) |
| 4 | BUG-034: Based on diagnostic findings, apply fix (likely: ensure meditate skill is set correctly, or adjust formula if needed) | c-expert | 3 | Small-Medium |

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| BUG-032 fix strips abilities that some NPC types legitimately need | Low | Low | Companions should NEVER be immune to damage; stripping immunity is always correct for companions |
| BUG-033 fix changes charm break behavior for non-Titanium clients | Low | Low | The Charmed() guard was blocking ALL clients; removing it is correct behavior |
| BUG-034 diagnostic logging adds overhead | Very Low | Very Low | Logging only fires every 10th tick and can be removed after diagnosis |

### Compatibility Risks

- **BUG-032**: No compatibility risk. Stripping more special abilities from companions only makes them more hittable, which is the desired behavior.
- **BUG-033**: The fix restores standard EQ behavior for charmed pet dismissal. No risk to existing functionality.
- **BUG-034**: Diagnostic changes don't affect gameplay. Any regen formula changes would need careful testing.

### Performance Risks

None. All changes are minor code path modifications in existing functions.

## Review Passes

### Pass 1: Feasibility

All three fixes are feasible:
- **BUG-033** is a confirmed 1-line logic fix. The `Charmed()` guard at `client_packet.cpp:11319` prevents the charm break code at line 11325 from ever executing. Removing or restructuring this guard is straightforward.
- **BUG-032** requires adding `SetSpecialAbility()` calls for abilities 22, 23, 35, 46, 47, 48 in `Companion::Spawn()`. The pattern already exists for abilities 19 and 20.
- **BUG-034** requires diagnostic logging first. The formulas appear correct, but runtime values need verification. The infrastructure for logging exists (LogCombat, LogInfo).

### Pass 2: Simplicity

- **BUG-033**: Cannot be simpler. One guard clause to fix.
- **BUG-032**: Stripping all immunity abilities is the simplest approach. An alternative (checking specific NPCs) would be fragile and harder to maintain.
- **BUG-034**: Starting with diagnostics before changing formulas is the simplest path. Changing the formula without understanding the actual values risks introducing new bugs.

### Pass 3: Antagonistic

- **BUG-032**: Could there be NPC types where immunity should be preserved on companions? No — companions must be hittable to function as combat participants. A companion immune to melee is broken by definition.
- **BUG-032**: Could stripping abilities cause issues if they're set by buffs later? No — `SetSpecialAbility()` only clears the inherited NPC value. If a spell later sets it, that's fine.
- **BUG-033**: Could charm break on "Go Away" cause any exploit? The mob returns to normal NPC behavior after charm breaks, which is standard EQ. No exploit vector.
- **BUG-033**: What if `BuffFadeByEffect(SpellEffect::Charm)` fails silently? The charm would persist, same as current broken state. The diagnostic logging from BUG-030 would catch this.
- **BUG-034**: If the meditate skill IS zero, fixing it might dramatically increase regen for all caster companions. This is actually desired — the user reports it as too slow. Check against player values to ensure parity, not superiority.

### Pass 4: Integration

- Tasks 1 and 2 are independent and can be done in any order.
- Task 3 (diagnostics) should be done before Task 4 (fix).
- All changes are in C++ files in the `zone/` directory. A single build cycle covers all fixes.
- The build must be followed by a server restart to test.
- No Lua or database changes means no quest reload or DB migration needed.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | Tasks 1-4 | All fixes are C++ code changes in zone/client_packet.cpp and zone/companion.cpp |

## Validation Plan

- [ ] **BUG-032**: Cast Thorns (or any damage shield) on a companion. Have the companion engage in melee combat. Verify that attackers take damage shield damage and no INVULNERABLE message appears.
- [ ] **BUG-032**: Test with a companion recruited from an NPC type that originally had special abilities in its npc_types row.
- [ ] **BUG-033**: As an enchanter, charm an NPC. Click "Go Away" on the pet controls. Verify the charm breaks and the NPC is released.
- [ ] **BUG-033**: Verify that normal (non-charmed) pet dismissal still works — summon a pet and click "Go Away" to dismiss it.
- [ ] **BUG-034**: Compare companion mana regen to player mana regen at the same level with the same buffs. They should be within ~20% of each other.
- [ ] **BUG-034**: Cast Clarity on a companion and verify the spell bonus shows up in the regen calculation (check logs).
- [ ] **BUG-034**: Verify that warrior/rogue companions still show 0 mana regen (non-mana users).
- [ ] **Regression**: Verify existing companion functionality (combat, healing, following, group membership) is unaffected by the changes.

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
