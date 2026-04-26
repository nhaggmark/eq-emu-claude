# Raid Scaling Phase 3 (Kunark) — In-Game Testing Guide

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-23
> **For:** User playing 1 player + 5 companions (Titanium client)

---

## Overview

This guide covers Phase 3 Kunark raid scaling validation. The server-side
checks all passed — every HP, damage, and respawn value is confirmed in the
database. This guide gives you the in-game steps to verify the changes feel
right during actual play and that no quest scripts were broken by the stat
changes.

You do not need to test everything in one session. Each section is
independent. Mark each test PASS/FAIL and report back.

### What Changed (Quick Reference)

| Zone | Boss | Change |
|------|------|--------|
| Dreadlands | Gorenaire | 32k→22k HP, maxdmg 500→400, respawn 54h→12h |
| Emerald Jungle | Severilous | 32k→22k HP, maxdmg 500→400, respawn 54h→12h |
| Skyfire Mountains | Talendor | 32k→22k HP, maxdmg 500→400, respawn 54h→12h |
| Timorous Deep | Faydedar | 32k→19k HP, respawn 54h→12h |
| Old Sebilis | Trakanon | 32k→22k HP, respawn 54h→12h; flurry+rampage intact |
| Karnor's Castle | #Venril_Sathir (triggered) | 22k→16.5k HP, maxdmg 404→365 |
| Howling Stones | Drusella_Sathir | UNCHANGED (was already named-tier) |
| Chardok | Queen Velazul, Overking Bathezid | HP trimmed 20-25%; respawn STAYS at 1.5h |
| Chardok | Prince Selrach | UNCHANGED |
| City of Mist | Kilidna | 100k→30k HP, 700-4600 dmg → 300-1000; respawn 1.5h→6h |
| City of Mist | Lhranc | UNCHANGED |
| Veeshan's Peak (revamp) | 7 VP dragons | HP 90k-120k (was 454k-814k), damage 40-60% cut, respawn 12h |
| Script-spawned (Monk epic) | #Renux_Herkanor | 500k→120k HP, maxdmg 1605→900 |

### What Did NOT Change

- Trash mob difficulty in any of these zones
- Drop tables — kills still produce standard loot
- Kunark epic quest script logic — only NPC stats changed
- VP classic-era variant dragons (108509-108517) — dormant and untouched
- Chardok Royals respawn (still 1.5h per Decision #21)

---

## Prerequisites (GM Setup)

**Recommended level:** 65 (endgame-capable character for VP and Trakanon)

If you need to adjust:
```
#level 65
```

**Confirm 5 companions are with you:**
```
!status
```

**Teleport shortcut (any zone):**
```
#zone [zoneshortname]
```

---

## Priority Order

Run sessions in this order — highest value first:

1. **Session 1: Trakanon** (signature Kunark boss; quest chain test)
2. **Session 2: Outdoor Dragon spot-check** (pick one — fastest)
3. **Session 3: Kilidna** (one-shot fix — most urgent damage-feel test)
4. **Session 4: Veeshan's Peak** (headline change)
5. **Session 5: Chardok Royals** (respawn preservation check)
6. **Session 6: Renux Herkanor** (Monk epic unblock test)
7. **Session 7: Edge cases** (antagonistic review items)

---

## Session 1: Trakanon (Old Sebilis)

Trakanon is the signature Kunark raid boss. This session tests: HP reduction
is live in-zone, flurry + rampage mechanics still fire (Decision #11), and
the Bard epic triggered variant (#Trakanon 89181) spawns correctly with its
separate stats.

### Test T1: Trakanon — Full Kill Attempt

**What we're validating:** HP cut from 32000 to 22000 (31% cut); respawn
now 12h; flurry still fires; rampage is capped at 2 targets globally; fight
is completable with 1+5 party.

**Travel:**
```
#zone sebilis
```
Trakanon is at the deepest level of Old Sebilis. Navigate through the main
corridors to his chamber at the bottom of the zone.

**Steps:**
1. Zone into sebilis and navigate to Trakanon's chamber.
2. Before engaging, target Trakanon and use `#showstats` to confirm his HP
   bar feels appropriate for a 22000 HP boss.
3. Pull Trakanon with your full party of 6.
4. During the fight, watch for:
   - **Flurry procs:** Trakanon should flurry (multiple swings). This is
     signature behavior that must remain intact.
   - **Rampage:** He should rampage, but the global MaxRampageTargets=2 cap
     means it hits at most 2 party members simultaneously.
   - **Summon:** He should summon fleeing party members.
5. Complete the kill.
6. Check loot — Trakanon's Tooth, Sarnak War Shield, etc. should drop per
   his loottable (loottable_id=331).
7. Note the time for the 12h respawn spot-check.

**Pass if:** Trakanon is killable in 1-3 attempts with a 1+5 party; fight
takes 5-20 minutes; flurry and rampage both fire; loot drops; respawn
indicator shows ~12h.

**Fail if:** Trakanon one-shots the party through rampage (suggests rampage
cap regressed — run `#reloadrules` and retest), or fight trivializes in
under 2 minutes.

---

### Test T2: Bard Epic — Triggered #Trakanon (89181) Verification

**What we're validating:** The Bard epic triggered version of Trakanon
(#Trakanon, ID 89181) was intentionally left at 16000 HP (already at
named-tier). Confirm it spawns at its correct stats when the Bard epic
event fires.

**Prerequisite:** Have the Mystical Lute Body (Bard epic item, obtained
from Phinigel) in your inventory. If you don't have it:
```
#summonitem 10014
```
(Verify this is the Mystical Lute Body item ID on your server before using.)

**NPC trigger:** Find An_Undead_Bard (ID 89168) in Old Sebilis. He is
located near the lower area of the zone.

**Steps:**
1. While in sebilis after completing Test T1, locate An_Undead_Bard (89168).
2. Target An_Undead_Bard and hand him the Mystical Lute Body.
3. The event should trigger and spawn #Trakanon (89181).
4. Use `#showstats` on the spawned #Trakanon. His HP should display as 16000.
5. You do not need to kill #Trakanon unless you want the Undead Dragongut
   Strings (the Bard epic drop).

**Pass if:** #Trakanon spawns at 16000 HP with his separate damage/ability
profile intact.

**Fail if:** #Trakanon spawns at 22000 HP (would mean the Phase 3 SQL
accidentally hit 89181 — DB checks say this did not happen, but in-game
confirms it), or if the event does not trigger at all.

**Note:** If you cannot test this immediately, it is lower priority than T1.
Skip and come back during Bard epic progression.

---

## Session 2: Outdoor Dragon (Pick One)

All four outdoor dragons (Gorenaire, Severilous, Talendor, Faydedar) received
the same treatment: 30-40% HP cuts, damage trims on three of them, and respawn
cut from 54h to 12h. Test one to verify the feel is consistent across the set.
Gorenaire in Dreadlands is the most accessible.

### Test D1: Gorenaire — Dreadlands

**What we're validating:** HP cut from 32000 to 22000; maxdmg cut from 500
to 400; respawn now 12h; fight is completable; enrage and summon still fire.

**Travel:**
```
#zone dreadlands
```
Gorenaire roams the grassy areas of Dreadlands. She is a large black dragon.

**Steps:**
1. Zone into dreadlands.
2. Locate Gorenaire — she roams, so you may need to traverse the zone.
   If you can't find her, use:
   ```
   #findnpc gorenaire
   ```
3. Pull Gorenaire with your party.
4. Observe: she should summon fleeing players and enrage at low HP. These
   mechanics are preserved per Decision #11.
5. Complete the kill.
6. Check loot.
7. Note kill time for the 12h respawn check.

**Pass if:** Gorenaire is completable in 1-3 attempts; fight feels similar
to a mid-tier named encounter (22000 HP is higher than standard named but
not a prolonged war); enrage and summon fire; loot drops.

**Fail if:** Gorenaire is still a 10-minute+ slugfest at full HP (would
indicate the HP change didn't propagate — confirm with `#showstats`), or
any instant-kill mechanic fires (there should be none).

**Alternative:** If Gorenaire is up on cooldown from previous killing, pick
any of the other outdoor dragons:
- Severilous: `#zone emeraldjungle`
- Talendor: `#zone skyfire`
- Faydedar: `#zone timorous` (19000 HP vs 22000 for others — slightly easier)

---

## Session 3: Kilidna (City of Mist) — CRITICAL ONE-SHOT FIX

Kilidna was the most dangerous outlier in Phase 3: 100k HP with up to
4,600 max damage meant she could one-shot any character through a companion
or during zone traversal. She has been cut to 30k HP with 300-1000 damage.
This is the highest-priority feel-test — verify she no longer one-shots.

### Test K1: Kilidna — Navigate Past Her (and Kill If You Want)

**What we're validating:** Kilidna's maxdmg is 1000 (was 4600); HP is 30000
(was 100000); respawn is now 6h (was 1.5h); she is a navigation hazard, not
an instant-kill wall.

**Travel:**
```
#zone citymist
```
Kilidna is a golem-type creature who roams City of Mist. She is the boss of
the zone and previously posed a serious one-shot threat to any character she
engaged while passing through.

**Steps:**
1. Zone into citymist.
2. Navigate through the zone toward Kilidna's patrol area. She moves through
   the main corridors.
3. When she engages you (or you pull her), observe the incoming damage. A
   max hit of 1000 should be survivable for a geared level 65 character.
   No single swing should instantly kill a player at full HP.
4. Optional: kill Kilidna. With 30000 HP she is still a meaningful fight.
5. Check loot (loottable_id=87761).
6. Note that her respawn is now 6h (was 1.5h) — plan accordingly for Paladin
   or SK epic route planning.

**Pass if:** Kilidna's hits land for up to ~1000 per swing — painful but
survivable; you can pass through her area without guaranteed death; loot
drops if she is killed.

**Fail if:** Any swing one-shots a companion or player from near-full HP.
A max hit of 1000 is the DB target. If you observe a hit significantly above
1000, report it — the DB confirms 1000 but zone cache could be stale if
#reloadworld was not issued.

**Zone cache note:** #reloadworld was issued by config-expert (status.md
Task K6 complete). If Kilidna still appears to hit for 4000+, issue:
```
(echo 'reloadworld'; sleep 2) | telnet 127.0.0.1 9000
```
Then repop the zone with `#repop` and retest.

---

## Session 4: Veeshan's Peak — The Headline Change

Veeshan's Peak had the most dramatic changes: seven revamp dragons cut from
454k-814k HP down to 90k-120k, and damage cut 40-60%. VP requires a key to
enter. VP access is NOT changed by Phase 3.

### Test VP1: VP Entry + Nexona or Druushk

**What we're validating:** VP revamp dragons (the live condition=2 variants)
have HP in the 90k-120k range and reduced damage; Dragon Harm Touch on Nexona
still fires (signature mechanic per Decision #11); fight is a multi-minute
encounter but completable.

**Prerequisite:** VP key (Holgresh Elder Beads or equivalent VP access key).
If you already have VP access:
```
#zone veeshan
```

**Steps:**
1. Zone into veeshan.
2. Navigate to the first accessible VP dragon. Druushk (108040, 95k HP) and
   Nexona (108047, 120k HP) are in the front section of the zone.
3. Engage your chosen target.
4. For Nexona specifically: watch for "Dragon Harm Touch" — this is a 4,000
   HP direct-damage spell that fires every 45 seconds. It should still proc
   as a signature mechanic. It is survivable with proper healing; it is NOT
   an instant kill at full HP.
5. For all VP dragons: watch for enrage, rampage, and any breath weapon AEs.
   These are preserved per Decision #11.
6. Complete the kill.
7. Check loot.

**Pass if:** VP dragon is killable in 1-3 attempts with a 1+5 party; Dragon
Harm Touch fires on Nexona but is survivable; fight takes 10-20 minutes at
most; loot drops.

**Fail if:** Dragon appears to still have 454k-814k HP (stats did not
propagate — confirm with `#showstats`), or Dragon Harm Touch one-shots a
player at full HP (it deals 4000 damage, which should be survivable for a
buffed level 65 with 6000+ HP).

**Second VP dragon (optional):** If time allows, test Phara Dar (108048,
120k HP). Phara Dar has HP-event triggered adds at 80/60/40/20% health.
These use percentage thresholds (not absolute HP values), so they should
still fire correctly at the new 120k HP. Verify the add-wave fires during
the fight.

---

### Test VP2: VP Classic Variants Are Dormant (Sanity Check)

**What we're validating:** VP classic-era variants (108509-108517) were not
scaled — they remain dormant with their original high HP values. You should
NOT encounter them during normal VP gameplay.

**Steps:**
1. While in VP during Test VP1, note which dragons you fight.
2. If a dragon appears that is MUCH harder than expected (several hundred
   thousand HP despite Phase 3), it may be a classic-era variant. Use
   `#showstats` to identify the NPC ID.
3. If a classic-era variant (IDs 108509-108517) is somehow active, report
   it — the spawn_condition_values should have VeeshanNew=1, VeeshanOld=0.

**Pass if:** Only revamp variants (IDs 108040-108053 range) are encountered
and they match the Phase 3 HP targets.
**Fail if:** Any dragon has hundreds of thousands of HP — would indicate
spawn condition flipped or wrong NPC ID set was encountered.

---

## Session 5: Chardok Royals — Respawn Preservation Check

Decision #21 preserved the Chardok Royals' 1.5h respawn (Option A). HP was
trimmed modestly (20-25% for Queen Velazul and Overking Bathezid; Prince
Selrach unchanged). This session verifies the respawn was truly kept at 1.5h.

### Test C1: Chardok Royals — Kill and Verify Respawn

**What we're validating:** Queen Velazul HP = 24000 (was 30000), Overking
Bathezid HP = 26000 (was 34500), Prince Selrach HP = 25000 (UNCHANGED).
All three respawn at 5400s (1.5h) — NOT the 12h mid-tier target.

**Travel:**
```
#zone chardok
```
The Royals are in the inner sections of Chardok (City of the Sarnak). They
are accessible after clearing through the outer guards.

**Steps:**
1. Zone into chardok and navigate to the Royals' area.
2. Pull and kill one of the Royals (Queen Velazul is a good first test —
   she now has 24000 HP instead of 30000).
3. Note the time of the kill.
4. Continue farming other content. **Return to Chardok in approximately
   1.5 hours** and verify the killed Royal has respawned.
5. Alternatively, you can verify via `#repop` (which ignores the timer but
   confirms the spawn point works), then note that the timer should be 1.5h.

**Pass if:** The killed Royal respawns after ~1.5 hours (5400 seconds), not
12 hours. The HP feels appropriately reduced from original but still presents
a meaningful fight.

**Fail if:** The Royal does NOT respawn after 1.5h and requires 12h — would
indicate Decision #21 was not honored. DB confirmed the timers are correct,
but in-game observation is the final confirmation.

**Epic note:** Chardok Royals are on Warrior epic (Ancient Blade), Cleric
epic (Singed Scroll), and VP key chains. The 1.5h respawn preserves the
farming cadence for these progressions.

---

## Session 6: Renux Herkanor (Monk Epic Kunark Terminus)

Decision #22 (Option A) included Renux Herkanor (ID 448200) in Phase 3
scaling. He was at 500k HP with 786-1605 damage — a hard wall for Monk epic
completion on a small-group server. He is now at 120k HP with maxdmg 900.
He is script-spawned (no static spawn point) as the Monk epic terminus.

### Test R1: #Renux_Herkanor — Monk Epic Kunark Step

**What we're validating:** #Renux_Herkanor (448200) spawns at 120k HP
(was 500k) and maxdmg 900 (was 1605) when the Monk epic event fires.
Fight is completable with 1+5.

**Prerequisite:** Progress the Monk epic to the Kunark terminus step that
spawns Renux Herkanor. This requires the relevant Monk epic item or trigger
sequence. The exact trigger item and NPC interaction depends on your
progression stage.

**Steps:**
1. Progress to the Monk epic step that spawns #Renux_Herkanor.
2. Trigger his spawn via the script event.
3. Use `#showstats` to confirm HP reads approximately 120000.
4. Engage and attempt the fight with your party.
5. With 120k HP and maxdmg 900, he is still a meaningful fight for a 1+5
   group — plan accordingly with a full tank and healer companion set.
6. Complete the kill and collect the Monk epic item he drops.

**Pass if:** #Renux_Herkanor spawns at ~120k HP; fight is completable with
1+5 in 1-3 attempts; fight duration ~10-20 minutes; Monk epic progression
item drops.

**Fail if:** #Renux_Herkanor spawns at 500k HP (stat change did not load
from DB — zone cache issue), or the script event fails to spawn him at all
(would be a pre-existing quest script issue, not Phase 3 regression).

**Note:** If you are not currently on the Monk epic, this test can be
deferred until Monk epic progression is active. The DB change is confirmed;
this test validates the script-spawn path picks up the new stats.

---

## Session 7: Edge Cases (From Architecture Antagonistic Review)

### Test E1: Trakanon Rampage Cap Verification

**Risk from architecture:** Trakanon's rampage targets should be globally
capped at 2 by MaxRampageTargets=2 rule. His special_abilities string was
NOT edited (Decision #11 preserves signature mechanics). The global rule
provides the cap.

**Steps:**
1. While fighting Trakanon in Test T1, watch for rampage in the combat log.
2. Count how many party members receive rampage hits simultaneously.
3. Rampage messages look like: "[NPC] rampages" in the combat log, and
   additional hits land on secondary targets within a brief window.

**Pass if:** Rampage hits at most 2 party members per proc.
**Fail if:** Rampage hits 3+ simultaneously. If this occurs:
```
#reloadrules
```
Then retest.

---

### Test E2: VP Phara Dar Add-Wave Triggers

**Risk from architecture:** Phara Dar (108048) uses `quest::setnexthpevent(N)`
for add waves at 80/60/40/20% health. These are percentage-based triggers,
not absolute HP values, so they should scale automatically from 681k to 120k.

**Steps:**
1. During the Phara Dar fight (optional extension of Test VP1):
2. Watch for scripted add waves as Phara Dar's HP drops through 80%, 60%,
   40%, and 20%.
3. Adds should spawn at each threshold.

**Pass if:** Add waves fire at approximately 80/60/40/20% of 120k HP
(i.e., at ~96k, 72k, 48k, 24k HP remaining).
**Fail if:** No adds spawn at all — would indicate a quest script bug, but
architecture confirmed the percentage-event triggers scale automatically.

---

### Test E3: Venril Sathir Two-Form Transition

**Risk from architecture:** Venril Sathir uses a two-form fight. The Lich
form transition depends on event_death of the triggered form (#Venril_Sathir
102112), not on HP thresholds. Scaling HP should be transparent to the script.

**Travel:**
```
#zone karnor
```

**Steps:**
1. Progress to the Venril Sathir triggered event. This requires the Firefly
   Globe + Rez scroll handoff to VS Remains in Karnor's Castle.
2. Trigger #Venril_Sathir (102112).
3. Use `#showstats` to confirm HP at approximately 16500.
4. Kill #Venril_Sathir. Watch for the event_death transition to the next
   fight phase (VS Lich form).
5. The Paw of Opolla should be obtainable through the full VS event sequence.

**Pass if:** #Venril_Sathir spawns at ~16500 HP; event_death fires correctly;
two-form fight completes as intended; Paw of Opolla is obtainable.
**Fail if:** VS fight fails to trigger second form on kill — would indicate
a quest script issue (pre-existing, not Phase 3 regression), or if VS spawns
at 22000 HP (change did not propagate — unlikely given DB confirmation).

---

### Test E4: Unchanged NPCs Are Unchanged

**Risk from architecture:** Verify that intentionally untouched NPCs in
Kunark zones feel identical to before.

**Target NPCs to spot-check:**
- Lhranc (90093, City of Mist): Should be at 19000 HP, ~13.67h respawn.
  Feel: a meaningful named-tier fight, not a push-over, not a wall.
- Drusella_Sathir (105153, Howling Stones): Should be at 15750 HP. Already
  near named-tier difficulty.
- Prince Selrach Di'zok (103080, Chardok): Should be at 25000 HP, 1.5h
  respawn (same as other Royals).

**Steps:**
1. If you encounter any of these NPCs during your Kunark testing sessions,
   note their apparent HP and difficulty.
2. Optionally use `#showstats` to confirm their HP values.

**Pass if:** All three feel consistent with named-tier difficulty (not
suddenly easier or harder).
**Fail if:** Any of these feels dramatically different from pre-Phase-3
named difficulty — would indicate an accidental UPDATE.

---

## Respawn Timer Reference

| Boss | Expected Respawn |
|------|-----------------|
| Gorenaire, Severilous, Talendor, Faydedar | 12h (43200s) |
| Trakanon | 12h (43200s) |
| Drusella_Sathir | 12h (43200s) |
| #Venril_Sathir spawn2 row | 12h (43200s — primarily script-spawned; static row updated) |
| VP revamp dragons (all 7, condition=2) | 12h (43200s) |
| Kilidna | 6h (21600s) — was 1.5h |
| Lhranc | ~13.67h (49215s) — UNCHANGED |
| Queen Velazul, Overking Bathezid, Prince Selrach | 1.5h (5400s) — UNCHANGED per Decision #21 |

---

## What to Report Back

After completing your testing sessions, report:

1. **Trakanon difficulty feel:** Does 22000 HP make him the "signature Kunark
   boss" experience? Too easy? Still a wall? Does flurry fire?

2. **Outdoor dragon feel:** Does 22000 HP feel right for Kunark outdoor
   dragons? Compare to Classic Nagafen/Vox at 14400 — Kunark dragons should
   be noticeably harder.

3. **Kilidna one-shot fix confirmed:** Can you navigate past her without
   instant death? What is the highest single hit you took?

4. **VP dragon fight duration:** Does 120k HP give a 10-20 minute fight
   for a 1+5 group? Does Dragon Harm Touch (-4000 HP) still fire on Nexona?

5. **Chardok respawn confirmed:** Did the killed Royal respawn at ~1.5h?

6. **Loot drops working:** Did each boss produce expected loot?

7. **Quest script integrity:** Did any event_death trigger, add wave, or
   triggered spawn fail to work correctly?

8. **Any unexpected instant kills or unusual behavior.**

---

## Rollback (If Needed)

If any test reveals a critical Phase 3 failure and you want to revert:

```bash
docker exec -i akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq < \
  /mnt/d/Dev/eq/claude/project-work/feature-raid-scaling/data-expert/sql/06-kunark-rollback.sql
```

Then reload world:
```bash
(echo 'reloadworld'; sleep 2) | telnet 127.0.0.1 9000
```

No full-stack restart required for Phase 3 rollback (no spell list changes
were made in Phase 3, unlike Phase 2's Cazic Touch deletion).

For Phase 2 rollback (separate file):
```bash
docker exec -i akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq < \
  /mnt/d/Dev/eq/claude/project-work/feature-raid-scaling/data-expert/sql/03-rollback.sql
```
