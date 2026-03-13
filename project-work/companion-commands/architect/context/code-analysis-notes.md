# Architect Code Analysis Notes

## Key Source Locations Verified

### Say Routing (client.cpp)
- Line 1546-1566: `#` command check (COMMAND_CHAR = '#')
- Line 1569-1593: `^` bot command check (BOT_COMMAND_CHAR = '^')
- Line 1609-1611: **Player EVENT_SAY** — fires regardless of target
- Line 1617-1619: Proximity say
- Line 1621-1647: **NPC EVENT_SAY** — requires GetTarget() != null + range check

**Critical finding:** Player EVENT_SAY (line 1609) fires BEFORE NPC EVENT_SAY
(line 1633). This enables !help interception without a companion target.

### companion.lua Key Lines
- Line 43: `local companion_modes = {}` — tracks "follow" or "guard" per entity
- Line 91-115: COMMANDS table — 23 entries, 7 categories
- Line 141-170: `dispatch_prefix_command()` — entry point from global_npc.lua
- Line 479-486: `companion_say()` — routes via group chat or npc:Say()
- Line 489-493: `cmd_passive` — SetStance(0), WipeHateList
- Line 514-521: `cmd_follow` — SetGuardMode(false), mode = "follow"
- Line 525-528: `cmd_guard` — SetGuardMode(true), mode = "guard"
- Line 843-860: `cmd_tome` — dead check, distance check, GMMove
- Line 864-887: `cmd_flee` — SetStance(0), SetGuardMode(false), GMMove
- Line 909-954: `cmd_assist` — auto-switch passive→balanced, SetTarget, AddToHateList
- Line 735-812: `cmd_help` — help_lock_key dedup, category-based output

### global_npc.lua (line 8-17)
```lua
function event_say(e)
    if e.self:IsCompanion() then
        if e.message:sub(1, 1) == "!" then
            companion_lib.dispatch_prefix_command(e.self, e.other, e.message)
            return
        end
    end
    -- ... LLM fallback
end
```

### global_player.lua — NO event_say exists
File has: event_enter_zone, event_combine_validate, event_combine_success,
event_command, event_connect, event_level_up, event_test_buff, event_task_complete.
No event_say. Safe to add one.

## Design Decisions

### Why WipeHateList instead of SetTarget(nil) for !tome
- `Lua_Mob::SetTarget(Lua_Mob t)` takes a Lua_Mob parameter, not a raw pointer
- When Lua passes `nil`, luabind may fail conversion (nil → Lua_Mob) with error
- WipeHateList() is well-tested, used in cmd_passive, proven safe
- Achieves same result: companion stops attacking
- Mobs' own hate lists are UNAFFECTED (they continue pursuit)

### Why companion_modes "guard" + stance check for !hold (not new mode)
- Adding "hold" as a third mode would require updating cmd_status display logic
- The combination guard+passive fully describes the hold state
- "Already holding" detection: `companion_modes[id] == "guard" AND stance == 0`
- Breaking hold is natural: !follow breaks guard, !assist breaks passive
