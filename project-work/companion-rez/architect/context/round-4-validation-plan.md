# Round 4 — Sustained-Play Validation Plan with Adjacent-System Regression Coverage

> **Date:** 2026-04-29
> **Architect:** V3R architect
> **Inputs:** Rounds 1–3 + V3R Architecture Mandates 4 and 5
> **Purpose:** Define the V3R Validation Plan for game-tester (V3R.6). Per Mandate 4 (sustained-play scenarios mandatory) and Mandate 5 (adjacent-system regression coverage for each customized subsystem the fix touches).

---

## 1. Validation Plan Structure

The V3R Validation Plan has THREE bands of scenarios:

1. **Direct symptom validation** — confirm each bug's reported symptom is resolved by the fix
2. **Sustained-play coverage** — long-duration scenarios that surface tick-rate, registration-drift, and timer-fires-but-not-checked bugs (per V3R Mandate 4 + the user's regression-discipline feedback)
3. **Adjacent-system regression coverage** — for each customized subsystem the V3R fix touches, regression tests for at least one consumer beyond the symptom (per V3R Mandate 5)

All scenarios are in-game tests run by game-tester at V3R.6 with user observation/confirmation.

---

## 2. Band 1 — Direct Symptom Validation

### Scenario V3R-1 — BUG-002 visibility heartbeat (PRIMARY)

**Pre-conditions:** Player + 1 NPC companion (e.g., Lashun Novashine, Cleric). Combat-capable mob nearby. Companion in balanced or aggressive stance.

**Steps:**
1. Engage a single mob.
2. Observe the companion entering combat. Cleric should casting (stationary).
3. Allow combat to play out for 60+ seconds with the cleric stationary in casting stance.
4. Watch the companion's visibility on screen continuously.

**Pass:** Companion remains visible throughout the entire fight, even when stationary for 30+ seconds at a time.

**Fail:** Companion vanishes from screen after a no-movement window of ~5-10 seconds.

**Why this works:** Tests Fix V's heartbeat-unconditional behavior in the alive-and-stationary case (the original BUG-002 symptom).

### Scenario V3R-2 — BUG-005 auto-dismiss timer (PRIMARY)

**Pre-conditions:** Player + 1 NPC companion. Safe zone (no aggro). `Companions:DeathDespawnS=1800` (30 min) at default.

**Steps:**
1. Kill the companion (`#kill` while targeting it).
2. Verify the companion enters dead state (`SELECT is_suspended FROM companion_data WHERE id=X` returns 1).
3. **Wait the full 30 minutes** without rezzing or unsuspending.
4. Verify the companion auto-dismisses.

**Pass:** After 30 minutes, the companion is auto-dismissed (companion_data.is_suspended remains, but the entity is removed from the zone; or the companion_data row is updated per existing auto-dismiss behavior).

**Fail:** After 30+ minutes, the companion is still in the dead-but-not-dismissed state. The despawn timer fired but was not checked.

**Notes:** This is a slow scenario. Game-tester should run it in parallel with other tests; can be backgrounded.

**Why this works:** Tests Fix V's despawn-timer-unconditional behavior. This is the regression that the prior V3 plan missed and the V3R enumeration surfaced.

### Scenario V3R-3 — BUG-004 AoE friend/foe filter (PRIMARY)

**Pre-conditions:** Player has a class with AoE detrimental spell (mez, stun, AoE damage). Player + 2 NPC companions. Engaged with 1+ enemy mob, with companions and enemy within AoE radius.

**Steps:**
1. Position so that own companions are within AoE radius of the player AND the enemy.
2. Cast a player-cast harmful AoE: AoE mez, AoE stun, or AoE damage spell.
3. Observe target list.

**Pass:** Companion is NOT affected by the AoE. Enemy is affected.

**Fail:** Companion is mezzed/stunned/damaged by the player's AoE.

**Repeat with:** AoE damage spell, AoE mez, AoE stun, and any `ST_TargetAENoPlayersPets` spell available at the player's level.

**Why this works:** Tests Fix W's two-site exclusion. The first three repeats test Site 1 (`Mob::IsAttackAllowed`). The `ST_TargetAENoPlayersPets` repeat tests Site 2 (`IsPetOwnerOfClientBot` extension).

### Scenario V3R-4 — BUG-003 empirical workflow (V3R-Empirical-1, 4-test protocol)

Already specified in detail in Round 3 Section 4. Repeated here as a validation scenario.

**Pre-conditions:** Player + Lashun Novashine (Cleric), in safe zone, sitting. Buffs verified or stripped.

**Test 1 (60s, current rules):**
1. `#set mana_full` on Lashun.
2. Both player and companion sit.
3. Record `!status` mana every 30s. Note every gsay mana report.
4. After 60s, calculate per-report mana delta.
5. Expected: ~157 mana per 15s gsay report (~2% of 7907 pool).

**Test 1.5 (60s, rule-bumped, conditional):**
- Run only if Test 1 result is ≤50/report.
- `data-expert: UPDATE rule_values SET rule_value='175' WHERE rule_name='Companions:CompanionManaRegenMult';` (or apply via Spire's rule editor).
- `#rules reload` (or `#rules set <Rule> <Value>` for transient test) in-game.
- `#set mana_full` on Lashun. Both sit.
- Same 4-cycle observation.
- Expected: regen rate scales 1.75x (matches the player's `Character:ManaRegenMultiplier=175`).

**Test 2 (60s, drain-and-climb, current rules):**
- Revert rule to 100 if needed.
- `#set mana 0` on Lashun. Sit.
- Same 4-cycle observation.
- Compare to Test 1.

**Test 3 (60s, post-rez-from-zero):**
- Unsuspend Jimble (`UPDATE companion_data SET is_suspended=0 WHERE id=22` or `!unsuspend Jimble`).
- `#kill Jimble`.
- Wait for Lashun to auto-rez Jimble.
- Verify Jimble post-rez at cur_mana=0 (SQL spot-check).
- Sit. Same 4-cycle observation.
- Compare to Test 2.

**Test 4 (60s, optional, buff-state):**
- Apply or wait for natural expiry of regen-boosting buffs (Spirit of Cheetah / Clarity / etc.) on Lashun.
- Repeat Test 1 setup (`#set mana_full`).
- Sit. Same 4-cycle observation.
- Compare with-buff vs without-buff rates.

**Pass / Decision matrix:**

| Test 1 | Test 1.5 | Verdict |
|---|---|---|
| ≥100/report | (skip) | Branch B-misperception → close with runbook note |
| ≤50/report | ≥100/report | Branch B-rule → V3R fix is one rule UPDATE (commit it) |
| ≤50/report | ≤50/report | Branch A → escalate to c-expert; possibly descope to follow-up bugfix |

| Test 2 | Test 3 | Additional verdict |
|---|---|---|
| Test 2 ≈ Test 1 | (any) | Climb-from-zero is NOT slower → confirms Branch B-misperception/rule, eliminates Branch C |
| Test 2 healthy | Test 3 < Test 2 | Branch C → rez path leaves degraded regen → escalate to c-expert |
| Test 4 ≪ Test 1 | (any) | Branch D → buff loss contributes → escalate to lua-expert |

---

## 3. Band 2 — Sustained-Play Coverage (per Mandate 4)

These scenarios specifically target tick-rate, registration-drift, and long-duration timer bugs that brief encounters miss. Required by V3R Mandate 4 and the user's regression-discipline feedback.

### Scenario V3R-5 — Sustained combat encounter (5+ minutes)

**Pre-conditions:** Player + 2-3 NPC companions in a higher-difficulty zone.

**Steps:**
1. Engage a sustained combat encounter (multiple mobs, 5+ minutes of actual combat).
2. Observe ALL companions throughout: visibility, regen, AoE friend-foe (if any AoE mobs in the area).
3. Verify each companion remains visible the entire time.
4. Verify each companion's HP/mana behave plausibly through the fight.
5. Verify NO companion is affected by player's harmful AoE (if cast).

**Pass:** All companions visible, regenning, and properly excluded from owner AoE throughout the 5+ minute window.

**Why this works:** Long combat = many stationary intervals for casters → exercises heartbeat. Multi-mob = AoE often used → exercises Fix W. Long duration = many regen ticks → exercises Fix V's alive-companion regen path remaining intact (V.3 regression guard).

### Scenario V3R-6 — Long-duration sit regen (3+ minutes)

**Pre-conditions:** Player + 2+ NPC companions, safe zone, sitting.

**Steps:**
1. All sit down. All start at full mana.
2. `#set mana 50` (or similar non-zero, non-full value) on each companion to give a regen runway.
3. Observe `!status` mana every 30s for at least 3 minutes.
4. Record per-companion regen rate.

**Pass:** All companions regen at the rate established by Test 1 in V3R-4 (whether at default rules or rule-bumped, depending on V3R-4 outcome). Rates remain consistent over the 3+ minute window.

**Why this works:** Long-duration sit confirms that regen ticks are CONSISTENT, not subject to drift, intermittent stalls, or progressive slowing. This is the "sustained play surfaces tick-rate bugs" failure mode the user's regression-discipline feedback warns about.

### Scenario V3R-7 — Multi-zone cycle

**Pre-conditions:** Player + 2 NPC companions.

**Steps:**
1. Verify all companions visible and present in current zone.
2. Zone to another zone. Verify all companions follow correctly. Verify visibility post-zone-in.
3. Sit and observe regen for 60s in the new zone.
4. Zone again. Verify same.
5. Repeat 3 zone transitions total.

**Pass:** All companions visible, follow correctly, regen normally in each zone after transition. No vanish-in-new-zone behavior.

**Why this works:** Tests that companion entity-list registration is stable across zone transitions (validates that Fix V's restructure doesn't affect SpawnCompanionsOnZone path).

### Scenario V3R-8 — Multi-rez cycle

**Pre-conditions:** Player + 1 Cleric companion + 1 melee companion.

**Steps:**
1. Engage and let melee companion die (force a death scenario).
2. Wait for Cleric auto-rez. Verify rez succeeds, melee companion alive in group.
3. Confirm rezzed companion has correct visibility, !status responds, group membership is intact.
4. Repeat the death+rez cycle 3 times.

**Pass:** Each rez cycle succeeds. Companion is alive, visible, in-group, regen ticking, and AoE-protected (if AoE cast in the post-rez window).

**Why this works:** Tests that Fix V doesn't degrade rez-path behavior (V2 Fix B). Tests that Fix W's AoE exclusion works for rezzed companions just as well as alive-from-spawn companions. Long-tail validation.

### Scenario V3R-9 — Sustained AoE encounter

**Pre-conditions:** Player has multiple AoE detrimental spells. Engage a multi-mob encounter where AoE is repeatedly cast.

**Steps:**
1. Engage 3-4 enemy mobs.
2. Cast multiple AoE spells over 2+ minutes — alternate AoE damage, AoE mez, AoE stun.
3. Observe whether any companion is ever incorrectly hit.
4. Cast ST_TargetAENoPlayersPets-class spells if the player class has them.

**Pass:** Across all AoE casts in the 2+ minute window, NO companion is ever incorrectly affected.

**Why this works:** Tests Fix W's exclusion under sustained pressure across multiple spell types. Catches any spell-type-specific gap.

---

## 4. Band 3 — Adjacent-System Regression Coverage (per Mandate 5)

For each customized subsystem the V3R fix touches, the validation plan includes a regression test for at least one consumer beyond the symptom.

### Subsystem touched: `Companion::Process()` AI tick loop

| Consumer | Scenario | Pass criterion |
|---|---|---|
| **Alive companion regen tick** (B.5, B.6) | V3R-6 (long-duration sit regen) | Mana/HP regen ticks consistently for 3+ minutes |
| **Sitting sync / stand-when-engage** (B.7) | V3R-5 (sustained combat) — companions transition stand→combat smoothly when player engages | Cleric companion stands when player enters combat (no stuck-sitting) |
| **Mana report gsay** (B.8) | V3R-4 Test 1 baseline | gsay reports fire on 15s cadence with non-zero mana increments |
| **LOM announcement** (B.9) | V3R-5 sustained combat — let cleric run low on mana | `Companions:LOMThresholdPct=15` triggers LOM announce |
| **Combat positioning** (B.10) | V3R-5 sustained combat — observe companion movement | Cleric maintains caster standoff range; melee companions engage in formation |
| **Attack rounds** (B.11) | V3R-5 sustained combat — melee companion auto-attacks | Melee companion swings on attack-timer cadence |
| **!command dispatch** (lua-expert L-6 high-risk) | V3R-8 (multi-rez cycle) — after each rez, run !status, !passive, !aggressive, !follow, !guard, !hold, !recall, !buffme, !target, !assist, !dismiss | Each !-command responds correctly post-rez |

### Subsystem touched: `Mob::IsAttackAllowed` AoE filter

| Consumer | Scenario | Pass criterion |
|---|---|---|
| **NPC-vs-Companion combat** | V3R-5 sustained combat — observe NPCs attacking companions | NPCs still treat companions as valid targets (Fix W only blocks Client owner, not third-party NPC casters) |
| **Cross-owner companions** | If multi-player available: own companion + another player's companion in AoE | Own companion excluded; other player's companion still hit (PVP behavior preserved) |
| **Companion-as-caster** | Companion casts harmful spell at NPC | Existing `Companion::IsAttackAllowed` override at companion.cpp:832 still works (companion can hit valid hostile target) |
| **Group beneficial AoE** | Player casts group heal AoE — companion in radius | Companion receives heal (Fix W only affects detrimental matrix; beneficial path unchanged) |
| **`ST_TargetAENoPlayersPets`-class spells** | V3R-3 PRIMARY repeat with this class of spell | Companion excluded from AoE (Site 2 fix verified) |

### Subsystem touched: `m_death_despawn_timer`

| Consumer | Scenario | Pass criterion |
|---|---|---|
| **Auto-dismiss after Companions:DeathDespawnS** | V3R-2 PRIMARY (30 min wait) | Auto-dismiss fires correctly |
| **Auto-dismiss interruption by rez** | After death + within DeathDespawnS, Cleric rezzes the companion | Despawn timer is correctly reset/disabled by rez (existing behavior, ensure not broken by Fix V) |
| **Auto-dismiss interruption by manual rez** | Player or Cleric NPC casts manual rez on companion corpse | Despawn timer correctly stopped |

### Subsystem touched: `m_ping_timer` heartbeat

| Consumer | Scenario | Pass criterion |
|---|---|---|
| **Heartbeat for alive stationary** | V3R-5 sustained combat — alive cleric stationary for 30+s | Companion remains visible (heartbeat firing at 5s cadence) |
| **Heartbeat for dead stationary** | V3R-1 PRIMARY | Companion (corpse) remains visible during the dying-window |
| **Heartbeat ceases at depop** | V3R-2 — observe that after auto-dismiss the companion entity is correctly removed | Heartbeat does not fire for a depopped (no-longer-in-zone) entity |

### Subsystem touched: `Companions:CompanionManaRegenMult` (conditional, Branch B-rule)

If V3R-4 Test 1.5 confirms Branch B-rule is the BUG-003 outcome:

| Consumer | Scenario | Pass criterion |
|---|---|---|
| **Sustained-sit regen** at bumped value | V3R-6 with `Companions:CompanionManaRegenMult=175` | Mana regen ticks at ~1.75x previous rate |
| **Combat regen** | V3R-5 — observe in-combat mana regen for casters | Combat regen unchanged or also scaled per `Companions:AlwaysMeditateRegen` interaction |
| **Cleric mana for healing** | V3R-5 — observe Cleric does not run dry as fast | Cleric maintains mana for sustained combat |
| **Ratio against player's regen** | Side-by-side observation of player vs companion mana regen | Companion mana regen rate visually matches player's (1.75x) |

---

## 5. Antagonistic Pass Hooks

Items flagged in Round 1/2 antagonistic pass that need explicit scenario coverage:

- **C-10 (Fix C atomic-rez coexistence window):** Insert into V3R-8 multi-rez cycle. During each rez, cast an AoE spell at the precise moment of rez. Pass: AoE never doubles damage on the rezzed companion. Negative result is theoretical only; this is a verification scenario not a failure-likely scenario.
- **NPC:OOCRegen vs Companions:OOCRegenPct interaction (G-9 carry-forward):** Insert into V3R-6 long-duration sit regen. Verify that a sustained-sit alive companion regens at the rate predicted by `Companions:OOCRegenPct=5` (5% of max HP per tick), NOT the base `NPC:OOCRegen=1` (~1 HP per tick). If observed rate is ~1 HP/tick, that's a code-path regression; escalate to c-expert.
- **`Companions:CompanionManaRegenMult` git audit (G-5a):** Documentation-only; does not require a scenario. c-expert reports the git audit result asynchronously.
- **HP regen parallel question (config-expert follow-up 2):** If V3R-4 Test 1 shows healthy mana regen but slow HP regen (or vice versa), V3R-7 architect-decision step considers whether a parallel rule UPDATE is warranted for `Companions:OOCRegenPct` or `Companions:HPRegenPerTic`.

---

## 6. Validation Plan Pass Criteria (Aggregate)

The V3R fix is considered validation-complete when:

1. **All Band 1 PRIMARY scenarios pass** (V3R-1, V3R-2, V3R-3) — direct symptom resolution
2. **V3R-4 has a defined outcome** — Branch B-misperception (close with note), Branch B-rule (rule UPDATE applied and confirmed), Branch A/C/D (escalated to follow-up with documented evidence)
3. **All Band 2 sustained-play scenarios pass** (V3R-5 through V3R-9)
4. **All Band 3 adjacent-system regression scenarios pass** (the consumer matrix for each touched subsystem)
5. **Antagonistic pass hooks all examined** with results documented (pass / theoretical-only / escalated)
6. **No regression observed** in any V1 or V2 fix behavior — Suite 29 + Suite 36 V1/V2 tests continue to pass post-V3R rebuild

A failure in any Band 1 scenario blocks V3R closure. A failure in Band 2 or Band 3 scenarios may indicate scope expansion needed in V3R or a follow-up bugfix.
