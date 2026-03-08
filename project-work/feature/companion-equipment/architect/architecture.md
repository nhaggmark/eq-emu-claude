# Companion Equipment Management Enhancement — Architecture & Implementation Plan

> **Feature branch:** `feature/companion-equipment`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-03-07
> **Status:** Approved

---

## Executive Summary

This feature upgrades companion equipment management from a system that already
has per-slot storage infrastructure to one that fully works end-to-end. The C++
companion class already stores items in 22 equipment slots and persists them to
the `companion_inventories` database table, but **equipment stats are not applied
to companions** because the `InventoryProfile` (`m_inv`) is never populated with
`ItemInstance` objects — `CalcItemBonuses()` reads from `m_inv` and finds nothing.
The primary C++ fix is populating `m_inv` following the bot system's pattern. The
Lua trade handler and commands need enhancements for multi-slot resolution (prefer
empty slots for rings/wrists), class/race restriction enforcement, and full
19-slot `!equipment` display. Three new Companions rules gate toggleable behavior.
No new opcodes, packets, or database tables are needed.

## Existing System Analysis

### Current State

The companion equipment system has more infrastructure in place than the PRD
assumed. Here is what already works:

**C++ Equipment Storage (companion.h / companion.cpp):**
- `uint32 m_equipment[EQ::invslot::EQUIPMENT_COUNT]` — per-slot item ID array
  (22 slots, indices 0–21)
- `GiveItem(item_id, slot)` — sets `m_equipment[slot]` and `NPC::equipment[slot]`,
  sends `SendWearChange()`, calls `SaveEquipment()` and `CalcBonuses()`
- `RemoveItemFromSlot(slot)` — clears slot, sends WearChange, saves, recalcs
- `LoadEquipment()` — loads from `companion_inventories` DB table via
  `CompanionInventoriesRepository::GetWhere`, syncs to `NPC::equipment[]`
- `SaveEquipment()` — deletes old rows, inserts current equipment to DB
- `ShowEquipment(client)` — iterates slots, shows only occupied ones
- `GiveSlot(client, slot_name)` — returns item from named slot to player
- `GiveAll(client)` — returns all equipped items to player
- `SlotNameToSlotID(name)` — maps slot names to slot constants
- `GetEquipmentMaterial(slot)` — checks companion equipment, falls back to NPC
  base appearance

**Database Persistence (companion_inventories table):**
- Schema: `id`, `companion_id`, `slot_id`, `item_id`, `charges`, `aug_slot_1-5`
- Keyed to `companion_id` (companion identity PK, not NPC type)
- Already per-slot — supports full 22-slot storage
- Equipment survives death (stays in `m_equipment[]` and DB)
- Equipment survives dismissal (DB rows persist with companion record)

**Visual Appearance (protocol layer):**
- `SendWearChange(material_slot)` → `OP_WearChange` to all clients in range
- 9 of 22 slots have visual representation (Head, Chest, Arms, Wrist1, Hands,
  Legs, Feet, Primary, Secondary)
- Wrist2 has no visual (`CalcMaterialFromSlot` returns `materialInvalid`)
- Zone-in appearance via `Spawn_Struct::equipment` (TextureProfile, 9 slots)

**Trade Handler (global_npc.lua event_trade + trading.cpp):**
- `trading.cpp:652` — companion bypass skips standard NPC return logic
- `event_trade` in Lua handles item processing
- `companion_find_slot(slots_bitmask)` — finds first valid slot from bitmask
- Currently calls `GiveSlot` for displaced item, then `GiveItem` for new item

**Lua Commands (companion.lua):**
- `!equipment` → calls `npc:ShowEquipment(client)` (C++ method)
- `!unequip <slot>` → calls `GiveSlot(client, slot_name)`
- `!unequip all` / `!unequipall` → calls `GiveAll(client)`
- `!equip` → shows usage instructions (trade window)
- `!gear` → alias for `!equipment`

### Gap Analysis

Despite the substantial infrastructure, five gaps exist between current state
and PRD requirements:

**Gap 1: Equipment stats not applied (CRITICAL)**
`CalcItemBonuses()` in `bonuses.cpp:131-190` iterates equipment slots and calls
`GetInv().GetItem(i)` to read items from the `InventoryProfile` (`m_inv`).
Companions store item IDs in `m_equipment[]` but **never populate `m_inv` with
`ItemInstance` objects**. Result: `CalcItemBonuses` finds no items and all
equipment stat bonuses (AC, stats, weapon damage, resists, haste, procs) are
zero. Equipment is effectively cosmetic-only. The bot system works because it
calls `m_inv.PutItem(slot_id, *inst)` in `bot.cpp:4083`.

**Gap 2: Multi-slot resolution always picks first slot**
`companion_find_slot()` in `global_npc.lua:118-128` returns the FIRST valid slot
from the item's bitmask using a simple `bit.band` check. For rings (Finger1 OR
Finger2) and wrist items (Wrist1 OR Wrist2), it always picks slot 1 even if
slot 1 is occupied and slot 2 is empty. PRD requires preferring empty slots.

**Gap 3: ShowEquipment only shows occupied slots**
`ShowEquipment()` in `companion.cpp:1318-1343` iterates all slots but only
displays ones with items. PRD requires showing all 19 slots with "(empty)" for
unoccupied ones.

**Gap 4: No class/race restriction enforcement**
The trade handler in `global_npc.lua` does not check class or race restrictions
before equipping items. PRD Goal #7 requires rejection of restricted items.
Items have `Classes` and `Races` bitmasks. `IsEquipable(race_id, class_id)` in
`item_data.cpp:170-181` exists but uses `GetPlayerRaceBit()` which only maps 16
player races — non-player race NPCs return `RaceBitmask::Unknown`.

**Gap 5: No configurable toggles for equipment behavior**
No Companions rules exist for class/race restriction enforcement or equipment
persistence through death. Config-expert recommends three new rules.

## Technical Approach

### Architecture Decision

The least-invasive-first principle was applied with config-expert's input. The
feature requires changes across three layers, each justified:

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `ruletypes.h` + `rule_values` | 3 new rules | Config-expert confirmed no existing rules cover these behaviors. Toggleable enforcement and persistence follow Bot system precedent. |
| `companion.cpp` / `companion.h` | C++ modification | Gap 1 (stats not applied) requires populating `m_inv` with `ItemInstance` objects — this is core engine state that cannot be done from Lua. Gap 3 (ShowEquipment format) is a display change best done in C++ where the method already lives. |
| `global_npc.lua` + `companion.lua` | Lua modification | Gap 2 (multi-slot resolution) and Gap 4 (class/race checks) are in the Lua trade handler. The companion bypass in `trading.cpp:652` deliberately puts item handling in Lua — these changes belong there. |

**What was NOT chosen and why:**
- New database tables: Not needed — `companion_inventories` already supports
  per-slot storage.
- New opcodes or packet changes: Protocol-agent confirmed all required protocol
  exists. No new opcodes, structs, or translations.
- New C++ methods for class/race checking: Item's `IsEquipable()` already exists.
  The Lua binding `item:IsEquipable(race, class)` can be used directly in the
  trade handler.
- Separate companion inventory profile: Companions inherit `m_inv` from Mob
  already. No new class or data structure needed.

### Data Model

No new tables or columns needed. The existing schema is sufficient:

**`companion_inventories`** (existing, no changes):
```
id              INT AUTO_INCREMENT PK
companion_id    INT (FK → companion_data.id)
slot_id         SMALLINT (0-21)
item_id         INT (FK → items.id)
charges         SMALLINT
aug_slot_1-5    INT
```

**`rule_values`** (3 new rows):
```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES
(1, 'Companions:EnforceClassRestrictions', 'true',
 'Enforce class-based item restrictions when equipping items on companions'),
(1, 'Companions:EnforceRaceRestrictions', 'true',
 'Enforce race-based item restrictions when equipping items on companions'),
(1, 'Companions:EquipmentPersistsThroughDeath', 'true',
 'If true, companion equipment is retained after death (not dropped on corpse)');
```

### Code Changes

#### C++ Changes

**File: `eqemu/common/ruletypes.h`**
- Add 3 new `RULE_BOOL` entries to the `Companions` category (after line 1205,
  before `RULE_CATEGORY_END()`):
  ```cpp
  RULE_BOOL(Companions, EnforceClassRestrictions, true,
      "Enforce class-based item restrictions when equipping items on companions")
  RULE_BOOL(Companions, EnforceRaceRestrictions, true,
      "Enforce race-based item restrictions when equipping items on companions")
  RULE_BOOL(Companions, EquipmentPersistsThroughDeath, true,
      "If true, companion equipment is retained after death (not dropped on corpse)")
  ```

**File: `eqemu/zone/companion.cpp`**

*Change 1: Populate `m_inv` when equipping items (Gap 1 fix)*

In `GiveItem(uint32 item_id, uint8 slot)` (line 1175-1189), after setting
`m_equipment[slot]` and before `CalcBonuses()`:
- Create an `EQ::ItemInstance` from the item ID using `database.CreateItem(item_id)`
- Call `m_inv.PutItem(slot, *inst)` to populate the InventoryProfile
- This enables `CalcItemBonuses()` to find the item and apply its stats

In `RemoveItemFromSlot(uint8 slot)` (line 1191-1205), after clearing
`m_equipment[slot]` and before `CalcBonuses()`:
- Call `m_inv.DeleteItem(slot)` to remove from InventoryProfile

In `LoadEquipment()` (line 1207-1232), after loading items from DB and syncing
to `NPC::equipment[]`:
- For each loaded item, create `ItemInstance` and call `m_inv.PutItem(slot, *inst)`
- This ensures stats are applied on zone-in / companion load, not just on equip

In the constructor (line 92 area), initialize the inventory version:
- Call `m_inv.SetInventoryVersion(EQ::versions::MobVersion::NPC)` (or appropriate
  version enum — c-expert should check what Bots use vs NPCs)

*Change 2: Enhanced ShowEquipment display (Gap 3 fix)*

In `ShowEquipment(Client* client)` (line 1318-1343):
- Change to display ALL slots matching the PRD's 19-slot list
- Show item name for occupied slots, "(empty)" for unoccupied
- Use the PRD's exact display format:
  ```
  [Companion Name]'s Equipment:
    Head:        Item Name
    Face:        (empty)
    ...
  ```
- Display 19 slots: Head, Face, Neck, Shoulders, Chest, Back, Arms, Wrist 1,
  Wrist 2, Hands, Finger 1, Finger 2, Legs, Feet, Waist, Primary, Secondary,
  Range, Ammo (skip Charm, Ear1, Ear2 per PRD)

*Change 3: Death handler equipment clear (conditional on rule)*

In the companion death handler (wherever companion death is processed):
- Check `RuleB(Companions, EquipmentPersistsThroughDeath)`
- If `false`: clear all equipment slots, delete from DB, clear `m_inv`
- If `true` (default): do nothing — equipment persists (current behavior)

**File: `eqemu/zone/companion.h`**
- No new method signatures needed — all changes are to existing method bodies
- Verify `m_inv` is accessible (inherited from `Mob` → no issue)

#### Lua/Script Changes

**File: `akk-stack/server/quests/global/global_npc.lua`**

*Change 1: Multi-slot resolution with empty-slot preference (Gap 2 fix)*

Replace `companion_find_slot()` (line 118-128) with enhanced logic:
```
function companion_find_slot(companion, slots_bitmask)
  -- For each slot in the bitmask, check if the companion's slot is empty
  -- Return the first EMPTY matching slot
  -- If no empty matching slot, return the FIRST matching slot (will displace)
  -- If no matching slot at all, return nil
end
```

The function needs access to the companion's current equipment to check which
slots are occupied. Use `companion:GetEquipment(slot_id)` (returns item_id, 0
if empty) to check occupancy.

Slot iteration order should match PRD slot ordering (Head first, Ammo last) to
ensure predictable behavior for multi-slot items.

*Change 2: Class/race restriction enforcement (Gap 4 fix)*

In `event_trade()` (line 132-204), before calling `companion:GiveItem()`:
- Check `eq.get_rule("Companions:EnforceClassRestrictions")` — if true, verify
  `item:IsEquipable(companion:GetRace(), companion:GetClass())` for class
- Check `eq.get_rule("Companions:EnforceRaceRestrictions")` — if true, verify
  the race component of `IsEquipable()`
- If check fails: return item to player via `e.self:SummonItem(item:GetID())`
  and message: "[Companion Name] cannot use that item (class/race restricted)."

**Important race mapping caveat:** `GetPlayerRaceBit()` only handles 16 player
races. Most recruiteable companion NPCs use player races (Human, Elf, Dwarf,
etc.) and will work correctly. Non-player race companions (skeleton, fairy,
etc.) will return `RaceBitmask::Unknown` from `GetPlayerRaceBit()`, which means
`IsEquipable()` will fail the race check for ANY race-restricted item. This is
actually correct behavior — if an item says "Humans only" and the companion is
a skeleton, it SHOULD be rejected. For items with NO race restriction (Races =
65535 / all races), the check passes regardless. No code change needed here.

**Class mapping:** NPC classes 1-16 match player classes 1-16. NPC-specific
classes (Banker=40, Merchant=41, etc.) are not recruiteable as companions, so
no mapping issue exists for class checks.

*Change 3: Money return on trade*

Protocol-agent flagged that money offered alongside items in the trade window is
silently consumed by the companion bypass. Add a check at the start of
`event_trade`:
- If `e.trade.platinum > 0 or e.trade.gold > 0 or e.trade.silver > 0 or e.trade.copper > 0`:
  return the money to the player and message "[Companion Name] has no use for
  money."

**File: `akk-stack/server/quests/lua_modules/companion.lua`**

*Change 1: Slot name alias expansion*

In `cmd_unequip()` (line 526-545), verify slot name aliases from the PRD are
handled. The C++ `SlotNameToSlotID()` already handles basic names. If PRD
aliases (helm, helmet, mask, necklace, etc.) are not in the C++ mapping, add
them either to `SlotNameToSlotID()` in C++ or handle in Lua before calling
`GiveSlot()`.

Review `SlotNameToSlotID()` (companion.cpp:1286-1316) against PRD alias table
and add any missing aliases.

#### Database Changes

**3 new rows in `rule_values`** (see Data Model section above).

No table schema changes. No migration needed.

#### Configuration Changes

**3 new rules in `ruletypes.h`** (see C++ Changes section above):
- `Companions:EnforceClassRestrictions` (bool, default true)
- `Companions:EnforceRaceRestrictions` (bool, default true)
- `Companions:EquipmentPersistsThroughDeath` (bool, default true)

## Implementation Sequence

Tasks ordered by dependency. Each task assigned to a specific expert agent.

| # | Task | Agent | Depends On | Scope |
|---|------|-------|------------|-------|
| 1 | Add 3 new Companions rules to `ruletypes.h` | config-expert | — | Small: 3 lines in ruletypes.h |
| 2 | Insert 3 rule_values rows into database | data-expert | — | Small: 1 SQL INSERT |
| 3 | Fix combat stat integration: populate `m_inv` with `ItemInstance` objects in `GiveItem`, `RemoveItemFromSlot`, `LoadEquipment`, and constructor | c-expert | 1 | Medium: ~30 lines across 4 methods in companion.cpp |
| 4 | Enhance `ShowEquipment` to display all 19 slots with "(empty)" format | c-expert | — | Small: rewrite ~25-line method |
| 5 | Add slot name aliases to `SlotNameToSlotID` per PRD alias table | c-expert | — | Small: ~20 additional case entries |
| 6 | Add death handler equipment clear gated on `EquipmentPersistsThroughDeath` rule | c-expert | 1 | Small: ~10 lines in death handler |
| 7 | Enhance `companion_find_slot` for multi-slot empty-slot preference | lua-expert | — | Small: ~20 lines replacing existing function |
| 8 | Add class/race restriction checks to `event_trade` handler | lua-expert | 1 | Small: ~15 lines before GiveItem call |
| 9 | Add money return check to `event_trade` handler | lua-expert | — | Small: ~5 lines at start of handler |
| 10 | Rebuild server and validate all changes | c-expert | 1-9 | Build: ninja rebuild |

**Dependency notes:**
- Tasks 1 and 2 are independent and can run in parallel.
- Task 3 depends on Task 1 (needs rule definitions compiled to reference them).
- Tasks 4, 5, 7, 9 have no dependencies and can start immediately.
- Task 6 depends on Task 1 (references the death persistence rule).
- Task 8 depends on Task 1 (references enforcement rules).
- Task 10 depends on all other tasks.

**Recommended execution order:**
1. config-expert does Task 1 (rules in ruletypes.h)
2. data-expert does Task 2 (rule_values INSERT) — parallel with Task 1
3. c-expert does Tasks 3, 4, 5, 6 (all C++ work, sequential)
4. lua-expert does Tasks 7, 8, 9 (all Lua work, sequential after Task 1)
5. c-expert does Task 10 (rebuild)

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `m_inv.PutItem` fails for NPC/Companion entity version | Low | High — stats remain broken | Bot system proves this works for non-player entities. c-expert should check `MobVersion` enum for correct version to set. Test by equipping an item and checking `CalcItemBonuses` output. |
| `ItemInstance` memory leak on repeated equip/unequip | Low | Medium — memory growth over time | `m_inv.DeleteItem` should handle cleanup. Verify `InventoryProfile` owns the `ItemInstance` memory. Bot system does this pattern safely. |
| `GetPlayerRaceBit` returning Unknown for edge-case player-race NPCs | Very Low | Low — items incorrectly rejected | Most player-race NPCs map correctly. If a specific race returns Unknown unexpectedly, it fails closed (rejects) which is safe. Server op can toggle `EnforceRaceRestrictions` off as workaround. |
| `SlotNameToSlotID` alias collisions | Very Low | Very Low — wrong slot used | Each alias must map to exactly one slot. PRD aliases are unambiguous. |

### Compatibility Risks

**Existing companion equipment is preserved.** `LoadEquipment()` already loads
from `companion_inventories` — the enhancement adds `m_inv.PutItem` calls during
load, which means existing equipment will start applying stats immediately after
upgrade. This is the desired behavior (equipment should have always applied stats).

**Existing commands still work.** `!equipment`, `!unequip`, `!gear` all use
existing C++ methods. The changes enhance output format (ShowEquipment) and add
aliases (SlotNameToSlotID) but do not break existing command syntax.

**Trade handler backward compatibility.** The Lua trade handler changes add
checks BEFORE the existing `GiveItem` call. If all checks pass, the existing
flow executes unchanged.

**No client-side changes.** Protocol-agent confirmed all protocol is already
correct. No client patch or opcode changes.

### Performance Risks

**`ItemInstance` creation on equip:** `database.CreateItem(item_id)` involves a
database lookup, but this only happens on equip (user-initiated, infrequent).
During `LoadEquipment()` it happens for each equipped item (max 22), once per
companion load — negligible.

**No additional DB queries at runtime.** `SaveEquipment()` and `LoadEquipment()`
already exist and are called at the same frequency. The `m_inv.PutItem` changes
are in-memory only.

**Rule checks in trade handler:** `eq.get_rule()` is a cached lookup (rules are
loaded into memory). Adding 2 rule checks per trade is negligible.

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes. All required extension points exist:

- `m_inv` (InventoryProfile) is inherited from Mob and available to Companion.
  The Bot system proves that non-player entities can use `m_inv.PutItem` to
  enable `CalcItemBonuses`. Verified in `bot.cpp:4083`.
- `CalcBonuses()` is already called by `GiveItem` and `RemoveItemFromSlot`.
  The call chain `CalcBonuses → NPC::CalcBonuses → CalcItemBonuses` works
  once `m_inv` is populated — the gate condition in `NPC::CalcBonuses` passes
  because `RuleB(NPC, UseItemBonusesForNonPets)` defaults to `true`.
- `ShowEquipment` is a straightforward display method — rewriting its format
  is trivial.
- `companion_find_slot` is a ~10-line Lua function — adding empty-slot
  preference is simple.
- `IsEquipable(race, class)` exists and is accessible from Lua via item binding.
- Protocol-agent confirmed: no new opcodes, no client changes, no struct
  modifications needed.

**Hardest part:** Task 3 (populating `m_inv`) is the most technically sensitive
because it touches the Mob inventory system that underpins stats, bonuses, and
combat math. But the Bot system is a proven reference implementation.

### Pass 2: Simplicity

**Is this the simplest approach?** Yes. Alternatives considered and rejected:

- **Custom stat calculation for companions:** Instead of populating `m_inv`,
  we could write a companion-specific `CalcItemBonuses` that reads from
  `m_equipment[]` directly. Rejected: duplicates complex bonus logic, creates
  maintenance burden, diverges from how every other entity type works.

- **Moving slot resolution to C++:** The multi-slot preference logic could be
  in C++ instead of Lua. Rejected: the trade handler is in Lua by design
  (the `trading.cpp` companion bypass deliberately delegates to Lua). Keeping
  slot resolution in Lua maintains the architecture.

- **Adding Charm, Ear1, Ear2 to the display:** The C++ storage supports 22
  slots, but the PRD specifies 19. We could display all 22. Rejected: PRD is
  clear about 19 slots. The 3 omitted slots (Charm, Ear1, Ear2) still store
  and apply stats — they just aren't shown in `!equipment`. This can be added
  later if desired.

- **Separate class/race check in C++:** Could add the restriction check to
  `GiveItem()` in C++. Rejected: the Lua handler is the right place because
  it already handles item return logic and player messaging. C++ methods
  should remain agnostic to business rules.

**Nothing can be deferred** without leaving a gap against PRD acceptance
criteria. Every task maps to a specific PRD goal or acceptance criterion.

### Pass 3: Antagonistic

**What could go wrong?**

1. **Race with trade and CalcBonuses:** If `GiveItem` is called while
   `CalcBonuses` is running, could we get inconsistent state? No — both run
   on the same zone thread. EQEmu is single-threaded per zone. No race
   condition possible.

2. **Player trades 4 items at once, all to same slot:** Trade window allows
   4 items. If player trades 4 helmets: each goes to Head slot in sequence.
   First displaces existing, second displaces first trade, etc. Only the last
   helmet ends up equipped. The displaced items are returned individually via
   `GiveSlot`. This is correct behavior and matches the PRD.

3. **Player's inventory full during unequip all:** `GiveAll` uses
   `SummonItem` which places items on cursor if inventory is full. If cursor
   is also full, items stack. Existing behavior — no change needed. However,
   the Lua `cmd_unequip` for "all" should check after each return whether the
   player can receive more items and stop with a warning if not. Currently
   `GiveAll` in C++ iterates all slots without checking — **the c-expert
   should add inventory capacity checking to `GiveAll`**.

4. **NO DROP items on companions:** PRD allows equipping NO DROP items on
   companions. When unequipped, they return to the player who equipped them.
   This works because the companion owner is the same player. No item
   laundering risk — the item was already NO DROP to the player. The `GiveSlot`
   / `SummonItem` path doesn't check NO DROP status, which is correct here.

5. **Server crash with `m_inv` in memory but not saved:** `SaveEquipment()`
   persists to DB on every equip/unequip. `m_inv` is transient and rebuilt
   from DB on load. A crash loses no data — `LoadEquipment` rebuilds `m_inv`
   from `companion_inventories` on next zone-up.

6. **Companion with equipment crosses zones:** Companions are despawned and
   re-spawned when crossing zones. Equipment is persisted in DB and loaded
   fresh via `LoadEquipment()`. The `m_inv` population happens in
   `LoadEquipment()`, so stats are correct after zone crossing.

7. **Exploit: equip valuable items on companion, dismiss, recruit different
   NPC of same type:** Each companion has a unique `companion_id` (PK).
   Equipment is keyed to `companion_id`, not `npc_type_id`. Recruiting a
   new Guard of the same type creates a new `companion_id`. The old Guard's
   equipment is only accessible by re-recruiting that specific Guard. No
   exploit possible.

8. **Rule toggled at runtime:** If `EnforceClassRestrictions` is toggled
   from true to false while the server is running (via `#reloadrules`),
   previously-rejected items could now be equipped. Already-equipped items
   that violate restrictions remain equipped. This is acceptable — the server
   admin intentionally toggled the rule. No retroactive enforcement needed.

9. **Protocol-agent flagged:** Money in trade window is silently consumed.
   Addressed by Task 9 — Lua handler returns money to player with message.

10. **`m_inv` version mismatch:** If `SetInventoryVersion` is not called or
    uses wrong version, `PutItem` may reject items or mismap slots. c-expert
    must verify the correct `MobVersion` enum value. Bot uses
    `MobVersion::Bot` — companion should use `MobVersion::NPC` or a dedicated
    version if one exists.

### Pass 4: Integration

**Implementation sequence walkthrough:**

1. **config-expert** adds 3 rules to `ruletypes.h`. This is a header change
   that affects compilation but has zero runtime impact until rules are
   referenced in code. Can be done first with no risk.

2. **data-expert** inserts 3 rows into `rule_values`. This is a DB-only
   change. Rules won't be recognized by the server until the new `ruletypes.h`
   is compiled, but having the rows pre-inserted is fine (unknown rules are
   ignored by the rule loader).

3. **c-expert** does all C++ work (Tasks 3, 4, 5, 6). Task 3 (m_inv
   population) is the critical path. Task 4 (ShowEquipment) is independent.
   Task 5 (aliases) is independent. Task 6 (death handler) references a rule
   from Task 1. All C++ changes are in `companion.cpp` (and possibly
   `companion.h` if new includes are needed for `ItemInstance`). No cross-file
   conflicts.

4. **lua-expert** does all Lua work (Tasks 7, 8, 9). Task 7 (multi-slot) is
   in `global_npc.lua`. Task 8 (class/race) is in `global_npc.lua`. Task 9
   (money return) is in `global_npc.lua`. All changes are in the same file's
   `event_trade` handler. Task 8 references rules from Task 1 via
   `eq.get_rule()` — the rule must exist in `ruletypes.h` for this to work.
   Lua-expert can start Tasks 7 and 9 immediately, but Task 8 must wait for
   Task 1 to compile.

5. **c-expert** rebuilds (Task 10). Rebuild picks up all C++ changes
   including new rules. After rebuild and server restart, `#reloadrules` loads
   the DB values inserted by Task 2.

**Verification that each expert has enough context:**

- **config-expert**: Has complete rule definitions from their own dev-notes.md.
  Copy-paste into `ruletypes.h`. No ambiguity.
- **data-expert**: Has complete INSERT statements from config-expert's
  dev-notes.md and this document. No ambiguity.
- **c-expert**: This document describes exactly which methods to modify,
  what to add, and references the Bot system as a pattern. The topography
  docs and actual source code provide implementation detail.
- **lua-expert**: This document describes the logic for each Lua change.
  The existing `global_npc.lua` and `companion.lua` code provide the
  modification points.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| config-expert | 1 (rules in ruletypes.h) | Owns rule definitions. Already researched and documented exact rule text. |
| data-expert | 2 (rule_values INSERT) | Owns database changes. Simple INSERT of 3 rows. |
| c-expert | 3, 4, 5, 6, 10 (C++ changes + rebuild) | Core engine changes: m_inv population, ShowEquipment rewrite, alias additions, death handler, rebuild. |
| lua-expert | 7, 8, 9 (Lua trade handler + commands) | Quest script changes: multi-slot resolution, class/race checks, money return. |

## Validation Plan

The game-tester agent should verify after implementation:

### Equipment Stat Integration (PRD Goals 5)
- [ ] Equip a weapon on a companion — verify melee damage output changes
  (compare DPS with Rusty Sword vs a high-damage weapon)
- [ ] Equip armor on a companion — verify AC increases (check with
  `#showstats` or observe damage taken)
- [ ] Equip stat items — verify stats change (STR, STA, etc.)
- [ ] Unequip items — verify stats revert to base values
- [ ] Zone with equipped companion — verify stats persist after zone-in

### Per-Slot Equipment Management (PRD Goals 1, 2)
- [ ] Trade a helmet to companion — goes to Head slot, returns old Head item
- [ ] Trade item to empty slot — nothing returned
- [ ] Trade ring when Finger 1 occupied, Finger 2 empty — goes to Finger 2
- [ ] Trade ring when both Finger slots occupied — goes to Finger 1,
  displaces existing
- [ ] Trade 4 items at once — all go to correct slots
- [ ] Trade non-equippable item (food, scroll) — returned with message

### Equipment Visibility (PRD Goal 3)
- [ ] `!equipment` shows all 19 slots with names/empty markers
- [ ] Format matches PRD example exactly
- [ ] Equipped items show correct item names
- [ ] Empty slots show "(empty)"

### Slot-Aware Commands (PRD Goal 4)
- [ ] `!unequip head` — returns Head item to player
- [ ] `!unequip primary` — returns Primary weapon to player
- [ ] `!unequip all` — returns all items to player
- [ ] `!unequip head` when Head is empty — shows "nothing equipped" message
- [ ] Slot aliases work: `!unequip helm`, `!unequip helmet`, `!unequip mask`
- [ ] Invalid slot name shows helpful error with valid slot list

### Equipment Persistence (PRD Goal 6)
- [ ] Companion dies → resurrect/respawn → equipment intact
- [ ] Companion dismissed → re-recruited → equipment intact
- [ ] Player logs out → logs in → companion equipment intact
- [ ] Server restart → companion equipment intact

### Class/Race Restrictions (PRD Goal 7)
- [ ] Plate armor on warrior companion — accepted
- [ ] Plate armor on caster companion — rejected with message
- [ ] Race-restricted item on matching race — accepted
- [ ] Race-restricted item on non-matching race — rejected with message
- [ ] Toggle `EnforceClassRestrictions` to false → plate on caster accepted
- [ ] Toggle `EnforceRaceRestrictions` to false → any race item accepted

### Visual Appearance (PRD acceptance criteria)
- [ ] Equip visible slot (Head, Chest, etc.) — companion appearance updates
- [ ] Unequip visible slot — appearance reverts
- [ ] Equip non-visual slot (Neck, Finger, etc.) — no visual change, no error

### Edge Cases
- [ ] Trade money to companion — money returned with message
- [ ] Unequip all with full inventory — partial return with warning
- [ ] NO DROP item equip → unequip — returned to player
- [ ] Multiple companions with different equipment — no cross-contamination
- [ ] Equip item, zone, check `!equipment` — item still there
- [ ] No item duplication on any equip/unequip/trade operation

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
