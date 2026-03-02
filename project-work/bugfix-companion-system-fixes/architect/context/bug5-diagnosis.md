# Bug #5 Diagnosis: GetFactionLevel Overload Mismatch

## Error Messages
```
[DEBUG] GetFaction error: No matching overload found, candidates: int GetFactionLevel(Client&,unsigned int,unsigned int,unsigned int,unsigned int,unsigned int,NPC)
[DEBUG] build_context error: No matching overload found, candidates: int GetFactionLevel(Client&,unsigned int,unsigned int,unsigned int,unsigned int,unsigned int,NPC)
```

## Root Cause
Identical class of bug as Bug #1 (GetPrimaryFaction): luabind inheritance mismatch.

### C++ hierarchy: Companion -> NPC -> Mob -> Entity
### Lua binding hierarchy:
- Lua_NPC -> Lua_Mob -> Lua_Entity
- Lua_Companion -> Lua_Mob -> Lua_Entity  (NOT Lua_NPC!)

`Lua_Companion` inherits from `Lua_Mob`, not `Lua_NPC`.
- Registered at lua_companion.cpp:219: `luabind::class_<Lua_Companion, Lua_Mob>("Companion")`
- Header at lua_companion.h:20: `class Lua_Companion : public Lua_Mob`

`GetFactionLevel` is bound with `Lua_NPC` as its last parameter:
- lua_client.h:150: `int GetFactionLevel(uint32, uint32, uint32, uint32, uint32, uint32, Lua_NPC npc)`
- lua_client.cpp:3923: `.def("GetFactionLevel", (int(Lua_Client::*)(uint32,uint32,uint32,uint32,uint32,uint32,Lua_NPC))&Lua_Client::GetFactionLevel)`

When `e.self` is a Companion, it's pushed as `Lua_Companion` (lua_parser.cpp:509-512).
Passing this to `GetFactionLevel` as the last arg fails: luabind can't match Lua_Companion to Lua_NPC.

## Affected Call Sites
1. global_npc.lua:35 -- `e.other:GetFaction(e.self)` -> caught by pcall, defaults faction to 5
2. llm_bridge.lua:123 -- `e.other:GetFaction(e.self)` inside build_context() -> caught by pcall at global_npc.lua:56, aborts entire LLM context build

## Fix
Add `CastToNPC()` guard in `Client:GetFaction()` (client_ext.lua:64-68).
`CastToNPC()` wraps the underlying pointer in `Lua_NPC` which luabind can match.
Same pattern as the Bug #1 workaround for GetPrimaryFaction (already on line 65).

## Key Files
- client_ext.lua:64-68 -- the broken function
- lua_companion.h:20 -- confirms Lua_Companion : Lua_Mob (not Lua_NPC)
- lua_companion.cpp:219 -- confirms luabind registration
- lua_client.cpp:401-403, 3923 -- GetFactionLevel binding
- lua_entity.cpp:115-118, 175 -- CastToNPC implementation
- lua_parser.cpp:509-512 -- where companions are pushed as Lua_Companion
