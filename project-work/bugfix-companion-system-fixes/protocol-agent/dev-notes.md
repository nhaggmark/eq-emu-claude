# Companion System Bug Fixes — Dev Notes: Protocol Agent

> **Feature branch:** `bugfix/companion-system-fixes`
> **Agent:** protocol-agent
> **Task(s):** Task #2 — Advise architect on Titanium client feasibility for equipment display
> **Date started:** 2026-03-01
> **Current stage:** Research (complete) — awaiting architect questions

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Advise architect on Titanium client feasibility for equipment display (OP_WearChange, spawn struct equipment materials) | — | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `common/patches/titanium_ops.h` | 137 | OP_WearChange: line 88 (E/ENCODE), line 133 (D/DECODE) — opcode exists in Titanium |
| `common/patches/titanium_structs.h` | 1061-1066 | Titanium WearChange_Struct: spawn_id(uint16), material(uint16), color(Tint_Struct 5B), wear_slot_id(uint8). 10 bytes total. |
| `common/patches/titanium.cpp` | 2289-2300, 3295-3310 | ENCODE: passes spawn_id, material, color.Color, wear_slot_id. DECODE: same fields IN, zeros unknown06/elite_material/hero_forge_model/unknown18. |
| `common/eq_packet_structs.h` | 1242-1252 | Internal WearChange_Struct: spawn_id(uint16), material(uint32), unknown06(uint32), elite_material(uint32), hero_forge_model(uint32), unknown18(uint32), color(Tint_Struct), wear_slot_id(uint8). |
| `zone/mob_appearance.cpp` | 378-444 | Mob::SendWearChange() — builds OP_WearChange packet using GetEquipmentMaterial(material_slot) |
| `zone/mob_appearance.cpp` | 331-343 | NPC::GetEquippedItemFromTextureSlot() — reads from NPC::equipment[inventory_slot] |
| `zone/npc.cpp` | 1600-1650 | NPC::GetEquipmentMaterial() — checks equipment[invslot] from NPC's loot array; if 0, returns texture fields; if non-zero, calls Mob::GetEquipmentMaterial() |
| `zone/mob_appearance.cpp` | 177-230 | Mob::GetEquipmentMaterial() — calls GetEquippedItemFromTextureSlot() then looks up item IDFile/Material |
| `zone/companion.h` | 304 | m_equipment[EQ::invslot::EQUIPMENT_COUNT] — Companion's own array, separate from NPC::equipment[] |
| `zone/companion.cpp` | 1126-1135 | GiveItem() — writes to m_equipment[slot], calls SendWearChange(slot), SaveEquipment() |
| `zone/companion.cpp` | 1196-1200 | SendWearChange() — just delegates to Mob::SendWearChange(material_slot) |
| `zone/companion.cpp` | 1150-1168 | LoadEquipment() — reads DB into m_equipment[], calls CalcBonuses(). Never called. |
| `zone/companion.cpp` | 537-548 | FillSpawnStruct() — calls NPC::FillSpawnStruct(), then zeroes is_npc, is_pet, NPC fields |
| `zone/mob.cpp` | 1362-1369 | Mob::FillSpawnStruct() equipment loop — calls GetEquipmentMaterial(i) for each texture slot |
| `zone/npc.cpp` | 2167-2171 | NPC::FillSpawnStruct() — calls Mob::FillSpawnStruct() then sets is_npc=1 |
| `common/patches/titanium.cpp` | 2408-2411 | ZoneSpawns ENCODE — copies equipment.Slot[k].Material for each texture slot to Titanium wire format |

### Key Findings

**Bug 2 (Equipment Display) — Root Cause Confirmed:**

The call chain is:
1. `GiveItem()` writes item_id to `m_equipment[slot]` (Companion's own array)
2. `GiveItem()` calls `SendWearChange(slot)` → `Mob::SendWearChange(material_slot)`
3. `Mob::SendWearChange()` calls `GetEquipmentMaterial(material_slot)` — which is `NPC::GetEquipmentMaterial()` (Companion doesn't override it)
4. `NPC::GetEquipmentMaterial()` checks `equipment[invslot]` — this is `NPC::equipment[]`, NOT `m_equipment[]`
5. `NPC::equipment[]` is the NPC loot array — it was never written by `GiveItem()`
6. Since `equipment[invslot] == 0`, `NPC::GetEquipmentMaterial()` returns the NPC's default texture field (helmtexture, d_melee_texture1, etc.)
7. The WearChange packet is sent with material=0 (or the default NPC texture), not the equipped item's material

**The two arrays are completely separate:**
- `NPC::equipment[]` (from `npc.h:753`) — loot-table populated array, used by `GetEquippedItemFromTextureSlot()` and `NPC::GetEquipmentMaterial()`
- `Companion::m_equipment[]` (from `companion.h:304`) — Companion's own array, populated by `GiveItem()`

**Bug 3 (Equipment Persistence) — Root Cause Confirmed:**
- `LoadEquipment()` fully implemented (companion.cpp:1150) — reads DB into `m_equipment[]` + calls CalcBonuses()
- Zero call sites anywhere in the codebase
- `Load()`, `Unsuspend()`, `SpawnCompanionsOnZone()` all skip `LoadEquipment()`

**Titanium OP_WearChange Support — CONFIRMED:**
- `OP_WearChange` has both ENCODE and DECODE in `titanium_ops.h` (lines 88, 133)
- The Titanium wire struct is a slimmer version of the internal struct: drops elite_material, hero_forge_model, unknown06, unknown18 fields — translation layer zeros these on DECODE
- ENCODE only passes: spawn_id, material, color.Color, wear_slot_id — exactly what Titanium expects
- The opcode is fully supported for NPCs — the existing code path for bots proves this works (bot.cpp:4040-4042 writes to `equipment[slot_id]` then calls SendWearChange())

**Spawn Packet (Bug 3 visual fix) — Confirmed path:**
- `Mob::FillSpawnStruct()` (mob.cpp:1362-1369) calls `GetEquipmentMaterial(i)` for each texture slot
- This goes through `NPC::GetEquipmentMaterial()` which reads `NPC::equipment[]`
- So if the fix writes to `NPC::equipment[]` (or overrides `GetEquipmentMaterial()`), spawn-time equipment will display correctly without needing extra WearChange packets

### Implementation Plan — Protocol Perspective

Two approaches to fix Bug 2. The architect picks one:

**Option A: Override `GetEquipmentMaterial()` in Companion**
- Add `uint32 GetEquipmentMaterial(uint8 material_slot) const override;` to `companion.h`
- Implement in `companion.cpp`: look up item from `m_equipment[CalcSlotFromMaterial(material_slot)]`, call `database.GetItem()`, return item->Material (or IDFile parse for weapons)
- Pro: Clean separation, m_equipment remains the single source of truth
- Con: Must duplicate the IDFile/Material logic from `Mob::GetEquipmentMaterial()`; also need to handle weaponPrimary IDFile parsing

**Option B: Write to both arrays in GiveItem()/LoadEquipment()**
- `GiveItem()` also does `equipment[slot] = item_id` (NPC's array) in addition to `m_equipment[slot] = item_id`
- `RemoveItemFromSlot()` also does `equipment[slot] = 0`
- `LoadEquipment()` also syncs to `equipment[]` after loading `m_equipment[]`
- Pro: Zero logic duplication — all existing NPC::GetEquipmentMaterial() IDFile/Material logic reused automatically
- Con: Two arrays to keep in sync; `equipment[]` originally exists for loot purposes

**Option C: Eliminate m_equipment entirely**
- Drop `m_equipment[]` from Companion, store items in `NPC::equipment[]` directly
- Con: Major refactor, touches many methods; not appropriate as a bug fix

**Bot precedent (confirming Option B pattern):**
- `bot.cpp:4040`: `equipment[slot_id] = item_id; SendWearChange(material_from_slot);`
- Bot uses `NPC::equipment[]` directly (no m_equipment shadow array)
- This is the proven pattern in the codebase

**Protocol recommendation: Option B** — follows the Bot pattern exactly, zero new logic, lowest risk.

**For Bug 3 (LoadEquipment call sites):**
After `LoadEquipment()` syncs `m_equipment[]` and (with Option B fix) `equipment[]`:
- No WearChange packets needed on zone-in — `FillSpawnStruct()` → `GetEquipmentMaterial()` will read populated `equipment[]` and embed materials in the spawn packet
- The spawn packet is the correct mechanism for initial visual state
- Add `LoadEquipment()` call in `Load()` after `m_companion_id` is set, AND in `Unsuspend()` to handle re-recruit case

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| OP_WearChange Titanium opcode | `titanium_ops.h:88,133` | Yes | Both ENCODE and DECODE present |
| Titanium WearChange_Struct | `titanium_structs.h:1061` | Yes | spawn_id uint16, material uint16, color 5B, wear_slot_id uint8 = 10 bytes |
| Internal WearChange_Struct | `eq_packet_structs.h:1242` | Yes | material is uint32; translation truncates to uint16 for Titanium wire |
| Mob::SendWearChange path | `mob_appearance.cpp:378` | Yes | Calls GetEquipmentMaterial() |
| NPC::GetEquipmentMaterial | `npc.cpp:1600` | Yes | Reads NPC::equipment[], not Companion::m_equipment[] |
| NPC::GetEquippedItemFromTextureSlot | `mob_appearance.cpp:331` | Yes | Returns equipment[CalcSlotFromMaterial()] |
| Mob::FillSpawnStruct equipment loop | `mob.cpp:1362` | Yes | Calls GetEquipmentMaterial() — same broken path without the fix |
| Bot precedent for equipment writes | `bot.cpp:4040` | Yes | equipment[slot_id] = item_id; SendWearChange(material) — proven pattern |
| Titanium spawn packet equipment copy | `titanium.cpp:2408-2411` | Yes | Copies equipment.Slot[k].Material to Titanium wire |

### Plan Amendments

Plan confirmed — no amendments needed. Research validates the analysis. Option B (write to both arrays) is the lowest-risk fix and matches the Bot pattern.

---

## Stage 3: Socialize

Awaiting architect's questions. Research complete and ready to respond.

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | (awaiting message) | Ready to respond when architect asks |

---

## Stage 4: Build

(Not yet started — advisory role in architecture phase)

---

## Context for Next Agent

**The core protocol findings:**

1. **OP_WearChange is fully supported by Titanium** — opcodes present for both encode/decode. No protocol limitation.

2. **Bug 2 root cause**: `Companion::GiveItem()` writes to `m_equipment[slot]` but `Mob::SendWearChange()` calls `NPC::GetEquipmentMaterial()` which reads `NPC::equipment[]`. These are two separate arrays. The fix is to also write to `equipment[slot]` in GiveItem()/RemoveItemFromSlot().

3. **Bug 3 root cause**: `LoadEquipment()` is implemented but never called. Add calls in `Load()` and `Unsuspend()`. With the Bug 2 fix (both arrays synced), spawn packets will automatically display equipment correctly via `FillSpawnStruct()` → `GetEquipmentMaterial()`.

4. **Bot pattern** (bot.cpp:4040): `equipment[slot_id] = item_id; SendWearChange(...)` — this is the reference implementation. Companion should follow this.

5. **No Titanium client constraints** apply to these bugs. They are pure server-side data routing issues.
