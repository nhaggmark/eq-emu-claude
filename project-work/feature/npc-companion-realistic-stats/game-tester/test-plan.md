# npc-companion-realistic-stats — Test Plan

> **Feature branch:** `feature/npc-companion-realistic-stats`
> **Author:** game-tester
> **Date:** 2026-03-11
> **Server-side result:** PASS

---

## Test Summary

This test plan validates all five implementation phases of the companion realistic
stats feature, plus the eight audit fixes applied after Phases 1-4 code review. The
feature makes companions behave like properly-equipped characters: weapons drive
damage and speed, skills drive avoidance, STA drives HP, and spell AI uses tuned
thresholds. All changes are companion-only — regular NPCs, bots, and mercs are
unaffected.

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Dev notes at `c-expert/dev-notes.md`
- [x] Audit fix plan at `architect/context/audit-fix-plan.md`
- [x] Phase 5 plan at `architect/context/phase5-plan.md`
- [x] Balance tuning doc at `architect/context/balance-tuning.md`
- [x] status.md — all implementation tasks Complete (Phase 5 tasks 8-14 complete
  as verified by build + test run)
- [x] Acceptance criteria identified: 28 criteria across 5 phases

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Build verification | PASS | `ninja: no work to do.` — binary is current, 0 errors |
| 2 | Test suite: all 15 suites | PASS | 242 PASSED, 2 expected SKIPs, 0 FAILED |
| 3 | Test suite: Suite 14 (audit fixes) | PASS | All 27 audit fix tests pass |
| 4 | Test suite: Suite 15 (Phase 5) | PASS | All 27 Phase 5 tests pass |
| 5 | DB: companion_spell_sets orphans | PASS | 0 orphaned spell_id references |
| 6 | DB: Cannibalize spells in companion_spell_sets | PASS | All 4 tiers present for class 10 |
| 7 | DB: ResistCapBase rule in rule_values | PASS | Value=50, ruleset_id=1 |
| 8 | DB: New C++ rules present in ruletypes.h | PASS | STAToHPFactor, SittingRegenMult, HealThresholdPct, ManaCutoffPct, HealerManaConservePct, ResistCapBase all present at correct defaults |
| 9 | Log analysis: zone logs for companion errors | PASS | No ERROR/CRASH entries in zone_dynamic_*.log; companion spawn/depop messages are Info-level and expected |
| 10 | Quest script syntax | PASS (N/A) | No Lua/Perl scripts modified — feature is C++ only |
| 11 | Spawn verification | PASS (N/A) | No spawns added or modified |
| 12 | Loot chain validation | PASS (N/A) | No loot tables modified |

### Database Integrity

#### Companion spell sets — orphan check

```sql
SELECT COUNT(*) as orphaned_count
FROM companion_spell_sets css
LEFT JOIN spells_new sn ON sn.id = css.spell_id
WHERE sn.id IS NULL;
```

**Result:** `orphaned_count = 0` — all spell references are valid.

#### Cannibalize spell data verification

```sql
SELECT css.spell_id, css.class_id, css.min_level, css.max_level, css.spell_type, sn.name
FROM companion_spell_sets css
JOIN spells_new sn ON sn.id = css.spell_id
WHERE css.class_id = 10
  AND sn.name LIKE '%Cannibalize%'
ORDER BY css.min_level;
```

**Result:**

| spell_id | class_id | min_level | max_level | spell_type | name |
|----------|----------|-----------|-----------|------------|------|
| 265 | 10 | 23 | 37 | 2 | Cannibalize |
| 754 | 10 | 38 | 53 | 2 | Cannibalize II |
| 1572 | 10 | 54 | 57 | 2 | Cannibalize III |
| 1332 | 10 | 58 | 65 | 2 | Cannibalize IV |

All four tiers present with correct class and level ranges.

#### ResistCapBase rule

```sql
SELECT rule_name, rule_value FROM rule_values
WHERE rule_name = 'Companions:ResistCapBase';
```

**Result:** `Companions:ResistCapBase = 50` — correct.

### Quest Script Syntax

No Lua or Perl quest scripts were modified. This feature is C++ only. Check passes
by absence.

### Log Analysis

Zone logs checked: `zone_dynamic_01.log` through `zone_dynamic_08.log` (2026-03-11).

**No ERROR-level entries related to companions.** Info-level messages confirm normal
companion spawn/despawn/group-join behavior functioning correctly. Example of expected
normal log output:

```
Zone | Info | LoadCompanionSpells Companion [Lydl the Great] (class 12 level 20) loaded [10] spells
Zone | Info | CompanionJoinClientGroup Companion joined new group with [Chelon]
Zone | Info | Spawn Companion::Spawn: spawned for owner [Chelon] (entity id: 429)
```

Depop messages (`NPC::Process() returned false`) are expected behavior when companions
zone out with the owner and are not errors.

### Rule Validation

Rules confirmed present in `eqemu/common/ruletypes.h` (verified in codebase):

| Rule | Category | Default | Confirmed In DB | Notes |
|------|----------|---------|----------------|-------|
| STAToHPFactor | Companions | 100 | In-code default | STA-to-HP multiplier |
| SittingRegenMult | Companions | 200 | In-code default | 2x OOC regen when sitting |
| HealThresholdPct | Companions | 80 | In-code default | Healer begins healing at 80% HP |
| ManaCutoffPct | Companions | 20 | In-code default | DPS casters stop nuking at 20% mana |
| HealerManaConservePct | Companions | 30 | In-code default | Efficient heal below 30% mana |
| ResistCapBase | Companions | 50 | **In rule_values** | 350 cap at level 60 (50+60*5) |
| UseWeaponDamage | Companions | true | In-code default | Phase 1 master toggle |

Note: STAToHPFactor through HealerManaConservePct exist in `ruletypes.h` with correct
defaults and are confirmed at runtime by the test suite (all Suite 13/14/15 checks pass),
but were not inserted into the `rule_values` table as database rows. The engine reads
defaults from `ruletypes.h` when a row is absent, so these rules are functionally correct.
Only `ResistCapBase` was explicitly inserted by data-expert. This is consistent with how
the companion system's other rules (OOCRegenPct, StatScalePct, etc.) are handled.

### Build Verification

- **Build command:** `docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
- **Result:** PASS — `ninja: no work to do.` (binary is up to date, no compile errors)

### Test Suite Results

```
Total tests: 244 ran
  PASSED:  242
  FAILED:  0
  SKIPPED: 2 (both expected)
```

Expected SKIPs:
- `ScaleStatsToLevel test (Recruited level is 0 or already at 55+)` — NPC source is level 55, test skipped by design
- `Monk below 60 test (NPC found is level 60+ — cannot test below-threshold monk)` — DB has no monk NPC below 60 for the test harness to use

Both SKIPs are known and documented. They are not failures.

---

## Part 2: In-Game Testing Guide

### Prerequisites

All tests assume a GM-level character with access to GM commands. Have the companion
system active (companions can be recruited). The easiest testing approach is to have
a selection of companion NPCs already available in the zone.

**Useful item IDs from the database:**

| Item | ID | Dmg | Delay | Notes |
|------|----|-----|-------|-------|
| Rusty Longsword | 11604 | 5 | 35 | Slow weapon for Phase 1 baseline |
| Fine Steel Long Sword | 5350 | 6 | 28 | Mid-tier 1H sword |
| Blackened Alloy Longsword | 3617 | 10 | 29 | Good 1H sword |
| Rusty Dagger | 7007 | 3 | 24 | Fast off-hand weapon |
| Fine Steel Dagger | 7350 | 3 | 19 | Fast off-hand dagger |
| Intricate Adept's Sphere | 50417 | — | — | +23 STA ring (reqlevel 48) |
| Ornate Adept's Sphere | 50376 | — | — | +20 STA ring (reqlevel 26) |
| Ward's Ring of Fealty | 83150 | — | — | +25 MR/FR/CR resist ring |
| Circle of Smoke | 30534 | — | — | +25 MR, +15 FR/CR/DR/PR |

**Standard GM command shortcuts:**
```
#level 60              — set to level 60 for testing
#zone [zone]           — zone to a specific zone
#reloadquests          — hot-reload quest scripts if needed
#reloadrules           — reload rule values after any #rules set changes
#spawn [npcid]         — spawn an NPC at your location for recruiting
#showstats             — inspect your targeted companion's stats
```

---

### Test 1: Weapon Damage Drives Melee Hits

**Acceptance criterion:** A companion equipped with a weapon deals melee damage
derived from that weapon's damage stat, not from npc_types.max_dmg.

**Prerequisite:** Recruit a warrior or rogue companion at level 40+. Have a Rusty
Longsword (item 11604, Dmg 5) and a Blackened Alloy Longsword (item 3617, Dmg 10)
available.

**Steps:**
1. Recruit a warrior-class companion (any warrior or paladin NPC).
2. Use `!equip primary [id]` with item 11604 (Rusty Longsword) to give the companion
   the weaker weapon. Confirm with `!equipment` or `#showstats`.
3. Engage a level-appropriate mob and watch the companion's melee combat messages in
   the chat log. Note the range of damage numbers (should be in the range of 5-20 per
   hit for a Rusty Longsword on an equal-level mob).
4. Now use `!equip primary [id]` with item 3617 (Blackened Alloy Longsword, Dmg 10).
5. Engage another mob of similar level/type and compare damage numbers.

**Expected result:** With the Blackened Alloy Longsword, individual hit values are
noticeably higher than with the Rusty Longsword — roughly double on average, consistent
with Dmg 10 vs Dmg 5.

**Pass if:** Individual hit values are clearly higher with the stronger weapon. The
companion is NOT dealing 50-150+ damage per hit on every swing with the Rusty Longsword
(which would indicate npc_types fallback is still active).

**Fail if:** Both weapons produce identical damage ranges, or the companion deals its
full npc_types.max_dmg damage regardless of equipped weapon.

**GM commands for setup:**
```
#summonitem 11604      — summon Rusty Longsword
#summonitem 3617       — summon Blackened Alloy Longsword
```

---

### Test 2: Weapon Delay Drives Attack Speed

**Acceptance criterion:** A companion equipped with a faster weapon attacks more
frequently.

**Prerequisite:** Warrior companion. Have a Rusty Longsword (delay 35) and a Fine
Steel Dagger (item 7350, delay 19) available.

**Steps:**
1. Equip the warrior companion with the Rusty Longsword (delay 35).
2. Engage a mob that the companion can fight without dying. Count how many times the
   companion attacks in 30 seconds of combat (count "[Companion name] hits" messages).
3. Dismiss and re-recruit (or use a fresh companion). Equip the Fine Steel Dagger (delay 19).
4. Engage a similar mob. Count attacks in 30 seconds.

**Expected result:** The dagger-wielding companion attacks noticeably more frequently —
roughly 1.5-1.8x more often than with the longsword (35/19 ratio ≈ 1.84).

**Pass if:** Attack frequency is visibly higher with the faster weapon. The combat log
shows more "[companion] hits" messages per unit time.

**Fail if:** Attack rate is identical between weapons, or the companion attacks at
a fixed NPC attack_delay rate regardless of weapon.

**GM commands for setup:**
```
#summonitem 7350       — summon Fine Steel Dagger
```

---

### Test 3: Unarmed/No Weapon Fallback

**Acceptance criterion:** A companion with no weapon equipped deals damage using
npc_types values (regression protection for monks).

**Prerequisite:** Any monk companion, or any companion with weapons removed.

**Steps:**
1. Recruit a monk companion. Do NOT give them any weapons.
2. Use `!equipment` to confirm primary and secondary slots are empty.
3. Engage a mob. Observe damage numbers in the combat log.
4. Optionally, use `#showstats` to view the companion's stats and confirm base damage.

**Expected result:** The monk attacks using its NPC fist damage values. It does not
deal 0 damage or behave broken. Damage should be consistent with the NPC's level
and database max_dmg value.

**Pass if:** The monk (unarmed) hits for nonzero damage appropriate to its level and NPC
base values.

**Fail if:** Monk deals 0 damage, crashes, or deals dramatically wrong damage.

---

### Test 4: Dual Wield — Off-Hand Weapon Used

**Acceptance criterion:** A dual-wielding companion uses the appropriate weapon
damage for each hand.

**Prerequisite:** Warrior or rogue companion with dual wield capability. Equip a
Fine Steel Long Sword (primary, Dmg 6) and a Fine Steel Dagger (secondary, Dmg 3).

**Steps:**
1. Equip the warrior companion: primary = Fine Steel Long Sword, secondary = Fine Steel Dagger.
2. Engage a mob and watch combat messages. You should see both "[companion] hits [mob]"
   (primary) and "[companion] hits [mob]" secondary attack messages.
3. Note that primary hits (from the longsword) are slightly larger than secondary hits
   (from the dagger) on average.

**Expected result:** Companion makes both main-hand and off-hand attacks. Off-hand hits
exist and reflect the dagger's damage range, not the longsword's.

**Pass if:** Two-weapon attacks appear in the combat log. Primary hits are generally
larger than off-hand hits.

**Fail if:** No off-hand attacks occur, or all attacks use only one weapon's damage.

**GM commands for setup:**
```
#summonitem 5350       — summon Fine Steel Long Sword
#summonitem 7350       — summon Fine Steel Dagger
```

---

### Test 5: Triple Attack (Warrior Level 56+)

**Acceptance criterion:** Level 56+ warriors land triple attacks.

**Prerequisite:** Warrior companion at level 56 or higher. Engage a mob and watch
the combat log for a period of at least 2 minutes.

**Steps:**
1. Recruit a warrior companion at level 56+. If your recruited warrior is below 56,
   try a different NPC source that is higher level.
2. Enter combat against a durable mob (one that will not die in a few seconds).
3. Watch the combat log carefully. Look for a turn where the companion attacks three
   times in the same combat round — three "[companion name] hits" messages in rapid
   succession.
4. Observe over 2-3 minutes of sustained combat.

**Expected result:** Occasional triple attack rounds appear, where the warrior lands
three hits in a single combat round. This should happen roughly every 20-40 attacks
at level 60 (depending on triple attack skill).

**Pass if:** At least one triple attack occurs during a 2-3 minute combat session.

**Fail if:** No triple attacks occur after extended observation, or the server crashes
or errors.

**Note:** Triple attack is probabilistic. If it does not trigger in one fight, try
again. A level 60 warrior companion should demonstrate triple attacks within 5 minutes
of sustained combat.

---

### Test 6: Monk Triple Attack (Level 60)

**Acceptance criterion:** Level 60+ monks land triple attacks.

**Prerequisite:** Monk companion at level 60.

**Steps:**
1. Recruit a level 60 monk companion.
2. Engage a durable mob without giving the monk any weapons (monks fight unarmed).
3. Watch for triple attack rounds in the combat log over 2-3 minutes.

**Pass if:** Triple attacks appear in the log during sustained combat.

**Fail if:** No triple attacks occur after extended observation.

---

### Test 7: Warrior Avoidance (Parry, Riposte, Dodge)

**Acceptance criterion:** A warrior companion has high parry, riposte, and dodge
skill values at level-appropriate rates.

**Prerequisite:** Level 50+ warrior companion. You need a mob that will attack the
companion (so the companion takes incoming hits and can attempt avoidance).

**Steps:**
1. Recruit a level 50+ warrior companion.
2. Use `!stats` to check the companion's defense-related stats. You should see
   defense, parry, riposte, and dodge skill values listed.
3. Engage a mob that will hit the companion. Watch the combat log for avoidance messages:
   "[Companion name] parries a hit from [mob]"
   "[Companion name] dodges a hit from [mob]"
   "[Companion name] ripostes [mob]" (riposte causes the companion to counterattack)
4. Over a 2-3 minute fight, parry, dodge, and riposte should each occur multiple times.

**Expected result:** Avoidance is frequent and visible. A level 50 warrior companion
should parry or dodge roughly 1 in 5-10 incoming attacks.

**Pass if:** Parry, dodge, and/or riposte messages appear regularly in combat.

**Fail if:** The companion never avoids a single hit despite being attacked repeatedly
(possible if all skills are at zero — the pre-fix behavior).

---

### Test 8: Caster Companion — Low Avoidance

**Acceptance criterion:** A caster companion has minimal defensive combat skills.

**Prerequisite:** Level 50+ cleric or wizard companion.

**Steps:**
1. Recruit a level 50+ cleric companion.
2. Use `!stats` to view the companion's parry, riposte, and block skills.
3. Engage a mob that will attack the cleric (put the cleric in melee range).
4. Observe the combat log for avoidance messages over 1-2 minutes.

**Expected result:** The cleric rarely or never parries/ripostes/dodges. `!stats`
should show parry and riposte at 0 (clerics do not have these skills). Dodge should
be very low (under 50) even at level 60.

**Pass if:** Cleric demonstrates essentially no combat avoidance (avoidance messages
are rare or absent).

**Fail if:** Cleric parries and dodges as frequently as a warrior companion.

---

### Test 9: Damage Bonus (Level 28+ Melee Companions)

**Acceptance criterion:** Level 28+ melee companions deal a damage bonus consistent
with the weapon delay bonus table.

**Prerequisite:** A level 35+ warrior companion with a weapon equipped.

**Steps:**
1. Recruit a level 35 warrior companion (if your source NPCs are level 35+).
2. Equip a Rusty Longsword (delay 35 — slow weapon, gets larger damage bonus).
3. Engage a mob and observe maximum hit values in the combat log.

**Expected result:** Hit values exceed the weapon's raw damage value by a consistent
flat bonus. At level 35 with a delay-35 weapon, the bonus is a few extra points per
hit (exact value depends on the standard EQ damage bonus table). Hits should be
clearly higher than just the weapon's Dmg value alone.

**Pass if:** Max hits are noticeably larger than the weapon's base damage would suggest,
consistent with the damage bonus being applied.

**Fail if:** All hits cluster exactly at the weapon's base damage range with no bonus
component (flat distribution at the low end would indicate no damage bonus).

**Note:** This is a statistical observation. You need to watch multiple hits to see
the bonus effect clearly. Faster weapons have smaller bonuses; slower weapons have
larger bonuses.

---

### Test 10: STA Gear Increases Companion Max HP

**Acceptance criterion:** Equipping a STA item on a companion increases max HP.
Removing it decreases max HP.

**Prerequisite:** Any companion. Items: Ornate Adept's Sphere (item 50376, +20 STA,
reqlevel 26) or Intricate Adept's Sphere (item 50417, +23 STA, reqlevel 48).

**Steps:**
1. Recruit a warrior companion at level 40+.
2. Use `!stats` to record the companion's current max HP. Write it down.
3. Summon the Ornate Adept's Sphere (item 50376) and use `!equip ring1 50376` to
   equip it.
4. Use `!stats` again. The max HP should be higher than before.
5. Use `!unequip ring1` to remove the ring.
6. Use `!stats` again. Max HP should return to (approximately) the original value.

**Expected result:** Equipping +20 STA ring increases max HP by approximately
100-200 HP at level 40 (based on the formula: ~5 HP per STA at level 40, scaled by
STAToHPFactor=100). The effect is immediately visible via `!stats`.

**Pass if:** Max HP increases when STA ring is equipped and returns to baseline when removed.

**Fail if:** Max HP is unchanged before and after equipping the STA ring.

**GM commands for setup:**
```
#summonitem 50376      — Ornate Adept's Sphere (+20 STA)
#summonitem 50417      — Intricate Adept's Sphere (+23 STA, higher level)
```

---

### Test 11: Sitting HP Regen — Gradual, Not Instant

**Acceptance criterion:** Sitting companions regenerate HP faster than standing
ones. The regen should be gradual (once per ~6-second tic), NOT instant.

**Prerequisite:** Any companion. Need to damage the companion below full HP without
killing it (fight a weak mob or have someone deal minor damage to the companion).

**Steps:**
1. Recruit a warrior companion.
2. Damage the companion down to approximately 50% HP (fight a mob briefly, then pull
   the companion away when it's at ~50%).
3. Use `!sit` to make the companion sit down.
4. Watch the companion's HP bar or use `!stats` every few seconds.

**Expected result:** HP recovers gradually, roughly every 6 seconds (one EQ tic).
Each tic restores approximately 2x the normal OOC regen amount (with SittingRegenMult=200,
a companion with 5000 max HP and OOCRegenPct=5 recovers ~250 HP per tic standing,
and ~500 HP per tic sitting).

The companion should NOT jump to full HP instantly. Full recovery from 50% should
take 30-90 seconds depending on max HP.

**Pass if:** HP recovers in discrete steps (every ~6 seconds), visibly faster than
if the companion were standing, and definitely NOT instantaneous.

**Fail if:** HP immediately jumps to full upon sitting (the pre-audit-fix bug), or
HP does not recover faster than standing.

**Note:** If you are unsure about the rate, compare sitting vs standing OOC regen
by timing each with a stopwatch. Sitting should be approximately 2x faster.

---

### Test 12: Defense Skill Contribution to AC

**Acceptance criterion:** Companion defense skill contribution to AC uses the Client/Bot
divisor (skill/3 for melee) rather than the NPC divisor (skill/5).

**Prerequisite:** A warrior companion at level 50+.

**Steps:**
1. Recruit a level 50+ warrior companion.
2. Use `!stats` to view the companion's AC. Note the value.
3. Compare this AC value to what you would expect from the companion's defense skill.
   A level 50 warrior has approximately 200 defense skill. With the fixed /3 divisor,
   this contributes ~67 AC. With the old /5 NPC divisor, it would only contribute ~40.

**Expected result:** The companion's AC includes a meaningful contribution from defense
skill, not the reduced NPC divisor. At level 50, the difference between /3 and /5 is
approximately 25+ AC points from defense skill alone.

**Pass if:** `!stats` shows an AC value consistent with the /3 divisor calculation.
The exact expected value: `base_NPC_AC + item_AC + defense_skill/3 ≈ total_AC`.

**Fail if:** AC is significantly lower than expected — specifically, if it appears the
/5 NPC divisor is still being used.

**Note:** This is primarily verifiable through the server-side test suite (Suite 12,
test 12.13 and 12.14 already confirm the math). The in-game check is a sanity validation.

---

### Test 13: Cleric Heal Threshold (80%, Not 90%)

**Acceptance criterion:** A cleric companion does not begin healing until a group
member drops below 80% HP in combat.

**Prerequisite:** Level 40+ cleric companion with healing spells loaded. You need
a companion or yourself to take damage in combat without dying.

**Steps:**
1. Recruit a cleric companion.
2. Enter combat against a mob that deals moderate damage.
3. As you take damage, watch when the cleric begins casting heals.
4. At approximately 85% HP, the cleric should NOT be casting.
5. At approximately 79% HP, the cleric should begin casting a heal.

**Expected result:** The cleric waits until the heal target is below 80% HP before
casting. With the old 90% threshold, the cleric would start healing at 90% (after
taking only one or two hits). With the new 80% threshold, the cleric tolerates more
damage before casting.

**Pass if:** The cleric does not cast a heal when you are at 85-88% HP, but DOES
cast when HP drops to 79% or lower.

**Fail if:** The cleric immediately starts healing after the first scratch (90%
threshold behavior), or refuses to heal even at very low HP.

---

### Test 14: Shaman Slow — Always Attempted First

**Acceptance criterion:** A shaman companion reliably slows the primary target as
its first combat action.

**Prerequisite:** Level 25+ shaman companion with Drowsy (slow spell) or higher-
tier slow spells loaded. Engage a mob that can be slowed.

**Steps:**
1. Recruit a shaman companion.
2. Engage a mob that the shaman will assist you fighting.
3. Watch the combat log. Within the first 2-3 seconds of combat, the shaman should
   attempt to cast its slow spell on the primary target.
4. Repeat this test several times (dismiss and re-engage, or fight multiple mobs).

**Expected result:** The shaman ALWAYS attempts slow on the first combat action in
every fight. With the old 70% chance, roughly 3 in 10 fights the shaman would not
slow on the first action. With the fix (100% attempt), every fight begins with a
slow cast.

**Pass if:** Slow spell attempt appears in the combat log at the start of every fight.

**Fail if:** In some fights the shaman's first action is a DoT or heal instead of slow
(suggesting the old random roll is still active). If it fails 3+ times out of 10 attempts,
that indicates the fix is not working.

---

### Test 15: Shaman Cannibalize

**Acceptance criterion:** A shaman companion uses Cannibalize when mana is low
and HP is healthy.

**Prerequisite:** Shaman companion at level 23+ (to have Cannibalize I) and level 55+
ideally for Cannibalize III/IV. The shaman must be at low mana (below 40%) and high
HP (above 80%).

**Steps:**
1. Recruit a level 55+ shaman companion (to get Cannibalize III).
2. Engage several mobs in sequence to drain the shaman's mana without taking serious
   HP damage (the shaman should be at 85%+ HP but below 40% mana).
3. Move to a safe area (no mobs) and use `!sit` to have the shaman sit.
4. Watch the combat log for a message indicating the shaman is casting Cannibalize.
   It will appear as the shaman casting a spell on itself.
5. After Cannibalize, the shaman's mana should increase and HP should decrease slightly.

**Expected result:** Once mana drops below 40% with HP above 80%, the shaman
automatically casts Cannibalize to trade HP for mana. The effect recurs as needed
until mana is above 40% or HP drops below 80%.

**Pass if:** Cannibalize appears in the combat log when conditions are met.

**Fail if:** The shaman never uses Cannibalize despite being at 30% mana and 90% HP
for an extended period.

---

### Test 16: DPS Casters Stop Nuking Below 20% Mana

**Acceptance criterion:** A wizard companion stops nuking when mana drops below 20%.

**Prerequisite:** Level 30+ wizard companion with nuke spells loaded and an active
combat situation where mana drains.

**Steps:**
1. Recruit a wizard companion.
2. Fight several mobs in sequence, allowing the wizard to nuke freely (aggressive stance).
3. As the wizard's mana depletes, watch for the point where it stops casting nukes.
4. Use `!stats` or watch for lack of casting in the combat log when mana is low.

**Expected result:** The wizard stops casting offensive spells at approximately 20%
mana. With the old 15% cutoff, the wizard would cast deeper into its mana pool. With
the new 20% cutoff, it conserves the last 20% for emergencies.

**Pass if:** The wizard stops nuking when mana is around 20% (rather than 10-15%
as with the old behavior).

**Fail if:** Wizard casts until completely OOM with no mana conservation at all, or
stops casting far above 20% mana without cause.

---

### Test 17: No Standard Buffs During Combat

**Acceptance criterion:** Companions do not attempt to cast standard buffs during
combat engagement.

**Prerequisite:** Level 40+ cleric companion that has buff spells loaded.

**Steps:**
1. Recruit a cleric companion.
2. Engage in extended combat against multiple mobs or a long fight.
3. Watch the combat log carefully for the cleric attempting to cast buff spells
   (like Divine Aura, Armor of Protection, etc.) while actively engaged in combat.

**Expected result:** The cleric does NOT attempt to recast standard buffs while in
combat. It focuses on healing and in-combat utility only. Buffs are only cast during
the idle period after combat ends.

**Pass if:** No standard buff-casting appears in the combat log during active fighting.
After combat ends, the cleric should attempt to rebuff the group.

**Fail if:** The cleric interrupts combat focus to cast armor/regeneration buffs in
the middle of a fight (the pre-Phase-4 behavior).

---

### Test 18: Druid HoT Preference Above 50% HP

**Acceptance criterion:** A druid companion prefers heal-over-time spells when the
target is above 50% HP.

**Prerequisite:** Level 29+ druid companion (to have Chloroplast or similar HoT).
Take moderate damage (50-85% HP range) without falling below 50%.

**Steps:**
1. Recruit a druid companion.
2. Take damage to bring yourself to approximately 70% HP.
3. Stop taking damage and observe what heal the druid casts.
4. Watch whether the druid casts a HoT (multiple small ticks visible in chat over
   time) vs a direct heal (one large heal immediately).

**Expected result:** Above 50% HP, the druid should prefer a HoT spell (like
Chloroplast or Regrowth) rather than a direct Greater Healing. Below 50% HP, the
druid should switch to direct heals.

**Pass if:** At 70% HP, druid casts a HoT. At 35% HP, druid casts a direct heal.

**Fail if:** Druid always uses a direct heal regardless of target HP percentage.

---

### Test 19: Enchanter Mez on Adds

**Acceptance criterion:** An enchanter companion prioritizes mezzing adds over other actions.

**Prerequisite:** Level 30+ enchanter companion with mez spells. You need a situation
where multiple hostile mobs are present (pull two mobs at once).

**Steps:**
1. Recruit an enchanter companion.
2. Set the enchanter to aggressive stance.
3. Pull two mobs at once (use #spawn to create two test mobs if needed).
4. Watch the enchanter's behavior: it should immediately attempt to mez the second mob
   rather than nuke the primary target.

**Expected result:** The enchanter's first action is a mez attempt on the secondary
target (add), not a nuke on the primary. This prevents the second mob from attacking
freely.

**Pass if:** Enchanter casts mez on the add within the first combat round.

**Fail if:** Enchanter ignores the add and starts nuking the primary target instead.

---

### Test 20: Resist Cap — Cannot Exceed Level-Appropriate Maximum

**Acceptance criterion:** No companion resist stat can exceed the resist cap
(level * 5 + 50, or 350 at level 60).

**Prerequisite:** Level 60 companion. Equip multiple resist items to attempt to push
a resist above 350. Use Ward's Ring of Fealty (item 83150, +25 MR/FR/CR) and Circle
of Smoke (item 30534, +25 MR, +15 FR/CR/DR/PR).

**Steps:**
1. Recruit a level 60 companion that has high base resists (look for caster companions
   that may have significant base MR from their NPC entry).
2. Use `!stats` to see current resist values. Note the MR value.
3. Equip Ward's Ring of Fealty: `!equip ring1 [id]`.
4. Use `!stats` again to see MR. Note the increase.
5. Equip Circle of Smoke: `!equip ring2 [id]`.
6. Use `!stats` again.
7. Try to stack additional resist gear or cast resist buffs (like Resist Magic).
8. Regardless of stacking, verify that MR never exceeds 350.

**Expected result:** Even with multiple resist items and resist buffs, MR is capped
at 350 (level 60: 60*5+50=350). Adding more resist gear cannot push it higher.

**Pass if:** MR and other resists stay at or below 350 regardless of how much gear
is stacked.

**Fail if:** Resists exceed 350 after stacking gear and buffs.

**GM commands for setup:**
```
#summonitem 83150      — Ward's Ring of Fealty (+25 MR/FR/CR)
#summonitem 30534      — Circle of Smoke (+25 MR, +15 others)
```

---

### Test 21: Focus Effects Work on Companion Spells

**Acceptance criterion:** Equipping a focus effect item on a companion produces
measurably increased spell damage, healing, or reduced mana cost.

**Prerequisite:** Level 40+ caster companion (wizard or cleric). Need a focus item
that provides Improved Damage (for wizard) or Improved Healing (for cleric). Use a
Wand of Tranquility (item 26768, reqlevel 55, has resist modifiers) or find a focus
item using Spire.

**Steps:**
1. Recruit a wizard or cleric companion at the required level.
2. Note the current spell output WITHOUT any focus gear.
   - For wizard: note nuke damage numbers from the combat log.
   - For cleric: note heal amounts from healing spells.
3. Find a focus item that provides Improved Damage (focustype=1) appropriate to the
   companion's level range. Check Spire or use `#finditem` to locate one.
4. Equip the focus item on the companion.
5. Cast similar spells and note the output.

**Expected result:** With an Improved Damage focus item equipped, nuke spells deal
more damage per cast (usually 5-25% more depending on the focus level). This was
previously broken because the NPC GetFocusEffect path was gated behind a rule that
blocked item focus.

**Pass if:** Spell output (damage or healing) increases after equipping the focus item.

**Fail if:** Spell output is identical whether or not a focus item is equipped.

**Note:** Focus effect items in the Classic-Luclin era typically provide modest
improvements (10-20%). The difference may be subtle. Compare the average damage
of 10 nukes before vs after equipping the focus item.

---

## Edge Case Tests

### Test E1: Weapon Swap Mid-Combat

**Risk from architecture plan:** "If a weapon is swapped via !equip during combat,
the new weapon's damage and delay should take effect on the next attack."

**Steps:**
1. Recruit a warrior companion. Equip a Rusty Longsword (slow, weak).
2. Enter combat against a durable mob.
3. While the companion is actively fighting, use `!equip primary 3617` to swap to the
   Blackened Alloy Longsword (faster, stronger).
4. Observe: attack speed and damage should change within the next attack round.

**Pass if:** After the weapon swap, damage and attack speed reflect the new weapon
on subsequent attacks. No crash or error occurs.

**Fail if:** Server crashes, companion stops attacking, or weapon stats do not update
after swap.

---

### Test E2: Remove All Gear — Fallback to NPC Values

**Risk from architecture plan:** "A companion with no gear at all should fight exactly
as they do today (regression protection)."

**Steps:**
1. Recruit a warrior companion.
2. Remove ALL gear using `!unequip all` or individual slot commands.
3. Use `!stats` to confirm no weapons or armor equipped.
4. Engage a mob. Observe combat behavior.

**Pass if:** Companion continues to attack and deal damage using NPC base values
(npc_types.max_dmg). No crash. HP and AC still reflect base NPC values.

**Fail if:** Companion deals 0 damage, crashes, or behaves erratically when unarmed.

---

### Test E3: Wizard Does NOT Cast Damage Shield on Caster Companions

**Risk from architecture plan:** "Wizard DS spam — wizard would cast DS on all group
members including casters where it is wasteful."

**Prerequisite:** Wizard companion in a group that also includes a caster companion
(enchanter, necromancer, or another wizard). Idle state (not in combat).

**Steps:**
1. Recruit a wizard companion and a caster DPS companion (e.g., enchanter).
2. Wait for the idle buff phase where the wizard refreshes group buffs.
3. Watch the combat log for the wizard's buff-casting behavior.

**Expected result:** The wizard casts damage shield only on melee companions (warriors,
rogues, etc.), NOT on caster companions. The wizard may cast other non-DS buffs on
all group members.

**Pass if:** Damage shield is not applied to caster companions by the wizard.

**Fail if:** The wizard spends mana casting damage shield on the enchanter, necromancer,
or other casters who never get hit in melee.

---

### Test E4: STA Removal Immediately Decreases Max HP

**Risk from PRD:** "The conversion is recalculated on CalcBonuses(), so equipping or
removing STA gear immediately updates max HP."

**Steps:**
1. Recruit a warrior companion.
2. Equip the +20 STA ring (item 50376). Note max HP via `!stats`.
3. Immediately unequip the ring.
4. Use `!stats` again within 5 seconds.

**Pass if:** Max HP drops back to (approximately) the pre-ring value immediately after
removing the ring.

**Fail if:** Max HP stays elevated for an extended period after ring removal.

---

### Test E5: Sitting Regen Does Not Apply During Combat

**Risk from architecture plan:** Sitting regen bonus should only apply when
out of combat.

**Steps:**
1. Recruit a companion. Let it get into combat.
2. While the companion is engaged with a mob, observe: the companion should NOT
   be sitting in combat (standard behavior).
3. If somehow forced to sit during combat, the sitting regen bonus should not
   apply while IsEngaged() is true.

**Pass if:** Companion regen in combat is normal (no bonus), matching expected
in-combat regen rates.

**Fail if:** Companion regens extremely fast during combat, suggesting the sitting
bonus fires during engagement.

---

## Balance Observation Checklist

After running the functional tests, observe overall companion power to fill in the
balance tuning doc values:

| Metric | Test Setup | Observation |
|--------|------------|-------------|
| Warrior DPS (lv60, BIS melee gear) | Level 60 warrior with Blade of Abrogation or equivalent | Damage/minute |
| Tank TTL (lv60, plate gear) | Level 60 warrior tanking a yellow-con mob | Seconds before death without heals |
| Wizard DPS (lv60, mana focus gear) | Level 60 wizard nuking with Improved Damage focus | Damage/minute |
| Cleric heal chain (lv60) | Cleric + warrior pair vs level-appropriate content | Fights per med break |

Target: companions should feel like 70-85% of an equivalently-geared player.

If any companion class feels significantly over- or under-powered, note the
observation for rule tuning:
- Over-powered: reduce `StatScalePct` from 100 to 90-95
- Under-powered: verify all Phases 1-4 active (`UseWeaponDamage=true`, etc.)

---

## Rollback Instructions

If the feature must be rolled back:

```bash
# Revert to previous feature branch commit (adjust commit hash as needed)
cd /mnt/d/Dev/eq/eqemu
git log --oneline -10
git checkout <previous-commit>

# Rebuild
docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"

# Rule rollback (if needed, removes Phase 5 rule from DB)
docker exec akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e \
  "DELETE FROM rule_values WHERE rule_name = 'Companions:ResistCapBase';"

# Data rollback for Cannibalize spells
docker exec akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e \
  "DELETE FROM companion_spell_sets WHERE spell_id IN (265, 754, 1572, 1332) AND class_id = 10;"

# Restart server via Spire or:
cd /mnt/d/Dev/eq/akk-stack && make restart
# Then start server processes per MEMORY.md startup sequence
```

---

## Blockers

No blockers identified from server-side validation.

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|-------------------|--------|
| — | No blockers found | — | — | — |

---

## Recommendations

1. **Fill in balance metrics.** The balance-tuning.md file has placeholder "TBD" values
   for warrior DPS, wizard DPS, cleric heal chains, and tank TTL. After completing the
   in-game tests, record actual measured values in
   `architect/context/balance-tuning.md` to complete the balance pass.

2. **Verify STAToHPFactor DB row (optional).** The `STAToHPFactor`, `SittingRegenMult`,
   `HealThresholdPct`, `ManaCutoffPct`, and `HealerManaConservePct` rules work correctly
   via `ruletypes.h` defaults, but they are not in `rule_values` as explicit rows. If you
   want these visible in the Spire rules UI for easy adjustment, the data-expert can insert
   them with `INSERT INTO rule_values (ruleset_id, rule_name, rule_value) VALUES ...`.
   This is cosmetic — the rules already work without it.

3. **Monitor for focus effect edge cases.** The Phase 5 focus fix delegates companion
   focus lookups to Mob::GetFocusEffect instead of NPC::GetFocusEffect. This is correct
   for all Classic-Luclin era focus items. If any unusual focus behaviors are observed
   (focus applying when it should not, etc.), verify with c-expert.

4. **Cannibalize spell type.** Cannibalize I-IV are tagged with spell_type=2 in
   companion_spell_sets. The c-expert's FindCannibalizeSpell() helper identifies them
   by spell effect (SE_CurrentMana positive), not by spell type, so the type tag is
   cosmetic for this purpose. No action needed.
