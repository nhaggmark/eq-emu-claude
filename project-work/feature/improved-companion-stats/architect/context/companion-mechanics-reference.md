# Companion Combat Mechanics Reference

> Definitive technical reference comparing Companion NPC combat mechanics to
> Client (Player Character) combat mechanics. For use by all downstream
> architect and engineer agents.
>
> **Last updated:** 2026-03-10
> **Source files examined:** companion.h, companion.cpp, companion_ai.cpp,
> attack.cpp, bonuses.cpp, mob.h, npc.h, npc.cpp, mob.cpp, bot.cpp,
> entity.h, ruletypes.h, companion_spell_sets (DB table)

---

## Table of Contents

1. [Critical Architecture Finding](#critical-architecture-finding)
2. [Base Stats (STR, STA, DEX, AGI, INT, WIS, CHA)](#1-base-stats)
3. [Armor Class (AC)](#2-armor-class)
4. [Attack / Hit Chance / Accuracy](#3-attack--hit-chance--accuracy)
5. [Melee Damage](#4-melee-damage)
6. [Weapon Delay / Attack Speed / Haste](#5-weapon-delay--attack-speed--haste)
7. [Dual Wield / Double Attack / Special Attacks](#6-dual-wield--double-attack--special-attacks)
8. [Dodge / Parry / Riposte / Block (Avoidance)](#7-dodge--parry--riposte--block-avoidance)
9. [HP and HP Regen](#8-hp-and-hp-regen)
10. [Mana and Mana Regen](#9-mana-and-mana-regen)
11. [Spell/Buff Effects on Companions](#10-spellbuff-effects-on-companions)
12. [Item Special Effects](#11-item-special-effects)
13. [Resistances](#12-resistances)
14. [Companion Spell System](#13-companion-spell-system)
15. [Known Gaps / Missing Mechanics](#14-known-gaps--missing-mechanics)
16. [Summary Gap Table](#15-summary-gap-table)

---

## Critical Architecture Finding

**Companions override `IsOfClientBot()` and `IsOfClientBotMerc()` to return `true`.**

```cpp
// companion.h:112-113
virtual bool IsOfClientBot()     const override { return true; }
virtual bool IsOfClientBotMerc() const override { return true; }
```

This is the single most important architectural fact about companion combat.
Throughout `attack.cpp`, `bonuses.cpp`, and `mob.cpp`, the code branches on
`IsOfClientBot()` and `IsOfClientBotMerc()` to decide whether to use
Client/Bot-style calculations or NPC-style calculations. By returning `true`,
companions get **Client/Bot treatment** for:

- AC softcap calculations (ACSum, line 947)
- AC anti-twink control (ACSum, line 916)
- Avoidance calculations (AvoidDamage, lines 258-272)
- Sitting damage multiplier (line 347, 1047)
- Critical hit calculations (lines 3896, 3914, 3950)
- Damage bonus calculations (lines 5025, 5283)
- Shield AC bonus (line 902)
- Spell damage cap (bonuses.cpp:241)
- Heal amount cap (bonuses.cpp:245)
- Various stat caps (bonuses.cpp:289, 382)

However, companions **also** return `true` for `IsNPC()` (companion.h:111),
which creates a dual identity: they are treated as NPCs for entity management
and AI, but as Client/Bot peers for combat math. This dual nature means some
code paths may check `IsNPC()` first and use NPC logic, while other paths check
`IsOfClientBot()` first and use Client/Bot logic.

**Also critical:** Companions inherit `NPC::Attack()` (via `Companion::Attack()`
which calls `NPC::Attack()`), NOT `Client::Attack()`. This means the NPC attack
path is used for damage calculation, which uses `GetBaseDamage()` / `GetMinDamage()`
from `npc_types` instead of weapon damage from inventory.

---

## 1. Base Stats

### How Companions Get Base Stats

Companions get their initial stats directly from the `npc_types` database table
when they are recruited. The `NPCType` struct (loaded via
`content_db.LoadNPCTypesData()`) provides all base values.

**Source: companion.cpp constructor (lines 82-98)**
```cpp
m_base_str  = d->STR;   // from npc_types.STR
m_base_sta  = d->STA;   // from npc_types.STA
m_base_dex  = d->DEX;   // from npc_types.DEX
m_base_agi  = d->AGI;   // from npc_types.AGI
m_base_int  = d->INT;   // from npc_types.INT
m_base_wis  = d->WIS;   // from npc_types.WIS
m_base_cha  = d->CHA;   // from npc_types.CHA
m_base_ac   = d->AC;    // from npc_types.AC
m_base_atk  = d->ATK;   // from npc_types.ATK
```

These are stored as `m_base_*` fields and written directly to the `Mob` class
member fields (STR, STA, DEX, AGI, INT, WIS, CHA, AC, ATK).

#### Stat Scaling at Level-Up (ScaleStatsToLevel)

When a companion levels up, stats are scaled linearly:

**Source: companion.cpp:285-316**
```cpp
void Companion::ScaleStatsToLevel(uint8 current_level) {
    float scale = (float)current_level / (float)m_recruited_level;
    STR = (int32)(m_base_str * scale);
    STA = (int32)(m_base_sta * scale);
    // ... same for all stats, AC, ATK, resists, HP, mana
    CalcBonuses();
}
```

#### Global Stat Scale (ApplyStatScalePct)

A global rule `Companions::StatScalePct` (default: 100) allows scaling all
companion stats up or down. Applied once in the constructor.

**Source: companion.cpp:318-344**
```cpp
void Companion::ApplyStatScalePct() {
    int stat_scale_pct = RuleI(Companions, StatScalePct);
    float scale = (float)stat_scale_pct / 100.0f;
    STR = (int32)(STR * scale);
    // ... all stats
}
```

### How Clients Compute Base Stats

Clients have a complex multi-layer stat system:

**Source: bonuses.cpp:62-116 (Client::CalcBonuses)**
```cpp
void Client::CalcBonuses() {
    CalcItemBonuses(&itembonuses);     // gear stats
    CalcHeroicBonuses(&itembonuses);   // heroic stat bonuses
    CalcEdibleBonuses(&itembonuses);   // food/drink bonuses
    CalcSpellBonuses(&spellbonuses);   // buff stats
    CalcAABonuses(&aabonuses);         // AA bonuses
    // Then individual stat calculations:
    CalcSTR(); CalcSTA(); CalcDEX(); CalcAGI();
    CalcINT(); CalcWIS(); CalcCHA();
    // Each CalcXXX() combines: base_race_stat + class_scaling + item + spell + AA
}
```

### Do Companions Benefit from Gear Stats?

**YES.** Companions call `CalcBonuses()` after equipping items.

**Source: companion.cpp:1842 (GiveItem)**
```cpp
bool Companion::GiveItem(uint32 item_id, int16 slot) {
    // ... put item in inventory profile
    GetInv().PutItem(slot, *inst);
    // ...
    CalcBonuses();  // <-- recalculates all stat bonuses including item bonuses
    return true;
}
```

And in `LoadEquipment()` (companion.cpp:1903):
```cpp
    CalcBonuses();  // after all equipment loaded
```

Companions inherit `NPC::CalcBonuses()` which calls `CalcItemBonuses()`:

**Source: bonuses.cpp:50-60**
```cpp
void NPC::CalcBonuses() {
    memset(&itembonuses, 0, sizeof(StatBonuses));
    if (GetOwner() || RuleB(NPC, UseItemBonusesForNonPets)) {
        CalcItemBonuses(&itembonuses);  // <-- item stats ARE applied
    }
    Mob::CalcBonuses();
}
```

**Important:** Companions do NOT have an `GetOwner()` set (they use
`GetCompanionOwner()` which queries by character ID, not the NPC ownership
system). So they depend on the rule `NPC::UseItemBonusesForNonPets` being true,
OR the CalcBonuses being called via the Companion code path that loads items
into the inventory profile first. Since the constructor calls `CalcBonuses()`
and the items are populated via `GetInv().PutItem()`, the `CalcItemBonuses()`
function iterates the inventory profile and finds the items.

### Comparison Table: Base Stats

| Aspect | Client | Companion | Gap |
|--------|--------|-----------|-----|
| Source of base stats | Race/class tables + level scaling | npc_types table | Different source, but functional |
| Level-up scaling | Complex per-class formulas | Linear: `base * (new_level / recruited_level)` | Simplified but functional |
| Item stat bonuses | Full CalcItemBonuses | Full CalcItemBonuses (via NPC::CalcBonuses) | **Same** |
| Spell stat bonuses | CalcSpellBonuses | CalcSpellBonuses (via Mob::CalcBonuses) | **Same** |
| AA bonuses | CalcAABonuses | CalcAABonuses (returns 0 — no AAs) | AAs not applicable |
| Heroic bonuses | CalcHeroicBonuses | Not called | **Gap: heroic stats from items ignored** |
| Individual CalcSTR/etc | Called for each stat | NOT called | **Gap: stat combination formulas not used** |
| Global scale | None | StatScalePct rule (default 100%) | Companion-specific tuning knob |

### Key Gap: CalcSTR/CalcSTA/etc Not Called

Clients call individual `CalcSTR()`, `CalcSTA()`, etc. which combine
base + item + spell + AA bonuses into a final stat. Companions do NOT call
these functions. Instead, their stats come from the raw `npc_types` values
plus item bonuses added via `CalcItemBonuses()`. The item/spell bonuses are
stored in `itembonuses.STR`, `spellbonuses.STR` etc., and when code calls
`GetSTR()` on a Mob, it returns `STR + itembonuses.STR + spellbonuses.STR +
aabonuses.STR`, so the bonuses DO apply — just the base stat calculation
path is different.

---

## 2. Armor Class

### How NPC AC is Computed

For NPCs, AC comes from `npc_types.AC` and is added directly in `ACSum()`:

**Source: attack.cpp:920-933 (ACSum, NPC path)**
```cpp
if (IsNPC()) {
    ac += GetAC();                          // npc_types.AC (the "developer tweaked number")
    ac += GetPetACBonusFromOwner();
    auto spell_aa_ac = aabonuses.AC + spellbonuses.AC;
    ac += GetSkill(EQ::skills::SkillDefense) / 5;
    if (class is caster)
        ac += spell_aa_ac / 3;
    else
        ac += spell_aa_ac / 4;
}
```

### How Client AC is Computed

For Clients/Bots (the `else` branch in ACSum):

**Source: attack.cpp:897-965 (ACSum)**
```cpp
int Mob::ACSum(bool skip_caps) {
    int ac = 0;
    ac += itembonuses.AC;                   // items + food + tribute
    int shield_ac = 0;
    if (HasShieldEquipped() && IsOfClientBot()) {
        // shield AC calculated from equipped item
    }
    ac = (ac * 4) / 3;                     // "EQ math" multiplier
    // anti-twink cap for low levels
    if (!skip_caps && IsOfClientBot() && GetLevel() < LevelToStopACTwinkControl)
        ac = std::min(ac, 25 + 6 * GetLevel());
    ac += GetClassRaceACBonus();
    // Client/Bot path:
    auto spell_aa_ac = aabonuses.AC + spellbonuses.AC;
    if (class is caster)
        ac += GetSkill(SkillDefense) / 2 + spell_aa_ac / 3;
    else
        ac += GetSkill(SkillDefense) / 3 + spell_aa_ac / 4;
    // AGI bonus
    if (GetAGI() > 70)
        ac += GetAGI() / 20;
    // Softcap (Client/Bot only)
    if (!skip_caps && IsOfClientBot()) {
        auto softcap = GetACSoftcap();
        // ... softcap + returns calculation
    }
}
```

### How Companion AC Works

Because `IsOfClientBot()` returns `true` AND `IsNPC()` returns `true`, the
code flow in ACSum is:

1. **Line 901:** `itembonuses.AC` is added (item AC from equipped gear)
2. **Line 902:** Shield AC is calculated because `IsOfClientBot()` is true
3. **Line 914:** The `(ac * 4) / 3` EQ math multiplier is applied
4. **Line 916:** Anti-twink cap applies because `IsOfClientBot()` is true
5. **Line 919:** `GetClassRaceACBonus()` is added
6. **Line 920:** `IsNPC()` is true, so the NPC AC path is taken:
   - `GetAC()` (npc_types.AC) is added
   - Defense skill / 5 is added
   - Spell/AA AC bonuses are added
7. **Line 942:** AGI bonus if AGI > 70
8. **Line 947:** AC softcap IS applied because `IsOfClientBot()` is true

**Critical issue:** The companion takes BOTH the NPC path (adding npc_types.AC)
AND gets treated as a Client/Bot for softcaps and anti-twink. This means
companions get the raw NPC AC number PLUS item AC PLUS the softcap treatment.
This is actually a hybrid that can be either too high (if npc_types.AC is
already generous) or appropriately bounded (if the softcap kicks in).

### Comparison Table: AC

| Aspect | Client | Companion | Gap |
|--------|--------|-----------|-----|
| Base AC source | Item AC only | npc_types.AC + Item AC | Companion gets NPC base AC too |
| Shield AC | From equipped shield | From equipped shield (IsOfClientBot=true) | **Same** |
| EQ math (4/3 multiplier) | Applied to item AC | Applied to item AC | **Same** |
| Anti-twink cap | Applied | Applied (IsOfClientBot=true) | **Same** |
| Defense skill contribution | skill/3 or skill/2 | skill/5 (NPC path) | **Different: NPC path** |
| Spell/AA AC bonuses | Applied with Client divisor | Applied with NPC divisor | **Different: NPC path** |
| AGI contribution | AGI/20 if > 70 | AGI/20 if > 70 | **Same** |
| AC softcap | Applied | Applied (IsOfClientBot=true) | **Same** |
| Item AC from gear | Yes | Yes (CalcItemBonuses) | **Same** |

---

## 3. Attack / Hit Chance / Accuracy

### Hit Determination

Both NPCs and Clients use the same `Mob::DoAttack()` -> `Mob::CheckHitChance()`
pipeline. The key inputs are:

- **offense:** `Mob::offense(skill)` — for NPCs uses `GetMobFixedWeaponSkill()`
  when `UseMobStaticOffenseSkill` rule is true, otherwise `GetSkill(skill)`
- **tohit:** `Mob::GetTotalToHit(skill, bonus)` — combines offense skill +
  spell/item/AA accuracy bonuses

### How NPC Hit Chance Works

NPCs use `NPC::Attack()` which calls:
```cpp
my_hit.offense = offense(my_hit.skill);
my_hit.tohit = GetTotalToHit(my_hit.skill, hit_chance_bonus);
```

### How Client Hit Chance Works

Clients use the same functions but with actual skill values from training.

### How Companions Work

Companions call `NPC::Attack()` (through `Companion::Attack()` which delegates
to `NPC::Attack()`). So they use the **NPC attack path** for hit calculation:

**Source: companion.cpp:439-466**
```cpp
bool Companion::Attack(Mob* other, int Hand, ...) {
    // ... safety checks for attacking owner/group ...
    return NPC::Attack(other, Hand, ...);
}
```

The NPC attack path calculates offense from NPC skill values (which for
companions come from `npc_types`).

### Does DEX/ATK from Gear Affect Companion Hit Chance?

**Partially.** The `itembonuses.ATK` is added via `Mob::GetTotalToHit()`:

```cpp
int Mob::GetTotalToHit(SkillType skill, int chance_mod) {
    // ... base from offense skill ...
    // + spell/item/AA accuracy bonuses
    // itembonuses.Accuracy IS included
}
```

However, the ATK stat from items (as opposed to accuracy) works differently
for NPCs vs Clients. NPCs use their `npc_types.ATK` field directly.

### Comparison Table: Hit Chance

| Aspect | Client | Companion | Gap |
|--------|--------|-----------|-----|
| Attack function | Client::Attack() | NPC::Attack() via Companion::Attack() | **Different path** |
| Offense skill | Trained weapon skill | NPC skill (npc_types or fixed) | **NPC path** |
| Accuracy from items | itembonuses.Accuracy | itembonuses.Accuracy | **Same** |
| ATK stat source | Calculated from STR + items | npc_types.ATK | **Different source** |
| Hit chance formula | Mob::CheckHitChance() | Mob::CheckHitChance() | **Same formula** |

---

## 4. Melee Damage

### NPC Damage Formula (Used by Companions)

This is the most critical difference. NPCs use `GetBaseDamage()` and
`GetMinDamage()` from `npc_types`, NOT weapon damage from equipped items.

**Source: attack.cpp:2362-2363 (NPC::Attack)**
```cpp
my_hit.base_damage = GetBaseDamage() + eleBane;  // npc_types.max_dmg scaled
my_hit.min_damage = GetMinDamage();               // npc_types.min_dmg
```

Where `GetBaseDamage()` returns a value derived from `npc_types.max_dmg`,
and `GetMinDamage()` returns `npc_types.min_dmg`.

### Client Damage Formula

Clients use weapon damage from their equipped item:

**Source: attack.cpp:1640**
```cpp
my_hit.base_damage = GetWeaponDamage(other, weapon, &hate);
```

`GetWeaponDamage()` reads `weapon->Damage` from the equipped `ItemInstance`.

### Do Companions Use Weapon Damage from Equipped Weapons?

**NO.** Companions use `NPC::Attack()` which reads `GetBaseDamage()` from
`npc_types`, NOT from the equipped weapon. The weapon in equipment[] is used
for:
- Animation/skill type selection (attack.cpp:2258-2296)
- Bane/elemental damage (attack.cpp:2333-2347)
- Proc triggers (attack.cpp:2417-2421)

But the base damage number comes from `npc_types.max_dmg` / `npc_types.min_dmg`.

**This is the biggest gap.** A companion wielding a high-damage weapon gets no
damage increase from it (only procs and bane damage). The weapon is essentially
cosmetic for base damage purposes.

### Damage Bonus (DB)

For Clients, damage bonus is calculated based on weapon delay:

**Source: attack.cpp:1676-1683**
```cpp
if (Hand == slotPrimary && GetLevel() >= 28 && IsWarriorClass()) {
    ucDamageBonus = GetWeaponDamageBonus(weapon->GetItem());
    my_hit.min_damage = ucDamageBonus;
}
```

For NPCs, damage bonus is NOT applied in `NPC::Attack()` — the min_damage is
set directly from `GetMinDamage()` (npc_types.min_dmg).

For Companions: since they use `NPC::Attack()`, **damage bonus from weapon delay
is NOT applied**.

### Comparison Table: Melee Damage

| Aspect | Client | Companion | Gap |
|--------|--------|-----------|-----|
| Base damage source | Weapon->Damage | npc_types.max_dmg (GetBaseDamage) | **CRITICAL: weapon damage ignored** |
| Min damage | Weapon damage bonus | npc_types.min_dmg (GetMinDamage) | **CRITICAL: different formula** |
| Damage bonus from delay | GetWeaponDamageBonus() | Not applied | **Missing** |
| Elemental/Bane damage | From weapon | From weapon (NPC::Attack) | **Same** |
| STR damage bonus | Via CalcItemBonuses | Via CalcItemBonuses (stat exists) | Indirect via STR stat |
| Weapon procs | Full proc system | TryWeaponProc (NPC::Attack line 2417) | **Same** |

---

## 5. Weapon Delay / Attack Speed / Haste

### NPC Attack Speed

NPCs use `attack_delay` from `npc_types` (stored in milliseconds, typically
values like 20-40 representing 2.0s-4.0s delay).

**Source: attack.cpp:6784-6827 (NPC::SetAttackTimer)**
```cpp
void NPC::SetAttackTimer() {
    float haste_mod = GetHaste() * 0.01f;
    attack_timer.SetAtTrigger(4000, true);  // default 4s
    int speed = (attack_delay / haste_mod) + (HundredHands adjustment);
    TimerToUse->SetAtTrigger(std::max(MinHastedDelay, speed), true, true);
}
```

### Client Attack Speed

Clients use weapon delay from their equipped item:

**Source: attack.cpp:6682-6727 (Client::SetAttackTimer)**
```cpp
void Client::SetAttackTimer() {
    float haste_mod = GetHaste() * 0.01f;
    // ... reads weapon->Delay from inventory for each hand slot
    // speed = weapon_delay * 100 / haste_mod
}
```

### How Companions Work

Companions inherit `NPC::SetAttackTimer()` through `NPC::CalcBonuses()` ->
`Mob::CalcBonuses()` -> `SetAttackTimer()`.

**The attack timer uses `attack_delay` from `npc_types`, NOT weapon delay from
equipped items.** This is consistent with the NPC damage model — weapons
equipped on companions are cosmetic for attack speed purposes.

### Do Companions Benefit from Haste?

**YES, from spells/buffs.** The `GetHaste()` function (mob.cpp:5446) reads
from `spellbonuses.haste`, which includes haste buffs cast on the companion.

**YES, from items (partially).** The `itembonuses.haste` is calculated by
`CalcItemBonuses()`, but the NPC `GetHaste()` function only uses
`spellbonuses.haste`, `spellbonuses.hastetype2`, and `spellbonuses.inhibitmelee`.
It does NOT include `itembonuses.haste`.

**Source: mob.cpp:5446-5476 (Mob::GetHaste)**
```cpp
int Mob::GetHaste() {
    // Only spellbonuses.haste is used
    // itembonuses.haste is NOT used for NPC path
    if (spellbonuses.haste < 0) { ... }
    int h = spellbonuses.haste + spellbonuses.hastetype2;
    // ... cap logic
    h += itembonuses.haste;  // <-- THIS IS added (line ~5480+)
}
```

Actually, looking more carefully at `GetHaste()`, it DOES add `itembonuses.haste`
after the spell haste, but the cap logic may differ. The key point is that
haste from items IS included in the haste calculation for NPCs, and since
companions call `CalcItemBonuses()` which populates `itembonuses.haste`,
haste items DO work on companions.

### Comparison Table: Attack Speed

| Aspect | Client | Companion | Gap |
|--------|--------|-----------|-----|
| Base delay source | Weapon->Delay | npc_types.attack_delay | **Different: weapon delay ignored** |
| Haste from spells | Full support | Full support (spellbonuses.haste) | **Same** |
| Haste from items | Full support | Supported (itembonuses.haste via CalcItemBonuses) | **Same** |
| HundredHands | Applied | Applied (NPC::SetAttackTimer) | **Same** |
| Min hasted delay | Combat::MinHastedDelay | Combat::MinHastedDelay | **Same** |

---

## 6. Dual Wield / Double Attack / Special Attacks

### NPC Special Attacks

NPCs get special attacks from `npc_types.special_abilities` field and from
level-based checks. In `NPC::SetAttackTimer()`:

```cpp
if (i == slotSecondary) {
    if (!CanThisClassDualWield() ||
        (HasTwoHanderEquipped() && !GetSpecialAbility(QuadrupleAttack))) {
        attack_dw_timer.Disable();
        continue;
    }
}
```

NPCs can dual wield if:
- Their class supports it (`CanThisClassDualWield()` — checks class list)
- AND they have a secondary weapon equipped OR special ability

Double attack for NPCs comes from `npc_types.attack_count` and
`GetSpecialAbility(SpecialAbility::DoubleAttack)`.

### Client Special Attacks

Clients get dual wield/double attack from trained skills and level thresholds:
- **Dual Wield:** Requires SkillDualWield > 0 and a weapon in secondary slot
- **Double Attack:** Based on SkillDoubleAttack vs random roll
- **Triple Attack:** Based on level and AA

### How Companions Work

Companions inherit NPC special attack behavior. Their special abilities come
from the `npc_types.special_abilities` field of their source NPC.

**Important:** In `Companion::Spawn()` (companion.cpp:1217-1219), some
problematic special abilities are stripped:
```cpp
SetSpecialAbility(SpecialAbility::MeleeImmunity, 0);
SetSpecialAbility(SpecialAbility::MagicImmunity, 0);
SetInvul(false);
```

But dual wield, double attack, and other combat specials are NOT stripped —
they are preserved from the source NPC.

### Comparison Table: Special Attacks

| Aspect | Client | Companion | Gap |
|--------|--------|-----------|-----|
| Dual wield | Skill-based | NPC class check + special_abilities | **Different mechanism** |
| Double attack | Skill-based roll | NPC attack_count / special_abilities | **Different mechanism** |
| Triple attack | Level/AA-based | Only if source NPC had it | **Likely missing** |
| Riposte | Skill-based | NPC special ability | **Different mechanism** |
| Dodge | Skill-based | NPC special ability | **Different mechanism** |
| Backstab | Class + position | Only if class=rogue + position logic | **Partially same** |
| Kick/Bash | Class + level | Only if source NPC has skill | **May be missing** |

---

## 7. Dodge / Parry / Riposte / Block (Avoidance)

### NPC Avoidance

For NPCs, avoidance is primarily controlled by:
- `npc_types.avoidance` (avoidance rating)
- Special abilities: `SpecialAbility::Dodge`, `SpecialAbility::Parry`,
  `SpecialAbility::Riposte`, `SpecialAbility::Block`

### Client Avoidance

Clients use skill-based avoidance:
- **Dodge:** SkillDodge roll
- **Parry:** SkillParry roll (requires weapon)
- **Riposte:** SkillRiposte roll (requires weapon)
- **Block:** SkillBlock roll (requires shield, Warrior/Paladin/SK)

### How Companions Work

Because `IsOfClientBot()` returns `true`, companions take the Client/Bot
path in `Mob::AvoidDamage()`:

**Source: attack.cpp:258-272 (AvoidDamage)**
```cpp
if (IsOfClientBot()) {
    // Uses skill-based avoidance checks
    // Check riposte, parry, dodge, block skills
}
```

This means companions use **Client/Bot-style skill checks** for avoidance,
not NPC special ability flags. The skills they have depend on what's set
in the NPC data or via NPC skill defaults.

### Does AGI from Gear Affect Companion Avoidance?

**Yes.** AGI contributes to avoidance through the AC formula (AGI/20 if >70)
and through the avoidance bonus calculations. Since companion items update
`itembonuses.AGI`, which is added to the base AGI when `GetAGI()` is called,
AGI from gear does affect avoidance indirectly.

### Comparison Table: Avoidance

| Aspect | Client | Companion | Gap |
|--------|--------|-----------|-----|
| Avoidance path | Client/Bot skill checks | Client/Bot skill checks (IsOfClientBot) | **Same path** |
| Dodge | SkillDodge | NPC skill value | Skills may be low/missing |
| Parry | SkillParry + weapon | NPC skill value + weapon check | Skills may be low/missing |
| Riposte | SkillRiposte + weapon | NPC skill value + weapon check | Skills may be low/missing |
| Block | SkillBlock + shield | NPC skill value + shield check | Skills may be low/missing |
| AGI contribution | Yes | Yes (via itembonuses.AGI) | **Same** |

**Key concern:** NPC skill values for defense/dodge/parry/riposte may be very
low or zero depending on the source NPC. Most PEQ NPCs don't have carefully
tuned skill values for these skills. Companions that are supposed to be
class-appropriate (e.g., a warrior companion should have good parry/riposte)
may have inadequate skill values.

---

## 8. HP and HP Regen

### NPC HP Calculation

NPC HP comes from `npc_types.hp` directly (or from level/class formulas if
the npc_types row doesn't specify an explicit HP value):

```cpp
// NPC constructor sets max_hp from NPCType->max_hp
```

### Client HP Calculation

Clients use: `base_hp + STA_bonus + item_hp + spell_hp + AA_hp`.

### Companion HP

Companion HP comes from `npc_types.max_hp` (stored as `m_base_hp`), and is
scaled linearly on level-up:

**Source: companion.cpp:311-312**
```cpp
max_hp   = (int64)(m_base_hp * scale);
base_hp  = max_hp;
```

### HP Regen

**Source: companion.cpp:472-484 (CalcHPRegen)**
```cpp
int64 Companion::CalcHPRegen() const {
    int64 native_regen = NPCTypedata ? NPCTypedata->hp_regen : 0;
    int64 floor_regen  = static_cast<int64>(RuleI(Companions, HPRegenPerTic));
    return std::max(native_regen, floor_regen);
}
```

The companion's `hp_regen` field is seeded with this value in `AI_Start()`.
Then `NPC::Process()` adds `itembonuses.HPRegen + spellbonuses.HPRegen` on
top via `GetNPCHPRegen()`:

**Source: npc.h:340**
```cpp
int64 GetNPCHPRegen() const {
    return hp_regen + itembonuses.HPRegen + spellbonuses.HPRegen;
}
```

**OOC Regen:** Companions also get out-of-combat regen via the
`Companions::OOCRegenPct` rule (default: 5% of max HP per tic).

**Source: companion.cpp:564**
```cpp
ooc_regen = RuleI(Companions, OOCRegenPct);
```

### Comparison Table: HP / HP Regen

| Aspect | Client | Companion | Gap |
|--------|--------|-----------|-----|
| HP source | Base + STA + items + spells | npc_types.max_hp scaled by level | **Different source** |
| HP regen base | Level-based formula | max(npc_types.hp_regen, HPRegenPerTic rule) | **Different formula** |
| Item HP regen | itembonuses.HPRegen | itembonuses.HPRegen (via GetNPCHPRegen) | **Same** |
| Spell HP regen | spellbonuses.HPRegen | spellbonuses.HPRegen (via GetNPCHPRegen) | **Same** |
| Sitting regen bonus | Yes (significant) | No explicit sitting bonus beyond OOC | **Gap: no sitting regen bonus** |
| OOC regen | Yes | Yes (OOCRegenPct rule, default 5%) | **Same concept** |
| STA contribution | STA -> HP formula | STA is just a number, no HP conversion | **Gap: STA doesn't add HP** |

---

## 9. Mana and Mana Regen

### Implementation

Companion mana regen is explicitly implemented with a meditate formula:

**Source: companion.cpp:491-524 (CalcManaRegen)**
```cpp
int64 Companion::CalcManaRegen() {
    if (GetMaxMana() <= 0) return 0;
    int32 regen = 2;  // flat standing base

    // Bards: slow regen
    if (cls == Class::Bard) {
        regen = IsSitting() ? 2 : 1;
        regen += itembonuses.ManaRegen + aabonuses.ManaRegen;
        return regen;
    }

    // Sitting non-melee casters use meditate formula
    if (IsSitting() && GetArchetype() != Archetype::Melee) {
        uint16 meditate = GetSkill(EQ::skills::SkillMeditate);
        regen = (((meditate / 10) + (level - (level / 4))) / 4) + 4;
    }

    regen += spellbonuses.ManaRegen + itembonuses.ManaRegen + aabonuses.ManaRegen;
    regen = (regen * RuleI(Character, ManaRegenMultiplier)) / 100;
    regen = (regen * RuleI(Companions, CompanionManaRegenMult)) / 100;
    return regen;
}
```

### Comparison Table: Mana Regen

| Aspect | Client | Companion | Gap |
|--------|--------|-----------|-----|
| Standing base | ~2 mana/tic | 2 mana/tic | **Same** |
| Sitting meditate | Meditate formula | Meditate formula (identical) | **Same** |
| Item mana regen | itembonuses.ManaRegen | itembonuses.ManaRegen | **Same** |
| Spell mana regen | spellbonuses.ManaRegen | spellbonuses.ManaRegen | **Same** |
| Companion multiplier | N/A | CompanionManaRegenMult rule (default 100%) | Extra tuning knob |
| Global multiplier | ManaRegenMultiplier | ManaRegenMultiplier | **Same** |
| Bard regen | 1 standing / 2 sitting | 1 standing / 2 sitting | **Same** |

**Note:** Mana regen is one of the best-implemented companion mechanics.

---

## 10. Spell/Buff Effects on Companions

### Do Buffs Affect Companion Stats?

**YES.** Companions fully participate in the spell/buff system because:

1. `Mob::CalcBonuses()` calls `CalcSpellBonuses(&spellbonuses)` which iterates
   all active buffs and computes `spellbonuses.*` values
2. `NPC::CalcBonuses()` calls `Mob::CalcBonuses()`
3. Buff application via `SpellOnTarget()` works on any Mob, including companions

### How Spell Bonuses Work

When a buff is cast on a companion:
1. `SpellOnTarget()` adds the buff to the companion's buff slots
2. On the next `CalcBonuses()` call, `CalcSpellBonuses()` recalculates all
   spell bonuses from active buffs
3. `spellbonuses.haste`, `spellbonuses.AC`, `spellbonuses.STR`, etc. are all updated

### Buff Types and Their Effects

| Buff Type | Works on Companions? | Mechanism |
|-----------|---------------------|-----------|
| Stat buffs (STR, STA, etc.) | **Yes** | spellbonuses.STR etc. via GetSTR() |
| AC buffs | **Yes** | spellbonuses.AC in ACSum() |
| Haste buffs | **Yes** | spellbonuses.haste in GetHaste() |
| HP regen buffs | **Yes** | spellbonuses.HPRegen in GetNPCHPRegen() |
| Mana regen buffs | **Yes** | spellbonuses.ManaRegen in CalcManaRegen() |
| Damage shields | **Yes** | DS triggers on Mob::Damage() for all Mobs |
| Resist buffs | **Yes** | spellbonuses.MR/FR/etc. in GetMR()/etc. |
| Root/Snare | **Yes** | Standard spell effects on Mob |
| Invisibility | **Yes** | Standard Mob invis tracking |
| Levitate | **Yes** | Standard Mob levitate |

### Buff Persistence

Companion buffs are saved/loaded across zones via `companion_buffs` table:

**Source: companion.cpp:1703-1803 (SaveBuffs/LoadBuffs)**

All buff slot data is preserved: spell_id, caster_level, ticks_remaining,
runes, counters, etc. `CalcBonuses()` is called after `LoadBuffs()`.

---

## 11. Item Special Effects

### Weapon Procs

**YES, weapon procs work.** In `NPC::Attack()`:

**Source: attack.cpp:2417-2421**
```cpp
if (has_hit && !bRiposte && !other->HasDied()) {
    TryWeaponProc(nullptr, weapon, other, Hand);
    if (!other->HasDied())
        TrySpellProc(nullptr, weapon, other, Hand);
}
```

`TryWeaponProc()` checks the weapon for proc effects and fires them.

### Worn Effects

**Partially.** Worn effects (like haste, mana regen, etc.) work through
the `CalcItemBonuses()` system. When items are loaded into the inventory
profile via `GetInv().PutItem()`, `CalcItemBonuses()` reads the item data
and applies stat bonuses including:
- Haste (`itembonuses.haste`)
- Mana regen (`itembonuses.ManaRegen`)
- HP regen (`itembonuses.HPRegen`)
- Stat bonuses (`itembonuses.STR`, etc.)
- AC (`itembonuses.AC`)

### Click Effects

**NO.** Companions cannot activate click effects. There is no mechanism for
a companion to use a clicky item — they have no UI, no hotbar, and no
casting-from-item logic in their AI.

### Comparison Table: Item Effects

| Effect Type | Works? | Mechanism |
|------------|--------|-----------|
| Weapon procs | **Yes** | TryWeaponProc in NPC::Attack() |
| Spell procs | **Yes** | TrySpellProc in NPC::Attack() |
| Worn effects (stat bonuses) | **Yes** | CalcItemBonuses() |
| Worn haste | **Yes** | itembonuses.haste in GetHaste() |
| Worn mana regen | **Yes** | itembonuses.ManaRegen in CalcManaRegen() |
| Worn HP regen | **Yes** | itembonuses.HPRegen in GetNPCHPRegen() |
| Click effects | **No** | No mechanism for AI-driven clicks |
| Focus effects | **Partially** | Focus effects on cast spells may apply via Mob focus code |
| Augment effects | **Unknown** | Augments not currently supported in companion_inventories |

---

## 12. Resistances

### NPC Resistances

NPCs get resistances from `npc_types`:
- MR, FR, DR, PR, CR columns

### Client Resistances

Clients use: `base_race_resist + level_bonus + item_resists + spell_resists + AA_resists`

### Companion Resistances

Companions start with `npc_types` resist values (stored as `m_base_mr`, etc.)
and scale them linearly on level-up:

```cpp
MR = (int32)(m_base_mr * scale);
FR = (int32)(m_base_fr * scale);
// etc.
```

Item and spell bonuses are added via the standard `GetMR()` formula:
```cpp
inline int32 GetMR() const { return MR + itembonuses.MR + spellbonuses.MR + aabonuses.MR; }
```

### Comparison Table: Resistances

| Aspect | Client | Companion | Gap |
|--------|--------|-----------|-----|
| Base source | Race + level | npc_types + level scaling | **Different source** |
| Item bonuses | itembonuses.MR etc. | itembonuses.MR etc. | **Same** |
| Spell bonuses | spellbonuses.MR etc. | spellbonuses.MR etc. | **Same** |
| AA bonuses | aabonuses.MR etc. | aabonuses.MR (always 0) | Not applicable |
| Resist caps | Level-based caps | No explicit caps | **Gap: may exceed intended caps** |

---

## 13. Companion Spell System

### Architecture

Companion spells come from the `companion_spell_sets` database table:

```sql
companion_spell_sets (
    id, class_id, min_level, max_level,
    spell_id, spell_type, stance, priority,
    min_hp_pct, max_hp_pct
)
```

**Source: companion_ai.cpp:184-244 (LoadCompanionSpells)**

Spells are loaded per class and level range. The `spell_type` bitmask uses
the same `SpellType_*` constants as Mercs:
- `SpellType_Nuke` (1), `SpellType_Heal` (2), `SpellType_Root` (4)
- `SpellType_Buff` (8), `SpellType_Escape` (16), `SpellType_Pet` (32)
- `SpellType_Lifetap` (64), `SpellType_Snare` (128), `SpellType_DOT` (256)
- `SpellType_Dispel` (512), `SpellType_InCombatBuff` (1024)
- `SpellType_Mez` (2048), `SpellType_Charm` (4096)
- `SpellType_Slow` (8192), `SpellType_Debuff` (16384)
- `SpellType_Cure` (32768), `SpellType_Resurrect` (65536)
- `SpellType_PreCombatBuff` (131072)

### Spell Content by Class

From database query:

| Class ID | Class Name | Spell Count | Level Range |
|----------|-----------|-------------|-------------|
| 2 | Cleric | 79 | 1-65 |
| 3 | Paladin | 41 | 9-65 |
| 4 | Ranger | 52 | 9-65 |
| 5 | Shadow Knight | 56 | 7-65 |
| 6 | Druid | 91 | 1-65 |
| 8 | Bard | 78 | 2-65 |
| 10 | Shaman | 91 | 0-65 |
| 11 | Necromancer | 85 | 1-65 |
| 12 | Wizard | 76 | 1-65 |
| 13 | Magician | 68 | 1-65 |
| 14 | Enchanter | 116 | 0-65 |
| 15 | Beastlord | 63 | 8-65 |

**Missing classes:** Warrior (1), Monk (7), Rogue (9) — these are pure melee
classes with no companion spell sets, which is correct.

### Class-Specific AI Logic

Each class has a dedicated AI handler in `companion_ai.cpp`:

#### AI_Cleric (lines 830-888)
- **Priority:** Cure > Heal > Buff
- **Engaged:** Cure conditions, heal group, buff if mana > 50%
- **Passive:** Only heal owner below 25% HP
- **Idle:** Cure > heal > resurrect (placeholder) > buff

#### AI_Wizard (not shown in detail but follows pattern)
- **Priority:** Nuke
- **Engaged:** Nuke target, no healing
- **Idle:** Buff

#### AI_Shaman (lines 967-999+)
- **Priority:** Slow > Heal > Cure > DoT
- **Engaged:** Slow target (70% chance), heal, cure
- **Idle:** Cure > heal > buff

#### AI_Enchanter
- **Priority:** Mez > Slow > Buff
- **Engaged:** Mez secondary targets, slow primary
- **Idle:** Buff group

#### AI_Druid (lines 895-960)
- **Priority:** Heal > Cure > Root > DoT > Nuke
- **Engaged:** Heal, cure, root (30% chance), DoT/nuke if aggressive
- **Idle:** Cure > heal > buff

### Mana Management

- OOM threshold: 10% mana — below this, no casting (companion_ai.cpp:282)
- Buff conservation: Don't buff below 30% mana (companion_ai.cpp:434)
- Stance-based casting frequency:
  - Passive: 20% chance to attempt cast
  - Balanced: 50% chance
  - Aggressive: 80% chance

### Heal Target Selection

**Source: companion_ai.cpp:355-423 (AI_HealGroupMember)**
- Iterates all group members
- Finds most injured member below threshold (90% engaged, 99% idle)
- Prioritizes owner over other members
- Also considers self-healing
- Selects best heal spell based on HP thresholds from spell data

---

## 14. Known Gaps / Missing Mechanics

### Critical Gaps

1. **Weapon damage not used for base melee damage** — Companions use
   `npc_types.max_dmg`/`min_dmg` instead of equipped weapon damage.
   A companion wielding an epic weapon does the same base damage as one
   wielding a rusty sword. **Priority: CRITICAL**

2. **Weapon delay not used for attack speed** — Attack timer uses
   `npc_types.attack_delay` not weapon delay. A fast weapon gives no
   attack speed benefit. **Priority: CRITICAL**

3. **Damage bonus not applied** — The weapon damage bonus
   (`GetWeaponDamageBonus()`) that melee classes get at level 28+ is
   not calculated for companions since they use `NPC::Attack()`.
   **Priority: HIGH**

### High Gaps

4. **No individual CalcSTR/CalcSTA/etc calls** — Stats are raw values
   from npc_types plus item/spell bonuses. The Client-style stat combination
   formulas (which include class-specific scaling) are not used.
   **Priority: MEDIUM** (functional but different scaling)

5. **Defense/avoidance skills may be low** — Companions use Client/Bot-style
   skill checks for avoidance, but NPC skill values from npc_types may be
   very low or zero. A warrior companion may have terrible parry/riposte
   skills. **Priority: HIGH**

6. **STA doesn't contribute to HP** — Unlike clients where STA adds
   significant HP, companion HP comes directly from npc_types. More STA
   from gear doesn't increase max HP. **Priority: MEDIUM**

7. **No heroic stat processing** — `CalcHeroicBonuses()` is not called.
   Items with heroic stats have those stats ignored.
   **Priority: LOW** (Classic-Luclin items don't have heroic stats)

### Medium Gaps

8. **No click effects from items** — Companions cannot activate clicky
   items. **Priority: MEDIUM**

9. **No sitting HP regen bonus** — Clients get significant HP regen bonus
   from sitting; companions only get OOC regen from the rule.
   **Priority: MEDIUM**

10. **No triple attack** — Unless the source NPC had it as a special ability.
    **Priority: MEDIUM**

11. **NPC defense skill divisor differs** — In ACSum, NPC defense skill is
    divided by 5, while Client/Bot defense is divided by 3. Since companions
    hit the NPC path for this calculation, they get less AC from defense skill.
    **Priority: LOW**

### Low Gaps

12. **No resist caps** — Companions may exceed intended resist limits if given
    resist gear plus resist buffs plus high npc_types resists.
    **Priority: LOW**

13. **No augment support** — `companion_inventories` doesn't track augments.
    **Priority: LOW**

14. **Focus effects uncertain** — Whether spell focus items (increased spell
    damage, reduced mana cost) work on companion casts is untested.
    **Priority: LOW**

---

## 15. Summary Gap Table

| # | Mechanic | Status | Priority | Fix Approach |
|---|----------|--------|----------|--------------|
| 1 | Weapon damage for base melee | **MISSING** | Critical | Override NPC::Attack or add weapon damage path |
| 2 | Weapon delay for attack speed | **MISSING** | Critical | Override SetAttackTimer to read weapon delay |
| 3 | Damage bonus from weapon delay | **MISSING** | High | Add GetWeaponDamageBonus() call |
| 4 | Individual stat calculation | **SIMPLIFIED** | Medium | Could add CalcSTR/etc calls, but npc_types works |
| 5 | Defense/avoidance skills | **POSSIBLY LOW** | High | Set class-appropriate skill values at recruitment |
| 6 | STA -> HP conversion | **MISSING** | Medium | Add STA contribution to max HP calculation |
| 7 | Heroic stat processing | **MISSING** | Low | N/A for Classic-Luclin era |
| 8 | Click effects | **MISSING** | Medium | Would need AI-driven click system |
| 9 | Sitting HP regen bonus | **MISSING** | Medium | Add sitting bonus to CalcHPRegen |
| 10 | Triple attack | **CONDITIONAL** | Medium | Set via special ability if class warrants |
| 11 | Defense skill AC divisor | **DIFFERENT** | Low | Cosmetic difference, minor impact |
| 12 | Resist caps | **MISSING** | Low | Add cap enforcement |
| 13 | Augment support | **MISSING** | Low | Extend companion_inventories schema |
| 14 | Focus effects | **UNCERTAIN** | Low | Needs testing |
| 15 | Spell bonuses work | **WORKING** | N/A | Already functional |
| 16 | Item stat bonuses | **WORKING** | N/A | Already functional via CalcItemBonuses |
| 17 | Haste (spell + item) | **WORKING** | N/A | Already functional |
| 18 | Weapon procs | **WORKING** | N/A | Already functional |
| 19 | Mana regen (meditate) | **WORKING** | N/A | Already functional |
| 20 | HP regen (base + items + spells) | **WORKING** | N/A | Already functional |
| 21 | Buff system | **WORKING** | N/A | Full buff save/load/apply |
| 22 | Companion spell AI | **WORKING** | N/A | Class-specific AI for 12 classes |

### Architecture Summary

The companion system occupies a unique position in the entity hierarchy:
it inherits from NPC (getting NPC-style damage, attack timers, and AI) but
declares itself as `IsOfClientBot()` (getting Client/Bot-style AC, avoidance,
crits, and stat caps). This dual identity means companions are a hybrid that
gets the best of some worlds and the worst of others.

**The two most impactful improvements would be:**
1. Making weapon damage and delay affect companion combat output
2. Ensuring class-appropriate skill values for avoidance/offense

These would make equipped weapons feel meaningful and companions that should be
tanky actually tank effectively.
