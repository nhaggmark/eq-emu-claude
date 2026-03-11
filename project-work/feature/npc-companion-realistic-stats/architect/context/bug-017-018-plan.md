# Bug Triage and Fix Plan: BUG-017 and BUG-018

**Author:** architect
**Date:** 2026-03-11
**Feature:** npc-companion-realistic-stats
**Branch:** feature/npc-companion-realistic-stats

---

## BUG-017: Wrong Mana Percentage in Chat Messages

### Root Cause Analysis

**Root cause: `CalcBonuses()` overwrites the level-scaled `max_mana` via `NPC::CalcMaxMana()`.**

The mana percentage is computed by `Mob::GetManaRatio()` (`zone/mob.h:674`):

```cpp
inline float GetManaRatio() const {
    return max_mana == 0 ? 100 :
        ((static_cast<float>(current_mana) / max_mana) * 100);
}
```

This uses the `max_mana` member variable directly. The problem is that Companion
does NOT override `CalcMaxMana()`, so the NPC base class version runs whenever
`CalcBonuses()` is called.

**The conflicting code paths:**

1. **`Companion::ScaleStatsToLevel()`** (`companion.cpp:289-319`):
   - Scales INT and WIS by level ratio (lines 305-306)
   - Sets `max_mana = (int64)(m_base_mana * scale)` (line 317)
   - Then calls `CalcBonuses()` (line 319)

2. **`CalcBonuses()` chain** (`bonuses.cpp:50-60`):
   - `NPC::CalcBonuses()` calls `CalcItemBonuses()` then `Mob::CalcBonuses()`
   - `Mob::CalcBonuses()` calls `CalcMaxMana()` (line 37)
   - Since Companion has no `CalcMaxMana()` override, `NPC::CalcMaxMana()` runs

3. **`NPC::CalcMaxMana()`** (`npc.cpp:2720-2749`):
   - If `npc_mana == 0`: recalculates from `GetINT()/2 + 1) * GetLevel()` + bonuses
   - If `npc_mana != 0`: uses `npc_mana + bonuses`
   - Either way, it OVERWRITES `max_mana` with its own formula, discarding the
     level-scaled value that `ScaleStatsToLevel()` just set

**The result:** `max_mana` is wrong because `NPC::CalcMaxMana()` uses
`npc_mana` (the original recruited NPC's mana from `npc_types`) or the
INT/WIS-based formula, but NOT the level-scaled value. This means:

- If the companion has leveled up, `max_mana` is too LOW (based on recruited
  level data, not current level)
- If equipment has increased INT/WIS, those bonuses ARE correctly included
  by `NPC::CalcMaxMana()`, but the base value is wrong because it uses
  `npc_mana` instead of the scaled base

**Where the wrong percentage appears:**

The mana percentage chat messages are emitted in three places in `companion.cpp`:

1. **Spell casting** (`companion.cpp:1709-1715` in `AIDoSpellCast()`):
   ```cpp
   int mana_pct = GetMaxMana() > 0 ? static_cast<int>(GetManaRatio()) : 100;
   CompanionGroupSay(this, "Casting %s on %s [Mana: %d%%]", spell_name, tar->GetCleanName(), mana_pct);
   ```

2. **Passive stance sitting** (`companion.cpp:1414-1415`):
   ```cpp
   CompanionGroupSay(this, "Mana: %d%%", static_cast<int>(GetManaRatio()));
   ```

3. **Balanced/aggressive stance sitting** (`companion.cpp:1571-1573`):
   ```cpp
   int mana_pct = static_cast<int>(GetManaRatio());
   CompanionGroupSay(this, "Mana: %d%%", mana_pct);
   ```

All three call `GetManaRatio()` which uses `max_mana`. The chat message code
itself is correct -- the bug is that `max_mana` is wrong.

**Additionally affected:** Every call to `CalcBonuses()` resets `max_mana`
incorrectly. This includes:
- `GiveItem()` (line 2460)
- `RemoveItemFromSlot()` (line 2480)
- `LoadEquipment()` (line 2521)
- `ApplyStatScalePct()` (indirectly, line 347 sets max_mana then CalcBonuses
  at line 385 overwrites it)

This is the same pattern as `CalcMaxHP()` which was overridden in Phase 3
(`companion.cpp:785`). The mana equivalent was never implemented.

### Fix Approach

**Add `Companion::CalcMaxMana()` override** that mirrors the HP override pattern:

1. Start with the level-scaled base: `m_base_mana * (current_level / recruited_level)`
2. Add item and spell mana bonuses: `itembonuses.Mana + spellbonuses.Mana`
3. Apply `StatScalePct` rule if applicable
4. Set `max_mana` to this result
5. Clamp `current_mana` to not exceed `max_mana`

The override should be declared in `companion.h` and implemented in
`companion.cpp`, placed adjacent to `CalcMaxHP()` for consistency.

**Files to modify:**
- `eqemu/zone/companion.h` -- Add `virtual int64 CalcMaxMana() override;` declaration
- `eqemu/zone/companion.cpp` -- Implement `Companion::CalcMaxMana()`

**No changes needed to:** chat message code, Lua scripts, database, or config.
The mana ratio calculation and chat output are correct -- only the underlying
`max_mana` value is wrong.

### Test Requirements

**Discriminating tests (should fail before fix, pass after):**

1. **CalcMaxMana after ScaleStatsToLevel:** Create companion at level 10,
   scale to level 20 via ScaleStatsToLevel(20). Verify `GetMaxMana()` returns
   approximately `m_base_mana * 2.0` (plus item/spell bonuses), not the
   npc_types base value.

2. **CalcMaxMana after CalcBonuses:** Create companion, call CalcBonuses().
   Verify `GetMaxMana()` matches the expected level-scaled value, not the
   NPC base formula.

3. **CalcMaxMana with equipment:** Create companion, equip item with +mana.
   Verify `GetMaxMana()` includes the item bonus on top of the scaled base.

4. **GetManaRatio accuracy:** Set current_mana to exactly 50% of expected
   max_mana. Verify `GetManaRatio()` returns ~50.0f.

5. **CalcMaxMana for non-caster:** Warrior companion should have GetMaxMana()
   return 0, regardless of equipment.

### Regression Risks

- **Mana regen:** `CalcManaRegen()` uses `GetMaxMana()` for sitting/standing
  checks. The fix should improve mana regen accuracy, not break it.
- **OOM bail:** AICastSpell checks `GetManaRatio() < 10.0f`. With correct
  max_mana, the OOM threshold is accurate. If max_mana was previously
  inflated, companions might OOM more frequently. This is correct behavior.
- **Spell casting:** AIDoSpellCast uses `GetMaxMana() > 0` to determine if
  the companion is a mana user. This should be unaffected.

---

## BUG-018: Equipment Trade Duplication

### Root Cause Analysis

**Probable root cause: `item_list` double-construction in `trading.cpp:611-617`
causing the EVENT_TRADE handler to receive duplicate item entries.**

The trade flow for NPCs (including companions) at `trading.cpp:510-660`:

1. Items are popped from the player's trade inventory (`insts[4]`, lines 518-522)
2. A copy is made: `std::vector<EQ::ItemInstance*> items(insts, insts + std::size(insts))` (line 525)
3. The item_list for the quest event is constructed (lines 611-617):

```cpp
std::vector<std::any> item_list(items.begin(), items.end());  // copies ALL 4 slots
for (EQ::ItemInstance *inst: items) {
    if (!inst || !inst->GetItem()) {
        continue;
    }
    item_list.emplace_back(inst);  // ADDS VALID ITEMS AGAIN
}
```

For a single-item trade, `item_list` ends up with 5 entries:
`[valid_item, nullptr, nullptr, nullptr, valid_item]`.

4. In `handle_npc_event_trade()` (`lua_parser_events.cpp:49-118`), lines 72-82
   iterate ALL entries of extra_pointers, setting them as `item1` through
   `item{N}` on the Lua trade table.

5. The Lua handler in `global_npc.lua:210` iterates `for i = 1, 4`, so it
   only processes `item1` through `item4`. For a single-item trade, only
   `item1` is valid. **This should mean the duplicate item5 is never processed.**

**However:** This analysis suggests the Lua handler should only process one item.
The fact that duplication occurs means there is an additional return path that
was not identified in static analysis. The most likely candidates are:

**Candidate A: Double event dispatch.** `EventNPC()` fires both `EventNPCLocal`
and `EventNPCGlobal` unconditionally (`quest_parser_collection.cpp:488-490`).
If a companion's NPC type happens to match a zone-specific NPC script file
(e.g., the companion was recruited from a quest NPC that has its own script),
the local script's `event_trade` / `EVENT_ITEM` handler would fire FIRST,
potentially returning the traded items via `plugin::return_items()` or
`eq.return_items()`. Then `global_npc.lua`'s `event_trade` fires and calls
`GiveSlot()` to return the old item. Result: TWO returns.

This is the most likely cause because:
- Not all companions would trigger it (only those recruited from NPCs with
  local quest scripts that handle trades)
- `plugin::returnUnusedItems()` in default.pl IS currently a no-op, but
  if the companion's NPC type matches any zone script with an EVENT_ITEM
  sub, that zone script's handler runs

**Candidate B: `item_list` duplication causing processing of item5.** If for
some reason `sz = extra_pointers->size()` exceeds 4, the Lua handler would
set both `item1` and `item5` as valid items. While the Lua `for i = 1, 4`
loop shouldn't process item5, a future change to the loop bound or a
different code path could expose this.

**Candidate C: The handin system's return path.** `CheckHandin()` at line 643
initializes the handin bucket with the traded items. Even though `ResetHandin()`
is called for companions at line 653, there might be a narrow window where
the handin return fires between EVENT_TRADE and the IsCompanion() check.
However, the code flow is synchronous, so this is unlikely.

**Recommended investigation approach for c-expert:**
1. Add logging to `Companion::GiveSlot()` and `Client::SummonItem()` to
   trace every item creation event during a companion equipment swap
2. Add logging to `EventNPCLocal()` and `EventNPCGlobal()` to confirm
   whether both fire for companion EVENT_TRADE
3. Reproduce with a companion recruited from a quest NPC (one with a local
   script) vs. a generic NPC (no local script) to test Candidate A

### Fix Approach

**Primary fix (addresses Candidate A and provides general safety):**

Add a guard in the Lua `event_trade` handler in `global_npc.lua` to prevent
the slot return if the item was already returned by a local handler. This
can be done by checking if the slot is already empty before calling GiveSlot:

```lua
-- Before returning old item, check slot is actually occupied
local old_item_id = e.self:GetEquipment(slot_id)
if old_item_id ~= 0 then
    e.self:GiveSlot(e.other, slot_name)
end
```

**Secondary fix (addresses Candidate B):**

Fix the `item_list` double-construction in `trading.cpp:611-617`. The loop
at lines 612-617 should be removed because the range constructor at line 611
already includes all items. This is a pre-existing bug in the EQEmu codebase
that happens to be masked by the `for i = 1, 4` bound in most handlers.

Replace:
```cpp
std::vector<std::any> item_list(items.begin(), items.end());
for (EQ::ItemInstance *inst: items) {
    if (!inst || !inst->GetItem()) { continue; }
    item_list.emplace_back(inst);
}
```
With:
```cpp
std::vector<std::any> item_list(items.begin(), items.end());
```

**Tertiary fix (defense in depth):**

In `Companion::GiveSlot()`, add an early return guard to prevent returning
an item that has already been removed:

```cpp
uint32 item_id = m_equipment[slot];
if (item_id == 0) {
    return false;  // Already existing, but ensures no double-return
}
```

This guard already exists at line 2696-2698, so GiveSlot IS safe against
double-calls. If the slot is empty (already cleared by a prior GiveSlot
call), it returns false without summoning an item.

**Files to modify:**
- `akk-stack/server/quests/global/global_npc.lua` -- Add pre-check before
  GiveSlot call (Primary fix)
- `eqemu/zone/trading.cpp` -- Remove duplicate item_list entries (Secondary fix)

### Test Requirements

**Discriminating tests (should fail before fix, pass after):**

1. **Single item swap:** Give companion a sword. Give companion a different
   sword for the same slot. Verify player receives exactly ONE copy of the
   old sword.

2. **Multi-slot swap:** Give companion head armor and chest armor. Replace
   both in a single 2-item trade. Verify player receives exactly ONE copy
   of each old item.

3. **Empty slot equip:** Give an item to a companion's empty slot. Verify
   player receives NO items back (only the item is equipped).

4. **Double-swap in same session:** Replace the same slot twice in quick
   succession. Verify no duplication occurs on either swap.

5. **Quest NPC companion:** Recruit a companion from an NPC that has a
   local quest script with EVENT_TRADE/event_trade handler. Trade equipment.
   Verify no duplication (tests Candidate A).

### Regression Risks

- **Removing item_list duplicate entries** (trading.cpp) affects ALL NPC
  trades, not just companions. However, since all known handlers iterate
  item1-item4 and the duplicate entries are item5+, removing them should
  have no effect on existing quest scripts. Test with standard quest NPC
  hand-ins after the change.
- **GiveSlot pre-check** in global_npc.lua is safe because GiveSlot already
  handles empty slots (returns false). The pre-check just avoids an
  unnecessary function call.

---

## Implementation Order

1. **BUG-017 first** (c-expert) -- The CalcMaxMana override is a clean,
   self-contained C++ change with no Lua or cross-system dependencies.
   It also fixes a broader stat correctness issue that affects AI decisions
   (OOM bail, mana conservation thresholds).

2. **BUG-018 second** (c-expert for trading.cpp, lua-expert for global_npc.lua) --
   Requires both C++ and Lua changes. The c-expert should first add diagnostic
   logging to confirm the root cause (Candidate A vs B vs C), then implement
   the fix. The lua-expert adds the GiveSlot pre-check.

## Assigned Agents

| Task | Agent | Files |
|------|-------|-------|
| BUG-017: Add CalcMaxMana override | **c-expert** | `eqemu/zone/companion.h`, `eqemu/zone/companion.cpp` |
| BUG-018: Diagnose duplication path | **c-expert** | `eqemu/zone/trading.cpp` (add logging, then fix item_list) |
| BUG-018: Add GiveSlot pre-check | **lua-expert** | `akk-stack/server/quests/global/global_npc.lua` |

Both bugs require rebuild + restart for testing. The c-expert should fix
BUG-017 first, build, then fix BUG-018 in the same build cycle.
