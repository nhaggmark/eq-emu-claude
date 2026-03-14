# Lua Expert — Re-Recruitment Fix Dev Notes

## Stage 1: Plan

### Problem Analysis

After companion dies:
1. C++ `Companion::Death()` calls `SetSuspended(true)`, increments `m_times_died`, calls `Save()` → sets `is_suspended=1`, `cur_hp=0` in DB
2. After `DeathDespawnS` timer fires, `Companion::Process()` calls `SetDismissed(true)`, `SetSuspended(true)`, `Save()` → sets `is_dismissed=1`, `is_suspended=1` in DB
3. The message says "X has returned home. You can recruit them again."

**What blocks re-recruitment:**

A) **Cooldown bucket** (`companion_cooldown_{npc_type_id}_{char_id}`) — set on recruitment *failure*, not on death. So this shouldn't normally block... unless a previous failed attempt set it and it hasn't expired. BUT per the task, we want immediate re-recruit after death — so we should clear this on death.

B) **Level range check** in `companion.is_eligible_npc()` — Step 5: if `Companions:LevelRange > 0` and level diff > range, blocks. This needs to be removed.

C) **is_dismissed=0 and is_suspended=0 in DB** — but that's what C++ sets (is_dismissed=1 after death despawn). The re-recruitment path in C++ `CreateFromNPC()` looks for `is_dismissed=1 OR is_suspended=1` — this is handled correctly by C++.

D) **DB state not cleared before re-recruitment** — The requirement says reset `experience`, `level`, `kills`, `times_died` on death (companion "loses memories"). C++ currently preserves these. We need to reset them in `event_death`.

### What needs to change

**File: `akk-stack/server/quests/global/global_npc.lua`**
- Add `event_death(e)` handler: when `e.self:IsCompanion()`, clear cooldown bucket and reset progression data in DB

**File: `akk-stack/server/quests/lua_modules/companion.lua`**
- Remove level range check (step 5) from `is_eligible_npc()` entirely

### Implementation plan

**`event_death` handler in `global_npc.lua`:**
```lua
function event_death(e)
    if not e.self:IsCompanion() then return end

    local npc_type_id = e.self:GetNPCTypeID()
    local char_id = (e.self.GetOwnerCharacterID and e.self:GetOwnerCharacterID()) or 0
    if char_id == 0 then return end

    -- 1. Clear cooldown bucket so re-recruitment is immediate
    local cooldown_key = "companion_cooldown_" .. npc_type_id .. "_" .. char_id
    eq.delete_data(cooldown_key)

    -- 2. Reset progression data (XP, level, kills, times_died) while preserving equipment
    --    Equipment is in companion_inventories (separate table), not companion_data.
    --    Resetting companion_data progression fields resets "memories" but gear survives.
    --    We reset level to recruited_level (base) so the companion starts fresh.
    local db = Database()
    local stmt = db:prepare(
        "UPDATE companion_data SET experience = 0, level = recruited_level, " ..
        "total_kills = 0, times_died = 0 " ..
        "WHERE owner_id = ? AND npc_type_id = ? AND (is_suspended = 1 OR is_dismissed = 1) LIMIT 1"
    )
    stmt:execute({char_id, npc_type_id})
    db:close()
end
```

Wait — at the time `event_death` fires, the C++ `Companion::Death()` function has JUST run. Looking at the C++ code:
- `SetSuspended(true)` is called → `is_suspended=1` is set in `Save()`
- `is_dismissed` is still 0 at this point (that happens after the timer)

So the DB query condition should be `is_suspended = 1 AND is_dismissed = 0` at death time, OR we can just use `owner_id + npc_type_id` as the key since there can only be one active record per pair.

Actually — the C++ calls `Save()` inside `Death()`, which persists `is_suspended=1`. The `event_death` Lua event fires from `NPC::Death()` via `quest_manager.death()`. Let me check the order: C++ `Companion::Death()` calls `NPC::Death()` first. The Lua `event_death` fires inside `NPC::Death()` before control returns to `Companion::Death()`.

So at event_death time, `is_suspended` may NOT be set yet (C++ sets it AFTER `NPC::Death()` returns). We should use a different condition — just find the active record (not dismissed, not suspended):

```sql
UPDATE companion_data SET experience = 0, level = recruited_level,
    total_kills = 0, times_died = 0
WHERE owner_id = ? AND npc_type_id = ? AND is_dismissed = 0 LIMIT 1
```

**`companion.is_eligible_npc` — remove step 5:**
Simply delete the level range block (lines 209-217).

## Stage 2: Research

### API verification
- `eq.delete_data(key)` — confirmed in LUA-CODE.md: `eq.delete_data("key")`
- `Database():prepare(sql)` / `stmt:execute({...})` / `db:close()` — confirmed pattern
- `e.self:IsCompanion()` — confirmed available
- `e.self:GetNPCTypeID()` — confirmed via Lua_NPC
- `e.self:GetOwnerCharacterID()` — confirmed, nil-guard needed (Companion-only)
- `eq.get_rule("Companions:LevelRange")` — confirmed in existing code

### event_death ordering
From lua_parser.cpp pattern, `event_death` fires when the NPC's `Death()` hook is called. In EQEmu, `NPC::Death()` triggers the quest event before the death processing continues. Since `Companion::Death()` calls `NPC::Death()` first and then sets `is_suspended=1`, the Lua event fires BEFORE `is_suspended` is set. Therefore the correct query uses `is_dismissed = 0` (active record) as the condition.

## Stage 3: Socialized

Plan confirmed — no dependencies on other experts. This is pure Lua.

## Stage 4: Build

### Changes:
1. `global_npc.lua` — add `event_death` companion handler
2. `companion.lua` — remove level range check from `is_eligible_npc`
3. `tests/test_companion_rerecruit.lua` — new test file
