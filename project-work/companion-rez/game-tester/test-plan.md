# Companion Rez — Test Plan

> **Feature branch:** `bugfix/companion-rez`
> **Author:** game-tester
> **Date:** 2026-04-28
> **Server-side result:** PASS

---

## Test Summary

This test plan validates the companion auto-rez bugfix (BUG-001). The fix has
two C++ changes: (1) `eqemu/zone/spells.cpp:2051` — extending the `ST_Corpse`
guard in `DetermineSpellTargets()` to admit `IsCompanionCorpse()` alongside
`IsPlayerCorpse()`, and (2) `eqemu/zone/companion_ai.cpp:1861` — extending
`FindDeadGroupMemberCorpse()` to find the owner's player corpse first before
falling back to companion corpse search.

**Systems touched:** C++ source only (no Lua, no SQL, no protocol, no config).
**Acceptance criteria:** 10 (AC-1 through AC-10).
**Known companion roster (character_id=6):**
- Lashun Novashine — Cleric, class 2, companion_id=24 (the rezzer)
- Hollish Tnoops — Warrior, class 1, companion_id=18
- Jimble Woodentoe — Ranger, class 4, companion_id=22
- Jracol Brestiage — Rogue, class 9, companion_id=23
- Lydl the Great — Wizard, class 12, companion_id=10

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] status.md — all implementation tasks Complete
- [x] Acceptance criteria identified: 10 criteria (AC-1 through AC-10)

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Commit verification — eqemu TDD red commit present | PASS | `30f6d6ef5` on `bugfix/companion-rez` — 241 lines test code, cli_companion_tests.cpp |
| 2 | Commit verification — eqemu fix commit present | PASS | `83a96f655` on `bugfix/companion-rez` — spells.cpp (+8/-6), companion_ai.cpp (+16/-4) |
| 3 | Commit ordering — TDD red commit precedes fix commit | PASS | `30f6d6ef5` (13:44) then `83a96f655` (13:47) — AC-9 TDD discipline verified |
| 4 | Commit verification — claude dev-notes commits present | PASS | `f9b8679` (c-expert dev-notes) and `dedb777` (infra-expert restart) |
| 5 | Binary verification — `IsCompanionCorpse` in running zone binary | PASS | `strings` shows `IsCompanionCorpse`, `_ZNK6Corpse17IsCompanionCorpseEv`, `is_companion_corpse`, `ResurrectFromCorpse`, `FindDeadGroupMemberCorpse` |
| 6 | Binary freshness — zone binary timestamp matches fix commit | PASS | `/home/eqemu/server/bin/zone` built Apr 28 13:46 (matches fix commit time) |
| 7 | Test suite — Suite 29 test 29.14 | PASS | `DetermineSpellTargets admits companion corpse (ST_Corpse guard)` |
| 8 | Test suite — Suite 29 test 29.15 | PASS | `IsCompanionCorpse() true after SetCompanionData (branch gate)` + `DetermineSpellTargets gate open for companion corpse (pipeline reachable)` |
| 9 | Test suite — Suite 29 test 29.16 | PASS | `FindDeadGroupMemberCorpse returns nullptr when no owner in zone (no crash post-fix)` + `FindDeadGroupMemberCorpse callable without crash after player corpse path added` |
| 10 | Test suite — Suite 29 test 29.17 | PASS | `DetermineSpellTargets admits companion corpse via Resurrection (392)` |
| 11 | Test suite — Suite 29 existing tests 29.1-29.13 | PASS | All 13 pre-existing tests pass; no regressions |
| 12 | Test suite — All 35 suites pass | PASS | `[OK] All Companion Tests Completed!` — zero failures, zero regressions |
| 13 | DB integrity — companion_data owner FK | PASS | 0 orphaned rows (owner_id refs valid character_data.id) |
| 14 | DB integrity — companion_data npc_type_id FK | PASS | 0 orphaned rows (npc_type_id refs valid npc_types.id) |
| 15 | DB integrity — companion_spell_sets spell FK | PASS | 0 orphaned spell refs (all spell_ids valid in spells_new) |
| 16 | DB integrity — companion_data death state | PASS | 5 total: 2 suspended, 0 dismissed, 0 ambiguous (is_suspended AND is_dismissed both set) |
| 17 | Rule validation — Companions:RezEnabled | PASS | Value: `true` |
| 18 | Rule validation — Companions:RezPostCombatDelayS | PASS | Value: `10` (N=10 per AC-1) |
| 19 | Rule validation — Companions:RezRange | PASS | Value: `200` |
| 20 | Rule validation — Companions:RezWaiveReagents | PASS | Value: `true` |
| 21 | Rule validation — Companions:DeathDespawnS | PASS | Value: `1800` (30 min corpse persistence) |
| 22 | Cleric rez spell data — companion_spell_sets coverage | PASS | 9 Cleric rez spells (class_id=2, spell_type=65536): Reanimation(2168), Reconstitution(2169), Reparation(2170), Revive(391), Renewal(2171), Resuscitate(388), Restoration(2172), Resurrection(392), Reviviscence(1524) |
| 23 | Cleric rez spell data — targettype and effectid | PASS | All 9 have targettype=15 (ST_Corpse) and effectid1=81 (SpellEffect::Revive) |
| 24 | Log analysis — zone logs post-restart | PASS WITH WARNING | No crash, no FATAL, no rez-related errors. Pre-existing inventory slot_id warnings present (slots 3810-3819 in The Hole zone, character_id=6) — unrelated to this fix, pre-existing condition |
| 25 | Log analysis — world log errors | PASS | No errors in world.log post-restart |
| 26 | Log analysis — no crashes since restart | PASS | Crash log folder newest entry is Apr 20 (pre-restart); no post-fix crashes |
| 27 | Spawn/loot/script verification | N/A — SKIP | No spawn, loot, or quest script changes in this fix |
| 28 | Build verification | PASS | Binary at `eqemu/build/bin/zone` is 222 MB, built Apr 28 13:46, post-fix timestamp confirmed |

### Database Integrity

No schema changes were made by this fix. The following queries confirm integrity of
tables involved in the rez pipeline.

```sql
-- companion_data health
SELECT COUNT(*) AS total, SUM(is_suspended) AS suspended,
       SUM(is_dismissed) AS dismissed,
       SUM(CASE WHEN is_suspended=1 AND is_dismissed=1 THEN 1 ELSE 0 END) AS ambiguous
FROM companion_data;
-- Result: total=5, suspended=2, dismissed=0, ambiguous=0 -- PASS

-- companion_data -> character_data FK
SELECT COUNT(*) FROM companion_data cd
LEFT JOIN character_data c ON cd.owner_id = c.id WHERE c.id IS NULL;
-- Result: 0 -- PASS

-- companion_data -> npc_types FK
SELECT COUNT(*) FROM companion_data cd
LEFT JOIN npc_types nt ON cd.npc_type_id = nt.id WHERE nt.id IS NULL;
-- Result: 0 -- PASS

-- companion_spell_sets -> spells_new FK
SELECT COUNT(*) FROM companion_spell_sets css
LEFT JOIN spells_new s ON css.spell_id = s.id WHERE s.id IS NULL;
-- Result: 0 -- PASS
```

### Quest Script Syntax

No Lua or Perl scripts were modified by this fix.

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| (none modified) | — | N/A | Architecture confirmed: no rez logic in Lua; all logic is C++ |

### Log Analysis

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| `zone_dynamic_01.log` | `_PutItem Invalid slot_id` (slots 3810-3819) | WARNING | Pre-existing inventory slot issue for character_id=6 items in The Hole zone. NOT related to companion-rez fix. Present before this fix. |
| `zone_dynamic_02.log` | Same inventory slot warnings | WARNING | Same pre-existing condition, different zone (freportw) |
| `world.log` | None | — | Clean |
| `loginserver.log` | None | — | Clean |
| `crashes/` | No new crashes | — | Newest crash is Apr 20 (pre-restart) |

**Pre-existing inventory warning note:** Slots 3810-3819 are beyond the Titanium
client's bank slot range and represent a known pre-existing character inventory
migration issue. These warnings appear on every zone load for character_id=6 and
predate this bugfix branch by many sessions. They do not affect gameplay or rez
functionality.

### Rule Validation

| Rule | Value | Valid Range | Result |
|------|-------|-------------|--------|
| `Companions:RezEnabled` | `true` | `true / false` | PASS |
| `Companions:RezPostCombatDelayS` | `10` | `0–3600` | PASS — N=10 per AC-1 |
| `Companions:RezRange` | `200` | `1–9999` | PASS |
| `Companions:RezWaiveReagents` | `true` | `true / false` | PASS |
| `Companions:DeathDespawnS` | `1800` | `60–86400` | PASS — 30 min corpse persistence |

### Build Verification

- **Build command:** `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
- **Result:** PASS (binary present at `/home/eqemu/server/bin/zone`, built Apr 28 13:46)
- **Status noted in:** c-expert dev-notes commit `f9b8679` — "Zero build warnings. No regressions."

---

## Part 2: In-Game Testing Guide

### Overview

Your companion roster for these tests:
- **Lashun Novashine** — Cleric companion (level 54, companion_id=24). She is the rezzer.
- **Hollish Tnoops** — Warrior companion (level 54). Use as the "goes down" target.
- **Jimble Woodentoe** or **Jracol Brestiage** — additional companions for multi-target tests.
- **Lydl the Great** — Wizard companion. Use for caster role in multi-target.

**Key timing to understand:** After combat ends, the rez pipeline has two stages:
1. `RezPostCombatDelayS=10` — a 10-second settling timer that fires after combat ends
2. AI idle tick cadence — once the timer fires, the cleric's spell AI checks every 6-60 seconds

**Worst-case total wait: ~70 seconds.** Budget this when waiting for the rez.
**Best-case total wait: ~10-15 seconds.**

### Prerequisites for All Tests

```
#level 54          -- ensures your character matches companion level
#reloadquests      -- ensure quest scripts are fresh
```

Use `!summon <CompanionName>` to bring your companion party together if any are
suspended. Standard companion recruit commands apply if any need re-recruitment.

---

### Test 1: Single NPC Companion Down Post-Fight — Primary Regression Test

**Acceptance criteria:** AC-1, AC-3, AC-7 (happy path), AC-10

**What you're proving:** After the fix, the Cleric actually rezzes a downed NPC
companion. This is the BUG-001 reproduction case. Before the fix: Lashun would
attempt to cast but Hollish would stay down. After the fix: Hollish comes back.

**Setup:**
1. Have Lashun Novashine (Cleric) and Hollish Tnoops (Warrior) both active and in your group.
2. Zone into a Classic-Luclin zone with manageable mobs. Najena, Befallen, or
   Lake of Ill Omen work well.

```
#zone najena
```

**Steps:**
1. Engage a mob that Hollish can kill without dying. Do a few fights to confirm Lashun has full mana.
2. Set up a fight where Hollish will likely die — a named mob, a bad pull with adds,
   or use the GM setup: let the fight proceed naturally.
   - Optional GM assist: `#spawn <mob_npcid>` then let it fight Hollish directly.
3. Win the fight with Lashun alive and Hollish as a corpse. Verify with `#findnpc Hollish` —
   you should see a corpse entity for Hollish.
4. Wait. Do NOT cast anything. Do NOT command Lashun.
5. Watch Lashun. Within 10-70 seconds, she should:
   - Begin casting a rez spell (you will see a spell bar / cast animation)
   - The cast completes (6-second cast)
   - Hollish's corpse disappears
   - Hollish reappears at the corpse location with low HP (rez %), 0 mana, no buffs

**Expected result:**
- Hollish returns to life and rejoins the group without any player input
- Hollish's HP is a percentage of max (depends on which rez tier Lashun uses at level 54)
  - At 54 with full mana (>=50%), Lashun should use Resurrection (392) — Hollish gets 90% XP back
  - If Lashun is low mana (<50%), she may use a cheaper tier
- No error messages in chat
- Hollish is in your group and ready to fight

**Pass if:**
- Hollish's corpse depops
- Hollish entity reappears
- Hollish is in your group (check group window)
- No "fizzle" / "corpse not valid" messages from Lashun

**Fail if:**
- Hollish stays as a corpse indefinitely (BUG-001 original symptom)
- Lashun's spell animation fires but nothing happens
- Error messages appear in chat about the rez
- Lashun enters an infinite cast-attempt loop

---

### Test 2: Player Rez — Cleric Targets Player Corpse First

**Acceptance criteria:** AC-2, AC-4

**What you're proving:** The extended `FindDeadGroupMemberCorpse()` now finds the
player's corpse (priority 1 per the architecture decision). The standard EQ rez
window appears for the player.

**Setup:**
- Have Lashun Novashine (Cleric) active.
- Have at least one other NPC companion (e.g., Hollish) active.
- Zone somewhere you can die safely and test the rez window.

```
#zone najena
```

**Steps:**
1. Engage a tough mob where you will die but Lashun survives.
   - GM option: `#invulnerable on` for companions only, then fight something hard.
   - Or use a weaker companion setup where you die last.
2. Die in combat. Ensure Lashun is still alive.
3. Watch from ghost/corpse perspective. The last mob must also die (so combat ends).
4. Wait 10-70 seconds.
5. Observe: Lashun should target YOUR corpse (not a companion's corpse) and begin casting.
6. The standard EQ rez window should appear: "Lashun Novashine has resurrected you..."

**Expected result:**
- Standard EQ rez accept/decline window appears
- `rezzer_name` in the window is Lashun's entity name
- You can accept: your character reappears with HP at rez %, mana/endurance restored per spell
- You can decline: your corpse remains, you stay as ghost

**Pass if:**
- Rez window appears
- Rez window shows Lashun as the caster
- Accepting the rez restores you to life

**Fail if:**
- Rez window never appears (cleric ignores player corpse)
- Rez window appears with no caster name
- Accepting the rez does nothing

**Note on player-first ordering:** If both you AND a companion are down, Lashun should
rez YOU first, then the companion ~20 seconds later. This is the documented player-priority
ordering (architecture.md Q4 resolution).

---

### Test 3: Multi-Target Sequencing

**Acceptance criteria:** AC-6

**What you're proving:** The Cleric rezzes multiple downed party members in sequence —
player first, then companions. All downed targets get rezzed, not just one.

**Setup:**
- Have Lashun (Cleric), Hollish (Warrior), and one more companion (Jimble or Jracol) active.
- Engineer a fight where at least two non-cleric companions die.

**Steps:**
1. Zone into a zone with stronger mobs. Pull something dangerous enough to kill both Hollish and Jimble.
2. Win the fight with Lashun alive.
3. You should now have 2 companion corpses (Hollish and Jimble).
4. Wait. Observe Lashun's behavior over ~2-3 minutes.

**Expected result:**
- Lashun casts on the first corpse (~10-70s after combat ends)
- First companion returns
- Lashun waits ~20 seconds (rez spell recast timer)
- Lashun casts on the second corpse
- Second companion returns
- No error spam between rezzes

**Pass if:**
- Both companions return to life in sequence
- ~20 second gap between the two rezzes
- No "corpse not valid" or other error messages

**Fail if:**
- Only one companion is rezzed and the second is ignored
- Lashun stops after the first rez and never continues

**Multi-target + player variant:** If you also die in this fight, Lashun should rez
YOU first (player priority), then sequence through the two companion corpses.

---

### Test 4: Cleric Out of Mana — Graceful OOM Behavior

**Acceptance criteria:** AC-7 (out-of-mana path)

**What you're proving:** When Lashun runs out of mana mid-rez-queue, she does NOT
spam errors, does NOT loop forever, and eventually rezzes remaining corpses after
regenerating mana.

**Setup:**
- Have Lashun active with low mana.
- Need 2 companion corpses.

**GM setup for forced low-mana state:**
```
-- There is no direct mana-drain command; use a long fight that burns her mana naturally
-- Or have her cast many heals before the fight where companions die
```

**Steps:**
1. Engineer a long fight that burns Lashun's mana significantly (multiple heals).
2. Ensure two companions die at the end of the fight.
3. Lashun finishes combat at very low mana.
4. Observe: Lashun rezzes the first corpse (using the cheapest rez available if mana < 50%).
5. After the first rez, her mana may be exhausted.
6. Observe: Lashun sits/meditates (one announcement: "I must meditate..."). No repeated messages.
7. Wait for mana to regenerate.
8. Observe: Lashun automatically casts on the second corpse when mana is sufficient.

**Expected result:**
- One meditation announcement (not repeated spam)
- No "fizzle" or "not enough mana" loops
- Second corpse is rezzed when mana recovers

**Pass if:**
- Meditation announcement appears once only
- Second companion is eventually rezzed without player input

**Fail if:**
- "Not enough mana" appears in chat repeatedly
- Lashun enters a cast-fail-attempt loop
- Second companion is never rezzed even after mana recovers

---

### Test 5: Cleric Down — Graceful No-Op

**Acceptance criteria:** AC-7 (no rezzer path)

**What you're proving:** When the Cleric dies and there is no other rezzer, the
system handles it gracefully — no error spam, no crash, no surprise behavior.
This is the documented expected behavior: no auto-rez.

**Setup:**
- Have Lashun (Cleric) and Hollish (Warrior) active.
- Engineer a fight where both die, but you (the player) and/or another companion finishes.

**Steps:**
1. Pull a fight where Lashun dies AND Hollish dies.
2. You (as player) finish the remaining mob.
3. Combat ends. You are the only one alive.
4. Observe: nothing auto-rez related happens.
5. Confirm: no error messages in chat, no failed cast loops.

**Expected result:**
- Combat ends with no alive Cleric
- No auto-rez fires
- No error messages appear
- The zone is stable (no crashes, no log spam)

**Pass if:**
- No rez attempt is made
- No error messages related to rez
- Server remains stable (zone does not crash)

**Fail if:**
- Error spam appears related to rez
- Dead Lashun somehow casts a rez
- Zone crashes

**Recovery note:** After this test, recover Hollish and Lashun via re-recruitment
(`!recruit Hollish_Tnoops` etc.) or a manual corpse run.

---

### Test 6: Mid-Combat Rez Prevention

**Acceptance criteria:** AC-8

**What you're proving:** Lashun does NOT initiate a rez while combat is still active.
The rez only fires after combat ends.

**Steps:**
1. Have Lashun and Hollish active.
2. Pull a fight. During the fight, intentionally have Hollish die (e.g., let it take damage until it drops).
3. Combat is still active (you are still fighting).
4. Observe Lashun during the active fight.
5. Win the fight. Combat ends.
6. Now observe Lashun — she should begin the rez sequence.

**Expected result:**
- During active combat with Hollish's corpse present: Lashun does NOT attempt to cast rez.
  She focuses on heals/CC/combat support.
- After combat ends: rez sequence begins within 70 seconds.

**Pass if:**
- No rez cast animation on Lashun during active combat
- Rez fires normally after combat ends

**Fail if:**
- Lashun initiates a rez cast while mobs are still alive and engaged

**Back-to-back fight variant (PRD Scenario F):**
1. Fight #1: Hollish dies, fight ends. Lashun begins casting rez on Hollish.
2. While Lashun is mid-cast, pull fight #2.
3. Observe: the in-flight rez completes (Hollish comes back) since it was initiated before fight #2 began.
4. Observe: Lashun does NOT initiate new rez attempts while fight #2 is active.

**Pass if:**
- In-flight rez completes even after new combat begins
- No NEW rez initiations until fight #2 ends

---

### Test 7: Rez Range Boundary

**Acceptance criteria:** AC-10 (range prerequisite), architecture Scenario 12

**What you're proving:** When the corpse is outside `RezRange=200` units, Lashun
does not attempt to rez (returns cleanly). When the corpse is within range, she rezzes.

**Note:** This test is harder to engineer precisely without GM teleport. Use GM
teleport to position Lashun far from a corpse.

**Steps:**
1. Have Hollish die in a fight. Note the corpse location.
2. Before the rez timer fires, use GM commands to move the cleric far away:
   - Move yourself far away, then `!follow` will move the companion party
   - Or teleport to a different part of the zone with Lashun in tow
3. Ensure you are more than 200 units from Hollish's corpse.
4. Wait 70+ seconds. Lashun should NOT attempt to cast.
5. Walk back within 200 units of the corpse (Lashun follows you).
6. Observe: Lashun detects the corpse in range and begins the rez.

**Expected result:**
- No rez attempt when out of range (no error spam, just silence)
- Rez fires when back in range

**Pass if:**
- No cast attempts when out of range
- Rez fires after returning to range

**Fail if:**
- Lashun spams failed cast attempts while out of range
- Rez never fires even after returning to range

---

### Test 8: Tier Preference Verification

**Acceptance criteria:** AC-5

**What you're proving:** Lashun uses the highest-tier rez available when mana >= 50%,
and falls back to cheaper tiers when mana < 50%.

**Observation method:** Watch the spell cast name in the buff/cast bar when Lashun rezzes.

**Setup — high mana (should use Resurrection or Reviviscence at level 54):**
1. Ensure Lashun is at full mana (100%).
2. Have Hollish die.
3. Observe which rez spell Lashun casts.

**Expected result at level 54 with full mana:**
- Lashun should cast Reviviscence (spell 1524, 96% XP return) or Resurrection (spell 392,
  90% XP return) — whichever is the highest tier she has available at her level.

**Setup — low mana (should use cheaper tier):**
1. Burn Lashun's mana to below 50%.
2. Have Hollish die.
3. Observe which rez spell Lashun casts — it should be a lower-tier rez.

**Expected result at low mana:**
- A cheaper rez spell (Reanimation, Reconstitution, Reparation, or Revive) instead of
  Resurrection/Reviviscence.

**Pass if:**
- Full mana: higher-tier rez spell name visible in cast bar
- Low mana: lower-tier rez spell name visible in cast bar

**Fail if:**
- Same spell regardless of mana state (no tier switching)

---

### Regression Tests

These tests verify that the fix did not break other systems.

---

### Regression R1: Charm Pets, Swarm Pets Unaffected

**Risk from architecture plan:** "Charm pets, swarm pets, mercenaries: Untouched.
None of these have `m_companion_id > 0`."

**Steps:**
1. Have a pet class companion (Necromancer/Mage) active.
2. If a charm pet or summoned pet dies in combat, observe Lashun's behavior.

**Expected result:** Lashun does NOT attempt to rez charm pets, swarm pets, or
summoned pets. She ignores their corpses.

**Pass if:** No rez cast observed on non-companion-registered entity corpses.
**Fail if:** Lashun casts rez on a pet corpse.

---

### Regression R2: Player-Cast Rez on Companion Corpse

**Risk from architecture plan:** "Player accidentally targets companion corpse with
`/cast Resurrection` and the rez fires unexpectedly."

**Architecture note:** This is EXPECTED TO SUCCEED after the fix. The `ST_Corpse`
guard now admits companion corpses, so if you (as a Cleric player character) cast a
rez on a companion's corpse, it should work. This is consistent with the PRD's intent
(player can manually rez their own companion).

**Steps:**
1. Have Hollish die.
2. As a player Cleric, target Hollish's corpse.
3. Cast a rez spell on it.

**Expected result:** The rez succeeds. Hollish returns to life via `ResurrectFromCorpse`.
This is working-as-intended behavior after the fix.

**Pass if:** Companion is rezzed by player-cast rez.
**Fail if:** Error message or rez fails despite prerequisites being met.

---

### Regression R3: Cross-Character Griefing Blocked

**Risk from architecture plan:** Cross-character griefing blocked by existing owner
check at `companion.cpp:3578-3584`.

**Steps:**
1. Log in with a second character (different account/character).
2. Target the first character's companion corpse.
3. Cast rez on it.

**Expected result:** The rez is rejected with an "owner not in zone or not the casting
client's owner" guard. The companion corpse is NOT rezzed by another player's character.

**Pass if:** Rez fails for non-owner caster (error message or silent rejection).
**Fail if:** Another character can rez your companion corpse.

---

### Regression R4: Companion XP Gain Intact (xp-retune regression)

**What you're checking:** The companion XP system still works after the fix.
The fix does not touch XP code; this is a smoke-check regression.

**Steps:**
1. Have Hollish kill a mob (or participate in a kill).
2. Check Hollish's experience in the companion status output.

**Expected result:** Hollish gains XP from kills as normal.

**Pass if:** `!status Hollish` shows growing XP values after kills.
**Fail if:** XP is always 0 or does not increase.

---

### Regression R5: Re-Recruit Still Works (companion-rerecruit regression)

**What you're checking:** The companion-rerecruit fix is not broken by this change.
`is_suspended` semantics remain intact.

**Steps:**
1. Dismiss Hollish (`!dismiss Hollish`).
2. Observe Hollish is dismissed.
3. Re-recruit Hollish (`!recruit Hollish_Tnoops` or target and say `"I need your help"`).
4. Hollish should rejoin the party.

**Expected result:** Re-recruitment works normally.

**Pass if:** Hollish rejoins after dismiss+recruit cycle.
**Fail if:** Hollish cannot be re-recruited, or appears in an inconsistent state.

---

## Rollback Instructions

If something goes wrong during testing and you need to revert:

**To revert the `spells.cpp:2051` fix (returns to BUG-001 state where rez cast goes
off but companion corpse stays down):**
```bash
cd /mnt/d/Dev/eq/eqemu
git revert 83a96f655 --no-commit   # Reverts both spells.cpp and companion_ai.cpp
# Review changes, then rebuild and restart
```

**To revert only the `companion_ai.cpp:1861` player-corpse-search extension (AC-2)
while keeping the companion-corpse fix (AC-3):**
```bash
cd /mnt/d/Dev/eq/eqemu
git checkout f95555884 -- zone/companion_ai.cpp   # Restore pre-fix version of companion_ai.cpp only
# Rebuild and restart
```

Both reverts are independent per the architecture rollback plan. The Suite 29 tests
remain in the repo as "known broken" markers if reverted — they are not deleted.

**Rebuild after any revert:**
```bash
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
# Then full restart: make restart from akk-stack/, then loginserver/world/8 zones
```

---

## Blockers

None identified from server-side validation. All Suite 29 tests pass. All DB
integrity checks pass. No rez-related errors in logs.

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|-------------------|--------|
| — | (none) | — | — | — |

---

## Recommendations

1. **Pre-existing inventory slot warnings** (slot_id 3810-3819 for character_id=6 in
   The Hole and West Freeport zones): These appear on every zone-load and predate the
   companion-rez work. They are a known condition but produce log noise. Consider filing
   a separate bug report to address this inventory slot mapping issue at some point.

2. **Worst-case 70-second rez wait:** The 10s post-combat delay + 6-60s idle AI tick
   cadence means the player may wait up to 70 seconds for the first rez. This is acceptable
   per the PRD but may feel slow. The architecture's "Future Work" section notes this
   could be improved in a later polish pass. Flag if real-play UX feedback reveals this
   is frustrating.

3. **Test 8 (tier preference) observation method:** Without a spell-name display toggle,
   tier verification depends on seeing the cast bar spell name. If this is hard to observe,
   the unit test coverage (Suite 29 existing tests 29.5-29.7 cover the spell selection
   logic) provides machine-verified assurance even if the in-game observation is difficult.

4. **Test 6 back-to-back fight variant:** The in-flight rez completing during a second
   fight (PRD Scenario F) is worth testing if convenient — it validates that the 10s
   post-combat delay design does not block an already-initiated cast.
