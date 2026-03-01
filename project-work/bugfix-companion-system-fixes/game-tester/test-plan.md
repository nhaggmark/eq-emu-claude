# Companion System Bug Fixes — Test Plan

> **Feature branch:** `bugfix/companion-system-fixes`
> **Author:** game-tester
> **Date:** 2026-03-01
> **Server-side result:** PASS

---

## Test Summary

This test plan covers three companion system bug fixes:

- **Bug 1 (LLM Chat):** Companions showed a thinking emote but never responded.
  The lua-expert added `pcall` guards, diagnostic logging via `eq.log()`, an
  `io.popen` fallback, and confirmed companion eligibility in `llm_bridge.lua`.
- **Bug 2 (Equipment Display):** Traded equipment did not visually appear on
  companions because `GiveItem()` wrote to `Companion::m_equipment[]` while the
  render pipeline read from `NPC::equipment[]`. The c-expert overrode
  `GetEquipmentMaterial()` and `GetEquippedItemFromTextureSlot()` and added
  array sync in `GiveItem()` and `RemoveItemFromSlot()`.
- **Bug 3 (Equipment Persistence):** `LoadEquipment()` was fully implemented but
  never called. The c-expert added the call to `Companion::Load()` with
  subsequent sync to `NPC::equipment[]`.

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] status.md — all 3 implementation tasks marked Complete
- [x] Acceptance criteria identified: 19 criteria across 3 bugs
- [x] Actual source files read and compared to architecture plan

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Build verification: C++ compiles cleanly | PASS | `ninja: no work to do` — binary current with source (zone binary 14:26, companion.cpp.o 14:24, source 14:23 on 2026-03-01) |
| 2 | Architecture match: GetEquipmentMaterial override in companion.cpp | PASS | Override exists at line 554, matches spec exactly |
| 3 | Architecture match: GetEquippedItemFromTextureSlot override in companion.cpp | PASS | Override exists at line 577, matches spec exactly |
| 4 | Architecture match: NPC::equipment[] sync in GiveItem() | PASS | `equipment[slot] = item_id` present at line 1181 |
| 5 | Architecture match: NPC::equipment[] sync in RemoveItemFromSlot() | PASS | `equipment[slot] = 0` present at line 1194 |
| 6 | Architecture match: LoadEquipment() called from Load() | PASS | Call present at line 1060 of companion.cpp |
| 7 | Architecture match: NPC::equipment[] sync in LoadEquipment() | PASS | Sync loop present at lines 1221-1223 |
| 8 | Architecture match: companion.h declares both overrides | PASS | Lines 148-149 declare both virtual overrides |
| 9 | Lua syntax: llm_bridge.lua | PASS | luajit -bl returns no errors |
| 10 | Lua syntax: global_npc.lua | PASS | luajit -bl returns no errors |
| 11 | Architecture match: pcall guards in llm_bridge.generate_response | PASS | pcall wraps json.decode at line 238 |
| 12 | Architecture match: io.popen fallback in generate_response | PASS | Fallback at lines 209-226 with eq.log() on failure |
| 13 | Architecture match: eq.log() error visibility | PASS | Four eq.log(LOG_ERRORS,...) calls at nil-return paths (lines 211, 223, 233, 240, 247) |
| 14 | Architecture match: companion eligibility check added | PASS | `if e.self:IsCompanion() then return true end` at line 65 of llm_bridge.lua |
| 15 | DB integrity: companion_inventories schema | PASS | Table exists; columns id, companion_id, slot_id, item_id, charges, aug_slot_1-5 confirmed |
| 16 | DB integrity: companion_inventories FK check | PASS | 0 orphaned rows (all companion_id values reference existing companion_data.id) |
| 17 | DB integrity: companion_inventories item_id validity | PASS | 0 rows with item_id not found in items table |
| 18 | DB integrity: slot_id range check | PASS | 0 rows with slot_id outside 0-22 |
| 19 | LLM sidecar connectivity: container healthy | PASS | akk-stack-npc-llm-1 healthy, up 4+ hours |
| 20 | LLM sidecar connectivity: DNS resolves from eqemu container | PASS | npc-llm resolves; health endpoint returns OK, model loaded, ChromaDB connected (8 collections) |
| 21 | LLM sidecar: end-to-end chat response test | PASS | POST /v1/chat returns `{"response":"..."}` with non-empty text and `"error":null` |
| 22 | LLM sidecar: response format matches Lua decode path | PASS | `decoded.response` field present in response JSON |
| 23 | Log analysis: zone_start.log after rebuild | PASS | No errors related to companion, equipment, or LLM. Companion "Guard Liben" spawned cleanly. |
| 24 | Log analysis: pre-existing "Zone Bootup failed" errors | INFO | Pre-existing noise from Feb 27-28 (before this branch). Unrelated to companion changes. |
| 25 | Companion data in DB: active companions list | INFO | 1 active companion: "Guard Liben" (id 8) owned by "Chelon" (char id 6), slot 13 = Rusty Shortened Spear (item 7010) |

### Database Integrity

**Queries run:**

```sql
-- Table schema verification
DESCRIBE companion_inventories;

-- Orphaned inventory rows (companion_id with no parent companion_data)
SELECT COUNT(*) FROM companion_inventories ci
LEFT JOIN companion_data cd ON ci.companion_id = cd.id
WHERE cd.id IS NULL;
-- Result: 0

-- Invalid item references
SELECT COUNT(*) FROM companion_inventories ci
LEFT JOIN items i ON ci.item_id = i.id
WHERE i.id IS NULL;
-- Result: 0

-- Out-of-range slot IDs
SELECT slot_id, item_id FROM companion_inventories
WHERE slot_id NOT BETWEEN 0 AND 22;
-- Result: 0 rows

-- Active companion inventory (verifies data written and readable)
SELECT ci.companion_id, ci.slot_id, ci.item_id, cd.name
FROM companion_inventories ci
JOIN companion_data cd ON ci.companion_id = cd.id;
-- Result: companion_id=8, slot_id=13 (primary), item_id=7010 (Rusty Shortened Spear), name=Guard Liben
```

**Findings:** All integrity checks pass. The one existing companion_inventories
row (Guard Liben, slot 13, Rusty Shortened Spear) is properly linked to
companion_data. No orphaned records, invalid item references, or slot out-of-range
values.

### Quest Script Syntax

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| `server/quests/lua_modules/llm_bridge.lua` | Lua | PASS | No syntax errors (luajit -bl) |
| `server/quests/global/global_npc.lua` | Lua | PASS | No syntax errors (luajit -bl) |

**luajit path used inside container:**
`/home/eqemu/code/build/vcpkg_installed/x64-linux/tools/luajit/luajit`

### Log Analysis

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| `zone_start.log` (2026-03-01) | 0 | — | No companion, equipment, or LLM errors after zone startup |
| `zone/*.log` (Zone Bootup failed) | Multiple | INFO | Pre-existing issue from Feb 27-28, unrelated to this branch |
| `world_start.log` | 0 | — | No relevant errors |

**Companion spawn log (zone_start.log — confirms clean spawn after rebuild):**
```
Zone | Info | LoadCompanionSpells Companion [Guard Liben] loaded [0] spells...
Zone | Info | CompanionJoinClientGroup Companion [Guard Liben] joined new group with [Chelon]
Zone | Info | Spawn Companion::Spawn: [Guard Liben] spawned for owner [Chelon] (entity id: 225)
Zone | Info | SpawnCompanionsOnZone: spawned companion 'Guard Liben' (id 8) for player 'Chelon'
```

No `LoadEquipment` errors logged despite the saved inventory row, which is
expected — `LoadEquipment()` uses a SELECT query that gracefully returns an
empty vector on any DB failure.

### Rule Validation

No new rule values were added or modified by this feature. Architecture plan
confirmed 22 existing Companions rules — none cover equipment display,
persistence, or LLM behavior.

### Spawn Verification

Not applicable. No new spawn points or NPC spawn records were created.

### Loot Chain Validation

Not applicable. No new loot tables, loot drops, or item associations were
created. The companion_inventories system is separate from the loot pipeline.

### Build Verification

- **Build command:** `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
- **Result:** PASS
- **Output:** `ninja: no work to do` — all objects and binary are current
- **Timestamp verification:**
  - `companion.cpp` source: 2026-03-01 14:23
  - `companion.cpp.o` object: 2026-03-01 14:24 (newer than source — compiled)
  - `zone` binary: 2026-03-01 14:26 (newer than object — linked)
- **Errors:** None

### Code Review Against Architecture Plan

**companion.h (lines 148-149):**
```cpp
uint32 GetEquipmentMaterial(uint8 material_slot) const override;
uint32 GetEquippedItemFromTextureSlot(uint8 material_slot) const override;
```
Matches specification exactly.

**companion.cpp — GetEquipmentMaterial() (lines 554-575):**
```cpp
uint32 Companion::GetEquipmentMaterial(uint8 material_slot) const
{
    if (material_slot >= EQ::textures::materialCount) { return 0; }
    int16 invslot = EQ::InventoryProfile::CalcSlotFromMaterial(material_slot);
    if (invslot == INVALID_INDEX) { return 0; }
    if (invslot >= EQ::invslot::EQUIPMENT_BEGIN &&
        invslot <= EQ::invslot::EQUIPMENT_END &&
        m_equipment[invslot] != 0) {
        return Mob::GetEquipmentMaterial(material_slot);  // item found — resolve via Mob
    }
    return NPC::GetEquipmentMaterial(material_slot);  // fallback to NPC appearance
}
```
Matches architecture plan verbatim.

**companion.cpp — GetEquippedItemFromTextureSlot() (lines 577-594):**
```cpp
uint32 Companion::GetEquippedItemFromTextureSlot(uint8 material_slot) const
{
    // ... bounds checks ...
    if (inventory_slot >= EQ::invslot::EQUIPMENT_BEGIN &&
        inventory_slot <= EQ::invslot::EQUIPMENT_END) {
        return m_equipment[inventory_slot];  // reads from companion's own array
    }
    return 0;
}
```
Matches architecture plan verbatim.

**companion.cpp — GiveItem() sync (line 1181):**
```cpp
equipment[slot] = item_id;  // sync to NPC::equipment[] for direct-access code paths
```

**companion.cpp — RemoveItemFromSlot() sync (line 1194):**
```cpp
equipment[slot] = 0;  // sync to NPC::equipment[]
```

**companion.cpp — Load() calls LoadEquipment() (line 1060):**
```cpp
// Load equipment from companion_inventories table
LoadEquipment();
```

**companion.cpp — LoadEquipment() sync loop (lines 1221-1223):**
```cpp
for (int slot = EQ::invslot::EQUIPMENT_BEGIN; slot <= EQ::invslot::EQUIPMENT_END; slot++) {
    equipment[slot] = m_equipment[slot];
}
```

All changes match the architecture specification.

**llm_bridge.lua — companion eligibility (line 65):**
```lua
if e.self:IsCompanion() then return true end
```

**llm_bridge.lua — io.popen nil guard + fallback (lines 208-230):**
```lua
local handle = io.popen(cmd)
if not handle then
    eq.log(LOG_ERRORS, "llm_bridge: io.popen returned nil for NPC ...")
    -- os.execute + temp file fallback
    ...
end
```

**llm_bridge.lua — eq.log() at all failure paths (lines 211, 223, 233, 240, 247):**
All nil-return paths log to category 87 (QuestErrors). Silent-to-player behavior
preserved (no player-facing error messages in generate_response).

---

## Part 2: In-Game Testing Guide

### Prerequisites

- Character with GM level access (all tests use GM commands for setup)
- Titanium client connected to the server
- A companion already recruited, OR be in a zone with recruitable NPCs
- Current active companion in DB: "Guard Liben" (companion id 8) owned by
  "Chelon" — this character can be used to test persistence immediately

**GM setup commands used across tests:**
```
#level 50          -- ensure character can handle most content
#zone qeynos2      -- North Qeynos, where Guard Liben was last active
#summonitem 5001   -- Short Sword (primary slot, slots bitmask = 24576)
#summonitem 2004   -- Leather Tunic (chest slot, slots bitmask = 131072)
#reloadquests      -- hot-reload Lua scripts after any quest script changes
```

**Known test companion:**
- Name: Guard Liben
- Owner: Chelon
- Zone: qeynos2 (North Qeynos)
- Already has Rusty Shortened Spear (item 7010) in slot 13 (primary) in DB

---

### Test 1: LLM Chat — Companion Responds to Normal Speech

**Acceptance criteria:**
- Player speaks to companion without `!` prefix
- Companion displays a thinking emote (already works)
- After a brief pause, companion responds with LLM-generated dialogue

**Prerequisite:** Logged in as Chelon (or any character with an active companion)
in qeynos2. The npc-llm sidecar must be running (confirmed healthy in
server-side validation).

**Steps:**
1. Log in as Chelon and zone to qeynos2 (`#zone qeynos2`).
2. Verify Guard Liben has spawned nearby. If not, use `#findnpc Guard Liben`.
3. Target Guard Liben.
4. In the `/say` channel, type: `How are you feeling today?`
5. Watch the chat window for the thinking indicator message (visible only to you).
6. Wait up to 15 seconds (LLM generation time).
7. Watch for Guard Liben to say a response in the chat window.

**Expected result:**
- Step 5: A yellow message appears to you only, e.g.: `Guard Liben considers
  your words carefully...` (or similar thinking emote from llm_config.lua).
- Step 7: Guard Liben speaks a response via Say() that reflects a Qeynos guard's
  personality, class, and context.

**Pass if:** Guard Liben responds with a non-empty, personality-appropriate
dialogue line in the zone-visible chat window after the thinking emote.

**Fail if:** Guard Liben shows the thinking emote but then says nothing (the
original bug behavior), or the client receives a `[DEBUG]` error message.

**GM commands for setup:**
```
#zone qeynos2
#findnpc Guard Liben
```

---

### Test 2: LLM Chat — Companion Memory Across Turns

**Acceptance criterion:** Subsequent conversations show memory of prior interactions.

**Prerequisite:** Test 1 passed. Guard Liben responded to the first message.

**Steps:**
1. With Guard Liben targeted, say: `Do you remember what I asked you before?`
2. Wait for Guard Liben's response.
3. Say: `Tell me more about your history as a guard.`
4. Wait for response.

**Expected result:**
- Guard Liben's response to the second and third messages should demonstrate
  continuity — referencing themes from prior messages in the conversation.
- The ChromaDB memory system stores conversation history; with 8 collections
  (confirmed in server-side validation), the system should be functional.

**Pass if:** Responses are coherent and show some context-awareness of the
prior exchange.

**Fail if:** Guard Liben repeats identical or clearly context-free responses with
no awareness of prior turns.

---

### Test 3: LLM Chat — Command Prefix Does Not Trigger LLM

**Acceptance criterion:** `!`-prefixed messages must route to command dispatch,
not LLM conversation.

**Prerequisite:** Active companion Guard Liben in zone.

**Steps:**
1. Target Guard Liben.
2. Say: `!equipment`
3. Observe the response.

**Expected result:** Guard Liben lists equipped items (the equipment command
response), not an LLM-generated chat response. No thinking emote should appear.

**Pass if:** The `!equipment` command output appears in chat (e.g., "--- Guard
Liben's equipment ---").

**Fail if:** A thinking emote appears, suggesting the message was routed to
the LLM instead of the command handler.

---

### Test 4: LLM Chat — Graceful Silence When Sidecar Is Down

**Acceptance criterion:** If the LLM sidecar is unavailable, the companion
remains silent (no crash, no error spam to the player).

**Prerequisite:** Active companion in zone. Ability to stop and restart the
npc-llm container.

**Steps:**
1. On the host machine, stop the npc-llm container:
   ```bash
   docker stop akk-stack-npc-llm-1
   ```
2. In game, target Guard Liben and say: `Hello there.`
3. Wait 15+ seconds.
4. Observe what happens.
5. Restart the container:
   ```bash
   docker start akk-stack-npc-llm-1
   ```
6. Verify companion responds normally after restart (repeat Test 1).

**Expected result:**
- Step 2-4: The thinking emote may or may not appear (depending on where the
  timeout occurs). The companion says nothing. No `[DEBUG]` error messages
  appear in the player's chat window.
- Server logs (akk-stack/server/logs/zone*.log) WILL show eq.log() entries:
  `llm_bridge: empty response from sidecar for NPC Guard Liben player=Chelon`
  This is expected and desired — errors go to server logs, not player chat.

**Pass if:** Companion stays silent with no player-visible errors. Server log
shows the error message from eq.log().

**Fail if:** Client sees `[DEBUG]` error messages, the server crashes, or the
zone process hangs indefinitely.

**Note on server log check:** After this test, run:
```bash
grep "llm_bridge" /mnt/d/Dev/eq/akk-stack/server/logs/zone*.log | tail -5
```
You should see lines like: `llm_bridge: empty response from sidecar for NPC Guard Liben`

---

### Test 5: Equipment Display — Weapon Appears Visually After Trade

**Acceptance criteria:**
- Player trades a weapon to their companion via the trade window
- The companion's visual model updates immediately to show the weapon
- Other players in the zone also see the visual update

**Prerequisite:** Logged in as Chelon in qeynos2 with Guard Liben active.
Have a Short Sword in inventory (`#summonitem 5001`).

**Steps:**
1. Use `#summonitem 5001` to place a Short Sword in your cursor/inventory.
2. Target Guard Liben.
3. Left-click Guard Liben to open the trade window.
4. Place the Short Sword in the trade window.
5. Click the Trade button.
6. Observe Guard Liben's visual model immediately after the trade completes.
7. Type `!equipment` and verify the weapon is listed.
8. Ask Guard Liben what they think (say any phrase) to confirm the companion
   is still functional after the equip.

**Expected result:**
- Step 5: Guard Liben says "Thank you."
- Step 6: A sword visually appears in Guard Liben's primary hand (right hand).
  The model update should be immediate — no zoning required.
- Step 7: `!equipment` output shows "Primary: Short Sword" (or the item name).

**Pass if:** The sword is visible on Guard Liben's model within 1-2 seconds of
the trade completing.

**Fail if:** Guard Liben says "Thank you" and `!equipment` confirms the item,
but Guard Liben's model looks unchanged (original bug behavior — no sword in hand).

**GM commands for setup:**
```
#summonitem 5001
```

---

### Test 6: Equipment Display — Armor Appears Visually After Trade

**Acceptance criterion:** Player trades armor to companion; companion's appearance
changes to reflect the armor.

**Prerequisite:** Chelon in qeynos2 with Guard Liben active. Have a Leather
Tunic (`#summonitem 2004`).

**Steps:**
1. Use `#summonitem 2004` to get a Leather Tunic.
2. Open the trade window with Guard Liben.
3. Place the Leather Tunic in the trade window and click Trade.
4. Observe Guard Liben's chest/body texture immediately.
5. Type `!equipment` to confirm the tunic is listed in the chest slot.

**Expected result:**
- Guard Liben's body texture changes to reflect the leather tunic appearance.
- `!equipment` shows "Chest: Leather Tunic".

**Pass if:** Visual change is visible on the companion's model.

**Fail if:** No visual change despite the item appearing in `!equipment`.

**GM commands for setup:**
```
#summonitem 2004
```

---

### Test 7: Equipment Display — Multi-Client Visual Verification

**Acceptance criterion:** Other players in the zone also see the visual update.

**Prerequisite:** Two clients in the same zone — or use a second character
window if available. Guard Liben equipped from Test 5.

**Steps:**
1. Log a second character into qeynos2 (or use the second client window).
2. From the second client, locate Guard Liben.
3. Verify the weapon traded in Test 5 is visible on Guard Liben from the
   second client's perspective.

**Expected result:** The second client sees Guard Liben holding the sword
traded in Test 5 without any additional packets needing to be sent.

**Pass if:** Both clients show Guard Liben with the equipped weapon.

**Fail if:** The owner sees the weapon but a second client does not.

---

### Test 8: Equipment Display — Unequip Visually Removes Item

**Acceptance criterion:** Using `!unequip <slot>` visually removes the item
from the companion.

**Prerequisite:** Guard Liben has the Short Sword from Test 5 equipped.

**Steps:**
1. Target Guard Liben.
2. Say: `!unequip primary`
3. Observe Guard Liben's visual model immediately after the command.
4. Type `!equipment` to confirm the slot is now empty.

**Expected result:**
- Guard Liben's hand/primary slot returns to the base model (no sword).
- `!equipment` no longer lists a primary weapon, or shows "(no equipment)" if
  all slots are empty.
- The Short Sword should appear in your inventory (returned to player).

**Pass if:** The sword visually disappears from Guard Liben's model and your
inventory receives the returned item.

**Fail if:** The sword disappears from `!equipment` but remains visually on
Guard Liben's model.

---

### Test 9: Equipment Persistence — Survives Zone Transition

**Acceptance criteria:**
- Player gives companion equipment and verifies via `!equipment`
- Player zones to a different area
- After zoning in, `!equipment` shows the same items as before
- The companion's visual model reflects the persisted equipment on spawn

**Prerequisite:** Guard Liben has the Short Sword equipped (from Test 5 or
re-equipped after Test 8). If starting fresh, use `#summonitem 5001` and trade.

**Steps:**
1. Confirm `!equipment` shows "Primary: Short Sword" (or item name) on Guard Liben.
2. Note the visual state — Guard Liben should be holding the sword.
3. Walk through a zone line (e.g., the South Qeynos gate from qeynos2 leads to
   qeynos) or use `#zone qeynos`.
4. After loading into the new zone, wait for Guard Liben to spawn near you.
5. Immediately after Guard Liben spawns, check the visual model.
6. Say `!equipment` to Guard Liben.

**Expected result:**
- Step 4-5: Guard Liben spawns holding the Short Sword (visual correct on spawn,
  no extra WearChange needed — spawn packet includes equipment materials).
- Step 6: `!equipment` reports "Primary: Short Sword" — same as before zoning.

**Pass if:** Both the visual model and `!equipment` output match the pre-zone state.

**Fail if:** Guard Liben spawns without the sword visually, or `!equipment`
shows empty slots after zoning (original Bug 3 behavior).

---

### Test 10: Equipment Persistence — Survives Logout/Login

**Acceptance criterion:** Equipment persists after logging out and back in.

**Prerequisite:** Guard Liben has equipment from earlier tests.

**Steps:**
1. Confirm `!equipment` shows equipped items on Guard Liben.
2. Log out of the game completely (Exit to character select or fully quit).
3. Log back in with Chelon.
4. Zone to wherever Guard Liben was last active (qeynos2 or wherever you zoned).
5. Wait for Guard Liben to spawn.
6. Check visual model immediately on spawn.
7. Say `!equipment`.

**Expected result:**
- Guard Liben spawns visually equipped.
- `!equipment` shows the same items as before logout.

**Pass if:** Equipment state is fully preserved across login/logout.

**Fail if:** Guard Liben spawns with empty hands and `!equipment` shows nothing.

---

### Test 11: Equipment Persistence — Previously Dismissed Companion Retains Equipment

**Acceptance criterion:** Re-recruited (previously dismissed) companions also
retain their equipment from before dismissal.

**Prerequisite:** Guard Liben has equipment from earlier tests.

**Steps:**
1. Confirm `!equipment` shows equipped items.
2. Say `!dismiss` to dismiss Guard Liben (non-permanently, just temporary
   dismissal — companion record should remain in the DB).
3. Verify Guard Liben departs.
4. Say "join me" to Guard Liben (or find another recruitable NPC to re-recruit
   Guard Liben if the dismiss/re-recruit flow uses the existing DB record).
5. Once re-recruited and spawned, say `!equipment`.

**Note:** If the `!dismiss` / re-recruit flow creates a new companion_data
record rather than reusing the existing one, this test effectively tests that
the new record starts fresh (expected). The acceptance criterion is about the
re-recruit reusing the EXISTING DB record. Verify behavior and note which path
the code takes.

**Pass if:** Re-recruited Guard Liben shows the same equipment from before
dismissal (same companion_data id reused), OR a new companion starts fresh
(clean slate — also acceptable if dismissal clears the record per design).

**Fail if:** Guard Liben has the WRONG equipment (partial load, corrupted state),
or the server crashes during re-recruit.

---

### Test 12: Full Integration — All Three Features Working Together

**Acceptance criterion (cross-bug):** Recruit NPC, trade equipment, speak to
companion (LLM), zone, verify all three features work.

**Steps:**
1. Find a recruitable NPC in your current zone (one without a local event_say
   script and with INT >= 75).
2. Say "join me" (or the recruitment keyword) to recruit the NPC.
3. Verify the companion joins your group.
4. Use `#summonitem 5001` and trade a Short Sword to the companion.
5. Verify visual update (sword in hand).
6. Say: `What do you think of adventuring together?` (LLM test).
7. Wait for LLM response.
8. Zone to a different area.
9. After the companion respawns, check `!equipment`.
10. Say another phrase to the companion (second LLM interaction).

**Expected result:**
- Step 4-5: Equipment displays immediately.
- Step 6-7: Companion responds with personality-driven dialogue.
- Step 9: `!equipment` shows the sword persisted.
- Step 10: Companion responds, potentially showing memory of step 6-7.

**Pass if:** All three features work in sequence without errors, crashes, or
silent failures.

**Fail if:** Any of the three features fails during the integrated test, or the
zone process crashes.

---

## Edge Case Tests

### Test E1: Companion with No Traded Equipment Displays Correctly

**Risk from architecture plan:** "Companion with no traded equipment but NPC has
loot-table gear: After LoadEquipment() runs, it memsets m_equipment[] to zero
then populates from DB. If DB has no rows (never traded), m_equipment stays
zeroed. The sync writes zeros to equipment[], potentially clearing loot-table items."

**Expected behavior per architecture:** This is CORRECT — recruited companions
should show their npc_types texture appearance, not random loot equipment.
`NPC::GetEquipmentMaterial` fallback handles base textures when equipment[slot]==0.

**Steps:**
1. Recruit a fresh NPC companion that you have NOT given any equipment.
2. Observe the companion's visual model on recruit.
3. Zone out and back in.
4. Observe the companion's visual model on zone-in.

**Pass if:** Companion displays its natural NPC model textures (helmtexture,
texture, melee texture from npc_types) consistently, both on recruit and after
zone, with no equipment.

**Fail if:** Companion appears textureless, invisible, or with corrupted
appearance after zoning.

---

### Test E2: Non-Owner Cannot Trade Equipment to Companion

**Risk from architecture plan (PRD):** "Player exploit: trade to someone else's
companion." Already guarded by ownership check in global_npc.lua:event_trade
(lines 110-124).

**Steps:**
1. Log in a second character in the same zone as Guard Liben (owned by Chelon).
2. From the second character, attempt to open the trade window with Guard Liben
   (left-click Guard Liben).
3. Place an item in the trade window and click Trade.

**Expected result:** The second character receives a message: "Only Guard
Liben's owner can give them equipment." The traded item is returned to the
second character. Guard Liben's equipment is unchanged.

**Pass if:** Trade is rejected, item returned, error message displayed.

**Fail if:** Second character successfully equips an item on Guard Liben.

---

### Test E3: Equipment Slot Already Occupied — Prior Item Returned

**Risk:** Trading to a slot that already has an item should return the existing
item before equipping the new one.

**Steps:**
1. Ensure Guard Liben has a Short Sword in the primary slot.
2. Use `#summonitem 5022` to get a Rusty Bastard Sword (also a primary slot weapon).
3. Trade the Rusty Bastard Sword to Guard Liben.

**Expected result:** Guard Liben says "Thank you." The Short Sword that was
previously in primary slot is returned to your inventory. The Rusty Bastard
Sword is now equipped and visually displayed.

**Pass if:** Old item returned to inventory, new item equipped and visually present.

**Fail if:** Old item disappears (item loss), both items equip (impossible), or
trade is rejected.

**GM commands:**
```
#summonitem 5022
```

---

### Test E4: Item With No Valid Equipment Slot Is Rejected

**Risk:** An item with no valid equipment slot (e.g., a container, food item)
should be rejected and returned to the player.

**Steps:**
1. Use `#summonitem 17718` (Backpack, slot=0, not equippable by companion) or
   any container/food item.
2. Attempt to trade it to Guard Liben.

**Expected result:** Guard Liben's message: "[Guard Liben] cannot equip that
item." The item is returned to your inventory.

**Pass if:** Item rejected cleanly with feedback message, item returned.

**Fail if:** Item is accepted and causes a crash or corrupted equipment state.

---

## Rollback Instructions

These fixes do not require database schema changes. Rollback is a git revert
and rebuild.

**If something goes wrong during testing:**

```bash
# Revert C++ changes in eqemu repo
cd /mnt/d/Dev/eq/eqemu
git revert HEAD  # reverts the c-expert commit
# Or to a specific state:
# git checkout f19d215b1 -- zone/companion.cpp zone/companion.h

# Rebuild after reverting
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"

# Revert Lua changes in akk-stack repo
cd /mnt/d/Dev/eq/akk-stack
git revert HEAD  # reverts the lua-expert commit
# Hot-reload (no restart needed for Lua):
# In game: #reloadquests

# Restart server processes (if C++ was reverted and rebuilt)
# Use Spire at http://192.168.1.86:3000 or: cd /mnt/d/Dev/eq/akk-stack && make restart
```

**Database rollback (if corrupted test data in companion_inventories):**
```sql
-- Remove test equipment from a specific companion
DELETE FROM companion_inventories WHERE companion_id = 8;
-- This resets Guard Liben to no equipment in DB
```

---

## Blockers

No blockers identified from server-side validation. All checks pass.

The server-side work is complete. In-game testing is required to confirm visual
behavior, LLM response quality, and persistence across the zone/login boundary.

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|-------------------|--------|
| — | None | — | — | — |

---

## Recommendations

1. **Test E4 item ID:** The backpack item ID used above (17718) should be
   verified before testing. Use `#summonitem [id]` and inspect the item to
   confirm it has `slots=0`. Alternatively, use any food or drink item.

2. **LLM response latency:** The LLM sidecar can take up to 15 seconds for the
   first response after idle. If a companion appears to fail Test 1, wait the
   full 15 seconds before concluding failure. Subsequent responses within the
   same session are typically faster.

3. **Equipment visual on zone-in:** The architecture confirmed that the spawn
   packet (`FillSpawnStruct`) reads from `GetEquipmentMaterial()` per slot,
   which now correctly dispatches to the Companion override. This means the
   initial spawn should show equipped items without needing additional
   WearChange packets. If visual appears on zone-in without any extra commands,
   this is a positive indicator the fix is working as designed.

4. **Guard Liben already has data in DB:** The companion_inventories table
   already has slot 13 (primary) = item 7010 (Rusty Shortened Spear) for Guard
   Liben (companion id 8). When Guard Liben spawns, this item should load
   automatically and display visually — providing an immediate persistence
   verification without needing to re-equip anything.
