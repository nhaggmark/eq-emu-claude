# BUG-035: Companions attack friendly pets (charmed, summoned, companion pets)

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-03-19
> **Feature:** companion-bug-batch-3
> **Status:** Open

---

## Observed Behavior

NPC companions attack pets that belong to the player or group members. Two
confirmed scenarios:

1. **Charmed pets:** After combat ends, companions attack the player's charmed
   pet (e.g., Enchanter charm pet in Lower Guk).
2. **Companion NPC pets:** When a recruited NPC companion is a Necro, other
   companions in the group attack the Necro companion's summoned pet.

## Expected Behavior

Companions should never attack any pet belonging to:
- Their owner (the player)
- Any group member
- Any other companion in the group
- Any pet of any of the above

This applies to ALL pet types: charmed, summoned, temporary, beastlord
warders, and pets belonging to NPC companions.

## Reproduction Steps

1. Recruit an NPC companion (any melee class)
2. As an Enchanter, charm an NPC in Lower Guk
3. Engage another mob in combat with the group
4. After combat ends, observe the companion turning to attack the charmed pet
5. Alternatively: recruit a Necro NPC companion, let it summon a pet, and
   observe other companions attacking the Necro's pet

## Evidence

Exploration agent investigation (2026-03-19) identified five gaps in the
companion targeting logic:

1. **Charm-break doesn't clear companion hate lists** (`spell_effects.cpp:4488`)
   - `ReplaceWithTarget()` / `WipeHateList()` don't notify companions
2. **Companion assist logic has no pet filters** (`companion.cpp:1920-1970`)
   - Scans check `IsNPC()` and `IsCompanion()` but never `IsPet()` or `IsCharmed()`
3. **IsAttackAllowed checks owner, not pet status** (`aggro.cpp:732-960`)
   - Substitutes owner for faction but never blocks based on pet TYPE
4. **Safety checks don't cover pets** (`companion.cpp:1975-2025`)
   - Checks "is target the owner / a companion / a group member" but not
     "is target a PET of those entities"
5. **Hate list accepts any entity** (`hate_list.cpp:206-255`)
   - No pet-type filtering before adding to hate list

## Affected Systems

- [x] C++ server source -> c-expert
- [ ] Lua quest scripts -> lua-expert
- [ ] Perl quest scripts -> perl-expert
- [ ] Database / SQL -> data-expert
- [ ] Rules / Configuration -> config-expert
- [ ] Client protocol -> protocol-agent
- [ ] Infrastructure / Docker -> infra-expert

## Test Coverage Requirements

The user explicitly requested **complete test coverage**. The test suite must
cover ALL of the following scenarios:

### Pet Type Coverage
- Charmed pets (Enchanter charm)
- Summoned pets (Magician, Necromancer)
- Beastlord warders
- Temporary/swarm pets
- Pets belonging to NPC companions (e.g., Necro companion's pet)

### Ownership Coverage
- Player's own pet
- Group member's pet
- Companion's pet (companion-owned pets)
- Pet of a pet's owner (transitive ownership)

### Scenario Coverage
- During combat: companion should not add friendly pets to hate list
- After combat ends: companion should not switch to friendly pet as target
- Charm break: companion should clear charmed mob from hate list when charm breaks
- Charm active: companion should never target an actively charmed pet
- New pet summoned mid-combat: companion should recognize new friendly pet
- Pet attacking same target: companion should not retaliate against friendly pet
- Assist logic (BALANCED stance): pet filtering when scanning nearby mobs
- Assist logic (AGGRESSIVE stance): pet filtering in vicinity scan
- Owner target assist: safety check should include pets of friendly entities
- IsAttackAllowed: should return false for all friendly pet types
- Hate list: should refuse to add friendly pets

### Edge Cases
- Charm breaks mid-combat (pet becomes hostile NPC again — companion SHOULD attack)
- Pet dies and is re-summoned during combat
- Multiple companions each with their own pets
- Charmed pet that is also on another mob's hate list
