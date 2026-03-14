# Companion Authenticity Audit — Dev Notes: Data Expert

> **Feature branch:** `feature/companion-authenticity-audit`
> **Agent:** data-expert
> **Task:** #3 — Database audit: companion spell lists, NPC stats, class/race scaling, equipment data
> **Date started:** 2026-03-14
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Database audit: companion NPC stats, spell lists, class configs, equipment, scaling | — | Complete |

---

## Stage 4: Build — Database Audit Findings

All findings are based on direct database queries run 2026-03-14 against the live `peq` database.

---

## Section 1: companion_data Table Structure

**Schema:**
```
id, owner_id, npc_type_id, name, companion_type, level, class_id, race_id, gender,
zone_id, x/y/z/heading, cur_hp, cur_mana, cur_endurance, is_suspended, stance,
spawn2_id, spawngroupid, recruited_at, experience, recruited_level, is_dismissed,
total_kills, zones_visited, time_active, times_died
```

**Sample data (all 7 companions on the server):**

| id | name | comp_level | recruited_level | class_id | race_id | npc_type_id | npc_base_level | cur_hp | cur_mana |
|----|------|-----------|----------------|---------|---------|-------------|---------------|--------|---------|
| 23 | Jracol Brestiage | 12 | 12 | 9 (ROG) | 6 (DEF) | 2029 | 12 | 201 | 0 |
| 15 | Olunea Miltin | 13 | 8 | 1 (WAR) | 1 (HUM) | 10016 | 8 | 1000 | 0 |
| 21 | Hollish Tnoops | 14 | 14 | 1 (WAR) | 6 (DEF) | 9144 | 14 | 1000 | 0 |
| 20 | Moldrak Drin | 25 | 22 | 11 (NEC) | 3 (ERU) | 35018 | 22 | 1000 | 1025 |
| 10 | Lydl the Great | 29 | 4 | 12 (WIZ) | 1 (HUM) | 10162 | 4 | 346 | 1798 |
| 18 | Hollish Tnoops | 29 | 14 | 1 (WAR) | 6 (DEF) | 9144 | 14 | 417 | 0 |
| 22 | Jimble Woodentoe | 29 | 4 | 4 (RNG) | 11 (HFL) | 22014 | 12 | 388 | 1450 |

**Critical observation:** `companion_data.level` (current level) and `recruited_level` are stored separately from `npc_types.level` (NPC template base level). Lydl was recruited at level 4 but has grown to companion level 29. The companion system uses its stored `level` at runtime, not the NPC base level. All class_id values match npc_types.class exactly — no mismatches.

**Assessment:** MATCH — companion_data correctly tracks leveled-up companions independent of NPC template level.

---

## Section 2: NPC Base Stats vs Player Stats

### 2a. Companion NPC Template Stats (from npc_types)

All companion NPCs have stats from `npc_scale_global_base` type=0 at their NPC template level. All stats (STR, STA, DEX, AGI, WIS, INT, CHA) are identical to each other per-NPC:

| NPC ID | Name | NPC Level | Class | HP | mindmg | maxdmg | attack_delay | AC | STR=STA=DEX=AGI=WIS=INT=CHA |
|--------|------|-----------|-------|-----|--------|--------|-------------|-----|---------------------------|
| 10162 | Lydl the Great | 4 | WIZ | 28 | 1 | 9 | 30 | 13 | 17 (all) |
| 10016 | Olunea Miltin | 8 | WAR | 72 | 1 | 15 | 30 | 23 | 29 (all) |
| 2029 | Jracol Brestiage | 12 | ROG | 132 | 1 | 21 | 30 | 33 | 41 (all) |
| 22014 | Jimble Woodentoe | 12 | RNG | 132 | 1 | 21 | 30 | 33 | 41 (all) |
| 9144 | Hollish Tnoops | 14 | WAR | 168 | 1 | 24 | 30 | 38 | 48 (all) |
| 35018 | Moldrak Drin | 22 | NEC | 352 | 1 | 36 | 30 | 78 | 72 (all) |

**All mana values = 0** in npc_types — mana is calculated server-side at runtime.
**All hp_regen_rate = 0 and hp_regen_per_second = 0** — regen is also server-side.
**attack_count = -1** for all companion NPCs (universal sentinel meaning "use class default").
**scalerate = 100** for all companion NPCs (100% of base scale).

### 2b. npc_scale_global_base Type 0 (Standard NPC Baseline)

This table drives companion scaling. The companion system uses `companion_data.level` as the level key into this table at runtime.

| Level | hp | ac | attack | strength (all stats equal) | mindmg | maxdmg | attack_delay |
|-------|----|----|--------|---------------------------|--------|--------|-------------|
| 5 | 38 | 16 | 0 | 20 | 1 | 11 | 30 |
| 10 | 100 | 28 | 0 | 35 | 1 | 18 | 30 |
| 20 | 303 | 70 | 0 | 66 | 7 | 35 | 30 |
| 29 | 620 | 101 | 0 | 94 | 8 | 50 | 30 |
| 30 | 675 | 104 | 0 | 97 | 8 | 51 | 30 |
| 40 | 1450 | 167 | 40 | 163 | 21 | 93 | 21 |
| 50 | 5000 | 201 | 50 | 194 | 48 | 153 | 21 |

Three scale types exist (0, 1, 2). Type 0 is the baseline used by standard companion NPCs. Type 1 gives ~20-33% more HP/stats than type 0 at equivalent levels. Type 2 is the boss/elite tier, with dramatically higher HP (7500 at level 40 vs type 0's 1450).

### 2c. Player HP/Mana Baseline (from base_data table)

`base_data` stores player HP and mana by class and level:

| Level | WAR HP | CLR HP | CLR mana | DRU mana | NEC mana | WIZ mana | MAG mana | ENC mana |
|-------|--------|--------|---------|---------|---------|---------|---------|---------|
| 5 | 125 | 110 | 75 | 75 | 75 | 75 | 75 | 75 |
| 10 | 250 | 220 | 150 | 150 | 150 | 150 | 150 | 150 |
| 20 | 500 | 440 | 300 | 300 | 300 | 300 | 300 | 300 |
| 29 | ~725 | ~638 | ~435 | ~435 | ~435 | ~435 | ~435 | ~435 |
| 30 | 750 | 660 | 450 | 450 | 450 | 450 | 450 | 450 |
| 40 | 1000 | 880 | 600 | 600 | 600 | 600 | 600 | 600 |
| 50 | 1500 | 1320 | 900 | 900 | 900 | 900 | 900 | 900 |

Note: `base_data.hp` is base HP before STA contribution. Actual player HP includes roughly `STA/2 * level` added on top.

**Gap Assessment: HP — MAJOR DIVERGENCE**
- At level 29: NPC scale_global_base type 0 gives 620 HP. Player warrior base = ~725 HP before STA.
- At level 30: NPC scale = 675 HP vs player warrior base 750 HP (13% lower), before STA multiplier contribution.
- At level 50: NPC scale = 5000 HP vs player warrior base 1500 HP (3.3x higher). NPC HP at level 50 dramatically exceeds player base, but actual player HP with full STA and gear is typically 3,000-6,000+ at level 50, so alignment depends on the C++ scaling implementation.

**Gap Assessment: Base Stats — MAJOR DIVERGENCE**
- The scale_global_base makes ALL stats identical (STR=STA=DEX=AGI=WIS=INT=CHA).
- A real player would have race-based stat specialization: a human warrior has STR ~85, STA ~85, INT ~75, WIS ~75. A high elf wizard has INT ~115, STR ~70.
- No class-specific stat distributions exist in npc_scale_global_base — a wizard companion at level 30 has STR=97 and INT=97, whereas a real wizard would have STR ~70 and INT ~115+.
- This is a fundamental authenticity gap: companion stat distribution is homogeneous, not class/race-appropriate.

---

## Section 3: Mana Pool

**All npc_types mana = 0.** Mana is fully computed server-side. The `npc_scale_global_base` table has no `mana` column — there is no NPC-specific mana baseline table. The server likely computes companion mana from `companion_data.class_id` + `companion_data.level` using the `base_data.mana` formula, potentially modified by the companion's effective INT/WIS.

**Gap Assessment: Mana — UNKNOWN (defer to c-expert)**
- Database has no mana baseline for NPCs. The mana calculation is entirely in C++.
- Companion Moldrak Drin (necro, lvl 25) shows cur_mana=1025 in companion_data. Player necro at level 25: ~435 base mana + INT contribution. 1025 may be correct if the companion has 75 INT and the server uses the base_data.mana_fac formula.
- Lydl (wizard, lvl 29) shows cur_mana=1798. Player wizard at level 29: ~435 base + INT contribution. Wizard has mana_fac=2.25; with INT 94 (from scale), formula gives roughly 435 + (94-15)*2.25*29/30 ≈ 435 + 172 = 607. 1798 seems high — needs C++ investigation.

---

## Section 4: NPC Spell Lists

### 4a. Spell List IDs for Companion NPCs

| Companion | Class | npc_spells_id | List Name | Expected? |
|-----------|-------|--------------|-----------|-----------|
| Hollish Tnoops (x2) | WAR (1) | 0 | (none) | CORRECT — warriors don't cast |
| Olunea Miltin | WAR (1) | 0 | (none) | CORRECT |
| Jracol Brestiage | ROG (9) | 0 | (none) | CORRECT — rogues don't cast |
| Moldrak Drin | NEC (11) | 3 | Default Necromancer List | CORRECT |
| Lydl the Great | WIZ (12) | 2 | Default Wizard List | CORRECT |
| Jimble Woodentoe | RNG (4) | 10 | Default Ranger List | CORRECT |

All companion spell list assignments are correct for their class.

### 4b. Spell List Composition

**Naming note:** npc_spells ID 2 is internally named "Default Wizard List" — it is correctly assigned to wizard NPCs (class 12), not clercs. The name is consistent.

**Default Wizard List (ID 2):** 81 spells total. Full progression from level 1-65+. Includes damage nukes (Shock of Ice, Conflagration, etc.), root/snare, self-buffs (shielding line). Highest-priority spells (priority 24-10): endgame nukes like Strike of Solusek (lvl 65), Shock of Magic, Lure of Ro. These are inaccessible for a companion at level 29. At level 29, the wizard list provides: Thunder Strike (lvl 29, priority 9), Inferno Shock (lvl 29, priority 8). Correct wizard spells for that level.

**Default Necromancer List (ID 3):** 68 spells total. Includes DoT (Dooming Darkness at lvl 27-48), lifetaps (Spirit Tap lvl 29, priority 14), fear, root. Priority 53-51 for DoTs, priority 10 for lifetap. For Moldrak at level 25: Dooming Darkness not yet available (min level 29); primary damage would be Engulfing Darkness (lvl 11, priority 52), Lifetap/Lifespike. **Gap:** At level 22-25, the necro companion's highest-damage spell is Engulfing Darkness (old DoT, limited damage). A real necro player at level 22 would also use Root (lvl 9), Lifetap chain, and begin the DoT rotation — this matches.

**Default Shaman List (ID 6):** 93 spells total. Full heal line (Minor Healing through Superior Healing), DoTs, slow, slow, wolf form, SoW, debuffs. Healing priority: Minor Healing (lvl 1, priority 1), Healing (lvl 19, priority 1), Greater Healing (lvl 29, priority 1), Superior Healing (lvl 51, priority 1). **GAP: No high-priority healing.** All heals share priority 1 with other spells except basic "Healing" at priority 1 and "Light Healing" at priority 1. This means shaman NPCs will randomly cast SoW or debuffs instead of healing critically injured companions. Compare: Default Cleric List has Healing at priority 20, Light Healing at priority 10 — much better triage.

**Default Ranger List (ID 10):** 52 spells total. Mix of damage spells, self-buffs (Skin like Rock, Firefist, skins), DoTs, healing (Light Healing at level 9, Healing at level 39, Greater Healing at level 57). Priority 1 for everything. No differentiated healing priority. Ranger Jimble Woodentoe at level 29 would have: Skin like Rock (buff), Firefist (buff), Ignite (damage), Snare (priority 1), Grasping Roots (root), Shield of Thistles (buff). This is reasonable.

**Default Cleric List (ID 1):** Used by cleric NPCs. Healing at priority 20, Light Healing at priority 10 — properly prioritized for healing role. Damage (Wrath, Smite) at priority 30 and 20. For reference, clerics are not currently represented in companion_data.

**Summary of spell list issues:**
- Shaman spell list (ID 6) has NO differentiated healing priorities. All heals at priority 1 alongside damage spells. A shaman companion may not heal appropriately.
- Necromancer (ID 3): no heal-self capability — correct for necro, but lifetap (priority 10) is the only regen. Relies on C++ to use lifetap for self-sustain.
- Wizard (ID 2): purely offensive + self-buff. No healing, correct.
- Ranger (ID 10): has heals (Light Healing, Healing) at priority 1. May or may not be used during combat effectively.

### 4c. Pet Spell Lists

Separate "Default Pet" spell lists exist (IDs 514-524 for Wizard Pet, Necromancer Pet, etc.). These are for summoned NPC pets, not companions.

---

## Section 5: NPC Scaling vs Player Comparison

### 5a. npc_scale_global_base vs Player Attack

The scale_global_base type 0 provides NPC damage baseline:

| Level | NPC mindmg | NPC maxdmg | NPC attack_delay | Player with 1HS (approx) |
|-------|-----------|-----------|-----------------|--------------------------|
| 10 | 1 | 18 | 30 | Weapon 4-20, delay ~30 → comparable |
| 20 | 7 | 35 | 30 | Weapon 7-25, delay ~30 → comparable |
| 29 | 8 | 50 | 30 | Weapon 8-35, delay ~28-32 → slightly higher |
| 30 | 8 | 51 | 30 | Weapon 8-35 → slightly higher |
| 40 | 21 | 93 | 21 | Weapon 15-60 + double attack → NPC hits harder per swing but no double |
| 50 | 48 | 153 | 21 | Weapon 20-80 + double attack → NPC base damage competitive |

**Gap Assessment: NPC damage is class-neutral.** A level 30 wizard companion has the same base damage (8-51, delay 30) as a warrior companion. A real wizard would do 3-8 damage per hit; a warrior would do 15-40 per hit with a weapon. The NPC scale treats all classes identically for melee — this is a significant authenticity divergence for casters who should be melee-weak.

**Specifically**: companion NPCs with npc_types.level equal to their recruited level (not grown level) retain the base mindmg=1 and very low maxdmg of the template. The scaling to companion_data.level is handled at runtime in C++ — the database values are effectively overridden.

### 5b. Attack Speed Transition

`attack_delay` drops from 30 to 21 between levels 30-40 in the scaling table — this is a uniform step down for all NPCs. In player terms, attack delay is determined by the equipped weapon's delay, not the character's level directly (except haste effects). This creates a discrepancy: all companion classes auto-shift to faster attack at level 31+ regardless of class or equipped weapon.

---

## Section 6: Equipment and Item Restrictions

### 6a. Companion Inventories Summary

7 companions have 53 total item slots populated. Key items and class restriction findings:

**Companion 10 (Lydl the Great, WIZ, race 1 HUM, lvl 29):**
- Equipped: Cloth armor (AC 2-4), Dagger (item 7001, classes=32153, damage 3 delay 20)
- Class restriction check: `32153 & 2048 (WIZ) = 2048` ✓ — Wizard can use dagger
- Race restriction: `32153` race 65535 — all races allowed ✓

**Companion 15 (Olunea Miltin, WAR, lvl 13):**
- Equipped: Rusty Long Sword (item 5019, classes=413)
- Warrior (bit 1) check: `413 & 1 = 1` ✓ — Warrior can use long sword ✓

**Companion 18 (Hollish Tnoops, WAR, race 6 DEF, lvl 29):**
- Equipped: Pickbringer's Chainmail (classes=33183, races=19640)
- Class: `33183 & 1 (WAR) = 1` ✓ — Warrior can wear chainmail ✓
- Race: `19640 & 32 (DEF = dark elf = bit 32) = 32` ✓ — Dark elf can wear it ✓
- Bronze Two Handed Sword (classes=32797): `32797 & 1 = 1` ✓ Warrior allowed ✓
- Small Round Shield (classes=1023): `1023 & 1 = 1` ✓ Warrior allowed ✓

**Companion 22 (Jimble Woodentoe, RNG, race 11 HFL, lvl 29):**
- Equipped: Longbow (item 8003, classes=285, races=285)
- Class: `285 & 8 (RNG = bit 3, value 8) = 8` ✓ — Ranger can use longbow ✓
- Race: `285 & 1024 (HFL = halfling = bit 10) = 0` **MISMATCH** — Halfling (race 11 in EQEmu = bit 1024) is NOT in the longbow's race allowlist (races=285 = HUM+ERU+ELF+HIE+TRL only)
- This means a halfling ranger companion **cannot legitimately equip this longbow** under standard item rules

**Gap Assessment: Equipment — MINOR DIVERGENCE**
- Class restrictions are properly observed for all checked items
- The Jimble Woodentoe longbow race restriction mismatch is a data inconsistency: halflings are one of the primary ranger races in EQ but are excluded from this particular item
- The question is whether the companion system enforces item race restrictions — if it does, the halfling can't benefit from the longbow stat; if it ignores race checks, it's equipped but potentially not applying stats correctly

### 6b. Item Stats vs Player Progression

Items equipped by companions are very low quality relative to their companion level:
- Level 29 warrior (Hollish) wearing Bronze Two Handed Sword (damage 9, delay 47) — this is a level 1-5 quality weapon. A level 29 warrior player would typically have a weapon dealing 15-25+ damage.
- Level 25 necromancer (Moldrak) has only cloth armor — no weapon shown in companion_inventories. Casters typically use spells for damage, so acceptable, but no defensive gear suggests the inventory system may not be fully utilized for casters.

---

## Section 7: HP and Mana Comparison (Detailed)

### 7a. NPC Scale HP vs Player Base HP

At level 30 (using companion Hollish's current level):

| Metric | NPC Scale (type 0, lvl 30) | Player Warrior Base | Player Cleric Base |
|--------|---------------------------|--------------------|--------------------|
| HP | 675 | 750 (before STA) | 660 (before STA) |
| HP with STA | — | ~750 + 97/2*30 = ~2205 | ~660 + 97/2*30 = ~2115 |
| Attack (bonus) | 0 | weapon-based | weapon-based |

**The scale_global_base attack field is 0 at levels 1-30, then rises to 40 at level 40, 50 at level 50.** At levels 1-30, there is zero attack bonus from the scale table. This is a major gap for melee companions at these levels.

### 7b. Player Mana vs Expected Companion Mana

At level 29:
- `base_data` for wizard (class 12) at level 30: 600 base mana + INT contribution
- Actual companion Lydl cur_mana=1798 at level 29 — this is 3× the base_data value
- At level 29 with INT=94 (from scale): formula ~600 + (94-15) * mana_fac = 600 + 79 * 2.25 = 778 expected
- Lydl's 1798 is significantly above the expected ~778. This suggests the companion system is either using a different mana formula or the cur_mana value is not authoritative (stored as last-saved state, recalculated at login)

---

## Section 8: Attack Speed Analysis

All companion NPC templates have `attack_delay=30` (standard base delay). The scale table also defaults to 30 up to level 33, then begins decreasing.

At level 40: scale_global_base `attack_delay=21`. A player at level 40 uses weapon delay (typically 25-38 for 1HS, 35-50 for 2HS). The NPC auto-attack speed of delay 21 at level 40 would make companions attack at the rate of a player using a very fast weapon with substantial haste — potentially faster than reasonable for the class.

**Gap: companions at level 40+ auto-attack at delay 21** (fast, like wielding a weapon with haste), regardless of what weapon they've equipped. A player warrior at level 40 typically attacks at delay 24-32 with a decent sword. The NPC scale attack delay compression from 30→21 between levels 30 and 40 represents a 30% speed increase that has no player equivalent unless the player has substantial haste.

---

## Section 9: Key Divergences Summary

| Area | Match Level | Details |
|------|-------------|---------|
| Companion level tracking | MATCH | companion_data.level correctly tracks progression independent of NPC template |
| Class assignment consistency | MATCH | class_id in companion_data matches npc_types.class for all companions |
| Spell list class assignments | MATCH | Necro→Necro list, Wizard→Wizard list, Ranger→Ranger list; Warriors/Rogues→0 (correct) |
| NPC base HP vs player HP | MINOR DIVERGENCE | NPC scale HP slightly below player base at levels 1-30; above player base at 40-50. Depends on C++ implementation. |
| Base stat distributions | MAJOR DIVERGENCE | All stats (STR=STA=DEX=AGI=WIS=INT=CHA) identical per level. No class/race stat specialization. A wizard has the same STR as a warrior at the same level. |
| Mana values | UNKNOWN | All npc_types.mana=0; mana calculated server-side. Stored cur_mana values suspect — needs C++ audit |
| Shaman spell priorities | MAJOR DIVERGENCE | All shaman heals at priority 1, competing equally with damage/debuff spells. Shaman companions may not heal effectively. Cleric list correctly prioritizes heals at 20/10. |
| Necro companion heals | MINOR (expected) | Necros have no self-heal beyond lifetap (priority 10). C++ must use lifetap for sustain. |
| Attack delay | MINOR DIVERGENCE | Scale table drops attack delay from 30 to 21 at level 40+, making all companions attack fast regardless of class or weapon equipped. |
| Attack bonus | MODERATE DIVERGENCE | scale_global_base attack=0 for levels 1-30. Players at level 20-30 have attack bonuses from STR and skills. Companions have no base attack bonus until level 31. |
| Base melee damage | MODERATE DIVERGENCE | All classes get the same base melee damage from scale table, ignoring class melee capacity. A wizard companion auto-attacks with the same damage as a warrior companion at the same level. |
| Equipment quality | MAJOR DIVERGENCE | Level 29 companions have starter-tier gear (Bronze 2HS, Small Ringmail). No gear scaling with companion level observed. |
| Item class restrictions | MATCH (mostly) | Class restrictions on equipped items appear correctly satisfied. |
| Item race restrictions | MINOR DIVERGENCE | Jimble Woodentoe (halfling ranger) equipped with Longbow that restricts halflings (races=285 excludes halfling). May affect stat application. |
| HP regen | UNKNOWN | All npc_types hp_regen=0. C++ calculates regen. scale_global_base has hp_regen (e.g., 13/tick at lvl 30), unclear if companions use this. |

---

## Open Items

- [ ] C++ investigation needed: how does companion mana calculation work? Does it use base_data.mana_fac + effective INT/WIS?
- [ ] C++ investigation needed: does companion HP use base_data.hp + STA formula (like players) or npc_scale_global_base.hp?
- [ ] Does the companion system check item race restrictions when applying item stats? Longbow on halfling may be a live issue.
- [ ] Shaman healing spell priority gap (all priority 1): no shaman companion currently in companion_data to test in-game, but this is a database-level issue that would affect any recruited shaman.

---

## Context for Next Agent

The data layer is well-structured for companion support. The major gaps are:
1. **Stat homogenization** — all stats equal per level in scale table, no class/race differentiation
2. **Shaman spell priorities** — heals compete equally with all other spells (priority 1 across the board)
3. **Attack delay compression** — all classes get fast attack delay at level 40+ regardless of class role
4. **Equipment quality** — companion gear is not scaling with companion level; starter gear equipped on level 29 companions

For the synthesis report: the most actionable database-side fix would be (a) a companion-specific spell list for shaman that elevates healing priority, and (b) a review of whether class-differentiated stat scaling can be applied per companion class_id.
