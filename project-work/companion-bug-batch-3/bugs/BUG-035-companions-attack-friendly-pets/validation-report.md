# BUG-035 Validation Report: Companions Attack Friendly Pets

> **Validator:** game-tester
> **Date:** 2026-03-19
> **Feature branch:** `bugfix/companion-bug-batch-3`
> **Server-side result:** PASS

---

## Summary

BUG-035 has been implemented and all server-side automated checks pass. The fix
introduces a centralized `Companion::IsFriendlyTarget()` helper method integrated
at three defense layers: assist logic scan filters (Layer 1), `IsAttackAllowed()`
override (Layer 2), and the `Attack()` safety net (Layer 3). 32 automated tests
in Suite 34 all pass with zero failures and zero skips. The build is clean.

In-game testing by the user is required before closing this bug.

---

## Part 1: Server-Side Validation Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Build verification | PASS | `ninja: no work to do.` — clean build, no compile errors |
| 2 | Automated test suite: Suite 34 (32 tests) | PASS | 32/32 PASSED, 0 FAILED, 0 SKIPPED |
| 3 | Full regression: all suites (1-34) | PASS | 562 total PASSED, 0 FAILED, 0 SKIPPED |
| 4 | Zone log errors | PASS | No errors related to companion/pet/IsFriendlyTarget in zone_dynamic_01.log |
| 5 | World log errors | PASS | No errors in world.log |
| 6 | Database integrity | N/A | No DB changes in this fix |
| 7 | Quest script syntax | N/A | No Lua/Perl script changes |
| 8 | Rule validation | N/A | No new rules added |
| 9 | Spawn verification | N/A | No spawn table changes |
| 10 | Loot chain validation | N/A | No loot table changes |

### Build Verification

```
docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
ninja: no work to do.
```

Result: PASS. Build is clean and current.

### Automated Test Run

Command used:
```
docker exec akk-stack-eqemu-server-1 bash -c "cd ~/server && ~/code/build/bin/zone tests:companion"
```

Suite 34 output (all 32 tests):
```
--- Suite 34: BUG-035 — Companions Don't Attack Friendly Pets ---
[PASS] BUG-035 > 34.1  IsFriendlyTarget(nullptr) == false
[PASS] BUG-035 > 34.2  IsFriendlyTarget(self) == true
[PASS] BUG-035 > 34.3  IsFriendlyTarget(same-owner companion) == true
[PASS] BUG-035 > 34.4  IsFriendlyTarget(different-owner companion) == false
[PASS] BUG-035 > 34.5  IsFriendlyTarget(same-owner companion's pet) == true
[PASS] BUG-035 > 34.6  IsFriendlyTarget(wild NPC, no owner) == false
[PASS] BUG-035 > 34.7  IsFriendlyTarget(own pet) == true (necro's own pet)
[PASS] BUG-035 > 34.8  IsFriendlyTarget(different-owner companion's pet) == false
[PASS] BUG-035 > 34.9  IsFriendlyTarget(charmed pet of same-owner companion) == true
[PASS] BUG-035 > 34.10 IsFriendlyTarget(charmed pet, different owner) == false
[PASS] BUG-035 > 34.11 IsFriendlyTarget after charm break (ownerid=0) == false
[PASS] BUG-035 > 34.12 IsFriendlyTarget(PetType::None, no owner) == false
[PASS] BUG-035 > 34.13 IsAttackAllowed(same-owner companion's pet) == false
[PASS] BUG-035 > 34.14 IsAttackAllowed(same-owner companion) == false
[PASS] BUG-035 > 34.15 IsFriendlyTarget(wild NPC) == false (pre-condition for attack allowed)
[PASS] BUG-035 > 34.16 IsAttackAllowed(different-owner companion) not blocked by IsFriendlyTarget
[PASS] BUG-035 > 34.17 Verify necro_pet was added to warrior hate list
[PASS] BUG-035 > 34.18 Attack(friendly pet) returns false (safety net fires)
[PASS] BUG-035 > 34.19 After Attack() rejection, warrior target is nullptr
[PASS] BUG-035 > 34.20 Attack(self) returns false
[PASS] BUG-035 > 34.21 Attack(same-owner companion) returns false
[PASS] BUG-035 > 34.22 After Attack(companion) rejection, warrior target is nullptr
[PASS] BUG-035 > 34.23 IsFriendlyTarget(swarm pet of companion's pet) == true
[PASS] BUG-035 > 34.24 IsAttackAllowed(swarm pet) == false
[PASS] BUG-035 > 34.25 IsFriendlyTarget(other-owner companion's pet) == false
[PASS] BUG-035 > 34.26 other_companion IsFriendlyTarget(own pet) == true
[PASS] BUG-035 > 34.27 warrior IsFriendlyTarget(necro companion's pet) == true
[PASS] BUG-035 > 34.28 IsFriendlyTarget(former pet, ownerid=0) == false (attack allowed)
[PASS] BUG-035 > 34.29 IsFriendlyTarget gating: false for former-charmed NPC (can attack)
[PASS] BUG-035 > 34.30 Wild NPC still IsFriendlyTarget == false (no regression)
[PASS] BUG-035 > 34.31 IsFriendlyTarget(different-owner companion) == false (no regression)
[PASS] BUG-035 > 34.32 IsFriendlyTarget(pet with non-existent owner) == false (no crash)
--- Suite 34 Complete ---
```

Full run totals: **562 PASSED, 0 FAILED, 0 SKIPPED** across all 34 suites.

### Log Analysis

No errors, crashes, or warnings related to companion, pet, or friendly target logic
were found in `zone_dynamic_01.log` or `world.log` after the fix was deployed.
The zone log shows normal companion spawn/depop lifecycle messages only.

---

## Test Coverage Gap Analysis

The bug report specifies complete test coverage requirements. This section maps each
requirement to the automated tests and identifies what remains for in-game validation.

### Pet Type Coverage

| Pet Type | Requirement | Automated Coverage | Status |
|----------|-------------|-------------------|--------|
| Charmed pets (Enchanter charm) | IsFriendlyTarget returns true while charmed, false after charm breaks | 34.9 (charmed active), 34.11 (charm break), 34.28-29 (break regression) | COVERED |
| Summoned pets (Mage/Necro) | IsFriendlyTarget returns true for Normal pet type | 34.5, 34.7, 34.13, 34.27 | COVERED |
| Beastlord warders | Same as summoned — warders use PetType::Normal (no separate Warder constant in engine) | 34.5, 34.7 (PetType::Normal path is identical) | COVERED by proxy |
| Temporary/swarm pets | Transitive ownership chain recognized | 34.23-24 | COVERED |
| Companion's own pets | Companion sees its own pet as friendly | 34.7, 34.13, 34.26 | COVERED |

Note on Beastlord warders: The EQEmu engine has no separate `PetType::Warder` constant.
Beastlord warders are created with `PetType::Normal`, identical to Mage/Necro summoned
pets. The test coverage for `PetType::Normal` fully covers the warder case.

### Ownership Coverage

| Ownership Scenario | Requirement | Automated Coverage | Status |
|-------------------|-------------|-------------------|--------|
| Player's own pet | IsFriendlyTarget returns true | Not directly testable without a live Client; owner lookup returns nullptr in test env. Layer 1/2/3 checks against companion's group and owner-chain still cover this transitively. | IN-GAME TEST REQUIRED |
| Group member's pet | IsFriendlyTarget uses GetGroup() / IsGroupMember() | Not tested with actual group member in Suite 34 — no group integration in this suite. | IN-GAME TEST REQUIRED |
| Companion's pet | Full coverage | 34.5, 34.7, 34.8, 34.13, 34.24-27 | COVERED |
| Transitive (pet-of-pet) | GetUltimateOwner() chain traced up to 3 hops | 34.23-24 (swarm pet → companion's pet → companion) | COVERED |

### Scenario Coverage

| Scenario | Requirement | Automated Coverage | Status |
|----------|-------------|-------------------|--------|
| During combat: no hate list add | Assist logic filters skip friendly pets | IsFriendlyTarget unit tests confirm the gate function is correct. Direct assist-scan invocation not tested — this is an integration path requiring a live zone. | IN-GAME TEST REQUIRED |
| After combat ends: no target switch | Companion does not pick pet as new target | 34.17-19 (Attack safety net fires, target cleared) confirms the escape hatch. Full "end of combat + pet selection" path requires in-game. | IN-GAME TEST REQUIRED |
| Charm break: companion clears charmed mob | ownerid=0 makes formerly-charmed NPC attackable | 34.11, 34.28, 34.29 | COVERED |
| Charm active: never target charmed pet | IsFriendlyTarget true while charmed | 34.9-10 | COVERED |
| New pet summoned mid-combat | New pet immediately recognized as friendly | Architecture handles this: IsFriendlyTarget is called live every tick; new pets with correct ownerid are protected immediately. No dedicated test for "during-fight summon". | IN-GAME TEST REQUIRED |
| Pet attacking same target: no retaliation | Companion does not add pet to hate list when pet attacks same mob | Not tested. This scenario (pet hits same mob companion is hitting) could trigger assist logic. | IN-GAME TEST REQUIRED |
| BALANCED stance: pet filtering in scan | IsFriendlyTarget blocks friendly pets from BALANCED assist scan | 34.1-12 validate the gate function; actual BALANCED-scan integration path not exercised. | IN-GAME TEST REQUIRED |
| AGGRESSIVE stance: pet filtering in scan | Same as BALANCED | Same as above. | IN-GAME TEST REQUIRED |
| Owner target assist: pet safety check | Owner target assist respects IsFriendlyTarget | 34.13-16 confirm IsAttackAllowed integration. | COVERED (via Layer 2) |
| IsAttackAllowed: false for friendly pets | Layer 2 blocks all attack paths | 34.13, 34.14, 34.24 | COVERED |
| Hate list: refuses friendly pets | Layer 1 prevents addition; Layer 3 scrubs if added | 34.17-19 (safety net), 34.1-12 (gate correctness) | COVERED |

### Edge Cases

| Edge Case | Requirement | Automated Coverage | Status |
|-----------|-------------|-------------------|--------|
| Charm breaks mid-combat (pet becomes hostile) | Companion SHOULD attack post-break | 34.11, 34.28-29 | COVERED |
| Pet dies and is re-summoned | New pet with ownerid set is immediately protected | Not tested. Architecture is sound (live lookup), but re-summon mid-fight not validated. | IN-GAME TEST REQUIRED |
| Multiple companions each with pets | Cross-companion pet isolation works | 34.25-27 (warrior 999 vs other_companion 888) | COVERED |
| Charmed pet on another mob's hate list | AoE/proc assist doesn't make companion target it | Not tested in automation; requires live zone with real hate list interactions. | IN-GAME TEST REQUIRED |

### Gap Summary

The automated test suite covers all the **correctness properties** of `IsFriendlyTarget()`,
`IsAttackAllowed()`, and the `Attack()` safety net. The gaps that remain are all
**integration scenarios** requiring a live zone with real Client entities and real
combat AI ticks. These cannot be replicated in the CLI test environment because:

1. The CLI test framework has no live Client — owner checks that resolve via
   `GetCompanionOwner()` → live Client cannot be fully tested.
2. The BALANCED and AGGRESSIVE assist scan loops run only inside `Companion::Process()`,
   which is not invoked by CLI tests.
3. The "new pet mid-combat" scenario requires the game loop ticking between pet summon
   and the companion's next AI tick.

These gaps are normal for a CLI test suite and are covered by the in-game tests below.

---

## Part 2: In-Game Testing Guide

Run these tests in-game with the Titanium client. All tests require a GM-level character.

### Prerequisites

- Level 45+ character (Enchanter or any class that can recruit companions)
- Active feature branch deployed on server
- At least 2-3 companion slots available
- Recommend testing in a zone with low ambient mob density (North Qeynos, West Commonlands, or Lavastorm)

**Setup commands:**
```
#level 50
#zone commons
#reloadquests
```

---

### Test I1: Summoned pet not attacked by companion (core scenario)

**Tests:** Summoned pets, companion's pet, during combat, after combat

**Prerequisite:** Recruit a Necromancer companion. Recruit a Warrior companion.
The Necro companion must have a summoned pet (it will cast one automatically
after entering combat).

**Steps:**
1. Zone to West Commonlands (`#zone commons`)
2. Recruit a Necromancer NPC companion (`!recruit <necro name>`)
3. Recruit a Warrior NPC companion (`!recruit <warrior name>`)
4. Engage a nearby mob in combat — let the Necro summon its pet
5. Watch the Warrior companion during combat — it should be attacking the hostile
   mob, NOT the Necro's pet
6. After the mob dies, watch for 30 seconds
   - The Warrior should go idle or return to following
   - The Warrior should NOT turn to attack the Necro's pet

**Pass if:** The Warrior companion never attacks the Necro companion's pet during or after combat.
**Fail if:** The Warrior companion's target switches to the Necro's pet, or you see the Warrior
taking swings at the pet (watch for MISS messages, pet HP dropping).

**GM commands for setup:**
```
#findnpc warrior
#findnpc necro
!recruit [npc name]
```

---

### Test I2: Charmed pet not attacked during combat

**Tests:** Charmed pets, Enchanter charm, during combat, new pet mid-combat

**Prerequisite:** Character is an Enchanter (or use a test character with charm spell).
Recruit 1-2 melee companions (Warrior, Monk, etc.).

**Steps:**
1. Zone to a dungeon with many mobs (Blackburrow, Crushbone, or use `#zone guk_old`)
2. Recruit a Warrior companion (`!recruit <warrior name>`)
3. Charm a nearby NPC using Enchant: Animal or a charm spell
4. The charmed mob is now your pet — verify it shows in your pet window
5. Engage a DIFFERENT hostile mob while keeping the charmed pet active
6. Watch the Warrior companion — it should fight only the hostile mob
7. The Warrior must NOT attack the charmed pet

**Pass if:** Warrior ignores the charmed pet and attacks only the engaged hostile mob.
**Fail if:** Warrior swings at or targets the charmed pet.

**GM commands for setup:**
```
#zone guk_old
#summonitem 1263   (Bard's Lute — can trade to companion to test)
#spawn [npcid]     (spawn a specific NPC to charm)
```

---

### Test I3: Charm break — companion resumes attacking former pet

**Tests:** Charm break mid-combat, formerly charmed NPC becomes hostile again

**Prerequisite:** Same as Test I2 (Enchanter + Warrior companion).

**Steps:**
1. Charm an NPC (same as Test I2 steps 1-4)
2. Engage a hostile mob with the group while charm is active
3. Allow charm to break naturally (or cast a spell to force break)
   - You will see the message "Your charm spell has worn off"
   - The formerly-charmed NPC is now hostile
4. Watch the Warrior companion immediately after charm breaks

**Pass if:** After charm breaks, the Warrior companion treats the formerly-charmed NPC as
a hostile enemy and attacks it (or engages it if it attacks the group).
**Fail if:** After charm breaks, the Warrior companion ignores the now-hostile NPC (over-protection)
or was already attacking it before charm broke (should not have happened — caught by Test I2).

---

### Test I4: Group member's player pet not attacked

**Tests:** Group member's pet, player-summoned pet, player's own pet

**Prerequisite:** Two accounts or second character in group. One character should be a
Magician or Necromancer. Recruit a Warrior companion for one of the players.

**Steps:**
1. Form a group between two characters
2. Character A: Warrior companion recruited
3. Character B: Summon a pet (Magician earth pet or Necromancer bone-walker)
4. Engage a hostile mob as a group
5. Watch the Warrior companion — it should attack only the hostile mob

**If you cannot test with two accounts:**
- Use your own character as a Magician/Necromancer
- Summon your own pet
- Recruit a Warrior companion
- Engage combat and verify Warrior does not attack your own pet

**Pass if:** The Warrior companion never attacks the group member's (or player's own) summoned pet.
**Fail if:** The Warrior companion targets or attacks any friendly player-owned pet.

**GM commands:**
```
#level 50
#reloadquests
!recruit [warrior name]
```

---

### Test I5: Pet summoned mid-combat is immediately recognized as friendly

**Tests:** New pet summoned mid-combat

**Prerequisite:** Necromancer companion that can summon pets, plus a Warrior companion.

**Steps:**
1. Engage a hostile mob with companions
2. During the fight, the Necro companion will summon its pet (first summon takes a few
   combat rounds)
3. From the moment the Necro's pet appears, the Warrior should not target it

**Note:** The Warrior may briefly "notice" the new entity appearing. The key test is
whether it adds the pet to its hate list and attacks.

**Pass if:** The Warrior never attacks the Necro's pet even as it appears mid-combat.
**Fail if:** The Warrior briefly attacks the newly-summoned pet before switching back.

---

### Test I6: Multiple companions with pets — no cross-companion pet aggro

**Tests:** Multiple companions each with pets, multi-companion pet isolation

**Prerequisite:** Recruit a Necromancer companion and a Magician companion (or two
NPC companions that summon pets). Also recruit a Warrior companion.

**Steps:**
1. Recruit Necro companion, Mage companion, and Warrior companion
2. Engage hostile mobs repeatedly until both the Necro and Mage have active pets
3. Watch the Warrior throughout — it should never attack either caster's pet
4. Watch the Necro companion — it should never attack the Mage's pet
5. Watch the Mage companion — it should never attack the Necro's pet

**Pass if:** No companion attacks any other companion's pet at any time.
**Fail if:** Any companion attacks any other companion's pet.

---

### Test I7: Pet attacking same target does not trigger companion retaliation

**Tests:** Pet attacking same target, no friendly fire

**Prerequisite:** Any companion + a player pet (Mage/Necro character).

**Steps:**
1. Summon your own pet
2. Recruit a Warrior companion
3. Engage a hostile mob
4. Your pet and the Warrior will both be attacking the same mob
5. Observe carefully — the Warrior should never switch to target your pet

**Pass if:** Warrior remains focused on the hostile mob even while your pet also attacks it.
**Fail if:** Warrior targets your pet because your pet is also engaged in combat.

---

### Test I8: BALANCED stance assist — friendly pet not added to hate list

**Tests:** BALANCED stance assist scan pet filtering

**Prerequisite:** Warrior companion in BALANCED stance (default), player pet active.

**Steps:**
1. Set companion to BALANCED stance: `!stance balanced`
2. Summon your player pet
3. Allow the companion to idle near your pet
4. Engage a hostile mob (let the companion auto-assist)
5. After combat, verify the companion does NOT linger on your pet

**Note:** BALANCED stance assists the owner's target. The companion should assist
you against the hostile mob and ignore your pet.

**Pass if:** Companion assists against the hostile mob only.
**Fail if:** Companion adds player pet to hate list or attacks it.

---

### Test I9: AGGRESSIVE stance assist — friendly pet not added to hate list

**Tests:** AGGRESSIVE stance assist scan pet filtering

**Prerequisite:** Warrior companion in AGGRESSIVE stance, player pet active nearby
hostile mobs.

**Steps:**
1. Set companion to AGGRESSIVE stance: `!stance aggressive`
2. Summon your player pet
3. Position near a hostile NPC
4. Watch the companion's vicinity scan — it should engage the hostile NPC, not your pet

**Pass if:** Companion attacks the hostile NPC and ignores your pet.
**Fail if:** Companion attacks your pet because it is a nearby "NPC".

---

### Edge Case Test IE1: Charmed pet that is on another mob's hate list

**Tests:** Charmed pet on another mob's hate list — companion should not add pet to hate list

**Prerequisite:** Enchanter character, Warrior companion.

**Steps:**
1. Charm an NPC
2. Let the charmed NPC take some damage from a wandering hostile mob
   (the charmed NPC will be on that mob's hate list)
3. The charmed NPC is still YOUR pet
4. Engage a different hostile mob with your companion
5. Verify the Warrior companion does not attack your charmed pet even though it is
   involved in nearby combat

**Pass if:** Warrior ignores charmed pet regardless of that pet's own combat state.
**Fail if:** Warrior attacks the charmed pet because it detected combat near the pet.

---

### Rollback Instructions

This fix is purely C++ server code with no database changes. If something goes wrong:

```bash
# Check out previous commit on the eqemu repo
cd /mnt/d/Dev/eq/eqemu
git log --oneline -5
git checkout HEAD~1 -- zone/companion.cpp zone/companion.h zone/cli/tests/cli_companion_tests.cpp

# Rebuild
docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"

# Restart zone processes (see MEMORY.md for full startup procedure)
```

No database rollback needed. No quest script rollback needed.

---

## Blockers

None. Server-side validation is PASS. In-game testing can proceed.

---

## Recommendations

1. **Test I3 (charm break) is the highest-priority in-game test.** The charm-break
   scenario was the primary bug report trigger, and the automated tests only verify
   the structural correctness (ownerid=0 returns false). The full behavioral path —
   companion had the charmed pet on its hate list, charm breaks, companion correctly
   transitions to attacking it — requires a live zone to verify.

2. **Test I4 (group member's pet) fills the most significant gap** not covered by
   automation. The CLI tests cannot instantiate a real Client, so group-member pet
   ownership via `GetGroup()` + `IsGroupMember()` was verified structurally but not
   with a real player-owned pet.

3. **Companion AI tick timing:** After charm breaks, there is one AI tick before the
   companion re-evaluates its target. If the companion's hate list already contained
   the charmed pet (which should not happen with the fix, but verify), the safety net
   in `Attack()` fires and clears it on the next attack attempt. This should be
   transparent to the user in practice.
