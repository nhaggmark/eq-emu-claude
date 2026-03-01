# Bug #4 Diagnosis: Equipment Removal Appearance

## Summary

`Companion::GiveItem()` and `Companion::RemoveItemFromSlot()` both call
`SendWearChange(slot)` passing an inventory slot (0-22) where a material
slot (0-8) is expected. The OP_WearChange packet is sent with an invalid
`wear_slot_id`, which the Titanium client ignores.

## Key Evidence

1. `companion.cpp:1182` — `GiveItem()` calls `SendWearChange(slot)` with inventory slot
2. `companion.cpp:1195` — `RemoveItemFromSlot()` calls `SendWearChange(slot)` with inventory slot
3. `Mob::SendWearChange()` at `mob_appearance.cpp:384` — reads `GetEquipmentMaterial(material_slot)` where material_slot is expected to be 0-8
4. `textures.h:39` — `materialCount = 9` (material slots 0 through 8)
5. `rof2_limits.h:138-148` — `slotPrimary = 13`, `slotChest = 17` (inventory slots, not material slots)

## Codebase Pattern

Every other caller of SendWearChange converts inventory slot to material slot first:

| File | Line | Conversion |
|------|------|------------|
| `npc.cpp` | 1837-1839 | Manual switch for primary/secondary |
| `bot.cpp` | 3679 | `CalcMaterialFromSlot(slot_id)` |
| `bot.cpp` | 4056 | `CalcMaterialFromSlot(slot_id)` |
| `loot.cpp` | 748 | `CalcMaterialFromSlot(equip_slot)` |
| `corpse.cpp` | 898 | `CalcMaterialFromSlot(equip_slot)` |
| `inventory.cpp` | 1250 | `CalcMaterialFromSlot(i)` |
| `merc.cpp` | 4600 | `CalcMaterialFromSlot(i)` |

Companion is the ONLY class that skips this conversion.

## Material Slot Mapping

| Material Slot | Name | Inventory Slot | Name |
|---------------|------|----------------|------|
| 0 | armorHead | 2 | slotHead |
| 1 | armorChest | 17 | slotChest |
| 2 | armorArms | 7 | slotArms |
| 3 | armorWrist | 9 | slotWrist1 |
| 4 | armorHands | 12 | slotHands |
| 5 | armorLegs | 18 | slotLegs |
| 6 | armorFeet | 19 | slotFeet |
| 7 | weaponPrimary | 13 | slotPrimary |
| 8 | weaponSecondary | 14 | slotSecondary |

Non-visual slots (charm, ears, neck, shoulders, back, wrist2, range, fingers,
waist, powersource, ammo) return `materialInvalid` from `CalcMaterialFromSlot()`.
