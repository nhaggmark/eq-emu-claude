# Velious Phase 4a — DB Investigation Findings

Date: 2026-04-23 (architect Phase 4a)

Covers live DB state for Phase 4a (Velious non-ToV) raid-scaling. Excludes ToV proper, Sleeper's Tomb, Avatar of War, and Vulak`Aerr (all Phase 4b).

All rows below confirmed via the PEQ content database at schema version 9328.

---

## 1. In-scope Velious non-ToV raid bosses with active spawn2

### Kael Drakkel (3 of 4 — AoW 113457 deferred to 4b)

| ID | Name | L | HP | dmg | AC | MR | Respawn | Special |
|----|------|---|----|-----|-----|----|--------|---------|
| 113215 | King Tormax | 70 | 452,000 | 195-575 | 550 | 105 | 72h | SERQUMCNDf + assist radius 16 + proc 31 |
| 113071 | The Statue of Rallos Zek | 59 | 400,750 | 245-1,100 | 700 | 260 | 54h | SERQMCNIDf + 5% flurry + double attack |
| 113118 | Derakor the Vindicator | 70 | 180,000 | 225-700 | 550 | 35 | **12h** (already) | SERQUMCNDf |

**Triggered (no active spawn2, event-spawned):**
| 113341 | #The Idol of Rallos Zek | 66 | 650,000 | 245-1,100 | 700 | 245 | — | SERTMCNIDf — spawns when Statue dies |

**Deferred to 4b:** 113457 Avatar of War (900k HP, 259,200s respawn, spawns from Idol kill).

### Skyshrine (4 Crusaders + Lord Yelinak x2)

| ID | Name | L | HP | dmg | Respawn | Notes |
|----|------|---|----|-----|---------|-------|
| 114106 | Lord Yelinak (main) | 70 | 500,000 | 204-804 | 72h | Active spawn2 (spawngroup 15292) |
| 114618 | Lord Yelinak (variant) | 70 | 297,000 | 204-804 | 72h | Active spawn2 (spawngroup 113099) — both live per DB sweep |
| 114242 | Charayan the Crusader | 70 | 233,000 | 125-410 | **10.7min** | Short respawn — group fight |
| 114243 | Susarrak the Crusader | 70 | 233,000 | 125-410 | 10.7min | " |
| 114245 | Grendish the Crusader | 70 | 233,000 | 125-410 | 10.7min | " |
| 114246 | Jortreva the Crusader | 70 | 233,000 | 125-410 | 10.7min | Missing special_attacks string — likely PEQ artifact |

**Yelinak duplicate resolution:** both 114106 (500k HP) and 114618 (297k HP) have active spawn2 rows with `_condition=0` (always spawn). No spawn_conditions table entries exist for skyshrine. Both live per DB sweep. Recommended: scale both for consistency (same target values).

### Plane of Growth — growthplane (named bosses + event triggers)

| ID | Name | L | HP | dmg | Respawn | Notes |
|----|------|---|----|-----|---------|-------|
| 127001 | #_Tunare | 66 | 530,000 | 166-926 | 72h | Final boss; special_abilities `f` (flurry) |
| 127007 | Guardian of Tunare | 60 | 310,000 | 92-187 | 18h | AE rampage (`m`) |
| 127106 | Guardian of Tunare (dup) | 60 | 310,000 | 92-187 | 18h | Duplicate, both live |
| 127020 | Ail the Elder | 60 | 215,000 | 130-700 | 18h | — |
| 127019 | Rumbleroot | 60 | 193,000 | 130-700 | 18h | — |
| 127021 | Treah Greenroot | 60 | 191,000 | 130-700 | 18h | — |
| 127035 | Guardian of Takish | 70 | 200,000 | 96-210 | 24h | — |
| 127018 | Fayl Everstrong | 60 | 150,000 | 130-700 | 18h | — |
| 127096 | Prince Thirneg | 65 | 69,719 | 82-196 | 18h | Mid-tier (near named) |

**Event triggers — DO NOT SCALE:**
| 127004 | a_warm_light | **1** | 1,000,000 | 2-9 | 18h | 8 spawn2 rows; non-combat event trigger (low damage passive) |
| 127005 | a_thifling_focuser | 65 | 1,000,000 | 100-233 | 18h | 2 spawn2; flawed spawn (no damage attacks) |
| 127006 | a_thifling_focuser (variant) | 65 | 1,000,000 | 100-233 | 18h | 2 spawn2 |

Per audit and lore-master Section 6: these are "event control NPCs" that trigger Tunare spawn mechanics. Leave untouched.

### Plane of Mischief — mischiefplane

| ID | Name | L | HP | Respawn | Notes |
|----|------|---|----|---------|-------|
| 126012 | #the_Mischievous_Jester | 70 | 200,000 | 78h | `_condition=2` gated; IN-ERA |
| 126160 | #Bristlebane | **75** | 1,000,000 | 96h | **OUT-OF-ERA** — LoN/PoP revamp. SKIP. |
| 126374 | All-Seeing Eye | **75** | 709,000 | 20min | **OUT-OF-ERA** — L75. SKIP. |

Per audit decision rule: only L55-70 in-era content. Bristlebane and All-Seeing Eye both exceed.

### Outdoor Velious dragons

**Western Wastes (in-scope raid-tier):**
| ID | Name | L | HP | dmg | Respawn | Notes |
|----|------|---|----|-----|---------|-------|
| 120005 | Sontalak | 70 | 97,500 | 140-425 | 72h | First Brood / Sleeper's Tomb key path |
| 120084 | Klandicar | 70 | 97,500 | 198-540 | 72h | First Brood / ST key path |
| 120057 | Harla Dar | 66 | 65,000 | 96-305 | 5h | Already near named-tier + short respawn |
| 120064 | #Mraaka | 66 | 60,000 | 149-320 | 6h | Already near named-tier + short respawn |
| 120126 | Melalafen | 65 | 70,000 | 192-504 | 54h | |

**NOT in scope — already named-tier per audit (leave alone):**
westwastes contains ~25 additional "dragon" named at 24k-50k HP (Bratavar, Cargalia, Derasinal, etc.) — audit explicitly calls out "most in named-tier range; no action or minor trim." Prior-pass globals already apply. Per Decision #2 trash/named untouched.

**Out-of-era westwastes NPCs (confirmed exclusions):**
- 120133 Sir Elmonious Falmont L70 400k HP / 500-3,667 dmg — PoP tier damage, SKIP
- 120127 a_wayward_wyvern L70 78k HP raid_target=0 — trash-elite

**Dragon Necropolis:**
| ID | Name | L | HP | dmg | Respawn | Notes |
|----|------|---|----|-----|---------|-------|
| 123115 | Zlandicar | 70 | 110,000 | 157-366 | 72h | First Brood / ST key path |
| 123011 | Jaled Dar's Shade | 70 | 3,002,000 | 250-900 | 640s | **Quest-NPC, not kill target.** Lore-master confirms. LEAVE 3M HP as uncombattable design. |

**Cobaltscar / Velketor / Iceclad / Wakening:**
| ID | Name | L | HP | dmg | Zone | Respawn | Notes |
|----|------|---|----|-----|------|---------|-------|
| 117073 | Kelorek`Dar | 65 | 100,000 | 63-219 | cobaltscar | 54h | |
| 112025 | Velketor the Sorcerer | 66 | 201,500 | 185-850 | velketor | 72h | DT check: special_abilities has `1,1,6000,100` (proc-based ability), not DT |
| 112049 | Lord Doljonijiarnimorinar | 65 | 147,000 | 195-480 | velketor | 18h | |
| 119112 | Wuoshi | 64 | 46,000 | 204-584 | wakening | 54h | Near named-tier |
| 110099 | Lodizal | 60 | 40,561 | 110-300 | iceclad | 9h | Velious Shawl giver; near named-tier |

**Sirens Grotto:**
| ID | Name | L | HP | dmg | Respawn | Notes |
|----|------|---|----|-----|---------|-------|
| 125070 | #Faleniel of Darkwater | 70 | 300,000 | 380-1,900 | 2h | Short respawn already; max dmg 1,900 = one-shot risk |
| 125072 | Wygrish | 68 | 200,000 | 587-1,575 | 2h | Short respawn; max dmg 1,575 = one-shot risk |

### Coldain Ring War zone — greatdivide

| ID | Name | L | HP | dmg | Respawn | Notes |
|----|------|---|----|-----|---------|-------|
| 118145 | #Narandi the Wretched | 65 | 150,000 | 195-480 | 208h | `_condition=16` (RingWarWave15 end) — script-spawned during Ring War |
| 118088 | Taskmaster Abyott | 62 | 72,000 | 88-278 | 18h | `_condition=1` (ColdainWar=1, always enabled); near named-tier |

### Icewell Keep — thurgadinb (Coldain faction-gated)

| ID | Name | L | HP | dmg | Respawn | Notes |
|----|------|---|----|-----|---------|-------|
| 129003 | #Dain Frostreaver IV | 70 | 352,000 | 160-350 | 120h | Ring War quest giver + Ring 10 terminus; faction-gated |
| 129028 | Chamberlain Krystorf | 60 | 80,000 | 125-315 | 18h | |

---

## 2. Excluded from Phase 4a (confirmed)

### Out-of-era (level 72+ or post-PoP content)
- 116605 #An Egg Hunter L75 eastwastes — LoN anniversary
- 116607 A Legendary Velious Dragon L72 eastwastes — LoN
- 119165 #Lantaric`Dar L70 wakening 800k HP 0-4 dmg — event trigger (passive)
- 57156 Scout Leader Plavo L70 wakening 300k HP — OUT-OF-ERA check (Lesser Faydark range)
- 120133 Sir Elmonious Falmont L70 westwastes 3,667 max dmg — PoP tier
- 126160 #Bristlebane L75 mischiefplane — OUT-OF-ERA
- 126374 All-Seeing Eye L75 mischiefplane — OUT-OF-ERA

### Quest-NPC (not kill target)
- 123011 Jaled Dar's Shade 3M HP — Sleeper's Tomb key turn-in

### Named-tier (Decision #2: trash/named untouched)
- 110104 Giligatabbus Igglebix L66 100k iceclad (raid_target=0, named)
- 114564 The Seer L63 500k skyshrine (raid_target=0, bodytype=26 "ghost/untargetable")
- 120127 a_wayward_wyvern L70 78k westwastes (raid_target=0)
- 126210 My Right Hand L63 60k mischiefplane (raid_target=0)
- ~25 westwastes dragons L51-62 24-50k HP (prior-pass already applies globals)
- ~95 growthplane raid_target=1 but L48-65 at 14k-40k HP = trash/named per audit
- 110037 Corudoth iceclad L5 60k HP oddity (non-combat by level)

### Event-trigger NPCs
- 127004 a_warm_light growthplane (8 rows, 1M HP, 2-9 dmg = passive)
- 127005/127006 a_thifling_focuser growthplane (trigger-NPCs for Tunare event)

### 4b scope (deferred)
- All ToV (124xxx range): 124103, 124076, 124074, 124008, 124071, 124010, 124037, 124077, 124017, 124020, 124011, 124104, 124105, 124001, 124072, 124004 + ToV mid-tier (Midayor/Grozzmel/etc. at 124030-124040, 124030-40 range, 124050-52 defenders) + Vulak 124155 + 124018 Cyndor, 124007 Yrrindor, 124107 Vyldin, 124106 Kalkar, 124073 Zlexak, 124075 Sevalak, 124003 Zyerek, 124009 Malteor
- All Sleeper (128xxx): 128040-45, 128089-95, 128143-45 + Drakonine trash
- 113457 Avatar of War

---

## 3. Ring War (Q8) script investigation

**Script path:** `akk-stack/server/quests/greatdivide/encounters/ring_war.lua` (293 lines)

### Event mechanics

- **Master NPC:** 118173 `ringtenmaster` — invisible/control NPC
- **Trigger:** Handing item 18511 to 118167 `Zrelik_the_Scout` starts the event
- **Wave structure:** Uses `spawn_conditions` table in `greatdivide` zone:
  - Condition 1 `ColdainWar` (default 1 = zone normal state)
  - Conditions 2-22 = `RingWarWave1` through `RingWarWave21` (21 condition slots; only 14 are used for wave gating)
- **Wave cadence:** One literal at line 26: `local wave_cooldown_time = 5 * 60 * 1000;` (5 minutes between waves)
- **Wave advancement:** `Master_Signal` with signal=2 (from wave master death) sets 5-min timer → timer fires → increments `current_spawn_condition` → calls `eq.spawn_condition("greatdivide", 0, current_spawn_condition, 1)` to activate next wave

### Actual wave composition (from DB)

| Wave cond | Spawn rows | Wave mobs |
|-----------|-----------|-----------|
| 2 | 59 | Kromrif Spearman, Royal Soldier, Seneschal Aldikar (background zone state during war) |
| 3 | 6 | Kromrif Captain (wave master) + Kromrif Recruit |
| 4 | 6 | same |
| 5 | 6 | same |
| 6 | 17 | Kromrif Captain + Kromrif Recruit (Round 1 bulk) |
| 7 | 18 | same |
| 8 | 11 | same |
| 9 | 15 | Kromrif General (wave master) + Kromrif Priest + Kromrif Warrior (Round 2) |
| 10 | 20 | same |
| 11 | 14 | same |
| 12 | 19 | same |
| 13 | 17 | Kromrif High Priest + Kromrif Veteran + Kromrif Warlord (wave master) (Round 3) |
| 14 | 24 | same |
| 15 | 17 | same |
| 16 | 1 | **#Narandi the Wretched** |

**Total:** 13 wave slots + Narandi. Total wave mob count before Narandi: **~190 giants.**

### Wave NPC stats (for DPS-vs-HP calculation)

| NPC | L | HP | dmg |
|-----|---|-----|-----|
| Kromrif Recruit 118160 | 48 | 7,000 | 34-97 |
| Kromrif Captain 118130 | 52 | 10,000 | 42-120 |
| Kromrif Warrior 118150 | 53 | 11,000 | 44-122 |
| Kromrif General 118120 | 56 | 13,000 | 51-130 |
| Kromrif Priest 118209 | 53 | 27,500 | 36-99 |
| Kromrif Veteran 118156 | 58 | 42,500 | 73-170 |
| Kromrif Warlord 118158 | 60 | 20,000 | 64-288 |
| Kromrif High Priest 118210 | 60 | 50,000 | 90-290 |
| Kromrif Spearman 118138 | 52 | 13,500 | 42-120 |
| Royal Soldier 118134 | 42 | 2,750 | 16-90 |
| #Narandi the Wretched 118145 | 65 | 150,000 | 195-480 |

### Key findings

- **Wave count is spawn-condition-driven (DB-gated), not hardcoded in Lua.** Lua increments `current_spawn_condition` and calls `eq.spawn_condition()` — if conditions 3-8 are removed from the DB (no spawn2 rows exist for them), Master_Timer still advances through them but finds nothing to spawn.
- **Wave cadence is parameterized** via ONE literal line in Lua (`wave_cooldown_time`). Simple edit.
- **No 30-min hard timeout.** The "30 minutes" from lore-master/audit was the community-source estimate of event duration, not a hardcoded timer. Fail is: Seneschal Aldikar (118166) dies, OR pathing — though no pathing-fail handler is visible in the script.
- **Kromrif wave mobs are raid_target=0** — they are "trash-tier" per Decision #2. Technically they would not be scaling targets. But they ARE the event gate per lore-master.

### Lever options (ordered by minimal blast radius)

- **Lever A — reduce cadence.** `wave_cooldown_time = 3 * 60 * 1000` (3 min). Single-line Lua change. Event completes faster; wave count unchanged.
- **Lever B — skip waves via script.** Modify `Master_Timer` to advance `current_spawn_condition` by 2 or 3 instead of 1 (skipping waves). Small Lua change. Doesn't touch DB or wave mob stats.
- **Lever C — reduce wave mob HP.** Decision #2 says trash untouched — but these are event-specific wave mobs. Arguable whether they count as "event raid content" (in scope) or "trash" (out of scope). **User decision needed.**
- **Lever D — skip entire rounds.** DELETE spawn2 rows for conditions 3-8 (Round 1 Kromrif Captains/Recruits). Event goes Generals → Warlords → Narandi. Blast radius is larger (DB schema; also breaks Ring War "feel").

### Recommendation (architect pending lore-master review)

**Lever A + B combined:** reduce `wave_cooldown_time` to 2 minutes AND have Master_Timer advance condition by 2 each fire (skipping every other wave). Net effect: ~7 waves instead of 13, 2-min cadence instead of 5-min, event completes in ~14 minutes of wave-clear time + Narandi fight. Lowest blast radius (two-line Lua change), preserves event progression feel. Pending lore-master recommendation.

**Alternative cleaner recommendation:** Lever B alone with advance-by-2, keep 5min cadence for pacing/feel. Event completes ~6-7 waves × 5min = 30-35min (matches original "30 min" audit estimate) with halved mob count. Script change is:

```lua
-- In Master_Timer:
current_spawn_condition = current_spawn_condition + 2;  -- was: + 1
if (current_spawn_condition > 15) then
    current_spawn_condition = 16;  -- ensure Narandi wave fires
end
eq.spawn_condition("greatdivide", 0, current_spawn_condition, 1);
```

---

## 4. Velious epic steps (Phase 4a scope confirmation)

Per lore-master Section 5 (velious-chains.md): **"The Epic 1.0 quests for all 14 classes have NO quest steps that require kills in Velious zones."**

Per audit Section 1801-1806: all 14 class Epic 1.0 chains complete in Classic + Kunark; Velious progression is its own ecosystem (Coldain Rings, Kael/ToV/ST access, Halls of Testing) that does not cross over into epic dependency.

**No Velious epic-boss touch-ups needed.** Decision #14 applies: class-gated steps stay as-is; no epic-boss work in Phase 4a.

---

## 5. Coldain Prayer Shawl

- Quest chain exists (scripts in `akk-stack/server/quests/thurgadina/Loremaster_Borannin.pl` etc.)
- **NOT a raid event.** Chain of item turn-ins: Kromrif toes → burlap shawl → preserved Kromrif heads → cloth shawl → Thoridain's Seal → woven shawl → Tanik's note (rescue) → fur-lined shawl → etc.
- Kills required are individual Kromrif giants (not raid-tier) and maybe Tanik rescue (named-tier)
- No scripted event, no wave structure, no timer
- **Out of Phase 4a raid-scaling scope** — boss-stats scaling does not affect this chain

Per audit line 2074-2083: "Prayer Shawl event" mentioned as potentially having "mechanic-scripted add waves" — but **this is incorrect** per my review of the scripts. The Prayer Shawl is turn-in driven, not a scripted wave event. No Phase 4a action needed.

---

## 6. Ring 8 / Ring 9 / Ring 10 failure-reset UX

Lore-master flagged Ring 8 failure (Chief Ry'Gorr 4-min kill window) as resetting Rings 1-7, and Ring 9 Juliash 10-minute timer. These are **script-level UX concerns**, not scaling levers:

- All Ring 4-9 named encounters are raid_target=0 at 870-6,000 HP (per DB check). Not raid-tier.
- Ring 8 "Chief Ry'Gorr" (116165 L45 3,272 HP, 116577 # variant L45 5,650 HP) is not a raid fight — difficulty is the failure-reset UX, not boss stats.
- Scaling cannot fix Ring 8 reset behavior; that's a script change.

**Recommendation:** out of Phase 4a scope (Phase 4a is boss-stats + respawn, not script-UX). User can raise a separate decision for UX softening if desired.

---

## 7. Phase 4a target values (preliminary — architect to finalize in main doc)

All targets align with audit recommendations + Decision #5 respawn tier (Velious non-ToV = mid-tier = 12h = 43,200s).

### Endgame-adjacent (Kael + Skyshrine Yelinak + Growth final + WW dragons)

| ID | Name | Current HP | Target HP | Current max dmg | Target max dmg | Current respawn | Target respawn |
|----|------|------------|-----------|-----------------|----------------|------------------|----------------|
| 113215 | King Tormax | 452,000 | 100,000 (-78%) | 575 | 575 (keep) | 72h | 12h |
| 113071 | Statue of Rallos Zek | 400,750 | 50,000 (-87%) | 1,100 | 500 (-55%) | 54h | 12h |
| 113341 | Idol of Rallos Zek (triggered) | 650,000 | 130,000 (-80%) | 1,100 | 700 (-36%) | — | — (script) |
| 113118 | Derakor the Vindicator | 180,000 | 60,000 (-67%) | 700 | 560 (-20%) | 12h | 12h (keep) |
| 114106 | Lord Yelinak main | 500,000 | 110,000 (-78%) | 804 | 804 (keep) | 72h | 12h |
| 114618 | Lord Yelinak variant | 297,000 | 110,000 (-63%) | 804 | 804 (keep) | 72h | 12h |
| 127001 | #_Tunare | 530,000 | 150,000 (-72%) | 926 | 926 (keep) | 72h | 12h |

### Mid-tier (Growth minor bosses + Skyshrine Crusaders + outdoor dragons)

| ID | Name | Current HP | Target HP | Target max dmg | Respawn |
|----|------|------------|-----------|----------------|---------|
| 114242-46 | Skyshrine Crusaders (4) | 233,000 | 50,000 (-78%) | 410 (keep) | 640s (keep — already short) |
| 127007/106 | Guardian of Tunare (dup) | 310,000 | 80,000 (-74%) | 187 (keep) | 18h (keep — already short) |
| 127020 | Ail the Elder | 215,000 | 60,000 (-72%) | 560 (-20%) | 18h (keep) |
| 127019 | Rumbleroot | 193,000 | 55,000 (-72%) | 560 (-20%) | 18h (keep) |
| 127021 | Treah Greenroot | 191,000 | 55,000 (-72%) | 560 (-20%) | 18h (keep) |
| 127035 | Guardian of Takish | 200,000 | 60,000 (-70%) | 210 (keep) | 24h (keep) |
| 127018 | Fayl Everstrong | 150,000 | 45,000 (-70%) | 560 (-20%) | 18h (keep) |
| 127096 | Prince Thirneg | 69,719 | 60,000 (-14% trim) | 196 (keep) | 18h (keep) |
| 125070 | Faleniel (Siren) | 300,000 | 90,000 (-70%) | 950 (-50% from 1,900) | 2h (keep) |
| 125072 | Wygrish (Siren) | 200,000 | 60,000 (-70%) | 780 (-50% from 1,575) | 2h (keep) |
| 112025 | Velketor the Sorcerer | 201,500 | 60,000 (-70%) | 680 (-20%) | 72h | 12h |
| 112049 | Lord Doljonijiarnimorinar | 147,000 | 45,000 (-69%) | 480 (keep) | 18h (keep) |
| 129003 | #Dain Frostreaver IV | 352,000 | 80,000 (-77%) | 350 (keep) | 120h | 12h |
| 120005 | Sontalak | 97,500 | 40,000 (-59%) | 425 (keep) | 72h | 12h |
| 120084 | Klandicar | 97,500 | 40,000 (-59%) | 540 (keep) | 72h | 12h |
| 123115 | Zlandicar | 110,000 | 35,000 (-68%) | 366 (keep) | 72h | 12h |
| 118145 | #Narandi the Wretched | 150,000 | 45,000 (-70%) | 480 (keep) | 208h (event) | — (script-spawned, condition gated) |
| 117073 | Kelorek`Dar | 100,000 | 35,000 (-65%) | 219 (keep) | 54h | 12h |
| 126012 | #the_Mischievous_Jester | 200,000 | 60,000 (-70%) | 780 (-45% from 1,431) | 78h | 12h |

### Near-named-tier (small trim only)

| ID | Name | Current HP | Target HP | dmg | Respawn |
|----|------|------------|-----------|-----|---------|
| 120057 | Harla Dar | 65,000 | 28,000 (-57%) | 305 (keep) | 5h (keep) |
| 120064 | #Mraaka | 60,000 | 42,000 (-30%) | 320 (keep) | 6h (keep) |
| 120126 | Melalafen | 70,000 | 42,000 (-40%) | 504 (keep) | 54h | 12h |
| 110099 | Lodizal | 40,561 | 32,000 (-20%) | 300 (keep) | 9h (keep) |
| 119112 | Wuoshi | 46,000 | 37,000 (-20%) | 584 (keep) | 54h | 12h |
| 118088 | Taskmaster Abyott | 72,000 | 30,000 (-58%) | 278 (keep) | 18h (keep) |
| 129028 | Chamberlain Krystorf | 80,000 | 30,000 (-63%) | 315 (keep) | 18h (keep) |

### Untouched (per decision / lore)

| ID | Name | Reason |
|----|------|--------|
| 123011 | Jaled Dar's Shade | Quest-NPC, 3M HP by design (uncombattable) |
| 127004 | a_warm_light | Event trigger (L1 1M HP passive) |
| 127005/6 | a_thifling_focuser | Event trigger NPCs |
| 119165 | #Lantaric`Dar | Event trigger (0-4 damage) |
| 126160 | #Bristlebane | Out-of-era (L75) |
| 126374 | All-Seeing Eye | Out-of-era (L75) |
| 116605 | #An Egg Hunter | Out-of-era (L75, LoN) |
| 116607 | A Legendary Velious Dragon | Out-of-era (LoN) |
| 120133 | Sir Elmonious Falmont | Out-of-era (PoP-tier damage 3,667) |
| 57156 | Scout Leader Plavo | Out-of-era (Lesser Faydark ID range) |

---

## 8. Expected change footprint

- **npc_types:** ~35 UPDATE rows (27 main scope + 4 Crusaders + 4 mid-trim)
- **spawn2:** ~20-25 respawn UPDATEs (12h mid-tier, skipping already-short respawns)
- **npc_spells_entries:** likely 0 changes (audit found no explicit Cazic-Touch-profile spells in Velious — to be confirmed in main doc)
- **Lua:** 1 file — `akk-stack/server/quests/greatdivide/encounters/ring_war.lua` — Ring War pacing change (pending lore-master approval on lever A+B)
- **Backups:** `npc_types_backup_raid_scaling_velious_a`, `spawn2_backup_raid_scaling_velious_a`, `ring_war_lua_backup_velious_a` (text snapshot of Lua file pre-change)

---

## 9. Open architect items (final decisions pending)

1. Coldain Ring War lever — pending lore-master final A/B/C recommendation
2. Death-touch sweep — verify zero DT-profile spells in Velious non-ToV raid NPC spell lists (architect to run before implementation dispatch)
3. Yelinak duplicate — should both 114106 AND 114618 be scaled? DB shows both live with independent spawngroups. **Architect recommendation: scale both to 110k HP for consistency.** Audit original text flagged one as possibly deprecated but DB shows both active.
