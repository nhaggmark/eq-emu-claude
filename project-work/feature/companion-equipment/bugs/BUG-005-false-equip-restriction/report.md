# BUG-005: Compatible item falsely rejected by class/race restriction check

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-08
> **Feature:** companion-equipment
> **Status:** Fix deployed, pending validation

---

## Observed Behavior

When trading a Rusty Mace to Guard Liben (Human Warrior), the companion
reports that his class/race cannot use the item and returns it. The Rusty
Mace is usable by WAR CLR PAL RNG SHD DRU MNK BRD ROG SHM BST — Warrior
is explicitly in the list. Guard Liben is a Human Warrior. The item should
be accepted and equipped.

## Expected Behavior

Guard Liben (Human Warrior) should accept the Rusty Mace and equip it in
the Primary or Secondary slot. If he already has a weapon in that slot
(Rusty Spear), the existing weapon should be returned and the mace equipped.

## Reproduction Steps

1. Recruit Guard Liben as a companion (Human Warrior)
2. He already has a Rusty Spear equipped (may be 2H — investigate)
3. Open trade window, give him a Rusty Mace (1H Blunt, WAR-usable)
4. Observe: companion says class/race cannot use it, returns item
5. Confirm via `#npcstats` that Guard Liben is Human Warrior

## User Hypothesis

The currently equipped Rusty Spear may be a 2H weapon occupying both
Primary and Secondary slots. The slot-finding logic may be failing because
of the 2H weapon interaction, or the IsEquipable check may be passing
incorrect race/class values (NPC type IDs vs player bitmask values).

## Evidence

- Previous screenshot showed the class/race rejection message
- Guard Liben confirmed as Human Warrior via `#npcstats`
- Rusty Mace item window shows WAR in the class list

## Affected Systems

- [ ] C++ server source → c-expert
- [x] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert

---

## Architecture Assessment (Triage by architect — 2026-03-08)

### Root Cause: NPC Model Race vs Player Race

**The bug is in the Lua trade handler at `global_npc.lua` line 213-218.** The
code passes the NPC's model race ID to `IsEquipable()`, but that function
expects a player race ID. Most NPCs use non-player model race IDs even when
they look like a player race.

#### The exact failure chain:

1. **Guard Liben's database record** (`npc_types` id=2122):
   - `race = 71` (QeynosCitizen — a model/appearance race)
   - `class = 1` (Warrior — a valid player class)
   - `level = 5`

2. **Lua code** (`global_npc.lua` lines 213-214):
   ```lua
   local comp_race  = e.self:GetRace()   -- returns 71 (QeynosCitizen)
   local comp_class = e.self:GetClass()  -- returns 1 (Warrior)
   ```

3. **C++ `IsEquipable(71, 1)` call chain**:
   - `ItemInstance::IsEquipable(71, 1)` delegates to `ItemData::IsEquipable(71, 1)`
   - Race check: `Races & GetPlayerRaceBit(71)`
   - `GetPlayerRaceBit(71)` — race 71 is NOT in the switch statement (only
     player races 1-12, 128, 130, 330, 522 are mapped). Falls through to
     `default`, returns `RaceBitmask::Unknown = 0`
   - `65535 & 0 = 0` → race check FAILS
   - Item is rejected despite `races = 65535` (ALL RACES)

4. **Why the class check passes but race check fails:**
   - Class 1 (Warrior) IS a valid player class → `GetPlayerClassBit(1)` returns 1
   - `17407 & 1 = 1` → class check passes
   - Race 71 is NOT a valid player race → `GetPlayerRaceBit(71)` returns 0
   - ANY races value ANDed with 0 = 0 → race check ALWAYS fails

### The 2H Weapon Theory: NOT the cause

The Rusty Spear (item 7009) has:
- `itemtype = 2` → `ItemType1HPiercing` (1H piercing, NOT 2H)
- `slots = 8192` → bit 13 only = primary slot only

The Rusty Mace (item 6011) has:
- `itemtype = 3` → `ItemType1HBlunt` (1H blunt)
- `slots = 24576` → bits 13+14 = primary + secondary

The slot-finding logic would correctly try secondary (empty) first, then
primary. The 2H theory is ruled out. The failure occurs at the race check
before slot assignment.

### Scope of Impact

This bug affects ALL NPCs with non-player model race IDs. In the database,
the following "citizen" and "guard" races look like playable races visually
but have non-player race IDs:

| Race ID | Race Name | NPC Count |
|---------|-----------|-----------|
| 44 | FreeportGuard | 309 |
| 55 | HumanBeggar | 63 |
| 67 | HighpassCitizen | 105 |
| 71 | QeynosCitizen | 631 |
| 77 | NeriakCitizen | 137 |
| 78 | EruditeCitizen | 95 |
| 81 | RivervaleCitizen | 166 |
| 90 | HalasCitizen | 57 |
| 92 | GrobbCitizen | 14 |
| 93 | OggokCitizen | 88 |
| 94 | KaladimCitizen | 118 |

That is 1,783 NPCs that would fail ALL race-restricted item checks when
recruited as companions, even for items marked "ALL RACES".

NPCs with actual player race IDs (1=Human, 2=Barbarian, etc.) would work
correctly. But the majority of "city guard" and "citizen" NPCs use the
cosmetic race variants above.

### Fix Approach

**The fix belongs in the Lua trade handler** (`global_npc.lua`), NOT in C++.
The `IsEquipable()` function works correctly — it is designed for player
race/class IDs. The bug is that we are passing it NPC model race IDs.

#### Option A: Map NPC model races to player races in Lua (RECOMMENDED)

Create a lookup table in the Lua trade handler (or companion module) that
maps known NPC model races to their corresponding player races:

```lua
local NPC_RACE_TO_PLAYER_RACE = {
    [44]  = 1,   -- FreeportGuard → Human
    [55]  = 1,   -- HumanBeggar → Human
    [67]  = 1,   -- HighpassCitizen → Human
    [71]  = 1,   -- QeynosCitizen → Human
    [77]  = 6,   -- NeriakCitizen → Dark Elf
    [78]  = 3,   -- EruditeCitizen → Erudite
    [81]  = 11,  -- RivervaleCitizen → Halfling
    [90]  = 2,   -- HalasCitizen → Barbarian
    [92]  = 9,   -- GrobbCitizen → Troll
    [93]  = 10,  -- OggokCitizen → Ogre
    [94]  = 8,   -- KaladimCitizen → Dwarf
}
```

Then in the trade handler, resolve the race before calling IsEquipable:

```lua
local comp_race = NPC_RACE_TO_PLAYER_RACE[e.self:GetRace()] or e.self:GetRace()
```

If the NPC's race doesn't map to any player race (e.g., a skeleton or
dragon), `GetPlayerRaceBit()` will return 0 and the item will be rejected.
This is correct behavior — a skeleton shouldn't equip human-only armor.

However, for truly non-player races, we may want to either:
- Skip race enforcement entirely (let those NPCs equip anything), or
- Only enforce race checks when the NPC has a mappable player race

**Recommended behavior:** If the NPC's race cannot be mapped to a player
race, skip the race check entirely but still enforce class restrictions.
This allows exotic NPCs (skeletons, ogres with unusual race IDs) to equip
items based on class alone, which is more fun for a companion system.

#### Option B: Use `GetBaseRace()` instead of `GetRace()`

If the companion C++ class or NPC base class has a `GetBaseRace()` method
that returns the underlying player race, use that. However, NPCs do not
typically have a "base race" concept — `GetBaseRace()` in `Mob` returns
the race they were created with, which for Guard Liben would still be 71.

**Verdict: Option A is the correct fix.** Option B would not solve the
problem because NPC base race IS the model race.

#### Option C: Skip race check for non-player races

Simpler variant of Option A: instead of mapping, just check if the NPC
race is a player race. If not, skip the race portion of the restriction
check (still enforce class):

```lua
local comp_race  = e.self:GetRace()
local comp_class = e.self:GetClass()
-- Only enforce race restrictions for player-race NPCs
local is_player_race = comp_race >= 1 and comp_race <= 12
    or comp_race == 128 or comp_race == 130 or comp_race == 330 or comp_race == 522
if enforce_race and is_player_race then
    if not inst:IsRaceEquipable(comp_race) then
        -- reject
    end
end
if enforce_class then
    if not inst:IsClassEquipable(comp_class) then
        -- reject
    end
end
```

**This avoids maintaining a mapping table** but loses the ability to enforce
race restrictions on citizen-model NPCs (a Qeynos guard couldn't be blocked
from wearing Iksar-only gear). For a small-group fun server, this is likely
acceptable.

### Recommended Fix: Option A (mapping table)

Option A is the most correct because it preserves race enforcement for the
vast majority of recruitable NPCs (guards, citizens) who DO correspond to
player races. It also establishes a pattern that can be extended if new
citizen/guard races are discovered.

The mapping table can live in the `companion` Lua module alongside the
existing companion utilities.

### Assignment

**lua-expert** should implement the fix in `global_npc.lua` (and optionally
`companion.lua` for the mapping table). No C++ changes needed. No database
changes needed. No rebuild needed — just `#reloadquest` after editing.

### Additional Notes

- The `IsClassEquipable()` and `IsRaceEquipable()` C++ methods exist as
  separate calls on ItemInstance. The Lua code could call them independently
  rather than the combined `IsEquipable(race, class)`. This would allow
  enforcing class checks even when race checks are skipped.
- The Bot system (`bot_item_use.cpp` line 192) faces the same conceptual
  issue but avoids it because Bots are always created with player race IDs
  (1-16). Companions recruited from NPCs do not have this guarantee.
- The NPC class check works because NPC warrior class (1) happens to match
  player warrior class (1). This is true for all 16 base classes. The class
  issue would only arise for GM-variant classes (20-35) or NPC service
  classes (40+), which are unlikely to be recruitable companions.
