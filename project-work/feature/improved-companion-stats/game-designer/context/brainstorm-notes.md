# Brainstorm Notes — improved-companion-stats

## Research Findings

### Current State of Companion Commands

1. **!status** (companion.lua:556-575) — Already shows: name, level, class, HP/Mana, XP/next-level, stance, mode, companion type. Owner-only.

2. **!equipment** (companion.lua:516-518) — Calls npc:ShowEquipment(client). C++ ShowEquipment (companion.cpp:1972-2014) displays 19 slots with "label  item_name" or "(empty)". Owner-only.

3. **#npcstats** (GM command) — Calls CastToNPC()->ShowStats(c). Crashes when used on companions per the feature brief (CastToClient() on non-client entity).

### Key Constraint: Lua_Companion Inheritance

Lua_Companion inherits Lua_Mob, NOT Lua_NPC. This means:
- Available: GetSTR/STA/DEX/AGI/INT/WIS/CHA, GetAC, GetATK, GetMR/FR/DR/PR/CR, GetHP/MaxHP, GetMana/MaxMana, GetLevel, GetClass, GetClassName
- NOT available on Lua_Companion: GetMinDMG, GetMaxDMG, GetAttackSpeed, GetAttackDelay (these are on Lua_NPC)
- NOT exposed to Lua: GetCombatRole() (C++ only)

### Item Link Support

eq.item_link(item_id) is available in Lua — generates Titanium-compatible clickable item links.
Lua_Item has: GetAC(), GetDamage(), GetDelay(), GetName(), GetID(), GetSlots()

### Ownership vs. Any-Player Access

The existing !command dispatch in companion.lua (dispatch_prefix_command) checks ownership:
```lua
if npc:GetOwnerCharacterID() ~= client:CharacterID() then
    client:Message(15, "That is not your companion.")
    return
end
```

The feature brief says: "Commands should work on any companion, not just the player's own"

This means !stats and enhanced !equipment need a different dispatch path — either:
- A parallel entry point in global_npc.lua that intercepts !stats/!equipment BEFORE the ownership check
- A global player command through event_command
- Or relaxing the ownership check for read-only commands

## Design Decisions

### 1. Command Dispatch Path

**Option A: Modify companion dispatch to allow read-only commands without ownership**
- Add a "requires_owner" flag to the COMMANDS table
- !stats and !equipment marked as requires_owner=false
- Cleanest integration with existing system
- Pro: Single dispatch path, consistent behavior
- Con: Changes to an existing, working system

**Option B: New entry point in global_npc.lua for inspection commands**
- Before the ownership check in global_npc.lua, intercept !stats and !equipment
- These bypass dispatch_prefix_command entirely
- Pro: No changes to existing owner-gated system
- Con: Two dispatch paths for companion commands

**Option C: Player global command (event_command / eq.DispatchCommands)**
- Register !stats as a custom command in the command.lua system
- Player types /command stats (or !stats in say)
- Pro: Works without targeting companion
- Con: Different command syntax from other companion commands

**Recommendation: Option A** — Add an access control distinction to the existing dispatch table. Read-only inspection commands (stats, equipment) skip the ownership check. Modification commands (stance, equip, dismiss, etc.) remain owner-only.

### 2. !stats vs !status Naming

Current !status shows a brief overview (level, HP, XP, stance).
The proposed !stats shows detailed combat stats (STR/STA/DEX/AGI/INT/WIS/CHA, AC, ATK, resists, damage, combat role).

These are complementary, not overlapping:
- !status = operational overview (how is my companion doing right now?)
- !stats = detailed stat sheet (what are my companion's combat numbers?)

Both should exist. Both should be viewable by any player.

### 3. Equipment Display Enhancement

Current ShowEquipment is C++. The enhancement needs:
- AC for armor
- Damage/Delay for weapons
- Clickable item links

Two approaches:
- Modify C++ ShowEquipment to include AC, dmg/delay, and generate item links
- Replace C++ ShowEquipment call with Lua-side implementation

The PRD should describe WHAT the player sees, not HOW it's implemented. That's the architect's call.

### 4. Combat Role Display

CompanionCombatRole enum values:
- COMBAT_ROLE_MELEE_TANK (Warriors, Paladins, Shadow Knights)
- COMBAT_ROLE_MELEE_DPS (Monks, Berserkers, Beastlords, Rangers, Bards)
- COMBAT_ROLE_ROGUE (Rogues)
- COMBAT_ROLE_CASTER_DPS (Wizards, Magicians, Necromancers, Enchanters)
- COMBAT_ROLE_HEALER (Clerics, Druids, Shamans)

Currently not exposed to Lua. The !stats command needs this. This is a technical dependency to flag.

### 5. Display Format

Use client:Message() with color-coded categories. EQ's tell window is what other !commands use (Message type 15 = yellow/white).

Stats should be organized in logical groups:
- Identity: Name, Level, Class, Combat Role
- Vitals: HP, Mana
- Core Stats: STR/STA/DEX/AGI/INT/WIS/CHA
- Combat: AC, ATK, Min-Max Damage
- Resists: MR/FR/CR/PR/DR

Equipment should show:
- Slot: [item link] (AC: X) or (Dmg: X  Delay: Y)
- Empty slots can be omitted or shown as "(empty)"

## Lore Considerations

This feature is purely mechanical/QoL — no lore, dialogue, faction, NPC personality, or narrative content. The lore-master review should be a quick sign-off with "no lore concerns, numerical/UI only."
