# Companion System Bug Fixes — Dev Notes: C Expert

> **Feature branch:** `bugfix/companion-system-fixes`
> **Agent:** c-expert
> **Task(s):** Task 1 (Bug 2 — equipment display), Task 2 (Bug 3 — equipment persistence)
> **Date started:** 2026-03-01
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Fix equipment display: override GetEquipmentMaterial + GetEquippedItemFromTextureSlot, sync NPC::equipment[] in GiveItem/RemoveItemFromSlot | — | In Progress |
| 2 | Fix equipment persistence: call LoadEquipment() from Load(), sync NPC::equipment[] in LoadEquipment() | Task 1 | Pending |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/zone/companion.h` | 1-357 | Companion class: m_equipment[] at line 304, GiveItem/RemoveItemFromSlot/LoadEquipment/SaveEquipment declared. FillSpawnStruct at line 147. |
| `eqemu/zone/companion.cpp` | 981-1169 | Load() at 981 returns true at 1013. GiveItem at 1126 sets m_equipment[slot] at 1131. RemoveItemFromSlot at 1138 zeros m_equipment[slot] at 1143. LoadEquipment at 1150 calls CalcBonuses() at 1167. |
| `eqemu/zone/npc.h` | 748-760 | NPC::equipment[] at line 753: `uint32 equipment[EQ::invslot::EQUIPMENT_COUNT]` |
| `eqemu/zone/npc.cpp` | 1600-1650 | NPC::GetEquipmentMaterial(): reads equipment[invslot], falls back to texture fields if 0, calls Mob::GetEquipmentMaterial() if item present |
| `eqemu/zone/mob_appearance.cpp` | 331-343 | NPC::GetEquippedItemFromTextureSlot(): reads equipment[inventory_slot] |
| `eqemu/zone/mob.h` | 544-549 | Mob virtual declarations: GetEquippedItemFromTextureSlot returns 0, GetEquipmentMaterial is virtual |

### Key Findings

- `Companion::m_equipment[]` and `NPC::equipment[]` are completely separate arrays
- The rendering pipeline calls virtual `GetEquipmentMaterial()` → resolves to `NPC::GetEquipmentMaterial()` → reads `NPC::equipment[]` (always empty for companions)
- `Companion::GiveItem()` only writes to `m_equipment[]`, never to `equipment[]`
- `Companion::LoadEquipment()` is fully implemented but has zero call sites
- The architect's plan provides exact code — all changes to companion.h and companion.cpp only

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/zone/companion.h` | Modify | Add 2 override declarations after FillSpawnStruct |
| `eqemu/zone/companion.cpp` | Modify | Implement 2 overrides, add 2 sync lines, add LoadEquipment() call + sync loop |

**Change sequence:**
1. companion.h: declare `GetEquipmentMaterial` and `GetEquippedItemFromTextureSlot` overrides
2. companion.cpp: implement `Companion::GetEquipmentMaterial()`
3. companion.cpp: implement `Companion::GetEquippedItemFromTextureSlot()`
4. companion.cpp: add `equipment[slot] = item_id` in GiveItem() after m_equipment[slot] = item_id (line 1131)
5. companion.cpp: add `equipment[slot] = 0` in RemoveItemFromSlot() after m_equipment[slot] = 0 (line 1143)
6. [Task 2] companion.cpp: add `LoadEquipment()` call in Load() before return true (after line 1013)
7. [Task 2] companion.cpp: add NPC::equipment[] sync loop in LoadEquipment() after CalcBonuses() (line 1167)

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `NPC::GetEquipmentMaterial(uint8)` signature | Source npc.cpp:1600 | Yes | const method, reads equipment[] |
| `NPC::GetEquippedItemFromTextureSlot(uint8)` signature | Source mob_appearance.cpp:331 | Yes | const method, reads equipment[] |
| `Mob::GetEquipmentMaterial(uint8)` virtual | Source mob.h:546 | Yes | base virtual, called when item present |
| `EQ::InventoryProfile::CalcSlotFromMaterial` | Source (used in npc.cpp:1617) | Yes | returns int16 or INVALID_INDEX |
| `EQ::textures::materialCount` | Source (used in npc.cpp:1613) | Yes | upper bound check |
| `EQ::invslot::EQUIPMENT_BEGIN/END` | Source (used in companion.cpp:1128,1140) | Yes | slot range bounds |
| `NPC::equipment[]` field access | Source npc.h:753 | Yes | accessible from Companion as inherited member |

### Plan Amendments

Plan confirmed — no amendments needed. Architect code is directly implementable.

---

## Stage 3: Socialize

Architecture plan is self-contained with exact code. Changes are independent of lua-expert's work.
No cross-system issues. Proceeding to build.

---

## Stage 4: Build

### Implementation Log

#### 2026-03-01 — Task 1: Equipment Display Fix

**What:** Added override declarations in companion.h, implemented both overrides in companion.cpp, added NPC::equipment[] sync in GiveItem and RemoveItemFromSlot.

**Where:**
- `eqemu/zone/companion.h` line 147 (after FillSpawnStruct declaration)
- `eqemu/zone/companion.cpp` — new methods after FillSpawnStruct impl, sync lines in GiveItem/RemoveItemFromSlot

**Why:** Virtual dispatch sends equipment queries to NPC::GetEquipmentMaterial() which reads NPC::equipment[] (empty). Overrides redirect to m_equipment[]. Sync ensures direct equipment[] access also works.

#### 2026-03-01 — Task 2: Equipment Persistence Fix

**What:** Added LoadEquipment() call in Load(), added NPC::equipment[] sync loop in LoadEquipment() after CalcBonuses().

**Where:** `eqemu/zone/companion.cpp` — Load() method and LoadEquipment() method

**Why:** LoadEquipment() was implemented but never called. Without the call, companions spawn with empty m_equipment[]. The sync loop mirrors m_equipment[] into NPC::equipment[] so both arrays stay consistent.

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `eqemu/zone/companion.h` | Modified | Added GetEquipmentMaterial and GetEquippedItemFromTextureSlot override declarations |
| `eqemu/zone/companion.cpp` | Modified | Implemented overrides, added sync in GiveItem/Remove, added LoadEquipment call + sync loop |
