# Phase 4b (Velious ToV + Sleeper + Vulak + AoW) — DB Investigation

> **Author:** architect
> **Date:** 2026-04-23
> **Purpose:** Confirm every NPC ID, scrub the Kerafyrm/Sleeper awake chain for accidental-trigger risk, run the death-touch spell sweep for Phase 4b bosses, and document the exact spawn2 / spawn_conditions / quest-script topology that governs ToV altar event, Sleeper's Tomb condition gating, and AoW triggered chain.

---

## 1. Phase 4b NPC inventory (verified)

### 1.1 Temple of Veeshan — 16 dragon lords (raid_target=1)

All verified live in `templeveeshan` zone, `_condition=0` (always spawn), `respawntime=259200s` (72h) with 25920s variance (7.2h).

| NPC ID | Name | Level | HP | Min/Max dmg | AC | MR | special_abilities (abbrev) | npcspecialattks | spawn2 id |
|--------|------|-------|------|-------------|------|------|-----|-----|-----|
| 124103 | #Lord_Koi`Doken | 66 | 580,000 | 215/690 | 484 | 195 | SREMCNITD + 42 (...) | SREMCNITDf | 25519 |
| 124076 | #Lady_Nevederia | 66 | 525,000 | 189/892 | 560 | 185 | SERTMCNID + 42 | SERTMCNIDf | 25414 |
| 124074 | #Lord_Kreizenn | 66 | 465,000 | 209/950 | 570 | 60 | SETMCNIDU + 42 | SETMCNIDUf | 25412 |
| 124008 | #Lord_Feshlak | 66 | 455,000 | 238/960 | 550 | 200 | SERTMCNID + 42 | SERTMCNIDf | 25284 |
| 124071 | #Cekenar | 66 | 425,000 | 225/700 | 560 | 200 | SRETMCND | SRETMCNDf | 25409 |
| 124010 | #Aaryonar | 66 | 390,000 | 235/900 | 560 | 225 | SEQMCNID | SEQMCNIDf | 25285 |
| 124037 | #Dozekar_the_Cursed | 66 | 386,500 | 235/900 | 484 | 190 | SEQMCNID | SEQMCNIDf | 25326 |
| 124077 | #Lady_Mirenilla | 66 | 380,000 | 285/950 | 560 | 210 | SERTMCNID + 42 | SERTMCNIDf | 25415 |
| **124017** | **#Lord_Vyemm** | 66 | 350,000 | 250/**1,200** | 560 | **1,000** | SERTMCNID + **42** | SERTMCNIDf | 25292 |
| 124020 | #Lendiniara_the_Keeper | 66 | 320,000 | 215/652 | 560 | 160 | SERQUMCNID + 42 | SERQUMCNIDf | 25294 |
| 124011 | Dagarn_the_Destroyer | 70 | 300,000 | 280/755 | **900** | 250 | SERQMCNID + HP-regen ability 10 | SERQMCNIDf | 25286 |
| 124104 | #Telkorenar | 66 | 280,000 | 195/480 | 605 | **1,000** | SERTUMCNID + 42 | SERTUMCNIDf | 25520 |
| 124105 | #Gozzrem | 66 | 280,000 | 195/480 | 560 | **1,000** | SERTMCNIDU + 42 | SERTMCNIDUf | 25521 |
| 124001 | #Ikatiar_the_Venom | 66 | 250,000 | 275/750 | 484 | 55 | SERTUMCNID | SERTUMCNIDf | 25275 |
| 124072 | #Jorlleag | 66 | 250,000 | 213/916 | 560 | 200 | SETMCNID | SETMCNIDf | 25410 |
| 124004 | #Eashen_of_the_Sky | 66 | 240,000 | 275/750 | 484 | 60 | SEFTUMCNID | SEFTUMCNIDf | 25280 |

**Three MR-wall bosses:** Vyemm (1,000), Telkorenar (1,000), Gozzrem (1,000). Preserve per Decision #11.
Dagarn has a HP-regen ability flag (1,10^8) — preserve signature.

### 1.2 Temple of Veeshan — NToV mid-tier named (L60 and L65-66)

| Cluster | NPC ID | Name | Level | HP | Max dmg | Respawn |
|---|---|---|---|---|---|---|
| **Midayor cluster (L60)** | 124030 | #Midayor | 60 | 120,000 | 436 | 194,400s (54h) |
| | 124031 | #Grozzmel | 60 | 120,000 | 436 | 194,400s |
| | 124034 | #Ymmeln | 60 | 120,000 | 436 | 194,400s |
| | 124035 | #Krigara | 60 | 120,000 | 436 | 194,400s |
| | 124036 | #Lepethida | 60 | 120,000 | 436 | 194,400s |
| | 124038 | #Essedera | 60 | 120,000 | 436 | 194,400s |
| | 124039 | #Tavekalem | 60 | 120,000 | 436 | 194,400s |
| | 124040 | #Casalen | 60 | 120,000 | 436 | 194,400s |
| **Mid-tier named (L65-66)** | 124018 | #Cyndor_Lightningfang | 65 | 140,000 | 700 | 64,800s (18h) |
| | 124073 | #Zlexak | 66 | 121,500 | 587 | 259,200s (72h) |
| | 124007 | #Yrrindor_Emerald_Claw | 65 | 120,000 | 700 | 64,800s |
| | 124106 | #Kalkar_of_the_Maelstrom | 65 | 120,000 | 700 | 64,800s |
| | 124107 | #Vyldin_Flamereaver | 65 | 120,000 | 700 | 64,800s |
| | 124003 | Zyerek_Onyxblood | 65 | 110,000 | 704 | 64,800s |
| | 124009 | #Malteor_Flamecaller | 65 | 110,000 | 700 | 64,800s |
| | 124075 | #Sevalak | 66 | 101,500 | 950 | 259,200s |

**Total NToV mid-tier named: 16** (8 Midayor cluster + 8 individual L65-66).

### 1.3 Temple of Veeshan — Defenders (EXCLUDED per audit + Decision #2)

| NPC ID | Name | Level | HP | Respawn | Disposition |
|---|---|---|---|---|---|
| 124050 | An_Emerald_Defender | 65 | 120,000 | 16,200s | **Excluded — elite trash** |
| 124051 | A_Sky_Defender | 65 | 120,000 | 11,250-16,200s | **Excluded** |
| 124052 | An_Onyx_Defender | 65 | 120,000 | 16,200s | **Excluded** |
| 124079 | A_Lava_Defender | 65 | 120,000 | 11,250-16,200s | **Excluded** |

Per audit line 1668-1678 and Decision #2: these are "elite trash at 50-75k HP" (raid_target=1 but already sit between named and boss tier). Prior-pass globals + Decision #2 hold; leave at 120k HP.

### 1.4 Vulak`Aerr (script-spawned, event-gated)

| NPC ID | Name | Level | HP | Min/Max dmg | AC | MR | special_abilities | spawn2 |
|---|---|---|---|---|---|---|---|---|
| 124155 | #Vulak`Aerr | 70 | **890,000** | 355/**1,400** | **950** | 80 | SERQMCNID + 5 (immune gravflux?) + 31 (immune dispel) + 42 (...) | **none** |

**Spawn mechanism (verified via `akk-stack/server/quests/templeveeshan/#Thylex_of_Veeshan.pl`):** Thylex runs a 60-second tick. If NONE of the six altar dragons (Mirenilla 124077, Nevederia 124076, Feshlak 124008, Aaryonar 124010, Kreizenn 124074, Vyemm 124017) is alive AND Vulak (124155) is not currently spawned AND the `vulak` qglobal isn't set → `quest::spawn2(124155, 0, 0, -739.4, 517.2, 121, 510)` with a 6-minute qglobal cooldown.

**spawn_conditions table row:** `(templeveeshan, 1, 0, onchange=3)` "Vulak" exists but **is not referenced by Thylex.pl** — the code path uses `entity_list` checks + qglobals. This row is legacy. Safe to leave.

**Phase 4b impact:** HP cuts on the 6 altar dragons do NOT change Thylex logic. Reducing Vulak HP alone makes him tractable once reached. **No script edit needed.**

### 1.5 Sleeper's Tomb (zone: `sleeper`)

**spawn_conditions state (ground truth):**
```
sleeper | 1 | value=0 | onchange=2 | "Warders"  ← currently OFF
sleeper | 2 | value=1 | onchange=2 | "Ancients" ← currently ON
```

**NPC roster (raid_target=1, by spawn_condition):**

**Condition 2 (Ancients — currently LIVE):**

| NPC ID | Name | Level | HP | Min/Max dmg | MR | spawn2 id | respawn | notes |
|---|---|---|---|---|---|---|---|---|
| 128040 | Milas_An`Rev | 67 | 210,000 | 162/447 | 300 | 25245 | 14,400s (4h) | Mid-tier boss |
| 128041 | #Kildrukaun_the_Ancient | 70 | 352,000 | 284/705 | **400** | 25246 | 259,200s (72h) | Ancient — highest MR in tomb |
| 128042 | #Vyskudra_the_Ancient | 70 | 352,000 | 284/789 | 180 | 25247 | 259,200s | **Casts Lightning Breath (-1,500 dmg, spell 839, 12s recast) — signature mechanic, preserve.** |
| 128043 | #Tjudawos_the_Ancient | 70 | 352,000 | 292/767 | 180 | 25248 | 259,200s | Ancient |
| 128044 | #Zeixshi-Kar_the_Ancient | 70 | 377,000 | 372/929 | 180 | 25249 | 259,200s | Highest-HP Ancient |
| 128143 | #The_Final_Arbiter (main) | 70 | 357,000 | 292/629 | 300 | 25250 | 259,200s | Main Arbiter — Sleeper-adjacent |
| 128144 | #The_Progenitor (main) | 70 | 327,000 | 204/619 | 250 | 25272 | 259,200s | Progenitor boss |
| 128145 | #Master_of_the_Guard (main) | 69 | 326,500 | 157/432 | 200 | 25273 | 259,200s | **8-sentry add encounter** (see §2) |

**Condition 1 (Warders — currently DORMANT):**

| NPC ID | Name | Level | HP | Min/Max dmg | MR | spawn2 id | respawn | Notes |
|---|---|---|---|---|---|---|---|---|
| 128045 | #The_Final_Arbiter (alt) | 70 | 200,000 | 166/460 | 300 | 151668 | 259,200s | Alt Final Arbiter variant |
| 128090 | #Nanzata_the_Warder | 70 | 200,000 | 115/442 | 250 | 58547 | 259,200s | Warder |
| 128091 | #Ventani_the_Warder | 70 | 200,000 | 136/415 | 255 | 58549 | 259,200s | Warder |
| 128092 | #Tukaarak_the_Warder | 70 | 200,000 | 126/405 | 250 | 58548 | 259,200s | Warder |
| 128093 | #Hraashna_the_Warder | 70 | 200,000 | 137/509 | 79 | 58546 | 259,200s | Warder |

**Condition 1 also governs The Sleeper:**

| NPC ID | Name | Level | HP | raid_target | spawn2 | Notes |
|---|---|---|---|---|---|---|
| 128094 | #The_Sleeper | 99 | 3,500,000 | **0** (not raid_target) | id 26883, `_condition=1 cond_value=1 respawntime=1200s` | **Uncombattable quest NPC** — shouts "I AM FREE" on signal 66 and spawns Kerafyrm (128089) at -1499, -2345, -1053. **Untouched per Decision #12.** |

**Kerafyrm (128089/95) — permanent untouched per Decision #12:**

| NPC ID | Name | Level | HP | raid_target | Notes |
|---|---|---|---|---|---|
| 128089 | #Kerafyrm | 99 | 3,500,000 | 0 | **Spell list 489 contains "Destroy" (spell 1948, mana=0, cast_time=0, -100,000 dmg).** Untouched. |
| 128095 | #Kerafyrm_ | 99 | 3,500,000 | 0 | Same. Used for zone transition. |

### 1.6 Avatar of War

| NPC ID | Name | Level | HP | Min/Max dmg | AC | MR | special_abilities | spawn2 |
|---|---|---|---|---|---|---|---|---|
| 113457 | The_Avatar_of_War | 70 | **900,000** | 299/**1,154** | 850 | 190 | SERQUMCNID + 5,6/6 (rampage 6×6 burst) + 31 | **none** (script-spawned by Idol death per Phase 4a) |

**Spawn mechanism:** Phase 4a scaled Statue (113071) + Idol (113341). Idol's `event_death_complete` → `eq.unique_spawn(113457, …)` spawns AoW. Phase 4a protocol-agent already cleared this chain (2026-04-22 addendum). Phase 4b completes the chain by scaling 113457 directly. **No spawn2 / respawntime change needed.**

---

## 2. Kerafyrm / Sleeper Awake mechanism (critical — Decision #12 boundary)

**Goal:** Verify that scaling Phase 4b HP values cannot accidentally trigger the Kerafyrm awake event. Decision #12 requires Sleeper-Awake event stays untouched.

**Complete code trace:**

### 2.1 Ancient scripts (`akk-stack/server/quests/sleeper/#Kildrukaun_the_Ancient.pl`, `#Vyskudra…`, `#Tjudawos…`, `#Zeixshi-Kar…`)

All four Ancient scripts have the same pattern:

```perl
sub EVENT_SPAWN {
  quest::settimer("kildrukaun",1);   # varies by ancient
}
sub EVENT_TIMER {
  $kerafyrm = $entity_list->GetMobByNpcTypeID(128089);
  if ($timer eq "kildrukaun" && $kerafyrm) {
    quest::stoptimer("kildrukaun");
    quest::depop_withtimer();
  }
}
```

The timer fires every 1 second after spawn and depops the Ancient if Kerafyrm is currently alive. **This means:** when Kerafyrm spawns, the Ancients self-depop. When Kerafyrm dies (or despawns), the condition 2 flip re-spawns them at the next zone tick.

Ancients do NOT set `spawn_condition` directly; their only action is self-depop when Kerafyrm is up.

### 2.2 Warder scripts (`#Hraashna_the_Warder.pl`, `#Nanzata…`, `#Ventani…`, `#Tukaarak…`)

All four Warder scripts share identical pattern. Example from Hraashna:

```perl
sub EVENT_DEATH_COMPLETE {
  $nanzata = $entity_list->GetMobByNpcTypeID(128090);
  $ventani = $entity_list->GetMobByNpcTypeID(128091);
  $tukaarak = $entity_list->GetMobByNpcTypeID(128092);
  if (!$nanzata && !$ventani && !$tukaarak) {
    quest::signalwith(128094, 66, 0);   # wakes The Sleeper
    quest::shout("Warders, I have fallen. …");
  } else {
    quest::shout("Warders, I have fallen. …");
  }
}
```

Each Warder's death checks if all other three Warders are also dead (via `GetMobByNpcTypeID` returning falsy). When the LAST Warder dies → `signalwith(128094, 66)` fires.

### 2.3 The Sleeper script (`#The_Sleeper.pl`)

```perl
sub EVENT_SIGNAL {
  if ($signal == 66) {
    quest::shout("I AM FREE!");
    quest::depop_withtimer();
    quest::spawn2(128089, 1, 0, -1499, -2344.8, -1052.8, 0);   # Kerafyrm
  }
}
```

Signal 66 from the last Warder's death → Kerafyrm spawns at hard-coded coordinates.

### 2.4 Kerafyrm script (`#Kerafyrm.pl`)

```perl
sub EVENT_SPAWN {
  quest::shout("ZERZURA!");
  quest::setglobal("kerafyrm", 1, 7, "F");
  quest::spawn_condition(sleeper, 2, 1);   # re-enable Ancients
  quest::spawn_condition(sleeper, 1, 0);   # disable Warders
  quest::forcedooropen(46);
  quest::settimer("depop", 1);
}
sub EVENT_DEATH_COMPLETE {
  quest::setglobal("kerafyrm", 3, 7, "F");
  quest::stoptimer("depop");
  quest::depop();
}
```

Kerafyrm on spawn immediately flips conditions (2=1 ON for Ancients, 1=0 OFF for Warders), restoring the original state. Also sets qglobal `kerafyrm=1` to mark the event has triggered. Transitions via 128095 (zone-clone of Kerafyrm) upon reaching coordinates.

### 2.5 Chain summary

**Only a player killing all 4 Warders in sequence triggers Kerafyrm.**

1. Current state on our server: condition 1 (Warders) = 0. **Warders and The Sleeper are currently UNREACHABLE by normal gameplay.**
2. No script found that auto-flips condition 1 from 0→1. The flip would require GM intervention (`#spawncondition sleeper 1 1` or equivalent).
3. If a GM ever flips condition 1 to 1, the 4 Warders + The Sleeper spawn.
4. If the player then kills all 4 Warders, signal 66 fires, The Sleeper shouts "I AM FREE," and Kerafyrm spawns.
5. Kerafyrm on spawn flips conditions BACK (1=0, 2=1), re-establishing Ancient rotation.

**Conclusion for Phase 4b (Decision #12 compliance):**

| Action | Affects Awake Event? | Phase 4b stance |
|---|---|---|
| Scale Warder HP (200k → 60k) | Makes Warders killable by small group **only if a GM first flips condition 1** | Scale per audit — **no risk of automatic trigger** |
| Scale Ancient HP | Does not touch Warder/Sleeper path | Scale per audit |
| Scale Kerafyrm (128089/95) HP | **WOULD** trivialize the awake event | **DO NOT TOUCH** — Decision #12 |
| Delete "Destroy" spell (1948) from Kerafyrm spell list | Would remove signature death-touch | **DO NOT TOUCH** — Decision #12 |
| Modify spawn_conditions row | Would change player/GM trigger mechanism | **DO NOT TOUCH** — leave gating intact |
| Edit Warder / Sleeper / Kerafyrm quest scripts | Could break awake trigger | **DO NOT TOUCH** — Decision #12 |

**Phase 4b explicitly does NOT touch:** npc_types rows 128089 / 128094 / 128095 (Kerafyrm trio + The Sleeper), npc_spells_entries for spell list 489 (Kerafyrm), any file in `akk-stack/server/quests/sleeper/` whose name matches Warder / Kerafyrm / Sleeper / Ancient patterns.

**Phase 4b DOES scale (by NPC ID):** the four Warders (128090/91/92/93) at the `npc_types.hp` + `npc_types.maxdmg` column level only. Scaling these has zero effect on the awake trigger, which depends purely on scripted GetMobByNpcTypeID() checks (count-based, not HP-based). Scaling the Warders makes them tractable if-and-when a GM chooses to activate them.

### 2.6 Master of the Guard encounter (signature mechanic — preserve)

`akk-stack/server/quests/sleeper/encounters/motg.lua` (confirmed in place):

Master of the Guard (128145) uses a timer-driven 8-add wave mechanism. Every 3s → 50s → 50s → 50s it signals 8 `#a_foreboding_sentry` NPCs (128000-128007) which spawn visible sentries (128063). This is a signature mechanic per Decision #11. **Preserve.** HP scaling on MotG is safe; we DO NOT touch timer intervals, signal targets, or special_abilities.

---

## 3. Death-touch spell sweep (Phase 4b bosses)

Query pattern mirrors Phase 2/3/4a sweeps: `mana=0 AND cast_time=0 AND effect_base_value1 <= -1000` against spell lists of every Phase 4b in-scope NPC (16 ToV dragons + 16 NToV mid-tier named + 4 Ancients + 4 Warders + Final Arbiter main + alt + Progenitor + Master of the Guard + Milas + Vulak + AoW = 47 NPCs).

**Result: ONE hit (non-death-touch signature mechanic):**

| NPC ID | Name | Spell ID | Spell Name | Mana | Cast | Recast | Damage | Effect ID |
|---|---|---|---|---|---|---|---|---|
| 128042 | #Vyskudra_the_Ancient | 839 | Lightning Breath | 0 | 0 | 12,000ms (12s) | -1,500 | 0 (direct damage) |

**Disposition:** Lightning Breath at -1,500 damage every 12 seconds is a **signature Ancient mechanic**, not a death-touch (instant-kill profile requires damage ≤ -10,000). Decision #11 preserves signature mechanics. Keep unchanged.

**Kerafyrm's "Destroy" (spell 1948, -100,000 damage, 0 cast, 0 mana)** was matched for spell list 489 — this IS a true death-touch, BUT Kerafyrm is out-of-scope per Decision #12. **Kerafyrm keeps Destroy; we do not edit spell list 489.**

**No `npc_spells_entries` DELETE needed for Phase 4b.** (Same disposition as Phases 3 and 4a.)

---

## 4. spawn2 / respawntime inventory

**Bosses with spawn2 rows that require respawntime update to 86400s (24h endgame per Decision #8):**

| NPC ID | Current respawn | Target respawn | Notes |
|---|---|---|---|
| 124001 | 93,744s (~26h) | 86,400s (24h) | Ikatiar the Venom — shorter than siblings already |
| 124004 | 259,200s (72h) | 86,400s | Eashen of the Sky |
| 124008 | 259,200s | 86,400s | Lord Feshlak |
| 124010 | 259,200s | 86,400s | Aaryonar |
| 124011 | 259,200s | 86,400s | Dagarn the Destroyer |
| 124017 | 259,200s | 86,400s | Lord Vyemm |
| 124020 | 259,200s | 86,400s | Lendiniara the Keeper |
| 124037 | 259,200s | 86,400s | Dozekar the Cursed |
| 124071 | 259,200s | 86,400s | Cekenar |
| 124072 | 259,200s | 86,400s | Jorlleag |
| 124074 | 259,200s | 86,400s | Lord Kreizenn |
| 124076 | 259,200s | 86,400s | Lady Nevederia |
| 124077 | 259,200s | 86,400s | Lady Mirenilla |
| 124103 | 259,200s | 86,400s | Lord Koi`Doken |
| 124104 | 259,200s | 86,400s | Telkorenar |
| 124105 | 259,200s | 86,400s | Gozzrem |
| 124073 | 259,200s | 86,400s | Zlexak (mid-tier) |
| 124075 | 259,200s | 86,400s | Sevalak (mid-tier) |
| 124030-40 | 194,400s (54h) | 86,400s | Midayor cluster (8 NPCs) |
| 128041 | 259,200s | 86,400s | Kildrukaun the Ancient |
| 128042 | 259,200s | 86,400s | Vyskudra the Ancient |
| 128043 | 259,200s | 86,400s | Tjudawos the Ancient |
| 128044 | 259,200s | 86,400s | Zeixshi-Kar the Ancient |
| 128045 | 259,200s | 86,400s | Final Arbiter (alt) — Warder condition, update anyway |
| 128090-93 | 259,200s | 86,400s | 4 Warders |
| 128143 | 259,200s | 86,400s | Final Arbiter (main) |
| 128144 | 259,200s | 86,400s | Progenitor (main) |
| 128145 | 259,200s | 86,400s | Master of the Guard |

**Already within range, no update:**
- 124018 Cyndor, 124007 Yrrindor, 124106 Kalkar, 124107 Vyldin, 124003 Zyerek, 124009 Malteor — all at 64,800s (18h). Under endgame tier but **these are mid-tier named sitting BELOW endgame**; 18h is appropriate. Leave.
- 128040 Milas An`Rev at 14,400s (4h) — mid-tier boss, already accessible. Leave.
- 124050/51/52/79 Defenders at 11,250-16,200s (3-5h) — **scaled HP/dmg per Q37 override but respawn UNCHANGED per architect Q37 resolution** (native 3-5h already below Decision #8 endgame 24h; bumping would over-extend farm-tier cadence).

**No spawn2 rows (script-spawned, no update):**
- 113457 AoW (spawned by Idol death, Phase 4a chain)
- 124155 Vulak (spawned by Thylex when 6 altar-dragons dead)
- 128089/94/95 Kerafyrm trio (untouched per Decision #12; The Sleeper's spawn2 at respawn 1200s is part of the awake event — untouched)

**Total spawn2 UPDATEs: ~28 rows** (16 ToV dragons + 8 Midayor cluster + 1 Zlexak + 1 Sevalak + 4 Ancients + 4 Warders + 3 Sleeper-adjacent mains + 1 Milas skip + Final Arbiter alt).

---

## 5. Proposed Phase 4b HP / damage targets (audit-aligned, architect-curated)

Per audit recommendations + Decision #1 endgame-tier ("peak mastery") + Decision #11 signature preservation.

### 5.1 Temple of Veeshan — 16 dragon lords

```sql
-- Based on audit recommendations (lines 1629-1646)
UPDATE npc_types SET hp = 130000, maxdmg =  690               WHERE id = 124103;  -- Lord Koi`Doken 580k→130k
UPDATE npc_types SET hp = 120000, maxdmg =  600               WHERE id = 124076;  -- Lady Nevederia 525k→120k, 892→600
UPDATE npc_types SET hp = 110000, maxdmg =  600               WHERE id = 124074;  -- Lord Kreizenn 465k→110k, 950→600
UPDATE npc_types SET hp = 110000, maxdmg =  600               WHERE id = 124008;  -- Lord Feshlak 455k→110k, 960→600
UPDATE npc_types SET hp = 100000                              WHERE id = 124071;  -- Cekenar 425k→100k (700 dmg OK)
UPDATE npc_types SET hp =  95000, maxdmg =  550               WHERE id = 124010;  -- Aaryonar 390k→95k, 900→550
UPDATE npc_types SET hp =  95000, maxdmg =  550               WHERE id = 124037;  -- Dozekar the Cursed 386.5k→95k
UPDATE npc_types SET hp =  95000, maxdmg =  600               WHERE id = 124077;  -- Lady Mirenilla 380k→95k, 950→600
UPDATE npc_types SET hp =  90000, maxdmg =  700               WHERE id = 124017;  -- Lord Vyemm 350k→90k, 1200→700 (MR=1000 PRESERVED)
UPDATE npc_types SET hp =  80000                              WHERE id = 124020;  -- Lendiniara the Keeper 320k→80k (652 dmg OK)
UPDATE npc_types SET hp =  80000                              WHERE id = 124011;  -- Dagarn the Destroyer 300k→80k (HP-regen ability PRESERVED)
UPDATE npc_types SET hp =  75000                              WHERE id = 124104;  -- Telkorenar 280k→75k (MR=1000 PRESERVED)
UPDATE npc_types SET hp =  75000                              WHERE id = 124105;  -- Gozzrem 280k→75k (MR=1000 PRESERVED)
UPDATE npc_types SET hp =  65000, maxdmg =  550               WHERE id = 124001;  -- Ikatiar the Venom 250k→65k
UPDATE npc_types SET hp =  65000, maxdmg =  600               WHERE id = 124072;  -- Jorlleag 250k→65k, 916→600
UPDATE npc_types SET hp =  65000, maxdmg =  550               WHERE id = 124004;  -- Eashen of the Sky 240k→65k
```

### 5.2 Temple of Veeshan — 16 NToV mid-tier named (40-50k HP per audit line 1669)

```sql
-- Midayor cluster (8 L60 NPCs at 120k HP)
UPDATE npc_types SET hp = 40000 WHERE id = 124030;  -- Midayor
UPDATE npc_types SET hp = 40000 WHERE id = 124031;  -- Grozzmel
UPDATE npc_types SET hp = 40000 WHERE id = 124034;  -- Ymmeln
UPDATE npc_types SET hp = 40000 WHERE id = 124035;  -- Krigara
UPDATE npc_types SET hp = 40000 WHERE id = 124036;  -- Lepethida
UPDATE npc_types SET hp = 40000 WHERE id = 124038;  -- Essedera
UPDATE npc_types SET hp = 40000 WHERE id = 124039;  -- Tavekalem
UPDATE npc_types SET hp = 40000 WHERE id = 124040;  -- Casalen

-- Mid-tier L65-66 named (8 at 101-140k HP)
UPDATE npc_types SET hp = 50000 WHERE id = 124018;  -- Cyndor Lightningfang 140k→50k
UPDATE npc_types SET hp = 45000 WHERE id = 124073;  -- Zlexak 121.5k→45k
UPDATE npc_types SET hp = 45000 WHERE id = 124007;  -- Yrrindor Emerald Claw 120k→45k
UPDATE npc_types SET hp = 45000 WHERE id = 124106;  -- Kalkar of the Maelstrom 120k→45k
UPDATE npc_types SET hp = 45000 WHERE id = 124107;  -- Vyldin Flamereaver 120k→45k
UPDATE npc_types SET hp = 42000 WHERE id = 124003;  -- Zyerek Onyxblood 110k→42k
UPDATE npc_types SET hp = 42000 WHERE id = 124009;  -- Malteor Flamecaller 110k→42k
UPDATE npc_types SET hp = 40000 WHERE id = 124075;  -- Sevalak 101.5k→40k
```

### 5.3 Sleeper's Tomb — Ancients + Progenitor + Arbiter + MotG + Milas + Warders

```sql
-- Ancients (live content)
UPDATE npc_types SET hp = 90000, maxdmg = 700 WHERE id = 128044;  -- Zeixshi-Kar 377k→90k, 929→700
UPDATE npc_types SET hp = 85000               WHERE id = 128143;  -- Final Arbiter main 357k→85k (629 dmg OK)
UPDATE npc_types SET hp = 85000               WHERE id = 128041;  -- Kildrukaun the Ancient 352k→85k (MR=400 PRESERVED)
UPDATE npc_types SET hp = 85000, maxdmg = 700 WHERE id = 128042;  -- Vyskudra the Ancient 352k→85k, 789→700 (Lightning Breath PRESERVED)
UPDATE npc_types SET hp = 85000, maxdmg = 700 WHERE id = 128043;  -- Tjudawos the Ancient 352k→85k
UPDATE npc_types SET hp = 80000               WHERE id = 128144;  -- Progenitor main 327k→80k
UPDATE npc_types SET hp = 80000               WHERE id = 128145;  -- Master of the Guard main 326.5k→80k (8-sentry wave PRESERVED)
UPDATE npc_types SET hp = 60000               WHERE id = 128040;  -- Milas An`Rev 210k→60k

-- Warders (dormant on current server — condition 1 = 0)
UPDATE npc_types SET hp = 60000 WHERE id = 128093;  -- Hraashna the Warder 200k→60k
UPDATE npc_types SET hp = 60000 WHERE id = 128090;  -- Nanzata the Warder 200k→60k
UPDATE npc_types SET hp = 60000 WHERE id = 128092;  -- Tukaarak the Warder 200k→60k
UPDATE npc_types SET hp = 60000 WHERE id = 128091;  -- Ventani the Warder 200k→60k

-- Final Arbiter alt variant (condition 1)
UPDATE npc_types SET hp = 60000 WHERE id = 128045;  -- Final Arbiter alt 200k→60k
```

### 5.4 Vulak`Aerr + Avatar of War (the Phase 4b pinnacle fights)

```sql
-- Vulak`Aerr — 890k at 1,400 max dmg is well beyond small-group tolerance
UPDATE npc_types SET hp = 150000, mindmg = 250, maxdmg = 800 WHERE id = 124155;
-- Vulak: 890k→150k HP (-83%), 355-1400 → 250-800 damage. Per audit line 1650.
-- ToV pinnacle: harder than 4a bosses but beatable with full preparation.
-- MR=80 (already low — magic-vulnerable dragon), AC=950 (preserved).
-- special_abilities 5/8/13/14/15/16/17/21/31/42 preserved (Decision #11).

-- Avatar of War — 900k / 1,154 max dmg + 6×6 rampage
UPDATE npc_types SET hp = 120000, mindmg = 200, maxdmg = 700 WHERE id = 113457;
-- AoW: 900k→120k HP (-87%), 299-1154 → 200-700 damage. Per audit line 1568.
-- Endgame-tier "peak mastery" encounter. Rampage 6×6 is capped to MaxRampageTargets=2 globally.
-- special_abilities preserved (S/E/R/Q/U/M/C/N/I/D/f + rampage 6×6 + 12/13/14/15/16/17/21/31).
```

### 5.5 spawn2 respawntime UPDATE (24h = 86,400s endgame per Decision #8)

```sql
UPDATE spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
SET s2.respawntime = 86400
WHERE se.npcID IN (
    124001, 124004, 124008, 124010, 124011, 124017, 124020, 124037,
    124071, 124072, 124074, 124076, 124077, 124103, 124104, 124105,
    124073, 124075, 124030, 124031, 124034, 124035, 124036, 124038, 124039, 124040,
    128041, 128042, 128043, 128044, 128045,
    128090, 128091, 128092, 128093,
    128143, 128144, 128145
);

-- Does NOT update: 124018/07/106/107/003/009 (already 64,800s - 18h mid-tier),
--   124050/51/52/79 (Defenders — HP/dmg scaled per Q37, respawn UNCHANGED at 11,250-16,200s native short-tier),
--   124075 exception handled above,
--   128040 Milas (14,400s — already accessible),
--   113457 AoW / 124155 Vulak (no spawn2, script-spawned),
--   128089/94/95 Kerafyrm trio (Decision #12).
```

---

## 6. Backup table scope

```sql
CREATE TABLE npc_types_backup_raid_scaling_velious_b AS
SELECT id, hp, mindmg, maxdmg, AC, MR, special_abilities, npcspecialattks, npc_spells_id
FROM npc_types
WHERE id IN (
    -- ToV 16 dragon lords
    124001, 124004, 124008, 124010, 124011, 124017, 124020, 124037,
    124071, 124072, 124074, 124076, 124077, 124103, 124104, 124105,
    -- NToV 16 mid-tier named
    124018, 124073, 124007, 124106, 124107, 124003, 124009, 124075,
    124030, 124031, 124034, 124035, 124036, 124038, 124039, 124040,
    -- Vulak + AoW
    124155, 113457,
    -- Sleeper's Tomb 12 (5 Ancients + Progenitor + Arbiter main & alt + MotG + Milas + 4 Warders)
    128040, 128041, 128042, 128043, 128044, 128045, 128090, 128091, 128092, 128093,
    128143, 128144, 128145
);
-- Expected rows: 43 (16 + 16 + 2 + 13 = 47 ...wait let me recount)
-- 16 ToV + 16 NToV + 2 (Vulak/AoW) + 13 Sleeper = 47
```

Recount: 16 ToV + 8 Midayor + 8 L65-66 named = 32 → 32+2(V/AoW)+13 Sleeper = **47 rows**.

```sql
CREATE TABLE spawn2_backup_raid_scaling_velious_b AS
SELECT s2.id, s2.zone, s2.spawngroupID, s2.respawntime, s2.variance,
       s2._condition, s2.cond_value, s2.x, s2.y, s2.z, s2.heading
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
WHERE se.npcID IN (
    -- same ID list as the respawn UPDATE for backup safety
    124001, 124004, 124008, 124010, 124011, 124017, 124020, 124037,
    124071, 124072, 124074, 124076, 124077, 124103, 124104, 124105,
    124073, 124075, 124030, 124031, 124034, 124035, 124036, 124038, 124039, 124040,
    -- Defender spawn2 rows (11 total; backed up but NOT respawn-updated per architect Q37 resolution 2026-04-23)
    124050, 124051, 124052, 124079,
    128040, 128041, 128042, 128043, 128044, 128045,
    128090, 128091, 128092, 128093,
    128143, 128144, 128145
);
-- Expected rows: ~46-49 (was ~35-38 pre-Q37; +11 Defender spawn2 rows per user Q37 override 2026-04-23)
```

---

## 7. Summary findings

| Item | Finding |
|---|---|
| Phase 4b bosses (total) | **51 raid-tier NPCs**: 16 ToV dragon lords + 16 NToV mid-tier named + **4 NToV Defenders (added per user Q37 override 2026-04-23)** + 2 (Vulak + AoW) + 13 Sleeper's Tomb bosses |
| Defenders (124050/51/52/79) | **INCLUDED per user Q37 override 2026-04-23** — scale to 45k HP / 550 maxdmg; native 3-5h respawn preserved |
| Kerafyrm trio (128089/94/95) | **UNTOUCHED** — Decision #12 permanent |
| The Sleeper (128094) | **UNTOUCHED** — integral to awake-event script chain |
| npc_types UPDATEs | **~51 rows** (47 original + 4 Defenders per Q37 override) |
| spawn2.respawntime UPDATEs | **~35-38 rows** (to 86400s endgame per Decision #8). Defender spawn2 rows (11) backed up but NOT updated — preserved at native 3-5h. |
| npc_spells_entries DELETEs | **0 rows** — sweep returned only Vyskudra Lightning Breath (signature, preserve) and Kerafyrm Destroy (out-of-scope, untouched) |
| Lua/Perl script edits | **0** — all Phase 4b levers are DB-column changes |
| special_abilities CSV edits | **0** — Decision #11 preserves all signature mechanics (Vyemm MR-wall, Telkorenar MR-wall, Gozzrem MR-wall, Kildrukaun MR=400, Vyskudra Lightning Breath, Aaryonar breath, AoW rampage, Dagarn HP-regen, MotG 8-sentry wave, Ancient Kerafyrm-alive depop) |
| Kerafyrm awake event safety | **Verified isolated** — scaling Phase 4b bosses has ZERO effect on the awake trigger chain (Warder-kill-count via `GetMobByNpcTypeID()`, not HP). Warders are currently dormant (condition 1 = 0) with no script-driven auto-flip path. |
| Vulak altar event safety | **Verified isolated** — Thylex uses `entity_list` checks + qglobals, not HP thresholds. Scaling the 6 altar dragons makes Vulak reachable per design; no script edit needed. |
| AoW triggered chain | **Completed** — Phase 4a scaled Statue+Idol; Phase 4b scales AoW, closing the Kael→AoW chain per Decision #1 tier curve. |

---

## 8. Open items / architect flags to user

No items that block implementation. Two "confirm" items for user awareness:

1. **Phase 4b inadvertently unlocks Sleeper Awake for small group** — by making the Warders tractable (60k HP instead of 200k), we reduce the barrier to triggering Kerafyrm. However: (a) the Warders are currently dormant, so the event is not accidentally reachable; (b) Kerafyrm himself remains untouched at 3.5M HP with "Destroy" death-touch intact; (c) triggering the awake event is still a deliberate player choice, and the consequence (Kerafyrm wipes the server) is preserved. Flag for user acknowledgment; architect recommendation: proceed with Warder HP cuts.

2. ~~Defender cluster (124050/51/52/79)~~ **RESOLVED 2026-04-23 via user Q37 override:** included. Scale HP 120k → 45k, maxdmg 700 → 550, respawn unchanged. Architect originally recommended exclude per audit + Decision #2; user chose Option B for scope consistency.

