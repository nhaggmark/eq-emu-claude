# Raid Scaling Phase 4a (Velious non-ToV) — In-Game Testing Guide

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-tester
> **Date:** 2026-04-23
> **Prerequisite:** BUG-001 (Tunare wrong NPC ID) should be fixed before running
> Session 1 (Plane of Growth). All other sessions can proceed now.

---

## Priority Order

The sessions below are ordered by validation priority:

1. **Session 1: Coldain Ring War (greatdivide)** — CRITICAL. This is the only
   event using a non-standard lever (SQL wave-mob HP cuts). Must validate that
   Lever 1 alone makes the event tractable before declaring Phase 4a complete.
   Results determine whether Lever 2 (wave_cooldown_time bump) is needed.

2. **Session 2: Kael Drakkel** — King Tormax is the face of Kael; Statue/Idol
   chain is the path to AoW in Phase 4b.

3. **Session 3: Lord Yelinak (Skyshrine)** — Tests Q24 Option A (both variants
   scaled) — confirm whichever version spawns is at 110k HP.

4. **Session 4: Outdoor Velious Dragons** — Klandicar, Zlandicar, Wuoshi are
   Sleeper's Tomb key path. Player will need to clear them.

5. **Session 5: Plane of Growth** — HOLD until BUG-001 is fixed. Tunare combat
   boss is at 530k HP (unscaled). All other PoG bosses are correctly scaled.

6. **Session 6: Velketor's Labyrinth** — Velketor with Sunstrike/Sundering
   mechanics. Quick sanity-check session.

7. **Session 7: Siren's Grotto** — Faleniel and Wygrish were one-shot-risk
   bosses. Damage cuts are critical to validate.

8. **Session 8: Plane of Mischief** — Jester fight. Quick session.

---

## Session 1: Coldain Ring War — CRITICAL Q23 Validation

**Priority: HIGHEST. Run this first.**

This session determines if Lever 1 (SQL wave-mob HP cuts) is sufficient for
1 player + companions, or if Lever 2 (wave_cooldown_time 5min -> 8min) is needed.

### Prerequisites

- Character at least level 60 (preferably 65+)
- Significant Coldain faction OR access to faction bypass (see note below)
- 5 companions recruited and ready
- Know the Ring War start location in Great Divide near Thurgadin entrance
- Zrelik the Scout (NPC 118167) is the event trigger NPC

**Faction note:** The Ring War requires Coldain faction to start. If faction
is not yet earned, you can either:
- Grind Coldain faction first (accept this is out of Phase 4a scope per Decision #25)
- Use `#faction [coldain faction id] [positive value]` to set faction for testing
  (not a permanent change, just for validation)
- Ask the user if they have a character with Coldain faction already

### Lever 1 Targets (confirmed in DB)

| NPC | ID | HP Target |
|-----|----|-----------|
| Kromrif Captain | 118130 | 6,000 |
| Kromrif Recruit | 118160 | 5,000 |
| Kromrif Warrior | 118150 | 7,000 |
| Kromrif General | 118120 | 9,000 |
| Kromrif Priest | 118209 | 12,000 |
| Kromrif Warlord | 118158 | 12,000 |
| Kromrif Veteran | 118156 | 12,000 |
| Kromrif High Priest | 118210 | 15,000 |
| Seneschal Aldikar | 118166 | 30,000 |
| Narandi the Wretched | 118145 | 45,000 |

### Test Steps

1. Log in with level 65 character with Coldain faction
2. `#zone greatdivide` or travel to Great Divide
3. Locate Seneschal Aldikar near Thurgadin — use `#findnpc Seneschal` to confirm he is at 30,000 HP (`#showstats` on Seneschal)
4. Locate Zrelik the Scout (event trigger NPC)
5. Before starting event: `#findnpc Kromrif` to spot-check any Kromrif Captains or Recruits visible; confirm HP values with `#showstats`
6. Begin the Ring War by hailing Zrelik and saying the appropriate trigger phrase (or via the quest chain)
7. **Wave 1 observation:**
   - Record the HP of the first wave mobs that spawn
   - Confirm Kromrif wave HP matches Lever 1 targets (5k-15k range)
   - Note time to clear the first wave
8. **Continue through waves, recording:**
   - Time to clear each wave
   - Whether wave N+1 begins before wave N is fully cleared (this is the Lever 2 trigger condition)
   - Whether Seneschal Aldikar survives each wave transition
   - Companion behavior during wave fights
9. **Key observation:** If 3+ consecutive waves start before the prior wave is fully cleared, Lever 2 should be considered

### Expected Results (Lever 1 only, 1 player + 5 companions)

- Each wave should be clearable in roughly 2-4 minutes at current DPS
- Waves should not overlap significantly (5-min cooldown after wave master death)
- Seneschal should survive (at 30k HP now vs 10k before)
- Total event duration: 45-90 min
- Narandi at ~45,000 HP should be a solid but not painful boss fight

### Pass Criteria

- All wave HP values match Lever 1 targets (check with #showstats)
- Event can be completed by 1 player + 5 companions
- No more than 1-2 waves begin while prior wave mobs are still alive
- Seneschal Aldikar survives to event completion
- Narandi the Wretched falls at ~45,000 HP
- Ring 10 reward (if applicable) is granted

### Fail Criteria / Lever 2 Trigger

**Trigger Lever 2 if:**
- 3+ consecutive waves start before prior wave is cleared
- Seneschal dies from AOE bleed during wave cooldowns despite 30k HP
- Wave mobs are still too high-HP for the group to clear

**If Lever 2 needed:** Report back. data-expert + lua-expert will apply
`ring_war.lua:26` change: `local wave_cooldown_time = 8 * 60 * 1000;`
followed by `#reloadquests` in greatdivide zone.

### GM Commands for Ring War Setup

```
#zone greatdivide
#findnpc Seneschal
#showstats                    (on targeted Seneschal Aldikar — expect 30000 HP)
#findnpc Zrelik               (locate event trigger NPC)
#reloadquests                 (if ring_war.lua changes are applied mid-test)
```

---

## Session 2: Kael Drakkel (kael zone)

**Note on AoW chain:** King Tormax -> Statue -> Idol chain leads to Avatar of War
(Phase 4b scope). The Idol (113341) spawns AoW on death. AoW is still at 900k HP
(unscaled for Phase 4a). **Do NOT engage AoW during this session.** Clearing
Tormax and Statue validates the Kael scaling; the full chain to AoW will require
Phase 4b completion.

### Prerequisites

- Level 65 character
- Claws of Veeshan or neutral faction for Kael (or `#faction` to bypass)
- 5 companions

### Test Steps

1. `#zone kael`
2. Navigate to King Tormax's throne room
3. `#showstats` on King Tormax — expect 100,000 HP, maxdmg 575
4. Engage King Tormax with full group
5. **Expected:** King Tormax is a meaningful boss fight (not trivial), completable without wipes
6. Navigate to Statue of Rallos Zek
7. `#showstats` on Statue — expect 50,000 HP, maxdmg 500
8. Engage Statue — confirm no one-shot hits occur (original maxdmg was 1,100)
9. **Idol of Rallos Zek:** When Statue dies, the Idol (113341) spawns
10. `#showstats` on Idol — expect 130,000 HP, maxdmg 700
11. Engage Idol (do NOT allow it to die — this spawns AoW at 900k HP which is Phase 4b)
    - OR engage and accept that AoW will spawn; retreat from AoW immediately
12. Navigate to Derakor the Vindicator
13. `#showstats` on Derakor — expect 60,000 HP, maxdmg 560
14. Engage Derakor

### Pass Criteria

- King Tormax HP = 100,000 confirmed with #showstats
- Statue of Rallos Zek HP = 50,000, maxdmg 500 — no one-shot hits during fight
- Idol of Rallos Zek HP = 130,000, maxdmg 700
- Derakor HP = 60,000, maxdmg 560
- All four Kael bosses killable by 1 player + 5 companions

### Fail Criteria

- Any Kael boss exceeds architecture HP targets (would indicate SQL did not apply)
- One-shot hits from Statue (maxdmg > 500 would indicate damage cap not applied)
- Wipes not explained by reasonable boss difficulty

---

## Session 3: Skyshrine — Lord Yelinak Q24 Validation

**Q24 Validation:** Both Lord Yelinak variants (114106 main and 114618 variant) should
be at 110,000 HP. This session confirms the Q24 Option A decision (scale both).

### Prerequisites

- Level 65 character
- Claws of Veeshan faction (or #faction bypass)

### Test Steps

1. `#zone skyshrine`
2. Navigate to Lord Yelinak's lair area
3. `#findnpc Yelinak` to locate which variant is currently up
4. `#showstats` on Lord Yelinak — expect 110,000 HP (whichever variant)
5. Engage Lord Yelinak — confirm the fight feels appropriate for Phase 4a scaling
6. Navigate to the Skyshrine Crusaders (Charayan, Susarrak, Grendish, Jortreva)
7. `#showstats` on each Crusader — expect 50,000 HP
8. Engage a Crusader to confirm respawn is fast (~640s / ~10 min)

### Pass Criteria

- Lord Yelinak at 110,000 HP (either variant ID)
- Skyshrine Crusaders at 50,000 HP
- Crusader respawn remains short (visible respawn within ~10 minutes)

### Fail Criteria

- Lord Yelinak at 500,000 or 297,000 HP (pre-Phase-4a values)
- Crusaders at 233,000 HP

---

## Session 4: Outdoor Velious Dragons

### Targets

| NPC | Zone | HP Target |
|-----|------|-----------|
| Klandicar | westwastes | 40,000 |
| Sontalak | westwastes | 40,000 |
| Zlandicar | necropolis | 35,000 |
| Kelorek`Dar | cobaltscar | 35,000 |
| Harla Dar | westwastes | 28,000 |
| Wuoshi | wakening | 37,000 |
| Lodizal | iceclad | 32,000 |

### Test Steps (priority: Klandicar first — ST key path)

1. `#zone westwastes`
2. `#findnpc Klandicar`
3. `#showstats` — expect 40,000 HP
4. Engage Klandicar — confirm fight is accessible for small group
5. `#findnpc Sontalak` in westwastes — expect 40,000 HP
6. `#zone necropolis` — `#findnpc Zlandicar` — expect 35,000 HP
7. `#zone cobaltscar` — `#findnpc Kelorek` — expect 35,000 HP
8. `#zone wakening` — `#findnpc Wuoshi` — expect 37,000 HP
9. `#zone iceclad` — `#findnpc Lodizal` — expect 32,000 HP

**Respawn spot-check:** After killing any of the 12h-target dragons, note the
respawn timer shown in zone (or check via DB post-kill if needed). Should be ~12h.

### Pass Criteria

- Klandicar, Sontalak at 40,000 HP
- Zlandicar, Kelorek`Dar at 35,000 HP
- All ST key path dragons killable by 1 player + 5 companions

### Fail Criteria

- Any outdoor dragon exceeds architecture HP (97,500 or 110,000 for main three)

---

## Session 5: Plane of Growth — HOLD FOR BUG-001 FIX

**DO NOT TEST until BUG-001 is resolved.**

BUG-001: The killable `#Tunare` (NPC 127098) is at 530,000 HP (unscaled). The
passive trigger NPC `#_Tunare` (127001) was incorrectly scaled to 150,000 HP.

data-expert must apply:
```sql
UPDATE npc_types SET hp = 150000 WHERE id = 127098;
```
followed by `#reloadworld` (or full-stack restart for safety).

**After BUG-001 fix — test steps:**

1. `#zone growthplane`
2. Navigate to `#_Tunare` (the passive NPC in the tree)
3. Engage `#_Tunare` — it should depop and spawn `#Tunare` (127098)
4. `#showstats` on spawned `#Tunare` — expect 150,000 HP (post-fix)
5. **If still at 530,000:** full-stack restart likely needed to flush NPC cache
6. Engage `#Tunare` — confirm fight is appropriate for Phase 4a
7. Other PoG bosses to spot-check:
   - Guardian of Tunare: 80,000 HP
   - Ail the Elder: 60,000 HP, maxdmg 560
   - Rumbleroot: 55,000 HP, maxdmg 560
   - Treah Greenroot: 55,000 HP
   - Guardian of Takish: 60,000 HP
   - Fayl Everstrong: 45,000 HP

### Pass Criteria (post-fix)

- `#Tunare` (combat boss) at ~150,000 HP
- All PoG mid-tier bosses at architecture values
- Full PoG raid cycle completable by small group

---

## Session 6: Velketor's Labyrinth

1. `#zone velketor`
2. Navigate to Velketor the Sorcerer
3. `#showstats` — expect 60,000 HP, maxdmg 680
4. **Verify Sunstrike/Sundering:** During the fight, confirm Velketor casts
   his signature spells (Sunstrike or Sundering). If he does, signature
   mechanics are intact per Decision #11.
5. Navigate to Lord Doljonijiarnimorinar
6. `#showstats` — expect 45,000 HP

### Pass Criteria

- Velketor at 60,000 HP, maxdmg 680
- Velketor still casts Sunstrike or Sundering during combat
- Lord Doljoni at 45,000 HP

---

## Session 7: Siren's Grotto — One-Shot Damage Validation

This session is especially important because Faleniel (maxdmg 950) and Wygrish
(maxdmg 780) were one-shot-risk bosses before Phase 4a (1,900 and 1,575 maxdmg).
Validate that the 50% damage cuts prevent instant-kill hits.

1. `#zone sirens`
2. Navigate to Faleniel of Darkwater
3. `#showstats` — expect 90,000 HP, mindmg 190, maxdmg 950
4. Engage Faleniel — note maximum hit observed on any group member
5. **Pass:** no hit above ~1,050 (expect 950 max per DB; some variance is normal)
6. Navigate to Wygrish
7. `#showstats` — expect 60,000 HP, mindmg 294, maxdmg 780
8. Engage Wygrish — note maximum hit observed

### Pass Criteria

- Faleniel at 90,000 HP, maxdmg ~950 — no instant-kill hits
- Wygrish at 60,000 HP, maxdmg ~780 — no instant-kill hits
- Both killable by 1 player + 5 companions without deaths from single large hits

### Fail Criteria

- Any hit exceeds 1,500 damage (would suggest damage cut did not apply in live zone)

---

## Session 8: Plane of Mischief — Jester (Optional)

1. `#zone mischiefplane`
2. `#findnpc Jester` or navigate to the Jester's tower
3. `#showstats` on `#the_Mischievous_Jester` (126012) — expect 60,000 HP, maxdmg 780
4. Note: Jester is condition=2 gated; confirm it is visible in the zone
5. Engage Jester — confirm fight is accessible

### Pass Criteria

- Jester at 60,000 HP, maxdmg 780
- Jester accessible and killable

---

## Additional Spot-Checks (if time permits)

### Dain Frostreaver IV (thurgadinb)

1. `#zone thurgadinb`
2. `#findnpc Dain`
3. `#showstats` — expect 80,000 HP

Note: Dain is faction-gated (Coldain ally required to enter Icewell).

### Taskmaster Abyott (greatdivide)

1. If you're already in greatdivide for the Ring War:
2. `#findnpc Taskmaster`
3. `#showstats` — expect 30,000 HP

### Chamberlain Krystorf (thurgadinb)

1. Near Dain's area
2. `#showstats` — expect 30,000 HP

---

## Ring War Lever 2 Decision Framework

After completing Session 1 (Ring War), report back with these observations:

| Observation | Action |
|-------------|--------|
| All waves cleared before next wave starts; event completed in < 90 min | Lever 1 sufficient — Phase 4a COMPLETE |
| 1-2 waves overlapping but manageable; event completed in < 120 min | Lever 1 borderline — user decides if Lever 2 worthwhile |
| 3+ consecutive waves overlapping; group overwhelmed | Lever 2 recommended — escalate to user for approval |
| Seneschal Aldikar dies from AOE bleed despite 30k HP | Lever 2 + potential Seneschal further HP review |

**Lever 2 application (if needed):**
lua-expert edits `akk-stack/server/quests/greatdivide/encounters/ring_war.lua`
line 26: `local wave_cooldown_time = 8 * 60 * 1000;`
config-expert runs `#reloadquests` in greatdivide zone.

---

## Rollback Instructions

If Phase 4a changes need to be fully reverted:

1. Confirm `data-expert/sql/08-velious-a-rollback.sql` exists (confirmed in server-side validation)
2. Apply rollback:
   ```bash
   docker exec -i akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq \
     < /path/to/08-velious-a-rollback.sql
   ```
3. `#reloadworld` (via Spire or world telnet port 9000)
4. If ring_war.lua was edited for Lever 2: `git checkout` the original file and `#reloadquests`
5. Verify key boss HP values returned to pre-Phase-4a values

---

## Quick Reference: All Phase 4a HP Targets

| NPC | ID | Zone | HP Target |
|-----|----|------|-----------|
| King Tormax | 113215 | kael | 100,000 |
| Statue of Rallos Zek | 113071 | kael | 50,000 |
| Idol of Rallos Zek | 113341 | kael | 130,000 |
| Derakor the Vindicator | 113118 | kael | 60,000 |
| Lord Yelinak (main) | 114106 | skyshrine | 110,000 |
| Lord Yelinak (variant) | 114618 | skyshrine | 110,000 |
| Skyshrine Crusaders (x4) | 114242-114246 | skyshrine | 50,000 |
| #Tunare (COMBAT BOSS) | 127098 | growthplane | 150,000 (BUG-001 — fix pending) |
| #_Tunare (trigger) | 127001 | growthplane | 150,000 (harmless — not kill target) |
| Guardian of Tunare (x2) | 127007/127106 | growthplane | 80,000 |
| Ail the Elder | 127020 | growthplane | 60,000 |
| Rumbleroot | 127019 | growthplane | 55,000 |
| Treah Greenroot | 127021 | growthplane | 55,000 |
| Guardian of Takish | 127035 | growthplane | 60,000 |
| Fayl Everstrong | 127018 | growthplane | 45,000 |
| Prince Thirneg | 127096 | growthplane | 60,000 |
| #the_Mischievous_Jester | 126012 | mischiefplane | 60,000 |
| Sontalak | 120005 | westwastes | 40,000 |
| Klandicar | 120084 | westwastes | 40,000 |
| Zlandicar | 123115 | necropolis | 35,000 |
| Kelorek`Dar | 117073 | cobaltscar | 35,000 |
| Harla Dar | 120057 | westwastes | 28,000 |
| Mraaka | 120064 | westwastes | 42,000 |
| Melalafen | 120126 | westwastes | 42,000 |
| Velketor the Sorcerer | 112025 | velketor | 60,000 |
| Lord Doljonijiarnimorinar | 112049 | velketor | 45,000 |
| Faleniel of Darkwater | 125070 | sirens | 90,000 |
| Wygrish | 125072 | sirens | 60,000 |
| Wuoshi | 119112 | wakening | 37,000 |
| Lodizal | 110099 | iceclad | 32,000 |
| Taskmaster Abyott | 118088 | greatdivide | 30,000 |
| #Narandi the Wretched | 118145 | greatdivide | 45,000 |
| #Dain Frostreaver IV | 129003 | thurgadinb | 80,000 |
| Chamberlain Krystorf | 129028 | thurgadinb | 30,000 |

**Ring War wave mobs (greatdivide, conditions 3-15):**

| NPC | ID | HP Target |
|-----|----|-----------|
| Kromrif Captain | 118130 | 6,000 |
| Kromrif Recruit | 118160 | 5,000 |
| Kromrif Warrior | 118150 | 7,000 |
| Kromrif General | 118120 | 9,000 |
| Kromrif Priest | 118209 | 12,000 |
| Kromrif Warlord | 118158 | 12,000 |
| Kromrif Veteran | 118156 | 12,000 |
| Kromrif High Priest | 118210 | 15,000 |
| Seneschal Aldikar | 118166 | 30,000 (safety bump) |
