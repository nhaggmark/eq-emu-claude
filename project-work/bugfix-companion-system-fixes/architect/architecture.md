# Companion System Bug Fixes — Architecture & Implementation Plan

> **Feature branch:** `bugfix/companion-system-fixes`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-03-01
> **Status:** Approved

---

## Executive Summary

Three bugs in the companion system need fixing: (1) LLM chat silently fails — config-expert verified the sidecar IS healthy and reachable (DNS resolves, health endpoint OK, model loaded), so the failure is in the Lua code path (`llm_bridge.lua` `io.popen(curl)` call or JSON response handling) — the fix requires diagnosing and fixing the actual Lua failure plus adding server-log error visibility, (2) equipment display fails because `Companion::GiveItem()` writes to `Companion::m_equipment[]` but `NPC::GetEquipmentMaterial()` reads from `NPC::equipment[]` — a dual-array mismatch fixed by overriding `GetEquipmentMaterial()` and `GetEquippedItemFromTextureSlot()` in the Companion class and syncing both arrays, and (3) equipment persistence fails because `Companion::LoadEquipment()` is fully implemented but has zero call sites — fixed by adding a call in `Companion::Load()` and syncing to `NPC::equipment[]` after loading. All three fixes are surgically targeted: Bug 1 is Lua diagnosis and fix, Bugs 2-3 are C++ changes to `companion.cpp` and `companion.h` only.

## Existing System Analysis

### Current State

**Companion Entity Hierarchy:**
`Entity → Mob → NPC → Companion` (companion.h:67)

Companion inherits from NPC, which provides the core equipment rendering pipeline:
- `NPC::equipment[EQ::invslot::EQUIPMENT_COUNT]` (npc.h:753) — the NPC's equipment array, populated from loot tables at spawn
- `NPC::GetEquipmentMaterial(uint8 material_slot)` (npc.cpp:1600) — reads `equipment[invslot]` to determine item material for rendering
- `NPC::GetEquippedItemFromTextureSlot(uint8 material_slot)` (mob_appearance.cpp:331) — reads `equipment[inventory_slot]` to return the item ID for a given texture slot

Companion adds its own equipment system (companion.h:304):
- `Companion::m_equipment[EQ::invslot::EQUIPMENT_COUNT]` — a separate equipment array
- `Companion::GiveItem()`, `RemoveItemFromSlot()`, `SaveEquipment()`, `LoadEquipment()` — CRUD operations on `m_equipment[]`

**Equipment Rendering Pipeline:**
1. `Mob::FillSpawnStruct()` (mob.cpp:1362-1369) calls `GetEquipmentMaterial(i)` for each material slot to populate the spawn packet's equipment fields
2. `Mob::SendWearChange()` (mob_appearance.cpp:378-384) calls `GetEquipmentMaterial(material_slot)` to populate the `OP_WearChange` packet
3. Both methods dispatch virtually to `NPC::GetEquipmentMaterial()`, which reads from `NPC::equipment[]`

**Equipment Persistence Pipeline:**
- **Save path:** `GiveItem()` → `SaveEquipment()` → writes to `companion_inventories` table — WORKS
- **Load path:** `LoadEquipment()` → reads from `companion_inventories` → populates `m_equipment[]` — IMPLEMENTED BUT NEVER CALLED
- **Spawn path:** `SpawnCompanionsOnZone()` → `new Companion()` → `Load(cd.id)` → `Spawn()` — Load() does NOT call LoadEquipment()

**LLM Chat Pipeline:**
- `global_npc.lua:event_say` → companion falls through to LLM block → `llm_bridge.is_eligible(e)` → `llm_bridge.build_context(e)` → `llm_bridge.generate_response(context, message)` → `e.self:Say(response)`
- `generate_response()` uses `io.popen(curl)` to call the sidecar at `http://npc-llm:8100/v1/chat`
- On failure, returns nil → companion stays silent (no error visible to player or server logs)
- **Config-expert verification:** The sidecar IS running and healthy — container up 3+ hours, DNS resolves (`npc-llm` → `172.18.0.9`), health endpoint returns OK (model loaded, ChromaDB connected). The failure is in the Lua code path, not infrastructure.

### Gap Analysis

**Bug 1 — LLM Chat:** The sidecar is verified healthy and reachable (config-expert confirmed via `docker ps`, DNS resolution test, and `/v1/health` endpoint check). The failure is therefore in the Lua code path — most likely in `llm_bridge.generate_response()` (llm_bridge.lua:164-217). Possible causes: (a) `io.popen()` shell escaping issue corrupting the JSON body, (b) sidecar returning unexpected response format, (c) the curl command failing silently in the zone process environment. The `pcall` wrappers in global_npc.lua:56-64 would catch Lua errors, but they print to the player as `[DEBUG]` messages — if the player sees no debug messages, the code is running without error but returning nil. The lua-expert must diagnose the exact failure point.

**Bug 2 — Equipment Display:** Two separate equipment arrays exist:
- `NPC::equipment[]` (inherited, npc.h:753) — read by the rendering pipeline
- `Companion::m_equipment[]` (companion.h:304) — written by GiveItem()
- Companion does NOT override `GetEquipmentMaterial()` or `GetEquippedItemFromTextureSlot()`
- Therefore: GiveItem writes to m_equipment, SendWearChange reads from NPC::equipment (which is empty) → material=0 → no visual

**Bug 3 — Equipment Persistence:** `LoadEquipment()` (companion.cpp:1150-1168) is fully implemented. It reads from `companion_inventories` and populates `m_equipment[]`. But it has ZERO call sites — `Load()` (companion.cpp:981-1013) does not call it. Even if it were called, the loaded items would only populate `m_equipment[]` and not `NPC::equipment[]`, so they would be invisible (Bug 2 again).

## Technical Approach

### Architecture Decision

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `companion.cpp` | C++ — override two virtual methods, add one call, add sync lines | Bug 2: override `GetEquipmentMaterial()` and `GetEquippedItemFromTextureSlot()` to read from `m_equipment[]`. Bug 3: call `LoadEquipment()` from `Load()` and sync to `NPC::equipment[]`. These are inheritance-level C++ issues that cannot be solved at any other layer. |
| `companion.h` | C++ — declare two virtual method overrides | Declare the overrides |
| `llm_bridge.lua` | Lua — diagnose and fix the actual failure in generate_response() | Bug 1: config-expert confirmed sidecar is healthy. The Lua code is failing silently. Lua-expert must diagnose the exact failure (shell escaping? response format? curl environment?) and fix it, plus add server-log error visibility. |

### Data Model

No database schema changes required. The `companion_inventories` table already exists and is correctly structured. The save path (`SaveEquipment()`) already works. Only the load path needs to be exercised.

### Code Changes

#### C++ Changes

**File: `eqemu/zone/companion.h`** — Add two method declarations in the public section:

```cpp
// After FillSpawnStruct declaration:
uint32 GetEquipmentMaterial(uint8 material_slot) const override;
uint32 GetEquippedItemFromTextureSlot(uint8 material_slot) const override;
```

**File: `eqemu/zone/companion.cpp`** — Four changes:

**Change 1 (Bug 2): Override `GetEquipmentMaterial()`**

Add a `Companion::GetEquipmentMaterial()` override that checks `m_equipment[]` first. If the companion has an item in the corresponding slot, look up the item's material via the base Mob class. Otherwise, fall back to `NPC::GetEquipmentMaterial()` for the NPC's base appearance.

```cpp
uint32 Companion::GetEquipmentMaterial(uint8 material_slot) const
{
    if (material_slot >= EQ::textures::materialCount) {
        return 0;
    }

    int16 invslot = EQ::InventoryProfile::CalcSlotFromMaterial(material_slot);
    if (invslot == INVALID_INDEX) {
        return 0;
    }

    // Check companion's own equipment first
    if (invslot >= EQ::invslot::EQUIPMENT_BEGIN &&
        invslot <= EQ::invslot::EQUIPMENT_END &&
        m_equipment[invslot] != 0) {
        // Item exists in companion equipment — use Mob base class to resolve material
        return Mob::GetEquipmentMaterial(material_slot);
    }

    // No companion equipment in this slot — fall back to NPC base appearance
    return NPC::GetEquipmentMaterial(material_slot);
}
```

**Change 2 (Bug 2): Override `GetEquippedItemFromTextureSlot()`**

This is called by `Mob::GetEquipmentMaterial()` to get the item ID for a material slot. For companions, it must read from `m_equipment[]`.

```cpp
uint32 Companion::GetEquippedItemFromTextureSlot(uint8 material_slot) const
{
    if (material_slot >= EQ::textures::materialCount) {
        return 0;
    }

    const int16 inventory_slot = EQ::InventoryProfile::CalcSlotFromMaterial(material_slot);
    if (inventory_slot == INVALID_INDEX) {
        return 0;
    }

    if (inventory_slot >= EQ::invslot::EQUIPMENT_BEGIN &&
        inventory_slot <= EQ::invslot::EQUIPMENT_END) {
        return m_equipment[inventory_slot];
    }

    return 0;
}
```

**Change 3 (Bug 2): Sync `NPC::equipment[]` in GiveItem() and RemoveItemFromSlot()**

In `GiveItem()`, after `m_equipment[slot] = item_id` (line 1131), add:
```cpp
equipment[slot] = item_id;  // sync to NPC::equipment[] for direct-access code paths
```

In `RemoveItemFromSlot()`, after `m_equipment[slot] = 0` (line 1143), add:
```cpp
equipment[slot] = 0;  // sync to NPC::equipment[]
```

**Change 4 (Bug 3): Call LoadEquipment() from Load() and sync in LoadEquipment()**

In `Companion::Load()`, after line 1013 (after all companion_data fields are restored):
```cpp
// Load equipment from companion_inventories table
LoadEquipment();
```

In `Companion::LoadEquipment()`, after the `CalcBonuses()` call (line 1167), add a sync loop:
```cpp
// Sync to NPC::equipment[] for code paths that read the inherited array
for (int slot = EQ::invslot::EQUIPMENT_BEGIN; slot <= EQ::invslot::EQUIPMENT_END; slot++) {
    equipment[slot] = m_equipment[slot];
}
```

#### Lua/Script Changes

**File: `akk-stack/server/quests/lua_modules/llm_bridge.lua`** — Diagnose and fix Bug 1:

The lua-expert must:

1. **Diagnose the failure point** in `generate_response()` (llm_bridge.lua:164-217):
   - Add temporary diagnostic logging at each decision point to identify where nil is returned
   - Test the curl command manually from inside the eqemu container to verify it works
   - Check if `io.popen()` works correctly in the zone process Lua environment (it may be sandboxed)
   - Verify the JSON escaping in line 193 (`gsub("'", "'\\''")`) doesn't corrupt the payload
   - Verify the sidecar response format matches what the Lua code expects (`decoded.response`)

2. **Fix the identified failure**

3. **Add server-log error visibility** for ongoing monitoring:
   - Add `eq.log()` calls at each nil-return path so operators can see failures in server logs
   - Preserve the silent-to-player behavior (no error spam in chat)

#### Database Changes

None required.

#### Configuration Changes

None required. Config-expert confirmed no existing rules address these bugs.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Fix equipment display: override `GetEquipmentMaterial()` and `GetEquippedItemFromTextureSlot()` in Companion, sync `NPC::equipment[]` in GiveItem/RemoveItemFromSlot | c-expert | — | ~50 lines C++ in companion.h and companion.cpp |
| 2 | Fix equipment persistence: call `LoadEquipment()` from `Load()`, sync `NPC::equipment[]` in LoadEquipment | c-expert | 1 | ~10 lines C++ in companion.cpp |
| 3 | Diagnose and fix LLM chat: find the actual failure in llm_bridge.lua generate_response(), fix it, add server-log error visibility | lua-expert | — | Investigation + ~20 lines Lua in llm_bridge.lua |

**Task 1 and Task 2** must be done by the same agent (c-expert) because they modify the same files and Bug 3 depends on Bug 2 (loaded equipment must render correctly). They should be implemented in sequence: first the overrides and sync (Task 1), then the persistence fix (Task 2).

**Task 3** is independent and can be done in parallel by lua-expert. The key work here is diagnosis — the sidecar is healthy but the Lua code is silently failing. The lua-expert must determine WHY and fix the root cause.

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| GetEquipmentMaterial override breaks NPC base appearance for companions | Low | Medium | The override falls back to `NPC::GetEquipmentMaterial()` when `m_equipment[slot]` is 0, preserving the NPC's natural textures |
| CalcSlotFromMaterial returns a slot outside EQUIPMENT range | Very Low | Low | Bounds check (`invslot >= EQUIPMENT_BEGIN && invslot <= EQUIPMENT_END`) before reading m_equipment |
| NPC::equipment[] and m_equipment[] get out of sync | Low | Medium | Both arrays are synced in GiveItem, RemoveItemFromSlot, and LoadEquipment — single source of truth is m_equipment[], NPC::equipment[] is a mirror |
| LLM bug root cause is deeper than Lua (e.g., io.popen sandbox) | Medium | Medium | If io.popen doesn't work in the zone Lua environment, alternative approaches exist: use a Lua HTTP library, write to a file and read response, or use the Lua_Database class to proxy requests |

### Compatibility Risks

These changes are fully backward compatible:
- Companions without equipment continue to render normally (fall through to NPC appearance textures)
- The NPC base class is not modified — all changes are in the Companion subclass
- No packet structure changes — same OP_WearChange packets, just with correct material values
- No database schema changes

### Performance Risks

None. The overrides add a single array lookup and one branch. LoadEquipment is called once per companion spawn (same pattern as LoadBuffs). No new database queries.

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes.

1. **Bug 2 (Equipment Display):** `GetEquipmentMaterial()` and `GetEquippedItemFromTextureSlot()` are virtual on `Mob` (mob.h:545-546). Companion can override them via standard C++ virtual dispatch. The Bot class uses a different approach (it writes directly to `NPC::equipment[]` in bot.cpp:4040), but the virtual override + sync approach is more robust because it ensures the rendering pipeline always reads the correct source.

2. **Bug 3 (Equipment Persistence):** Adding `LoadEquipment()` to `Load()` follows the exact same pattern as `LoadBuffs()` being called from `Unsuspend()`. The repository and table already exist.

3. **Bug 1 (LLM Chat):** The sidecar is confirmed healthy (config-expert verified). The bug is in the Lua code. The lua-expert must diagnose the failure point. If `io.popen()` is the issue, alternatives exist.

**Protocol-agent confirmation:** Titanium client processes OP_WearChange for entities with NPC=0 (companions use NPC=0). All 9 material slots work. Hero's Forge and elite material fields are silently dropped by Titanium ENCODE (harmless). Spawn packet handles zone-in visuals automatically once equipment[] is correct.

**Config-expert confirmation:** No existing rules address any of these bugs. The Companions category has 22 rules (CompanionsEnabled, HPRegenPerTic, MaxActiveCompanions, XPSharePercent, StatScalePct, etc.) — none related to equipment display, persistence, or LLM. All three bugs require code-level fixes.

### Pass 2: Simplicity

**Is this the simplest approach?**

For Bug 2, three approaches were considered:
- **(a) Override GetEquipmentMaterial + sync NPC::equipment[]** — Clean virtual dispatch + belt-and-suspenders sync. Catches both the rendering pipeline and any direct equipment[] access.
- **(b) Write to NPC::equipment[] only, drop m_equipment[]** — Invasive: SaveEquipment/LoadEquipment/ShowEquipment/GiveSlot all reference m_equipment. Would require rewriting 6+ methods.
- **(c) Override only, no sync** — Risky: any code path that reads equipment[] directly bypasses the override.

Decision: **(a)**. Override for correctness through virtual dispatch, sync for safety against direct access.

For Bug 3: one line in Load() + 4 lines sync in LoadEquipment(). Minimal.

For Bug 1: diagnosis required, but the fix will be targeted to the specific failure point.

Nothing can be deferred. Bugs 2 and 3 are interdependent. Bug 1 is independent but equally important.

### Pass 3: Antagonistic

**Edge cases and failure modes:**

1. **Companion with no traded equipment but NPC has loot-table gear:** The NPC constructor may populate `NPC::equipment[]` from loot tables. After `LoadEquipment()` runs, it memsets `m_equipment[]` to zero then populates from DB. If DB has no rows (never traded), m_equipment stays zeroed. The sync writes zeros to equipment[], potentially clearing loot-table items. **Verdict:** This is correct — recruited companions shouldn't display random loot equipment. They should show their npc_types texture appearance (helmtexture, texture, d_melee_texture1, etc.) which the NPC::GetEquipmentMaterial fallback path handles when equipment[slot]==0.

2. **Race condition on GiveItem vs Load:** Cannot happen — Load() runs during SpawnCompanionsOnZone construction before the entity enters the world. GiveItem requires a trade event which can't occur until spawn is complete.

3. **CalcSlotFromMaterial wrist mapping:** Returns slotWrist1 for wrist material (one texture slot for two wrist inventory slots). Only wrist1 equipment renders. Pre-existing EQ limitation.

4. **Player exploit: trade to someone else's companion:** Already guarded by ownership check in global_npc.lua:event_trade (lines 110-124).

5. **Server crash during LoadEquipment:** SELECT query via repository returns empty vector on DB failure. m_equipment stays zeroed. Graceful degradation.

6. **LLM sidecar returns malformed JSON:** Caught by `pcall(json.decode, result)` at llm_bridge.lua:210. Returns nil. Now with logging fix, failure will be visible in server logs.

7. **io.popen not available in zone Lua sandbox:** If the zone process restricts io.popen, the lua-expert should fall back to an alternative HTTP mechanism. The `os.execute` + file-based approach or a custom Lua C function could work.

### Pass 4: Integration

**Implementation sequence walkthrough:**

1. **c-expert starts with Task 1** (Bug 2 fix):
   - Add `GetEquipmentMaterial()` and `GetEquippedItemFromTextureSlot()` declarations to companion.h
   - Implement both overrides in companion.cpp
   - Add `equipment[slot] = m_equipment[slot]` sync in `GiveItem()` after line 1131
   - Add `equipment[slot] = 0` sync in `RemoveItemFromSlot()` after line 1143
   - Build and test: trade a weapon to companion → it should appear visually

2. **c-expert proceeds to Task 2** (Bug 3 fix):
   - Add `LoadEquipment()` call in `Load()` after line 1013
   - Add sync loop in `LoadEquipment()` after the CalcBonuses() call (line 1167)
   - Build and test: trade equipment, zone out and back → equipment persists and displays

3. **lua-expert does Task 3** (Bug 1 fix) in parallel:
   - Diagnose the failure: run the curl command manually from inside the eqemu container, add diagnostic logging to each code path in generate_response(), verify io.popen behavior
   - Fix the root cause
   - Add `eq.log()` calls for ongoing monitoring
   - Test: speak to companion → get LLM response

**Dependencies are correct:**
- Task 2 depends on Task 1 (loaded equipment must render correctly)
- Task 3 is independent
- No circular dependencies

**Each expert has enough context:**
- c-expert needs: companion.h, companion.cpp, npc.h (line 753 for equipment[]), npc.cpp (line 1600-1649 for GetEquipmentMaterial), mob_appearance.cpp (lines 177-217, 331-343, 378-398), mob.h (lines 545-546 for virtual declarations), common/inventory_profile.cpp (lines 1130-1152 for CalcSlotFromMaterial)
- lua-expert needs: llm_bridge.lua, llm_config.lua, global_npc.lua, docker-compose.npc-llm.yml. Config-expert finding: sidecar IS healthy at npc-llm:8100, DNS resolves to 172.18.0.9

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | Tasks 1, 2 | C++ changes to companion.h/cpp — virtual method overrides, Load() modification, array sync |
| lua-expert | Task 3 | Lua diagnosis and fix in llm_bridge.lua — identify why generate_response() returns nil when sidecar is healthy, fix root cause, add error logging |

## Validation Plan

### Bug 2: Equipment Display
- [ ] Trade a weapon (e.g., Short Sword) to companion via trade window
- [ ] Verify companion's visual model shows the weapon in primary hand
- [ ] Trade armor (chest piece) to companion
- [ ] Verify companion's appearance changes to reflect the armor
- [ ] Use `!unequip primary` command and verify weapon disappears visually
- [ ] Have a second player (or alt) verify they also see the visual changes

### Bug 3: Equipment Persistence
- [ ] Trade equipment to companion, verify via `!equipment` command
- [ ] Zone to a different area, verify `!equipment` shows same items
- [ ] Log out and log back in, verify `!equipment` shows same items
- [ ] Verify companion's visual model reflects persisted equipment on zone-in
- [ ] Dismiss companion (non-permanently), re-recruit, verify equipment retained

### Bug 1: LLM Chat
- [ ] Verify sidecar container is running: `docker ps | grep npc-llm`
- [ ] Speak to companion without `!` prefix
- [ ] Verify thinking emote appears (already works)
- [ ] Verify companion responds with LLM-generated dialogue after fix
- [ ] Stop sidecar, speak to companion, verify graceful silence (no crash/error spam)
- [ ] Check server logs for the new error message when sidecar is down

### Cross-Bug Validation
- [ ] Trade equipment, zone, verify both persistence AND display work together
- [ ] Full cycle: recruit NPC → trade equipment → speak to companion (LLM) → zone → verify all three features work

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
