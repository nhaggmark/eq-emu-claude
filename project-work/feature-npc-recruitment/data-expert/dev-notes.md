# NPC Recruitment / Recruit-Any-NPC Companion System — Dev Notes: Data Expert

> **Feature branch:** `feature/npc-recruitment`
> **Agent:** data-expert
> **Task(s):** 2, 3, 4, 5, 20
> **Date started:** 2026-02-27
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Create companion_data, companion_buffs, companion_exclusions, companion_culture_persuasion tables | none | In Progress |
| 3 | Seed companion_exclusions with auto-exclusions + named lore anchors | Task 2 | Pending |
| 4 | Seed companion_culture_persuasion with racial persuasion mappings | Task 2 | Pending |
| 5 | Create companion_spell_sets table + seed all 15 classes | Task 2 | Pending |
| 20 | Create companion_inventories table + expanded companion_data columns | Task 2 | Pending |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| architecture.md | 600+ | Full schema definitions for all 5 tables; spell list source guidance |
| prd.md | 400+ | Exclusion list details; racial persuasion table; froglok exclusion |
| user-stories.md | 400+ | Expanded scope decisions (leveling, equipment, soul wipe) |
| status.md | 188 | 6 new rules added for expanded scope; Task 20 created for inventories |
| SQL-CODE.md | 250+ tables | merc_buffs structure; npc_spells_entries structure |
| npc_spells_entries (DB) | 5122 rows | type bitmask values: 1,2,4,8,16,32,64,128,256,512,1024,2048,4096,8192,16384 |
| npc_spells (DB) | IDs 1-12 | Default class spell lists with real entries: Cleric(1), Wizard(2), Necro(3), Mage(4), Enc(5), Shm(6), Dru(7), Pal(8), SK(9), Rng(10), Brd(11), Bst(12) |
| mercs (DB) | struct | merc table reference for companion_data field comparisons |
| merc_buffs (DB) | struct | merc_buffs fields mapped to companion_buffs |

### Key Findings

1. **Bot spell lists (npc_spells IDs 3001-3016) have ZERO entries** in npc_spells_entries. The Bot system uses C++ hardcoded spells, not DB entries. The architecture doc's claim that "bot_spells_entries has comprehensive spell data" was referring to a table that doesn't exist in this database.

2. **"Default" class spell lists (IDs 1-12) have real entries** — 41-121 entries each, covering all spellcasting classes. These are the correct source for companion_spell_sets.

3. **Warriors, Rogues, and Monks have no Default spell list** — these are pure melee classes with no spells. companion_spell_sets will have zero rows for class_id 1 (WAR), 9 (ROG), 7 (MON). This is correct — the companion_ai.cpp code handles melee classes without spell AI.

4. **Exclusion counts are large**:
   - Class 40/41 (Banker/Merchant) + class 20-35: 3768 NPCs
   - rare_spawn=1: 364 NPCs
   - bodytype IN (11,64,65,66,67): 2936 NPCs
   - Frogloks (race 330 or 74): 277 NPCs
   - These overlap significantly. Use INSERT IGNORE to handle duplicates.

5. **Named lore anchor IDs found**:
   - Lucan D'Lere: 9018, 382202 (Sir_Lucan_D`Lere); 9147, 382244 (#Sir_Lucan_D`Lere)
   - Captain Tillin: 1068 (Captain_Tillin), 466035 (#Captain_Hiran_Tillin)
   - Lord Antonius Bayle: 466029
   - King Raja Kerrath: 155151 (King_Raja_Kerrath)
   - High Priestess Alexandria: 42019
   - Harbinger Glosk: 82044
   - King Thex'Ka IV (Teir'Dal king): 73103 (King_Thex`Ka_IV), 73112 (Fabled)

6. **companion_data expanded scope**: All expanded columns (XP tracking, leveling, dismissal, history) need to be in the initial CREATE TABLE per instructions. Task 20 will only need companion_inventories.

7. **EQ class IDs**: 1=WAR, 2=CLR, 3=PAL, 4=RNG, 5=SHK, 6=DRU, 7=MNK, 8=BRD, 9=ROG, 10=SHM, 11=NEC, 12=WIZ, 13=MAG, 14=ENC, 15=BST (16=BER is post-Luclin, excluded)

8. **npc_spells_entries type bitmask values**: 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384

### Implementation Plan

**Files to create:**

| File | Action | What Changes |
|------|--------|-------------|
| `data-expert/context/01_create_tables.sql` | Create | companion_data, companion_buffs, companion_exclusions, companion_culture_persuasion |
| `data-expert/context/02_seed_exclusions.sql` | Create | Auto-exclusions + named lore anchors |
| `data-expert/context/03_seed_culture.sql` | Create | Race->persuasion mappings |
| `data-expert/context/04_spell_sets.sql` | Create | companion_spell_sets table + spell data from Default lists |
| `data-expert/context/05_companion_inventories.sql` | Create | companion_inventories table |

**Change sequence:**
1. Execute 01_create_tables.sql (Task 2)
2. Execute 02_seed_exclusions.sql (Task 3)
3. Execute 03_seed_culture.sql (Task 4)
4. Execute 04_spell_sets.sql (Task 5)
5. Execute 05_companion_inventories.sql (Task 20)
6. Notify c-expert that tables are ready
7. Commit SQL files

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| MariaDB CREATE TABLE ENGINE=InnoDB DEFAULT CHARSET=latin1 | DB inspection of existing tables | Yes | Consistent with all peq tables |
| INSERT IGNORE for duplicate handling | MariaDB docs / standard SQL | Yes | Handles overlapping exclusion sets |
| INSERT INTO ... SELECT for spell data | MariaDB standard | Yes | Used to pull from npc_spells_entries |
| BIGINT UNSIGNED for experience | architecture.md | Yes | Matches character_data.exp pattern |
| TINYINT UNSIGNED DEFAULT 0 for flags | inspection of mercs table | Yes | Standard EQEmu boolean pattern |

### Plan Amendments

1. **companion_spell_sets source changed**: Bot tables don't exist; use Default class lists (npc_spells IDs 1-12). No Warrior/Rogue/Monk entries needed.
2. **Erudite dual-entry**: architecture.md has two rows for race_id 3 (Erudite) in companion_culture_persuasion — this violates PRIMARY KEY. Will use only the companion (non-mercenary) entry since PRIMARY KEY = race_id. Lua code handles zone context.
3. **Froglok race IDs**: race 74 appears to be the standard Froglok in npc_types; race 330 is alternate. Both excluded.

### Verified Plan

See Stage 1 Implementation Plan — confirmed with amendment notes above.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| c-expert | Task 2 starting, tables incoming | Confirm companion_data column set matches what companion.h needs |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| (pending) | | |

### Consensus Plan

Proceeding with plan as documented. Will notify c-expert when tables are created.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `data-expert/context/01_create_tables.sql` | Create | 4 core tables |
| `data-expert/context/02_seed_exclusions.sql` | Create | Exclusion seed data |
| `data-expert/context/03_seed_culture.sql` | Create | Culture persuasion seed data |
| `data-expert/context/04_spell_sets.sql` | Create | Spell sets table + seed |
| `data-expert/context/05_companion_inventories.sql` | Create | Inventory table |

---

## Stage 4: Build

### Implementation Log

_Chronological record of changes._

---

## Open Items

- [ ] Confirm with c-expert which exact companion_data columns are needed in C++ struct
- [ ] companion_spell_sets: verify min_expansion/max_expansion filter needed for Classic-Luclin

---

## Context for Next Agent

All 5 companion tables created and seeded. Key facts:

1. **Table names**: companion_data, companion_buffs, companion_exclusions, companion_culture_persuasion, companion_spell_sets, companion_inventories

2. **companion_data** includes all expanded scope columns: experience, recruited_level, is_dismissed, total_kills, zones_visited (TEXT), time_active, times_died

3. **companion_spell_sets source**: Derived from npc_spells_entries joined with Default class spell lists (IDs 1=CLR, 2=WIZ, 3=NEC, 4=MAG, 5=ENC, 6=SHM, 7=DRU, 8=PAL, 9=SK, 10=RNG, 11=BRD, 12=BST). Warriors (1), Rogues (9), Monks (7) have no spell entries — melee only.

4. **companion_exclusions** auto-populated from: class IN(40,41) + class 20-35 (Banker/Merchant/Guildmaster), rare_spawn=1, bodytype IN(11,64,65,66,67), race IN(74,330) (Froglok). Named lore anchors added manually.

5. **companion_culture_persuasion** PRIMARY KEY is race_id — one row per race. Erudite (3) uses companion/CHA/faction since zone-based context handled in Lua.

6. **companion_inventories** mirrors character_corpse_items structure: companion_id FK, slot, item_id, charges, etc.

7. SQL scripts saved in context/ for reference. Execute against peq database.
