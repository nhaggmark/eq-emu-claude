# Raid Scaling Phase 5a (Luclin non-VT) — In-Game Testing Guide

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-22
> **Prerequisite:** Server-side validation PASS confirmed in `luclin-a-server-validation.md`
> **Sessions listed in priority order** — Session 1 is the most critical and should be
> done first.

---

## Quick Reference

| GM Command | Effect |
|-----------|--------|
| `#zone [zoneshort]` | Zone to a zone |
| `#goto [x] [y] [z]` | Teleport to coordinates |
| `#level 65` | Set character to level 65 |
| `#spawn [npcid]` | Spawn NPC at your location |
| `#kill` | Kill targeted NPC |
| `#repop` | Repop all NPCs in zone |
| `#reloadquests` | Hot-reload quest scripts |
| `#showstats` | Show targeted NPC stats |
| `#findnpc [name]` | Find NPC in current zone |

---

## Session 1: Touch of Vinitras Cache Flush Verification (HIGHEST PRIORITY)

**What this tests:** Confirms the full-stack restart successfully flushed the
`npc_spells_entries` spell list 196 cache. This is the single most important in-game
check — if Touch of Vinitras is still firing on Vyzh`dra the Exiled or Banished after
the restart, the zone process did not load the updated spell list.

**Prerequisite:** Character level 65. Companion set up. Zone into akheva.

**Setup:**
```
#zone akheva
```

Vyzh`dra the Exiled (162232) and Vyzh`dra the Banished (162214) are script-spawned
by `#cursed_controller.pl`. They are not standing spawns. You need to progress the
Vyzh`dra chain to encounter them:

- The chain starts by killing the pre-chain mobs that trigger the cursed_controller.
  Per `luclin-chains.md` the chain order is: rune-covered serpent (162253) → glyph-
  covered serpent (162261) → Banished or Exiled appear.
- Alternatively, use `#spawn 162232` to spawn Vyzh`dra the Exiled directly for a quick
  spell-cast test, then kill it.

**Steps:**
1. `#zone akheva`
2. `#level 65` (ensure you can survive the test pull)
3. `#spawn 162232` — spawn Vyzh`dra the Exiled at your location
4. Target Vyzh`dra the Exiled and check `#showstats` — confirm HP at 70,000
5. Engage combat and watch your hit points carefully for approximately 120 seconds
6. If Touch of Vinitras is still in the spell list, you will receive a ~20,000 HP hit
   with a debuff from spell 2859 — this would be a critical failure

**Pass if:** No -20,000 HP hit from "Touch of Vinitras" during the 120-second engagement.
Normal melee and Pyrokinetic Hallucinations debuffs are expected.

**Fail if:** You see a "Touch of Vinitras" message or receive an unexplained ~20,000 HP
drop in a single tick. If this happens:

1. Do NOT proceed with other sessions
2. Dispatch infra-expert to perform a targeted akheva zone-process restart
3. After restart, re-run this session

**GM commands for cleanup:**
- `#kill` — kill the spawned Vyzh`dra after test
- `#repop` — repop zone if needed

---

## Session 2: Emperor Ssraeshza Full Encounter

**What this tests:** Emperor Ssraeshza encounter including Blood phase, Emperor HP at
120k, Leash 290 mechanic, and the new 22-24h post-kill respawn cycle.

**Prerequisite:** Prepared 1+5 companion group. Character level 65. Understand the
3-phase encounter: Blood phase → Emperor engage → post-mortem wraiths.

**Background:** Emperor Ssraeshza is script-spawned via `#EmpCycle.pl`. The cycle state
uses `qglobals`. If `qglobal.Emperor` is not set, Blood spawns. You must kill Blood
of Ssraeshza (162189, 60k HP) first to unlock Emperor.

**Steps:**
1. `#zone ssratemple`
2. Navigate to Emperor's chamber (central throne area)
3. Engage Blood of Ssraeshza first — it should be at 60,000 HP
4. Kill Blood of Ssraeshza — this triggers the Emperor to become targetable after
   ~150 seconds (`$EmpPrepTime`)
5. Engage Emperor Ssraeshza — confirm HP at 120,000 with `#showstats`
6. Watch for the Leash 290 mechanic — if you run beyond ~290 units from Emperor,
   he should leash back to his spawn point (special_abilities `32,1,290`)
7. Defeat Emperor Ssraeshza
8. Note the time of kill for respawn verification (see below)
9. Watch for 5 shissar_wraith spawns post-mortem — these should be small HP (~50 HP
   each at L59) and should not wipe an exhausted group

**Pass if:**
- Blood of Ssraeshza has 60,000 HP
- Emperor has 120,000 HP and is defeatable by a 1+5 group
- Leash mechanic fires if you exceed ~290 units distance
- Post-mortem wraiths spawn (5x) and are trivial to dispatch

**Fail if:**
- Emperor or Blood HP appears unchanged at ~1M
- Emperor does not spawn after Blood kill (cycle logic broken)
- Leash fires at wrong distance or does not fire at all

**Emperor respawn cycle verification (22-24h):**
After killing Emperor, the qglobal `Emperor` is set and `$EmpRepopTime` governs when
he respawns. The new value is `int(rand(7200)) + 79200` = 22-24h range. You cannot
verify this in a single session, but you can confirm the Perl file is set correctly
(server-side validation confirms this already). If you want to verify in-game timing,
check qglobals via:
```sql
SELECT * FROM data_buckets WHERE key_name LIKE '%Emperor%';
```

**GM commands:**
- `#findnpc Blood_of_Ssraeshza` — locate Blood in zone
- `#findnpc Emperor_Ssraeshza` — locate Emperor after Blood kill
- `#showstats` — confirm HP values on targeted NPC

---

## Session 3: Lord Inquisitor Seru — MR Wall Test

**What this tests:** Lord Inquisitor Seru HP at 120,000 with MR=800 wall preserved.
This is the "caster death zone" signature mechanic (same design philosophy as Vyemm
MR=1000 in Phase 4b). Caster-heavy companion comps will find spells resist-capped.

**Prerequisite:** Character level 65. Mixed melee/caster companion group recommended.
Have at least 2-3 melee companions for primary DPS.

**Setup:**
```
#zone sseru
```

Lord Inquisitor Seru (159691) is spawn2-backed at 86,400s respawn (confirmed updated
from 259,200s). He is a standing spawn.

**Steps:**
1. `#zone sseru`
2. `#findnpc Lord_Inquisitor_Seru` — locate him in zone
3. Target Seru and confirm `#showstats` shows HP ~120,000 and MR=800
4. Engage with a caster companion — observe spell resist rates (expect most spells to
   resist against MR=800)
5. Switch to melee companions for primary DPS
6. Defeat Lord Seru — confirm the fight is challenging but completable by a 1+5 group
   with melee-primary DPS

**Pass if:**
- Lord Seru has 120,000 HP
- MR=800 causes frequent caster resists
- Fight is winnable with melee-focused comp

**Fail if:**
- HP appears unchanged at ~1.2M
- MR appears different from 800 (would indicate a regression)

**Note for caster-heavy players:** If your companion setup is caster-heavy, consider
recruiting a warrior or ranger companion before this fight. Melee DPS is the intended
path per Decision #11.

---

## Session 4: Vyzh`dra Chain — Full Encounter

**What this tests:** The complete Vyzh`dra multi-form chain orchestrated by
`#cursed_controller.pl`. Verifies that chain progression works after HP cuts and
Touch of Vinitras removal. The chain order: rune serpent → glyph serpent → Banished/
Exiled intermediate forms → Vyzh`dra the Cursed (final form, 90k HP, list 197/clean).

**Prerequisite:** Session 1 (Touch of Vinitras cache flush) must PASS first. Level 65.

**Steps:**
1. `#zone akheva`
2. Locate and engage a_rune_covered_serpent (162253) — confirm HP at 60,000
3. Kill rune serpent — watch for chain progression signal (glyph serpent or intermediate
   form should spawn per `#cursed_controller.pl` logic)
4. Engage a_glyph_covered_serpent (162261) — confirm HP at 70,000
5. Kill glyph serpent — watch for Vyzh`dra the Banished (162214) or Exiled (162232)
   to spawn
6. Engage Banished (65,000 HP) — confirm no Touch of Vinitras fires (critical)
7. Kill Banished — watch for chain to advance toward Exiled or Cursed
8. Engage Exiled (70,000 HP) — confirm no Touch of Vinitras fires
9. Kill Exiled — watch for Vyzh`dra the Cursed (162206) to spawn
10. Engage and defeat the Cursed (90,000 HP, list 197)

**Pass if:**
- Each chain form spawns at the correct HP target
- No Touch of Vinitras fires on Banished or Exiled
- Chain advances through all forms to the Cursed
- Cursed is defeatable at 90,000 HP with list 197 spells only

**Fail if:**
- Touch of Vinitras fires on Banished or Exiled (Session 1 fail re-trigger)
- Chain does not advance after a kill (controller logic broken by HP cut — unlikely per
  architecture isolation proof but flag if it happens)
- Any intermediate form HP is wrong

---

## Session 5: Khati Sha the Twisted — 2-Phase Acrylia Event

**What this tests:** Khati Sha's HP at 90,000 with damage cap 750. The event has a
Phase 2 trigger at y=-545 (player crosses into the inner chamber). Also tests
A_Spiritual_Arcanist (154153) at 40,000 HP — the wrong-choice penalty mob spawned if
the player fails the Phase 2 dialogue choice.

**Prerequisite:** Level 65. Acrylia Caverns scripted event knowledge. Khati Sha is
script-spawned via `acrylia/Khati_Sha_the_Twisted.lua` — she is at L68 (3 levels above
the player cap).

**Steps:**
1. `#zone acrylia`
2. Navigate to Khati Sha's lair (inner Acrylia zone, past the grimling cave section)
3. Engage Khati Sha the Twisted — confirm HP at 90,000 and maxdmg at 750 via `#showstats`
4. Fight Phase 1 (outer chamber)
5. Cross y=-545 into the inner chamber — this should trigger Phase 2 if the script
   is functioning
6. Continue the fight to completion

**A_Spiritual_Arcanist wrong-choice path:**
7. On a second attempt (or use `#reloadquests` to reset the event), deliberately
   choose the wrong dialogue option during the Phase 2 event
8. A_Spiritual_Arcanist (154153) should spawn — confirm HP at 40,000 and that it's
   a manageable fight at that HP level

**Pass if:**
- Khati Sha HP at 90,000, maxdmg at 750
- Phase 2 trigger fires on y=-545 crossing
- A_Spiritual_Arcanist spawns at 40,000 HP on wrong-choice path and is tractable
- Khati Sha at L68 with 90k HP is a challenging but completable fight for level 65

**Fail if:**
- HP appears unchanged at ~475k or ~150k
- Phase 2 trigger fails (Lua event broken by HP change — architecture says HP-independent
  but worth confirming)
- Arcanist spawns at wrong HP

---

## Session 6: Shei Vinitras — Dual Form + Touch of Vinitras on REAL Form

**What this tests:** The Shei Vinitras dual-form mechanic (Decision #60). The MERCHANT
form (179157, 60k HP) triggers a spawn-swap `event_death_complete` to spawn the REAL
form (179032, 85k HP). Critically, the REAL form's list 179 still contains Touch of
Vinitras — this is an INTENDED signature mechanic. This session confirms both forms
have correct HP AND that the REAL form does still cast Touch of Vinitras.

**Prerequisite:** Level 65. Akheva Ruins. Full group/companion prep for a challenging
fight — the REAL Shei Vinitras at 85k HP WITH Touch of Vinitras is the intended
encounter difficulty.

**Steps:**
1. `#zone akheva`
2. Locate Shei Vinitras MERCHANT form (179157) — she is a standing spawn
3. Confirm `#showstats` shows HP at 60,000 (the MERCHANT form)
4. Engage and kill the MERCHANT form
5. Watch for the REAL Shei Vinitras (179032) to spawn via `event_death_complete` trigger
6. Target the REAL form — confirm `#showstats` shows HP at 85,000, maxdmg at 600
7. Engage the REAL form — watch for Touch of Vinitras to fire (spell 2859 on list 179)
8. If Touch of Vinitras fires: this is EXPECTED and correct (Decision #60 preserved it)
9. Manage the fight with Touch of Vinitras in play — challenge is intended

**Pass if:**
- MERCHANT form at 60,000 HP
- REAL form spawns after MERCHANT death
- REAL form at 85,000 HP, maxdmg 600
- Touch of Vinitras fires on REAL form (this is correct behavior, NOT a bug)
- REAL form is a hard but completable fight with Touch of Vinitras present

**Fail if:**
- Either form HP appears wrong
- Spawn-swap does not fire after MERCHANT death (Lua event broken)
- Touch of Vinitras does NOT fire on REAL form (would indicate list 179 was accidentally
  modified — check npc_spells_entries where npc_spells_id=179)

---

## Session 7: Akheva Elite-Named — Sheleric Vis and Xaui Tatrua (Q51 Override)

**What this tests:** The Q51=B user override — Akheva elite-named scaled for scope
consistency at shallow HP targets. These mobs spawn at 5400s (1.5h) natural respawn
which is preserved. They are named-tier mobs (not full raid-tier), so the fight should
feel like a tough named encounter, not a raid boss.

**Steps:**
1. `#zone akheva`
2. `#findnpc Sheleric_Vis` — locate Sheleric Vis (179133 or 179046 variant)
3. Engage Sheleric Vis 179133 (L61) — confirm HP at 35,000, maxdmg at 550
4. Engage Sheleric Vis variant 179046 (L62) — confirm HP at 30,000
5. `#findnpc Xaui_Tatrua` — locate Xaui Tatrua (179044)
6. Engage Xaui Tatrua (L60) — confirm HP at 30,000

**Pass if:**
- Sheleric Vis 179133 at 35,000 HP, maxdmg 550 — tough named fight, completable
- Sheleric Vis 179046 at 30,000 HP — softer variant
- Xaui Tatrua 179044 at 30,000 HP

**Fail if:**
- Any HP appears unchanged from pre-scale values (116,000 / 70,000 / 70,000)

---

## Session 8: Umbral Plains — Doomshade and the Umbral Cluster

**What this tests:** The three Umbral Plains bosses. Doomshade (176088) was audit-missed
and is script-spawned from `#Doomshade.lua`. Zelnithak (176089) and Rumblecrush (176002)
are standing spawns.

**Steps:**
1. `#zone umbral`
2. `#findnpc Zelnithak` — locate Zelnithak (176089)
3. Engage Zelnithak — confirm HP at 60,000
4. `#findnpc Rumblecrush` — locate Rumblecrush (176002)
5. Engage Rumblecrush — confirm HP at 45,000, maxdmg at 600
6. For Doomshade: he is script-spawned via `#Doomshade.lua`. Either progress the
   trigger that spawns him, or use `#spawn 176088` to spawn him at your location
7. Engage Doomshade — confirm HP at 70,000

**Pass if:**
- Zelnithak at 60,000 HP
- Rumblecrush at 45,000 HP, maxdmg 600 (was 720 — confirms no one-shot risk)
- Doomshade at 70,000 HP

**Fail if:**
- Any HP appears unchanged from pre-scale values (251k, 150k, 350k)

---

## Session 9: Thought Horror Overfiend — The Deep

**What this tests:** Thought Horror Overfiend (164078) at 90,000 HP. This is the single
boss in The Deep and a key Luclin raid milestone for cross-zone VT key progression.

**Steps:**
1. `#zone thedeep`
2. `#findnpc Thought_Horror_Overfiend` — locate the boss
3. Engage — confirm HP at 90,000 via `#showstats`
4. Defeat — confirm it's completable for a 1+5 group at level 65

**Pass if:** HP at 90,000 and defeatable.
**Fail if:** HP unchanged at ~807,000.

---

## Session 10: Grieg's End — Servitor of Luclin + Praetorian Myral + Variant

**What this tests:** The Grieg's End cluster. Note Grieg Veneficus MAIN (163075) is
script-spawned — test the variant (163231) which is spawn2-backed and had the most
dramatic respawn update (561,600s → 86,400s).

**Steps:**
1. `#zone griegsend`
2. `#findnpc Servitor_of_Luclin` — locate Servitor (163013)
3. Engage Servitor — confirm HP at 40,000
4. `#findnpc Praetorian_Myral` — locate Praetorian Myral (163078)
5. Engage Myral — confirm HP at 35,000
6. `#findnpc Grieg_Veneficus` — locate the variant (163231) — confirm HP still at
   162,500 (intentionally unchanged — already scaled-tier) and that it feels like
   a tough endgame named encounter, not a trivial mob

**Pass if:**
- Servitor at 40,000 HP ("easiest Luclin raid boss" — should be the most approachable)
- Praetorian Myral at 35,000 HP
- Grieg variant at 162,500 HP (UNCHANGED — confirm the HP cut to 80k only applies to
  the main 163075, not the variant 163231)

**Fail if:**
- Servitor or Myral HP appears unchanged from ~120k / ~95k
- Grieg variant HP was accidentally changed to 80,000 (would indicate wrong ID targeted)

---

## Rollback Instructions

If a critical failure is discovered in-game that requires reverting Phase 5a changes:

### Database rollback
```sql
-- Run from docker exec -i akk-stack-mariadb-1 mysql -ueqemu -p'...' peq
-- File: data-expert/sql/15-luclin-a-rollback.sql
SOURCE /path/to/15-luclin-a-rollback.sql;
```

The rollback script restores all three tables from the backup tables:
- `npc_types` — JOIN-UPDATE to restore HP/damage from `npc_types_backup_raid_scaling_luclin_a`
- `spawn2` — JOIN-UPDATE to restore respawntime from `spawn2_backup_raid_scaling_luclin_a`
- `npc_spells_entries` — INSERT IGNORE to re-add spell 2859 row to list 196

After rollback, issue `#reloadworld` and then a full-stack restart to flush the spell
list cache.

### Perl rollback
```bash
# View git history for #EmpCycle.pl
cd /mnt/d/Dev/eq/akk-stack
git log --oneline -- "server/quests/ssratemple/#EmpCycle.pl"
# Revert to pre-Q52 value
git checkout <pre-edit-commit> -- "server/quests/ssratemple/#EmpCycle.pl"
```

Then `#reloadquests` in ssratemple zone (or full-stack restart).

---

## Edge Cases to Watch

1. **Emperor 30-min engagement window:** The Blood phase triggers a 30-minute window
   to engage Emperor. This is preserved by Decision #11. A prepared group should be
   ready to engage quickly after Blood dies and the 150-second prep timer expires.

2. **Emperor 40-min combat timer:** After Emperor engages, there is a 40-minute
   hard timer. At 120,000 HP with 1+5 DPS (estimated 1500-2500 DPS), the fight clears
   in well under 2 minutes — the 40-min timer is not a practical constraint.

3. **Emperor failure cycle (Blood Golem):** If the Blood phase fails, the Ssraeshzian
   Blood Golem (162064, 60,000 HP) spawns as a failure-retry gate. Test this path
   if time permits to confirm the cycle recovers correctly.

4. **Khati Sha L68 vs. player cap L65:** Khati Sha sits 3 levels above the player cap.
   This is intentional (era-accurate). The damage cap at 750 (was 1004) prevents
   one-shot risk against a L65 companion. The level disparity makes the fight harder
   through miss chances and resist rates but does not require special handling.

5. **Lord Seru MR=800 caster friction:** MR=800 will soft-block all but the highest
   magic resistance roll spells. This is intentional. If your companion group relies
   entirely on casters, consider adding a melee companion before fighting Seru.

6. **Shei Vinitras REAL Touch of Vinitras:** Touch of Vinitras remains active on Shei
   Vinitras REAL (list 179). This is Decision #60 — it is a retained signature mechanic.
   The fight is intended to be hard. Plan for a 120-second cooldown between Touch of
   Vinitras casts.

7. **Vyzh`dra chain reset:** If the chain gets into a broken state mid-run (e.g., a
   form dies but the next form doesn't spawn), use `#repop` to reset the zone and start
   fresh. The `#cursed_controller.pl` state is qglobal-driven, not persistent after a
   repop.
