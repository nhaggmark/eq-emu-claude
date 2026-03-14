# Companion Recruitment & Re-recruitment Overhaul — Product Requirements Document

> **Feature branch:** `feature/companion-recruitment-overhaul`
> **Author:** game-designer
> **Date:** 2026-03-14
> **Status:** Approved

---

## Problem Statement

On our 1-3 player Custom EverQuest server, companions are essential party
members — not disposable summons. When a companion dies or is dismissed,
re-recruiting them is blocked by multiple overlapping mechanisms that were
designed for first-time recruitment:

1. **Cooldown timers** (`companion_cooldown_{npc_type_id}_{char_id}` in
   `data_buckets`) — a 15-minute timer that blocks re-recruitment even
   though the companion already has an established relationship with the
   player.
2. **Level range restriction** (`Companions:LevelRange` rule, default ±3) —
   prevents recruiting an NPC more than 3 levels away. After death, the
   companion may have leveled well beyond their base NPC level, making
   re-recruitment of their NPC body impossible.
3. **Dismissed/suspended flag confusion** — Death sets `is_suspended=1,
   is_dismissed=0`. The Lua recruitment handler's `check_dismissed_record()`
   only looks for `is_dismissed=1`, so dead companions don't match. The C++
   `CreateFromNPC()` was fixed to check both `is_dismissed=1 OR is_suspended=1`,
   but the Lua layer still applies cooldowns and persuasion rolls before
   C++ is ever reached.
4. **Persuasion roll on re-recruitment** — A companion who adventured with
   you, leveled up, and died in battle must still pass a persuasion roll
   to rejoin. This is narratively absurd and mechanically punishing.
5. **Group wipe cascade** — When all companions die simultaneously, every
   single one triggers its own cooldown and flag set, forcing the player
   to manually clean up each companion's state in the database.

These issues have been documented in BUG-012 (equipment loss on death) and
BUG-013 (re-recruitment blocked without DB cleanup). The user has repeatedly
needed manual database intervention (`DELETE FROM data_buckets WHERE key LIKE
'companion_cooldown_%'`) after every group wipe — an unacceptable gameplay
experience for the server's signature feature.

## Goals

1. **Seamless re-recruitment**: Previously recruited companions (dead or
   dismissed) can be re-recruited instantly — no cooldown, no level check,
   no persuasion roll.
2. **Level preservation**: Re-recruited companions return at their last
   progressed companion level with full XP, not their base NPC level.
3. **Equipment preservation**: Re-recruited companions retain all equipment
   given to them by the player (already partially implemented in C++, needs
   Lua-side fixes to avoid blocking the path).
4. **Group wipe recovery**: After a group wipe, all companions can be
   re-recruited without any flags, cooldowns, or caps interfering.
5. **Clean state management**: No orphaned cooldowns, stale dismissed flags,
   or conflicting suspended states after any recruitment lifecycle event.

## Non-Goals

- Changing first-time recruitment mechanics (level range, faction check,
  persuasion roll, cooldown on failure) — these stay as-is.
- Adding new companion abilities, spells, or AI behaviors.
- Modifying the companion death/corpse/resurrection system.
- Changing the `!dismiss` voluntary dismissal flow (it already correctly
  sets `is_dismissed=1`).
- Reworking the soul wipe / permanent death system.
- Modifying companion XP gain rates or level-up mechanics.
- Adding a new UI or client-side changes.

## User Experience

### Player Flow: First-Time Recruitment (unchanged)

1. Player encounters an NPC in the world and says a recruitment keyword
   (e.g., "join me", "recruit", "follow me").
2. System checks eligibility:
   - Companions enabled
   - Group not full (< 6 members)
   - NPC not already recruited
   - Neither party in combat
   - **Level range: player within ±3 levels of NPC** (first-time only)
   - Faction standing >= Kindly
   - NPC type not excluded (pets, bots, mercs, bankers, guildmasters)
3. System calculates persuasion roll (base 50% + faction bonus +
   disposition modifier + persuasion stat bonus - level penalty).
4. **On success**: NPC joins party, C++ creates companion record, NPC
   depops and companion spawns.
5. **On failure**: NPC refuses, cooldown timer starts (15 min default).

### Player Flow: Re-Recruitment After Death

1. Companion dies in combat. Player receives death notification with
   despawn timer countdown.
2. If not resurrected before despawn timer, companion is auto-suspended
   (saved to DB with `is_suspended=1`, `cur_hp=0`).
3. Player finds the same NPC type in the world (respawned at the original
   spawn point, or another instance of the same npc_type_id).
4. Player says a recruitment keyword to the NPC.
5. **System detects existing companion record** for this player + npc_type_id
   with `is_suspended=1` or `is_dismissed=1`.
6. **Bypasses ALL first-time checks**: no cooldown check, no level range
   check, no faction check, no persuasion roll.
7. C++ `CreateFromNPC()` loads the existing record, restores level, XP,
   equipment, and stance.
8. NPC says "I remember you. Let us continue." and joins the party.
9. Companion is immediately at their saved companion level (not the base
   NPC level), with all equipment intact.

### Player Flow: Re-Recruitment After Voluntary Dismissal

1. Player uses `!dismiss` on a companion.
2. Companion says "Farewell for now." and depops. Record saved with
   `is_dismissed=1`.
3. Later, player finds the same NPC type and says a recruitment keyword.
4. **Same bypass as death**: no cooldown, no level check, no roll.
5. Companion rejoins at saved level with equipment.

### Player Flow: Group Wipe Recovery

1. Multiple companions die during a difficult encounter.
2. Player recovers (resurrected, returns to zone, etc.).
3. Player finds each companion's NPC type in the world.
4. For each NPC: says recruitment keyword, companion instantly rejoins
   at their saved level. **No cooldown stacking, no cascading failures.**
5. Full group is restored within minutes of finding the NPCs.

### Example Scenario

A level 40 ranger with three companions (a level 38 cleric, a level 37
warrior, and a level 36 rogue — all having leveled from their recruited
base levels through companion XP) enters a dungeon. A bad pull causes
a group wipe.

**Current behavior (broken)**: Player respawns. All three companions are
flagged as suspended. When the player returns to town and tries to
re-recruit the cleric NPC (base level 20), recruitment fails because the
cleric is 20 levels below the player (level range ±3). Even if level
range were disabled, a cooldown timer blocks the attempt for 15 minutes.
Manual DB cleanup required for each companion.

**Desired behavior (this PRD)**: Player respawns and returns to town. The
cleric NPC has respawned at her original spawn point. Player says "join me"
to the cleric. The system detects the existing companion record, bypasses
all first-time checks, and the cleric rejoin instantly at level 38 with
all her equipment. Repeat for the warrior and rogue. Full group restored
in under 5 minutes.

## Game Design Details

### Mechanics

#### Two-Track Recruitment System

The recruitment system operates on two distinct tracks:

**Track 1: First-Time Recruitment** (existing, unchanged)
- Full eligibility checks (level range, faction, combat, exclusions)
- Persuasion roll with bonuses/penalties
- Cooldown on failure (default 15 minutes)
- Creates new `companion_data` record on success

**Track 2: Re-Recruitment** (new)
- Triggered when a `companion_data` record exists for this player +
  npc_type_id with `is_suspended=1` OR `is_dismissed=1`
- **Bypasses**: cooldown check, level range check, faction check,
  persuasion roll, NPC type exclusion checks
- **Still enforces**: companions enabled rule, group capacity (< 6),
  neither party in combat, NPC not already recruited by someone else
- Restores companion to saved state (level, XP, equipment, stance)
- Clears `is_suspended` and `is_dismissed` flags
- Clears any stale cooldown data_bucket for this npc_type_id + char_id

#### Re-Recruitment Detection Logic

The detection must happen **early in the Lua flow**, before any
eligibility checks or cooldown lookups. The decision tree:

1. Is the NPC saying a recruitment keyword? Yes -> proceed.
2. Query `companion_data` for `owner_id = {char_id} AND npc_type_id =
   {npc_type_id} AND (is_dismissed = 1 OR is_suspended = 1)`.
3. If record found: **enter Track 2** (re-recruitment). Skip all
   eligibility checks except: companions enabled, group capacity,
   combat check.
4. If no record found: **enter Track 1** (first-time recruitment).
   Run full eligibility and persuasion flow.

#### Cooldown Cleanup

On successful re-recruitment, any existing cooldown data_bucket key
(`companion_cooldown_{npc_type_id}_{char_id}`) must be explicitly
deleted. This prevents stale cooldowns from a prior failed first-time
attempt from blocking future interactions.

#### Level Restoration

The C++ `Load()` function already handles level restoration by calling
`ScaleStatsToLevel()` with the saved companion level. This works correctly
today. The change is ensuring the Lua side never prevents the C++ path
from executing by rejecting the recruitment attempt prematurely.

#### State Flag Cleanup on Death

When a companion dies, the C++ `Death()` function sets `is_suspended=1`.
This is correct. The key requirement is that the Lua re-recruitment
detection recognizes `is_suspended=1` as a valid re-recruitment target
(matching the C++ `CreateFromNPC()` behavior that already checks for
`is_dismissed=1 OR is_suspended=1`).

### Balance Considerations

**Why bypass all checks on re-recruitment?**

On a 1-3 player server, companions are core party members. Losing a
companion to death is already a significant setback:
- Loss of combat effectiveness during the death/re-recruitment cycle
- Time to find the NPC's spawn point and travel there
- Potential loss of buffs (companion buffs are saved/restored, but any
  buffs cast by other party members are lost)
- The companion may need to re-med after resurrection at low HP/mana

Adding cooldowns, level checks, and persuasion rolls on top of this
natural penalty makes companion death disproportionately punishing for
a small-group server. The companion has already proven their loyalty
through adventuring together — a re-introduction check is unnecessary.

**What prevents abuse?**

- **First-time recruitment** still has full checks — you can't bypass
  faction, level, or persuasion for a new companion.
- **Group capacity** still enforced — you can't exceed 6 party members.
- **Combat check** still enforced — you can't re-recruit mid-fight to
  get a full-health companion replacing a dying one.
- **Travel time** — you still have to find the NPC's spawn point to
  re-recruit, which provides natural pacing.
- **One companion per npc_type_id** — you can't have duplicate companions
  of the same NPC type.

**No cost or delay on re-recruitment?**

Given the small-group nature of the server and the pain points documented
in the problem statement, re-recruitment should have **zero artificial
friction**. The natural costs (travel time, lost buffs, re-medding) are
sufficient. If the server owner later wants to add a platinum cost or
brief delay, those can be added as rule-controlled knobs, but they are
**out of scope** for this overhaul.

### Era Compliance

This feature does not reference any expansion-specific content. The
companion recruitment system is a custom server feature not present in
any EverQuest expansion. All NPC types, zones, and factions referenced
are Classic-Luclin era.

The narrative framing of "I remember you" for re-recruitment is consistent
with EverQuest's Classic-era quest design, where NPCs remember players
based on faction standing and quest completion. The concept of an NPC
recognizing a former adventuring companion is a natural extension of
EverQuest's faction and relationship systems.

## Lua/C++ Interface Contract Requirement

**MANDATORY GATE**: Before implementation begins, the lua-expert and
c-expert must formally agree on the interface contract between the Lua
recruitment logic and the C++ companion lifecycle.

### Current Contract (to be reviewed and confirmed)

| C++ Method | Signature | Returns | Called From |
|------------|-----------|---------|-------------|
| `client:CreateCompanion(npc)` | `Lua_Companion Lua_Client::CreateCompanion(Lua_NPC)` | `Lua_Companion` or nil on failure | `companion.lua:_on_recruitment_success()` |
| `client:HasActiveCompanion(npc_type_id)` | `bool Lua_Client::HasActiveCompanion(uint32)` | bool | Not currently used in recruitment |
| `client:GetCompanionByNPCTypeID(npc_type_id)` | `Lua_Companion Lua_Client::GetCompanionByNPCTypeID(uint32)` | `Lua_Companion` or nil | Not currently used in recruitment |
| `companion:Dismiss(voluntary_bool)` | `void Companion::Dismiss(bool)` | void | `companion.lua:cmd_dismiss()` |
| `npc:IsCompanion()` | `bool NPC::IsCompanion()` | bool | `global_npc.lua` routing |

### Contract Requirements for This Feature

1. **No new C++ methods needed** — `CreateFromNPC()` already handles
   both fresh and re-recruitment paths transparently. The Lua side just
   needs to call `client:CreateCompanion(npc)` as before.
2. **Lua must stop blocking re-recruitment** — The change is entirely
   in the Lua layer: detect existing records early, bypass checks, and
   let `CreateCompanion()` handle the rest.
3. **Both experts confirm**: After implementation, lua-expert confirms
   the Lua flow correctly routes re-recruitment, and c-expert confirms
   `CreateFromNPC()` correctly restores state for both `is_dismissed=1`
   and `is_suspended=1` records.

## Affected Systems

- [x] C++ server source (`eqemu/`) — Minor: confirm `CreateFromNPC()`
  handles all re-recruitment states correctly. May need cooldown cleanup.
- [x] Lua quest scripts (`akk-stack/server/quests/`) — Primary: rewrite
  `companion.lua:attempt_recruitment()` to detect re-recruitment early
  and bypass first-time-only checks.
- [ ] Perl quest scripts (maintenance only)
- [x] Database tables (`peq`) — `companion_data` queries for re-recruitment
  detection; `data_buckets` cooldown cleanup.
- [x] Rule values — Potentially no changes needed (existing rules are
  correct for first-time recruitment; re-recruitment bypasses them).
- [ ] Server configuration
- [ ] Infrastructure / Docker

## Dependencies

- **BUG-012 (equipment loss on death)**: The C++ `Death()` path and
  `CreateFromNPC()` re-recruitment path have already been fixed to preserve
  equipment through `SaveEquipment()` calls. This PRD depends on those
  fixes being in place.
- **BUG-013 (re-recruitment blocked)**: The C++ `CreateFromNPC()` was
  already fixed to check `is_dismissed=1 OR is_suspended=1`. This PRD
  completes the fix by also fixing the Lua layer.
- **`companion_data` table**: Must have the `is_dismissed` and
  `is_suspended` columns (already present).
- **`data_buckets` table**: Used for cooldown storage (already present).

## Open Questions

1. **Should `is_suspended=1` with `cur_hp > 0` be treated differently?**
   This state represents a companion that zoned out with the player (alive
   but suspended). Currently `CreateFromNPC()` handles this case, but it's
   worth confirming the architect agrees this should also bypass checks.
   Recommendation: yes, bypass — the companion was alive and traveling with
   the player.

2. **Should the companion be re-recruitable from ANY instance of that
   npc_type_id, or only the original spawn point?** Currently, any NPC
   with the same `npc_type_id` works. Recommendation: keep this behavior —
   forcing the player to find the exact spawn point is unnecessarily
   punishing given that some spawn points are deep in dangerous zones.

3. **Edge case: what if the player encounters two NPCs of the same
   npc_type_id simultaneously?** The first one recruited depops and becomes
   the companion. The second one remains as a normal NPC. If the companion
   dies and the player re-recruits the second NPC, `CreateFromNPC()` should
   correctly reuse the existing record. Confirm with architect.

## Acceptance Criteria

### First-Time Recruitment (unchanged, regression tests)

- [ ] Player within ±3 levels of NPC can recruit successfully (with
  sufficient faction and persuasion roll)
- [ ] Player outside ±3 levels of NPC is rejected with level range message
- [ ] Failed recruitment attempt triggers 15-minute cooldown
- [ ] Cooldown prevents re-attempt on the same NPC during the timer
- [ ] Faction below Kindly prevents recruitment
- [ ] Excluded NPC types (pets, bots, mercs, bankers, guildmasters) cannot
  be recruited

### Re-Recruitment After Death

- [ ] Companion dies, player finds same npc_type_id, says recruitment keyword
- [ ] No cooldown check — re-recruitment succeeds immediately
- [ ] No level range check — even if base NPC is 20 levels below player
- [ ] No faction check — re-recruitment bypasses faction requirement
- [ ] No persuasion roll — re-recruitment is guaranteed (barring combat/
  group capacity)
- [ ] Companion returns at saved companion level (not base NPC level)
- [ ] Companion returns with all previously equipped items intact
- [ ] Companion XP is preserved
- [ ] `is_suspended` flag is cleared in both C++ and database
- [ ] Any stale cooldown data_bucket for this npc_type_id + char_id is
  deleted

### Re-Recruitment After Voluntary Dismissal

- [ ] Dismissed companion's npc_type_id re-recruitable with same bypasses
- [ ] `is_dismissed` flag is cleared on re-recruitment
- [ ] Companion returns at saved level with equipment and XP

### Group Wipe Recovery (Multiple Simultaneous)

- [ ] All companions that died in a group wipe can be re-recruited
  individually without any cross-companion interference
- [ ] No cooldown stacking — each companion re-recruitment is independent
- [ ] Full group can be restored by sequentially re-recruiting each
  companion's NPC type

### Level Restoration on Re-Recruitment

- [ ] Companion that leveled from 20 to 38 through XP, died, and is
  re-recruited returns at level 38 (not level 20)
- [ ] Stats are correctly scaled to the saved level via `ScaleStatsToLevel()`
- [ ] HP and mana are restored to maximum after re-recruitment

### Flag/State Cleanup Verification

- [ ] After successful re-recruitment: `companion_data.is_suspended = 0`
- [ ] After successful re-recruitment: `companion_data.is_dismissed = 0`
- [ ] After successful re-recruitment: no `companion_cooldown_*` data_bucket
  exists for this npc_type_id + char_id
- [ ] After companion death: `companion_data.is_suspended = 1` (no change)
- [ ] After companion death: equipment rows in `companion_inventories` are
  preserved (no change — already fixed)

### Lua/C++ Contract Alignment Verification

- [ ] lua-expert confirms: `attempt_recruitment()` detects existing records
  before any eligibility checks and routes to re-recruitment track
- [ ] c-expert confirms: `CreateFromNPC()` correctly handles `is_suspended=1`
  records (including `cur_hp=0` dead companions) and restores full state
- [ ] Both experts confirm: `client:CreateCompanion(npc)` is the single
  entry point for both tracks, with no new C++ methods required

### Blocking Scenarios (still enforced on re-recruitment)

- [ ] Player in combat cannot re-recruit (message: "You cannot recruit
  while in combat.")
- [ ] NPC in combat cannot be re-recruited (message: "[Name] is engaged
  in combat.")
- [ ] Group at 6 members cannot add re-recruited companion (message: "Your
  party is full.")
- [ ] Companion system disabled prevents all recruitment

---

## Appendix: Technical Notes for Architect

_These are advisory observations from reading the codebase. The architect
makes all implementation decisions._

### Primary Change Location

The main change is in `akk-stack/server/quests/lua_modules/companion.lua`,
specifically the `attempt_recruitment()` function (line ~390). The function
currently checks cooldown first, then calls `is_eligible_npc()` which
enforces level range, faction, and other checks before the C++ path is
ever reached.

The re-recruitment detection should happen at the very top of
`attempt_recruitment()`, before the cooldown check, so the function can
early-return into the re-recruitment track.

### Existing C++ Re-Recruitment Support

`Companion::CreateFromNPC()` (companion.cpp:159) already has correct
re-recruitment logic:
```
auto existing = CompanionDataRepository::GetWhere(
    database,
    fmt::format(
        "owner_id = {} AND npc_type_id = {} AND (is_dismissed = 1 OR is_suspended = 1) LIMIT 1",
        owner->CharacterID(),
        source_npc->GetNPCTypeID()
    )
);
```
This correctly matches both dismissed and suspended (dead) companions.

### Lua Re-Recruitment Detection

The existing `check_dismissed_record()` function (companion.lua:371) only
checks `is_dismissed = 1`. It needs to be expanded or replaced with a
broader check that also matches `is_suspended = 1` records.

### Data Bucket Cooldown Keys

Cooldown keys follow the pattern: `companion_cooldown_{npc_type_id}_{char_id}`
These are stored with `character_id=0` in the data_buckets table (the IDs
are embedded in the key string). Cleanup requires matching by key pattern.

### Rule Names Referenced

| Rule | Default | Used In |
|------|---------|---------|
| `Companions:CompanionsEnabled` | true | Master toggle |
| `Companions:LevelRange` | 3 | First-time only |
| `Companions:MinFaction` | 3 (Kindly) | First-time only |
| `Companions:BaseRecruitChance` | 50 | First-time only |
| `Companions:RecruitCooldownS` | 900 (15 min) | First-time only |
| `Companions:ReRecruitBonus` | 0.10 | Obsolete for re-recruitment (bypassed) |

### Minimal Checks for Re-Recruitment Track

The re-recruitment track should still enforce these (subset of
`is_eligible_npc()`):
1. `Companions:CompanionsEnabled` rule
2. Group capacity (< 6 members)
3. NPC not already recruited (`is_recruited` entity variable)
4. Neither party in combat
5. NPC is not a Companion already (`IsCompanion()` check)

These are safety checks that prevent game-breaking states regardless of
recruitment track.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
