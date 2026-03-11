# Architect Research Notes — npc-companion-realistic-stats

## Key Findings from Source Code Analysis

### 1. Companion Skills Are Already Correct

NPCs (and companions) get skills from `SkillCaps::Instance()->GetSkillCap()` in
the NPC constructor at `npc.cpp:368-369`. This means companions already have:
- Class-appropriate dodge, parry, riposte, defense, offense skills
- Double attack and dual wield skills (overridden at npc.cpp:382-393)

The mechanics reference flagged "skills may be low/missing" but this is NOT the
case. Skills are properly initialized from the skill_caps system.

### 2. Mob::Attack() Is the Client/Bot Path

`Mob::Attack()` at attack.cpp:1566 is used by both Clients and Bots. It:
- Reads weapon from `GetInv().GetItem()` (inventory profile)
- Uses `GetWeaponDamage(other, weapon_inst, &hate)` for base damage
- Applies `GetWeaponDamageBonus()` at level 28+ for warrior classes
- Calls shared functions: `DoAttack()`, `CheckHitChance()`, `MeleeMitigation()`

Bots do NOT have their own Attack() override — they use `Mob::Attack()`.

### 3. NPC::Attack() Is a Separate Code Path

`NPC::Attack()` at attack.cpp:2202 is a completely separate function, NOT a
call to `Mob::Attack()`. It:
- Reads weapon from `database.GetItem(equipment[slot])` (raw ID lookup)
- Uses `GetBaseDamage()` + `GetMinDamage()` for damage (npc_types values)
- Does NOT call `GetWeaponDamageBonus()`
- Does NOT call `DoDamageCaps()`

### 4. SetAttackTimer Is Virtual

Both `Client::SetAttackTimer()` and `NPC::SetAttackTimer()` exist as separate
implementations. The method is virtual (declared in mob.h). Companion can
override it.

### 5. Inventory Profile Is Functional

Companions use `GetInv().PutItem()` in `GiveItem()` to populate their inventory
profile. `CalcItemBonuses()` reads from this profile. The inventory profile is
the same mechanism bots use. `GetInv().GetItem(slot)` returns ItemInstance* which
has `GetItem()` returning `EQ::ItemData*` with Damage and Delay fields.

### 6. Double Attack Path

`DoMainHandAttackRounds()` at attack.cpp:6938 has two paths:
- `UseLiveCombatRounds=true`: Single Attack + CheckDoubleAttack() (skill-based)
- `UseLiveCombatRounds=false`: NPC path with GetNumberOfAttacks()

If the server uses UseLiveCombatRounds=true, companions already get proper
skill-based double attack. This needs verification during implementation.

### 7. GetWeaponDamageBonus Function

At attack.cpp:3451. Takes `const EQ::ItemData*` and returns uint8 damage bonus
based on weapon delay. Available to all Mob descendants. The key requirement is
`IsWarriorClass()` and level >= 28.

### 8. AttackAnimation Has Multiple Overloads

From mob.h search, AttackAnimation takes either:
- `(int Hand, const EQ::ItemInstance* weapon)` — Client path
- `(int Hand, const EQ::ItemInstance* weapon, EQ::skills::SkillType skill)` — NPC path

The Companion should use the first overload (Client style) since it has
ItemInstance objects.

## Files Examined

| File | Lines Read | Purpose |
|------|-----------|---------|
| zone/companion.h | Full | Class declaration, virtual overrides |
| zone/companion.cpp | 1-600 | Constructor, Attack, CalcHPRegen, CalcManaRegen, AI_Start |
| zone/companion_ai.cpp | 1-300 | Spell AI architecture |
| zone/attack.cpp:1566-1765 | Mob::Attack (Client/Bot path) |
| zone/attack.cpp:2202-2433 | NPC::Attack |
| zone/attack.cpp:6682-6827 | Client/NPC SetAttackTimer |
| zone/attack.cpp:6938-7020 | DoMainHandAttackRounds / DoOffHandAttackRounds |
| zone/attack.cpp:250-370 | compute_defense, GetTotalDefense |
| zone/attack.cpp:372-520 | AvoidDamage |
| zone/attack.cpp:3451-3480 | GetWeaponDamageBonus |
| zone/bonuses.cpp:50-65 | NPC::CalcBonuses |
| zone/npc.h:306-307 | GetBaseDamage, GetMinDamage |
| zone/npc.cpp:360-395 | NPC skill initialization |
| common/ruletypes.h:1181-1214 | Companions rule category |
