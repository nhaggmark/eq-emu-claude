# npc-companion-realistic-stats — Architecture & Implementation Plan

> **Feature branch:** `feature/npc-companion-realistic-stats`
> **Primary Input:** `improved-companion-stats/architect/context/companion-mechanics-reference.md`
> **Author:** architect
> **Date:** 2026-03-10
> **Status:** Approved

---

## Executive Summary

Companion NPCs currently inherit NPC-style melee combat: damage comes from
`npc_types.max_dmg`/`min_dmg`, attack speed from `npc_types.attack_delay`,
and damage bonus is not applied. This makes equipped weapons cosmetic for
base damage. This plan closes those gaps by overriding the attack path in
the `Companion` class to use weapon damage and delay (following the
Client/Bot pattern in `Mob::Attack()`), adding damage bonus calculations,
and ensuring class-appropriate combat skills are properly initialized.
All changes are Companion class overrides — no NPC base class behavior is
modified.

The work is organized into four independently deployable phases:
1. **Equipment Drives Damage** — weapon damage and delay replace npc_types values
2. **Damage Bonus** — `GetWeaponDamageBonus()` applied to companion melee
3. **Combat Skill Tuning** — skill initialization and double/triple attack mechanics
4. **Rule System Integration** — tuning knobs for all new behaviors

---

## Existing System Analysis

### Current State

**Entity Hierarchy:**
`Companion` inherits from `NPC` which inherits from `Mob`. Companion declares
`IsOfClientBot()` = true and `IsNPC()` = true, creating a dual identity.

**Attack Path:**
`Companion::Attack()` (companion.cpp:439) performs safety checks (no attacking
owner/group), then delegates to `NPC::Attack()` (attack.cpp:2202). NPC::Attack
uses `GetBaseDamage()` (npc.h:306, returns `base_damage` from npc_types.max_dmg)
and `GetMinDamage()` (npc.h:307, returns `min_damage` from npc_types.min_dmg)
for melee damage calculation at attack.cpp:2362-2363.

**Attack Timer:**
`NPC::SetAttackTimer()` (attack.cpp:6784) uses `attack_delay` from npc_types,
not weapon delay. Haste modifiers from spells/items are applied correctly.

**Damage Bonus:**
`Mob::Attack()` (attack.cpp:1674-1685) calls `GetWeaponDamageBonus()` for
Client/Bot at level 28+ for warrior classes. `NPC::Attack()` does not call
this function at all.

**Weapon Handling in NPC::Attack():**
The weapon IS loaded from `equipment[]` at attack.cpp:2250-2254 and IS used for:
- Skill type / animation (2258-2296)
- Bane/elemental damage (2333-2347)
- Procs (2417-2421)

But base damage comes from `GetBaseDamage()`, not `weapon->Damage`.

**Skill Initialization:**
NPCs (including companions) get skills in the NPC constructor (npc.cpp:368-369):
```cpp
for (r = 0; r <= EQ::skills::HIGHEST_SKILL; r++) {
    skills[r] = SkillCaps::Instance()->GetSkillCap(GetClass(), (EQ::skills::SkillType)r, moblevel).cap;
}
```
This means companions already have class-appropriate dodge, parry, riposte,
defense, and offense skills from the skill_caps table. They also get
double attack and dual wield overrides at npc.cpp:382-393.

**CalcBonuses:**
`NPC::CalcBonuses()` (bonuses.cpp:50-60) calls `CalcItemBonuses()` if the NPC
has an owner OR `NPC::UseItemBonusesForNonPets` rule is true. Companions call
`CalcBonuses()` after equipping items. Item stat bonuses, haste, HP/mana regen,
AC all work correctly through this path.

**Avoidance:**
Because `IsOfClientBot()` returns true, companions use the Client/Bot avoidance
path in `Mob::AvoidDamage()` (attack.cpp:372+), which uses `GetSkill(SkillRiposte)`,
`GetSkill(SkillParry)`, etc. Since skills are initialized from SkillCaps, this
already works with class-appropriate values.

### Gap Analysis

| # | Gap | Impact | Fix Layer |
|---|-----|--------|-----------|
| 1 | Weapon damage not used for base melee | **Critical** — weapons are cosmetic | C++ (Companion override) |
| 2 | Weapon delay not used for attack speed | **Critical** — fast weapons have no effect | C++ (Companion override) |
| 3 | Damage bonus not applied at level 28+ | **High** — significant DPS loss for melee | C++ (Companion override) |
| 4 | Double attack uses NPC n_atk, not skill roll | **Medium** — inconsistent with player mechanics | C++ (Companion override) |
| 5 | No rule to toggle weapon-based damage | **Medium** — no tuning knob | C++ (rules) |

**Already Working (no changes needed):**
- Item stat bonuses (via CalcItemBonuses)
- Spell/buff effects (via CalcSpellBonuses)
- Haste from spells and items
- Weapon procs
- Mana regen (meditate formula)
- HP regen (OOC + floor rule)
- Avoidance skills (dodge/parry/riposte from SkillCaps)
- AC calculation (hybrid NPC+ClientBot path)
- Companion spell AI (companion_ai.cpp)

---

## Technical Approach

### Architecture Decision

All changes are **Companion class overrides** in C++. No NPC base class
modifications. No SQL schema changes. New rule values for tunability.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `zone/companion.cpp` | Override `Attack()` method body | Companion-specific weapon damage path |
| `zone/companion.cpp` | New `SetAttackTimer()` override | Use weapon delay instead of npc_types.attack_delay |
| `zone/companion.h` | Declare new virtual overrides | Enable Companion-specific combat methods |
| `zone/companion.cpp` | New `DoAttackRounds()` method | Companion-specific double/triple attack logic |
| `common/ruletypes.h` | New Companion rule entries | Tuning toggles and knobs |

**Why C++ and not Lua Mods?**

The Lua mod system has hooks for `MeleeMitigation`, `TryCriticalHit`, etc., but
not for the fundamental damage source (weapon vs npc_types). The damage source
decision happens deep in `NPC::Attack()` at lines 2362-2363, before any mod hook
fires. Similarly, `SetAttackTimer()` has no Lua hook. The only way to change the
damage source is to override the Attack method in the Companion class.

### Data Model

No database schema changes required. Companions already store equipment in
`companion_inventories` and retrieve items via `GetInv().GetItem()`. The weapon
damage and delay values come from `EQ::ItemData` which is already available
through the item data system.

### Code Changes

#### C++ Changes

##### 1. companion.h — Declare New Overrides

Add declarations for `SetAttackTimer()` override and a helper method
`GetCompanionWeaponDamage()`:

```cpp
// In public section of Companion class:
virtual void SetAttackTimer() override;

// Private helpers:
int GetCompanionWeaponDamage(Mob* target, const EQ::ItemData* weapon, int64* hate = nullptr);
int GetCompanionWeaponDelay(int hand);
```

##### 2. companion.cpp — Override Attack() to Use Weapon Damage

Replace the current `Companion::Attack()` body. Instead of delegating to
`NPC::Attack()`, implement a weapon-damage-aware attack path modeled on
`Mob::Attack()` (attack.cpp:1566-1765, the Client/Bot path).

**Key changes from the current NPC::Attack path:**

a. **Weapon retrieval:** Use `GetInv().GetItem()` (like Client/Bot) instead of
   `database.GetItem(equipment[])` (like NPC). Companions populate their
   inventory profile in `GiveItem()` so `GetInv().GetItem()` returns the
   correct ItemInstance.

b. **Base damage source:** When `RuleB(Companions, UseWeaponDamage)` is true AND
   a weapon is equipped, use `GetWeaponDamage(other, weapon, &hate)` (the shared
   Mob function that reads `weapon->Damage`). When the rule is false OR no
   weapon is equipped, fall back to `GetBaseDamage()` + `GetMinDamage()` (current
   NPC behavior).

c. **Damage bonus:** When the companion is level 28+ and a warrior class
   (`IsWarriorClass()`), call `GetWeaponDamageBonus()` to set `my_hit.min_damage`,
   matching the Client path at attack.cpp:1676-1683.

d. **All other combat logic remains shared:** `DoAttack()`, `CheckHitChance()`,
   `AvoidDamage()`, `MeleeMitigation()`, `TryCriticalHit()`,
   `CommonOutgoingHitSuccess()` are all `Mob::` methods that already work for
   companions via `IsOfClientBot()`.

**Pseudocode for the new Companion::Attack():**

```
bool Companion::Attack(Mob* other, int Hand, bool bRiposte, ...) {
    // Safety checks (existing: no attacking owner/group)

    if (!other || DivineAura() || !IsAttackAllowed(other))
        return false;

    FaceTarget(GetTarget());

    DamageHitInfo my_hit;
    // Determine weapon
    const EQ::ItemInstance* weapon_inst = nullptr;
    const EQ::ItemData* weapon = nullptr;

    if (RuleB(Companions, UseWeaponDamage)) {
        weapon_inst = GetInv().GetItem(Hand);
        if (weapon_inst && weapon_inst->IsWeapon())
            weapon = weapon_inst->GetItem();
    }

    // Skill type from weapon or hand-to-hand
    my_hit.skill = AttackAnimation(Hand, weapon_inst);
    my_hit.damage_done = 1;
    my_hit.min_damage = 0;

    int64 hate = 0;

    if (weapon && RuleB(Companions, UseWeaponDamage)) {
        // CLIENT/BOT PATH: weapon damage
        if (weapon)
            hate = weapon->Damage + weapon->ElemDmgAmt;
        my_hit.base_damage = GetWeaponDamage(other, weapon_inst, &hate);
    } else {
        // NPC PATH: fallback to npc_types damage
        my_hit.base_damage = GetBaseDamage();
        my_hit.min_damage = GetMinDamage();
        hate = my_hit.base_damage + my_hit.min_damage;
    }

    if (my_hit.base_damage > 0) {
        // Damage caps
        if (Hand == slotPrimary || Hand == slotSecondary)
            my_hit.base_damage = DoDamageCaps(my_hit.base_damage);

        // Damage bonus (Client path: attack.cpp:1676-1683)
        if (RuleB(Companions, UseWeaponDamage) && weapon) {
            if (Hand == slotPrimary && GetLevel() >= 28 && IsWarriorClass()) {
                int db = GetWeaponDamageBonus(weapon);
                my_hit.min_damage = db;
                hate += db;
            }
        }

        // Bane/elemental damage (keep existing NPC logic)
        int eleBane = 0;
        if (weapon) { /* existing bane damage logic */ }
        my_hit.base_damage += eleBane;

        my_hit.offense = offense(my_hit.skill);
        my_hit.hand = Hand;
        my_hit.tohit = GetTotalToHit(my_hit.skill, hit_chance_bonus);

        DoAttack(other, my_hit, opts, bRiposte);
    } else {
        my_hit.damage_done = DMG_INVULNERABLE;
    }

    // Rest: Damage call, hate, procs — same as NPC::Attack
    other->AddToHateList(this, hate);
    other->Damage(this, my_hit.damage_done, ...);
    MeleeLifeTap(my_hit.damage_done);
    CommonBreakInvisibleFromCombat();

    // Procs (identical to NPC::Attack lines 2416-2426)
    if (has_hit && !bRiposte && !other->HasDied()) {
        TryWeaponProc(nullptr, weapon, other, Hand);
        TrySpellProc(nullptr, weapon, other, Hand);
        TrySkillProc(other, my_hit.skill, 0, true, Hand);
    }

    return has_hit;
}
```

##### 3. companion.cpp — Override SetAttackTimer() to Use Weapon Delay

When `UseWeaponDamage` rule is true, read weapon delay from inventory.
Otherwise fall back to the NPC attack_delay path.

**Pseudocode:**

```
void Companion::SetAttackTimer() {
    if (!RuleB(Companions, UseWeaponDamage)) {
        NPC::SetAttackTimer();  // fallback to npc_types.attack_delay
        return;
    }

    float haste_mod = GetHaste() * 0.01f;
    attack_timer.SetAtTrigger(4000, true);  // default

    for (int i = slotRange; i <= slotSecondary; i++) {
        Timer* TimerToUse = (pick appropriate timer);

        // Dual wield check
        if (i == slotSecondary) {
            if (!CanThisClassDualWield() || HasTwoHanderEquipped()) {
                attack_dw_timer.Disable();
                continue;
            }
        }

        // Get weapon from inventory profile
        EQ::ItemInstance* ci = GetInv().GetItem(i);
        const EQ::ItemData* item = ci ? ci->GetItem() : nullptr;

        int delay;
        if (item && item->Damage > 0 && item->Delay > 0) {
            delay = 100 * item->Delay;  // weapon delay in centiseconds
        } else if (i == slotPrimary) {
            delay = 100 * GetHandToHandDelay();  // unarmed fallback
        } else {
            continue;  // no valid offhand weapon
        }

        int hhe = itembonuses.HundredHands + spellbonuses.HundredHands;
        int speed = delay / haste_mod;
        // Apply HundredHands
        speed = static_cast<int>(speed + ((hhe / 1000.0f) * speed));

        TimerToUse->SetAtTrigger(std::max(RuleI(Combat, MinHastedDelay), speed), true, true);
    }
}
```

##### 4. companion.cpp — Double/Triple Attack via Skill Rolls

Currently companions use `DoMainHandAttackRounds()` which checks `IsNPC()` and
uses `GetNumberOfAttacks()` (npc_types.attack_count) for extra swings. This is
the NPC path, not skill-based.

Override approach: Since `DoMainHandAttackRounds()` is a `Mob::` method (not
virtual), companions need either:
- (A) A Companion override of `Process()` that calls a custom attack-rounds
  method, OR
- (B) Modification of `DoMainHandAttackRounds()` to check `IsCompanion()`

**Recommended: Option A** — Add a `Companion::DoCompanionAttackRounds()` private
method and modify the attack-round calling code in `Companion::Process()`.

However, examining the code more carefully: `DoMainHandAttackRounds()` already
handles both NPC and Client/Bot paths. When `RuleB(Combat, UseLiveCombatRounds)`
is true (the modern path), it does:
```
Attack() once, then CheckDoubleAttack(), then pet flurry check
```
This is the same for ALL mobs. The NPC-specific path only runs when
`!UseLiveCombatRounds`. Since our server likely uses UseLiveCombatRounds=true,
companions already get the correct double-attack behavior via skill roll.

**Key verification needed during implementation:** Check the value of
`Combat::UseLiveCombatRounds` rule. If true, no attack-round changes needed.
If false, add a Companion check to `DoMainHandAttackRounds()` to use the
skill-based path.

##### 5. common/ruletypes.h — New Rules

```cpp
RULE_BOOL(Companions, UseWeaponDamage, true,
    "When true, companions use equipped weapon damage and delay instead of "
    "npc_types.max_dmg and attack_delay. When false, weapons remain cosmetic "
    "for base damage (procs and bane still work).")
```

This single rule is the master toggle for all Phase 1 and 2 changes.
When false, behavior is identical to current (pre-change) behavior.

#### Lua/Script Changes

None required. All changes are in the C++ combat path.

#### Database Changes

One rule value insertion:

```sql
INSERT INTO `rule_values` (`ruleset_id`, `rule_name`, `rule_value`, `notes`)
VALUES (1, 'Companions:UseWeaponDamage', 'true',
        'Use equipped weapon damage/delay for companions instead of npc_types values');
```

#### Configuration Changes

No eqemu_config.json changes. The new rule is managed via the `rule_values` table
and accessible via `#rules` GM command.

---

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Add `UseWeaponDamage` rule to `common/ruletypes.h` | **c-expert** | — | Small (1 line) |
| 2 | Add `SetAttackTimer()` override declaration to `companion.h` | **c-expert** | — | Small (3 lines) |
| 3 | Implement `Companion::SetAttackTimer()` in `companion.cpp` | **c-expert** | 1, 2 | Medium (50-70 lines) |
| 4 | Rewrite `Companion::Attack()` to use weapon damage path | **c-expert** | 1, 2 | Large (100-140 lines) |
| 5 | Verify `Combat::UseLiveCombatRounds` behavior for double attack | **c-expert** | 4 | Small (investigation + possible 10-line change) |
| 6 | Insert `UseWeaponDamage` rule into `rule_values` table | **data-expert** | 1 | Small (1 INSERT) |
| 7 | Build, deploy, test the full attack chain | **c-expert** | 3, 4, 5, 6 | Medium (build + manual testing) |

### Task Details

#### Task 1: Add UseWeaponDamage Rule

**File:** `eqemu/common/ruletypes.h`
**Location:** After line 1214 (end of Companions category)
**Action:** Add one `RULE_BOOL` line

#### Task 2: Declare New Overrides in companion.h

**File:** `eqemu/zone/companion.h`
**Location:** In the public virtual overrides section (near line 103)
**Action:** Add:
```cpp
virtual void SetAttackTimer() override;
```

No new private helper methods needed — the logic lives directly in the
`Attack()` and `SetAttackTimer()` method bodies.

#### Task 3: Implement Companion::SetAttackTimer()

**File:** `eqemu/zone/companion.cpp`
**Reference:** `Client::SetAttackTimer()` at attack.cpp:6682-6782
**Behavior:**
- When `UseWeaponDamage` is false, delegate to `NPC::SetAttackTimer()`
- When true, follow the Client pattern:
  - Read weapon delay from `GetInv().GetItem(slot)`
  - Fall back to `GetHandToHandDelay()` for unarmed
  - Apply haste and HundredHands modifiers
  - Respect `Combat::MinHastedDelay` cap
  - Handle dual wield timer (check `CanThisClassDualWield()`)

**Critical detail:** The Client path reads `ItemInstance*` from `GetInv()`.
Companions populate their inventory via `GetInv().PutItem()` in `GiveItem()`,
so this works. NPCs use `equipment[]` (raw item IDs) and `database.GetItem()`.
The Companion override MUST use the inventory profile path.

**Critical detail 2:** `SetAttackTimer()` is called from `CalcBonuses()` ->
`Mob::CalcBonuses()` -> `SetAttackTimer()`. Since companions call
`CalcBonuses()` after equipping items, the timer automatically updates when
weapons change.

#### Task 4: Rewrite Companion::Attack()

**File:** `eqemu/zone/companion.cpp`
**Replace:** Current body (lines 439-466)
**Reference:** `Mob::Attack()` at attack.cpp:1566-1765 (Client/Bot path)

The new body should:

1. Keep the existing safety checks (no attacking owner/group) — lines 442-463
2. When `UseWeaponDamage` is true AND a weapon is equipped:
   - Get weapon via `GetInv().GetItem(Hand)` (not `database.GetItem(equipment[Hand])`)
   - Use `GetWeaponDamage(other, weapon_inst, &hate)` for base_damage
   - Apply `DoDamageCaps()` (attack.cpp:1650)
   - Apply `GetWeaponDamageBonus()` for level 28+ warrior classes (attack.cpp:1676-1683)
   - Set `my_hit.min_damage = ucDamageBonus`
3. When `UseWeaponDamage` is false OR no weapon equipped:
   - Fall back to `GetBaseDamage()` and `GetMinDamage()` (current NPC behavior)
4. Common paths (always execute):
   - `offense()`, `GetTotalToHit()`, `DoAttack()` (shared Mob functions)
   - `other->Damage()`, `MeleeLifeTap()`, `CommonBreakInvisibleFromCombat()`
   - `TryWeaponProc()`, `TrySpellProc()`, `TrySkillProc()` — keep existing proc logic
   - Bane/elemental damage from weapon (keep existing NPC logic)

**Important: The AttackAnimation call.** `Mob::Attack()` calls
`AttackAnimation(Hand, weapon_inst)` passing an `ItemInstance*`. `NPC::Attack()`
calls `AttackAnimation(Hand, &weapon_inst, my_hit.skill)` constructing a
temporary. The Companion should use the Client pattern since it has ItemInstance
objects in inventory.

**Important: Hate calculation.** The Client path sets
`hate = weapon->Damage + weapon->ElemDmgAmt` before `GetWeaponDamage()`.
The NPC path sets `hate = base_damage + min_damage` after. The Companion
should follow the Client pattern when using weapon damage.

#### Task 5: Verify Double Attack Behavior

**File:** `eqemu/zone/attack.cpp`, function `DoMainHandAttackRounds()` (line 6938)
**Action:** Check `Combat::UseLiveCombatRounds` rule value in the database.
- If true: companions already get proper double attack via `CheckDoubleAttack()`
  skill roll (lines 6944-6957). No changes needed.
- If false: the NPC path at lines 6960-6992 uses `GetNumberOfAttacks()` and
  `GetSpecialAbility(TripleAttack)`. In this case, add a check for
  `IsCompanion()` to use the Client-style skill-based double attack instead.

**Expected outcome:** `UseLiveCombatRounds` is likely true for this server,
meaning no code changes needed for double attack. Verify and document.

#### Task 6: Insert Rule Value

**Agent:** data-expert
**Action:** Insert the `UseWeaponDamage` rule into the database:
```sql
INSERT INTO `rule_values` (`ruleset_id`, `rule_name`, `rule_value`, `notes`)
VALUES (1, 'Companions:UseWeaponDamage', 'true',
        'Companions use weapon damage/delay instead of npc_types values');
```

#### Task 7: Build and Test

**Build command:**
```bash
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
```

**Test plan:**
1. Recruit a melee companion (warrior or rogue)
2. Equip a high-damage weapon via `!give <item_id>`
3. Observe damage output — should reflect weapon damage, not npc_types.max_dmg
4. Equip a fast weapon (low delay) — attack speed should increase
5. Remove weapon — should fall back to hand-to-hand or npc_types behavior
6. Toggle rule to false via `#rules set Companions:UseWeaponDamage false`
7. Verify damage reverts to npc_types-based damage
8. Test level 28+ warrior companion — verify damage bonus appears
9. Test caster companion — verify no weapon damage changes (casters use spells)

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `GetInv().GetItem()` returns null for companion equipment slots | Medium | Attack crashes | Null check before weapon use; fall back to NPC path |
| Inventory profile not populated before first attack | Low | Incorrect damage on first swing | `LoadEquipment()` already called before `AI_Start()` |
| `GetWeaponDamage()` returns 0 for legitimate weapons | Low | No damage dealt | Log warning, fall back to `GetBaseDamage()` |
| `AttackAnimation()` overload mismatch between Client and NPC versions | Medium | Wrong animation or compilation error | Verify function signature; both overloads exist in mob.h |
| Haste interaction with new SetAttackTimer | Low | Speed capping issues | Follow Client::SetAttackTimer exactly; same caps apply |

### Compatibility Risks

- **Existing companion behavior:** All changes gated behind `UseWeaponDamage` rule.
  Setting to false restores pre-change behavior entirely.
- **Unarmed companions:** Companions without weapons fall back to NPC damage path.
  No regression for existing companions who have not been given weapons.
- **Weapon procs:** Already working; this change does not touch proc logic.
  Procs continue to fire from the same code path.
- **Buff/spell interactions:** `DoAttack()`, `MeleeMitigation()`,
  `TryCriticalHit()`, `CommonOutgoingHitSuccess()` are shared Mob methods that
  don't care about the damage source. No compatibility issues.
- **Dual wield:** The new `SetAttackTimer()` handles dual wield via
  `CanThisClassDualWield()` check, same as Client. Classes that can't dual wield
  will have their DW timer disabled.

### Performance Risks

No performance concerns. The changes replace one damage lookup (npc_types) with
another (inventory item), both O(1). `SetAttackTimer()` is called infrequently
(only when bonuses are recalculated). No new database queries are introduced.

---

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes. The approach is well-precedented:

- `Mob::Attack()` (the Client/Bot path) is 200 lines of proven code that we are
  adapting for companions. The key functions (`GetWeaponDamage()`,
  `GetWeaponDamageBonus()`, `DoDamageCaps()`) are all `Mob::` methods available
  to companions.
- `Client::SetAttackTimer()` is 100 lines we are adapting. The companion
  inventory profile is already functional (CalcItemBonuses uses it).
- Companions already have `GetInv()` populated via `GiveItem()` which calls
  `GetInv().PutItem()`. This is the same mechanism bots use.

**Hardest part:** Ensuring the `AttackAnimation()` call works correctly with
the `ItemInstance*` from `GetInv()` rather than the temporary constructed in
`NPC::Attack()`. Both overloads exist, but the signatures differ slightly.
The c-expert must verify which overload to call.

**Verified during research:**
- NPCs (and companions) already get class-appropriate skills from
  `SkillCaps::Instance()->GetSkillCap()` in the NPC constructor (npc.cpp:368-369).
  Skills like dodge, parry, riposte, defense, offense are all populated correctly.
- The `AvoidDamage()` path already uses skills (not special abilities) for
  companions because `IsOfClientBot()` returns true.
- Item bonuses already work because `NPC::CalcBonuses()` calls
  `CalcItemBonuses()` which reads from the inventory profile.

### Pass 2: Simplicity

**Can anything be removed or deferred?**

- **Deferred: STA -> HP conversion (Gap #6 from reference).** This is a
  separate concern from weapon damage. Not in scope for this feature.
- **Deferred: Click effects (Gap #8).** Requires AI-driven clicky system.
  Complex, low impact. Not in scope.
- **Deferred: Sitting HP regen bonus (Gap #9).** Minor quality-of-life.
  Not in scope.
- **Deferred: Individual CalcSTR/CalcSTA (Gap #4).** The current system works.
  Items add stats via CalcItemBonuses. The only missing piece is the Client-style
  class-specific scaling formulas, which is cosmetic for companions.
- **Removed: Combat skill tuning.** After investigation, companions already get
  proper skills from SkillCaps. No changes needed. This was a perceived gap that
  doesn't exist.
- **Simplified: One rule instead of many.** A single `UseWeaponDamage` bool
  controls all changes. No need for separate rules for damage vs delay vs
  damage bonus — they are logically inseparable.

**Result:** 4 tasks instead of 14+. Clean, minimal, testable.

### Pass 3: Antagonistic

**What could go wrong?**

1. **Overpowered companions:** If a companion is given an epic weapon, they could
   deal substantially more damage than intended. **Mitigation:** The existing
   `Companions::StatScalePct` rule can scale down companion effectiveness.
   Additionally, `DoDamageCaps()` enforces damage caps. Level gating on
   `GetWeaponDamageBonus()` prevents low-level companions from getting the
   damage bonus.

2. **Unarmed regression:** A companion with no weapon who uses the new code
   path could get `GetWeaponDamage()` returning 0 for hand-to-hand.
   **Mitigation:** When no weapon is equipped, fall back to `GetBaseDamage()`
   (NPC path). The code must explicitly check for null weapon and fallback.

3. **Attack speed exploit:** Equipping a very fast weapon (delay=10) could make
   companion attack speed unreasonably fast. **Mitigation:**
   `Combat::MinHastedDelay` rule caps minimum attack speed. Same cap applies to
   clients. No companion-specific exploit possible.

4. **Proc rate interaction:** If weapon delay changes but the proc system still
   references `attack_delay` from npc_types, proc rates could be wrong.
   **Investigation:** `TryWeaponProc()` and `TrySpellProc()` in attack.cpp don't
   use attack_delay — they use their own proc chance calculations based on
   weapon proc rate. No interaction.

5. **Save/Load cycle:** Companion equipment is persisted in
   `companion_inventories`. When a companion unsuspends, `LoadEquipment()` is
   called, then `CalcBonuses()` which calls `SetAttackTimer()`. The new
   `SetAttackTimer()` reads from `GetInv()` which is populated by
   `LoadEquipment()`. The timing is correct.

6. **Server crash during attack:** If the server crashes between equipping a
   weapon and the next `CalcBonuses()` call, the attack timer might be stale.
   **Mitigation:** `CalcBonuses()` is called synchronously in `GiveItem()`.
   No window for inconsistency.

7. **Race condition: weapon removed mid-fight:** If `RemoveItemFromSlot()` is
   called while the companion is in combat, the next attack could use stale
   weapon data. **Mitigation:** `RemoveItemFromSlot()` calls `CalcBonuses()`
   which calls `SetAttackTimer()`, updating the timer immediately. The next
   `Attack()` call reads the weapon fresh from `GetInv()`. No race condition.

### Pass 4: Integration

**Implementation order:**

1. Task 1 (rule) and Task 2 (header declaration) are independent — can be done
   in parallel or any order.
2. Task 3 (SetAttackTimer) depends on Task 1 (rule) and Task 2 (declaration).
3. Task 4 (Attack override) depends on Task 1 and Task 2.
4. Tasks 3 and 4 are independent of each other — can be done in parallel.
5. Task 5 (verify double attack) depends on Task 4 being complete so the full
   attack chain can be tested.
6. Task 6 (DB insert) depends on Task 1 (rule name must match).
7. Task 7 (build/test) depends on all previous tasks.

**Context for implementation experts:**

The c-expert needs:
- `companion-mechanics-reference.md` — to understand the current system
- This architecture doc — for the specific implementation plan
- Read access to: `zone/attack.cpp` (lines 1566-1765 and 2202-2433 and 6682-6827),
  `zone/companion.cpp`, `zone/companion.h`, `zone/npc.h` (GetBaseDamage/GetMinDamage)

The data-expert needs:
- The rule name and value from Task 6

---

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| **c-expert** | 1, 2, 3, 4, 5, 7 | All changes are C++ (Companion class overrides, rule definition, build/test) |
| **data-expert** | 6 | Single SQL INSERT for rule_values |

---

## Validation Plan

- [ ] Companion with weapon equipped deals damage based on weapon->Damage, not npc_types.max_dmg
- [ ] Companion attack speed reflects weapon delay, not npc_types.attack_delay
- [ ] Companion with no weapon falls back to NPC damage (GetBaseDamage/GetMinDamage)
- [ ] Level 28+ warrior-class companion gets damage bonus from GetWeaponDamageBonus()
- [ ] Equipping a faster weapon increases companion attack rate
- [ ] Equipping a slower, higher-damage weapon increases per-hit damage
- [ ] `#rules set Companions:UseWeaponDamage false` reverts to pre-change behavior
- [ ] `#rules set Companions:UseWeaponDamage true` re-enables weapon damage
- [ ] Weapon procs still fire correctly with the new attack path
- [ ] Haste buffs still affect companion attack speed with weapon delay
- [ ] Dual-wield companions attack correctly with both hands
- [ ] Caster companions are unaffected (they use spells, not melee)
- [ ] Companion without any weapon uses hand-to-hand delay
- [ ] No server crash when removing weapon from companion mid-combat
- [ ] Companion equipment persists through zone changes and suspend/unsuspend

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above — **c-expert** and **data-expert**.
> They should work through the task list in dependency order.
