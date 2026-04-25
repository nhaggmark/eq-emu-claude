# Luclin non-VT (Phase 5a) — DB Investigation

> **Author:** architect
> **Date:** 2026-04-22
> **Scope:** Ssraeshza Temple, Akheva Ruins, Sanctus Seru/Katta Castellum, Grieg's End, Umbral Plains, Acrylia Caverns, The Deep, Echo Caverns, and Grimling Forest (for Khati Sha). Vex Thal proper and Yaemiu elite trash are **Phase 5b**.
> **Authoritative files consulted:** `npc_types`, `spawn2`, `spawnentry`, `spawn_conditions`, `npc_spells_entries`, `spells_new`, `zone`, plus Lua/Perl scripts under `akk-stack/server/quests/`.

This document is the DB-grounded scope and data dossier feeding `architect/luclin-a-architecture.md`.

---

## 1. Zone confirmation

| zone short_name | zone id | long_name | expansion | ruleset | version | Phase |
|---|---|---|---|---|---|---|
| `ssratemple` | 162 | Ssraeshza Temple | 3 | 1 | 0 | **5a** |
| `akheva` | 179 | The Akheva Ruins | 3 | 1 | 0 | **5a** |
| `sseru` | 159 | Sanctus Seru | 3 | 1 | 0 | **5a** |
| `katta` | 160 | Katta Castellum | 3 | 1 | 0 | **5a** |
| `griegsend` | 163 | Grieg's End | 3 | 1 | 0 and 1 | **5a** |
| `acrylia` | 154 | The Acrylia Caverns | 3 | 1 | 0 | **5a** |
| `thedeep` | 164 | The Deep | 3 | 1 | 0 | **5a** |
| `umbral` | 176 | The Umbral Plains | 3 | 1 | 0 | **5a** |
| `echo` | 153 | The Echo Caverns | 3 | 1 | 0 | **5a** |
| `grimling` | 167 | Grimling Forest | 3 | 1 | 0 | not in 5a (Khati Sha is in acrylia, not grimling) |
| `vexthal` | 158 | Vex Thal | 3 | 1 | 0 | **5b** |

**Audit note resolved:** The audit tentatively placed Khati Sha the Twisted in `grimling?`. Script path `akk-stack/server/quests/acrylia/Khati_Sha_the_Twisted.lua` confirms **zone is `acrylia`** (Acrylia Caverns) — she is the inner-Acrylia raid boss.

**Zone version quirk:** `griegsend` has TWO rows in `zone` — version 0 and version 1. Both `ruleset = 1`, `expansion = 3`. This is not a DZ/instance — it's a static zone revision pair, common in PEQ (dungeon layout iterations). Confirmed by the spawn2 distribution: `Grieg_Veneficus 163097` at spawn2 id 37534 / respawn 259,200s is on one version; `#Grieg_Veneficus 163231` at spawn2 id 3265605 / respawn 561,600s is on the other. Phase 5a treats both as a single scaling target (main boss is the 163075 ID).

All Phase 5a zones use `ruleset = 1` (default), `min_status = 0`, `expansion = 3`. **No custom rulesets.**

---

## 2. spawn_conditions state

**No Phase 5a zones use raid-gate-style spawn conditions** like sleeper's condition 1 (Warders) / condition 2 (Ancients). The only `spawn_conditions` rows in Phase 5a zones are:

| zone | id | value | onchange | name |
|---|---|---|---|---|
| `dawnshroud` | 1 | 0 | 2 | Sambata |
| `dawnshroud` | 2 | 1 | 2 | Rockhopper |
| `grimling` | 1 | 1 | 2 | Grimling |
| `grimling` | 2 | 0 | 2 | Warwon |
| `hollowshade` | 1-13 | 1 | 2 | North/East/South/Camp Owl/Wolf/Grimling (zone-wide rotating waves, not raid gates) |

None of these affect Phase 5a raid bosses. `ssratemple`, `akheva`, `sseru`, `katta`, `griegsend`, `acrylia`, `thedeep`, `umbral`, `echo` have **zero** `spawn_conditions` rows.

**Implication:** Emperor Ssraeshza's event-gated respawn is NOT driven by `spawn_conditions`; it's driven entirely by `#EmpCycle.pl` using `qglobals` (`Emperor`, `BloodCoolDown`) and `quest::unique_spawn`. Same for Vyzh`dra, Doomshade, Khati Sha, Grieg Veneficus script-spawned variant, Arch Lich Rhag`Zadune, Rhag`Mozdezh.

---

## 3. Phase 5a boss catalog — DB-verified

### 3.1 Ssraeshza Temple (ssratemple) — ~30 scope NPCs

**Script-spawned (no spawn2 row):**

| npc_id | name | level | hp | mindmg/maxdmg | AC/MR | special_abilities | npcspecialattks | npc_spells_id | Script |
|---|---|---|---|---|---|---|---|---|---|
| 162227 | #Emperor_Ssraeshza_ (REAL) | 66 | **1,250,500** | 283 / 904 | 650 / 386 | `1^2^3,1,10^7^13^14^15^16^17^21^22^23^31^32,1,290` | SERQMCNIDfWO | **227** | `#Emperor_Ssraeshza_.pl` (via `#EmpCycle.pl`) |
| 162065 | #Emperor_Ssraeshza (PLACEHOLDER, no-target) | 66 | 6,516 | 0 / 4 | 588 / 679 | `19^20^21` | AB | 0 | `#EmpCycle.pl` spawn — DO NOT SCALE (non-combat phase trigger) |
| 162189 | #Blood_of_Ssraeshza | 63 | **200,000** | 170 / 550 | 620 / 80 | `1^2^5,1,25^13^14^15^16^17^21^31` | SERFQMCNIDf | 3625 | `#Blood_of_Ssraeshza.lua` — gate mob |
| 162064 | #Ssraeshzian_Blood_Golem | 63 | **201,000** | 170 / 550 | 620 / 80 | `1^2^5^13^14^15^16^17^21^31` | SERFQMCNIDf | 3625 | `#Ssraeshzian_Blood_Golem.lua` — failure-retry gate |
| 162177 | #Arch_Lich_Rhag\`Zadune | 64 | **790,000** | 275 / 664 | 700 / 160 | `1^2^3,1,60^12^13^14^15^16^17^21^42` | SERUMCNIDf | 176 | event-spawned |
| 162192 | #Rhag\`Mozdezh | 63 | **226,000** | 270 / 574 | 900 / 60 | `1^2^3,1,45^12^13^14^15^16^17^21^42` | SERTUMCNIDf | 175 | event-spawned |
| 162253 | #a_rune_covered_serpent | 63 | **221,000** | — | — | — | — | 190 | script-spawned raid_target=1 — NEW FIND (not in audit). Lore-master consult needed. |
| 162261 | #a_glyph_covered_serpent | 63 | **300,000** | — | — | — | — | 190 | script-spawned raid_target=1 — NEW FIND (not in audit). Lore-master consult needed. |

**spawn2-backed (standing spawns):**

| npc_id | name | level | hp | mindmg/maxdmg | AC/MR | npc_spells_id | spawn2 respawntime |
|---|---|---|---|---|---|---|---|
| 162076 | High_Priest_of_Ssraeshza | 66 | **941,000** | 277 / 722 | 750 / 95 | 202 | 259,200s (72h) |
| 162190 | Xerkizh_The_Creator | 66 | **806,516** | 275 / 674 | 900 / 165 | 203 | 259,200s (72h) |
| 162178 | #Rhag\`Zhezum | 63 | **201,000** | 168 / 310 | 850 / 60 | 174 | 194,400s (54h) |
| 162066 | #General_Kizuhx | 53 | **250,000** | 168 / 510 | 450 / 77 | 3613 | 1,080s (18m) × 17 spawn2 rows (static named floor) |
| 162067 | #Advisor_Zekuzh | 53 | **150,000** | 163 / 410 | 395 / 34 | 208 | 1,080s × 17 |
| 162191 | #Arbiter_Korazhk | 55 | **205,000** | 168 / 510 | 409 / 43 | 1 | 1,080s × 17 |
| 162258 | #Rhozth_Ssrakezh | 60 | 119,000 | 142 / 523 | 262 / 54 | 210 | 5,400s (1.5h) |
| 162089 | #Rhozth_Ssravizh | 60 | 105,200 | 142 / 284 | 262 / 54 | 209 | 21,600s (6h) |

**Taskmasters (raid_target=1, 50.2k HP, 5,400s respawn — already elite-named tier, NOT in Phase 5a scope):**
- 162011 Taskmaster_Zerumaz, 162013 Taskmaster_Mikazha, 162021 Taskmaster_Keuzozh, 162024 Taskmaster_Vezhkah, 162059 Taskmaster_Zhe\`Vozh, 162060 Taskmaster_Revan\`Kezh — treat as elite trash per Decision #2.
- 162012 Taskmaster_Kavamezh (32.2k HP) — elite trash.
- 162023 Warden_Mekuzh (33k HP, raid_target=1) — elite named, not raid-tier. Lore-master `luclin-chains.md` Section 2 confirmed (Ring of the Shissar Taskmaster's Pouch source).

**Phase 5a scope for ssratemple:** 13 scaling targets (8 script-spawned + 5 standing-spawn bosses + 3 static pre-Emperor named L53/55). Plus 2 newly-discovered scripted serpents (162253, 162261) flagged for lore-master.

### 3.2 Akheva Ruins (akheva) — 8 scope NPCs

**Script-spawned (no spawn2):**

| npc_id | name | level | hp | mindmg/maxdmg | AC/MR | npc_spells_id | Script |
|---|---|---|---|---|---|---|---|
| 162206 | #Vyzh\`dra_the_Cursed | 66 | **900,000** | 271 / 588 | 900 / 135 | **197** | `#Vyzh-dra_the_Cursed.lua` (ssratemple quest dir — zone is akheva per lore-master) |
| 162232 | #Vyzh\`dra_the_Exiled | 63 | **450,000** | 267 / 624 | — / — | **196 (DT)** | `#Vyzh-dra_the_Exiled.lua` |
| 162214 | #Vyzh\`dra_the_Banished | 63 | **403,000** | 305 / 704 | — / — | **196 (DT)** | `#Vyzh-dra_the_Banished.pl` |

**spawn2-backed:**

| npc_id | name | level | hp | mindmg/maxdmg | AC/MR | npc_spells_id | spawn2 respawntime |
|---|---|---|---|---|---|---|---|
| 179037 | The_Itraer_Vius | 63 | **601,000** | 220 / 600 | 600 / 60 | 173 | 210,924s (58h) |
| 179134 | #Shar_Vinitras | 63 | **460,900** | 250 / **1,010** | 466 / 190 | 178 | 10,800s (3h) ← short-tier natural |
| 179157 | #Shei_Vinitras_ | 65 | **400,000** | 145 / 400 | 481 / 56 | 0 | 194,474s (54h) |
| 179180 | #The_Insanity_Crawler | 63 | **401,000** | 174 / 573 | 650 / 80 | 180 | 210,924s (58h) |
| 179178 | The_Va\`Dyn | 63 | **250,000** | 240 / 525 | 670 / 75 | 1350 | 194,400s (54h) |
| 179133 | Sheleric_Vis | 61 | 116,000 | 176 / 746 | 267 / 190 | 3082 | 5,400s (1.5h) × 2 spawn2 — elite named tier |
| 179046 | Sheleric_Vis (variant) | 62 | 70,000 | 59 / 173 | 271 / 190 | 0 | 5,400s × 2 — elite named tier |
| 179044 | Xaui_Tatrua | 60 | 70,000 | 110 / 376 | 262 / 24 | 1 | 5,400s — elite named tier |

**Phase 5a scope for akheva:** 8 primary bosses (3 Vyzh\`dra variants + Itraer Vius + Shar Vinitras + Shei Vinitras + Insanity Crawler + Va\`Dyn). Sheleric Vis and Xaui Tatrua are elite named at 70-116k — flag for user decision / treat as Decision #2 elite-trash.

**DT FINDING:** `spell list 196` contains spell **2859 Touch of Vinitras** (base_value1 = **-20,000**, mana 0, cast 0, recast 120s) — DEATH TOUCH profile. Used by Vyzh\`dra the Exiled (162232) and Vyzh\`dra the Banished (162214). Phase 5a must **DELETE** the spell 2859 row from `npc_spells_entries` where `npc_spells_id = 196` — follows Phase 2 Decision #16 pattern (Cazic Touch DELETE) and Decision #13 PoSky DT precedent. List 197 (Vyzh\`dra the Cursed) is clean — no DT.

### 3.3 Sanctus Seru (sseru) + Katta Castellum (katta) — 7 scope NPCs

All spawn2-backed.

| npc_id | name | zone | level | hp | mindmg/maxdmg | AC/MR | npc_spells_id | spawn2 respawntime |
|---|---|---|---|---|---|---|---|---|
| 159691 | #Lord_Inquisitor_Seru_ | sseru | 66 | **1,201,500** | 339 / 915 | 488 / **800** | 228 | 259,200s (72h) |
| 159113 | #Praesertum_Vantorus | sseru | 66 | **250,000** | 130 / 510 | 488 / 58 | 1086 | 259,200s (72h) |
| 159112 | #Praesertum_Rhugol | sseru | 66 | **200,000** | 125 / 500 | 488 / 58 | 1086 | 259,200s (72h) |
| 159115 | #Praesertum_Bikun | sseru | 66 | **160,000** | 147 / 500 | 488 / 100 | 1086 | 259,200s (72h) |
| 159114 | #Praesertum_Matpa | sseru | 66 | **150,000** | 147 / 418 | 488 / 58 | 1087 | 259,200s (72h) |
| 160375 | Lcea_Katta | katta | 60 | **401,200** | 238 / 827 | 445 / 150 | 581 | 258,750s (72h) |
| 160135 | #Nathyn_Illuminious | katta | 64 | **430,000** | 195 / 575 | 600 / 50 | 1351 | 194,400s (54h) |

**Event-control (NOT scope):**
- 160177 Bella_Helsin (L1, 1M HP, uncombattable flag 24)
- 160178 Heracus_Helsin (L1, 1M HP, uncombattable flag 24)

DT sweep: spell list 228 (Lord Inquisitor Seru) — highest 0-cast damage spell is Torturing Winds (-300, 2s cast, 45s recast). No DT. Lists 1086/1087 (Praesertum) — no DT. Lists 581 (Lcea Katta), 1351 (Nathyn) — no DT.

**Lord Inquisitor Seru's MR = 800** is a signature mechanic (close to Vyemm's 1000). Preserve per Decision #11.

### 3.4 Grieg's End (griegsend) — 3 scope NPCs (main)

| npc_id | name | level | hp | mindmg/maxdmg | AC/MR | npc_spells_id | spawn2 respawntime |
|---|---|---|---|---|---|---|---|
| 163075 | #Grieg_Veneficus (MAIN, script-spawned) | 65 | **475,500** | 214 / 632 | 481 / 64 | 168 | no spawn2 — script-spawned |
| 163231 | #Grieg_Veneficus (variant, spawn2-backed) | 65 | **162,500** | 92 / 320 | — / — | 168 | 561,600s (156h) ← massive outlier, probably custom timer |
| 163097 | #Grieg_Veneficus (variant, 14.25k placeholder) | 65 | 14,250 | 0 / 3 | — / — | 0 | 259,200s — likely placeholder/event trigger |
| 163013 | #Servitor_of_Luclin | 65 | **120,021** | 152 / 365 | 481 / 75 | 216 | 194,400s (54h) |
| 163078 | #Praetorian_Myral | 60 | **95,051** | 47 / 241 | 445 / 75 | 215 | 70,308s (19.5h) |
| 163055 | #Hyraja_Mazarduruk | 59 | 20,704 | 82 / 196 | 438 / 46 | 3081 | 70,308s — named tier (Grieg's Key drop per `luclin-chains.md` Section 4) |

**OUT OF ERA (DO NOT SCALE, confirmed by audit):**
- 163051 a_shrouded_minion (L75, 200k HP)
- 163052 an_ancient_necromantic_shade (L80, 1M HP, raid_target=1 — LoN/anniversary)

Confirm with config-expert that these 2 have `min_expansion > 3` filtering and are excluded at runtime.

**Grieg's End scope complexity:** There are 3 distinct Grieg_Veneficus npc_type IDs + ~13 trigger NPCs (163057/59/69/70/72/92/100/103/131/140/141/144/159/163/235/237/238). Scope Phase 5a HP scaling to 163075 (main, 475k → target). Variant 163231 (162.5k HP / 156h respawn) is likely an alternate encounter version — scope HP unchanged (already 162.5k is scaled-tier), scope respawn down to 86,400s (24h) per Decision #8. Variant 163097 (14.25k placeholder) — SKIP (non-combat trigger).

### 3.5 Acrylia Caverns (acrylia) — 2 scope NPCs

| npc_id | name | level | hp | mindmg/maxdmg | AC/MR | npc_spells_id | spawn2 respawntime |
|---|---|---|---|---|---|---|---|
| 154142 | #an_evolved_burrower | 63 | **300,750** | 200 / 693 | 466 / 56 | 0 | 97,200s (27h) |
| 154145 | Khati_Sha_the_Twisted | 68 | **475,000** | 400 / **1,004** | 502 / 64 | 616 | no spawn2 — script-spawned (`Khati_Sha_the_Twisted.lua`) |

**OUT OF ERA:**
- 154161 `#The_Fabled_Khati_Sha_the_Twisted` (L80) — confirm expansion filter excludes.

**Khati Sha level 68 edge note:** Luclin in this project normally caps at level 65 (scaled-named target band L66). Level 68 is unusual but era-consistent (Luclin introduced L65 cap; a few bosses sit above to give raid-tier difficulty). Audit flagged HP target 90k. No action needed on level — scale HP only.

### 3.6 Other Phase 5a zones

| npc_id | name | zone | level | hp | mindmg/maxdmg | AC/MR | npc_spells_id | spawn2 respawntime |
|---|---|---|---|---|---|---|---|---|
| 176088 | #Doomshade | umbral | 66 | **350,000** | 127 / 412 | 488 / 80 | 0 | no spawn2 — script-spawned (`#Doomshade.lua`) |
| 176089 | #Zelnithak | umbral | 60 | **251,000** | 115 / 400 | 445 / 54 | 235 | — (if spawn2 exists, need re-query) |
| 176002 | #Rumblecrush | umbral | 66 | **150,000** | 226 / 720 | 900 / 60 | 0 | — |
| 164078 | Thought_Horror_Overfiend | thedeep | 63 | **807,000** | 282 / 776 | 466 / 155 | 204 | — |
| 153095 | General_Jared_Blaystich | echo | 55 | **60,000** | 78 / 254 | 242 / 43 | 0 | 64,800s (18h) — already scaled-named tier; audit line 2350 says "minor trim or none" |

**OUT OF ERA:**
- 176111 `#Netherbian_Swarmfiend` (umbral, L73, 600k HP) — confirm expansion filter.

**Event-control (NOT scope):**
- 176110 `#Keymaster` (L1, 99,999,999 HP, umbral — instance gate)

**Doomshade finding (NEW):** audit missed Doomshade 176088 at 350k HP L66. Lore-master `luclin-chains.md` Section 5 flagged "Umbral Plains hosts Doomshade." Phase 5a scope — add to scaling list.

---

## 4. Death-touch sweep — COMPLETE

**Query:**
```sql
SELECT DISTINCT sn.id, sn.name, sn.mana, sn.cast_time, sn.recast_time,
       sn.effect_base_value1, sn.effectid1, nse.npc_spells_id
FROM npc_spells_entries nse
JOIN spells_new sn ON sn.id = nse.spellid
WHERE nse.npc_spells_id IN (
  -- Phase 5a boss spell lists
  202, 203, 174, 175, 176, 208, 227, 197, 228, 1086, 1087, 581, 1351,
  168, 215, 216, 1350, 173, 180, 178, 204, 235, 196, 616, 3625, 3613,
  3081, 3082, 3627, 1, 2, 3, 9
)
  AND sn.mana = 0
  AND sn.cast_time = 0
  AND sn.effect_base_value1 <= -5000;
```

**Result — single row:**

| spell_id | name | mana | cast_time | recast_time | base_value1 | effectid1 | npc_spells_id |
|---|---|---|---|---|---|---|---|
| **2859** | **Touch of Vinitras** | 0 | 0 | 120000 | **-20,000** | 0 | **196** |

**Impacted NPCs:** Vyzh\`dra the Exiled (162232) + Vyzh\`dra the Banished (162214) — both reference list 196.

**Mitigation (architect decision):** DELETE this single row from `npc_spells_entries` where `(npc_spells_id = 196 AND spellid = 2859)`. This follows Decision #16 (Cazic Touch DELETE) and Decision #13 (PoSky death-touch removal unblocks epic progression). Vyzh\`dra the Cursed (162206) uses list 197 — clean, no DT.

**Config-expert DT sweep cross-check requested** (see advisor log). If config-expert independently finds zero additional DT hits in Luclin content, proceed with the single-row DELETE.

---

## 5. Summary of scope

### Total Phase 5a scaling targets: ~35 NPCs

**Ssraeshza Temple (ssratemple) — 13:**
- Emperor Ssraeshza 162227 (main, 1.25M HP → target)
- Blood of Ssraeshza 162189 (200k HP gate mob)
- Ssraeshzian Blood Golem 162064 (201k HP retry gate)
- High Priest of Ssraeshza 162076 (941k HP)
- Xerkizh the Creator 162190 (806k HP)
- Arch Lich Rhag\`Zadune 162177 (790k HP)
- Rhag\`Mozdezh 162192 (226k HP)
- Rhag\`Zhezum 162178 (201k HP)
- General Kizuhx 162066 (250k HP, L53)
- Arbiter Korazhk 162191 (205k HP, L55)
- Advisor Zekuzh 162067 (150k HP, L53)
- Rhozth Ssrakezh 162258 (119k HP, L60)
- Rhozth Ssravizh 162089 (105k HP, L60)

**Flagged for lore-master decision (possibly in-scope):**
- #a_rune_covered_serpent 162253 (221k HP, raid_target=1)
- #a_glyph_covered_serpent 162261 (300k HP, raid_target=1)

**Akheva (akheva) — 8:** Vyzh\`dra Cursed + Exiled + Banished, Itraer Vius, Shar Vinitras, Shei Vinitras, Insanity Crawler, Va\`Dyn.

**Seru/Katta — 7:** Lord Inquisitor Seru + 4 Praesertum, Lcea Katta, Nathyn Illuminious.

**Grieg's End — 3:** Grieg Veneficus main (163075) + Servitor of Luclin + Praetorian Myral. Grieg variant (163231) scaled-tier HP but respawn needs update.

**Umbral Plains — 3:** Doomshade, Zelnithak, Rumblecrush.

**The Deep — 1:** Thought Horror Overfiend.

**Acrylia — 2:** Khati Sha the Twisted, evolved burrower.

**Echo — 0** (General Blaystich at 60k HP is already elite-named tier; Decision #2 applies).

### spawn2.respawntime updates — ~25 rows

Phase 5a spawn2 respawn targets (per Decision #8 endgame = 86,400s):
- ssratemple: High Priest + Xerkizh + Rhag\`Zhezum (3 rows; Rhozths at 5.4k/21.6k stay as mid-tier)
- akheva: Itraer Vius + Shei Vinitras + Insanity Crawler + Va\`Dyn (4 rows; Shar Vinitras at 3h short-tier preserved)
- sseru: Lord Inquisitor Seru + 4 Praesertum (5 rows, all 72h → 24h)
- katta: Lcea Katta + Nathyn Illuminious (2 rows, 72h → 24h)
- griegsend: Grieg 163097 + 163231 + Servitor + Praetorian Myral (4 rows)
- acrylia: evolved burrower (1 row, 27h → 24h)
- umbral: Zelnithak + Rumblecrush (2 rows — if they have spawn2)
- thedeep: Thought Horror Overfiend (1 row — if spawn2)

**Script-spawned bosses (Emperor, Vyzh\`dra trio, Rhag\`Zadune, Rhag\`Mozdezh, Khati Sha, Doomshade, Grieg 163075) have NO spawn2.** Their cycle timers live in Perl/Lua scripts — per Decision #11 (preserve signature), scripts are NOT edited in Phase 5a. `#EmpCycle.pl` currently uses a 3-4 hour failure cooldown and 3-5 day success respawn (`$EmpRepopTime = int(rand(2880)) + 4320`). Architect recommends leaving this native (per lore + Decision #11).

### Script / spell edits

- **npc_spells_entries:** DELETE WHERE npc_spells_id = 196 AND spellid = 2859 (Touch of Vinitras DT removal — Phase 2 Decision #16 pattern). 1 row.
- **Lua / Perl scripts:** **ZERO changes.** All signature mechanics (Emperor wave mechanic, Vyzh\`dra trio spawn chain, Emperor's 30-min engagement + 40-min combat timers, 5×shissar_wraith post-mortem, EmpCycle qglobal state machine, Grieg Veneficus cycle, Doomshade mechanics, Khati Sha mechanics) preserved untouched per Decision #11.

---

## 6. Open DB-level questions for lore-master / config-expert

1. **162253 + 162261 — rune/glyph serpents (221k / 300k HP, raid_target=1, ssratemple).** Not in audit. Lore-master: are these Ssraeshza Temple mini-bosses worth including in Phase 5a scope, or are they event-scripted trash under Decision #2? Scripts `#a_rune_covered_serpent.pl` and `#a_glyph_covered_serpent.lua` exist — need lore context.
2. **176088 Doomshade — zone/lore confirmation.** Script exists in `umbral/` — assumed umbral-zone. Lore-master: any Paladin epic / Cleric epic / quest dependency I should be aware of for Phase 5a scaling?
3. **Grieg Veneficus variants 163097 (14.25k placeholder) + 163231 (162.5k HP, 156h respawn).** Lore-master: is 163231 a distinct encounter or the same boss at a different progression state? Should Phase 5a scale both or only the 163075 main?
4. **Blood Golem 162064 vs Blood of Ssraeshza 162189 — both 200-201k HP, same spell list 3625.** Per `#EmpCycle.pl`, Blood is phase-1 gate (primary); Blood Golem is phase-2/failure gate. Scale both identically? (Architect default: yes.)
5. **Shei Vinitras 179157 special_abilities = `13,1^14,1^17,1^21,1^31,1` (only standard immunities, npcspecialattks = `f` just flurry, npc_spells_id = 0).** Audit line 2287 says "abilities: f" — she has no spell list and no damage shields, only standard raid-immunity flags. Phase 5a target HP cut (400k → 60k per audit). Confirm no hidden mechanic via script review (`#Shei_Vinitras.lua` / `#Shei_Vinitras_.lua` exist).
6. **Emperor's 32,1,290 special ability flag.** special_abilities CSV includes `32,1,290` — ability 32 = `SpecAtk_Enraged` (enrage at 290% threshold? or 2.9% HP trigger?). Preserve per Decision #11 — no edit. Flag for reviewer awareness.
7. **Confirm `min_expansion`/`max_expansion` on 163051 + 163052 (Grieg LoN adds) + 176111 (Netherbian OOE) + 154161 (Fabled Khati Sha) — are they all filtered on our era-lock (expansion 3 max)?** Config-expert question.

---

## 7. Advisor consultations logged

- **protocol-agent:** Initial Phase 5a questions sent 2026-04-22 covering DZ/instance posture, Khati Sha zone boundary, Yaemiu elite trash boundary, Emperor add-wave opcode path, DT audit cross-check, event-control NPC scope. Response pending.
- **config-expert:** Initial Phase 5a questions sent 2026-04-22 covering rule_values posture, zone ruleset verification, DT sweep cross-check, instance/DZ, data_buckets interactions, Emperor respawn mechanism, OOE filtering, spawn_conditions. Response pending.
- **lore-master:** Initial Phase 5a questions sent 2026-04-22 covering Emperor add-wave lore, Vyzh\`dra trio zone lore, Khati Sha zone (resolved by script path: acrylia), Seru/Katta faction mechanics, Ring of the Shissar dependencies, VT key Emperor drop, Akheva Sacrificed Remains chain, Grieg keying, Grimling War event boundary, Umbral/Doomshade lore, Thought Horror Overfiend mechanics, faction gates, epic dependency, signature mechanics per boss, respawn exceptions. Response pending.

All exchanges logged to `agent-conversations.md`.

