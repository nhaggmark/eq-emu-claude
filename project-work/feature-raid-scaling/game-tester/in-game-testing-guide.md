# Raid Scaling Phase 2 — In-Game Testing Guide

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-22
> **For:** User playing 1 player + 5 companions (Titanium client)

---

## Overview

This guide covers every major area changed in Phase 2 Classic raid scaling.
You do NOT need to run everything in one session. Each zone section is
independent — do them in whatever order suits you. Mark each test PASS/FAIL
as you go and report back.

### What Changed (Quick Reference)

| Zone | What to Expect |
|------|---------------|
| Plane of Fear (fearplane) | Bosses much more manageable; dracoliche/CT severely reduced |
| Plane of Hate (hateplaneb) | Innoruuk is a real fight but beatable; adds scaled |
| Plane of Sky (airplane) | Island 4-8 bosses no longer instakill; death-touch REMOVED |
| Nagafen's Lair (soldungb) | Nagafen is a 6-hour respawn, manageable HP |
| Permafrost (permafrost) | Vox is at same tier as Nagafen |
| Cazic Thule zone (cazicthule) | Event mobs around CT are scaled; CT himself is beatable |

### What Did NOT Change

- Trash mob difficulty in any of these zones
- Drop tables — kills are still loot pinatas
- Classic epic quest script logic — only NPC stats changed

---

## Prerequisites (GM Setup)

Before testing, ensure your character is at an appropriate level and has your
companion squad ready. These are raid-tier encounters — bring all 5 companions.

**Recommended level:** 65 (endgame-capable character)

**If you need to adjust level:**
```
#level 65
```

**Check your companion squad is full (5 companions):**
```
!status
```

**If you need to spawn a quick test NPC at your location:**
```
#spawn [npcid]
#kill
```

**Important for PoSky testing — confirm zone boot time after #reloadworld:**
All zone processes started at 20:42 on 2026-04-22 (after the death-touch DELETE
was applied). Any zone you enter should boot fresh from DB. If a PoSky boss
still casts Cazic Touch during testing, the zone's spell list cache is stale.
Report this immediately — infra-expert will need to run a full-stack restart.

---

## Session 1: Nagafen and Vox (Fastest, Best Starting Point)

These are the most accessible Classic raid bosses and the best first test
of "does the scaling feel right."

### Test N1: Lord Nagafen — Full Kill Attempt

**What we're validating:** HP cut from 32000 to 14400 (55% cut); respawn
now 6h; signature mechanics (summon, enrage) still fire; encounter is
completable with 1+5 party.

**Travel:**
```
#zone soldungb
```
Navigate to the Nagafen room (deepest part of Nagafen's Lair, lower Lavastorm).
Nagafen is a single stationary boss with fire breath.

**Steps:**
1. Zone into soldungb and navigate to Nagafen's chamber.
2. Note the current HP bar when you target him with `#showstats` or the
   standard target window. He should feel comparable to a tough named mob —
   not a trash mob, not an hour-long war.
3. Pull Nagafen with your party of 6.
4. Observe: does he summon players who run (should summon at low HP)? Does
   he enrage at the end? These mechanics should still fire.
5. Complete the kill.
6. Check loot — should be standard Nagafen drops (Nagafen's Fang, etc.).
7. Note the respawn indicator (or check `/who` status if the corpse gives a
   respawn message). Expected: 6 hours (21600s).

**Pass if:** Nagafen is killable in 1-3 attempts with 1+5 party; fight takes
5-15 minutes; summon and enrage mechanics still fire; loot drops normally.

**Fail if:** Nagafen one-shots the party, or the fight trivializes in under
2 minutes with no meaningful threat, or loot does not drop.

**Respawn sanity check:** After the kill, note the time. If you return in
~6 hours, Nagafen should have repopulated. You can also use:
```
#repop
```
to force a repop and confirm he respawns (useful for verifying the spawn2
row is working — though a forced repop ignores the timer).

---

### Test V1: Lady Vox — Full Kill Attempt

**What we're validating:** Same tier as Nagafen (14400 HP, 21600s respawn).

**Travel:**
```
#zone permafrost
```
Lady Vox is at the bottom of Permafrost Keep.

**Steps:**
1. Zone into permafrost and navigate to Vox's chamber.
2. Pull Vox with your party.
3. Complete the kill.
4. Check loot.

**Pass if:** Vox is completable at similar difficulty to Nagafen; loot drops.
**Fail if:** Same failure conditions as Nagafen.

**Note:** Vox and Nagafen should feel identical in difficulty — they have the
same HP target (14400) and same damage output. If one is significantly harder
than the other, report it.

---

## Session 2: Plane of Fear

Fear is the most complex Classic raid zone — multiple named bosses, a
dracoliche (Wizard epic), the CT-adjacent event mobs, and Cazic Thule himself.

### Test F1: Plane of Fear Named — Pull Two Bosses

**What we're validating:** Dread/Terror/Fright/Wraith/Tempest Reaver are
scaled (20000-21000 HP); feel "slightly harder than named mobs"; zone
remains playable.

**Travel:** Plane of Fear is accessed via a portal. The standard Classic-era
access is through the Fear gate in Feerrott:
```
#zone fearplane
```

**Steps:**
1. Zone into fearplane.
2. Target one of the standard PoFear named mobs — Dread, Terror, or Fright
   (the three amygdalans). They wander the zone.
3. Pull one with your party. Note the difficulty compared to overland named
   mobs you've fought.
4. Kill it. Check loot.
5. Pull a second named — ideally from a different type (e.g., Wraith of a
   Shissar or Tempest Reaver).

**Pass if:** Each boss falls in a manageable fight (5-10 minutes); feels
"slightly harder than a Velious named" rather than "walls of HP"; loot drops.
**Fail if:** Any boss trivializes instantly or requires more than 30 minutes.

---

### Test F2: a_dracoliche — Wizard Epic Path

**What we're validating:** dracoliche HP cut from 175000 to 40000 (77% cut);
maxdmg trimmed to 420 (was 595). Wizard epic chain is now completable.

**Steps:**
1. In fearplane, locate a_dracoliche (it patrols or can be triggered by
   Cleric epic events — if not immediately visible, wait or use `#findnpc dracoliche`).
2. Pull and kill the dracoliche.
3. Confirm loot drops — the dracoliche drops the Cleric epic component
   (Words of Cazic-Thule / Rune of Xorbb for Soulfire chain). Note whether
   the epic component drops.
4. Note fight duration — should be noticeably longer than standard named but
   NOT the wall it was at 175000 HP.

**Pass if:** dracoliche killable; epic loot component present in drops.
**Fail if:** dracoliche still feels like a wall (may indicate HP cut didn't
propagate to the zone cache — check `#showstats` for an HP estimate).

**Triggered spawn note:** dracoliche has a standard spawn point in fearplane
as well as a script-triggered path. If you need to force-spawn it:
```
#spawn 72090
```

---

### Test F3: Cazic Thule — Main Boss

**What we're validating:** CT HP cut from 451000 to 80000 (82% cut);
maxdmg trimmed to 450 (was 603); rampage effectively capped at 2 targets
via global rule (no per-NPC edit needed); encounter is doable but the
hardest Classic fight.

**Cazic Thule location:** His temple in the cazicthule zone (Lost Temple of
Cazic-Thule), not in fearplane. His zone is `cazicthule`.

**Steps:**
1. Zone into cazicthule:
   ```
   #zone cazicthule
   ```
2. Navigate to Cazic Thule's inner sanctum (deep in the temple).
3. Before engaging CT, you may encounter the Avatar event mobs (Avatar of
   Dread, Avatar of Fright, Avatar of Terror, a_boiling_ooze, guards,
   Spinechill Spiders, Gorgons, Shiverbacks, Amygdalan Knights). These are
   all scaled (18000-35000 HP). Expect a moderately challenging series of
   pulls to clear to CT.
4. Engage Cazic Thule himself.
5. Observe: rampage should hit at most 2 targets (global cap). He should
   still feel threatening but not 10-target rampaging.
6. Complete the kill.
7. Check loot.

**Pass if:** CT is killable with deliberate play; event mobs around him feel
appropriately harder than trash but not brick walls; rampage does not
simultaneously hit more than 2-3 targets; loot drops normally.

**Fail if:** CT is trivially easy (80000 HP is intentionally the hardest
Classic boss — should require your full party and some preparation); rampage
is still hitting 5+ targets (would indicate global rule regressed, check
`#reloadrules`).

**Respawn note:** CT respawns on a 12h timer (43200s) — he's the only Classic
boss with a 12h respawn vs. 6h for others.

---

### Test F4: Q13 Plane of Fear Triggered Adds

**What we're validating:** Ireblind Imp (72069, 35000 HP), Enraged Golem
(72106, 40000 HP), Enraged Imp (72108, 18000 HP) are all scaled.

**Steps:**
1. While in fearplane, trigger any of these event mobs if they spawn
   during normal content clearing. Ireblind Imp and Enraged Imp are
   zone-event triggered. Enraged Golem (Wizard epic) is triggered by
   giving items to `a_broken_golem` (NPC 72074).
2. You do not need to specifically test all three — if you encounter them
   during normal fearplane clearing, note whether they feel proportional.

**Pass if:** Enraged Golem (the hardest at 40000 HP) is killable with a
focused effort; Enraged Imp at 18000 is the easiest of the three.

**Note:** If doing the Wizard epic, specifically killing the Enraged Golem
is required to test epic chain completion.

---

## Session 3: Plane of Sky — CRITICAL (Death-Touch Removal)

This is the most important in-game test. Three PoSky bosses (Spiroc Lord
island 4, Bazzt Zzzt island 6, Keeper of Souls island 8) previously cast
spell 982 "Cazic Touch" — an instant kill with -100,000 HP damage. This
spell has been removed from their spell lists. If it still fires, infra-expert
must do a full server restart to flush the zone spell list cache.

**Travel:** Plane of Sky is accessed via boat in East Karana, or directly:
```
#zone airplane
```

### Test S1: Spiroc Lord — Island 4, No Death-Touch

**What we're validating:** Spiroc Lord (71012, 22000 HP) no longer insta-
kills; fight is now a survivable HP/damage encounter.

**Steps:**
1. Zone into airplane and progress through Islands 1-3 (or teleport to the
   relevant island if you have GM access).
2. Island 4 contains the Spiroc Lord. Engage him.
3. During the fight, watch closely for any message reading "Cazic Touch"
   or any instant-kill mechanic. There should be NONE. His remaining spell
   (spell 988 "Greater Spiroc Thunder") is a survivable AE attack — this
   should still fire normally.
4. Kill the Spiroc Lord.

**Pass if:** Spiroc Lord fight plays out as a normal HP encounter; no instant
kill; Greater Spiroc Thunder AE fires but is survivable.

**Fail if:** Any party member is instantly killed from full HP by a spell
named "Cazic Touch" or similar. This is a critical failure — stop testing
immediately, report to orchestrator, infra-expert must do full restart.

**GM teleport to Island 4 if needed:**
```
#goto airplane [x] [y] [z]
```
(You'll need to know the island 4 coordinates — zone into airplane and walk
the island chain, or use `#goto` with known PoSky island coordinates.)

---

### Test S2: Bazzt Zzzt — Island 6, No Death-Touch

**What we're validating:** Bazzt Zzzt (71072, 22000 HP, maxdmg trimmed to
700 from 941) no longer insta-kills.

**Steps:**
1. Progress to Island 6 in Plane of Sky.
2. Engage Bazzt Zzzt.
3. Watch for death-touch. His remaining spell (spell 897 "Rotting Flesh")
   is a DOT — this should still fire normally.
4. Kill Bazzt Zzzt.

**Pass if:** No instant kill; Rotting Flesh DOT fires; fight is completable.
**Fail if:** Instant kill occurs. Critical failure, same as S1.

---

### Test S3: Keeper of Souls — Island 8, No Death-Touch

**What we're validating:** Keeper of Souls (71075, 22000 HP) no longer
insta-kills.

**Steps:**
1. Progress to Island 8 (the final Keeper of Souls island).
2. Engage the Keeper of Souls.
3. Watch for death-touch. His remaining spell (spell 899 "Whirl") is a
   crowd-control throw — this should still fire.
4. Kill the Keeper.

**Pass if:** No instant kill; Whirl spell may fling a party member but
they survive; fight is completable.
**Fail if:** Instant kill occurs. Critical failure, report immediately.

**Epic implications:** If these three tests all pass, the following class
epics become viable:
- Necromancer epic (Keeper of Souls progression)
- Ranger epic (requires essence tamer on Island 3 — spell list unchanged,
  throw mechanic is survivable)
- Magician epic (Island 4 progression via Spiroc Lord)
- Warrior epic (Island 6 or 8 progression)

---

### Test S4: essence tamer — Ranger Epic Check

**What we're validating:** essence tamer (71071, 11500 HP, NOT scaled —
already named-tier) still uses spell 303 "Whirl till you hurl" (throw,
not death touch). Ranger can obtain the Swirling Sphere from this encounter.

**Steps:**
1. Locate the essence tamer in Plane of Sky (Island 3 or nearby per
   Ranger epic route).
2. Engage it.
3. The "Whirl till you hurl" spell should throw a party member into the air
   — they will take fall damage, not instant-kill. This is survivable with
   reasonable HP. No change was made to this spell list; this test confirms
   the pre-existing behavior continues as expected.

**Pass if:** essence tamer uses throw mechanic; player takes fall damage;
survives with reasonable HP; Swirling Sphere epic item drops on kill.
**Fail if:** Player is instantly killed from throw. This would be a different
bug (fall damage too high) unrelated to Phase 2.

---

### Test S5: Other PoSky Named Scaling

**What we're validating:** Noble Dojorn (22000 HP), Gorgalosk (20000 HP),
Eye of Veeshan (25600 HP), Thunder Spirit Princess (17000 HP), Overseer of
Air (22000 HP), Protector of Sky (17000 HP), Hand of Veeshan (22000 HP),
Sister of the Spire (12000 HP).

You do not need to kill all of them in one session. Pick 2-3 during your
PoSky island run.

**Steps:**
1. Progress through the island chain during S1-S4 testing.
2. Pull 2-3 of the above named bosses.
3. Confirm they are noticably harder than island trash but not brick walls.

**Pass if:** Each named feels proportional to its HP tier — Sister of the
Spire (12000) should be the easiest, Eye of Veeshan (25600) the hardest
of this set.
**Fail if:** Any named feels identical to trash (may indicate HP update
didn't propagate — use `#showstats` to check).

---

## Session 4: Plane of Hate (hateplaneb)

The live Plane of Hate on this server is the revamp layout (`hateplaneb`),
reached via the teleport door in Oasis of Marr. The classic `hateplane`
layout is dormant (accessible only from PoP, which is out of era).

### Test H1: hateplaneb Named — Pull 1-2 Bosses

**What we're validating:** hateplaneb named bosses (20000-22000 HP range)
feel appropriate — harder than overland named, easier than the top endgame.

**Travel:** Oasis of Marr → Plane of Hate teleport door.
```
#zone oasis
```
Then take the PoHate portal (or direct zone if you know coordinates:
```
#zone hateplaneb
```).

**Steps:**
1. Zone into hateplaneb.
2. Pull one of the named bosses — Lord of Ire (20000 HP), Magi P'Tasa
   (20000 HP), or Deathrot Knight (22000 HP) are good test subjects.
3. Kill it. Check loot.
4. Pull a second if time allows.

**Pass if:** Bosses are challenging but completable; feel "slightly harder
than overland named"; loot drops.
**Fail if:** Any boss trivializes or remains a wall.

---

### Test H2: Innoruuk — End Boss

**What we're validating:** Innoruuk (186158, 60000 HP, maxdmg 500) is the
hardest hateplaneb fight; encounter is beatable with preparation; loot is
script-distributed (loottable_id=0, but event_loot script fires).

**Note:** Innoruuk in hateplaneb is script-triggered, not a standing spawn.
The DZ event progression must be completed to reach him. His adds (banshees,
Evangelist of Hate) are also scaled.

**Steps:**
1. Progress through the hateplaneb event sequence to reach Innoruuk.
2. The Evangelist of Hate (186198, 60000 HP, maxdmg 600) is a phase-boss
   you will encounter first — this should be a challenging but beatable fight.
3. Complete the event to trigger Innoruuk.
4. Engage Innoruuk. He has rampage (capped at 2 targets by global rule),
   AE damage, and summon mechanics.
5. After the kill, check loot — it is distributed by `event_loot` in the
   quest script, NOT from a loottable. You should see items drop normally.

**Pass if:** Innoruuk is beatable; fight feels like the hardest Classic encounter;
loot appears from event script; no instant kill mechanics.
**Fail if:** Innoruuk is trivially easy; OR loot does not drop (which would
indicate a quest script bug, not a Phase 2 issue — report separately).

---

## Session 5: Miscellaneous Classic Bosses

These are shorter spot-checks that can be done in any order.

### Test M1: Phinigel Autropos — Kedge Keep

**What we're validating:** Phinigel (64001, 13500 HP from 18000, 25% cut)
is a minor boss in an underwater zone; Cleric/Wizard/Necro epic component.

**Travel:**
```
#zone kedge
```

**Steps:**
1. Navigate to Phinigel's chamber in Kedge Keep (underwater zone — bring
   Enduring Breath or water breathing).
2. Kill Phinigel.
3. Confirm he drops his epic loot component (Phinigel's Eye).

**Pass if:** Phinigel killable; fight is easier than Nagafen (13500 HP vs
14400 HP — Phinigel is a lighter fight); Phinigel's Eye drops.

---

### Test M2: Guardian of the Seal — The Hole / Paineel Area

**What we're validating:** Guardian of the Seal (39115, 87000 HP from 124000,
30% cut); 12h respawn (mid-tier boss); SK epic path.

**Travel:**
```
#zone hole
```
The Guardian of the Seal is in The Hole zone near Paineel.

**Steps:**
1. Navigate to the Guardian of the Seal.
2. Engage and kill.
3. Confirm fight duration is appropriate for an 87000 HP boss (should be
   harder than standard PoFear named but nowhere near CT-tier).
4. Check loot.

**Pass if:** Guardian is beatable in 1-2 attempts; feels like a "mid-tier"
challenge commensurate with his 12h respawn.

---

### Test M3: Zordakalicus Ragefire — Lavastorm

**What we're validating:** Zordakalicus (91090, 26000 HP from 33000, 21%
cut) is a low-end raid encounter in Lavastorm; Magician/Wizard epic path.

**Travel:**
```
#zone lavastorm
```

**Steps:**
1. Locate Zordakalicus in Lavastorm Mountains.
2. Kill him.
3. Check loot.

**Pass if:** Zordakalicus is completable; feel is appropriate for a 26000 HP
encounter (harder than zone trash, softer than Nagafen).

---

## Respawn Timer Spot-Checks

You do not need to sit and wait. Record kill times and check back later.
Here is the expected respawn by tier:

| Boss | Respawn |
|------|---------|
| Most Classic bosses (Nagafen, Vox, PoFear named, Maestro, etc.) | 6h (21600s) |
| Cazic Thule | 12h (43200s) |
| Guardian of the Seal | 12h (43200s) |
| PoSky standing-spawn bosses (Spiroc Lord, Noble Dojorn, etc.) | 6h (21600s) |
| PoSky triggered-spawn bosses (Keeper of Souls, Bazzt Zzzt, etc.) | N/A (script spawned) |
| hateplaneb standing-spawn bosses | varies (900s DZ or 21600s depending on NPC) |

To verify respawn timers, kill a boss, note the time, and return after
the expected window. Alternatively, you can verify via DB query after any
kill and compare to the expected values above.

---

## Edge Case Tests (from Architecture Antagonistic Review)

### Test E1: Cazic Touch removal — No orphan cast attempt

**Risk from architecture:** After DELETE, Bazzt Zzzt's AI iterates its spell
list and finds nothing at that slot. Could cause any behavior?

**Steps:**
1. Complete test S2 (Bazzt Zzzt) as described above.
2. Pay particular attention to whether Bazzt Zzzt's spellcasting behavior
   looks normal — he should cast Rotting Flesh (spell 897) at regular intervals
   if he would have cast before.

**Pass if:** Bazzt Zzzt casts Rotting Flesh (DOT) normally; no weird behavior,
no skipped casts, no crashes.
**Fail if:** Zone crashes when Bazzt Zzzt attempts to cast, or no spells cast
at all (might indicate the entire spell list was wiped rather than just one entry).

---

### Test E2: CT special_abilities string — Rampage cap verification

**Risk from architecture:** The REPLACE(special_abilities, '3,1,10', '3,1,3')
edit was NOT applied (confirmed correct per architect addendum — global rule
is sufficient). Verify that CT's rampage targets remain capped at 2 in practice.

**Steps:**
1. Engage Cazic Thule with your full 6-person party in positions spread out.
2. During the CT fight, watch for rampage warnings in the combat log. Count
   how many party members are hit by rampage swings.

**Pass if:** Rampage hits at most 2 party members simultaneously.
**Fail if:** Rampage hits 3+ party members simultaneously, suggesting the
global MaxRampageTargets=2 rule regressed. Run `#reloadrules` and retest.

---

### Test E3: Prior-pass named mobs not regressed

**Risk from architecture:** Phase 2 UPDATEs used explicit NPC ID WHERE clauses,
not a broad raid_target=1 sweep. Verify that PoFear trash (raid_target=1 trash
mobs like a_scareling 72005) are at their pre-Phase-2 values.

**Steps:**
1. In fearplane, kill one a_scareling (common PoFear trash, raid_target=1).
2. The a_scareling should be at 14285 HP (confirmed in DB from the prior
   small-group-scaling pass).

**Pass if:** a_scareling feels like normal PoFear trash, not a raid boss.
**Fail if:** a_scareling has abnormally high HP or feels significantly different
from other PoFear trash — would indicate an unintended broad UPDATE.

---

### Test E4: PoFear quest script — event_death chain fires correctly

**Risk from architecture:** HP cuts could in theory break percentage-based
event_hp script triggers. These use percentage, not absolute values, so they
should scale automatically.

**Steps:**
1. Kill the a_dracoliche (Test F2).
2. Verify that any associated event_death trigger fires — the dracoliche's
   death spawns or signals the next step in the Wizard epic chain.
3. Confirm the dracoliche's loot drop chain works (Words of Cazic-Thule or
   relevant component).

**Pass if:** dracoliche's death fires the correct event; loot drops.
**Fail if:** Zone does not respond to dracoliche kill — would indicate a
quest script is checking absolute HP value somewhere. Report this as a bug.

---

## What to Report Back

After completing your testing sessions, report:

1. **PoSky death-touch result:** PASS or FAIL for tests S1, S2, S3. If FAIL,
   we need infra-expert immediately.

2. **Difficulty feel for each zone:** Does each zone feel "slightly harder
   than scaled named"? Is there any encounter that still feels like a wall
   (too hard) or trivially easy (too soft)?

3. **Loot confirmed:** Yes/No for each zone you tested. Did kills produce
   loot?

4. **Any quest chain breakage:** Did any epic item fail to drop, or did any
   event_death trigger fail to fire?

5. **Respawn times:** Any timers that feel wrong? (e.g., a boss respawned
   in 10 minutes when it should be 6 hours)

6. **Anything unexpected:** Strange behavior, zone crashes, companion AI
   oddities during raid boss fights.

---

## Rollback (If Needed)

If any test reveals a critical failure and you want to revert all Phase 2
changes:

```bash
docker exec -i akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq < \
  /mnt/d/Dev/eq/claude/project-work/feature-raid-scaling/data-expert/sql/03-rollback.sql
```

Then reload world:
```
(echo 'reloadworld'; sleep 2) | telnet 127.0.0.1 9000
```

For spell list cache (if reverting the Cazic Touch removal specifically):
infra-expert must run full-stack restart after rollback to flush zone caches.
