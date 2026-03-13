# Command Audit Notes

## Source Files Reviewed

- `akk-stack/server/quests/lua_modules/companion.lua` (1210 lines) — All command handlers
- `akk-stack/server/quests/global/global_npc.lua` (640 lines) — Event dispatch, trade handler
- `eqemu/zone/client.cpp` (lines 1680-1859) — HandleGroupChatMentions (@all/gsay dispatch)
- `claude/docs/companion-commands-reference.md` — Existing documentation (outdated)

## Command Dispatch Flow

1. Player types `/say !command` targeting a companion
2. global_npc.lua:event_say() fires with e.self = targeted NPC
3. If e.self:IsCompanion() and message starts with "!", calls companion.dispatch_prefix_command()
4. dispatch_prefix_command() strips prefix, looks up COMMANDS table, checks ownership, calls handler

For @all/gsay:
1. Player types `@all !command` in group chat
2. C++ Client::HandleGroupChatMentions() parses @tokens, resolves companions in group
3. Dispatches payload as EVENT_SAY to each companion (no stagger for ! commands)
4. Each companion receives the event and routes through the same Lua path

## Key Discrepancies Between Docs and Code

| Doc Says | Code Actually Does | Status |
|----------|-------------------|--------|
| Free-text dismiss keywords (leave, goodbye, etc.) | Only !dismiss exists | Doc outdated |
| `stance` alias for balanced | No such COMMANDS entry | Doc outdated |
| `stay` alias for guard | No such COMMANDS entry | Doc outdated |
| Free-text equipment commands | Only ! prefix versions exist | Doc outdated |
| Handler: handle_command() | Actual: dispatch_prefix_command() | Doc outdated |

## Nil-Guard Pattern

Due to luabind inheritance issues (Lua_Companion inherits Lua_NPC but methods
don't resolve at runtime), all Companion-specific methods must be nil-guarded:

```lua
if npc.SetStance then npc:SetStance(0) end  -- nil-guard
```

Methods requiring nil-guards: SetStance, GetStance, SetGuardMode,
GetCompanionType, GetCompanionID, GetCombatRole.

## Module-Level State

companion_modes = {} — Maps entity IDs to "follow" or "guard"
- Reset on quest reload
- Default assumption is "follow"
- Used by cmd_follow, cmd_guard, cmd_flee, cmd_recall, cmd_status

## @all !help Deduplication

help_lock_key = "help_lock_" .. zone_id — 1-second TTL data bucket
- First companion to receive !help claims the lock
- Subsequent companions in the same zone skip responding
- Prevents multiple help responses when @all is used
