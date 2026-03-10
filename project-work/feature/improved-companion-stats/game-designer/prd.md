# improved-companion-stats — Product Requirements Document

> **Feature branch:** `feature/improved-companion-stats`
> **Author:** game-designer
> **Date:** 2026-03-10
> **Status:** Approved

---

## Problem Statement

Players on this server rely heavily on companions — the recruit-any-NPC system is the signature feature. When equipping and managing companions, players currently lack critical information:

1. **No detailed stat visibility.** The existing `!status` command shows a brief operational overview (level, HP, XP, stance) but not the companion's actual combat stats — base attributes, AC, attack damage, or resistances. The only way to see detailed NPC stats is the GM command `#npcstats`, which crashes the zone when used on a companion because it calls `CastToClient()` on a non-client entity. Players have no safe way to see what their companion's numbers actually are.

2. **Equipment display lacks useful detail.** The `!equipment` command lists equipped items by slot name and item name only. Players cannot see the AC contribution of armor, the damage/delay of weapons, or click an item to inspect its full stats. This forces players to manually look up every item in an external database tool, breaking immersion and slowing down gearing decisions.

For a 1-3 player server where companions fill critical party roles, informed gearing and stat awareness is not optional — it is how players make decisions about which companions to recruit, how to equip them, and whether their party composition can handle upcoming content.

## Goals

1. **Safe companion stat inspection.** Any player can view a companion's detailed combat statistics without risking a zone crash, by targeting the companion and using `!stats`.
2. **Informed equipment decisions.** The `!equipment` command shows enough item detail (AC, damage/delay, item links) that players can evaluate gear at a glance without leaving the game.
3. **Consistency with existing system.** Both commands use the same `!` prefix convention and tell/message window output format as all other companion commands on this server.
4. **Open inspection.** Both `!stats` and `!equipment` work when any player targets any companion — not just the owner. This supports the 1-3 player server where companions are shared group assets.

## Non-Goals

- Modifying the existing `!status` command. `!status` and `!stats` are complementary: `!status` is the operational overview (stance, mode, XP progress); `!stats` is the detailed stat sheet. Both remain.
- Adding a full-blown character sheet window or custom UI panel. Output goes to the message/tell window using `client:Message()`, consistent with how all `!` commands work today.
- Allowing any player to command or modify another player's companion. Only the companion owner can issue modification commands (stance, equip, unequip, dismiss, etc.). The open-inspection change applies exclusively to read-only commands (`!stats`, `!equipment`).
- Fixing the `#npcstats` crash on companions. That is a separate bug in the GM command implementation. This feature provides a player-facing alternative that works correctly.
- Showing companion buffs, spell lists, or AI behavior details. Those are out of scope for this feature.

## User Experience

### Player Flow: !stats

1. Player targets a companion in their group (or any companion in the zone).
2. Player types `!stats` in /say chat.
3. The companion's detailed stat sheet appears in the player's message window, organized into clear sections: identity, vitals, core attributes, combat, and resistances.
4. If the player's target is not a companion, they see an error message: "You must target a companion to use this command."
5. If the player has no target, they see: "You must target a companion to use this command."

### Player Flow: !equipment (enhanced)

1. Player targets a companion (their own or another player's).
2. Player types `!equipment` in /say chat.
3. The companion's equipment list appears in the message window. Each occupied slot shows:
   - The slot name (Head, Chest, Primary, etc.)
   - A clickable item link (Titanium client format) that the player can click to see full item stats
   - For armor: the item's AC value
   - For weapons (Primary, Secondary, Range): the item's damage and delay values
4. Empty slots are listed as "(empty)" to help players see what slots still need gear.
5. Ownership is NOT required — any player can inspect any companion's equipment.

### Example Scenario: !stats

A level 32 ranger has recruited Guard Arliss (a warrior companion) in North Qeynos. The ranger targets Guard Arliss and types `!stats`. The following appears in the ranger's message window:

```
=== Guard Arliss — Stats ===
  Level: 30  Class: Warrior  Role: Melee Tank
  HP: 3200 / 3200  Mana: 0 / 0
--- Attributes ---
  STR: 125  STA: 120  AGI: 85
  DEX: 80   INT: 55   WIS: 60   CHA: 65
--- Combat ---
  AC: 280  ATK: 195
  Damage: 18 - 72
--- Resistances ---
  Magic: 45  Fire: 35  Cold: 30  Poison: 25  Disease: 25
```

### Example Scenario: !equipment (enhanced)

The same ranger types `!equipment` while targeting Guard Arliss. The following appears:

```
=== Guard Arliss — Equipment ===
  Head       [Blackened Iron Helm] (AC: 8)
  Face       (empty)
  Neck       (empty)
  Shoulders  (empty)
  Chest      [Banded Mail Armor] (AC: 15)
  Back       (empty)
  Arms       [Banded Mail Bracers] (AC: 6)
  Wrist 1    (empty)
  Wrist 2    (empty)
  Hands      [Banded Mail Gauntlets] (AC: 5)
  Finger 1   (empty)
  Finger 2   (empty)
  Legs       [Banded Mail Leggings] (AC: 10)
  Feet       [Banded Mail Boots] (AC: 5)
  Waist      (empty)
  Primary    [Rusty Longsword] (Dmg: 7  Delay: 35)
  Secondary  [Wooden Shield] (AC: 5)
  Range      (empty)
  Ammo       (empty)
```

The item names in brackets are clickable item links. Clicking "[Blackened Iron Helm]" opens the standard EverQuest item inspection window showing all stats, effects, lore text, and restrictions.

## Game Design Details

### Mechanics

#### !stats Command

The `!stats` command displays a companion's combat-relevant statistics, organized into five sections:

**Identity Block:**
- Name (clean name, no special characters)
- Level
- Class name (e.g., "Warrior", "Cleric", "Wizard")
- Combat role (e.g., "Melee Tank", "Melee DPS", "Rogue", "Caster DPS", "Healer") — this is the role the companion AI uses for positioning and spell selection

**Vitals Block:**
- Current HP / Maximum HP
- Current Mana / Maximum Mana (shows 0/0 for non-caster classes)

**Attributes Block:**
- STR, STA, AGI (first line)
- DEX, INT, WIS, CHA (second line)
- These are the companion's current effective values (base + equipment bonuses + level scaling)

**Combat Block:**
- AC (armor class)
- ATK (attack rating)
- Damage range: Min Damage - Max Damage (the companion's melee damage range)

**Resistances Block:**
- Magic Resist, Fire Resist, Cold Resist, Poison Resist, Disease Resist
- Displayed on a single line with abbreviated labels

All values shown are the companion's current computed values (including equipment bonuses). No hidden modifiers — what the player sees is what the companion actually has.

#### !equipment Enhancement

The existing `!equipment` command is enhanced to show richer item information while maintaining the same slot display order already established:

**Slot display order** (19 slots, same as current): Head, Face, Neck, Shoulders, Chest, Back, Arms, Wrist 1, Wrist 2, Hands, Finger 1, Finger 2, Legs, Feet, Waist, Primary, Secondary, Range, Ammo.

**For occupied slots:**
- Slot label, left-aligned and padded
- Clickable item link in EverQuest's native item link format (Titanium client compatible). Player clicks the link to open the standard item inspection window.
- Stat summary in parentheses after the item link:
  - For armor/accessory slots: display AC value if AC > 0 — e.g., "(AC: 8)"
  - For weapon slots (Primary, Secondary, Range): display Damage and Delay — e.g., "(Dmg: 7  Delay: 35)"
  - For items with both AC and Damage (e.g., a shield with AC that can also be used as a weapon): show AC
  - For items with no AC and no Damage (e.g., a ring with only stat bonuses): show no parenthetical — the item link is sufficient; player clicks for details

**For empty slots:**
- Slot label followed by "(empty)"

#### Access Control Change

The existing companion command dispatch system gates all `!` commands behind an ownership check. This feature modifies that to distinguish between:

- **Read-only commands** (`!stats`, `!equipment`, `!gear`, `!status`): Any player can use these on any companion. No ownership required.
- **Modification commands** (all other `!` commands: `!passive`, `!balanced`, `!aggressive`, `!follow`, `!guard`, `!recall`, `!equip`, `!unequip`, `!unequipall`, `!target`, `!assist`, `!dismiss`): Owner only. Unchanged from current behavior.

When a non-owner attempts a modification command, the existing error message is shown: "That is not your companion."

### Balance Considerations

This feature has no balance impact. It is purely an information display enhancement:
- No stats are changed
- No new abilities are granted
- No gameplay advantage is created (all displayed information was always computed by the server; it simply was not visible to players)
- Works identically for a solo player with one companion or a 3-player group with a full party of companions

### Era Compliance

This feature introduces no content that could violate the Classic-Luclin era lock:
- No new items, spells, zones, NPCs, or quests
- Item links use the Titanium client's native item link format, which is era-appropriate
- The `!` command convention is custom to this server and not tied to any expansion
- All stats displayed (STR, AC, resistances, etc.) are core EverQuest stats present since Classic

## Affected Systems

- [x] C++ server source (`eqemu/`) — The companion's `ShowEquipment()` method may need modification to include item links, AC, and damage/delay. The `GetCombatRole()` method needs to be exposed to the scripting layer for `!stats` to display the role.
- [x] Lua quest scripts (`akk-stack/server/quests/`) — The companion command system in `companion.lua` needs the new `!stats` handler and the access control change for read-only commands. The `!equipment` handler may be reimplemented in Lua or may continue to delegate to C++.
- [ ] Perl quest scripts (maintenance only)
- [ ] Database tables (`peq`)
- [ ] Rule values
- [ ] Server configuration
- [ ] Infrastructure / Docker

## Dependencies

- **Existing companion system must be functional.** This feature adds commands to the already-working companion recruitment and management system. The companion class, equipment system, and command dispatch must be operational.
- **Lua_Companion binding completeness.** The `!stats` command needs access to stat methods (STR, STA, etc.), attack methods (min/max damage), and combat role. Some of these may already be accessible via Lua_Mob inheritance; others (GetMinDMG, GetMaxDMG, GetCombatRole) may need to be exposed on Lua_Companion. The architect should assess which methods are available and what bindings need to be added.

## Open Questions

1. **GetMinDMG/GetMaxDMG availability on Lua_Companion:** These methods exist on `Lua_NPC` but `Lua_Companion` inherits from `Lua_Mob`, not `Lua_NPC`. The architect needs to determine whether to add these bindings to `Lua_Companion` or take another approach (e.g., implementing `!stats` in C++ instead of Lua).
2. **GetCombatRole exposure to Lua:** `CompanionCombatRole GetCombatRole()` exists on the C++ `Companion` class but is not exposed to Lua. The architect should determine the best way to make this available for the `!stats` display.
3. **Item link generation approach for !equipment:** Should the enhanced equipment display be done by modifying the C++ `ShowEquipment()` method (adding item link generation in C++) or by replacing the Lua-side `cmd_equipment` handler to iterate equipment slots and call `eq.item_link()` from Lua? The architect decides.

## Acceptance Criteria

- [ ] A player targets any companion in the zone and types `!stats` in /say. The companion's full stat sheet appears in the player's message window, showing: name, level, class, combat role, HP/MaxHP, Mana/MaxMana, STR, STA, DEX, AGI, INT, WIS, CHA, AC, ATK, min-max damage, and all five resistances (MR, FR, CR, PR, DR).
- [ ] The `!stats` display works when any player targets any companion — not just the companion's owner.
- [ ] A player targets any companion and types `!equipment`. The equipment display shows, for each occupied slot: the slot name, a clickable item link, and a stat summary (AC for armor, Damage/Delay for weapons).
- [ ] Clicking an item link in the `!equipment` display opens the standard EverQuest item inspection window in the Titanium client.
- [ ] The `!equipment` display works when any player targets any companion — not just the companion's owner.
- [ ] Empty equipment slots show "(empty)" next to the slot name.
- [ ] Owner-only commands (`!passive`, `!balanced`, `!aggressive`, `!follow`, `!guard`, `!recall`, `!equip`, `!unequip`, `!unequipall`, `!target`, `!assist`, `!dismiss`) still reject non-owners with "That is not your companion."
- [ ] Using `!stats` or `!equipment` on a non-companion target (regular NPC, player, pet) shows an appropriate error message.
- [ ] Using `!stats` or `!equipment` with no target shows an appropriate error message.
- [ ] The combat role displayed by `!stats` correctly maps to the companion's class: Warriors/Paladins/Shadow Knights show "Melee Tank", Monks/Rangers/Beastlords/Bards show "Melee DPS", Rogues show "Rogue", Wizards/Magicians/Necromancers/Enchanters show "Caster DPS", Clerics/Druids/Shamans show "Healer".
- [ ] No zone crashes occur when using `!stats` on a companion (unlike the existing `#npcstats` command).

---

## Appendix: Technical Notes for Architect

These notes are advisory. The architect makes all implementation decisions.

### Lua_Companion Binding Gap

`Lua_Companion` inherits `Lua_Mob` (not `Lua_NPC`) due to the luabind limitation documented in MEMORY.md. This means `GetMinDMG()`, `GetMaxDMG()`, `GetAttackSpeed()`, and `GetAttackDelay()` from `Lua_NPC` are not available on companion objects in Lua. Options:

- Add `GetMinDMG()`/`GetMaxDMG()` directly to `Lua_Companion` (same pattern as `SetFollowDistance` which was added to work around this gap)
- Add `GetCombatRole()` to `Lua_Companion` returning an integer (0-4), with Lua-side mapping to display strings
- Alternatively, implement the entire `!stats` display in C++ as a `Companion::ShowStats(Client*)` method (parallel to `ShowEquipment`)

### Command Dispatch Access Control

The current `companion.dispatch_prefix_command()` in `companion.lua` has a blanket ownership check. One approach to supporting read-only inspection:

Add a `requires_owner` field to the `COMMANDS` table:
```
stats      = { handler = "cmd_stats",     category = "information", requires_owner = false },
equipment  = { handler = "cmd_equipment", category = "equipment",   requires_owner = false },
```

Then split the ownership check: if `COMMANDS[cmd].requires_owner ~= false`, enforce ownership. Otherwise, proceed without it.

### Item Links

`eq.item_link(item_id)` is available in Lua and generates Titanium-compatible clickable links. This could be used in a Lua-side equipment display implementation. In C++, `quest_manager.varlink(item_id)` provides the same functionality.

### C++ ShowEquipment Reference

Current implementation is at `companion.cpp:1972-2014`. It iterates `kDisplaySlots[]` and calls `database.GetItem(item_id)` to get item names. The `EQ::ItemData*` returned has `AC`, `Damage`, `Delay` fields available.

### Existing !status Command

Located at `companion.lua:556-575`. The `!stats` command is complementary, not a replacement. No changes to `!status` are needed. `!status` should also be marked `requires_owner = false` for consistency.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
