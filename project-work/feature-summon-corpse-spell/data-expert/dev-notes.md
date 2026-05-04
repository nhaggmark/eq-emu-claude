# Universal Summon Corpse Spell — Dev Notes: Data Expert

> **Feature branch:** `feature/summon-corpse-spell`
> **Agent:** data-expert
> **Task(s):** 2, 3, 5, 6, 7, 9
> **Date started:** 2026-05-03
> **Current stage:** Build (Stage 4)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Identify clone-source row + assign spell_category | — | Complete |
| 3 | Author 12 spells_new INSERTs | 2 | Complete |
| 5 | Author 12 items INSERTs (scrolls) | 3 | Complete |
| 6 | Enumerate vendor merchant_ids + author merchantlist INSERTs | 5 | Complete |
| 7 | Author auto-scribe migration (12 INSERT...SELECT blocks) | 3 | Complete |
| 9 | Bundle into transactional migration, test idempotency | 3,5,6,7,8 | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| architecture.md | All | Full task specs, spell ID assignments, DB field specs |
| source-spike-findings.md | All | Column names, vendor mapping reference, class IDs |
| prd.md | All | Final spell names, class table |
| spells_new (DB) | DESCRIBE | Actual column names: buffduration, buffdurationformula, CastingAnim, goodEffect, resisttype, EndurTimerIndex, IsDiscipline |
| items (DB) | DESCRIBE + query | scrolls use itemtype=20 (NOT 9), scrolltype=7, slots=0 for spell scrolls |
| merchantlist (DB) | DESCRIBE | merchantid, slot, item, faction_required, level_required, classes_required, probability |
| character_spells (DB) | SHOW CREATE | id (= character_id FK), slot_id, spell_id — composite PK (id, slot_id) |
| character_data (DB) | DESCRIBE | class column is `class` (not `class_`) |

### Key Findings

1. **Scroll itemtype is 20, not 9.** The source spike doc says itemtype=9 (ItemTypeScroll) but the live DB has zero items with itemtype=9. All existing spell scrolls use itemtype=20. Verified by checking existing "Spell: Summon Corpse" item (id=15003).
2. **spell_category 221 is free.** Max in use (excluding 999) is 220. Assigned 221 to all 12 new spells.
3. **Clone source:** Spell 2213 "Lesser Summon Corpse" — new_icon=109, CastingAnim=43, effect_base_value1=35. Architecture says use 255 for the new spells' effect_base_value1 (level cap). Clone-source descnum=2213, effectdescnum=64, goodEffect=1. spell_category on existing summon corpse line is 52 — new spells use 221 (different, no collision).
4. **Scroll slots=0** for existing spell scrolls (not 1048584). The architecture doc suggested slots=1048584 but live DB shows slots=0 for all spell scrolls.
5. **Vendor findings:** Identified the primary class spell vendor per zone per class. See Stage 3 section for full table.
6. **Only 1 character exists:** id=6, class=14 (Enchanter), max scribed slot=283.

### Implementation Plan

12 INSERTs for spells_new → 12 INSERTs for items → N INSERTs for merchantlist → 12 INSERT...SELECTs for character_spells → 1 INSERT for rule_values — wrapped in a single transaction.

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| spells_new column names | Live DB DESCRIBE | Yes | buffduration not buff_duration; CastingAnim not casting_animation; goodEffect not good_effect |
| items scroll itemtype | Live DB query | Yes | itemtype=20, not 9 |
| character_data.class | Live DB DESCRIBE | Yes | column is `class` not `class_` |
| character_spells schema | SHOW CREATE TABLE | Yes | id+slot_id composite PK; id = character_id FK |
| merchantlist schema | DESCRIBE | Yes | slot, item, faction_required, level_required, classes_required, probability |
| spell_category values | SELECT DISTINCT | Yes | Max=220 (excl. 999), assigned 221 |

### Plan Amendments

- **itemtype: use 20 not 9.** The architecture doc says itemtype=9 but all live scroll items use itemtype=20. This is a live-DB correction over the spec.
- **slots: use 0 not 1048584.** Existing spell scrolls have slots=0.
- **scrolllevel: use 0 not 1.** Existing scrolls all have scrolllevel=0.
- **effect_base_value1: 255.** Architecture spec — covers level cap for all characters.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| c-expert | spell_category = 221 | Confirmed, unblocked task 4 |

### Vendor Mapping — Final Table

Methodology: queried merchantlist joined to items (scrolleffect > 0 AND classes != 65535) grouped by zone/vendor, then selected the vendor with highest count for the target class in each starting city. For multi-class vendors (general spell vendors), selected the highest-item-count vendor in each city.

**NOTE:** The architecture says "standard class spell vendor in each starting city." In practice, most starting cities have multiple spell vendors. I selected the vendor with the highest count of spells for the target class. Where a vendor is clearly dedicated to one class (e.g., Bard-only vendors in gfaydark), I used them; otherwise the general high-count vendor.

| Class | Zone | Vendor Name | merchant_id | Next slot |
|-------|------|-------------|-------------|-----------|
| CLR | erudnext | Mertitt_Phentilly | 24028 | 21 |
| CLR | qeynos2 | Mellisa_Purgor | 2047 | 22 |
| CLR | felwithea | Celest_Palestream | 61020 | 21 |
| CLR | halas | Shenigan_Mc`Macky | 29082 | 20 |
| CLR | kaladimb | Zeffan_Holdsman | 67067 | 21 |
| CLR | rivervale | Frappy_Slimfinger | 19024 | 21 |
| CLR | qcat | Leon_Ereek | 45058 | 21 |
| CLR | freeportwest | Amata_D`Lavi | 383202 | 21 |
| CLR | neriakc | Issia_H`Rugla | 42033 | 21 |
| PAL | erudnext | Mertitt_Phentilly | 24028 | (shares with CLR) |
| PAL | qeynos2 | Mellisa_Purgor | 2047 | (shares) |
| PAL | felwithea | Celest_Palestream | 61020 | (shares) |
| PAL | halas | Shenigan_Mc`Macky | 29082 | (shares) |
| PAL | kaladimb | Zeffan_Holdsman | 67067 | (shares) |
| PAL | rivervale | Frappy_Slimfinger | 19024 | (shares) |
| PAL | freeportwest | Amata_D`Lavi | 383202 | (shares) |
| RNG | gfaydark | Zelli_Starsfire | 54081 | 22 |
| RNG | qcat | Vidurlyn_Aeminee | 45050 | 20 |
| RNG | qeynos2 | Henlom_Visrek | 2054 | 19 |
| SHD | neriakc | Misal_S`Kor | 42027 | 21 |
| SHD | cabeast | Lord_Vizaroth | 106016 | 17 |
| SHD | freeporteast | Malalon_Morotia | 382151 | 80 (after existing) |
| DRU | gfaydark | Zelli_Starsfire | 54081 | (shares with RNG) |
| DRU | misty/mistythicket | (no scroll vendor found) | — | N/A |
| DRU | qeynos2 | Henlom_Visrek | 2054 | (shares) |
| DRU | qcat | Leon_Ereek | 45058 | (shares with CLR) |
| BRD | gfaydark | Astar_Leafsinger | 54074 | 13 |
| BRD | freeporteast | Malusuard_Blolus | 382070 | 41 |
| BRD | qeynos | Chalea_Volesga | 1036 | 18 |
| BRD | neriakc | Sol_Punox | 42035 | 20 |
| SHM | grobb | Crilt | 52027 | 45 |
| SHM | halas | Shenigan_Mc`Macky | 29082 | (shares) |
| SHM | oggok | Brogdog | 49089 | 20 |
| SHM | cabeast | Vessel_Kabda | 106092 | 12 |
| SHM | sharvahl | Scribe_Mojir | 155187 | 21 |
| NEC | paineel | Kilevra_Natasu | 75087 | 19 |
| NEC | cabwest | Keeper_Plight | 82037 | 21 |
| NEC | neriakc | Misal_S`Kor | 42027 | (shares with SHD) |
| WIZ | erudnint | Onyssa_Vroce | 23008 | 18 |
| WIZ | felwitheb | Celent_Newmist | 62007 | 15 |
| WIZ | freeportwest | Charia_Betou | 383133 | 8 (low - use after) |
| WIZ | qeynos | Pai_Berenis | 1024 | 14 |
| WIZ | neriakb | Mignar_Mi`Draskch | 41003 | 10 |
| MAG | erudnext | Chembla_Ellent | 24014 | 21 |
| MAG | erudnint | Onyssa_Vroce | 23008 | (shares with WIZ) |
| MAG | felwitheb | Osisa_Goldenspear | 62012 | 3 |
| MAG | freeportwest | Tharma_Jaremi | 383156 | 3 |
| MAG | qeynos | Gende_Reldari | 1015 | 18 |
| MAG | neriakc | Ash_C`Luzz | 42008 | 21 |
| ENC | erudnint | Pinilla | 23015 | 21 |
| ENC | felwitheb | Est_Treewalker | 62002 | 20 |
| ENC | freeporteast | Eywen_Nalous | 382158 | 76 |
| ENC | qeynos | Corrao_Duperame | 1021 | 18 |
| ENC | neriakb | Kizya_D`Dbth | 41015 | 19 |
| ENC | sharvahl | Scribe_Qualia | 155230 | 21 |
| BST | grobb | Tracab | 52027 | 20 |
| BST | oggok | Brogdog | 49089 | (shares with SHM) |
| BST | cabeast | Vessel_Kabda | 106092 | (shares with SHM) |
| BST | sharvahl | Scribe_Kaleej | 155237 | 20 |

Note: `misty`/`mistythicket` vendors do NOT sell spell scrolls — no scrolleffect items on those merchants. Druid starting in Misty Thicket can still buy from qcat or qeynos2 vendors. This is acceptable — the architecture says "standard class spell vendor in each starting city"; if no vendor in a zone carries scrolls, that zone has no scroll vendor to add to.

### Consensus Plan

- spell_category = 221 (agreed with c-expert via SendMessage)
- All 12 spells: buffduration=65535, buffdurationformula=0, effect_base_value1=255
- Scroll items: itemtype=20, scrolltype=7, scrolllevel=0, slots=0
- Item IDs: 1000001-1000012
- auto-scribe: INSERT using character_data.class (not class_), slot = MIN(MAX(slot_id)+1, 399)

---

## Stage 4: Build

### Implementation Log

#### 2026-05-03 — Task 2: Clone-source capture, spell_category assignment

- Queried all spells with effectid1=91 → 11 rows, all have spell_category=52 (except spell 2245 which has -99)
- Verified SELECT DISTINCT spell_category → max non-999 value = 220
- Assigned spell_category=221 to all 12 new spells
- Clone cosmetic values from spell 2213 (Lesser Summon Corpse): new_icon=109, CastingAnim=43, descnum=2213, effectdescnum=64, goodEffect=1
- SendMessage to c-expert: spell_category = 221

#### 2026-05-03 — Tasks 3, 5, 6, 7, 9: SQL migration authored

- File: `/mnt/d/Dev/eq/akk-stack/server/quests/sql/feature_summon_corpse_spell.sql`
- Transactional migration with START TRANSACTION / COMMIT
- Idempotent: all INSERTs guarded by NOT EXISTS
- Sections: spells_new (12 rows) → items (12 rows) → merchantlist (N rows) → character_spells (12 INSERT...SELECT) → rule_values (1 row)
- Slot cap guard: MIN(MAX(slot_id)+1, 399) per character for auto-scribe

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `/mnt/d/Dev/eq/akk-stack/server/quests/sql/feature_summon_corpse_spell.sql` | Created | Full transactional migration |
| `/mnt/d/Dev/eq/claude/project-work/feature-summon-corpse-spell/data-expert/context/validation-queries.sql` | Created | Validation pack for all 12 spells, items, vendor entries, auto-scribed rows |

---

## Open Items

- [x] spell_category communicated to c-expert (221)
- [x] config-expert rule_values row — included in migration Section 5, applied
- [x] infra-expert applied migration (task 10 complete)

## Known UX Wart — 3-Minute Warm-Up After Memorize

Universal Summon Corpse spells have a 3-minute warm-up period after memorizing
before they can be cast for the first time. This is standard EQEmu engine
behavior: `recast_time` gates the spell gem on both cast AND memorize.

**Release-notes item for game-designer/PRD:**
> Players should keep the spell memorized at all times to use it as a true
> emergency tool. Memorizing the spell mid-emergency will not allow immediate
> casting — the 3-minute cooldown applies from the moment the spell is scribed
> into a gem slot.

**Design-review checklist note:** When proposing `recast_time` on a new spell,
verify that the memorize-warmup behavior matches the player-facing cooldown
spec. A spell with `recast_time = 180000` cannot be cast for 3 minutes after
it is first memorized, even by a fresh character who has never cast it before.

---

## Context for Next Agent

spell_category = 221 for all 12 new universal summon corpse spells.

Migration file: `/mnt/d/Dev/eq/akk-stack/server/quests/sql/feature_summon_corpse_spell.sql`
Validation file: `/mnt/d/Dev/eq/claude/project-work/feature-summon-corpse-spell/data-expert/context/validation-queries.sql`

The migration is a single transaction. Run it once; it is idempotent (all sections guarded by NOT EXISTS). The auto-scribe section targets character_data.class IN (2,3,4,5,6,8,10,11,12,13,14,15) with deleted_at IS NULL.

Key corrections vs architecture doc:
- Scroll itemtype = 20 (not 9) — live DB verification
- Scroll slots = 0 (not 1048584) — live DB verification
- character_data column is `class` (not `class_`) — live DB verification
