# NPC Recruitment / Recruit-Any-NPC Companion System — Dev Notes: C Expert

> **Feature branch:** `feature/npc-recruitment`
> **Agent:** c-expert
> **Task(s):** 1, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 21, 22, 23, 24
> **Date started:** 2026-02-27
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Add Companions rule category to ruletypes.h + seed rule_values | — | In Progress |
| 6 | Implement Companion class (companion.h, companion.cpp) | 1, 2 | Pending |
| 7 | Implement companion_ai.cpp | 5, 6 | Pending |
| 8 | Modify entity.h/cpp — add companion_list | 6 | Pending |
| 9 | Modify client.h/cpp — companion ownership, SpawnCompanionsOnZone | 6 | Pending |
| 10 | Modify groups.cpp — auto-dismiss on full group | 6 | Pending |
| 11 | Add ServerOP_CompanionZone, ServerOP_CompanionDismiss to servertalk.h | 6 | Pending |
| 12 | Add IsCompanion() virtual to mob.h | 6 | Pending |
| 13 | Add DB migration entries to database_update_manifest.h | 2 | Pending |
| 17 | Add Lua API methods for companion creation/management | 6, 14 | Pending |
| 18 | Expose Companion class to Lua: zone/lua_companion.h/cpp | 6 | Pending |
| 19 | Add XP tracking + leveling system to Companion class | 6 | Pending |
| 21 | Implement equipment system in Companion class | 6, 20 | Pending |
| 22 | Add companion history tracking | 6, 20 | Pending |
| 23 | Implement re-recruitment logic | 6, 14, 20, 21 | Pending |
| 24 | Implement soul wipe on permanent death | 6, 20 | Pending |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| claude/docs/topography/C-CODE.md | 635 | Full architecture overview, entity hierarchy, code patterns |
| zone/merc.h | 386 | Merc class: lifecycle (Zone/Suspend/Unsuspend), owner tracking, group methods, stat accessors |
| zone/npc.h | 100+ | NPC base: AISpells_Struct, forward declarations |
| common/ruletypes.h | 1187 | Rule system: X-macro pattern, 47 categories, Bots category as reference |
| common/database/database_update_manifest.h | 80+ | Migration manifest: version, check, condition, sql fields |
| architect/architecture.md | Full | Architecture plan with all 24 tasks, data schemas, code sketches |

### Key Findings

1. **Rule system X-macro pattern**: `RULE_CATEGORY(Name)` / `RULE_BOOL/INT/REAL/STRING(Cat, Rule, Default, Notes)` / `RULE_CATEGORY_END()`. Add new categories before the `#undef` block at line 1181.
2. **Merc lifecycle pattern**: `Zone()` = Save + Depop; `Suspend()` = save state; `Unsuspend()` = restore. Companion must follow this exactly.
3. **Merc owns NPCType**: Merc constructor takes `const NPCType*`. Companion will too.
4. **Migration manifest**: Uses `ManifestEntry{ .version, .description, .check, .condition, .match, .sql }`. Task 2 (data-expert) creates tables; Task 13 (c-expert) adds the manifest entries.
5. **No Titanium merc opcodes**: Confirmed by architecture doc. All companion interaction via chat + group window.
6. **Entity list pattern**: `merc_list` uses `std::map<uint16, Merc*>`. Companion will use `std::unordered_map<uint16, Companion*>` per architecture doc.
7. **18 Companions rules** (12 original + 6 from expanded scope): Enabled, MaxPerPlayer, LevelRange, BaseRecruitChance, StatScalePct, SpellScalePct, RecruitCooldownS, DeathDespawnS, MinFaction, XPContribute, MercRetentionCheckS, ReplacementSpawnDelayS + XPSharePct, MaxLevelOffset, ReRecruitBonus, DismissedRetentionDays, CompanionSelfPreservePct, MercSelfPreservePct

### Implementation Plan

**Files to create or modify (Task 1):**

| File | Action | What Changes |
|------|--------|-------------|
| eqemu/common/ruletypes.h | Modify | Add Companions rule category with 18 rules before #undef block |

**Files to create or modify (Task 12 — no dependencies, can do with Task 1):**

| File | Action | What Changes |
|------|--------|-------------|
| eqemu/zone/mob.h | Modify | Add `virtual bool IsCompanion() const { return false; }` |

**Change sequence for Task 1:**
1. Add Companions rule category to ruletypes.h immediately before `#undef RULE_CATEGORY` at line 1181
2. SQL for rule_values seed goes into the migration manifest (Task 13)

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| RULE_CATEGORY X-macro pattern | ruletypes.h source | Yes | Lines 41+, category format confirmed |
| Bots rule category | ruletypes.h line 769 | Yes | Reference pattern for Companions |
| ManifestEntry struct | database_update_manifest.h line 7 | Yes | .version, .description, .check, .condition, .match, .sql |
| IsCompanion virtual pattern | mob.h (IsBot, IsMerc pattern) | Yes | merc.h line 124: `bool IsMerc() const override { return true; }` |

### Plan Amendments

Plan confirmed — no amendments needed. The Bots rule category at line 769 is the exact reference for our Companions category.

The 18 rules split by type:
- RULE_BOOL: Enabled, XPContribute
- RULE_INT: MaxPerPlayer, LevelRange, BaseRecruitChance, StatScalePct, SpellScalePct, RecruitCooldownS, DeathDespawnS, MinFaction, MercRetentionCheckS, ReplacementSpawnDelayS, XPSharePct, MaxLevelOffset, DismissedRetentionDays
- RULE_REAL: ReRecruitBonus, CompanionSelfPreservePct, MercSelfPreservePct

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| data-expert | Task 13 SQL dependency | Confirming I'll add the manifest C++ entry using their SQL from Task 2 |

### Consensus Plan

**Agreed approach:** Implement Task 1 (ruletypes.h) now as it has no dependencies. Also implement Task 12 (mob.h IsCompanion virtual) which has no real dependencies beyond Task 6 class existence — adding a virtual that returns false is safe to add before the class exists.

**Files to modify:**

| File | Action | What Changes |
|------|--------|-------------|
| eqemu/common/ruletypes.h | Modify | Add 18-rule Companions category before #undef block |
| eqemu/zone/mob.h | Modify | Add IsCompanion() virtual method |

**Change sequence (final):**
1. Add Companions category to ruletypes.h (Task 1)
2. Add IsCompanion() virtual to mob.h (Task 12)
3. After data-expert completes Task 2: Add migration manifest entries (Task 13)
4. After data-expert completes Tasks 2+20: Implement Companion class (Task 6)

---

## Stage 4: Build

### Implementation Log

#### 2026-02-27 — Task 1: Added Companions rule category to ruletypes.h

**What:** Added new `Companions` rule category with 18 rules after the `EvolvingItems` category and before the `#undef` block
**Where:** `eqemu/common/ruletypes.h` lines 1179-1198 (new content)
**Why:** Architecture requires 18 Companions rules for all tuning knobs without code changes. Follows exact X-macro pattern of Bots category.
**Notes:** 6 rules from expanded scope: XPSharePct, MaxLevelOffset, ReRecruitBonus, DismissedRetentionDays, CompanionSelfPreservePct, MercSelfPreservePct

#### 2026-02-27 — Task 12: Added IsCompanion() virtual to mob.h

**What:** Added `virtual bool IsCompanion() const { return false; }` to Mob class alongside IsBot()/IsMerc(). Also added to entity.h (where type-check virtuals actually live). Added `CastToCompanion()` to entity.h and entity.cpp.
**Where:** `eqemu/zone/entity.h`, `eqemu/zone/entity.cpp`
**Why:** Required for entity type checking. Virtual is in entity.h not mob.h (discovered by reading source).

#### 2026-02-27 — Task 8: Modified entity.h/cpp — add companion_list

**What:** Added companion_list (unordered_map<uint16, Companion*>) to EntityList. Added AddCompanion/RemoveCompanion/GetCompanionByOwnerCharacterID/GetCompanionsByOwnerCharacterID. Implementations are in companion.cpp following Bot pattern.
**Where:** `eqemu/zone/entity.h` (declarations), `eqemu/zone/companion.cpp` (implementations)

#### 2026-02-27 — Task 6: Implemented Companion class

**What:** Created companion.h and companion.cpp — full Companion : public NPC class.
- Constructor, destructor, factory CreateFromNPC()
- Lifecycle: Spawn, Suspend, Unsuspend, Zone, Depop, Dismiss
- Group management: CompanionJoinClientGroup, AddCompanionToGroup, RemoveCompanionFromGroup, CompanionGroupSay
- Persistence: Save, Load, SaveBuffs, LoadBuffs
- Equipment (Task 21): GiveItem, RemoveItemFromSlot, LoadEquipment, SaveEquipment, SendWearChange
- XP/Leveling (Task 19): AddExperience, CheckForLevelUp, GetXPForNextLevel
- History (partial Task 22): RecordKill, RecordZoneVisit, UpdateTimeActive stubs
- Soul wipe (Task 24): SoulWipe, SoulWipeByCompanionID
- Stat scaling: ScaleStatsToLevel, ApplyStatScalePct using direct Mob member access
- Spell AI stubs: LoadCompanionSpells (stub for companion_ai.cpp Task 7)

**Repositories also created:**
- `companion_data_repository.h` — hand-written, matches data-expert's SQL schema
- `companion_buffs_repository.h` — hand-written, InsertMany for batch insert
- `companion_inventories_repository.h` — hand-written, slot_id column (not slot)

#### 2026-02-27 — CMakeLists.txt update

**What:** Added companion.cpp and companion.h to zone/CMakeLists.txt
**Where:** `eqemu/zone/CMakeLists.txt`

**Build verification:** `ninja zone` passes (21 warnings, 0 errors)

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| `Bool__Enabled` redefinition | Rule names are globally unique (no category prefix) | Renamed `Companions, Enabled` to `Companions, CompanionsEnabled` |
| `GetBuff(i)` doesn't exist | Mob stores buffs in `Buffs_Struct *buffs` array, no GetBuff() accessor | Use `GetBuffs()` to get pointer, index with `buffs[i]` |
| `ScaleStats()` not on NPC | ScaleStats is a Merc-only method | Implemented stat scaling inline using direct Mob member fields |
| `TELL_SAY` undefined | Different GroupMessage signature | Used Merc's pattern: `g->GroupMessage(speaker, Language::CommonTongue, Language::MaxValue, buf)` |
| `WearChange_Struct.item_id` doesn't exist | Struct only has `material` and `wear_slot_id` | Delegate to `Mob::SendWearChange(material_slot)` which already exists |
| `AIDoSpellCast` param type mismatch | `oDontDoAgainBefore` is `oSpellWillFinish` (6th param), not `resist_adjust` (9th) | Fixed CastSpell() call order |
| `cd.companion_xp` doesn't exist | Repository uses `experience` column name | Fixed to `cd.experience = m_companion_xp` |
| `row.slot` doesn't exist in inventories | SQL column is `slot_id` not `slot` | Fixed to `row.slot_id` |

### Files Modified (session 1 commit)

| File | Action | Description |
|------|--------|-------------|
| eqemu/common/ruletypes.h | Modified | Added Companions rule category (18 rules, CompanionsEnabled) |
| eqemu/zone/entity.h | Modified | Added IsCompanion() virtual, CastToCompanion(), companion_list |
| eqemu/zone/entity.cpp | Modified | Added CastToCompanion() impl, companion cleanup in RemoveEntity/mob_dead |
| eqemu/zone/companion.h | Created | Full Companion class declaration |
| eqemu/zone/companion.cpp | Created | Full Companion implementation (~1300 lines) |
| eqemu/zone/CMakeLists.txt | Modified | Added companion.cpp, companion.h |
| common/repositories/companion_data_repository.h | Created | CRUD for companion_data table |
| common/repositories/companion_buffs_repository.h | Created | CRUD + InsertMany for companion_buffs |
| common/repositories/companion_inventories_repository.h | Created | CRUD for companion_inventories |

### Files Modified (session 2 commit)

| File | Action | Description |
|------|--------|-------------|
| eqemu/common/database/database_update_manifest.h | Modified | 4 ManifestEntry blocks (9329-9332): all 6 tables + exclusion seed + culture seed + 18 rule_values |
| eqemu/common/servertalk.h | Modified | ServerOP_CompanionZone (0x4800), ServerOP_CompanionDismiss (0x4801) + packet structs |
| eqemu/zone/client.h | Modified | Added SpawnCompanionsOnZone() declaration |
| eqemu/zone/client_packet.cpp | Modified | Call SpawnCompanionsOnZone() after SpawnMercOnZone() on zone-in |
| eqemu/zone/companion.cpp | Modified | SpawnCompanionsOnZone() implementation; restores active companions from DB on zone-in |
| eqemu/zone/groups.cpp | Modified | Auto-suspend companion when new Client joins group at MAX_GROUP_MEMBERS-1 |

---

## Open Items

- [ ] Task 7 (companion_ai.cpp): all 15 classes, stance-based spell AI (~1500 lines)
- [ ] Task 17: Lua API bindings for companion creation/management
- [ ] Task 18: lua_companion.h/cpp — expose Companion class to Lua
- [ ] Task 22: full history tracking (m_time_active increment on AI tick)
- [ ] Task 23: re-recruitment logic (shared with lua-expert)

---

## Context for Next Agent

If picking up this work after context compaction, read this section first.

The Companion system is a new `Companion : public NPC` class. The overall flow:
1. Recruit via Lua: `companion.lua` calls C++ API to create Companion from NPC
2. Companion tracks owner_char_id, has group integration, spell AI by class
3. Zone transitions: Zone() = Save+Depop on zone-out; SpawnCompanionsOnZone() = load+spawn on zone-in
4. Stats come from npc_types entry (NPCType struct), scaled by StatScalePct rule
5. Level scaling: `(int)(base_stat * (float)current_level / (float)recruited_level)` — MUST use float division

Key file dependencies:
- companion.h/cpp depend on: ruletypes.h (Task 1), DB tables (Task 2)
- companion_ai.cpp depends on: companion.h (Task 6), companion_spell_sets data (Task 5)
- entity.h/cpp changes depend on: companion.h (Task 6)
- client.h/cpp changes depend on: companion.h (Task 6)
- lua_companion.h/cpp depend on: companion.h (Task 6)
