# Companion Rez — Dev Notes: protocol-agent

> **Feature branch:** `bugfix/companion-rez`
> **Agent:** protocol-agent
> **Task(s):** Rez packet protocol triage — verify/refute the auto-accept hypothesis
> **Date started:** 2026-04-27
> **Current stage:** Stage 2 Complete (Research finished; Findings delivered to architect)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| P1 | Map rez packet flow end-to-end, confirm/reject auto-accept hypothesis | — | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/zone/spell_effects.cpp` | ~1707–1729 | `SpellEffect::Revive` handler — the entry point when a rez spell lands on a corpse |
| `eqemu/zone/corpse.cpp` | 2305–2374 | `Corpse::CastRezz()` — builds `OP_RezzRequest`, sends to world; only callable via player-corpse path |
| `eqemu/zone/corpse.h` | 104, 108–109, 264 | `IsCompanionCorpse()`, `SetCompanionData()`, `GetCompanionID()` — companion-corpse detection |
| `eqemu/zone/companion.cpp` | 3547–3700 | `Companion::ResurrectFromCorpse()` — companion-specific direct-rez path (NO packet round-trip) |
| `eqemu/zone/companion.h` | 419, 577 | `ResurrectFromCorpse()` declaration, `m_xp_lost_on_death` field |
| `eqemu/zone/worldserver.cpp` | 909–960, 4286–4303 | `ServerOP_RezzPlayer` handler + `WorldServer::RezzPlayer()` — routes rez through world server |
| `eqemu/zone/worldserver.h` | 49 | `RezzPlayer()` declaration |
| `eqemu/zone/client_packet.cpp` | 357, 13666–13697 | `ConnectedOpcodes[OP_RezzAnswer]` registration; `Handle_OP_RezzAnswer()` |
| `eqemu/zone/client_process.cpp` | 1053–1145 | `OPRezzAnswer()` — actual rez application after player accepts |
| `eqemu/common/eq_packet_structs.h` | 2968–2983 | `Resurrect_Struct` (228 bytes): your_name, corpse_name, rezzer_name, spellid, zone_id, action |
| `eqemu/common/emu_oplist.h` | 464–466 | `OP_RezzAnswer`, `OP_RezzComplete`, `OP_RezzRequest` all defined |
| `eqemu/common/patches/titanium_ops.h` | 1–137 | No `E()` or `D()` entry for any Rezz opcodes — pass-through (no translation needed) |

---

## Stage 2: Research

### Rez Packet Flow — Complete End-to-End

```
1. NPC casts rez spell on a corpse
   ↓
   spell_effects.cpp:1708  SpellEffect::Revive case
   ↓
   spell_effects.cpp:1713  if (IsCorpse())
                             if (IsPlayerCorpse())       → CastRezz() [full OP_RezzRequest flow]
                             else if (IsCompanionCorpse()) → Companion::ResurrectFromCorpse() [direct, no packet]

2. PLAYER CORPSE PATH (standard EQ, uses packets):
   corpse.cpp:2305   Corpse::CastRezz(spell_id, caster)
     ↓
   corpse.cpp:2354   new EQApplicationPacket(OP_RezzRequest, sizeof(Resurrect_Struct))
     fills: your_name = corpse_name (player's char name)
            corpse_name = entity name
            rezzer_name = caster's name
            zone_id, spellid, x/y/z
     ↓
   corpse.cpp:2372   worldserver.RezzPlayer(outapp, rezzed_exp, corpse_db_id, OP_RezzRequest)
     ↓
   worldserver.cpp:4286  WorldServer::RezzPlayer()
     wraps in ServerPacket(ServerOP_RezzPlayer, RezzPlayer_Struct)
     sends via TCP to world server process
     ↓
   worldserver.cpp:909   HandleMessage(ServerOP_RezzPlayer) [in DESTINATION ZONE]
     rezzopcode == OP_RezzRequest:
       entity_list.GetClientByName(srs->rez.your_name)   ← finds the PLAYER CLIENT
       client->SetPendingRezzData(...)
       client->QueuePacket(OP_RezzRequest)                ← SENDS to Titanium client
     ↓
   Titanium Client: shows "Accept Rez?" dialog
     ↓
   Client sends OP_RezzAnswer back to zone server
     ↓
   client_packet.cpp:357   Handle_OP_RezzAnswer()
     → OPRezzAnswer(action, spellid, zone_id, ...)
     if action == Accept:
       worldserver.RezzPlayer(outapp_copy, 0, 0, OP_RezzComplete)
         ↓
       worldserver.cpp:942   rezzopcode == OP_RezzComplete:
         entity_list.GetCorpseByName(...)
         corpse->IsRezzed(true)
         corpse->CompleteResurrection()

3. COMPANION CORPSE PATH (custom, direct, NO PACKETS):
   spell_effects.cpp:1720   CastToCorpse()->IsCompanionCorpse()
     ↓
   spell_effects.cpp:1726   Companion::ResurrectFromCorpse(corpse, spell_id, caster)
     companion.cpp:3547:
       - Gets companion_id and owner_char_id from corpse
       - Loads CompanionData row
       - Loads NPCType
       - Finds owner Client in zone entity list
       - Marks corpse IsRezzed(true)
       - Computes XP restoration from spell base_value[0]
       - Updates DB: is_suspended=0, cur_hp=0, experience += xp_restore
       - Calls corpse->DepopNPCCorpse()
       - Creates new Companion entity at corpse position
       - entity_list.AddNPC(new_comp)
       - new_comp->AI_Start(), Load(), LoadEquipment(), CalcBonuses()
       - ScaleStatsToLevel()
       - Sets HP = (rez_pct% of max HP), mana = 0
       - BuffFadeAll()
       - new_comp->CompanionJoinClientGroup()
       - Announces rez in group chat
```

### Key Protocol-Level Findings

**Finding 1: The user's hypothesis is CORRECT in the general case — but ALREADY FIXED in the code.**

The `CastRezz()` function in `corpse.cpp` populates `your_name` with `corpse_name` (the player's character name) and routes the rez request via world server to find a `Client*` by that name. For an NPC companion corpse, there is no `Client*` — the lookup in `worldserver.cpp:915` (`entity_list.GetClientByName(srs->rez.your_name)`) would find nothing, and the rez request would be silently dropped. The rez dialog would never fire. This is exactly the bug described.

**Finding 2: `spell_effects.cpp` already has the companion-specific bypass.**

The fix already exists at `spell_effects.cpp:1720–1727`. When `IsCompanionCorpse()` is true, `Companion::ResurrectFromCorpse()` is called directly — bypassing `CastRezz()` entirely. No `OP_RezzRequest` is sent. No packet round-trip. No client dialog. The companion is directly re-spawned at the corpse position.

**Finding 3: The companion corpse path requires `SetCompanionData()` to have been called when the corpse was created.**

`IsCompanionCorpse()` returns `m_companion_id > 0`. This is only true if `Corpse::SetCompanionData(companion_id, owner_id)` was called after the corpse was created. The NPC corpse constructor initializes `m_companion_id = 0` (line 127). If `SetCompanionData()` is never called on a companion's death corpse, the corpse is treated as a generic NPC corpse and `CastRezz()` would NOT be invoked (it's guarded by `IsPlayerCorpse()` at line 1714). In that case the rez spell would have no effect whatsoever.

**Finding 4: Titanium client — no translation needed for rez opcodes.**

`OP_RezzRequest`, `OP_RezzAnswer`, `OP_RezzComplete` are all defined in `emu_oplist.h` but have no `E()` or `D()` entries in `titanium_ops.h`. This means they are pass-through — same wire format as internal format. The `Resurrect_Struct` (228 bytes) is sent to the Titanium client unchanged for player rez. No Titanium-specific concern for the companion bypass path (which never sends any of these opcodes).

**Finding 5: `Companion::ResurrectFromCorpse()` has an owner-not-in-zone guard.**

`companion.cpp:3579–3583`: if the owner `Client*` is not found in the current zone entity list, the rez is silently skipped with a log message. This is appropriate but means cross-zone rez is unsupported (owner and corpse must be in same zone). This is the expected behavior for our single-zone small-group play.

### Hypothesis Verdict

**Status: CORRECT but already addressed in code.**

The hypothesis ("NPC corpses have no UI to confirm a rez request") is precisely correct. The existing fix takes the second PRD option: bypass the rez request mechanism entirely for NPC companion targets and apply the rez effect directly. The implementation is in `spell_effects.cpp` (routing branch) + `companion.cpp:3547` (the actual rez logic).

The remaining question for the architect is: **why is the rez still failing in practice?** The protocol path is fixed. The remaining failure must be elsewhere:

1. `SetCompanionData()` not being called when a companion dies (corpse is created as plain NPC corpse, `IsCompanionCorpse()` == false → rez spell skips companion branch, falls through with no effect)
2. The Cleric AI not initiating rez at all (Lua/C++ post-combat trigger not implemented)
3. Both

The protocol layer itself is correct.

---

## Recommended Fix (Protocol-Level Assessment)

No additional changes needed to the rez packet flow. The bypass is correctly placed and implemented.

The architect should verify:
1. **Death path in `companion.cpp`**: does the companion death handler call `Corpse::SetCompanionData()` on the created corpse? (File: `companion.cpp`, grep for `SetCompanionData` near death/corpse creation logic)
2. **Cleric AI trigger**: is there Lua/C++ code that causes a Cleric companion to scan for and cast rez post-combat? If not, that's the missing piece.

---

## Stage 3: Socialize

Findings sent to architect via SendMessage (see agent-conversations.md).

---

## Stage 4: Build

N/A — this is a planning/triage task. No code changes.

---

## Open Items (Task P1 — CLOSED)

- [x] Architect to verify `SetCompanionData()` is called in companion death path
- [x] Lua-expert to confirm/deny existence of Cleric post-combat rez trigger

---

## Context for Next Agent

The rez packet flow has TWO paths at `spell_effects.cpp:1708–1729`:
- Player corpses → `CastRezz()` → `OP_RezzRequest` packet round-trip → Titanium dialog
- Companion corpses → `Companion::ResurrectFromCorpse()` → direct re-spawn, no packets

For companion rez to work, `IsCompanionCorpse()` must return true, which requires `Corpse::SetCompanionData()` to have been called when the companion died. If that call is missing in the death path, the companion corpse is treated as a plain NPC corpse and the rez spell has no effect (falls through neither branch at spell_effects.cpp:1714/1720).

The Titanium client is not involved in companion rez at all — no `OP_RezzRequest` is ever sent to the client for companion targets. No Titanium-side fix is needed.

---

# BUG-002 Triage: Companion Visibility Heartbeat Regression

> **Task:** Protocol/visibility investigation for BUG-002
> **Date:** 2026-04-28
> **Stage:** Stage 2 Complete — Findings ready for architect

---

## Stage 1: Plan

Investigation scope:
1. Map entity-visibility packet flow for NPC companions
2. Find the prior heartbeat fix (`m_ping_timer`)
3. Determine whether V2 commit (`17662d4ba`) broke or bypassed the heartbeat
4. Identify Titanium client cull window
5. Check position update deduplication system from `25826c668`

---

## Stage 2: Research Findings

### Prior Heartbeat Fix

**Commit:** `9e4b7dfd1` — "fix(companions): enable caster spell casting and prevent client-side vanishing"

**What it does:** Added `m_ping_timer` (5-second interval) to `Companion::Process()`. When the companion is stationary (`!IsMoving()`), it calls `SentPositionPacket(0.0f, 0.0f, 0.0f, 0.0f, 0)` every 5 seconds. This sends `OP_ClientUpdate` directly to all clients via `entity_list.QueueClients()`, preventing the Titanium client from culling the entity.

**Source location:** `eqemu/zone/companion.cpp:2128–2142`, `eqemu/zone/companion.h:522`

### Entity Visibility Packet Flow

When the Titanium client renders an entity, it depends on:
1. `OP_NewSpawn` / `NewSpawn_Struct` — initial spawn into client's awareness (sent by `AddCompanion` via `CreateSpawnPacket`)
2. `OP_ClientUpdate` / `PlayerPositionUpdateServer_Struct` — periodic position updates to keep entity alive in client render set
3. Titanium client culls entities that haven't received an `OP_ClientUpdate` in **~10 seconds** (documented in `ec00daa5b` commit message: "clients will disappear after 10 seconds without a position update to the client")

The 10-second cull timeout is a Titanium client behavior, not server-configurable. The heartbeat at 5-second intervals provides 2× margin.

### `OP_ClientUpdate` Wire Format (Titanium)

`SentPositionPacket` uses `OP_ClientUpdate` with `PlayerPositionUpdateServer_Struct` (line 1392 of `eq_packet_structs.h`, ~24 bytes, bitfield-packed). No Titanium translation entry in `titanium_ops.h` — it's a pass-through. The struct is sent as-is.

### V2 Commit Analysis (`17662d4ba`)

V2 added the following to `Companion::Process()`:

```cpp
// Line 1933
if (GetHP() <= 0) {
    return NPC::Process();  // FIX R4: dead entities skip companion AI
}
```

This early return is **before** the ping timer at line 2128. For dead companions this is correct — dead entities should not fire the heartbeat. For LIVE companions in combat (HP > 0), this guard does not fire, and the ping timer path is reached normally.

V2 made NO other changes to `Process()` between line 1933 and the ping timer at 2128. The two bare `return;` statements added by V2 are in `ResurrectFromCorpse()`, not in `Process()`.

**Conclusion: V2 did NOT directly break the heartbeat for living companions.**

### Position Update Deduplication System (`25826c668`)

Commit `25826c668` ("Performance: Client/NPC Position Update Optimizations") added `CheckSendBulkNpcPositions()` called from `Handle_OP_ClientUpdate`. This function iterates `mob_list` and sends position updates to the client, but **skips any mob whose position hasn't changed since the last send** (using `m_last_seen_mob_position` map on the `Client` object).

**Critical path for companions:**
- `CheckSendBulkNpcPositions` iterates `mob_list` → includes companions (IsNPC() returns true for companions)
- If companion is stationary in combat, its position matches `m_last_seen_mob_position` → skipped
- The heartbeat (`SentPositionPacket`) fires via `entity_list.QueueClients()` — bypasses `MobMovementManager::SendCommandToClients` and the dedup entirely
- `m_last_seen_mob_position` is only updated by `MobMovementManager::SendCommandToClients`, NOT by `QueueClients`

**Conclusion: The dedup system does not block the heartbeat. Heartbeat packets still reach the client every 5 seconds.**

### Spawn Path Difference: AddNPC vs AddCompanion (V2 Fix B)

Pre-V2 rez path: `entity_list.AddNPC(new_comp)` — adds to `npc_list` + `mob_list`, calls `SendPositionToClients()` after spawn.
V2 rez path: `new_comp->Spawn(owner)` → `entity_list.AddCompanion()` — adds to `companion_list` + `mob_list`, sends spawn packet via `CreateSpawnPacket()` + `QueueClients()`, does NOT call `SendPositionToClients()`.

`SendPositionToClients()` is an initial position sync for the client. `AddCompanion` instead sends `CreateSpawnPacket` which includes full spawn data. The `m_ping_timer` handles ongoing keepalive for both paths.

**Conclusion: The V2 Spawn() path is protocol-equivalent to AddNPC for entity visibility.**

### Root Cause Assessment

Static analysis does not reveal a clear code-level regression. The heartbeat mechanism is intact in the current codebase:
- `m_ping_timer` is declared in `companion.h:522`
- Timer is initialized to 5000ms in constructor, starts disabled (`companion.cpp:131`)
- In `Process()`, enabled when `!IsMoving()` and fires `SentPositionPacket(0,0,0,0,0)` every 5 seconds (`companion.cpp:2133–2141`)
- For BALANCED/AGGRESSIVE stance companions in combat, the code path reaches the ping timer correctly (no early returns between line 1933 and 2128 for these stances)
- PASSIVE stance takes an early return at line 2036 (before the ping timer), but passive companions are never in combat (their hate list is wiped each tick)

### Remaining Hypothesis for c-expert

The user reports this is "only in combat." Two possible explanations for static analysis not revealing the bug:

**Hypothesis A — Timing window in rez path:** The rezzed companion spawns via `Spawn()` which sets up `m_ping_timer.Disable()` in the constructor. If the companion is immediately engaged (e.g., rez fires mid-combat), the ping timer may not fire in time before the first cull window if the companion doesn't move at all and the initial spawn packet's position tracking is incomplete.

**Hypothesis B — `IsMoving()` false positive during combat AI:** If the movement manager briefly sets `moving = true` during NPC::AI_Process() (pursuit calculation) even when the companion doesn't physically translate position, the ping timer's `Disable()` call may reset the 5-second window more often than expected, leaving a gap larger than 10 seconds between actual heartbeat sends.

**Hypothesis C — The bug is about newly-rezzed companions specifically:** V2's `Fix R4` `GetHP() <= 0` guard fires for the OLD dead entity. The NEW rezzed entity starts fresh with HP > 0 from `Spawn()`. But `Load()` is called BEFORE `Spawn()` and sets HP from `comp_data.cur_hp` — which V2's Fix C deferred to 0 at the time `Load()` executes. The NPC constructor default (max_hp from npc_type) prevails, so HP > 0 before `Spawn()`. Not a regression path.

**Recommendation for c-expert:** Instrument `MobMovementManager::SetMoving` and the `IsMoving()` check around `companion.cpp:2133` to verify `moving = false` is consistently maintained during stationary combat. Also check if `NPC::Process()` internally calls any movement commands that set `moving = true` temporarily (e.g., face-target rotation via `RotateTo`).

### Titanium Client Cull Timeout

The Titanium cull window is **~10 seconds** without an `OP_ClientUpdate`. This is hardcoded in the client and not server-configurable. The 5-second heartbeat interval provides adequate margin. No Titanium-specific change is needed.

---

## Recommended Fix (Protocol Assessment)

The heartbeat mechanism itself is correct. The c-expert should investigate the `moving` flag state during NPC AI processing for companions in combat — specifically whether `NPC::Process()` → `Mob::AI_Process()` temporarily sets `moving = true` during aggro rotation or pursuit calculations, which would reset the ping timer window and potentially create gaps > 10 seconds between heartbeat sends.
