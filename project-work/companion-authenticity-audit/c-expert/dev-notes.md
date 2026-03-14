# Companion Authenticity Audit — Dev Notes: C Expert

> **Feature branch:** `feature/companion-authenticity-audit`
> **Agent:** c-expert
> **Task(s):** Task #1 — C++ audit: companion stats, melee, HP/mana, regen, AC, attack formulas
> **Date started:** 2026-03-14
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | C++ audit: companion stats, melee, HP/mana, regen, AC, attack formulas | None | Complete |

---

## Stage 1-4: Comprehensive Audit Findings

This document captures a full read of `eqemu/zone/companion.cpp` (3567 lines),
`eqemu/zone/companion_ai.cpp` (1829 lines), cross-referenced against
`eqemu/zone/attack.cpp`, `eqemu/zone/mob.cpp`, `eqemu/zone/npc.cpp`,
and `eqemu/zone/spells.cpp`.

---

## System 1: Base Stats (STR, STA, DEX, AGI, WIS, INT, CHA)

### Current Companion Behavior

Stats come directly from `npc_types` at recruitment time (`companion.cpp:85-98`).
The constructor copies `d->STR`, `d->STA`, `d->DEX`, `d->AGI`, `d->INT`, `d->WIS`,
`d->CHA` into `Mob` member fields (`STR`, `STA`, etc.) AND stores them as base
values (`m_base_str` etc.) for future scaling.

**Scaling formula** (`companion.cpp:312-343`):
```
scale = (float)current_level / (float)m_recruited_level
stat_X = (int32)(m_base_X * scale)
```
Integer cast from float — this is proportional linear scaling, not the EQ player
stat table approach.

**`ApplyStatScalePct()`** (`companion.cpp:345-371`): Applies a server-wide percentage
multiplier (`RuleI(Companions, StatScalePct)`, default 100). Scales all base stats
including HP, mana, AC, ATK, resistances.

**`CalcBonuses()`** is called at end of both scaling functions, so itembonuses and
spellbonuses are re-applied on top of the scaled raw stats.

### Expected Authentic EQ Behavior

Players have class/race/level-based stat tables (`character_base_data` table) with
explicit values per level. Progression is not simple linear scaling — stats often
plateau or grow nonlinearly. NPCs get their stats entirely from `npc_types` — no
per-level formula.

### Gap Assessment: MINOR DIVERGENCE

The scaling formula is "close enough" for companion purposes. The per-companion
stat table entries in `npc_types` are already pre-tuned by data-expert to reasonable
values at the NPC's base level. Linear proportional scaling produces reasonable
results when recruiting an NPC near the player's level. The main weakness: recruiting
a very low-level NPC then leveling them produces lower absolute stats than a
level-appropriate NPC of the same class would have (because NPC stat values don't
follow the same growth curves as player stat tables). This is a data/design issue,
not a formula bug.

---

## System 2: HP and Mana

### Current Companion Behavior — MaxHP

**`Companion::CalcMaxHP()`** (`companion.cpp:808-868`):
1. Calls `Mob::CalcMaxHP()` which computes: `base_hp + itembonuses.HP + PercentMaxHP + FlatMaxHP`
2. `base_hp` = `max_hp` as set by `ScaleStatsToLevel()` = `m_base_hp * scale`
3. Adds STA-to-HP bonus using only **bonus STA from items/spells** (not base STA):
   - Tanks (WAR/PAL/SHD): 8 HP/STA at lvl60, scaled by `min(level, 60)/60`
   - Melee DPS: 5 HP/STA
   - Priests: 4 HP/STA
   - Casters: 3 HP/STA
   - Entire bonus scaled by `RuleI(Companions, STAToHPFactor)` (default 100)

**`Mob::CalcMaxHP()`** (`mob.cpp:989-995`):
```cpp
max_hp = (base_hp + itembonuses.HP);
max_hp += max_hp * ((aabonuses.PercentMaxHPChange + spellbonuses.PercentMaxHPChange
          + itembonuses.PercentMaxHPChange) / 10000.0f);
max_hp += spellbonuses.FlatMaxHPChange + itembonuses.FlatMaxHPChange
          + aabonuses.FlatMaxHPChange;
```

### Current Companion Behavior — MaxMana

**`Companion::CalcMaxMana()`** (`companion.cpp:892-942`):
- Non-casters: returns 0 immediately
- `npc_mana == 0` path (NPC type has no explicit mana): delegates to `NPC::CalcMaxMana()`
  which uses `((INT or WIS)/2 + 1) * level + bonuses` — this is the Mob/Player formula
- `npc_mana != 0` path (BUG-017 fix): reconstructs from `m_base_mana * (level / recruited_level)`
  then adds item/spell bonuses. This prevents `NPC::CalcMaxMana()` from resetting to the
  unscaled `npc_mana` value.

**`NPC::CalcMaxMana()`** (`npc.cpp:2720-2751`): When `npc_mana != 0`, returns
`npc_mana + spellbonuses.Mana + itembonuses.Mana` (ignores current level entirely).

### Expected Authentic EQ Behavior

Players use `CalcBaseHP()` (`client.cpp`) which uses a class-specific multiplier
on STA applied at each level increment. Players receive: `(STA - 25) * hpfactor +
base_class_hp_per_level * level`. Mana uses `((INT or WIS)/2 + 1) * level` for all
casters, which is the same formula NPC::CalcMaxMana uses for npc_mana=0 case.

### Gap Assessment: MATCH (with caveats)

- MaxHP: The companion system correctly implements a STA-to-HP conversion for bonus STA
  from gear, scaled by class archetype and level. Base HP (from NPC type) already
  represents the NPC's natural constitution. The formula is reasonable and intentional.
- MaxMana: For `npc_mana=0` NPCs (which is most recruited casters), the companion
  correctly uses `((INT or WIS)/2 + 1) * level` — identical to player formula.
  For `npc_mana != 0` NPCs, the BUG-017 fix correctly scales mana with level.
  **One nuance:** ShadowKnight and Bard are `IsIntelligenceCasterClass()` so they
  get the INT-based mana formula — correct per EQ lore.

---

## System 3: AC and Defense

### Current Companion Behavior

**`ACSum()` in `attack.cpp:900-976`** — the `IsNPC()` branch:

```
ac = base_ac + itembonuses.AC   (items/tribute)
shield_ac calculated if HasShieldEquipped() && IsOfClientBot()  ← INCLUDES Companion
ac = (ac * 4) / 3               (EQ AC math)
anti-twink cap: if IsOfClientBot() && level < LevelToStopACTwinkControl
ac = max(0, ac + GetClassRaceACBonus())

IsNPC() branch:
  ac += GetAC()                 ← NPC base AC from npc_types.AC
  ac += GetPetACBonusFromOwner()
  if IsCompanion():             ← SPECIAL CASE for companions
    casters: ac += SkillDefense/2 + spell_aa_ac/3
    others:  ac += SkillDefense/3 + spell_aa_ac/4
  else (regular NPC):
    ac += SkillDefense/5        ← NPC divisor is /5 (weaker)
    casters: ac += spell_aa_ac/3
    others:  ac += spell_aa_ac/4

ac += AGI/20 if AGI > 70

if IsOfClientBot():             ← INCLUDES Companion
  apply AC softcap by class (war_softcaps, palshd_softcaps, etc.)
  apply diminishing returns above softcap (GetSoftcapReturns())
```

Key: Companions get the **player/bot defense skill divisor** (`:3` for non-casters,
`:2` for casters), NOT the NPC divisor (`:5`). Companions also get:
- `IsOfClientBot()` path for shield AC calculation (`attack.cpp:902-911`)
- Anti-twink cap (`attack.cpp:916-917`)
- Full AC softcap with diminishing returns (`attack.cpp:958-970`)

`GetACSoftcap()` uses class-specific level-indexed arrays
(`war_softcaps`, `palshd_softcaps`, `clrbrdmnk_softcaps`, `rng_softcaps`, etc.)
— these are the same tables as used for players.

### Expected Authentic EQ Behavior

Players use their Defense skill as `SkillDefense/3` (non-casters) or `/2` (casters).
Players get AC softcap per class. Players' shield AC reads from inventory.

### Gap Assessment: MATCH

Companions get identical AC calculation as players/bots. The `IsCompanion()` guard at
`attack.cpp:932` explicitly gives companions the player AC divisors and `IsOfClientBot()`
returns true, giving them shield-from-inventory and AC softcap. This is correct and
intentional.

---

## System 4: Melee Combat — Attack Rating, Hit Chance, Damage

### Current Companion Behavior

**Attack path**: `Companion::Attack()` in `companion.cpp:466-664`.

When `RuleB(Companions, UseWeaponDamage)` is true (weapon-damage path):
- Reads weapon from `GetInv()` (inventory profile), not from NPC `equipment[]` array
- Calls `AttackAnimation(Hand, weapon_inst)` to get skill type
- `GetWeaponDamage(other, weapon_inst, &hate)` for base damage
- `DoDamageCaps()` on primary/secondary hands
- Bane/elemental damage from weapon stats
- **Damage bonus** (`#ifndef EQEMU_NO_WEAPON_DAMAGE_BONUS`):
  - Primary hand, level >= 28, `IsWarriorClass()` → `GetWeaponDamageBonus(weapon)`
  - Sinister Strikes offhand bonus when `aabonuses.SecondaryDmgInc || ...`
- `offense(my_hit.skill)` for tohit
- `GetTotalToHit()` for tohit value
- `DoAttack(other, my_hit, ...)` — passes through to `Mob::DoAttack()` which calls
  `CheckHitChance()`, `AvoidDamage()`, `MeleeMitigation()`, `TryCriticalHit()`

When `UseWeaponDamage` is false (fallback): uses `NPC::Attack()` which uses
`GetBaseDamage()` / `GetMinDamage()` from `npc_types`.

**Hit chance formula** (`mob.cpp:331-370` `CheckHitChance()`):
- Uses `GetTotalDefense()` (includes defender's Defense skill, AGI, buffs)
- Uses `hit.tohit` (from `GetTotalToHit()`)
- Rolls both, attacker wins if tohit roll > avoid roll
- **No special NPC or companion branching** — same formula for all mob types

**`offense()` function** (`attack.cpp:153-165`):
```cpp
if (IsNPC()) {
    return static_cast<int>(GetLevel() * 5 + 50); // NPC formula: level*5+50
}
if (IsClient()) {
    return GetSkill(skill) + 50;  // Player formula: skill+50
}
```
**COMPANIONS USE THE NPC OFFENSE FORMULA** because `IsNPC()` returns true.
Companions should ideally use the skill-based formula, but for most cases this
is comparable or even slightly better since `level*5+50` at level 60 = 350 vs
a player offense skill of ~250 at level 60.

### Expected Authentic EQ Behavior

Players' offense = `GetSkill(weapon_skill) + 50`.
For a level 60 player: weapon skill ~250 → offense = 300.
For a level 60 NPC: `60*5+50` = 350.
Companions at level 60 get offense 350 vs a player's ~300. Slight advantage.

### Gap Assessment: MINOR DIVERGENCE (companion-favorable)

Companions use NPC offense formula (level-based) instead of skill-based. Since
companions inherit NPC skill values from the recruited NPC's npc_types data, their
weapon skills are typically `level * 5` (set by NPC constructor `npc.cpp:387-388`).
So `GetSkill(skill) + 50` ≈ `level*5 + 50` for most companions anyway. The
formulas converge at typical levels. Not a significant gap.

---

## System 5: Dual Wield

### Current Companion Behavior

**`SetAttackTimer()`** (`companion.cpp:670-777`):
- When `UseWeaponDamage=true`: mirrors `Client::SetAttackTimer()` using weapon delays from `GetInv()`
- Dual wield check: `CanThisClassDualWield() && !HasTwoHanderEquipped()`
- Enables/disables `attack_dw_timer` based on weapon presence
- Applies HundredHands effect and haste mod
- HHE formula respects `Jun182014HundredHandsRevamp` rule

**`DoAttackRounds()`** (`companion.cpp:1078-1123`):
- Double attack: `CanThisClassDoubleAttack()` — for non-clients, checks `GetSkill(SkillDoubleAttack) > 0`
  NPC constructor sets `SkillDoubleAttack = level * 5` for levels 4-50, = 250 for 50+.
  So all companions level 4+ can double attack. ✓
- Off-hand double attack requires `SkillDoubleAttack > 149` OR GiveDoubleAttack bonuses
- `CheckDoubleAttack()` rolls against the double attack chance
- Triple attack: `CanCompanionTripleAttack()` — Warriors level 56+, Monks/Rangers level 60+
- Flurry: from spell/item bonuses only (no AAs)

**Dual wield eligibility** (`mob.cpp`): `CanThisClassDualWield()` for non-clients checks
`GetSkill(SkillDualWield) > 0`. NPC constructor sets `SkillDualWield = SkillDoubleAttack`
so all companions that can double attack can also dual wield. ✓

### Expected Authentic EQ Behavior

Players dual wield based on class having the skill. Rogues, monks, rangers, etc.
Double attack: class skill, checked against skill roll. Triple attack: warriors 56+,
monks/rangers 60+, by rule or skill.

### Gap Assessment: MATCH

Companions correctly implement dual wield, double attack, and triple attack. The
triple attack implementation in `Companion::DoAttackRounds()` correctly intercepts
before `NPC::Process()` so the companion's custom triple attack check fires.

---

## System 6: Critical Hits

### Current Companion Behavior

**`TryCriticalHit()`** (`attack.cpp:5419-5638`):

```cpp
// Pet-owner checks first
if ((IsPet() && GetOwner()->IsClient()) || (IsNPC() && CastToNPC()->GetSwarmOwner())) {
    TryPetCriticalHit(...); return;
}
if (IsPet() && GetOwner() && GetOwner()->IsBot()) {
    TryPetCriticalHit(...); return;
}
if (IsNPC() && !RuleB(Combat, NPCCanCrit)) {
    return; // NPCs don't crit if rule is off
}
```

**Companions return `IsNPC()=true`** and are NOT pets. Therefore:
- They do NOT go through `TryPetCriticalHit()`
- They ARE gated by `RuleB(Combat, NPCCanCrit)` default value
- If `NPCCanCrit` is true, they proceed to the full crit check

**Full crit check** (`attack.cpp:5500-5559`):
- `innate_crit = true` if: (Warrior or Berserker, level >= 12) OR (Ranger archery, level >= 12) OR (Rogue throwing, level >= 12)
- `crit_chance = GetCriticalChanceBonus(hit.skill)` (from bonuses)
- If `innate_crit || crit_chance`: rolls `zone->random.Int(1, MeleeCritDifficulty)`
- DEX bonus: if DEX > 255, reduced; +45 base boost
- If innate_crit: full DEX bonus; if not: DEX bonus * 3/5
- Crit modifier: 170 + `GetCritDmgMod()` (from bonuses)

**Key concern**: Companions ARE companions (custom type), NOT bots or clients. They
fall into the `IsNPC()` path and are subject to `NPCCanCrit` rule. If that rule is
false (which is the server default — `false`), companions CANNOT critical hit at all.

### Expected Authentic EQ Behavior

Warriors and Berserkers have innate crit at level 12+. Rogues crit with throwing at
level 12+. Rangers crit with archery at level 12+. All classes can get crit from
SPA 169 (CriticalHitChance) from items/spells/AAs.

### Gap Assessment: MAJOR DIVERGENCE

If `RuleB(Combat, NPCCanCrit)` is `false` (server default), **companions cannot
crit at all**. The code path goes: companion is NPC, not pet, `NPCCanCrit=false`
→ early return with no crit check. A warrior companion at level 60 will never crit
even though EQ warriors have innate crit. This is a significant authenticity gap.

**Fix needed**: Add `IsCompanion()` guard before the `NPCCanCrit` check, OR ensure
`NPCCanCrit` is set to `true` on this server (which would also affect all NPCs).
The cleanest fix is a guard in `TryCriticalHit()`:
```cpp
if (IsNPC() && !IsCompanion() && !RuleB(Combat, NPCCanCrit)) {
    return;
}
```

---

## System 7: Damage Bonus (STR-based)

### Current Companion Behavior

In `Companion::Attack()` (`companion.cpp:592-597`):
```cpp
if (Hand == EQ::invslot::slotPrimary && GetLevel() >= 28 && IsWarriorClass()) {
    int ucDamageBonus = static_cast<int>(GetWeaponDamageBonus(weapon));
    my_hit.min_damage = ucDamageBonus;
    hate += ucDamageBonus;
}
```

`IsWarriorClass()` includes Warriors, Paladins, Shadow Knights, Rangers, Monks, Rogues,
Bards, Berserkers, and Beastlords — the EQ "warrior archetype" classes. Level 28+
gate matches authentic EQ behavior.

In `Client::Attack()` (`attack.cpp:1687-1696`) — the comparison:
```cpp
if (Hand == EQ::invslot::slotPrimary && GetLevel() >= 28 && IsWarriorClass())
    ucDamageBonus = GetWeaponDamageBonus(weapon ? weapon->GetItem() : nullptr);
```

### Gap Assessment: MATCH

Companions correctly implement the damage bonus for warrior-class companions at level
28+ on primary hand hits. The formula (`GetWeaponDamageBonus`) is the shared mob method
and is identical to the client path.

---

## System 8: Weapon Skills

### Current Companion Behavior

Companions inherit skills from the NPC base class. The NPC constructor (`npc.cpp:382-393`)
sets skills at construction time:
- Level > 50: `SkillDoubleAttack = 250`, `SkillDualWield = 250`
- Level 4-50: `SkillDoubleAttack = level * 5`, `SkillDualWield = SkillDoubleAttack`
- Level <= 3: `SkillDoubleAttack = level * 5`

The `IsBot()` check at `npc.cpp:374` routes bots to a different path; companions
fall into the `else` branch and get the NPC skill values.

Weapon skills (1H slash, 2H blunt, etc.) are set from the `npc_types` `skills` field
or defaulted. Companions generally inherit whatever the recruited NPC had, which for
most NPCs is minimal. There is no mechanic to increase weapon skills over time.

`offense()` in `attack.cpp` for companions uses `IsNPC()` branch (level*5+50) rather
than skill-based offset — see System 4 above.

### Expected Authentic EQ Behavior

Players have class/level-based skill caps for every weapon type, with skills that
increase through use. For combat purposes, the skill feeds into `offense()`.

### Gap Assessment: MINOR DIVERGENCE

Companions don't increase weapon skills through combat, but since the `offense()`
function uses level-based formula for NPCs anyway, this doesn't affect hit chance.
Where weapon skills matter directly is for some specific checks (e.g., `SkillDefense`
for AC, `SkillMeditate` for mana regen) — but companion NPC constructors don't set
these, leaving them at 0 or whatever the recruited NPC had.

**Specific concern**: `SkillDefense` at 0 means the AC formula's `SkillDefense/3`
term contributes nothing. For a level 60 warrior with skill cap 255, this should add
255/3 = 85 AC. If NPC SkillDefense is 0, companion loses that AC. **This is a gap.**

Similarly, `SkillMeditate` affects mana regen. If 0, mana regen falls back to base.
The `CalcManaRegen()` formula uses `GetSkill(SkillMeditate)` at `companion.cpp:1172`.
If the companion's meditate skill is 0, regen = `(0 + (level - level/4)) / 4 + 4`.
At level 60: `(60 - 15) / 4 + 4 = 15`. With meditate 250: `(25 + 45) / 4 + 4 = 21.5`.
Not a huge difference, but still divergent.

---

## System 9: Parry, Riposte, Block, Dodge

### Current Companion Behavior

`CanThisClassParry()`, `CanThisClassRiposte()`, `CanThisClassBlock()`,
`CanThisClassDodge()` in `mob.cpp:4714-4748`:
- For non-clients: checks `GetSkill(SkillParry) > 0`, `GetSkill(SkillRiposte) > 0`, etc.
- These skills come from the NPC `skills[]` array
- NPC constructor does NOT set parry/riposte/dodge/block skills explicitly
- These are set from `npc_types` `skills` field (typically 0 for most NPCs)

**Companion parry/riposte/dodge/block skills are likely 0** unless the recruited NPC
has them explicitly set in the database.

`AvoidDamage()` (`attack.cpp:372-598`) checks:
- `CanThisClassRiposte()` — skill > 0 check
- `CanThisClassBlock()` — skill > 0 check
- `CanThisClassParry()` — skill > 0 check
- `CanThisClassDodge()` — skill > 0 check

If skills are 0, companions cannot parry, riposte, block, or dodge.

### Expected Authentic EQ Behavior

Players have class-appropriate defensive skills (warriors parry/riposte at high levels,
monks dodge extremely well, etc.) that increase through gameplay.

### Gap Assessment: MAJOR DIVERGENCE

Unless the recruited NPC's `npc_types` row has defensive skills set, companions will
not parry, riposte, block, or dodge at all. This is a significant defensive gap.
A level 60 warrior companion should be able to parry and riposte. A monk should
have strong dodge. Without these skills set in the database, companions take more
damage than they should.

**Mitigation**: The `npc_scale_manager` may set these skills for NPCs with appropriate
`npc_types` entries. But this is data-dependent — the data-expert needs to confirm.

---

## System 10: Fizzle Rate

### Current Companion Behavior

**`CheckFizzle()`** (`spells.cpp:1044-1047`):
```cpp
bool Mob::CheckFizzle(uint16 spell_id) {
    return(true);  // NPCs never fizzle
}
```

Only `Client::CheckFizzle()` (`spells.cpp:1049+`) implements actual fizzle logic.
Companions are not Clients, so `Mob::CheckFizzle()` is called → **companions never
fizzle**.

The mana deduction path at `spells.cpp:321-332`: if `!CheckFizzle()` is false, fizzle
occurs and 1/4 mana is consumed. Since `Mob::CheckFizzle()` always returns `true`
(no fizzle), companions always succeed the fizzle check.

### Expected Authentic EQ Behavior

Players fizzle based on casting skill vs spell difficulty, with prime stat (INT or WIS)
reducing fizzle chance. At low levels and with hard spells, fizzle is a meaningful
resource drain.

### Gap Assessment: COMPANION-FAVORABLE (intentional)

Companions never fizzle. This is the same behavior as all other NPCs (bots use a
special check, but standard mobs and mercs don't fizzle). This is probably intentional
for companion playability. Worth noting as a design decision.

---

## System 11: Mana Costs

### Current Companion Behavior

**Mana deduction** (`spells.cpp:421-437`):
```cpp
if (mana_cost > 0 && slot != CastingSlot::Item ||
    (IsBot() && !CastToBot()->IsBotNonSpellFighter())) {
    int my_curmana = GetMana();
    int my_maxmana = GetMaxMana();
    if (my_curmana < mana_cost) {
        if (IsNPC() && my_curmana == my_maxmana) {
            mana_cost = 0; // Special case: NPC at full mana casts free
        } else {
            DoSpellInterrupt(spell_id, mana_cost, my_curmana);
            return false;
        }
    }
}
```

Companions ARE NPCs, so if `current_mana == max_mana`, the first cast is free.
After that, they pay normal mana costs.

The companion AICastSpell (`companion_ai.cpp:392-396`) has its own OOM check:
```cpp
if (has_mana && GetManaRatio() < 10.0f) {
    return false; // don't cast below 10% mana
}
```

### Expected Authentic EQ Behavior

Players pay full mana costs. No free-first-cast behavior.

### Gap Assessment: MINOR DIVERGENCE

Companions may get a free cast when at full mana (NPC special case in spells.cpp:426).
In practice this is rarely relevant — companions are almost never at exactly max mana
when combat starts. The AICastSpell OOM bail at 10% is intentional design.

---

## System 12: Spell Resistances (companion AS TARGET)

### Current Companion Behavior

When companions are targeted by enemy spells, resistance checks go through
`Mob::ResistSpell()`. Companions have resist values from `npc_types` (MR, FR, DR, PR, CR),
scaled by `ScaleStatsToLevel()`, with **resist caps** enforced via `Companion::GetMR()` etc.

**Resist cap** (`companion.h:147-162`):
```cpp
inline int32 GetMR() const override {
    return std::min(MR + itembonuses.MR + spellbonuses.MR, GetMaxResist());
}
```
`GetMaxResist()` = `level * 5 + ResistCapBase` (default 50).
At level 60: cap = `60*5 + 50 = 350`. Player cap = 500.

Companions are intentionally capped at ~350 (70% of player cap) per the PRD.

### Gap Assessment: INTENTIONAL DIVERGENCE (design decision)

Companions have lower resist caps than players. This is a documented design decision
from the PRD. Not an authenticity gap per se — it's intentional tuning.

---

## System 13: Spell Targeting (companion AS TARGET — pcnpc_only_flag)

### Current Companion Behavior

In `SpellFinished()` / `SpellOnTarget()` (`spells.cpp:831-844`):
```cpp
if (spells[spell_id].pcnpc_only_flag == PCNPCOnlyFlagType::PC
    && !spell_target->IsClient()
    && !spell_target->IsMerc()
    && !spell_target->IsBot()) {
    // "This spell only works on other PCs"
    return false;
}
```

**Companions are NOT listed here.** `IsCompanion()` is NOT in the check.
This means: **PC-only spells cannot be cast on companions.** A player trying to
buff a companion with a spell that has `pcnpc_only_flag = 1` (PC only) will get
"This spell only works on other PCs." Bots and mercs are explicitly exempted but
companions are not.

Also at `spells.cpp:3935-3945` (the AE radius path) and `spells.cpp:6999/7094`
(AE range paths) — same missing `IsCompanion()` check.

### Expected Authentic EQ Behavior

Player buffs should work on companions (they are the player's ally).

### Gap Assessment: SIGNIFICANT GAP

PC-only spells cannot target companions. This includes common buffs. Bots and mercs
are explicitly handled but companions were not added. This affects every spell with
`pcnpc_only_flag = 1` (PC-only) trying to target a companion. Fix needed:
add `|| spell_target->IsCompanion()` to all three `pcnpc_only_flag` checks in
`spells.cpp`.

---

## System 14: Spell Damage (companion AS CASTER)

### Current Companion Behavior

Companions call `CastSpell()` via `AIDoSpellCast()` (`companion.cpp:1923`).
Spell damage follows the standard `SpellEffect()` / `SpellEffect_Nuke()` path.
No special branching for companion-cast spells.

`GetFocusEffect()` is **overridden** in Companion (`companion.cpp:987-991`):
```cpp
int64 Companion::GetFocusEffect(focusType type, uint16 spell_id, Mob* caster, bool from_buff_tic) {
    return Mob::GetFocusEffect(type, spell_id, caster, from_buff_tic);
}
```
This bypasses `NPC::GetFocusEffect()` which has two problems:
1. Gates item focus behind `RuleB(Spells, NPC_UseFocusFromItems)` (default false)
2. Reads from `NPC::equipment[]` not `GetInv()` — wrong for companions

Using `Mob::GetFocusEffect()` means companions correctly apply focus effects from
equipped items (e.g., spell damage focus from a Cloak of Flames).

### Gap Assessment: MATCH

Companion spell damage correctly applies focus effects from equipment. Spell damage
values themselves are from the spell database and are identical to what players or
NPCs cast. No companion-specific spell damage modification.

---

## System 15: HP Regen

### Current Companion Behavior

**NPC::Process()** regen block (`npc.cpp:648-696`):
```cpp
int64 npc_hp_regen = GetNPCHPRegen();
npc_sitting_regen_bonus = (sitting) ? 3 : 0;
ooc_regen_calc = ooc_regen > 0 ? GetMaxHP() * ooc_regen / 100 : 0;
npc_regen = max(npc_hp_regen, ooc_regen_calc);
if (HP < MaxHP && !IsPet()) {
    if (!IsEngaged()) SetHP(HP + npc_regen + 3);
    else SetHP(HP + npc_hp_regen);
}
```

Companion sets:
- `hp_regen = CalcHPRegen()` in `AI_Start()` — uses `max(native_hp_regen, HPRegenPerTic rule floor)`
- `ooc_regen = RuleI(Companions, OOCRegenPct)` in `AI_Start()`

**Sitting bonus** (`companion.cpp:1827-1842`):
Companion::Process() adds extra sitting HP regen on a 6-second `m_sitting_regen_timer`
gated by `SittingRegenMult` rule. Without this gate, the bonus fires every Process()
tick (~6x per regen period), causing massive overregen.

**In-combat regen**: `npc_hp_regen` rate (which was seeded from `CalcHPRegen()`)
**Out-of-combat regen**: `max(npc_hp_regen, ooc_regen_calc)` where `ooc_regen_calc =
MaxHP * OOCRegenPct / 100`

### Expected Authentic EQ Behavior

Players regenerate HP based on class, level, and base stats (STA-based formula). Out
of combat, much faster. Sitting gives minor bonus (3/tick in standard mechanic).
Certain classes (Warrior) have higher natural regen.

### Gap Assessment: REASONABLE DIVERGENCE

Companions don't use the player HP regen formula (which is stat/level/class based).
Instead they use a simpler OOC percentage + sitting multiplier. This is functionally
serviceable. The sitting-bonus timer fix (Issue #1) correctly prevents overregen.

---

## System 16: Mana Regen

### Current Companion Behavior

**NPC::Process()** mana regen block (`npc.cpp:692-710`):
```cpp
if (GetMana() < GetMaxMana()) {
    if (IsCompanion()) {
        int64 companion_mana_regen = CastToCompanion()->CalcManaRegen();
        SetMana(min(GetMana() + companion_mana_regen, GetMaxMana()));
    }
    ...
}
```

**`CalcManaRegen()`** (`companion.cpp:1148-1184`):
- Non-mana classes (no max_mana): return 0
- Bards: sit=2, stand=1 + itembonuses + aabonuses
- Other casters: if `AlwaysMeditateRegen || IsSitting()`:
  - Uses meditate formula: `((meditate/10 + (level - level/4)) / 4) + 4`
- Standing non-meditate: flat base 2
- Adds `spellbonuses.ManaRegen + itembonuses.ManaRegen + aabonuses.ManaRegen`
- Applies `Character:ManaRegenMultiplier` then `Companions:CompanionManaRegenMult`
- `AlwaysMeditateRegen` rule (default `true`): companions always get meditate rate
  regardless of sitting — intentional design for small-group playability

**NOTE**: This is explicitly documented as a **KNOWN EXCEPTION**. Companions use
meditate-rate regen always (when AlwaysMeditateRegen=true). This was a deliberate
design decision to prevent mana starvation in single-player use.

### Gap Assessment: INTENTIONAL DIVERGENCE (documented)

The always-meditate regen is a deliberate design decision. When `AlwaysMeditateRegen=false`,
authentic behavior is restored (must sit to get meditate rate). The rule exists to
let server operators choose. No fix needed.

---

## System 17: Haste and Attack Speed

### Current Companion Behavior

`Companion::SetAttackTimer()` (`companion.cpp:670-777`) — weapon-delay path:
```cpp
float haste_mod = std::max(0.01f, GetHaste() * 0.01f);
delay = 100 * ItemToUse->Delay;  // weapon delay in hundredths
speed = static_cast<int>(delay / haste_mod);
// Apply HundredHands effect
// Clamp to RuleI(Combat, MinHastedDelay)
TimerToUse->SetAtTrigger(max(MinHastedDelay, speed), ...);
```

`GetHaste()` is the shared Mob method that combines:
- `itembonuses.haste` (item haste)
- `spellbonuses.haste` (spell haste, overcap variant)
- `aabonuses.haste` (AA haste — always 0 for companions)

HHE (HundredHands effect) is also applied, respecting the `Jun182014HundredHandsRevamp` rule.

When `UseWeaponDamage=false` (fallback): delegates to `NPC::SetAttackTimer()` which
uses `npc_types.attack_delay`. No haste applied.

### Expected Authentic EQ Behavior

Players: `attack_timer = weapon_delay * 100 / haste_mod` with HHE correction and
`MinHastedDelay` cap.

### Gap Assessment: MATCH (weapon-damage path)

The weapon-damage path correctly mirrors `Client::SetAttackTimer()`. Haste from
items and spells applies correctly. The fallback NPC path (no weapon equipped)
uses NPC attack delay without haste — acceptable for unarmed companions.

---

## System 18: ACSoftcap (AC scaling)

The `GetACSoftcap()` and `GetSoftcapReturns()` in `attack.cpp:647-810` use
class-based lookup tables with 105 entries (levels 1-105).

`IsOfClientBot()` returns true for companions, so the softcap path is taken.
The class-based lookup uses `GetClass()` which returns the companion's actual class.
This is **correct** — companions get per-class AC softcaps and diminishing returns
just like players.

### Gap Assessment: MATCH

---

## Summary Table

| System | Assessment | Notes |
|--------|-----------|-------|
| Base Stats | Minor Divergence | Linear scaling vs player stat tables; functionally acceptable |
| MaxHP | Match | Correct STA-to-HP conversion for item/spell bonus STA |
| MaxMana | Match | Correct level-scaled mana via override; INT/WIS formula correct |
| AC / Defense | Match | Correct skill divisors, shield-from-inventory, class AC softcaps |
| Hit Chance | Match | Same `CheckHitChance()` for all mob types |
| Offense | Minor Divergence | NPC level-based formula vs player skill-based; converge at high levels |
| Damage Bonus | Match | Warrior class damage bonus at level 28+ correctly implemented |
| Dual Wield | Match | Weapon delay, haste, DW eligibility all correct |
| Double Attack | Match | Correct double attack with skill check |
| Triple Attack | Match | Custom `CanCompanionTripleAttack()` for Warriors/Monks/Rangers |
| **Critical Hits** | **MAJOR GAP** | Companions blocked by `NPCCanCrit` rule (default false); no innate crits |
| Weapon Skills | Minor Divergence | Parry/riposte/dodge/block skills likely 0; data-dependent |
| **Defensive Skills** | **MAJOR GAP** | SkillDefense=0 → no AC from Defense skill; SkillParry=0 → no parry |
| Fizzle Rate | Companion-Favorable | Never fizzle (all NPCs); intentional |
| Mana Costs | Minor Divergence | Free-cast at full mana (NPC special case); rarely relevant |
| **PC-only Spell Targeting** | **SIGNIFICANT GAP** | Companions missing from pcnpc_only_flag PC check; can't receive PC-only buffs |
| Spell Damage / Focus | Match | Focus effects via Mob::GetFocusEffect() override correctly bypass NPC gate |
| HP Regen | Reasonable Divergence | OOC% regen + sitting mult; intentional |
| Mana Regen | Intentional Divergence | AlwaysMeditateRegen=true default; documented known exception |
| Haste | Match | Client-style haste calculation in weapon-delay path |
| AC Softcap | Match | Class-based softcaps and diminishing returns correctly applied |
| Resist Caps | Intentional Divergence | Capped at level*5+50 (≈70% of player cap); PRD design decision |

---

## Critical Issues Requiring Fixes

### Critical Issue 1: Companions Cannot Critical Hit
**Location:** `eqemu/zone/attack.cpp:5446-5448`
**Problem:** `TryCriticalHit()` has an early return for `IsNPC() && !RuleB(Combat, NPCCanCrit)`.
Companions return `IsNPC()=true`. If `NPCCanCrit=false` (default), companions cannot crit.
Warriors, Berserkers at level 12+ should have innate crit. Crit gear/spells should work.
**Fix:** Add `&& !IsCompanion()` guard at `attack.cpp:5446`.

### Critical Issue 2: PC-Only Spells Cannot Target Companions
**Location:** `eqemu/zone/spells.cpp:832` (and 3940, 6999, 7094)
**Problem:** `pcnpc_only_flag == PCNPCOnlyFlagType::PC` check excludes companions.
Players cannot buff companions with PC-targeted spells. Bots and mercs are explicitly
included but companions are not.
**Fix:** Add `|| spell_target->IsCompanion()` to all `pcnpc_only_flag` PC checks.

### Significant Issue 3: Missing Defensive Skills (SkillDefense, SkillParry, etc.)
**Location:** NPC constructor `npc.cpp` — skills not set for companions
**Problem:** If recruited NPC's `npc_types` doesn't have Defense/Parry/Riposte/Dodge/Block
skills set, companions have 0 for these skills. A level 60 warrior loses:
- ~85 AC from Defense skill (255/3)
- All parry/riposte/dodge/block chances
**Fix:** Companion constructor or `Spawn()` should set class-appropriate skill values,
OR the data-expert needs to ensure `npc_types` rows for companion NPCs have correct
skill values. The former is more reliable.

---

## Code References

| File | Line(s) | Topic |
|------|---------|-------|
| `eqemu/zone/companion.cpp` | 85-101 | Constructor: base stat storage from NPCType |
| `eqemu/zone/companion.cpp` | 312-343 | `ScaleStatsToLevel()` — float linear scaling |
| `eqemu/zone/companion.cpp` | 345-371 | `ApplyStatScalePct()` — global stat multiplier |
| `eqemu/zone/companion.cpp` | 466-664 | `Companion::Attack()` — weapon-damage path |
| `eqemu/zone/companion.cpp` | 549-597 | Damage bonus and weapon damage calculation |
| `eqemu/zone/companion.cpp` | 670-777 | `SetAttackTimer()` — weapon delay / haste |
| `eqemu/zone/companion.cpp` | 808-868 | `CalcMaxHP()` — STA-to-HP conversion |
| `eqemu/zone/companion.cpp` | 892-942 | `CalcMaxMana()` — level-scaled mana override |
| `eqemu/zone/companion.cpp` | 960-967 | `GetMaxResist()` — resist cap formula |
| `eqemu/zone/companion.cpp` | 987-991 | `GetFocusEffect()` — bypasses NPC gate |
| `eqemu/zone/companion.cpp` | 1001-1071 | Triple attack eligibility and roll |
| `eqemu/zone/companion.cpp` | 1078-1123 | `DoAttackRounds()` — multi-attack sequence |
| `eqemu/zone/companion.cpp` | 1129-1141 | `CalcHPRegen()` — HP regen rate |
| `eqemu/zone/companion.cpp` | 1148-1184 | `CalcManaRegen()` — meditate formula |
| `eqemu/zone/companion.cpp` | 1519-1850 | `Process()` — sit/stand, attack intercept, regen |
| `eqemu/zone/attack.cpp` | 900-976 | `ACSum()` — companion gets player divisors |
| `eqemu/zone/attack.cpp` | 647-734 | `GetACSoftcap()` — class-based AC caps |
| `eqemu/zone/attack.cpp` | 153-165 | `offense()` — NPC uses level*5+50 |
| `eqemu/zone/attack.cpp` | 5436-5448 | `TryCriticalHit()` — NPCCanCrit gate |
| `eqemu/zone/mob.cpp` | 989-995 | `Mob::CalcMaxHP()` — base formula |
| `eqemu/zone/mob.cpp` | 972-987 | `Mob::CalcMaxMana()` — base formula |
| `eqemu/zone/mob.cpp` | 4684-4748 | `CanThisClassDoubleAttack/Parry/Riposte/etc.` |
| `eqemu/zone/npc.cpp` | 382-393 | NPC constructor skill initialization |
| `eqemu/zone/npc.cpp` | 648-710 | NPC::Process() regen block |
| `eqemu/zone/npc.cpp` | 2720-2751 | `NPC::CalcMaxMana()` |
| `eqemu/zone/spells.cpp` | 1044-1047 | `Mob::CheckFizzle()` — always true |
| `eqemu/zone/spells.cpp` | 421-433 | Mana deduction; NPC free-cast at full mana |
| `eqemu/zone/spells.cpp` | 831-844 | pcnpc_only_flag — missing IsCompanion() |
| `eqemu/zone/companion_ai.cpp` | 287-347 | `LoadCompanionSpells()` — from companion_spell_sets |
| `eqemu/zone/companion_ai.cpp` | 358-396 | `AICastSpell()` entry point |
