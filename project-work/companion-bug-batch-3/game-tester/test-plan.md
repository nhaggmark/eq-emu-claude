# Companion Bug Batch 3 — Test Plan

> **Feature branch:** `bugfix/companion-bug-batch-3`
> **Author:** game-tester
> **Date:** 2026-03-19
> **Server-side result:** PASS

---

## Test Summary

This test plan covers four bugs in the companion system batch:
- BUG-032: Damage shields trigger INVULNERABLE on companions (C++ fix: strip melee immunity special abilities)
- BUG-033: Charm Go Away button broken (C++ fix: restructure PET_GETLOST case)
- BUG-034: Companion mana regen too slow (C++ fix: confirm formula + multiplier)
- BUG-035: Companions attack friendly pets (C++ fix: IsFriendlyTarget() defense-in-depth)

All fixes are pure C++ in the `zone/` directory. No database, Lua, Perl, or protocol changes.

### Inputs Reviewed

- [x] Architecture plan at `bugs/BUG-035-companions-attack-friendly-pets/architecture.md`
- [x] Bug reports at `bugs/BUG-032*/report.md`, `bugs/BUG-033*/report.md`, `bugs/BUG-034*/report.md`, `bugs/BUG-035*/report.md`
- [x] status.md — implementation tasks 1-4 Complete
- [x] Acceptance criteria identified: 4 bugs × multiple criteria each

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Build verification | PASS | `ninja: no work to do.` — clean build |
| 2 | BUG-035 automated tests: Suite 34 (32 tests) | PASS | 32/32 PASSED, 0 FAILED, 0 SKIPPED |
| 3 | Full regression: Suites 1-34 (562 tests) | PASS | 562 PASSED, 0 FAILED, 0 SKIPPED |
| 4 | Zone log errors | PASS | No errors in zone_dynamic_01.log |
| 5 | World log errors | PASS | No errors in world.log |
| 6 | Database integrity | N/A | No DB changes in this batch |
| 7 | Quest script syntax | N/A | No Lua/Perl changes |
| 8 | Rule validation | N/A | No new rules added |
| 9 | Spawn/loot chain | N/A | No spawn or loot table changes |

### Database Integrity

No database changes were made by any of the four bugs. No integrity checks needed.

### Quest Script Syntax

No Lua or Perl scripts were modified. No syntax checks needed.

### Log Analysis

| Log File | Errors Found | Notes |
|----------|-------------|-------|
| `zone_dynamic_01.log` | 0 | Normal companion spawn/depop lifecycle messages only |
| `world.log` | 0 | Clean |

### Rule Validation

No new rules were added. No validation needed.

### Spawn Verification

No spawn table changes. No verification needed.

### Loot Chain Validation

No loot table changes. No verification needed.

### Build Verification

- **Build command:** `docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
- **Result:** PASS
- **Output:** `ninja: no work to do.`

---

## Part 2: In-Game Testing Guide

### Prerequisites

- Level 50+ character recommended
- GM access for teleport and spawn commands
- Access to test zone with mobs (West Commonlands, North Qeynos, or a dungeon)
- For BUG-035 tests: character class that can charm (Enchanter) or companions that summon pets

**Quick GM setup:**
```
#level 50
#zone commons
#reloadquests
```

---

### Test 1: BUG-032 — Damage shields no longer trigger INVULNERABLE

**Acceptance criterion:** A companion that is struck by a damage shield (reflected damage)
does not enter the INVULNERABLE state. The companion should continue taking damage normally
and not become immune to all further hits.

**Prerequisite:** Active melee companion. Need to fight a mob that has a damage shield buff
(or cast Damage Shield on a test mob). Damage shields are common on Velious raid mobs and
can be applied via `#castspell`.

**Steps:**
1. Recruit a Warrior or Monk companion (`!recruit <name>`)
2. Find a mob that has a damage shield, or use `#castspell 2541` on a nearby mob to apply
   one (Damage Shield spell)
3. Engage the mob with your companion in melee
4. Watch the combat log for `INVULNERABLE` messages when the companion strikes the mob
5. Continue combat through several rounds

**Pass if:** The companion takes damage normally from the mob's counterattacks. No
`INVULNERABLE` message appears when the companion strikes the shielded mob.

**Fail if:** The companion shows `INVULNERABLE` in the combat log when striking a
damage-shielded mob, or the companion stops taking damage entirely after the first strike.

**GM commands for setup:**
```
!recruit [warrior name]
#castspell 2541   (apply Damage Shield to target mob)
```

---

### Test 2: BUG-033 — Charm Go Away button works correctly

**Acceptance criterion:** When an Enchanter player right-clicks a charmed NPC and selects
"Go Away", the charmed NPC is released and becomes a wild mob again. It should not remain
as a charmed pet after the Go Away command.

**Prerequisite:** Enchanter character with a charm spell. Recruit no companions for this
test (the bug affects the charm release mechanism, not companion interaction).

**Steps:**
1. Find a charmable NPC (any animal or appropriate NPC for your charm spell)
2. Cast your charm spell to charm the NPC
3. Verify the NPC appears in your pet window as a charmed pet
4. Right-click the charmed NPC in your pet window
5. Select "Go Away" from the pet command menu
6. The charmed NPC should be released and become hostile (or wander off)

**Pass if:** The charmed NPC is released after clicking Go Away. It either wanders off
(if it does not re-aggro) or turns hostile. The NPC is removed from your pet window.

**Fail if:** The Go Away button does nothing. The NPC remains charmed after clicking
Go Away. The NPC disappears entirely (depops) instead of being released.

**GM commands for setup:**
```
#zone commons
#spawn [npcid]   (spawn a charmable NPC if needed)
```

---

### Test 3: BUG-034 — Companion mana regen at expected rate

**Acceptance criterion:** A caster companion (Wizard, Necromancer, Enchanter, etc.)
regenerates mana at a reasonable rate — fast enough that it can cast multiple spells per
combat encounter and be ready for the next fight within 30-60 seconds out of combat.

**Prerequisite:** Recruit a caster companion (Wizard or Cleric recommended). Need a way
to deplete the companion's mana (multiple combat encounters).

**Steps:**
1. Recruit a caster companion (`!recruit <wizard name>`)
2. Check initial mana: target the companion, check its mana bar
3. Engage 3-4 hostile mobs back-to-back to deplete the companion's mana
4. After combat ends, watch the companion's mana bar over the next 60 seconds
5. The mana bar should visibly increase. At rule value of 175% regen multiplier, a
   level 45 caster should recover roughly 25-35 mana per tick (6 seconds)

**Pass if:** The caster companion's mana bar increases steadily out of combat. After
60 seconds, it should have recovered at least 20-30% of missing mana.

**Fail if:** The mana bar does not move or moves so slowly that recovery would take
many minutes for a full bar.

**GM commands for setup:**
```
!recruit [caster name]
#showstats     (show companion stats including mana)
```

---

### Test 4: BUG-035 — Companions do not attack friendly pets (core scenarios)

See the full validation report at:
`claude/project-work/companion-bug-batch-3/bugs/BUG-035-companions-attack-friendly-pets/validation-report.md`

The in-game tests for BUG-035 are detailed there (Tests I1 through I9 plus edge case IE1).
Summary of required in-game tests:

**BUG-035 Test I1: Necro companion's summoned pet not attacked by Warrior companion**

**Steps:**
1. Recruit a Warrior companion and a Necromancer companion
2. Engage hostile mobs — let the Necro summon its pet during combat
3. Watch the Warrior: it must NOT attack the Necro's pet

**Pass if:** Warrior never targets or strikes the Necro's pet.
**Fail if:** Warrior attacks or targets the Necro's pet.

---

**BUG-035 Test I2: Charmed pet not attacked during combat**

**Steps:**
1. Enchanter: charm a nearby NPC
2. Recruit a Warrior companion
3. Engage a DIFFERENT hostile mob while charmed pet is active
4. Watch the Warrior: it must NOT attack the charmed pet

**Pass if:** Warrior attacks only the hostile mob, ignores charmed pet.
**Fail if:** Warrior attacks or targets the charmed pet.

---

**BUG-035 Test I3: After charm breaks — companion correctly attacks former pet**

**Steps:**
1. Repeat setup from I2 (charmed pet, Warrior companion)
2. Allow charm to expire naturally
3. Watch the Warrior's behavior after charm breaks

**Pass if:** Warrior treats the now-hostile NPC as a valid attack target.
**Fail if:** Warrior refuses to attack the former charmed NPC (over-protection regression).

---

**BUG-035 Test I4: Player's own summoned pet not attacked**

**Steps:**
1. Play as Mage/Necro (or use a test character), summon your pet
2. Recruit a Warrior companion
3. Engage hostile mobs

**Pass if:** Warrior never attacks your summoned pet.
**Fail if:** Warrior attacks your pet.

---

**BUG-035 Test I5: Multiple companions with multiple pets — no cross-pet aggro**

**Steps:**
1. Recruit Necro companion + Mage companion + Warrior companion
2. Fight mobs until Necro and Mage both have active pets
3. Watch all companions: none should attack any companion's pet

**Pass if:** No companion attacks any other companion's pet.
**Fail if:** Any companion attacks any other companion's pet.

---

### Edge Case Tests

### Test E1: BALANCED vs AGGRESSIVE stance — pet filtering works in both

**Risk from architecture plan:** The BALANCED and AGGRESSIVE assist scans both had the
same pet-filter gap. Both were fixed with the same `IsFriendlyTarget()` check, but
both must be tested.

**Steps:**
1. Set companion to BALANCED stance (`!stance balanced`), summon your pet, engage combat.
   Verify companion does not attack pet.
2. Set companion to AGGRESSIVE stance (`!stance aggressive`), repeat.

**Pass if:** Companion ignores your pet in both stances.
**Fail if:** Companion attacks your pet in either stance.

---

### Test E2: New pet summoned mid-combat is recognized immediately

**Risk from architecture plan:** IsFriendlyTarget() is called live every tick, so new
pets should be protected immediately. But this needs real-time verification.

**Steps:**
1. Enter combat with a Warrior companion (no Necro pet yet)
2. Mid-fight, summon or recruit a Necro companion that immediately summons a pet
3. Verify the Warrior does not attack the newly-appeared pet

**Pass if:** Warrior ignores the new pet from the moment it appears.
**Fail if:** Warrior briefly attacks the new pet before recognizing it as friendly.

---

## Rollback Instructions

All four bug fixes are C++ only. No database or config changes.

```bash
# To roll back all BUG-035 changes:
cd /mnt/d/Dev/eq/eqemu
git log --oneline -5    # find the commit before BUG-035 changes
git checkout <pre-bug035-commit> -- zone/companion.cpp zone/companion.h
git checkout <pre-bug035-commit> -- zone/cli/tests/cli_companion_tests.cpp

# Rebuild
docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
```

No database rollback needed. No quest script rollback needed.

---

## Blockers

None. All server-side checks pass.

---

## Recommendations

1. BUG-035 Test I3 (charm break) is the highest priority in-game test — it was the
   primary reported scenario and the automated tests only cover the structural
   property, not the live AI behavior.

2. BUG-035 Test I4 (player's own summoned pet) fills the biggest automation gap —
   no live Client was available in the CLI test environment.

3. BUG-032 may require a specific mob type or buff to reproduce. If you cannot find a
   damage-shielded mob naturally, use `#castspell` to apply one to a test target.

4. After in-game tests pass, mark the Validation phase Complete in status.md and
   proceed to the completion phase (commit + push all repos).
