# Companion Equipment Management Enhancement — Dev Notes: Protocol Agent

> **Feature branch:** `feature/companion-equipment`
> **Agent:** protocol-agent
> **Task(s):** Task #2 — Research protocol implications for companion equipment
> **Date started:** 2026-03-07
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Research protocol implications for companion equipment | — | Complete |

---

## Stage 1: Plan

**Goal:** Answer five research questions for the architect:
1. How does the Titanium client render NPC equipment visually?
2. What opcodes handle trade window interactions?
3. Are there client-side limitations for NPC equipment slots vs player slots?
4. How does the server send equipment appearance data to the client?
5. How does the existing companion trade flow work at the packet level?

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `common/textures.h` | 1–160 | TextureProfile / TintProfile: 9 visual slots (materialCount = 9), not 19 |
| `common/eq_packet_structs.h` | 217–330 | Spawn_Struct: equipment (EQ::TextureProfile at offset 0x197), equipment_tint (EQ::TintProfile at offset 0x348) |
| `common/eq_packet_structs.h` | 1242–1252 | WearChange_Struct: spawn_id, material, unknown06, elite_material, hero_forge_model, unknown18, color, wear_slot_id |
| `common/patches/titanium_structs.h` | 1061–1066 | Titanium WearChange_Struct (wire): spawn_id uint16, material uint16, color Tint_Struct (5B), wear_slot_id uint8 — total 10B |
| `common/patches/titanium.cpp` | 2289–2300 | ENCODE(OP_WearChange): outputs spawn_id, material, color.Color, wear_slot_id only (strips elite_material, hero_forge_model, unknowns) |
| `common/patches/titanium.cpp` | 3295–3310 | DECODE(OP_WearChange): reads same 4 fields, zeros new-client fields |
| `common/patches/titanium.cpp` | 2304–2454 | ENCODE(OP_ZoneSpawns): loops `for k = textureBegin; k < materialCount; k++` — copies 9 equipment slots into Spawn_Struct |
| `common/patches/titanium_ops.h` | 88, 133 | OP_WearChange mapped to Titanium wire opcode (both ENCODE E and DECODE D exist) |
| `common/inventory_profile.cpp` | 1157–1181 | CalcMaterialFromSlot: maps inventory slots → texture material indices. Only 9 slots map: Head, Chest, Arms, Wrist1, Hands, Legs, Feet, Primary, Secondary |
| `common/patches/titanium_limits.h` | 107–159 | Equipment slot enum: slotCharm=0 through slotAmmo=21. EQUIPMENT_BEGIN=0, EQUIPMENT_END=21, EQUIPMENT_COUNT=22 |
| `zone/trading.cpp` | 510–660 | Client::FinishTrade(Mob*): NPC trade branch, EVENT_TRADE dispatch, companion-specific bypass at line 652 |
| `zone/companion.cpp` | 1171–1263 | Companion::GiveItem, RemoveItemFromSlot, LoadEquipment, SaveEquipment, SendWearChange — equipment system already fully implemented |
| `zone/client_packet.cpp` | 15370–15444 | Handle_OP_TradeAcceptClick: player↔NPC branch calls FinishTrade(with->CastToNPC()) |
| `zone/client_packet.cpp` | 15617–15662 | Handle_OP_TradeRequest: for NPC/Bot, server immediately sends TradeRequestAck (no wait needed) |

---

## Stage 2: Research

### Finding 1 — Titanium Visual Equipment: 9 Slots Only

The Titanium client renders NPC equipment through two mechanisms, both capped at **9 visual material slots** (`EQ::textures::materialCount = 9`):

```
EQ::textures::TextureSlot (textures.h:29-41):
  armorHead     = 0  (textureBegin)
  armorChest    = 1
  armorArms     = 2
  armorWrist    = 3
  armorHands    = 4
  armorLegs     = 5
  armorFeet     = 6
  weaponPrimary = 7
  weaponSecondary = 8
  materialCount = 9
```

**On zone-in:** The client receives `OP_ZoneSpawns` carrying `Spawn_Struct` fields `equipment` (EQ::TextureProfile at byte 0x197) and `equipment_tint` (EQ::TintProfile at byte 0x348). Each carries 9 slots. The titanium.cpp ENCODE loop copies exactly `materialCount = 9` slots.

**Live updates:** `OP_WearChange` (opcode mapped at titanium_ops.h line 88) carries:
- Titanium wire format (titanium_structs.h:1061): `spawn_id` uint16, `material` uint16, `color` Tint_Struct (5B), `wear_slot_id` uint8 — 10 bytes total
- `wear_slot_id` is the material index (0–8), NOT the inventory slot number
- ENCODE strips post-Titanium fields (elite_material, hero_forge_model) — confirmed at titanium.cpp:2294-2298

**Key constraint:** Only 9 of the 22 inventory equipment slots have visual representation in the Titanium client. The 13 non-visual slots (Charm, Ear1, Face, Ear2, Neck, Shoulders, Back, Wrist2, Range, Finger1, Finger2, Waist, Ammo) **never generate WearChange packets** — `CalcMaterialFromSlot()` returns `materialInvalid` for all of them.

### Finding 2 — Trade Window Opcodes

Complete trade session flow for NPC/companion:

| Step | Direction | Opcode | Struct | Notes |
|------|-----------|--------|--------|-------|
| 1 | C→S | `OP_TradeRequest` | `TradeRequest_Struct` (8B) | Player initiates — `from_mob_id`, `to_mob_id` |
| 2 | S→C | `OP_TradeRequestAck` | `TradeRequest_Struct` (8B) | Server immediately sends for NPC (no NPC-side confirmation needed) |
| 3 | C→S | `OP_MoveItem` | `MoveItem_Struct` (12B) | Player moves item into trade slot (3000–3003) |
| 4 | C→S | `OP_TradeAcceptClick` | `TradeAccept_Struct` (8B) | Player clicks Accept |
| 5 | S→C | `OP_FinishTrade` | (0 bytes) | Server closes trade window |

The server handles step 4 in `Handle_OP_TradeAcceptClick()` (client_packet.cpp:15370). When `with` is not a Client, it dispatches `FinishTrade(with->CastToNPC())`.

**No Titanium-specific translation needed** for any trade opcode — they all pass through unchanged (not in the ENCODE/DECODE table).

### Finding 3 — Client-Side Slot Limitations

**Titanium equipment slot inventory IDs** (titanium_limits.h:111-133):

| Slot Name | ID | Has Visual? |
|-----------|-----|------------|
| slotCharm | 0 | No |
| slotEar1 | 1 | No |
| slotHead | 2 | Yes (armorHead) |
| slotFace | 3 | No |
| slotEar2 | 4 | No |
| slotNeck | 5 | No |
| slotShoulders | 6 | No |
| slotArms | 7 | Yes (armorArms) |
| slotBack | 8 | No |
| slotWrist1 | 9 | Yes (armorWrist) |
| slotWrist2 | 10 | No |
| slotRange | 11 | No |
| slotHands | 12 | Yes (armorHands) |
| slotPrimary | 13 | Yes (weaponPrimary) |
| slotSecondary | 14 | Yes (weaponSecondary) |
| slotFinger1 | 15 | No |
| slotFinger2 | 16 | No |
| slotChest | 17 | Yes (armorChest) |
| slotLegs | 18 | Yes (armorLegs) |
| slotFeet | 19 | Yes (armorFeet) |
| slotWaist | 20 | No |
| slotAmmo | 21 | No |

EQUIPMENT_BEGIN = 0 (slotCharm), EQUIPMENT_END = 21 (slotAmmo), EQUIPMENT_COUNT = 22.

**The PRD lists 19 slots but the Titanium slot system has 22** (adding Charm, Ear1, Ear2). The PRD omits Charm, Ear1, and Ear2 from its list, which matches conventional EQ equipment slots. This is not a problem — the C++ equipment storage uses EQUIPMENT_BEGIN–EQUIPMENT_END (0–21), and all 22 slots are storable. Charm/Ear1/Ear2 not being in the PRD's UI list is a UX decision, not a protocol constraint.

**Critical finding:** `Wrist2` has NO visual update. When the companion equips in slot 10 (slotWrist2), `CalcMaterialFromSlot()` returns `materialInvalid`, no WearChange is sent. This is an existing EQEmu behavior — wrist2 shares visual with wrist1. The architect needs to know this.

### Finding 4 — How the Server Sends Equipment Appearance Data

Two code paths:

**A. Zone-in (initial appearance):**
The server populates `Spawn_Struct::equipment` (TextureProfile, 9 slots) in the spawn packet. For companions, this is built from `NPC::equipment[]` array, which is synced to `m_equipment[]` by `Companion::LoadEquipment()` and `GiveItem()`/`RemoveItemFromSlot()`.

**B. Live equipment change:**
`Companion::SendWearChange(uint8 material_slot)` delegates to `Mob::SendWearChange(material_slot)`, which sends `OP_WearChange` to all clients in range. Called by `GiveItem()` and `RemoveItemFromSlot()` after updating `m_equipment[]`.

Both mechanisms are **already implemented** in the current companion system. The protocol path is functional.

### Finding 5 — Existing Companion Trade Flow at Packet Level

The companion trade system is already largely implemented. The flow:

1. Client sends `OP_TradeRequest` → server calls `trade->Start()`, sends `OP_TradeRequestAck`
2. Client moves items into trade slots 3000–3003 via `OP_MoveItem`
3. Client sends `OP_TradeAcceptClick` → `Handle_OP_TradeAcceptClick()` → `FinishTrade(with->CastToNPC())`
4. `Client::FinishTrade(Mob*)` takes ownership of 4 trade-slot items (trading.cpp:518-522)
5. Since `tradingWith->IsCompanion()` (trading.cpp:652), EVENT_TRADE fires for the Lua handler
6. After EVENT_TRADE, the companion-specific bypass at trading.cpp:652 **skips the standard NPC return-items system** — items are consumed/handled entirely in the Lua handler
7. Server sends `OP_FinishTrade` to close the window

**Current Lua handler calls `companion:GiveItem(item_id, slot)` in C++**, which:
- Updates `m_equipment[slot]`
- Syncs to `NPC::equipment[slot]`
- Calls `SendWearChange(mat_slot)` if the slot has a visual material
- Calls `SaveEquipment()` → `CompanionInventoriesRepository`
- Calls `CalcBonuses()` for stat recalculation

**The protocol layer is complete.** The existing equipment system fully handles opcodes, struct translation, and visual update delivery.

---

## Key Protocol Constraints for Architect

1. **9 visual slots, 22 storable slots.** The Titanium client can only show visual gear changes for 9 slots via OP_WearChange. The other 13 slots (including Face, Neck, Shoulders, Back, Wrist2, Range, Finger1/2, Waist, Ammo) are stored and affect stats but generate no visual update. This is expected EQ behavior.

2. **Wrist2 has no visual.** slotWrist2 maps to `materialInvalid` in `CalcMaterialFromSlot()`. Both wrist slots share the wrist visual (armorWrist = slotWrist1 only).

3. **Trade window takes exactly 4 items.** `TRADE_NPC_SIZE = 4` (titanium_limits.h:93). The player can trade up to 4 items at once to a companion.

4. **WearChange wear_slot_id is the MATERIAL index (0-8), not the inventory slot ID.** The translation from inventory slot (0-21) to material slot (0-8) is done by `CalcMaterialFromSlot()`.

5. **No new opcodes or struct changes needed.** All required protocol operations exist:
   - `OP_WearChange` — visual appearance update (bidirectional, Titanium-translated)
   - `OP_TradeRequest` / `OP_TradeRequestAck` / `OP_TradeAcceptClick` / `OP_FinishTrade` — full trade session
   - `OP_ZoneSpawns` / `OP_NewSpawn` — initial equipment appearance on zone-in

6. **Titanium WearChange wire format is smaller than internal.** The ENCODE strips `elite_material` and `hero_forge_model` fields (post-Titanium additions). The Titanium wire struct is 10 bytes vs the internal 27-byte struct.

7. **The existing companion trade bypass in trading.cpp is critical.** The `if (tradingWith->IsCompanion())` block at line 652 prevents double-processing. The Lua event_trade handler owns all return logic. Any new slot-handling code must be in the Lua handler, not in the C++ trade completion path.

8. **No server-to-server protocol impact.** Companion equipment is local to the zone — no `ServerOP_*` codes need modification.

---

## Stage 3: Socialize

Findings sent to architect via SendMessage.

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Protocol research complete for companion equipment | Confirmed: no new opcodes needed; 9-slot visual limitation noted; companion trade bypass explained |

---

## Open Items

- [ ] Architect should note: Wrist2 (slotWrist2) has no visual — both wrist slots equip items but only Wrist1 updates appearance. This is existing EQEmu behavior and not a bug to fix in this feature.
- [ ] Architect should note: The PRD's 19-slot list omits Charm, Ear1, Ear2. These slots (0, 1, 4) are supported by the C++ storage but the Lua `!equipment` command will need to decide whether to display them.

---

## Context for Next Agent

This task is research-only (no code written). All findings are in Stages 1-2 above.

**Bottom line:** The protocol layer is already correct and complete for this feature. The companion equipment system (`companion.cpp:1171-1263`) already handles:
- Per-slot storage via `m_equipment[]` array
- Visual updates via `Companion::SendWearChange()` → `Mob::SendWearChange()` → `OP_WearChange`
- Database persistence via `CompanionInventoriesRepository`
- Stat recalculation via `CalcBonuses()`
- Trade bypass that lets Lua own item handling

Work remaining is in Lua (`event_trade` handler), not in the protocol layer.
