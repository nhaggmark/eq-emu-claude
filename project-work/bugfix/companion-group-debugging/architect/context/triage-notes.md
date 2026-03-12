# Triage Notes — BUG-021 & BUG-022

## Investigation Path

### Event Dispatch Chain (verified in source)

1. Player sends `/gsay @all !assist`
2. C++ `Client::ChannelMessage` (client.cpp ~1700) parses `@all`, resolves companions
3. Payload extraction strips `@all` → payload is `!assist`
4. For each matched companion: `parse->EventBotMercNPC(EVENT_SAY, companion, this, payload, language)` (line 1856)
5. `EventBotMercNPC` checks `e->IsNPC()` (true — Companion inherits NPC)
6. Calls `EventNPC(event_id, e->CastToNPC(), ...)` — **Companion cast to NPC here**
7. `EventNPC` → `EventNPCGlobal` → `global_npc.lua::event_say(e)`
8. `e.self` is **Lua_NPC** (not Lua_Companion)
9. `e.self:IsCompanion()` returns true (IsCompanion on Lua_Entity — works)
10. `companion_lib.dispatch_prefix_command(e.self, e.other, e.message)` called
11. COMMANDS["assist"] → `companion.cmd_assist(npc, client, args)`
12. `npc:GetStance()` → **nil** (GetStance only on Lua_Companion) → stack trace

### Method Verification

Confirmed via grep of lua_*.h files:

- `GetStance()` — only in `lua_companion.h:39`
- `SetStance()` — only in `lua_companion.h:61`
- `SetGuardMode()` — only in `lua_companion.h:72`
- `GetCompanionType()` — only in `lua_companion.h:37`
- `GetCompanionID()` — only in `lua_companion.h:35`
- `GetCombatRole()` — only in `lua_companion.h:91`
- `GetOwnerCharacterID()` — on `lua_npc.h:185` (works from NPC context)
- `IsCompanion()` — on `lua_entity.h:52` (works from any entity)

### BUG-022 RunTo Override Analysis

Verified in mob_ai.cpp lines 1494-1530:
- Companions have `SetFollowID(owner->GetID())` set at group join (companion.cpp lines 2156, 2176, 2196, 2214)
- `AI_Process` idle branch checks `GetFollowID()` — if set, navigates to follow target
- Follow logic fires every AI tick (many times per second)
- `RunTo()` → `mMovementManager->NavigateTo()` (waypoints.cpp line 620)
- Next AI tick: follow logic overrides the NavigateTo destination
- Result: companion never visibly moves from RunTo — AI immediately redirects

### Precedent for GMMove Fix

`cmd_recall` (companion.lua line 551) already uses `GMMove` for instant repositioning:
```lua
npc:GMMove(client:GetX(), client:GetY(), client:GetZ(), client:GetHeading())
```
This bypasses the movement manager entirely and sets position directly.
