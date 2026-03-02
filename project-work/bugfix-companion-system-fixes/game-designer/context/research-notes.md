# Bug-Fix PRD Research Notes

## Key Files Reviewed

### Bug 1: LLM Chat
- `akk-stack/server/quests/global/global_npc.lua` — event_say handler, LLM flow
- `akk-stack/server/quests/lua_modules/llm_bridge.lua` — sidecar integration
- `akk-stack/server/quests/lua_modules/llm_config.lua` — LLM configuration
- `akk-stack/docker-compose.npc-llm.yml` — sidecar Docker service definition

### Bug 2: Equipment Display
- `eqemu/zone/companion.cpp:1126` — GiveItem() writes to m_equipment[]
- `eqemu/zone/companion.cpp:1196` — SendWearChange() delegates to Mob::SendWearChange
- `eqemu/zone/mob_appearance.cpp:378` — Mob::SendWearChange reads GetEquipmentMaterial()
- `eqemu/zone/npc.cpp:1600` — NPC::GetEquipmentMaterial reads from NPC::equipment[]
- `eqemu/zone/npc.h:753` — NPC::equipment[] declaration
- `eqemu/zone/companion.h:304` — Companion::m_equipment[] declaration (SEPARATE ARRAY)

### Bug 3: Equipment Persistence
- `eqemu/zone/companion.cpp:1150` — LoadEquipment() is implemented
- `eqemu/zone/companion.cpp:1171` — SaveEquipment() is called from GiveItem()
- `eqemu/zone/companion.cpp:981` — Load() does NOT call LoadEquipment()
- `eqemu/zone/companion.cpp:627` — Unsuspend() loads buffs but NOT equipment
- `eqemu/zone/companion.cpp:1756` — SpawnCompanionsOnZone() calls Load() then Spawn()

## Root Cause Analysis

### Bug 2: Two Equipment Arrays
The fundamental issue: NPC has `equipment[EQUIPMENT_COUNT]` at npc.h:753.
Companion added its own `m_equipment[EQUIPMENT_COUNT]` at companion.h:304.
GiveItem writes to m_equipment. GetEquipmentMaterial reads from equipment.
The wear change packet sends material=0 because it reads the wrong array.

### Bug 3: LoadEquipment Never Called
grep across entire eqemu/ codebase shows LoadEquipment() has exactly ONE
location: its definition at companion.cpp:1150. Zero call sites. Dead code.
SaveEquipment() is called (from GiveItem and RemoveItemFromSlot), so data
IS in the database. It's just never read back.

### Bug Interaction
Bugs 2 and 3 interact: even if LoadEquipment is called, if it only populates
m_equipment (not NPC::equipment), the visual display will still be broken.
Both bugs must be fixed together for equipment to work end-to-end.
