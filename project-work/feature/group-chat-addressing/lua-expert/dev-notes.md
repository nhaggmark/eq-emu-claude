# Group Chat Companion Addressing — Dev Notes: Lua Expert

> **Feature branch:** `feature/group-chat-addressing`
> **Agent:** lua-expert
> **Task(s):** Task #4
> **Date started:** 2026-03-07
> **Current stage:** Build (waiting for Task #3 unblock)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 4 | Modify global_npc.lua for group chat response routing + stagger timer | Task #3 (c-expert: @-parser) | Pending (blocked) |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `claude/project-work/feature/group-chat-addressing/architect/architecture.md` | All | Full specification for Lua changes: entity variable names, stagger logic, event_say and event_timer patterns |
| `akk-stack/server/quests/global/global_npc.lua` | 1-299 | Existing event_say (lines 8-75), event_timer (lines 227-238), event_spawn (lines 178-223), event_death_zone (lines 243-298) |
| `claude/docs/topography/LUA-CODE.md` | All | API surface: eq.set_timer, eq.stop_timer, group:GroupMessage, entity variable methods, event_timer e.timer field |

### Key Findings

1. **event_say response delivery** is at lines 67-73. Currently: if `response` then `e.self:Say(response)`. This is the exact insertion point.

2. **event_timer** is at lines 227-238. Currently handles only `comp_commentary_<id>` timers. Need to add a second branch for `gsay_deliver_<id>` timers.

3. **Entity variable pattern** is already established — the existing commentary system uses `e.self:SetEntityVariable()` / `e.self:GetEntityVariable()` extensively (lines 217-222, 270-286). Same pattern for new variables.

4. **group:GroupMessage** — architecture doc confirms it's already Lua-exposed via `lua_group.cpp:40`, accepts any Lua_Mob as sender. Companion inherits Lua_Mob, so `group:GroupMessage(e.self, response)` is valid.

5. **Timer-based stagger** — the stagger path stores response in entity variable `gsay_pending_response`, schedules timer `gsay_deliver_<id>`, then delivers in event_timer. The timer ID includes the NPC entity ID to avoid collisions.

6. **e.other:GetGroup()** — used to look up the player's group from within event_say. In event_timer we don't have e.other, so we need the companion's owner: `e.self:GetOwnerCharacterID()` then `eq.get_entity_list():GetClientByCharID(owner_id)`, then `owner:GetGroup()`.

7. **Variable clear-before-use pattern** — architecture doc explicitly requires clearing `gsay_response_channel` immediately upon reading (before the sidecar call) so a failed LLM call doesn't leave stale state.

### Implementation Plan

**Files to modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/global/global_npc.lua` | Modify | event_say response block (lines 67-73), event_timer handler (lines 227-238) |

**Change sequence:**
1. In `event_say`, replace the simple `e.self:Say(response)` block with a channel-routing block that checks `gsay_response_channel` entity variable
2. Inside the "group" branch, check `gsay_stagger_ms` to decide between immediate vs. timer-deferred delivery
3. In `event_timer`, add a branch before the existing `comp_commentary_` check to handle `gsay_deliver_` timers

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `e.self:GetEntityVariable(name)` | architecture.md + LUA-CODE.md (lua_mob.cpp:2815) | Yes | Returns string or "" |
| `e.self:SetEntityVariable(name, value)` | architecture.md + LUA-CODE.md (lua_mob.cpp:2845) | Yes | In-memory only, cleared on despawn |
| `e.other:GetGroup()` | architecture.md + existing global_npc.lua:263 | Yes | Returns group or nil; check `.valid` |
| `group:GroupMessage(mob, message)` | architecture.md (lua_group.cpp:40) | Yes | Accepts Lua_Mob (companion) as sender |
| `eq.set_timer(name, ms)` | LUA-CODE.md + existing global_npc.lua:216 | Yes | Timer name is string, ms is integer |
| `eq.stop_timer(name)` | LUA-CODE.md | Yes | Stops named timer |
| `e.self:GetOwnerCharacterID()` | existing global_npc.lua:111 | Yes | Returns int char ID or 0 |
| `eq.get_entity_list():GetClientByCharID(id)` | architecture.md stagger spec | Yes | Returns Lua_Client or nil; check `.valid` |
| `tonumber(str)` | Lua 5.1 standard | Yes | Converts string to number or nil |
| `string:sub(1, N)` | Lua 5.1 standard + existing global_npc.lua:229 | Yes | Used for timer prefix matching |
| `e.self:GetID()` | LUA-CODE.md | Yes | Returns NPC entity ID (integer) |

### Plan Amendments

Plan confirmed — no amendments needed. The architecture doc's recommended Lua code (section "Code Changes > Lua/Script Changes") matches all verified API signatures. The `group.valid` guard and the nil checks for `owner` and `group` are essential defensive patterns consistent with existing code in the file.

One note: the architecture doc shows `eq.stop_timer(e.timer)` inside the timer handler. This is the correct way to stop a one-shot timer — calling stop after it has already fired ensures it doesn't repeat. This is consistent with how commentary timers restart themselves with `eq.set_timer` at the end of their handler.

### Verified Plan

See Implementation Plan above — confirmed by research.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| team-lead (via dispatch) | Waiting on Task #3 | Will begin Stage 4 as soon as c-expert completes Task #3 and confirms entity variable names match architecture doc |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| team-lead | If c-expert changes entity variable names, use their updated names instead of architecture doc | Noted — will check for c-expert messages before writing code |

### Consensus Plan

**Agreed approach:** Implement exactly as specified in architecture.md. Entity variable names from architecture doc:
- `gsay_response_channel` — set by C++ to "group" when response should route to group chat
- `gsay_stagger_ms` — set by C++ with delay in ms for staggered delivery (companions 2..N)
- `gsay_pending_response` — stored by Lua for timer-based delivery

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/global/global_npc.lua` | Modify | event_say lines 67-73, event_timer lines 227-238 |

**Change sequence (final):**
1. Replace `event_say` response block (lines 67-73) with channel-routing block
2. Add `gsay_deliver_` branch to `event_timer` before the existing `comp_commentary_` branch

**Self-contained implementation reference:**

### event_say change (replaces lines 67-73)

```lua
    if response then
        local channel = e.self:GetEntityVariable("gsay_response_channel")
        if channel == "group" then
            -- Clear immediately so a failed LLM call doesn't leave stale state
            e.self:SetEntityVariable("gsay_response_channel", "")
            -- Check if stagger delay was requested (companions 2..N in @all)
            local stagger = e.self:GetEntityVariable("gsay_stagger_ms")
            if stagger ~= "" then
                e.self:SetEntityVariable("gsay_stagger_ms", "")
                local delay_ms = tonumber(stagger) or 0
                if delay_ms > 0 then
                    -- Store response and schedule timer delivery
                    e.self:SetEntityVariable("gsay_pending_response", response)
                    eq.set_timer("gsay_deliver_" .. e.self:GetID(), delay_ms)
                    -- Threatening cooldown still applies if needed
                    if faction_data and faction_data.max_responses then
                        llm_bridge.set_hostile_cooldown(e)
                    end
                    return  -- response delivered by event_timer
                end
            end
            -- Immediate group delivery
            local group = e.other:GetGroup()
            if group and group.valid then
                group:GroupMessage(e.self, response)
            else
                e.self:Say(response)  -- fallback if group lookup fails
            end
        else
            e.self:Say(response)
        end
        -- Threatening cooldown after delivery
        if faction_data and faction_data.max_responses then
            llm_bridge.set_hostile_cooldown(e)
        end
    end
```

Wait — examining existing code more carefully: the cooldown call `llm_bridge.set_hostile_cooldown(e)` is currently INSIDE the `if response then` block at line 70-72. I need to preserve it correctly regardless of delivery path. The architecture doc's pseudocode doesn't show this cooldown, but it's existing behavior.

Refined: preserve the cooldown call after all delivery paths (it's already structured that way in the existing code — the `if faction_data.max_responses then` check is at lines 70-72 and will be inside the `if response then` block in my new version).

### event_timer change (add branch before line 229)

```lua
function event_timer(e)
    -- gsay_deliver_<entity_id>: deferred group chat delivery for staggered multi-companion LLM responses
    if e.timer and e.timer:sub(1, 13) == "gsay_deliver_" then
        eq.stop_timer(e.timer)
        local pending = e.self:GetEntityVariable("gsay_pending_response")
        if pending and pending ~= "" then
            e.self:SetEntityVariable("gsay_pending_response", "")
            local owner_id = e.self:GetOwnerCharacterID()
            local owner = owner_id ~= 0 and eq.get_entity_list():GetClientByCharID(owner_id) or nil
            if owner and owner.valid then
                local group = owner:GetGroup()
                if group and group.valid then
                    group:GroupMessage(e.self, pending)
                else
                    e.self:Say(pending)  -- fallback
                end
            end
        end
        return
    end

    -- Companion commentary timers are named "comp_commentary_<entity_id>"
    if e.timer and e.timer:sub(1, 16) == "comp_commentary_" and e.self:IsCompanion() then
        ...existing code...
    end
end
```

---

## Stage 4: Build

### Implementation Log

_To be filled in when Task #3 is complete and this task is unblocked._

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| (none yet) | | |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/global/global_npc.lua` | Modified | (pending Task #3 completion) |

---

## Open Items

- [ ] Wait for c-expert to complete Task #3 and confirm entity variable names match architecture doc
- [ ] If c-expert messages with changed variable names, update consensus plan before building

---

## Context for Next Agent

If picking this up after context compaction:
- File to modify: `/mnt/d/Dev/eq/akk-stack/server/quests/global/global_npc.lua`
- Two changes: (1) event_say response block at lines 67-73, (2) event_timer handler starting at line 227
- Entity variable names are confirmed by architecture doc unless c-expert sends an update
- Full implementation code is in the "Consensus Plan" section above
- Check for messages from c-expert about Task #3 completion before starting
- After implementing: `cd /mnt/d/Dev/eq/akk-stack && git add -A && git commit -m "feat(companion): route LLM responses through group chat when @-addressed"`
