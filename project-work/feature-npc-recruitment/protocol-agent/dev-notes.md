# NPC Recruitment / Recruit-Any-NPC Companion System — Dev Notes: Protocol Agent

> **Feature branch:** `feature/npc-recruitment`
> **Agent:** protocol-agent
> **Task(s):** Task #2 — Analyze mercenary packet structures and opcodes for recruitment hijack
> **Date started:** 2026-02-25
> **Current stage:** Research Complete → Socializing

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Analyze mercenary packet structures and opcodes | None | Research Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `common/patches/titanium_ops.h` | 137 | Zero mercenary opcodes. Only `OP_AdventureMerchantSell` (adventure merchant, not merc system). No `OP_Mercenary*` entries of any kind. |
| `common/emu_oplist.h` | 630 | 11 `OP_Mercenary*` opcodes defined internally (see below), but none mapped in Titanium. |
| `common/patches/sod_ops.h` | — | Seeds of Destruction IS where merc opcodes first appear: `OP_MercenaryDataResponse`, `OP_MercenaryDataUpdate`. |
| `common/patches/sof_ops.h` | — | SoF (Secrets of Faydwer) also has only `OP_AdventureMerchantSell` — still no merc packets. |
| `common/patches/titanium.cpp` | 3,923 | Zero ENCODE/DECODE for any `OP_Mercenary*` opcode. No EAT_ENCODE either. The merc opcodes are registered in the dispatch table but the Titanium patch has no translation layer for them. |
| `zone/client_packet.cpp` | 17,356 | 7 merc opcode handlers registered in `ConnectedOpcodes` (lines 302-308). These are present in the dispatch table but would be unreachable from a Titanium client because Titanium has no wire opcodes that map to `OP_Mercenary*`. |
| `zone/merc.h` | — | `Merc` class inherits from `NPC`. Defines roles: TANK=1, HEALER=2, MELEEDPS=9, CASTERDPS=12. MAXMERCS=1. |
| `zone/merc.cpp` | ~5,700 | `ProcessClientZoneChange()`, `AddMercToGroup()`, `SuspendMercCommand()`, `SpawnMercOnZone()`. Group joining uses standard `Group::AddMember(Mob*, ...)` with `is_merc=true` flag. |
| `zone/groups.cpp` | — | `Group::AddMember()` accepts any `Mob*`. NPCs and Mercs both go through the same path. Uses `OP_GroupUpdate` with `GroupJoin_Struct` to notify clients. Group opcodes ARE in `titanium_ops.h`. |

### Key Findings

**CRITICAL: Titanium has ZERO mercenary opcodes.**

The 11 internal `OP_Mercenary*` opcodes in `emu_oplist.h` are:
- `OP_MercenaryAssign`
- `OP_MercenaryCommand`
- `OP_MercenaryDataRequest`
- `OP_MercenaryDataResponse`
- `OP_MercenaryDataUpdate`
- `OP_MercenaryDataUpdateRequest`
- `OP_MercenaryDismiss`
- `OP_MercenaryHire`
- `OP_MercenarySuspendRequest`
- `OP_MercenarySuspendResponse`
- `OP_MercenaryTimer`
- `OP_MercenaryTimerRequest`
- `OP_MercenaryUnknown1`
- `OP_MercenaryUnsuspendResponse`

None of these appear in `titanium_ops.h`. The mercenary system was introduced with Seeds of Destruction (2008 expansion). The Titanium client (October 2006) predates it by 2 years.

**What Titanium DOES support (relevant to companion system):**

| Opcode | Status | Purpose |
|--------|--------|---------|
| `OP_GroupUpdate` | ENCODE in titanium.cpp | Group roster updates, join/leave |
| `OP_GroupInvite` / `OP_GroupInvite2` | Present | Group invitation flow |
| `OP_GroupFollow` / `OP_GroupFollow2` | Present | Accept group invite |
| `OP_GroupDisband` | Present | Leave/disband group |
| `OP_GroupMakeLeader` | Present | Transfer leadership |
| `OP_NewSpawn` | ENCODE in titanium.cpp | Spawn new entity |
| `OP_DeleteSpawn` | ENCODE in titanium.cpp | Remove entity |
| `OP_ChannelMessage` | ENCODE+DECODE | All chat including /say |
| `OP_PetCommands` | DECODE | Pet control commands |

**The `Group::AddMember()` function at groups.cpp:224 accepts any `Mob*`** — players, mercs, NPCs. The Titanium group packet system (`OP_GroupUpdate` with `GroupJoin_Struct`) is fully functional. This is the key: we can add a companion NPC to a group using the exact same mechanism mercs use, and the Titanium client will see it as a normal group member.

**Merc's zone persistence is just a `Zone()` call.** `Merc::ProcessClientZoneChange()` at merc.cpp:5087 simply calls `Zone()`. The zone transition persistence is handled at the entity/group level, not through merc-specific packets.

**`AllowMercs` rule defaults to `false`.** Our companion system does NOT need to enable the merc system. We can use the merc AI/group infrastructure without ever touching the merc-specific opcodes.

### Implementation Plan

The NPC companion system CANNOT use mercenary UI or opcodes on the Titanium client. It MUST use:
1. `/say` commands for recruitment initiation (quest script intercepts)
2. Standard group packets (`OP_GroupUpdate`) for group join/leave — already fully supported
3. Standard spawn packets (`OP_NewSpawn` / `OP_DeleteSpawn`) for companion spawning
4. Standard NPC entity management for AI behavior
5. The chat window for all feedback (no merc window)
6. The group window (6 slots, fully functional in Titanium) as the status display

A new `Companion` class inheriting from `NPC` (or adapting from `Merc : NPC`) is architecturally sound. The group join/leave infrastructure in `groups.cpp` works with any `Mob*`. The merc AI approach (role-based spell casting from `merc_spells_list`) can be replicated for companions without touching merc-specific client packets.

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `titanium_ops.h` — complete opcode mapping | Source file read | Yes | 137 lines, zero `OP_Mercenary*` entries confirmed |
| `emu_oplist.h` — internal opcode definitions | Source file grep | Yes | 14 `OP_Mercenary*` opcodes defined but not mapped to Titanium |
| `sod_ops.h` — SoD patch merc opcodes | Source file grep | Yes | First client version with merc opcodes |
| `sof_ops.h` — SoF patch (no merc) | Source file grep | Yes | SoF is one expansion before SoD, still no merc system |
| `titanium.cpp` — ENCODE/DECODE list | Source file grep | Yes | No mercenary ENCODE or DECODE methods |
| `groups.cpp:224` — `Group::AddMember()` | Source file read | Yes | Accepts any `Mob*`, handles merc as NPC with `is_merc=true` flag |
| `merc.cpp:5087` — `ProcessClientZoneChange` | Source file read | Yes | Just calls `Zone()` — no merc-specific packet |
| `client_packet.cpp:302-308` — merc dispatch | Source file grep | Yes | Merc handlers registered but unreachable from Titanium |
| `ruletypes.h:248` — `AllowMercs` rule | Source file grep | Yes | Defaults to `false` — independent of companion system |

### Plan Amendments

Plan confirmed — no amendments needed. Research deepened the confidence: the group packet path is fully available to the Titanium client and works for any `Mob*` subclass.

### Verified Plan

See Implementation Plan above. Key constraint confirmed: **all companion interaction must be chat-based**. The mercenary hire window, timer window, and management UI cannot be displayed by the Titanium client.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Titanium merc protocol findings | Confirmed: zero merc opcodes. Group path viable. Full constraint list provided. |

### Feedback Received

_(Awaiting architect response)_

### Consensus Plan

_(Will be filled after architect confirms approach)_

---

## Stage 4: Build

_(Not yet started — this is an architecture research task, no code changes expected)_

---

## Open Items

- [ ] Await architect's decision on `Companion` class design (extend Merc vs. extend NPC vs. new class)
- [ ] Confirm with c-expert: which group join codepath to use for companion spawning
- [ ] If bot system is evaluated: check `bot_command.cpp` for Titanium-safe chat command patterns

---

## Context for Next Agent

**Critical finding:** The Titanium client has ZERO mercenary opcodes. The mercenary system (hire window, timer window, management UI) was introduced in Seeds of Destruction (2008) and cannot be displayed on the Titanium client (2006). Any NPC recruitment feature MUST use chat commands and/or NPC dialogue, with the group window as the primary status display.

**What works on Titanium for companions:**
- Standard group packets (`OP_GroupUpdate`) — fully supported, allows any `Mob*` to join a group
- `/say` command interception for recruitment keywords (via quest scripts)
- Standard spawn/despawn packets for companion NPC management
- Pet command packet (`OP_PetCommands`) potentially re-usable for stance control

**What does NOT work:**
- Any `OP_Mercenary*` packet — the Titanium client has no wire mapping for these
- Merc hire window / merc management UI
- Merc timer window

**Key source files:**
- `/mnt/d/Dev/EQ/eqemu/common/patches/titanium_ops.h` — confirms zero merc opcodes (137 lines total)
- `/mnt/d/Dev/EQ/eqemu/zone/merc.cpp:5087` — `ProcessClientZoneChange` (just calls `Zone()`)
- `/mnt/d/Dev/EQ/eqemu/zone/groups.cpp:224` — `Group::AddMember(Mob*)` — the group join path
- `/mnt/d/Dev/EQ/eqemu/zone/merc.cpp:5486` — `Merc::AddMercToGroup()` — pattern to adapt
