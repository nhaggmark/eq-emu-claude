# Raid Scaling — Dev Notes: protocol-agent

> **Feature branch:** `feature/raid-scaling`
> **Agent:** protocol-agent
> **Task(s):** Architecture consultation — Phase 2 Classic raids
> **Date started:** 2026-04-21
> **Current stage:** Plan (Stage 1 complete)

---

## Task Assignment

Architecture consultation role: advise the architect on client-server
protocol implications of Phase 2 changes. No implementation tasks assigned
yet — waiting for architect to assign from architecture doc.

| # | Task | Depends On | Status |
|---|------|------------|--------|
| — | Consult on PoSky death-touch removal protocol impact | — | In Progress |
| — | Confirm HP/damage client-side caching behavior | — | In Progress |
| — | Confirm respawn timer client-side state | — | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `claude/docs/topography/PROTOCOL-CODE.md` | 690 | Full protocol layer summary |
| `claude/project-work/feature-raid-scaling/feature-brief.md` | 60 | Scope, philosophy, phasing |
| `claude/project-work/feature-raid-scaling/status.md` | 210 | Decision log, open questions, all 14 user decisions |
| `claude/project-work/feature-raid-scaling/game-designer/raid-scaling-audit.md` | 2400+ | Per-era boss catalog, quest chain findings, headline findings, key decision #6 on PoSky death-touch |
| `claude/project-work/feature-raid-scaling/agent-conversations.md` | 312 | Design team exchanges, PoSky death-touch protocol flag |

### Key Findings

#### 1. Death-Touch Removal — Server-Side Only, No Client Protocol Impact

Decision #13 (status.md): "Remove death-touch entirely on Islands 4-8."

Death-touch in EQEmu is implemented as a special ability (`special_abilities`
column on `npc_types`) or via the `npcspecialattks` string — specifically the
'L' flag or special ability type 14 (Death Touch). The kill itself is
delivered to the client as a standard `OP_Death` or `OP_Damage` packet with
a lethal hit. From the Titanium client's perspective, a death-touch kill is
indistinguishable from a normal kill (very large hit) — it receives the same
`Death_Struct` / `CombatDamage_Struct` packets.

**Protocol conclusion:** Removing or nerfing death-touch is purely a
server-side database/special-ability change. The Titanium client has no
special opcode or state for "death touch received." No translation layer
changes. No opcode changes. The client will handle it cleanly whether
death-touch is removed (NPC simply doesn't use the ability) or converted
to a survivable high-damage hit (client receives normal damage packet).

**Wire format:** `CombatDamage_Struct` (line 1335 in `eq_packet_structs.h`,
~23B) carries the damage value. `type` field: 231 (0xE7) = spell damage,
otherwise skill ID. A converted death-touch would arrive as a normal melee or
spell hit — no special client handling needed. `Death_Struct` (~32B) is sent
on kill. Both are standard pass-through packets with no Titanium-specific
encoding differences that affect this change.

#### 2. NPC HP / Damage Scaling — No Client Caching, Hot-Updatable

The Titanium client does not cache NPC HP pools or max-hit values between
sessions or across zone-ins. NPC stats (HP, damage) are server-authoritative:

- On zone entry, the server sends `NewSpawn_Struct` for each visible NPC,
  which includes the spawn's appearance but NOT full stat blocks.
- HP percentage is communicated via `MobHealth` struct (~3B: entity ID +
  HP percentage 0-100). The client renders a health bar percentage, not an
  absolute HP value.
- Max-hit values are never sent to the client at all — the client never
  knows an NPC's true damage range. Combat results arrive as individual
  `CombatDamage_Struct` packets after each hit.

**Protocol conclusion:** Updating `npc_types.hp`, `npc_types.mindmg`,
`npc_types.maxdmg` via SQL requires no client-side anything. The server
will load the new values on next NPC spawn (zone restart or repop). No
packet changes. No client state to invalidate. No restart needed beyond
repop/zone restart for the NPC pool.

**Important nuance:** The `Consider_Struct` (~28B) packet sent when a
player /considers an NPC does include a con color (con_minlevel /
con_maxlevel range), but NOT raw HP or damage. Con color is level-derived,
not HP-derived. HP changes don't affect consider results.

#### 3. Respawn Timers — Server-Side Only, No Client State

Respawn timers live in `spawn2.respawntime`. The client has no visibility
into respawn state:

- When an NPC dies, the server sends `DeleteSpawn_Struct` (entity ID +
  Decay flag). The client removes the mob from its spawn list.
- When the NPC respawns, the server sends `NewSpawn_Struct` again.
- There is no "timer countdown" packet. No client state tied to respawn
  duration.

**Protocol conclusion:** Changing `spawn2.respawntime` values is a pure
database change. The client will never know or care what the respawn
duration was — it only sees spawn/despawn events. No protocol impact.

#### 4. SpawnAppearance Opcodes — Not Relevant for Stat Changes

`SpawnAppearance_Struct` (~8B, `OP_SpawnAppearance`) handles visual state
changes (animation, invisibility, etc.), not stat changes. HP/damage scaling
does not touch this path.

#### 5. No New Opcodes Needed for Phase 2

Phase 2 Classic raids involve:
- SQL changes to `npc_types` (HP, mindmg, maxdmg)
- SQL changes to `spawn2.respawntime`
- Special ability removal/modification on ~15-20 NPC rows

None of these require new opcodes, struct changes, or translation layer
modifications. All changes are server-side and transparent to the Titanium
client.

#### 6. One Potential Concern: PoSky Event Script Mechanics

The audit notes PoSky has "island-timer mechanics (if any remain)" and
potential scripted interactions. If any PoSky bosses use scripted mechanics
that send custom chat messages, emotes, or spawn packets via quest scripts
(`OP_ChannelMessage`, `OP_SpawnAppearance`, etc.) to trigger on death-touch
application — those would continue to work normally after death-touch removal.
Quest scripts use standard opcodes. No protocol concern here, but the
architect should ensure quest scripts that reference death-touch ability
behavior (if any) are reviewed by lua-expert or perl-expert when implementing.

### Implementation Plan

This is a consultation role. My deliverable is the above findings, passed
to the architect. No code written by protocol-agent for Phase 2.

**If death-touch conversion (not removal) is chosen:**
- The change is: modify `special_abilities` on the affected NPC rows to
  remove the death-touch flag, OR (if conversion to survivable hit is
  desired) replace with a high-damage spell ability — both are database
  changes.
- Wire format: the converted hit arrives as `CombatDamage_Struct` exactly
  like any other melee or spell hit. No new structs or opcodes.

**If any Phase 2 change turns out to require new client-visible behavior:**
Flag to architect immediately. Current assessment: Phase 2 is 100%
server-side; zero protocol changes required.

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `CombatDamage_Struct` layout | PROTOCOL-CODE.md line 1335 | Yes | ~23B, type field 0xE7=spell |
| `Death_Struct` layout | PROTOCOL-CODE.md line 1367 | Yes | ~32B, standard kill packet |
| `MobHealth` struct | PROTOCOL-CODE.md line 1487 | Yes | ~3B, HP percentage only |
| `NewSpawn_Struct` / `DeleteSpawn_Struct` | PROTOCOL-CODE.md | Yes | No HP stats in new spawn; delete is entity ID + decay flag |
| `Consider_Struct` | PROTOCOL-CODE.md line 1351 | Yes | ~28B, con color only, no raw HP |
| `SpawnAppearance_Struct` | PROTOCOL-CODE.md line 489 | Yes | Visual state only |
| EQ special_abilities death-touch | PROTOCOL-CODE.md topography + audit doc | Yes | Server-side special ability, no dedicated client opcode |

### Plan Amendments

Plan confirmed — no amendments needed. All Phase 2 changes are server-side.
The Titanium client has no cached NPC stat state that would require
packet resend. Death-touch removal is transparent to the client wire protocol.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Protocol consultation ready | Findings on death-touch, HP scaling, respawn — all server-side, no protocol changes required for Phase 2 |
| architect | Full 5-question detailed consultation | Death-touch is spell 982 in npc_spells_entries (data-expert task); HP/damage/respawn/rampage all server-side |

### Feedback Received

_(Awaiting architect response to detailed 5-question reply.)_

---

## Detailed Research Notes — Architect 5-Question Consultation (2026-04-21)

### Q1: Death-Touch Mechanism — VERIFIED: Spell via npc_spells_entries

DB query result for NPCs 71075/71012/71072:

| id | name | npc_spells_id | npcspecialattks |
|----|------|---------------|-----------------|
| 71012 | The_Spiroc_Lord | 118 | SERFT |
| 71072 | Bazzt_Zzzt | 449 | SEQMCNIDf |
| 71075 | Keeper_of_Souls | 969 | EMCNIDf |

npc_spells_entries for spell lists 118, 449, 969 — all three contain:
spellid=982 ("Cazic Touch"), type=1, recast_delay=30, priority=0

Spell 982 effect: effectid1=0 (SPA 0 = SE_CurrentHP), effect_base_value1=-100000.
This is a -100,000 HP direct-damage spell. NOT SPA 202 (SE_InstantDeath).
At any normal HP value under 100,000 this kills the target — functionally
instant death, but mechanically a large HP drain.

npcspecialattks letter flags decoded from NPCSpecialAttacks() at npc.cpp:1869:
E=Enrage, S=Summon, R=Rampage, Q=Quad, M=Mez, C=Charm, N=Stun, I=Snare,
D=Fear, f=FleeImmunity, T=Triple, F=Flurry, W=MeleeImmunityExceptMagical.
None of these letter flags encode death-touch.

special_abilities CSV numeric flags from emu_constants.h:527-591:
1=Summon, 2=Enrage, 3=Rampage, 4=AreaRampage, 5=Flurry, 6=TripleAttack,
7=QuadrupleAttack, 10=MagicalAttack, 13=MesmerizeImmunity, 14=CharmImmunity,
15=StunImmunity, 16=SnareImmunity, 17=FearImmunity, 21=FleeingImmunity,
23=MeleeImmunityExceptMagical, 31=PacifyImmunity, 44=CounterAvoidDamage.
There is NO death-touch entry in the SpecialAbility namespace (max=58).

Quest scripts (all three) — no death-touch scripting:
- airplane/Keeper_of_Souls.lua — summit timer + death_complete spawns Sirran
- airplane/The_Spiroc_Lord.lua — death_complete spawns Sirran, updates respawn
- airplane/Bazzt_Zzzt.lua — death_complete spawns Sirran

**Owning agent for removal:** data-expert (DELETE or disable the
npc_spells_entries rows for spellid=982 where npc_spells_id IN (118, 449, 969))

**Caution for data-expert:** Each spell list has other spells to preserve:
- npc_spells_id 118 (Spiroc Lord): also has spellid=988 "Greater Spiroc Thunder" — keep
- npc_spells_id 449 (Bazzt Zzzt): also has spellid=897 "Rotting Flesh" — keep
- npc_spells_id 969 (Keeper of Souls): also has spellid=899 "Whirl Until You Hurl" — keep

### Q2: Client Visibility of HP Changes — VERIFIED: Percentage Only

From mob.cpp:
- OP_MobHealth path: `ds->hp = (int)GetHPRatio()` (mob.cpp:1500) — int percentage 0-100
- NewSpawn_Struct: `ns->spawn.curHp = static_cast<uint8>(GetHPRatio())` (mob.cpp:1296) — uint8 percentage

Client never sees absolute NPC HP. Column type npc_types.hp = bigint(20).
No int16/overflow risk at any HP value. mindmg/maxdmg = int(10) unsigned.
Reducing 450k→90k is invisible to client until first damage packet or /consider
(con color is level-derived, not HP-derived — unaffected).

### Q3: Respawn Timers — Confirmed: Server-Side Only

No respawn timer packet exists. Client sees only DeleteSpawn_Struct (on death)
and NewSpawn_Struct (on repop). Duration between is entirely server-internal.

### Q4: Rampage special_abilities Params — Confirmed: Server-Side Only

From Mob::Rampage() at mob_ai.cpp:2114-2121:
```
int rampage_targets = GetSpecialAbilityParam(SpecialAbility::Rampage, 1);
if (rampage_targets == 0) {
    rampage_targets = RuleI(Combat, DefaultRampageTargets);
}
if (rampage_targets > RuleI(Combat, MaxRampageTargets)) {
    rampage_targets = RuleI(Combat, MaxRampageTargets);
}
```
Param index 1 in the special_abilities CSV for flag 3 (Rampage) controls the
target count. The client receives individual CombatDamage_Struct packets per
hit — no packet encodes "NPC will rampage N targets". Modifying these params
is pure server-side AI. No protocol changes needed.

Note on CSV format: `3,<chance>,<target_count>,<dmg_mod>^...` — params are
comma-separated after the flag ID, entries separated by `^`.

### Q5: Titanium-Specific Constraints — None New for Phase 2

All Phase 2 changes remain server-side. One confirmation: the Titanium client
HP display uses a 1-byte (uint8) percentage field. Any HP value from 1 to
bigint(20) max will render correctly — the server always sends a 0-100 ratio.

---

## Stage 4: Build

_(Not applicable — protocol-agent is consultation-only for Phase 2.
Implementation tasks will be assigned if any C++ or protocol changes
are needed in later phases.)_

---

## Open Items

- [x] Phase 2 Classic consultation complete
- [x] Phase 3 Kunark consultation complete (2026-04-22)
- [x] Phase 4a Velious non-ToV consultation complete (2026-04-22)
- [ ] Phase 4b Velious ToV+Sleeper+Vulak — re-consult when architect starts
- [ ] Phase 5 Luclin (VT, Shards) — re-consult when architect starts

---

## Phase 3: Kunark Protocol Consultation (2026-04-22)

**Scope:** All 19 Kunark raid bosses cataloged in `game-designer/raid-scaling-audit.md`
(4 outdoor dragons, Trakanon, Venril Sathir, Drusella, 3 Chardok royals, 2 City of
Mist, 7 VP dragons).

**Summary finding: Phase 3 is fully server-side. Zero client protocol impact.**
Same conclusion as Phase 2. Detailed findings below.

### Finding 1: HP/Damage/Respawn scaling — confirmed server-side only

Phase 2 analysis applies unchanged. `MobHealth` sends percentage only; client never
sees absolute NPC HP. Max-damage values never sent to client. `spawn2.respawntime`
changes invisible to client. No new protocol concerns for Kunark NPCs.

### Finding 2: Phara Dar HP-percentage add-wave script — safe to scale HP

Phara Dar (`veeshan/108048.pl`) has a `quest::setnexthpevent(N)` / `EVENT_HP` pattern
that spawns `#Protector_of_Phara_Dar` (NPC 108518) at 80/60/40/20% HP thresholds.

**Protocol assessment:** `quest::setnexthpevent(N)` is a server-side percentage trigger
computed from the NPC's current HP ratio — the same ratio the server already tracks for
`MobHealth` packets. When Phara Dar's HP is scaled down (e.g. from 681k to ~120k), the
percentage thresholds remain meaningful and fire at the same points in the fight. The
client receives normal `NewSpawn_Struct` packets for each protector as they appear —
standard spawn traffic, no special client state.

**Conclusion:** HP scaling does not break or alter the Phara Dar add-wave mechanic.
The wave-spawn behavior is preserved exactly. No protocol impact. This is the most
interesting scripted encounter in Phase 3 and it is clean.

### Finding 3: Venril Sathir two-form transition — safe to scale HP

VS uses two NPC IDs: form 1 is Spirit of Venril Sathir (102112, script-spawned by
`karnor/Spirit_of_Venril_Sathir.pl`), form 2 is Venril Sathir himself (102126,
spawned by the Spirit's EVENT_ITEM handler on turn-in). The `#Venril_Sathir.lua`
script (`karnor/#Venril_Sathir.lua`) simply depops VS's remains (NPC 102099) on
spawn if they are already up — a spawn-deduplication guard.

**Protocol assessment:** The form transition is a `quest::spawn2` + `quest::depop`
pattern. The client sees a standard `DeleteSpawn_Struct` for the Spirit and a
`NewSpawn_Struct` for VS. This is identical to any other server-side despawn/respawn
event. Scaling the HP on NPC 102112 (Spirit) and/or 102126 (VS Lich form) via SQL
has zero effect on the form-transition packet sequence.

**Conclusion:** Two-form scripted transition is fully server-side. HP scaling on both
NPC IDs is safe. No protocol impact.

### Finding 4: Veeshan's Peak door-gate mechanic — safe, no DZ/instance

`veeshan/player.pl` implements a door-gate for VP's inner chamber (doors 56/57):
all five outer dragons (108053, 108040, 108047, 108043, 108050) must be dead before
the door opens. The script uses `entity_list->IsMobSpawnedByNpcTypeID()` checks and
`quest::forcedooropen()`.

**Protocol assessment:** No Expedition/DZ mechanism is used. VP is a standard open
zone with a script-driven door lock. `quest::forcedooropen()` sends `OP_MoveDoor`
to the client — a standard packet already in the Titanium translation layer. Scaling
HP on the five outer dragons does not affect the door-gate logic (it checks NPC
presence, not HP). No new packets, no DZ opcodes, no expedition protocol involved.

**Conclusion:** VP door-gate is purely server-side entity presence detection.
No protocol impact.

### Finding 5: No DZ/Expedition mechanism for any Kunark encounter

Surveyed all VP scripts (`108040.pl`, `108043.pl`, `108047.pl`, `108048.pl`,
`108050.pl`, `108053.pl`), Karnor scripts, and the VP player script. None use
`expedition`, `MovePCDynamicZone`, `ServerOP_ExpeditionCreate`, or any DZ API.
VP is a flat open zone. Contrast with `hateplaneb` (Phase 2) which DOES use
`MovePCDynamicZone` for Rogue epic access — but VP does not.

**Conclusion:** No Kunark encounter uses Expedition/DZ mechanics. No
`ServerOP_Expedition*` traffic relevant to Phase 3.

### Finding 6: Outdoor dragon special abilities (npcspecialattks) — no protocol flags

Outdoor dragons (Gorenaire, Severilous, Talendor, Faydedar) have `npcspecialattks`
flags S (summon), E (enrage), T (triple), R (rampage), M/C/N/I/D/f (immunities).
All of these are server-side combat behavior flags. Each resulting combat event
delivers standard `CombatDamage_Struct` / `Action_Struct` packets to the client.
No special client opcode needed for any of these mechanics.

**Conclusion:** npcspecialattks changes on Kunark bosses (if any flurry or rampage
trimming is done, as the audit recommends for Trakanon) remain server-side. Same
pattern as Cazic Thule rampage trim in Phase 2.

### Phase 3 Protocol Summary

| Concern | Source | Verdict |
|---------|--------|---------|
| HP/damage/respawn scaling (all 19 bosses) | Phase 2 analysis applies | Server-side only |
| Phara Dar add-wave (% HP event → spawn adds) | veeshan/108048.pl | Server-side; % thresholds survive HP rescale |
| Venril Sathir two-form transition | karnor/Spirit_of_Venril_Sathir.pl | Server-side spawn/depop |
| VP door-gate (5 outer dragons must die) | veeshan/player.pl | Server-side entity check; OP_MoveDoor is standard |
| VP DZ/Expedition mechanism | All VP scripts + karnor | None — VP is standard open zone |
| Outdoor dragon npcspecialattks trimming | Audit recommendations | Server-side AI only |
| Flurry trim on Trakanon | Audit recommendation | special_abilities CSV edit, same as Phase 2 CT rampage |

**No Phase 3 changes require opcode additions, struct modifications, or Titanium
translation layer changes. Phase 3 is 100% server-side (SQL), same as Phase 2.**

---

---

## Phase 4a: Velious non-ToV Protocol Consultation (2026-04-22)

**Scope:** Kael Drakkel, Plane of Growth, Skyshrine, outdoor Velious (Western Wastes,
Great Divide, necropolis, Siren's Grotto), Coldain Ring War event.

**Summary finding: Phase 4a is fully server-side. Zero client protocol impact.**
Same conclusion as Phases 2 and 3. Detailed findings below.

### Finding 1: Coldain Ring War — spawn_condition wave system, no DZ

Examined `akk-stack/server/quests/greatdivide/encounters/ring_war.lua` (full read).

The Ring War uses `eq.spawn_condition("greatdivide", 0, N, 0/1)` to toggle 21 spawn
conditions for wave mobs. A `ringtenmaster` NPC (118173) coordinates waves via `eq.signal()`
and a `wave_cooldown` timer (`wave_cooldown_time = 5 * 60 * 1000` — 5 minutes, Lua local).
Wave bosses (WaveMaster NPCs) signal the master on death to trigger the next wave.

`eq.spawn_condition()` is a server-internal state change — no special opcode to client.
Client sees only `NewSpawn_Struct` / `DeleteSpawn_Struct` for each wave mob. No Expedition,
no DZ, no progress-bar opcode. The Ring War is a standard open-zone event.

Wave mob HP scaling: pure SQL `npc_types.hp` UPDATE per wave-mob NPC ID — same as any
boss. Transparent to client. Wave timer reduction (`wave_cooldown_time`): Lua-only local
variable — lua-expert edit if architect wants to address small-group throughput problem.

Failure conditions (Seneschal Aldikan death OR giants reaching Thurgadin waypoint) trigger
`Stop_Event()` which resets all spawn conditions — fully server-side.

**Protocol conclusion:** No client protocol impact. No new opcodes.

### Finding 2: Kael faction gating — server-side only

`King_Tormax.lua` uses `e.other:GetFaction(e.self) <= 3` (kindly or better) to gate
say/trade handlers. Faction data lives in `faction_values` table — no client-cached
faction state. Client only receives resulting `ChannelMessage_Struct` (NPC speech) or
item summoning packets after server-side check passes.

Avatar of War spawn chain: `The_Statue_of_Rallos_Zek.lua` event_death_complete →
`eq.unique_spawn(113341, ...)` (Idol). Then `#The_Idol_of_Rallos_Zek.lua`
event_death_complete → `eq.unique_spawn(113457, ...)` (Avatar). Both use `eq.unique_spawn`
which sends a standard `NewSpawn_Struct` — identical to VP's `quest::forcedooropen()` +
`IsMobSpawnedByNpcTypeID()` pattern confirmed safe in Phase 3.

`The_Avatar_of_War.lua` has a 1-hour `depop` timer that pauses while in combat — server-side
only, client sees `DeleteSpawn_Struct` on depop.

King Tormax combat (`King_Tormax.lua`) also calls `MoveTo()` on 6 adds (NPCs 113129, 113130,
113131, 113133, 113134, 113302, 113382, 113383) to assist — standard server-side pathfinding,
no special opcodes.

**Protocol conclusion:** No client protocol impact. Faction check is server-side.
Spawn chain is standard NewSpawn_Struct. Same pattern as VP Phase 3.

### Finding 3: Plane of Growth Tunare — spawn-swap, zone aggro

`#_Tunare.lua` (NPC 127001, tree form): on event_combat joined, calls `eq.spawn2(127098,...)`
(the actual combat form) then `call_zone_to_assist()` (iterates entity_list, adds all non-
excluded NPCs to hate list) then `eq.depop_with_timer()`.

Client sees: `DeleteSpawn_Struct` for 127001 (depop), `NewSpawn_Struct` for 127098 entering
combat. Standard spawn-swap — same as VS form-transition in Phase 3. Zone-wide aggro is
server-side AI hate-list manipulation; no special packet.

**Protocol conclusion:** No client protocol impact. Standard spawn-swap pattern.

### Finding 4: No DZ/Expedition in any Velious non-ToV zone

Grepped all scripts in greatdivide/, kael/, growthplane/, skyshrine/, westwastes/,
necropolis/ for `MovePCDynamicZone`, `expedition`, `DynamicZone`. Zero results.

All Velious non-ToV zones are standard open zones with `ZoneChange_Struct` →
`ZoneServerInfo_Struct` entry flow. Contrast: Phase 2's hateplaneb used
`MovePCDynamicZone("hateplaneb")` from `oasis/player.lua`. No Velious non-ToV equivalent.

**Protocol conclusion:** No DZ/instance overhead in any Phase 4a zone.

### Phase 4a Protocol Summary

| Concern | Source | Verdict |
|---------|--------|---------|
| Ring War spawn_condition wave system | greatdivide/encounters/ring_war.lua | Server-side; NewSpawn/DeleteSpawn per wave mob; no special opcodes |
| Ring War wave_cooldown_time (5 min) | ring_war.lua Lua local | Lua-only; lua-expert editable; no protocol impact |
| Ring War failure (seneschal death / giants reach Thurgadin) | ring_war.lua | Server-side Stop_Event(); no protocol impact |
| Kael faction check (GetFaction <= 3) | kael/King_Tormax.lua | Server-side; client sees NPC speech/trade results only |
| Statue→Idol→Avatar spawn chain | kael/Statue+Idol+Avatar scripts | eq.unique_spawn() = NewSpawn_Struct; same as VP Phase 3 |
| Avatar of War 1-hour depop timer | kael/The_Avatar_of_War.lua | Server-side timer; DeleteSpawn on depop |
| Tunare spawn-swap (#_Tunare → #Tunare 127098) | growthplane/#_Tunare.lua | Standard spawn-swap; same as VS Phase 3 |
| DZ/Expedition usage in Velious non-ToV | grep all scripts | None found — all standard open zones |
| HP/damage/respawn scaling | Phase 2/3 analysis applies | Server-side SQL only; client sees % HP |

**No Phase 4a changes require opcode additions, struct modifications, or Titanium
translation layer changes. Phase 4a is 100% server-side (SQL + optional Lua for Ring
War wave timer), same as Phases 2 and 3.**

**Flag for architect:** Ring War addressing requires two agents:
- data-expert (wave-mob HP scaling via npc_types UPDATE — same SQL pattern)
- lua-expert (wave_cooldown_time reduction if architect decides to reduce inter-wave gap)
Both are server-side. Neither touches protocol layer.

---

## Context for Next Agent

Protocol-agent has completed consultation for Phase 2 (Classic) and Phase 3
(Kunark) raid scaling. Core finding in both phases: **all changes are purely
server-side and have zero Titanium client protocol impact.**

Key source refs:
- `CombatDamage_Struct` at eq_packet_structs.h:1335 — standard hit packet
- `MobHealth` at eq_packet_structs.h:1487 — HP percentage only, no absolute values
- `Death_Struct` at eq_packet_structs.h:1367 — same packet used for all kills
- `quest::setnexthpevent` — server-side trigger, percentage-based, unaffected by HP scale
- VP door-gate: `OP_MoveDoor` (standard Titanium opcode, no new protocol needed)

Phase 4 (Velious: Ring War, ToV, Sleeper) may have scripted event complexity worth
re-checking. Phase 5 (Luclin: VT key event, Shards) likewise. Re-consult for those.
