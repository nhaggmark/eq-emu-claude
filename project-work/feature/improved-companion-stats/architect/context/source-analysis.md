# Source Code Analysis — improved-companion-stats

## Key File Locations

| File | What | Lines of Interest |
|------|------|-------------------|
| `eqemu/zone/lua_companion.h` | Lua_Companion class declaration | Lines 20-95 — inherits Lua_Mob |
| `eqemu/zone/lua_companion.cpp` | Lua_Companion method implementations | Lines 242-272 — luabind registration |
| `eqemu/zone/companion.h` | C++ Companion class | Line 133 — GetCombatRole(), Line 61-67 — CompanionCombatRole enum |
| `eqemu/zone/companion.cpp` | ShowEquipment implementation | Lines 1972-2014 |
| `eqemu/zone/companion.cpp` | GetCombatRole/DetermineRoleFromClass | Lines 575-617 |
| `eqemu/zone/lua_npc.h` | GetMinDMG/GetMaxDMG on Lua_NPC | Lines 73-74 |
| `eqemu/zone/lua_npc.cpp` | GetMinDMG/GetMaxDMG implementation | Lines 215-223 |
| `eqemu/zone/npc.h` | NPC::GetMinDMG/GetMaxDMG | Lines 304-305 |
| `eqemu/zone/lua_mob.h` | Stat accessors available via inheritance | Lines 144-158 (AC, ATK, STR-CHA, resists) |
| `eqemu/zone/lua_general.cpp` | eq.item_link registration | Lines 4009-4047 (implementations), 6058-6067 (registration) |
| `eqemu/common/item_data.h` | ItemData struct fields | Line 363 (Name), 410 (AC), 425 (Delay), 431 (Damage) |
| `akk-stack/server/quests/lua_modules/companion.lua` | Command dispatch + handlers | Lines 77-94 (COMMANDS), 118-142 (dispatch), 516-518 (cmd_equipment), 556-575 (cmd_status) |
| `akk-stack/server/quests/global/global_npc.lua` | Companion command entry point | Lines 11-14 (IsCompanion + dispatch) |

## Lua_Companion Methods Available via Lua_Mob Inheritance

These DO work on companion objects in Lua (confirmed by reading lua_mob.h):

```
GetSTR(), GetSTA(), GetDEX(), GetAGI(), GetINT(), GetWIS(), GetCHA()
GetAC(), GetATK()
GetMR(), GetFR(), GetCR(), GetDR(), GetPR()
GetHP(), GetMaxHP(), GetMana(), GetMaxMana()
GetLevel(), GetCleanName(), GetClassName()
GetClass(), GetRace()
```

## Methods NOT Available on Lua_Companion (Need New Bindings)

These are on Lua_NPC but NOT inherited by Lua_Companion:
- `GetMinDMG()` — NPC::GetMinDMG() returns uint32 m_min_dmg
- `GetMaxDMG()` — NPC::GetMaxDMG() returns uint32 m_max_dmg

This is NOT exposed to Lua at all:
- `GetCombatRole()` — Companion::GetCombatRole() returns CompanionCombatRole enum (uint8, 0-4)

## CompanionCombatRole Enum Values

```cpp
enum CompanionCombatRole : uint8 {
    COMBAT_ROLE_MELEE_TANK = 0,  // Warrior, Paladin, Shadow Knight
    COMBAT_ROLE_MELEE_DPS  = 1,  // Monk, Berserker, Beastlord, Ranger, Bard
    COMBAT_ROLE_ROGUE      = 2,  // Rogue
    COMBAT_ROLE_CASTER_DPS = 3,  // Wizard, Magician, Necromancer, Enchanter
    COMBAT_ROLE_HEALER     = 4   // Cleric, Druid, Shaman
};
```

Lua display mapping:
```lua
local COMBAT_ROLE_NAMES = {
    [0] = "Melee Tank",
    [1] = "Melee DPS",
    [2] = "Rogue",
    [3] = "Caster DPS",
    [4] = "Healer",
}
```

## Existing Pattern for Adding Methods to Lua_Companion

Follow the SetFollowDistance pattern (lua_companion.cpp:194-198):

```cpp
// In lua_companion.h — add declaration:
uint32 GetMinDMG();

// In lua_companion.cpp — add implementation:
uint32 Lua_Companion::GetMinDMG()
{
    Lua_Safe_Call_Int();
    return self->GetMinDMG();
}

// In lua_register_companion() — add registration:
.def("GetMinDMG", &Lua_Companion::GetMinDMG)
```

## ShowEquipment Enhancement Pattern

Current code (companion.cpp:2004-2013):
```cpp
for (const auto& entry : kDisplaySlots) {
    uint32 item_id = m_equipment[entry.slot];
    if (item_id != 0) {
        const EQ::ItemData* item = database.GetItem(item_id);
        const char* item_name = item ? item->Name : "(unknown item)";
        client->Message(Chat::White, "  %-12s %s", entry.label, item_name);
    } else {
        client->Message(Chat::White, "  %-12s (empty)", entry.label);
    }
}
```

Enhanced version needs:
1. Generate item link: `std::string link = quest_manager.varlink(item_id);`
   (or fallback to direct link generation if quest_manager unavailable)
2. Check if weapon slot: entry.slot is slotPrimary, slotSecondary, or slotRange
3. If weapon and item->Damage > 0: append "(Dmg: X  Delay: Y)"
4. Else if item->AC > 0: append "(AC: X)"
5. Else: just show the item link

## quest_manager.varlink Availability

quest_manager.varlink(item_id) is used by lua_item_link() in lua_general.cpp.
It calls quest_manager.varlink() which generates a Titanium-compatible item link
string. The quest_manager is set up when quest events are dispatched via
LuaParser/PerlembParser. Since ShowEquipment is called from within a Lua
event_say handler (companion.lua:cmd_equipment -> npc:ShowEquipment(client)),
the quest_manager should have a valid context.

If quest_manager is not available, alternative: use the static method
`EQ::SayLinkEngine::GenerateQuestSaylink()` or generate raw item link format
directly. The c-expert should test this.
