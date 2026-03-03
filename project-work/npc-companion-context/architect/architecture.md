# NPC Companion Context — Architecture & Implementation Plan

> **Feature branch:** `feature/npc-companion-context`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-03-02
> **Status:** Draft

---

## Executive Summary

This feature adds a companion-aware context layer to the LLM dialogue system so recruited NPCs talk as group members rather than their original roles. The implementation is almost entirely in Lua — enriching `llm_bridge.build_context()` with companion-specific fields when `npc:IsCompanion()` is true, creating a new `companion_context.lua` module for context construction, and adding a timer-driven unprompted commentary system in `global_npc.lua`. Two small C++ additions expose `time_active` and `recruited_zone_id` data from the Companion class to Lua. No new database tables, packets, opcodes, or UI elements are needed. The sidecar receives richer context and uses it to generate situationally appropriate companion dialogue.

## Existing System Analysis

### Current State

The LLM dialogue system has three layers working in concert:

**1. LLM Bridge (`llm_bridge.lua`)** — The bridge between quest scripts and the LLM sidecar. When a player speaks to an NPC, `global_npc.lua:event_say()` calls `llm_bridge.is_eligible(e)` to check if the NPC qualifies for LLM dialogue, then `llm_bridge.build_context(e)` to construct a context payload, then `llm_bridge.generate_response(context, message)` to call the sidecar via HTTP.

The context payload currently includes: `npc_type_id`, `npc_name`, `npc_race`, `npc_class`, `npc_level`, `npc_int`, `npc_primary_faction`, `npc_gender`, `npc_is_merchant`, `npc_deity`, `zone_short`, `zone_long`, `player_id`, `player_name`, `player_race`, `player_class`, `player_level`, `faction_level`, `faction_tone`, `faction_instruction`.

This same payload is sent whether the NPC is a guard at their post or a companion fighting gnolls in Blackburrow. There is no companion-specific data.

**2. Companion Culture (`companion_culture.lua`)** — Already provides companion-specific prompt additions for specific events (recruitment success/failure, dismiss, level_up, self-preservation, etc.). Has identity evolution tiers (0-10h, 10-50h, 50h+), companion type framing (loyal vs. mercenary), and race-specific personality for Dark Elf, Iksar, Ogre, and Troll mercenaries. Its `get_companion_context()` function accepts `companion_data` as a parameter table but is not yet called from `llm_bridge.build_context()`.

**3. Companion System (`companion.lua`, `companion.h/cpp`)** — The C++ Companion class inherits from NPC and tracks: `m_owner_char_id`, `m_companion_type` (0=loyal, 1=mercenary), `m_current_stance`, `m_time_active` (cumulative seconds), `m_total_kills`, `m_zones_visited` (JSON array), `m_active_since` (epoch timestamp), `m_recruited_level`, `m_recruited_npc_type_id`. The Lua binding (`lua_companion.cpp`) exposes: `GetCompanionID()`, `GetOwnerCharacterID()`, `GetCompanionType()`, `GetStance()`, `GetCompanionXP()`, `GetRecruitedLevel()`, `GetRecruitedNPCTypeID()`.

**4. Global NPC Handler (`global_npc.lua`)** — Routes companion prefix commands (`!passive`, `!follow`, etc.) and recruitment keywords to `companion.lua`, then falls through to the LLM bridge for natural conversation.

### Gap Analysis

| What the PRD Requires | What Exists Today | Gap |
|----------------------|-------------------|-----|
| Companion status flag in LLM context | `npc:IsCompanion()` exists | Need to include `is_companion=true` in context payload |
| Origin summary (former role as backstory) | `companion_culture.get_evolution_context()` exists | Need to call it from `build_context()` and integrate with context payload |
| Current zone awareness | `eq.get_zone_short_name()`, `eq.get_zone_long_name()` exist | Already in payload, but need zone type (indoor/outdoor/city) |
| Zone type classification | `eq.get_zone():GetZoneType()` exists (returns ztype from zone table) | Need to map ztype integer to descriptive string |
| Time of day | `eq.get_zone_time()` returns hour/minute | Need to classify into dawn/day/dusk/night and add to context |
| Combat status | `npc:IsEngaged()`, `npc:GetHateListCount()` on Lua_Mob | Available — need to include in context |
| Group composition | `client:GetGroup()`, `group:GetMember(i)`, `group:GroupCount()` | Available — need to iterate and include |
| Time since recruitment | `m_time_active` exists in C++ but no Lua getter | **Gap: need new Lua binding** |
| Cultural identity markers | Race/class/deity already in payload; `companion_culture.lua` has partial race coverage | Need to extend to all Classic-Luclin races |
| Recent kill history | `m_total_kills` tracks count but not NPC names | Use Lua-side entity variable tracking (simple) |
| Recently taken damage | `GetHPRatio()` available on Lua_Mob | Available — compare to max |
| Unprompted commentary | Nothing exists | **Gap: need timer system + context change detection** |
| Recruited zone (home zone) | `m_zones_visited` has history, but not easily accessible | **Gap: need Lua accessor or DB query for first zone** |
| Luclin fixed-lighting zones | No zone flag exists for this | Handle with a hardcoded Lua lookup table |

## Technical Approach

### Architecture Decision

This feature follows the least-invasive-first principle. The vast majority of work is in Lua scripts (hot-reloadable, no rebuild needed). Two small C++ additions expose data that is already tracked but not accessible from Lua.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `llm_bridge.lua` | Modify | Core change: companion-aware `build_context()` that adds companion fields when `npc:IsCompanion()` |
| `companion_context.lua` (new) | Create | New Lua module: constructs the companion context payload (situational awareness, group composition, activity hints, zone classification) |
| `companion_culture.lua` | Modify | Extend race personality coverage from 4 races to all 14 Classic-Luclin playable races |
| `global_npc.lua` | Modify | Add `event_spawn` timer setup for companion unprompted commentary system |
| `llm_config.lua` | Modify | Add unprompted commentary config values (intervals, probability, feature toggle) |
| `lua_companion.h/cpp` | Modify | Expose `GetTimeActive()` and `GetRecruitedZoneID()` to Lua (2 new methods) |
| `companion.h` | Modify | Add public getters for `m_time_active` and recruit zone derivation |
| No SQL changes | — | All data already exists in `companion_data` table and zone entity state |
| No protocol changes | — | Uses existing `OP_ChannelMessage` / NPC Say mechanism |
| No rule changes | — | Timing values go in `llm_config.lua` (hot-reloadable, creative tuning) |

### Data Model

No new database tables or columns are needed. All companion context data is derived from:

1. **Live entity state** — `npc:IsCompanion()`, `npc:GetRace()`, `npc:GetClass()`, `npc:GetDeity()`, `npc:GetLevel()`, `npc:IsEngaged()`, `npc:GetHPRatio()`
2. **Companion C++ state** — `GetCompanionType()`, `GetStance()`, `GetCompanionXP()`, `GetRecruitedLevel()`, `GetRecruitedNPCTypeID()`, and the new `GetTimeActive()`, `GetRecruitedZoneID()`
3. **Zone state** — `eq.get_zone_short_name()`, `eq.get_zone_long_name()`, `eq.get_zone():GetZoneType()`, `eq.get_zone_time()`
4. **Group state** — `client:GetGroup()`, `group:GroupCount()`, `group:GetMember(i)`
5. **Lua-side tracking** — Entity variables for recent kills (set on death events), last zone change timestamp, last unprompted comment timestamp

### Code Changes

#### C++ Changes

**File: `eqemu/zone/companion.h`** — Add two public getters:

```cpp
// In public section, near existing getters:
uint32 GetTimeActive() const;      // returns m_time_active + elapsed since m_active_since
uint32 GetRecruitedZoneID() const;  // derives from first entry in m_zones_visited JSON
```

`GetTimeActive()` must compute the live value: `m_time_active + (time(nullptr) - m_active_since)` when `m_active_since > 0` (unsuspended), or just `m_time_active` when suspended.

`GetRecruitedZoneID()` parses the first element from the `m_zones_visited` JSON array string. If empty, returns 0.

**File: `eqemu/zone/companion.cpp`** — Implement the two getters.

**File: `eqemu/zone/lua_companion.h`** — Add Lua binding declarations:

```cpp
uint32 GetTimeActive();
uint32 GetRecruitedZoneID();
```

**File: `eqemu/zone/lua_companion.cpp`** — Add Lua binding implementations and register them:

```cpp
uint32 Lua_Companion::GetTimeActive() {
    Lua_Safe_Call_Int();
    return self->GetTimeActive();
}

uint32 Lua_Companion::GetRecruitedZoneID() {
    Lua_Safe_Call_Int();
    return self->GetRecruitedZoneID();
}
```

Add to `lua_register_companion()`:
```cpp
.def("GetTimeActive",       &Lua_Companion::GetTimeActive)
.def("GetRecruitedZoneID",  &Lua_Companion::GetRecruitedZoneID)
```

**Note on luabind inheritance:** `Lua_Companion` inherits from `Lua_Mob`, not `Lua_NPC`. Methods on `Lua_NPC` are not available on companion objects at runtime (documented in MEMORY.md as "Luabind Inheritance Issue"). The new methods are added directly to `Lua_Companion` to avoid this problem.

#### Lua/Script Changes

**File: `akk-stack/server/quests/lua_modules/companion_context.lua` (NEW)** — Core module for building companion context. Functions:

- `companion_context.build(npc, client)` — Main entry point. Returns a table of companion-specific context fields to merge into the LLM payload. Gathers:
  - `is_companion = true`
  - `companion_type` (0=loyal, 1=mercenary)
  - `companion_stance` (0/1/2)
  - `companion_name` (clean name)
  - `time_active_seconds` (from C++ `GetTimeActive()`)
  - `time_active_description` ("a few hours", "several days", "many weeks")
  - `evolution_tier` (0/1/2, from `companion_culture.get_evolution_tier()`)
  - `recruited_zone_short` (from `GetRecruitedZoneID()` -> zone table lookup)
  - `recruited_zone_long`
  - `original_role` (from `companion_culture._extract_role_from_name()`)
  - `zone_type` (outdoor/dungeon/city/indoor from ztype mapping)
  - `time_of_day` (dawn/day/dusk/night from `eq.get_zone_time()`)
  - `is_luclin_fixed_light` (hardcoded lookup for Luclin zones with fixed lighting)
  - `in_combat` (from `npc:IsEngaged()`)
  - `hp_percent` (from `npc:GetHPRatio()`)
  - `recently_damaged` (HP below 80% as heuristic)
  - `group_members` (array of {name, race_name, class_name, level, is_companion} from group iteration)
  - `group_size` (integer)
  - `recent_kills` (from entity variable tracking, list of NPC clean names)
  - `type_framing` (from `companion_culture.get_type_framing()`)
  - `evolution_context` (from `companion_culture.get_evolution_context()`)
  - `race_culture_id` (race ID for sidecar cultural prompt selection)

- `companion_context.classify_time_of_day(hour)` — Maps EQ hour (0-23) to dawn/day/dusk/night string.

- `companion_context.classify_zone_type(ztype)` — Maps zone `ztype` integer to descriptive string (0=indoor/1=outdoor/2=dungeon/etc.).

- `companion_context.get_time_description(seconds)` — Converts cumulative seconds to human-readable duration.

- `companion_context.get_recruited_zone_name(zone_id)` — DB lookup for zone short/long name from zone ID.

- `companion_context.get_group_composition(client)` — Iterates group members and returns structured array.

- `companion_context.is_luclin_fixed_light(zone_short)` — Returns true for Luclin zones with fixed day/night (hardcoded lookup table: `nexus`, `echo`, `umbral`, `griegsend`, `thedeep`, `shadowrest`, etc.).

**File: `akk-stack/server/quests/lua_modules/llm_bridge.lua`** — Modify `build_context()`:

```lua
function llm_bridge.build_context(e)
    -- ... existing context building ...
    local context = { ... existing fields ... }

    -- Companion context enrichment
    if e.self:IsCompanion() then
        local comp_ctx = require("companion_context")
        local companion_fields = comp_ctx.build(e.self, e.other)
        for k, v in pairs(companion_fields) do
            context[k] = v
        end
    end

    return context
end
```

Also modify `generate_response()` to include the new companion fields in the request payload when present.

**File: `akk-stack/server/quests/lua_modules/companion_culture.lua`** — Extend race coverage. Add cultural framing for all Classic-Luclin races not currently covered:

Currently covered (mercenary framing only): Dark Elf (12), Iksar (128), Ogre (9), Troll (8).

Need to add (for both loyal and mercenary companions):
- Human (1)
- Barbarian (2)
- Erudite (3) — with Erudin/Paineel distinction based on class
- Wood Elf (4)
- High Elf (5)
- Dark Elf (12) — loyal framing (mercenary already exists)
- Half Elf (6)
- Dwarf (8) — note: race ID 8 is Dwarf in EQ, not Troll. Need to verify race IDs.
- Halfling (11)
- Gnome (12) — need to verify, may conflict with Dark Elf
- Iksar (128) — loyal framing (mercenary already exists)
- Vah Shir (130) — with oral culture trait per lore-master
- Ogre (10) — verify race ID
- Troll (9) — verify race ID

**IMPORTANT:** Race ID verification is needed during implementation. The existing `companion_culture.lua` uses race IDs from the code comments (12=Dark Elf, 128=Iksar, 9=Ogre, 8=Troll). The c-expert should verify these against `common/races.h` or the `npc_types` table.

**File: `akk-stack/server/quests/global/global_npc.lua`** — Add unprompted commentary system:

In `event_spawn(e)`:
```lua
-- When a companion spawns (or re-enters zone), set up unprompted commentary timer
if e.self:IsCompanion() then
    eq.set_timer("companion_commentary_" .. e.self:GetID(), 600000) -- 10 minutes
    -- Track zone entry for context change detection
    e.self:SetEntityVariable("comp_last_zone", eq.get_zone_short_name())
    e.self:SetEntityVariable("comp_last_comment_time", tostring(os.time()))
    e.self:SetEntityVariable("comp_spawn_time", tostring(os.time()))
end
```

Add new `event_timer(e)` handler (or extend existing):
```lua
-- In event_timer(e):
if e.timer:find("companion_commentary_") and e.self:IsCompanion() then
    companion_commentary.check_and_speak(e.self)
    eq.set_timer(e.timer, 600000) -- restart 10-minute check cycle
end
```

Add new `event_death_zone(e)` handler to track recent kills for companion context:
```lua
-- In event_death_zone(e):
-- Track recent kills for companion context
-- Store last 5 killed NPC names on each companion in the zone
```

**File: `akk-stack/server/quests/lua_modules/companion_commentary.lua` (NEW)** — Unprompted commentary logic:

- `companion_commentary.check_and_speak(npc)` — Main check function called from timer. Evaluates:
  1. Is companion still alive and active? (not suspended, HP > 0)
  2. Is companion NOT in combat? (skip during combat)
  3. Has minimum interval elapsed since last unprompted comment? (15 min hard cap)
  4. Has a significant context change occurred? (new zone, named NPC killed, extended idle)
  5. Random roll (25% chance when conditions met)
  6. Has the 2-minute post-recruitment grace period elapsed?
  If all pass: build companion context, call `llm_bridge.generate_response()` with `unprompted=true` flag, NPC says the response.

- `companion_commentary.detect_context_change(npc)` — Checks entity variables to detect zone changes, significant kills, idle periods.

**File: `akk-stack/server/quests/lua_modules/llm_config.lua`** — Add companion commentary settings:

```lua
-- Unprompted companion commentary
companion_commentary_enabled = true,
companion_commentary_min_interval_s = 600,    -- 10 minutes minimum between checks
companion_commentary_hard_cap_s = 900,        -- 15 minutes hard cap between comments
companion_commentary_probability = 25,         -- 25% chance when conditions met
companion_commentary_grace_period_s = 120,     -- 2 minutes after recruitment: no comments
companion_commentary_combat_block = true,      -- suppress during combat
```

#### Database Changes

None. All data is derived from existing `companion_data` table fields (`time_active`, `zones_visited`, `companion_type`, `name`, `level`, `race_id`, `class_id`) and live entity state.

#### Configuration Changes

Only `llm_config.lua` additions (see above). No `eqemu_config.json` or `ruletypes.h` changes. The commentary timing values are creative tuning parameters that benefit from hot-reload via `#reloadquest`, not server rules.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Add `GetTimeActive()` and `GetRecruitedZoneID()` C++ getters + Lua bindings | c-expert | — | Small: 4 files, ~30 lines |
| 2 | Create `companion_context.lua` module (context builder) | lua-expert | 1 | Medium: new file, ~200 lines |
| 3 | Extend `companion_culture.lua` with all Classic-Luclin race personality framings | lua-expert | — | Medium: ~150 lines of cultural text |
| 4 | Modify `llm_bridge.lua` to integrate companion context | lua-expert | 2 | Small: ~30 lines in `build_context()` and `generate_response()` |
| 5 | Create `companion_commentary.lua` (unprompted commentary module) | lua-expert | 2, 4 | Medium: new file, ~120 lines |
| 6 | Modify `global_npc.lua` for companion timer setup and death tracking | lua-expert | 5 | Small: ~40 lines across event handlers |
| 7 | Add commentary config values to `llm_config.lua` | lua-expert | — | Trivial: ~10 lines |

**Dependency chain:** Task 1 (C++) must complete first and require a server rebuild. Tasks 2-7 (all Lua) can then proceed, with Task 2 as the foundation for Tasks 4-6. Task 3 is independent and can run in parallel with Task 2.

**Build requirement:** Only Task 1 requires a C++ rebuild. Tasks 2-7 are hot-reloadable Lua.

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Luabind inheritance prevents `GetTimeActive()` on companion objects | Low | High | Methods added directly to `Lua_Companion`, not relying on `Lua_NPC` inheritance. Pattern already established in existing `lua_companion.cpp`. |
| `m_zones_visited` JSON parsing in C++ for `GetRecruitedZoneID()` | Low | Low | Simple string parsing of `[id1,id2,...]` format. Fallback to 0 if empty/malformed. |
| LLM sidecar does not utilize new context fields | Medium | Medium | The sidecar must be configured to use `is_companion` and companion fields in its system prompt template. This is sidecar-side work, out of scope for this feature, but the data contract must be documented. |
| Timer accumulation if many companions in zone | Low | Low | Timer per companion entity; companions despawn on dismiss/zone/death, clearing timers. Maximum practical companions per zone is 5 (one group). |
| Entity variable storage for kill tracking | Low | Low | Entity variables are in-memory only, reset on NPC respawn/zone. This is acceptable for "recent kills" context which should be transient. |

### Compatibility Risks

This feature adds data to the LLM payload without removing or modifying existing fields. The sidecar must handle new fields gracefully (ignore if unknown). Existing non-companion NPC dialogue is completely unaffected — the companion context is only added when `npc:IsCompanion()` is true.

Existing `companion_culture.lua` functions are not modified, only extended with new race coverage. Existing race framings (Dark Elf, Iksar, Ogre, Troll) are preserved as-is per lore-master confirmation.

### Performance Risks

- **Context building overhead:** `companion_context.build()` does one DB query (zone name lookup for recruited zone) plus in-memory entity state reads. The DB query can be cached per companion session. Negligible overhead compared to the LLM sidecar call (~5-10 seconds).
- **Unprompted commentary:** Maximum one sidecar call per companion per 15 minutes. With 5 companions, that's at most one extra sidecar call every 3 minutes — well within capacity.
- **Timer overhead:** One 10-minute repeating timer per companion NPC. EQEmu handles thousands of timers routinely.

## Review Passes

### Pass 1: Feasibility

**Can we actually build this?**

Yes. The critical infrastructure is already in place:

1. `npc:IsCompanion()` reliably identifies companions in Lua.
2. `llm_bridge.build_context()` is the single point where LLM context is constructed — easy to extend.
3. `companion_culture.lua` already has the identity evolution and type framing patterns — extending it to new races is straightforward content work.
4. `eq.set_timer()` and `event_timer()` are battle-tested mechanisms for periodic checks.
5. The two C++ getters (`GetTimeActive`, `GetRecruitedZoneID`) access data that already exists in memory — no new computation or storage needed.

**Hardest part:** Ensuring the sidecar actually uses the new context fields effectively. This is outside our control (sidecar-side prompt engineering) but the data contract is clear.

**Verified against source code:**
- `companion.h:353` confirms `m_time_active` member exists
- `companion.h:355` confirms `m_active_since` member exists for live computation
- `companion.h:354` confirms `m_zones_visited` as JSON string
- `lua_companion.cpp:218-243` confirms the luabind registration pattern
- `llm_bridge.lua:122-148` confirms `build_context()` returns a flat table
- `global_npc.lua:8-17` confirms companion say routing pattern
- `zone/lua_zone.cpp:502-505` confirms `GetZoneType()` is exposed to Lua

### Pass 2: Simplicity

**Is this the simplest approach?**

Considered alternatives:
1. **Store companion context in database** — Rejected. All needed data is already available from live entity state and existing `companion_data` columns. Adding more tables would be overengineering.
2. **Use data buckets for all tracking** — Rejected for time_active and zone history (already tracked in C++). Used for transient data like recent kills (appropriate scope).
3. **Put commentary timing in ruletypes.h** — Rejected. These are creative tuning values, not server infrastructure settings. `llm_config.lua` is hot-reloadable and colocated with other LLM settings.
4. **Separate sidecar endpoint for companions** — Rejected. The existing `/v1/chat` endpoint with enriched context is sufficient. The sidecar branches behavior based on `is_companion` flag.
5. **Tracking recent kills in C++ with NPC names** — Rejected. The C++ `RecordKill()` only increments a counter. Tracking NPC names in Lua entity variables is simpler and sufficient for the "last few kills" context need.

**Deferred items:**
- Companion-to-companion interaction (PRD non-goal)
- Milestone conversation triggers (PRD non-goal)
- Preference/opinion tracking (PRD non-goal)

### Pass 3: Antagonistic

**What could go wrong?**

1. **LLM ignores companion context:** If the sidecar's system prompt doesn't incorporate the new fields, companions will still talk like NPCs. **Mitigation:** Document the data contract clearly. The sidecar must check `is_companion` and use companion-specific prompt framing. This is the single most important integration point.

2. **Unprompted commentary fires too often or at bad times:** Player is in the middle of a conversation with another NPC and the companion interrupts. **Mitigation:** Combat block, minimum interval, low probability, hard cap. Also, unprompted comments should be short (the `unprompted=true` flag tells the sidecar to generate brief observational remarks).

3. **Entity variable loss on zone change:** Recent kill tracking stored in entity variables is lost when the companion zones (entity variables are per-NPC-instance, not persisted). **Mitigation:** This is acceptable — "recent kills" should reflect the current zone session, not carry over. The companion's general history is in `companion_data.total_kills`.

4. **Race ID mismatch in cultural framing:** If the race IDs in `companion_culture.lua` don't match the EQ constants. **Mitigation:** Implementation must verify race IDs against `common/races.h`. The existing file uses IDs 8, 9, 12, 128 for Troll, Ogre, Dark Elf, Iksar respectively — these should be verified.

5. **Timer cleanup on companion death/dismiss:** If a companion dies or is dismissed, the commentary timer should stop. **Mitigation:** `eq.stop_timer()` in the dismiss handler. Also, timers are per-entity — when the companion entity is removed from the zone, its timers are automatically cleaned up by the engine.

6. **Concurrent LLM calls from unprompted commentary:** If the sidecar is slow, an unprompted commentary call could overlap with a player-initiated conversation call. **Mitigation:** The blocking `io.popen(curl)` call means only one call happens at a time per zone process. Unprompted commentary checks run on a 10-minute interval, making collision unlikely.

7. **Luclin fixed-light zone list becomes stale:** If new Luclin zones are added to the database, the hardcoded list won't include them. **Mitigation:** The list is in a hot-reloadable Lua module. Also, this server's zone list is stable (Classic-Luclin content only, no new zones being added).

8. **`GetRecruitedZoneID()` returns 0 for companions recruited before `RecordZoneVisit` was implemented:** If old companion_data records have empty `zones_visited`, the function returns 0. **Mitigation:** Fallback to current zone or "unknown origins" framing when recruited_zone_id is 0.

### Pass 4: Integration

**How do the pieces fit together?**

Implementation sequence walkthrough:

1. **c-expert** implements Task 1 (C++ getters). This is a clean, isolated change — add two public methods to `Companion`, implement them in `companion.cpp`, bind them in `lua_companion.cpp`. Server rebuild required. No risk to existing functionality.

2. **lua-expert** starts Tasks 2 and 3 in parallel after Task 1 is complete:
   - Task 2 creates `companion_context.lua` which uses the new `GetTimeActive()` and `GetRecruitedZoneID()` bindings.
   - Task 3 extends `companion_culture.lua` with new race framings — independent of Task 2.

3. **lua-expert** does Task 4 (modify `llm_bridge.lua`) after Task 2 — this is the integration point where companion context enters the LLM payload.

4. **lua-expert** does Tasks 5-7 (commentary system) after Task 4 — the unprompted commentary system uses the same context builder and LLM bridge.

**Each task can be validated independently:**
- Task 1: Build succeeds, Lua can call `npc:GetTimeActive()` on a companion.
- Task 2: `companion_context.build(npc, client)` returns a valid table with expected fields.
- Task 3: `companion_culture.get_type_framing(0, race_id)` returns non-empty for all Classic-Luclin races.
- Task 4: When speaking to a companion, the sidecar receives `is_companion=true` and companion fields.
- Task 5-6: After 10+ minutes, a companion occasionally says something unprompted.
- Task 7: Config values are in `llm_config.lua` and respected by the commentary system.

## Open Questions — Answers

**Q1: What companion state is already exposed to Lua?**
A: Via `Lua_Companion`: `GetCompanionID()`, `GetOwnerCharacterID()`, `GetCompanionType()`, `GetStance()`, `GetCompanionXP()`, `GetRecruitedLevel()`, `GetRecruitedNPCTypeID()`. Via `Lua_Mob` inheritance: `GetRace()`, `GetClass()`, `GetLevel()`, `GetDeity()`, `GetGender()`, `GetHP()`, `GetMaxHP()`, `GetHPRatio()`, `IsEngaged()`, `GetHateListCount()`, `GetCleanName()`, `GetName()`, `GetINT()`, `GetRaceName()`, `GetClassName()`, `GetDeityName()`. NOT exposed: `time_active`, `total_kills`, `zones_visited`, `active_since`. Two new bindings needed: `GetTimeActive()` and `GetRecruitedZoneID()`.

**Q2: How does the sidecar currently structure its system prompt?**
A: The sidecar receives the context payload via `POST /v1/chat` with all fields from `llm_bridge.generate_response()`. The sidecar's internal prompt engineering is out of scope (per PRD non-goals), but the data contract is: when `is_companion=true` is present in the payload, the sidecar should use a companion-appropriate system prompt frame. The sidecar can branch on this field.

**Q3: What recent activity data is readily available?**
A: Combat status (`IsEngaged()`, `GetHateListCount()`), HP ratio (`GetHPRatio()`), and cumulative stats from C++ (`time_active`, `total_kills` via proposed getter). Recent kill names are NOT tracked in C++ (only a counter). Solution: track last 5 killed NPC names in entity variables via `event_death_zone` in `global_npc.lua`.

**Q4: Unprompted commentary implementation approach?**
A: Timer-based. `eq.set_timer()` on companion entity in `event_spawn`, fires every 10 minutes, evaluates context change conditions + probability roll. Uses existing `llm_bridge.generate_response()` with an `unprompted=true` flag. Timer auto-cleans when entity despawns.

**Q5: Luclin fixed-lighting zones?**
A: Handled with a hardcoded Lua lookup table in `companion_context.lua`. When `is_luclin_fixed_light` is true, the context omits time-of-day data or flags it as "fixed lighting" so the sidecar avoids inappropriate day/night commentary. No zone metadata changes needed.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | Task 1: C++ getters + Lua bindings | Two new methods on Companion class, binding in lua_companion.cpp. Requires C++ and luabind knowledge. |
| lua-expert | Tasks 2-7: All Lua module creation and modification | All remaining work is Lua scripts. Single agent to maintain consistency across the interconnected modules. |

## Validation Plan

- [ ] Speak to a companion NPC and verify the sidecar receives `is_companion=true` plus companion-specific fields in the context payload (check server logs at `LOG_DEBUG` level)
- [ ] Verify a companion responds as a group member, not their original role (guard should not say "Move along, citizen")
- [ ] Verify a companion references the current zone appropriately
- [ ] Verify a companion references their origin as backstory ("Back in Qeynos...")
- [ ] Verify two companions of different races produce noticeably different dialogue styles
- [ ] Verify unprompted commentary fires after 10+ minutes, not during combat
- [ ] Verify unprompted commentary does not exceed once per 15 minutes
- [ ] Verify unprompted commentary does not fire in first 2 minutes after recruitment
- [ ] Verify dismissed and re-recruited companion resumes companion-style dialogue
- [ ] Verify Iksar companion does not reference good-aligned old-world cities as friendly
- [ ] Verify Vah Shir companion reflects oral culture traits
- [ ] Verify no post-Luclin lore references appear in context data
- [ ] Verify Luclin fixed-lighting zones suppress time-of-day context
- [ ] Verify `GetTimeActive()` returns correct cumulative seconds from Lua
- [ ] Verify `GetRecruitedZoneID()` returns the first zone from zones_visited
- [ ] Verify no performance degradation (companion context adds < 100ms to build_context)
- [ ] Verify existing non-companion NPC dialogue is completely unaffected

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
