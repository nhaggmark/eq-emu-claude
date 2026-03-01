# Companion System Bug Fixes — Product Requirements Document

> **Feature branch:** `bugfix/companion-system-fixes`
> **Author:** game-designer
> **Date:** 2026-03-01
> **Status:** Approved

---

## Problem Statement

The companion system — the server's signature feature — has three bugs that
undermine the player experience. Companions are meant to feel like living party
members who remember conversations, visually equip gear the player gives them,
and retain that gear across play sessions. All three of these behaviors are
currently broken:

1. **LLM Chat**: Companions show a "thinking" emote when spoken to but never
   respond with dialogue. The soul/memory/LLM integration that gives companions
   personality is non-functional.

2. **Equipment Display**: When a player trades equipment to their companion
   (e.g., a sword), the companion's visual model does not update. The item is
   accepted and tracked internally, but other players and the owner see the
   companion holding/wearing nothing new.

3. **Equipment Persistence**: Equipment given to a companion does not survive
   session boundaries. The player can verify equipment is tracked via the
   `!equipment` command during a session, but after zoning or logging out and
   back in, the equipment is gone.

For a 1-3 player server where companions fill critical party roles, these bugs
significantly degrade the experience. A companion that cannot talk, cannot
visually show its gear, and loses its gear on relog feels like a broken feature
rather than a living party member.

## Goals

1. **Restore companion LLM dialogue** — when a player speaks to their companion
   (without a `!` prefix), the companion responds with LLM-generated,
   personality-driven dialogue using the soul/memory system.

2. **Fix companion equipment visuals** — when a companion receives equipment via
   the trade window, other clients in the zone see the companion's model update
   immediately (e.g., a sword appears in their hand, armor changes their
   appearance).

3. **Fix companion equipment persistence** — equipment given to a companion
   persists across zone transitions and log off/on cycles. When the companion
   respawns on zone-in, it should be wearing/holding everything it had before.

## Non-Goals

- Adding new companion commands or features beyond what already exists.
- Changing the LLM sidecar service itself (prompt engineering, model changes,
  memory system redesign). The sidecar is assumed to work correctly when
  reachable; the bug is in the integration path.
- Changing the equipment trade flow or adding new equipment slots.
- Rebalancing companion stats, combat AI, or recruitment mechanics.
- Addressing any companion bugs beyond these three specific issues.

## User Experience

### Bug 1: LLM Chat — Reproduction Steps

**What the player does:**
1. Recruit an NPC companion (e.g., say "join me" to an eligible NPC).
2. Once the companion joins the party, type a message in `/say` without a `!`
   prefix. For example: "How are you feeling today?"

**What currently happens:**
1. The player sees a thinking emote: "[Companion Name] considers your words
   carefully..." (or similar variant from `llm_config.lua` thinking_emotes).
2. Nothing else happens. No dialogue response appears. The companion is silent.

**What should happen:**
1. The thinking emote appears (this already works correctly).
2. After a brief pause (LLM generation time), the companion speaks a
   personality-driven response via `Say()`. The response should reflect the
   companion's race, class, faction history, and any prior conversation memory
   stored in ChromaDB.

**Notes for investigation:**
- The thinking emote appearing confirms the Lua flow reaches
  `llm_bridge.send_thinking_indicator()` and then calls
  `llm_bridge.generate_response()`. The likely failure point is the curl call
  to the LLM sidecar at `http://npc-llm:8100/v1/chat`.
- The sidecar is an opt-in Docker Compose overlay
  (`docker-compose.npc-llm.yml`). It may not be running, or the DNS name
  `npc-llm` may not resolve from inside the eqemu-server container.
- The code silently swallows errors: if `generate_response()` returns nil, the
  companion simply says nothing (line 74 of `global_npc.lua`: "Sidecar
  unavailable: silent fallthrough").

### Bug 2: Equipment Display — Reproduction Steps

**What the player does:**
1. Recruit a companion.
2. Pick up a weapon (e.g., a Short Sword) from inventory onto the cursor.
3. Left-click the companion to open the trade window.
4. Place the weapon in the trade window and click Trade.
5. Observe the companion's visual model.

**What currently happens:**
1. The trade completes. The companion says "Thank you."
2. The `!equipment` command confirms the item is equipped in the correct slot
   (e.g., "Primary: Short Sword").
3. The companion's visual model does NOT change. No weapon appears in their
   hand. Armor trades similarly have no visual effect.

**What should happen:**
1. After the trade completes, the companion's visual model updates immediately.
   A traded weapon should appear in the companion's hand. Traded armor should
   change the companion's appearance texture for the appropriate body slot.
2. All other players in the zone should also see the visual update.

**Notes for investigation:**
- `Companion::GiveItem()` calls `SendWearChange(slot)` which delegates to
  `Mob::SendWearChange()`. This sends an `OP_WearChange` packet.
- However, `Mob::SendWearChange()` calls `GetEquipmentMaterial(material_slot)`,
  which for NPCs (and Companions, which inherit from NPC) reads from
  `NPC::equipment[]` — the NPC's native loot equipment array.
- `Companion::GiveItem()` writes to `Companion::m_equipment[]`, a separate
  array declared in `companion.h`. These are two different arrays.
- The render pipeline reads the wrong array, so the wear change packet contains
  material=0 (no item) even though the companion has the item in m_equipment.

### Bug 3: Equipment Persistence — Reproduction Steps

**What the player does:**
1. Recruit a companion and trade it equipment (e.g., a weapon and chest armor).
2. Verify via `!equipment` that items are shown as equipped.
3. Zone to a different area (e.g., walk through a zone line), or log out and
   log back in.
4. After zoning in, check `!equipment` again.

**What currently happens:**
1. Equipment is visible via `!equipment` during the session.
2. After zoning or relogging, `!equipment` shows empty slots. The equipment
   is gone.

**What should happen:**
1. Equipment persists across zone transitions and login/logout cycles.
2. After zoning or relogging, `!equipment` shows the same items that were
   equipped before the transition.
3. The companion's visual model also reflects the persisted equipment on spawn.

**Notes for investigation:**
- `Companion::SaveEquipment()` IS called on every `GiveItem()` and writes rows
  to `companion_inventories` table. The data IS saved to the database.
- `Companion::LoadEquipment()` is declared and implemented but is NEVER CALLED
  anywhere in the codebase. It exists as dead code.
- `Companion::Load()` restores HP, mana, XP, stance, and other fields but does
  not call `LoadEquipment()`.
- `Companion::Unsuspend()` loads buffs but does not load equipment.
- `Client::SpawnCompanionsOnZone()` calls `Load()` then `Spawn()` — neither
  calls `LoadEquipment()`.
- The fix likely requires adding `LoadEquipment()` calls to the appropriate
  lifecycle methods (Load, Unsuspend, or SpawnCompanionsOnZone).

## Game Design Details

### Mechanics

#### Companion LLM Chat

The companion chat system is designed to give each companion a unique
personality driven by their race, class, faction standing, and accumulated
conversation history. When a player speaks to their companion without a command
prefix:

1. The companion's eligibility is checked (companions always pass — line 65 of
   `llm_bridge.lua`).
2. A "thinking" emote is shown to the speaking player only.
3. Context is gathered: NPC stats, player stats, faction data, zone info.
4. The LLM sidecar generates a response using this context plus the companion's
   soul elements and conversation memory (ChromaDB).
5. The companion speaks the response via `Say()`.

The expected behavior is that companions carry on natural conversations that
reflect their background and remember past interactions. This is a core part of
what makes companions feel like living party members rather than generic bots.

#### Companion Equipment Display

When equipment is traded to a companion:

1. The trade handler in `global_npc.lua` determines the correct equipment slot
   from the item's `Slots` bitmask.
2. `GiveItem(item_id, slot_id)` is called on the companion C++ object.
3. The item is stored internally and a wear change packet is sent to all
   clients in the zone.
4. The client renders the new equipment on the companion's model.

Visual equipment display is important for player feedback. When a player gives
their companion a fiery sword, they expect to see the companion holding it.
This visual feedback confirms the trade worked and adds to the sense that the
companion is a real party member.

#### Companion Equipment Persistence

The companion system uses three database tables for persistence:
- `companion_data` — core companion record (level, XP, stance, owner, etc.)
- `companion_buffs` — active buff/debuff state
- `companion_inventories` — equipped items (slot_id, item_id per companion)

The lifecycle for persistence:
- **Save path**: `GiveItem()` → `SaveEquipment()` writes to
  `companion_inventories`. `Save()` writes to `companion_data`.
  `SaveBuffs()` writes to `companion_buffs`.
- **Load path**: `Load()` reads from `companion_data`. `LoadBuffs()` reads
  from `companion_buffs`. `LoadEquipment()` reads from
  `companion_inventories` — but is never called.

Equipment persistence matters because companions are long-lived entities.
Players invest time and resources gearing up their companions. Losing that
gear on every zone transition would make equipment meaningless and frustrate
players who are sharing limited loot drops with their companions.

### Balance Considerations

These are bug fixes to existing systems. No balance changes are involved:

- LLM chat is cosmetic/narrative — it does not affect combat or progression.
- Equipment display is visual only — the internal stat bonuses from
  `CalcBonuses()` may already work (untested, but the code calls it). The
  visual fix ensures the player can see what they've already given.
- Equipment persistence ensures items that were already given are retained.
  No new items or slots are being added.

### Era Compliance

All three systems were designed for the Classic-Luclin era lock:

- The LLM sidecar uses soul elements and context that reference Classic-Luclin
  races, classes, zones, and factions only.
- Equipment slots match the Titanium client's slot definitions (no post-Luclin
  slots like Power Source are included; slot 21 is explicitly excluded in the
  Lua trade handler).
- No new content is introduced by these fixes.

## Affected Systems

- [x] C++ server source (`eqemu/`)
  - `zone/companion.cpp` — equipment load/save lifecycle, wear change packet
    generation, equipment array synchronization
  - `zone/companion.h` — potentially no changes needed (LoadEquipment already
    declared)
- [x] Lua quest scripts (`akk-stack/server/quests/`)
  - `global/global_npc.lua` — may need debug logging or error handling
    improvements for the LLM path
  - `lua_modules/llm_bridge.lua` — LLM sidecar call path (may need error
    visibility improvements)
- [ ] Perl quest scripts (maintenance only)
- [x] Database tables (`peq`)
  - `companion_inventories` — read path (LoadEquipment) needs to be exercised
- [ ] Rule values
- [x] Server configuration
  - Docker Compose overlay (`docker-compose.npc-llm.yml`) — sidecar service
    must be running for LLM chat to work
- [x] Infrastructure / Docker
  - LLM sidecar container health and DNS resolution within the Docker network

## Dependencies

- **LLM Chat Bug**: Requires the `npc-llm` Docker sidecar service to be built,
  configured, and running. Requires a model file at the configured path. The
  sidecar must be reachable from inside the `akk-stack-eqemu-server-1`
  container at `http://npc-llm:8100`.
- **Equipment Bugs**: No external dependencies. These are self-contained in the
  companion C++ code and database schema (which already exists).

## Open Questions

1. **Is the LLM sidecar service currently running?** The "thinking" emote
   appears but no response follows, which is consistent with the sidecar being
   unreachable (curl timeout → nil return → silent fallthrough). The architect
   should verify whether the sidecar container is running and healthy before
   investigating code-level issues.

2. **Does `NPC::equipment[]` need to be synchronized with
   `Companion::m_equipment[]`, or should Companion override
   `GetEquipmentMaterial()`?** The architect should determine the cleanest
   approach: (a) write to both arrays in GiveItem, (b) override
   GetEquipmentMaterial in Companion to read from m_equipment, or (c) eliminate
   the duplicate array entirely and use the inherited NPC equipment array.

3. **When equipment is loaded on zone-in, should wear change packets be sent
   for each slot?** The spawn packet already includes equipment material data
   via `FillSpawnStruct` → `NPC::FillSpawnStruct` → equipment material lookup.
   If the equipment array is correctly populated before spawning, the initial
   spawn packet may handle visuals automatically. The architect should verify.

## Acceptance Criteria

### Bug 1: LLM Chat
- [ ] Player speaks to their companion without a `!` prefix
- [ ] Companion displays a thinking emote (already works)
- [ ] After a brief pause, companion responds with LLM-generated dialogue
- [ ] Response reflects the companion's personality (race, class context)
- [ ] Subsequent conversations show memory of prior interactions
- [ ] If the LLM sidecar is unavailable, the companion remains silent (no
      crash, no error spam to the player) — current graceful degradation
      behavior should be preserved

### Bug 2: Equipment Display
- [ ] Player trades a weapon to their companion via the trade window
- [ ] The companion's visual model updates immediately to show the weapon
- [ ] Player trades armor (chest, head, etc.) to their companion
- [ ] The companion's visual appearance changes to reflect the armor
- [ ] Other players in the zone also see the visual update
- [ ] Using `!unequip <slot>` visually removes the item from the companion

### Bug 3: Equipment Persistence
- [ ] Player gives their companion equipment and verifies via `!equipment`
- [ ] Player zones to a different area
- [ ] After zoning in, `!equipment` shows the same items as before
- [ ] Player logs out and logs back in
- [ ] After logging in, `!equipment` shows the same items as before
- [ ] The companion's visual model reflects the persisted equipment on spawn
- [ ] Re-recruited (previously dismissed) companions also retain their
      equipment from before dismissal

---

## Appendix: Technical Notes for Architect

These observations come from reading the codebase during PRD development. They
are advisory — the architect makes all implementation decisions.

### Bug 1: LLM Chat

- The Lua flow is: `global_npc.lua:event_say` → companion falls through to LLM
  block → `llm_bridge.is_eligible(e)` returns true → `build_context(e)` →
  `generate_response(context, message)` → `e.self:Say(response)`.
- `generate_response()` uses `io.popen(curl ...)` to call the sidecar. On
  failure (sidecar down, timeout, bad JSON), it returns nil and the companion
  says nothing.
- The sidecar runs as a separate Docker Compose service via
  `docker-compose.npc-llm.yml` (opt-in overlay, started with `make up-llm`).
- First diagnostic step: verify the sidecar container is running and healthy
  (`docker ps`, `curl http://npc-llm:8100/v1/health` from inside the eqemu
  container).

### Bug 2: Equipment Display

- `Companion::m_equipment[]` (companion.h:304) and `NPC::equipment[]`
  (npc.h:753) are two separate arrays.
- `GiveItem()` writes to `m_equipment[slot]` then calls `SendWearChange(slot)`.
- `SendWearChange` → `Mob::SendWearChange` → `GetEquipmentMaterial(slot)` →
  `NPC::GetEquipmentMaterial` reads from `NPC::equipment[]`, NOT from
  `m_equipment[]`.
- The wear change packet therefore sends material=0 (empty slot) even though
  the item was stored in m_equipment.
- Possible fix approaches: (a) Companion overrides `GetEquipmentMaterial()` to
  read from `m_equipment[]`; (b) `GiveItem()` also writes to
  `NPC::equipment[]`; (c) Companion uses the inherited array and drops
  `m_equipment[]` entirely.

### Bug 3: Equipment Persistence

- `LoadEquipment()` at companion.cpp:1150 is fully implemented — it reads from
  `companion_inventories` and populates `m_equipment[]`.
- It is NEVER called from anywhere. Zero call sites across the entire codebase.
- `SaveEquipment()` IS called from `GiveItem()` and `RemoveItemFromSlot()`, so
  data is correctly saved to the database.
- The fix likely involves calling `LoadEquipment()` from `Load()` (after the
  companion_data record is loaded and `m_companion_id` is set) and/or from
  `SpawnCompanionsOnZone()` after `Load()` completes.
- If Bug 2 is fixed by syncing m_equipment to NPC::equipment[], then
  `LoadEquipment()` must also sync to NPC::equipment[] after loading.

### Cross-Bug Dependencies

- Bug 3 depends on Bug 2: if equipment is loaded from DB but written only to
  m_equipment (not NPC::equipment[]), the persisted equipment will be invisible
  even though it's restored. Both bugs should be fixed together.
- Bug 1 is independent of Bugs 2 and 3.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
